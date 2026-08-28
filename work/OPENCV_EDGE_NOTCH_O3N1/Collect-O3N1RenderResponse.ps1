#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) {
    throw 'Specify exactly one of -Preflight or -Collect.'
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Assert-PinnedJson([string]$Path, [string]$Sha256, [string]$State) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3N1 response dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O3N1 response dependency changed: $Path"
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Assert-True ([string]$value.state -eq $State) "O3N1 response dependency state changed: $Path"
    return $value
}

function Read-BoundedZipEntry([IO.Compression.ZipArchive]$Archive, [string]$Name, [int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry) "O3N1 response entry is absent: $Name"
    Assert-True ($entry.Length -le $MaximumBytes) "O3N1 response entry exceeds its bound: $Name"
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        return $memory.ToArray()
    }
    finally {
        $stream.Dispose()
        $memory.Dispose()
    }
}

function Write-NewJson([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3N1 response collection gate exists: $Path"
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine),
        (New-Object Text.UTF8Encoding($false))
    )
}

$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_RENDER_RESPONSE_COLLECTION_INVOCATION.json'))
Assert-True ($invocationPath.Equals($expectedInvocationPath, [StringComparison]::OrdinalIgnoreCase)) 'O3N1 response invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3n1_render_response_collection_invocation_v1') 'O3N1 response invocation schema changed.'
Assert-True ([string]$invocation.state -eq 'FROZEN_EXACT_RESPONSE_COLLECTION_INVOCATION') 'O3N1 response invocation state changed.'
Assert-True ([string]$invocation.collectorSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3N1 response invocation does not pin the exact collector.'

$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$localRoot = [IO.Path]::GetFullPath([string]$invocation.localRoot)
$localZip = Join-Path $localRoot ([string]$invocation.sourceZipName)
$extractRoot = Join-Path $localRoot ([string]$invocation.responseReadyName)
$collectionGate = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_RENDER_RESPONSE_COLLECTION_GATE.json'))
$certificate = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) ([string]$invocation.endpointCertificate)))
$verifier = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) ([string]$invocation.responseVerifier)))
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$observationPath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.matchingResponseObservation)))
$publicationGatePath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.publicationGate)))
$routeGatePath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.completeRouteGate)))
$packageGatePath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.finalPackageGate)))

$observation = Assert-PinnedJson $observationPath ([string]$invocation.matchingResponseObservationSha256) 'PASS_O3N1_EXACT_MATCHING_RENDER_RESPONSE_OBSERVED'
$publication = Assert-PinnedJson $publicationGatePath ([string]$invocation.publicationGateSha256) 'PASS_O3N1_RENDER_REQUEST_PUBLISHED_ONCE'
Assert-PinnedJson $routeGatePath ([string]$invocation.completeRouteGateSha256) 'PASS_O3N1_COMPLETE_ROUTE_GATE' | Out-Null
Assert-PinnedJson $packageGatePath ([string]$invocation.finalPackageGateSha256) 'PASS_O3N1_FINAL_PACKAGE_GATE' | Out-Null
Assert-True ([string]$observation.requestId -eq [string]$invocation.requestId -and [string]$observation.responseId -eq [string]$invocation.responseId -and [int]$observation.matchingResponseCount -eq 1) 'O3N1 matching-response observation changed.'
Assert-True ([string]$publication.requestId -eq [string]$invocation.requestId -and [int]$publication.publicationCount -eq 1 -and -not [bool]$publication.requestRetryAuthorized) 'O3N1 publication evidence changed.'

Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3N1 matching response ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes) 'O3N1 matching response ZIP length changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'O3N1 matching response ZIP hash changed.'
Assert-True (Test-Path -LiteralPath $certificate -PathType Leaf) 'O3N1 endpoint certificate is absent.'
Assert-True ((Get-Sha256 $certificate) -eq [string]$invocation.endpointCertificateSha256) 'O3N1 endpoint certificate changed.'
Assert-True (Test-Path -LiteralPath $verifier -PathType Leaf) 'O3N1 response verifier is absent.'
Assert-True ((Get-Sha256 $verifier) -eq [string]$invocation.responseVerifierSha256) 'O3N1 response verifier changed.'
Assert-True (-not (Test-Path -LiteralPath $localRoot)) 'O3N1 create-new collection root already exists.'
Assert-True (-not (Test-Path -LiteralPath $collectionGate)) 'O3N1 response collection gate already exists.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($archive.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @(
        'MAINTENANCE.stderr.txt',
        'MAINTENANCE.stdout.txt',
        'PORTAL_RESPONSE_MANIFEST.json',
        'PORTAL_RESPONSE_MANIFEST.sig',
        'RESULT.json'
    ) | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count) 'O3N1 response ZIP entry count changed.'
    Assert-True (@(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3N1 response ZIP entry set changed.'

    $manifestBytes = Read-BoundedZipEntry $archive 'PORTAL_RESPONSE_MANIFEST.json' 65536
    $signatureBytes = Read-BoundedZipEntry $archive 'PORTAL_RESPONSE_MANIFEST.sig' 8192
    $stdoutBytes = Read-BoundedZipEntry $archive 'MAINTENANCE.stdout.txt' 65536
    $stderrBytes = Read-BoundedZipEntry $archive 'MAINTENANCE.stderr.txt' 65536
    $resultBytes = Read-BoundedZipEntry $archive 'RESULT.json' 65536
    $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
    $endpointResult = [Text.Encoding]::UTF8.GetString($stdoutBytes) | ConvertFrom-Json
    $maintenanceResult = [Text.Encoding]::UTF8.GetString($resultBytes) | ConvertFrom-Json
}
finally {
    $archive.Dispose()
}

Assert-True ($stderrBytes.Length -eq 0) 'O3N1 maintenance stderr is not empty.'
Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1') 'O3N1 response manifest schema changed.'
Assert-True ([string]$manifest.requestId -eq [string]$invocation.requestId) 'O3N1 response request correlation changed.'
Assert-True ([string]$manifest.responseId -eq [string]$invocation.responseId) 'O3N1 response identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3N1 response source or terminal state changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'O3N1 response safety flags changed.'
Assert-True (([string]$manifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -eq [string]$invocation.expectedSignerThumbprint) 'O3N1 response signer declaration changed.'
Assert-True ([string]$manifest.signatureAlgorithm -eq 'RSA-SHA256-PKCS1') 'O3N1 response signature algorithm changed.'

$cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
try {
    $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
finally {
    $rsa.Dispose()
}
Assert-True $signatureValid 'O3N1 response signature is invalid.'
Assert-True ($cert.Thumbprint.ToUpperInvariant() -eq [string]$invocation.expectedSignerThumbprint) 'O3N1 endpoint certificate thumbprint changed.'

$declaredFiles = @($manifest.files)
Assert-True ($declaredFiles.Count -eq 3) 'O3N1 response manifest file count changed.'
$entryBytesByName = @{
    'MAINTENANCE.stderr.txt' = $stderrBytes
    'MAINTENANCE.stdout.txt' = $stdoutBytes
    'RESULT.json' = $resultBytes
}
foreach ($record in $declaredFiles) {
    $name = [string]$record.path
    Assert-True ($entryBytesByName.ContainsKey($name)) "O3N1 undeclared response file encountered: $name"
    $bytes = [byte[]]$entryBytesByName[$name]
    Assert-True ($bytes.Length -eq [int64]$record.bytes) "O3N1 response file length changed: $name"
    Assert-True ((Get-BytesSha256 $bytes) -eq [string]$record.sha256) "O3N1 response file hash changed: $name"
}

Assert-True ([string]$maintenanceResult.schema -eq 'argos_project_portal_maintenance_result_v1') 'O3N1 maintenance result schema changed.'
Assert-True ([string]$maintenanceResult.state -eq 'PASS_MAINTENANCE_PATCH' -and [int]$maintenanceResult.exitCode -eq 0) 'O3N1 maintenance result did not pass.'
Assert-True ([string]$maintenanceResult.entryPoint -eq 'payload/Invoke-O3N1Slot16Endpoint.ps1' -and [int]$maintenanceResult.changedFiles -eq 1) 'O3N1 maintenance execution identity changed.'
Assert-True ([bool]$maintenanceResult.reviewOnly -and -not [bool]$maintenanceResult.productionRoutingEnabled) 'O3N1 maintenance authority changed.'

Assert-True ([string]$endpointResult.schema -eq 'argos_o3m8_endpoint_result_v1') 'O3N1 endpoint result schema changed.'
Assert-True ([string]$endpointResult.state -eq 'PASS_O3M8_SLOT16_SPLIT_METHOD_RENDERED_FOR_DATA_PULL') 'O3N1 endpoint result state changed.'
Assert-True ([string]$endpointResult.revision -eq 'FMOCV03_O3N1_20260827T231100Z' -and -not [bool]$endpointResult.rehearsal) 'O3N1 endpoint revision changed.'
Assert-True ([string]$endpointResult.detectorState -eq 'HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH') 'O3N1 detector state changed.'
Assert-True ([int]$endpointResult.eligiblePhysicalCandidateCount -eq 0 -and [int]$endpointResult.physicalCandidateCount -eq 0) 'O3N1 candidate cardinality changed.'
Assert-True ([string]$endpointResult.exportRelativePath -eq [string]$invocation.expectedExportRelativePath) 'O3N1 export relative path changed.'
Assert-True ([int64]$endpointResult.exportZipBytes -eq [int64]$invocation.expectedExportZipBytes) 'O3N1 export ZIP length changed.'
Assert-True ([string]$endpointResult.exportZipSha256 -eq [string]$invocation.expectedExportZipSha256) 'O3N1 export ZIP hash changed.'
Assert-True ([int]$endpointResult.zipEntryCount -eq 91 -and [int]$endpointResult.sourceImageReadCount -eq 2 -and [bool]$endpointResult.sourceHashesMatched) 'O3N1 endpoint source or export cardinality changed.'
Assert-True ([bool]$endpointResult.detectorRerunPerformed -and -not [bool]$endpointResult.thresholdOrAlgorithmChanged) 'O3N1 detector execution boundary changed.'
Assert-True (-not [bool]$endpointResult.backsidePixelsConsumed -and -not [bool]$endpointResult.argosRotationMetadataConsumed) 'O3N1 forbidden detector input was consumed.'
Assert-True (-not [bool]$endpointResult.sourceMutationPerformed -and -not [bool]$endpointResult.processorTouched -and -not [bool]$endpointResult.providerActivated) 'O3N1 protected invariant changed.'
Assert-True (-not [bool]$endpointResult.requestRetryAuthorized -and [bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3N1 endpoint authority changed.'
Assert-True ([int]$endpointResult.processorProcessCount -eq 0 -and [bool]$endpointResult.processorIdentityUnchanged -and [bool]$endpointResult.sourceAliasRemoved) 'O3N1 processor observation or alias cleanup changed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3n1_render_response_collection_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3N1_RENDER_RESPONSE_COLLECTION_PREFLIGHT'
        requestId = [string]$invocation.requestId
        responseId = [string]$invocation.responseId
        responseZipSha256 = [string]$invocation.sourceZipSha256
        manifestState = [string]$manifest.state
        endpointState = [string]$endpointResult.state
        detectorState = [string]$endpointResult.detectorState
        signatureVerified = $true
        mutationsPerformed = $false
        imageBytesRead = $false
        requestRetryAuthorized = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

[IO.Directory]::CreateDirectory($localRoot) | Out-Null
Copy-Item -LiteralPath $sourceZip -Destination $localZip -ErrorAction Stop
Assert-True ((Get-Sha256 $localZip) -eq [string]$invocation.sourceZipSha256) 'O3N1 local response ZIP copy changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $extractRoot)
$verification = & $verifier -PackagePath $extractRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId ([string]$invocation.requestId)
Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O3N1 extracted response verification failed.'
Assert-True ([string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3N1 extracted endpoint state changed.'
Assert-True ([string]$verification.SignerThumbprint -eq [string]$invocation.expectedSignerThumbprint) 'O3N1 extracted response signer changed.'

$gate = [ordered]@{
    schema = 'argos_o3n1_render_response_collection_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3N1_MATCHING_SIGNED_RENDER_RESPONSE_COLLECTED'
    requestId = [string]$invocation.requestId
    responseId = [string]$invocation.responseId
    responseZipPath = $localZip
    responseZipBytes = [int64]$invocation.sourceZipBytes
    responseZipSha256 = [string]$invocation.sourceZipSha256
    responseManifestSha256 = Get-Sha256 (Join-Path $extractRoot 'PORTAL_RESPONSE_MANIFEST.json')
    responseSignatureSha256 = Get-Sha256 (Join-Path $extractRoot 'PORTAL_RESPONSE_MANIFEST.sig')
    maintenanceStdoutSha256 = Get-Sha256 (Join-Path $extractRoot 'MAINTENANCE.stdout.txt')
    maintenanceResultSha256 = Get-Sha256 (Join-Path $extractRoot 'RESULT.json')
    signatureVerified = $true
    signerThumbprint = [string]$verification.SignerThumbprint
    endpointState = [string]$endpointResult.state
    detectorState = [string]$endpointResult.detectorState
    eligiblePhysicalCandidateCount = [int]$endpointResult.eligiblePhysicalCandidateCount
    physicalCandidateCount = [int]$endpointResult.physicalCandidateCount
    renderManifestSha256 = [string]$endpointResult.renderManifestSha256
    exportRelativePath = [string]$endpointResult.exportRelativePath
    exportZipBytes = [int64]$endpointResult.exportZipBytes
    exportZipSha256 = [string]$endpointResult.exportZipSha256
    exportZipEntryCount = [int]$endpointResult.zipEntryCount
    sourceImageReadCount = [int]$endpointResult.sourceImageReadCount
    sourceHashesMatched = [bool]$endpointResult.sourceHashesMatched
    detectorRerunPerformed = [bool]$endpointResult.detectorRerunPerformed
    thresholdOrAlgorithmChanged = [bool]$endpointResult.thresholdOrAlgorithmChanged
    backsidePixelsConsumed = [bool]$endpointResult.backsidePixelsConsumed
    argosRotationMetadataConsumed = [bool]$endpointResult.argosRotationMetadataConsumed
    sourceMutationPerformed = [bool]$endpointResult.sourceMutationPerformed
    processorTouched = [bool]$endpointResult.processorTouched
    processorProcessCount = [int]$endpointResult.processorProcessCount
    processorIdentityUnchanged = [bool]$endpointResult.processorIdentityUnchanged
    providerActivated = [bool]$endpointResult.providerActivated
    sourceAliasRemoved = [bool]$endpointResult.sourceAliasRemoved
    requestRetryAuthorized = $false
    dataPullNowEligible = $true
    gatewayAcceptanceIsExecutionEvidence = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-NewJson $collectionGate $gate
$gate | ConvertTo-Json -Depth 12
