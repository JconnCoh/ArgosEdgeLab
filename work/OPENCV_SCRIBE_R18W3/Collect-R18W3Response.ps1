#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Collect)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'R18W3 collector requires Windows PowerShell 5.1 exactly.' }

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
$requestId = 'REQ_R18W3'; $responseId = 'R_EB5FC8126975_20260905194132964_5d52a580'; $branch = 'codex/opencv-scribe-deciphering'; $requiredTip = 'bb5769b2ea70ebabef44e1abc68f55b11118a484'
$responseRoot = 'U:\ProjectPortalRO\responses'; $source = $responseRoot + '\' + $responseId + '.ready.zip'
$expectedOuterBytes = 28029870; $expectedOuterSha = '1F7EF72AA6F035510CF13A634FA9F694A3EA3414380EF832096E7F2F1B7693DF'
$expectedManifestSha = 'DAFFB9EE8844ADE24CFD5DFCF8836A550AAAE69C5B54C821C0C6103E45AC6799'
$expectedSignatureSha = '6F10213DC16A1EE327A4DAB00EA5093ECB2A30CD0F9B40D680980E42D8529F3E'
$expectedResultSha = 'E2CAEC97E1E7A8C1B2846980BB2990C47A8D6B23007E4662E156ADBDF74DDB35'
$expectedPayloadBytes = 28036009; $expectedPayloadSha = 'F9C88A59EE8411D922732F114E7742DD58E4D21D6616CD8EE2FCBC76F6230E6E'
$expectedSigner = 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC'
$publishGatePath = Join-Path $PSScriptRoot 'R18W3_PUBLISH_GATE.json'
$publicationToolingGatePath = Join-Path $PSScriptRoot 'R18W3_PUBLICATION_TOOLING_GATE.json'
$definitionPath = Join-Path $PSScriptRoot 'R18W3_DATA_PULL_DEFINITION.json'
$selectionPath = Join-Path $PSScriptRoot 'R18W3_SELECTION.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W3_COMPLETE_ROUTE_GATE.json'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$responseTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$outerRoot = 'C:\R18W3R'; $payloadRoot = 'C:\R18W3'
$metadataRoot = Join-Path $PSScriptRoot 'collected_response_metadata'
$terminalGatePath = Join-Path $PSScriptRoot 'R18W3_TERMINAL_RESPONSE_GATE.json'
$inventoryPath = Join-Path $PSScriptRoot 'R18W3_RETURNED_FILE_INVENTORY.json'

Require ((Get-Sha256 $publishGatePath) -eq '9B46E7BA5447B1931AFD65A27ABBD5223FEFCC79D765550422EE4F611E5DB3CA') 'R18W3 publish gate changed.'
Require ((Get-Sha256 $publicationToolingGatePath) -eq '30BD80C564F3E90E3FE401E9C71FF234E31F2DB991977808F8D12FC293C330DB') 'R18W3 publication tooling gate changed.'
Require ((Get-Sha256 $definitionPath) -eq '5D7A8B30462AED9B29CE1C94BB5559305283E5D1E694DF1D22BE9723A0747372') 'R18W3 definition changed.'
Require ((Get-Sha256 $selectionPath) -eq '48795396398ED73F73C87509803FC1B647389872CDDC5F31B532995906181D7E') 'R18W3 selection changed.'
Require ((Get-Sha256 $routeGatePath) -eq 'EF3601249B470A7B50DEC85F380855BE6444E72731D0D9CF5FB1DA5F24895931') 'R18W3 route gate changed.'
Require ((Get-Sha256 $endpointCertificate) -eq '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B') 'JBOD response certificate changed.'
Require ((Get-Sha256 $responseTester) -eq '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C') 'Response verifier changed.'

$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$selection = Get-Content -LiteralPath $selectionPath -Raw | ConvertFrom-Json
Require ([string]$publishGate.state -eq 'PASS_R18W3_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW' -and [string]$publishGate.requestId -eq $requestId -and [string]$publishGate.sha256 -eq '41113CE44CFB56D64EC2253D475CDD764EC84D759B5F360BE81D6CD325DCCCD6' -and [int]$publishGate.maximumPublicationsAuthorized -eq 1 -and -not [bool]$publishGate.retryAuthorized) 'R18W3 publication boundary changed.'
Require ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [int]$definition.parameters.maximumFiles -eq 24 -and [int64]$definition.parameters.maximumBytes -eq 50331648 -and @($definition.parameters.relativePaths).Count -eq 24) 'R18W3 definition scope changed.'
Require ([string]$selection.state -eq 'PASS_R18W3_CORRECTED_EIGHT_SELECTION_VALIDATED' -and [int]$selection.selectedCount -eq 8 -and @($selection.selected).Count -eq 8 -and -not [bool]$selection.partitionBoundary.reservedValidationIncluded -and -not [bool]$selection.partitionBoundary.sameTruthPostAcquisitionIncluded -and -not [bool]$selection.partitionBoundary.localOnlyPackageExcludedIncluded) 'R18W3 selection boundary changed.'
$publishTime = [DateTimeOffset]::Parse([string]$publishGate.publishedUtc)

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim(); $localTip = (& git -C $project rev-parse HEAD | Out-String).Trim(); $remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim(); $status = @(& git -C $project status --porcelain=v1 --untracked-files=all)
Require ($currentBranch -eq $branch -and $localTip -eq $requiredTip -and $remoteTip -eq $requiredTip) 'R18W3 collection requires the pinned dedicated branch and matching recorded origin.'
$allowedLocal = @('?? work/OPENCV_SCRIBE_R18W3/Collect-R18W3Response.ps1','?? work/OPENCV_SCRIBE_R18W3/PREACTION_R18W3_PUBLICATION.json','?? work/OPENCV_SCRIBE_R18W3/Publish-R18W3.ps1','?? work/OPENCV_SCRIBE_R18W3/R18W3_COLLECTION_CLONE_LITERAL_GATE.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_COLLECTION_CLONE_LITERAL_GATE_V2.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_COLLECTION_CLONE_LITERAL_GATE_V3.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_COLLECTION_CLONE_LITERAL_REMEDIATION.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_COLLECTION_TOOLING_GATE.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_AUTHORITY.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_CLONE_LITERAL_GATE.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_CLONE_LITERAL_REMEDIATION.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLICATION_TOOLING_GATE.json','?? work/OPENCV_SCRIBE_R18W3/R18W3_PUBLISH_GATE.json')
Require (@($status | Where-Object { $_ -notin $allowedLocal }).Count -eq 0) 'R18W3 collection found unrelated worktree changes.'

Add-Type -AssemblyName System.IO.Compression; Add-Type -AssemblyName System.IO.Compression.FileSystem
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($endpointCertificate)
$responseFiles = @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop)
Require ($responseFiles.Count -le 1024) 'R18W3 response archive exceeds corrected bounded uniqueness scan.'
$archiveMatches = @()
foreach ($responseFile in $responseFiles) {
    $candidateZip = $null; $candidateManifestBytes = $null; $candidateSignatureBytes = $null; $candidateManifest = $null
    try {
        $candidateZip = [IO.Compression.ZipFile]::OpenRead($responseFile.FullName)
        $manifestEntries = @($candidateZip.Entries | Where-Object { [string]$_.FullName -eq 'PORTAL_RESPONSE_MANIFEST.json' })
        if ($manifestEntries.Count -ne 1 -or [int64]$manifestEntries[0].Length -gt 1048576) { continue }
        $candidateManifestBytes = Read-ZipEntryBytes $candidateZip 'PORTAL_RESPONSE_MANIFEST.json' 1048576
        $candidateManifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($candidateManifestBytes) | ConvertFrom-Json
        if ([string]$candidateManifest.requestId -cne $requestId) { continue }
        $candidateSignatureBytes = Read-ZipEntryBytes $candidateZip 'PORTAL_RESPONSE_MANIFEST.sig' 8192
        $candidateRsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
        try { $candidateSignatureValid = $candidateRsa.VerifyData($candidateManifestBytes,$candidateSignatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $candidateRsa.Dispose() }
        Require ($candidateSignatureValid) "R18W3 archive contains an unauthenticated matching request response: $($responseFile.Name)"
        $archiveMatches += [pscustomobject]@{path=$responseFile.FullName;name=$responseFile.Name;responseId=[string]$candidateManifest.responseId;createdUtc=[string]$candidateManifest.createdUtc;lastWriteTimeUtc=$responseFile.LastWriteTimeUtc.ToString('o');sha256=(Get-Sha256 $responseFile.FullName)}
    } catch {
        if ($null -ne $candidateManifest -and [string]$candidateManifest.requestId -ceq $requestId) { throw }
    } finally {
        if ($null -ne $candidateZip) { $candidateZip.Dispose() }
    }
}
Require ($archiveMatches.Count -eq 1 -and [string]$archiveMatches[0].responseId -eq $responseId -and [string]$archiveMatches[0].name -eq ($responseId + '.ready.zip')) 'R18W3 response archive uniqueness or identity binding failed.'
Require (Test-Path -LiteralPath $source -PathType Leaf) 'Exact R18W3 response is absent.'
$sourceItem = Get-Item -LiteralPath $source
Require ([int64]$sourceItem.Length -eq $expectedOuterBytes -and (Get-Sha256 $source) -eq $expectedOuterSha) 'Exact R18W3 response ZIP changed.'

$zip = [IO.Compression.ZipFile]::OpenRead($source)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    Require ($names.Count -eq 4 -and @(Compare-Object -ReferenceObject @('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') -DifferenceObject $names).Count -eq 0) 'R18W3 outer member set changed.'
    $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_RESPONSE_MANIFEST.json' 1048576
    $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_RESPONSE_MANIFEST.sig' 8192
    $resultBytes = Read-ZipEntryBytes $zip 'RESULT.json' 1048576
    $payloadBytes = Read-ZipEntryBytes $zip 'DATA_PULL_PAYLOAD.zip' 50331648
} finally { $zip.Dispose() }
Require ((Get-ByteSha256 $manifestBytes) -eq $expectedManifestSha -and (Get-ByteSha256 $signatureBytes) -eq $expectedSignatureSha -and (Get-ByteSha256 $resultBytes) -eq $expectedResultSha -and $payloadBytes.Length -eq $expectedPayloadBytes -and (Get-ByteSha256 $payloadBytes) -eq $expectedPayloadSha) 'R18W3 frozen response member hashes changed.'
$manifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($manifestBytes) | ConvertFrom-Json
$result = (New-Object Text.UTF8Encoding($false,$true)).GetString($resultBytes) | ConvertFrom-Json
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Require ($signatureValid -and $certificate.Thumbprint.ToUpperInvariant() -eq $expectedSigner) 'R18W3 response signature failed.'
Require ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId -and $sourceItem.Name -eq ([string]$manifest.responseId + '.ready.zip') -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_DATA_PULL') 'R18W3 response identity/state changed.'
Require (([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $expectedSigner -and [string]$manifest.signatureAlgorithm -eq 'RSA-SHA256-PKCS1' -and [bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18W3 response authority widened.'
$responseCreated = [DateTimeOffset]::Parse([string]$manifest.createdUtc); $clockDeltaSeconds = ($responseCreated.UtcDateTime - $publishTime.UtcDateTime).TotalSeconds
Require ($clockDeltaSeconds -ge -30 -and $clockDeltaSeconds -le 600 -and $sourceItem.LastWriteTimeUtc -gt $publishTime.UtcDateTime) 'R18W3 response does not satisfy bounded signed-clock/share-write publication binding.'
$manifestFiles = @($manifest.files); $payloadManifestRows = @($manifestFiles | Where-Object { [string]$_.path -eq 'DATA_PULL_PAYLOAD.zip' }); $resultManifestRows = @($manifestFiles | Where-Object { [string]$_.path -eq 'RESULT.json' })
Require ($manifestFiles.Count -eq 2 -and $payloadManifestRows.Count -eq 1 -and $resultManifestRows.Count -eq 1 -and [int64]$payloadManifestRows[0].bytes -eq $payloadBytes.Length -and [string]$payloadManifestRows[0].sha256 -eq $expectedPayloadSha -and [int64]$resultManifestRows[0].bytes -eq $resultBytes.Length -and [string]$resultManifestRows[0].sha256 -eq $expectedResultSha) 'R18W3 response manifest file declarations changed.'
Require ([string]$result.schema -eq 'argos_project_portal_data_pull_result_v2' -and [string]$result.state -eq 'PASS_DATA_PULL' -and [string]$result.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [string]$result.container -eq 'DATA_PULL_PAYLOAD.zip' -and [string]$result.containerSha256 -eq $expectedPayloadSha -and [int64]$result.containerBytes -eq $payloadBytes.Length -and [int64]$result.totalSourceBytes -le 50331648) 'R18W3 result/container changed.'
$expectedPaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ }); $files = @($result.files)
Require ($files.Count -eq 24) 'R18W3 returned file count changed.'
$inventoryRows = @(); $payloadMemory = New-Object IO.MemoryStream(,$payloadBytes); $payloadZip = New-Object IO.Compression.ZipArchive($payloadMemory,[IO.Compression.ZipArchiveMode]::Read,$false)
try {
    $expectedEntryPaths = @($expectedPaths | ForEach-Object { 'data/JBOD_PROCESSOR_REVIEW/' + $_ })
    $payloadEntryNames = @($payloadZip.Entries | ForEach-Object { [string]$_.FullName })
    Require ($payloadEntryNames.Count -eq 24 -and @(Compare-Object -ReferenceObject $expectedEntryPaths -DifferenceObject $payloadEntryNames -SyncWindow 0).Count -eq 0) 'R18W3 payload membership or ordering changed.'
    foreach ($relative in $expectedPaths) {
        $rows = @($files | Where-Object { [string]$_.relativePath -ceq $relative })
        $entryPath = 'data/JBOD_PROCESSOR_REVIEW/' + $relative
        Require ($rows.Count -eq 1 -and [string]$rows[0].entryPath -ceq $entryPath) "R18W3 returned declaration changed: $relative"
        $fileBytes = Read-ZipEntryBytes $payloadZip $entryPath 50331648; $fileSha = Get-ByteSha256 $fileBytes
        Require ($fileBytes.Length -eq [int64]$rows[0].bytes -and $fileSha -eq [string]$rows[0].sha256) "R18W3 returned bytes changed: $relative"
        $kind = if ($relative.EndsWith('/SCRIBE_PROPOSAL.json',[StringComparison]::Ordinal)) { 'PROPOSAL_JSON' } elseif ($relative.EndsWith('/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',[StringComparison]::Ordinal)) { 'BF_ORIENTED_INPUT_PNG' } elseif ($relative.EndsWith('/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',[StringComparison]::Ordinal)) { 'DF_ORIENTED_INPUT_PNG' } else { 'UNEXPECTED' }
        Require ($kind -ne 'UNEXPECTED') "R18W3 returned file type changed: $relative"
        if ($kind -eq 'PROPOSAL_JSON') { $null = (New-Object Text.UTF8Encoding($false,$true)).GetString($fileBytes) | ConvertFrom-Json }
        $inventoryRows += [ordered]@{relativePath=$relative;entryPath=$entryPath;kind=$kind;bytes=$fileBytes.Length;sha256=$fileSha;extractedPath=(Join-Path $payloadRoot $entryPath.Replace('/','\'))}
    }
} finally { $payloadZip.Dispose(); $payloadMemory.Dispose() }
$proposalCount = @($inventoryRows | Where-Object { $_.kind -eq 'PROPOSAL_JSON' }).Count; $bfCount = @($inventoryRows | Where-Object { $_.kind -eq 'BF_ORIENTED_INPUT_PNG' }).Count; $dfCount = @($inventoryRows | Where-Object { $_.kind -eq 'DF_ORIENTED_INPUT_PNG' }).Count
$inventoryByteTotal = [int64]0; foreach ($inventoryRow in $inventoryRows) { $inventoryByteTotal += [int64]$inventoryRow.bytes }
Require ($proposalCount -eq 8 -and $bfCount -eq 8 -and $dfCount -eq 8 -and $inventoryByteTotal -eq [int64]$result.totalSourceBytes) 'R18W3 returned triad counts or byte total changed.'

$inventory = [ordered]@{schema='argos_opencv_scribe_r18w3_returned_file_inventory_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18W3_EXACT_24_FILE_HASH_INVENTORY';classification='DIAGNOSTIC_ONLY';requestId=$requestId;responseId=$responseId;approvedRoot='JBOD_PROCESSOR_REVIEW';returnedFileCount=24;proposalFiles=$proposalCount;bfOrientedInputPngFiles=$bfCount;dfOrientedInputPngFiles=$dfCount;totalSourceBytes=[int64]$result.totalSourceBytes;rows=$inventoryRows;opaqueImageFiles=16;imageBytesReadForHashVerification=$true;pixelsDecoded=$false;identityAccepted=$false;referenceAdmissionPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
$gate = [ordered]@{schema='argos_opencv_scribe_r18w3_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($Preflight){'PASS_R18W3_RESPONSE_COLLECTION_PREFLIGHT'}else{'PASS_R18W3_SIGNED_EIGHT_LINEAGE_DATA_PULL_COLLECTED'});disposition='DIAGNOSTIC_ONLY';requestId=$requestId;responseId=$responseId;endpointState='PASS_DATA_PULL';signedResponseVerified=$true;signerThumbprint=$expectedSigner;sourceZip=$source;sourceZipBytes=$expectedOuterBytes;sourceZipSha256=$expectedOuterSha;responseManifestSha256=$expectedManifestSha;responseSignatureSha256=$expectedSignatureSha;resultSha256=$expectedResultSha;payloadBytes=$payloadBytes.Length;payloadSha256=$expectedPayloadSha;returnedFileCount=24;proposalFiles=$proposalCount;bfOrientedInputPngFiles=$bfCount;dfOrientedInputPngFiles=$dfCount;totalSourceBytes=[int64]$result.totalSourceBytes;publicationUtc=[string]$publishGate.publishedUtc;responseCreatedUtc=[string]$manifest.createdUtc;signedClockDeltaSeconds=$clockDeltaSeconds;clockSkewAllowanceSeconds=30;responseShareCreationUtc=$sourceItem.CreationTimeUtc.ToString('o');responseShareLastWriteUtc=$sourceItem.LastWriteTimeUtc.ToString('o');shareLastWriteAfterPublication=$true;responseArchiveReadyZipCount=$responseFiles.Count;matchingAuthenticatedRequestIdResponseCount=$archiveMatches.Count;prepublicationStaticResponseArchiveCheckPerformed=$false;compensatingPostpublicationArchiveUniquenessPassed=$true;requestRetried=$false;taskOrProcessActionPerformed=$false;queueMutationPerformed=$false;sourceMutationPerformed=$false;opaqueImageFiles=16;imageBytesReadForHashVerification=$true;pixelsDecoded=$false;identityAccepted=$false;referenceAdmissionPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mutationsPerformed=$false}
if ($Preflight) { [ordered]@{gate=$gate;inventory=$inventory} | ConvertTo-Json -Depth 32; return }

foreach ($path in @($outerRoot,$payloadRoot,$metadataRoot,$terminalGatePath,$inventoryPath)) { Require (-not (Test-Path -LiteralPath $path)) "Fresh R18W3 collection output exists: $path" }
[IO.Compression.ZipFile]::ExtractToDirectory($source,$outerRoot)
$verified = & $responseTester -PackagePath $outerRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Require ([string]$verified.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verified.EndpointState -eq 'PASS_DATA_PULL') 'Extracted R18W3 response verification failed.'
[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $outerRoot 'DATA_PULL_PAYLOAD.zip'),$payloadRoot)
foreach ($row in $inventoryRows) { Require ((Get-Sha256 ([string]$row.extractedPath)) -eq [string]$row.sha256 -and [int64](Get-Item -LiteralPath ([string]$row.extractedPath)).Length -eq [int64]$row.bytes) "Extracted R18W3 file changed: $($row.relativePath)" }
[void](New-Item -ItemType Directory -Path $metadataRoot)
Write-BytesCreateNew (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.json') $manifestBytes
Write-BytesCreateNew (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.sig') $signatureBytes
Write-BytesCreateNew (Join-Path $metadataRoot 'RESULT.json') $resultBytes
Write-JsonCreateNew $inventoryPath $inventory
$gate.mutationsPerformed = $true; Write-JsonCreateNew $terminalGatePath $gate
$gate | ConvertTo-Json -Depth 32
