#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Build)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(@(@($Preflight,$Build)|Where-Object{[bool]$_}).Count-ne1){throw 'Specify exactly one of -Preflight or -Build.'}

function Get-Sha([string]$Path){return(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Sha,[string]$State=''){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)-or(Get-Sha $Path)-ne$Sha){throw "O3C2 pinned dependency changed: $Path"}
    if(-not[string]::IsNullOrWhiteSpace($State)){$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;if([string]$value.state-ne$State){throw "O3C2 pinned gate state changed: $Path"}}
}

$project=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root=$PSScriptRoot
$requestId='REQ_20260827T151200111Z_62629419C3F2'
$definitionPath=Join-Path $root 'MAINTENANCE_DEFINITION.json'
$entrypointPath=Join-Path $root 'Invoke-O3C2SourceFreezeEndpoint.ps1'
$providerPath=Join-Path $root 'OCV03_SourceFreezeProviderV1.ps1'
$targetsPath=Join-Path $root 'O3C2_SOURCE_TARGETS.json'
$stagingRoot='C:\A33'
$signedRoot=Join-Path $stagingRoot 's'
$partialSigned=Join-Path $stagingRoot 'sp'
$ready=Join-Path $signedRoot ($requestId+'.ready')
$finalRoot=Join-Path $root 'final_o3c2'
$partialFinal=Join-Path $stagingRoot 'f'
$zipName=$requestId+'.ready.zip'
$zipPath=Join-Path $finalRoot $zipName
$packageGatePath=Join-Path $root 'O3C2_FINAL_PACKAGE_GATE.json'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$entrypointSha='B6561FECE5570EC7A21CBB6BD56871871C1C4C829C781B4924893B36BCAE76F0'
$providerSha='1A73D69F38C1E578734E30376845DF308636A893A846CF86FB9531144FE04B88'
$targetsSha='AF94AAF89093781624C5A113BC58147CA1E94F030EC5132E2C00F1A26A1F79A4'
$definitionSha='C22B4E6855796654F324567920087B0E75ED0745452A8A2EA7E6EF384232D763'
Assert-Pin $entrypointPath $entrypointSha
Assert-Pin $providerPath $providerSha
Assert-Pin $targetsPath $targetsSha 'FROZEN'
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'O3C2_PROVIDER_LOCAL_GATE.json') '75AF2A42C629F6C9C71AE8EA58798E451E34B438C06E0290B09FC057455AA4D0' 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_LOCAL_GATE'
Assert-Pin (Join-Path $root 'O3C2_ENTRYPOINT_R3_GATE.json') '9CE430D938BEE89DEDD6965E9B784C7997E40A6E4AF74BADDA94FF0A78011DA9' 'PASS_O3C2_ENTRYPOINT_R3_GATE'
Assert-Pin (Join-Path $root 'O3C2_RECOVERY_INTENT.json') 'C10DBBBECD1B5E63C8238C02A3D99275885E6D8334F88704433227174A7A8F2B'
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_O2D23\O2D23_COMPLETE_ROUTE_GATE_R3.json') '04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3' 'PASS_O2D23_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
if([string]$definition.targetRole-ne'JBOD'-or[string]$definition.jobClass-ne'MAINTENANCE_PATCH'-or[string]$definition.entryPoint-ne'payload/Invoke-O3C2SourceFreezeEndpoint.ps1'-or@($definition.changes).Count-ne1-or@($definition.entryPointMutations).Count-ne0-or@($definition.entryPointOutputs).Count-ne1-or@($definition.allowedTaskActions).Count-ne0-or@($definition.allowedProcessActions).Count-ne0-or-not[bool]$definition.reviewOnly-or[bool]$definition.productionRoutingEnabled){throw 'O3C2 maintenance definition contract changed.'}
if([string]$definition.changes[0].source-ne'payload/OCV03_SourceFreezeProviderV1.ps1'-or[string]$definition.changes[0].destination-ne'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_SourceFreezeProviderV1.ps1'-or[string]$definition.changes[0].installedSha256-ne$providerSha-or@($definition.changes[0].approvedPredecessorSha256).Count-ne1-or@($definition.changes[0].approvedPredecessorSha256)-notcontains$providerSha-or-not[bool]$definition.changes[0].allowCreate){throw 'O3C2 installed-provider contract changed.'}
$contract=$definition.sourceReadContract
if([string]$contract.mode-ne'EXACT_FROZEN_TWENTY_LEAF_SHA256_ONLY'-or[string]$contract.targetManifest-ne'payload/O3C2_SOURCE_TARGETS.json'-or[string]$contract.targetManifestSha256-ne$targetsSha-or[int]$contract.pairCount-ne10-or[int]$contract.leafCount-ne20-or-not[bool]$contract.fileContentReadAllowedForHashOnly-or[bool]$contract.imageDecodeAllowed-or[bool]$contract.pixelProcessingAllowed-or[bool]$contract.knownNotchLocationConsumed-or[bool]$contract.notchAnglePriorConsumed-or[bool]$contract.fixedAngularSearchWindowConsumed-or[bool]$contract.sourceMutationAllowed-or[bool]$contract.taskOrProcessActionAllowed-or[bool]$contract.providerActivationAllowed){throw 'O3C2 source-read contract changed.'}

foreach($path in @($stagingRoot,$signedRoot,$partialSigned,$finalRoot,$partialFinal,$packageGatePath)){if(Test-Path -LiteralPath $path){throw "O3C2 fresh output already exists: $path"}}
$planned=@($ready,(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'),(Join-Path $ready 'payload\Invoke-O3C2SourceFreezeEndpoint.ps1'),(Join-Path $ready 'payload\OCV03_SourceFreezeProviderV1.ps1'),(Join-Path $ready 'payload\O3C2_SOURCE_TARGETS.json'),$zipPath,(Join-Path $partialFinal 'extract\payload\Invoke-O3C2SourceFreezeEndpoint.ps1'),(Join-Path $partialFinal 'extract\payload\OCV03_SourceFreezeProviderV1.ps1'),(Join-Path $partialFinal 'extract\payload\O3C2_SOURCE_TARGETS.json'),$packageGatePath)
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'O3C2 package path gate failed.'}

if($Preflight){
    [ordered]@{schema='argos_o3c2_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_BUILD_PREFLIGHT';requestId=$requestId;entrypointSha256=$entrypointSha;providerSha256=$providerSha;targetManifestSha256=$targetsSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;mutationsPerformed=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store=New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try{$certificateMatches=@($store.Certificates|Where-Object{([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant()-eq$thumbprint});if($certificateMatches.Count-ne1){throw 'O3C2 signer certificate cardinality changed.'};$certificate=$certificateMatches[0]}
finally{$store.Close();$store.Dispose()}
if(-not$certificate.HasPrivateKey){throw 'O3C2 signer private key is unavailable.'}
$files=@(
    [ordered]@{source=$entrypointPath;path='payload/Invoke-O3C2SourceFreezeEndpoint.ps1';bytes=(Get-Item -LiteralPath $entrypointPath).Length;sha256=$entrypointSha},
    [ordered]@{source=$providerPath;path='payload/OCV03_SourceFreezeProviderV1.ps1';bytes=(Get-Item -LiteralPath $providerPath).Length;sha256=$providerSha},
    [ordered]@{source=$targetsPath;path='payload/O3C2_SOURCE_TARGETS.json';bytes=(Get-Item -LiteralPath $targetsPath).Length;sha256=$targetsSha}
)
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@();entryPointOutputs=@($definition.entryPointOutputs);sourceReadContract=$definition.sourceReadContract;allowedTaskActions=@();allowedProcessActions=@();rehearsal=$definition.rehearsal
}
$partialReady=Join-Path $partialSigned ($requestId+'.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partialReady 'payload'))
foreach($file in $files){Copy-Item -LiteralPath $file.source -Destination (Join-Path $partialReady $file.path.Replace('/','\'))}
$manifestPath=Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath=Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'
$utf8=New-Object Text.UTF8Encoding($false)
$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath $partialReady -Destination $ready
Remove-Item -LiteralPath $partialSigned -Force
$packageTest=& $packageTester -PackagePath $ready -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if([string]$packageTest.State-ne'PASS_SIGNED_PORTAL_PACKAGE'){throw 'O3C2 signed package verification failed.'}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip=Join-Path $partialFinal $zipName
$extract=Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($ready,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extract)
$expected=@{'payload/Invoke-O3C2SourceFreezeEndpoint.ps1'=$entrypointSha;'payload/OCV03_SourceFreezeProviderV1.ps1'=$providerSha;'payload/O3C2_SOURCE_TARGETS.json'=$targetsSha;'PORTAL_REQUEST_MANIFEST.json'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted=@(Get-ChildItem -LiteralPath $extract -Recurse -File)
if($extracted.Count-ne5){throw 'O3C2 final ZIP file count changed.'}
foreach($item in $expected.GetEnumerator()){$path=Join-Path $extract $item.Key.Replace('/','\');if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Sha $path)-ne[string]$item.Value){throw "O3C2 final ZIP file changed: $($item.Key)"}}
foreach($script in @((Join-Path $extract 'payload\Invoke-O3C2SourceFreezeEndpoint.ps1'),(Join-Path $extract 'payload\OCV03_SourceFreezeProviderV1.ps1'))){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($script,[ref]$tokens,[ref]$errors);if(@($errors).Count-ne0){throw "O3C2 extracted payload parser failed: $script"}}
$zipSha=Get-Sha $partialZip
$gate=[ordered]@{schema='argos_o3c2_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_EDGE_NOTCH_O3C2/final_o3c2/'+$zipName);requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;entrypointSha256=$entrypointSha;providerSha256=$providerSha;targetManifestSha256=$targetsSha;providerInstalledDestination='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_SourceFreezeProviderV1.ps1';maintenanceInstalledShaMatchesPayload=$true;providerGateSha256='75AF2A42C629F6C9C71AE8EA58798E451E34B438C06E0290B09FC057455AA4D0';entrypointGateSha256='9CE430D938BEE89DEDD6965E9B784C7997E40A6E4AF74BADDA94FF0A78011DA9';recoveryIntentSha256='C10DBBBECD1B5E63C8238C02A3D99275885E6D8334F88704433227174A7A8F2B';inheritedCompleteRouteGateSha256='04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3';inheritedQueueGateSha256='170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D';exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassedForPayloadScripts=2;installedProviderExecutedInLocalRehearsal=$true;shortLocalStagingRoot=$stagingRoot;sourceImageBytesRead=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;processorTaskChanged=$false;currentWaferAborted=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;publicationAuthorized=$false;publicationRequiresCompleteRouteGate=$true}
[void](New-Item -ItemType Directory -Path $finalRoot)
Move-Item -LiteralPath $partialZip -Destination $zipPath
if((Get-Sha $zipPath)-ne$zipSha){throw 'O3C2 final ZIP move changed bytes.'}
[IO.File]::WriteAllText((Join-Path $finalRoot ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
[IO.Directory]::Delete($stagingRoot,$true)
[IO.File]::WriteAllText($packageGatePath,(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
$gate|ConvertTo-Json -Depth 10
