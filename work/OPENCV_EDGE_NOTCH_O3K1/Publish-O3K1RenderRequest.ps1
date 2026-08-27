#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Publish)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Hash,[string]$State){Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3K1 publisher dependency absent: $Path";Assert-True ((Get-Sha $Path)-eq$Hash) "O3K1 publisher dependency changed: $Path";$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;Assert-True ([string]$value.state-eq$State) "O3K1 publisher gate state changed: $Path"}
function Write-NewJson([string]$Path,[object]$Value){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3K1 publication gate exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 10)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$requestId='REQ_20260827T201500111Z_62629419O3K1'
$zipName=$requestId+'.ready.zip'
$zip=Join-Path $PSScriptRoot ('final_render\'+$zipName)
$expectedZipSha='B755ECE17D8FE81BD5D49D607445004BE729A47FD7F2154AD0544D1B1F8FA24C'
$routeGate=Join-Path $PSScriptRoot 'O3K1_COMPLETE_ROUTE_GATE.json'
$packageGate=Join-Path $PSScriptRoot 'O3K1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$shareObservation=Join-Path $PSScriptRoot 'O3K1_CURRENT_SHARE_OBSERVATION.json'
$publicationGate=Join-Path $PSScriptRoot 'O3K1_RENDER_PUBLISH_GATE.json'
$expectedDisplayRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestShare='U:\ProjectPortalRO\requests'
$upload=Join-Path $requestShare ($zipName+'.upload')
$destination=Join-Path $requestShare $zipName
Assert-True (Test-Path -LiteralPath $zip -PathType Leaf) 'O3K1 request ZIP is absent.'
Assert-True ((Get-Sha $zip)-eq$expectedZipSha) 'O3K1 request ZIP changed.'
Assert-Pin $routeGate '74B5B8D29596D6DADB81CFE987584AE768D0BAC4F37FF63CE990403588BBF1E0' 'PASS_O3K1_COMPLETE_ROUTE_GATE'
Assert-Pin $packageGate 'CF55899F25D2143629A9E0EE9165DAEC390597A12504352C2AB663B4A9009299' 'PASS_O3K1_EXACT_PACKAGE_REHEARSAL'
Assert-Pin $shareObservation '80BBCA60C07F0EE75DD82A8E877AA031C02FCA98F426C5AA66BD677C660DFB2C' 'PASS_O3K1_CURRENT_SHARE_ZERO_PENDING_REQUESTS'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot-eq$expectedDisplayRoot) 'O3K1 persistent U: mapping changed.'
Assert-True (Test-Path -LiteralPath $requestShare -PathType Container) 'O3K1 request share is unavailable.'
Assert-True (@(Get-ChildItem -LiteralPath $requestShare -File -ErrorAction Stop).Count-eq0) 'O3K1 request share is not zero-pending.'
foreach($path in @($upload,$destination,$publicationGate)){Assert-True (-not(Test-Path -LiteralPath $path)) "O3K1 publication target exists: $path"}
$branch=(git branch --show-current).Trim();Assert-True ($branch-eq'codex/fiducial-opencv-d-drive') 'O3K1 publisher branch changed.'
$status=@(git status --porcelain);Assert-True ($status.Count-eq0) 'O3K1 publisher requires a clean worktree.'
$local=(git rev-parse HEAD).Trim();$remote=(git rev-parse origin/codex/fiducial-opencv-d-drive).Trim();Assert-True ($local-eq$remote) 'O3K1 publisher requires matching local and remote tips.'
if($Preflight){[ordered]@{schema='argos_o3k1_render_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_RENDER_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha;branch=$branch;commit=$local;displayRoot=$expectedDisplayRoot;share=$requestShare;zeroPending=$true;destinationAbsent=$true;requestRetryAuthorized=$false;mutationsPerformed=$false;gatewayAcceptanceIsExecutionEvidence=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}
Copy-Item -LiteralPath $zip -Destination $upload -ErrorAction Stop
Assert-True ((Get-Sha $upload)-eq$expectedZipSha) 'O3K1 upload hash changed.'
Move-Item -LiteralPath $upload -Destination $destination -ErrorAction Stop
Assert-True ((Get-Sha $destination)-eq$expectedZipSha) 'O3K1 published hash changed.'
$gate=[ordered]@{schema='argos_o3k1_render_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_RENDER_REQUEST_PUBLISHED_ONCE';requestId=$requestId;requestZipSha256=$expectedZipSha;destination=$destination;destinationSha256=Get-Sha $destination;branch=$branch;commit=$local;publicationCount=1;requestRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $publicationGate $gate
$gate|ConvertTo-Json -Depth 10
