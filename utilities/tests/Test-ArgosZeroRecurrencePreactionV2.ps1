[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$validator = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$audit = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$v2 = Join-Path $project 'work\ARGOS_RECOVERY_GOVERNANCE_PREACTION_20260821.json'
$v1 = Join-Path $PSScriptRoot 'fixtures\preaction_v1_historical_pass.json'
$missing = Join-Path $PSScriptRoot 'fixtures\preaction_v2_missing_collection_fail.json'
foreach ($path in @($validator, $audit, $v2, $v1, $missing)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Pre-action v2 test input missing: $path" } }
if ($Preflight) {
    [ordered]@{schema='argos_zero_recurrence_v2_test_preflight_v1';state='PASS_ARGOS_ZERO_RECURRENCE_V2_TEST_PREFLIGHT';caseCount=3;mutationsPerformed=$false}|ConvertTo-Json -Depth 4
    return
}

$v2Result = & $validator -AuditPath $audit -ContractPath $v2 -ProjectRoot $project -Preflight | ConvertFrom-Json
if ([string]$v2Result.state -ne 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION' -or -not [bool]$v2Result.collectionCaseEvidenceVerified) { throw 'Evidence-backed v2 pre-action case failed.' }
$v1Result = & $validator -AuditPath $audit -ContractPath $v1 -ProjectRoot $project -Preflight | ConvertFrom-Json
if ([string]$v1Result.schema -ne 'argos_zero_recurrence_preaction_result_v1' -or [bool]$v1Result.evidenceBackedContract) { throw 'Historical v1 grandfather case failed.' }
$missingFailed = $false
try { [void](& $validator -AuditPath $audit -ContractPath $missing -ProjectRoot $project -Preflight) }
catch { if ($_.Exception.Message -match 'omitted collection-case evidence') { $missingFailed = $true } else { throw } }
if (-not $missingFailed) { throw 'Pre-action v2 missing-evidence case did not fail closed.' }
[ordered]@{schema='argos_zero_recurrence_v2_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_ARGOS_ZERO_RECURRENCE_V2_TESTS';caseCount=3;cases=@('V2_EVIDENCE_PASS','V1_HISTORICAL_PASS','V2_MISSING_EVIDENCE_FAIL_CLOSED');mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
