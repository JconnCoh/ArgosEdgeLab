[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Write-AtomicJson {
    param([string]$Path,[object]$Value,[int]$Depth=14)
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    $temp=$Path+'.partial.'+[Guid]::NewGuid().ToString('N')
    $encoding=New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temp,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),$encoding)
    if([IO.File]::Exists($Path)){
        for($attempt=1;$attempt-le5;$attempt++){
            $backup=$Path+'.replace-backup.'+[Guid]::NewGuid().ToString('N')
            try{
                [IO.File]::Replace($temp,$Path,$backup,$true)
                [IO.File]::Delete($backup)
                break
            }catch [IO.IOException]{
                if($attempt-eq5){throw}
                Start-Sleep -Milliseconds 100
            }catch [UnauthorizedAccessException]{
                if($attempt-eq5){throw}
                Start-Sleep -Milliseconds 100
            }
        }
    }else{
        [IO.File]::Move($temp,$Path)
    }
}

function Channel-Path {
    param([object]$Acquisition,[string]$Channel)
    $property=$Acquisition.channels.PSObject.Properties[$Channel]
    if($null-eq$property){return ''}
    return [string]$property.Value.path
}

function Has-Channel {
    param([object]$Acquisition,[string]$Channel)
    if($null-eq$Acquisition-or$null-eq$Acquisition.channels){return $false}
    return $null-ne$Acquisition.channels.PSObject.Properties[$Channel]
}

function Safe-Token {
    param([string]$Value)
    $token=($Value-replace'[^A-Za-z0-9._-]','_').Trim('_')
    if([string]::IsNullOrWhiteSpace($token)){return 'UNKNOWN'}
    return $token
}

$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
if([string]$config.schema-notin@('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3') -or
   [string]$config.metadataLookupAuthority-ne'CONFIRMED_SCRIBE_ONLY' -or
   -not[bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or [bool]$config.frontsideDefectInspectionEnabled){
    throw 'Scribe identity queue config safety contract refused.'
}
$stateRoot=[IO.Path]::GetFullPath([string]$config.stateRoot)
$identityRoot=Join-Path $stateRoot 'identity'
$catalogPath=Join-Path $stateRoot 'catalog\ALL_WAFER_CATALOG.json'
$queuePath=Join-Path $stateRoot 'identity\SCRIBE_IDENTITY_QUEUE.json'
if(-not(Test-Path -LiteralPath $catalogPath -PathType Leaf)){return}
$catalog=Get-Content -LiteralPath $catalogPath -Raw|ConvertFrom-Json

$activeConfirmed=@{}
$activeConfirmedPath=Join-Path $identityRoot 'confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json'
if(Test-Path -LiteralPath $activeConfirmedPath -PathType Leaf){
    $activeOverlay=Get-Content -LiteralPath $activeConfirmedPath -Raw|ConvertFrom-Json
    if([string]$activeOverlay.schema-ne'argos_confirmed_scribe_overlay_v1' -or-not[bool]$activeOverlay.reviewOnly){
        throw 'Active confirmed-scribe overlay safety contract refused.'
    }
    foreach($confirmed in @($activeOverlay.rows)){$activeConfirmed[[string]$confirmed.acquisitionKey]=$confirmed}
}
$activeNoncanonical=@{}
$activeNoncanonicalPath=Join-Path $identityRoot 'noncanonical\ACTIVE_HUMAN_VISIBLE_SCRIBE_HOLDS.json'
if(Test-Path -LiteralPath $activeNoncanonicalPath -PathType Leaf){
    $noncanonicalOverlay=Get-Content -LiteralPath $activeNoncanonicalPath -Raw|ConvertFrom-Json
    if([string]$noncanonicalOverlay.schema-ne'argos_human_visible_noncanonical_scribe_hold_overlay_v1' -or-not[bool]$noncanonicalOverlay.reviewOnly){
        throw 'Active noncanonical-scribe hold overlay safety contract refused.'
    }
    foreach($held in @($noncanonicalOverlay.rows)){$activeNoncanonical[[string]$held.acquisitionKey]=$held}
}

$frontByPhysical=@{}
foreach($front in @($catalog.acquisitions|Where-Object{[string]$_.domain-eq'FRONTSIDE'})){
    $key=[string]$front.physicalIdentity
    if($frontByPhysical.ContainsKey($key)){throw "More than one frontside acquisition record exists for $key"}
    $frontByPhysical[$key]=$front
}

$rows=New-Object Collections.Generic.List[object]
# Scribe discovery is frontside-first and must not depend on the backside
# recipe folder already containing the words Bare or BowComp.  A new recipe
# can therefore reach image-first operator identity review while its backside
# regime remains an explicit fail-closed domain hold.  Detector admission is
# still controlled separately by the inventory and MES regime gates.
$backsideRows=@($catalog.acquisitions|Where-Object{
    [string]$_.domain-ne'FRONTSIDE'-and(
        (Has-Channel $_ 'BACKSIDE_BF')-or(Has-Channel $_ 'BACKSIDE_DF')
    )
}|Sort-Object @{Expression='scanTimestampLocal';Descending=$true},physicalIdentity)
foreach($back in $backsideRows){
    $metadataState=[string]$back.metadataState
    $routeState=[string]$back.routeState
    $terminalInsiteHold=$routeState-in@(
        'HOLD_INSITE_LINEAGE_INCOMPLETE_OR_AMBIGUOUS',
        'HOLD_INSITE_CURRENT_STATE_INCOMPLETE_AND_NO_EXACT_SCAN_CONTEXT'
    )
    if($metadataState-in@('SCRIBE_CONFIRMED_MES_SNAPSHOT','SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING')){
        $rows.Add([pscustomobject][ordered]@{
            physicalIdentity=[string]$back.physicalIdentity
            waferId=[string]$back.waferId
            state=$metadataState
            proposal=''
            frontsideBf=''
            frontsideDf=''
            backsideDomain=[string]$back.domain
            backsideRouteState=$routeState
            nextAction=$(if($metadataState-eq'SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'-and-not$terminalInsiteHold){'READ_ONLY_INSITE_LOOKUP_REQUIRED'}else{'NONE'})
        })
        continue
    }
    $physical=[string]$back.physicalIdentity
    if($terminalInsiteHold){
        $rows.Add([pscustomobject][ordered]@{
            physicalIdentity=$physical
            waferId=[string]$back.waferId
            state=$(if([string]::IsNullOrWhiteSpace($metadataState)){$routeState}else{$metadataState})
            proposal=''
            frontsideBf=''
            frontsideDf=''
            backsideDomain=[string]$back.domain
            backsideRouteState=$routeState
            nextAction='NONE'
        })
        continue
    }
    if($activeNoncanonical.ContainsKey($physical)){
        $held=$activeNoncanonical[$physical]
        $rows.Add([pscustomobject][ordered]@{
            physicalIdentity=$physical
            waferId=''
            state='HOLD_HUMAN_VISIBLE_NONCANONICAL_CHECKSUM'
            proposal=[string]$held.visibleScribe
            proposalSource='HUMAN_VISIBLE_NONCANONICAL_CHECKSUM_HOLD'
            frontsideBf=''
            frontsideDf=''
            backsideDomain=[string]$back.domain
            backsideRouteState=[string]$back.routeState
            nextAction='SEPARATE_LEGACY_OR_NONCANONICAL_IDENTITY_AUTHORITY_REQUIRED'
        })
        continue
    }
    if($activeConfirmed.ContainsKey($physical)){
        $confirmed=$activeConfirmed[$physical]
        $rows.Add([pscustomobject][ordered]@{
            physicalIdentity=$physical
            waferId=[string]$confirmed.scribe
            state='SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'
            proposal=''
            frontsideBf=''
            frontsideDf=''
            backsideDomain=[string]$back.domain
            backsideRouteState=[string]$back.routeState
            nextAction='READ_ONLY_INSITE_LOOKUP_REQUIRED'
        })
        continue
    }
    $front=if($frontByPhysical.ContainsKey($physical)){$frontByPhysical[$physical]}else{$null}
    $bf=if($null-eq$front){''}else{Channel-Path $front 'FRONTSIDE_BF'}
    $df=if($null-eq$front){''}else{Channel-Path $front 'FRONTSIDE_DF'}
    $frontStable=$null-ne$front -and [string]$front.routeState-notlike'WAIT_*'
    $proposalPath=Join-Path (Join-Path (Join-Path $stateRoot 'identity\proposals') (Safe-Token $physical)) 'SCRIBE_PROPOSAL.json'
    $proposalRecord=if(Test-Path -LiteralPath $proposalPath -PathType Leaf){Get-Content -LiteralPath $proposalPath -Raw|ConvertFrom-Json}else{$null}
    if($null-ne$proposalRecord-and([string]$proposalRecord.schema-ne'argos_jbod_scribe_proposal_v1'-or-not[bool]$proposalRecord.reviewOnly-or[bool]$proposalRecord.productionEligible)){
        throw "Scribe proposal safety contract refused: $proposalPath"
    }
    $state=if($null-ne$proposalRecord-and-not[string]::IsNullOrWhiteSpace([string]$proposalRecord.proposal)){
        'PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED'
    }elseif($null-ne$proposalRecord){
        'SCRIBE_IDENTITY_CONFIRMATION_HOLD'
    }elseif($null-eq$front){
        'HOLD_FRONTSIDE_ACQUISITION_MISSING_FOR_SCRIBE'
    }elseif([string]::IsNullOrWhiteSpace($bf)-or[string]::IsNullOrWhiteSpace($df)){
        'HOLD_FRONTSIDE_BF_DF_PAIR_MISSING_FOR_SCRIBE'
    }elseif(-not$frontStable){
        'WAIT_FRONTSIDE_INPUT_STABILITY_FOR_SCRIBE'
    }else{
        'PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL'
    }
    $rows.Add([pscustomobject][ordered]@{
        physicalIdentity=$physical
        waferId=''
        state=$state
        proposal=$(if($null-eq$proposalRecord){''}else{[string]$proposalRecord.proposal})
        proposalSource=$(if($null-eq$proposalRecord-or$null-eq$proposalRecord.PSObject.Properties['proposalSource']){''}else{[string]$proposalRecord.proposalSource})
        proposalPath=$(if($null-eq$proposalRecord){''}else{$proposalPath})
        frontsideBf=$bf
        frontsideDf=$df
        backsideDomain=[string]$back.domain
        backsideRouteState=[string]$back.routeState
        nextAction=$(if($state-eq'PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL'){'RUN_IMAGE_FIRST_PROPOSAL_THEN_OPERATOR_VERIFY'}elseif($state-eq'PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED'){'OPERATOR_VERIFY_VISIBLE_12_CHARACTER_STRING'}else{'RESOLVE_INPUT_HOLD'})
    })
}

Write-AtomicJson $queuePath ([ordered]@{
    schema='argos_jbod_scribe_identity_queue_v1'
    updatedUtc=[DateTime]::UtcNow.ToString('o')
    state='SCRIBE_FIRST_FAIL_CLOSED_REVIEW_ONLY'
    lookupAuthority='CONFIRMED_12_CHARACTER_SCRIBE_ONLY'
    backsideDiscoveryAuthority='BACKSIDE_CHANNEL_PRESENCE_INDEPENDENT_OF_RECIPE_FOLDER_NAME'
    automaticProposalAuthority='PROPOSAL_ONLY_NEVER_AUTOMATIC_MES_IDENTITY'
    operatorConfirmationRequiredForNewScribes=$true
    frontsideDefectInspectionEnabled=$false
    counts=[ordered]@{
        total=$rows.Count
        confirmed=@($rows|Where-Object{$_.state-like'SCRIBE_CONFIRMED_*'}).Count
        mesEnriched=@($rows|Where-Object{$_.state-eq'SCRIBE_CONFIRMED_MES_SNAPSHOT'}).Count
        insiteLookupPending=@($rows|Where-Object{$_.state-eq'SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'}).Count
        proposalPending=@($rows|Where-Object{$_.state-eq'PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL'}).Count
        proposalReady=@($rows|Where-Object{$_.state-eq'PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED'}).Count
        waiting=@($rows|Where-Object{$_.state-like'WAIT_*'}).Count
        held=@($rows|Where-Object{$_.state-like'HOLD_*'}).Count
        noncanonicalChecksumHolds=@($rows|Where-Object{$_.state-eq'HOLD_HUMAN_VISIBLE_NONCANONICAL_CHECKSUM'}).Count
        domainUnqualified=@($rows|Where-Object{$_.backsideDomain-in@('UNKNOWN','BACKSIDE_PENDING_REGIME','BACKSIDE_REGIME_HOLD')}).Count
        backsideRegimePending=@($rows|Where-Object{$_.backsideDomain-in@('UNKNOWN','BACKSIDE_PENDING_REGIME')}).Count
    }
    rows=$rows.ToArray()
    imageBytesEmbedded=$false
    reviewOnly=$true
    trainingEligible=$false
    xmlEligible=$false
    productionEligible=$false
}) 14

[pscustomobject]@{State='SCRIBE_IDENTITY_QUEUE_UPDATED_REVIEW_ONLY';Queue=$queuePath;Rows=$rows.Count}|Format-List
