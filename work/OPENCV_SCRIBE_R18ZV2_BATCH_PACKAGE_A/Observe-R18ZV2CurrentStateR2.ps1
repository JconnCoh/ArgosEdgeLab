$ErrorActionPreference='Stop'
$s='argos_r18zv2_current_state_observation_v2'
try{
$p='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_RZV2.ready'
$l='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\REQ_RZV2.json'
$d='D:\A2\o\ocv\R18ZV2'
$m=@()
foreach($n in @('LAUNCH.json','STATUS.json','RUNNING.json','COMPLETE.json','FAILURE.json','LAUNCH_REPORTING_ERROR.json')){
$f=Join-Path $d $n
if(Test-Path -LiteralPath $f -PathType Leaf){
$i=Get-Item -LiteralPath $f
if($i.Length -gt 1048576){throw "Oversize marker $n"}
$j=Get-Content -LiteralPath $f -Raw|ConvertFrom-Json
$m+=@{name=$n;bytes=$i.Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash;state=$j.state;disposition=$j.disposition;processId=$j.processId;workerState=$j.workerStateAtConfirmation;completed=$j.completedCount;qualified=$j.qualifiedCaseCount;detail=$j.detail}
}}
$g=$null
if(Test-Path -LiteralPath $l -PathType Leaf){
$i=Get-Item -LiteralPath $l
if($i.Length -gt 1048576){throw 'Oversize ledger'}
$j=Get-Content -LiteralPath $l -Raw|ConvertFrom-Json
$g=@{bytes=$i.Length;sha256=(Get-FileHash -LiteralPath $l -Algorithm SHA256).Hash;state=$j.state;processedUtc=$j.processedUtc;responsePackage=$j.responsePackage}
}
$r=@{schema=$s;state='PASS';computerName=$env:COMPUTERNAME;pending=[bool](Test-Path -LiteralPath $p -PathType Container);ledger=$g;outputRoot=[bool](Test-Path -LiteralPath $d -PathType Container);markers=$m;mutationsPerformed=$false}
}catch{
$e=[string]$_.Exception.Message
if($e.Length -gt 500){$e=$e.Substring(0,500)}
$r=@{schema=$s;state='FAIL_OBSERVATION';stage='bounded_read';errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$false}
}
$r|ConvertTo-Json -Compress -Depth 8|clip.exe
