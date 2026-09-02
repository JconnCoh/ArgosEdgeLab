$ErrorActionPreference='Stop'
$run='D:\R32C953L2RT';$root='D:\R32M1';$py='D:\AFCV1\rt\python.exe'
if(Test-Path -LiteralPath $root){throw 'R32M1 fresh root exists'}
[void](New-Item -ItemType Directory -Path $root)
$ids=@(@('17','BackSide_BowComp_Lot_62625-956_62625-956_2_533be53514'),@('21','BackSide_BowComp_Lot_62625-956_62625-956_2_fd9890b702'),@('24','BackSide_BowComp_Lot_62625-956_62625-956_2_237d648310'))
$cfg=Get-Content -LiteralPath (Join-Path $run 'BACKSIDE_NOTCH_CONFIG_R13.json') -Raw|ConvertFrom-Json
$rows=@()
foreach($rev in 20..32){foreach($x in $ids){
 $src=Get-Content -LiteralPath "D:\R32C953L2\i\$($x[1])\result.json" -Raw|ConvertFrom-Json
 $out=Join-Path $root "R$($rev)_S$($x[0])";$jobPath=Join-Path $root "J$($rev)_S$($x[0]).json"
 $job=[ordered]@{bf=$src.bf.path;df=$src.df.path;bfSha256=$src.bf.sha256;dfSha256=$src.df.sha256;output=$out;maximumDimension=2400;radialEngine=$cfg.radialEngine;radialEngineSha256=$cfg.radialEngineSha256;radialParameters=$cfg.radialParameters}
 [IO.File]::WriteAllText($jobPath,($job|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
 & $py -B (Join-Path $run "Detect-BacksideNotchOpenCvR$rev.py") --job $jobPath 2>&1|Out-Null
 if($LASTEXITCODE-ne0){throw "R$rev S$($x[0]) detector failed"}
 $r=Get-Content -LiteralPath (Join-Path $out 'RESULT.json') -Raw|ConvertFrom-Json;$pairs=@($r.pairedCandidates)
 $rows+=[ordered]@{revision=$rev;slot=[int]$x[0];pairCount=$pairs.Count;bfCandidateCount=@($r.bf.candidates).Count;dfCandidateCount=@($r.df.candidates).Count;angles=@($pairs|ForEach-Object{$_.meanAngleDegrees})}
}}
$summary=[ordered]@{schema='argos_r32_three_revision_matrix_v1';state='PASS_R20_R32_THREE_CASE_MATRIX';rows=$rows;sourceMutationPerformed=$false;reviewOnly=$true}
$path=Join-Path $root 'SUMMARY.json';[IO.File]::WriteAllText($path,($summary|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
[ordered]@{state=$summary.state;rowCount=$rows.Count;summarySha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}|ConvertTo-Json -Compress
