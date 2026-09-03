#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F11([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F11Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F11Json([string]$Path, [object]$Value) { Assert-O3F11 (-not (Test-Path -LiteralPath $Path)) "O3F11 rehearsal file exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F11_PACKAGE_SPEC.json'
$endpoint = Join-Path $PSScriptRoot 'Invoke-O3F11StagedEndpoint.ps1'
$fixture = Join-Path $PSScriptRoot 'O3F11FixtureRunner.py'
$gatePath = Join-Path $PSScriptRoot 'O3F11_ENDPOINT_REHEARSAL_GATE.json'
foreach ($path in @($specPath, $endpoint, $fixture)) { Assert-O3F11 (Test-Path -LiteralPath $path -PathType Leaf) "O3F11 rehearsal dependency is absent: $path" }
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$specSha256 = Get-O3F11Hash $specPath
$expectedGateContractRoot = 'D:/O3F9G11'
$expectedDev6ContractRoot = 'D:/O3F9D11'
Assert-O3F11 ([string]$spec.gateOutputRoot -eq $expectedGateContractRoot -and [string]$spec.realRunnerGateContractRoot -eq $expectedGateContractRoot) 'O3F11 spec GATE/live runner-root contract is not exact.'
Assert-O3F11 ([string]$spec.dev6OutputRoot -eq $expectedDev6ContractRoot -and [string]$spec.realRunnerDev6ContractRoot -eq $expectedDev6ContractRoot) 'O3F11 spec DEV6/live runner-root contract is not exact.'
$pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
$python = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
$pythonHash = Get-O3F11Hash $python

$sourceRows = New-Object Collections.Generic.List[object]
$sourceRows.Add([pscustomobject]@{role='runner';path=[string]$spec.runnerSource})
foreach ($row in @($spec.payloadSources)) { $sourceRows.Add([pscustomobject]@{role=[string]$row.role;path=[string]$row.source}) }
$rows = @($sourceRows.ToArray() | ForEach-Object { $full=Join-Path $project $_.path; Assert-O3F11 (Test-Path -LiteralPath $full -PathType Leaf) "O3F11 rehearsal payload source is absent: $full"; [ordered]@{role=$_.role;path=$_.path.Replace('\','/');bytes=[int64](Get-Item -LiteralPath $full).Length;sha256=Get-O3F11Hash $full} })
Assert-O3F11 ($rows.Count -eq 12) 'O3F11 rehearsal payload role count changed.'
$realRunnerRow = @($rows | Where-Object { [string]$_.role -eq 'runner' })
Assert-O3F11 ($realRunnerRow.Count -eq 1) 'O3F11 exact real runner role cardinality changed.'
Assert-O3F11 ([string]$spec.runnerSha256 -eq '606AFE5DF058F0298CFE333D9091DF3F5F0B5F222EC03C40E73006773F587D72' -and [string]$realRunnerRow[0].sha256 -eq [string]$spec.runnerSha256) 'O3F11 exact frozen real runner hash changed.'
$realRunner = [IO.Path]::GetFullPath((Join-Path $project ([string]$realRunnerRow[0].path)))
foreach ($root in @('C:\A11U', 'C:\A11V')) { Assert-O3F11 (-not (Test-Path -LiteralPath $root)) "O3F11 rehearsal root exists: $root" }
Assert-O3F11 (-not (Test-Path -LiteralPath $gatePath)) 'O3F11 rehearsal gate exists.'
if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f11_endpoint_rehearsal_preflight_v1';state='PASS_O3F11_ENDPOINT_REHEARSAL_PREFLIGHT';packageSpecSha256=$specSha256;pythonPath=$python;pythonSha256=$pythonHash;payloadRoleCount=$rows.Count;successRoot='C:/A11U';failureRoot='C:/A11V';realRunnerGateContractRoot=[string]$spec.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$spec.realRunnerDev6ContractRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$results = New-Object Collections.Generic.List[object]
$realSelfTestEvidence = $null
$realRootContractEvidence = $null
foreach ($case in @([pscustomobject]@{id='SUCCESS';root='C:\A11U';failure=''}, [pscustomobject]@{id='INJECTED_DEV6_FAILURE';root='C:\A11V';failure='DEV6'})) {
    if (-not (Test-Path -LiteralPath $case.root)) { [void](New-Item -ItemType Directory -Path $case.root) }
    $invocationPath = Join-Path $case.root 'i.json'
    $invocation = [ordered]@{schema='argos_ocv03_o3f11_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision=('O3F11_REHEARSAL_' + $case.id);expectedComputerName=$env:COMPUTERNAME;payloadRoot=$project;endpointSha256=Get-O3F11Hash $endpoint;files=$rows;runtimePath='';runtimeSha256='';rehearsalRuntimePath=$python;rehearsalRuntimeSha256=$pythonHash;gateOutputRoot=(Join-Path $case.root 'g');dev6OutputRoot=(Join-Path $case.root 'd');realRunnerGateContractRoot=[string]$spec.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$spec.realRunnerDev6ContractRoot;expectedSelfTestState=[string]$spec.expectedSelfTestState;expectedPreflightState=[string]$spec.expectedPreflightState;expectedGateState=[string]$spec.expectedGateState;expectedDev6State=[string]$spec.expectedDev6State;selfTestTimeoutSeconds=30;preflightTimeoutSeconds=30;rootContractTimeoutSeconds=30;gateTimeoutSeconds=30;dev6TimeoutSeconds=30;maximumChildOutputBytes=1048576;maximumTerminalOutputBytes=1048576;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    Write-O3F11Json $invocationPath $invocation
    $priorFailure = [Environment]::GetEnvironmentVariable('ARGOS_O3F11_FIXTURE_FAIL_STAGE', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('ARGOS_O3F11_FIXTURE_FAIL_STAGE', [string]$case.failure, 'Process')
        $caught = $null
        try { $value = & $endpoint -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json }
        catch { $caught = $_ }
        if ([string]::IsNullOrWhiteSpace([string]$case.failure)) {
            Assert-O3F11 ($null -eq $caught -and [string]$value.state -eq 'COMPLETE_O3F11_GATE_AND_DEV6_REVIEW_ONLY' -and @($value.dev6.cases).Count -eq 6) 'O3F11 success rehearsal failed.'
            Assert-O3F11 ([string]$value.selfTest.state -eq [string]$spec.expectedSelfTestState -and -not [bool]$value.selfTest.mutationsPerformed -and [string]$value.selfTest.runnerSha256 -eq [string]$realRunnerRow[0].sha256) 'O3F11 exact real runner SELF_TEST endpoint contract changed.'
            Assert-O3F11 ([string]$value.rootContract.state -eq 'PASS_O3F11_EXACT_REAL_RUNNER_ROOT_CONTRACT' -and [string]$value.rootContract.gateRoot -eq [string]$spec.realRunnerGateContractRoot -and [string]$value.rootContract.dev6Root -eq [string]$spec.realRunnerDev6ContractRoot -and [string]::Join('|', @($value.rootContract.gateTerminalKeys)) -ceq 'commands|stage|state|summarySha256' -and [string]::Join('|', @($value.rootContract.dev6TerminalKeys)) -ceq 'executedCount|newProviderHoldCount|results|selectedCount|stage|state|stateCounts|summarySha256' -and [bool]$value.rootContract.simulatedFilesystem -and [bool]$value.rootContract.incompatibleO3F11PrefixRejected -and -not [bool]$value.rootContract.mutationsPerformed) 'O3F11 exact real runner root/schema contract changed.'
            $realSelfTestEvidence = $value.selfTest
            $realRootContractEvidence = $value.rootContract
        } else {
            Assert-O3F11 ($null -ne $caught -and [string]$caught.Exception.Message -like '*INJECTED_O3F11_DEV6_FAILURE*') 'O3F11 injected failure did not fail closed.'
            Assert-O3F11 (Test-Path -LiteralPath ((Join-Path $case.root 'g') + '.failed') -PathType Container) 'O3F11 injected failure did not quarantine the created GATE root.'
            Assert-O3F11 (-not (Test-Path -LiteralPath (Join-Path $case.root 'g'))) 'O3F11 injected failure left the live GATE root in place.'
        }
    } finally { [Environment]::SetEnvironmentVariable('ARGOS_O3F11_FIXTURE_FAIL_STAGE', $priorFailure, 'Process') }
    $results.Add([pscustomobject]@{caseId=$case.id;passed=$true;failureInjected=(-not [string]::IsNullOrWhiteSpace([string]$case.failure));imageBytesRead=$false})
}
Assert-O3F11 ($null -ne $realSelfTestEvidence) 'O3F11 exact real runner SELF_TEST evidence is absent.'
Assert-O3F11 ($null -ne $realRootContractEvidence) 'O3F11 exact real runner root-contract evidence is absent.'
$gateValue = [ordered]@{schema='argos_ocv03_o3f11_endpoint_rehearsal_gate_v1';state='PASS_O3F11_EXACT_ENTRYPOINT_REHEARSAL';packageSpecSha256=$specSha256;packageSpecRevision=[string]$spec.revision;packageSpecRequestId=[string]$spec.requestId;packageSpecRunnerSha256=[string]$spec.runnerSha256;packageSpecGateOutputRoot=[string]$spec.gateOutputRoot;packageSpecDev6OutputRoot=[string]$spec.dev6OutputRoot;endpointSha256=Get-O3F11Hash $endpoint;fixtureRunnerSha256=Get-O3F11Hash $fixture;rootContractProbeSha256=Get-O3F11Hash (Join-Path $PSScriptRoot 'O3F11RootContractProbe.py');realRunnerSha256=[string]$realSelfTestEvidence.runnerSha256;realRunnerSelfTestState=[string]$realSelfTestEvidence.state;realRunnerSelfTestMutationsPerformed=[bool]$realSelfTestEvidence.mutationsPerformed;realRunnerGateContractRoot=[string]$realRootContractEvidence.gateRoot;realRunnerDev6ContractRoot=[string]$realRootContractEvidence.dev6Root;realRunnerGateTerminalKeys=@($realRootContractEvidence.gateTerminalKeys);realRunnerDev6TerminalKeys=@($realRootContractEvidence.dev6TerminalKeys);incompatibleO3F11PrefixRejected=[bool]$realRootContractEvidence.incompatibleO3F11PrefixRejected;pythonSha256=$pythonHash;cases=$results.ToArray();successStages=@('SELF_TEST','PREFLIGHT','ROOT_CONTRACT','GATE','DEV6');injectedFailureStage='DEV6';sourceImageBytesRead=$false;taskActionCount=0;existingProcessActionCount=0;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-O3F11Json $gatePath $gateValue
$gateValue | ConvertTo-Json -Depth 10
