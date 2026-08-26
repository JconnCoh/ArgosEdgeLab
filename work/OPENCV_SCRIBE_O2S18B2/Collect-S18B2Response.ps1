#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Collect)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Collect)){throw 'Specify exactly one of -Preflight or -Collect.'}

function Assert-ExactCondition([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-ExactFileSha256([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Get-ExactBytesSha256([byte[]]$Bytes){if($null-eq$Bytes){$Bytes=[byte[]]::new(0)};$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([byte[]]$Bytes))).Replace('-','')}finally{$sha.Dispose()}}
function Read-ExactZipEntryBytes([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes){$entry=$Archive.GetEntry($Name);Assert-ExactCondition($null-ne$entry -and $entry.Length-le$MaximumBytes)"S18B2 ZIP entry is absent or too large: $Name";$stream=$entry.Open();$memory=New-Object IO.MemoryStream;try{$stream.CopyTo($memory);return ,([byte[]]$memory.ToArray())}finally{$memory.Dispose();$stream.Dispose()}}
function Write-ExactBytesCreateNew([string]$Path,[byte[]]$Bytes){$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($Bytes,0,$Bytes.Length)}finally{$stream.Dispose()}}
function Write-ExactJsonCreateNew([string]$Path,[object]$Value){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth 14)+[Environment]::NewLine));Write-ExactBytesCreateNew -Path $Path -Bytes $bytes}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_20260826T211126103Z_8028A37AF6FF'
$responseId='R_2F9A6357BD64_20260826211256935_515aba34'
$source='U:\ProjectPortalRO\responses\R_2F9A6357BD64_20260826211256935_515aba34.ready.zip'
$expectedZipBytes=2330211
$expectedZipSha256='260FD3F853858136A290ADD881E3983DA02073E87EE1436449C8806B450129CB'
$expectedManifestSha256='0FA10F78A4E9EDE009227E8F8AC742FE95CB291F8D52037299ECC249FCA9E26A'
$expectedResultSha256='C086491034934BE71FE88A8224884A03C056FF62656FFB3C70309568F77C10D8'
$expectedPayloadSha256='88DE48CDFCA5E0A1F277936598F5F04FC221AA265C63A3F2932F6772282E431A'
$expectedBfBytes=1655393
$expectedBfSha256='68BC8F2A68CCDBE0D9C71BFE742509509DEE43E79FF3661723F5429A2799AC66'
$expectedDfBytes=671586
$expectedDfSha256='5E8D1377A8D84C467AC60FF9EEAAEA1FCC5C8835AC384246F84F1936624B9048'
$preactionPath=Join-Path $PSScriptRoot 'PREACTION_S18B2_COLLECT.json'
Assert-ExactCondition((Get-ExactFileSha256 $preactionPath)-eq'DE2BE00BFA8BBE58EDFB9444D92F3E76A9360954AE9DCB099E936A64F091117E')'S18B2 collection preaction changed.'
& (Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1') -AuditPath (Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json') -ContractPath $preactionPath -ProjectRoot $project -Preflight|Out-Null
Assert-ExactCondition((Test-Path -LiteralPath $source -PathType Leaf) -and (Get-Item -LiteralPath $source).Length-eq$expectedZipBytes -and (Get-ExactFileSha256 $source)-eq$expectedZipSha256)'S18B2 response ZIP changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($source)
try{
    $expectedEntries=@('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json')
    $entryNames=@($archive.Entries|ForEach-Object{$_.FullName})
    Assert-ExactCondition($entryNames.Count-eq4 -and @(Compare-Object $expectedEntries $entryNames).Count-eq0)'S18B2 response entry set changed.'
    $manifestBytes=Read-ExactZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes=Read-ExactZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096
    $resultBytes=Read-ExactZipEntryBytes $archive 'RESULT.json' 1048576
    $payloadBytes=Read-ExactZipEntryBytes $archive 'DATA_PULL_PAYLOAD.zip' 4194304
}finally{$archive.Dispose()}
Assert-ExactCondition((Get-ExactBytesSha256 $manifestBytes)-eq$expectedManifestSha256 -and (Get-ExactBytesSha256 $resultBytes)-eq$expectedResultSha256 -and (Get-ExactBytesSha256 $payloadBytes)-eq$expectedPayloadSha256)'S18B2 signed response content changed.'
$manifest=[Text.Encoding]::UTF8.GetString($manifestBytes)|ConvertFrom-Json
$result=[Text.Encoding]::UTF8.GetString($resultBytes)|ConvertFrom-Json
Assert-ExactCondition([string]$manifest.schema-eq'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId-eq$requestId -and [string]$manifest.responseId-eq$responseId -and [string]$manifest.sourceRole-eq'JBOD' -and [string]$manifest.state-eq'PASS_DATA_PULL')'S18B2 signed manifest identity or state changed.'
Assert-ExactCondition([string]$manifest.signerThumbprint-eq'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC' -and [bool]$manifest.reviewOnly -and -not[bool]$manifest.trainingEligible -and -not[bool]$manifest.xmlEligible -and -not[bool]$manifest.productionEligible -and -not[bool]$manifest.productionRoutingEnabled -and -not[bool]$manifest.credentialsIncluded)'S18B2 signed authority changed.'
Assert-ExactCondition(@($manifest.files).Count-eq2 -and @(Compare-Object @('DATA_PULL_PAYLOAD.zip','RESULT.json') @($manifest.files.path)).Count-eq0)'S18B2 manifest file set changed.'
foreach($record in @($manifest.files)){$recordBytes=if([string]$record.path-eq'DATA_PULL_PAYLOAD.zip'){$payloadBytes}else{$resultBytes};Assert-ExactCondition(@($recordBytes).Count-eq[int64]$record.bytes -and (Get-ExactBytesSha256 ([byte[]]$recordBytes))-eq[string]$record.sha256)"S18B2 declared response file changed: $($record.path)"}
$certificatePath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$certificate=New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try{$signatureValid=$rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
Assert-ExactCondition($signatureValid -and $certificate.Thumbprint-eq'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC')'S18B2 response signature failed.'
$bfEntry='data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot18/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$dfEntry='data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot18/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$memory=New-Object IO.MemoryStream(,([byte[]]$payloadBytes))
$inner=New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
try{$innerNames=@($inner.Entries|ForEach-Object{$_.FullName});Assert-ExactCondition($innerNames.Count-eq2 -and @(Compare-Object @($bfEntry,$dfEntry) $innerNames).Count-eq0)'S18B2 nested payload entry set changed.';$bfBytes=Read-ExactZipEntryBytes $inner $bfEntry 4194304;$dfBytes=Read-ExactZipEntryBytes $inner $dfEntry 4194304}finally{$inner.Dispose();$memory.Dispose()}
$bfSha256=Get-ExactBytesSha256 $bfBytes
$dfSha256=Get-ExactBytesSha256 $dfBytes
Assert-ExactCondition(@($bfBytes).Count-eq$expectedBfBytes -and $bfSha256-eq$expectedBfSha256 -and @($dfBytes).Count-eq$expectedDfBytes -and $dfSha256-eq$expectedDfSha256)'S18B2 oriented input bytes changed.'
Assert-ExactCondition([string]$result.schema-eq'argos_project_portal_data_pull_result_v2' -and [string]$result.state-eq'PASS_DATA_PULL' -and [string]$result.approvedRoot-eq'JBOD_PROCESSOR_REVIEW' -and [string]$result.containerSha256-eq$expectedPayloadSha256 -and @($result.files).Count-eq2)'S18B2 DATA_PULL result changed.'
foreach($row in @($result.files)){$expectedHash=if([string]$row.entryPath-eq$bfEntry){$expectedBfSha256}elseif([string]$row.entryPath-eq$dfEntry){$expectedDfSha256}else{throw "S18B2 unexpected result path: $($row.entryPath)"};Assert-ExactCondition([string]$row.sha256-eq$expectedHash)"S18B2 result hash changed: $($row.entryPath)"}
$outputRoot=Join-Path $PSScriptRoot 'collected_metadata'
$terminalGate=Join-Path $PSScriptRoot 'S18B2_TERMINAL_RESPONSE_GATE.json'
Assert-ExactCondition(-not(Test-Path -LiteralPath $outputRoot) -and -not(Test-Path -LiteralPath $terminalGate))'S18B2 collection output exists.'
$pathGate=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $outputRoot 'PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $outputRoot 'PORTAL_RESPONSE_MANIFEST.sig'),(Join-Path $outputRoot 'RESULT.json'),$terminalGate) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-ExactCondition([string]$pathGate.state-eq'PASS_PATH_BUDGET')'S18B2 collection path budget failed.'
$gate=[ordered]@{schema='argos_s18b2_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S18B2_SIGNED_SLOT18_ORIENTED_INPUT_HASH_BINDING';disposition='APPROVED_BASELINE';requestId=$requestId;responseId=$responseId;endpointState='PASS_DATA_PULL';signedResponseVerified=$true;signerThumbprint=[string]$manifest.signerThumbprint;sourceZip=$source;sourceZipBytes=$expectedZipBytes;sourceZipSha256=$expectedZipSha256;responseManifestSha256=$expectedManifestSha256;resultSha256=$expectedResultSha256;payloadSha256=$expectedPayloadSha256;bfPath=$bfEntry;bfBytes=$expectedBfBytes;bfSha256=$expectedBfSha256;dfPath=$dfEntry;dfBytes=$expectedDfBytes;dfSha256=$expectedDfSha256;sourceImageBytesReadByEndpoint=$true;payloadImagesExtractedLocally=$false;pixelsDecoded=$false;requestRetried=$false;taskOrProcessActionPerformed=$false;sourceMutationPerformed=$false;providerActivated=$false;slots22Through25Exposed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
if($Preflight){$gate.state='PASS_S18B2_RESPONSE_COLLECTION_PREFLIGHT';$gate.mutationsPerformed=$false;$gate|ConvertTo-Json -Depth 14;return}
[void][IO.Directory]::CreateDirectory($outputRoot)
Write-ExactBytesCreateNew -Path (Join-Path $outputRoot 'PORTAL_RESPONSE_MANIFEST.json') -Bytes $manifestBytes
Write-ExactBytesCreateNew -Path (Join-Path $outputRoot 'PORTAL_RESPONSE_MANIFEST.sig') -Bytes $signatureBytes
Write-ExactBytesCreateNew -Path (Join-Path $outputRoot 'RESULT.json') -Bytes $resultBytes
Write-ExactJsonCreateNew -Path $terminalGate -Value $gate
$gate|ConvertTo-Json -Depth 14
