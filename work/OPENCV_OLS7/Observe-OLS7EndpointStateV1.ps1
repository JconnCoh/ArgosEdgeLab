$ErrorActionPreference='Stop'
$s='argos_ols7_endpoint_state_observation_v1'
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$id='REQ_20260911T130501848Z_E64F5EE1B952'
$cp='C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json'
$c=Get-Content -LiteralPath $cp -Raw|ConvertFrom-Json
if([string]$c.schema-cne'argos_project_portal_endpoint_config_v1'){throw 'Config identity changed'}
$p=Join-Path ([string]$c.incomingRoot) ($id+'.ready')
$l=Join-Path ([string]$c.stateRoot) ('ledger\'+$id+'.json')
$m=Join-Path ([string]$c.stateRoot) ('maintenance\'+$id)
$o='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_OLS7_THREE_LOT_INVENTORY.json'
$g=$null
if(Test-Path -LiteralPath $l -PathType Leaf){
$i=Get-Item -LiteralPath $l;if($i.Length-gt 1048576){throw 'Oversize ledger'}
$j=Get-Content -LiteralPath $l -Raw|ConvertFrom-Json
$g=@{state=$j.state;processedUtc=$j.processedUtc;responsePackage=$j.responsePackage;responseExists=[bool](Test-Path -LiteralPath ([string]$j.responsePackage) -PathType Container)}
}
$a=@()
foreach($n in @('completed','failed','replayed')){$q=Join-Path (Join-Path ([string]$c.processedRoot) $n) ($id+'.ready');$a+=@{state=$n;exists=[bool](Test-Path -LiteralPath $q -PathType Container)}}
$z=$null
if(Test-Path -LiteralPath $o -PathType Leaf){$i=Get-Item -LiteralPath $o;if($i.Length-gt 33554432){throw 'Oversize output'};$j=Get-Content -LiteralPath $o -Raw|ConvertFrom-Json;$z=@{state=$j.state;targetCount=$j.targetCount;completedTargetCount=$j.completedTargetCount}}
$r=@{schema=$s;state='PASS_OLS7_ENDPOINT_STATE_OBSERVATION';pending=[bool](Test-Path -LiteralPath $p -PathType Container);ledger=$g;archives=$a;maintenanceRoot=[bool](Test-Path -LiteralPath $m -PathType Container);output=$z;mutationsPerformed=$false}
}catch{$e=[string]$_.Exception.Message;if($e.Length-gt 500){$e=$e.Substring(0,500)};$r=@{schema=$s;state='FAIL_OLS7_ENDPOINT_STATE_OBSERVATION';errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$false}}
$r|ConvertTo-Json -Compress -Depth 8|clip.exe
