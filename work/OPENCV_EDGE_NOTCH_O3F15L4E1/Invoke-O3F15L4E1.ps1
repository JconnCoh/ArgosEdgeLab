#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$PackageLeafPreflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:rehearsalFixtureMode = ''

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Assert-ChildArgument([string]$Value, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Value)) "O3F15L4E1 empty child argument: $Label"
    Require ($Value -notmatch '[\s"\r\n]') "O3F15L4E1 child argument requires an unsupported quoting form: $Label"
}

function Read-ChildJson([string]$Text, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Text)) "O3F15L4E1 $Label emitted no JSON."
    try { return ($Text | ConvertFrom-Json) }
    catch { throw "O3F15L4E1 $Label emitted invalid JSON." }
}

function Invoke-OwnedPython(
    [string]$Python,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [int]$TimeoutSeconds,
    [string]$Label
) {
    foreach ($argument in $Arguments) { Assert-ChildArgument $argument $Label }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Python
    $start.Arguments = ($Arguments -join ' ')
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $start.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $start.EnvironmentVariables['PYTHONUTF8'] = '1'
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() "O3F15L4E1 $Label did not start."
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        $process.WaitForExit()
        throw "O3F15L4E1 $Label exceeded $TimeoutSeconds seconds."
    }
    $stdout = [string]$stdoutTask.Result
    $stderr = [string]$stderrTask.Result
    $exitCode = $process.ExitCode
    $process.Dispose()
    [pscustomobject]@{ ExitCode = $exitCode; Stdout = $stdout.Trim(); Stderr = $stderr.Trim() }
}

function Start-OwnedPython(
    [string]$Python,
    [string[]]$Arguments,
    [string]$WorkingDirectory,
    [int]$ProbeSeconds,
    [string]$FixtureMode
) {
    foreach ($argument in $Arguments) { Assert-ChildArgument $argument 'RUN worker' }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Python
    $start.Arguments = ($Arguments -join ' ')
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $start.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $start.EnvironmentVariables['PYTHONUTF8'] = '1'
    if (-not [string]::IsNullOrWhiteSpace($FixtureMode)) {
        $start.EnvironmentVariables['ARGOS_O3F15_LAUNCH_FIXTURE_MODE'] = $FixtureMode
    }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() 'O3F15L4E1 RUN worker did not start.'
    Start-Sleep -Seconds $ProbeSeconds
    if ($process.HasExited) {
        $exitCode = $process.ExitCode
        $process.Dispose()
        throw "O3F15L4E1 RUN worker exited immediately: $exitCode"
    }
    [pscustomobject]@{
        Process = $process
        Pid = $process.Id
        CreationTimeUtc = $process.StartTime.ToUniversalTime().ToString('o')
    }
}

function Wait-OwnedBootstrap(
    [Diagnostics.Process]$Process,
    [string]$ProgressPath,
    [int]$TimeoutSeconds
) {
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTime]::UtcNow -lt $deadline) {
        if ($Process.HasExited) {
            $exitCode = $Process.ExitCode
            $Process.Dispose()
            throw "O3F15L4E1 RUN worker exited before bootstrap progress: $exitCode"
        }
        if (Test-Path -LiteralPath $ProgressPath -PathType Leaf) {
            try { $progress = Get-Content -LiteralPath $ProgressPath -Raw | ConvertFrom-Json }
            catch {
                if (-not $Process.HasExited) { $Process.Kill(); $Process.WaitForExit() }
                $Process.Dispose()
                throw 'O3F15L4E1 RUN bootstrap progress is invalid JSON.'
            }
            if ([string]$progress.schema -ne 'argos_ocv03_o3f15_progress_v1' -or [string]$progress.state -ne 'RUNNING_O3F15_FULL978' -or [int]$progress.scheduledCount -ne 978) {
                if (-not $Process.HasExited) { $Process.Kill(); $Process.WaitForExit() }
                $Process.Dispose()
                throw 'O3F15L4E1 RUN bootstrap progress state changed.'
            }
            return $progress
        }
        Start-Sleep -Milliseconds 250
    }
    if (-not $Process.HasExited) { $Process.Kill(); $Process.WaitForExit() }
    $Process.Dispose()
    throw "O3F15L4E1 RUN bootstrap progress exceeded $TimeoutSeconds seconds."
}

function Assert-FrozenContract([object]$Contract) {
    Require ([string]$Contract.schema -eq 'argos_ocv03_o3f15l4e1_launch_contract_v1') 'O3F15L4E1 contract schema changed.'
    Require ([string]$Contract.state -eq 'FROZEN_FOR_BUILD') 'O3F15L4E1 contract is not frozen.'
    Require ([string]$Contract.revision -eq 'OCV03_O3F15L4E1_R11_EXACT_978_FRONT_RECONCILIATION_20260903') 'O3F15L4E1 revision changed.'
    Require ([string]$Contract.expectedComputerName -eq 'A1025645101') 'O3F15L4E1 target changed.'
    Require ([string]$Contract.side -eq 'FRONT' -and [int]$Contract.expectedPairCount -eq 978 -and [int]$Contract.expectedSourceProblemCount -eq 0) 'O3F15L4E1 corpus identity changed.'
    Require ([string]$Contract.runtimeRoot -eq 'D:/O3F15L4RT' -and [string]$Contract.gateRoot -eq 'D:/O3F15L4G' -and [string]$Contract.corpusRoot -eq 'D:/O3F15L4C') 'O3F15L4E1 private roots changed.'
    Require ([string]$Contract.mirrorRoot -eq 'D:/KLARFExport/_ArgosReview/F15L4S') 'O3F15L4E1 portal mirror root changed.'
    Require ([string]$Contract.runtimePath -eq 'D:/AFCV1/rt/python.exe' -and [string]$Contract.runtimeSha256 -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F15L4E1 runtime pin changed.'
    Require ([string]$Contract.inventoryPath -eq 'D:/O3F3INV/inventory.json' -and [string]$Contract.inventorySha256 -eq '7320331752A094F51C44F713A9C644AB41A059B0226DE0F8E0BD8E1D0ABCA056') 'O3F15L4E1 inventory pin changed.'
    Require ([string]$Contract.o3f6ResultsPath -eq 'D:/O3F6R8M/RESULTS.json' -and [string]$Contract.o3f6ResultsSha256 -eq 'A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8') 'O3F15L4E1 R8 results pin changed.'
    Require ([string]$Contract.reviewOrderPath -eq 'D:/O3F7SEL2/REVIEW_ORDER.json' -and [string]$Contract.reviewOrderSha256 -eq 'D57DFE4301FEE2144D18EF4DB2BFD0A323EB095C117BBF10A856A691A8E73BBA') 'O3F15L4E1 review-order pin changed.'
    Require ([string]$Contract.o3f14SummaryPath -eq 'D:/O3F9D14/SUMMARY.json' -and [string]$Contract.o3f14SummarySha256 -eq '22B2CE0A05D2AD5802717CAE13F5E425DAB77D16B224CEE6FBBED3782E0050B3') 'O3F15L4E1 O3F14 prerequisite pin changed.'
    Require ([string]$Contract.expectedPackageLeafState -eq 'PASS_O3F15L4E1_EXACT_PACKAGED_LAUNCH_LEAVES') 'O3F15L4E1 package-leaf state changed.'
    Require ([string]$Contract.expectedPreflightState -eq 'PASS_O3F15L4E1_TARGET_PREFLIGHT') 'O3F15L4E1 target-preflight state changed.'
    Require ([string]$Contract.expectedRehearsalState -eq 'PASS_O3F15L4E1_REHEARSAL_WORKER_LAUNCHED') 'O3F15L4E1 rehearsal state changed.'
    Require ([string]$Contract.expectedLaunchState -eq 'PASS_O3F15L4E1_FRESH_EXACT_978_FRONT_CORPUS_LAUNCHED') 'O3F15L4E1 launch state changed.'
    Require ([string]$Contract.expectedFocusedTestState -eq 'PASS_O3F15L4_FOCUSED_IMAGE_FREE') 'O3F15L4E1 focused-test state changed.'
    Require ([string]$Contract.expectedSelfTestState -eq 'PASS_O3F15L4_FRONT_RECONCILE_SELF_TEST') 'O3F15L4E1 self-test state changed.'
    Require ([string]$Contract.expectedRunnerPreflightState -eq 'PASS_O3F15L4_FRONT_RECONCILE_PREFLIGHT') 'O3F15L4E1 runner-preflight state changed.'
    Require ([string]$Contract.expectedGateState -eq 'COMPLETE_O3F15L4_GATE') 'O3F15L4E1 GATE state changed.'
    Require (-not [bool]$Contract.requestRetryAuthorized -and [bool]$Contract.reviewOnly -and -not [bool]$Contract.productionRoutingEnabled) 'O3F15L4E1 authority widened.'
    $requiredPins = @(
        @('D:/AFCV1/rt/python.exe','7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'),
        @('C:/Windows/System32/subst.exe','158598ED3D590937C964B43DD91546FFCABAB5636B6CE619B4FFC43224013BB6'),
        @('D:/O3F3INV/inventory.json','7320331752A094F51C44F713A9C644AB41A059B0226DE0F8E0BD8E1D0ABCA056'),
        @('D:/O3F6R8M/RESULTS.json','A933227FE4F41259D53D586CBB5189E1B6542B96B7585B606207DAFD35326BD8'),
        @('D:/O3F7SEL2/REVIEW_ORDER.json','D57DFE4301FEE2144D18EF4DB2BFD0A323EB095C117BBF10A856A691A8E73BBA'),
        @('D:/O3F9D14/SUMMARY.json','22B2CE0A05D2AD5802717CAE13F5E425DAB77D16B224CEE6FBBED3782E0050B3'),
        @('C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03CorpusR1/NativeFrontsideWaferPoseOpenCvV2R6.py','90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'),
        @('C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03CorpusR1/WaferTopologyAxisOpenCv.py','D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD'),
        @('C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py','6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4')
    )
    Require (@($Contract.targetPins).Count -eq $requiredPins.Count) 'O3F15L4E1 target-pin cardinality changed.'
    foreach ($required in $requiredPins) {
        $matching = @($Contract.targetPins | Where-Object { [string]$_.path -eq [string]$required[0] -and [string]$_.sha256 -eq [string]$required[1] })
        Require ($matching.Count -eq 1) "O3F15L4E1 required target pin changed: $($required[0])"
    }
}

function Assert-Payload([object]$Contract) {
    $records = @($Contract.payloadFiles)
    Require ($records.Count -ge 8) 'O3F15L4E1 payload file list is incomplete.'
    $names = @($records | ForEach-Object { [string]$_.name })
    Require (@($names | Sort-Object -Unique).Count -eq $records.Count) 'O3F15L4E1 payload names are not unique.'
    foreach ($record in $records) {
        $name = [string]$record.name
        Require (-not [string]::IsNullOrWhiteSpace($name) -and -not [IO.Path]::IsPathRooted($name) -and $name -notmatch '[\\/]' -and $name -notmatch '^\.') "O3F15L4E1 unsafe payload name: $name"
        $path = Join-Path $PSScriptRoot $name
        Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4E1 package payload absent: $name"
        Require ((Sha $path) -eq [string]$record.sha256) "O3F15L4E1 package payload changed: $name"
    }
    foreach ($name in @('Invoke-O3F15L4E1.ps1','O3F15L4E1LaunchFixture.py','Run-O3F15L4FrontReconcile.py','Test-O3F15L4PathHolds.py','FullPerimeterWaferTopologyOpenCvR11.py','OCV03_NotchReviewOpenCvV1.py')) {
        Require (@($records | Where-Object { [string]$_.name -eq $name }).Count -eq 1) "O3F15L4E1 required payload absent: $name"
    }
    $carrier = @($records | Where-Object { [string]$_.name -eq 'OCV03_NotchReviewOpenCvV1.py' })
    Require (-not [bool]$carrier[0].copyToRuntime -and [string]$carrier[0].sha256 -eq '6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4') 'O3F15L4E1 same-bytes carrier changed.'
    return $records
}

function Assert-FreshRoots([string[]]$Roots) {
    foreach ($root in $Roots) {
        Require (-not (Test-Path -LiteralPath $root)) "O3F15L4E1 create-new root exists: $root"
        $parent = Split-Path -Parent $root
        Require (Test-Path -LiteralPath $parent -PathType Container) "O3F15L4E1 create-new root parent is absent: $parent"
    }
}

function Invoke-O3F15L4E1Main {
    Require (-not ($PackageLeafPreflight -and ($Preflight -or $Rehearsal -or -not [string]::IsNullOrWhiteSpace($InvocationManifest)))) 'O3F15L4E1 package-leaf preflight cannot be combined.'
    Require ($Rehearsal -or [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3F15L4E1 invocation manifest is rehearsal-only.'
    $contractPath = Join-Path $PSScriptRoot 'O3F15L4E1_LAUNCH_CONTRACT.json'
    Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'O3F15L4E1 launch contract is absent.'
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Assert-FrozenContract $contract
    $payload = @(Assert-Payload $contract)

    if ($PackageLeafPreflight) {
        [ordered]@{
            schema = 'argos_ocv03_o3f15l4e1_package_leaf_preflight_v1'
            state = [string]$contract.expectedPackageLeafState
            payloadPinCount = $payload.Count
            runtimeCopyFileCount = @($payload | Where-Object { [bool]$_.copyToRuntime }).Count
            expectedPairCount = 978
            side = 'FRONT'
            imageBytesRead = $false
            processStarted = $false
            mutationsPerformed = $false
            reviewOnly = $true
        } | ConvertTo-Json -Depth 6 -Compress
        return
    }

    $fixtureMode = ''
    if ($Rehearsal) {
        Require (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3F15L4E1 rehearsal requires an invocation manifest.'
        $manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
        $invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        Require ([string]$invocation.schema -eq 'argos_ocv03_o3f15l4e1_rehearsal_invocation_v1') 'O3F15L4E1 rehearsal invocation schema changed.'
        $fixtureMode = [string]$invocation.fixtureMode
        Require ($fixtureMode -in @('NORMAL','IMMEDIATE_EXIT')) 'O3F15L4E1 rehearsal fixture mode changed.'
        $python = [IO.Path]::GetFullPath([string]$invocation.pythonPath)
        Require (Test-Path -LiteralPath $python -PathType Leaf) 'O3F15L4E1 rehearsal Python is absent.'
        Require ((Sha $python) -eq [string]$invocation.pythonSha256) 'O3F15L4E1 rehearsal Python changed.'
        $runtime = [IO.Path]::GetFullPath([string]$invocation.runtimeRoot)
        $gate = [IO.Path]::GetFullPath([string]$invocation.gateRoot)
        $corpus = [IO.Path]::GetFullPath([string]$invocation.corpusRoot)
        $mirror = [IO.Path]::GetFullPath([string]$invocation.mirrorRoot)
        $roots = @($runtime,$gate,$corpus,$mirror)
        Require (@($roots | Sort-Object -Unique).Count -eq 4) 'O3F15L4E1 rehearsal roots are not distinct.'
        foreach ($root in $roots) {
            Require ($root -notmatch '(?i)^D:\\O3F15' -and $root -notmatch '(?i)^D:\\KLARFExport') 'O3F15L4E1 rehearsal root entered a JBOD namespace.'
            Assert-ChildArgument $root 'rehearsal root'
        }
        $script:rehearsalFixtureMode = $fixtureMode
        $runnerName = 'O3F15L4E1LaunchFixture.py'
        $testName = 'O3F15L4E1LaunchFixture.py'
    } else {
        Require ([Environment]::MachineName -eq [string]$contract.expectedComputerName) 'O3F15L4E1 launch reached the wrong computer.'
        $python = [string]$contract.runtimePath
        Require (Test-Path -LiteralPath $python -PathType Leaf) 'O3F15L4E1 pinned runtime is absent.'
        Require ((Sha $python) -eq [string]$contract.runtimeSha256) 'O3F15L4E1 pinned runtime changed.'
        Require (Test-Path -LiteralPath ([string]$contract.sourceRoot) -PathType Container) 'O3F15L4E1 source root is absent.'
        foreach ($pin in @($contract.targetPins)) {
            $path = [string]$pin.path
            Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4E1 target pin is absent: $path"
            Require ((Sha $path) -eq [string]$pin.sha256) "O3F15L4E1 target pin changed: $path"
        }
        Require (-not ([Environment]::GetLogicalDrives() -contains 'Q:\')) 'O3F15L4E1 required Q: alias is already occupied.'
        $runtime = [string]$contract.runtimeRoot
        $gate = [string]$contract.gateRoot
        $corpus = [string]$contract.corpusRoot
        $mirror = [string]$contract.mirrorRoot
        $runnerName = 'Run-O3F15L4FrontReconcile.py'
        $testName = 'Test-O3F15L4PathHolds.py'
    }
    Assert-FreshRoots @($runtime,$gate,$corpus,$mirror)

    if ($Preflight) {
        [ordered]@{
            schema = $(if ($Rehearsal) { 'argos_ocv03_o3f15l4e1_rehearsal_preflight_v1' } else { 'argos_ocv03_o3f15l4e1_target_preflight_v1' })
            state = $(if ($Rehearsal) { 'PASS_O3F15L4E1_REHEARSAL_PREFLIGHT' } else { [string]$contract.expectedPreflightState })
            runtimeRoot = $runtime
            gateRoot = $gate
            corpusRoot = $corpus
            mirrorRoot = $mirror
            inventoryPath = $(if ($Rehearsal) { $null } else { [string]$contract.inventoryPath })
            inventorySha256 = $(if ($Rehearsal) { $null } else { [string]$contract.inventorySha256 })
            expectedPairCount = 978
            expectedSourceProblemCount = 0
            frozenOrder = @('HOLDOUT18','CURRENT_TAIL247','FULL_TAIL713')
            imageBytesRead = $false
            processStarted = $false
            mutationsPerformed = $false
            reviewOnly = $true
        } | ConvertTo-Json -Depth 6 -Compress
        return
    }

    $working = $PSScriptRoot
    $testScript = Join-Path $working $testName
    $runnerScript = Join-Path $working $runnerName
    $testJson = $null
    if ($Rehearsal) {
        $testResult = Invoke-OwnedPython $python @('-I','-B',$testScript,'FOCUSED_TEST') $working ([int]$contract.testTimeoutSeconds) 'focused regression'
        Require ($testResult.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($testResult.Stderr)) 'O3F15L4E1 focused regression failed.'
        $testJson = Read-ChildJson $testResult.Stdout 'focused regression'
        Require ([string]$testJson.schema -eq [string]$contract.expectedFocusedTestSchema -and [string]$testJson.state -eq [string]$contract.expectedFocusedTestState) 'O3F15L4E1 focused regression state changed.'
    }

    $selfResult = Invoke-OwnedPython $python @('-I','-B',$runnerScript,'SELF_TEST') $working ([int]$contract.testTimeoutSeconds) 'runner SELF_TEST'
    Require ($selfResult.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($selfResult.Stderr)) 'O3F15L4E1 runner SELF_TEST failed.'
    $selfJson = Read-ChildJson $selfResult.Stdout 'runner SELF_TEST'
    Require ([string]$selfJson.schema -eq [string]$contract.expectedSelfTestSchema -and [string]$selfJson.state -eq [string]$contract.expectedSelfTestState -and -not [bool]$selfJson.mutationsPerformed) 'O3F15L4E1 runner SELF_TEST state changed.'

    $precheckResult = Invoke-OwnedPython $python @('-I','-B',$runnerScript,'PREFLIGHT') $working ([int]$contract.preflightTimeoutSeconds) 'runner PREFLIGHT'
    Require ($precheckResult.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($precheckResult.Stderr)) 'O3F15L4E1 runner PREFLIGHT failed.'
    $precheckJson = Read-ChildJson $precheckResult.Stdout 'runner PREFLIGHT'
    Require ([string]$precheckJson.schema -eq [string]$contract.expectedRunnerPreflightSchema -and [string]$precheckJson.state -eq [string]$contract.expectedRunnerPreflightState -and -not [bool]$precheckJson.mutationsPerformed) 'O3F15L4E1 runner PREFLIGHT state changed.'
    Require ([int]$precheckJson.cohortCounts.HOLDOUT18 -eq 18 -and [int]$precheckJson.cohortCounts.CURRENT_TAIL -eq 247 -and [int]$precheckJson.cohortCounts.FULL_TAIL -eq 713 -and [int]$precheckJson.cohortCounts.FULL978 -eq 978) 'O3F15L4E1 runner PREFLIGHT cohort counts changed.'

    $gateResult = Invoke-OwnedPython $python @('-I','-B',$runnerScript,'GATE','--output-root',$gate) $working ([int]$contract.gateTimeoutSeconds) 'runner GATE'
    Require ($gateResult.ExitCode -eq 0 -and [string]::IsNullOrWhiteSpace($gateResult.Stderr)) 'O3F15L4E1 runner GATE failed.'
    $gateJson = Read-ChildJson $gateResult.Stdout 'runner GATE'
    Require ([string]$gateJson.state -eq [string]$contract.expectedGateState) 'O3F15L4E1 runner GATE state changed.'
    $gateSummary = Join-Path $gate 'SUMMARY.json'
    Require (Test-Path -LiteralPath $gateSummary -PathType Leaf) 'O3F15L4E1 GATE summary is absent.'
    $gateSummaryJson = Get-Content -LiteralPath $gateSummary -Raw | ConvertFrom-Json
    Require ([string]$gateSummaryJson.schema -eq [string]$contract.expectedGateSchema -and [string]$gateSummaryJson.state -eq [string]$contract.expectedGateState) 'O3F15L4E1 GATE summary changed.'
    if (-not $Rehearsal) {
        $focusedPath = Join-Path $gate 'FOCUSED.json'
        Require (Test-Path -LiteralPath $focusedPath -PathType Leaf) 'O3F15L4E1 GATE focused evidence is absent.'
        $testJson = Get-Content -LiteralPath $focusedPath -Raw | ConvertFrom-Json
        Require ([string]$testJson.schema -eq [string]$contract.expectedFocusedTestSchema -and [string]$testJson.state -eq [string]$contract.expectedFocusedTestState) 'O3F15L4E1 GATE focused evidence changed.'
    }
    $gateSummaryHash = Sha $gateSummary

    [void](New-Item -ItemType Directory -Path $runtime)
    foreach ($record in @($payload | Where-Object { [bool]$_.copyToRuntime })) {
        $destination = Join-Path $runtime ([string]$record.name)
        [IO.File]::Copy((Join-Path $PSScriptRoot ([string]$record.name)),$destination,$false)
        Require ((Sha $destination) -eq [string]$record.sha256) "O3F15L4E1 runtime copy changed: $($record.name)"
    }
    $runtimeRunner = Join-Path $runtime $runnerName
    $workerArgs = @('-I','-B',$runtimeRunner,'RUN','--output-root',$corpus,'--mirror-root',$mirror,'--prerequisite-summary',$gateSummary,'--prerequisite-sha256',$gateSummaryHash)
    $worker = Start-OwnedPython $python $workerArgs $runtime ([int]$contract.survivalProbeSeconds) $fixtureMode
    $mirrorProgress = Join-Path $mirror 'PROGRESS.json'
    $bootstrap = Wait-OwnedBootstrap $worker.Process $mirrorProgress ([int]$contract.bootstrapProgressTimeoutSeconds)
    $worker.Process.Dispose()

    [ordered]@{
        schema = $(if ($Rehearsal) { 'argos_ocv03_o3f15l4e1_rehearsal_launch_v1' } else { 'argos_ocv03_o3f15l4e1_launch_v1' })
        state = $(if ($Rehearsal) { [string]$contract.expectedRehearsalState } else { [string]$contract.expectedLaunchState })
        fixtureMode = $(if ($Rehearsal) { $fixtureMode } else { $null })
        focusedTestState = [string]$testJson.state
        selfTestState = [string]$selfJson.state
        preflightState = [string]$precheckJson.state
        gateState = [string]$gateSummaryJson.state
        gateSummarySha256 = $gateSummaryHash
        pid = $worker.Pid
        creationTimeUtc = $worker.CreationTimeUtc
        runtimeRoot = $runtime
        gateRoot = $gate
        corpusRoot = $corpus
        mirrorRoot = $mirror
        progressPath = Join-Path $corpus 'PROGRESS.json'
        summaryPath = Join-Path $corpus 'SUMMARY.json'
        mirrorProgressPath = $mirrorProgress
        terminalFailurePath = Join-Path $corpus 'TERMINAL_FAILURE.json'
        mirrorTerminalFailurePath = Join-Path $mirror 'TERMINAL_FAILURE.json'
        acceptedPostLaunchObservationStates = @($contract.acceptedPostLaunchObservationStates)
        workerStillRunningAfterSeconds = [int]$contract.survivalProbeSeconds
        bootstrapProgressState = [string]$bootstrap.state
        bootstrapScheduledCount = [int]$bootstrap.scheduledCount
        expectedPairCount = 978
        sourceImagesReadByEndpoint = $false
        imageBytesRead = $false
        sourceImagesMutated = $false
        existingProcessesQueried = $false
        existingProcessOrTaskActionPerformed = $false
        ownedProcessStarted = $true
        automaticRetryAuthorized = $false
        holdsCleared = $false
        mutationsPerformed = $true
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
    } | ConvertTo-Json -Depth 8 -Compress
}

try {
    Invoke-O3F15L4E1Main
} catch {
    if ($Rehearsal) {
        $message = [string]$_.Exception.Message
        $collision = $message -match '(?i)create-new root exists'
        $immediate = $message -match '(?i)worker exited immediately'
        [ordered]@{
            schema = 'argos_ocv03_o3f15l4e1_rehearsal_launch_v1'
            state = $(if ($collision) { 'HOLD_O3F15L4E1_REHEARSAL_CREATE_NEW_COLLISION' } elseif ($immediate) { 'HOLD_O3F15L4E1_REHEARSAL_WORKER_EXITED_IMMEDIATELY' } else { 'HOLD_O3F15L4E1_REHEARSAL_FAILURE' })
            fixtureMode = $script:rehearsalFixtureMode
            error = $message
            processLaunchAttempted = $immediate
            ownedProcessStarted = $false
            existingProcessesQueried = $false
            existingProcessOrTaskActionPerformed = $false
            imageBytesRead = $false
            mutationsPerformed = $immediate
            reviewOnly = $true
        } | ConvertTo-Json -Depth 5 -Compress
        exit 2
    }
    throw
}
