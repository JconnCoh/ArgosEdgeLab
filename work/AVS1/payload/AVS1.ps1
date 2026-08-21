[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$configPath = Join-Path $processorRoot 'PROCESSOR_CONFIG.json'
$processorTaskName = 'ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'
$trayTaskName = 'ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2'
$processorTaskDefinitionSha256 = '6E306778640AF823C53422411E65F9A796075392DEA25306F59FE7EDB8259B17'
$trayTaskDefinitionSha256 = 'E3D78B9802BC4599CEC37BCC80F01BC8A0086B398CCABC25163DE4AEFC0C419F'
$targetHashes = [ordered]@{
    'Run-JbodAllWaferProcessor.ps1' = '8EB83C05CA650C831D2DE8A6AB89ABD2941271B05B31FA93BCFFB553DEAAA892'
    'Invoke-JbodAllWaferInventory.ps1' = 'BF0BAF295F3D1F3234C5C2A5DE184AFEA4BE446BB9593BE9E10BB0E8F932F50A'
    'Invoke-JbodAllWaferProcessingPass.ps1' = '8050EEB71923DC69EBD0A81F6C95840A7BD6215998E8546F9170C5A051B936EB'
    'Update-JbodDashboardManifest.ps1' = '036650143A582222CF46ED6892AE81EB3D90582ED558191D95626176D2E1BBFB'
    'Show-JbodAllWaferTray.ps1' = 'C03812C6889B102DFD9B3CB466E70B06B8943C1123A882EB0ADE972C641DAB2B'
}
$predecessorHashes = [ordered]@{
    'Run-JbodAllWaferProcessor.ps1' = '46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
    'Invoke-JbodAllWaferInventory.ps1' = '8919C3DD4AC04FD662B57E356AC6E1A70BD614E97AFC270EB4B8FF617D705160'
    'Invoke-JbodAllWaferProcessingPass.ps1' = '0B063D452CA76AE5EE3EC1BDF6726853259039683C36E208718B8FE937D23753'
    'Update-JbodDashboardManifest.ps1' = 'DCF97D92BDA0A82A49DA277D54CFD1BC7802068CD8B9D89340534CC892792BAD'
    'Show-JbodAllWaferTray.ps1' = '769ACAD731F8EA04C1820AB90CCA80591A132CEDDFCF44611B54D9BB2A41FB45'
}

function Get-OptionalProperty {
    param([object]$Object, [string]$Name, $Default)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256 {
    param([string]$Text)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Get-TaskRecord {
    param([object]$Task)
    $xml = Export-ScheduledTask -TaskName ([string]$Task.TaskName) -TaskPath ([string]$Task.TaskPath)
    return [pscustomobject]@{
        name = [string]$Task.TaskName
        taskPath = [string]$Task.TaskPath
        principal = [string]$Task.Principal.UserId
        state = [string]$Task.State
        definitionSha256 = Get-TextSha256 $xml
        actions = @($Task.Actions | ForEach-Object {
            [pscustomobject]@{
                execute = [string](Get-OptionalProperty $_ 'Execute' '')
                arguments = [string](Get-OptionalProperty $_ 'Arguments' '')
            }
        })
    }
}

function Read-ProtectedTasks {
    return @(Get-ScheduledTask -ErrorAction Stop | Where-Object {
        $_.TaskName -like 'Argos*' -or $_.TaskName -like 'ArgosProjectPortal*'
    } | Sort-Object TaskPath, TaskName | ForEach-Object { Get-TaskRecord $_ })
}

function Assert-ProtectedTasksUnchanged {
    param([object[]]$Before, [object[]]$After)
    if ($Before.Count -ne $After.Count) { throw 'Protected Argos task cardinality changed.' }
    foreach ($row in $Before) {
        $match = @($After | Where-Object {
            [string]$_.name -eq [string]$row.name -and [string]$_.taskPath -eq [string]$row.taskPath
        })
        if ($match.Count -ne 1 -or
            [string]$match[0].principal -ne [string]$row.principal -or
            [string]$match[0].definitionSha256 -ne [string]$row.definitionSha256) {
            throw "Protected task definition or principal changed: $($row.name)"
        }
    }
}

function Get-ExactScriptProcesses {
    param([string]$ScriptPath)
    $fullPath = [IO.Path]::GetFullPath($ScriptPath)
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction Stop | Where-Object {
        $commandLine = [string](Get-OptionalProperty $_ 'CommandLine' '')
        $commandLine.IndexOf($fullPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
    } | ForEach-Object {
        [pscustomobject]@{
            processId = [int]$_.ProcessId
            creationUtc = ([DateTime]$_.CreationDate).ToUniversalTime().ToString('o')
        }
    })
}

function Wait-ExactProcessCount {
    param([string]$ScriptPath, [int]$ExpectedCount, [int]$TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $rows = @(Get-ExactScriptProcesses $ScriptPath)
        if ($rows.Count -eq $ExpectedCount) { return $rows }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "Exact process count did not become $ExpectedCount for $ScriptPath; observed $($rows.Count)."
}

function Stop-ExactTask {
    param([string]$TaskName, [string]$ScriptPath)
    $task = Get-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    if ([string]$task.State -eq 'Running') {
        Stop-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    }
    [void](Wait-ExactProcessCount -ScriptPath $ScriptPath -ExpectedCount 0 -TimeoutSeconds 60)
}

function Start-ExactTask {
    param([string]$TaskName, [string]$ScriptPath)
    Start-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    return @(Wait-ExactProcessCount -ScriptPath $ScriptPath -ExpectedCount 1 -TimeoutSeconds 90)
}

function Restore-InstalledPredecessors {
    param([string]$PriorRoot)
    if (-not (Test-Path -LiteralPath $PriorRoot -PathType Container)) {
        throw "Endpoint predecessor evidence root is missing: $PriorRoot"
    }
    $priorFiles = @(Get-ChildItem -LiteralPath $PriorRoot -File -Filter '*.prior' -ErrorAction Stop)
    foreach ($name in $predecessorHashes.Keys) {
        $expected = [string]$predecessorHashes[$name]
        $matches = @($priorFiles | Where-Object { (Get-Sha256 $_.FullName) -eq $expected })
        if ($matches.Count -ne 1) { throw "Expected one predecessor evidence file for $name; observed $($matches.Count)." }
        $destination = Join-Path $processorRoot $name
        $stage = Join-Path $processorRoot ('.AVS1_RESTORE_' + $name + '.stage')
        if (Test-Path -LiteralPath $stage) { throw "Refusing pre-existing restore stage: $stage" }
        Copy-Item -LiteralPath $matches[0].FullName -Destination $stage -ErrorAction Stop
        if ((Get-Sha256 $stage) -ne $expected) { throw "Restore stage hash mismatch: $name" }
        [IO.File]::Replace($stage, $destination, $null)
        if ((Get-Sha256 $destination) -ne $expected) { throw "Installed predecessor restore failed: $name" }
    }
}

function Assert-PayloadHashes {
    foreach ($name in $targetHashes.Keys) {
        $path = Join-Path $PSScriptRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "AVS1 payload file is missing: $name" }
        if ((Get-Sha256 $path) -ne [string]$targetHashes[$name]) { throw "AVS1 payload hash mismatch: $name" }
    }
}

Assert-PayloadHashes
if ($Preflight) {
    [ordered]@{
        schema = 'argos_avs1_entrypoint_preflight_v1'
        state = 'PASS_AVS1_NON_MUTATING_PREFLIGHT'
        payloadFiles = $targetHashes.Count
        mutationsPerformed = $false
        reviewOnly = $true
        xmlExportEnabled = $false
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 4
    return
}

$runnerPath = Join-Path $processorRoot 'Run-JbodAllWaferProcessor.ps1'
$inventoryPath = Join-Path $processorRoot 'Invoke-JbodAllWaferInventory.ps1'
$trayPath = Join-Path $processorRoot 'Show-JbodAllWaferTray.ps1'
$statusPath = Join-Path $processorRoot 'processor\PROCESSOR_STATUS.json'
$catalogPath = Join-Path $processorRoot 'catalog\ALL_WAFER_CATALOG.json'
$dashboardPath = Join-Path $processorRoot 'dashboard_manifest.json'
$processorStopped = $false
$trayStopped = $false
$localRestoreRequired = $false
$priorRoot = ''
$tasksBefore = @()
$processorBefore = @()
$trayBefore = @()

try {
    foreach ($name in $targetHashes.Keys) {
        $path = Join-Path $processorRoot $name
        if ((Get-Sha256 $path) -ne [string]$targetHashes[$name]) { throw "Installed target hash mismatch: $name" }
    }
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ([string]$config.schema -ne 'argos_jbod_all_wafer_processor_config_v3' -or
        -not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or
        [bool](Get-OptionalProperty $config 'productionRoutingEnabled' $false) -or
        [bool](Get-OptionalProperty $config 'processorCooperativeHold' $false) -or
        [IO.Path]::GetFullPath([string]$config.stateRoot).TrimEnd('\') -ne $processorRoot) {
        throw 'Processor safety config changed.'
    }
    $inventoryCommand = Get-Command -Name $inventoryPath
    if ($inventoryCommand.Parameters.Keys -contains 'MetadataSnapshotRoot') { throw 'Inventory unexpectedly declares MetadataSnapshotRoot.' }
    if ([IO.File]::ReadAllText($runnerPath) -match '(?m)^\s*-MetadataSnapshotRoot\b') { throw 'Runner still passes MetadataSnapshotRoot.' }

    $packageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $requestManifest = Get-Content -LiteralPath (Join-Path $packageRoot 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
    $priorRoot = Join-Path 'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance' ([string]$requestManifest.requestId + '\prior')

    $tasksBefore = @(Read-ProtectedTasks)
    if ($tasksBefore.Count -ne 13) { throw "Expected 13 protected Argos tasks; observed $($tasksBefore.Count)." }
    $processorTask = @($tasksBefore | Where-Object { [string]$_.name -eq $processorTaskName })
    $trayTask = @($tasksBefore | Where-Object { [string]$_.name -eq $trayTaskName })
    if ($processorTask.Count -ne 1 -or [string]$processorTask[0].principal -ne 'SYSTEM' -or
        [string]$processorTask[0].definitionSha256 -ne $processorTaskDefinitionSha256) {
        throw 'Exact processor task principal or definition changed.'
    }
    if ($trayTask.Count -ne 1 -or [string]$trayTask[0].principal -ne 'lwm' -or
        [string]$trayTask[0].definitionSha256 -ne $trayTaskDefinitionSha256) {
        throw 'Exact tray task principal or definition changed.'
    }
    $processorAction = (@($processorTask[0].actions) | ForEach-Object { ([string]$_.execute) + ' ' + ([string]$_.arguments) }) -join ' '
    $trayAction = (@($trayTask[0].actions) | ForEach-Object { ([string]$_.execute) + ' ' + ([string]$_.arguments) }) -join ' '
    if (@($processorTask[0].actions).Count -ne 1 -or $processorAction.IndexOf($runnerPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Exact processor task action changed.'
    }
    if (@($trayTask[0].actions).Count -ne 1 -or $trayAction.IndexOf($trayPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Exact tray task action changed.'
    }

    $processorBefore = @(Get-ExactScriptProcesses $runnerPath)
    $trayBefore = @(Get-ExactScriptProcesses $trayPath)
    if ($processorBefore.Count -gt 1 -or $trayBefore.Count -gt 1) { throw 'Exact processor or tray process is duplicated.' }

    $localRestoreRequired = $true
    Stop-ExactTask -TaskName $processorTaskName -ScriptPath $runnerPath
    $processorStopped = $true

    $planStart = [DateTime]::UtcNow
    $null = & $runnerPath -ConfigPath $configPath -Once -PlanOnly
    $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    if ([string]$status.state -ne 'PLAN_ONLY' -or ([DateTime]$status.updatedUtc).ToUniversalTime() -lt $planStart) {
        throw 'Exact live runner PlanOnly status did not refresh.'
    }
    $targetRows = @($catalog.acquisitions | Where-Object {
        [string]$_.physicalIdentity -like '62631-586_20260819173317_*' -and [string]$_.domain -eq 'FRONTSIDE'
    })
    $targetUnique = @($targetRows | Group-Object physicalIdentity)
    $targetReady = @($targetRows | Where-Object {
        [string]$_.routeState -eq 'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING' -and
        [string]$_.metadataState -eq 'SCRIBE_CONFIRMED_MES_SNAPSHOT' -and
        [string]$_.identityState -in @(
            'HUMAN_CONFIRMED_REVIEW_ONLY',
            'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY',
            'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY'
        )
    })
    if ($targetRows.Count -ne 10 -or $targetUnique.Count -ne 10 -or $targetReady.Count -ne 10) {
        throw "Live PlanOnly target gate failed: rows=$($targetRows.Count), unique=$($targetUnique.Count), ready=$($targetReady.Count)."
    }

    $dashboard = Get-Content -LiteralPath $dashboardPath -Raw | ConvertFrom-Json
    $frontDashboardRows = @($dashboard.scanSessions | ForEach-Object { $_.wafers } | Where-Object {
        [string]$_.metadata.domain -eq 'FRONTSIDE'
    })
    $frontDashboardUnique = @($frontDashboardRows | Group-Object identity)
    $historicalFrontRows = @($frontDashboardRows | Where-Object {
        [string]$_.metadata.resultFingerprintState -eq 'HISTORICAL_COMPLETED_SUPERSEDED_CURRENT_FINGERPRINT'
    })
    if ($frontDashboardRows.Count -ne 32 -or $frontDashboardUnique.Count -ne 32 -or $historicalFrontRows.Count -ne 3) {
        throw "Live dashboard reconciliation failed: rows=$($frontDashboardRows.Count), unique=$($frontDashboardUnique.Count), historical=$($historicalFrontRows.Count)."
    }

    $processorRestartUtc = [DateTime]::UtcNow
    $processorAfter = @(Start-ExactTask -TaskName $processorTaskName -ScriptPath $runnerPath)
    $processorStopped = $false
    $heartbeatDeadline = (Get-Date).AddSeconds(120)
    do {
        Start-Sleep -Seconds 1
        $liveStatus = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        $heartbeatReady = ([DateTime]$liveStatus.updatedUtc).ToUniversalTime() -ge $processorRestartUtc -and [string]$liveStatus.state -ne 'PLAN_ONLY'
    } while (-not $heartbeatReady -and (Get-Date) -lt $heartbeatDeadline)
    if (-not $heartbeatReady) { throw 'Fresh processor task did not produce a post-restart heartbeat.' }

    Stop-ExactTask -TaskName $trayTaskName -ScriptPath $trayPath
    $trayStopped = $true
    $trayAfter = @(Start-ExactTask -TaskName $trayTaskName -ScriptPath $trayPath)
    $trayStopped = $false

    $tasksAfter = @(Read-ProtectedTasks)
    Assert-ProtectedTasksUnchanged -Before $tasksBefore -After $tasksAfter
    if ($processorBefore.Count -eq 1 -and [int]$processorAfter[0].processId -eq [int]$processorBefore[0].processId) {
        throw 'Processor task process was not replaced.'
    }
    if ($trayBefore.Count -eq 1 -and [int]$trayAfter[0].processId -eq [int]$trayBefore[0].processId) {
        throw 'Tray task process was not replaced.'
    }

    $localRestoreRequired = $false
    [ordered]@{
        schema = 'argos_avs1_apply_result_v1'
        state = 'PASS_AVS1_ALL_VALID_INSPECTIONS_VISIBILITY_RECOVERY'
        changedFiles = 5
        directCallParameterSurfaces = 'PASS'
        planOnlyState = [string]$status.state
        targetFrontRows = $targetRows.Count
        targetFrontReady = $targetReady.Count
        frontDashboardRows = $frontDashboardRows.Count
        frontDashboardUnique = $frontDashboardUnique.Count
        historicalFrontRows = $historicalFrontRows.Count
        processorPid = [int]$processorAfter[0].processId
        trayPid = [int]$trayAfter[0].processId
        postRestartProcessorState = [string]$liveStatus.state
        protectedTasks = $tasksAfter.Count
        queueRefreshPerformed = $true
        ledgerDirectMutationPerformed = $false
        sourceImagesChanged = $false
        waferActionPerformed = $false
        reviewOnly = $true
        xmlExportEnabled = $false
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
}
catch {
    $failure = $_
    if ($localRestoreRequired) {
        try {
            Stop-ExactTask -TaskName $processorTaskName -ScriptPath $runnerPath
            $processorStopped = $true
            Stop-ExactTask -TaskName $trayTaskName -ScriptPath $trayPath
            $trayStopped = $true
            Restore-InstalledPredecessors -PriorRoot $priorRoot
            if ($processorBefore.Count -eq 1) { [void](Start-ExactTask -TaskName $processorTaskName -ScriptPath $runnerPath); $processorStopped = $false }
            if ($trayBefore.Count -eq 1) { [void](Start-ExactTask -TaskName $trayTaskName -ScriptPath $trayPath); $trayStopped = $false }
        }
        catch {
            throw "AVS1 failed and local predecessor/task recovery also failed. Original: $($failure.Exception.Message) Recovery: $($_.Exception.Message)"
        }
    }
    throw $failure
}
