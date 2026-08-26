$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16r2_8A6DE04B\ctl'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'h000.bin'
if(Test-Path -LiteralPath $path){throw'Exists'}
$bytes=[Convert]::FromBase64String('cGFyYW0oW3N0cmluZ10kUGFydCxbc3RyaW5nXSREYXRhLFtzdHJpbmddJEV4cGVjdGVkU2hhKQokRXJyb3JBY3Rpb25QcmVmZXJlbmNlPSdTdG9wJwpTZXQtU3RyaWN0TW9kZSAtVmVyc2lvbiBMYXRlc3QKaWYoJGVudjpDT01QVVRFUk5BTUUtbmUnQTEwMjU2NDUxMDEnKXt0aHJvdydXcm9uZyBob3N0J30KJHJvb3Q9J0Q6XEEyXHhccjNzMTZyMl84QTZERTA0QlxwYXJ0cycKW0lPLkRpcmVjdG9yeV06OkNyZWF0ZURpcmVjdG9yeSgkcm9vdCl8T3V0LU51bGwKaWYoJFBhcnQtbm90bWF0Y2gnXnBbMC05XXszfVwuYmluJCcpe3Rocm93J1BhcnQgbmFtZSd9CiRwYXRoPUpvaW4tUGF0aCAkcm9vdCAkUGFydAppZihUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRwYXRoKXt0aHJvdydQ')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'EE7634B281DD54C236416A049AE86ECF912319ED13047D46B5FBB4218573E52D'){throw'Hash'}
'PASS_R3S16R2_WRITER_PART|h000.bin'