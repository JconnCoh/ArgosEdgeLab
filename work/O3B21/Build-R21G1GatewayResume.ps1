#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-R21G1([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-R21G1Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}
function Assert-R21G1Pin([string]$Path, [string]$Expected) {
    Assert-R21G1 (Test-Path -LiteralPath $Path -PathType Leaf) "R21G1 dependency is absent: $Path"
    Assert-R21G1 ((Get-R21G1Hash $Path) -eq $Expected) "R21G1 dependency hash changed: $Path"
}

$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Build) { $modeCount++ }
Assert-R21G1 ($modeCount -eq 1) 'Select exactly one R21G1 action.'

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$planPath = Join-Path $PSScriptRoot 'R21G1_PLAN.json'
$plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json
Assert-R21G1 ([string]$plan.schema -eq 'argos_r21g1_gateway_resume_plan_v1') 'R21G1 plan schema changed.'
Assert-R21G1 ([string]$plan.requestId -eq 'REQ_20260831T152321980Z_0F7B21A5E991') 'R21G1 request identity changed.'
Assert-R21G1 ([string]$plan.stageRoot -eq 'C:\R21G1') 'R21G1 staging root changed.'
Assert-R21G1 ([string]$plan.finalRoot -eq 'C:\R21G1A') 'R21G1 final root changed.'
Assert-R21G1 (@($plan.allowedTaskActions).Count -eq 1) 'R21G1 task-action count changed.'
Assert-R21G1 ([string]$plan.allowedTaskActions[0] -eq 'RESTART:ArgosProjectPortal.Gateway.ShareBridge.RO') 'R21G1 task action changed.'
Assert-R21G1 ([bool]$plan.reviewOnly -and -not [bool]$plan.productionRoutingEnabled) 'R21G1 authority changed.'

foreach ($row in @($plan.payloads)) {
    Assert-R21G1Pin (Join-Path $project ([string]$row.source)) ([string]$row.sha256)
}
Assert-R21G1Pin (Join-Path $project ([string]$plan.sourceFinalPackageGate)) ([string]$plan.sourceFinalPackageGateSha256)

$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
Assert-R21G1Pin $identityPath '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-R21G1 ([bool]$certificate.HasPrivateKey) 'R21G1 signer private key is absent.'

$stageRoot = [IO.Path]::GetFullPath([string]$plan.stageRoot)
$readyRoot = Join-Path $stageRoot ([string]$plan.requestId + '.ready')
$partialRoot = Join-Path $stageRoot ([string]$plan.requestId + '.partial')
$finalRoot = [IO.Path]::GetFullPath([string]$plan.finalRoot)
$zipPath = Join-Path $finalRoot ([string]$plan.requestId + '.ready.zip')
foreach ($path in @($stageRoot, $readyRoot, $partialRoot, $finalRoot, $zipPath)) {
    Assert-R21G1 (-not (Test-Path -LiteralPath $path)) "R21G1 create-new path exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r21g1_build_preflight_v1'
        state = 'PASS_R21G1_BUILD_PREFLIGHT'
        requestId = [string]$plan.requestId
        payloadCount = @($plan.payloads).Count
        allowedTaskActions = @($plan.allowedTaskActions)
        stageRoot = $stageRoot
        finalRoot = $finalRoot
        signerThumbprint = $thumbprint
        mutationsPerformed = $false
        publications = 0
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path (Join-Path $partialRoot 'payload'))
foreach ($row in @($plan.payloads)) {
    $destination = Join-Path $partialRoot ([string]$row.path).Replace('/', '\')
    Copy-Item -LiteralPath (Join-Path $project ([string]$row.source)) -Destination $destination -ErrorAction Stop
    Assert-R21G1Pin $destination ([string]$row.sha256)
}
$records = @(Get-ChildItem -LiteralPath (Join-Path $partialRoot 'payload') -File | Sort-Object Name | ForEach-Object {
    [ordered]@{
        path = 'payload/' + $_.Name
        bytes = [int64]$_.Length
        sha256 = Get-R21G1Hash $_.FullName
    }
})
Assert-R21G1 ($records.Count -eq 3) 'R21G1 payload count changed.'

$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = [string]$plan.requestId
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
    entryPoint = [string]$plan.entryPoint
    changes = @($plan.changes)
    allowedTaskActions = @($plan.allowedTaskActions)
    rehearsal = [ordered]@{ requiredState = [string]$plan.rehearsalRequiredState }
    requestRetryAuthorized = $false
}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes((Join-Path $partialRoot 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try {
    $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
} finally {
    $rsa.Dispose()
}
[IO.File]::WriteAllBytes((Join-Path $partialRoot 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
Move-Item -LiteralPath $partialRoot -Destination $readyRoot -ErrorAction Stop
[void](New-Item -ItemType Directory -Path $finalRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)

[ordered]@{
    schema = 'argos_r21g1_build_result_v1'
    state = 'PASS_R21G1_FRESH_SIGNED_DIRECT_GATEWAY_PACKAGE'
    requestId = [string]$plan.requestId
    readyRoot = $readyRoot
    zipPath = $zipPath
    zipBytes = [int64](Get-Item -LiteralPath $zipPath).Length
    zipSha256 = Get-R21G1Hash $zipPath
    manifestSha256 = Get-R21G1Hash (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json')
    signatureSha256 = Get-R21G1Hash (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')
    unchangedQualifiedEntrypointSha256 = 'ACBC549FF33620D59990FA5C86F716FAE152A694450CBBC08D798B3F9FC76073'
    allowedTaskActions = @($plan.allowedTaskActions)
    publications = 0
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8
