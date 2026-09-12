#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Need([bool]$Value,[string]$Message){if(-not$Value){throw $Message}}
function Sha([string]$Path){(Get-FileHash -Algorithm SHA256 -LiteralPath $Path -ErrorAction Stop).Hash}
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$oldGatePath=Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3F15L4E3\final_o3f15l4e3\O3F15L4E3_PREPUBLICATION_PATH_R4_GATE.json';$oldGateHash='94B829E7EAEB852F6CAB6EABA68CCD68B950DC2BB3C69B07607A8E1469B9E6DB'
$signGatePath=Join-Path $PSScriptRoot 'O3F16R28G1_SIGN_GATE.json';$outputPath=Join-Path $PSScriptRoot 'final_o3f16r28g1\O3F16R28G1_PREPUBLICATION_PATH_GATE.json'
foreach($path in @($oldGatePath,$signGatePath)){Need (Test-Path -LiteralPath $path -PathType Leaf) "Route dependency absent: $path"};Need ((Sha $oldGatePath)-eq$oldGateHash) 'Inherited route gate bytes changed'
$old=Get-Content -Raw -LiteralPath $oldGatePath|ConvertFrom-Json;$sign=Get-Content -Raw -LiteralPath $signGatePath|ConvertFrom-Json
Need ([string]$old.state-eq'PASS_O3F15L4E3_COMPLETE_ROUTE_PATH_R4_GATE') 'Inherited route gate state changed';Need ([string]$sign.state-eq'PASS_O3F16R28G1_SIGNED_FRONT24_PACKAGE'-and[int]$sign.payloadFileCount-eq33) 'Target sign gate changed'
$manifestPath=[string]$sign.packagePath+'\PORTAL_REQUEST_MANIFEST.json';$signaturePath=[string]$sign.packagePath+'\PORTAL_REQUEST_MANIFEST.sig';Need ((Sha $manifestPath)-eq[string]$sign.manifestSha256-and(Sha $signaturePath)-eq[string]$sign.signatureSha256) 'Signed manifest or signature changed'
$manifest=Get-Content -Raw -LiteralPath $manifestPath|ConvertFrom-Json;Need (@($manifest.files).Count-eq33) 'Signed payload cardinality changed'
$oldId=[string]$old.requestId;$newId=[string]$sign.requestId;$rows=New-Object Collections.Generic.List[object];$payloadParents=@{}
foreach($row in @($old.routePaths)){$path=([string]$row.path).Replace($oldId,$newId).Replace('O3F15L4E3','O3F16R28G1').Replace('o3f15l4e3','o3f16r28g1');$match=[regex]::Match($path,'(?i)^(.*[\\/]payload[\\/])[^\\/]+$');if($match.Success){$key=[string]$row.stage+'|'+$match.Groups[1].Value;$payloadParents[$key]=[pscustomobject]@{stage=[string]$row.stage;prefix=$match.Groups[1].Value}}else{$rows.Add([pscustomobject]@{stage=[string]$row.stage;path=$path})}}
Need ($payloadParents.Count-eq11) 'Inherited payload route-stage count changed'
foreach($parent in @($payloadParents.Values)){foreach($file in @($manifest.files)){$relative=([string]$file.path).Replace('/','\');$leaf=Split-Path -Leaf $relative;$rows.Add([pscustomobject]@{stage=[string]$parent.stage;path=[string]$parent.prefix+$leaf})}}
$semantic=$rows.ToArray();$normalized=@($semantic|ForEach-Object{[IO.Path]::GetFullPath([string]$_.path)}|Sort-Object -Unique)
$budget=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $normalized -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json;Need ([string]$budget.state-eq'PASS_PATH_BUDGET') 'Complete route path budget failed'
$measure=@{};foreach($candidate in @($budget.candidates)){$measure[[IO.Path]::GetFullPath([string]$candidate.path)]=$candidate}
$finalRows=@($semantic|ForEach-Object{$key=[IO.Path]::GetFullPath([string]$_.path);$m=$measure[$key];Need ($null-ne$m) "Route measurement absent: $key";[pscustomobject]@{stage=[string]$_.stage;path=$key;rawLength=[int]$m.pathLength;effectiveLength=[int]$m.effectiveLength;maximumComponentLength=[int]$m.longestComponentLength;disposition=[string]$m.disposition}})
$maxRow=$finalRows|Sort-Object effectiveLength -Descending|Select-Object -First 1;Need ([int]$maxRow.effectiveLength-lt200) 'Route effective path reached 200';Need (@($finalRows|Where-Object{[int]$_.maximumComponentLength-gt80}).Count-eq0) 'Route component exceeds 80'
$result=[ordered]@{schema='argos_ocv03_o3f16r28g1_complete_route_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F16R28G1_COMPLETE_ROUTE_PATH_GATE';lifecycle=$(if($Preflight){'DRAFT'}else{'FROZEN'});requestId=$newId;manifestSha256=[string]$sign.manifestSha256;signatureSha256=[string]$sign.signatureSha256;installedRouteRevision='O3F15L4E3_R4_INHERITED_BY_O3F8R13T5';endpointWorkerSha256=[string]$sign.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$sign.installedRouteConfigEvidenceSha256;inheritedQueueSafetyGateSha256=[string]$sign.queueSafetyGateSha256;completeRouteGateSha256=[string]$sign.completeRouteGateSha256;routeImplementationChanged=$false;payloadFileCount=33;routePathCount=$finalRows.Count;maximumEffectiveLength=[int]$maxRow.effectiveLength;maximumComponentLength=($finalRows|Measure-Object maximumComponentLength -Maximum).Maximum;reservedSuffixCharacters=32;routePaths=$finalRows;disposition='PASS';published=$false;targetExecuted=$false;reviewOnly=$true}
if($Preflight){$result.state='PASS_O3F16R28G1_COMPLETE_ROUTE_PATH_PREFLIGHT';$result|ConvertTo-Json -Depth 8;return}
Need (-not(Test-Path -LiteralPath $outputPath)) "Create-new route gate exists: $outputPath";[IO.File]::WriteAllText($outputPath,(($result|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)));$result|ConvertTo-Json -Depth 8
