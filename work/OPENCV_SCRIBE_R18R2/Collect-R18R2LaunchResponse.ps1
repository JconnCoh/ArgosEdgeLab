#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Collect)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18R2'
$requestZipSha256 = 'E541EB7FCCD19A04BFE401D6FCFB70B7976C0F47E9F4F1AD8E1FCC1626EEF300'
$expectedResponseId = 'R_932D503BB922_20260904234107020_0a55ed37'
$expectedResponseZipSha256 = 'D310854F22538041C1E8D1318A70F2EA7B54D02C912000124A15C4FD83B4B6A5'
$expectedSignerThumbprint = 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$responseRoot = 'U:\ProjectPortalRO\responses'
$responsePath = Join-Path $responseRoot ($expectedResponseId + '.ready.zip')
$outerExtractRoot = 'C:\R18R2R'
$metadataRoot = Join-Path $PSScriptRoot 'collected_launch_response'
$terminalGatePath = Join-Path $PSScriptRoot 'R18R2_LAUNCH_RESPONSE_GATE.json'
$publishGatePath = Join-Path $PSScriptRoot 'R18R2_PUBLISH_GATE.json'
$toolingGatePath = Join-Path $PSScriptRoot 'R18R2_PUBLICATION_TOOLING_GATE.json'
$discoveryGatePath = Join-Path $PSScriptRoot 'R18R2_RESPONSE_DISCOVERY_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18R2_LAUNCH_RESPONSE_COLLECTION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$responseTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$publishGateSha256 = '41FEFC9846BFF325C1656B17C64F11835C3ECB9E92FEF063FB051706DAB32A29'
$toolingGateSha256 = 'B6BDA610F512F59EA09EF40AECC4D1A08EE21E76947F970B4E75AC0CDC3A6589'
$discoveryGateSha256 = 'B141669141DFF96AC06D07D666EC57A4B59D2146C6313A50F3A6AC9D2BAF9B9E'
$preactionSha256 = '5FAD63618FAA2E4E1FDCF7E3B3B34BFF838514F7569B8E3322ED6CD401E7E448'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-ByteSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') } finally { $sha.Dispose() }
}
function Assert-PinnedFile([string]$Path, [string]$ExpectedSha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $ExpectedSha256) "$Label hash changed: $Path"
}
function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\','/'), $Name, [StringComparison]::OrdinalIgnoreCase) })
    Assert-True ($matches.Count -eq 1 -and [int64]$matches[0].Length -le $MaximumBytes) "Missing, duplicated, or oversized response entry: $Name"
    $input = $matches[0].Open()
    $memory = New-Object IO.MemoryStream
    try { $input.CopyTo($memory); return ,([byte[]]$memory.ToArray()) } finally { $memory.Dispose(); $input.Dispose() }
}
function Write-BytesCreateNew([string]$Path, [byte[]]$Bytes) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($Bytes, 0, $Bytes.Length) } finally { $stream.Dispose() }
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine))
    Write-BytesCreateNew -Path $Path -Bytes $bytes
}

Assert-PinnedFile $publishGatePath $publishGateSha256 'R18R2 publish gate'
Assert-PinnedFile $toolingGatePath $toolingGateSha256 'R18R2 publication tooling gate'
Assert-PinnedFile $discoveryGatePath $discoveryGateSha256 'R18R2 response discovery gate'
Assert-PinnedFile $preactionPath $preactionSha256 'R18R2 response-collection preaction'
Assert-PinnedFile $endpointCertificate '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B' 'JBOD endpoint signer certificate'
Assert-PinnedFile $responseTester '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C' 'official signed-response verifier'
$preactionJson = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String)
Assert-True ([string](($preactionJson | ConvertFrom-Json).state) -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18R2 response-collection preaction changed.'

$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
$discoveryGate = Get-Content -LiteralPath $discoveryGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$publishGate.state -eq 'PASS_R18R2_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW' -and [string]$publishGate.requestId -eq $requestId -and [string]$publishGate.sha256 -eq $requestZipSha256 -and -not [bool]$publishGate.retryAuthorized) 'R18R2 publication evidence changed.'
Assert-True ([string]$discoveryGate.state -eq 'PASS_R18R2_MATCHING_RESPONSE_FOUND' -and [string]$discoveryGate.responseId -eq $expectedResponseId -and [string]$discoveryGate.responseZipSha256 -eq $expectedResponseZipSha256 -and [int]$discoveryGate.matchingResponseCount -eq 1) 'R18R2 response discovery evidence changed.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Assert-True ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18R2 persistent U mapping changed.'
Assert-PinnedFile $responsePath $expectedResponseZipSha256 'exact R18R2 response ZIP'
Assert-True ([int64](Get-Item -LiteralPath $responsePath).Length -eq 3005) 'R18R2 response ZIP byte count changed.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$responseFiles = @(Get-ChildItem -LiteralPath $responseRoot -File -Filter '*.ready.zip' -ErrorAction Stop | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 500)
$matching = New-Object Collections.Generic.List[string]
foreach ($candidate in $responseFiles) {
    try {
        $candidateZip = [IO.Compression.ZipFile]::OpenRead($candidate.FullName)
        try {
            $candidateManifestBytes = Read-ZipEntryBytes -Zip $candidateZip -Name 'PORTAL_RESPONSE_MANIFEST.json' -MaximumBytes 1048576
            $candidateManifest = (New-Object Text.UTF8Encoding($false,$true)).GetString($candidateManifestBytes) | ConvertFrom-Json
            if ([string]$candidateManifest.requestId -eq $requestId) { $matching.Add($candidate.FullName) }
        } finally { $candidateZip.Dispose() }
    } catch { continue }
}
Assert-True ($matching.Count -eq 1 -and [string]::Equals($matching[0], $responsePath, [StringComparison]::OrdinalIgnoreCase)) 'R18R2 must have exactly one matching response.'

$zip = [IO.Compression.ZipFile]::OpenRead($responsePath)
try {
    $names = @($zip.Entries | ForEach-Object { ([string]$_.FullName).Replace('\','/') } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq 5 -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'R18R2 response entry set changed.'
    $manifestBytes = Read-ZipEntryBytes -Zip $zip -Name 'PORTAL_RESPONSE_MANIFEST.json' -MaximumBytes 1048576
    $signatureBytes = Read-ZipEntryBytes -Zip $zip -Name 'PORTAL_RESPONSE_MANIFEST.sig' -MaximumBytes 8192
    $resultBytes = Read-ZipEntryBytes -Zip $zip -Name 'RESULT.json' -MaximumBytes 1048576
    $stdoutBytes = Read-ZipEntryBytes -Zip $zip -Name 'MAINTENANCE.stdout.txt' -MaximumBytes 1048576
    $stderrBytes = Read-ZipEntryBytes -Zip $zip -Name 'MAINTENANCE.stderr.txt' -MaximumBytes 1048576
}
finally { $zip.Dispose() }
$utf8 = New-Object Text.UTF8Encoding($false,$true)
$manifest = $utf8.GetString($manifestBytes) | ConvertFrom-Json
$result = $utf8.GetString($resultBytes) | ConvertFrom-Json
$launch = $utf8.GetString($stdoutBytes).Trim() | ConvertFrom-Json
Assert-True ($stderrBytes.Length -eq 0) 'R18R2 maintenance stderr is not empty.'
Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.responseId -eq $expectedResponseId -and [string]$manifest.requestId -eq $requestId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'R18R2 response manifest identity/state changed.'
Assert-True ([string]$manifest.signatureAlgorithm -eq 'RSA-SHA256-PKCS1' -and ([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $expectedSignerThumbprint) 'R18R2 response signer declaration changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R18R2 response authority widened.'
$signedNames = @($manifest.files | ForEach-Object { [string]$_.path } | Sort-Object)
$expectedSignedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','RESULT.json') | Sort-Object
Assert-True (@($manifest.files).Count -eq 3 -and @(Compare-Object -ReferenceObject $expectedSignedNames -DifferenceObject $signedNames).Count -eq 0) 'R18R2 signed response file set changed.'
$signedBytes = @{'MAINTENANCE.stderr.txt'=$stderrBytes;'MAINTENANCE.stdout.txt'=$stdoutBytes;'RESULT.json'=$resultBytes}
foreach ($record in @($manifest.files)) {
    $bytes = [byte[]]$signedBytes[[string]$record.path]
    Assert-True ([int64]$bytes.Length -eq [int64]$record.bytes -and (Get-ByteSha256 $bytes) -eq ([string]$record.sha256).ToUpperInvariant()) "R18R2 signed response leaf changed: $($record.path)"
}
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($endpointCertificate)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
Assert-True ($signatureValid -and $certificate.Thumbprint.ToUpperInvariant() -eq $expectedSignerThumbprint) 'R18R2 signed response verification failed.'
Assert-True ([string]$result.schema -eq 'argos_project_portal_maintenance_result_v1' -and [string]$result.state -eq 'PASS_MAINTENANCE_PATCH' -and [int]$result.exitCode -eq 0 -and [string]$result.entryPoint -eq 'payload/Invoke-R18RReferenceIsolatedLaunch.ps1') 'R18R2 maintenance result changed.'
Assert-True ([string]$launch.schema -eq 'argos_opencv_scribe_r18r_reference_isolated_launch_v1' -and [string]$launch.state -eq 'PASS_R18R_REFERENCE_ISOLATED_WORKER_STARTED' -and [string]$launch.computerName -eq 'A1025645101') 'R18R2 launch state or endpoint changed.'
Assert-True ([string]$launch.workRoot -eq 'D:\A2\w\ocv\R18R2' -and [string]$launch.outputRoot -eq 'D:\A2\o\ocv\R18R2' -and [string]$launch.proposalRoot -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals') 'R18R2 launch roots changed.'
Assert-True ([string]$launch.payloadManifestSha256 -eq '52114D3C344F9864918844A987B59984AB5578A076AE403701894A52DA551FD8' -and [string]$launch.providerSha256 -eq '51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5' -and [string]$launch.runnerSha256 -eq 'B826767EA21BB148DD30A719595B23DD818FD9CFC08B347FEAFD9FD4959F4E3C' -and [string]$launch.cohortSha256 -eq '7393A6CB84F3CF246DCA3751DFCCB76422198C25270CA2759FBF260D2DE8AF56') 'R18R2 launch artifact pins changed.'
Assert-True ([int]$launch.cohortCaseCount -eq 21 -and [bool]$launch.ownedProcessStarted -and -not [bool]$launch.automaticRetryAllowed -and [bool]$launch.checksumVerificationRequired -and -not [bool]$launch.checksumUsedForImageFirst -and [int]$launch.runtimeOverrideCount -eq 0) 'R18R2 launch execution contract changed.'
Assert-True (-not [bool]$launch.fullWaferImagesRead -and -not [bool]$launch.wholeWaferFallbackAllowed -and -not [bool]$launch.identityAccepted -and -not [bool]$launch.readerModified -and -not [bool]$launch.referenceLibraryModified -and -not [bool]$launch.sourceMutationPerformed -and [bool]$launch.reviewOnly -and -not [bool]$launch.productionRoutingEnabled) 'R18R2 launch authority widened.'

$gate = [ordered]@{
    schema='argos_opencv_scribe_r18r2_launch_response_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');
    state='PASS_R18R2_SIGNED_LAUNCH_RESPONSE_COLLECTED_AND_OUTPUT_ROOT_PROVED';disposition='PENDING_GATE';
    requestId=$requestId;requestZipSha256=$requestZipSha256;responseId=$expectedResponseId;endpointState='PASS_MAINTENANCE_PATCH';
    responseZip=$responsePath;responseZipBytes=3005;responseZipSha256=$expectedResponseZipSha256;
    responseManifestSha256=(Get-ByteSha256 $manifestBytes);responseSignatureSha256=(Get-ByteSha256 $signatureBytes);
    resultSha256=(Get-ByteSha256 $resultBytes);stdoutSha256=(Get-ByteSha256 $stdoutBytes);stderrSha256=(Get-ByteSha256 $stderrBytes);
    signedResponseVerified=$true;signerThumbprint=$expectedSignerThumbprint;matchingResponseCount=1;
    launchState=[string]$launch.state;processId=[int]$launch.processId;processStartTimeUtc=[string]$launch.processStartTimeUtc;
    workRoot=[string]$launch.workRoot;outputRoot=[string]$launch.outputRoot;outputRootProvedBySignedLaunch=$true;
    configuredCaseCount=[int]$launch.cohortCaseCount;checksumVerificationRequired=[bool]$launch.checksumVerificationRequired;
    checksumUsedForImageFirst=[bool]$launch.checksumUsedForImageFirst;runtimeOverrideCount=[int]$launch.runtimeOverrideCount;
    ownedProcessStarted=[bool]$launch.ownedProcessStarted;automaticRetryAllowed=[bool]$launch.automaticRetryAllowed;
    outerExtractionRoot=$outerExtractRoot;metadataRoot=$metadataRoot;requestRetried=$false;pixelsDecodedDuringCollection=$false;
    sourceMutationPerformed=$false;identityAccepted=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) {
    Assert-True (-not (Test-Path -LiteralPath $outerExtractRoot) -and -not (Test-Path -LiteralPath $metadataRoot) -and -not (Test-Path -LiteralPath $terminalGatePath)) 'R18R2 fresh collection output already exists.'
    $gate.state = 'PASS_R18R2_LAUNCH_RESPONSE_COLLECTION_PREFLIGHT'
    $gate.mutationsPerformed = $false
    $gate | ConvertTo-Json -Depth 24
    return
}

foreach ($path in @($outerExtractRoot,$metadataRoot,$terminalGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R18R2 fresh collection output exists: $path" }
[IO.Compression.ZipFile]::ExtractToDirectory($responsePath, $outerExtractRoot)
$responseTest = & $responseTester -PackagePath $outerExtractRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
Assert-True ([string]$responseTest.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$responseTest.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'R18R2 extracted signed response verification failed.'
[void](New-Item -ItemType Directory -Path $metadataRoot)
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.json') -Bytes $manifestBytes
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'PORTAL_RESPONSE_MANIFEST.sig') -Bytes $signatureBytes
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'RESULT.json') -Bytes $resultBytes
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'MAINTENANCE.stdout.txt') -Bytes $stdoutBytes
Write-BytesCreateNew -Path (Join-Path $metadataRoot 'MAINTENANCE.stderr.txt') -Bytes $stderrBytes
Write-JsonCreateNew -Path $terminalGatePath -Value $gate
$gate | ConvertTo-Json -Depth 24
