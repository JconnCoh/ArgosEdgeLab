$ErrorActionPreference='Stop'
function q($v){if(-not $v){throw 'R18ZT1_STOP_REFUSED_IDENTITY_MISMATCH'}}
$o='D:\A2\o\ocv\R18ZT1'
if(Test-Path -LiteralPath "$o\COMPLETE.json" -PathType Leaf){'{"state":"NO_ACTION_R18ZT1_ALREADY_COMPLETE"}';return}
if(Test-Path -LiteralPath "$o\FAILURE.json" -PathType Leaf){'{"state":"NO_ACTION_R18ZT1_ALREADY_FAILED"}';return}
q (Test-Path -LiteralPath "$o\LAUNCH.json" -PathType Leaf)
q (Test-Path -LiteralPath "$o\RUNNING.json" -PathType Leaf)
$l=Get-Content -LiteralPath "$o\LAUNCH.json" -Raw|ConvertFrom-Json
$r=Get-Content -LiteralPath "$o\RUNNING.json" -Raw|ConvertFrom-Json
q ([string]$l.state -ceq 'PASS_R18ZT_BATCH_WORKER_STARTED')
q ([string]$l.workRoot -ceq 'D:\A2\w\ocv\R18ZT1')
q ([string]$l.outputRoot -ceq $o)
q ([string]$r.state -ceq 'RUNNING_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY')
$i=[int]$l.processId
$p=Get-Process -Id $i -ErrorAction Stop
$s=$p.StartTime.ToUniversalTime().ToString('o')
q ($s -ceq [string]$l.processStartTimeUtc)
$e='D:\AFCV1\rt\python.exe'
q ($p.Path -ieq $e)
$c=[string](Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $i)).CommandLine
q ($c.Contains('D:\A2\w\ocv\R18ZT1\OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTBatchExecutionEnvelope.py'))
q ($c.Contains('D:\A2\w\ocv\R18ZT1\OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTExistingOrientedCrops.py'))
q ($c.Contains($o))
Stop-Process -Id $i -Force -ErrorAction Stop
for($a=0;$a -lt 50 -and (Get-Process -Id $i -ErrorAction SilentlyContinue);$a++){Start-Sleep -Milliseconds 200}
q (-not (Get-Process -Id $i -ErrorAction SilentlyContinue))
[pscustomobject]@{state='PASS_R18ZT1_EXACT_OWNED_WORKER_STOPPED';processId=$i;processStartTimeUtc=$s;executable=$e;otherProcessMutationCount=0}|ConvertTo-Json -Compress
