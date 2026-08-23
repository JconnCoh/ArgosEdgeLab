[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(ParameterSetName = 'Test')][switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

$resolvedManifest = (Resolve-Path -LiteralPath $InvocationManifest).Path
$manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
if ([string]$manifest.schema -ne 'argos_opencv_native_pose_test_invocation_v1') {
    throw "Unsupported invocation schema: $($manifest.schema)"
}
$pythonPath = (Resolve-Path -LiteralPath ([string]$manifest.pythonPath)).Path
$toolPath = (Resolve-Path -LiteralPath ([string]$manifest.toolPath)).Path
if ((Get-Sha256 $toolPath) -ne ([string]$manifest.toolSha256).ToUpperInvariant()) {
    throw 'Pinned OpenCV tool hash does not match.'
}
if ([string]::IsNullOrWhiteSpace([string]$manifest.outputRoot)) {
    throw 'Invocation outputRoot is required.'
}
$outputRoot = [IO.Path]::GetFullPath([string]$manifest.outputRoot)
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
if (-not $outputRoot.StartsWith($projectRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Local test output root must stay inside the authoritative project.'
}

if ($Preflight) {
    $raw = & $pythonPath -B $toolPath --runtime-preflight
    if ($LASTEXITCODE -ne 0) { throw "OpenCV runtime preflight failed with exit code $LASTEXITCODE." }
    $result = $raw | ConvertFrom-Json
    if ([string]$result.state -ne 'PASS_OPENCV_NATIVE_POSE_RUNTIME_PREFLIGHT') {
        throw "Unexpected OpenCV runtime state: $($result.state)"
    }
    [pscustomobject]@{
        schema = 'argos_opencv_native_pose_test_harness_preflight_v1'
        state = 'PASS_OPENCV_NATIVE_POSE_TEST_HARNESS_PREFLIGHT'
        invocationManifest = $resolvedManifest
        invocationManifestSha256 = Get-Sha256 $resolvedManifest
        toolPath = $toolPath
        toolSha256 = Get-Sha256 $toolPath
        pythonPath = $pythonPath
        runtime = $result
        mutationsPerformed = $false
        reviewOnly = $true
    } | ConvertTo-Json -Depth 6
    return
}

if (-not $Test) { throw 'Specify exactly one of -Preflight or -Test.' }
if (Test-Path -LiteralPath $outputRoot) {
    throw "Test output root already exists: $outputRoot"
}
$raw = & $pythonPath -B $toolPath --synthetic-gate --output-root $outputRoot
if ($LASTEXITCODE -ne 0) { throw "OpenCV synthetic gate failed with exit code $LASTEXITCODE.`n$raw" }
$gate = $raw | ConvertFrom-Json
if ([string]$gate.state -ne 'PASS_OPENCV_NATIVE_POSE_SYNTHETIC_GATE') {
    throw "Unexpected OpenCV synthetic gate state: $($gate.state)"
}
$gate | ConvertTo-Json -Depth 8
