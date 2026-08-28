#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Publish)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if([bool]$Preflight-eq[bool]$Publish){throw 'Specify exactly one mode.'}
function Assert([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Norm([string]$Path){$Path.Replace('/','\').TrimEnd('\')}
function Write-NewJson([string]$Path,[object]$Value){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 10)+[Environment]::NewLine));$s=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$s.Write($bytes,0,$bytes.Length)}finally{$s.Dispose()}}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$id='REQ_20260828T221421386Z_36FAA9BECC1C'
$zip=Join-Path $PSScriptRoot ('final\'+$id+'.ready.zip')
$zipSha='C6ACF4CFA5B4755763F3462AC4A9BCFE40FEEC72C7EB451A4FCE824446EFF0AC';$zipBytes=1311
$gate=Join-Path $PSScriptRoot 'O3B5_FINAL_PACKAGE_GATE.json';$gateSha='D5FCAE261F4A861B996BC5E565C09AF401928944D1C7133E54473FB490AF821A'
$share='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$root='U:\ProjectPortalRO\requests';$ready=Join-Path $root ($id+'.ready.zip');$upload=$ready+'.upload';$processed=Join-Path (Join-Path $root 'processed') ($id+'.ready.zip');$publishGate=Join-Path $PSScriptRoot 'O3B5_PUBLISH_GATE.json'
Assert((Test-Path -LiteralPath $zip -PathType Leaf)-and(Sha $zip)-eq$zipSha-and(Get-Item -LiteralPath $zip).Length-eq$zipBytes)'O3B5 ZIP changed.'
Assert((Test-Path -LiteralPath $gate -PathType Leaf)-and(Sha $gate)-eq$gateSha)'O3B5 final gate changed.'
$g=Get-Content -LiteralPath $gate -Raw|ConvertFrom-Json;Assert([string]$g.state-eq'PASS_O3B5_FINAL_STATUS_PACKAGE_GATE'-and[string]$g.requestId-eq$id-and[bool]$g.signatureVerified-and[bool]$g.allEnumeratedRoutePathsPassed)'O3B5 final gate invalid.'
$branch='codex/fiducial-opencv-d-drive';$local=(&git -C $project rev-parse HEAD|Out-String).Trim();$remote=(&git -C $project rev-parse ('origin/'+$branch)|Out-String).Trim();Assert((&git -C $project branch --show-current|Out-String).Trim()-eq$branch-and$local-eq$remote)'O3B5 branch tips differ.';Assert(@(&git -C $project status --porcelain=v1).Count-eq0)'O3B5 worktree is not clean.'
$drive=Get-PSDrive U -PSProvider FileSystem -ErrorAction Stop;$logical=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop;Assert((Norm([string]$drive.DisplayRoot)).Equals((Norm $share),[StringComparison]::OrdinalIgnoreCase))'O3B5 PowerShell U mapping changed.';Assert([int]$logical.DriveType-eq4-and(Norm([string]$logical.ProviderName)).Equals((Norm $share),[StringComparison]::OrdinalIgnoreCase))'O3B5 logical U mapping changed.'
$pending=@(Get-ChildItem -LiteralPath $root -File -Force|Where-Object{$_.Name-match'\.ready\.zip(\.upload)?$'});Assert($pending.Count-eq0)'O3B5 another request is pending.';foreach($p in @($ready,$upload,$processed,$publishGate)){Assert(-not(Test-Path -LiteralPath $p))"O3B5 create-new target exists: $p"}
$record=[ordered]@{schema='argos_o3b5_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=if($Preflight){'PASS_O3B5_PUBLISH_PREFLIGHT'}else{'PASS_O3B5_EXACT_STATUS_REQUEST_PUBLISHED_CREATE_NEW'};requestId=$id;zipSha256=$zipSha;zipBytes=$zipBytes;localTip=$local;remoteTip=$remote;tipsMatch=$true;pendingRequestCount=0;persistentUMappingVerified=$true;maximumPublications=1;retryAuthorized=$false;installedCodeChange=$false;taskActions=0;processActions=0;imageBytesRead=$false;sourceHashingPerformed=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$record|ConvertTo-Json -Depth 8;return}
[IO.File]::Copy($zip,$upload,$false);Assert((Sha $upload)-eq$zipSha)'O3B5 upload changed.';[IO.File]::Move($upload,$ready);Assert((Sha $ready)-eq$zipSha)'O3B5 ready changed.';$record.publishedPath=$ready;Write-NewJson $publishGate $record;$record|ConvertTo-Json -Depth 8
