[CmdletBinding()]
param([switch]$Preflight,[switch]$Rehearsal,[string]$InvocationManifest)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Rehearsal)){throw 'Specify exactly one of -Preflight or -Rehearsal.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$work=Join-Path $project 'work\R7'
$requestId='REQ_R7_0821_1605_X1'
$requestRoot=Join-Path $work 'signed_short\REQ_R7_0821_1605_X1.ready'
$testRoot='C:\R7E1'
$gatePath=Join-Path $work 'R7_EXACT_ENDPOINT_GATE.json'
$entrySource=Join-Path $work 'pkg\payload\R7.ps1'
$importerSource=Join-Path $project 'work\R4\pkg\payload\Import-JbodLiveInsiteSnapshot.ps1'
$v38Path=Join-Path $project 'work\V38\C2V38_TERMINAL_RESPONSE_GATE.json'
$endpoint=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\pkg\payload\W.ps1'
$requestVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$responseVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$public=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$installRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$entryDestination=Join-Path $installRoot 'hotfixes\R7.ps1'
$entrySha='A6A373457FA0F435BD0D351AE290175A29D50B8EA24F00246C7A5177B2798173'
$importerSha='45965930699A0F0C38098B65E5A153C5DE360103BC9FED345AC5811B6F1FBD0D'
$endpointSha='244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6'
$routeContract='LATEST_QUALIFYING_NUMBERED_SACRIFICIAL_NITRIDE_DEP_ANCHOR_AT_OR_BEFORE_EXACT_SCAN; SELECTED_BLOCK_INSTANCE_FOLLOW_ON_ALLOWED; EAGLE_OR_LV150MM_ONLY_AFTER_SELECTED_BLOCK; RECIPE_FOLDER_NAMES_UNUSED'
$utf8=New-Object Text.UTF8Encoding($false)

if(-not[string]::IsNullOrWhiteSpace($InvocationManifest)){
    $inv=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
    if([string]$inv.schema-ne'argos_r7_endpoint_test_invocation_v1'){throw 'R7 endpoint invocation refused.'}
    $requestRoot=[IO.Path]::GetFullPath([string]$inv.requestRoot)
    $testRoot=[IO.Path]::GetFullPath([string]$inv.testRoot)
    $gatePath=[IO.Path]::GetFullPath([string]$inv.gatePath)
}
foreach($path in @($requestRoot,$entrySource,$importerSource,$v38Path,$endpoint,$requestVerifier,$responseVerifier,$public,$identityPath)){
    if(-not(Test-Path -LiteralPath $path)){throw "R7 endpoint input missing: $path"}
}
if((Get-FileHash -Algorithm SHA256 $entrySource).Hash-ne$entrySha-or
   (Get-FileHash -Algorithm SHA256 $importerSource).Hash-ne$importerSha-or
   (Get-FileHash -Algorithm SHA256 $endpoint).Hash-ne$endpointSha){throw 'R7 endpoint fixture hash changed.'}
foreach($path in @($testRoot,$gatePath)){if(Test-Path -LiteralPath $path){throw "Fresh R7 endpoint path required: $path"}}
& $requestVerifier -PackagePath $requestRoot -SignerCertificatePath $public -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH|Out-Null
$manifestSha=(Get-FileHash -Algorithm SHA256 (Join-Path $requestRoot 'PORTAL_REQUEST_MANIFEST.json')).Hash
if($Preflight){
    [ordered]@{schema='argos_r7_endpoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R7_EXACT_ENDPOINT_PREFLIGHT';requestId=$requestId;requestManifestSha256=$manifestSha;exactEndpointSha256=$endpointSha;releasedImporterSha256=$importerSha;entrypointSha256=$entrySha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
    return
}

function Write-Json([string]$Path,[object]$Value,[int]$Depth=40){
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),$utf8)
}
function Set-Entry([string]$Mode){
    $parent=Split-Path -Parent $entryDestination
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    if($Mode-eq'absent'){if(Test-Path -LiteralPath $entryDestination){Remove-Item -LiteralPath $entryDestination -Force}}
    elseif($Mode-eq'target'){Copy-Item -LiteralPath $entrySource -Destination $entryDestination -Force}
    elseif($Mode-eq'bad'){[IO.File]::WriteAllText($entryDestination,"param()`r`n'bad'`r`n",$utf8)}
    else{throw "R7 entry fixture mode refused: $Mode"}
}
function New-Fixture([string]$Case,[bool]$ForceFailure){
    $state=Join-Path $Case 'state'
    $bridge=Join-Path $Case 'bridge'
    $metadataRoot=Join-Path $Case 'metadata'
    [void](New-Item -ItemType Directory -Path (Join-Path $state 'identity\confirmed') -Force)
    Copy-Item -LiteralPath $importerSource -Destination (Join-Path $state 'Import-JbodLiveInsiteSnapshot.ps1')
    $v38=Get-Content -LiteralPath $v38Path -Raw|ConvertFrom-Json
    if(@($v38.targetConfirmedRows).Count-ne10-or@($v38.processedPayload.targetRecords).Count-ne10){throw 'R7 frozen V38 fixture cardinality changed.'}
    Write-Json (Join-Path $state 'identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json') ([ordered]@{schema='argos_confirmed_scribe_overlay_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='CONFIRMED_REVIEW_ONLY';rows=@($v38.targetConfirmedRows);reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false})
    $configPath=Join-Path $state 'PROCESSOR_CONFIG.json'
    Write-Json $configPath ([ordered]@{schema='argos_jbod_all_wafer_processor_config_v3';stateRoot=$state;metadataSnapshotRoot=$metadataRoot;reviewOnly=$true;xmlExportEnabled=$false;productionEligible=$false})
    $configSha=(Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash
    $records=@($v38.processedPayload.targetRecords|ForEach-Object{[ordered]@{scribe=$_.scribe;queryState=$_.queryState;lineage=$_.lineage;visualState=$_.visualState;backsideRegime=$_.backsideRegime;acquisitionContexts=@($_.acquisitionContext)}})
    $snapshot=[ordered]@{schemaVersion=1;authority='READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT';lookupKey='confirmed 12-character wafer scribe';frontsideScratchTestRouteContract=$routeContract;records=$records}
    $requestSha=('A' * 64)
    $responseId='INSITE_RESP__'+$requestSha.Substring(0,32)
    $responseRoot=Join-Path $bridge ('response_inbox\processed\'+$responseId+'.ready')
    $payload=Join-Path $responseRoot 'INSITE_RESPONSE.json'
    Write-Json $payload $snapshot
    $payloadSha=(Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash
    Write-Json (Join-Path $responseRoot 'INSITE_RESPONSE_MANIFEST.json') ([ordered]@{schema='argos_insite_response_relay_manifest_v1';createdUtc=[DateTime]::UtcNow.ToString('o');requestPackageId=('INSITE_REQ__'+$requestSha.Substring(0,32));requestContentSha256=$requestSha;payloadFile='INSITE_RESPONSE.json';bytes=[int64](Get-Item $payload).Length;sha256=$payloadSha;recordCount=10;imagesIncluded=$false;credentialsIncluded=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false})
    $control=Join-Path $Case 'R7_REHEARSAL.json'
    Write-Json $control ([ordered]@{schema='argos_r7_processed_response_replay_rehearsal_v1';rehearsal=$true;stateRoot=$state;bridgeRoot=$bridge;targetRequestSha=$requestSha;targetResponseId=$responseId;targetPayloadSha=$payloadSha;expectedConfigSha=$configSha;forceFailureBeforeImport=$ForceFailure})
    [pscustomobject]@{state=$state;bridge=$bridge;metadataRoot=$metadataRoot;payload=$payload;payloadSha=$payloadSha;responseId=$responseId;control=$control}
}
function Invoke-Case([string]$Name,[string]$Mode,[bool]$ForceFailure,[string]$ExpectedState,[string]$ExpectedEntryDisposition){
    $case=Join-Path $testRoot $Name
    foreach($relative in @('incoming','processed','responses','endpoint_state')){[void](New-Item -ItemType Directory -Path (Join-Path $case $relative) -Force)}
    $fixture=New-Fixture $case $ForceFailure
    Set-Entry $Mode
    $beforeExists=Test-Path -LiteralPath $entryDestination -PathType Leaf
    $beforeSha=if($beforeExists){(Get-FileHash -LiteralPath $entryDestination -Algorithm SHA256).Hash}else{''}
    Copy-Item -LiteralPath $requestRoot -Destination (Join-Path $case 'incoming') -Recurse
    $identity=Get-Content $identityPath -Raw|ConvertFrom-Json
    $config=[ordered]@{schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false;incomingRoot=Join-Path $case 'incoming';processedRoot=Join-Path $case 'processed';responseOutbox=Join-Path $case 'responses';stateRoot=Join-Path $case 'endpoint_state';requestVerifierPath=$requestVerifier;laptopSignerCertificatePath=$public;endpointSignerThumbprint=[string]$identity.thumbprint;endpointSignerStoreLocation='CurrentUser';approvedMaintenanceRoots=@($installRoot);approvedDataRoots=@();status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()};handlers=@()}
    $configPath=Join-Path $case 'ENDPOINT_CONFIG.json'
    Write-Json $configPath $config
    $old=[Environment]::GetEnvironmentVariable('ARGOS_R7_REHEARSAL_MANIFEST','Process')
    try{
        $env:ARGOS_R7_REHEARSAL_MANIFEST=$fixture.control
        & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $endpoint -ConfigPath $configPath -Once|Out-Null
        if($LASTEXITCODE-ne0){throw "R7 endpoint process failed: $Name"}
    }finally{[Environment]::SetEnvironmentVariable('ARGOS_R7_REHEARSAL_MANIFEST',$old,'Process')}
    $responses=@(Get-ChildItem (Join-Path $case 'responses') -Directory -Filter '*.ready')
    if($responses.Count-ne1){throw "R7 response count failed: $Name"}
    & $responseVerifier -PackagePath $responses[0].FullName -EndpointCertificatePath $public -ExpectedSourceRole JBOD -ExpectedRequestId $requestId|Out-Null
    $response=Get-Content (Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.json') -Raw|ConvertFrom-Json
    $afterExists=Test-Path -LiteralPath $entryDestination -PathType Leaf
    $afterSha=if($afterExists){(Get-FileHash -LiteralPath $entryDestination -Algorithm SHA256).Hash}else{''}
    if([string]$response.state-ne$ExpectedState){throw "R7 endpoint state mismatch: $Name / $($response.state)"}
    if($ExpectedEntryDisposition-eq'target'-and(-not$afterExists-or$afterSha-ne$entrySha)){throw "R7 target entry outcome mismatch: $Name"}
    if($ExpectedEntryDisposition-eq'unchanged'-and($afterExists-ne$beforeExists-or$afterSha-ne$beforeSha)){throw "R7 refused entry changed: $Name"}
    if($ExpectedEntryDisposition-eq'absent'-and$afterExists){throw "R7 failed create was not rolled back: $Name"}
    $overlay=Join-Path $fixture.metadataRoot 'ACTIVE_VERIFIED_METADATA_OVERLAY.json'
    if($ExpectedState-eq'PASS_MAINTENANCE_PATCH'){
        $stdout=Get-Content (Join-Path $responses[0].FullName 'MAINTENANCE.stdout.txt') -Raw|ConvertFrom-Json
        if([string]$stdout.state-ne'PASS_R7_EXACT_PROCESSED_RESPONSE_REIMPORTED'-or-not[bool]$stdout.rehearsal-or[int]$stdout.expectedRouteRows-ne10-or[int]$stdout.verifiedRouteRows-ne10-or-not[bool]$stdout.sourceRetained-or[bool]$stdout.sourceDeletionPerformed-or[bool]$stdout.hardcodedIdentityUsed-or[int]$stdout.taskActionsPerformed-ne0-or-not(Test-Path -LiteralPath $overlay)-or-not(Test-Path -LiteralPath $fixture.payload)-or(Get-FileHash -LiteralPath $fixture.payload -Algorithm SHA256).Hash-ne$fixture.payloadSha){throw "R7 replay result contract failed: $Name"}
    }elseif(Test-Path -LiteralPath $overlay){throw "R7 failure case mutated verified overlay: $Name"}
    [pscustomobject]@{case=$Name;mode=$Mode;endpointState=[string]$response.state;entryExists=$afterExists;entrySha256=$afterSha;responseId=[string]$response.responseId;signatureVerified=$true}
}

[void](New-Item -ItemType Directory -Path $testRoot)
$entryExisted=Test-Path -LiteralPath $entryDestination
$entryBackup=Join-Path $testRoot 'ENTRY_BEFORE.bin'
if($entryExisted){Copy-Item -LiteralPath $entryDestination -Destination $entryBackup}
$results=New-Object Collections.Generic.List[object]
try{
    $results.Add((Invoke-Case 'create' 'absent' $false 'PASS_MAINTENANCE_PATCH' 'target'))
    $results.Add((Invoke-Case 'target_idempotent' 'target' $false 'PASS_MAINTENANCE_PATCH' 'target'))
    $results.Add((Invoke-Case 'unapproved' 'bad' $false 'FAILED' 'unchanged'))
    $results.Add((Invoke-Case 'runtime_failure' 'absent' $true 'FAILED' 'absent'))
    $results.Add((Invoke-Case 'control_after_failure' 'absent' $false 'PASS_MAINTENANCE_PATCH' 'target'))
}finally{
    if($entryExisted){Copy-Item -LiteralPath $entryBackup -Destination $entryDestination -Force}
    elseif(Test-Path -LiteralPath $entryDestination){Remove-Item -LiteralPath $entryDestination -Force}
}
$gate=[ordered]@{schema='argos_r7_exact_endpoint_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R7_EXACT_ENDPOINT_GATE';requestId=$requestId;requestManifestSha256=$manifestSha;exactEndpointSha256=$endpointSha;releasedImporterSha256=$importerSha;entrypointSha256=$entrySha;allowCreateAccepted=$true;targetIdempotenceAccepted=$true;unapprovedPredecessorRefusedBeforeMutation=$true;postInstallFailureRolledBack=$true;controlAfterFailurePassed=$true;exactProcessedResponseReplayPassed=$true;tenV3RouteContextsVerified=$true;preservedSourceRetained=$true;hardcodedIdentityUsed=$false;responseSignaturesVerified=$results.Count;localEntrypointRestored=$true;results=$results.ToArray();reviewOnly=$true;productionRoutingEnabled=$false}
Write-Json $gatePath $gate 12
$gate|ConvertTo-Json -Depth 12
