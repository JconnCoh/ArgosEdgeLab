[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-TextSha256([string]$Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Resolve-Pin([string]$ProjectRoot, [object]$Pin, [string]$Label) {
    $value = [string]$Pin.path
    if (-not [IO.Path]::IsPathRooted($value)) { $value = Join-Path $ProjectRoot $value.Replace('/', '\') }
    $value = [IO.Path]::GetFullPath($value)
    if (-not (Test-Path -LiteralPath $value -PathType Leaf)) { throw "$Label is absent: $value" }
    if ((Get-FileSha256 -Path $value) -cne [string]$Pin.sha256) { throw "$Label hash mismatch." }
    return $value
}

function New-TopLevelPayload([string]$ExecutorText, [string]$RequestText) {
    $requestLiteral = $RequestText.Replace("'", "''")
    $prefix = @'
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [ValidateSet('ZERO','ONE','MANY','ERROR','TIMEOUT')][string]$RehearsalCase = 'ONE'
)
$directObserverExecutor = {
'@
    $suffix = @"
}
`$directObserverRequestJson = '$requestLiteral'
if (`$Preflight) {
    & `$directObserverExecutor -RequestJson `$directObserverRequestJson -Preflight
    return
}
if (`$Rehearsal) {
    & `$directObserverExecutor -RequestJson `$directObserverRequestJson -Rehearsal -RehearsalCase `$RehearsalCase
    return
}
& `$directObserverExecutor -RequestJson `$directObserverRequestJson -Execute -EmitClipboard
"@
    return $prefix.TrimStart() + "`r`n" + $ExecutorText.Trim() + "`r`n" + $suffix.TrimStart()
}

function Assert-Parses([string]$Source, [string]$Context) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($Source, $Context, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) {
        $messages = @($errors | ForEach-Object { [string]$_.Message })
        throw "$Context parser failure: $($messages -join '; ')"
    }
}

function Convert-ExactJson([object[]]$Rows, [string]$Context) {
    $text = ($Rows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ([string]::IsNullOrWhiteSpace($text)) { throw "$Context returned no JSON." }
    return ($text | ConvertFrom-Json -ErrorAction Stop)
}

function Assert-RunnerFixture([string]$RunnerSource, [object]$Fixture) {
    $runnerFields = @(
        [regex]::Matches($RunnerSource, '\$remoteResult\.([A-Za-z][A-Za-z0-9]*)') |
            ForEach-Object { [string]$_.Groups[1].Value } |
            Sort-Object -Unique
    )
    $expectedFields = @(
        'computerName','imageBytesRead','nonce','scalar','schema','state',
        'targetPersistentMutationPerformed','taskOrProcessManagementPerformed'
    ) | Sort-Object
    if (($runnerFields -join ',') -cne ($expectedFields -join ',')) { throw 'Transport runner result field set changed.' }
    $fixtureFields = @($Fixture.PSObject.Properties.Name)
    foreach ($field in $runnerFields) {
        if ($fixtureFields -notcontains $field) { throw "Generated result lacks runner field: $field" }
    }
    [void][string]$Fixture.schema
    [void][string]$Fixture.state
    [void][string]$Fixture.nonce
    [void][string]$Fixture.computerName
    [void][string]$Fixture.scalar
    [void][bool]$Fixture.taskOrProcessManagementPerformed
    [void][bool]$Fixture.imageBytesRead
    [void][bool]$Fixture.targetPersistentMutationPerformed
}

$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Build) { $modeCount++ }
if ($modeCount -ne 1) { throw 'Select exactly one of -Preflight or -Build.' }

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Invocation manifest is absent: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$manifest.schema -cne 'argos_direct_observer_payload_build_invocation_v2') { throw 'Unexpected payload-build invocation schema.' }
$lifecycle = [string]$manifest.artifactLifecycle
if (@('DRAFT','FROZEN') -cnotcontains $lifecycle) { throw 'Payload-build invocation lifecycle is not designable.' }
if ($Build -and $lifecycle -cne 'FROZEN') { throw 'Build requires a frozen invocation.' }
$projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd('\')
$builderPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.builder -Label 'Builder V2'
if (-not $builderPath.Equals([IO.Path]::GetFullPath($PSCommandPath), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invocation pins a different builder.' }
$executorPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.executor -Label 'Executor'
$requestPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.request -Label 'Request'
$runnerPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.transportRunner -Label 'Transport runner'

$executorText = [IO.File]::ReadAllText($executorPath, [Text.UTF8Encoding]::new($false))
$requestText = [IO.File]::ReadAllText($requestPath, [Text.UTF8Encoding]::new($false)).Trim()
$runnerText = [IO.File]::ReadAllText($runnerPath, [Text.UTF8Encoding]::new($false))
$payload = New-TopLevelPayload -ExecutorText $executorText -RequestText $requestText
Assert-Parses -Source $payload -Context 'ARGOS_DIRECT_OBSERVER_TOP_LEVEL_PAYLOAD_V2'
if ($payload.Length -gt [int]$manifest.maximumPayloadCharacters) { throw 'Generated payload exceeds its character limit.' }

$payloadBlock = [ScriptBlock]::Create($payload)
$preflightRows = @(& $payloadBlock -Preflight)
$payloadPreflight = Convert-ExactJson -Rows $preflightRows -Context 'Generated payload preflight'
if ([string]$payloadPreflight.state -cne 'PASS_ARGOS_DIRECT_OBSERVER_PREFLIGHT') { throw 'Generated payload preflight did not pass.' }
$caseIds = @($payloadPreflight.cases | ForEach-Object { [string]$_.caseId } | Sort-Object)
if (($caseIds -join ',') -cne 'ERROR,MANY,ONE,TIMEOUT,ZERO') { throw 'Generated payload preflight case set changed.' }

$rehearsalRows = @(& $payloadBlock -Rehearsal -RehearsalCase ONE)
$rehearsal = Convert-ExactJson -Rows $rehearsalRows -Context 'Generated payload rehearsal'
if ([string]$rehearsal.state -cne 'PASS_ARGOS_DIRECT_OBSERVATION' -or @($rehearsal.rows).Count -ne 1) { throw 'Generated payload ONE rehearsal did not pass.' }
Assert-RunnerFixture -RunnerSource $runnerText -Fixture $rehearsal

$outputPath = [string]$manifest.outputPath
if (-not [IO.Path]::IsPathRooted($outputPath)) { $outputPath = Join-Path $projectRoot $outputPath.Replace('/', '\') }
$outputPath = [IO.Path]::GetFullPath($outputPath)
$gatePath = [string]$manifest.buildGatePath
if (-not [IO.Path]::IsPathRooted($gatePath)) { $gatePath = Join-Path $projectRoot $gatePath.Replace('/', '\') }
$gatePath = [IO.Path]::GetFullPath($gatePath)
$payloadHash = Get-TextSha256 -Text $payload

$plan = [ordered]@{
    schema = 'argos_direct_observer_payload_build_plan_v2'
    state = 'PASS_ARGOS_DIRECT_OBSERVER_PAYLOAD_BUILD_PLAN_V2'
    invocationManifestSha256 = Get-FileSha256 -Path $manifestPath
    builderSha256 = [string]$manifest.builder.sha256
    executorSha256 = [string]$manifest.executor.sha256
    requestFileSha256 = [string]$manifest.request.sha256
    requestSha256 = [string]$payloadPreflight.requestSha256
    requestSchemaSha256 = [string]$payloadPreflight.requestSchemaSha256
    resultSchemaSha256 = [string]$payloadPreflight.resultSchemaSha256
    transportRunnerSha256 = [string]$manifest.transportRunner.sha256
    outputPath = $outputPath
    buildGatePath = $gatePath
    payloadCharacters = $payload.Length
    payloadSha256 = $payloadHash
    topLevelPreflightDeclared = $true
    topLevelRehearsalDeclared = $true
    preflightCaseIds = $caseIds
    combinedRehearsalState = [string]$rehearsal.state
    combinedRehearsalRowCount = @($rehearsal.rows).Count
    targetQueryPerformed = $false
    clipboardChanged = $false
    remoteInputSent = $false
    taskOrProcessManagementPerformed = $false
    imageBytesRead = $false
    targetPersistentMutationPerformed = $false
}

if ($Preflight) {
    if (Test-Path -LiteralPath $outputPath) { throw "Preflight refuses existing output: $outputPath" }
    if (Test-Path -LiteralPath $gatePath) { throw "Preflight refuses existing build gate: $gatePath" }
    $plan | ConvertTo-Json -Depth 8
    return
}

if (Test-Path -LiteralPath $outputPath) { throw "Create-new output already exists: $outputPath" }
if (Test-Path -LiteralPath $gatePath) { throw "Create-new build gate already exists: $gatePath" }
$outputParent = Split-Path -Parent $outputPath
if ($outputParent -cne (Split-Path -Parent $gatePath)) { throw 'Payload and build gate must share one parent.' }
if (-not (Test-Path -LiteralPath $outputParent -PathType Container)) { throw "Output parent is absent: $outputParent" }

$payloadBytes = [Text.UTF8Encoding]::new($false).GetBytes($payload)
$payloadStream = [IO.File]::Open($outputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $payloadStream.Write($payloadBytes, 0, $payloadBytes.Length) }
finally { $payloadStream.Dispose() }
if ((Get-FileSha256 -Path $outputPath) -cne $payloadHash) { throw 'Created payload hash mismatch.' }

$buildGate = [ordered]@{}
foreach ($key in $plan.Keys) { $buildGate[$key] = $plan[$key] }
$buildGate.schema = 'argos_direct_observer_payload_build_gate_v2'
$buildGate.state = 'PASS_ARGOS_DIRECT_OBSERVER_PAYLOAD_BUILD_V2'
$buildGate.createdUtc = [DateTime]::UtcNow.ToString('o')
$buildGate.outputCreated = $true
$gateJson = $buildGate | ConvertTo-Json -Depth 8
$gateBytes = [Text.UTF8Encoding]::new($false).GetBytes($gateJson + [Environment]::NewLine)
$gateStream = [IO.File]::Open($gatePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $gateStream.Write($gateBytes, 0, $gateBytes.Length) }
finally { $gateStream.Dispose() }
$gateJson
