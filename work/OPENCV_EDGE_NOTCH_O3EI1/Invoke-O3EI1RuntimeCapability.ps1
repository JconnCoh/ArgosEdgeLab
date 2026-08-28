[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open([IO.Path]::GetFullPath($Path), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Assert-NewPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $components = @($full.Split('\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $longest = if ($components.Count -eq 0) { 0 } else { [int](($components | Measure-Object Length -Maximum).Maximum) }
    if (($full.Length + 32) -ge 200 -or $longest -gt 80) { throw 'O3EI1 output path budget failed.' }
    if (Test-Path -LiteralPath $full) { throw "O3EI1 refuses existing output: $full" }
    return $full
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "O3EI1 refuses overwrite: $Path" }
    $json = ($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush() }
    finally { $stream.Dispose() }
}

$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$providerPath = Join-Path $processorRoot 'Invoke-O3EI1RuntimeProbe.ps1'
$outputPath = Join-Path $processorRoot 'OCV03_O3EI1_RUNTIME_STATUS.json'
$providerInvocation = ''
$failAfterProvider = $false
$expectedProviderSha256 = 'C4BCE3DBC9ABF91E99AE1E1DEB971EEB60610C2A117E645B5903EC4BAD744E8D'

if ($Preflight -or $Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'O3EI1 Preflight/Rehearsal requires InvocationManifest.' }
    $manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or (Get-Item -LiteralPath $manifestPath).Length -gt 65536) { throw 'O3EI1 entrypoint invocation is missing or too large.' }
    $invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]$invocation.schema -ne 'argos_o3ei1_entrypoint_invocation_v1') { throw 'O3EI1 entrypoint invocation schema mismatch.' }
    $processorRoot = [IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $providerPath = [IO.Path]::GetFullPath([string]$invocation.providerPath)
    $outputPath = Join-Path $processorRoot 'OCV03_O3EI1_RUNTIME_STATUS.json'
    $providerInvocation = [IO.Path]::GetFullPath([string]$invocation.providerInvocation)
    $expectedProviderSha256 = [string]$invocation.expectedProviderSha256
    $failAfterProvider = [bool]$invocation.failAfterProvider
}
elseif (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'O3EI1 live mode refuses InvocationManifest.' }

$outputPath = Assert-NewPath $outputPath
if (-not (Test-Path -LiteralPath $providerPath -PathType Leaf)) { throw 'O3EI1 installed provider is missing.' }
if ((Get-Sha256 $providerPath) -ne $expectedProviderSha256) { throw 'O3EI1 installed provider hash changed.' }
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($providerPath, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -ne 0) { throw 'O3EI1 installed provider parser failed.' }

$providerPreflightArgs = @{ Preflight = $true }
if ($Rehearsal -or $Preflight) { $providerPreflightArgs['Rehearsal'] = $true; $providerPreflightArgs['InvocationManifest'] = $providerInvocation }
$providerPreflight = (& $providerPath @providerPreflightArgs) | ConvertFrom-Json
if ([string]$providerPreflight.state -ne 'PASS_O3EI1_RUNTIME_PROBE_PREFLIGHT' -or [bool]$providerPreflight.childProcessStarted -or [bool]$providerPreflight.mutationsPerformed) { throw 'O3EI1 provider preflight contract failed.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3ei1_entrypoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3EI1_ENTRYPOINT_PREFLIGHT'
        providerPath = $providerPath
        providerSha256 = $expectedProviderSha256
        outputPath = $outputPath
        childProcessStarted = $false
        mutationsPerformed = $false
        imageBytesRead = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$providerArgs = @{ Observe = $true }
if ($Rehearsal) { $providerArgs['Rehearsal'] = $true; $providerArgs['InvocationManifest'] = $providerInvocation }
$probe = (& $providerPath @providerArgs) | ConvertFrom-Json
if ($failAfterProvider) { throw 'INJECTED_O3EI1_ENTRYPOINT_FAILURE_AFTER_PROVIDER' }
if ([string]$probe.schema -ne 'argos_o3ei1_runtime_probe_v1' -or [string]$probe.state -notin @('PASS_O3EI1_RUNTIME_PREMISE','HOLD_O3EI1_RUNTIME_VERSION_MISMATCH','HOLD_O3EI1_RUNTIME_TIMEOUT','HOLD_O3EI1_RUNTIME_ERROR','HOLD_O3EI1_RUNTIME_MALFORMED')) { throw 'O3EI1 provider terminal contract changed.' }
if ([bool]$probe.sourceFilesRead -or [bool]$probe.imageBytesRead -or [bool]$probe.sourceMutationPerformed -or @($probe.taskActions).Count -ne 0 -or @($probe.existingProcessActions).Count -ne 0) { throw 'O3EI1 provider crossed the read-only boundary.' }

$result = [ordered]@{
    schema = 'argos_o3ei1_runtime_capability_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3EI1_RUNTIME_CAPABILITY'
    disposition = [string]$probe.state
    runtimePremisePass = [bool]$probe.runtimePremisePass
    providerPath = $providerPath
    providerSha256 = $expectedProviderSha256
    probe = $probe
    imageBytesRead = $false
    sourceMutationPerformed = $false
    protectedProcessorTouched = $false
    taskActions = @()
    existingProcessActions = @()
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-JsonCreateNew $outputPath $result
$readback = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
if ([string]$readback.state -ne 'PASS_O3EI1_RUNTIME_CAPABILITY' -or [string]$readback.disposition -ne [string]$probe.state) { throw 'O3EI1 output readback failed.' }
$result['capabilityOutputPath'] = $outputPath
$result['capabilityOutputSha256'] = Get-Sha256 $outputPath
$result['capabilityOutputBytes'] = (Get-Item -LiteralPath $outputPath).Length
$result | ConvertTo-Json -Depth 20
