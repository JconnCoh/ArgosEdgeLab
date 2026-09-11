$ErrorActionPreference='Stop';$s='argos_r18zv2_endpoint_pending_observation_v1';$stage='START'
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$p='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_RZV2.ready';$stage='READ_EXACT_PENDING_PATH';$e=Test-Path -LiteralPath $p -PathType Container;$rows=@()
foreach($n in @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig')){$f=Join-Path $p $n;if($e-and(Test-Path -LiteralPath $f -PathType Leaf)){$i=Get-Item -LiteralPath $f;$rows+=@([pscustomobject]@{name=$n;exists=$true;bytes=[int64]$i.Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash})}else{$rows+=@([pscustomobject]@{name=$n;exists=$false})}}
[pscustomobject]@{schema=$s;state='PASS_R18ZV2_ENDPOINT_PENDING_OBSERVATION';pendingRootExists=$e;files=$rows;mutationsPerformed=$false}|ConvertTo-Json -Depth 4 -Compress|clip.exe
}catch{$m=[string]$_.Exception.Message;if($m.Length-gt1000){$m=$m.Substring(0,1000)};[pscustomobject]@{schema=$s;state='FAIL_R18ZV2_ENDPOINT_PENDING_OBSERVATION';stage=$stage;errorType=$_.Exception.GetType().FullName;errorMessage=$m;mutationsPerformed=$false}|ConvertTo-Json -Compress|clip.exe}
