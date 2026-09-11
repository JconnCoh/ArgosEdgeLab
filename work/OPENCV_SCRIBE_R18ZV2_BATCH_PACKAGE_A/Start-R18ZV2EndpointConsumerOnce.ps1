$ErrorActionPreference='Stop'
$s='argos_r18zv2_task_start_once_v1';$m=$false;$g='preflight'
try{
$n='ArgosProjectPortal.JBOD.Endpoint.RO'
$p='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_RZV2.ready'
$l='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\REQ_RZV2.json'
$o='D:\A2\o\ocv\R18ZV2'
$w='C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
$c='C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json'
if(!(Test-Path -LiteralPath $p -PathType Container)){throw'Pending request absent'}
if((Test-Path -LiteralPath $l)-or(Test-Path -LiteralPath $o)){throw'Request already advanced'}
if((Get-FileHash $w -Algorithm SHA256).Hash-ne'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'){throw'Worker hash mismatch'}
if((Get-FileHash $c -Algorithm SHA256).Hash-ne'55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'){throw'Config hash mismatch'}
$a=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(!$a){throw'Administrator required'}
$t=Get-ScheduledTask -TaskName $n -ErrorAction Stop
if(@($t).Count-ne1-or[string]$t.State-ne'Ready'){throw"Task not singular Ready: $($t.State)"}
$x=(($t.Actions|%{"$($_.Execute) $($_.Arguments)"})-join' ')
if($x-notmatch'Invoke-ArgosProjectPortalEndpointWorker\.ps1.*endpoint_jbod\.json'){throw'Task action mismatch'}
$g='start_once';$m=$true;Start-ScheduledTask -TaskName $n -ErrorAction Stop
Start-Sleep 5;$t=Get-ScheduledTask -TaskName $n
$r=@{schema=$s;state='PASS_R18ZV2_ENDPOINT_TASK_STARTED_ONCE';taskState=[string]$t.State;mutationsPerformed=$m}
}catch{$e=[string]$_.Exception.Message;if($e.Length-gt300){$e=$e.Substring(0,300)};$r=@{schema=$s;state='FAIL_R18ZV2_ENDPOINT_TASK_START_ONCE';stage=$g;errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$m}}
$r|ConvertTo-Json -Compress -Depth 6|clip.exe
