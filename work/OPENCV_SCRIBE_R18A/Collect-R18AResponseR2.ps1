#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Collect)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T171128612Z_R18A'
$expectedResponseId = 'R_84B9CB78722E_20260903172040421_2b8e31ed'
$expectedResponseZipSha256 = 'CBA4E0A078D867BD13FD77F49628B32F83B72FC203BC6C302C39D33352600F7B'
$definitionPath = Join-Path $PSScriptRoot 'R18A_DATA_PULL_DEFINITION.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18A_ONE_TIME_PUBLICATION.json'
$publishGatePath = Join-Path $PSScriptRoot 'R18A_PUBLISH_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18A_COMPLETE_ROUTE_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$responseTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$responseRoot = 'U:\ProjectPortalRO\responses'
$outerExtractRoot = 'C:\R18A2R'
$payloadExtractRoot = 'C:\R18A2'
$metadataRoot = Join-Path $PSScriptRoot 'collected_metadata_r2'
$terminalGatePath = Join-Path $PSScriptRoot 'R18A_TERMINAL_RESPONSE_GATE_R2.json'
$definitionSha256 = '46DC41477138D078E4A93A5CBE452B1753B83ACBA6FDF5A02CF747E5A228BEDA'
$preactionSha256 = 'BD80A13C187DC5F7811F0640B021ADB3428D4D68A475C641157E3647175FC9C1'
$publishGateSha256 = '288CA976B1F6A743ADB0F7A73765C695CC33597BB3D839BC2359A37CAEBFC954'
$expectedSignerThumbprint = 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-ByteSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') } finally { $sha.Dispose() }
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $entry = $Zip.GetEntry($Name)
    Assert-True ($null -ne $entry -and [int64]$entry.Length -le $MaximumBytes) "Missing or oversized response entry: $Name"
    $input = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try { $input.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $input.Dispose() }
}
function Write-BytesCreateNew([string]$Path, [byte[]]$Bytes) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine))
    Write-BytesCreateNew -Path $Path -Bytes $bytes
}

Assert-True ((Get-Sha256 $definitionPath) -eq $definitionSha256) 'R18A definition changed.'
Assert-True ((Get-Sha256 $preactionPath) -eq $preactionSha256) 'R18A preaction changed.'
Assert-True ((Get-Sha256 $publishGatePath) -eq $publishGateSha256) 'R18A publish gate changed.'
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
Assert-True (Test-Path -LiteralPath $publishGatePath -PathType Leaf) 'R18A has not been published.'
Assert-True (Test-Path -LiteralPath $routeGatePath -PathType Leaf) 'R18A route gate is missing.'
$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$publishGate.state -eq 'PASS_R18A_EXACT_SIGNED_DATA_PULL_PUBLISHED_CREATE_NEW' -and [string]$publishGate.requestId -eq $requestId -and -not [bool]$publishGate.retryAuthorized) 'R18A publication evidence changed.'
Assert-True ([string]$routeGate.state -eq 'PASS_R18A_COMPLETE_ROUTE_GATE' -and [int]$routeGate.maximumEffectiveLength -lt 200) 'R18A route gate changed.'
Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'Portal response share is unavailable.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.IO.Compression
$responseFiles = @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 500)
$matches = New-Object Collections.Generic.List[object]
foreach ($candidate in $responseFiles) {
    try {
        $candidateZip = [IO.Compression.ZipFile]::OpenRead($candidate.FullName)
        try {
            $candidateManifestEntry = $candidateZip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
            if ($null -eq $candidateManifestEntry -or [int64]$candidateManifestEntry.Length -gt 1048576) { continue }
            $candidateBytes = Read-ZipEntryBytes -Zip $candidateZip -Name 'PORTAL_RESPONSE_MANIFEST.json' -MaximumBytes 1048576
            $candidateManifest = [Text.Encoding]::UTF8.GetString($candidateBytes) | ConvertFrom-Json
            if ([string]$candidateManifest.requestId -eq $requestId) { $matches.Add([pscustomobject]@{file=$candidate;manifest=$candidateManifest}) }
        } finally { $candidateZip.Dispose() }
    } catch { continue }
}
Assert-True ($matches.Count -le 1) 'Multiple terminal responses match R18A.'
if ($matches.Count -eq 0) {
    if ($Collect) { throw 'No matching signed terminal response exists yet.' }
    [ordered]@{schema='argos_r18a_response_collection_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='WAIT_R18A_MATCHING_RESPONSE';requestId=$requestId;responseFilesScanned=$responseFiles.Count;matchingResponses=0;mutationsPerformed=$false;requestRetried=$false;pixelsDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$source = [string]$matches[0].file.FullName
$sourceZipBytes = [int64]$matches[0].file.Length
Assert-True ($sourceZipBytes -le 50331648) 'R18A response ZIP exceeds the signed bound.'
$sourceZipSha256 = Get-Sha256 $source
Assert-True ([string]$matches[0].manifest.responseId -eq $expectedResponseId -and $sourceZipSha256 -eq $expectedResponseZipSha256) 'R18A exact response identity or ZIP changed.'
$zip = [IO.Compression.ZipFile]::OpenRead($source)
try {
    $names = @($zip.Entries | ForEach-Object { $_.FullName })
    Assert-True ($names.Count -eq 4 -and @(Compare-Object -ReferenceObject @('DATA_PULL_PAYLOAD.zip','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') -DifferenceObject $names).Count -eq 0) 'R18A response entry set changed.'
    $manifestBytes = Read-ZipEntryBytes -Zip $zip -Name 'PORTAL_RESPONSE_MANIFEST.json' -MaximumBytes 1048576
    $signatureBytes = Read-ZipEntryBytes -Zip $zip -Name 'PORTAL_RESPONSE_MANIFEST.sig' -MaximumBytes 4096
    $resultBytes = Read-ZipEntryBytes -Zip $zip -Name 'RESULT.json' -MaximumBytes 1048576
    $payloadBytes = Read-ZipEntryBytes -Zip $zip -Name 'DATA_PULL_PAYLOAD.zip' -MaximumBytes 50331648
} finally { $zip.Dispose() }
$manifest = [Text.Encoding]::UTF8.GetString($manifestBytes) | ConvertFrom-Json
$result = [Text.Encoding]::UTF8.GetString($resultBytes) | ConvertFrom-Json
$responseId = [string]$manifest.responseId
$payloadSha256 = Get-ByteSha256 $payloadBytes
Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_DATA_PULL') 'R18A response manifest state changed.'
Assert-True (([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $expectedSignerThumbprint -and [bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled) 'R18A response authority flags changed.'
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($endpointCertificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Assert-True ($signatureValid -and $certificate.Thumbprint.ToUpperInvariant() -eq $expectedSignerThumbprint) 'R18A response signature failed.'

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$expectedRelativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ } | Sort-Object)
$resultFiles = @($result.files)
$observedRelativePaths = @($resultFiles | ForEach-Object { [string]$_.relativePath } | Sort-Object)
$observedEntryPaths = @($resultFiles | ForEach-Object { [string]$_.entryPath } | Sort-Object)
$expectedEntryPaths = @($expectedRelativePaths | ForEach-Object { 'data/JBOD_PROCESSOR_REVIEW/' + $_ } | Sort-Object)
Assert-True ([string]$result.schema -eq 'argos_project_portal_data_pull_result_v2' -and [string]$result.state -eq 'PASS_DATA_PULL' -and [string]$result.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R18A DATA_PULL result changed.'
Assert-True ([string]$result.container -eq 'DATA_PULL_PAYLOAD.zip' -and [string]$result.containerSha256 -eq $payloadSha256 -and [int64]$result.containerBytes -eq $payloadBytes.Length) 'R18A payload container pin changed.'
Assert-True ($resultFiles.Count -eq 24 -and @(Compare-Object -ReferenceObject $expectedRelativePaths -DifferenceObject $observedRelativePaths).Count -eq 0 -and @(Compare-Object -ReferenceObject $expectedEntryPaths -DifferenceObject $observedEntryPaths).Count -eq 0) 'R18A exact returned file set changed.'
Assert-True ([int64]$result.totalSourceBytes -le 50331648 -and [bool]$result.sourcePathsPreservedAsZipEntries -and [bool]$result.filesystemReturnPathsFlattened) 'R18A returned path/byte contract changed.'

$payloadMemory = New-Object IO.MemoryStream(,$payloadBytes)
$payloadZip = New-Object IO.Compression.ZipArchive($payloadMemory, [IO.Compression.ZipArchiveMode]::Read, $false)
try {
    $payloadNames = @($payloadZip.Entries | ForEach-Object { $_.FullName } | Sort-Object)
    Assert-True ($payloadNames.Count -eq 24 -and @(Compare-Object -ReferenceObject $expectedEntryPaths -DifferenceObject $payloadNames).Count -eq 0) 'R18A payload member set changed.'
    foreach ($row in $resultFiles) {
        $entry = $payloadZip.GetEntry([string]$row.entryPath)
        Assert-True ($null -ne $entry -and [int64]$entry.Length -eq [int64]$row.bytes) "R18A payload size mismatch: $($row.entryPath)"
        $entryStream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $entrySha256 = ([BitConverter]::ToString($sha.ComputeHash($entryStream))).Replace('-', '') } finally { $sha.Dispose(); $entryStream.Dispose() }
        Assert-True ($entrySha256 -eq [string]$row.sha256) "R18A payload hash mismatch: $($row.entryPath)"
    }
} finally { $payloadZip.Dispose(); $payloadMemory.Dispose() }

$gate = [ordered]@{schema='argos_r18a_terminal_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18A_SIGNED_FRESH_LOT_EXISTING_CROPS_COLLECTED';disposition='APPROVED_BASELINE';requestId=$requestId;responseId=$responseId;endpointState='PASS_DATA_PULL';signedResponseVerified=$true;signerThumbprint=$expectedSignerThumbprint;sourceZip=$source;sourceZipBytes=$sourceZipBytes;sourceZipSha256=$sourceZipSha256;responseManifestSha256=(Get-ByteSha256 $manifestBytes);responseSignatureSha256=(Get-ByteSha256 $signatureBytes);resultSha256=(Get-ByteSha256 $resultBytes);payloadSha256=$payloadSha256;returnedFileCount=24;proposalFileCount=8;imageFileCount=16;totalSourceBytes=[int64]$result.totalSourceBytes;files=$resultFiles;outerExtractionRoot=$outerExtractRoot;payloadExtractionRoot=$payloadExtractRoot;developmentAcquisitions=4;blindValidationAcquisitions=4;blindValidationPixelsInspected=$false;pixelsDecodedDuringCollection=$false;requestRetried=$false;taskOrProcessActionPerformed=$false;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
if ($Preflight) {
    $gate.state = 'PASS_R18A_RESPONSE_COLLECTION_PREFLIGHT'
    $gate.mutationsPerformed = $false
    $gate | ConvertTo-Json -Depth 32
    return
}

foreach ($path in @($outerExtractRoot, $payloadExtractRoot, $metadataRoot, $terminalGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R18A fresh collection output exists: $path" }
[IO.Compression.ZipFile]::ExtractToDirectory($source, $outerExtractRoot)
$responseTest = & $responseTester -PackagePath $outerExtractRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$responseTest.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$responseTest.EndpointState -eq 'PASS_DATA_PULL') 'R18A extracted signed response verification failed.'
[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $outerExtractRoot 'DATA_PULL_PAYLOAD.zip'), $payloadExtractRoot)
$diskFiles = @(Get-ChildItem -LiteralPath $payloadExtractRoot -Recurse -File)
Assert-True ($diskFiles.Count -eq 24) 'R18A extracted payload count changed.'
foreach ($row in $resultFiles) {
    $diskPath = Join-Path $payloadExtractRoot ([string]$row.entryPath).Replace('/', '\')
    Assert-True (Test-Path -LiteralPath $diskPath -PathType Leaf) "R18A extracted file missing: $($row.entryPath)"
    Assert-True ([int64](Get-Item -LiteralPath $diskPath).Length -eq [int64]$row.bytes -and (Get-Sha256 $diskPath) -eq [string]$row.sha256) "R18A extracted file changed: $($row.entryPath)"
}
[void](New-Item -ItemType Directory -Path $metadataRoot)
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.json') -Bytes $manifestBytes
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.sig') -Bytes $signatureBytes
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'RESULT.json') -Bytes $resultBytes
Write-JsonCreateNew -Path $terminalGatePath -Value $gate
$gate | ConvertTo-Json -Depth 32
