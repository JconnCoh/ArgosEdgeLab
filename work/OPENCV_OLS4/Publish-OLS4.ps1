[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(@(@($Preflight,$Publish)|Where-Object{[bool]$_}).Count-ne1){throw 'Specify exactly one of -Preflight or -Publish.'}

function Get-ProviderSha([string]$Path){
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        Get-Content -LiteralPath $Path -Encoding Byte -ReadCount 1048576|ForEach-Object{[byte[]]$block=@($_);if($block.Length){[void]$sha.TransformBlock($block,0,$block.Length,$block,0)}}
        [void]$sha.TransformFinalBlock([byte[]]@(),0,0)
        return ([BitConverter]::ToString($sha.Hash)).Replace('-','')
    }finally{$sha.Dispose()}
}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\OPENCV_OLS4'
$requestId='REQ_OLS4'
$source=Join-Path $root 'final_ols4\REQ_OLS4.ready.zip'
$finalGatePath=Join-Path $root 'OLS4_FINAL_PACKAGE_GATE.json'
$routeGatePath=Join-Path $root 'OLS4_COMPLETE_ROUTE_GATE.json'
$intentPath=Join-Path $root 'OLS4_LIVE_RECOVERY_INTENT_R3.json'
$publishGatePath=Join-Path $root 'OLS4_PUBLISH_GATE.json'
$continuityPath=Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$shareRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$expectedZipSha='F425A2C58ECB183B3590921BF98BE6E8485F135DA30E1FE9A0A89B9C16CE4090'
$expectedFinalGateSha='432A85DBA7F85998F0FDD6895644E0E15A87E7F7938AA05365A3C14E1DBC7954'
$expectedRouteGateSha='A0BECC1A59665E6BF936C0E76B56910DD3DBF3AFC9E9674EC825368F3069C7EE'
$expectedIntentSha='EE16211508D933610A8E2F60DAEFC80B616709A3BC41A359E880FA5F35BF4E6B'
foreach($pin in @(@($source,$expectedZipSha),@($finalGatePath,$expectedFinalGateSha),@($routeGatePath,$expectedRouteGateSha),@($intentPath,$expectedIntentSha))){if(-not(Test-Path -LiteralPath $pin[0] -PathType Leaf)-or(Get-ProviderSha $pin[0])-ne$pin[1]){throw "OLS4 publish input changed: $($pin[0])"}}
if(Test-Path -LiteralPath $publishGatePath){throw 'OLS4 publish gate already exists.'}
$expectedBytes=[int64](Get-Item -LiteralPath $source).Length
$finalGate=Get-Content -LiteralPath $finalGatePath -Raw|ConvertFrom-Json
$routeGate=Get-Content -LiteralPath $routeGatePath -Raw|ConvertFrom-Json
$intent=Get-Content -LiteralPath $intentPath -Raw|ConvertFrom-Json
if([string]$finalGate.state-ne'PASS_OLS4_FINAL_PACKAGE_GATE'-or[string]$finalGate.requestId-ne$requestId-or[string]$finalGate.requestZipSha256-ne$expectedZipSha-or[int64]$finalGate.requestZipBytes-ne$expectedBytes-or-not[bool]$finalGate.publicationRequiresCompleteRouteGate-or[bool]$finalGate.publicationAuthorized){throw 'OLS4 final package gate changed.'}
if([string]$routeGate.state-ne'PASS_OLS4_COMPLETE_ROUTE_GATE'-or[string]$routeGate.requestId-ne$requestId-or[string]$routeGate.requestZipSha256-ne$expectedZipSha-or-not[bool]$routeGate.exactFinalZipExtractionPassed-or-not[bool]$routeGate.exactFinalZipSignaturePassed){throw 'OLS4 complete route gate changed.'}
if([string]$finalGate.requestManifestSha256-ne[string]$routeGate.requestManifestSha256-or[string]$finalGate.requestSignatureSha256-ne[string]$routeGate.requestSignatureSha256){throw 'OLS4 package and route gates do not describe the same request.'}
if([string]$intent.artifactLifecycle-ne'FROZEN'-or-not[bool]$intent.authorizationBoundary.livePublicationAuthorized-or[int]$intent.authorizationBoundary.liveEndpointRequestsMaximum-ne1){throw 'OLS4 live authorization boundary changed.'}
$continuity=Get-Content -LiteralPath $continuityPath -Raw|ConvertFrom-Json
if([string]$continuity.activePhase-ne'OCV00_OLS4_DEEPEST_ALIAS_LOCAL_PROOF_LIVE_INVENTORY_GATE_PENDING'-or[bool]$continuity.productionEligible-or[bool]$continuity.xmlEligible-or[bool]$continuity.trainingEligible){throw 'OLS4 continuity authority changed.'}
$branch=(& git -C $project branch --show-current|Out-String).Trim()
$local=(& git -C $project rev-parse HEAD|Out-String).Trim()
$remoteLine=(& git -C $project ls-remote --heads origin ('refs/heads/'+$branch)|Out-String).Trim()
$remote=if([string]::IsNullOrWhiteSpace($remoteLine)){''}else{($remoteLine-split'\s+')[0]}
if($branch-ne'codex/fiducial-opencv-d-drive'-or$local-ne'ecbda3205852550d7f9fdb4a4daf99b4a001e7da'-or$remote-ne$local){throw 'OLS4 local/GitHub branch authority mismatch.'}

$requestRoot='U:\ProjectPortalRO\requests'
$uncRequestRoot=$shareRoot.TrimEnd('\')+'\ProjectPortalRO\requests'
if(-not(Test-Path -LiteralPath $uncRequestRoot -PathType Container)){throw 'Portal request share is unavailable.'}
$pending=@(Get-ChildItem -LiteralPath $uncRequestRoot|Where-Object{-not$_.PSIsContainer-and$_.Name-match'\.ready\.zip(\.upload)?$'}|Select-Object -First 21)
if($pending.Count){throw ('Another portal request is pending: '+(($pending|ForEach-Object{$_.Name})-join', '))}
$ready=$requestRoot.TrimEnd('\')+'\'+$requestId+'.ready.zip'
$upload=$ready+'.upload'
$processed=$requestRoot.TrimEnd('\')+'\processed\'+$requestId+'.ready.zip'
$uncReady=$uncRequestRoot.TrimEnd('\')+'\'+$requestId+'.ready.zip'
$uncUpload=$uncReady+'.upload'
$uncProcessed=$uncRequestRoot.TrimEnd('\')+'\processed\'+$requestId+'.ready.zip'
$pathGate=& $pathTool -CandidatePath @($source,$upload,$ready,$processed) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'OLS4 publish path gate failed.'}
foreach($path in @($uncUpload,$uncReady,$uncProcessed)){if(Test-Path -LiteralPath $path){throw "OLS4 share artifact already exists: $path"}}

if($Preflight){
    [ordered]@{schema='argos_ols4_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS4_PUBLISH_PREFLIGHT';requestId=$requestId;sourceSha256=$expectedZipSha;sourceBytes=$expectedBytes;finalGateSha256=$expectedFinalGateSha;completeRouteGateSha256=$expectedRouteGateSha;recoveryIntentSha256=$expectedIntentSha;branch=$branch;localTip=$local;remoteTip=$remote;tipsMatch=$true;pendingRequests=0;existingRequestArtifacts=0;gatewayShareRoot=$shareRoot;gatewayShareObserved=$true;shortShareMapping='U:';shortShareMappingPlanned=$true;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$shareDriveCreated=$false
try{
$drive=Get-PSDrive -Name U -ErrorAction SilentlyContinue
if($null-eq$drive){[void](New-PSDrive -Name U -PSProvider FileSystem -Root $shareRoot -Scope Script -ErrorAction Stop);$shareDriveCreated=$true;$drive=Get-PSDrive -Name U -ErrorAction Stop}
$mappedRoot=if([string]::IsNullOrWhiteSpace([string]$drive.DisplayRoot)){[string]$drive.Root}else{[string]$drive.DisplayRoot}
if([string]::IsNullOrWhiteSpace($mappedRoot)-or-not$mappedRoot.TrimEnd('\').Equals($shareRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'U: does not map to the approved InspectionRevs gateway root.'}
$pending=@(Get-ChildItem -LiteralPath $requestRoot|Where-Object{-not$_.PSIsContainer-and$_.Name-match'\.ready\.zip(\.upload)?$'}|Select-Object -First 21)
if($pending.Count){throw ('Another portal request appeared after preflight: '+(($pending|ForEach-Object{$_.Name})-join', '))}
foreach($path in @($upload,$ready,$processed)){if(Test-Path -LiteralPath $path){throw "OLS4 share artifact appeared after preflight: $path"}}
Copy-Item -LiteralPath $source -Destination $upload -ErrorAction Stop
if((Get-Item -LiteralPath $upload).Length-ne$expectedBytes-or(Get-ProviderSha $upload)-ne$expectedZipSha){throw 'OLS4 uploaded ZIP hash mismatch.'}
Move-Item -LiteralPath $upload -Destination $ready -ErrorAction Stop
if((Get-Item -LiteralPath $ready).Length-ne$expectedBytes-or(Get-ProviderSha $ready)-ne$expectedZipSha){throw 'OLS4 published ZIP hash mismatch.'}
$record=[ordered]@{schema='argos_ols4_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS4_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;source=$source;publishedPath=$ready;bytes=$expectedBytes;sha256=$expectedZipSha;finalGateSha256=$expectedFinalGateSha;completeRouteGateSha256=$expectedRouteGateSha;recoveryIntentSha256=$expectedIntentSha;branch=$branch;localTip=$local;remoteTip=$remote;tipsMatch=$true;pendingRequestsBefore=0;shortShareMapping='U:';shortShareMappingVerified=$true;createNew=$true;overwritePerformed=$false;pathState=[string]$pathGate.state;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;currentWaferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($publishGatePath,(($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$record|ConvertTo-Json -Depth 8
}
finally{if($shareDriveCreated){Remove-PSDrive -Name U -Scope Script -Force -ErrorAction Stop}}
