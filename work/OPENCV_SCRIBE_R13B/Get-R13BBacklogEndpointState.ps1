[CmdletBinding()]param([switch]$Preflight)
$ErrorActionPreference='Stop'
if($Preflight){@{state='PASS_R13B_BACKLOG_PAYLOAD_PREFLIGHT';mutationsPerformed=$false}|ConvertTo-Json -Compress;return}
$ids=@('REQ_20260902T001500111Z_62619433S22M','REQ_20260902T002400222Z_62619433S22P','REQ_20260902T003000333Z_62619433S22S')
$b='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod'
$loc=@('pending','processed\completed','processed\failed','processed\replayed')
$rows=@()
foreach($id in $ids){foreach($l in $loc){$p=Join-Path (Join-Path $b $l) ($id+'.ready');$x=Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue;if($x){$rows+=@{requestId=$id;kind=$l;path=$p;lastWriteUtc=$x.LastWriteTimeUtc.ToString('o')}}}}
foreach($d in @(Get-ChildItem -LiteralPath (Join-Path $b 'state\work') -Directory -Force -ErrorAction SilentlyContinue|Select-Object -First 64)){$p=Join-Path $d.FullName 'package\PORTAL_REQUEST_MANIFEST.json';$x=Get-Item -LiteralPath $p -ErrorAction SilentlyContinue;if($x -and $x.Length -le 1048576){$m=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json;if($ids -ccontains [string]$m.requestId){$rows+=@{requestId=[string]$m.requestId;kind='state\work';path=$d.FullName;lastWriteUtc=$d.LastWriteTimeUtc.ToString('o')}}}}
foreach($d in @(Get-ChildItem -LiteralPath (Join-Path $b 'state\response_quarantine') -Directory -Force -ErrorAction SilentlyContinue|Select-Object -First 64)){$p=Join-Path $d.FullName 'PORTAL_RESPONSE_MANIFEST.json';$x=Get-Item -LiteralPath $p -ErrorAction SilentlyContinue;if($x -and $x.Length -le 1048576){$m=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json;if($ids -ccontains [string]$m.requestId){$rows+=@{requestId=[string]$m.requestId;kind='response_quarantine';path=$d.FullName;responseId=[string]$m.responseId;state=[string]$m.state}}}}
@{state='PASS_R13B_EXACT_BACKLOG_ENDPOINT_OBSERVATION';computerName=$env:COMPUTERNAME;requestIds=$ids;rows=$rows;rowCount=$rows.Count;mutationsPerformed=$false}|ConvertTo-Json -Compress -Depth 5
