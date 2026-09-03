#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Test)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Test)){throw 'Specify exactly one of -Preflight or -Test.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function New-Json([string]$Path,[object]$Value){Require (-not(Test-Path -LiteralPath $Path)) "O3F15L1 create-new JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
function Quote([string]$Value){if($Value-notmatch'[\s"]'){return $Value};return '"'+$Value.Replace('"','\"')+'"'}
function Invoke-Captured([string]$Executable,[string[]]$Arguments,[string]$WorkingDirectory){
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$Executable
    $start.Arguments=(@($Arguments|ForEach-Object{Quote([string]$_)})-join' ')
    $start.WorkingDirectory=$WorkingDirectory
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process
    $process.StartInfo=$start
    Require $process.Start() 'O3F15L1 rehearsal child did not start.'
    $stdout=$process.StandardOutput.ReadToEnd()
    $stderr=$process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{exitCode=[int]$process.ExitCode;stdout=$stdout;stderr=$stderr}
}
function Parse-OneJson([string]$Text,[string]$Label){$lines=@($Text-split'\r?\n'|Where-Object{-not[string]::IsNullOrWhiteSpace($_)});Require ($lines.Count-eq1) "O3F15L1 $Label stdout line count changed.";try{return($lines[0]|ConvertFrom-Json)}catch{throw "O3F15L1 $Label stdout is not JSON: $($_.Exception.Message)"}}
function New-RehearsalInvocation([string]$Path,[string]$Mode,[string]$Python,[string]$PythonHash,[string]$Base){
    New-Json $Path ([ordered]@{schema='argos_ocv03_o3f15l1_rehearsal_invocation_v1';fixtureMode=$Mode;pythonPath=$Python;pythonSha256=$PythonHash;runtimeRoot=(Join-Path $Base 'r');gateRoot=(Join-Path $Base 'g');corpusRoot=(Join-Path $Base 'c');mirrorRoot=(Join-Path $Base 'm')})
}
function New-MaintenanceFixture([string]$TemplateRoot,[string]$RequestRoot,[string]$CaseRequestId,[string]$Destination,[object]$Signer){
    Require (-not(Test-Path -LiteralPath $RequestRoot)) "O3F15L1 installer fixture request exists: $RequestRoot"
    Copy-Item -LiteralPath $TemplateRoot -Destination $RequestRoot -Recurse
    $manifestPath=Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.json'
    $signaturePath=Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.sig'
    $payloadRoot=Join-Path $RequestRoot 'payload'
    $fixtureEntry=Join-Path $payloadRoot 'O3F15MaintenanceValidationFixture.ps1'
    $fixtureText="#Requires -Version 5.1`r`n[ordered]@{state='PASS_O3F15_MAINTENANCE_VALIDATION_ENTRYPOINT';taskActionCount=0;existingProcessActionCount=0;providerActivated=`$false;sourceImageBytesRead=`$false;reviewOnly=`$true;productionRoutingEnabled=`$false}|ConvertTo-Json -Compress`r`n"
    [IO.File]::WriteAllText($fixtureEntry,$fixtureText,(New-Object Text.UTF8Encoding($false)))
    $fixtureManifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    $created=[DateTimeOffset]::UtcNow
    $fixtureManifest.requestId=$CaseRequestId
    $fixtureManifest.createdUtc=$created.ToString('o')
    $fixtureManifest.expiresUtc=$created.AddHours(2).ToString('o')
    $fixtureManifest.entryPoint='payload/O3F15MaintenanceValidationFixture.ps1'
    $fixtureManifest.changes[0].destination=$Destination.Replace('\','/')
    $fixtureManifest.rehearsal.requiredState='PASS_O3F15_MAINTENANCE_VALIDATION_ENTRYPOINT'
    $fixtureManifest.signerThumbprint=([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant()
    $fixtureManifest.entryPointMutations=@()
    $fixtureManifest.entryPointOutputs=@()
    $fixtureManifest.allowedTaskActions=@()
    $fixtureManifest.allowedProcessActions=@()
    $fixtureManifest.files=@(Get-ChildItem -LiteralPath $payloadRoot -File|Sort-Object Name|ForEach-Object{[ordered]@{path=('payload/'+$_.Name);bytes=[int64]$_.Length;sha256=Sha $_.FullName}})
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($fixtureManifest|ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes($manifestPath,$bytes)
    $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Signer)
    try{[IO.File]::WriteAllBytes($signaturePath,$rsa.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))}finally{$rsa.Dispose()}
    [ordered]@{requestId=$CaseRequestId;manifestSha256=Sha $manifestPath;signatureSha256=Sha $signaturePath;payloadFileCount=@($fixtureManifest.files).Count}
}
function Invoke-MaintenanceCase([string]$Name,[string]$TemplateRoot,[string]$CasesRoot,[string]$Carrier,[bool]$Approved,[object]$Signer,[string]$Worker,[string]$RequestVerifier,[string]$ResponseVerifier,[string]$PublicCertificate){
    $caseRoot=Join-Path $CasesRoot $Name
    $installRoot=Join-Path $caseRoot 'install'
    $target=Join-Path $installRoot 'OCV03_NotchReviewOpenCvV1.py'
    foreach($relative in @('incoming','processed','responses','state','install')){[void](New-Item -ItemType Directory -Path (Join-Path $caseRoot $relative))}
    if($Approved){Copy-Item -LiteralPath $Carrier -Destination $target}else{[IO.File]::WriteAllText($target,'O3F15_UNAPPROVED_PREDECESSOR',(New-Object Text.UTF8Encoding($false)))}
    $beforeSha=Sha $target
    $caseRequestId='REQ_O3F15_IR_'+$Name
    $requestRoot=Join-Path (Join-Path $caseRoot 'incoming') ($caseRequestId+'.ready')
    $fixture=New-MaintenanceFixture $TemplateRoot $requestRoot $caseRequestId $target $Signer
    $configPath=Join-Path $caseRoot 'ENDPOINT_CONFIG.json'
    New-Json $configPath ([ordered]@{schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false;incomingRoot=Join-Path $caseRoot 'incoming';processedRoot=Join-Path $caseRoot 'processed';responseOutbox=Join-Path $caseRoot 'responses';stateRoot=Join-Path $caseRoot 'state';requestVerifierPath=$RequestVerifier;laptopSignerCertificatePath=$PublicCertificate;endpointSignerThumbprint=([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant();endpointSignerStoreLocation='CurrentUser';approvedMaintenanceRoots=@($installRoot);approvedDataRoots=@();status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()};handlers=@()})
    & $Worker -ConfigPath $configPath -Once|Out-Null
    $responses=@(Get-ChildItem -LiteralPath (Join-Path $caseRoot 'responses') -Directory -Filter '*.ready')
    Require ($responses.Count-eq1) "O3F15L1 installer fixture response cardinality changed: $Name"
    & $ResponseVerifier -PackagePath $responses[0].FullName -EndpointCertificatePath $PublicCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $caseRequestId|Out-Null
    $response=Get-Content -LiteralPath (Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.json') -Raw|ConvertFrom-Json
    $afterSha=Sha $target
    $installLeaves=@(Get-ChildItem -LiteralPath $installRoot -File)
    Require ($installLeaves.Count-eq1-and$installLeaves[0].FullName-eq$target) "O3F15L1 installer fixture wrote an undeclared install leaf: $Name"
    if($Approved){
        Require ([string]$response.state-eq'PASS_MAINTENANCE_PATCH'-and$afterSha-eq(Sha $Carrier)) "O3F15L1 approved installer case failed: $Name"
        $result=Get-Content -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json') -Raw|ConvertFrom-Json
        Require ([string]$result.state-eq'PASS_MAINTENANCE_PATCH'-and[int]$result.changedFiles-eq1-and[bool]$result.changes[0].predecessorExisted-and[string]$result.changes[0].installedSha256-eq$afterSha) "O3F15L1 maintenance result contract changed: $Name"
    }else{
        Require ([string]$response.state-eq'FAILED'-and([string]$response.detail)-like'*Installed predecessor is not approved*'-and$afterSha-eq$beforeSha-and-not(Test-Path -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json'))) 'O3F15L1 unapproved predecessor was not refused before install mutation.'
    }
    [ordered]@{case=$Name;endpointState=[string]$response.state;requestManifestSha256=[string]$fixture.manifestSha256;signatureVerified=$true;approvedPredecessor=$Approved;beforeSha256=$beforeSha;afterSha256=$afterSha;installLeafCount=$installLeaves.Count;refusedBeforeMutation=(-not$Approved)}
}

Require ([string]$PSVersionTable.PSEdition-eq'Desktop'-and[int]$PSVersionTable.PSVersion.Major-eq5-and[int]$PSVersionTable.PSVersion.Minor-eq1) 'O3F15L1 final-ZIP rehearsal requires exact Windows PowerShell 5.1.'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$signGatePath=Join-Path $PSScriptRoot 'O3F15L1_SIGN_GATE.json'
$certificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$responseVerifier=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$signingIdentityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$python=Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$windowsPowerShell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$fixtureRoot='C:\O3F15L1V1'
$extract=Join-Path $fixtureRoot 'x'
$normalBase=Join-Path $fixtureRoot 'n'
$immediateBase=Join-Path $fixtureRoot 'i'
$normalInvocation=Join-Path $fixtureRoot 'normal.json'
$immediateInvocation=Join-Path $fixtureRoot 'immediate.json'
$gatePath=Join-Path $PSScriptRoot 'O3F15L1_FINAL_ZIP_REHEARSAL_GATE.json'
foreach($path in @($signGatePath,$certificate,$packageTester,$responseVerifier,$signingIdentityPath,$endpointWorker,$queueGate,$python,$windowsPowerShell)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L1 final-ZIP dependency absent: $path"}
$signGate=Get-Content -LiteralPath $signGatePath -Raw|ConvertFrom-Json
Require ([string]$signGate.state-eq'PASS_O3F15L1_SIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE') 'O3F15L1 sign gate changed.'
$requestId=[string]$signGate.requestId
$zip=[string]$signGate.packageZipPath
$zipHash=[string]$signGate.packageZipSha256
Require (Test-Path -LiteralPath $zip -PathType Leaf) 'O3F15L1 signed ZIP absent.'
Require ((Get-Item -LiteralPath $zip).Length-eq[int64]$signGate.packageZipBytes-and(Sha $zip)-eq$zipHash) 'O3F15L1 signed ZIP changed.'
Require ((Sha $python)-eq'7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F15L1 local rehearsal runtime changed.'
Require ((Sha $certificate)-eq'2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'-and(Sha $packageTester)-eq'6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'-and(Sha $responseVerifier)-eq'4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C'-and(Sha $signingIdentityPath)-eq'3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289') 'O3F15L1 signed-package installer rehearsal dependencies changed.'
Require ((Sha $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'-and(Sha $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F15L1 inherited endpoint worker or queue-safety evidence changed.'
foreach($path in @($fixtureRoot,$gatePath)){Require (-not(Test-Path -LiteralPath $path)) "O3F15L1 create-new final-ZIP rehearsal target exists: $path"}
$planned=@((Join-Path $extract 'payload\Invoke-O3F15L1.ps1'),$normalInvocation,$immediateInvocation,(Join-Path $normalBase 'r\Run-O3F15FrontReconcile.py'),(Join-Path $normalBase 'c\PROGRESS.json'),(Join-Path $normalBase 'm\PROGRESS.json'),(Join-Path $immediateBase 'c\PROGRESS.json'),(Join-Path $fixtureRoot 'installer\UNAPPROVED\state\maintenance\REQ_O3F15_IR_UNAPPROVED\failed_new\M000_0123456789_0123456789.rollback'),$gatePath)
$pathGate=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Require ([string]$pathGate.state-eq'PASS_PATH_BUDGET') 'O3F15L1 exact-package path gate failed.'

if($Preflight){[ordered]@{schema='argos_ocv03_o3f15l1_final_zip_rehearsal_preflight_v1';state='PASS_O3F15L1_FINAL_ZIP_REHEARSAL_PREFLIGHT';requestId=$requestId;packageZipSha256=$zipHash;fixtureRoot=$fixtureRoot;pathState=[string]$pathGate.state;endpointWorkerSha256=Sha $endpointWorker;queueSafetyGateSha256=Sha $queueGate;installerCaseCount=3;targetOrJbodAccessed=$false;sourceImageBytesRead=$false;existingProcessesQueried=$false;existingProcessOrTaskActionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
[void](New-Item -ItemType Directory -Path $normalBase)
[void](New-Item -ItemType Directory -Path $immediateBase)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE') 'O3F15L1 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$payload=Join-Path $extract 'payload'
Require ([string]$manifest.requestId-eq$requestId-and@($manifest.files).Count-eq[int]$signGate.payloadFileCount-and@($manifest.changes).Count-eq1-and[string]$manifest.entryPoint-eq'payload/Invoke-O3F15L1.ps1') 'O3F15L1 signed manifest identity changed.'
Require ([bool]$manifest.reviewOnly-and-not[bool]$manifest.trainingEligible-and-not[bool]$manifest.xmlEligible-and-not[bool]$manifest.productionEligible-and-not[bool]$manifest.productionRoutingEnabled-and-not[bool]$manifest.requestRetryAuthorized-and@($manifest.allowedTaskActions).Count-eq0) 'O3F15L1 signed authority widened.'
$expectedOutputs=@('D:/O3F15C/PROGRESS.json','D:/O3F15C/RESULTS.json','D:/O3F15C/SUMMARY.json','D:/O3F15C/HOLDOUT18.json','D:/O3F15C/CURRENT265.json','D:/O3F15C/TERMINAL_FAILURE.json','D:/KLARFExport/_ArgosReview/F15S/PROGRESS.json','D:/KLARFExport/_ArgosReview/F15S/RESULTS.json','D:/KLARFExport/_ArgosReview/F15S/SUMMARY.json','D:/KLARFExport/_ArgosReview/F15S/TERMINAL_FAILURE.json')
$actualOutputs=@($manifest.entryPointOutputs|ForEach-Object{Require (-not[bool]$_.requiredAtLaunch) 'O3F15L1 output was incorrectly declared launch-required.';[string]$_.path})
Require ($actualOutputs.Count-eq$expectedOutputs.Count-and@($actualOutputs|Sort-Object).Count-eq@($expectedOutputs|Sort-Object).Count-and(@(Compare-Object ($actualOutputs|Sort-Object) ($expectedOutputs|Sort-Object)).Count-eq0)) 'O3F15L1 declared result/mirror outputs changed.'
Require (@($manifest.allowedProcessActions).Count-eq2-and[int]$manifest.timeoutContract.bootstrapProgressSeconds-eq600-and[string]$manifest.sourceProcessingContract.terminalFailureSchema-eq'argos_ocv03_o3f15_terminal_failure_v1'-and[string]$manifest.sourceProcessingContract.terminalFailureState-eq'HOLD_O3F15_ARTIFACT_COMMIT_FAILURE') 'O3F15L1 signed terminal-failure/process/timeout contract changed.'
foreach($record in @($manifest.files)){
    $relative=[string]$record.path
    Require (-not[IO.Path]::IsPathRooted($relative)-and$relative-notmatch'(^|[\\/])\.\.([\\/]|$)') 'O3F15L1 signed payload path is unsafe.'
    $file=Join-Path $extract $relative
    Require (Test-Path -LiteralPath $file -PathType Leaf) "O3F15L1 signed payload file absent: $relative"
    Require ((Get-Item -LiteralPath $file).Length-eq[int64]$record.bytes-and(Sha $file)-eq[string]$record.sha256) "O3F15L1 signed payload hash changed: $relative"
}
$change=@($manifest.changes)[0]
$carrier=Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py'
$carrierHash=Sha $carrier
Require ([string]$change.source-eq'payload/OCV03_NotchReviewOpenCvV1.py'-and[string]$change.installedSha256-eq$carrierHash-and@($change.approvedPredecessorSha256).Count-eq1-and@($change.approvedPredecessorSha256)-contains$carrierHash-and-not[bool]$change.allowCreate) 'O3F15L1 signed same-bytes carrier contract changed.'
$identity=Get-Content -LiteralPath $signingIdentityPath -Raw|ConvertFrom-Json
$signer=Get-Item -LiteralPath ('Cert:\CurrentUser\My\'+([string]$identity.thumbprint).Replace(' ','')) -ErrorAction Stop
Require ([bool]$signer.HasPrivateKey) 'O3F15L1 installer-rehearsal signing key is absent.'
$installerRoot=Join-Path $fixtureRoot 'installer'
[void](New-Item -ItemType Directory -Path $installerRoot)
$installerCases=New-Object Collections.Generic.List[object]
$installerCases.Add((Invoke-MaintenanceCase 'APPROVED' $extract $installerRoot $carrier $true $signer $endpointWorker $packageTester $responseVerifier $certificate))
$installerCases.Add((Invoke-MaintenanceCase 'IDEMPOTENT' $extract $installerRoot $carrier $true $signer $endpointWorker $packageTester $responseVerifier $certificate))
$installerCases.Add((Invoke-MaintenanceCase 'UNAPPROVED' $extract $installerRoot $carrier $false $signer $endpointWorker $packageTester $responseVerifier $certificate))
Require ($installerCases.Count-eq3-and@($installerCases|Where-Object{[string]$_.endpointState-eq'PASS_MAINTENANCE_PATCH'}).Count-eq2-and@($installerCases|Where-Object{[bool]$_.refusedBeforeMutation}).Count-eq1) 'O3F15L1 exact maintenance-validation case set changed.'
$endpoint=Join-Path $payload 'Invoke-O3F15L1.ps1'
$contract=Get-Content -LiteralPath (Join-Path $payload 'O3F15_LAUNCH_CONTRACT.json') -Raw|ConvertFrom-Json
Require ([string]$contract.schema-eq'argos_ocv03_o3f15l1_launch_contract_v1'-and[string]$contract.state-eq'FROZEN_FOR_BUILD'-and[int]$contract.expectedPairCount-eq978-and[string]$contract.side-eq'FRONT'-and[string]$contract.expectedTerminalFailureSchema-eq'argos_ocv03_o3f15_terminal_failure_v1'-and[string]$contract.expectedTerminalFailureState-eq'HOLD_O3F15_ARTIFACT_COMMIT_FAILURE') 'O3F15L1 extracted launch contract changed.'
Require ([string]$contract.inheritedRoute.endpointWorkerSha256-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'-and[string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256-eq'465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'-and[string]$contract.inheritedRoute.queueSafetyGateSha256-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'-and-not[bool]$contract.inheritedRoute.routeImplementationChanged) 'O3F15L1 extracted inherited route pins changed.'
$leafProcess=Invoke-Captured $windowsPowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$endpoint,'-PackageLeafPreflight') $payload
$leaf=Parse-OneJson $leafProcess.stdout 'package-leaf preflight'
Require ($leafProcess.exitCode-eq0-and[string]$leaf.state-eq'PASS_O3F15L1_EXACT_PACKAGED_LAUNCH_LEAVES'-and-not[bool]$leaf.mutationsPerformed) 'O3F15L1 exact packaged leaf preflight failed.'
$testProcess=Invoke-Captured $python @('-I','-B',(Join-Path $payload 'Test-O3F15FrontReconcile.py')) $payload
$focused=Parse-OneJson $testProcess.stdout 'focused Python test'
Require ($testProcess.exitCode-eq0-and[string]::IsNullOrWhiteSpace($testProcess.stderr)-and[string]$focused.schema-eq'argos_ocv03_o3f15_front_reconcile_focused_gate_v1'-and[string]$focused.state-eq'PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE') 'O3F15L1 exact packaged isolated Python test failed.'
Require ([bool]$focused.sizeChecks.resultsUnder2MiB-and[bool]$focused.sizeChecks.progressUnder2MiB-and[bool]$focused.sizeChecks.allKnownOutputLeavesPathSafe-and[bool]$focused.sizeChecks.allKnownOutputComponentsSafe-and[bool]$focused.sizeChecks.fullCountNotTerminalBeforeCommit-and[bool]$focused.sizeChecks.terminalOnlyAfterCommit) 'O3F15L1 packaged terminal-commit/path checks changed.'
New-RehearsalInvocation $normalInvocation 'NORMAL' $python (Sha $python) $normalBase
$normalPreflightProcess=Invoke-Captured $windowsPowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$endpoint,'-Preflight','-Rehearsal','-InvocationManifest',$normalInvocation) $payload
$normalPreflight=Parse-OneJson $normalPreflightProcess.stdout 'NORMAL endpoint preflight'
Require ($normalPreflightProcess.exitCode-eq0-and[string]$normalPreflight.schema-eq'argos_ocv03_o3f15l1_rehearsal_preflight_v1'-and[string]$normalPreflight.state-eq'PASS_O3F15L1_REHEARSAL_PREFLIGHT'-and-not[bool]$normalPreflight.processStarted-and-not[bool]$normalPreflight.mutationsPerformed) 'O3F15L1 NORMAL endpoint preflight failed.'
$normalProcess=Invoke-Captured $windowsPowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$endpoint,'-Rehearsal','-InvocationManifest',$normalInvocation) $payload
$normal=Parse-OneJson $normalProcess.stdout 'NORMAL endpoint rehearsal'
Require ($normalProcess.exitCode-eq0-and[string]$normal.schema-eq'argos_ocv03_o3f15l1_rehearsal_launch_v1'-and[string]$normal.state-eq'PASS_O3F15L1_REHEARSAL_WORKER_LAUNCHED'-and[string]$normal.fixtureMode-eq'NORMAL') 'O3F15L1 NORMAL endpoint rehearsal failed.'
Require ([string]$normal.focusedTestState-eq'PASS_O3F15_FRONT_RECONCILE_FOCUSED_GATE'-and[string]$normal.selfTestState-eq'PASS_O3F15_FRONT_RECONCILE_SELF_TEST'-and[string]$normal.preflightState-eq'PASS_O3F15_FRONT_RECONCILE_PREFLIGHT'-and[string]$normal.gateState-eq'COMPLETE_O3F15_GATE'-and[int]$normal.pid-gt0-and-not[string]::IsNullOrWhiteSpace([string]$normal.creationTimeUtc)-and[int]$normal.workerStillRunningAfterSeconds-eq3) 'O3F15L1 NORMAL child identity/stage evidence changed.'
Require ([string]$normal.runtimeRoot-eq(Join-Path $normalBase 'r')-and[string]$normal.gateRoot-eq(Join-Path $normalBase 'g')-and[string]$normal.corpusRoot-eq(Join-Path $normalBase 'c')-and[string]$normal.mirrorRoot-eq(Join-Path $normalBase 'm')) 'O3F15L1 NORMAL rehearsal roots changed.'
Require ([string]$normal.progressPath-eq(Join-Path $normalBase 'c\PROGRESS.json')-and[string]$normal.summaryPath-eq(Join-Path $normalBase 'c\SUMMARY.json')-and[string]$normal.mirrorProgressPath-eq(Join-Path $normalBase 'm\PROGRESS.json')-and[string]$normal.bootstrapProgressState-eq'RUNNING_O3F15_FULL978'-and[int]$normal.bootstrapScheduledCount-eq978) 'O3F15L1 NORMAL bootstrap progress evidence changed.'
Require (-not[bool]$normal.imageBytesRead-and-not[bool]$normal.existingProcessesQueried-and-not[bool]$normal.existingProcessOrTaskActionPerformed-and[bool]$normal.ownedProcessStarted-and[bool]$normal.mutationsPerformed-and[bool]$normal.reviewOnly) 'O3F15L1 NORMAL rehearsal safety evidence changed.'
$collisionProcess=Invoke-Captured $windowsPowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$endpoint,'-Rehearsal','-InvocationManifest',$normalInvocation) $payload
$collision=Parse-OneJson $collisionProcess.stdout 'collision endpoint rehearsal'
Require ($collisionProcess.exitCode-ne0-and[string]$collision.schema-eq'argos_ocv03_o3f15l1_rehearsal_launch_v1'-and[string]$collision.state-eq'HOLD_O3F15L1_REHEARSAL_CREATE_NEW_COLLISION'-and-not[bool]$collision.ownedProcessStarted) 'O3F15L1 create-new collision was not refused before process start.'
New-RehearsalInvocation $immediateInvocation 'IMMEDIATE_EXIT' $python (Sha $python) $immediateBase
$immediateProcess=Invoke-Captured $windowsPowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$endpoint,'-Rehearsal','-InvocationManifest',$immediateInvocation) $payload
$immediate=Parse-OneJson $immediateProcess.stdout 'IMMEDIATE_EXIT endpoint rehearsal'
Require ($immediateProcess.exitCode-ne0-and[string]$immediate.schema-eq'argos_ocv03_o3f15l1_rehearsal_launch_v1'-and[string]$immediate.state-eq'HOLD_O3F15L1_REHEARSAL_WORKER_EXITED_IMMEDIATELY'-and[string]$immediate.fixtureMode-eq'IMMEDIATE_EXIT'-and-not[bool]$immediate.ownedProcessStarted) 'O3F15L1 immediate worker exit was not surfaced as an explicit hold.'
$record=[ordered]@{schema='argos_ocv03_o3f15l1_final_zip_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L1_FINAL_ZIP_WINDOWS_PS51_REHEARSAL';requestId=$requestId;packageZipPath=$zip;packageZipBytes=[int64](Get-Item -LiteralPath $zip).Length;packageZipSha256=$zipHash;windowsPowerShell=@{major=[int]$PSVersionTable.PSVersion.Major;minor=[int]$PSVersionTable.PSVersion.Minor};exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=@($manifest.files).Count;changeCount=1;allowCreateFalseCasePassed=$true;approvedPredecessorExercisedThroughEndpointWorker=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;maintenanceValidationFixtureDerivedFromExactExtractedPayload=$true;maintenanceValidationCaseCount=$installerCases.Count;maintenanceValidationCases=$installerCases.ToArray();declaredOutputCount=$actualOutputs.Count;terminalFailureSchema=[string]$contract.expectedTerminalFailureSchema;terminalFailureState=[string]$contract.expectedTerminalFailureState;terminalCommitChecksPassed=$true;endpointWorkerSha256=[string]$contract.inheritedRoute.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256;queueSafetyGateSha256=[string]$contract.inheritedRoute.queueSafetyGateSha256;exactEndpointQueueRollbackRehearsalInherited=$true;packageLeafState=[string]$leaf.state;focusedPythonTestState=[string]$focused.state;normalPreflightState=[string]$normalPreflight.state;normalState=[string]$normal.state;normalWorkerPid=[int]$normal.pid;normalWorkerCreationTimeUtc=[string]$normal.creationTimeUtc;normalWorkerStillRunningAfterSeconds=[int]$normal.workerStillRunningAfterSeconds;bootstrapProgressState=[string]$normal.bootstrapProgressState;bootstrapScheduledCount=[int]$normal.bootstrapScheduledCount;immediateExitState=[string]$immediate.state;collisionState=[string]$collision.state;normalRoots=@{runtime=[string]$normal.runtimeRoot;gate=[string]$normal.gateRoot;corpus=[string]$normal.corpusRoot;mirror=[string]$normal.mirrorRoot};fixtureRoot=$fixtureRoot;fixturePreserved=$true;targetOrJbodAccessed=$false;sourceImageBytesRead=$false;existingProcessesQueried=$false;existingProcessOrTaskActionPerformed=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
New-Json $gatePath $record
$record|ConvertTo-Json -Depth 10
