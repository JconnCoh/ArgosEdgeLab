[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OEL1'
$requestId = 'REQ_OEL1'
$sourceRoot = Join-Path $workRoot 'signed_short\REQ_OEL1.ready'
$finalRoot = Join-Path $workRoot 'final'
$partialRoot = Join-Path $workRoot 'final.partial'
$zipName = 'REQ_OEL1.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$definitionPath = Join-Path $workRoot 'pkg\MAINTENANCE_DEFINITION.json'
$signedSourceGatePath = Join-Path $workRoot 'OEL1_SIGNED_SOURCE_GATE.json'
$entrypointGatePath = Join-Path $workRoot 'OEL1_ENTRYPOINT_TEST_GATE.json'
$queueGatePath = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$exactEndpointGatePath = Join-Path $project 'work\FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1\FIC1_COMPLETE_ROUTE_GATE.json'

$expectedEntrypointSha = '48F4642404A377A792B5333D3A75E11FBE5D96F2E178A89EC79B447D3C0DE85E'
$expectedWorkerSha = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$expectedOldWorkerSha = '750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08'
$expectedDefinitionSha = 'A7D9EE2BE3BFF85A87072590B36F326071E47B93B9C2FACEE6F9A483695EAFFA'
$expectedEntrypointGateSha = 'B6315433FE0D14D1C1AF3705ED3EF2EAE2E406C73E0A2380202AE4087904D352'
$expectedQueueGateSha = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$expectedExactEndpointGateSha = '32AFF1FD7DCC1FA96A9C245FB3385EC7C01484B03B6A70C01C3F92064C0C8C83'

function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Gate([string]$Path, [string]$Sha256, [string]$State) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required OEL1 gate is missing: $Path" }
    if ((Get-Sha $Path) -ne $Sha256) { throw "Required OEL1 gate hash changed: $Path" }
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ([string]$value.state -ne $State) { throw "Required OEL1 gate state changed: $Path" }
    return $value
}

foreach ($path in @($sourceRoot, $pathTool, $publicCertificatePath, $definitionPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "OEL1 package prerequisite is missing: $path" }
}
if ((Get-Sha $definitionPath) -ne $expectedDefinitionSha) { throw 'OEL1 maintenance definition changed.' }
$signedSourceGate = Get-Content -LiteralPath $signedSourceGatePath -Raw | ConvertFrom-Json
if ([string]$signedSourceGate.schema -ne 'argos_oel1_signed_source_gate_v1' -or [string]$signedSourceGate.state -ne 'PASS_OEL1_SIGNED_SOURCE_GATE' -or [string]$signedSourceGate.requestId -ne $requestId -or -not ([IO.Path]::GetFullPath([string]$signedSourceGate.signedSourcePath)).Equals([IO.Path]::GetFullPath($sourceRoot), [StringComparison]::OrdinalIgnoreCase) -or [string]$signedSourceGate.maintenanceDefinitionSha256 -ne $expectedDefinitionSha -or [string]$signedSourceGate.entrypointSha256 -ne $expectedEntrypointSha -or [string]$signedSourceGate.workerSha256 -ne $expectedWorkerSha -or [int]$signedSourceGate.payloadFileCount -ne 2 -or [string]$signedSourceGate.signatureAlgorithm -ne 'RSA-SHA256-PKCS1' -or -not [bool]$signedSourceGate.reviewOnly -or [bool]$signedSourceGate.productionRoutingEnabled) { throw 'OEL1 signed-source gate contract changed.' }
$expectedManifestSha = [string]$signedSourceGate.requestManifestSha256
$expectedSignatureSha = [string]$signedSourceGate.requestSignatureSha256
if ($expectedManifestSha -notmatch '^[0-9A-F]{64}$' -or $expectedSignatureSha -notmatch '^[0-9A-F]{64}$') { throw 'OEL1 signed-source gate hashes are invalid.' }
if (Test-Path -LiteralPath $finalRoot) { throw "OEL1 final root already exists: $finalRoot" }
if (Test-Path -LiteralPath $partialRoot) { throw "OEL1 partial final root already exists: $partialRoot" }

$expectedFiles = [ordered]@{
    'PORTAL_REQUEST_MANIFEST.json' = $expectedManifestSha
    'PORTAL_REQUEST_MANIFEST.sig' = $expectedSignatureSha
    'payload/E.ps1' = $expectedEntrypointSha
    'payload/W.ps1' = $expectedWorkerSha
}
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName)
if ($sourceFiles.Count -ne $expectedFiles.Count) { throw "OEL1 signed source file count changed: $($sourceFiles.Count)" }
foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = Join-Path $sourceRoot $entry.Key.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha $path) -ne [string]$entry.Value) { throw "OEL1 signed source changed: $($entry.Key)" }
}

$entrypointGate = Assert-Gate $entrypointGatePath $expectedEntrypointGateSha 'PASS_OEL1_ENTRYPOINT_TEST_GATE'
$queueGate = Assert-Gate $queueGatePath $expectedQueueGateSha 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
$exactEndpointGate = Assert-Gate $exactEndpointGatePath $expectedExactEndpointGateSha 'PASS_FIC1_COMPLETE_ROUTE_GATE'
if ([string]$exactEndpointGate.endpointWorkerTargetSha256 -ne $expectedOldWorkerSha) { throw 'OEL1 inherited endpoint predecessor does not match the qualified FIC1 endpoint target.' }

$planned = New-Object Collections.Generic.List[string]
foreach ($root in @($finalRoot, $partialRoot)) {
    [void]$planned.Add((Join-Path $root $zipName))
    [void]$planned.Add((Join-Path $root ($zipName + '.gate.json')))
    foreach ($relative in $expectedFiles.Keys) { [void]$planned.Add((Join-Path (Join-Path $root 'extract') $relative.Replace('/', '\'))) }
}
$pathGate = & $pathTool -CandidatePath $planned.ToArray() -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OEL1 final package path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_oel1_final_package_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OEL1_FINAL_PACKAGE_PREFLIGHT'
        requestId = $requestId
        signedSourceFiles = $sourceFiles.Count
        signedSourceGateSha256 = (Get-Sha $signedSourceGatePath)
        entrypointGateSha256 = $expectedEntrypointGateSha
        inheritedQueueGateSha256 = $expectedQueueGateSha
        inheritedExactEndpointGateSha256 = $expectedExactEndpointGateSha
        exactTransformationPredecessorSha256 = $expectedOldWorkerSha
        exactTransformationTargetSha256 = $expectedWorkerSha
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialRoot)
$partialZip = Join-Path $partialRoot $zipName
$partialExtract = Join-Path $partialRoot 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($sourceRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $partialExtract)

$extracted = @(Get-ChildItem -LiteralPath $partialExtract -Recurse -File | Sort-Object FullName)
if ($extracted.Count -ne $expectedFiles.Count) { throw "OEL1 extracted file count changed: $($extracted.Count)" }
foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = Join-Path $partialExtract $entry.Key.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha $path) -ne [string]$entry.Value) { throw "OEL1 exact final ZIP file changed: $($entry.Key)" }
}

$manifestPath = Join-Path $partialExtract 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $partialExtract 'PORTAL_REQUEST_MANIFEST.sig'
$manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
$signatureBytes = [IO.File]::ReadAllBytes($signaturePath)
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($publicCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signaturePassed = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose(); $certificate.Dispose() }
if (-not $signaturePassed) { throw 'OEL1 exact final ZIP signature verification failed.' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.requestId -ne $requestId -or [string]$manifest.targetRole -ne 'JBOD' -or [string]$manifest.jobClass -ne 'MAINTENANCE_PATCH' -or @($manifest.files).Count -ne 2 -or @($manifest.changes).Count -ne 1 -or @($manifest.entryPointMutations).Count -ne 1 -or @($manifest.entryPointOutputs).Count -ne 1 -or @($manifest.allowedTaskActions).Count -ne 0 -or @($manifest.allowedProcessActions).Count -ne 0) { throw 'OEL1 exact final ZIP manifest contract changed.' }
$parserPassed = 0
foreach ($relative in @('payload/E.ps1', 'payload/W.ps1')) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $partialExtract $relative.Replace('/', '\')), [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "OEL1 exact final ZIP parser failure: $relative" }
    $parserPassed++
}

$zipBytes = (Get-Item -LiteralPath $partialZip).Length
$zipSha = Get-Sha $partialZip
$gate = [ordered]@{
    schema = 'argos_oel1_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OEL1_FINAL_PACKAGE_GATE'
    requestId = $requestId
    requestZip = 'work/OPENCV_OEL1/final/REQ_OEL1.ready.zip'
    requestZipBytes = [int64]$zipBytes
    requestZipSha256 = $zipSha
    requestManifestSha256 = $expectedManifestSha
    requestSignatureSha256 = $expectedSignatureSha
    signedSourceGateSha256 = (Get-Sha $signedSourceGatePath)
    maintenanceDefinitionSha256 = $expectedDefinitionSha
    entrypointSha256 = $expectedEntrypointSha
    oldEndpointWorkerSha256 = $expectedOldWorkerSha
    targetEndpointWorkerSha256 = $expectedWorkerSha
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    exactFinalZipPayloadHashesPassed = $true
    windowsPowerShell51ParserPassedForPayloadScripts = $parserPassed
    entrypointGateSha256 = $expectedEntrypointGateSha
    entrypointCheckCount = [int]$entrypointGate.caseCount
    inheritedQueueGateSha256 = $expectedQueueGateSha
    inheritedQueueCheckCount = [int]$queueGate.checkCount
    inheritedExactEndpointGateSha256 = $expectedExactEndpointGateSha
    reservedSuffixCharacters = 32
    sourceDeletionPerformed = $false
    inspectionTasksChanged = $false
    currentWaferAborted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    publicationAuthorized = $false
    publicationRequiresCompleteRouteGate = $true
}
[IO.File]::WriteAllText((Join-Path $partialRoot ($zipName + '.gate.json')), (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $partialRoot -Destination $finalRoot
$gate | ConvertTo-Json -Depth 10
