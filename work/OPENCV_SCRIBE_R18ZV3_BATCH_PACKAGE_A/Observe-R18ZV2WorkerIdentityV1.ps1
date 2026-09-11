param([switch]$Preflight)
$ErrorActionPreference='Stop'
$s='argos_r18zv2_worker_identity_observation_v1'
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$f='D:\A2\o\ocv\R18ZV2\LAUNCH.json'
if(-not(Test-Path -LiteralPath $f -PathType Leaf)){throw 'R18ZV2 launch marker absent'}
$i=Get-Item -LiteralPath $f
if($i.Length-gt1048576){throw 'R18ZV2 launch marker oversized'}
$j=Get-Content -LiteralPath $f -Raw|ConvertFrom-Json
$workerPid=[int]$j.processId
$rows=@(Get-CimInstance Win32_Process -Filter "ProcessId=$workerPid")
if($rows.Count-gt1){throw 'Duplicate process identity'}
$p=$null
if($rows.Count-eq1){$q=$rows[0];$p=@{processId=[int]$q.ProcessId;parentProcessId=[int]$q.ParentProcessId;name=[string]$q.Name;executablePath=[string]$q.ExecutablePath;creationDate=[string]$q.CreationDate;commandLine=[string]$q.CommandLine}}
$r=@{schema=$s;state='PASS_R18ZV2_WORKER_IDENTITY_OBSERVATION';computerName=$env:COMPUTERNAME;launch=@{bytes=$i.Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash;state=$j.state;processId=$workerPid;processCreationTimeUtc=$j.processCreationTimeUtc;workerState=$j.workerStateAtConfirmation};process=$p;r18zv3Pending=[bool](Test-Path -LiteralPath 'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_RZV3.ready' -PathType Container);mutationsPerformed=$false}
}catch{
$e=[string]$_.Exception.Message
if($e.Length-gt500){$e=$e.Substring(0,500)}
$r=@{schema=$s;state='FAIL_R18ZV2_WORKER_IDENTITY_OBSERVATION';errorType=$_.Exception.GetType().FullName;errorMessage=$e;mutationsPerformed=$false}
}
$r|ConvertTo-Json -Compress -Depth 8|clip.exe
