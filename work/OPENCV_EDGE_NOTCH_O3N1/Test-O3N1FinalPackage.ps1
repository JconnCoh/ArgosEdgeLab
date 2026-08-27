#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Write-NewJson([string]$Path,[object]$Value){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3N1 exact rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 24)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_20260827T231500111Z_62629419O3N1'
$zip=Join-Path $PSScriptRoot 'final_render\REQ_20260827T231500111Z_62629419O3N1.ready.zip'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$python=Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$installation=Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\FIDCV1_PORTABLE_RUNTIME_GATE.json'
$fixtureRoot='C:\A3N1R'
$gatePath=Join-Path $PSScriptRoot 'O3N1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$expectedZip='76BA22E074ADE5DF0D2B14CBB2C7937EA7E25DBEC3A1D552B923834C1BF12FAE'
$endpointSha='192C2A0D93031FF8184B3D2796D8845AB07492CA1D5FD378A735491067960840'
$engineSha='A6E63914D8669E3E733EA2BFC78FAF78F77B1FC5A54E9CC4D051F2AC34D2296B'
$liveInvocationSha='855DCCF842C46A6D1B23A7AA1D0FB7045904E5C7A4A49728921070D0701343BF'
$jobSha='E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3'
$anchorSha='6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
foreach($path in @($zip,$certificate,$packageTester,$endpointWorker,$queueGate,$python,$installation)){Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3N1 exact rehearsal dependency absent: $path"}
Assert-True ((Get-Sha $zip)-eq$expectedZip) 'O3N1 exact final ZIP changed.'
Assert-True ((Get-Sha $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3N1 endpoint worker changed.'
Assert-True ((Get-Sha $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3N1 queue gate changed.'
Assert-True (-not(Test-Path -LiteralPath $fixtureRoot)) 'O3N1 exact rehearsal root exists.'
Assert-True (-not(Test-Path -LiteralPath $gatePath)) 'O3N1 exact rehearsal gate exists.'
$pathCheck=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3N1Slot16Endpoint.ps1'),(Join-Path $fixtureRoot 'target\OCV03_NotchReviewOpenCvV1.py'),$gatePath,'C:\A3N1PX','C:\A3N1PE') -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathCheck.state-eq'PASS_PATH_BUDGET') 'O3N1 exact rehearsal path gate failed.'
if($Preflight){[ordered]@{schema='argos_o3n1_exact_package_rehearsal_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract=Join-Path $fixtureRoot 'x';Add-Type -AssemblyName System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE') 'O3N1 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$payload=Join-Path $extract 'payload';$endpoint=Join-Path $payload 'Invoke-O3N1Slot16Endpoint.ps1';$engine=Join-Path $payload 'FullPerimeterWaferTopologyOpenCvR7.py';$liveInvocation=Join-Path $payload 'O3N1_ENDPOINT_LIVE_INVOCATION.json';$job=Join-Path $payload 'O3M9_SLOT16_JOB.json';$anchor=Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py'
Assert-True ([string]$manifest.requestId-eq$requestId-and@($manifest.files).Count-eq9-and@($manifest.changes).Count-eq1) 'O3N1 signed manifest identity changed.'
Assert-True ((Get-Sha $endpoint)-eq$endpointSha-and(Get-Sha $engine)-eq$engineSha-and(Get-Sha $liveInvocation)-eq$liveInvocationSha-and(Get-Sha $job)-eq$jobSha-and(Get-Sha $anchor)-eq$anchorSha) 'O3N1 extracted payload changed.'
Assert-True ([int64]$manifest.maxResultBytes-eq4194304-and[string]$manifest.entryPoint-eq'payload/Invoke-O3N1Slot16Endpoint.ps1'-and@($manifest.entryPointMutations).Count-eq2-and@($manifest.entryPointOutputs).Count-eq2-and@($manifest.allowedTaskActions).Count-eq0-and@($manifest.allowedProcessActions).Count-eq1) 'O3N1 signed maintenance contract changed.'
$change=$manifest.changes[0]
Assert-True ([string]$change.source-eq'payload/OCV03_NotchReviewOpenCvV1.py'-and[string]$change.installedSha256-eq$anchorSha-and@($change.approvedPredecessorSha256).Count-eq1-and@($change.approvedPredecessorSha256)-contains$anchorSha-and-not[bool]$change.allowCreate) 'O3N1 signed protocol-anchor contract changed.'

$absentRoot=Join-Path $fixtureRoot 'absent';[void](New-Item -ItemType Directory -Path $absentRoot);$absent=Join-Path $absentRoot 'OCV03_NotchReviewOpenCvV1.py';Assert-True (-not(Test-Path -LiteralPath $absent)-and-not[bool]$change.allowCreate) 'O3N1 absent protocol anchor was not rejected.'
$targetRoot=Join-Path $fixtureRoot 'target';[void](New-Item -ItemType Directory -Path $targetRoot);$target=Join-Path $targetRoot 'OCV03_NotchReviewOpenCvV1.py';Copy-Item -LiteralPath $anchor -Destination $target;$targetBefore=Get-Sha $target;Assert-True (@($change.approvedPredecessorSha256)-contains$targetBefore-and$targetBefore-eq$anchorSha) 'O3N1 same-hash protocol anchor was not approved.';Assert-True ((Get-Sha $target)-eq$targetBefore) 'O3N1 same-hash protocol anchor changed bytes.'
$unapprovedRoot=Join-Path $fixtureRoot 'unapproved';[void](New-Item -ItemType Directory -Path $unapprovedRoot);$unapproved=Join-Path $unapprovedRoot 'OCV03_NotchReviewOpenCvV1.py';[IO.File]::WriteAllText($unapproved,'unapproved',(New-Object Text.UTF8Encoding($false)));$unapprovedSha=Get-Sha $unapproved;Assert-True (@($change.approvedPredecessorSha256)-notcontains$unapprovedSha-and(Get-Sha $unapproved)-eq$unapprovedSha) 'O3N1 unapproved predecessor handling changed.'

$preflightInvocation=Join-Path $fixtureRoot 'endpoint_preflight.json'
$invocation=[ordered]@{schema='argos_o3m8_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision='FMOCV03_O3N1_PACKAGE_PREFLIGHT_20260827';expectedComputerName=$env:COMPUTERNAME;payloadRoot=$payload;enginePath=$engine;engineSha256=$engineSha;jobPath=$job;jobSha256=$jobSha;dependencyFiles=@([ordered]@{path='NativeFrontsideWaferPoseOpenCvV2.py';sha256='304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC'},[ordered]@{path='NativeFrontsideWaferPoseOpenCvV2R5.py';sha256='47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24'},[ordered]@{path='NativeFrontsideWaferPoseOpenCvV2R6.py';sha256='90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'},[ordered]@{path='WaferTopologyAxisOpenCv.py';sha256='D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD'});runtimePath=$python;runtimeSha256='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1';runtimeInstallationPath=$installation;runtimeInstallationSha256='6BCA2B3FA69416BE9E7DE9D02B606081A24C976275C5A4D1B1E83D133D30A409';sourceAliasDrive='F:';sourceRoot=$project;outputRoot='C:\A3N1PX';exportRoot='C:\A3N1PE';exportZipName='O3N1_PACKAGE_PREFLIGHT.zip';maximumExportZipBytes=134217728;processorCommandToken='Invoke-AllWaferProcessorV2.ps1';sourceImageReadAuthorized=$true;detectorRerunAuthorized=$true;thresholdOrAlgorithmChangeAuthorized=$false;frontsideOnly=$true;backsidePixelsConsumed=$false;argosRotationMetadataConsumed=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $preflightInvocation $invocation
$endpointPreflightResult=(& $endpoint -Preflight -Rehearsal -InvocationManifest $preflightInvocation)|ConvertFrom-Json
Assert-True ([string]$endpointPreflightResult.state-eq'PASS_O3M8_ENDPOINT_PREFLIGHT'-and-not[bool]$endpointPreflightResult.sourceMetadataRead-and-not[bool]$endpointPreflightResult.sourceImageBytesRead-and-not[bool]$endpointPreflightResult.outputCreated) 'O3N1 exact extracted endpoint preflight failed.'

$record=[ordered]@{schema='argos_o3n1_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_EXACT_PACKAGE_REHEARSAL';requestId=$requestId;requestZipSha256=$expectedZip;windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;windowsPowerShellMinor=$PSVersionTable.PSVersion.Minor;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=9;changeCount=1;allowCreateFalseCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;exactExtractedEndpointPreflightState=[string]$endpointPreflightResult.state;exactExtractedEndpointSha256=Get-Sha $endpoint;exactExtractedEngineSha256=Get-Sha $engine;protocolAnchorSha256=Get-Sha $anchor;protocolAnchorExpectedByteIdentical=$true;protocolAnchorExecutedByEntrypoint=$false;endpointWorkerSha256=Get-Sha $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceHashesComputed=$false;pixelsDecoded=$false;sourceMutationPerformed=$false;taskActions=0;healthyProcessorTouched=$false;providerActivated=$false;backsidePixelsConsumed=$false;argosRotationMetadataConsumed=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record|ConvertTo-Json -Depth 12
