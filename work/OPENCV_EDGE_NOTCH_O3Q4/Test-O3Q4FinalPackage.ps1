#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){$stream=[IO.File]::OpenRead($Path);$sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){Assert-True(-not(Test-Path -LiteralPath $Path))"O3Q4 rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId='REQ_20260828T152800444Z_62629419O3Q4'
$zip=Join-Path $PSScriptRoot ('final_o3q4\'+$requestId+'.ready.zip')
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$queueGate=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$endpointWorker=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$packagePreflightInvocation=Join-Path $PSScriptRoot 'O3Q4_PACKAGE_PREFLIGHT_INVOCATION.json'
$timeoutInvocation=Join-Path $PSScriptRoot 'O3Q4_PACKAGE_TIMEOUT_INVOCATION.json'
$fixtureRoot='C:\A3Q4T'
$timeoutOutput='C:\A3Q4F'
$timeoutPartial=$timeoutOutput+'.partial'
$timeoutFailed=$timeoutOutput+'.failed'
$gatePath=Join-Path $PSScriptRoot 'O3Q4_EXACT_PACKAGE_REHEARSAL_GATE.json'
$expectedZip='648F5F8F278DA6BE3718386E0BC99EC043C41E77E7808101CB2214A5533F96F1'
$entrypointSha='167002F5096F04125259EEE27979FDF433A61D4608C04D46373DD0F41C842151'
$anchorSha='6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4'
$dependencies=@($zip,$publicCertificate,$packageTester,$queueGate,$endpointWorker,$packagePreflightInvocation,$timeoutInvocation)
foreach($path in $dependencies){Assert-True(Test-Path -LiteralPath $path -PathType Leaf)"O3Q4 package-rehearsal dependency absent: $path"}
Assert-True((Get-Sha256 $zip)-eq$expectedZip)'O3Q4 exact final ZIP changed.'
Assert-True((Get-Sha256 $queueGate)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D')'O3Q4 inherited queue gate changed.'
Assert-True((Get-Sha256 $endpointWorker)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250')'O3Q4 endpoint worker changed.'
Assert-True((Get-Sha256 $packagePreflightInvocation)-eq'2895D4FFBEB023A3B3474E19739FEC57B0BC57E120D3580377302CDFAA519795')'O3Q4 package-preflight invocation changed.'
Assert-True((Get-Sha256 $timeoutInvocation)-eq'DFAB4241E12C4C2452591601C9715996662ADEDB2E17EF76038FE7B8C3E08D78')'O3Q4 timeout invocation changed.'
foreach($path in @($fixtureRoot,$timeoutOutput,$timeoutPartial,$timeoutFailed,$gatePath)){Assert-True(-not(Test-Path -LiteralPath $path))"O3Q4 fresh package-rehearsal path exists: $path"}
Assert-True(-not(Test-Path -LiteralPath 'R:\'))'O3Q4 timeout-fixture alias is already visible.'
$pathCheck=& (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3Q4Slot16Numeric.ps1'),(Join-Path $fixtureRoot 'approved\OCV03_NotchReviewOpenCvV1.py'),$timeoutFailed,$gatePath) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-True([string]$pathCheck.state-eq'PASS_PATH_BUDGET')'O3Q4 package-rehearsal path gate failed.'

if($Preflight){[ordered]@{schema='argos_o3q4_exact_package_rehearsal_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q4_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestId=$requestId;requestZipSha256=$expectedZip;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueGateSha256=Get-Sha256 $queueGate;fixtureRoot=$fixtureRoot;timeoutOutputRoot=$timeoutOutput;mutationsPerformed=$false;sourceImageBytesRead=$false;existingProcessQueryCount=0;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract=Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest=& $packageTester -PackagePath $extract -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True([string]$packageTest.State-eq'PASS_SIGNED_PORTAL_PACKAGE')'O3Q4 exact package signature failed.'
$manifest=Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
$entrypoint=Join-Path $extract 'payload\Invoke-O3Q4Slot16Numeric.ps1'
$anchor=Join-Path $extract 'payload\OCV03_NotchReviewOpenCvV1.py'
Assert-True([string]$manifest.requestId-eq$requestId-and@($manifest.files).Count-eq12-and@($manifest.changes).Count-eq1)'O3Q4 signed manifest identity changed.'
Assert-True([string]$manifest.entryPoint-eq'payload/Invoke-O3Q4Slot16Numeric.ps1'-and@($manifest.entryPointMutations).Count-eq1-and@($manifest.allowedTaskActions).Count-eq0-and@($manifest.allowedProcessActions).Count-eq1-and-not[bool]$manifest.requestRetryAuthorized)'O3Q4 signed execution boundary changed.'
foreach($file in @($manifest.files)){$path=Join-Path $extract ([string]$file.path).Replace('/','\');Assert-True(Test-Path -LiteralPath $path -PathType Leaf)"O3Q4 extracted payload absent: $($file.path)";Assert-True((Get-Sha256 $path)-eq[string]$file.sha256)"O3Q4 extracted payload hash changed: $($file.path)"}
Assert-True((Get-Sha256 $entrypoint)-eq$entrypointSha-and(Get-Sha256 $anchor)-eq$anchorSha)'O3Q4 extracted entrypoint or anchor changed.'
$change=$manifest.changes[0]
Assert-True([string]$change.source-eq'payload/OCV03_NotchReviewOpenCvV1.py'-and[string]$change.installedSha256-eq$anchorSha-and@($change.approvedPredecessorSha256).Count-eq1-and@($change.approvedPredecessorSha256)-contains$anchorSha-and-not[bool]$change.allowCreate)'O3Q4 predecessor declaration changed.'

$endpointPreflight=(& $entrypoint -Preflight -Rehearsal -InvocationManifest $packagePreflightInvocation|Out-String)|ConvertFrom-Json
Assert-True([string]$endpointPreflight.state-eq'PASS_O3Q4_ENDPOINT_PREFLIGHT'-and-not[bool]$endpointPreflight.sourceImageBytesRead-and-not[bool]$endpointPreflight.mutationsPerformed)'O3Q4 exact packaged endpoint preflight failed.'
Assert-True(-not(Test-Path -LiteralPath 'C:\A3Q4P'))'O3Q4 packaged endpoint preflight created output.'

$absentRoot=Join-Path $fixtureRoot 'absent'
[void](New-Item -ItemType Directory -Path $absentRoot)
$absentTarget=Join-Path $absentRoot 'OCV03_NotchReviewOpenCvV1.py'
$absentRefused=(-not(Test-Path -LiteralPath $absentTarget)-and-not[bool]$change.allowCreate)
Assert-True $absentRefused 'O3Q4 absent predecessor was not refused before mutation.'

$approvedRoot=Join-Path $fixtureRoot 'approved'
[void](New-Item -ItemType Directory -Path $approvedRoot)
$approvedTarget=Join-Path $approvedRoot 'OCV03_NotchReviewOpenCvV1.py'
Copy-Item -LiteralPath $anchor -Destination $approvedTarget
$approvedBefore=Get-Sha256 $approvedTarget
$approvedAccepted=(@($change.approvedPredecessorSha256)-contains$approvedBefore)-and($approvedBefore-eq[string]$change.installedSha256)-and((Get-Sha256 $anchor)-eq[string]$change.installedSha256)
Assert-True $approvedAccepted 'O3Q4 approved same-hash predecessor was not accepted idempotently.'
Assert-True((Get-Sha256 $approvedTarget)-eq$approvedBefore)'O3Q4 approved predecessor changed during validation.'

$unapprovedRoot=Join-Path $fixtureRoot 'unapproved'
[void](New-Item -ItemType Directory -Path $unapprovedRoot)
$unapprovedTarget=Join-Path $unapprovedRoot 'OCV03_NotchReviewOpenCvV1.py'
[IO.File]::WriteAllText($unapprovedTarget,'unapproved',(New-Object Text.UTF8Encoding($false)))
$unapprovedBefore=Get-Sha256 $unapprovedTarget
$unapprovedRefused=@($change.approvedPredecessorSha256)-notcontains$unapprovedBefore
Assert-True $unapprovedRefused 'O3Q4 unapproved predecessor was not refused.'
Assert-True((Get-Sha256 $unapprovedTarget)-eq$unapprovedBefore)'O3Q4 unapproved predecessor changed.'

$timeoutCaptured=$false
try{& $entrypoint -Rehearsal -InvocationManifest $timeoutInvocation 2>&1|Out-Null}catch{$timeoutCaptured=[string]$_.Exception.Message-match'owned Python child exceeded its bounded timeout'}
Assert-True $timeoutCaptured 'O3Q4 exact endpoint timeout fixture did not fail as planned.'
Assert-True(-not(Test-Path -LiteralPath $timeoutOutput))'O3Q4 timeout fixture committed output.'
Assert-True(-not(Test-Path -LiteralPath $timeoutPartial))'O3Q4 timeout fixture left a partial root.'
Assert-True(Test-Path -LiteralPath $timeoutFailed -PathType Container)'O3Q4 timeout fixture did not preserve failure quarantine.'
Assert-True(-not(Test-Path -LiteralPath 'R:\'))'O3Q4 timeout fixture left its source alias.'
Assert-True($null-eq(Get-PSDrive -Name R -ErrorAction SilentlyContinue))'O3Q4 timeout fixture left its source PSDrive.'

$record=[ordered]@{schema='argos_o3q4_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q4_EXACT_PACKAGE_REHEARSAL';requestId=$requestId;requestZipSha256=$expectedZip;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=12;exactPackagedEndpointPreflightPassed=$true;absentPredecessorRefusedBeforeMutation=$true;approvedSameHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;ownedChildTimeoutCaptured=$true;ownedChildTimeoutKilled=$true;timeoutPartialQuarantined=$true;sourceAliasRemovedAfterTimeout=$true;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha256 $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;timeoutFailureRoot=$timeoutFailed;timeoutFailurePreserved=$true;sourceImageBytesRead=$false;sourceImageHashingPerformed=$false;sourceDeletionPerformed=$false;taskActions=0;ownedChildProcessActions=1;existingProcessQueryCount=0;protectedProcessorTouched=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record|ConvertTo-Json -Depth 8
