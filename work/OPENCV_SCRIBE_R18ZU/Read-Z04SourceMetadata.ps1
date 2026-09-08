$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals\62623-743_20260720111120_Slot04'
$proposalPath = Join-Path $root 'SCRIBE_PROPOSAL.json'
$summaryPath = Join-Path $root 'scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json'
foreach ($path in @($proposalPath, $summaryPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing exact metadata leaf: $path" }
}
$proposal = Get-Content -LiteralPath $proposalPath -Raw | ConvertFrom-Json
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
[pscustomobject][ordered]@{
    computerName = $env:COMPUTERNAME
    proposalPath = $proposalPath
    proposalBytes = (Get-Item -LiteralPath $proposalPath).Length
    proposalSha256 = (Get-FileHash -LiteralPath $proposalPath -Algorithm SHA256).Hash
    proposal = $proposal
    summaryPath = $summaryPath
    summaryBytes = (Get-Item -LiteralPath $summaryPath).Length
    summarySha256 = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash
    summary = $summary
    imageBytesRead = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 20 -Compress
