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
function Get-RequiredProperty([object]$InputObject, [string]$Name) {
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "Required property is absent: $Name" }
    return $property.Value
}
function Read-ZipJson([IO.Compression.ZipArchive]$Archive, [string]$Name, [int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry -and $entry.Length -gt 0 -and $entry.Length -le $MaximumBytes) "O2D5 bounded ZIP entry is absent or too large: $Name"
    $stream = $entry.Open()
    $reader = New-Object IO.StreamReader($stream,(New-Object Text.UTF8Encoding($false,$true)))
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) }
    finally { $reader.Dispose(); $stream.Dispose() }
}
function Get-ZipEntrySha256([IO.Compression.ZipArchive]$Archive, [string]$Name) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry) "O2D5 ZIP entry is absent: $Name"
    $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 14) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'O2D5 collection invocation escaped the project.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
$revision = 'O2D5_20260825T190855Z_54B4C08C'
$requestId = 'DIRECT_O2D5_20260825T190855Z_54B4C08C'
$responseId = 'R_ADD3BF802E2F_20260825193812855_dbc9bb56'
Assert-True ([string]$invocation.schema -eq 'argos_o2d5_response_collection_invocation_v1' -and [string]$invocation.revision -eq $revision -and [string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O2D5 response collection identity changed.'
Assert-True ([bool]$invocation.singleCollectionAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D5 response collection authority changed.'

$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\ProjectPortalRO\responses'
Assert-True (([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedResponseRoot,[StringComparison]::OrdinalIgnoreCase)) 'O2D5 response source parent changed.'
Assert-True ([IO.Path]::GetFileName($sourceZip) -eq ($responseId+'.ready.zip')) 'O2D5 response source leaf changed.'
$expectedZipBytes = [int64]$invocation.expectedZipBytes
$expectedZipSha256 = ([string]$invocation.expectedZipSha256).ToUpperInvariant()
$expectedManifestSha256 = ([string]$invocation.expectedResponseManifestSha256).ToUpperInvariant()
Assert-True ($expectedZipBytes -eq 67852 -and $expectedZipSha256 -match '^[0-9A-F]{64}$' -and $expectedManifestSha256 -match '^[0-9A-F]{64}$') 'O2D5 response hash/size contract changed.'
Assert-True ((Test-Path -LiteralPath $sourceZip -PathType Leaf) -and (Get-Item -LiteralPath $sourceZip).Length -eq $expectedZipBytes -and (Get-Sha256 $sourceZip) -eq $expectedZipSha256) 'O2D5 source response ZIP changed.'

$collectionRoot = [IO.Path]::GetFullPath([string]$invocation.collectionRoot).TrimEnd('\')
Assert-True ($collectionRoot.Equals('C:\A2D5R',[StringComparison]::OrdinalIgnoreCase)) 'O2D5 collection root changed.'
$responseToken = $responseId+'.ready'
$localZip = $collectionRoot+'\'+$responseToken+'.zip'
$readyRoot = $collectionRoot+'\'+$responseToken
$partialRoot = $readyRoot+'.partial'
$terminalGate = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.terminalGate).Replace('/','\')))
Assert-True ($terminalGate.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'O2D5 terminal gate escaped the project.'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($required in @($responseVerifier,$endpointCertificate,$pathTool)) { Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2D5 response prerequisite is absent: $required" }
foreach ($fresh in @($collectionRoot,$localZip,$readyRoot,$partialRoot,$terminalGate)) { Assert-True (-not (Test-Path -LiteralPath $fresh)) "O2D5 response collection path is not fresh: $fresh" }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
    $expectedEntryNames = @('EXECUTION.json','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json','RUN_GATE.json')
    Assert-True ($entryNames.Count -eq $expectedEntryNames.Count -and (@(Compare-Object $expectedEntryNames $entryNames).Count -eq 0)) 'O2D5 response ZIP entry set changed.'
    $manifest = Read-ZipJson $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $execution = Read-ZipJson $archive 'EXECUTION.json' 1048576
    $result = Read-ZipJson $archive 'RESULT.json' 1048576
    $runGate = Read-ZipJson $archive 'RUN_GATE.json' 1048576
    $manifestSha256 = Get-ZipEntrySha256 $archive 'PORTAL_RESPONSE_MANIFEST.json'
}
finally { $archive.Dispose() }

Assert-True ($manifestSha256 -eq $expectedManifestSha256 -and [string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.responseId -eq $responseId -and [string]$manifest.requestId -eq $requestId) 'O2D5 signed response manifest identity changed.'
Assert-True ([string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_O2D5_DIRECT_ADMIN_SLOT16' -and [string]$manifest.signerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O2D5 signed response source/state/signer changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'O2D5 signed response authority changed.'
$manifestFiles = @(Get-RequiredProperty $manifest 'files')
Assert-True ($manifestFiles.Count -eq 3 -and (@($manifestFiles.path | Sort-Object) -join '|') -eq 'EXECUTION.json|RESULT.json|RUN_GATE.json') 'O2D5 response manifest file set changed.'

Assert-True ([string]$execution.schema -eq 'argos_o2d5_direct_execution_v1' -and [string]$execution.state -eq 'PASS_O2D5_DIRECT_EXECUTION' -and [string]$execution.revision -eq $revision -and [string]$execution.requestId -eq $requestId -and [string]$execution.computerName -eq 'A1025645101') 'O2D5 execution identity changed.'
Assert-True ([string]$execution.workRoot -eq 'D:\A2\w\ocv\O2D5_20260825T190855Z_54B4C08C' -and [string]$execution.outputRoot -eq 'D:\A2\o\ocv\O2D5_20260825T190855Z_54B4C08C') 'O2D5 execution D roots changed.'
Assert-True ([bool]$execution.sourceImageBytesRead -and [bool]$execution.pixelsDecodedByOpenCv -and -not [bool]$execution.taskOrProcessRestarted -and -not [bool]$execution.providerActivated -and [bool]$execution.reviewOnly -and -not [bool]$execution.productionRoutingEnabled) 'O2D5 execution boundary changed.'

Assert-True ([string]$result.schema -eq 'argos_opencv_scribe_result_v1' -and [string]$result.state -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' -and -not [bool]$result.eligibleIdentity -and [string]$result.imageFirstString -eq '699F999999F6' -and [string]$result.checksumState -eq 'SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY') 'O2D5 Slot16 result state/string changed.'
Assert-True (@($result.hypotheses).Count -eq 72 -and @($result.candidates).Count -eq 124 -and @($result.holds).Count -eq 1 -and [string]$result.holds[0].code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD') 'O2D5 Slot16 result cardinality/hold changed.'
Assert-True ([int]$result.localization.candidateCount -eq 9 -and [string]$result.localization.selectedRegionId -eq 'EXCEPTION_120_0010_X1.25_O+0.00' -and [string]$result.localization.confidenceCalibrationState -eq 'UNQUALIFIED_DEVELOPMENT') 'O2D5 Slot16 localization changed.'
Assert-True ([string]$result.provenance.sources.bf.sha256 -eq 'CE5502F33D54A12FEF1A082A0B18C1635169B2F5D0BE98C402EA8238D86C2E53' -and [string]$result.provenance.sources.df.sha256 -eq '6FAC812536C19F07D1C3DAD5263741350E94460A07867F2AEE0D2EEEA8C19ED9' -and [string]$result.provenance.sources.jobSha256 -eq 'C05B48D1FFF96B28BC6D5C3393FB7E1F8F84844DA92DAF90FC04F983BA5C2A98') 'O2D5 Slot16 input provenance changed.'
Assert-True (-not [bool]$result.provenance.references.referenceCoverageComplete -and [string]$result.provenance.references.missingBodyReferenceLabels -eq 'IJKOQVWXYZ' -and [bool]$result.provenance.bfDfIndependent -and [bool]$result.provenance.boundedExceptionSearchUsed) 'O2D5 Slot16 reference/localization provenance changed.'
Assert-True ([bool]$result.authority.reviewOnly -and -not [bool]$result.authority.automaticIdentityAuthority -and -not [bool]$result.authority.trainingEligible -and -not [bool]$result.authority.xmlEligible -and -not [bool]$result.authority.productionEligible -and -not [bool]$result.authority.mayClearHolds) 'O2D5 result authority changed.'

Assert-True ([string]$runGate.schema -eq 'argos_o2d5_opencv_scribe_development_gate_v1' -and [string]$runGate.state -eq 'PASS_O2D5_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED' -and [string]$runGate.disposition -eq 'PENDING_GATE' -and [string]$runGate.revision -eq $revision -and [string]$runGate.requestId -eq $requestId -and [string]$runGate.slotId -eq 'Slot16') 'O2D5 run gate identity changed.'
Assert-True ([string]$runGate.engineSha256 -eq '3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9' -and [string]$runGate.referenceBundleSha256 -eq '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6' -and [string]$runGate.jobSha256 -eq 'C05B48D1FFF96B28BC6D5C3393FB7E1F8F84844DA92DAF90FC04F983BA5C2A98') 'O2D5 run gate dependency hashes changed.'
Assert-True ([string]$runGate.resultSha256 -eq [string]$execution.resultSha256 -and [string]$runGate.resultState -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' -and [string]$runGate.imageFirstString -eq '699F999999F6' -and [string]$runGate.checksumState -eq 'SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY') 'O2D5 run gate result binding changed.'
Assert-True ([bool]$runGate.sourceAliasCreated -and [bool]$runGate.sourceAliasTargetVerified -and [bool]$runGate.sourceAliasRemoved -and -not [bool]$runGate.referenceCoverageComplete -and [string]$runGate.missingReferenceLabels -eq 'IJKOQVWXYZ') 'O2D5 run gate alias/reference state changed.'
Assert-True (-not [bool]$runGate.inspectionTasksChanged -and -not [bool]$runGate.processorTaskChanged -and -not [bool]$runGate.taskOrProcessRestarted -and -not [bool]$runGate.sourceMutationPerformed -and -not [bool]$runGate.sourceDeletionPerformed -and -not [bool]$runGate.waferActionPerformed -and -not [bool]$runGate.holdsCleared -and -not [bool]$runGate.providerActivated -and [bool]$runGate.reviewOnly -and -not [bool]$runGate.productionEligible) 'O2D5 run gate protected invariants changed.'

$planned = @($localZip,$partialRoot+'\PORTAL_RESPONSE_MANIFEST.json',$partialRoot+'\RESULT.json',$readyRoot+'\RUN_GATE.json',$terminalGate)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') "O2D5 response collection path gate failed: $($pathGate.state)"

$preflightValue = [ordered]@{
    schema='argos_o2d5_response_collection_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_RESPONSE_COLLECTION_PREFLIGHT'
    revision=$revision;requestId=$requestId;responseId=$responseId;sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256
    responseManifestSha256=$manifestSha256;endpointState=[string]$manifest.state;resultState=[string]$result.state;imageFirstString=[string]$result.imageFirstString
    pathState=[string]$pathGate.state;mutationsPerformed=$false;jbodContacted=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightValue | ConvertTo-Json -Depth 10; return }

[void][IO.Directory]::CreateDirectory($collectionRoot)
[IO.File]::Copy($sourceZip,$localZip,$false)
Assert-True ((Get-Item -LiteralPath $localZip).Length -eq $expectedZipBytes -and (Get-Sha256 $localZip) -eq $expectedZipSha256) 'O2D5 response changed during local copy.'
[void][IO.Directory]::CreateDirectory($partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip,$partialRoot)
& $responseVerifier -PackagePath $partialRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'O2D5 signed response verification failed.' }
foreach ($row in $manifestFiles) {
    $path = Join-Path $partialRoot ([string]$row.path)
    Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes -and (Get-Sha256 $path) -eq [string]$row.sha256) "O2D5 extracted response file changed: $($row.path)"
}
[IO.Directory]::Move($partialRoot,$readyRoot)

$terminal = [ordered]@{
    schema='argos_o2d5_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_SIGNED_SLOT16_DEVELOPMENT_RESULT';disposition='PENDING_GATE'
    revision=$revision;requestId=$requestId;responseId=$responseId;endpointState=[string]$manifest.state;signedResponseVerified=$true;signerThumbprint=[string]$manifest.signerThumbprint
    sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256;responseManifestSha256=$manifestSha256;responseFileCount=$manifestFiles.Count
    executionState=[string]$execution.state;resultSha256=[string]$execution.resultSha256;runGateSha256=[string]$execution.gateSha256;resultState=[string]$result.state
    imageFirstString=[string]$result.imageFirstString;checksumState=[string]$result.checksumState;localizationCandidateCount=[int]$result.localization.candidateCount
    hypothesisCount=@($result.hypotheses).Count;candidateCount=@($result.candidates).Count;holdCodes=@($result.holds | ForEach-Object { [string]$_.code })
    bfSha256=[string]$result.provenance.sources.bf.sha256;dfSha256=[string]$result.provenance.sources.df.sha256;referenceCoverageComplete=[bool]$result.provenance.references.referenceCoverageComplete
    missingReferenceLabels=[string]$result.provenance.references.missingBodyReferenceLabels;collectedRoot=$readyRoot;localResponseZip=$localZip;pathState=[string]$pathGate.state
    sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;inspectionTasksChanged=$false;processorTaskChanged=$false;taskOrProcessRestarted=$false
    providerActivated=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false
    slot16DevelopmentFrozen=$true;slot17Authorized=$true;slots22Through25Exposed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path $terminalGate -Value $terminal -Depth 12
$terminal | ConvertTo-Json -Depth 12
