#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-O3F10([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-O3F10Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-O3F10Pin([string]$Path, [string]$Sha256, [string]$Label) {
    Assert-O3F10 (Test-Path -LiteralPath $Path -PathType Leaf) "O3F10 $Label is absent: $Path"
    Assert-O3F10 ((Get-O3F10Hash $Path) -eq $Sha256) "O3F10 $Label hash changed: $Path"
}

function Assert-O3F10Path([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $maximum = 0
    if ($parts.Count -gt 0) { $maximum = [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) }
    Assert-O3F10 (($full.Length + 32) -lt 200) "O3F10 path budget failed: $full"
    Assert-O3F10 ($maximum -le 80) "O3F10 path component budget failed: $full"
}

function Test-O3F10Property([object]$Value, [string]$Name) {
    return $null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name]
}

function Get-O3F10Property([object]$Value, [string]$Name, [object]$Default = $null) {
    if (Test-O3F10Property $Value $Name) { return $Value.$Name }
    return $Default
}

function Invoke-O3F10OwnedChild(
    [string]$Executable,
    [string]$WorkingDirectory,
    [string[]]$Arguments,
    [int]$TimeoutSeconds,
    [int]$MaximumOutputBytes
) {
    foreach ($value in @($Executable, $WorkingDirectory) + @($Arguments)) {
        Assert-O3F10 (-not [string]::IsNullOrWhiteSpace($value)) 'O3F10 child argument is empty.'
        Assert-O3F10 ($value.IndexOfAny([char[]]@('"', "`r", "`n")) -lt 0) 'O3F10 child argument contains a forbidden character.'
    }
    $quoted = @($Arguments | ForEach-Object { '"' + $_ + '"' })
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $Executable
    $info.Arguments = [string]::Join(' ', $quoted)
    $info.WorkingDirectory = $WorkingDirectory
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $info.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $info.EnvironmentVariables['PYTHONUTF8'] = '1'
    $child = New-Object Diagnostics.Process
    $child.StartInfo = $info
    Assert-O3F10 $child.Start() 'O3F10 owned child did not start.'
    $identifier = [int]$child.Id
    $startedUtc = $child.StartTime.ToUniversalTime().ToString('o')
    $stdoutTask = $child.StandardOutput.ReadToEndAsync()
    $stderrTask = $child.StandardError.ReadToEndAsync()
    $timedOut = -not $child.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $child.Kill() } catch { }
        $child.WaitForExit()
    }
    $stdout = [string]$stdoutTask.Result
    $stderr = [string]$stderrTask.Result
    $exitCode = [int]$child.ExitCode
    $child.Dispose()
    $combinedBytes = [Text.Encoding]::UTF8.GetByteCount($stdout) + [Text.Encoding]::UTF8.GetByteCount($stderr)
    Assert-O3F10 ($combinedBytes -le $MaximumOutputBytes) 'O3F10 owned-child output exceeded its bound.'
    return [ordered]@{
        processId = $identifier
        startedUtc = $startedUtc
        timedOut = $timedOut
        exitCode = $exitCode
        stdout = $stdout
        stderr = $stderr
        outputBytes = $combinedBytes
    }
}

function ConvertTo-O3F10ChildJson([object]$Child, [string]$Label) {
    Assert-O3F10 (-not [bool]$Child.timedOut) "O3F10 $Label child timed out."
    Assert-O3F10 ([int]$Child.exitCode -eq 0) ("O3F10 $Label child failed: " + ([string]$Child.stderr).Trim())
    Assert-O3F10 ([Text.Encoding]::UTF8.GetByteCount([string]$Child.stderr) -eq 0) "O3F10 $Label child wrote stderr."
    try { return (([string]$Child.stdout).Trim() | ConvertFrom-Json) }
    catch { throw "O3F10 $Label child stdout is not one bounded JSON object." }
}

function Get-O3F10EligibleCorrespondence([object]$Symmetric) {
    $rows = New-Object Collections.Generic.List[object]
    foreach ($hypothesis in @(Get-O3F10Property $Symmetric 'eligibleHypotheses' @())) {
        $correspondence = Get-O3F10Property $hypothesis 'correspondence' $null
        $rows.Add([pscustomobject]@{
            hypothesisId = [string](Get-O3F10Property $hypothesis 'hypothesisId' '')
            direction = [string](Get-O3F10Property $hypothesis 'direction' '')
            correspondenceMethod = [string](Get-O3F10Property $correspondence 'correspondenceMethod' '')
            centerGapDegrees = Get-O3F10Property $correspondence 'centerGapDegrees' $null
            mouthIntervalOverlapDegrees = Get-O3F10Property $correspondence 'mouthIntervalOverlapDegrees' $null
        })
    }
    Assert-O3F10 ($rows.Count -le 128) 'O3F10 eligible-hypothesis projection exceeded its bound.'
    return $rows.ToArray()
}

function Get-O3F10Dev6Projection([object]$Summary, [string]$DevRoot) {
    $rows = New-Object Collections.Generic.List[object]
    foreach ($result in @(Get-O3F10Property $Summary 'results' @())) {
        $manifest = $null
        $observed = $null
        $errorText = [string](Get-O3F10Property $result 'error' '')
        if ([string](Get-O3F10Property $result 'execution' '') -like 'PASS_*') {
            $manifestPath = [IO.Path]::GetFullPath([string](Get-O3F10Property $result 'manifestPath' ''))
            $devPrefix = [IO.Path]::GetFullPath($DevRoot).TrimEnd('\') + '\'
            Assert-O3F10 ($manifestPath.StartsWith($devPrefix, [StringComparison]::OrdinalIgnoreCase)) 'O3F10 DEV6 manifest escaped its result root.'
            Assert-O3F10Pin $manifestPath ([string](Get-O3F10Property $result 'manifestSha256' '')) 'DEV6 case manifest'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            Assert-O3F10 (@($manifest.results).Count -eq 1) 'O3F10 DEV6 case manifest cardinality changed.'
            $observed = @($manifest.results)[0]
        }
        $symmetric = Get-O3F10Property $observed 'r10SymmetricRecovery' $null
        $dfSeeded = Get-O3F10Property $observed 'o3p8DfSeededLocalBfRecovery' $null
        $bfSeeded = Get-O3F10Property $observed 'bfSeededLocalDfRecovery' $null
        $selected = Get-O3F10Property $symmetric 'selectedCluster' $null
        $rows.Add([pscustomobject]@{
            identity = [string](Get-O3F10Property $result 'identity' '')
            safeId = [string](Get-O3F10Property $result 'safeId' '')
            priorR8State = [string](Get-O3F10Property $result 'priorR8State' '')
            baselineR8State = [string](Get-O3F10Property $observed 'baselineR8State' '')
            inheritedR9State = [string](Get-O3F10Property $observed 'inheritedR9State' '')
            finalState = [string](Get-O3F10Property $observed 'state' (Get-O3F10Property $result 'state' ''))
            r10Invoked = [bool](Get-O3F10Property $symmetric 'invoked' $false)
            physicalClusterCount = @((Get-O3F10Property $symmetric 'physicalClusters' @())).Count
            selectedClusterDirections = @((Get-O3F10Property $selected 'directions' @()))
            dfSeedCount = [int](Get-O3F10Property $dfSeeded 'seedCount' 0)
            dfHypothesisCount = @((Get-O3F10Property $dfSeeded 'seeds' @())).Count
            dfEligibleCount = @((Get-O3F10Property $dfSeeded 'eligibleSeedIndices' @())).Count
            bfSeedCount = [int](Get-O3F10Property $bfSeeded 'seedCount' 0)
            bfHypothesisCount = [int](Get-O3F10Property $bfSeeded 'hypothesisCount' 0)
            bfEligibleCount = @((Get-O3F10Property $bfSeeded 'eligibleHypothesisIndices' @())).Count
            eligibleHypothesisCount = @((Get-O3F10Property $symmetric 'eligibleHypotheses' @())).Count
            eligibleCorrespondence = @(Get-O3F10EligibleCorrespondence $symmetric)
            error = $errorText
        })
    }
    Assert-O3F10 ($rows.Count -eq 6) 'O3F10 DEV6 projection is not exactly six cases.'
    return $rows.ToArray()
}

$manifestPath = $InvocationManifest
if ([string]::IsNullOrWhiteSpace($manifestPath)) { $manifestPath = Join-Path $PSScriptRoot 'O3F10_ENDPOINT_LIVE_INVOCATION.json' }
$manifestPath = [IO.Path]::GetFullPath($manifestPath)
Assert-O3F10 (Test-Path -LiteralPath $manifestPath -PathType Leaf) "O3F10 invocation manifest is absent: $manifestPath"
$invoke = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedState = if ($Rehearsal) { 'FROZEN_REHEARSAL_CONTRACT' } else { 'FROZEN_LIVE_CONTRACT' }
Assert-O3F10 ([string]$invoke.schema -eq 'argos_ocv03_o3f10_endpoint_invocation_v1' -and [string]$invoke.state -eq $expectedState) 'O3F10 invocation schema/state changed.'
Assert-O3F10 ([string]$invoke.endpointSha256 -eq (Get-O3F10Hash $PSCommandPath)) 'O3F10 invocation does not pin the exact endpoint.'
Assert-O3F10 ($env:COMPUTERNAME.Equals([string]$invoke.expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O3F10 wrong computer: $env:COMPUTERNAME"
Assert-O3F10 ([bool]$invoke.detectorDevelopmentAuthorized -and -not [bool]$invoke.taskOrExistingProcessActionAuthorized -and -not [bool]$invoke.sourceMutationAuthorized -and -not [bool]$invoke.sourceDeletionAuthorized -and -not [bool]$invoke.providerActivationAuthorized -and -not [bool]$invoke.requestRetryAuthorized) 'O3F10 authority widened.'
Assert-O3F10 ([bool]$invoke.reviewOnly -and -not [bool]$invoke.trainingEligible -and -not [bool]$invoke.xmlEligible -and -not [bool]$invoke.productionEligible -and -not [bool]$invoke.productionRoutingEnabled) 'O3F10 eligibility widened.'

$payloadRoot = if ([string]::IsNullOrWhiteSpace([string]$invoke.payloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath([string]$invoke.payloadRoot) }
$fileByRole = @{}
foreach ($record in @($invoke.files)) {
    $relative = [string]$record.path
    Assert-O3F10 (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3F10 payload-relative path is unsafe.'
    $path = [IO.Path]::GetFullPath((Join-Path $payloadRoot $relative))
    $payloadPrefix = $payloadRoot.TrimEnd('\') + '\'
    Assert-O3F10 ($path.StartsWith($payloadPrefix, [StringComparison]::OrdinalIgnoreCase)) 'O3F10 payload file escaped its root.'
    Assert-O3F10Pin $path ([string]$record.sha256) ([string]$record.role)
    Assert-O3F10 ((Get-Item -LiteralPath $path).Length -eq [int64]$record.bytes) "O3F10 payload byte count changed: $relative"
    Assert-O3F10Path $path
    $fileByRole[[string]$record.role] = $path
}
foreach ($role in @('runner', 'baseRunner', 'r10Detector', 'r9Detector', 'r8Detector', 'o3p8Detector', 'localGate', 'o3p8Job', 'canonicalJob', 'protocolAnchor', 'rehearsalRunner')) {
    Assert-O3F10 ($fileByRole.ContainsKey($role)) "O3F10 required payload role is absent: $role"
}

$runtimePath = [IO.Path]::GetFullPath([string]$(if ($Rehearsal) { $invoke.rehearsalRuntimePath } else { $invoke.runtimePath }))
$runtimeSha256 = [string]$(if ($Rehearsal) { $invoke.rehearsalRuntimeSha256 } else { $invoke.runtimeSha256 })
Assert-O3F10Pin $runtimePath $runtimeSha256 'runtime executable'
$gateRoot = [IO.Path]::GetFullPath([string]$invoke.gateOutputRoot)
$devRoot = [IO.Path]::GetFullPath([string]$invoke.dev6OutputRoot)
$gateSummary = Join-Path $gateRoot 'SUMMARY.json'
$devSummary = Join-Path $devRoot 'SUMMARY.json'
foreach ($path in @($gateRoot, ($gateRoot + '.partial'), ($gateRoot + '.failed'), $gateSummary, $devRoot, ($devRoot + '.partial'), ($devRoot + '.failed'), $devSummary)) { Assert-O3F10Path $path }
Assert-O3F10 (-not (Test-Path -LiteralPath $gateRoot)) "O3F10 create-new gate root exists: $gateRoot"
Assert-O3F10 (-not (Test-Path -LiteralPath $devRoot)) "O3F10 create-new DEV6 root exists: $devRoot"
Assert-O3F10 (-not (Test-Path -LiteralPath ($gateRoot + '.failed'))) "O3F10 create-new gate quarantine exists: $gateRoot.failed"
Assert-O3F10 (-not (Test-Path -LiteralPath ($devRoot + '.failed'))) "O3F10 create-new DEV6 quarantine exists: $devRoot.failed"
Assert-O3F10 (Test-Path -LiteralPath (Split-Path -Parent $gateRoot) -PathType Container) 'O3F10 gate parent is absent.'
Assert-O3F10 ((Split-Path -Parent $gateRoot).Equals((Split-Path -Parent $devRoot), [StringComparison]::OrdinalIgnoreCase)) 'O3F10 output parents differ.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f10_endpoint_preflight_v1'
        state = 'PASS_O3F10_ENDPOINT_PREFLIGHT'
        rehearsal = [bool]$Rehearsal
        payloadFileCount = @($invoke.files).Count
        gateOutputRoot = $gateRoot
        dev6OutputRoot = $devRoot
        plannedStages = @('SELF_TEST', 'PREFLIGHT', 'GATE', 'DEV6')
        sourceImageBytesRead = $false
        outputCreated = $false
        mutationsPerformed = $false
        taskActionCount = 0
        existingProcessActionCount = 0
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

try {
  $maximumOutputBytes = [int]$invoke.maximumChildOutputBytes
  $selfTestRunner = [string]$fileByRole['runner']
  $selfTestChild = Invoke-O3F10OwnedChild $runtimePath (Split-Path -Parent $selfTestRunner) @('-I', '-B', $selfTestRunner, 'SELF_TEST') ([int]$invoke.selfTestTimeoutSeconds) $maximumOutputBytes
$selfTest = ConvertTo-O3F10ChildJson $selfTestChild 'SELF_TEST'
Assert-O3F10 ([string]$selfTest.state -eq [string]$invoke.expectedSelfTestState -and -not [bool]$selfTest.mutationsPerformed) 'O3F10 SELF_TEST state or mutation contract changed.'
$runner = [string]$(if ($Rehearsal) { $fileByRole['rehearsalRunner'] } else { $fileByRole['runner'] })
$workingDirectory = Split-Path -Parent $runner

$runnerPreflightChild = Invoke-O3F10OwnedChild $runtimePath $workingDirectory @('-I', '-B', $runner, 'PREFLIGHT') ([int]$invoke.preflightTimeoutSeconds) $maximumOutputBytes
$runnerPreflight = ConvertTo-O3F10ChildJson $runnerPreflightChild 'PREFLIGHT'
Assert-O3F10 ([string]$runnerPreflight.state -eq [string]$invoke.expectedPreflightState -and -not [bool]$runnerPreflight.mutationsPerformed) 'O3F10 runner PREFLIGHT state changed.'

$gateChild = Invoke-O3F10OwnedChild $runtimePath $workingDirectory @('-I', '-B', $runner, 'GATE', '--output-root', $gateRoot) ([int]$invoke.gateTimeoutSeconds) $maximumOutputBytes
$gateTerminal = ConvertTo-O3F10ChildJson $gateChild 'GATE'
Assert-O3F10 ([string]$gateTerminal.state -eq [string]$invoke.expectedGateState -and [string]$gateTerminal.stage -eq 'GATE') 'O3F10 GATE state changed.'
Assert-O3F10Pin $gateSummary ([string]$gateTerminal.summarySha256) 'GATE summary'

$devChild = Invoke-O3F10OwnedChild $runtimePath $workingDirectory @('-I', '-B', $runner, 'DEV6', '--output-root', $devRoot, '--prerequisite-summary', $gateSummary, '--prerequisite-sha256', ([string]$gateTerminal.summarySha256)) ([int]$invoke.dev6TimeoutSeconds) $maximumOutputBytes
$devTerminal = ConvertTo-O3F10ChildJson $devChild 'DEV6'
Assert-O3F10 ([string]$devTerminal.state -eq [string]$invoke.expectedDev6State -and [string]$devTerminal.stage -eq 'DEV6' -and [int]$devTerminal.selectedCount -eq 6) 'O3F10 DEV6 completion identity changed.'
Assert-O3F10Pin $devSummary ([string]$devTerminal.summarySha256) 'DEV6 summary'
$devSummaryValue = Get-Content -LiteralPath $devSummary -Raw | ConvertFrom-Json
$projection = @(Get-O3F10Dev6Projection $devSummaryValue $devRoot)

$terminal = [ordered]@{
    schema = 'argos_ocv03_o3f10_staged_endpoint_result_v1'
    state = 'COMPLETE_O3F10_GATE_AND_DEV6_REVIEW_ONLY'
    revision = [string]$invoke.revision
    rehearsal = [bool]$Rehearsal
    stages = @('SELF_TEST', 'PREFLIGHT', 'GATE', 'DEV6')
    selfTest = [ordered]@{
        state = [string]$selfTest.state
        mutationsPerformed = [bool]$selfTest.mutationsPerformed
        runnerSha256 = Get-O3F10Hash $selfTestRunner
    }
    gate = [ordered]@{
        state = [string]$gateTerminal.state
        summaryPath = $gateSummary
        summarySha256 = [string]$gateTerminal.summarySha256
    }
    dev6 = [ordered]@{
        state = [string]$devTerminal.state
        summaryPath = $devSummary
        summarySha256 = [string]$devTerminal.summarySha256
        selectedCount = [int]$devTerminal.selectedCount
        executedCount = [int]$devTerminal.executedCount
        preservedProviderHoldCount = [int]$devTerminal.preservedProviderHoldCount
        newProviderHoldCount = [int]$devTerminal.newProviderHoldCount
        stateCounts = $devTerminal.stateCounts
        cases = $projection
    }
    childProcessIds = @([int]$selfTestChild.processId, [int]$runnerPreflightChild.processId, [int]$gateChild.processId, [int]$devChild.processId)
    ownedChildCount = 4
    sourceImageBytesRead = (-not [bool]$Rehearsal)
    existingProcessQueryCount = 0
    taskActionCount = 0
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    providerActivated = $false
    requestRetryAuthorized = $false
    holdsAutomaticallyCleared = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
$terminalJson = $terminal | ConvertTo-Json -Depth 24 -Compress
Assert-O3F10 ([Text.Encoding]::UTF8.GetByteCount($terminalJson) -le [int]$invoke.maximumTerminalOutputBytes) 'O3F10 terminal projection exceeded its bound.'
  $terminalJson
} catch {
  foreach ($pair in @(@($devRoot, ($devRoot + '.failed')), @($gateRoot, ($gateRoot + '.failed')))) {
    if (Test-Path -LiteralPath $pair[0]) {
      Assert-O3F10 (-not (Test-Path -LiteralPath $pair[1])) "O3F10 failure quarantine collision: $($pair[1])"
      Move-Item -LiteralPath $pair[0] -Destination $pair[1]
    }
  }
  throw
}
