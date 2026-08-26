#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($Preflight){[ordered]@{schema='argos_o2d10_jbod_tiny_failure_preflight_v1';state='PASS_O2D10_JBOD_TINY_FAILURE_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
try{
 $base='C:\ProgramData\ArgosProjectPortalRO'
 $work=Join-Path $base 'endpoint_jbod\state\work\J_237A755E9434_310f4c9d'
 $paths=@((Join-Path $work 'FAILURE.json'),(Join-Path $work 'MAINTENANCE.stderr.txt'),(Join-Path $base 'state\transport_JBOD_RESPONSE_SENDER\STATUS.json'))
 $files=@(foreach($path in $paths){$item=Get-Item -LiteralPath $path -ErrorAction Stop;if($item.Length-gt 4096){throw "Tiny-file limit exceeded: $path"};[pscustomobject]@{path=$path;length=$item.Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;content=[IO.File]::ReadAllText($path)}})
 [ordered]@{schema='argos_o2d10_jbod_tiny_failure_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_JBOD_TINY_FAILURE_OBSERVATION';computerName=$env:COMPUTERNAME;files=$files;requestRetried=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8 -Compress|Set-Clipboard
}catch{[ordered]@{schema='argos_o2d10_jbod_tiny_failure_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_O2D10_JBOD_TINY_FAILURE_OBSERVATION';computerName=$env:COMPUTERNAME;errorType=$_.Exception.GetType().FullName;errorMessage=$_.Exception.Message;requestRetried=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress|Set-Clipboard}
