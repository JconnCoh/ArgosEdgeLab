[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest
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
    $bytes = [IO.File]::ReadAllBytes($resolved)
    if ($bytes.Length -gt 65536) { throw "JSON file exceeds 65,536 bytes: $resolved" }
    return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop)
}

function Write-CreateNewJson([string]$Path,[object]$Value) {
    $json = $Value | ConvertTo-Json -Depth 16
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = [IO.File]::Open([IO.Path]::GetFullPath($Path),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
}

if ([bool]$Preflight -eq [bool]$Collect) { throw 'Specify exactly one of -Preflight or -Collect.' }
$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
$manifest = Get-ExactJson -Path $manifestPath
if ([string]$manifest.schema -ne 'argos_o3ro3_process_state_collection_invocation_v1') { throw 'Collection invocation schema changed.' }
if ([string]$manifest.artifactLifecycle -notin @('DRAFT','FROZEN')) { throw 'Collection invocation lifecycle is invalid.' }
if ($Collect -and [string]$manifest.artifactLifecycle -ne 'FROZEN') { throw 'Collect requires a FROZEN invocation manifest.' }
if ((Get-Sha256File -Path $scriptPath) -ne [string]$manifest.collector.sha256) { throw 'Collector hash changed.' }
$projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd([IO.Path]::DirectorySeparatorChar)
$sourceInvocationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.sourceInvocation.path)))
$terminalPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.transportTerminal.path)))
$observationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.observationGate.path)))
if ((Get-Sha256File -Path $sourceInvocationPath) -ne [string]$manifest.sourceInvocation.sha256) { throw 'Source invocation hash changed.' }
if ([string]$manifest.expected.schema -ne 'argos_o3ro3_process_state_result_v1') { throw 'Expected result schema changed.' }
if ([string]$manifest.expected.computerName -ne 'A1025645101') { throw 'Expected hostname changed.' }
if ([string]$manifest.expected.executablePath -ne 'D:\AFCV1\rt\python.exe') { throw 'Expected executable path changed.' }
if ([string]$manifest.expected.commandMarker -ne 'import json,platform,cv2,numpy as np') { throw 'Expected command marker changed.' }
if ([int]$manifest.expected.maximumRows -ne 8) { throw 'Expected row bound changed.' }
if ([IO.File]::Exists($observationPath)) { throw "Create-new observation gate already exists: $observationPath" }

if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3ro3_process_state_collector_preflight_v1'
        state = 'PASS_O3RO3_PROCESS_STATE_COLLECTOR_PREFLIGHT'
        artifactLifecycle = [string]$manifest.artifactLifecycle
        collectorSha256 = Get-Sha256File -Path $scriptPath
        invocationManifestSha256 = Get-Sha256File -Path $manifestPath
        sourceInvocationSha256 = Get-Sha256File -Path $sourceInvocationPath
        transportTerminalExists = [IO.File]::Exists($terminalPath)
        observationGateExists = $false
        clipboardRead = $false
        remoteInputSent = $false
        targetExecuted = $false
        localEvidenceWritten = $false
        taskOrProcessManagementPerformed = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

$terminal = Get-ExactJson -Path $terminalPath
if ([string]$terminal.schema -ne 'argos_o3tc1_fresh_console_short_trigger_terminal_v1' -or [string]$terminal.state -ne 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER' -or [string]$terminal.stage -ne 'COMPLETE') { throw 'Transport terminal is not the exact complete pass.' }
if ([string]$terminal.invocationManifestSha256 -ne [string]$manifest.sourceInvocation.sha256 -or [string]$terminal.entrypointSha256 -ne [string]$manifest.entrypoint.sha256 -or [string]$terminal.payloadSha256 -ne [string]$manifest.payload.sha256) { throw 'Transport terminal hashes changed.' }
if (-not [bool]$terminal.remoteInputAttempted -or -not [bool]$terminal.freshConsoleOpened -or -not [bool]$terminal.hostnameGatePassed -or -not [bool]$terminal.payloadTriggerSubmitted -or -not [bool]$terminal.resultReturned) { throw 'Transport terminal lacks exact execution proof.' }
if ([string]$terminal.resultNonce -ne [string]$manifest.expected.nonce -or [string]$terminal.resultScalar -ne [string]$manifest.expected.scalar) { throw 'Transport terminal result identity changed.' }
if ([bool]$terminal.originalTwoStrandedConsolesInputSent -or [bool]$terminal.targetPersistentMutationPerformed) { throw 'Transport terminal reports forbidden action.' }

$raw = [string](Get-Clipboard -Raw -ErrorAction Stop)
if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -gt 65536) { throw 'Clipboard result is empty or exceeds 65,536 characters.' }
$result = $raw | ConvertFrom-Json -ErrorAction Stop
foreach ($name in @('schema','state','nonce','computerName','scalar','taskOrProcessManagementPerformed','processManagementPerformed','imageBytesRead','sourceMutationPerformed','targetPersistentMutationPerformed')) {
    if ($null -eq $result.PSObject.Properties[$name]) { throw "Result property is absent: $name" }
}
if ([string]$result.schema -ne [string]$manifest.expected.schema -or [string]$result.state -ne [string]$manifest.expected.state -or [string]$result.nonce -ne [string]$manifest.expected.nonce -or [string]$result.scalar -ne [string]$manifest.expected.scalar -or [string]$result.computerName -ne [string]$manifest.expected.computerName) { throw 'Process-state result identity changed.' }
if ([bool]$result.taskOrProcessManagementPerformed -or [bool]$result.processManagementPerformed -or [bool]$result.imageBytesRead -or [bool]$result.sourceMutationPerformed -or [bool]$result.targetPersistentMutationPerformed) { throw 'Process-state result reports forbidden action.' }
$pythonCount = [int]$result.pythonProcessCount
$pathCount = [int]$result.exactRuntimePathProcessCount
$exactCount = [int]$result.exactO3RO1ProcessCount
if ($pythonCount -lt 0 -or $pathCount -lt 0 -or $exactCount -lt 0 -or $pathCount -gt $pythonCount -or $exactCount -gt $pathCount -or $exactCount -gt [int]$manifest.expected.maximumRows) { throw 'Process-state counts are invalid.' }
$rows = @($result.rows)
if ($rows.Count -ne $exactCount) { throw 'Returned row count does not match exact O3RO1 count.' }
$processIds = @()
foreach ($row in $rows) {
    $processId = [uint32]$row.processId
    if ($processId -eq 0 -or $processIds -contains $processId) { throw 'Process IDs must be positive and unique.' }
    $processIds += $processId
    if (-not ([string]$row.executablePath).Equals([string]$manifest.expected.executablePath,[StringComparison]::OrdinalIgnoreCase)) { throw 'Returned executable path changed.' }
    $commandLine = [string]$row.commandLine
    if ($commandLine.Length -lt 1 -or $commandLine.Length -gt [int]$manifest.expected.maximumCommandLineCharacters -or $commandLine.IndexOf([string]$manifest.expected.commandMarker,[StringComparison]::Ordinal) -lt 0) { throw 'Returned command line is invalid.' }
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse([string]$row.creationUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)) { throw 'Returned creationUtc is invalid.' }
}
$classification = if ($exactCount -eq 0) { 'NO_EXACT_O3RO1_PROCESS_RUNNING_COMMAND_EXECUTION_UNPROVED' } elseif ($exactCount -eq 1) { 'ONE_EXACT_O3RO1_PROCESS_RUNNING_DO_NOT_MANAGE' } else { 'MULTIPLE_EXACT_O3RO1_PROCESSES_RUNNING_HOLD_DO_NOT_MANAGE' }
$observation = [ordered]@{
    schema = 'argos_o3ro3_process_state_observation_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3RO3_PROCESS_STATE_OBSERVATION'
    classification = $classification
    incidentId = 'OCV03_O3Q2_NUMPY_RUNTIME_PREMISE_20260828'
    collectionInvocationPath = [string]$manifest.collectionInvocationPath
    collectionInvocationSha256 = Get-Sha256File -Path $manifestPath
    collectorPath = [string]$manifest.collector.path
    collectorSha256 = Get-Sha256File -Path $scriptPath
    transportTerminalPath = [string]$manifest.transportTerminal.path
    transportTerminalSha256 = Get-Sha256File -Path $terminalPath
    sourceInvocationPath = [string]$manifest.sourceInvocation.path
    sourceInvocationSha256 = Get-Sha256File -Path $sourceInvocationPath
    payloadPath = [string]$manifest.payload.path
    payloadSha256 = [string]$manifest.payload.sha256
    nonce = [string]$result.nonce
    computerName = [string]$result.computerName
    scalar = [string]$result.scalar
    pythonProcessCount = $pythonCount
    exactRuntimePathProcessCount = $pathCount
    exactO3RO1ProcessCount = $exactCount
    rows = $rows
    taskOrProcessManagementPerformed = $false
    imageBytesRead = $false
    sourceMutationPerformed = $false
    targetPersistentMutationPerformed = $false
    remoteInputSentByCollector = $false
    localEvidenceWritten = $true
    retryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-CreateNewJson -Path $observationPath -Value $observation
$observation | ConvertTo-Json -Depth 12
