$p = 'D:\O3F15L4E5RT'
$b = "$p\R10D_C1.b64"
$z = "$p\R10D_C1.zip"
$t = 'D:\O3F16U10T'
$d = "$p\AnnularUnwrapDiagnosticOpenCvR10.py"
$w = "$p\AnnularUnwrapDiagnosticOpenCvR11.py"
if ((Get-Item -LiteralPath $b).Length -ne 11220 -or (Get-FileHash -LiteralPath $b -Algorithm SHA256).Hash -ne 'AD81CB1987889837538B5E5D32B7B79D612C8570E9A0E7C3CEE6352521B1B66C') { throw 'Base64 pin' }
if (@($z, $t, $d, $w | Where-Object { Test-Path -LiteralPath $_ }).Count) { throw 'Target collision' }
[IO.File]::WriteAllBytes($z, [Convert]::FromBase64String([IO.File]::ReadAllText($b)))
if ((Get-FileHash -LiteralPath $z -Algorithm SHA256).Hash -ne '17135CB958E74ABBBE3CC861058AE7F09AFC97CAE266DBC1B74431BFCC550E6D') { throw 'ZIP hash' }
Expand-Archive -LiteralPath $z -DestinationPath $t
$u = Join-Path $t 'AnnularUnwrapDiagnosticOpenCvR10.py'
$v = Join-Path $t 'AnnularUnwrapDiagnosticOpenCvR11.py'
if (@(Get-ChildItem -LiteralPath $t -File).Count -ne 2 -or (Get-FileHash -LiteralPath $u -Algorithm SHA256).Hash -ne '6B28925E04839D411838CB3D6C7D39E523AFC3AE89EDBAC83034351D27ED814C' -or (Get-FileHash -LiteralPath $v -Algorithm SHA256).Hash -ne 'DE8BD27DC9731AEE4739531F58F18B365FA1423A861DB4B90CD21A68C361C4FE') { throw 'Payload pin' }
Copy-Item -LiteralPath $u -Destination $d
Copy-Item -LiteralPath $v -Destination $w
$help = & 'D:\AFCV1\rt\python.exe' -I -B $w --help 2>&1
if ($LASTEXITCODE -ne 0) { throw ($help | Out-String) }
[pscustomobject]@{
    state = 'PASS_O3F16U10_INSTALL'
    detectorSha256 = (Get-FileHash -LiteralPath $d -Algorithm SHA256).Hash
    wrapperSha256 = (Get-FileHash -LiteralPath $w -Algorithm SHA256).Hash
    zipSha256 = (Get-FileHash -LiteralPath $z -Algorithm SHA256).Hash
    importHelpPassed = $true
} | ConvertTo-Json -Compress
