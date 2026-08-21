[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply,[string]$InvocationManifest='')

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}
$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R8'
$requestId='REQ_R8'
$requestSha='0F1597BDBE5DBA29CC5123D580D7F1B3B85D0A170A2F86B17E8D2F0EDF9C88A0'
$requestBytes=[int64]8706
$finalGateSha='0D9DA2616924E2B85F89A4F7F81989823CDA66598A3FC1645A93277A1EA9B5F2'
$source=Join-Path $root 'final\REQ_R8.ready.zip'
$finalGatePath=$source+'.gate.json'
$publishGate=Join-Path $root 'R8_PUBLISH_GATE.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$share='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$uncRequestRoot=Join-Path $share 'ProjectPortalRO\requests'
$shortRequestRoot='U:\ProjectPortalRO\requests'
$isRehearsal=$false
if(-not[string]::IsNullOrWhiteSpace($InvocationManifest)){
    $invocation=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
    if([string]$invocation.schema-ne'argos_r8_publish_rehearsal_v1'-or-not[bool]$invocation.rehearsal){throw 'R8 publisher rehearsal manifest changed.'}
    $uncRequestRoot=[IO.Path]::GetFullPath([string]$invocation.queueRoot)
    $shortRequestRoot=$uncRequestRoot
    $publishGate=[IO.Path]::GetFullPath([string]$invocation.publishGate)
    foreach($path in @($uncRequestRoot,$publishGate)){if(-not$path.StartsWith('C:\R8P\',[StringComparison]::OrdinalIgnoreCase)){throw "R8 publisher rehearsal path escaped: $path"}}
    $isRehearsal=$true
}
$readyName=$requestId+'.ready.zip';$uploadName=$readyName+'.upload';$ready=$shortRequestRoot.TrimEnd('\')+'\'+$readyName;$upload=$shortRequestRoot.TrimEnd('\')+'\'+$uploadName
foreach($path in @($source,$finalGatePath,$pathTool)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "C2R publish input missing: $path"}}
if(Test-Path -LiteralPath $publishGate){throw 'C2R publish gate already exists.'}
if([int64](Get-Item -LiteralPath $source).Length-ne$requestBytes-or(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash-ne$requestSha){throw 'C2R final ZIP changed.'}
if((Get-FileHash -LiteralPath $finalGatePath -Algorithm SHA256).Hash-ne$finalGateSha){throw 'C2R final gate changed.'}
$finalGate=Get-Content -LiteralPath $finalGatePath -Raw|ConvertFrom-Json
if([string]$finalGate.state-ne'PASS_R8_FINAL_PACKAGE_GATE'-or-not[bool]$finalGate.publicationAuthorized-or@($finalGate.allowedTaskActions).Count-ne1-or[string]$finalGate.allowedTaskActions[0]-ne'RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'){throw 'R8 final contract changed.'}
function Queue-State([string]$Root){$items=@(Get-ChildItem -LiteralPath $Root -File -ErrorAction Stop|Where-Object{$_.Name-match'\.ready\.zip(\.upload)?$'});if($items.Count-eq0){return [pscustomobject]@{state='NEW';foreign=0}};if($items.Count-ne1-or@($readyName,$uploadName)-notcontains[string]$items[0].Name){throw ('Foreign or ambiguous portal request queue: '+(($items|Select-Object -First 5|ForEach-Object{$_.Name})-join', '))};if([int64]$items[0].Length-ne$requestBytes-or(Get-FileHash -LiteralPath $items[0].FullName -Algorithm SHA256).Hash-ne$requestSha){throw 'Own-name C2R queue artifact changed.'};return [pscustomobject]@{state=if([string]$items[0].Name-eq$uploadName){'EXACT_UPLOAD'}else{'EXACT_READY'};foreign=0}}
if(-not(Test-Path -LiteralPath $uncRequestRoot -PathType Container)){throw 'C2R request share unavailable.'}
$queue=Queue-State $uncRequestRoot
$pathGate=&$pathTool -CandidatePath @($source,$upload,$ready,$publishGate) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'C2R publish path gate failed.'}
$existing=if($isRehearsal){$null}else{Get-PSDrive U -ErrorAction SilentlyContinue}
if(-not$isRehearsal-and$null-ne$existing-and-not([IO.Path]::GetFullPath([string]$existing.Root).TrimEnd('\')).Equals([IO.Path]::GetFullPath($share).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Existing U: mapping is not pinned.'}
if($Preflight){[ordered]@{schema='argos_r8_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R8_PUBLISH_PREFLIGHT';requestId=$requestId;sourceSha256=$requestSha;sourceBytes=$requestBytes;finalGateSha256=$finalGateSha;pendingRequests=[int]$queue.foreign;exactResumeState=[string]$queue.state;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return}
$createdDrive=$false
try{
    $drive=Get-PSDrive U -ErrorAction SilentlyContinue
    if(-not$isRehearsal-and$null-eq$drive){[void](New-PSDrive -Name U -PSProvider FileSystem -Root $share -Scope Global);$createdDrive=$true;$drive=Get-PSDrive U -ErrorAction Stop}
    if(-not$isRehearsal-and-not([IO.Path]::GetFullPath([string]$drive.Root).TrimEnd('\')).Equals([IO.Path]::GetFullPath($share).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'C2R U: mapping changed.'}
    $applyState=Queue-State $shortRequestRoot
    if([string]$applyState.state-ne[string]$queue.state){throw "C2R queue changed: $($queue.state) -> $($applyState.state)"}
    if([string]$queue.state-eq'NEW'){Copy-Item -LiteralPath $source -Destination $upload;if([int64](Get-Item -LiteralPath $upload).Length-ne$requestBytes-or(Get-FileHash -LiteralPath $upload -Algorithm SHA256).Hash-ne$requestSha){throw 'C2R upload changed.'};Move-Item -LiteralPath $upload -Destination $ready}
    elseif([string]$queue.state-eq'EXACT_UPLOAD'){if(Test-Path -LiteralPath $ready){throw 'C2R ready appeared before resume.'};Move-Item -LiteralPath $upload -Destination $ready}
    elseif([string]$queue.state-ne'EXACT_READY'){throw "Unsupported C2R queue state: $($queue.state)"}
    if([int64](Get-Item -LiteralPath $ready).Length-ne$requestBytes-or(Get-FileHash -LiteralPath $ready -Algorithm SHA256).Hash-ne$requestSha){throw 'C2R published ZIP changed.'}
    $state=if($isRehearsal){'PASS_R8_EXACT_PUBLISHER_CREATE_NEW_REHEARSAL'}elseif([string]$queue.state-eq'NEW'){'PASS_R8_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'}elseif([string]$queue.state-eq'EXACT_UPLOAD'){'PASS_R8_EXACT_SIGNED_REQUEST_PUBLISHED_RESUMED_UPLOAD'}else{'PASS_R8_EXACT_SIGNED_REQUEST_PUBLISHED_RECOVERED_READY'}
    $gate=[ordered]@{schema='argos_r8_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state=$state;disposition='PENDING_GATE';requestId=$requestId;source=$source;publishedPath=$ready;bytes=$requestBytes;sha256=$requestSha;finalGateSha256=$finalGateSha;createNew=$true;initialQueueState=[string]$queue.state;overwritePerformed=$false;pendingRequestsBeforePublication=[int]$queue.foreign;pendingRequestsAtApply=[int]$applyState.foreign;pathState=[string]$pathGate.state;allowedTaskActions=@('RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2');priorTerminalResponseId='R_CB3CDBA6F0B8_20260821161419288_ddf4e3bc';sourceDeletionPerformed=$false;otherInspectionTasksChanged=$false;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    [IO.File]::WriteAllText($publishGate,(($gate|ConvertTo-Json -Depth 6)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    $gate|ConvertTo-Json -Depth 6
}finally{if($createdDrive){Remove-PSDrive U -Force -Scope Global -ErrorAction SilentlyContinue}}
