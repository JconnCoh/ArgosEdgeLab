[CmdletBinding()]
param(
    [string]$InstallRoot='C:\ProgramData\ArgosInsiteBridgeRO',
    [string]$WorkerTaskName='ArgosEdgeLab.InsiteBridge.Worker.ReviewOnly.V1',
    [switch]$Rehearsal
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Write-AtomicJson([string]$Path,[object]$Value,[int]$Depth=18){
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    $temp=$Path+'.partial.'+[Guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    if(Test-Path -LiteralPath $Path){$backup=$Path+'.backup.'+[Guid]::NewGuid().ToString('N');[IO.File]::Replace($temp,$Path,$backup,$true)}else{[IO.File]::Move($temp,$Path)}
}
function Assert([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Test-QualifiedResponse([string]$Path){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $false}
    try{$snapshot=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json}catch{return $false}
    $rows=@($snapshot.records|Where-Object{([string]$_.scribe).Trim().ToUpperInvariant()-eq'0737S071FEB3'})
    if($rows.Count-ne1){return $false}
    $row=$rows[0]
    [string]$row.queryState-eq'MES_READ_ONLY_SNAPSHOT' -and
    [string]$row.lineage.state-eq'MES_SCRIBE_LINEAGE_EXACT' -and
    [string]$row.lineage.resolutionAuthority-in@('DIRECT_INSITE_CONTAINER_SUBSTRATE_EXACT','ISSUE_HISTORY_AND_DIRECT_UNIT_CONTAINER_AGREE') -and
    [string]$row.lineage.directUnitContainer-eq'62631-586-070' -and
    [string]$row.lineage.issuedWaferContainer-eq'62631-586-070' -and
    [string]$row.lineage.mesStateContainer-eq'62631-586' -and
    -not[bool]$row.lineage.lotSlotIdentityAuthorityUsed -and
    [string]$row.visualState.state-eq'COMPLETE' -and
    [string]$row.visualState.productName-eq'1498994' -and
    [string]$row.visualState.productRevision-eq'A00' -and
    [string]$row.visualState.prodFamily-eq'3393-901'
}

$install=[IO.Path]::GetFullPath($InstallRoot)
if(-not$Rehearsal-and$install-ne'C:\ProgramData\ArgosInsiteBridgeRO'){
    throw "Live direct-unit query patch refused noncanonical root: $install"
}
$queryRoot=Join-Path $install 'query'
$mainPath=Join-Path $queryRoot 'Invoke-ArgosMesVisualStateSnapshot.ps1'
$resolverPath=Join-Path $queryRoot 'Resolve-ArgosExactScribeLineage.ps1'
$expected=[ordered]@{
    $mainPath='D15DA5FEE86B528F12B61B5DD0B4A510593D1A7AA5B60D6491DD951AEF4053CB'
    $resolverPath='45DEDB48B7DAFA634A8CB86ABE46314E0644ED9DA5506999A8FAA7BB022E0186'
}
$installedRows=New-Object Collections.Generic.List[object]
foreach($path in $expected.Keys){
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Installed query file is missing: $path"}
    $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if($hash-ne$expected[$path]){throw "Installed query hash mismatch: $path actual=$hash"}
    $tokens=$null;$parseErrors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$parseErrors)
    if(@($parseErrors).Count){throw "Installed query parse failure: $path $($parseErrors.Message -join ' | ')"}
    $installedRows.Add([pscustomobject]@{path=$path;sha256=$hash;parseErrors=0})
}
. $resolverPath

$scribe='0737S071FEB3'
$epi=[pscustomobject]@{EpiWaferNumber='152619-376H-1'}
$issue=[pscustomobject]@{IssuedWaferContainer='62631-586-070';MesStateContainer='62631-586'}
$direct=[pscustomobject]@{UnitContainer='62631-586-070';ParentContainer='62631-586'}
$directOnly=Resolve-ArgosExactScribeLineage -Scribe $scribe -EpiMatches @($epi) -DirectContainerMatches @($direct)
$issueOnly=Resolve-ArgosExactScribeLineage -Scribe $scribe -EpiMatches @($epi) -IssueLineageMatches @($issue)
$agree=Resolve-ArgosExactScribeLineage -Scribe $scribe -EpiMatches @($epi) -IssueLineageMatches @($issue) -DirectContainerMatches @($direct)
$conflict=Resolve-ArgosExactScribeLineage -Scribe $scribe -EpiMatches @($epi) -IssueLineageMatches @($issue) -DirectContainerMatches @([pscustomobject]@{UnitContainer='62631-999-070';ParentContainer='62631-999'})
$multiple=Resolve-ArgosExactScribeLineage -Scribe $scribe -EpiMatches @($epi) -DirectContainerMatches @($direct,[pscustomobject]@{UnitContainer='62631-586-071';ParentContainer='62631-586'})
$noEpi=Resolve-ArgosExactScribeLineage -Scribe $scribe -DirectContainerMatches @($direct)
$noContainer=Resolve-ArgosExactScribeLineage -Scribe $scribe -EpiMatches @($epi)
Assert ($directOnly.lineageState-eq'MES_SCRIBE_LINEAGE_EXACT'-and$directOnly.lineageResolutionAuthority-eq'DIRECT_INSITE_CONTAINER_SUBSTRATE_EXACT') 'Installed resolver direct-only case failed.'
Assert ($issueOnly.lineageState-eq'MES_SCRIBE_LINEAGE_EXACT'-and$issueOnly.lineageResolutionAuthority-eq'ISSUE_HISTORY_EXACT') 'Installed resolver historical issue path regressed.'
Assert ($agree.lineageState-eq'MES_SCRIBE_LINEAGE_EXACT') 'Installed resolver agreeing case failed.'
Assert ($conflict.lineageState-eq'MES_LOOKUP_HOLD_AMBIGUOUS_LINEAGE'-and$multiple.lineageState-eq'MES_LOOKUP_HOLD_AMBIGUOUS_LINEAGE') 'Installed resolver ambiguity gate failed.'
Assert ($noEpi.lineageState-eq'MES_LOOKUP_HOLD_NO_ROW'-and$noContainer.lineageState-eq'MES_LOOKUP_HOLD_NO_ROW') 'Installed resolver missing-evidence gate failed.'
Assert (-not$directOnly.lotSlotIdentityAuthorityUsed-and-not$agree.lotSlotIdentityAuthorityUsed) 'Installed resolver enabled lot/slot identity authority.'

$pendingRoot=Join-Path $install 'request_inbox\pending'
$processedRoot=Join-Path $install 'request_inbox\processed'
$responsePending=Join-Path $install 'response_queue\pending'
$responseSent=Join-Path $install 'response_queue\sent'
foreach($root in @($pendingRoot,$processedRoot,$responsePending,$responseSent)){
    if(-not(Test-Path -LiteralPath $root -PathType Container)){throw "Required Insite queue root is missing: $root"}
}
$requestRows=New-Object Collections.Generic.List[object]
foreach($location in @([pscustomobject]@{state='PENDING';root=$pendingRoot},[pscustomobject]@{state='PROCESSED';root=$processedRoot})){
    foreach($package in @(Get-ChildItem -LiteralPath $location.root -Directory -Filter 'INSITE_REQ__*.ready' -ErrorAction SilentlyContinue)){
        $payload=Join-Path $package.FullName 'PENDING_INSITE_REQUEST.json'
        $manifestPath=Join-Path $package.FullName 'INSITE_REQUEST_MANIFEST.json'
        if(-not(Test-Path -LiteralPath $payload -PathType Leaf)-or-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){continue}
        try{$request=Get-Content -LiteralPath $payload -Raw|ConvertFrom-Json;$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json}catch{continue}
        $target=@($request.rows|Where-Object{([string]$_.scribe).Trim().ToUpperInvariant()-eq$scribe})
        if($target.Count-ne1){continue}
        $keys=@($target[0].acquisitionKeys|ForEach-Object{([string]$_).Trim().ToUpperInvariant()})
        if($keys-notcontains'62631-586_20260806152140_SLOT24'-or$keys-notcontains'62631-586_20260814131935_SLOT07'){continue}
        $contentHash=(Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash
        if($contentHash-ne([string]$manifest.requestContentSha256).ToUpperInvariant()){throw "Insite request content hash mismatch: $($package.FullName)"}
        $requestRows.Add([pscustomobject]@{package=$package;queueState=$location.state;payload=$payload;contentHash=$contentHash;acquisitionKeys=$keys})
    }
}
if($requestRows.Count-lt1){throw 'No exact processed/pending Insite request contains both target acquisitions for 0737S071FEB3.'}
$selected=@($requestRows|Sort-Object @{Expression={$_.package.LastWriteTimeUtc};Descending=$true})[0]
$responseId='INSITE_RESP__'+$selected.contentHash.Substring(0,32)
$responseLocations=@(
    [pscustomobject]@{state='PENDING';path=Join-Path $responsePending ($responseId+'.ready')},
    [pscustomobject]@{state='SENT';path=Join-Path $responseSent ($responseId+'.ready')}
)
$qualified=$null
foreach($candidate in $responseLocations){
    if(Test-QualifiedResponse (Join-Path $candidate.path 'INSITE_RESPONSE.json')){$qualified=$candidate;break}
}

$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$hotfixRoot=Join-Path $install ('state\hotfixes\DIRECT_UNIT_CONTAINER_QUERY_'+$stamp)
[void](New-Item -ItemType Directory -Path $hotfixRoot -Force)
$queueChanged=$false;$responsesQuarantined=New-Object Collections.Generic.List[object]
if($null-eq$qualified){
    $taskWasRunning=$false
    if(-not$Rehearsal){
        $task=Get-ScheduledTask -TaskName $WorkerTaskName -ErrorAction Stop
        if([string]$task.State-ne'Running'){throw "Insite worker must be running before exact requery: $WorkerTaskName state=$($task.State)"}
        $taskWasRunning=$true
        Stop-ScheduledTask -TaskName $WorkerTaskName
        $deadline=(Get-Date).AddSeconds(30)
        do{Start-Sleep -Milliseconds 250;$task=Get-ScheduledTask -TaskName $WorkerTaskName}while([string]$task.State-eq'Running'-and(Get-Date)-lt$deadline)
        if([string]$task.State-eq'Running'){throw "Insite worker did not stop: $WorkerTaskName"}
    }
    $requestOriginal=$selected.package.FullName
    $requestPendingPath=Join-Path $pendingRoot $selected.package.Name
    try{
        foreach($candidate in $responseLocations){
            if(Test-Path -LiteralPath $candidate.path -PathType Container){
                $held=Join-Path $hotfixRoot ('stale_'+$candidate.state.ToLowerInvariant()+'_'+[IO.Path]::GetFileName($candidate.path))
                Move-Item -LiteralPath $candidate.path -Destination $held
                $responsesQuarantined.Add([pscustomobject]@{original=$candidate.path;quarantine=$held;state=$candidate.state})
            }
        }
        if($selected.queueState-eq'PROCESSED'){
            if(Test-Path -LiteralPath $requestPendingPath){throw "Exact requery pending destination exists: $requestPendingPath"}
            Move-Item -LiteralPath $requestOriginal -Destination $requestPendingPath
            $queueChanged=$true
        }
        if(-not$Rehearsal-and$taskWasRunning){Start-ScheduledTask -TaskName $WorkerTaskName}
    }catch{
        if($queueChanged-and(Test-Path -LiteralPath $requestPendingPath)-and-not(Test-Path -LiteralPath $requestOriginal)){Move-Item -LiteralPath $requestPendingPath -Destination $requestOriginal}
        foreach($moved in $responsesQuarantined){if((Test-Path -LiteralPath $moved.quarantine)-and-not(Test-Path -LiteralPath $moved.original)){Move-Item -LiteralPath $moved.quarantine -Destination $moved.original}}
        if(-not$Rehearsal-and$taskWasRunning){$task=Get-ScheduledTask -TaskName $WorkerTaskName -ErrorAction SilentlyContinue;if($null-ne$task-and[string]$task.State-ne'Running'){Start-ScheduledTask -TaskName $WorkerTaskName}}
        throw
    }
}

$qualifiedState=$null
if($null-ne$qualified){$qualifiedState=[string]$qualified.state}
$quarantineRows=$responsesQuarantined.ToArray()
$workerRestarted=$false
if(-not$Rehearsal-and$null-eq$qualified){$workerRestarted=$true}
$result=[ordered]@{
    schema='argos_direct_unit_container_query_apply_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_ARGOS_DIRECT_UNIT_CONTAINER_QUERY_PATCH_REVIEW_ONLY'
    installedFiles=$installedRows.ToArray();resolverCases=7;exactScribe=$scribe
    exactUnitContainer='62631-586-070';exactParentContainer='62631-586';product='1498994/A00';prodFamily='3393-901'
    selectedRequest=$selected.package.Name;requestContentSha256=$selected.contentHash;targetAcquisitionKeys=$selected.acquisitionKeys
    qualifiedResponseAlreadyPresent=($null-ne$qualified);qualifiedResponseQueue=$qualifiedState
    requeryQueued=($null-eq$qualified);requestMovedFromProcessed=$queueChanged;staleResponsesQuarantined=$responsesQuarantined.Count
    staleResponseQuarantine=$quarantineRows;workerRestarted=$workerRestarted
    lotSlotIdentityAuthorityUsed=$false;rawImagesChanged=$false;detectorChanged=$false;xmlChanged=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-AtomicJson (Join-Path $hotfixRoot 'APPLY_RESULT.json') $result 20
[pscustomobject]$result|Format-List
