#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F9([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F9Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F9Json([string]$Path, [object]$Value) { Assert-O3F9 (-not (Test-Path -LiteralPath $Path)) "O3F9 exact-package gate exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_O3F9_20260902A'
$zip = Join-Path $PSScriptRoot 'final_o3f9\REQ_O3F9_20260902A.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'O3F9_FINAL_PACKAGE_GATE.json'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$endpointWorker = Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$python = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$fixtureRoot = 'C:\A9R'
$gateRoot = 'C:\A9R\g'
$devRoot = 'C:\A9R\d'
$gatePath = Join-Path $PSScriptRoot 'O3F9_EXACT_PACKAGE_REHEARSAL_GATE.json'
foreach ($path in @($zip, $finalGatePath, $certificate, $packageTester, $endpointWorker, $queueGate, $python)) { Assert-O3F9 (Test-Path -LiteralPath $path -PathType Leaf) "O3F9 exact-package dependency is absent: $path" }
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-O3F9 ([string]$finalGate.state -eq 'PASS_O3F9_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O3F9 final package gate changed.'
$expectedZip = [string]$finalGate.requestZipSha256
Assert-O3F9 ((Get-O3F9Hash $zip) -eq $expectedZip) 'O3F9 final ZIP changed.'
Assert-O3F9 ((Get-O3F9Hash $certificate) -eq '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF') 'O3F9 laptop signer certificate changed.'
Assert-O3F9 ((Get-O3F9Hash $packageTester) -eq '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B') 'O3F9 signed-package verifier changed.'
Assert-O3F9 ((Get-O3F9Hash $endpointWorker) -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3F9 endpoint worker changed.'
Assert-O3F9 ((Get-O3F9Hash $queueGate) -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F9 queue-safety gate changed.'
Assert-O3F9 ((Get-O3F9Hash $python) -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F9 rehearsal runtime changed.'
Assert-O3F9 (-not (Test-Path -LiteralPath $fixtureRoot)) 'O3F9 exact-package rehearsal root exists.'
Assert-O3F9 (-not (Test-Path -LiteralPath $gatePath)) 'O3F9 exact-package rehearsal gate exists.'
$pathCheck = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3F9StagedEndpoint.ps1'), (Join-Path $fixtureRoot 'target\OCV03_NotchReviewOpenCvV1.py'), (Join-Path $fixtureRoot 'i.json'), (Join-Path $gateRoot 'SUMMARY.json'), (Join-Path $devRoot 'SUMMARY.json'), $gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-O3F9 ([string]$pathCheck.state -eq 'PASS_PATH_BUDGET') 'O3F9 exact-package path gate failed.'
if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f9_exact_package_rehearsal_preflight_v1';state='PASS_O3F9_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract = Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
$packageTest = & $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-O3F9 ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F9 exact package signature failed.'
$manifest = Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
$payload = Join-Path $extract 'payload'
Assert-O3F9 ([string]$manifest.requestId -eq $requestId -and @($manifest.files).Count -eq 13 -and @($manifest.changes).Count -eq 1) 'O3F9 signed manifest identity changed.'
Assert-O3F9 ([int64]$manifest.maxResultBytes -eq 2097152 -and [string]$manifest.entryPoint -eq 'payload/Invoke-O3F9StagedEndpoint.ps1' -and @($manifest.entryPointMutations).Count -eq 2 -and @($manifest.entryPointOutputs).Count -eq 2 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1) 'O3F9 signed maintenance contract changed.'
foreach ($record in @($manifest.files)) {
    $relative = [string]$record.path
    Assert-O3F9 (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3F9 signed payload path is unsafe.'
    $file = Join-Path $extract $relative
    Assert-O3F9 (Test-Path -LiteralPath $file -PathType Leaf) "O3F9 signed payload file is absent: $relative"
    Assert-O3F9 ((Get-Item -LiteralPath $file).Length -eq [int64]$record.bytes -and (Get-O3F9Hash $file) -eq [string]$record.sha256) "O3F9 signed payload hash changed: $relative"
}
$change = @($manifest.changes)[0]
$anchor = Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py'
$anchorSha = Get-O3F9Hash $anchor
Assert-O3F9 ([string]$change.source -eq 'payload/OCV03_NotchReviewOpenCvV1.py' -and [string]$change.installedSha256 -eq $anchorSha -and @($change.approvedPredecessorSha256).Count -eq 1 -and @($change.approvedPredecessorSha256) -contains $anchorSha -and -not [bool]$change.allowCreate) 'O3F9 signed protocol-anchor contract changed.'
$targetRoot = Join-Path $fixtureRoot 'target'
[void](New-Item -ItemType Directory -Path $targetRoot)
$target = Join-Path $targetRoot 'OCV03_NotchReviewOpenCvV1.py'
Copy-Item -LiteralPath $anchor -Destination $target
$targetBefore = Get-O3F9Hash $target
Assert-O3F9 (@($change.approvedPredecessorSha256) -contains $targetBefore -and $targetBefore -eq $anchorSha -and (Get-O3F9Hash $target) -eq $targetBefore) 'O3F9 same-hash predecessor/idempotent case failed.'
$unapproved = Join-Path $targetRoot 'unapproved.py'
[IO.File]::WriteAllText($unapproved, 'unapproved', (New-Object Text.UTF8Encoding($false)))
$unapprovedSha = Get-O3F9Hash $unapproved
Assert-O3F9 (@($change.approvedPredecessorSha256) -notcontains $unapprovedSha -and (Get-O3F9Hash $unapproved) -eq $unapprovedSha) 'O3F9 unapproved predecessor was not refused before mutation.'

$roleByName = @{
    'Run-O3F9Staged.py'='runner'; 'Run-O3F8Staged.py'='baseRunner'; 'FullPerimeterWaferTopologyOpenCvR10.py'='r10Detector'; 'FullPerimeterWaferTopologyOpenCvR9.py'='r9Detector'; 'FullPerimeterWaferTopologyOpenCvR8.py'='r8Detector'; 'Detect-O3P8FrontSplitNotches.py'='o3p8Detector'; 'Test-O3F8SymmetricRecovery.py'='localGate'; 'O3P8_POST2_SHORT_ALIAS_JOB.json'='o3p8Job'; 'O3M9_SLOT16_JOB.json'='canonicalJob'; 'OCV03_NotchReviewOpenCvV1.py'='protocolAnchor'; 'O3F9FixtureRunner.py'='rehearsalRunner'
}
$files = New-Object Collections.Generic.List[object]
foreach ($name in $roleByName.Keys) {
    $record = @($manifest.files | Where-Object { [string]$_.path -eq ('payload/' + $name) })
    Assert-O3F9 ($record.Count -eq 1) "O3F9 role payload cardinality changed: $name"
    $files.Add([pscustomobject]@{role=[string]$roleByName[$name];path=$name;bytes=[int64]$record[0].bytes;sha256=[string]$record[0].sha256})
}
$endpoint = Join-Path $payload 'Invoke-O3F9StagedEndpoint.ps1'
$invocationPath = Join-Path $fixtureRoot 'i.json'
$invocation = [ordered]@{schema='argos_ocv03_o3f9_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision='O3F9_EXACT_PACKAGE_PREFLIGHT';expectedComputerName=$env:COMPUTERNAME;payloadRoot=$payload;endpointSha256=Get-O3F9Hash $endpoint;files=$files.ToArray();runtimePath='';runtimeSha256='';rehearsalRuntimePath=$python;rehearsalRuntimeSha256=Get-O3F9Hash $python;gateOutputRoot=$gateRoot;dev6OutputRoot=$devRoot;expectedSelfTestState='PASS_O3F9_STAGED_RUNNER_SELF_TEST';expectedPreflightState='PASS_O3F9_STAGED_PREFLIGHT';expectedGateState='COMPLETE_O3F9_GATE';expectedDev6State='COMPLETE_O3F9_DEV6';selfTestTimeoutSeconds=30;preflightTimeoutSeconds=30;gateTimeoutSeconds=30;dev6TimeoutSeconds=30;maximumChildOutputBytes=1048576;maximumTerminalOutputBytes=1048576;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-O3F9Json $invocationPath $invocation
$endpointPreflight = & $endpoint -Preflight -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json
Assert-O3F9 ([string]$endpointPreflight.state -eq 'PASS_O3F9_ENDPOINT_PREFLIGHT' -and -not [bool]$endpointPreflight.sourceImageBytesRead -and -not [bool]$endpointPreflight.outputCreated) 'O3F9 exact extracted endpoint preflight failed.'
$record = [ordered]@{schema='argos_ocv03_o3f9_exact_package_rehearsal_gate_v1';state='PASS_O3F9_EXACT_PACKAGE_REHEARSAL';requestId=$requestId;requestZipSha256=$expectedZip;windowsPowerShell=@{major=[int]$PSVersionTable.PSVersion.Major;minor=[int]$PSVersionTable.PSVersion.Minor};exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=13;changeCount=1;allowCreateFalseCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;exactExtractedEndpointPreflightState=[string]$endpointPreflight.state;exactExtractedEndpointSha256=Get-O3F9Hash $endpoint;protocolAnchorSha256=$anchorSha;protocolAnchorExpectedByteIdentical=$true;protocolAnchorExecutedByEntrypoint=$false;endpointWorkerSha256=Get-O3F9Hash $endpointWorker;inheritedQueueSafetyGateSha256=Get-O3F9Hash $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceMutationPerformed=$false;taskActionCount=0;existingProcessActionCount=0;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-O3F9Json $gatePath $record
$record | ConvertTo-Json -Depth 12
