[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$schema = 'argos_o3ro1_runtime_versions_result_v1'
$nonce = 'O3RO1_RUNTIME_VERSIONS_20260828_24B91C6E'
$expectedComputerName = 'A1025645101'
$pythonPath = 'D:\AFCV1\rt\python.exe'
$installationPath = 'D:\AFCV1\INSTALLATION.json'
$moduleRoot = 'D:\AFCV1\rt'
$scalar = 'PASS_O3RO1_RUNTIME_VERSION_OBSERVATION_20260828'
if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3ro1_runtime_version_payload_preflight_v1'
        state = 'PASS_O3RO1_RUNTIME_VERSION_PAYLOAD_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        pythonPath = $pythonPath
        installationPath = $installationPath
        moduleRoot = $moduleRoot
        targetReadPerformed = $false
        pythonExecuted = $false
        clipboardChanged = $false
        imageBytesRead = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 4
    return
}

function Get-Sha256File([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

try {
    if ($env:COMPUTERNAME -ne $expectedComputerName) { throw "Wrong computer: $($env:COMPUTERNAME)" }
    if (-not [IO.File]::Exists($pythonPath)) { throw 'Exact O3RO1 Python is absent.' }
    if (-not [IO.File]::Exists($installationPath)) { throw 'Exact O3RO1 installation record is absent.' }
    $priorBytecode = [Environment]::GetEnvironmentVariable('PYTHONDONTWRITEBYTECODE','Process')
    $priorNoUser = [Environment]::GetEnvironmentVariable('PYTHONNOUSERSITE','Process')
    $priorPythonPath = [Environment]::GetEnvironmentVariable('PYTHONPATH','Process')
    try {
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE','1','Process')
        [Environment]::SetEnvironmentVariable('PYTHONNOUSERSITE','1','Process')
        [Environment]::SetEnvironmentVariable('PYTHONPATH',$moduleRoot,'Process')
        $versionText = @(& $pythonPath -c "import json,platform,cv2,numpy as np;print(json.dumps({'pythonVersion':platform.python_version(),'opencvVersion':cv2.__version__,'numpyVersion':np.__version__},sort_keys=True))" 2>&1)
        if ($LASTEXITCODE -ne 0) { throw ('Exact runtime query failed: ' + ($versionText -join ' ')) }
    }
    finally {
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE',$priorBytecode,'Process')
        [Environment]::SetEnvironmentVariable('PYTHONNOUSERSITE',$priorNoUser,'Process')
        [Environment]::SetEnvironmentVariable('PYTHONPATH',$priorPythonPath,'Process')
    }
    $versions = (($versionText -join [Environment]::NewLine).Trim() | ConvertFrom-Json -ErrorAction Stop)
    $result = [ordered]@{
        schema = $schema
        state = 'PASS_O3RO1_RUNTIME_VERSION_OBSERVATION'
        nonce = $nonce
        computerName = $env:COMPUTERNAME
        scalar = $scalar
        pythonPath = $pythonPath
        pythonSha256 = Get-Sha256File -Path $pythonPath
        installationPath = $installationPath
        installationSha256 = Get-Sha256File -Path $installationPath
        pythonVersion = [string]$versions.pythonVersion
        opencvVersion = [string]$versions.opencvVersion
        numpyVersion = [string]$versions.numpyVersion
        imageBytesRead = $false
        sourceMutationPerformed = $false
        taskOrProcessManagementPerformed = $false
        targetPersistentMutationPerformed = $false
    }
}
catch {
    $result = [ordered]@{
        schema = $schema
        state = 'FAIL_O3RO1_RUNTIME_VERSION_OBSERVATION'
        nonce = $nonce
        computerName = [string]$env:COMPUTERNAME
        scalar = ''
        errorMessage = [string]$_.Exception.Message
        imageBytesRead = $false
        sourceMutationPerformed = $false
        taskOrProcessManagementPerformed = $false
        targetPersistentMutationPerformed = $false
    }
}
$result | ConvertTo-Json -Compress | clip.exe

