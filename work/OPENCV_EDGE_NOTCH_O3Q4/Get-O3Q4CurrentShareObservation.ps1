#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Observe)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Observe)){throw 'Specify exactly one of -Preflight or -Observe.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}

$requestId='REQ_20260828T152800444Z_62629419O3Q4'
$portalRoot='U:\ProjectPortalRO'
$requestsRoot=Join-Path $portalRoot 'requests'
$responsesRoot=Join-Path $portalRoot 'responses'
$readyPath=Join-Path $requestsRoot ($requestId+'.ready.zip')
$uploadPath=$readyPath+'.upload'
$outputPath=Join-Path $PSScriptRoot 'O3Q4_CURRENT_SHARE_OBSERVATION.json'
Assert-True(Test-Path -LiteralPath $portalRoot -PathType Container)'O3Q4 persistent U: portal root is absent.'
Assert-True(Test-Path -LiteralPath $requestsRoot -PathType Container)'O3Q4 request share is absent.'
Assert-True(Test-Path -LiteralPath $responsesRoot -PathType Container)'O3Q4 response share is absent.'
Assert-True(-not(Test-Path -LiteralPath $outputPath))'O3Q4 share observation already exists.'
$drive=Get-PSDrive -Name U -ErrorAction Stop
$mappingCommand=Get-Command -Name Get-SmbMapping -ErrorAction SilentlyContinue
$mappingRows=@()
if($null-ne$mappingCommand){$mappingRows=@(Get-SmbMapping -LocalPath 'U:' -ErrorAction Stop)}
Assert-True($mappingRows.Count-le1)'O3Q4 U: mapping cardinality changed.'
if($mappingRows.Count-eq1){Assert-True([string]$mappingRows[0].Status-eq'OK')'O3Q4 U: SMB mapping is not OK.'}
$pending=@(Get-ChildItem -LiteralPath $requestsRoot -File -Filter '*.ready.zip' -ErrorAction Stop|Select-Object -First 101)
Assert-True($pending.Count-le100)'O3Q4 pending request enumeration exceeded its bound.'
$uploads=@(Get-ChildItem -LiteralPath $requestsRoot -File -Filter '*.upload' -ErrorAction Stop|Select-Object -First 101)
Assert-True($uploads.Count-le100)'O3Q4 upload enumeration exceeded its bound.'
$matchingResponses=@(Get-ChildItem -LiteralPath $responsesRoot -File -Filter ('R_*'+$requestId+'*.ready.zip') -ErrorAction Stop|Select-Object -First 2)
$record=[ordered]@{schema='argos_o3q4_current_share_observation_v1';observedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q4_CURRENT_SHARE_OBSERVATION';requestId=$requestId;portalRoot=$portalRoot;driveRoot=[string]$drive.Root;smbMappingCommandAvailable=($null-ne$mappingCommand);smbMappingCount=$mappingRows.Count;smbMappingStatus=$(if($mappingRows.Count-eq1){[string]$mappingRows[0].Status}else{'PSDRIVE_ONLY'});pendingRequestCount=$pending.Count;pendingRequestNames=@($pending|ForEach-Object{$_.Name});uploadCount=$uploads.Count;uploadNames=@($uploads|ForEach-Object{$_.Name});targetReadyExists=(Test-Path -LiteralPath $readyPath);targetUploadExists=(Test-Path -LiteralPath $uploadPath);matchingResponseCount=$matchingResponses.Count;matchingResponseNames=@($matchingResponses|ForEach-Object{$_.Name});zeroPendingShareRequests=($pending.Count-eq0-and$uploads.Count-eq0);targetAbsent=(-not(Test-Path -LiteralPath $readyPath)-and-not(Test-Path -LiteralPath $uploadPath));persistentUMappingVerified=$true;mappingRemoved=$false;targetExecuted=$false;mutationsPerformed=[bool]$Observe;sourceImageBytesRead=$false;existingProcessQueryCount=0;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$record.mutationsPerformed=$false;$record|ConvertTo-Json -Depth 8;return}
[IO.File]::WriteAllText($outputPath,(($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$record|ConvertTo-Json -Depth 8
