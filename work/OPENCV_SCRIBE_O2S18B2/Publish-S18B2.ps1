
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260826T211126103Z_8028A37AF6FF'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'S18B2_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'S18B2_COMPLETE_ROUTE_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_S18B2_PUBLISH.json'
$intentPath = Join-Path $PSScriptRoot 'S18B2_RECOVERY_INTENT.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV02_O2D12_SIGNED_SLOT17_FROZEN_SLOT18_NEXT_CHECKPOINT_20260826.md'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$intentTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'S18B2_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$expectedZipSha256 = '3D9E401EA3061ECAD5FFAD74ACEBA078B088C52F999DE6C7620BE43E9B2F722C'
$expectedZipBytes = 1214
$expectedPackageGateSha256 = '592FC817DB4E0836611E64EBF53A363E66F54B42D052E189506BD010A6D8652E'
$expectedRouteGateSha256 = '5B0036A9D9ADBEC4CE35414C3A4216B61EDAD1D72E43BD4F84E0DEAD4EC326FE'
$expectedPreactionSha256 = 'B68039A719D8B5549E2C94FE0192C3C1EA6F14A1CCC6430884D49D1B7F7305A9'
$expectedIntentSha256 = 'D72F67CB22494366ED65A0CD11BEF31C6FD90CA4EA433680962773D78AECA596'
$expectedCheckpointSha256 = '1572D141FDAAE39530C457E1DEC4B56753AAD21DD039D3A7D4035817F0709ACA'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Normalize-Root([string]$Path) { return $Path.Replace('/','\').TrimEnd('\') }
function Get-Sha256([string]$Path) {
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$sha.Dispose()}}finally{$stream.Dispose()}
}
function Assert-Pin([string]$Path,[string]$Sha256) { Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "S18B2 publication dependency is absent: $Path"; Assert-True ((Get-Sha256 $Path) -eq $Sha256) "S18B2 publication dependency changed: $Path" }
function Write-JsonCreateNew([string]$Path,[object]$Value) {
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 16)+[Environment]::NewLine));$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}

Assert-Pin $sourceZip $expectedZipSha256
Assert-Pin $packageGatePath $expectedPackageGateSha256
Assert-Pin $routeGatePath $expectedRouteGateSha256
Assert-Pin $preactionPath $expectedPreactionSha256
Assert-Pin $intentPath $expectedIntentSha256
Assert-Pin $checkpointPath $expectedCheckpointSha256
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'S18B2 request ZIP byte count changed.'
& $intentTool -IntentPath $intentPath -ProjectRoot $project -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
$packageGate=Get-Content -Raw -LiteralPath $packageGatePath|ConvertFrom-Json
$routeGate=Get-Content -Raw -LiteralPath $routeGatePath|ConvertFrom-Json
$continuity=Get-Content -Raw -LiteralPath (Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json')|ConvertFrom-Json
Assert-True ([string]$packageGate.state -eq 'PASS_S18B2_FINAL_PACKAGE_GATE' -and [string]$packageGate.requestZipSha256 -eq $expectedZipSha256 -and [bool]$packageGate.exactFinalZipSignaturePassed) 'S18B2 package gate changed.'
Assert-True ([string]$routeGate.state -eq 'PASS_S18B2_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId -and [bool]$routeGate.publicationAuthorized -and [int]$routeGate.maximumRequestsAuthorized -eq 1 -and -not [bool]$routeGate.retryOnFailure) 'S18B2 route gate changed.'
Assert-True ([int]$routeGate.unresolvedEarlierAcceptedRequestCount -eq 0 -and [int]$routeGate.imageBytesRequested -eq 2 -and -not [bool]$routeGate.pixelsDecoded -and -not [bool]$routeGate.slots22Through25Exposed) 'S18B2 route scope changed.'
Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2D12_SIGNED_SLOT17_FROZEN_SLOT18_NEXT' -and -not [bool]$continuity.productionEligible) 'S18B2 continuity authority changed.'
$currentBranch=(& git -C $project branch --show-current|Out-String).Trim();$localTip=(& git -C $project rev-parse HEAD|Out-String).Trim();$remoteTip=(& git -C $project rev-parse ('origin/'+$branch)|Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'S18B2 publication requires matching local/origin tips.'

$psDrive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'S18B2 U: PowerShell mapping changed.'
$logicalDisk=Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logicalDisk -and [int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'S18B2 persistent U: operating-system mapping changed.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'S18B2 request root is unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop|Where-Object{$_.Name -match '\.ready\.zip(\.upload)?$'}|Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('S18B2 another portal request is pending: '+(($pending|ForEach-Object{$_.Name})-join', '))
foreach($path in @($uploadPath,$readyPath,$processedPath,$publishGatePath)){Assert-True (-not(Test-Path -LiteralPath $path)) "S18B2 create-new publication target exists: $path"}
$pathGate=& $pathTool -CandidatePath @($sourceZip,$uploadPath,$readyPath,$processedPath,$publishGatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'S18B2 publication path budget failed.'

if($Preflight){[ordered]@{schema='argos_s18b2_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S18B2_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha256;requestZipBytes=$expectedZipBytes;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;pendingRequests=0;unresolvedEarlierAcceptedRequests=0;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingRemovalAuthorized=$false;targetAndUploadAbsent=$true;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

$uploadCreated=$false
try{
    [IO.File]::Copy($sourceZip,$uploadPath,$false);$uploadCreated=$true
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256) 'S18B2 upload changed.'
    [IO.File]::Move($uploadPath,$readyPath);$uploadCreated=$false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha256) 'S18B2 ready request changed.'
    $result=[ordered]@{schema='argos_s18b2_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S18B2_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$expectedZipBytes;sha256=$expectedZipSha256;packageGateSha256=$expectedPackageGateSha256;routeGateSha256=$expectedRouteGateSha256;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;imageBytesRequested=2;pixelsDecoded=$false;taskActions=@();processActions=@();sourceMutationPerformed=$false;waferActionPerformed=$false;providerActivated=$false;slots22Through25Exposed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-JsonCreateNew -Path $publishGatePath -Value $result
    $result|ConvertTo-Json -Depth 12
}
catch{
    if($uploadCreated -and -not(Test-Path -LiteralPath $readyPath) -and (Test-Path -LiteralPath $uploadPath -PathType Leaf) -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256){[IO.File]::Delete($uploadPath)}
    throw
}


