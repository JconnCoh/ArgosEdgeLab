[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256File([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-Sha256Text([string]$Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Resolve-PinnedPath([string]$ProjectRoot, [object]$Pin, [string]$Context) {
    $path = [string]$Pin.path
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $ProjectRoot $path.Replace('/', '\') }
    $path = [IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$Context is absent: $path" }
    $actualHash = Get-Sha256File -Path $path
    if ($actualHash -cne [string]$Pin.sha256) { throw "$Context hash mismatch." }
    return $path
}

function New-CombinedPayload([string]$ExecutorText, [string]$RequestText, [string]$ModeSuffix) {
    $requestLiteral = $RequestText.Replace("'", "''")
    return "& {`r`n$($ExecutorText.Trim())`r`n} -RequestJson '$requestLiteral' $ModeSuffix`r`n"
}

function Assert-PayloadParses([string]$Payload, [string]$Context) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($Payload, $Context, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) {
        $messages = @($errors | ForEach-Object { [string]$_.Message })
        throw "$Context parser failure: $($messages -join '; ')"
    }
}

function Assert-TransportConsumerContract([string]$RunnerSource, [object]$Fixture) {
    $consumerFields = @(
        [regex]::Matches($RunnerSource, '\$remoteResult\.([A-Za-z][A-Za-z0-9]*)') |
            ForEach-Object { [string]$_.Groups[1].Value } |
            Sort-Object -Unique
    )
    $expectedFields = @(
        'computerName','imageBytesRead','nonce','scalar','schema','state',
        'targetPersistentMutationPerformed','taskOrProcessManagementPerformed'
    ) | Sort-Object
    if (($consumerFields -join ',') -cne ($expectedFields -join ',')) {
        throw "Transport consumer field set changed. Actual=$($consumerFields -join ',')"
    }
    $fixtureNames = @($Fixture.PSObject.Properties.Name)
    foreach ($field in $consumerFields) {
        if ($fixtureNames -notcontains $field) { throw "Fixture lacks transport consumer field: $field" }
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

$resolvedInvocationPath = [IO.Path]::GetFullPath($InvocationManifest)
if (-not (Test-Path -LiteralPath $resolvedInvocationPath -PathType Leaf)) { throw "Invocation manifest is absent: $resolvedInvocationPath" }
$invocation = Get-Content -LiteralPath $resolvedInvocationPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$invocation.schema -cne 'argos_direct_observer_payload_build_invocation_v1') { throw 'Unexpected payload-build invocation schema.' }
$invocationLifecycle = [string]$invocation.artifactLifecycle
if (@('DRAFT','FROZEN') -cnotcontains $invocationLifecycle) { throw 'Payload-build invocation lifecycle is not designable.' }
if ($Build -and $invocationLifecycle -cne 'FROZEN') { throw 'Build requires a frozen invocation.' }
$projectRoot = [IO.Path]::GetFullPath([string]$invocation.projectRoot).TrimEnd('\')
$builderPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.builder -Context 'Payload builder'
if (-not $builderPath.Equals([IO.Path]::GetFullPath($PSCommandPath), [StringComparison]::OrdinalIgnoreCase)) { throw 'Invocation pins a different payload builder.' }
$executorPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.executor -Context 'Executor'
$requestPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.request -Context 'Request'
$runnerPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.transportRunner -Context 'Transport runner'
$executorText = [IO.File]::ReadAllText($executorPath, [Text.UTF8Encoding]::new($false))
$requestText = [IO.File]::ReadAllText($requestPath, [Text.UTF8Encoding]::new($false)).Trim()
$runnerSource = [IO.File]::ReadAllText($runnerPath, [Text.UTF8Encoding]::new($false))

$executorPreflightTextRows = @(& $executorPath -RequestPath $requestPath -Preflight)
$executorPreflightText = ($executorPreflightTextRows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
$executorPreflight = $executorPreflightText | ConvertFrom-Json -ErrorAction Stop
if ([string]$executorPreflight.state -cne 'PASS_ARGOS_DIRECT_OBSERVER_PREFLIGHT') { throw 'Executor preflight did not pass.' }

$rehearsalPayload = New-CombinedPayload -ExecutorText $executorText -RequestText $requestText -ModeSuffix '-Rehearsal -RehearsalCase ONE'
Assert-PayloadParses -Payload $rehearsalPayload -Context 'ARGOS_DIRECT_OBSERVER_REHEARSAL_PAYLOAD'
$rehearsalBlock = [ScriptBlock]::Create($rehearsalPayload)
$rehearsalTextRows = @(& $rehearsalBlock)
$rehearsalText = ($rehearsalTextRows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
$rehearsalResult = $rehearsalText | ConvertFrom-Json -ErrorAction Stop
if ([string]$rehearsalResult.state -cne 'PASS_ARGOS_DIRECT_OBSERVATION' -or @($rehearsalResult.rows).Count -ne 1) {
    throw 'Combined payload rehearsal did not return one passing fixture row.'
}
Assert-TransportConsumerContract -RunnerSource $runnerSource -Fixture $rehearsalResult

$livePayload = New-CombinedPayload -ExecutorText $executorText -RequestText $requestText -ModeSuffix '-Execute -EmitClipboard'
Assert-PayloadParses -Payload $livePayload -Context 'ARGOS_DIRECT_OBSERVER_LIVE_PAYLOAD'
$livePayloadSha256 = Get-Sha256Text -Text $livePayload
if ($livePayload.Length -gt [int]$invocation.maximumPayloadCharacters) { throw 'Combined live payload exceeds its character bound.' }

$outputPath = [string]$invocation.outputPath
if (-not [IO.Path]::IsPathRooted($outputPath)) { $outputPath = Join-Path $projectRoot $outputPath.Replace('/', '\') }
$outputPath = [IO.Path]::GetFullPath($outputPath)
$gatePath = [string]$invocation.buildGatePath
if (-not [IO.Path]::IsPathRooted($gatePath)) { $gatePath = Join-Path $projectRoot $gatePath.Replace('/', '\') }
$gatePath = [IO.Path]::GetFullPath($gatePath)

$plan = [ordered]@{
    schema = 'argos_direct_observer_payload_build_plan_v1'
    state = 'PASS_ARGOS_DIRECT_OBSERVER_PAYLOAD_BUILD_PLAN'
    invocationManifestSha256 = Get-Sha256File -Path $resolvedInvocationPath
    executorSha256 = [string]$invocation.executor.sha256
    requestFileSha256 = [string]$invocation.request.sha256
    requestSha256 = [string]$executorPreflight.requestSha256
    requestSchemaSha256 = [string]$executorPreflight.requestSchemaSha256
    resultSchemaSha256 = [string]$executorPreflight.resultSchemaSha256
    transportRunnerSha256 = [string]$invocation.transportRunner.sha256
    outputPath = $outputPath
    buildGatePath = $gatePath
    payloadCharacters = $livePayload.Length
    payloadSha256 = $livePayloadSha256
    combinedRehearsalState = [string]$rehearsalResult.state
    combinedRehearsalRowCount = @($rehearsalResult.rows).Count
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
if ((Split-Path -Parent $outputPath) -cne (Split-Path -Parent $gatePath)) { throw 'Payload and build gate must share one existing parent.' }
$parent = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "Output parent is absent: $parent" }

$payloadBytes = [Text.UTF8Encoding]::new($false).GetBytes($livePayload)
$payloadStream = [IO.File]::Open($outputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $payloadStream.Write($payloadBytes, 0, $payloadBytes.Length) }
finally { $payloadStream.Dispose() }
if ((Get-Sha256File -Path $outputPath) -cne $livePayloadSha256) { throw 'Created payload hash mismatch.' }

$buildGate = [ordered]@{}
foreach ($key in $plan.Keys) { $buildGate[$key] = $plan[$key] }
$buildGate.schema = 'argos_direct_observer_payload_build_gate_v1'
$buildGate.state = 'PASS_ARGOS_DIRECT_OBSERVER_PAYLOAD_BUILD'
$buildGate.createdUtc = [DateTime]::UtcNow.ToString('o')
$buildGate.outputCreated = $true
$gateJson = $buildGate | ConvertTo-Json -Depth 8
$gateBytes = [Text.UTF8Encoding]::new($false).GetBytes($gateJson + [Environment]::NewLine)
$gateStream = [IO.File]::Open($gatePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $gateStream.Write($gateBytes, 0, $gateBytes.Length) }
finally { $gateStream.Dispose() }
$gateJson
