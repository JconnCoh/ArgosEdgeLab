#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Collect)){throw 'Specify exactly one of -Preflight or -Collect.'}

function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Get-BytesSha256([byte[]]$Bytes){if($null-eq$Bytes){$Bytes=[byte[]]::new(0)};$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([byte[]]$Bytes))).Replace('-','')}finally{$sha.Dispose()}}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes){$entry=$Archive.GetEntry($Name);Assert-True($null-ne$entry -and $entry.Length-le$MaximumBytes)"S18B1 ZIP entry is absent or too large: $Name";$stream=$entry.Open();$memory=New-Object IO.MemoryStream;try{$stream.CopyTo($memory);return ,([byte[]]$memory.ToArray())}finally{$memory.Dispose();$stream.Dispose()}}
function Write-BytesCreateNew([string]$Path,[byte[]]$Bytes){$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($Bytes,0,$Bytes.Length)}finally{$stream.Dispose()}}
function Write-JsonCreateNew([string]$Path,[object]$Value,[int]$Depth=16){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine));Write-BytesCreateNew -Path $Path -Bytes $bytes}
function Normalize-Root([string]$Path){return $Path.Replace('/','\').TrimEnd('\')}

$project=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True($invocationPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase))'S18B1 invocation escaped the project.'
$invocation=Get-Content -Raw -LiteralPath $invocationPath|ConvertFrom-Json
$requestId='REQ_20260826T210516620Z_01E7E1F12961'
$responseId='R_6D8041628F37_20260826210733495_dacf9295'
$expectedZipBytes=3983
$expectedZipSha256='6D31A8B7157C7DAE895E26567CC8D915629304D4F62A2A5438A696D6C4C57709'
$expectedManifestSha256='5C55C28AD38F26551AB8D5F3AC48006F7658D004ED016202142962B856DE4A3C'
$expectedResultSha256='786B30141441DA56EE02412C3294A4A9C3D152F6FCA3EFBF97B9BC586CF2D1E3'
$expectedPayloadSha256='FF65951371B8287021E65517DBA148D9D6588B81AEB08A1E1E3F880CFF525511'
$expectedProposalSha256='52750D994411CB6E687F0B02B273B23A8B232A35EA77895B58E7C3A42A526473'
$expectedSummarySha256='B5E8F920FD6F2650F4D80B63A5E66E86C1E78536E92E8A191AF2BB9BAF381FDF'
$expectedInvocationSha256='D50A2C0DEBF2D66DC103C1AD3B393D0EB73FD7881B39B485E672BC95883F6E5A'
$expectedPreactionSha256='1CF4A0DC135FEE8B0DCBA7E30159C27606C6C005803FEDFDFA9021CBF76B0395'
$expectedPublishGateSha256='FA12D2EDBF17326F2356A7ADBB71423E4CE0BEAA3F5ED8053B7687469252FBC8'
$shareRoot='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'

Assert-True([string]$invocation.schema-eq'argos_s18b1_response_collection_invocation_v1' -and [string]$invocation.requestId-eq$requestId -and [string]$invocation.responseId-eq$responseId)'S18B1 collection identity changed.'
Assert-True([int64]$invocation.expectedZipBytes-eq$expectedZipBytes -and [string]$invocation.expectedZipSha256-eq$expectedZipSha256 -and [string]$invocation.expectedResponseManifestSha256-eq$expectedManifestSha256)'S18B1 response pins changed.'
Assert-True([bool]$invocation.singleCollectionAuthorized -and -not[bool]$invocation.requestRetryAuthorized -and [bool]$invocation.flattenNestedPayloadToSignedShortNames -and [bool]$invocation.reviewOnly -and -not[bool]$invocation.productionRoutingEnabled)'S18B1 collection authority changed.'
Assert-True((Get-Sha256 $invocationPath)-eq$expectedInvocationSha256)'S18B1 invocation bytes changed.'
$preactionPath=Join-Path $project 'work\OPENCV_SCRIBE_O2S18B1\PREACTION_S18B1_COLLECT.json'
$publishGatePath=Join-Path $project 'work\OPENCV_SCRIBE_O2S18B1\S18B1_PUBLISH_GATE.json'
Assert-True((Get-Sha256 $preactionPath)-eq$expectedPreactionSha256 -and (Get-Sha256 $publishGatePath)-eq$expectedPublishGateSha256)'S18B1 collection dependencies changed.'
$preactionTool=Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1';$historyPath=Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight|Out-Null

$psDrive=Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'S18B1 U: PowerShell mapping changed.'
$logicalDisk=Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Assert-True ($null-ne$logicalDisk -and [int]$logicalDisk.DriveType-eq4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot),[StringComparison]::OrdinalIgnoreCase)) 'S18B1 persistent U: mapping changed.'
$sourceZip=[IO.Path]::GetFullPath([string]$invocation.sourceZip)
Assert-True([IO.Path]::GetDirectoryName($sourceZip).Equals('U:\ProjectPortalRO\responses',[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($sourceZip)-eq($responseId+'.ready.zip'))'S18B1 response source changed.'
Assert-True((Test-Path -LiteralPath $sourceZip -PathType Leaf) -and (Get-Item -LiteralPath $sourceZip).Length-eq$expectedZipBytes -and (Get-Sha256 $sourceZip)-eq$expectedZipSha256)'S18B1 response ZIP changed.'

$outputRoot=[IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.outputRoot).Replace('/','\'))).TrimEnd('\')
$terminalGate=[IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.terminalGate).Replace('/','\')))
Assert-True($outputRoot.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase) -and $terminalGate.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase))'S18B1 collection target escaped the project.'
$localZip=Join-Path $outputRoot 'response.zip';$partialRoot=Join-Path $outputRoot 'response.partial';$readyRoot=Join-Path $outputRoot 'response';$decodedPartial=Join-Path $partialRoot 'decoded';$proposalLocal=Join-Path $decodedPartial 'slot18_proposal.json';$summaryLocal=Join-Path $decodedPartial 'slot18_multi_channel_summary.json';$mappingLocal=Join-Path $decodedPartial 'source_to_local_mapping.json'
foreach($fresh in @($outputRoot,$terminalGate)){Assert-True(-not(Test-Path -LiteralPath $fresh))"S18B1 collection target is not fresh: $fresh"}
$verifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1';$certificatePath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer';$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($sourceZip)
try{
    $expectedEntries=@('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json');$entryNames=@($archive.Entries|ForEach-Object{$_.FullName});Assert-True($entryNames.Count-eq4 -and @(Compare-Object $expectedEntries $entryNames).Count-eq0)'S18B1 response entry set changed.'
    $manifestBytes=Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576;$signatureBytes=Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096;$resultBytes=Read-ZipEntryBytes $archive 'RESULT.json' 1048576;$payloadBytes=Read-ZipEntryBytes $archive 'DATA_PULL_PAYLOAD.zip' 4194304
}finally{$archive.Dispose()}
Assert-True((Get-BytesSha256 $manifestBytes)-eq$expectedManifestSha256 -and (Get-BytesSha256 $resultBytes)-eq$expectedResultSha256 -and (Get-BytesSha256 $payloadBytes)-eq$expectedPayloadSha256)'S18B1 response content hash changed.'
$manifest=[Text.Encoding]::UTF8.GetString($manifestBytes)|ConvertFrom-Json;$result=[Text.Encoding]::UTF8.GetString($resultBytes)|ConvertFrom-Json
Assert-True([string]$manifest.schema-eq'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId-eq$requestId -and [string]$manifest.responseId-eq$responseId -and [string]$manifest.sourceRole-eq'JBOD' -and [string]$manifest.state-eq'PASS_DATA_PULL')'S18B1 signed manifest identity/state changed.'
Assert-True([string]$manifest.signerThumbprint-eq'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC' -and [bool]$manifest.reviewOnly -and -not[bool]$manifest.trainingEligible -and -not[bool]$manifest.xmlEligible -and -not[bool]$manifest.productionEligible -and -not[bool]$manifest.productionRoutingEnabled -and -not[bool]$manifest.credentialsIncluded)'S18B1 signed authority changed.'
Assert-True(@($manifest.files).Count-eq2 -and @(Compare-Object @('DATA_PULL_PAYLOAD.zip','RESULT.json') @($manifest.files.path)).Count-eq0)'S18B1 manifest file set changed.'
foreach($record in @($manifest.files)){$bytes=if([string]$record.path-eq'DATA_PULL_PAYLOAD.zip'){$payloadBytes}else{$resultBytes};Assert-True (@($bytes).Count-eq[int64]$record.bytes -and (Get-BytesSha256 ([byte[]]$bytes))-eq[string]$record.sha256) "S18B1 declared file changed: $($record.path)"}
$cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath);$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert);try{$signatureValid=$rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
Assert-True($signatureValid -and $cert.Thumbprint-eq'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC')'S18B1 response signature failed.'

$proposalEntry='data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot18/SCRIBE_PROPOSAL.json';$summaryEntry='data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot18/scribe/multi_channel/MULTI_CHANNEL_READER_SUMMARY.json'
$memory=New-Object IO.MemoryStream(,([byte[]]$payloadBytes));$inner=New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
try{$innerNames=@($inner.Entries|ForEach-Object{$_.FullName});Assert-True($innerNames.Count-eq2 -and @(Compare-Object @($proposalEntry,$summaryEntry) $innerNames).Count-eq0)'S18B1 nested payload entry set changed.';$proposalBytes=Read-ZipEntryBytes $inner $proposalEntry 1048576;$summaryBytes=Read-ZipEntryBytes $inner $summaryEntry 1048576}finally{$inner.Dispose();$memory.Dispose()}
Assert-True((Get-BytesSha256 $proposalBytes)-eq$expectedProposalSha256 -and (Get-BytesSha256 $summaryBytes)-eq$expectedSummarySha256)'S18B1 nested source hashes changed.'
Assert-True([string]$result.schema-eq'argos_project_portal_data_pull_result_v2' -and [string]$result.state-eq'PASS_DATA_PULL' -and [string]$result.approvedRoot-eq'JBOD_PROCESSOR_REVIEW' -and [string]$result.containerSha256-eq$expectedPayloadSha256 -and @($result.files).Count-eq2)'S18B1 DATA_PULL result changed.'
foreach($row in @($result.files)){$expected=if([string]$row.entryPath-eq$proposalEntry){$expectedProposalSha256}elseif([string]$row.entryPath-eq$summaryEntry){$expectedSummarySha256}else{throw "S18B1 unexpected result path: $($row.entryPath)"};Assert-True([string]$row.sha256-eq$expected)"S18B1 result hash changed: $($row.entryPath)"}
$proposal=[Text.Encoding]::UTF8.GetString($proposalBytes)|ConvertFrom-Json;$summary=[Text.Encoding]::UTF8.GetString($summaryBytes)|ConvertFrom-Json
Assert-True([string]$proposal.schema-eq'argos_jbod_scribe_proposal_v1' -and [string]$proposal.physicalIdentity-eq'62619-433_20260824005735_Slot18' -and [string]$summary.schema-eq'argos_scribe_multi_channel_polarity_reader_v1' -and [string]$summary.acquisitionKey-eq'62619-433_20260824005735_SLOT18')'S18B1 source identity changed.'
$bfPath=[string]$proposal.bfOrientedReviewPath;$dfPath=[string]$proposal.dfOrientedReviewPath
Assert-True($bfPath.EndsWith('\62619-433_20260824005735_Slot18\scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',[StringComparison]::OrdinalIgnoreCase) -and $dfPath.EndsWith('\62619-433_20260824005735_Slot18\scribe\DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',[StringComparison]::OrdinalIgnoreCase))'S18B1 oriented input paths changed.'
$hashMetadataPresent=($proposal.PSObject.Properties.Name -contains 'bfOrientedReviewSha256') -and ($proposal.PSObject.Properties.Name -contains 'dfOrientedReviewSha256')
$pathGate=& $pathTool -CandidatePath @($localZip,(Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json'),$proposalLocal,$summaryLocal,$mappingLocal,$terminalGate) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True([string]$pathGate.state-eq'PASS_PATH_BUDGET')'S18B1 collection path budget failed.'
$preflightResult=[ordered]@{schema='argos_s18b1_response_collection_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S18B1_RESPONSE_COLLECTION_PREFLIGHT';requestId=$requestId;responseId=$responseId;endpointState=[string]$manifest.state;sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256;responseManifestSha256=$expectedManifestSha256;signedResponseVerified=$signatureValid;proposalSha256=$expectedProposalSha256;summarySha256=$expectedSummarySha256;bfOrientedReviewPath=$bfPath;dfOrientedReviewPath=$dfPath;orientedInputHashMetadataPresent=$hashMetadataPresent;pathState=[string]$pathGate.state;mutationsPerformed=$false;jbodContacted=$false;requestRetried=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$preflightResult|ConvertTo-Json -Depth 10;return}

[void][IO.Directory]::CreateDirectory($outputRoot);[IO.File]::Copy($sourceZip,$localZip,$false);Assert-True((Get-Sha256 $localZip)-eq$expectedZipSha256)'S18B1 response changed during copy.';[void][IO.Directory]::CreateDirectory($partialRoot);[IO.Compression.ZipFile]::ExtractToDirectory($localZip,$partialRoot)
$verified=& $verifier -PackagePath $partialRoot -EndpointCertificatePath $certificatePath -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True([string]$verified.State-eq'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verified.EndpointState-eq'PASS_DATA_PULL')'S18B1 extracted response verification failed.'
[void][IO.Directory]::CreateDirectory($decodedPartial);Write-BytesCreateNew -Path $proposalLocal -Bytes $proposalBytes;Write-BytesCreateNew -Path $summaryLocal -Bytes $summaryBytes
$mapping=[ordered]@{schema='argos_s18b1_signed_source_to_local_mapping_v1';createdUtc=[DateTime]::UtcNow.ToString('o');requestId=$requestId;responseId=$responseId;payloadSha256=$expectedPayloadSha256;files=@([ordered]@{entryPath=$proposalEntry;sourceSha256=$expectedProposalSha256;localName='slot18_proposal.json';localSha256=(Get-Sha256 $proposalLocal)},[ordered]@{entryPath=$summaryEntry;sourceSha256=$expectedSummarySha256;localName='slot18_multi_channel_summary.json';localSha256=(Get-Sha256 $summaryLocal)});deepSourcePathsNotMaterialized=$true;shortDeterministicLocalNames=$true;reviewOnly=$true;productionRoutingEnabled=$false};Write-JsonCreateNew -Path $mappingLocal -Value $mapping -Depth 10
[IO.Directory]::Move($partialRoot,$readyRoot)
$terminal=[ordered]@{schema='argos_s18b1_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S18B1_SIGNED_SLOT18_SOURCE_METADATA_COLLECTED_HASH_BINDING_PENDING';disposition='PENDING_GATE';requestId=$requestId;responseId=$responseId;endpointState=[string]$manifest.state;signedResponseVerified=$true;signerThumbprint=[string]$manifest.signerThumbprint;sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256;responseManifestSha256=$expectedManifestSha256;payloadSha256=$expectedPayloadSha256;proposalSha256=$expectedProposalSha256;summarySha256=$expectedSummarySha256;physicalIdentity=[string]$proposal.physicalIdentity;bfOrientedReviewPath=$bfPath;dfOrientedReviewPath=$dfPath;orientedInputPathsBound=$true;orientedInputHashMetadataPresent=$hashMetadataPresent;orientedInputHashesBound=$false;proposal=[string]$proposal.proposal;proposalState=[string]$proposal.state;readerState=[string]$proposal.readerState;referenceCoverageComplete=[bool]$proposal.referenceCoverageComplete;multiChannelState=[string]$summary.state;consensusState=[string]$summary.consensusState;candidateCount=[int]$summary.candidateCount;nextObservation='OBTAIN_EXACT_CURRENT_BF_DF_ORIENTED_INPUT_SHA256_WITHOUT_DECODING_PIXELS';collectedRoot=$readyRoot;deepSourcePathsNotMaterialized=$true;requestRetried=$false;imageBytesRead=$false;pixelsDecoded=$false;taskOrProcessActionPerformed=$false;sourceMutationPerformed=$false;providerActivated=$false;slots22Through25Exposed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $terminalGate -Value $terminal -Depth 14;$terminal|ConvertTo-Json -Depth 14
