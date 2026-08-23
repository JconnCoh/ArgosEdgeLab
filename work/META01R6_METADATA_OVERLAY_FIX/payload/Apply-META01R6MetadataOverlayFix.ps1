[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Preflight -and $Rehearsal) { throw 'Specify at most one of -Preflight or -Rehearsal.' }

$packageRoot = Split-Path -Parent $PSScriptRoot
$packageLeaf = Split-Path -Leaf $packageRoot
if ($packageLeaf -notmatch '^(REQ_[A-Z0-9_]+)\.ready$') { throw 'Maintenance package root does not expose an exact request identity.' }
$requestId = [string]$Matches[1]

$installRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
if (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) {
    if (-not ($Preflight -or $Rehearsal)) { throw 'Invocation manifest is accepted only for preflight or rehearsal.' }
    $fixture = Get-Content -LiteralPath $InvocationManifest -Raw | ConvertFrom-Json
    if ([string]$fixture.schema -ne 'argos_meta01r6_metadata_overlay_fix_fixture_v1') { throw 'META01R6 fixture schema refused.' }
    $installRoot = [string]$fixture.installRoot
}

$installRoot = [IO.Path]::GetFullPath($installRoot).TrimEnd('\')
$configPath = Join-Path $installRoot 'PROCESSOR_CONFIG.json'
$configSha256 = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$specs = @(
    [pscustomobject]@{
        Name = 'inventory'
        RelativePath = 'Invoke-JbodAllWaferInventory.ps1'
        PredecessorSha256 = 'BF0BAF295F3D1F3234C5C2A5DE184AFEA4BE446BB9593BE9E10BB0E8F932F50A'
        TargetSha256 = '228D9EDD0EFF45E58682659DC6C807FB04F63DD55E48C7F70426BF272C08FA7C'
    },
    [pscustomobject]@{
        Name = 'runner'
        RelativePath = 'Run-JbodAllWaferProcessor.ps1'
        PredecessorSha256 = '8EB83C05CA650C831D2DE8A6AB89ABD2941271B05B31FA93BCFFB553DEAAA892'
        TargetSha256 = '46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
    }
)

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-PathBudget {
    param([string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $longest = 0
    foreach ($part in $full.Split([IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($part.Length -gt $longest) { $longest = $part.Length }
    }
    if (($full.Length + 32) -ge 200 -or $longest -gt 80) { throw "META01R6 path budget refused: $full" }
    return $full
}

foreach ($path in @($installRoot, $configPath)) { [void](Assert-PathBudget $path) }
if (-not (Test-Path -LiteralPath $installRoot -PathType Container)) { throw "META01R6 install root is missing: $installRoot" }
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'META01R6 installed processor config is missing.' }

$actualConfigHash = Get-Sha256 $configPath
if ($actualConfigHash -ne $configSha256) { throw "META01R6 paired processor config hash refused: $actualConfigHash" }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string]$config.schema -ne 'argos_jbod_all_wafer_processor_config_v3' -or
    -not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or [bool]$config.frontsideDefectInspectionEnabled) {
    throw 'META01R6 processor safety contract refused.'
}
if ([string]::IsNullOrWhiteSpace([string]$config.metadataSnapshotRoot)) { throw 'META01R6 configured metadata snapshot root is missing.' }
$metadataRoot = [IO.Path]::GetFullPath([string]$config.metadataSnapshotRoot).TrimEnd('\')
if ($metadataRoot -eq [IO.Path]::GetFullPath((Join-Path $installRoot 'metadata\verified')).TrimEnd('\')) {
    throw 'META01R6 configured metadata snapshot root still resolves to the stale local overlay.'
}

$records = @()
foreach ($spec in $specs) {
    $targetPath = Join-Path $installRoot $spec.RelativePath
    $payloadPath = Join-Path $PSScriptRoot $spec.RelativePath
    foreach ($path in @($targetPath, $payloadPath)) { [void](Assert-PathBudget $path) }
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) { throw "META01R6 installed $($spec.Name) is missing." }
    if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) { throw "META01R6 payload $($spec.Name) is missing." }
    $payloadHash = Get-Sha256 $payloadPath
    if ($payloadHash -ne $spec.TargetSha256) { throw "META01R6 payload $($spec.Name) hash refused: $payloadHash" }
    $beforeHash = Get-Sha256 $targetPath
    if ($beforeHash -notin @($spec.PredecessorSha256, $spec.TargetSha256)) { throw "META01R6 installed $($spec.Name) predecessor hash refused: $beforeHash" }
    $records += [pscustomobject]@{ Spec = $spec; TargetPath = $targetPath; PayloadPath = $payloadPath; BeforeHash = $beforeHash }
}

$preflightResult = [pscustomobject][ordered]@{
    schema = 'argos_meta01r6_metadata_overlay_fix_preflight_v1'
    state = 'PASS_META01R6_METADATA_OVERLAY_FIX_PREFLIGHT'
    requestId = $requestId
    installRoot = $installRoot
    metadataSnapshotRoot = $metadataRoot
    files = @($records | ForEach-Object { [ordered]@{ name = $_.Spec.Name; installedBeforeSha256 = $_.BeforeHash; targetSha256 = $_.Spec.TargetSha256 } })
    taskActions = @()
    processActions = @()
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) { $preflightResult; return }

$backupRoot = Join-Path $installRoot ("state\m6\" + $requestId)
[void](Assert-PathBudget $backupRoot)
$changed = @()
if (@($records | Where-Object { $_.BeforeHash -ne $_.Spec.TargetSha256 }).Count -gt 0) {
    if (Test-Path -LiteralPath $backupRoot) { throw "META01R6 backup root already exists: $backupRoot" }
    [void](New-Item -ItemType Directory -Path $backupRoot)
}
try {
    $index = 0
    foreach ($record in $records) {
        if ($record.BeforeHash -eq $record.Spec.TargetSha256) { $index++; continue }
        $backupPath = Join-Path $backupRoot ("$index.ps1")
        $temporary = Join-Path $installRoot ("M6_$index.tmp")
        foreach ($path in @($backupPath, $temporary)) { [void](Assert-PathBudget $path) }
        if (Test-Path -LiteralPath $temporary) { throw "META01R6 staging path already exists: $temporary" }
        Copy-Item -LiteralPath $record.PayloadPath -Destination $temporary -ErrorAction Stop
        if ((Get-Sha256 $temporary) -ne $record.Spec.TargetSha256) { throw "META01R6 staged $($record.Spec.Name) hash mismatch." }
        [IO.File]::Replace($temporary, $record.TargetPath, $backupPath, $true)
        $changed += [pscustomobject]@{ Record = $record; BackupPath = $backupPath }
        if ((Get-Sha256 $record.TargetPath) -ne $record.Spec.TargetSha256) { throw "META01R6 installed $($record.Spec.Name) hash mismatch after replace." }
        if ((Get-Sha256 $backupPath) -ne $record.Spec.PredecessorSha256) { throw "META01R6 backup $($record.Spec.Name) hash mismatch." }
        $index++
    }
} catch {
    foreach ($item in @($changed | Sort-Object { [array]::IndexOf($changed, $_) } -Descending)) {
        $failedTarget = Join-Path $installRoot ("M6F_" + $item.Record.Spec.Name + '.tmp')
        [IO.File]::Replace($item.BackupPath, $item.Record.TargetPath, $failedTarget, $true)
        if ((Get-Sha256 $item.Record.TargetPath) -ne $item.Record.Spec.PredecessorSha256) { throw "META01R6 rollback $($item.Record.Spec.Name) hash mismatch." }
    }
    throw
}

foreach ($record in $records) {
    if ((Get-Sha256 $record.TargetPath) -ne $record.Spec.TargetSha256) { throw "META01R6 terminal $($record.Spec.Name) hash mismatch." }
}
[pscustomobject][ordered]@{
    schema = 'argos_meta01r6_metadata_overlay_fix_result_v1'
    state = 'PASS_META01R6_METADATA_OVERLAY_FIX'
    requestId = $requestId
    metadataSnapshotRoot = $metadataRoot
    files = @($records | ForEach-Object { [ordered]@{ name = $_.Spec.Name; installedBeforeSha256 = $_.BeforeHash; installedAfterSha256 = $_.Spec.TargetSha256; changed = ($_.BeforeHash -ne $_.Spec.TargetSha256) } })
    taskActions = @()
    processActions = @()
    processorRestarted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    xmlGenerated = $false
}
