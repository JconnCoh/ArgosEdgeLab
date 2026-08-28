[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Sign
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Sign)) { throw 'Specify exactly one of -Preflight or -Sign.' }

$requestId = 'REQ_O3B3'
$definitionPath = Join-Path $PSScriptRoot 'pkg\MAINTENANCE_DEFINITION.json'
$payloadRoot = Join-Path $PSScriptRoot 'pkg\payload'
$outputRoot = Join-Path $PSScriptRoot 'signed_o3b3'
$identityPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json

if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH') { throw 'O3B3 maintenance definition contract refused.' }
if (@($definition.allowedTaskActions).Count -ne 0 -or @($definition.allowedProcessActions).Count -ne 0) { throw 'O3B3 task/process actions must remain empty.' }
if (@($definition.changes).Count -ne 1 -or @($definition.entryPointMutations).Count -ne 1 -or @($definition.entryPointOutputs).Count -ne 1) { throw 'O3B3 declared mutation/output cardinality changed.' }

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'Portal signer private key is unavailable.' }

$payloadItems = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
if ($payloadItems.Count -ne 2) { throw "O3B3 payload file count changed: $($payloadItems.Count)" }
$payloadFiles = @($payloadItems | ForEach-Object {
    [pscustomobject]@{source=$_.FullName;path=('payload/'+$_.Name);bytes=[int64]$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$entry = @($payloadFiles | Where-Object { [string]$_.path -eq 'payload/E.ps1' })
$worker = @($payloadFiles | Where-Object { [string]$_.path -eq 'payload/W.ps1' })
if ($entry.Count -ne 1 -or [string]$entry[0].sha256 -ne [string]$definition.changes[0].installedSha256) { throw 'O3B3 entrypoint target hash mismatch.' }
if ($worker.Count -ne 1 -or [string]$worker[0].sha256 -ne [string]$definition.entryPointMutations[0].installedSha256) { throw 'O3B3 worker target hash mismatch.' }
if ([string]$definition.entryPoint -ne 'payload/E.ps1') { throw 'O3B3 entrypoint path changed.' }

$ready = Join-Path $outputRoot ($requestId + '.ready')
$partial = Join-Path $outputRoot ($requestId + '.partial')
foreach ($path in @($ready, $partial)) { if (Test-Path -LiteralPath $path) { throw "O3B3 request path already exists: $path" } }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b3_signing_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3B3_SIGNING_PREFLIGHT'
        requestId = $requestId
        payloadFiles = $payloadFiles.Count
        entrypointSha256 = [string]$entry[0].sha256
        workerSha256 = [string]$worker[0].sha256
        declaredChanges = @($definition.changes).Count
        declaredEntryPointMutations = @($definition.entryPointMutations).Count
        declaredEntryPointOutputs = @($definition.entryPointOutputs).Count
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

$created = [DateTimeOffset]::UtcNow
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
    files = @($payloadFiles | ForEach-Object { [ordered]@{path=$_.path;bytes=$_.bytes;sha256=$_.sha256} })
    entryPoint = [string]$definition.entryPoint
    changes = @($definition.changes)
    entryPointMutations = @($definition.entryPointMutations)
    entryPointOutputs = @($definition.entryPointOutputs)
    allowedTaskActions = @($definition.allowedTaskActions)
    allowedProcessActions = @($definition.allowedProcessActions)
    rehearsal = $definition.rehearsal
}

[void](New-Item -ItemType Directory -Path $partial -Force)
foreach ($file in $payloadFiles) {
    $destination = Join-Path $partial $file.path.Replace('/', '\')
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath $file.source -Destination $destination
}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
Move-Item -LiteralPath $partial -Destination $ready

[ordered]@{
    schema = 'argos_o3b3_signing_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3B3_SIGNED_REQUEST'
    requestId = $requestId
    packagePath = $ready
    requestManifestSha256 = (Get-FileHash -LiteralPath (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json') -Algorithm SHA256).Hash
    requestSignatureSha256 = (Get-FileHash -LiteralPath (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig') -Algorithm SHA256).Hash
    payloadFiles = $payloadFiles.Count
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6
