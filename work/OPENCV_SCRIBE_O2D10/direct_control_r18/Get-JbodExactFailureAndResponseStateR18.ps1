#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='C:\ProgramData\ArgosProjectPortalRO'
$workRoot=Join-Path $root 'endpoint_jbod\state\work\J_237A755E9434_310f4c9d'
$responseRoot=Join-Path $root 'to_argos\pending\R_AAB6C504C28E_20260826190116689_9f0ba1d4.ready'
$senderState=Join-Path $root 'state\transport_JBOD_RESPONSE_SENDER'
if($Preflight){[ordered]@{schema='argos_o2d10_jbod_failure_response_preflight_v1';state='PASS_O2D10_JBOD_FAILURE_RESPONSE_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
$readPaths=@((Join-Path $workRoot 'FAILURE.json'),(Join-Path $workRoot 'MAINTENANCE.stderr.txt'),(Join-Path $workRoot 'MAINTENANCE.stdout.txt'),(Join-Path $senderState 'STATUS.json'))
$files=@(foreach($path in $readPaths){if(Test-Path -LiteralPath $path -PathType Leaf){$item=Get-Item -LiteralPath $path;[pscustomobject]@{path=$path;length=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;content=if($item.Length-le 131072){[IO.File]::ReadAllText($path)}else{$null}}}else{[pscustomobject]@{path=$path;missing=$true}}})
$responseRows=@()
if(Test-Path -LiteralPath $responseRoot -PathType Container){$responseRows=@(Get-ChildItem -LiteralPath $responseRoot -Recurse -Force -ErrorAction Stop|Select-Object -First 64|ForEach-Object{[pscustomobject]@{name=$_.Name;path=$_.FullName;isContainer=$_.PSIsContainer;length=if($_.PSIsContainer){$null}else{$_.Length};sha256=if(-not $_.PSIsContainer){(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}else{$null};content=if(-not $_.PSIsContainer -and $_.Length-le 131072 -and $_.Extension -in @('.json','.txt','.log')){[IO.File]::ReadAllText($_.FullName)}else{$null}}})}
$senderLogTail=@();$senderLog=Join-Path $senderState 'relay.log';if(Test-Path -LiteralPath $senderLog -PathType Leaf){$senderLogTail=@(Get-Content -LiteralPath $senderLog -Tail 30 -ErrorAction Stop)}
$tcp48717=@(Get-NetTCPConnection -RemotePort 48717 -ErrorAction SilentlyContinue|Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess)
[ordered]@{schema='argos_o2d10_jbod_failure_response_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_JBOD_FAILURE_RESPONSE_OBSERVATION';computerName=$env:COMPUTERNAME;files=$files;responseRoot=$responseRoot;responseRows=$responseRows;senderLogTail=$senderLogTail;tcp48717=$tcp48717;requestRetried=$false;queueMutationPerformed=$false;taskOrProcessActionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 12 -Compress|Set-Clipboard
