$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p005.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('6LwXfQFBWUWHudfr9S7J6VREHRAaDP8+ytJCkEGw0BWl1EfGkhXS4E9e8BtV7viiGT0I0VoIX1EwldjuatNOp05Uisz7As4T3PMMngEBjLYj9gK8pZJoiR+JIpuhGDu1j3y1tMNMiRqHWVjTkpE3BrZpB6i4U8fVb3Q+SjtIEj92mF0XWISygYhBedH6R97+ndqzlW8RsUq25nCQ9DLQGwL/mB35CEvvMzPPeRgK2wIWsi57/Yo8IVZnCGN70ZSrwWRAw/6spig9xqtZvJYjLCFx0ArMrCcczo9ouGm1ibr2NDUH7Cga0TPSZ4eBiYT8JJ3+Ps2nYO7OOQS03IJ4otEDdJM15QUR6HLtH21RD71mdaOKpZ5bnXw4TlnLMaHQoP8uSFLYtUXT0+adwbWFGjo0OM1rdF7uWa/nxdpeGPbLCHIgueBMllE9lAstp1Itt9wSJWpoexQYpnM8YJNpgdFVKGLcgygO1iUtTZuSXRMvCEsPlbBKeahd46XoymeUjlNWFWX5TLctnxcjLZ9pAqi8IHrZ1uqwLdGBdlaHSdkgJomH4W/A5VaHsrwJ8AFZX0FIozBRw7gX3cbriZSVea8IjB4JBaULCJDs7Fuwh3vJToHKYgKoOl2EVOVUjVTcT9g7NVW8Gc/A8o7ydL5JwFbTqZZlTh7vvgfimByEgAIdMl8OKpCxEoIIXUH83A+uEEoNJ8w8zdf62bQ4BWAUVECigQoQRYJAil6pVhs2etubpTaW1tgvXVkOxq9SswZ33NXYm2KjBYDakf4Vxkhp6ZHvzsAog7NYjjrYuxHujbl70um7Ja3M+dLBvbK4VUplBXbKqoO0tmaBD+D8HAbcPMfDCJ81pai0zWd11mob21cNjv1tEzGYG2i9JtSj21peZ+uKmAAIxTpCSetnYeLe7a/SxCovdI0Xyh0HOQNumvE1hLAfa0dUWhFXcdOho1bXVCu73VZABtGx0TLwnBbxEM8zbRGcdLtSi7tyi8VxNnCcFnAA/+4RK6yb7+mgAO1y')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'2557D8E8A59ECBD16F3AD2F43E65F38F735A336AF1A71D2C0047D86DA0D39210'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p005.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress