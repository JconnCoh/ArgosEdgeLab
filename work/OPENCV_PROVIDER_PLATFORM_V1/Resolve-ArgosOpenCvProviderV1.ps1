[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfigurationPath,
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Family,
    [switch]$Preflight,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $Preflight) {
    throw 'Provider resolution is preflight-only in OCV-01.'
}

function Read-BoundedJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int64]$MaximumBytes
    )
    if ($Path.IndexOfAny([char[]]'*?') -ge 0) { throw "Wildcards are not allowed: $Path" }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "File is missing: $Path" }
    $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    $length = (Get-Item -LiteralPath $resolved).Length
    if ($length -gt $MaximumBytes) { throw "File exceeds bounded JSON limit: $resolved" }
    $bytes = [IO.File]::ReadAllBytes($resolved)
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    try { $text = $utf8.GetString($bytes).TrimStart([char]0xFEFF) }
    catch { throw "File is not valid UTF-8: $resolved" }
    return ($text | ConvertFrom-Json)
}

function Test-JbodRoot {
    param([Parameter(Mandatory = $true)][string]$Value)
    return $Value -match '^[Dd]:[\\/]'
}

function New-Resolution {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][bool]$Eligible,
        [Parameter(Mandatory = $true)][bool]$RuntimeProbePerformed,
        [string]$ProviderId = '',
        [string]$RuntimeExecutable = '',
        [string]$EngineEntrypoint = ''
    )
    $result = [pscustomobject]@{
        schema = 'argos_opencv_provider_resolution_v1'
        state = $State
        eligible = $Eligible
        family = $Family
        providerId = $ProviderId
        runtimeProbePerformed = $RuntimeProbePerformed
        runtimeExecutable = $RuntimeExecutable
        engineEntrypoint = $EngineEntrypoint
        providerInvoked = $false
        imageBytesRead = $false
        imageProcessingPerformed = $false
        processorActionPerformed = $false
        holdCleared = $false
    }
    if ($AsJson) { return ($result | ConvertTo-Json -Compress) }
    return $result
}

$config = Read-BoundedJson -Path $ConfigurationPath -MaximumBytes 1048576
if ([string]$config.schema -cne 'argos_opencv_provider_config_v1') {
    New-Resolution -State 'HOLD_OPENCV_SCHEMA_MISMATCH' -Eligible $false -RuntimeProbePerformed $false
    return
}

if (-not [bool]$config.enabled) {
    New-Resolution -State 'DISABLED_UNCHANGED_LEGACY_PATH' -Eligible $false -RuntimeProbePerformed $false
    return
}

$rootNames = @('runtimeRoot', 'workRoot', 'cacheRoot', 'outputRoot')
foreach ($rootName in $rootNames) {
    if (-not ($config.roots.PSObject.Properties.Name -contains $rootName)) {
        New-Resolution -State 'HOLD_OPENCV_SCHEMA_MISMATCH' -Eligible $false -RuntimeProbePerformed $false
        return
    }
    if (-not (Test-JbodRoot -Value ([string]$config.roots.$rootName))) {
        New-Resolution -State 'HOLD_OPENCV_NON_JBOD_ROOT' -Eligible $false -RuntimeProbePerformed $false
        return
    }
}

if (-not ($config.familyBindings.PSObject.Properties.Name -contains $Family)) {
    New-Resolution -State 'HOLD_OPENCV_PROVIDER_MISSING' -Eligible $false -RuntimeProbePerformed $false
    return
}
$providerId = [string]$config.familyBindings.$Family
if ([string]::IsNullOrWhiteSpace($providerId)) {
    New-Resolution -State 'HOLD_OPENCV_PROVIDER_MISSING' -Eligible $false -RuntimeProbePerformed $false
    return
}
$providers = @($config.providers | Where-Object { [string]$_.providerId -ceq $providerId })
if ($providers.Count -ne 1 -or -not [bool]$providers[0].enabled) {
    New-Resolution -State 'HOLD_OPENCV_PROVIDER_MISSING' -Eligible $false -RuntimeProbePerformed $false -ProviderId $providerId
    return
}

$provider = $providers[0]
$runtimeRoot = ([string]$config.roots.runtimeRoot).TrimEnd([char[]]'\/')
$runtimeExecutable = [IO.Path]::GetFullPath($runtimeRoot + '\' + ([string]$provider.runtimeExecutableRelativePath).TrimStart([char[]]'\/'))
$engineEntrypoint = [IO.Path]::GetFullPath($runtimeRoot + '\' + ([string]$provider.engineEntrypointRelativePath).TrimStart([char[]]'\/'))
if (-not (Test-Path -LiteralPath $runtimeExecutable -PathType Leaf) -or -not (Test-Path -LiteralPath $engineEntrypoint -PathType Leaf)) {
    New-Resolution -State 'HOLD_OPENCV_RUNTIME_MISSING' -Eligible $false -RuntimeProbePerformed $true -ProviderId $providerId -RuntimeExecutable $runtimeExecutable -EngineEntrypoint $engineEntrypoint
    return
}

$runtimeHash = (Get-FileHash -LiteralPath $engineEntrypoint -Algorithm SHA256).Hash
if ($runtimeHash -cne [string]$provider.engineSha256) {
    New-Resolution -State 'HOLD_OPENCV_PROVENANCE_MISMATCH' -Eligible $false -RuntimeProbePerformed $true -ProviderId $providerId -RuntimeExecutable $runtimeExecutable -EngineEntrypoint $engineEntrypoint
    return
}

New-Resolution -State 'PASS_OPENCV_PROVIDER_RESOLVED_REVIEW_ONLY' -Eligible $true -RuntimeProbePerformed $true -ProviderId $providerId -RuntimeExecutable $runtimeExecutable -EngineEntrypoint $engineEntrypoint
