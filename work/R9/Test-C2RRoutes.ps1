[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}
$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$work=Join-Path $project 'work\R9'
$requestId='REQ_R9'
$responseId='R_0123456789AB_20260820050505050_a1b2c3d4'
$jobId='J_0123456789AB_01234567'
$compactId='C_0123456789AB_01234567'
$portalRoot='C:\ProgramData\ArgosProjectPortalRO'
$portalState=Join-Path $portalRoot 'endpoint_jbod\state'
$laptopRoot='C:\R9S'
$definition=Get-Content -LiteralPath (Join-Path $work 'pkg\MAINTENANCE_DEFINITION.json') -Raw|ConvertFrom-Json
if(Test-Path -LiteralPath $laptopRoot){throw "C2R response root must be fresh: $laptopRoot"}
$paths=New-Object Collections.Generic.List[string]
function Add-Leaf([string]$Path){[void]$paths.Add($Path)}
function Short-Sha([string]$Text,[int]$Length){$s=[Security.Cryptography.SHA256]::Create();try{return (([BitConverter]::ToString($s.ComputeHash((New-Object Text.UTF8Encoding($false)).GetBytes($Text)))).Replace('-','')).Substring(0,$Length)}finally{$s.Dispose()}}
$requestLeaves=@('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload/C2R.ps1','payload/Run-JbodAllWaferProcessor.ps1')
$responseLeaves=@('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','MAINTENANCE.stdout.txt','MAINTENANCE.stderr.txt','RESULT.json','FAILURE.json')
foreach($leaf in $requestLeaves){Add-Leaf (Join-Path $work ('signed_short\'+$requestId+'.ready\'+$leaf.Replace('/','\')))}
foreach($path in @((Join-Path $work 'pkg\MAINTENANCE_DEFINITION.json'),(Join-Path $work ('final\'+$requestId+'.ready.zip')),(Join-Path $work ('final\'+$requestId+'.ready.zip.gate.json')),('U:\ProjectPortalRO\requests\'+$requestId+'.ready.zip.upload'),('U:\ProjectPortalRO\requests\'+$requestId+'.ready.zip'),('C:\APR\S\requests\'+$requestId+'.ready.zip'),('C:\APR\S\requests\processed\'+$requestId+'.ready.zip'),(Join-Path $portalRoot ('share\staging\'+$requestId+'.ready.zip')),(Join-Path $portalRoot ('share\request_archive\'+$requestId+'.ready.zip')))){Add-Leaf $path}
foreach($routeRoot in @((Join-Path $portalRoot ('requests_to_argos\pending\'+$requestId+'.ready')),(Join-Path $portalRoot ('requests_from_gateway\pending\'+$requestId+'.ready')),(Join-Path $portalRoot ('to_jbod\pending\'+$requestId+'.ready')),(Join-Path $portalRoot ('to_jbod\sent\'+$requestId+'.ready')),(Join-Path $portalRoot ('endpoint_jbod\pending\'+$requestId+'.ready')))){foreach($leaf in $requestLeaves){Add-Leaf (Join-Path $routeRoot $leaf.Replace('/','\'))}}
$workResult=Join-Path $portalState ('work\'+$jobId)
foreach($leaf in @('MAINTENANCE.stdout.txt','MAINTENANCE.stderr.txt','RESULT.json','FAILURE.json')){Add-Leaf (Join-Path $workResult $leaf)}
Add-Leaf (Join-Path $portalState ('compact\'+$compactId+'\FAILURE.json'))
Add-Leaf (Join-Path $portalState ('ledger\'+$requestId+'.json'))
$requestToken=Short-Sha $requestId 10;$index=0
foreach($change in @($definition.changes)){$destination=[IO.Path]::GetFullPath([string]$change.destination);$evidence=('M{0:D3}_{1}_{2}'-f$index,(Short-Sha $destination 10),$requestToken);$maintenance=Join-Path $portalState ('maintenance\'+$requestId);foreach($path in @($destination,(Join-Path $maintenance ('prior\'+$evidence+'.prior')),(Join-Path $maintenance ('prior\'+$evidence+'.atomic')),(Join-Path (Split-Path -Parent $destination) ('.'+$evidence+'.stage')),(Join-Path (Split-Path -Parent $destination) ('.'+$evidence+'.restore')),(Join-Path $maintenance ('failed_new\'+$evidence+'.rollback')),(Join-Path $maintenance ('failed_new\'+$evidence+'.created')))){Add-Leaf $path};$index++}
foreach($path in @(
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\PROCESSOR_CONFIG.json',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\SCRIBE_IDENTITY_QUEUE.json',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Run-JbodAllWaferProcessor.ps1',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Invoke-JbodAllWaferInventory.ps1',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Import-JbodLiveInsiteSnapshot.ps1',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\processor\PROCESSOR_STATUS.json',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\catalog\ALL_WAFER_CATALOG.json',
  'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\SCRIBE_IDENTITY_QUEUE.json',
  'D:\A2\m\verified\ACTIVE_VERIFIED_METADATA_OVERLAY.json',
  'D:\A2\o','D:\A2\d','D:\A2\c','D:\A2\m\verified'
)){Add-Leaf $path}
$responseRoots=@((Join-Path $portalState ('response_quarantine\'+$responseId+'.partial')),(Join-Path $portalRoot ('to_argos\pending\'+$responseId+'.partial')),(Join-Path $portalRoot ('to_argos\pending\'+$responseId+'.ready')),(Join-Path $portalRoot ('to_argos\sent\'+$responseId+'.ready')),(Join-Path $portalRoot ('from_jbod\pending\'+$responseId+'.ready')),(Join-Path $portalRoot ('to_gateway\pending\'+$responseId+'.ready')),(Join-Path $portalRoot ('to_gateway\sent\'+$responseId+'.ready')),('C:\APR\R\pending\'+$responseId+'.ready'),('C:\APR\A\'+$responseId+'.ready'),(Join-Path $laptopRoot ($responseId+'.ready')))
foreach($routeRoot in $responseRoots){foreach($leaf in $responseLeaves){Add-Leaf (Join-Path $routeRoot $leaf)}}
foreach($path in @((Join-Path $portalRoot ('share\response_zip_archive\'+$responseId+'.ready.zip')),('U:\ProjectPortalRO\responses\'+$responseId+'.ready.zip'),(Join-Path $laptopRoot ($responseId+'.ready.zip')))){Add-Leaf $path}
$budget=&(Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $paths.ToArray() -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$budget.state-ne'PASS_PATH_BUDGET'){throw 'C2R complete route path budget failed.'}
$rows=@($budget.candidates);$longest=@($rows|Sort-Object effectiveLength -Descending|Select-Object -First 1)[0]
$result=[ordered]@{schema='argos_r9_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9_COMPLETE_ROUTE_GATE';requestId=$requestId;requestManifestSha256='3174326BBA1813189BA2F6E4662B6DD95DDE7F68F8408FCEA91C47649E8A3FF6';routePathRowsEvaluated=$rows.Count;requestLeafCount=$requestLeaves.Count;responseLeafCount=$responseLeaves.Count;maintenanceChangeCount=@($definition.changes).Count;reservedSuffixCharacters=32;maximumPlannedEffectiveLength=[int]$longest.effectiveLength;maximumPlannedComponentLength=[int](($rows|Measure-Object longestComponentLength -Maximum).Maximum);longestPath=[string]$longest.path;installedRouteRootSetSha256='2D1DFA2D56F525395BE871B206EDD7649C77D1E1EA47B940332165E5F3F65BAE';transportRevisionSha256='843629F44D8C310FAE201EAD808509FBECF3FC3C04D8D16B0D67CCADEFAE2DDB';exactEndpointWorkerSha256='244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6';approvedMaintenanceRoots=@('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2');laptopResponseExtractionRoot=$laptopRoot;laptopResponseRootFreshAtFreeze=$true;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result.state='PASS_R9_COMPLETE_ROUTE_PREFLIGHT';$result|ConvertTo-Json -Depth 8;return}
[IO.File]::WriteAllText((Join-Path $work 'R9_COMPLETE_ROUTE_GATE.json'),(($result|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$result|ConvertTo-Json -Depth 8
