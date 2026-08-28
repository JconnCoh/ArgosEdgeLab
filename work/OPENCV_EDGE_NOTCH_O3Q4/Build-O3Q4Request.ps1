[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(@(@($Preflight,$Build)|Where-Object{[bool]$_}).Count-ne1){throw 'Specify exactly one of -Preflight or -Build.'}

function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Sha,[string]$State=''){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)-or(Get-Sha $Path)-ne$Sha){throw "O3Q4 pinned dependency changed: $Path"}
    if(-not[string]::IsNullOrWhiteSpace($State)){$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;if([string]$value.state-ne$State){throw "O3Q4 pinned gate state changed: $Path"}}
}

$project=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root=$PSScriptRoot
$requestId='REQ_20260828T152800444Z_62629419O3Q4'
$definitionPath=Join-Path $root 'MAINTENANCE_DEFINITION.json'
$entrypointPath=Join-Path $root 'Invoke-O3Q4Slot16Numeric.ps1'
$stagingRoot='C:\A39'
$signedRoot=Join-Path $stagingRoot 's'
$partialSigned=Join-Path $stagingRoot 'sp'
$ready=Join-Path $signedRoot 'REQ_20260828T152800444Z_62629419O3Q4.ready'
$finalRoot=Join-Path $root 'final_o3q4'
$partialFinal=Join-Path $stagingRoot 'f'
$zipName='REQ_20260828T152800444Z_62629419O3Q4.ready.zip'
$zipPath=Join-Path $finalRoot $zipName
$packageGatePath=Join-Path $root 'O3Q4_FINAL_PACKAGE_GATE.json'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$entrypointSha='167002F5096F04125259EEE27979FDF433A61D4608C04D46373DD0F41C842151'
$anchorSha='6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
$definitionSha='BD6E797D17F994AC04A45143A0FCC407CFF193605FCE1113FBCA670FD94F79FB'
$payloadSpecs=@(
    [ordered]@{source=$entrypointPath;path='payload/Invoke-O3Q4Slot16Numeric.ps1';sha256=$entrypointSha},
    [ordered]@{source=(Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3P8\Detect-O3P8FrontSplitNotches.py');path='payload/Detect-O3P8FrontSplitNotches.py';sha256='41F60AF393E0B2C752AF6B33BB6673145490AE2BB346A4DA8E59A2D42E383E36'},
    [ordered]@{source=(Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3L8\WaferTopologyAxisOpenCv.py');path='payload/WaferTopologyAxisOpenCv.py';sha256='D8897C1A5B60CB5AA9B0343CF8C9E5A249CCC5DEF5FBCDFE645EC08C354EF3BD'},
    [ordered]@{source=(Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3K1\OCV03_NotchReviewOpenCvV1.py');path='payload/OCV03_NotchReviewOpenCvV1.py';sha256=$anchorSha},
    [ordered]@{source=(Join-Path $root 'O3Q4_SLOT16_SEED_PROJECTION.json');path='payload/O3Q4_SLOT16_SEED_PROJECTION.json';sha256='EEF259AAF045FC678A3ACE0CCA35BB67D52626BE37E12B6BDD733F5F908A5F5E'},
    [ordered]@{source=(Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3N1\local_review_r2\assets\MANIFEST.json');path='payload/O3N1_NUMERIC_MANIFEST.json';sha256='69FDAD4AB4DCF06A8A38C76EA009F0DA178896E8D0291668670AB9ADD24A05C8'},
    [ordered]@{source=(Join-Path $project 'work\O3J1R\files\S16.json');path='payload/S16_SOURCE_RECORD.json';sha256='FBBF0609AD337D495E90E73C6F175E6D255287730B81498CE23C4C83536760B1'},
    [ordered]@{source=(Join-Path $root 'O3Q4_RUNTIME_GATE.json');path='payload/O3Q4_RUNTIME_GATE.json';sha256='09DEEF0BC1C0DC9464F5BF5CE93EF590F2780F3123BB13AB6080358E562C68C4'},
    [ordered]@{source=(Join-Path $root 'O3Q4_JOB_CONTRACT.json');path='payload/O3Q4_JOB_CONTRACT.json';sha256='16109E6E788FED7886300ADB13DD52A86BF41A94D6852B471150C2E74215ADA7'},
    [ordered]@{source=(Join-Path $root 'O3Q4_TERMINAL_GATE_FIXTURE.json');path='payload/O3Q4_TERMINAL_GATE_FIXTURE.json';sha256='55318F9FBFBF72A8C03B49F5AE59E1B0AA0132FA7A740A195EA3C14A8A6F1765'},
    [ordered]@{source=(Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3P8\O3P8_DETECTOR_CONFIG_EQUIVALENCE_GATE.json');path='payload/O3P8_DETECTOR_CONFIG_EQUIVALENCE_GATE.json';sha256='CF896E114179370BC9C8A58D64FDD3470EDCAB1A96836252693C935845224F95'},
    [ordered]@{source=(Join-Path $root 'O3Q4_ENDPOINT_LIVE_INVOCATION.json');path='payload/O3Q4_ENDPOINT_LIVE_INVOCATION.json';sha256='8C50CE2945F2E2B33F3EED04A3F804721053A7AFE05D5FD14EA9E7B794A50705'}
)
foreach($spec in $payloadSpecs){Assert-Pin ([string]$spec.source) ([string]$spec.sha256)}
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'O3Q4_ENDPOINT_REHEARSAL_GATE.json') '9199E68FBC6ABA429E842485AA280A35D9669C6C665D6004B8FA949EFAE8618F' 'PASS_O3Q4_POST2_NUMERIC_REHEARSAL'
Assert-Pin (Join-Path $root 'O3Q4_ENDPOINT_STATIC_GATE.json') 'CA1452A879CD760748F0911041A3BBA4A7F076ED8364504AB3F1E6C3C3A2FFC1' 'PASS_O3Q4_ENDPOINT_STATIC_AND_PREFLIGHT_GATES'
Assert-Pin (Join-Path $root 'O3Q4_DETECTOR_CONFIG_LOCK_GATE.json') '63E6AC664D3C5D4654312C80561DA9BAE518A538663283EA33BABB5F3C2BBC60' 'PASS_O3Q4_UNCHANGED_O3P8_DETECTOR_AND_CONFIG'
Assert-Pin (Join-Path $root 'O3Q4_RECOVERY_INTENT.json') '3362A52D432A8032C0F9A51F602A732DAD5CDF3AB6615E4B356DE69B8E147AC5'
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_O2D23\O2D23_COMPLETE_ROUTE_GATE_R3.json') '04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3' 'PASS_O2D23_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
if([string]$definition.targetRole-ne'JBOD'-or[string]$definition.jobClass-ne'MAINTENANCE_PATCH'-or[string]$definition.entryPoint-ne'payload/Invoke-O3Q4Slot16Numeric.ps1'-or@($definition.changes).Count-ne1-or@($definition.entryPointMutations).Count-ne1-or@($definition.entryPointOutputs).Count-ne1-or@($definition.allowedTaskActions).Count-ne0-or@($definition.allowedProcessActions).Count-ne1-or-not[bool]$definition.reviewOnly-or[bool]$definition.productionRoutingEnabled-or[bool]$definition.requestRetryAuthorized){throw 'O3Q4 maintenance definition contract changed.'}
if([string]$definition.changes[0].source-ne'payload/OCV03_NotchReviewOpenCvV1.py'-or[string]$definition.changes[0].destination-ne'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_NotchReviewOpenCvV1.py'-or[string]$definition.changes[0].installedSha256-ne$anchorSha-or@($definition.changes[0].approvedPredecessorSha256).Count-ne1-or@($definition.changes[0].approvedPredecessorSha256)-notcontains$anchorSha-or[bool]$definition.changes[0].allowCreate){throw 'O3Q4 same-hash installed protocol anchor changed.'}
if([string]$definition.entryPointMutations[0].targetRoot-ne'D:\A2\o\ocv\O3Q4_20260828T151900Z'-or[string]$definition.entryPointMutations[0].mode-ne'CREATE_NEW_NUMERIC_REVIEW_ONLY_OUTPUT_TREE'-or[string]$definition.entryPointOutputs[0].path-ne'D:\A2\o\ocv\O3Q4_20260828T151900Z\O3Q4_RESULT.json'-or-not[bool]$definition.sourceProcessingContract.sourceImageReadAuthorized-or[bool]$definition.sourceProcessingContract.thresholdOrAlgorithmChangeAllowed-or[bool]$definition.sourceProcessingContract.backsidePixelsConsumed-or[bool]$definition.sourceProcessingContract.argosRotationMetadataConsumed-or[bool]$definition.sourceProcessingContract.knownNotchLocationConsumed-or[bool]$definition.sourceProcessingContract.sourceMutationAllowed-or[bool]$definition.sourceProcessingContract.sourceDeletionAllowed-or[string]$definition.allowedProcessActions[0]-ne'START_BOUNDED_OWNED_PORTABLE_OPENCV_O3P8_SLOT16_NUMERIC_CHILD_ONLY'){throw 'O3Q4 numeric execution boundary changed.'}

foreach($path in @($stagingRoot,$signedRoot,$partialSigned,$finalRoot,$partialFinal,$packageGatePath)){if(Test-Path -LiteralPath $path){throw "O3Q4 fresh output already exists: $path"}}
$planned=@($ready,(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'),$zipPath,$packageGatePath)
foreach($spec in $payloadSpecs){$planned+=Join-Path $ready ([string]$spec.path).Replace('/','\');$planned+=Join-Path (Join-Path $partialFinal 'extract') ([string]$spec.path).Replace('/','\')}
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'O3Q4 package path gate failed.'}

if($Preflight){
    [ordered]@{schema='argos_o3q4_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q4_BUILD_PREFLIGHT';requestId=$requestId;payloadCount=$payloadSpecs.Count;entrypointSha256=$entrypointSha;installedAnchorSha256=$anchorSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;maximumPublications=1;retryAuthorized=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store=New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try{$certificateMatches=@($store.Certificates|Where-Object{([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant()-eq$thumbprint});if($certificateMatches.Count-ne1){throw 'O3Q4 signer certificate cardinality changed.'};$certificate=$certificateMatches[0]}
finally{$store.Close();$store.Dispose()}
if(-not$certificate.HasPrivateKey){throw 'O3Q4 signer private key is unavailable.'}
$files=@($payloadSpecs|ForEach-Object{[ordered]@{source=[string]$_.source;path=[string]$_.path;bytes=(Get-Item -LiteralPath ([string]$_.source)).Length;sha256=[string]$_.sha256}})
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@($definition.allowedTaskActions);allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal;requestRetryAuthorized=$false
}
[void](New-Item -ItemType Directory -Path (Join-Path $partialSigned 'REQ_20260828T152800444Z_62629419O3Q4.ready\payload'))
foreach($file in $files){Copy-Item -LiteralPath $file.source -Destination (Join-Path (Join-Path $partialSigned 'REQ_20260828T152800444Z_62629419O3Q4.ready') $file.path.Replace('/','\'))}
$manifestPath=Join-Path $partialSigned 'REQ_20260828T152800444Z_62629419O3Q4.ready\PORTAL_REQUEST_MANIFEST.json'
$signaturePath=Join-Path $partialSigned 'REQ_20260828T152800444Z_62629419O3Q4.ready\PORTAL_REQUEST_MANIFEST.sig'
$utf8=New-Object Text.UTF8Encoding($false)
$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath (Join-Path $partialSigned 'REQ_20260828T152800444Z_62629419O3Q4.ready') -Destination $ready
Remove-Item -LiteralPath $partialSigned -Force
$packageTest=& $packageTester -PackagePath $ready -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if([string]$packageTest.State-ne'PASS_SIGNED_PORTAL_PACKAGE'){throw 'O3Q4 signed package verification failed.'}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip=Join-Path $partialFinal $zipName
$extract=Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($ready,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extract)
$expected=@{}
foreach($spec in $payloadSpecs){$expected[[string]$spec.path]=[string]$spec.sha256}
$expected['PORTAL_REQUEST_MANIFEST.json']=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json')
$expected['PORTAL_REQUEST_MANIFEST.sig']=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')
$extracted=@(Get-ChildItem -LiteralPath $extract -Recurse -File)
if($extracted.Count-ne($payloadSpecs.Count+2)){throw 'O3Q4 final ZIP file count changed.'}
foreach($item in $expected.GetEnumerator()){$path=Join-Path $extract $item.Key.Replace('/','\');if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Sha $path)-ne[string]$item.Value){throw "O3Q4 final ZIP file changed: $($item.Key)"}}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract 'payload\Invoke-O3Q4Slot16Numeric.ps1'),[ref]$tokens,[ref]$errors);if(@($errors).Count-ne0){throw 'O3Q4 extracted entrypoint parser failed.'}
$zipSha=Get-Sha $partialZip
$gate=[ordered]@{schema='argos_o3q4_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q4_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_EDGE_NOTCH_O3Q4/final_o3q4/REQ_20260828T152800444Z_62629419O3Q4.ready.zip';requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;payloadCount=$payloadSpecs.Count;entrypointSha256=$entrypointSha;installedAnchorSha256=$anchorSha;installedAnchorDestination='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_NotchReviewOpenCvV1.py';maintenanceInstalledShaMatchesPayload=$true;endpointRehearsalGateSha256='9199E68FBC6ABA429E842485AA280A35D9669C6C665D6004B8FA949EFAE8618F';endpointStaticGateSha256='CA1452A879CD760748F0911041A3BBA4A7F076ED8364504AB3F1E6C3C3A2FFC1';detectorConfigGateSha256='63E6AC664D3C5D4654312C80561DA9BAE518A538663283EA33BABB5F3C2BBC60';recoveryIntentSha256='3362A52D432A8032C0F9A51F602A732DAD5CDF3AB6615E4B356DE69B8E147AC5';inheritedCompleteRouteGateSha256='04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3';inheritedQueueGateSha256='170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D';exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassedForPayloadScripts=1;exactEndpointPassedLocalNumericRehearsal=$true;shortLocalStagingRoot=$stagingRoot;sourceImageBytesReadDuringBuild=$false;sourceHashingPerformedDuringBuild=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;existingProcessesQueried=$false;processorTaskChanged=$false;protectedProcessorTouched=$false;currentWaferAborted=$false;providerActivated=$false;maximumPublications=1;retryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;publicationAuthorized=$false;publicationRequiresCompleteRouteGate=$true}
[void](New-Item -ItemType Directory -Path $finalRoot)
Move-Item -LiteralPath $partialZip -Destination $zipPath
if((Get-Sha $zipPath)-ne$zipSha){throw 'O3Q4 final ZIP move changed bytes.'}
[IO.File]::WriteAllText((Join-Path $finalRoot ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
[IO.Directory]::Delete($stagingRoot,$true)
[IO.File]::WriteAllText($packageGatePath,(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
$gate|ConvertTo-Json -Depth 10
