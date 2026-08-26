$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p013.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('A31blaouSKxWbaTVEt6iZNxmpl+0hG9OwyvNdFi9cM/LmPrSVQ1Esb+bWojZkhcc0hjBssrPusdeXwYfTUVFY+pNNPLtUES/PlJBCglqT0HCZVwr/g+BY7MFpdZMX0D0ch3eTWHlqus78Q6DJ1f0dcXKRX5Uu/jubQd91erGCKjty++H1MW377DaxTumE1NT6ZvJL3OR2WeF2PTP8QxGEgbFDButOAVSQ/psAWesfCDJEcaHR2SMTcO5fjERTajQi8O4UekxCWCFpHHkRvzRJgtOrT6ZtZNgeHQaRw1/s1qnNtz9JsxsMuNM/r5z4BQFJSTDgaCtOcTCQW2cCg0xf9zV1NudpJehKeXFGm/x9ZL7DXgFU9tL7h86bJjxBN46h14UlBReco+gDchoSNfeXL2hAwohYVoD9CSuG3yi35cIP8BJotuyrXr9czyzHIZZUSiTDsGKXpXBNe2Qpieq6k6lNoRgYKdy3VlXaIDUI9GY+QPJf6XYBImfC0ZG+pGXFXXMS7gW8ObFRBq5HHi4vm3vaGu5XOpcYarMq4ml7Dc66JS6BVtFsGCuG3kr7rq4Y7ou0OO6co80grvFCp7s0oyvBtsArnmB/MtdCrmQD9NWR6VHyRhrvV0yCKEwY60PML8FfkR3dDO47n9ypcPiZjz6NASL1GA8Ho1BdiG+290a39sACYRYUGuo3lA/JKwX8fgbJLkFIe8C1Wnm84RcC4D9O/l/UEsDBBQAAAAIAD2bGV2aiVTzhw8AABktAAAZAAAASW52b2tlLVIzU2xvdDE2RGlyZWN0LnBzMdVabXPaurb+zq/Q5DBjPA1cG7CxwzBTv7b0JCEbSHvOTjOMYwtQayxXFiTsbP77HUk2OEBe2u65M7cfUiMtrbUkrZdnLftfQ/hjiQjMQP0zJBnCCdAaauXGWUQxpDZKIpTMavJtJQ1IsKjdZPeIhvPb6hWB0xjN5lSuVKoeIZhYIUU4YeOQwCSEPWlEcSpVRpDWR5SgkF7gCO7EnAcUZrRSJXCF')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'A9FE1ED95486B9B20056548E2A4C46DD2B464A45FEF8D648537079E8B9C62E7B'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p013.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress