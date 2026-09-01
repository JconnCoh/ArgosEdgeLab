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
$dashboardUpdaterSha256 = 'C6A862FE32BB1013626A2C70D97173732F24724D644F44D084EC67DBB3351299'
$trayLauncherSha256 = '8302F44CCCEC09E97CD77115E83C8012B5DF7D89A89791B5A362D263A0556BBB'
$processorConfigSha256 = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$scribeImporterSha256 = '58E3ED71F532FDB0CCE0D68B1252B788CC04DC349C198516BC96303352B601A6'
$dashboardManifestSha256 = 'E55F21FF680DD70AD2D71084B199F21862D91E9C4FC83D4943D0FF510846F16B'
$dashboardManifestBytes = 3451199
$dashboardStatusSha256 = '787BD3107214E3C50FF8589310D7C77AFE0A9D1584E733372F928A4AB671A189'
$scribeQueueSha256 = '9F8F5B0A0037DDDCA309579CF5A6339CF4215273ED153E46B3BD9D2E1E5D2541'
$scribeReason = 'HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'

$targetSpecs = @(
    [pscustomobject]@{
        index = 1
        relativePath = 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        payloadName = 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        predecessorName = '1'
        targetSha256 = '018A74CB5EFA08D59810B09BD16EEF5E3F0345A4C4335CB59ABE334ABE888AA7'
        approvedPredecessors = @(
            'D893CA3C8F7C4F2993BA4D412986EC30D8B113408039EF8E381F4025C1A04D82',
            '018A74CB5EFA08D59810B09BD16EEF5E3F0345A4C4335CB59ABE334ABE888AA7'
        )
    },
    [pscustomobject]@{
        index = 2
        relativePath = 'runtime\viewer\ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        payloadName = 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
        predecessorName = '2'
        targetSha256 = '018A74CB5EFA08D59810B09BD16EEF5E3F0345A4C4335CB59ABE334ABE888AA7'
        approvedPredecessors = @(
            'D893CA3C8F7C4F2993BA4D412986EC30D8B113408039EF8E381F4025C1A04D82',
            '018A74CB5EFA08D59810B09BD16EEF5E3F0345A4C4335CB59ABE334ABE888AA7'
        )
    },
    [pscustomobject]@{
        index = 3
        relativePath = 'runtime\viewer\Program.cs'
        payloadName = 'Program.cs'
        predecessorName = '3'
        targetSha256 = '776BDD0F5D8F644851A8495187178417B021CF5350A988FD0DBFE94D0CFDEF0A'
        approvedPredecessors = @(
            'DFEC0EA9E7A3C309CD7BD845099B23AB725A760035EBAC787340570C34181C76',
            '776BDD0F5D8F644851A8495187178417B021CF5350A988FD0DBFE94D0CFDEF0A'
        )
    },
    [pscustomobject]@{
        index = 4
        relativePath = 'Update-JbodDashboardManifest.ps1'
        payloadName = 'Update-JbodDashboardManifest.ps1'
        predecessorName = '4'
        targetSha256 = 'C6A862FE32BB1013626A2C70D97173732F24724D644F44D084EC67DBB3351299'
        approvedPredecessors = @(
            '73C2289B58F6F6B23DD2FA12E847AFF171B3FAC45153202E93EE00E0B7533FBA',
            'C6A862FE32BB1013626A2C70D97173732F24724D644F44D084EC67DBB3351299'
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
        throw "GUIHV5 path budget refused: $fullPath"
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
    $fixturePath = [Environment]::GetEnvironmentVariable('ARGOS_GUIHV5_REHEARSAL_MANIFEST', 'Process')
}

$fixture = $null
$isFixture = -not [string]::IsNullOrWhiteSpace($fixturePath)
if ($isFixture) {
    $fixturePath = [IO.Path]::GetFullPath($fixturePath)
    $fixture = Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json
    if ([string]$fixture.schema -ne 'argos_guihv5_direct_patch_rehearsal_v1' -or -not [bool]$fixture.rehearsal) {
        throw 'GUIHV5 rehearsal fixture changed.'
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
            throw "GUIHV5 payload is missing: $($spec.payloadName)"
        }
        if ((Get-Sha256 -Path $payloadPath) -ne [string]$spec.targetSha256) {
            throw "GUIHV5 payload hash changed: $($spec.payloadName)"
        }

        $destination = Assert-PathBudget -Path (Join-Path $script:InstallRoot $spec.relativePath)
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            throw "GUIHV5 destination is missing: $($spec.relativePath)"
        }

        $installedSha256 = Get-Sha256 -Path $destination
        if (@($spec.approvedPredecessors) -notcontains $installedSha256) {
            throw "GUIHV5 destination predecessor is unapproved: $($spec.relativePath)"
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

function Test-ScribeConfigContract {
    param([object]$Config)

    return (
        [string]$Config.schema -in @(
            'argos_jbod_all_wafer_processor_config_v2',
            'argos_jbod_all_wafer_processor_config_v3'
        ) -and
        [string]$Config.metadataLookupAuthority -eq 'CONFIRMED_SCRIBE_ONLY' -and
        [bool]$Config.reviewOnly -and
        -not [bool]$Config.xmlExportEnabled
    )
}

function Get-ScribeGuardEvidence {
    param([string]$ConfigPath, [string]$ImporterPath)

    $observedConfigSha256 = Get-Sha256 -Path $ConfigPath
    if (-not $script:IsFixture -and $observedConfigSha256 -ne $processorConfigSha256) {
        throw 'Installed processor config premise changed.'
    }
    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if (-not (Test-ScribeConfigContract -Config $config)) {
        throw 'Installed processor config failed the scribe import safety contract.'
    }
    $importerText = Get-Content -LiteralPath $ImporterPath -Raw
    foreach ($token in @(
        "'argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3'",
        "metadataLookupAuthority-ne'CONFIRMED_SCRIBE_ONLY'",
        'xmlExportEnabled'
    )) {
        if ($importerText.IndexOf($token, [StringComparison]::Ordinal) -lt 0) {
            throw "Installed importer safety token is missing: $token"
        }
    }

    $safeV2 = $config.PSObject.Copy(); $safeV2.schema = 'argos_jbod_all_wafer_processor_config_v2'
    $unsafeSchema = $config.PSObject.Copy(); $unsafeSchema.schema = 'argos_jbod_all_wafer_processor_config_v1'
    $unsafeAuthority = $config.PSObject.Copy(); $unsafeAuthority.metadataLookupAuthority = 'UNCONFIRMED'
    $unsafeReview = $config.PSObject.Copy(); $unsafeReview.reviewOnly = $false
    $unsafeXml = $config.PSObject.Copy(); $unsafeXml.xmlExportEnabled = $true
    if (-not (Test-ScribeConfigContract -Config $safeV2) -or
        (Test-ScribeConfigContract -Config $unsafeSchema) -or
        (Test-ScribeConfigContract -Config $unsafeAuthority) -or
        (Test-ScribeConfigContract -Config $unsafeReview) -or
        (Test-ScribeConfigContract -Config $unsafeXml)) {
        throw 'Scribe import config guard controls failed.'
    }

    return [pscustomobject]@{
        liveSchema = [string]$config.schema
        liveConfigSha256 = $observedConfigSha256
        productionConfigSha256 = $processorConfigSha256
        safeV2Accepted = $true
        safeV3Accepted = $true
        unsafeSchemaRefused = $true
        unsafeAuthorityRefused = $true
        unsafeReviewOnlyFalseRefused = $true
        unsafeXmlEnabledRefused = $true
        importerExecuted = $false
        mutationsPerformed = $false
    }
}

function Invoke-HoldProjectionCheck {
    param([string]$ViewerPath, [string]$ManifestPath)

    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $ViewerPath
    $start.Arguments = '--hold-projection-check 1532 190 5'
    $start.WorkingDirectory = Split-Path -Parent $ViewerPath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Hold projection check process did not start.' }
        if (-not $process.WaitForExit(120000)) {
            try { $process.Kill() } catch {}
            throw 'Hold projection check timed out.'
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        if ($process.ExitCode -ne 0) {
            throw "Hold projection check failed with exit $($process.ExitCode): $stderr $stdout"
        }
        return [pscustomobject]@{
            exitCode = $process.ExitCode
            manifestBytes = (Get-Item -LiteralPath $ManifestPath).Length
            manifestSha256 = Get-Sha256 -Path $ManifestPath
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-PropertyText {
    param([object]$Object, [string]$Name)

    if ($null -eq $Object) { return '' }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return '' }
    return [string]$property.Value
}

function Get-UnrelatedHoldJson {
    param([object[]]$Rows)

    return @(
        $Rows |
            Where-Object { (Get-PropertyText -Object $_ -Name 'holdReason') -ne $scribeReason } |
            ForEach-Object { $_ | ConvertTo-Json -Depth 14 -Compress }
    )
}

function Assert-ScribeProjectionOutput {
    param([object]$ManifestBefore, [object]$ManifestAfter, [object]$ReadinessAfter)

    $beforeHeld = @($ManifestBefore.heldAcquisitions)
    $afterHeld = @($ManifestAfter.heldAcquisitions)
    $scribeRows = @($afterHeld | Where-Object { (Get-PropertyText -Object $_ -Name 'holdReason') -eq $scribeReason })
    $physicalGroups = @($scribeRows | Group-Object physicalIdentity)
    if ($afterHeld.Count -ne 1722 -or $scribeRows.Count -ne 380 -or $physicalGroups.Count -ne 190) {
        throw 'GUIHV5 exact signed hold cardinality changed.'
    }
    if (@($physicalGroups | Where-Object { $_.Count -ne 2 }).Count -ne 0) {
        throw 'GUIHV5 physical scribe domain duplication changed.'
    }
    if (@($physicalGroups | Where-Object {
        (@($_.Group.domain | Sort-Object -Unique) -join ',') -ne 'BACKSIDE_PENDING_REGIME,FRONTSIDE'
    }).Count -ne 0) {
        throw 'GUIHV5 physical scribe domain set changed.'
    }

    $beforeUnrelated = @(Get-UnrelatedHoldJson -Rows $beforeHeld)
    $afterUnrelated = @(Get-UnrelatedHoldJson -Rows $afterHeld)
    if ($beforeUnrelated.Count -ne 1342 -or $afterUnrelated.Count -ne 1342 -or
        (Compare-Object -ReferenceObject $beforeUnrelated -DifferenceObject $afterUnrelated)) {
        throw 'GUIHV5 unrelated hold rows changed.'
    }

    $stateCounts = @($physicalGroups | ForEach-Object { $_.Group[0] } | Group-Object scribeQueueState)
    $expectedCounts = @{
        'SCRIBE_IDENTITY_CONFIRMATION_HOLD' = 126
        'PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL' = 55
        'PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED' = 5
        'HOLD_HUMAN_VISIBLE_NONCANONICAL_CHECKSUM' = 4
    }
    foreach ($state in $expectedCounts.Keys) {
        $row = @($stateCounts | Where-Object { [string]$_.Name -eq $state })
        if ($row.Count -ne 1 -or [int]$row[0].Count -ne [int]$expectedCounts[$state]) {
            throw "GUIHV5 queue-state split changed: $state"
        }
    }
    if (@($scribeRows | Where-Object {
        [string]::IsNullOrWhiteSpace((Get-PropertyText -Object $_ -Name 'scribeQueueState')) -or
        [string]::IsNullOrWhiteSpace((Get-PropertyText -Object $_ -Name 'scribeNextAction')) -or
        [string]::IsNullOrWhiteSpace((Get-PropertyText -Object $_ -Name 'scribeActionability'))
    }).Count -ne 0) {
        throw 'GUIHV5 exact scribe queue projection is incomplete.'
    }
    if ([int]$ReadinessAfter.scribeHoldQueueJoinRows -ne 380 -or
        [int]$ReadinessAfter.scribeQueueRows -ne 978 -or
        [int]$ReadinessAfter.scribeHoldQueueMissing -ne 0) {
        throw 'GUIHV5 dashboard readiness queue-join evidence changed.'
    }

    return [pscustomobject]@{
        acquisitionScribeRows = $scribeRows.Count
        physicalScribeRows = $physicalGroups.Count
        displayRows = 1532
        unrelatedRows = $afterUnrelated.Count
        missingQueueJoins = 0
        operatorReviewReady = 5
        queueStateCounts = @(
            $stateCounts | Sort-Object Name | ForEach-Object {
                [ordered]@{ state = [string]$_.Name; count = [int]$_.Count }
            }
        )
    }
}
$processorBeforeId = if ($processorBefore.Count -eq 1) { [int]$processorBefore[0].processId } else { 0 }
$processorBeforeCreationUtc = if ($processorBefore.Count -eq 1) { [string]$processorBefore[0].creationUtc } else { '' }
$dashboardUpdaterPath = Join-Path $script:InstallRoot 'Update-JbodDashboardManifest.ps1'
if (-not (Test-Path -LiteralPath $dashboardUpdaterPath -PathType Leaf)) {
    throw 'Installed dashboard updater is missing.'
}
$trayLauncherPath = Join-Path $script:InstallRoot 'Show-JbodAllWaferTray.ps1'
if (-not (Test-Path -LiteralPath $trayLauncherPath -PathType Leaf) -or
    (Get-Sha256 -Path $trayLauncherPath) -ne $trayLauncherSha256) {
    throw 'Installed tray launcher premise changed.'
}
$processorConfigPath = Join-Path $script:InstallRoot 'PROCESSOR_CONFIG.json'
$dashboardManifestPath = Join-Path $script:InstallRoot 'dashboard_manifest.json'
$dashboardStatusPath = Join-Path $script:InstallRoot 'dashboard\DASHBOARD_CATALOG_STATUS.json'
$installedImporterPath = Join-Path $script:InstallRoot 'Import-JbodScribeVerificationResponse.ps1'
if ((Get-Sha256 -Path $installedImporterPath) -ne $scribeImporterSha256) {
    throw 'Installed scribe importer premise changed.'
}
$scribeGuardPreflight = Get-ScribeGuardEvidence -ConfigPath $processorConfigPath -ImporterPath $installedImporterPath
if ((Get-Item -LiteralPath $dashboardManifestPath).Length -ne $dashboardManifestBytes -or
    (Get-Sha256 -Path $dashboardManifestPath) -ne $dashboardManifestSha256) {
    throw 'Exact completed dashboard manifest premise changed.'
}
$config = Get-Content -LiteralPath $processorConfigPath -Raw | ConvertFrom-Json
$scribeQueuePath = Join-Path ([IO.Path]::GetFullPath([string]$config.stateRoot)) 'identity\SCRIBE_IDENTITY_QUEUE.json'
if ((Get-Sha256 -Path $scribeQueuePath) -ne $scribeQueueSha256) {
    throw 'Exact signed scribe queue premise changed.'
}
if (-not (Test-Path -LiteralPath $dashboardStatusPath -PathType Leaf)) {
    throw 'Dashboard readiness status is missing.'
}

$trayBefore = @(Get-ExactProcessRows -Kind tray)
if ($trayBefore.Count -gt 1) {
    throw 'Exact tray process is ambiguous.'
}

$preflightResult = [ordered]@{
    schema = 'argos_guihv5_scribe_hold_projection_maintenance_patch_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIHV5_SCRIBE_HOLD_PROJECTION_MAINTENANCE_PATCH_PREFLIGHT'
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
    trayLauncherSha256 = $trayLauncherSha256
    processorConfigSha256 = $processorConfigSha256
    dashboardManifestBytes = $dashboardManifestBytes
    dashboardManifestSha256 = $dashboardManifestSha256
    scribeQueueSha256 = $scribeQueueSha256
    scribeGuardPreflight = $scribeGuardPreflight
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

$scribeGuardEvidence = Get-ScribeGuardEvidence -ConfigPath $processorConfigPath -ImporterPath $installedImporterPath

$actionsStarted = $false
$trayRestarted = $false
$viewerResult = $null
$trayStopResult = $null
$projectionEvidence = $null
$catalogEvidence = $null
$dashboardPriorPath = Join-Path (Join-Path $PSScriptRoot 'p') 'd'
$dashboardStatusPriorPath = Join-Path (Join-Path $PSScriptRoot 'p') 's'
$dashboardMutationStarted = $false
$updaterOutput = ''

try {
    $actionsStarted = $true
    [void](Assert-PathBudget -Path $dashboardPriorPath)
    [void](Assert-PathBudget -Path $dashboardStatusPriorPath)
    if ((Get-Sha256 -Path $dashboardPriorPath) -ne $dashboardManifestSha256 -or
        (Get-Sha256 -Path $dashboardStatusPriorPath) -ne $dashboardStatusSha256) {
        throw 'GUIHV5 signed producer-output predecessors changed.'
    }
    $manifestBefore = Get-Content -LiteralPath $dashboardManifestPath -Raw | ConvertFrom-Json
    $producerStartedUtc = [DateTime]::UtcNow
    $dashboardMutationStarted = $true
    $updaterOutput = (& $dashboardUpdaterPath -ConfigPath $processorConfigPath | Out-String).Trim()
    $manifestAfter = Get-Content -LiteralPath $dashboardManifestPath -Raw | ConvertFrom-Json
    $readinessAfter = Get-Content -LiteralPath $dashboardStatusPath -Raw | ConvertFrom-Json
    if ([string]$readinessAfter.state -ne 'DASHBOARD_CATALOG_READY_REVIEW_ONLY' -or
        [DateTimeOffset]::Parse([string]$manifestAfter.createdUtc).UtcDateTime -lt $producerStartedUtc -or
        [DateTimeOffset]::Parse([string]$readinessAfter.updatedUtc).UtcDateTime -lt $producerStartedUtc) {
        throw 'GUIHV5 installed dashboard producer did not emit a fresh terminal revision.'
    }
    $projectionEvidence = Assert-ScribeProjectionOutput -ManifestBefore $manifestBefore -ManifestAfter $manifestAfter -ReadinessAfter $readinessAfter
    $catalogEvidence = Invoke-HoldProjectionCheck -ViewerPath (Join-Path $script:InstallRoot 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe') -ManifestPath $dashboardManifestPath

    $viewerResult = Close-ExactViewer
    $trayStopResult = Stop-ExactTray

    if ($isFixture -and [bool](Get-OptionalValue -Object $fixture -Name 'failAfterTargetVerification' -Default $false)) {
        throw 'INJECTED_GUIHV5_POST_PRODUCER_VALIDATION_FAILURE'
    }

    Start-ExactTray
    $trayRestarted = $true
    $stableTray = Get-StableTray

    $processorAfter = @(Get-ExactProcessRows -Kind processor)
    if ($processorAfter.Count -ne $processorBefore.Count) {
        throw 'Exact processor selector count changed during GUIHV5.'
    }
    if ($processorAfter.Count -eq 1 -and (
        [int]$processorAfter[0].processId -ne $processorBeforeId -or
        [string]$processorAfter[0].creationUtc -ne $processorBeforeCreationUtc
    )) {
        throw 'Exact processor selector identity changed during GUIHV5.'
    }

    $tasksAfter = @(Get-TaskSnapshot)
    Compare-TaskSnapshots -Before $tasksBefore -After $tasksAfter
    $processorTaskAfter = @($tasksAfter | Where-Object { [string]$_.name -eq $processorTaskName })
    if ($processorTaskAfter.Count -ne 1 -or [string]$processorTaskAfter[0].state -ne [string]$processorTaskRows[0].state) {
        throw 'Processor selector task state changed during GUIHV5.'
    }
    if ((Get-Sha256 -Path $dashboardUpdaterPath) -ne $dashboardUpdaterSha256) {
        throw 'Dashboard updater changed during GUIHV5.'
    }

    foreach ($row in $priorRows) {
        if ((Get-Sha256 -Path $row.destination) -ne [string]$row.targetSha256) {
            throw "GUIHV5 target changed after tray activation: $([string]$row.relativePath)"
        }
    }

    [ordered]@{
        schema = 'argos_guihv5_scribe_hold_projection_maintenance_patch_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_GUIHV5_SCRIBE_HOLD_PROJECTION_PRODUCED_VALIDATED_AND_TRAY_ACTIVATED'
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
        dashboardUpdaterChanged = $true
        trayLauncherSha256 = $trayLauncherSha256
        trayLauncherChanged = $false
        holdProjectionCheckExitCode = [int]$catalogEvidence.exitCode
        producedDashboardManifestBytes = [int64]$catalogEvidence.manifestBytes
        producedDashboardManifestSha256 = [string]$catalogEvidence.manifestSha256
        producerOutput = $updaterOutput
        scribeHoldProjection = $projectionEvidence
        signedProducerOutputPredecessorsRetainedInPackage = $true
        scribeConfigGuard = $scribeGuardEvidence
        scribeImporterExecuted = $false
        identityStateChanged = $false
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
            if ($dashboardMutationStarted) {
                Copy-Item -LiteralPath $dashboardPriorPath -Destination $dashboardManifestPath -Force -ErrorAction Stop
                Copy-Item -LiteralPath $dashboardStatusPriorPath -Destination $dashboardStatusPath -Force -ErrorAction Stop
                if ((Get-Sha256 -Path $dashboardManifestPath) -ne $dashboardManifestSha256 -or
                    (Get-Sha256 -Path $dashboardStatusPath) -ne $dashboardStatusSha256) {
                    throw 'GUIHV5 producer-output rollback verification failed.'
                }
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
        'FAIL_GUIHV5_SCRIBE_HOLD_PROJECTION_ROLLED_BACK_BEFORE_TRAY_RESTART'
    }
    else {
        'FAIL_GUIHV5_SCRIBE_HOLD_PROJECTION_RECOVERY_FAILED'
    }

    [ordered]@{
        schema = 'argos_guihv5_scribe_hold_projection_maintenance_patch_failure_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = $failureState
        requestId = $requestId
        rehearsal = $isFixture
        failure = $originalFailure
        rollbackVerified = $rollbackVerified
        producerOutputRollbackAttempted = $dashboardMutationStarted
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
        throw "GUIHV5 failed; all endpoint and producer-output predecessors were restored before tray relaunch. $originalFailure"
    }

    throw "GUIHV5 failed and recovery failed. Original: $originalFailure Recovery: $recoveryFailure"
}
