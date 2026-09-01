#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Publish) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260901T160000111Z_7F77B8EFE092'
$branch = 'codex/opencv-scribe-deciphering'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$sourceZip = Join-Path $project ('work\OPENCV_SCRIBE_R6V1\final\' + $requestId + '.ready.zip')
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')
$finalGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R6V1\R6V1_FINAL_PACKAGE_GATE.json'
$pathGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R6V1\R6V1_PATH_ROUTE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R6V1_CURRENT_ROUTE_SHARE_GATE.json'
$publishGatePath = Join-Path $PSScriptRoot 'R6V1_PUBLISH_GATE.json'
$expectedZipSha = 'E4F62D6126F9FBEDD228CDDE8678136D7FDEFCF5CB2B3825BF1245E11BBF925D'
$expectedZipBytes = 28279L
$expectedFinalGateSha = '04E8330DAF95AE6274626F50284B1312118402BD5565F44EEDBD56F940D9BFB4'
$expectedPathGateSha = 'C34C5163AE3DA95BF58179B2CCCBAF61D79C4A24ADC4167118C3376FFB93F9A0'
$expectedRouteGateSha = '9B80A94D052B8454372CEABEC90B7113C883F1638314A69AABD81EB5FF373A15'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { $sha = [Security.Cryptography.SHA256]::Create(); try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $sha.Dispose() } }
    finally { $stream.Dispose() }
}
function Assert-Pin([string]$Path, [string]$Expected) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R6V1 publication dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Expected) "R6V1 publication dependency changed: $Path"
}
function Normalize-Root([string]$Path) { return $Path.Replace('/', '\').TrimEnd('\') }
function Write-JsonNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-Pin $sourceZip $expectedZipSha
Assert-Pin $finalGatePath $expectedFinalGateSha
Assert-Pin $pathGatePath $expectedPathGateSha
Assert-Pin $routeGatePath $expectedRouteGateSha
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'R6V1 frozen ZIP byte count changed.'
$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
$pathGate = Get-Content -Raw -LiteralPath $pathGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_R6V1_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $expectedZipSha) 'R6V1 final package identity changed.'
Assert-True ([bool]$finalGate.exactFinalZipExtractionPassed -and [bool]$finalGate.exactFinalZipSignaturePassed -and -not [bool]$finalGate.publicationAuthorized) 'R6V1 frozen package contract changed.'
Assert-True ([string]$pathGate.state -eq 'PASS_R6V1_PATH_ROUTE_GATE' -and [int]$pathGate.maximumEffectiveLength -lt 200) 'R6V1 complete path route gate changed.'
Assert-True ([string]$routeGate.state -eq 'PASS_R6V1_CURRENT_ROUTE_SHARE_AND_QUEUE_GATE' -and [string]$routeGate.requestId -eq $requestId) 'R6V1 current route gate changed.'
Assert-True ([bool]$routeGate.publication.authorized -and [int]$routeGate.publication.maximumPublications -eq 1 -and -not [bool]$routeGate.publication.retryAuthorized -and [bool]$routeGate.publication.matchingSignedTerminalResponseOnly) 'R6V1 publication boundary changed.'
Assert-True ([int]$routeGate.queueObservation.pendingRequestFileCount -eq 0 -and [int]$routeGate.queueObservation.unresolvedEarlierAcceptedRequestCount -eq 0 -and [int]$routeGate.queueObservation.exactRequestIdProcessedMatchCount -eq 0 -and [int]$routeGate.queueObservation.exactRequestIdResponseMatchCount -eq 0) 'R6V1 queue route is not clear.'
Assert-True ([bool]$routeGate.reviewOnly -and -not [bool]$routeGate.automaticIdentityAuthority -and -not [bool]$routeGate.mayClearHolds -and -not [bool]$routeGate.xmlEligible -and -not [bool]$routeGate.productionEligible) 'R6V1 route authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'R6V1 publication requires matching local/origin branch tips.'
$worktreeRows = @(& git -C $project status --porcelain=v1)
Assert-True ($worktreeRows.Count -eq 0) 'R6V1 publication requires a clean worktree.'
$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R6V1 U: PowerShell mapping changed.'
Assert-True ([int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R6V1 persistent U: mapping changed.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Select-Object -First 2)
Assert-True ($pending.Count -eq 0) ('R6V1 another request is pending: ' + (($pending | ForEach-Object Name) -join ','))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R6V1 create-new target exists: $path" }
foreach ($path in @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath)) { Assert-True (($path.Length + 32) -lt 200) "R6V1 unsafe publication path: $path" }

$preflightEvidence = [ordered]@{schema='argos_r6v1_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V1_PUBLISH_PREFLIGHT';requestId=$requestId;sourceZipSha256=$expectedZipSha;sourceZipBytes=$expectedZipBytes;finalGateSha256=$expectedFinalGateSha;completePathRouteGateSha256=$expectedPathGateSha;currentRouteShareGateSha256=$expectedRouteGateSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;worktreeRowCount=$worktreeRows.Count;pendingShareRequestCount=0;unresolvedEarlierAcceptedRequestCount=0;persistentUMapping=$true;targetAndUploadAbsent=$true;mutationsPerformed=$false;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseOnly=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
if ($Preflight) { $preflightEvidence | ConvertTo-Json -Depth 8; return }

$uploadCreated = $false
try {
    [IO.File]::Copy($sourceZip, $uploadPath, $false)
    $uploadCreated = $true
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha) 'R6V1 upload hash changed.'
    [IO.File]::Move($uploadPath, $readyPath)
    $uploadCreated = $false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha) 'R6V1 ready request hash changed.'
    $result = [ordered]@{schema='argos_r6v1_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V1_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;sourceZip=$sourceZip;publishedPath=$readyPath;bytes=$expectedZipBytes;sha256=$expectedZipSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseOnly=$true;targetExecuted=$false;providerActivated=$false;identityEligible=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
    Write-JsonNew $publishGatePath $result
    $result | ConvertTo-Json -Depth 8
}
catch {
    if ($uploadCreated -and (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath)) { Remove-Item -LiteralPath $uploadPath -Force }
    throw
}
