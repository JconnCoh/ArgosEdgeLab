#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Publish)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if([bool]$Preflight -eq [bool]$Publish){throw 'Specify exactly one mode.'}
function Assert-O3B8([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Get-Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Normalize-Root([string]$Path){$Path.Replace('/','\').TrimEnd('\')}
function Write-NewJson([string]$Path,[object]$Value){
  $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 8)+[Environment]::NewLine))
  $stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_O3B8_20260828A'
$zip=Join-Path $PSScriptRoot ('final\'+$requestId+'.ready.zip')
$zipHash='BED3E048D6AFF6330A68A7EF3493353E9F954DD737BFEA5925331D63E25CE327'
$zipBytes=12622
$rehearsal=Join-Path $PSScriptRoot 'O3B8_EXACT_PACKAGE_REHEARSAL_GATE.json'
$rehearsalHash='A06612B9142FAE4AF45B4AA44490EFEBC2C5A39C98712975B1DF2DFDA6A03B17'
$authorization=Join-Path $PSScriptRoot 'O3B8_PUBLICATION_AUTHORIZATION.json'
$share='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot='U:\ProjectPortalRO\requests'
$ready=Join-Path $requestRoot ($requestId+'.ready.zip')
$upload=$ready+'.upload'
$processed=Join-Path (Join-Path $requestRoot 'processed') ($requestId+'.ready.zip')
$out=Join-Path $PSScriptRoot 'O3B8_PUBLISH_GATE.json'
Assert-O3B8 ((Test-Path -LiteralPath $zip -PathType Leaf) -and (Get-Sha $zip) -eq $zipHash -and (Get-Item -LiteralPath $zip).Length -eq $zipBytes) 'O3B8 ZIP changed.'
Assert-O3B8 ((Test-Path -LiteralPath $rehearsal -PathType Leaf) -and (Get-Sha $rehearsal) -eq $rehearsalHash) 'O3B8 exact-package rehearsal gate changed.'
$gate=Get-Content -LiteralPath $rehearsal -Raw|ConvertFrom-Json
Assert-O3B8 ([string]$gate.state -eq 'PASS_O3B8_EXACT_PACKAGE_REHEARSAL' -and [string]$gate.requestId -eq $requestId -and [bool]$gate.signatureVerified) 'O3B8 exact-package rehearsal gate invalid.'
$auth=Get-Content -LiteralPath $authorization -Raw|ConvertFrom-Json
Assert-O3B8 ([string]$auth.state -eq 'AUTHORIZED_ONE_O3B8_PUBLICATION_NO_RETRY' -and [string]$auth.requestId -eq $requestId -and [int]$auth.maximumPublications -eq 1 -and -not [bool]$auth.retryAuthorized) 'O3B8 publication authorization invalid.'
$branch='codex/fiducial-opencv-d-drive'
$local=(& git -C $project rev-parse HEAD|Out-String).Trim()
$remote=(& git -C $project rev-parse ('origin/'+$branch)|Out-String).Trim()
Assert-O3B8 ((& git -C $project branch --show-current|Out-String).Trim() -eq $branch -and $local -eq $remote) 'O3B8 branch mismatch.'
Assert-O3B8 (@(& git -C $project status --porcelain=v1).Count -eq 0) 'O3B8 worktree dirty.'
$drive=Get-PSDrive U -PSProvider FileSystem -ErrorAction Stop
$logical=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Assert-O3B8 ((Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $share),[StringComparison]::OrdinalIgnoreCase) -and [int]$logical.DriveType -eq 4 -and (Normalize-Root ([string]$logical.ProviderName)).Equals((Normalize-Root $share),[StringComparison]::OrdinalIgnoreCase)) 'O3B8 persistent U mapping changed.'
Assert-O3B8 (@(Get-ChildItem -LiteralPath $requestRoot -File -Force|Where-Object{$_.Name -match '\.ready\.zip(\.upload)?$'}).Count -eq 0) 'Another portal request is pending.'
foreach($path in @($ready,$upload,$processed,$out)){Assert-O3B8 (-not (Test-Path -LiteralPath $path)) "O3B8 create-new publication target exists: $path"}
$result=[ordered]@{schema='argos_ocv03_o3b8_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=if($Preflight){'PASS_O3B8_PUBLISH_PREFLIGHT'}else{'PASS_O3B8_EXACT_REQUEST_PUBLISHED_CREATE_NEW'};requestId=$requestId;zipSha256=$zipHash;zipBytes=$zipBytes;exactPackageRehearsalSha256=$rehearsalHash;localTip=$local;remoteTip=$remote;pendingRequestCount=0;persistentUMappingVerified=$true;maximumPublications=1;retryAuthorized=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrExistingProcessActionPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result|ConvertTo-Json -Depth 6;return}
[IO.File]::Copy($zip,$upload,$false)
Assert-O3B8 ((Get-Sha $upload) -eq $zipHash) 'O3B8 upload changed.'
[IO.File]::Move($upload,$ready)
Assert-O3B8 ((Get-Sha $ready) -eq $zipHash) 'O3B8 ready changed.'
$result.publishedPath=$ready
Write-NewJson $out $result
$result|ConvertTo-Json -Depth 6
