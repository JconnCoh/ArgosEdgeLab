#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T171128612Z_R18A'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18A_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18A_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $sourceZip + '.path_gate.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18A_ONE_TIME_PUBLICATION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'R18A_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$preactionSha256 = 'BD80A13C187DC5F7811F0640B021ADB3428D4D68A475C641157E3647175FC9C1'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-True ((Get-Sha256 $preactionPath) -eq $preactionSha256) 'R18A preaction changed.'
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
foreach ($path in @($sourceZip, $packageGatePath, $routeGatePath, $pathSidecar)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R18A publication input missing: $path" }
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$sidecar = Get-Content -LiteralPath $pathSidecar -Raw | ConvertFrom-Json
$sourceSha256 = Get-Sha256 $sourceZip
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Assert-True ([string]$packageGate.state -eq 'PASS_R18A_FINAL_PACKAGE_GATE' -and [string]$routeGate.state -eq 'PASS_R18A_COMPLETE_ROUTE_GATE') 'R18A final gates are not PASS.'
Assert-True ([string]$packageGate.requestId -eq $requestId -and [string]$routeGate.requestId -eq $requestId -and [string]$sidecar.requestId -eq $requestId) 'R18A request identity changed.'
Assert-True ([string]$packageGate.requestZipSha256 -eq $sourceSha256 -and [string]$routeGate.requestZipSha256 -eq $sourceSha256 -and [string]$sidecar.requestZipSha256 -eq $sourceSha256) 'R18A ZIP pin changed.'
Assert-True ([int64]$packageGate.requestZipBytes -eq $sourceBytes -and [bool]$routeGate.publicationAuthorized -and [int]$routeGate.maximumRequestsAuthorized -eq 1 -and -not [bool]$routeGate.retryOnFailure) 'R18A publication scope changed.'
Assert-True ([int]$routeGate.maximumFiles -eq 24 -and [int64]$routeGate.maximumBytes -eq 50331648 -and [int]$routeGate.maximumEffectiveLength -lt 200) 'R18A route/path bounds changed.'
Assert-True (-not (Test-Path -LiteralPath $publishGatePath)) 'R18A publication gate already exists; republish refused.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18A publish requires a clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Assert-True ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot) 'Persistent U mapping changed.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'Portal request root unavailable.'
Assert-True (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18A request identity already exists in the publication route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Assert-True ($pending.Count -eq 0) 'Another portal request is pending; R18A publication refused.'

if ($Preflight) {
    [ordered]@{schema='argos_r18a_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18A_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipBytes=$sourceBytes;requestZipSha256=$sourceSha256;queueState='NEW';pendingRequestCount=0;maximumRequestsAuthorized=1;retryAuthorized=$false;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$sourceStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Assert-True ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $sourceSha256) 'R18A staged upload verification failed.'
Assert-True (-not (Test-Path -LiteralPath $readyPath)) 'R18A ready path appeared before commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$gate = [ordered]@{schema='argos_r18a_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18A_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$sourceSha256;packageGateSha256=(Get-Sha256 $packageGatePath);routeGateSha256=(Get-Sha256 $routeGatePath);branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumRequestsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;requestedFileCount=24;imageFilesRequested=16;pixelsDecoded=$false;taskActions=@();processActions=@();sourceMutationPerformed=$false;waferActionPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $publishGatePath -Value $gate
$gate | ConvertTo-Json -Depth 16
