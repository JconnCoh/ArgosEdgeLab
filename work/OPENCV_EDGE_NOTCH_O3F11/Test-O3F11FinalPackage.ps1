#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F11([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F11Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F11Json([string]$Path, [object]$Value) { Assert-O3F11 (-not (Test-Path -LiteralPath $Path)) "O3F11 exact-package gate exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_O3F11_20260902A'
$zip = Join-Path $PSScriptRoot 'final_o3f11\REQ_O3F11_20260902A.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'O3F11_FINAL_PACKAGE_GATE.json'
$endpointRehearsalGatePath = Join-Path $PSScriptRoot 'O3F11_ENDPOINT_REHEARSAL_GATE.json'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$endpointWorker = Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$python = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$fixtureRoot = 'C:\A11R'
$gateRoot = 'C:\A11R\g'
$devRoot = 'C:\A11R\d'
$gatePath = Join-Path $PSScriptRoot 'O3F11_EXACT_PACKAGE_REHEARSAL_GATE.json'
foreach ($path in @($zip, $finalGatePath, $endpointRehearsalGatePath, $certificate, $packageTester, $endpointWorker, $queueGate, $python)) { Assert-O3F11 (Test-Path -LiteralPath $path -PathType Leaf) "O3F11 exact-package dependency is absent: $path" }
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-O3F11 ([string]$finalGate.state -eq 'PASS_O3F11_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O3F11 final package gate changed.'
$expectedZip = [string]$finalGate.requestZipSha256
Assert-O3F11 ((Get-O3F11Hash $zip) -eq $expectedZip) 'O3F11 final ZIP changed.'
Assert-O3F11 ((Get-O3F11Hash $certificate) -eq '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF') 'O3F11 laptop signer certificate changed.'
Assert-O3F11 ((Get-O3F11Hash $packageTester) -eq '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B') 'O3F11 signed-package verifier changed.'
Assert-O3F11 ((Get-O3F11Hash $endpointWorker) -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3F11 endpoint worker changed.'
Assert-O3F11 ((Get-O3F11Hash $queueGate) -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F11 queue-safety gate changed.'
Assert-O3F11 ((Get-O3F11Hash $python) -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F11 rehearsal runtime changed.'
Assert-O3F11 (-not (Test-Path -LiteralPath $fixtureRoot)) 'O3F11 exact-package rehearsal root exists.'
Assert-O3F11 (-not (Test-Path -LiteralPath $gatePath)) 'O3F11 exact-package rehearsal gate exists.'
$pathCheck = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3F11StagedEndpoint.ps1'), (Join-Path $fixtureRoot 'target\OCV03_NotchReviewOpenCvV1.py'), (Join-Path $fixtureRoot 'i.json'), (Join-Path $gateRoot 'SUMMARY.json'), (Join-Path $devRoot 'SUMMARY.json'), $gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-O3F11 ([string]$pathCheck.state -eq 'PASS_PATH_BUDGET') 'O3F11 exact-package path gate failed.'
if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f11_exact_package_rehearsal_preflight_v1';state='PASS_O3F11_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract = Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
$packageTest = & $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-O3F11 ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F11 exact package signature failed.'
$manifest = Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
$payload = Join-Path $extract 'payload'
Assert-O3F11 ([string]$manifest.requestId -eq $requestId -and @($manifest.files).Count -eq 14 -and @($manifest.changes).Count -eq 1) 'O3F11 signed manifest identity changed.'
Assert-O3F11 ([int64]$manifest.maxResultBytes -eq 2097152 -and [string]$manifest.entryPoint -eq 'payload/Invoke-O3F11StagedEndpoint.ps1' -and @($manifest.entryPointMutations).Count -eq 2 -and @($manifest.entryPointOutputs).Count -eq 2 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1 -and [string]$manifest.allowedProcessActions[0] -eq 'START_FIVE_SEQUENTIAL_BOUNDED_OWNED_O3F11_CHILDREN_ONLY') 'O3F11 signed maintenance contract changed.'
Assert-O3F11 ([string]::Join('|', @($manifest.sourceProcessingContract.stages)) -ceq 'SELF_TEST|PREFLIGHT|ROOT_CONTRACT|GATE|DEV6' -and [int]$manifest.sourceProcessingContract.dev6Cardinality -eq 6) 'O3F11 signed stage sequence/cardinality changed.'
Assert-O3F11 ([string]$manifest.rehearsal.requiredState -eq 'COMPLETE_O3F11_GATE_AND_DEV6_REVIEW_ONLY' -and [string]$manifest.rehearsal.gateState -eq 'PASS_O3F11_EXACT_ENTRYPOINT_REHEARSAL' -and [string]$manifest.rehearsal.gateSha256 -eq (Get-O3F11Hash $endpointRehearsalGatePath)) 'O3F11 signed rehearsal evidence is pending, absent, or stale.'
foreach ($record in @($manifest.files)) {
    $relative = [string]$record.path
    Assert-O3F11 (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3F11 signed payload path is unsafe.'
    $file = Join-Path $extract $relative
    Assert-O3F11 (Test-Path -LiteralPath $file -PathType Leaf) "O3F11 signed payload file is absent: $relative"
    Assert-O3F11 ((Get-Item -LiteralPath $file).Length -eq [int64]$record.bytes -and (Get-O3F11Hash $file) -eq [string]$record.sha256) "O3F11 signed payload hash changed: $relative"
}
$liveInvocationPath = Join-Path $payload 'O3F11_ENDPOINT_LIVE_INVOCATION.json'
$liveInvocation = Get-Content -LiteralPath $liveInvocationPath -Raw | ConvertFrom-Json
Assert-O3F11 ([string]$liveInvocation.schema -eq 'argos_ocv03_o3f11_endpoint_invocation_v1' -and [string]$liveInvocation.state -eq 'FROZEN_LIVE_CONTRACT' -and @($liveInvocation.files).Count -eq 12) 'O3F11 extracted live invocation identity changed.'
Assert-O3F11 ([string]$liveInvocation.endpointSha256 -eq (Get-O3F11Hash (Join-Path $payload 'Invoke-O3F11StagedEndpoint.ps1'))) 'O3F11 extracted live invocation endpoint pin changed.'
Assert-O3F11 ([string]$liveInvocation.gateOutputRoot -eq 'D:/O3F9G11' -and [string]$liveInvocation.realRunnerGateContractRoot -eq [string]$liveInvocation.gateOutputRoot) 'O3F11 extracted live GATE/root contract is not exact.'
Assert-O3F11 ([string]$liveInvocation.dev6OutputRoot -eq 'D:/O3F9D11' -and [string]$liveInvocation.realRunnerDev6ContractRoot -eq [string]$liveInvocation.dev6OutputRoot) 'O3F11 extracted live DEV6/root contract is not exact.'
Assert-O3F11 ([string]$liveInvocation.revision -eq 'OCV03_O3F11_R10_STAGED_DEV6_20260902A' -and [string]$liveInvocation.expectedComputerName -eq 'A1025645101' -and [string]$liveInvocation.payloadRoot -eq '') 'O3F11 extracted live identity/endpoint target changed.'
Assert-O3F11 ([string]$liveInvocation.runtimePath -eq 'D:/AFCV1/rt/python.exe' -and [string]$liveInvocation.runtimeSha256 -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F11 extracted live runtime pin changed.'
Assert-O3F11 ([string]$liveInvocation.expectedSelfTestState -eq 'PASS_O3F9_STAGED_RUNNER_SELF_TEST' -and [string]$liveInvocation.expectedPreflightState -eq 'PASS_O3F9_STAGED_PREFLIGHT' -and [string]$liveInvocation.expectedGateState -eq 'COMPLETE_O3F9_GATE' -and [string]$liveInvocation.expectedDev6State -eq 'COMPLETE_O3F9_DEV6') 'O3F11 extracted live stage states changed.'
Assert-O3F11 ([int]$liveInvocation.selfTestTimeoutSeconds -eq 60 -and [int]$liveInvocation.preflightTimeoutSeconds -eq 120 -and [int]$liveInvocation.rootContractTimeoutSeconds -eq 60 -and [int]$liveInvocation.gateTimeoutSeconds -eq 300 -and [int]$liveInvocation.dev6TimeoutSeconds -eq 900) 'O3F11 extracted live child timeouts changed.'
Assert-O3F11 ([int]$liveInvocation.maximumChildOutputBytes -eq 1048576 -and [int]$liveInvocation.maximumTerminalOutputBytes -eq 1048576) 'O3F11 extracted live output bounds changed.'
Assert-O3F11 ([bool]$liveInvocation.detectorDevelopmentAuthorized -and -not [bool]$liveInvocation.taskOrExistingProcessActionAuthorized -and -not [bool]$liveInvocation.sourceMutationAuthorized -and -not [bool]$liveInvocation.sourceDeletionAuthorized -and -not [bool]$liveInvocation.providerActivationAuthorized -and -not [bool]$liveInvocation.requestRetryAuthorized) 'O3F11 extracted live execution authority widened.'
Assert-O3F11 ([bool]$liveInvocation.reviewOnly -and -not [bool]$liveInvocation.trainingEligible -and -not [bool]$liveInvocation.xmlEligible -and -not [bool]$liveInvocation.productionEligible -and -not [bool]$liveInvocation.productionRoutingEnabled) 'O3F11 extracted live eligibility widened.'
$liveRunnerRecord = @($liveInvocation.files | Where-Object { [string]$_.role -eq 'runner' })
$liveRootProbeRecord = @($liveInvocation.files | Where-Object { [string]$_.role -eq 'rootContractProbe' })
Assert-O3F11 ($liveRunnerRecord.Count -eq 1 -and [string]$liveRunnerRecord[0].sha256 -eq '606AFE5DF058F0298CFE333D9091DF3F5F0B5F222EC03C40E73006773F587D72') 'O3F11 extracted live runner pin changed.'
Assert-O3F11 ($liveRootProbeRecord.Count -eq 1 -and [string]$liveRootProbeRecord[0].sha256 -eq (Get-O3F11Hash (Join-Path $payload 'O3F11RootContractProbe.py'))) 'O3F11 extracted live root-probe pin changed.'
$change = @($manifest.changes)[0]
$anchor = Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py'
$anchorSha = Get-O3F11Hash $anchor
Assert-O3F11 ([string]$change.source -eq 'payload/OCV03_NotchReviewOpenCvV1.py' -and [string]$change.installedSha256 -eq $anchorSha -and @($change.approvedPredecessorSha256).Count -eq 1 -and @($change.approvedPredecessorSha256) -contains $anchorSha -and -not [bool]$change.allowCreate) 'O3F11 signed protocol-anchor contract changed.'
$targetRoot = Join-Path $fixtureRoot 'target'
[void](New-Item -ItemType Directory -Path $targetRoot)
$target = Join-Path $targetRoot 'OCV03_NotchReviewOpenCvV1.py'
Copy-Item -LiteralPath $anchor -Destination $target
$targetBefore = Get-O3F11Hash $target
Assert-O3F11 (@($change.approvedPredecessorSha256) -contains $targetBefore -and $targetBefore -eq $anchorSha -and (Get-O3F11Hash $target) -eq $targetBefore) 'O3F11 same-hash predecessor/idempotent case failed.'
$unapproved = Join-Path $targetRoot 'unapproved.py'
[IO.File]::WriteAllText($unapproved, 'unapproved', (New-Object Text.UTF8Encoding($false)))
$unapprovedSha = Get-O3F11Hash $unapproved
Assert-O3F11 (@($change.approvedPredecessorSha256) -notcontains $unapprovedSha -and (Get-O3F11Hash $unapproved) -eq $unapprovedSha) 'O3F11 unapproved predecessor was not refused before mutation.'

$roleByName = @{
    'Run-O3F9Staged.py'='runner'; 'Run-O3F8Staged.py'='baseRunner'; 'FullPerimeterWaferTopologyOpenCvR10.py'='r10Detector'; 'FullPerimeterWaferTopologyOpenCvR9.py'='r9Detector'; 'FullPerimeterWaferTopologyOpenCvR8.py'='r8Detector'; 'Detect-O3P8FrontSplitNotches.py'='o3p8Detector'; 'Test-O3F8SymmetricRecovery.py'='localGate'; 'O3P8_POST2_SHORT_ALIAS_JOB.json'='o3p8Job'; 'O3M9_SLOT16_JOB.json'='canonicalJob'; 'OCV03_NotchReviewOpenCvV1.py'='protocolAnchor'; 'O3F11FixtureRunner.py'='rehearsalRunner'; 'O3F11RootContractProbe.py'='rootContractProbe'
}
$files = New-Object Collections.Generic.List[object]
foreach ($name in $roleByName.Keys) {
    $record = @($manifest.files | Where-Object { [string]$_.path -eq ('payload/' + $name) })
    Assert-O3F11 ($record.Count -eq 1) "O3F11 role payload cardinality changed: $name"
    $files.Add([pscustomobject]@{role=[string]$roleByName[$name];path=$name;bytes=[int64]$record[0].bytes;sha256=[string]$record[0].sha256})
}
$liveRoles = @($liveInvocation.files.role | Sort-Object -Unique)
Assert-O3F11 ($liveRoles.Count -eq $files.Count) 'O3F11 extracted live invocation role cardinality changed.'
foreach ($fileRecord in $files.ToArray()) {
    $liveRecord = @($liveInvocation.files | Where-Object { [string]$_.role -eq [string]$fileRecord.role })
    Assert-O3F11 ($liveRecord.Count -eq 1 -and [string]$liveRecord[0].path -eq [string]$fileRecord.path -and [int64]$liveRecord[0].bytes -eq [int64]$fileRecord.bytes -and [string]$liveRecord[0].sha256 -eq [string]$fileRecord.sha256) "O3F11 extracted live invocation payload pin changed: $($fileRecord.role)"
}
$endpoint = Join-Path $payload 'Invoke-O3F11StagedEndpoint.ps1'
$invocationPath = Join-Path $fixtureRoot 'i.json'
$invocation = [ordered]@{schema='argos_ocv03_o3f11_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision='O3F11_EXACT_PACKAGE_PREFLIGHT';expectedComputerName=$env:COMPUTERNAME;payloadRoot=$payload;endpointSha256=Get-O3F11Hash $endpoint;files=$files.ToArray();runtimePath='';runtimeSha256='';rehearsalRuntimePath=$python;rehearsalRuntimeSha256=Get-O3F11Hash $python;gateOutputRoot=$gateRoot;dev6OutputRoot=$devRoot;realRunnerGateContractRoot=[string]$liveInvocation.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$liveInvocation.realRunnerDev6ContractRoot;expectedSelfTestState=[string]$liveInvocation.expectedSelfTestState;expectedPreflightState=[string]$liveInvocation.expectedPreflightState;expectedGateState=[string]$liveInvocation.expectedGateState;expectedDev6State=[string]$liveInvocation.expectedDev6State;selfTestTimeoutSeconds=[int]$liveInvocation.selfTestTimeoutSeconds;preflightTimeoutSeconds=[int]$liveInvocation.preflightTimeoutSeconds;rootContractTimeoutSeconds=[int]$liveInvocation.rootContractTimeoutSeconds;gateTimeoutSeconds=[int]$liveInvocation.gateTimeoutSeconds;dev6TimeoutSeconds=[int]$liveInvocation.dev6TimeoutSeconds;maximumChildOutputBytes=[int]$liveInvocation.maximumChildOutputBytes;maximumTerminalOutputBytes=[int]$liveInvocation.maximumTerminalOutputBytes;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-O3F11Json $invocationPath $invocation
$endpointPreflight = & $endpoint -Preflight -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json
Assert-O3F11 ([string]$endpointPreflight.state -eq 'PASS_O3F11_ENDPOINT_PREFLIGHT' -and -not [bool]$endpointPreflight.sourceImageBytesRead -and -not [bool]$endpointPreflight.outputCreated) 'O3F11 exact extracted endpoint preflight failed.'
$endpointRehearsal = & $endpoint -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json
$runnerRecord = @($files.ToArray() | Where-Object { [string]$_.role -eq 'runner' })
Assert-O3F11 ($runnerRecord.Count -eq 1) 'O3F11 exact extracted real runner role cardinality changed.'
Assert-O3F11 ([string]$endpointRehearsal.state -eq 'COMPLETE_O3F11_GATE_AND_DEV6_REVIEW_ONLY' -and [bool]$endpointRehearsal.rehearsal -and @($endpointRehearsal.dev6.cases).Count -eq 6 -and -not [bool]$endpointRehearsal.sourceImageBytesRead) 'O3F11 exact extracted endpoint image-free rehearsal failed.'
Assert-O3F11 ([string]$endpointRehearsal.selfTest.state -eq 'PASS_O3F9_STAGED_RUNNER_SELF_TEST' -and -not [bool]$endpointRehearsal.selfTest.mutationsPerformed -and [string]$endpointRehearsal.selfTest.runnerSha256 -eq [string]$runnerRecord[0].sha256) 'O3F11 exact extracted real SELF_TEST contract changed.'
Assert-O3F11 ([string]$endpointRehearsal.rootContract.state -eq 'PASS_O3F11_EXACT_REAL_RUNNER_ROOT_CONTRACT' -and [string]$endpointRehearsal.rootContract.gateRoot -eq 'D:/O3F9G11' -and [string]$endpointRehearsal.rootContract.dev6Root -eq 'D:/O3F9D11' -and [string]::Join('|', @($endpointRehearsal.rootContract.gateTerminalKeys)) -ceq 'commands|stage|state|summarySha256' -and [string]::Join('|', @($endpointRehearsal.rootContract.dev6TerminalKeys)) -ceq 'executedCount|newProviderHoldCount|results|selectedCount|stage|state|stateCounts|summarySha256' -and [bool]$endpointRehearsal.rootContract.simulatedFilesystem -and [bool]$endpointRehearsal.rootContract.incompatibleO3F11PrefixRejected -and -not [bool]$endpointRehearsal.rootContract.mutationsPerformed) 'O3F11 exact extracted real-runner root/schema contract changed.'
$record = [ordered]@{schema='argos_ocv03_o3f11_exact_package_rehearsal_gate_v1';state='PASS_O3F11_EXACT_PACKAGE_REHEARSAL';requestId=$requestId;requestZipSha256=$expectedZip;windowsPowerShell=@{major=[int]$PSVersionTable.PSVersion.Major;minor=[int]$PSVersionTable.PSVersion.Minor};exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=14;changeCount=1;allowCreateFalseCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;exactLiveInvocationSha256=Get-O3F11Hash $liveInvocationPath;exactLiveGateOutputRoot=[string]$liveInvocation.gateOutputRoot;exactLiveDev6OutputRoot=[string]$liveInvocation.dev6OutputRoot;exactLiveRunnerSha256=[string]$liveRunnerRecord[0].sha256;exactExtractedEndpointPreflightState=[string]$endpointPreflight.state;exactExtractedEndpointRehearsalState=[string]$endpointRehearsal.state;exactExtractedRealSelfTestState=[string]$endpointRehearsal.selfTest.state;exactExtractedRealRunnerSha256=[string]$endpointRehearsal.selfTest.runnerSha256;exactExtractedRootContractState=[string]$endpointRehearsal.rootContract.state;exactExtractedRootContractProbeSha256=Get-O3F11Hash (Join-Path $payload 'O3F11RootContractProbe.py');exactExtractedRootContractGateRoot=[string]$endpointRehearsal.rootContract.gateRoot;exactExtractedRootContractDev6Root=[string]$endpointRehearsal.rootContract.dev6Root;incompatibleO3F11PrefixRejected=[bool]$endpointRehearsal.rootContract.incompatibleO3F11PrefixRejected;exactExtractedFixtureDev6CaseCount=@($endpointRehearsal.dev6.cases).Count;exactExtractedEndpointSha256=Get-O3F11Hash $endpoint;protocolAnchorSha256=$anchorSha;protocolAnchorExpectedByteIdentical=$true;protocolAnchorExecutedByEntrypoint=$false;endpointWorkerSha256=Get-O3F11Hash $endpointWorker;inheritedQueueSafetyGateSha256=Get-O3F11Hash $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceMutationPerformed=$false;taskActionCount=0;existingProcessActionCount=0;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-O3F11Json $gatePath $record
$record | ConvertTo-Json -Depth 12
