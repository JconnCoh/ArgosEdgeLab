#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$requestId='REQ_20260826T015418549Z_F5D3732576F9'
$inboxRoot='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod'
$stateRoot='C:\ProgramData\ArgosProjectPortalRO\state\transport_JBOD_REQUEST_RECEIVER'
if($Preflight){[ordered]@{schema='argos_o2d10_jbod_inbox_transport_preflight_v1';state='PASS_O2D10_JBOD_INBOX_TRANSPORT_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
$roots=@($inboxRoot,$stateRoot)
$rootRows=@(foreach($root in $roots){
  $immediate=@();$exact=@();$texts=@()
  if(Test-Path -LiteralPath $root -PathType Container){
    $immediate=@(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop|Select-Object -First 64 Name,FullName,PSIsContainer,Length,LastWriteTimeUtc)
    $exact=@(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction Stop|Where-Object{$_.Name.IndexOf($requestId,[StringComparison]::OrdinalIgnoreCase)-ge 0}|Select-Object -First 32 Name,FullName,PSIsContainer,Length,LastWriteTimeUtc)
    $texts=@(Get-ChildItem -LiteralPath $root -File -Force -ErrorAction Stop|Where-Object{$_.Length-le 131072 -and $_.Extension -in @('.json','.log','.txt')}|Select-Object -First 16|ForEach-Object{[pscustomobject]@{name=$_.Name;path=$_.FullName;length=$_.Length;lastWriteTimeUtc=$_.LastWriteTimeUtc;content=[IO.File]::ReadAllText($_.FullName)}})
  }
  [pscustomobject]@{root=$root;exists=(Test-Path -LiteralPath $root -PathType Container);immediate=$immediate;exactRequestRows=$exact;textFiles=$texts}
})
[ordered]@{schema='argos_o2d10_jbod_inbox_transport_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_JBOD_INBOX_TRANSPORT_OBSERVATION';computerName=$env:COMPUTERNAME;requestId=$requestId;roots=$rootRows;requestRetried=$false;queueMutationPerformed=$false;taskOrProcessActionPerformed=$false;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 12 -Compress|Set-Clipboard
