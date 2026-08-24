[CmdletBinding()]
param([switch]$Preflight,[switch]$Publish)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Get-ProviderSha256([string]$LiteralPath){$sha=[Security.Cryptography.SHA256]::Create();try{Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576|ForEach-Object{[byte[]]$block=$_;if($block.Length){[void]$sha.TransformBlock($block,0,$block.Length,$block,0)}};[void]$sha.TransformFinalBlock((New-Object byte[] 0),0,0);return([BitConverter]::ToString($sha.Hash)).Replace('-','')}finally{$sha.Dispose()}}
$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\OPENCV_OLS5'
$requestId='REQ_O5OBS1'
$source=Join-Path $root 'final_o5obs1\REQ_O5OBS1.ready.zip'
$packageGate=Join-Path $root 'O5OBS1_EXACT_PACKAGE_GATE.json'
$routeGate=Join-Path $root 'O5OBS1_COMPLETE_ROUTE_GATE.json'
$intent=Join-Path $root 'O5OBS1_RECOVERY_INTENT_R4.json'
$output=Join-Path $root 'O5OBS1_PUBLISH_GATE.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$expectedZip='8B450620F1A4BF467AFECC48EB300117C604D302D80D4A3504C418ED4A2BF5E6'
$expectedPackageGate='173B0D83DFFD9F59FF29FDDC5150303451C85254ADBDB95046133E2608F54386'
$expectedRouteGate='3F223688170297BAF156181060AF61FB6B1C9335B8ACA8C7B8A9898D96980163'
$expectedIntent='7888778CA8EAC9C6081092CB723B58106D8E0D11BE0B2AE8E54DEEC457AC6771'
foreach($pin in @(@($source,$expectedZip),@($packageGate,$expectedPackageGate),@($routeGate,$expectedRouteGate),@($intent,$expectedIntent))){if(-not(Test-Path -LiteralPath $pin[0] -PathType Leaf)-or(Get-ProviderSha256 $pin[0])-ne$pin[1]){throw "O5OBS1 publish input changed: $($pin[0])"}}
if(Test-Path -LiteralPath $output){throw 'O5OBS1 publish gate already exists.'}
$p=Get-Content -LiteralPath $packageGate -Raw|ConvertFrom-Json;$r=Get-Content -LiteralPath $routeGate -Raw|ConvertFrom-Json;$i=Get-Content -LiteralPath $intent -Raw|ConvertFrom-Json
if([string]$p.state-ne'PASS_O5OBS1_EXACT_SIGNED_DATA_PULL_PACKAGE'-or[string]$p.requestZipSha256-ne$expectedZip-or[string]$r.state-ne'PASS_O5OBS1_COMPLETE_ROUTE_GATE'-or[string]$r.requestZipSha256-ne$expectedZip-or-not[bool]$r.publicationAuthorized-or[string]$i.mode-ne'OBSERVE'-or[string]$i.route.jobClass-ne'DATA_PULL'){throw 'O5OBS1 frozen publish contract changed.'}
$continuity=Get-Content -LiteralPath (Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json') -Raw|ConvertFrom-Json
if([string]$continuity.activePhase-ne'OCV00_OLS5_SIGNED_HASH_TIMEOUT_POST_FAILURE_OBSERVATION_REQUIRED'-or[bool]$continuity.productionEligible){throw 'O5OBS1 continuity authority changed.'}
$branch=(& git -C $project branch --show-current|Out-String).Trim();$local=(& git -C $project rev-parse HEAD|Out-String).Trim();$remoteLine=(& git -C $project ls-remote --heads origin ('refs/heads/'+$branch)|Out-String).Trim();$remote=if([string]::IsNullOrWhiteSpace($remoteLine)){''}else{($remoteLine-split'\s+')[0]}
if($branch-ne'codex/fiducial-opencv-d-drive'-or$local-ne'ecbda3205852550d7f9fdb4a4daf99b4a001e7da'-or$remote-ne$local){throw 'O5OBS1 branch authority mismatch.'}
$share='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$uncRoot=$share+'\ProjectPortalRO\requests';$requestRoot='U:\ProjectPortalRO\requests';$ready=$requestRoot+'\'+$requestId+'.ready.zip';$upload=$ready+'.upload';$processed=$requestRoot+'\processed\'+$requestId+'.ready.zip'
$pending=@(Get-ChildItem -LiteralPath $uncRoot|Where-Object{-not$_.PSIsContainer-and$_.Name-match'\.ready\.zip(\.upload)?$'}|Select-Object -First 21);if($pending.Count){throw 'Another request is pending.'}
foreach($path in @($uncRoot+'\'+$requestId+'.ready.zip.upload',$uncRoot+'\'+$requestId+'.ready.zip',$uncRoot+'\processed\'+$requestId+'.ready.zip')){if(Test-Path -LiteralPath $path){throw "O5OBS1 share artifact exists: $path"}}
$pathGate=& $pathTool -CandidatePath @($source,$upload,$ready,$processed) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json;if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'O5OBS1 publish path gate failed.'}
if($Preflight){[ordered]@{schema='argos_o5obs1_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O5OBS1_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;requestZipBytes=(Get-Item -LiteralPath $source).Length;packageGateSha256=$expectedPackageGate;routeGateSha256=$expectedRouteGate;intentSha256=$expectedIntent;branch=$branch;localTip=$local;remoteTip=$remote;pendingRequests=0;existingArtifacts=0;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}
$createdDrive=$false
try{$drive=Get-PSDrive -Name U -ErrorAction SilentlyContinue;if($null-eq$drive){[void](New-PSDrive -Name U -PSProvider FileSystem -Root $share -Scope Script);$createdDrive=$true;$drive=Get-PSDrive -Name U};$mapped=if([string]::IsNullOrWhiteSpace([string]$drive.DisplayRoot)){[string]$drive.Root}else{[string]$drive.DisplayRoot};if(-not$mapped.TrimEnd('\').Equals($share.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'U mapping changed.'};if(@(Get-ChildItem -LiteralPath $requestRoot|Where-Object{-not$_.PSIsContainer-and$_.Name-match'\.ready\.zip(\.upload)?$'}|Select-Object -First 1).Count){throw 'Another request appeared.'};Copy-Item -LiteralPath $source -Destination $upload;if((Get-ProviderSha256 $upload)-ne$expectedZip){throw 'O5OBS1 upload hash mismatch.'};Move-Item -LiteralPath $upload -Destination $ready;if((Get-ProviderSha256 $ready)-ne$expectedZip){throw 'O5OBS1 ready hash mismatch.'};$record=[ordered]@{schema='argos_o5obs1_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O5OBS1_EXACT_SIGNED_DATA_PULL_PUBLISHED';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$ready;bytes=(Get-Item -LiteralPath $ready).Length;sha256=$expectedZip;packageGateSha256=$expectedPackageGate;routeGateSha256=$expectedRouteGate;intentSha256=$expectedIntent;branch=$branch;localTip=$local;remoteTip=$remote;tipsMatch=$true;pendingRequestsBefore=0;createNew=$true;overwritePerformed=$false;imageRead=$false;sourceHashing=$false;taskActions=@();processActions=@();sourceDeletionPerformed=$false;waferActionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false};[IO.File]::WriteAllText($output,(($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)));$record|ConvertTo-Json -Depth 8}finally{if($createdDrive){Remove-PSDrive -Name U -Scope Script -Force}}
