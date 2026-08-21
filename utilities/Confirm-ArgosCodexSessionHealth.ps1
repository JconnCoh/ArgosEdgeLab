[CmdletBinding()]
param(
    [string]$ProjectRoot,
    [string]$SessionRoot,
    [string]$SessionId,
    [ValidateRange(1, 720)]
    [int]$RecentHours = 24,
    [ValidateSet('NOT_ASSESSED', 'PASS_NO_DEGRADATION', 'FAIL_DEGRADATION')]
    [string]$ObservedInteractionHealth = 'NOT_ASSESSED',
    [ValidateRange(0, 1000000)]
    [int]$UnexpectedRetryCount = 0,
    [ValidateRange(0, 1000000)]
    [int]$RepeatedWorkCount = 0,
    [ValidateRange(0, 1000000)]
    [int]$ContinuityErrorCount = 0,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$startedUtc = [DateTime]::UtcNow
$stopwatch = [Diagnostics.Stopwatch]::StartNew()

$quarantinedSessionIds = @(
    '019f95b4-36be-72c0-b0bc-34ae4c3dbf97',
    '019fcd2e-cf41-7f11-93de-592c43d4131b'
)

if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    foreach ($quarantinedId in $quarantinedSessionIds) {
        if ($SessionId.Equals($quarantinedId, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to inspect quarantined Codex session $SessionId."
        }
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw 'Cannot resolve this script path.'
    }
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}
$resolvedProjectRoot = [IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $ProjectRoot).Path
).TrimEnd([IO.Path]::DirectorySeparatorChar)

if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    $profileRoot = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrWhiteSpace($profileRoot)) {
        throw 'Cannot resolve the current user profile directory.'
    }
    $SessionRoot = Join-Path $profileRoot '.codex\sessions'
}
$resolvedSessionRoot = [IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $SessionRoot).Path
).TrimEnd([IO.Path]::DirectorySeparatorChar)

$statePath = Join-Path $resolvedProjectRoot 'work\ARGOS_CONTINUITY_STATE.json'
$continuityScript = Join-Path $resolvedProjectRoot 'utilities\Confirm-ArgosProjectContinuity.ps1'
foreach ($requiredPath in @($statePath, $continuityScript)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Missing required health-probe input: $requiredPath"
    }
}

& $continuityScript -ProjectRoot $resolvedProjectRoot | Out-String | Out-Null
$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$checkpointRelative = [string]$state.currentPhaseCheckpoint
$checkpointPath = Join-Path $resolvedProjectRoot (
    $checkpointRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)
)
$checkpointHash = (Get-FileHash -LiteralPath $checkpointPath -Algorithm SHA256).Hash
if ($checkpointHash -ne [string]$state.currentPhaseCheckpointSha256) {
    throw 'Current phase checkpoint hash changed after the continuity check.'
}

$authorityPassed = (
    [bool]$state.reviewOnly -and
    -not [bool]$state.trainingEligible -and
    -not [bool]$state.xmlEligible -and
    -not [bool]$state.productionEligible
)
if (-not $authorityPassed) {
    throw 'Session-health authority gate failed; expected review-only and no training/XML/production eligibility.'
}

$cutoffUtc = [DateTime]::UtcNow.AddHours(-1 * $RecentHours)
$eligible = @(
    Get-ChildItem -LiteralPath $resolvedSessionRoot -Recurse -File `
        -Filter '*.jsonl' -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $cutoffUtc } |
        Where-Object {
            $name = $_.Name
            @($quarantinedSessionIds | Where-Object {
                $name.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
            }).Count -eq 0
        }
)
if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    $eligible = @($eligible | Where-Object {
        $_.Name.IndexOf($SessionId, [StringComparison]::OrdinalIgnoreCase) -ge 0
    })
}
$selectedSession = @($eligible | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
if ($selectedSession.Count -eq 0) {
    throw 'No recent eligible Codex session was found for the health probe.'
}
$sessionFile = $selectedSession[0]
$sessionBytes = [long]$sessionFile.Length
$sizeBand = if ($sessionBytes -ge 536870912) {
    'HARD_STOP_512_MIB'
} elseif ($sessionBytes -ge 402653184) {
    'SECOND_PROBE_384_MIB'
} elseif ($sessionBytes -ge 268435456) {
    'FIRST_PROBE_256_MIB'
} elseif ($sessionBytes -ge 134217728) {
    'CHECKPOINT_ONLY_128_MIB'
} else {
    'BELOW_128_MIB'
}

$interactionPassed = (
    $ObservedInteractionHealth -eq 'PASS_NO_DEGRADATION' -and
    $UnexpectedRetryCount -eq 0 -and
    $RepeatedWorkCount -eq 0 -and
    $ContinuityErrorCount -eq 0
)
$interactionRequired = $sessionBytes -ge 268435456
$probePassed = $authorityPassed -and (
    -not $interactionRequired -or $interactionPassed
)
$stopwatch.Stop()

$result = [ordered]@{
    schema = 'argos_codex_session_health_probe_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($probePassed) {
        'PASS_ARGOS_CODEX_SESSION_HEALTH'
    } else {
        'FAIL_ARGOS_CODEX_SESSION_HEALTH'
    }
    elapsedMilliseconds = $stopwatch.ElapsedMilliseconds
    metadataOnlySessionInspection = $true
    sessionContentRead = $false
    session = [ordered]@{
        id = if ($sessionFile.BaseName -match '([0-9a-f]{8}-[0-9a-f-]{27,})$') {
            $Matches[1]
        } else {
            $null
        }
        path = $sessionFile.FullName
        bytes = $sessionBytes
        mebibytes = [math]::Round($sessionBytes / 1MB, 3)
        sizeBand = $sizeBand
    }
    continuity = [ordered]@{
        passed = $true
        state = 'PASS_ARGOS_PROJECT_CONTINUITY'
        activePhase = [string]$state.activePhase
        checkpointPath = $checkpointRelative
        checkpointSha256 = $checkpointHash
    }
    authority = [ordered]@{
        passed = $authorityPassed
        reviewOnly = [bool]$state.reviewOnly
        trainingEligible = [bool]$state.trainingEligible
        xmlEligible = [bool]$state.xmlEligible
        productionEligible = [bool]$state.productionEligible
    }
    interaction = [ordered]@{
        requiredAtCurrentSize = $interactionRequired
        observedHealth = $ObservedInteractionHealth
        unexpectedRetryCount = $UnexpectedRetryCount
        repeatedWorkCount = $RepeatedWorkCount
        continuityErrorCount = $ContinuityErrorCount
        passed = if ($interactionRequired) { $interactionPassed } else { $true }
    }
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    [pscustomobject]$result | Format-List
}

if (-not $probePassed) {
    exit 2
}
