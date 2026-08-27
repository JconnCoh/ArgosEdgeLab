#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3K1_DATA_PULL_BUILD_INVOCATION.json'))
$definitionPath = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_DEFINITION.json'
$intentPath = Join-Path $PSScriptRoot 'O3K1_RECOVERY_INTENT.json'
$renderTerminalPath = Join-Path $PSScriptRoot 'O3K1_RENDER_RESPONSE_COLLECTION_GATE.json'
$inheritedRoutePath = Join-Path $PSScriptRoot 'O3K1_COMPLETE_ROUTE_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_O3K1_BUILD_DATA_PULL.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageBuilder = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\New-SignedPortalPackage.ps1'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$intentTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$signedRoot = Join-Path $PSScriptRoot 'dp'
$finalRoot = Join-Path $PSScriptRoot 'dpf'
$finalPartial = $finalRoot + '.partial'
$packageGatePath = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'O3K1_DATA_PULL_COMPLETE_ROUTE_GATE.json'
$expectedDefinitionSha256 = '76AE3EDAC0F23FC40372C36E65CE3448230D099024983851FC7F79F440A38316'
$expectedIntentSha256 = '8D4B2D8E2443572F16D7D1988BDDA0D2E5DD18F0850119978B11E9A711430B9D'
$expectedRenderTerminalSha256 = '1CE3B6EC3AE63654DCA10B8113ED1DD04A9946EA40DF2A815226886967B7D4E4'
$expectedInheritedRouteSha256 = '74B5B8D29596D6DADB81CFE987584AE768D0BAC4F37FF63CE990403588BBF1E0'
$expectedPackageBuilderSha256 = '8AF7AF26B6899CB6475735FEE8AB6E5A29231AAED8EDA898F1E7F4B04A2A403F'
$expectedPackageTesterSha256 = '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'
$expectedIdentitySha256 = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$expectedPublicCertificateSha256 = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$expectedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$expectedConfigSha256 = '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'
$expectedQueueSafetySha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$expectedExportZipSha256 = 'CEE193475613E04D0AD25F0402437E3E21E310EF1F8B1312737B28463699F724'
$expectedExportZipBytes = [int64]5666342
$expectedRelativePath = 'OCV03ReviewExports/O3K1_20260827T200000Z/O3K1_REVIEW.zip'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3K1 DATA_PULL dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O3K1 DATA_PULL dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}
function Get-RoutePaths([string]$RequestId) {
    $responseId = 'R_0123456789AB_20260827235959999_a1b2c3d4'
    $responseReady = $responseId + '.ready'
    $returnedLeaf = 'data\JBOD_PROCESSOR_REVIEW\' + $expectedRelativePath.Replace('/','\')
    return @(
        (Join-Path $signedRoot ($RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json')),
        (Join-Path $signedRoot ($RequestId + '.ready\PORTAL_REQUEST_MANIFEST.sig')),
        (Join-Path $finalRoot ($RequestId + '.ready.zip')),
        (Join-Path $finalRoot ($RequestId + '.ready.zip.path_gate.json')),
        ('U:\ProjectPortalRO\requests\' + $RequestId + '.ready.zip.upload'),
        ('U:\ProjectPortalRO\requests\' + $RequestId + '.ready.zip'),
        ('C:\APR\S\requests\processed\' + $RequestId + '.ready.zip'),
        ('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
        ('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
        ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
        ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
        ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
        'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03ReviewExports\O3K1_20260827T200000Z\O3K1_REVIEW.zip',
        'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial',
        ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\DATA_PULL_PAYLOAD.zip'),
        ('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'),
        ('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
        ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
        ('C:\APR\R\pending\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'),
        ('C:\APR\A\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
        ('U:\ProjectPortalRO\responses\' + $responseReady + '.zip'),
        'C:\O3K1P\R.zip',
        'C:\O3K1P\R\PORTAL_RESPONSE_MANIFEST.json',
        'C:\O3K1P\R\DATA_PULL_PAYLOAD.zip',
        ('C:\O3K1D\' + $returnedLeaf)
    )
}

Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3K1 DATA_PULL invocation manifest path changed.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3k1_data_pull_build_invocation_v1' -and [string]$invocation.state -eq 'FROZEN_EXACT_BUILD_INVOCATION') 'O3K1 DATA_PULL invocation manifest state changed.'
Assert-True ([string]$invocation.powerShellScriptSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3K1 DATA_PULL invocation does not pin the exact builder.'
Assert-True ([string]$invocation.definitionSha256 -eq $expectedDefinitionSha256 -and [string]$invocation.renderTerminalResponseSha256 -eq $expectedRenderTerminalSha256) 'O3K1 DATA_PULL invocation dependency pins changed.'
Assert-True ([int]$invocation.maximumFiles -eq 1 -and [int64]$invocation.maximumBytes -eq 16777216 -and -not [bool]$invocation.requestRetryAuthorized) 'O3K1 DATA_PULL invocation bounds changed.'

Assert-Pin $definitionPath $expectedDefinitionSha256
Assert-Pin $intentPath $expectedIntentSha256
Assert-Pin $renderTerminalPath $expectedRenderTerminalSha256
Assert-Pin $inheritedRoutePath $expectedInheritedRouteSha256
Assert-Pin $packageBuilder $expectedPackageBuilderSha256
Assert-Pin $packageTester $expectedPackageTesterSha256
Assert-Pin $identityPath $expectedIdentitySha256
Assert-Pin $publicCertificatePath $expectedPublicCertificateSha256
foreach ($path in @($preactionPath,$historyPath,$intentTool,$preactionTool,$pathTool)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3K1 DATA_PULL gate dependency is absent: $path"
}

$intentResult = & $intentTool -IntentPath $intentPath -Preflight -AsJson | ConvertFrom-Json
Assert-True ([string]$intentResult.state -eq 'PASS_ARGOS_RECOVERY_INTENT') 'O3K1 DATA_PULL recovery intent failed.'
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -Preflight | Out-Null

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
$relativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL') 'O3K1 DATA_PULL route changed.'
Assert-True ([string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'O3K1 DATA_PULL approved root changed.'
Assert-True ($relativePaths.Count -eq 1 -and $relativePaths[0] -eq $expectedRelativePath) 'O3K1 DATA_PULL exact file set changed.'
Assert-True ([int]$definition.parameters.maximumFiles -eq 1) 'O3K1 DATA_PULL maximum file count changed.'
Assert-True ([int64]$definition.parameters.maximumBytes -eq 16777216 -and [int64]$definition.maxResultBytes -eq 16777216) 'O3K1 DATA_PULL byte bounds changed.'

$intent = Get-Content -Raw -LiteralPath $intentPath | ConvertFrom-Json
$terminal = Get-Content -Raw -LiteralPath $renderTerminalPath | ConvertFrom-Json
$inheritedRoute = Get-Content -Raw -LiteralPath $inheritedRoutePath | ConvertFrom-Json
Assert-True ([string]$intent.mode -eq 'MUTATE' -and [int]$intent.authorizationBoundary.liveEndpointRequestsMaximum -eq 2) 'O3K1 two-step authorization changed.'
$sequence = @($intent.authorizationBoundary.liveEndpointRequestSequence | ForEach-Object { [string]$_ })
Assert-True ($sequence.Count -eq 2 -and $sequence[1] -eq 'ONE_DATA_PULL_AFTER_THE_MATCHING_RENDER_TERMINAL_RESPONSE_TO_RETURN_THAT_EXACT_ZIP') 'O3K1 DATA_PULL sequence authorization changed.'
Assert-True (-not [bool]$intent.requestRetryAuthorized) 'O3K1 retry authority changed.'
Assert-True ([string]$terminal.state -eq 'PASS_O3K1_MATCHING_SIGNED_RENDER_RESPONSE_COLLECTED' -and [bool]$terminal.signatureVerified -and [bool]$terminal.dataPullNowEligible) 'O3K1 matching signed render terminal proof is absent.'
Assert-True ([string]$terminal.exportRelativePath -eq $expectedRelativePath -and [int64]$terminal.exportZipBytes -eq $expectedExportZipBytes -and [string]$terminal.exportZipSha256 -eq $expectedExportZipSha256) 'O3K1 rendered export identity changed.'
Assert-True ([string]$inheritedRoute.state -eq 'PASS_O3K1_COMPLETE_ROUTE_GATE') 'O3K1 inherited route gate changed.'
Assert-True ([string]$inheritedRoute.endpointWorkerSha256 -eq $expectedWorkerSha256 -and [string]$inheritedRoute.installedConfigEvidenceSha256 -eq $expectedConfigSha256 -and [string]$inheritedRoute.inheritedQueueSafetyGateSha256 -eq $expectedQueueSafetySha256) 'O3K1 installed route pins changed.'
Assert-True (-not [bool]$inheritedRoute.requestRetryAuthorized -and -not [bool]$inheritedRoute.gatewayAcceptanceIsExecutionEvidence) 'O3K1 route evidence semantics changed.'

$builderCommand = Get-Command -Name $packageBuilder -CommandType ExternalScript -ErrorAction Stop
$builderParameters = @($builderCommand.Parameters.Keys | ForEach-Object { [string]$_ })
foreach ($required in @('DefinitionPath','PayloadRoot','OutputRoot','IdentityStatePath')) {
    Assert-True ($builderParameters -contains $required) "O3K1 package builder argument is absent: $required"
}
$testerCommand = Get-Command -Name $packageTester -CommandType ExternalScript -ErrorAction Stop
$testerParameters = @($testerCommand.Parameters.Keys | ForEach-Object { [string]$_ })
foreach ($required in @('PackagePath','SignerCertificatePath','ExpectedTargetRole','ExpectedJobClass')) {
    Assert-True ($testerParameters -contains $required) "O3K1 package tester argument is absent: $required"
}

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'O3K1 DATA_PULL requires matching local/origin branch tips.'
foreach ($path in @($signedRoot,$finalRoot,$finalPartial,$packageGatePath,$routeGatePath)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3K1 DATA_PULL create-new output exists: $path"
}

$placeholderRequestId = 'REQ_20260827T203000111Z_62629419O3K1P'
$plannedPaths = @(Get-RoutePaths -RequestId $placeholderRequestId)
$plannedPathGate = & $pathTool -CandidatePath $plannedPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$plannedPathGate.state -eq 'PASS_PATH_BUDGET') 'O3K1 DATA_PULL complete round-trip path budget failed.'
$plannedMaximumEffective = [int](($plannedPathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$plannedMaximumComponent = [int](($plannedPathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)

if ($Preflight) {
    [ordered]@{
        schema='argos_o3k1_data_pull_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3K1_DATA_PULL_BUILD_PREFLIGHT';relativePath=$expectedRelativePath;maximumFiles=1
        maximumBytes=16777216;expectedExportZipBytes=$expectedExportZipBytes;expectedExportZipSha256=$expectedExportZipSha256
        routePathCount=$plannedPaths.Count;maximumEffectiveLength=$plannedMaximumEffective;maximumComponentLength=$plannedMaximumComponent
        builderArgumentsResolved=$true;testerArgumentsResolved=$true;matchingSignedRenderTerminalVerified=$true
        branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;jbodContacted=$false
        requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$built = & $packageBuilder -DefinitionPath $definitionPath -OutputRoot $signedRoot -IdentityStatePath $identityPath
Assert-True ([string]$built.State -eq 'SIGNED_PORTAL_PACKAGE_READY') 'O3K1 DATA_PULL signed package builder failed.'
$requestId = [string]$built.RequestId
$readyRoot = [IO.Path]::GetFullPath([string]$built.PackagePath)
Assert-True ($requestId -match '^REQ_[0-9]{8}T[0-9]{9}Z_[A-F0-9]{12}$') 'O3K1 DATA_PULL generated request ID is invalid.'
Assert-True ((Split-Path -Leaf $readyRoot) -eq ($requestId + '.ready')) 'O3K1 DATA_PULL ready root does not match its request ID.'
$folderTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3K1 DATA_PULL signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial = Join-Path $finalPartial ($requestId + '.ready.zip')
$extractRoot = Join-Path $finalPartial 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot,$zipPartial,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial,$extractRoot)
$extractTest = & $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3K1 DATA_PULL exact ZIP signature validation failed.'
Assert-True (@(Get-ChildItem -LiteralPath $extractRoot -File).Count -eq 2) 'O3K1 DATA_PULL exact ZIP entry cardinality changed.'

$zipSha256 = Get-Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig')
$actualPaths = @(Get-RoutePaths -RequestId $requestId)
$actualPathGate = & $pathTool -CandidatePath $actualPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$actualPathGate.state -eq 'PASS_PATH_BUDGET') 'O3K1 DATA_PULL exact route path budget failed.'
$maximumEffective = [int](($actualPathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($actualPathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
$routeRows = @($actualPathGate.candidates | ForEach-Object {
    [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'}
})
$requestZipRelative = 'work/OPENCV_EDGE_NOTCH_O3K1/dpf/' + $requestId + '.ready.zip'
$routeGate = [ordered]@{
    schema='argos_o3k1_data_pull_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_DATA_PULL_COMPLETE_ROUTE_GATE'
    requestId=$requestId;jobClass='DATA_PULL';requestZipPath=$requestZipRelative;requestZipBytes=$zipBytes;requestZipSha256=$zipSha256
    requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;renderTerminalResponseSha256=$expectedRenderTerminalSha256
    endpointWorkerSha256=$expectedWorkerSha256;installedEndpointConfigSha256=$expectedConfigSha256;inheritedQueueSafetyGateSha256=$expectedQueueSafetySha256
    approvedRoot='JBOD_PROCESSOR_REVIEW';relativePaths=$relativePaths;maximumFiles=1;maximumBytes=16777216;maxResultBytes=16777216
    expectedReturnedZipEntry=('data/JBOD_PROCESSOR_REVIEW/' + $expectedRelativePath);expectedExportZipBytes=$expectedExportZipBytes;expectedExportZipSha256=$expectedExportZipSha256
    routePathCount=$routeRows.Count;routeRows=$routeRows;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;reservedSuffixCharacters=32
    exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;unresolvedEarlierAcceptedRequestCount=0;publicationAuthorized=$true
    maximumRequestsAuthorized=1;retryOnFailure=$false;matchingSignedTerminalResponseCollectionOnly=$true;gatewayAcceptanceIsExecutionEvidence=$false
    sourceZipTransferredWithoutImageDecode=$true;imagePixelsDecoded=$false;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
$packageGate = [ordered]@{
    schema='argos_o3k1_data_pull_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_DATA_PULL_FINAL_PACKAGE_GATE'
    requestId=$requestId;requestZip=$requestZipRelative;requestZipBytes=$zipBytes;requestZipSha256=$zipSha256
    requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;definitionSha256=$expectedDefinitionSha256
    recoveryIntentSha256=$expectedIntentSha256;renderTerminalResponseSha256=$expectedRenderTerminalSha256
    exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;requestedFileCount=1;publicationAuthorized=$false
    requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path (Join-Path $finalPartial ($requestId + '.ready.zip.path_gate.json')) -Value $routeGate -Depth 32
[IO.Directory]::Move($finalPartial,$finalRoot)
Write-JsonCreateNew -Path $packageGatePath -Value $packageGate -Depth 20
Write-JsonCreateNew -Path $routeGatePath -Value $routeGate -Depth 32
[ordered]@{
    schema='argos_o3k1_data_pull_build_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_EXACT_SIGNED_DATA_PULL_READY'
    requestId=$requestId;requestZip=(Join-Path $finalRoot ($requestId + '.ready.zip'));requestZipBytes=$zipBytes;requestZipSha256=$zipSha256
    packageGate=$packageGatePath;routeGate=$routeGatePath;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8
