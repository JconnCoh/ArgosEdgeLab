#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedHost = 'DESKTOP-266P787'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$ids = @(
    'REQ_20260902T001500111Z_62619433S22M',
    'REQ_20260902T002400222Z_62619433S22P',
    'REQ_20260902T003000333Z_62619433S22S'
)
$roots = @(
    'to_gateway\pending',
    'to_gateway\sent'
)
$maximumItems = 2000
if ($Preflight) {
    [ordered]@{
        schema = 'argos_r13b_argos_return_route_observation_preflight_v2'
        state = 'PASS_R13B_ARGOS_RETURN_ROUTE_OBSERVATION_R2_PREFLIGHT'
        expectedHost = $expectedHost
        requestIds = $ids
        roots = $roots
        maximumItemsPerRoot = $maximumItems
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}
function Read-BoundedJson([string]$Path) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -gt 1048576) { throw "JSON exceeds 1 MiB: $Path" }
    return (Get-Content -LiteralPath $item.FullName -Raw -ErrorAction Stop | ConvertFrom-Json)
}
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$admin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($env:COMPUTERNAME -ne $expectedHost) { throw "Wrong host: $env:COMPUTERNAME" }
if (-not $admin) { throw 'Administrative token is required for this read-only protected-root observation.' }
if (-not (Test-Path -LiteralPath $portalRoot -PathType Container)) { throw 'Protected portal root is absent.' }
$rootRows = New-Object Collections.Generic.List[object]
$matchRows = New-Object Collections.Generic.List[object]
$errors = New-Object Collections.Generic.List[object]
foreach ($relativeRoot in $roots) {
    $fullRoot = Join-Path $portalRoot $relativeRoot
    try {
        $exists = Test-Path -LiteralPath $fullRoot -PathType Container -ErrorAction Stop
        $items = @(if ($exists) { Get-ChildItem -LiteralPath $fullRoot -Force -ErrorAction Stop | Select-Object -First ($maximumItems + 1) })
        $truncated = $items.Count -gt $maximumItems
        if ($truncated) { $items = @($items | Select-Object -First $maximumItems) }
        foreach ($item in $items) {
            $manifestPath = if ($item.PSIsContainer) { Join-Path $item.FullName 'PORTAL_RESPONSE_MANIFEST.json' } elseif ($item.Name -eq 'PORTAL_RESPONSE_MANIFEST.json') { $item.FullName } else { $null }
            if ($null -ne $manifestPath -and (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
                $manifest = Read-BoundedJson -Path $manifestPath
                if ($ids -ccontains [string]$manifest.requestId) {
                    $matchRows.Add([pscustomobject]@{
                        requestId = [string]$manifest.requestId
                        responseId = [string]$manifest.responseId
                        responseState = [string]$manifest.state
                        relativeRoot = $relativeRoot
                        name = $item.Name
                        lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
                    })
                }
            }
        }
        $rootRows.Add([pscustomobject]@{relativeRoot=$relativeRoot;exists=$exists;itemCount=$items.Count;truncated=$truncated})
    }
    catch {
        $errors.Add([pscustomobject]@{relativeRoot=$relativeRoot;error=$_.Exception.Message})
    }
}
$taskRows = New-Object Collections.Generic.List[object]
foreach ($taskName in @('ArgosProjectPortal.Argos.ResponseRelay.RO')) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        $taskRows.Add([pscustomobject]@{
            taskName = $taskName
            state = [string]$task.State
            principal = [string]$task.Principal.UserId
            lastRunUtc = $info.LastRunTime.ToUniversalTime().ToString('o')
            lastTaskResult = [int64]$info.LastTaskResult
        })
    }
    catch { $errors.Add([pscustomobject]@{relativeRoot='TASK';error=$_.Exception.Message}) }
}
$rootArray = @($rootRows.ToArray())
$matchArray = @($matchRows.ToArray())
$errorArray = @($errors.ToArray())
$taskArray = @($taskRows.ToArray())
$healthy = $errorArray.Count -eq 0 -and @($rootArray | Where-Object {$_.truncated}).Count -eq 0 -and $taskArray.Count -eq 1 -and $taskArray[0].state -eq 'Running' -and $taskArray[0].principal -eq 'SYSTEM'
$result = [ordered]@{
    schema = 'argos_r13b_argos_return_route_observation_v2'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($healthy) {'PASS_R13B_ARGOS_RETURN_ROUTE_R2_READ_ONLY_OBSERVATION'} else {'HOLD_R13B_ARGOS_RETURN_ROUTE_R2_READ_ONLY_OBSERVATION'}
    computerName = $env:COMPUTERNAME
    administrativeToken = $admin
    requestIds = $ids
    rootRows = $rootArray
    matchRows = $matchArray
    matchCount = $matchArray.Count
    taskRows = $taskArray
    returnRelayHealthy = $healthy
    errors = $errorArray
    errorCount = $errorArray.Count
    queueMutationPerformed = $false
    taskOrProcessActionPerformed = $false
    imageBytesRead = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$result | ConvertTo-Json -Depth 10 -Compress | Set-Clipboard
