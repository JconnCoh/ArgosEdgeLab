param([switch]$Preflight)
$ErrorActionPreference = 'Stop'
$expectedComputerName = 'A1025645101'
$pythonPath = 'D:\AFCV1\rt\python.exe'
$installationPath = 'D:\AFCV1\INSTALLATION.json'

if ($Preflight) {
    [ordered]@{
        state = 'PASS_O3Q2_RUNTIME_VERSION_OBSERVATION_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        pythonPath = $pythonPath
        installationPath = $installationPath
        targetMutationsPerformed = $false
    } | ConvertTo-Json -Compress
    exit 0
}

if ($env:COMPUTERNAME -ne $expectedComputerName) { throw 'O3Q2 runtime observation reached the wrong computer.' }
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) { throw 'O3Q2 runtime Python is missing.' }
if (-not (Test-Path -LiteralPath $installationPath -PathType Leaf)) { throw 'O3Q2 runtime installation record is missing.' }

$versionText = & $pythonPath -c "import json, cv2, numpy as np; print(json.dumps({'opencvVersion': cv2.__version__, 'numpyVersion': np.__version__}, sort_keys=True))" 2>&1
if ($LASTEXITCODE -ne 0) { throw ('O3Q2 runtime version query failed: ' + ($versionText -join ' ')) }
$versions = ($versionText -join "`n") | ConvertFrom-Json

[ordered]@{
    state = 'PASS_O3Q2_DIRECT_RUNTIME_VERSION_OBSERVATION'
    computerName = $env:COMPUTERNAME
    pythonPath = $pythonPath
    pythonSha256 = (Get-FileHash -LiteralPath $pythonPath -Algorithm SHA256).Hash
    installationPath = $installationPath
    installationSha256 = (Get-FileHash -LiteralPath $installationPath -Algorithm SHA256).Hash
    opencvVersion = [string]$versions.opencvVersion
    numpyVersion = [string]$versions.numpyVersion
    targetMutationsPerformed = $false
    imageBytesRead = $false
    providerActivated = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Compress
