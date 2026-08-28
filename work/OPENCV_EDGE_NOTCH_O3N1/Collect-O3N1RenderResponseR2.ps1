#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

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

function Write-ByteArrayObject {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][byte[]]$Bytes)
    $PSCmdlet.WriteObject($Bytes, $false)
}

function Test-ByteArrayBoundary {
    $cases = @(
        [pscustomobject]@{ id = 'ZERO'; bytes = [byte[]]@(); expected = 0 },
        [pscustomobject]@{ id = 'ONE'; bytes = [byte[]]@(7); expected = 1 },
        [pscustomobject]@{ id = 'MANY'; bytes = [byte[]]@(1, 2, 3, 4); expected = 4 }
    )
    foreach ($case in $cases) {
        $received = Write-ByteArrayObject -Bytes ([byte[]]$case.bytes)
        Assert-True ($received -is [byte[]]) "O3N1 R2 byte-array case lost its type: $($case.id)"
        Assert-True ($received.Length -eq [int]$case.expected) "O3N1 R2 byte-array length changed: $($case.id)"
    }
}

function Read-BoundedZipBytes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][IO.Compression.ZipArchive]$Archive,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][int64]$MaximumBytes
    )
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry) "O3N1 R2 response entry is absent: $Name"
    Assert-True ($entry.Length -le $MaximumBytes) "O3N1 R2 response entry exceeds its bound: $Name"
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        Write-ByteArrayObject -Bytes ([byte[]]$memory.ToArray())
    }
    finally {
        $stream.Dispose()
        $memory.Dispose()
    }
}

function Assert-PinnedJson([string]$Path, [string]$Sha256, [string]$State) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3N1 R2 dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O3N1 R2 dependency changed: $Path"
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Assert-True ([string]$value.state -eq $State) "O3N1 R2 dependency state changed: $Path"
    return $value
}

function Write-NewJson([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3N1 R2 collection gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Test-ByteArrayBoundary
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_RENDER_RESPONSE_COLLECTION_R2_INVOCATION.json'))
Assert-True ($invocationPath.Equals($expectedInvocationPath, [StringComparison]::OrdinalIgnoreCase)) 'O3N1 R2 invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3n1_render_response_collection_r2_invocation_v1') 'O3N1 R2 invocation schema changed.'
Assert-True ([string]$invocation.state -eq 'FROZEN_EXACT_RESPONSE_COLLECTION_INVOCATION') 'O3N1 R2 invocation state changed.'
Assert-True ([string]$invocation.collectorSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3N1 R2 invocation does not pin the exact collector.'

$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$localRoot = [IO.Path]::GetFullPath([string]$invocation.localRoot)
$localZip = Join-Path $localRoot ([string]$invocation.sourceZipName)
$extractRoot = Join-Path $localRoot ([string]$invocation.responseReadyName)
$collectionGate = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_RENDER_RESPONSE_COLLECTION_R2_GATE.json'))
$certificate = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.endpointCertificate)))
$verifier = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.responseVerifier)))

$withdrawal = Assert-PinnedJson ([IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.r1Withdrawal))) ([string]$invocation.r1WithdrawalSha256) 'WITHDRAWN_PREFLIGHT_ONLY_NO_MUTATION'
$observation = Assert-PinnedJson ([IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.matchingResponseObservation))) ([string]$invocation.matchingResponseObservationSha256) 'PASS_O3N1_EXACT_MATCHING_RENDER_RESPONSE_OBSERVED'
$publication = Assert-PinnedJson ([IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.publicationGate))) ([string]$invocation.publicationGateSha256) 'PASS_O3N1_RENDER_REQUEST_PUBLISHED_ONCE'
Assert-PinnedJson ([IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.completeRouteGate))) ([string]$invocation.completeRouteGateSha256) 'PASS_O3N1_COMPLETE_ROUTE_GATE' | Out-Null
Assert-PinnedJson ([IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$invocation.finalPackageGate))) ([string]$invocation.finalPackageGateSha256) 'PASS_O3N1_FINAL_PACKAGE_GATE' | Out-Null
Assert-True (-not [bool]$withdrawal.futureReuseAllowed -and -not [bool]$withdrawal.localExtractionRootCreated -and -not [bool]$withdrawal.collectionGateCreated) 'O3N1 R1 withdrawal boundary changed.'
Assert-True ([string]$observation.requestId -eq [string]$invocation.requestId -and [string]$observation.responseId -eq [string]$invocation.responseId -and [int]$observation.matchingResponseCount -eq 1) 'O3N1 R2 matching-response observation changed.'
Assert-True ([string]$publication.requestId -eq [string]$invocation.requestId -and [int]$publication.publicationCount -eq 1 -and -not [bool]$publication.requestRetryAuthorized) 'O3N1 R2 publication evidence changed.'

Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3N1 R2 response ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes) 'O3N1 R2 response ZIP length changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'O3N1 R2 response ZIP hash changed.'
Assert-True ((Get-Sha256 $certificate) -eq [string]$invocation.endpointCertificateSha256) 'O3N1 R2 certificate changed.'
Assert-True ((Get-Sha256 $verifier) -eq [string]$invocation.responseVerifierSha256) 'O3N1 R2 verifier changed.'
Assert-True (-not (Test-Path -LiteralPath $localRoot)) 'O3N1 R2 create-new collection root exists.'
Assert-True (-not (Test-Path -LiteralPath $collectionGate)) 'O3N1 R2 collection gate exists.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($archive.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig', 'RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq 5 -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3N1 R2 response ZIP entry set changed.'
    $manifestBytes = Read-BoundedZipBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 65536
    $signatureBytes = Read-BoundedZipBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 8192
    $stdoutBytes = Read-BoundedZipBytes $archive 'MAINTENANCE.stdout.txt' 65536
    $stderrBytes = Read-BoundedZipBytes $archive 'MAINTENANCE.stderr.txt' 65536
    $resultBytes = Read-BoundedZipBytes $archive 'RESULT.json' 65536
}
finally { $archive.Dispose() }

Assert-True ($manifestBytes -is [byte[]] -and $signatureBytes -is [byte[]] -and $stdoutBytes -is [byte[]] -and $stderrBytes -is [byte[]] -and $resultBytes -is [byte[]]) 'O3N1 R2 ZIP byte-array type boundary failed.'
Assert-True ($stderrBytes.Length -eq 0) 'O3N1 R2 maintenance stderr is not empty.'
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
$endpointResult = [Text.Encoding]::UTF8.GetString($stdoutBytes) | ConvertFrom-Json
$maintenanceResult = [Text.Encoding]::UTF8.GetString($resultBytes) | ConvertFrom-Json

Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq [string]$invocation.requestId -and [string]$manifest.responseId -eq [string]$invocation.responseId) 'O3N1 R2 response correlation changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3N1 R2 response terminal state changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'O3N1 R2 response authority changed.'
Assert-True (([string]$manifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -eq [string]$invocation.expectedSignerThumbprint -and [string]$manifest.signatureAlgorithm -eq 'RSA-SHA256-PKCS1') 'O3N1 R2 signer declaration changed.'

$cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
Assert-True ($signatureValid -and $cert.Thumbprint.ToUpperInvariant() -eq [string]$invocation.expectedSignerThumbprint) 'O3N1 R2 signature verification failed.'

$actualByName = @{
    'MAINTENANCE.stderr.txt' = $stderrBytes
    'MAINTENANCE.stdout.txt' = $stdoutBytes
    'RESULT.json' = $resultBytes
}
$declaredFiles = @($manifest.files)
Assert-True ($declaredFiles.Count -eq 3) 'O3N1 R2 declared response file count changed.'
foreach ($record in $declaredFiles) {
    $name = [string]$record.path
    Assert-True ($actualByName.ContainsKey($name)) "O3N1 R2 response file was not expected: $name"
    $bytes = [byte[]]$actualByName[$name]
    Assert-True ($bytes.Length -eq [int64]$record.bytes -and (Get-BytesSha256 $bytes) -eq [string]$record.sha256) "O3N1 R2 response file changed: $name"
}

Assert-True ([string]$maintenanceResult.schema -eq 'argos_project_portal_maintenance_result_v1' -and [string]$maintenanceResult.state -eq 'PASS_MAINTENANCE_PATCH' -and [int]$maintenanceResult.exitCode -eq 0) 'O3N1 R2 maintenance result failed.'
Assert-True ([string]$maintenanceResult.entryPoint -eq 'payload/Invoke-O3N1Slot16Endpoint.ps1' -and [int]$maintenanceResult.changedFiles -eq 1 -and [bool]$maintenanceResult.reviewOnly -and -not [bool]$maintenanceResult.productionRoutingEnabled) 'O3N1 R2 maintenance identity changed.'
Assert-True ([string]$endpointResult.schema -eq 'argos_o3m8_endpoint_result_v1' -and [string]$endpointResult.state -eq 'PASS_O3M8_SLOT16_SPLIT_METHOD_RENDERED_FOR_DATA_PULL') 'O3N1 R2 endpoint result failed.'
Assert-True ([string]$endpointResult.revision -eq 'FMOCV03_O3N1_20260827T231100Z' -and -not [bool]$endpointResult.rehearsal) 'O3N1 R2 endpoint revision changed.'
Assert-True ([string]$endpointResult.detectorState -eq 'HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH' -and [int]$endpointResult.eligiblePhysicalCandidateCount -eq 0 -and [int]$endpointResult.physicalCandidateCount -eq 0) 'O3N1 R2 detector outcome changed.'
Assert-True ([string]$endpointResult.exportRelativePath -eq [string]$invocation.expectedExportRelativePath -and [int64]$endpointResult.exportZipBytes -eq [int64]$invocation.expectedExportZipBytes -and [string]$endpointResult.exportZipSha256 -eq [string]$invocation.expectedExportZipSha256) 'O3N1 R2 export identity changed.'
Assert-True ([int]$endpointResult.zipEntryCount -eq 91 -and [int]$endpointResult.sourceImageReadCount -eq 2 -and [bool]$endpointResult.sourceHashesMatched -and [bool]$endpointResult.detectorRerunPerformed) 'O3N1 R2 source/export cardinality changed.'
Assert-True (-not [bool]$endpointResult.thresholdOrAlgorithmChanged -and -not [bool]$endpointResult.backsidePixelsConsumed -and -not [bool]$endpointResult.argosRotationMetadataConsumed) 'O3N1 R2 detector boundary changed.'
Assert-True (-not [bool]$endpointResult.sourceMutationPerformed -and -not [bool]$endpointResult.processorTouched -and -not [bool]$endpointResult.providerActivated -and -not [bool]$endpointResult.requestRetryAuthorized) 'O3N1 R2 protected invariant changed.'
Assert-True ([int]$endpointResult.processorProcessCount -eq 0 -and [bool]$endpointResult.processorIdentityUnchanged -and [bool]$endpointResult.sourceAliasRemoved -and [bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3N1 R2 processor/authority observation changed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3n1_render_response_collection_r2_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3N1_RENDER_RESPONSE_COLLECTION_R2_PREFLIGHT'
        byteArrayCases = @('ZERO', 'ONE', 'MANY')
        requestId = [string]$invocation.requestId
        responseId = [string]$invocation.responseId
        responseZipSha256 = [string]$invocation.sourceZipSha256
        signatureVerified = $true
        endpointState = [string]$endpointResult.state
        detectorState = [string]$endpointResult.detectorState
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
Assert-True ((Get-Sha256 $localZip) -eq [string]$invocation.sourceZipSha256) 'O3N1 R2 local ZIP copy changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $extractRoot)
$verification = & $verifier -PackagePath $extractRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId ([string]$invocation.requestId)
Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [string]$verification.SignerThumbprint -eq [string]$invocation.expectedSignerThumbprint) 'O3N1 R2 extracted response verification failed.'

$gate = [ordered]@{
    schema = 'argos_o3n1_render_response_collection_r2_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3N1_MATCHING_SIGNED_RENDER_RESPONSE_COLLECTED_R2'
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
    r1FutureReuseAllowed = $false
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
