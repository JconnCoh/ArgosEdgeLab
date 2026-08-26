$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p004.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('ysiqMJrS0gjgwGAI+hwHyYau5SPxxx8WWohSvq7VaoXqwUJg+Em0gt5N/CJ7R+xUT+0kT+ceHGjy7iHGvX0U/AVFkl3Axkd5JTeYS40qChY8zVxic5MWozWfZ9x3NYSwyQrW0gNaZi+pemabdcinBUO8U7DjSYumN8/gkAjGXzDTEoOxQZ4eZAr/U3cvqcrIesh+ko+0qswmH3r19tkrtgrSlZfNl8piogG6xF5bTaAqbdzzzLbS+ZKvPAutOdIzCJ5HcEgq3+B9uFsv82lK3YeW9Z1ki1ZKVB9wi7Aum95pA1sSPwKPmqTnFFkOm96RoRT+BDSq20n8KMCxEGSFVdMm7mmnlZ/dpAQQPgzD8AY7TxBtxFGArMU94k42O7XUMgDes+5qUujVii3i0gtSwVU1EDxFvwROj0Yrnlp3uhsFM+GhNYuTCXJJmk8xNALiJlA20eUKHzhDsu4eC1YOpjZeAN1jWnFQhXspVLhW26H2jdYdnJHOqY/HMIEXTqQKu8Oa+M/AZPxsUpfVgiItWcmeOHC5yWzGNV1VI5ezdsNbr3nk25q3hWvLMblTeTuH0tkpGdUhRMvhIZjBXWZ/4btu6K1mvoc+uw7LHXk1arTN69VAEzhouR1G6WaxCOYQ2sH8IM2CaJ7JISDty/5qZ6JlNT7HQWRLN97Xoy7Fb7JPihlzFHkt7RykbnjoE5bL3UuQYO4zuhWHeCktJUMmYhF1qMB2cjC9pPtgT7E6xSEkoLr0EokAWPxCQGT/3sb+TnOUhpYPqxt/4Il3z/sx6K8ZtzrYYaPGN7mZLoIw4wn3n+h3Bs/TPNz43Dcd7LhBFmAFqyh41i1Xbcy9lC/i0LeNOZjmyw/mvpoJiuJQtyOhG6VIANKa2GNFBUR0J4fDC8P4kfuumAt7Haeo8eXmXOrUUE/Bg2CsDNENI5ajsk6ruo4K8qBjQthYac1e9MXN17l9IMZBTDmdVsP5LR/TvkqVB2e0WsERA8W6+4ZMntggsgMWOVn/Mjrh74TYimOD')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'09E17B81F2D3E6A26F6816CB30B813C10F35F752BAA0516BF6AE5FF131E07917'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p004.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress