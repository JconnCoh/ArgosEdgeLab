$ErrorActionPreference='Stop'
$r='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals\62619-433_20260824005735_Slot16\scribe'
$n=@('BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png','DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png')
$o=@()
foreach ($x in $n){$p=Join-Path $r $x;if (-not(Test-Path -LiteralPath $p -PathType Leaf)){throw ('Missing crop: '+$x)};$i=Get-Item -LiteralPath $p;$o+=[ordered]@{leaf=$x;path=$p;bytes=$i.Length;sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash}}
[ordered]@{schema='argos_r3_slot16_crop_hashes_v1';state='PASS_R3_SLOT16_CROP_HASHES';computerName=$env:COMPUTERNAME;physicalIdentity='62619-433_20260824005735_Slot16';files=$o;pixelsDecoded=$false;taskOrProcessRestarted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress
