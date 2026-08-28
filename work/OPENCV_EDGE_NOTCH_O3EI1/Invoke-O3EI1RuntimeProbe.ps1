[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Observe,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (@(@($Preflight, $Observe) | Where-Object { [bool]$_ }).Count -ne 1) { throw 'O3EI1 requires exactly one of Preflight or Observe.' }

function Get-Sha256([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $stream = [IO.File]::Open($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Limit-Text([string]$Value, [int]$Maximum) {
    if ($null -eq $Value) { return '' }
    if ($Value.Length -le $Maximum) { return $Value }
    return $Value.Substring(0, $Maximum)
}

$pythonPath = 'D:\AFCV1\rt\python.exe'
$installationPath = 'D:\AFCV1\INSTALLATION.json'
$expectedPythonSha256 = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$expectedInstallationSha256 = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$expectedOpenCvVersion = '5.0.0'
$expectedNumpyVersion = '2.5.1'
$timeoutMilliseconds = 15000
$probeMode = 'VERSION'

if ($Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'O3EI1 rehearsal requires InvocationManifest.' }
    $manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or (Get-Item -LiteralPath $manifestPath).Length -gt 65536) { throw 'O3EI1 invocation manifest is missing or too large.' }
    $invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$invocation.schema -ne 'argos_o3ei1_runtime_probe_invocation_v1') { throw 'O3EI1 invocation schema mismatch.' }
    $pythonPath = [IO.Path]::GetFullPath([string]$invocation.pythonPath)
    $installationPath = [IO.Path]::GetFullPath([string]$invocation.installationPath)
    $expectedPythonSha256 = [string]$invocation.expectedPythonSha256
    $expectedInstallationSha256 = [string]$invocation.expectedInstallationSha256
    $expectedOpenCvVersion = [string]$invocation.expectedOpenCvVersion
    $expectedNumpyVersion = [string]$invocation.expectedNumpyVersion
    $timeoutMilliseconds = [int]$invocation.timeoutMilliseconds
    $probeMode = [string]$invocation.probeMode
}
elseif (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'O3EI1 live mode refuses InvocationManifest.' }

if ($probeMode -notin @('VERSION', 'FIXED', 'TIMEOUT', 'ERROR', 'MALFORMED')) { throw 'O3EI1 probe mode is invalid.' }
if (-not $Rehearsal -and $probeMode -ne 'VERSION') { throw 'O3EI1 live probe mode changed.' }
if ($timeoutMilliseconds -lt 1000 -or $timeoutMilliseconds -gt 30000) { throw 'O3EI1 timeout boundary changed.' }
foreach ($required in @($pythonPath, $installationPath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "O3EI1 prerequisite is missing: $required" }
}
$pythonSha256 = Get-Sha256 $pythonPath
$installationSha256 = Get-Sha256 $installationPath
if ($pythonSha256 -ne $expectedPythonSha256) { throw 'O3EI1 Python executable hash changed.' }
if ($installationSha256 -ne $expectedInstallationSha256) { throw 'O3EI1 installation manifest hash changed.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3ei1_runtime_probe_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3EI1_RUNTIME_PROBE_PREFLIGHT'
        pythonPath = $pythonPath
        pythonSha256 = $pythonSha256
        installationPath = $installationPath
        installationSha256 = $installationSha256
        timeoutMilliseconds = $timeoutMilliseconds
        childProcessStarted = $false
        mutationsPerformed = $false
        imageBytesRead = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$versionCode = "import json,platform,cv2,numpy as np;print(json.dumps({'schema':'argos_o3ei1_python_versions_v1','pythonVersion':platform.python_version(),'opencvVersion':cv2.__version__,'numpyVersion':np.__version__},sort_keys=True))"
$fixedCode = "import json,platform;print(json.dumps({'schema':'argos_o3ei1_python_versions_v1','pythonVersion':platform.python_version(),'opencvVersion':'$expectedOpenCvVersion','numpyVersion':'$expectedNumpyVersion'},sort_keys=True))"
$argumentCode = switch ($probeMode) {
    'VERSION' { $versionCode }
    'FIXED' { $fixedCode }
    'TIMEOUT' { 'import time;time.sleep(60)' }
    'ERROR' { 'import sys;sys.stderr.write("O3EI1_INJECTED_ERROR\n");sys.exit(23)' }
    'MALFORMED' { 'print("NOT_JSON")' }
}

$startInfo = New-Object Diagnostics.ProcessStartInfo
$startInfo.FileName = $pythonPath
$startInfo.Arguments = '-c "' + $argumentCode.Replace('"', '\"') + '"'
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = New-Object Diagnostics.Process
$process.StartInfo = $startInfo
$started = $false
$ownedPid = 0
$ownedStartUtc = $null
$timedOut = $false
$killedOnTimeout = $false
$exitCode = $null
$stdout = ''
$stderr = ''
try {
    $started = $process.Start()
    if (-not $started) { throw 'O3EI1 child process did not start.' }
    $ownedPid = [int]$process.Id
    $ownedStartUtc = $process.StartTime.ToUniversalTime()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($timeoutMilliseconds)) {
        $timedOut = $true
        if (-not $process.HasExited -and [int]$process.Id -eq $ownedPid -and $process.StartTime.ToUniversalTime().Ticks -eq $ownedStartUtc.Ticks) {
            $process.Kill()
            $killedOnTimeout = $true
            if (-not $process.WaitForExit(5000)) { throw 'O3EI1 owned child did not terminate after timeout kill.' }
        }
    }
    if ($process.HasExited) { $exitCode = [int]$process.ExitCode }
    $stdout = Limit-Text ([string]$stdoutTask.Result) 16384
    $stderr = Limit-Text ([string]$stderrTask.Result) 16384
}
finally { $process.Dispose() }

$versions = $null
$state = 'HOLD_O3EI1_RUNTIME_ERROR'
$runtimePremisePass = $false
if ($timedOut) { $state = 'HOLD_O3EI1_RUNTIME_TIMEOUT' }
elseif ($exitCode -ne 0) { $state = 'HOLD_O3EI1_RUNTIME_ERROR' }
else {
    try { $versions = $stdout.Trim() | ConvertFrom-Json }
    catch { $state = 'HOLD_O3EI1_RUNTIME_MALFORMED' }
    if ($null -ne $versions) {
        if ([string]$versions.schema -ne 'argos_o3ei1_python_versions_v1') { $state = 'HOLD_O3EI1_RUNTIME_MALFORMED' }
        else {
            $runtimePremisePass = [string]$versions.opencvVersion -eq $expectedOpenCvVersion -and [string]$versions.numpyVersion -eq $expectedNumpyVersion
            $state = if ($runtimePremisePass) { 'PASS_O3EI1_RUNTIME_PREMISE' } else { 'HOLD_O3EI1_RUNTIME_VERSION_MISMATCH' }
        }
    }
}

[ordered]@{
    schema = 'argos_o3ei1_runtime_probe_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = $state
    probeMode = $probeMode
    runtimePremisePass = $runtimePremisePass
    pythonPath = $pythonPath
    pythonSha256 = $pythonSha256
    installationPath = $installationPath
    installationSha256 = $installationSha256
    expectedOpenCvVersion = $expectedOpenCvVersion
    expectedNumpyVersion = $expectedNumpyVersion
    versions = $versions
    child = [ordered]@{
        owned = $true
        pid = $ownedPid
        startUtc = $(if ($null -eq $ownedStartUtc) { $null } else { $ownedStartUtc.ToString('o') })
        timeoutMilliseconds = $timeoutMilliseconds
        timedOut = $timedOut
        killedOnTimeout = $killedOnTimeout
        exitCode = $exitCode
    }
    stderr = $stderr.Trim()
    sourceFilesRead = $false
    imageBytesRead = $false
    sourceMutationPerformed = $false
    taskActions = @()
    existingProcessActions = @()
    ownedChildProcessStarted = $true
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 12
