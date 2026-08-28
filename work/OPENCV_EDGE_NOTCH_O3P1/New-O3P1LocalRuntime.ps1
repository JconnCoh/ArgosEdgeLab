[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [Parameter(Mandatory = $true, ParameterSetName = 'Preflight')]
    [switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Require-ExactFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Sha256,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label is absent: $Path"
    }
    $actual = Get-Sha256 -Path $Path
    if ($actual -cne $Sha256) {
        throw "$Label SHA-256 changed: $Path"
    }
}

if (-not (Test-Path -LiteralPath $InvocationManifest -PathType Leaf)) {
    throw "Invocation manifest is absent: $InvocationManifest"
}
$invocation = Get-Content -LiteralPath $InvocationManifest -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_ocv03_o3p1_local_runtime_invocation_v1') {
    throw 'Invocation schema changed.'
}
if (-not [bool]$invocation.reviewOnly -or [bool]$invocation.productionRoutingEnabled -or [bool]$invocation.networkAllowed -or [bool]$invocation.sourceMutationAllowed) {
    throw 'Invocation authority widened.'
}

$pythonPath = [IO.Path]::GetFullPath([string]$invocation.pythonPath)
$targetRoot = [IO.Path]::GetFullPath([string]$invocation.targetRoot).TrimEnd('\')
$gatePath = [IO.Path]::GetFullPath([string]$invocation.gatePath)
if ($targetRoot -cne 'C:\A3P1R') {
    throw "Runtime target changed: $targetRoot"
}
if (-not $gatePath.EndsWith('\work\OPENCV_EDGE_NOTCH_O3P1\O3P1_LOCAL_RUNTIME_GATE.json', [StringComparison]::OrdinalIgnoreCase)) {
    throw "Runtime gate path changed: $gatePath"
}
Require-ExactFile -Path $pythonPath -Sha256 ([string]$invocation.pythonSha256) -Label 'Python runtime'

$wheelRows = @($invocation.wheels)
if ($wheelRows.Count -ne 2) {
    throw 'Exactly two local wheels are required.'
}
$wheelPaths = New-Object Collections.Generic.List[string]
foreach ($wheel in $wheelRows) {
    $wheelPath = [IO.Path]::GetFullPath([string]$wheel.path)
    Require-ExactFile -Path $wheelPath -Sha256 ([string]$wheel.sha256) -Label 'Local wheel'
    $wheelPaths.Add($wheelPath)
}

$pythonVersion = (& $pythonPath -c 'import sys; print(sys.version.split()[0])') | Select-Object -Last 1
if ($LASTEXITCODE -ne 0 -or -not ([string]$pythonVersion).StartsWith([string]$invocation.expectedPythonVersionPrefix, [StringComparison]::Ordinal)) {
    throw "Python version changed: $pythonVersion"
}

if ($Preflight) {
    if (Test-Path -LiteralPath $targetRoot) {
        throw "Create-new runtime target already exists: $targetRoot"
    }
    if (Test-Path -LiteralPath $gatePath) {
        throw "Create-new runtime gate already exists: $gatePath"
    }
    [ordered]@{
        schema = 'argos_ocv03_o3p1_local_runtime_preflight_v1'
        state = 'PASS_O3P1_LOCAL_RUNTIME_PREFLIGHT'
        invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
        invocationSha256 = Get-Sha256 -Path $InvocationManifest
        pythonPath = $pythonPath
        pythonSha256 = [string]$invocation.pythonSha256
        pythonVersion = [string]$pythonVersion
        wheelCount = $wheelPaths.Count
        targetRoot = $targetRoot
        targetExists = $false
        gatePath = $gatePath
        gateExists = $false
        networkAllowed = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
    return
}

if (-not $Apply) {
    throw 'Either -Preflight or -Apply is required.'
}
if (Test-Path -LiteralPath $targetRoot) {
    throw "Create-new runtime target already exists: $targetRoot"
}
if (Test-Path -LiteralPath $gatePath) {
    throw "Create-new runtime gate already exists: $gatePath"
}

New-Item -ItemType Directory -Path $targetRoot -ErrorAction Stop | Out-Null
$arguments = New-Object Collections.Generic.List[string]
$arguments.Add('-m')
$arguments.Add('pip')
$arguments.Add('install')
$arguments.Add('--no-index')
$arguments.Add('--disable-pip-version-check')
$arguments.Add('--no-deps')
$arguments.Add('--target')
$arguments.Add($targetRoot)
foreach ($wheelPath in $wheelPaths) {
    $arguments.Add($wheelPath)
}
& $pythonPath @($arguments.ToArray())
if ($LASTEXITCODE -ne 0) {
    throw "Local offline wheel installation failed with exit code $LASTEXITCODE."
}

$verifyCode = 'import json,sys;sys.path.insert(0,sys.argv[1]);import cv2,numpy;print(json.dumps({"python":sys.version.split()[0],"opencv":cv2.__version__,"numpy":numpy.__version__},separators=(",",":")))'
$verifyText = (& $pythonPath -c $verifyCode $targetRoot) | Select-Object -Last 1
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace([string]$verifyText)) {
    throw 'Installed runtime import verification failed.'
}
$verified = [string]$verifyText | ConvertFrom-Json
if ([string]$verified.opencv -ne [string]$invocation.expectedOpenCvVersion -or [string]$verified.numpy -ne [string]$invocation.expectedNumpyVersion) {
    throw "Installed runtime versions changed: OpenCV=$($verified.opencv) NumPy=$($verified.numpy)"
}

$result = [ordered]@{
    schema = 'argos_ocv03_o3p1_local_runtime_apply_v1'
    state = 'PASS_O3P1_LOCAL_RUNTIME_INSTALLED'
    invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    invocationSha256 = Get-Sha256 -Path $InvocationManifest
    pythonPath = $pythonPath
    pythonSha256 = [string]$invocation.pythonSha256
    pythonVersion = [string]$verified.python
    opencvVersion = [string]$verified.opencv
    numpyVersion = [string]$verified.numpy
    wheelCount = $wheelPaths.Count
    targetRoot = $targetRoot
    gatePath = $gatePath
    networkAllowed = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$resultJson = $result | ConvertTo-Json -Depth 5
$gateParent = Split-Path -Parent $gatePath
if (-not (Test-Path -LiteralPath $gateParent -PathType Container)) {
    throw "Runtime gate parent is absent: $gateParent"
}
$gateTemporary = "$gatePath.partial"
if (Test-Path -LiteralPath $gateTemporary) {
    throw "Runtime gate temporary path already exists: $gateTemporary"
}
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($gateTemporary, $resultJson + [Environment]::NewLine, $utf8NoBom)
Move-Item -LiteralPath $gateTemporary -Destination $gatePath
if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf)) {
    throw 'Runtime gate commit failed.'
}
$resultJson
