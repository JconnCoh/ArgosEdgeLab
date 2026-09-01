#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

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
$engine = Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR22.py'
$engineHash = 'DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94'
$r20 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R20.py'
$r20Hash = 'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
$r18 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py'
$r18Hash = 'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$r17 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py'
$r17Hash = 'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
$r15 = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py'
$r15Hash = 'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath = Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R10.json'
$configHash = '66680048EC05C73AAE4213A3BA750C7AEF862F9AB07F401684F1050CE0BABFB2'
$manifestPath = Join-Path $PSScriptRoot 'R22T1_TARGET_CASES.json'
$manifestHash = 'FEF0D2E1618209D7F4C1EF21C95D8CB8F38BABDEB98435B9FF340C0C9E5D9892'
$frozenPath = Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R22T1 missing-only evidence reached the wrong computer.'
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


Require ($allCases.Count -eq [int]$manifest.caseSelection.allCaseCount) 'R22T1 all-case cardinality changed.'
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
Require ($selectedCases.Count -eq [int]$manifest.caseSelection.selectedCount) 'R22T1 selected cardinality changed.'
Require (@($selectedCases | Where-Object { $_.group -eq 'R20_CURRENT_HOLD' }).Count -eq [int]$manifest.caseSelection.r20CurrentHoldCount) 'R22T1 hold cardinality changed.'
Require (@($selectedCases | Where-Object { $_.group -like 'NEW_*' }).Count -eq [int]$manifest.caseSelection.newControlCount) 'R22T1 new-control cardinality changed.'
foreach ($case in $selectedCases) {
    Require ([string]$case.bfSha256 -match '^[A-Fa-f0-9]{64}$') "Invalid BF hash: $($case.id)"
    Require ([string]$case.dfSha256 -match '^[A-Fa-f0-9]{64}$') "Invalid DF hash: $($case.id)"
    Require (Test-Path -LiteralPath ([string]$case.bf) -PathType Leaf) "BF source absent: $($case.id)"
    Require (Test-Path -LiteralPath ([string]$case.df) -PathType Leaf) "DF source absent: $($case.id)"
}

$outputRoot = [string]$manifest.outputRoot
Require (-not (Test-Path -LiteralPath $outputRoot)) "Create-new R22T1 output exists: $outputRoot"
if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b21_r22t1_missing_only_preflight_v1'
        state = 'PASS_O3B21_R22T1_MISSING_ONLY_PREFLIGHT'
        outputRoot = $outputRoot
        selectedOrdinals = @($selectedCases | ForEach-Object { [int]$_.ordinal })
        selectedIds = @($selectedCases | ForEach-Object { [string]$_.id })
        caseCount = $selectedCases.Count
        r20CurrentHoldCount = @($selectedCases | Where-Object { $_.group -eq 'R20_CURRENT_HOLD' }).Count
        newControlCount = @($selectedCases | Where-Object { $_.group -like 'NEW_*' }).Count
        completedOrdinalsExcluded = '0-18'
        imageDecoded = $false
        sourceHashingPerformed = $false
        processStarted = $false
        mutationsPerformed = $false
        reviewOnly = $true
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

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
    Require $process.Start() "R22T1 detector did not start: $($case.id)"
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(([int]$manifest.runtimeBoundary.maximumPerCaseSeconds * 1000))) {
        try { $process.Kill() } catch {}
        throw "R22T1 detector case timed out: $($case.id)"
    }
    $caseTimer.Stop()
    Require ($process.ExitCode -eq 0) ("R22T1 detector failed: $($case.id): " + $stderr.Result)
    $resultPath = Join-Path $caseRoot 'RESULT.json'
    Require (Test-Path -LiteralPath $resultPath -PathType Leaf) "R22T1 result absent: $($case.id)"
    $detector = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    $assets = New-Object Collections.Generic.List[object]
    foreach ($asset in @(
        @('BF_REVIEW', (Join-Path $caseRoot 'BF_review.jpg')),
        @('DF_REVIEW', (Join-Path $caseRoot 'DF_review.jpg')),
        @('BF_HOLDER_MASK', (Join-Path $caseRoot 'BF_holder_exclusion.png')),
        @('DF_HOLDER_MASK', (Join-Path $caseRoot 'DF_holder_exclusion.png'))
    )) {
        Require (Test-Path -LiteralPath $asset[1] -PathType Leaf) "R22T1 evidence asset absent: $($case.id) $($asset[0])"
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
    schema = 'argos_ocv03_o3b21_r22t1_missing_only_real_image_evidence_v1'
    state = 'PASS_O3B21_R22T1_MISSING_ONLY_EVIDENCE_EXECUTED'
    gateState = 'PASS_O3B21_R22T1_EXACT_CARDINALITY_GATE'
    outputRoot = $outputRoot
    caseCount = $selectedCases.Count
    selectedOrdinals = @($selectedCases | ForEach-Object { [int]$_.ordinal })
    completedOrdinalsExcluded = '0-18'
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
    providerActivationPerformed = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
} | ConvertTo-Json -Depth 64 -Compress
'PASS_O3B21_R22T1_MISSING_ONLY_EVIDENCE_EXECUTED'
