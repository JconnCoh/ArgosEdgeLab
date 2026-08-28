[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
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

function Resolve-PinnedPath([string]$ProjectRoot, [object]$Pin, [string]$Context) {
    $path = [string]$Pin.path
    if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $ProjectRoot $path.Replace('/', '\') }
    $path = [IO.Path]::GetFullPath($path)
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "$Context is absent: $path" }
    $actualHash = Get-Sha256File -Path $path
    if ($actualHash -cne [string]$Pin.sha256) { throw "$Context hash mismatch." }
    return $path
}

function Invoke-JsonChild([string]$PowerShellPath, [string]$ExecutorPath, [string]$RequestPath, [string[]]$ModeArguments) {
    $argumentRows = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$ExecutorPath,'-RequestPath',$RequestPath) + @($ModeArguments)
    $outputRows = @(& $PowerShellPath @argumentRows 2>&1)
    $exitCode = $LASTEXITCODE
    $outputText = ($outputRows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ($exitCode -ne 0) { throw "Child Windows PowerShell failed ($exitCode): $outputText" }
    if ([string]::IsNullOrWhiteSpace($outputText)) { throw 'Child Windows PowerShell returned no JSON.' }
    return ($outputText | ConvertFrom-Json -ErrorAction Stop)
}

$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Gate) { $modeCount++ }
if ($modeCount -ne 1) { throw 'Select exactly one of -Preflight or -Gate.' }
$resolvedInvocationPath = [IO.Path]::GetFullPath($InvocationManifest)
if (-not (Test-Path -LiteralPath $resolvedInvocationPath -PathType Leaf)) { throw "Invocation manifest is absent: $resolvedInvocationPath" }
$invocation = Get-Content -LiteralPath $resolvedInvocationPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$invocation.schema -cne 'argos_direct_observer_test_invocation_v1') { throw 'Unexpected test invocation schema.' }
if ([string]$invocation.artifactLifecycle -cne 'FROZEN') { throw 'Test invocation is not frozen.' }
$projectRoot = [IO.Path]::GetFullPath([string]$invocation.projectRoot).TrimEnd('\')
$executorPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.executor -Context 'Executor'
$requestPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.request -Context 'Request'
$requestSchemaPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.requestSchema -Context 'Request schema'
$resultSchemaPath = Resolve-PinnedPath -ProjectRoot $projectRoot -Pin $invocation.resultSchema -Context 'Result schema'
$powerShellPath = [IO.Path]::GetFullPath([string]$invocation.windowsPowerShell51)
if (-not (Test-Path -LiteralPath $powerShellPath -PathType Leaf)) { throw "Windows PowerShell 5.1 is absent: $powerShellPath" }
$executorCommands = @(Get-Command -Name $executorPath -CommandType ExternalScript -ErrorAction Stop)
if ($executorCommands.Count -ne 1) { throw 'Executor did not resolve exactly once.' }
foreach ($parameterName in @('RequestPath','Preflight','Rehearsal','RehearsalCase','Execute','EmitClipboard')) {
    if (-not $executorCommands[0].Parameters.ContainsKey($parameterName)) { throw "Executor parameter is absent: $parameterName" }
}
$requestSchema = Get-Content -LiteralPath $requestSchemaPath -Raw | ConvertFrom-Json -ErrorAction Stop
$resultSchema = Get-Content -LiteralPath $resultSchemaPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$requestSchema.title -cne 'Argos direct read-only observation request v1') { throw 'Request schema title mismatch.' }
if ([string]$resultSchema.title -cne 'Argos direct read-only observation result v1') { throw 'Result schema title mismatch.' }

$preflightResult = Invoke-JsonChild -PowerShellPath $powerShellPath -ExecutorPath $executorPath -RequestPath $requestPath -ModeArguments @('-Preflight')
if ([string]$preflightResult.state -cne 'PASS_ARGOS_DIRECT_OBSERVER_PREFLIGHT') { throw 'Executor preflight did not pass.' }
$preflightCaseIds = @($preflightResult.cases | ForEach-Object { [string]$_.caseId } | Sort-Object)
if (($preflightCaseIds -join ',') -cne 'ERROR,MANY,ONE,TIMEOUT,ZERO') { throw 'Executor preflight case set mismatch.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_direct_observer_test_preflight_v1'
        state = 'PASS_ARGOS_DIRECT_OBSERVER_TEST_PREFLIGHT'
        invocationPath = $resolvedInvocationPath
        executorSha256 = [string]$invocation.executor.sha256
        requestSha256 = [string]$preflightResult.requestSha256
        requestSchemaSha256 = [string]$invocation.requestSchema.sha256
        resultSchemaSha256 = [string]$invocation.resultSchema.sha256
        caseIds = $preflightCaseIds
        targetQueryPerformed = $false
        gateWritten = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}

$gatePath = [string]$invocation.gatePath
if (-not [IO.Path]::IsPathRooted($gatePath)) { $gatePath = Join-Path $projectRoot $gatePath.Replace('/', '\') }
$gatePath = [IO.Path]::GetFullPath($gatePath)
if (Test-Path -LiteralPath $gatePath) { throw "Create-new test gate already exists: $gatePath" }

$rehearsalRows = New-Object 'System.Collections.Generic.List[object]'
foreach ($caseId in @('ZERO','ONE','MANY','ERROR','TIMEOUT')) {
    $result = Invoke-JsonChild -PowerShellPath $powerShellPath -ExecutorPath $executorPath -RequestPath $requestPath -ModeArguments @('-Rehearsal','-RehearsalCase',$caseId)
    $expectedState = if ($caseId -eq 'ERROR' -or $caseId -eq 'TIMEOUT') { 'FAIL_ARGOS_DIRECT_OBSERVATION' } else { 'PASS_ARGOS_DIRECT_OBSERVATION' }
    if ([string]$result.state -cne $expectedState) { throw "Unexpected $caseId rehearsal state." }
    $rehearsalRows.Add([pscustomobject][ordered]@{
        caseId = $caseId
        state = [string]$result.state
        operationState = [string]$result.operationState
        rowCount = @($result.rows).Count
        safetyFieldsFalse = (-not [bool]$result.taskOrProcessManagementPerformed -and -not [bool]$result.imageBytesRead -and -not [bool]$result.targetPersistentMutationPerformed)
    })
}

$liveResult = Invoke-JsonChild -PowerShellPath $powerShellPath -ExecutorPath $executorPath -RequestPath $requestPath -ModeArguments @('-Execute')
if ([string]$liveResult.state -cne 'PASS_ARGOS_DIRECT_OBSERVATION') { throw 'Local live-provider execution did not pass.' }
if ([string]$liveResult.operationState -cne 'OBSERVED') { throw 'Local live-provider operation state mismatch.' }
if ([string]$liveResult.scalar -cne [string]$invocation.expectedScalar) { throw 'Local live-provider scalar mismatch.' }
if ([int]$liveResult.exactMatchCount -ne 1 -or @($liveResult.rows).Count -ne 1) { throw 'Local live-provider exact-match cardinality is not one.' }
if ([string]$liveResult.rows[0].commandLine -notlike '*Invoke-ArgosDirectObservation.ps1*') { throw 'Local live-provider command line did not prove the exact executor.' }
if ([bool]$liveResult.taskOrProcessManagementPerformed -or [bool]$liveResult.imageBytesRead -or [bool]$liveResult.targetPersistentMutationPerformed) { throw 'Local live-provider safety assertion failed.' }

$gateResult = [ordered]@{
    schema = 'argos_direct_observer_local_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_DIRECT_OBSERVER_LOCAL_SCHEMA_AND_PROVIDER_GATE'
    invocationManifestSha256 = Get-Sha256File -Path $resolvedInvocationPath
    executorSha256 = [string]$invocation.executor.sha256
    requestSha256 = [string]$preflightResult.requestSha256
    requestSchemaSha256 = [string]$invocation.requestSchema.sha256
    resultSchemaSha256 = [string]$invocation.resultSchema.sha256
    preflightCaseIds = $preflightCaseIds
    rehearsals = @($rehearsalRows.ToArray())
    liveProvider = [ordered]@{
        executionCount = 1
        state = [string]$liveResult.state
        operationState = [string]$liveResult.operationState
        operationTimeoutSeconds = [int]$liveResult.operationTimeoutSeconds
        candidateProcessCount = [int]$liveResult.candidateProcessCount
        exactExecutablePathProcessCount = [int]$liveResult.exactExecutablePathProcessCount
        exactMatchCount = [int]$liveResult.exactMatchCount
        observedProcessId = [uint32]$liveResult.rows[0].processId
        exactExecutorCommandLineObserved = $true
    }
    clipboardChanged = $false
    remoteInputSent = $false
    taskOrProcessManagementPerformed = $false
    imageBytesRead = $false
    sourceMutationPerformed = $false
    targetPersistentMutationPerformed = $false
    providerActivationPerformed = $false
    productionRoutingEnabled = $false
}
$json = $gateResult | ConvertTo-Json -Depth 8
$parent = Split-Path -Parent $gatePath
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "Gate parent is absent: $parent" }
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
$stream = [IO.File]::Open($gatePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($bytes, 0, $bytes.Length) }
finally { $stream.Dispose() }
$json
