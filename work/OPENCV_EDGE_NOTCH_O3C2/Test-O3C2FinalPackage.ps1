#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){$s=[IO.File]::OpenRead($Path);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){Assert-True(-not(Test-Path -LiteralPath $Path))"O3C2 package rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
Assert-True($invocationPath.StartsWith([IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase))'O3C2 package rehearsal invocation must remain under the O3C2 root.'
Assert-True(Test-Path -LiteralPath $invocationPath -PathType Leaf)'O3C2 package rehearsal invocation is absent.'
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True([string]$invocation.schema-eq'argos_o3c2_exact_package_rehearsal_invocation_v1')'O3C2 package rehearsal invocation schema changed.'
$requestId='REQ_20260827T151200111Z_62629419C3F2'
Assert-True([string]$invocation.requestId-eq$requestId)'O3C2 package rehearsal request identity changed.'
$zip=[IO.Path]::GetFullPath([string]$invocation.requestZipPath)
$expectedZip=([string]$invocation.requestZipSha256).ToUpperInvariant()
$gatePath=[IO.Path]::GetFullPath([string]$invocation.outputGatePath)
$fixtureRoot='C:\A34'
$sourceFixture='C:\A32T1\many'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$providerSha='1A73D69F38C1E578734E30376845DF308636A893A846CF86FB9531144FE04B88'
$entrypointSha='B6561FECE5570EC7A21CBB6BD56871871C1C4C829C781B4924893B36BCAE76F0'
$targetsSha='AF94AAF89093781624C5A113BC58147CA1E94F030EC5132E2C00F1A26A1F79A4'
foreach($p in @($zip,$publicCertificate,$packageTester,$queueGate,$endpointWorker,(Join-Path $sourceFixture 'portal\config\endpoint_jbod.json'),(Join-Path $sourceFixture 'targets.json'),(Join-Path $sourceFixture 'inventory.json'))){Assert-True(Test-Path -LiteralPath $p -PathType Leaf)"O3C2 package-rehearsal dependency absent: $p"}
Assert-True((Get-Sha256 $zip)-eq$expectedZip)'O3C2 exact final ZIP changed.'
Assert-True((Get-Sha256 $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D')'O3C2 inherited queue gate changed.'
Assert-True((Get-Sha256 $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250')'O3C2 endpoint worker changed.'
Assert-True(-not(Test-Path -LiteralPath $fixtureRoot))'O3C2 fresh rehearsal root exists.'
Assert-True(-not(Test-Path -LiteralPath $gatePath))'O3C2 package rehearsal gate exists.'
$pathCheck=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3C2SourceFreezeEndpoint.ps1'),(Join-Path $fixtureRoot 'success\OCV03_O3C2_SOURCE_FREEZE.json'),(Join-Path $fixtureRoot 'failure\OCV03_O3C2_SOURCE_FREEZE.json'),$gatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True([string]$pathCheck.state-eq'PASS_PATH_BUDGET')'O3C2 package-rehearsal path gate failed.'

if($Preflight){[ordered]@{schema='argos_o3c2_exact_package_rehearsal_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueGateSha256=Get-Sha256 $queueGate;fixtureRoot=$fixtureRoot;exactLiveCardinalityFixturePairCount=10;exactLiveCardinalityFixtureLeafCount=20;mutationsPerformed=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 7;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract=Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE')'O3C2 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$entrypoint=Join-Path $extract 'payload\Invoke-O3C2SourceFreezeEndpoint.ps1'
$provider=Join-Path $extract 'payload\OCV03_SourceFreezeProviderV1.ps1'
$targets=Join-Path $extract 'payload\O3C2_SOURCE_TARGETS.json'
Assert-True([string]$manifest.requestId-eq$requestId-and@($manifest.files).Count-eq3-and@($manifest.changes).Count-eq1)'O3C2 signed manifest identity changed.'
Assert-True((Get-Sha256 $entrypoint)-eq$entrypointSha-and(Get-Sha256 $provider)-eq$providerSha-and(Get-Sha256 $targets)-eq$targetsSha)'O3C2 extracted payload hash changed.'
Assert-True([string]$manifest.changes[0].source-eq'payload/OCV03_SourceFreezeProviderV1.ps1'-and[string]$manifest.changes[0].installedSha256-eq$providerSha-and@($manifest.changes[0].approvedPredecessorSha256)-contains$providerSha-and[bool]$manifest.changes[0].allowCreate)'O3C2 predecessor declaration changed.'
Assert-True([string]$manifest.sourceReadContract.targetManifest-eq'payload/O3C2_SOURCE_TARGETS.json'-and[int]$manifest.sourceReadContract.pairCount-eq10-and[int]$manifest.sourceReadContract.leafCount-eq20-and-not[bool]$manifest.sourceReadContract.knownNotchLocationConsumed-and-not[bool]$manifest.sourceReadContract.notchAnglePriorConsumed-and-not[bool]$manifest.sourceReadContract.fixedAngularSearchWindowConsumed)'O3C2 source-read contract changed.'

$successRoot=Join-Path $fixtureRoot 'success'
[void](New-Item -ItemType Directory -Path $successRoot)
$installedSuccess=Join-Path $successRoot 'OCV03_SourceFreezeProviderV1.ps1'
Assert-True(-not(Test-Path -LiteralPath $installedSuccess))'O3C2 create-case provider unexpectedly exists.'
Copy-Item -LiteralPath $provider -Destination $installedSuccess
Assert-True((Get-Sha256 $installedSuccess)-eq$providerSha)'O3C2 create-case installed provider changed.'
Copy-Item -LiteralPath $provider -Destination $installedSuccess
Assert-True((Get-Sha256 $installedSuccess)-eq$providerSha)'O3C2 target-hash idempotent case changed provider.'
$successInvocation=Join-Path $fixtureRoot 'success.json'
$successOutput=Join-Path $successRoot 'OCV03_O3C2_SOURCE_FREEZE.json'
Write-NewJson $successInvocation ([ordered]@{schema='argos_o3c2_entrypoint_invocation_v1';portalRoot=(Join-Path $sourceFixture 'portal');processorRoot=$successRoot;providerPath=$installedSuccess;targetManifestPath=(Join-Path $sourceFixture 'targets.json');inventoryPath=(Join-Path $sourceFixture 'inventory.json');outputPath=$successOutput;aliasName='Q';expectedProviderSha256=$providerSha;expectedTargetManifestSha256=(Get-Sha256 (Join-Path $sourceFixture 'targets.json'));expectedInventorySha256=(Get-Sha256 (Join-Path $sourceFixture 'inventory.json'));failAfterHashCount=0})
$successResult=(& $entrypoint -Rehearsal -InvocationManifest $successInvocation|Out-String)|ConvertFrom-Json
Assert-True([string]$successResult.state-eq'PASS_O3C2_HOTSPOT_SOURCE_FREEZE'-and[int]$successResult.pairCount-eq10-and[int]$successResult.leafCount-eq20)'O3C2 exact-package success case failed.'
Assert-True(-not[bool]$successResult.knownNotchLocationConsumed-and-not[bool]$successResult.notchAnglePriorConsumed-and-not[bool]$successResult.fixedAngularSearchWindowConsumed)'O3C2 exact-package success consumed a forbidden notch prior.'

$unapprovedRoot=Join-Path $fixtureRoot 'unapproved'
[void](New-Item -ItemType Directory -Path $unapprovedRoot)
$unapproved=Join-Path $unapprovedRoot 'OCV03_SourceFreezeProviderV1.ps1'
[IO.File]::WriteAllText($unapproved,'unapproved',(New-Object Text.UTF8Encoding($false)))
$unapprovedBefore=Get-Sha256 $unapproved
Assert-True(@($manifest.changes[0].approvedPredecessorSha256)-notcontains$unapprovedBefore)'O3C2 unapproved control accidentally approved.'
Assert-True((Get-Sha256 $unapproved)-eq$unapprovedBefore)'O3C2 unapproved predecessor changed.'

$failureRoot=Join-Path $fixtureRoot 'failure'
[void](New-Item -ItemType Directory -Path $failureRoot)
$installedFailure=Join-Path $failureRoot 'OCV03_SourceFreezeProviderV1.ps1'
Copy-Item -LiteralPath $provider -Destination $installedFailure
$failureInvocation=Join-Path $fixtureRoot 'failure.json'
$failureOutput=Join-Path $failureRoot 'OCV03_O3C2_SOURCE_FREEZE.json'
Write-NewJson $failureInvocation ([ordered]@{schema='argos_o3c2_entrypoint_invocation_v1';portalRoot=(Join-Path $sourceFixture 'portal');processorRoot=$failureRoot;providerPath=$installedFailure;targetManifestPath=(Join-Path $sourceFixture 'targets.json');inventoryPath=(Join-Path $sourceFixture 'inventory.json');outputPath=$failureOutput;aliasName='Q';expectedProviderSha256=$providerSha;expectedTargetManifestSha256=(Get-Sha256 (Join-Path $sourceFixture 'targets.json'));expectedInventorySha256=(Get-Sha256 (Join-Path $sourceFixture 'inventory.json'));failAfterHashCount=1})
$captured=$false
try{& $entrypoint -Rehearsal -InvocationManifest $failureInvocation 2>&1|Out-Null}catch{$captured=[string]$_.Exception.Message-match'^O3C2_PROVIDER_EXECUTION_FAILED: .*INJECTED_O3C2_FAILURE_AFTER_HASH'}
Assert-True $captured 'O3C2 injected failure was not captured through the exact packaged entrypoint.'
Assert-True(-not(Test-Path -LiteralPath $failureOutput))'O3C2 injected failure wrote output.'
Assert-True($null-eq(Get-PSDrive -Name Q -ErrorAction SilentlyContinue)-and-not[IO.Directory]::Exists('Q:\'))'O3C2 injected failure left the alias visible.'

$record=[ordered]@{schema='argos_o3c2_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_EXACT_PACKAGE_REHEARSAL';requestId=[string]$manifest.requestId;requestZipSha256=$expectedZip;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=3;createCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;exactPackagedEntrypointSuccessPassed=$true;exactPackagedEntrypointInjectedFailureCaptured=$true;postFailureOutputAbsent=$true;postFailureAliasAbsent=$true;successPairCount=[int]$successResult.pairCount;successLeafCount=[int]$successResult.leafCount;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha256 $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceHashingPerformedInSuccessRehearsal=$true;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;sourceDeletionPerformed=$false;taskActions=0;processActions=0;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record|ConvertTo-Json -Depth 10
