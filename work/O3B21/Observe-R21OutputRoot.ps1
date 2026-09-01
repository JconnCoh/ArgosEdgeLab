$outputRoot = 'D:\R21TG1'
$rootExists = Test-Path -LiteralPath $outputRoot
$files = @()
if ($rootExists) {
    $files = @(Get-ChildItem -LiteralPath $outputRoot -File -ErrorAction Stop |
        Sort-Object Name |
        Select-Object -First 20 Name, Length, LastWriteTimeUtc)
}

[ordered]@{
    schema = 'argos_ocv03_r21_output_root_observation_v1'
    state = 'OBSERVED_R21_OUTPUT_ROOT'
    computerName = $env:COMPUTERNAME
    outputRoot = $outputRoot
    outputRootExists = $rootExists
    resultExists = Test-Path -LiteralPath (Join-Path $outputRoot 'RESULT.json')
    summaryExists = Test-Path -LiteralPath (Join-Path $outputRoot 'SUMMARY.json')
    boundedFiles = $files
    mutationsPerformed = $false
    taskOrProcessActionPerformed = $false
    sourceImageBytesRead = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 5 -Compress
