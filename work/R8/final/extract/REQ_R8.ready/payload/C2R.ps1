[CmdletBinding()]
param([switch]$Rehearsal,[string]$InvocationManifest='')

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

$processorRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$taskName='ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'
$lot='62631-586'
$scan='20260819173317'
$dRootBoundary=[DateTime]::Parse('2026-08-20T02:05:10Z').ToUniversalTime()
$expectedConfig='CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$approvedRunnerBefore='6B61A415DF2F6852C290ABD0F794E86BE13B270A91E9E86E005B76A468404F1C'
$expectedRunner='46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
$expectedInventory='8919C3DD4AC04FD662B57E356AC6E1A70BD614E97AFC270EB4B8FF617D705160'
$expectedImporter='45965930699A0F0C38098B65E5A153C5DE360103BC9FED345AC5811B6F1FBD0D'
$isRehearsal=[bool]$Rehearsal
$manifestText=[string]$InvocationManifest
if(-not[string]::IsNullOrWhiteSpace($env:ARGOS_C2R_REHEARSAL_MANIFEST)){$manifestText=$env:ARGOS_C2R_REHEARSAL_MANIFEST;$isRehearsal=$true}
$fixture=$null
if($isRehearsal){
    if([string]::IsNullOrWhiteSpace($manifestText)){throw 'C2R rehearsal requires InvocationManifest.'}
    $fixture=Get-Content -LiteralPath ([IO.Path]::GetFullPath($manifestText)) -Raw|ConvertFrom-Json
    if([string]$fixture.schema-ne'argos_c2r_rehearsal_v1'){throw 'C2R rehearsal schema changed.'}
    $processorRoot=[IO.Path]::GetFullPath([string]$fixture.processorRoot).TrimEnd('\')
}

function Get-Optional([object]$Object,[string]$Name,$Default){$p=$Object.PSObject.Properties[$Name];if($null-eq$p){return $Default};return $p.Value}
if($isRehearsal){
    $expectedInventory=[string](Get-Optional $fixture 'expectedInventorySha256' $expectedInventory)
    $expectedImporter=[string](Get-Optional $fixture 'expectedImporterSha256' $expectedImporter)
}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Get-BudgetedPath([string]$Path){$full=[IO.Path]::GetFullPath($Path);$component=0;foreach($part in $full.Split([IO.Path]::DirectorySeparatorChar,[StringSplitOptions]::RemoveEmptyEntries)){if($part.Length-gt$component){$component=$part.Length}};if($full.Length+32-ge200-or$component-gt80){throw "R8 path budget refused: $full"};return $full}
function Get-TextSha([string]$Text){$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text);$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}finally{$sha.Dispose()}}
function Read-Tasks([string]$Phase){
    if($isRehearsal){$property=if($Phase-eq'before'){'tasksBefore'}else{'tasksAfter'};return @((Get-Optional $fixture $property @()))}
    return @(Get-ScheduledTask -ErrorAction Stop|Where-Object{$_.TaskName-like'Argos*'-or$_.TaskName-like'ArgosProjectPortal*'}|Sort-Object TaskPath,TaskName|ForEach-Object{
        $xml=Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath
        [pscustomobject]@{name=[string]$_.TaskName;taskPath=[string]$_.TaskPath;principal=[string]$_.Principal.UserId;state=[string]$_.State;definitionSha256=Get-TextSha $xml;actions=@($_.Actions|ForEach-Object{[pscustomobject]@{execute=[string](Get-Optional $_ 'Execute' '');arguments=[string](Get-Optional $_ 'Arguments' '')}})}
    })
}
function Read-ProcessorProcesses([string]$Phase){
    if($isRehearsal){$property=if($Phase-eq'before'){'processesBefore'}else{'processesAfter'};return @((Get-Optional $fixture $property @()))}
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop|Where-Object{
        $command=[string](Get-Optional $_ 'CommandLine' '')
        $command.IndexOf($runnerPath,[StringComparison]::OrdinalIgnoreCase)-ge0-and$command.IndexOf($processorRoot,[StringComparison]::OrdinalIgnoreCase)-ge0
    }|ForEach-Object{[pscustomobject]@{processId=[int]$_.ProcessId;commandLine=[string]$_.CommandLine;creationUtc=([DateTime]$_.CreationDate).ToUniversalTime().ToString('o')}})
}
function Compare-ProtectedTasks([object[]]$Before,[object[]]$After){
    if($Before.Count-ne$After.Count){throw 'C2R protected task cardinality changed.'}
    foreach($row in $Before){
        $match=@($After|Where-Object{[string]$_.name-eq[string]$row.name-and[string]$_.taskPath-eq[string]$row.taskPath})
        if($match.Count-ne1-or[string]$match[0].principal-ne[string]$row.principal-or[string]$match[0].definitionSha256-ne[string]$row.definitionSha256){throw "C2R protected task definition or principal changed: $($row.name)"}
    }
}
function Normalize-Key([string]$Value){
    if([string]::IsNullOrWhiteSpace($Value)){return ''}
    $normalized=$Value.Trim().ToUpperInvariant()
    $match=[regex]::Match($normalized,'^(?<lot>\d{5}[-_]\d{3})(?<variant>.*?)_(?<stamp>\d{14})_SLOT0*(?<slot>\d+)$')
    if(-not$match.Success){return $normalized}
    $lotToken=$match.Groups['lot'].Value.Replace('_','-');$variant=$match.Groups['variant'].Value
    return ('{0}{1}_{2}_SLOT{3:D2}'-f$lotToken,$variant,$match.Groups['stamp'].Value,[int]$match.Groups['slot'].Value)
}
function Read-LotState([string]$Phase){
    if($isRehearsal){$property=if($Phase-eq'before'){'lotStateBefore'}else{'lotStateAfter'};return (Get-Optional $fixture $property $null)}
    $queue=Get-Content -LiteralPath (Join-Path $processorRoot 'identity\SCRIBE_IDENTITY_QUEUE.json') -Raw|ConvertFrom-Json
    $catalog=Get-Content -LiteralPath (Join-Path $processorRoot 'catalog\ALL_WAFER_CATALOG.json') -Raw|ConvertFrom-Json
    $overlay=Get-Content -LiteralPath (Join-Path ([string]$config.metadataSnapshotRoot) 'ACTIVE_VERIFIED_METADATA_OVERLAY.json') -Raw|ConvertFrom-Json
    if([string]$queue.schema-ne'argos_jbod_scribe_identity_queue_v1'-or[string]$catalog.schema-ne'argos_jbod_all_wafer_catalog_v1'-or[string]$overlay.schema-ne'argos_verified_scribe_mes_metadata_overlay_v1'-or-not[bool]$catalog.reviewOnly-or[bool]$catalog.xmlExportEnabled-or-not[bool]$overlay.reviewOnly-or[bool]$overlay.xmlEligible-or[bool]$overlay.productionEligible){throw 'C2R live queue/catalog/overlay safety contract changed.'}
    $expected=@(1..10|ForEach-Object{('{0}_{1}_Slot{2:D2}'-f$lot,$scan,$_)});$queueRows=@($queue.rows|Where-Object{$expected-contains[string]$_.physicalIdentity})
    if($queueRows.Count-ne10){throw "C2R expected ten current queue rows; found $($queueRows.Count)."}
    $confirmed=@($queueRows|Where-Object{[string]$_.state-eq'SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'})
    $catalogRows=@($catalog.acquisitions|Where-Object{$expected-contains[string]$_.physicalIdentity})
    if($catalogRows.Count-ne20){throw "C2R expected twenty current catalog rows; found $($catalogRows.Count)."}
    $overlayKeys=@{};foreach($row in @($overlay.rows)){$key=Normalize-Key ([string]$row.acquisitionKey);if($expected-contains$key){$overlayKeys[$key]=$true}}
    $matchedRows=@($catalogRows|Where-Object{$overlayKeys.ContainsKey((Normalize-Key ([string]$_.physicalIdentity)))})
    $staleRows=@($matchedRows|Where-Object{[string]$_.routeState-like'HOLD_INSITE_*'})
    $scribeRows=@($catalogRows|Where-Object{[string]$_.routeState-eq'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'})
    $notReadyRows=@($matchedRows|Where-Object{[string]$_.routeState-notlike'READY_*'})
    return [pscustomobject]@{catalogGeneratedUtc=[string]$catalog.generatedUtc;queueRows=$queueRows.Count;confirmedPhysical=$confirmed.Count;overlayPhysicalMatches=$overlayKeys.Count;catalogRows=$catalogRows.Count;metadataMatchedCatalogRows=$matchedRows.Count;staleMatchedInsiteRows=$staleRows.Count;scribeHoldRows=$scribeRows.Count;notReadyMatchedRows=$notReadyRows.Count;routeStates=@($catalogRows|Group-Object routeState|ForEach-Object{[pscustomobject]@{state=$_.Name;count=$_.Count}})}
}

$configPath=Join-Path $processorRoot 'PROCESSOR_CONFIG.json'
$runnerPath=Join-Path $processorRoot 'Run-JbodAllWaferProcessor.ps1'
$inventoryPath=Join-Path $processorRoot 'Invoke-JbodAllWaferInventory.ps1'
$importerPath=Join-Path $processorRoot 'Import-JbodLiveInsiteSnapshot.ps1'
$statusPath=Join-Path $processorRoot 'processor\PROCESSOR_STATUS.json'
$runnerPayload=Get-BudgetedPath (Join-Path $PSScriptRoot 'Run-JbodAllWaferProcessor.ps1')
foreach($row in @([pscustomobject]@{path=$configPath;hash=$expectedConfig;label='config'},[pscustomobject]@{path=$inventoryPath;hash=$expectedInventory;label='inventory consumer'},[pscustomobject]@{path=$importerPath;hash=$expectedImporter;label='snapshot importer'},[pscustomobject]@{path=$runnerPayload;hash=$expectedRunner;label='runner repair payload'})){
    if(-not(Test-Path -LiteralPath $row.path -PathType Leaf)-or(Get-Sha $row.path)-ne[string]$row.hash){throw "C2R installed $($row.label) hash changed."}
}
$runnerBeforeSha=if(Test-Path -LiteralPath $runnerPath -PathType Leaf){Get-Sha $runnerPath}else{''}
if($runnerBeforeSha-notin@($approvedRunnerBefore,$expectedRunner)){throw "R8 installed runner predecessor is not approved: $runnerBeforeSha"}
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
if([string]$config.schema-ne'argos_jbod_all_wafer_processor_config_v3'-or-not[bool]$config.reviewOnly-or[bool]$config.xmlExportEnabled-or[bool](Get-Optional $config 'productionRoutingEnabled' $false)-or[string]$config.metadataSnapshotRoot-ne'D:\A2\m\verified'-or[bool]$config.processorCooperativeHold){throw 'C2R D-root processor contract refused.'}
$status=Get-Content -LiteralPath $statusPath -Raw|ConvertFrom-Json
if(-not[bool]$status.reviewOnly-or[bool]$status.xmlExportEnabled-or-not[string]::IsNullOrWhiteSpace([string](Get-Optional $status 'currentIdentity' ''))){throw 'C2R requires an idle review-only processor boundary.'}
$runnerChanged=$false;$runnerEvidence='';$runnerPrior=''
if($runnerBeforeSha-eq$approvedRunnerBefore){
    $runnerEvidence=Get-BudgetedPath (Join-Path $processorRoot ('state\maintenance_runner_fix\R8_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')))
    if(Test-Path -LiteralPath $runnerEvidence){throw 'R8 runner evidence collision.'}
    $runnerPrior=Get-BudgetedPath (Join-Path $runnerEvidence 'prior.ps1');$backup=Get-BudgetedPath (Join-Path $runnerEvidence 'swap.bak');$failed=Get-BudgetedPath (Join-Path $runnerEvidence 'failed.ps1')
    $stage=Get-BudgetedPath (Join-Path $processorRoot 'R8.stage.ps1');$restore=Get-BudgetedPath (Join-Path $processorRoot 'R8.restore.ps1')
    foreach($path in @($stage,$restore)){if(Test-Path -LiteralPath $path){throw "R8 runner swap collision: $path"}}
    [void](New-Item -ItemType Directory -Path $runnerEvidence -Force);Copy-Item -LiteralPath $runnerPath -Destination $runnerPrior
    if((Get-Sha $runnerPrior)-ne$approvedRunnerBefore){throw 'R8 archived predecessor changed.'}
    $swapped=$false
    try{
        Copy-Item -LiteralPath $runnerPayload -Destination $stage;if((Get-Sha $stage)-ne$expectedRunner){throw 'R8 staged runner changed.'}
        [IO.File]::Replace($stage,$runnerPath,$backup,$true);$swapped=$true
        if((Get-Sha $runnerPath)-ne$expectedRunner){throw 'R8 repaired runner absent after swap.'}
        if($isRehearsal-and[bool](Get-Optional $fixture 'failAfterSwap' $false)){throw 'INJECTED_R8_FAILURE_AFTER_SWAP'}
        $runnerChanged=$true
    }catch{
        $failure=$_
        if($swapped){Copy-Item -LiteralPath $runnerPrior -Destination $restore;[IO.File]::Replace($restore,$runnerPath,$failed,$true);if((Get-Sha $runnerPath)-ne$approvedRunnerBefore){throw 'R8 runner rollback failed.'}}
        throw $failure
    }finally{foreach($path in @($stage,$restore)){if(Test-Path -LiteralPath $path -PathType Leaf){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}}}
}
if((Get-Sha $runnerPath)-ne$expectedRunner){throw 'R8 repaired runner is not installed.'}
$runnerLastWriteUtc=(Get-Item -LiteralPath $runnerPath).LastWriteTimeUtc
$inventoryLastWriteUtc=(Get-Item -LiteralPath $inventoryPath).LastWriteTimeUtc
$beforeState=Read-LotState 'before'
if([int]$beforeState.confirmedPhysical-ne10-or[int]$beforeState.overlayPhysicalMatches-ne10-or[int]$beforeState.metadataMatchedCatalogRows-ne20){throw 'R8 expected ten confirmed physical acquisitions and twenty side-specific overlay-matched catalog rows.'}

$tasksBefore=@(Read-Tasks 'before');if($tasksBefore.Count-eq0){throw 'C2R protected task set is empty.'}
$targetBefore=@($tasksBefore|Where-Object{[string]$_.name-eq$taskName})
if($targetBefore.Count-ne1-or[string]::IsNullOrWhiteSpace([string]$targetBefore[0].principal)){throw 'C2R exact processor task is missing or ambiguous.'}
$targetActions=@($targetBefore[0].actions);if($targetActions.Count-ne1){throw "C2R exact processor task must have one action; found $($targetActions.Count)."}
$action=([string]$targetActions[0].execute)+' '+([string]$targetActions[0].arguments)
if($action.IndexOf($runnerPath,[StringComparison]::OrdinalIgnoreCase)-lt0){throw 'C2R exact processor task action does not reference the approved runner.'}
$processesBefore=@(Read-ProcessorProcesses 'before');if($processesBefore.Count-gt1){throw "C2R exact processor process is ambiguous before activation: $($processesBefore.Count)."}
$oldPid=if($processesBefore.Count-eq1){[int]$processesBefore[0].processId}else{$null}
$oldCreation=if($processesBefore.Count-eq1){([DateTime]$processesBefore[0].creationUtc).ToUniversalTime()}else{[DateTime]::MinValue}
$restartPerformed=($processesBefore.Count-ne1-or$oldCreation-lt$dRootBoundary-or$oldCreation-lt$runnerLastWriteUtc-or[int]$beforeState.staleMatchedInsiteRows-gt0-or[int]$beforeState.notReadyMatchedRows-gt0)
$restartUtc=$null
if($restartPerformed){
    $restartUtc=[DateTime]::UtcNow
    if($isRehearsal){if([bool](Get-Optional $fixture 'failAfterAuthorization' $false)){throw 'INJECTED_C2R_RUNTIME_FAILURE'}}
    else{
        $task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        if([string]$task.State-eq'Running'){Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop}
        $deadline=(Get-Date).AddSeconds(30);do{Start-Sleep -Milliseconds 250;$remaining=@(Read-ProcessorProcesses 'after')}while($remaining.Count-ne0-and(Get-Date)-lt$deadline)
        if($remaining.Count-gt1){throw 'C2R exact process became ambiguous after task stop.'}
        if($remaining.Count-eq1){Stop-Process -Id ([int]$remaining[0].processId) -Force -ErrorAction Stop}
        $deadline=(Get-Date).AddSeconds(30);do{Start-Sleep -Milliseconds 250;$remaining=@(Read-ProcessorProcesses 'after')}while($remaining.Count-ne0-and(Get-Date)-lt$deadline)
        if($remaining.Count-ne0){throw 'C2R exact processor process did not exit.'}
        Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
    }
}

$deadline=(Get-Date).AddSeconds(180);$processesAfter=@();$afterState=$null
do{
    $processesAfter=@(Read-ProcessorProcesses 'after');$afterState=Read-LotState 'after'
    $catalogFresh=if($null-eq$restartUtc){$true}else{([DateTime]$afterState.catalogGeneratedUtc).ToUniversalTime()-ge$restartUtc}
    if($processesAfter.Count-eq1-and$catalogFresh-and[int]$afterState.staleMatchedInsiteRows-eq0-and[int]$afterState.notReadyMatchedRows-eq0){break}
    if($isRehearsal){break};Start-Sleep -Milliseconds 500
}while((Get-Date)-lt$deadline)
if($processesAfter.Count-ne1){throw "C2R expected one exact processor process after activation; found $($processesAfter.Count)."}
$newPid=[int]$processesAfter[0].processId;$newCreation=([DateTime]$processesAfter[0].creationUtc).ToUniversalTime()
if($newPid-le0-or$newCreation-lt$dRootBoundary-or$newCreation-lt$runnerLastWriteUtc-or($restartPerformed-and$null-ne$oldPid-and$newPid-eq$oldPid)){throw 'C2R processor process is not fresh for the active D-root and installed-runner revision boundaries.'}
if([int]$afterState.confirmedPhysical-ne10-or[int]$afterState.overlayPhysicalMatches-ne10-or[int]$afterState.metadataMatchedCatalogRows-ne20-or[int]$afterState.staleMatchedInsiteRows-ne0-or[int]$afterState.scribeHoldRows-ne0-or[int]$afterState.notReadyMatchedRows-ne0){throw 'R8 downstream catalog did not admit all ten confirmed FRONT wafers.'}
$tasksAfter=@(Read-Tasks 'after');Compare-ProtectedTasks -Before $tasksBefore -After $tasksAfter

[ordered]@{
    schema='argos_r8_processor_runner_fix_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JBOD_PROCESSOR_RUNNER_FIX_AND_REFRESH_R8';rehearsal=$isRehearsal
    taskName=$taskName;taskPrincipal=[string]$targetBefore[0].principal;taskDefinitionSha256=[string]$targetBefore[0].definitionSha256
    dRootBoundaryUtc=$dRootBoundary.ToString('o');runnerLastWriteUtc=$runnerLastWriteUtc.ToString('o');inventoryLastWriteUtc=$inventoryLastWriteUtc.ToString('o');restartStartedUtc=if($null-eq$restartUtc){''}else{$restartUtc.ToString('o')};processorTaskRestarted=$restartPerformed;restartSkippedFresh=(-not$restartPerformed)
    oldProcessId=$oldPid;oldProcessCreationUtc=if($oldCreation-eq[DateTime]::MinValue){''}else{$oldCreation.ToString('o')};newProcessId=$newPid;newProcessCreationUtc=$newCreation.ToString('o');exactProcessCountAfter=$processesAfter.Count
    runnerBeforeSha256=$runnerBeforeSha;runnerSha256=$expectedRunner;runnerChanged=$runnerChanged;runnerEvidenceRoot=$runnerEvidence;runnerPriorArchive=$runnerPrior;inventorySha256=$expectedInventory;importerSha256=$expectedImporter;configSha256=$expectedConfig;metadataSnapshotRoot=[string]$config.metadataSnapshotRoot
    lot=$lot;scan=$scan;currentQueueRows=[int]$afterState.queueRows;confirmedPhysicalAcquisitions=[int]$afterState.confirmedPhysical;overlayPhysicalMatches=[int]$afterState.overlayPhysicalMatches;metadataMatchedCatalogRows=[int]$afterState.metadataMatchedCatalogRows
    catalogGeneratedUtc=[string]$afterState.catalogGeneratedUtc;staleMatchedInsiteRowsBefore=[int]$beforeState.staleMatchedInsiteRows;staleMatchedInsiteRowsAfter=[int]$afterState.staleMatchedInsiteRows;notReadyMatchedRowsBefore=[int]$beforeState.notReadyMatchedRows;notReadyMatchedRowsAfter=[int]$afterState.notReadyMatchedRows;scribeHoldRowsAfter=[int]$afterState.scribeHoldRows;routeStatesAfter=@($afterState.routeStates)
    protectedTaskCount=$tasksBefore.Count;protectedTaskDefinitionsChanged=$false;protectedTaskPrincipalsChanged=$false;otherInspectionTasksChanged=$false
    requestOrResponseDeleted=$false;waferAborted=$false;reviewOnly=$true;xmlExportEnabled=$false;productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 10
