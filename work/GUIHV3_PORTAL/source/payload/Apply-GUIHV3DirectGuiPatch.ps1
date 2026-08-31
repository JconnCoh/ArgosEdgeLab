[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Preflight -and $Rehearsal) {
    throw 'Specify at most one of -Preflight or -Rehearsal.'
}

$packageRoot = Split-Path -Parent $PSScriptRoot
$packageLeaf = Split-Path -Leaf $packageRoot
if ($packageLeaf -notmatch '^(REQ_[A-Z0-9_]+)\.ready$') {
    throw 'Maintenance package root does not expose an exact request identity.'
}
$requestId = [string]$Matches[1]
$installRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$trayTaskName = 'ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2'
$trayTaskPrincipal = 'lwm'
$trayTaskDefinitionSha256 = 'E3D78B9802BC4599CEC37BCC80F01BC8A0086B398CCABC25163DE4AEFC0C419F'
$processorTaskName = 'ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'
$dashboardUpdaterSha256 = '73C2289B58F6F6B23DD2FA12E847AFF171B3FAC45153202E93EE00E0B7533FBA'

$targetSpecs = @(
    [pscustomobject]@{
        index = 1
        relativePath = 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        payloadName = 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        predecessorName = '1'
        targetSha256 = '5A1320BD3E7430A054E859B3F26ACC3B665A89A687EFF4B6472E565BDF1278F1'
        approvedPredecessors = @(
            'FD2ABADC0494C0FABA81452B18FB7D860AF7B4F32CA086018D0907E2885B1225',
            '5A1320BD3E7430A054E859B3F26ACC3B665A89A687EFF4B6472E565BDF1278F1'
        )
    },
    [pscustomobject]@{
        index = 2
        relativePath = 'runtime\viewer\ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        payloadName = 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        predecessorName = '2'
        targetSha256 = '5A1320BD3E7430A054E859B3F26ACC3B665A89A687EFF4B6472E565BDF1278F1'
        approvedPredecessors = @(
            'FD2ABADC0494C0FABA81452B18FB7D860AF7B4F32CA086018D0907E2885B1225',
            '5A1320BD3E7430A054E859B3F26ACC3B665A89A687EFF4B6472E565BDF1278F1'
        )
    },
    [pscustomobject]@{
        index = 3
        relativePath = 'runtime\viewer\Program.cs'
        payloadName = 'Program.cs'
        predecessorName = '3'
        targetSha256 = 'CBF4CB8333D8E7F9A397F480E16F18DF9E1D7DFB789397D023A696E8DFC07944'
        approvedPredecessors = @(
            'CA69813161A862FF1623AE1989D18F8E6B1394901B2C1BAC279F97307AA07B2C',
            'CBF4CB8333D8E7F9A397F480E16F18DF9E1D7DFB789397D023A696E8DFC07944'
        )
    }
)

function Get-OptionalValue {
    param(
        [object]$Object,
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Object) {
        return $Default
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-TextSha256 {
    param([string]$Text)

    $encoding = New-Object Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

function Assert-PathBudget {
    param([string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path)
    $maximumComponentLength = 0
    foreach ($component in $fullPath.Split([IO.Path]::DirectorySeparatorChar, [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($component.Length -gt $maximumComponentLength) {
            $maximumComponentLength = $component.Length
        }
    }

    if (($fullPath.Length + 32) -ge 200 -or $maximumComponentLength -gt 80) {
        throw "GUIHV3 path budget refused: $fullPath"
    }

    return $fullPath
}

function Get-TaskSnapshot {
    if ($script:IsFixture) {
        return @($script:Fixture.tasks)
    }

    $tasks = @(
        Get-ScheduledTask -ErrorAction Stop |
            Where-Object {
                $_.TaskName -like 'Argos*' -or
                $_.TaskName -like 'ArgosProjectPortal*'
            } |
            Sort-Object TaskPath, TaskName
    )

    $rows = @(
        foreach ($task in $tasks) {
            $definition = Export-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath
            $actions = @(
                foreach ($action in @($task.Actions)) {
                    [pscustomobject]@{
                        execute = [string](Get-OptionalValue -Object $action -Name 'Execute' -Default '')
                        arguments = [string](Get-OptionalValue -Object $action -Name 'Arguments' -Default '')
                    }
                }
            )

            [pscustomobject]@{
                name = [string]$task.TaskName
                taskPath = [string]$task.TaskPath
                principal = [string]$task.Principal.UserId
                state = [string]$task.State
                definitionSha256 = Get-TextSha256 -Text $definition
                actions = $actions
            }
        }
    )

    return $rows
}

function Convert-CimCreationDateToUtcString {
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) {
        throw 'Process CreationDate is null.'
    }

    if ($Value -is [DateTime]) {
        return ([DateTime]$Value).ToUniversalTime().ToString('o')
    }

    $dmtfText = [string]$Value
    if ($dmtfText -notmatch '^\d{14}\.\d{6}[+-]\d{3}$') {
        throw 'Process CreationDate is neither a DateTime nor an exact DMTF timestamp.'
    }

    return ([Management.ManagementDateTimeConverter]::ToDateTime($dmtfText)).ToUniversalTime().ToString('o')
}

function Get-ExactProcessRows {
    param([ValidateSet('tray', 'processor')][string]$Kind)

    if ($script:IsFixture) {
        if ($Kind -eq 'tray') {
            return @($script:FixtureTrayProcesses)
        }
        return @($script:Fixture.processorProcesses)
    }

    $scriptLeaf = if ($Kind -eq 'tray') {
        'Show-JbodAllWaferTray.ps1'
    }
    else {
        'Run-JbodAllWaferProcessor.ps1'
    }

    $consoleHostName = 'power' + 'shell.exe'
    $iseHostName = 'power' + 'shell_ise.exe'
    $processes = @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object {
                [string]$_.Name -eq $consoleHostName -or
                [string]$_.Name -eq $iseHostName
            }
    )

    $rows = @(
        foreach ($process in $processes) {
            $commandLine = [string]$process.CommandLine
            if (
                $commandLine.IndexOf($scriptLeaf, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                $commandLine.IndexOf($script:InstallRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
            ) {
                [pscustomobject]@{
                    processId = [int]$process.ProcessId
                    sessionId = [int]$process.SessionId
                    creationUtc = Convert-CimCreationDateToUtcString -Value $process.CreationDate
                }
            }
        }
    )

    return $rows
}

function Compare-TaskSnapshots {
    param(
        [object[]]$Before,
        [object[]]$After
    )

    if ($Before.Count -ne $After.Count) {
        throw 'Protected task count changed.'
    }

    for ($index = 0; $index -lt $Before.Count; $index++) {
        foreach ($propertyName in @('name', 'taskPath', 'principal', 'definitionSha256')) {
            if ([string]$Before[$index].$propertyName -ne [string]$After[$index].$propertyName) {
                throw "Protected task changed: $([string]$Before[$index].name)"
            }
        }

        $beforeActions = @($Before[$index].actions)
        $afterActions = @($After[$index].actions)
        if ($beforeActions.Count -ne $afterActions.Count) {
            throw "Protected task action count changed: $([string]$Before[$index].name)"
        }

        for ($actionIndex = 0; $actionIndex -lt $beforeActions.Count; $actionIndex++) {
            if (
                [string]$beforeActions[$actionIndex].execute -ne [string]$afterActions[$actionIndex].execute -or
                [string]$beforeActions[$actionIndex].arguments -ne [string]$afterActions[$actionIndex].arguments
            ) {
                throw "Protected task action changed: $([string]$Before[$index].name)"
            }
        }
    }
}

function Close-ExactViewer {
    if ($script:IsFixture) {
        $closedCount = [int](Get-OptionalValue -Object $script:Fixture -Name 'viewerProcessCount' -Default 0)
        return [pscustomobject]@{ closed = $closedCount; forced = 0 }
    }

    $initial = @(Get-Process -Name 'ArgosEdgeLab.JbodCompositeAccepted.V1_2' -ErrorAction SilentlyContinue)
    foreach ($process in $initial) {
        [void]$process.CloseMainWindow()
    }

    $deadline = (Get-Date).AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @(Get-Process -Name 'ArgosEdgeLab.JbodCompositeAccepted.V1_2' -ErrorAction SilentlyContinue)
    }
    while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

    $forcedCount = 0
    foreach ($process in $remaining) {
        Stop-Process -Id $process.Id -Force -ErrorAction Stop
        $forcedCount++
    }

    $final = @(Get-Process -Name 'ArgosEdgeLab.JbodCompositeAccepted.V1_2' -ErrorAction SilentlyContinue)
    if ($final.Count -ne 0) {
        throw 'Exact Completed Lots viewer did not exit.'
    }

    return [pscustomobject]@{ closed = $initial.Count; forced = $forcedCount }
}

function Stop-ExactTray {
    $before = @(Get-ExactProcessRows -Kind tray)
    if ($before.Count -gt 1) {
        throw 'Exact tray process is ambiguous.'
    }

    if ($script:IsFixture) {
        $script:FixtureTrayProcesses = @()
        return [pscustomobject]@{
            taskStopIssued = ($before.Count -eq 1)
            forced = $false
            beforeCount = $before.Count
        }
    }

    $task = Get-ScheduledTask -TaskName $trayTaskName -ErrorAction Stop
    $taskStopIssued = $false
    if ([string]$task.State -eq 'Running' -or $before.Count -eq 1) {
        Stop-ScheduledTask -TaskName $trayTaskName -ErrorAction Stop
        $taskStopIssued = $true
    }

    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @(Get-ExactProcessRows -Kind tray)
    }
    while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

    $forced = $false
    if ($remaining.Count -eq 1) {
        Stop-Process -Id ([int]$remaining[0].processId) -Force -ErrorAction Stop
        $forced = $true
    }

    $deadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Milliseconds 250
        $remaining = @(Get-ExactProcessRows -Kind tray)
    }
    while ($remaining.Count -gt 0 -and (Get-Date) -lt $deadline)

    if ($remaining.Count -ne 0) {
        throw 'Exact tray process did not exit.'
    }

    return [pscustomobject]@{
        taskStopIssued = $taskStopIssued
        forced = $forced
        beforeCount = $before.Count
    }
}

function Start-ExactTray {
    if ($script:IsFixture) {
        $script:FixtureTrayProcesses = @(
            [pscustomobject]@{
                processId = 9109
                sessionId = 2
                creationUtc = [DateTime]::UtcNow.ToString('o')
            }
        )
        return
    }

    Start-ScheduledTask -TaskName $trayTaskName -ErrorAction Stop
}

function Get-StableTray {
    if ($script:IsFixture) {
        $fixtureProcesses = @($script:FixtureTrayProcesses)
        if ($fixtureProcesses.Count -ne 1) {
            throw 'Fixture tray did not become stable.'
        }
        return $fixtureProcesses[0]
    }

    $deadline = (Get-Date).AddSeconds(60)
    $first = $null
    do {
        Start-Sleep -Milliseconds 500
        $processes = @(Get-ExactProcessRows -Kind tray)
        if ($processes.Count -eq 1) {
            $first = $processes[0]
            break
        }
    }
    while ((Get-Date) -lt $deadline)

    if ($null -eq $first) {
        throw 'Exact tray process did not appear.'
    }

    Start-Sleep -Seconds 5
    $final = @(Get-ExactProcessRows -Kind tray)
    if ($final.Count -ne 1 -or [int]$final[0].processId -ne [int]$first.processId) {
        throw 'Exact tray process did not remain stable.'
    }

    return $final[0]
}

function Get-PriorRows {
    param([string]$PriorRoot)

    $rows = @(
        foreach ($spec in $targetSpecs) {
            $destination = Assert-PathBudget -Path (Join-Path $script:InstallRoot $spec.relativePath)
            $priorPath = Assert-PathBudget -Path (Join-Path $PriorRoot $spec.predecessorName)

            if (-not (Test-Path -LiteralPath $priorPath -PathType Leaf)) {
                throw "Signed JBOD predecessor copy is missing: $($spec.relativePath)"
            }

            $priorSha256 = Get-Sha256 -Path $priorPath
            if (@($spec.approvedPredecessors) -notcontains $priorSha256) {
                throw "Signed JBOD predecessor copy is unapproved: $($spec.relativePath)"
            }

            [pscustomobject]@{
                relativePath = [string]$spec.relativePath
                destination = $destination
                prior = $priorPath
                priorSha256 = $priorSha256
                targetSha256 = [string]$spec.targetSha256
            }
        }
    )

    return $rows
}

function Restore-PriorFiles {
    param([object[]]$PriorRows)

    foreach ($row in $PriorRows) {
        Copy-Item -LiteralPath $row.prior -Destination $row.destination -Force -ErrorAction Stop
        if ((Get-Sha256 -Path $row.destination) -ne [string]$row.priorSha256) {
            throw "Predecessor restore failed: $([string]$row.relativePath)"
        }
    }
}

$fixturePath = ''
if ($Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) {
        throw 'Rehearsal requires -InvocationManifest.'
    }
    $fixturePath = $InvocationManifest
}
elseif ($Preflight -and -not [string]::IsNullOrWhiteSpace($InvocationManifest)) {
    $fixturePath = $InvocationManifest
}
else {
    $fixturePath = [Environment]::GetEnvironmentVariable('ARGOS_GUIHV3_REHEARSAL_MANIFEST', 'Process')
}

$fixture = $null
$isFixture = -not [string]::IsNullOrWhiteSpace($fixturePath)
if ($isFixture) {
    $fixturePath = [IO.Path]::GetFullPath($fixturePath)
    $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    if ([string]$fixture.schema -ne 'argos_guihv3_direct_patch_rehearsal_v1' -or -not [bool]$fixture.rehearsal) {
        throw 'GUIHV3 rehearsal fixture changed.'
    }
    $installRoot = [IO.Path]::GetFullPath([string]$fixture.installRoot)
}

$script:IsFixture = $isFixture
$script:Fixture = $fixture
$script:InstallRoot = [IO.Path]::GetFullPath($installRoot).TrimEnd('\')
$script:FixtureTrayProcesses = @(
    if ($isFixture) {
        @($fixture.trayProcessesBefore)
    }
)

$payloadRows = @(
    foreach ($spec in $targetSpecs) {
        $payloadPath = Assert-PathBudget -Path (Join-Path $PSScriptRoot $spec.payloadName)
        if (-not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw "GUIHV3 payload is missing: $($spec.payloadName)"
        }
        if ((Get-Sha256 -Path $payloadPath) -ne [string]$spec.targetSha256) {
            throw "GUIHV3 payload hash changed: $($spec.payloadName)"
        }

        $destination = Assert-PathBudget -Path (Join-Path $script:InstallRoot $spec.relativePath)
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            throw "GUIHV3 destination is missing: $($spec.relativePath)"
        }

        $installedSha256 = Get-Sha256 -Path $destination
        if (@($spec.approvedPredecessors) -notcontains $installedSha256) {
            throw "GUIHV3 destination predecessor is unapproved: $($spec.relativePath)"
        }

        [pscustomobject]@{
            relativePath = [string]$spec.relativePath
            payloadPath = $payloadPath
            destination = $destination
            installedSha256 = $installedSha256
            targetSha256 = [string]$spec.targetSha256
        }
    }
)

$priorRoot = Assert-PathBudget -Path (Join-Path $PSScriptRoot 'p')
$priorRows = @(Get-PriorRows -PriorRoot $priorRoot)

$tasksBefore = @(Get-TaskSnapshot)
$trayTaskRows = @($tasksBefore | Where-Object { [string]$_.name -eq $trayTaskName })
if ($trayTaskRows.Count -ne 1) {
    throw 'Exact tray task is missing or ambiguous.'
}

$trayTask = $trayTaskRows[0]
if (
    [string]$trayTask.principal -ne $trayTaskPrincipal -or
    [string]$trayTask.definitionSha256 -ne $trayTaskDefinitionSha256
) {
    throw 'Exact tray task identity changed.'
}

$trayActions = @($trayTask.actions)
if ($trayActions.Count -ne 1) {
    throw 'Exact tray task action count changed.'
}

$trayCommand = ([string]$trayActions[0].execute) + ' ' + ([string]$trayActions[0].arguments)
if ($trayCommand.IndexOf($script:InstallRoot, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
    throw 'Exact tray task no longer targets the installed root.'
}

$processorTaskRows = @($tasksBefore | Where-Object { [string]$_.name -eq $processorTaskName })
if ($processorTaskRows.Count -ne 1) {
    throw 'Exact processor task is missing or ambiguous.'
}

$processorBefore = @(Get-ExactProcessRows -Kind processor)
if ($processorBefore.Count -gt 1) {
    throw 'Exact processor selector is ambiguous.'
}
$processorBeforeId = if ($processorBefore.Count -eq 1) { [int]$processorBefore[0].processId } else { 0 }
$processorBeforeCreationUtc = if ($processorBefore.Count -eq 1) { [string]$processorBefore[0].creationUtc } else { '' }
$dashboardUpdaterPath = Join-Path $script:InstallRoot 'Update-JbodDashboardManifest.ps1'
if (-not (Test-Path -LiteralPath $dashboardUpdaterPath -PathType Leaf) -or
    (Get-Sha256 -Path $dashboardUpdaterPath) -ne $dashboardUpdaterSha256) {
    throw 'Installed GUIDU1 dashboard updater premise changed.'
}

$trayBefore = @(Get-ExactProcessRows -Kind tray)
if ($trayBefore.Count -gt 1) {
    throw 'Exact tray process is ambiguous.'
}

$preflightResult = [ordered]@{
    schema = 'argos_guihv3_direct_gui_patch_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIHV3_DIRECT_GUI_ONLY_PATCH_PREFLIGHT'
    requestId = $requestId
    rehearsal = $isFixture
    payloadFileCount = @($payloadRows | Select-Object -ExpandProperty payloadPath -Unique).Count
    targetCount = $payloadRows.Count
    targetRows = @(
        $payloadRows | ForEach-Object {
            [ordered]@{
                relativePath = $_.relativePath
                installedSha256 = $_.installedSha256
                targetSha256 = $_.targetSha256
            }
        }
    )
    predecessorCopyCount = $priorRows.Count
    predecessorRows = @(
        $priorRows | ForEach-Object {
            [ordered]@{
                relativePath = $_.relativePath
                predecessorSha256 = $_.priorSha256
            }
        }
    )
    trayProcessCount = $trayBefore.Count
    processorProcessCount = $processorBefore.Count
    processorProcessId = $processorBeforeId
    dashboardUpdaterSha256 = $dashboardUpdaterSha256
    childPowerShellRunnerPresent = $false
    nestedInstallerPresent = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 10
    return
}

foreach ($row in $priorRows) {
    if ((Get-Sha256 -Path $row.destination) -ne [string]$row.targetSha256) {
        throw "Endpoint did not install the target before verification: $([string]$row.relativePath)"
    }
}

$actionsStarted = $false
$trayRestarted = $false
$viewerResult = $null
$trayStopResult = $null

try {
    $actionsStarted = $true
    $viewerResult = Close-ExactViewer
    $trayStopResult = Stop-ExactTray

    if ($isFixture -and [bool](Get-OptionalValue -Object $fixture -Name 'failAfterTargetVerification' -Default $false)) {
        throw 'INJECTED_GUIHV3_POST_TARGET_FAILURE'
    }

    Start-ExactTray
    $trayRestarted = $true
    $stableTray = Get-StableTray

    $processorAfter = @(Get-ExactProcessRows -Kind processor)
    if ($processorAfter.Count -ne $processorBefore.Count) {
        throw 'Exact processor selector count changed during GUIHV3.'
    }
    if ($processorAfter.Count -eq 1 -and (
        [int]$processorAfter[0].processId -ne $processorBeforeId -or
        [string]$processorAfter[0].creationUtc -ne $processorBeforeCreationUtc
    )) {
        throw 'Exact processor selector identity changed during GUIHV3.'
    }

    $tasksAfter = @(Get-TaskSnapshot)
    Compare-TaskSnapshots -Before $tasksBefore -After $tasksAfter
    $processorTaskAfter = @($tasksAfter | Where-Object { [string]$_.name -eq $processorTaskName })
    if ($processorTaskAfter.Count -ne 1 -or [string]$processorTaskAfter[0].state -ne [string]$processorTaskRows[0].state) {
        throw 'Processor selector task state changed during GUIHV3.'
    }
    if ((Get-Sha256 -Path $dashboardUpdaterPath) -ne $dashboardUpdaterSha256) {
        throw 'GUIDU1 dashboard updater changed during GUIHV3.'
    }

    foreach ($row in $priorRows) {
        if ((Get-Sha256 -Path $row.destination) -ne [string]$row.targetSha256) {
            throw "GUIHV3 target changed after tray activation: $([string]$row.relativePath)"
        }
    }

    [ordered]@{
        schema = 'argos_guihv3_direct_gui_patch_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_GUIHV3_DIRECT_GUI_ONLY_PATCH_AND_TRAY_ACTIVATION'
        requestId = $requestId
        rehearsal = $isFixture
        targetFiles = @(
            $priorRows | ForEach-Object {
                [ordered]@{
                    relativePath = $_.relativePath
                    predecessorSha256 = $_.priorSha256
                    installedSha256 = Get-Sha256 -Path $_.destination
                    targetSha256 = $_.targetSha256
                }
            }
        )
        trayTaskName = $trayTaskName
        trayTaskPrincipal = $trayTaskPrincipal
        trayTaskDefinitionSha256 = $trayTaskDefinitionSha256
        trayTaskStopIssued = [bool]$trayStopResult.taskStopIssued
        trayForcedStop = [bool]$trayStopResult.forced
        trayProcessId = [int]$stableTray.processId
        traySessionId = [int]$stableTray.sessionId
        trayProcessStable = $true
        viewerProcessesClosed = [int]$viewerResult.closed
        viewerForcedCloseCount = [int]$viewerResult.forced
        processorTaskName = $processorTaskName
        processorProcessCountBefore = $processorBefore.Count
        processorProcessCountAfter = $processorAfter.Count
        processorProcessIdBefore = $processorBeforeId
        processorProcessIdAfter = $(if ($processorAfter.Count -eq 1) { [int]$processorAfter[0].processId } else { 0 })
        processorProcessCreationUtc = $processorBeforeCreationUtc
        processorSelectorStateUnchanged = $true
        processorRestarted = $false
        processorTaskAction = $false
        dashboardUpdaterSha256 = $dashboardUpdaterSha256
        dashboardUpdaterChanged = $false
        protectedTaskCount = $tasksAfter.Count
        protectedTaskDefinitionsChanged = $false
        protectedTaskPrincipalsChanged = $false
        childPowerShellRunnerPresent = $false
        nestedInstallerPresent = $false
        imageRead = $false
        sourceMutation = $false
        deletion = $false
        waferAction = $false
        fiducialArtifactsChanged = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12
}
catch {
    $originalFailure = $_.Exception.Message
    $rollbackVerified = $false
    $recoveryFailure = ''

    if ($actionsStarted) {
        try {
            if ($trayRestarted) {
                [void](Stop-ExactTray)
            }
            Restore-PriorFiles -PriorRows $priorRows
            Start-ExactTray
            [void](Get-StableTray)
            $rollbackVerified = $true
        }
        catch {
            $recoveryFailure = $_.Exception.Message
        }
    }

    $failureState = if ($rollbackVerified) {
        'FAIL_GUIHV3_DIRECT_GUI_ONLY_PATCH_ROLLED_BACK_BEFORE_TRAY_RESTART'
    }
    else {
        'FAIL_GUIHV3_DIRECT_GUI_ONLY_PATCH_RECOVERY_FAILED'
    }

    [ordered]@{
        schema = 'argos_guihv3_direct_gui_patch_failure_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = $failureState
        requestId = $requestId
        rehearsal = $isFixture
        failure = $originalFailure
        rollbackVerified = $rollbackVerified
        recoveryFailure = $recoveryFailure
        processorTaskAction = $false
        processorRestarted = $false
        childPowerShellRunnerPresent = $false
        nestedInstallerPresent = $false
        imageRead = $false
        sourceMutation = $false
        deletion = $false
        waferAction = $false
        fiducialArtifactsChanged = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8

    if ($rollbackVerified) {
        throw "GUIHV3 failed; all endpoint predecessors were restored before tray relaunch. $originalFailure"
    }

    throw "GUIHV3 failed and recovery failed. Original: $originalFailure Recovery: $recoveryFailure"
}
