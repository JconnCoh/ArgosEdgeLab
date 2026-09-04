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
$definitionPath = Join-Path $PSScriptRoot 'R18J2_POST_FAILURE_STATUS_DEFINITION.json'
$intentPath = Join-Path $PSScriptRoot 'RECOVERY_INTENT_R18J2_POST_FAILURE_STATUS.json'
$failureGatePath = Join-Path $PSScriptRoot 'R18J2_SIGNED_TERMINAL_FAILURE_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18J2_POST_FAILURE_STATUS_PATH_GATE.json'
$requestId = 'REQ_20260904T021000000Z_R18J2OBS'
$stageRoot = 'C:\R18J2O1'
$readyDir = Join-Path $stageRoot ($requestId + '.ready')
$zipPath = Join-Path $stageRoot ($requestId + '.ready.zip')
$besidePathGate = Join-Path $stageRoot 'R18J2_POST_FAILURE_STATUS_PATH_GATE.json'
$requestRoot = 'U:\ProjectPortalRO\requests'
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
$processedPath = Join-Path (Join-Path $requestRoot 'processed') ($requestId + '.ready.zip')
$share = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$intentTester = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'

Assert-True ((Get-Sha $identityPath) -eq '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289') 'Signing identity record changed.'
Assert-True ((Get-Sha $publicCertificate) -eq '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF') 'Laptop signer certificate changed.'
Assert-True ((Get-Sha $packageTester) -eq '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B') 'Package verifier changed.'
Assert-True ((Get-Sha $failureGatePath) -eq '2907832D0C9475DF66A60A428FCE8D3094D45EA485B907877226DD7A9C51AE98') 'Signed failure gate changed.'

$intentResult = & $intentTester -IntentPath $intentPath -ProjectRoot $project -Preflight -AsJson | ConvertFrom-Json
Assert-True ([string]$intentResult.state -eq 'PASS_ARGOS_RECOVERY_INTENT' -and [string]$intentResult.mode -eq 'OBSERVE') 'Recovery observation intent failed.'
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'STATUS') 'STATUS route changed.'
Assert-True (-not [bool]$definition.parameters.environmentInventory.enabled) 'Environment inventory must remain disabled.'
Assert-True ([bool]$definition.reviewOnly -and -not [bool]$definition.productionRoutingEnabled) 'STATUS authority changed.'
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_R18J2_POST_FAILURE_STATUS_COMPLETE_ROUTE_GATE' -and [string]$pathGate.requestId -eq $requestId) 'STATUS route path gate changed.'
Assert-True ([int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumObservedComponentLength -le 80) 'STATUS route path budget is unsafe.'

$drive = Get-PSDrive U -PSProvider FileSystem -ErrorAction Stop
$logical = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$drive.DisplayRoot)).Equals((Normalize-Root $share), [StringComparison]::OrdinalIgnoreCase)) 'PowerShell U mapping changed.'
Assert-True ([int]$logical.DriveType -eq 4 -and (Normalize-Root ([string]$logical.ProviderName)).Equals((Normalize-Root $share), [StringComparison]::OrdinalIgnoreCase)) 'Logical U mapping changed.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File -Force | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' })
Assert-True ($pending.Count -eq 0) 'Another portal request is pending.'
foreach ($target in @($stageRoot,$readyPath,$uploadPath,$processedPath)) { Assert-True (-not (Test-Path -LiteralPath $target)) "Create-new target exists: $target" }

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $matches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant() -eq $thumbprint })
    Assert-True ($matches.Count -eq 1 -and $matches[0].HasPrivateKey) 'Signer private key unavailable.'
    $certificate = $matches[0]
} finally { $store.Close(); $store.Dispose() }

$result = [ordered]@{
    schema='argos_r18j2_post_failure_status_publish_gate_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state=if($Preflight){'PASS_R18J2_POST_FAILURE_STATUS_PREFLIGHT'}else{'PASS_R18J2_POST_FAILURE_STATUS_PUBLISHED_ONCE'}
    requestId=$requestId
    mode='OBSERVE'
    imageBytesRead=$false
    sourceMutationPerformed=$false
    installedCodeChanged=$false
    taskActions=@()
    processActions=@()
    maximumPublications=1
    retryAuthorized=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 8; return }

$branch = (& git -C $project branch --show-current | Out-String).Trim()
$local = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remote = (& git -C $project rev-parse origin/codex/opencv-scribe-deciphering | Out-String).Trim()
Assert-True ($branch -eq 'codex/opencv-scribe-deciphering' -and $local -eq $remote) 'Scribe branch tips differ.'
Assert-True (@(& git -C $project status --porcelain=v1).Count -eq 0) 'Scribe worktree is not clean.'

[void](New-Item -ItemType Directory -Path $readyDir)
[IO.File]::Copy($pathGatePath,$besidePathGate,$false)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1'
    requestId=$requestId
    createdUtc=$created.ToString('o')
    expiresUtc=$created.AddHours(24).ToString('o')
    targetRole='JBOD'
    jobClass='STATUS'
    handler=''
    maxResultBytes=[int64]$definition.maxResultBytes
    reviewOnly=$true
    trainingEligible=$false
    xmlEligible=$false
    productionEligible=$false
    productionRoutingEnabled=$false
    credentialsIncluded=$false
    signerThumbprint=$thumbprint
    signatureAlgorithm='RSA-SHA256-PKCS1'
    files=@()
    parameters=$definition.parameters
}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestPath = Join-Path $readyDir 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyDir 'PORTAL_REQUEST_MANIFEST.sig'
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
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
