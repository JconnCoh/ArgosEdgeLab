#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Collect)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'R18W2 collector requires Windows PowerShell 5.1 exactly.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-ByteSha256([byte[]]$Bytes) { $sha = [Security.Cryptography.SHA256]::Create(); try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') } finally { $sha.Dispose() } }
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\','/'), $Name, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [int64]$matches[0].Length -le $MaximumBytes) "Missing, duplicated, or oversized ZIP entry: $Name"
    $input = $matches[0].Open(); $memory = New-Object IO.MemoryStream
    try { $input.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $input.Dispose() }
}
function Write-BytesCreateNew([string]$Path, [byte[]]$Bytes) { $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None); try { $stream.Write($Bytes,0,$Bytes.Length) } finally { $stream.Dispose() } }
function Write-JsonCreateNew([string]$Path, [object]$Value) { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine)); Write-BytesCreateNew $Path $bytes }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18W2'; $responseId = 'R_FADCA24C1D79_20260905191141560_093c0c66'
$responseRoot = 'U:\ProjectPortalRO\responses'; $source = $responseRoot + '\' + $responseId + '.ready.zip'
$expectedOuterSha = '18B4F8EED464DF4D0ADBC1345F7C2AB753B6F9ADDB18538D8955B8A5180F9F8E'
$expectedSigner = 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC'
$publishGatePath = Join-Path $PSScriptRoot 'R18W2_PUBLISH_GATE.json'
$scopePath = Join-Path $PSScriptRoot 'R18W2_CROSSWALK_SCOPE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W2_COMPLETE_ROUTE_GATE.json'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$responseTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$outerRoot = 'C:\R18W2R'; $payloadRoot = 'C:\R18W2D'
$metadataRoot = Join-Path $PSScriptRoot 'collected_response_metadata'; $overlayRoot = Join-Path $PSScriptRoot 'collected_overlay'
$terminalGatePath = Join-Path $PSScriptRoot 'R18W2_TERMINAL_RESPONSE_GATE.json'; $crosswalkPath = Join-Path $PSScriptRoot 'R18W2_EXACT_OVERLAY_CROSSWALK.json'

Require ((Get-Sha256 $publishGatePath) -eq '36ED33ED38B4AEA79032A4DDAE5E1CA80277049A3314ED6B99387DF80B5BBE6E') 'R18W2 publish gate changed.'
Require ((Get-Sha256 $scopePath) -eq '0A6CF71F00AB4CA895E61A14A55933CD2EB6D86C91388B0CA8DD66CEDA3E6AF3') 'R18W2 scope changed.'
Require ((Get-Sha256 $routeGatePath) -eq '5359058FE1CDB9ACBA11DFBE0317B208B063E5FF1F3BB496C81E565D6AF093B5') 'R18W2 route gate changed.'
Require ((Get-Sha256 $endpointCertificate) -eq '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B') 'JBOD response certificate changed.'
Require ((Get-Sha256 $responseTester) -eq '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C') 'Response verifier changed.'
Require (Test-Path -LiteralPath $source -PathType Leaf) 'Exact R18W2 response is absent.'
Require ([int64](Get-Item -LiteralPath $source).Length -eq 33334 -and (Get-Sha256 $source) -eq $expectedOuterSha) 'Exact R18W2 response ZIP changed.'

Add-Type -AssemblyName System.IO.Compression; Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($source)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    Require ($names.Count -eq 4 -and @(Compare-Object -ReferenceObject @('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') -DifferenceObject $names).Count -eq 0) 'R18W2 outer member set changed.'
    $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_RESPONSE_MANIFEST.sig' 8192
    $resultBytes = Read-ZipEntryBytes $zip 'RESULT.json' 1048576
    $payloadBytes = Read-ZipEntryBytes $zip 'DATA_PULL_PAYLOAD.zip' 16777216
} finally { $zip.Dispose() }
$manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
$result = (New-Object Text.UTF8Encoding($false,$true)).GetString($resultBytes) | ConvertFrom-Json
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($endpointCertificate); $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ($signatureValid -and $certificate.Thumbprint.ToUpperInvariant() -eq $expectedSigner) 'R18W2 response signature failed.'
Require ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_DATA_PULL') 'R18W2 response identity/state changed.'
Require (([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $expectedSigner -and [bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18W2 response authority widened.'
$payloadSha = Get-ByteSha256 $payloadBytes
Require ([string]$result.schema -eq 'argos_project_portal_data_pull_result_v2' -and [string]$result.state -eq 'PASS_DATA_PULL' -and [string]$result.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [string]$result.container -eq 'DATA_PULL_PAYLOAD.zip' -and [string]$result.containerSha256 -eq $payloadSha -and [int64]$result.containerBytes -eq $payloadBytes.Length) 'R18W2 result/container changed.'
$files = @($result.files); $relative = 'identity/confirmed/ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json'; $entryPath = 'data/JBOD_PROCESSOR_REVIEW/' + $relative
Require ($files.Count -eq 1 -and [string]$files[0].relativePath -eq $relative -and [string]$files[0].entryPath -eq $entryPath -and [int64]$result.totalSourceBytes -le 16777216) 'R18W2 returned file set changed.'
$payloadMemory = New-Object IO.MemoryStream(,$payloadBytes); $payloadZip = New-Object IO.Compression.ZipArchive($payloadMemory,[IO.Compression.ZipArchiveMode]::Read,$false)
try {
    Require (@($payloadZip.Entries).Count -eq 1) 'R18W2 payload membership changed.'
    $overlayBytes = Read-ZipEntryBytes $payloadZip $entryPath 16777216
} finally { $payloadZip.Dispose(); $payloadMemory.Dispose() }
$overlaySha = Get-ByteSha256 $overlayBytes
Require ($overlayBytes.Length -eq [int64]$files[0].bytes -and $overlaySha -eq [string]$files[0].sha256) 'R18W2 overlay bytes changed.'
$overlay = (New-Object Text.UTF8Encoding($false,$true)).GetString($overlayBytes) | ConvertFrom-Json
Require ([string]$overlay.schema -eq 'argos_confirmed_scribe_overlay_v1' -and @($overlay.rows).Count -eq 814 -and [bool]$overlay.reviewOnly -and -not [bool]$overlay.trainingEligible -and -not [bool]$overlay.xmlEligible -and -not [bool]$overlay.productionEligible) 'R18W2 overlay contract changed.'

$scope = Get-Content -LiteralPath $scopePath -Raw | ConvertFrom-Json; $crosswalkRows = @()
foreach ($member in @($scope.members)) {
    $hits = @($overlay.rows | Where-Object { [string]$_.scribe -ceq [string]$member.scribe -and ([string]$_.acquisitionKey).Split('_')[0] -ceq [string]$member.queryLot })
    $state = if ($hits.Count -eq 1) { 'EXACT_CURRENT_OVERLAY_MATCH' } elseif ($hits.Count -eq 0) { 'HOLD_UNMATCHED_CURRENT_OVERLAY' } else { 'HOLD_MULTIPLE_EXACT_CURRENT_OVERLAY_MATCHES' }
    $crosswalkRows += [ordered]@{character=[string]$member.character;queryLot=[string]$member.queryLot;unitContainer=[string]$member.unitContainer;scribe=[string]$member.scribe;state=$state;exactMatchCount=$hits.Count;acquisitionKeys=@($hits | ForEach-Object { [string]$_.acquisitionKey })}
}
$resolved = @($crosswalkRows | Where-Object { $_.state -eq 'EXACT_CURRENT_OVERLAY_MATCH' }).Count; $unmatched = @($crosswalkRows | Where-Object { $_.state -eq 'HOLD_UNMATCHED_CURRENT_OVERLAY' }).Count; $multiple = @($crosswalkRows | Where-Object { $_.state -eq 'HOLD_MULTIPLE_EXACT_CURRENT_OVERLAY_MATCHES' }).Count
$crosswalk = [ordered]@{schema='argos_opencv_scribe_r18w2_exact_overlay_crosswalk_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='USABLE_WITH_HOLDS';classification='DIAGNOSTIC_ONLY';requestId=$requestId;responseId=$responseId;overlayBytes=$overlayBytes.Length;overlaySha256=$overlaySha;scopeMembers=$crosswalkRows.Count;resolvedExact=$resolved;unmatched=$unmatched;multiple=$multiple;joinFields=@('queryLot','unitContainer','scribe');acquisitionKeyInferenceAllowed=$false;unitSuffixToSlotConversionAllowed=$false;lotPrefixMatchAllowed=$false;unmatchedOrMultipleRemainHold=$true;rows=$crosswalkRows;identityAccepted=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
$gate = [ordered]@{schema='argos_opencv_scribe_r18w2_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($Preflight){'PASS_R18W2_RESPONSE_COLLECTION_PREFLIGHT'}else{'PASS_R18W2_SIGNED_CURRENT_OVERLAY_COLLECTED'});disposition='DIAGNOSTIC_ONLY';requestId=$requestId;responseId=$responseId;endpointState='PASS_DATA_PULL';signedResponseVerified=$true;signerThumbprint=$expectedSigner;sourceZip=$source;sourceZipBytes=33334;sourceZipSha256=$expectedOuterSha;responseManifestSha256=(Get-ByteSha256 $manifestBytes);responseSignatureSha256=(Get-ByteSha256 $signatureBytes);resultSha256=(Get-ByteSha256 $resultBytes);payloadSha256=$payloadSha;returnedFileCount=1;overlayBytes=$overlayBytes.Length;overlaySha256=$overlaySha;overlayRows=@($overlay.rows).Count;crosswalkResolved=$resolved;crosswalkUnmatched=$unmatched;crosswalkMultiple=$multiple;requestRetried=$false;taskOrProcessActionPerformed=$false;sourceMutationPerformed=$false;imageBytesRead=$false;identityAccepted=$false;r18w3PublicationAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mutationsPerformed=$false}
if ($Preflight) { [ordered]@{gate=$gate;crosswalk=$crosswalk} | ConvertTo-Json -Depth 32; return }

foreach ($path in @($outerRoot,$payloadRoot,$metadataRoot,$overlayRoot,$terminalGatePath,$crosswalkPath)) { Require (-not (Test-Path -LiteralPath $path)) "Fresh R18W2 collection output exists: $path" }
[IO.Compression.ZipFile]::ExtractToDirectory($source,$outerRoot)
$verified = & $responseTester -PackagePath $outerRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Require ([string]$verified.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verified.EndpointState -eq 'PASS_DATA_PULL') 'Extracted R18W2 response verification failed.'
[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $outerRoot 'DATA_PULL_PAYLOAD.zip'),$payloadRoot)
$diskOverlay = Join-Path $payloadRoot $entryPath.Replace('/','\')
Require ((Get-Sha256 $diskOverlay) -eq $overlaySha -and [int64](Get-Item -LiteralPath $diskOverlay).Length -eq $overlayBytes.Length) 'Extracted R18W2 overlay changed.'
[void](New-Item -ItemType Directory -Path $metadataRoot); [void](New-Item -ItemType Directory -Path $overlayRoot)
Write-BytesCreateNew (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.json') $manifestBytes
Write-BytesCreateNew (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.sig') $signatureBytes
Write-BytesCreateNew (Join-Path $metadataRoot 'RESULT.json') $resultBytes
Write-BytesCreateNew (Join-Path $overlayRoot 'ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json') $overlayBytes
Write-JsonCreateNew $crosswalkPath $crosswalk
$gate.mutationsPerformed = $true; Write-JsonCreateNew $terminalGatePath $gate
$gate | ConvertTo-Json -Depth 32
