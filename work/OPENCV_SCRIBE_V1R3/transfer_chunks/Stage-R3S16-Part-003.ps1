$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p003.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('GI7prgX8BIvgzmHb1hS+OaxzJwYRPnUC3PweYANzswL4dB/mIrDo9DzeRBl2Y9didbZr1nQd9ozZWyjcNmu6Ll0NdDgbTUcMyHOFsi4YqOJsUGftRrNWfPKinYsraRMQ60I2KdaKsUAEI+D6EN935Ls8Uerf6kCJBYXlxP5NRBbKIFetBvFLrQlFRnFdLNhW7Z079QXYUNR7Y2BBmFNJj34mySvuHUCWPCcm90HkwmJaeVv7hVqnz58zJaQkyE6CnDmqDYA5l1Iajt4BCnfVlylQo+p2CGl1XSrWlCKhk/dMg2zFQDxiTeAn1VAVAzx7xtoE3E03K9YVR3ZbYmikm5XtQ80uqal3GlLxDWvx+qt84HZArZQ58rBla2Jw2hxWQqxrK3sF6xpdZqeSPEUfe8a221o1lew5oa+EGqaHjngV6t3u6ah5mJK9tkC/5BFYcPvoUDyiYUBD4lGmeX4VRFq6th123qwZYLK+gNOc03ZYqwgJRAVRZidg0rY1pfVCi0iJnGr1ZFdVFQR4gYqqumrJbB0kkTKv0bCT16hoHTDsBAZjiZgE5Dh2EkfqrdYhRyLEPMZJvmPkJJ4yO98KiwbQCoZlp6zZOMuZ61lpEItIhNAnyzGINOdLIncHidztJVLYY7+LSj1fJTRPoFMOJqgztiois0e+go5sjEudtaq6TFHtyCSSrwRVrhkIXHjOSalIBbK3LsGoyKzdNcAn5K25XW9V7oEoybkHWqyQCwJ7hRxtAJhdK9CwHx6kNfeiva1GcQJyGHwPjfRfSWaL9qN1w48PkCGtEFWPlNEMLSfJiv0CspqcKWWLLSl5lJa9vwfPscoB3SHhaRw+gDthwRMezbkLRwk74aGXBQ/iFx4rHTTHGKZVOA4J4wl8E1RCc2BcxqOCgaWR8HXozbltPbccZv3xhzyurBO+ALOfdIyBhSPzAlCZc1xgjskCOKfZeUVpXtL1QFEQyITZKZIUHzpXjVW3VU3wcMV46l0E95uE+x321eiGtjuBcaormpiK')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'4A48464065AE6CA3A6C095A3AB95C76954584F660492FA63E62E2916D5A2D276'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p003.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress