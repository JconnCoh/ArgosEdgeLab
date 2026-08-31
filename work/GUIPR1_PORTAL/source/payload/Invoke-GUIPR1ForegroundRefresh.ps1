[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Preflight -and $Rehearsal) { throw 'Specify at most one of -Preflight or -Rehearsal.' }

$expectedComputer = 'A1025645101'
$installRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$processorTaskName = 'ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2'
$expectedTaskPrincipal = 'SYSTEM'
$expectedTaskDefinitionSha256 = '6E306778640AF823C53422411E65F9A796075392DEA25306F59FE7EDB8259B17'
$expectedHashes = [ordered]@{
    'PROCESSOR_CONFIG.json' = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
    'Run-JbodAllWaferProcessor.ps1' = '46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
    'Invoke-JbodAllWaferInventory.ps1' = '228D9EDD0EFF45E58682659DC6C807FB04F63DD55E48C7F70426BF272C08FA7C'
    'Invoke-JbodAllWaferProcessingPass.ps1' = '8050EEB71923DC69EBD0A81F6C95840A7BD6215998E8546F9170C5A051B936EB'
    'Update-JbodScribeIdentityQueue.ps1' = '6185D960F32088120E304BE49D5BF99C525B07EE60F5D68017A40A93F68EC6A9'
    'Update-JbodDashboardManifest.ps1' = 'F73AC7C38139098B079A23CC9C7653A93D7464BE1D4376708B25B3346B704E5D'
}

function Get-TextSha256 {
    param([Parameter(Mandatory=$true)][string]$Text)
    $encoding = New-Object Text.UTF8Encoding($false)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($encoding.GetBytes($Text)))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Get-ExactRunnerProcesses {
    param([Parameter(Mandatory=$true)][string]$RunnerPath)
    $escaped = [Regex]::Escape([IO.Path]::GetFullPath($RunnerPath))
    return @(
        Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and [string]$_.CommandLine -match $escaped } |
            Select-Object ProcessId, CreationDate, CommandLine
    )
}

function Get-ExactTaskRow {
    param([Parameter(Mandatory=$true)][string]$RunnerPath)
    $task = Get-ScheduledTask -TaskName $processorTaskName -TaskPath '\' -ErrorAction Stop
    $definition = Export-ScheduledTask -TaskName $processorTaskName -TaskPath '\'
    $actions = @($task.Actions)
    if ($actions.Count -ne 1) { throw 'Exact processor task action count changed.' }
    $command = ([string]$actions[0].Execute) + ' ' + ([string]$actions[0].Arguments)
    if ($command.IndexOf($RunnerPath, [StringComparison]::OrdinalIgnoreCase) -lt 0) {
        throw 'Exact processor task action no longer references the installed runner.'
    }
    return [pscustomobject]@{
        name = [string]$task.TaskName
        state = [string]$task.State
        principal = [string]$task.Principal.UserId
        definitionSha256 = Get-TextSha256 -Text $definition
        command = $command
    }
}

function Assert-TaskPremise {
    param([Parameter(Mandatory=$true)][object]$Task)
    if ([string]$Task.name -ne $processorTaskName -or
        -not ([string]$Task.principal).Equals($expectedTaskPrincipal, [StringComparison]::OrdinalIgnoreCase) -or
        [string]$Task.definitionSha256 -ne $expectedTaskDefinitionSha256 -or
        [string]$Task.state -ne 'Ready') {
        throw 'Exact stopped processor task premise changed.'
    }
}

function Read-JsonFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required producer output is missing: $Path" }
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

function Get-DashboardKeys {
    param([Parameter(Mandatory=$true)][object]$Manifest)
    return @(
        foreach ($session in @($Manifest.scanSessions)) {
            foreach ($wafer in @($session.wafers)) {
                ([string]$wafer.identity) + '|' + ([string]$wafer.metadata.domain)
            }
        }
    )
}

function Get-CatalogKeys {
    param([Parameter(Mandatory=$true)][object]$Catalog)
    return @(
        foreach ($row in @($Catalog.acquisitions)) {
            ([string]$row.physicalIdentity) + '|' + ([string]$row.domain)
        }
    )
}

function Test-FreshAfter {
    param([Parameter(Mandatory=$true)][string]$Value,[Parameter(Mandatory=$true)][DateTime]$StartUtc,[Parameter(Mandatory=$true)][string]$Label)
    $parsed = [DateTime]::MinValue
    if (-not [DateTime]::TryParse($Value, [ref]$parsed) -or $parsed.ToUniversalTime() -lt $StartUtc) {
        throw "$Label was not refreshed by this exact invocation."
    }
    return $parsed.ToUniversalTime().ToString('o')
}

if ($Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'Rehearsal requires -InvocationManifest.' }
    $fixture = Read-JsonFile -Path $InvocationManifest
    if ([bool]$fixture.injectFailure) { throw 'INJECTED_GUIPR1_REHEARSAL_FAILURE' }
    $catalogKeys = @($fixture.catalogKeys | Sort-Object -Unique)
    $dashboardKeys = @($fixture.dashboardKeys | Sort-Object -Unique)
    $missing = @($catalogKeys | Where-Object { $_ -notin $dashboardKeys })
    if ($catalogKeys.Count -eq 0 -or $dashboardKeys.Count -eq 0 -or $missing.Count -eq 0) {
        throw 'GUIPR1 rehearsal did not preserve a strict dashboard subset.'
    }
    [ordered]@{
        schema = 'argos_guipr1_foreground_refresh_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_GUIPR1_FOREGROUND_PLAN_AND_UNCHANGED_DASHBOARD_REFRESH'
        rehearsal = $true
        catalogAcquisitions = $catalogKeys.Count
        dashboardRows = $dashboardKeys.Count
        missingDashboardRows = $missing.Count
        silentOmissionCount = $missing.Count
        taskActions = 0
        detectorScoring = $false
        imageProcessing = $false
        guiBytesChanged = $false
        xmlExportEnabled = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

if ([Environment]::MachineName -ne $expectedComputer) { throw 'GUIPR1 is restricted to JBOD A1025645101.' }

$resolvedInstallRoot = [IO.Path]::GetFullPath($installRoot).TrimEnd('\')
$paths = [ordered]@{}
foreach ($name in $expectedHashes.Keys) {
    $path = [IO.Path]::GetFullPath((Join-Path $resolvedInstallRoot $name))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required installed dependency is missing: $name" }
    $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($actual -ne [string]$expectedHashes[$name]) { throw "Installed dependency hash changed: $name" }
    $paths[$name] = $path
}

$config = Read-JsonFile -Path $paths['PROCESSOR_CONFIG.json']
if ([string]$config.schema -ne 'argos_jbod_all_wafer_processor_config_v3' -or
    -not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or
    [bool]$config.productionEligible -or [bool]$config.trainingEligible -or
    [bool]$config.processorCooperativeHold) {
    throw 'Exact review-only processor configuration safety contract changed.'
}

$runnerCommand = Get-Command -Name $paths['Run-JbodAllWaferProcessor.ps1'] -ErrorAction Stop
$updaterCommand = Get-Command -Name $paths['Update-JbodDashboardManifest.ps1'] -ErrorAction Stop
foreach ($parameter in @('ConfigPath','Once','PlanOnly')) {
    if (-not $runnerCommand.Parameters.ContainsKey($parameter)) { throw "Installed runner parameter is missing: $parameter" }
}
if (-not $updaterCommand.Parameters.ContainsKey('ConfigPath')) { throw 'Installed dashboard updater ConfigPath parameter is missing.' }

$taskBefore = Get-ExactTaskRow -RunnerPath $paths['Run-JbodAllWaferProcessor.ps1']
Assert-TaskPremise -Task $taskBefore
if (@(Get-ExactRunnerProcesses -RunnerPath $paths['Run-JbodAllWaferProcessor.ps1']).Count -ne 0) {
    throw 'Exact foreground runner process already exists.'
}

$preflightResult = [ordered]@{
    schema = 'argos_guipr1_foreground_refresh_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIPR1_NON_MUTATING_PREFLIGHT'
    installRoot = $resolvedInstallRoot
    installedHashes = $expectedHashes
    taskName = $taskBefore.name
    taskState = $taskBefore.state
    taskPrincipal = $taskBefore.principal
    taskDefinitionSha256 = $taskBefore.definitionSha256
    exactRunnerProcessCount = 0
    sameBytesConfigSelfSwap = $true
    taskActions = 0
    detectorScoring = $false
    guiBytesChanged = $false
    xmlExportEnabled = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 8; return }

$catalogPath = Join-Path $resolvedInstallRoot 'catalog\ALL_WAFER_CATALOG.json'
$scribePath = Join-Path $resolvedInstallRoot 'identity\SCRIBE_IDENTITY_QUEUE.json'
$statusPath = Join-Path $resolvedInstallRoot 'processor\PROCESSOR_STATUS.json'
$dashboardPath = Join-Path $resolvedInstallRoot 'dashboard_manifest.json'
$dashboardStatusPath = Join-Path $resolvedInstallRoot 'dashboard\DASHBOARD_CATALOG_STATUS.json'
$startedUtc = [DateTime]::UtcNow

& $paths['Run-JbodAllWaferProcessor.ps1'] -ConfigPath $paths['PROCESSOR_CONFIG.json'] -Once -PlanOnly | Out-Null

$catalog = Read-JsonFile -Path $catalogPath
$scribe = Read-JsonFile -Path $scribePath
$status = Read-JsonFile -Path $statusPath
$catalogUtc = Test-FreshAfter -Value ([string]$catalog.generatedUtc) -StartUtc $startedUtc -Label 'Catalog'
$scribeUtc = Test-FreshAfter -Value ([string]$scribe.updatedUtc) -StartUtc $startedUtc -Label 'Scribe queue'
$statusUtc = Test-FreshAfter -Value ([string]$status.updatedUtc) -StartUtc $startedUtc -Label 'Processor status'
if ([string]$status.state -ne 'PLAN_ONLY') { throw 'Exact foreground runner did not return PLAN_ONLY status.' }
if (-not [bool]$catalog.reviewOnly -or [bool]$catalog.xmlExportEnabled -or
    -not [bool]$scribe.reviewOnly -or [bool]$scribe.xmlEligible -or
    -not [bool]$status.reviewOnly -or [bool]$status.xmlExportEnabled) {
    throw 'Fresh producer outputs violated the review-only/XML-disabled boundary.'
}

$dashboardStartUtc = [DateTime]::UtcNow
& $paths['Update-JbodDashboardManifest.ps1'] -ConfigPath $paths['PROCESSOR_CONFIG.json'] | Out-Null
$dashboard = Read-JsonFile -Path $dashboardPath
$dashboardStatus = Read-JsonFile -Path $dashboardStatusPath
$dashboardUtc = Test-FreshAfter -Value ([string]$dashboard.createdUtc) -StartUtc $dashboardStartUtc -Label 'Dashboard manifest'
$dashboardStatusUtc = Test-FreshAfter -Value ([string]$dashboardStatus.updatedUtc) -StartUtc $dashboardStartUtc -Label 'Dashboard status'
if ([bool]$dashboard.xmlExportEnabled -or -not [bool]$dashboardStatus.reviewOnly -or [bool]$dashboardStatus.xmlExportEnabled) {
    throw 'Fresh dashboard outputs violated the review-only/XML-disabled boundary.'
}

$catalogKeys = @(Get-CatalogKeys -Catalog $catalog | Sort-Object -Unique)
$dashboardKeys = @(Get-DashboardKeys -Manifest $dashboard | Sort-Object -Unique)
$dashboardNotCatalog = @($dashboardKeys | Where-Object { $_ -notin $catalogKeys })
$missingKeys = @($catalogKeys | Where-Object { $_ -notin $dashboardKeys })
if ($catalogKeys.Count -eq 0 -or $dashboardNotCatalog.Count -ne 0 -or $missingKeys.Count -eq 0) {
    throw 'Unchanged dashboard producer did not prove the expected strict current-catalog subset.'
}

$excludedIdentities = @($dashboardStatus.excluded | ForEach-Object { [string]$_.identity } | Sort-Object -Unique)
$silentOmissions = @(
    foreach ($row in @($catalog.acquisitions)) {
        $key = ([string]$row.physicalIdentity) + '|' + ([string]$row.domain)
        if ($key -in $missingKeys -and [string]$row.identity -notin $excludedIdentities) { $key }
    }
)
if ($silentOmissions.Count -eq 0) { throw 'Unchanged dashboard producer did not reproduce silent current-row omission.' }

$taskAfter = Get-ExactTaskRow -RunnerPath $paths['Run-JbodAllWaferProcessor.ps1']
Assert-TaskPremise -Task $taskAfter
if (@(Get-ExactRunnerProcesses -RunnerPath $paths['Run-JbodAllWaferProcessor.ps1']).Count -ne 0) {
    throw 'Exact foreground runner process remained after completion.'
}
foreach ($name in $expectedHashes.Keys) {
    if ((Get-FileHash -LiteralPath $paths[$name] -Algorithm SHA256).Hash -ne [string]$expectedHashes[$name]) {
        throw "Installed dependency changed during GUIPR1: $name"
    }
}

[ordered]@{
    schema = 'argos_guipr1_foreground_refresh_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIPR1_FOREGROUND_PLAN_AND_UNCHANGED_DASHBOARD_REFRESH'
    catalogGeneratedUtc = $catalogUtc
    scribeUpdatedUtc = $scribeUtc
    processorStatusUpdatedUtc = $statusUtc
    processorStatusState = [string]$status.state
    dashboardCreatedUtc = $dashboardUtc
    dashboardStatusUpdatedUtc = $dashboardStatusUtc
    catalogAcquisitions = $catalogKeys.Count
    dashboardRows = $dashboardKeys.Count
    missingDashboardRows = $missingKeys.Count
    silentOmissionCount = $silentOmissions.Count
    dashboardNotCatalogRows = 0
    taskName = $taskAfter.name
    taskState = $taskAfter.state
    taskPrincipal = $taskAfter.principal
    taskDefinitionSha256 = $taskAfter.definitionSha256
    exactRunnerProcessCountAfter = 0
    installedHashes = $expectedHashes
    sameBytesConfigSelfSwap = $true
    taskActions = 0
    detectorScoring = $false
    imageProcessing = $false
    guiBytesChanged = $false
    xmlExportEnabled = $false
    sourceDeletion = $false
    sourceMutation = $false
    retry = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8
