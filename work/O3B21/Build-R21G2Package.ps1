#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-G2([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-G2Hash([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Assert-G2Pin([string]$Path, [string]$Expected) {
    Assert-G2 (Test-Path -LiteralPath $Path -PathType Leaf) "R21G2 dependency is absent: $Path"
    Assert-G2 ((Get-G2Hash $Path) -eq $Expected) "R21G2 dependency hash changed: $Path"
}

$actions = 0
if ($Preflight) { $actions++ }
if ($Build) { $actions++ }
Assert-G2 ($actions -eq 1) 'Select exactly one R21G2 build action.'

$requestId = 'REQ_20260831T153100000Z_21A5E991C602'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$entry = Join-Path $PSScriptRoot 'R21G2_E.ps1'
$marker = Join-Path $PSScriptRoot 'R21G2_M.json'
Assert-G2Pin $entry '6078F956EC3DF67C9FAFC366913681F7AC1BEE63C6A32064ABF0A6354473A11B'
Assert-G2Pin $marker '4C214E7D77D8F47C1FD7404BF221BE13C0C554D051F7D871E41E3BCB38BFEC93'

$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
Assert-G2Pin $identityPath '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-G2 ([bool]$certificate.HasPrivateKey) 'R21G2 signer private key is absent.'

$stage = 'C:\R21G2'
$partial = Join-Path $stage ($requestId + '.partial')
$ready = Join-Path $stage ($requestId + '.ready')
$final = 'C:\R21G2A'
$zip = Join-Path $final ($requestId + '.ready.zip')
foreach ($path in @($stage, $partial, $ready, $final, $zip)) {
    Assert-G2 (-not (Test-Path -LiteralPath $path)) "R21G2 create-new path exists: $path"
}

if ($Preflight) {
    [ordered]@{
        state = 'PASS_R21G2_BUILD_PREFLIGHT'
        requestId = $requestId
        stageRoot = $stage
        finalRoot = $final
        entrypointSha256 = Get-G2Hash $entry
        markerSha256 = Get-G2Hash $marker
        allowedTaskActions = @('RESTART:ArgosProjectPortal.Gateway.ShareBridge.RO')
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload'))
Copy-Item -LiteralPath $entry -Destination (Join-Path $partial 'payload\E.ps1') -ErrorAction Stop
Copy-Item -LiteralPath $marker -Destination (Join-Path $partial 'payload\M.json') -ErrorAction Stop
$records = @(
    [ordered]@{ path = 'payload/E.ps1'; bytes = [int64](Get-Item -LiteralPath $entry).Length; sha256 = Get-G2Hash $entry }
    [ordered]@{ path = 'payload/M.json'; bytes = [int64](Get-Item -LiteralPath $marker).Length; sha256 = Get-G2Hash $marker }
)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = $requestId
    createdUtc = $created.ToString('o')
    expiresUtc = $created.AddHours(24).ToString('o')
    targetRole = 'GATEWAY'
    jobClass = 'MAINTENANCE_PATCH'
    handler = 'SIGNED_REVIEW_ONLY_PATCH_V1'
    maxResultBytes = 1048576
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    credentialsIncluded = $false
    signerThumbprint = $thumbprint
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    files = $records
    entryPoint = 'payload/E.ps1'
    changes = @(
        [ordered]@{ source = 'payload/E.ps1'; destination = 'C:\ProgramData\ArgosGatewayMaintenanceRO\managed\R21G2.ps1'; approvedPredecessorSha256 = @('6078F956EC3DF67C9FAFC366913681F7AC1BEE63C6A32064ABF0A6354473A11B'); installedSha256 = '6078F956EC3DF67C9FAFC366913681F7AC1BEE63C6A32064ABF0A6354473A11B'; allowCreate = $true }
        [ordered]@{ source = 'payload/M.json'; destination = 'C:\ProgramData\ArgosGatewayMaintenanceRO\managed\R21G2.marker.json'; approvedPredecessorSha256 = @('4C214E7D77D8F47C1FD7404BF221BE13C0C554D051F7D871E41E3BCB38BFEC93'); installedSha256 = '4C214E7D77D8F47C1FD7404BF221BE13C0C554D051F7D871E41E3BCB38BFEC93'; allowCreate = $true }
    )
    allowedTaskActions = @('RESTART:ArgosProjectPortal.Gateway.ShareBridge.RO')
    rehearsal = [ordered]@{ requiredState = 'PASS_R21G2_CURRENT_REQUEST_SHAREBRIDGE_RESTART_REHEARSAL' }
    requestRetryAuthorized = $false
}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
Move-Item -LiteralPath $partial -Destination $ready -ErrorAction Stop
[void](New-Item -ItemType Directory -Path $final)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($ready, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
[ordered]@{
    state = 'PASS_R21G2_FRESH_SIGNED_DIRECT_PACKAGE'
    requestId = $requestId
    zipPath = $zip
    zipBytes = [int64](Get-Item -LiteralPath $zip).Length
    zipSha256 = Get-G2Hash $zip
    manifestSha256 = Get-G2Hash (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json')
    signatureSha256 = Get-G2Hash (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6
