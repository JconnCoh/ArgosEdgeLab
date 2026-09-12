$ErrorActionPreference='Stop'
$expected='A1025645101'
if($env:COMPUTERNAME-ne$expected){throw "HOST_MISMATCH:$($env:COMPUTERNAME)"}
$taskName='ArgosProjectPortal.JBOD.ResponseSender.RO'
$t=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
$i=Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
$p='C:\ProgramData\ArgosProjectPortalRO\to_argos\pending'
$s='C:\ProgramData\ArgosProjectPortalRO\to_argos\sent'
$target='R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$pending=@(Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop)
$sent=@(Get-ChildItem -LiteralPath $s -Force -ErrorAction Stop)
$a=@($t.Actions|ForEach-Object{[ordered]@{execute=$_.Execute;arguments=$_.Arguments;workingDirectory=$_.WorkingDirectory}})
[ordered]@{
 schema='argos_ols7_response_sender_observation_v1'
 state='PASS_OLS7_RESPONSE_SENDER_OBSERVATION'
 computerName=$env:COMPUTERNAME
 task=[ordered]@{name=$taskName;state=[string]$t.State;enabled=[bool]$t.Settings.Enabled;lastRunTime=$i.LastRunTime.ToUniversalTime().ToString('o');lastTaskResult=[int64]$i.LastTaskResult;nextRunTime=$i.NextRunTime.ToUniversalTime().ToString('o');missedRuns=[int]$i.NumberOfMissedRuns;actions=$a}
 queue=[ordered]@{pendingCount=$pending.Count;sentCount=$sent.Count;targetPending=Test-Path -LiteralPath (Join-Path $p $target);targetSent=Test-Path -LiteralPath (Join-Path $s $target);oldestPending=@($pending|Sort-Object CreationTimeUtc|Select-Object -First 5|ForEach-Object{[ordered]@{name=$_.Name;createdUtc=$_.CreationTimeUtc.ToString('o');lastWriteUtc=$_.LastWriteTimeUtc.ToString('o')}})}
 mutationsPerformed=$false
}|ConvertTo-Json -Compress -Depth 7
