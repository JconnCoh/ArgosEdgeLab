$ErrorActionPreference='Stop'
$s='argos_r18zv2_endpoint_consumer_observation_v1'
try{
$c='C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json'
$w='C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
foreach($p in @($c,$w)){if(!(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing $p"}}
$ci=Get-Item -LiteralPath $c;$wi=Get-Item -LiteralPath $w
$ts=@(Get-ScheduledTask -ErrorAction Stop|Where-Object{(($_.Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"})-join' ') -match 'Invoke-ArgosProjectPortalEndpointWorker|endpoint_jbod\.json'})
if($ts.Count -gt 5){throw "Too many matching tasks: $($ts.Count)"}
$rows=@()
foreach($t in $ts){
$i=$t|Get-ScheduledTaskInfo
$a=(($t.Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"})-join' ')
if($a.Length -gt 600){$a=$a.Substring(0,600)}
$rows+=@{taskPath=$t.TaskPath;taskName=$t.TaskName;state=[string]$t.State;lastRunTime=$i.LastRunTime.ToUniversalTime().ToString('o');lastTaskResult=$i.LastTaskResult;nextRunTime=$i.NextRunTime.ToUniversalTime().ToString('o');missedRuns=$i.NumberOfMissedRuns;action=$a}
}
$r=@{schema=$s;state='PASS_R18ZV2_ENDPOINT_CONSUMER_OBSERVATION';computerName=$env:COMPUTERNAME;config=@{bytes=$ci.Length;sha256=(Get-FileHash -LiteralPath $c -Algorithm SHA256).Hash};worker=@{bytes=$wi.Length;sha256=(Get-FileHash -LiteralPath $w -Algorithm SHA256).Hash};matchingTaskCount=$rows.Count;tasks=$rows;mutationsPerformed=$false}
}catch{
$e=[string]$_.Exception.Message;if($e.Length -gt 500){$e=$e.Substring(0,500)}
$r=@{schema=$s;state='FAIL_R18ZV2_ENDPOINT_CONSUMER_OBSERVATION';stage='bounded_read';errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$false}
}
$r|ConvertTo-Json -Compress -Depth 8|clip.exe
