#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Observe)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Observe)){throw 'Specify exactly one of -Preflight or -Observe.'}
function Assert-O3F10([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-O3F10Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Write-O3F10Json([string]$Path,[object]$Value){Assert-O3F10 (-not(Test-Path -LiteralPath $Path)) "O3F10 share observation exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
$expected='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-O3F10 ([string]$drive.DisplayRoot-eq$expected-and[string]$disk.ProviderName-eq$expected-and[int]$disk.DriveType-eq4) 'O3F10 persistent U: mapping changed.'
$requestRoot='U:\ProjectPortalRO\requests';$responseRoot='U:\ProjectPortalRO\responses'
Assert-O3F10 (Test-Path -LiteralPath $requestRoot -PathType Container) 'O3F10 request share is unavailable.'
Assert-O3F10 (Test-Path -LiteralPath $responseRoot -PathType Container) 'O3F10 response share is unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop)
Assert-O3F10 ($pending.Count-eq0) 'O3F10 request share is not zero-pending.'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$o3f9Failure=Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3F9\O3F9_SIGNED_TERMINAL_FAILURE_GATE.json';$o3f9FailureHash='AF2617E0177360D02450E09DE39835804B2F1BC322BA08019B74C0F43821A75F'
$launchGate=Join-Path $project 'work\O3B21\R32C953L1_SIGNED_TERMINAL_LAUNCH_GATE.json';$launchHash='3DADD29689FA30DC107599D16FA4B0E3E0BF44BD701616FC3DF0E8DAD877ADD2'
$checkpoint=Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3F6_R8_FULL_978_COMPLETE_STITCH_HOLDER_REVIEW_PENDING_CHECKPOINT_20260902.md';$checkpointHash='FB1FD87FB338158C71469BE9F92B8081756146BA3869C8A8193FB3A8C3FCF746'
Assert-O3F10 ((Get-O3F10Hash $o3f9Failure)-eq$o3f9FailureHash-and(Get-O3F10Hash $launchGate)-eq$launchHash-and(Get-O3F10Hash $checkpoint)-eq$checkpointHash) 'O3F10 prior accepted-request closure evidence changed.'
$failureValue=Get-Content -LiteralPath $o3f9Failure -Raw|ConvertFrom-Json
Assert-O3F10 ([string]$failureValue.requestId-eq'REQ_O3F9_20260902A'-and[string]$failureValue.responseState-eq'FAILED'-and[bool]$failureValue.signatureVerified-and-not[bool]$failureValue.requestRetryAuthorized) 'O3F10 O3F9 signed terminal closure changed.'
$result=[ordered]@{schema='argos_ocv03_o3f10_current_share_observation_v1';state='PASS_O3F10_CURRENT_SHARE_ZERO_PENDING_REQUESTS';displayRoot=$expected;logicalDiskProvider=[string]$disk.ProviderName;driveType=[int]$disk.DriveType;pendingRequestCount=0;unresolvedAcceptedRequestCount=0;acceptedRequestClosureEvidence=@([ordered]@{path='work/OPENCV_EDGE_NOTCH_O3F9/O3F9_SIGNED_TERMINAL_FAILURE_GATE.json';sha256=$o3f9FailureHash;requestId='REQ_O3F9_20260902A';terminalState='FAILED';signatureVerified=$true},[ordered]@{path='work/O3B21/R32C953L1_SIGNED_TERMINAL_LAUNCH_GATE.json';sha256=$launchHash},[ordered]@{path='work/FRONTSIDE_INSPECTION_REVIEW_ONLY/OCV03_O3F6_R8_FULL_978_COMPLETE_STITCH_HOLDER_REVIEW_PENDING_CHECKPOINT_20260902.md';sha256=$checkpointHash});mutationsPerformed=$false;mappingChanged=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result.state='PASS_O3F10_CURRENT_SHARE_OBSERVATION_PREFLIGHT';$result|ConvertTo-Json -Depth 8;return}
Write-O3F10Json (Join-Path $PSScriptRoot 'O3F10_CURRENT_SHARE_OBSERVATION.json') $result
$result|ConvertTo-Json -Depth 8
