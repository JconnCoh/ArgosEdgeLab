$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p001.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('29HY/W14cfuBdVn7JS39MBi+/3DLuuzl+cnb0cU/3ave7+7F4PIWsDcbLVLa711fDC96t4MJgJ/0Pwz6vxbAXzZV8fDanfRH4wHrsnqz0Twj4Aae85P34+GFezXoXbu/KVqajZ/PRPnloHcxvH5PH7Xa8tntuDe8rHj4dvTx+qI3/icQMbz6eKUJaTZar0V3LntvB5fQvNVstV+8PHv18/nr3tv+xeDd+w/D//j18up6dPOP8eT246fffv/nf1qC+BappoDlo3YFRuvk5OTvmpXsRRL/yaPubbLhtRMsYmMUO50TxpgUQW7gd1iaJViUxptkzvPfc1iaibvtsEUYexkt29Gyx8DPlrRgyYP7ZUZLvOg+5K7P7xPOU/qAShs3nccJV0+PdeYmibM426256E/ozXiY075e7tJg7oWuEnr5I58D266zOOmwaN0AsZ14u6e399aLvog2V7izGFg0KW4Q+cEcOusH82yaZolD4O5OEPLvKciZ+Ypny9iXxC0YrHV3rZpL7fxrh4VBmk01KXc1Vn/DLIM0S9CW08e60PBDmnnzL/Y0yPiqkQ9Bw0uhoh2tGzjsr17W2AIkZsZXLIhY3vZdTePFDqYCL3ZHosXy49XlyLAu+6rLyBQiKV4WxdGfPIlt1VhXPM/RwAfaEq3CNhonGfftlGeyUiOLYbzsWi2v9U1/S3i2SSJzXm0xZF3xxzGnsiv/1k5OTmCe0qXXPnvlwk5jg8zuoKjGKUmzREyDH9zzNGNdtWE0RCVbEAS6B4r7BghU20pmVg0Edpol3FvlE/m4DELOgBvzMvjMQNlhXQnfgD3VfsmesVazrf6Y4xUsGGgFWM9EhegS7n0xSgX5jc0adB8bqwmEcvDk8yXfim92rbFZr3liqzECklzYHYsjlK+KXrS761QPh+UwHs1jP4juu9YmW9TP62lwXz1GD1644ayLW3EjjD3fFhCCXtnxIEUNI5pzG+EdpKOWY0m8IOXsEzwbJEmc2AvrPyaja5bEccZWmzRjMw5a')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'A2992AAD7FCEF989ABE4563E81E7095D659378D5CA452922F4756D8EB4676A07'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p001.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress