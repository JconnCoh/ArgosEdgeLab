#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Build)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Build)){throw 'Specify exactly one of -Preflight or -Build.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function New-Json([string]$Path,[object]$Value){Require (-not(Test-Path -LiteralPath $Path)) "O3F15L4E4 create-new JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath=Join-Path $PSScriptRoot 'O3F15L4E4_LAUNCH_CONTRACT.json'
$contractHash='6880AF22BFE4B1CFB042D06AADCE785FFB1C3760C053F1402D4FDC60902DAD08'
$definitionSource=Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$root='C:\O3F15L4E4PK'
$payload=Join-Path $root 'payload'
$definitionTarget=Join-Path $root 'DEFINITION.json'
$gatePath=Join-Path $PSScriptRoot 'O3F15L4E4_BUILD_GATE.json'
foreach($path in @($contractPath,$definitionSource)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4E4 build dependency absent: $path"}
Require ($contractHash-notmatch'^__PENDING_') 'O3F15L4E4 contract hash is not frozen.'
Require ((Sha $contractPath)-eq$contractHash) 'O3F15L4E4 launch contract changed.'
$contract=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json
$definition=Get-Content -LiteralPath $definitionSource -Raw|ConvertFrom-Json
Require ([string]$contract.schema-eq'argos_ocv03_o3f15l4e4_launch_contract_v1'-and[string]$contract.state-eq'FROZEN_FOR_BUILD') 'O3F15L4E4 launch contract is not frozen.'
Require ([string]$contract.expectedComputerName-eq'A1025645101'-and[string]$contract.side-eq'FRONT'-and[int]$contract.expectedPairCount-eq978-and[int]$contract.expectedSourceProblemCount-eq0) 'O3F15L4E4 front-corpus identity changed.'
Require ([string]$contract.runtimeRoot-eq'D:/O3F15L4E4RT'-and[string]$contract.gateRoot-eq'D:/O3F15L4E4G'-and[string]$contract.corpusRoot-eq'D:/O3F15L4C'-and[string]$contract.mirrorRoot-eq'D:/KLARFExport/_ArgosReview/F15L4S') 'O3F15L4E4 exact fresh roots changed.'
Require ([string]$contract.expectedTerminalFailureSchema-eq'argos_ocv03_o3f15_terminal_failure_v1'-and[string]$contract.expectedTerminalFailureState-eq'HOLD_O3F15_ARTIFACT_COMMIT_FAILURE') 'O3F15L4E4 terminal artifact-failure contract changed.'
$inheritedRoute=$contract.inheritedRoute
Require ([string]$inheritedRoute.endpointWorkerSha256-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'-and[string]$inheritedRoute.installedRouteConfigEvidenceSha256-eq'465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'-and[string]$inheritedRoute.queueSafetyGateSha256-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'-and-not[bool]$inheritedRoute.routeImplementationChanged) 'O3F15L4E4 inherited portal route pins changed.'
Require ([string]$definition.schema-eq'argos_ocv03_o3f15l4e4_maintenance_definition_v1'-and[string]$definition.entryPoint-eq'payload/Invoke-O3F15L4E4.ps1') 'O3F15L4E4 maintenance definition changed.'
Require ([bool]$definition.reviewOnly-and-not[bool]$definition.productionRoutingEnabled-and-not[bool]$definition.requestRetryAuthorized-and@($definition.allowedTaskActions).Count-eq0-and@($definition.allowedProcessActions).Count-eq2) 'O3F15L4E4 authority widened.'
Require (@($definition.entryPointOutputs).Count-eq10-and@($definition.entryPointOutputs|Where-Object{[string]$_.path-eq'D:/O3F15L4C/TERMINAL_FAILURE.json'}).Count-eq1-and@($definition.entryPointOutputs|Where-Object{[string]$_.path-eq'D:/KLARFExport/_ArgosReview/F15L4S/TERMINAL_FAILURE.json'}).Count-eq1-and[int]$definition.timeoutContract.bootstrapProgressSeconds-eq600) 'O3F15L4E4 output/launch timeout declaration changed.'

$rows=New-Object Collections.Generic.List[object]
foreach($record in @($contract.payloadFiles)){
    $name=[string]$record.name
    $source=Join-Path $project ([string]$record.source)
    Require (-not[string]::IsNullOrWhiteSpace($name)-and-not[IO.Path]::IsPathRooted($name)-and$name-notmatch'[\\/]' -and$name-notmatch'^\.') "O3F15L4E4 unsafe payload name: $name"
    Require (Test-Path -LiteralPath $source -PathType Leaf) "O3F15L4E4 payload source absent: $source"
    $hash=Sha $source
    Require ($hash-eq[string]$record.sha256) "O3F15L4E4 payload source changed: $name"
    $rows.Add([pscustomobject]@{path=$name;source=$source;bytes=[int64](Get-Item -LiteralPath $source).Length;sha256=$hash;copyToRuntime=[bool]$record.copyToRuntime})
}
$rows.Add([pscustomobject]@{path='O3F15L4E4_LAUNCH_CONTRACT.json';source=$contractPath;bytes=[int64](Get-Item -LiteralPath $contractPath).Length;sha256=$contractHash;copyToRuntime=$false})
$sources=$rows.ToArray()
Require ($sources.Count-eq24-and@($sources.path|Sort-Object -Unique).Count-eq$sources.Count-and@($sources|Where-Object{$_.copyToRuntime}).Count-eq20) 'O3F15L4E4 payload source cardinality, runtime-copy count, or uniqueness changed.'
foreach($requiredName in @('Invoke-O3F15L4E4.ps1','O3F15L4E4_LAUNCH_CONTRACT.json','O3F15L4E4LaunchFixture.py','Recover-O3F15L4E4Gate.py','Run-O3F15L4FrontReconcile.py','Test-O3F15L4PathHolds.py','FullPerimeterWaferTopologyOpenCvR11.py','FullPerimeterWaferTopologyOpenCvR10.py','NativeFrontsideWaferPoseOpenCvV2R6.py','NativeFrontsideWaferPoseOpenCvV2R5.py','NativeFrontsideWaferPoseOpenCvV2.py','WaferTopologyAxisOpenCv.py','O3M9_SLOT16_JOB.json','OCV03_NotchReviewOpenCvV1.py')){Require (@($sources|Where-Object{$_.path-eq$requiredName}).Count-eq1) "O3F15L4E4 required payload source absent: $requiredName"}
$carrier=@($sources|Where-Object{$_.path-eq'OCV03_NotchReviewOpenCvV1.py'})
Require ($carrier.Count-eq1-and-not[bool]$carrier[0].copyToRuntime-and[string]$carrier[0].sha256-eq'6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4') 'O3F15L4E4 same-bytes carrier source changed.'
foreach($path in @($root,$gatePath)){Require (-not(Test-Path -LiteralPath $path)) "O3F15L4E4 create-new build target exists: $path"}
$planned=@($root,$payload,$definitionTarget,$gatePath,(Join-Path $payload 'Invoke-O3F15L4E4.ps1'),(Join-Path $payload 'O3F15L4E4_LAUNCH_CONTRACT.json'))
$pathGate=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Require ([string]$pathGate.state-eq'PASS_PATH_BUDGET') 'O3F15L4E4 local build path gate failed.'

if($Preflight){[ordered]@{schema='argos_ocv03_o3f15l4e4_build_preflight_v1';state='PASS_O3F15L4E4_BUILD_PREFLIGHT';contractSha256=$contractHash;definitionSha256=Sha $definitionSource;payloadFileCount=$sources.Count;runtimeCopyFileCount=@($sources|Where-Object{$_.copyToRuntime}).Count;payloadFiles=@($sources|ForEach-Object{[ordered]@{path=$_.path;bytes=$_.bytes;sha256=$_.sha256;copyToRuntime=$_.copyToRuntime}});expectedPairCount=978;side='FRONT';terminalFailureSchema=[string]$contract.expectedTerminalFailureSchema;terminalFailureState=[string]$contract.expectedTerminalFailureState;endpointWorkerSha256=[string]$inheritedRoute.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$inheritedRoute.installedRouteConfigEvidenceSha256;queueSafetyGateSha256=[string]$inheritedRoute.queueSafetyGateSha256;pathState=[string]$pathGate.state;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 10;return}

Require ([string]$definition.state-eq'FROZEN_FOR_SIGNING') 'O3F15L4E4 maintenance definition is not frozen for signing.'
[void](New-Item -ItemType Directory -Path $payload -Force)
foreach($row in $sources){[IO.File]::Copy([string]$row.source,(Join-Path $payload ([string]$row.path)),$false)}
[IO.File]::Copy($definitionSource,$definitionTarget,$false)
$actual=@(Get-ChildItem -LiteralPath $payload -File|Sort-Object Name)
Require ($actual.Count-eq$sources.Count) 'O3F15L4E4 built payload cardinality changed.'
$payloadFiles=@($actual|ForEach-Object{[ordered]@{path=$_.Name;bytes=[int64]$_.Length;sha256=Sha $_.FullName}})
$gate=[ordered]@{schema='argos_ocv03_o3f15l4e4_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4E4_UNSIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE_BUILT';buildRoot=$root;payloadFileCount=$payloadFiles.Count;runtimeCopyFileCount=@($sources|Where-Object{$_.copyToRuntime}).Count;payloadFiles=$payloadFiles;contractSha256=$contractHash;definitionSha256=Sha $definitionTarget;entrySha256=Sha (Join-Path $payload 'Invoke-O3F15L4E4.ps1');runnerSha256=Sha (Join-Path $payload 'Run-O3F15L4FrontReconcile.py');testSha256=Sha (Join-Path $payload 'Test-O3F15L4PathHolds.py');r11Sha256=Sha (Join-Path $payload 'FullPerimeterWaferTopologyOpenCvR11.py');carrierSha256=Sha (Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py');endpointWorkerSha256=[string]$inheritedRoute.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$inheritedRoute.installedRouteConfigEvidenceSha256;queueSafetyGateSha256=[string]$inheritedRoute.queueSafetyGateSha256;expectedPairCount=978;side='FRONT';terminalFailureSchema=[string]$contract.expectedTerminalFailureSchema;terminalFailureState=[string]$contract.expectedTerminalFailureState;sameBytesCarrier=$true;installedSemanticChange=$false;taskActionCount=0;signed=$false;published=$false;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
New-Json $gatePath $gate
$gate|ConvertTo-Json -Depth 10
