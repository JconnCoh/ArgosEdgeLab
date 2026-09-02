$s=Get-Content -LiteralPath 'D:\O3F3C978\SUMMARY.json' -Raw|ConvertFrom-Json
@($s.failures|Where-Object stage -eq 'notch'|Select-Object -First 8)|ConvertTo-Json -Depth 8 -Compress
