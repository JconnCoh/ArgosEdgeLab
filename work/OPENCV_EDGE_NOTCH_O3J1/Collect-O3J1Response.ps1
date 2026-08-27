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
if ([bool]$Preflight -eq [bool]$Gate) {
    throw 'Specify exactly one of -Preflight or -Gate.'
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T185500111Z_62629419O3J1'
$responseId = 'R_7AF93A801F21_20260827192418120_a88bd396'
$sourceZip = 'U:\ProjectPortalRO\responses\R_7AF93A801F21_20260827192418120_a88bd396.ready.zip'
$expectedSourceZipBytes = 41491
$expectedSourceZipSha256 = '702932F08C741610CC8E2950E8D7A2CFE963CD16A8E75E831B0BDDFE6A348130'
$expectedInvocationSha256 = '072D7875498D06E3FF7CDA08476731BD2EA5A790A7C495E581A55EFC363E8C17'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$expectedSourceInvocation = Join-Path $PSScriptRoot 'O3J1_RESULT_JSON_INVOCATION.json'
$tempRoot = 'C:\A3J1C'
$tempZip = Join-Path $tempRoot 'R.zip'
$tempExtract = Join-Path $tempRoot 'R'
$tempReconstituted = Join-Path $tempRoot 'J'
$collectedRoot = Join-Path $project 'work\O3J1C'
$archivePath = Join-Path $collectedRoot 'R.zip'
$extractionRoot = Join-Path $collectedRoot 'R'
$reconstitutedRoot = Join-Path $project 'work\O3J1R'
$collectionGatePath = Join-Path $PSScriptRoot 'O3J1_EXACT_RESPONSE_COLLECTION_GATE.json'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Get-Sha256Bytes {
    param([byte[]]$Bytes)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Write-BytesCreateNew {
    param([string]$Path, [byte[]]$Bytes)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($Bytes, 0, $Bytes.Length)
        $stream.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

function Write-JsonCreateNew {
    param([string]$Path, [object]$Value, [int]$Depth = 16)
    $json = ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine
    Write-BytesCreateNew -Path $Path -Bytes ((New-Object Text.UTF8Encoding($false)).GetBytes($json))
}

function Resolve-ProjectFile {
    param([string]$RelativePath)
    $full = [IO.Path]::GetFullPath((Join-Path $project $RelativePath.Replace('/', '\')))
    Assert-True ($full.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) "Project dependency escaped the repository: $RelativePath"
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "Project dependency is absent: $RelativePath"
    return $full
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3J1 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ((Get-Sha256 -Path $invocationPath) -eq $expectedInvocationSha256) 'O3J1 response invocation manifest changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3j1_exact_response_collection_invocation_v1') 'O3J1 response invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O3J1 response invocation identity changed.'
Assert-True ([string]$invocation.sourceZipSha256 -eq $expectedSourceZipSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedSourceZipBytes -and [int]$invocation.maximumSourceZips -eq 1) 'O3J1 response archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3J1 response terminal manifest contract changed.'
Assert-True ([string]$invocation.expectedEndpointResultState -eq 'PASS_O3J1_EXACT_RESULT_JSON_CAPABILITY' -and [string]$invocation.expectedEndpointRevision -eq 'O3J1_20260827T185500000Z_62629419') 'O3J1 endpoint result contract changed.'
Assert-True ([int]$invocation.expectedFileCount -eq 13 -and [bool]$invocation.reconstitutedJsonFilesOnly) 'O3J1 exact JSON cardinality contract changed.'
Assert-True ([string]$invocation.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$invocation.pathCount -eq 11 -and [int]$invocation.maximumEffectivePathLength -lt 200 -and [int]$invocation.maximumComponentLength -le 80) 'O3J1 collection path evidence changed.'
Assert-True ([bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized -and -not [bool]$invocation.legacyBulkReceiverUsed) 'O3J1 response selection or retry authority changed.'
Assert-True (-not [bool]$invocation.imageBytesReadByCollector -and -not [bool]$invocation.sourceImageBytesReadByCollector -and -not [bool]$invocation.sourceHashingPerformedByCollector -and -not [bool]$invocation.sourceDeletionPerformed) 'O3J1 collector image/source boundary changed.'
Assert-True (-not [bool]$invocation.inspectionTasksChanged -and -not [bool]$invocation.healthyProcessorTouched -and -not [bool]$invocation.providerActivated -and -not [bool]$invocation.waferActionPerformed) 'O3J1 collector runtime boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3J1 collector authority widened.'

$observationPath = Resolve-ProjectFile -RelativePath ([string]$invocation.matchingResponseObservation)
Assert-True ((Get-Sha256 -Path $observationPath) -eq [string]$invocation.matchingResponseObservationSha256) 'O3J1 matching-response observation changed.'
$observation = Get-Content -LiteralPath $observationPath -Raw | ConvertFrom-Json
Assert-True ([string]$observation.state -eq 'PASS_O3J1_EXACT_MATCHING_RESPONSE_OBSERVED' -and [int]$observation.matchingResponseCount -eq 1) 'O3J1 matching-response observation is not exact.'
Assert-True ([string]$observation.requestId -eq $requestId -and [string]$observation.responseId -eq $responseId -and [string]$observation.sourceZipSha256 -eq $expectedSourceZipSha256) 'O3J1 matching-response observation identity changed.'

$publicationGatePath = Resolve-ProjectFile -RelativePath ([string]$invocation.publicationGate)
Assert-True ((Get-Sha256 -Path $publicationGatePath) -eq [string]$invocation.publicationGateSha256) 'O3J1 publication gate changed.'
$publicationGate = Get-Content -LiteralPath $publicationGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$publicationGate.state -eq 'PASS_O3J1_PUBLISHED_ONCE' -and [int]$publicationGate.publicationCount -eq 1 -and -not [bool]$publicationGate.requestRetryAuthorized) 'O3J1 publication evidence changed.'

Assert-True ((Get-Sha256 -Path $expectedSourceInvocation) -eq [string]$invocation.expectedCollectionInvocationSha256) 'O3J1 source invocation changed.'
Assert-True ((Get-Sha256 -Path (Join-Path $PSScriptRoot 'O3J1_RESULT_JSON_PROVIDER_CONFIG.json')) -eq [string]$invocation.expectedConfigurationSha256) 'O3J1 provider configuration changed.'
Assert-True ((Get-Sha256 -Path (Join-Path $PSScriptRoot 'OCV03_ResultJsonProviderV1.ps1')) -eq [string]$invocation.expectedProviderSha256) 'O3J1 provider changed.'
Assert-True ((Get-Sha256 -Path $verifier) -eq '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C') 'Portal response verifier changed.'
Assert-True ((Get-Sha256 -Path $certificate) -eq '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B') 'JBOD endpoint certificate changed.'
Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3J1 source response ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedSourceZipBytes) 'O3J1 source response ZIP byte count changed.'
Assert-True ((Get-Sha256 -Path $sourceZip) -eq $expectedSourceZipSha256) 'O3J1 source response ZIP hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig', 'RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3J1 response ZIP entry set changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and [int64]$manifestEntry.Length -le 65536) 'O3J1 response manifest is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try {
        $manifest = $reader.ReadToEnd() | ConvertFrom-Json
    }
    finally {
        $reader.Dispose()
    }
}
finally {
    $zip.Dispose()
}

Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O3J1 response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3J1 response manifest terminal state changed.'
Assert-True (@($manifest.files).Count -eq 3) 'O3J1 signed response manifest file count changed.'

foreach ($target in @($tempRoot, $collectedRoot, $reconstitutedRoot, $collectionGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $target)) "O3J1 create-new collection target exists: $target"
}

$preflightResult = [ordered]@{
    schema = 'argos_o3j1_response_collection_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3J1_EXACT_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
    invocationManifestSha256 = $expectedInvocationSha256
    sourceZipSha256 = $expectedSourceZipSha256
    sourceZipBytes = $expectedSourceZipBytes
    endpointState = [string]$manifest.state
    expectedJsonFileCount = 13
    signatureVerified = $false
    mutationsPerformed = $false
    imageBytesReadByCollector = $false
    sourceImageBytesReadByCollector = $false
    requestRetryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 8
    return
}

[void][IO.Directory]::CreateDirectory($tempRoot)
[IO.File]::Copy($sourceZip, $tempZip, $false)
Assert-True ((Get-Sha256 -Path $tempZip) -eq $expectedSourceZipSha256) 'O3J1 temporary response copy changed.'
Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract

$verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O3J1 signed response verification failed.'
Assert-True ([string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3J1 signed response correlation or terminal state changed.'
Assert-True ([string]$verification.SignerThumbprint -eq [string]$invocation.expectedSignerThumbprint) 'O3J1 JBOD signer changed.'

$stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
Assert-True ((Get-Item -LiteralPath $stdoutPath).Length -le 16777216) 'O3J1 stdout exceeded the bounded result limit.'
$endpointResult = Get-Content -LiteralPath $stdoutPath -Raw | ConvertFrom-Json
Assert-True ([string]$endpointResult.schema -eq 'argos_o3j1_entrypoint_result_v1' -and [string]$endpointResult.state -eq [string]$invocation.expectedEndpointResultState) 'O3J1 endpoint result state changed.'
Assert-True ([string]$endpointResult.revision -eq [string]$invocation.expectedEndpointRevision -and [bool]$endpointResult.installedProviderExecuted) 'O3J1 endpoint revision or installed execution evidence changed.'
Assert-True ([string]$endpointResult.providerSha256 -eq [string]$invocation.expectedProviderSha256 -and [string]$endpointResult.configurationSha256 -eq [string]$invocation.expectedConfigurationSha256 -and [string]$endpointResult.collectionInvocationSha256 -eq [string]$invocation.expectedCollectionInvocationSha256) 'O3J1 endpoint dependency hash changed.'
Assert-True ([bool]$endpointResult.sourceJsonFilesRead -and -not [bool]$endpointResult.sourceImageBytesRead -and -not [bool]$endpointResult.imageBytesRead) 'O3J1 endpoint JSON/image boundary changed.'
Assert-True (-not [bool]$endpointResult.sourceMutationPerformed -and -not [bool]$endpointResult.sourceDeletionPerformed -and -not [bool]$endpointResult.taskOrProcessActionPerformed -and -not [bool]$endpointResult.inspectionTasksChanged -and -not [bool]$endpointResult.healthyProcessorTouched -and -not [bool]$endpointResult.providerActivated -and -not [bool]$endpointResult.waferActionPerformed) 'O3J1 endpoint crossed a protected boundary.'
Assert-True ([bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.trainingEligible -and -not [bool]$endpointResult.xmlEligible -and -not [bool]$endpointResult.productionEligible -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3J1 endpoint authority widened.'

$collection = $endpointResult.collection
Assert-True ([string]$collection.schema -eq 'argos_ocv03_review_json_provider_result_v1' -and [string]$collection.state -eq 'PASS_O3J1_EXACT_RESULT_JSON_COLLECTED') 'O3J1 collection terminal contract changed.'
Assert-True ([int]$collection.fileCount -eq 13 -and @($collection.files).Count -eq 13 -and [bool]$collection.exactAllowlistConsumed) 'O3J1 exact collection cardinality changed.'
Assert-True ([bool]$collection.jsonTextOnly -and [bool]$collection.sourceFilesRead -and -not [bool]$collection.imageBytesRead -and -not [bool]$collection.sourceImageBytesRead -and -not [bool]$collection.sourceMutationPerformed -and -not [bool]$collection.sourceDeletionPerformed -and -not [bool]$collection.taskOrProcessActionPerformed -and -not [bool]$collection.providerActivated) 'O3J1 collection authority changed.'

$sourceInvocation = Get-Content -LiteralPath $expectedSourceInvocation -Raw | ConvertFrom-Json
$expectedRelativePaths = @($sourceInvocation.relativePaths | ForEach-Object { [string]$_.Replace('\', '/') } | Sort-Object)
$actualRelativePaths = @($collection.files | ForEach-Object { [string]$_.relativePath.Replace('\', '/') } | Sort-Object)
Assert-True ($expectedRelativePaths.Count -eq 13 -and @(Compare-Object -ReferenceObject $expectedRelativePaths -DifferenceObject $actualRelativePaths).Count -eq 0) 'O3J1 returned relative-path set changed.'

[void][IO.Directory]::CreateDirectory($tempReconstituted)
$tempFilesRoot = Join-Path $tempReconstituted 'files'
[void][IO.Directory]::CreateDirectory($tempFilesRoot)
$rows = New-Object Collections.Generic.List[object]
$targetNames = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
$totalBytes = [int64]0
foreach ($file in @($collection.files)) {
    $relativePath = [string]$file.relativePath.Replace('\', '/')
    $returnName = switch ($relativePath) {
        'SUMMARY.json' { 'SUMMARY.json'; break }
        'RUN_GATE.json' { 'RUN_GATE.json'; break }
        'EXECUTION.json' { 'EXECUTION.json'; break }
        default {
            $match = [regex]::Match($relativePath, '^62629-419_20260824112405_SLOT([0-9]{2})/NATIVE_WAFER_POSE_OPENCV_V2\.json$')
            Assert-True ($match.Success) "O3J1 returned an unexpected JSON identity: $relativePath"
            'S' + $match.Groups[1].Value + '.json'
        }
    }
    Assert-True ($targetNames.Add($returnName)) "O3J1 reconstructed target name is duplicated: $returnName"
    $rawText = [string]$file.rawJsonText
    [void]($rawText | ConvertFrom-Json)
    $bytes = (New-Object Text.UTF8Encoding($false, $true)).GetBytes($rawText)
    Assert-True ([int64]$bytes.Length -eq [int64]$file.bytes) "O3J1 returned byte count changed: $relativePath"
    Assert-True ((Get-Sha256Bytes -Bytes $bytes) -eq [string]$file.sha256) "O3J1 returned JSON hash changed: $relativePath"
    $targetPath = Join-Path $tempFilesRoot $returnName
    Write-BytesCreateNew -Path $targetPath -Bytes $bytes
    Assert-True ((Get-Sha256 -Path $targetPath) -eq [string]$file.sha256) "O3J1 reconstructed JSON hash changed: $relativePath"
    $totalBytes += [int64]$bytes.Length
    $rows.Add([pscustomobject]@{
        relativePath = $relativePath
        returnPath = 'files/' + $returnName
        bytes = [int64]$bytes.Length
        sha256 = [string]$file.sha256
    })
}
Assert-True ($rows.Count -eq 13 -and $targetNames.Count -eq 13 -and $totalBytes -eq [int64]$collection.totalBytes) 'O3J1 reconstructed JSON cardinality or total bytes changed.'

$mapping = [ordered]@{
    schema = 'argos_o3j1_source_to_return_mapping_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3J1_EXACT_13_JSON_RECONSTITUTED'
    requestId = $requestId
    responseId = $responseId
    sourceZipSha256 = $expectedSourceZipSha256
    fileCount = $rows.Count
    totalBytes = $totalBytes
    files = @($rows.ToArray())
    imageBytesRead = $false
    sourceImageBytesRead = $false
    sourceHashingPerformedByCollector = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path (Join-Path $tempReconstituted 'SOURCE_TO_RETURN_MAPPING.json') -Value $mapping -Depth 12

[void][IO.Directory]::CreateDirectory($collectedRoot)
[IO.File]::Copy($tempZip, $archivePath, $false)
Assert-True ((Get-Sha256 -Path $archivePath) -eq $expectedSourceZipSha256) 'O3J1 archived response changed.'
[IO.Directory]::Move($tempExtract, $extractionRoot)
[IO.Directory]::Move($tempReconstituted, $reconstitutedRoot)
[IO.File]::Delete($tempZip)
Assert-True (@(Get-ChildItem -LiteralPath $tempRoot -Force).Count -eq 0) 'O3J1 temporary root is not empty after verified collection.'
[IO.Directory]::Delete($tempRoot)

$finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3J1 final collected response verification failed.'
foreach ($row in $rows) {
    $finalPath = Join-Path $reconstitutedRoot ([string]$row.returnPath).Replace('/', '\')
    Assert-True ((Get-Item -LiteralPath $finalPath).Length -eq [int64]$row.bytes -and (Get-Sha256 -Path $finalPath) -eq [string]$row.sha256) "O3J1 final reconstructed JSON changed: $($row.relativePath)"
}

$result = [ordered]@{
    schema = 'argos_o3j1_exact_response_collection_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3J1_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED'
    disposition = 'DIAGNOSTIC_ONLY'
    requestId = $requestId
    responseId = $responseId
    invocationManifestSha256 = $expectedInvocationSha256
    responseZipBytes = $expectedSourceZipBytes
    responseZipSha256 = $expectedSourceZipSha256
    archivePath = $archivePath
    extractionRoot = $extractionRoot
    reconstitutedRoot = $reconstitutedRoot
    sourceToReturnMappingPath = Join-Path $reconstitutedRoot 'SOURCE_TO_RETURN_MAPPING.json'
    sourceToReturnMappingSha256 = Get-Sha256 -Path (Join-Path $reconstitutedRoot 'SOURCE_TO_RETURN_MAPPING.json')
    endpointState = [string]$finalVerification.EndpointState
    sourceRole = [string]$finalVerification.SourceRole
    signerThumbprint = [string]$finalVerification.SignerThumbprint
    signedFileCount = [int]$finalVerification.Files
    signatureVerified = $true
    endpointResultState = [string]$endpointResult.state
    endpointRevision = [string]$endpointResult.revision
    endpointStdoutBytes = [int64](Get-Item -LiteralPath (Join-Path $extractionRoot 'MAINTENANCE.stdout.txt')).Length
    endpointStdoutSha256 = Get-Sha256 -Path (Join-Path $extractionRoot 'MAINTENANCE.stdout.txt')
    jsonFileCount = $rows.Count
    jsonTotalBytes = $totalBytes
    files = @($rows.ToArray())
    temporaryCDriveRootRemoved = $true
    requestRetryAuthorized = $false
    imageBytesReadByCollector = $false
    sourceImageBytesReadByCollector = $false
    sourceHashingPerformedByCollector = $false
    sourceDeletionPerformed = $false
    inspectionTasksChanged = $false
    healthyProcessorTouched = $false
    providerActivated = $false
    waferActionPerformed = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path $collectionGatePath -Value $result -Depth 16
$result | ConvertTo-Json -Depth 16
