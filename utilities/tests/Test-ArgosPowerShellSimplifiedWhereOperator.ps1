[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

$project = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$guard = Join-Path $project 'utilities\Confirm-ArgosPowerShellHarnessSafety.ps1'
$safe = Join-Path $PSScriptRoot 'fixtures\simplified_where_operator_safe.ps1'
$unsafe = Join-Path $PSScriptRoot 'fixtures\simplified_where_operator_unsafe.ps1'
foreach ($path in @($guard, $safe, $unsafe)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Simplified-Where test input missing: $path" }
}
if ($Preflight) {
    [pscustomobject]@{ State = 'PASS_SIMPLIFIED_WHERE_OPERATOR_TEST_PREFLIGHT'; MutationPerformed = $false } | ConvertTo-Json
    return
}

$safeResult = & $guard -PowerShellScript $safe -Preflight -AsJson | ConvertFrom-Json
$unsafeResult = & $guard -PowerShellScript $unsafe -Preflight -AsJson -ReturnFailureResult | ConvertFrom-Json
$unsafeCodes = @($unsafeResult.violations | ForEach-Object { [string]$_.code })
if ([string]$safeResult.state -ne 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY') {
    throw 'Whitespace-delimited simplified Where-Object fixture did not pass.'
}
if ([string]$unsafeResult.state -ne 'FAIL_ARGOS_POWERSHELL_HARNESS_SAFETY' -or
    $unsafeCodes -notcontains 'SIMPLIFIED_WHERE_OPERATOR_TOKEN_BOUNDARY') {
    throw 'Joined simplified Where-Object comparison did not produce the required violation.'
}

[ordered]@{
    schema = 'argos_powershell_simplified_where_operator_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_POWERSHELL_SIMPLIFIED_WHERE_OPERATOR_GATE'
    windowsPowerShell = [ordered]@{
        major = [int]$PSVersionTable.PSVersion.Major
        minor = [int]$PSVersionTable.PSVersion.Minor
        edition = [string]$PSVersionTable.PSEdition
    }
    safeGuardState = [string]$safeResult.state
    unsafeGuardState = [string]$unsafeResult.state
    requiredViolation = 'SIMPLIFIED_WHERE_OPERATOR_TOKEN_BOUNDARY'
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 5
