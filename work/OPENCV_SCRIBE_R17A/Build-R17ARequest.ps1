#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T142600000Z_R17A'
$branch = 'codex/opencv-scribe-deciphering'
$definitionPath = Join-Path $PSScriptRoot 'R17A_DATA_PULL_DEFINITION.json'
$cohortPath = Join-Path $PSScriptRoot 'R17A_FAILURE_FIRST_COHORT.json'
$intentPath = Join-Path $PSScriptRoot 'R17A_RECOVERY_INTENT.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R17A_ONE_TIME_PUBLICATION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$intentTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$stageRoot = 'C:\R17AB'
$verifyRoot = 'C:\R17AV'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R17A_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R17A_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $finalZip + '.path_gate.json'
$definitionSha256 = '3266EFC50A4517278512CC07C4D623D20483351C2DACDF83C226B3BA26665246'
$cohortSha256 = 'EA15D1AE228DB1FD1307D2F4209D57C61572D192FFE1D807EDA3D2C00472499D'
$intentSha256 = '06643F8505B1DC952B222CACFC2B08E144563F107D7BDFC6776B1E993DD73754'
$preactionSha256 = '54D1FC542B255B6A31193D5584503452C399C063C573DDBC249D7CEB98BB5AF9'
$inheritedRouteSha256 = 'E0EAE7BBECDE766E6E78D86074A098465F3117B737146DDF4FF32D1D4953ED2C'
$queueSafetySha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$installedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R17A dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R17A dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-Pin $definitionPath $definitionSha256
Assert-Pin $cohortPath $cohortSha256
Assert-Pin $intentPath $intentSha256
Assert-Pin $preactionPath $preactionSha256
& $intentTool -IntentPath $intentPath -ProjectRoot $project -Preflight | Out-Null
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$cohort = Get-Content -LiteralPath $cohortPath -Raw | ConvertFrom-Json
$relativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
$uniquePaths = @($relativePaths | Sort-Object -Unique)
$proposalPaths = @($relativePaths | Where-Object { $_ -like '*/SCRIBE_PROPOSAL.json' })
$bfPaths = @($relativePaths | Where-Object { $_ -like '*/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png' })
$dfPaths = @($relativePaths | Where-Object { $_ -like '*/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png' })
$selected = @($cohort.partitions.development) + @($cohort.partitions.blindValidation)
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R17A route changed.'
Assert-True ($relativePaths.Count -eq 24 -and $uniquePaths.Count -eq 24 -and $proposalPaths.Count -eq 8 -and $bfPaths.Count -eq 8 -and $dfPaths.Count -eq 8) 'R17A exact file cardinality changed.'
Assert-True ($selected.Count -eq 8 -and @($cohort.partitions.development).Count -eq 4 -and @($cohort.partitions.blindValidation).Count -eq 4) 'R17A cohort partition changed.'
Assert-True ([int]$definition.parameters.maximumFiles -eq 24 -and [int64]$definition.parameters.maximumBytes -eq 50331648 -and [int64]$definition.maxResultBytes -eq 50331648) 'R17A byte bounds changed.'
Assert-True (-not [bool]$cohort.authority.automaticIdentityAuthority -and -not [bool]$cohort.authority.trainingAuthorized -and -not [bool]$cohort.authority.productionEligible) 'R17A authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R17A requires a clean dedicated branch matching origin.'
Assert-True ((Get-PSDrive -Name U -ErrorAction Stop).DisplayRoot -eq $shareRoot) 'Persistent U mapping changed.'
Assert-True (Test-Path -LiteralPath 'U:\ProjectPortalRO\requests' -PathType Container) 'Portal request share is unavailable.'
Assert-True (Test-Path -LiteralPath 'U:\ProjectPortalRO\responses' -PathType Container) 'Portal response share is unavailable.'
Assert-True (@(Get-ChildItem -LiteralPath 'U:\ProjectPortalRO\requests' -File -ErrorAction Stop | Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.ready.zip.upload' }).Count -eq 0) 'A portal request is already pending.'

$responseId = 'R_0123456789AB_20260903235959999_a1b2c3d4'
$responseReady = $responseId + '.ready'
$longestRelative = 'data\JBOD_PROCESSOR_REVIEW\' + (($relativePaths | Sort-Object Length -Descending)[0]).Replace('/', '\')
$routePaths = @(
    (Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json'),
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
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\RESULT.json',
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\DATA_PULL_PAYLOAD.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\APR\R\pending\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'),
    ('C:\APR\A\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('U:\ProjectPortalRO\responses\' + $responseReady + '.zip'),
    'C:\R17AR\PORTAL_RESPONSE_MANIFEST.json',
    'C:\R17AR\DATA_PULL_PAYLOAD.zip',
    ('C:\R17A\' + $longestRelative)
)
$pathGate = & $pathTool -CandidatePath $routePaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R17A complete route path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ($maximumEffective -lt 200 -and $maximumComponent -le 80) 'R17A route requires a shorter root.'
foreach ($path in @($stageRoot, $verifyRoot, $finalPartial, $finalRoot, $packageGatePath, $routeGatePath, $pathSidecar)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "R17A fresh output exists: $path"
}
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ([bool]$certificate.HasPrivateKey) 'R17A signer private key is unavailable.'

if ($Preflight) {
    [ordered]@{schema='argos_r17a_build_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R17A_BUILD_PREFLIGHT';requestId=$requestId;relativePathCount=24;proposalCount=8;imageCount=16;maximumBytes=50331648;routePathCount=$routePaths.Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;mutationsPerformed=$false;jbodContacted=$false;pixelsDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $stageRoot)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='DATA_PULL';handler='';maxResultBytes=50331648;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@();parameters=$definition.parameters}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 24))
[IO.File]::WriteAllBytes((Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
$folderTest = & $packageTester -PackagePath $stageRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R17A signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial = Join-Path $finalPartial ($requestId + '.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $zipPartial, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial, $verifyRoot)
$extractTest = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and @(Get-ChildItem -LiteralPath $verifyRoot -File).Count -eq 2) 'R17A exact ZIP validation failed.'
$zipSha256 = Get-Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
$routeRows = @($pathGate.candidates | ForEach-Object { [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'} })
$packageGate = [ordered]@{schema='argos_r17a_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R17A_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_R17A/final/'+$requestId+'.ready.zip');requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;definitionSha256=$definitionSha256;cohortSha256=$cohortSha256;recoveryIntentSha256=$intentSha256;preactionSha256=$preactionSha256;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;requestedFileCount=24;requestedProposalFiles=8;requestedImageFiles=16;sourceHashingRequested=$true;publicationAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$routeGate = [ordered]@{schema='argos_r17a_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R17A_COMPLETE_ROUTE_GATE';requestId=$requestId;jobClass='DATA_PULL';requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;installedEndpointWorkerSha256=$installedWorkerSha256;inheritedRouteHealthSha256=$inheritedRouteSha256;queueSafetyGateSha256=$queueSafetySha256;approvedRoot='JBOD_PROCESSOR_REVIEW';relativePaths=$relativePaths;maximumFiles=24;maximumBytes=50331648;maxResultBytes=50331648;longestReturnedZipEntry=$longestRelative.Replace('\','/');filesystemReturnPathsFlattened=$true;routePathCount=$routeRows.Count;routeRows=$routeRows;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;reservedSuffixCharacters=32;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;unresolvedEarlierAcceptedRequestCount=0;publicationAuthorized=$true;maximumRequestsAuthorized=1;retryOnFailure=$false;matchingSignedTerminalResponseCollectionOnly=$true;pixelsDecoded=$false;blindValidationPixelsInspected=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path (Join-Path $finalPartial ($requestId + '.ready.zip.path_gate.json')) -Value $routeGate
[IO.Directory]::Move($finalPartial, $finalRoot)
Write-JsonCreateNew -Path $packageGatePath -Value $packageGate
Write-JsonCreateNew -Path $routeGatePath -Value $routeGate
[IO.Directory]::Delete($stageRoot, $true)
[IO.Directory]::Delete($verifyRoot, $true)
[ordered]@{schema='argos_r17a_build_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R17A_EXACT_SIGNED_DATA_PULL_READY';requestId=$requestId;requestZip=$finalZip;requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;packageGate=$packageGatePath;routeGate=$routeGatePath;temporaryRootsRemoved=@($stageRoot,$verifyRoot);reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
