#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Write-NewUtf8([string]$Path,[string]$Text){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3K1 exact rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))}
function Write-NewJson([string]$Path,[object]$Value){Write-NewUtf8 $Path (($Value|ConvertTo-Json -Depth 18)+[Environment]::NewLine)}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_20260827T201500111Z_62629419O3K1'
$zip=Join-Path $PSScriptRoot 'final_render\REQ_20260827T201500111Z_62629419O3K1.ready.zip'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$fixtureRoot='C:\A3K1R'
$gatePath=Join-Path $PSScriptRoot 'O3K1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$expectedZip='B755ECE17D8FE81BD5D49D607445004BE729A47FD7F2154AD0544D1B1F8FA24C'
$endpointSha='E1D0D45622DC4AB1E2C086A2B765F4F7022B548AD8399DEB2D1048FF08FAB958'
$providerSha='6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
$liveInvocationSha='6CA796CFF22092DE1899BA2FCB6C67D21457D0118F854115B8B337F2C8D83E3E'
$jobSha='2BD9E34A9CCFDFF92942FC11A6E88CBABE2CBBED47A0320C118520D2C16988C7'
$python=Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$installation=Join-Path $project 'work\OPENCV_SCRIBE_O2D23\fixtures\INSTALLATION.json'
foreach($path in @($zip,$certificate,$packageTester,$endpointWorker,$queueGate,$python,$installation)){Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3K1 exact rehearsal dependency absent: $path"}
Assert-True ((Get-Sha $zip)-eq$expectedZip) 'O3K1 exact final ZIP changed.'
Assert-True ((Get-Sha $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3K1 endpoint worker changed.'
Assert-True ((Get-Sha $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3K1 queue gate changed.'
Assert-True (-not(Test-Path -LiteralPath $fixtureRoot)) 'O3K1 exact rehearsal root exists.'
Assert-True (-not(Test-Path -LiteralPath $gatePath)) 'O3K1 exact rehearsal gate exists.'
$pathCheck=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3K1NotchReviewEndpoint.ps1'),(Join-Path $fixtureRoot 'target\OCV03_NotchReviewOpenCvV1.py'),$gatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathCheck.state-eq'PASS_PATH_BUDGET') 'O3K1 exact rehearsal path gate failed.'
if($Preflight){[ordered]@{schema='argos_o3k1_exact_package_rehearsal_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;endpointWorkerSha256=Get-Sha $endpointWorker;inheritedQueueGateSha256=Get-Sha $queueGate;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract=Join-Path $fixtureRoot 'x';Add-Type -AssemblyName System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE') 'O3K1 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$endpoint=Join-Path $extract 'payload\Invoke-O3K1NotchReviewEndpoint.ps1';$provider=Join-Path $extract 'payload\OCV03_NotchReviewOpenCvV1.py';$liveInvocation=Join-Path $extract 'payload\O3K1_ENDPOINT_LIVE_INVOCATION.json';$job=Join-Path $extract 'payload\O3K1_RENDER_JOB.json'
Assert-True ([string]$manifest.requestId-eq$requestId-and@($manifest.files).Count-eq6-and@($manifest.changes).Count-eq1) 'O3K1 signed manifest identity changed.'
Assert-True ((Get-Sha $endpoint)-eq$endpointSha-and(Get-Sha $provider)-eq$providerSha-and(Get-Sha $liveInvocation)-eq$liveInvocationSha-and(Get-Sha $job)-eq$jobSha) 'O3K1 extracted payload changed.'
Assert-True ([int64]$manifest.maxResultBytes-eq4194304-and[string]$manifest.entryPoint-eq'payload/Invoke-O3K1NotchReviewEndpoint.ps1'-and@($manifest.entryPointMutations).Count-eq2-and@($manifest.entryPointOutputs).Count-eq2-and@($manifest.allowedTaskActions).Count-eq0-and@($manifest.allowedProcessActions).Count-eq1) 'O3K1 signed maintenance contract changed.'
$change=$manifest.changes[0]
Assert-True ([string]$change.source-eq'payload/OCV03_NotchReviewOpenCvV1.py'-and[string]$change.installedSha256-eq$providerSha-and@($change.approvedPredecessorSha256).Count-eq1-and@($change.approvedPredecessorSha256)-contains$providerSha-and[bool]$change.allowCreate) 'O3K1 signed predecessor contract changed.'

$createRoot=Join-Path $fixtureRoot 'create';[void](New-Item -ItemType Directory -Path $createRoot);$createTarget=Join-Path $createRoot 'OCV03_NotchReviewOpenCvV1.py';Assert-True (-not(Test-Path -LiteralPath $createTarget)-and[bool]$change.allowCreate) 'O3K1 allow-create case premise changed.';Copy-Item -LiteralPath $provider -Destination $createTarget;Assert-True ((Get-Sha $createTarget)-eq$providerSha) 'O3K1 allow-create case failed.'
$targetRoot=Join-Path $fixtureRoot 'target';[void](New-Item -ItemType Directory -Path $targetRoot);$target=Join-Path $targetRoot 'OCV03_NotchReviewOpenCvV1.py';Copy-Item -LiteralPath $provider -Destination $target;Assert-True (@($change.approvedPredecessorSha256)-contains(Get-Sha $target)) 'O3K1 target-hash idempotent case was not approved.';Assert-True ((Get-Sha $target)-eq$providerSha) 'O3K1 target-hash case changed bytes.'
$unapprovedRoot=Join-Path $fixtureRoot 'unapproved';[void](New-Item -ItemType Directory -Path $unapprovedRoot);$unapproved=Join-Path $unapprovedRoot 'OCV03_NotchReviewOpenCvV1.py';Write-NewUtf8 $unapproved 'unapproved';$unapprovedSha=Get-Sha $unapproved;Assert-True (@($change.approvedPredecessorSha256)-notcontains$unapprovedSha) 'O3K1 unapproved predecessor was accepted.';Assert-True ((Get-Sha $unapproved)-eq$unapprovedSha) 'O3K1 unapproved predecessor changed.'

$preflightInvocation=Join-Path $fixtureRoot 'endpoint_preflight.json'
$invocation=[ordered]@{schema='argos_o3k1_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision='FMOCV03_O3K1TEST_20260827T200000Z';expectedComputerName=$env:COMPUTERNAME;payloadRoot='C:\O3K1T\job';providerPath=$provider;providerSha256=$providerSha;jobPath='C:\O3K1T\job\JOB.json';jobSha256='B8CE40469C401192BBBF9EB811A40C82F875D1B5A43F4DB3C4193475D09173CF';resultFiles=@([ordered]@{path='S16_RESULT.json';sha256='3860F79B6F9BBE2E51883B999A208C082BE914AD1FB6FE83BFD6CBF2CEF5DF10'},[ordered]@{path='S17_RESULT.json';sha256='3127EC3E703DA18C96332A6478414D9594D2F5510A3FDE6805C77A94FC41D96A'});runtimePath=$python;runtimeSha256='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1';runtimeInstallationPath=$installation;runtimeInstallationSha256='6579C27B395CE211DD2AC1AFFA3CB92341458B5CE947E2F0434C39718603C130';useSourceAlias=$false;sourceAliasDrive='F:';sourceRoot='C:\O3K1T\src';outputRoot='C:\O3K1T\out\package_preflight_o3k1';exportRoot='C:\O3K1T\export\package_preflight_o3k1';exportZipName='O3K1_REVIEW.zip';maximumExportZipBytes=67108864;processorCommandToken='Invoke-AllWaferProcessorV2.ps1';sourceImageReadAuthorized=$true;detectorRerunAuthorized=$false;thresholdOrAlgorithmChangeAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $preflightInvocation $invocation
$endpointPreflightResult=(& $endpoint -Preflight -Rehearsal -InvocationManifest $preflightInvocation)|ConvertFrom-Json
Assert-True ([string]$endpointPreflightResult.state-eq'PASS_O3K1_ENDPOINT_PREFLIGHT'-and-not[bool]$endpointPreflightResult.sourceImageBytesRead-and-not[bool]$endpointPreflightResult.outputCreated) 'O3K1 exact extracted endpoint preflight failed.'

$record=[ordered]@{schema='argos_o3k1_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_EXACT_PACKAGE_REHEARSAL';requestId=$requestId;requestZipSha256=$expectedZip;windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;windowsPowerShellMinor=$PSVersionTable.PSVersion.Minor;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=6;changeCount=1;allowCreateCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;exactExtractedEndpointPreflightState=[string]$endpointPreflightResult.state;exactExtractedEndpointSha256=Get-Sha $endpoint;exactExtractedProviderSha256=Get-Sha $provider;endpointWorkerSha256=Get-Sha $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceHashesComputed=$false;pixelsDecoded=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskActions=0;healthyProcessorTouched=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record|ConvertTo-Json -Depth 10
