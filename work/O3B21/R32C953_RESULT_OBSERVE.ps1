$ErrorActionPreference='Stop'
$root='D:\R32C953'
$summaryPath=Join-Path $root 'SUMMARY.json'
$resultsPath=Join-Path $root 'RESULTS.csv'
$failuresPath=Join-Path $root 'FAILURES.json'
$process=Get-Process -Id 15456 -ErrorAction SilentlyContinue
$summary=$null
if(Test-Path -LiteralPath $summaryPath -PathType Leaf){$summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json}
function FileFact([string]$path){
 if(Test-Path -LiteralPath $path -PathType Leaf){
  $item=Get-Item -LiteralPath $path
  return [ordered]@{exists=$true;bytes=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;lastWriteUtc=$item.LastWriteTimeUtc.ToString('o')}
 }
 return [ordered]@{exists=$false}
}
$rows=@(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)
[ordered]@{
 schema='argos_r32c953_bounded_result_observation_v1'
 state=if($summary -and $summary.complete -eq $true){'COMPLETE'}elseif($summary){'RUNNING'}else{'NO_SUMMARY'}
 processPresent=($null-ne$process)
 processCreationUtc=if($process){$process.StartTime.ToUniversalTime().ToString('o')}else{$null}
 outputDirectoryCount=$rows.Count
 pairCount=if($summary){$summary.pairCount}else{$null}
 sourceProblemCount=if($summary){$summary.sourceProblemCount}else{$null}
 failureCount=if($summary){$summary.failureCount}else{$null}
 counts=if($summary){$summary.counts}else{$null}
 summary=FileFact $summaryPath
 results=FileFact $resultsPath
 failures=FileFact $failuresPath
 mutationsPerformed=$false
 imageBytesRead=$false
}|ConvertTo-Json -Depth 8 -Compress
