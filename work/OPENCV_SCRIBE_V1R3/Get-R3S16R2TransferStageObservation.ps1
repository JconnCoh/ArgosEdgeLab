$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
function Get-ExactSha([string]$path){$stream=[IO.File]::OpenRead($path);$hasher=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','')}finally{$hasher.Dispose();$stream.Dispose()}}
$root='D:\A2\x\r3s16r2_8A6DE04B';$partRoot=Join-Path $root 'parts';$helper=Join-Path $root 'ctl\StagePart.ps1';$rows=@()
if(Test-Path -LiteralPath $partRoot -PathType Container){foreach($file in @(Get-ChildItem -LiteralPath $partRoot -Filter 'p*.bin' -File|Sort-Object Name|Select-Object -First 32)){$rows+=@{name=$file.Name;bytes=$file.Length;sha256=(Get-ExactSha $file.FullName)}}}
$targets=@('D:\A2\x\r3s16r2_8A6DE04B\R3S16_PAYLOAD.zip','D:\A2\x\r3s16r2_8A6DE04B\pkg','D:\A2\w\ocv\R3S16_20260826T002500Z_8A6DE04B','D:\A2\o\ocv\R3S16_20260826T002500Z_8A6DE04B','D:\A2\x\R3S16R_20260826T002500Z_8A6DE04B.zip')
[ordered]@{schema='argos_r3s16r2_transfer_stage_observation_v1';state='PASS_R3S16R2_TRANSFER_STAGE_OBSERVATION';computerName=$env:COMPUTERNAME;helper=@{exists=(Test-Path -LiteralPath $helper -PathType Leaf);sha256=if(Test-Path -LiteralPath $helper -PathType Leaf){Get-ExactSha $helper}else{''}};parts=$rows;targets=@($targets|ForEach-Object{@{path=$_;exists=(Test-Path -LiteralPath $_)}});imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress -Depth 5
