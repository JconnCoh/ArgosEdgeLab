#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3Q4 publisher dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O3Q4 publisher dependency changed: $Path"
}
function Normalize-Root([string]$Path) { return $Path.Replace('/', '\').TrimEnd('\') }
function Write-NewJson([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260828T152800444Z_62629419O3Q4'
$branch = 'codex/fiducial-opencv-d-drive'
$sourceZip = Join-Path $PSScriptRoot ('final_o3q4\' + $requestId + '.ready.zip')
$finalGatePath = Join-Path $PSScriptRoot 'O3Q4_FINAL_PACKAGE_GATE.json'
$rehearsalGatePath = Join-Path $PSScriptRoot 'O3Q4_EXACT_PACKAGE_REHEARSAL_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'O3Q4_COMPLETE_ROUTE_GATE.json'
$shareObservationPath = Join-Path $PSScriptRoot 'O3Q4_CURRENT_SHARE_OBSERVATION.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3Q4_SLOT16_NUMERIC_REQUEST_PUBLISH_READY_20260828.md'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'O3Q4_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')
$zipSha = '648F5F8F278DA6BE3718386E0BC99EC043C41E77E7808101CB2214A5533F96F1'
$zipBytes = 48673
$finalGateSha = '489F1CE44F4EE1EE43891B0DA50C7357B61BBBF41ED107F3D60F64F791DAA2B4'
$rehearsalGateSha = 'EE58430102DB4D7222E9E088829D803C6F1410A67F8BFA4D86CABA1952811F9B'
$routeGateSha = '886FD5E402072CA330BF32CDE7FCD88DA16C1DA38BAA44F0A5BA3C7F20E51155'
$shareObservationSha = '1295F75CF598D3D794740C28760CF6C49DE20F3AADBE7DC5AF71648BB51757DF'
$checkpointSha = 'D2927B22AEECDB2E367AE556ABA4E7E54357D30015B18E47910193B11DB32CAC'
$invocationSha = '2E805966D6D1CA7FCC32695E6F459700443167855ABD5AAFFB73F61B4B3C5F35'

$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-Pin $invocationPath $invocationSha
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3q4_publish_invocation_v1' -and [string]$invocation.publisherRevision -eq 'Publish-O3Q4' -and [string]$invocation.requestId -eq $requestId) 'O3Q4 publisher invocation identity changed.'
Assert-True ([string]$invocation.requestZipSha256 -eq $zipSha -and [string]$invocation.checkpointSha256 -eq $checkpointSha -and [string]$invocation.branch -eq $branch) 'O3Q4 publisher invocation pins changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.matchingSignedResponseCollectionOnly -and [bool]$invocation.requireCleanMatchingBranchTips -and [bool]$invocation.requireZeroPendingShareRequests) 'O3Q4 publisher one-shot boundary changed.'
Assert-True (-not [bool]$invocation.queryExistingProcesses -and [int]$invocation.taskActions -eq 0 -and -not [bool]$invocation.imageBytesRead -and -not [bool]$invocation.sourceMutationPerformed -and -not [bool]$invocation.sourceDeletionPerformed -and -not [bool]$invocation.providerActivated) 'O3Q4 publisher runtime or source authority widened.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3Q4 publisher authority widened.'
foreach ($pin in @(@($sourceZip, $zipSha), @($finalGatePath, $finalGateSha), @($rehearsalGatePath, $rehearsalGateSha), @($routeGatePath, $routeGateSha), @($shareObservationPath, $shareObservationSha), @($checkpointPath, $checkpointSha))) { Assert-Pin $pin[0] $pin[1] }
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $zipBytes) 'O3Q4 ZIP byte count changed.'

$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
$rehearsalGate = Get-Content -LiteralPath $rehearsalGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$shareObservation = Get-Content -LiteralPath $shareObservationPath -Raw | ConvertFrom-Json
$continuity = Get-Content -LiteralPath $continuityPath -Raw | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_O3Q4_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $zipSha -and [bool]$finalGate.maintenanceInstalledShaMatchesPayload -and [bool]$finalGate.exactEndpointPassedLocalNumericRehearsal) 'O3Q4 final package gate changed.'
Assert-True ([string]$rehearsalGate.state -eq 'PASS_O3Q4_EXACT_PACKAGE_REHEARSAL' -and [string]$rehearsalGate.requestId -eq $requestId -and [string]$rehearsalGate.requestZipSha256 -eq $zipSha -and [bool]$rehearsalGate.exactPackagedEndpointPreflightPassed -and [bool]$rehearsalGate.absentPredecessorRefusedBeforeMutation -and [bool]$rehearsalGate.approvedSameHashIdempotentCasePassed -and [bool]$rehearsalGate.unapprovedPredecessorRefusedBeforeMutation -and [bool]$rehearsalGate.ownedChildTimeoutCaptured -and [bool]$rehearsalGate.ownedChildTimeoutKilled) 'O3Q4 exact-package rehearsal changed.'
Assert-True ([string]$routeGate.state -eq 'PASS_O3Q4_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId -and [string]$routeGate.requestZipSha256 -eq $zipSha -and [bool]$routeGate.exactFinalZipExtractionPassed -and [bool]$routeGate.exactFinalZipSignaturePassed -and [bool]$routeGate.allRequestAndResponseHopsEnumerated) 'O3Q4 complete route gate changed.'
Assert-True ([string]$shareObservation.state -eq 'PASS_O3Q4_CURRENT_SHARE_OBSERVATION' -and [bool]$shareObservation.persistentUMappingVerified -and [bool]$shareObservation.zeroPendingShareRequests -and [bool]$shareObservation.targetAbsent) 'O3Q4 current-share observation changed.'
Assert-True ([string]$continuity.activePhase -eq 'OCV03_O3Q4_SLOT16_NUMERIC_REQUEST_PUBLISH_READY' -and [string]$continuity.currentPhaseCheckpointSha256 -eq $checkpointSha) 'O3Q4 continuity phase changed.'
$capability = $continuity.ocv03O3Q4Slot16NumericRequest
Assert-True ([string]$capability.requestId -eq $requestId -and [string]$capability.requestZipSha256 -eq $zipSha -and [bool]$capability.publicationAuthorized -and [int]$capability.maximumPublications -eq 1 -and -not [bool]$capability.retryAuthorized -and -not [bool]$capability.published) 'O3Q4 continuity publication state changed.'
Assert-True ([bool]$continuity.reviewOnly -and -not [bool]$continuity.trainingEligible -and -not [bool]$continuity.xmlEligible -and -not [bool]$continuity.productionEligible) 'O3Q4 continuity authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'O3Q4 publisher requires matching local/origin branch tips.'
$worktree = @(& git -C $project status --porcelain=v1)
Assert-True ($worktree.Count -eq 0) 'O3Q4 publisher requires a clean worktree.'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O3Q4 persistent U: mapping changed.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'O3Q4 request share unavailable.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -Force | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('O3Q4 another request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O3Q4 create-new publication target exists: $path" }
$pathGate = & $pathTool -CandidatePath @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath, $invocationPath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3Q4 publication path gate failed.'

$preflightResult = [ordered]@{
    schema = 'argos_o3q4_publish_preflight_v1'; checkedUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_O3Q4_PUBLISH_PREFLIGHT'; requestId = $requestId
    sourceZipSha256 = $zipSha; sourceZipBytes = $zipBytes; branch = $branch; localTip = $localTip; remoteTip = $remoteTip; tipsMatch = $true
    worktreeRowCount = 0; pendingRequestCount = 0; persistentUMappingVerified = $true; targetAbsent = $true; uploadAbsent = $true
    maximumPublications = 1; retryAuthorized = $false; matchingSignedResponseCollectionOnly = $true; queryExistingProcesses = $false; taskActions = 0
    mutationsPerformed = $false; imageBytesRead = $false; sourceMutationPerformed = $false; sourceDeletionPerformed = $false; providerActivated = $false
    reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 8; return }

[IO.File]::Copy($sourceZip, $uploadPath, $false)
Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $zipBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'O3Q4 upload copy changed.'
[IO.File]::Move($uploadPath, $readyPath)
Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $zipBytes -and (Get-Sha256 $readyPath) -eq $zipSha) 'O3Q4 published ZIP changed.'
$record = [ordered]@{
    schema = 'argos_o3q4_publish_gate_v1'; publishedUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_O3Q4_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'; disposition = 'PENDING_GATE'
    requestId = $requestId; sourceZip = $sourceZip; publishedPath = $readyPath; bytes = $zipBytes; sha256 = $zipSha; branch = $branch; localTip = $localTip; remoteTip = $remoteTip; tipsMatch = $true
    createNew = $true; overwritePerformed = $false; persistentUMappingVerified = $true; persistentUMappingLeftInPlace = $true; maximumPublications = 1; retryAuthorized = $false
    matchingSignedTerminalResponseOnly = $true; gatewayAcceptanceIsExecutionEvidence = $false; queryExistingProcesses = $false; taskActions = 0; imageBytesRead = $false
    sourceMutationPerformed = $false; sourceDeletionPerformed = $false; protectedProcessorTouched = $false; providerActivated = $false; thresholdOrAlgorithmChanged = $false
    reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false
}
Write-NewJson $publishGatePath $record
$record | ConvertTo-Json -Depth 10
