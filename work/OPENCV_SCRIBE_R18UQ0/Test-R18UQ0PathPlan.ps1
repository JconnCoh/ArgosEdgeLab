#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$inputPath = Join-Path $PSScriptRoot 'R18UQ0_ROUND_TRIP_PATH_PLAN_INPUT.json'
$outputPath = Join-Path $PSScriptRoot 'R18UQ0_PATH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($path in @($inputPath, $pathTool)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "R18UQ0 path dependency missing: $path"
}
Require (-not (Test-Path -LiteralPath $outputPath)) 'R18UQ0 path gate already exists.'

$inputRecord = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json
Require ([string]$inputRecord.schema -eq 'argos_r18uq0_round_trip_path_plan_input_v1') 'R18UQ0 path input schema changed.'
Require ([string]$inputRecord.requestId -eq 'REQ_R18UQ0') 'R18UQ0 path input request ID changed.'
Require ([int]$inputRecord.reservedSuffixCharacters -eq 32) 'R18UQ0 suffix reserve changed.'
$candidates = @($inputRecord.candidates)
Require ($candidates.Count -eq 25) 'R18UQ0 path candidate count changed.'
Require (@($candidates.id | Sort-Object -Unique).Count -eq $candidates.Count) 'R18UQ0 path candidate IDs are not unique.'
Require (@($candidates.path | Sort-Object -Unique).Count -eq $candidates.Count) 'R18UQ0 path candidates are not unique.'
foreach ($property in $inputRecord.routeCoverage.PSObject.Properties) {
    Require ($property.Value -is [bool] -and [bool]$property.Value) "R18UQ0 route coverage is incomplete: $($property.Name)"
}

$rows = New-Object Collections.Generic.List[object]
foreach ($candidate in $candidates) {
    $text = (& $pathTool -CandidatePath ([string]$candidate.path) -ReservedSuffixCharacters 32 -AsJson | Out-String)
    $result = $text | ConvertFrom-Json
    Require ([string]$result.schema -eq 'argos_windows_path_budget_check_v1') 'R18UQ0 path utility schema changed.'
    Require (@($result.candidates).Count -eq 1) 'R18UQ0 path utility scalar boundary changed.'
    $row = $result.candidates[0]
    $rows.Add([pscustomobject]@{
        id = [string]$candidate.id
        hop = [string]$candidate.hop
        path = [string]$row.path
        pathLength = [int]$row.pathLength
        reservedSuffixCharacters = [int]$row.reservedSuffixCharacters
        effectiveLength = [int]$row.effectiveLength
        longestComponentLength = [int]$row.longestComponentLength
        disposition = [string]$row.disposition
    }) | Out-Null
}
$rowArray = $rows.ToArray()
$unsafe = @($rowArray | Where-Object { [string]$_.disposition -ne 'PASS_PATH_BUDGET' })
$maximumEffective = [int](($rowArray | Measure-Object -Property effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($rowArray | Measure-Object -Property longestComponentLength -Maximum).Maximum)
Require ($unsafe.Count -eq 0 -and $maximumEffective -lt 200 -and $maximumComponent -le 80) 'R18UQ0 round-trip path plan is unsafe.'

$gateRecord = [ordered]@{
    schema = 'argos_r18uq0_round_trip_path_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18UQ0_ROUND_TRIP_PATH_GATE'
    requestId = 'REQ_R18UQ0'
    inputPath = 'work/OPENCV_SCRIBE_R18UQ0/R18UQ0_ROUND_TRIP_PATH_PLAN_INPUT.json'
    inputSha256 = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
    pathUtilitySha256 = (Get-FileHash -LiteralPath $pathTool -Algorithm SHA256).Hash
    candidateCount = $rowArray.Count
    maximumEffectiveLength = $maximumEffective
    maximumComponentLength = $maximumComponent
    reservedSuffixCharacters = 32
    unsafePathCount = $unsafe.Count
    routeCoverage = $inputRecord.routeCoverage
    candidates = $rowArray
    externalExistenceChecked = $false
    pathBytesMutated = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$json = $gateRecord | ConvertTo-Json -Depth 10
if ($Preflight) {
    $json
    return
}
$bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
$stream = New-Object IO.FileStream($outputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
$json
