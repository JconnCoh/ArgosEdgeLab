#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$guard = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new path gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'JEO1 path invocation left the project.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'JEO1 path invocation is absent.'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$manifest.schema -eq 'argos_jeo1_path_invocation_v1') 'JEO1 path invocation schema changed.'
$candidatePaths = @($manifest.candidatePaths | ForEach-Object { [string]$_ })
Assert-True ($candidatePaths.Count -eq 12) 'JEO1 path invocation must contain exactly 12 candidates.'
Assert-True (@($candidatePaths | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -match 'REPLACE_WITH' }).Count -eq 0) 'JEO1 path invocation contains residue.'
$guardJson = & $guard -CandidatePath $candidatePaths -ReservedSuffixCharacters ([int]$manifest.reservedSuffixCharacters) -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'JEO1 path-budget guard failed.'
$guardResult = $guardJson | ConvertFrom-Json
Assert-True ([string]$guardResult.state -eq 'PASS_PATH_BUDGET') 'JEO1 path-budget state changed.'
$pathRows = @($guardResult.candidates)
$maximumPathLength = [int](($pathRows | Measure-Object -Property pathLength -Maximum).Maximum)
$maximumEffectiveLength = [int](($pathRows | Measure-Object -Property effectiveLength -Maximum).Maximum)
$maximumObservedComponentLength = [int](($pathRows | Measure-Object -Property longestComponentLength -Maximum).Maximum)
$longestRow = @($pathRows | Sort-Object effectiveLength -Descending | Select-Object -First 1)
$result = [ordered]@{
    schema='argos_jeo1_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_COMPLETE_DIRECT_ADMIN_ROUTE_PATH_GATE'
    invocationManifest=$manifestPath;invocationManifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    candidatePathCount=$candidatePaths.Count;reservedSuffixCharacters=[int]$manifest.reservedSuffixCharacters
    maximumPathLength=$maximumPathLength;maximumEffectiveLength=$maximumEffectiveLength;maximumComponentLength=$maximumObservedComponentLength
    longestPath=[string]$longestRow[0].path;pathBudgetState=[string]$guardResult.state;pathRows=$pathRows
    targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 16; return }
Assert-True (-not [string]::IsNullOrWhiteSpace($OutputPath)) 'JEO1 gate mode requires OutputPath.'
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
Assert-True ($resolvedOutput.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'JEO1 path gate output left the project.'
Write-JsonCreateNew -Path $resolvedOutput -Value $result -Depth 16
$result | ConvertTo-Json -Depth 16
