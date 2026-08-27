#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T023200111Z_8A9CFF90BF26'
$responseId = 'R_0625466C6A6C_20260827024747655_661acb16'
$sourceZip = 'U:\ProjectPortalRO\responses\R_0625466C6A6C_20260827024747655_661acb16.ready.zip'
$expectedBytes = 3686
$expectedSha256 = '8A249AD8ACDFCFBA75F2815FF1EFCC1B0A9762C447BB9DC7A777F39629FCF491'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\O2D21R_8A9CFF90'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

foreach ($dependency in @($sourceZip, $certificate, $verifier)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O2D21 response dependency absent: $dependency"
}
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes) 'O2D21 response ZIP byte count changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq $expectedSha256) 'O2D21 response ZIP hash changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count) 'O2D21 response ZIP entry count changed.'
    $nameDifference = @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names)
    Assert-True ($nameDifference.Count -eq 0) 'O2D21 response ZIP entry names changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O2D21 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(), [Text.Encoding]::UTF8, $true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }

Assert-True ([string]$manifest.requestId -eq $requestId) 'O2D21 response request identity changed.'
Assert-True ([string]$manifest.responseId -eq $responseId) 'O2D21 response identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O2D21 response terminal state changed.'

$preflightResult = [ordered]@{
    schema = 'argos_o2d21_response_collection_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D21_EXACT_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
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

foreach ($path in @($tempRoot, $archivePath, $extractionRoot)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D21 create-new collection target exists: $path"
}
$archiveCreated = $false
$extractionMoved = $false
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip, $tempZip, $false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O2D21 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE') 'O2D21 signed response verification failed.'
    Assert-True ([string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O2D21 signed response correlation or terminal state changed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D21 JBOD signer changed.'

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip, $archivePath, $false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O2D21 archived response changed.'
    [IO.Directory]::Move($tempExtract, $extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O2D21 final collected response verification failed.'

    [ordered]@{
        schema = 'argos_o2d21_exact_response_collection_gate_v1'
        collectedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D21_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED'
        requestId = $requestId
        responseId = $responseId
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
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
}
catch {
    if ($extractionMoved -and (Test-Path -LiteralPath $extractionRoot -PathType Container)) { [IO.Directory]::Delete($extractionRoot, $true) }
    if ($archiveCreated -and (Test-Path -LiteralPath $archivePath -PathType Leaf)) { [IO.File]::Delete($archivePath) }
    throw
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        Assert-True ($resolvedTemp -eq 'C:\O2D21R_8A9CFF90') 'O2D21 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp, $true)
    }
}
