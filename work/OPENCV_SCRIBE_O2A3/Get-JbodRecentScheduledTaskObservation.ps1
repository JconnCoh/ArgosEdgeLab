param([switch]$Preflight)
$ErrorActionPreference = 'Stop'
if ($Preflight) {
    [ordered]@{
        schema = 'argos_jbod_recent_scheduled_task_observation_preflight_v1'
        state = 'PASS_JBOD_RECENT_SCHEDULED_TASK_OBSERVATION_PREFLIGHT'
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json
    return
}
$cutoff = (Get-Date).AddMinutes(-30)
$rows = New-Object Collections.Generic.List[object]
foreach ($task in @(Get-ScheduledTask -ErrorAction Stop)) {
    $info = Get-ScheduledTaskInfo -InputObject $task -ErrorAction SilentlyContinue
    $actions = @($task.Actions | ForEach-Object {
        [ordered]@{
            execute = [string]$_.Execute
            arguments = [string]$_.Arguments
            workingDirectory = [string]$_.WorkingDirectory
        }
    })
    $lastRun = if ($null -eq $info -or $info.LastRunTime -eq [DateTime]::MinValue) { $null } else { [DateTime]$info.LastRunTime }
    $scriptAction = @($actions | Where-Object {
        $_.execute -match '(?i)(powershell|pwsh|cmd|wscript|cscript|mshta|conhost)' -or
        $_.arguments -match '(?i)(\.ps1|\.cmd|\.bat|\.vbs|WindowStyle)'
    }).Count -gt 0
    $include = $task.TaskPath -notlike '\Microsoft\*' -or ($null -ne $lastRun -and $lastRun -ge $cutoff) -or $scriptAction
    if ($include -and $rows.Count -lt 80) {
        $rows.Add([ordered]@{
            taskPath = [string]$task.TaskPath
            taskName = [string]$task.TaskName
            state = [string]$task.State
            lastRunTime = if ($null -eq $lastRun) { '' } else { $lastRun.ToUniversalTime().ToString('o') }
            lastTaskResult = if ($null -eq $info) { $null } else { [int64]$info.LastTaskResult }
            nextRunTime = if ($null -eq $info -or $info.NextRunTime -eq [DateTime]::MinValue) { '' } else { ([DateTime]$info.NextRunTime).ToUniversalTime().ToString('o') }
            principal = [ordered]@{
                userId = [string]$task.Principal.UserId
                logonType = [string]$task.Principal.LogonType
                runLevel = [string]$task.Principal.RunLevel
            }
            actions = $actions
            recent = [bool]($null -ne $lastRun -and $lastRun -ge $cutoff)
            scriptAction = [bool]$scriptAction
        })
    }
}
[ordered]@{
    schema = 'argos_jbod_recent_scheduled_task_observation_v1'
    state = 'PASS_JBOD_RECENT_SCHEDULED_TASK_OBSERVATION'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    computerName = $env:COMPUTERNAME
    cutoffUtc = $cutoff.ToUniversalTime().ToString('o')
    rowCount = $rows.Count
    rows = @($rows | Sort-Object lastRunTime -Descending)
    imageBytesRead = $false
    taskOrProcessRestarted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8 -Compress
