[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Inventory,
    [switch]$SelfTest,
    [Parameter(Mandatory=$true)][string]$ApprovedRoot,
    [Parameter(Mandatory=$true)][string]$RelativeSubtree,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Z]$')][string]$AliasName,
    [int]$MaximumDepth=8,
    [int]$MaximumEntries=20000,
    [int]$MaximumDirectories=2048,
    [int]$MaximumBmpLeaves=2048,
    [string]$CanonicalProvenanceRoot,
    [switch]$Rehearsal,
    [switch]$FailAfterAlias
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$modeCount=@(@($Preflight,$Inventory,$SelfTest)|Where-Object{[bool]$_}).Count
if($modeCount-ne1){throw 'Specify exactly one of -Preflight, -Inventory, or -SelfTest.'}
if($SelfTest-and-not$Rehearsal){throw 'SelfTest is rehearsal-only.'}
if($FailAfterAlias-and-not$Rehearsal){throw 'Injected failure is rehearsal-only.'}
if($MaximumDepth-lt1-or$MaximumDepth-gt8){throw 'MaximumDepth must be 1 through 8.'}
if($MaximumEntries-lt1-or$MaximumEntries-gt20000){throw 'MaximumEntries must be 1 through 20000.'}
if($MaximumDirectories-lt1-or$MaximumDirectories-gt2048){throw 'MaximumDirectories must be 1 through 2048.'}
if($MaximumBmpLeaves-lt1-or$MaximumBmpLeaves-gt2048){throw 'MaximumBmpLeaves must be 1 through 2048.'}
if([string]::IsNullOrWhiteSpace($RelativeSubtree)-or[IO.Path]::IsPathRooted($RelativeSubtree)-or$RelativeSubtree-match'(^|\\)\.\.?($|\\)'-or$RelativeSubtree.IndexOfAny([char[]]'*?[]')-ge0){throw 'RelativeSubtree is unsafe.'}

function Get-SafeChildPath([string]$Root,[string]$Relative){
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidate=[IO.Path]::GetFullPath((Join-Path $rootFull $Relative))
    if(-not$candidate.StartsWith($rootFull+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Relative subtree escaped its root.'}
    return $candidate
}

function Get-NormalizedProvenanceRoot([string]$Path){
    if([string]::IsNullOrWhiteSpace($Path)){throw 'Canonical provenance root is empty.'}
    $text=$Path.Replace('/','\').TrimEnd('\')
    if($text-notmatch'^(?:[A-Za-z]:\\|\\\\[^\\]+\\[^\\]+(?:\\|$))'){throw 'Canonical provenance root must be an absolute Windows path.'}
    $tail=if($text-match'^[A-Za-z]:\\'){$text.Substring(3)}else{$text.Substring(([regex]::Match($text,'^\\\\[^\\]+\\[^\\]+(?:\\|$)')).Length)}
    $components=@($tail.Split('\')|Where-Object{-not[string]::IsNullOrWhiteSpace($_)})
    if(@($components|Where-Object{$_-eq'.'-or$_-eq'..'-or$_.IndexOfAny([char[]]'*?[]')-ge0}).Count-gt0){throw 'Canonical provenance root contains an unsafe component.'}
    return $text
}

function Get-ProvenanceChildPath([string]$Root,[string]$Relative){
    $normalized=Get-NormalizedProvenanceRoot $Root
    return $normalized+'\'+$Relative.TrimStart('\')
}

function Get-SourceBudget([string]$Path,[int]$Reserve=32){
    $text=$Path.Replace('/','\')
    $tail=if($text-match'^[A-Za-z]:\\'){$text.Substring(3)}elseif($text-match'^\\\\[^\\]+\\[^\\]+(?:\\|$)'){$text.Substring(([regex]::Match($text,'^\\\\[^\\]+\\[^\\]+(?:\\|$)')).Length)}else{$text.TrimStart('\')}
    $components=@($tail.Split('\')|Where-Object{-not[string]::IsNullOrWhiteSpace($_)})
    $longest=if($components.Count){[int](($components|Measure-Object Length -Maximum).Maximum)}else{0}
    $effective=[int]$text.Length+$Reserve
    $state=if($longest-gt255){'REJECT_FILESYSTEM_COMPONENT'}elseif($effective-ge200){'REJECT_ALIAS_EFFECTIVE_LENGTH'}else{'PASS_EXISTING_SOURCE_ALIAS'}
    [pscustomobject]@{
        path=$text
        pathLength=[int]$text.Length
        reservedSuffixCharacters=$Reserve
        effectiveLength=$effective
        longestComponentLength=$longest
        existingSourceComponentAbove80=($longest-gt80-and$longest-le255)
        state=$state
    }
}

function Get-ProvenanceBudget([string]$Path,[int]$Reserve=32){
    $value=Get-SourceBudget -Path $Path -Reserve $Reserve
    $state=if($value.effectiveLength-ge230){'HARD_STOP_IF_USED_FOR_IO'}elseif($value.effectiveLength-ge200){'SHORT_ALIAS_REQUIRED_FOR_IO'}else{'PASS_CANONICAL_SPELLING'}
    [pscustomobject]@{
        path=$value.path
        pathLength=$value.pathLength
        reservedSuffixCharacters=$Reserve
        effectiveLength=$value.effectiveLength
        longestComponentLength=$value.longestComponentLength
        existingSourceComponentAbove80=$value.existingSourceComponentAbove80
        state=$state
        ioAllowed=($state-eq'PASS_CANONICAL_SPELLING')
    }
}

function Get-ChildDecision(
    [string]$ParentRelativePath,
    [string]$ChildName,
    [string]$PathType,
    [string]$Extension,
    [string]$CanonicalPath,
    [string]$AliasPath
){
    $canonicalBudget=Get-ProvenanceBudget $CanonicalPath
    $aliasBudget=Get-SourceBudget $AliasPath
    $reason=$null
    if($aliasBudget.state-eq'REJECT_ALIAS_EFFECTIVE_LENGTH'){$reason='ALIAS_EFFECTIVE_LENGTH_AT_OR_ABOVE_200'}
    elseif($aliasBudget.state-eq'REJECT_FILESYSTEM_COMPONENT'){$reason='ALIAS_COMPONENT_ABOVE_FILESYSTEM_MAXIMUM'}
    $skipRow=if($null-eq$reason){$null}else{[pscustomobject]@{
        parentRelativePath=$ParentRelativePath
        childName=$ChildName
        pathType=$PathType
        extension=$Extension
        canonicalProvenancePath=$CanonicalPath
        canonicalEffectiveLength=[int]$canonicalBudget.effectiveLength
        canonicalLongestComponentLength=[int]$canonicalBudget.longestComponentLength
        aliasReadPath=$AliasPath
        aliasEffectiveLength=[int]$aliasBudget.effectiveLength
        aliasLongestComponentLength=[int]$aliasBudget.longestComponentLength
        rejectionReason=$reason
    }}
    [pscustomobject]@{
        accepted=($null-eq$reason)
        canonicalBudget=$canonicalBudget
        aliasBudget=$aliasBudget
        existingSourceComponentAbove80=[bool]$aliasBudget.existingSourceComponentAbove80
        skipRow=$skipRow
    }
}

if($SelfTest){
    $canonicalLong='C:\'+((('provenance_segment_12345')+'\')*10)+'leaf.bmp'
    $acceptLongCanonical=Get-ChildDecision '' 'leaf.bmp' 'LEAF' '.bmp' $canonicalLong 'Q:\leaf.bmp'
    $aliasLong='Q:\'+((('alias_segment_123456789012')+'\')*7)+'leaf.bmp'
    $rejectLongAlias=Get-ChildDecision 'synthetic' 'leaf.bmp' 'LEAF' '.bmp' $canonicalLong $aliasLong
    $name81=('n'*81)+'.bmp'
    $acceptExistingLongComponent=Get-ChildDecision '' $name81 'LEAF' '.bmp' ('C:\source\'+$name81) ('Q:\'+$name81)
    $name256=('z'*256)
    $rejectImpossibleComponent=Get-ChildDecision '' $name256 'LEAF' '' ('C:\source\'+$name256) ('Q:\'+$name256)
    if(-not$acceptLongCanonical.accepted-or$acceptLongCanonical.canonicalBudget.effectiveLength-lt230-or-not$acceptLongCanonical.aliasBudget.state.Equals('PASS_EXISTING_SOURCE_ALIAS')){throw 'SelfTest canonical-provenance/short-alias case failed.'}
    if($rejectLongAlias.accepted-or[string]$rejectLongAlias.skipRow.rejectionReason-ne'ALIAS_EFFECTIVE_LENGTH_AT_OR_ABOVE_200'){throw 'SelfTest long-alias exact skip-row case failed.'}
    if(-not$acceptExistingLongComponent.accepted-or-not$acceptExistingLongComponent.existingSourceComponentAbove80){throw 'SelfTest existing source component advisory case failed.'}
    if($rejectImpossibleComponent.accepted-or[string]$rejectImpossibleComponent.skipRow.rejectionReason-ne'ALIAS_COMPONENT_ABOVE_FILESYSTEM_MAXIMUM'){throw 'SelfTest impossible component exact skip-row case failed.'}
    [ordered]@{
        schema='argos_ocv00_deepest_alias_provider_self_test_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_OCV00_DEEPEST_ALIAS_PROVIDER_SELF_TEST'
        canonical230AliasUnder200Accepted=$true
        alias200ExactIdentityHold=$true
        existingSourceComponentAbove80Advisory=$true
        filesystemImpossibleComponentExactIdentityHold=$true
        filesRead=$false
        imageBytesRead=$false
        sourceHashingPerformed=$false
        mutationsPerformed=$false
    }|ConvertTo-Json -Depth 8
    return
}

$approvedRootFull=[IO.Path]::GetFullPath($ApprovedRoot).TrimEnd('\')
$physicalSubtree=Get-SafeChildPath $approvedRootFull $RelativeSubtree
$canonicalBase=if($Rehearsal-and-not[string]::IsNullOrWhiteSpace($CanonicalProvenanceRoot)){Get-NormalizedProvenanceRoot $CanonicalProvenanceRoot}else{$approvedRootFull}
if(-not$Rehearsal-and-not[string]::IsNullOrWhiteSpace($CanonicalProvenanceRoot)-and-not$canonicalBase.Equals($approvedRootFull,[StringComparison]::OrdinalIgnoreCase)){throw 'Live canonical provenance root must equal the approved root.'}
$canonicalSubtree=Get-ProvenanceChildPath $canonicalBase $RelativeSubtree
$aliasRoot=$AliasName+':\'
$physicalRootBudget=Get-SourceBudget $physicalSubtree
$aliasRootBudget=Get-SourceBudget $aliasRoot
if([string]$physicalRootBudget.state-ne'PASS_EXISTING_SOURCE_ALIAS'){throw 'Requested subtree root requires a shorter pre-alias physical root.'}
if([string]$aliasRootBudget.state-ne'PASS_EXISTING_SOURCE_ALIAS'){throw 'Alias root path budget failed.'}

if($Preflight){
    [ordered]@{
        schema='argos_ocv00_deepest_alias_inventory_preflight_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_OCV00_DEEPEST_ALIAS_INVENTORY_PREFLIGHT'
        approvedRoot=$approvedRootFull
        relativeSubtree=$RelativeSubtree
        requestedSubtreeRoot=$physicalSubtree
        canonicalProvenanceRoot=$canonicalSubtree
        aliasName=$AliasName
        aliasRoot=$aliasRoot
        aliasAnchor='EXACT_REQUESTED_SUBTREE_ROOT'
        pathsEnumerated=$false
        filesRead=$false
        imageBytesRead=$false
        sourceHashingPerformed=$false
        mutationsPerformed=$false
    }|ConvertTo-Json -Depth 8
    return
}

if(Get-PSDrive -Name $AliasName -ErrorAction SilentlyContinue){throw "Process-local alias is already in use: $AliasName"}
$aliasCreated=$false
$aliasRemoved=$true
$rootExists=$false
$directories=New-Object 'Collections.Generic.List[object]'
$bmpLeaves=New-Object 'Collections.Generic.List[object]'
$skipRows=New-Object 'Collections.Generic.List[object]'
$accessErrors=New-Object 'Collections.Generic.List[object]'
$entriesVisited=0
$directoriesEnumerated=0
$otherLeafCount=0
$depthBoundaryDirectoryCount=0
$truncated=$false

$segments=@($RelativeSubtree.Split('\')|Where-Object{-not[string]::IsNullOrWhiteSpace($_)})
$current=$approvedRootFull
$missing=$false
foreach($segment in $segments){
    $current=Join-Path $current $segment
    if(-not(Test-Path -LiteralPath $current)){$missing=$true;break}
    $currentItem=Get-Item -LiteralPath $current -Force -ErrorAction Stop
    if(($currentItem.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){throw 'Requested subtree has a reparse ancestor.'}
}

if(-not$missing-and(Test-Path -LiteralPath $physicalSubtree -PathType Container)){
    $rootExists=$true
    try{
        [void](New-PSDrive -Name $AliasName -PSProvider FileSystem -Root $physicalSubtree -Scope Script -ErrorAction Stop)
        $aliasCreated=$true
        $aliasRemoved=$false
        $drive=Get-PSDrive -Name $AliasName -ErrorAction Stop
        if(-not([IO.Path]::GetFullPath([string]$drive.Root).TrimEnd('\')).Equals($physicalSubtree,[StringComparison]::OrdinalIgnoreCase)){throw 'Process-local alias did not bind the exact requested subtree.'}
        if($FailAfterAlias){throw 'INJECTED_OLS4_FAILURE_AFTER_ALIAS'}
        $queue=New-Object 'Collections.Generic.Queue[object]'
        $queue.Enqueue([pscustomobject]@{readPath=$aliasRoot;subtreeRelativePath='';canonicalPath=$canonicalSubtree;depth=0})
        while($queue.Count-gt0-and-not$truncated){
            $node=$queue.Dequeue()
            try{$children=@(Get-ChildItem -LiteralPath ([string]$node.readPath) -Force -ErrorAction Stop)}
            catch{
                $message=[string]$_.Exception.Message
                if($accessErrors.Count-lt16){$accessErrors.Add([pscustomobject]@{parentRelativePath=[string]$node.subtreeRelativePath;message=$message.Substring(0,[Math]::Min(240,$message.Length))})}
                continue
            }
            $directoriesEnumerated++
            foreach($child in $children){
                if($entriesVisited-ge$MaximumEntries){$truncated=$true;break}
                $entriesVisited++
                $parentRelative=[string]$node.subtreeRelativePath
                $childRelative=if([string]::IsNullOrWhiteSpace($parentRelative)){[string]$child.Name}else{$parentRelative+'\'+[string]$child.Name}
                $aliasRead=Join-Path ([string]$node.readPath) ([string]$child.Name)
                $canonicalPath=[string]$node.canonicalPath+'\'+[string]$child.Name
                $pathType=if([bool]$child.PSIsContainer){'CONTAINER'}else{'LEAF'}
                $extension=if([bool]$child.PSIsContainer){''}else{[string]$child.Extension}
                $decision=Get-ChildDecision $parentRelative ([string]$child.Name) $pathType $extension $canonicalPath $aliasRead
                if(-not$decision.accepted){$skipRows.Add($decision.skipRow);continue}
                $reparse=($child.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0
                if($reparse){
                    $skipRows.Add([pscustomobject]@{
                        parentRelativePath=$parentRelative;childName=[string]$child.Name;pathType=$pathType;extension=$extension;canonicalProvenancePath=$canonicalPath;canonicalEffectiveLength=[int]$decision.canonicalBudget.effectiveLength;canonicalLongestComponentLength=[int]$decision.canonicalBudget.longestComponentLength;aliasReadPath=$aliasRead;aliasEffectiveLength=[int]$decision.aliasBudget.effectiveLength;aliasLongestComponentLength=[int]$decision.aliasBudget.longestComponentLength;rejectionReason='REPARSE_CHILD_NOT_TRAVERSED'
                    })
                    continue
                }
                $depth=[int]$node.depth+1
                $common=[ordered]@{
                    relativePath=$RelativeSubtree+'\'+$childRelative
                    subtreeRelativePath=$childRelative
                    canonicalProvenancePath=$canonicalPath
                    canonicalEffectiveLength=[int]$decision.canonicalBudget.effectiveLength
                    canonicalBudgetState=[string]$decision.canonicalBudget.state
                    canonicalIoAllowed=[bool]$decision.canonicalBudget.ioAllowed
                    aliasReadPath=$aliasRead
                    aliasEffectiveLength=[int]$decision.aliasBudget.effectiveLength
                    aliasLongestComponentLength=[int]$decision.aliasBudget.longestComponentLength
                    existingSourceComponentAbove80=[bool]$decision.existingSourceComponentAbove80
                    name=[string]$child.Name
                    depth=$depth
                    pathType=$pathType
                    attributes=[string]$child.Attributes
                    reparsePoint=$false
                    lastWriteTimeUtc=$child.LastWriteTimeUtc.ToString('o')
                    containedByApprovedRoot=$true
                    filesRead=$false
                    imageBytesRead=$false
                    sourceHashingPerformed=$false
                    mutationsPerformed=$false
                }
                if([bool]$child.PSIsContainer){
                    if($directories.Count-ge$MaximumDirectories){$truncated=$true;break}
                    $directories.Add([pscustomobject]$common)
                    if($depth-lt$MaximumDepth){$queue.Enqueue([pscustomobject]@{readPath=$aliasRead;subtreeRelativePath=$childRelative;canonicalPath=$canonicalPath;depth=$depth})}else{$depthBoundaryDirectoryCount++}
                }elseif([string]$child.Extension-eq'.bmp'){
                    if($bmpLeaves.Count-ge$MaximumBmpLeaves){$truncated=$true;break}
                    $common['extension']='.bmp'
                    $common['length']=[int64]$child.Length
                    $bmpLeaves.Add([pscustomobject]$common)
                }else{$otherLeafCount++}
            }
        }
    }finally{
        if($aliasCreated){Remove-PSDrive -Name $AliasName -Scope Script -Force -ErrorAction Stop;$aliasRemoved=-not[bool](Get-PSDrive -Name $AliasName -ErrorAction SilentlyContinue)}
    }
}
if(-not$aliasRemoved){throw 'Process-local alias was not removed.'}

$directoryArray=$directories.ToArray()
$bmpArray=$bmpLeaves.ToArray()
$skipArray=$skipRows.ToArray()
$errorArray=$accessErrors.ToArray()
$complete=($rootExists-and-not$truncated-and$errorArray.Count-eq0-and$skipArray.Count-eq0-and$depthBoundaryDirectoryCount-eq0)
[ordered]@{
    schema='argos_ocv00_deepest_alias_inventory_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state=if($complete){'COMPLETE'}else{'HOLD_INCOMPLETE'}
    approvedRoot=$approvedRootFull
    relativeSubtree=$RelativeSubtree
    requestedSubtreeRoot=$physicalSubtree
    canonicalProvenanceRoot=$canonicalSubtree
    aliasRoot=$aliasRoot
    aliasAnchor='EXACT_REQUESTED_SUBTREE_ROOT'
    rootExists=$rootExists
    complete=$complete
    maximumDepth=$MaximumDepth
    maximumEntries=$MaximumEntries
    maximumDirectories=$MaximumDirectories
    maximumBmpLeaves=$MaximumBmpLeaves
    entriesVisited=$entriesVisited
    directoriesEnumerated=$directoriesEnumerated
    directories=$directoryArray
    directoryCount=$directoryArray.Count
    bmpLeaves=$bmpArray
    bmpLeafCount=$bmpArray.Count
    otherLeafCount=$otherLeafCount
    skippedPathRows=$skipArray
    skippedPathRowCount=$skipArray.Count
    skippedUnsafePathSubtrees=@($skipArray|Where-Object{[string]$_.rejectionReason-ne'REPARSE_CHILD_NOT_TRAVERSED'}).Count
    skippedReparseSubtrees=@($skipArray|Where-Object{[string]$_.rejectionReason-eq'REPARSE_CHILD_NOT_TRAVERSED'}).Count
    accessErrors=$errorArray
    accessErrorCount=$errorArray.Count
    depthBoundaryDirectoryCount=$depthBoundaryDirectoryCount
    truncated=$truncated
    processLocalAlias=[ordered]@{name=$AliasName;root=$physicalSubtree;created=$aliasCreated;removed=$aliasRemoved;persistent=$false}
    pathsEnumerated=$true
    filesRead=$false
    imageBytesRead=$false
    sourceHashingPerformed=$false
    mutationsPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 10
