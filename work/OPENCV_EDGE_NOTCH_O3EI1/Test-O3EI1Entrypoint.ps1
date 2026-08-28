[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of Preflight or Gate.' }

function Resolve-ProjectPath([string]$Root, [string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.IndexOfAny([char[]]'*?') -ge 0) { throw 'Unsafe O3EI1 control path.' }
    return $(if ([IO.Path]::IsPathRooted($Value)) { [IO.Path]::GetFullPath($Value) } else { [IO.Path]::GetFullPath((Join-Path $Root $Value)) })
}
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha) { if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Sha $Path) -ne $Sha) { throw "O3EI1 pinned dependency changed: $Path" } }

$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$controlPath = Resolve-ProjectPath $projectRoot $InvocationManifest
$control = Get-Content -LiteralPath $controlPath -Raw | ConvertFrom-Json
if ([string]$control.schema -ne 'argos_o3ei1_entrypoint_test_control_v1' -or [string]$control.state -ne 'FROZEN_TEST_INPUT' -or -not [bool]$control.reviewOnly -or [bool]$control.productionRoutingEnabled) { throw 'O3EI1 test control changed.' }
$provider = Resolve-ProjectPath $projectRoot ([string]$control.providerPath)
$entrypoint = Resolve-ProjectPath $projectRoot ([string]$control.entrypointPath)
$fixedInvocation = Resolve-ProjectPath $projectRoot ([string]$control.fixedInvocationPath)
$timeoutInvocation = Resolve-ProjectPath $projectRoot ([string]$control.timeoutInvocationPath)
$errorInvocation = Resolve-ProjectPath $projectRoot ([string]$control.errorInvocationPath)
$malformedInvocation = Resolve-ProjectPath $projectRoot ([string]$control.malformedInvocationPath)
$okInvocation = Resolve-ProjectPath $projectRoot ([string]$control.okEntrypointInvocationPath)
$failureInvocation = Resolve-ProjectPath $projectRoot ([string]$control.failureEntrypointInvocationPath)
$fixtureRoot = [IO.Path]::GetFullPath([string]$control.fixtureRoot)
$gateOutput = Resolve-ProjectPath $projectRoot ([string]$control.gateOutputPath)
foreach ($pin in @(
    @($provider, [string]$control.providerSha256),
    @($entrypoint, [string]$control.entrypointSha256),
    @($fixedInvocation, [string]$control.fixedInvocationSha256),
    @($timeoutInvocation, [string]$control.timeoutInvocationSha256),
    @($errorInvocation, [string]$control.errorInvocationSha256),
    @($malformedInvocation, [string]$control.malformedInvocationSha256),
    @($okInvocation, [string]$control.okEntrypointInvocationSha256),
    @($failureInvocation, [string]$control.failureEntrypointInvocationSha256)
)) { Assert-Pin $pin[0] $pin[1] }
if (Test-Path -LiteralPath $fixtureRoot) { throw 'O3EI1 fresh fixture root already exists.' }
if (Test-Path -LiteralPath $gateOutput) { throw 'O3EI1 gate output already exists.' }

$providerPreflight = (& $provider -Preflight -Rehearsal -InvocationManifest $fixedInvocation) | ConvertFrom-Json
if ([string]$providerPreflight.state -ne 'PASS_O3EI1_RUNTIME_PROBE_PREFLIGHT' -or [bool]$providerPreflight.childProcessStarted -or [bool]$providerPreflight.mutationsPerformed) { throw 'O3EI1 provider preflight failed.' }
$entrypointPreflight = (& $entrypoint -Preflight -InvocationManifest $okInvocation) | ConvertFrom-Json
if ([string]$entrypointPreflight.state -ne 'PASS_O3EI1_ENTRYPOINT_PREFLIGHT' -or [bool]$entrypointPreflight.childProcessStarted -or [bool]$entrypointPreflight.mutationsPerformed) { throw 'O3EI1 entrypoint preflight failed.' }
if ($Preflight) {
    [ordered]@{schema='argos_o3ei1_entrypoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_ENTRYPOINT_TEST_PREFLIGHT';fixtureRoot=$fixtureRoot;gateOutput=$gateOutput;mutationsPerformed=$false;childProcessStarted=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'ok'))
[void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'fail'))
$fixed = (& $provider -Observe -Rehearsal -InvocationManifest $fixedInvocation) | ConvertFrom-Json
if ([string]$fixed.state -ne 'PASS_O3EI1_RUNTIME_PREMISE' -or -not [bool]$fixed.runtimePremisePass -or [bool]$fixed.child.timedOut) { throw 'O3EI1 fixed rehearsal failed.' }
$timer = [Diagnostics.Stopwatch]::StartNew()
$timeout = (& $provider -Observe -Rehearsal -InvocationManifest $timeoutInvocation) | ConvertFrom-Json
$timer.Stop()
if ([string]$timeout.state -ne 'HOLD_O3EI1_RUNTIME_TIMEOUT' -or -not [bool]$timeout.child.timedOut -or -not [bool]$timeout.child.killedOnTimeout -or $timer.Elapsed.TotalSeconds -gt 8) { throw 'O3EI1 timeout isolation failed.' }
$errorResult = (& $provider -Observe -Rehearsal -InvocationManifest $errorInvocation) | ConvertFrom-Json
if ([string]$errorResult.state -ne 'HOLD_O3EI1_RUNTIME_ERROR' -or [int]$errorResult.child.exitCode -ne 23) { throw 'O3EI1 error isolation failed.' }
$malformed = (& $provider -Observe -Rehearsal -InvocationManifest $malformedInvocation) | ConvertFrom-Json
if ([string]$malformed.state -ne 'HOLD_O3EI1_RUNTIME_MALFORMED') { throw 'O3EI1 malformed-output isolation failed.' }

$failureCaptured = $false
try { [void](& $entrypoint -Rehearsal -InvocationManifest $failureInvocation) }
catch { $failureCaptured = [string]$_.Exception.Message -match 'INJECTED_O3EI1_ENTRYPOINT_FAILURE_AFTER_PROVIDER' }
if (-not $failureCaptured -or (Test-Path -LiteralPath (Join-Path $fixtureRoot 'fail\OCV03_O3EI1_RUNTIME_STATUS.json'))) { throw 'O3EI1 entrypoint injected-failure boundary failed.' }
$success = (& $entrypoint -Rehearsal -InvocationManifest $okInvocation) | ConvertFrom-Json
if ([string]$success.state -ne 'PASS_O3EI1_RUNTIME_CAPABILITY' -or [string]$success.disposition -ne 'PASS_O3EI1_RUNTIME_PREMISE' -or -not [bool]$success.runtimePremisePass) { throw 'O3EI1 entrypoint success rehearsal failed.' }
$outputPath = Join-Path $fixtureRoot 'ok\OCV03_O3EI1_RUNTIME_STATUS.json'
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf) -or (Get-Sha $outputPath) -ne [string]$success.capabilityOutputSha256) { throw 'O3EI1 producer output evidence changed.' }

$record = [ordered]@{
    schema = 'argos_o3ei1_entrypoint_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3EI1_ENTRYPOINT_GATE'
    lifecycle = 'FROZEN_LOCAL_EVIDENCE'
    providerSha256 = [string]$control.providerSha256
    entrypointSha256 = [string]$control.entrypointSha256
    controlSha256 = Get-Sha $controlPath
    fixedState = [string]$fixed.state
    timeoutState = [string]$timeout.state
    timeoutMilliseconds = [int]$timeout.child.timeoutMilliseconds
    timeoutElapsedMilliseconds = [int][Math]::Ceiling($timer.Elapsed.TotalMilliseconds)
    timeoutChildKilled = [bool]$timeout.child.killedOnTimeout
    errorState = [string]$errorResult.state
    malformedState = [string]$malformed.state
    injectedFailureCaptured = $failureCaptured
    outputWrittenAfterProducerSuccess = $true
    taskActions = 0
    existingProcessActions = 0
    boundedOwnedChildTests = 5
    imageBytesRead = $false
    sourceMutationPerformed = $false
    jbodContacted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
[IO.File]::WriteAllText($gateOutput, (($record | ConvertTo-Json -Depth 10) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
[ordered]@{schema='argos_o3ei1_entrypoint_gate_result_v1';state='PASS_O3EI1_ENTRYPOINT_GATE';gateOutput=$gateOutput;gateSha256=Get-Sha $gateOutput;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 5
