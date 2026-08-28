#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath = 'work/OPENCV_EDGE_NOTCH_O3Q3/O3Q3_COLLECTION_CASE_GATE.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Gate) { $modeCount++ }
if ($modeCount -ne 1) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Select-PairRows {
    param([object]$Value, [string]$PairId)
    return @($Value.results | Where-Object { [string]$_.pairId -eq $PairId })
}

$zero = [pscustomobject]@{ results = @() }
$one = [pscustomobject]@{ results = @([pscustomobject]@{pairId='TARGET';df=[pscustomobject]@{candidates=@()}}) }
$many = [pscustomobject]@{ results = @(
    [pscustomobject]@{pairId='TARGET';df=[pscustomobject]@{candidates=@()}},
    [pscustomobject]@{pairId='TARGET';df=[pscustomobject]@{candidates=@()}}
) }
$cases = @(
    [pscustomobject]@{caseId='ZERO';expected=0;actual=@(Select-PairRows $zero 'TARGET').Count},
    [pscustomobject]@{caseId='ONE';expected=1;actual=@(Select-PairRows $one 'TARGET').Count},
    [pscustomobject]@{caseId='MANY';expected=2;actual=@(Select-PairRows $many 'TARGET').Count}
)
foreach ($case in $cases) {
    if ([int]$case.actual -ne [int]$case.expected) { throw "O3Q3 collection case failed: $($case.caseId)" }
}
$result = [ordered]@{
    schema = 'argos_ocv03_o3q3_collection_case_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3Q3_ZERO_ONE_MANY_COLLECTION_CASES'
    caseIds = @($cases | ForEach-Object { [string]$_.caseId })
    cases = $cases
    sourceFilesRead = 0
    imageBytesRead = $false
    targetExecuted = $false
    mutationsPerformed = [bool]$Gate
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $result.mutationsPerformed = $false
    $result | ConvertTo-Json -Depth 8
    return
}
$full = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $full) { throw "O3Q3 collection gate exists: $full" }
$parent = Split-Path -Parent $full
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "O3Q3 collection gate parent is absent: $parent" }
[IO.File]::WriteAllText($full, (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result | ConvertTo-Json -Depth 8
