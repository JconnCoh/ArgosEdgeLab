$ErrorActionPreference='Stop'
$p=Get-Process -Id 15648 -ErrorAction SilentlyContinue
$f='D:\R34C953R2\SUMMARY.json';$s=Get-Content $f -Raw|ConvertFrom-Json
[ordered]@{observation=5;state=if($s.complete){'COMPLETE'}elseif($p){'RUNNING'}else{'STOPPED'};processPresent=($null-ne$p);completed=$s.pairCount;failures=$s.failureCount;counts=$s.counts;complete=$s.complete;sha256=(Get-FileHash $f).Hash;stderrEmpty=((Get-Item 'D:\R34C953R2\runner.stderr.log').Length-eq0);imageBytesReturned=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 3 -Compress
