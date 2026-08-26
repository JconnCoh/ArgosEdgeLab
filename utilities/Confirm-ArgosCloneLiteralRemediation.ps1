[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
if (-not $manifestPath.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Clone remediation manifest must remain inside the project.' }
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Clone remediation manifest is missing.' }
if ((Get-Item -LiteralPath $manifestPath).Length -gt 1048576) { throw 'Clone remediation manifest exceeds 1 MiB.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.schema -ne 'argos_clone_literal_remediation_manifest_v1' -or @($manifest.pairs).Count -eq 0) { throw 'Clone remediation manifest schema or pair set changed.' }
$resolvedOutput = $null
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
    if (-not $resolvedOutput.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Clone remediation output must remain inside the project.' }
    if (Test-Path -LiteralPath $resolvedOutput) { throw 'Clone remediation output already exists.' }
    $pathTool = Join-Path $PSScriptRoot 'Confirm-ArgosPathBudget.ps1'
    $pathResult = & $pathTool -CandidatePath @($resolvedOutput, ($resolvedOutput + '.partial')) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    if ([string]$pathResult.state -ne 'PASS_PATH_BUDGET') { throw 'Clone remediation output path budget failed.' }
}
if ($Gate -and [string]::IsNullOrWhiteSpace($resolvedOutput)) { throw 'Gate mode requires OutputPath.' }

function Get-LiteralRoots([string]$Text) {
    $roots = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
    $driveText = $Text.Replace('\\', '\')
    foreach ($match in [regex]::Matches($driveText, '(?i)(?<![A-Z0-9_])([A-Z]:\\(?:[A-Z0-9_.-]+)?)')) {
        [void]$roots.Add($match.Groups[1].Value.TrimEnd('\'))
    }
    foreach ($match in [regex]::Matches($Text, '(?i)(?<![:\\])(\\{2,})([A-Z0-9_.-]+)\\+([A-Z0-9_$.-]+)')) {
        [void]$roots.Add(('\\' + $match.Groups[2].Value + '\' + $match.Groups[3].Value))
    }
    return @($roots | Sort-Object)
}

function Resolve-ProjectFile([string]$RelativePath) {
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or $RelativePath.IndexOfAny([char[]]'*?') -ge 0) { throw "Unsafe clone-remediation file path: $RelativePath" }
    $full = [IO.Path]::GetFullPath((Join-Path $project $RelativePath.Replace('/', '\')))
    if (-not $full.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "Clone-remediation file escapes project: $RelativePath" }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "Clone-remediation file missing: $RelativePath" }
    if ((Get-Item -LiteralPath $full).Length -gt 1048576) { throw "Clone-remediation file exceeds 1 MiB: $RelativePath" }
    return $full
}

$violations = New-Object Collections.Generic.List[object]
$pairResults = @()
foreach ($pair in @($manifest.pairs)) {
    $sourcePath = Resolve-ProjectFile ([string]$pair.source)
    $generatedPath = Resolve-ProjectFile ([string]$pair.generated)
    $sourceRoots = @(Get-LiteralRoots ([IO.File]::ReadAllText($sourcePath)))
    $generatedRoots = @(Get-LiteralRoots ([IO.File]::ReadAllText($generatedPath)))
    $rules = @($pair.rootRules)
    if ($rules.Count -eq 0) { throw "Clone-remediation pair has no root rules: $($pair.generated)" }
    $declaredSource = @($rules | Where-Object { [string]$_.disposition -ne 'ADDED' } | ForEach-Object { [string]$_.sourceRoot } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    $declaredGenerated = @($rules | ForEach-Object { [string]$_.generatedRoot } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
    foreach ($root in $sourceRoots) { if ($declaredSource -inotcontains $root) { $violations.Add([pscustomobject]@{code='UNDECLARED_SOURCE_LITERAL_ROOT';file=[string]$pair.source;root=$root}) } }
    foreach ($root in $declaredSource) { if ($sourceRoots -inotcontains $root) { $violations.Add([pscustomobject]@{code='DECLARED_SOURCE_LITERAL_ROOT_MISSING';file=[string]$pair.source;root=$root}) } }
    foreach ($root in $generatedRoots) { if ($declaredGenerated -inotcontains $root) { $violations.Add([pscustomobject]@{code='UNDECLARED_GENERATED_LITERAL_ROOT';file=[string]$pair.generated;root=$root}) } }
    foreach ($root in $declaredGenerated) { if ($generatedRoots -inotcontains $root) { $violations.Add([pscustomobject]@{code='DECLARED_GENERATED_LITERAL_ROOT_MISSING';file=[string]$pair.generated;root=$root}) } }
    foreach ($rule in $rules) {
        $from = [string]$rule.sourceRoot
        $to = [string]$rule.generatedRoot
        $disposition = [string]$rule.disposition
        if ($disposition -eq 'REPLACED') {
            if ($from.Equals($to, [StringComparison]::OrdinalIgnoreCase) -or $generatedRoots -icontains $from -or $generatedRoots -inotcontains $to) { $violations.Add([pscustomobject]@{code='REQUIRED_LITERAL_ROOT_REPLACEMENT_FAILED';file=[string]$pair.generated;root=$from;expected=$to}) }
        }
        elseif ($disposition -eq 'UNCHANGED_ALLOWED') {
            if (-not $from.Equals($to, [StringComparison]::OrdinalIgnoreCase) -or $generatedRoots -inotcontains $to) { $violations.Add([pscustomobject]@{code='UNCHANGED_LITERAL_ROOT_CONTRACT_FAILED';file=[string]$pair.generated;root=$from;expected=$to}) }
        }
        elseif ($disposition -eq 'ADDED') {
            if (-not [string]::IsNullOrWhiteSpace($from) -or [string]::IsNullOrWhiteSpace($to) -or $sourceRoots -icontains $to -or $generatedRoots -inotcontains $to) { $violations.Add([pscustomobject]@{code='ADDED_LITERAL_ROOT_CONTRACT_FAILED';file=[string]$pair.generated;root=$from;expected=$to}) }
        }
        elseif ($disposition -eq 'NO_LITERAL_ROOTS') {
            if (-not [string]::IsNullOrWhiteSpace($from) -or -not [string]::IsNullOrWhiteSpace($to) -or $sourceRoots.Count -ne 0 -or $generatedRoots.Count -ne 0) { $violations.Add([pscustomobject]@{code='NO_LITERAL_ROOTS_CONTRACT_FAILED';file=[string]$pair.generated;root=$from;expected=$to}) }
        }
        else { $violations.Add([pscustomobject]@{code='UNKNOWN_LITERAL_ROOT_DISPOSITION';file=[string]$pair.generated;root=$from;expected=$disposition}) }
    }
    $pairResults += [pscustomobject]@{source=[string]$pair.source;generated=[string]$pair.generated;sourceSha256=(Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash;generatedSha256=(Get-FileHash -LiteralPath $generatedPath -Algorithm SHA256).Hash;sourceRoots=$sourceRoots;generatedRoots=$generatedRoots;ruleCount=$rules.Count}
}

$result = [ordered]@{schema='argos_clone_literal_remediation_gate_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state=$(if($violations.Count-eq0){'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'}else{'FAIL_ARGOS_CLONE_LITERAL_REMEDIATION'});mode=$(if($Preflight){'PREFLIGHT'}else{'GATE'});manifest=$manifestPath;manifestSha256=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash;pairCount=$pairResults.Count;pairs=$pairResults;violations=$violations.ToArray();metadataOnly=$true;targetExecuted=$false;evidenceWritten=$false}
$json = $result | ConvertTo-Json -Depth 8
if ($violations.Count -gt 0) { if ($AsJson) { $json } else { $result }; throw "Clone literal remediation failed with $($violations.Count) violation(s)." }
if ($Preflight) { if ($AsJson) { $json } else { $result }; return }
$result.evidenceWritten = $true
$json = $result | ConvertTo-Json -Depth 8
[IO.File]::WriteAllText($resolvedOutput, ($json + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
if ($AsJson) { $json } else { $result }
