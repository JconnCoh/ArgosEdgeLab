$ErrorActionPreference='Stop'
$s='argos_r18zw_endpoint_queue_observation_v1'
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$p='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending'
if(!(Test-Path -LiteralPath $p -PathType Container)){throw 'Endpoint pending root absent'}
$x=@(Get-ChildItem -LiteralPath $p -Force -ErrorAction Stop|Select-Object -First 65)
if($x.Count -gt 64){throw 'Endpoint pending count exceeds bounded observation limit'}
$n=@($x|ForEach-Object{$_.Name})
$r=@{schema=$s;checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18ZW_ENDPOINT_QUEUE_OBSERVATION';computerName=$env:COMPUTERNAME;pendingRequestCount=$x.Count;pendingRequestNames=$n;queueHeadClear=($x.Count-eq0);taskOrProcessMutationPerformed=$false;mutationsPerformed=$false}
}catch{
$e=[string]$_.Exception.Message;if($e.Length-gt500){$e=$e.Substring(0,500)}
$r=@{schema=$s;checkedUtc=[DateTime]::UtcNow.ToString('o');state='FAIL_R18ZW_ENDPOINT_QUEUE_OBSERVATION';stage='bounded_read';errorType=$_.Exception.GetType().FullName;errorMessage=$e;taskOrProcessMutationPerformed=$false;mutationsPerformed=$false}
}
$r|ConvertTo-Json -Compress -Depth 5|clip.exe
