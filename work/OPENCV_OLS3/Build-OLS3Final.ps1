[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OLS3'
$requestId = 'REQ_OLS3'
$sourceRoot = Join-Path $workRoot 'signed_ols3\REQ_OLS3.ready'
$finalRoot = Join-Path $workRoot 'final_ols3'
$partialRoot = Join-Path $workRoot 'final_ols3.partial'
$zipName = 'REQ_OLS3.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$definitionPath = Join-Path $workRoot 'pkg\MAINTENANCE_DEFINITION.json'
$signedSourceGatePath = Join-Path $workRoot 'OLS3_SIGNED_SOURCE_GATE.json'
$providerGatePath = Join-Path $project 'work\OPENCV_OLS2\OLS2_PROVIDER_TEST_GATE_R3.json'
$entrypointGatePath = Join-Path $workRoot 'OLS3_ENTRYPOINT_TEST_GATE.json'
$inheritanceGatePath = Join-Path $project 'work\OPENCV_OLS2\OLS2_WORKER_INHERITANCE_GATE.json'
$cloneGatePath = Join-Path $workRoot 'OLS3_CLONE_GATE_R2.json'
$queueGatePath = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$exactEndpointGatePath = Join-Path $project 'work\OPENCV_OEL1\OEL1_COMPLETE_ROUTE_GATE.json'

$expectedEntrypointSha = 'FB2BA81F2159EEF026EB459F7A857E1DDD0821AD446FD4888DEAF9F003D9C2B3'
$expectedWorkerSha = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$expectedOldWorkerSha = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$expectedDefinitionSha = '6D735D09927BEE6D6CDC4A7A895420672CE08D011932EF52353DFA87215067E2'
$expectedProviderGateSha = 'C98500E5CD005B62E2B1F4683B8E5B4304B3AEC26C948497C7A851B86A87015D'
$expectedEntrypointGateSha = '4BECCB3A5C1A7EF5A3E508CE11CA41854EEC77C06181EAB0000876AE750AF95B'
$expectedInheritanceGateSha = '58092C6586DEA26DFD937CD04A84A834D9B4C8A9B0D0DEFCBF4AC7736CD12E55'
$expectedCloneGateSha = 'C05A4FE9F66C4D9E3176238459EB95BC3F99F797726EEF83EA90519E93FC58D1'
$expectedQueueGateSha = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$expectedExactEndpointGateSha = '30E2A04438770BF9D1515BF9515FC91584EF8A84ACD9C2EF05BBF789F21C95B3'

function Get-Sha([string]$Path) {
    $full=[IO.Path]::GetFullPath($Path)
    $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}
    finally{$sha.Dispose();$stream.Dispose()}
}
function Assert-Gate([string]$Path, [string]$Sha256, [string]$State) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required OLS3 gate is missing: $Path" }
    if ((Get-Sha $Path) -ne $Sha256) { throw "Required OLS3 gate hash changed: $Path" }
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ([string]$value.state -ne $State) { throw "Required OLS3 gate state changed: $Path" }
    return $value
}

foreach ($path in @($sourceRoot, $pathTool, $publicCertificatePath, $definitionPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "OLS3 package prerequisite is missing: $path" }
}
if ((Get-Sha $definitionPath) -ne $expectedDefinitionSha) { throw 'OLS3 maintenance definition changed.' }
$signedSourceGate = Get-Content -LiteralPath $signedSourceGatePath -Raw | ConvertFrom-Json
if ([string]$signedSourceGate.schema -ne 'argos_ols3_signed_source_gate_v1' -or [string]$signedSourceGate.state -ne 'PASS_OLS3_SIGNED_SOURCE_GATE' -or [string]$signedSourceGate.requestId -ne $requestId -or -not ([IO.Path]::GetFullPath([string]$signedSourceGate.signedSourcePath)).Equals([IO.Path]::GetFullPath($sourceRoot), [StringComparison]::OrdinalIgnoreCase) -or [string]$signedSourceGate.maintenanceDefinitionSha256 -ne $expectedDefinitionSha -or [string]$signedSourceGate.entrypointSha256 -ne $expectedEntrypointSha -or [string]$signedSourceGate.workerSha256 -ne $expectedWorkerSha -or [int]$signedSourceGate.payloadFileCount -ne 2 -or [string]$signedSourceGate.signatureAlgorithm -ne 'RSA-SHA256-PKCS1' -or -not [bool]$signedSourceGate.reviewOnly -or [bool]$signedSourceGate.productionRoutingEnabled) { throw 'OLS3 signed-source gate contract changed.' }
$expectedManifestSha = [string]$signedSourceGate.requestManifestSha256
$expectedSignatureSha = [string]$signedSourceGate.requestSignatureSha256
if ($expectedManifestSha -notmatch '^[0-9A-F]{64}$' -or $expectedSignatureSha -notmatch '^[0-9A-F]{64}$') { throw 'OLS3 signed-source gate hashes are invalid.' }
if (Test-Path -LiteralPath $finalRoot) { throw "OLS3 final root already exists: $finalRoot" }
if (Test-Path -LiteralPath $partialRoot) { throw "OLS3 partial final root already exists: $partialRoot" }

$expectedFiles = [ordered]@{
    'PORTAL_REQUEST_MANIFEST.json' = $expectedManifestSha
    'PORTAL_REQUEST_MANIFEST.sig' = $expectedSignatureSha
    'payload/E.ps1' = $expectedEntrypointSha
    'payload/W.ps1' = $expectedWorkerSha
}
$sourceFiles = @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName)
if ($sourceFiles.Count -ne $expectedFiles.Count) { throw "OLS3 signed source file count changed: $($sourceFiles.Count)" }
foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = Join-Path $sourceRoot $entry.Key.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha $path) -ne [string]$entry.Value) { throw "OLS3 signed source changed: $($entry.Key)" }
}

$providerGate = Assert-Gate $providerGatePath $expectedProviderGateSha 'PASS_OLS2_PROVIDER_TEST_GATE'
$entrypointGate = Assert-Gate $entrypointGatePath $expectedEntrypointGateSha 'PASS_OLS3_ENTRYPOINT_TEST_GATE'
$inheritanceGate = Assert-Gate $inheritanceGatePath $expectedInheritanceGateSha 'PASS_OLS2_WORKER_INHERITANCE_GATE'
$cloneGate = Assert-Gate $cloneGatePath $expectedCloneGateSha 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'
$queueGate = Assert-Gate $queueGatePath $expectedQueueGateSha 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
$exactEndpointGate = Assert-Gate $exactEndpointGatePath $expectedExactEndpointGateSha 'PASS_OEL1_COMPLETE_ROUTE_GATE'
if ([string]$providerGate.workerSha256 -ne $expectedWorkerSha -or [string]$entrypointGate.targetWorkerSha256 -ne $expectedWorkerSha -or [string]$inheritanceGate.sourceWorkerSha256 -ne $expectedOldWorkerSha -or [string]$inheritanceGate.targetWorkerSha256 -ne $expectedWorkerSha -or [string]$exactEndpointGate.endpointWorkerTargetSha256 -ne $expectedOldWorkerSha) { throw 'OLS3 provider, inheritance, entrypoint, or qualified predecessor gate changed.' }

$planned = New-Object Collections.Generic.List[string]
foreach ($root in @($finalRoot, $partialRoot)) {
    [void]$planned.Add((Join-Path $root $zipName))
    [void]$planned.Add((Join-Path $root ($zipName + '.gate.json')))
    foreach ($relative in $expectedFiles.Keys) { [void]$planned.Add((Join-Path (Join-Path $root 'extract') $relative.Replace('/', '\'))) }
}
$pathGate = & $pathTool -CandidatePath $planned.ToArray() -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OLS3 final package path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols3_final_package_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS3_FINAL_PACKAGE_PREFLIGHT'
        requestId = $requestId
        signedSourceFiles = $sourceFiles.Count
        signedSourceGateSha256 = (Get-Sha $signedSourceGatePath)
        providerGateSha256 = $expectedProviderGateSha
        entrypointGateSha256 = $expectedEntrypointGateSha
        inheritanceGateSha256 = $expectedInheritanceGateSha
        cloneGateSha256 = $expectedCloneGateSha
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
if ($extracted.Count -ne $expectedFiles.Count) { throw "OLS3 extracted file count changed: $($extracted.Count)" }
foreach ($entry in $expectedFiles.GetEnumerator()) {
    $path = Join-Path $partialExtract $entry.Key.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha $path) -ne [string]$entry.Value) { throw "OLS3 exact final ZIP file changed: $($entry.Key)" }
}

$manifestPath = Join-Path $partialExtract 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $partialExtract 'PORTAL_REQUEST_MANIFEST.sig'
$manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
$signatureBytes = [IO.File]::ReadAllBytes($signaturePath)
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($publicCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $signaturePassed = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose(); $certificate.Dispose() }
if (-not $signaturePassed) { throw 'OLS3 exact final ZIP signature verification failed.' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.requestId -ne $requestId -or [string]$manifest.targetRole -ne 'JBOD' -or [string]$manifest.jobClass -ne 'MAINTENANCE_PATCH' -or @($manifest.files).Count -ne 2 -or @($manifest.changes).Count -ne 1 -or @($manifest.entryPointMutations).Count -ne 1 -or @($manifest.entryPointOutputs).Count -ne 1 -or @($manifest.allowedTaskActions).Count -ne 0 -or @($manifest.allowedProcessActions).Count -ne 0) { throw 'OLS3 exact final ZIP manifest contract changed.' }
$parserPassed = 0
foreach ($relative in @('payload/E.ps1', 'payload/W.ps1')) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $partialExtract $relative.Replace('/', '\')), [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "OLS3 exact final ZIP parser failure: $relative" }
    $parserPassed++
}

$zipBytes = (Get-Item -LiteralPath $partialZip).Length
$zipSha = Get-Sha $partialZip
$gate = [ordered]@{
    schema = 'argos_ols3_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS3_FINAL_PACKAGE_GATE'
    requestId = $requestId
    requestZip = 'work/OPENCV_OLS3/final_ols3/REQ_OLS3.ready.zip'
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
    providerGateSha256 = $expectedProviderGateSha
    providerCheckCount = [int]$providerGate.caseCount
    entrypointGateSha256 = $expectedEntrypointGateSha
    entrypointCheckCount = [int]$entrypointGate.caseCount
    inheritanceGateSha256 = $expectedInheritanceGateSha
    cloneGateSha256 = $expectedCloneGateSha
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
