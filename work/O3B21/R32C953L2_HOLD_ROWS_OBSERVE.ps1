$s=Get-Content -LiteralPath 'D:\R32C953L2\SUMMARY.json' -Raw|ConvertFrom-Json
$f=Get-Content -LiteralPath 'D:\R32C953L2\FAILURES.json' -Raw|ConvertFrom-Json
$rows=@($f.rows|Select-Object -First 20|ForEach-Object{[ordered]@{identity=$_.identity;stage=$_.stage;state=$_.state;reasonCode=$_.reasonCode;holdCount=@($_.holds).Count;angle=$_.notchAngleDegrees;candidateCount=$_.pairedCandidateCount}})
[ordered]@{state='PASS_R32C953L2_HOLD_ROWS_OBSERVED';pairCount=$s.pairCount;failureCount=$s.failureCount;sourceProblemCount=$s.sourceProblemCount;counts=$s.counts;rows=$rows;truncated=(@($f.rows).Count-gt20);imageBytesRead=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 6 -Compress
