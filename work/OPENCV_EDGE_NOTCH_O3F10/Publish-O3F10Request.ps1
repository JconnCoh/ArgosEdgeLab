#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InvocationManifest,[switch]$Preflight,[switch]$Publish)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Assert-O3F10([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-O3F10Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-O3F10Gate([string]$Path,[string]$Hash,[string]$State){Assert-O3F10 (Test-Path -LiteralPath $Path -PathType Leaf) "O3F10 publisher dependency is absent: $Path";Assert-O3F10 ((Get-O3F10Hash $Path)-eq$Hash) "O3F10 publisher dependency changed: $Path";$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;Assert-O3F10 ([string]$value.state-eq$State) "O3F10 publisher state changed: $Path";return $value}
function Write-O3F10Json([string]$Path,[object]$Value){Assert-O3F10 (-not(Test-Path -LiteralPath $Path)) "O3F10 publication gate exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 10)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$invocationPath=[IO.Path]::GetFullPath($InvocationManifest);$expectedInvocationPath=Join-Path $PSScriptRoot 'O3F10_PUBLISH_INVOCATION.json'
Assert-O3F10 ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3F10 publish invocation path changed.'
$invoke=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-O3F10 ([string]$invoke.schema-eq'argos_ocv03_o3f10_publish_invocation_v1'-and[string]$invoke.state-eq'FROZEN_EXACT_PUBLISH_INVOCATION') 'O3F10 publish invocation is not frozen.'
Assert-O3F10 ([string]$invoke.publisherSha256-eq(Get-O3F10Hash $PSCommandPath)-and[string]$invoke.requestId-eq'REQ_O3F10_20260902A'-and[int]$invoke.maximumPublicationsAuthorized-eq1-and-not[bool]$invoke.requestRetryAuthorized) 'O3F10 publish authority changed.'
$zip=Join-Path $project ([string]$invoke.requestZip);Assert-O3F10 (Test-Path -LiteralPath $zip -PathType Leaf) 'O3F10 request ZIP is absent.';Assert-O3F10 ((Get-O3F10Hash $zip)-eq[string]$invoke.requestZipSha256) 'O3F10 request ZIP changed.'
$finalGate=Assert-O3F10Gate (Join-Path $project ([string]$invoke.finalPackageGate.path)) ([string]$invoke.finalPackageGate.sha256) 'PASS_O3F10_FINAL_PACKAGE_GATE'
$packageRehearsal=Assert-O3F10Gate (Join-Path $project ([string]$invoke.exactPackageRehearsalGate.path)) ([string]$invoke.exactPackageRehearsalGate.sha256) 'PASS_O3F10_EXACT_PACKAGE_REHEARSAL'
$routeGate=Assert-O3F10Gate (Join-Path $project ([string]$invoke.completeRouteGate.path)) ([string]$invoke.completeRouteGate.sha256) 'PASS_O3F10_COMPLETE_ROUTE_GATE'
$rehearsalGate=Assert-O3F10Gate (Join-Path $project ([string]$invoke.endpointRehearsalGate.path)) ([string]$invoke.endpointRehearsalGate.sha256) 'PASS_O3F10_EXACT_ENTRYPOINT_REHEARSAL'
$share=Assert-O3F10Gate (Join-Path $project ([string]$invoke.currentShareObservation.path)) ([string]$invoke.currentShareObservation.sha256) 'PASS_O3F10_CURRENT_SHARE_ZERO_PENDING_REQUESTS'
$accepted=Assert-O3F10Gate (Join-Path $project ([string]$invoke.acceptedRequestObservation.path)) ([string]$invoke.acceptedRequestObservation.sha256) 'PASS_O3F10_CURRENT_SHARE_ZERO_PENDING_REQUESTS'
$preaction=Assert-O3F10Gate (Join-Path $project ([string]$invoke.preactionGate.path)) ([string]$invoke.preactionGate.sha256) 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION'
Assert-O3F10 ([int]$share.pendingRequestCount-eq0-and[int]$accepted.unresolvedAcceptedRequestCount-eq0) 'O3F10 portal queue is not clear.'
Assert-O3F10 ([string]$finalGate.requestZipSha256-eq[string]$invoke.requestZipSha256-and[string]$packageRehearsal.requestZipSha256-eq[string]$invoke.requestZipSha256-and[string]$routeGate.requestZipSha256-eq[string]$invoke.requestZipSha256) 'O3F10 package/rehearsal/route ZIP identity changed.'
$expectedDisplayRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop;$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-O3F10 ([string]$drive.DisplayRoot-eq$expectedDisplayRoot-and[string]$disk.ProviderName-eq$expectedDisplayRoot-and[int]$disk.DriveType-eq4) 'O3F10 persistent U: mapping changed.'
$requestRoot='U:\ProjectPortalRO\requests';$zipName='REQ_O3F10_20260902A.ready.zip';$upload=Join-Path $requestRoot ($zipName+'.upload');$destination=Join-Path $requestRoot $zipName;$gatePath=Join-Path $PSScriptRoot 'O3F10_PUBLISH_GATE.json'
Assert-O3F10 (@(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop).Count-eq0) 'O3F10 request share is not zero-pending.'
foreach($path in @($upload,$destination,$gatePath)){Assert-O3F10 (-not(Test-Path -LiteralPath $path)) "O3F10 publication target exists: $path"}
$git=Get-Command git.exe -CommandType Application -ErrorAction Stop;$branch=(& $git.Source branch --show-current).Trim();$status=@(& $git.Source status --porcelain --untracked-files=no);$local=(& $git.Source rev-parse HEAD).Trim();$remote=(& $git.Source rev-parse refs/remotes/origin/codex/fiducial-opencv-d-drive).Trim()
Assert-O3F10 ($branch-eq'codex/fiducial-opencv-d-drive'-and$status.Count-eq0-and$local-eq$remote) 'O3F10 publisher requires clean matching branch tips.'
if($Preflight){[ordered]@{schema='argos_ocv03_o3f10_publish_preflight_v1';state='PASS_O3F10_PUBLISH_PREFLIGHT';requestId=[string]$invoke.requestId;requestZipSha256=[string]$invoke.requestZipSha256;branch=$branch;commit=$local;zeroPending=$true;unresolvedAcceptedRequestCount=0;destinationAbsent=$true;mutationsPerformed=$false;publicationCount=0;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}
Copy-Item -LiteralPath $zip -Destination $upload;Assert-O3F10 ((Get-O3F10Hash $upload)-eq[string]$invoke.requestZipSha256) 'O3F10 upload hash changed.';Move-Item -LiteralPath $upload -Destination $destination;Assert-O3F10 ((Get-O3F10Hash $destination)-eq[string]$invoke.requestZipSha256) 'O3F10 published hash changed.'
$gate=[ordered]@{schema='argos_ocv03_o3f10_publish_gate_v1';state='PASS_O3F10_REQUEST_PUBLISHED_ONCE';requestId=[string]$invoke.requestId;destination=$destination;destinationSha256=Get-O3F10Hash $destination;branch=$branch;commit=$local;publicationCount=1;requestRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;reviewOnly=$true;productionRoutingEnabled=$false};Write-O3F10Json $gatePath $gate;$gate|ConvertTo-Json -Depth 10

