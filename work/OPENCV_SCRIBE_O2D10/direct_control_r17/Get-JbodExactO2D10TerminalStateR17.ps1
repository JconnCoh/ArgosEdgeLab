#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='C:\ProgramData\ArgosProjectPortalRO'
$requestId='REQ_20260826T015418549Z_F5D3732576F9'
$paths=@(
 (Join-Path $root "endpoint_jbod\receipts\$requestId.receipt.json"),
 (Join-Path $root "endpoint_jbod\state\ledger\$requestId.json"),
 (Join-Path $root 'config\endpoint_jbod.json'),
 (Join-Path $root 'config\JBOD_RESPONSE_SENDER.json')
)
if($Preflight){[ordered]@{schema='argos_o2d10_jbod_terminal_state_preflight_v1';state='PASS_O2D10_JBOD_TERMINAL_STATE_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
$files=@(foreach($path in $paths){if(Test-Path -LiteralPath $path -PathType Leaf){$item=Get-Item -LiteralPath $path;[pscustomobject]@{path=$path;length=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;content=if($item.Length-le 131072){[IO.File]::ReadAllText($path)}else{$null}}}else{[pscustomobject]@{path=$path;missing=$true}}})
$maintenanceRoot=Join-Path $root "endpoint_jbod\state\maintenance\$requestId"
$maintenanceRows=@()
if(Test-Path -LiteralPath $maintenanceRoot -PathType Container){$maintenanceRows=@(Get-ChildItem -LiteralPath $maintenanceRoot -Recurse -Force -ErrorAction Stop|Select-Object -First 96|ForEach-Object{[pscustomobject]@{name=$_.Name;path=$_.FullName;isContainer=$_.PSIsContainer;length=if($_.PSIsContainer){$null}else{$_.Length};lastWriteTimeUtc=$_.LastWriteTimeUtc;sha256=if(-not $_.PSIsContainer){(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}else{$null};content=if(-not $_.PSIsContainer -and $_.Length-le 131072 -and $_.Extension -in @('.json','.log','.txt')){[IO.File]::ReadAllText($_.FullName)}else{$null}}})}
$recentEndpointRows=@(Get-ChildItem -LiteralPath (Join-Path $root 'endpoint_jbod') -Recurse -Force -ErrorAction Stop|Where-Object{$_.LastWriteTimeUtc-ge [DateTime]::Parse('2026-08-26T19:01:00Z')}|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 96 Name,FullName,PSIsContainer,Length,LastWriteTimeUtc)
[ordered]@{schema='argos_o2d10_jbod_terminal_state_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_JBOD_TERMINAL_STATE_OBSERVATION';computerName=$env:COMPUTERNAME;requestId=$requestId;files=$files;maintenanceRows=$maintenanceRows;recentEndpointRows=$recentEndpointRows;requestRetried=$false;queueMutationPerformed=$false;taskOrProcessActionPerformed=$false;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 12 -Compress|Set-Clipboard
