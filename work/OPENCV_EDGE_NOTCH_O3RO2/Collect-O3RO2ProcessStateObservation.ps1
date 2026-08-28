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
    if ([string]$manifest.schema -ne 'argos_o3ro2_process_state_collection_invocation_v1') { throw 'Collection invocation schema changed.' }
    if ([string]$manifest.artifactLifecycle -notin @('DRAFT','FROZEN')) { throw 'Collection invocation lifecycle is invalid.' }
    if ($Collect -and [string]$manifest.artifactLifecycle -ne 'FROZEN') { throw 'Collect requires a FROZEN invocation manifest.' }
    if ((Get-Sha256File -Path $scriptPath) -ne [string]$manifest.collector.sha256) { throw 'Collector hash changed.' }
    $projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $sourceInvocationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.sourceInvocation.path)))
    $terminalPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.transportTerminal.path)))
    $observationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.observationGate.path)))
    if ((Get-Sha256File -Path $sourceInvocationPath) -ne [string]$manifest.sourceInvocation.sha256) { throw 'Source invocation hash changed.' }
    if ([string]$manifest.expected.schema -ne 'argos_o3ro2_process_state_result_v1') { throw 'Expected result schema changed.' }
    if ([string]$manifest.expected.computerName -ne 'A1025645101') { throw 'Expected hostname changed.' }
    if ([string]$manifest.expected.executablePath -ne 'D:\AFCV1\rt\python.exe') { throw 'Expected executable path changed.' }
    if ([string]$manifest.expected.commandMarker -ne 'import json,platform,cv2,numpy as np') { throw 'Expected command marker changed.' }
    if ([int]$manifest.expected.maximumRows -ne 8) { throw 'Expected row bound changed.' }
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
        schema = 'argos_o3ro2_process_state_collector_preflight_v1'
        state = 'PASS_O3RO2_PROCESS_STATE_COLLECTOR_PREFLIGHT'
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
        processManagementPerformed = $false
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
if ([string]$result.schema -ne [string]$plan.Manifest.expected.schema) { throw 'Process-state result schema changed.' }
if ([string]$result.state -ne [string]$plan.Manifest.expected.state) { throw 'Process-state result is not the exact expected pass.' }
if ([string]$result.nonce -ne [string]$plan.Manifest.expected.nonce) { throw 'Process-state result nonce changed.' }
if ([string]$result.scalar -ne [string]$plan.Manifest.expected.scalar) { throw 'Process-state result scalar changed.' }
if ([string]$result.computerName -ne [string]$plan.Manifest.expected.computerName) { throw 'Process-state result hostname changed.' }
if ([int]$result.pythonProcessCount -lt 0 -or [int]$result.exactRuntimePathProcessCount -lt 0 -or [int]$result.exactO3RO1ProcessCount -lt 0) { throw 'Process-state result contains a negative count.' }
if ([int]$result.exactRuntimePathProcessCount -gt [int]$result.pythonProcessCount) { throw 'Exact runtime-path count exceeds python process count.' }
if ([int]$result.exactO3RO1ProcessCount -gt [int]$result.exactRuntimePathProcessCount) { throw 'Exact O3RO1 count exceeds exact runtime-path count.' }
if ([int]$result.exactO3RO1ProcessCount -gt [int]$plan.Manifest.expected.maximumRows) { throw 'Exact O3RO1 count exceeds the row bound.' }
$rows = @($result.rows)
if ($rows.Count -ne [int]$result.exactO3RO1ProcessCount) { throw 'Returned row count does not match exact O3RO1 count.' }
$processIds = @()
foreach ($row in $rows) {
    $processId = [uint32]$row.processId
    if ($processId -eq 0 -or $processIds -contains $processId) { throw 'Process IDs must be positive and unique.' }
    $processIds += $processId
    if (-not ([string]$row.executablePath).Equals([string]$plan.Manifest.expected.executablePath,[StringComparison]::OrdinalIgnoreCase)) { throw 'Returned executable path changed.' }
    $commandLine = [string]$row.commandLine
    if ($commandLine.Length -lt 1 -or $commandLine.Length -gt [int]$plan.Manifest.expected.maximumCommandLineCharacters) { throw 'Returned command line is outside the bound.' }
    if ($commandLine.IndexOf([string]$plan.Manifest.expected.commandMarker,[StringComparison]::Ordinal) -lt 0) { throw 'Returned command line lacks the exact O3RO1 marker.' }
    $parsedCreation = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$row.creationUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsedCreation)) { throw 'Returned creationUtc is invalid.' }
}
if ([bool]$result.processManagementPerformed -or [bool]$result.imageBytesRead -or [bool]$result.sourceMutationPerformed -or [bool]$result.targetPersistentMutationPerformed) { throw 'Process-state result reports forbidden action.' }

$classification = if ([int]$result.exactO3RO1ProcessCount -eq 0) {
    'NO_EXACT_O3RO1_PROCESS_RUNNING_COMMAND_EXECUTION_UNPROVED'
} elseif ([int]$result.exactO3RO1ProcessCount -eq 1) {
    'ONE_EXACT_O3RO1_PROCESS_RUNNING_DO_NOT_MANAGE'
} else {
    'MULTIPLE_EXACT_O3RO1_PROCESSES_RUNNING_HOLD_DO_NOT_MANAGE'
}
$observation = [ordered]@{
    schema = 'argos_o3ro2_process_state_observation_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3RO2_PROCESS_STATE_OBSERVATION'
    classification = $classification
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
    pythonProcessCount = [int]$result.pythonProcessCount
    exactRuntimePathProcessCount = [int]$result.exactRuntimePathProcessCount
    exactO3RO1ProcessCount = [int]$result.exactO3RO1ProcessCount
    rows = $rows
    processManagementPerformed = $false
    imageBytesRead = $false
    sourceMutationPerformed = $false
    targetPersistentMutationPerformed = $false
    remoteInputSentByCollector = $false
    localEvidenceWritten = $true
    retryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-CreateNewJson -Path $plan.ObservationPath -Value $observation
$observation | ConvertTo-Json -Depth 12
