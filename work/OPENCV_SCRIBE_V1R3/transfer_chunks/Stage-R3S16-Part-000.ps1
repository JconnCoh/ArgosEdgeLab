$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p000.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('UEsDBBQAAAAIAFGZGV3hrPEO7ygAAFCRAAAYAAAAQXJnb3NPcGVuQ3ZTY3JpYmVWMVIzLnB57X39c9rIsujv/itm9eq9J2JBgMRZh7OkDsEk4a5tfMDJ7rmsSyXQYJQIiSMJGzYn//ur7vlQjyTAyd37w6u6VCqGUU9Pz0xPT09/jP7XT883afJ8FkTPefTA1rtsGUcvTizL6iX3ccoS/hDwx3ochTs2WvOo/4ml8ySYcbZO4ofA54nDUr7yoiyYI3AaxBEbv2icnIxfsHWcZCnLlpyF8fwL99mEr4KrVvsizq68LAm2w5V3z8fc83nCPr1iKz5felEwT9ljkC3jTXYCv++D6B6QBAnLlglPl3HopyxO2NyL/MD3Mq5JSBuM3cQpr8/iTeSzNPMi30v8k4TfB3GUMi/yGT7iPuPbOV9nQRzVU+4l8yVTQAlfeUHEUr72Ei/jHeZFOfCJBJ57EfMD7z6KU84elzzhcmDqYfCFs4xvs03CGd8GaZY6bLbJWJBBrSjO2D2POKA+8SIW+DzKgmzHNlEWhMzT7YY79q+NFwaLgPswfl4Y/OkBCWweR1nizTOJvcFY7yTl8ziCTq3DYB5kLIjWm4ytYp8zbw60pwwncemly/o6iCLuM59nfJ7FiQBOmRcm3PN3J3ES8CjjPpvtcPKCKM28MOS+wQ7rJJ7zNI2Tv7Fs6cm2gpRF/IEDygVPEu6fLJJ4xTy29rKlwxZByCNvxR2YvgAmn/nBikfANWkD2O5EVHDdxQYG0HVZsAI2Yjhy2P/05ESVJfdrL0m5+g2dC4OZ+vk5jSP1feVlS/U9TtW3dJeK9nwv8+ahl6Y8VQ3qIgEBHQiDmXp6A/jwQbZbA4PK8l60c9gw44k3C7kmdP7QVl+jzWq9Y17KovXJycng+v3weuCOB5+Gk+HomnWZ1Ru/H03c0c3guv/JnfTHw7cD91Nr/MJtN9uvmuftM+tkPJh8vLx1J/0Pg6se1PFgsbrxmkfzB1fwoZvwdBNm7kPbOrkYAJ6b')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'D5949D8185FEA3CF2229AD2F5B25869A0E1033B1173662AFC27411ED56F990AC'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p000.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress