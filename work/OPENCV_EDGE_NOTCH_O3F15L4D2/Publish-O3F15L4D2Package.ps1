#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash($stream))).Replace('-', '') }
    finally { $algorithm.Dispose(); $stream.Dispose() }
}

function Get-RequiredProperty([object]$Value, [string]$Name) {
    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "D2 publication invocation is missing $Name." }
    $property.Value
}

function Resolve-RepositoryFile([string]$ProjectRoot, [string]$RelativePath) {
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "D2 publication dependency must be repository-relative: $RelativePath"
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $RelativePath.Replace('/', '\')))
    Assert-True ($resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) "D2 publication dependency escapes the repository: $RelativePath"
    $resolved
}

function Assert-PinnedFile([string]$Path, [string]$Sha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "D2 publication $Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -ceq $Sha256) "D2 publication $Label hash changed."
}

function Assert-QualifiedPersistentDrive([string]$ExpectedShare) {
    $drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
    Assert-True ([string]$drive.DisplayRoot -ceq $ExpectedShare) 'D2 persistent U: DisplayRoot changed.'
    Assert-True ([string]$disk.ProviderName -ceq $ExpectedShare -and [int]$disk.DriveType -eq 4) 'D2 persistent U: Win32 provider identity changed.'
}

function Get-PendingRequestFiles([string]$RequestRoot) {
    @(Get-ChildItem -LiteralPath $RequestRoot -File -ErrorAction Stop | Where-Object {
        $_.Name -cmatch '\.ready\.zip(?:\.upload)?$'
    })
}

function Read-ZipManifest([string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.json')
        Assert-True ($null -ne $entry -and $entry.Length -ge 2 -and $entry.Length -le 1048576) 'D2 request manifest ZIP entry is absent or oversized.'
        $reader = New-Object IO.StreamReader($entry.Open(), (New-Object Text.UTF8Encoding($false, $true)), $true)
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        $text | ConvertFrom-Json
    } finally {
        $archive.Dispose()
    }
}

function Write-NewUtf8Json([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "D2 publication gate already exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Assert-True ($Preflight -xor $Publish) 'Specify exactly one of -Preflight or -Publish.'
Assert-True ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'D2 publisher requires Windows PowerShell 5.1.'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocation = Join-Path $PSScriptRoot 'O3F15L4D2_PUBLISH_INVOCATION.json'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocation, [StringComparison]::OrdinalIgnoreCase)) 'D2 publication invocation path changed.'
Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'D2 publication invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string](Get-RequiredProperty $invocation 'schema') -ceq 'argos_ocv03_o3f15l4d2_publish_invocation_v1') 'D2 publication invocation schema changed.'
Assert-True ([string](Get-RequiredProperty $invocation 'state') -ceq 'FROZEN_O3F15L4D2_EXACTLY_ONCE_PUBLICATION_INVOCATION') 'D2 publication invocation is not frozen.'
Assert-True ([string](Get-RequiredProperty $invocation 'publisherSha256') -ceq (Get-Sha256 $PSCommandPath)) 'D2 publisher is not the frozen byte set.'
Assert-True ([int](Get-RequiredProperty $invocation 'maximumPublications') -eq 1 -and -not [bool](Get-RequiredProperty $invocation 'requestRetryAuthorized')) 'D2 publication/retry authority changed.'
Assert-True ([bool](Get-RequiredProperty $invocation 'reviewOnly') -and -not [bool](Get-RequiredProperty $invocation 'trainingEligible') -and -not [bool](Get-RequiredProperty $invocation 'xmlEligible') -and -not [bool](Get-RequiredProperty $invocation 'productionEligible') -and -not [bool](Get-RequiredProperty $invocation 'productionRoutingEnabled')) 'D2 publication authority widened.'

$requestId = [string](Get-RequiredProperty $invocation 'requestId')
Assert-True ($requestId -cmatch '^REQ_[0-9]{8}T[0-9]{9}Z_[0-9A-F]{12}$') 'D2 publication request ID shape changed.'
$sourceZip = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'sourceZip'))
$sourceHash = [string](Get-RequiredProperty $invocation 'sourceZipSha256')
$sourceBytes = [int64](Get-RequiredProperty $invocation 'sourceZipBytes')
Assert-PinnedFile $sourceZip $sourceHash 'source ZIP'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $sourceBytes) 'D2 source ZIP byte count changed.'
$manifest = Read-ZipManifest $sourceZip
Assert-True ([string]$manifest.schema -ceq 'argos_project_portal_request_manifest_v1' -and [string]$manifest.requestId -ceq $requestId -and [string]$manifest.targetRole -ceq 'JBOD' -and [string]$manifest.jobClass -ceq 'MAINTENANCE_PATCH') 'D2 request ZIP identity changed.'
Assert-True ([int64]$manifest.maxResultBytes -eq 8388608 -and [bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded -and -not [bool]$manifest.requestRetryAuthorized) 'D2 request ZIP authority changed.'

$routeGatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'routeGatePath'))
$preactionGatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'preactionGatePath'))
Assert-PinnedFile $routeGatePath ([string](Get-RequiredProperty $invocation 'routeGateSha256')) 'prepublication route gate'
Assert-PinnedFile $preactionGatePath ([string](Get-RequiredProperty $invocation 'preactionGateSha256')) 'preaction gate'
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$preactionGate = Get-Content -LiteralPath $preactionGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$routeGate.state -ceq 'PASS_O3F15L4D2_COMPLETE_ROUTE_PATH_GATE' -and [string]$routeGate.requestId -ceq $requestId -and [string]$routeGate.signedPackageZipSha256 -ceq $sourceHash -and [int]$routeGate.publicationCountMaximum -eq 1 -and -not [bool]$routeGate.requestRetryAuthorized) 'D2 prepublication route gate changed.'
Assert-True ([string]$preactionGate.state -ceq [string](Get-RequiredProperty $invocation 'expectedPreactionGateState')) 'D2 publication preaction gate changed.'

$closure = Get-RequiredProperty $invocation 'priorAcceptedRequestClosure'
Assert-True ([string](Get-RequiredProperty $closure 'scope') -ceq 'IMMEDIATE_PRIOR_SERIAL_REQUEST_CHAIN') 'D2 prior-request closure scope changed.'
Assert-True ([bool](Get-RequiredProperty $closure 'completeSerialChain') -and [int](Get-RequiredProperty $closure 'unresolvedCount') -eq 0) 'D2 immediate prior accepted request is not terminal.'
$closureRows = @((Get-RequiredProperty $closure 'records'))
Assert-True ($closureRows.Count -eq [int](Get-RequiredProperty $closure 'acceptedRequestCount')) 'D2 prior-request closure cardinality changed.'
Assert-True ($closureRows.Count -eq 1) 'D2 immediate prior serial-chain closure must contain exactly one request.'
$seenRequestIds = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
foreach ($row in $closureRows) {
    $priorId = [string](Get-RequiredProperty $row 'requestId')
    Assert-True ($priorId -cmatch '^REQ_' -and $priorId -cne $requestId -and $seenRequestIds.Add($priorId)) 'D2 prior-request closure contains an invalid or duplicate request ID.'
    Assert-True ([bool](Get-RequiredProperty $row 'terminal') -and [bool](Get-RequiredProperty $row 'responseSignatureVerified') -and -not [bool](Get-RequiredProperty $row 'retryPending')) "D2 prior request is not signed-terminal: $priorId"
    Assert-True ($priorId -ceq 'REQ_20260903T090514331Z_84BB875EEFD2' -and [string](Get-RequiredProperty $row 'responseId') -ceq 'R_B8A16CFA33BC_20260903092008761_68e46cd3') 'D2 immediate prior serial request is not O3F15L3.'
    $acceptanceEvidence = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $row 'acceptanceEvidencePath'))
    Assert-PinnedFile $acceptanceEvidence ([string](Get-RequiredProperty $row 'acceptanceEvidenceSha256')) "prior acceptance evidence $priorId"
    $acceptance = Get-Content -LiteralPath $acceptanceEvidence -Raw | ConvertFrom-Json
    Assert-True ([string](Get-RequiredProperty $acceptance 'requestId') -ceq $priorId -and [int](Get-RequiredProperty $acceptance 'publicationCount') -eq 1 -and -not [bool](Get-RequiredProperty $acceptance 'automaticRetryAuthorized')) 'D2 immediate prior acceptance evidence changed.'
    $terminalEvidence = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $row 'terminalEvidencePath'))
    Assert-PinnedFile $terminalEvidence ([string](Get-RequiredProperty $row 'terminalEvidenceSha256')) "prior terminal evidence $priorId"
    $terminal = Get-Content -LiteralPath $terminalEvidence -Raw | ConvertFrom-Json
    Assert-True ([string](Get-RequiredProperty $terminal 'requestId') -ceq $priorId -and [string](Get-RequiredProperty $terminal 'responseId') -ceq [string](Get-RequiredProperty $row 'responseId') -and [bool](Get-RequiredProperty $terminal 'responseSignatureVerified')) "D2 prior terminal evidence identity changed: $priorId"
}

$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
Assert-True ([string](Get-RequiredProperty $invocation 'expectedPersistentShare') -ceq $expectedShare) 'D2 publication share pin changed.'
Assert-QualifiedPersistentDrive $expectedShare
$requestRoot = 'U:\ProjectPortalRO\requests'
Assert-True (Test-Path -LiteralPath $requestRoot -PathType Container) 'D2 Project Portal request root is unavailable.'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$publicationGatePath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'publicationGatePath'))
$publicationAttemptPath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'publicationAttemptPath'))
Assert-True ($publicationGatePath.Equals((Join-Path $PSScriptRoot 'O3F15L4D2_PUBLISH_GATE.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 publication gate path changed.'
Assert-True ($publicationAttemptPath.Equals((Join-Path $PSScriptRoot 'O3F15L4D2_PUBLISH_ATTEMPT.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 publication-attempt receipt path changed.'
Assert-True (-not (Test-Path -LiteralPath $publicationGatePath)) "D2 publication gate already exists: $publicationGatePath"
$attemptReceiptExists = Test-Path -LiteralPath $publicationAttemptPath -PathType Leaf
if ($attemptReceiptExists) {
    $attemptReceipt = Get-Content -LiteralPath $publicationAttemptPath -Raw | ConvertFrom-Json
    Assert-True ([string](Get-RequiredProperty $attemptReceipt 'schema') -ceq 'argos_ocv03_o3f15l4d2_publish_attempt_v1' -and [string](Get-RequiredProperty $attemptReceipt 'state') -ceq 'STARTED_O3F15L4D2_SINGLE_PUBLICATION_ATTEMPT') 'D2 publication-attempt receipt identity changed.'
    Assert-True ([string](Get-RequiredProperty $attemptReceipt 'requestId') -ceq $requestId -and [string](Get-RequiredProperty $attemptReceipt 'sourceZipSha256') -ceq $sourceHash -and [int64](Get-RequiredProperty $attemptReceipt 'sourceZipBytes') -eq $sourceBytes) 'D2 publication-attempt receipt belongs to another package.'
    Assert-True ([int](Get-RequiredProperty $attemptReceipt 'attemptCount') -eq 1 -and [bool](Get-RequiredProperty $attemptReceipt 'committedBeforeExternalWrite') -and -not [bool](Get-RequiredProperty $attemptReceipt 'requestRetryAuthorized')) 'D2 publication-attempt receipt widened retry authority.'
}
$pendingBefore = @(Get-PendingRequestFiles $requestRoot)
$otherPending = @($pendingBefore | Where-Object { -not $_.FullName.Equals($uploadPath, [StringComparison]::OrdinalIgnoreCase) -and -not $_.FullName.Equals($readyPath, [StringComparison]::OrdinalIgnoreCase) })
Assert-True ($otherPending.Count -eq 0) ('D2 publication blocked by another pending request: ' + (($otherPending | ForEach-Object { $_.Name }) -join ', '))
$queueState = 'INVALID'
if (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and $pendingBefore.Count -eq 0) {
    Assert-True (-not $attemptReceiptExists) 'D2 prior publication attempt has no exact queue artifact; refusing an ambiguous retry after possible importer consumption.'
    $queueState = 'NEW'
} elseif ((Test-Path -LiteralPath $uploadPath -PathType Leaf) -and -not (Test-Path -LiteralPath $readyPath) -and $pendingBefore.Count -eq 1) {
    Assert-True $attemptReceiptExists 'D2 exact upload lacks the durable local publication-attempt receipt.'
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -ceq $sourceHash) 'D2 pre-existing upload is not the exact pinned request.'
    $queueState = 'EXACT_UPLOAD'
} elseif (-not (Test-Path -LiteralPath $uploadPath) -and (Test-Path -LiteralPath $readyPath -PathType Leaf) -and $pendingBefore.Count -eq 1) {
    Assert-True $attemptReceiptExists 'D2 exact ready request lacks the durable local publication-attempt receipt.'
    Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $sourceBytes -and (Get-Sha256 $readyPath) -ceq $sourceHash) 'D2 pre-existing ready request is not the exact pinned request.'
    $queueState = 'EXACT_READY'
}
Assert-True ($queueState -cin @('NEW', 'EXACT_UPLOAD', 'EXACT_READY')) 'D2 publication queue is not NEW, pinned EXACT_UPLOAD, or pinned EXACT_READY.'

$preflightResult = [ordered]@{
    schema = 'argos_ocv03_o3f15l4d2_publish_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3F15L4D2_EXACTLY_ONCE_PUBLICATION_PREFLIGHT'
    requestId = $requestId
    sourceZip = $sourceZip
    sourceZipBytes = $sourceBytes
    sourceZipSha256 = $sourceHash
    routeGateSha256 = Get-Sha256 $routeGatePath
    priorAcceptedRequestCount = $closureRows.Count
    priorAcceptedUnresolvedCount = 0
    pendingRequestCount = $pendingBefore.Count
    otherPendingRequestCount = 0
    queueState = $queueState
    persistentDriveDisplayRoot = $expectedShare
    persistentDriveProviderName = $expectedShare
    persistentDriveType = 4
    uploadPath = $uploadPath
    readyPath = $readyPath
    publicationAttemptPath = $publicationAttemptPath
    publicationAttemptReceiptExists = $attemptReceiptExists
    publicationCountMaximum = 1
    requestRetryAuthorized = $false
    mappingCreatedOrRemoved = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 12
    return
}

$createdUpload = $false
$createdAttemptReceipt = $false
$atomicRenamePerformed = $false
if ($queueState -ceq 'NEW') {
    $attemptReceipt = [ordered]@{
        schema = 'argos_ocv03_o3f15l4d2_publish_attempt_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'STARTED_O3F15L4D2_SINGLE_PUBLICATION_ATTEMPT'
        requestId = $requestId
        sourceZip = $sourceZip
        sourceZipBytes = $sourceBytes
        sourceZipSha256 = $sourceHash
        uploadPath = $uploadPath
        readyPath = $readyPath
        attemptCount = 1
        requestRetryAuthorized = $false
        committedBeforeExternalWrite = $true
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-NewUtf8Json $publicationAttemptPath $attemptReceipt
    $createdAttemptReceipt = $true
    $source = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $destination = $null
    try {
        $destination = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
        $source.CopyTo($destination, 1048576)
        $destination.Flush()
        $createdUpload = $true
    } finally {
        if ($null -ne $destination) { $destination.Dispose() }
        $source.Dispose()
    }
}
if ($queueState -cin @('NEW', 'EXACT_UPLOAD')) {
    Assert-True ((Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -ceq $sourceHash) 'D2 exact upload verification failed; upload is retained as a no-retry hold.'
    Assert-QualifiedPersistentDrive $expectedShare
    $transitionRows = @(Get-PendingRequestFiles $requestRoot)
    $transitionOther = @($transitionRows | Where-Object { -not $_.FullName.Equals($uploadPath, [StringComparison]::OrdinalIgnoreCase) })
    Assert-True ($transitionRows.Count -eq 1 -and $transitionOther.Count -eq 0 -and -not (Test-Path -LiteralPath $readyPath)) 'D2 request queue changed before commit; exact upload is retained as a no-retry hold.'
    [IO.File]::Move($uploadPath, $readyPath)
    $atomicRenamePerformed = $true
}
$readyObserved = Test-Path -LiteralPath $readyPath -PathType Leaf
if ($readyObserved) { Assert-True ((Get-Item -LiteralPath $readyPath).Length -eq $sourceBytes -and (Get-Sha256 $readyPath) -ceq $sourceHash) 'D2 published request verification failed; no retry is authorized.' }
Assert-True ($queueState -ceq 'EXACT_READY' -or $atomicRenamePerformed) 'D2 publication commit was not proved.'

$gate = [ordered]@{
    schema = 'argos_ocv03_o3f15l4d2_publish_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3F15L4D2_PUBLISHED_EXACTLY_ONCE_AWAITING_MATCHING_SIGNED_RESPONSE'
    disposition = 'PENDING_GATE'
    requestId = $requestId
    sourceZip = $sourceZip
    publishedPath = $readyPath
    publishedBytes = $sourceBytes
    publishedSha256 = $sourceHash
    routeGateSha256 = Get-Sha256 $routeGatePath
    priorAcceptedRequestCount = $closureRows.Count
    priorAcceptedUnresolvedCount = 0
    publicationCount = 1
    recoveredQueueState = $queueState
    publicationAttemptPath = $publicationAttemptPath
    publicationAttemptSha256 = Get-Sha256 $publicationAttemptPath
    publicationAttemptCreatedThisRun = $createdAttemptReceipt
    createNewUpload = $createdUpload
    atomicSameDirectoryUploadToReadyRename = $atomicRenamePerformed
    readyObservedAfterCommit = $readyObserved
    overwritePerformed = $false
    automaticRetryAuthorized = $false
    mappingCreatedOrRemoved = $false
    sourceMutationOrDeletionPerformed = $false
    existingTaskOrProcessActionCount = 0
    imageBytesRead = $false
    providerActivated = $false
    holdsAutomaticallyCleared = $false
    fullFrontsideHoldCountPreserved = 184
    patternedFrontHoldCountPreserved = 12
    slot02AmbiguityPreserved = $true
    slot16RareHotspotPreserved = $true
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-NewUtf8Json $publicationGatePath $gate
$gate | ConvertTo-Json -Depth 16
