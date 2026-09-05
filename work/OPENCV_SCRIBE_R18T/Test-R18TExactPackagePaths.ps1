#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Get-TextSha256([string]$Text) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
        return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '')
    }
    finally { $hasher.Dispose() }
}

function Get-LexicalPathRow([string]$Id, [string]$Hop, [string]$Path, [int]$Reserve) {
    Require (-not [string]::IsNullOrWhiteSpace($Path)) "R18T empty path candidate: $Id"
    Require ($Path.IndexOfAny([char[]]'*?') -lt 0) "R18T wildcard path candidate: $Id"
    $normalized = $Path.Replace('/', '\')
    $full = [IO.Path]::GetFullPath($normalized)
    $parts = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $maximumComponent = if ($parts.Count -eq 0) {
        0
    }
    else {
        [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    }
    $effective = $full.Length + $Reserve
    $disposition = if ($effective -ge 230 -or $maximumComponent -gt 80) {
        'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH'
    }
    elseif ($effective -ge 200) {
        'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH'
    }
    else {
        'PASS_PATH_BUDGET'
    }
    return [pscustomobject][ordered]@{
        id = $Id
        hop = $Hop
        path = $full
        pathLength = $full.Length
        reservedSuffixCharacters = $Reserve
        effectiveLength = $effective
        longestComponentLength = $maximumComponent
        disposition = $disposition
        existenceChecked = $false
    }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$manifestPath = Join-Path $PSScriptRoot 'R18T_PAYLOAD_MANIFEST.json'
$launcherPath = Join-Path $PSScriptRoot 'Invoke-R18TLiveOnlyLaunch.ps1'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$inputPath = Join-Path $PSScriptRoot 'R18T_ROUND_TRIP_PATH_PLAN_INPUT.json'
foreach ($path in @($manifestPath, $launcherPath, $definitionPath, $inputPath)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "R18T path dependency absent: $path"
}
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$input = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18t_payload_manifest_v1') 'R18T path manifest schema changed.'
Require ([string]$definition.schema -eq 'argos_opencv_scribe_r18t_maintenance_definition_v1') 'R18T path definition schema changed.'
Require ([string]$input.schema -eq 'argos_opencv_scribe_r18t_round_trip_path_plan_input_v1') 'R18T path input schema changed.'
Require ([string]$input.requestId -eq 'REQ_R18T1') 'R18T path input request changed.'
$reserve = [int]$input.pathBudget.reservedSuffixCharacters
Require ($reserve -eq 32) 'R18T path suffix reserve changed.'

$files = @($manifest.files)
Require ($files.Count -gt 0) 'R18T path manifest is empty.'
$memberSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$members = New-Object Collections.Generic.List[string]
foreach ($leaf in @(
    'PORTAL_REQUEST_MANIFEST.json',
    'PORTAL_REQUEST_MANIFEST.sig',
    'payload/Invoke-R18TLiveOnlyLaunch.ps1',
    'payload/R18T_PAYLOAD_MANIFEST.json'
)) {
    Require ($memberSet.Add($leaf)) "R18T duplicate fixed package member: $leaf"
    $members.Add($leaf)
}
foreach ($file in $files) {
    $relative = [string]$file.installRelativePath
    Require (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[/\\])\.\.([/\\]|$)') "R18T unsafe payload member: $relative"
    $leaf = 'payload/files/' + $relative.Replace('\', '/')
    Require ($memberSet.Add($leaf)) "R18T duplicate package member: $leaf"
    $members.Add($leaf)
}
$sortedMembers = @($members.ToArray() | Sort-Object)
$memberSetSha = Get-TextSha256 (($sortedMembers -join "`n") + "`n")

$rows = New-Object Collections.Generic.List[object]
$rowIds = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($candidate in @($input.candidatePaths)) {
    $id = [string]$candidate.id
    Require ($rowIds.Add($id)) "R18T duplicate path-plan id: $id"
    $rows.Add((Get-LexicalPathRow $id ([string]$candidate.hop) ([string]$candidate.path) $reserve))
}

$packageRoots = [ordered]@{
    LOCAL_STAGE = 'C:\R18T1P\REQ_R18T1.ready'
    LOCAL_VERIFY = 'C:\R18T1V'
    JBOD_ENDPOINT_PENDING = 'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_R18T1.ready'
}
foreach ($rootEntry in $packageRoots.GetEnumerator()) {
    foreach ($leaf in $sortedMembers) {
        $id = 'EXPANDED_' + [string]$rootEntry.Key + '_' + (Get-TextSha256 $leaf).Substring(0, 16)
        Require ($rowIds.Add($id)) "R18T duplicate expanded package path id: $id"
        $candidate = [IO.Path]::Combine([string]$rootEntry.Value, $leaf.Replace('/', '\'))
        $rows.Add((Get-LexicalPathRow $id ('expanded_' + ([string]$rootEntry.Key).ToLowerInvariant()) $candidate $reserve))
    }
}

foreach ($workRoot in @('D:\A2\w\ocv\R18T1.partial', 'D:\A2\w\ocv\R18T1')) {
    foreach ($file in $files) {
        $leaf = ([string]$file.installRelativePath).Replace('/', '\')
        $id = 'EXPANDED_WORK_' + (Get-TextSha256 ($workRoot + '|' + $leaf)).Substring(0, 16)
        Require ($rowIds.Add($id)) "R18T duplicate expanded work path id: $id"
        $rows.Add((Get-LexicalPathRow $id 'expanded_jbod_work' ([IO.Path]::Combine($workRoot, $leaf)) $reserve))
    }
}

foreach ($output in @($definition.entryPointOutputs)) {
    $id = 'DEFINITION_OUTPUT_' + (Get-TextSha256 ([string]$output.path)).Substring(0, 16)
    if ($rowIds.Add($id)) {
        $rows.Add((Get-LexicalPathRow $id 'definition_output' ([string]$output.path) $reserve))
    }
}
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputFull = [IO.Path]::GetFullPath($OutputPath)
    foreach ($candidate in @($outputFull, ($outputFull + '.partial'))) {
        $id = 'GATE_OUTPUT_' + (Get-TextSha256 $candidate).Substring(0, 16)
        if ($rowIds.Add($id)) {
            $rows.Add((Get-LexicalPathRow $id 'local_gate_output' $candidate $reserve))
        }
    }
}

$unsafe = @($rows | Where-Object { [string]$_.disposition -ne 'PASS_PATH_BUDGET' })
Require ($unsafe.Count -eq 0) ('R18T unsafe path-plan rows: ' + (($unsafe | ForEach-Object { $_.path }) -join ', '))
$longest = @($rows | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$maximumComponent = [int](($rows | Measure-Object longestComponentLength -Maximum).Maximum)
$result = [ordered]@{
    schema = 'argos_opencv_scribe_r18t_exact_membership_round_trip_path_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_PATH_BUDGET'
    artifactLifecycle = $(if ($Gate) { 'FROZEN' } else { 'DRAFT_PREFLIGHT' })
    requestId = 'REQ_R18T1'
    revision = 'R18T_LIVE_ONLY_EXECUTION_ENVELOPE_CORRECTION_REVIEW_ONLY_20260904A'
    payloadManifestPath = 'work/OPENCV_SCRIBE_R18T/R18T_PAYLOAD_MANIFEST.json'
    payloadManifestSha256 = Get-Sha256 $manifestPath
    launcherSha256 = Get-Sha256 $launcherPath
    maintenanceDefinitionSha256 = Get-Sha256 $definitionPath
    pathPlanInputSha256 = Get-Sha256 $inputPath
    plannedFinalZipMemberCount = $sortedMembers.Count
    plannedFinalZipMemberSetSha256 = $memberSetSha
    plannedFinalZipMembers = $sortedMembers
    payloadManifestFileCount = $files.Count
    pythonRuntimeSourceCount = @($files | Where-Object { [IO.Path]::GetExtension([string]$_.installRelativePath) -eq '.py' }).Count
    expandedPackageRootCount = $packageRoots.Count
    evaluatedCandidateCount = $rows.Count
    longestConstructedLeaf = [string]$longest.path
    maximumPathLength = [int]$longest.pathLength
    maximumEffectiveLength = [int]$longest.effectiveLength
    maximumComponentLength = $maximumComponent
    reservedSuffixCharacters = $reserve
    unsafePathCount = $unsafe.Count
    routeCoverage = $input.knownRouteCoverage
    candidateRows = $rows.ToArray()
    allCardinalitiesDerivedFromCollections = $true
    externalExistenceChecked = $false
    lexicalOnlyForExternalAndJbodRoots = $true
    pixelsDecoded = $false
    targetExecuted = $false
    mutationsPerformed = $false
    evidenceWritten = $false
    publicationAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

if ($Preflight) {
    $result | ConvertTo-Json -Depth 20
    return
}
Require (-not [string]::IsNullOrWhiteSpace($OutputPath)) 'R18T -Gate requires -OutputPath.'
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
Require ($resolvedOutput.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'R18T path gate output escaped project.'
Require (-not (Test-Path -LiteralPath $resolvedOutput)) 'R18T path gate output already exists.'
$result.evidenceWritten = $true
[IO.File]::WriteAllText(
    $resolvedOutput,
    (($result | ConvertTo-Json -Depth 20) + [Environment]::NewLine),
    (New-Object Text.UTF8Encoding($false))
)
$result | ConvertTo-Json -Depth 20
