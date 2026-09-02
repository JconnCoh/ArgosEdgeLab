$ErrorActionPreference='Stop'
$s=Get-Content 'D:\R34C953R2\SUMMARY.json' -Raw|ConvertFrom-Json
$m=@($s.failures|Where-Object{$_.stage-eq'notch'-and$_.state-eq'HOLD_BACK_NOTCH_MULTIPLE_BF_DF_MATCHES'})
$rows=@($m|ForEach-Object{$z=Get-Content (Join-Path $_.diagnosticRoot 'RESULT.json') -Raw|ConvertFrom-Json;$p=@($z.pairedCandidates);$d=$z.bf.multiPairExteriorCleanResolution;$a=[double]$p[0].meanAngleDegrees;$b=[double]$p[1].meanAngleDegrees;$x=[math]::Abs($a-$b);$sep=[math]::Min($x,360-$x);[ordered]@{identity=$_.identity;angles=@($a,$b);separation=$sep;scores=@($p[0].score,$p[1].score);clears=@($d.rows[0].bothChannelsExteriorClear,$d.rows[1].bothChannelsExteriorClear)}})
[ordered]@{state='PASS_R34_MULTIPLE_SEPARATION_OBSERVATION';completed=$s.pairCount;rows=$rows;imageBytesReturned=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 4 -Compress
