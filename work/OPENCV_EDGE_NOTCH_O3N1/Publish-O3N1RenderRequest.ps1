#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InvocationManifest,[switch]$Preflight,[switch]$Publish)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Hash,[string]$State){Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3N1 publisher dependency absent: $Path";Assert-True ((Get-Sha $Path)-eq$Hash) "O3N1 publisher dependency changed: $Path";$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;Assert-True ([string]$value.state-eq$State) "O3N1 publisher gate state changed: $Path"}
function Write-NewJson([string]$Path,[object]$Value){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3N1 publication gate exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 10)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
$expectedInvocationPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_PUBLISH_INVOCATION.json'))
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3N1 publish invocation path changed.'
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True ([string]$invocation.schema-eq'argos_o3n1_publish_invocation_v1'-and[string]$invocation.state-eq'FROZEN_EXACT_PUBLISH_INVOCATION') 'O3N1 publish invocation state changed.'
Assert-True ([string]$invocation.powerShellScriptSha256-eq(Get-Sha $PSCommandPath)) 'O3N1 invocation does not pin the exact publisher.'
Assert-True ([string]$invocation.requestId-eq'REQ_20260827T231500111Z_62629419O3N1'-and[int]$invocation.maximumPublicationsAuthorized-eq1-and-not[bool]$invocation.requestRetryAuthorized) 'O3N1 publish authority changed.'

$requestId='REQ_20260827T231500111Z_62629419O3N1'
$zipName=$requestId+'.ready.zip'
$zip=Join-Path $PSScriptRoot ('final_render\'+$zipName)
$expectedZipSha='76BA22E074ADE5DF0D2B14CBB2C7937EA7E25DBEC3A1D552B923834C1BF12FAE'
$routeGate=Join-Path $PSScriptRoot 'O3N1_COMPLETE_ROUTE_GATE.json'
$packageGate=Join-Path $PSScriptRoot 'O3N1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$shareObservation=Join-Path $PSScriptRoot 'O3N1_CURRENT_SHARE_OBSERVATION.json'
$publicationGate=Join-Path $PSScriptRoot 'O3N1_RENDER_PUBLISH_GATE.json'
$expectedDisplayRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestShare='U:\ProjectPortalRO\requests'
$upload=Join-Path $requestShare ($zipName+'.upload')
$destination=Join-Path $requestShare $zipName
Assert-True (Test-Path -LiteralPath $zip -PathType Leaf) 'O3N1 request ZIP is absent.'
Assert-True ((Get-Sha $zip)-eq$expectedZipSha) 'O3N1 request ZIP changed.'
Assert-Pin $routeGate 'C46F4C24150E4799A373224DF421A8A08872FC7921309F8F9DD87C033C86E94D' 'PASS_O3N1_COMPLETE_ROUTE_GATE'
Assert-Pin $packageGate '5AFFED3580C93D1ACC97CDB6AF1D5CCA58D9673A132A1350DB83AC4F09844BBB' 'PASS_O3N1_EXACT_PACKAGE_REHEARSAL'
Assert-Pin $shareObservation '11F82CC0D11243CD4CBBEDA67BF020049E8AF5CAC852F34C88EA06CAF88DAA2D' 'PASS_O3N1_CURRENT_SHARE_ZERO_PENDING_REQUESTS'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ([string]$drive.DisplayRoot-eq$expectedDisplayRoot) 'O3N1 persistent U: mapping changed.'
Assert-True (Test-Path -LiteralPath $requestShare -PathType Container) 'O3N1 request share is unavailable.'
Assert-True (@(Get-ChildItem -LiteralPath $requestShare -File -ErrorAction Stop).Count-eq0) 'O3N1 request share is not zero-pending.'
foreach($path in @($upload,$destination,$publicationGate)){Assert-True (-not(Test-Path -LiteralPath $path)) "O3N1 publication target exists: $path"}
$branch=(git branch --show-current).Trim();Assert-True ($branch-eq'codex/fiducial-opencv-d-drive') 'O3N1 publisher branch changed.'
$status=@(git status --porcelain);Assert-True ($status.Count-eq0) 'O3N1 publisher requires a clean worktree.'
$local=(git rev-parse HEAD).Trim();$remote=(git rev-parse origin/codex/fiducial-opencv-d-drive).Trim();Assert-True ($local-eq$remote) 'O3N1 publisher requires matching local and remote tips.'
if($Preflight){[ordered]@{schema='argos_o3n1_render_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_RENDER_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZipSha;branch=$branch;commit=$local;displayRoot=$expectedDisplayRoot;share=$requestShare;zeroPending=$true;destinationAbsent=$true;requestRetryAuthorized=$false;mutationsPerformed=$false;gatewayAcceptanceIsExecutionEvidence=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}
Copy-Item -LiteralPath $zip -Destination $upload -ErrorAction Stop
Assert-True ((Get-Sha $upload)-eq$expectedZipSha) 'O3N1 upload hash changed.'
Move-Item -LiteralPath $upload -Destination $destination -ErrorAction Stop
Assert-True ((Get-Sha $destination)-eq$expectedZipSha) 'O3N1 published hash changed.'
$gate=[ordered]@{schema='argos_o3n1_render_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_RENDER_REQUEST_PUBLISHED_ONCE';requestId=$requestId;requestZipSha256=$expectedZipSha;destination=$destination;destinationSha256=Get-Sha $destination;branch=$branch;commit=$local;publicationCount=1;requestRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $publicationGate $gate
$gate|ConvertTo-Json -Depth 10
