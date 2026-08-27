#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T035500111Z_3C97863DBF26'
$uncRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestsRoot = 'U:\ProjectPortalRO\requests'
$responsesRoot = 'U:\ProjectPortalRO\responses'
$target = Join-Path $requestsRoot ($requestId + '.ready.zip')
$upload = $target + '.upload'
$priorResponse = Join-Path $responsesRoot 'R_C74B050C0F51_20260827034006298_4d459405.ready.zip'
$observationPath = Join-Path $PSScriptRoot 'O2D23_CURRENT_SHARE_OBSERVATION.json'
$aliasGatePath = Join-Path $PSScriptRoot 'O2D23_INSPECTIONREVS_U_ALIAS_GATE.json'
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
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D23 create-new share evidence exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine), $utf8)
}

$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logical = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logical) 'O2D23 persistent U: logical disk is absent.'
$displayRoot = ([string]$drive.DisplayRoot).TrimEnd('\')
$providerRoot = ([string]$logical.ProviderName).TrimEnd('\')
Assert-True ($displayRoot.Equals($uncRoot, [StringComparison]::OrdinalIgnoreCase)) 'O2D23 U: PowerShell DisplayRoot changed.'
Assert-True ($providerRoot.Equals($uncRoot, [StringComparison]::OrdinalIgnoreCase) -and [int]$logical.DriveType -eq 4) 'O2D23 U: persistent logical-disk mapping changed.'
Assert-True (Test-Path -LiteralPath $requestsRoot -PathType Container) 'O2D23 requests root is unreadable.'
Assert-True (Test-Path -LiteralPath $responsesRoot -PathType Container) 'O2D23 responses root is unreadable.'

$requestFiles = @(Get-ChildItem -LiteralPath $requestsRoot -File -Force -ErrorAction Stop | Select-Object -First 1001)
Assert-True ($requestFiles.Count -le 1000) 'O2D23 top-level request observation exceeded 1000 files.'
$readyRows = @($requestFiles | Where-Object { $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) })
$uploadRows = @($requestFiles | Where-Object { $_.Name.EndsWith('.upload', [StringComparison]::OrdinalIgnoreCase) })
Assert-True ($readyRows.Count -eq 0 -and $uploadRows.Count -eq 0) 'O2D23 share has a pending request or upload.'
Assert-True (-not (Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $upload)) 'O2D23 target request or upload already exists.'
Assert-True (Test-Path -LiteralPath $priorResponse -PathType Leaf) 'O2D23 prior O2D22 response is absent.'
Assert-True ((Get-Item -LiteralPath $priorResponse).Length -eq 3736) 'O2D23 prior O2D22 response byte count changed.'
Assert-True ((Get-Sha256 $priorResponse) -eq 'D68EF3002168396B993A25C4BD37C4EDB7A54BC6811129936FBCA8A82E33BD42') 'O2D23 prior O2D22 response hash changed.'

$aliasBudget = & $pathTool -CandidatePath @($target,$upload,$observationPath,$aliasGatePath) -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$aliasBudget.state -eq 'PASS_PATH_BUDGET' -and @($aliasBudget.candidates).Count -eq 4) 'O2D23 alias path budget failed.'
$rawTarget = Join-Path (Join-Path $uncRoot 'ProjectPortalRO\requests') ($requestId + '.ready.zip')
$rawUpload = $rawTarget + '.upload'
$maxComponent = (@($target,$upload) | ForEach-Object { @($_.Split([IO.Path]::DirectorySeparatorChar) | ForEach-Object Length | Measure-Object -Maximum).Maximum } | Measure-Object -Maximum).Maximum
$now = [DateTime]::UtcNow.ToString('o')
$normalizedRoot = $uncRoot.Replace('\','/')
$observation = [ordered]@{
    schema='argos_o2d23_current_share_observation_v1';observedUtc=$now;state='PASS_O2D23_CURRENT_SHARE_ZERO_PENDING'
    alias='U:';aliasRoot=$normalizedRoot;powerShellDisplayRootExact=$true;windowsLogicalDiskProviderExact=$true;windowsLogicalDiskDriveType=[int]$logical.DriveType
    requestsRoot=$requestsRoot.Replace('\','/');responsesRoot=$responsesRoot.Replace('\','/');requestsRootReadable=$true;responsesRootReadable=$true
    topLevelPendingReadyZipCount=$readyRows.Count;topLevelPendingUploadCount=$uploadRows.Count;targetAbsent=$true;uploadAbsent=$true
    priorO2D22ResponsePresent=$true;priorO2D22ResponseBytes=3736;priorO2D22ResponseSha256='D68EF3002168396B993A25C4BD37C4EDB7A54BC6811129936FBCA8A82E33BD42'
    requestId=$requestId;targetExecuted=$false;mutationsPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
$aliasGate = [ordered]@{
    schema='argos_o2d23_publication_alias_gate_v1';createdUtc=$now;state='PASS_O2D23_EXACT_INSPECTIONREVS_U_ALIAS_GATE'
    alias='U:';aliasRoot=$normalizedRoot;aliasResolvedExact=$true;persistentMappingVerified=$true;requestsRootReadable=$true
    rawUncTargetLength=$rawTarget.Length;rawUncTargetEffectiveLength=($rawTarget.Length+32);rawUncUploadLength=$rawUpload.Length;rawUncUploadEffectiveLength=($rawUpload.Length+32)
    rawUncDisposition='HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH';aliasTarget=$target.Replace('\','/');aliasTargetLength=$target.Length;aliasTargetEffectiveLength=($target.Length+32)
    aliasUpload=$upload.Replace('\','/');aliasUploadLength=$upload.Length;aliasUploadEffectiveLength=($upload.Length+32);maximumComponentLength=[int]$maxComponent
    aliasPathBudgetState='PASS_PATH_BUDGET';pendingRequestCountAtGate=0;targetAbsentAtGate=$true;uploadAbsentAtGate=$true
    publicationPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false
}

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_current_share_observation_preflight_v1';checkedUtc=$now;state='PASS_O2D23_CURRENT_SHARE_OBSERVATION_PREFLIGHT';pendingRequestCount=0;targetAbsent=$true;uploadAbsent=$true;persistentMappingVerified=$true;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

Write-NewJson $observationPath $observation
Write-NewJson $aliasGatePath $aliasGate
[ordered]@{schema='argos_o2d23_current_share_observation_result_v1';createdUtc=$now;state='PASS_O2D23_CURRENT_SHARE_OBSERVATION_WRITTEN';observationSha256=Get-Sha256 $observationPath;aliasGateSha256=Get-Sha256 $aliasGatePath;mutationsPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
