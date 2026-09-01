#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')][switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\R21P2'
$payloadRoot = Join-Path $root 'payload'
$entrySource = Join-Path $PSScriptRoot 'R21P1_E.ps1'
$responseZip = 'U:\ProjectPortalRO\responses\R_39807C114944_20260831180751098_3671cbc0.ready.zip'
$endpointCertificate = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$gatePath = Join-Path $PSScriptRoot 'R21P2_BUILD_GATE.json'
$expectedResponseZipSha = '4893A57B235327808F9B4AE2B61D357759459889E357DF69E1E077911CE0F6D5'
$expectedRequestId = 'REQ_20260831T175803632Z_81BAFDA47A65'
$expectedContainerSha = '24590A5B6C4E6F172B39A8B65241BAA59EA9391AA49540A67B1DF6DBF00BE57D'
$expectedConfigSha = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$expectedEntrySha = '98EDCD1B37CA01119B80E2662390C1E2115CF1A93840FABC2D142D698919A582'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Get-ZipEntryBytes([IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $rows = @($Archive.Entries | Where-Object { [string]$_.FullName -eq $Name })
    if ($rows.Count -ne 1) { throw "ZIP entry is missing or ambiguous: $Name" }
    $stream = $rows[0].Open()
    try {
        $memory = New-Object IO.MemoryStream
        try { $stream.CopyTo($memory); return $memory.ToArray() }
        finally { $memory.Dispose() }
    } finally { $stream.Dispose() }
}
function Write-NewUtf8Json([string]$Path, [object]$Value, [int]$Depth = 12) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
foreach ($path in @($entrySource, $responseZip, $endpointCertificate)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "R21P2 dependency is absent: $path" }
}
if ((Get-Sha256 $entrySource) -ne $expectedEntrySha) { throw 'R21P2 entrypoint hash changed.' }
if ((Get-Sha256 $responseZip) -ne $expectedResponseZipSha) { throw 'GUIHV1 signed response ZIP hash changed.' }
$archive = [IO.Compression.ZipFile]::OpenRead($responseZip)
try {
    $manifestBytes = Get-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json'
    $signatureBytes = Get-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig'
    $containerBytes = Get-ZipEntryBytes $archive 'DATA_PULL_PAYLOAD.zip'
} finally { $archive.Dispose() }
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($endpointCertificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
if (-not $signatureValid) { throw 'GUIHV1 response signature is invalid.' }
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
if ([string]$manifest.requestId -ne $expectedRequestId -or [string]$manifest.sourceRole -ne 'JBOD' -or [string]$manifest.state -ne 'PASS_DATA_PULL') {
    throw 'GUIHV1 signed response identity or state changed.'
}
$containerRows = @($manifest.files | Where-Object { [string]$_.path -eq 'DATA_PULL_PAYLOAD.zip' })
if ($containerRows.Count -ne 1 -or [string]$containerRows[0].sha256 -ne $expectedContainerSha -or (Get-BytesSha256 $containerBytes) -ne $expectedContainerSha) {
    throw 'GUIHV1 signed nested payload changed.'
}
$containerStream = New-Object IO.MemoryStream(,$containerBytes)
$containerArchive = New-Object IO.Compression.ZipArchive($containerStream, [IO.Compression.ZipArchiveMode]::Read, $false)
try { $configBytes = Get-ZipEntryBytes $containerArchive 'data/JBOD_PROCESSOR_REVIEW/PROCESSOR_CONFIG.json' }
finally { $containerArchive.Dispose(); $containerStream.Dispose() }
if ($configBytes.Length -ne 1964 -or (Get-BytesSha256 $configBytes) -ne $expectedConfigSha) { throw 'GUIHV1 PROCESSOR_CONFIG bytes changed.' }
if (Test-Path -LiteralPath $root) { throw 'R21P2 short build root already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21P2 build gate already exists.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r21p2_build_preflight_v1'
        state = 'PASS_R21P2_BUILD_PREFLIGHT'
        signedSourceRequestId = $expectedRequestId
        responseSignatureVerified = $true
        configBytes = $configBytes.Length
        configSha256 = $expectedConfigSha
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $payloadRoot -Force)
[IO.File]::WriteAllBytes((Join-Path $payloadRoot 'C.json'), $configBytes)
[IO.File]::Copy($entrySource, (Join-Path $payloadRoot 'E.ps1'), $false)
$definition = [ordered]@{
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    maxResultBytes = 1048576
    entryPoint = 'payload/E.ps1'
    changes = @([ordered]@{
        source = 'payload/C.json'
        destination = 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json'
        approvedPredecessorSha256 = @($expectedConfigSha)
        installedSha256 = $expectedConfigSha
        allowCreate = $false
    })
    allowedTaskActions = @()
    rehearsal = [ordered]@{requiredState = 'PASS_R21P1_CURRENT_PREMISE_OBSERVED'}
}
Write-NewUtf8Json -Path (Join-Path $root 'DEFINITION.json') -Value $definition -Depth 12
$gate = [ordered]@{
    schema = 'argos_r21p2_build_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21P2_UNSIGNED_PAYLOAD_BUILT'
    root = $root
    signedSourceRequestId = $expectedRequestId
    responseSignatureVerified = $true
    entrySha256 = Get-Sha256 (Join-Path $payloadRoot 'E.ps1')
    configBytes = (Get-Item -LiteralPath (Join-Path $payloadRoot 'C.json')).Length
    configSha256 = Get-Sha256 (Join-Path $payloadRoot 'C.json')
    definitionSha256 = Get-Sha256 (Join-Path $root 'DEFINITION.json')
    identicalConfigSelfSwap = $true
    approvedMaintenanceDestination = $true
    installedSemanticChange = $false
    taskOrProcessActionCount = 0
    detectorRerun = $false
    signed = $false
    published = $false
    mutationsPerformed = $false
}
Write-NewUtf8Json -Path $gatePath -Value $gate -Depth 8
$gate | ConvertTo-Json -Depth 8
