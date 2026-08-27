#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,[switch]$Preflight,[switch]$Publish)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){$s=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}}
function Assert-Pin([string]$Path,[string]$Sha){Assert-True(Test-Path -LiteralPath $Path -PathType Leaf)"O3C1 publisher dependency absent: $Path";Assert-True((Get-Sha256 $Path)-eq$Sha)"O3C1 publisher dependency changed: $Path"}
function Normalize-Root([string]$Path){return$Path.Replace('/','\').TrimEnd('\')}
function Write-NewJson([string]$Path,[object]$Value){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine));$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_20260827T141000111Z_62629419C3A1'
$branch='codex/fiducial-opencv-d-drive'
$sourceZip=Join-Path $PSScriptRoot ('final_o3c1\'+$requestId+'.ready.zip')
$finalGatePath=Join-Path $PSScriptRoot 'O3C1_FINAL_PACKAGE_GATE.json'
$rehearsalGatePath=Join-Path $PSScriptRoot 'O3C1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$routeGatePath=Join-Path $PSScriptRoot 'O3C1_COMPLETE_ROUTE_GATE.json'
$aliasGatePath=Join-Path $PSScriptRoot 'O3C1_INSPECTIONREVS_U_ALIAS_GATE.json'
$continuityPath=Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$checkpointPath=Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3C1_METADATA_CAPABILITY_PUBLISH_READY_20260827.md'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath=Join-Path $PSScriptRoot 'O3C1_PUBLISH_GATE.json'
$shareRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot='U:\ProjectPortalRO\requests'
$readyPath=Join-Path $requestRoot ($requestId+'.ready.zip')
$uploadPath=$readyPath+'.upload'
$processedPath=Join-Path (Join-Path $requestRoot 'processed') ($requestId+'.ready.zip')
$zipSha='2D191B3FBC9C40D447F3D7EAE0C998946085BE1916275999F32EB92E963F9293'
$zipBytes=10081
$finalGateSha='6B86A5222FF55FCF791D26467D0D93444074563F70F795CB33AE57D1B9B1AB75'
$rehearsalGateSha='36102773F30C915D9173891F904512646659F6A36371C5C4C3946F55B5A404E1'
$routeGateSha='62D72EF54D22D83E0B46C39B4B6646D45A1B6F58CD017C51B89A7FC4ED93ECDD'
$aliasGateSha='4D19F239F277A36C26B859549742723B0F5DDDB1067B7F8FFC7ED0734E59DE76'
$checkpointSha='1A7AE8535F1324296B9693C438983684C1EAB607E17CB6C18B8B6B8A400557B4'
$invocationSha='2885A554BC607271969703158AC47F6D757C20BDC2FD7F5F1711FEAC6A43702E'

$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
Assert-Pin $invocationPath $invocationSha
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True([string]$invocation.schema-eq'argos_o3c1_publish_invocation_v1'-and[string]$invocation.publisherRevision-eq'Publish-O3C1'-and[string]$invocation.requestId-eq$requestId)'O3C1 publisher invocation identity changed.'
Assert-True([string]$invocation.requestZipSha256-eq$zipSha-and[string]$invocation.checkpointSha256-eq$checkpointSha-and[string]$invocation.branch-eq$branch)'O3C1 publisher invocation pins changed.'
Assert-True([int]$invocation.maximumPublications-eq1-and-not[bool]$invocation.retryAuthorized-and[bool]$invocation.matchingSignedResponseCollectionOnly-and[bool]$invocation.requireCleanMatchingBranchTips-and[bool]$invocation.requireZeroPendingShareRequests)'O3C1 publisher one-shot boundary changed.'
Assert-True([bool]$invocation.reviewOnly-and-not[bool]$invocation.trainingEligible-and-not[bool]$invocation.xmlEligible-and-not[bool]$invocation.productionRoutingEnabled-and-not[bool]$invocation.imageBytesRead-and-not[bool]$invocation.sourceHashingPerformed-and-not[bool]$invocation.providerActivated)'O3C1 publisher authority widened.'
foreach($pin in @(@($sourceZip,$zipSha),@($finalGatePath,$finalGateSha),@($rehearsalGatePath,$rehearsalGateSha),@($routeGatePath,$routeGateSha),@($aliasGatePath,$aliasGateSha),@($checkpointPath,$checkpointSha))){Assert-Pin $pin[0] $pin[1]}
Assert-True((Get-Item -LiteralPath $sourceZip).Length-eq$zipBytes)'O3C1 ZIP byte count changed.'
$finalGate=Get-Content -LiteralPath $finalGatePath -Raw|ConvertFrom-Json
$rehearsalGate=Get-Content -LiteralPath $rehearsalGatePath -Raw|ConvertFrom-Json
$routeGate=Get-Content -LiteralPath $routeGatePath -Raw|ConvertFrom-Json
$aliasGate=Get-Content -LiteralPath $aliasGatePath -Raw|ConvertFrom-Json
$continuity=Get-Content -LiteralPath $continuityPath -Raw|ConvertFrom-Json
Assert-True([string]$finalGate.state-eq'PASS_O3C1_FINAL_PACKAGE_GATE'-and[string]$finalGate.requestId-eq$requestId-and[string]$finalGate.requestZipSha256-eq$zipSha-and[bool]$finalGate.maintenanceInstalledShaMatchesPayload)'O3C1 final package gate changed.'
Assert-True([string]$rehearsalGate.state-eq'PASS_O3C1_EXACT_PACKAGE_REHEARSAL'-and[string]$rehearsalGate.requestZipSha256-eq$zipSha-and[bool]$rehearsalGate.createCasePassed-and[bool]$rehearsalGate.targetHashIdempotentCasePassed-and[bool]$rehearsalGate.unapprovedPredecessorRefusedBeforeMutation-and[bool]$rehearsalGate.postProviderFailureOutputAbsent)'O3C1 exact-package rehearsal changed.'
Assert-True([string]$routeGate.state-eq'PASS_O3C1_COMPLETE_ROUTE_GATE'-and[string]$routeGate.requestId-eq$requestId-and[string]$routeGate.requestZipSha256-eq$zipSha-and[bool]$routeGate.exactFinalZipExtractionPassed-and[bool]$routeGate.exactFinalZipSignaturePassed)'O3C1 complete route gate changed.'
Assert-True([string]$aliasGate.state-eq'PASS_O3C1_EXACT_INSPECTIONREVS_U_ALIAS_GATE'-and[bool]$aliasGate.persistentMappingVerified-and[bool]$aliasGate.targetAbsentAtGate-and[bool]$aliasGate.uploadAbsentAtGate)'O3C1 persistent-U alias gate changed.'
Assert-True([string]$continuity.activePhase-eq'OCV03_O3C1_METADATA_CAPABILITY_PUBLISH_READY'-and[string]$continuity.currentPhaseCheckpointSha256-eq$checkpointSha)'O3C1 continuity phase changed.'
$cap=$continuity.ocv03O3C1MetadataCapability
Assert-True([string]$cap.requestId-eq$requestId-and[string]$cap.requestZipSha256-eq$zipSha-and[bool]$cap.publicationAuthorized-and[int]$cap.maximumPublications-eq1-and-not[bool]$cap.retryAuthorized-and-not[bool]$cap.published)'O3C1 continuity publication state changed.'
Assert-True([bool]$continuity.reviewOnly-and-not[bool]$continuity.trainingEligible-and-not[bool]$continuity.xmlEligible-and-not[bool]$continuity.productionEligible)'O3C1 continuity authority widened.'

$currentBranch=(& git -C $project branch --show-current|Out-String).Trim()
$localTip=(& git -C $project rev-parse HEAD|Out-String).Trim()
$remoteTip=(& git -C $project rev-parse ('origin/'+$branch)|Out-String).Trim()
Assert-True($currentBranch-eq$branch-and$localTip-eq$remoteTip)'O3C1 publisher requires matching local/origin branch tips.'
$worktree=@(& git -C $project status --porcelain=v1)
Assert-True($worktree.Count-eq0)'O3C1 publisher requires a clean worktree.'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logical=Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True($null-ne$logical-and[int]$logical.DriveType-eq4-and(Normalize-Root([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)-and(Normalize-Root([string]$logical.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase))'O3C1 persistent U: mapping changed.'
Assert-True(Test-Path -LiteralPath $requestRoot -PathType Container)'O3C1 request share unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -Force|Where-Object{$_.Name-match'\.ready\.zip(\.upload)?$'}|Select-Object -First 21)
Assert-True($pending.Count-eq0)('O3C1 another request is pending: '+(($pending|ForEach-Object{$_.Name})-join', '))
foreach($p in @($uploadPath,$readyPath,$processedPath,$publishGatePath)){Assert-True(-not(Test-Path -LiteralPath $p))"O3C1 create-new publication target exists: $p"}
$pathGate=& $pathTool -CandidatePath @($sourceZip,$uploadPath,$readyPath,$processedPath,$publishGatePath,$invocationPath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True([string]$pathGate.state-eq'PASS_PATH_BUDGET')'O3C1 publication path gate failed.'

$pre=[ordered]@{schema='argos_o3c1_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_PUBLISH_PREFLIGHT';requestId=$requestId;sourceZipSha256=$zipSha;sourceZipBytes=$zipBytes;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;tipsMatch=$true;worktreeRowCount=0;pendingRequestCount=0;persistentUMappingVerified=$true;targetAbsent=$true;uploadAbsent=$true;maximumPublications=1;retryAuthorized=$false;matchingSignedResponseCollectionOnly=$true;mutationsPerformed=$false;imageBytesRead=$false;sourceHashingPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$pre|ConvertTo-Json -Depth 8;return}
[IO.File]::Copy($sourceZip,$uploadPath,$false)
Assert-True((Get-Item -LiteralPath $uploadPath).Length-eq$zipBytes-and(Get-Sha256 $uploadPath)-eq$zipSha)'O3C1 upload copy changed.'
[IO.File]::Move($uploadPath,$readyPath)
Assert-True((Get-Item -LiteralPath $readyPath).Length-eq$zipBytes-and(Get-Sha256 $readyPath)-eq$zipSha)'O3C1 published ZIP changed.'
$record=[ordered]@{schema='argos_o3c1_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;sourceZip=$sourceZip;publishedPath=$readyPath;bytes=$zipBytes;sha256=$zipSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;tipsMatch=$true;createNew=$true;overwritePerformed=$false;persistentUMappingVerified=$true;persistentUMappingLeftInPlace=$true;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;gatewayAcceptanceIsExecutionEvidence=$false;imageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;healthyProcessorTouched=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $publishGatePath $record
$record|ConvertTo-Json -Depth 10
