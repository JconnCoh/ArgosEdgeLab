[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$configuredRoot=[IO.Path]::GetFullPath($Root).TrimEnd('\')
$maximumDepth=3
$maximumEntries=50000
$maximumMatches=128
$literalToken='62616-115'
$pending=New-Object 'Collections.Generic.Queue[object]'
$pending.Enqueue([pscustomobject]@{fullPath=$configuredRoot;depth=0})
$matches=New-Object 'Collections.Generic.List[object]'
$accessErrors=New-Object 'Collections.Generic.List[object]'
$entriesVisited=0
$directoriesEnumerated=0
$skippedReparseSubtrees=0
$skippedUnsafePathSubtrees=0
$truncated=$false
while($pending.Count-gt0-and-not$truncated){
    $node=$pending.Dequeue()
    $children=@()
    try{$children=@(Get-ChildItem -LiteralPath ([string]$node.fullPath) -Force -ErrorAction Stop)}catch{$message=[string]$_.Exception.Message;if($accessErrors.Count-lt16){$accessErrors.Add([pscustomobject]@{path=[string]$node.fullPath;message=$message.Substring(0,[Math]::Min(240,$message.Length))})};continue}
    $directoriesEnumerated++
    foreach($child in $children){
        if($entriesVisited-ge$maximumEntries){$truncated=$true;break}
        $entriesVisited++
        $full=[IO.Path]::GetFullPath([string]$child.FullName)
        $prefix=$configuredRoot+'\'
        $relative=$full.Substring($prefix.Length)
        $isContainer=[bool]$child.PSIsContainer
        $reparse=($child.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0
        if(([string]$child.Name).IndexOf($literalToken,[StringComparison]::OrdinalIgnoreCase)-ge0){if($matches.Count-ge$maximumMatches){$truncated=$true;break};$matches.Add([pscustomobject]@{relativePath=$relative;normalizedFullPath=$full;name=[string]$child.Name;depth=([int]$node.depth+1);pathType=if($isContainer){'CONTAINER'}else{'LEAF'};attributes=[string]$child.Attributes;reparsePoint=$reparse;length=if($isContainer){$null}else{[int64]$child.Length};lastWriteTimeUtc=$child.LastWriteTimeUtc.ToString('o');containedByApprovedRoot=$true;filesRead=$false;imageBytesRead=$false;sourceHashingPerformed=$false;mutationsPerformed=$false})}
        if($isContainer-and([int]$node.depth+1)-lt$maximumDepth){if($reparse){$skippedReparseSubtrees++;continue};$componentLength=([string]$child.Name).Length;if(($full.Length+32)-ge230-or$componentLength-gt80){$skippedUnsafePathSubtrees++;continue};$pending.Enqueue([pscustomobject]@{fullPath=$full;depth=([int]$node.depth+1)})}
    }
}
$matchArray=$matches.ToArray()
$errorArray=$accessErrors.ToArray()
$complete=(-not$truncated-and$errorArray.Count-eq0-and$skippedReparseSubtrees-eq0-and$skippedUnsafePathSubtrees-eq0)
$search=[ordered]@{schema='argos_bounded_path_name_search_v1';state=if($complete){'COMPLETE'}else{'HOLD_INCOMPLETE'};literalToken=$literalToken;maximumDepth=$maximumDepth;maximumEntries=$maximumEntries;maximumMatches=$maximumMatches;entriesVisited=$entriesVisited;directoriesEnumerated=$directoriesEnumerated;matches=$matchArray;matchCount=$matchArray.Count;truncated=$truncated;accessErrorCount=$errorArray.Count;accessErrors=$errorArray;skippedReparseSubtrees=$skippedReparseSubtrees;skippedUnsafePathSubtrees=$skippedUnsafePathSubtrees;complete=$complete;filesRead=$false;imageBytesRead=$false;sourceHashingPerformed=$false;mutationsPerformed=$false}
$result=[ordered]@{schema='debug';workerSha256=(Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash;search=$search}
$result|ConvertTo-Json -Depth 30
