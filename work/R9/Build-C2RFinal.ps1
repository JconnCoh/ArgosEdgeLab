[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R9'
$requestId='REQ_R9'
$sourceRoot=Join-Path $root 'signed_short\REQ_R9.ready'
$finalRoot=Join-Path $root 'final'
$partialRoot='C:\R9Z'
$zipName='REQ_R9.ready.zip'
$manifestSha='3174326BBA1813189BA2F6E4662B6DD95DDE7F68F8408FCEA91C47649E8A3FF6'
$targetSha='46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
$entrySha='1B9E1687C6B70CBB7D128C992157D9FB528292DDD25DEE0EAFD3BDCEDC2B5074'
$endpointPath=Join-Path $root 'C2R_EXACT_ENDPOINT_GATE.json'
$routePath=Join-Path $root 'R9_COMPLETE_ROUTE_GATE.json'
$priorPath=Join-Path $project 'work\R8\R8_TERMINAL_RESPONSE_GATE.json'
$requestVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$public=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$endpointTest=Join-Path $root 'Test-C2RExactEndpoint.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$wrapper=Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$finalTestRoot='C:\R9F1'
$finalEndpointPath=Join-Path $root 'R9_FINAL_EXACT_ENDPOINT_GATE.json'
$finalInvocationPath=Join-Path $root 'R9_FINAL_ENDPOINT_INVOCATION.json'

foreach($path in @($sourceRoot,$endpointPath,$routePath,$priorPath,$requestVerifier,$public,$endpointTest,$pathTool,$wrapper)){if(-not(Test-Path -LiteralPath $path)){throw "R9 final prerequisite missing: $path"}}
foreach($path in @($finalRoot,$partialRoot,$finalTestRoot,$finalEndpointPath,$finalInvocationPath)){if(Test-Path -LiteralPath $path){throw "Fresh C2R final path required: $path"}}
function Read-Gate([string]$Path,[string]$State){$value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json;if([string]$value.state-ne$State){throw "C2R gate state changed: $Path"};return $value}
$endpoint=Read-Gate $endpointPath 'PASS_R9_EXACT_ENDPOINT_GATE'
$route=Read-Gate $routePath 'PASS_R9_COMPLETE_ROUTE_GATE'
$prior=Read-Gate $priorPath 'FAIL_R8_SIGNED_TERMINAL_RESPONSE'
if(-not[bool]$endpoint.approvedOldPredecessorExercised-or-not[bool]$endpoint.targetIdempotenceAccepted-or-not[bool]$endpoint.unapprovedPredecessorRefusedBeforeMutation-or-not[bool]$endpoint.runtimeVerifierFailureRolledBack-or-not[bool]$endpoint.controlAfterRuntimeFailurePassed-or[int]$endpoint.responseSignaturesVerified-ne5){throw 'R9 endpoint contract changed.'}
if([int]$route.maximumPlannedEffectiveLength-ge200-or[int]$route.maximumPlannedComponentLength-gt80-or[string]$route.laptopResponseExtractionRoot-ne'C:\R9S'-or-not[bool]$route.laptopResponseRootFreshAtFreeze){throw 'R9 route contract changed.'}
if(-not[bool]$prior.signatureVerified-or[string]$prior.responseId-ne'R_0FE56F0676DA_20260821163245034_fbc68fa1'-or[string]$prior.responseState-ne'FAILED'-or[string]$prior.failureState-ne'FAILED'){throw 'R9 prior signed terminal prerequisite changed.'}

$scriptRows=New-Object Collections.Generic.List[object]
foreach($relative in @('New-C2RRequest.ps1','Test-C2RExactEndpoint.ps1','Test-C2RRoutes.ps1','Build-C2RFinal.ps1','pkg\payload\C2R.ps1','pkg\payload\Run-JbodAllWaferProcessor.ps1')){
    $script=Join-Path $root $relative
    if(-not(Test-Path -LiteralPath $script -PathType Leaf)){throw "C2R script missing: $relative"}
    &$wrapper -PowerShellScript $script -AsJson|Out-Null
    $tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseFile($script,[ref]$tokens,[ref]$errors)|Out-Null
    if(@($errors).Count-ne0){throw "C2R parser failed: $relative"}
    $scriptRows.Add([pscustomobject]@{file=('work/R9/'+$relative.Replace('\','/'));sha256=(Get-FileHash -LiteralPath $script -Algorithm SHA256).Hash})
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $requestVerifier -PackagePath $sourceRoot -SignerCertificatePath $public -ExpectedTargetRole JBOD|Out-Null
if($LASTEXITCODE-ne0){throw 'C2R signed request verification failed.'}
$manifestPath=Join-Path $sourceRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath=Join-Path $sourceRoot 'PORTAL_REQUEST_MANIFEST.sig'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
if((Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash-ne$manifestSha-or[string]$manifest.requestId-ne$requestId-or@($manifest.files).Count-ne2-or@($manifest.changes).Count-ne2-or@($manifest.allowedTaskActions).Count-ne1-or[string]$manifest.allowedTaskActions[0]-ne'RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'){throw 'R9 signed manifest contract changed.'}
if((Get-FileHash -LiteralPath (Join-Path $sourceRoot 'payload\C2R.ps1') -Algorithm SHA256).Hash-ne$entrySha-or(Get-FileHash -LiteralPath (Join-Path $sourceRoot 'payload\Run-JbodAllWaferProcessor.ps1') -Algorithm SHA256).Hash-ne$targetSha){throw 'R9 signed payload changed.'}

$planned=@((Join-Path $partialRoot $zipName),(Join-Path $partialRoot ($zipName+'.gate.json')),(Join-Path $partialRoot 'extract\REQ_R9.ready\PORTAL_REQUEST_MANIFEST.json'),(Join-Path $partialRoot 'extract\REQ_R9.ready\payload\C2R.ps1'),(Join-Path $partialRoot 'extract\REQ_R9.ready\payload\Run-JbodAllWaferProcessor.ps1'),(Join-Path $finalRoot $zipName),(Join-Path $finalRoot ($zipName+'.gate.json')),$finalInvocationPath,$finalEndpointPath,(Join-Path $finalTestRoot 'control_after_failure\responses\R_0123456789AB_20260820050505050_a1b2c3d4.ready\PORTAL_RESPONSE_MANIFEST.json'))
$pathGate=&$pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'C2R final path gate failed.'}
if($Preflight){
    [ordered]@{schema='argos_r9_final_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9_FINAL_PACKAGE_PREFLIGHT';requestId=$requestId;manifestSha256=$manifestSha;targetSha256=$targetSha;entryPointSha256=$entrySha;priorTerminalResponseId=[string]$prior.responseId;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
    return
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialRoot)
$zip=Join-Path $partialRoot $zipName
$extract=Join-Path $partialRoot 'extract\REQ_R9.ready'
[IO.Compression.ZipFile]::CreateFromDirectory($sourceRoot,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$expectedMembers=@('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload\C2R.ps1','payload\Run-JbodAllWaferProcessor.ps1')
foreach($relative in $expectedMembers){if(-not(Test-Path -LiteralPath (Join-Path $extract $relative) -PathType Leaf)){throw "C2R ZIP member missing: $relative"}}
if(@(Get-ChildItem -LiteralPath $extract -File -Recurse).Count-ne4){throw 'R9 ZIP member count changed.'}
if((Get-FileHash -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Algorithm SHA256).Hash-ne$manifestSha-or(Get-FileHash -LiteralPath (Join-Path $extract 'payload\C2R.ps1') -Algorithm SHA256).Hash-ne$entrySha-or(Get-FileHash -LiteralPath (Join-Path $extract 'payload\Run-JbodAllWaferProcessor.ps1') -Algorithm SHA256).Hash-ne$targetSha){throw 'R9 ZIP content changed.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $requestVerifier -PackagePath $extract -SignerCertificatePath $public -ExpectedTargetRole JBOD|Out-Null
if($LASTEXITCODE-ne0){throw 'C2R extracted request signature failed.'}
$invocation=[ordered]@{schema='argos_r9_endpoint_test_invocation_v1';requestRoot=$extract;testRoot=$finalTestRoot;gatePath=$finalEndpointPath}
[IO.File]::WriteAllText($finalInvocationPath,(($invocation|ConvertTo-Json -Depth 5)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $endpointTest -Rehearsal -InvocationManifest $finalInvocationPath
if($LASTEXITCODE-ne0){throw 'C2R extracted exact endpoint rehearsal failed.'}
$finalEndpoint=Read-Gate $finalEndpointPath 'PASS_R9_EXACT_ENDPOINT_GATE'
if([string]$finalEndpoint.requestManifestSha256-ne$manifestSha-or[int]$finalEndpoint.responseSignaturesVerified-ne5-or-not[bool]$finalEndpoint.controlAfterRuntimeFailurePassed){throw 'C2R final endpoint contract changed.'}

$zipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
$zipBytes=[int64](Get-Item -LiteralPath $zip).Length
$gate=[ordered]@{
    schema='argos_r9_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9_FINAL_PACKAGE_GATE';requestId=$requestId
    requestZip='work/R9/final/REQ_R9.ready.zip';requestZipBytes=$zipBytes;requestZipSha256=$zipHash
    requestManifestSha256=$manifestSha;requestSignatureSha256=(Get-FileHash -LiteralPath $signaturePath -Algorithm SHA256).Hash
    entryPointSha256=$entrySha;targetSha256=$targetSha;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true
    legacyBehaviorHarnessUsed=$false;preFinalEndpointGateSha256=(Get-FileHash -LiteralPath $endpointPath -Algorithm SHA256).Hash;finalExtractedEndpointGateSha256=(Get-FileHash -LiteralPath $finalEndpointPath -Algorithm SHA256).Hash
    scriptRows=$scriptRows.ToArray();approvedOldPredecessorExercised=$true;targetIdempotenceAccepted=$true;unapprovedPredecessorRefusedBeforeMutation=$true;runtimeVerifierFailureRolledBack=$true;controlAfterRuntimeFailurePassed=$true;responseSignaturesVerified=5
    completeRouteGateSha256=(Get-FileHash -LiteralPath $routePath -Algorithm SHA256).Hash;completeRoutePathCount=[int]$route.routePathRowsEvaluated;maximumRouteEffectiveLength=[int]$route.maximumPlannedEffectiveLength;maximumRouteComponentLength=[int]$route.maximumPlannedComponentLength;reservedSuffixCharacters=[int]$route.reservedSuffixCharacters
    installedRouteRootSetSha256=[string]$route.installedRouteRootSetSha256;transportRevisionSha256=[string]$route.transportRevisionSha256;exactEndpointWorkerSha256=[string]$route.exactEndpointWorkerSha256;laptopResponseExtractionRoot=[string]$route.laptopResponseExtractionRoot
    priorTerminalResponseId=[string]$prior.responseId;allowedTaskActions=@('RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2');sourceDeletionPerformed=$false;otherInspectionTasksChanged=$false;waferAborted=$false;reviewOnly=$true;productionRoutingEnabled=$false;publicationAuthorized=$true
}
[IO.File]::WriteAllText((Join-Path $partialRoot ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $partialRoot -Destination $finalRoot
$gate|ConvertTo-Json -Depth 12
