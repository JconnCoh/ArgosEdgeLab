$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p021.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('QASgy+wAhQASzKLQQ0EA4jAIaYAo/KsSkR9CD/1fQjw1SSPX0simkA8aZS0atZZtdzxaepnn2M7zz3mui9s8/8ZMl+dGrts8H9ozjmaMv569T654ymKWsjlh/BrPpzHLlo+vo3HT8x2EGcGxG0YUYBIT4BM3skPfwTEMghBHNIwdHwQEuhAGNsAI+TFFjgOiEMTQtsMjs7wrqr6UZfL9Q47Ren+T/DYex5eJkZXo1K1MjFyru4FqU93vtu3kxbmgvzNvI9HYLP5pM37r8UI3a2VqWY7EAP1nLjxDP4jHsj6eJNRKYYrtWT7ybieLTpap3Cjd7NP2cczjSvdNKUt2V8jdML1mR+jDGaAWd6ru63fa/K6aDVW1bMYXCEQAPDYioilVKcaSccdFbZRsuv18nHVyR+XGyEN7905e677b9V2qdfcwT/rf5ekwjYu+22rz6PkxPJfk50VTDf860x9jEn2na9Gp4ig+/AD7MPjOCNWoZnOck54s39WnCerJys7osi+GkJ8xqMU9qaQwV7oqh1zs14Z0XHy9+BNQSwECFAAUAAAACABRmRld4azxDu8oAABQkQAAGAAAAAAAAAAAAAAAAAAAAAAAQXJnb3NPcGVuQ3ZTY3JpYmVWMVIzLnB5UEsBAhQAFAAAAAgAPZsZXZqJVPOHDwAAGS0AABkAAAAAAAAAAAAAAAAAJSkAAEludm9rZS1SM1Nsb3QxNkRpcmVjdC5wczFQSwECFAAUAAAACABimxld6qERjXQCAABSBAAAFQAAAAAAAAAAAAAAAADjOAAAUEFZTE9BRF9NQU5JRkVTVC5qc29uUEsBAhQAFAAAAAgAG5sZXfM3SdTZBAAAFQ4AABkAAAAAAAAAAAAAAAAAijsAAFIzX1NMT1QxNl9ESVJFQ1RfSk9CLmpzb25QSwUGAAAAAAQABAAXAQAAmkAAAAAA')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'3EA75FFF400A85AC667826B269AD737A502DCC3D5A5DF70C6054ED970235627A'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p021.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress