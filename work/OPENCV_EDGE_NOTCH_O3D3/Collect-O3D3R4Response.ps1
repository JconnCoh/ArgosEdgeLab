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
$requestId = 'REQ_20260827T165500111Z_62629419D3R4'
$responseId = 'R_E4D013703169_20260827165600165_9435b5d9'
$sourceZip = 'U:\ProjectPortalRO\responses\R_E4D013703169_20260827165600165_9435b5d9.ready.zip'
$expectedBytes = 5299
$expectedSha256 = '3CE333ADB06B8164B96864E2F2343D99282FE93667102C19B34B8E57579AD7C2'
$expectedInvocationSha256 = '9F6521D9BBC044A702DAF6921548BDB836345DE55BF181BA2D5C4887A1F00A36'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\A39R'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')
$collectionGatePath = Join-Path $PSScriptRoot 'O3D3R4_EXACT_RESPONSE_COLLECTION_GATE.json'

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

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3D3R4 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ((Get-Sha256 $invocationPath) -eq $expectedInvocationSha256) 'O3D3R4 response invocation manifest changed.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3d3r4_exact_response_collection_invocation_v1') 'O3D3R4 response invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O3D3R4 response invocation identity changed.'
Assert-True ([string]$invocation.sourceZipSha256 -eq $expectedSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedBytes -and [int]$invocation.maximumSourceZips -eq 1) 'O3D3R4 response invocation archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [string]$invocation.expectedEndpointResultState -eq 'PASS_O3D3R4_HOTSPOT_EDGE_NOTCH_EXECUTED') 'O3D3R4 response invocation terminal-state contract changed.'
Assert-True ([int]$invocation.expectedInputCount -eq 10 -and [int]$invocation.expectedVerifiedSourceCount -eq 20 -and [int]$invocation.expectedRowCount -eq 10) 'O3D3R4 response invocation cardinality changed.'
Assert-True ([string]$invocation.expectedRevision -eq 'O3D3R4_20260827T165500000Z_62629419' -and [string]$invocation.expectedSourceAcquisitionFingerprintSha256 -eq 'EB45C81DB9A4A3B220B0D4161C2F280A7FB402A40296FB94110223692073BAA0') 'O3D3R4 response invocation revision or acquisition pin changed.'
Assert-True ([bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized -and -not [bool]$invocation.legacyBulkReceiverUsed) 'O3D3R4 response selection or retry authority changed.'
Assert-True ([string]$invocation.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$invocation.pathCount -eq 6 -and [int]$invocation.maximumEffectivePathLength -lt 200 -and [int]$invocation.maximumComponentLength -le 80) 'O3D3R4 response invocation path evidence changed.'
Assert-True ([bool]$invocation.endpointSourceHashingExpected -and [bool]$invocation.endpointImageBytesDecodedByOpenCv -and -not [bool]$invocation.imageBytesReadByCollector -and -not [bool]$invocation.sourceHashingPerformedByCollector -and -not [bool]$invocation.sourceDeletionPerformed) 'O3D3R4 response collection image/source boundary changed.'
Assert-True (-not [bool]$invocation.inspectionTasksChanged -and -not [bool]$invocation.healthyProcessorTouched -and -not [bool]$invocation.providerActivated -and -not [bool]$invocation.rotationAuthorityGranted) 'O3D3R4 response collection runtime boundary changed.'
Assert-True (-not [bool]$invocation.knownNotchLocationConsumed -and -not [bool]$invocation.notchAnglePriorConsumed -and -not [bool]$invocation.fixedAngularSearchWindowConsumed -and -not [bool]$invocation.regressionLabelsConsumed -and [bool]$invocation.knownLocationAllowedOnlyForPostInferenceRegressionScoring) 'O3D3R4 response collection algorithm-integrity boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3D3R4 response collection authority widened.'

foreach ($dependency in @($sourceZip, $certificate, $verifier)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O3D3R4 response dependency absent: $dependency"
}
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes) 'O3D3R4 response ZIP byte count changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq $expectedSha256) 'O3D3R4 response ZIP hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig', 'RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count) 'O3D3R4 response ZIP entry count changed.'
    Assert-True (@(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3D3R4 response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O3D3R4 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }

Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O3D3R4 response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3D3R4 response manifest terminal state changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o3d3r4_response_collection_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3D3R4_EXACT_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
    invocationManifestSha256 = $expectedInvocationSha256
    sourceZipSha256 = $expectedSha256
    sourceZipBytes = $expectedBytes
    endpointState = [string]$manifest.state
    signatureVerified = $false
    mutationsPerformed = $false
    imageBytesReadByCollector = $false
    knownNotchLocationConsumed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 8
    return
}

foreach ($path in @($tempRoot, $archivePath, $extractionRoot, $collectionGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3D3R4 create-new collection target exists: $path"
}
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O3D3R4 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O3D3R4 signed response verification failed.'
    Assert-True ([string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3D3R4 signed response correlation or terminal state changed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3D3R4 JBOD signer changed.'

    $stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
    Assert-True ((Get-Item -LiteralPath $stdoutPath).Length -le 2097152) 'O3D3R4 stdout exceeded the bounded result limit.'
    $endpointResult = Get-Content -Raw -LiteralPath $stdoutPath | ConvertFrom-Json
    Assert-True ([string]$endpointResult.schema -eq 'argos_o3d3_hotspot_edge_notch_gate_v1' -and [string]$endpointResult.state -eq 'PASS_O3D3R4_HOTSPOT_EDGE_NOTCH_EXECUTED' -and [string]$endpointResult.disposition -eq 'DIAGNOSTIC_ONLY') 'O3D3R4 endpoint result identity changed.'
    Assert-True ([string]$endpointResult.revision -eq 'O3D3R4_20260827T165500000Z_62629419' -and -not [bool]$endpointResult.rehearsal) 'O3D3R4 endpoint revision or execution mode changed.'
    Assert-True ([string]$endpointResult.coreSha256 -eq '304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC' -and [string]$endpointResult.r5Sha256 -eq '47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24' -and [string]$endpointResult.r6Sha256 -eq '90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30' -and [string]$endpointResult.jobSha256 -eq 'F7DB6FE811D58DAA3F410C5AD8E4F063BBD6E961004BDAF1BF2470BB74392717') 'O3D3R4 endpoint dependency hash changed.'
    Assert-True ([string]$endpointResult.sourceFreezeGateSha256 -eq '665C1DDDFD1E1FBDECED11C5C9F382D147E3AB1F7904BF191A5F9026E43063AD' -and [string]$endpointResult.sourceAcquisitionFingerprintSha256 -eq 'EB45C81DB9A4A3B220B0D4161C2F280A7FB402A40296FB94110223692073BAA0') 'O3D3R4 source-freeze lineage changed.'
    Assert-True ([int]$endpointResult.inputCount -eq 10 -and [int]$endpointResult.verifiedSourceCount -eq 20 -and @($endpointResult.rows).Count -eq 10) 'O3D3R4 endpoint result cardinality changed.'
    Assert-True ([bool]$endpointResult.sourceHashesComputed -and [bool]$endpointResult.allSourceHashesMatched -and [string]$endpointResult.summarySha256 -match '^[0-9A-F]{64}$' -and [string]$endpointResult.summaryState -eq 'COMPLETE_REVIEW_ONLY_DEVELOPMENT') 'O3D3R4 endpoint source or summary evidence changed.'
    Assert-True ([bool]$endpointResult.sourceImageBytesRead -and [bool]$endpointResult.pixelsDecodedByOpenCv -and [bool]$endpointResult.fullPerimeterInference -and [bool]$endpointResult.bfDfIndependent) 'O3D3R4 endpoint did not perform the required OpenCV edge/notch inference.'
    Assert-True ([bool]$endpointResult.sourceAliasRemoved -and [bool]$endpointResult.processorIdentityUnchanged) 'O3D3R4 endpoint did not remove the alias or preserve processor identity.'
    Assert-True (-not [bool]$endpointResult.rotationAuthorityGranted -and -not [bool]$endpointResult.knownNotchLocationConsumed -and -not [bool]$endpointResult.notchAnglePriorConsumed -and -not [bool]$endpointResult.fixedAngularSearchWindowConsumed -and -not [bool]$endpointResult.regressionLabelsConsumed) 'O3D3R4 endpoint consumed a forbidden notch prior or granted rotation authority.'
    Assert-True (-not [bool]$endpointResult.sourceMutationPerformed -and -not [bool]$endpointResult.sourceDeletionPerformed -and -not [bool]$endpointResult.taskOrProcessRestarted -and -not [bool]$endpointResult.providerActivated -and -not [bool]$endpointResult.waferActionPerformed -and -not [bool]$endpointResult.holdsCleared) 'O3D3R4 endpoint crossed a protected runtime boundary.'
    Assert-True (-not [bool]$endpointResult.independentValidationCohortInspected -and [bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.trainingEligible -and -not [bool]$endpointResult.xmlEligible -and -not [bool]$endpointResult.productionEligible -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3D3R4 endpoint authority widened.'

    $expectedIdentities = 16..25 | ForEach-Object { '62629-419_20260824112405_SLOT' + $_.ToString('00') }
    $actualIdentities = @($endpointResult.rows | ForEach-Object { [string]$_.identity } | Sort-Object)
    Assert-True (@(Compare-Object -ReferenceObject @($expectedIdentities | Sort-Object) -DifferenceObject $actualIdentities).Count -eq 0) 'O3D3R4 endpoint row identity set changed.'
    $identitySet = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    foreach ($row in @($endpointResult.rows)) {
        Assert-True ($identitySet.Add([string]$row.identity) -and [string]$row.resultSha256 -match '^[0-9A-F]{64}$') 'O3D3R4 row identity is duplicated or its result hash is invalid.'
        Assert-True ([bool]$row.bfQualified -and [bool]$row.dfQualified -and [double]$row.bfRadius -gt 0 -and [double]$row.dfRadius -gt 0) 'O3D3R4 row edge fit is not qualified.'
        Assert-True ([double]$row.bfCoverage -gt 0 -and [double]$row.bfCoverage -le 1 -and [double]$row.dfCoverage -gt 0 -and [double]$row.dfCoverage -le 1) 'O3D3R4 row edge coverage is invalid.'
        Assert-True ([double]$row.bfRmsResidualPx -ge 0 -and [double]$row.dfRmsResidualPx -ge 0 -and [int]$row.bfCandidateCount -ge 0 -and [int]$row.dfCandidateCount -ge 0 -and [int]$row.physicalCandidateCount -ge 0) 'O3D3R4 row edge/candidate measurement is invalid.'
        if ([string]$row.state -eq 'PASS_REVIEW_ONLY_MANUFACTURED_NOTCH_CANDIDATE') {
            Assert-True ([int]$row.manufacturedMorphologyCount -eq 1 -and [bool]$row.manufacturedNotchSelectedForReview) 'O3D3R4 pass row has invalid manufactured-notch selection cardinality.'
            Assert-True ($null -ne $row.reviewAngleDegrees -and -not [string]::IsNullOrWhiteSpace([string]$row.reviewAngleChannel) -and [double]$row.selectedWidthDegrees -gt 0 -and [double]$row.selectedCrossChannelOverlap -gt 0 -and [double]$row.selectedCrossChannelOverlap -le 1) 'O3D3R4 pass row has invalid review measurements.'
        }
        elseif ([string]$row.state -eq 'FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_MANUFACTURED_NOTCH_MORPHOLOGY') {
            Assert-True ([int]$row.manufacturedMorphologyCount -eq 0 -and -not [bool]$row.manufacturedNotchSelectedForReview -and $null -eq $row.reviewAngleDegrees) 'O3D3R4 hold row improperly selected a notch.'
        }
        else { throw "O3D3R4 row has an unexpected state: $($row.state)" }
    }

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O3D3R4 archived response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3D3R4 final collected response verification failed.'

    $result = [ordered]@{
        schema = 'argos_o3d3r4_exact_response_collection_gate_v1'
        collectedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3D3R4_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED'
        disposition = 'DIAGNOSTIC_ONLY'
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
        endpointRevision = [string]$endpointResult.revision
        endpointStdoutBytes = [int64](Get-Item -LiteralPath (Join-Path $extractionRoot 'MAINTENANCE.stdout.txt')).Length
        endpointStdoutSha256 = Get-Sha256 (Join-Path $extractionRoot 'MAINTENANCE.stdout.txt')
        summaryState = [string]$endpointResult.summaryState
        summarySha256 = [string]$endpointResult.summarySha256
        sourceAcquisitionFingerprintSha256 = [string]$endpointResult.sourceAcquisitionFingerprintSha256
        inputCount = [int]$endpointResult.inputCount
        verifiedSourceCount = [int]$endpointResult.verifiedSourceCount
        rowCount = @($endpointResult.rows).Count
        passRowCount = @($endpointResult.rows | Where-Object { [string]$_.state -eq 'PASS_REVIEW_ONLY_MANUFACTURED_NOTCH_CANDIDATE' }).Count
        holdRowCount = @($endpointResult.rows | Where-Object { [string]$_.state -eq 'FRONTSIDE_NOTCH_ALIGNMENT_HOLD_NO_MANUFACTURED_NOTCH_MORPHOLOGY' }).Count
        rows = @($endpointResult.rows)
        temporaryCDriveRootRemoved = $true
        requestRetryAuthorized = $false
        imageBytesReadByCollector = $false
        endpointImageBytesDecodedByOpenCv = $true
        endpointFullPerimeterInference = $true
        endpointBfDfIndependent = $true
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
        regressionLabelsConsumed = $false
        knownLocationAllowedOnlyForPostInferenceRegressionScoring = $true
        rotationAuthorityGranted = $false
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
        Assert-True ($resolvedTemp -eq 'C:\A39R') 'O3D3R4 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
