#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$BuildSign,
    [switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function New-Json([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F16U12 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Require (@(@($Preflight, $BuildSign, $Publish) | Where-Object { $_ }).Count -eq 1) 'Specify exactly one action.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'O3F16U12 package utility requires Windows PowerShell 5.1.'

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$packageRoot = 'C:\O3F16U12PK1'
$unsignedPayload = Join-Path $packageRoot 'payload'
$signedRoot = Join-Path $packageRoot 'signed'
$finalRoot = Join-Path $PSScriptRoot 'final_o3f16u12'
$signGatePath = Join-Path $PSScriptRoot 'O3F16U12_SIGN_GATE.json'
$routeGatePath = Join-Path $finalRoot 'O3F16U12_PREPUBLICATION_PATH_GATE.json'
$attemptPath = Join-Path $PSScriptRoot 'O3F16U12_PUBLISH_ATTEMPT.json'
$publishGatePath = Join-Path $PSScriptRoot 'O3F16U12_PUBLISH_GATE.json'
$invokeSource = Join-Path $PSScriptRoot 'Invoke-O3F16U12.ps1'
$r12Source = Join-Path $project 'work\O3F8\AnnularUnwrapDiagnosticOpenCvR12.py'
$carrierSource = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3K1\OCV03_NotchReviewOpenCvV1.py'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$certificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$parentRouteGate = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3F8R13T5\final_o3f8r13t5\O3F8R13T5_PREPUBLICATION_PATH_R4_GATE.json'
$priorTerminalGate = Join-Path $project 'work\OPENCV_EDGE_UNWRAP_O3F16U10\O3F16U10_OBS1_TERMINAL_VISUAL_GATE.json'
$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestRoot = 'U:\ProjectPortalRO\requests'
$invokeHash = '0B556B98243C09939F0AFF3AD7749A66ED994497AA33CA264438E65D362AE594'
$r12Hash = '1696DBE407E4461B351C6B939C591A4E652E558DF15BF4AC5CEFB369950FF7F6'
$carrierHash = '6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'

foreach ($pin in @(
    @($invokeSource, $invokeHash),
    @($r12Source, $r12Hash),
    @($carrierSource, $carrierHash),
    @($parentRouteGate, '0CB055D73381F036E126566B8EB7CEA90E8114D0A6C90D9E100AA9375B7708A0'),
    @($priorTerminalGate, '7F0CDF880CD8A4E5FB348068830339486630C8AA6911F8CC1131C33DDFB46BF9')
)) {
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "O3F16U12 dependency absent: $($pin[0])"
    Require ((Sha $pin[0]) -ceq $pin[1]) "O3F16U12 dependency hash changed: $($pin[0])"
}
foreach ($path in @($identityPath, $certificatePath, $verifier)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F16U12 signing dependency absent: $path"
}
$prior = Get-Content -LiteralPath $priorTerminalGate -Raw | ConvertFrom-Json
Require ([string]$prior.portalRoundTrip.requestId -ceq 'REQ_20260904T011547893Z_A5EB49CD10A1' -and [string]$prior.portalRoundTrip.responseId -ceq 'R_61F3CAD40107_20260904011738470_715b8268' -and [bool]$prior.portalRoundTrip.signatureVerified) 'O3F16U12 prior serial request is not signed-terminal U10 OBS1.'
$parentRoute = Get-Content -LiteralPath $parentRouteGate -Raw | ConvertFrom-Json
Require ([string]$parentRoute.state -ceq 'PASS_O3F8R13T5_COMPLETE_ROUTE_PATH_R4_GATE' -and [int]$parentRoute.maximumEffectiveLength -lt 200 -and [int]$parentRoute.maximumComponentLength -le 80) 'O3F16U12 inherited route gate changed.'

$plannedId = 'REQ_20260904T235959999Z_0123456789AB'
$plannedReady = Join-Path $signedRoot ($plannedId + '.ready')
$plannedZip = Join-Path $finalRoot ($plannedId + '.ready.zip')
$plannedCandidates = @(
    $packageRoot,
    $unsignedPayload,
    $signedRoot,
    $finalRoot,
    (Join-Path $plannedReady 'payload\AnnularUnwrapDiagnosticOpenCvR12.py'),
    (Join-Path $plannedReady 'PORTAL_REQUEST_MANIFEST.json'),
    $plannedZip,
    (Join-Path $requestRoot ($plannedId + '.ready.zip.upload')),
    (Join-Path $requestRoot ($plannedId + '.ready.zip')),
    $signGatePath,
    $routeGatePath,
    $attemptPath,
    $publishGatePath
)
$pathCheck = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $plannedCandidates -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathCheck.state -ceq 'PASS_PATH_BUDGET') 'O3F16U12 package/publication path preflight failed.'
$maximumPlannedEffectiveLength = [int](($pathCheck.candidates | Measure-Object -Property effectiveLength -Maximum).Maximum)

if ($Preflight) {
    Require (-not (Test-Path -LiteralPath $packageRoot)) 'O3F16U12 package root already exists.'
    Require (-not (Test-Path -LiteralPath $finalRoot)) 'O3F16U12 final root already exists.'
    Require (-not (Test-Path -LiteralPath $signGatePath)) 'O3F16U12 sign gate already exists.'
    [ordered]@{
        schema = 'argos_ocv03_o3f16u12_build_sign_publish_preflight_v1'
        state = 'PASS_O3F16U12_BUILD_SIGN_PUBLISH_PREFLIGHT'
        r12Sha256 = $r12Hash
        payloadFileCount = 3
        sourcePayloadPinsPassed = $true
        requestedCaseCount = 4
        inheritedRouteGateSha256 = Sha $parentRouteGate
        priorSignedTerminalRequestId = [string]$prior.portalRoundTrip.requestId
        pathState = [string]$pathCheck.state
        maximumPlannedEffectiveLength = $maximumPlannedEffectiveLength
        externalWritePerformed = $false
        mutationsPerformed = $false
        reviewOnly = $true
    } | ConvertTo-Json -Depth 8
    return
}

if ($BuildSign) {
    foreach ($path in @($packageRoot, $finalRoot, $signGatePath)) {
        Require (-not (Test-Path -LiteralPath $path)) "O3F16U12 create-new build target exists: $path"
    }
    [void](New-Item -ItemType Directory -Path $unsignedPayload)
    [void](New-Item -ItemType Directory -Path $signedRoot)
    [void](New-Item -ItemType Directory -Path $finalRoot)
    [IO.File]::Copy($invokeSource, (Join-Path $unsignedPayload 'Invoke-O3F16U12.ps1'), $false)
    [IO.File]::Copy($r12Source, (Join-Path $unsignedPayload 'AnnularUnwrapDiagnosticOpenCvR12.py'), $false)
    [IO.File]::Copy($carrierSource, (Join-Path $unsignedPayload 'OCV03_NotchReviewOpenCvV1.py'), $false)
    $actual = @(Get-ChildItem -LiteralPath $unsignedPayload -File | Sort-Object Name)
    Require ($actual.Count -eq 3) 'O3F16U12 unsigned payload cardinality changed.'
    Require ((Sha (Join-Path $unsignedPayload 'Invoke-O3F16U12.ps1')) -ceq $invokeHash) 'O3F16U12 copied entrypoint changed.'
    Require ((Sha (Join-Path $unsignedPayload 'AnnularUnwrapDiagnosticOpenCvR12.py')) -ceq $r12Hash) 'O3F16U12 copied detector changed.'
    Require ((Sha (Join-Path $unsignedPayload 'OCV03_NotchReviewOpenCvV1.py')) -ceq $carrierHash) 'O3F16U12 copied carrier changed.'
    $leaf = & (Join-Path $unsignedPayload 'Invoke-O3F16U12.ps1') -PackageLeafPreflight | ConvertFrom-Json
    Require ([string]$leaf.state -ceq 'PASS_O3F16U12_PACKAGE_LEAVES') 'O3F16U12 assembled package-leaf preflight failed.'

    $identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
    $thumb = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
    $certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumb") -ErrorAction Stop
    Require ([bool]$certificate.HasPrivateKey) 'O3F16U12 signer private key unavailable.'
    $created = [DateTimeOffset]::UtcNow
    $requestId = 'REQ_' + $created.ToString('yyyyMMddTHHmmssfffZ') + '_' + ([Guid]::NewGuid().ToString('N').Substring(0, 12).ToUpperInvariant())
    $partial = Join-Path $signedRoot ($requestId + '.partial')
    $ready = Join-Path $signedRoot ($requestId + '.ready')
    [void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload'))
    foreach ($item in $actual) { [IO.File]::Copy($item.FullName, (Join-Path (Join-Path $partial 'payload') $item.Name), $false) }
    $files = @(Get-ChildItem -LiteralPath (Join-Path $partial 'payload') -File | Sort-Object Name | ForEach-Object {
        [ordered]@{path = 'payload/' + $_.Name; bytes = [int64]$_.Length; sha256 = Sha $_.FullName}
    })
    $manifest = [ordered]@{
        schema = 'argos_project_portal_request_manifest_v1'
        requestId = $requestId
        createdUtc = $created.ToString('o')
        expiresUtc = $created.AddHours(24).ToString('o')
        targetRole = 'JBOD'
        jobClass = 'MAINTENANCE_PATCH'
        handler = ''
        maxResultBytes = 1048576
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
        productionRoutingEnabled = $false
        credentialsIncluded = $false
        signerThumbprint = $thumb
        signatureAlgorithm = 'RSA-SHA256-PKCS1'
        files = $files
        entryPoint = 'payload/Invoke-O3F16U12.ps1'
        changes = @([ordered]@{
            source = 'payload/OCV03_NotchReviewOpenCvV1.py'
            destination = 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py'
            approvedPredecessorSha256 = @($carrierHash)
            installedSha256 = $carrierHash
            allowCreate = $false
        })
        entryPointMutations = @(
            [ordered]@{action = 'COPY_EXACT_R12_TO_EXISTING_JBOD_DEVELOPMENT_ROOT'; target = 'D:/O3F15L4E5RT/AnnularUnwrapDiagnosticOpenCvR12.py'},
            [ordered]@{action = 'RUN_FOUR_CASE_REVIEW_ONLY_ANNULAR_DIAGNOSTIC_FOREGROUND'; target = 'D:/O3F16U12'},
            [ordered]@{action = 'CREATE_PORTAL_READABLE_RESULT_ARCHIVE'; target = 'D:/KLARFExport/_ArgosReview/O3F16U12_20260904.zip'}
        )
        entryPointOutputs = @(
            [ordered]@{path = 'D:/O3F16U12/SUMMARY.json'; requiredAtCompletion = $true},
            [ordered]@{path = 'D:/KLARFExport/_ArgosReview/O3F16U12_20260904.zip'; requiredAtCompletion = $true}
        )
        sourceProcessingContract = [ordered]@{
            side = 'FRONT'; expectedPairCount = 4; detectorRevision = 'R12'; detectorSha256 = $r12Hash
            outputRoot = 'D:/O3F16U12'; sourceMutationAllowed = $false; selectorThresholdRelaxationAllowed = $false
            automaticHoldClearanceAllowed = $false; notchSelectionPerformed = $false
        }
        timeoutContract = [ordered]@{entryPointSeconds = 1800; endpointResponseIsTerminal = $true}
        allowedTaskActions = @()
        allowedProcessActions = @('START_ONE_BOUNDED_OWNED_O3F16U12_DETECTOR_CHILD', 'TERMINATE_ONLY_NEWLY_OWNED_CHILD_ON_TIMEOUT')
        requestRetryAuthorized = $false
    }
    $manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
    finally { $rsa.Dispose() }
    [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
    Move-Item -LiteralPath $partial -Destination $ready
    & $verifier -PackagePath $ready -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = Join-Path $finalRoot ($requestId + '.ready.zip')
    [IO.Compression.ZipFile]::CreateFromDirectory($ready, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
    $routeGate = [ordered]@{
        schema = 'argos_ocv03_o3f16u12_prepublication_path_gate_v1'; state = 'PASS_O3F16U12_COMPLETE_ROUTE_PATH_GATE'
        requestId = $requestId; requestManifestSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json')
        signedPackageZipSha256 = Sha $zip; inheritedRouteGatePath = 'work/OPENCV_EDGE_NOTCH_O3F8R13T5/final_o3f8r13t5/O3F8R13T5_PREPUBLICATION_PATH_R4_GATE.json'
        inheritedRouteGateSha256 = Sha $parentRouteGate; routeImplementationChanged = $false
        inheritedMaximumEffectiveLength = [int]$parentRoute.maximumEffectiveLength; inheritedMaximumComponentLength = [int]$parentRoute.maximumComponentLength
        localPlannedPathState = [string]$pathCheck.state; suffixReserve = 32; publicationCountMaximum = 1
        requestRetryAuthorized = $false; reviewOnly = $true; productionRoutingEnabled = $false
    }
    New-Json $routeGatePath $routeGate
    $signGate = [ordered]@{
        schema = 'argos_ocv03_o3f16u12_sign_gate_v1'; state = 'PASS_O3F16U12_SIGNED_FOUR_CASE_PACKAGE'
        requestId = $requestId; packagePath = $ready; packageZipPath = $zip
        packageZipBytes = [int64](Get-Item -LiteralPath $zip).Length; packageZipSha256 = Sha $zip
        manifestSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'); signatureSha256 = Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
        routeGateSha256 = Sha $routeGatePath; signerThumbprint = $thumb; payloadFileCount = 3
        r12Sha256 = $r12Hash; requestedCaseCount = 4; signed = $true; published = $false
        targetExecuted = $false; requestRetryAuthorized = $false; reviewOnly = $true; productionRoutingEnabled = $false
    }
    New-Json $signGatePath $signGate
    $signGate | ConvertTo-Json -Depth 12
    return
}

Require (Test-Path -LiteralPath $signGatePath -PathType Leaf) 'O3F16U12 sign gate is absent.'
Require (Test-Path -LiteralPath $routeGatePath -PathType Leaf) 'O3F16U12 route gate is absent.'
Require (-not (Test-Path -LiteralPath $attemptPath)) 'O3F16U12 publication attempt already exists; retry forbidden.'
Require (-not (Test-Path -LiteralPath $publishGatePath)) 'O3F16U12 publication gate already exists.'
$sign = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
$route = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
Require ([string]$sign.state -ceq 'PASS_O3F16U12_SIGNED_FOUR_CASE_PACKAGE' -and [string]$route.state -ceq 'PASS_O3F16U12_COMPLETE_ROUTE_PATH_GATE') 'O3F16U12 signed or route gate changed.'
$zipPath = [string]$sign.packageZipPath
Require (Test-Path -LiteralPath $zipPath -PathType Leaf) 'O3F16U12 signed ZIP is absent.'
Require ((Sha $zipPath) -ceq [string]$sign.packageZipSha256 -and (Sha $routeGatePath) -ceq [string]$sign.routeGateSha256) 'O3F16U12 signed package evidence changed.'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'O3F16U12 persistent U: mapping changed.'
Require (Test-Path -LiteralPath $requestRoot -PathType Container) 'O3F16U12 request root unavailable.'
$pending = @(Get-ChildItem -LiteralPath $requestRoot -File | Where-Object { $_.Name -cmatch '\.ready\.zip(?:\.upload)?$' })
Require ($pending.Count -eq 0) ('O3F16U12 blocked by pending request: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
$requestId = [string]$sign.requestId
$readyPath = Join-Path $requestRoot ($requestId + '.ready.zip')
$uploadPath = $readyPath + '.upload'
Require (-not (Test-Path -LiteralPath $readyPath) -and -not (Test-Path -LiteralPath $uploadPath)) 'O3F16U12 request path collision.'
$attempt = [ordered]@{
    schema = 'argos_ocv03_o3f16u12_publish_attempt_v1'; state = 'STARTED_O3F16U12_SINGLE_PUBLICATION_ATTEMPT'
    requestId = $requestId; sourceZip = $zipPath; sourceZipBytes = [int64]$sign.packageZipBytes
    sourceZipSha256 = [string]$sign.packageZipSha256; uploadPath = $uploadPath; readyPath = $readyPath
    attemptCount = 1; committedBeforeExternalWrite = $true; requestRetryAuthorized = $false
    reviewOnly = $true; productionRoutingEnabled = $false
}
New-Json $attemptPath $attempt
$source = [IO.File]::Open($zipPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
$destination = $null
try {
    $destination = New-Object IO.FileStream($uploadPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    $source.CopyTo($destination, 1048576)
    $destination.Flush()
} finally {
    if ($null -ne $destination) { $destination.Dispose() }
    $source.Dispose()
}
Require ((Get-Item -LiteralPath $uploadPath).Length -eq [int64]$sign.packageZipBytes -and (Sha $uploadPath) -ceq [string]$sign.packageZipSha256) 'O3F16U12 upload verification failed; no retry authorized.'
$transition = @(Get-ChildItem -LiteralPath $requestRoot -File | Where-Object { $_.Name -cmatch '\.ready\.zip(?:\.upload)?$' })
Require ($transition.Count -eq 1 -and $transition[0].FullName.Equals($uploadPath, [StringComparison]::OrdinalIgnoreCase)) 'O3F16U12 queue changed before atomic publication.'
[IO.File]::Move($uploadPath, $readyPath)
$publishGate = [ordered]@{
    schema = 'argos_ocv03_o3f16u12_publish_gate_v1'; state = 'PASS_O3F16U12_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_TERMINAL_RESPONSE'
    disposition = 'PENDING_GATE'; requestId = $requestId; sourceZip = $zipPath
    publishedPath = $readyPath; publishedBytes = [int64]$sign.packageZipBytes; publishedSha256 = [string]$sign.packageZipSha256
    publicationCount = 1; publicationAttemptPath = $attemptPath; publicationAttemptSha256 = Sha $attemptPath
    atomicSameDirectoryUploadToReadyRename = $true; overwritePerformed = $false; automaticRetryAuthorized = $false
    priorSignedTerminalRequestId = [string]$prior.portalRoundTrip.requestId; priorSignedTerminalResponseId = [string]$prior.portalRoundTrip.responseId
    sourceMutationOrDeletionPerformed = $false; existingTaskOrProcessActionCount = 0; providerActivated = $false
    holdsAutomaticallyCleared = $false; reviewOnly = $true; trainingEligible = $false; xmlEligible = $false
    productionEligible = $false; productionRoutingEnabled = $false
}
New-Json $publishGatePath $publishGate
$publishGate | ConvertTo-Json -Depth 12
