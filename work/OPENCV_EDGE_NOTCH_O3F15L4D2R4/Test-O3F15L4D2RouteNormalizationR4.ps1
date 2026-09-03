#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Specify -Preflight.' }
if ([string]$PSVersionTable.PSEdition -cne 'Desktop' -or [int]$PSVersionTable.PSVersion.Major -ne 5) {
    throw 'Windows PowerShell 5.1 is required.'
}

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$semanticRows = @(
    [pscustomobject]@{ stage = 'slash_a'; path = 'C:/ProgramData/ArgosProjectPortalRO/example/result.json' },
    [pscustomobject]@{ stage = 'slash_b'; path = 'C:\ProgramData\ArgosProjectPortalRO\example\result.json' },
    [pscustomobject]@{ stage = 'second'; path = 'C:\APR\R\pending\example.ready.zip' }
)
$candidatePaths = @($semanticRows | ForEach-Object { [IO.Path]::GetFullPath([string]$_.path) } | Sort-Object -Unique)
$pathResult = & $pathTool -CandidatePath $candidatePaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathResult.state -cne 'PASS_PATH_BUDGET') { throw 'Representative path budget failed.' }
if (@($pathResult.candidates).Count -ne $candidatePaths.Count) { throw 'Normalized candidate cardinality changed.' }

$measurements = @{}
foreach ($row in @($pathResult.candidates)) { $measurements[[string]$row.path] = $row }
$routeRows = foreach ($item in $semanticRows) {
    $normalizedPath = [IO.Path]::GetFullPath([string]$item.path)
    $measurement = $measurements[$normalizedPath]
    if ($null -eq $measurement) { throw "Normalized lookup failed: $normalizedPath" }
    [pscustomobject][ordered]@{
        stage = [string]$item.stage
        path = $normalizedPath
        maximumComponentLength = [int]$measurement.longestComponentLength
    }
}
$maximum = [int]($routeRows | Measure-Object maximumComponentLength -Maximum).Maximum
if ($routeRows.Count -ne 3 -or $candidatePaths.Count -ne 2 -or $maximum -le 0) { throw 'Typed normalized-row consumer proof failed.' }

[ordered]@{
    state = 'PASS_O3F15L4D2_ROUTE_NORMALIZATION_R4_PS51_PREFLIGHT'
    semanticRowCount = $routeRows.Count
    normalizedCandidateCount = $candidatePaths.Count
    routeRowRuntimeType = $routeRows[0].GetType().FullName
    maximumComponentLength = $maximum
    targetExecuted = $false
} | ConvertTo-Json -Depth 4
