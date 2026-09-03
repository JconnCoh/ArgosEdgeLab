#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-O3F13([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-O3F13Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-O3F13Pin([string]$Path, [string]$Sha256, [string]$Label) {
    Assert-O3F13 (Test-Path -LiteralPath $Path -PathType Leaf) "O3F13 $Label is absent: $Path"
    Assert-O3F13 ((Get-O3F13Hash $Path) -eq $Sha256) "O3F13 $Label hash changed: $Path"
}

function Assert-O3F13Path([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $maximum = 0
    if ($parts.Count -gt 0) { $maximum = [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) }
    Assert-O3F13 (($full.Length + 32) -lt 200) "O3F13 path budget failed: $full"
    Assert-O3F13 ($maximum -le 80) "O3F13 path component budget failed: $full"
}

function Get-O3F13SubstTarget([string]$SubstPath, [string]$Drive) {
    $rows = @(& $SubstPath)
    Assert-O3F13 ($LASTEXITCODE -eq 0) 'O3F13 subst inventory query failed.'
    $prefix = $Drive + '\: => '
    $matches = @($rows | Where-Object { ([string]$_).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
    Assert-O3F13 ($matches.Count -le 1) "O3F13 subst returned multiple mappings for $Drive"
    if ($matches.Count -eq 0) { return $null }
    return ([string]$matches[0]).Substring($prefix.Length).Trim().TrimEnd('\')
}

function Assert-O3F13AliasAbsent([string]$SubstPath, [string]$Drive) {
    $target = Get-O3F13SubstTarget $SubstPath $Drive
    $name = $Drive.Substring(0, 1)
    Assert-O3F13 ($null -eq $target -and -not (Test-Path -LiteralPath ($Drive + '\')) -and $null -eq (Get-PSDrive -Name $name -ErrorAction SilentlyContinue)) "O3F13 temporary alias is occupied: $Drive"
}

function Invoke-O3F13AliasCleanupBackstop([string]$SubstPath, [string]$Drive, [string[]]$AllowedTargets) {
    $target = Get-O3F13SubstTarget $SubstPath $Drive
    if ($null -eq $target) {
        Assert-O3F13AliasAbsent $SubstPath $Drive
        return [ordered]@{aliasDrive=$Drive;mappingObserved=$false;removedByBackstop=$false;verifiedAbsent=$true;matchedAllowedTarget=$false}
    }
    $targetFull = [IO.Path]::GetFullPath($target).TrimEnd('\')
    $matching = @($AllowedTargets | Where-Object { [IO.Path]::GetFullPath([string]$_).TrimEnd('\').Equals($targetFull, [StringComparison]::OrdinalIgnoreCase) })
    Assert-O3F13 ($matching.Count -eq 1) "O3F13 refuses to remove unowned or mismatched Q: mapping: $target"
    $removeRows = @(& $SubstPath $Drive '/D')
    Assert-O3F13 ($LASTEXITCODE -eq 0) ("O3F13 endpoint alias cleanup failed: " + ([string]::Join(' ', @($removeRows))).Trim())
    Assert-O3F13AliasAbsent $SubstPath $Drive
    return [ordered]@{aliasDrive=$Drive;mappingObserved=$true;removedByBackstop=$true;verifiedAbsent=$true;matchedAllowedTarget=$true;removedTarget=$targetFull}
}

function Test-O3F13Property([object]$Value, [string]$Name) {
    return $null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name]
}

function Get-O3F13Property([object]$Value, [string]$Name, [object]$Default = $null) {
    if (Test-O3F13Property $Value $Name) { return $Value.$Name }
    return $Default
}

function Invoke-O3F13OwnedChild(
    [string]$Executable,
    [string]$WorkingDirectory,
    [string[]]$Arguments,
    [int]$TimeoutSeconds,
    [int]$MaximumOutputBytes
) {
    foreach ($value in @($Executable, $WorkingDirectory) + @($Arguments)) {
        Assert-O3F13 (-not [string]::IsNullOrWhiteSpace($value)) 'O3F13 child argument is empty.'
        Assert-O3F13 ($value.IndexOfAny([char[]]@('"', "`r", "`n")) -lt 0) 'O3F13 child argument contains a forbidden character.'
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
    Assert-O3F13 $child.Start() 'O3F13 owned child did not start.'
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
    Assert-O3F13 ($combinedBytes -le $MaximumOutputBytes) 'O3F13 owned-child output exceeded its bound.'
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

function ConvertTo-O3F13ChildJson([object]$Child, [string]$Label) {
    Assert-O3F13 (-not [bool]$Child.timedOut) "O3F13 $Label child timed out."
    Assert-O3F13 ([int]$Child.exitCode -eq 0) ("O3F13 $Label child failed: " + ([string]$Child.stderr).Trim())
    Assert-O3F13 ([Text.Encoding]::UTF8.GetByteCount([string]$Child.stderr) -eq 0) "O3F13 $Label child wrote stderr."
    try { return (([string]$Child.stdout).Trim() | ConvertFrom-Json) }
    catch { throw "O3F13 $Label child stdout is not one bounded JSON object." }
}

function ConvertTo-O3F13Dev6ChildJson([object]$Child, [string]$PassState, [string]$HoldState) {
    Assert-O3F13 (-not [bool]$Child.timedOut) 'O3F13 DEV6 child timed out.'
    Assert-O3F13 ([Text.Encoding]::UTF8.GetByteCount([string]$Child.stderr) -eq 0) 'O3F13 DEV6 child wrote stderr.'
    $exitCode = [int]$Child.exitCode
    Assert-O3F13 ($exitCode -eq 0 -or $exitCode -eq 2) "O3F13 DEV6 child returned unsupported exit code $exitCode."
    try { $value = (([string]$Child.stdout).Trim() | ConvertFrom-Json) }
    catch { throw 'O3F13 DEV6 child stdout is not one bounded JSON object.' }
    Assert-O3F13 ($value -is [System.Management.Automation.PSCustomObject]) 'O3F13 DEV6 child stdout is not one JSON object.'
    $requiredState = if ($exitCode -eq 0) { $PassState } else { $HoldState }
    Assert-O3F13 ([string]$value.state -ceq $requiredState) "O3F13 DEV6 exit/state mapping changed for exit code $exitCode."
    return $value
}

function Assert-O3F13ExactPropertySet([object]$Value, [string[]]$Expected, [string]$Label) {
    $actual = @($Value.PSObject.Properties.Name | Sort-Object)
    $wanted = @($Expected | Sort-Object)
    Assert-O3F13 ($actual.Count -eq $wanted.Count -and [string]::Join('|', $actual) -ceq [string]::Join('|', $wanted)) "O3F13 $Label property set changed."
}

function Get-O3F13EligibleCorrespondence([object]$Symmetric) {
    $rows = New-Object Collections.Generic.List[object]
    foreach ($hypothesis in @(Get-O3F13Property $Symmetric 'eligibleHypotheses' @())) {
        $correspondence = Get-O3F13Property $hypothesis 'correspondence' $null
        $rows.Add([pscustomobject]@{
            hypothesisId = [string](Get-O3F13Property $hypothesis 'hypothesisId' '')
            direction = [string](Get-O3F13Property $hypothesis 'direction' '')
            correspondenceMethod = [string](Get-O3F13Property $correspondence 'correspondenceMethod' '')
            centerGapDegrees = Get-O3F13Property $correspondence 'centerGapDegrees' $null
            mouthIntervalOverlapDegrees = Get-O3F13Property $correspondence 'mouthIntervalOverlapDegrees' $null
        })
    }
    Assert-O3F13 ($rows.Count -le 128) 'O3F13 eligible-hypothesis projection exceeded its bound.'
    return $rows.ToArray()
}

function Get-O3F13Dev6Projection([object]$Summary, [string]$DevRoot) {
    $rows = New-Object Collections.Generic.List[object]
    foreach ($result in @(Get-O3F13Property $Summary 'results' @())) {
        $manifest = $null
        $observed = $null
        $errorText = [string](Get-O3F13Property $result 'error' '')
        if ([string](Get-O3F13Property $result 'execution' '') -like 'PASS_*') {
            $manifestPath = [IO.Path]::GetFullPath([string](Get-O3F13Property $result 'manifestPath' ''))
            $devPrefix = [IO.Path]::GetFullPath($DevRoot).TrimEnd('\') + '\'
            Assert-O3F13 ($manifestPath.StartsWith($devPrefix, [StringComparison]::OrdinalIgnoreCase)) 'O3F13 DEV6 manifest escaped its result root.'
            Assert-O3F13Pin $manifestPath ([string](Get-O3F13Property $result 'manifestSha256' '')) 'DEV6 case manifest'
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            Assert-O3F13 (@($manifest.results).Count -eq 1) 'O3F13 DEV6 case manifest cardinality changed.'
            $observed = @($manifest.results)[0]
        }
        $symmetric = Get-O3F13Property $observed 'r10SymmetricRecovery' $null
        $dfSeeded = Get-O3F13Property $observed 'o3p8DfSeededLocalBfRecovery' $null
        $bfSeeded = Get-O3F13Property $observed 'bfSeededLocalDfRecovery' $null
        $selected = Get-O3F13Property $symmetric 'selectedCluster' $null
        $rows.Add([pscustomobject]@{
            identity = [string](Get-O3F13Property $result 'identity' '')
            safeId = [string](Get-O3F13Property $result 'safeId' '')
            priorR8State = [string](Get-O3F13Property $result 'priorR8State' '')
            baselineR8State = [string](Get-O3F13Property $observed 'baselineR8State' '')
            inheritedR9State = [string](Get-O3F13Property $observed 'inheritedR9State' '')
            finalState = [string](Get-O3F13Property $observed 'state' (Get-O3F13Property $result 'finalState' (Get-O3F13Property $result 'state' '')))
            r10Invoked = [bool](Get-O3F13Property $symmetric 'invoked' $false)
            physicalClusterCount = @((Get-O3F13Property $symmetric 'physicalClusters' @())).Count
            selectedClusterDirections = @((Get-O3F13Property $selected 'directions' @()))
            dfSeedCount = [int](Get-O3F13Property $dfSeeded 'seedCount' 0)
            dfHypothesisCount = @((Get-O3F13Property $dfSeeded 'seeds' @())).Count
            dfEligibleCount = @((Get-O3F13Property $dfSeeded 'eligibleSeedIndices' @())).Count
            bfSeedCount = [int](Get-O3F13Property $bfSeeded 'seedCount' 0)
            bfHypothesisCount = [int](Get-O3F13Property $bfSeeded 'hypothesisCount' 0)
            bfEligibleCount = @((Get-O3F13Property $bfSeeded 'eligibleHypothesisIndices' @())).Count
            eligibleHypothesisCount = @((Get-O3F13Property $symmetric 'eligibleHypotheses' @())).Count
            eligibleCorrespondence = @(Get-O3F13EligibleCorrespondence $symmetric)
            error = $errorText
        })
    }
    Assert-O3F13 ($rows.Count -eq 6) 'O3F13 DEV6 projection is not exactly six cases.'
    return $rows.ToArray()
}

$manifestPath = $InvocationManifest
if ([string]::IsNullOrWhiteSpace($manifestPath)) { $manifestPath = Join-Path $PSScriptRoot 'O3F13_ENDPOINT_LIVE_INVOCATION.json' }
$manifestPath = [IO.Path]::GetFullPath($manifestPath)
Assert-O3F13 (Test-Path -LiteralPath $manifestPath -PathType Leaf) "O3F13 invocation manifest is absent: $manifestPath"
$invoke = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedState = if ($Rehearsal) { 'FROZEN_REHEARSAL_CONTRACT' } else { 'FROZEN_LIVE_CONTRACT' }
Assert-O3F13 ([string]$invoke.schema -eq 'argos_ocv03_o3f13_endpoint_invocation_v1' -and [string]$invoke.state -eq $expectedState) 'O3F13 invocation schema/state changed.'
Assert-O3F13 ([string]$invoke.endpointSha256 -eq (Get-O3F13Hash $PSCommandPath)) 'O3F13 invocation does not pin the exact endpoint.'
Assert-O3F13 ($env:COMPUTERNAME.Equals([string]$invoke.expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O3F13 wrong computer: $env:COMPUTERNAME"
Assert-O3F13 ([string]$invoke.expectedDev6PassState -ceq 'COMPLETE_O3F12_DEV6' -and [string]$invoke.expectedDev6HoldState -ceq 'HOLD_O3F12_DEV6_EXECUTION') 'O3F13 DEV6 exit/state contract changed.'
Assert-O3F13 ([bool]$invoke.detectorDevelopmentAuthorized -and -not [bool]$invoke.taskOrExistingProcessActionAuthorized -and -not [bool]$invoke.sourceMutationAuthorized -and -not [bool]$invoke.sourceDeletionAuthorized -and -not [bool]$invoke.providerActivationAuthorized -and -not [bool]$invoke.requestRetryAuthorized) 'O3F13 authority widened.'
Assert-O3F13 ([bool]$invoke.reviewOnly -and -not [bool]$invoke.trainingEligible -and -not [bool]$invoke.xmlEligible -and -not [bool]$invoke.productionEligible -and -not [bool]$invoke.productionRoutingEnabled) 'O3F13 eligibility widened.'

$payloadRoot = if ([string]::IsNullOrWhiteSpace([string]$invoke.payloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath([string]$invoke.payloadRoot) }
$fileByRole = @{}
foreach ($record in @($invoke.files)) {
    $relative = [string]$record.path
    Assert-O3F13 (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3F13 payload-relative path is unsafe.'
    $path = [IO.Path]::GetFullPath((Join-Path $payloadRoot $relative))
    $payloadPrefix = $payloadRoot.TrimEnd('\') + '\'
    Assert-O3F13 ($path.StartsWith($payloadPrefix, [StringComparison]::OrdinalIgnoreCase)) 'O3F13 payload file escaped its root.'
    Assert-O3F13Pin $path ([string]$record.sha256) ([string]$record.role)
    Assert-O3F13 ((Get-Item -LiteralPath $path).Length -eq [int64]$record.bytes) "O3F13 payload byte count changed: $relative"
    Assert-O3F13Path $path
    $fileByRole[[string]$record.role] = $path
}
foreach ($role in @('runner', 'baseRunner', 'r10Detector', 'r9Detector', 'r8Detector', 'o3p8Detector', 'localGate', 'o3p8Job', 'canonicalJob', 'protocolAnchor', 'rehearsalRunner', 'rootContractProbe', 'sourceAliasPlan')) {
    Assert-O3F13 ($fileByRole.ContainsKey($role)) "O3F13 required payload role is absent: $role"
}

$aliasDrive = [string]$invoke.sourceAliasDrive
$substPath = [IO.Path]::GetFullPath([string]$invoke.substPath)
Assert-O3F13 ($aliasDrive -ceq 'Q:') 'O3F13 source alias drive changed.'
Assert-O3F13Pin $substPath ([string]$invoke.substSha256) 'subst executable'
$aliasPlanPath = [string]$fileByRole['sourceAliasPlan']
$aliasPlan = Get-Content -LiteralPath $aliasPlanPath -Raw | ConvertFrom-Json
Assert-O3F13 ([string]$aliasPlan.schema -eq 'argos_ocv03_o3f12_dev6_source_alias_plan_v1' -and [string]$aliasPlan.state -eq 'FROZEN_FOR_BUILD' -and [string]$aliasPlan.aliasDrive -ceq $aliasDrive -and [int]$aliasPlan.caseCount -eq 6 -and [int]$aliasPlan.sourceLeafCount -eq 12) 'O3F13 frozen source-alias plan changed.'
$allowedAliasTargets = @($aliasPlan.cases | ForEach-Object { [IO.Path]::GetFullPath([string]$_.slotAnchor).TrimEnd('\') })
Assert-O3F13 ($allowedAliasTargets.Count -eq 6 -and @($allowedAliasTargets | Sort-Object -Unique).Count -eq 6) 'O3F13 source-alias target cardinality changed.'
Assert-O3F13AliasAbsent $substPath $aliasDrive

$runtimePath = [IO.Path]::GetFullPath([string]$(if ($Rehearsal) { $invoke.rehearsalRuntimePath } else { $invoke.runtimePath }))
$runtimeSha256 = [string]$(if ($Rehearsal) { $invoke.rehearsalRuntimeSha256 } else { $invoke.runtimeSha256 })
Assert-O3F13Pin $runtimePath $runtimeSha256 'runtime executable'
$gateRoot = [IO.Path]::GetFullPath([string]$invoke.gateOutputRoot)
$devRoot = [IO.Path]::GetFullPath([string]$invoke.dev6OutputRoot)
$contractGateRoot = [IO.Path]::GetFullPath([string]$invoke.realRunnerGateContractRoot)
$contractDevRoot = [IO.Path]::GetFullPath([string]$invoke.realRunnerDev6ContractRoot)
$rehearsalCleanupTarget = $null
if ($Rehearsal -and (Test-O3F13Property $invoke 'rehearsalAliasCleanupAllowedTarget')) {
    $rehearsalCleanupTarget = [IO.Path]::GetFullPath([string]$invoke.rehearsalAliasCleanupAllowedTarget).TrimEnd('\')
    $rehearsalParent = [IO.Path]::GetFullPath((Split-Path -Parent $gateRoot)).TrimEnd('\') + '\'
    Assert-O3F13 (($rehearsalCleanupTarget + '\').StartsWith($rehearsalParent, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $rehearsalCleanupTarget -PathType Container)) 'O3F13 rehearsal alias cleanup target is not an existing bounded fixture root.'
    $allowedAliasTargets += $rehearsalCleanupTarget
}
$expectedContractGateRoot = [IO.Path]::GetFullPath('D:\O3F9G13')
$expectedContractDevRoot = [IO.Path]::GetFullPath('D:\O3F9D13')
Assert-O3F13 ($contractGateRoot.Equals($expectedContractGateRoot, [StringComparison]::OrdinalIgnoreCase) -and $contractDevRoot.Equals($expectedContractDevRoot, [StringComparison]::OrdinalIgnoreCase)) 'O3F13 exact real-runner contract roots changed.'
if (-not $Rehearsal) {
    Assert-O3F13 ($gateRoot.Equals($contractGateRoot, [StringComparison]::OrdinalIgnoreCase) -and $devRoot.Equals($contractDevRoot, [StringComparison]::OrdinalIgnoreCase)) 'O3F13 live roots differ from the verified real-runner roots.'
}
$gateSummary = Join-Path $gateRoot 'SUMMARY.json'
$devSummary = Join-Path $devRoot 'SUMMARY.json'
foreach ($path in @($gateRoot, ($gateRoot + '.partial'), ($gateRoot + '.failed'), $gateSummary, $devRoot, ($devRoot + '.partial'), ($devRoot + '.failed'), $devSummary, $contractGateRoot, $contractDevRoot)) { Assert-O3F13Path $path }
Assert-O3F13 (-not (Test-Path -LiteralPath $gateRoot)) "O3F13 create-new gate root exists: $gateRoot"
Assert-O3F13 (-not (Test-Path -LiteralPath $devRoot)) "O3F13 create-new DEV6 root exists: $devRoot"
Assert-O3F13 (-not (Test-Path -LiteralPath ($gateRoot + '.failed'))) "O3F13 create-new gate quarantine exists: $gateRoot.failed"
Assert-O3F13 (-not (Test-Path -LiteralPath ($devRoot + '.failed'))) "O3F13 create-new DEV6 quarantine exists: $devRoot.failed"
Assert-O3F13 (Test-Path -LiteralPath (Split-Path -Parent $gateRoot) -PathType Container) 'O3F13 gate parent is absent.'
Assert-O3F13 ((Split-Path -Parent $gateRoot).Equals((Split-Path -Parent $devRoot), [StringComparison]::OrdinalIgnoreCase)) 'O3F13 output parents differ.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f13_endpoint_preflight_v1'
        state = 'PASS_O3F13_ENDPOINT_PREFLIGHT'
        rehearsal = [bool]$Rehearsal
        payloadFileCount = @($invoke.files).Count
        gateOutputRoot = $gateRoot
        dev6OutputRoot = $devRoot
        realRunnerGateContractRoot = $contractGateRoot
        realRunnerDev6ContractRoot = $contractDevRoot
        plannedStages = @('SELF_TEST', 'PREFLIGHT', 'ROOT_CONTRACT', 'GATE', 'DEV6')
        sourceAliasDrive = $aliasDrive
        sourceAliasPlanSha256 = Get-O3F13Hash $aliasPlanPath
        sourceAliasUnused = $true
        substSha256 = Get-O3F13Hash $substPath
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
$selfTestChild = Invoke-O3F13OwnedChild $runtimePath (Split-Path -Parent $selfTestRunner) @('-I', '-B', $selfTestRunner, 'SELF_TEST') ([int]$invoke.selfTestTimeoutSeconds) $maximumOutputBytes
$selfTest = ConvertTo-O3F13ChildJson $selfTestChild 'SELF_TEST'
Assert-O3F13ExactPropertySet $selfTest @('mutationsPerformed', 'state') 'SELF_TEST terminal'
Assert-O3F13 ([string]$selfTest.state -eq [string]$invoke.expectedSelfTestState -and -not [bool]$selfTest.mutationsPerformed) 'O3F13 SELF_TEST state or mutation contract changed.'
$runner = [string]$(if ($Rehearsal) { $fileByRole['rehearsalRunner'] } else { $fileByRole['runner'] })
$workingDirectory = Split-Path -Parent $runner

$runnerPreflightChild = Invoke-O3F13OwnedChild $runtimePath $workingDirectory @('-I', '-B', $runner, 'PREFLIGHT') ([int]$invoke.preflightTimeoutSeconds) $maximumOutputBytes
$runnerPreflight = ConvertTo-O3F13ChildJson $runnerPreflightChild 'PREFLIGHT'
Assert-O3F13ExactPropertySet $runnerPreflight @('mutationsPerformed', 'state') 'PREFLIGHT terminal'
Assert-O3F13 ([string]$runnerPreflight.state -eq [string]$invoke.expectedPreflightState -and -not [bool]$runnerPreflight.mutationsPerformed) 'O3F13 runner PREFLIGHT state changed.'

$rootContractArguments = @('-I', '-B', [string]$fileByRole['rootContractProbe'], '--runner', $selfTestRunner, '--runner-sha256', (Get-O3F13Hash $selfTestRunner), '--gate-root', $contractGateRoot, '--dev-root', $contractDevRoot, '--alias-plan', $aliasPlanPath, '--alias-plan-sha256', (Get-O3F13Hash $aliasPlanPath), '--subst-path', $substPath, '--subst-sha256', (Get-O3F13Hash $substPath))
if ($Rehearsal) {
    $aliasFixtureRoot = [IO.Path]::GetFullPath([string]$invoke.aliasFixtureRoot)
    Assert-O3F13Path $aliasFixtureRoot
    Assert-O3F13 (-not (Test-Path -LiteralPath $aliasFixtureRoot) -and (Test-Path -LiteralPath (Split-Path -Parent $aliasFixtureRoot) -PathType Container)) 'O3F13 alias fixture root is not fresh beneath an existing parent.'
    $rootContractArguments += @('--simulate-filesystem', '--exercise-alias', '--alias-fixture-root', $aliasFixtureRoot)
}
$rootContractChild = Invoke-O3F13OwnedChild $runtimePath (Split-Path -Parent ([string]$fileByRole['rootContractProbe'])) $rootContractArguments ([int]$invoke.rootContractTimeoutSeconds) $maximumOutputBytes
$rootContract = ConvertTo-O3F13ChildJson $rootContractChild 'ROOT_CONTRACT'
Assert-O3F13ExactPropertySet $rootContract @('aliasContract', 'dev6Root', 'dev6TerminalKeys', 'gateRoot', 'gateTerminalKeys', 'incompatibleO3F13PrefixRejected', 'mutationsPerformed', 'outputCreated', 'runnerSha256', 'schema', 'simulatedFilesystem', 'sourceImageBytesRead', 'state') 'ROOT_CONTRACT terminal'
Assert-O3F13 ([string]$rootContract.schema -eq 'argos_ocv03_o3f13_exact_runner_root_contract_v1' -and [string]$rootContract.state -eq 'PASS_O3F13_EXACT_REAL_RUNNER_ROOT_CONTRACT' -and [string]$rootContract.runnerSha256 -eq (Get-O3F13Hash $selfTestRunner) -and [string]::Join('|', @($rootContract.gateTerminalKeys)) -ceq 'commands|stage|state|summarySha256' -and [string]::Join('|', @($rootContract.dev6TerminalKeys)) -ceq 'aliasEvidence|executedCount|newProviderHoldCount|results|selectedCount|stage|state|stateCounts|summarySha256' -and [bool]$rootContract.incompatibleO3F13PrefixRejected -and [bool]$rootContract.simulatedFilesystem -eq [bool]$Rehearsal -and [bool]$rootContract.mutationsPerformed -eq [bool]$Rehearsal -and [bool]$rootContract.outputCreated -eq [bool]$Rehearsal -and -not [bool]$rootContract.sourceImageBytesRead) 'O3F13 exact real-runner root/schema contract changed.'
Assert-O3F13 ([string]$rootContract.aliasContract.planSha256 -eq (Get-O3F13Hash $aliasPlanPath) -and [int]$rootContract.aliasContract.canonicalLeafCount -eq 12 -and [int]$rootContract.aliasContract.aliasLeafCount -eq 12 -and [bool]$rootContract.aliasContract.broadRootSlot16Rejected -and [bool]$rootContract.aliasContract.lifecycle.exercised -eq [bool]$Rehearsal) 'O3F13 exact source-alias contract changed.'
Assert-O3F13 ([IO.Path]::GetFullPath([string]$rootContract.gateRoot).Equals($contractGateRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFullPath([string]$rootContract.dev6Root).Equals($contractDevRoot, [StringComparison]::OrdinalIgnoreCase)) 'O3F13 root-contract result identities changed.'

$gateChild = Invoke-O3F13OwnedChild $runtimePath $workingDirectory @('-I', '-B', $runner, 'GATE', '--output-root', $gateRoot) ([int]$invoke.gateTimeoutSeconds) $maximumOutputBytes
$gateTerminal = ConvertTo-O3F13ChildJson $gateChild 'GATE'
Assert-O3F13ExactPropertySet $gateTerminal @($rootContract.gateTerminalKeys) 'GATE terminal'
Assert-O3F13 ([string]$gateTerminal.state -eq [string]$invoke.expectedGateState -and [string]$gateTerminal.stage -eq 'GATE') 'O3F13 GATE state changed.'
Assert-O3F13Pin $gateSummary ([string]$gateTerminal.summarySha256) 'GATE summary'

$devChild = $null
$devTerminal = $null
$devFailure = $null
$aliasCleanupFailure = $null
$devAliasCleanup = $null
try {
    $devChild = Invoke-O3F13OwnedChild $runtimePath $workingDirectory @('-I', '-B', $runner, 'DEV6', '--output-root', $devRoot, '--prerequisite-summary', $gateSummary, '--prerequisite-sha256', ([string]$gateTerminal.summarySha256)) ([int]$invoke.dev6TimeoutSeconds) $maximumOutputBytes
    $devTerminal = ConvertTo-O3F13Dev6ChildJson $devChild ([string]$invoke.expectedDev6PassState) ([string]$invoke.expectedDev6HoldState)
    Assert-O3F13ExactPropertySet $devTerminal @($rootContract.dev6TerminalKeys) 'DEV6 terminal'
    Assert-O3F13 ([string]$devTerminal.stage -ceq 'DEV6' -and [int]$devTerminal.selectedCount -eq 6 -and @($devTerminal.results).Count -eq 6) 'O3F13 DEV6 result identity/cardinality changed.'
    if ([int]$devChild.exitCode -eq 0) {
        Assert-O3F13 ([int]$devTerminal.executedCount -eq 6 -and [int]$devTerminal.newProviderHoldCount -eq 0) 'O3F13 DEV6 pass counts changed.'
    } else {
        Assert-O3F13 ([int]$devTerminal.newProviderHoldCount -ge 1 -and [int]$devTerminal.newProviderHoldCount -le 6 -and ([int]$devTerminal.executedCount + [int]$devTerminal.newProviderHoldCount) -eq 6) 'O3F13 DEV6 hold counts changed.'
    }
    Assert-O3F13Pin $devSummary ([string]$devTerminal.summarySha256) 'DEV6 summary'
} catch {
    $devFailure = [string]$_.Exception.Message
} finally {
    try { $devAliasCleanup = Invoke-O3F13AliasCleanupBackstop $substPath $aliasDrive $allowedAliasTargets }
    catch { $aliasCleanupFailure = [string]$_.Exception.Message }
}
if (-not [string]::IsNullOrWhiteSpace($aliasCleanupFailure)) {
    if (-not [string]::IsNullOrWhiteSpace($devFailure)) { throw ($devFailure + ' | ALIAS_CLEANUP_BACKSTOP_FAILURE: ' + $aliasCleanupFailure) }
    throw $aliasCleanupFailure
}
if (-not [string]::IsNullOrWhiteSpace($devFailure)) { throw $devFailure }
$devSummaryValue = Get-Content -LiteralPath $devSummary -Raw | ConvertFrom-Json
Assert-O3F13 ([string]$devSummaryValue.state -ceq [string]$devTerminal.state -and [string]$devSummaryValue.stage -ceq 'DEV6' -and [int]$devSummaryValue.selectedCount -eq 6 -and @($devSummaryValue.results).Count -eq 6) 'O3F13 DEV6 on-disk summary identity/cardinality changed.'
Assert-O3F13 ([int]$devSummaryValue.executedCount -eq [int]$devTerminal.executedCount -and [int]$devSummaryValue.newProviderHoldCount -eq [int]$devTerminal.newProviderHoldCount) 'O3F13 DEV6 terminal/summary counts diverged.'
$projection = @(Get-O3F13Dev6Projection $devSummaryValue $devRoot)

$terminal = [ordered]@{
    schema = 'argos_ocv03_o3f13_staged_endpoint_result_v1'
    state = 'COMPLETE_O3F13_GATE_AND_DEV6_RESULTS_RETURNED_REVIEW_ONLY'
    revision = [string]$invoke.revision
    rehearsal = [bool]$Rehearsal
    stages = @('SELF_TEST', 'PREFLIGHT', 'ROOT_CONTRACT', 'GATE', 'DEV6')
    selfTest = [ordered]@{
        state = [string]$selfTest.state
        mutationsPerformed = [bool]$selfTest.mutationsPerformed
        runnerSha256 = Get-O3F13Hash $selfTestRunner
    }
    rootContract = $rootContract
    gate = [ordered]@{
        state = [string]$gateTerminal.state
        summaryPath = $gateSummary
        summarySha256 = [string]$gateTerminal.summarySha256
    }
    dev6 = [ordered]@{
        state = [string]$devTerminal.state
        childExitCode = [int]$devChild.exitCode
        summaryPath = $devSummary
        summarySha256 = [string]$devTerminal.summarySha256
        selectedCount = [int]$devTerminal.selectedCount
        executedCount = [int]$devTerminal.executedCount
        newProviderHoldCount = [int]$devTerminal.newProviderHoldCount
        stateCounts = $devTerminal.stateCounts
        aliasEvidence = $devTerminal.aliasEvidence
        endpointAliasCleanupBackstop = $devAliasCleanup
        cases = $projection
    }
    childProcessIds = @([int]$selfTestChild.processId, [int]$runnerPreflightChild.processId, [int]$rootContractChild.processId, [int]$gateChild.processId, [int]$devChild.processId)
    ownedChildCount = 5
    sourceImageBytesRead = (-not [bool]$Rehearsal)
    sourceAliasPlanSha256 = Get-O3F13Hash $aliasPlanPath
    temporarySourceAliasDrive = $aliasDrive
    temporarySourceAliasVerifiedAbsentAfterDev6 = [bool]$devAliasCleanup.verifiedAbsent
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
Assert-O3F13 ([Text.Encoding]::UTF8.GetByteCount($terminalJson) -le [int]$invoke.maximumTerminalOutputBytes) 'O3F13 terminal projection exceeded its bound.'
  $terminalJson
} catch {
  foreach ($pair in @(@($devRoot, ($devRoot + '.failed')), @($gateRoot, ($gateRoot + '.failed')))) {
    if (Test-Path -LiteralPath $pair[0]) {
      Assert-O3F13 (-not (Test-Path -LiteralPath $pair[1])) "O3F13 failure quarantine collision: $($pair[1])"
      Move-Item -LiteralPath $pair[0] -Destination $pair[1]
    }
  }
  throw
}
