$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$base='D:\KLARFExport'
$lot='62623-743'
if(-not(Test-Path -LiteralPath $base -PathType Container)){throw "Missing raw root: $base"}
$cats=@(Get-ChildItem -LiteralPath $base -Directory|Select-Object -First 257)
if($cats.Count-gt256){throw "Raw category cap exceeded: $($cats.Count)"}
$roots=New-Object System.Collections.Generic.List[object]
foreach($c in $cats){
 $found=@(Get-ChildItem -LiteralPath $c.FullName -Directory -Filter "*$lot*"|Select-Object -First 65)
 if($found.Count-gt64){throw "Lot-root cap exceeded under $($c.FullName)"}
 foreach($f in $found){$roots.Add($f)}
}
foreach($name in @("Lot_$lot","Lot_Lot_$lot","Lot-$lot")){
 $p=Join-Path $base $name
 if(Test-Path -LiteralPath $p -PathType Container){$roots.Add((Get-Item -LiteralPath $p))}
}
$uniq=@($roots|Sort-Object FullName -Unique)
if($uniq.Count-gt32){throw "Total lot-root cap exceeded: $($uniq.Count)"}
$rows=@($uniq|ForEach-Object{
 $acq=@(Get-ChildItem -LiteralPath $_.FullName -Directory|Select-Object -First 65)
 if($acq.Count-gt64){throw "Acquisition cap exceeded under $($_.FullName)"}
 [ordered]@{root=$_.FullName;lastWriteUtc=$_.LastWriteTimeUtc.ToString('o');acquisitions=@($acq|ForEach-Object{
  $slots=@(Get-ChildItem -LiteralPath $_.FullName -Directory|Select-Object -First 65)
  if($slots.Count-gt64){throw "Slot cap exceeded under $($_.FullName)"}
  [ordered]@{path=$_.FullName;lastWriteUtc=$_.LastWriteTimeUtc.ToString('o');children=@($slots|ForEach-Object{$_.Name})}
 })}
})
[ordered]@{computerName=$env:COMPUTERNAME;rawRoot=$base;topLevelCategoryCount=$cats.Count;targetLot=$lot;matchedRootCount=$rows.Count;rows=$rows;imageBytesRead=$false;sourceMutationPerformed=$false;tasksProcessesQueuesAccessed=$false}|ConvertTo-Json -Depth 8 -Compress
