$ErrorActionPreference='Stop'
if($env:COMPUTERNAME-cne'A1025645101'){throw'Wrong host'}
$r='D:\A2\o\ocv\R18ZV1';$ap="$r\AGGREGATE.json";$ip="$r\CASE_INDEX.json"
$af=Get-Item -LiteralPath $ap;$ixf=Get-Item -LiteralPath $ip
if($af.Length-gt1MB-or$ixf.Length-gt64MB){throw'Bound exceeded'}
$a=Get-Content -LiteralPath $ap -Raw|ConvertFrom-Json
$i=Get-Content -LiteralPath $ip -Raw|ConvertFrom-Json;$z=@($i.rows)
if($z.Count-ne[int]$i.caseCount-or$z.Count-lt1){throw'Index count mismatch'}
$cp=[IO.Path]::GetFullPath([string]$z[0].caseResultPath)
if(-not$cp.StartsWith("$r\cases\",[StringComparison]::OrdinalIgnoreCase)){throw'Case path escaped root'}
$cf=Get-Item -LiteralPath $cp;if($cf.Length-gt1MB){throw'Case bound exceeded'}
$c=Get-Content -LiteralPath $cp -Raw|ConvertFrom-Json
[pscustomobject]@{schema='argos_r18zv1_bounded_terminal_observation_v1';state='PASS_R18ZV1_BOUNDED_TERMINAL_OBSERVATION';observedUtc=[DateTime]::UtcNow.ToString('o');aggregateFile=[pscustomobject]@{bytes=[int64]$af.Length;sha256=(Get-FileHash -LiteralPath $ap -Algorithm SHA256).Hash};indexFile=[pscustomobject]@{bytes=[int64]$ixf.Length;sha256=(Get-FileHash -LiteralPath $ip -Algorithm SHA256).Hash};aggregate=$a;caseIndex=[pscustomobject]@{state=$i.state;caseCount=$i.caseCount;rowCount=$z.Count};representativeFailure=[pscustomobject]@{caseId=$c.caseId;state=$c.state;providerError=$c.providerError;providerReturnCode=$c.providerReturnCode;entered=$c.providerRunJobEnteredCount;returned=$c.providerRunJobReturnedCount;bytes=[int64]$cf.Length;sha256=(Get-FileHash -LiteralPath $cp -Algorithm SHA256).Hash}}|ConvertTo-Json -Depth 8 -Compress|clip.exe
