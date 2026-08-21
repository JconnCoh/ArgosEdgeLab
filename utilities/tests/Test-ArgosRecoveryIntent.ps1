[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$validator = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$fixtureRoot = Join-Path $PSScriptRoot 'fixtures'
$cases = @(
    [pscustomobject]@{id='OBSERVE_STATUS_PASS';file='recovery_intent_observe_status_pass.json';expectedState='PASS_ARGOS_RECOVERY_INTENT';expectedCode=''},
    [pscustomobject]@{id='OBSERVE_DIRECT_ADMIN_PASS';file='recovery_intent_observe_direct_admin_pass.json';expectedState='PASS_ARGOS_RECOVERY_INTENT';expectedCode=''},
    [pscustomobject]@{id='OBSERVE_MAINTENANCE_FAIL';file='recovery_intent_observe_maintenance_fail.json';expectedState='FAIL_ARGOS_RECOVERY_INTENT';expectedCode='OBSERVATION_MAINTENANCE_PATCH_FORBIDDEN'},
    [pscustomobject]@{id='OBSERVE_CAPABILITY_GAP_FAIL';file='recovery_intent_observe_capability_gap_fail.json';expectedState='FAIL_ARGOS_RECOVERY_INTENT';expectedCode='OBSERVATION_ROUTE_CAPABILITY_GAP'},
    [pscustomobject]@{id='FAILURE_COUNT_UNPROVED_FAIL';file='recovery_intent_failure_count_unproved_fail.json';expectedState='FAIL_ARGOS_RECOVERY_INTENT';expectedCode='SIGNED_FAILURE_COUNT_UNPROVED'},
    [pscustomobject]@{id='MUTATE_STOPLOSS_FAIL';file='recovery_intent_mutate_stoploss_fail.json';expectedState='FAIL_ARGOS_RECOVERY_INTENT';expectedCode='MUTATION_STOP_LOSS_ACTIVE'},
    [pscustomobject]@{id='MUTATE_MISSING_OBSERVATION_FAIL';file='recovery_intent_mutate_missing_observation_fail.json';expectedState='FAIL_ARGOS_RECOVERY_INTENT';expectedCode='POST_FAILURE_OBSERVATION_REQUIRED'},
    [pscustomobject]@{id='MUTATE_SUPPORTED_PASS';file='recovery_intent_mutate_supported_pass.json';expectedState='PASS_ARGOS_RECOVERY_INTENT';expectedCode=''}
)
foreach ($case in $cases) {
    $path = Join-Path $fixtureRoot $case.file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Recovery-intent fixture missing: $path" }
}
if ($Preflight) {
    [ordered]@{schema='argos_recovery_intent_test_preflight_v1';state='PASS_ARGOS_RECOVERY_INTENT_TEST_PREFLIGHT';caseCount=$cases.Count;mutationsPerformed=$false}|ConvertTo-Json -Depth 4
    return
}

$results = New-Object Collections.Generic.List[object]
foreach ($case in $cases) {
    $path = Join-Path $fixtureRoot $case.file
    $result = & $validator -IntentPath $path -ProjectRoot $project -Preflight -AsJson -ReturnFailureResult | ConvertFrom-Json
    if ([string]$result.state -ne [string]$case.expectedState) { throw "Recovery-intent case state mismatch: $($case.id)" }
    $codes = @($result.violations | ForEach-Object { [string]$_.code })
    if (-not [string]::IsNullOrWhiteSpace([string]$case.expectedCode) -and $codes -notcontains [string]$case.expectedCode) { throw "Recovery-intent case omitted expected code: $($case.id) / $($case.expectedCode)" }
    $results.Add([pscustomobject]@{id=$case.id;state=[string]$result.state;violationCodes=$codes})
}
[ordered]@{schema='argos_recovery_intent_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_ARGOS_RECOVERY_INTENT_TESTS';caseCount=$results.Count;cases=$results.ToArray();mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8
