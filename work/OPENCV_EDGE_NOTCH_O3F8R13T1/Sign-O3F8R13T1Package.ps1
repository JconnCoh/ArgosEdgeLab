#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Sign)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Sign)){throw 'Specify exactly one of -Preflight or -Sign.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function New-Bytes([string]$Path,[byte[]]$Bytes){Require (-not(Test-Path -LiteralPath $Path)) "O3F8R13T1 create-new path exists: $Path";[IO.File]::WriteAllBytes($Path,$Bytes)}
function New-Json([string]$Path,[object]$Value){Require (-not(Test-Path -LiteralPath $Path)) "O3F8R13T1 create-new JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root='C:\O3F8R13T1PKR1'
$payload=Join-Path $root 'payload'
$definitionPath=Join-Path $root 'DEFINITION.json'
$buildGatePath=Join-Path $PSScriptRoot 'O3F8R13T1_BUILD_GATE_R1.json'
$signGatePath=Join-Path $PSScriptRoot 'O3F8R13T1_SIGN_GATE.json'
$finalRoot=Join-Path $PSScriptRoot 'final_o3f8r13t1'
$signedRoot=Join-Path $root 'signed'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$certificatePath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$verifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
foreach($path in @($definitionPath,$buildGatePath,$identityPath,$certificatePath,$verifier)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F8R13T1 signing dependency absent: $path"}
$buildGate=Get-Content -LiteralPath $buildGatePath -Raw|ConvertFrom-Json
$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
Require ([string]$buildGate.state-eq'PASS_O3F8R13T1_UNSIGNED_TARGETED_PACKAGE_BUILT'-and[string]$buildGate.definitionSha256-eq(Sha $definitionPath)) 'O3F8R13T1 build evidence changed.'
Require ([string]$definition.state-eq'FROZEN_FOR_SIGNING'-and[string]$definition.targetRole-eq'JBOD'-and[string]$definition.jobClass-eq'MAINTENANCE_PATCH'-and[string]$definition.entryPoint-eq'payload/Invoke-O3F8R13T1.ps1') 'O3F8R13T1 definition is not frozen for signing.'
Require (@($definition.changes).Count-eq1-and@($definition.allowedTaskActions).Count-eq0-and@($definition.allowedProcessActions).Count-eq2-and@($definition.entryPointOutputs).Count-eq4-and[int]$definition.sourceProcessingContract.expectedPairCount-eq11-and[int]$definition.sourceProcessingContract.hotspotCount-eq10-and[int]$definition.sourceProcessingContract.providerErrorCount-eq5-and[string]$definition.sourceProcessingContract.side-eq'FRONT') 'O3F8R13T1 maintenance bounds changed.'
$change=@($definition.changes)[0]
$carrierHash='6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
Require ([string]$change.source-eq'payload/OCV03_NotchReviewOpenCvV1.py'-and[string]$change.destination-eq'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py'-and[string]$change.installedSha256-eq$carrierHash-and@($change.approvedPredecessorSha256).Count-eq1-and([string]@($change.approvedPredecessorSha256)[0])-eq$carrierHash-and-not[bool]$change.allowCreate) 'O3F8R13T1 same-bytes carrier contract changed.'
Require ([string]$buildGate.endpointWorkerSha256-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'-and[string]$buildGate.installedRouteConfigEvidenceSha256-eq'465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'-and[string]$buildGate.queueSafetyGateSha256-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F8R13T1 inherited portal route evidence changed.'
$actual=@(Get-ChildItem -LiteralPath $payload -File|Sort-Object Name)
Require ($actual.Count-eq[int]$buildGate.payloadFileCount) 'O3F8R13T1 payload cardinality changed.'
foreach($row in @($buildGate.payloadFiles)){$path=Join-Path $payload ([string]$row.path);Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F8R13T1 payload absent: $($row.path)";Require ((Get-Item -LiteralPath $path).Length-eq[int64]$row.bytes-and(Sha $path)-eq[string]$row.sha256) "O3F8R13T1 payload changed: $($row.path)"}
$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumb=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$certificate=Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumb") -ErrorAction Stop
Require ([bool]$certificate.HasPrivateKey) 'O3F8R13T1 signer private key unavailable.'
$plannedRequest='REQ_20260903T235959999Z_0123456789AB'
$plannedReady=Join-Path $signedRoot ($plannedRequest+'.ready')
$plannedZip=Join-Path $finalRoot ($plannedRequest+'.ready.zip')
$pathGate=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @($finalRoot,$signedRoot,(Join-Path $plannedReady 'payload\FullPerimeterWaferTopologyOpenCvR13.py'),(Join-Path $plannedReady 'PORTAL_REQUEST_MANIFEST.json'),$plannedZip,$signGatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Require ([string]$pathGate.state-eq'PASS_PATH_BUDGET') 'O3F8R13T1 final package path gate failed.'
foreach($path in @($finalRoot,$signedRoot,$signGatePath)){Require (-not(Test-Path -LiteralPath $path)) "O3F8R13T1 create-new signing target exists: $path"}

if($Preflight){[ordered]@{schema='argos_ocv03_o3f8r13t1_sign_preflight_v1';state='PASS_O3F8R13T1_SIGN_PREFLIGHT';definitionSha256=Sha $definitionPath;buildGateSha256=Sha $buildGatePath;payloadFileCount=$actual.Count;finalRoot=$finalRoot;pathState=[string]$pathGate.state;signerThumbprint=$thumb;expectedPairCount=11;hotspotCount=10;providerErrorCount=5;side='FRONT';endpointWorkerSha256=[string]$buildGate.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$buildGate.installedRouteConfigEvidenceSha256;queueSafetyGateSha256=[string]$buildGate.queueSafetyGateSha256;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

[void](New-Item -ItemType Directory -Path $finalRoot)
[void](New-Item -ItemType Directory -Path $signedRoot)
$created=[DateTimeOffset]::UtcNow
$requestId='REQ_'+$created.ToString('yyyyMMddTHHmmssfffZ')+'_'+([Guid]::NewGuid().ToString('N').Substring(0,12).ToUpperInvariant())
$partial=Join-Path $signedRoot ($requestId+'.partial')
$ready=Join-Path $signedRoot ($requestId+'.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload') -Force)
foreach($item in $actual){[IO.File]::Copy($item.FullName,(Join-Path (Join-Path $partial 'payload') $item.Name),$false)}
$files=@(Get-ChildItem -LiteralPath (Join-Path $partial 'payload') -File|Sort-Object Name|ForEach-Object{[ordered]@{path='payload/'+$_.Name;bytes=[int64]$_.Length;sha256=Sha $_.FullName}})
Require ($files.Count-eq$actual.Count) 'O3F8R13T1 signed payload cardinality changed.'
$manifest=[ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumb;signatureAlgorithm='RSA-SHA256-PKCS1';files=$files;entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@();allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal;requestRetryAuthorized=$false}
$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($manifest|ConvertTo-Json -Depth 32))
New-Bytes (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json') $bytes
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
New-Bytes (Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig') $signature
Move-Item -LiteralPath $partial -Destination $ready
& $verifier -PackagePath $ready -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH|Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip=Join-Path $finalRoot ($requestId+'.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($ready,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$gate=[ordered]@{schema='argos_ocv03_o3f8r13t1_sign_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F8R13T1_SIGNED_TARGETED_PACKAGE';requestId=$requestId;finalRoot=$finalRoot;packagePath=$ready;packageZipPath=$zip;packageZipBytes=[int64](Get-Item -LiteralPath $zip).Length;packageZipSha256=Sha $zip;manifestSha256=Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');signatureSha256=Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig');signerThumbprint=$thumb;exactPackageSignaturePassed=$true;payloadFileCount=$files.Count;pythonCacheLeafCount=0;contractSha256=[string]$buildGate.contractSha256;expectedPairCount=11;hotspotCount=10;providerErrorCount=5;side='FRONT';r13Sha256=[string]$buildGate.r13Sha256;endpointWorkerSha256=[string]$buildGate.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$buildGate.installedRouteConfigEvidenceSha256;queueSafetyGateSha256=[string]$buildGate.queueSafetyGateSha256;allowedTaskActionCount=0;signed=$true;published=$false;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
New-Json $signGatePath $gate
$gate|ConvertTo-Json -Depth 10
