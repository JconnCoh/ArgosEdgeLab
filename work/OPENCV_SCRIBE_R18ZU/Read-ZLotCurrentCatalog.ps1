$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$p='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\catalog\ALL_WAFER_CATALOG.json'
$lot='62623-743'
if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing catalog: $p"}
$item=Get-Item -LiteralPath $p
$sha=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash
$o=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
if([string]$o.schema-ne'argos_jbod_all_wafer_catalog_v1'){throw "Bad schema: $($o.schema)"}
$a=@($o.acquisitions)
if($a.Count-gt10000){throw "Catalog row cap: $($a.Count)"}
$m=@($a|Where-Object{[string]$_.lot-eq$lot})
if($m.Count-gt32){throw "Lot row cap: $($m.Count)"}
$rows=@($m|ForEach-Object{[ordered]@{
 identity=[string]$_.identity
 physicalIdentity=[string]$_.physicalIdentity
 scanTimestampLocal=[string]$_.scanTimestampLocal
 slot=[string]$_.slot
 domain=[string]$_.domain
 waferId=[string]$_.waferId
 scribe=[string]$_.scribe
 identityState=[string]$_.identityState
 scribeChecksumState=[string]$_.scribeChecksumState
 mesIssuedWaferContainer=[string]$_.mesIssuedWaferContainer
 mesQueryState=[string]$_.mesQueryState
 metadataState=[string]$_.metadataState
 channels=$_.channels
}})
[ordered]@{
 computerName=$env:COMPUTERNAME
 catalogPath=$p
 catalogBytes=$item.Length
 catalogSha256=$sha
 catalogGeneratedUtc=[string]$o.generatedUtc
 catalogAcquisitionCount=$a.Count
 targetLot=$lot
 targetLotRowCount=$rows.Count
 rows=$rows
 imageBytesRead=$false
 sourceMutationPerformed=$false
 tasksProcessesQueuesAccessed=$false
}|ConvertTo-Json -Depth 12 -Compress
