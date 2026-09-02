$ErrorActionPreference='Stop'
$p=Get-Process -Id 36444 -ErrorAction SilentlyContinue
$path='D:\R34C953\SUMMARY.json';$s=$null
if(Test-Path -LiteralPath $path -PathType Leaf){$s=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}
$e=Get-Content -LiteralPath 'D:\R34C953\runner.stderr.log' -Tail 8 -ErrorAction SilentlyContinue|Out-String
[ordered]@{state=if($s-and$s.complete){'COMPLETE'}elseif($p){'RUNNING'}else{'STOPPED'};processPresent=($null-ne$p);pid=36444;pairCount=if($s){$s.pairCount}else{0};failureCount=if($s){$s.failureCount}else{0};complete=if($s){$s.complete}else{$false};stderr=$e;summaryExists=($null-ne$s);imageBytesReturned=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
