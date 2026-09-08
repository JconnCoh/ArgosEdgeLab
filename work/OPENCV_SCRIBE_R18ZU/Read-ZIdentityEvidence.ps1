$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$b='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$units=@('62623-743-040','62623-743-050','62623-743-070')
$truth=@('147Z6155SUG7','147Z6156SUD6','147Z6158SUE7')
$spec=@(
 @('verified','metadata\verified\ACTIVE_VERIFIED_METADATA_OVERLAY.json','argos_verified_scribe_mes_metadata_overlay_v1'),
 @('confirmed','identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json','argos_confirmed_scribe_overlay_v1')
)
function V($x,$n){$q=$x.PSObject.Properties[$n];if($null-ne$q){[string]$q.Value}else{''}}
$out=@()
foreach($s in $spec){
 $p=Join-Path $b $s[1]
 if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing $($s[0]): $p"}
 $i=Get-Item -LiteralPath $p
 if($i.Length-gt33554432){throw "$($s[0]) byte cap: $($i.Length)"}
 $o=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
 if([string]$o.schema-ne$s[2]){throw "$($s[0]) schema: $($o.schema)"}
 $rows=@($o.rows)
 if($rows.Count-gt10000){throw "$($s[0]) row cap: $($rows.Count)"}
 $m=@($rows|Where-Object{$sc=V $_ 'scribe';$u=V $_ 'issuedWaferContainer';$truth-contains$sc-or$units-contains$u-or$sc-match'Z'})
 if($m.Count-gt64){throw "$($s[0]) match cap: $($m.Count)"}
 $out+=,[ordered]@{source=$s[0];path=$p;bytes=$i.Length;sha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;rowCount=$rows.Count;matches=@($m|ForEach-Object{[ordered]@{
  acquisitionKey=V $_ 'acquisitionKey'
  physicalIdentity=V $_ 'physicalIdentity'
  scribe=V $_ 'scribe'
  waferId=V $_ 'waferId'
  issuedWaferContainer=V $_ 'issuedWaferContainer'
  identityState=V $_ 'identityState'
  operatorDisposition=V $_ 'operatorDisposition'
 }})}
}
[ordered]@{computerName=$env:COMPUTERNAME;sources=$out;imageBytesRead=$false;sourceMutationPerformed=$false;tasksProcessesQueuesAccessed=$false}|ConvertTo-Json -Depth 8 -Compress
