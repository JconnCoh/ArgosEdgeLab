#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F12([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F12Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F12Json([string]$Path, [object]$Value) { Assert-O3F12 (-not (Test-Path -LiteralPath $Path)) "O3F12 rehearsal file exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }
function Get-O3F12SubstTarget([string]$SubstPath) { $rows=@(& $SubstPath); Assert-O3F12 ($LASTEXITCODE-eq0) 'O3F12 test subst query failed.'; $matches=@($rows|Where-Object{([string]$_).StartsWith('Q:\: => ',[StringComparison]::OrdinalIgnoreCase)}); Assert-O3F12 ($matches.Count-le1) 'O3F12 test subst Q: cardinality changed.'; if($matches.Count-eq0){return $null}; return ([string]$matches[0]).Substring(8).Trim().TrimEnd('\') }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F12_PACKAGE_SPEC.json'
$endpoint = Join-Path $PSScriptRoot 'Invoke-O3F12StagedEndpoint.ps1'
$fixture = Join-Path $PSScriptRoot 'O3F12FixtureRunner.py'
$gatePath = Join-Path $PSScriptRoot 'O3F12_ENDPOINT_REHEARSAL_GATE.json'
foreach ($path in @($specPath, $endpoint, $fixture)) { Assert-O3F12 (Test-Path -LiteralPath $path -PathType Leaf) "O3F12 rehearsal dependency is absent: $path" }
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$specSha256 = Get-O3F12Hash $specPath
$expectedGateContractRoot = 'D:/O3F9G12'
$expectedDev6ContractRoot = 'D:/O3F9D12'
Assert-O3F12 ([string]$spec.gateOutputRoot -eq $expectedGateContractRoot -and [string]$spec.realRunnerGateContractRoot -eq $expectedGateContractRoot) 'O3F12 spec GATE/live runner-root contract is not exact.'
Assert-O3F12 ([string]$spec.dev6OutputRoot -eq $expectedDev6ContractRoot -and [string]$spec.realRunnerDev6ContractRoot -eq $expectedDev6ContractRoot) 'O3F12 spec DEV6/live runner-root contract is not exact.'
$pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
$python = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
$pythonHash = Get-O3F12Hash $python

$sourceRows = New-Object Collections.Generic.List[object]
$sourceRows.Add([pscustomobject]@{role='runner';path=[string]$spec.runnerSource})
foreach ($row in @($spec.payloadSources)) { $sourceRows.Add([pscustomobject]@{role=[string]$row.role;path=[string]$row.source}) }
$rows = @($sourceRows.ToArray() | ForEach-Object { $full=Join-Path $project $_.path; Assert-O3F12 (Test-Path -LiteralPath $full -PathType Leaf) "O3F12 rehearsal payload source is absent: $full"; [ordered]@{role=$_.role;path=$_.path.Replace('\','/');bytes=[int64](Get-Item -LiteralPath $full).Length;sha256=Get-O3F12Hash $full} })
Assert-O3F12 ($rows.Count -eq 13) 'O3F12 rehearsal payload role count changed.'
$realRunnerRow = @($rows | Where-Object { [string]$_.role -eq 'runner' })
Assert-O3F12 ($realRunnerRow.Count -eq 1) 'O3F12 exact real runner role cardinality changed.'
Assert-O3F12 ([string]$spec.runnerSha256 -eq '7FA26CF830CAE3FFEB1B34295408E6551F96003A9AC3E07896F750BE5B8492A1' -and [string]$realRunnerRow[0].sha256 -eq [string]$spec.runnerSha256) 'O3F12 exact frozen real runner hash changed.'
$realRunner = [IO.Path]::GetFullPath((Join-Path $project ([string]$realRunnerRow[0].path)))
$substPath = [IO.Path]::GetFullPath([string]$spec.substPath)
Assert-O3F12 ((Get-O3F12Hash $substPath) -eq [string]$spec.substSha256 -and $null -eq (Get-O3F12SubstTarget $substPath) -and -not (Test-Path -LiteralPath 'Q:\')) 'O3F12 rehearsal Q:/subst premise changed.'
foreach ($root in @('C:\A12U', 'C:\A12V', 'C:\A12W', 'C:\A12Q')) { Assert-O3F12 (-not (Test-Path -LiteralPath $root)) "O3F12 rehearsal root exists: $root" }
Assert-O3F12 (-not (Test-Path -LiteralPath $gatePath)) 'O3F12 rehearsal gate exists.'
if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f12_endpoint_rehearsal_preflight_v1';state='PASS_O3F12_ENDPOINT_REHEARSAL_PREFLIGHT';packageSpecSha256=$specSha256;pythonPath=$python;pythonSha256=$pythonHash;payloadRoleCount=$rows.Count;successRoot='C:/A12U';failureRoot='C:/A12V';timeoutRoot='C:/A12W';preoccupiedRoot='C:/A12Q/P';sourceAliasDrive='Q:';substSha256=Get-O3F12Hash $substPath;realRunnerGateContractRoot=[string]$spec.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$spec.realRunnerDev6ContractRoot;mutationsPerformed=$false;sourceImageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$results = New-Object Collections.Generic.List[object]
$realSelfTestEvidence = $null
$realRootContractEvidence = $null
foreach ($case in @([pscustomobject]@{id='SUCCESS';root='C:\A12U';failure='';timeout=30}, [pscustomobject]@{id='INJECTED_DEV6_FAILURE';root='C:\A12V';failure='DEV6';timeout=30}, [pscustomobject]@{id='DEV6_TIMEOUT_ALIAS_BACKSTOP';root='C:\A12W';failure='DEV6_TIMEOUT_ALIAS';timeout=2})) {
    if (-not (Test-Path -LiteralPath $case.root)) { [void](New-Item -ItemType Directory -Path $case.root) }
    $aliasFixtureRoot = Join-Path $case.root 'q'
    $timeoutAliasAnchor = Join-Path $case.root 't'
    if ([string]$case.failure -eq 'DEV6_TIMEOUT_ALIAS') { [void](New-Item -ItemType Directory -Path $timeoutAliasAnchor) }
    $invocationPath = Join-Path $case.root 'i.json'
    $invocation = [ordered]@{schema='argos_ocv03_o3f12_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision=('O3F12_REHEARSAL_' + $case.id);expectedComputerName=$env:COMPUTERNAME;payloadRoot=$project;endpointSha256=Get-O3F12Hash $endpoint;files=$rows;runtimePath='';runtimeSha256='';rehearsalRuntimePath=$python;rehearsalRuntimeSha256=$pythonHash;sourceAliasDrive='Q:';substPath=$substPath;substSha256=Get-O3F12Hash $substPath;aliasFixtureRoot=$aliasFixtureRoot;gateOutputRoot=(Join-Path $case.root 'g');dev6OutputRoot=(Join-Path $case.root 'd');realRunnerGateContractRoot=[string]$spec.realRunnerGateContractRoot;realRunnerDev6ContractRoot=[string]$spec.realRunnerDev6ContractRoot;expectedSelfTestState=[string]$spec.expectedSelfTestState;expectedPreflightState=[string]$spec.expectedPreflightState;expectedGateState=[string]$spec.expectedGateState;expectedDev6State=[string]$spec.expectedDev6State;selfTestTimeoutSeconds=30;preflightTimeoutSeconds=30;rootContractTimeoutSeconds=30;gateTimeoutSeconds=30;dev6TimeoutSeconds=[int]$case.timeout;maximumChildOutputBytes=1048576;maximumTerminalOutputBytes=1048576;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    if ([string]$case.failure -eq 'DEV6_TIMEOUT_ALIAS') { $invocation.rehearsalAliasCleanupAllowedTarget = $timeoutAliasAnchor }
    Write-O3F12Json $invocationPath $invocation
    $priorFailure = [Environment]::GetEnvironmentVariable('ARGOS_O3F12_FIXTURE_FAIL_STAGE', 'Process')
    $priorAliasAnchor = [Environment]::GetEnvironmentVariable('ARGOS_O3F12_FIXTURE_ALIAS_ANCHOR', 'Process')
    $priorSubstPath = [Environment]::GetEnvironmentVariable('ARGOS_O3F12_FIXTURE_SUBST_PATH', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('ARGOS_O3F12_FIXTURE_FAIL_STAGE', [string]$case.failure, 'Process')
        [Environment]::SetEnvironmentVariable('ARGOS_O3F12_FIXTURE_ALIAS_ANCHOR', $timeoutAliasAnchor, 'Process')
        [Environment]::SetEnvironmentVariable('ARGOS_O3F12_FIXTURE_SUBST_PATH', $substPath, 'Process')
        $caught = $null
        try { $value = & $endpoint -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json }
        catch { $caught = $_ }
        if ([string]::IsNullOrWhiteSpace([string]$case.failure)) {
            Assert-O3F12 ($null -eq $caught -and [string]$value.state -eq 'COMPLETE_O3F12_GATE_AND_DEV6_REVIEW_ONLY' -and @($value.dev6.cases).Count -eq 6) 'O3F12 success rehearsal failed.'
            Assert-O3F12 ([string]$value.selfTest.state -eq [string]$spec.expectedSelfTestState -and -not [bool]$value.selfTest.mutationsPerformed -and [string]$value.selfTest.runnerSha256 -eq [string]$realRunnerRow[0].sha256) 'O3F12 exact real runner SELF_TEST endpoint contract changed.'
            Assert-O3F12 ([string]$value.rootContract.state -eq 'PASS_O3F12_EXACT_REAL_RUNNER_ROOT_CONTRACT' -and [string]$value.rootContract.gateRoot -eq [string]$spec.realRunnerGateContractRoot -and [string]$value.rootContract.dev6Root -eq [string]$spec.realRunnerDev6ContractRoot -and [string]::Join('|', @($value.rootContract.gateTerminalKeys)) -ceq 'commands|stage|state|summarySha256' -and [string]::Join('|', @($value.rootContract.dev6TerminalKeys)) -ceq 'aliasEvidence|executedCount|newProviderHoldCount|results|selectedCount|stage|state|stateCounts|summarySha256' -and [bool]$value.rootContract.simulatedFilesystem -and [bool]$value.rootContract.incompatibleO3F12PrefixRejected -and [bool]$value.rootContract.mutationsPerformed -and [bool]$value.rootContract.aliasContract.lifecycle.exercised -and [bool]$value.rootContract.aliasContract.lifecycle.qAbsentAfterBoth) 'O3F12 exact real runner root/schema/alias contract changed.'
            $realSelfTestEvidence = $value.selfTest
            $realRootContractEvidence = $value.rootContract
        } elseif ([string]$case.failure -eq 'DEV6') {
            Assert-O3F12 ($null -ne $caught -and [string]$caught.Exception.Message -like '*INJECTED_O3F12_DEV6_FAILURE*') 'O3F12 injected failure did not fail closed.'
            Assert-O3F12 (Test-Path -LiteralPath ((Join-Path $case.root 'g') + '.failed') -PathType Container) 'O3F12 injected failure did not quarantine the created GATE root.'
            Assert-O3F12 (-not (Test-Path -LiteralPath (Join-Path $case.root 'g'))) 'O3F12 injected failure left the live GATE root in place.'
        } else {
            Assert-O3F12 ($null -ne $caught -and [string]$caught.Exception.Message -like '*timed out*') 'O3F12 timeout-alias fixture did not time out.'
            Assert-O3F12 ($null -eq (Get-O3F12SubstTarget $substPath) -and -not (Test-Path -LiteralPath 'Q:\')) 'O3F12 endpoint timeout cleanup backstop left Q: mapped.'
        }
    } finally {
        [Environment]::SetEnvironmentVariable('ARGOS_O3F12_FIXTURE_FAIL_STAGE', $priorFailure, 'Process')
        [Environment]::SetEnvironmentVariable('ARGOS_O3F12_FIXTURE_ALIAS_ANCHOR', $priorAliasAnchor, 'Process')
        [Environment]::SetEnvironmentVariable('ARGOS_O3F12_FIXTURE_SUBST_PATH', $priorSubstPath, 'Process')
    }
    $results.Add([pscustomobject]@{caseId=$case.id;passed=$true;failureInjected=(-not [string]::IsNullOrWhiteSpace([string]$case.failure));endpointTimeoutAliasCleanupPassed=([string]$case.failure -eq 'DEV6_TIMEOUT_ALIAS');imageBytesRead=$false})
}
$preoccupiedRoot = 'C:\A12Q\P'
[void](New-Item -ItemType Directory -Path $preoccupiedRoot -Force)
$preoccupiedCreated = $false
try {
    $createRows = @(& $substPath 'Q:' $preoccupiedRoot)
    Assert-O3F12 ($LASTEXITCODE -eq 0) ('O3F12 preoccupied-Q fixture creation failed: ' + ([string]::Join(' ', $createRows)))
    $preoccupiedCreated = $true
    Assert-O3F12 ([IO.Path]::GetFullPath([string](Get-O3F12SubstTarget $substPath)).TrimEnd('\').Equals([IO.Path]::GetFullPath($preoccupiedRoot).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O3F12 preoccupied-Q fixture target changed.'
    $occupiedFailure = $null
    try { [void](& $endpoint -Preflight -Rehearsal -InvocationManifest 'C:\A12U\i.json') } catch { $occupiedFailure = $_ }
    Assert-O3F12 ($null -ne $occupiedFailure -and [string]$occupiedFailure.Exception.Message -like '*temporary alias is occupied*') 'O3F12 endpoint did not refuse preoccupied Q: before execution.'
    Assert-O3F12 ([IO.Path]::GetFullPath([string](Get-O3F12SubstTarget $substPath)).TrimEnd('\').Equals([IO.Path]::GetFullPath($preoccupiedRoot).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O3F12 endpoint removed or changed an unowned Q: mapping.'
} finally {
    if ($preoccupiedCreated) {
        $target = Get-O3F12SubstTarget $substPath
        if ($null -ne $target -and [IO.Path]::GetFullPath([string]$target).TrimEnd('\').Equals([IO.Path]::GetFullPath($preoccupiedRoot).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { [void](& $substPath 'Q:' '/D') }
    }
}
Assert-O3F12 ($null -eq (Get-O3F12SubstTarget $substPath) -and -not (Test-Path -LiteralPath 'Q:\')) 'O3F12 test harness did not remove its own preoccupied Q: fixture.'
Assert-O3F12 ($null -ne $realSelfTestEvidence) 'O3F12 exact real runner SELF_TEST evidence is absent.'
Assert-O3F12 ($null -ne $realRootContractEvidence) 'O3F12 exact real runner root-contract evidence is absent.'
$gateValue = [ordered]@{schema='argos_ocv03_o3f12_endpoint_rehearsal_gate_v1';state='PASS_O3F12_EXACT_ENTRYPOINT_REHEARSAL';packageSpecSha256=$specSha256;packageSpecRevision=[string]$spec.revision;packageSpecRequestId=[string]$spec.requestId;packageSpecRunnerSha256=[string]$spec.runnerSha256;packageSpecGateOutputRoot=[string]$spec.gateOutputRoot;packageSpecDev6OutputRoot=[string]$spec.dev6OutputRoot;endpointSha256=Get-O3F12Hash $endpoint;fixtureRunnerSha256=Get-O3F12Hash $fixture;rootContractProbeSha256=Get-O3F12Hash (Join-Path $PSScriptRoot 'O3F12RootContractProbe.py');sourceAliasPlanSha256=Get-O3F12Hash (Join-Path $PSScriptRoot 'O3F12_DEV6_SOURCE_ALIAS_PLAN.json');substSha256=Get-O3F12Hash $substPath;realRunnerSha256=[string]$realSelfTestEvidence.runnerSha256;realRunnerSelfTestState=[string]$realSelfTestEvidence.state;realRunnerSelfTestMutationsPerformed=[bool]$realSelfTestEvidence.mutationsPerformed;realRunnerGateContractRoot=[string]$realRootContractEvidence.gateRoot;realRunnerDev6ContractRoot=[string]$realRootContractEvidence.dev6Root;realRunnerGateTerminalKeys=@($realRootContractEvidence.gateTerminalKeys);realRunnerDev6TerminalKeys=@($realRootContractEvidence.dev6TerminalKeys);realRunnerAliasContract=$realRootContractEvidence.aliasContract;incompatibleO3F12PrefixRejected=[bool]$realRootContractEvidence.incompatibleO3F12PrefixRejected;pythonSha256=$pythonHash;cases=$results.ToArray();successStages=@('SELF_TEST','PREFLIGHT','ROOT_CONTRACT','GATE','DEV6');injectedFailureStage='DEV6';timeoutAliasCleanupBackstopPassed=$true;preoccupiedAliasRefusedAndPreserved=$true;qAbsentAfterRehearsal=$true;sourceImageBytesRead=$false;taskActionCount=0;existingProcessActionCount=0;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-O3F12Json $gatePath $gateValue
$gateValue | ConvertTo-Json -Depth 10
