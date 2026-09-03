#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Publish)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Publish)){throw 'Specify exactly one of -Preflight or -Publish.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function New-Json([string]$Path,[object]$Value){Require (-not(Test-Path -LiteralPath $Path)) "O3F15L1 create-new JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
function Require-Dependency([object[]]$Dependencies,[string]$Path,[string]$Hash){$matches=@($Dependencies|Where-Object{[string]$_.path-eq$Path});Require ($matches.Count-eq1-and[string]$matches[0].sha256-eq$Hash) "O3F15L1 preaction dependency absent or stale: $Path"}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$signGatePath=Join-Path $PSScriptRoot 'O3F15L1_SIGN_GATE.json'
$rehearsalGatePath=Join-Path $PSScriptRoot 'O3F15L1_FINAL_ZIP_REHEARSAL_GATE.json'
$routeGatePath=Join-Path (Join-Path $PSScriptRoot 'final_o3f15') 'O3F15L1_PREPUBLICATION_PATH_GATE.json'
$preactionPath=Join-Path $PSScriptRoot 'PREACTION_O3F15L1_PUBLISH.json'
$preactionGatePath=Join-Path $PSScriptRoot 'O3F15L1_PUBLISH_PREACTION_GATE.json'
$publishGatePath=Join-Path $PSScriptRoot 'O3F15L1_PUBLISH_GATE.json'
$contractPath=Join-Path $PSScriptRoot 'O3F15_LAUNCH_CONTRACT.json'
$definitionPath=Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$historyAuditPath=Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$collectionCasePath=Join-Path $project 'work\ARGOS_POWERSHELL_COLLECTION_CASE_GATE_20260821.json'
foreach($path in @($signGatePath,$rehearsalGatePath,$routeGatePath,$preactionPath,$preactionGatePath,$contractPath,$definitionPath,$historyAuditPath,$collectionCasePath)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L1 publication dependency absent: $path"}
$signGate=Get-Content -LiteralPath $signGatePath -Raw|ConvertFrom-Json
$rehearsalGate=Get-Content -LiteralPath $rehearsalGatePath -Raw|ConvertFrom-Json
$routeGate=Get-Content -LiteralPath $routeGatePath -Raw|ConvertFrom-Json
$preaction=Get-Content -LiteralPath $preactionPath -Raw|ConvertFrom-Json
$preactionGate=Get-Content -LiteralPath $preactionGatePath -Raw|ConvertFrom-Json
$contract=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json
$requestId=[string]$signGate.requestId
$source=[string]$signGate.packageZipPath
$sourceHash=[string]$signGate.packageZipSha256
Require ([string]$signGate.state-eq'PASS_O3F15L1_SIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE') 'O3F15L1 sign gate state changed.'
Require (Test-Path -LiteralPath $source -PathType Leaf) 'O3F15L1 signed ZIP absent.'
Require ((Get-Item -LiteralPath $source).Length-eq[int64]$signGate.packageZipBytes-and(Sha $source)-eq$sourceHash) 'O3F15L1 signed ZIP changed.'
Require ([string]$rehearsalGate.state-eq'PASS_O3F15L1_FINAL_ZIP_WINDOWS_PS51_REHEARSAL'-and[string]$rehearsalGate.requestId-eq$requestId-and[string]$rehearsalGate.packageZipSha256-eq$sourceHash) 'O3F15L1 final-ZIP rehearsal is absent or stale.'
Require ([string]$routeGate.state-eq'PASS_O3F15L1_SIGNED_AND_PATH_GATED'-and[string]$routeGate.requestId-eq$requestId-and[string]$routeGate.packageZipSha256-eq$sourceHash-and[int]$routeGate.reservedSuffixCharacters-eq32) 'O3F15L1 route gate is absent or stale.'
Require ([bool]$routeGate.packageZipAndPathGateAdjacent-and[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($source))-eq[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($routeGatePath))) 'O3F15L1 final ZIP and machine-readable path gate are not adjacent.'
Require ([string]$contract.schema-eq'argos_ocv03_o3f15l1_launch_contract_v1'-and[string]$contract.state-eq'FROZEN_FOR_BUILD'-and(Sha $contractPath)-eq[string]$signGate.contractSha256) 'O3F15L1 frozen launch contract changed after signing.'
Require ([string]$contract.inheritedRoute.endpointWorkerSha256-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'-and[string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256-eq'465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'-and[string]$contract.inheritedRoute.queueSafetyGateSha256-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'-and-not[bool]$contract.inheritedRoute.routeImplementationChanged) 'O3F15L1 inherited portal route pins changed.'
Require ([string]$routeGate.endpointWorkerSha256-eq[string]$contract.inheritedRoute.endpointWorkerSha256-and[string]$routeGate.installedRouteConfigEvidenceSha256-eq[string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256-and[string]$routeGate.queueSafetyGateSha256-eq[string]$contract.inheritedRoute.queueSafetyGateSha256) 'O3F15L1 route gate no longer binds the inherited endpoint evidence.'
Require ([string]$preaction.schema-eq'argos_zero_recurrence_preaction_v2'-and[string]$preaction.state-eq'PASS_PREACTION_CONTRACT'-and[string]$preaction.historyAuditPath-eq'work/ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'-and[string]$preaction.historyAuditSha256-eq'D54E5F766D4546827069C65F098D3C98E8C1C9B724B718A101674775FB51DA75'-and(Sha $historyAuditPath)-eq[string]$preaction.historyAuditSha256) 'O3F15L1 publication preaction history contract is absent or stale.'
Require ([string]$preaction.collectionCaseEvidence.path-eq'work/ARGOS_POWERSHELL_COLLECTION_CASE_GATE_20260821.json'-and[string]$preaction.collectionCaseEvidence.sha256-eq'17128A6B5745DC2B588D9803BD0E892D1108A69F87BA35300567089E1D83FF11'-and(Sha $collectionCasePath)-eq[string]$preaction.collectionCaseEvidence.sha256-and(@($preaction.collectionCaseEvidence.requiredCaseIds|Sort-Object)-join',')-eq'MANY,ONE,ZERO') 'O3F15L1 ZERO/ONE/MANY collection evidence changed.'
Require ([string]$preaction.scope.endpointWorkerSha256-eq[string]$contract.inheritedRoute.endpointWorkerSha256-and[string]$preaction.scope.installedRouteConfigEvidenceSha256-eq[string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256-and[string]$preaction.scope.queueSafetyGateSha256-eq[string]$contract.inheritedRoute.queueSafetyGateSha256-and-not[bool]$preaction.scope.routeImplementationChanged-and[int]$preaction.scope.maximumPublicationCount-eq1-and-not[bool]$preaction.scope.requestRetryAuthorized) 'O3F15L1 publication preaction scope changed.'
$dependencies=@($preaction.dependencies)
Require-Dependency $dependencies 'work/OPENCV_EDGE_NOTCH_O3F15/O3F15_LAUNCH_CONTRACT.json' (Sha $contractPath)
Require-Dependency $dependencies 'work/OPENCV_EDGE_NOTCH_O3F15/MAINTENANCE_DEFINITION.json' (Sha $definitionPath)
Require-Dependency $dependencies 'work/OPENCV_EDGE_NOTCH_O3F15/Publish-O3F15L1Package.ps1' (Sha $PSCommandPath)
Require-Dependency $dependencies 'work/OPENCV_EDGE_NOTCH_O3F15/O3F15L1_SIGN_GATE.json' (Sha $signGatePath)
Require-Dependency $dependencies 'work/OPENCV_EDGE_NOTCH_O3F15/O3F15L1_FINAL_ZIP_REHEARSAL_GATE.json' (Sha $rehearsalGatePath)
Require-Dependency $dependencies 'work/OPENCV_EDGE_NOTCH_O3F15/final_o3f15/O3F15L1_PREPUBLICATION_PATH_GATE.json' (Sha $routeGatePath)
Require ([string]$preactionGate.state-eq'PASS_ARGOS_ZERO_RECURRENCE_PREACTION'-and[string]$preactionGate.revision-eq[string]$preaction.revision-and[string]$preactionGate.actionType-eq[string]$preaction.actionType-and[bool]$preactionGate.collectionCaseEvidenceVerified-and(@($preactionGate.collectionCaseIds|Sort-Object)-join',')-eq'MANY,ONE,ZERO'-and[bool]$preactionGate.reviewOnly-and-not[bool]$preactionGate.productionRoutingEnabled) 'O3F15L1 publication preaction gate is absent or stale.'

$expectedShare='\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$psDrive=Get-PSDrive U -ErrorAction Stop
$disk=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$psDrive.DisplayRoot-eq$expectedShare-and[string]$disk.ProviderName-eq$expectedShare-and[int]$disk.DriveType-eq4) 'O3F15L1 qualified persistent U: mapping changed.'
$requests='U:\ProjectPortalRO\requests'
Require (Test-Path -LiteralPath $requests -PathType Container) 'O3F15L1 portal request root unavailable.'
$pending=@(Get-ChildItem -LiteralPath $requests -File -Filter '*.ready.zip' -ErrorAction Stop)
Require ($pending.Count-eq0) 'O3F15L1 portal request root contains an unresolved pending request.'
$target=Join-Path $requests ($requestId+'.ready.zip')
$upload=$target+'.upload'
foreach($path in @($target,$upload,$publishGatePath)){Require (-not(Test-Path -LiteralPath $path)) "O3F15L1 create-new publication path exists: $path"}
Require ((Get-Command git -ErrorAction Stop).CommandType-ne$null) 'O3F15L1 git is unavailable.'
$branch=[string](& git -C $project branch --show-current)
$head=[string](& git -C $project rev-parse HEAD)
$origin=[string](& git -C $project rev-parse refs/remotes/origin/codex/fiducial-opencv-d-drive)
$trackedStatus=@(& git -C $project status --porcelain --untracked-files=no)
Require ($LASTEXITCODE-eq0-and$branch-eq'codex/fiducial-opencv-d-drive'-and$head-eq$origin-and$trackedStatus.Count-eq0) 'O3F15L1 publication requires a clean tracked tree on the exact matching origin branch tip.'

if($Preflight){[ordered]@{schema='argos_ocv03_o3f15l1_publish_preflight_v1';state='PASS_O3F15L1_PUBLISH_PREFLIGHT';requestId=$requestId;packageZipSha256=$sourceHash;packageZipBytes=[int64]$signGate.packageZipBytes;rehearsalGateSha256=Sha $rehearsalGatePath;routeGateSha256=Sha $routeGatePath;preactionContractSha256=Sha $preactionPath;preactionGateSha256=Sha $preactionGatePath;pendingRequestCount=0;branch=$branch;branchTip=$head;trackedTreeClean=$true;publishAttemptCount=0;requestRetryAuthorized=$false;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

[IO.File]::Copy($source,$upload,$false)
Require ((Sha $upload)-eq$sourceHash) 'O3F15L1 upload hash changed.'
[IO.File]::Move($upload,$target)
Require ((Sha $target)-eq$sourceHash) 'O3F15L1 published hash changed.'
$value=[ordered]@{schema='argos_ocv03_o3f15l1_publish_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L1_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_LAUNCH_RESPONSE';requestId=$requestId;publishedPath=$target;publishedSha256=$sourceHash;publishedBytes=[int64](Get-Item -LiteralPath $target).Length;manifestSha256=[string]$signGate.manifestSha256;signatureSha256=[string]$signGate.signatureSha256;publishAttemptCount=1;automaticRetryAuthorized=$false;matchingSignedTerminalResponseRequired=$true;expectedPairCount=978;side='FRONT';reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
New-Json $publishGatePath $value
$value|ConvertTo-Json -Depth 10
