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
$requestId = 'REQ_20260827T141000111Z_62629419C3A1'
$responseId = 'R_96293D05BC45_20260827143055769_eb895d3c'
$sourceZip = 'U:\ProjectPortalRO\responses\R_96293D05BC45_20260827143055769_eb895d3c.ready.zip'
$expectedBytes = 10695
$expectedSha256 = '7CFD6195E3BBD0369C1A6468102E27A9654BFE520C8D18680A20B560CAC63C83'
$expectedInvocationSha256 = '962521E426102EC52F432BA3ED2A8C4E1196D9A1BB1CE937327F35D72CB3B960'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\O3C1R_62629'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')
$collectionGatePath = Join-Path $PSScriptRoot 'O3C1_EXACT_RESPONSE_COLLECTION_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    $jsonBytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($jsonBytes, 0, $jsonBytes.Length) }
    finally { $stream.Dispose() }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3C1 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ((Get-Sha256 $invocationPath) -eq $expectedInvocationSha256) 'O3C1 response invocation manifest changed.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3c1_exact_response_collection_invocation_v1') 'O3C1 response invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O3C1 response invocation identity changed.'
Assert-True ([string]$invocation.sourceZipSha256 -eq $expectedSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedBytes -and [int]$invocation.maximumSourceZips -eq 1) 'O3C1 response invocation archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized) 'O3C1 response invocation authority changed.'
Assert-True ([string]$invocation.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$invocation.maximumEffectivePathLength -lt 200 -and [int]$invocation.maximumComponentLength -le 80) 'O3C1 response invocation path evidence changed.'
Assert-True (-not [bool]$invocation.imageBytesRead -and -not [bool]$invocation.sourceHashingPerformed -and -not [bool]$invocation.sourceDeletionPerformed) 'O3C1 response collection image/source boundary changed.'
Assert-True (-not [bool]$invocation.inspectionTasksChanged -and -not [bool]$invocation.healthyProcessorTouched -and -not [bool]$invocation.providerActivated) 'O3C1 response collection runtime boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3C1 response collection authority widened.'

foreach ($dependency in @($sourceZip, $certificate, $verifier)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O3C1 response dependency absent: $dependency"
}
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes) 'O3C1 response ZIP byte count changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq $expectedSha256) 'O3C1 response ZIP hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count) 'O3C1 response ZIP entry count changed.'
    Assert-True (@(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3C1 response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O3C1 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }

Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O3C1 response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3C1 response manifest terminal state changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o3c1_response_collection_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3C1_EXACT_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
    invocationManifestSha256 = $expectedInvocationSha256
    sourceZipSha256 = $expectedSha256
    sourceZipBytes = $expectedBytes
    endpointState = [string]$manifest.state
    signatureVerified = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 6
    return
}

foreach ($path in @($tempRoot, $archivePath, $extractionRoot, $collectionGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3C1 create-new collection target exists: $path"
}
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O3C1 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O3C1 signed response verification failed.'
    Assert-True ([string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3C1 signed response correlation or terminal state changed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3C1 JBOD signer changed.'

    $stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
    Assert-True ((Get-Item -LiteralPath $stdoutPath).Length -le 10485760) 'O3C1 stdout exceeded the bounded metadata limit.'
    $endpointResult = Get-Content -Raw -LiteralPath $stdoutPath | ConvertFrom-Json
    Assert-True ([string]$endpointResult.state -eq 'PASS_OCV03_METADATA_CAPABILITY_O3C1') 'O3C1 endpoint result state changed.'
    Assert-True ([bool]$endpointResult.installedProviderExecuted -and [bool]$endpointResult.pathsEnumerated) 'O3C1 installed metadata provider execution was not proven.'
    Assert-True (-not [bool]$endpointResult.filesRead -and -not [bool]$endpointResult.imageBytesRead -and -not [bool]$endpointResult.sourceHashingPerformed) 'O3C1 endpoint crossed its metadata-only boundary.'
    Assert-True (-not [bool]$endpointResult.sourceDeletionPerformed -and -not [bool]$endpointResult.inspectionTasksChanged -and -not [bool]$endpointResult.processorTaskChanged) 'O3C1 endpoint crossed its runtime boundary.'
    Assert-True ([bool]$endpointResult.reviewOnly -and -not [bool]$endpointResult.productionRoutingEnabled) 'O3C1 endpoint authority widened.'
    $inventory = $endpointResult.inventory
    Assert-True ($null -ne $inventory) 'O3C1 endpoint inventory is absent.'

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O3C1 archived response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3C1 final collected response verification failed.'

    $result = [ordered]@{
        schema = 'argos_o3c1_exact_response_collection_gate_v1'
        collectedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C1_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED'
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
        installedProviderExecuted = [bool]$endpointResult.installedProviderExecuted
        inventoryDisposition = [string]$endpointResult.inventoryDisposition
        directoryCount = [int]$inventory.directoryCount
        bmpLeafCount = [int]$inventory.bmpLeafCount
        otherLeafCount = [int]$inventory.otherLeafCount
        skippedPathRowCount = [int]$inventory.skippedPathRowCount
        accessErrorCount = [int]$inventory.accessErrorCount
        inventoryTruncated = [bool]$inventory.truncated
        capabilityOutputPath = [string]$endpointResult.capabilityOutputPath
        capabilityOutputSha256 = [string]$endpointResult.capabilityOutputSha256
        capabilityOutputBytes = [int64]$endpointResult.capabilityOutputBytes
        temporaryCDriveRootRemoved = $true
        requestRetryAuthorized = $false
        imageBytesRead = $false
        sourceHashingPerformed = $false
        sourceDeletionPerformed = $false
        inspectionTasksChanged = $false
        healthyProcessorTouched = $false
        providerActivated = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionRoutingEnabled = $false
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
        Assert-True ($resolvedTemp -eq 'C:\O3C1R_62629') 'O3C1 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
