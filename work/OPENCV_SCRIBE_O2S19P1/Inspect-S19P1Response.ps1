#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ResponseZip,
    [Parameter(Mandatory=$true)][string]$ExpectedRequestId,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Inspect-S19P1Response.ps1 is read-only and requires -Preflight.' }

function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') } finally { $sha.Dispose() }
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry -and $entry.Length -le $MaximumBytes) "S19P1 ZIP entry is absent or too large: $Name"
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try { $stream.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $stream.Dispose() }
}
function Get-OptionalValue([object]$Object,[string]$Name) {
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    return $null
}

$resolvedZip = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ResponseZip).Path)
Assert-True ([IO.Path]::GetDirectoryName($resolvedZip).Equals('U:\ProjectPortalRO\responses',[StringComparison]::OrdinalIgnoreCase)) 'S19P1 response is outside the qualified response root.'
$certificatePath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'))
Assert-True (Test-Path -LiteralPath $certificatePath -PathType Leaf) 'Pinned JBOD response certificate is absent.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedZip)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
    $expectedEntries = @('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json')
    Assert-True ($entryNames.Count -eq 4 -and @(Compare-Object -ReferenceObject $expectedEntries -DifferenceObject $entryNames).Count -eq 0) 'S19P1 response entry set changed.'
    $manifestBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096
    $resultBytes = Read-ZipEntryBytes $archive 'RESULT.json' 1048576
    $payloadBytes = Read-ZipEntryBytes $archive 'DATA_PULL_PAYLOAD.zip' 2097152
} finally { $archive.Dispose() }

$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
$result = [Text.Encoding]::UTF8.GetString($resultBytes) | ConvertFrom-Json
Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $ExpectedRequestId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_DATA_PULL') 'S19P1 response manifest identity or state changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'S19P1 response authority changed.'
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Assert-True ($signatureValid -and ([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $certificate.Thumbprint.ToUpperInvariant()) 'S19P1 response signature failed.'

$outerBytes = @{ 'DATA_PULL_PAYLOAD.zip' = $payloadBytes; 'RESULT.json' = $resultBytes }
Assert-True (@($manifest.files).Count -eq 2 -and @(Compare-Object -ReferenceObject @('DATA_PULL_PAYLOAD.zip','RESULT.json') -DifferenceObject @($manifest.files.path)).Count -eq 0) 'S19P1 signed file set changed.'
foreach ($record in @($manifest.files)) {
    $bytes = [byte[]]$outerBytes[[string]$record.path]
    Assert-True ($bytes.Length -eq [int64]$record.bytes -and (Get-BytesSha256 $bytes) -eq [string]$record.sha256) "S19P1 signed file record changed: $($record.path)"
}
Assert-True ([string]$result.schema -eq 'argos_project_portal_data_pull_result_v2' -and [string]$result.state -eq 'PASS_DATA_PULL' -and [string]$result.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [string]$result.containerSha256 -eq (Get-BytesSha256 $payloadBytes) -and @($result.files).Count -eq 1) 'S19P1 DATA_PULL result changed.'

$proposalEntry = 'data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot19/SCRIBE_PROPOSAL.json'
$memory = New-Object IO.MemoryStream(,([byte[]]$payloadBytes))
$inner = New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
try {
    $innerNames = @($inner.Entries | ForEach-Object { $_.FullName })
    Assert-True ($innerNames.Count -eq 1 -and $innerNames[0] -eq $proposalEntry) 'S19P1 nested payload entry set changed.'
    $proposalBytes = Read-ZipEntryBytes $inner $proposalEntry 1048576
} finally { $inner.Dispose(); $memory.Dispose() }
$proposalSha256 = Get-BytesSha256 $proposalBytes
$resultRow = @($result.files)[0]
Assert-True ([string]$resultRow.entryPath -eq $proposalEntry -and [string]$resultRow.sha256 -eq $proposalSha256 -and [int64]$resultRow.bytes -eq $proposalBytes.Length) 'S19P1 proposal result record changed.'
$proposal = [Text.Encoding]::UTF8.GetString($proposalBytes) | ConvertFrom-Json
Assert-True ([string]$proposal.schema -eq 'argos_jbod_scribe_proposal_v1' -and [string]$proposal.physicalIdentity -eq '62619-433_20260824005735_Slot19') 'S19P1 proposal identity changed.'

[ordered]@{
    schema = 'argos_s19p1_signed_response_inspection_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_S19P1_SIGNED_POST_FAILURE_PROPOSAL_OBSERVATION'
    requestId = [string]$manifest.requestId
    responseId = [string]$manifest.responseId
    endpointState = [string]$manifest.state
    responseZip = $resolvedZip
    responseZipBytes = [int64](Get-Item -LiteralPath $resolvedZip).Length
    responseZipSha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedZip).Hash
    responseManifestSha256 = Get-BytesSha256 $manifestBytes
    resultSha256 = Get-BytesSha256 $resultBytes
    payloadSha256 = Get-BytesSha256 $payloadBytes
    proposalSha256 = $proposalSha256
    proposalBytes = $proposalBytes.Length
    signerThumbprint = [string]$manifest.signerThumbprint
    signatureValid = $signatureValid
    physicalIdentity = [string]$proposal.physicalIdentity
    proposal = Get-OptionalValue $proposal 'proposal'
    proposalState = Get-OptionalValue $proposal 'state'
    readerState = Get-OptionalValue $proposal 'readerState'
    referenceCoverageComplete = Get-OptionalValue $proposal 'referenceCoverageComplete'
    bfOrientedReviewPath = Get-OptionalValue $proposal 'bfOrientedReviewPath'
    dfOrientedReviewPath = Get-OptionalValue $proposal 'dfOrientedReviewPath'
    proposalPropertyNames = @($proposal.PSObject.Properties.Name)
    proposalContent = $proposal
    directPostFailureObservation = $true
    imageBytesRead = $false
    pixelsDecoded = $false
    taskOrProcessRestarted = $false
    providerActivated = $false
    slots22Through25Exposed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    targetExecuted = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 24
