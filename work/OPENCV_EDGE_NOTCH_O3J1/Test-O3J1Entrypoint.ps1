#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Resolve-ControlPath([string]$Root,[string]$Value){if([IO.Path]::IsPathRooted($Value)){return [IO.Path]::GetFullPath($Value)};return [IO.Path]::GetFullPath((Join-Path $Root $Value))}
function Assert-Pin([string]$Path,[string]$Hash){Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Pinned entrypoint test dependency is absent: $Path";Assert-True ((Get-Sha $Path)-eq$Hash) "Pinned entrypoint test dependency changed: $Path"}
function Write-NewUtf8([string]$Path,[string]$Text){Assert-True (-not(Test-Path -LiteralPath $Path)) "Entrypoint test refuses overwrite: $Path";[IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))}
function Write-NewJson([string]$Path,[object]$Value){Write-NewUtf8 $Path (($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine)}

$projectRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$controlPath=Resolve-ControlPath $projectRoot $InvocationManifest
$control=Get-Content -LiteralPath $controlPath -Raw|ConvertFrom-Json
Assert-True ([string]$control.schema-eq'argos_o3j1_entrypoint_test_control_v1'-and[string]$control.state-eq'FROZEN_TEST_INPUT') 'Entrypoint test control changed.'
Assert-True ([bool]$control.reviewOnly-and-not[bool]$control.trainingEligible-and-not[bool]$control.xmlEligible-and-not[bool]$control.productionEligible-and-not[bool]$control.productionRoutingEnabled) 'Entrypoint test authority changed.'
$entrypoint=Resolve-ControlPath $projectRoot ([string]$control.entrypointPath)
$provider=Resolve-ControlPath $projectRoot ([string]$control.providerPath)
$preflightInvocation=Resolve-ControlPath $projectRoot ([string]$control.preflightInvocationPath)
$liveCollectionInvocation=Resolve-ControlPath $projectRoot ([string]$control.liveCollectionInvocationPath)
$fixtureRoot=[IO.Path]::GetFullPath([string]$control.fixtureRoot)
$gateOutput=Resolve-ControlPath $projectRoot ([string]$control.gateOutputPath)
Assert-Pin $entrypoint ([string]$control.entrypointSha256)
Assert-Pin $provider ([string]$control.providerSha256)
Assert-Pin $preflightInvocation ([string]$control.preflightInvocationSha256)
Assert-Pin $liveCollectionInvocation ([string]$control.liveCollectionInvocationSha256)
Assert-True (-not(Test-Path -LiteralPath $fixtureRoot)) 'Entrypoint fixture root already exists.'
Assert-True (-not(Test-Path -LiteralPath $gateOutput)) 'Entrypoint gate output already exists.'
Assert-True (($fixtureRoot.Length+32)-lt200) 'Entrypoint fixture root path budget failed.'
$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($entrypoint,[ref]$tokens,[ref]$errors);Assert-True (@($errors).Count-eq0) 'Entrypoint parser failed.'
$preflightResult=(& $entrypoint -Preflight -InvocationManifest $preflightInvocation)|ConvertFrom-Json
Assert-True ([string]$preflightResult.state-eq'PASS_O3J1_ENTRYPOINT_PREFLIGHT'-and[int]$preflightResult.requestedFileCount-eq[int]$control.expectedFileCount) 'Entrypoint preflight state changed.'
Assert-True (-not[bool]$preflightResult.sourceFilesRead-and-not[bool]$preflightResult.sourceImageBytesRead-and-not[bool]$preflightResult.imageBytesRead-and-not[bool]$preflightResult.mutationsPerformed-and-not[bool]$preflightResult.taskOrProcessActionPerformed-and-not[bool]$preflightResult.providerActivated) 'Entrypoint preflight crossed its boundary.'
if($Preflight){[ordered]@{schema='argos_o3j1_entrypoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_ENTRYPOINT_TEST_PREFLIGHT';entrypointSha256=[string]$control.entrypointSha256;providerSha256=[string]$control.providerSha256;fixtureRoot=$fixtureRoot;gateOutput=$gateOutput;sourceFilesRead=$false;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$sourceRoot=Join-Path $fixtureRoot 's';[void](New-Item -ItemType Directory -Path $sourceRoot)
$relativePaths=@((Get-Content -LiteralPath $liveCollectionInvocation -Raw|ConvertFrom-Json).relativePaths)
Assert-True ($relativePaths.Count-eq[int]$control.expectedFileCount) 'Entrypoint fixture path count changed.'
foreach($relative in $relativePaths){$leaf=[IO.Path]::GetFullPath([IO.Path]::Combine($sourceRoot,([string]$relative).Replace('/','\')));[void](New-Item -ItemType Directory -Path (Split-Path -Parent $leaf) -Force);Write-NewUtf8 $leaf (([ordered]@{schema='argos_o3j1_entrypoint_fixture_json_v1';relativePath=[string]$relative;candidateRows=@([ordered]@{channel='BF';widthDegrees=2.1},[ordered]@{channel='DF';widthDegrees=2.2})}|ConvertTo-Json -Depth 6 -Compress)+[Environment]::NewLine)}
$configPath=Join-Path $fixtureRoot 'c.json';$collectionPath=Join-Path $fixtureRoot 'i.json'
Write-NewJson $configPath ([ordered]@{schema='argos_ocv03_review_json_provider_config_v1';revision='TEST_O3J1_ENTRYPOINT';state='FROZEN_CONFIG';approvedRootName='TEST_O3J1_ENTRYPOINT';approvedRootPath=$sourceRoot;allowedExtension='.json';maximumFiles=13;maximumFileBytes=4194304;maximumTotalBytes=33554432;allowedRelativePaths=$relativePaths;imageExtensionsAllowed=$false;sourceMutationAllowed=$false;taskOrProcessActionAllowed=$false;providerActivationAllowed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false})
Write-NewJson $collectionPath ([ordered]@{schema='argos_ocv03_review_json_provider_invocation_v1';revision='TEST_O3J1_ENTRYPOINT';approvedRootName='TEST_O3J1_ENTRYPOINT';relativePaths=$relativePaths;expectedFileCount=13;returnRawJsonText=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false})
$configSha=Get-Sha $configPath;$collectionSha=Get-Sha $collectionPath
$successInvocation=Join-Path $fixtureRoot 'ok.json';$failureInvocation=Join-Path $fixtureRoot 'fail.json'
$base=[ordered]@{schema='argos_o3j1_entrypoint_invocation_v1';providerPath=$provider;providerSha256=[string]$control.providerSha256;configurationPath=$configPath;configurationSha256=$configSha;collectionInvocationPath=$collectionPath;collectionInvocationSha256=$collectionSha;failAfterProvider=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $successInvocation $base
$base.failAfterProvider=$true;Write-NewJson $failureInvocation $base
$failureCaptured=$false;$failureMessage=''
try{[void](& $entrypoint -Rehearsal -InvocationManifest $failureInvocation)}catch{$failureMessage=[string]$_.Exception.Message;$failureCaptured=$failureMessage-match'INJECTED_O3J1_ENTRYPOINT_FAILURE_AFTER_PROVIDER'}
Assert-True $failureCaptured 'Entrypoint injected failure was not captured.'
$success=(& $entrypoint -Rehearsal -InvocationManifest $successInvocation)|ConvertFrom-Json
Assert-True ([string]$success.state-eq'PASS_O3J1_EXACT_RESULT_JSON_CAPABILITY'-and[string]$success.collection.state-eq'PASS_O3J1_EXACT_RESULT_JSON_COLLECTED') 'Entrypoint success state changed.'
Assert-True ([int]$success.collection.fileCount-eq13-and@($success.collection.files).Count-eq13) 'Entrypoint success file count changed.'
Assert-True (-not[bool]$success.sourceImageBytesRead-and-not[bool]$success.imageBytesRead-and-not[bool]$success.sourceMutationPerformed-and-not[bool]$success.taskOrProcessActionPerformed-and-not[bool]$success.healthyProcessorTouched-and-not[bool]$success.providerActivated) 'Entrypoint success authority changed.'
$record=[ordered]@{schema='argos_o3j1_entrypoint_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_ENTRYPOINT_GATE';lifecycle='FROZEN_LOCAL_EVIDENCE';entrypointSha256=[string]$control.entrypointSha256;providerSha256=[string]$control.providerSha256;controlSha256=Get-Sha $controlPath;preflightState=[string]$preflightResult.state;terminalState=[string]$success.state;collectionState=[string]$success.collection.state;fileCount=[int]$success.collection.fileCount;injectedFailureCaptured=$failureCaptured;injectedFailureMessage=$failureMessage;installedProviderExecutedInRehearsal=[bool]$success.installedProviderExecuted;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;sourceImageBytesRead=$false;imageBytesRead=$false;sourceMutationPerformed=$false;taskActions=0;processActions=0;healthyProcessorTouched=$false;providerActivationPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewUtf8 $gateOutput (($record|ConvertTo-Json -Depth 10)+[Environment]::NewLine)
[ordered]@{schema='argos_o3j1_entrypoint_gate_result_v1';state='PASS_O3J1_ENTRYPOINT_GATE';gateOutput=$gateOutput;gateSha256=Get-Sha $gateOutput;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 5
