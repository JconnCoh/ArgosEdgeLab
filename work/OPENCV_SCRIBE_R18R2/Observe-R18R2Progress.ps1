[CmdletBinding()]
param([switch]$Preflight = $true)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Specify -Preflight.' }
$root = 'D:\A2\o\ocv\R18R2'
if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw 'R18R2 output root is absent.' }
function Read-SmallJson([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    if ((Get-Item -LiteralPath $Path).Length -gt 1048576) { throw "Oversized R18R2 JSON: $Path" }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}
$runningPath = Join-Path $root 'RUNNING.json'
$completePath = Join-Path $root 'COMPLETE.json'
$running = Read-SmallJson $runningPath
$complete = Read-SmallJson $completePath
$casesRoot = Join-Path $root 'c'
$caseDirs = @(if (Test-Path -LiteralPath $casesRoot -PathType Container) { Get-ChildItem -LiteralPath $casesRoot -Directory -ErrorAction Stop })
$resultRows = @($caseDirs | ForEach-Object {
    $resultPath = Join-Path $_.FullName 'RESULT.json'
    if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
        $item = Get-Item -LiteralPath $resultPath
        [pscustomobject]@{caseId=$_.Name;bytes=[int64]$item.Length;lastWriteUtc=$item.LastWriteTimeUtc.ToString('o')}
    }
})
[ordered]@{
    schema='argos_opencv_scribe_r18r2_progress_observation_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');
    state=$(if($null -ne $complete){'COMPLETE_PRESENT'}elseif($null -ne $running){'RUNNING_PRESENT'}else{'LAUNCH_ONLY'});
    outputRoot=$root;running=$running;complete=$complete;caseDirectoryCount=$caseDirs.Count;
    resultCount=$resultRows.Count;results=$resultRows;
    sourceImagesReadByObservation=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8 -Compress
