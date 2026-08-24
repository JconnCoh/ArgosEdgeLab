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
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)-or(Get-Sha $Path)-ne$Sha){throw "OLS4 pinned dependency changed: $Path"}
    if(-not[string]::IsNullOrWhiteSpace($State)){$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;if([string]$value.state-ne$State){throw "OLS4 pinned gate state changed: $Path"}}
}

$project=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root=$PSScriptRoot
$requestId='REQ_OLS4'
$definitionPath=Join-Path $root 'MAINTENANCE_DEFINITION.json'
$entrypointPath=Join-Path $root 'Invoke-OCV00DeepestAliasEndpoint.ps1'
$providerPath=Join-Path $root 'Invoke-OCV00DeepestAliasInventory.ps1'
$signedRoot=Join-Path $root 'signed_ols4'
$partialSigned=Join-Path $root 'signed_ols4.partial'
$ready=Join-Path $signedRoot 'REQ_OLS4.ready'
$finalRoot=Join-Path $root 'final_ols4'
$partialFinal=Join-Path $root 'final_ols4.partial'
$zipName='REQ_OLS4.ready.zip'
$zipPath=Join-Path $finalRoot $zipName
$packageGatePath=Join-Path $root 'OLS4_FINAL_PACKAGE_GATE.json'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$entrypointSha='5C2496DA36EDEBF5FF156F93D626BB36B2414442D805274192F46FB549CD8361'
$providerSha='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
$definitionSha='9BF5336D11A16D2DF67DE8DAC39F38B438F645DD1441CA0DFDB5564EAD9171F0'
Assert-Pin $entrypointPath $entrypointSha
Assert-Pin $providerPath $providerSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'OLS4_DEEPEST_ALIAS_PROVIDER_GATE.json') '791829F3EFE668B10FD6DB6CD6847F375556790204C8A9D811224627AD309396' 'PASS_OCV00_DEEPEST_ALIAS_PROVIDER_LOCAL_GATE'
Assert-Pin (Join-Path $root 'OLS4_ENTRYPOINT_GATE.json') 'A25537A5225F75D7813188328FA040844B75974CF72AF7E7A999444522A38D3F' 'PASS_OLS4_ENTRYPOINT_GATE'
Assert-Pin (Join-Path $root 'OLS4_LIVE_RECOVERY_INTENT_R3.json') 'EE16211508D933610A8E2F60DAEFC80B616709A3BC41A359E880FA5F35BF4E6B'
Assert-Pin (Join-Path $project 'work\OPENCV_OLS3\OLS3_COMPLETE_ROUTE_GATE.json') '932C792DA3095FA43FF1749775D7F4BD3473FA6043ABE86C449FBA16A3914F3A' 'PASS_OLS3_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
if([string]$definition.targetRole-ne'JBOD'-or[string]$definition.jobClass-ne'MAINTENANCE_PATCH'-or[string]$definition.entryPoint-ne'payload/Invoke-OCV00DeepestAliasEndpoint.ps1'-or@($definition.changes).Count-ne1-or@($definition.entryPointMutations).Count-ne0-or@($definition.entryPointOutputs).Count-ne1-or@($definition.allowedTaskActions).Count-ne0-or@($definition.allowedProcessActions).Count-ne0-or-not[bool]$definition.reviewOnly-or[bool]$definition.productionRoutingEnabled){throw 'OLS4 maintenance definition contract changed.'}
if([string]$definition.changes[0].installedSha256-ne$entrypointSha-or-not[bool]$definition.changes[0].allowCreate-or[string]$definition.metadataReadContract.aliasAnchor-ne'EXACT_REQUESTED_SUBTREE_ROOT'-or-not[bool]$definition.metadataReadContract.canonicalPathsAreProvenanceOnly-or-not[bool]$definition.metadataReadContract.exactSkipIdentityRequired-or-not[bool]$definition.metadataReadContract.completeRequiresZeroSkipRows-or[bool]$definition.metadataReadContract.fileContentReadAllowed-or[bool]$definition.metadataReadContract.imageBytesReadAllowed-or[bool]$definition.metadataReadContract.sourceHashingAllowed){throw 'OLS4 metadata-read contract changed.'}

foreach($path in @($signedRoot,$partialSigned,$finalRoot,$partialFinal,$packageGatePath)){if(Test-Path -LiteralPath $path){throw "OLS4 fresh output already exists: $path"}}
$planned=@($ready,(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'),(Join-Path $ready 'payload\Invoke-OCV00DeepestAliasEndpoint.ps1'),(Join-Path $ready 'payload\Invoke-OCV00DeepestAliasInventory.ps1'),$zipPath,(Join-Path $partialFinal 'extract\payload\Invoke-OCV00DeepestAliasEndpoint.ps1'),(Join-Path $partialFinal 'extract\payload\Invoke-OCV00DeepestAliasInventory.ps1'),$packageGatePath)
$pathGate=& $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'OLS4 package path gate failed.'}

if($Preflight){
    [ordered]@{schema='argos_ols4_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS4_BUILD_PREFLIGHT';requestId=$requestId;entrypointSha256=$entrypointSha;providerSha256=$providerSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$certificate=Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if(-not$certificate.HasPrivateKey){throw 'OLS4 signer private key is unavailable.'}
$files=@(
    [ordered]@{source=$entrypointPath;path='payload/Invoke-OCV00DeepestAliasEndpoint.ps1';bytes=(Get-Item -LiteralPath $entrypointPath).Length;sha256=$entrypointSha},
    [ordered]@{source=$providerPath;path='payload/Invoke-OCV00DeepestAliasInventory.ps1';bytes=(Get-Item -LiteralPath $providerPath).Length;sha256=$providerSha}
)
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@();entryPointOutputs=@($definition.entryPointOutputs);metadataReadContract=$definition.metadataReadContract;allowedTaskActions=@();allowedProcessActions=@();rehearsal=$definition.rehearsal
}
[void](New-Item -ItemType Directory -Path (Join-Path $partialSigned 'REQ_OLS4.ready\payload'))
foreach($file in $files){Copy-Item -LiteralPath $file.source -Destination (Join-Path (Join-Path $partialSigned 'REQ_OLS4.ready') $file.path.Replace('/','\'))}
$manifestPath=Join-Path $partialSigned 'REQ_OLS4.ready\PORTAL_REQUEST_MANIFEST.json'
$signaturePath=Join-Path $partialSigned 'REQ_OLS4.ready\PORTAL_REQUEST_MANIFEST.sig'
$utf8=New-Object Text.UTF8Encoding($false)
$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath (Join-Path $partialSigned 'REQ_OLS4.ready') -Destination $ready
Remove-Item -LiteralPath $partialSigned -Force
$packageTest=& $packageTester -PackagePath $ready -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip=Join-Path $partialFinal $zipName
$extract=Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($ready,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extract)
$expected=@{'payload/Invoke-OCV00DeepestAliasEndpoint.ps1'=$entrypointSha;'payload/Invoke-OCV00DeepestAliasInventory.ps1'=$providerSha;'PORTAL_REQUEST_MANIFEST.json'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted=@(Get-ChildItem -LiteralPath $extract -Recurse -File)
if($extracted.Count-ne4){throw 'OLS4 final ZIP file count changed.'}
foreach($item in $expected.GetEnumerator()){$path=Join-Path $extract $item.Key.Replace('/','\');if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Get-Sha $path)-ne[string]$item.Value){throw "OLS4 final ZIP file changed: $($item.Key)"}}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract 'payload\Invoke-OCV00DeepestAliasEndpoint.ps1'),[ref]$tokens,[ref]$errors);if(@($errors).Count-ne0){throw 'OLS4 extracted entrypoint parser failed.'}
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract 'payload\Invoke-OCV00DeepestAliasInventory.ps1'),[ref]$tokens,[ref]$errors);if(@($errors).Count-ne0){throw 'OLS4 extracted provider parser failed.'}
$zipSha=Get-Sha $partialZip
$gate=[ordered]@{schema='argos_ols4_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS4_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_OLS4/final_ols4/REQ_OLS4.ready.zip';requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;entrypointSha256=$entrypointSha;providerSha256=$providerSha;providerGateSha256='791829F3EFE668B10FD6DB6CD6847F375556790204C8A9D811224627AD309396';entrypointGateSha256='A25537A5225F75D7813188328FA040844B75974CF72AF7E7A999444522A38D3F';inheritedCompleteRouteGateSha256='932C792DA3095FA43FF1749775D7F4BD3473FA6043ABE86C449FBA16A3914F3A';inheritedQueueGateSha256='170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D';exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassedForPayloadScripts=2;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;currentWaferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false;publicationAuthorized=$false;publicationRequiresCompleteRouteGate=$true}
[IO.File]::WriteAllText((Join-Path $partialFinal ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
[IO.File]::WriteAllText($packageGatePath,(($gate|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)
$gate|ConvertTo-Json -Depth 10
