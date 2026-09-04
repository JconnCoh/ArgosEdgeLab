#Requires -Version 5.1
# Clone-audit historical template root only: D:\KLARFExport is not read by R18O.
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18O publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18O publication dependency changed: $Path"
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
$requestId = 'REQ_R18O2'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18O_FINAL_PACKAGE_GATE.json'
$routeGatePath = $sourceZip + '.complete_route_gate.json'
$roundTripGatePath = Join-Path $PSScriptRoot 'R18O_FULL_ROUND_TRIP_PATH_GATE.json'
$exactPathGatePath = Join-Path $PSScriptRoot 'R18O_EXACT_PACKAGE_PATH_GATE.json'
$authorityPath = Join-Path $PSScriptRoot 'R18O_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18O_EXISTING_CROPS_PUBLICATION.json'
$checkpointPath = Join-Path $project 'work\OPENCV_SCRIBE_R18N\R18N_COMPLETE_SCRIBE_ROLLOVER_CHECKPOINT_20260904.md'
$stopCheckpointPath = Join-Path $project 'work\OPENCV_SCRIBE_R18N\R18N_PUBLISHED_OPERATOR_STOP_BLOCKED_CHECKPOINT_20260904.md'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18O_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'
$uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'
$zipSha = '0DC7D8D3FE59AD2296A036DCE04AA425CA20C859EAB2B7B0F1EEC9A8A9A09B36'
$packageGateSha = 'C528052F95F41A93B388F942B93FE5B0B00CF4654C6D91F03781FEDB0C84035A'
$routeGateSha = '1348489FAD2567B2B0A6B26CE86863270DC3078435F8CAA32124338396AE04AB'
$roundTripGateSha = 'DE68A5F8EBAE6DE8D65DE8126E002D9273A3287EBBFBD32768E984FD8A1FC5EE'
$exactPathGateSha = '5426C1C4A002D207176849F8D4F9C82C86FE4E58E0B73CC4F781E7BF5504C9E0'
$authoritySha = '6639F8F7F7B8ED373A48C1871C95C1723300F7E6C00A3DA8AB6A812F48546302'
$preactionSha = '9AEC70403F326592A241C7A26A03A8DD2A5076D4CC849806321D758C51D3F266'
$checkpointSha = '898F79913F3E210D8D074C895D4F0742CAB2C585D99A1CE6AEC53E5A0BDC2484'
$stopCheckpointSha = '60C0C27CCD67546FB71B2F26E629C59BB9B721B30A3F056FF68333AB9B4508B1'

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath $packageGateSha
Require-Pin $routeGatePath $routeGateSha
Require-Pin $roundTripGatePath $roundTripGateSha
Require-Pin $exactPathGatePath $exactPathGateSha
Require-Pin $authorityPath $authoritySha
Require-Pin $preactionPath $preactionSha
Require-Pin $checkpointPath $checkpointSha
Require-Pin $stopCheckpointPath $stopCheckpointSha
Require-Pin $signerCertificatePath '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
$preaction = $preactionJson | ConvertFrom-Json
Require ([string]$preaction.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18O publication preaction changed.'
$packageGate = Get-Content -Raw -LiteralPath $packageGatePath | ConvertFrom-Json
$routeGate = Get-Content -Raw -LiteralPath $routeGatePath | ConvertFrom-Json
$roundTripGate = Get-Content -Raw -LiteralPath $roundTripGatePath | ConvertFrom-Json
$exactPathGate = Get-Content -Raw -LiteralPath $exactPathGatePath | ConvertFrom-Json
$authority = Get-Content -Raw -LiteralPath $authorityPath | ConvertFrom-Json
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Require ([string]$packageGate.state -eq 'PASS_R18O_FINAL_PACKAGE_GATE' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int64]$packageGate.requestZipBytes -eq $sourceBytes -and [int]$packageGate.finalZipFileCount -eq 27 -and [int]$packageGate.maximumEffectiveLength -lt 200) 'R18O package gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18O_COMPLETE_ROUTE_GATE' -and [string]$routeGate.requestId -eq $requestId -and [string]$routeGate.requestZipSha256 -eq $zipSha -and [int]$routeGate.actualFinalZipMemberCount -eq 27 -and [bool]$routeGate.deepestPayloadLeafIncludedAtEveryExtractionHop -and [int]$routeGate.maximumEffectiveLength -lt 200 -and [int]$routeGate.pendingRequestCount -eq 0) 'R18O complete route gate changed.'
Require ([string]$roundTripGate.state -eq 'PASS_R18O_FULL_ROUND_TRIP_PATH_GATE' -and [string]$roundTripGate.requestId -eq $requestId -and [string]$roundTripGate.requestZipSha256 -eq $zipSha -and [int]$roundTripGate.candidateCount -eq 26 -and [int]$roundTripGate.maximumEffectiveLength -lt 200 -and [int]$roundTripGate.unsafePathCount -eq 0) 'R18O full round-trip path gate changed.'
Require ([string]$exactPathGate.state -eq 'PASS_R18O_EXACT_PACKAGE_PATHS' -and [string]$exactPathGate.requestId -eq $requestId -and [string]$exactPathGate.requestZipSha256 -eq $zipSha -and [bool]$exactPathGate.entrypointDefaultsMatchSignedDefinition -and [int]$exactPathGate.maximumEffectiveLength -lt 200) 'R18O exact-package path gate changed.'
Require ([string]$authority.state -eq 'PASS_R18O_PUBLICATION_AUTHORITY' -and [string]$authority.requestId -eq $requestId -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized -and @($authority.operatorAuthority) -contains 'PUBLISH') 'R18O publication authority changed.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18O publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $entries = @($archive.Entries)
    Require ($entries.Count -eq 27) 'R18O signed ZIP membership count changed.'
    $manifestEntry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.json')
    $signatureEntry = $archive.GetEntry('PORTAL_REQUEST_MANIFEST.sig')
    Require ($null -ne $manifestEntry -and $null -ne $signatureEntry) 'R18O signed manifest or signature entry absent.'
    $manifestBytes = Read-ZipEntryBytes $manifestEntry
    $signatureBytes = Read-ZipEntryBytes $signatureEntry
    $manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
}
finally { $archive.Dispose() }
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
Require ($null -ne $rsa) 'Pinned request signer certificate has no RSA key.'
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ([bool]$signatureValid) 'R18O request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'R18O signed manifest identity changed.'
Require (@($manifest.files).Count -eq 25 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1) 'R18O signed manifest action cardinality changed.'
Require ([string]$manifest.sourceProcessingContract.proposalRoot -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals' -and [bool]$manifest.sourceProcessingContract.existingCropOnly -and -not [bool]$manifest.sourceProcessingContract.fullWaferImageReadAllowed -and -not [bool]$manifest.sourceProcessingContract.wholeWaferFallbackAllowed) 'R18O signed existing-crop-only source contract changed.'
Require ([string]$manifest.entryPointMutations[0].targetRoot -eq 'D:\A2\w\ocv\R18O2' -and [string]$manifest.entryPointMutations[1].targetRoot -eq 'D:\A2\o\ocv\R18O2' -and [string]$manifest.entryPointOutputs[0].path -eq 'D:\A2\o\ocv\R18O2\LAUNCH.json') 'R18O signed work/output root changed.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$manifest.sourceProcessingContract.sourceMutationAllowed) 'R18O signed manifest authority changed.'
Require (-not [bool]$manifest.publication.explicitOperatorAuthorityPresent) 'Frozen R18O manifest publication flag unexpectedly changed.'
Require (@($manifest.changes[0].approvedPredecessorSha256).Count -eq 1 -and [string]$manifest.changes[0].approvedPredecessorSha256[0] -eq [string]$manifest.changes[0].installedSha256) 'R18O signed create-only idempotent hash boundary changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18O signed request expired; publication refused.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18O publish requires clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18O persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18O portal request root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18O request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18O publication refused.'
if ($Preflight) {
    [ordered]@{schema='argos_opencv_scribe_r18o_publish_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18O_PUBLISH_PREFLIGHT';requestId=$requestId;requestZipBytes=$sourceBytes;requestZipSha256=$zipSha;signatureVerified=$true;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;maximumPublicationsAuthorized=1;retryAuthorized=$false;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$sourceStream = [IO.File]::Open($sourceZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18O staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18O ready path appeared before commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
    $gate = [ordered]@{schema='argos_opencv_scribe_r18o_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18O_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW';disposition='PENDING_GATE';requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;packageGateSha256=$packageGateSha;routeGateSha256=$routeGateSha;roundTripGateSha256=$roundTripGateSha;exactPathGateSha256=$exactPathGateSha;authoritySha256=$authoritySha;preactionSha256=$preactionSha;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublicationsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;persistentUMappingRemoved=$false;taskActions=@();processActions=@('START_ONE_OWNED_BACKGROUND_R18O_SCRIBE_CROP_OCR_WORKER');sourceMutationPerformed=$false;identityAccepted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $publishGatePath -Value $gate
$gate | ConvertTo-Json -Depth 16
