#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ResponseZip,
    [Parameter(Mandatory = $true)][string]$ExpectedRequestId,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Candidate response inspection is preflight-only.' }
if (-not (Test-Path -LiteralPath $ResponseZip -PathType Leaf)) { throw 'Candidate response ZIP is absent.' }
if ((Get-Item -LiteralPath $ResponseZip).Length -gt 16777216) { throw 'Candidate response ZIP exceeds 16 MiB.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$certificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
if (-not (Test-Path -LiteralPath $certificatePath -PathType Leaf)) { throw 'Pinned JBOD signer certificate is absent.' }
$archive = [IO.Compression.ZipFile]::OpenRead((Get-Item -LiteralPath $ResponseZip).FullName)
try {
    $entries = @($archive.Entries | ForEach-Object { [string]$_.FullName })
    $manifestEntry = @($archive.Entries | Where-Object { $_.FullName -eq 'PORTAL_RESPONSE_MANIFEST.json' })
    if ($manifestEntry.Count -ne 1) { throw 'Candidate response has no unique manifest.' }
    $manifestStream = $manifestEntry[0].Open()
    $manifestMemory = New-Object IO.MemoryStream
    try { $manifestStream.CopyTo($manifestMemory); $manifestBytes = [byte[]]$manifestMemory.ToArray() } finally { $manifestMemory.Dispose(); $manifestStream.Dispose() }
    $signatureEntry = @($archive.Entries | Where-Object { $_.FullName -eq 'PORTAL_RESPONSE_MANIFEST.sig' })
    if ($signatureEntry.Count -ne 1) { throw 'Candidate response has no unique signature.' }
    $signatureStream = $signatureEntry[0].Open()
    $signatureMemory = New-Object IO.MemoryStream
    try { $signatureStream.CopyTo($signatureMemory); $signatureBytes = [byte[]]$signatureMemory.ToArray() } finally { $signatureMemory.Dispose(); $signatureStream.Dispose() }
    $failureEntry = @($archive.Entries | Where-Object { $_.FullName -eq 'FAILURE.json' })
    $failureBytes = [byte[]]::new(0)
    if ($failureEntry.Count -eq 1) {
        $failureStream = $failureEntry[0].Open()
        $failureMemory = New-Object IO.MemoryStream
        try { $failureStream.CopyTo($failureMemory); $failureBytes = [byte[]]$failureMemory.ToArray() } finally { $failureMemory.Dispose(); $failureStream.Dispose() }
    }
} finally { $archive.Dispose() }

$manifestText = [Text.Encoding]::UTF8.GetString($manifestBytes)
$manifest = $manifestText | ConvertFrom-Json
$failure = if ($failureBytes.Length -gt 0) { ([Text.Encoding]::UTF8.GetString($failureBytes) | ConvertFrom-Json) } else { $null }
$sha = [Security.Cryptography.SHA256]::Create()
try {
    $manifestSha256 = ([BitConverter]::ToString($sha.ComputeHash([byte[]]$manifestBytes))).Replace('-', '')
    $failureSha256 = if ($failureBytes.Length -gt 0) { ([BitConverter]::ToString($sha.ComputeHash([byte[]]$failureBytes))).Replace('-', '') } else { '' }
} finally { $sha.Dispose() }
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
$failureRecord = @($manifest.files | Where-Object { [string]$_.path -eq 'FAILURE.json' })
$failureRecordVerified = $failureBytes.Length -gt 0 -and $failureRecord.Count -eq 1 -and [int64]$failureRecord[0].bytes -eq $failureBytes.Length -and [string]$failureRecord[0].sha256 -eq $failureSha256
[ordered]@{
    schema = 'argos_s19b1_candidate_manifest_inspection_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = if ([string]$manifest.requestId -eq $ExpectedRequestId) { 'PASS_S19B1_MATCHING_RESPONSE_MANIFEST' } else { 'HOLD_S19B1_NONMATCHING_RESPONSE_MANIFEST' }
    expectedRequestId = $ExpectedRequestId
    observedRequestId = [string]$manifest.requestId
    responseId = [string]$manifest.responseId
    endpointState = [string]$manifest.state
    signerThumbprint = [string]$manifest.signerThumbprint
    pinnedCertificateThumbprint = [string]$certificate.Thumbprint
    signatureValid = $signatureValid
    manifestFailureRecordVerified = $failureRecordVerified
    responseManifestSha256 = $manifestSha256
    failureSha256 = $failureSha256
    failureState = if ($null -ne $failure) { [string]$failure.state } else { '' }
    failureDetail = if ($null -ne $failure) { [string]$failure.detail } else { '' }
    reviewOnly = [bool]$manifest.reviewOnly
    trainingEligible = [bool]$manifest.trainingEligible
    xmlEligible = [bool]$manifest.xmlEligible
    productionEligible = [bool]$manifest.productionEligible
    productionRoutingEnabled = [bool]$manifest.productionRoutingEnabled
    zipBytes = [int64](Get-Item -LiteralPath $ResponseZip).Length
    zipSha256 = (Get-FileHash -LiteralPath $ResponseZip -Algorithm SHA256).Hash
    entryCount = $entries.Count
    entries = $entries
    targetExecuted = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 8
