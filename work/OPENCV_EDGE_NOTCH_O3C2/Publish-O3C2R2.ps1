#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,[switch]$Preflight,[switch]$Publish)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){$s=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}}
function Assert-Pin([string]$Path,[string]$Sha){Assert-True(Test-Path -LiteralPath $Path -PathType Leaf)"O3C2 R2 publisher dependency absent: $Path";Assert-True((Get-Sha256 $Path)-eq$Sha)"O3C2 R2 publisher dependency changed: $Path"}
function Normalize-Root([string]$Path){return $Path.Replace('/','\').TrimEnd('\')}
function Write-NewJson([string]$Path,[object]$Value){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine));$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_20260827T151200111Z_62629419C3F2'
$branch='codex/fiducial-opencv-d-drive'
$sourceZip=Join-Path $PSScriptRoot ('final_o3c2\'+$requestId+'.ready.zip')
$finalGatePath=Join-Path $PSScriptRoot 'O3C2_FINAL_PACKAGE_GATE.json'
$rehearsalGatePath=Join-Path $PSScriptRoot 'O3C2_EXACT_PACKAGE_REHEARSAL_GATE.json'
$routeGatePath=Join-Path $PSScriptRoot 'O3C2_COMPLETE_ROUTE_GATE.json'
$aliasGatePath=Join-Path $PSScriptRoot 'O3C2_INSPECTIONREVS_U_ALIAS_GATE.json'
$r1WithdrawalPath=Join-Path $PSScriptRoot 'O3C2_PUBLISHER_R1_WITHDRAWAL.json'
$continuityPath=Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$checkpointPath=Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3C2_SOURCE_FREEZE_PUBLISH_READY_R2_20260827.md'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath=Join-Path $PSScriptRoot 'O3C2_PUBLISH_R2_GATE.json'
$shareRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot='U:\ProjectPortalRO\requests'
$readyPath=Join-Path $requestRoot ($requestId+'.ready.zip')
$uploadPath=$readyPath+'.upload'
$processedPath=Join-Path (Join-Path $requestRoot 'processed') ($requestId+'.ready.zip')
$zipSha='14C2408B3644CFC30D09CD0DAB175196EFF5F7254BB792DD1A68DEDAC4781402'
$zipBytes=11847
$finalGateSha='A3532F4D9604C73FC094D9706E9BA74FE905A5547B3786320EAAFB14D0B2257E'
$rehearsalGateSha='10BDA7E7B359E596F7F2E9983470DAB575439AA646ACE905050C4C6EC502D9DF'
$routeGateSha='2BCD47C9F3F06C7941416CE8F453242E52D1E809B6FA2985F56AB553C8CD1033'
$aliasGateSha='0D0C574F910F3BC88647DEC3B0519F3E19AF44C24B2BDD7BFF001C29265E96C4'
$r1WithdrawalSha='30AC361BCEC5D0843A6243E56791071AA387D85E2DEAC738B80BB97ABC56A2CB'
$checkpointSha='6E2C67499D2716FFE5D3CBABE22C2DB83B7ADE317BF2ADB12CB36F15F51EFD2B'
$invocationSha='6F1FCE13DCB87DE91B3E4DB3832410868108DC03ECEF2507CFBE3D32B7B51223'

$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
Assert-Pin $invocationPath $invocationSha
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True([string]$invocation.schema-eq'argos_o3c2_publish_r2_invocation_v1'-and[string]$invocation.publisherRevision-eq'Publish-O3C2R2'-and[string]$invocation.requestId-eq$requestId)'O3C2 R2 publisher invocation identity changed.'
Assert-True([string]$invocation.requestZipSha256-eq$zipSha-and[string]$invocation.checkpointSha256-eq$checkpointSha-and[string]$invocation.publisherR1WithdrawalSha256-eq$r1WithdrawalSha-and[string]$invocation.branch-eq$branch)'O3C2 R2 publisher invocation pins changed.'
Assert-True([int]$invocation.maximumPublications-eq1-and-not[bool]$invocation.retryAuthorized-and[bool]$invocation.matchingSignedResponseCollectionOnly-and[bool]$invocation.requireCleanMatchingBranchTips-and[bool]$invocation.requireZeroPendingShareRequests)'O3C2 R2 publisher one-shot boundary changed.'
Assert-True([bool]$invocation.reviewOnly-and-not[bool]$invocation.trainingEligible-and-not[bool]$invocation.xmlEligible-and-not[bool]$invocation.productionRoutingEnabled-and-not[bool]$invocation.sourceHashingPerformed-and-not[bool]$invocation.imageBytesDecoded-and-not[bool]$invocation.pixelProcessingPerformed-and-not[bool]$invocation.knownNotchLocationConsumed-and-not[bool]$invocation.notchAnglePriorConsumed-and-not[bool]$invocation.fixedAngularSearchWindowConsumed-and-not[bool]$invocation.providerActivated)'O3C2 R2 publisher authority widened.'
foreach($pin in @(@($sourceZip,$zipSha),@($finalGatePath,$finalGateSha),@($rehearsalGatePath,$rehearsalGateSha),@($routeGatePath,$routeGateSha),@($aliasGatePath,$aliasGateSha),@($r1WithdrawalPath,$r1WithdrawalSha),@($checkpointPath,$checkpointSha))){Assert-Pin $pin[0] $pin[1]}
Assert-True((Get-Item -LiteralPath $sourceZip).Length-eq$zipBytes)'O3C2 R2 ZIP byte count changed.'
$finalGate=Get-Content -LiteralPath $finalGatePath -Raw|ConvertFrom-Json
$rehearsalGate=Get-Content -LiteralPath $rehearsalGatePath -Raw|ConvertFrom-Json
$routeGate=Get-Content -LiteralPath $routeGatePath -Raw|ConvertFrom-Json
$aliasGate=Get-Content -LiteralPath $aliasGatePath -Raw|ConvertFrom-Json
$r1Withdrawal=Get-Content -LiteralPath $r1WithdrawalPath -Raw|ConvertFrom-Json
$continuity=Get-Content -LiteralPath $continuityPath -Raw|ConvertFrom-Json
Assert-True([string]$r1Withdrawal.state-eq'WITHDRAWN'-and-not[bool]$r1Withdrawal.publicationAttempted-and-not[bool]$r1Withdrawal.futureReuseAllowed-and[bool]$r1Withdrawal.signedRequestUnchanged)'O3C2 R1 publisher withdrawal changed.'
Assert-True([string]$finalGate.state-eq'PASS_O3C2_FINAL_PACKAGE_GATE'-and[string]$finalGate.requestId-eq$requestId-and[string]$finalGate.requestZipSha256-eq$zipSha-and[bool]$finalGate.maintenanceInstalledShaMatchesPayload-and-not[bool]$finalGate.knownNotchLocationConsumed-and-not[bool]$finalGate.notchAnglePriorConsumed-and-not[bool]$finalGate.fixedAngularSearchWindowConsumed)'O3C2 R2 final package gate changed.'
Assert-True([string]$rehearsalGate.state-eq'PASS_O3C2_EXACT_PACKAGE_REHEARSAL'-and[string]$rehearsalGate.requestZipSha256-eq$zipSha-and[bool]$rehearsalGate.createCasePassed-and[bool]$rehearsalGate.targetHashIdempotentCasePassed-and[bool]$rehearsalGate.unapprovedPredecessorRefusedBeforeMutation-and[bool]$rehearsalGate.exactPackagedEntrypointSuccessPassed-and[bool]$rehearsalGate.postFailureOutputAbsent-and[bool]$rehearsalGate.postFailureAliasAbsent-and-not[bool]$rehearsalGate.knownNotchLocationConsumed-and-not[bool]$rehearsalGate.notchAnglePriorConsumed-and-not[bool]$rehearsalGate.fixedAngularSearchWindowConsumed)'O3C2 R2 exact-package rehearsal changed.'
Assert-True([string]$routeGate.state-eq'PASS_O3C2_COMPLETE_ROUTE_GATE'-and[string]$routeGate.requestId-eq$requestId-and[string]$routeGate.requestZipSha256-eq$zipSha-and[bool]$routeGate.exactFinalZipExtractionPassed-and[bool]$routeGate.exactFinalZipSignaturePassed-and-not[bool]$routeGate.knownNotchLocationConsumed-and-not[bool]$routeGate.notchAnglePriorConsumed-and-not[bool]$routeGate.fixedAngularSearchWindowConsumed)'O3C2 R2 complete route gate changed.'
Assert-True([string]$aliasGate.state-eq'PASS_O3C2_EXACT_INSPECTIONREVS_U_ALIAS_GATE'-and[bool]$aliasGate.persistentMappingVerified-and[bool]$aliasGate.targetAbsentAtGate-and[bool]$aliasGate.uploadAbsentAtGate)'O3C2 R2 persistent-U alias gate changed.'
Assert-True([string]$continuity.activePhase-eq'OCV03_O3C2_SOURCE_FREEZE_PUBLISH_READY_R2'-and[string]$continuity.currentPhaseCheckpointSha256-eq$checkpointSha)'O3C2 R2 continuity phase changed.'
$cap=$continuity.ocv03O3C2SourceFreeze
Assert-True([string]$cap.requestId-eq$requestId-and[string]$cap.requestZipSha256-eq$zipSha-and[bool]$cap.publisherR1Withdrawn-and[bool]$cap.publisherR1PreflightFailedBeforeMutation-and[bool]$cap.publicationAuthorized-and[int]$cap.maximumPublications-eq1-and-not[bool]$cap.retryAuthorized-and-not[bool]$cap.published-and-not[bool]$cap.knownNotchLocationConsumed-and-not[bool]$cap.notchAnglePriorConsumed-and-not[bool]$cap.fixedAngularSearchWindowConsumed-and[bool]$cap.fullPerimeterInferenceRequiredForDetector-and[bool]$cap.knownLocationAllowedOnlyForPostInferenceRegressionScoring)'O3C2 R2 continuity publication or algorithm-integrity state changed.'
Assert-True([bool]$continuity.reviewOnly-and-not[bool]$continuity.trainingEligible-and-not[bool]$continuity.xmlEligible-and-not[bool]$continuity.productionEligible)'O3C2 R2 continuity authority widened.'

$currentBranch=(& git -C $project branch --show-current|Out-String).Trim()
$localTip=(& git -C $project rev-parse HEAD|Out-String).Trim()
$remoteTip=(& git -C $project rev-parse ('origin/'+$branch)|Out-String).Trim()
Assert-True($currentBranch-eq$branch-and$localTip-eq$remoteTip)'O3C2 R2 publisher requires matching local/origin branch tips.'
$worktree=@(& git -C $project status --porcelain=v1)
Assert-True($worktree.Count-eq0)'O3C2 R2 publisher requires a clean worktree.'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logical=Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True($null-ne$logical-and[int]$logical.DriveType-eq4-and(Normalize-Root([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)-and(Normalize-Root([string]$logical.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase))'O3C2 R2 persistent U: mapping changed.'
Assert-True(Test-Path -LiteralPath $requestRoot -PathType Container)'O3C2 R2 request share unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -Force|Where-Object{$_.Name-match'\.ready\.zip(\.upload)?$'}|Select-Object -First 21)
Assert-True($pending.Count-eq0)('O3C2 R2 another request is pending: '+(($pending|ForEach-Object{$_.Name})-join', '))
foreach($p in @($uploadPath,$readyPath,$processedPath,$publishGatePath)){Assert-True(-not(Test-Path -LiteralPath $p))"O3C2 R2 create-new publication target exists: $p"}
$pathGate=& $pathTool -CandidatePath @($sourceZip,$uploadPath,$readyPath,$processedPath,$publishGatePath,$invocationPath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True([string]$pathGate.state-eq'PASS_PATH_BUDGET')'O3C2 R2 publication path gate failed.'
$pre=[ordered]@{schema='argos_o3c2_publish_r2_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_PUBLISH_R2_PREFLIGHT';requestId=$requestId;sourceZipSha256=$zipSha;sourceZipBytes=$zipBytes;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;tipsMatch=$true;worktreeRowCount=0;pendingRequestCount=0;persistentUMappingVerified=$true;targetAbsent=$true;uploadAbsent=$true;r1PublisherWithdrawn=$true;maximumPublications=1;retryAuthorized=$false;matchingSignedResponseCollectionOnly=$true;mutationsPerformed=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$pre|ConvertTo-Json -Depth 8;return}
[IO.File]::Copy($sourceZip,$uploadPath,$false)
Assert-True((Get-Item -LiteralPath $uploadPath).Length-eq$zipBytes-and(Get-Sha256 $uploadPath)-eq$zipSha)'O3C2 R2 upload copy changed.'
[IO.File]::Move($uploadPath,$readyPath)
Assert-True((Get-Item -LiteralPath $readyPath).Length-eq$zipBytes-and(Get-Sha256 $readyPath)-eq$zipSha)'O3C2 R2 published ZIP changed.'
$record=[ordered]@{schema='argos_o3c2_publish_r2_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_R2_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;sourceZip=$sourceZip;publishedPath=$readyPath;bytes=$zipBytes;sha256=$zipSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;tipsMatch=$true;r1PublisherWithdrawn=$true;createNew=$true;overwritePerformed=$false;persistentUMappingVerified=$true;persistentUMappingLeftInPlace=$true;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;gatewayAcceptanceIsExecutionEvidence=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;healthyProcessorTouched=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $publishGatePath $record
$record|ConvertTo-Json -Depth 10
