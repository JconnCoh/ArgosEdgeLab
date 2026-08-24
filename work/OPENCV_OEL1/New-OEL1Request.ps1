[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Sign
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Sign)) { throw 'Specify exactly one of -Preflight or -Sign.' }

$requestId = 'REQ_OEL1'
$definitionPath = Join-Path $PSScriptRoot 'pkg\MAINTENANCE_DEFINITION.json'
$payloadRoot = Join-Path $PSScriptRoot 'pkg\payload'
$outputRoot = Join-Path $PSScriptRoot 'signed_short'
$signedSourceGatePath = Join-Path $PSScriptRoot 'OEL1_SIGNED_SOURCE_GATE.json'
$signedSourceGatePartial = $signedSourceGatePath + '.partial'
$pathTool = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'utilities\Confirm-ArgosPathBudget.ps1'
$identityPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json

if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH') { throw 'OEL1 maintenance definition contract refused.' }
if (@($definition.allowedTaskActions).Count -ne 0 -or @($definition.allowedProcessActions).Count -ne 0) { throw 'OEL1 task/process actions must remain empty.' }
if (@($definition.changes).Count -ne 1 -or @($definition.entryPointMutations).Count -ne 1 -or @($definition.entryPointOutputs).Count -ne 1) { throw 'OEL1 declared mutation/output cardinality changed.' }
$readContract = $definition.metadataReadContract
if ([string]$readContract.mode -ne 'CONFIG_ANCHORED_PROCESS_LOCAL_ALIAS_METADATA_ONLY' -or [string]$readContract.approvedDataRoot -ne 'JBOD_KLARF_EXPORT' -or [string]$readContract.processLocalAliasName -ne 'F' -or [int]$readContract.maximumLeaves -ne 4 -or @($readContract.relativeLeafPaths).Count -ne 4 -or [bool]$readContract.pathEnumerationAllowed -or [bool]$readContract.fileContentReadAllowed -or [bool]$readContract.imageBytesReadAllowed -or [bool]$readContract.sourceHashingAllowed -or [bool]$readContract.persistentAliasAllowed) { throw 'OEL1 metadata-read contract changed.' }

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'Portal signer private key is unavailable.' }

$payloadItems = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
if ($payloadItems.Count -ne 2) { throw "OEL1 payload file count changed: $($payloadItems.Count)" }
$payloadFiles = @($payloadItems | ForEach-Object {
    [pscustomobject]@{source=$_.FullName;path=('payload/'+$_.Name);bytes=[int64]$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
$entry = @($payloadFiles | Where-Object { [string]$_.path -eq 'payload/E.ps1' })
$worker = @($payloadFiles | Where-Object { [string]$_.path -eq 'payload/W.ps1' })
if ($entry.Count -ne 1 -or [string]$entry[0].sha256 -ne [string]$definition.changes[0].installedSha256) { throw 'OEL1 entrypoint target hash mismatch.' }
if ($worker.Count -ne 1 -or [string]$worker[0].sha256 -ne [string]$definition.entryPointMutations[0].installedSha256) { throw 'OEL1 worker target hash mismatch.' }
if ([string]$definition.entryPoint -ne 'payload/E.ps1') { throw 'OEL1 entrypoint path changed.' }

$ready = Join-Path $outputRoot ($requestId + '.ready')
$partial = Join-Path $outputRoot ($requestId + '.partial')
foreach ($path in @($ready, $partial, $signedSourceGatePath, $signedSourceGatePartial)) { if (Test-Path -LiteralPath $path) { throw "OEL1 request path already exists: $path" } }
$plannedPaths = @($ready, $partial, $signedSourceGatePath, $signedSourceGatePartial, (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'), (Join-Path $partial 'payload\E.ps1'), (Join-Path $partial 'payload\W.ps1'))
$pathGate = & $pathTool -CandidatePath $plannedPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OEL1 signing path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_oel1_signing_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OEL1_SIGNING_PREFLIGHT'
        requestId = $requestId
        signedSourceGatePath = $signedSourceGatePath
        payloadFiles = $payloadFiles.Count
        entrypointSha256 = [string]$entry[0].sha256
        workerSha256 = [string]$worker[0].sha256
        pathState = [string]$pathGate.state
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
    metadataReadContract = $definition.metadataReadContract
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

$requestManifestSha256 = (Get-FileHash -LiteralPath (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json') -Algorithm SHA256).Hash
$requestSignatureSha256 = (Get-FileHash -LiteralPath (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig') -Algorithm SHA256).Hash
$signedSourceGate = [ordered]@{
    schema = 'argos_oel1_signed_source_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OEL1_SIGNED_SOURCE_GATE'
    requestId = $requestId
    signedSourcePath = $ready
    maintenanceDefinitionSha256 = (Get-FileHash -LiteralPath $definitionPath -Algorithm SHA256).Hash
    requestManifestSha256 = $requestManifestSha256
    requestSignatureSha256 = $requestSignatureSha256
    entrypointSha256 = [string]$entry[0].sha256
    workerSha256 = [string]$worker[0].sha256
    payloadFileCount = $payloadFiles.Count
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    reviewOnly = $true
    productionRoutingEnabled = $false
}
[IO.File]::WriteAllText($signedSourceGatePartial, (($signedSourceGate | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $signedSourceGatePartial -Destination $signedSourceGatePath

[ordered]@{
    schema = 'argos_oel1_signing_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OEL1_SIGNED_REQUEST'
    requestId = $requestId
    packagePath = $ready
    requestManifestSha256 = $requestManifestSha256
    requestSignatureSha256 = $requestSignatureSha256
    signedSourceGatePath = $signedSourceGatePath
    signedSourceGateSha256 = (Get-FileHash -LiteralPath $signedSourceGatePath -Algorithm SHA256).Hash
    payloadFiles = $payloadFiles.Count
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6
