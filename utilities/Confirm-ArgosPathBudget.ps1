[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]]$CandidatePath,
    [string]$ProjectRoot,
    [ValidateRange(0, 128)]
    [int]$ReservedSuffixCharacters = 32,
    [ValidateRange(80, 259)]
    [int]$WarningEffectiveLength = 200,
    [ValidateRange(81, 260)]
    [int]$HardStopEffectiveLength = 230,
    [ValidateRange(16, 200)]
    [int]$MaximumComponentLength = 80,
    [switch]$ScanExistingChildren,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($WarningEffectiveLength -ge $HardStopEffectiveLength) {
    throw 'WarningEffectiveLength must be less than HardStopEffectiveLength.'
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw 'Cannot resolve this script path.'
    }
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}

if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
    throw "Project root does not exist: $ProjectRoot"
}

$resolvedProjectRoot = [IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $ProjectRoot).Path
).TrimEnd([IO.Path]::DirectorySeparatorChar)
$projectPrefix = $resolvedProjectRoot + [IO.Path]::DirectorySeparatorChar

function Resolve-CandidatePath {
    param([Parameter(Mandatory = $true)][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw 'Candidate paths cannot be empty.'
    }
    if ($Value.IndexOfAny([char[]]'*?') -ge 0) {
        throw "Wildcards are not allowed in path-budget candidates: $Value"
    }
    if ([IO.Path]::IsPathRooted($Value)) {
        return [IO.Path]::GetFullPath($Value)
    }
    return [IO.Path]::GetFullPath((Join-Path $resolvedProjectRoot $Value))
}

function Get-PathDisposition {
    param(
        [Parameter(Mandatory = $true)][int]$EffectiveLength,
        [Parameter(Mandatory = $true)][int]$LongestComponentLength
    )
    if (
        $EffectiveLength -ge $HardStopEffectiveLength -or
        $LongestComponentLength -gt $MaximumComponentLength
    ) {
        return 'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH'
    }
    if ($EffectiveLength -ge $WarningEffectiveLength) {
        return 'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH'
    }
    return 'PASS_PATH_BUDGET'
}

$expandedCandidates = New-Object System.Collections.Generic.List[string]
foreach ($value in $CandidatePath) {
    $full = Resolve-CandidatePath -Value $value
    $expandedCandidates.Add($full)
    if (
        $ScanExistingChildren -and
        (Test-Path -LiteralPath $full -PathType Container)
    ) {
        Get-ChildItem -LiteralPath $full -Recurse -Force `
            -ErrorAction SilentlyContinue | ForEach-Object {
                $expandedCandidates.Add($_.FullName)
            }
    }
}

$uniqueCandidates = @(
    $expandedCandidates |
        Sort-Object -Unique
)

$rows = @(
    foreach ($full in $uniqueCandidates) {
$components = @(
    $full.Split([char[]]@(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    ), [StringSplitOptions]::RemoveEmptyEntries)
)
        $longestComponent = if ($components.Count -gt 0) {
            ($components | Measure-Object -Property Length -Maximum).Maximum
        } else {
            0
        }
        $effectiveLength = $full.Length + $ReservedSuffixCharacters
        $shortSuggestion = $null
        if ($full.StartsWith(
            $projectPrefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            $relative = $full.Substring($projectPrefix.Length)
            $shortSuggestion = 'R:\' + $relative
        } elseif ($full.Equals(
            $resolvedProjectRoot,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            $shortSuggestion = 'R:\'
        }
        [ordered]@{
            path = $full
            pathLength = $full.Length
            reservedSuffixCharacters = $ReservedSuffixCharacters
            effectiveLength = $effectiveLength
            longestComponentLength = [int]$longestComponent
            exists = Test-Path -LiteralPath $full
            disposition = Get-PathDisposition `
                -EffectiveLength $effectiveLength `
                -LongestComponentLength $longestComponent
            suggestedShortForm = $shortSuggestion
        }
    }
)

$overall = 'PASS_PATH_BUDGET'
$exitCode = 0
if (@($rows | Where-Object {
    $_.disposition -eq 'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH'
}).Count -gt 0) {
    $overall = 'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH'
    $exitCode = 2
} elseif (@($rows | Where-Object {
    $_.disposition -eq 'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH'
}).Count -gt 0) {
    $overall = 'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH'
    $exitCode = 1
}

$result = [ordered]@{
    schema = 'argos_windows_path_budget_check_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = $overall
    projectRoot = $resolvedProjectRoot
    warningEffectiveLength = $WarningEffectiveLength
    hardStopEffectiveLength = $HardStopEffectiveLength
    maximumComponentLength = $MaximumComponentLength
    reservedSuffixCharacters = $ReservedSuffixCharacters
    metadataOnly = $true
    fileContentRead = $false
    candidates = $rows
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    [pscustomobject]@{
        State = $overall
        CandidateCount = $rows.Count
        WarningEffectiveLength = $WarningEffectiveLength
        HardStopEffectiveLength = $HardStopEffectiveLength
        MaximumComponentLength = $MaximumComponentLength
        ReservedSuffixCharacters = $ReservedSuffixCharacters
        MetadataOnly = $true
        FileContentRead = $false
    } | Format-List
    $rows | ForEach-Object { [pscustomobject]$_ } |
        Format-Table pathLength, effectiveLength, longestComponentLength,
            disposition, path -AutoSize -Wrap
}

exit $exitCode
