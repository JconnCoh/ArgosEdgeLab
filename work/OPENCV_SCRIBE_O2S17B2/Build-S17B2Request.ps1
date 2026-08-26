
#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_O2S17B2_20260826'
$definitionPath = Join-Path $PSScriptRoot 'S17B2_DATA_PULL_DEFINITION.json'
$intentPath = Join-Path $PSScriptRoot 'S17B2_RECOVERY_INTENT.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_S17B2_BUILD.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$checkpointPath = Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV02_O2D11_SIGNED_SLOT16_FROZEN_SLOT17_SOURCE_BINDING_CHECKPOINT_20260826.md'
$routeHealthPath = Join-Path $project 'work\OPENCV_SCRIBE_O2D11\O2D11_COMPLETE_ROUTE_GATE_R2.json'
$terminalPath = Join-Path $project 'work\OPENCV_SCRIBE_O2S17B1\S17B1_TERMINAL_RESPONSE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$intentTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$partialRoot = Join-Path $PSScriptRoot 'build.partial'
$signedRoot = Join-Path $PSScriptRoot 'signed'
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'S17B2_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'S17B2_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $finalZip + '.path_gate.json'
$expectedDefinitionSha256 = '6902CDEF142A8CA96BCDEAFDD2DAA44496B2C047CB89FCA37173A86541C36B78'
$expectedIntentSha256 = 'EC48BB597F422F5C8F576C4BED9C20FA233D0D269AE03EE82DF618A4589F77BA'
$expectedPreactionSha256 = 'F27CBC0B780A2500D4D0A763547CF6C0074A9E37692E7C0050BEE44838C460A2'
$expectedCheckpointSha256 = 'C3E6190047375AF7A6DC01E96612758E4B072C82847A0EFE2F624364C46EA770'
$expectedRouteHealthSha256 = 'C0C1603C98AB5061BE89468AA4B7615D0908B0A33E46C44C6C03142069201033'
$expectedTerminalSha256 = '72F646F8A3BE332368154B3B9E5D4EC6D821D23C368D2BF5B49DB5A608BB52D7'
$expectedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$expectedConfigSha256 = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$branch = 'codex/fiducial-opencv-d-drive'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try { $sha = [Security.Cryptography.SHA256]::Create(); try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') } finally { $sha.Dispose() } }
    finally { $stream.Dispose() }
}
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "S17B2 dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "S17B2 dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-Pin $definitionPath $expectedDefinitionSha256
Assert-Pin $intentPath $expectedIntentSha256
Assert-Pin $preactionPath $expectedPreactionSha256
Assert-Pin $checkpointPath $expectedCheckpointSha256
Assert-Pin $routeHealthPath $expectedRouteHealthSha256
Assert-Pin $terminalPath $expectedTerminalSha256
foreach ($path in @($identityPath,$publicCertificatePath,$packageTester,$intentTool,$preactionTool,$pathTool)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "S17B2 input is absent: $path" }
& $intentTool -IntentPath $intentPath -ProjectRoot $project -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
$relativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
$expectedRelativePaths = @(
    'identity/proposals/62619-433_20260824005735_Slot17/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',
    'identity/proposals/62619-433_20260824005735_Slot17/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
)
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'S17B2 DATA_PULL route changed.'
Assert-True ($relativePaths.Count -eq 2 -and @(Compare-Object -ReferenceObject $expectedRelativePaths -DifferenceObject $relativePaths).Count -eq 0) 'S17B2 exact relative path set changed.'
Assert-True ([int]$definition.parameters.maximumFiles -eq 2 -and [int64]$definition.parameters.maximumBytes -eq 4194304 -and [int64]$definition.maxResultBytes -eq 4194304) 'S17B2 bounds changed.'

$routeHealth = Get-Content -Raw -LiteralPath $routeHealthPath | ConvertFrom-Json
$terminal = Get-Content -Raw -LiteralPath $terminalPath | ConvertFrom-Json
$continuity = Get-Content -Raw -LiteralPath (Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json') | ConvertFrom-Json
Assert-True ([string]$routeHealth.state -eq 'PASS_O2D11_COMPLETE_ROUTE_GATE' -and [bool]$routeHealth.publicationAuthorized -and -not [bool]$routeHealth.retryAuthorized) 'S17B2 inherited route health changed.'
Assert-True ([int]$routeHealth.unresolvedEarlierAcceptedRequestCount -eq 0 -and [bool]$routeHealth.argosInboundRelayCurrentHealthProved) 'S17B2 route has unresolved earlier work.'
Assert-True ([string]$routeHealth.endpointWorkerSha256 -eq $expectedWorkerSha256 -and [string]$routeHealth.installedEndpointConfigSha256 -eq $expectedConfigSha256) 'S17B2 installed route pins changed.'
Assert-True ([string]$terminal.state -eq 'PASS_S17B1_SIGNED_SLOT17_SOURCE_METADATA_COLLECTED_HASH_BINDING_PENDING' -and [bool]$terminal.signedResponseVerified) 'S17B2 predecessor terminal evidence changed.'
Assert-True ([string]$continuity.activePhase -eq 'OCV02_O2D11_SIGNED_SLOT16_FROZEN_SLOT17_SOURCE_BINDING' -and -not [bool]$continuity.productionEligible) 'S17B2 continuity authority changed.'
$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'S17B2 requires matching local/origin branch tips.'

foreach ($path in @($partialRoot,$signedRoot,$finalRoot,$packageGatePath,$routeGatePath,$pathSidecar)) { Assert-True (-not (Test-Path -LiteralPath $path)) "S17B2 fresh output exists: $path" }
$responseId = 'R_0123456789AB_20260826235959999_a1b2c3d4'
$responseReady = $responseId + '.ready'
$longestRelative = 'data\JBOD_PROCESSOR_REVIEW\' + $expectedRelativePaths[1].Replace('/','\')
$routePaths = @(
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    $finalZip,
    $pathSidecar,
    ('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip.upload'),
    ('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip'),
    ('C:\APR\S\requests\processed\' + $requestId + '.ready.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial',
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\DATA_PULL_PAYLOAD.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\APR\R\pending\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\APR\A\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('U:\ProjectPortalRO\responses\' + $responseReady + '.zip'),
    'C:\S17B2R.zip',
    'C:\S17B2R\PORTAL_RESPONSE_MANIFEST.json',
    'C:\S17B2R\DATA_PULL_PAYLOAD.zip',
    ('C:\S17B2D\' + $longestRelative)
)
$pathGate = & $pathTool -CandidatePath $routePaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'S17B2 complete route path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ([bool]$certificate.HasPrivateKey) 'S17B2 signer private key is unavailable.'

if ($Preflight) {
    [ordered]@{schema='argos_s17b2_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S17B2_BUILD_PREFLIGHT';requestId=$requestId;relativePathCount=2;maximumFiles=2;maximumBytes=4194304;routePathCount=$routePaths.Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;jbodContacted=$false;imageBytesRequested=2;pixelsDecoded=$false;slots22Through25Exposed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$partialReady = Join-Path $partialRoot ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path $partialReady)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='DATA_PULL';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@();parameters=$definition.parameters}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 24))
[IO.File]::WriteAllBytes((Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
[IO.Directory]::Move($partialReady, $readyRoot)
[IO.Directory]::Delete($partialRoot)
$folderTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'S17B2 signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$finalPartial = $finalRoot + '.partial'
[void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial = Join-Path $finalPartial ($requestId + '.ready.zip')
$extractRoot = Join-Path $finalPartial 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot,$zipPartial,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial,$extractRoot)
$extractTest = & $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and @(Get-ChildItem -LiteralPath $extractRoot -File).Count -eq 2) 'S17B2 exact ZIP extraction validation failed.'
$zipSha256 = Get-Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig')
$routeRows = @($pathGate.candidates | ForEach-Object { [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'} })
$packageGate = [ordered]@{schema='argos_s17b2_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S17B2_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_O2S17B2/final/'+$requestId+'.ready.zip');requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;definitionSha256=$expectedDefinitionSha256;recoveryIntentSha256=$expectedIntentSha256;preactionSha256=$expectedPreactionSha256;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;requestedFileCount=2;requestedImageFiles=2;sourceHashingRequested=$true;publicationAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$routeGate = [ordered]@{schema='argos_s17b2_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S17B2_COMPLETE_ROUTE_GATE';requestId=$requestId;jobClass='DATA_PULL';requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;endpointWorkerSha256=$expectedWorkerSha256;installedEndpointConfigSha256=$expectedConfigSha256;inheritedRouteHealthSha256=$expectedRouteHealthSha256;priorTerminalResponseSha256=$expectedTerminalSha256;approvedRoot='JBOD_PROCESSOR_REVIEW';relativePaths=$relativePaths;maximumFiles=2;maximumBytes=4194304;maxResultBytes=4194304;longestReturnedZipEntry=$longestRelative.Replace('\','/');routePathCount=$routeRows.Count;routeRows=$routeRows;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;reservedSuffixCharacters=32;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;unresolvedEarlierAcceptedRequestCount=0;publicationAuthorized=$true;maximumRequestsAuthorized=1;retryOnFailure=$false;matchingSignedTerminalResponseCollectionOnly=$true;imageBytesRequested=2;pixelsDecoded=$false;slots22Through25Exposed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path (Join-Path $finalPartial ($requestId + '.ready.zip.path_gate.json')) -Value $routeGate -Depth 24
[IO.Directory]::Move($finalPartial, $finalRoot)
Write-JsonCreateNew -Path $packageGatePath -Value $packageGate -Depth 16
Write-JsonCreateNew -Path $routeGatePath -Value $routeGate -Depth 24
[ordered]@{schema='argos_s17b2_build_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_S17B2_EXACT_SIGNED_DATA_PULL_READY';requestId=$requestId;requestZip=$finalZip;requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;packageGate=$packageGatePath;routeGate=$routeGatePath;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8

