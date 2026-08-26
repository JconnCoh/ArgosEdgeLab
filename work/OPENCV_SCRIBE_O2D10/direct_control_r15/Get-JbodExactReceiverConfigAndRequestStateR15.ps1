#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$configPath='C:\ProgramData\ArgosProjectPortalRO\config\JBOD_REQUEST_RECEIVER.json'
$requestId='REQ_20260826T015418549Z_F5D3732576F9'
if($Preflight){[ordered]@{schema='argos_o2d10_jbod_receiver_config_request_preflight_v1';state='PASS_O2D10_JBOD_RECEIVER_CONFIG_REQUEST_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
function Add-StringValues([object]$Value,[string]$PropertyPath,[Collections.Generic.List[object]]$Rows){
    if($null -eq $Value){return}
    if($Value -is [string]){$Rows.Add([pscustomobject]@{propertyPath=$PropertyPath;value=[string]$Value});return}
    if($Value -is [Collections.IEnumerable] -and $Value -isnot [Management.Automation.PSCustomObject]){$i=0;foreach($item in $Value){Add-StringValues $item ($PropertyPath+'['+$i+']') $Rows;$i++};return}
    foreach($property in $Value.PSObject.Properties){$next=if([string]::IsNullOrWhiteSpace($PropertyPath)){$property.Name}else{$PropertyPath+'.'+$property.Name};Add-StringValues $property.Value $next $Rows}
}
$raw=[IO.File]::ReadAllText($configPath)
$config=$raw|ConvertFrom-Json
$strings=New-Object 'Collections.Generic.List[object]'
Add-StringValues $config '' $strings
$pathRows=New-Object 'Collections.Generic.List[object]'
foreach($row in $strings.ToArray()){
    $value=[string]$row.value
    if(-not [IO.Path]::IsPathRooted($value)){continue}
    if($value -notlike 'C:\ProgramData\ArgosProjectPortalRO*' -and $value -notlike 'D:\A2*'){continue}
    $exists=Test-Path -LiteralPath $value
    $matches=@()
    if($exists -and (Test-Path -LiteralPath $value -PathType Container)){$matches=@(Get-ChildItem -LiteralPath $value -Force -ErrorAction Stop|Where-Object{$_.Name.IndexOf($requestId,[StringComparison]::OrdinalIgnoreCase)-ge 0}|Select-Object -First 16 Name,FullName,PSIsContainer,Length,LastWriteTimeUtc)}
    $pathRows.Add([pscustomobject]@{propertyPath=$row.propertyPath;path=$value;exists=$exists;exactRequestMatches=$matches})
}
$taskStateRoot='C:\ProgramData\ArgosProjectPortalRO\state\task_hosts\ArgosProjectPortal.JBOD.RequestReceiver.RO'
$stateFiles=@()
if(Test-Path -LiteralPath $taskStateRoot -PathType Container){$stateFiles=@(Get-ChildItem -LiteralPath $taskStateRoot -File -Force -ErrorAction Stop|Select-Object -First 16 Name,FullName,Length,LastWriteTimeUtc)}
[ordered]@{schema='argos_o2d10_jbod_receiver_config_request_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_JBOD_RECEIVER_CONFIG_REQUEST_OBSERVATION';computerName=$env:COMPUTERNAME;configSha256=(Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash;configRaw=$raw;configStrings=$strings.ToArray();boundedConfiguredPaths=$pathRows.ToArray();receiverTaskStateFiles=$stateFiles;requestRetried=$false;queueMutationPerformed=$false;taskOrProcessActionPerformed=$false;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 10 -Compress|Set-Clipboard
