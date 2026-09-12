$ErrorActionPreference='Stop'
$s='argos_ols7_response_sender_observation_v5'
try{
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong host'}
$n='ArgosProjectPortal.JBOD.ResponseSender.RO'
$p='C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$q='C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\R_4165D2AA78E1_20260911165403415_1688d84f.ready'
$t=@(Get-ScheduledTask -TaskName $n -ErrorAction Stop)
if($t.Count-ne1){throw'Task cardinality changed'}
$i=Get-ScheduledTaskInfo -TaskName $n -ErrorAction Stop
$a=(($t[0].Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"})-join' ')
$r=[ordered]@{schema=$s;state='PASS_OLS7_RESPONSE_SENDER_OBSERVATION';computerName=$env:COMPUTERNAME;task=[ordered]@{name=$n;state=[string]$t[0].State;principal=[string]$t[0].Principal.UserId;lastRunUtc=$i.LastRunTime.ToUniversalTime().ToString('o');lastTaskResult=[int64]$i.LastTaskResult;action=$a};targetPending=Test-Path -LiteralPath $p -PathType Container;targetSent=Test-Path -LiteralPath $q -PathType Container;mutationsPerformed=$false}
}catch{$e=[string]$_.Exception.Message;if($e.Length-gt300){$e=$e.Substring(0,300)};$r=[ordered]@{schema=$s;state='FAIL_OLS7_RESPONSE_SENDER_OBSERVATION';errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$false}}
$r|ConvertTo-Json -Compress -Depth 6|clip.exe
