#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of Preflight or Gate.' }
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { $s=[IO.File]::OpenRead($Path);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()} }
function Write-NewJson([string]$Path, [object]$Value) { Assert-True (-not (Test-Path -LiteralPath $Path)) "O3EI1 rehearsal refuses overwrite: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 12)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$zip = Join-Path $PSScriptRoot 'final_o3ei1\REQ_20260828T143500111Z_O3EI1R01.ready.zip'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$queueGate = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$endpointWorker = Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$python = 'C:\Python314\python.exe'
$installation = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3Q2\O3Q2_REHEARSAL_RUNTIME_GATE.json'
$fixtureRoot = 'C:\O3EI1P'
$gatePath = Join-Path $PSScriptRoot 'O3EI1_EXACT_PACKAGE_REHEARSAL_GATE.json'
$expectedZip = 'A0FC4A5885CDD6350113212FCB299302E2EB9E8C0AA860BAEC95094F64EC740D'
$providerSha = 'C4BCE3DBC9ABF91E99AE1E1DEB971EEB60610C2A117E645B5903EC4BAD744E8D'
$entrypointSha = 'B7453E74C1DF80DB4BAAA5F398870B6C5C99A71959EAD4C8F038B9A4B3812CAA'
$pythonSha = '4942B86A6597E5AEE0128DAA00050ED79BC21F6E709A78EB19CBFEB0C2F39AC9'
$installationSha = '0CE732749B6A9F07E930547689D85A68552A29382DBB9CA3018D7D6C9E75BC60'
foreach ($p in @($zip,$publicCertificate,$packageTester,$queueGate,$endpointWorker,$python,$installation)) { Assert-True (Test-Path -LiteralPath $p -PathType Leaf) "O3EI1 package-rehearsal dependency absent: $p" }
Assert-True ((Get-Sha256 $zip) -eq $expectedZip) 'O3EI1 exact final ZIP changed.'
Assert-True ((Get-Sha256 $queueGate) -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3EI1 inherited queue gate changed.'
Assert-True ((Get-Sha256 $endpointWorker) -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3EI1 endpoint worker changed.'
Assert-True ((Get-Sha256 $python) -eq $pythonSha -and (Get-Sha256 $installation) -eq $installationSha) 'O3EI1 local rehearsal runtime changed.'
Assert-True (-not (Test-Path -LiteralPath $fixtureRoot)) 'O3EI1 fresh rehearsal root exists.'
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O3EI1 rehearsal gate exists.'
$pathCheck = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @((Join-Path $fixtureRoot 'x\payload\Invoke-O3EI1RuntimeCapability.ps1'),(Join-Path $fixtureRoot 'create\OCV03_O3EI1_RUNTIME_STATUS.json'),(Join-Path $fixtureRoot 'timeout\OCV03_O3EI1_RUNTIME_STATUS.json'),$gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathCheck.state -eq 'PASS_PATH_BUDGET') 'O3EI1 package-rehearsal path gate failed.'

if ($Preflight) {
    [ordered]@{schema='argos_o3ei1_exact_package_rehearsal_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_EXACT_PACKAGE_REHEARSAL_PREFLIGHT';requestZipSha256=$expectedZip;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueGateSha256=Get-Sha256 $queueGate;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;childProcessStarted=$false;sourceImageBytesRead=$false;sourceHashingPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$extract = Join-Path $fixtureRoot 'x'
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip,$extract)
$packageTest = & $packageTester -PackagePath $extract -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3EI1 exact package signature failed.'
$manifest = Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
$entrypoint = Join-Path $extract 'payload\Invoke-O3EI1RuntimeCapability.ps1'
$provider = Join-Path $extract 'payload\Invoke-O3EI1RuntimeProbe.ps1'
Assert-True ([string]$manifest.requestId -eq 'REQ_20260828T143500111Z_O3EI1R01' -and @($manifest.files).Count -eq 2 -and @($manifest.changes).Count -eq 1) 'O3EI1 signed manifest identity changed.'
Assert-True ((Get-Sha256 $entrypoint) -eq $entrypointSha -and (Get-Sha256 $provider) -eq $providerSha) 'O3EI1 extracted payload hash changed.'
Assert-True ([string]$manifest.changes[0].source -eq 'payload/Invoke-O3EI1RuntimeProbe.ps1' -and [string]$manifest.changes[0].installedSha256 -eq $providerSha -and @($manifest.changes[0].approvedPredecessorSha256) -contains $providerSha -and [bool]$manifest.changes[0].allowCreate) 'O3EI1 predecessor declaration changed.'
Assert-True (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 2 -and @($manifest.allowedProcessActions) -contains 'START_OWNED_BOUNDED_D_AFCV1_RUNTIME_QUERY' -and @($manifest.allowedProcessActions) -contains 'TERMINATE_ONLY_OWNED_RUNTIME_QUERY_ON_TIMEOUT') 'O3EI1 process action declaration changed.'

function Invoke-Case([string]$Name,[string]$ProbeMode,[bool]$FailAfterProvider) {
    $processor = Join-Path $fixtureRoot $Name
    [void](New-Item -ItemType Directory -Path $processor)
    $installed = Join-Path $processor 'Invoke-O3EI1RuntimeProbe.ps1'
    Copy-Item -LiteralPath $provider -Destination $installed
    Assert-True ((Get-Sha256 $installed) -eq $providerSha) "O3EI1 $Name installed provider changed."
    $providerInvocationPath = Join-Path $fixtureRoot ($Name + '.provider.json')
    $timeout = if ($ProbeMode -eq 'TIMEOUT') { 1000 } else { 3000 }
    Write-NewJson $providerInvocationPath ([ordered]@{schema='argos_o3ei1_runtime_probe_invocation_v1';pythonPath=$python;installationPath=$installation;expectedPythonSha256=$pythonSha;expectedInstallationSha256=$installationSha;expectedOpenCvVersion='5.0.0';expectedNumpyVersion='2.5.1';timeoutMilliseconds=$timeout;probeMode=$ProbeMode})
    $entryInvocationPath = Join-Path $fixtureRoot ($Name + '.entry.json')
    Write-NewJson $entryInvocationPath ([ordered]@{schema='argos_o3ei1_entrypoint_invocation_v1';processorRoot=$processor;providerPath=$installed;providerInvocation=$providerInvocationPath;expectedProviderSha256=$providerSha;failAfterProvider=$FailAfterProvider})
    if ($FailAfterProvider) { $captured=$false;try{& $entrypoint -Rehearsal -InvocationManifest $entryInvocationPath 2>&1|Out-Null}catch{$captured=[string]$_.Exception.Message-match'INJECTED_O3EI1_ENTRYPOINT_FAILURE_AFTER_PROVIDER'};Assert-True $captured 'O3EI1 injected rollback case did not fail as planned.';Assert-True (-not (Test-Path -LiteralPath (Join-Path $processor 'OCV03_O3EI1_RUNTIME_STATUS.json'))) 'O3EI1 injected failure wrote output.';return $null }
    $result = (& $entrypoint -Rehearsal -InvocationManifest $entryInvocationPath | Out-String) | ConvertFrom-Json
    Assert-True ([string]$result.state -eq 'PASS_O3EI1_RUNTIME_CAPABILITY') "O3EI1 $Name capability case failed."
    return $result
}
$create = Invoke-Case 'create' 'FIXED' $false
Assert-True ([string]$create.disposition -eq 'PASS_O3EI1_RUNTIME_PREMISE' -and [bool]$create.runtimePremisePass) 'O3EI1 create case version evidence failed.'
$target = Invoke-Case 'target' 'FIXED' $false
Assert-True ([string]$target.disposition -eq 'PASS_O3EI1_RUNTIME_PREMISE') 'O3EI1 target-hash idempotent case failed.'
$timeoutResult = Invoke-Case 'timeout' 'TIMEOUT' $false
Assert-True ([string]$timeoutResult.disposition -eq 'HOLD_O3EI1_RUNTIME_TIMEOUT' -and [bool]$timeoutResult.probe.child.killedOnTimeout) 'O3EI1 timeout case failed.'
$unapproved = Join-Path $fixtureRoot 'unapproved\Invoke-O3EI1RuntimeProbe.ps1'
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $unapproved))
[IO.File]::WriteAllText($unapproved,'unapproved',(New-Object Text.UTF8Encoding($false)))
$unapprovedBefore = Get-Sha256 $unapproved
Assert-True (@($manifest.changes[0].approvedPredecessorSha256) -notcontains $unapprovedBefore) 'O3EI1 unapproved control accidentally approved.'
Assert-True ((Get-Sha256 $unapproved) -eq $unapprovedBefore) 'O3EI1 unapproved predecessor changed.'
[void](Invoke-Case 'rollback' 'FIXED' $true)

$record = [ordered]@{schema='argos_o3ei1_exact_package_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_EXACT_PACKAGE_REHEARSAL';requestId=[string]$manifest.requestId;requestZipSha256=$expectedZip;exactSignedZipExtracted=$true;signatureVerified=$true;payloadHashCount=2;createCasePassed=$true;targetHashIdempotentCasePassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;postProviderFailureCaptured=$true;postProviderFailureOutputAbsent=$true;timeoutIsolationCasePassed=$true;timeoutOwnedChildKilled=$true;endpointWorkerSha256=Get-Sha256 $endpointWorker;inheritedQueueSafetyGateSha256=Get-Sha256 $queueGate;exactEndpointQueueRollbackRehearsalInherited=$true;fixtureRoot=$fixtureRoot;fixturePreserved=$true;sourceImageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;taskActions=0;existingProcessActions=0;ownedChildProcessActions=4;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record | ConvertTo-Json -Depth 8
