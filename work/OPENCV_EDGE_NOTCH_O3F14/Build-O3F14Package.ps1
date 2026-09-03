#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }
function Assert-O3F14([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F14Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F14Json([string]$Path, [object]$Value) { Assert-O3F14 (-not (Test-Path -LiteralPath $Path)) "O3F14 create-new JSON exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F14_PACKAGE_SPEC.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$endpointRehearsalGatePath = Join-Path $PSScriptRoot 'O3F14_ENDPOINT_REHEARSAL_GATE.json'
foreach ($path in @($specPath, $definitionPath, $endpointRehearsalGatePath)) { Assert-O3F14 (Test-Path -LiteralPath $path -PathType Leaf) "O3F14 package dependency is absent: $path" }
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$endpointRehearsalGate = Get-Content -LiteralPath $endpointRehearsalGatePath -Raw | ConvertFrom-Json
Assert-O3F14 (((Get-Content -LiteralPath $specPath -Raw) + (Get-Content -LiteralPath $definitionPath -Raw)) -notmatch '__PENDING_O3F14_[A-Z0-9_]+__') 'O3F14 scaffold placeholders remain unresolved.'
Assert-O3F14 ([string]$spec.schema -eq 'argos_ocv03_o3f14_package_spec_v1' -and [string]$spec.requestId -eq 'REQ_O3F14_20260902A') 'O3F14 package identity changed.'
Assert-O3F14 ([string]$definition.entryPoint -eq [string]$spec.entryPoint -and @($definition.changes).Count -eq 1 -and @($definition.allowedTaskActions).Count -eq 0) 'O3F14 maintenance contract changed.'
Assert-O3F14 ([bool]$spec.reviewOnly -and -not [bool]$spec.productionRoutingEnabled -and -not [bool]$spec.requestRetryAuthorized) 'O3F14 package authority widened.'
Assert-O3F14 ([string]$spec.expectedDev6PassState -ceq 'COMPLETE_O3F14_DEV6' -and [string]$spec.expectedDev6HoldState -ceq 'HOLD_O3F14_DEV6_EXECUTION') 'O3F14 exact DEV6 pass/hold states changed.'
$expectedGateContractRoot = 'D:/O3F9G14'
$expectedDev6ContractRoot = 'D:/O3F9D14'
Assert-O3F14 ([string]$spec.gateOutputRoot -eq $expectedGateContractRoot -and [string]$spec.realRunnerGateContractRoot -eq $expectedGateContractRoot) 'O3F14 package GATE/live runner-root contract is not exact.'
Assert-O3F14 ([string]$spec.dev6OutputRoot -eq $expectedDev6ContractRoot -and [string]$spec.realRunnerDev6ContractRoot -eq $expectedDev6ContractRoot) 'O3F14 package DEV6/live runner-root contract is not exact.'
Assert-O3F14 (@($definition.entryPointMutations).Count -eq 2 -and @($definition.entryPointMutations.targetRoot) -contains $expectedGateContractRoot -and @($definition.entryPointMutations.targetRoot) -contains $expectedDev6ContractRoot) 'O3F14 maintenance mutation roots differ from the runner-root contract.'
Assert-O3F14 (@($definition.entryPointOutputs).Count -eq 2 -and @($definition.entryPointOutputs.path) -contains ($expectedGateContractRoot + '/SUMMARY.json') -and @($definition.entryPointOutputs.path) -contains ($expectedDev6ContractRoot + '/SUMMARY.json')) 'O3F14 maintenance output roots differ from the runner-root contract.'
$gateOutput = @($definition.entryPointOutputs | Where-Object { [string]$_.path -eq ($expectedGateContractRoot + '/SUMMARY.json') })
$dev6Output = @($definition.entryPointOutputs | Where-Object { [string]$_.path -eq ($expectedDev6ContractRoot + '/SUMMARY.json') })
Assert-O3F14 ($gateOutput.Count -eq 1 -and [string]$gateOutput[0].requiredState -ceq 'COMPLETE_O3F14_GATE') 'O3F14 GATE output state contract changed.'
Assert-O3F14 ($dev6Output.Count -eq 1 -and $null -eq $dev6Output[0].PSObject.Properties['requiredState'] -and [string]::Join('|', @($dev6Output[0].requiredStates)) -ceq 'COMPLETE_O3F14_DEV6|HOLD_O3F14_DEV6_EXECUTION') 'O3F14 DEV6 output accepted-state set changed.'
$dev6Pairs = @($definition.sourceProcessingContract.dev6AcceptedExitStatePairs)
Assert-O3F14 ($dev6Pairs.Count -eq 2 -and [int]$dev6Pairs[0].exitCode -eq 0 -and [string]$dev6Pairs[0].state -ceq 'COMPLETE_O3F14_DEV6' -and [int]$dev6Pairs[1].exitCode -eq 2 -and [string]$dev6Pairs[1].state -ceq 'HOLD_O3F14_DEV6_EXECUTION') 'O3F14 DEV6 exit/state pair contract changed.'
Assert-O3F14 ([string]$endpointRehearsalGate.state -eq 'PASS_O3F14_EXACT_ENTRYPOINT_REHEARSAL' -and [string]$endpointRehearsalGate.packageSpecRevision -eq [string]$spec.revision -and [string]$endpointRehearsalGate.packageSpecRequestId -eq [string]$spec.requestId -and [string]$endpointRehearsalGate.packageSpecRunnerSha256 -eq [string]$spec.runnerSha256) 'O3F14 endpoint rehearsal is not bound to the package identity and frozen runner.'
Assert-O3F14 ([string]$endpointRehearsalGate.packageSpecGateOutputRoot -eq $expectedGateContractRoot -and [string]$endpointRehearsalGate.packageSpecDev6OutputRoot -eq $expectedDev6ContractRoot -and [string]$endpointRehearsalGate.realRunnerGateContractRoot -eq $expectedGateContractRoot -and [string]$endpointRehearsalGate.realRunnerDev6ContractRoot -eq $expectedDev6ContractRoot -and [bool]$endpointRehearsalGate.incompatibleO3F14PrefixRejected) 'O3F14 endpoint rehearsal did not prove the exact live runner roots.'
Assert-O3F14 ([string]::Join('|', @($endpointRehearsalGate.realRunnerGateTerminalKeys)) -ceq 'commands|stage|state|summarySha256' -and [string]::Join('|', @($endpointRehearsalGate.realRunnerDev6TerminalKeys)) -ceq 'aliasEvidence|executedCount|newProviderHoldCount|results|selectedCount|stage|state|stateCounts|summarySha256') 'O3F14 endpoint rehearsal did not prove the exact real-runner terminal schemas.'
Assert-O3F14 ([string]$endpointRehearsalGate.sourceAliasPlanSha256 -eq [string]$spec.sourceAliasPlanSha256 -and [string]$endpointRehearsalGate.substSha256 -eq [string]$spec.substSha256 -and [bool]$endpointRehearsalGate.timeoutAliasCleanupBackstopPassed -and [bool]$endpointRehearsalGate.preoccupiedAliasRefusedAndPreserved -and [bool]$endpointRehearsalGate.qAbsentAfterRehearsal) 'O3F14 endpoint rehearsal did not prove the full source-alias lifecycle.'
$fixtureSource = Join-Path $PSScriptRoot 'O3F14FixtureRunner.py'
$rootProbeSource = Join-Path $PSScriptRoot 'O3F14RootContractProbe.py'
$rootProbeSpecRows = @($spec.payloadSources | Where-Object { [string]$_.role -eq 'rootContractProbe' })
Assert-O3F14 ($rootProbeSpecRows.Count -eq 1 -and [string]$rootProbeSpecRows[0].sha256 -eq (Get-O3F14Hash $rootProbeSource)) 'O3F14 root-probe spec pin changed.'
Assert-O3F14 ([string]$endpointRehearsalGate.endpointSha256 -eq (Get-O3F14Hash (Join-Path $project ([string]$spec.endpointSource)))) 'O3F14 endpoint bytes changed after rehearsal.'
Assert-O3F14 ([string]$endpointRehearsalGate.fixtureRunnerSha256 -eq (Get-O3F14Hash $fixtureSource)) 'O3F14 fixture bytes changed after rehearsal.'
Assert-O3F14 ([string]$endpointRehearsalGate.rootContractProbeSha256 -eq (Get-O3F14Hash $rootProbeSource)) 'O3F14 root probe bytes changed after rehearsal.'
Assert-O3F14 ([string]$endpointRehearsalGate.realRunnerSha256 -eq [string]$spec.runnerSha256 -and [string]$spec.runnerSha256 -eq (Get-O3F14Hash (Join-Path $project ([string]$spec.runnerSource)))) 'O3F14 real runner bytes changed after rehearsal.'
Assert-O3F14 ([string]$definition.rehearsal.requiredState -eq 'COMPLETE_O3F14_GATE_AND_DEV6_RESULTS_RETURNED_REVIEW_ONLY' -and [string]$definition.rehearsal.gateState -eq 'PASS_O3F14_EXACT_ENTRYPOINT_REHEARSAL' -and [string]$definition.rehearsal.gateSha256 -eq (Get-O3F14Hash $endpointRehearsalGatePath)) 'O3F14 maintenance definition does not pin the exact rehearsal gate.'
Assert-O3F14 ([string]::Join('|', @($definition.sourceProcessingContract.stages)) -ceq 'SELF_TEST|PREFLIGHT|ROOT_CONTRACT|GATE|DEV6') 'O3F14 maintenance stage sequence changed.'
Assert-O3F14 (@($definition.allowedProcessActions).Count -eq 2 -and @($definition.allowedProcessActions) -contains 'START_FIVE_SEQUENTIAL_BOUNDED_OWNED_O3F14_CHILDREN_ONLY' -and @($definition.allowedProcessActions) -contains 'CREATE_QUERY_VERIFY_REMOVE_TEMPORARY_Q_SOURCE_ALIAS_PER_DEV6_CASE_WITH_ENDPOINT_TIMEOUT_CLEANUP_BACKSTOP') 'O3F14 maintenance owned-child/alias authority changed.'

$sourceRows = New-Object Collections.Generic.List[object]
$endpointSource = Join-Path $project ([string]$spec.endpointSource)
$runnerSource = Join-Path $project ([string]$spec.runnerSource)
$candidateRows = @(
    [pscustomobject]@{role='endpoint';source=$endpointSource;path='Invoke-O3F14StagedEndpoint.ps1';expected=''},
    [pscustomobject]@{role='runner';source=$runnerSource;path='Run-O3F14Staged.py';expected=[string]$spec.runnerSha256}
)
foreach ($row in @($spec.payloadSources)) {
    $expected = ''
    if ($null -ne $row.PSObject.Properties['sha256']) { $expected = [string]$row.sha256 }
    $candidateRows += [pscustomobject]@{role=[string]$row.role;source=(Join-Path $project ([string]$row.source));path=[string]$row.path;expected=$expected}
}
foreach ($row in $candidateRows) {
    Assert-O3F14 (Test-Path -LiteralPath $row.source -PathType Leaf) "O3F14 payload source is absent: $($row.source)"
    $hash = Get-O3F14Hash $row.source
    if (-not [string]::IsNullOrWhiteSpace([string]$row.expected)) { Assert-O3F14 ($hash -eq [string]$row.expected) "O3F14 inherited payload hash changed: $($row.source)" }
    $sourceRows.Add([pscustomobject]@{role=[string]$row.role;source=[string]$row.source;path=[string]$row.path;bytes=[int64](Get-Item -LiteralPath $row.source).Length;sha256=$hash})
}
$sources = $sourceRows.ToArray()
Assert-O3F14 ($sources.Count -eq 15 -and @($sources.role | Sort-Object -Unique).Count -eq 15 -and @($sources.path | Sort-Object -Unique).Count -eq 15) 'O3F14 payload source cardinality changed.'

$stageRoot = [IO.Path]::GetFullPath([string]$spec.stageRoot)
Assert-O3F14 ($stageRoot -eq 'C:\A14F') 'O3F14 staging root changed.'
$payloadRoot = Join-Path $stageRoot 'p'
$requestPartial = Join-Path $stageRoot (([string]$spec.requestId) + '.partial')
$requestReady = Join-Path $stageRoot ([string]$spec.requestReadyName)
$finalRoot = Join-Path $project ([string]$spec.finalRoot)
$finalZip = Join-Path $finalRoot (([string]$spec.requestReadyName) + '.zip')
$finalGate = Join-Path $PSScriptRoot 'O3F14_FINAL_PACKAGE_GATE.json'
foreach ($path in @($stageRoot, $requestPartial, $requestReady, $finalRoot, $finalZip, $finalGate)) { Assert-O3F14 (-not (Test-Path -LiteralPath $path)) "O3F14 create-new build target exists: $path" }
$planned = @($stageRoot, $requestPartial, $requestReady, (Join-Path $requestReady 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $requestReady 'payload\Run-O3F14Staged.py'), $finalRoot, $finalZip, $finalGate, [string]$spec.gateOutputRoot, [string]$spec.dev6OutputRoot)
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-O3F14 ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3F14 build path gate failed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f14_build_preflight_v1'
        state = 'PASS_O3F14_BUILD_PREFLIGHT'
        requestId = [string]$spec.requestId
        payloadSourceCount = $sources.Count
        payloadSources = @($sources | ForEach-Object { [ordered]@{role=$_.role;path=$_.path;bytes=$_.bytes;sha256=$_.sha256} })
        endpointInvocationGeneratedAtBuild = $true
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        packageSigned = $false
        publicationCount = 0
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 10
    return
}

Assert-O3F14 ([string]$spec.state -eq 'FROZEN_FOR_BUILD' -and [string]$definition.state -eq 'FROZEN_FOR_BUILD') 'O3F14 draft spec/definition must be frozen only after all gates pass.'
[void](New-Item -ItemType Directory -Path $payloadRoot)
foreach ($row in $sources) { Copy-Item -LiteralPath $row.source -Destination (Join-Path $payloadRoot $row.path) }
$endpointRow = @($sources | Where-Object { $_.role -eq 'endpoint' })[0]
$invocationFiles = @($sources | Where-Object { $_.role -ne 'endpoint' } | ForEach-Object { [ordered]@{role=$_.role;path=$_.path;bytes=$_.bytes;sha256=$_.sha256} })
$liveInvocation = [ordered]@{
    schema='argos_ocv03_o3f14_endpoint_invocation_v1';state='FROZEN_LIVE_CONTRACT';revision=[string]$spec.revision;expectedComputerName=[string]$spec.expectedComputerName;payloadRoot='';endpointSha256=[string]$endpointRow.sha256;files=$invocationFiles;runtimePath=[string]$spec.runtimePath;runtimeSha256=[string]$spec.runtimeSha256;sourceAliasDrive=[string]$spec.sourceAliasDrive;substPath=[string]$spec.substPath;substSha256=[string]$spec.substSha256;gateOutputRoot=[string]$spec.gateOutputRoot;dev6OutputRoot=[string]$spec.dev6OutputRoot;realRunnerGateContractRoot=[string]$spec.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$spec.realRunnerDev6ContractRoot;expectedSelfTestState=[string]$spec.expectedSelfTestState;expectedPreflightState=[string]$spec.expectedPreflightState;expectedGateState=[string]$spec.expectedGateState;expectedDev6PassState=[string]$spec.expectedDev6PassState;expectedDev6HoldState=[string]$spec.expectedDev6HoldState;selfTestTimeoutSeconds=[int]$spec.timeouts.selfTestSeconds;preflightTimeoutSeconds=[int]$spec.timeouts.preflightSeconds;rootContractTimeoutSeconds=[int]$spec.timeouts.rootContractSeconds;gateTimeoutSeconds=[int]$spec.timeouts.gateSeconds;dev6TimeoutSeconds=[int]$spec.timeouts.dev6Seconds;maximumChildOutputBytes=[int]$spec.maximumChildOutputBytes;maximumTerminalOutputBytes=[int]$spec.maximumTerminalOutputBytes;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
$invocationPath = Join-Path $payloadRoot 'O3F14_ENDPOINT_LIVE_INVOCATION.json'
Write-O3F14Json $invocationPath $liveInvocation
[void](New-Item -ItemType Directory -Path (Join-Path $requestPartial 'payload'))
$stagedPayloadFiles = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
foreach ($stagedPayloadFile in $stagedPayloadFiles) { Copy-Item -LiteralPath $stagedPayloadFile.FullName -Destination (Join-Path $requestPartial 'payload') }
$records = @(Get-ChildItem -LiteralPath (Join-Path $requestPartial 'payload') -File | Sort-Object Name | ForEach-Object { [ordered]@{path=('payload/' + $_.Name);bytes=[int64]$_.Length;sha256=Get-O3F14Hash $_.FullName} })
Assert-O3F14 ($records.Count -eq 16) 'O3F14 staged payload count changed.'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint")
Assert-O3F14 ([bool]$certificate.HasPrivateKey) 'O3F14 signer private key is absent.'
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=[string]$spec.requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=$records;entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@();allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal;requestRetryAuthorized=$false}
$manifestPath = Join-Path $requestPartial 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $requestPartial 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
Move-Item -LiteralPath $requestPartial -Destination $requestReady
[void](New-Item -ItemType Directory -Path $finalRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPartial = Join-Path $stageRoot (([string]$spec.requestReadyName) + '.zip.partial')
[IO.Compression.ZipFile]::CreateFromDirectory($requestReady, $zipPartial, [IO.Compression.CompressionLevel]::Optimal, $false)
Move-Item -LiteralPath $zipPartial -Destination $finalZip
$gate = [ordered]@{schema='argos_ocv03_o3f14_final_package_gate_v1';state='PASS_O3F14_FINAL_PACKAGE_GATE';requestId=[string]$spec.requestId;requestZip=$finalZip;requestZipBytes=[int64](Get-Item -LiteralPath $finalZip).Length;requestZipSha256=Get-O3F14Hash $finalZip;requestManifestSha256=Get-O3F14Hash (Join-Path $requestReady 'PORTAL_REQUEST_MANIFEST.json');requestSignatureSha256=Get-O3F14Hash (Join-Path $requestReady 'PORTAL_REQUEST_MANIFEST.sig');endpointSha256=[string]$endpointRow.sha256;runnerSha256=[string](@($sources | Where-Object {$_.role -eq 'runner'})[0].sha256);rootContractProbeSha256=[string](@($sources | Where-Object {$_.role -eq 'rootContractProbe'})[0].sha256);sourceAliasPlanSha256=[string](@($sources | Where-Object {$_.role -eq 'sourceAliasPlan'})[0].sha256);substSha256=[string]$spec.substSha256;r11Sha256=[string](@($sources | Where-Object {$_.role -eq 'r11Detector'})[0].sha256);r10PredecessorSha256=[string](@($sources | Where-Object {$_.role -eq 'r10Detector'})[0].sha256);r11FocusedRegressionSha256=[string](@($sources | Where-Object {$_.role -eq 'localGate'})[0].sha256);localGateSha256=[string](@($sources | Where-Object {$_.role -eq 'localGate'})[0].sha256);dev6AcceptedExitStatePairs=@($dev6Pairs);payloadFileCount=16;publicationAuthorized=$false;publicationCount=0;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-O3F14Json $finalGate $gate
$gate | ConvertTo-Json -Depth 10
