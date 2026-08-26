param([switch]$Preflight)
$ErrorActionPreference='Stop'
if($Preflight){[ordered]@{schema='argos_o2a3_processor_task_observation_preflight_v1';state='PASS_O2A3_PROCESSOR_TASK_OBSERVATION_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
$n='ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2'
$t=Get-ScheduledTask -TaskPath '\' -TaskName $n -ErrorAction Stop
$i=Get-ScheduledTaskInfo -TaskPath '\' -TaskName $n -ErrorAction Stop
$x=[string](Export-ScheduledTask -TaskPath '\' -TaskName $n -ErrorAction Stop)
$s=[Security.Cryptography.SHA256]::Create()
try{$xh=([BitConverter]::ToString($s.ComputeHash([Text.Encoding]::UTF8.GetBytes($x)))).Replace('-','')}finally{$s.Dispose()}
$cp='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\PROCESSOR_CONFIG.json'
$c=Get-Item -LiteralPath $cp -ErrorAction Stop
[ordered]@{schema='argos_o2a3_processor_task_observation_v1';state='PASS_O2A3_PROCESSOR_TASK_OBSERVATION';computerName=$env:COMPUTERNAME;task=[ordered]@{taskPath=$t.TaskPath;taskName=$t.TaskName;state=[string]$t.State;principal=[ordered]@{userId=$t.Principal.UserId;logonType=[string]$t.Principal.LogonType;runLevel=[string]$t.Principal.RunLevel};actions=@($t.Actions|ForEach-Object{[ordered]@{execute=$_.Execute;arguments=$_.Arguments;workingDirectory=$_.WorkingDirectory}});lastRunTime=$i.LastRunTime.ToUniversalTime().ToString('o');lastTaskResult=[int64]$i.LastTaskResult;nextRunTime=$i.NextRunTime.ToUniversalTime().ToString('o');taskXmlSha256=$xh};processorConfig=[ordered]@{path=$c.FullName;bytes=[int64]$c.Length;sha256=(Get-FileHash -LiteralPath $c.FullName -Algorithm SHA256).Hash};imageBytesRead=$false;taskOrProcessRestarted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 7
