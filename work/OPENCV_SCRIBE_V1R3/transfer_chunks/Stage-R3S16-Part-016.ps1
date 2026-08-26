$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p016.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('1GVBvifoSgo2WCQdYy+JrGydhCxgQULKdFzPQ7JtiE8bXwJEmeM/IFpTDYX9k+VHFmWraePfKI5r8iYMaDh/3HR5Fig0hA8hhBGMQL4KLFAcowyGOIkyadOtkt5NmoXLjOJF7mnvH+EDC9kRZDp6+XM3oxHfHuY7YpfJhvhOICH50Iad4i4yixQAqmRTqeydJkxWZ87g4up67A0vrQuvDn9Ilqo0Nb2tqYoqyeDkC8HJDMxxxmLG4Qr5pDLFBAbhvFZNAUrAe0bD3aBAIqdPUMVpgahOnwCnU46N5P1Y8lwYSQEfHa9TCM5hMJXBSV50RWCKYgiCu0yEuXQbG3fZh61vNTeHmjOceVrAztMcLpwy3HhaY39LGFQ+LcGd0y2cOX0KVnYbOpS+F//L6ADkZyjX4Y9dgSYDSTg6YNkXhPMgmcFIeplRfgmckyjOZCB9wnc/w4NfDWOQl2QykIZFSQrulkkUwzdyKl8557grzBhTYRmgTLVjvDWjHuPp4ITChIL6MLjfM46yuRUpwid4wZPEnn7b8FwsamThHC4C5gkBA9kT0ppkMaaqPhFxbZIG6xgH0aRYMVkxR5GuxDAohoFgtNN/a20MHwp72wplNsusv5o+i7p3qhJ832DJX+7+srMUysYwmO58pbZjvY8o+D32KVzs85ZzyFKHPxgs0NtCv7s1hVlJEP9dnMUbRO1MJmV28mTv2TxoanqJedmU93hveEH0msXkTvJmY/mG7xooSZe8/cJM5Y9r67zv9z13kpd9njsZDPve5dhzJ6439pzxYDjpX15dj5mt9NlasGC9m2f8Ji8+mKBgSeeY433W1oH3gyRe14MkYmnpKFmwpHgRUBT2I5hQRNdWMfXispTgaMnxjhejGbqL4Yvki2DtxDAgH3EcZTKQtkKe3VL59ERoZYbNooD4JQNJJGtAmMEfOg4bSWAsnEe6m0qnUjSVmNtkJOztbiVrFKRv85CdahkJheEcuswIL0lYSiy5hDc6yhERRzyHzRWek8vbd5yX')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'6E3F7AB66E7700184831B7306F0A28458CD407D2F45766FAB7D220A3867311E8'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p016.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress