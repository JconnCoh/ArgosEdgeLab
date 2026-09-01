#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Sign')][switch]$Sign
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\R21P1'
$payloadRoot = Join-Path $root 'payload'
$definitionPath = Join-Path $root 'DEFINITION.json'
$signedRoot = Join-Path $root 'signed'
$gatePath = Join-Path $PSScriptRoot 'R21P1_SIGN_GATE.json'
$identityPath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$verifierPath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$expectedEntrySha = '98EDCD1B37CA01119B80E2662390C1E2115CF1A93840FABC2D142D698919A582'
$expectedConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$expectedDefinitionSha = 'C032F293AC38BF4BBCF065DFC1CDCB87AB0D9EA1B7C3274F14A6A3968307AEBD'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-NewBytes([string]$Path, [byte[]]$Bytes) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllBytes($Path, $Bytes)
}
function Write-NewUtf8Json([string]$Path, [object]$Value, [int]$Depth = 16) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

foreach ($path in @($definitionPath, (Join-Path $payloadRoot 'C.json'), (Join-Path $payloadRoot 'E.ps1'), $identityPath, $publicCertificatePath, $verifierPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "R21P1 signing dependency is absent: $path" }
}
if ((Get-Sha256 $definitionPath) -ne $expectedDefinitionSha) { throw 'R21P1 definition hash changed.' }
if ((Get-Sha256 (Join-Path $payloadRoot 'C.json')) -ne $expectedConfigSha) { throw 'R21P1 config payload hash changed.' }
if ((Get-Sha256 (Join-Path $payloadRoot 'E.ps1')) -ne $expectedEntrySha) { throw 'R21P1 entry payload hash changed.' }
if (Test-Path -LiteralPath $signedRoot) { throw 'R21P1 signed root already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21P1 sign gate already exists.' }
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH') { throw 'R21P1 definition identity changed.' }
if (@($definition.changes).Count -ne 1 -or @($definition.allowedTaskActions).Count -ne 0) { throw 'R21P1 mutation bounds changed.' }
$change = @($definition.changes)[0]
if (
    [string]$change.destination -ne 'C:/ProgramData/ArgosProjectPortalRO/config/endpoint_jbod.json' -or
    [string]$change.installedSha256 -ne $expectedConfigSha -or
    @($change.approvedPredecessorSha256).Count -ne 1 -or
    [string]@($change.approvedPredecessorSha256)[0] -ne $expectedConfigSha -or
    [bool]$change.allowCreate
) { throw 'R21P1 exact same-bytes config self-swap contract changed.' }
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'R21P1 signer private key is unavailable.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r21p1_sign_preflight_v1'
        state = 'PASS_R21P1_SIGN_PREFLIGHT'
        signerThumbprint = $thumbprint
        definitionSha256 = $expectedDefinitionSha
        payloadFileCount = 2
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $signedRoot)
$created = [DateTimeOffset]::UtcNow
$requestId = 'REQ_' + $created.ToString('yyyyMMddTHHmmssfffZ') + '_' + ([Guid]::NewGuid().ToString('N').Substring(0, 12).ToUpperInvariant())
$partial = Join-Path $signedRoot ($requestId + '.partial')
$ready = Join-Path $signedRoot ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload') -Force)
foreach ($leaf in @('C.json', 'E.ps1')) { [IO.File]::Copy((Join-Path $payloadRoot $leaf), (Join-Path (Join-Path $partial 'payload') $leaf), $false) }
$files = @(
    Get-ChildItem -LiteralPath (Join-Path $partial 'payload') -File | Sort-Object Name | ForEach-Object {
        [ordered]@{path = 'payload/' + $_.Name; bytes = $_.Length; sha256 = Get-Sha256 $_.FullName}
    }
)
$manifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = $requestId
    createdUtc = $created.ToString('o')
    expiresUtc = $created.AddHours(24).ToString('o')
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    handler = ''
    maxResultBytes = [int64]$definition.maxResultBytes
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    credentialsIncluded = $false
    signerThumbprint = $thumbprint
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    files = $files
    entryPoint = [string]$definition.entryPoint
    changes = @($definition.changes)
    allowedTaskActions = @()
    rehearsal = $definition.rehearsal
}
$manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
Write-NewBytes -Path (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json') -Bytes $manifestBytes
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
Write-NewBytes -Path (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig') -Bytes $signature
Move-Item -LiteralPath $partial -Destination $ready
& $verifierPath -PackagePath $ready -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole 'JBOD' -ExpectedJobClass 'MAINTENANCE_PATCH' | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $root ($requestId + '.ready.zip')
if (Test-Path -LiteralPath $zipPath) { throw 'R21P1 ZIP path already exists.' }
[IO.Compression.ZipFile]::CreateFromDirectory($ready, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
$gate = [ordered]@{
    schema = 'argos_r21p1_sign_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21P1_SIGNED_PACKAGE'
    requestId = $requestId
    packagePath = $ready
    packageZipPath = $zipPath
    packageZipBytes = (Get-Item -LiteralPath $zipPath).Length
    packageZipSha256 = Get-Sha256 $zipPath
    manifestSha256 = Get-Sha256 (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json')
    signatureSha256 = Get-Sha256 (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
    signerThumbprint = $thumbprint
    exactPackageSignaturePassed = $true
    identicalConfigSelfSwap = $true
    allowedTaskActionCount = 0
    signed = $true
    published = $false
    targetExecuted = $false
    mutationsPerformed = $false
}
Write-NewUtf8Json -Path $gatePath -Value $gate -Depth 10
$gate | ConvertTo-Json -Depth 10
