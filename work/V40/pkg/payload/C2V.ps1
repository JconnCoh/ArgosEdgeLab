[CmdletBinding()]
param([switch]$Rehearsal,[string]$InvocationManifest='')

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$expectedConfigSha='CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$lot='62631-586'
$scanDate='2026-08-19'
$targetRequestSha='5C08CE4E6D8A4603B14BFC1692B30CE4E64CAE538A7D1FA7CE94C66CC095518C'
$targetResponseId='INSITE_RESP__5C08CE4E6D8A4603B14BFC1692B30CE4'
$expectedWorkerSha='8D10D7A775741F9A2B4FD4AA831E1426DCA1DC2A17A9A68AD8CD432F10265B5C'
$configPath='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\PROCESSOR_CONFIG.json'
$stateRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$bridgeRoot='C:\ProgramData\ArgosInsiteBridgeRO'
$isRehearsal=[bool]$Rehearsal

function Get-Optional([AllowNull()][object]$Object,[string]$Name,[AllowNull()][object]$Default=$null){if($null-ne$Object-and$Object.PSObject.Properties.Name-contains$Name){return $Object.$Name};return $Default}
function Assert-PathBudget([string]$Path){$full=[IO.Path]::GetFullPath($Path);$effective=$full.Length+32;$maxComponent=0;foreach($part in @($full.Split(@('\'),[StringSplitOptions]::RemoveEmptyEntries))){$maxComponent=[Math]::Max($maxComponent,$part.Length)};if($effective-ge200-or$maxComponent-gt80){throw "C2V35 unsafe path ($effective/$maxComponent): $full"}}
function Read-JsonSnapshot([string]$Path,[int64]$MaximumBytes){
    for($attempt=0;$attempt-lt4;$attempt++){
        try{
            $stream=New-Object IO.FileStream($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]'ReadWrite,Delete')
            try{if($stream.Length-gt$MaximumBytes){throw "C2V35 JSON exceeds byte bound: $Path"};$memory=New-Object IO.MemoryStream;try{$stream.CopyTo($memory);$text=[Text.Encoding]::UTF8.GetString($memory.ToArray())}finally{$memory.Dispose()}}finally{$stream.Dispose()}
            return($text|ConvertFrom-Json)
        }catch{if($attempt-eq3){throw};Start-Sleep -Milliseconds 250}
    }
}
function Get-PackageSnapshot([string]$State,[string]$Path){
    if(-not(Test-Path -LiteralPath $Path -PathType Container)){return [pscustomobject]@{state=$State;exists=$false;path=$Path;manifest=$null;failure=$null}}
    $manifestPath=Join-Path $Path 'INSITE_RESPONSE_MANIFEST.json';$failurePath=Join-Path $Path 'IMPORT_FAILURE.json';Assert-PathBudget $manifestPath;Assert-PathBudget $failurePath
    $manifest=if(Test-Path -LiteralPath $manifestPath -PathType Leaf){Read-JsonSnapshot $manifestPath 1048576}else{$null}
    $failure=if(Test-Path -LiteralPath $failurePath -PathType Leaf){Read-JsonSnapshot $failurePath 1048576}else{$null}
    return [pscustomobject]@{state=$State;exists=$true;path=$Path;manifest=$manifest;failure=$failure}
}

$rehearsalManifest=if($Rehearsal){[string]$InvocationManifest}else{[string]$env:ARGOS_C2V_REHEARSAL_MANIFEST}
if($Rehearsal-and[string]::IsNullOrWhiteSpace($rehearsalManifest)){throw 'C2V35 -Rehearsal requires -InvocationManifest.'}
if(-not[string]::IsNullOrWhiteSpace($rehearsalManifest)){
    $i=Get-Content -LiteralPath ([IO.Path]::GetFullPath($rehearsalManifest)) -Raw|ConvertFrom-Json
    if([string]$i.schema-ne'argos_jbod_front_catalog_probe_rehearsal_v1'-or-not[bool]$i.rehearsal){throw 'C2V35 invocation schema changed.'}
    $configPath=[IO.Path]::GetFullPath([string]$i.configPath);$stateRoot=[IO.Path]::GetFullPath([string]$i.stateRoot);$bridgeRoot=[IO.Path]::GetFullPath([string]$i.bridgeRoot);$isRehearsal=$true
}

$catalogPath=Join-Path $stateRoot 'catalog\ALL_WAFER_CATALOG.json'
$dashboardPath=Join-Path $stateRoot 'dashboard_manifest.json'
$lastImportedPath=Join-Path $bridgeRoot 'state\LAST_IMPORTED_RESPONSE.json'
$lastQueuedPath=Join-Path $bridgeRoot 'state\LAST_QUEUED_REQUEST.json'
$packageRows=New-Object Collections.Generic.List[object]
$processedPackagePath=Join-Path $bridgeRoot ('response_inbox\processed\'+$targetResponseId+'.ready')
foreach($queueState in @('pending','processed')){
    $path=Join-Path $bridgeRoot ('response_inbox\'+$queueState+'\'+$targetResponseId+'.ready')
    Assert-PathBudget $path;$packageRows.Add((Get-PackageSnapshot $queueState $path))
}
$processedPayload=$null
$processedPayloadSummary=[ordered]@{exists=$false;path=(Join-Path $processedPackagePath 'INSITE_RESPONSE.json');sha256='';authority='';lookupKey='';targetContextCount=0;targetRecords=@()}
if(Test-Path -LiteralPath $processedPayloadSummary.path -PathType Leaf){
    Assert-PathBudget $processedPayloadSummary.path
    $processedPayload=Read-JsonSnapshot $processedPayloadSummary.path 4194304
    $targetRecords=New-Object Collections.Generic.List[object]
    foreach($record in @($processedPayload.records)){
        $recordContexts=@(Get-Optional $record 'acquisitionContexts' @())
        $contexts=@($recordContexts|Where-Object{([string]$_.acquisitionKey).IndexOf($lot,[StringComparison]::OrdinalIgnoreCase)-ge0})
        if($contexts.Count-eq0){continue}
        if(($targetRecords.Count+$contexts.Count)-gt20){throw 'C2V35 target response context bound exceeded.'}
        foreach($context in $contexts){
            $targetRecords.Add([pscustomobject][ordered]@{
                scribe=[string]$record.scribe
                queryState=[string]$record.queryState
                lineage=$record.lineage
                visualState=$record.visualState
                backsideRegime=$record.backsideRegime
                acquisitionContext=$context
            })
        }
    }
    $processedPayloadSummary=[ordered]@{
        exists=$true;path=$processedPayloadSummary.path;sha256=(Get-FileHash -LiteralPath $processedPayloadSummary.path -Algorithm SHA256).Hash
        authority=[string]$processedPayload.authority;lookupKey=[string]$processedPayload.lookupKey
        frontsideScratchTestRouteContract=[string](Get-Optional $processedPayload 'frontsideScratchTestRouteContract' '')
        recordCount=@($processedPayload.records).Count;targetContextCount=$targetRecords.Count;targetRecords=$targetRecords.ToArray()
    }
}
$failedRoot=Join-Path $bridgeRoot 'response_inbox\failed';Assert-PathBudget $failedRoot
$failedMatches=@([IO.Directory]::GetDirectories($failedRoot,$targetResponseId+'.ready.failed.*',[IO.SearchOption]::TopDirectoryOnly))
if($failedMatches.Count-gt1){throw 'C2V35 exact target has multiple failed response leaves.'}
$responseAcquisitionKeys=@()
if($failedMatches.Count-eq1){
    $packageRows.Add((Get-PackageSnapshot 'failed' $failedMatches[0]))
    $failedPayloadPath=Join-Path $failedMatches[0] 'INSITE_RESPONSE.json';Assert-PathBudget $failedPayloadPath
    if(Test-Path -LiteralPath $failedPayloadPath -PathType Leaf){
        $failedPayload=Read-JsonSnapshot $failedPayloadPath 1048576
        $responseAcquisitionKeys=@((Get-Optional $failedPayload 'requestRows' @())|ForEach-Object{([string](Get-Optional $_ 'acquisitionKey' '')).Trim().ToUpperInvariant()}|Where-Object{$_}|Sort-Object -Unique)
        if($responseAcquisitionKeys.Count-gt100){throw 'C2V35 response acquisition key bound exceeded.'}
    }
}
$runtimePaths=[ordered]@{
    candidateImporter=(Join-Path $stateRoot 'Import-JbodCandidateInsiteSnapshot.ps1')
    lotResolver=(Join-Path $stateRoot 'ArgosScribeCandidateLotResolver.psm1')
    liveImporter=(Join-Path $stateRoot 'Import-JbodLiveInsiteSnapshot.ps1')
    worker=(Join-Path $bridgeRoot 'Invoke-JbodAutomaticInsiteBridgeWorker.ps1')
    inventory=(Join-Path $stateRoot 'Invoke-JbodAllWaferInventory.ps1')
    processingPass=(Join-Path $stateRoot 'Invoke-JbodAllWaferProcessingPass.ps1')
    dashboardUpdater=(Join-Path $stateRoot 'Update-JbodDashboardManifest.ps1')
    scribeProposalPass=(Join-Path $stateRoot 'Invoke-JbodScribeProposalPass.ps1')
    multiChannelReader=(Join-Path $stateRoot 'runtime\scribe\Invoke-ScribeMultiChannelPolarityReader.ps1')
}
$runtimeHashes=[ordered]@{}
foreach($name in @($runtimePaths.Keys)){$path=[string]$runtimePaths[$name];Assert-PathBudget $path;if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "C2V35 runtime dependency missing: $name"};$runtimeHashes[$name]=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash}
if(-not$isRehearsal-and[string]$runtimeHashes.worker-ne$expectedWorkerSha){throw "C2V35 installed worker hash changed: $($runtimeHashes.worker)"}
foreach($path in @($configPath,$catalogPath,$dashboardPath,$lastImportedPath,$lastQueuedPath)){Assert-PathBudget $path}
foreach($path in @($configPath,$catalogPath,$dashboardPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "C2V35 required live file missing: $path"}}

$configSha=(Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
if($configSha-ne$expectedConfigSha){throw "C2V35 config hash changed: $configSha"}
$config=Read-JsonSnapshot $configPath 1048576
if(-not[bool]$config.reviewOnly-or[bool]$config.xmlExportEnabled-or[bool]$config.productionEligible-or[bool]$config.processorCooperativeHold){throw 'C2V35 live safety contract changed.'}
if(-not$isRehearsal-and-not([IO.Path]::GetFullPath([string]$config.stateRoot)).TrimEnd('\').Equals($stateRoot.TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'C2V35 state root changed.'}

$catalog=Read-JsonSnapshot $catalogPath 67108864
$dashboard=Read-JsonSnapshot $dashboardPath 67108864
if(-not[bool]$catalog.reviewOnly-or[bool]$catalog.xmlExportEnabled-or[bool]$dashboard.xmlExportEnabled){throw 'C2V35 review-only catalog/dashboard contract changed.'}
$frontRows=@($catalog.acquisitions|Where-Object{[string]$_.lot-eq$lot-and[string]$_.scanTimestampLocal-like($scanDate+'*')-and[string]$_.domain-eq'FRONTSIDE'}|Sort-Object {[string]$_.scanTimestampLocal},{[string]$_.slot},{[string]$_.physicalIdentity})
$frontPhysicalIdentities=@($frontRows|ForEach-Object{[string]$_.physicalIdentity}|Where-Object{$_}|Sort-Object -Unique)
$frontSlots=@($frontRows|ForEach-Object{[string]$_.slot}|Where-Object{$_}|Sort-Object -Unique)
$frontRowSummary=@($frontRows|ForEach-Object{[pscustomobject]@{identity=[string]$_.identity;physicalIdentity=[string]$_.physicalIdentity;scanTimestampLocal=[string]$_.scanTimestampLocal;slot=[string]$_.slot;routeState=[string]$_.routeState}})
$targetIdentitySet=@{};foreach($identity in $frontPhysicalIdentities){$targetIdentitySet[$identity]=$true}
$ledgerPath=Join-Path $stateRoot 'processor\PROCESSING_LEDGER.json';$dashboardReadinessPath=Join-Path $stateRoot 'dashboard\DASHBOARD_CATALOG_STATUS.json'
foreach($path in @($ledgerPath,$dashboardReadinessPath)){Assert-PathBudget $path}
$targetLedgerRows=@()
if(Test-Path -LiteralPath $ledgerPath -PathType Leaf){
    $ledger=Read-JsonSnapshot $ledgerPath 67108864
    $targetLedgerRows=@($ledger.rows|Where-Object{$targetIdentitySet.ContainsKey([string]$_.identity)})
    if($targetLedgerRows.Count-gt20){throw 'C2V35 target ledger row bound exceeded.'}
}
$dashboardReadiness=if(Test-Path -LiteralPath $dashboardReadinessPath -PathType Leaf){Read-JsonSnapshot $dashboardReadinessPath 4194304}else{$null}
$targetDashboardExclusions=if($dashboardReadiness){@($dashboardReadiness.excluded|Where-Object{$targetIdentitySet.ContainsKey([string]$_.identity)})}else{@()}
$proposalRoot=Join-Path $stateRoot 'identity\proposals';Assert-PathBudget $proposalRoot
$targetProposalRows=New-Object Collections.Generic.List[object]
if(Test-Path -LiteralPath $proposalRoot -PathType Container){
    if($frontPhysicalIdentities.Count-ne10){throw 'C2V35 exact target identity cardinality changed before proposal lookup.'}
    foreach($physicalIdentity in $frontPhysicalIdentities){
        $directory=Join-Path $proposalRoot $physicalIdentity
        Assert-PathBudget $directory
        $proposalPath=Join-Path $directory 'SCRIBE_PROPOSAL.json';$readerPath=Join-Path $directory 'scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json';$readerHoldPath=Join-Path $directory 'scribe\multi_channel\MULTI_CHANNEL_READER_HOLD.json'
        foreach($path in @($proposalPath,$readerPath,$readerHoldPath)){Assert-PathBudget $path}
        $proposal=if(Test-Path -LiteralPath $proposalPath -PathType Leaf){Read-JsonSnapshot $proposalPath 1048576}else{$null}
        $reader=if(Test-Path -LiteralPath $readerPath -PathType Leaf){Read-JsonSnapshot $readerPath 1048576}else{$null}
        $readerHold=if(Test-Path -LiteralPath $readerHoldPath -PathType Leaf){Read-JsonSnapshot $readerHoldPath 1048576}else{$null}
        $targetProposalRows.Add([pscustomobject][ordered]@{
            physicalIdentity=$physicalIdentity
            proposalDirectoryExists=(Test-Path -LiteralPath $directory -PathType Container)
            proposalState=[string](Get-Optional $proposal 'state' '')
            proposal=[string](Get-Optional $proposal 'proposal' '')
            proposalFailure=[string](Get-Optional $proposal 'failure' '')
            readerState=[string](Get-Optional $reader 'state' '')
            consensusState=[string](Get-Optional $reader 'consensusState' '')
            candidateCount=[int](Get-Optional $reader 'candidateCount' 0)
            uniqueImageCandidate=[string](Get-Optional $reader 'uniqueImageCandidate' '')
            candidates=if($reader){@($reader.candidates|ForEach-Object{[pscustomobject]@{string=[string](Get-Optional $_ 'string' '');directImageFirstSupport=[bool](Get-Optional $_ 'directImageFirstSupport' $false);maximumScore=[double](Get-Optional $_ 'maximumScore' 0);supportCount=[int](Get-Optional $_ 'supportCount' 0)}})}else{@()}
            readerHoldState=[string](Get-Optional $readerHold 'state' '')
            readerHoldDetail=[string](Get-Optional $readerHold 'detail' '')
        })
    }
}
$sessionSummary=New-Object Collections.Generic.List[object]
foreach($session in @($dashboard.scanSessions|Where-Object{[string]$_.lot-eq$lot-and[string]$_.scanTimestampLocal-like($scanDate+'*')})){
    $wafers=@($session.wafers);$frontAssetWafers=@($wafers|Where-Object{-not[string]::IsNullOrWhiteSpace([string](Get-Optional $_ 'frontsideBfRaw' ''))-or-not[string]::IsNullOrWhiteSpace([string](Get-Optional $_ 'frontsideDfRaw' ''))})
    $backAssetWafers=@($wafers|Where-Object{-not[string]::IsNullOrWhiteSpace([string](Get-Optional $_ 'backsideBfRaw' ''))-or-not[string]::IsNullOrWhiteSpace([string](Get-Optional $_ 'backsideDfRaw' ''))})
    $sessionSummary.Add([pscustomobject]@{scanTimestampLocal=[string]$session.scanTimestampLocal;waferCount=$wafers.Count;frontsideAssetWafers=$frontAssetWafers.Count;backsideAssetWafers=$backAssetWafers.Count})
}
$lastImported=if(Test-Path -LiteralPath $lastImportedPath -PathType Leaf){Read-JsonSnapshot $lastImportedPath 1048576}else{$null}
$lastQueued=if(Test-Path -LiteralPath $lastQueuedPath -PathType Leaf){Read-JsonSnapshot $lastQueuedPath 1048576}else{$null}
$responseShape=[ordered]@{rootProperties=@();transportEnvelope='';transportRequestKind='';logicalRequestSha256='';transportRequestSha256='';transportCandidateRequestSha256='';requestRowCount=0;requestRows=@();allAcquisitionContextCount=0;allAcquisitionContextKeys=@()}
if($null-ne$processedPayload){
    $requestRows=@(Get-Optional $processedPayload 'requestRows' @())
    if($requestRows.Count-gt25){throw 'C2V35 processed response request-row bound exceeded.'}
    $allContexts=@($processedPayload.records|ForEach-Object{@(Get-Optional $_ 'acquisitionContexts' @())}|ForEach-Object{$_})
    if($allContexts.Count-gt100){throw 'C2V35 processed response acquisition-context bound exceeded.'}
    $responseShape=[ordered]@{
        rootProperties=@($processedPayload.PSObject.Properties.Name|Sort-Object)
        transportEnvelope=[string](Get-Optional $processedPayload 'transportEnvelope' '')
        transportRequestKind=[string](Get-Optional $processedPayload 'transportRequestKind' '')
        logicalRequestSha256=[string](Get-Optional $processedPayload 'requestContentSha256' '')
        transportRequestSha256=[string](Get-Optional $processedPayload 'transportRequestContentSha256' '')
        transportCandidateRequestSha256=[string](Get-Optional $processedPayload 'transportCandidateRequestContentSha256' '')
        requestRowCount=$requestRows.Count
        requestRows=@($requestRows|ForEach-Object{[pscustomobject]@{acquisitionKey=[string](Get-Optional $_ 'acquisitionKey' '');candidateScribes=@(Get-Optional $_ 'candidateScribes' @());candidateCount=@(Get-Optional $_ 'candidateScribes' @()).Count}})
        allAcquisitionContextCount=$allContexts.Count
        allAcquisitionContextKeys=@($allContexts|ForEach-Object{[string](Get-Optional $_ 'acquisitionKey' '')}|Where-Object{$_}|Sort-Object -Unique)
    }
}
$confirmedPath=Join-Path $stateRoot 'identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json'
$verifiedPath=Join-Path $stateRoot 'metadata\verified\ACTIVE_VERIFIED_METADATA_OVERLAY.json'
$activeHoldPath=Join-Path $stateRoot 'metadata\holds\ACTIVE_INSITE_METADATA_HOLDS.json'
$candidateAuditRoot=Join-Path $stateRoot 'identity\candidate_resolutions'
$exporterPath=Join-Path $stateRoot 'Export-JbodPendingInsiteRequestV2.ps1'
foreach($path in @($confirmedPath,$verifiedPath,$activeHoldPath,$candidateAuditRoot,$exporterPath)){Assert-PathBudget $path}
foreach($path in @($confirmedPath,$exporterPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "C2V35 overlay diagnostic input missing: $path"}}
$confirmedOverlay=Read-JsonSnapshot $confirmedPath 16777216
if([string]$confirmedOverlay.schema-ne'argos_confirmed_scribe_overlay_v1'-or-not[bool]$confirmedOverlay.reviewOnly-or[bool]$confirmedOverlay.productionEligible){throw 'C2V35 confirmed overlay contract changed.'}
$targetConfirmedRows=@($confirmedOverlay.rows|Where-Object{$targetIdentitySet.ContainsKey(([string]$_.acquisitionKey).Trim().ToUpperInvariant())}|ForEach-Object{[pscustomobject]@{acquisitionKey=[string]$_.acquisitionKey;scribe=[string]$_.scribe;identityState=[string]$_.identityState;scribeChecksumState=[string]$_.scribeChecksumState;imageReadAuthority=[string]$_.imageReadAuthority}})
$priorLotGroups=@($confirmedOverlay.rows|Where-Object{$key=([string]$_.acquisitionKey).Trim().ToUpperInvariant();$key.StartsWith($lot,[StringComparison]::OrdinalIgnoreCase)-and-not$targetIdentitySet.ContainsKey($key)}|Group-Object {([string]$_.scribe).Trim().ToUpperInvariant()}|Sort-Object Name)
if($priorLotGroups.Count-gt50){throw 'C2V35 prior-lot confirmed-scribe group bound exceeded.'}
$priorLotScribes=@($priorLotGroups|ForEach-Object{[pscustomobject]@{scribe=[string]$_.Name;acquisitionCount=$_.Count;humanConfirmedCount=@($_.Group|Where-Object{[string]$_.identityState-eq'HUMAN_CONFIRMED_REVIEW_ONLY'}).Count;identityStates=@($_.Group.identityState|Sort-Object -Unique);acquisitionKeys=@($_.Group.acquisitionKey|Sort-Object|Select-Object -Last 5)}})
$targetVerifiedRows=@()
if(Test-Path -LiteralPath $verifiedPath -PathType Leaf){$verifiedOverlay=Read-JsonSnapshot $verifiedPath 16777216;$targetVerifiedRows=@($verifiedOverlay.rows|Where-Object{$targetIdentitySet.ContainsKey(([string]$_.acquisitionKey).Trim().ToUpperInvariant())}|ForEach-Object{[pscustomobject]@{acquisitionKey=[string]$_.acquisitionKey;scribe=[string]$_.scribe;metadataQualificationState=[string]$_.metadataQualificationState;scanTimeContextState=[string]$_.scanTimeContextState;frontsideScratchTestRouteState=[string]$_.frontsideScratchTestRouteState;frontsideScratchTestRouteAuthority=[string]$_.frontsideScratchTestRouteAuthority}})}
$targetActiveHolds=@()
if(Test-Path -LiteralPath $activeHoldPath -PathType Leaf){$holdOverlay=Read-JsonSnapshot $activeHoldPath 8388608;$targetActiveHolds=@($holdOverlay.rows|Where-Object{$targetIdentitySet.ContainsKey(([string]$_.acquisitionKey).Trim().ToUpperInvariant())}|ForEach-Object{[pscustomobject]@{acquisitionKey=[string]$_.acquisitionKey;scribe=[string]$_.scribe;state=[string]$_.state;terminal=[bool]$_.terminal;attemptCount=[int]$_.attemptCount;nextRetryUtc=[string]$_.nextRetryUtc}})}
$targetCandidateResolutions=New-Object Collections.Generic.List[object];$auditFilesInspected=0
if(Test-Path -LiteralPath $candidateAuditRoot -PathType Container){
    $auditFiles=@(Get-ChildItem -LiteralPath $candidateAuditRoot -File -Filter 'C_*.json' -ErrorAction Stop|Sort-Object LastWriteTimeUtc -Descending|Select-Object -First 256)
    foreach($auditFile in $auditFiles){if($auditFile.Length-gt4194304){throw "C2V35 candidate audit exceeds bound: $($auditFile.Name)"};$auditFilesInspected++;$audit=Read-JsonSnapshot $auditFile.FullName 4194304;foreach($row in @($audit.resolutions)){if($targetIdentitySet.ContainsKey(([string]$row.acquisitionKey).Trim().ToUpperInvariant())){if($targetCandidateResolutions.Count-ge20){throw 'C2V35 target candidate-resolution bound exceeded.'};$resolution=$row.resolution;$targetCandidateResolutions.Add([pscustomobject]@{auditFile=$auditFile.Name;requestContentSha256=[string]$audit.requestContentSha256;sourceSnapshotSha256=[string]$audit.sourceSnapshotSha256;acquisitionKey=[string]$row.acquisitionKey;state=[string](Get-Optional $resolution 'state' '');candidateCount=[int](Get-Optional $resolution 'candidateCount' 0);exactMesLotMatchCount=[int](Get-Optional $resolution 'exactMesLotMatchCount' 0);resolvedScribe=[string](Get-Optional $resolution 'resolvedScribe' '')})}}}
}
$exporterSha256=(Get-FileHash -LiteralPath $exporterPath -Algorithm SHA256).Hash
$importedHash=([string](Get-Optional $lastImported 'requestContentSha256' '')).Trim().ToUpperInvariant()
$queuedHash=([string](Get-Optional $lastQueued 'requestContentSha256' '')).Trim().ToUpperInvariant()
$targetPackageLocations=@($packageRows|Where-Object{$_.exists}|ForEach-Object{[string]$_.state})
$catalogAcceptance=($frontPhysicalIdentities.Count-eq10)
$guiAcceptance=(@($sessionSummary|Where-Object{$_.frontsideAssetWafers-eq10}).Count-gt0)
$disposition=if($catalogAcceptance-and$guiAcceptance){'PASS_TEN_62631_586_FRONTS_VISIBLE'}elseif($catalogAcceptance){'PENDING_DASHBOARD_REFRESH'}elseif($importedHash-eq$targetRequestSha){'PENDING_CATALOG_REFRESH_AFTER_TARGET_IMPORT'}elseif($targetPackageLocations.Count){'PENDING_TARGET_RESPONSE_IMPORT'}else{'TARGET_RESPONSE_NOT_PRESENT_ON_JBOD'}

[ordered]@{
    schema='argos_jbod_front_catalog_probe_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_C2V35_BOUNDED_LIVE_SNAPSHOT';disposition=$disposition;rehearsal=$isRehearsal;lot=$lot;scanDate=$scanDate;configSha256=$configSha
    targetRequestSha256=$targetRequestSha;targetResponseId=$targetResponseId;targetPackageLocations=$targetPackageLocations;targetPackageSnapshots=$packageRows.ToArray();responseAcquisitionKeys=$responseAcquisitionKeys;processedPayload=$processedPayloadSummary;responseShape=$responseShape;runtimePaths=$runtimePaths;runtimeHashes=$runtimeHashes;exporterSha256=$exporterSha256;lastQueuedRequest=$lastQueued;lastQueuedMatchesTarget=($queuedHash-eq$targetRequestSha);lastImportedResponse=$lastImported;lastImportedMatchesTarget=($importedHash-eq$targetRequestSha)
    frontCatalogRows=$frontRows.Count;distinctFrontPhysicalIdentities=$frontPhysicalIdentities.Count;frontSlots=$frontSlots;frontPhysicalIdentities=$frontPhysicalIdentities;frontRows=$frontRowSummary
    targetLedgerRows=$targetLedgerRows;dashboardReadiness=$dashboardReadiness;targetDashboardExclusions=$targetDashboardExclusions;targetProposals=$targetProposalRows.ToArray();targetConfirmedRows=$targetConfirmedRows;priorLotScribes=$priorLotScribes;targetVerifiedRows=$targetVerifiedRows;targetActiveHolds=$targetActiveHolds;candidateAuditFilesInspected=$auditFilesInspected;targetCandidateResolutions=$targetCandidateResolutions.ToArray()
    dashboardSessions=$sessionSummary.ToArray();catalogAcceptance=$catalogAcceptance;guiAcceptance=$guiAcceptance
    catalogReadPerformed=$true;dashboardReadPerformed=$true;fullQueueEnumerationPerformed=$false;historicalRootEnumerationPerformed=$false;imageFilesRead=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;trayRestarted=$false;waferAborted=$false;reviewOnly=$true;xmlExportEnabled=$false;productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 12
