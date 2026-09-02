#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Gate) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Resolve-ProjectPath([string]$ProjectRoot, [string]$RelativePath, [string]$Label) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) "$Label path is empty."
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "$Label path must be project-relative: $RelativePath"
    $normalized = $RelativePath.Replace('/', '\')
    Assert-True ($normalized -notmatch '(^|\\)\.\.(\\|$)') "$Label path traverses outside the project: $RelativePath"
    $prefix = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $normalized))
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "$Label path escapes the project: $RelativePath"
    return $full
}

function Assert-PinnedFile([string]$Path, [string]$ExpectedSha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $ExpectedSha256.ToUpperInvariant()) "$Label hash changed: $Path"
}

function Expand-Template([string]$Template, [string]$RequestId, [string]$ResponseId) {
    return $Template.Replace('{REQUEST_ID}', $RequestId).Replace('{RESPONSE_ID}', $ResponseId)
}

function Add-UniquePath([Collections.Generic.List[string]]$Paths, [Collections.Generic.HashSet[string]]$Seen, [string]$Path) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) 'R13B route path is empty.'
    $full = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { $Path }
    if ($Seen.Add($full)) { $Paths.Add($full) }
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'R13B route invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_r13b_complete_route_invocation_v1') 'R13B route invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260902T204408092Z_R13B') 'R13B route request identity changed.'
Assert-True ([int]$invocation.reservedSuffixCharacters -eq 32 -and [int]$invocation.maximumEffectiveLengthExclusive -eq 200 -and [int]$invocation.maximumComponentLength -eq 80) 'R13B path-policy thresholds changed.'
Assert-True ((Get-Sha256 $MyInvocation.MyCommand.Path) -eq [string]$invocation.routeTesterSha256) 'R13B route tester self-pin changed.'

$r6Path = Resolve-ProjectPath $project ([string]$invocation.inheritedRecords.r6v2.path) 'R6V2 route record'
$o2d23Path = Resolve-ProjectPath $project ([string]$invocation.inheritedRecords.o2d23.path) 'O2D23 route-root record'
$o2d23PassPath = Resolve-ProjectPath $project ([string]$invocation.inheritedRecords.o2d23Pass.path) 'O2D23 superseding route gate'
$pathTool = Resolve-ProjectPath $project ([string]$invocation.pathTool.path) 'path-budget tool'
Assert-PinnedFile $r6Path ([string]$invocation.inheritedRecords.r6v2.sha256) 'R13B inherited R6V2 route record'
Assert-PinnedFile $o2d23Path ([string]$invocation.inheritedRecords.o2d23.sha256) 'R13B inherited O2D23 route-root record'
Assert-PinnedFile $o2d23PassPath ([string]$invocation.inheritedRecords.o2d23Pass.sha256) 'R13B inherited O2D23 superseding route gate'
Assert-PinnedFile $pathTool ([string]$invocation.pathTool.sha256) 'R13B path-budget tool'
$r6 = Get-Content -Raw -LiteralPath $r6Path | ConvertFrom-Json
$o2d23 = Get-Content -Raw -LiteralPath $o2d23Path | ConvertFrom-Json
$o2d23Pass = Get-Content -Raw -LiteralPath $o2d23PassPath | ConvertFrom-Json
Assert-True ([string]$r6.state -eq 'PASS_R6V2_PATH_ROUTE_GATE' -and [int]$r6.requestExtractedHopCount -eq 9 -and [int]$r6.responseHopCount -eq 10 -and [int]$r6.reservedSuffixCharacters -eq 32 -and [int]$r6.maximumEffectiveLength -lt 200) 'R13B inherited complete path route premise changed.'
Assert-True ([string]$o2d23.state -eq 'HOLD_O2D23_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN' -and [int]$o2d23.routePathRowsEvaluated -ge 100 -and [int]$o2d23.maximumEffectiveLength -lt 200) 'R13B inherited route-root record changed.'
Assert-True ([string]$o2d23Pass.state -eq 'PASS_O2D23_COMPLETE_ROUTE_GATE' -and [string]$o2d23Pass.inheritedPathRouteGate.sha256 -eq [string]$invocation.inheritedRecords.o2d23.sha256 -and [int]$o2d23Pass.inheritedPathRouteGate.maximumEffectiveLength -lt 200) 'R13B superseding O2D23 route premise changed.'

$requestId = [string]$invocation.requestId
$responseId = [string]$invocation.maximumResponseIdentity
Assert-True ($responseId.Length -eq 41 -and $responseId -match '^R_[A-Z0-9]{12}_[0-9]{17}_[a-z0-9]{8}$') 'R13B maximum response identity shape changed.'
$requestLeaves = @($invocation.requestExtractedLeaves)
$responseLeaves = @($invocation.responseLeaves)
Assert-True ($requestLeaves.Count -eq 9 -and $responseLeaves.Count -eq 5) 'R13B request/response leaf cardinality changed.'
Assert-True (@($requestLeaves | Where-Object { $_ -match '(?i)(__pycache__|\.pyc$)' }).Count -eq 0) 'R13B request route includes cache bytecode.'

$paths = New-Object Collections.Generic.List[string]
$seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$localExtract = Resolve-ProjectPath $project ([string]$invocation.localFinalExtractRoot) 'local final extract root'
$requestRoots = New-Object Collections.Generic.List[string]
$requestRoots.Add($localExtract)
foreach ($template in @($invocation.installedRequestExtractRootTemplates)) { $requestRoots.Add((Expand-Template ([string]$template) $requestId $responseId)) }
Assert-True ($requestRoots.Count -eq 10) 'R13B exact extracted request-hop count changed.'
foreach ($root in $requestRoots) {
    foreach ($leaf in $requestLeaves) { Add-UniquePath $paths $seen ($root.TrimEnd('\') + '\' + ([string]$leaf).Replace('/','\')) }
}

foreach ($template in @($invocation.requestZipPathTemplates)) { Add-UniquePath $paths $seen (Expand-Template ([string]$template) $requestId $responseId) }
foreach ($template in @($invocation.installedResponseExtractRootTemplates)) {
    $root = Expand-Template ([string]$template) $requestId $responseId
    foreach ($leaf in $responseLeaves) { Add-UniquePath $paths $seen ($root.TrimEnd('\') + '\' + [string]$leaf) }
}
Assert-True (@($invocation.installedResponseExtractRootTemplates).Count -eq 10) 'R13B exact installed response-hop count changed.'
$shortResponseRoot = [string]$invocation.shortResponseExtractRoot
Assert-True ($shortResponseRoot -eq 'C:\R13BR\r') 'R13B short response extraction root changed.'
foreach ($leaf in $responseLeaves) { Add-UniquePath $paths $seen ($shortResponseRoot + '\' + [string]$leaf) }
foreach ($template in @($invocation.responseZipPathTemplates)) { Add-UniquePath $paths $seen (Expand-Template ([string]$template) $requestId $responseId) }

foreach ($relative in @($invocation.localPaths)) { Add-UniquePath $paths $seen (Resolve-ProjectPath $project ([string]$relative) 'local route path') }
foreach ($remote in @($invocation.remoteWorkOutputAndBundlePaths)) { Add-UniquePath $paths $seen ([string]$remote) }
foreach ($source in @($invocation.shortAliasedSourcePaths)) { Add-UniquePath $paths $seen ([string]$source) }

$pathJson = & $pathTool -CandidatePath $paths.ToArray() -ReservedSuffixCharacters 32 -AsJson | Out-String
$pathGate = $pathJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R13B complete route path budget failed.'
$rows = @($pathGate.candidates)
Assert-True ($rows.Count -eq $paths.Count) 'R13B complete route path row cardinality changed.'
$maximumEffective = [int](($rows | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($rows | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ($maximumEffective -lt 200 -and $maximumComponent -le 80) 'R13B complete route exceeds path policy.'
$longest = [string](($rows | Sort-Object effectiveLength -Descending | Select-Object -First 1).path)
$outputPath = Resolve-ProjectPath $project ([string]$invocation.outputPath) 'route gate output'
Assert-True (-not (Test-Path -LiteralPath $outputPath)) "R13B route gate create-new output exists: $outputPath"

$routeGateResult = [ordered]@{
    schema='argos_r13b_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_COMPLETE_ROUTE_GATE';classification='FROZEN_PREPUBLICATION_PATH_EVIDENCE';requestId=$requestId;jobClass='MAINTENANCE_PATCH'
    invocationManifestSha256=Get-Sha256 $invocationPath;routeTesterSha256=[string]$invocation.routeTesterSha256;reservedSuffixCharacters=32;pathBudgetState=[string]$pathGate.state;routePathRowsEvaluated=$rows.Count
    requestLeafCountPerExtractedHop=$requestLeaves.Count;requestExtractedHopCount=$requestRoots.Count;inheritedRequestExtractedHopCount=9;additionalCurrentEndpointWorkPackageHopCount=1;responseLeafCountPerHop=$responseLeaves.Count;installedResponseHopCount=@($invocation.installedResponseExtractRootTemplates).Count;shortResponseExtractionHopCount=1
    requestZipPathCount=@($invocation.requestZipPathTemplates).Count;responseZipPathCount=@($invocation.responseZipPathTemplates).Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;longestPath=$longest
    inheritedR6V2RouteGate=[ordered]@{path=[string]$invocation.inheritedRecords.r6v2.path;sha256=[string]$invocation.inheritedRecords.r6v2.sha256;state=[string]$r6.state}
    inheritedO2D23RouteRootGate=[ordered]@{path=[string]$invocation.inheritedRecords.o2d23.path;sha256=[string]$invocation.inheritedRecords.o2d23.sha256;state=[string]$o2d23.state}
    inheritedO2D23SupersedingPassGate=[ordered]@{path=[string]$invocation.inheritedRecords.o2d23Pass.path;sha256=[string]$invocation.inheritedRecords.o2d23Pass.sha256;state=[string]$o2d23Pass.state}
    requestPayloadLeaves=$requestLeaves;responseLeaves=$responseLeaves;maximumResponseIdentity=$responseId;shortPhysicalResponseExtractionRoot='C:\R13BR';shortExtractionUsedInsteadOfLongResponseIdRepoRoot=$true
    packageBindingState='PRE_BUILD_ROUTE_BYTES_UNBOUND';requiresPostBuildPackageBinding=$true;currentRouteHealthObservationRequiredImmediatelyBeforePublication=$true;publicationAuthorized=$false;retryAuthorized=$false
    sourceImagesRead=$false;externalRouteAccessPerformed=$false;targetExecuted=$false;providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;rows=$rows
}
if ($Preflight) {
    [ordered]@{schema='argos_r13b_complete_route_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_COMPLETE_ROUTE_PREFLIGHT';requestId=$requestId;pathBudgetState=[string]$pathGate.state;routePathRowsEvaluated=$rows.Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;mutationsPerformed=$false;externalRouteAccessPerformed=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 10
    return
}
Write-JsonCreateNew $outputPath $routeGateResult
$routeGateResult | ConvertTo-Json -Depth 20
