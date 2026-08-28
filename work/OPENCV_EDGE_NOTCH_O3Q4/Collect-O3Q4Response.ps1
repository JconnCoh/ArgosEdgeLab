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
$requestId = 'REQ_20260828T152800444Z_62629419O3Q4'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\A4Q'
$collectionGatePath = Join-Path $PSScriptRoot 'O3Q4_EXACT_RESPONSE_COLLECTION_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Resolve-ProjectPath([string]$RelativePath) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath) -and $RelativePath.IndexOfAny([char[]]'*?') -lt 0) 'O3Q4 collection project path is unsafe.'
    $full = [IO.Path]::GetFullPath((Join-Path $project $RelativePath.Replace('/', '\')))
    Assert-True ($full.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O3Q4 collection path escapes the project.'
    return $full
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3Q4 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O3Q4 response invocation must remain in the project.'
$invocationSha256 = Get-Sha256 $invocationPath
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3q4_exact_response_collection_invocation_v1' -and [string]$invocation.state -eq 'PASS_O3Q4_EXACT_RESPONSE_COLLECTION_INVOCATION_FROZEN') 'O3Q4 response invocation schema or state changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -match '^R_[A-Za-z0-9_\-]+$') 'O3Q4 response invocation identity changed.'
Assert-True ([int64]$invocation.sourceZipBytes -gt 0 -and [int64]$invocation.sourceZipBytes -le 10485760 -and [string]$invocation.sourceZipSha256 -match '^[A-F0-9]{64}$' -and [int]$invocation.maximumSourceZips -eq 1) 'O3Q4 response invocation archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [string]$invocation.expectedEndpointResultState -eq 'COMPLETE_O3Q4_NUMERIC_REVIEW_ONLY') 'O3Q4 response invocation terminal contract changed.'
Assert-True ([bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized -and [bool]$invocation.temporaryCDriveRootMustBeRemovedAfterVerifiedCollection) 'O3Q4 response invocation authority changed.'
Assert-True (-not [bool]$invocation.existingProcessesQueried -and [int]$invocation.taskActions -eq 0 -and -not [bool]$invocation.sourceMutationPerformed -and -not [bool]$invocation.sourceDeletionPerformed -and -not [bool]$invocation.providerActivated) 'O3Q4 response collection runtime or source boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3Q4 response collection authority widened.'

$responseId = [string]$invocation.responseId
$sourceZip = [IO.Path]::GetFullPath(([string]$invocation.sourceZip).Replace('/', '\'))
$expectedBytes = [int64]$invocation.sourceZipBytes
$expectedSha256 = [string]$invocation.sourceZipSha256
$archivePath = Resolve-ProjectPath ([string]$invocation.archivePath)
$extractionRoot = Resolve-ProjectPath ([string]$invocation.extractionRoot)
$archiveDir = Split-Path -Parent $archivePath
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
Assert-True ($sourceZip.Equals(('U:\ProjectPortalRO\responses\' + $responseId + '.ready.zip'), [StringComparison]::OrdinalIgnoreCase)) 'O3Q4 response source path changed.'
foreach ($dependency in @($sourceZip, $certificate, $verifier)) { Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O3Q4 response dependency absent: $dependency" }
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes -and (Get-Sha256 $sourceZip) -eq $expectedSha256) 'O3Q4 response ZIP bytes or hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig', 'RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3Q4 response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O3Q4 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }
Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3Q4 response manifest identity or terminal state changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o3q4_response_collection_preflight_v1'; checkedUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_O3Q4_EXACT_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId; responseId = $responseId; invocationManifestSha256 = $invocationSha256; sourceZipSha256 = $expectedSha256; sourceZipBytes = $expectedBytes
    endpointState = [string]$manifest.state; signatureVerified = $false; mutationsPerformed = $false; existingProcessesQueried = $false; taskActions = 0
    sourceMutationPerformed = $false; sourceDeletionPerformed = $false; providerActivated = $false; requestRetryAuthorized = $false; reviewOnly = $true; productionRoutingEnabled = $false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 6; return }

foreach ($path in @($tempRoot, $archivePath, $extractionRoot, $collectionGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O3Q4 create-new collection target exists: $path" }
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O3Q4 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3Q4 signed response verification failed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3Q4 JBOD signer changed.'

    $stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
    Assert-True ((Get-Item -LiteralPath $stdoutPath).Length -le 10485760) 'O3Q4 stdout exceeded the bounded numeric-result limit.'
    $endpointResult = Get-Content -LiteralPath $stdoutPath -Raw | ConvertFrom-Json
    Assert-True ([string]$endpointResult.schema -eq 'argos_ocv03_o3q4_endpoint_result_v1' -and [string]$endpointResult.state -eq 'COMPLETE_O3Q4_NUMERIC_REVIEW_ONLY' -and [string]$endpointResult.revision -eq 'FMOCV03_O3Q4_20260828T151900Z' -and -not [bool]$endpointResult.rehearsal) 'O3Q4 endpoint result identity changed.'
    Assert-True ([string]$endpointResult.identity -eq '62629-419_20260824112405_SLOT16' -and [int]$endpointResult.seedCount -eq 21) 'O3Q4 Slot16 numeric identity or frozen seed count changed.'
    Assert-True (-not [bool]$endpointResult.ownedChildTimedOut -and -not [bool]$endpointResult.ownedChildKilledOnTimeout -and [int]$endpointResult.existingProcessQueryCount -eq 0 -and [int]$endpointResult.taskActionCount -eq 0 -and -not [bool]$endpointResult.protectedProcessorTouched) 'O3Q4 endpoint crossed its process/task boundary or timed out.'
    Assert-True ([bool]$endpointResult.allFrozenDfSeedsConsumed -and -not [bool]$endpointResult.knownNotchLocationConsumed -and -not [bool]$endpointResult.hotspotMembershipConsumed -and -not [bool]$endpointResult.argosRotationMetadataConsumed -and -not [bool]$endpointResult.backsidePixelsConsumed -and [int]$endpointResult.dfTopologyInvocationCount -eq 0) 'O3Q4 endpoint changed its frozen-input or prior boundary.'
    Assert-True (-not [bool]$endpointResult.rasterOutputCreated -and -not [bool]$endpointResult.sourceMutationPerformed -and -not [bool]$endpointResult.sourceDeletionPerformed -and -not [bool]$endpointResult.providerActivated -and -not [bool]$endpointResult.requestRetryAuthorized) 'O3Q4 endpoint crossed its source/provider/retry boundary.'
    Assert-True ([bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.trainingEligible -and -not [bool]$endpointResult.xmlEligible -and -not [bool]$endpointResult.productionEligible -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3Q4 endpoint authority widened.'
    $numericResult = $endpointResult.numericResult
    Assert-True ([string]$numericResult.schema -eq 'argos_ocv03_o3p8_front_split_notch_result_v1' -and [int]$numericResult.inputCount -eq 1 -and @($numericResult.rows).Count -eq 1) 'O3Q4 signed numeric-result schema or cardinality changed.'
    Assert-True (-not [bool]$numericResult.knownNotchLocationConsumed -and -not [bool]$numericResult.notchAnglePriorConsumed -and -not [bool]$numericResult.fixedAngularSearchWindowConsumed -and -not [bool]$numericResult.scorerInputsConsumed -and -not [bool]$numericResult.backsidePixelsConsumed -and -not [bool]$numericResult.rasterOutputCreated -and -not [bool]$numericResult.sourceMutationPerformed) 'O3Q4 signed numeric result consumed a prohibited prior or changed source state.'

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O3Q4 archived response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3Q4 final collected response verification failed.'

    $numericPass = [bool]$endpointResult.numericIndependentPass
    $disposition = if ($numericPass) { 'PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH' } else { 'HOLD_O3Q4_SLOT16_NUMERIC_INDEPENDENT_RESULT' }
    $result = [ordered]@{
        schema = 'argos_o3q4_exact_response_collection_gate_v1'; collectedUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_O3Q4_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED'; disposition = $disposition
        requestId = $requestId; responseId = $responseId; invocationManifestSha256 = $invocationSha256; responseZipBytes = $expectedBytes; responseZipSha256 = $expectedSha256
        archivePath = $archivePath; extractionRoot = $extractionRoot; endpointState = [string]$finalVerification.EndpointState; sourceRole = [string]$finalVerification.SourceRole
        signerThumbprint = [string]$finalVerification.SignerThumbprint; signedFileCount = [int]$finalVerification.Files; signatureVerified = $true
        endpointResultState = [string]$endpointResult.state; numericIndependentPass = $numericPass; numericDecision = [string]$endpointResult.numericDecision
        identity = [string]$endpointResult.identity; seedCount = [int]$endpointResult.seedCount; eligibleCount = [int]$endpointResult.eligibleCount
        candidateLocalTopologyInsufficiencyCount = [int]$endpointResult.candidateLocalTopologyInsufficiencyCount; selected = $endpointResult.selected
        engineState = [string]$endpointResult.engineState; engineOutputPath = [string]$endpointResult.engineOutputPath; engineOutputSha256 = [string]$endpointResult.engineOutputSha256
        ownedChildProcessId = [int]$endpointResult.ownedChildProcessId; ownedChildTimedOut = $false; ownedChildKilledOnTimeout = $false; existingProcessQueryCount = 0; taskActionCount = 0
        allFrozenDfSeedsConsumed = $true; knownNotchLocationConsumed = $false; hotspotMembershipConsumed = $false; argosRotationMetadataConsumed = $false; backsidePixelsConsumed = $false
        dfTopologyInvocationCount = 0; rasterOutputCreated = $false; sourceMutationPerformed = $false; sourceDeletionPerformed = $false; protectedProcessorTouched = $false; providerActivated = $false
        temporaryCDriveRootRemoved = $true; requestRetryAuthorized = $false; thresholdOrAlgorithmChanged = $false; bfSlot16CoveragePartial = $true; holdsCleared = $false
        reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false
    }
    Write-JsonCreateNew -Path $collectionGatePath -Value $result -Depth 12
    $collectionGateCreated = $true
    $result | ConvertTo-Json -Depth 12
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
        Assert-True ($resolvedTemp -eq 'C:\A4Q') 'O3Q4 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
