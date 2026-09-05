#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'R18W2 publisher requires Windows PowerShell 5.1 exactly.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Require-Pin([string]$Path, [string]$Sha256) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18W2 publication dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18W2 publication dependency changed: $Path"
}
function Normalize-Root([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
    return $Value.Trim().TrimEnd('\').Replace('/', '\')
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\','/'), $Name, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [int64]$matches[0].Length -le $MaximumBytes) "Missing, duplicated, or oversized request entry: $Name"
    $input = $matches[0].Open(); $memory = New-Object IO.MemoryStream
    try { $input.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $input.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18W2'; $branch = 'codex/opencv-scribe-deciphering'
$zipSha = 'F1C77DCDC4962FEF7983CC93C9CE01F79C4B9E0CA54ADCEFAD9725AD5EF66D8E'
$sourceZip = Join-Path $PSScriptRoot 'final\REQ_R18W2.ready.zip'
$packageGatePath = Join-Path $PSScriptRoot 'R18W2_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W2_COMPLETE_ROUTE_GATE.json'
$freezeGatePath = Join-Path $PSScriptRoot 'R18W2_PRESIGNATURE_FREEZE_GATE.json'
$authorityPath = Join-Path $PSScriptRoot 'R18W2_PUBLICATION_AUTHORITY.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18W2_PUBLICATION.json'
$priorTerminalPath = Join-Path $project 'work\OPENCV_SCRIBE_R18T\R18T1_SIGNED_LAUNCH_RESPONSE_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signerCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$publishGatePath = Join-Path $PSScriptRoot 'R18W2_PUBLISH_GATE.json'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'; $responseRoot = 'U:\ProjectPortalRO\responses'
$readyPath = $requestRoot + '\' + $requestId + '.ready.zip'; $uploadPath = $readyPath + '.upload'
$processedPath = $requestRoot + '\processed\' + $requestId + '.ready.zip'

Require-Pin $sourceZip $zipSha
Require-Pin $packageGatePath 'E824A18819B1F6E058AE337D107C0CECB97AEFBAD8418FC88CC36C8E7A473CA1'
Require-Pin $routeGatePath '5359058FE1CDB9ACBA11DFBE0317B208B063E5FF1F3BB496C81E565D6AF093B5'
Require-Pin $freezeGatePath '6180770E8889815DA406C36849A6E54FC0D34A5C503F4B00D08A9CD4450CA00E'
Require-Pin $priorTerminalPath 'A3F37C4C9D0F4244D7574177E160AED65AEF136263F848D85FE5EEDCE3A98B6C'
Require-Pin $signerCertificatePath '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'

$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
Require ([string](($preactionJson | ConvertFrom-Json).state) -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18W2 publication preaction changed.'
$packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$freezeGate = Get-Content -LiteralPath $freezeGatePath -Raw | ConvertFrom-Json
$authority = Get-Content -LiteralPath $authorityPath -Raw | ConvertFrom-Json
$priorTerminal = Get-Content -LiteralPath $priorTerminalPath -Raw | ConvertFrom-Json
Require ([string]$packageGate.state -eq 'PASS_R18W2_FINAL_PACKAGE_GATE_SIGNED_UNPUBLISHED' -and [string]$packageGate.requestId -eq $requestId -and [string]$packageGate.requestZipSha256 -eq $zipSha -and [int]$packageGate.requestedFileCount -eq 1 -and -not [bool]$packageGate.retryAuthorized) 'R18W2 final package gate changed.'
Require ([string]$routeGate.state -eq 'PASS_R18W2_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED' -and [string]$routeGate.requestId -eq $requestId -and [int]$routeGate.routePathCount -eq 37 -and [int]$routeGate.maximumEffectiveLength -lt 200 -and [int]$routeGate.maximumComponentLength -le 80 -and [int]$routeGate.reservedSuffixCharacters -eq 32 -and @($routeGate.routeRows | Where-Object { [string]$_.state -ne 'PASS_PATH_BUDGET' }).Count -eq 0) 'R18W2 complete route gate changed.'
Require ([string]$freezeGate.state -eq 'PASS_R18W2_PRESIGNATURE_FREEZE' -and [string]$freezeGate.requestId -eq $requestId) 'R18W2 freeze gate changed.'
Require ([string]$authority.state -eq 'PASS_R18W2_PUBLICATION_AUTHORITY' -and [string]$authority.operatorAuthority -eq 'PUBLISH for REQ_R18W2' -and [int]$authority.maximumPublications -eq 1 -and -not [bool]$authority.retryAuthorized -and -not [bool]$authority.r18w3Authorized) 'R18W2 publication authority changed.'
Require ([string]$priorTerminal.requestId -eq 'REQ_R18T1' -and [bool]$priorTerminal.signedResponseVerified -and [string]$priorTerminal.state -eq 'PASS_R18T1_SIGNED_LAUNCH_RESPONSE_COLLECTED' -and [string]$priorTerminal.launchState -eq 'PASS_R18T_LIVE_ONLY_WORKER_STARTED' -and -not [bool]$priorTerminal.automaticRetryAllowed) 'Prior accepted portal request lacks its pinned signed launch response.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'R18W2 publication gate already exists; republish refused.'

Add-Type -AssemblyName System.IO.Compression; Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try { Require (@($zip.Entries).Count -eq 2) 'R18W2 ZIP membership changed.'; $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.json' 1048576; $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_REQUEST_MANIFEST.sig' 8192 } finally { $zip.Dispose() }
$manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($signerCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ($signatureValid) 'R18W2 request signature verification failed.'
Require ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'DATA_PULL' -and @($manifest.files).Count -eq 0) 'R18W2 signed manifest identity changed.'
Require ([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse([string]$manifest.expiresUtc)) 'R18W2 signed request expired; publication refused.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18W2 signed authority widened.'
Require ([string]$manifest.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [int]$manifest.parameters.maximumFiles -eq 1 -and [int64]$manifest.parameters.maximumBytes -eq 16777216 -and @($manifest.parameters.relativePaths).Count -eq 1 -and [string]$manifest.parameters.relativePaths[0] -eq 'identity/confirmed/ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json') 'R18W2 signed data-pull scope changed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim(); $localTip = (& git -C $project rev-parse HEAD | Out-String).Trim(); $remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim(); $status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'R18W2 publish requires the dedicated branch matching recorded origin.'
$allowedLocal = @('?? work/OPENCV_SCRIBE_R18W2/PREACTION_R18W2_PUBLICATION.json','?? work/OPENCV_SCRIBE_R18W2/Publish-R18W2.ps1','?? work/OPENCV_SCRIBE_R18W2/R18W2_PUBLICATION_AUTHORITY.json','?? work/OPENCV_SCRIBE_R18W2/R18W2_PUBLICATION_TOOLING_GATE.json')
Require (@($status | Where-Object { $_ -notin $allowedLocal }).Count -eq 0) 'R18W2 publish found unrelated worktree changes.'
$drive = Get-PSDrive -Name U -ErrorAction Stop; $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Require ($null -ne $disk -and [int]$disk.DriveType -eq 4 -and (Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase) -and (Normalize-Root ([string]$disk.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'R18W2 persistent U mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'R18W2 request root unavailable.'; Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'R18W2 response root unavailable.'
Require (-not (Test-Path -LiteralPath $uploadPath) -and -not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $processedPath)) 'R18W2 request identity already exists in route.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' })
Require ($pending.Count -eq 0) 'Another portal request is pending; R18W2 publication refused.'

$sourceBytes = [int64](Get-Item -LiteralPath $sourceZip).Length
$result = [ordered]@{schema='argos_opencv_scribe_r18w2_publish_gate_v1';publishedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($Preflight){'PASS_R18W2_PUBLISH_PREFLIGHT'}else{'PASS_R18W2_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW'});requestId=$requestId;publishedPath=$readyPath;bytes=$sourceBytes;sha256=$zipSha;signatureVerified=$true;expiresUtc=[string]$manifest.expiresUtc;queueState='NEW';pendingRequestCount=0;priorSameEndpointRequestSignedResponse=$true;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;createNew=$true;overwritePerformed=$false;maximumPublicationsAuthorized=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;expectedResponseSourceRole='JBOD';expectedResponseSignerThumbprint='DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC';persistentUMapping=$true;persistentUMappingRoot=$shareRoot;persistentUMappingLeftInPlace=$true;requestedRelativePaths=@('identity/confirmed/ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json');maximumFiles=1;maximumBytes=16777216;taskActions=@();processActions=@();imageBytesRead=$false;sourceMutationPerformed=$false;identityAccepted=$false;r18w3Authorized=$false;reviewOnly=$true;productionRoutingEnabled=$false;mutationsPerformed=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 16; return }
$sourceStream = [IO.File]::Open($sourceZip,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read); $targetStream = New-Object IO.FileStream($uploadPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $sourceStream.CopyTo($targetStream); $targetStream.Flush($true) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
Require ([int64](Get-Item -LiteralPath $uploadPath).Length -eq $sourceBytes -and (Get-Sha256 $uploadPath) -eq $zipSha) 'R18W2 staged upload verification failed.'
Require (-not (Test-Path -LiteralPath $readyPath)) 'R18W2 ready path appeared before atomic commit.'
Move-Item -LiteralPath $uploadPath -Destination $readyPath; $result.mutationsPerformed = $true
Write-JsonCreateNew $publishGatePath $result
$result | ConvertTo-Json -Depth 16
