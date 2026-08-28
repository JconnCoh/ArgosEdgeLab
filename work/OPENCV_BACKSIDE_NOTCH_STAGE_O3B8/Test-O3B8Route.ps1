#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Select exactly one O3B8 route action.'}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$planPath=Join-Path $PSScriptRoot 'O3B8_PACKAGE_PLAN.json';$payloadPath=Join-Path $PSScriptRoot 'O3B8_PAYLOAD_PLAN.json';$gatePath=Join-Path $PSScriptRoot 'O3B8_EXACT_ROUTE_PATH_GATE.json'
foreach($path in @($planPath,$payloadPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "O3B8 route prerequisite missing: $path"}}
$plan=Get-Content -LiteralPath $planPath -Raw|ConvertFrom-Json;$payload=Get-Content -LiteralPath $payloadPath -Raw|ConvertFrom-Json
$requestId=[string]$plan.requestId;$requestLeaves=@('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig')+@($payload.files|ForEach-Object{'payload/'+[string]$_.path})
$candidates=New-Object Collections.Generic.List[string]
foreach($root in @($plan.requestExpandedRoots)){foreach($leaf in $requestLeaves){$candidates.Add(([string]$root).TrimEnd('/')+'/'+$leaf)}}
foreach($path in @($plan.requestZipPaths)){[void]$candidates.Add([string]$path)}
$internal=@(
 "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/ledger/$requestId.json",
 "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/maintenance/$requestId/prior/M000_0123456789_0123456789.prior",
 "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/maintenance/$requestId/failed_new/M000_0123456789_0123456789.rollback",
 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/.M000_0123456789_0123456789.stage',
 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/.M000_0123456789_0123456789.restore',
 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py',
 'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/MAINTENANCE.stdout.txt',
 'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/MAINTENANCE.stderr.txt',
 'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/RESULT.json',
 'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/compact/C_0123456789AB_01234567/FAILURE.json',
 'Q:/BrightfieldBacksideWafer/resizedImage/62627-193_Slot01_BrightfieldBacksideWafer_PM2_resizedImage.bmp',
 'Q:/DarkfieldBacksideWafer/resizedImage/62627-193_Slot01_DarkfieldBacksideWafer_PM2_resizedImage.bmp',
 'D:/B8O1.partial/BF.bmp','D:/B8O1.partial/DF.bmp','D:/B8O1.partial/O3B8_RESULT.json','D:/B8O1/BF.bmp','D:/B8O1/DF.bmp','D:/B8O1/O3B8_RESULT.json','D:/B8O1.failed/O3B8_RESULT.json'
)
foreach($path in $internal){[void]$candidates.Add($path)}
$responseId='R_0123456789AB_20260828235959999_a1b2c3d4';$responseLeaves=@('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','MAINTENANCE.stdout.txt','MAINTENANCE.stderr.txt','RESULT.json')
$responseRoots=@(
 "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/response_quarantine/$responseId.partial",
 "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/responses/pending/$responseId.ready",
 "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseId.ready",
 "C:/ProgramData/ArgosProjectPortalRO/to_argos/sent/$responseId.ready",
 "C:/ProgramData/ArgosProjectPortalRO/from_jbod/pending/$responseId.ready",
 "C:/ProgramData/ArgosProjectPortalRO/to_gateway/pending/$responseId.ready",
 "C:/ProgramData/ArgosProjectPortalRO/to_gateway/sent/$responseId.ready",
 "C:/APR/R/pending/$responseId.ready",
 "C:/APR/A/$responseId.ready"
)
foreach($root in $responseRoots){foreach($leaf in $responseLeaves){$candidates.Add($root+'/'+$leaf)}}
foreach($path in @("C:/ProgramData/ArgosProjectPortalRO/share/response_zip_archive/$responseId.ready.zip","U:/ProjectPortalRO/responses/$responseId.ready.zip","C:/B8R/$responseId.ready.zip","C:/B8R/$responseId.ready/PORTAL_RESPONSE_MANIFEST.json")){[void]$candidates.Add($path)}
$unique=@($candidates.ToArray()|Sort-Object -Unique);$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1';$budget=& $pathTool -CandidatePath $unique -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$budget.state-ne'PASS_PATH_BUDGET'){throw 'O3B8 complete route path budget failed.'}
$maximumRow=@($budget.candidates|Sort-Object effectiveLength -Descending|Select-Object -First 1)[0];$maximumComponent=[int](($budget.candidates|Measure-Object longestComponentLength -Maximum).Maximum)
$record=[ordered]@{schema='argos_ocv03_o3b8_exact_route_path_gate_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3B8_EXACT_ROUTE_PATH_GATE_PRE_SIGN';requestId=$requestId;requestLeafCount=$requestLeaves.Count;expandedRequestRootCount=@($plan.requestExpandedRoots).Count;requestZipPathCount=@($plan.requestZipPaths).Count;responseRootCount=$responseRoots.Count;uniqueEvaluatedCandidateCount=$unique.Count;reservedSuffixCharacters=32;maximumEffectiveLength=[int]$maximumRow.effectiveLength;maximumPath=[string]$maximumRow.path;maximumComponentLength=$maximumComponent;allCandidatesBelowWarningThreshold=$true;fullFinalPayloadLeafSetExpandedBeforeSignature=$true;deepestProcessedCompletedRootIncluded=$true;requestsFromGatewayPendingRootIncluded=$true;actualSourceAliasDrive='Q:';canonicalDSourcePathsAreProvenanceOnly=$true;signaturesCreated=0;publications=0;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$record|ConvertTo-Json -Depth 8;return}
if(Test-Path -LiteralPath $gatePath){throw 'O3B8 route gate already exists.'};[IO.File]::WriteAllText($gatePath,(($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)));$record|ConvertTo-Json -Depth 8
