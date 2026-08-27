#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T141000111Z_62629419C3A1'
$uncRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestsRoot = 'U:\ProjectPortalRO\requests'
$responsesRoot = 'U:\ProjectPortalRO\responses'
$target = Join-Path $requestsRoot ($requestId + '.ready.zip')
$upload = $target + '.upload'
$priorResponse = Join-Path $responsesRoot 'R_E15698774150_20260827044400129_f775f729.ready.zip'
$observationPath = Join-Path $PSScriptRoot 'O3C1_CURRENT_SHARE_OBSERVATION.json'
$aliasGatePath = Join-Path $PSScriptRoot 'O3C1_INSPECTIONREVS_U_ALIAS_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}
function Write-NewJson([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3C1 create-new share evidence exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $utf8)
}

$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logical = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logical) 'O3C1 persistent U: logical disk is absent.'
$displayRoot = ([string]$drive.DisplayRoot).TrimEnd('\')
$providerRoot = ([string]$logical.ProviderName).TrimEnd('\')
Assert-True ($displayRoot.Equals($uncRoot, [StringComparison]::OrdinalIgnoreCase)) 'O3C1 U: PowerShell DisplayRoot changed.'
Assert-True ($providerRoot.Equals($uncRoot, [StringComparison]::OrdinalIgnoreCase) -and [int]$logical.DriveType -eq 4) 'O3C1 U: persistent logical-disk mapping changed.'
Assert-True (Test-Path -LiteralPath $requestsRoot -PathType Container) 'O3C1 requests root is unreadable.'
Assert-True (Test-Path -LiteralPath $responsesRoot -PathType Container) 'O3C1 responses root is unreadable.'

$requestFiles = @(Get-ChildItem -LiteralPath $requestsRoot -File -Force -ErrorAction Stop | Select-Object -First 1001)
Assert-True ($requestFiles.Count -le 1000) 'O3C1 top-level request observation exceeded 1000 files.'
$readyRows = @($requestFiles | Where-Object { $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) })
$uploadRows = @($requestFiles | Where-Object { $_.Name.EndsWith('.upload', [StringComparison]::OrdinalIgnoreCase) })
Assert-True ($readyRows.Count -eq 0 -and $uploadRows.Count -eq 0) 'O3C1 share has a pending request or upload.'
Assert-True (-not (Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $upload)) 'O3C1 target request or upload already exists.'
Assert-True (Test-Path -LiteralPath $priorResponse -PathType Leaf) 'O3C1 prior O2D23 response is absent.'
Assert-True ((Get-Item -LiteralPath $priorResponse).Length -eq 3697) 'O3C1 prior O2D23 response byte count changed.'
Assert-True ((Get-Sha256 $priorResponse) -eq '044066FEF469C05DC4C1F8E907C929486D9FC3DFE75315C1A885485BED8C589A') 'O3C1 prior O2D23 response hash changed.'

$aliasBudget = & $pathTool -CandidatePath @($target,$upload,$observationPath,$aliasGatePath) -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$aliasBudget.state -eq 'PASS_PATH_BUDGET' -and @($aliasBudget.candidates).Count -eq 4) 'O3C1 alias path budget failed.'
$rawTarget = Join-Path (Join-Path $uncRoot 'ProjectPortalRO\requests') ($requestId + '.ready.zip')
$rawUpload = $rawTarget + '.upload'
$maxComponent = (@($target,$upload) | ForEach-Object { @($_.Split([IO.Path]::DirectorySeparatorChar) | ForEach-Object Length | Measure-Object -Maximum).Maximum } | Measure-Object -Maximum).Maximum
$now = [DateTime]::UtcNow.ToString('o')
$normalizedRoot = $uncRoot.Replace('\','/')
$observation = [ordered]@{
    schema='argos_o3c1_current_share_observation_v1';observedUtc=$now;state='PASS_O3C1_CURRENT_SHARE_ZERO_PENDING'
    alias='U:';aliasRoot=$normalizedRoot;powerShellDisplayRootExact=$true;windowsLogicalDiskProviderExact=$true;windowsLogicalDiskDriveType=[int]$logical.DriveType
    requestsRoot=$requestsRoot.Replace('\','/');responsesRoot=$responsesRoot.Replace('\','/');requestsRootReadable=$true;responsesRootReadable=$true
    topLevelPendingReadyZipCount=$readyRows.Count;topLevelPendingUploadCount=$uploadRows.Count;targetAbsent=$true;uploadAbsent=$true
    priorO2D23ResponsePresent=$true;priorO2D23ResponseBytes=3697;priorO2D23ResponseSha256='044066FEF469C05DC4C1F8E907C929486D9FC3DFE75315C1A885485BED8C589A'
    requestId=$requestId;targetExecuted=$false;mutationsPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
$aliasGate = [ordered]@{
    schema='argos_o3c1_publication_alias_gate_v1';createdUtc=$now;state='PASS_O3C1_EXACT_INSPECTIONREVS_U_ALIAS_GATE'
    alias='U:';aliasRoot=$normalizedRoot;aliasResolvedExact=$true;persistentMappingVerified=$true;requestsRootReadable=$true
    rawUncTargetLength=$rawTarget.Length;rawUncTargetEffectiveLength=($rawTarget.Length+32);rawUncUploadLength=$rawUpload.Length;rawUncUploadEffectiveLength=($rawUpload.Length+32)
    rawUncDisposition='HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH';aliasTarget=$target.Replace('\','/');aliasTargetLength=$target.Length;aliasTargetEffectiveLength=($target.Length+32)
    aliasUpload=$upload.Replace('\','/');aliasUploadLength=$upload.Length;aliasUploadEffectiveLength=($upload.Length+32);maximumComponentLength=[int]$maxComponent
    aliasPathBudgetState='PASS_PATH_BUDGET';pendingRequestCountAtGate=0;targetAbsentAtGate=$true;uploadAbsentAtGate=$true
    publicationPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false
}

if ($Preflight) {
    [ordered]@{schema='argos_o3c1_current_share_observation_preflight_v1';checkedUtc=$now;state='PASS_O3C1_CURRENT_SHARE_OBSERVATION_PREFLIGHT';pendingRequestCount=0;targetAbsent=$true;uploadAbsent=$true;persistentMappingVerified=$true;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

Write-NewJson $observationPath $observation
Write-NewJson $aliasGatePath $aliasGate
[ordered]@{schema='argos_o3c1_current_share_observation_result_v1';createdUtc=$now;state='PASS_O3C1_CURRENT_SHARE_OBSERVATION_WRITTEN';observationSha256=Get-Sha256 $observationPath;aliasGateSha256=Get-Sha256 $aliasGatePath;mutationsPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5


