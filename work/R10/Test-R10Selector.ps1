[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R10'
$testRoot='C:\R10P'
$gatePath=Join-Path $root 'R10_SELECTOR_GATE.json'
$payload=Join-Path $root 'pkg\payload\C2R.ps1'
$targetRunner=Join-Path $root 'pkg\payload\Run-JbodAllWaferProcessor.ps1'
$sourceConfig=Join-Path $project 'work\JBOD_LOT_VALIDATE_C2V3\pkg\payload\PROCESSOR_CONFIG.json'
$sourceRunner=Join-Path $project 'work\JBOD_METADATA_ROOT_CONSUMERS_C1D2\pkg\payload\Run-JbodAllWaferProcessor.ps1'
$sourceInventory=Join-Path $project 'work\JBOD_METADATA_ROOT_CONSUMERS_C1D2\pkg\payload\Invoke-JbodAllWaferInventory.ps1'
$sourceImporter=Join-Path $project 'work\JBOD_INSITE_HOLD_ATTEMPT_FIX_C2H\pkg\payload\Import-JbodLiveInsiteSnapshot.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$payloadSha='A0E48FB4CFE30FDF9C7B7F83924309CAEA43AB25C9542DAD5E940D92B933F747'
$targetRunnerSha='46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
$oldRunnerSha='6B61A415DF2F6852C290ABD0F794E86BE13B270A91E9E86E005B76A468404F1C'
$utf8=New-Object Text.UTF8Encoding($false)

foreach($path in @($payload,$targetRunner,$sourceConfig,$sourceRunner,$sourceInventory,$sourceImporter,$pathTool)){
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "R10 selector prerequisite missing: $path"}
}
if((Get-FileHash -Algorithm SHA256 -LiteralPath $payload).Hash-ne$payloadSha-or(Get-FileHash -Algorithm SHA256 -LiteralPath $targetRunner).Hash-ne$targetRunnerSha-or(Get-FileHash -Algorithm SHA256 -LiteralPath $sourceRunner).Hash-ne$oldRunnerSha){throw 'R10 selector pinned payload or runner changed.'}
$planned=@($testRoot,(Join-Path $testRoot 'wrong_domain_replacement\fixture\p\state\maintenance_runner_fix\R10_20991231T235959999Z\failed.ps1'),$gatePath,($gatePath+'.partial'))
$pathResult=&$pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathResult.state-ne'PASS_PATH_BUDGET'){throw 'R10 selector path budget failed.'}
if(Test-Path -LiteralPath $testRoot){throw "Fresh R10 selector root required: $testRoot"}
if(Test-Path -LiteralPath $gatePath){throw "Fresh R10 selector gate required: $gatePath"}
if($Preflight){
    [ordered]@{schema='argos_r10_selector_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_SELECTOR_PREFLIGHT';entryPointSha256=$payloadSha;caseCount=6;rawCatalogRowsRequired=$true;scalarLotStateForbidden=$true;pathState=[string]$pathResult.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

function Write-Json([string]$Path,[object]$Value){
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 30)+[Environment]::NewLine),$utf8)
}
function New-Queue{
    [pscustomobject]@{schema='argos_jbod_scribe_identity_queue_v1';rows=@(1..10|ForEach-Object{[pscustomobject]@{physicalIdentity=('62631-586_20260819173317_Slot{0:D2}'-f$_);state='SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'}})}
}
function New-Overlay{
    [pscustomobject]@{schema='argos_verified_scribe_mes_metadata_overlay_v1';reviewOnly=$true;xmlEligible=$false;productionEligible=$false;rows=@(1..10|ForEach-Object{[pscustomobject]@{acquisitionKey=('62631-586_20260819173317_Slot{0:D2}'-f$_);scribe=('R10{0:D2}'-f$_)}})}
}
function New-Catalog([string]$Variant,[bool]$Ready){
    $rows=New-Object Collections.Generic.List[object]
    foreach($number in 1..10){
        $slot='Slot{0:D2}'-f$number;$physical='62631-586_20260819173317_'+$slot
        $route=if($Ready){'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING'}elseif($number-le3){'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'}else{'HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED'}
        $rows.Add([pscustomobject]@{identity=$physical+'__FRONTSIDE';physicalIdentity=$physical;lot='62631-586';scanTimestampLocal='2026-08-19T17:33:17';slot=$slot;domain='FRONTSIDE';routeState=$route})
        $rows.Add([pscustomobject]@{identity=$physical+'__BACKSIDE';physicalIdentity=$physical;lot='62631-586';scanTimestampLocal='2026-08-19T17:33:17';slot=$slot;domain='BACKSIDE';routeState='HOLD_BACKSIDE_REVIEW_ONLY'})
    }
    if($Variant-eq'missing_front'){
        $kept=@($rows|Where-Object{[string]$_.identity-ne'62631-586_20260819173317_Slot10__FRONTSIDE'});$rows=New-Object Collections.Generic.List[object];foreach($row in $kept){$rows.Add($row)}
    }elseif($Variant-eq'duplicate_front'){
        $rows.Add([pscustomobject]@{identity='62631-586_20260819173317_Slot01__FRONTSIDE_DUPLICATE';physicalIdentity='62631-586_20260819173317_Slot01';lot='62631-586';scanTimestampLocal='2026-08-19T17:33:17';slot='Slot01';domain='FRONTSIDE';routeState='HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'})
    }elseif($Variant-eq'wrong_domain'){
        $row=@($rows|Where-Object{[string]$_.identity-eq'62631-586_20260819173317_Slot10__FRONTSIDE'});if($row.Count-ne1){throw 'R10 wrong-domain fixture source changed.'};$row[0].domain='BACKSIDE';$row[0].identity='62631-586_20260819173317_Slot10__WRONG_DOMAIN'
    }elseif($Variant-ne'valid'){throw "R10 selector fixture variant changed: $Variant"}
    [pscustomobject]@{schema='argos_jbod_all_wafer_catalog_v1';generatedUtc=if($Ready){'2099-08-21T16:21:00Z'}else{'2026-08-21T16:20:00Z'};reviewOnly=$true;xmlExportEnabled=$false;acquisitions=$rows.ToArray()}
}
function Invoke-SelectorCase([string]$Name,[string]$Variant,[bool]$ProcessPresent,[bool]$FailAfterSwap,[bool]$ExpectPass,[string]$FailurePattern){
    $case=Join-Path $testRoot $Name;$processor=Join-Path $case 'fixture\p';[void](New-Item -ItemType Directory -Path (Join-Path $processor 'processor') -Force)
    Copy-Item -LiteralPath $sourceConfig -Destination (Join-Path $processor 'PROCESSOR_CONFIG.json')
    Copy-Item -LiteralPath $sourceRunner -Destination (Join-Path $processor 'Run-JbodAllWaferProcessor.ps1')
    Copy-Item -LiteralPath $sourceInventory -Destination (Join-Path $processor 'Invoke-JbodAllWaferInventory.ps1')
    Copy-Item -LiteralPath $sourceImporter -Destination (Join-Path $processor 'Import-JbodLiveInsiteSnapshot.ps1')
    Write-Json (Join-Path $processor 'processor\PROCESSOR_STATUS.json') ([ordered]@{state='WATCHING';currentIdentity='';reviewOnly=$true;xmlExportEnabled=$false})
    $runner=Join-Path $processor 'Run-JbodAllWaferProcessor.ps1';$task=[pscustomobject]@{name='ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2';taskPath='\';principal='SYSTEM';state='Running';definitionSha256=('B'*64);actions=@([pscustomobject]@{execute='powershell.exe';arguments=('-File "'+$runner+'"')})}
    $before=[pscustomobject]@{processId=101;creationUtc='2026-08-20T01:00:00Z';commandLine='processor'};$after=[pscustomobject]@{processId=202;creationUtc='2099-08-21T16:21:00Z';commandLine='processor'}
    $beforeProcesses=if($ProcessPresent){@($before)}else{@()}
    $fixturePath=Join-Path $case 'INVOCATION.json'
    Write-Json $fixturePath ([ordered]@{schema='argos_c2r_rehearsal_v1';processorRoot=$processor;expectedInventorySha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $sourceInventory).Hash;expectedImporterSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $sourceImporter).Hash;tasksBefore=@($task);tasksAfter=@($task);processesBefore=@($beforeProcesses);processesAfter=@($after);queueBefore=(New-Queue);catalogBefore=(New-Catalog $Variant $false);overlayBefore=(New-Overlay);queueAfter=(New-Queue);catalogAfter=(New-Catalog 'valid' $true);overlayAfter=(New-Overlay);failAfterSwap=$FailAfterSwap;failAfterAuthorization=$false})
    $priorPreference=$ErrorActionPreference
    try{
        $ErrorActionPreference='Continue'
        $lines=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $payload -Rehearsal -InvocationManifest $fixturePath 2>&1|ForEach-Object{[string]$_})
        $exitCode=$LASTEXITCODE
    }finally{$ErrorActionPreference=$priorPreference}
    $text=$lines-join[Environment]::NewLine
    $runnerAfter=(Get-FileHash -Algorithm SHA256 -LiteralPath $runner).Hash
    if($ExpectPass){
        if($exitCode-ne0){throw "R10 selector positive case failed: $Name / $text"};$value=$text|ConvertFrom-Json
        if([string]$value.state-ne'PASS_JBOD_PROCESSOR_RUNNER_FIX_AND_REFRESH_R10'-or[int]$value.frontCatalogRows-ne10-or[int]$value.distinctFrontPhysicalIdentities-ne10-or[int]$value.sameIdentityNonFrontCompetitorRows-ne10-or[string]$value.selectedDomain-ne'FRONTSIDE'){throw "R10 selector positive contract changed: $Name"}
    }else{
        if($exitCode-eq0-or$text.IndexOf($FailurePattern,[StringComparison]::OrdinalIgnoreCase)-lt0){throw "R10 selector refusal signature changed: $Name / $text"}
        if($FailAfterSwap-and$runnerAfter-ne$oldRunnerSha){throw 'R10 injected internal swap failure did not restore the old runner.'}
    }
    [pscustomobject]@{case=$Name;variant=$Variant;expectedPass=$ExpectPass;exitCode=$exitCode;failurePattern=$FailurePattern;failurePatternVerified=(-not$ExpectPass);runnerAfterSha256=$runnerAfter}
}

$results=New-Object Collections.Generic.List[object]
try{
    $results.Add((Invoke-SelectorCase 'valid_non_front_competitors' 'valid' $true $false $true ''))
    $results.Add((Invoke-SelectorCase 'missing_front' 'missing_front' $true $false $false 'expected ten current FRONT catalog rows; found 9'))
    $results.Add((Invoke-SelectorCase 'duplicate_front' 'duplicate_front' $true $false $false 'expected ten current FRONT catalog rows; found 11'))
    $results.Add((Invoke-SelectorCase 'wrong_domain_replacement' 'wrong_domain' $true $false $false 'expected ten current FRONT catalog rows; found 9'))
    $results.Add((Invoke-SelectorCase 'absent_process' 'valid' $false $false $false 'declared RESTART requires exactly one existing processor process; found 0'))
    $results.Add((Invoke-SelectorCase 'injected_internal_swap_rollback' 'valid' $true $true $false 'INJECTED_R10_FAILURE_AFTER_SWAP'))
    $resultGate=[ordered]@{schema='argos_r10_selector_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_RAW_CATALOG_SELECTOR_GATE';entryPointSha256=$payloadSha;caseCount=$results.Count;rawCatalogRowsExercised=$true;scalarLotStateUsed=$false;sameIdentityNonFrontCompetitorsExcluded=$true;missingFrontRefused=$true;duplicateFrontRefused=$true;wrongDomainReplacementRefused=$true;absentProcessRefused=$true;internalSwapRollbackPassed=$true;results=$results.ToArray();sourceDeletionPerformed=$false;inspectionTasksChanged=$false;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    [IO.File]::WriteAllText(($gatePath+'.partial'),(($resultGate|ConvertTo-Json -Depth 12)+[Environment]::NewLine),$utf8);Move-Item -LiteralPath ($gatePath+'.partial') -Destination $gatePath
    $resultGate|ConvertTo-Json -Depth 12
}finally{
    $resolved=Resolve-Path -LiteralPath $testRoot -ErrorAction SilentlyContinue
    if($null-ne$resolved-and[IO.Path]::GetFullPath([string]$resolved.Path)-eq'C:\R10P'){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
