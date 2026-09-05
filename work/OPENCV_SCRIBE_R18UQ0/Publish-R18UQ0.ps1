#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18UQ0 publisher requires Windows PowerShell 5.1 exactly.'
}

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18UQ0 publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18UQ0 publication dependency changed: $Path"
}
function Normalize-Root([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return $Value.Trim().TrimEnd('\').Replace('/', '\')
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
$requestId = 'REQ_R18UQ0'
$branch = 'codex/opencv-scribe-deciphering'
$zipSha = '7DA7922BE356786B251B4ADD0656119A72474F456EA1BAC6B1E7DFCA49FE77C4'
$sourceZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18UQ0_FINAL_PACKAGE_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18UQ0_PATH_GATE.json'
$recoveryIntentPath = Join-Path $PSScriptRoot 'R18UQ0_RECOVERY_INTENT.json'
$recoveryGatePath = Join-Path $PSScriptRoot 'R18UQ0_RECOVERY_INTENT_GATE.json'
$authorityPath = Join-Path $PSScriptRoot 'R18UQ0_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18UQ0_PUBLICATION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18UQ0_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$responseRoot = 'U:\ProjectPortalRO\responses'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath '1561391F8E58938FF02FFD33ECC7E28066D2FDBD17DAF472FD08881102D4B34D'
Require-Pin $pathGatePath 'A8BE45C14ED02B9C4212C30C0842475B7C3A0800DABC8B1F6DD2988AD7BAA797'
Require-Pin $recoveryIntentPath 'D67407C520CF797ABBC15BC62C64D7B388D05D09CC65D408B075CEE1670A8649'
Require-Pin $recoveryGatePath 'D0C84A849EE66ACD76769751C9E50E1F33A63004E61A6C1AC0C418DB232384A5'
Require-Pin $authorityPath '2E8E59B92BEC9A12B5800A4EAA5A2DE0BA14B036A99B762B6441FE633C49E492'
Require-Pin $preactionPath '44202B252A4F24A918E3C983CFA61A593300462279BCC73D8917AFBB0913ED87'
Require-Pin $signerCertificatePath '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
Require ([string](($preactionJson | ConvertFrom-Json).state) -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18UQ0 publication preaction changed.'
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
$intent = Get-Content -LiteralPath $recoveryIntentPath -Raw | ConvertFrom-Json
$recoveryGate = Get-Content -LiteralPath $recoveryGatePath -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
Require ([string]$packageGate.state -eq 'PASS_R18UQ0_SIGNED_UNPUBLISHED_PACKAGE_GATE' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int64]$packageGate.requestZipBytes -eq $sourceBytes -and [int]$packageGate.finalZipMemberCount -eq 3 -and [int]$packageGate.endpointManagedInstalledFileCount -eq 1 -and -not [bool]$packageGate.retryAuthorized) 'R18UQ0 final package gate changed.'
Require ([string]$pathGate.state -eq 'PASS_R18UQ0_ROUND_TRIP_PATH_GATE' -and [int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80 -and [int]$pathGate.unsafePathCount -eq 0) 'R18UQ0 path gate changed.'
Require ([string]$intent.mode -eq 'MUTATE' -and [string]$intent.mutation.supportedRemedy -eq 'B' -and [bool]$intent.mutation.singleMutationAttemptAuthorized -and [bool]$intent.mutation.publicationAuthorized -and -not [bool]$intent.mutation.automaticRetryAuthorized) 'R18UQ0 recovery intent changed.'
Require ([string]$recoveryGate.state -eq 'PASS_ARGOS_RECOVERY_INTENT' -and [string]$recoveryGate.mode -eq 'MUTATE') 'R18UQ0 recovery-intent gate changed.'
Require ([string]$authority.state -eq 'PASS_R18UQ0_PUBLICATION_AUTHORITY' -and [string]$authority.requestId -eq $requestId -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized) 'R18UQ0 publication authority changed.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18UQ0 publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    Require (@($zip.Entries).Count -eq 3) 'R18UQ0 signed ZIP membership count changed.'
    $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.sig' 8192
} finally { $zip.Dispose() }
$manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ($signatureValid) 'R18UQ0 request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'ARGOS' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$manifest.entryPoint -eq 'payload/R18UQ0.ps1' -and @($manifest.files).Count -eq 1 -and @($manifest.changes).Count -eq 1) 'R18UQ0 signed manifest identity changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18UQ0 signed request expired; publication refused.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18UQ0 signed authority widened.'
Require (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 0) 'R18UQ0 signed task/process action set changed.'
$change = $manifest.changes[0]
Require ([string]$change.destination -eq 'C:\ProgramData\ArgosInsiteBridgeRO\hotfixes\R18UQ0.ps1' -and [string]$change.installedSha256 -eq 'B6E5A12E2A3D2E5B1397F9CB169E82E32419A8BA21F2DF0B5CE71718D465F1AF' -and [bool]$change.allowCreate -and @($change.approvedPredecessorSha256).Count -eq 1 -and [string]$change.approvedPredecessorSha256[0] -eq [string]$change.installedSha256) 'R18UQ0 signed one-file mutation contract changed.'
Require ([string]$manifest.mutationContract.mode -eq 'MUTATE' -and [string]$manifest.mutationContract.remedy -eq 'B' -and [int]$manifest.mutationContract.endpointManagedInstalledFileCount -eq 1 -and -not [bool]$manifest.mutationContract.entryPointWritesPerformed -and -not [bool]$manifest.mutationContract.queryExecuted -and -not [bool]$manifest.mutationContract.taskOrProcessActionPerformed -and -not [bool]$manifest.mutationContract.imageBytesRead -and -not [bool]$manifest.mutationContract.jbodContacted) 'R18UQ0 signed mutation boundary changed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18UQ0 publish requires a clean dedicated branch matching recorded origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($null -ne $logical -and [int]$logical.DriveType -eq 4 -and (Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase) -and (Normalize-Root ([string]$logical.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'R18UQ0 persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18UQ0 portal request root unavailable.'
Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'R18UQ0 portal response root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18UQ0 request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18UQ0 publication refused.'

$result = [ordered]@{
    schema='argos_opencv_scribe_r18uq0_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');
    state=$(if($Preflight){'PASS_R18UQ0_PUBLISH_PREFLIGHT'}else{'PASS_R18UQ0_EXACT_SIGNED_ARGOS_MAINTENANCE_PUBLISHED_CREATE_NEW'});
    requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;signatureVerified=$true;
    expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;
    createNew=$true;overwritePerformed=$false;maximumPublicationsAuthorized=1;retryAuthorized=$false;
    matchingSignedTerminalResponseCollectionOnly=$true;expectedResponseSourceRole='ARGOS';expectedResponseSignerThumbprint='5C00B8E35A9F5AC21DC051D7C2D9FD68D9361E48';
    persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;
    endpointManagedInstalledFileCount=1;entryPointWritesPerformed=$false;queryExecuted=$false;taskActions=@();processActions=@();
    imageBytesRead=$false;jbodContacted=$false;sourceMutationPerformed=$false;fullKlarfAuthorized=$false;
    reviewOnly=$true;productionRoutingEnabled=$false;mutationsPerformed=$false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 16; return }

$sourceStream = [IO.File]::Open($sourceZip,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
$targetStream = New-Object IO.FileStream($uploadPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18UQ0 staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18UQ0 ready path appeared before atomic commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath
$result.mutationsPerformed = $true
Write-JsonCreateNew $publishGatePath $result
$result | ConvertTo-Json -Depth 16
