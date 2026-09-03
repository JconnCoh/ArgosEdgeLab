#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Observe)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Observe)){throw 'Specify exactly one of -Preflight or -Observe.'}
function Assert-O3F9([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-O3F9Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Write-O3F9Json([string]$Path,[object]$Value){Assert-O3F9 (-not(Test-Path -LiteralPath $Path)) "O3F9 share observation exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
$expected='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-O3F9 ([string]$drive.DisplayRoot-eq$expected-and[string]$disk.ProviderName-eq$expected-and[int]$disk.DriveType-eq4) 'O3F9 persistent U: mapping changed.'
$requestRoot='U:\ProjectPortalRO\requests';$responseRoot='U:\ProjectPortalRO\responses'
Assert-O3F9 (Test-Path -LiteralPath $requestRoot -PathType Container) 'O3F9 request share is unavailable.'
Assert-O3F9 (Test-Path -LiteralPath $responseRoot -PathType Container) 'O3F9 response share is unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop)
Assert-O3F9 ($pending.Count-eq0) 'O3F9 request share is not zero-pending.'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$launchGate=Join-Path $project 'work\O3B21\R32C953L1_SIGNED_TERMINAL_LAUNCH_GATE.json';$launchHash='3DADD29689FA30DC107599D16FA4B0E3E0BF44BD701616FC3DF0E8DAD877ADD2'
$checkpoint=Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3F6_R8_FULL_978_COMPLETE_STITCH_HOLDER_REVIEW_PENDING_CHECKPOINT_20260902.md';$checkpointHash='FB1FD87FB338158C71469BE9F92B8081756146BA3869C8A8193FB3A8C3FCF746'
Assert-O3F9 ((Get-O3F9Hash $launchGate)-eq$launchHash-and(Get-O3F9Hash $checkpoint)-eq$checkpointHash) 'O3F9 prior accepted-request closure evidence changed.'
$result=[ordered]@{schema='argos_ocv03_o3f9_current_share_observation_v1';state='PASS_O3F9_CURRENT_SHARE_ZERO_PENDING_REQUESTS';displayRoot=$expected;logicalDiskProvider=[string]$disk.ProviderName;driveType=[int]$disk.DriveType;pendingRequestCount=0;unresolvedAcceptedRequestCount=0;acceptedRequestClosureEvidence=@([ordered]@{path='work/O3B21/R32C953L1_SIGNED_TERMINAL_LAUNCH_GATE.json';sha256=$launchHash},[ordered]@{path='work/FRONTSIDE_INSPECTION_REVIEW_ONLY/OCV03_O3F6_R8_FULL_978_COMPLETE_STITCH_HOLDER_REVIEW_PENDING_CHECKPOINT_20260902.md';sha256=$checkpointHash});mutationsPerformed=$false;mappingChanged=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result.state='PASS_O3F9_CURRENT_SHARE_OBSERVATION_PREFLIGHT';$result|ConvertTo-Json -Depth 8;return}
Write-O3F9Json (Join-Path $PSScriptRoot 'O3F9_CURRENT_SHARE_OBSERVATION.json') $result
$result|ConvertTo-Json -Depth 8
