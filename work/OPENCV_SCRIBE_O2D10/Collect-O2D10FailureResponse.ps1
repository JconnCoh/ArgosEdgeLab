#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Archive, [string]$Name, [int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry -and $entry.Length -le $MaximumBytes) "O2D10 ZIP entry is absent or too large: $Name"
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        return ,([byte[]]$memory.ToArray())
    }
    finally {
        $memory.Dispose()
        $stream.Dispose()
    }
}
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D10 invocation escaped the project.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json

$requestId = 'REQ_20260826T015418549Z_F5D3732576F9'
$responseId = 'R_AAB6C504C28E_20260826190116689_9f0ba1d4'
$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ProjectPortalRO\responses'
Assert-True ([string]$invocation.schema -eq 'argos_o2d10_failure_response_collection_invocation_v1') 'O2D10 invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O2D10 response identity changed.'
Assert-True ([bool]$invocation.singleCollectionAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D10 collection authority changed.'
Assert-True ([IO.Path]::GetDirectoryName($sourceZip).Equals($approvedResponseRoot, [StringComparison]::OrdinalIgnoreCase)) 'O2D10 response source root changed.'
Assert-True ([IO.Path]::GetFileName($sourceZip) -eq ($responseId + '.ready.zip')) 'O2D10 response source leaf changed.'
Assert-True ((Test-Path -LiteralPath $sourceZip -PathType Leaf) -and (Get-Item -LiteralPath $sourceZip).Length -eq 2290) 'O2D10 response ZIP size changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq 'B7F63459F186561D67B3C175B683805B62F02104E01385AB53BD25275061EB54') 'O2D10 response ZIP hash changed.'

$outputRoot = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.outputRoot).Replace('/', '\'))).TrimEnd('\')
$terminalGate = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.terminalGate).Replace('/', '\')))
Assert-True ($outputRoot.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D10 output root escaped the project.'
Assert-True ($terminalGate.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D10 terminal gate escaped the project.'
Assert-True (-not (Test-Path -LiteralPath $outputRoot) -and -not (Test-Path -LiteralPath $terminalGate)) 'O2D10 collection output is not fresh.'

$localZip = Join-Path $outputRoot 'response.zip'
$partialRoot = Join-Path $outputRoot 'partial'
$readyRoot = Join-Path $outputRoot 'ready'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($required in @($verifier, $certificate, $pathTool)) {
    Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2D10 verification dependency is absent: $required"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $expectedEntries = @('FAILURE.json', 'MAINTENANCE.stderr.txt', 'MAINTENANCE.stdout.txt', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig')
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
    Assert-True ($entryNames.Count -eq 5 -and @(Compare-Object $expectedEntries $entryNames).Count -eq 0) 'O2D10 response ZIP entry set changed.'
    $manifestBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096
    $failureBytes = Read-ZipEntryBytes $archive 'FAILURE.json' 1048576
    $stderrBytes = Read-ZipEntryBytes $archive 'MAINTENANCE.stderr.txt' 1048576
    $stdoutBytes = Read-ZipEntryBytes $archive 'MAINTENANCE.stdout.txt' 1048576
}
finally { $archive.Dispose() }

Assert-True ((Get-BytesSha256 $manifestBytes) -eq '0299752CB7A142CDA45860AA551C1D23644B481EF0A2BFCB8C8198478EF62762') 'O2D10 response manifest hash changed.'
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
$failure = [Text.Encoding]::UTF8.GetString($failureBytes) | ConvertFrom-Json
$stderr = [Text.Encoding]::UTF8.GetString($stderrBytes)
Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O2D10 signed response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'FAILED' -and [string]$manifest.signerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D10 response source, state, or signer changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'O2D10 response authority changed.'
Assert-True (@($manifest.files).Count -eq 3) 'O2D10 response manifest file count changed.'
foreach ($record in @($manifest.files)) {
    if ([string]$record.path -eq 'MAINTENANCE.stdout.txt') {
        Assert-True ([int64]$record.bytes -eq 0 -and [string]$record.sha256 -eq 'E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855') 'O2D10 empty stdout record changed.'
        continue
    }
    $bytes = if ([string]$record.path -eq 'FAILURE.json') {
        $failureBytes
    }
    elseif ([string]$record.path -eq 'MAINTENANCE.stderr.txt') {
        $stderrBytes
    }
    else {
        throw "O2D10 response manifest has an unexpected file: $($record.path)"
    }
    Assert-True (@($bytes).Count -eq [int64]$record.bytes -and (Get-BytesSha256 ([byte[]]$bytes)) -eq [string]$record.sha256) "O2D10 response file hash changed: $($record.path)"
}

$cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
Assert-True $signatureValid 'O2D10 response signature is invalid.'
Assert-True ($cert.Thumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D10 pinned certificate changed.'
Assert-True ([string]$failure.state -eq 'FAILED' -and [string]$failure.detail -eq 'Maintenance verifier failed with exit code 1. Exact stderr is attached.') 'O2D10 failure state changed.'
Assert-True ($stderr -match "Cannot bind argument to parameter 'Path' because it is an empty string") 'O2D10 exact maintenance failure changed.'
Assert-True (@($stdoutBytes).Count -eq 0) 'O2D10 maintenance stdout is no longer empty.'

$plannedPaths = @($localZip, (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json'), (Join-Path $readyRoot 'MAINTENANCE.stderr.txt'), $terminalGate)
$pathGate = & $pathTool -CandidatePath $plannedPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D10 collection path gate failed: $($pathGate.state)"

$preflightResult = [ordered]@{
    schema = 'argos_o2d10_failure_response_collection_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D10_FAILURE_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
    endpointState = [string]$manifest.state
    sourceZipBytes = 2290
    sourceZipSha256 = 'B7F63459F186561D67B3C175B683805B62F02104E01385AB53BD25275061EB54'
    responseManifestSha256 = '0299752CB7A142CDA45860AA551C1D23644B481EF0A2BFCB8C8198478EF62762'
    signedResponseVerified = $signatureValid
    pathState = [string]$pathGate.state
    targetExecuted = $false
    mutationsPerformed = $false
    jbodContacted = $false
    requestRetried = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 8
    return
}

[void][IO.Directory]::CreateDirectory($outputRoot)
[IO.File]::Copy($sourceZip, $localZip, $false)
Assert-True ((Get-Item -LiteralPath $localZip).Length -eq 2290 -and (Get-Sha256 $localZip) -eq 'B7F63459F186561D67B3C175B683805B62F02104E01385AB53BD25275061EB54') 'O2D10 response changed during local copy.'
[void][IO.Directory]::CreateDirectory($partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
$verified = & $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$verified.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verified.EndpointState -eq 'FAILED') 'O2D10 extracted signed response verification failed.'
[IO.Directory]::Move($partialRoot, $readyRoot)

$terminal = [ordered]@{
    schema = 'argos_o2d10_terminal_failure_response_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D10_SIGNED_TERMINAL_FAILURE_COLLECTED'
    disposition = 'HOLD_SLOT16_O2D10_ENDPOINT_INVOCATION_FAILED'
    requestId = $requestId
    responseId = $responseId
    endpointState = 'FAILED'
    signedResponseVerified = $true
    signerThumbprint = [string]$manifest.signerThumbprint
    sourceZipBytes = 2290
    sourceZipSha256 = 'B7F63459F186561D67B3C175B683805B62F02104E01385AB53BD25275061EB54'
    responseManifestSha256 = '0299752CB7A142CDA45860AA551C1D23644B481EF0A2BFCB8C8198478EF62762'
    failureDetail = [string]$failure.detail
    stderrSha256 = '3E9F731AA991617BCBC35B2E906D1C51BB4541FE5C92D362D10C90B5E83B7F90'
    failureSignature = "Cannot bind argument to parameter 'Path' because it is an empty string."
    collectedRoot = $readyRoot
    localResponseZip = $localZip
    slot16DevelopmentFrozen = $false
    slot17Authorized = $false
    slots22Through25Exposed = $false
    requestRetried = $false
    providerActivated = $false
    healthyProcessorTouched = $false
    holdsCleared = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path $terminalGate -Value $terminal
$terminal | ConvertTo-Json -Depth 12
