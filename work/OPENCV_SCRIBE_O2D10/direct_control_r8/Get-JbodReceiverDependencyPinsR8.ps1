#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$taskName='ArgosProjectPortal.JBOD.RequestReceiver.RO'
$root='C:\ProgramData\ArgosProjectPortalRO'
$paths=@(
    (Join-Path $root 'bin\ArgosProjectPortal.Transport.ReviewOnly.V1.exe'),
    (Join-Path $root 'bin\Invoke-ProjectPortalTaskHost.ps1'),
    (Join-Path $root 'config\JBOD_REQUEST_RECEIVER.json')
)
if($Preflight){[ordered]@{schema='argos_o2d10_jbod_receiver_dependency_pins_preflight_v1';state='PASS_O2D10_JBOD_RECEIVER_DEPENDENCY_PINS_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}

function Get-Sha([string]$Path){$s=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite);try{$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose()}}finally{$s.Dispose()}}
function Get-TextSha([string]$Text){$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash([Text.Encoding]::Unicode.GetBytes($Text)))).Replace('-','')}finally{$h.Dispose()}}

$files=@(foreach($path in $paths){[pscustomobject]@{path=$path;bytes=(Get-Item -LiteralPath $path).Length;sha256=Get-Sha $path}})
$task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
$taskXml=Export-ScheduledTask -TaskName $taskName -ErrorAction Stop
$processor=@(Get-CimInstance Win32_Process|Where-Object{[string]$_.CommandLine -match '(?i)AllWaferProcessorV2|Invoke-AllWaferProcessor'}|Select-Object -First 8 ProcessId,ParentProcessId,Name,CreationDate,CommandLine)
[ordered]@{
 schema='argos_o2d10_jbod_receiver_dependency_pins_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_JBOD_RECEIVER_DEPENDENCY_PINS'
 computerName=$env:COMPUTERNAME;taskName=$taskName;taskState=[string]$task.State;taskPrincipal=[string]$task.Principal.UserId
 taskXmlSha256=Get-TextSha $taskXml;files=$files;healthyProcessorRows=$processor
 imageBytesRead=$false;taskOrProcessActionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 7 -Compress|Set-Clipboard
