#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Collect,[Parameter(Mandatory=$true)][string]$InvocationManifest)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Collect)){throw 'Specify exactly one of -Preflight or -Collect.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Sha-Bytes([byte[]]$Bytes){$algorithm=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-','')}finally{$algorithm.Dispose()}}
function Required([object]$Object,[string]$Name){$property=$Object.PSObject.Properties[$Name];if($null-eq$property){throw "O3F15L1 required property absent: $Name"};$property.Value}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$signGatePath=Join-Path $PSScriptRoot 'O3F15L1_SIGN_GATE.json'
$publishGatePath=Join-Path $PSScriptRoot 'O3F15L1_PUBLISH_GATE.json'
$verifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
foreach($path in @($InvocationManifest,$signGatePath,$publishGatePath,$verifier,$certificate)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L1 collection dependency absent: $path"}
$invocation=Get-Content -LiteralPath $InvocationManifest -Raw|ConvertFrom-Json
$signGate=Get-Content -LiteralPath $signGatePath -Raw|ConvertFrom-Json
$publishGate=Get-Content -LiteralPath $publishGatePath -Raw|ConvertFrom-Json
Require ([string]$invocation.schema-eq'argos_ocv03_o3f15l1_response_collection_invocation_v1'-and[string]$invocation.state-eq'FROZEN_FOR_COLLECTION') 'O3F15L1 collection invocation is not frozen.'
$requestId=[string](Required $invocation 'requestId')
$responseId=[string](Required $invocation 'responseId')
$sourceZip=[IO.Path]::GetFullPath([string](Required $invocation 'sourceZip'))
$zipBytes=[int64](Required $invocation 'sourceZipBytes')
$zipHash=[string](Required $invocation 'sourceZipSha256')
Require ([string]$signGate.state-eq'PASS_O3F15L1_SIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE'-and[string]$signGate.requestId-eq$requestId) 'O3F15L1 sign gate does not match collection invocation.'
Require ([string]$publishGate.state-eq'PASS_O3F15L1_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_LAUNCH_RESPONSE'-and[string]$publishGate.requestId-eq$requestId) 'O3F15L1 publish gate does not match collection invocation.'
$expectedShare='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$psDrive=Get-PSDrive U -ErrorAction Stop
$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$psDrive.DisplayRoot-eq$expectedShare-and[string]$disk.ProviderName-eq$expectedShare-and[int]$disk.DriveType-eq4) 'O3F15L1 qualified persistent U: mapping changed.'
$responses=[IO.Path]::GetFullPath('U:\ProjectPortalRO\responses')
Require ($sourceZip.StartsWith(($responses.TrimEnd('\')+'\'),[StringComparison]::OrdinalIgnoreCase)) 'O3F15L1 response ZIP is outside the qualified response root.'
Require (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3F15L1 response ZIP absent.'
Require ((Get-Item -LiteralPath $sourceZip).Length-eq$zipBytes-and(Sha $sourceZip)-eq$zipHash) 'O3F15L1 response ZIP changed.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($sourceZip)
try{
    $entry=$archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Require ($null-ne$entry-and$entry.Length-le65536) 'O3F15L1 response manifest absent or too large.'
    $entryStream=$entry.Open()
    $memory=New-Object IO.MemoryStream
    try{$entryStream.CopyTo($memory);$manifestBytes=$memory.ToArray()}finally{$memory.Dispose();$entryStream.Dispose()}
    $manifest=([Text.Encoding]::UTF8.GetString($manifestBytes))|ConvertFrom-Json
    $sourceManifestSha256=Sha-Bytes $manifestBytes
}finally{$archive.Dispose()}
Require ([string](Required $manifest 'requestId')-eq$requestId-and[string](Required $manifest 'responseId')-eq$responseId-and[string](Required $manifest 'state')-eq'PASS_MAINTENANCE_PATCH'-and[string](Required $manifest 'sourceRole')-eq'JBOD'-and[bool](Required $manifest 'reviewOnly')-and-not[bool](Required $manifest 'productionRoutingEnabled')) 'O3F15L1 terminal response manifest contract changed.'
$ready=Join-Path $PSScriptRoot 'o3f15l1_response'
$partial=$ready+'.partial'
$gatePath=Join-Path $PSScriptRoot 'O3F15L1_SIGNED_LAUNCH_GATE.json'
$resumePartial=Test-Path -LiteralPath $partial -PathType Container
foreach($path in @($ready,$gatePath)){Require (-not(Test-Path -LiteralPath $path)) "O3F15L1 create-new collection target exists: $path"}
if($resumePartial){
    $partialManifestPath=Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.json'
    Require (Test-Path -LiteralPath $partialManifestPath -PathType Leaf) 'O3F15L1 resumable partial response manifest is absent.'
    Require ((Sha $partialManifestPath)-eq$sourceManifestSha256) 'O3F15L1 partial response is not the exact pinned source response attempt.'
    $partialManifest=Get-Content -LiteralPath $partialManifestPath -Raw|ConvertFrom-Json
    Require ([string](Required $partialManifest 'requestId')-eq$requestId-and[string](Required $partialManifest 'responseId')-eq$responseId) 'O3F15L1 partial response identity changed.'
}

if($Preflight){[ordered]@{schema='argos_ocv03_o3f15l1_response_collection_preflight_v1';state='PASS_O3F15L1_RESPONSE_COLLECTION_PREFLIGHT';requestId=$requestId;responseId=$responseId;sourceZipBytes=$zipBytes;sourceZipSha256=$zipHash;sourceManifestSha256=$sourceManifestSha256;exactPartialResume=$resumePartial;partialManifestExact=$(if($resumePartial){$true}else{$null});mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

if(-not$resumePartial){[void](New-Item -ItemType Directory -Path $partial);[IO.Compression.ZipFile]::ExtractToDirectory($sourceZip,$partial)}
Require ((Sha (Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.json'))-eq$sourceManifestSha256) 'O3F15L1 extracted response manifest changed from the pinned source ZIP.'
& $verifier -PackagePath $partial -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId|Out-Null
$stdoutPath=Join-Path $partial 'MAINTENANCE.stdout.txt'
$stderrPath=Join-Path $partial 'MAINTENANCE.stderr.txt'
$resultPath=Join-Path $partial 'RESULT.json'
foreach($path in @($stdoutPath,$stderrPath,$resultPath)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L1 response file absent: $path"}
Require ((Get-Item -LiteralPath $stderrPath).Length-eq0-and(Get-Item -LiteralPath $stdoutPath).Length-le1048576) 'O3F15L1 maintenance output bounds changed.'
$lines=@(Get-Content -LiteralPath $stdoutPath)
Require ($lines.Count-eq1) 'O3F15L1 stdout line count changed.'
$execution=$lines[0]|ConvertFrom-Json
$maintenance=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
Require ([string](Required $execution 'schema')-eq'argos_ocv03_o3f15l1_launch_v1'-and[string](Required $execution 'state')-eq'PASS_O3F15L1_FRESH_EXACT_978_FRONT_CORPUS_LAUNCHED'-and[int](Required $execution 'expectedPairCount')-eq978) 'O3F15L1 signed launch identity/cardinality changed.'
Require ([int](Required $execution 'pid')-gt0-and-not[string]::IsNullOrWhiteSpace([string](Required $execution 'creationTimeUtc'))) 'O3F15L1 owned worker identity is incomplete.'
Require ([string](Required $execution 'runtimeRoot')-eq'D:/O3F15RT'-and[string](Required $execution 'gateRoot')-eq'D:/O3F15G'-and[string](Required $execution 'corpusRoot')-eq'D:/O3F15C'-and[string](Required $execution 'mirrorRoot')-eq'D:/KLARFExport/_ArgosReview/F15S') 'O3F15L1 signed launch roots changed.'
Require ([string](Required $execution 'progressPath')-eq'D:/O3F15C/PROGRESS.json'-and[string](Required $execution 'summaryPath')-eq'D:/O3F15C/SUMMARY.json'-and[string](Required $execution 'mirrorProgressPath')-eq'D:/KLARFExport/_ArgosReview/F15S/PROGRESS.json'-and[string](Required $execution 'bootstrapProgressState')-eq'RUNNING_O3F15_FULL978'-and[int](Required $execution 'bootstrapScheduledCount')-eq978) 'O3F15L1 signed launch bootstrap progress changed.'
Require ([string](Required $execution 'focusedTestState')-eq'PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE'-and[string](Required $execution 'selfTestState')-eq'PASS_O3F15_FRONT_RECONCILE_SELF_TEST'-and[string](Required $execution 'preflightState')-eq'PASS_O3F15_FRONT_RECONCILE_PREFLIGHT'-and[string](Required $execution 'gateState')-eq'COMPLETE_O3F15_GATE') 'O3F15L1 signed launch stage states changed.'
Require ([bool](Required $execution 'ownedProcessStarted')-and-not[bool](Required $execution 'existingProcessesQueried')-and-not[bool](Required $execution 'existingProcessOrTaskActionPerformed')-and-not[bool](Required $execution 'sourceImagesReadByEndpoint')-and-not[bool](Required $execution 'sourceImagesMutated')-and-not[bool](Required $execution 'automaticRetryAuthorized')-and-not[bool](Required $execution 'holdsCleared')-and[bool](Required $execution 'reviewOnly')-and-not[bool](Required $execution 'trainingEligible')-and-not[bool](Required $execution 'xmlEligible')-and-not[bool](Required $execution 'productionEligible')) 'O3F15L1 signed launch safety contract changed.'
Require ([string](Required $maintenance 'state')-eq'PASS_MAINTENANCE_PATCH'-and[int](Required $maintenance 'exitCode')-eq0-and[bool](Required $maintenance 'reviewOnly')-and-not[bool](Required $maintenance 'productionRoutingEnabled')) 'O3F15L1 maintenance result changed.'
Move-Item -LiteralPath $partial -Destination $ready
$value=[ordered]@{schema='argos_ocv03_o3f15l1_signed_launch_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L1_SIGNED_EXACT_978_FRONT_CORPUS_LAUNCHED';requestId=$requestId;responseId=$responseId;responseZipBytes=$zipBytes;responseZipSha256=$zipHash;responseManifestSha256=$sourceManifestSha256;exactSourceResponseAttemptCollected=$true;signedResponseVerified=$true;endpointState='PASS_MAINTENANCE_PATCH';executionState=[string]$execution.state;expectedPairCount=978;side='FRONT';focusedTestState=[string]$execution.focusedTestState;selfTestState=[string]$execution.selfTestState;preflightState=[string]$execution.preflightState;gateState=[string]$execution.gateState;gateSummarySha256=[string]$execution.gateSummarySha256;workerPid=[int]$execution.pid;workerCreationTimeUtc=[string]$execution.creationTimeUtc;runtimeRoot=[string]$execution.runtimeRoot;gateRoot=[string]$execution.gateRoot;corpusRoot=[string]$execution.corpusRoot;mirrorRoot=[string]$execution.mirrorRoot;progressPath=[string]$execution.progressPath;summaryPath=[string]$execution.summaryPath;mirrorProgressPath=[string]$execution.mirrorProgressPath;bootstrapProgressState=[string]$execution.bootstrapProgressState;bootstrapScheduledCount=[int]$execution.bootstrapScheduledCount;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingProcessesQueried=$false;existingProcessOrTaskActionPerformed=$false;providerActivationPerformed=$false;holdsAutomaticallyCleared=$false;automaticRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($gatePath,(($value|ConvertTo-Json -Depth 10)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$value|ConvertTo-Json -Depth 10
