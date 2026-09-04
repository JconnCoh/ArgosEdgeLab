#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Need([bool]$Value,[string]$Message){if(-not $Value){throw $Message}}
function Sha([string]$Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop).Hash}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$oldGatePath=Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3F15L4E3\final_o3f15l4e3\O3F15L4E3_PREPUBLICATION_PATH_R4_GATE.json'
$signGatePath=Join-Path $PSScriptRoot 'O3F15L4E4_SIGN_GATE.json'
$outputPath=Join-Path $PSScriptRoot 'final_o3f15l4e4\O3F15L4E4_PREPUBLICATION_PATH_R4_GATE.json'
foreach($path in @($oldGatePath,$signGatePath)){Need (Test-Path -LiteralPath $path -PathType Leaf) "E4 route dependency absent: $path"}
Need (-not(Test-Path -LiteralPath $outputPath)) 'E4 route output already exists.'
$old=Get-Content -Raw -LiteralPath $oldGatePath|ConvertFrom-Json
$sign=Get-Content -Raw -LiteralPath $signGatePath|ConvertFrom-Json
Need ([string]$old.state-eq'PASS_O3F15L4E3_COMPLETE_ROUTE_PATH_R4_GATE') 'E3 route gate changed.'
Need ([string]$sign.state-eq'PASS_O3F15L4E4_SIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE') 'E4 sign gate changed.'
$oldId=[string]$old.requestId
$newId=[string]$sign.requestId
$rows=New-Object Collections.Generic.List[object]
foreach($row in @($old.routePaths)){
  $path=([string]$row.path).Replace($oldId,$newId).Replace('O3F15L4E3','O3F15L4E4').Replace('o3f15l4e3','o3f15l4e4')
  $rows.Add([pscustomobject]@{stage=[string]$row.stage;path=$path})
}
$addedNames=@('NativeFrontsideWaferPoseOpenCvV2R6.py','NativeFrontsideWaferPoseOpenCvV2R5.py','NativeFrontsideWaferPoseOpenCvV2.py','WaferTopologyAxisOpenCv.py')
$payloadStages=@($rows.ToArray()|Where-Object{$_.path -match '(?i)[\\/]payload[\\/]'}|Group-Object stage)
Need ($payloadStages.Count-eq11) 'E4 inherited payload-stage count changed.'
foreach($group in $payloadStages){
  Need ($group.Count-eq20) "E4 inherited payload cardinality changed at $($group.Name)."
  $sample=[string]$group.Group[0].path
  $match=[regex]::Match($sample,'(?i)^(.*[\\/]payload[\\/])[^\\/]+$')
  Need $match.Success "E4 payload parent unresolved at $($group.Name)."
  foreach($name in $addedNames){$rows.Add([pscustomobject]@{stage=[string]$group.Name;path=$match.Groups[1].Value+$name})}
}
$semanticRows=$rows.ToArray()
Need ($semanticRows.Count-eq388) 'E4 route semantic cardinality changed.'
$normalized=@($semanticRows|ForEach-Object{[IO.Path]::GetFullPath([string]$_.path)}|Sort-Object -Unique)
$budget=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $normalized -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Need ([string]$budget.state-eq'PASS_PATH_BUDGET') 'E4 complete route path budget failed.'
$measure=@{}
foreach($candidate in @($budget.candidates)){$measure[[IO.Path]::GetFullPath([string]$candidate.path)]=$candidate}
$finalRows=@($semanticRows|ForEach-Object{
  $key=[IO.Path]::GetFullPath([string]$_.path);$m=$measure[$key];Need ($null-ne$m) "E4 route measurement absent: $key"
  [pscustomobject]@{stage=[string]$_.stage;path=$key;rawLength=[int]$m.pathLength;effectiveLength=[int]$m.effectiveLength;maximumComponentLength=[int]$m.longestComponentLength;disposition=[string]$m.disposition}
})
$manifestPath=[string]$sign.packagePath+'\PORTAL_REQUEST_MANIFEST.json'
$signaturePath=[string]$sign.packagePath+'\PORTAL_REQUEST_MANIFEST.sig'
Need ((Sha $manifestPath)-eq[string]$sign.manifestSha256-and(Sha $signaturePath)-eq[string]$sign.signatureSha256) 'E4 signed manifest or signature changed.'
$manifest=Get-Content -Raw -LiteralPath $manifestPath|ConvertFrom-Json
Need (@($manifest.files).Count-eq24) 'E4 signed payload cardinality changed.'
$maxRow=$finalRows|Sort-Object effectiveLength -Descending|Select-Object -First 1
$maxComponent=($finalRows|Measure-Object maximumComponentLength -Maximum).Maximum
$result=[ordered]@{
 schema='argos_ocv03_o3f15l4e4_complete_route_path_r4_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');lifecycle='FROZEN';state='PASS_O3F15L4E4_COMPLETE_ROUTE_PATH_R4_GATE';revision='OCV03_O3F15L4E4_COMPLETE_R10_DEPENDENCY_CLOSURE_20260903';requestId=$newId;requestManifestSha256=[string]$sign.manifestSha256;requestSignatureSha256=[string]$sign.signatureSha256;signedPackageZipSha256=[string]$sign.packageZipSha256;installedRouteConfigRevisionSha256=[string]$sign.installedRouteConfigEvidenceSha256;endpointWorkerSha256=[string]$sign.endpointWorkerSha256;queueSafetyGateSha256=[string]$sign.queueSafetyGateSha256;queueSafetyChecksInherited=$true;suffixReserve=32;requestPayloadFileCount=24;longestRelativeRequestLeaf=[string](@($manifest.files.path)|Sort-Object Length -Descending|Select-Object -First 1);maximumResponseResultBytes=1048576;maximumResponseEntryBytes=1048576;responseLeafSet=@($old.responseLeafSet);evaluatedRouteRootCount=@($finalRows.stage|Sort-Object -Unique).Count;evaluatedPathCount=$finalRows.Count;maximumEffectiveLength=[int]$maxRow.effectiveLength;maximumComponentLength=[int]$maxComponent;longestPath=[string]$maxRow.path;longestResultLeaf=([string]$old.longestResultLeaf).Replace($oldId,$newId).Replace('O3F15L4E3','O3F15L4E4').Replace('o3f15l4e3','o3f15l4e4');routePaths=$finalRows;routeRowRuntimeType='System.Management.Automation.PSCustomObject';pathDisposition='PASS_PATH_BUDGET';publicationCountMaximum=1;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;requestRetryAuthorized=$false;rustDeskAllowed=$false;operatorInputRequired=$false;sourceImageBytesRead=$false;sourceMutationOrDeletionAuthorized=$false;existingTaskOrProcessActionAuthorized=$false;providerActivationAuthorized=$false;selectorOrThresholdChangeAuthorized=$false;automaticHoldClearanceAuthorized=$false;fullFrontsideHoldCountPreserved=184;patternedFrontHoldCountPreserved=12;slot02AmbiguityPreserved=$true;slot16RareHotspotPreserved=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mutationsPerformed=$false
}
if($Preflight){$result.lifecycle='DRAFT';$result.state='PASS_O3F15L4E4_COMPLETE_ROUTE_PATH_R4_PREFLIGHT';$result|ConvertTo-Json -Depth 8;return}
[IO.File]::WriteAllText($outputPath,(($result|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$result|ConvertTo-Json -Depth 8
