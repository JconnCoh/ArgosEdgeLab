#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ResponseZip,
    [Parameter(Mandatory=$true)][string]$ExpectedRequestId,
    [switch]$Preflight
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(-not$Preflight){throw 'S18B2 response inspection is preflight-only.'}

function Assert-ExactCondition([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-ExactBytesSha256([byte[]]$Bytes){if($null-eq$Bytes){$Bytes=[byte[]]::new(0)};$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([byte[]]$Bytes))).Replace('-','')}finally{$sha.Dispose()}}
function Read-ExactZipEntryBytes([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes){$entry=$Archive.GetEntry($Name);Assert-ExactCondition($null-ne$entry -and $entry.Length-le$MaximumBytes)"S18B2 ZIP entry is absent or too large: $Name";$stream=$entry.Open();$memory=New-Object IO.MemoryStream;try{$stream.CopyTo($memory);return ,([byte[]]$memory.ToArray())}finally{$memory.Dispose();$stream.Dispose()}}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceZip=[IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ResponseZip).Path)
Assert-ExactCondition((Get-Item -LiteralPath $sourceZip).Length-le 4194304)'S18B2 response exceeds 4 MiB.'
$certificatePath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($sourceZip)
try{
    $expectedEntries=@('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json')
    $entryNames=@($archive.Entries|ForEach-Object{$_.FullName})
    Assert-ExactCondition($entryNames.Count-eq4 -and @(Compare-Object $expectedEntries $entryNames).Count-eq0)'S18B2 response entry set changed.'
    $manifestBytes=Read-ExactZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes=Read-ExactZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' 4096
    $resultBytes=Read-ExactZipEntryBytes $archive 'RESULT.json' 1048576
    $payloadBytes=Read-ExactZipEntryBytes $archive 'DATA_PULL_PAYLOAD.zip' 4194304
}finally{$archive.Dispose()}
$manifest=[Text.Encoding]::UTF8.GetString($manifestBytes)|ConvertFrom-Json
$result=[Text.Encoding]::UTF8.GetString($resultBytes)|ConvertFrom-Json
Assert-ExactCondition([string]$manifest.schema-eq'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId-eq$ExpectedRequestId -and [string]$manifest.sourceRole-eq'JBOD' -and [string]$manifest.state-eq'PASS_DATA_PULL')'S18B2 signed response identity or state changed.'
Assert-ExactCondition([string]$manifest.signerThumbprint-eq'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC' -and [bool]$manifest.reviewOnly -and -not[bool]$manifest.trainingEligible -and -not[bool]$manifest.xmlEligible -and -not[bool]$manifest.productionEligible -and -not[bool]$manifest.productionRoutingEnabled -and -not[bool]$manifest.credentialsIncluded)'S18B2 signed response authority changed.'
Assert-ExactCondition(@($manifest.files).Count-eq2 -and @(Compare-Object @('DATA_PULL_PAYLOAD.zip','RESULT.json') @($manifest.files.path)).Count-eq0)'S18B2 manifest file set changed.'
foreach($record in @($manifest.files)){$recordBytes=if([string]$record.path-eq'DATA_PULL_PAYLOAD.zip'){$payloadBytes}else{$resultBytes};Assert-ExactCondition(@($recordBytes).Count-eq[int64]$record.bytes -and (Get-ExactBytesSha256 ([byte[]]$recordBytes))-eq[string]$record.sha256)"S18B2 declared response file changed: $($record.path)"}
$certificate=New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try{$signatureValid=$rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
Assert-ExactCondition($signatureValid -and $certificate.Thumbprint-eq'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC')'S18B2 response signature failed.'
$bfEntry='data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot18/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$dfEntry='data/JBOD_PROCESSOR_REVIEW/identity/proposals/62619-433_20260824005735_Slot18/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$memory=New-Object IO.MemoryStream(,([byte[]]$payloadBytes))
$inner=New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
try{$innerNames=@($inner.Entries|ForEach-Object{$_.FullName});Assert-ExactCondition($innerNames.Count-eq2 -and @(Compare-Object @($bfEntry,$dfEntry) $innerNames).Count-eq0)'S18B2 nested payload entry set changed.';$bfBytes=Read-ExactZipEntryBytes $inner $bfEntry 4194304;$dfBytes=Read-ExactZipEntryBytes $inner $dfEntry 4194304}finally{$inner.Dispose();$memory.Dispose()}
Assert-ExactCondition([string]$result.schema-eq'argos_project_portal_data_pull_result_v2' -and [string]$result.state-eq'PASS_DATA_PULL' -and [string]$result.approvedRoot-eq'JBOD_PROCESSOR_REVIEW' -and [string]$result.containerSha256-eq(Get-ExactBytesSha256 $payloadBytes) -and @($result.files).Count-eq2)'S18B2 DATA_PULL result changed.'
$bfSha256=Get-ExactBytesSha256 $bfBytes
$dfSha256=Get-ExactBytesSha256 $dfBytes
foreach($row in @($result.files)){$expectedHash=if([string]$row.entryPath-eq$bfEntry){$bfSha256}elseif([string]$row.entryPath-eq$dfEntry){$dfSha256}else{throw "S18B2 unexpected result path: $($row.entryPath)"};Assert-ExactCondition([string]$row.sha256-eq$expectedHash)"S18B2 result hash changed: $($row.entryPath)"}
[ordered]@{schema='argos_s18b2_response_inspection_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S18B2_MATCHING_SIGNED_ORIENTED_INPUT_RESPONSE';requestId=$ExpectedRequestId;responseId=[string]$manifest.responseId;endpointState=[string]$manifest.state;sourceZip=$sourceZip;sourceZipBytes=[int64](Get-Item -LiteralPath $sourceZip).Length;sourceZipSha256=(Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash;manifestSha256=(Get-ExactBytesSha256 $manifestBytes);resultSha256=(Get-ExactBytesSha256 $resultBytes);payloadSha256=(Get-ExactBytesSha256 $payloadBytes);bfEntry=$bfEntry;bfBytes=@($bfBytes).Count;bfSha256=$bfSha256;dfEntry=$dfEntry;dfBytes=@($dfBytes).Count;dfSha256=$dfSha256;signedResponseVerified=$true;imageBytesRead=$true;pixelsDecoded=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 12
