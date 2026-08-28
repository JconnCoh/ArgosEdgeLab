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
$responseId = 'R_4972FF4F6E27_20260828155653502_d78b4283'
$sourceZip = 'U:\ProjectPortalRO\responses\R_4972FF4F6E27_20260828155653502_d78b4283.ready.zip'
$expectedBytes = 2674
$expectedSha256 = '72CD823F644C49DBB847B49FDAD4BC1836389A8CD4810840F503D2B4A2FB85CA'
$expectedInvocationSha256 = '50F4340566F597C0493F2C00EC728C137706DBDE3D2E0CC45D0DAED97788A3B2'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\A4Q'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')
$collectionGatePath = Join-Path $PSScriptRoot 'O3Q4_FAILED_RESPONSE_COLLECTION_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3Q4 failed-response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O3Q4 failed-response invocation escaped the project.'
Assert-True ((Get-Sha256 $invocationPath) -eq $expectedInvocationSha256) 'O3Q4 failed-response invocation manifest changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3q4_failed_response_collection_invocation_v1' -and [string]$invocation.state -eq 'PASS_O3Q4_FAILED_RESPONSE_COLLECTION_INVOCATION_FROZEN') 'O3Q4 failed-response invocation schema or state changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId -and [string]$invocation.sourceZipSha256 -eq $expectedSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedBytes) 'O3Q4 failed-response invocation identity changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'FAILED' -and [int]$invocation.maximumSourceZips -eq 1 -and [bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized) 'O3Q4 failed-response invocation terminal boundary changed.'
Assert-True (-not [bool]$invocation.imageBytesReadByCollector -and -not [bool]$invocation.sourceImageHashingPerformedByCollector -and -not [bool]$invocation.sourceMutationPerformed -and -not [bool]$invocation.sourceDeletionPerformed) 'O3Q4 failed-response collection source boundary changed.'
Assert-True (-not [bool]$invocation.existingProcessesQueried -and [int]$invocation.taskActions -eq 0 -and -not [bool]$invocation.protectedProcessorTouched -and -not [bool]$invocation.providerActivated) 'O3Q4 failed-response collection runtime boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3Q4 failed-response collection authority widened.'

foreach ($dependency in @($sourceZip, $certificate, $verifier)) { Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O3Q4 failed-response dependency absent: $dependency" }
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes -and (Get-Sha256 $sourceZip) -eq $expectedSha256) 'O3Q4 failed-response ZIP bytes or hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('FAILURE.json', 'MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3Q4 failed-response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O3Q4 failed-response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }
Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'FAILED') 'O3Q4 failed-response manifest identity or state changed.'
Assert-True (@($manifest.files).Count -eq 3 -and [bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled) 'O3Q4 failed-response manifest authority or file count changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o3q4_failed_response_collection_preflight_v1'; checkedUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_O3Q4_FAILED_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId; responseId = $responseId; invocationManifestSha256 = $expectedInvocationSha256; sourceZipSha256 = $expectedSha256; sourceZipBytes = $expectedBytes
    endpointState = 'FAILED'; signatureVerified = $false; mutationsPerformed = $false; requestRetryAuthorized = $false; existingProcessesQueried = $false; taskActions = 0
    imageBytesReadByCollector = $false; sourceImageHashingPerformedByCollector = $false; sourceMutationPerformed = $false; sourceDeletionPerformed = $false; providerActivated = $false
    reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 6; return }

foreach ($path in @($tempRoot, $archivePath, $extractionRoot, $collectionGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O3Q4 failed-response create-new target exists: $path" }
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O3Q4 failed-response temporary copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'FAILED') 'O3Q4 signed failure response verification failed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3Q4 failed-response signer changed.'

    $failurePath = Join-Path $tempExtract 'FAILURE.json'
    $stderrPath = Join-Path $tempExtract 'MAINTENANCE.stderr.txt'
    $stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
    Assert-True ((Get-Item -LiteralPath $failurePath).Length -le 65536 -and (Get-Item -LiteralPath $stderrPath).Length -le 10485760 -and (Get-Item -LiteralPath $stdoutPath).Length -eq 0) 'O3Q4 failed-response payload sizes changed.'
    $failure = Get-Content -LiteralPath $failurePath -Raw | ConvertFrom-Json
    Assert-True ([string]$failure.schema -eq 'argos_project_portal_failure_v1' -and [string]$failure.state -eq 'FAILED' -and [bool]$failure.reviewOnly -and -not [bool]$failure.productionRoutingEnabled) 'O3Q4 failure payload schema or authority changed.'
    $stderrFirstLine = [string](Get-Content -LiteralPath $stderrPath -TotalCount 1)

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O3Q4 archived failed response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'FAILED') 'O3Q4 final collected failure verification failed.'

    $result = [ordered]@{
        schema = 'argos_o3q4_failed_response_collection_gate_v1'; collectedUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_O3Q4_EXACT_SIGNED_TERMINAL_FAILURE_COLLECTED'; disposition = 'FAILED_HOLD_NO_RETRY'
        requestId = $requestId; responseId = $responseId; invocationManifestSha256 = $expectedInvocationSha256; responseZipBytes = $expectedBytes; responseZipSha256 = $expectedSha256
        archivePath = $archivePath; extractionRoot = $extractionRoot; endpointState = [string]$finalVerification.EndpointState; sourceRole = [string]$finalVerification.SourceRole
        signerThumbprint = [string]$finalVerification.SignerThumbprint; signedFileCount = [int]$finalVerification.Files; signatureVerified = $true
        manifestSha256 = Get-Sha256 (Join-Path $extractionRoot 'PORTAL_RESPONSE_MANIFEST.json'); signatureSha256 = Get-Sha256 (Join-Path $extractionRoot 'PORTAL_RESPONSE_MANIFEST.sig')
        failureCreatedUtc = [string]$failure.createdUtc; failureDetail = [string]$failure.detail; scriptStackPresent = -not [string]::IsNullOrWhiteSpace([string]$failure.scriptStack)
        failureSha256 = Get-Sha256 (Join-Path $extractionRoot 'FAILURE.json'); stderrBytes = [int64](Get-Item -LiteralPath (Join-Path $extractionRoot 'MAINTENANCE.stderr.txt')).Length
        stderrSha256 = Get-Sha256 (Join-Path $extractionRoot 'MAINTENANCE.stderr.txt'); stderrFirstLine = $stderrFirstLine; stdoutBytes = 0
        temporaryCDriveRootRemoved = $true; requestRetryAuthorized = $false; requestRetryPerformed = $false; matchingResponseCount = 1; nonMatchingResponseCollected = $false
        collectorImageBytesRead = $false; sourceImageHashingPerformedByCollector = $false; sourceMutationPerformed = $false; sourceDeletionPerformed = $false
        existingProcessesQueried = $false; taskActions = 0; protectedProcessorTouched = $false; providerActivated = $false; thresholdOrAlgorithmChanged = $false; holdsCleared = $false
        reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false
    }
    Write-JsonCreateNew -Path $collectionGatePath -Value $result -Depth 10
    $collectionGateCreated = $true
    $result | ConvertTo-Json -Depth 10
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
        Assert-True ($resolvedTemp -eq 'C:\A4Q') 'O3Q4 failed-response temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
