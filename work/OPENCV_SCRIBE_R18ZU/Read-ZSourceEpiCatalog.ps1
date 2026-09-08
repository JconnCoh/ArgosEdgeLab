$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$p='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\catalog\ALL_WAFER_CATALOG.json'
$keys=@('62623-743-040','62623-743-040Wafer','62623-743-050','62623-743-050Wafer','62623-743-070','172609-197D-1')
if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing catalog: $p"}
$item=Get-Item -LiteralPath $p
$o=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
if([string]$o.schema-ne'argos_jbod_all_wafer_catalog_v1'){throw "Bad schema: $($o.schema)"}
$a=@($o.acquisitions)
if($a.Count-gt10000){throw "Catalog row cap: $($a.Count)"}
$m=@($a|Where-Object{$j=$_|ConvertTo-Json -Depth 8 -Compress;$hit=$false;foreach($k in $keys){if($j.Contains($k)){$hit=$true;break}};$hit})
if($m.Count-gt64){throw "Match cap: $($m.Count)"}
$rows=@($m|ForEach-Object{[ordered]@{
 identity=[string]$_.identity
 physicalIdentity=[string]$_.physicalIdentity
 lot=[string]$_.lot
 slot=[string]$_.slot
 scanTimestampLocal=[string]$_.scanTimestampLocal
 domain=[string]$_.domain
 waferId=[string]$_.waferId
 scribe=[string]$_.scribe
 mesIssuedWaferContainer=[string]$_.mesIssuedWaferContainer
 identityState=[string]$_.identityState
 metadataState=[string]$_.metadataState
 channels=$_.channels
}})
[ordered]@{computerName=$env:COMPUTERNAME;catalogPath=$p;catalogBytes=$item.Length;catalogSha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;catalogAcquisitionCount=$a.Count;queryKeys=$keys;matchCount=$rows.Count;rows=$rows;imageBytesRead=$false;sourceMutationPerformed=$false;tasksProcessesQueuesAccessed=$false}|ConvertTo-Json -Depth 12 -Compress
