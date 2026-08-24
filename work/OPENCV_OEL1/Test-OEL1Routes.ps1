[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory = $true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.schema -ne 'argos_oel1_route_invocation_v1') { throw 'OEL1 route invocation schema mismatch.' }
$projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd('\')
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$paths = @($manifest.paths | ForEach-Object { [string]$_ })
if ($paths.Count -lt 20 -or $paths.Count -gt 128 -or @($paths | Sort-Object -Unique).Count -ne $paths.Count) { throw 'OEL1 route path set is incomplete or duplicated.' }

$rows = New-Object Collections.Generic.List[object]
foreach ($path in $paths) {
    $one = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    if ([string]$one.state -ne 'PASS_PATH_BUDGET' -or @($one.candidates).Count -ne 1) { throw "OEL1 route path budget failed: $path" }
    $row = @($one.candidates)[0]
    $rows.Add([pscustomobject]@{path=[string]$row.path;pathLength=[int]$row.pathLength;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state=[string]$row.disposition})
}
$rowArray = $rows.ToArray()
$longest = @($rowArray | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$result = [ordered]@{
    schema = 'argos_oel1_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_OEL1_COMPLETE_ROUTE_PREFLIGHT' } else { 'PASS_OEL1_COMPLETE_ROUTE_GATE' }
    requestId = [string]$manifest.requestId
    jobClass = 'MAINTENANCE_PATCH'
    routePathRowsEvaluated = $rowArray.Count
    reservedSuffixCharacters = 32
    maximumPlannedEffectiveLength = [int]$longest.effectiveLength
    maximumPlannedComponentLength = [int](($rowArray | Measure-Object longestComponentLength -Maximum).Maximum)
    longestPath = [string]$longest.path
    endpointWorkerPredecessorSha256 = [string]$manifest.endpointWorkerPredecessorSha256
    endpointWorkerTargetSha256 = [string]$manifest.endpointWorkerTargetSha256
    installedConfigEvidenceSha256 = [string]$manifest.installedConfigEvidenceSha256
    requestZipPath = [IO.Path]::GetFullPath([string]$manifest.requestZipPath)
    requestZipSha256 = $null
    requestManifestSha256 = $null
    requestSignatureSha256 = $null
    exactFinalZipExtractionPassed = $false
    exactFinalZipSignaturePassed = $false
    rows = $rowArray
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

if ($Preflight) { $result | ConvertTo-Json -Depth 8; return }

$zipPath = [IO.Path]::GetFullPath([string]$manifest.requestZipPath)
$requestManifestPath = [IO.Path]::GetFullPath([string]$manifest.requestManifestPath)
$requestSignaturePath = [IO.Path]::GetFullPath([string]$manifest.requestSignaturePath)
foreach ($path in @($zipPath, $requestManifestPath, $requestSignaturePath)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OEL1 exact route artifact is missing: $path" } }
$result.requestZipSha256 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
$result.requestManifestSha256 = (Get-FileHash -LiteralPath $requestManifestPath -Algorithm SHA256).Hash
$result.requestSignatureSha256 = (Get-FileHash -LiteralPath $requestSignaturePath -Algorithm SHA256).Hash
$result.exactFinalZipExtractionPassed = [bool]$manifest.exactFinalZipExtractionPassed
$result.exactFinalZipSignaturePassed = [bool]$manifest.exactFinalZipSignaturePassed
if (-not$result.exactFinalZipExtractionPassed -or -not$result.exactFinalZipSignaturePassed) { throw 'OEL1 exact final ZIP verification is not PASS.' }
$outputPath = [IO.Path]::GetFullPath([string]$manifest.outputPath)
if (Test-Path -LiteralPath $outputPath) { throw "OEL1 route gate output already exists: $outputPath" }
[IO.File]::WriteAllText($outputPath, ($result | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding($false)))
$result.mutationsPerformed = $true
$result | ConvertTo-Json -Depth 8
