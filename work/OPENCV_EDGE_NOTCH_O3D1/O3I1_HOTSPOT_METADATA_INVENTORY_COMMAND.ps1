$cp='C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\config\endpoint_jbod.json'
$c=Get-Content -Raw -LiteralPath $cp|ConvertFrom-Json
$m=@($c.approvedDataRoots|Where-Object{$_.name-eq'JBOD_KLARF_EXPORT'})
if($m.Count-ne1){throw 'approved root row count changed'}
$b=[IO.Path]::GetFullPath([string]$m[0].path).TrimEnd('\')
$r=[IO.Path]::GetFullPath((Join-Path $b 'PatternedFront\Lot_62629-419_NotchBad_Hotspot'))
if(!$r.StartsWith($b+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'root escape'}
if(!(Test-Path -LiteralPath $r -PathType Container)){throw 'exact lot absent'}
$q=New-Object Collections.Queue;$q.Enqueue(@($r,'',0));$d=@([pscustomobject]@{p='';z=0});$f=@();$x=@();$e=@();$n=0;$o=0
while($q.Count){$a=$q.Dequeue();try{$g=@(Get-ChildItem -LiteralPath $a[0] -Force -ErrorAction Stop)}catch{$e+=@([pscustomobject]@{p=$a[1];m=$_.Exception.Message});continue};foreach($i in $g){$n++;if($n-gt20000){throw 'entry bound'};$p=if($a[1]){$a[1]+'\'+$i.Name}else{$i.Name};$t=[IO.File]::GetAttributes($i.FullName);if(($t-band[IO.FileAttributes]::ReparsePoint)-ne0){$x+=@([pscustomobject]@{p=$p;k='REPARSE'});continue};if($i.PSIsContainer){$z=$a[2]+1;if($z-gt8){$x+=@([pscustomobject]@{p=$p;k='DEPTH'});continue};$d+=@([pscustomobject]@{p=$p;z=$z});$q.Enqueue(@($i.FullName,$p,$z))}elseif($i.Extension-ieq'.bmp'){$f+=@([pscustomobject]@{p=$p;b=$i.Length;u=$i.LastWriteTimeUtc.ToString('o');z=$a[2];l=$i.FullName.Length})}else{$o++}}}
[ordered]@{schema='argos_ocv03_hotspot_metadata_inventory_v1';state=if(!$e.Count-and!$x.Count){'COMPLETE'}else{'HOLD'};computerName=$env:COMPUTERNAME;config=$cp;approvedRoot=$b;exactRoot=$r;directories=$d;bmpLeaves=$f;entryCount=$n;directoryCount=$d.Count;bmpCount=$f.Count;nonBmpFileCount=$o;skipRows=$x;errors=$e;truncated=$false;maximumDepth=8;maximumEntries=20000;filesRead=$false;imageBytesRead=$false;sourceHashingPerformed=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress -Depth 6
