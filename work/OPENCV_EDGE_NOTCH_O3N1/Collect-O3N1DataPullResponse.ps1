#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Resolve-ProjectFile([string]$Project,[string]$Relative) {
    $full = [IO.Path]::GetFullPath((Join-Path $Project $Relative.Replace('/','\')))
    Assert-True ($full.StartsWith($Project.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) "O3N1 DATA_PULL collector dependency escaped project: $Relative"
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "O3N1 DATA_PULL collector dependency is absent: $Relative"
    return $full
}
function Write-NewJson([string]$Path,[object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3N1 DATA_PULL collection gate exists: $Path"
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}
function Read-BoundedZipEntry([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry -and [int64]$entry.Length -le $MaximumBytes) "O3N1 DATA_PULL ZIP entry is absent or unbounded: $Name"
    $stream = $entry.Open()
    try {
        $memory = New-Object IO.MemoryStream
        try {
            $stream.CopyTo($memory)
            return ,([byte[]]$memory.ToArray())
        }
        finally { $memory.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}
function Test-ByteArrayCases {
    $cases = [ordered]@{
        ZERO = [byte[]]@()
        ONE = [byte[]]@(17)
        MANY = [byte[]]@(1,2,3,4,5,6,7)
    }
    $passed = New-Object 'Collections.Generic.List[string]'
    foreach ($case in $cases.GetEnumerator()) {
        $memory = New-Object IO.MemoryStream
        try {
            $writer = New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
            try {
                $entry = $writer.CreateEntry(([string]$case.Key + '.bin'),[IO.Compression.CompressionLevel]::NoCompression)
                $stream = $entry.Open()
                try {
                    $bytes = [byte[]]$case.Value
                    if ($bytes.Length -gt 0) { $stream.Write($bytes,0,$bytes.Length) }
                }
                finally { $stream.Dispose() }
            }
            finally { $writer.Dispose() }
            $memory.Position = 0
            $reader = New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Read,$true)
            try { $actual = Read-BoundedZipEntry -Archive $reader -Name ([string]$case.Key + '.bin') -MaximumBytes 64 }
            finally { $reader.Dispose() }
            Assert-True ($actual -is [byte[]]) "O3N1 DATA_PULL byte-array case did not return byte[]: $($case.Key)"
            Assert-True ($actual.Length -eq ([byte[]]$case.Value).Length) "O3N1 DATA_PULL byte-array length changed: $($case.Key)"
            [void]$passed.Add([string]$case.Key)
        }
        finally { $memory.Dispose() }
    }
    return $passed.ToArray()
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_DATA_PULL_RESPONSE_COLLECTION_INVOCATION.json'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3N1 DATA_PULL response invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3n1_data_pull_response_collection_invocation_v1' -and [string]$invocation.state -eq 'FROZEN_EXACT_MATCHING_RESPONSE') 'O3N1 DATA_PULL response invocation identity changed.'
Assert-True ([string]$invocation.collectorScriptSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3N1 DATA_PULL response invocation does not pin the exact collector.'
Assert-True ([bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized -and -not [bool]$invocation.imagePixelsDecodedByCollector) 'O3N1 DATA_PULL response selection or pixel boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3N1 DATA_PULL response collector authority widened.'

$observation = Resolve-ProjectFile $project ([string]$invocation.matchingResponseObservation)
Assert-True ((Get-Sha256 $observation) -eq [string]$invocation.matchingResponseObservationSha256) 'O3N1 DATA_PULL matching response observation changed.'
$observationValue = Get-Content -LiteralPath $observation -Raw | ConvertFrom-Json
Assert-True ([string]$observationValue.state -eq 'MATCHING_DATA_PULL_RESPONSE_OBSERVED_SIGNATURE_PENDING_COLLECTION' -and -not [bool]$observationValue.signatureVerified) 'O3N1 DATA_PULL matching response observation state changed.'
$publication = Resolve-ProjectFile $project ([string]$invocation.publicationGate)
Assert-True ((Get-Sha256 $publication) -eq [string]$invocation.publicationGateSha256) 'O3N1 DATA_PULL publication gate changed.'
$publicationValue = Get-Content -LiteralPath $publication -Raw | ConvertFrom-Json
Assert-True ([string]$publicationValue.state -eq 'PASS_O3N1_DATA_PULL_REQUEST_PUBLISHED_ONCE' -and [int]$publicationValue.publicationCount -eq 1 -and -not [bool]$publicationValue.requestRetryAuthorized) 'O3N1 DATA_PULL publication evidence changed.'
$renderTerminal = Resolve-ProjectFile $project ([string]$invocation.renderTerminalGate)
Assert-True ((Get-Sha256 $renderTerminal) -eq [string]$invocation.renderTerminalGateSha256) 'O3N1 render terminal gate changed.'
$renderTerminalValue = Get-Content -LiteralPath $renderTerminal -Raw | ConvertFrom-Json
Assert-True ([string]$renderTerminalValue.state -eq 'PASS_O3N1_MATCHING_SIGNED_RENDER_RESPONSE_COLLECTED_R3' -and [bool]$renderTerminalValue.signatureVerified -and [bool]$renderTerminalValue.dataPullNowEligible) 'O3N1 signed render terminal proof changed.'
Assert-True ([string]$renderTerminalValue.detectorState -eq 'HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH' -and [int]$renderTerminalValue.eligiblePhysicalCandidateCount -eq 0 -and [int]$renderTerminalValue.physicalCandidateCount -eq 0) 'O3N1 detector hold changed before DATA_PULL collection.'
Assert-True ([string]$renderTerminalValue.exportRelativePath -eq [string]$invocation.expectedRelativePath -and [int64]$renderTerminalValue.exportZipBytes -eq [int64]$invocation.expectedEntryBytes -and [string]$renderTerminalValue.exportZipSha256 -eq [string]$invocation.expectedEntrySha256) 'O3N1 signed render export identity changed.'
$verifier = Resolve-ProjectFile $project ([string]$invocation.verifier)
$certificate = Resolve-ProjectFile $project ([string]$invocation.endpointCertificate)
Assert-True ((Get-Sha256 $verifier) -eq [string]$invocation.verifierSha256 -and (Get-Sha256 $certificate) -eq [string]$invocation.endpointCertificateSha256) 'O3N1 DATA_PULL verifier or certificate changed.'

$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3N1 DATA_PULL matching response ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes -and (Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'O3N1 DATA_PULL matching response ZIP changed.'
$responseRoot = [IO.Path]::GetFullPath([string]$invocation.temporaryResponseRoot)
$responseZip = [IO.Path]::GetFullPath([string]$invocation.temporaryResponseZip)
$responseExtract = [IO.Path]::GetFullPath([string]$invocation.temporaryResponseExtractionRoot)
$payloadExtract = [IO.Path]::GetFullPath([string]$invocation.temporaryPayloadExtractionRoot)
$gatePath = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.collectionGate).Replace('/','\')))
foreach ($target in @($responseRoot,$payloadExtract,$gatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $target)) "O3N1 DATA_PULL create-new collection target exists: $target"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$byteArrayCases = @(Test-ByteArrayCases)
Assert-True ($byteArrayCases.Count -eq 3 -and $byteArrayCases -contains 'ZERO' -and $byteArrayCases -contains 'ONE' -and $byteArrayCases -contains 'MANY') 'O3N1 DATA_PULL byte-array cases failed.'
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($archive.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq 4 -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3N1 DATA_PULL response ZIP entry set changed.'
    $manifestBytes = Read-BoundedZipEntry -Archive $archive -Name 'PORTAL_RESPONSE_MANIFEST.json' -MaximumBytes 65536
    $manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
}
finally { $archive.Dispose() }
Assert-True ([string]$manifest.requestId -eq [string]$invocation.requestId -and [string]$manifest.responseId -eq [string]$invocation.responseId -and [string]$manifest.sourceRole -eq [string]$invocation.expectedSourceRole -and [string]$manifest.state -eq [string]$invocation.expectedManifestState) 'O3N1 DATA_PULL response manifest correlation changed.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o3n1_data_pull_response_collection_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3N1_DATA_PULL_RESPONSE_COLLECTION_PREFLIGHT';requestId=[string]$invocation.requestId;responseId=[string]$invocation.responseId
        sourceZipSha256=[string]$invocation.sourceZipSha256;manifestState=[string]$manifest.state;signatureVerified=$false
        byteArrayCases=$byteArrayCases;matchingSignedRenderTerminalVerified=$true;detectorStatePreserved='HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH'
        mutationsPerformed=$false;imagePixelsDecoded=$false;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[void][IO.Directory]::CreateDirectory($responseRoot)
[IO.File]::Copy($sourceZip,$responseZip,$false)
Assert-True ((Get-Sha256 $responseZip) -eq [string]$invocation.sourceZipSha256) 'O3N1 DATA_PULL temporary response copy changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($responseZip,$responseExtract)
$verification = & $verifier -PackagePath $responseExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId ([string]$invocation.requestId)
Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.EndpointState -eq [string]$invocation.expectedManifestState -and [string]$verification.SignerThumbprint -eq [string]$invocation.expectedSignerThumbprint) 'O3N1 DATA_PULL JBOD signature or terminal correlation failed.'

$payloadZip = Join-Path $responseExtract 'DATA_PULL_PAYLOAD.zip'
$resultPath = Join-Path $responseExtract 'RESULT.json'
Assert-True ((Get-Item -LiteralPath $payloadZip).Length -eq [int64]$invocation.expectedPayloadBytes -and (Get-Sha256 $payloadZip) -eq [string]$invocation.expectedPayloadSha256) 'O3N1 DATA_PULL payload identity changed.'
Assert-True ((Get-Item -LiteralPath $resultPath).Length -eq [int64]$invocation.expectedResultJsonBytes -and (Get-Sha256 $resultPath) -eq [string]$invocation.expectedResultJsonSha256) 'O3N1 DATA_PULL result identity changed.'
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
Assert-True ([string]$result.schema -eq 'argos_project_portal_data_pull_result_v2' -and [string]$result.state -eq 'PASS_DATA_PULL' -and [string]$result.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'O3N1 DATA_PULL result state changed.'
$resultFiles = @($result.files)
Assert-True ($resultFiles.Count -eq 1 -and [string]$resultFiles[0].entryPath -eq [string]$invocation.expectedEntryPath -and [int64]$resultFiles[0].bytes -eq [int64]$invocation.expectedEntryBytes -and [string]$resultFiles[0].sha256 -eq [string]$invocation.expectedEntrySha256) 'O3N1 DATA_PULL returned file mapping changed.'

[IO.Compression.ZipFile]::ExtractToDirectory($payloadZip,$payloadExtract)
$returnedFiles = @(Get-ChildItem -LiteralPath $payloadExtract -Recurse -File -ErrorAction Stop)
Assert-True ($returnedFiles.Count -eq 1) 'O3N1 DATA_PULL extracted payload file cardinality changed.'
$reviewZip = Join-Path $payloadExtract ([string]$invocation.expectedEntryPath).Replace('/','\')
Assert-True (Test-Path -LiteralPath $reviewZip -PathType Leaf) 'O3N1 returned review ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $reviewZip).Length -eq [int64]$invocation.expectedEntryBytes -and (Get-Sha256 $reviewZip) -eq [string]$invocation.expectedEntrySha256) 'O3N1 returned review ZIP identity changed.'

$reviewArchive = [IO.Compression.ZipFile]::OpenRead($reviewZip)
try {
    $reviewEntries = @($reviewArchive.Entries)
    Assert-True ($reviewEntries.Count -eq 91 -and @($reviewEntries | Where-Object { [string]$_.FullName -eq 'MANIFEST.json' }).Count -eq 1) 'O3N1 review ZIP entry set changed.'
    Assert-True (@($reviewEntries | Where-Object { [string]$_.FullName -match '(?i)\.png$' }).Count -eq 90) 'O3N1 review ZIP raster asset cardinality changed.'
    $renderManifestBytes = Read-BoundedZipEntry -Archive $reviewArchive -Name 'MANIFEST.json' -MaximumBytes 131072
    $renderManifestSha256 = Get-BytesSha256 $renderManifestBytes
    $renderManifest = [Text.Encoding]::UTF8.GetString($renderManifestBytes) | ConvertFrom-Json
}
finally { $reviewArchive.Dispose() }
Assert-True ($renderManifestSha256 -eq '69FDAD4AB4DCF06A8A38C76EA009F0DA178896E8D0291668670AB9ADD24A05C8') 'O3N1 returned render manifest hash changed.'
Assert-True ([string]$renderManifest.schema -eq 'argos_ocv03_full_perimeter_topology_manifest_v1' -and [string]$renderManifest.revision -eq 'O3M7_SLOT16_SPLIT_METHOD_FULL_PERIMETER_R7_20260827' -and [string]$renderManifest.state -eq 'COMPLETE_REVIEW_ONLY_FULL_PERIMETER_TOPOLOGY') 'O3N1 returned render manifest state changed.'
Assert-True ([int]$renderManifest.inputCount -eq 2 -and [bool]$renderManifest.inputHashesMatched -and [bool]$renderManifest.fullPerimeterInference -and [double]$renderManifest.tileCoverageDegrees -eq 360.0 -and [bool]$renderManifest.rawImageCoordinateSystemUsed) 'O3N1 returned source or full-perimeter evidence changed.'
Assert-True ([string]$renderManifest.channelMethods.BF -eq 'TOP_CONNECTED_TOPOLOGY_FULL_360' -and [string]$renderManifest.channelMethods.DF -eq 'OUTER_EDGE_RADIAL_FULL_360') 'O3N1 returned split channel methods changed.'
Assert-True (-not [bool]$renderManifest.backsidePixelsConsumed -and -not [bool]$renderManifest.argosRotationMetadataConsumed -and -not [bool]$renderManifest.orientationMetadataConsumed -and -not [bool]$renderManifest.knownNotchLocationConsumed -and -not [bool]$renderManifest.notchAnglePriorConsumed -and -not [bool]$renderManifest.fixedAngularSearchWindowConsumed -and -not [bool]$renderManifest.operatorLocationConsumedBeforeOutputFreeze) 'O3N1 returned prior or appearance boundary changed.'
Assert-True (-not [bool]$renderManifest.interpolatedContourRenderedAsMeasured -and [string]$renderManifest.notchOverlaySemantics -eq 'RED_MEASURED_CHANNEL_CONTOUR_MOUTH_TO_MOUTH; NO_STRAIGHT_RED_AXIS_LINE') 'O3N1 returned contour semantics changed.'
$renderResults = @($renderManifest.results)
Assert-True ($renderResults.Count -eq 1) 'O3N1 returned result cardinality changed.'
$slot16 = $renderResults[0]
Assert-True ([string]$slot16.pairId -eq '62629-419_SLOT16' -and [string]$slot16.state -eq 'HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH') 'O3N1 returned Slot16 hold changed.'
Assert-True ([string]$slot16.bf.state -eq 'HOLD_PARTIAL_TILE_TOPOLOGY_COVERAGE' -and [int]$slot16.bf.candidateCount -eq 1 -and @($slot16.bf.candidates).Count -eq 1) 'O3N1 returned BF evidence changed.'
Assert-True ([string]$slot16.df.state -eq 'PASS_R6_RADIAL_FULL_PERIMETER_SCANNED' -and [int]$slot16.df.candidateCount -eq 21 -and @($slot16.df.candidates).Count -eq 21) 'O3N1 returned DF evidence changed.'
Assert-True (@($slot16.physicalIndentationCandidates).Count -eq 0 -and @($slot16.eligiblePhysicalCandidateIndices).Count -eq 0 -and @($slot16.bfOnlyCandidateIndices).Count -eq 1 -and @($slot16.dfOnlyCandidateIndices).Count -eq 21 -and $null -eq $slot16.selectedReviewOnlyManufacturedNotch) 'O3N1 returned physical candidate reconciliation changed.'
Assert-True (-not [bool]$slot16.bfDfPoseAveraged -and -not [bool]$slot16.backsidePixelsConsumed -and -not [bool]$slot16.argosRotationMetadataConsumed) 'O3N1 returned paired-channel or coordinate boundary changed.'
Assert-True (-not [bool]$renderManifest.sourceMutationPerformed -and -not [bool]$renderManifest.providerActivated -and -not [bool]$renderManifest.processorTouched -and -not [bool]$renderManifest.holdCleared -and [bool]$renderManifest.reviewOnly -and -not [bool]$renderManifest.trainingEligible -and -not [bool]$renderManifest.xmlEligible -and -not [bool]$renderManifest.productionEligible -and -not [bool]$renderManifest.productionRoutingEnabled) 'O3N1 returned protected or authority boundary changed.'

$gate = [ordered]@{
    schema='argos_o3n1_data_pull_response_collection_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_MATCHING_SIGNED_DATA_PULL_RESPONSE_COLLECTED'
    requestId=[string]$invocation.requestId;responseId=[string]$invocation.responseId;responseZipPath=$responseZip
    responseZipBytes=[int64]$invocation.sourceZipBytes;responseZipSha256=[string]$invocation.sourceZipSha256
    responseManifestSha256=Get-Sha256 (Join-Path $responseExtract 'PORTAL_RESPONSE_MANIFEST.json');responseSignatureSha256=Get-Sha256 (Join-Path $responseExtract 'PORTAL_RESPONSE_MANIFEST.sig')
    signatureVerified=$true;signerThumbprint=[string]$verification.SignerThumbprint;endpointState=[string]$verification.EndpointState
    dataPullPayloadPath=$payloadZip;dataPullPayloadBytes=[int64]$invocation.expectedPayloadBytes;dataPullPayloadSha256=[string]$invocation.expectedPayloadSha256
    reviewZipPath=$reviewZip;reviewZipBytes=[int64]$invocation.expectedEntryBytes;reviewZipSha256=[string]$invocation.expectedEntrySha256
    renderManifestPath='MANIFEST.json';renderManifestSha256=$renderManifestSha256;reviewZipEntryCount=91;renderRasterAssetFileCount=90
    sourceImageReadCount=2;sourceHashesMatched=$true;detectorState='HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH'
    bfState='HOLD_PARTIAL_TILE_TOPOLOGY_COVERAGE';bfCandidateCount=1;dfState='PASS_R6_RADIAL_FULL_PERIMETER_SCANNED';dfCandidateCount=21
    eligiblePhysicalCandidateCount=0;physicalCandidateCount=0;byteArrayCases=$byteArrayCases
    imagePixelsDecodedByCollector=$false;detectorRerunPerformedByCollector=$false;renderDetectorRerunPerformed=$true;thresholdOrAlgorithmChanged=$false;sourceMutationPerformed=$false
    backsidePixelsConsumed=$false;argosRotationMetadataConsumed=$false;taskOrProcessActionPerformed=$false;processorTouched=$false;providerActivated=$false;holdCleared=$false
    requestRetryAuthorized=$false;gatewayAcceptanceIsExecutionEvidence=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-NewJson -Path $gatePath -Value $gate
$gate | ConvertTo-Json -Depth 14
