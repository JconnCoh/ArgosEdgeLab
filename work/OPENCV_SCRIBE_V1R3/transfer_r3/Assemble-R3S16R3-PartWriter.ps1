$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16r3_8A6DE04B\ctl'
$out=Join-Path $root 'StagePart.ps1'
if(Test-Path -LiteralPath $out){throw'Exists'}
$stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{foreach($n in @('h000.bin','h001.bin')){$b=[IO.File]::ReadAllBytes((Join-Path $root $n));$stream.Write($b,0,$b.Length)}}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash;if($hash-ne'019B558FF269B2CD48B8432AF6398E4D3E7D5E3F5C18EB3C4183864C06A943C8'){throw'Hash'}
'PASS_R3S16R3_WRITER_ASSEMBLED'