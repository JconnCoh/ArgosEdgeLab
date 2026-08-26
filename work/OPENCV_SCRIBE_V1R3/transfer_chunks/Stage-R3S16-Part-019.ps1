$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p019.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('AFBBWUxPQURfTUFOSUZFU1QuanNvbn2TX2+bMBTF3/MpEM9tdP0Xkzcb21OnbZlIt4euE3LBaVgZROBkS6t+9wnStZOW9sVC5neuzj33+mEWRfFQbvxPFy+i2PW33VD0pBiaLiBeVHXvy1Bs3aHpXFX8dG299kMo9ig+G5W939dD3bWjNicrxAsMmIPA/BIAM4CrQkiuDVB1FJS9d8FXX0I5Skb4HMT5hC9wsgC4OnJNvfbloWz8iNl8eWU+HX+s68YP8SL6NouiKHqYziiKty5sRlSODSy3vs32q7Kvb/xXlJP59jCJJ/LmEKYCJMEAz7fDxmHGxwp//SZagzBWJiiRlgO3GjRQjrFURtAsYUTxFDLKUlBgUqaFIkhJFU8lH89O+7to992dP8/JagpYT/nOtwP63yBCjLITBoEbbBQxKoMUG0ukTIxljPE0zawiQmJBLWeaMqW4olJJQTKeIMWoJamybxvMSbH6sLxEvNAXuckui/dLNf8xdO2JBDmc8kcIkpZxybjOOMsSIblgjBnFLEKCpiZTWtEswUCM1ARQmqYUhCApWEKMefI3i6Lv08TrdgiuaXyV+7XvfVt6tWuraTOO7p+968X19RJrdn0t83fLVXH8Hs8iN3Y1v6+3T128hEwFY4g9LcI/XTCuLYAhiUQpM4nKiAHMDU0ZaKuYhDH2RFqaSm4tSQGDggQJCllmleZjF1PGsf/tyjCOeyx7HPtxlYMb7pb9574r/TDkfgiuD3IXNl1f3/sqXkRr1wx+Qrd9t68r38sy1HsX6q59BRy6XV/6j7vwFrTpmiprvOtdW/pXmPFl+1/LtjnEiyj0u2cf1a4cS+fdLtTtrWndTfMinT3O/gBQSwMEFAAAAAgAG5sZXfM3SdTZBAAAFQ4AABkAAABSM19TTE9UMTZfRElSRUNUX0pPQi5qc29u1Vffj5s4EH7fvwLlua1sfhjYN2ObbqRsQiHbqj0qywEncQ9wzsB2V1X/9xMJSXb3bq+n6k5t3xCe7/PM+Jvx')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'2072B9F6225BC3660E0A1C92145F4E45E79F0EE44BEBA8309A775FF72FEB66E4'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p019.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress