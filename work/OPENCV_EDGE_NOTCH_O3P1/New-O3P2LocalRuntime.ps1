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

function Invoke-ExactVerifier {
    param(
        [Parameter(Mandatory = $true)][string]$PythonPath,
        [Parameter(Mandatory = $true)][string]$VerifierPath,
        [Parameter(Mandatory = $true)][string]$ManifestPath,
        [Parameter(Mandatory = $true)][string]$ExpectedRoot
    )
    $priorDontWrite = [Environment]::GetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', '1', 'Process')
        $rows = @(& $PythonPath -I -B $VerifierPath --manifest $ManifestPath --preflight)
        $exitCode = $LASTEXITCODE
    } finally {
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', $priorDontWrite, 'Process')
    }
    if ($exitCode -ne 0 -or $rows.Count -ne 1 -or [string]::IsNullOrWhiteSpace([string]$rows[0])) {
        throw "File-backed runtime verification failed for $ExpectedRoot with exit code $exitCode and $($rows.Count) output rows."
    }
    try {
        $verified = [string]$rows[0] | ConvertFrom-Json
    } catch {
        throw "File-backed runtime verification returned invalid JSON for $ExpectedRoot."
    }
    if ([string]$verified.state -ne 'PASS_O3P2_LOCAL_RUNTIME_VERIFICATION') {
        throw "File-backed runtime verification did not pass for $ExpectedRoot."
    }
    $verifiedRoot = [IO.Path]::GetFullPath([string]$verified.targetRoot).TrimEnd('\')
    if ($verifiedRoot -cne $ExpectedRoot) {
        throw "File-backed runtime verification returned the wrong root: $verifiedRoot"
    }
    if ([bool]$verified.mutationsPerformed -or [bool]$verified.networkUsed -or -not [bool]$verified.beforeAfterInventoryEqual) {
        throw "File-backed runtime verification widened authority or changed $ExpectedRoot."
    }
    return $verified
}

if (-not (Test-Path -LiteralPath $InvocationManifest -PathType Leaf)) {
    throw "Invocation manifest is absent: $InvocationManifest"
}
$invocation = Get-Content -LiteralPath $InvocationManifest -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_ocv03_o3p2_local_runtime_invocation_v1') {
    throw 'Invocation schema changed.'
}
if (-not [bool]$invocation.reviewOnly -or [bool]$invocation.productionRoutingEnabled -or [bool]$invocation.networkAllowed -or [bool]$invocation.sourceMutationAllowed -or [bool]$invocation.failedTargetReuseAllowed) {
    throw 'Invocation authority widened.'
}

$pythonPath = [IO.Path]::GetFullPath([string]$invocation.pythonPath)
$targetRoot = [IO.Path]::GetFullPath([string]$invocation.targetRoot).TrimEnd('\')
$failedTargetRoot = [IO.Path]::GetFullPath([string]$invocation.failedTargetRoot).TrimEnd('\')
$gatePath = [IO.Path]::GetFullPath([string]$invocation.gatePath)
if ($targetRoot -cne 'C:\A3P2R' -or $failedTargetRoot -cne 'C:\A3P1R' -or $targetRoot -ceq $failedTargetRoot) {
    throw "Fresh/failed runtime target contract changed: target=$targetRoot failed=$failedTargetRoot"
}
if (-not $gatePath.EndsWith('\work\OPENCV_EDGE_NOTCH_O3P1\O3P2_LOCAL_RUNTIME_GATE.json', [StringComparison]::OrdinalIgnoreCase)) {
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

$verifierPath = [IO.Path]::GetFullPath([string]$invocation.verifier.path)
$rehearsalManifest = [IO.Path]::GetFullPath([string]$invocation.verifierRehearsalManifest.path)
$applyManifest = [IO.Path]::GetFullPath([string]$invocation.verifierApplyManifest.path)
Require-ExactFile -Path $verifierPath -Sha256 ([string]$invocation.verifier.sha256) -Label 'File-backed verifier'
Require-ExactFile -Path $rehearsalManifest -Sha256 ([string]$invocation.verifierRehearsalManifest.sha256) -Label 'Verifier rehearsal manifest'
Require-ExactFile -Path $applyManifest -Sha256 ([string]$invocation.verifierApplyManifest.sha256) -Label 'Verifier apply manifest'

$recoveryIntentPath = if ([IO.Path]::IsPathRooted([string]$invocation.recoveryIntent.path)) {
    [IO.Path]::GetFullPath([string]$invocation.recoveryIntent.path)
} else {
    [IO.Path]::GetFullPath((Join-Path (Get-Location) ([string]$invocation.recoveryIntent.path)))
}
Require-ExactFile -Path $recoveryIntentPath -Sha256 ([string]$invocation.recoveryIntent.sha256) -Label 'Recovery intent'

if (-not (Test-Path -LiteralPath $failedTargetRoot -PathType Container)) {
    throw "Failed rehearsal target is absent: $failedTargetRoot"
}
if (Test-Path -LiteralPath $targetRoot) {
    throw "Create-new runtime target already exists: $targetRoot"
}
if (Test-Path -LiteralPath $gatePath) {
    throw "Create-new runtime gate already exists: $gatePath"
}
$gateTemporary = "$gatePath.partial"
if (Test-Path -LiteralPath $gateTemporary) {
    throw "Create-new runtime gate temporary path already exists: $gateTemporary"
}

$rehearsal = Invoke-ExactVerifier -PythonPath $pythonPath -VerifierPath $verifierPath -ManifestPath $rehearsalManifest -ExpectedRoot $failedTargetRoot

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3p2_local_runtime_preflight_v1'
        state = 'PASS_O3P2_LOCAL_RUNTIME_PREFLIGHT'
        invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
        invocationSha256 = Get-Sha256 -Path $InvocationManifest
        pythonPath = $pythonPath
        pythonSha256 = [string]$invocation.pythonSha256
        wheelCount = $wheelPaths.Count
        verifierPath = $verifierPath
        verifierSha256 = [string]$invocation.verifier.sha256
        rehearsalState = [string]$rehearsal.state
        rehearsalRoot = [string]$rehearsal.targetRoot
        targetRoot = $targetRoot
        targetExists = $false
        gatePath = $gatePath
        gateExists = $false
        networkAllowed = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 7
    return
}

if (-not $Apply) {
    throw 'Either -Preflight or -Apply is required.'
}

New-Item -ItemType Directory -Path $targetRoot -ErrorAction Stop | Out-Null
$installArguments = New-Object Collections.Generic.List[string]
$installArguments.Add('-m')
$installArguments.Add('pip')
$installArguments.Add('install')
$installArguments.Add('--no-index')
$installArguments.Add('--disable-pip-version-check')
$installArguments.Add('--no-deps')
$installArguments.Add('--target')
$installArguments.Add($targetRoot)
foreach ($wheelPath in $wheelPaths) {
    $installArguments.Add($wheelPath)
}
& $pythonPath @($installArguments.ToArray())
if ($LASTEXITCODE -ne 0) {
    throw "Local offline wheel installation failed with exit code $LASTEXITCODE."
}

$verified = Invoke-ExactVerifier -PythonPath $pythonPath -VerifierPath $verifierPath -ManifestPath $applyManifest -ExpectedRoot $targetRoot
$result = [ordered]@{
    schema = 'argos_ocv03_o3p2_local_runtime_apply_v1'
    state = 'PASS_O3P2_LOCAL_RUNTIME_INSTALLED'
    invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    invocationSha256 = Get-Sha256 -Path $InvocationManifest
    pythonPath = $pythonPath
    pythonSha256 = [string]$verified.pythonSha256
    pythonVersion = [string]$verified.pythonVersion
    opencvVersion = [string]$verified.opencvVersion
    numpyVersion = [string]$verified.numpyVersion
    fileCount = [int]$verified.fileCount
    byteCount = [long]$verified.byteCount
    beforeAfterInventoryEqual = [bool]$verified.beforeAfterInventoryEqual
    wheelCount = $wheelPaths.Count
    targetRoot = $targetRoot
    failedTargetRoot = $failedTargetRoot
    failedTargetReused = $false
    verifierPath = $verifierPath
    verifierSha256 = [string]$invocation.verifier.sha256
    verifierManifestPath = $applyManifest
    verifierManifestSha256 = [string]$invocation.verifierApplyManifest.sha256
    gatePath = $gatePath
    networkAllowed = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$resultJson = $result | ConvertTo-Json -Depth 7
$gateParent = Split-Path -Parent $gatePath
if (-not (Test-Path -LiteralPath $gateParent -PathType Container)) {
    throw "Runtime gate parent is absent: $gateParent"
}
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($gateTemporary, $resultJson + [Environment]::NewLine, $utf8NoBom)
Move-Item -LiteralPath $gateTemporary -Destination $gatePath
if (-not (Test-Path -LiteralPath $gatePath -PathType Leaf)) {
    throw 'Runtime gate commit failed.'
}
$resultJson
