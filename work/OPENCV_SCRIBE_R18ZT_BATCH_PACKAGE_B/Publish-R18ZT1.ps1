#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Apply)) { throw 'Specify exactly one of -Preflight or -Apply.' }

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Require-Pin([string]$Path, [string]$Sha256) {
    Require ($Sha256 -cmatch '^[A-F0-9]{64}$') "R18ZT publication pin is not finalized: $Path"
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18ZT publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18ZT publication dependency changed: $Path"
}

function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\', '/'), $Name, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [int64]$matches[0].Length -le $MaximumBytes) "Missing, duplicated, or oversized request entry: $Name"
    $input = $matches[0].Open()
    $memory = New-Object IO.MemoryStream
    try {
        $input.CopyTo($memory)
        return ,([byte[]]$memory.ToArray())
    }
    finally { $memory.Dispose(); $input.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18ZT1'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18ZT_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip.complete_route_gate.json')
$pathGatePath = Join-Path $PSScriptRoot 'R18ZT_PATH_PLAN_GATE.json'
$collisionGatePath = Join-Path $PSScriptRoot 'R18ZT_REQUEST_ID_COLLISION_GATE.json'
$authorityPath = Join-Path $PSScriptRoot 'R18ZT_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18ZT_PUBLICATION.json'
$priorTerminalGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R18W4S21\R18W4S21_SIGNED_TERMINAL_RESPONSE_CHECKPOINT_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18ZT1_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')

$zipSha = 'PENDING_R18ZT_REQUEST_ZIP_SHA256'
$packageGateSha = 'PENDING_R18ZT_FINAL_PACKAGE_GATE_SHA256'
$routeGateSha = 'PENDING_R18ZT_COMPLETE_ROUTE_GATE_SHA256'
$pathGateSha = 'PENDING_R18ZT_PATH_GATE_SHA256'
$collisionGateSha = 'PENDING_R18ZT_REQUEST_ID_COLLISION_GATE_SHA256'
$authoritySha = 'PENDING_R18ZT_PUBLICATION_AUTHORITY_SHA256'
$preactionSha = 'PENDING_R18ZT_PUBLICATION_PREACTION_SHA256'

foreach ($pin in @(
    [pscustomobject]@{path=$sourceZip;sha=$zipSha},
    [pscustomobject]@{path=$packageGatePath;sha=$packageGateSha},
    [pscustomobject]@{path=$routeGatePath;sha=$routeGateSha},
    [pscustomobject]@{path=$pathGatePath;sha=$pathGateSha},
    [pscustomobject]@{path=$collisionGatePath;sha=$collisionGateSha},
    [pscustomobject]@{path=$authorityPath;sha=$authoritySha},
    [pscustomobject]@{path=$preactionPath;sha=$preactionSha},
    [pscustomobject]@{path=$priorTerminalGatePath;sha='AFE5D75B4ED250C961961A756A52B0BA8D46E50B336E9B11924CBCD9F6E1F335'},
    [pscustomobject]@{path=$signerCertificatePath;sha='2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'}
)) { Require-Pin ([string]$pin.path) ([string]$pin.sha) }

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
Require ([string](($preactionJson | ConvertFrom-Json).state) -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18ZT publication preaction changed.'
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
$collisionGate = Get-Content -LiteralPath $collisionGatePath -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$priorTerminal = Get-Content -LiteralPath $priorTerminalGatePath -Raw | ConvertFrom-Json
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Require ([string]$packageGate.state -eq 'PASS_R18ZT_SIGNED_UNPUBLISHED_PACKAGE_GATE' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int64]$packageGate.requestZipBytes -eq $sourceBytes -and -not [bool]$packageGate.completionClaimed -and -not [bool]$packageGate.retryAuthorized) 'R18ZT final package gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18ZT_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED' -and [string]$routeGate.requestId -eq $requestId -and [string]$routeGate.requestZipSha256 -eq $zipSha -and [bool]$routeGate.publicationMustRecheckAllCollisionScopes -and [int]$routeGate.maximumEffectiveLength -lt 200 -and [int]$routeGate.unsafePathCount -eq 0 -and -not [bool]$routeGate.completionClaimed) 'R18ZT complete route gate changed.'
Require ([string]$pathGate.state -eq 'PASS_PATH_BUDGET' -and [int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80 -and [int]$pathGate.unsafePathCount -eq 0) 'R18ZT path gate changed.'
Require ([string]$collisionGate.state -eq 'PASS_R18ZT_REQUEST_ID_ABSENT_ALL_SCOPES' -and [string]$collisionGate.requestId -eq $requestId -and [bool]$collisionGate.liveRequestsScanned -and [bool]$collisionGate.liveProcessedArchiveScanned -and [bool]$collisionGate.localPublicationArchiveScanned -and ([bool]$collisionGate.gatewayInventoryScanned -or [bool]$collisionGate.gatewayInventoryUnavailableExplicitlyHeld) -and [int]$collisionGate.matchCount -eq 0) 'R18ZT request-ID collision gate changed.'
Require ([string]$authority.state -eq 'PASS_R18ZT_CONDITIONAL_PUBLICATION_AUTHORITY' -and [string]$authority.requestId -eq $requestId -and [string]$authority.operatorAuthorityText -eq 'Do the work, if it is successful - as in deciphering correctly. PUBLISH the package to JBOD.' -and [bool]$authority.exactSlot21ImageFirstPassVerified -and [string]$authority.exactSlot21ImageFirstString -eq '13HFX135SUE3' -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized -and -not [bool]$authority.freshRequestIdSpecificLiteralRequired) 'R18ZT conditional publication authority changed.'
Require ([string]$priorTerminal.state -match '^PASS_' -and [string]$priorTerminal.requestId -eq 'REQ_S21_20260905212322_S9RHWN0X00G4K59QB7Q1120VDR' -and [bool]$priorTerminal.signedResponseVerified) 'Latest same-endpoint request lacks its pinned signed terminal response.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18ZT publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.sig' 8192
}
finally { $zip.Dispose() }
$manifest = (New-Object Text.UTF8Encoding($false, $true)).GetString($manifestBytes) | ConvertFrom-Json
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
Require ($signatureValid) 'R18ZT request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'R18ZT signed manifest identity changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18ZT signed request expired; publication refused.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled) 'R18ZT signed authority widened.'
Require ([bool]$manifest.timeoutContract.corpusWorkerPersistsAfterPortalResponse -and [bool]$manifest.timeoutContract.corpusCompletionNotRequiredForLaunchResponse -and [bool]$manifest.timeoutContract.portalResponseProvesLaunchOnly -and -not [bool]$manifest.rehearsal.completionClaimed) 'R18ZT signed launch-only semantics changed.'
Require (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1 -and [string]$manifest.allowedProcessActions[0] -eq 'START_ONE_OWNED_BACKGROUND_R18ZT_BATCH_WORKER') 'R18ZT signed action set changed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18ZT publish requires clean dedicated branch matching recorded origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18ZT persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18ZT portal request root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18ZT request identity already exists in the live route.'
$pendingRequests = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pendingRequests.Count -eq 0) 'Another portal request is pending; R18ZT publication refused.'

$result = [ordered]@{
    schema = 'argos_opencv_scribe_r18zt1_publish_gate_v1'
    publishedUtc = [DateTime]::UtcNow.ToString('o')
    state = $(if ($Preflight) { 'PASS_R18ZT1_PUBLISH_PREFLIGHT' } else { 'PASS_R18ZT1_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW' })
    requestId = $requestId
    publishedPath = $readyPath
    bytes = $sourceBytes
    sha256 = $zipSha
    signatureVerified = $true
    expiresUtc = [string]$manifest.expiresUtc
    queueState = 'NEW'
    pendingRequestCount = 0
    requestIdCollisionGateSha256 = $collisionGateSha
    createNew = $true
    overwritePerformed = $false
    maximumPublicationsAuthorized = 1
    retryAuthorized = $false
    matchingSignedTerminalResponseCollectionOnly = $true
    persistentUMapping = $true
    persistentUMappingRoot = $shareRoot
    persistentUMappingLeftInPlace = $true
    taskActions = @()
    processActions = @('START_ONE_OWNED_BACKGROUND_R18ZT_BATCH_WORKER')
    asynchronousLaunchOnly = $true
    completionClaimed = $false
    sourceMutationPerformed = $false
    identityAccepted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    mutationsPerformed = $false
}
if ($Preflight) {
    $result | ConvertTo-Json -Depth 16
    return
}

$sourceStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $sourceStream.CopyTo($targetStream)
    $targetStream.Flush($true)
}
finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18ZT staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18ZT ready path appeared before atomic commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$result.mutationsPerformed = $true
Write-JsonCreateNew $publishGatePath $result
$result | ConvertTo-Json -Depth 16
