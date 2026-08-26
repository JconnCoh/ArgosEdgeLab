$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p008.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('jkYAxgJqYyTcKVhX4SKTgPBwsYIb8uheJHjB1BnMV8b3DC4iamrWXgbzLxFP1cS3HAMlyUnUV6Ap11CjeS5P4BChteYJSGuIMla0Ouz1eUOH4s6CyEvQJafHBeybCms5wZo9Y+2zMzGSROJQYWKuHZTAufmwiYlrTkky0TWFEVvYndcydop0/hlrNc5q7N8qOQg+X3gSoQUuWjfgQprUtgGJg6hqJHFKJombOxn0HtsEx6Oog19pfJYfeJGYDchMET9lbAd2kC46Mw8Pa8zj1Ja1YASNySQpdVjdzMUT2UJB9NTqIGHguS3GxGEym084gXxI3hK/0SXj72oGxGkB4lRAtJycJfOm4BAuUvwf2o1VnKyXcRjf7wZbW3CVuMngajS++eD2L0eTAVgPgChCbRxl8SZJHeZKPKCN9mWpLVoQeMaD27E7+P12ML7uXYqi/ofe8Nrt3dyMR7+7k+HVzeXA3LIleuA+1ZIpXuw5dBcHIXl0WALXL8AND67gWtm1IOol3BvzeWZLNKY9d+V9xvgu4FiJxnweROI5TGPFc8jZQJBf2Auw7Qp8z8XSx90RnkJQ94tGQT7uNfNiHgig+YVVS5vmy7ypN9hUhTRDyHMERALf7EHWbj+RrFm8laM6i7c3cRBlqW0fnoVaIVlRpdPlo59+oUvf7Mb+xa9WyyIIw34cPfDtTRzubEDnAJ0OlTBGCqBqYYpNv2EyAEt9zHAumWwngzO1HV8GpuKO3yTZw3Lukkf2C0tkkhz9EO487bLXxaoIgmMIO+bSYcmj2WEts9XuWHXsMI8eC2vwe39wczscXbsXw97769Hkdth3vyIVneYL/5v7FYyxOe5ap/nS/2aZ2jY5o1hotRpcuL99GF0O3OFV7/3AzRuZDHrj/gfaFlyHVIGucJaZb9lzqc/thVWnlvnuAKxxPHk8AGgeUJYHICtPKDmPlytUHE4KkWzwUWprPq3VKSNopG2UcRrn3ByL9liSY4U6y8SJj9aLWbx112IFiz/03FJ5n4q4')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'90675809E39B0D01BDE4FE1765803CD2A540C7835616CAA5168765D831C5A2A4'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p008.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress