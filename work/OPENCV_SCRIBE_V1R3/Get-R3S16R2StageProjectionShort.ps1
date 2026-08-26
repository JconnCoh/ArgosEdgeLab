$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$r='D:\A2\x\r3s16r2_8A6DE04B';$h=Join-Path $r 'ctl\StagePart.ps1';$p=Join-Path $r 'parts'
$count=if(Test-Path -LiteralPath $p){@(Get-ChildItem -LiteralPath $p -Filter 'p*.bin' -File|Select-Object -First 32).Count}else{0}
$targets=@('D:\A2\x\r3s16r2_8A6DE04B\R3S16_PAYLOAD.zip','D:\A2\x\r3s16r2_8A6DE04B\pkg','D:\A2\w\ocv\R3S16_20260826T002500Z_8A6DE04B','D:\A2\o\ocv\R3S16_20260826T002500Z_8A6DE04B','D:\A2\x\R3S16R_20260826T002500Z_8A6DE04B.zip')
[ordered]@{state='PASS_R3S16R2_SHORT_STAGE_PROJECTION';helperExists=(Test-Path -LiteralPath $h -PathType Leaf);helperSha256=if(Test-Path -LiteralPath $h -PathType Leaf){(Get-FileHash -LiteralPath $h -Algorithm SHA256).Hash}else{''};payloadPartCount=$count;existingSuccessorTargetCount=@($targets|Where-Object{Test-Path -LiteralPath $_}).Count;imageBytesRead=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
