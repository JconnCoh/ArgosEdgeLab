#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Diagnostic is preflight-only.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$path = Join-Path $project 'work\OPENCV_SCRIBE_R18ZT_SLOT21\R18ZT_SLOT21_POST_RESULT_ADJUDICATION_GATE_20260906A.json'
$finish = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).decipheringFinish
$expectedScoreDecimal = [decimal]::Parse('0.9117836040446633', [Globalization.CultureInfo]::InvariantCulture)
$checks = [ordered]@{
    exact = [bool]$finish.exact
    criterion = ([string]$finish.criterion -ceq 'EXACT_IMAGE_FIRST_STRING_WITH_DEFENSIBLE_GENERIC_SUPPORT_AND_ZERO_WRONG_ACCEPTED')
    imageFirstString = ([string]$finish.imageFirstString -ceq '13HFX135SUE3')
    truth = ([string]$finish.truth -ceq '13HFX135SUE3')
    selectedChannel = ([string]$finish.selectedChannel -ceq 'BF')
    selectedPolarity = ([string]$finish.selectedPolarity -ceq 'DARK')
    selectedDirection = ([string]$finish.selectedDirection -ceq 'FORWARD')
    selectionScore = ([double]$finish.selectionScore -eq [double]0.9117836040446633)
    selectionScoreDecimal = ([decimal]$finish.selectionScore -eq $expectedScoreDecimal)
    selectedGlyphEnvelopePassed = [bool]$finish.selectedGlyphEnvelopePassed
    correctImageFirstCount = ([int]$finish.correctImageFirstCount -eq 1)
    wrongImageFirstAcceptedCount = ([int]$finish.wrongImageFirstAcceptedCount -eq 0)
    developmentAcceptedWrongCount = ([int]$finish.developmentAcceptedWrongCount -eq 0)
    validationCaseCount = ([int]$finish.validationCaseCount -eq 1)
    truthComparedOnlyAfterProviderResult = [bool]$finish.truthComparedOnlyAfterProviderResult
}
[ordered]@{
    schema = 'argos_opencv_scribe_r18zt_package_c_preflight_failure_diagnostic_v1'
    state = if (@($checks.Values | Where-Object { -not $_ }).Count -eq 0) { 'ALL_PREDICATES_TRUE' } else { 'FALSE_PREDICATE_FOUND' }
    powerShellVersion = [string]$PSVersionTable.PSVersion
    selectionScoreType = $finish.selectionScore.GetType().FullName
    selectionScoreRoundTrip = [string]$finish.selectionScore
    checks = $checks
    targetWritesPerformed = $false
} | ConvertTo-Json -Depth 6
