$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$p='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\catalog\ALL_WAFER_CATALOG.json'
if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing catalog: $p"}
$item=Get-Item -LiteralPath $p
$o=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
if([string]$o.schema-ne'argos_jbod_all_wafer_catalog_v1'){throw "Bad schema: $($o.schema)"}
$a=@($o.acquisitions)
if($a.Count-gt10000){throw "Catalog row cap: $($a.Count)"}
$m=@($a|Where-Object{([string]$_.scribe)-match'Z'})
if($m.Count-gt64){throw "Z row cap: $($m.Count)"}
$rows=@($m|ForEach-Object{[ordered]@{
 identity=[string]$_.identity
 physicalIdentity=[string]$_.physicalIdentity
 lot=[string]$_.lot
 slot=[string]$_.slot
 scanTimestampLocal=[string]$_.scanTimestampLocal
 domain=[string]$_.domain
 scribe=[string]$_.scribe
 waferId=[string]$_.waferId
 identityState=[string]$_.identityState
 scribeChecksumState=[string]$_.scribeChecksumState
 mesIssuedWaferContainer=[string]$_.mesIssuedWaferContainer
 metadataState=[string]$_.metadataState
 channels=$_.channels
}})
[ordered]@{computerName=$env:COMPUTERNAME;catalogPath=$p;catalogBytes=$item.Length;catalogSha256=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;catalogGeneratedUtc=[string]$o.generatedUtc;catalogAcquisitionCount=$a.Count;zRowCount=$rows.Count;rows=$rows;imageBytesRead=$false;sourceMutationPerformed=$false;tasksProcessesQueuesAccessed=$false}|ConvertTo-Json -Depth 12 -Compress
