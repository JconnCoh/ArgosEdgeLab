$summary = Get-Content -LiteralPath 'D:\R31VAL2\SUMMARY.json' -Raw | ConvertFrom-Json
$row = @($summary.results)[92]
$job = Get-Content -LiteralPath 'D:\R31VAL2\J92.json' -Raw | ConvertFrom-Json
$dfRows = @()
foreach ($candidate in @($row.df.candidates)) {
    $dfRows += [ordered]@{
        centerAngleDegrees = $candidate.centerAngleDegrees
        widthDegrees = $candidate.widthDegrees
        maximumDepthNativePx = $candidate.maximumDepthNativePx
        manufacturedMorphologyPassed = $candidate.manufacturedMorphologyPassed
        candidateSource = $candidate.candidateSource
        holderMasked = $candidate.holderMasked
        slopeConsistencyFraction = $candidate.slopeConsistencyFraction
        symmetryScore = $candidate.symmetryScore
        exteriorBrightPixelFraction = $candidate.exteriorContext.brightPixelFraction
        exteriorAngularSupportFraction = $candidate.exteriorContext.maximumAngularBrightSupportFraction
    }
}
[ordered]@{
    schema = 'argos_r31val2_mismatch_df_compact_v1'
    bfPath = $job.bf
    dfPath = $job.df
    dfCandidates = $dfRows
    dfHolderSpans = $row.df.holderExclusion.spans
    imageBytesRead = $false
    taskOrProcessActionPerformed = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 8 -Compress
