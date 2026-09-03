#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F12([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F12Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F12Json([string]$Path, [object]$Value) { Assert-O3F12 (-not (Test-Path -LiteralPath $Path)) "O3F12 exact-package gate exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }
function Get-O3F12SubstTarget([string]$SubstPath) { $rows=@(& $SubstPath); Assert-O3F12 ($LASTEXITCODE-eq0) 'O3F12 exact-package subst query failed.'; $matches=@($rows|Where-Object{([string]$_).StartsWith('Q:\: => ',[StringComparison]::OrdinalIgnoreCase)}); Assert-O3F12 ($matches.Count-le1) 'O3F12 exact-package subst Q: cardinality changed.'; if($matches.Count-eq0){return $null}; return ([string]$matches[0]).Substring(8).Trim().TrimEnd('\') }
function New-O3F12MaintenanceFixture([string]$TemplateRoot,[string]$RequestRoot,[string]$CaseRequestId,[string]$Destination,[object]$Signer) {
    Assert-O3F12 (-not(Test-Path -LiteralPath $RequestRoot)) "O3F12 installer fixture request exists: $RequestRoot"
    Copy-Item -LiteralPath $TemplateRoot -Destination $RequestRoot -Recurse
    $manifestPath=Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.json';$signaturePath=Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.sig';$payloadRoot=Join-Path $RequestRoot 'payload'
    $fixtureEntry=Join-Path $payloadRoot 'O3F12MaintenanceValidationFixture.ps1'
    $fixtureText="#Requires -Version 5.1`r`n[ordered]@{state='PASS_O3F12_MAINTENANCE_VALIDATION_ENTRYPOINT';taskActionCount=0;existingProcessActionCount=0;providerActivated=`$false;sourceImageBytesRead=`$false;reviewOnly=`$true;productionRoutingEnabled=`$false}|ConvertTo-Json -Compress`r`n"
    [IO.File]::WriteAllText($fixtureEntry,$fixtureText,(New-Object Text.UTF8Encoding($false)))
    $fixtureManifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json;$created=[DateTimeOffset]::UtcNow
    $fixtureManifest.requestId=$CaseRequestId;$fixtureManifest.createdUtc=$created.ToString('o');$fixtureManifest.expiresUtc=$created.AddHours(2).ToString('o');$fixtureManifest.entryPoint='payload/O3F12MaintenanceValidationFixture.ps1'
    $fixtureManifest.changes[0].destination=$Destination.Replace('\','/');$fixtureManifest.rehearsal.requiredState='PASS_O3F12_MAINTENANCE_VALIDATION_ENTRYPOINT';$fixtureManifest.signerThumbprint=([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant()
    $fixtureManifest.entryPointMutations=@();$fixtureManifest.entryPointOutputs=@();$fixtureManifest.allowedTaskActions=@();$fixtureManifest.allowedProcessActions=@()
    $fixtureManifest.files=@(Get-ChildItem -LiteralPath $payloadRoot -File|Sort-Object Name|ForEach-Object{[ordered]@{path=('payload/'+$_.Name);bytes=[int64]$_.Length;sha256=Get-O3F12Hash $_.FullName}})
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($fixtureManifest|ConvertTo-Json -Depth 32));[IO.File]::WriteAllBytes($manifestPath,$bytes)
    $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Signer);try{[IO.File]::WriteAllBytes($signaturePath,$rsa.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))}finally{$rsa.Dispose()}
    return [ordered]@{requestId=$CaseRequestId;manifestSha256=Get-O3F12Hash $manifestPath;signatureSha256=Get-O3F12Hash $signaturePath;payloadFileCount=@($fixtureManifest.files).Count}
}
function Invoke-O3F12MaintenanceCase([string]$Name,[string]$TemplateRoot,[string]$CasesRoot,[string]$Anchor,[bool]$Approved,[object]$Signer,[string]$Worker,[string]$RequestVerifier,[string]$ResponseVerifier,[string]$PublicCertificate) {
    $caseRoot=Join-Path $CasesRoot $Name;$installRoot=Join-Path $caseRoot 'install';$target=Join-Path $installRoot 'OCV03_NotchReviewOpenCvV1.py'
    foreach($relative in @('incoming','processed','responses','state','install')){[void](New-Item -ItemType Directory -Path (Join-Path $caseRoot $relative))}
    if($Approved){Copy-Item -LiteralPath $Anchor -Destination $target}else{[IO.File]::WriteAllText($target,'O3F12_UNAPPROVED_PREDECESSOR',(New-Object Text.UTF8Encoding($false)))}
    $beforeSha=Get-O3F12Hash $target;$caseRequestId='REQ_O3F12_IR_'+$Name;$requestRoot=Join-Path (Join-Path $caseRoot 'incoming') ($caseRequestId+'.ready')
    $fixture=New-O3F12MaintenanceFixture $TemplateRoot $requestRoot $caseRequestId $target $Signer
    $configPath=Join-Path $caseRoot 'ENDPOINT_CONFIG.json'
    Write-O3F12Json $configPath ([ordered]@{schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false;incomingRoot=Join-Path $caseRoot 'incoming';processedRoot=Join-Path $caseRoot 'processed';responseOutbox=Join-Path $caseRoot 'responses';stateRoot=Join-Path $caseRoot 'state';requestVerifierPath=$RequestVerifier;laptopSignerCertificatePath=$PublicCertificate;endpointSignerThumbprint=([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant();endpointSignerStoreLocation='CurrentUser';approvedMaintenanceRoots=@($installRoot);approvedDataRoots=@();status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()};handlers=@()})
    & $Worker -ConfigPath $configPath -Once|Out-Null
    $responses=@(Get-ChildItem -LiteralPath (Join-Path $caseRoot 'responses') -Directory -Filter '*.ready');Assert-O3F12 ($responses.Count-eq1) "O3F12 installer fixture response cardinality changed: $Name"
    & $ResponseVerifier -PackagePath $responses[0].FullName -EndpointCertificatePath $PublicCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $caseRequestId|Out-Null
    $response=Get-Content -LiteralPath (Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.json') -Raw|ConvertFrom-Json;$afterSha=Get-O3F12Hash $target;$installLeaves=@(Get-ChildItem -LiteralPath $installRoot -File)
    Assert-O3F12 ($installLeaves.Count-eq1-and$installLeaves[0].FullName-eq$target) "O3F12 installer fixture wrote an undeclared install leaf: $Name"
    if($Approved){
        Assert-O3F12 ([string]$response.state-eq'PASS_MAINTENANCE_PATCH'-and$afterSha-eq(Get-O3F12Hash $Anchor)) "O3F12 approved installer case failed: $Name"
        $result=Get-Content -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json') -Raw|ConvertFrom-Json
        Assert-O3F12 ([string]$result.state-eq'PASS_MAINTENANCE_PATCH'-and[int]$result.changedFiles-eq1-and[bool]$result.changes[0].predecessorExisted-and[string]$result.changes[0].installedSha256-eq$afterSha) "O3F12 maintenance result contract changed: $Name"
    }else{
        Assert-O3F12 ([string]$response.state-eq'FAILED'-and([string]$response.detail)-like'*Installed predecessor is not approved*'-and$afterSha-eq$beforeSha-and-not(Test-Path -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json'))) 'O3F12 unapproved predecessor was not refused before install mutation.'
    }
    return [ordered]@{case=$Name;endpointState=[string]$response.state;requestManifestSha256=[string]$fixture.manifestSha256;signatureVerified=$true;approvedPredecessor=$Approved;beforeSha256=$beforeSha;afterSha256=$afterSha;installLeafCount=$installLeaves.Count;refusedBeforeMutation=(-not$Approved)}
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_O3F12_20260902A'
$zip = Join-Path $PSScriptRoot 'final_o3f12\REQ_O3F12_20260902A.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'O3F12_FINAL_PACKAGE_GATE.json'
$endpointRehearsalGatePath = Join-Path $PSScriptRoot 'O3F12_ENDPOINT_REHEARSAL_GATE.json'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$signingIdentityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$endpointWorker = Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$python = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$fixtureRoot = 'C:\A12R'
$gateRoot = 'C:\A12R\g'
$devRoot = 'C:\A12R\d'
$gatePath = Join-Path $PSScriptRoot 'O3F12_EXACT_PACKAGE_REHEARSAL_GATE.json'
foreach ($path in @($zip, $finalGatePath, $endpointRehearsalGatePath, $certificate, $packageTester, $responseVerifier, $signingIdentityPath, $endpointWorker, $queueGate, $python)) { Assert-O3F12 (Test-Path -LiteralPath $path -PathType Leaf) "O3F12 exact-package dependency is absent: $path" }
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-O3F12 ([string]$finalGate.state -eq 'PASS_O3F12_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O3F12 final package gate changed.'
$expectedZip = [string]$finalGate.requestZipSha256
Assert-O3F12 ((Get-O3F12Hash $zip) -eq $expectedZip) 'O3F12 final ZIP changed.'
Assert-O3F12 ((Get-O3F12Hash $certificate) -eq '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF') 'O3F12 laptop signer certificate changed.'
Assert-O3F12 ((Get-O3F12Hash $packageTester) -eq '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B') 'O3F12 signed-package verifier changed.'
Assert-O3F12 ((Get-O3F12Hash $responseVerifier) -eq '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C' -and (Get-O3F12Hash $signingIdentityPath) -eq '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289') 'O3F12 installer-rehearsal signing dependencies changed.'
Assert-O3F12 ((Get-O3F12Hash $endpointWorker) -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3F12 endpoint worker changed.'
Assert-O3F12 ((Get-O3F12Hash $queueGate) -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F12 queue-safety gate changed.'
Assert-O3F12 ((Get-O3F12Hash $python) -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F12 rehearsal runtime changed.'
Assert-O3F12 (-not (Test-Path -LiteralPath $fixtureRoot)) 'O3F12 exact-package rehearsal root exists.'
Assert-O3F12 (-not (Test-Path -LiteralPath $gatePath)) 'O3F12 exact-package rehearsal gate exists.'
$pathCheck = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3F12StagedEndpoint.ps1'), (Join-Path $fixtureRoot 'installer\UNAPPROVED\state\maintenance\REQ_O3F12_IR_UNAPPROVED\failed_new\M000_0123456789_0123456789.rollback'), (Join-Path $fixtureRoot 'i.json'), (Join-Path $gateRoot 'SUMMARY.json'), (Join-Path $devRoot 'SUMMARY.json'), $gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-O3F12 ([string]$pathCheck.state -eq 'PASS_PATH_BUDGET') 'O3F12 exact-package path gate failed.'
if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f12_exact_package_rehearsal_preflight_v1';state='PASS_O3F12_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract = Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
$packageTest = & $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-O3F12 ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F12 exact package signature failed.'
$manifest = Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
$payload = Join-Path $extract 'payload'
Assert-O3F12 ([string]$manifest.requestId -eq $requestId -and @($manifest.files).Count -eq 15 -and @($manifest.changes).Count -eq 1) 'O3F12 signed manifest identity changed.'
Assert-O3F12 ([int64]$manifest.maxResultBytes -eq 2097152 -and [string]$manifest.entryPoint -eq 'payload/Invoke-O3F12StagedEndpoint.ps1' -and @($manifest.entryPointMutations).Count -eq 2 -and @($manifest.entryPointOutputs).Count -eq 2 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 2 -and @($manifest.allowedProcessActions) -contains 'START_FIVE_SEQUENTIAL_BOUNDED_OWNED_O3F12_CHILDREN_ONLY' -and @($manifest.allowedProcessActions) -contains 'CREATE_QUERY_VERIFY_REMOVE_TEMPORARY_Q_SOURCE_ALIAS_PER_DEV6_CASE_WITH_ENDPOINT_TIMEOUT_CLEANUP_BACKSTOP') 'O3F12 signed maintenance contract changed.'
Assert-O3F12 ([string]::Join('|', @($manifest.sourceProcessingContract.stages)) -ceq 'SELF_TEST|PREFLIGHT|ROOT_CONTRACT|GATE|DEV6' -and [int]$manifest.sourceProcessingContract.dev6Cardinality -eq 6) 'O3F12 signed stage sequence/cardinality changed.'
Assert-O3F12 ([string]$manifest.rehearsal.requiredState -eq 'COMPLETE_O3F12_GATE_AND_DEV6_REVIEW_ONLY' -and [string]$manifest.rehearsal.gateState -eq 'PASS_O3F12_EXACT_ENTRYPOINT_REHEARSAL' -and [string]$manifest.rehearsal.gateSha256 -eq (Get-O3F12Hash $endpointRehearsalGatePath)) 'O3F12 signed rehearsal evidence is pending, absent, or stale.'
foreach ($record in @($manifest.files)) {
    $relative = [string]$record.path
    Assert-O3F12 (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3F12 signed payload path is unsafe.'
    $file = Join-Path $extract $relative
    Assert-O3F12 (Test-Path -LiteralPath $file -PathType Leaf) "O3F12 signed payload file is absent: $relative"
    Assert-O3F12 ((Get-Item -LiteralPath $file).Length -eq [int64]$record.bytes -and (Get-O3F12Hash $file) -eq [string]$record.sha256) "O3F12 signed payload hash changed: $relative"
}
$liveInvocationPath = Join-Path $payload 'O3F12_ENDPOINT_LIVE_INVOCATION.json'
$liveInvocation = Get-Content -LiteralPath $liveInvocationPath -Raw | ConvertFrom-Json
Assert-O3F12 ([string]$liveInvocation.schema -eq 'argos_ocv03_o3f12_endpoint_invocation_v1' -and [string]$liveInvocation.state -eq 'FROZEN_LIVE_CONTRACT' -and @($liveInvocation.files).Count -eq 13) 'O3F12 extracted live invocation identity changed.'
Assert-O3F12 ([string]$liveInvocation.endpointSha256 -eq (Get-O3F12Hash (Join-Path $payload 'Invoke-O3F12StagedEndpoint.ps1'))) 'O3F12 extracted live invocation endpoint pin changed.'
Assert-O3F12 ([string]$liveInvocation.gateOutputRoot -eq 'D:/O3F9G12' -and [string]$liveInvocation.realRunnerGateContractRoot -eq [string]$liveInvocation.gateOutputRoot) 'O3F12 extracted live GATE/root contract is not exact.'
Assert-O3F12 ([string]$liveInvocation.dev6OutputRoot -eq 'D:/O3F9D12' -and [string]$liveInvocation.realRunnerDev6ContractRoot -eq [string]$liveInvocation.dev6OutputRoot) 'O3F12 extracted live DEV6/root contract is not exact.'
Assert-O3F12 ([string]$liveInvocation.revision -eq 'OCV03_O3F12_R10_STAGED_DEV6_20260902A' -and [string]$liveInvocation.expectedComputerName -eq 'A1025645101' -and [string]$liveInvocation.payloadRoot -eq '') 'O3F12 extracted live identity/endpoint target changed.'
Assert-O3F12 ([string]$liveInvocation.runtimePath -eq 'D:/AFCV1/rt/python.exe' -and [string]$liveInvocation.runtimeSha256 -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F12 extracted live runtime pin changed.'
Assert-O3F12 ([string]$liveInvocation.sourceAliasDrive -ceq 'Q:' -and [string]$liveInvocation.substPath -eq 'C:/Windows/System32/subst.exe' -and [string]$liveInvocation.substSha256 -eq '158598ED3D590937C964B43DD91546FFCABAB5636B6CE619B4FFC43224013BB6') 'O3F12 extracted live source-alias executable contract changed.'
Assert-O3F12 ([string]$liveInvocation.expectedSelfTestState -eq 'PASS_O3F12_STAGED_RUNNER_SELF_TEST' -and [string]$liveInvocation.expectedPreflightState -eq 'PASS_O3F12_STAGED_PREFLIGHT' -and [string]$liveInvocation.expectedGateState -eq 'COMPLETE_O3F12_GATE' -and [string]$liveInvocation.expectedDev6State -eq 'COMPLETE_O3F12_DEV6') 'O3F12 extracted live stage states changed.'
Assert-O3F12 ([int]$liveInvocation.selfTestTimeoutSeconds -eq 60 -and [int]$liveInvocation.preflightTimeoutSeconds -eq 120 -and [int]$liveInvocation.rootContractTimeoutSeconds -eq 60 -and [int]$liveInvocation.gateTimeoutSeconds -eq 300 -and [int]$liveInvocation.dev6TimeoutSeconds -eq 900) 'O3F12 extracted live child timeouts changed.'
Assert-O3F12 ([int]$liveInvocation.maximumChildOutputBytes -eq 1048576 -and [int]$liveInvocation.maximumTerminalOutputBytes -eq 1048576) 'O3F12 extracted live output bounds changed.'
Assert-O3F12 ([bool]$liveInvocation.detectorDevelopmentAuthorized -and -not [bool]$liveInvocation.taskOrExistingProcessActionAuthorized -and -not [bool]$liveInvocation.sourceMutationAuthorized -and -not [bool]$liveInvocation.sourceDeletionAuthorized -and -not [bool]$liveInvocation.providerActivationAuthorized -and -not [bool]$liveInvocation.requestRetryAuthorized) 'O3F12 extracted live execution authority widened.'
Assert-O3F12 ([bool]$liveInvocation.reviewOnly -and -not [bool]$liveInvocation.trainingEligible -and -not [bool]$liveInvocation.xmlEligible -and -not [bool]$liveInvocation.productionEligible -and -not [bool]$liveInvocation.productionRoutingEnabled) 'O3F12 extracted live eligibility widened.'
$liveRunnerRecord = @($liveInvocation.files | Where-Object { [string]$_.role -eq 'runner' })
$liveRootProbeRecord = @($liveInvocation.files | Where-Object { [string]$_.role -eq 'rootContractProbe' })
Assert-O3F12 ($liveRunnerRecord.Count -eq 1 -and [string]$liveRunnerRecord[0].sha256 -eq '7FA26CF830CAE3FFEB1B34295408E6551F96003A9AC3E07896F750BE5B8492A1') 'O3F12 extracted live runner pin changed.'
Assert-O3F12 ($liveRootProbeRecord.Count -eq 1 -and [string]$liveRootProbeRecord[0].sha256 -eq (Get-O3F12Hash (Join-Path $payload 'O3F12RootContractProbe.py'))) 'O3F12 extracted live root-probe pin changed.'
$change = @($manifest.changes)[0]
$anchor = Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py'
$anchorSha = Get-O3F12Hash $anchor
Assert-O3F12 ([string]$change.source -eq 'payload/OCV03_NotchReviewOpenCvV1.py' -and [string]$change.installedSha256 -eq $anchorSha -and @($change.approvedPredecessorSha256).Count -eq 1 -and @($change.approvedPredecessorSha256) -contains $anchorSha -and -not [bool]$change.allowCreate) 'O3F12 signed protocol-anchor contract changed.'
$identity=Get-Content -LiteralPath $signingIdentityPath -Raw|ConvertFrom-Json;$signer=Get-Item -LiteralPath ('Cert:\CurrentUser\My\'+([string]$identity.thumbprint).Replace(' ',''))
Assert-O3F12 ([bool]$signer.HasPrivateKey) 'O3F12 installer-rehearsal signing key is absent.'
$installerRoot=Join-Path $fixtureRoot 'installer';[void](New-Item -ItemType Directory -Path $installerRoot)
$installerCases=New-Object Collections.Generic.List[object]
$installerCases.Add((Invoke-O3F12MaintenanceCase 'APPROVED' $extract $installerRoot $anchor $true $signer $endpointWorker $packageTester $responseVerifier $certificate))
$installerCases.Add((Invoke-O3F12MaintenanceCase 'IDEMPOTENT' $extract $installerRoot $anchor $true $signer $endpointWorker $packageTester $responseVerifier $certificate))
$installerCases.Add((Invoke-O3F12MaintenanceCase 'UNAPPROVED' $extract $installerRoot $anchor $false $signer $endpointWorker $packageTester $responseVerifier $certificate))
Assert-O3F12 ($installerCases.Count-eq3-and@($installerCases|Where-Object{[string]$_.endpointState-eq'PASS_MAINTENANCE_PATCH'}).Count-eq2-and@($installerCases|Where-Object{[bool]$_.refusedBeforeMutation}).Count-eq1) 'O3F12 exact maintenance-validation case set changed.'

$roleByName = @{
    'Run-O3F12Staged.py'='runner'; 'Run-O3F8Staged.py'='baseRunner'; 'FullPerimeterWaferTopologyOpenCvR10.py'='r10Detector'; 'FullPerimeterWaferTopologyOpenCvR9.py'='r9Detector'; 'FullPerimeterWaferTopologyOpenCvR8.py'='r8Detector'; 'Detect-O3P8FrontSplitNotches.py'='o3p8Detector'; 'Test-O3F8SymmetricRecovery.py'='localGate'; 'O3P8_POST2_SHORT_ALIAS_JOB.json'='o3p8Job'; 'O3M9_SLOT16_JOB.json'='canonicalJob'; 'OCV03_NotchReviewOpenCvV1.py'='protocolAnchor'; 'O3F12FixtureRunner.py'='rehearsalRunner'; 'O3F12RootContractProbe.py'='rootContractProbe'; 'O3F12_DEV6_SOURCE_ALIAS_PLAN.json'='sourceAliasPlan'
}
$files = New-Object Collections.Generic.List[object]
foreach ($name in $roleByName.Keys) {
    $record = @($manifest.files | Where-Object { [string]$_.path -eq ('payload/' + $name) })
    Assert-O3F12 ($record.Count -eq 1) "O3F12 role payload cardinality changed: $name"
    $files.Add([pscustomobject]@{role=[string]$roleByName[$name];path=$name;bytes=[int64]$record[0].bytes;sha256=[string]$record[0].sha256})
}
$liveRoles = @($liveInvocation.files.role | Sort-Object -Unique)
Assert-O3F12 ($liveRoles.Count -eq $files.Count) 'O3F12 extracted live invocation role cardinality changed.'
foreach ($fileRecord in $files.ToArray()) {
    $liveRecord = @($liveInvocation.files | Where-Object { [string]$_.role -eq [string]$fileRecord.role })
    Assert-O3F12 ($liveRecord.Count -eq 1 -and [string]$liveRecord[0].path -eq [string]$fileRecord.path -and [int64]$liveRecord[0].bytes -eq [int64]$fileRecord.bytes -and [string]$liveRecord[0].sha256 -eq [string]$fileRecord.sha256) "O3F12 extracted live invocation payload pin changed: $($fileRecord.role)"
}
$endpoint = Join-Path $payload 'Invoke-O3F12StagedEndpoint.ps1'
$invocationPath = Join-Path $fixtureRoot 'i.json'
$invocation = [ordered]@{schema='argos_ocv03_o3f12_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision='O3F12_EXACT_PACKAGE_PREFLIGHT';expectedComputerName=$env:COMPUTERNAME;payloadRoot=$payload;endpointSha256=Get-O3F12Hash $endpoint;files=$files.ToArray();runtimePath='';runtimeSha256='';rehearsalRuntimePath=$python;rehearsalRuntimeSha256=Get-O3F12Hash $python;sourceAliasDrive=[string]$liveInvocation.sourceAliasDrive;substPath=[string]$liveInvocation.substPath;substSha256=[string]$liveInvocation.substSha256;aliasFixtureRoot=(Join-Path $fixtureRoot 'q');gateOutputRoot=$gateRoot;dev6OutputRoot=$devRoot;realRunnerGateContractRoot=[string]$liveInvocation.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$liveInvocation.realRunnerDev6ContractRoot;expectedSelfTestState=[string]$liveInvocation.expectedSelfTestState;expectedPreflightState=[string]$liveInvocation.expectedPreflightState;expectedGateState=[string]$liveInvocation.expectedGateState;expectedDev6State=[string]$liveInvocation.expectedDev6State;selfTestTimeoutSeconds=[int]$liveInvocation.selfTestTimeoutSeconds;preflightTimeoutSeconds=[int]$liveInvocation.preflightTimeoutSeconds;rootContractTimeoutSeconds=[int]$liveInvocation.rootContractTimeoutSeconds;gateTimeoutSeconds=[int]$liveInvocation.gateTimeoutSeconds;dev6TimeoutSeconds=[int]$liveInvocation.dev6TimeoutSeconds;maximumChildOutputBytes=[int]$liveInvocation.maximumChildOutputBytes;maximumTerminalOutputBytes=[int]$liveInvocation.maximumTerminalOutputBytes;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-O3F12Json $invocationPath $invocation
$endpointPreflight = & $endpoint -Preflight -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json
Assert-O3F12 ([string]$endpointPreflight.state -eq 'PASS_O3F12_ENDPOINT_PREFLIGHT' -and -not [bool]$endpointPreflight.sourceImageBytesRead -and -not [bool]$endpointPreflight.outputCreated) 'O3F12 exact extracted endpoint preflight failed.'
$endpointRehearsal = & $endpoint -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json
$runnerRecord = @($files.ToArray() | Where-Object { [string]$_.role -eq 'runner' })
Assert-O3F12 ($runnerRecord.Count -eq 1) 'O3F12 exact extracted real runner role cardinality changed.'
Assert-O3F12 ([string]$endpointRehearsal.state -eq 'COMPLETE_O3F12_GATE_AND_DEV6_REVIEW_ONLY' -and [bool]$endpointRehearsal.rehearsal -and @($endpointRehearsal.dev6.cases).Count -eq 6 -and -not [bool]$endpointRehearsal.sourceImageBytesRead) 'O3F12 exact extracted endpoint image-free rehearsal failed.'
Assert-O3F12 ([string]$endpointRehearsal.selfTest.state -eq 'PASS_O3F12_STAGED_RUNNER_SELF_TEST' -and -not [bool]$endpointRehearsal.selfTest.mutationsPerformed -and [string]$endpointRehearsal.selfTest.runnerSha256 -eq [string]$runnerRecord[0].sha256) 'O3F12 exact extracted real SELF_TEST contract changed.'
Assert-O3F12 ([string]$endpointRehearsal.rootContract.state -eq 'PASS_O3F12_EXACT_REAL_RUNNER_ROOT_CONTRACT' -and [string]$endpointRehearsal.rootContract.gateRoot -eq 'D:/O3F9G12' -and [string]$endpointRehearsal.rootContract.dev6Root -eq 'D:/O3F9D12' -and [string]::Join('|', @($endpointRehearsal.rootContract.gateTerminalKeys)) -ceq 'commands|stage|state|summarySha256' -and [string]::Join('|', @($endpointRehearsal.rootContract.dev6TerminalKeys)) -ceq 'aliasEvidence|executedCount|newProviderHoldCount|results|selectedCount|stage|state|stateCounts|summarySha256' -and [bool]$endpointRehearsal.rootContract.simulatedFilesystem -and [bool]$endpointRehearsal.rootContract.incompatibleO3F12PrefixRejected -and [bool]$endpointRehearsal.rootContract.mutationsPerformed -and [bool]$endpointRehearsal.rootContract.aliasContract.lifecycle.exercised -and [bool]$endpointRehearsal.rootContract.aliasContract.lifecycle.qAbsentAfterBoth) 'O3F12 exact extracted real-runner root/schema/alias contract changed.'
Assert-O3F12 ($null -eq (Get-O3F12SubstTarget ([string]$liveInvocation.substPath)) -and -not (Test-Path -LiteralPath 'Q:\')) 'O3F12 exact-package rehearsal left Q: mapped.'
$sourceAliasPlanRecord = @($files.ToArray() | Where-Object { [string]$_.role -eq 'sourceAliasPlan' })
Assert-O3F12 ($sourceAliasPlanRecord.Count -eq 1 -and [string]$sourceAliasPlanRecord[0].sha256 -eq (Get-O3F12Hash (Join-Path $payload 'O3F12_DEV6_SOURCE_ALIAS_PLAN.json'))) 'O3F12 exact extracted source-alias plan changed.'
$record = [ordered]@{schema='argos_ocv03_o3f12_exact_package_rehearsal_gate_v1';state='PASS_O3F12_EXACT_PACKAGE_REHEARSAL';requestId=$requestId;requestZipSha256=$expectedZip;windowsPowerShell=@{major=[int]$PSVersionTable.PSVersion.Major;minor=[int]$PSVersionTable.PSVersion.Minor};exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=15;changeCount=1;allowCreateFalseCasePassed=$true;approvedPredecessorExercisedThroughEndpointWorker=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;maintenanceValidationFixtureDerivedFromExactExtractedPayload=$true;maintenanceValidationCaseCount=$installerCases.Count;maintenanceValidationCases=$installerCases.ToArray();exactLiveInvocationSha256=Get-O3F12Hash $liveInvocationPath;exactLiveGateOutputRoot=[string]$liveInvocation.gateOutputRoot;exactLiveDev6OutputRoot=[string]$liveInvocation.dev6OutputRoot;exactLiveRunnerSha256=[string]$liveRunnerRecord[0].sha256;exactSourceAliasPlanSha256=[string]$sourceAliasPlanRecord[0].sha256;substSha256=[string]$liveInvocation.substSha256;exactExtractedEndpointPreflightState=[string]$endpointPreflight.state;exactExtractedEndpointRehearsalState=[string]$endpointRehearsal.state;exactExtractedRealSelfTestState=[string]$endpointRehearsal.selfTest.state;exactExtractedRealRunnerSha256=[string]$endpointRehearsal.selfTest.runnerSha256;exactExtractedRootContractState=[string]$endpointRehearsal.rootContract.state;exactExtractedRootContractProbeSha256=Get-O3F12Hash (Join-Path $payload 'O3F12RootContractProbe.py');exactExtractedRootContractGateRoot=[string]$endpointRehearsal.rootContract.gateRoot;exactExtractedRootContractDev6Root=[string]$endpointRehearsal.rootContract.dev6Root;exactExtractedAliasContract=$endpointRehearsal.rootContract.aliasContract;incompatibleO3F12PrefixRejected=[bool]$endpointRehearsal.rootContract.incompatibleO3F12PrefixRejected;exactExtractedFixtureDev6CaseCount=@($endpointRehearsal.dev6.cases).Count;qAbsentAfterExactPackageRehearsal=$true;exactExtractedEndpointSha256=Get-O3F12Hash $endpoint;protocolAnchorSha256=$anchorSha;protocolAnchorExpectedByteIdentical=$true;protocolAnchorExecutedByEntrypoint=$false;endpointWorkerSha256=Get-O3F12Hash $endpointWorker;inheritedQueueSafetyGateSha256=Get-O3F12Hash $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceMutationPerformed=$false;taskActionCount=0;existingProcessActionCount=0;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-O3F12Json $gatePath $record
$record | ConvertTo-Json -Depth 12
