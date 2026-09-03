#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F9([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F9Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F9Json([string]$Path, [object]$Value) { Assert-O3F9 (-not (Test-Path -LiteralPath $Path)) "O3F9 rehearsal file exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F9_PACKAGE_SPEC.json'
$endpoint = Join-Path $PSScriptRoot 'Invoke-O3F9StagedEndpoint.ps1'
$fixture = Join-Path $PSScriptRoot 'O3F9FixtureRunner.py'
$gatePath = Join-Path $PSScriptRoot 'O3F9_ENDPOINT_REHEARSAL_GATE.json'
foreach ($path in @($specPath, $endpoint, $fixture)) { Assert-O3F9 (Test-Path -LiteralPath $path -PathType Leaf) "O3F9 rehearsal dependency is absent: $path" }
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
$python = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
$pythonHash = Get-O3F9Hash $python

$sourceRows = New-Object Collections.Generic.List[object]
$sourceRows.Add([pscustomobject]@{role='runner';path=[string]$spec.runnerSource})
foreach ($row in @($spec.payloadSources)) { $sourceRows.Add([pscustomobject]@{role=[string]$row.role;path=[string]$row.source}) }
$rows = @($sourceRows.ToArray() | ForEach-Object { $full=Join-Path $project $_.path; Assert-O3F9 (Test-Path -LiteralPath $full -PathType Leaf) "O3F9 rehearsal payload source is absent: $full"; [ordered]@{role=$_.role;path=$_.path.Replace('\','/');bytes=[int64](Get-Item -LiteralPath $full).Length;sha256=Get-O3F9Hash $full} })
Assert-O3F9 ($rows.Count -eq 11) 'O3F9 rehearsal payload role count changed.'
foreach ($root in @('C:\A9U', 'C:\A9V')) { Assert-O3F9 (-not (Test-Path -LiteralPath $root)) "O3F9 rehearsal root exists: $root" }
Assert-O3F9 (-not (Test-Path -LiteralPath $gatePath)) 'O3F9 rehearsal gate exists.'
if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f9_endpoint_rehearsal_preflight_v1';state='PASS_O3F9_ENDPOINT_REHEARSAL_PREFLIGHT';pythonPath=$python;pythonSha256=$pythonHash;payloadRoleCount=$rows.Count;successRoot='C:/A9U';failureRoot='C:/A9V';mutationsPerformed=$false;sourceImageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$results = New-Object Collections.Generic.List[object]
foreach ($case in @([pscustomobject]@{id='SUCCESS';root='C:\A9U';failure=''}, [pscustomobject]@{id='INJECTED_DEV6_FAILURE';root='C:\A9V';failure='DEV6'})) {
    [void](New-Item -ItemType Directory -Path $case.root)
    $invocationPath = Join-Path $case.root 'i.json'
    $invocation = [ordered]@{schema='argos_ocv03_o3f9_endpoint_invocation_v1';state='FROZEN_REHEARSAL_CONTRACT';revision=('O3F9_REHEARSAL_' + $case.id);expectedComputerName=$env:COMPUTERNAME;payloadRoot=$project;endpointSha256=Get-O3F9Hash $endpoint;files=$rows;runtimePath='';runtimeSha256='';rehearsalRuntimePath=$python;rehearsalRuntimeSha256=$pythonHash;gateOutputRoot=(Join-Path $case.root 'g');dev6OutputRoot=(Join-Path $case.root 'd');expectedSelfTestState=[string]$spec.expectedSelfTestState;expectedPreflightState=[string]$spec.expectedPreflightState;expectedGateState=[string]$spec.expectedGateState;expectedDev6State=[string]$spec.expectedDev6State;selfTestTimeoutSeconds=30;preflightTimeoutSeconds=30;gateTimeoutSeconds=30;dev6TimeoutSeconds=30;maximumChildOutputBytes=1048576;maximumTerminalOutputBytes=1048576;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    Write-O3F9Json $invocationPath $invocation
    $priorFailure = [Environment]::GetEnvironmentVariable('ARGOS_O3F9_FIXTURE_FAIL_STAGE', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('ARGOS_O3F9_FIXTURE_FAIL_STAGE', [string]$case.failure, 'Process')
        $caught = $null
        try { $value = & $endpoint -Rehearsal -InvocationManifest $invocationPath | ConvertFrom-Json }
        catch { $caught = $_ }
        if ([string]::IsNullOrWhiteSpace([string]$case.failure)) {
            Assert-O3F9 ($null -eq $caught -and [string]$value.state -eq 'COMPLETE_O3F9_GATE_AND_DEV6_REVIEW_ONLY' -and @($value.dev6.cases).Count -eq 6) 'O3F9 success rehearsal failed.'
        } else {
            Assert-O3F9 ($null -ne $caught -and [string]$caught.Exception.Message -like '*INJECTED_O3F9_DEV6_FAILURE*') 'O3F9 injected failure did not fail closed.'
            Assert-O3F9 (Test-Path -LiteralPath ((Join-Path $case.root 'g') + '.failed') -PathType Container) 'O3F9 injected failure did not quarantine the created GATE root.'
            Assert-O3F9 (-not (Test-Path -LiteralPath (Join-Path $case.root 'g'))) 'O3F9 injected failure left the live GATE root in place.'
        }
    } finally { [Environment]::SetEnvironmentVariable('ARGOS_O3F9_FIXTURE_FAIL_STAGE', $priorFailure, 'Process') }
    $results.Add([pscustomobject]@{caseId=$case.id;passed=$true;failureInjected=(-not [string]::IsNullOrWhiteSpace([string]$case.failure));imageBytesRead=$false})
}
$gateValue = [ordered]@{schema='argos_ocv03_o3f9_endpoint_rehearsal_gate_v1';state='PASS_O3F9_EXACT_ENTRYPOINT_REHEARSAL';endpointSha256=Get-O3F9Hash $endpoint;fixtureRunnerSha256=Get-O3F9Hash $fixture;pythonSha256=$pythonHash;cases=$results.ToArray();successStages=@('SELF_TEST','PREFLIGHT','GATE','DEV6');injectedFailureStage='DEV6';sourceImageBytesRead=$false;taskActionCount=0;existingProcessActionCount=0;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-O3F9Json $gatePath $gateValue
$gateValue | ConvertTo-Json -Depth 10
