#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Sign
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Write-NewBytes([string]$Path, [byte[]]$Bytes) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L4D1 create-new path exists: $Path"
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L4D1 create-new JSON exists: $Path"
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine),
        (New-Object Text.UTF8Encoding($false))
    )
}

Require (([bool]$Preflight) -xor ([bool]$Sign)) 'Specify exactly one of -Preflight or -Sign.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\O3F15L4D1PK'
$payloadRoot = Join-Path $root 'payload'
$definitionPath = Join-Path $root 'DEFINITION.json'
$buildGatePath = Join-Path $PSScriptRoot 'O3F15L4D1_BUILD_GATE.json'
$signGatePath = Join-Path $PSScriptRoot 'O3F15L4D1_SIGN_GATE.json'
$finalRoot = Join-Path $PSScriptRoot 'final_o3f15l4d1'
$signedRoot = Join-Path $root 'signed'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$certificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'

foreach ($path in @($definitionPath, $buildGatePath, $identityPath, $certificatePath, $verifier)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4D1 signing dependency absent: $path"
}
$buildGate = Get-Content -LiteralPath $buildGatePath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Require ([string]$buildGate.state -ceq 'PASS_O3F15L4D1_UNSIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE_BUILT' -and [string]$buildGate.definitionSha256 -ceq (Sha $definitionPath)) 'O3F15L4D1 build evidence changed.'
Require ([string]$definition.schema -ceq 'argos_ocv03_o3f15l4d1_maintenance_definition_v1' -and [string]$definition.state -ceq 'FROZEN_FOR_SIGNING' -and [string]$definition.entryPoint -ceq 'payload/Invoke-O3F15L4D1.ps1') 'O3F15L4D1 definition is not frozen for signing.'
Require (@($definition.changes).Count -eq 1 -and @($definition.entryPointMutations).Count -eq 0 -and @($definition.entryPointOutputs).Count -eq 0 -and @($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'O3F15L4D1 signed authority bounds changed.'
Require ([string]::Join('|', @($definition.sourceProcessingContract.exactChildArguments)) -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT' -and [int64]$definition.maxResultBytes -eq 8388608 -and -not [bool]$definition.sourceProcessingContract.selfTestAllowed -and -not [bool]$definition.sourceProcessingContract.gateAllowed -and -not [bool]$definition.sourceProcessingContract.runAllowed -and -not [bool]$definition.sourceProcessingContract.detectorResultRootCreationAllowed -and -not [bool]$definition.sourceProcessingContract.imageBytesReadAllowed) 'O3F15L4D1 signed child boundary changed.'
$change = @($definition.changes)[0]
$carrierHash = '6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
Require ([string]$change.source -ceq 'payload/OCV03_NotchReviewOpenCvV1.py' -and [string]$change.destination -ceq 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py' -and [string]$change.installedSha256 -ceq $carrierHash -and @($change.approvedPredecessorSha256).Count -eq 1 -and [string]$change.approvedPredecessorSha256[0] -ceq $carrierHash -and -not [bool]$change.allowCreate) 'O3F15L4D1 same-bytes carrier contract changed.'
$actual = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
Require ($actual.Count -eq [int]$buildGate.payloadFileCount) 'O3F15L4D1 payload cardinality changed.'
foreach ($row in @($buildGate.payloadFiles)) {
    $path = Join-Path $payloadRoot ([string]$row.path)
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4D1 payload absent: $($row.path)"
    Require ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes -and (Sha $path) -ceq [string]$row.sha256) "O3F15L4D1 payload changed: $($row.path)"
}
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Require ([bool]$certificate.HasPrivateKey) 'O3F15L4D1 signer private key unavailable.'
$plannedRequest = 'REQ_20260903T235959999Z_0123456789AB'
$plannedReady = Join-Path $signedRoot ($plannedRequest + '.ready')
$plannedZip = Join-Path $finalRoot ($plannedRequest + '.ready.zip')
$longestPayload = @($actual | Sort-Object { $_.Name.Length } -Descending | Select-Object -First 1)[0].Name
$planned = @(
    $finalRoot,
    $signedRoot,
    (Join-Path $plannedReady (Join-Path 'payload' $longestPayload)),
    (Join-Path $plannedReady 'PORTAL_REQUEST_MANIFEST.json'),
    $plannedZip,
    $signGatePath
)
$pathGate = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'O3F15L4D1 final package path gate failed.'
foreach ($path in @($finalRoot, $signedRoot, $signGatePath)) {
    Require (-not (Test-Path -LiteralPath $path)) "O3F15L4D1 create-new signing target exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f15l4d1_sign_preflight_v1'
        state = 'PASS_O3F15L4D1_SIGN_PREFLIGHT'
        definitionSha256 = Sha $definitionPath
        buildGateSha256 = Sha $buildGatePath
        payloadFileCount = $actual.Count
        finalRoot = $finalRoot
        expandedSigningRoot = $signedRoot
        pathState = [string]$pathGate.state
        signerThumbprint = $thumbprint
        maximumOwnedChildCount = 1
        exactStage = 'PREFLIGHT'
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $finalRoot)
[void](New-Item -ItemType Directory -Path $signedRoot)
$created = [DateTimeOffset]::UtcNow
$requestId = 'REQ_' + $created.ToString('yyyyMMddTHHmmssfffZ') + '_' + ([Guid]::NewGuid().ToString('N').Substring(0, 12).ToUpperInvariant())
$partial = Join-Path $signedRoot ($requestId + '.partial')
$ready = Join-Path $signedRoot ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload') -Force)
foreach ($item in $actual) {
    [IO.File]::Copy($item.FullName, (Join-Path (Join-Path $partial 'payload') $item.Name), $false)
}
$files = @(Get-ChildItem -LiteralPath (Join-Path $partial 'payload') -File | Sort-Object Name | ForEach-Object {
    [ordered]@{ path = 'payload/' + $_.Name; bytes = [int64]$_.Length; sha256 = Sha $_.FullName }
})
Require ($files.Count -eq $actual.Count) 'O3F15L4D1 signed payload cardinality changed.'
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
    files = $files
    entryPoint = [string]$definition.entryPoint
    changes = @($definition.changes)
    entryPointMutations = @()
    entryPointOutputs = @()
    sourceProcessingContract = $definition.sourceProcessingContract
    timeoutContract = $definition.timeoutContract
    allowedTaskActions = @()
    allowedProcessActions = @($definition.allowedProcessActions)
    rehearsal = $definition.rehearsal
    requestRetryAuthorized = $false
}
$manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
Write-NewBytes (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json') $manifestBytes
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try {
    $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
} finally {
    $rsa.Dispose()
}
Write-NewBytes (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig') $signature
Move-Item -LiteralPath $partial -Destination $ready
& $verifier -PackagePath $ready -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = Join-Path $finalRoot ($requestId + '.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($ready, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
$gate = [ordered]@{
    schema = 'argos_ocv03_o3f15l4d1_sign_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3F15L4D1_SIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE'
    requestId = $requestId
    finalRoot = $finalRoot
    packagePath = $ready
    packageZipPath = $zip
    packageZipBytes = [int64](Get-Item -LiteralPath $zip).Length
    packageZipSha256 = Sha $zip
    manifestSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json')
    signatureSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
    signerThumbprint = $thumbprint
    exactPackageSignaturePassed = $true
    payloadFileCount = $files.Count
    pythonCacheLeafCount = 0
    contractSha256 = [string]$buildGate.contractSha256
    definitionSha256 = [string]$buildGate.definitionSha256
    endpointWorkerSha256 = [string]$buildGate.endpointWorkerSha256
    installedRouteConfigEvidenceSha256 = [string]$buildGate.installedRouteConfigEvidenceSha256
    queueSafetyGateSha256 = [string]$buildGate.queueSafetyGateSha256
    maximumOwnedChildCount = 1
    exactStage = 'PREFLIGHT'
    fullFrontsideHoldCount = 184
    currentPatternedFrontHoldCount = 12
    allowedTaskActionCount = 0
    signed = $true
    published = $false
    targetExecuted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-NewJson $signGatePath $gate
$gate | ConvertTo-Json -Depth 10
