$ErrorActionPreference='Stop'
$r='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals\62619-433_20260824005735_Slot16'
$n=@('SCRIBE_PROPOSAL.json','scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json','scribe\multi_channel\MULTI_CHANNEL_READER_HOLD.json')
$o=@()
foreach ($x in $n){$p=Join-Path $r $x;if (Test-Path -LiteralPath $p -PathType Leaf){$i=Get-Item -LiteralPath $p;$v=Get-Content -Raw -LiteralPath $p|ConvertFrom-Json;$q=@($v.PSObject.Properties|Where-Object{$_.Name-match'(?i)state|path|crop|region|dimension|orient|proposal|consensus|unique|source|channel'}|ForEach-Object{[ordered]@{name=$_.Name;value=$_.Value}});$o+=[ordered]@{leaf=$x;present=$true;bytes=$i.Length;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash;propertyNames=@($v.PSObject.Properties.Name);projection=$q}}else{$o+=[ordered]@{leaf=$x;present=$false}}}
[ordered]@{schema='argos_r3_slot16_scribe_projection_v1';state='PASS_R3_SLOT16_SCRIBE_PROJECTION';computerName=$env:COMPUTERNAME;physicalIdentity='62619-433_20260824005735_Slot16';files=$o;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress -Depth 20
