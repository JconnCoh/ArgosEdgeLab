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

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T035500111Z_3C97863DBF26'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$finalGatePath = Join-Path $PSScriptRoot 'O2D23_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'O2D23_COMPLETE_ROUTE_GATE_R3.json'
$aliasGatePath = Join-Path $PSScriptRoot 'O2D23_INSPECTIONREVS_U_ALIAS_GATE.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\O2D23_SLOT25_PUBLISH_READY_20260827.md'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publishGatePath = Join-Path $PSScriptRoot 'O2D23_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$expectedZipSha256 = '8D4E9C9C8C4105B28CF8539942AD182C6E9F237974200C86412D0EBDF67303F0'
$expectedZipBytes = 21412
$expectedFinalGateSha256 = '532CCF66A5BC1ACE7B2C3FBE844D50B876E13F91CEC04C20D953D494604C8B50'
$expectedRouteGateSha256 = '04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3'
$expectedAliasGateSha256 = 'AF134891346B4CE880B9CE19F1D703191332394921DB24D3ACF7A59CF8E05FEF'
$expectedCheckpointSha256 = 'DD833B90A654D2B5DF4029530E11D2E13B4CEEB5D3985D1F8E3761EAE015BD6C'
$expectedEndpointSha256 = '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'
$expectedSelfPinGateSha256 = 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'
$expectedInvocationSha256 = 'B3DF9C619045199E1C58FCAF5A4402F0DB4F3D79CDC016F04D7D3F6C51665943'
$validationQualification = 'INDEPENDENT_VALIDATION_OUTCOME_BLIND_METADATA_DISCLOSED'
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
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D23 publication dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D23 publication dependency changed: $Path"
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

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O2D23 invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-Pin $invocationPath $expectedInvocationSha256
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_publish_invocation_v1') 'O2D23 invocation schema changed.'
Assert-True ([string]$invocation.publisherRevision -eq 'Publish-O2D23' -and [string]$invocation.requestId -eq $requestId -and [string]$invocation.branch -eq $branch) 'O2D23 invocation identity changed.'
Assert-True ([string]$invocation.checkpointPath -eq 'work/FRONTSIDE_INSPECTION_REVIEW_ONLY/O2D23_SLOT25_PUBLISH_READY_20260827.md' -and [string]$invocation.checkpointSha256 -eq $expectedCheckpointSha256) 'O2D23 invocation checkpoint changed.'
Assert-True ([string]$invocation.validationQualification -eq $validationQualification) 'O2D23 validation qualification changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.matchingSignedResponseCollectionOnly -and [bool]$invocation.requireCleanMatchingBranchTips -and [bool]$invocation.requireZeroPendingShareRequests) 'O2D23 invocation publication boundary changed.'
Assert-True ([bool]$invocation.slot25SourceMetadataPrematurelyExposed -and -not [bool]$invocation.slot25ImageBytesRead -and -not [bool]$invocation.slot25OutcomeSeen -and -not [bool]$invocation.slot25WhollyUnseenClaimAllowed) 'O2D23 invocation Slot25 disclosure changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 invocation authority widened.'

Assert-Pin $sourceZip $expectedZipSha256
Assert-Pin $finalGatePath $expectedFinalGateSha256
Assert-Pin $routeGatePath $expectedRouteGateSha256
Assert-Pin $aliasGatePath $expectedAliasGateSha256
Assert-Pin $checkpointPath $expectedCheckpointSha256
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes) 'O2D23 frozen ZIP byte count changed.'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'O2D23 path-budget guard is absent.'

$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
$aliasGate = Get-Content -Raw -LiteralPath $aliasGatePath | ConvertFrom-Json
$continuity = Get-Content -Raw -LiteralPath $continuityPath | ConvertFrom-Json
$migration = $continuity.openCvAllImageProcessingMigration

Assert-True ([string]$finalGate.state -eq 'PASS_O2D23_FINAL_PACKAGE_GATE') 'O2D23 final-package state changed.'
Assert-True ([string]$finalGate.requestId -eq $requestId -and [string]$finalGate.requestZipSha256 -eq $expectedZipSha256 -and [int64]$finalGate.requestZipBytes -eq $expectedZipBytes) 'O2D23 final-package identity changed.'
Assert-True ([bool]$finalGate.exactFinalZipExtractionPassed -and [bool]$finalGate.exactFinalZipSignaturePassed -and [bool]$finalGate.publicationRequiresCompleteRouteGate -and -not [bool]$finalGate.publicationAuthorized) 'O2D23 frozen package contract changed.'
Assert-True ([bool]$finalGate.maintenanceInstalledShaMatchesPayload -and [string]$finalGate.endpointPayloadSha256 -eq $expectedEndpointSha256 -and [string]$finalGate.declaredInstalledSha256 -eq [string]$finalGate.endpointPayloadSha256) 'O2D23 endpoint payload and installed hashes diverged.'
Assert-True ([string]$finalGate.selfPinGateState -eq 'PASS_O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE' -and [string]$finalGate.selfPinGateSha256 -eq $expectedSelfPinGateSha256 -and [int]$finalGate.endpointSelfPinCount -eq 6 -and [int]$finalGate.endpointSelfPinMatchCount -eq 6 -and [int]$finalGate.liveAssertionBranchCaseCount -eq 3) 'O2D23 frozen self-pin proof changed.'
Assert-True ([string]$finalGate.validationQualification -eq $validationQualification -and [bool]$finalGate.slot25SourceMetadataPrematurelyExposed -and -not [bool]$finalGate.slot25ImageBytesRead -and -not [bool]$finalGate.slot25OutcomeSeen) 'O2D23 final-package disclosure changed.'
Assert-True ([bool]$finalGate.reviewOnly -and -not [bool]$finalGate.productionRoutingEnabled -and -not [bool]$finalGate.providerActivated -and -not [bool]$finalGate.targetExecuted -and -not [bool]$finalGate.sourceImageBytesRead) 'O2D23 frozen package authority widened.'

Assert-True ([string]$routeGate.state -eq 'PASS_O2D23_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId) 'O2D23 route gate changed.'
Assert-True ([string]$routeGate.requestZipSha256 -eq $expectedZipSha256 -and [string]$routeGate.finalPackageGateSha256 -eq $expectedFinalGateSha256) 'O2D23 route/package pins diverged.'
Assert-True ([bool]$routeGate.publicationAuthorized -and [int]$routeGate.createNewPublicationMaximum -eq 1 -and -not [bool]$routeGate.retryAuthorized -and [bool]$routeGate.matchingSignedTerminalResponseCollectionOnly) 'O2D23 route publication authority changed.'
Assert-True ([int]$routeGate.unresolvedEarlierAcceptedRequestCount -eq 0 -and [bool]$routeGate.argosInboundRelayCurrentHealthProved -and [int]$routeGate.toJbodPendingAfterCount -eq 0) 'O2D23 route is not terminally clear.'
Assert-True ([string]$routeGate.validationQualification -eq $validationQualification -and [bool]$routeGate.slot25SourceMetadataPrematurelyExposed -and -not [bool]$routeGate.slot25ImageBytesRead -and -not [bool]$routeGate.slot25OutcomeSeen) 'O2D23 route disclosure changed.'
Assert-True ([bool]$routeGate.reviewOnly -and -not [bool]$routeGate.productionRoutingEnabled -and -not [bool]$routeGate.providerActivated -and -not [bool]$routeGate.targetExecuted -and -not [bool]$routeGate.targetMutationsPerformed -and -not [bool]$routeGate.sourceImageBytesRead) 'O2D23 route authority widened.'

Assert-True ([string]$aliasGate.state -eq 'PASS_O2D23_EXACT_INSPECTIONREVS_U_ALIAS_GATE' -and [bool]$aliasGate.aliasResolvedExact -and [bool]$aliasGate.persistentMappingVerified -and [bool]$aliasGate.requestsRootReadable) 'O2D23 alias gate changed.'
Assert-True ([string]$aliasGate.aliasPathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$aliasGate.aliasTargetEffectiveLength -lt 200 -and [int]$aliasGate.aliasUploadEffectiveLength -lt 200) 'O2D23 alias path gate is not safe.'
Assert-True (-not [bool]$aliasGate.publicationPerformed -and [bool]$aliasGate.targetAbsentAtGate -and [bool]$aliasGate.uploadAbsentAtGate) 'O2D23 alias gate lifecycle changed.'
Assert-True ((Normalize-Root ([string]$aliasGate.aliasRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O2D23 alias root changed.'

Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2D23_SLOT25_OUTCOME_BLIND_PUBLISHER_READY') 'O2D23 continuity phase changed.'
Assert-True ([string]$continuity.currentPhaseCheckpointSha256 -eq $expectedCheckpointSha256) 'O2D23 continuity checkpoint changed.'
Assert-True ([string]$migration.ocv02O2D23RequestId -eq $requestId -and [string]$migration.ocv02O2D23FinalZipSha256 -eq $expectedZipSha256) 'O2D23 continuity request identity changed.'
Assert-True ([string]$migration.ocv02O2D23CompleteRouteGateSha256 -eq $expectedRouteGateSha256 -and [string]$migration.ocv02O2D23PublicationAliasGateSha256 -eq $expectedAliasGateSha256) 'O2D23 continuity route pins changed.'
Assert-True ([bool]$migration.ocv02O2D23PublicationAuthorized -and [int]$migration.ocv02O2D23MaximumPublications -eq 1 -and -not [bool]$migration.ocv02O2D23RetryAuthorized -and -not [bool]$migration.ocv02O2D23Published -and -not [bool]$migration.ocv02O2D23ExecutedOnJbod) 'O2D23 continuity publication lifecycle changed.'
Assert-True ([string]$migration.ocv02O2D23ValidationQualification -eq $validationQualification -and [bool]$migration.ocv02O2D23Slot25SourceMetadataPrematurelyExposed -and -not [bool]$migration.ocv02O2D23Slot25ImageBytesRead -and -not [bool]$migration.ocv02O2D23Slot25OutcomeSeen -and -not [bool]$migration.ocv02O2D23WhollyUnseenClaimAllowed) 'O2D23 continuity disclosure changed.'
Assert-True ([bool]$migration.ocv02O2D23NoTuning -and -not [bool]$migration.ocv02O2D23TaskOrProcessRestarted -and -not [bool]$migration.ocv02O2D23ProviderActivated -and -not [bool]$migration.ocv02O2D23SourceMutationPerformed -and -not [bool]$migration.ocv02O2D23WaferActionPerformed -and -not [bool]$migration.ocv02O2D23HoldsCleared) 'O2D23 continuity holds changed.'
Assert-True ([bool]$continuity.reviewOnly -and -not [bool]$continuity.productionEligible -and -not [bool]$continuity.xmlEligible -and -not [bool]$continuity.trainingEligible) 'O2D23 continuity authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'O2D23 publication requires matching local/origin branch tips.'
$worktreeRows = @(& git -C $project status --porcelain=v1)
Assert-True ($worktreeRows.Count -eq 0) 'O2D23 publication requires a clean worktree.'

$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'U: PowerShell mapping does not target the exact InspectionRevs root.'
$logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null -ne $logicalDisk -and [int]$logicalDisk.DriveType -eq 4) 'U: is not a persistent Windows network-drive mapping.'
Assert-True ((Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'U: operating-system mapping does not target the exact InspectionRevs root.'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'O2D23 request share is unavailable through persistent U:.'

$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
Assert-True ($pending.Count -eq 0) ('O2D23 another portal request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
foreach ($path in @($uploadPath, $readyPath, $processedPath, $publishGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D23 create-new publication target exists: $path"
}

$pathGate = & $pathTool -CandidatePath @($sourceZip, $uploadPath, $readyPath, $processedPath, $publishGatePath, $invocationPath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D23 exact publication path gate failed: $($pathGate.state)"

$preflightResult = [ordered]@{
    schema = 'argos_o2d23_publish_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D23_PUBLISH_PREFLIGHT'
    requestId = $requestId
    validationQualification = $validationQualification
    invocationManifestSha256 = $expectedInvocationSha256
    sourceZipSha256 = $expectedZipSha256
    sourceZipBytes = $expectedZipBytes
    finalGateSha256 = $expectedFinalGateSha256
    completeRouteGateSha256 = $expectedRouteGateSha256
    aliasGateSha256 = $expectedAliasGateSha256
    checkpointSha256 = $expectedCheckpointSha256
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
    slot25SourceMetadataPrematurelyExposed = $true
    slot25ImageBytesRead = $false
    slot25OutcomeSeen = $false
    slot25WhollyUnseenClaimAllowed = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
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
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $expectedZipBytes -and (Get-Sha256 $uploadPath) -eq $expectedZipSha256) 'O2D23 uploaded request ZIP changed.'
    [IO.File]::Move($uploadPath, $readyPath)
    $uploadCreated = $false
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $expectedZipBytes -and (Get-Sha256 $readyPath) -eq $expectedZipSha256) 'O2D23 published request ZIP changed.'

    $result = [ordered]@{
        schema = 'argos_o2d23_publish_gate_v1'
        publishedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D23_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'
        disposition = 'PENDING_GATE'
        requestId = $requestId
        validationQualification = $validationQualification
        invocationManifestSha256 = $expectedInvocationSha256
        sourceZip = $sourceZip
        publishedPath = $readyPath
        bytes = $expectedZipBytes
        sha256 = $expectedZipSha256
        finalGateSha256 = $expectedFinalGateSha256
        completeRouteGateSha256 = $expectedRouteGateSha256
        aliasGateSha256 = $expectedAliasGateSha256
        checkpointSha256 = $expectedCheckpointSha256
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
        slot25SourceMetadataPrematurelyExposed = $true
        slot25ImageBytesRead = $false
        slot25OutcomeSeen = $false
        slot25WhollyUnseenClaimAllowed = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
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
