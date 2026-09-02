$p=Get-Process -Id 30804 -ErrorAction SilentlyContinue
$path='D:\R32C953L2\SUMMARY.json';$s=$null
if(Test-Path -LiteralPath $path -PathType Leaf){$s=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}
$e=Get-Content -LiteralPath 'D:\R32C953L2\runner.stderr.log' -Tail 8 -ErrorAction SilentlyContinue|Out-String
[ordered]@{state=if($s-and$s.complete){'COMPLETE'}elseif($p){'RUNNING'}else{'STOPPED'};processPresent=($null-ne$p);pairCount=if($s){$s.pairCount}else{0};failureCount=if($s){$s.failureCount}else{0};complete=if($s){$s.complete}else{$false};stderr=$e;summaryExists=($null-ne$s);imageBytesReturned=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
