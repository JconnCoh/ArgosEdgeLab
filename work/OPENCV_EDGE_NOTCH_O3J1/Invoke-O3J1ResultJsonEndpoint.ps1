#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($Preflight-and$Rehearsal){throw 'O3J1 cannot combine Preflight and Rehearsal.'}

function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Resolve-TestPath([string]$Root,[string]$Value){
    Assert-True (-not[string]::IsNullOrWhiteSpace($Value)-and$Value.IndexOfAny([char[]]'*?')-lt0) 'Unsafe O3J1 test path.'
    if([IO.Path]::IsPathRooted($Value)){return [IO.Path]::GetFullPath($Value)}
    return [IO.Path]::GetFullPath((Join-Path $Root $Value))
}
function Assert-Pin([string]$Path,[string]$Hash){
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O3J1 prerequisite is absent: $Path"
    Assert-True ((Get-Sha $Path)-eq$Hash) "O3J1 prerequisite hash changed: $Path"
}

$projectRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$processorRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$providerPath=Join-Path $processorRoot 'OCV03_ResultJsonProviderV1.ps1'
$configPath=Join-Path $processorRoot 'OCV03_O3J1_RESULT_JSON_PROVIDER_CONFIG.json'
$collectionInvocationPath=Join-Path $PSScriptRoot 'O3J1_RESULT_JSON_INVOCATION.json'
$providerSha='EF9773ADAC624A7A8A689989AB0EE404C2863B4E32B2666F437331E8CC9CAE67'
$configSha='01C09158CF67EB9C04C84DE35F8C039D9F0F5B913319E304543AD8482ACE3EA0'
$collectionInvocationSha='6220CD7638D83EA18FE24E4C31A29FD542747B99ECF6AE6B205E5556335CC96B'
$failAfterProvider=$false

if($Preflight-or$Rehearsal){
    Assert-True (-not[string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3J1 Preflight/Rehearsal requires InvocationManifest.'
    $invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
    Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'O3J1 entrypoint invocation is absent.'
    Assert-True ((Get-Item -LiteralPath $invocationPath).Length-le65536) 'O3J1 entrypoint invocation is too large.'
    $invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
    Assert-True ([string]$invocation.schema-eq'argos_o3j1_entrypoint_invocation_v1') 'O3J1 entrypoint invocation schema changed.'
    Assert-True ([bool]$invocation.reviewOnly-and-not[bool]$invocation.trainingEligible-and-not[bool]$invocation.xmlEligible-and-not[bool]$invocation.productionEligible-and-not[bool]$invocation.productionRoutingEnabled) 'O3J1 entrypoint invocation authority changed.'
    $providerPath=Resolve-TestPath $projectRoot ([string]$invocation.providerPath)
    $configPath=Resolve-TestPath $projectRoot ([string]$invocation.configurationPath)
    $collectionInvocationPath=Resolve-TestPath $projectRoot ([string]$invocation.collectionInvocationPath)
    $providerSha=[string]$invocation.providerSha256
    $configSha=[string]$invocation.configurationSha256
    $collectionInvocationSha=[string]$invocation.collectionInvocationSha256
    $failAfterProvider=($invocation.PSObject.Properties.Name-contains'failAfterProvider')-and[bool]$invocation.failAfterProvider
}
else{
    Assert-True ($providerPath-eq'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_ResultJsonProviderV1.ps1') 'O3J1 live provider path changed.'
    Assert-True ($configPath-eq'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_O3J1_RESULT_JSON_PROVIDER_CONFIG.json') 'O3J1 live configuration path changed.'
    Assert-True ($collectionInvocationPath-eq(Join-Path $PSScriptRoot 'O3J1_RESULT_JSON_INVOCATION.json')) 'O3J1 live invocation path changed.'
}

Assert-Pin $providerPath $providerSha
Assert-Pin $configPath $configSha
Assert-Pin $collectionInvocationPath $collectionInvocationSha
$tokens=$null;$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$parseErrors)
Assert-True (@($parseErrors).Count-eq0) 'O3J1 installed provider parser failed.'
$providerPreflight=(& $providerPath -Preflight -ConfigurationPath $configPath -InvocationPath $collectionInvocationPath)|ConvertFrom-Json
Assert-True ([string]$providerPreflight.state-eq'PASS_O3J1_RESULT_JSON_PROVIDER_PREFLIGHT') 'O3J1 provider preflight state changed.'
Assert-True ([int]$providerPreflight.requestedFileCount-eq13-and-not[bool]$providerPreflight.sourceFilesRead-and-not[bool]$providerPreflight.imageBytesRead-and-not[bool]$providerPreflight.mutationsPerformed) 'O3J1 provider preflight contract changed.'

if($Preflight){
    [ordered]@{schema='argos_o3j1_entrypoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_ENTRYPOINT_PREFLIGHT';providerSha256=$providerSha;configurationSha256=$configSha;collectionInvocationSha256=$collectionInvocationSha;requestedFileCount=13;sourceFilesRead=$false;sourceImageBytesRead=$false;imageBytesRead=$false;mutationsPerformed=$false;taskOrProcessActionPerformed=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6 -Compress
    return
}

$collection=(& $providerPath -Collect -ConfigurationPath $configPath -InvocationPath $collectionInvocationPath)|ConvertFrom-Json
if($failAfterProvider){throw 'INJECTED_O3J1_ENTRYPOINT_FAILURE_AFTER_PROVIDER'}
Assert-True ([string]$collection.schema-eq'argos_ocv03_review_json_provider_result_v1'-and[string]$collection.state-eq'PASS_O3J1_EXACT_RESULT_JSON_COLLECTED') 'O3J1 collection terminal contract changed.'
Assert-True ([int]$collection.fileCount-eq13-and@($collection.files).Count-eq13-and[bool]$collection.exactAllowlistConsumed) 'O3J1 exact file count changed.'
Assert-True ([bool]$collection.jsonTextOnly-and-not[bool]$collection.imageBytesRead-and-not[bool]$collection.sourceImageBytesRead-and-not[bool]$collection.sourceMutationPerformed-and-not[bool]$collection.sourceDeletionPerformed-and-not[bool]$collection.taskOrProcessActionPerformed-and-not[bool]$collection.providerActivated) 'O3J1 collection authority changed.'
[ordered]@{schema='argos_o3j1_entrypoint_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_EXACT_RESULT_JSON_CAPABILITY';revision='O3J1_20260827T185500000Z_62629419';providerSha256=$providerSha;configurationSha256=$configSha;collectionInvocationSha256=$collectionInvocationSha;installedProviderExecuted=$true;collection=$collection;sourceJsonFilesRead=$true;sourceImageBytesRead=$false;imageBytesRead=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessActionPerformed=$false;inspectionTasksChanged=$false;healthyProcessorTouched=$false;providerActivated=$false;waferActionPerformed=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 12 -Compress
