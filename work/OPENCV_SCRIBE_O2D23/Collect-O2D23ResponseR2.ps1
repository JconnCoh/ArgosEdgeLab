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
$requestId = 'REQ_20260827T035500111Z_3C97863DBF26'
$responseId = 'R_E15698774150_20260827044400129_f775f729'
$sourceZip = 'U:\ProjectPortalRO\responses\R_E15698774150_20260827044400129_f775f729.ready.zip'
$expectedBytes = 3697
$expectedSha256 = '044066FEF469C05DC4C1F8E907C929486D9FC3DFE75315C1A885485BED8C589A'
$expectedInvocationSha256 = '37E1A882DA5B41186BC9BEABB01D79EC29CC2C43ADE8FA7041C7B8D0C1A2E395'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\O2D23R2_3C97863D'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')
$collectionGatePath = Join-Path $PSScriptRoot 'O2D23_EXACT_RESPONSE_COLLECTION_R2_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 12) {
    $jsonBytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($jsonBytes, 0, $jsonBytes.Length) }
    finally { $stream.Dispose() }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O2D23 R2 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ((Get-Sha256 $invocationPath) -eq $expectedInvocationSha256) 'O2D23 R2 response invocation manifest changed.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_exact_response_collection_r2_invocation_v2') 'O2D23 R2 response invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O2D23 R2 response invocation identity changed.'
Assert-True ([string]$invocation.sourceZipSha256 -eq $expectedSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedBytes -and [int]$invocation.maximumSourceZips -eq 1) 'O2D23 R2 response invocation archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized) 'O2D23 R2 response invocation authority changed.'
Assert-True ([string]$invocation.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$invocation.pathCount -eq 18 -and [int]$invocation.maximumEffectivePathLength -lt 200 -and [int]$invocation.maximumComponentLength -le 80) 'O2D23 R2 response invocation path evidence changed.'
Assert-True ([bool]$invocation.slot25SourceMetadataPrematurelyExposed -and -not [bool]$invocation.slot25ImageBytesRead -and -not [bool]$invocation.slot25OutcomeSeen) 'O2D23 R2 Slot25 collection boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled -and -not [bool]$invocation.providerActivated -and -not [bool]$invocation.targetExecuted) 'O2D23 R2 response invocation widened authority.'

foreach ($dependency in @($sourceZip, $certificate, $verifier)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O2D23 R2 response dependency absent: $dependency"
}
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes) 'O2D23 R2 response ZIP byte count changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq $expectedSha256) 'O2D23 R2 response ZIP hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count) 'O2D23 R2 response ZIP entry count changed.'
    $nameDifference = @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names)
    Assert-True ($nameDifference.Count -eq 0) 'O2D23 R2 response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O2D23 R2 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }

Assert-True ([string]$manifest.requestId -eq $requestId) 'O2D23 R2 response request identity changed.'
Assert-True ([string]$manifest.responseId -eq $responseId) 'O2D23 R2 response identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O2D23 R2 response terminal state changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o2d23_response_collection_r2_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D23_EXACT_RESPONSE_COLLECTION_R2_PREFLIGHT'
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
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D23 R2 create-new collection target exists: $path"
}
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O2D23 R2 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O2D23 R2 signed response verification failed.'
    Assert-True ([string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O2D23 R2 signed response correlation or terminal state changed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D23 R2 JBOD signer changed.'

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O2D23 R2 archived response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O2D23 R2 final collected response verification failed.'

    $result = [ordered]@{
        schema = 'argos_o2d23_exact_response_collection_r2_gate_v1'
        collectedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D23_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED_R2'
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
        temporaryCDriveRootRemoved = $true
        requestRetryAuthorized = $false
        providerActivated = $false
        slot25SourceMetadataPrematurelyExposed = $true
        slot25ImageBytesRead = $false
        slot25OutcomeSeen = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-JsonCreateNew -Path $collectionGatePath -Value $result -Depth 8
    $collectionGateCreated = $true
    $result | ConvertTo-Json -Depth 8
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
        Assert-True ($resolvedTemp -eq 'C:\O2D23R2_3C97863D') 'O2D23 R2 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
