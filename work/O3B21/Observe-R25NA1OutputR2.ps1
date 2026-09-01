[CmdletBinding()]
param([switch]$Rehearsal)

$root = 'D:\R25NA1'
$rows = New-Object Collections.Generic.List[object]
for ($ordinal = 0; $ordinal -lt 24; $ordinal++) {
    $number = '{0:D2}' -f $ordinal
    $jobRelative = 'J' + $number + '.json'
    $resultRelative = 'O' + $number + '\RESULT.json'
    $relativeLeaves = @($jobRelative, $resultRelative)
    if ($relativeLeaves.Count -ne 2) { throw "Invalid relative-leaf count for ordinal $ordinal." }
    foreach ($relative in $relativeLeaves) {
        $path = Join-Path $root $relative
        $exists = Test-Path -LiteralPath $path -PathType Leaf
        $item = if ($exists) { Get-Item -LiteralPath $path -ErrorAction Stop } else { $null }
        $rows.Add([ordered]@{
            relativePath = $relative.Replace('\', '/')
            exists = $exists
            bytes = if ($exists) { [int64]$item.Length } else { $null }
            lastWriteUtc = if ($exists) { $item.LastWriteTimeUtc.ToString('o') } else { $null }
        })
    }
}
if ($rows.Count -ne 48) { throw "Invalid output metadata row count: $($rows.Count)." }
[ordered]@{
    schema = 'argos_r25na1_postfailure_output_metadata_v2'
    state = 'PASS_R25NA1_POSTFAILURE_OUTPUT_METADATA'
    computerName = $env:COMPUTERNAME
    outputRoot = $root
    outputRootExists = Test-Path -LiteralPath $root -PathType Container
    rows = $rows
    presentCount = @($rows | Where-Object { $_.exists }).Count
    absentCount = @($rows | Where-Object { -not $_.exists }).Count
    imageBytesRead = $false
    taskOrProcessActionPerformed = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6 -Compress
