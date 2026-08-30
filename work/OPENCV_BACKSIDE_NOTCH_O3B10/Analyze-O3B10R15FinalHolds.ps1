[CmdletBinding()]
param(
    [string]$HoldCsv = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/comparison_r14_r15_complete_20260829/R15_HOLDS.csv',
    [string]$ResultRoot = 'C:\R15H8D\data\JBOD_KLARF_EXPORT',
    [string]$OutputRoot = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/analysis_r15_final_holds_20260829'
)

$ErrorActionPreference = 'Stop'
if (Test-Path -LiteralPath $OutputRoot) { throw "Refusing existing output root: $OutputRoot" }
$holds = @(Import-Csv -LiteralPath $HoldCsv)
if ($holds.Count -ne 55) { throw "Expected 55 hold rows; found $($holds.Count)." }

$byRoot = @{}
foreach ($hold in $holds) {
    $prefix = 'D:\KLARFExport\'
    $root = [string]$hold.r15DiagnosticRoot
    if (-not $root.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected R15 diagnostic root: $root"
    }
    $byRoot[$root.Substring($prefix.Length).Replace('\', '/')] = $hold
}

$rows = foreach ($file in @(Get-ChildItem -LiteralPath $ResultRoot -Recurse -File -Filter 'RESULT.json')) {
    $relativeRoot = $file.Directory.FullName.Substring($ResultRoot.TrimEnd('\').Length + 1).Replace('\', '/')
    if (-not $byRoot.ContainsKey($relativeRoot)) { throw "No hold row for $relativeRoot" }
    $hold = $byRoot[$relativeRoot]
    $result = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
    $bfMorph = @($result.bf.candidates | Where-Object { [bool]$_.manufacturedMorphologyPassed })
    $dfMorph = @($result.df.candidates | Where-Object { [bool]$_.manufacturedMorphologyPassed })
    $bfEligible = [int]$result.bfEligibleCandidateCount
    $dfEligible = [int]$result.dfEligibleCandidateCount
    $pairCount = [int]$result.pairedCandidateCount

    $family = switch ([string]$hold.r15State) {
        'HOLD_BACK_NOTCH_CHANNEL_ANALYSIS_FAILED' {
            if ($pairCount -eq 1) { 'CHANNEL_ANALYSIS_WITH_UNIQUE_PAIR' } else { 'CHANNEL_ANALYSIS_WITHOUT_PAIR' }
        }
        'HOLD_BACK_NOTCH_MULTIPLE_BF_DF_MATCHES' { 'MULTIPLE_CROSS_CHANNEL_PAIRS' }
        default {
            if ($bfEligible -eq 0 -and $dfEligible -eq 0) { 'NO_ELIGIBLE_CANDIDATE_EITHER_CHANNEL' }
            elseif ($bfEligible -eq 0) { 'DF_ONLY_ELIGIBLE' }
            elseif ($dfEligible -eq 0) { 'BF_ONLY_ELIGIBLE' }
            else { 'ELIGIBLE_CANDIDATES_DISAGREE' }
        }
    }

    [pscustomobject]@{
        identity = [string]$hold.identity
        holdState = [string]$hold.r15State
        residualFamily = $family
        relativeDiagnosticRoot = $relativeRoot
        bfEligibleCandidateCount = $bfEligible
        dfEligibleCandidateCount = $dfEligible
        pairedCandidateCount = $pairCount
        bfMorphologyAnglesDegrees = @($bfMorph | ForEach-Object { [double]$_.centerAngleDegrees }) -join ';'
        dfMorphologyAnglesDegrees = @($dfMorph | ForEach-Object { [double]$_.centerAngleDegrees }) -join ';'
        bfInlierFraction = [double]$result.bf.radialQualification.fit.inlierFraction
        bfCoverageFraction = [double]$result.bf.radialQualification.fit.angularCoverageFraction
        bfRmsResidualPx = [double]$result.bf.radialQualification.fit.rmsResidualPx
        dfInlierFraction = [double]$result.df.radialQualification.fit.inlierFraction
        dfCoverageFraction = [double]$result.df.radialQualification.fit.angularCoverageFraction
        dfRmsResidualPx = [double]$result.df.radialQualification.fit.rmsResidualPx
        patternSuppression = [string]$result.patternSuppression
        sourceMutationPerformed = [bool]$result.sourceMutationPerformed
    }
}
if ($rows.Count -ne 55) { throw "Expected 55 analyzed result rows; found $($rows.Count)." }
if (@($rows | Where-Object { $_.patternSuppression -ne 'FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY_BOTH_CHANNELS' }).Count -ne 0) {
    throw 'A hold result did not declare the frozen full-360 pattern suppression method.'
}
if (@($rows | Where-Object sourceMutationPerformed).Count -ne 0) { throw 'A result declared source mutation.' }

$familyCounts = @($rows | Group-Object residualFamily | Sort-Object Name | ForEach-Object {
    [ordered]@{ family = $_.Name; count = $_.Count }
})
$summary = [ordered]@{
    schema = 'argos_o3b10_r15_final_hold_analysis_v1'
    createdUtc = [DateTimeOffset]::UtcNow.ToString('o')
    state = 'PASS_R15_FINAL_HOLD_ANALYSIS'
    inputHoldCount = $holds.Count
    analyzedResultCount = $rows.Count
    patternSuppression = 'FULL_360_OUTERMOST_DARK_EXTERIOR_BOUNDARY_BOTH_CHANNELS'
    familyCounts = $familyCounts
    imagePairCoverageCount = 55
    sourceMutationPerformed = $false
    reviewOnly = $true
}

[void](New-Item -ItemType Directory -Path $OutputRoot)
$csvPath = Join-Path $OutputRoot 'HOLD_ROWS.csv'
$jsonPath = Join-Path $OutputRoot 'SUMMARY.json'
$rows | Sort-Object residualFamily, identity | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding utf8
[IO.File]::WriteAllText($jsonPath, (($summary | ConvertTo-Json -Depth 6) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    State = $summary.state
    AnalyzedResultCount = $rows.Count
    FamilyCounts = $familyCounts
    SummarySha256 = (Get-FileHash -LiteralPath $jsonPath -Algorithm SHA256).Hash
    HoldRowsSha256 = (Get-FileHash -LiteralPath $csvPath -Algorithm SHA256).Hash
}
