$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p015.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('pLWbO4zj26qDkwix2dObjBKUzG6rFzDLghmUH9G0Vk8wBTsi+ZHOCb4HBc1ms+P+AeasR/OgtmXGNJMfqxklMFj0bvqDho9ieHt2xq53CIOoJki61XmQzSHp3YxguCSIrhsOWacUz0iQzteN0Uerqem3Z2cOgQGFNblLyfqRQLokSe3GRtTByQoSCsnt2dkYs/SRzGo504aDF+mSwo9BNq/lusiy3BjCNA5CWJPq0qkkyZspSoI4Xj8Wy1yUpThjwvJFu5HyzvNzZfuwl9EM0qfbP71BCb2tDmEGyQr2Wk35sTpdxjE/DUZwe3b2AVJ/Gcfs1/ZAWDzIeu9rnLgxSmNEazfhPCA3t7fva9JX6VT6H0k+vRF75fODlCmU3Z6dDeECr6C3SOnaSyhBMJPlbjXGyQxmtIemNcG+4eBlQuVHrmItH/zbx8QLwnl9cPcNhvSxOmmcw2RG55u/L2CQLQnMZ0D9InhAi+VCbhQPGxhn8FHZdMvGBmr5JgSbd8VZyPWYgqaiyODkOsmCKQRwOoUhRSsI0oDOzwBfdrLHrNhGPYbAKC0O8SLFCUxosa50R18IorD+KcPJJbzfvx/Md3Nb/RzES5hflwtTOu+puvz4VDjziNqYSedOVz9HFJKA3xwQNyeDE2Gk9QTeg0+jwSWADyij2ZkgOOmW3IDrZcXxGD5QcfOntZpQ5O/cpMeY6w3qXCUgNJPf3XjJChGcLGBCb8/OLuH9OUqgfFq7hPfF/TCujeuxb3hJiDkuq06DOIOyLJfOpp+s8HdYv+Jhv3Q2/PcuLng8au9+f8J3ux9DHhyZp6NeSQEXBbMEZxSFWeOK4BBm2YgGhPaTKe5WM8SP4TJYwF4ujg9aZLZk28p60on0Lhf8TjoB9fo3fAfY2Cd8JwZEVOZjQod30onEuVxncDSHcezx+Ap7Yut8StzPJf6Ckgjf96qULMXEEEaIwJCOaJBEAYkGIhM/T8CBbDGfvrL1bjVtbLffq2Zo37Dz6ZosA0mcB4hQBFgQztiE')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'32B97280E54B892DEA04A84BDE65C7BF25B6616C91D379E94F26DB790A8876B5'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p015.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress