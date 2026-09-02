$root = 'D:\R31VAL2'
$expectedCount = 298
$completeBits = ''
$resultCount = 0

for ($ordinal = 0; $ordinal -lt $expectedCount; $ordinal++) {
    $resultPath = Join-Path $root (('O{0:D2}\RESULT.json' -f $ordinal))
    if (Test-Path -LiteralPath $resultPath) {
        $completeBits += '1'
        $resultCount++
    }
    else {
        $completeBits += '0'
    }
}

[ordered]@{
    schema                       = 'argos_r31val2_postfail_fast_observation_v1'
    computerName                 = $env:COMPUTERNAME
    rootExists                   = Test-Path -LiteralPath $root
    caseFileExists               = Test-Path -LiteralPath (Join-Path $root 'FROZEN_CASES.json')
    summaryExists                = Test-Path -LiteralPath (Join-Path $root 'SUMMARY.json')
    jobCount                     = @(Get-ChildItem -LiteralPath $root -File -Filter 'J*.json' -ErrorAction SilentlyContinue).Count
    resultCount                  = $resultCount
    completeBits                 = $completeBits
    imageBytesRead               = $false
    taskOrProcessActionPerformed = $false
    mutationsPerformed           = $false
} | ConvertTo-Json -Compress
