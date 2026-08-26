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
    Assert-True ($null -ne $entry -and $entry.Length -le $MaximumBytes) "O2D15 ZIP entry is absent or too large: $Name"
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
    try { return ([BitConverter]::ToString($sha.ComputeHash([byte[]]$Bytes))).Replace('-', '') }
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
Assert-True ($invocationPath.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D15 invocation escaped the project.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json

$requestId = 'REQ_20260826T225708001Z_9A8661E9BF26'
$responseId = 'R_9641D12F7275_20260826231910853_331d63ea'
$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = 'U:\ProjectPortalRO\responses'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
Assert-True ([string]$invocation.schema -eq 'argos_o2d15_failure_response_collection_invocation_v1') 'O2D15 invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O2D15 response identity changed.'
Assert-True ([bool]$invocation.singleCollectionAuthorized -and -not [bool]$invocation.requestRetryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D15 collection authority changed.'
$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True (([string]$psDrive.DisplayRoot).TrimEnd('\').Equals($shareRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O2D15 U: mapping changed.'
Assert-True ([IO.Path]::GetDirectoryName($sourceZip).Equals($approvedResponseRoot, [StringComparison]::OrdinalIgnoreCase)) 'O2D15 response source root changed.'
Assert-True ([IO.Path]::GetFileName($sourceZip) -eq ($responseId + '.ready.zip')) 'O2D15 response source leaf changed.'
Assert-True ((Test-Path -LiteralPath $sourceZip -PathType Leaf) -and (Get-Item -LiteralPath $sourceZip).Length -eq 1617) 'O2D15 response ZIP size changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq 'C7DE7023A7921A14ADDDAC80A781144754C3A103B245F90DA1E62CD1E207F08F') 'O2D15 response ZIP hash changed.'

$outputRoot = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.outputRoot).Replace('/', '\'))).TrimEnd('\')
$terminalGate = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.terminalGate).Replace('/', '\')))
Assert-True ($outputRoot.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D15 output root escaped the project.'
Assert-True ($terminalGate.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D15 terminal gate escaped the project.'
Assert-True (-not (Test-Path -LiteralPath $outputRoot) -and -not (Test-Path -LiteralPath $terminalGate)) 'O2D15 collection output is not fresh.'

$localZip = Join-Path $outputRoot 'response.zip'
$partialRoot = Join-Path $outputRoot 'partial'
$readyRoot = Join-Path $outputRoot 'ready'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($required in @($verifier, $certificate, $pathTool)) {
    Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2D15 verification dependency is absent: $required"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $expectedEntries = @('FAILURE.json', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig')
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
    Assert-True ($entryNames.Count -eq 3 -and @(Compare-Object $expectedEntries $entryNames).Count -eq 0) 'O2D15 response ZIP entry set changed.'
    $manifestBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096
    $failureBytes = Read-ZipEntryBytes $archive 'FAILURE.json' 1048576
}
finally { $archive.Dispose() }

Assert-True ((Get-BytesSha256 $manifestBytes) -eq '6EF5190F009FA6DEC6610CBC7BFD002B0AB7EB07D917FA35B9A4E4374D91DDA3') 'O2D15 response manifest hash changed.'
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
$failure = [Text.Encoding]::UTF8.GetString($failureBytes) | ConvertFrom-Json
Assert-True ((Get-BytesSha256 $failureBytes) -eq '196C9B1682E2E11987A117DB76BE9EF51071778C6F3F7B0E30F0CDACC3EB504B') 'O2D15 failure leaf hash changed.'
Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O2D15 signed response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'FAILED' -and [string]$manifest.signerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D15 response source, state, or signer changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'O2D15 response authority changed.'
Assert-True (@($manifest.files).Count -eq 1) 'O2D15 response manifest file count changed.'
foreach ($record in @($manifest.files)) {
    Assert-True ([string]$record.path -eq 'FAILURE.json') "O2D15 response manifest has an unexpected file: $($record.path)"
    $bytes = $failureBytes
    Assert-True (@($bytes).Count -eq [int64]$record.bytes -and (Get-BytesSha256 ([byte[]]$bytes)) -eq [string]$record.sha256) "O2D15 response file hash changed: $($record.path)"
}

$cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
Assert-True $signatureValid 'O2D15 response signature is invalid.'
Assert-True ($cert.Thumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D15 pinned certificate changed.'
Assert-True ([string]$failure.state -eq 'FAILED' -and [string]$failure.detail -eq 'Maintenance source hash mismatch: payload/Invoke-O2D15ScribeEndpoint.ps1') 'O2D15 failure state changed.'

$plannedPaths = @($localZip, (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json'), (Join-Path $readyRoot 'FAILURE.json'), $terminalGate)
$pathGate = & $pathTool -CandidatePath $plannedPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D15 collection path gate failed: $($pathGate.state)"

$preflightResult = [ordered]@{
    schema = 'argos_o2d15_failure_response_collection_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D15_FAILURE_RESPONSE_COLLECTION_PREFLIGHT'
    requestId = $requestId
    responseId = $responseId
    endpointState = [string]$manifest.state
    sourceZipBytes = 1617
    sourceZipSha256 = 'C7DE7023A7921A14ADDDAC80A781144754C3A103B245F90DA1E62CD1E207F08F'
    responseManifestSha256 = '6EF5190F009FA6DEC6610CBC7BFD002B0AB7EB07D917FA35B9A4E4374D91DDA3'
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
Assert-True ((Get-Item -LiteralPath $localZip).Length -eq 1617 -and (Get-Sha256 $localZip) -eq 'C7DE7023A7921A14ADDDAC80A781144754C3A103B245F90DA1E62CD1E207F08F') 'O2D15 response changed during local copy.'
[void][IO.Directory]::CreateDirectory($partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
$verified = & $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$verified.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verified.EndpointState -eq 'FAILED') 'O2D15 extracted signed response verification failed.'
[IO.Directory]::Move($partialRoot, $readyRoot)

$terminal = [ordered]@{
    schema = 'argos_o2d15_terminal_failure_response_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D15_SIGNED_TERMINAL_FAILURE_COLLECTED'
    disposition = 'HOLD_SLOT19_O2D15_SOURCE_HASH_DECLARATION_MISMATCH_STOP_LOSS_ACTIVE'
    requestId = $requestId
    responseId = $responseId
    endpointState = 'FAILED'
    signedResponseVerified = $true
    signerThumbprint = [string]$manifest.signerThumbprint
    sourceZipBytes = 1617
    sourceZipSha256 = 'C7DE7023A7921A14ADDDAC80A781144754C3A103B245F90DA1E62CD1E207F08F'
    responseManifestSha256 = '6EF5190F009FA6DEC6610CBC7BFD002B0AB7EB07D917FA35B9A4E4374D91DDA3'
    failureDetail = [string]$failure.detail
    failureSha256 = '196C9B1682E2E11987A117DB76BE9EF51071778C6F3F7B0E30F0CDACC3EB504B'
    failureSignature = 'Maintenance source hash mismatch: payload/Invoke-O2D15ScribeEndpoint.ps1'
    collectedRoot = $readyRoot
    localResponseZip = $localZip
    slot16DevelopmentFrozen = $true
    slot17DevelopmentFrozen = $true
    slot18DevelopmentFrozen = $true
    slot19DevelopmentFrozen = $false
    slots22Through25Exposed = $false
    entryPointExecuted = $false
    sourceImageBytesRead = $false
    mutationStopLossActive = $true
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
