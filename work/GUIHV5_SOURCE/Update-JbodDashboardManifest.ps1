[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $ConfigPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-AtomicJson {
    param([string]$Path,[object]$Value,[int]$Depth=18)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }
    $temporary = $Path + '.partial.' + [Guid]::NewGuid().ToString('N')
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temporary,
        (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), $encoding)
    Move-Item -LiteralPath $temporary -Destination $Path -Force
}

function Safe-Token {
    param([string]$Value)
    $token = ($Value -replace '[^A-Za-z0-9._-]', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($token)) { return 'UNKNOWN' }
    return $token
}

function Assert-PlannedOutputPath {
    param([string]$Path,[int]$SuffixReserve=32)
    $full=[IO.Path]::GetFullPath($Path)
    $root=[IO.Path]::GetPathRoot($full)
    if([string]::IsNullOrWhiteSpace($root)){throw "Dashboard output path is not rooted: $Path"}
    foreach($component in @($full.Substring($root.Length).Split([char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))){if($component.Length-gt80){throw "Dashboard output component exceeds 80 characters: $component"}}
    if(($full.Length+$SuffixReserve)-ge200){throw "Dashboard output path must remain below effective length 200: $full"}
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function Property-Text {
    param([object]$Object,[string]$Name)
    if ($null -eq $Object) { return '' }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return '' }
    return [string]$property.Value
}

function Get-ScribeActionability([string]$State) {
    switch ($State) {
        'PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED' { return 'OPERATOR_REVIEW_READY' }
        'PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL' { return 'AUTOMATIC_PROPOSAL_PENDING' }
        'SCRIBE_IDENTITY_CONFIRMATION_HOLD' { return 'INPUT_HOLD_NOT_REVIEWABLE' }
        'HOLD_HUMAN_VISIBLE_NONCANONICAL_CHECKSUM' { return 'SEPARATE_AUTHORITY_REQUIRED' }
        default { return 'SCRIBE_STATE_NOT_REVIEWABLE' }
    }
}

function Get-Sha256Text {
    param([string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString(
            $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))
        )).Replace('-','')
    } finally {
        $sha.Dispose()
    }
}

function Acquisition-Fingerprint {
    param([object]$Acquisition)
    $rows=foreach($property in $Acquisition.channels.PSObject.Properties|Sort-Object Name){
        $value=$property.Value
        "$($property.Name)|$($value.path)|$($value.bytes)|$($value.lastWriteUtc)|$($value.widthPx)x$($value.heightPx)"
    }
    $fingerprint=Get-Sha256Text (([string]$Acquisition.identity)+'|'+($rows -join ';'))
    return $fingerprint
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
if ([string]$config.schema -notin @('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3') -or
    -not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled) {
    throw 'Dashboard updater safety contract refused.'
}

$appRoot = [IO.Path]::GetFullPath([string]$config.appRoot)
$stateRoot = [IO.Path]::GetFullPath([string]$config.stateRoot)
$catalogPath = Join-Path $stateRoot 'catalog\ALL_WAFER_CATALOG.json'
$ledgerPath = Join-Path $stateRoot 'processor\PROCESSING_LEDGER.json'
$processorStatusPath = Join-Path $stateRoot 'processor\PROCESSOR_STATUS.json'
$scribeQueuePath = Join-Path $stateRoot 'identity\SCRIBE_IDENTITY_QUEUE.json'
$readinessPath = Join-Path $stateRoot 'dashboard\DASHBOARD_CATALOG_STATUS.json'
$manifestPath = Join-Path $appRoot 'dashboard_manifest.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "All-wafer catalog is missing: $catalogPath"
}
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$ledger = if(Test-Path -LiteralPath $ledgerPath -PathType Leaf){
    Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
}else{[pscustomobject]@{rows=@()}}
$processorStatus = if(Test-Path -LiteralPath $processorStatusPath -PathType Leaf){
    Get-Content -LiteralPath $processorStatusPath -Raw | ConvertFrom-Json
}else{$null}
if (-not (Test-Path -LiteralPath $scribeQueuePath -PathType Leaf)) { throw "Scribe identity queue is missing: $scribeQueuePath" }
$scribeQueue = Get-Content -LiteralPath $scribeQueuePath -Raw | ConvertFrom-Json
$scribeByPhysical = @{}
foreach ($row in @($scribeQueue.rows)) {
    $physical = Property-Text $row 'physicalIdentity'
    if ([string]::IsNullOrWhiteSpace($physical) -or $scribeByPhysical.ContainsKey($physical)) {
        throw "Scribe identity queue has a missing or duplicate physical identity: $physical"
    }
    $scribeByPhysical[$physical] = $row
}
if (-not [bool]$catalog.reviewOnly -or [bool]$catalog.xmlExportEnabled) {
    throw 'Dashboard updater refused a non-review-only catalog.'
}

$acquisitions = @{}
foreach ($acquisition in @($catalog.acquisitions)) {
    $acquisitions[[string]$acquisition.identity] = $acquisition
}

$included = New-Object Collections.Generic.List[object]
$held = New-Object Collections.Generic.List[object]
$excluded = New-Object Collections.Generic.List[object]
$completedLedgerRows=@($ledger.rows|Where-Object{[string]$_.state-eq'COMPLETED'})
$allLedgerRows=@($ledger.rows)
$processorHoldRows=if($null-ne$processorStatus-and$processorStatus.PSObject.Properties.Name-contains'routeHolds'){@($processorStatus.routeHolds)}else{@()}
$supersededCompletedRows=0
$duplicateCurrentRowsCollapsed=0
$scribeHoldQueueJoinRows=0
foreach ($catalogAcquisition in @($catalog.acquisitions)) {
    $identity=[string]$catalogAcquisition.identity
    $fingerprint=Acquisition-Fingerprint $catalogAcquisition
    $expectedJobKey=$identity+'__'+$fingerprint
    $identityRows=@($completedLedgerRows|Where-Object{[string]$_.identity-eq$identity})
    $currentRows=@($identityRows|Where-Object{[string]$_.jobKey-eq$expectedJobKey})
    $supersededCompletedRows+=@($identityRows|Where-Object{[string]$_.jobKey-ne$expectedJobKey}).Count
    if($currentRows.Count-eq0){
        $holdReason=Property-Text $catalogAcquisition 'routeState'
        $holdDetail=''
        $holdSource='CATALOG_ROUTE_STATE'
        $currentNonCompleted=@($allLedgerRows|Where-Object{[string]$_.identity-eq$identity-and[string]$_.jobKey-eq$expectedJobKey-and[string]$_.state-ne'COMPLETED'}|Sort-Object finishedUtc -Descending)
        $processorHold=@($processorHoldRows|Where-Object{[string]$_.identity-eq$identity}|Select-Object -First 1)
        if($currentNonCompleted.Count-gt0){
            $holdRow=$currentNonCompleted[0]
            $holdReason=Property-Text $holdRow 'reason'
            if([string]::IsNullOrWhiteSpace($holdReason)){$holdReason=Property-Text $holdRow 'state'}
            $holdDetail=Property-Text $holdRow 'message'
            $holdSource='CURRENT_LEDGER_ROW'
        }elseif($processorHold.Count-gt0){
            $holdReason=Property-Text $processorHold[0] 'state'
            $holdDetail=Property-Text $processorHold[0] 'detail'
            $holdSource='PROCESSOR_ROUTE_HOLD'
        }elseif([string]::IsNullOrWhiteSpace($holdReason)){
            $holdReason='WAITING_FOR_CURRENT_INSPECTION_RESULT'
            $holdSource='DASHBOARD_CURRENT_RESULT_WAIT'
        }
        $scribeState='';$scribeNextAction='';$scribeProposalSource='';$scribeActionability=''
        if($holdReason-eq'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'){
            $physicalIdentity=Property-Text $catalogAcquisition 'physicalIdentity'
            if(-not$scribeByPhysical.ContainsKey($physicalIdentity)){throw "Scribe hold has no exact queue row: $physicalIdentity"}
            $scribeRow=$scribeByPhysical[$physicalIdentity]
            $scribeState=Property-Text $scribeRow 'state'
            $scribeNextAction=Property-Text $scribeRow 'nextAction'
            $scribeProposalSource=Property-Text $scribeRow 'proposalSource'
            $scribeActionability=Get-ScribeActionability $scribeState
            $scribeHoldQueueJoinRows++
        }
        $held.Add([ordered]@{
            identity=$identity;physicalIdentity=(Property-Text $catalogAcquisition 'physicalIdentity')
            lot=(Property-Text $catalogAcquisition 'lot');scanTimestampLocal=(Property-Text $catalogAcquisition 'scanTimestampLocal')
            slot=(Property-Text $catalogAcquisition 'slot');domain=(Property-Text $catalogAcquisition 'domain')
            waferId=(Property-Text $catalogAcquisition 'waferId');product=(Property-Text $catalogAcquisition 'product')
            processBlock=(Property-Text $catalogAcquisition 'processBlock');step=(Property-Text $catalogAcquisition 'step')
            lastTool=(Property-Text $catalogAcquisition 'tool');holdReason=$holdReason;holdDetail=$holdDetail
            scribeQueueState=$scribeState;scribeNextAction=$scribeNextAction
            scribeProposalSource=$scribeProposalSource;scribeActionability=$scribeActionability
            holdSource=$holdSource;currentJobKey=$expectedJobKey;historicalCompletedRows=$identityRows.Count
            reviewOnly=$true;xmlEligible=$false
        })
        if($identityRows.Count-gt0){
            $excluded.Add([pscustomobject]@{
                identity=$identity
                reason='CURRENT_ACQUISITION_FINGERPRINT_HAS_NO_COMPLETED_RESULT'
                historicalCompletedRows=$identityRows.Count
            })
        }
        continue
    }
    $currentResultPaths=@($currentRows|ForEach-Object{[string]$_.resultPath}|Sort-Object -Unique)
    if($currentResultPaths.Count-ne1){
        $excluded.Add([pscustomobject]@{
            identity=$identity
            reason='CURRENT_JOB_KEY_RESULT_PATH_CONFLICT'
            currentJobKey=$expectedJobKey
            distinctResultPaths=$currentResultPaths.Count
        })
        continue
    }
    if($currentRows.Count-gt1){$duplicateCurrentRowsCollapsed+=($currentRows.Count-1)}
    $ledgerRow=@($currentRows|Sort-Object finishedUtc -Descending)[0]
    $identityState=Property-Text $catalogAcquisition 'identityState'
    $identityStateAllowed=$identityState-in@(
        'HUMAN_CONFIRMED_REVIEW_ONLY',
        'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY',
        'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY'
    )
    if ((Property-Text $catalogAcquisition 'metadataState') -ne 'SCRIBE_CONFIRMED_MES_SNAPSHOT' -or
        -not $identityStateAllowed -or
        (Property-Text $catalogAcquisition 'waferId') -notmatch '^[A-Z0-9]{12}$') {
        $excluded.Add([pscustomobject]@{identity=$identity;reason='SCRIBE_INSITE_METADATA_REQUIRED_BEFORE_REVIEW_CATALOG'})
        continue
    }
    $resultPath = [string]$ledgerRow.resultPath
    if ([string]::IsNullOrWhiteSpace($resultPath) -or
        -not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        $excluded.Add([pscustomobject]@{identity=$identity;reason='JOB_RESULT_MISSING'})
        continue
    }
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if ([string]$result.state -notlike 'PASS_*' -or -not [bool]$result.reviewOnly -or
        [bool]$result.xmlWritten -or [bool]$result.scratchRulesChanged) {
        $excluded.Add([pscustomobject]@{identity=$identity;reason='JOB_RESULT_SAFETY_CONTRACT_FAILED'})
        continue
    }
    $review = $result.PSObject.Properties['review']
    if ($null -eq $review) {
        $excluded.Add([pscustomobject]@{identity=$identity;reason='TWO_VIEW_REVIEW_RECORD_MISSING'})
        continue
    }
    $review = $review.Value
    $requiredPaths = @(
        [string]$review.backsideBfRaw,
        [string]$review.backsideDfRaw,
        [string]$review.backsideCompositeAcceptedBf,
        [string]$review.backsideCompositeAcceptedDf,
        [string]$review.backsideCompositeAcceptedDfDisplay
    )
    if (@($requiredPaths | Where-Object {
        [string]::IsNullOrWhiteSpace($_) -or -not (Test-Path -LiteralPath $_ -PathType Leaf)
    }).Count -ne 0) {
        $excluded.Add([pscustomobject]@{identity=$identity;reason='TWO_VIEW_REVIEW_ARTIFACT_INCOMPLETE'})
        continue
    }
    $included.Add([pscustomobject]@{
        acquisition=$acquisitions[$identity]
        result=$result
        resultPath=$resultPath
    })
}

if ($included.Count -eq 0 -and $held.Count -eq 0) {
    Write-AtomicJson $readinessPath ([ordered]@{
        schema='argos_jbod_dashboard_catalog_status_v1'
        updatedUtc=[DateTime]::UtcNow.ToString('o')
        state='WAITING_FOR_FIRST_COMPLETE_TWO_VIEW_RESULT'
        includedWafers=0
        excluded=$excluded.ToArray()
        existingManifestPreserved=(Test-Path -LiteralPath $manifestPath -PathType Leaf)
        supersededCompletedRows=$supersededCompletedRows
        duplicateCurrentRowsCollapsed=$duplicateCurrentRowsCollapsed
        reviewOnly=$true
        xmlExportEnabled=$false
    })
    return
}

$sessionGroups = $included | Group-Object {
    $side = if ([string]$_.acquisition.domain -eq 'FRONTSIDE') { 'FRONTSIDE' } else { 'BACKSIDE' }
    ([string]$_.acquisition.lot) + '|' + ([string]$_.acquisition.scanTimestampLocal) + '|' + $side
}
$sessions = New-Object Collections.Generic.List[object]
foreach ($group in $sessionGroups) {
    $first = @($group.Group)[0]
    $acquisition = $first.acquisition
    $lot = [string]$acquisition.lot
    $scanTimestamp = [string]$acquisition.scanTimestampLocal
    $timestampDigits = $scanTimestamp -replace '[^0-9]', ''
    $sessionSide = if ([string]$acquisition.domain -eq 'FRONTSIDE') { 'FRONTSIDE' } else { 'BACKSIDE' }
    $waferRows = New-Object Collections.Generic.List[object]
    foreach ($entry in @($group.Group | Sort-Object { [string]$_.acquisition.slot })) {
        $acq = $entry.acquisition
        $result = $entry.result
        $review = $result.review
        $domain = [string]$acq.domain
        $geometryDisposition = if ($domain -eq 'BOWCOMP_BACKSIDE') {
            Property-Text $result 'geometryDisposition'
        } else {
            Property-Text $result.geometry 'state'
        }
        $isFrontside = $domain -eq 'FRONTSIDE'
        $waferRows.Add([ordered]@{
            identity=[string]$acq.physicalIdentity
            lot=[string]$acq.lot
            waferId=(Property-Text $acq 'waferId')
            product=(Property-Text $acq 'product')
            processBlock=(Property-Text $acq 'processBlock')
            step=(Property-Text $acq 'step')
            slot=[string]$acq.slot
            lastTool=(Property-Text $acq 'tool')
            backsideBfRaw=[string]$review.backsideBfRaw
            backsideDfRaw=[string]$review.backsideDfRaw
            backsideCompositeAcceptedBf=[string]$review.backsideCompositeAcceptedBf
            backsideCompositeAcceptedDf=[string]$review.backsideCompositeAcceptedDf
            backsideCompositeAcceptedDfDisplay=[string]$review.backsideCompositeAcceptedDfDisplay
            backsideBfAccepted=$null
            backsideBfConfirmation=$null
            backsideBfShadowRaw=$null
            backsideBfShadowAccepted=$null
            backsideBfShadowConfirmation=$null
            scratchAcceptedBranchComponents=0
            scratchConfirmationBranchComponents=0
            frontsideBfRaw=$(if($isFrontside){Property-Text $review 'frontsideBfRaw'}else{$null})
            frontsideDfRaw=$(if($isFrontside){Property-Text $review 'frontsideDfRaw'}else{$null})
            frontsideCompositeAcceptedBf=$(if($isFrontside){Property-Text $review 'frontsideCompositeAcceptedBf'}else{$null})
            frontsideCompositeAcceptedDf=$(if($isFrontside){Property-Text $review 'frontsideCompositeAcceptedDf'}else{$null})
            frontsideCompositeAcceptedDfDisplay=$(if($isFrontside){Property-Text $review 'frontsideCompositeAcceptedDfDisplay'}else{$null})
            metadata=[ordered]@{
                domain=$domain
                acquisitionSide=$(if($isFrontside){'FRONTSIDE'}else{'BACKSIDE'})
                reviewOnly='true'
                inspectionState=[string]$result.state
                geometryDisposition=$geometryDisposition
                confirmationIncluded='false'
                scratchDetectorModified='false'
                xmlEligible='false'
            }
        })
    }
    $sessions.Add([ordered]@{
        scanId=((Safe-Token $lot) + '_' + $timestampDigits + '_' + $sessionSide)
        lot=$lot
        scanTimestampLocal=$scanTimestamp
        timestampProvenance=$(if([string]::IsNullOrWhiteSpace((Property-Text $acquisition 'timestampProvenance'))){'Argos acquisition directory timestamp; tool-local timezone not encoded'}else{Property-Text $acquisition 'timestampProvenance'})
        metadata=[ordered]@{
            reviewOnly='true'
            includedDomains=((@($group.Group.acquisition.domain | Sort-Object -Unique)) -join ',')
            inspectionState='COMPLETED_TWO_VIEW_RESULTS_ONLY'
            xmlExportState='DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY'
        }
        wafers=$waferRows.ToArray()
    })
}

$dashboardOutputRoot = if(($config.PSObject.Properties.Name-contains'dashboardOutputRoot')-and-not[string]::IsNullOrWhiteSpace([string]$config.dashboardOutputRoot)){
    [string]$config.dashboardOutputRoot
}else{Join-Path $stateRoot 'dashboard_outputs'}
$dashboardOutputRoot=Assert-PlannedOutputPath $dashboardOutputRoot
if (-not (Test-Path -LiteralPath $dashboardOutputRoot)) {
    [void](New-Item -ItemType Directory -Path $dashboardOutputRoot -Force)
}
$manifest = [ordered]@{
    schema='argos_lot_dashboard_catalog_v4_composite_accepted'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    outputRoot=$dashboardOutputRoot
    shareImageQueueEnabled=[bool]$config.queueRelaySummary
    shareImageQueueRoot=[string]$config.relayQueueRoot
    shareImageQueueState='LIVE_BOUND_RELAY_JBOD_TO_ARGOS_TO_GATEWAY_REVIEW_ONLY'
    defectOverlayOpacity=1.0
    xmlExportEnabled=$false
    xmlExportState='DISABLED_PENDING_DATA_ENGINEERING_DEFECT_BINS_AND_COORDINATE_AUTHORITY'
    scanTimestampAuthority='ARGOS_ACQUISITION_DIRECTORY_TIMESTAMP_TOOL_LOCAL'
    filterableFields=@(
        [ordered]@{label='Scan date';key='scanDate';scope='scan'},
        [ordered]@{label='Scan time';key='scanTime';scope='scan'},
        [ordered]@{label='Lot';key='lot';scope='scan'},
        [ordered]@{label='Domain';key='domain';scope='wafer'},
        [ordered]@{label='Product';key='product';scope='wafer'},
        [ordered]@{label='Process block';key='processBlock';scope='wafer'},
        [ordered]@{label='Step';key='step';scope='wafer'},
        [ordered]@{label='Last tool';key='lastTool';scope='wafer'},
        [ordered]@{label='Slot';key='slot';scope='wafer'},
        [ordered]@{label='Wafer ID';key='waferId';scope='wafer'}
    )
    scanSessions=@($sessions.ToArray() | Sort-Object scanTimestampLocal -Descending)
    heldAcquisitions=@($held.ToArray() | Sort-Object scanTimestampLocal -Descending)
}
Write-AtomicJson $manifestPath $manifest 18
Write-AtomicJson $readinessPath ([ordered]@{
    schema='argos_jbod_dashboard_catalog_status_v1'
    updatedUtc=[DateTime]::UtcNow.ToString('o')
    state='DASHBOARD_CATALOG_READY_REVIEW_ONLY'
    manifestPath=$manifestPath
    scanSessions=$sessions.Count
    includedWafers=$included.Count
    heldWafers=$held.Count
    scribeHoldQueueJoinRows=$scribeHoldQueueJoinRows
    scribeQueueRows=$scribeByPhysical.Count
    scribeHoldQueueMissing=0
    supersededCompletedRows=$supersededCompletedRows
    duplicateCurrentRowsCollapsed=$duplicateCurrentRowsCollapsed
    excluded=$excluded.ToArray()
    reviewOnly=$true
    xmlExportEnabled=$false
}) 14

[pscustomobject]@{
    State='DASHBOARD_CATALOG_READY_REVIEW_ONLY'
    Manifest=$manifestPath
    ScanSessions=$sessions.Count
    Wafers=$included.Count
    HeldWafers=$held.Count
    ScribeHoldQueueJoinRows=$scribeHoldQueueJoinRows
    SupersededCompletedRows=$supersededCompletedRows
    DuplicateCurrentRowsCollapsed=$duplicateCurrentRowsCollapsed
    Excluded=$excluded.Count
    XMLExportEnabled=$false
} | Format-List
