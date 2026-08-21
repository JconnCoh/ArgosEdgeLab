[CmdletBinding()]
param(
    [string] $ConfigPath,
    [ValidateRange(1,100)][int] $MaximumJobs = 20,
    [switch] $PlanOnly,
    [switch] $Rehearsal
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Write-AtomicJson {
    param([string]$Path,[object]$Value,[int]$Depth=16)
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    $temp=$Path+'.partial.'+[Guid]::NewGuid().ToString('N')
    $encoding=New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temp,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),$encoding)
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Invoke-NonBlockingDashboardRefresh {
    param(
        [Parameter(Mandatory=$true)][string]$AppRoot,
        [Parameter(Mandatory=$true)][string]$StateRoot,
        [Parameter(Mandatory=$true)][string]$ConfigPath,
        [string]$CompletedIdentity=''
    )
    try {
        $updater=Join-Path $AppRoot 'Update-JbodDashboardManifest.ps1'
        if(-not(Test-Path -LiteralPath $updater -PathType Leaf)){throw "Dashboard updater is missing: $updater"}
        & $updater -ConfigPath $ConfigPath | Out-Null
    } catch {
        # Dashboard availability is downstream of the durable inspection ledger.
        # A viewer refresh failure must remain visible but must never abort the
        # current or next wafer.
        try {
            $failurePath=Join-Path $StateRoot 'dashboard\DASHBOARD_REFRESH_FAILURE.json'
            Write-AtomicJson $failurePath ([ordered]@{
                schema='argos_jbod_dashboard_refresh_failure_v1'
                updatedUtc=[DateTime]::UtcNow.ToString('o')
                state='HOLD_DASHBOARD_REFRESH_FAILED_INSPECTION_CONTINUES'
                completedIdentity=$CompletedIdentity
                message=$_.Exception.Message
                inspectionContinues=$true
                reviewOnly=$true
                xmlExportEnabled=$false
                productionRoutingEnabled=$false
            }) 8
        } catch {
            # The ledger is already committed. Do not promote a secondary
            # failure-record write into an inspection-process failure.
        }
    }
}

function Get-Sha256Text {
    param([string]$Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-','')} finally {$sha.Dispose()}
}

function Get-OptionalPropertyText {
    param(
        [object]$InputObject,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if($null-eq$InputObject){return ''}
    $property=$InputObject.PSObject.Properties[$Name]
    if($null-eq$property -or $null-eq$property.Value){return ''}
    return [string]$property.Value
}

function Safe-Token {
    param([string]$Value)
    $token=($Value -replace '[^A-Za-z0-9._-]','_').Trim('_')
    if([string]::IsNullOrWhiteSpace($token)){'UNKNOWN'}else{$token}
}

function Bounded-Token {
    param([string]$Value,[ValidateRange(12,64)][int]$MaximumLength=18)
    $token=Safe-Token $Value
    if($token.Length-le$MaximumLength){return $token}
    $hash=(Get-Sha256Text $token).Substring(0,8)
    $prefixLength=$MaximumLength-$hash.Length-1
    return ($token.Substring(0,$prefixLength)+'_'+$hash)
}

function Assert-PlannedOutputPath {
    param([string]$Path,[int]$SuffixReserve=32)
    if([string]::IsNullOrWhiteSpace($Path)){throw 'Planned output path is empty.'}
    $full=[IO.Path]::GetFullPath($Path)
    $root=[IO.Path]::GetPathRoot($full)
    if([string]::IsNullOrWhiteSpace($root)){throw "Planned output path is not rooted: $Path"}
    foreach($component in @($full.Substring($root.Length).Split(@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))){
        if($component.Length-gt80){throw "Planned output component exceeds 80 characters: $component"}
    }
    $effective=$full.Length+$SuffixReserve
    if($effective-ge200){throw "Planned output path must remain below effective length 200; got ${effective}: $full"}
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function New-OutputPathPlan {
    param([string]$OutputParent,[string]$Domain,[string]$Lot,[string]$ScanTimestamp,[string]$Slot,[string]$Fingerprint)
    if($Fingerprint-notmatch'^[A-Fa-f0-9]{64}$'){throw 'Output path planning requires a SHA-256 acquisition fingerprint.'}
    $parent=Assert-PlannedOutputPath $OutputParent
    $artifactToken='A_'+$Fingerprint.Substring(0,16).ToUpperInvariant()
    $lotToken=Bounded-Token $Lot 18
    $slotToken=Bounded-Token $Slot 12
    $domainToken=if($Domain-eq'BARE_BACKSIDE'){'B'}elseif($Domain-eq'BOWCOMP_BACKSIDE'){'W'}elseif($Domain-eq'FRONTSIDE'){'F'}else{throw "Unsupported output domain: $Domain"}
    $timestampToken=(Safe-Token $ScanTimestamp)-replace'[^0-9]',''
    if([string]::IsNullOrWhiteSpace($timestampToken)){$timestampToken='NO_TIME'}
    elseif($timestampToken.Length-gt14){$timestampToken=$timestampToken.Substring(0,14)}
    $outputName='{0}_{1}_{2}_{3}_{4}'-f $domainToken,$lotToken,$timestampToken,$slotToken,$Fingerprint.Substring(0,12).ToUpperInvariant()
    if($outputName.Length-gt80){throw "Output directory component exceeds 80 characters: $outputName"}
    $outputRoot=Assert-PlannedOutputPath ([IO.Path]::Combine($parent,$outputName))
    [void](Assert-PlannedOutputPath ([IO.Path]::Combine($outputRoot,'geometry',('GEOMETRY_'+$artifactToken+'_20991231T235959Z'),'GEOMETRY_QUALIFICATION_SUMMARY.json')))
    $overviewName=$artifactToken+'_BF_COMPOSITE_ACCEPTED_HEATMAP_DISPLAY_OVERVIEW.png'
    if($overviewName.Length-gt80){throw "Composite overview component exceeds 80 characters: $overviewName"}
    return [pscustomobject]@{outputParent=$parent;outputName=$outputName;outputRoot=$outputRoot;artifactToken=$artifactToken;jobConfigName=('J_'+$Fingerprint.Substring(0,16).ToUpperInvariant()+'.json');overviewName=$overviewName}
}

if($Rehearsal){
    $testFingerprint=Get-Sha256Text ('ARGOS_OUTPUT_PATH_CONTRACT_TEST|' + ('X'*256))
    $plan=New-OutputPathPlan -OutputParent 'D:\A2\o' -Domain FRONTSIDE -Lot ('LOT_'+'L'*200) -ScanTimestamp '2099-12-31T23:59:59' -Slot ('Slot_'+'S'*100) -Fingerprint $testFingerprint
    [ordered]@{schema='argos_jbod_short_output_path_contract_test_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JBOD_SHORT_OUTPUT_PATH_CONTRACT_V1';outputName=$plan.outputName;outputNameLength=$plan.outputName.Length;artifactToken=$plan.artifactToken;overviewName=$plan.overviewName;overviewNameLength=$plan.overviewName.Length;maximumEffectiveLength=199;maximumComponentLength=80;betweenWaferCooperativeHoldSupported=$true;mutationsPerformed=$false;inspectionTasksChanged=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}
if([string]::IsNullOrWhiteSpace($ConfigPath)){throw 'ConfigPath is required outside Rehearsal.'}
. (Join-Path $PSScriptRoot 'Select-JbodAppearanceReferenceFamily.ps1')

function Channel-Path {
    param([object]$Acquisition,[string]$Channel)
    $property=$Acquisition.channels.PSObject.Properties[$Channel]
    if($null -eq $property){return $null}
    return [string]$property.Value.path
}

function Acquisition-Fingerprint {
    param([object]$Acquisition)
    $rows=foreach($property in $Acquisition.channels.PSObject.Properties|Sort-Object Name){
        $value=$property.Value
        "$($property.Name)|$($value.path)|$($value.bytes)|$($value.lastWriteUtc)|$($value.widthPx)x$($value.heightPx)"
    }
    Get-Sha256Text (([string]$Acquisition.identity)+'|'+($rows -join ';'))
}

function Reference-Family {
    param([object]$Acquisition)
    $metadataState=Get-OptionalPropertyText $Acquisition 'metadataState'
    $identityState=Get-OptionalPropertyText $Acquisition 'identityState'
    $waferId=Get-OptionalPropertyText $Acquisition 'waferId'
    $scanTimeContextState=Get-OptionalPropertyText $Acquisition 'scanTimeContextState'
    $scanTimeContextAuthority=Get-OptionalPropertyText $Acquisition 'scanTimeContextAuthority'
    $identityStateAllowed=$identityState-in@(
        'HUMAN_CONFIRMED_REVIEW_ONLY',
        'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY',
        'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY'
    )
    if($metadataState-ne'SCRIBE_CONFIRMED_MES_SNAPSHOT' -or
       -not$identityStateAllowed -or
       $waferId-notmatch'^[A-Z0-9]{12}$' -or
       $scanTimeContextState-ne'EXACT_PRIOR_MOVEIN_FOUND' -or
       $scanTimeContextAuthority-ne'LAST_INSITE_MOVEIN_PRECEDING_ARGOS_SCAN'){
        return ''
    }
    $domain=Get-OptionalPropertyText $Acquisition 'domain'
    $domainContext=switch($domain){
        'BARE_BACKSIDE' {Get-OptionalPropertyText $Acquisition 'backsideRegimeState';break}
        'BOWCOMP_BACKSIDE' {Get-OptionalPropertyText $Acquisition 'backsideRegimeState';break}
        'FRONTSIDE' {Get-OptionalPropertyText $Acquisition 'frontsideScratchTestRouteState';break}
        default {''}
    }
    $parts=@(
        $domain,
        $domainContext,
        (Get-OptionalPropertyText $Acquisition 'productName'),
        (Get-OptionalPropertyText $Acquisition 'productRevision'),
        (Get-OptionalPropertyText $Acquisition 'processBlockWorkflow'),
        (Get-OptionalPropertyText $Acquisition 'processBlock'),
        (Get-OptionalPropertyText $Acquisition 'step')
    )
    if(@($parts|Where-Object{[string]::IsNullOrWhiteSpace($_)}).Count-ne 0){return ''}
    return 'SCRIBE_MES_VISUAL_STATE_'+(Get-Sha256Text ($parts-join'|')).Substring(0,16)
}

function Resolve-AppearanceCohort {
    param(
        [Parameter(Mandatory=$true)][object]$Target,
        [Parameter(Mandatory=$true)][object[]]$Cohort,
        [Parameter(Mandatory=$true)][ValidateSet('FRONTSIDE','BACKSIDE')][string]$Side,
        [Parameter(Mandatory=$true)][string]$ContextFamily,
        [Parameter(Mandatory=$true)][string]$StateRoot,
        [Parameter(Mandatory=$true)][hashtable]$MemoryCache
    )
    $memberBinding=@($Cohort|Sort-Object identity|ForEach-Object{([string]$_.identity)+'|'+(Acquisition-Fingerprint $_)})-join';'
    $cohortKey=Get-Sha256Text ('APPEARANCE_ADMISSION_V1|'+$Side+'|'+$ContextFamily+'|'+$memberBinding)
    if(-not$MemoryCache.ContainsKey($cohortKey)){
        $auditPath=Join-Path ([IO.Path]::GetFullPath($StateRoot)) ('appearance\admission\'+$cohortKey+'.json')
        if(Test-Path -LiteralPath $auditPath -PathType Leaf){
            $document=Get-Content -LiteralPath $auditPath -Raw|ConvertFrom-Json
            if([string]$document.schema-ne'argos_exact_context_appearance_admission_audit_v1'-or[string]$document.cohortKey-ne$cohortKey){throw "Appearance admission audit contract mismatch: $auditPath"}
        }else{
            $featureRows=New-Object Collections.Generic.List[object]
            foreach($member in @($Cohort|Sort-Object identity)){$featureRows.Add((Get-NativeAppearanceFeatureRecord -Acquisition $member -Side $Side -StateRoot $StateRoot))}
            $groupResult=Select-AppearanceReferenceGroups -FeatureRows $featureRows.ToArray()
            $document=[ordered]@{
                schema='argos_exact_context_appearance_admission_audit_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
                cohortKey=$cohortKey;contextFamily=$ContextFamily;side=$Side;memberBinding=$memberBinding
                result=$groupResult;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false
            }
            Write-AppearanceAtomicJson $auditPath $document 24
            $document=[pscustomobject]$document
        }
        $MemoryCache[$cohortKey]=$document
    }
    $active=$MemoryCache[$cohortKey]
    $row=@($active.result.rows|Where-Object{[string]$_.identity-eq[string]$Target.identity}|Select-Object -First 1)
    if($row.Count-ne1){throw "Appearance admission row missing: $($Target.identity)"}
    $contributionState=[string]$row[0].state
    $admittedGroups=@{}
    foreach($candidateRow in @($active.result.rows|Where-Object{[string]$_.state-eq'ADMIT_EXACT_CONTEXT_APPEARANCE_FAMILY'})){
        $ids=@($candidateRow.groupIdentities|ForEach-Object{[string]$_}|Sort-Object -Unique)
        $signature=$ids-join'|'
        if(-not$admittedGroups.ContainsKey($signature)){$admittedGroups[$signature]=[pscustomobject]@{signature=$signature;identities=$ids}}
    }
    $chosenGroup=$null
    if($contributionState-eq'ADMIT_EXACT_CONTEXT_APPEARANCE_FAMILY'){
        $signature=@($row[0].groupIdentities|ForEach-Object{[string]$_}|Sort-Object -Unique)-join'|'
        if($admittedGroups.ContainsKey($signature)){$chosenGroup=$admittedGroups[$signature]}
    }elseif($admittedGroups.Count){
        $chosenGroup=@($admittedGroups.Values|Sort-Object @{Expression={@($_.identities).Count};Descending=$true},@{Expression={[string]$_.signature};Ascending=$true}|Select-Object -First 1)[0]
    }
    $inspectionState=if($null-eq$chosenGroup){
        'HOLD_NO_ACCEPTED_APPEARANCE_REFERENCE_FAMILY'
    }elseif($contributionState-eq'ADMIT_EXACT_CONTEXT_APPEARANCE_FAMILY'){
        'INSPECT_TARGET_EXCLUDED_OWN_APPEARANCE_FAMILY'
    }else{
        'INSPECT_TARGET_AGAINST_ACCEPTED_APPEARANCE_FAMILY_REFERENCE_CONTRIBUTION_HELD'
    }
    $chosenIdentities=if($null-eq$chosenGroup){@()}else{@($chosenGroup.identities)}
    $peerSet=@{};foreach($id in $chosenIdentities){if([string]$id-ne[string]$Target.identity){$peerSet[[string]$id]=$true}}
    $peers=@($Cohort|Where-Object{$peerSet.ContainsKey([string]$_.identity)})
    $visualFamily=if($chosenIdentities.Count){'APPEARANCE_'+(Get-Sha256Text (($chosenIdentities|Sort-Object)-join'|')).Substring(0,16)}else{''}
    $inspectionDetail=if($inspectionState-eq'INSPECT_TARGET_AGAINST_ACCEPTED_APPEARANCE_FAMILY_REFERENCE_CONTRIBUTION_HELD'){
        ' The wafer is excluded from reference membership but remains an inspection target against the largest accepted exact-context appearance family.'
    }elseif($inspectionState-eq'HOLD_NO_ACCEPTED_APPEARANCE_REFERENCE_FAMILY'){
        ' No exact-context appearance family with at least three mutually compatible physical wafers is available for target-excluded inspection.'
    }else{' The wafer is inspected against its own target-excluded accepted appearance family.'}
    return [pscustomobject]@{state=$contributionState;contributionState=$contributionState;inspectionState=$inspectionState;peers=$peers;visualFamily=$visualFamily;contextFamily=$ContextFamily;cohortKey=$cohortKey;auditPath=(Join-Path ([IO.Path]::GetFullPath($StateRoot)) ('appearance\admission\'+$cohortKey+'.json'));detail=([string]$row[0].detail+$inspectionDetail)}
}

$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
$configSchema=[string]$config.schema
if($configSchema -notin @('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3') -or
   -not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or
   -not [bool]$config.detectorExecutionEnabled){throw 'Processor config safety contract refused.'}
$appRoot=(Resolve-Path -LiteralPath ([string]$config.appRoot)).Path
$stateRoot=[IO.Path]::GetFullPath([string]$config.stateRoot)
$catalogPath=Join-Path $stateRoot 'catalog\ALL_WAFER_CATALOG.json'
$ledgerPath=Join-Path $stateRoot 'processor\PROCESSING_LEDGER.json'
$statusPath=Join-Path $stateRoot 'processor\PROCESSOR_STATUS.json'
$jobsRoot=Join-Path $stateRoot 'processor\jobs'
$outputParent=if(($config.PSObject.Properties.Name-contains'outputRoot')-and-not[string]::IsNullOrWhiteSpace([string]$config.outputRoot)){
    [string]$config.outputRoot
}else{Join-Path $stateRoot 'outputs\review_only'}
$outputParent=Assert-PlannedOutputPath $outputParent
$cooperativeHold=($config.PSObject.Properties.Name-contains'processorCooperativeHold')-and[bool]$config.processorCooperativeHold
if($cooperativeHold){
    $holdId=if($config.PSObject.Properties.Name-contains'processorCooperativeHoldId'){[string]$config.processorCooperativeHoldId}else{''}
    if([string]::IsNullOrWhiteSpace($holdId)-or$holdId-notmatch'^[A-Za-z0-9._-]{1,64}$'){throw 'Cooperative hold requires a bounded processorCooperativeHoldId.'}
    $ackPath=Join-Path $stateRoot 'processor\PROCESSOR_COOPERATIVE_HOLD_ACK.json'
    $holdRecord=[ordered]@{
        schema='argos_jbod_processor_cooperative_hold_ack_v1';updatedUtc=[DateTime]::UtcNow.ToString('o')
        state='HELD_AT_PROCESSING_PASS_BOUNDARY';holdId=$holdId;configSchema=$configSchema
        configSha256=(Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash
        outputRoot=$outputParent;currentIdentity='';waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-AtomicJson $ackPath $holdRecord 10
    Write-AtomicJson $statusPath ([ordered]@{schema='argos_jbod_all_wafer_processor_status_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');state='COOPERATIVE_HOLD_AT_PASS_BOUNDARY';holdId=$holdId;currentIdentity='';progressPercent=0;waferAborted=$false;reviewOnly=$true;xmlExportEnabled=$false}) 10
    [pscustomobject]@{State='COOPERATIVE_HOLD_AT_PASS_BOUNDARY';HoldId=$holdId;WaferAborted=$false;ReviewOnly=$true}|Format-List
    return
}
if(-not(Test-Path -LiteralPath $catalogPath -PathType Leaf)){throw "Catalog missing: $catalogPath"}
$catalog=Get-Content -LiteralPath $catalogPath -Raw|ConvertFrom-Json
if(-not [bool]$catalog.reviewOnly -or [bool]$catalog.xmlExportEnabled -or [bool]$catalog.imagePixelsLoaded){throw 'Catalog safety contract refused.'}
$appearanceAdmissionCache=@{}
foreach($path in @($jobsRoot,$outputParent)){if(-not(Test-Path -LiteralPath $path)){[void](New-Item -ItemType Directory -Path $path -Force)}}
$ledger=if(Test-Path -LiteralPath $ledgerPath){Get-Content -LiteralPath $ledgerPath -Raw|ConvertFrom-Json}else{[pscustomobject]@{schema='argos_jbod_processing_ledger_v1';rows=@()}}
$ledgerRows=New-Object Collections.Generic.List[object]
foreach($row in @($ledger.rows)){$ledgerRows.Add($row)}
$completedKeys=@{}
foreach($row in $ledgerRows){if([string]$row.state -in @('COMPLETED','FAILED','HOLD')){$completedKeys[[string]$row.jobKey]=$true}}

$routeRows=New-Object Collections.Generic.List[object]
$eligible=New-Object Collections.Generic.List[object]
foreach($acquisition in @($catalog.acquisitions)){
    if([string]$acquisition.routeState -notlike 'READY_*'){continue}
    $fingerprint=Acquisition-Fingerprint $acquisition
    $jobKey=([string]$acquisition.identity)+'__'+$fingerprint
    if($completedKeys.ContainsKey($jobKey)){continue}
    if([string]$acquisition.domain -eq 'BARE_BACKSIDE'){
        $family=Reference-Family $acquisition
        if([string]::IsNullOrWhiteSpace($family)){
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state='HOLD_REFERENCE_IDENTITY_CONTEXT_UNVERIFIED';detail='Bare detector admission requires an exact acquisition-keyed human-confirmed scribe and the last read-only Insite MoveIn preceding the Argos scan. The wafer cannot contribute identity, product, step, or future reference authority without it.'})
        }else{
            $bareCohort=@($catalog.acquisitions|Where-Object{[string]$_.domain-eq'BARE_BACKSIDE' -and [string]$_.routeState-like'READY_*' -and (Reference-Family $_)-eq$family})
            $appearance=$null
            if($bareCohort.Count-ge3){
                try{$appearance=Resolve-AppearanceCohort -Target $acquisition -Cohort $bareCohort -Side BACKSIDE -ContextFamily $family -StateRoot $stateRoot -MemoryCache $appearanceAdmissionCache}
                catch{$appearance=[pscustomobject]@{state='HOLD_APPEARANCE_ADMISSION_FAILED';contributionState='HOLD_APPEARANCE_ADMISSION_FAILED';inspectionState='BARE_NO_COMPOSITE_CONSUMED';peers=@();visualFamily='';contextFamily=$family;cohortKey='';auditPath='';detail=$_.Exception.Message}}
            }else{$appearance=[pscustomobject]@{state='HOLD_APPEARANCE_REFERENCE_INSUFFICIENT';contributionState='HOLD_APPEARANCE_REFERENCE_INSUFFICIENT';inspectionState='BARE_NO_COMPOSITE_CONSUMED';peers=@();visualFamily='';contextFamily=$family;cohortKey='';auditPath='';detail='Fewer than three exact-context physical wafers are available for future reference contribution.'}}
            # Bare scoring does not consume a composite.  A visual-family hold
            # therefore blocks only reference contribution, never inspection of
            # the target wafer itself.
            $eligible.Add([pscustomobject]@{acquisition=$acquisition;fingerprint=$fingerprint;jobKey=$jobKey;referenceFamily=$family;appearance=$appearance})
        }
        continue
    }
    if([string]$acquisition.domain -eq 'BOWCOMP_BACKSIDE'){
        $family=Reference-Family $acquisition
        $cohort=@();$appearance=$null;$peers=@()
        if(-not[string]::IsNullOrWhiteSpace($family)){
            $cohort=@($catalog.acquisitions|Where-Object{[string]$_.domain -eq 'BOWCOMP_BACKSIDE' -and [string]$_.routeState -like 'READY_*' -and (Reference-Family $_) -eq $family})
            if($cohort.Count-ge3){
                try{$appearance=Resolve-AppearanceCohort -Target $acquisition -Cohort $cohort -Side BACKSIDE -ContextFamily $family -StateRoot $stateRoot -MemoryCache $appearanceAdmissionCache;$peers=@($appearance.peers)}
                catch{$appearance=[pscustomobject]@{state='HOLD_APPEARANCE_ADMISSION_FAILED';contributionState='HOLD_APPEARANCE_ADMISSION_FAILED';inspectionState='HOLD_APPEARANCE_ADMISSION_FAILED';peers=@();visualFamily='';contextFamily=$family;cohortKey='';auditPath='';detail=$_.Exception.Message}}
            }
        }
        if([string]::IsNullOrWhiteSpace($family)){
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state='HOLD_REFERENCE_IDENTITY_CONTEXT_UNVERIFIED';detail='Need an exact acquisition-keyed, human-confirmed scribe and scan-time Insite product-revision-process-step context.'})
        }elseif($cohort.Count-lt3){
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state='HOLD_BOWCOMP_REFERENCE_FAMILY_UNRESOLVED';detail='Need at least three exact-context physical wafers before appearance-family admission; every target is excluded from its own composite.'})
        }elseif($null-eq$appearance-or[string]$appearance.inspectionState-notlike'INSPECT_*'-or$peers.Count-lt2){
            $detail=if($null-ne$appearance){[string]$appearance.detail}else{'Appearance admission did not return a result.'}
            $state=if($null-ne$appearance-and[string]$appearance.state-eq'HOLD_APPEARANCE_ADMISSION_FAILED'){'HOLD_APPEARANCE_ADMISSION_FAILED'}else{'HOLD_NO_ACCEPTED_APPEARANCE_REFERENCE_FAMILY'}
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state=$state;detail=$detail})
        } else {
            $eligible.Add([pscustomobject]@{acquisition=$acquisition;fingerprint=$fingerprint;jobKey=$jobKey;referenceFamily=($family+'_'+[string]$appearance.visualFamily);contextReferenceFamily=$family;peers=$peers;appearance=$appearance})
        }
        continue
    }
    if([string]$acquisition.domain -eq 'FRONTSIDE'){
        $family=Reference-Family $acquisition
        if([string]::IsNullOrWhiteSpace($family)){
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state='HOLD_REFERENCE_IDENTITY_CONTEXT_UNVERIFIED';detail='Frontside admission requires an exact acquisition-keyed human-confirmed scribe and the last read-only Insite MoveIn preceding the Argos scan.'})
            continue
        }
        if([string]$acquisition.frontsideScratchTestRouteState -ne
           'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED'){
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state='HOLD_FRONTSIDE_SCRATCH_TEST_ROUTE_NOT_CONFIRMED';detail='The exact Insite nitride-deposition anchor and post-anchor inspection-only tool history are required.'})
            continue
        }
        $sameAcquisition=@($catalog.acquisitions|Where-Object{
            [string]$_.domain -eq 'FRONTSIDE' -and
            [string]$_.lot -eq [string]$acquisition.lot -and
             [string]$_.scanTimestampLocal -eq [string]$acquisition.scanTimestampLocal -and
             [string]$_.routeState -eq 'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING' -and
             [string]$_.frontsideScratchTestRouteState -eq 'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED' -and
             (Reference-Family $_) -eq $family
        })
        $appearance=$null;$peers=@()
        if($sameAcquisition.Count-ge3){
            try{$appearance=Resolve-AppearanceCohort -Target $acquisition -Cohort $sameAcquisition -Side FRONTSIDE -ContextFamily ($family+'|'+[string]$acquisition.lot+'|'+[string]$acquisition.scanTimestampLocal) -StateRoot $stateRoot -MemoryCache $appearanceAdmissionCache;$peers=@($appearance.peers)}
            catch{$appearance=[pscustomobject]@{state='HOLD_APPEARANCE_ADMISSION_FAILED';contributionState='HOLD_APPEARANCE_ADMISSION_FAILED';inspectionState='HOLD_APPEARANCE_ADMISSION_FAILED';peers=@();visualFamily='';contextFamily=$family;cohortKey='';auditPath='';detail=$_.Exception.Message}}
        }
        if($sameAcquisition.Count -lt 3){
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state='HOLD_FRONTSIDE_SCRATCH_TEST_REFERENCE_INSUFFICIENT';detail='Need at least three physical wafers from the exact same lot acquisition and verified Insite product-revision-process-step context; every target is excluded from its own composite.'})
        }elseif($null-eq$appearance-or[string]$appearance.inspectionState-notlike'INSPECT_*'-or$peers.Count-lt2){
            $detail=if($null-ne$appearance){[string]$appearance.detail}else{'Appearance admission did not return a result.'}
            $state=if($null-ne$appearance-and[string]$appearance.state-eq'HOLD_APPEARANCE_ADMISSION_FAILED'){'HOLD_APPEARANCE_ADMISSION_FAILED'}else{'HOLD_NO_ACCEPTED_APPEARANCE_REFERENCE_FAMILY'}
            $routeRows.Add([pscustomobject]@{identity=[string]$acquisition.identity;waferId=[string]$acquisition.waferId;identityState=[string]$acquisition.identityState;state=$state;detail=$detail})
        }else{
            $eligible.Add([pscustomobject]@{acquisition=$acquisition;fingerprint=$fingerprint;jobKey=$jobKey;referenceFamily=($family+'_'+[string]$appearance.visualFamily);contextReferenceFamily=$family;peers=$peers;appearance=$appearance})
        }
    }
}

$priorityFrontsideLots=@()
if($config.PSObject.Properties.Name -contains 'frontsideScratchTestPriorityLots'){
    $priorityFrontsideLots=@($config.frontsideScratchTestPriorityLots|ForEach-Object{([string]$_).Trim()}|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}|Sort-Object -Unique)
}
$priorityLotSet=@{}
foreach($priorityLot in $priorityFrontsideLots){$priorityLotSet[$priorityLot]=$true}
$currentScanDateLocal=(Get-Date).ToString('yyyy-MM-dd')
$queuePolicy='EXPLICIT_FRONTSIDE_THEN_CURRENT_SCAN_DATE_THEN_NEWEST_FIRST'
$eligibleOrdered=@($eligible|Sort-Object `
    @{Expression={if([string]$_.acquisition.domain-eq'FRONTSIDE' -and $priorityLotSet.ContainsKey([string]$_.acquisition.lot)){0}else{1}};Ascending=$true},
    @{Expression={$scan=[string]$_.acquisition.scanTimestampLocal;if($scan.Length-ge10-and$scan.Substring(0,10)-eq$currentScanDateLocal){0}else{1}};Ascending=$true},
    @{Expression={[string]$_.acquisition.scanTimestampLocal};Descending=$true},
    @{Expression={[string]$_.acquisition.slot};Ascending=$true},
    @{Expression={[string]$_.acquisition.identity};Ascending=$true})
$priorityEligible=@($eligibleOrdered|Where-Object{[string]$_.acquisition.domain-eq'FRONTSIDE' -and $priorityLotSet.ContainsKey([string]$_.acquisition.lot)}).Count
$currentAcquisitionPriorityEligible=@($eligibleOrdered|Where-Object{$scan=[string]$_.acquisition.scanTimestampLocal;$scan.Length-ge10-and$scan.Substring(0,10)-eq$currentScanDateLocal}).Count
$referenceContributionHolds=@($eligibleOrdered|Where-Object{
    $null-ne$_.appearance -and
    [string]$_.appearance.contributionState-ne'ADMIT_EXACT_CONTEXT_APPEARANCE_FAMILY'
}).Count
$nextEligible=@($eligibleOrdered|Select-Object -First 1)
$nextEligibleIdentity=if($nextEligible.Count){[string]$nextEligible[0].acquisition.identity}else{''}
$nextEligibleLot=if($nextEligible.Count){[string]$nextEligible[0].acquisition.lot}else{''}
$nextEligibleDomain=if($nextEligible.Count){[string]$nextEligible[0].acquisition.domain}else{''}

Write-AtomicJson $statusPath ([ordered]@{schema='argos_jbod_all_wafer_processor_status_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($PlanOnly){'PLAN_ONLY'}elseif($eligibleOrdered.Count){'READY_TO_PROCESS'}else{'IDLE_WATCHING'});catalogAcquisitions=[int]$catalog.counts.acquisitions;eligiblePending=$eligibleOrdered.Count;queuePolicy=$queuePolicy;currentScanDateLocal=$currentScanDateLocal;currentAcquisitionPriorityEligible=$currentAcquisitionPriorityEligible;priorityFrontsideLots=$priorityFrontsideLots;priorityEligible=$priorityEligible;nextEligibleIdentity=$nextEligibleIdentity;nextEligibleLot=$nextEligibleLot;nextEligibleDomain=$nextEligibleDomain;referenceHolds=$routeRows.Count;referenceContributionHolds=$referenceContributionHolds;completed=@($ledgerRows|Where-Object{$_.state-eq'COMPLETED'}).Count;failed=@($ledgerRows|Where-Object{$_.state-eq'FAILED'}).Count;currentIdentity='';progressPercent=0;routeHolds=$routeRows.ToArray();reviewOnly=$true;xmlExportEnabled=$false}) 14
if($PlanOnly){[pscustomobject]@{State='PLAN_PASS_REVIEW_ONLY';Eligible=$eligibleOrdered.Count;QueuePolicy=$queuePolicy;CurrentScanDateLocal=$currentScanDateLocal;CurrentAcquisitionPriorityEligible=$currentAcquisitionPriorityEligible;PriorityEligible=$priorityEligible;PriorityFrontsideLots=$priorityFrontsideLots;NextEligibleIdentity=$nextEligibleIdentity;NextEligibleLot=$nextEligibleLot;NextEligibleDomain=$nextEligibleDomain;ReferenceHolds=$routeRows.Count;Completed=@($ledgerRows|Where-Object{$_.state-eq'COMPLETED'}).Count}|Format-List;return}

$processed=0
foreach($candidate in @($eligibleOrdered|Select-Object -First $MaximumJobs)){
    # Re-read only the bounded cooperative-hold fields between wafers.  A
    # config change can therefore stop the batch after the current wafer has
    # committed its ledger row, without stopping or aborting that wafer.
    $liveConfig=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
    if([string]$liveConfig.schema-notin@('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3')-or-not[bool]$liveConfig.reviewOnly-or[bool]$liveConfig.xmlExportEnabled){throw 'Live cooperative-hold config safety contract refused.'}
    $liveHold=($liveConfig.PSObject.Properties.Name-contains'processorCooperativeHold')-and[bool]$liveConfig.processorCooperativeHold
    if($liveHold){
        $holdId=if($liveConfig.PSObject.Properties.Name-contains'processorCooperativeHoldId'){[string]$liveConfig.processorCooperativeHoldId}else{''}
        if([string]::IsNullOrWhiteSpace($holdId)-or$holdId-notmatch'^[A-Za-z0-9._-]{1,64}$'){throw 'Live cooperative hold requires a bounded processorCooperativeHoldId.'}
        $liveOutputParent=if(($liveConfig.PSObject.Properties.Name-contains'outputRoot')-and-not[string]::IsNullOrWhiteSpace([string]$liveConfig.outputRoot)){[string]$liveConfig.outputRoot}else{Join-Path $stateRoot 'outputs\review_only'}
        $liveOutputParent=Assert-PlannedOutputPath $liveOutputParent
        $ackPath=Join-Path $stateRoot 'processor\PROCESSOR_COOPERATIVE_HOLD_ACK.json'
        Write-AtomicJson $ackPath ([ordered]@{schema='argos_jbod_processor_cooperative_hold_ack_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');state='HELD_BETWEEN_COMPLETED_WAFERS';holdId=$holdId;configSchema=[string]$liveConfig.schema;configSha256=(Get-FileHash -LiteralPath $ConfigPath -Algorithm SHA256).Hash;outputRoot=$liveOutputParent;currentIdentity='';completedThisPass=$processed;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 10
        Write-AtomicJson $statusPath ([ordered]@{schema='argos_jbod_all_wafer_processor_status_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');state='COOPERATIVE_HOLD_BETWEEN_COMPLETED_WAFERS';holdId=$holdId;processedThisPass=$processed;currentIdentity='';progressPercent=0;waferAborted=$false;reviewOnly=$true;xmlExportEnabled=$false}) 10
        [pscustomobject]@{State='COOPERATIVE_HOLD_BETWEEN_COMPLETED_WAFERS';HoldId=$holdId;ProcessedThisPass=$processed;WaferAborted=$false;ReviewOnly=$true}|Format-List
        return
    }
    $acq=$candidate.acquisition
    $pathPlan=New-OutputPathPlan -OutputParent $outputParent -Domain ([string]$acq.domain) -Lot ([string]$acq.lot) -ScanTimestamp ([string]$acq.scanTimestampLocal) -Slot ([string]$acq.slot) -Fingerprint $candidate.fingerprint
    $safeIdentity=$pathPlan.artifactToken
    $outputName=$pathPlan.outputName
    $outputRoot=$pathPlan.outputRoot
    $jobConfigPath=Join-Path $jobsRoot $pathPlan.jobConfigName
    if([string]$acq.domain-eq'FRONTSIDE'){
        $bf=Channel-Path $acq 'FRONTSIDE_BF';$df=Channel-Path $acq 'FRONTSIDE_DF'
    }else{
        $bf=Channel-Path $acq 'BACKSIDE_BF';$df=Channel-Path $acq 'BACKSIDE_DF'
    }
    $base=[ordered]@{appRoot=$appRoot;identity=[string]$acq.identity;safeIdentity=$safeIdentity;physicalIdentity=[string]$acq.physicalIdentity;waferId=[string]$acq.waferId;identityState=[string]$acq.identityState;metadataState=[string]$acq.metadataState;lot=[string]$acq.lot;scanTimestampLocal=[string]$acq.scanTimestampLocal;slot=[string]$acq.slot;domain=[string]$acq.domain;brightfieldPath=$bf;darkfieldPath=$df;outputRoot=$outputRoot;outputParent=$outputParent;outputPathContract=[ordered]@{schema='argos_jbod_short_output_path_contract_v1';outputName=$outputName;artifactIdentityToken=$safeIdentity;fullIdentity=[string]$acq.identity;physicalIdentity=[string]$acq.physicalIdentity;acquisitionFingerprintSha256=$candidate.fingerprint;maximumComponentLength=80;maximumEffectiveLength=199;suffixReserve=32};reviewOnly=$true;trainingEligible=$false;productionEligible=$false;xmlExportEnabled=$false}
    if(($config.PSObject.Properties.Name-contains'cacheRoot')-and-not[string]::IsNullOrWhiteSpace([string]$config.cacheRoot)){$base.cacheRoot=[IO.Path]::GetFullPath([string]$config.cacheRoot)}
    if([string]$acq.domain-eq'BARE_BACKSIDE'){
        $base.schema='argos_jbod_bare_acquisition_job_v1'
        $base.referenceFamily=[string]$candidate.referenceFamily
        $base.referenceContributionState=[string]$candidate.appearance.state
        $base.appearanceAdmissionAudit=[string]$candidate.appearance.auditPath
    }elseif([string]$acq.domain-eq'BOWCOMP_BACKSIDE'){
        $base.schema='argos_jbod_bowcomp_acquisition_job_v1'
        if(($config.PSObject.Properties.Name -contains 'bowCompReferenceCacheRoot') -and
           -not [string]::IsNullOrWhiteSpace([string]$config.bowCompReferenceCacheRoot)){
            $base.referenceCacheRoot=[IO.Path]::GetFullPath([string]$config.bowCompReferenceCacheRoot)
        }
        $base.referenceFamily=[string]$candidate.referenceFamily
        $base.contextReferenceFamily=[string]$candidate.contextReferenceFamily
        $base.appearanceAdmissionState=[string]$candidate.appearance.inspectionState
        $base.referenceContributionState=[string]$candidate.appearance.contributionState
        $base.appearanceAdmissionAudit=[string]$candidate.appearance.auditPath
        $base.peerBrightfieldPaths=@($candidate.peers|ForEach-Object{Channel-Path $_ 'BACKSIDE_BF'})
    }else{
        $base.schema='argos_jbod_frontside_scratch_test_acquisition_job_v1'
        $base.referenceFamily=[string]$candidate.referenceFamily
        $base.contextReferenceFamily=[string]$candidate.contextReferenceFamily
        $base.appearanceAdmissionState=[string]$candidate.appearance.inspectionState
        $base.referenceContributionState=[string]$candidate.appearance.contributionState
        $base.appearanceAdmissionAudit=[string]$candidate.appearance.auditPath
        $base.frontsideScratchTestRouteState=[string]$acq.frontsideScratchTestRouteState
        $base.frontsideScratchTestRouteAuthority=[string]$acq.frontsideScratchTestRouteAuthority
        $base.frontsideScratchTestRoute=$acq.frontsideScratchTestRoute
        $base.peerBrightfieldPaths=@($candidate.peers|ForEach-Object{Channel-Path $_ 'FRONTSIDE_BF'})
        $base.peerDarkfieldPaths=@($candidate.peers|ForEach-Object{Channel-Path $_ 'FRONTSIDE_DF'})
    }
    Write-AtomicJson $jobConfigPath $base 12
    $operatorIdentity=if([string]::IsNullOrWhiteSpace([string]$acq.waferId)){'WAFER IDENTITY HOLD'}else{[string]$acq.waferId}
    Write-AtomicJson $statusPath ([ordered]@{schema='argos_jbod_all_wafer_processor_status_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');state='PROCESSING';catalogAcquisitions=[int]$catalog.counts.acquisitions;eligiblePending=$eligible.Count;referenceHolds=$routeRows.Count;currentIdentity=[string]$acq.identity;currentWaferId=$operatorIdentity;currentDomain=[string]$acq.domain;currentStage='NATIVE_DETECTOR';progressPercent=1;jobConfig=$jobConfigPath;outputRoot=$outputRoot;reviewOnly=$true;xmlExportEnabled=$false}) 12
    $started=[DateTime]::UtcNow
    try {
        if([string]$acq.domain-eq'BARE_BACKSIDE'){
            $jobOut=& (Join-Path $appRoot 'Invoke-BareAcquisition.ps1') -JobConfigPath $jobConfigPath 2>&1
        }elseif([string]$acq.domain-eq'BOWCOMP_BACKSIDE'){
            $jobOut=& (Join-Path $appRoot 'Invoke-BowCompAcquisition.ps1') -JobConfigPath $jobConfigPath -WorkerCount ([int]$config.bowCompWorkerCount) 2>&1
        }else{
            $jobOut=& (Join-Path $appRoot 'Invoke-FrontsideScratchTestAcquisition.ps1') -JobConfigPath $jobConfigPath -WorkerCount ([int]$config.bowCompWorkerCount) 2>&1
        }
        $resultPath=Join-Path $outputRoot 'JOB_RESULT.json'
        if(-not(Test-Path -LiteralPath $resultPath -PathType Leaf)){throw 'Job completed without JOB_RESULT.json.'}
        $result=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
        $state=if([string]$result.state -like 'PASS_*'){'COMPLETED'}else{'HOLD'}
        $ledgerRows.Add([pscustomobject]@{jobKey=$candidate.jobKey;identity=[string]$acq.identity;domain=[string]$acq.domain;state=$state;startedUtc=$started.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');outputRoot=$outputRoot;resultPath=$resultPath;message=($jobOut -join [Environment]::NewLine)})
    } catch {
        $ledgerRows.Add([pscustomobject]@{jobKey=$candidate.jobKey;identity=[string]$acq.identity;domain=[string]$acq.domain;state='FAILED';startedUtc=$started.ToString('o');finishedUtc=[DateTime]::UtcNow.ToString('o');outputRoot=$outputRoot;resultPath='';message=$_.Exception.Message})
    }
    Write-AtomicJson $ledgerPath ([ordered]@{schema='argos_jbod_processing_ledger_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');rows=$ledgerRows.ToArray();reviewOnly=$true;xmlExportEnabled=$false}) 14
    Invoke-NonBlockingDashboardRefresh -AppRoot $appRoot -StateRoot $stateRoot -ConfigPath $ConfigPath -CompletedIdentity ([string]$acq.identity)
    $processed++
}

# Refresh the operator catalog only from completed jobs with all required BF/DF
# review artifacts. Holds and partial jobs remain visible in status but can never
# enter the share/dashboard catalog.
Invoke-NonBlockingDashboardRefresh -AppRoot $appRoot -StateRoot $stateRoot -ConfigPath $ConfigPath
& (Join-Path $appRoot 'Update-JbodReferenceRegistry.ps1') -ConfigPath $ConfigPath | Out-Null

Write-AtomicJson $statusPath ([ordered]@{schema='argos_jbod_all_wafer_processor_status_v1';updatedUtc=[DateTime]::UtcNow.ToString('o');state='WATCHING';catalogAcquisitions=[int]$catalog.counts.acquisitions;processedThisPass=$processed;eligibleBeforePass=$eligibleOrdered.Count;queuePolicy=$queuePolicy;currentScanDateLocal=$currentScanDateLocal;currentAcquisitionPriorityEligibleBeforePass=$currentAcquisitionPriorityEligible;priorityFrontsideLots=$priorityFrontsideLots;priorityEligibleBeforePass=$priorityEligible;referenceHolds=$routeRows.Count;completed=@($ledgerRows|Where-Object{$_.state-eq'COMPLETED'}).Count;held=@($ledgerRows|Where-Object{$_.state-eq'HOLD'}).Count;failed=@($ledgerRows|Where-Object{$_.state-eq'FAILED'}).Count;currentIdentity='';progressPercent=0;routeHolds=$routeRows.ToArray();reviewOnly=$true;xmlExportEnabled=$false}) 14
[pscustomobject]@{State='PROCESSING_PASS_COMPLETE_REVIEW_ONLY';Processed=$processed;EligibleBeforePass=$eligibleOrdered.Count;QueuePolicy=$queuePolicy;CurrentScanDateLocal=$currentScanDateLocal;CurrentAcquisitionPriorityEligibleBeforePass=$currentAcquisitionPriorityEligible;PriorityEligibleBeforePass=$priorityEligible;PriorityFrontsideLots=$priorityFrontsideLots;ReferenceHolds=$routeRows.Count;Completed=@($ledgerRows|Where-Object{$_.state-eq'COMPLETED'}).Count;Held=@($ledgerRows|Where-Object{$_.state-eq'HOLD'}).Count;Failed=@($ledgerRows|Where-Object{$_.state-eq'FAILED'}).Count}|Format-List
