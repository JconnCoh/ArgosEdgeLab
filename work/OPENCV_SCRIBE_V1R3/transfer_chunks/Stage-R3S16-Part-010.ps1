$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p010.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('RrzoO0Qn4mmthp5uvDKxcpaoP3q5W8fZkqf8aCoZCskKdGaUrbQ7OnJLA4Ozbb19ZzlsBgEhtnUB3/0FTUxQdcHEnATZzmFwJ7+se9Eb/2pJdIjg7RhydSwHbHisLh9URLUBRkEwpMVIYx3ebAho343Gv/XGF5ZoCxGPB58G48nAbZ03LYduxQBh7MRwbVVVk5XXwdKP9s5RX2LBFawINYN+jXVqXCrx9VtNuXCEz/WmOku/On5P3kOb72M/GIqX81F1Xhz95P6/zvdJCOcYSrEDA9oPvckH92Z4fW0ghrcSDH7Do7h7Mx71B5PJaOyOPt4ewS65GsMXBH/vh1VcjBlSkqH3Q2sOxf1Mcet+eHr8VXlahsOv+Hn2TDNdNRANfMBBlIFshhjOuWK2cJW2qk5x4FEScMQEXAbzK8BAuilIkvisa1e6w0uMeEzwCGRU/MiS/xFC/yOEIBtWHIO1ufDpckbWlKfQ/18FiOxF2bT2XxcrZF84nsZfpg1S+o1E/2JKJcn4p1Elxj0AOPJGoR5iozQfSh22LXO18l5gQO2CFAhtStuUVFwa1cer9KpCbLEMzCDamCEiQQFEEkvBd/TgTNun0ex5t82gOeg8iWxP4seiJRa0P42+kOhuBuaaz5T3GY5/8podIAKDa8mMGPHRkK/yrWBEVhMV8GpUZB6P49LTW42Lzv5xZHJfrMREGPE4InlimBQzujG0GhlfIC3nGxdRE8xVQdEiHyjKOYRmANwdM8GXF2s14caCUiGYsJqENIAXnZUOGmmWFA4aeMlh8SR48FBDXO+gs0OItXzT1OWo37sc/mcP3TIfRpcX4qCpySFXlsDJFwwWXsYdZvkcbi4EZfI6Ji8uW5ffxqYUp0d4BcVmvQ4D7v+t/Do29Qq1IKXBSfDqsYYlxSUP9yZvFvs1Gby/Glzf/mX9Up2py87QTEAll4IU+0iCDCndGIIIokokRB6UVf8NvbmF6+zlBQ/A9eouCUWHSmoEz6YfCF5acZ7hPfgi6BNfpcXu')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'281AFD3714579EAA3450AAC4E30ED5C7DB40824742723C2361E8E2F67AA6DD27'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p010.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress