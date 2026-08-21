[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\R10'
$requestId='REQ_R10'
$sourceRoot=Join-Path $root 'signed_short\REQ_R10.ready'
$finalRoot=Join-Path $root 'final'
$partialRoot='C:\R10Z'
$zipName='REQ_R10.ready.zip'
$manifestSha='898D5E18B0532F01448CFDBDA0D8E26F43D7D98FE689A84D56A2FC2C9E991E22'
$runnerSha='46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
$entrySha='A0E48FB4CFE30FDF9C7B7F83924309CAEA43AB25C9542DAD5E940D92B933F747'
$endpointPath=Join-Path $root 'R10_EXACT_ENDPOINT_GATE.json'
$routePath=Join-Path $root 'R10_COMPLETE_ROUTE_GATE.json'
$sourceTerminalPath=Join-Path $project 'work\JBOD_PROCESSOR_RUNNER_FIX_C2R3\C2R3_TERMINAL_RESPONSE_GATE.json'
$r9TerminalPath=Join-Path $project 'work\R9\R9_TERMINAL_RESPONSE_GATE.json'
$validatorPath=Join-Path $project 'work\V40\C2V40_TERMINAL_RESPONSE_GATE.json'
$sourceTerminalSha='FE8FCD5CAA29F51100263AFCA0D9C868C7252C75F7928CF12837BD9288AF85F2'
$r9TerminalSha='445B1CDA8C28E5E0C8239C913BC6C0B2BBB72B6DEB4637615482B0206F2AE91A'
$validatorSha='F3EE67B7C900A8BE3E83A03020C6BE5E8BB0C6C5D6B1F332044892631A2D813E'
$requestVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$public=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$endpointTest=Join-Path $root 'Test-C2RExactEndpoint.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$wrapper=Join-Path $project 'utilities\Confirm-ArgosPowerShellWrapper.ps1'
$finalTestRoot='C:\R10F1'
$finalEndpointPath=Join-Path $root 'R10_FINAL_EXACT_ENDPOINT_GATE.json'
$finalInvocationPath=Join-Path $root 'R10_FINAL_ENDPOINT_INVOCATION.json'

foreach($path in @($sourceRoot,$endpointPath,$routePath,$sourceTerminalPath,$r9TerminalPath,$validatorPath,$requestVerifier,$public,$endpointTest,$pathTool,$wrapper)){
    if(-not(Test-Path -LiteralPath $path)){throw "R10 final prerequisite missing: $path"}
}
foreach($path in @($finalRoot,$partialRoot,$finalTestRoot,$finalEndpointPath,$finalInvocationPath)){
    if(Test-Path -LiteralPath $path){throw "Fresh R10 final path required: $path"}
}
function Read-Gate([string]$Path,[string]$State){
    $value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json
    if([string]$value.state-ne$State){throw "R10 gate state changed: $Path"}
    return $value
}
$endpoint=Read-Gate $endpointPath 'PASS_R10_EXACT_ENDPOINT_GATE'
$route=Read-Gate $routePath 'PASS_R10_COMPLETE_ROUTE_GATE'
$sourceTerminal=Read-Gate $sourceTerminalPath 'PASS_C2R3_SIGNED_TERMINAL_RESPONSE'
$r9Terminal=Read-Gate $r9TerminalPath 'FAIL_R9_SIGNED_TERMINAL_RESPONSE'
$validator=Read-Gate $validatorPath 'PASS_C2V40_SIGNED_TERMINAL_RESPONSE'
if((Get-FileHash -LiteralPath $sourceTerminalPath -Algorithm SHA256).Hash-ne$sourceTerminalSha-or-not[bool]$sourceTerminal.signatureVerified){throw 'R10 successful source terminal authority changed.'}
if((Get-FileHash -LiteralPath $r9TerminalPath -Algorithm SHA256).Hash-ne$r9TerminalSha-or-not[bool]$r9Terminal.signatureVerified-or[string]$r9Terminal.disposition-ne'WITHDRAWN'){throw 'R10 R9 terminal diagnostic changed.'}
if((Get-FileHash -LiteralPath $validatorPath -Algorithm SHA256).Hash-ne$validatorSha-or[int]$validator.frontCatalogRows-ne10-or[int]$validator.distinctFrontPhysicalIdentities-ne10-or[bool]$validator.guiAcceptance){throw 'R10 signed validator authority changed.'}
if(
    -not[bool]$endpoint.signedValidatorContractVerified-or-not[bool]$endpoint.rawCatalogSelectorExercised-or[bool]$endpoint.scalarLotStateFixtureUsed-or
    -not[bool]$endpoint.sameIdentityNonFrontCompetitorsExercised-or-not[bool]$endpoint.missingFrontRefused-or
    -not[bool]$endpoint.duplicateFrontRefused-or-not[bool]$endpoint.wrongDomainReplacementRefused-or
    -not[bool]$endpoint.approvedOldPredecessorExercised-or-not[bool]$endpoint.targetIdempotenceAccepted-or
    -not[bool]$endpoint.unapprovedPredecessorRefusedBeforeMutation-or-not[bool]$endpoint.absentProcessRefused-or
    -not[bool]$endpoint.runtimeVerifierFailureRolledBack-or-not[bool]$endpoint.controlAfterRuntimeFailurePassed-or
    [int]$endpoint.responseSignaturesVerified-ne10
){throw 'R10 endpoint contract changed.'}
if([int]$route.maximumPlannedEffectiveLength-ge200-or[int]$route.maximumPlannedComponentLength-gt80-or[string]$route.laptopResponseExtractionRoot-ne'C:\R10S'-or-not[bool]$route.laptopResponseRootFreshAtFreeze){throw 'R10 route contract changed.'}

$scriptRows=New-Object Collections.Generic.List[object]
foreach($relative in @('New-C2RRequest.ps1','Test-C2RExactEndpoint.ps1','Test-C2RRoutes.ps1','Build-C2RFinal.ps1','Publish-C2R.ps1','Collect-C2RResponse.ps1','pkg\payload\C2R.ps1','pkg\payload\Run-JbodAllWaferProcessor.ps1')){
    $script=Join-Path $root $relative
    if(-not(Test-Path -LiteralPath $script -PathType Leaf)){throw "R10 script missing: $relative"}
    &$wrapper -PowerShellScript $script -AsJson|Out-Null
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile($script,[ref]$tokens,[ref]$errors)|Out-Null
    if(@($errors).Count-ne0){throw "R10 parser failed: $relative"}
    $scriptRows.Add([pscustomobject]@{file=('work/R10/'+$relative.Replace('\','/'));sha256=(Get-FileHash -LiteralPath $script -Algorithm SHA256).Hash})
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $requestVerifier -PackagePath $sourceRoot -SignerCertificatePath $public -ExpectedTargetRole JBOD|Out-Null
if($LASTEXITCODE-ne0){throw 'R10 signed request verification failed.'}
$manifestPath=Join-Path $sourceRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath=Join-Path $sourceRoot 'PORTAL_REQUEST_MANIFEST.sig'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
if(
    (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash-ne$manifestSha-or
    [string]$manifest.requestId-ne$requestId-or@($manifest.files).Count-ne2-or@($manifest.changes).Count-ne2-or
    @($manifest.allowedTaskActions).Count-ne1-or[string]$manifest.allowedTaskActions[0]-ne'RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'
){throw 'R10 signed manifest contract changed.'}
if(
    (Get-FileHash -LiteralPath (Join-Path $sourceRoot 'payload\C2R.ps1') -Algorithm SHA256).Hash-ne$entrySha-or
    (Get-FileHash -LiteralPath (Join-Path $sourceRoot 'payload\Run-JbodAllWaferProcessor.ps1') -Algorithm SHA256).Hash-ne$runnerSha
){throw 'R10 signed payload changed.'}

$planned=@(
    (Join-Path $partialRoot $zipName),(Join-Path $partialRoot ($zipName+'.gate.json')),
    (Join-Path $partialRoot 'extract\REQ_R10.ready\PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $partialRoot 'extract\REQ_R10.ready\payload\C2R.ps1'),
    (Join-Path $partialRoot 'extract\REQ_R10.ready\payload\Run-JbodAllWaferProcessor.ps1'),
    (Join-Path $finalRoot $zipName),(Join-Path $finalRoot ($zipName+'.gate.json')),
    $finalInvocationPath,$finalEndpointPath,
    (Join-Path $finalTestRoot 'control_after_failure\responses\R_0123456789AB_20260820050505050_a1b2c3d4.ready\PORTAL_RESPONSE_MANIFEST.json')
)
$pathGate=&$pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'R10 final path gate failed.'}
if($Preflight){
    [ordered]@{
        schema='argos_r10_final_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_FINAL_PACKAGE_PREFLIGHT'
        requestId=$requestId;manifestSha256=$manifestSha;runnerSha256=$runnerSha;entryPointSha256=$entrySha
        sourceTerminalResponseId=[string]$sourceTerminal.responseId;r9DiagnosticResponseId=[string]$r9Terminal.responseId
        signedValidatorSha256=$validatorSha;endpointSignedCases=[int]$endpoint.responseSignaturesVerified
        pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }|ConvertTo-Json -Depth 6
    return
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialRoot)
$zip=Join-Path $partialRoot $zipName
$extract=Join-Path $partialRoot 'extract\REQ_R10.ready'
[IO.Compression.ZipFile]::CreateFromDirectory($sourceRoot,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$expectedMembers=@('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload\C2R.ps1','payload\Run-JbodAllWaferProcessor.ps1')
foreach($relative in $expectedMembers){if(-not(Test-Path -LiteralPath (Join-Path $extract $relative) -PathType Leaf)){throw "R10 ZIP member missing: $relative"}}
if(@(Get-ChildItem -LiteralPath $extract -File -Recurse).Count-ne4){throw 'R10 ZIP member count changed.'}
if(
    (Get-FileHash -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Algorithm SHA256).Hash-ne$manifestSha-or
    (Get-FileHash -LiteralPath (Join-Path $extract 'payload\C2R.ps1') -Algorithm SHA256).Hash-ne$entrySha-or
    (Get-FileHash -LiteralPath (Join-Path $extract 'payload\Run-JbodAllWaferProcessor.ps1') -Algorithm SHA256).Hash-ne$runnerSha
){throw 'R10 ZIP content changed.'}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $requestVerifier -PackagePath $extract -SignerCertificatePath $public -ExpectedTargetRole JBOD|Out-Null
if($LASTEXITCODE-ne0){throw 'R10 extracted request signature failed.'}
$invocation=[ordered]@{schema='argos_r10_endpoint_test_invocation_v1';requestRoot=$extract;testRoot=$finalTestRoot;gatePath=$finalEndpointPath}
[IO.File]::WriteAllText($finalInvocationPath,(($invocation|ConvertTo-Json -Depth 5)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $endpointTest -Rehearsal -InvocationManifest $finalInvocationPath
if($LASTEXITCODE-ne0){throw 'R10 extracted exact endpoint rehearsal failed.'}
$finalEndpoint=Read-Gate $finalEndpointPath 'PASS_R10_EXACT_ENDPOINT_GATE'
if([string]$finalEndpoint.requestManifestSha256-ne$manifestSha-or[int]$finalEndpoint.responseSignaturesVerified-ne10-or-not[bool]$finalEndpoint.controlAfterRuntimeFailurePassed-or-not[bool]$finalEndpoint.rawCatalogSelectorExercised){throw 'R10 final endpoint contract changed.'}

$zipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
$zipBytes=[int64](Get-Item -LiteralPath $zip).Length
$gate=[ordered]@{
    schema='argos_r10_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10_FINAL_PACKAGE_GATE';requestId=$requestId
    requestZip='work/R10/final/REQ_R10.ready.zip';requestZipBytes=$zipBytes;requestZipSha256=$zipHash
    requestManifestSha256=$manifestSha;requestSignatureSha256=(Get-FileHash -LiteralPath $signaturePath -Algorithm SHA256).Hash
    entryPointSha256=$entrySha;runnerSha256=$runnerSha;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true
    preFinalEndpointGateSha256=(Get-FileHash -LiteralPath $endpointPath -Algorithm SHA256).Hash
    finalExtractedEndpointGateSha256=(Get-FileHash -LiteralPath $finalEndpointPath -Algorithm SHA256).Hash
    signedValidatorSha256=$validatorSha;rawCatalogSelectorExercised=$true;sameIdentityNonFrontCompetitorsExercised=$true
    missingFrontRefused=$true;duplicateFrontRefused=$true;wrongDomainReplacementRefused=$true;absentProcessRefused=$true
    approvedOldPredecessorExercised=$true;targetIdempotenceAccepted=$true;unapprovedPredecessorRefusedBeforeMutation=$true
    runtimeVerifierFailureRolledBack=$true;controlAfterRuntimeFailurePassed=$true;responseSignaturesVerified=10
    completeRouteGateSha256=(Get-FileHash -LiteralPath $routePath -Algorithm SHA256).Hash
    completeRoutePathCount=[int]$route.routePathRowsEvaluated;maximumRouteEffectiveLength=[int]$route.maximumPlannedEffectiveLength
    maximumRouteComponentLength=[int]$route.maximumPlannedComponentLength;reservedSuffixCharacters=[int]$route.reservedSuffixCharacters
    installedRouteRootSetSha256=[string]$route.installedRouteRootSetSha256;transportRevisionSha256=[string]$route.transportRevisionSha256
    exactEndpointWorkerSha256=[string]$route.exactEndpointWorkerSha256;laptopResponseExtractionRoot=[string]$route.laptopResponseExtractionRoot
    sourceTerminalResponseId=[string]$sourceTerminal.responseId;r9DiagnosticResponseId=[string]$r9Terminal.responseId
    allowedTaskActions=@('RESTART:ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2')
    scriptRows=$scriptRows.ToArray();sourceDeletionPerformed=$false;otherInspectionTasksChanged=$false;waferAborted=$false
    reviewOnly=$true;productionRoutingEnabled=$false;publicationAuthorized=$true
}
[IO.File]::WriteAllText((Join-Path $partialRoot ($zipName+'.gate.json')),(($gate|ConvertTo-Json -Depth 14)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $partialRoot -Destination $finalRoot
$gate|ConvertTo-Json -Depth 14
