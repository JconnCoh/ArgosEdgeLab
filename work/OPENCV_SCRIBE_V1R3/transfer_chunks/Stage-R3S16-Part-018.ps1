$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$root='D:\A2\x\r3s16_8A6DE04B\parts'
[IO.Directory]::CreateDirectory($root)|Out-Null
$path=Join-Path $root 'p018.bin'
if(Test-Path -LiteralPath $path){throw'Part exists'}
$bytes=[Convert]::FromBase64String('X8QroSvv0vk8GTnDvu1N2AUVr6k0abfBvL7EBBQcnneAEorPpcIc4xc1AtfsCcUb6o4DyjeXHgcrX60+DlbsFyDFvR/WIa/dHks4MGEw5requlwBdKS4+wkNRO59FUs+v/AotCxsRmD93aoXVORN/kMxW2iR7R75OxLm621NP35trzJYQRLMIMuJMaTwla2WWCxQlqFkZuNove1JnQd3MM7YDfY//Xvwx+cv//nvn9KTptVbDuB9rZA8Zxb295c53L7XedwqN2kwJMRk5e469Hxv6F063sQZfPaG1gdv8nFw7kobubE9JvWJMmG+ecDklOMWayr23gBZ82gTwRWMccreC0zY0n8IuebRyPU+e+eDqwvvcjwR71s9V+pGvM3MX332pCvv0u1ffuDvbo/i238MwIqLyUf3m5VFGC+o+K4OIjYb7SIGcX1EMirO4YBsn4BBTtZXj56hfzrdDecw/J4tF8d1eDLbDYMkQhH7goe90ixItoNyl5thaY7/lrsxDoMY/SW+PyjmyoOvwG0REy5ysH6A1cW0C2N4dPo+mAqkfmSOK8hj9O+B+yIjFLC+Ap6+rRSeIrI4ewKqfkjypC8Pam+vBLcL/9lKcPvNwq9UggyZseaZ+DSmu+um8VdD6ZK+0UPYaR2lKQ70zaWgvRagMp/7v6rwZKAqL9ZTopPBkFypoMrbJYfvdPb5lJ7PWXTln2VQtGA9F/Ge+Pli4ID7XlXwF0qPFwVvtkwKyYJ9kPHPGqblXvQvy+H+qIH+P42tYu3xCLv/VUcpx4unjYjBrLA5iMMvLGb+scnjtMBh/LskZgDlwaN+yGh+0Zdeieu/30wpnKNoq6hKZVMRL8AZeokgDVDcq04a3kMI+Xc3jfyrqAoA+Xv1Zyu8/FOtXXXHKrcAJZDI8uPP182bN4gsfTQmy4976aM0+TPJI1/2qx7KkOMLqWOSf8gmdYvDFv//Xsb/J6OzwQ6efwxR2VT+F1BLAwQUAAAACABimxld6qERjXQCAABSBAAAFQAA')
$stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
$hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;if($hash-ne'6FA4DB4022BC036DCF9E7B980C6EBDDA7E3D5CF58E82E2A041E1E33921CE654A'){throw'Part hash mismatch'}
[ordered]@{schema='argos_r3s16_transfer_part_v1';state='PASS_R3S16_TRANSFER_PART';part='p018.bin';bytes=$bytes.Length;sha256=$hash;mutationsPerformed=$true;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress