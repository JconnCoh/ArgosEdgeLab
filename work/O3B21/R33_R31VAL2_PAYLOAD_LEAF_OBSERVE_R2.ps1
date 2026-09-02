$id='REQ_20260901T225534688Z_673F2FFD0E09.ready'
$base='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod'
$names='Run-R29ValidationBatch.py','Run-R31ValidationBatch.py','R18_REGRESSION_CASES.json','R31VAL2_CONTRACT.json'
$rows=@()
foreach($state in 'pending','processed'){$root=Join-Path (Join-Path $base $state) "$id\payload";foreach($name in $names){$path=Join-Path $root $name;$exists=Test-Path -LiteralPath $path -PathType Leaf;$rows+=[ordered]@{state=$state;name=$name;exists=$exists;sha256=$(if($exists){(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}else{$null})}}}
[ordered]@{state='PASS_R33_R31VAL2_EXACT_PAYLOAD_LEAF_OBSERVATION_R2';rows=$rows;imageBytesRead=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 4 -Compress
