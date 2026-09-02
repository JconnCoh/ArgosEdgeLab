#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Publish)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Normalize-Root([string]$Path) { ([IO.Path]::GetFullPath($Path)).TrimEnd('\') }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$definitionPath = Join-Path $PSScriptRoot 'STATUS_DEFINITION.json'
$requestId = 'REQ_20260902T001500111Z_62619433S22M'
$stageRoot = 'C:\S22M1'
$readyDir = Join-Path $stageRoot ($requestId + '.ready')
$zipPath = Join-Path $stageRoot ($requestId + '.ready.zip')
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')
$share = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

Assert-True ((Get-Sha $identityPath) -eq '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289') 'Signing identity record changed.'
Assert-True ((Get-Sha $publicCertificate) -eq '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF') 'Laptop signer certificate changed.'
Assert-True ((Get-Sha $packageTester) -eq '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B') 'Package verifier changed.'
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'STATUS') 'STATUS route changed.'
$inventory = $definition.parameters.environmentInventory
Assert-True ([string]$inventory.approvedDataRoot -eq 'JBOD_KLARF_EXPORT' -and [string]$inventory.processLocalAliasName -eq 'F') 'Approved root or alias changed.'
Assert-True ([string]$inventory.boundedSubtreeInventory.relativeRoot -eq 'PatternedFront/Lot_62619-433/62619-433_20260824005735/Slot22/BrightfieldFrontsideWafer/resizedImage') 'Exact Slot22 subtree changed.'
Assert-True ([int]$inventory.boundedSubtreeInventory.maximumDepth -eq 1 -and [int]$inventory.boundedSubtreeInventory.maximumEntries -eq 64) 'Inventory bound changed.'

$drive = Get-PSDrive U -PSProvider FileSystem -ErrorAction Stop
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $share), [StringComparison]::OrdinalIgnoreCase)) 'PowerShell U mapping changed.'
Assert-True ([int]$logical.DriveType -eq 4 -and (Normalize-Root ([string]$logical.ProviderName)).Equals((Normalize-Root $share), [StringComparison]::OrdinalIgnoreCase)) 'Logical U mapping changed.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -Force | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' })
Assert-True ($pending.Count -eq 0) 'Another portal request is pending.'
foreach ($target in @($stageRoot,$readyPath,$uploadPath,$processedPath)) { Assert-True (-not (Test-Path -LiteralPath $target)) "Create-new target exists: $target" }

$planned = @($readyDir,(Join-Path $readyDir 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $readyDir 'PORTAL_REQUEST_MANIFEST.sig'),$zipPath,$readyPath,$uploadPath,$processedPath,'C:\APR\S\requests\'+$requestId+'.ready.zip','C:\ProgramData\ArgosProjectPortalRO\share\staging\'+$requestId+'.ready.zip','C:\ProgramData\ArgosProjectPortalRO\share\request_archive\'+$requestId+'.ready.zip','C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_12345678\RESULT.json','C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\responses\partial\R_0123456789AB_20260902001600999_12345678.partial\RESULT.json','U:\ProjectPortalRO\responses\R_0123456789AB_20260902001600999_12345678.ready.zip','C:\S22M1R\R_0123456789AB_20260902001600999_12345678.ready.zip')
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'Complete route path gate failed.'

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try { $matches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant() -eq $thumbprint }); Assert-True ($matches.Count -eq 1 -and $matches[0].HasPrivateKey) 'Signer private key unavailable.'; $certificate = $matches[0] }
finally { $store.Close(); $store.Dispose() }

$result = [ordered]@{schema='argos_slot22_marked_metadata_request_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=if($Preflight){'PASS_SLOT22_MARKED_METADATA_PREFLIGHT'}else{'PASS_SLOT22_MARKED_METADATA_REQUEST_PUBLISHED_ONCE'};requestId=$requestId;exactSubtree=[string]$inventory.boundedSubtreeInventory.relativeRoot;metadataOnly=$true;imageBytesRead=$false;sourceHashingPerformed=$false;sourceMutationPerformed=$false;maximumPublications=1;retryAuthorized=$false;pathGateState=[string]$pathGate.state;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 8; return }

$branch = (& git -C $project branch --show-current | Out-String).Trim()
$local = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remote = (& git -C $project rev-parse origin/codex/opencv-scribe-deciphering | Out-String).Trim()
Assert-True ($branch -eq 'codex/opencv-scribe-deciphering' -and $local -eq $remote) 'Scribe branch tips differ.'
Assert-True (@(& git -C $project status --porcelain=v1).Count -eq 0) 'Scribe worktree is not clean.'

[void](New-Item -ItemType Directory -Path $readyDir)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='STATUS';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@();parameters=$definition.parameters}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestPath = Join-Path $readyDir 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyDir 'PORTAL_REQUEST_MANIFEST.sig'
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath,$signature)
$verify = & $packageTester -PackagePath $readyDir -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass STATUS
Assert-True ([string]$verify.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and [string]$verify.RequestId -eq $requestId) 'Signed STATUS package verification failed.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($readyDir,$zipPath,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.File]::Copy($zipPath,$uploadPath,$false)
Assert-True ((Get-Sha $uploadPath) -eq (Get-Sha $zipPath)) 'Upload copy changed.'
[IO.File]::Move($uploadPath,$readyPath)
Assert-True ((Get-Sha $readyPath) -eq (Get-Sha $zipPath)) 'Published copy changed.'
$result.zipSha256 = Get-Sha $zipPath
$result.zipBytes = [int64](Get-Item -LiteralPath $zipPath).Length
$result.publishedPath = $readyPath
$result.localTip = $local
$result.remoteTip = $remote
$result | ConvertTo-Json -Depth 8
