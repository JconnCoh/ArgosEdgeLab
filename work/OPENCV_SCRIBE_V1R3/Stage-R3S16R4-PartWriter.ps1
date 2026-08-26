param([string]$Part,[string]$Data,[string]$ExpectedSha)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16r4_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
if($Part-notmatch'^p[0-9]{3}\.bin$'){throw'Part name'}
$path=Join-Path $root $Part
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String($Data)
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
if($hash-ne$ExpectedSha){throw'Part hash'}
"PASS_R3S16R4_PART|$Part|$hash"
