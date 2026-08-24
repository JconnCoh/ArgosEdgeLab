[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$projectRoot = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$requestId = 'REQ_O2OBS1'
$workRoot = Join-Path $projectRoot 'work\OPENCV_OLS2'
$definitionPath = Join-Path $workRoot 'OBS1_DATA_PULL_DEFINITION.json'
$intentPath = Join-Path $workRoot 'POST_FAILURE_OBSERVATION_INTENT_R2.json'
$preactionPath = Join-Path $workRoot 'PREACTION_OBS1_BUILD.json'
$historyPath = Join-Path $projectRoot 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $projectRoot 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$intentTool = Join-Path $projectRoot 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$preactionTool = Join-Path $projectRoot 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$signedRoot = 'C:\O2Q'
$finalRoot = 'C:\O2Z'
$extractRoot = 'C:\O2X'
$partialPackage = Join-Path $signedRoot ($requestId + '.partial')
$readyPackage = Join-Path $signedRoot ($requestId + '.ready')
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$extractedPackage = Join-Path $extractRoot ($requestId + '.ready')
$packageGatePath = Join-Path $workRoot 'OBS1_EXACT_PACKAGE_GATE.json'
$pathGatePath = Join-Path $workRoot 'OBS1_PREPUBLICATION_PATH_GATE.json'
$pathGateSidecar = $finalZip + '.path_gate.json'

$expectedDefinitionSha = '8A13255A2A7FAA2C3B4A30D2FCCA6E720742CA01E65BC3D980FDAA918609E44B'
$expectedIntentSha = '9FAE387C6E7BFC46F0626767F0F2C4542AB89BF96542D327093B00418B7298E8'
$expectedEndpointWorkerSha = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$expectedEndpointConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'

function Get-Sha256([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $stream = [IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Write-NewJson([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "Refusing existing evidence: $Path" }
    $temporary = $Path + '.partial'
    if (Test-Path -LiteralPath $temporary) { throw "Refusing existing evidence partial: $temporary" }
    [IO.File]::WriteAllText($temporary, (($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temporary -Destination $Path
}
function Verify-Signature([string]$PackagePath) {
    $manifestBytes = [IO.File]::ReadAllBytes((Join-Path $PackagePath 'PORTAL_REQUEST_MANIFEST.json'))
    $signatureBytes = [IO.File]::ReadAllBytes((Join-Path $PackagePath 'PORTAL_REQUEST_MANIFEST.sig'))
    $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($publicCertificatePath)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
    try { return $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
    finally { $rsa.Dispose(); $certificate.Dispose() }
}

if ($requestId -notmatch '^REQ_[A-Z0-9_]{1,19}$' -or $requestId.Length -gt 23) { throw 'OLS2 OBS1 request identity is not short and bounded.' }
foreach ($path in @($definitionPath,$intentPath,$preactionPath,$historyPath,$identityPath,$publicCertificatePath,$pathTool,$intentTool,$preactionTool)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS2 OBS1 input missing: $path" }
}
if ((Get-Sha256 $definitionPath) -ne $expectedDefinitionSha -or (Get-Sha256 $intentPath) -ne $expectedIntentSha) { throw 'OLS2 OBS1 frozen observation contracts changed.' }
& $intentTool -IntentPath $intentPath -ProjectRoot $projectRoot -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $projectRoot -Preflight | Out-Null

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$relativePaths = @($definition.parameters.relativePaths)
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'DATA_PULL' -or [string]$definition.parameters.approvedRoot -ne 'JBOD_PROCESSOR_REVIEW' -or $relativePaths.Count -ne 2 -or [int]$definition.parameters.maximumFiles -ne 2 -or [int64]$definition.parameters.maximumBytes -ne 4194304 -or [int64]$definition.maxResultBytes -ne 4194304) { throw 'OLS2 OBS1 DATA_PULL definition contract changed.' }
$expectedRelativePaths = @('OCV00_OLS2_LOT_INVENTORY.json','OCV00_OLS2.ps1')
if (@(Compare-Object -ReferenceObject $expectedRelativePaths -DifferenceObject @($relativePaths | ForEach-Object { [string]$_ })).Count -ne 0) { throw 'OLS2 OBS1 exact source path set changed.' }

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$privateCertificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $privateCertificate.HasPrivateKey) { throw 'OLS2 OBS1 signer private key is unavailable.' }
$publicCertificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($publicCertificatePath)
try { if (-not $publicCertificate.Thumbprint.Equals($thumbprint,[StringComparison]::OrdinalIgnoreCase)) { throw 'OLS2 OBS1 signer public/private identity changed.' } }
finally { $publicCertificate.Dispose() }

foreach ($path in @($signedRoot,$finalRoot,$extractRoot,$packageGatePath,$pathGatePath,$pathGateSidecar)) {
    if (Test-Path -LiteralPath $path) { throw "Fresh OLS2 OBS1 build path required: $path" }
}

$responseId = 'R_0123456789AB_20260824235959999_a1b2c3d4'
$responseReadyName = $responseId + '.ready'
$innerLongest = 'data\JBOD_PROCESSOR_REVIEW\OCV00_OLS2_LOT_INVENTORY.json'
$routeCandidates = @(
    (Join-Path $partialPackage 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyPackage 'PORTAL_REQUEST_MANIFEST.sig'),
    $finalZip,
    $pathGateSidecar,
    ('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip.upload'),
    ('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip'),
    ('C:\APR\S\requests\' + $requestId + '.ready.zip'),
    ('C:\APR\S\requests\processed\' + $requestId + '.ready.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial',
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\DATA_PULL_PAYLOAD.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseReadyName + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReadyName + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReadyName + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReadyName + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\APR\R\pending\' + $responseReadyName + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\APR\A\' + $responseReadyName + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('U:\ProjectPortalRO\responses\' + $responseReadyName + '.zip'),
    ('C:\O2R\' + $responseReadyName + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\O2R\' + $responseReadyName + '\' + $innerLongest)
)
$pathBudget = & $pathTool -CandidatePath $routeCandidates -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathBudget.state -ne 'PASS_PATH_BUDGET') { throw 'OLS2 OBS1 complete route path budget failed.' }
$longest = @($pathBudget.candidates | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$routeRows = @($pathBudget.candidates | ForEach-Object { [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'} })

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols2_obs1_builder_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS2_OBS1_BUILDER_PREFLIGHT'
        requestId = $requestId
        relativePaths = $relativePaths.Count
        maximumEffectiveLength = [int]$longest.effectiveLength
        maximumComponentLength = [int](($pathBudget.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
        mutationsPerformed = $false
        imageBytesRequested = 0
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $partialPackage -Force)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='DATA_PULL';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@();parameters=$definition.parameters
}
$encoding = New-Object Text.UTF8Encoding($false)
$manifestBytes = $encoding.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes((Join-Path $partialPackage 'PORTAL_REQUEST_MANIFEST.json'),$manifestBytes)
$privateRsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($privateCertificate)
try { $signature=$privateRsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $privateRsa.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $partialPackage 'PORTAL_REQUEST_MANIFEST.sig'),$signature)
Move-Item -LiteralPath $partialPackage -Destination $readyPackage
if (-not (Verify-Signature $readyPackage)) { throw 'OLS2 OBS1 signed request verification failed.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $finalRoot)
[IO.Compression.ZipFile]::CreateFromDirectory($readyPackage,$finalZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[void](New-Item -ItemType Directory -Path $extractedPackage -Force)
[IO.Compression.ZipFile]::ExtractToDirectory($finalZip,$extractedPackage)
if (-not (Verify-Signature $extractedPackage)) { throw 'OLS2 OBS1 extracted request signature verification failed.' }
$sourceFiles = @(Get-ChildItem -LiteralPath $readyPackage -File | Sort-Object Name)
$extractedFiles = @(Get-ChildItem -LiteralPath $extractedPackage -File | Sort-Object Name)
if ($sourceFiles.Count -ne 2 -or $extractedFiles.Count -ne 2 -or (@($sourceFiles.Name)-join '|') -ne (@($extractedFiles.Name)-join '|')) { throw 'OLS2 OBS1 exact package file set changed.' }
foreach ($sourceFile in $sourceFiles) { if ((Get-Sha256 $sourceFile.FullName) -ne (Get-Sha256 (Join-Path $extractedPackage $sourceFile.Name))) { throw "OLS2 OBS1 extracted file changed: $($sourceFile.Name)" } }
$manifestSha256 = Get-Sha256 (Join-Path $readyPackage 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $readyPackage 'PORTAL_REQUEST_MANIFEST.sig')
$zipSha256 = Get-Sha256 $finalZip
$zipBytes = [int64](Get-Item -LiteralPath $finalZip).Length
$packageGate = [ordered]@{
    schema='argos_ols2_obs1_exact_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_OBS1_EXACT_SIGNED_DATA_PULL_PACKAGE';requestId=$requestId;packageDirectory=$readyPackage;finalZip=$finalZip;finalZipBytes=$zipBytes;finalZipSha256=$zipSha256;manifestSha256=$manifestSha256;signatureSha256=$signatureSha256;exactFolderSignaturePassed=$true;exactFinalZipExtractionRoot=$extractedPackage;exactFinalZipExtractionPassed=$true;exactExtractedSignaturePassed=$true;definition=[ordered]@{path=$definitionPath;sha256=$expectedDefinitionSha};preactionContract=[ordered]@{path=$preactionPath;sha256=(Get-Sha256 $preactionPath)};payloadFiles=0;requestedTextOrSourceFiles=2;requestedImageOrBinaryFiles=0;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-NewJson $packageGatePath $packageGate
$pathGate = [ordered]@{
    schema='argos_project_portal_prepublication_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_PROJECT_PORTAL_PREPUBLICATION_PATH_GATE';requestId=$requestId;jobClass='DATA_PULL';requestZip=$finalZip;requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;definition=[ordered]@{path=$definitionPath;sha256=$expectedDefinitionSha};preactionContract=[ordered]@{path=$preactionPath;sha256=(Get-Sha256 $preactionPath)};installedRoute=[ordered]@{endpointWorkerPath='C:/ProgramData/ArgosProjectPortalRO/bin/W.ps1';endpointWorkerSha256=$expectedEndpointWorkerSha;endpointConfigPath='C:/ProgramData/ArgosProjectPortalRO/config/endpoint_jbod.json';endpointConfigSha256=$expectedEndpointConfigSha;incomingRoot='C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending';processedRoot='C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/processed';responsePartialAndReadyRoot='C:/ProgramData/ArgosProjectPortalRO/to_argos/pending';responseSenderSentRoot='C:/ProgramData/ArgosProjectPortalRO/to_argos/sent';stateRoot='C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state';approvedRoot='JBOD_PROCESSOR_REVIEW';approvedRootPath='C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2'};requestContract=[ordered]@{relativePathCount=2;maximumFiles=2;maximumBytes=4194304;maxResultBytes=4194304;optionalPathCount=0;longestReturnedZipEntry=$innerLongest.Replace('\','/');sourcePathsPreservedInsideNestedZip=$true;filesystemReturnPathsFlattened=$true;imageOrBinaryFilesRequested=0};reservedSuffixCharacters=32;routeRows=$routeRows;maximumEffectiveLength=[int]$longest.effectiveLength;maximumComponentLength=[int](($pathBudget.candidates|Measure-Object longestComponentLength -Maximum).Maximum);exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;publicationAuthorized=$true;maximumRequestsAuthorized=1;retryOnFailure=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-NewJson $pathGatePath $pathGate
Write-NewJson $pathGateSidecar $pathGate
[ordered]@{schema='argos_ols2_obs1_builder_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_OBS1_EXACT_SIGNED_DATA_PULL_READY';requestId=$requestId;finalZip=$finalZip;finalZipSha256=$zipSha256;finalZipBytes=$zipBytes;packageGate=$packageGatePath;pathGate=$pathGatePath;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
