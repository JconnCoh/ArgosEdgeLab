$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-ne'A1025645101'){throw "HOST_MISMATCH:$($env:COMPUTERNAME)"}
$n='ArgosProjectPortal.JBOD.ResponseSender.RO'
$p='C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$s='C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$t=Get-ScheduledTask -TaskName $n -ErrorAction Stop
$i=Get-ScheduledTaskInfo -TaskName $n -ErrorAction Stop
$a=@($t.Actions|ForEach-Object{[ordered]@{execute=$_.Execute;arguments=$_.Arguments;workingDirectory=$_.WorkingDirectory}})
[ordered]@{
 schema='argos_ols7_response_sender_observation_v2'
 state='PASS_OLS7_RESPONSE_SENDER_OBSERVATION'
 computerName=$env:COMPUTERNAME
 task=[ordered]@{state=[string]$t.State;enabled=[bool]$t.Settings.Enabled;lastRunTime=$i.LastRunTime.ToUniversalTime().ToString('o');lastTaskResult=[int64]$i.LastTaskResult;nextRunTime=$i.NextRunTime.ToUniversalTime().ToString('o');missedRuns=[int]$i.NumberOfMissedRuns;actions=$a}
 target=[ordered]@{pending=Test-Path -LiteralPath $p;sent=Test-Path -LiteralPath $s}
 mutationsPerformed=$false
}|ConvertTo-Json -Compress -Depth 6
