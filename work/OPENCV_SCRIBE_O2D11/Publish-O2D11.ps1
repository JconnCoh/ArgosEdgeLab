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
$requestId = 'REQ_20260826T193716129Z_9C27A4D18E60'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$finalGatePath = Join-Path $PSScriptRoot 'O2D11_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'O2D11_COMPLETE_ROUTE_GATE_R2.json'
$aliasGatePath = Join-Path $PSScriptRoot 'O2D11_INSPECTIONREVS_U_ALIAS_GATE.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV02_O2D11_COMPLETE_ROUTE_PASS_PUBLICATION_READY_CHECKPOINT_20260826.md'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'O2D11_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$expectedZipSha256 = 'FD777711DD5A12583DB711924818A055711D6049DA9CD56122DE41A0212E7D67'
$expectedZipBytes = 19345
$expectedFinalGateSha256 = '13AA46A62E3637FB979B157AB187DBBE44012A568D81F116339A1785C7655F4B'
$expectedRouteGateSha256 = 'C0C1603C98AB5061BE89468AA4B7615D0908B0A33E46C44C6C03142069201033'
$expectedAliasGateSha256 = '4EA29188BB4E311373C637BE8CB897A4007D1774F4DC550F45F7153623D31D5F'
$expectedCheckpointSha256 = 'A7C7E6D1E5E5453A3F9D94E66D072587785ADC1C5788B3919A69063D254E212A'
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
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D11 publication dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D11 publication dependency changed: $Path"
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
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'O2D11 frozen ZIP byte count changed.'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'O2D11 path-budget guard is absent.'

$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
$aliasGate = Get-Content -Raw -LiteralPath $aliasGatePath | ConvertFrom-Json
$continuity = Get-Content -Raw -LiteralPath $continuityPath | ConvertFrom-Json
$migration = $continuity.openCvAllImageProcessingMigration

Assert-True ([string]$finalGate.state -eq 'PASS_O2D11_FINAL_PACKAGE_GATE') 'O2D11 final-package state changed.'
Assert-True ([string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $expectedZipSha256 -and [int64]$finalGate.requestZipBytes -eq $expectedZipBytes) 'O2D11 final-package identity changed.'
Assert-True ([bool]$finalGate.exactFinalZipExtractionPassed -and [bool]$finalGate.exactFinalZipSignaturePassed -and [bool]$finalGate.publicationRequiresCompleteRouteGate -and -not [bool]$finalGate.publicationAuthorized) 'O2D11 frozen package contract changed.'
Assert-True ([bool]$finalGate.reviewOnly -and -not [bool]$finalGate.productionRoutingEnabled -and -not [bool]$finalGate.providerActivated -and -not [bool]$finalGate.targetExecuted) 'O2D11 frozen package authority widened.'

Assert-True ([string]$routeGate.state -eq 'PASS_O2D11_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId) 'O2D11 route gate changed.'
Assert-True ([string]$routeGate.requestZipSha256 -eq $expectedZipSha256 -and [string]$routeGate.finalPackageGateSha256 -eq $expectedFinalGateSha256) 'O2D11 route/package pins diverged.'
Assert-True ([bool]$routeGate.publicationAuthorized -and [int]$routeGate.createNewPublicationMaximum -eq 1 -and -not [bool]$routeGate.retryAuthorized) 'O2D11 route publication authority changed.'
Assert-True ([int]$routeGate.unresolvedEarlierAcceptedRequestCount -eq 0 -and [bool]$routeGate.argosInboundRelayCurrentHealthProved -and [int]$routeGate.toJbodPendingAfterCount -eq 0) 'O2D11 route is not terminally clear.'
Assert-True ([bool]$routeGate.reviewOnly -and -not [bool]$routeGate.productionRoutingEnabled -and -not [bool]$routeGate.providerActivated -and -not [bool]$routeGate.targetExecuted) 'O2D11 route authority widened.'

Assert-True ([string]$aliasGate.state -eq 'PASS_O2D11_EXACT_INSPECTIONREVS_U_ALIAS_GATE' -and [bool]$aliasGate.aliasResolvedExact -and [bool]$aliasGate.requestsRootReadable) 'O2D11 alias gate changed.'
Assert-True ([string]$aliasGate.aliasPathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$aliasGate.aliasTargetEffectiveLength -lt 200 -and [int]$aliasGate.aliasUploadEffectiveLength -lt 200) 'O2D11 alias path gate is not safe.'
Assert-True (-not [bool]$aliasGate.publicationPerformed -and [bool]$aliasGate.targetAbsentAtGate -and [bool]$aliasGate.uploadAbsentAtGate) 'O2D11 alias gate lifecycle changed.'
Assert-True ((Normalize-Root ([string]$aliasGate.aliasRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O2D11 alias gate root changed.'

Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2D11_COMPLETE_ROUTE_PASS_PUBLICATION_READY') 'O2D11 continuity phase changed.'
Assert-True ([string]$migration.ocv02O2D11RequestId -eq $requestId -and [string]$migration.ocv02O2D11FinalZipSha256 -eq $expectedZipSha256) 'O2D11 continuity request identity changed.'
Assert-True ([string]$migration.ocv02O2D11CompleteRouteGateSha256 -eq $expectedRouteGateSha256 -and [string]$migration.ocv02O2D11PublicationAliasGateSha256 -eq $expectedAliasGateSha256) 'O2D11 continuity route pins changed.'
Assert-True ([bool]$migration.ocv02O2D11PublicationAuthorized -and -not [bool]$migration.ocv02O2D11RetryAuthorized -and -not [bool]$migration.ocv02O2D11Published -and -not [bool]$migration.ocv02O2D11ExecutedOnJbod) 'O2D11 continuity publication lifecycle changed.'
Assert-True (-not [bool]$migration.ocv02O2D11Slot16Frozen -and -not [bool]$migration.ocv02O2D11Slot17Started -and [bool]$migration.ocv02O2D11ReferenceCoverageHoldPreserved) 'O2D11 continuity holds changed.'
Assert-True (-not [bool]$continuity.productionEligible -and -not [bool]$continuity.xmlEligible -and -not [bool]$continuity.trainingEligible) 'O2D11 continuity authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'O2D11 publication requires matching local/origin branch tips.'

$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'U: PowerShell mapping does not target the exact InspectionRevs root.'
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logicalDisk -and [int]$logicalDisk.DriveType -eq 4) 'U: is not a persistent Windows network-drive mapping.'
Assert-True ((Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'U: operating-system mapping does not target the exact InspectionRevs root.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'O2D11 request share is unavailable through persistent U:.'

$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('O2D11 another portal request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D11 create-new publication target exists: $path"
}

$pathGate = & $pathTool -CandidatePath @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D11 exact publication path gate failed: $($pathGate.state)"

$worktreeRows = @(& git -C $project status --porcelain=v1)
$preflightResult = [ordered]@{
    schema = 'argos_o2d11_publish_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D11_PUBLISH_PREFLIGHT'
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
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256) 'O2D11 uploaded request ZIP changed.'
    [IO.File]::Move($uploadPath, $readyPath)
    $uploadCreated = $false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha256) 'O2D11 published request ZIP changed.'

    $result = [ordered]@{
        schema = 'argos_o2d11_publish_gate_v1'
        publishedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D11_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'
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
