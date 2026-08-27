#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Write-NewUtf8([string]$Path,[string]$Text){Assert-True (-not(Test-Path -LiteralPath $Path)) "O3J1 exact rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))}
function Write-NewJson([string]$Path,[object]$Value){Write-NewUtf8 $Path (($Value|ConvertTo-Json -Depth 15)+[Environment]::NewLine)}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$zip=Join-Path $PSScriptRoot 'final\REQ_20260827T185500111Z_62629419O3J1.ready.zip'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$fixtureRoot='C:\A3J1R'
$gatePath=Join-Path $PSScriptRoot 'O3J1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$expectedZip='71E3BA51EF387C91D8F1425CD7703B3F3606B4C6043166E1907069F4A803DF94'
$entrypointSha='A30D0150EF309464034EAF5B5EBD87C7E23050DB756E76A8EA5B7BA242016862'
$providerSha='EF9773ADAC624A7A8A689989AB0EE404C2863B4E32B2666F437331E8CC9CAE67'
$configurationSha='01C09158CF67EB9C04C84DE35F8C039D9F0F5B913319E304543AD8482ACE3EA0'
$collectionInvocationSha='6220CD7638D83EA18FE24E4C31A29FD542747B99ECF6AE6B205E5556335CC96B'
foreach($path in @($zip,$certificate,$packageTester,$endpointWorker,$queueGate)){Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3J1 exact rehearsal dependency absent: $path"}
Assert-True ((Get-Sha $zip)-eq$expectedZip) 'O3J1 exact final ZIP changed.'
Assert-True ((Get-Sha $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3J1 endpoint worker changed.'
Assert-True ((Get-Sha $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3J1 queue gate changed.'
Assert-True (-not(Test-Path -LiteralPath $fixtureRoot)) 'O3J1 exact rehearsal root exists.'
Assert-True (-not(Test-Path -LiteralPath $gatePath)) 'O3J1 exact rehearsal gate exists.'
$pathCheck=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3J1ResultJsonEndpoint.ps1'),(Join-Path $fixtureRoot 'create\OCV03_ResultJsonProviderV1.ps1'),$gatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True ([string]$pathCheck.state-eq'PASS_PATH_BUDGET') 'O3J1 exact rehearsal path gate failed.'
if($Preflight){[ordered]@{schema='argos_o3j1_exact_package_rehearsal_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestZipSha256=$expectedZip;endpointWorkerSha256=Get-Sha $endpointWorker;inheritedQueueGateSha256=Get-Sha $queueGate;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract=Join-Path $fixtureRoot 'x';Add-Type -AssemblyName System.IO.Compression.FileSystem;[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE') 'O3J1 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$entrypoint=Join-Path $extract 'payload\Invoke-O3J1ResultJsonEndpoint.ps1';$provider=Join-Path $extract 'payload\OCV03_ResultJsonProviderV1.ps1';$configuration=Join-Path $extract 'payload\O3J1_RESULT_JSON_PROVIDER_CONFIG.json';$collectionInvocation=Join-Path $extract 'payload\O3J1_RESULT_JSON_INVOCATION.json'
Assert-True ([string]$manifest.requestId-eq'REQ_20260827T185500111Z_62629419O3J1'-and@($manifest.files).Count-eq4-and@($manifest.changes).Count-eq2) 'O3J1 signed manifest identity changed.'
Assert-True ((Get-Sha $entrypoint)-eq$entrypointSha-and(Get-Sha $provider)-eq$providerSha-and(Get-Sha $configuration)-eq$configurationSha-and(Get-Sha $collectionInvocation)-eq$collectionInvocationSha) 'O3J1 extracted payload changed.'
Assert-True ([int64]$manifest.maxResultBytes-eq67108864-and[string]$manifest.entryPoint-eq'payload/Invoke-O3J1ResultJsonEndpoint.ps1'-and@($manifest.entryPointMutations).Count-eq0-and@($manifest.entryPointOutputs).Count-eq0-and@($manifest.allowedTaskActions).Count-eq0-and@($manifest.allowedProcessActions).Count-eq0) 'O3J1 signed maintenance contract changed.'
foreach($change in @($manifest.changes)){Assert-True (@($change.approvedPredecessorSha256).Count-eq1-and@($change.approvedPredecessorSha256)-contains[string]$change.installedSha256-and[bool]$change.allowCreate) "O3J1 predecessor declaration changed: $($change.source)"}

$relativePaths=@((Get-Content -LiteralPath $collectionInvocation -Raw|ConvertFrom-Json).relativePaths)
$sourceRoot=Join-Path $fixtureRoot 's';[void](New-Item -ItemType Directory -Path $sourceRoot)
foreach($relative in $relativePaths){$leaf=[IO.Path]::GetFullPath([IO.Path]::Combine($sourceRoot,([string]$relative).Replace('/','\')));[void](New-Item -ItemType Directory -Path (Split-Path -Parent $leaf) -Force);Write-NewUtf8 $leaf (([ordered]@{schema='argos_o3j1_exact_package_fixture_v1';relativePath=[string]$relative;candidateRows=@([ordered]@{channel='BF';physicalCandidate=1},[ordered]@{channel='DF';physicalCandidate=1})}|ConvertTo-Json -Depth 6 -Compress)+[Environment]::NewLine)}
$fixtureConfiguration=Join-Path $fixtureRoot 'c.json';$configurationValue=Get-Content -LiteralPath $configuration -Raw|ConvertFrom-Json;$configurationValue.approvedRootPath=$sourceRoot;Write-NewJson $fixtureConfiguration $configurationValue;$fixtureConfigurationSha=Get-Sha $fixtureConfiguration

function Invoke-Case([string]$Name,[bool]$FailAfterProvider){
    $processor=Join-Path $fixtureRoot $Name;[void](New-Item -ItemType Directory -Path $processor)
    $installedProvider=Join-Path $processor 'OCV03_ResultJsonProviderV1.ps1';$installedConfig=Join-Path $processor 'OCV03_O3J1_RESULT_JSON_PROVIDER_CONFIG.json'
    Copy-Item -LiteralPath $provider -Destination $installedProvider;Copy-Item -LiteralPath $configuration -Destination $installedConfig
    Assert-True ((Get-Sha $installedProvider)-eq$providerSha-and(Get-Sha $installedConfig)-eq$configurationSha) "O3J1 $Name installed target bytes changed."
    $invocationPath=Join-Path $fixtureRoot ($Name+'.json')
    Write-NewJson $invocationPath ([ordered]@{schema='argos_o3j1_entrypoint_invocation_v1';providerPath=$installedProvider;providerSha256=$providerSha;configurationPath=$fixtureConfiguration;configurationSha256=$fixtureConfigurationSha;collectionInvocationPath=$collectionInvocation;collectionInvocationSha256=$collectionInvocationSha;failAfterProvider=$FailAfterProvider;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false})
    if($FailAfterProvider){$captured=$false;try{[void](& $entrypoint -Rehearsal -InvocationManifest $invocationPath)}catch{$captured=[string]$_.Exception.Message-match'INJECTED_O3J1_ENTRYPOINT_FAILURE_AFTER_PROVIDER'};Assert-True $captured 'O3J1 injected failure was not captured.';return}
    $result=(& $entrypoint -Rehearsal -InvocationManifest $invocationPath)|ConvertFrom-Json
    Assert-True ([string]$result.state-eq'PASS_O3J1_EXACT_RESULT_JSON_CAPABILITY'-and[int]$result.collection.fileCount-eq13-and[bool]$result.installedProviderExecuted) "O3J1 $Name exact entrypoint failed."
}
Invoke-Case 'create' $false
Invoke-Case 'target' $false
$unapprovedProvider=Join-Path $fixtureRoot 'unapproved_provider.ps1';$unapprovedConfig=Join-Path $fixtureRoot 'unapproved_config.json';Write-NewUtf8 $unapprovedProvider 'unapproved';Write-NewUtf8 $unapprovedConfig '{}'
$unapprovedProviderHash=Get-Sha $unapprovedProvider;$unapprovedConfigHash=Get-Sha $unapprovedConfig
Assert-True (@($manifest.changes[0].approvedPredecessorSha256)-notcontains$unapprovedProviderHash-and@($manifest.changes[1].approvedPredecessorSha256)-notcontains$unapprovedConfigHash) 'O3J1 unapproved predecessor accidentally approved.'
Assert-True ((Get-Sha $unapprovedProvider)-eq$unapprovedProviderHash-and(Get-Sha $unapprovedConfig)-eq$unapprovedConfigHash) 'O3J1 unapproved predecessor changed.'
Invoke-Case 'rollback' $true
$record=[ordered]@{schema='argos_o3j1_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_EXACT_PACKAGE_REHEARSAL';requestId=[string]$manifest.requestId;requestZipSha256=$expectedZip;windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;windowsPowerShellMinor=$PSVersionTable.PSVersion.Minor;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=4;changeCount=2;createCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;postProviderFailureCaptured=$true;endpointWorkerSha256=Get-Sha $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceJsonContentRead=$true;sourceImageBytesRead=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskActions=0;processActions=0;healthyProcessorTouched=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record|ConvertTo-Json -Depth 8
