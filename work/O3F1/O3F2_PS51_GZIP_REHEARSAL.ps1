$ErrorActionPreference='Stop'
$bytes=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Run-FrozenFrontCorpus.py'))
$compressed=[IO.MemoryStream]::new()
$writer=[IO.Compression.GZipStream]::new([IO.Stream]$compressed,[IO.Compression.CompressionMode]::Compress,$true)
$writer.Write($bytes,0,$bytes.Length)
$writer.Dispose()
$compressed.Position=0
$reader=[IO.Compression.GZipStream]::new([IO.Stream]$compressed,[IO.Compression.CompressionMode]::Decompress)
$roundTrip=[IO.MemoryStream]::new()
$reader.CopyTo($roundTrip)
$reader.Dispose()
if([Convert]::ToBase64String($roundTrip.ToArray())-ne[Convert]::ToBase64String($bytes)){throw'GZip round trip changed'}
'PASS_PS51_EXPLICIT_GZIP_TYPES'
