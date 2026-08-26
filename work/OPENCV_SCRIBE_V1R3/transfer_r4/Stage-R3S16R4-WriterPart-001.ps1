$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16r4_8A6DE04B\ctl'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'h001.bin'
if(Test-Path -LiteralPath $path){throw'Exists'}
$bytes=[Convert]::FromBase64String('YXJ0IGV4aXN0cyd9CiRieXRlcz1bQ29udmVydF06OkZyb21CYXNlNjRTdHJpbmcoJERhdGEpCiRzdHJlYW09W0lPLkZpbGVdOjpPcGVuKCRwYXRoLFtJTy5GaWxlTW9kZV06OkNyZWF0ZU5ldyxbSU8uRmlsZUFjY2Vzc106OldyaXRlLFtJTy5GaWxlU2hhcmVdOjpOb25lKQp0cnl7JHN0cmVhbS5Xcml0ZSgkYnl0ZXMsMCwkYnl0ZXMuTGVuZ3RoKX1maW5hbGx5eyRzdHJlYW0uRGlzcG9zZSgpfQokaGFzaD0oR2V0LUZpbGVIYXNoIC1MaXRlcmFsUGF0aCAkcGF0aCAtQWxnb3JpdGhtIFNIQTI1NikuSGFzaAppZigkaGFzaC1uZSRFeHBlY3RlZFNoYSl7dGhyb3cnUGFydCBoYXNoJ30KIlBBU1NfUjNTMTZSNF9QQVJUfCRQYXJ0fCRoYXNoIgo=')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'83D3672B0A103DA0EA762512FED2C52C31F101DC06BD051AD4CB343AA263AFBA'){throw'Hash'}
'PASS_R3S16R4_WRITER_PART|h001.bin'