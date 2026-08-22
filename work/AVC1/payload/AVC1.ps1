[CmdletBinding()]
param(
    [switch]$Preflight,
    [string]$InstallRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$liveInstallRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$processorTaskName = 'ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'
$trayTaskName = 'ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2'
$processorTaskDefinitionSha256 = '6E306778640AF823C53422411E65F9A796075392DEA25306F59FE7EDB8259B17'
$trayTaskDefinitionSha256 = 'E3D78B9802BC4599CEC37BCC80F01BC8A0086B398CCABC25163DE4AEFC0C419F'
$targetHashes = [ordered]@{
    'Run-JbodAllWaferProcessor.ps1' = '8EB83C05CA650C831D2DE8A6AB89ABD2941271B05B31FA93BCFFB553DEAAA892'
    'Invoke-JbodAllWaferInventory.ps1' = 'BF0BAF295F3D1F3234C5C2A5DE184AFEA4BE446BB9593BE9E10BB0E8F932F50A'
    'Invoke-JbodAllWaferProcessingPass.ps1' = '8050EEB71923DC69EBD0A81F6C95840A7BD6215998E8546F9170C5A051B936EB'
    'Update-JbodDashboardManifest.ps1' = 'F73AC7C38139098B079A23CC9C7653A93D7464BE1D4376708B25B3346B704E5D'
    'Show-JbodAllWaferTray.ps1' = 'C03812C6889B102DFD9B3CB466E70B06B8943C1123A882EB0ADE972C641DAB2B'
}
$predecessorHashes = [ordered]@{
    'Run-JbodAllWaferProcessor.ps1' = '46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
    'Invoke-JbodAllWaferInventory.ps1' = '8919C3DD4AC04FD662B57E356AC6E1A70BD614E97AFC270EB4B8FF617D705160'
    'Invoke-JbodAllWaferProcessingPass.ps1' = '0B063D452CA76AE5EE3EC1BDF6726853259039683C36E208718B8FE937D23753'
    'Update-JbodDashboardManifest.ps1' = 'DCF97D92BDA0A82A49DA277D54CFD1BC7802068CD8B9D89340534CC892792BAD'
    'Show-JbodAllWaferTray.ps1' = '769ACAD731F8EA04C1820AB90CCA80591A132CEDDFCF44611B54D9BB2A41FB45'
}
$identityStates = @(
    'HUMAN_CONFIRMED_REVIEW_ONLY',
    'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY',
    'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY'
)

function Get-OptionalProperty {
    param([object]$Object, [string]$Name, $Default)
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $Default }
    return $property.Value
}

function Get-Sha256 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required file is missing: $Path" }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Get-TextSha256 {
    param([string]$Text)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Assert-PowerShellParse {
    param([string]$Path)
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "PowerShell parse failed for $Path`: $($errors[0].Message)" }
}

function Assert-PayloadContract {
    foreach ($name in $targetHashes.Keys) {
        $path = Join-Path $PSScriptRoot $name
        if ((Get-Sha256 $path) -ne [string]$targetHashes[$name]) { throw "AVC1 payload hash mismatch: $name" }
        Assert-PowerShellParse $path
    }
    $runnerText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Run-JbodAllWaferProcessor.ps1'))
    if ($runnerText -match '(?m)^\s*-MetadataSnapshotRoot\b') { throw 'Runner still passes the unsupported MetadataSnapshotRoot argument.' }
    foreach ($name in @('Invoke-JbodAllWaferInventory.ps1', 'Invoke-JbodAllWaferProcessingPass.ps1', 'Update-JbodDashboardManifest.ps1')) {
        $text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot $name))
        foreach ($state in $identityStates) {
            if (-not $text.Contains($state)) { throw "Identity-state contract is incomplete in $name`: $state" }
        }
    }
    $dashboardText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Update-JbodDashboardManifest.ps1'))
    if ($dashboardText.Contains('HISTORICAL_COMPLETED_SUPERSEDED_CURRENT_FINGERPRINT') -or
        $dashboardText.Contains('resultFingerprintState')) {
        throw 'Unsafe historical-result substitution is present in the dashboard payload.'
    }
    $trayText = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Show-JbodAllWaferTray.ps1'))
    if ($trayText.Contains('$script:lastActivityKey') -or -not $trayText.Contains('$form.Tag.LastActivityKey')) {
        throw 'Tray callback state is not anchored on the captured form object.'
    }
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

function Start-ExactTask {
    param([string]$TaskName, [string]$ScriptPath)
    Start-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    $first = @(Wait-ExactProcessCount -ScriptPath $ScriptPath -ExpectedCount 1 -TimeoutSeconds 90)
    Start-Sleep -Seconds 2
    $second = @(Get-ExactScriptProcesses $ScriptPath)
    if ($second.Count -ne 1 -or [int]$second[0].processId -ne [int]$first[0].processId) {
        throw "Exact process was not stable after starting $TaskName."
    }
    return $second
}

function Stop-TaskStartedHere {
    param([string]$TaskName, [string]$ScriptPath)
    Stop-ScheduledTask -TaskName $TaskName -TaskPath '\' -ErrorAction Stop
    [void](Wait-ExactProcessCount -ScriptPath $ScriptPath -ExpectedCount 0 -TimeoutSeconds 60)
}

Assert-PayloadContract
$resolvedInstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')

if ($Preflight) {
    if (-not (Test-Path -LiteralPath $resolvedInstallRoot -PathType Container)) {
        throw "AVC1 preflight install root is missing: $resolvedInstallRoot"
    }
    $predecessorMatches = 0
    $targetMatches = 0
    foreach ($name in $targetHashes.Keys) {
        $observed = Get-Sha256 (Join-Path $resolvedInstallRoot $name)
        if ($observed -eq [string]$predecessorHashes[$name]) { $predecessorMatches++ }
        elseif ($observed -eq [string]$targetHashes[$name]) { $targetMatches++ }
        else { throw "AVC1 preflight found an unapproved installed hash: $name $observed" }
    }
    if (($predecessorMatches -ne $targetHashes.Count -and $targetMatches -ne $targetHashes.Count)) {
        throw "AVC1 preflight refuses a mixed predecessor/target install: predecessor=$predecessorMatches target=$targetMatches."
    }
    [ordered]@{
        schema = 'argos_avc1_entrypoint_preflight_v1'
        state = 'PASS_AVC1_NON_MUTATING_PREFLIGHT'
        payloadFiles = $targetHashes.Count
        installedState = $(if ($predecessorMatches -eq $targetHashes.Count) { 'COHERENT_PREDECESSOR' } else { 'COHERENT_TARGET' })
        mutationsPerformed = $false
        reviewOnly = $true
        xmlExportEnabled = $false
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 4
    return
}

if (-not $resolvedInstallRoot.Equals($liveInstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'AVC1 apply is restricted to the exact live processor root.'
}

$configPath = Join-Path $resolvedInstallRoot 'PROCESSOR_CONFIG.json'
$runnerPath = Join-Path $resolvedInstallRoot 'Run-JbodAllWaferProcessor.ps1'
$inventoryPath = Join-Path $resolvedInstallRoot 'Invoke-JbodAllWaferInventory.ps1'
$trayPath = Join-Path $resolvedInstallRoot 'Show-JbodAllWaferTray.ps1'
$statusPath = Join-Path $resolvedInstallRoot 'processor\PROCESSOR_STATUS.json'
$catalogPath = Join-Path $resolvedInstallRoot 'catalog\ALL_WAFER_CATALOG.json'
$processorStarted = $false
$trayStarted = $false

try {
    foreach ($name in $targetHashes.Keys) {
        if ((Get-Sha256 (Join-Path $resolvedInstallRoot $name)) -ne [string]$targetHashes[$name]) {
            throw "Installed AVC1 target hash mismatch: $name"
        }
    }
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if ([string]$config.schema -ne 'argos_jbod_all_wafer_processor_config_v3' -or
        -not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or
        [bool](Get-OptionalProperty $config 'productionRoutingEnabled' $false) -or
        [bool](Get-OptionalProperty $config 'processorCooperativeHold' $false) -or
        [IO.Path]::GetFullPath([string]$config.stateRoot).TrimEnd('\') -ne $resolvedInstallRoot) {
        throw 'Processor safety config changed.'
    }
    $inventoryCommand = Get-Command -Name $inventoryPath
    if ($inventoryCommand.Parameters.Keys -contains 'MetadataSnapshotRoot') {
        throw 'Inventory unexpectedly declares MetadataSnapshotRoot.'
    }

    $tasksBefore = @(Read-ProtectedTasks)
    if ($tasksBefore.Count -ne 13) { throw "Expected 13 protected Argos tasks; observed $($tasksBefore.Count)." }
    $processorTask = @($tasksBefore | Where-Object { [string]$_.name -eq $processorTaskName })
    $trayTask = @($tasksBefore | Where-Object { [string]$_.name -eq $trayTaskName })
    if ($processorTask.Count -ne 1 -or
        -not ([string]$processorTask[0].principal).Equals('SYSTEM', [StringComparison]::OrdinalIgnoreCase) -or
        [string]$processorTask[0].definitionSha256 -ne $processorTaskDefinitionSha256 -or
        [string]$processorTask[0].state -ne 'Ready') {
        throw 'Exact processor task identity, definition, principal, or stopped state changed.'
    }
    if ($trayTask.Count -ne 1 -or
        -not ([string]$trayTask[0].principal).Equals('lwm', [StringComparison]::OrdinalIgnoreCase) -or
        [string]$trayTask[0].definitionSha256 -ne $trayTaskDefinitionSha256 -or
        [string]$trayTask[0].state -ne 'Ready') {
        throw 'Exact tray task identity, definition, principal, or stopped state changed.'
    }
    if (@($processorTask[0].actions).Count -ne 1 -or
        ([string]$processorTask[0].actions[0].arguments).IndexOf($runnerPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Exact processor task action changed.'
    }
    if (@($trayTask[0].actions).Count -ne 1 -or
        ([string]$trayTask[0].actions[0].arguments).IndexOf($trayPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Exact tray task action changed.'
    }
    if (@(Get-ExactScriptProcesses $runnerPath).Count -ne 0 -or
        @(Get-ExactScriptProcesses $trayPath).Count -ne 0) {
        throw 'Processor or tray process exists while its exact task is expected stopped.'
    }

    $planStartUtc = [DateTime]::UtcNow
    $null = & $runnerPath -ConfigPath $configPath -Once -PlanOnly
    $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
    if ([string]$status.state -ne 'PLAN_ONLY' -or
        ([DateTime]$status.updatedUtc).ToUniversalTime() -lt $planStartUtc) {
        throw 'Exact live runner PlanOnly status did not refresh.'
    }
    $targetRows = @($catalog.acquisitions | Where-Object {
        [string]$_.physicalIdentity -like '62631-586_20260819173317_*' -and
        [string]$_.domain -eq 'FRONTSIDE'
    })
    $targetGroups = @($targetRows | Group-Object physicalIdentity)
    $targetReady = @($targetRows | Where-Object {
        [string]$_.routeState -eq 'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING' -and
        [string]$_.metadataState -eq 'SCRIBE_CONFIRMED_MES_SNAPSHOT' -and
        [string]$_.identityState -in $identityStates
    })
    if ($targetRows.Count -ne 10 -or $targetGroups.Count -ne 10 -or
        @($targetGroups | Where-Object { $_.Count -ne 1 }).Count -ne 0 -or
        $targetReady.Count -ne 10) {
        throw "Live PlanOnly target gate failed: rows=$($targetRows.Count), groups=$($targetGroups.Count), ready=$($targetReady.Count)."
    }

    $trayAfter = @(Start-ExactTask -TaskName $trayTaskName -ScriptPath $trayPath)
    $trayStarted = $true
    $processorStartUtc = [DateTime]::UtcNow
    $processorAfter = @(Start-ExactTask -TaskName $processorTaskName -ScriptPath $runnerPath)
    $processorStarted = $true
    $heartbeatDeadline = (Get-Date).AddSeconds(120)
    $heartbeatReady = $false
    do {
        if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
            $liveStatus = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
            $heartbeatReady = ([DateTime]$liveStatus.updatedUtc).ToUniversalTime() -ge $processorStartUtc -and
                [string]$liveStatus.state -ne 'PLAN_ONLY'
        }
        if (-not $heartbeatReady) { Start-Sleep -Seconds 1 }
    } while (-not $heartbeatReady -and (Get-Date) -lt $heartbeatDeadline)
    if (-not $heartbeatReady) { throw 'Fresh processor task did not produce a post-start heartbeat.' }

    $tasksAfter = @(Read-ProtectedTasks)
    Assert-ProtectedTasksUnchanged -Before $tasksBefore -After $tasksAfter

    [ordered]@{
        schema = 'argos_avc1_apply_result_v1'
        state = 'PASS_AVC1_ALL_VALID_CONSUMER_REPAIR'
        changedFiles = $targetHashes.Count
        directCallParameterSurfaces = 'PASS'
        identityStateConsumers = 3
        identityStates = $identityStates
        historicalCurrentSubstitutionAllowed = $false
        planOnlyState = [string]$status.state
        targetFrontRows = $targetRows.Count
        targetFrontReady = $targetReady.Count
        processorPid = [int]$processorAfter[0].processId
        trayPid = [int]$trayAfter[0].processId
        postStartProcessorState = [string]$liveStatus.state
        protectedTasks = $tasksAfter.Count
        dashboardValidatedBeforeProducerRun = $false
        ledgerDirectMutationPerformed = $false
        sourceImagesChanged = $false
        detectorCodeChanged = $false
        waferActionPerformed = $false
        reviewOnly = $true
        xmlExportEnabled = $false
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
}
catch {
    $failure = $_
    $cleanupFailures = New-Object Collections.Generic.List[string]
    if ($processorStarted) {
        try { Stop-TaskStartedHere -TaskName $processorTaskName -ScriptPath $runnerPath }
        catch { $cleanupFailures.Add('processor: ' + $_.Exception.Message) }
    }
    if ($trayStarted) {
        try { Stop-TaskStartedHere -TaskName $trayTaskName -ScriptPath $trayPath }
        catch { $cleanupFailures.Add('tray: ' + $_.Exception.Message) }
    }
    if ($cleanupFailures.Count -gt 0) {
        throw "AVC1 failed and exact started-task cleanup also failed. Original: $($failure.Exception.Message) Cleanup: $($cleanupFailures -join '; ')"
    }
    throw $failure
}
