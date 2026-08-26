#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260826T015418549Z_F5D3732576F9'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$finalGatePath = Join-Path $PSScriptRoot 'O2D10_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'O2D10_COMPLETE_ROUTE_GATE_R2.json'
$aliasGatePath = Join-Path $PSScriptRoot 'O2D10_INSPECTIONREVS_U_ALIAS_GATE.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV02_O2D10_COMPLETE_ROUTE_PASS_PUBLICATION_READY_CHECKPOINT_20260826.md'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'O2D10_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$expectedZipSha256 = '289276329B5C2A34F8155C33001747034ACB85CC89B16EBB630D9E4F6FC87256'
$expectedZipBytes = 19249
$expectedFinalGateSha256 = 'CA653F6FA44F0282F52B56DC4B8D158FFFD1AC638AD271A85FD4C43929F98D50'
$expectedRouteGateSha256 = '6938DC3E37A5208DC1F3E2F8F7A5703CC9A6B70B7533556E584F531DCD310D81'
$expectedAliasGateSha256 = 'CACBDAE6B4480B52E5323024D7E88D78D0B3F2BA24992F38F633984CC8AA6A21'
$expectedCheckpointSha256 = 'F9C67D1E1E91B1BBF79ADD94192D96135DC654D54D45D37395A3B8E080D2CC55'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D10 publication dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D10 publication dependency changed: $Path"
}

function Normalize-Root([string]$Path) {
    return $Path.Replace('/', '\').TrimEnd('\')
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 12) {
    $jsonBytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($jsonBytes, 0, $jsonBytes.Length) }
    finally { $stream.Dispose() }
}

Assert-Pin $sourceZip $expectedZipSha256
Assert-Pin $finalGatePath $expectedFinalGateSha256
Assert-Pin $routeGatePath $expectedRouteGateSha256
Assert-Pin $aliasGatePath $expectedAliasGateSha256
Assert-Pin $checkpointPath $expectedCheckpointSha256
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'O2D10 frozen ZIP byte count changed.'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'O2D10 path-budget guard is absent.'

$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
$aliasGate = Get-Content -Raw -LiteralPath $aliasGatePath | ConvertFrom-Json
$continuity = Get-Content -Raw -LiteralPath $continuityPath | ConvertFrom-Json
$migration = $continuity.openCvAllImageProcessingMigration

Assert-True ([string]$finalGate.state -eq 'PASS_O2D10_FINAL_PACKAGE_GATE') 'O2D10 final-package state changed.'
Assert-True ([string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $expectedZipSha256 -and [int64]$finalGate.requestZipBytes -eq $expectedZipBytes) 'O2D10 final-package identity changed.'
Assert-True ([bool]$finalGate.exactFinalZipExtractionPassed -and [bool]$finalGate.exactFinalZipSignaturePassed -and [bool]$finalGate.publicationRequiresCompleteRouteGate -and -not [bool]$finalGate.publicationAuthorized) 'O2D10 frozen package contract changed.'
Assert-True ([bool]$finalGate.reviewOnly -and -not [bool]$finalGate.productionRoutingEnabled -and -not [bool]$finalGate.providerActivated -and -not [bool]$finalGate.targetExecuted) 'O2D10 frozen package authority widened.'

Assert-True ([string]$routeGate.state -eq 'PASS_O2D10_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId) 'O2D10 route gate changed.'
Assert-True ([string]$routeGate.requestZipSha256 -eq $expectedZipSha256 -and [string]$routeGate.finalPackageGateSha256 -eq $expectedFinalGateSha256) 'O2D10 route/package pins diverged.'
Assert-True ([bool]$routeGate.publicationAuthorized -and [int]$routeGate.createNewPublicationMaximum -eq 1 -and -not [bool]$routeGate.retryAuthorized) 'O2D10 route publication authority changed.'
Assert-True ([int]$routeGate.unresolvedEarlierAcceptedRequestCount -eq 0 -and [bool]$routeGate.argosInboundRelayCurrentHealthProved -and [int]$routeGate.toJbodPendingAfterCount -eq 0) 'O2D10 route is not terminally clear.'
Assert-True ([bool]$routeGate.reviewOnly -and -not [bool]$routeGate.productionRoutingEnabled -and -not [bool]$routeGate.providerActivated -and -not [bool]$routeGate.targetExecuted) 'O2D10 route authority widened.'

Assert-True ([string]$aliasGate.state -eq 'PASS_O2D10_EXACT_INSPECTIONREVS_U_ALIAS_GATE' -and [bool]$aliasGate.aliasResolvedExact -and [bool]$aliasGate.requestsRootReadable) 'O2D10 alias gate changed.'
Assert-True ([string]$aliasGate.aliasPathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$aliasGate.aliasTargetEffectiveLength -lt 200 -and [int]$aliasGate.aliasUploadEffectiveLength -lt 200) 'O2D10 alias path gate is not safe.'
Assert-True (-not [bool]$aliasGate.publicationPerformed -and [bool]$aliasGate.targetAbsentAtGate -and [bool]$aliasGate.uploadAbsentAtGate) 'O2D10 alias gate lifecycle changed.'
Assert-True ((Normalize-Root ([string]$aliasGate.aliasRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O2D10 alias gate root changed.'

Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2D10_COMPLETE_ROUTE_PASS_PUBLICATION_READY') 'O2D10 continuity phase changed.'
Assert-True ([string]$migration.ocv02O2D10RequestId -eq $requestId -and [string]$migration.ocv02O2D10FinalZipSha256 -eq $expectedZipSha256) 'O2D10 continuity request identity changed.'
Assert-True ([string]$migration.ocv02O2D10CompleteRouteGateSha256 -eq $expectedRouteGateSha256 -and [string]$migration.ocv02O2D10PublicationAliasGateSha256 -eq $expectedAliasGateSha256) 'O2D10 continuity route pins changed.'
Assert-True ([bool]$migration.ocv02O2D10PublicationAuthorized -and -not [bool]$migration.ocv02O2D10RetryAuthorized -and -not [bool]$migration.ocv02O2D10Published -and -not [bool]$migration.ocv02O2D10ExecutedOnJbod) 'O2D10 continuity publication lifecycle changed.'
Assert-True (-not [bool]$migration.ocv02O2D10Slot16Frozen -and -not [bool]$migration.ocv02O2D10Slot17Started -and [bool]$migration.ocv02O2D10ReferenceCoverageHoldPreserved) 'O2D10 continuity holds changed.'
Assert-True (-not [bool]$continuity.productionEligible -and -not [bool]$continuity.xmlEligible -and -not [bool]$continuity.trainingEligible) 'O2D10 continuity authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'O2D10 publication requires matching local/origin branch tips.'

$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'U: PowerShell mapping does not target the exact InspectionRevs root.'
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logicalDisk -and [int]$logicalDisk.DriveType -eq 4) 'U: is not a persistent Windows network-drive mapping.'
Assert-True ((Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'U: operating-system mapping does not target the exact InspectionRevs root.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'O2D10 request share is unavailable through persistent U:.'

$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('O2D10 another portal request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D10 create-new publication target exists: $path"
}

$pathGate = & $pathTool -CandidatePath @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D10 exact publication path gate failed: $($pathGate.state)"

$worktreeRows = @(& git -C $project status --porcelain=v1)
$preflightResult = [ordered]@{
    schema = 'argos_o2d10_publish_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D10_PUBLISH_PREFLIGHT'
    requestId = $requestId
    sourceZipSha256 = $expectedZipSha256
    sourceZipBytes = $expectedZipBytes
    finalGateSha256 = $expectedFinalGateSha256
    completeRouteGateSha256 = $expectedRouteGateSha256
    aliasGateSha256 = $expectedAliasGateSha256
    branch = $branch
    localTip = $localTip
    remoteTip = $remoteTip
    worktreeRowCount = $worktreeRows.Count
    unresolvedEarlierAcceptedRequestCount = 0
    pendingShareRequestCount = 0
    persistentUMapping = $true
    persistentUMappingRoot = $shareRoot
    persistentUMappingRemovalAuthorized = $false
    targetAndUploadAbsent = $true
    pathState = [string]$pathGate.state
    mutationsPerformed = $false
    jbodContacted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 10
    return
}

$uploadCreated = $false
try {
    [IO.File]::Copy($sourceZip, $uploadPath, $false)
    $uploadCreated = $true
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256) 'O2D10 uploaded request ZIP changed.'
    [IO.File]::Move($uploadPath, $readyPath)
    $uploadCreated = $false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha256) 'O2D10 published request ZIP changed.'

    $result = [ordered]@{
        schema = 'argos_o2d10_publish_gate_v1'
        publishedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D10_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'
        disposition = 'PENDING_GATE'
        requestId = $requestId
        sourceZip = $sourceZip
        publishedPath = $readyPath
        bytes = $expectedZipBytes
        sha256 = $expectedZipSha256
        finalGateSha256 = $expectedFinalGateSha256
        completeRouteGateSha256 = $expectedRouteGateSha256
        aliasGateSha256 = $expectedAliasGateSha256
        branch = $branch
        localTip = $localTip
        remoteTip = $remoteTip
        createNew = $true
        overwritePerformed = $false
        persistentUMapping = $true
        persistentUMappingRoot = $shareRoot
        persistentUMappingLeftInPlace = $true
        persistentUMappingRemoved = $false
        pathState = [string]$pathGate.state
        sourceDeletionPerformed = $false
        retryAuthorized = $false
        matchingSignedTerminalResponseCollectionOnly = $true
        inspectionTasksChanged = $false
        healthyProcessorTouched = $false
        currentWaferAborted = $false
        providerActivated = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-JsonCreateNew -Path $publishGatePath -Value $result -Depth 12
    $result | ConvertTo-Json -Depth 12
}
catch {
    if ($uploadCreated -and -not (Test-Path -LiteralPath $readyPath) -and (Test-Path -LiteralPath $uploadPath -PathType Leaf)) {
        if ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256) {
            [IO.File]::Delete($uploadPath)
        }
    }
    throw
}
