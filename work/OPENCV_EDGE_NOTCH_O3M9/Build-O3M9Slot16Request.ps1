#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InvocationManifest,[switch]$Preflight,[switch]$Build)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Build)){throw 'Specify exactly one of -Preflight or -Build.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Hash,[string]$State=''){Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3M9 build dependency absent: $Path";Assert-True ((Get-Sha $Path)-eq$Hash) "O3M9 build dependency changed: $Path";if($State){$v=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;Assert-True ([string]$v.state-eq$State) "O3M9 gate state changed: $Path"}}
function Write-NewJson([string]$Path,[object]$Value,[int]$Depth=16){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3M9 create-new JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
$expectedInvocationPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3M9_BUILD_INVOCATION.json'))
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3M9 build invocation path changed.'
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True ([string]$invocation.schema-eq'argos_o3m9_build_invocation_v1'-and[string]$invocation.state-eq'FROZEN_EXACT_BUILD_INVOCATION') 'O3M9 build invocation state changed.'
Assert-True ([string]$invocation.powerShellScriptSha256-eq(Get-Sha $PSCommandPath)) 'O3M9 invocation does not pin the exact builder.'
Assert-True ([string]$invocation.requestId-eq'REQ_20260827T230600111Z_62629419O3M9'-and[int]$invocation.maximumRequestsAuthorized-eq1-and-not[bool]$invocation.requestRetryAuthorized) 'O3M9 invocation authority changed.'
$requestId='REQ_20260827T230600111Z_62629419O3M9'
$requestName=$requestId+'.ready'
$zipName=$requestName+'.zip'
$staging='C:\A3M9B'
$partial=Join-Path $staging 'p'
$ready=Join-Path (Join-Path $staging 's') $requestName
$finalRoot=Join-Path $PSScriptRoot 'final_render'
$finalZip=Join-Path $finalRoot $zipName
$gatePath=Join-Path $PSScriptRoot 'O3M9_FINAL_PACKAGE_GATE.json'
$definition=Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$identity=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$routeGate=Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3D3\O3D3R4_COMPLETE_ROUTE_GATE.json'
$recoveryIntent=Join-Path $PSScriptRoot 'O3M9_RECOVERY_INTENT.json'
$rehearsalGate=Join-Path $PSScriptRoot 'O3M9_ENDPOINT_REHEARSAL_GATE.json'
$definitionSha='1A310294BF0423036BF66FE9312D023ED00553E9B0A0B7E341EA47FAEC9937B8'
$recoverySha='67B17EE9E7FCBD74CF57282BB01697E24741798F02C98A892420D5F4DE9673BB'
$rehearsalSha='B5383140D3AAD385EE27BE1B8B203E46D7B805EADC9362984DBF6AB2B724B941'
$files=@(
 [ordered]@{source=(Join-Path $PSScriptRoot 'Invoke-O3M9Slot16Endpoint.ps1');path='payload/Invoke-O3M9Slot16Endpoint.ps1';sha256='6FCBD72372DB278A9EF4C6476B57398D2F29478776CF82819945828B52C14A7A'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'FullPerimeterWaferTopologyOpenCvR7.py');path='payload/FullPerimeterWaferTopologyOpenCvR7.py';sha256='A6E63914D8669E3E733EA2BFC78FAF78F77B1FC5A54E9CC4D051F2AC34D2296B'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'NativeFrontsideWaferPoseOpenCvV2.py');path='payload/NativeFrontsideWaferPoseOpenCvV2.py';sha256='304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'NativeFrontsideWaferPoseOpenCvV2R5.py');path='payload/NativeFrontsideWaferPoseOpenCvV2R5.py';sha256='47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py');path='payload/NativeFrontsideWaferPoseOpenCvV2R6.py';sha256='90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'WaferTopologyAxisOpenCv.py');path='payload/WaferTopologyAxisOpenCv.py';sha256='D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'O3M9_ENDPOINT_LIVE_INVOCATION.json');path='payload/O3M9_ENDPOINT_LIVE_INVOCATION.json';sha256='00100836FE711D27A99C7B1CCC886B525BE75806D9BB1A3B7A63BE41020089DC'},
 [ordered]@{source=(Join-Path $PSScriptRoot 'O3M9_SLOT16_JOB.json');path='payload/O3M9_SLOT16_JOB.json';sha256='E384ABD12E9B77DB9B4492504A5D792E316C5396C3B0A3E1D2B1AB11BB4C7DD3'}
)
foreach($file in $files){Assert-Pin $file.source $file.sha256}
Assert-Pin $definition $definitionSha
Assert-Pin $recoveryIntent $recoverySha
Assert-Pin $rehearsalGate $rehearsalSha 'PASS'
Assert-Pin $queueGate '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
Assert-Pin $routeGate '41A4A1B808E40E7A14A8F22BA7BF9189C0B00B16639A43DDF5AB9A3FC70385D2' 'PASS_O3D3R4_COMPLETE_ROUTE_GATE'
foreach($tool in @($identity,$certificate,$packageTester,$pathTool)){Assert-True (Test-Path -LiteralPath $tool -PathType Leaf) "O3M9 build tool absent: $tool"}
$def=Get-Content -LiteralPath $definition -Raw|ConvertFrom-Json
Assert-True ([string]$def.targetRole-eq'JBOD'-and[string]$def.jobClass-eq'MAINTENANCE_PATCH'-and[string]$def.entryPoint-eq'payload/Invoke-O3M9Slot16Endpoint.ps1') 'O3M9 maintenance identity changed.'
Assert-True (@($def.changes).Count-eq0-and@($def.entryPointMutations).Count-eq2-and@($def.entryPointOutputs).Count-eq2-and@($def.allowedTaskActions).Count-eq0-and@($def.allowedProcessActions).Count-eq1) 'O3M9 maintenance cardinality changed.'
Assert-True ([bool]$def.sourceProcessingContract.sourceImageReadAuthorized-and[bool]$def.sourceProcessingContract.detectorRerunAllowed-and-not[bool]$def.sourceProcessingContract.thresholdOrAlgorithmChangeAllowed-and-not[bool]$def.sourceProcessingContract.backsidePixelsConsumed-and-not[bool]$def.sourceProcessingContract.argosRotationMetadataConsumed-and-not[bool]$def.requestRetryAuthorized) 'O3M9 processing authority changed.'
Assert-True ([bool]$def.reviewOnly-and-not[bool]$def.trainingEligible-and-not[bool]$def.xmlEligible-and-not[bool]$def.productionEligible-and-not[bool]$def.productionRoutingEnabled) 'O3M9 authority widened.'
foreach($path in @($staging,$partial,$ready,$finalRoot,$finalZip,$gatePath)){Assert-True (-not(Test-Path -LiteralPath $path)) "O3M9 fresh build target exists: $path"}
$planned=@($ready,(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'payload\FullPerimeterWaferTopologyOpenCvR7.py'),$finalZip,$gatePath,(Join-Path $staging 'x\payload\O3M9_ENDPOINT_LIVE_INVOCATION.json'))
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathGate.state-eq'PASS_PATH_BUDGET') 'O3M9 build path gate failed.'
if($Preflight){[ordered]@{schema='argos_o3m9_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3M9_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=8;definitionSha256=$definitionSha;recoveryIntentSha256=$recoverySha;rehearsalGateSha256=$rehearsalSha;pathState=[string]$pathGate.state;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

$identityValue=Get-Content -LiteralPath $identity -Raw|ConvertFrom-Json
$thumbprint=([string]$identityValue.thumbprint).Replace(' ','').ToUpperInvariant()
$store=New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser);$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try{$matches=@($store.Certificates|Where-Object{([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant()-eq$thumbprint});Assert-True ($matches.Count-eq1) 'O3M9 signer cardinality changed.';$signer=$matches[0]}finally{$store.Close();$store.Dispose()}
Assert-True $signer.HasPrivateKey 'O3M9 signer private key is absent.'
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$def.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=[int64](Get-Item -LiteralPath $_.source).Length;sha256=$_.sha256}});entryPoint=[string]$def.entryPoint;changes=@();entryPointMutations=@($def.entryPointMutations);entryPointOutputs=@($def.entryPointOutputs);sourceProcessingContract=$def.sourceProcessingContract;timeoutContract=$def.timeoutContract;allowedTaskActions=@();allowedProcessActions=@($def.allowedProcessActions);rehearsal=$def.rehearsal;requestRetryAuthorized=$false}
$requestPartial=Join-Path $partial $requestName;$payloadPartial=Join-Path $requestPartial 'payload';[void](New-Item -ItemType Directory -Path $payloadPartial)
foreach($file in $files){Copy-Item -LiteralPath $file.source -Destination (Join-Path $requestPartial $file.path.Replace('/','\')) -ErrorAction Stop}
$manifestPath=Join-Path $requestPartial 'PORTAL_REQUEST_MANIFEST.json';$signaturePath=Join-Path $requestPartial 'PORTAL_REQUEST_MANIFEST.sig';$utf8=New-Object Text.UTF8Encoding($false);$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 32));[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer);try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()};[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $ready));Move-Item -LiteralPath $requestPartial -Destination $ready
$packageTest=& $packageTester -PackagePath $ready -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH;Assert-True ([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE') 'O3M9 signed request verification failed.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPartial=Join-Path $staging $zipName;[IO.Compression.ZipFile]::CreateFromDirectory($ready,$zipPartial,[IO.Compression.CompressionLevel]::Optimal,$false)
$extract=Join-Path $staging 'x';[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial,$extract)
$expected=@{};foreach($file in $files){$expected[$file.path]=$file.sha256};$expected['PORTAL_REQUEST_MANIFEST.json']=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');$expected['PORTAL_REQUEST_MANIFEST.sig']=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
$leaves=@(Get-ChildItem -LiteralPath $extract -Recurse -File);Assert-True ($leaves.Count-eq10) 'O3M9 final ZIP file count changed.'
foreach($item in $expected.GetEnumerator()){$leaf=Join-Path $extract $item.Key.Replace('/','\');Assert-True (Test-Path -LiteralPath $leaf -PathType Leaf) "O3M9 final ZIP leaf absent: $($item.Key)";Assert-True ((Get-Sha $leaf)-eq[string]$item.Value) "O3M9 final ZIP leaf changed: $($item.Key)"}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract 'payload\Invoke-O3M9Slot16Endpoint.ps1'),[ref]$tokens,[ref]$errors);Assert-True (@($errors).Count-eq0) 'O3M9 extracted endpoint parser failed.'
$zipSha=Get-Sha $zipPartial
$gate=[ordered]@{schema='argos_o3m9_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3M9_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_EDGE_NOTCH_O3M9/final_render/'+$zipName;requestZipBytes=[int64](Get-Item $zipPartial).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];payloadFileCount=8;maintenanceDefinitionSha256=$definitionSha;endpointSha256=$files[0].sha256;engineSha256=$files[1].sha256;liveInvocationSha256=$files[6].sha256;jobSha256=$files[7].sha256;recoveryIntentSha256=$recoverySha;rehearsalGateSha256=$rehearsalSha;inheritedQueueGateSha256=Get-Sha $queueGate;inheritedCompleteRouteGateSha256=Get-Sha $routeGate;exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassed=$true;sourceImageBytesRead=$false;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false;backsidePixelsConsumed=$false;argosRotationMetadataConsumed=$false;sourceMutationPerformed=$false;processorTouched=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;publicationAuthorized=$false}
[void](New-Item -ItemType Directory -Path $finalRoot);Move-Item -LiteralPath $zipPartial -Destination $finalZip;Assert-True ((Get-Sha $finalZip)-eq$zipSha) 'O3M9 final ZIP move changed bytes.';Write-NewJson $gatePath $gate 16;Write-NewJson (Join-Path $finalRoot ($zipName+'.gate.json')) $gate 16
$resolvedStaging=[IO.Path]::GetFullPath($staging);Assert-True ($resolvedStaging-eq'C:\A3M9B') 'O3M9 staging cleanup target changed.';[IO.Directory]::Delete($resolvedStaging,$true)
$gate|ConvertTo-Json -Depth 16
