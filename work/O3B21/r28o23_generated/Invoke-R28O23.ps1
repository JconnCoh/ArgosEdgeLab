#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}
function Has($Value, [string]$Name) {
    $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name
}
function CircularDistance([double]$Left, [double]$Right) {
    $distance = [Math]::Abs($Left - $Right) % 360.0
    [Math]::Min($distance, 360.0 - $distance)
}
function MeanAngle([double]$Left, [double]$Right) {
    $x = [Math]::Cos($Left * [Math]::PI / 180.0) + [Math]::Cos($Right * [Math]::PI / 180.0)
    $y = [Math]::Sin($Left * [Math]::PI / 180.0) + [Math]::Sin($Right * [Math]::PI / 180.0)
    $angle = [Math]::Atan2($y, $x) * 180.0 / [Math]::PI
    if ($angle -lt 0) { $angle += 360.0 }
    $angle
}
function PairedFixture($BfCandidate, $DfCandidate, $Parameters) {
    if (-not (Has $BfCandidate 'exteriorContext') -or -not (Has $DfCandidate 'exteriorContext')) { return $false }
    $bright = @([double]$BfCandidate.exteriorContext.brightPixelFraction, [double]$DfCandidate.exteriorContext.brightPixelFraction)
    $support = @([double]$BfCandidate.exteriorContext.maximumAngularBrightSupportFraction, [double]$DfCandidate.exteriorContext.maximumAngularBrightSupportFraction)
    ([Math]::Min($bright[0], $bright[1]) -ge [double]$Parameters.fixtureExteriorMinimumSecondaryChannelBrightFraction) -and
    ([Math]::Max($bright[0], $bright[1]) -ge [double]$Parameters.fixtureExteriorMinimumPrimaryChannelBrightFraction) -and
    ([Math]::Min($support[0], $support[1]) -ge [double]$Parameters.fixtureExteriorMinimumSecondaryChannelAngularSupportFraction) -and
    ([Math]::Max($support[0], $support[1]) -ge [double]$Parameters.fixtureExteriorMinimumPrimaryChannelAngularSupportFraction)
}
function CaseFromItem($Item, [string]$Id, [string]$Group, [string]$Expected, [string]$SourceRecordPath) {
    Require ([string]$Item.identity -eq $Id) "Corpus item identity changed: $Id"
    foreach ($side in @('bf', 'df')) {
        Require (Has $Item $side) "Corpus item source record absent: $Id $side"
        Require ([string]$Item.$side.sha256 -match '^[A-Fa-f0-9]{64}$') "Corpus item source hash invalid: $Id $side"
    }
    [pscustomobject][ordered]@{
        id = $Id
        group = $Group
        expected = $Expected
        bf = [string]$Item.bf.path
        bfSha256 = ([string]$Item.bf.sha256).ToUpperInvariant()
        df = [string]$Item.df.path
        dfSha256 = ([string]$Item.df.sha256).ToUpperInvariant()
        sourceRecordPath = $SourceRecordPath
    }
}
function ItemForDiagnostic([string]$DiagnosticRoot) {
    $itemPath = Join-Path (Split-Path -Parent $DiagnosticRoot) 'result.json'
    Require (Test-Path -LiteralPath $itemPath -PathType Leaf) "Corpus item result absent: $itemPath"
    [pscustomobject]@{ Path = $itemPath; Value = (Get-Content -LiteralPath $itemPath -Raw | ConvertFrom-Json) }
}

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR28.py'
$engineHash = '4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466'
$r20 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R20.py'
$r20Hash = 'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
$r18 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py'
$r18Hash = 'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$r17 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py'
$r17Hash = 'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
$r15 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py'
$r15Hash = 'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath = Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json'
$configHash = '27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$manifestPath = Join-Path $PSScriptRoot 'R28O23_CASE.json'
$manifestHash = 'E2580C625067293E8A044703DAB1C0DE40F592D47663AD809483BC68E0C1092B'
$priorContractPath = Join-Path $PSScriptRoot 'R28_PRIOR31_CONTRACT.json'
$priorContractHash = '3000BE26473C5333E8BF2C62D349BE98CF49F6477595956A0B1A9BC6BE63485C'
$syntheticTestPath = Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR28.py'
$syntheticTestHash = '0BF3E7DE98D586833FA392D686ADFA4CB341F73672B6C7113728604E2AD4901F'
$frozenPath = Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json'

if ($PackageLeafPreflight) {
    foreach ($pin in @(
        @($engine, $engineHash), @($configPath, $configHash), @($manifestPath, $manifestHash),
        @($priorContractPath, $priorContractHash), @($syntheticTestPath, $syntheticTestHash),
        @($frozenPath, '7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4')
    )) {
        Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package-local dependency absent: $($pin[0])"
        Require ((Sha $pin[0]) -eq $pin[1]) "Package-local dependency changed: $($pin[0])"
    }
    $packageManifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Require ([string]$packageManifest.outputRoot -eq 'D:/R28O23') 'Package output root changed.'
    Require ([int]$packageManifest.caseSelection.selectedCount -eq 1) 'Package target count changed.'
    Require ((@($packageManifest.caseSelection.selectedOrdinals | ForEach-Object { [int]$_ }) -join ',') -eq '23') 'Package target ordinals changed.'
    [ordered]@{
        schema = 'argos_o3b21_r28o23_package_leaf_preflight_v1'
        state = 'PASS_R28O23_EXACT_PACKAGED_ENTRY_MANIFEST_LEAF'
        manifestLeaf = [IO.Path]::GetFileName($manifestPath)
        manifestSha256 = Sha $manifestPath
        detectorSha256 = Sha $engine
        configSha256 = Sha $configPath
        selectedOrdinals = @($packageManifest.caseSelection.selectedOrdinals | ForEach-Object { [int]$_ })
        imageDecoded = $false
        processStarted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5 -Compress
    return
}

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R28O23 target evidence reached the wrong computer.'
foreach ($pin in @(
    @($python, $pythonHash), @($engine, $engineHash), @($r20, $r20Hash), @($r18, $r18Hash),
    @($r17, $r17Hash), @($r15, $r15Hash), @($configPath, $configHash), @($manifestPath, $manifestHash),
    @($priorContractPath, $priorContractHash), @($syntheticTestPath, $syntheticTestHash)
)) {
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Pinned dependency absent: $($pin[0])"
    Require ((Sha $pin[0]) -eq $pin[1]) "Pinned dependency changed: $($pin[0])"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$priorContract = Get-Content -LiteralPath $priorContractPath -Raw | ConvertFrom-Json
Require ((Sha $frozenPath) -eq [string]$manifest.frozenControls.sha256) 'Frozen ten-case manifest changed.'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$corpusRoot = [string]$manifest.r20Corpus.root
$summaryPath = Join-Path $corpusRoot 'SUMMARY.json'
$resultsCsvPath = Join-Path $corpusRoot 'RESULTS.csv'
$failuresPath = Join-Path $corpusRoot 'FAILURES.json'
foreach ($pin in @(
    @($summaryPath, [string]$manifest.r20Corpus.summarySha256),
    @($resultsCsvPath, [string]$manifest.r20Corpus.resultsCsvSha256),
    @($failuresPath, [string]$manifest.r20Corpus.failuresSha256)
)) {
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Frozen R20 corpus evidence absent: $($pin[0])"
    Require ((Sha $pin[0]) -eq $pin[1]) "Frozen R20 corpus evidence changed: $($pin[0])"
}

$allCases = New-Object Collections.Generic.List[object]
$seen = @{}
$frozen = @((Get-Content -LiteralPath $frozenPath -Raw | ConvertFrom-Json).cases)
Require ($frozen.Count -eq [int]$manifest.frozenControls.count) 'Frozen control cardinality changed.'
foreach ($case in $frozen) {
    $allCases.Add([pscustomobject][ordered]@{
        id = [string]$case.id; group = 'FROZEN_R20_CONTROL'; expected = [string]$case.expected
        bf = [string]$case.bf; bfSha256 = [string]$case.bfSha256
        df = [string]$case.df; dfSha256 = [string]$case.dfSha256
        sourceRecordPath = $frozenPath
    })
    $seen[[string]$case.id] = $true
}
$failures = @((Get-Content -LiteralPath $failuresPath -Raw | ConvertFrom-Json).rows)
Require ($failures.Count -eq [int]$manifest.r20Corpus.holdCount) 'R20 hold cardinality changed.'
foreach ($failure in $failures | Sort-Object identity) {
    $record = ItemForDiagnostic ([string]$failure.diagnosticRoot)
    $case = CaseFromItem $record.Value ([string]$failure.identity) 'R20_CURRENT_HOLD' 'OBSERVE' $record.Path
    if (-not $seen.ContainsKey($case.id)) { $allCases.Add($case); $seen[$case.id] = $true }
}


Require ($allCases.Count -eq [int]$manifest.caseSelection.allCaseCount) 'R28O23 all-case cardinality changed.'
$selectedCases = @(
    foreach ($ordinal in @($manifest.caseSelection.selectedOrdinals | ForEach-Object { [int]$_ })) {
        $case = $allCases[$ordinal]
        [pscustomobject][ordered]@{
            ordinal = $ordinal; id = [string]$case.id; group = [string]$case.group; expected = [string]$case.expected
            bf = [string]$case.bf; bfSha256 = [string]$case.bfSha256
            df = [string]$case.df; dfSha256 = [string]$case.dfSha256
            sourceRecordPath = [string]$case.sourceRecordPath
        }
    }
)
Require ($selectedCases.Count -eq [int]$manifest.caseSelection.selectedCount) 'R28O23 selected cardinality changed.'
Require (@($selectedCases | Where-Object { $_.group -eq 'R20_CURRENT_HOLD' }).Count -eq [int]$manifest.caseSelection.r20CurrentHoldCount) 'R28O23 hold cardinality changed.'
Require (@($selectedCases | Where-Object { $_.group -like 'NEW_*' }).Count -eq [int]$manifest.caseSelection.newControlCount) 'R28O23 new-control cardinality changed.'
foreach ($case in $selectedCases) {
    Require ([string]$case.bfSha256 -match '^[A-Fa-f0-9]{64}$') "Invalid BF hash: $($case.id)"
    Require ([string]$case.dfSha256 -match '^[A-Fa-f0-9]{64}$') "Invalid DF hash: $($case.id)"
    Require (Test-Path -LiteralPath ([string]$case.bf) -PathType Leaf) "BF source absent: $($case.id)"
    Require (Test-Path -LiteralPath ([string]$case.df) -PathType Leaf) "DF source absent: $($case.id)"
}

# Read-only preservation proof for the other 31 frozen outcomes. These are the
# exact existing R27 roots; no task, process, source, or result is changed.
$priorRows = New-Object Collections.Generic.List[object]
foreach ($ordinal in 0..31) {
    if ($ordinal -eq [int]$priorContract.excludedFreshOrdinal) { continue }
    $priorRoot = if ($ordinal -le 19) { [string]$priorContract.r27First20Root } else { [string]$priorContract.r27Last12Root }
    $priorResultPath = Join-Path $priorRoot (('O{0:D2}' -f $ordinal) + '\RESULT.json')
    Require (Test-Path -LiteralPath $priorResultPath -PathType Leaf) "Prior R27 result absent: O$ordinal"
    $prior = Get-Content -LiteralPath $priorResultPath -Raw | ConvertFrom-Json
    $expectedCount = [int]@($priorContract.expectedPairedCandidateCountsByOrdinal)[$ordinal]
    Require ([int]$prior.pairedCandidateCount -eq $expectedCount) "Prior R27 paired cardinality changed: O$ordinal"
    Require (Has $prior.bf 'dfGeometryBfFullPerimeterCompensation') "Prior R27 compensation evidence absent: O$ordinal"
    Require ([string]$prior.bf.dfGeometryBfFullPerimeterCompensation.state -eq [string]$priorContract.requiredBypassState) "Prior R27 branch bypass changed: O$ordinal"
    if ($ordinal -eq 8) {
        Require ([string]$prior.bf.bfShallowDepthRatioNegativeControl.state -eq [string]$priorContract.ordinal8RequiredNegativeControlState) 'O8 negative-control state changed.'
    }
    if ($ordinal -eq 11) {
        Require ((Sha (Join-Path $priorRoot 'O11\BF_holder_exclusion.png')) -eq [string]$priorContract.ordinal11RequiredBfHolderMaskSha256) 'O11 BF holder exclusion changed.'
        Require ((Sha (Join-Path $priorRoot 'O11\DF_holder_exclusion.png')) -eq [string]$priorContract.ordinal11RequiredDfHolderMaskSha256) 'O11 DF holder exclusion changed.'
    }
    $priorRows.Add([pscustomobject][ordered]@{ ordinal=$ordinal; pairedCandidateCount=$expectedCount; compensationState=[string]$prior.bf.dfGeometryBfFullPerimeterCompensation.state; resultSha256=Sha $priorResultPath })
}
Require ($priorRows.Count -eq 31) 'Prior R27 preservation cardinality changed.'

$outputRoot = [string]$manifest.outputRoot
Require (-not (Test-Path -LiteralPath $outputRoot)) "Create-new R28O23 output exists: $outputRoot"
if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b21_r28o23_target_preflight_v1'
        state = 'PASS_O3B21_R28O23_TARGET_PREFLIGHT'
        outputRoot = $outputRoot
        selectedOrdinals = @($selectedCases | ForEach-Object { [int]$_.ordinal })
        selectedIds = @($selectedCases | ForEach-Object { [string]$_.id })
        caseCount = $selectedCases.Count
        r20CurrentHoldCount = @($selectedCases | Where-Object { $_.group -eq 'R20_CURRENT_HOLD' }).Count
        newControlCount = @($selectedCases | Where-Object { $_.group -like 'NEW_*' }).Count
        completedOrdinalsExcluded = '0-22,24-31'
        imageDecoded = $false
        sourceHashingPerformed = $false
        processStarted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        prior31ReadOnlyValidationPassed = $true
        syntheticTestPlanned = $true
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

[Diagnostics.ProcessStartInfo]$testStart = New-Object Diagnostics.ProcessStartInfo
$testStart.FileName = $python
$testStart.Arguments = ('-B "{0}"' -f $syntheticTestPath)
$testStart.WorkingDirectory = $PSScriptRoot
$testStart.UseShellExecute = $false
$testStart.CreateNoWindow = $true
$testStart.RedirectStandardOutput = $true
$testStart.RedirectStandardError = $true
$testProcess = New-Object Diagnostics.Process
$testProcess.StartInfo = $testStart
Require $testProcess.Start() 'R28 packaged synthetic test did not start.'
$testStdout = $testProcess.StandardOutput.ReadToEndAsync()
$testStderr = $testProcess.StandardError.ReadToEndAsync()
Require ($testProcess.WaitForExit(120000)) 'R28 packaged synthetic test timed out.'
Require ($testProcess.ExitCode -eq 0) ('R28 packaged synthetic test failed: ' + $testStderr.Result)
Require ($testStdout.Result.Trim() -eq 'PASS_R28_PACKAGED_SYNTHETIC_33_OF_33') 'R28 packaged synthetic test state changed.'

[void](New-Item -ItemType Directory -Path $outputRoot)
$overall = [Diagnostics.Stopwatch]::StartNew()
$results = New-Object Collections.Generic.List[object]
$assetPaths = New-Object Collections.Generic.List[object]
foreach ($case in $selectedCases) {
    $bfHash = Sha ([string]$case.bf)
    $dfHash = Sha ([string]$case.df)
    Require ($bfHash -eq ([string]$case.bfSha256).ToUpperInvariant()) "BF source changed: $($case.id)"
    Require ($dfHash -eq ([string]$case.dfSha256).ToUpperInvariant()) "DF source changed: $($case.id)"
    $ordinalText = '{0:D2}' -f [int]$case.ordinal
    $caseRoot = Join-Path $outputRoot ('O' + $ordinalText)
    $jobPath = Join-Path $outputRoot ('J' + $ordinalText + '.json')
    $job = [ordered]@{
        bf = [string]$case.bf; df = [string]$case.df; bfSha256 = $bfHash; dfSha256 = $dfHash
        output = $caseRoot; radialEngine = [string]$config.radialEngine
        radialEngineSha256 = [string]$config.radialEngineSha256
        radialParameters = $config.radialParameters; maximumDimension = [int]$manifest.maximumDimension
    }
    [IO.File]::WriteAllText($jobPath, ($job | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $python
    $start.Arguments = ('-B "{0}" --job "{1}"' -f $engine, $jobPath)
    $start.WorkingDirectory = $PSScriptRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    $caseTimer = [Diagnostics.Stopwatch]::StartNew()
    Require $process.Start() "R28O23 detector did not start: $($case.id)"
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(([int]$manifest.runtimeBoundary.maximumPerCaseSeconds * 1000))) {
        try { $process.Kill() } catch {}
        throw "R28O23 detector case timed out: $($case.id)"
    }
    $caseTimer.Stop()
    Require ($process.ExitCode -eq 0) ("R28O23 detector failed: $($case.id): " + $stderr.Result)
    $resultPath = Join-Path $caseRoot 'RESULT.json'
    Require (Test-Path -LiteralPath $resultPath -PathType Leaf) "R28O23 result absent: $($case.id)"
    $detector = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Require ([int]$detector.pairedCandidateCount -eq [int]$manifest.targetGate.targetExpectedPairedCandidateCount) 'R28 O23 paired cardinality failed.'
    Require (Has $detector.bf 'dfGeometryBfFullPerimeterCompensation') 'R28 O23 compensation diagnostic absent.'
    $compensation = $detector.bf.dfGeometryBfFullPerimeterCompensation
    Require ([string]$compensation.state -eq [string]$manifest.targetGate.requiredCompensationState) 'R28 O23 compensation state failed.'
    Require ([int]$compensation.eligibleBfCandidateCount -eq [int]$manifest.targetGate.requiredEligibleBfCandidateCount) 'R28 O23 eligible BF cardinality failed.'
    Require ([int]$compensation.dfShallowQualifiedCandidateCount -eq [int]$manifest.targetGate.requiredDfShallowQualifiedCandidateCount) 'R28 O23 DF shallow cardinality failed.'
    Require ([int]$compensation.dfShallowHolderClearCandidateCount -eq [int]$manifest.targetGate.requiredDfShallowHolderClearCandidateCount) 'R28 O23 holder-clear cardinality failed.'
    Require ([int]$compensation.preClusterPairCount -eq [int]$manifest.targetGate.requiredPreClusterPairCount) 'R28 O23 precluster cardinality failed.'
    Require ([int]$compensation.proposedPairCount -eq [int]$manifest.targetGate.requiredProposedPairCount) 'R28 O23 clustered cardinality failed.'
    Require ([string]@($detector.pairedCandidates)[0].confirmationMode -eq [string]$manifest.targetGate.requiredConfirmationMode) 'R28 O23 confirmation mode failed.'
    Require (-not [bool]$detector.knownNotchLocationConsumed) 'R28 O23 consumed known notch location.'
    $assets = New-Object Collections.Generic.List[object]
    foreach ($asset in @(
        @('BF_REVIEW', (Join-Path $caseRoot 'BF_review.jpg')),
        @('DF_REVIEW', (Join-Path $caseRoot 'DF_review.jpg')),
        @('BF_HOLDER_MASK', (Join-Path $caseRoot 'BF_holder_exclusion.png')),
        @('DF_HOLDER_MASK', (Join-Path $caseRoot 'DF_holder_exclusion.png'))
    )) {
        Require (Test-Path -LiteralPath $asset[1] -PathType Leaf) "R28O23 evidence asset absent: $($case.id) $($asset[0])"
        $item = Get-Item -LiteralPath $asset[1]
        $record = [pscustomobject][ordered]@{ role = $asset[0]; path = $item.FullName; bytes = $item.Length; sha256 = Sha $item.FullName }
        $assets.Add($record)
        $assetPaths.Add($record)
    }
    $results.Add([pscustomobject][ordered]@{
        ordinal = [int]$case.ordinal; id = [string]$case.id; group = [string]$case.group; expected = [string]$case.expected
        bfSha256 = $bfHash; dfSha256 = $dfHash; sourceRecordPath = [string]$case.sourceRecordPath
        elapsedSeconds = [Math]::Round($caseTimer.Elapsed.TotalSeconds, 3)
        detector = $detector; assets = $assets; detectorStdout = $stdout.Result.Trim()
    })
}
$overall.Stop()
$assetBytes = [int64]0
foreach ($asset in $assetPaths) { $assetBytes += [int64]$asset.bytes }
$returnRasters = $assetBytes -le [int64]$manifest.maximumReturnedRasterBytes
if ($returnRasters) {
    foreach ($result in $results) {
        foreach ($asset in $result.assets) {
            $asset | Add-Member -NotePropertyName base64 -NotePropertyValue ([Convert]::ToBase64String([IO.File]::ReadAllBytes([string]$asset.path)))
        }
    }
}
[ordered]@{
    schema = 'argos_ocv03_o3b21_r28o23_target_real_image_evidence_v1'
    state = 'PASS_O3B21_R28O23_TARGET_EVIDENCE_EXECUTED'
    gateState = 'PASS_O3B21_R28O23_EXACT_CARDINALITY_GATE'
    outputRoot = $outputRoot
    caseCount = $selectedCases.Count
    selectedOrdinals = @($selectedCases | ForEach-Object { [int]$_.ordinal })
    completedOrdinalsExcluded = '0-22,24-31'
    r20CurrentHoldCount = @($selectedCases | Where-Object { $_.group -eq 'R20_CURRENT_HOLD' }).Count
    newControlCount = @($selectedCases | Where-Object { $_.group -like 'NEW_*' }).Count
    elapsedSeconds = [Math]::Round($overall.Elapsed.TotalSeconds, 3)
    returnedRasterBytes = $assetBytes
    rasterBytesEmbedded = $returnRasters
    results = $results
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    existingTaskOrProcessActionPerformed = $false
    ownedChildProcessCount = $selectedCases.Count
    completedCaseRerunCount = 0
    syntheticTestState = $testStdout.Result.Trim()
    syntheticTestCount = 33
    prior31ReadOnlyValidationPassed = $true
    prior31 = $priorRows
    providerActivationPerformed = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
} | ConvertTo-Json -Depth 64 -Compress
'PASS_O3B21_R28O23_TARGET_EVIDENCE_EXECUTED'
