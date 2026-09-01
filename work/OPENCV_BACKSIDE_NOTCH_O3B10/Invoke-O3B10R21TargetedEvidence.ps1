#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
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
        id = $Id; group = $Group; expected = $Expected
        bf = [string]$Item.bf.path; bfSha256 = ([string]$Item.bf.sha256).ToUpperInvariant()
        df = [string]$Item.df.path; dfSha256 = ([string]$Item.df.sha256).ToUpperInvariant()
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
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R21.py'
$engineHash = '29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E'
$r20 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R20.py'
$r20Hash = 'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
$r18 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py'
$r18Hash = 'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$r17 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py'
$r17Hash = 'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
$r15 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py'
$r15Hash = 'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R9.json'
$configHash = '62591703B789D3981819E9AEE36C39DD187B2BC9A02BB335367206C78A064D73'
$manifestPath = Join-Path $PSScriptRoot 'R21_TARGETED_CASES.json'
$manifestHash = '7EBEDF8490CABC2427078418637CDEEF0EDD7DA96F2ACEE4AEDC113B60A16D63'
$frozenPath = Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R21 targeted evidence reached the wrong computer.'
foreach ($pin in @(
    @($python, $pythonHash), @($engine, $engineHash), @($r20, $r20Hash), @($r18, $r18Hash),
    @($r17, $r17Hash), @($r15, $r15Hash), @($configPath, $configHash), @($manifestPath, $manifestHash)
)) {
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Pinned dependency absent: $($pin[0])"
    Require ((Sha $pin[0]) -eq $pin[1]) "Pinned dependency changed: $($pin[0])"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
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

$cases = New-Object Collections.Generic.List[object]
$seen = @{}
$frozen = @((Get-Content -LiteralPath $frozenPath -Raw | ConvertFrom-Json).cases)
Require ($frozen.Count -eq [int]$manifest.frozenControls.count) 'Frozen control cardinality changed.'
foreach ($case in $frozen) {
    $cases.Add([pscustomobject][ordered]@{
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
    if (-not $seen.ContainsKey($case.id)) { $cases.Add($case); $seen[$case.id] = $true }
}

$resultRows = @(Import-Csv -LiteralPath $resultsCsvPath)
Require ($resultRows.Count -eq [int]$manifest.r20Corpus.pairCount) 'R20 result cardinality changed.'
$soleHolder = $null
$adjacent = $null
$adjacentDistance = [double]::PositiveInfinity
foreach ($row in $resultRows | Sort-Object identity) {
    if ([string]$row.notchState -ne 'PASS_REVIEW_ONLY_UNIQUE_BACK_BF_DF_NOTCH' -or $seen.ContainsKey([string]$row.identity)) { continue }
    $detectorPath = Join-Path ([string]$row.diagnosticRoot) 'RESULT.json'
    if (-not (Test-Path -LiteralPath $detectorPath -PathType Leaf)) { continue }
    $detector = Get-Content -LiteralPath $detectorPath -Raw | ConvertFrom-Json
    if ([int]$detector.pairedCandidateCount -ne 1) { continue }
    $selected = @($detector.pairedCandidates)[0]
    if ($null -eq $soleHolder -and (Has $selected 'bothChannelsExteriorFixtureContact') -and [bool]$selected.bothChannelsExteriorFixtureContact) {
        $record = ItemForDiagnostic ([string]$row.diagnosticRoot)
        $soleHolder = CaseFromItem $record.Value ([string]$row.identity) 'NEW_SOLE_HOLDER_NEGATIVE' 'OBSERVE' $record.Path
    }
    if ((Has $selected 'bothChannelsExteriorFixtureContact') -and [bool]$selected.bothChannelsExteriorFixtureContact) { continue }
    foreach ($bfCandidate in @($detector.bf.candidates)) {
        foreach ($dfCandidate in @($detector.df.candidates)) {
            $channelDistance = CircularDistance ([double]$bfCandidate.centerAngleDegrees) ([double]$dfCandidate.centerAngleDegrees)
            if ($channelDistance -gt [double]$config.radialParameters.confirmationAngleToleranceDegrees) { continue }
            if (-not (PairedFixture $bfCandidate $dfCandidate $config.radialParameters)) { continue }
            $fixtureAngle = MeanAngle ([double]$bfCandidate.centerAngleDegrees) ([double]$dfCandidate.centerAngleDegrees)
            $distance = CircularDistance ([double]$selected.meanAngleDegrees) $fixtureAngle
            if ($distance -lt [double]$manifest.newControlSelection.minimumAdjacentDistanceDegrees -or
                $distance -gt [double]$manifest.newControlSelection.maximumAdjacentDistanceDegrees -or $distance -ge $adjacentDistance) { continue }
            $record = ItemForDiagnostic ([string]$row.diagnosticRoot)
            $adjacent = CaseFromItem $record.Value ([string]$row.identity) 'NEW_NOTCH_ADJACENT_HOLDER_CONTROL' 'OBSERVE' $record.Path
            $adjacentDistance = $distance
        }
    }
}
$selectionHolds = New-Object Collections.Generic.List[string]
if ($null -eq $soleHolder) { $selectionHolds.Add('HOLD_NO_EXACT_R20_SOLE_PAIRED_HOLDER_CONTROL_FOUND') }
else { $cases.Add($soleHolder); $seen[$soleHolder.id] = $true }
if ($null -eq $adjacent) { $selectionHolds.Add('HOLD_NO_EXACT_R20_NOTCH_ADJACENT_PAIRED_HOLDER_CONTROL_FOUND') }
elseif (-not $seen.ContainsKey($adjacent.id)) { $cases.Add($adjacent); $seen[$adjacent.id] = $true }
else { $selectionHolds.Add('HOLD_NEW_CONTROL_SELECTION_NOT_DISTINCT') }

$outputRoot = [string]$manifest.outputRoot
foreach ($case in $cases) {
    Require ([string]$case.bfSha256 -match '^[A-Fa-f0-9]{64}$') "Invalid BF hash: $($case.id)"
    Require ([string]$case.dfSha256 -match '^[A-Fa-f0-9]{64}$') "Invalid DF hash: $($case.id)"
    Require (Test-Path -LiteralPath ([string]$case.bf) -PathType Leaf) "BF source absent: $($case.id)"
    Require (Test-Path -LiteralPath ([string]$case.df) -PathType Leaf) "DF source absent: $($case.id)"
}
Require (-not (Test-Path -LiteralPath $outputRoot)) "Create-new R21 targeted output exists: $outputRoot"
if ($Preflight) {
    [ordered]@{
        state = 'PASS_O3B10_R21_TARGETED_PREFLIGHT'; caseCount = $cases.Count
        frozenControlCount = $frozen.Count; currentHoldCount = $failures.Count
        newControlCount = $cases.Count - $frozen.Count - $failures.Count
        selectionHolds = @($selectionHolds); output = $outputRoot
        imageDecoded = $false; sourceHashingPerformed = $false; processStarted = $false
        reviewOnly = $true
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

[void](New-Item -ItemType Directory -Path $outputRoot)
$results = New-Object Collections.Generic.List[object]
$assetPaths = New-Object Collections.Generic.List[object]
$frozenFailures = New-Object Collections.Generic.List[string]
$index = 0
foreach ($case in $cases) {
    $bfHash = Sha ([string]$case.bf); $dfHash = Sha ([string]$case.df)
    Require ($bfHash -eq ([string]$case.bfSha256).ToUpperInvariant()) "BF source changed: $($case.id)"
    Require ($dfHash -eq ([string]$case.dfSha256).ToUpperInvariant()) "DF source changed: $($case.id)"
    $caseRoot = Join-Path $outputRoot ('O{0:D2}' -f $index)
    $jobPath = Join-Path $outputRoot ('J{0:D2}.json' -f $index)
    $job = [ordered]@{
        bf = [string]$case.bf; df = [string]$case.df; bfSha256 = $bfHash; dfSha256 = $dfHash
        output = $caseRoot; radialEngine = [string]$config.radialEngine
        radialEngineSha256 = [string]$config.radialEngineSha256
        radialParameters = $config.radialParameters; maximumDimension = [int]$manifest.maximumDimension
    }
    [IO.File]::WriteAllText($jobPath, ($job | ConvertTo-Json -Depth 20), [Text.UTF8Encoding]::new($false))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $python; $start.Arguments = ('-B "{0}" --job "{1}"' -f $engine, $jobPath)
    $start.WorkingDirectory = $PSScriptRoot; $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process; $process.StartInfo = $start
    Require $process.Start() "R21 detector did not start: $($case.id)"
    $stdout = $process.StandardOutput.ReadToEndAsync(); $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(900000)) { try { $process.Kill() } catch {}; throw "R21 detector timed out: $($case.id)" }
    Require ($process.ExitCode -eq 0) ("R21 detector failed: $($case.id): " + $stderr.Result)
    $resultPath = Join-Path $caseRoot 'RESULT.json'
    Require (Test-Path -LiteralPath $resultPath -PathType Leaf) "R21 result absent: $($case.id)"
    $detector = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $pairCount = [int]$detector.pairedCandidateCount
    if ([string]$case.group -eq 'FROZEN_R20_CONTROL') {
        if ([string]$case.expected -eq 'UNIQUE' -and ($pairCount -ne 1 -or [string]$detector.state -eq 'HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED')) { $frozenFailures.Add([string]$case.id) }
        if ([string]$case.expected -eq 'ZERO' -and $pairCount -ne 0) { $frozenFailures.Add([string]$case.id) }
    }
    $assets = New-Object Collections.Generic.List[object]
    foreach ($asset in @(
        @('BF_REVIEW', (Join-Path $caseRoot 'BF_review.jpg')),
        @('DF_REVIEW', (Join-Path $caseRoot 'DF_review.jpg')),
        @('BF_HOLDER_MASK', (Join-Path $caseRoot 'BF_holder_exclusion.png')),
        @('DF_HOLDER_MASK', (Join-Path $caseRoot 'DF_holder_exclusion.png'))
    )) {
        Require (Test-Path -LiteralPath $asset[1] -PathType Leaf) "R21 evidence asset absent: $($case.id) $($asset[0])"
        $item = Get-Item -LiteralPath $asset[1]
        $record = [pscustomobject][ordered]@{ role = $asset[0]; path = $item.FullName; bytes = $item.Length; sha256 = Sha $item.FullName }
        $assets.Add($record); $assetPaths.Add($record)
    }
    $results.Add([pscustomobject][ordered]@{
        id = [string]$case.id; group = [string]$case.group; expected = [string]$case.expected
        bfSha256 = $bfHash; dfSha256 = $dfHash; sourceRecordPath = [string]$case.sourceRecordPath
        detector = $detector; assets = $assets; detectorStdout = $stdout.Result.Trim()
    })
    $index++
}
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
$gateState = if ($frozenFailures.Count -eq 0 -and $selectionHolds.Count -eq 0) {
    'PASS_O3B10_R21_TARGETED_CONTROL_GATE'
} else { 'HOLD_O3B10_R21_TARGETED_CONTROL_GATE' }
[ordered]@{
    schema = 'argos_ocv03_o3b10_r21_targeted_real_image_evidence_v1'
    state = 'PASS_O3B10_R21_TARGETED_EVIDENCE_EXECUTED'; gateState = $gateState
    caseCount = $cases.Count; frozenControlCount = $frozen.Count; currentHoldCount = $failures.Count
    newControlCount = $cases.Count - $frozen.Count - $failures.Count
    frozenControlFailures = @($frozenFailures); selectionHolds = @($selectionHolds)
    returnedRasterBytes = $assetBytes; rasterBytesEmbedded = $returnRasters
    results = $results; outputRoot = $outputRoot
    sourceMutationPerformed = $false; sourceDeletionPerformed = $false
    existingTaskOrProcessActionPerformed = $false; ownedChildProcessCount = $cases.Count
    providerActivationPerformed = $false; reviewOnly = $true
    trainingEligible = $false; xmlEligible = $false; productionEligible = $false
} | ConvertTo-Json -Depth 64 -Compress
