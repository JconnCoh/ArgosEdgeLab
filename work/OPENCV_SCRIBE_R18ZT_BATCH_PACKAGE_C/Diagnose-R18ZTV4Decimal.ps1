#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Diagnostic is preflight-only.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$adjudicationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZT_SLOT21\R18ZT_SLOT21_POST_RESULT_ADJUDICATION_GATE_20260906A.json'
$resultPath = 'C:\R18ZTS21A\R18ZT_SLOT21_PROVIDER_RESULT.json'
$finishScore = (Get-Content -LiteralPath $adjudicationPath -Raw | ConvertFrom-Json).decipheringFinish.selectionScore
$resultScore = (Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json).selectedHypothesis.selectionScore
$expected = [decimal]::Parse('0.9117836040446633', [Globalization.CultureInfo]::InvariantCulture)
$finishDecimal = ([decimal]$finishScore -eq $expected)
$resultDecimal = ([decimal]$resultScore -eq $expected)
$finishDouble = ([double]$finishScore -eq [double]0.9117836040446633)
$resultDouble = ([double]$resultScore -eq [double]0.9117836040446633)

[ordered]@{
    schema = 'argos_opencv_scribe_r18zt_v4_decimal_predicate_diagnostic_v1'
    state = if ($finishDecimal -and $resultDecimal -and -not $finishDouble -and -not $resultDouble) { 'PASS_R18ZT_V4_PS51_DECIMAL_PREDICATES' } else { 'FAIL_R18ZT_V4_PS51_DECIMAL_PREDICATES' }
    powerShellVersion = [string]$PSVersionTable.PSVersion
    finishScoreType = $finishScore.GetType().FullName
    resultScoreType = $resultScore.GetType().FullName
    expectedDecimal = $expected.ToString([Globalization.CultureInfo]::InvariantCulture)
    finishDecimalEqual = $finishDecimal
    resultDecimalEqual = $resultDecimal
    withdrawnFinishDoubleEqual = $finishDouble
    withdrawnResultDoubleEqual = $resultDouble
    targetWritesPerformed = $false
    externalAccessPerformed = $false
} | ConvertTo-Json -Depth 5
