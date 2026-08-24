[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('CHUNK01','CHUNK02','CHUNK03','CHUNK04','CHUNK05')]
    [string]$ChunkId,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Get-Sha256([string]$LiteralPath) { return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash }
function Assert-Pin([string]$LiteralPath, [string]$Sha256, [string]$RequiredState = '') {
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf) -or (Get-Sha256 $LiteralPath) -ne $Sha256) { throw "OLS6 pinned dependency changed: $LiteralPath" }
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -LiteralPath $LiteralPath -Raw | ConvertFrom-Json
        if ([string]$value.state -ne $RequiredState) { throw "OLS6 pinned gate state changed: $LiteralPath" }
    }
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$ordinal = [int]$ChunkId.Substring(5, 2)
$suffix = '{0:D2}' -f $ordinal
$requestId = 'REQ_OLS6C' + $suffix
$endpointPath = Join-Path $root 'Invoke-OCV00SourceHashChunkEndpoint.ps1'
$chunkPath = Join-Path $root ('OCV00_SOURCE_HASH_CHUNK' + $suffix + '.json')
$definitionPath = Join-Path $root ('MAINTENANCE_DEFINITION_CHUNK' + $suffix + '.json')
$signedRoot = Join-Path $root ('signed_c' + $suffix)
$partialSigned = Join-Path $root ('signed_c' + $suffix + '.partial')
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root ('final_c' + $suffix)
$partialFinal = Join-Path $root ('final_c' + $suffix + '.partial')
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$packageGatePath = Join-Path $root ('OLS6_' + $ChunkId + '_FINAL_PACKAGE_GATE.json')
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$endpointSha = 'ED960F358ACC93D0EF57D294888E1BF71421B9890814C11F10D25530784B083E'
$chunkHashes = @{
    CHUNK01 = '2E16F86A61A54EDE87B43EECE96AFA6BF8F2C97305E8889D4A1416CAE74A85FE'
    CHUNK02 = 'F91E3460FD93C194D9CBA89AB3FB3E1930CC495B6A3A48C1C0D5D9C94EFEDD4B'
    CHUNK03 = '82CFD74AC32597F905F22B49B2FD5F9673DFDB1CA35D8416EBA0EDC9D7D9691D'
    CHUNK04 = '9AFC8F72CA61D83B207E8E7288B904ACCA37DA4A2038636960833478886B33F3'
    CHUNK05 = '02F470F23FC7189CA1A8CD921507B5E09D2748F90E829F61E4AEA0CCD5B77F55'
}
$definitionHashes = @{
    CHUNK01 = '6E49DF167540B99875B9D9F667F041F4F553F7559DAF36DDF7C18C0E122A6FB1'
    CHUNK02 = 'FD74E8753D37FFF6F7709B9C21DFD4B3C7B428D5A87A6151D8FF6B69461578F8'
    CHUNK03 = '2939B4A0B50128953E5C5331822808ABB55C2A198D7A8D836A2B9AF46D3CE99C'
    CHUNK04 = 'F31031272F5825940C698BAA7835B98FD0000ACCD130355DCDD46331BC427594'
    CHUNK05 = '2755DB1934F334EE9D297B33B31109E3E471E8FF49740524F354699100C48241'
}
$chunkSha = [string]$chunkHashes[$ChunkId]
$definitionSha = [string]$definitionHashes[$ChunkId]
$proofSha = '9128EA5494C528C2D5F834051DCA1394350A48106DDF5AD203D0ACA7482C5B60'
$intentSha = 'A4B7EF0739300D01FF403D4D7D2889E0FAE2D27ED067C52105DE83F5663A0751'
Assert-Pin $endpointPath $endpointSha
Assert-Pin $chunkPath $chunkSha 'FROZEN'
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'OLS6_LOCAL_PROOF_FREEZE.json') $proofSha 'PASS_OLS6_LOCAL_PROOF_FROZEN'
Assert-Pin (Join-Path $root 'OLS6_LIVE_RECOVERY_INTENT.json') $intentSha
Assert-Pin (Join-Path $project 'work\OPENCV_OLS4\OLS4_COMPLETE_ROUTE_GATE.json') 'A0BECC1A59665E6BF936C0E76B56910DD3DBF3AFC9E9674EC825368F3069C7EE' 'PASS_OLS4_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$expectedOutput = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV00_OLS6_' + $ChunkId + '_SOURCE_HASHES.json'
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH' -or [string]$definition.entryPoint -ne 'payload/Invoke-OCV00SourceHashChunkEndpoint.ps1' -or @($definition.changes).Count -ne 1 -or @($definition.entryPointMutations).Count -ne 0 -or @($definition.entryPointOutputs).Count -ne 1 -or [string]$definition.entryPointOutputs[0].path -ne $expectedOutput -or @($definition.allowedTaskActions).Count -ne 0 -or @($definition.allowedProcessActions).Count -ne 0 -or -not [bool]$definition.reviewOnly -or [bool]$definition.productionRoutingEnabled) { throw 'OLS6 maintenance definition contract changed.' }
$readContract = $definition.metadataReadContract
if ([string]$definition.changes[0].installedSha256 -ne $endpointSha -or -not [bool]$definition.changes[0].allowCreate -or [string]$readContract.chunkId -ne $ChunkId -or [string]$readContract.chunkManifestSha256 -ne $chunkSha -or [string]$readContract.aliasAnchor -ne 'EXACT_REQUESTED_SUBTREE_ROOT' -or [int]$readContract.targetCount -ne 4 -or -not [bool]$readContract.providerAwareIncrementalHashing -or -not [bool]$readContract.fileContentReadAllowed -or -not [bool]$readContract.imageBytesReadAllowed -or -not [bool]$readContract.sourceHashingAllowed -or [bool]$readContract.pixelDecodeAllowed -or [bool]$readContract.imageProcessingAllowed -or [bool]$readContract.sourceMutationAllowed -or [bool]$readContract.taskOrProcessActionAllowed) { throw 'OLS6 source-hash chunk contract changed.' }

foreach ($path in @($signedRoot, $partialSigned, $finalRoot, $partialFinal, $packageGatePath)) {
    if (Test-Path -LiteralPath $path) { throw "OLS6 fresh output already exists: $path" }
}
$planned = @(
    $readyRoot,
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $readyRoot 'payload\Invoke-OCV00SourceHashChunkEndpoint.ps1'),
    (Join-Path $readyRoot 'payload\OCV00_SOURCE_HASH_CHUNK.json'),
    $zipPath,
    (Join-Path $partialFinal 'extract\payload\Invoke-OCV00SourceHashChunkEndpoint.ps1'),
    (Join-Path $partialFinal 'extract\payload\OCV00_SOURCE_HASH_CHUNK.json'),
    $packageGatePath
)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw 'OLS6 package path gate failed.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols6_chunk_build_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS6_CHUNK_BUILD_PREFLIGHT'
        chunkId = $ChunkId
        requestId = $requestId
        endpointSha256 = $endpointSha
        chunkManifestSha256 = $chunkSha
        definitionSha256 = $definitionSha
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'OLS6 signer private key is unavailable.' }
$files = @(
    [ordered]@{ source = $endpointPath; path = 'payload/Invoke-OCV00SourceHashChunkEndpoint.ps1'; bytes = (Get-Item -LiteralPath $endpointPath).Length; sha256 = $endpointSha },
    [ordered]@{ source = $chunkPath; path = 'payload/OCV00_SOURCE_HASH_CHUNK.json'; bytes = (Get-Item -LiteralPath $chunkPath).Length; sha256 = $chunkSha }
)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = $requestId
    createdUtc = $created.ToString('o')
    expiresUtc = $created.AddHours(24).ToString('o')
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    handler = ''
    maxResultBytes = [int64]$definition.maxResultBytes
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    credentialsIncluded = $false
    signerThumbprint = $thumbprint
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    files = @($files | ForEach-Object { [ordered]@{ path = $_.path; bytes = [int64]$_.bytes; sha256 = $_.sha256 } })
    entryPoint = [string]$definition.entryPoint
    changes = @($definition.changes)
    entryPointMutations = @()
    entryPointOutputs = @($definition.entryPointOutputs)
    metadataReadContract = $definition.metadataReadContract
    allowedTaskActions = @()
    allowedProcessActions = @()
    rehearsal = $definition.rehearsal
}
$partialReady = Join-Path $partialSigned ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partialReady 'payload'))
foreach ($file in $files) { Copy-Item -LiteralPath $file.source -Destination (Join-Path $partialReady $file.path.Replace('/', '\')) }
$manifestPath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath $partialReady -Destination $readyRoot
Remove-Item -LiteralPath $partialSigned -Force
$packageTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if ([string]$packageTest.State -ne 'PASS_SIGNED_PORTAL_PACKAGE') { throw 'OLS6 signed package verification failed.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{
    'payload/Invoke-OCV00SourceHashChunkEndpoint.ps1' = $endpointSha
    'payload/OCV00_SOURCE_HASH_CHUNK.json' = $chunkSha
    'PORTAL_REQUEST_MANIFEST.json' = Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json')
    'PORTAL_REQUEST_MANIFEST.sig' = Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')
}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
if ($extracted.Count -ne 4) { throw 'OLS6 final ZIP file count changed.' }
foreach ($item in $expected.GetEnumerator()) {
    $path = Join-Path $extractRoot $item.Key.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne [string]$item.Value) { throw "OLS6 final ZIP file changed: $($item.Key)" }
}
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extractRoot 'payload\Invoke-OCV00SourceHashChunkEndpoint.ps1'), [ref]$tokens, [ref]$errors)
if (@($errors).Count -ne 0) { throw 'OLS6 extracted endpoint parser failed.' }
$zipSha = Get-Sha256 $partialZip
$gate = [ordered]@{
    schema = 'argos_ols6_chunk_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS6_CHUNK_FINAL_PACKAGE_GATE'
    chunkId = $ChunkId
    requestId = $requestId
    requestZip = 'work/OPENCV_OLS6/final_c' + $suffix + '/' + $zipName
    requestZipBytes = (Get-Item -LiteralPath $partialZip).Length
    requestZipSha256 = $zipSha
    requestManifestSha256 = $expected['PORTAL_REQUEST_MANIFEST.json']
    requestSignatureSha256 = $expected['PORTAL_REQUEST_MANIFEST.sig']
    maintenanceDefinitionSha256 = $definitionSha
    endpointSha256 = $endpointSha
    chunkManifestSha256 = $chunkSha
    localProofSha256 = $proofSha
    recoveryIntentSha256 = $intentSha
    inheritedCompleteRouteGateSha256 = 'A0BECC1A59665E6BF936C0E76B56910DD3DBF3AFC9E9674EC825368F3069C7EE'
    inheritedQueueGateSha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
    exactFinalZipExtractionPassed = $true
    exactFinalZipPayloadHashesPassed = $true
    exactPackageSignaturePassed = $true
    windowsPowerShell51ParserPassed = $true
    sourceHashingAuthorized = $true
    pixelsDecoded = $false
    imageProcessingPerformed = $false
    sourceDeletionPerformed = $false
    inspectionTasksChanged = $false
    currentWaferAborted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    publicationAuthorized = $false
    publicationRequiresCompleteRouteGate = $true
}
[IO.File]::WriteAllText((Join-Path $partialFinal ($zipName + '.gate.json')), (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
[IO.File]::WriteAllText($packageGatePath, (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
$gate | ConvertTo-Json -Depth 10
