[CmdletBinding()]param([switch]$Preflight)
$ErrorActionPreference='Stop'
$s='argos_ols7_response_sender_start_once_v2';$m=$false;$g='preflight'
if($Preflight){@{schema=$s;state='PASS_OLS7_RESPONSE_SENDER_START_ONCE_PREFLIGHT';targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress;return}
try{
if($env:COMPUTERNAME-ne'A1025645101'){throw 'Wrong host'}
$n='ArgosProjectPortal.JBOD.ResponseSender.RO';$b='C:\ProgramData\ArgosProjectPortalRO'
$x='R_4165D2AA78E1_20260911165403415_1688d84f.ready';$p=Join-Path "$b\to_argos\pending" $x;$q=Join-Path "$b\to_argos\sent" $x
if(!(Test-Path $p -PathType Container)-or(Test-Path $q)){throw 'Response state changed'}
$h=@{"$b\config\JBOD_RESPONSE_SENDER.json"='8420A302D0EE0665E9E034448A245613C6AD5E7EE2D82BF0E7F962A7F7B104E0';"$b\bin\ArgosProjectPortal.Transport.ReviewOnly.V1.exe"='843629F44D8C310FAE201EAD808509FBECF3FC3C04D8D16B0D67CCADEFAE2DDB';"$b\bin\Invoke-ProjectPortalTaskHost.ps1"='2D77E8E973B86E789C3A54702550B2A67E80E1E7EBB0AF51575F69ACEB157253'}
foreach($k in $h.Keys){if((Get-FileHash $k -Algorithm SHA256).Hash-ne$h[$k]){throw "Hash changed: $k"}}
$t=@(Get-ScheduledTask -TaskName $n);if($t.Count-ne1-or[string]$t[0].State-ne'Ready'-or[string]$t[0].Principal.UserId-ne'SYSTEM'){throw 'Task premise changed'}
$a=(($t[0].Actions|%{"$($_.Execute) $($_.Arguments)"})-join' ');if($a-notmatch'ArgosProjectPortal\.Transport\.ReviewOnly\.V1\.exe'-or$a-notmatch'SkJPRF9SRVNQT05TRV9TRU5ERVI'){throw 'Task action changed'}
$g='start_once';$m=$true;Start-ScheduledTask -TaskName $n -ErrorAction Stop
Start-Sleep 5;$r=@{schema=$s;state='PASS_OLS7_RESPONSE_SENDER_STARTED_ONCE';taskState=[string](Get-ScheduledTask -TaskName $n).State;targetPending=Test-Path $p;targetSent=Test-Path $q;mutationsPerformed=$m}
}catch{$e=[string]$_.Exception.Message;if($e.Length-gt300){$e=$e.Substring(0,300)};$r=@{schema=$s;state='FAIL_OLS7_RESPONSE_SENDER_START_ONCE';stage=$g;errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$m}}
$r|ConvertTo-Json -Compress|clip.exe
