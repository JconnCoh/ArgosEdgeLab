#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InvocationManifest,[switch]$Preflight,[switch]$Publish)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Hash,[string]$State){Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3Q2 publisher dependency absent: $Path";Assert-True ((Get-Sha $Path)-eq$Hash) "O3Q2 publisher dependency changed: $Path";$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;Assert-True ([string]$value.state-eq$State) "O3Q2 publisher gate state changed: $Path"}
function Write-NewJson([string]$Path,[object]$Value){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3Q2 publication gate exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 10)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
$expectedInvocationPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3Q2_PUBLISH_INVOCATION.json'))
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3Q2 publish invocation path changed.'
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True ([string]$invocation.schema-eq'argos_o3q2_publish_invocation_v1'-and[string]$invocation.state-eq'FROZEN_EXACT_PUBLISH_INVOCATION') 'O3Q2 publish invocation state changed.'
Assert-True ([string]$invocation.powerShellScriptSha256-eq(Get-Sha $PSCommandPath)) 'O3Q2 invocation does not pin the exact publisher.'
Assert-True ([string]$invocation.requestId-eq'REQ_20260828T033000222Z_62629419O3Q2'-and[int]$invocation.maximumPublicationsAuthorized-eq1-and-not[bool]$invocation.requestRetryAuthorized) 'O3Q2 publish authority changed.'

$requestId='REQ_20260828T033000222Z_62629419O3Q2'
$zipName=$requestId+'.ready.zip'
$zip=Join-Path $PSScriptRoot ('final_numeric\'+$zipName)
$expectedZipSha='F107CB94E8580EB018C373F2995BC6D817D7E4337D351F875E861B5A42D1AACC'
$routeGate=Join-Path $PSScriptRoot 'O3Q2_COMPLETE_ROUTE_GATE.json'
$packageGate=Join-Path $PSScriptRoot 'O3Q2_EXACT_PACKAGE_REHEARSAL_R3_GATE.json'
$shareObservation=Join-Path $PSScriptRoot 'O3Q2_CURRENT_SHARE_OBSERVATION.json'
$publicationGate=Join-Path $PSScriptRoot 'O3Q2_NUMERIC_PUBLISH_GATE.json'
$expectedDisplayRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestShare='U:\ProjectPortalRO\requests'
$upload=Join-Path $requestShare ($zipName+'.upload')
$destination=Join-Path $requestShare $zipName
Assert-True (Test-Path -LiteralPath $zip -PathType Leaf) 'O3Q2 request ZIP is absent.'
Assert-True ((Get-Sha $zip)-eq$expectedZipSha) 'O3Q2 request ZIP changed.'
Assert-Pin $routeGate '99DF24C6CF06C3365E9349E140216B300BA4AE565A9162AEC99670F6EB72DC2C' 'PASS_O3Q2_COMPLETE_ROUTE_GATE'
Assert-Pin $packageGate 'A280ABD5962589DBFB53654B571304CB8F5E8476B04497464E485194F37B7D00' 'PASS_O3Q2_EXACT_PACKAGE_REHEARSAL_R3'
Assert-Pin $shareObservation 'D461ADF0870F74C66243A6BA26D8F9FD57CA14B098621CC721BBE775DED07BF9' 'PASS_O3Q2_CURRENT_SHARE_ZERO_PENDING_REQUESTS'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot-eq$expectedDisplayRoot) 'O3Q2 persistent U: mapping changed.'
$logicalDisk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ([string]$logicalDisk.ProviderName-eq$expectedDisplayRoot-and[int]$logicalDisk.DriveType-eq4) 'O3Q2 Win32 persistent U: mapping changed.'
Assert-True (Test-Path -LiteralPath $requestShare -PathType Container) 'O3Q2 request share is unavailable.'
Assert-True (@(Get-ChildItem -LiteralPath $requestShare -File -ErrorAction Stop).Count-eq0) 'O3Q2 request share is not zero-pending.'
foreach($path in @($upload,$destination,$publicationGate)){Assert-True (-not(Test-Path -LiteralPath $path)) "O3Q2 publication target exists: $path"}
$branch=(git branch --show-current).Trim();Assert-True ($branch-eq'codex/fiducial-opencv-d-drive') 'O3Q2 publisher branch changed.'
$status=@(git status --porcelain);Assert-True ($status.Count-eq0) 'O3Q2 publisher requires a clean worktree.'
$local=(git rev-parse HEAD).Trim();$remote=(git rev-parse origin/codex/fiducial-opencv-d-drive).Trim();Assert-True ($local-eq$remote) 'O3Q2 publisher requires matching local and remote tips.'
if($Preflight){[ordered]@{schema='argos_o3q2_numeric_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q2_NUMERIC_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha;branch=$branch;commit=$local;displayRoot=$expectedDisplayRoot;win32ProviderName=[string]$logicalDisk.ProviderName;win32DriveType=[int]$logicalDisk.DriveType;share=$requestShare;zeroPending=$true;destinationAbsent=$true;requestRetryAuthorized=$false;mutationsPerformed=$false;gatewayAcceptanceIsExecutionEvidence=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}
Copy-Item -LiteralPath $zip -Destination $upload -ErrorAction Stop
Assert-True ((Get-Sha $upload)-eq$expectedZipSha) 'O3Q2 upload hash changed.'
Move-Item -LiteralPath $upload -Destination $destination -ErrorAction Stop
Assert-True ((Get-Sha $destination)-eq$expectedZipSha) 'O3Q2 published hash changed.'
$gate=[ordered]@{schema='argos_o3q2_numeric_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q2_NUMERIC_REQUEST_PUBLISHED_ONCE';requestId=$requestId;requestZipSha256=$expectedZipSha;destination=$destination;destinationSha256=Get-Sha $destination;branch=$branch;commit=$local;displayRoot=$expectedDisplayRoot;win32ProviderName=[string]$logicalDisk.ProviderName;win32DriveType=[int]$logicalDisk.DriveType;publicationCount=1;requestRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $publicationGate $gate
$gate|ConvertTo-Json -Depth 10
