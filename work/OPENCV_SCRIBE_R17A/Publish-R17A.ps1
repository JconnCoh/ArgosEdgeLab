#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T142600000Z_R17A'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R17A_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R17A_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $sourceZip + '.path_gate.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R17A_ONE_TIME_PUBLICATION.json'
$intentPath = Join-Path $PSScriptRoot 'R17A_RECOVERY_INTENT.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$intentTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'R17A_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$preactionSha256 = '54D1FC542B255B6A31193D5584503452C399C063C573DDBC249D7CEB98BB5AF9'
$intentSha256 = '06643F8505B1DC952B222CACFC2B08E144563F107D7BDFC6776B1E993DD73754'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-True ((Get-Sha256 $preactionPath) -eq $preactionSha256) 'R17A preaction changed.'
Assert-True ((Get-Sha256 $intentPath) -eq $intentSha256) 'R17A recovery intent changed.'
& $intentTool -IntentPath $intentPath -ProjectRoot $project -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
foreach ($path in @($sourceZip, $packageGatePath, $routeGatePath, $pathSidecar)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R17A publication input missing: $path" }
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$sidecar = Get-Content -LiteralPath $pathSidecar -Raw | ConvertFrom-Json
$sourceSha256 = Get-Sha256 $sourceZip
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Assert-True ([string]$packageGate.state -eq 'PASS_R17A_FINAL_PACKAGE_GATE' -and [string]$routeGate.state -eq 'PASS_R17A_COMPLETE_ROUTE_GATE') 'R17A final gates are not PASS.'
Assert-True ([string]$packageGate.requestId -eq $requestId -and [string]$routeGate.requestId -eq $requestId -and [string]$sidecar.requestId -eq $requestId) 'R17A request identity changed.'
Assert-True ([string]$packageGate.requestZipSha256 -eq $sourceSha256 -and [string]$routeGate.requestZipSha256 -eq $sourceSha256 -and [string]$sidecar.requestZipSha256 -eq $sourceSha256) 'R17A ZIP pin changed.'
Assert-True ([int64]$packageGate.requestZipBytes -eq $sourceBytes -and [bool]$routeGate.publicationAuthorized -and [int]$routeGate.maximumRequestsAuthorized -eq 1 -and -not [bool]$routeGate.retryOnFailure) 'R17A publication scope changed.'
Assert-True ([int]$routeGate.maximumFiles -eq 24 -and [int64]$routeGate.maximumBytes -eq 50331648 -and [int]$routeGate.maximumEffectiveLength -lt 200) 'R17A route/path bounds changed.'
Assert-True (-not (Test-Path -LiteralPath $publishGatePath)) 'R17A publication gate already exists; republish refused.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R17A publish requires a clean dedicated branch matching origin.'
Assert-True ((Get-PSDrive -Name U -ErrorAction Stop).DisplayRoot -eq $shareRoot) 'Persistent U mapping changed.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'Portal request root unavailable.'
Assert-True (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R17A request identity already exists in the publication route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Assert-True ($pending.Count -eq 0) 'Another portal request is pending; R17A publication refused.'

if ($Preflight) {
    [ordered]@{schema='argos_r17a_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R17A_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipBytes=$sourceBytes;requestZipSha256=$sourceSha256;queueState='NEW';pendingRequestCount=0;maximumRequestsAuthorized=1;retryAuthorized=$false;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$sourceStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Assert-True ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $sourceSha256) 'R17A staged upload verification failed.'
Assert-True (-not (Test-Path -LiteralPath $readyPath)) 'R17A ready path appeared before commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$gate = [ordered]@{schema='argos_r17a_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R17A_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$sourceSha256;packageGateSha256=(Get-Sha256 $packageGatePath);routeGateSha256=(Get-Sha256 $routeGatePath);branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumRequestsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;requestedFileCount=24;imageFilesRequested=16;pixelsDecoded=$false;taskActions=@();processActions=@();sourceMutationPerformed=$false;waferActionPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $publishGatePath -Value $gate
$gate | ConvertTo-Json -Depth 16
