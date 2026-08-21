[CmdletBinding()]
param([switch]$Preflight,[switch]$Rehearsal,[string]$InvocationManifest='')

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Rehearsal)){throw 'Specify exactly one of -Preflight or -Rehearsal.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R10'
$requestId='REQ_R10'
$requestRoot=Join-Path $root 'signed_short\REQ_R10.ready'
$testRoot='C:\R10E1'
$installedRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$helperDestination=Join-Path $installedRoot 'R10.ps1'
$runnerDestination=Join-Path $installedRoot 'Run-JbodAllWaferProcessor.ps1'
$target=Join-Path $requestRoot 'payload\C2R.ps1'
$targetSha='A0E48FB4CFE30FDF9C7B7F83924309CAEA43AB25C9542DAD5E940D92B933F747'
$runnerTarget=Join-Path $requestRoot 'payload\Run-JbodAllWaferProcessor.ps1'
$runnerTargetSha='46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
$runnerOldSha='6B61A415DF2F6852C290ABD0F794E86BE13B270A91E9E86E005B76A468404F1C'
$manifestSha='898D5E18B0532F01448CFDBDA0D8E26F43D7D98FE689A84D56A2FC2C9E991E22'
$worker=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\pkg\payload\W.ps1'
$workerSha='244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6'
$requestVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$responseVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$public=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$gatePath=Join-Path $root 'R10_EXACT_ENDPOINT_GATE.json'
$sourceConfig=Join-Path $project 'work\JBOD_LOT_VALIDATE_C2V3\pkg\payload\PROCESSOR_CONFIG.json'
$sourceRunner=Join-Path $project 'work\JBOD_METADATA_ROOT_CONSUMERS_C1D2\pkg\payload\Run-JbodAllWaferProcessor.ps1'
$sourceInventory=Join-Path $project 'work\JBOD_METADATA_ROOT_CONSUMERS_C1D2\pkg\payload\Invoke-JbodAllWaferInventory.ps1'
$sourceImporter=Join-Path $project 'work\JBOD_INSITE_HOLD_ATTEMPT_FIX_C2H\pkg\payload\Import-JbodLiveInsiteSnapshot.ps1'
$validatorPath=Join-Path $project 'work\V40\C2V40_TERMINAL_RESPONSE_GATE.json'
$validatorSha='F3EE67B7C900A8BE3E83A03020C6BE5E8BB0C6C5D6B1F332044892631A2D813E'

if($Rehearsal-and-not[string]::IsNullOrWhiteSpace($InvocationManifest)){
    $invocation=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
    if([string]$invocation.schema-ne'argos_r10_endpoint_test_invocation_v1'){throw 'R10 endpoint-test invocation schema changed.'}
    $requestRoot=[IO.Path]::GetFullPath([string]$invocation.requestRoot)
    $testRoot=[IO.Path]::GetFullPath([string]$invocation.testRoot)
    $target=Join-Path $requestRoot 'payload\C2R.ps1'
    $runnerTarget=Join-Path $requestRoot 'payload\Run-JbodAllWaferProcessor.ps1'
    $gatePath=[IO.Path]::GetFullPath([string]$invocation.gatePath)
}

foreach($path in @($requestRoot,$target,$runnerTarget,$worker,$requestVerifier,$responseVerifier,$public,$identityPath,$sourceConfig,$sourceRunner,$sourceInventory,$sourceImporter,$validatorPath)){
    if(-not(Test-Path -LiteralPath $path)){throw "R10 endpoint prerequisite missing: $path"}
}
if(
    (Get-FileHash -Algorithm SHA256 -LiteralPath $target).Hash-ne$targetSha-or
    (Get-FileHash -Algorithm SHA256 -LiteralPath $runnerTarget).Hash-ne$runnerTargetSha-or
    (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $requestRoot 'PORTAL_REQUEST_MANIFEST.json')).Hash-ne$manifestSha-or
    (Get-FileHash -Algorithm SHA256 -LiteralPath $worker).Hash-ne$workerSha-or
    (Get-FileHash -Algorithm SHA256 -LiteralPath $validatorPath).Hash-ne$validatorSha
){throw 'R10 endpoint pinned input changed.'}

$validator=Get-Content -LiteralPath $validatorPath -Raw|ConvertFrom-Json
$expectedSlots=@(1..10|ForEach-Object{'Slot{0:D2}'-f$_})
$slotDelta=@(Compare-Object -ReferenceObject $expectedSlots -DifferenceObject @($validator.frontSlots))
$validatorRoutes=@($validator.frontRows|Group-Object routeState)
$validatorAppearance=@($validatorRoutes|Where-Object{$_.Name-eq'HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED'})
$validatorScribe=@($validatorRoutes|Where-Object{$_.Name-eq'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'})
if(
    [string]$validator.state-ne'PASS_C2V40_SIGNED_TERMINAL_RESPONSE'-or
    [int]$validator.frontCatalogRows-ne10-or[int]$validator.distinctFrontPhysicalIdentities-ne10-or
    $slotDelta.Count-ne0-or@($validator.targetConfirmedRows).Count-ne10-or@($validator.targetVerifiedRows).Count-ne10-or
    @($validator.targetActiveHolds).Count-ne0-or@($validator.targetLedgerRows).Count-ne0-or
    $validatorRoutes.Count-ne2-or$validatorAppearance.Count-ne1-or$validatorAppearance[0].Count-ne7-or
    $validatorScribe.Count-ne1-or$validatorScribe[0].Count-ne3-or[bool]$validator.guiAcceptance
){throw 'R10 signed V40 validator contract changed.'}
if(Test-Path -LiteralPath $testRoot){throw "Fresh R10 endpoint root required: $testRoot"}
if($Preflight){
    [ordered]@{
        schema='argos_r10_endpoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_EXACT_ENDPOINT_PREFLIGHT'
        requestId=$requestId;requestManifestSha256=$manifestSha;entryPointSha256=$targetSha;endpointWorkerSha256=$workerSha
        signedValidatorSha256=$validatorSha;signedFrontCatalogRows=10;signedDistinctFrontPhysicalIdentities=10
        selector=@{lot='62631-586';scanDatePrefix='2026-08-19';domain='FRONTSIDE'}
        declaredTaskAction='RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2';requiredSignedCases=10
        rawCatalogFixtureRequired=$true;scalarLotStateFixtureForbidden=$true;allowCreate=$true;approvedTargetIdempotence=$true
        mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }|ConvertTo-Json -Depth 8
    return
}

$utf8=New-Object Text.UTF8Encoding($false)
$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
function Write-Json([string]$Path,[object]$Value){
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 30)+[Environment]::NewLine),$utf8)
}
function Get-TextSha([string]$Text){
    $bytes=$utf8.GetBytes($Text);$sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}finally{$sha.Dispose()}
}
function New-QueueDocument{
    $rows=@(1..10|ForEach-Object{
        [pscustomobject]@{physicalIdentity=('62631-586_20260819173317_Slot{0:D2}'-f$_);state='SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING'}
    })
    return [pscustomobject]@{schema='argos_jbod_scribe_identity_queue_v1';rows=$rows}
}
function New-OverlayDocument{
    $rows=@(1..10|ForEach-Object{
        [pscustomobject]@{acquisitionKey=('62631-586_20260819173317_Slot{0:D2}'-f$_);scribe=('R10{0:D2}'-f$_)}
    })
    return [pscustomobject]@{schema='argos_verified_scribe_mes_metadata_overlay_v1';reviewOnly=$true;xmlEligible=$false;productionEligible=$false;rows=$rows}
}
function New-CatalogDocument([string]$Variant,[bool]$Ready){
    $rows=New-Object Collections.Generic.List[object]
    foreach($slotNumber in 1..10){
        $slot='Slot{0:D2}'-f$slotNumber
        $physical='62631-586_20260819173317_'+$slot
        $route=if($Ready){'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING'}elseif($slotNumber-le3){'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'}else{'HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED'}
        $rows.Add([pscustomobject]@{identity=$physical+'__FRONTSIDE';physicalIdentity=$physical;lot='62631-586';scanTimestampLocal='2026-08-19T17:33:17';slot=$slot;domain='FRONTSIDE';routeState=$route})
        $rows.Add([pscustomobject]@{identity=$physical+'__BACKSIDE';physicalIdentity=$physical;lot='62631-586';scanTimestampLocal='2026-08-19T17:33:17';slot=$slot;domain='BACKSIDE';routeState='HOLD_BACKSIDE_REVIEW_ONLY'})
    }
    if($Variant-eq'missing_front'){
        $kept=@($rows|Where-Object{[string]$_.identity-ne'62631-586_20260819173317_Slot10__FRONTSIDE'})
        $rows=New-Object Collections.Generic.List[object]
        foreach($row in $kept){$rows.Add($row)}
    }elseif($Variant-eq'duplicate_front'){
        $original=@($rows|Where-Object{[string]$_.identity-eq'62631-586_20260819173317_Slot01__FRONTSIDE'})
        if($original.Count-ne1){throw 'R10 duplicate fixture source changed.'}
        $rows.Add([pscustomobject]@{identity='62631-586_20260819173317_Slot01__FRONTSIDE_DUPLICATE';physicalIdentity=[string]$original[0].physicalIdentity;lot='62631-586';scanTimestampLocal='2026-08-19T17:33:17';slot='Slot01';domain='FRONTSIDE';routeState=[string]$original[0].routeState})
    }elseif($Variant-eq'wrong_domain'){
        $row=@($rows|Where-Object{[string]$_.identity-eq'62631-586_20260819173317_Slot10__FRONTSIDE'})
        if($row.Count-ne1){throw 'R10 wrong-domain fixture source changed.'}
        $row[0].domain='BACKSIDE';$row[0].identity='62631-586_20260819173317_Slot10__WRONG_DOMAIN'
    }elseif($Variant-ne'valid'){
        throw "R10 unsupported catalog fixture variant: $Variant"
    }
    return [pscustomobject]@{schema='argos_jbod_all_wafer_catalog_v1';generatedUtc=if($Ready){'2099-08-21T16:21:00Z'}else{'2026-08-21T16:20:00Z'};reviewOnly=$true;xmlExportEnabled=$false;acquisitions=$rows.ToArray()}
}
function New-Fixture([string]$Name,[string]$CatalogVariant,[bool]$ProcessPresent,[bool]$Inject){
    $base=Join-Path (Join-Path $testRoot $Name) 'fixture'
    $processor=Join-Path $base 'p'
    [void](New-Item -ItemType Directory -Path (Join-Path $processor 'processor') -Force)
    Copy-Item -LiteralPath $sourceConfig -Destination (Join-Path $processor 'PROCESSOR_CONFIG.json')
    Copy-Item -LiteralPath $sourceRunner -Destination (Join-Path $processor 'Run-JbodAllWaferProcessor.ps1')
    Copy-Item -LiteralPath $sourceInventory -Destination (Join-Path $processor 'Invoke-JbodAllWaferInventory.ps1')
    Copy-Item -LiteralPath $sourceImporter -Destination (Join-Path $processor 'Import-JbodLiveInsiteSnapshot.ps1')
    Write-Json (Join-Path $processor 'processor\PROCESSOR_STATUS.json') ([ordered]@{state='WATCHING';updatedUtc=[DateTime]::UtcNow.ToString('o');currentIdentity='';reviewOnly=$true;xmlExportEnabled=$false})
    $runner=Join-Path $processor 'Run-JbodAllWaferProcessor.ps1'
    $task=[pscustomobject]@{name='ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2';taskPath='\';principal='SYSTEM';state='Running';definitionSha256=('B'*64);actions=@([pscustomobject]@{execute='powershell.exe';arguments=('-File "'+$runner+'" -ConfigPath "'+(Join-Path $processor 'PROCESSOR_CONFIG.json')+'"')})}
    $before=[pscustomobject]@{processId=101;creationUtc='2026-08-20T01:00:00Z';commandLine='processor'}
    $after=[pscustomobject]@{processId=202;creationUtc='2026-08-20T06:00:00Z';commandLine='processor'}
    $beforeProcesses=if($ProcessPresent){@($before)}else{@()}
    $path=Join-Path $base 'INVOCATION.json'
    Write-Json $path ([ordered]@{
        schema='argos_c2r_rehearsal_v1';processorRoot=$processor
        expectedInventorySha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $sourceInventory).Hash
        expectedImporterSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $sourceImporter).Hash
        tasksBefore=@($task);tasksAfter=@($task);processesBefore=@($beforeProcesses);processesAfter=@($after)
        queueBefore=(New-QueueDocument);catalogBefore=(New-CatalogDocument $CatalogVariant $false);overlayBefore=(New-OverlayDocument)
        queueAfter=(New-QueueDocument);catalogAfter=(New-CatalogDocument 'valid' $true);overlayAfter=(New-OverlayDocument)
        failAfterAuthorization=$Inject
    })
    return $path
}
function Set-Destination([string]$Mode){
    if(Test-Path -LiteralPath $helperDestination){Remove-Item -LiteralPath $helperDestination -Force}
    if($Mode-eq'old'){Copy-Item -LiteralPath $sourceRunner -Destination $runnerDestination -Force;return}
    if($Mode-eq'target'){Copy-Item -LiteralPath $target -Destination $helperDestination -Force;Copy-Item -LiteralPath $runnerTarget -Destination $runnerDestination -Force;return}
    if($Mode-eq'bad'){[IO.File]::WriteAllText($runnerDestination,"# UNAPPROVED R10`r`n",$utf8);return}
    throw "R10 unsupported installed-predecessor mode: $Mode"
}
function Invoke-Case([string]$Name,[string]$Mode,[string]$Expected,[string]$CatalogVariant,[bool]$ProcessPresent,[bool]$Inject,[string]$FailurePattern){
    $case=Join-Path $testRoot $Name
    foreach($leaf in @('incoming','processed','responses','state')){[void](New-Item -ItemType Directory -Path (Join-Path $case $leaf) -Force)}
    Set-Destination $Mode
    $helperBefore=if(Test-Path -LiteralPath $helperDestination){(Get-FileHash -Algorithm SHA256 -LiteralPath $helperDestination).Hash}else{''}
    $runnerBefore=(Get-FileHash -Algorithm SHA256 -LiteralPath $runnerDestination).Hash
    Copy-Item -LiteralPath $requestRoot -Destination (Join-Path $case 'incoming') -Recurse
    $config=[ordered]@{
        schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false
        incomingRoot=Join-Path $case 'incoming';processedRoot=Join-Path $case 'processed';responseOutbox=Join-Path $case 'responses';stateRoot=Join-Path $case 'state'
        requestVerifierPath=$requestVerifier;laptopSignerCertificatePath=$public;endpointSignerThumbprint=[string]$identity.thumbprint;endpointSignerStoreLocation='CurrentUser'
        approvedMaintenanceRoots=@($installedRoot);approvedDataRoots=@();status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()};handlers=@()
    }
    $configPath=Join-Path $case 'ENDPOINT_CONFIG.json'
    Write-Json $configPath $config
    $fixturePath=New-Fixture $Name $CatalogVariant $ProcessPresent $Inject
    $prior=$env:ARGOS_C2R_REHEARSAL_MANIFEST
    try{
        $env:ARGOS_C2R_REHEARSAL_MANIFEST=$fixturePath
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $worker -ConfigPath $configPath -Once
        if($LASTEXITCODE-ne0){throw "R10 endpoint process failed: $Name"}
    }finally{$env:ARGOS_C2R_REHEARSAL_MANIFEST=$prior}
    $responses=@(Get-ChildItem -LiteralPath (Join-Path $case 'responses') -Directory -Filter '*.ready')
    if($responses.Count-ne1){throw "R10 response count failed: $Name"}
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $responseVerifier -PackagePath $responses[0].FullName -EndpointCertificatePath $public -ExpectedSourceRole JBOD -ExpectedRequestId $requestId|Out-Null
    if($LASTEXITCODE-ne0){throw "R10 response signature failed: $Name"}
    $response=Get-Content -LiteralPath (Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.json') -Raw|ConvertFrom-Json
    if([string]$response.state-ne$Expected){throw "R10 endpoint state mismatch: $Name / $($response.state)"}
    $helperAfter=if(Test-Path -LiteralPath $helperDestination){(Get-FileHash -Algorithm SHA256 -LiteralPath $helperDestination).Hash}else{''}
    $runnerAfter=(Get-FileHash -Algorithm SHA256 -LiteralPath $runnerDestination).Hash
    $failurePatternVerified=$false
    $failureEvidencePath=''
    $stderrSha=''
    if($Expected-eq'PASS_MAINTENANCE_PATCH'){
        if($helperAfter-ne$targetSha-or$runnerAfter-ne$runnerTargetSha){throw "R10 targets absent: $Name"}
        $stdout=Get-Content -LiteralPath (Join-Path $responses[0].FullName 'MAINTENANCE.stdout.txt') -Raw|ConvertFrom-Json
        $readyRows=@($stdout.routeStatesAfter|Where-Object{[string]$_.state-eq'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING'})
        if(
            [string]$stdout.state-ne'PASS_JBOD_PROCESSOR_RUNNER_FIX_AND_REFRESH_R10'-or
            -not[bool]$stdout.processorTaskRestarted-or[bool]$stdout.restartSkippedFresh-or
            [int]$stdout.oldProcessId-ne101-or[int]$stdout.newProcessId-ne202-or
            [string]$stdout.selectedDomain-ne'FRONTSIDE'-or[int]$stdout.frontCatalogRows-ne10-or
            [int]$stdout.distinctFrontPhysicalIdentities-ne10-or[int]$stdout.sameIdentityNonFrontCompetitorRows-ne10-or
            [int]$stdout.staleMatchedInsiteRowsAfter-ne0-or[int]$stdout.notReadyMatchedRowsAfter-ne0-or
            [int]$stdout.metadataMatchedCatalogRows-ne10-or@($stdout.routeStatesAfter).Count-ne1-or
            $readyRows.Count-ne1-or[int]$readyRows[0].count-ne10
        ){throw "R10 stdout contract failed: $Name"}
    }else{
        if($helperAfter-ne$helperBefore-or$runnerAfter-ne$runnerBefore){throw "R10 failed case mutated a protected destination: $Name"}
        $stderrPath=Join-Path $responses[0].FullName 'MAINTENANCE.stderr.txt'
        $failurePath=Join-Path $responses[0].FullName 'FAILURE.json'
        $failureEvidencePath=if(Test-Path -LiteralPath $stderrPath -PathType Leaf){$stderrPath}elseif(Test-Path -LiteralPath $failurePath -PathType Leaf){$failurePath}else{throw "R10 failed case has no declared failure evidence: $Name"}
        $failureText=Get-Content -LiteralPath $failureEvidencePath -Raw
        $stderrSha=(Get-FileHash -Algorithm SHA256 -LiteralPath $failureEvidencePath).Hash
        $failurePatternVerified=(-not[string]::IsNullOrWhiteSpace($FailurePattern)-and$failureText.IndexOf($FailurePattern,[StringComparison]::OrdinalIgnoreCase)-ge0)
        if(-not$failurePatternVerified){throw "R10 failure signature changed: $Name"}
    }
    return [pscustomobject]@{
        case=$Name;mode=$Mode;catalogVariant=$CatalogVariant;processPresent=$ProcessPresent;injectedFailure=$Inject
        endpointState=[string]$response.state;helperBeforeSha256=$helperBefore;helperAfterSha256=$helperAfter
        runnerBeforeSha256=$runnerBefore;runnerAfterSha256=$runnerAfter;responseId=[string]$response.responseId
        failurePattern=$FailurePattern;failurePatternVerified=$failurePatternVerified;failureEvidenceFile=[IO.Path]::GetFileName($failureEvidencePath);failureEvidenceSha256=$stderrSha;signatureVerified=$true
    }
}

$initialHelper=Test-Path -LiteralPath $helperDestination
$initialRunner=Test-Path -LiteralPath $runnerDestination
$backupRoot=Join-Path $testRoot '_installed_backup'
[void](New-Item -ItemType Directory -Path $backupRoot -Force)
$helperBackup=Join-Path $backupRoot 'helper.ps1'
$runnerBackup=Join-Path $backupRoot 'runner.ps1'
if($initialHelper){Copy-Item -LiteralPath $helperDestination -Destination $helperBackup}
if($initialRunner){Copy-Item -LiteralPath $runnerDestination -Destination $runnerBackup}
$results=New-Object Collections.Generic.List[object]
try{
    $results.Add((Invoke-Case 'approved_old' 'old' 'PASS_MAINTENANCE_PATCH' 'valid' $true $false ''))
    $results.Add((Invoke-Case 'target_idempotent' 'target' 'PASS_MAINTENANCE_PATCH' 'valid' $true $false ''))
    $results.Add((Invoke-Case 'non_front_competitor_control' 'old' 'PASS_MAINTENANCE_PATCH' 'valid' $true $false ''))
    $results.Add((Invoke-Case 'unapproved_predecessor' 'bad' 'FAILED' 'valid' $true $false 'predecessor'))
    $results.Add((Invoke-Case 'missing_front' 'old' 'FAILED' 'missing_front' $true $false 'expected ten current FRONT catalog rows; found 9'))
    $results.Add((Invoke-Case 'duplicate_front' 'old' 'FAILED' 'duplicate_front' $true $false 'expected ten current FRONT catalog rows; found 11'))
    $results.Add((Invoke-Case 'wrong_domain_replacement' 'old' 'FAILED' 'wrong_domain' $true $false 'expected ten current FRONT catalog rows; found 9'))
    $results.Add((Invoke-Case 'absent_process' 'old' 'FAILED' 'valid' $false $false 'declared RESTART requires exactly one existing processor process; found 0'))
    $results.Add((Invoke-Case 'post_swap_runtime_failure_rollback' 'old' 'FAILED' 'valid' $true $true 'INJECTED_R10_RUNTIME_FAILURE'))
    $results.Add((Invoke-Case 'control_after_failure' 'old' 'PASS_MAINTENANCE_PATCH' 'valid' $true $false ''))
    if($results.Count-ne10-or@($results|Where-Object{[bool]$_.signatureVerified}).Count-ne10){throw 'R10 exact signed case count changed.'}
    $gate=[ordered]@{
        schema='argos_r10_exact_endpoint_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_EXACT_ENDPOINT_GATE'
        requestId=$requestId;requestManifestSha256=$manifestSha;entryPointSha256=$targetSha;endpointWorkerSha256=$workerSha
        signedValidatorSha256=$validatorSha;signedValidatorContractVerified=$true
        rawCatalogSelectorExercised=$true;scalarLotStateFixtureUsed=$false;frontPopulationPredicate='lot == 62631-586 AND scanTimestampLocal starts 2026-08-19 AND domain == FRONTSIDE'
        sameIdentityNonFrontCompetitorsExercised=$true;missingFrontRefused=$true;duplicateFrontRefused=$true;wrongDomainReplacementRefused=$true
        approvedOldPredecessorExercised=$true;targetIdempotenceAccepted=$true;unapprovedPredecessorRefusedBeforeMutation=$true
        absentProcessRefused=$true;runtimeVerifierFailureRolledBack=$true;controlAfterRuntimeFailurePassed=$true
        responseSignaturesVerified=$results.Count;results=$results.ToArray();taskFixtureOnly=$true
        sourceDeletionPerformed=$false;otherInspectionTasksChanged=$false;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-Json $gatePath $gate
}finally{
    if($initialHelper){Copy-Item -LiteralPath $helperBackup -Destination $helperDestination -Force}elseif(Test-Path -LiteralPath $helperDestination){Remove-Item -LiteralPath $helperDestination -Force}
    if($initialRunner){Copy-Item -LiteralPath $runnerBackup -Destination $runnerDestination -Force}elseif(Test-Path -LiteralPath $runnerDestination){Remove-Item -LiteralPath $runnerDestination -Force}
    $resolved=Resolve-Path -LiteralPath $testRoot -ErrorAction SilentlyContinue
    if($null-ne$resolved-and[IO.Path]::GetFullPath([string]$resolved.Path)-eq'C:\R10E1'){Remove-Item -LiteralPath $testRoot -Recurse -Force}
}
