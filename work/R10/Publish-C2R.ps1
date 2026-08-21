[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}
$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R10'
$requestId='REQ_R10'
$requestSha='10DEEB44E465CBE53A0E427BB36169E9EC1B31EB24F550251D83D838396D51E7'
$requestBytes=[int64]9229
$finalGateSha='A455C9A46073EFBAE3A414874F4404EB4D5DA8E34F0A09795ABC79F516272E83'
$source=Join-Path $root 'final\REQ_R10.ready.zip'
$finalGatePath=$source+'.gate.json'
$publishGate=Join-Path $root 'R10_PUBLISH_GATE.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$share='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$uncRequestRoot=Join-Path $share 'ProjectPortalRO\requests'
$shortRequestRoot='U:\ProjectPortalRO\requests'
$readyName=$requestId+'.ready.zip';$uploadName=$readyName+'.upload';$ready=$shortRequestRoot.TrimEnd('\')+'\'+$readyName;$upload=$shortRequestRoot.TrimEnd('\')+'\'+$uploadName
foreach($path in @($source,$finalGatePath,$pathTool)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "C2R publish input missing: $path"}}
if(Test-Path -LiteralPath $publishGate){throw 'C2R publish gate already exists.'}
if([int64](Get-Item -LiteralPath $source).Length-ne$requestBytes-or(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash-ne$requestSha){throw 'C2R final ZIP changed.'}
if((Get-FileHash -LiteralPath $finalGatePath -Algorithm SHA256).Hash-ne$finalGateSha){throw 'C2R final gate changed.'}
$finalGate=Get-Content -LiteralPath $finalGatePath -Raw|ConvertFrom-Json
if([string]$finalGate.state-ne'PASS_R10_FINAL_PACKAGE_GATE'-or-not[bool]$finalGate.publicationAuthorized-or[int]$finalGate.responseSignaturesVerified-ne10-or-not[bool]$finalGate.rawCatalogSelectorExercised-or@($finalGate.allowedTaskActions).Count-ne1-or[string]$finalGate.allowedTaskActions[0]-ne'RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'){throw 'R10 final contract changed.'}
function Queue-State([string]$Root){$items=@(Get-ChildItem -LiteralPath $Root -File -ErrorAction Stop|Where-Object{$_.Name-match'\.ready\.zip(\.upload)?$'});if($items.Count-eq0){return [pscustomobject]@{state='NEW';foreign=0}};if($items.Count-ne1-or@($readyName,$uploadName)-notcontains[string]$items[0].Name){throw ('Foreign or ambiguous portal request queue: '+(($items|Select-Object -First 5|ForEach-Object{$_.Name})-join', '))};if([int64]$items[0].Length-ne$requestBytes-or(Get-FileHash -LiteralPath $items[0].FullName -Algorithm SHA256).Hash-ne$requestSha){throw 'Own-name C2R queue artifact changed.'};return [pscustomobject]@{state=if([string]$items[0].Name-eq$uploadName){'EXACT_UPLOAD'}else{'EXACT_READY'};foreign=0}}
if(-not(Test-Path -LiteralPath $uncRequestRoot -PathType Container)){throw 'C2R request share unavailable.'}
$queue=Queue-State $uncRequestRoot
$pathGate=&$pathTool -CandidatePath @($source,$upload,$ready,$publishGate) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'C2R publish path gate failed.'}
$existing=Get-PSDrive U -ErrorAction SilentlyContinue
if($null-ne$existing-and-not([IO.Path]::GetFullPath([string]$existing.Root).TrimEnd('\')).Equals([IO.Path]::GetFullPath($share).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Existing U: mapping is not pinned.'}
if($Preflight){[ordered]@{schema='argos_r10_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_PUBLISH_PREFLIGHT';requestId=$requestId;sourceSha256=$requestSha;sourceBytes=$requestBytes;finalGateSha256=$finalGateSha;pendingRequests=[int]$queue.foreign;exactResumeState=[string]$queue.state;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return}
$createdDrive=$false
try{
    $drive=Get-PSDrive U -ErrorAction SilentlyContinue
    if($null-eq$drive){[void](New-PSDrive -Name U -PSProvider FileSystem -Root $share -Scope Global);$createdDrive=$true;$drive=Get-PSDrive U -ErrorAction Stop}
    if(-not([IO.Path]::GetFullPath([string]$drive.Root).TrimEnd('\')).Equals([IO.Path]::GetFullPath($share).TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'C2R U: mapping changed.'}
    $applyState=Queue-State $shortRequestRoot
    if([string]$applyState.state-ne[string]$queue.state){throw "C2R queue changed: $($queue.state) -> $($applyState.state)"}
    if([string]$queue.state-eq'NEW'){Copy-Item -LiteralPath $source -Destination $upload;if([int64](Get-Item -LiteralPath $upload).Length-ne$requestBytes-or(Get-FileHash -LiteralPath $upload -Algorithm SHA256).Hash-ne$requestSha){throw 'C2R upload changed.'};Move-Item -LiteralPath $upload -Destination $ready}
    elseif([string]$queue.state-eq'EXACT_UPLOAD'){if(Test-Path -LiteralPath $ready){throw 'C2R ready appeared before resume.'};Move-Item -LiteralPath $upload -Destination $ready}
    elseif([string]$queue.state-ne'EXACT_READY'){throw "Unsupported C2R queue state: $($queue.state)"}
    if([int64](Get-Item -LiteralPath $ready).Length-ne$requestBytes-or(Get-FileHash -LiteralPath $ready -Algorithm SHA256).Hash-ne$requestSha){throw 'C2R published ZIP changed.'}
    $state=if([string]$queue.state-eq'NEW'){'PASS_R10_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'}elseif([string]$queue.state-eq'EXACT_UPLOAD'){'PASS_R10_EXACT_SIGNED_REQUEST_PUBLISHED_RESUMED_UPLOAD'}else{'PASS_R10_EXACT_SIGNED_REQUEST_PUBLISHED_RECOVERED_READY'}
    $gate=[ordered]@{schema='argos_r10_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state=$state;disposition='PENDING_GATE';requestId=$requestId;source=$source;publishedPath=$ready;bytes=$requestBytes;sha256=$requestSha;finalGateSha256=$finalGateSha;createNew=$true;initialQueueState=[string]$queue.state;overwritePerformed=$false;pendingRequestsBeforePublication=[int]$queue.foreign;pendingRequestsAtApply=[int]$applyState.foreign;pathState=[string]$pathGate.state;allowedTaskActions=@('RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2');sourceTerminalResponseId='R_C57E232B3681_20260820052535470_afeba1f7';r9DiagnosticResponseId='R_A5A427490F0D_20260821174144370_961e73de';sourceDeletionPerformed=$false;otherInspectionTasksChanged=$false;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    [IO.File]::WriteAllText($publishGate,(($gate|ConvertTo-Json -Depth 6)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    $gate|ConvertTo-Json -Depth 6
}finally{if($createdDrive){Remove-PSDrive U -Force -Scope Global -ErrorAction SilentlyContinue}}
