$ErrorActionPreference='Stop'
$s='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$id='62619-433_20260824005735_Slot16'
$c=Join-Path $s 'catalog\ALL_WAFER_CATALOG.json'
$r=Join-Path $s ('identity\proposals\'+$id)
$f=@([ordered]@{id='PROPOSAL';p=Join-Path $r 'SCRIBE_PROPOSAL.json'},[ordered]@{id='SUMMARY';p=Join-Path $r 'scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json'},[ordered]@{id='HOLD';p=Join-Path $r 'scribe\multi_channel\MULTI_CHANNEL_READER_HOLD.json'})
$o=@()
foreach ($x in $f){$z=Test-Path -LiteralPath $x.p -PathType Leaf;if ($z){$i=Get-Item -LiteralPath $x.p;if ($i.Length-gt4096){throw('Evidence JSON exceeds direct bound: '+$x.id)};$v=Get-Content -Raw -LiteralPath $x.p|ConvertFrom-Json;$o+=[ordered]@{id=$x.id;path=$x.p;present=$true;bytes=$i.Length;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $x.p).Hash;value=$v}}else{$o+=[ordered]@{id=$x.id;path=$x.p;present=$false}}}
$ci=Get-Item -LiteralPath $c
if ($ci.Length-gt1048576){throw'Catalog exceeds bound'}
$cv=Get-Content -Raw -LiteralPath $c|ConvertFrom-Json
$rows=@($cv.acquisitions|Where-Object{[string]$_.physicalIdentity-eq$id-and[string]$_.domain-eq'FRONTSIDE'}|Select-Object -First 2)
$ok=$rows.Count-eq1-and@($o|Where-Object{$_.id-eq'PROPOSAL'-and$_.present}).Count-eq1-and@($o|Where-Object{$_.id-in@('SUMMARY','HOLD')-and$_.present}).Count-ge1
[ordered]@{schema='argos_r3_slot16_installed_scribe_metadata_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=if($ok){'PASS_R3_SLOT16_INSTALLED_SCRIBE_METADATA'}else{'HOLD_R3_SLOT16_INSTALLED_SCRIBE_METADATA_INCOMPLETE'};computerName=$env:COMPUTERNAME;physicalIdentity=$id;catalog=[ordered]@{path=$c;bytes=$ci.Length;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $c).Hash;exactRows=$rows};files=$o;imageBytesRead=$false;taskOrProcessRestarted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress -Depth 30
