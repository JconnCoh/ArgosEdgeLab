#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T151200111Z_62629419C3F2'
$responseId = 'R_21E61BDA3E47_20260827153734977_d7ab3f62'
$sourceZip = 'U:\ProjectPortalRO\responses\R_21E61BDA3E47_20260827153734977_d7ab3f62.ready.zip'
$expectedBytes = 5590
$expectedSha256 = '42D02AE95A4E33F0CD0B6A3DF890CEE010CBE8B535BB2D0526E01C081B5F9874'
$expectedInvocationSha256 = '5707A7878D8DF4C1BD017E0739848558E7810B926265F0E79890545C89777166'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\A35R'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')
$collectionGatePath = Join-Path $PSScriptRoot 'O3C2_EXACT_RESPONSE_COLLECTION_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 48) {
    $jsonBytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($jsonBytes, 0, $jsonBytes.Length) }
    finally { $stream.Dispose() }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3C2 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ((Get-Sha256 $invocationPath) -eq $expectedInvocationSha256) 'O3C2 response invocation manifest changed.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3c2_exact_response_collection_invocation_v1') 'O3C2 response invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O3C2 response invocation identity changed.'
Assert-True ([string]$invocation.sourceZipSha256 -eq $expectedSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedBytes -and [int]$invocation.maximumSourceZips -eq 1) 'O3C2 response invocation archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [string]$invocation.expectedEndpointResultState -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE') 'O3C2 response invocation terminal-state contract changed.'
Assert-True ([int]$invocation.expectedPairCount -eq 10 -and [int]$invocation.expectedLeafCount -eq 20 -and [bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized) 'O3C2 response invocation cardinality or retry authority changed.'
Assert-True ([string]$invocation.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$invocation.maximumEffectivePathLength -lt 200 -and [int]$invocation.maximumComponentLength -le 80) 'O3C2 response invocation path evidence changed.'
Assert-True ([bool]$invocation.endpointSourceHashingExpected -and -not [bool]$invocation.imageBytesReadByCollector -and -not [bool]$invocation.sourceHashingPerformedByCollector -and -not [bool]$invocation.sourceDeletionPerformed) 'O3C2 response collection source boundary changed.'
Assert-True (-not [bool]$invocation.inspectionTasksChanged -and -not [bool]$invocation.healthyProcessorTouched -and -not [bool]$invocation.providerActivated) 'O3C2 response collection runtime boundary changed.'
Assert-True (-not [bool]$invocation.knownNotchLocationConsumed -and -not [bool]$invocation.notchAnglePriorConsumed -and -not [bool]$invocation.fixedAngularSearchWindowConsumed -and [bool]$invocation.knownLocationAllowedOnlyForPostInferenceRegressionScoring) 'O3C2 response collection algorithm-integrity boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3C2 response collection authority widened.'

foreach ($dependency in @($sourceZip, $certificate, $verifier)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O3C2 response dependency absent: $dependency"
}
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes) 'O3C2 response ZIP byte count changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq $expectedSha256) 'O3C2 response ZIP hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig', 'RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count) 'O3C2 response ZIP entry count changed.'
    Assert-True (@(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3C2 response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O3C2 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }

Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O3C2 response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3C2 response manifest terminal state changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o3c2_response_collection_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3C2_EXACT_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
    invocationManifestSha256 = $expectedInvocationSha256
    sourceZipSha256 = $expectedSha256
    sourceZipBytes = $expectedBytes
    endpointState = [string]$manifest.state
    signatureVerified = $false
    mutationsPerformed = $false
    imageBytesRead = $false
    knownNotchLocationConsumed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 8
    return
}

foreach ($path in @($tempRoot, $archivePath, $extractionRoot, $collectionGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3C2 create-new collection target exists: $path"
}
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O3C2 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O3C2 signed response verification failed.'
    Assert-True ([string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3C2 signed response correlation or terminal state changed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3C2 JBOD signer changed.'

    $stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
    Assert-True ((Get-Item -LiteralPath $stdoutPath).Length -le 2097152) 'O3C2 stdout exceeded the bounded result limit.'
    $endpointResult = Get-Content -Raw -LiteralPath $stdoutPath | ConvertFrom-Json
    Assert-True ([string]$endpointResult.schema -eq 'argos_ocv03_hotspot_source_freeze_v1' -and [string]$endpointResult.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE' -and [string]$endpointResult.disposition -eq 'LOCKED_INPUT') 'O3C2 endpoint result identity changed.'
    Assert-True ([int]$endpointResult.pairCount -eq 10 -and [int]$endpointResult.leafCount -eq 20 -and @($endpointResult.pairs).Count -eq 10) 'O3C2 endpoint result cardinality changed.'
    Assert-True ([bool]$endpointResult.sourceHashingPerformed -and -not [bool]$endpointResult.imageBytesDecoded -and -not [bool]$endpointResult.pixelProcessingPerformed) 'O3C2 endpoint source-hash boundary changed.'
    Assert-True (-not [bool]$endpointResult.knownNotchLocationConsumed -and -not [bool]$endpointResult.notchAnglePriorConsumed -and -not [bool]$endpointResult.fixedAngularSearchWindowConsumed) 'O3C2 endpoint consumed a forbidden notch prior.'
    Assert-True (-not [bool]$endpointResult.sourceMutationPerformed -and -not [bool]$endpointResult.sourceDeletionPerformed -and -not [bool]$endpointResult.inspectionTasksChanged -and -not [bool]$endpointResult.processorTaskChanged -and -not [bool]$endpointResult.providerActivated -and -not [bool]$endpointResult.waferActionPerformed) 'O3C2 endpoint crossed a protected runtime boundary.'
    Assert-True (-not [bool]$endpointResult.independentValidationCohortInspected -and [bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.trainingEligible -and -not [bool]$endpointResult.xmlEligible -and -not [bool]$endpointResult.productionEligible -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3C2 endpoint authority widened.'
    Assert-True ([bool]$endpointResult.allSourcesStableDuringHash -and [string]$endpointResult.sourceHashAlgorithm -eq 'SHA256') 'O3C2 endpoint did not prove stable SHA-256 acquisition.'
    Assert-True ([string]$endpointResult.aggregateFingerprintSha256 -match '^[0-9A-F]{64}$' -and [string]$endpointResult.outputSha256 -match '^[0-9A-F]{64}$' -and [int64]$endpointResult.outputBytes -gt 0) 'O3C2 endpoint aggregate or output fingerprint is invalid.'
    Assert-True ([bool]$endpointResult.processLocalAlias.removed -and -not [bool]$endpointResult.processLocalAlias.persistent) 'O3C2 process-local alias was not removed.'

    $identities = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    foreach ($pair in @($endpointResult.pairs)) {
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$pair.physicalIdentity) -and $identities.Add([string]$pair.physicalIdentity)) 'O3C2 pair physical identity is absent or duplicated.'
        Assert-True ([string]$pair.acquisitionFingerprintSchema -eq 'argos_ocv03_pair_acquisition_fingerprint_v1' -and [string]$pair.acquisitionFingerprintSha256 -match '^[0-9A-F]{64}$') 'O3C2 pair acquisition fingerprint is invalid.'
        Assert-True (-not [bool]$pair.knownNotchLocationConsumed -and -not [bool]$pair.notchAnglePriorConsumed -and -not [bool]$pair.fixedAngularSearchWindowConsumed) 'O3C2 pair consumed a forbidden notch prior.'
        Assert-True ([string]$pair.bf.channel -eq 'BF' -and [string]$pair.df.channel -eq 'DF') 'O3C2 pair channel identity changed.'
        Assert-True ([string]$pair.bf.physicalIdentity -eq [string]$pair.physicalIdentity -and [string]$pair.df.physicalIdentity -eq [string]$pair.physicalIdentity) 'O3C2 pair/source identity mismatch.'
        Assert-True ([string]$pair.bf.sha256 -match '^[0-9A-F]{64}$' -and [string]$pair.df.sha256 -match '^[0-9A-F]{64}$') 'O3C2 pair source SHA-256 is invalid.'
        Assert-True ([int64]$pair.bf.bytes -gt 0 -and [int64]$pair.df.bytes -gt 0) 'O3C2 pair source byte count is invalid.'
    }

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O3C2 archived response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3C2 final collected response verification failed.'

    $result = [ordered]@{
        schema = 'argos_o3c2_exact_response_collection_gate_v1'
        collectedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C2_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED'
        disposition = 'LOCKED_INPUT'
        requestId = $requestId
        responseId = $responseId
        invocationManifestSha256 = $expectedInvocationSha256
        responseZipBytes = $expectedBytes
        responseZipSha256 = $expectedSha256
        archivePath = $archivePath
        extractionRoot = $extractionRoot
        endpointState = [string]$finalVerification.EndpointState
        sourceRole = [string]$finalVerification.SourceRole
        signerThumbprint = [string]$finalVerification.SignerThumbprint
        signedFileCount = [int]$finalVerification.Files
        signatureVerified = $true
        endpointResultState = [string]$endpointResult.state
        endpointOutputPath = [string]$endpointResult.outputPath
        endpointOutputBytes = [int64]$endpointResult.outputBytes
        endpointOutputSha256 = [string]$endpointResult.outputSha256
        pairCount = [int]$endpointResult.pairCount
        leafCount = [int]$endpointResult.leafCount
        sourceBytesRead = [int64]$endpointResult.sourceBytesRead
        sourceHashAlgorithm = [string]$endpointResult.sourceHashAlgorithm
        aggregateFingerprintSchema = [string]$endpointResult.aggregateFingerprintSchema
        aggregateFingerprintSha256 = [string]$endpointResult.aggregateFingerprintSha256
        allSourcesStableDuringHash = [bool]$endpointResult.allSourcesStableDuringHash
        pairs = @($endpointResult.pairs)
        temporaryCDriveRootRemoved = $true
        requestRetryAuthorized = $false
        imageBytesReadByCollector = $false
        endpointImageBytesDecoded = $false
        endpointPixelProcessingPerformed = $false
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
        knownLocationAllowedOnlyForPostInferenceRegressionScoring = $true
        sourceDeletionPerformed = $false
        inspectionTasksChanged = $false
        healthyProcessorTouched = $false
        providerActivated = $false
        independentValidationCohortInspected = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionRoutingEnabled = $false
    }
    Write-JsonCreateNew -Path $collectionGatePath -Value $result -Depth 48
    $collectionGateCreated = $true
    $result | ConvertTo-Json -Depth 48
}
catch {
    if ($collectionGateCreated -and (Test-Path -LiteralPath $collectionGatePath -PathType Leaf)) { [IO.File]::Delete($collectionGatePath) }
    if ($extractionMoved -and (Test-Path -LiteralPath $extractionRoot -PathType Container)) { [IO.Directory]::Delete($extractionRoot, $true) }
    if ($archiveCreated -and (Test-Path -LiteralPath $archivePath -PathType Leaf)) { [IO.File]::Delete($archivePath) }
    if (-not $archiveDirExisted -and (Test-Path -LiteralPath $archiveDir -PathType Container) -and @(Get-ChildItem -LiteralPath $archiveDir -Force).Count -eq 0) { [IO.Directory]::Delete($archiveDir) }
    throw
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        Assert-True ($resolvedTemp -eq 'C:\A35R') 'O3C2 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
