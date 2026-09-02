$summary = Get-Content -LiteralPath 'D:\R31VAL2\SUMMARY.json' -Raw | ConvertFrom-Json
$cases = @(Get-Content -LiteralPath 'D:\R31VAL2\FROZEN_CASES.json' -Raw | ConvertFrom-Json)
$row = @($summary.results)[92]

function Compact-Candidate($candidate) {
    if ($null -eq $candidate) { return $null }
    [ordered]@{
        centerAngleDegrees          = $candidate.centerAngleDegrees
        widthDegrees                = $candidate.widthDegrees
        maximumDepthNativePx        = $candidate.maximumDepthNativePx
        manufacturedMorphologyPassed = $candidate.manufacturedMorphologyPassed
        candidateSource             = $candidate.candidateSource
        holderMasked                = $candidate.holderMasked
        slopeConsistencyFraction    = $candidate.slopeConsistencyFraction
        symmetryScore               = $candidate.symmetryScore
        exteriorBrightPixelFraction = $candidate.exteriorContext.brightPixelFraction
        exteriorAngularSupportFraction = $candidate.exteriorContext.maximumAngularBrightSupportFraction
    }
}

[ordered]@{
    schema = 'argos_r31val2_mismatch_ordinal_92_observation_v1'
    id = $row.id
    bfPath = $cases[92].bf
    dfPath = $cases[92].df
    expectedPairedCandidateCount = $row.expectedPairedCandidateCount
    pairedCandidateCount = $row.pairedCandidateCount
    pairedCandidates = $row.pairedCandidates
    bfCandidateCount = $row.bf.candidateCount
    bfCandidates = @($row.bf.candidates | ForEach-Object { Compact-Candidate $_ })
    bfHolderSpans = $row.bf.holderExclusion.spans
    dfCandidateCount = $row.df.candidateCount
    dfCandidates = @($row.df.candidates | ForEach-Object { Compact-Candidate $_ })
    dfHolderSpans = $row.df.holderExclusion.spans
    knownNotchLocationConsumed = $row.knownNotchLocationConsumed
    imageBytesRead = $false
    taskOrProcessActionPerformed = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 12 -Compress
