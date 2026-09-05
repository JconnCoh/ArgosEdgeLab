#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18UQ0 builder requires Windows PowerShell 5.1 exactly.'
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Require-Pin([string]$Path, [string]$Sha256, [string]$State = '') {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18UQ0 dependency missing: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18UQ0 dependency hash changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        Require ([string]$record.state -eq $State) "R18UQ0 dependency state changed: $Path"
    }
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18UQ0'
$payloadSource = Join-Path $PSScriptRoot 'payload\R18UQ0.ps1'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$recoveryIntentPath = Join-Path $PSScriptRoot 'R18UQ0_RECOVERY_INTENT.json'
$recoveryGatePath = Join-Path $PSScriptRoot 'R18UQ0_RECOVERY_INTENT_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18UQ0_PATH_GATE.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18UQ0_CLONE_GATE.json'
$packageTest = Join-Path $PSScriptRoot 'Test-R18UQ0Package.ps1'
$pathTest = Join-Path $PSScriptRoot 'Test-R18UQ0PathPlan.ps1'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18UQ0_BUILD.json'
$historyAudit = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$recoveryTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$harnessTool = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'
$wrapperTool = Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$stageRoot = 'C:\R18UQ0P'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\R18UQ0V'
$stageTestRoot = 'C:\R18UQ0T'
$finalTestRoot = 'C:\R18UQ0X'
$stageTestGate = Join-Path $PSScriptRoot 'R18UQ0_STAGED_PACKAGE_REHEARSAL_GATE.json'
$finalTestGate = Join-Path $PSScriptRoot 'R18UQ0_FINAL_EXTRACTED_PACKAGE_REHEARSAL_GATE.json'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$zipName = $requestId + '.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'R18UQ0_FINAL_PACKAGE_GATE.json'

Require-Pin $payloadSource 'B6E5A12E2A3D2E5B1397F9CB169E82E32419A8BA21F2DF0B5CE71718D465F1AF'
Require-Pin $definitionPath 'CC393DAF0ED1FB3777EF95FE65494C7E1EEB62EBBAC8CF9DA246C03EBED73241'
Require-Pin $recoveryIntentPath 'D67407C520CF797ABBC15BC62C64D7B388D05D09CC65D408B075CEE1670A8649'
Require-Pin $recoveryGatePath 'D0C84A849EE66ACD76769751C9E50E1F33A63004E61A6C1AC0C418DB232384A5' 'PASS_ARGOS_RECOVERY_INTENT'
Require-Pin $pathGatePath 'A8BE45C14ED02B9C4212C30C0842475B7C3A0800DABC8B1F6DD2988AD7BAA797' 'PASS_R18UQ0_ROUND_TRIP_PATH_GATE'
Require-Pin $cloneGatePath '9DBF75E093F9F19CFEA258780578F0F972DBEA4E22500AAA3D385C0CFC809E1F' 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'
Require-Pin $packageTest '52BE577924E299703BDB620255E41D493EBF1E8A21060CADB17E8271186D5D87'
Require-Pin $pathTest '960799B88CEDBA7E2BB16C720D47F858CB8D326919D5652EBA68761E894AAD67'
Require-Pin $identityPath '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
Require-Pin $publicCertificate '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
Require-Pin $packageTester '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'
foreach ($path in @($preactionPath, $historyAudit, $preactionTool, $recoveryTool, $harnessTool, $wrapperTool)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "R18UQ0 build prerequisite missing: $path"
}

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Require ([string]$definition.state -eq 'DRAFT_MUTATE_B_CAPABILITY_BOOTSTRAP' -and [string]$definition.requestId -eq $requestId) 'R18UQ0 definition identity changed.'
Require ([string]$definition.targetRole -eq 'ARGOS' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/R18UQ0.ps1') 'R18UQ0 definition route changed.'
Require (@($definition.changes).Count -eq 1 -and @($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 0) 'R18UQ0 definition action cardinality changed.'
Require ([bool]$definition.publication.publicationAuthorized -and [int]$definition.publication.maximumPublications -eq 1 -and -not [bool]$definition.publication.retryAuthorized) 'R18UQ0 definition publication authority changed.'
Require ([string]$definition.mutationClassification.mode -eq 'MUTATE' -and [string]$definition.mutationClassification.remedy -eq 'B' -and [int]$definition.mutationClassification.endpointManagedInstalledFileCount -eq 1 -and -not [bool]$definition.mutationClassification.entryPointWritesPerformed) 'R18UQ0 mutation classification changed.'
$change = $definition.changes[0]
Require ([string]$change.installedSha256 -eq (Get-Sha256 $payloadSource) -and [int64]$change.bytes -eq [int64](Get-Item -LiteralPath $payloadSource).Length) 'R18UQ0 payload definition is stale.'

$recoveryResult = (& $recoveryTool -IntentPath $recoveryIntentPath -ProjectRoot $project -Preflight -AsJson | Out-String) | ConvertFrom-Json
Require ([string]$recoveryResult.state -eq 'PASS_ARGOS_RECOVERY_INTENT') 'R18UQ0 recovery-intent preflight failed.'
$preactionResult = (& $preactionTool -AuditPath $historyAudit -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18UQ0 zero-recurrence preaction failed.'
$preaction = Get-Content -LiteralPath $preactionPath -Raw | ConvertFrom-Json
$builderSelf = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$builderRelative = $builderSelf.Substring($project.TrimEnd('\').Length + 1).Replace('\', '/')
$builderPins = @($preaction.dependencies | Where-Object { [string]$_.path -eq $builderRelative })
Require ($builderPins.Count -eq 1 -and [string]$builderPins[0].sha256 -eq (Get-Sha256 $builderSelf)) 'R18UQ0 preaction does not pin the exact builder.'

foreach ($scriptPath in @($payloadSource, $packageTest, $pathTest, $builderSelf)) {
    $harness = (& $harnessTool -PowerShellScript $scriptPath -Preflight -AsJson | Out-String) | ConvertFrom-Json
    Require ([string]$harness.state -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY') "R18UQ0 harness safety failed: $scriptPath"
    $wrapper = (& $wrapperTool -PowerShellScript $scriptPath -RequirePreflightSwitch -AsJson | Out-String) | ConvertFrom-Json
    Require ([string]$wrapper.state -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') "R18UQ0 wrapper safety failed: $scriptPath"
}

foreach ($path in @($stageRoot, $readyRoot, $stageZip, $verifyRoot, $stageTestRoot, $finalTestRoot, $stageTestGate, $finalTestGate, $finalPartial, $finalRoot, $finalGatePath)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18UQ0 fresh build output exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r18uq0_build_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18UQ0_BUILD_PREFLIGHT'
        requestId = $requestId
        payloadSha256 = Get-Sha256 $payloadSource
        recoveryIntentState = [string]$recoveryResult.state
        preactionState = [string]$preactionResult.state
        outputPathsFresh = $true
        signingKeyAccessed = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path (Join-Path $readyRoot 'payload') -Force)
$stagedPayload = Join-Path $readyRoot 'payload\R18UQ0.ps1'
Copy-Item -LiteralPath $payloadSource -Destination $stagedPayload -ErrorAction Stop
Require ((Get-Sha256 $stagedPayload) -eq (Get-Sha256 $payloadSource)) 'R18UQ0 staged payload changed.'

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
Require ($thumbprint -eq 'C82181052919C475CF888F49427C1B55AE65DC12') 'R18UQ0 laptop signer identity changed.'
$created = [DateTimeOffset]::UtcNow
$requestManifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = $requestId
    createdUtc = $created.ToString('o')
    expiresUtc = $created.AddDays(2).ToString('o')
    targetRole = 'ARGOS'
    jobClass = 'MAINTENANCE_PATCH'
    handler = 'SIGNED_REVIEW_ONLY_PATCH_V1'
    maxResultBytes = [int64]$definition.maxResultBytes
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    credentialsIncluded = $false
    signerThumbprint = $thumbprint
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    files = @([ordered]@{path='payload/R18UQ0.ps1';bytes=[int64](Get-Item -LiteralPath $stagedPayload).Length;sha256=Get-Sha256 $stagedPayload})
    entryPoint = 'payload/R18UQ0.ps1'
    changes = @($definition.changes)
    allowedTaskActions = @()
    allowedProcessActions = @()
    rehearsal = [ordered]@{required=$true;requiredState='PASS_R18UQ0_ARGOS_INSITE_RUNTIME_AUDIT'}
    mutationContract = [ordered]@{mode='MUTATE';remedy='B';endpointManagedInstalledFileCount=1;entryPointWritesPerformed=$false;queryExecuted=$false;taskOrProcessActionPerformed=$false;imageBytesRead=$false;jbodContacted=$false}
    publicationContract = [ordered]@{maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseRequired=$true}
}
$manifestPath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'
Write-JsonCreateNew -Path $manifestPath -Value $requestManifest -Depth 16
$manifestBytes = [IO.File]::ReadAllBytes($manifestPath)

$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $certificateMatches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint })
    Require ($certificateMatches.Count -eq 1 -and $certificateMatches[0].HasPrivateKey) 'R18UQ0 signing certificate/private key changed.'
    $privateRsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificateMatches[0])
    Require ($null -ne $privateRsa) 'R18UQ0 RSA private key is unavailable.'
    try {
        $signatureBytes = $privateRsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    }
    finally { $privateRsa.Dispose() }
}
finally { $store.Close(); $store.Dispose() }
$signatureStream = New-Object IO.FileStream($signaturePath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $signatureStream.Write($signatureBytes, 0, $signatureBytes.Length) } finally { $signatureStream.Dispose() }

$stagedVerification = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole ARGOS -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$stagedVerification.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18UQ0 staged package signature failed.'
$stagePreflight = (& $packageTest -Preflight -RequestRoot $readyRoot | Out-String) | ConvertFrom-Json
Require ([string]$stagePreflight.state -eq 'PASS_R18UQ0_PACKAGE_REHEARSAL_PREFLIGHT') 'R18UQ0 staged package-test preflight failed.'
& $packageTest -Test -RequestRoot $readyRoot -TestRoot $stageTestRoot -GatePath $stageTestGate | Out-Null
$stageGate = Get-Content -LiteralPath $stageTestGate -Raw | ConvertFrom-Json
Require ([string]$stageGate.state -eq 'PASS_R18UQ0_PACKAGE_REHEARSAL' -and [bool]$stageGate.approvedPredecessorExercised -and [bool]$stageGate.targetIdempotenceAccepted -and [bool]$stageGate.unapprovedPredecessorRefusedBeforeMutation -and [bool]$stageGate.injectedPostSwapRollbackPassed) 'R18UQ0 staged rehearsal failed.'

[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $stageZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[void](New-Item -ItemType Directory -Path $verifyRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($stageZip, $verifyRoot)
$verifyFiles = @(Get-ChildItem -LiteralPath $verifyRoot -File -Recurse)
Require ($verifyFiles.Count -eq 3) 'R18UQ0 final ZIP member count changed.'
$extractedVerification = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole ARGOS -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$extractedVerification.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18UQ0 extracted package signature failed.'
& $packageTest -Test -RequestRoot $verifyRoot -TestRoot $finalTestRoot -GatePath $finalTestGate | Out-Null
$finalTest = Get-Content -LiteralPath $finalTestGate -Raw | ConvertFrom-Json
Require ([string]$finalTest.state -eq 'PASS_R18UQ0_PACKAGE_REHEARSAL' -and [string]$finalTest.payloadSha256 -eq (Get-Sha256 $payloadSource)) 'R18UQ0 extracted package rehearsal failed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
$partialZip = Join-Path $finalPartial $zipName
Copy-Item -LiteralPath $stageZip -Destination $partialZip -ErrorAction Stop
Require ((Get-Sha256 $partialZip) -eq (Get-Sha256 $stageZip)) 'R18UQ0 final partial ZIP changed.'
Move-Item -LiteralPath $finalPartial -Destination $finalRoot -ErrorAction Stop
$finalZip = Join-Path $finalRoot $zipName
$finalGate = [ordered]@{
    schema = 'argos_r18uq0_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18UQ0_SIGNED_UNPUBLISHED_PACKAGE_GATE'
    artifactLifecycle = 'SIGNED'
    requestId = $requestId
    requestZip = 'work/OPENCV_SCRIBE_R18UQ0/final/REQ_R18UQ0.ready.zip'
    requestZipBytes = [int64](Get-Item -LiteralPath $finalZip).Length
    requestZipSha256 = Get-Sha256 $finalZip
    requestManifestSha256 = Get-Sha256 $manifestPath
    requestSignatureSha256 = Get-Sha256 $signaturePath
    payloadSha256 = Get-Sha256 $payloadSource
    finalZipMemberCount = $verifyFiles.Count
    finalZipMembers = @($verifyFiles | ForEach-Object { $_.FullName.Substring($verifyRoot.TrimEnd('\').Length + 1).Replace('\', '/') } | Sort-Object)
    stagedSignatureVerified = $true
    extractedSignatureVerified = $true
    stagedRehearsalGateSha256 = Get-Sha256 $stageTestGate
    extractedRehearsalGateSha256 = Get-Sha256 $finalTestGate
    pathGateSha256 = Get-Sha256 $pathGatePath
    cloneGateSha256 = Get-Sha256 $cloneGatePath
    buildPreactionSha256 = Get-Sha256 $preactionPath
    approvedPredecessorExercised = $true
    targetIdempotenceAccepted = $true
    unapprovedPredecessorRefusedBeforeMutation = $true
    injectedPostSwapRollbackPassed = $true
    endpointManagedInstalledFileCount = 1
    entryPointWritesPerformed = $false
    taskActions = @()
    processActions = @()
    queryExecuted = $false
    imageBytesRead = $false
    jbodContacted = $false
    publicationAuthorized = $true
    maximumPublications = 1
    retryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path $finalGatePath -Value $finalGate -Depth 16
$finalGate | ConvertTo-Json -Depth 16
