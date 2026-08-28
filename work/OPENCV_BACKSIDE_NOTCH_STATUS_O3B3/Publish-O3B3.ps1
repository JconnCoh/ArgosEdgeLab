#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Publish) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Write-NewJson([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Normalize-Root([string]$Path) { return $Path.Replace('/', '\').TrimEnd('\') }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_O3B3'
$branch = 'codex/fiducial-opencv-d-drive'
$zipSha = '9CD28F3E60B7B949D676419E61015CDB83BDD056FBC8AEE2B5B8C2FFAD8104E6'
$zipBytes = 15867
$checkpointSha = '7006C828396C881FC8AB7599F6248D7BC73C2B558E9601FA48741848047EF2A1'
$finalGateSha = '10AD736B1F4F57705B7375055AF4CC12BEC2CE35DAD8412CFFE7A3131DCB6EF4'
$sourceZip = Join-Path $PSScriptRoot 'final\REQ_O3B3.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'final\REQ_O3B3.ready.zip.gate.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3B3_BACKSIDE_METADATA_CAPABILITY_PROMOTED_LOCAL_20260828.md'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'O3B3_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = Join-Path $requestRoot 'REQ_O3B3.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') 'REQ_O3B3.ready.zip'

foreach ($pin in @(@($sourceZip, $zipSha), @($finalGatePath, $finalGateSha), @($checkpointPath, $checkpointSha))) {
    Assert-True (Test-Path -LiteralPath $pin[0] -PathType Leaf) "O3B3 dependency absent: $($pin[0])"
    Assert-True ((Get-Sha256 $pin[0]) -eq $pin[1]) "O3B3 dependency changed: $($pin[0])"
}
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $zipBytes) 'O3B3 ZIP byte count changed.'
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_O3B3_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $zipSha -and [bool]$finalGate.signatureVerified -and [bool]$finalGate.exactZipExtractionPassed) 'O3B3 final package gate changed.'
$continuity = Get-Content -LiteralPath $continuityPath -Raw | ConvertFrom-Json
$capability = $continuity.ocv03O3B3BacksideMetadataCapability
Assert-True ([string]$continuity.activePhase -eq 'OCV03_O3B3_BACKSIDE_METADATA_CAPABILITY_PROMOTED_LOCAL' -and [string]$continuity.currentPhaseCheckpointSha256 -eq $checkpointSha) 'O3B3 continuity phase changed.'
Assert-True ([string]$capability.requestId -eq $requestId -and [string]$capability.requestZipSha256 -eq $zipSha -and [bool]$capability.publicationAuthorized -and -not [bool]$capability.liveRequestPerformed -and -not [bool]$capability.requestRetryAuthorized) 'O3B3 publication authority changed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'O3B3 requires matching local/origin branch tips.'
Assert-True (@(& git -C $project status --porcelain=v1).Count -eq 0) 'O3B3 requires a clean worktree.'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O3B3 PowerShell U: mapping changed.'
Assert-True ([int]$logical.DriveType -eq 4 -and (Normalize-Root ([string]$logical.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O3B3 logical U: mapping changed.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -Force | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('O3B3 another request is pending: ' + (($pending | ForEach-Object Name) -join ', '))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O3B3 create-new target exists: $path" }
$pathGate = & $pathTool -CandidatePath @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3B3 publication path gate failed.'

$record = [ordered]@{
    schema='argos_o3b3_publish_gate_v1'; checkedUtc=[DateTime]::UtcNow.ToString('o'); state=if($Preflight){'PASS_O3B3_PUBLISH_PREFLIGHT'}else{'PASS_O3B3_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'}
    requestId=$requestId; sourceZipSha256=$zipSha; sourceZipBytes=$zipBytes; branch=$branch; localTip=$localTip; remoteTip=$remoteTip; tipsMatch=$true
    pendingRequestCount=0; persistentUMappingVerified=$true; createNew=$true; overwritePerformed=$false; maximumPublications=1; retryAuthorized=$false
    matchingSignedTerminalResponseOnly=$true; gatewayAcceptanceIsExecutionEvidence=$false; taskActions=0; processActions=0; imageBytesRead=$false
    sourceHashingPerformed=$false; sourceMutationPerformed=$false; sourceDeletionPerformed=$false; protectedProcessorTouched=$false; providerActivated=$false
    thresholdOrAlgorithmChanged=$false; holdsCleared=$false; reviewOnly=$true; trainingEligible=$false; xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false
}
if ($Preflight) { $record | ConvertTo-Json -Depth 10; return }

[IO.File]::Copy($sourceZip, $uploadPath, $false)
Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $zipBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'O3B3 upload copy changed.'
[IO.File]::Move($uploadPath, $readyPath)
Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $zipBytes -and (Get-Sha256 $readyPath) -eq $zipSha) 'O3B3 published ZIP changed.'
$record.publishedPath = $readyPath
$record.persistentUMappingLeftInPlace = $true
Write-NewJson $publishGatePath $record
$record | ConvertTo-Json -Depth 10
