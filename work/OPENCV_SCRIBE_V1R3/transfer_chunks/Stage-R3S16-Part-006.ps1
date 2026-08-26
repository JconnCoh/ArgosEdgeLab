$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p006.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('zQdpRDsQomw5dHDJYoJqW7MaOA9xpA5UU4SxriEnocgp6KK5akX1l+1BdUpLGGzjeJSVdR2DZybwWfbIwwdeB2QqHwqokLakGdfE+Xn82yKI4LT03UMsph8OFEDm1NoJ6UlHzDk+9YX6p0Z9mIMDs1WkYPsECqrZvYDjIBVk1ArzL0v/UhZQLT2NCxT0j/CBjNhEBEoJEClpbq61wqlsz3El18pzw8d+U4DS1wFdcW/LTz16ywY4Q2k1tvVCalC1Nl3ICFISCqKaKAqS/3MMTw6qBKNEVkfPahAtDqNQWUiGGQv8D8QPAR0HLBXHZPYG9WtWl+OQaxolMEna3bQje6xMVxiNm25WrgcWvQhdCLk5Zu9Mh8Eq0GfdsyNTDWkrOrUFjtMCVnjGEFgcZ/HE+7XZYVPbshzWbDRrd98OHW+bZFVGfJu539dSntyB460CdCEpcv6Fo61XIGyAaTAt+j6gEgRgO8JeBeCiYjlVAgO3cw03qlpYesyn6tvdtHDgI0usQEuVN4qom9SKUlmPho4Lm5YZNk4/Tw0hP2jjoh+cuu8KL6/EIOcq5ZnPF94mzGwTMTru1GEYg+7ZqbJpqfNm+XygFPB83EQ7pXwk3U5HpRYJbnBYyWtShz/TFpjwZPgerqdabsw7yJS0t5IzcwuAWC9gkgAKK+1onUopQWTOQe5sNav4stWsiaZlvu9/U9utyrZbsu0F1KWajDaTybUO7UBYP1mytvYWlFa9CE6xzRQ3AUWW36E8hUrWR5Ersw0qkyEMoxZCgN4URHJaQcyL0haWihE3G0Xu7opkCEge4HMzUwtHagpQMDrAhFiCNm0h0/QWViOrA9qfKoru2KlsWxa17u72eGS+WmmWBNE9WCMQu5j6yWYFRg/4asrigliV60mQKDm+YlnZal05WAAnydq0g0tLrCy16S2CCKNz1LkY0lorEquqDsAihFetL+2EVKxODIImW0MjU2J3KR5yDzIFaXTaaakDMq4UL9m5c+mxM0LUxTITzVaakIRi')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'B4DB936BE9FAE1B675221713A2EDAFFBDDB6777E9598CE05DFD7CA9344195876'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p006.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress