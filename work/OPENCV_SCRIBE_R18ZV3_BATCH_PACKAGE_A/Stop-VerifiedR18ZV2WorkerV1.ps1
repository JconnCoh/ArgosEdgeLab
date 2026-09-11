param([switch]$Preflight)
$ErrorActionPreference='Stop'
$s='argos_r18zv2_verified_worker_stop_v1';$stage='START';$mutated=$false
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$f='D:\A2\o\ocv\R18ZV2\LAUNCH.json';$stage='VERIFY_LAUNCH'
if(-not(Test-Path -LiteralPath $f -PathType Leaf)){throw 'Launch marker absent'}
if((Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash-cne'F908959F3B6D00A9DA30D5305E22ADA2996B17565D72577E9167060F9261231B'){throw 'Launch marker hash changed'}
$stage='VERIFY_PROCESS';$rows=@(Get-CimInstance Win32_Process -Filter 'ProcessId=35456')
if($rows.Count-ne1){throw 'Exact worker process count changed'}
$p=$rows[0];$cl=[string]$p.CommandLine
if([int]$p.ParentProcessId-ne9380-or[string]$p.Name-cne'python.exe'-or[string]$p.ExecutablePath-cne'D:\AFCV1\rt\python.exe'-or[string]$p.CreationDate-cne'09/11/2026 07:15:25'){throw 'Exact worker process identity changed'}
if($cl-notlike'*D:\A2\w\ocv\R18ZV2\OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTBatchExecutionEnvelope.py*'-or$cl-notlike'*D:\A2\o\ocv\R18ZV2*'){throw 'Exact worker command line changed'}
if(-not(Test-Path -LiteralPath 'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_RZV3.ready' -PathType Container)){throw 'R18ZV3 no longer pending'}
if($Preflight){$r=@{schema=$s;state='PASS_R18ZV2_VERIFIED_WORKER_STOP_PREFLIGHT';processId=35456;mutationsPerformed=$false}}
else{$stage='STOP_EXACT_WORKER';Stop-Process -Id 35456 -Force;$mutated=$true;for($n=0;$n-lt12-and(Get-Process -Id 35456 -ErrorAction SilentlyContinue);$n++){Start-Sleep -Milliseconds 250};if(Get-Process -Id 35456 -ErrorAction SilentlyContinue){throw 'Exact worker remains'};$r=@{schema=$s;state='PASS_R18ZV2_VERIFIED_WORKER_STOP';processId=35456;mutationsPerformed=$true}}
}catch{$e=[string]$_.Exception.Message;if($e.Length-gt500){$e=$e.Substring(0,500)};$r=@{schema=$s;state='FAIL_R18ZV2_VERIFIED_WORKER_STOP';stage=$stage;errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$mutated}}
$r|ConvertTo-Json -Compress -Depth 6|clip.exe
