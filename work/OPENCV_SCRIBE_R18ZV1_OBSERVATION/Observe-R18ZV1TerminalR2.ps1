$ErrorActionPreference='Stop';$s='argos_r18zv1_bounded_terminal_observation_v1'
try{
if($env:COMPUTERNAME-cne'A1025645101'){throw 'Wrong host'}
$r='D:\A2\o\ocv\R18ZV1';$ap="$r\AGGREGATE.json";$ip="$r\CASE_INDEX.json"
$af=Get-Item -LiteralPath $ap;$ixf=Get-Item -LiteralPath $ip
if($af.Length-gt1MB-or$ixf.Length-gt64MB){throw 'Bound exceeded'}
$i=Get-Content -LiteralPath $ip -Raw|ConvertFrom-Json;$z=@($i.rows)
if($z.Count-ne[int]$i.caseCount-or$z.Count-lt1){throw 'Index count mismatch'}
$cp=[IO.Path]::GetFullPath([string]$z[0].caseResultPath)
if(-not$cp.StartsWith("$r\cases\",[StringComparison]::OrdinalIgnoreCase)){throw 'Case path escaped root'}
$cf=Get-Item -LiteralPath $cp;if($cf.Length-gt1MB){throw 'Case bound exceeded'}
$c=Get-Content -LiteralPath $cp -Raw|ConvertFrom-Json
$sc=@($z|Group-Object state|%{[pscustomobject]@{state=$_.Name;count=$_.Count}})
$pc=@($z|Group-Object providerState|%{[pscustomobject]@{state=$_.Name;count=$_.Count}})
[pscustomobject]@{schema=$s;state='PASS_R18ZV1_BOUNDED_TERMINAL_OBSERVATION';mutationsPerformed=$false;aggregateFile=[pscustomobject]@{bytes=[int64]$af.Length;sha256=(Get-FileHash $ap -Algorithm SHA256).Hash};indexFile=[pscustomobject]@{bytes=[int64]$ixf.Length;sha256=(Get-FileHash $ip -Algorithm SHA256).Hash;state=$i.state;caseCount=$i.caseCount;rowCount=$z.Count;stateCounts=$sc;providerStateCounts=$pc};representativeFailure=[pscustomobject]@{caseId=$c.caseId;state=$c.state;providerError=$c.providerError;providerReturnCode=$c.providerReturnCode;entered=$c.providerRunJobEnteredCount;returned=$c.providerRunJobReturnedCount;bytes=[int64]$cf.Length;sha256=(Get-FileHash $cp -Algorithm SHA256).Hash}}|ConvertTo-Json -Depth 7 -Compress|clip.exe
}catch{$m=[string]$_.Exception.Message;if($m.Length-gt1000){$m=$m.Substring(0,1000)};[pscustomobject]@{schema=$s;state='FAIL_R18ZV1_BOUNDED_TERMINAL_OBSERVATION';stage='READ_TERMINAL_SUMMARY';errorType=$_.Exception.GetType().FullName;errorMessage=$m;mutationsPerformed=$false}|ConvertTo-Json -Compress|clip.exe}
