$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16r2_8A6DE04B\ctl'
$out=Join-Path $root 'StagePart.ps1'
if(Test-Path -LiteralPath $out){throw'Exists'}
$stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{foreach($n in @('h000.bin','h001.bin')){$b=[IO.File]::ReadAllBytes((Join-Path $root $n));$stream.Write($b,0,$b.Length)}}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash;if($hash-ne'35BBCDA143AA12CB90C19978570B2CD1387BBF8A1ED48A652B079520D8DC2A70'){throw'Hash'}
'PASS_R3S16R2_WRITER_ASSEMBLED'