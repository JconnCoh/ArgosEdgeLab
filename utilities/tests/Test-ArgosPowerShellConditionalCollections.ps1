[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }
$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$guard = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'
$safe = Join-Path $PSScriptRoot 'fixtures\conditional_collection_safe.ps1'
$unsafe = Join-Path $PSScriptRoot 'fixtures\conditional_collection_unsafe.ps1'
foreach ($path in @($guard, $safe, $unsafe)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Conditional-collection test input missing: $path" } }
if ($Preflight) {
    [ordered]@{schema='argos_powershell_collection_test_preflight_v1';state='PASS_ARGOS_POWERSHELL_COLLECTION_TEST_PREFLIGHT';caseIds=@('ZERO','ONE','MANY');mutationsPerformed=$false}|ConvertTo-Json -Depth 4
    return
}

$safeGuard = & $guard -PowerShellScript $safe -Preflight -AsJson | ConvertFrom-Json
$unsafeGuard = & $guard -PowerShellScript $unsafe -Preflight -AsJson -ReturnFailureResult | ConvertFrom-Json
if ([string]$safeGuard.state -ne 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY') { throw 'Safe outer-boundary fixture did not pass the harness guard.' }
$unsafeCodes = @($unsafeGuard.violations | ForEach-Object { [string]$_.code })
if ([string]$unsafeGuard.state -ne 'FAIL_ARGOS_POWERSHELL_HARNESS_SAFETY' -or $unsafeCodes -notcontains 'CONDITIONAL_COLLECTION_ASSIGNMENT_CAN_SCALARIZE') { throw 'Unsafe inner-boundary fixture did not produce the required violation.' }

$cases = New-Object Collections.Generic.List[object]
foreach ($row in @([pscustomobject]@{id='ZERO';cardinality=0}, [pscustomobject]@{id='ONE';cardinality=1}, [pscustomobject]@{id='MANY';cardinality=3})) {
    $result = & $safe -Preflight -Cardinality $row.cardinality | ConvertFrom-Json
    if ([string]$result.state -ne 'PASS_CONDITIONAL_COLLECTION_SAFE' -or [int]$result.observedCount -ne [int]$row.cardinality) { throw "Conditional-collection cardinality case failed: $($row.id)" }
    $cases.Add([pscustomobject]@{id=$row.id;inputCardinality=[int]$row.cardinality;observedCount=[int]$result.observedCount;state='PASS'})
}
[ordered]@{
    schema='argos_powershell_collection_case_gate_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_ARGOS_POWERSHELL_COLLECTION_CASES'
    windowsPowerShell=[ordered]@{major=[int]$PSVersionTable.PSVersion.Major;minor=[int]$PSVersionTable.PSVersion.Minor;edition=[string]$PSVersionTable.PSEdition}
    caseIds=@('ZERO','ONE','MANY')
    cases=$cases.ToArray()
    safeGuardState=[string]$safeGuard.state
    unsafeGuardState=[string]$unsafeGuard.state
    unsafeViolationCode='CONDITIONAL_COLLECTION_ASSIGNMENT_CAN_SCALARIZE'
    sourceFiles=@(
        [pscustomobject]@{path='utilities/tests/fixtures/conditional_collection_safe.ps1';sha256=(Get-FileHash -LiteralPath $safe -Algorithm SHA256).Hash},
        [pscustomobject]@{path='utilities/Confirm-ArgosPowerShellHarnessSafety.ps1';sha256=(Get-FileHash -LiteralPath $guard -Algorithm SHA256).Hash}
    )
    mutationsPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 8
