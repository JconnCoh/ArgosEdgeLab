#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Sign')][switch]$Sign
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\R21M1PK'
$payloadRoot = Join-Path $root 'payload'
$definitionPath = Join-Path $root 'DEFINITION.json'
$signedRoot = Join-Path $root 'signed'
$gatePath = Join-Path $PSScriptRoot 'R21M1_SIGN_GATE.json'
$identityPath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$verifierPath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$expectedDefinitionSha = '6B2B377850BD8C0F53C058D2E058CBEE7866C263A5DED42E44D4D8D6A17D11AE'
$payloadPins = [ordered]@{
    'C.json' = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
    'Invoke-R21M1MissingOnly.ps1' = 'E29608364151BB7458FA07C50CFCCE389CEF412BB231E9FF95773A5AEB5DB27F'
    'R18_REGRESSION_CASES.json' = '7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
    'R21M1_MISSING_ONLY_CASES.json' = '56419244A465B6E45D7409649BB7810BFEF474E26CD6812E7108907741F8270A'
}

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-NewBytes([string]$Path, [byte[]]$Bytes) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllBytes($Path, $Bytes)
}
function Write-NewUtf8Json([string]$Path, [object]$Value, [int]$Depth = 16) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

foreach ($path in @($definitionPath, $identityPath, $publicCertificatePath, $verifierPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "R21M1 signing dependency is absent: $path" }
}
if ((Get-Sha256 $definitionPath) -ne $expectedDefinitionSha) { throw 'R21M1 definition hash changed.' }
foreach ($leaf in $payloadPins.Keys) {
    $path = Join-Path $payloadRoot $leaf
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne $payloadPins[$leaf]) { throw "R21M1 payload changed: $leaf" }
}
if (Test-Path -LiteralPath $signedRoot) { throw 'R21M1 signed root already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21M1 sign gate already exists.' }
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH') { throw 'R21M1 definition identity changed.' }
if (@($definition.changes).Count -ne 1 -or @($definition.allowedTaskActions).Count -ne 0) { throw 'R21M1 mutation bounds changed.' }
$change = @($definition.changes)[0]
if (
    [string]$change.destination -ne 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json' -or
    [string]$change.installedSha256 -ne [string]$payloadPins['C.json'] -or
    @($change.approvedPredecessorSha256).Count -ne 1 -or
    [string]@($change.approvedPredecessorSha256)[0] -ne [string]$payloadPins['C.json'] -or
    [bool]$change.allowCreate
) { throw 'R21M1 exact same-bytes carrier contract changed.' }
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'R21M1 signer private key is unavailable.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b21_r21m1_sign_preflight_v1'
        state = 'PASS_R21M1_SIGN_PREFLIGHT'
        signerThumbprint = $thumbprint
        definitionSha256 = $expectedDefinitionSha
        payloadFileCount = $payloadPins.Count
        selectedCaseCount = 15
        completedCaseRerunCount = 0
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
foreach ($leaf in $payloadPins.Keys) { [IO.File]::Copy((Join-Path $payloadRoot $leaf), (Join-Path (Join-Path $partial 'payload') $leaf), $false) }
$files = @(
    Get-ChildItem -LiteralPath (Join-Path $partial 'payload') -File | Sort-Object Name | ForEach-Object {
        [ordered]@{ path = 'payload/' + $_.Name; bytes = $_.Length; sha256 = Get-Sha256 $_.FullName }
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
if (Test-Path -LiteralPath $zipPath) { throw 'R21M1 ZIP path already exists.' }
[IO.Compression.ZipFile]::CreateFromDirectory($ready, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
$gate = [ordered]@{
    schema = 'argos_o3b21_r21m1_sign_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21M1_SIGNED_MISSING_ONLY_PACKAGE'
    requestId = $requestId
    packagePath = $ready
    packageZipPath = $zipPath
    packageZipBytes = (Get-Item -LiteralPath $zipPath).Length
    packageZipSha256 = Get-Sha256 $zipPath
    manifestSha256 = Get-Sha256 (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json')
    signatureSha256 = Get-Sha256 (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
    signerThumbprint = $thumbprint
    exactPackageSignaturePassed = $true
    sameBytesCarrier = $true
    selectedCaseCount = 15
    completedCaseRerunCount = 0
    allowedTaskActionCount = 0
    signed = $true
    published = $false
    targetExecuted = $false
    mutationsPerformed = $false
}
Write-NewUtf8Json -Path $gatePath -Value $gate -Depth 10
$gate | ConvertTo-Json -Depth 10
