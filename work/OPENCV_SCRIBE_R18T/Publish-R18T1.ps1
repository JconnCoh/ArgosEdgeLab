#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18T publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18T publication dependency changed: $Path"
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\','/'), $Name, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [int64]$matches[0].Length -le $MaximumBytes) "Missing, duplicated, or oversized request entry: $Name"
    $input = $matches[0].Open()
    $memory = New-Object IO.MemoryStream
    try { $input.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $input.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18T1'
$branch = 'codex/opencv-scribe-deciphering'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18T_FINAL_PACKAGE_GATE.json'
$runtimeGatePath = Join-Path $PSScriptRoot 'final\R18T_PACKAGED_RUNTIME_GATE.json'
$routeGatePath = $sourceZip + '.complete_route_gate.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18T_PATH_PLAN_GATE.json'
$handoffGatePath = Join-Path $PSScriptRoot 'R18T_SIGNED_UNPUBLISHED_READY_GATE_V2.json'
$authorityPath = Join-Path $PSScriptRoot 'R18T_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18T_PUBLICATION.json'
$priorTerminalGatePath = Join-Path $project 'work\OPENCV_SCRIBE_R18R2\R18R2_LAUNCH_RESPONSE_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18T1_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')
$zipSha = '3A6CDE8E0702D4BCE6D24A8AFF178376509A422E3DBDFD06B7FE517A99483313'

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath 'B77AB09EA377144D17319E545A55293501B3BE7B7F0780E6D85D5756BEB7B800'
Require-Pin $runtimeGatePath '3CE146E5C0C8C65B20E83513504277053EF4CA117400D6D9EF24CA79CCC57137'
Require-Pin $routeGatePath '11F4ECE581A4CB14EC7CA6C546391E7F0685E128C35AA9D13CEB5DD4BB0B1C22'
Require-Pin $pathGatePath '98B26B8AF73F290D9B52D6178B735C6747565AFF493AA0AD9F61EB8F4A59ABB9'
Require-Pin $handoffGatePath 'DA36A9E45AE722C762FC4768BA9EA3D91D389F8A8ECD92D582A2F23B5D48C302'
Require-Pin $authorityPath '491616206D540BD41C4057477881F5B8A84D377B2000844AF370053A77748A47'
Require-Pin $preactionPath '8B200F76423DF42E78C56F50D6327659FAB2566A545C4AB57B04FF8996735471'
Require-Pin $priorTerminalGatePath 'ECD1E67112AA9ED5FCDEE97895088A3A46D25EA3E820C275527679F4887824EE'
Require-Pin $signerCertificatePath '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
Require ([string](($preactionJson | ConvertFrom-Json).state) -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18T publication preaction changed.'
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$runtimeGate = Get-Content -LiteralPath $runtimeGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
$handoffGate = Get-Content -LiteralPath $handoffGatePath -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$priorTerminal = Get-Content -LiteralPath $priorTerminalGatePath -Raw | ConvertFrom-Json
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Require ([string]$packageGate.state -eq 'PASS_R18T_SIGNED_UNPUBLISHED_PACKAGE_GATE' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int64]$packageGate.requestZipBytes -eq $sourceBytes -and [int]$packageGate.finalZipMemberCount -eq 33 -and [int]$packageGate.payloadManifestFileCount -eq 29 -and [int]$packageGate.signedPayloadFileCount -eq 31 -and [bool]$packageGate.slot24PackageExcluded -and -not [bool]$packageGate.retryAuthorized) 'R18T final package gate changed.'
Require ([string]$runtimeGate.state -eq 'PASS_R18T_PACKAGED_RUNTIME_GATE' -and [string]$runtimeGate.requestId -eq $requestId -and [string]$runtimeGate.requestZipSha256 -eq $zipSha) 'R18T packaged runtime gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18T_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED' -and [string]$routeGate.requestId -eq $requestId -and [string]$routeGate.requestZipSha256 -eq $zipSha -and [int]$routeGate.actualFinalZipMemberCount -eq 33 -and [bool]$routeGate.publicationMustRecheckQueueAndNamespace -and [int]$routeGate.maximumEffectiveLength -lt 200 -and [int]$routeGate.unsafePathCount -eq 0) 'R18T complete route gate changed.'
Require ([string]$pathGate.state -eq 'PASS_PATH_BUDGET' -and [int]$pathGate.plannedFinalZipMemberCount -eq 33 -and [int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80 -and [int]$pathGate.unsafePathCount -eq 0) 'R18T path gate changed.'
Require ([string]$handoffGate.state -eq 'PASS_R18T_SIGNED_UNPUBLISHED_READY_GATE_V2' -and [int]$handoffGate.validation.requiredReadOrderCount -eq 27 -and [int]$handoffGate.validation.gateCount -eq 17) 'R18T V2 handoff gate changed.'
Require ([string]$authority.state -eq 'PASS_R18T_PUBLICATION_AUTHORITY' -and [string]$authority.requestId -eq $requestId -and @($authority.operatorAuthority) -contains 'PUBLISH for REQ_R18T1' -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized -and -not [bool]$authority.r18sAuthorized) 'R18T publication authority changed.'
Require ([string]$priorTerminal.state -eq 'PASS_R18R2_SIGNED_LAUNCH_RESPONSE_COLLECTED_AND_OUTPUT_ROOT_PROVED' -and [string]$priorTerminal.requestId -eq 'REQ_R18R2' -and [bool]$priorTerminal.signedResponseVerified -and [string]$priorTerminal.endpointState -eq 'PASS_MAINTENANCE_PATCH') 'Prior accepted same-endpoint request lacks a pinned signed portal response.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18T publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    Require (@($zip.Entries).Count -eq 33) 'R18T signed ZIP membership count changed.'
    $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.sig' 8192
} finally { $zip.Dispose() }
$manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ($signatureValid) 'R18T request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH' -and @($manifest.files).Count -eq 31) 'R18T signed manifest identity changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18T signed request expired; publication refused.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$manifest.sourceProcessingContract.automaticIdentityAuthority) 'R18T signed authority widened.'
Require ([int]$manifest.sourceProcessingContract.configuredCaseCount -eq 20 -and [int]$manifest.sourceProcessingContract.uniqueSourcePairCount -eq 20 -and [bool]$manifest.sourceProcessingContract.existingCropOnly -and -not [bool]$manifest.sourceProcessingContract.fullWaferImageReadAllowed -and -not [bool]$manifest.sourceProcessingContract.wholeWaferFallbackAllowed -and [bool]$manifest.sourceProcessingContract.checksumVerificationRequired -and -not [bool]$manifest.sourceProcessingContract.checksumUsedForImageFirst) 'R18T signed source contract changed.'
Require (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1 -and [string]$manifest.allowedProcessActions[0] -eq 'START_ONE_OWNED_BACKGROUND_R18T_EXECUTION_ENVELOPE_WORKER') 'R18T signed action set changed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18T publish requires clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18T persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18T portal request root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18T request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18T publication refused.'

$result = [ordered]@{schema='argos_opencv_scribe_r18t1_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($Preflight){'PASS_R18T1_PUBLISH_PREFLIGHT'}else{'PASS_R18T1_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW'});requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;signatureVerified=$true;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;priorSameEndpointRequestTerminal=$true;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublicationsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;taskActions=@();processActions=@('START_ONE_OWNED_BACKGROUND_R18T_EXECUTION_ENVELOPE_WORKER');configuredCaseCount=20;uniqueSourcePairCount=20;slot24PackageExcluded=$true;sourceMutationPerformed=$false;identityAccepted=$false;r18sAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false;mutationsPerformed=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 16; return }

$sourceStream = [IO.File]::Open($sourceZip,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18T staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18T ready path appeared before atomic commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$result.mutationsPerformed = $true
Write-JsonCreateNew $publishGatePath $result
$result | ConvertTo-Json -Depth 16
