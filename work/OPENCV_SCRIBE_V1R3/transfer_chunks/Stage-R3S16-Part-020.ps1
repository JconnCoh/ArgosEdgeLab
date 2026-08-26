$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p020.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('+MuFZU3aYitrMbm0JsJsdMv1TjbFLW8Lo1aSf9IrfgsnLwZLI29Vq3Qz2C7IW2Dz1Mkg4jawEQhstATA9gD4wAOMKANudIB90qtpOWC+Yc2RjWD40nUcns0WS4gO8MJI0cnypisGjgH9EgQv9/hL27sE4MPBTpWy6VR3P7m0vlxYlmVNKt0dNj4R7y0tayKKP3rVqk7p5onF0T0XAM93vCOgPXFlle5G1yxrstvet6oQ1fS8+bNcfIReWNbXg8fNru+udSkH1JsbPJvGU0b5dJ4t8WzGKF+kUzZfMsopWzKyXKR8Ok9ulpMz+k0vKrVWhRhCOUfedqL7LtbvDOkINXqnW1ElotsOMHKZ54nRGyNqKjqR53hQGCs3ciZW6SLPcVW9E2tpEqML2bbavLXz/HiQeX7ka/P8Gx7keUbSacR4ki6SRYZnrz61unnqV7YVtof2nnm+EwASejDwEQQB8AmKCPOIY+MgYA72YjdkrouITQHxgiiMHBIHnhdB6GEQH5nrvuoU2YqmkVXW17Uw9z8i+EOx5vneHV4c/Mnz65vZcsrJFZ7P2YynDFOW8uzm+hqn7x8l6G/COOcqpiRAIaV2aGPoURRGYRRjzEAMfB/7Ycg8x4u9iLnYRdDF0KUMQjeIQxgBL2THTVTTdqKqZJmMkbFKbdSqkg+UthZVK5/aE920smn7NjvKeh9YMmN8eo1fM57dJMkiHSR9DW1O8JxOKV6y7EmptecCWa1P34M+fuCRRTEfpftMXb7aNZsxhUM3FI1uhvJMjL6VjWgKmfw63is9OEsq0Q5nMTn3pCucXfFkOp8zylP2dsre8cV89v6MFJUS7VzU++M//25PKvVil4UhCYI4dm07dHBMiU8dbMchhIBA20Y2cYnjAx94XhSGEfBcFhMEHOa5kJw5V/edHNyDyIMBsM+p19qUqhGdjI2o5eE6mC2W+2Tx87X1oNWOuXnSaPeEe11a1qT8aZRIf2kl0p9GiREiwAsjx8MEuZT6UUCdOIp82wkCjAAK')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'9D4001EEA330A3EE5B6E4DB7E119E9EC048673D34508BD635EB1117EF64ADA99'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p020.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress