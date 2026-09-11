$ErrorActionPreference='Stop';$s='argos_r18zv2_bounded_launch_observation_v1';$stage='START'
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$r='D:\A2\o\ocv\R18ZV2';$rows=@();$stage='READ_MARKERS'
foreach($n in @('LAUNCH.json','STATUS.json','RUNNING.json','COMPLETE.json','FAILURE.json','LAUNCH_REPORTING_ERROR.json')){
$p=Join-Path $r $n
if(Test-Path -LiteralPath $p -PathType Leaf){$f=Get-Item -LiteralPath $p;if($f.Length-gt1MB){throw "Marker too large: $n"};$j=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json;$rows+=@([pscustomobject]@{name=$n;exists=$true;bytes=[int64]$f.Length;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;state=[string]$j.state;disposition=[string]$j.disposition;processId=$j.processId;workerState=[string]$j.workerStateAtConfirmation;completed=$j.completedCount;qualified=$j.qualifiedCaseCount;detail=[string]$j.detail;error=[string]$j.error})}else{$rows+=@([pscustomobject]@{name=$n;exists=$false})}
}
[pscustomobject]@{schema=$s;state='PASS_R18ZV2_BOUNDED_LAUNCH_OBSERVATION';rootExists=(Test-Path -LiteralPath $r -PathType Container);files=$rows;mutationsPerformed=$false}|ConvertTo-Json -Depth 5 -Compress|clip.exe
}catch{$m=[string]$_.Exception.Message;if($m.Length-gt1000){$m=$m.Substring(0,1000)};[pscustomobject]@{schema=$s;state='FAIL_R18ZV2_BOUNDED_LAUNCH_OBSERVATION';stage=$stage;errorType=$_.Exception.GetType().FullName;errorMessage=$m;mutationsPerformed=$false}|ConvertTo-Json -Compress|clip.exe}
