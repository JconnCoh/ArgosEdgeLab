[CmdletBinding(DefaultParameterSetName='Query')]
param(
    [Parameter(Mandatory=$true,ParameterSetName='Query')][string]$RequestPath,
    [Parameter(Mandatory=$true,ParameterSetName='Query')][Management.Automation.PSCredential]$SqlCredential,
    [Parameter(Mandatory=$true,ParameterSetName='Query')][string]$OutputPath,
    [Parameter(Mandatory=$true,ParameterSetName='RouteRehearsal')][string]$RouteRehearsalManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Value-OrNull([object]$Value) {
    if ($null -eq $Value -or $Value -is [DBNull]) { return $null }
    return $Value
}

function Resource-FromSummary([object]$Summary) {
    if ($null -eq $Summary -or $Summary -is [DBNull]) { return $null }
    $text = [string]$Summary
    if ($text -match '(?i)Resource:\s*(?<resource>[^,.\r\n]+)') {
        return $Matches.resource.Trim()
    }
    return $null
}

function Get-FrontsideScratchTestRoute {
    param(
        [Parameter(Mandatory=$true)][AllowNull()][AllowEmptyCollection()][object[]]$HistoryRows,
        [Parameter(Mandatory=$true)][DateTime]$ScanTime
    )

    if ($null -eq $HistoryRows) { $HistoryRows = @() }

    # The dielectric scratch-test family is established by the actual Insite
    # history, never by an Argos recipe-folder name. Repeating scratch-test lots
    # may have multiple numbered instances of the sacrificial-nitride block. The
    # anchor is the latest qualifying numbered deposition MoveIn at or before
    # the exact scan. Follow-on moves inside only that selected block instance
    # are part of its deposition flow. Once the flow leaves the selected block,
    # only the two inspection-tool families approved by the operator may have a
    # nonblank resource before the Argos acquisition.
    $eligibleRows = @($HistoryRows | Where-Object {
        $_.TxnDate -isnot [DBNull] -and [DateTime]$_.TxnDate -le $ScanTime
    } | Sort-Object { [DateTime]$_.TxnDate },HistoryMainlineId)
    $anchor=$null
    $anchorIndex=-1
    for($index=0;$index-lt$eligibleRows.Count;$index++){
        $row=$eligibleRows[$index]
        $processBlock=([string]$row.ProcessBlockName).Trim()
        if($processBlock -match '^SACRIFICIAL NITRIDE DEP \{[1-9][0-9]*\}$' -and
           ([string]$row.WorkflowStepName).Trim() -eq 'NITRIDE_DEP' -and
           (Resource-FromSummary $row.TxnSummary) -match '(?i)^6-4-CVD-[0-9]+$'){
            $anchor=$row
            $anchorIndex=$index
        }
    }
    if($null-eq$anchor){
        return [pscustomobject][ordered]@{
            state='HOLD_FRONTSIDE_SCRATCH_TEST_NITRIDE_ANCHOR_NOT_FOUND'
            authority='INSITE_MOVEIN_HISTORY_BEFORE_EXACT_ARGOS_ACQUISITION'
            fingerprintVersion='FRONTSIDE_SCRATCH_TEST_ROUTE_V3'
            anchor=$null;postAnchorResourceRows=@();disallowedResourceRows=@()
        }
    }
    $anchorDate=[DateTime]$anchor.TxnDate
    $anchorProcessBlock=([string]$anchor.ProcessBlockName).Trim()
    $postRows=if($anchorIndex+1-lt$eligibleRows.Count){@($eligibleRows[($anchorIndex+1)..($eligibleRows.Count-1)])}else{@()}
    $resourceRows=New-Object Collections.Generic.List[object]
    $disallowed=New-Object Collections.Generic.List[object]
    foreach($row in $postRows){
        $resource=Resource-FromSummary $row.TxnSummary
        if([string]::IsNullOrWhiteSpace($resource)){continue}
        $processBlock=([string]$row.ProcessBlockName).Trim()
        $isSameDepositionFlow=$processBlock -eq $anchorProcessBlock
        $isApprovedInspectionTool=$resource -match '(?i)(?:EAGLE|LV1?150MM)'
        $evidence=[pscustomobject][ordered]@{
            processBlock=Value-OrNull $row.ProcessBlockName
            step=Value-OrNull $row.WorkflowStepName
            txnDate=([DateTime]$row.TxnDate).ToString('yyyy-MM-ddTHH:mm:ss')
            historyMainlineId=Value-OrNull $row.HistoryMainlineId
            resource=$resource
            disposition=if($isSameDepositionFlow){'ALLOWED_SAME_NITRIDE_PROCESS_BLOCK'}elseif($isApprovedInspectionTool){'ALLOWED_INSPECTION_TOOL'}else{'DISALLOWED_POST_ANCHOR_RESOURCE'}
        }
        $resourceRows.Add($evidence)
        if(-not $isSameDepositionFlow -and -not $isApprovedInspectionTool){$disallowed.Add($evidence)}
    }
    return [pscustomobject][ordered]@{
        state=if($disallowed.Count -eq 0){'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED'}else{'HOLD_FRONTSIDE_SCRATCH_TEST_POST_ANCHOR_MATERIAL_TOOL_PRESENT'}
        authority='INSITE_MOVEIN_HISTORY_BEFORE_EXACT_ARGOS_ACQUISITION'
        fingerprintVersion='FRONTSIDE_SCRATCH_TEST_ROUTE_V3'
        anchor=[ordered]@{
            processBlock=Value-OrNull $anchor.ProcessBlockName
            step=Value-OrNull $anchor.WorkflowStepName
            txnDate=$anchorDate.ToString('yyyy-MM-ddTHH:mm:ss')
            historyMainlineId=Value-OrNull $anchor.HistoryMainlineId
            resource=Resource-FromSummary $anchor.TxnSummary
        }
        postAnchorResourceRows=@($resourceRows.ToArray())
        disallowedResourceRows=@($disallowed.ToArray())
    }
}

if($PSCmdlet.ParameterSetName-eq'RouteRehearsal'){
    $routeManifestPath=[IO.Path]::GetFullPath($RouteRehearsalManifest)
    if(-not(Test-Path -LiteralPath $routeManifestPath -PathType Leaf)){throw 'Route rehearsal manifest is missing.'}
    if((Get-Item -LiteralPath $routeManifestPath).Length-gt1048576){throw 'Route rehearsal manifest exceeds 1 MiB.'}
    $routeManifest=Get-Content -LiteralPath $routeManifestPath -Raw|ConvertFrom-Json
    if([string]$routeManifest.schema-ne'argos_frontside_scratch_test_route_rehearsal_v1' -or
       -not[bool]$routeManifest.rehearsal){throw 'Route rehearsal manifest contract refused.'}
    $routeResult=Get-FrontsideScratchTestRoute -HistoryRows @($routeManifest.historyRows) `
        -ScanTime ([DateTime]::Parse([string]$routeManifest.scanTime,[Globalization.CultureInfo]::InvariantCulture))
    [ordered]@{
        schema='argos_frontside_scratch_test_route_rehearsal_result_v1'
        state=[string]$routeResult.state
        fingerprintVersion=[string]$routeResult.fingerprintVersion
        anchor=$routeResult.anchor
        postAnchorResourceRows=@($routeResult.postAnchorResourceRows)
        disallowedResourceRows=@($routeResult.disallowedResourceRows)
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    }|ConvertTo-Json -Depth 10
    return
}

function Read-MoveInHistory {
    param(
        [string]$SqlServer,
        [string]$Database,
        [Management.Automation.PSCredential]$Credential,
        [string[]]$Containers
    )
    $table = [Data.DataTable]::new()
    if ($Containers.Count -eq 0) { return $table }
    $builder = [Data.SqlClient.SqlConnectionStringBuilder]::new()
    $builder['Data Source'] = $SqlServer
    $builder['Initial Catalog'] = $Database
    $builder['User ID'] = $Credential.UserName
    $builder['Password'] = $Credential.GetNetworkCredential().Password
    $builder['Integrated Security'] = $false
    $builder['Encrypt'] = $true
    $builder['TrustServerCertificate'] = $true
    $builder['Application Name'] = 'ArgosEdgeLabReadOnlyAcquisitionContext'
    $connection = [Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
    try {
        $connection.Open()
        $command = $connection.CreateCommand()
        $command.CommandTimeout = 120
        $parameterNames = New-Object Collections.Generic.List[string]
        for ($i = 0; $i -lt $Containers.Count; $i++) {
            $name = '@container' + $i
            [void]$parameterNames.Add($name)
            [void]$command.Parameters.Add($name,[Data.SqlDbType]::NVarChar,128)
            $command.Parameters[$name].Value = $Containers[$i]
        }
        $command.CommandText = @"
select
    c.ContainerName,
    ws.WorkflowStepName,
    pb.WorkflowStepName as ProcessBlockName,
    hm.TxnServiceName,
    hm.TxnType,
    hm.TxnDate,
    hm.HistoryMainlineId,
    hm.TxnSummary
from Insite.HistoryMainline hm
join Insite.Container c on c.ContainerId = hm.ContainerId
left join Insite.WorkflowStep ws on ws.WorkflowStepId = hm.WorkflowStepId
left join Insite.WorkflowStep pb on pb.WorkflowStepId = hm.fnsr_ProcessBlockId
where c.ContainerName in ($($parameterNames -join ','))
  and hm.TxnServiceName = 'MoveIn'
order by c.ContainerName, hm.TxnDate, hm.HistoryMainlineId
"@
        $adapter = [Data.SqlClient.SqlDataAdapter]::new($command)
        [void]$adapter.Fill($table)
        $adapter.Dispose()
        $command.Dispose()
        return ,$table
    }
    finally {
        if ($connection.State -ne 'Closed') { $connection.Close() }
        $connection.Dispose()
        $builder['Password'] = ''
    }
}
$requestPath=(Resolve-Path -LiteralPath $RequestPath).Path
$outputPath=[IO.Path]::GetFullPath($OutputPath)
if(Test-Path -LiteralPath $outputPath){throw "Refusing existing output: $outputPath"}
$request=Get-Content -LiteralPath $requestPath -Raw|ConvertFrom-Json
$compatibility=$null
if($request.PSObject.Properties.Name-contains'transportEnvelope'){
    $canonicalModule=Join-Path $PSScriptRoot 'ArgosInsiteRequestCanonical.psm1'
    $candidateQuery=Join-Path $PSScriptRoot 'Invoke-ArgosCandidateInsiteRequest.ps1'
    foreach($dependency in @($canonicalModule,$candidateQuery)){
        if(-not(Test-Path -LiteralPath $dependency -PathType Leaf)){throw "Candidate compatibility dependency missing: $dependency"}
    }
    Import-Module -Name $canonicalModule -Force -ErrorAction Stop
    $compatibility=Get-ArgosLegacyRelayCandidateCompatibility -Request $request
}
if($null-ne$compatibility){
    $outerRequestHash=Get-ArgosInsiteRequestCanonicalHashV2 -Request $request
    $innerRequestHash=[string]$compatibility.candidateRequestContentSha256
    $innerRequestPath=$outputPath+'.candidate-request.'+[Guid]::NewGuid().ToString('N')+'.json'
    try{
        [IO.File]::WriteAllText(
            $innerRequestPath,
            (($compatibility.candidateRequest|ConvertTo-Json -Depth 18)+[Environment]::NewLine),
            [Text.UTF8Encoding]::new($false)
        )
        & $candidateQuery -RequestPath $innerRequestPath -SqlCredential $SqlCredential `
            -OutputPath $outputPath -ExpectedRequestContentSha256 $innerRequestHash|Out-Null
    }finally{
        if(Test-Path -LiteralPath $innerRequestPath){Remove-Item -LiteralPath $innerRequestPath -Force -ErrorAction SilentlyContinue}
    }
    $candidateSnapshot=Get-Content -LiteralPath $outputPath -Raw|ConvertFrom-Json
    if([string]$candidateSnapshot.authority-ne'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT' -or
       [string]$candidateSnapshot.lookupKey-ne'current-image-supported canonical M12 candidate scribe' -or
       [string]$candidateSnapshot.requestContentSha256-ne$innerRequestHash){
        throw 'Candidate compatibility query result contract refused.'
    }
    $candidateSnapshot.lookupKey='confirmed 12-character wafer scribe'
    $candidateSnapshot|Add-Member -NotePropertyName transportEnvelope -NotePropertyValue `
        'ARGOS_CURRENT_IMAGE_CANDIDATE_OVER_LEGACY_RELAY_V1' -Force
    $candidateSnapshot|Add-Member -NotePropertyName transportLookupKey -NotePropertyValue `
        'current-image-supported canonical M12 candidate scribe' -Force
    $candidateSnapshot|Add-Member -NotePropertyName transportRequestKind -NotePropertyValue `
        'CURRENT_IMAGE_CANDIDATE' -Force
    $candidateSnapshot|Add-Member -NotePropertyName transportRequestContentSha256 `
        -NotePropertyValue $outerRequestHash -Force
    $candidateSnapshot|Add-Member -NotePropertyName transportCandidateRequestContentSha256 `
        -NotePropertyValue $innerRequestHash -Force
    $candidateSnapshot|Add-Member -NotePropertyName transportCandidateRequest `
        -NotePropertyValue $compatibility.candidateRequest -Force
    [IO.File]::WriteAllText(
        $outputPath,
        (($candidateSnapshot|ConvertTo-Json -Depth 20)+[Environment]::NewLine),
        [Text.UTF8Encoding]::new($false)
    )
    [pscustomobject]@{
        State='PASS_LEGACY_RELAY_CANDIDATE_INSITE_REQUEST_QUERIED_READ_ONLY'
        RequestedScribes=@($compatibility.innerContract.scribes).Count
        RequestedAcquisitions=@($compatibility.innerContract.acquisitionKeys).Count
        OutputPath=$outputPath
        SHA256=(Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
    }|Format-List
    return
}
if([string]$request.schema-ne'argos_jbod_pending_insite_request_v1' -or
   [string]$request.state-ne'PENDING_CONFIRMED_SCRIBE_READ_ONLY_INSITE_LOOKUP' -or
   [string]$request.lookupKey-ne'confirmed 12-character wafer scribe' -or
   [bool]$request.imagesIncluded -or [bool]$request.credentialsIncluded -or
   -not[bool]$request.reviewOnly -or [bool]$request.trainingEligible -or
   [bool]$request.xmlEligible -or [bool]$request.productionEligible){
    throw 'Pending Insite request contract refused.'
}
$scribes=@($request.rows|ForEach-Object{([string]$_.scribe).Trim().ToUpperInvariant()}|Sort-Object -Unique)
if($scribes.Count-ne[int]$request.pendingScribes){throw 'Pending scribe count does not match the request manifest.'}
foreach($scribe in $scribes){if($scribe-notmatch'^[A-Z0-9]{12}$'){throw "Invalid pending scribe: $scribe"}}
if($scribes.Count-eq0){throw 'Pending Insite request contains no scribes.'}

& (Join-Path $PSScriptRoot 'Invoke-ArgosMesVisualStateSnapshot.ps1') `
    -Scribe $scribes -SqlCredential $SqlCredential -OutputPath $outputPath|Out-Null
$snapshot=Get-Content -LiteralPath $outputPath -Raw|ConvertFrom-Json
if([string]$snapshot.authority-ne'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT' -or
   @($snapshot.records).Count-ne$scribes.Count){throw 'Generated snapshot count/authority validation failed.'}

# Current WIP is useful for current routing, but it is not acquisition-time
# appearance authority. Add the exact MoveIn immediately before and after
# each acquisition without changing the existing current-state fields.
$requestByScribe = @{}
foreach ($row in @($request.rows)) {
    $scribe = ([string]$row.scribe).Trim().ToUpperInvariant()
    if (-not $requestByScribe.ContainsKey($scribe)) {
        $requestByScribe[$scribe] = New-Object Collections.Generic.List[string]
    }
    foreach ($keyValue in @($row.acquisitionKeys)) {
        $key = ([string]$keyValue).Trim().ToUpperInvariant()
        if ($key) { $requestByScribe[$scribe].Add($key) }
    }
}
$historyContainers = @($snapshot.records | ForEach-Object {
    [string]$_.lineage.historyBaseLot
} | Where-Object { $_ } | Sort-Object -Unique)
$historyTable = Read-MoveInHistory -SqlServer ([string]$snapshot.serverTarget) `
    -Database ([string]$snapshot.database) -Credential $SqlCredential `
    -Containers $historyContainers
$historyByContainer = @{}
foreach ($historyRow in $historyTable.Rows) {
    $container = [string]$historyRow.ContainerName
    if (-not $historyByContainer.ContainsKey($container)) {
        $historyByContainer[$container] = New-Object Collections.Generic.List[object]
    }
    $historyByContainer[$container].Add($historyRow)
}

$enrichedRecords = foreach ($record in @($snapshot.records)) {
    $scribe = ([string]$record.scribe).Trim().ToUpperInvariant()
    $contexts = New-Object Collections.Generic.List[object]
    if ($requestByScribe.ContainsKey($scribe)) {
        foreach ($acquisitionKey in @($requestByScribe[$scribe].ToArray() | Sort-Object -Unique)) {
            $match = [regex]::Match($acquisitionKey,'^(?<prefix>.+)_(?<timestamp>\d{14})_(?<slot>SLOT\d+)$')
            if (-not $match.Success) {
                $contexts.Add([pscustomobject][ordered]@{
                    acquisitionKey=$acquisitionKey
                    state='HOLD_ACQUISITION_KEY_TIMESTAMP_UNPARSEABLE'
                    authority='NONE'
                })
                continue
            }
            $scanTime = [DateTime]::ParseExact($match.Groups['timestamp'].Value,
                'yyyyMMddHHmmss',[Globalization.CultureInfo]::InvariantCulture,
                [Globalization.DateTimeStyles]::AssumeLocal)
            $baseLot = [string]$record.lineage.historyBaseLot
            $historyRows = if ($baseLot -and $historyByContainer.ContainsKey($baseLot)) {
                @($historyByContainer[$baseLot].ToArray())
            } else { @() }
            $prior = @($historyRows | Where-Object {
                $_.TxnDate -isnot [DBNull] -and [DateTime]$_.TxnDate -le $scanTime
            } | Sort-Object { [DateTime]$_.TxnDate },HistoryMainlineId | Select-Object -Last 1)
            $next = @($historyRows | Where-Object {
                $_.TxnDate -isnot [DBNull] -and [DateTime]$_.TxnDate -gt $scanTime
            } | Sort-Object { [DateTime]$_.TxnDate },HistoryMainlineId | Select-Object -First 1)
            $priorWithResource = @($historyRows | Where-Object {
                $_.TxnDate -isnot [DBNull] -and [DateTime]$_.TxnDate -le $scanTime -and
                (Resource-FromSummary $_.TxnSummary)
            } | Sort-Object { [DateTime]$_.TxnDate },HistoryMainlineId | Select-Object -Last 1)
            $priorRow = if ($prior.Count -eq 1) { $prior[0] } else { $null }
            $nextRow = if ($next.Count -eq 1) { $next[0] } else { $null }
            $priorResourceRow = if ($priorWithResource.Count -eq 1) { $priorWithResource[0] } else { $null }
            $frontsideScratchTestRoute = Get-FrontsideScratchTestRoute -HistoryRows $historyRows -ScanTime $scanTime
            $contexts.Add([pscustomobject][ordered]@{
                acquisitionKey=$acquisitionKey
                state=if($priorRow){'EXACT_PRIOR_MOVEIN_FOUND'}else{'HOLD_NO_PRIOR_MOVEIN_AT_SCAN_TIME'}
                authority=if($priorRow){'LAST_INSITE_MOVEIN_PRECEDING_ARGOS_SCAN'}else{'NONE'}
                scanTimestampLocal=$scanTime.ToString('yyyy-MM-ddTHH:mm:ss')
                timestampBasis='ARGOS_ACQUISITION_KEY_LOCAL_TIME_TIMEZONE_UNSPECIFIED'
                priorMoveIn=if($priorRow){[ordered]@{
                    processBlock=Value-OrNull $priorRow.ProcessBlockName
                    step=Value-OrNull $priorRow.WorkflowStepName
                    txnDate=([DateTime]$priorRow.TxnDate).ToString('yyyy-MM-ddTHH:mm:ss')
                    historyMainlineId=Value-OrNull $priorRow.HistoryMainlineId
                    resource=Resource-FromSummary $priorRow.TxnSummary
                    summary=Value-OrNull $priorRow.TxnSummary
                }}else{$null}
                nextMoveIn=if($nextRow){[ordered]@{
                    processBlock=Value-OrNull $nextRow.ProcessBlockName
                    step=Value-OrNull $nextRow.WorkflowStepName
                    txnDate=([DateTime]$nextRow.TxnDate).ToString('yyyy-MM-ddTHH:mm:ss')
                    historyMainlineId=Value-OrNull $nextRow.HistoryMainlineId
                    resource=Resource-FromSummary $nextRow.TxnSummary
                    summary=Value-OrNull $nextRow.TxnSummary
                }}else{$null}
                priorResourceMoveIn=if($priorResourceRow){[ordered]@{
                    processBlock=Value-OrNull $priorResourceRow.ProcessBlockName
                    step=Value-OrNull $priorResourceRow.WorkflowStepName
                    txnDate=([DateTime]$priorResourceRow.TxnDate).ToString('yyyy-MM-ddTHH:mm:ss')
                    historyMainlineId=Value-OrNull $priorResourceRow.HistoryMainlineId
                    resource=Resource-FromSummary $priorResourceRow.TxnSummary
                    summary=Value-OrNull $priorResourceRow.TxnSummary
                }}else{$null}
                frontsideScratchTestRoute=$frontsideScratchTestRoute
            })
        }
    }
    $copy = [ordered]@{}
    foreach ($property in $record.PSObject.Properties) { $copy[$property.Name] = $property.Value }
    $copy['acquisitionContexts'] = @($contexts.ToArray())
    [pscustomobject]$copy
}
$snapshot.records = @($enrichedRecords)
$snapshot | Add-Member -NotePropertyName acquisitionContextContract -NotePropertyValue `
    'LAST_MOVEIN_AT_OR_BEFORE_ARGOS_ACQUISITION_TIMESTAMP; NEXT_MOVEIN_AFTER; RECIPE_FOLDER_NAMES_UNUSED' -Force
$snapshot | Add-Member -NotePropertyName frontsideScratchTestRouteContract -NotePropertyValue `
    'LATEST_QUALIFYING_NUMBERED_SACRIFICIAL_NITRIDE_DEP_ANCHOR_AT_OR_BEFORE_EXACT_SCAN; SELECTED_BLOCK_INSTANCE_FOLLOW_ON_ALLOWED; EAGLE_OR_LV150MM_ONLY_AFTER_SELECTED_BLOCK; RECIPE_FOLDER_NAMES_UNUSED' -Force
[IO.File]::WriteAllText($outputPath,(($snapshot|ConvertTo-Json -Depth 16)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    State='PASS_PENDING_INSITE_REQUEST_QUERIED_READ_ONLY'
    RequestedScribes=$scribes.Count
    ExactComplete=@($snapshot.records|Where-Object{
        [string]$_.queryState-eq'MES_READ_ONLY_SNAPSHOT' -and
        [string]$_.lineage.state-eq'MES_SCRIBE_LINEAGE_EXACT' -and
        [string]$_.visualState.state-eq'COMPLETE'
    }).Count
    Held=@($snapshot.records|Where-Object{
        [string]$_.queryState-ne'MES_READ_ONLY_SNAPSHOT' -or
        [string]$_.lineage.state-ne'MES_SCRIBE_LINEAGE_EXACT' -or
        [string]$_.visualState.state-ne'COMPLETE'
    }).Count
    AcquisitionContexts=@($snapshot.records.acquisitionContexts).Count
    ExactPriorMoveIn=@($snapshot.records.acquisitionContexts|Where-Object state -eq 'EXACT_PRIOR_MOVEIN_FOUND').Count
    FrontsideScratchTestRouteConfirmed=@($snapshot.records.acquisitionContexts|Where-Object{
        $_.frontsideScratchTestRoute.state -eq 'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED'
    }).Count
    OutputPath=$outputPath
    SHA256=(Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
}|Format-List
