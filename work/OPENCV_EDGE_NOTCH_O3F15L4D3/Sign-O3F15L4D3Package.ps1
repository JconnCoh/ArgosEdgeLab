#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Sign,
    [string]$PackageRoot = 'C:\O3F15L4D3PK'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-NewBytes([string]$Path, [byte[]]$Bytes) {
    Require (-not (Test-Path -LiteralPath $Path)) "Refusing existing output: $Path"
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

function Write-NewUtf8Json([string]$Path, [object]$Value) {
    Write-NewBytes $Path ((New-Object Text.UTF8Encoding($false)).GetBytes(($Value | ConvertTo-Json -Depth 32)))
}

Require (($Preflight -and -not $Sign) -or ($Sign -and -not $Preflight)) 'Select exactly one of -Preflight or -Sign.'

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = [IO.Path]::GetFullPath($PackageRoot)
Require ($root -ceq 'C:\O3F15L4D3PK') 'O3F15L4D3 package root changed.'
$buildRoot = Join-Path $root 'build.ready'
$payloadRoot = Join-Path $buildRoot 'payload'
$buildGatePath = Join-Path $buildRoot 'O3F15L4D3_BUILD_GATE.json'
$definitionPath = Join-Path $buildRoot 'MAINTENANCE_DEFINITION.json'
$contractPath = Join-Path $payloadRoot 'O3F15L4D3_DIAGNOSTIC_CONTRACT.json'
$publicCertificatePath = Join-Path $project 'work/PROJECT_PORTAL_REVIEW_ONLY/enrollment/ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$verifierPath = Join-Path $project 'work/PROJECT_PORTAL_REVIEW_ONLY/scripts/Test-SignedPortalPackage.ps1'
foreach ($path in @($buildGatePath, $definitionPath, $contractPath, $publicCertificatePath, $verifierPath)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "D2 signing dependency is absent: $path"
}

$buildGate = Get-Content -LiteralPath $buildGatePath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
Require ([string]$buildGate.state -ceq 'PASS_O3F15L4D3_UNSIGNED_METADATA_DIAGNOSTIC_PACKAGE_BUILT' -and [int]$buildGate.buildCount -eq 1 -and [int]$buildGate.payloadPinCount -eq 17 -and [int]$buildGate.payloadFileCount -eq 18) 'D2 build evidence changed.'
Require ([string]$contract.lifecycle -ceq 'FROZEN' -and [string]$contract.state -ceq 'FROZEN_O3F15L4D3_METADATA_DIAGNOSTIC_CONTRACT') 'D2 signing requires the once-frozen contract.'
Require ([string]$definition.lifecycle -ceq 'FROZEN' -and [string]$definition.state -ceq 'FROZEN_O3F15L4D3_MAINTENANCE_DEFINITION') 'D2 signing requires the once-frozen definition.'
Require ((Get-Sha256 $contractPath) -ceq [string]$buildGate.contractSha256 -and (Get-Sha256 $definitionPath) -ceq [string]$buildGate.definitionSha256) 'D2 built contract or definition changed.'
Require ([int64]$definition.maximumResultBytes -eq 8388608 -and [int64]$contract.response.maximumConstructedResponseBytes -eq 8388608) 'D2 signed result ceiling changed.'
Require ([string]$definition.entrypoint -ceq 'Invoke-O3F15L4D3.ps1' -and [int]$definition.timeoutSeconds -eq 630 -and -not [bool]$definition.automaticRetry) 'D2 signed entrypoint/timeout/retry contract changed.'
Require ([bool]$definition.reviewOnly -and -not [bool]$definition.trainingEligible -and -not [bool]$definition.xmlEligible -and -not [bool]$definition.productionEligible -and -not [bool]$definition.productionRoutingEnabled) 'D2 definition authority widened.'
Require ([int]$contract.child.maximumCount -eq 1 -and [string]::Join('|', @($contract.child.arguments)) -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT' -and [int]$contract.child.timeoutSeconds -eq 600) 'D2 signed sole-child contract changed.'
Require ([int]$contract.holds.fullFrontside -eq 184 -and [int]$contract.holds.patternedFront -eq 12 -and [bool]$contract.holds.slot02MultipleCandidateAmbiguity -and [bool]$contract.holds.slot16RareHotspot -and [bool]$contract.holds.laterPrerequisitesPreserved) 'D2 signed hold preservation changed.'

$actual = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
Require ($actual.Count -eq 18 -and @($actual.Name | Sort-Object -Unique).Count -eq 18) 'D2 built payload cardinality changed.'
foreach ($record in @($buildGate.payloadFiles)) {
    $path = Join-Path $payloadRoot ([string]$record.path)
    Require (Test-Path -LiteralPath $path -PathType Leaf) "D2 built payload is absent: $($record.path)"
    Require ((Get-Item -LiteralPath $path).Length -eq [int64]$record.bytes -and (Get-Sha256 $path) -ceq [string]$record.sha256) "D2 built payload changed: $($record.path)"
}

$changeDefinition = @($definition.installedFiles)
Require ($changeDefinition.Count -eq 1) 'D2 signed change count changed.'
$installed = $changeDefinition[0]
$carrierHash = '6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
Require ([string]$installed.source -ceq 'OCV03_NotchReviewOpenCvV1.py' -and [string]$installed.destination -ceq 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py' -and [string]$installed.expectedInstalledSha256 -ceq $carrierHash -and @($installed.approvedPredecessorSha256).Count -eq 1 -and [string]$installed.approvedPredecessorSha256[0] -ceq $carrierHash -and [bool]$installed.sameBytesOnly -and -not [bool]$installed.allowCreate) 'D2 signed carrier is not same-byte/idempotent-only.'
Require ((Get-Sha256 (Join-Path $payloadRoot 'OCV03_NotchReviewOpenCvV1.py')) -ceq $carrierHash) 'D2 signed carrier payload changed.'

$expectedThumbprint = 'C82181052919C475CF888F49427C1B55AE65DC12'
$publicCertificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2([IO.Path]::GetFullPath($publicCertificatePath))
Require ($publicCertificate.Thumbprint.ToUpperInvariant() -ceq $expectedThumbprint) 'D2 public signer certificate thumbprint changed.'
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$expectedThumbprint") -ErrorAction Stop
Require ([bool]$certificate.HasPrivateKey -and $certificate.Thumbprint.ToUpperInvariant() -ceq $expectedThumbprint) 'D2 private signing identity is unavailable.'

$expandedPartial = Join-Path $root 'request.partial'
$plannedRequestId = 'REQ_20260903T235959999Z_0123456789AB'
$plannedExpandedReady = Join-Path $root ($plannedRequestId + '.ready')
$finalRoot = Join-Path $PSScriptRoot 'final_o3f15l4d3'
$plannedZip = Join-Path $finalRoot ($plannedRequestId + '.ready.zip')
$signGatePath = Join-Path $finalRoot 'O3F15L4D3_SIGN_GATE.json'
$longest = @($actual | Sort-Object { $_.Name.Length } -Descending | Select-Object -First 1)[0].Name
$planned = @($expandedPartial, (Join-Path $expandedPartial (Join-Path 'payload' $longest)), (Join-Path $expandedPartial 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $expandedPartial 'PORTAL_REQUEST_MANIFEST.sig'), $plannedExpandedReady, $finalRoot, $plannedZip, $signGatePath)
$pathGate = & (Join-Path $project 'utilities/Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'D2 short expanded-signing/final-artifact path gate failed.'
Require (-not (Test-Path -LiteralPath $expandedPartial) -and -not (Test-Path -LiteralPath $finalRoot)) 'D2 one-shot signing output already exists.'
Require (@(Get-ChildItem -LiteralPath $root -Directory | Where-Object { $_.Name -like 'REQ_*.ready' }).Count -eq 0) 'D2 expanded signed request already exists.'

if ($Preflight) {
    [ordered]@{
        schema='argos_ocv03_o3f15l4d3_sign_preflight_v1'
        state='PASS_O3F15L4D3_SIGN_PREFLIGHT'
        buildGateSha256=Get-Sha256 $buildGatePath
        contractSha256=Get-Sha256 $contractPath
        definitionSha256=Get-Sha256 $definitionPath
        payloadFileCount=18
        maximumResultBytes=8388608
        signerThumbprint=$expectedThumbprint
        expandedSigningRoot=$root
        durableFinalRoot=$finalRoot
        pathState=[string]$pathGate.state
        signatureCount=0
        published=$false
        targetExecuted=$false
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path (Join-Path $expandedPartial 'payload') -Force)
foreach ($item in $actual) {
    [IO.File]::Copy($item.FullName, (Join-Path (Join-Path $expandedPartial 'payload') $item.Name), $false)
}
$files = @(Get-ChildItem -LiteralPath (Join-Path $expandedPartial 'payload') -File | Sort-Object Name | ForEach-Object {
    [ordered]@{path='payload/' + $_.Name;bytes=[int64]$_.Length;sha256=Get-Sha256 $_.FullName}
})
Require ($files.Count -eq 18) 'D2 signed payload count changed.'

$created = [DateTimeOffset]::UtcNow
$requestId = 'REQ_' + $created.ToString('yyyyMMddTHHmmssfffZ') + '_' + ([Guid]::NewGuid().ToString('N').Substring(0,12).ToUpperInvariant())
$expandedReady = Join-Path $root ($requestId + '.ready')
$changes = @([ordered]@{
    source='payload/' + [string]$installed.source
    destination=[string]$installed.destination
    approvedPredecessorSha256=@($installed.approvedPredecessorSha256)
    installedSha256=[string]$installed.expectedInstalledSha256
    allowCreate=[bool]$installed.allowCreate
})
$sourceProcessingContract = [ordered]@{
    mode=[string]$contract.mode
    exactChildExecutable=[string]$contract.child.executable
    exactChildArguments=@($contract.child.arguments)
    exactChildWorkingDirectory=[string]$contract.child.workingDirectory
    maximumOwnedChildCount=[int]$contract.child.maximumCount
    childTimeoutSeconds=[int]$contract.child.timeoutSeconds
    maximumCombinedStdoutStderrBytes=[int64]$contract.child.maximumCombinedStdoutStderrBytes
    resultSchema=[string]$contract.response.schema
    successState=[string]$contract.response.successState
    failureState=[string]$contract.response.failureState
    corpus=[string]$contract.classification.corpus
    pairCount=[int]$contract.classification.pairCount
    identityCount=[int]$contract.classification.identityCount
    sourceLeafCount=[int]$contract.classification.sourceLeafCount
    classes=@($contract.classification.classes)
    selfTestAllowed=$false
    focusedTestAllowed=$false
    gateAllowed=$false
    runAllowed=$false
    qSubstAllowed=$false
    detectorResultRootCreationAllowed=$false
    imageBytesReadAllowed=$false
    backgroundLaunchAllowed=$false
}
$timeoutContract = [ordered]@{endpointSeconds=[int]$definition.timeoutSeconds;childSeconds=[int]$contract.child.timeoutSeconds;childOutputBytes=[int64]$contract.child.maximumCombinedStdoutStderrBytes;emittedJsonBytes=[int64]$contract.response.maximumEmittedJsonBytes;constructedResponseBytes=[int64]$contract.response.maximumConstructedResponseBytes}
$manifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1'
    requestId=$requestId
    createdUtc=$created.ToString('o')
    expiresUtc=$created.AddHours(24).ToString('o')
    targetRole='JBOD'
    jobClass='MAINTENANCE_PATCH'
    handler=''
    maxResultBytes=[int64]$definition.maximumResultBytes
    reviewOnly=$true
    trainingEligible=$false
    xmlEligible=$false
    productionEligible=$false
    productionRoutingEnabled=$false
    credentialsIncluded=$false
    signerThumbprint=$expectedThumbprint
    signatureAlgorithm='RSA-SHA256-PKCS1'
    files=$files
    entryPoint='payload/' + [string]$definition.entrypoint
    changes=$changes
    entryPointMutations=@()
    entryPointOutputs=@()
    sourceProcessingContract=$sourceProcessingContract
    timeoutContract=$timeoutContract
    allowedTaskActions=@()
    allowedProcessActions=@('START_EXACTLY_ONE_BOUNDED_OWNED_O3F15L4_PREFLIGHT_CHILD_ONLY')
    rehearsal=[ordered]@{requiredState=[string]$contract.response.successState}
    requestRetryAuthorized=$false
}
$manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
Write-NewBytes (Join-Path $expandedPartial 'PORTAL_REQUEST_MANIFEST.json') $manifestBytes
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try {
    $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
} finally {
    $rsa.Dispose()
}
Write-NewBytes (Join-Path $expandedPartial 'PORTAL_REQUEST_MANIFEST.sig') $signature
Move-Item -LiteralPath $expandedPartial -Destination $expandedReady
& $verifierPath -PackagePath $expandedReady -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH | Out-Null

[void](New-Item -ItemType Directory -Path $finalRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPath = Join-Path $finalRoot ($requestId + '.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($expandedReady, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
$gate = [ordered]@{
    schema='argos_ocv03_o3f15l4d3_sign_gate_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_O3F15L4D3_SIGNED_METADATA_DIAGNOSTIC_PACKAGE'
    requestId=$requestId
    expandedPackagePath=$expandedReady
    packageZipPath=$zipPath
    packageZipBytes=[int64](Get-Item -LiteralPath $zipPath).Length
    packageZipSha256=Get-Sha256 $zipPath
    requestManifestSha256=Get-Sha256 (Join-Path $expandedReady 'PORTAL_REQUEST_MANIFEST.json')
    requestSignatureSha256=Get-Sha256 (Join-Path $expandedReady 'PORTAL_REQUEST_MANIFEST.sig')
    signerThumbprint=$expectedThumbprint
    signatureCount=1
    exactPackageSignaturePassed=$true
    buildGateSha256=Get-Sha256 $buildGatePath
    contractSha256=Get-Sha256 $contractPath
    definitionSha256=Get-Sha256 $definitionPath
    payloadPinCount=17
    payloadFileCount=18
    maximumResultBytes=8388608
    endpointWorkerSha256=[string]$contract.routePins.endpointWorkerSha256
    installedRouteConfigEvidenceSha256=[string]$contract.routePins.installedRouteConfigEvidenceSha256
    queueSafetyGateSha256=[string]$contract.routePins.queueSafetyGateSha256
    maximumOwnedChildCount=1
    exactChildArguments=@($contract.child.arguments)
    fullFrontsideHoldCount=184
    patternedFrontHoldCount=12
    pathState=[string]$pathGate.state
    published=$false
    targetExecuted=$false
    imageBytesRead=$false
    mutationsPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}
Write-NewUtf8Json $signGatePath $gate
$gate | ConvertTo-Json -Depth 10
