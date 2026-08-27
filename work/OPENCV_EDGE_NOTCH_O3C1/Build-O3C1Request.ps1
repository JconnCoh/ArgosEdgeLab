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
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)-or(Get-Sha $Path)-ne$Sha){throw "O3C1 pinned dependency changed: $Path"}
    if(-not[string]::IsNullOrWhiteSpace($State)){$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;if([string]$value.state-ne$State){throw "O3C1 pinned gate state changed: $Path"}}
}

$project=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root=$PSScriptRoot
$requestId='REQ_20260827T141000111Z_62629419C3A1'
$definitionPath=Join-Path $root 'MAINTENANCE_DEFINITION.json'
$entrypointPath=Join-Path $root 'Invoke-OCV03HotspotMetadataEndpoint.ps1'
$providerPath=Join-Path $project 'work\OPENCV_OLS4\Invoke-OCV00DeepestAliasInventory.ps1'
$stagingRoot='C:\A31'
$signedRoot=Join-Path $stagingRoot 's'
$partialSigned=Join-Path $stagingRoot 'sp'
$ready=Join-Path $signedRoot 'REQ_20260827T141000111Z_62629419C3A1.ready'
$finalRoot=Join-Path $root 'final_o3c1'
$partialFinal=Join-Path $stagingRoot 'f'
$zipName='REQ_20260827T141000111Z_62629419C3A1.ready.zip'
$zipPath=Join-Path $finalRoot $zipName
$packageGatePath=Join-Path $root 'O3C1_FINAL_PACKAGE_GATE.json'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$entrypointSha='B4C9FE769E6560815520B1922AEF5E446DA17EBD9C214A84FCB86BE7181BF06F'
$providerSha='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
$definitionSha='A886E948BC67922C1ACACBDAB94F5ED2984932E125ECE2B7940E5E3BF4AB2D3B'
Assert-Pin $entrypointPath $entrypointSha
Assert-Pin $providerPath $providerSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $project 'work\OPENCV_OLS4\OLS4_DEEPEST_ALIAS_PROVIDER_GATE.json') '791829F3EFE668B10FD6DB6CD6847F375556790204C8A9D811224627AD309396' 'PASS_OCV00_DEEPEST_ALIAS_PROVIDER_LOCAL_GATE'
Assert-Pin (Join-Path $root 'O3C1_ENTRYPOINT_GATE.json') '511AA11B16A00B8A413BD5C6287BB86F5E05F7879D862C6C46CFD3204E80145D' 'PASS_O3C1_ENTRYPOINT_GATE'
Assert-Pin (Join-Path $root 'O3C1_RECOVERY_INTENT.json') '4D1EA72FE27BAA0FCD246306CD3CEC7279210C467AB841325FE67A6640C70749'
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_O2D23\O2D23_COMPLETE_ROUTE_GATE_R3.json') '04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3' 'PASS_O2D23_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
if([string]$definition.targetRole-ne'JBOD'-or[string]$definition.jobClass-ne'MAINTENANCE_PATCH'-or[string]$definition.entryPoint-ne'payload/Invoke-OCV03HotspotMetadataEndpoint.ps1'-or@($definition.changes).Count-ne1-or@($definition.entryPointMutations).Count-ne0-or@($definition.entryPointOutputs).Count-ne1-or@($definition.allowedTaskActions).Count-ne0-or@($definition.allowedProcessActions).Count-ne0-or-not[bool]$definition.reviewOnly-or[bool]$definition.productionRoutingEnabled){throw 'O3C1 maintenance definition contract changed.'}
if([string]$definition.changes[0].source-ne'payload/OCV03_MetadataProviderV1.ps1'-or[string]$definition.changes[0].destination-ne'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_MetadataProviderV1.ps1'-or[string]$definition.changes[0].installedSha256-ne$providerSha-or@($definition.changes[0].approvedPredecessorSha256).Count-ne1-or@($definition.changes[0].approvedPredecessorSha256)-notcontains$providerSha-or-not[bool]$definition.changes[0].allowCreate-or[string]$definition.metadataReadContract.aliasAnchor-ne'EXACT_REQUESTED_SUBTREE_ROOT'-or[string]$definition.metadataReadContract.relativeRoot-ne'PatternedFront/Lot_62629-419_NotchBad_Hotspot'-or-not[bool]$definition.metadataReadContract.canonicalPathsAreProvenanceOnly-or-not[bool]$definition.metadataReadContract.exactSkipIdentityRequired-or-not[bool]$definition.metadataReadContract.completeRequiresZeroSkipRows-or[bool]$definition.metadataReadContract.fileContentReadAllowed-or[bool]$definition.metadataReadContract.imageBytesReadAllowed-or[bool]$definition.metadataReadContract.sourceHashingAllowed){throw 'O3C1 metadata-read contract changed.'}

foreach($path in @($stagingRoot,$signedRoot,$partialSigned,$finalRoot,$partialFinal,$packageGatePath)){if(Test-Path -LiteralPath $path){throw "O3C1 fresh output already exists: $path"}}
$planned=@($ready,(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'),(Join-Path $ready 'payload\Invoke-OCV03HotspotMetadataEndpoint.ps1'),(Join-Path $ready 'payload\OCV03_MetadataProviderV1.ps1'),$zipPath,(Join-Path $partialFinal 'extract\payload\Invoke-OCV03HotspotMetadataEndpoint.ps1'),(Join-Path $partialFinal 'extract\payload\OCV03_MetadataProviderV1.ps1'),$packageGatePath)
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'O3C1 package path gate failed.'}

if($Preflight){
    [ordered]@{schema='argos_o3c1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_BUILD_PREFLIGHT';requestId=$requestId;entrypointSha256=$entrypointSha;providerSha256=$providerSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store=New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try{$certificateMatches=@($store.Certificates|Where-Object{([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant()-eq$thumbprint});if($certificateMatches.Count-ne1){throw 'O3C1 signer certificate cardinality changed.'};$certificate=$certificateMatches[0]}
finally{$store.Close();$store.Dispose()}
if(-not$certificate.HasPrivateKey){throw 'O3C1 signer private key is unavailable.'}
$files=@(
    [ordered]@{source=$entrypointPath;path='payload/Invoke-OCV03HotspotMetadataEndpoint.ps1';bytes=(Get-Item -LiteralPath $entrypointPath).Length;sha256=$entrypointSha},
    [ordered]@{source=$providerPath;path='payload/OCV03_MetadataProviderV1.ps1';bytes=(Get-Item -LiteralPath $providerPath).Length;sha256=$providerSha}
)
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@();entryPointOutputs=@($definition.entryPointOutputs);metadataReadContract=$definition.metadataReadContract;allowedTaskActions=@();allowedProcessActions=@();rehearsal=$definition.rehearsal
}
[void](New-Item -ItemType Directory -Path (Join-Path $partialSigned 'REQ_20260827T141000111Z_62629419C3A1.ready\payload'))
foreach($file in $files){Copy-Item -LiteralPath $file.source -Destination (Join-Path (Join-Path $partialSigned 'REQ_20260827T141000111Z_62629419C3A1.ready') $file.path.Replace('/','\'))}
$manifestPath=Join-Path $partialSigned 'REQ_20260827T141000111Z_62629419C3A1.ready\PORTAL_REQUEST_MANIFEST.json'
$signaturePath=Join-Path $partialSigned 'REQ_20260827T141000111Z_62629419C3A1.ready\PORTAL_REQUEST_MANIFEST.sig'
$utf8=New-Object Text.UTF8Encoding($false)
$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath (Join-Path $partialSigned 'REQ_20260827T141000111Z_62629419C3A1.ready') -Destination $ready
Remove-Item -LiteralPath $partialSigned -Force
$packageTest=& $packageTester -PackagePath $ready -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if([string]$packageTest.State-ne'PASS_SIGNED_PORTAL_PACKAGE'){throw 'O3C1 signed package verification failed.'}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip=Join-Path $partialFinal $zipName
$extract=Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($ready,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extract)
$expected=@{'payload/Invoke-OCV03HotspotMetadataEndpoint.ps1'=$entrypointSha;'payload/OCV03_MetadataProviderV1.ps1'=$providerSha;'PORTAL_REQUEST_MANIFEST.json'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted=@(Get-ChildItem -LiteralPath $extract -Recurse -File)
if($extracted.Count-ne4){throw 'O3C1 final ZIP file count changed.'}
foreach($item in $expected.GetEnumerator()){$path=Join-Path $extract $item.Key.Replace('/','\');if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Sha $path)-ne[string]$item.Value){throw "O3C1 final ZIP file changed: $($item.Key)"}}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract 'payload\Invoke-OCV03HotspotMetadataEndpoint.ps1'),[ref]$tokens,[ref]$errors);if(@($errors).Count-ne0){throw 'O3C1 extracted entrypoint parser failed.'}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract 'payload\OCV03_MetadataProviderV1.ps1'),[ref]$tokens,[ref]$errors);if(@($errors).Count-ne0){throw 'O3C1 extracted provider parser failed.'}
$zipSha=Get-Sha $partialZip
$gate=[ordered]@{schema='argos_o3c1_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_EDGE_NOTCH_O3C1/final_o3c1/REQ_20260827T141000111Z_62629419C3A1.ready.zip';requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;entrypointSha256=$entrypointSha;providerSha256=$providerSha;providerInstalledDestination='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_MetadataProviderV1.ps1';maintenanceInstalledShaMatchesPayload=$true;providerGateSha256='791829F3EFE668B10FD6DB6CD6847F375556790204C8A9D811224627AD309396';entrypointGateSha256='511AA11B16A00B8A413BD5C6287BB86F5E05F7879D862C6C46CFD3204E80145D';recoveryIntentSha256='4D1EA72FE27BAA0FCD246306CD3CEC7279210C467AB841325FE67A6640C70749';inheritedCompleteRouteGateSha256='04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3';inheritedQueueGateSha256='170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D';exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassedForPayloadScripts=2;installedProviderExecutedInLocalRehearsal=$true;shortLocalStagingRoot=$stagingRoot;sourceImageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;processorTaskChanged=$false;currentWaferAborted=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;publicationAuthorized=$false;publicationRequiresCompleteRouteGate=$true}
[void](New-Item -ItemType Directory -Path $finalRoot)
Move-Item -LiteralPath $partialZip -Destination $zipPath
if((Get-Sha $zipPath)-ne$zipSha){throw 'O3C1 final ZIP move changed bytes.'}
[IO.File]::WriteAllText((Join-Path $finalRoot ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
[IO.Directory]::Delete($stagingRoot,$true)
[IO.File]::WriteAllText($packageGatePath,(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
$gate|ConvertTo-Json -Depth 10
