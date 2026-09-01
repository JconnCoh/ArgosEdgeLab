[CmdletBinding()]
param([switch]$Rehearsal)

$root = 'D:\R25NA1'
$pairStates = New-Object Collections.Generic.List[string]
$completePairCount = 0
$partialPairCount = 0
$absentPairCount = 0
for ($ordinal = 0; $ordinal -lt 24; $ordinal++) {
    $number = '{0:D2}' -f $ordinal
    $jobPath = Join-Path $root ('J' + $number + '.json')
    $resultPath = Join-Path $root ('O' + $number + '\RESULT.json')
    $jobExists = Test-Path -LiteralPath $jobPath -PathType Leaf
    $resultExists = Test-Path -LiteralPath $resultPath -PathType Leaf
    $pairStates.Add($number + ':' + ([int]$jobExists).ToString() + ([int]$resultExists).ToString())
    if ($jobExists -and $resultExists) { $completePairCount++ }
    elseif ($jobExists -or $resultExists) { $partialPairCount++ }
    else { $absentPairCount++ }
}
if ($pairStates.Count -ne 24) { throw "Invalid pair-state count: $($pairStates.Count)." }
[ordered]@{
    schema = 'argos_r25na1_postfailure_output_compact_v1'
    state = 'PASS_R25NA1_POSTFAILURE_OUTPUT_COMPACT'
    computerName = $env:COMPUTERNAME
    outputRootExists = Test-Path -LiteralPath $root -PathType Container
    pairStates = @($pairStates)
    completePairCount = $completePairCount
    partialPairCount = $partialPairCount
    absentPairCount = $absentPairCount
    imageBytesRead = $false
    taskOrProcessActionPerformed = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 4 -Compress
