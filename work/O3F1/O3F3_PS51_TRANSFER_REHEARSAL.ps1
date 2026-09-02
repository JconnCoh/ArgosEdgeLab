$ErrorActionPreference='Stop'
$source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'O3F3_DIRECT_INIT.ps1'))
$encoded=[regex]::Match($source,'\$b=''([^'']+)''').Groups[1].Value
if(-not $encoded){throw'Embedded transfer payload absent'}
$compressed=[IO.MemoryStream]::new([byte[]][Convert]::FromBase64String($encoded))
$compressed.Position=0
$reader=[IO.Compression.GZipStream]::new([IO.Stream]$compressed,[IO.Compression.CompressionMode]::Decompress)
$output=[IO.MemoryStream]::new()
$reader.CopyTo($output)
$reader.Dispose()
$sha=[Security.Cryptography.SHA256]::Create()
$hash=([BitConverter]::ToString($sha.ComputeHash($output.ToArray()))).Replace('-','')
$sha.Dispose()
if($hash-ne'EDD263C7A530AE12D8C963EFC60DD3F3B1A95DCF2A88440F823C32FE7C671499'){throw "Transferred wrapper hash changed: $hash"}
'PASS_PS51_O3F3_TRANSFER_EXACT_SHA256'
