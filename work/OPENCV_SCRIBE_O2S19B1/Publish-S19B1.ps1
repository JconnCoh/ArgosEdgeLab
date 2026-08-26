#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260826T215420761Z_425F35B315C7'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'S19B1_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'S19B1_COMPLETE_ROUTE_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_S19B1_PUBLISH.json'
$intentPath = Join-Path $PSScriptRoot 'S19B1_RECOVERY_INTENT.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV02_O2D13_SIGNED_SLOT18_FROZEN_SLOT19_NEXT_CHECKPOINT_20260826.md'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$intentTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'S19B1_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$expectedZipSha256 = '2E20CE8F9EB1A7A5BF4F26CF0469AD753E85FC0DDE6641065AF44F2DEFF1A049'
$expectedZipBytes = 1232
$expectedPackageGateSha256 = 'CDA243A7C1EB08E76842F27AC16F99B96402B683B863F54EB8C0CDC73D81691F'
$expectedRouteGateSha256 = 'DDC01CE068DE675BDB2463EF9A25AA0C63A63025D32F7D45726B44A6AF4DAE11'
$expectedPreactionSha256 = '88D38E591B00D2064DC5F36B7591E2B947BBEA6DD49006876414105364D2D654'
$expectedIntentSha256 = 'FC8C5DF56C2E370D80A55992DC45C1325E6DA2F5E07B40FEA92A4BE5D8B35DD4'
$expectedCheckpointSha256 = '1009F3149E1826F88200369BF716BB0E975C41CC0954A2B43526368715A047FF'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Normalize-Root([string]$Path) { return $Path.Replace('/','\').TrimEnd('\') }
function Get-Sha256([string]$Path) {
    $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$sha.Dispose()}}finally{$stream.Dispose()}
}
function Assert-Pin([string]$Path,[string]$Sha256) { Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "S19B1 publication dependency is absent: $Path"; Assert-True ((Get-Sha256 $Path) -eq $Sha256) "S19B1 publication dependency changed: $Path" }
function Write-JsonCreateNew([string]$Path,[object]$Value) {
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 16)+[Environment]::NewLine));$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}

Assert-Pin $sourceZip $expectedZipSha256
Assert-Pin $packageGatePath $expectedPackageGateSha256
Assert-Pin $routeGatePath $expectedRouteGateSha256
Assert-Pin $preactionPath $expectedPreactionSha256
Assert-Pin $intentPath $expectedIntentSha256
Assert-Pin $checkpointPath $expectedCheckpointSha256
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'S19B1 request ZIP byte count changed.'
& $intentTool -IntentPath $intentPath -ProjectRoot $project -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
$packageGate=Get-Content -Raw -LiteralPath $packageGatePath|ConvertFrom-Json
$routeGate=Get-Content -Raw -LiteralPath $routeGatePath|ConvertFrom-Json
$continuity=Get-Content -Raw -LiteralPath (Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json')|ConvertFrom-Json
Assert-True ([string]$packageGate.state -eq 'PASS_S19B1_FINAL_PACKAGE_GATE' -and [string]$packageGate.requestZipSha256 -eq $expectedZipSha256 -and [bool]$packageGate.exactFinalZipSignaturePassed) 'S19B1 package gate changed.'
Assert-True ([string]$routeGate.state -eq 'PASS_S19B1_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId -and [bool]$routeGate.publicationAuthorized -and [int]$routeGate.maximumRequestsAuthorized -eq 1 -and -not [bool]$routeGate.retryOnFailure) 'S19B1 route gate changed.'
Assert-True ([int]$routeGate.unresolvedEarlierAcceptedRequestCount -eq 0 -and [int]$routeGate.imageBytesRequested -eq 0 -and -not [bool]$routeGate.slots22Through25Exposed) 'S19B1 route scope changed.'
Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2D13_SIGNED_SLOT18_FROZEN_SLOT19_NEXT' -and -not [bool]$continuity.productionEligible) 'S19B1 continuity authority changed.'
$currentBranch=(& git -C $project branch --show-current|Out-String).Trim();$localTip=(& git -C $project rev-parse HEAD|Out-String).Trim();$remoteTip=(& git -C $project rev-parse ('origin/'+$branch)|Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'S19B1 publication requires matching local/origin tips.'

$psDrive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'S19B1 U: PowerShell mapping changed.'
$logicalDisk=Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logicalDisk -and [int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'S19B1 persistent U: operating-system mapping changed.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'S19B1 request root is unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop|Where-Object{$_.Name -match '\.ready\.zip(\.upload)?$'}|Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('S19B1 another portal request is pending: '+(($pending|ForEach-Object{$_.Name})-join', '))
foreach($path in @($uploadPath,$readyPath,$processedPath,$publishGatePath)){Assert-True (-not(Test-Path -LiteralPath $path)) "S19B1 create-new publication target exists: $path"}
$pathGate=& $pathTool -CandidatePath @($sourceZip,$uploadPath,$readyPath,$processedPath,$publishGatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'S19B1 publication path budget failed.'

if($Preflight){[ordered]@{schema='argos_s19b1_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S19B1_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha256;requestZipBytes=$expectedZipBytes;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;pendingRequests=0;unresolvedEarlierAcceptedRequests=0;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingRemovalAuthorized=$false;targetAndUploadAbsent=$true;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

$uploadCreated=$false
try{
    [IO.File]::Copy($sourceZip,$uploadPath,$false);$uploadCreated=$true
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256) 'S19B1 upload changed.'
    [IO.File]::Move($uploadPath,$readyPath);$uploadCreated=$false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha256) 'S19B1 ready request changed.'
    $result=[ordered]@{schema='argos_s19b1_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S19B1_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$expectedZipBytes;sha256=$expectedZipSha256;packageGateSha256=$expectedPackageGateSha256;routeGateSha256=$expectedRouteGateSha256;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;imageBytesRequested=0;taskActions=@();processActions=@();sourceMutationPerformed=$false;waferActionPerformed=$false;providerActivated=$false;slots22Through25Exposed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-JsonCreateNew -Path $publishGatePath -Value $result
    $result|ConvertTo-Json -Depth 12
}
catch{
    if($uploadCreated -and -not(Test-Path -LiteralPath $readyPath) -and (Test-Path -LiteralPath $uploadPath -PathType Leaf) -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256){[IO.File]::Delete($uploadPath)}
    throw
}
