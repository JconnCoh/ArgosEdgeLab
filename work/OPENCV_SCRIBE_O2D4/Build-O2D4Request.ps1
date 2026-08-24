[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) {
    throw 'Specify exactly one of -Preflight or -Build.'
}

function Get-Sha256([string]$LiteralPath) {
    return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash
}

function Assert-Pin([string]$LiteralPath, [string]$Sha256, [string]$RequiredState = '') {
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf) -or (Get-Sha256 $LiteralPath) -ne $Sha256) {
        throw "O2D4 pinned dependency changed: $LiteralPath"
    }
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $LiteralPath | ConvertFrom-Json
        if ([string]$value.state -ne $RequiredState) {
            throw "O2D4 pinned dependency state changed: $LiteralPath"
        }
    }
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$requestId = 'REQ_O2D4'
$endpointPath = Join-Path $root 'Invoke-O2D4ScribeEndpoint.ps1'
$enginePath = Join-Path $project 'work\OPENCV_SCRIBE_V1\ArgosOpenCvScribeV1.py'
$bundlePath = Join-Path $project 'work\OPENCV_SCRIBE_O2D1\O2D1_REFS.zip'
$jobPath = Join-Path $root 'O2D4_SLOT16_JOB.json'
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$signedRoot = Join-Path $root 'signed'
$partialSigned = Join-Path $root 'signed.partial'
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root 'final'
$partialFinal = Join-Path $root 'final.partial'
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$gatePath = Join-Path $root 'O2D4_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$endpointSha = '7FB8B54B18D4D446F4C7AC2FFCB3898721222B93FE4B17E69B681B6E6F85C8C2'
$engineSha = '3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'
$bundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$jobSha = '10FA06D089A7F0918AFA3073033D8F92C0F7D94A625FD8DB4F2C730B12BF3669'
$definitionSha = 'B2637AD2EABA2D40E1AE138BD21AD2285F0B9D97FB27B5846AD1851EDF73A2BB'

Assert-Pin $endpointPath $endpointSha
Assert-Pin $enginePath $engineSha
Assert-Pin $bundlePath $bundleSha
Assert-Pin $jobPath $jobSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'O2D4_ENTRYPOINT_TEST_GATE.json') '7CF2D16A380E202B116A7BCA29BB54702EF7226CD832E17CA1168385ABBB16C3' 'PASS_O2D4_ENTRYPOINT_TEST_GATE'
Assert-Pin (Join-Path $root 'O2D4_CLONE_GATE.json') 'F04FD6B5AD032668B5155B50C01E90BF1BA635A531A3D8AA4FDE76750190ECBA' 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'
Assert-Pin (Join-Path $project 'work\FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1\FOI1_TERMINAL_RESPONSE_GATE.json') 'E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C' 'PASS_FOI1_SIGNED_TERMINAL_RESPONSE'
Assert-Pin (Join-Path $project 'work\OPENCV_PROVIDER_PLATFORM_V1\OCV01_PLATFORM_GATE.json') 'F0A6B44976C570FCE4CCAB28839AC4DEC702B51B9EEE87859738D1332DB11190' 'PASS_OCV01_PROVIDER_PLATFORM_DISABLED_CONTRACT'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
if ([string]$definition.targetRole -ne 'JBOD' -or
    [string]$definition.jobClass -ne 'MAINTENANCE_PATCH' -or
    [string]$definition.entryPoint -ne 'payload/Invoke-O2D4ScribeEndpoint.ps1' -or
    @($definition.changes).Count -ne 1 -or
    @($definition.entryPointMutations).Count -ne 2 -or
    @($definition.entryPointOutputs).Count -ne 2 -or
    @($definition.allowedTaskActions).Count -ne 0 -or
    @($definition.allowedProcessActions).Count -ne 1 -or
    [string]$definition.allowedProcessActions[0] -ne 'START_BOUNDED_PORTABLE_OPENCV_SCRIBE_DEVELOPMENT_SLOT16' -or
    -not [bool]$definition.reviewOnly -or
    [bool]$definition.productionRoutingEnabled) {
    throw 'O2D4 maintenance definition contract changed.'
}
if ([string]$definition.changes[0].installedSha256 -ne $endpointSha -or
    -not [bool]$definition.changes[0].allowCreate -or
    [string]$definition.entryPointMutations[0].targetRoot -ne 'D:\A2\w\ocv\O2D4' -or
    [string]$definition.entryPointMutations[1].targetRoot -ne 'D:\A2\o\ocv\O2D4' -or
    [string]$definition.sourceProcessingContract.lotId -ne '62619-433' -or
    [string]$definition.sourceProcessingContract.slotId -ne 'Slot16' -or
    [string]$definition.sourceProcessingContract.ioPathClass -ne 'SHORT_DOS_DEVICE_ALIAS' -or
    [string]$definition.sourceProcessingContract.sourceAliasName -ne 'X:' -or
    -not [bool]$definition.sourceProcessingContract.opencvPixelDecodeRequired -or
    -not [bool]$definition.sourceProcessingContract.boundedWholeImageScribeSearchRequired -or
    [bool]$definition.sourceProcessingContract.sourceMutationAllowed -or
    [bool]$definition.sourceProcessingContract.sourceDeletionAllowed -or
    [bool]$definition.sourceProcessingContract.holdClearanceAllowed -or
    [bool]$definition.sourceProcessingContract.providerActivationAllowed) {
    throw 'O2D4 exact processing boundary changed.'
}
foreach ($path in @($signedRoot, $partialSigned, $finalRoot, $partialFinal, $gatePath)) {
    if (Test-Path -LiteralPath $path) {
        throw "O2D4 fresh output exists: $path"
    }
}

$planned = @(
    $readyRoot,
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $readyRoot 'payload\Invoke-O2D4ScribeEndpoint.ps1'),
    (Join-Path $readyRoot 'payload\ArgosOpenCvScribeV1.py'),
    (Join-Path $readyRoot 'payload\O2D4_REFS.zip'),
    (Join-Path $readyRoot 'payload\O2D4_SLOT16_JOB.json'),
    $zipPath,
    (Join-Path $partialFinal 'extract\payload\O2D4_REFS.zip'),
    $gatePath,
    'C:\O2D4B\w',
    'C:\O2D4B\o'
)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') {
    throw 'O2D4 package path gate failed.'
}
if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d4_build_preflight_v1'
        state = 'PASS_O2D4_BUILD_PREFLIGHT'
        requestId = $requestId
        payloadFileCount = 4
        engineSha256 = $engineSha
        referenceBundleSha256 = $bundleSha
        jobSha256 = $jobSha
        definitionSha256 = $definitionSha
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if (-not $certificate.HasPrivateKey) {
    throw 'O2D4 signer private key is unavailable.'
}
$files = @(
    [ordered]@{source=$endpointPath;path='payload/Invoke-O2D4ScribeEndpoint.ps1';bytes=[int64](Get-Item -LiteralPath $endpointPath).Length;sha256=$endpointSha},
    [ordered]@{source=$enginePath;path='payload/ArgosOpenCvScribeV1.py';bytes=[int64](Get-Item -LiteralPath $enginePath).Length;sha256=$engineSha},
    [ordered]@{source=$bundlePath;path='payload/O2D4_REFS.zip';bytes=[int64](Get-Item -LiteralPath $bundlePath).Length;sha256=$bundleSha},
    [ordered]@{source=$jobPath;path='payload/O2D4_SLOT16_JOB.json';bytes=[int64](Get-Item -LiteralPath $jobPath).Length;sha256=$jobSha}
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
    files = @($files | ForEach-Object { [ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256} })
    entryPoint = [string]$definition.entryPoint
    changes = @($definition.changes)
    entryPointMutations = @($definition.entryPointMutations)
    entryPointOutputs = @($definition.entryPointOutputs)
    sourceProcessingContract = $definition.sourceProcessingContract
    allowedTaskActions = @($definition.allowedTaskActions)
    allowedProcessActions = @($definition.allowedProcessActions)
    rehearsal = $definition.rehearsal
}

$partialReady = Join-Path $partialSigned ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partialReady 'payload'))
foreach ($file in $files) {
    Copy-Item -LiteralPath $file.source -Destination (Join-Path $partialReady $file.path.Replace('/', '\')) -ErrorAction Stop
}
$manifestPath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try {
    $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
}
finally {
    $rsa.Dispose()
}
[IO.File]::WriteAllBytes($signaturePath, $signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath $partialReady -Destination $readyRoot
Remove-Item -LiteralPath $partialSigned -Force
$packageTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if ([string]$packageTest.State -ne 'PASS_SIGNED_PORTAL_PACKAGE') {
    throw 'O2D4 signed package verification failed.'
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{
    'payload/Invoke-O2D4ScribeEndpoint.ps1' = $endpointSha
    'payload/ArgosOpenCvScribeV1.py' = $engineSha
    'payload/O2D4_REFS.zip' = $bundleSha
    'payload/O2D4_SLOT16_JOB.json' = $jobSha
    'PORTAL_REQUEST_MANIFEST.json' = Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json')
    'PORTAL_REQUEST_MANIFEST.sig' = Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')
}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
if ($extracted.Count -ne 6) {
    throw 'O2D4 final ZIP file count changed.'
}
foreach ($item in $expected.GetEnumerator()) {
    $path = Join-Path $extractRoot $item.Key.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha256 $path) -ne [string]$item.Value) {
        throw "O2D4 final ZIP file changed: $($item.Key)"
    }
}
$tokens = $null
$parserErrors = $null
$extractedEndpoint = Join-Path $extractRoot 'payload\Invoke-O2D4ScribeEndpoint.ps1'
[void][Management.Automation.Language.Parser]::ParseFile($extractedEndpoint, [ref]$tokens, [ref]$parserErrors)
if (@($parserErrors).Count -ne 0) {
    throw 'O2D4 extracted endpoint parser failed.'
}
$runtimeRoot = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$rehearsalJob = Join-Path $root 'O2D4_REHEARSAL_JOB.json'
$exactPreflight = (& $extractedEndpoint -Preflight -Rehearsal -PayloadRoot (Join-Path $extractRoot 'payload') -RuntimeRoot $runtimeRoot -WorkRoot 'C:\O2D4B\w' -OutputRoot 'C:\O2D4B\o' -SourceAliasRoot 'C:\O2D4I' -RehearsalJobPath $rehearsalJob | Out-String) | ConvertFrom-Json
if ([string]$exactPreflight.state -ne 'PASS_O2D4_ENDPOINT_PREFLIGHT' -or
    [bool]$exactPreflight.mutationsPerformed -or
    [bool]$exactPreflight.processStarted) {
    throw 'O2D4 exact extracted endpoint preflight failed.'
}

$zipSha = Get-Sha256 $partialZip
$gate = [ordered]@{
    schema = 'argos_o2d4_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D4_FINAL_PACKAGE_GATE'
    requestId = $requestId
    requestZip = 'work/OPENCV_SCRIBE_O2D4/final/' + $zipName
    requestZipBytes = [int64](Get-Item -LiteralPath $partialZip).Length
    requestZipSha256 = $zipSha
    requestManifestSha256 = $expected['PORTAL_REQUEST_MANIFEST.json']
    requestSignatureSha256 = $expected['PORTAL_REQUEST_MANIFEST.sig']
    maintenanceDefinitionSha256 = $definitionSha
    endpointSha256 = $endpointSha
    engineSha256 = $engineSha
    referenceBundleSha256 = $bundleSha
    jobSha256 = $jobSha
    exactFinalZipExtractionPassed = $true
    exactFinalZipPayloadHashesPassed = $true
    exactPackageSignaturePassed = $true
    windowsPowerShell51ParserPassed = $true
    exactExtractedEndpointPreflightPassed = $true
    installedRuntimeGateSha256 = 'E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C'
    inheritedQueueGateSha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
    imageProcessingAuthorized = $true
    sourceMutationAuthorized = $false
    sourceDeletionAuthorized = $false
    taskActionsAuthorized = 0
    processActionsAuthorized = 1
    holdsMayBeCleared = $false
    providerActivationAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
    publicationAuthorized = $false
    publicationRequiresCompleteRouteGate = $true
}
[IO.File]::WriteAllText((Join-Path $partialFinal ($zipName + '.gate.json')), (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
[IO.File]::WriteAllText($gatePath, (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
$gate | ConvertTo-Json -Depth 10
