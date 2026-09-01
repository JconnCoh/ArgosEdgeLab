#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Publish) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260901T220000222Z_5A348AE509A4'
$branch = 'codex/opencv-scribe-deciphering'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$sourceZip = Join-Path $project ('work\OPENCV_SCRIBE_R6V2\final\' + $requestId + '.ready.zip')
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')
$finalGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R6V2\R6V2_FINAL_PACKAGE_GATE.json'
$pathGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R6V2\R6V2_PATH_ROUTE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R6V2_CURRENT_ROUTE_SHARE_GATE.json'
$publishGatePath = Join-Path $PSScriptRoot 'R6V2_PUBLISH_GATE.json'
$expectedZipSha = '1048FB48EFDB736D397A856E75AD1A3F8B0D59599766636F9ABB1353C2AB291D'
$expectedZipBytes = 29794L
$expectedFinalGateSha = 'AF461D346CF6A6FAFD9B3B63FF6F13E0DDB9EF84DEF0E3E1871D739D0B8545BA'
$expectedPathGateSha = '6AD3325DE6A8DDFC98D503731F69CC18C4A002674E58E0AAD0D874AA47FDE352'
$expectedRouteGateSha = '408AC7832CA5DD9EF12F048E8448BF8E5F2F01341159646937C69A3FF4E01822'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Assert-Pin([string]$Path, [string]$Expected) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R6V2 publication dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Expected) "R6V2 publication dependency changed: $Path"
}
function Normalize-Root([string]$Path) { return $Path.Replace('/', '\').TrimEnd('\') }
function Write-GateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

Assert-Pin $sourceZip $expectedZipSha
Assert-Pin $finalGatePath $expectedFinalGateSha
Assert-Pin $pathGatePath $expectedPathGateSha
Assert-Pin $routeGatePath $expectedRouteGateSha
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'R6V2 frozen ZIP byte count changed.'
$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
$pathGate = Get-Content -Raw -LiteralPath $pathGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_R6V2_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $expectedZipSha) 'R6V2 final package identity changed.'
Assert-True ([bool]$finalGate.exactFinalZipExtractionPassed -and [bool]$finalGate.exactFinalZipSignaturePassed -and -not [bool]$finalGate.publicationAuthorized) 'R6V2 frozen package contract changed.'
Assert-True ([string]$pathGate.state -eq 'PASS_R6V2_PATH_ROUTE_GATE' -and [int]$pathGate.maximumEffectiveLength -lt 200) 'R6V2 complete path route gate changed.'
Assert-True ([string]$routeGate.state -eq 'PASS_R6V2_CURRENT_ROUTE_SHARE_AND_QUEUE_GATE' -and [string]$routeGate.requestId -eq $requestId) 'R6V2 current route gate changed.'
Assert-True ([bool]$routeGate.publication.authorized -and [int]$routeGate.publication.maximumPublications -eq 1 -and -not [bool]$routeGate.publication.retryAuthorized -and [bool]$routeGate.publication.matchingSignedTerminalResponseOnly) 'R6V2 publication boundary changed.'
Assert-True ([int]$routeGate.queueObservation.pendingRequestFileCount -eq 0 -and [int]$routeGate.queueObservation.unresolvedEarlierAcceptedRequestCount -eq 0 -and [int]$routeGate.queueObservation.exactRequestIdProcessedMatchCount -eq 0 -and [int]$routeGate.queueObservation.exactRequestIdResponseMatchCount -eq 0) 'R6V2 recorded queue route is not clear.'
Assert-True ([bool]$routeGate.priorRequestTerminalEvidence.matchingSignedTerminalResponseRecorded) 'R6V1 terminal evidence is absent.'
Assert-True ([bool]$routeGate.reviewOnly -and -not [bool]$routeGate.automaticIdentityAuthority -and -not [bool]$routeGate.mayClearHolds -and -not [bool]$routeGate.providerActivated -and -not [bool]$routeGate.xmlEligible -and -not [bool]$routeGate.productionEligible) 'R6V2 route authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'R6V2 publication requires matching local/origin branch tips.'
$worktreeRows = @(& git -C $project status --porcelain=v1)
Assert-True ($worktreeRows.Count -eq 0) 'R6V2 publication requires a clean worktree.'
$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R6V2 U: PowerShell mapping changed.'
Assert-True ([int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R6V2 persistent U: mapping changed.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Select-Object -First 2)
Assert-True ($pending.Count -eq 0) ('R6V2 another request is pending: ' + (($pending | ForEach-Object Name) -join ','))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R6V2 create-new target exists: $path" }
foreach ($path in @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath)) { Assert-True (($path.Length + 32) -lt 200) "R6V2 unsafe publication path: $path" }

$preflightResult = [ordered]@{schema='argos_r6v2_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V2_PUBLISH_PREFLIGHT';requestId=$requestId;sourceZipSha256=$expectedZipSha;sourceZipBytes=$expectedZipBytes;finalGateSha256=$expectedFinalGateSha;completePathRouteGateSha256=$expectedPathGateSha;currentRouteShareGateSha256=$expectedRouteGateSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;worktreeRowCount=$worktreeRows.Count;pendingShareRequestCount=0;unresolvedEarlierAcceptedRequestCount=0;persistentUMapping=$true;targetAndUploadAbsent=$true;mutationsPerformed=$false;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseOnly=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 8; return }

$uploadCreated = $false
try {
    [IO.File]::Copy($sourceZip, $uploadPath, $false)
    $uploadCreated = $true
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha) 'R6V2 upload hash changed.'
    [IO.File]::Move($uploadPath, $readyPath)
    $uploadCreated = $false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha) 'R6V2 ready request hash changed.'
    $result = [ordered]@{schema='argos_r6v2_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V2_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;sourceZip=$sourceZip;publishedPath=$readyPath;bytes=$expectedZipBytes;sha256=$expectedZipSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseOnly=$true;targetExecuted=$false;providerActivated=$false;identityEligible=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
    Write-GateNew $publishGatePath $result
    $result | ConvertTo-Json -Depth 8
}
catch {
    if ($uploadCreated -and (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath)) { Remove-Item -LiteralPath $uploadPath -Force }
    throw
}
