[CmdletBinding()]
param(
    [string]$SessionRoot,
    [string]$SessionId,
    [ValidateRange(1, 720)]
    [int]$RecentHours = 24,
    [ValidateRange(1, [long]::MaxValue)]
    [Alias('WarningBytes')]
    [long]$CheckpointBytes = 134217728,
    [ValidateRange(1, [long]::MaxValue)]
    [Alias('RotateBytes')]
    [long]$FirstProbeBytes = 268435456,
    [ValidateRange(1, [long]::MaxValue)]
    [long]$SecondProbeBytes = 402653184,
    [ValidateRange(1, [long]::MaxValue)]
    [long]$HardStopBytes = 536870912,
    [ValidateRange(0, [long]::MaxValue)]
    [long]$PriorSessionBytes = 0,
    [ValidateRange(1, [long]::MaxValue)]
    [long]$SingleTurnGrowthAlarmBytes = 16777216,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$quarantinedSessionIds = @(
    '019f95b4-36be-72c0-b0bc-34ae4c3dbf97',
    '019fcd2e-cf41-7f11-93de-592c43d4131b'
)

if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    foreach ($quarantinedId in $quarantinedSessionIds) {
        if ($SessionId.Equals(
            $quarantinedId,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Refusing to inspect quarantined Codex session $SessionId."
        }
    }
}

if (
    $CheckpointBytes -ge $FirstProbeBytes -or
    $FirstProbeBytes -ge $SecondProbeBytes -or
    $SecondProbeBytes -ge $HardStopBytes
) {
    throw 'Thresholds must satisfy CheckpointBytes < FirstProbeBytes < SecondProbeBytes < HardStopBytes.'
}

if ($PriorSessionBytes -gt 0 -and [string]::IsNullOrWhiteSpace($SessionId)) {
    throw 'PriorSessionBytes requires an exact SessionId.'
}

if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
    $userProfileRoot = [Environment]::GetFolderPath('UserProfile')
    if ([string]::IsNullOrWhiteSpace($userProfileRoot)) {
        $userProfileRoot = [Environment]::GetEnvironmentVariable(
            'USERPROFILE',
            'Process'
        )
    }
    if ([string]::IsNullOrWhiteSpace($userProfileRoot)) {
        throw 'Cannot resolve the current user profile directory.'
    }
    $SessionRoot = Join-Path $userProfileRoot '.codex\sessions'
}

if (-not (Test-Path -LiteralPath $SessionRoot -PathType Container)) {
    throw "Codex session root does not exist: $SessionRoot"
}

$resolvedSessionRoot = [IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $SessionRoot).Path
).TrimEnd([IO.Path]::DirectorySeparatorChar)
$cutoffUtc = [DateTime]::UtcNow.AddHours(-1 * $RecentHours)

$allRecent = @(
    Get-ChildItem -LiteralPath $resolvedSessionRoot -Recurse -File `
        -Filter '*.jsonl' -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTimeUtc -ge $cutoffUtc }
)

$quarantinedExcluded = @(
    $allRecent | Where-Object {
        $name = $_.Name
        @($quarantinedSessionIds | Where-Object {
            $name.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
        }).Count -gt 0
    }
)

$eligible = @(
    $allRecent | Where-Object {
        $name = $_.Name
        @($quarantinedSessionIds | Where-Object {
            $name.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0
        }).Count -eq 0
    }
)

if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
    $eligible = @(
        $eligible | Where-Object {
            $_.Name.IndexOf(
                $SessionId,
                [StringComparison]::OrdinalIgnoreCase
            ) -ge 0
        }
    )
}

function Get-SessionDisposition {
    param([Parameter(Mandatory = $true)][long]$Length)
    if (
        $PriorSessionBytes -gt 0 -and
        ($Length - $PriorSessionBytes) -ge $SingleTurnGrowthAlarmBytes
    ) {
        return 'HARD_STOP_ABNORMAL_SINGLE_TURN_GROWTH'
    }
    if ($Length -ge $HardStopBytes) {
        return 'HARD_STOP_START_FRESH_TASK'
    }
    if ($Length -ge $SecondProbeBytes) {
        return 'SECOND_HEALTH_PROBE_AND_SOFT_ROTATION_RECOMMENDED'
    }
    if ($Length -ge $FirstProbeBytes) {
        return 'SESSION_HEALTH_PROBE_REQUIRED'
    }
    if ($Length -ge $CheckpointBytes) {
        return 'CHECKPOINT_ONLY_CONTINUE'
    }
    return 'PASS_SESSION_SIZE'
}

$sessionRows = @(
    $eligible |
        Sort-Object LastWriteTimeUtc -Descending |
        ForEach-Object {
            [ordered]@{
                sessionId = if ($_.BaseName -match '([0-9a-f]{8}-[0-9a-f-]{27,})$') {
                    $Matches[1]
                } else {
                    $null
                }
                path = $_.FullName
                bytes = [long]$_.Length
                mebibytes = [math]::Round($_.Length / 1MB, 3)
                priorSessionBytes = if ($PriorSessionBytes -gt 0) {
                    $PriorSessionBytes
                } else {
                    $null
                }
                growthSincePriorBytes = if ($PriorSessionBytes -gt 0) {
                    [long]$_.Length - $PriorSessionBytes
                } else {
                    $null
                }
                lastWriteUtc = $_.LastWriteTimeUtc.ToString('o')
                disposition = Get-SessionDisposition -Length $_.Length
            }
        }
)

$exitCode = 0
$overall = 'PASS_SESSION_SIZE'
if (@($sessionRows | Where-Object {
    $_.disposition -in @(
        'HARD_STOP_START_FRESH_TASK',
        'HARD_STOP_ABNORMAL_SINGLE_TURN_GROWTH'
    )
}).Count -gt 0) {
    $exitCode = 3
    $overall = @(
        $sessionRows | Where-Object {
            $_.disposition -in @(
                'HARD_STOP_START_FRESH_TASK',
                'HARD_STOP_ABNORMAL_SINGLE_TURN_GROWTH'
            )
        } | Select-Object -First 1
    )[0].disposition
} elseif (@($sessionRows | Where-Object {
    $_.disposition -eq 'SECOND_HEALTH_PROBE_AND_SOFT_ROTATION_RECOMMENDED'
}).Count -gt 0) {
    $exitCode = 2
    $overall = 'SECOND_HEALTH_PROBE_AND_SOFT_ROTATION_RECOMMENDED'
} elseif (@($sessionRows | Where-Object {
    $_.disposition -eq 'SESSION_HEALTH_PROBE_REQUIRED'
}).Count -gt 0) {
    $exitCode = 1
    $overall = 'SESSION_HEALTH_PROBE_REQUIRED'
} elseif (@($sessionRows | Where-Object {
    $_.disposition -eq 'CHECKPOINT_ONLY_CONTINUE'
}).Count -gt 0) {
    $overall = 'CHECKPOINT_ONLY_CONTINUE'
} elseif ($sessionRows.Count -eq 0) {
    $overall = 'NO_RECENT_ELIGIBLE_SESSION_FOUND'
}

$result = [ordered]@{
    schema = 'argos_codex_session_safety_check_v2'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = $overall
    metadataOnly = $true
    sessionContentRead = $false
    sessionRoot = $resolvedSessionRoot
    recentHours = $RecentHours
    thresholds = [ordered]@{
        checkpointBytes = $CheckpointBytes
        firstProbeBytes = $FirstProbeBytes
        secondProbeBytes = $SecondProbeBytes
        hardStopBytes = $HardStopBytes
        singleTurnGrowthAlarmBytes = $SingleTurnGrowthAlarmBytes
    }
    quarantinedSessionIds = $quarantinedSessionIds
    quarantinedSessionsExcluded = $quarantinedExcluded.Count
    sessions = $sessionRows
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 8
} else {
    [pscustomobject]@{
        State = $result.state
        MetadataOnly = $result.metadataOnly
        SessionContentRead = $result.sessionContentRead
        RecentEligibleSessions = $result.sessions.Count
        QuarantinedSessionsExcluded = $result.quarantinedSessionsExcluded
        CheckpointMiB = [math]::Round($CheckpointBytes / 1MB, 3)
        FirstProbeMiB = [math]::Round($FirstProbeBytes / 1MB, 3)
        SecondProbeMiB = [math]::Round($SecondProbeBytes / 1MB, 3)
        HardStopMiB = [math]::Round($HardStopBytes / 1MB, 3)
    } | Format-List
    if ($sessionRows.Count -gt 0) {
        $sessionRows | ForEach-Object { [pscustomobject]$_ } |
            Format-Table sessionId, mebibytes, lastWriteUtc, disposition -AutoSize
    }
}

exit $exitCode
