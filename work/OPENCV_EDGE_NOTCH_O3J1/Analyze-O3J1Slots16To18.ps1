#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Gate) {
    throw 'Specify exactly one of -Preflight or -Gate.'
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$collectionGatePath = Join-Path $PSScriptRoot 'O3J1_EXACT_RESPONSE_COLLECTION_GATE.json'
$expectedCollectionGateSha256 = '4C277E2F92BC33D61F29BBF41E0E79D3371A8258365522B100DC606C02EB2748'
$mappingPath = Join-Path $project 'work\O3J1R\SOURCE_TO_RETURN_MAPPING.json'
$expectedMappingSha256 = 'F5A148CC5CDE765A0A86B7046D2665B65389D48BC3775A315B52FFA87393FFA3'
$jobPath = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3D3\O3D3R4_HOTSPOT_JOB.json'
$expectedJobSha256 = 'F7DB6FE811D58DAA3F410C5AD8E4F063BBD6E961004BDAF1BF2470BB74392717'
$enginePath = Join-Path $project 'work\PATTERNED_FIDUCIAL_INVENTORY\tools\NativeFrontsideWaferPoseOpenCvV2R6.py'
$expectedEngineSha256 = '90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'
$resultPath = Join-Path $PSScriptRoot 'O3J1_SLOTS16_18_JSON_DIAGNOSIS.json'
$filesRoot = Join-Path $project 'work\O3J1R\files'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-JsonCreateNew {
    param([string]$Path, [object]$Value)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

function Get-Median {
    param([double[]]$Values)
    $ordered = @($Values | Sort-Object)
    Assert-True ($ordered.Count -gt 0) 'Median requires at least one value.'
    $middle = [int][Math]::Floor($ordered.Count / 2)
    if (($ordered.Count % 2) -eq 1) {
        return [double]$ordered[$middle]
    }
    return ([double]$ordered[$middle - 1] + [double]$ordered[$middle]) / 2.0
}

Assert-True (Test-Path -LiteralPath $collectionGatePath -PathType Leaf) 'O3J1 collection gate is absent.'
Assert-True ((Get-Sha256 -Path $collectionGatePath) -eq $expectedCollectionGateSha256) 'O3J1 collection gate changed.'
Assert-True (Test-Path -LiteralPath $mappingPath -PathType Leaf) 'O3J1 source-to-return mapping is absent.'
Assert-True ((Get-Sha256 -Path $mappingPath) -eq $expectedMappingSha256) 'O3J1 source-to-return mapping changed.'
Assert-True ((Get-Sha256 -Path $jobPath) -eq $expectedJobSha256) 'O3D3R4 frozen job changed.'
Assert-True ((Get-Sha256 -Path $enginePath) -eq $expectedEngineSha256) 'Frozen R6 engine changed.'

$collectionGate = Get-Content -LiteralPath $collectionGatePath -Raw | ConvertFrom-Json
$mapping = Get-Content -LiteralPath $mappingPath -Raw | ConvertFrom-Json
Assert-True ([string]$collectionGate.state -eq 'PASS_O3J1_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED' -and [bool]$collectionGate.signatureVerified) 'O3J1 collection gate is not signed-terminal PASS.'
Assert-True ([string]$mapping.state -eq 'PASS_O3J1_EXACT_13_JSON_RECONSTITUTED' -and [int]$mapping.fileCount -eq 13) 'O3J1 reconstructed JSON mapping changed.'
Assert-True (@($collectionGate.files).Count -eq 13 -and @($mapping.files).Count -eq 13) 'O3J1 reconstructed JSON evidence cardinality changed.'

foreach ($row in @($mapping.files)) {
    $path = Join-Path (Join-Path $project 'work\O3J1R') ([string]$row.returnPath).Replace('/', '\')
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3J1 reconstructed JSON is absent: $($row.returnPath)"
    Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes -and (Get-Sha256 -Path $path) -eq [string]$row.sha256) "O3J1 reconstructed JSON changed: $($row.returnPath)"
}

$job = Get-Content -LiteralPath $jobPath -Raw | ConvertFrom-Json
$parameters = $job.parameters
$thresholds = [ordered]@{
    manufacturedMinimumWidthDegrees = [double]$parameters.manufacturedMinimumWidthDegrees
    manufacturedMaximumWidthDegrees = [double]$parameters.manufacturedMaximumWidthDegrees
    manufacturedMinimumSymmetry = [double]$parameters.manufacturedMinimumSymmetry
    manufacturedMaximumTipOffsetFraction = [double]$parameters.manufacturedMaximumTipOffsetFraction
    manufacturedMinimumSlopeConsistency = [double]$parameters.manufacturedMinimumSlopeConsistency
    manufacturedMinimumCrossChannelOverlap = [double]$parameters.manufacturedMinimumCrossChannelOverlap
}

function Test-Candidate {
    param([object]$Candidate, [int]$Ordinal)
    $width = [double]$Candidate.combinedWidthDegrees
    $symmetry = [double]$Candidate.combinedSymmetryScore
    $tip = [double]$Candidate.combinedTipCenterOffsetFraction
    $slope = [double]$Candidate.combinedSlopeConsistencyFraction
    $overlap = [double]$Candidate.crossChannelOverlapFraction
    $failed = New-Object Collections.Generic.List[string]
    if ($width -lt $thresholds.manufacturedMinimumWidthDegrees) { $failed.Add('WIDTH_BELOW_MINIMUM') }
    if ($width -gt $thresholds.manufacturedMaximumWidthDegrees) { $failed.Add('WIDTH_ABOVE_MAXIMUM') }
    if ($symmetry -lt $thresholds.manufacturedMinimumSymmetry) { $failed.Add('SYMMETRY_BELOW_MINIMUM') }
    if ($tip -gt $thresholds.manufacturedMaximumTipOffsetFraction) { $failed.Add('TIP_OFFSET_ABOVE_MAXIMUM') }
    if ($slope -lt $thresholds.manufacturedMinimumSlopeConsistency) { $failed.Add('SLOPE_CONSISTENCY_BELOW_MINIMUM') }
    if ($overlap -lt $thresholds.manufacturedMinimumCrossChannelOverlap) { $failed.Add('CROSS_CHANNEL_OVERLAP_BELOW_MINIMUM') }
    $eligible = $failed.Count -eq 0
    Assert-True ($eligible -eq [bool]$Candidate.manufacturedNotchMorphologyEligible) 'Computed morphology eligibility disagrees with the frozen detector output.'
    return [pscustomobject]@{
        candidateOrdinal = $Ordinal
        reviewAngleDegrees = [double]$Candidate.reviewAngleDegrees
        reviewAngleChannel = [string]$Candidate.reviewAngleChannel
        channelAngleDifferenceDegrees = [double]$Candidate.channelAngleDifferenceDegrees
        crossChannelOverlapFraction = $overlap
        combinedWidthDegrees = $width
        combinedSymmetryScore = $symmetry
        combinedTipCenterOffsetFraction = $tip
        combinedSlopeConsistencyFraction = $slope
        minimumWidthMarginDegrees = $width - $thresholds.manufacturedMinimumWidthDegrees
        maximumWidthMarginDegrees = $thresholds.manufacturedMaximumWidthDegrees - $width
        symmetryMargin = $symmetry - $thresholds.manufacturedMinimumSymmetry
        tipOffsetMargin = $thresholds.manufacturedMaximumTipOffsetFraction - $tip
        slopeConsistencyMargin = $slope - $thresholds.manufacturedMinimumSlopeConsistency
        crossChannelOverlapMargin = $overlap - $thresholds.manufacturedMinimumCrossChannelOverlap
        failedCriteria = $failed.ToArray()
        manufacturedNotchMorphologyEligible = $eligible
    }
}

$slotRows = New-Object Collections.Generic.List[object]
foreach ($slot in 16..18) {
    $slotPath = Join-Path $filesRoot ('S' + $slot + '.json')
    $value = Get-Content -LiteralPath $slotPath -Raw | ConvertFrom-Json
    $candidates = New-Object Collections.Generic.List[object]
    $ordinal = 0
    foreach ($candidate in @($value.physicalIndentationCandidates)) {
        $ordinal++
        $candidates.Add((Test-Candidate -Candidate $candidate -Ordinal $ordinal))
    }
    $eligibleCount = @($candidates | Where-Object { [bool]$_.manufacturedNotchMorphologyEligible }).Count
    Assert-True ($eligibleCount -eq $(if ([bool]$value.manufacturedNotchSelectedForReview) { 1 } else { 0 })) "Slot$slot selection cardinality disagrees with eligible morphology count."
    $slotRows.Add([pscustomobject]@{
        slot = $slot
        identity = [string]$value.identity
        detectorState = [string]$value.state
        bfQualified = [bool]$value.bf.qualified
        dfQualified = [bool]$value.df.qualified
        channelComparisonQualified = [bool]$value.channelComparison.qualified
        channelCenterDifferencePx = [double]$value.channelComparison.centerDifferencePx
        channelRadiusDifferencePx = [double]$value.channelComparison.radiusDifferencePx
        physicalCandidateCount = @($value.physicalIndentationCandidates).Count
        bfOnlyBoundaryCandidateCount = @($value.bfOnlyBoundaryCandidates).Count
        dfOnlyBoundaryCandidateCount = @($value.dfOnlyBoundaryCandidates).Count
        eligibleManufacturedMorphologyCount = $eligibleCount
        manufacturedNotchSelectedForReview = [bool]$value.manufacturedNotchSelectedForReview
        candidates = @($candidates.ToArray())
    })
}

$clusterRows = New-Object Collections.Generic.List[object]
foreach ($slot in 19..25) {
    $value = Get-Content -LiteralPath (Join-Path $filesRoot ('S' + $slot + '.json')) -Raw | ConvertFrom-Json
    Assert-True ([string]$value.state -eq 'PASS_REVIEW_ONLY_MANUFACTURED_NOTCH_CANDIDATE' -and $null -ne $value.selectedReviewOnlyManufacturedNotch) "Slot$slot cluster member changed."
    $candidate = $value.selectedReviewOnlyManufacturedNotch
    $clusterRows.Add([pscustomobject]@{
        slot = $slot
        reviewAngleDegrees = [double]$candidate.reviewAngleDegrees
        combinedWidthDegrees = [double]$candidate.combinedWidthDegrees
        combinedSymmetryScore = [double]$candidate.combinedSymmetryScore
        combinedTipCenterOffsetFraction = [double]$candidate.combinedTipCenterOffsetFraction
        combinedSlopeConsistencyFraction = [double]$candidate.combinedSlopeConsistencyFraction
        crossChannelOverlapFraction = [double]$candidate.crossChannelOverlapFraction
        channelAngleDifferenceDegrees = [double]$candidate.channelAngleDifferenceDegrees
    })
}
$clusterAngles = @($clusterRows | ForEach-Object { [double]$_.reviewAngleDegrees })
$clusterMedianAngle = Get-Median -Values $clusterAngles
$slot18 = $slotRows | Where-Object { [int]$_.slot -eq 18 }
$slot18Angle = [double]$slot18.candidates[0].reviewAngleDegrees

$result = [ordered]@{
    schema = 'argos_o3j1_slots16_18_json_diagnosis_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3J1_SLOTS16_18_JSON_DIAGNOSIS_NO_TUNING'
    disposition = 'DIAGNOSTIC_ONLY'
    requestId = [string]$collectionGate.requestId
    responseId = [string]$collectionGate.responseId
    collectionGateSha256 = $expectedCollectionGateSha256
    sourceToReturnMappingSha256 = $expectedMappingSha256
    frozenJobSha256 = $expectedJobSha256
    frozenEngineSha256 = $expectedEngineSha256
    thresholds = $thresholds
    slots = @($slotRows.ToArray())
    slots19To25SelectedCandidateCohort = @($clusterRows.ToArray())
    slots19To25ReviewAngleMedianDegrees = $clusterMedianAngle
    slot18ReviewAngleDegrees = $slot18Angle
    slot18AbsoluteDifferenceFromSlots19To25MedianDegrees = [Math]::Abs($slot18Angle - $clusterMedianAngle)
    conclusions = [ordered]@{
        slot16 = 'HOLD_ONLY_MATCHED_PHYSICAL_CANDIDATE_FAILS_WIDTH_BELOW_FROZEN_MINIMUM'
        slot17 = 'HOLD_TWO_MATCHED_PHYSICAL_CANDIDATES_EACH_FAILS_ONE_DIFFERENT_FROZEN_CRITERION'
        slot18 = 'DETECTOR_PASS_SINGLE_PHYSICAL_CANDIDATE_PASSES_ALL_FROZEN_MORPHOLOGY_CRITERIA'
        slot18CohortAngleOutlierIsDetectorFailure = $false
        thresholdChangeSupportedByCurrentEvidence = $false
        algorithmChangeSupportedByCurrentEvidence = $false
        freshHotspotSuccessorAuthorized = $false
        frozenPost2RerunRequiredBeforeAnyFreshHotspotSuccessor = $true
        frozenPost2RerunPerformedByThisAnalysis = $false
    }
    imageBytesRead = $false
    sourceImageBytesRead = $false
    o3d3r4RerunPerformed = $false
    taskOrProcessActionPerformed = $false
    providerActivated = $false
    healthyProcessorTouched = $false
    rotationAuthorityGranted = $false
    holdsCleared = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}

if ($Preflight) {
    $result.mutationsPerformed = $false
    $result | ConvertTo-Json -Depth 16
    return
}

Assert-True (-not (Test-Path -LiteralPath $resultPath)) 'O3J1 Slots16-18 diagnosis already exists.'
Write-JsonCreateNew -Path $resultPath -Value $result
$result | ConvertTo-Json -Depth 16
