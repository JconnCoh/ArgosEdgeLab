[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptPath = [IO.Path]::GetFullPath($PSCommandPath)

function Get-Sha256File([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($resolved)) { throw "Required file is absent: $resolved" }
    $stream = [IO.File]::OpenRead($resolved)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-ExactJson([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($resolved)) { throw "JSON file is absent: $resolved" }
    $bytes = [IO.File]::ReadAllBytes($resolved)
    if ($bytes.Length -gt 65536) { throw "JSON file exceeds 65,536 bytes: $resolved" }
    return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop)
}

function Write-CreateNewJson([string]$Path,[object]$Value) {
    $resolved = [IO.Path]::GetFullPath($Path)
    $json = $Value | ConvertTo-Json -Depth 16
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = [IO.File]::Open($resolved,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

function Get-Plan {
    if ([bool]$Preflight -eq [bool]$Collect) { throw 'Specify exactly one of -Preflight or -Collect.' }
    $manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
    $manifest = Get-ExactJson -Path $manifestPath
    if ([string]$manifest.schema -ne 'argos_o3ro1_runtime_observation_collection_invocation_v1') { throw 'Collection invocation schema changed.' }
    if ([string]$manifest.artifactLifecycle -notin @('DRAFT','FROZEN')) { throw 'Collection invocation lifecycle is invalid.' }
    if ($Collect -and [string]$manifest.artifactLifecycle -ne 'FROZEN') { throw 'Collect requires a FROZEN invocation manifest.' }
    if ((Get-Sha256File -Path $scriptPath) -ne [string]$manifest.collector.sha256) { throw 'Collector hash changed.' }
    $projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $sourceInvocationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.sourceInvocation.path)))
    $terminalPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.transportTerminal.path)))
    $observationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.observationGate.path)))
    if ((Get-Sha256File -Path $sourceInvocationPath) -ne [string]$manifest.sourceInvocation.sha256) { throw 'Source invocation hash changed.' }
    if ([string]$manifest.expected.schema -ne 'argos_o3ro1_runtime_versions_result_v1') { throw 'Expected result schema changed.' }
    if ([string]$manifest.expected.computerName -ne 'A1025645101') { throw 'Expected hostname changed.' }
    if ([string]$manifest.expected.pythonPath -ne 'D:\AFCV1\rt\python.exe') { throw 'Expected Python path changed.' }
    if ([string]$manifest.expected.installationPath -ne 'D:\AFCV1\INSTALLATION.json') { throw 'Expected installation path changed.' }
    if ([IO.File]::Exists($observationPath)) { throw "Create-new observation gate already exists: $observationPath" }
    return [pscustomobject]@{
        Manifest = $manifest
        ManifestPath = $manifestPath
        SourceInvocationPath = $sourceInvocationPath
        TerminalPath = $terminalPath
        ObservationPath = $observationPath
    }
}

$plan = Get-Plan
if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3ro1_runtime_observation_collector_preflight_v1'
        state = 'PASS_O3RO1_RUNTIME_OBSERVATION_COLLECTOR_PREFLIGHT'
        artifactLifecycle = [string]$plan.Manifest.artifactLifecycle
        collectorSha256 = Get-Sha256File -Path $scriptPath
        invocationManifestSha256 = Get-Sha256File -Path $plan.ManifestPath
        sourceInvocationSha256 = Get-Sha256File -Path $plan.SourceInvocationPath
        transportTerminalExists = [IO.File]::Exists($plan.TerminalPath)
        observationGateExists = $false
        clipboardRead = $false
        remoteInputSent = $false
        targetExecuted = $false
        localEvidenceWritten = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}

$terminal = Get-ExactJson -Path $plan.TerminalPath
if ([string]$terminal.schema -ne 'argos_o3tc1_fresh_console_short_trigger_terminal_v1') { throw 'Transport terminal schema changed.' }
if ([string]$terminal.state -ne 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER' -or [string]$terminal.stage -ne 'COMPLETE') { throw 'Transport terminal is not a complete pass.' }
if ([string]$terminal.invocationManifestSha256 -ne [string]$plan.Manifest.sourceInvocation.sha256) { throw 'Transport terminal invocation hash changed.' }
if ([string]$terminal.entrypointSha256 -ne [string]$plan.Manifest.entrypoint.sha256) { throw 'Transport terminal entrypoint hash changed.' }
if ([string]$terminal.payloadSha256 -ne [string]$plan.Manifest.payload.sha256) { throw 'Transport terminal payload hash changed.' }
if (-not [bool]$terminal.remoteInputAttempted -or -not [bool]$terminal.freshConsoleOpened -or -not [bool]$terminal.hostnameGatePassed -or -not [bool]$terminal.payloadTriggerSubmitted -or -not [bool]$terminal.resultReturned) { throw 'Transport terminal lacks exact execution proof.' }
if ([string]$terminal.resultNonce -ne [string]$plan.Manifest.expected.nonce -or [string]$terminal.resultScalar -ne [string]$plan.Manifest.expected.scalar) { throw 'Transport terminal result identity changed.' }
if ([bool]$terminal.originalTwoStrandedConsolesInputSent -or [bool]$terminal.targetPersistentMutationPerformed) { throw 'Transport terminal reports forbidden action.' }

$raw = [string](Get-Clipboard -Raw -ErrorAction Stop)
if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 65536) { throw 'Clipboard result is empty or exceeds 65,536 characters.' }
$result = $raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$result.schema -ne [string]$plan.Manifest.expected.schema) { throw 'Runtime result schema changed.' }
if ([string]$result.state -ne [string]$plan.Manifest.expected.state) { throw 'Runtime result is not the exact expected pass.' }
if ([string]$result.nonce -ne [string]$plan.Manifest.expected.nonce) { throw 'Runtime result nonce changed.' }
if ([string]$result.scalar -ne [string]$plan.Manifest.expected.scalar) { throw 'Runtime result scalar changed.' }
if ([string]$result.computerName -ne [string]$plan.Manifest.expected.computerName) { throw 'Runtime result hostname changed.' }
if ([string]$result.pythonPath -ne [string]$plan.Manifest.expected.pythonPath) { throw 'Runtime result Python path changed.' }
if ([string]$result.installationPath -ne [string]$plan.Manifest.expected.installationPath) { throw 'Runtime result installation path changed.' }
foreach ($property in @('pythonSha256','installationSha256')) {
    if ([string]$result.$property -notmatch '\A[0-9A-Fa-f]{64}\z') { throw "Runtime result $property is not SHA-256." }
}
foreach ($property in @('pythonVersion','opencvVersion','numpyVersion')) {
    $value = [string]$result.$property
    if ($value -notmatch '\A[0-9A-Za-z._+\-]{1,64}\z') { throw "Runtime result $property is invalid." }
}
if ([bool]$result.imageBytesRead -or [bool]$result.sourceMutationPerformed -or [bool]$result.taskOrProcessManagementPerformed -or [bool]$result.targetPersistentMutationPerformed) { throw 'Runtime result reports forbidden action.' }

$observation = [ordered]@{
    schema = 'argos_o3ro1_runtime_observation_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3RO1_RUNTIME_VERSION_OBSERVATION'
    incidentId = 'OCV03_O3Q2_NUMPY_RUNTIME_PREMISE_20260828'
    collectionInvocationPath = [string]$plan.Manifest.collectionInvocationPath
    collectionInvocationSha256 = Get-Sha256File -Path $plan.ManifestPath
    collectorPath = [string]$plan.Manifest.collector.path
    collectorSha256 = Get-Sha256File -Path $scriptPath
    transportTerminalPath = [string]$plan.Manifest.transportTerminal.path
    transportTerminalSha256 = Get-Sha256File -Path $plan.TerminalPath
    sourceInvocationPath = [string]$plan.Manifest.sourceInvocation.path
    sourceInvocationSha256 = Get-Sha256File -Path $plan.SourceInvocationPath
    payloadPath = [string]$plan.Manifest.payload.path
    payloadSha256 = [string]$plan.Manifest.payload.sha256
    nonce = [string]$result.nonce
    computerName = [string]$result.computerName
    scalar = [string]$result.scalar
    pythonPath = [string]$result.pythonPath
    pythonSha256 = ([string]$result.pythonSha256).ToUpperInvariant()
    installationPath = [string]$result.installationPath
    installationSha256 = ([string]$result.installationSha256).ToUpperInvariant()
    pythonVersion = [string]$result.pythonVersion
    opencvVersion = [string]$result.opencvVersion
    numpyVersion = [string]$result.numpyVersion
    imageBytesRead = $false
    sourceMutationPerformed = $false
    taskOrProcessManagementPerformed = $false
    targetPersistentMutationPerformed = $false
    remoteInputSentByCollector = $false
    localEvidenceWritten = $true
    retryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-CreateNewJson -Path $plan.ObservationPath -Value $observation
$observation | ConvertTo-Json -Depth 12
