#Requires -Version 5.1
# Clone-audit historical template root only: D:\KLARFExport is not read by R18R2.
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18R2 publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18R2 publication dependency changed: $Path"
}
function Read-ZipEntryBytes([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); return $memory.ToArray() } finally { $memory.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18R2'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18R_FINAL_PACKAGE_GATE.json'
$routeGatePath = $sourceZip + '.complete_route_gate.json'
$roundTripGatePath = Join-Path $PSScriptRoot 'R18R_FULL_ROUND_TRIP_PATH_GATE.json'
$exactPathGatePath = Join-Path $PSScriptRoot 'R18R_EXACT_PACKAGE_PATH_GATE.json'
$authorityPath = Join-Path $PSScriptRoot 'R18R2_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18R2_REFERENCE_ISOLATED_PUBLICATION.json'
$checkpointPath = Join-Path $project 'work\OPENCV_SCRIBE_R18R2\R18R2_SIGNED_UNPUBLISHED_READY_CHECKPOINT_20260904.md'
$priorTerminalGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R18P\R18P_COMPLETED_REVIEW_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18R2_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$zipSha = 'E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300'
$packageGateSha = '3970AE7F63E5309DD6425EEEC72865AF56215B4226398064F324162E3DB2F4A4'
$routeGateSha = 'C66F9E564639E5080E76D14BDDBA0B01E3CB7F96FB53CDB9E29F1EBFB2E3F617'
$roundTripGateSha = 'CD6AB17E09C12B23557048B3B3A7AB0EC2DFDFF68439A01474B41240CB66C81C'
$exactPathGateSha = '077EE30402CBD9A5F72191972B2CA14E63B355B6C9A24102D075D6F57E6D8A38'
$authoritySha = '4A32BF9E63179AF982F03F04402EFC91760C3D7708A09D80F7233120742C5258'
$preactionSha = '17A8B17C6FD9321B87DD46CCE8B31289E5D5C9146812D67922307522C484D424'
$checkpointSha = 'A7F9F2D05A4DEC2C3EC64D003D0C555A66ACBBFF4B824EB034062AB429385CCD'
$priorTerminalGateSha = '018F3CA26CF5D8F63D9BD28C346100999C3407AFA2E31AC4DD646E8C8AF24B11'

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath $packageGateSha
Require-Pin $routeGatePath $routeGateSha
Require-Pin $roundTripGatePath $roundTripGateSha
Require-Pin $exactPathGatePath $exactPathGateSha
Require-Pin $authorityPath $authoritySha
Require-Pin $preactionPath $preactionSha
Require-Pin $checkpointPath $checkpointSha
Require-Pin $priorTerminalGatePath $priorTerminalGateSha
Require-Pin $signerCertificatePath '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
$preaction = $preactionJson | ConvertFrom-Json
Require ([string]$preaction.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18R2 publication preaction changed.'
$packageGate = Get-Content -Raw -LiteralPath $packageGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
$roundTripGate = Get-Content -Raw -LiteralPath $roundTripGatePath | ConvertFrom-Json
$exactPathGate = Get-Content -Raw -LiteralPath $exactPathGatePath | ConvertFrom-Json
$authority = Get-Content -Raw -LiteralPath $authorityPath | ConvertFrom-Json
$priorTerminalGate = Get-Content -Raw -LiteralPath $priorTerminalGatePath | ConvertFrom-Json
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Require ([string]$packageGate.state -eq 'PASS_R18R_FINAL_PACKAGE_GATE' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int64]$packageGate.requestZipBytes -eq $sourceBytes -and [int]$packageGate.finalZipFileCount -eq 31 -and [int]$packageGate.engineSourceCount -eq 15 -and [int]$packageGate.hardCodedEngineLiteralCount -eq 0 -and [int]$packageGate.configurationLiteralLeakCount -eq 0 -and [bool]$packageGate.checksumVerificationRequired -and -not [bool]$packageGate.checksumUsedForImageFirst -and [int]$packageGate.maximumEffectiveLength -lt 200) 'R18R2 package gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18R_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId -and [string]$routeGate.requestZipSha256 -eq $zipSha -and [int]$routeGate.actualFinalZipMemberCount -eq 31 -and [bool]$routeGate.actualPriorFailureLeafIncluded -and [bool]$routeGate.publicationMustRecheckQueueAndNamespace -and [string]$routeGate.queueState -eq 'NOT_OBSERVED_BY_LOCAL_BUILDER' -and $null -eq $routeGate.pendingRequestCount -and [int]$routeGate.maximumEffectiveLength -lt 200) 'R18R2 complete route gate changed.'
Require ([string]$roundTripGate.state -eq 'PASS_R18R_FULL_ROUND_TRIP_PATH_GATE' -and [string]$roundTripGate.requestId -eq $requestId -and [string]$roundTripGate.requestZipSha256 -eq $zipSha -and [int]$roundTripGate.candidateCount -eq 26 -and [bool]$roundTripGate.actualFinalZipMembersCheckedAtEveryExtractionHop -and [int]$roundTripGate.maximumEffectiveLength -lt 200 -and [int]$roundTripGate.unsafePathCount -eq 0) 'R18R2 full round-trip path gate changed.'
Require ([string]$exactPathGate.state -eq 'PASS_R18R_EXACT_PACKAGE_PATHS' -and [string]$exactPathGate.requestId -eq $requestId -and [string]$exactPathGate.requestZipSha256 -eq $zipSha -and [bool]$exactPathGate.entrypointDefaultsMatchSignedDefinition -and [int]$exactPathGate.actualFinalZipMemberCount -eq 31 -and [int]$exactPathGate.maximumEffectiveLength -lt 200) 'R18R2 exact-package path gate changed.'
Require ([string]$authority.state -eq 'PASS_R18R2_PUBLICATION_AUTHORITY' -and [string]$authority.requestId -eq $requestId -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized -and [bool]$authority.checksumVerificationRequired -and -not [bool]$authority.checksumUsedForImageFirst -and @($authority.operatorAuthority) -contains 'PUBLISH') 'R18R2 publication authority changed.'
Require ([string]$priorTerminalGate.requestId -eq 'REQ_R18P1' -and [bool]$priorTerminalGate.publication.publishedExactlyOnce -and [bool]$priorTerminalGate.signedResponse.signatureVerified -and [string]$priorTerminalGate.signedResponse.sourceRole -eq 'JBOD' -and [string]$priorTerminalGate.completion.state -eq 'PASS_R18P_REFERENCE_ISOLATED_REVIEW_ONLY_COMPLETE') 'Prior same-endpoint request lacks a pinned signed terminal completion.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18R2 publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $entries = @($archive.Entries)
    Require ($entries.Count -eq 31) 'R18R2 signed ZIP membership count changed.'
    $manifestEntry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.json')
    $signatureEntry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.sig')
    Require ($null -ne $manifestEntry -and $null -ne $signatureEntry) 'R18R2 signed manifest or signature entry absent.'
    $manifestBytes = Read-ZipEntryBytes $manifestEntry
    $signatureBytes = Read-ZipEntryBytes $signatureEntry
    $manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
}
finally { $archive.Dispose() }
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
Require ($null -ne $rsa) 'Pinned request signer certificate has no RSA key.'
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ([bool]$signatureValid) 'R18R2 request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'R18R2 signed manifest identity changed.'
Require (@($manifest.files).Count -eq 29 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1 -and [string]$manifest.allowedProcessActions[0] -eq 'START_ONE_OWNED_BACKGROUND_R18R_REFERENCE_ISOLATED_SCRIBE_OCR_WORKER') 'R18R2 signed manifest action cardinality changed.'
Require ([string]$manifest.sourceProcessingContract.proposalRoot -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals' -and [int]$manifest.sourceProcessingContract.configuredCaseCount -eq 21 -and [int]$manifest.sourceProcessingContract.uniqueSourcePairCount -eq 21 -and [string]$manifest.sourceProcessingContract.cohortSha256 -eq '7393A6CB84F3CF246DCA3751DFCCB76422198C25270CA2759FBF260D2DE8AF56' -and [bool]$manifest.sourceProcessingContract.existingCropOnly -and -not [bool]$manifest.sourceProcessingContract.fullWaferImageReadAllowed -and -not [bool]$manifest.sourceProcessingContract.wholeWaferFallbackAllowed -and [bool]$manifest.sourceProcessingContract.checksumVerificationRequired -and -not [bool]$manifest.sourceProcessingContract.checksumUsedForImageFirst) 'R18R2 signed existing-crop-only source contract changed.'
Require ([string]$manifest.entryPointMutations[0].targetRoot -eq 'D:\A2\w\ocv\R18R2' -and [string]$manifest.entryPointMutations[1].targetRoot -eq 'D:\A2\o\ocv\R18R2' -and [string]$manifest.entryPointOutputs[0].path -eq 'D:\A2\o\ocv\R18R2\LAUNCH.json') 'R18R2 signed work/output root changed.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$manifest.sourceProcessingContract.sourceMutationAllowed) 'R18R2 signed manifest authority changed.'
Require (-not [bool]$manifest.publication.explicitOperatorAuthorityPresent) 'Frozen R18R2 manifest publication flag unexpectedly changed.'
Require (@($manifest.changes[0].approvedPredecessorSha256).Count -eq 1 -and [string]$manifest.changes[0].approvedPredecessorSha256[0] -eq [string]$manifest.changes[0].installedSha256) 'R18R2 signed create-only idempotent hash boundary changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18R2 signed request expired; publication refused.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18R2 publish requires clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18R2 persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18R2 portal request root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18R2 request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18R2 publication refused.'
if ($Preflight) {
    [ordered]@{schema='argos_opencv_scribe_r18r2_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R2_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipBytes=$sourceBytes;requestZipSha256=$zipSha;signatureVerified=$true;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;priorSameEndpointRequestTerminal=$true;maximumPublicationsAuthorized=1;retryAuthorized=$false;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$sourceStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18R2 staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18R2 ready path appeared before commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$gate = [ordered]@{schema='argos_opencv_scribe_r18r2_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R2_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;packageGateSha256=$packageGateSha;routeGateSha256=$routeGateSha;roundTripGateSha256=$roundTripGateSha;exactPathGateSha256=$exactPathGateSha;authoritySha256=$authoritySha;preactionSha256=$preactionSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublicationsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;taskActions=@();processActions=@('START_ONE_OWNED_BACKGROUND_R18R_REFERENCE_ISOLATED_SCRIBE_OCR_WORKER');configuredCaseCount=21;uniqueSourcePairCount=21;checksumVerificationRequired=$true;checksumUsedForImageFirst=$false;hardCodedEngineLiteralCount=0;sourceMutationPerformed=$false;identityAccepted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $publishGatePath -Value $gate
$gate | ConvertTo-Json -Depth 16
