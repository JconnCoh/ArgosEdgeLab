[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$R14ResultsCsv,
    [Parameter(Mandatory=$true)][string]$R15ResultsCsv,
    [Parameter(Mandatory=$true)][string]$OutputRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Circular-Difference([double]$A, [double]$B) {
    return [math]::Abs((($B - $A + 540.0) % 360.0) - 180.0)
}

function Percentile([double[]]$Values, [double]$Fraction) {
    if ($Values.Count -eq 0) { return $null }
    $sorted = @($Values | Sort-Object)
    $index = [math]::Min($sorted.Count - 1, [math]::Floor($Fraction * ($sorted.Count - 1)))
    return [math]::Round([double]$sorted[$index], 6)
}

foreach ($path in @($R14ResultsCsv,$R15ResultsCsv)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Results CSV is absent: $path" }
}
if (Test-Path -LiteralPath $OutputRoot) { throw "Create-new comparison root already exists: $OutputRoot" }

$r14 = @(Import-Csv -LiteralPath $R14ResultsCsv)
$r15 = @(Import-Csv -LiteralPath $R15ResultsCsv)
$map14 = @{}
$map15 = @{}
foreach ($row in $r14) {
    if ($map14.ContainsKey([string]$row.identity)) { throw "R14 identity is duplicated: $($row.identity)" }
    $map14[[string]$row.identity] = $row
}
foreach ($row in $r15) {
    if ($map15.ContainsKey([string]$row.identity)) { throw "R15 identity is duplicated: $($row.identity)" }
    $map15[[string]$row.identity] = $row
}

$passState = 'PASS_REVIEW_ONLY_UNIQUE_BACK_BF_DF_NOTCH'
$allIdentities = @($map14.Keys + $map15.Keys | Sort-Object -Unique)
$transitions = @()
foreach ($identity in $allIdentities) {
    $has14 = $map14.ContainsKey($identity)
    $has15 = $map15.ContainsKey($identity)
    $a = if ($has14) { $map14[$identity] } else { $null }
    $b = if ($has15) { $map15[$identity] } else { $null }
    $aPass = $has14 -and [string]$a.notchState -eq $passState
    $bPass = $has15 -and [string]$b.notchState -eq $passState
    $classification = if (-not $has14) { 'NEW_R15' }
        elseif (-not $has15) { 'MISSING_R15' }
        elseif ($aPass -and $bPass) { 'SAME_PASS' }
        elseif (-not $aPass -and $bPass) { 'RESCUED' }
        elseif ($aPass -and -not $bPass) { 'REGRESSED' }
        elseif ([string]$a.notchState -eq [string]$b.notchState) { 'SAME_HOLD' }
        else { 'CHANGED_HOLD' }
    $delta = $null
    if ($aPass -and $bPass) {
        $delta = Circular-Difference ([double]$a.notchAngleDegrees) ([double]$b.notchAngleDegrees)
    }
    $transitions += [pscustomobject][ordered]@{
        identity = $identity
        classification = $classification
        r14State = if ($has14) { [string]$a.notchState } else { '' }
        r15State = if ($has15) { [string]$b.notchState } else { '' }
        r14AngleDegrees = if ($has14) { [string]$a.notchAngleDegrees } else { '' }
        r15AngleDegrees = if ($has15) { [string]$b.notchAngleDegrees } else { '' }
        angleDeltaDegrees = if ($null -eq $delta) { '' } else { [math]::Round($delta, 9) }
        r14BfDfDifferenceDegrees = if ($has14) { [string]$a.bfDfAngleDifferenceDegrees } else { '' }
        r15BfDfDifferenceDegrees = if ($has15) { [string]$b.bfDfAngleDifferenceDegrees } else { '' }
        r14DiagnosticRoot = if ($has14) { [string]$a.diagnosticRoot } else { '' }
        r15DiagnosticRoot = if ($has15) { [string]$b.diagnosticRoot } else { '' }
    }
}

$samePassDeltas = @($transitions | Where-Object classification -eq 'SAME_PASS' | ForEach-Object { [double]$_.angleDeltaDegrees })
$matrix = @($transitions | Where-Object { $_.classification -notin @('NEW_R15','MISSING_R15') } |
    Group-Object r14State,r15State | Sort-Object Name | ForEach-Object {
        [pscustomobject][ordered]@{ r14State=$_.Group[0].r14State; r15State=$_.Group[0].r15State; count=$_.Count }
    })
$summary = [ordered]@{
    schema = 'argos_o3b10_r14_r15_backside_corpus_comparison_v1'
    state = 'COMPLETE_O3B10_R14_R15_BACKSIDE_CORPUS_COMPARISON'
    createdUtc = [DateTimeOffset]::UtcNow.ToString('o')
    inputs = [ordered]@{
        r14 = [ordered]@{ path=[IO.Path]::GetFullPath($R14ResultsCsv); sha256=(Get-FileHash -LiteralPath $R14ResultsCsv -Algorithm SHA256).Hash; rows=$r14.Count }
        r15 = [ordered]@{ path=[IO.Path]::GetFullPath($R15ResultsCsv); sha256=(Get-FileHash -LiteralPath $R15ResultsCsv -Algorithm SHA256).Hash; rows=$r15.Count }
    }
    identityCounts = [ordered]@{
        common=@($transitions | Where-Object classification -notin @('NEW_R15','MISSING_R15')).Count
        onlyR14=@($transitions | Where-Object classification -eq 'MISSING_R15').Count
        onlyR15=@($transitions | Where-Object classification -eq 'NEW_R15').Count
    }
    outcomeCounts = [ordered]@{
        samePass=@($transitions | Where-Object classification -eq 'SAME_PASS').Count
        rescued=@($transitions | Where-Object classification -eq 'RESCUED').Count
        regressed=@($transitions | Where-Object classification -eq 'REGRESSED').Count
        sameHold=@($transitions | Where-Object classification -eq 'SAME_HOLD').Count
        changedHold=@($transitions | Where-Object classification -eq 'CHANGED_HOLD').Count
    }
    transitionMatrix = $matrix
    samePassAngleDeltaDegrees = [ordered]@{
        count=$samePassDeltas.Count
        median=(Percentile $samePassDeltas 0.50)
        p90=(Percentile $samePassDeltas 0.90)
        p95=(Percentile $samePassDeltas 0.95)
        p99=(Percentile $samePassDeltas 0.99)
        maximum=if ($samePassDeltas.Count) { [math]::Round(($samePassDeltas | Measure-Object -Maximum).Maximum, 6) } else { $null }
    }
    regressions = @($transitions | Where-Object classification -eq 'REGRESSED')
    rescued = @($transitions | Where-Object classification -eq 'RESCUED')
    newR15 = @($transitions | Where-Object classification -eq 'NEW_R15')
    sourceMutationPerformed = $false
    reviewOnly = $true
}

[void](New-Item -ItemType Directory -Path $OutputRoot)
$summary | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $OutputRoot 'COMPARISON.json') -Encoding utf8NoBOM
$transitions | Export-Csv -LiteralPath (Join-Path $OutputRoot 'TRANSITIONS.csv') -NoTypeInformation -Encoding utf8
$transitions | Where-Object { $_.r15State -like 'HOLD*' } | Export-Csv -LiteralPath (Join-Path $OutputRoot 'R15_HOLDS.csv') -NoTypeInformation -Encoding utf8
$transitions | Where-Object classification -eq 'NEW_R15' | Export-Csv -LiteralPath (Join-Path $OutputRoot 'R15_NEW_IDENTITIES.csv') -NoTypeInformation -Encoding utf8
$summary | ConvertTo-Json -Depth 5 -Compress
