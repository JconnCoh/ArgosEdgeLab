#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){$s=[IO.File]::OpenRead($Path);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){Assert-True(-not(Test-Path -LiteralPath $Path))"O3C1 rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$zip=Join-Path $PSScriptRoot 'final_o3c1\REQ_20260827T141000111Z_62629419C3A1.ready.zip'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$portalFixture=Join-Path $project 'work\OPENCV_OLS4\fixture_portal'
$fixtureRoot='C:\O3P'
$gatePath=Join-Path $PSScriptRoot 'O3C1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$expectedZip='2D191B3FBC9C40D447F3D7EAE0C998946085BE1916275999F32EB92E963F9293'
$providerSha='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
$entrypointSha='B4C9FE769E6560815520B1922AEF5E446DA17EBD9C214A84FCB86BE7181BF06F'
foreach($p in @($zip,$publicCertificate,$packageTester,$queueGate,$endpointWorker,(Join-Path $portalFixture 'config\endpoint_jbod.json'))){Assert-True(Test-Path -LiteralPath $p -PathType Leaf)"O3C1 package-rehearsal dependency absent: $p"}
Assert-True((Get-Sha256 $zip)-eq$expectedZip)'O3C1 exact final ZIP changed.'
Assert-True((Get-Sha256 $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D')'O3C1 inherited queue gate changed.'
Assert-True((Get-Sha256 $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250')'O3C1 endpoint worker changed.'
Assert-True(-not(Test-Path -LiteralPath $fixtureRoot))'O3C1 fresh rehearsal root exists.'
Assert-True(-not(Test-Path -LiteralPath $gatePath))'O3C1 rehearsal gate exists.'
$pathCheck=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-OCV03HotspotMetadataEndpoint.ps1'),(Join-Path $fixtureRoot 'create\OCV03_O3C1_HOTSPOT_INVENTORY.json'),$gatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True([string]$pathCheck.state-eq'PASS_PATH_BUDGET')'O3C1 package-rehearsal path gate failed.'

if($Preflight){[ordered]@{schema='argos_o3c1_exact_package_rehearsal_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestZipSha256=$expectedZip;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueGateSha256=Get-Sha256 $queueGate;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;sourceHashingPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract=Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE')'O3C1 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$entrypoint=Join-Path $extract 'payload\Invoke-OCV03HotspotMetadataEndpoint.ps1'
$provider=Join-Path $extract 'payload\OCV03_MetadataProviderV1.ps1'
Assert-True([string]$manifest.requestId-eq'REQ_20260827T141000111Z_62629419C3A1'-and@($manifest.files).Count-eq2-and@($manifest.changes).Count-eq1)'O3C1 signed manifest identity changed.'
Assert-True((Get-Sha256 $entrypoint)-eq$entrypointSha-and(Get-Sha256 $provider)-eq$providerSha)'O3C1 extracted payload hash changed.'
Assert-True([string]$manifest.changes[0].source-eq'payload/OCV03_MetadataProviderV1.ps1'-and[string]$manifest.changes[0].installedSha256-eq$providerSha-and@($manifest.changes[0].approvedPredecessorSha256)-contains$providerSha-and[bool]$manifest.changes[0].allowCreate)'O3C1 predecessor declaration changed.'

function Invoke-Case([string]$Name,[bool]$FailAfterProvider){
    $processor=Join-Path $fixtureRoot $Name
    [void](New-Item -ItemType Directory -Path $processor)
    $installed=Join-Path $processor 'OCV03_MetadataProviderV1.ps1'
    Copy-Item -LiteralPath $provider -Destination $installed
    Assert-True((Get-Sha256 $installed)-eq$providerSha)"O3C1 $Name installed provider changed."
    $invocationPath=Join-Path $fixtureRoot ($Name+'.json')
    Write-NewJson $invocationPath ([ordered]@{schema='argos_o3c1_entrypoint_invocation_v1';portalRoot=$portalFixture;processorRoot=$processor;relativeSubtree='lot';approvedDataRootName='JBOD_KLARF_EXPORT';aliasName='F';maximumDepth=8;maximumEntries=20000;maximumDirectories=2048;maximumBmpLeaves=2048;failAfterProvider=$FailAfterProvider})
    if($FailAfterProvider){$captured=$false;try{& $entrypoint -Rehearsal -InvocationManifest $invocationPath 2>&1|Out-Null}catch{$captured=[string]$_.Exception.Message-match'INJECTED_O3C1_ENTRYPOINT_FAILURE_AFTER_PROVIDER'};Assert-True $captured 'O3C1 injected rollback case did not fail as planned.';Assert-True(-not(Test-Path -LiteralPath (Join-Path $processor 'OCV03_O3C1_HOTSPOT_INVENTORY.json')))'O3C1 injected failure wrote output.';return}
    $result=(& $entrypoint -Rehearsal -InvocationManifest $invocationPath|Out-String)|ConvertFrom-Json
    Assert-True([string]$result.state-eq'PASS_OCV03_METADATA_CAPABILITY_O3C1'-and[string]$result.inventoryDisposition-eq'COMPLETE'-and[bool]$result.installedProviderExecuted)"O3C1 $Name case failed."
}
Invoke-Case 'create' $false
Invoke-Case 'target' $false
$unapproved=Join-Path $fixtureRoot 'unapproved\OCV03_MetadataProviderV1.ps1'
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $unapproved))
[IO.File]::WriteAllText($unapproved,'unapproved',(New-Object Text.UTF8Encoding($false)))
$unapprovedBefore=Get-Sha256 $unapproved
Assert-True(@($manifest.changes[0].approvedPredecessorSha256)-notcontains$unapprovedBefore)'O3C1 unapproved control accidentally approved.'
Assert-True((Get-Sha256 $unapproved)-eq$unapprovedBefore)'O3C1 unapproved predecessor changed.'
Invoke-Case 'rollback' $true

$record=[ordered]@{schema='argos_o3c1_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_EXACT_PACKAGE_REHEARSAL';requestId=[string]$manifest.requestId;requestZipSha256=$expectedZip;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=2;createCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;postProviderFailureCaptured=$true;postProviderFailureOutputAbsent=$true;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha256 $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;taskActions=0;processActions=0;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record|ConvertTo-Json -Depth 8
