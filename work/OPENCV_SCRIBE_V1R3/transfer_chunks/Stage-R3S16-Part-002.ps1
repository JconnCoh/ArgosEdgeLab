$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p002.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('Wjz7zOdZh30Fcr9ZxqAgZtn/xyTIOA6AG/FHMgiOAOsUBgLH5jqO5ETjYKy9hEdZY/XFDxJb/EhRNDlCLXPjL1JSmeKNdVmciqEUOlGcNkbub+PR9eU/2b/Fr/540LtVPwa/9y8FkizZEe6DaYnTxsJHXHkDDrMey1NkOSzij2EQ8a71R1Q9WfDBifI3q7WaCgHkgHzgUdZtm6wreRwH1EbE+Fioy2ygtOa8DaMPejA3URjAOg/SNIjuzaE7jE+gSFOTV+Q8r1ptV2jzPk9s0Mlxw8HpDKJM7bkSAHSDEyW/5ksPVGzUZFGbL/N0nPi2BquxOnvRzqXpQoL9wpqg64ofb9jZuUm6ZM56iwjAnBz7nD0jBacCTY39b3b2mvK2BiH9ni/5/Iur6UvtWeyL/daUhcGChTzCpzX2U5e1mgfWnTUZXA3ZVavNAF4sPTiNwHmJb715Fu5YxqN89NKGXoV5t8xpQUynzOo1JWiwoNBdRgkS/QVYofjEScLneCjqsrPXrE6GgsDPl4kNs2X1rBo7ZbZN6r15w17U2P9hP9fgkYZsCkgCiCBygH0+j33u3ifezsV+FwVprlQI4udxiEt//tBuBCvcEtIM5Ea2rDlYOrwaD3oXbn90ORrrcRDVgpQInz3yUB7O5/Em9FGoChLFIasgEWeCfxH5tOOwjsOad0Tn2ARR1nolYEE3jArArX3ACfcLoO39oDgztt1+zZ4Jik5Z66zJnskmT9nPPyP3+/CgfV6DmTqvFdCd6xnxki9w5An8jRfKOYHpoXqgwxLPDzZpBxZ/5TRZlvUJj8TBn2Ah+NcmePBCHmUsXlAzBswfT/5vyuZhsF5zH/Dx+8QL2Yp7UQOOsbnG7QhVnHUZ0AOqxppPO+07MceqomQN+RNJd1jq83W27MKT/if31ct3Yuyk8uglXnTPbcQuHuyMB6J5WaUpHq28bbDarOymw7awWnA8JEhLggQRggiq66wFoKcKFCZDtFXGuCtg3BUwCoIEyl0FynSzAv3TJjqp')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'372958026DB7AF0BD1AE2D2B35926490F383F2B7E5F53D0CE492C63473A7C198'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p002.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress