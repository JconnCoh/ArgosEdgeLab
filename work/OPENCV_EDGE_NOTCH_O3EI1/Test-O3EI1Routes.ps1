[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of Preflight or Gate.' }
function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_o3ei1_route_invocation_v1') { throw 'O3EI1 route invocation schema mismatch.' }
$projectRoot = [IO.Path]::GetFullPath([string]$invocation.projectRoot).TrimEnd('\')
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
$paths = @($invocation.paths | ForEach-Object { [string]$_ })
if ($paths.Count -lt 30 -or $paths.Count -gt 128 -or @($paths | Sort-Object -Unique).Count -ne $paths.Count) { throw 'O3EI1 route path set is incomplete or duplicated.' }
$rows = New-Object Collections.Generic.List[object]
foreach ($path in $paths) {
    $one = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    if ([string]$one.state -ne 'PASS_PATH_BUDGET' -or @($one.candidates).Count -ne 1) { throw "O3EI1 route path budget failed: $path" }
    $row = @($one.candidates)[0]
    $rows.Add([pscustomobject]@{path=[string]$row.path;pathLength=[int]$row.pathLength;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state=[string]$row.disposition})
}
$rowArray = $rows.ToArray()
$longest = @($rowArray | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$result = [ordered]@{
    schema = 'argos_o3ei1_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_O3EI1_COMPLETE_ROUTE_PREFLIGHT' } else { 'PASS_O3EI1_COMPLETE_ROUTE_GATE' }
    requestId = [string]$invocation.requestId
    jobClass = 'MAINTENANCE_PATCH'
    routePathRowsEvaluated = $rowArray.Count
    reservedSuffixCharacters = 32
    maximumPlannedEffectiveLength = [int]$longest.effectiveLength
    maximumPlannedComponentLength = [int](($rowArray | Measure-Object longestComponentLength -Maximum).Maximum)
    longestPath = [string]$longest.path
    endpointWorkerSha256 = [string]$invocation.endpointWorkerSha256
    installedConfigEvidenceSha256 = [string]$invocation.installedConfigEvidenceSha256
    requestZipPath = [IO.Path]::GetFullPath([string]$invocation.requestZipPath)
    requestZipSha256 = $null
    requestManifestSha256 = $null
    requestSignatureSha256 = $null
    exactFinalZipExtractionPassed = $false
    exactFinalZipSignaturePassed = $false
    rows = $rowArray
    remoteMutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 8; return }
foreach ($property in @('requestZipPath','requestManifestPath','requestSignaturePath')) { $path=[IO.Path]::GetFullPath([string]$invocation.$property);if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "O3EI1 exact route artifact is missing: $path"} }
$result.requestZipSha256 = Get-Sha ([string]$invocation.requestZipPath)
$result.requestManifestSha256 = Get-Sha ([string]$invocation.requestManifestPath)
$result.requestSignatureSha256 = Get-Sha ([string]$invocation.requestSignaturePath)
$result.exactFinalZipExtractionPassed = [bool]$invocation.exactFinalZipExtractionPassed
$result.exactFinalZipSignaturePassed = [bool]$invocation.exactFinalZipSignaturePassed
if (-not $result.exactFinalZipExtractionPassed -or -not $result.exactFinalZipSignaturePassed) { throw 'O3EI1 exact final ZIP verification is not PASS.' }
$outputPath = [IO.Path]::GetFullPath([string]$invocation.outputPath)
if (Test-Path -LiteralPath $outputPath) { throw 'O3EI1 route gate output already exists.' }
[IO.File]::WriteAllText($outputPath,(($result|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$result['localEvidenceWritten'] = $true
$result | ConvertTo-Json -Depth 8
