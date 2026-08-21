[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$stateRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$bridgeRoot='C:\ProgramData\ArgosInsiteBridgeRO'
$targetRequestSha='5C08CE4E6D8A4603B14BFC1692B30CE4E64CAE538A7D1FA7CE94C66CC095518C'
$targetResponseId='INSITE_RESP__5C08CE4E6D8A4603B14BFC1692B30CE4'
$targetPayloadSha='C816B8EFF451940F0B85FDF59BC43D2031FCB9FF5DDAF8DC895CDFFA209B05B1'
$importerSha='45965930699A0F0C38098B65E5A153C5DE360103BC9FED345AC5811B6F1FBD0D'
$configSha='CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$routeContract='LATEST_QUALIFYING_NUMBERED_SACRIFICIAL_NITRIDE_DEP_ANCHOR_AT_OR_BEFORE_EXACT_SCAN; SELECTED_BLOCK_INSTANCE_FOLLOW_ON_ALLOWED; EAGLE_OR_LV150MM_ONLY_AFTER_SELECTED_BLOCK; RECIPE_FOLDER_NAMES_UNUSED'
$rehearsal=$false
$forceFailureBeforeImport=$false

function Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Read-Json([string]$Path,[int64]$MaximumBytes=2097152){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "R7 required file missing: $Path"}
    if([int64](Get-Item -LiteralPath $Path).Length-gt$MaximumBytes){throw "R7 JSON exceeds bounded size: $Path"}
    return Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json
}
function Property-Text([object]$Object,[string]$Name){
    if($null-eq$Object){return ''}
    $property=$Object.PSObject.Properties[$Name]
    if($null-eq$property-or$null-eq$property.Value){return ''}
    return [string]$property.Value
}

$controlPath=[Environment]::GetEnvironmentVariable('ARGOS_R7_REHEARSAL_MANIFEST','Process')
if(-not[string]::IsNullOrWhiteSpace($controlPath)){
    $control=Read-Json ([IO.Path]::GetFullPath($controlPath)) 1048576
    if([string]$control.schema-ne'argos_r7_processed_response_replay_rehearsal_v1'-or-not[bool]$control.rehearsal){throw 'R7 rehearsal contract refused.'}
    $stateRoot=[IO.Path]::GetFullPath([string]$control.stateRoot).TrimEnd('\')
    $bridgeRoot=[IO.Path]::GetFullPath([string]$control.bridgeRoot).TrimEnd('\')
    if([string]$control.targetRequestSha-cnotmatch'^[A-F0-9]{64}$'-or
       [string]$control.targetResponseId-cnotmatch'^INSITE_RESP__[A-F0-9]{32}$'-or
       [string]$control.targetPayloadSha-cnotmatch'^[A-F0-9]{64}$'){
        throw 'R7 rehearsal response identity refused.'
    }
    $targetRequestSha=[string]$control.targetRequestSha
    $targetResponseId=[string]$control.targetResponseId
    $targetPayloadSha=[string]$control.targetPayloadSha
    if([string]$control.expectedConfigSha-cnotmatch'^[A-F0-9]{64}$'){throw 'R7 rehearsal config hash refused.'}
    $configSha=[string]$control.expectedConfigSha
    $forceFailureBeforeImport=[bool]$control.forceFailureBeforeImport
    $rehearsal=$true
}

$importer=Join-Path $stateRoot 'Import-JbodLiveInsiteSnapshot.ps1'
$configPath=Join-Path $stateRoot 'PROCESSOR_CONFIG.json'
$responseRoot=Join-Path $bridgeRoot ('response_inbox\processed\'+$targetResponseId+'.ready')
$manifestPath=Join-Path $responseRoot 'INSITE_RESPONSE_MANIFEST.json'
$payloadPath=Join-Path $responseRoot 'INSITE_RESPONSE.json'
foreach($path in @($importer,$configPath,$manifestPath,$payloadPath)){
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "R7 exact replay input missing: $path"}
    $effective=[IO.Path]::GetFullPath($path).Length+32
    if($effective-ge200){throw "R7 unsafe effective path length ${effective}: $path"}
}
if((Sha $importer)-ne$importerSha){throw 'R7 installed released importer hash changed.'}
if((Sha $configPath)-ne$configSha){throw 'R7 processor config hash changed.'}
$config=Read-Json $configPath 1048576
if(-not[bool]$config.reviewOnly-or[bool]$config.xmlExportEnabled-or
   (($config.PSObject.Properties.Name-contains'productionRoutingEnabled')-and[bool]$config.productionRoutingEnabled)-or
   [string]::IsNullOrWhiteSpace([string]$config.metadataSnapshotRoot)){throw 'R7 processor metadata-root contract refused.'}
$metadataSnapshotRoot=[IO.Path]::GetFullPath([string]$config.metadataSnapshotRoot).TrimEnd('\')
if(($metadataSnapshotRoot.Length+32)-ge200){throw 'R7 configured metadata root is unsafe.'}
$manifest=Read-Json $manifestPath 1048576
$snapshot=Read-Json $payloadPath 1048576
if([string]$manifest.schema-ne'argos_insite_response_relay_manifest_v1'-or
   [string]$manifest.requestContentSha256-cne$targetRequestSha-or
   [string]$manifest.payloadFile-cne'INSITE_RESPONSE.json'-or
   [int64]$manifest.bytes-ne[int64](Get-Item -LiteralPath $payloadPath).Length-or
   [string]$manifest.sha256-cne$targetPayloadSha-or
   (Sha $payloadPath)-ne$targetPayloadSha-or
   [bool]$manifest.imagesIncluded-or[bool]$manifest.credentialsIncluded-or
   -not[bool]$manifest.reviewOnly-or[bool]$manifest.trainingEligible-or
   [bool]$manifest.xmlEligible-or[bool]$manifest.productionEligible-or
   [bool]$manifest.productionRoutingEnabled){throw 'R7 exact processed response binding refused.'}
if([string]$snapshot.authority-cne'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT'-or
   [string]$snapshot.lookupKey-cne'confirmed 12-character wafer scribe'-or
   [string]$snapshot.frontsideScratchTestRouteContract-cne$routeContract-or
   $snapshot.PSObject.Properties.Name-contains'transportEnvelope'){
    throw 'R7 signed payload shape is not the exact normal confirmed-scribe snapshot.'
}
$routeRows=New-Object Collections.Generic.List[object]
foreach($record in @($snapshot.records)){
    if(-not($record.PSObject.Properties.Name-contains'acquisitionContexts')){continue}
    foreach($context in @($record.acquisitionContexts)){
        if((Property-Text $context 'acquisitionKey')-ne''-and
           $null-ne$context.frontsideScratchTestRoute-and
           (Property-Text $context.frontsideScratchTestRoute 'state')-eq'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED'-and
           (Property-Text $context.frontsideScratchTestRoute 'fingerprintVersion')-eq'FRONTSIDE_SCRATCH_TEST_ROUTE_V3'){
            $routeRows.Add($context)
        }
    }
}
$expectedKeys=@($routeRows.ToArray()|ForEach-Object{Property-Text $_ 'acquisitionKey'}|Sort-Object -Unique)
if($routeRows.Count-ne10-or$expectedKeys.Count-ne10){throw 'R7 exact response no longer contains ten unique V3 route contexts.'}
$preflightResult=& $importer -StateRoot $stateRoot -MetadataSnapshotRoot $metadataSnapshotRoot -MesSnapshotPath $payloadPath -Preflight
if([string]$preflightResult.State-ne'PASS_JBOD_LIVE_INSITE_IMPORT_CURRENT_IMAGE_IDENTITY_PREFLIGHT'-or[bool]$preflightResult.MutationPerformed){throw 'R7 released importer preflight failed.'}
if($Preflight){
    [ordered]@{schema='argos_r7_processed_response_replay_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R7_EXACT_PROCESSED_RESPONSE_REPLAY_PREFLIGHT';rehearsal=$rehearsal;requestContentSha256=$targetRequestSha;responseId=$targetResponseId;payloadSha256=$targetPayloadSha;installedImporterSha256=$importerSha;configSha256=$configSha;metadataSnapshotRoot=$metadataSnapshotRoot;expectedRouteRows=$expectedKeys.Count;transportEnvelopePresent=$false;sourceRetained=$true;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}
if($forceFailureBeforeImport){throw 'R7 injected failure before processed response import.'}
$result=& $importer -StateRoot $stateRoot -MetadataSnapshotRoot $metadataSnapshotRoot -MesSnapshotPath $payloadPath
if([string]$result.State-ne'PASS_LIVE_INSITE_SNAPSHOT_IMPORTED_REVIEW_ONLY'){throw 'R7 released importer apply failed.'}
$overlay=Read-Json ([string]$result.ActiveOverlay) 16777216
if([string]$overlay.schema-ne'argos_verified_scribe_mes_metadata_overlay_v1'-or[string]$overlay.state-ne'VERIFIED_REVIEW_ONLY'){throw 'R7 active verified overlay contract refused.'}
$verified=@($overlay.rows|Where-Object{$expectedKeys-contains(Property-Text $_ 'acquisitionKey')})
$verifiedKeys=@($verified|ForEach-Object{Property-Text $_ 'acquisitionKey'}|Sort-Object -Unique)
$bad=@($verified|Where-Object{
    (Property-Text $_ 'frontsideScratchTestRouteState')-ne'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED'-or
    (Property-Text $_ 'frontsideScratchTestFingerprintVersion')-ne'FRONTSIDE_SCRATCH_TEST_ROUTE_V3'
})
if($verified.Count-ne10-or$verifiedKeys.Count-ne10-or$bad.Count-ne0){throw 'R7 verified metadata overlay did not admit every exact V3 route context.'}
if(-not(Test-Path -LiteralPath $payloadPath -PathType Leaf)-or(Sha $payloadPath)-ne$targetPayloadSha){throw 'R7 preserved response was not retained byte-for-byte.'}
[ordered]@{schema='argos_r7_processed_response_replay_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R7_EXACT_PROCESSED_RESPONSE_REIMPORTED';rehearsal=$rehearsal;requestContentSha256=$targetRequestSha;responseId=$targetResponseId;payloadSha256=$targetPayloadSha;installedImporterSha256=$importerSha;configSha256=$configSha;metadataSnapshotRoot=$metadataSnapshotRoot;importerResultState=[string]$result.State;expectedRouteRows=$expectedKeys.Count;verifiedRouteRows=$verifiedKeys.Count;activeVerifiedRows=@($overlay.rows).Count;activeOverlay=[string]$result.ActiveOverlay;sourceRetained=$true;sourceDeletionPerformed=$false;hardcodedIdentityUsed=$false;taskActionsPerformed=0;reviewOnly=$true;xmlEligible=$false;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 7
