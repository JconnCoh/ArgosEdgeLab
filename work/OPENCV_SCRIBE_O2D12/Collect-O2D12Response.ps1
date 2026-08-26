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

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-BytesSha256([byte[]]$Bytes) {
    if ($null -eq $Bytes) { $Bytes = [byte[]]::new(0) }
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([byte[]]$Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Archive, [string]$Name, [int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry -and $entry.Length -le $MaximumBytes) "O2D12 ZIP entry is absent or too large: $Name"
    $stream = $entry.Open(); $memory = New-Object IO.MemoryStream
    try { $stream.CopyTo($memory); return ,([byte[]]$memory.ToArray()) }
    finally { $memory.Dispose(); $stream.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 14) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}
function Normalize-Root([string]$Path) { return $Path.Replace('/', '\').TrimEnd('\') }

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D12 invocation escaped the project.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
$revision = 'O2D12_20260826T202600000Z_6B91F2C4'
$requestId = 'REQ_O2D12_20260826'
$responseId = 'R_BE5255B84095_20260826204317306_d9536434'
$expectedZipBytes = 3249
$expectedZipSha256 = 'CEE8F5EB3ABE6CB7D507B14C3C8DF6400E953B7B5445E5730992F5B8FCAFF14B'
$expectedManifestSha256 = 'D8648FA64644E359F3BECC8CA881445C9DD3584BF5331DD85E32058646EA6B0D'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'

Assert-True ([string]$invocation.schema -eq 'argos_o2d12_response_collection_invocation_v1') 'O2D12 invocation schema changed.'
Assert-True ([string]$invocation.revision -eq $revision -and [string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O2D12 collection identity changed.'
Assert-True ([int64]$invocation.expectedZipBytes -eq $expectedZipBytes -and [string]$invocation.expectedZipSha256 -eq $expectedZipSha256 -and [string]$invocation.expectedResponseManifestSha256 -eq $expectedManifestSha256) 'O2D12 response pins changed.'
Assert-True ([bool]$invocation.singleCollectionAuthorized -and -not [bool]$invocation.requestRetryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D12 collection authority changed.'

$psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'O2D12 U: mapping changed.'
$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
Assert-True ([IO.Path]::GetDirectoryName($sourceZip).Equals('U:\ProjectPortalRO\responses', [StringComparison]::OrdinalIgnoreCase)) 'O2D12 response source root changed.'
Assert-True ([IO.Path]::GetFileName($sourceZip) -eq ($responseId + '.ready.zip')) 'O2D12 response source leaf changed.'
Assert-True ((Test-Path -LiteralPath $sourceZip -PathType Leaf) -and (Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes -and (Get-Sha256 $sourceZip) -eq $expectedZipSha256) 'O2D12 response ZIP changed.'

$outputRoot = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.outputRoot).Replace('/', '\'))).TrimEnd('\')
$terminalGate = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.terminalGate).Replace('/', '\')))
Assert-True ($outputRoot.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase) -and $terminalGate.StartsWith($project + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D12 collection target escaped the project.'
$localZip = Join-Path $outputRoot 'response.zip'
$partialRoot = Join-Path $outputRoot 'partial'
$readyRoot = Join-Path $outputRoot 'ready'
foreach ($fresh in @($outputRoot, $terminalGate)) { Assert-True (-not (Test-Path -LiteralPath $fresh)) "O2D12 collection target is not fresh: $fresh" }

$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($required in @($verifier, $certificate, $pathTool)) { Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2D12 verification dependency is absent: $required" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $expectedEntries = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json')
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
    Assert-True ($entryNames.Count -eq 5 -and @(Compare-Object $expectedEntries $entryNames).Count -eq 0) 'O2D12 response entry set changed.'
    $manifestBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096
    $resultBytes = Read-ZipEntryBytes $archive 'RESULT.json' 1048576
    $stdoutBytes = Read-ZipEntryBytes $archive 'MAINTENANCE.stdout.txt' 1048576
    $stderrBytes = Read-ZipEntryBytes $archive 'MAINTENANCE.stderr.txt' 1048576
}
finally { $archive.Dispose() }

Assert-True ((Get-BytesSha256 $manifestBytes) -eq $expectedManifestSha256) 'O2D12 manifest hash changed.'
Assert-True ((Get-BytesSha256 $resultBytes) -eq '94842DFCF3A2CBAE00F7B80B4E097D99142E9B747EEB42A1B373D0E05D2E5945') 'O2D12 maintenance result hash changed.'
Assert-True ((Get-BytesSha256 $stdoutBytes) -eq '5C83BF8825A843555A29E6762CF401A55D7DCEEE62CE701F349A62D59FFE683B' -and @($stderrBytes).Count -eq 0) 'O2D12 maintenance output changed.'
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
$maintenance = [Text.Encoding]::UTF8.GetString($resultBytes) | ConvertFrom-Json
$runGate = [Text.Encoding]::UTF8.GetString($stdoutBytes) | ConvertFrom-Json

Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId) 'O2D12 signed manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH' -and [string]$manifest.signerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D12 signed source/state/signer changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'O2D12 signed authority widened.'
Assert-True (@($manifest.files).Count -eq 3) 'O2D12 manifest file count changed.'
foreach ($record in @($manifest.files)) {
    $bytes = if ([string]$record.path -eq 'RESULT.json') { $resultBytes } elseif ([string]$record.path -eq 'MAINTENANCE.stdout.txt') { $stdoutBytes } elseif ([string]$record.path -eq 'MAINTENANCE.stderr.txt') { $stderrBytes } else { throw "O2D12 unexpected manifest file: $($record.path)" }
    Assert-True (@($bytes).Count -eq [int64]$record.bytes -and (Get-BytesSha256 ([byte[]]$bytes)) -eq [string]$record.sha256) "O2D12 response file changed: $($record.path)"
}
$cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Assert-True ($signatureValid -and $cert.Thumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D12 response signature failed.'

Assert-True ([string]$maintenance.schema -eq 'argos_project_portal_maintenance_result_v1' -and [string]$maintenance.state -eq 'PASS_MAINTENANCE_PATCH' -and [int]$maintenance.changedFiles -eq 1 -and [string]$maintenance.entryPoint -eq 'payload/Invoke-O2D12ScribeEndpoint.ps1' -and [int]$maintenance.exitCode -eq 0) 'O2D12 maintenance result changed.'
Assert-True ([bool]$maintenance.reviewOnly -and -not [bool]$maintenance.productionRoutingEnabled) 'O2D12 maintenance authority widened.'
Assert-True ([string]$runGate.schema -eq 'argos_o2d12_opencv_scribe_development_gate_v1' -and [string]$runGate.state -eq 'PASS_O2D12_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED' -and [string]$runGate.revision -eq $revision -and -not [bool]$runGate.rehearsal) 'O2D12 run identity changed.'
Assert-True ([string]$runGate.engineSha256 -eq '8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB' -and [string]$runGate.jobSha256 -eq 'EA50016888080BCF4906D47A1C30239AE09114FA90B2ABAEF095351E8526C2B6' -and [string]$runGate.referenceBundleSha256 -eq '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6') 'O2D12 dependency binding changed.'
Assert-True ([string]$runGate.resultSha256 -eq '7575C082A50F8E11027F8E533790A3194D21F30F59A0A92021892A3AC19AC8E5' -and [string]$runGate.resultState -eq 'SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID') 'O2D12 result state changed.'
Assert-True ([string]$runGate.imageFirstString -eq '1443R072SUC4' -and [string]$runGate.proposedString -eq '1443R072SUC4' -and [string]$runGate.checksumState -eq 'SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY') 'O2D12 result proposal changed.'
Assert-True (@($runGate.candidates).Count -eq 7 -and @($runGate.holds).Count -eq 2 -and (@($runGate.holds.code) -contains 'SCRIBE_M12_AMBIGUOUS_MULTIPLE_VALID') -and (@($runGate.holds.code) -contains 'SCRIBE_REFERENCE_COVERAGE_HOLD')) 'O2D12 candidates/holds changed.'
Assert-True ([int]$runGate.localization.qualifiedInstalledDetectorInputCount -eq 2 -and [string]$runGate.localization.selectedRegionSource -eq 'HASH_PINNED_INSTALLED_REVIEW_ONLY_PROCESSOR_OUTPUT' -and -not [bool]$runGate.installedProposalEligibleIdentity -and [string]$runGate.installedConsensusState -eq 'MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES') 'O2D12 installed-proposal evidence changed.'
Assert-True (-not [bool]$runGate.taskOrProcessRestarted -and -not [bool]$runGate.sourceMutationPerformed -and -not [bool]$runGate.sourceDeletionPerformed -and -not [bool]$runGate.waferActionPerformed -and -not [bool]$runGate.holdsCleared -and -not [bool]$runGate.providerActivated -and [bool]$runGate.reviewOnly -and -not [bool]$runGate.productionEligible) 'O2D12 protected invariants changed.'

$pathGate = & $pathTool -CandidatePath @($localZip, (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json'), (Join-Path $readyRoot 'RESULT.json'), $terminalGate) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D12 collection path gate failed: $($pathGate.state)"
$preflightResult = [ordered]@{schema='argos_o2d12_response_collection_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D12_RESPONSE_COLLECTION_PREFLIGHT';revision=$revision;requestId=$requestId;responseId=$responseId;endpointState=[string]$manifest.state;sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256;responseManifestSha256=$expectedManifestSha256;signedResponseVerified=$signatureValid;resultState=[string]$runGate.resultState;imageFirstString=[string]$runGate.imageFirstString;proposedString=[string]$runGate.proposedString;pathState=[string]$pathGate.state;mutationsPerformed=$false;jbodContacted=$false;requestRetried=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 10; return }

[void][IO.Directory]::CreateDirectory($outputRoot)
[IO.File]::Copy($sourceZip, $localZip, $false)
Assert-True ((Get-Item -LiteralPath $localZip).Length -eq $expectedZipBytes -and (Get-Sha256 $localZip) -eq $expectedZipSha256) 'O2D12 response changed during collection.'
[void][IO.Directory]::CreateDirectory($partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
$verified = & $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$verified.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verified.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O2D12 extracted response verification failed.'
[IO.Directory]::Move($partialRoot, $readyRoot)
$terminal = [ordered]@{schema='argos_o2d12_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D12_SIGNED_SLOT17_DEVELOPMENT_RESULT';disposition='APPROVED_BASELINE';revision=$revision;requestId=$requestId;responseId=$responseId;endpointState=[string]$manifest.state;signedResponseVerified=$true;signerThumbprint=[string]$manifest.signerThumbprint;sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256;responseManifestSha256=$expectedManifestSha256;responseFileCount=3;maintenanceState=[string]$maintenance.state;resultSha256=[string]$runGate.resultSha256;resultState=[string]$runGate.resultState;imageFirstString=[string]$runGate.imageFirstString;proposedString=[string]$runGate.proposedString;checksumState=[string]$runGate.checksumState;candidateCount=@($runGate.candidates).Count;holdCodes=@($runGate.holds.code);installedProposalEligibleIdentity=[bool]$runGate.installedProposalEligibleIdentity;installedConsensusState=[string]$runGate.installedConsensusState;processorProcessCount=[int]$runGate.processorProcessCount;taskOrProcessRestarted=[bool]$runGate.taskOrProcessRestarted;providerActivated=[bool]$runGate.providerActivated;sourceMutationPerformed=[bool]$runGate.sourceMutationPerformed;waferActionPerformed=[bool]$runGate.waferActionPerformed;holdsCleared=[bool]$runGate.holdsCleared;collectedRoot=$readyRoot;localResponseZip=$localZip;pathState=[string]$pathGate.state;slot16DevelopmentFrozen=$true;slot17DevelopmentFrozen=$true;slot18Authorized=$true;slots22Through25Exposed=$false;requestRetried=$false;healthyProcessorTouched=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $terminalGate -Value $terminal -Depth 14
$terminal | ConvertTo-Json -Depth 14

