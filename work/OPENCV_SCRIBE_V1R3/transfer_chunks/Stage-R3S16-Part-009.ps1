$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p009.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('g9LYpl86DI77ZmazWuHyBhCBHRP2vW2QduWy9IOFSg8TKKFAkuIwCUmzgQkNsNcpxJBM7CX3qFFvVqn0B0m4dhnO21bAtSrxERJN8BeVaKvAZXwA1NIpuPMsWOyq7rMRd0dKS8LBOzgADQA1xFHpF4ahdLJMno1+YUSqF8N5gQpQnGxZRy1FRYUqEFKdtKUBpBVH/zZWiGQAFBfCQ1rkOXMPAXKq0papgTi/ccHb2m2qj1P6amadPGpuTyUVOlI4lObXLk4hie3OYVODCrz2Zk+x2XSdgW8FsJTL7/YtHX2tJAzTPc9ueJKCkSJ44LeJF6WLOFnZYnjVWVUnIc+Xst6jl6xJRZ3mJ+5dtCnhBeJqcAbx7lNy4L0cXg96Y9hZYS6vYp/jw7ej8cVg7I4HN5fDfu92QHOZ58s8gOmNUdAi1mRKcQKXAmNG5Xwp1cbRbe924L5uggra//W34WRQTFaeq2xlmQUphkWOTqU1TxiD6dKrDMGQSaSYyA1mOYFxakG5jgDfmyKKJeAUtWsNyCoGdeEncTRQiGY7dMYevhtxIhaRuF85SJk3S/EOK/CupgxQMHmWqE4T1ddjlnJWFf0SQmawKuIOJLHup7KY/lyg5QnpqnJeBa8SXxAOOlr35T1rxHviRXEE+Wc3SfzAI7h68iaHFv0Rlr59kDKXM0cZxFDeh1tpK9DQp6WqXhh46bW34hUV82elaoIXOlVsQ4PfVVKkmDPyRFhg0UBoRu7RRqT5tQTVVFAqkN2LvHD3J3eR66S1s8I27nyXGfSoNydP0+ZwG31UXr4CTgzpAaD9nmjwOLl4ubng9s/xTM4pPAGxBlNzM5oMXFRyqYprySXvB6j5mW4sPPXnyLvM+sfH3uXw3XBw4Q6vJ7e9y8vBhTsaDwfXt4ML92JwO+jDrS7D65uPt8Lsqi64V0ZmzOMsOygUEcrEa4BX2qnFJOV84JPvwAmGTXxqSd3xtzj5EkT3F+qkaNjf91ejYSaHKxAb0iTj66KZX3qU49CsJ6ZL')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'9552CCFAFE9CA171880A0CE8A7CC8FAFB74AC6FDAA8229D0446763D746C441F3'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p009.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress