#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T192241716Z_R18E'
$branch = 'codex/opencv-scribe-deciphering'
$definitionPath = Join-Path $PSScriptRoot 'R18E_DATA_PULL_DEFINITION.json'
$cohortPath = Join-Path $PSScriptRoot 'R18E_COHORT.json'
$selectionGatePath = Join-Path $PSScriptRoot 'R18E_SELECTION_GATE.json'
$localGatePath = Join-Path $PSScriptRoot 'R18E_LOCAL_COHORT_GATE.json'
$sourcePathGatePath = Join-Path $PSScriptRoot 'R18E_SOURCE_AND_EXTRACTION_PATH_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18E_LOCAL_PACKAGE_PREPARATION.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$stageRoot = 'C:\R18EB'
$verifyRoot = 'C:\R18EV'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18E_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18E_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $finalZip + '.path_gate.json'
$definitionSha256 = 'C4787C80AB9AFB05772112EED4D9DCAB83CFB26EEDF77317E1555B518B03AE5B'
$cohortSha256 = 'A36B94205B56CAF67B69D7CFB48651CC0D185AA74496CA4C7BF6EA2D5AC3931C'
$selectionGateSha256 = '70C6862FDDBA435B77515266C31612F5819F51F333EE829E32843B13A3D38C0E'
$localGateSha256 = 'C094EBC16024B2324E2EF68852A9F98280A419DF62375C8785A4424C19620A7B'
$sourcePathGateSha256 = '32B29DC749B708C1281800CC7F8D962AF6C4758247BE9E97E5828FD18C856140'
$preactionSha256 = '8D4393F7ACFCF7CC0DDB9F712F0122D5EF48C6E5B6310DFCFE3CBEF1D730FC61'
$providerSha256 = '39E44AE48A76DA0BDF25490BD3EFE49EC98770B0B10BE6DF0FF57373951B95A1'
$providerGateSha256 = '0E3D94DBA81B37C83667FE7AE61E17D06476DDC4B466F86C58502EA52471609D'
$supplementSha256 = '8B7F0BAC5892DA7BBB4D25CDD058CC995042A0C596F3790FE333AAAEEE43D60A'
$inheritedRouteSha256 = 'E0EAE7BBECDE766E6E78D86074A098465F3117B737146DDF4FF32D1D4953ED2C'
$queueSafetySha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$installedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R18E dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R18E dependency changed: $Path"
}
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-Pin $definitionPath $definitionSha256
Assert-Pin $cohortPath $cohortSha256
Assert-Pin $selectionGatePath $selectionGateSha256
Assert-Pin $localGatePath $localGateSha256
Assert-Pin $sourcePathGatePath $sourcePathGateSha256
Assert-Pin $preactionPath $preactionSha256
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_R18D\ArgosOpenCvScribeV1R18D.py') $providerSha256
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_R18D\R18D_LOCAL_GATE.json') $providerGateSha256
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_R18D\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json') $supplementSha256
& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$cohort = Get-Content -LiteralPath $cohortPath -Raw | ConvertFrom-Json
$relativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
$uniquePaths = @($relativePaths | Sort-Object -Unique)
$proposalPaths = @($relativePaths | Where-Object { $_ -like '*/SCRIBE_PROPOSAL.json' })
$bfPaths = @($relativePaths | Where-Object { $_ -like '*/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png' })
$dfPaths = @($relativePaths | Where-Object { $_ -like '*/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png' })
$selected = @($cohort.partitions.development) + @($cohort.partitions.blindValidation)
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R18E route changed.'
Assert-True ($relativePaths.Count -eq 24 -and $uniquePaths.Count -eq 24 -and $proposalPaths.Count -eq 8 -and $bfPaths.Count -eq 8 -and $dfPaths.Count -eq 8) 'R18E exact file cardinality changed.'
Assert-True ($selected.Count -eq 8 -and @($cohort.partitions.development).Count -eq 4 -and @($cohort.partitions.blindValidation).Count -eq 4) 'R18E cohort partition changed.'
Assert-True ([int]$definition.parameters.maximumFiles -eq 24 -and [int64]$definition.parameters.maximumBytes -eq 50331648 -and [int64]$definition.maxResultBytes -eq 50331648) 'R18E byte bounds changed.'
Assert-True (-not [bool]$cohort.authority.portalPublicationAuthorized -and [int]$cohort.authority.maximumPublicationsAfterExplicitPublish -eq 1 -and -not [bool]$cohort.authority.retryAuthorized) 'R18E local preparation authority changed.'
Assert-True (-not [bool]$cohort.authority.identityAcceptance -and -not [bool]$cohort.authority.trainingAuthorized -and -not [bool]$cohort.authority.productionEligible) 'R18E authority widened.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip -and $status.Count -eq 0) 'R18E build requires a clean dedicated branch matching origin.'
$drive = Get-PSDrive -Name U -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'"
Assert-True ($drive.DisplayRoot -eq $shareRoot -and [string]$disk.ProviderName -eq $shareRoot) 'Persistent U mapping changed.'
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
    'C:\R18ER\PORTAL_RESPONSE_MANIFEST.json',
    'C:\R18ER\DATA_PULL_PAYLOAD.zip',
    ('C:\R18E\' + $longestRelative)
)
$pathGate = & $pathTool -CandidatePath $routePaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R18E complete route path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ($maximumEffective -lt 200 -and $maximumComponent -le 80) 'R18E route requires a shorter root.'
foreach ($path in @($stageRoot, $verifyRoot, $finalPartial, $finalRoot, $packageGatePath, $routeGatePath, $pathSidecar)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "R18E fresh output exists: $path"
}
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ([bool]$certificate.HasPrivateKey) 'R18E signer private key is unavailable.'

if ($Preflight) {
    [ordered]@{schema='argos_r18e_build_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18E_BUILD_PREFLIGHT';requestId=$requestId;relativePathCount=24;proposalCount=8;imageCount=16;maximumBytes=50331648;routePathCount=$routePaths.Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;branch=$branch;localTip=$localTip;remoteTip=$remoteTip;publicationAuthorized=$false;explicitPublishRequired=$true;mutationsPerformed=$false;jbodContacted=$false;pixelsDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
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
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18E signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial = Join-Path $finalPartial ($requestId + '.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $zipPartial, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial, $verifyRoot)
$extractTest = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and @(Get-ChildItem -LiteralPath $verifyRoot -File).Count -eq 2) 'R18E exact ZIP validation failed.'
$zipSha256 = Get-Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
$routeRows = @($pathGate.candidates | ForEach-Object { [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'} })
$packageGate = [ordered]@{schema='argos_r18e_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18E_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_R18E/final/'+$requestId+'.ready.zip');requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;definitionSha256=$definitionSha256;cohortSha256=$cohortSha256;selectionGateSha256=$selectionGateSha256;preactionSha256=$preactionSha256;providerSha256=$providerSha256;providerGateSha256=$providerGateSha256;supplementalManifestSha256=$supplementSha256;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;requestedFileCount=24;requestedProposalFiles=8;requestedImageFiles=16;sourceHashingRequested=$true;publicationAuthorized=$false;explicitPublishRequired=$true;maximumPublicationsAfterExplicitPublish=1;retryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$routeGate = [ordered]@{schema='argos_r18e_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18E_COMPLETE_ROUTE_GATE';requestId=$requestId;jobClass='DATA_PULL';requestZipSha256=$zipSha256;requestManifestSha256=$manifestSha256;requestSignatureSha256=$signatureSha256;installedEndpointWorkerSha256=$installedWorkerSha256;inheritedRouteHealthSha256=$inheritedRouteSha256;queueSafetyGateSha256=$queueSafetySha256;approvedRoot='JBOD_PROCESSOR_REVIEW';relativePaths=$relativePaths;maximumFiles=24;maximumBytes=50331648;maxResultBytes=50331648;longestReturnedZipEntry=$longestRelative.Replace('\','/');deepSourcePathsPreserved=$true;filesystemReturnPathsFlattened=$false;routePathCount=$routeRows.Count;routeRows=$routeRows;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;reservedSuffixCharacters=32;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;unresolvedEarlierAcceptedRequestCount=0;publicationAuthorized=$false;explicitPublishRequired=$true;maximumRequestsAfterExplicitPublish=1;retryOnFailure=$false;matchingSignedTerminalResponseCollectionOnly=$true;pixelsDecoded=$false;blindValidationPixelsInspected=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path (Join-Path $finalPartial ($requestId + '.ready.zip.path_gate.json')) -Value $routeGate
[IO.Directory]::Move($finalPartial, $finalRoot)
Write-JsonCreateNew -Path $packageGatePath -Value $packageGate
Write-JsonCreateNew -Path $routeGatePath -Value $routeGate
[IO.Directory]::Delete($stageRoot, $true)
[IO.Directory]::Delete($verifyRoot, $true)
[ordered]@{schema='argos_r18e_build_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18E_EXACT_SIGNED_DATA_PULL_READY_LOCAL_ONLY';requestId=$requestId;requestZip=$finalZip;requestZipBytes=$zipBytes;requestZipSha256=$zipSha256;packageGate=$packageGatePath;routeGate=$routeGatePath;publicationAuthorized=$false;explicitPublishRequired=$true;temporaryRootsRemoved=@($stageRoot,$verifyRoot);reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
