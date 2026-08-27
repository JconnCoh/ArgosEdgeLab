#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Build)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Build)){throw 'Specify exactly one of -Preflight or -Build.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Hash,[string]$State=''){Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3J1 pinned dependency is absent: $Path";Assert-True ((Get-Sha $Path)-eq$Hash) "O3J1 pinned dependency changed: $Path";if(-not[string]::IsNullOrWhiteSpace($State)){$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;Assert-True ([string]$value.state-eq$State) "O3J1 pinned gate state changed: $Path"}}

$project=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root=$PSScriptRoot
$requestId='REQ_20260827T185500111Z_62629419O3J1'
$requestDirName=$requestId+'.ready'
$zipName=$requestDirName+'.zip'
$entrypoint=Join-Path $root 'Invoke-O3J1ResultJsonEndpoint.ps1'
$provider=Join-Path $root 'OCV03_ResultJsonProviderV1.ps1'
$configuration=Join-Path $root 'O3J1_RESULT_JSON_PROVIDER_CONFIG.json'
$collectionInvocation=Join-Path $root 'O3J1_RESULT_JSON_INVOCATION.json'
$definition=Join-Path $root 'MAINTENANCE_DEFINITION.json'
$staging='C:\A3J1'
$partial=Join-Path $staging 'p'
$ready=Join-Path (Join-Path $staging 's') $requestDirName
$finalRoot=Join-Path $root 'final'
$finalZip=Join-Path $finalRoot $zipName
$gatePath=Join-Path $root 'O3J1_FINAL_PACKAGE_GATE.json'
$identity=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$entrypointSha='A30D0150EF309464034EAF5B5EBD87C7E23050DB756E76A8EA5B7BA242016862'
$providerSha='EF9773ADAC624A7A8A689989AB0EE404C2863B4E32B2666F437331E8CC9CAE67'
$configurationSha='01C09158CF67EB9C04C84DE35F8C039D9F0F5B913319E304543AD8482ACE3EA0'
$collectionInvocationSha='6220CD7638D83EA18FE24E4C31A29FD542747B99ECF6AE6B205E5556335CC96B'
$definitionSha='E377BF771A5942112534653C234E88655BAC4D8E6C21017459E95C7B9524DBB4'
Assert-Pin $entrypoint $entrypointSha
Assert-Pin $provider $providerSha
Assert-Pin $configuration $configurationSha
Assert-Pin $collectionInvocation $collectionInvocationSha
Assert-Pin $definition $definitionSha
Assert-Pin (Join-Path $root 'O3J1_PROVIDER_GATE_R2.json') '5ED3A1568193C6D4AEBC1DBD03A158ED8EB2A8C88807F94D8B567061D71A02BA' 'PASS_O3J1_RESULT_JSON_PROVIDER_GATE'
Assert-Pin (Join-Path $root 'O3J1_ENTRYPOINT_GATE.json') '649024CB557E690A87AD52666DA41A3AA7D98E96140EA0B8319EC0D9D2C5246F' 'PASS_O3J1_ENTRYPOINT_GATE'
Assert-Pin (Join-Path $root 'O3J1_RECOVERY_INTENT_R2.json') '0147AC058D62580EEE50E95839D1C989FD854D54A11B5CFF0A3F6BFBF49D6A70'
Assert-Pin (Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3D3\O3D3R4_COMPLETE_ROUTE_GATE.json') '41A4A1B808E40E7A14A8F22BA7BF9189C0B00B16639A43DDF5AB9A3FC70385D2' 'PASS_O3D3R4_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$def=Get-Content -LiteralPath $definition -Raw|ConvertFrom-Json
Assert-True ([string]$def.targetRole-eq'JBOD'-and[string]$def.jobClass-eq'MAINTENANCE_PATCH'-and[string]$def.entryPoint-eq'payload/Invoke-O3J1ResultJsonEndpoint.ps1') 'O3J1 maintenance identity changed.'
Assert-True (@($def.changes).Count-eq2-and@($def.entryPointMutations).Count-eq0-and@($def.entryPointOutputs).Count-eq0-and@($def.allowedTaskActions).Count-eq0-and@($def.allowedProcessActions).Count-eq0) 'O3J1 maintenance action cardinality changed.'
Assert-True ([int64]$def.maxResultBytes-eq67108864-and[bool]$def.jsonReadContract.sourceJsonContentReadAllowed-and-not[bool]$def.jsonReadContract.sourceImageBytesReadAllowed-and-not[bool]$def.jsonReadContract.sourceMutationAllowed-and-not[bool]$def.jsonReadContract.taskOrProcessActionAllowed-and-not[bool]$def.jsonReadContract.providerActivationAllowed) 'O3J1 JSON read contract changed.'
Assert-True ([bool]$def.reviewOnly-and-not[bool]$def.trainingEligible-and-not[bool]$def.xmlEligible-and-not[bool]$def.productionEligible-and-not[bool]$def.productionRoutingEnabled-and-not[bool]$def.requestRetryAuthorized) 'O3J1 authority changed.'
$expectedChanges=@{
 'payload/OCV03_ResultJsonProviderV1.ps1'=@{destination='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_ResultJsonProviderV1.ps1';hash=$providerSha}
 'payload/O3J1_RESULT_JSON_PROVIDER_CONFIG.json'=@{destination='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_O3J1_RESULT_JSON_PROVIDER_CONFIG.json';hash=$configurationSha}
}
foreach($change in @($def.changes)){$source=[string]$change.source;Assert-True ($expectedChanges.ContainsKey($source)) "O3J1 unexpected change source: $source";$expected=$expectedChanges[$source];Assert-True ([string]$change.destination-eq[string]$expected.destination-and[string]$change.installedSha256-eq[string]$expected.hash-and@($change.approvedPredecessorSha256).Count-eq1-and@($change.approvedPredecessorSha256)-contains[string]$expected.hash-and[bool]$change.allowCreate) "O3J1 change contract changed: $source"}

foreach($path in @($staging,$partial,$ready,$finalRoot,$finalZip,$gatePath)){Assert-True (-not(Test-Path -LiteralPath $path)) "O3J1 fresh build output already exists: $path"}
$planned=@($ready,(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'),(Join-Path $ready 'payload\Invoke-O3J1ResultJsonEndpoint.ps1'),(Join-Path $ready 'payload\OCV03_ResultJsonProviderV1.ps1'),(Join-Path $ready 'payload\O3J1_RESULT_JSON_PROVIDER_CONFIG.json'),(Join-Path $ready 'payload\O3J1_RESULT_JSON_INVOCATION.json'),$finalZip,$gatePath,(Join-Path $staging 'f\x\payload\Invoke-O3J1ResultJsonEndpoint.ps1'))
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathGate.state-eq'PASS_PATH_BUDGET') 'O3J1 build path gate failed.'
if($Preflight){[ordered]@{schema='argos_o3j1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_BUILD_PREFLIGHT';requestId=$requestId;entrypointSha256=$entrypointSha;providerSha256=$providerSha;configurationSha256=$configurationSha;collectionInvocationSha256=$collectionInvocationSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

$identityValue=Get-Content -LiteralPath $identity -Raw|ConvertFrom-Json
$thumbprint=([string]$identityValue.thumbprint).Replace(' ','').ToUpperInvariant()
$store=New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser);$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try{$matches=@($store.Certificates|Where-Object{([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant()-eq$thumbprint});Assert-True ($matches.Count-eq1) 'O3J1 signer certificate cardinality changed.';$signer=$matches[0]}finally{$store.Close();$store.Dispose()}
Assert-True $signer.HasPrivateKey 'O3J1 signer private key is absent.'
$files=@(
 [ordered]@{source=$entrypoint;path='payload/Invoke-O3J1ResultJsonEndpoint.ps1';sha256=$entrypointSha},
 [ordered]@{source=$provider;path='payload/OCV03_ResultJsonProviderV1.ps1';sha256=$providerSha},
 [ordered]@{source=$configuration;path='payload/O3J1_RESULT_JSON_PROVIDER_CONFIG.json';sha256=$configurationSha},
 [ordered]@{source=$collectionInvocation;path='payload/O3J1_RESULT_JSON_INVOCATION.json';sha256=$collectionInvocationSha}
)
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$def.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=(Get-Item -LiteralPath $_.source).Length;sha256=$_.sha256}});entryPoint=[string]$def.entryPoint;changes=@($def.changes);entryPointMutations=@();entryPointOutputs=@();jsonReadContract=$def.jsonReadContract;allowedTaskActions=@();allowedProcessActions=@();rehearsal=$def.rehearsal;requestRetryAuthorized=$false}
$payloadRoot=Join-Path (Join-Path $partial $requestDirName) 'payload';[void](New-Item -ItemType Directory -Path $payloadRoot)
foreach($file in $files){Copy-Item -LiteralPath $file.source -Destination (Join-Path (Join-Path $partial $requestDirName) $file.path.Replace('/','\'))}
$manifestPath=Join-Path (Join-Path $partial $requestDirName) 'PORTAL_REQUEST_MANIFEST.json';$signaturePath=Join-Path (Join-Path $partial $requestDirName) 'PORTAL_REQUEST_MANIFEST.sig'
$utf8=New-Object Text.UTF8Encoding($false);$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 32));[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer);try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()};[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $ready));Move-Item -LiteralPath (Join-Path $partial $requestDirName) -Destination $ready
$packageTest=& $packageTester -PackagePath $ready -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH;Assert-True ([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE') 'O3J1 signed request verification failed.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$finalPartialRoot=Join-Path $staging 'f';[void](New-Item -ItemType Directory -Path $finalPartialRoot);$partialZip=Join-Path $finalPartialRoot $zipName;[IO.Compression.ZipFile]::CreateFromDirectory($ready,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
$extract=Join-Path $finalPartialRoot 'x';[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extract)
$expected=@{'payload/Invoke-O3J1ResultJsonEndpoint.ps1'=$entrypointSha;'payload/OCV03_ResultJsonProviderV1.ps1'=$providerSha;'payload/O3J1_RESULT_JSON_PROVIDER_CONFIG.json'=$configurationSha;'payload/O3J1_RESULT_JSON_INVOCATION.json'=$collectionInvocationSha;'PORTAL_REQUEST_MANIFEST.json'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted=@(Get-ChildItem -LiteralPath $extract -Recurse -File);Assert-True ($extracted.Count-eq6) 'O3J1 final ZIP file count changed.'
foreach($item in $expected.GetEnumerator()){$leaf=Join-Path $extract $item.Key.Replace('/','\');Assert-True (Test-Path -LiteralPath $leaf -PathType Leaf) "O3J1 final ZIP leaf absent: $($item.Key)";Assert-True ((Get-Sha $leaf)-eq[string]$item.Value) "O3J1 final ZIP leaf changed: $($item.Key)"}
foreach($script in @((Join-Path $extract 'payload\Invoke-O3J1ResultJsonEndpoint.ps1'),(Join-Path $extract 'payload\OCV03_ResultJsonProviderV1.ps1'))){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($script,[ref]$tokens,[ref]$errors);Assert-True (@($errors).Count-eq0) "O3J1 extracted PowerShell parser failed: $script"}
$zipSha=Get-Sha $partialZip
$gate=[ordered]@{schema='argos_o3j1_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_EDGE_NOTCH_O3J1/final/'+$zipName;requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;entrypointSha256=$entrypointSha;providerSha256=$providerSha;configurationSha256=$configurationSha;collectionInvocationSha256=$collectionInvocationSha;providerGateSha256='5ED3A1568193C6D4AEBC1DBD03A158ED8EB2A8C88807F94D8B567061D71A02BA';entrypointGateSha256='649024CB557E690A87AD52666DA41A3AA7D98E96140EA0B8319EC0D9D2C5246F';recoveryIntentSha256='0147AC058D62580EEE50E95839D1C989FD854D54A11B5CFF0A3F6BFBF49D6A70';inheritedCompleteRouteGateSha256='41A4A1B808E40E7A14A8F22BA7BF9189C0B00B16639A43DDF5AB9A3FC70385D2';inheritedQueueGateSha256='170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D';exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassedForPayloadScripts=2;installedProviderExecutedInLocalRehearsal=$true;sourceJsonContentReadAuthorized=$true;sourceImageBytesRead=$false;sourceMutationPerformed=$false;inspectionTasksChanged=$false;healthyProcessorTouched=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;publicationAuthorized=$true;publicationRequiresCompleteRouteGate=$true}
[void](New-Item -ItemType Directory -Path $finalRoot);Move-Item -LiteralPath $partialZip -Destination $finalZip;Assert-True ((Get-Sha $finalZip)-eq$zipSha) 'O3J1 final ZIP move changed bytes.'
[IO.File]::WriteAllText((Join-Path $finalRoot ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
[IO.File]::WriteAllText($gatePath,(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
[IO.Directory]::Delete($staging,$true)
$gate|ConvertTo-Json -Depth 10
