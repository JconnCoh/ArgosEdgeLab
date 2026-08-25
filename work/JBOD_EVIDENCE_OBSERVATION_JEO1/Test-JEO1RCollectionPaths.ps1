[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$manifestPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
if (-not $manifestPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'JEO1R path invocation left the project.' }
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_jeo1r_collection_path_invocation_v1') { throw 'JEO1R path invocation schema changed.' }
$candidatePaths = @($invocation.candidatePaths | ForEach-Object { [string]$_ })
if ($candidatePaths.Count -ne 11) { throw 'JEO1R path candidate count changed.' }
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$pathResult = & $pathTool -CandidatePath $candidatePaths -ProjectRoot $project -ReservedSuffixCharacters ([int]$invocation.reservedSuffixCharacters) -AsJson | ConvertFrom-Json
if ([string]$pathResult.state -ne 'PASS_PATH_BUDGET') { throw 'JEO1R path budget failed.' }
$result = [ordered]@{
    schema='argos_jeo1r_collection_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1R_COLLECTION_PATH_GATE'
    invocationManifest=$manifestPath;invocationManifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    candidatePathCount=$candidatePaths.Count;reservedSuffixCharacters=[int]$invocation.reservedSuffixCharacters
    maximumPathLength=[int](($pathResult.candidates | Measure-Object -Property pathLength -Maximum).Maximum)
    maximumEffectiveLength=[int](($pathResult.candidates | Measure-Object -Property effectiveLength -Maximum).Maximum)
    maximumComponentLength=[int](($pathResult.candidates | Measure-Object -Property longestComponentLength -Maximum).Maximum)
    pathRows=@($pathResult.candidates);targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 16; return }
$output = [IO.Path]::GetFullPath((Join-Path $project $OutputPath))
if (-not $output.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'JEO1R path-gate output left the project.' }
if (Test-Path -LiteralPath $output) { throw 'JEO1R path-gate output already exists.' }
$json = $result | ConvertTo-Json -Depth 16
$bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
$stream = New-Object IO.FileStream($output,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
try { $stream.Write($bytes,0,$bytes.Length) }
finally { $stream.Dispose() }
$result | ConvertTo-Json -Depth 16
