[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Get-Sha256([string]$LiteralPath) { return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash }
function Assert-Pin([string]$LiteralPath, [string]$Sha256, [string]$RequiredState = '') {
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf) -or (Get-Sha256 $LiteralPath) -ne $Sha256) { throw "OLS5 pinned dependency changed: $LiteralPath" }
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) { $value = Get-Content -LiteralPath $LiteralPath -Raw | ConvertFrom-Json; if ([string]$value.state -ne $RequiredState) { throw "OLS5 pinned gate state changed: $LiteralPath" } }
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$requestId = 'REQ_OLS5'
$endpointPath = Join-Path $root 'Invoke-OCV00SourceHashEndpoint.ps1'
$targetsPath = Join-Path $root 'OCV00_SOURCE_HASH_TARGETS.json'
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$signedRoot = Join-Path $root 'signed_ols5'
$partialSigned = Join-Path $root 'signed_ols5.partial'
$readyRoot = Join-Path $signedRoot 'REQ_OLS5.ready'
$finalRoot = Join-Path $root 'final_ols5'
$partialFinal = Join-Path $root 'final_ols5.partial'
$zipName = 'REQ_OLS5.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$packageGatePath = Join-Path $root 'OLS5_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$endpointSha = '6508FE7EACBAA39E4EB49CA0B15F0A292BD19F636D6AA7BAE3C2A26737F6D640'
$targetsSha = 'EC016561994CD3FAFCB35C5ED2D9C39D6D425515C9AC4998DBFB4024327A7CA8'
$definitionSha = '2870A58741CFA87491F06411CFEB10F4A3FF8A6D367F27520859530E4C551F02'
Assert-Pin $endpointPath $endpointSha
Assert-Pin $targetsPath $targetsSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'OLS5_SOURCE_HASH_LOCAL_GATE.json') 'ADC6BB4FC5118953692F71BB9C2649C7B8F7CD7E94928C99AB42FEE809231627' 'PASS_OLS5_SOURCE_HASH_LOCAL_GATE'
Assert-Pin (Join-Path $root 'OCV00_SOURCE_HASH_LOCAL_PROOF_FREEZE.json') '9A13FD0D2D36E66B14EBA4666352299205A4C4B5DEE1912B92C6F2B9939DBC91' 'PASS_OLS5_SOURCE_HASH_LOCAL_PROOF_FROZEN'
Assert-Pin (Join-Path $root 'OLS5_LIVE_RECOVERY_INTENT_R2.json') 'D4CBABCBE4001F5F8FBC9E06952BF8DD3D1C95049B3FFEBC9E2CCB4E1DEAAA8B'
Assert-Pin (Join-Path $project 'work\OPENCV_OLS4\OLS4_COMPLETE_ROUTE_GATE.json') 'A0BECC1A59665E6BF936C0E76B56910DD3DBF3AFC9E9674EC825368F3069C7EE' 'PASS_OLS4_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH' -or [string]$definition.entryPoint -ne 'payload/Invoke-OCV00SourceHashEndpoint.ps1' -or @($definition.changes).Count -ne 1 -or @($definition.entryPointMutations).Count -ne 0 -or @($definition.entryPointOutputs).Count -ne 1 -or @($definition.allowedTaskActions).Count -ne 0 -or @($definition.allowedProcessActions).Count -ne 0 -or -not [bool]$definition.reviewOnly -or [bool]$definition.productionRoutingEnabled) { throw 'OLS5 maintenance definition contract changed.' }
$readContract = $definition.metadataReadContract
if ([string]$definition.changes[0].installedSha256 -ne $endpointSha -or -not [bool]$definition.changes[0].allowCreate -or [string]$readContract.aliasAnchor -ne 'EXACT_REQUESTED_SUBTREE_ROOT' -or [int]$readContract.targetCount -ne 20 -or -not [bool]$readContract.providerAwareIncrementalHashing -or -not [bool]$readContract.fileContentReadAllowed -or -not [bool]$readContract.imageBytesReadAllowed -or -not [bool]$readContract.sourceHashingAllowed -or [bool]$readContract.pixelDecodeAllowed -or [bool]$readContract.imageProcessingAllowed -or [bool]$readContract.sourceMutationAllowed -or [bool]$readContract.taskOrProcessActionAllowed) { throw 'OLS5 source-hash contract changed.' }

foreach ($path in @($signedRoot, $partialSigned, $finalRoot, $partialFinal, $packageGatePath)) { if (Test-Path -LiteralPath $path) { throw "OLS5 fresh output already exists: $path" } }
$planned = @($readyRoot, (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'), (Join-Path $readyRoot 'payload\Invoke-OCV00SourceHashEndpoint.ps1'), (Join-Path $readyRoot 'payload\OCV00_SOURCE_HASH_TARGETS.json'), $zipPath, (Join-Path $partialFinal 'extract\payload\Invoke-OCV00SourceHashEndpoint.ps1'), (Join-Path $partialFinal 'extract\payload\OCV00_SOURCE_HASH_TARGETS.json'), $packageGatePath)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw 'OLS5 package path gate failed.' }

if ($Preflight) {
    [ordered]@{ schema = 'argos_ols5_build_preflight_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OLS5_BUILD_PREFLIGHT'; requestId = $requestId; endpointSha256 = $endpointSha; targetManifestSha256 = $targetsSha; definitionSha256 = $definitionSha; pathState = [string]$pathGate.state; mutationsPerformed = $false; reviewOnly = $true; productionRoutingEnabled = $false } | ConvertTo-Json -Depth 6
    return
}

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) { throw 'OLS5 signer private key is unavailable.' }
$files = @(
    [ordered]@{ source = $endpointPath; path = 'payload/Invoke-OCV00SourceHashEndpoint.ps1'; bytes = (Get-Item -LiteralPath $endpointPath).Length; sha256 = $endpointSha },
    [ordered]@{ source = $targetsPath; path = 'payload/OCV00_SOURCE_HASH_TARGETS.json'; bytes = (Get-Item -LiteralPath $targetsPath).Length; sha256 = $targetsSha }
)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'; requestId = $requestId; createdUtc = $created.ToString('o'); expiresUtc = $created.AddHours(24).ToString('o'); targetRole = 'JBOD'; jobClass = 'MAINTENANCE_PATCH'; handler = ''; maxResultBytes = [int64]$definition.maxResultBytes; reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false; productionRoutingEnabled = $false; credentialsIncluded = $false; signerThumbprint = $thumbprint; signatureAlgorithm = 'RSA-SHA256-PKCS1'; files = @($files | ForEach-Object { [ordered]@{ path = $_.path; bytes = [int64]$_.bytes; sha256 = $_.sha256 } }); entryPoint = [string]$definition.entryPoint; changes = @($definition.changes); entryPointMutations = @(); entryPointOutputs = @($definition.entryPointOutputs); metadataReadContract = $definition.metadataReadContract; allowedTaskActions = @(); allowedProcessActions = @(); rehearsal = $definition.rehearsal
}
$partialReady = Join-Path $partialSigned 'REQ_OLS5.ready'
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
if ([string]$packageTest.State -ne 'PASS_SIGNED_PORTAL_PACKAGE') { throw 'OLS5 signed package verification failed.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{
    'payload/Invoke-OCV00SourceHashEndpoint.ps1' = $endpointSha
    'payload/OCV00_SOURCE_HASH_TARGETS.json' = $targetsSha
    'PORTAL_REQUEST_MANIFEST.json' = Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json')
    'PORTAL_REQUEST_MANIFEST.sig' = Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')
}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
if ($extracted.Count -ne 4) { throw 'OLS5 final ZIP file count changed.' }
foreach ($item in $expected.GetEnumerator()) { $path = Join-Path $extractRoot $item.Key.Replace('/', '\'); if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne [string]$item.Value) { throw "OLS5 final ZIP file changed: $($item.Key)" } }
$tokens = $null; $errors = $null
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extractRoot 'payload\Invoke-OCV00SourceHashEndpoint.ps1'), [ref]$tokens, [ref]$errors)
if (@($errors).Count -ne 0) { throw 'OLS5 extracted endpoint parser failed.' }
$zipSha = Get-Sha256 $partialZip
$gate = [ordered]@{
    schema = 'argos_ols5_final_package_gate_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OLS5_FINAL_PACKAGE_GATE'; requestId = $requestId; requestZip = 'work/OPENCV_OLS5/final_ols5/REQ_OLS5.ready.zip'; requestZipBytes = (Get-Item -LiteralPath $partialZip).Length; requestZipSha256 = $zipSha; requestManifestSha256 = $expected['PORTAL_REQUEST_MANIFEST.json']; requestSignatureSha256 = $expected['PORTAL_REQUEST_MANIFEST.sig']; maintenanceDefinitionSha256 = $definitionSha; endpointSha256 = $endpointSha; targetManifestSha256 = $targetsSha; localGateSha256 = 'ADC6BB4FC5118953692F71BB9C2649C7B8F7CD7E94928C99AB42FEE809231627'; recoveryIntentSha256 = 'D4CBABCBE4001F5F8FBC9E06952BF8DD3D1C95049B3FFEBC9E2CCB4E1DEAAA8B'; inheritedCompleteRouteGateSha256 = 'A0BECC1A59665E6BF936C0E76B56910DD3DBF3AFC9E9674EC825368F3069C7EE'; inheritedQueueGateSha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'; exactFinalZipExtractionPassed = $true; exactFinalZipPayloadHashesPassed = $true; exactPackageSignaturePassed = $true; windowsPowerShell51ParserPassed = $true; sourceHashingAuthorized = $true; pixelsDecoded = $false; imageProcessingPerformed = $false; sourceDeletionPerformed = $false; inspectionTasksChanged = $false; currentWaferAborted = $false; reviewOnly = $true; productionRoutingEnabled = $false; publicationAuthorized = $false; publicationRequiresCompleteRouteGate = $true
}
[IO.File]::WriteAllText((Join-Path $partialFinal ($zipName + '.gate.json')), (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
[IO.File]::WriteAllText($packageGatePath, (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
$gate | ConvertTo-Json -Depth 10
