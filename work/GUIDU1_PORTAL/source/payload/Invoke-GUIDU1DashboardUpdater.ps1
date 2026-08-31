[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Preflight -and $Rehearsal) { throw 'Specify at most one of -Preflight or -Rehearsal.' }
if (($Preflight -or $Rehearsal) -and [string]::IsNullOrWhiteSpace($InvocationManifest)) {
    throw 'Preflight and rehearsal require -InvocationManifest.'
}

$targetUpdaterSha256 = '73C2289B58F6F6B23DD2FA12E847AFF171B3FAC45153202E93EE00E0B7533FBA'
$configSha256 = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$installRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$configPath = Join-Path $installRoot 'PROCESSOR_CONFIG.json'
$fixture = $null
$isFixture = $Preflight -or $Rehearsal
if ($isFixture) {
    $fixture = Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw | ConvertFrom-Json
    if ([string]$fixture.schema -ne 'argos_guidu1_updater_rehearsal_v1' -or -not [bool]$fixture.rehearsal) {
        throw 'GUIDU1 rehearsal fixture changed.'
    }
    $installRoot = [IO.Path]::GetFullPath([string]$fixture.installRoot)
    $configPath = [IO.Path]::GetFullPath([string]$fixture.configPath)
}
$installRoot = [IO.Path]::GetFullPath($installRoot).TrimEnd('\')
$updaterPath = Join-Path $installRoot 'Update-JbodDashboardManifest.ps1'

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Property-Text([object]$Object, [string]$Name) {
    if ($null -eq $Object) { return '' }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return '' }
    return [string]$property.Value
}

function Get-TextSha256([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text)))).Replace('-', '')
    }
    finally { $sha.Dispose() }
}

function Get-AcquisitionFingerprint([object]$Acquisition) {
    $rows = foreach ($property in $Acquisition.channels.PSObject.Properties | Sort-Object Name) {
        $value = $property.Value
        "$($property.Name)|$($value.path)|$($value.bytes)|$($value.lastWriteUtc)|$($value.widthPx)x$($value.heightPx)"
    }
    return Get-TextSha256 (([string]$Acquisition.identity) + '|' + ($rows -join ';'))
}

function Get-CompletedKeys([object]$Manifest) {
    return @(
        foreach ($session in @($Manifest.scanSessions)) {
            foreach ($wafer in @($session.wafers)) {
                ([string]$wafer.identity) + '|' + (Property-Text $wafer.metadata 'domain')
            }
        }
    )
}

function Get-ExpectedHeldRows([object]$Catalog, [object]$Ledger, [object]$ProcessorStatus) {
    $completed = @($Ledger.rows | Where-Object { [string]$_.state -eq 'COMPLETED' })
    $allRows = @($Ledger.rows)
    $routeHolds = @(
        if ($null -ne $ProcessorStatus -and $ProcessorStatus.PSObject.Properties.Name -contains 'routeHolds') {
            @($ProcessorStatus.routeHolds)
        }
    )
    return @(
        foreach ($acquisition in @($Catalog.acquisitions)) {
            $identity = [string]$acquisition.identity
            $jobKey = $identity + '__' + (Get-AcquisitionFingerprint $acquisition)
            $identityRows = @($completed | Where-Object { [string]$_.identity -eq $identity })
            $currentRows = @($identityRows | Where-Object { [string]$_.jobKey -eq $jobKey })
            if ($currentRows.Count -ne 0) { continue }

            $reason = Property-Text $acquisition 'routeState'
            $detail = ''
            $source = 'CATALOG_ROUTE_STATE'
            $nonCompleted = @(
                $allRows |
                    Where-Object {
                        [string]$_.identity -eq $identity -and
                        [string]$_.jobKey -eq $jobKey -and
                        [string]$_.state -ne 'COMPLETED'
                    } |
                    Sort-Object finishedUtc -Descending
            )
            $processorHold = @($routeHolds | Where-Object { [string]$_.identity -eq $identity } | Select-Object -First 1)
            if ($nonCompleted.Count -gt 0) {
                $reason = Property-Text $nonCompleted[0] 'reason'
                if ([string]::IsNullOrWhiteSpace($reason)) { $reason = Property-Text $nonCompleted[0] 'state' }
                $detail = Property-Text $nonCompleted[0] 'message'
                $source = 'CURRENT_LEDGER_ROW'
            }
            elseif ($processorHold.Count -gt 0) {
                $reason = Property-Text $processorHold[0] 'state'
                $detail = Property-Text $processorHold[0] 'detail'
                $source = 'PROCESSOR_ROUTE_HOLD'
            }
            elseif ([string]::IsNullOrWhiteSpace($reason)) {
                $reason = 'WAITING_FOR_CURRENT_INSPECTION_RESULT'
                $source = 'DASHBOARD_CURRENT_RESULT_WAIT'
            }
            [pscustomobject]@{
                key = $identity + '|' + (Property-Text $acquisition 'domain')
                physicalKey = (Property-Text $acquisition 'physicalIdentity') + '|' + (Property-Text $acquisition 'domain')
                reason = $reason
                detail = $detail
                source = $source
                jobKey = $jobKey
                historicalCompletedRows = $identityRows.Count
            }
        }
    )
}

function Assert-ExactSet([string[]]$Expected, [string[]]$Actual, [string]$Label) {
    $expectedSet = @($Expected | Sort-Object -Unique)
    $actualSet = @($Actual | Sort-Object -Unique)
    if ($expectedSet.Count -ne $Expected.Count) { throw "$Label expected set contains duplicates." }
    if ($actualSet.Count -ne $Actual.Count) { throw "$Label actual set contains duplicates." }
    if (Compare-Object -ReferenceObject $expectedSet -DifferenceObject $actualSet) {
        throw "$Label exact set changed."
    }
}

function Get-GuiHashRows {
    $relativePaths = @(
        'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe',
        'runtime\viewer\ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe',
        'runtime\viewer\Program.cs'
    )
    return @(
        foreach ($relative in $relativePaths) {
            $path = Join-Path $installRoot $relative
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "GUI premise is missing: $relative" }
            [pscustomobject]@{ relativePath = $relative; sha256 = Get-Sha256 $path }
        }
    )
}

function Get-RuntimeSnapshot {
    if ($isFixture) { return @($fixture.runtimeSnapshot) }
    return @(
        Get-CimInstance Win32_Process -ErrorAction Stop |
            Where-Object {
                ([string]$_.ExecutablePath).IndexOf($installRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0 -or
                ([string]$_.CommandLine).IndexOf($installRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
            } |
            Sort-Object ProcessId |
            ForEach-Object {
                [pscustomobject]@{
                    processId = [int]$_.ProcessId
                    name = [string]$_.Name
                    executablePath = [string]$_.ExecutablePath
                    commandLine = [string]$_.CommandLine
                    creationDate = [string]$_.CreationDate
                }
            }
    )
}

function Get-TaskSnapshot {
    if ($isFixture) { return @($fixture.taskSnapshot) }
    return @(
        Get-ScheduledTask -ErrorAction Stop |
            Where-Object { $_.TaskName -like 'Argos*' } |
            Sort-Object TaskPath, TaskName |
            ForEach-Object {
                $xml = Export-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath
                [pscustomobject]@{
                    name = [string]$_.TaskName
                    path = [string]$_.TaskPath
                    principal = [string]$_.Principal.UserId
                    state = [string]$_.State
                    definitionSha256 = Get-TextSha256 $xml
                }
            }
    )
}

function Assert-SnapshotUnchanged([object[]]$Before, [object[]]$After, [string]$Label) {
    $beforeJson = $Before | ConvertTo-Json -Depth 8 -Compress
    $afterJson = $After | ConvertTo-Json -Depth 8 -Compress
    if ($beforeJson -cne $afterJson) { throw "$Label changed during updater-only transaction." }
}

if (-not (Test-Path -LiteralPath $updaterPath -PathType Leaf) -or (Get-Sha256 $updaterPath) -ne $targetUpdaterSha256) {
    throw 'Installed dashboard updater target hash changed.'
}
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'Processor config is missing.' }
if (-not $isFixture -and (Get-Sha256 $configPath) -ne $configSha256) { throw 'Installed processor config hash changed.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if (-not [bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled) { throw 'GUIDU1 config safety contract refused.' }
$appRoot = [IO.Path]::GetFullPath([string]$config.appRoot)
$stateRoot = [IO.Path]::GetFullPath([string]$config.stateRoot)
$catalogPath = Join-Path $stateRoot 'catalog\ALL_WAFER_CATALOG.json'
$ledgerPath = Join-Path $stateRoot 'processor\PROCESSING_LEDGER.json'
$processorStatusPath = Join-Path $stateRoot 'processor\PROCESSOR_STATUS.json'
$readinessPath = Join-Path $stateRoot 'dashboard\DASHBOARD_CATALOG_STATUS.json'
$manifestPath = Join-Path $appRoot 'dashboard_manifest.json'
foreach ($path in @($catalogPath, $ledgerPath, $processorStatusPath, $manifestPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "GUIDU1 input is missing: $path" }
}

$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
$processorStatus = Get-Content -LiteralPath $processorStatusPath -Raw | ConvertFrom-Json
$manifestBefore = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$completedBefore = @(Get-CompletedKeys $manifestBefore)
$expectedHeld = @(Get-ExpectedHeldRows $catalog $ledger $processorStatus)
$guiBefore = @(Get-GuiHashRows)
$runtimeBefore = @(Get-RuntimeSnapshot)
$tasksBefore = @(Get-TaskSnapshot)

$preflightResult = [ordered]@{
    schema = 'argos_guidu1_updater_only_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIDU1_UPDATER_ONLY_PREFLIGHT'
    rehearsal = $isFixture
    catalogAcquisitions = @($catalog.acquisitions).Count
    completedRowsBefore = $completedBefore.Count
    expectedHeldRows = $expectedHeld.Count
    updaterSha256 = Get-Sha256 $updaterPath
    guiFilesPinned = $guiBefore.Count
    taskActions = 0
    processActions = 0
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 8; return }

$startedUtc = [DateTime]::UtcNow
$updaterOutput = (& $updaterPath -ConfigPath $configPath | Out-String)
if ($isFixture -and [bool]$fixture.failAfterUpdater) { throw 'INJECTED_GUIDU1_POST_UPDATER_FAILURE' }

$manifestAfter = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$readinessAfter = Get-Content -LiteralPath $readinessPath -Raw | ConvertFrom-Json
if ([string]$readinessAfter.state -ne 'DASHBOARD_CATALOG_READY_REVIEW_ONLY') { throw 'Dashboard updater did not report terminal READY.' }
if ([DateTimeOffset]::Parse([string]$manifestAfter.createdUtc).UtcDateTime -lt $startedUtc) { throw 'Dashboard manifest was not produced by this updater instance.' }
if ([DateTimeOffset]::Parse([string]$readinessAfter.updatedUtc).UtcDateTime -lt $startedUtc) { throw 'Dashboard status was not produced by this updater instance.' }

$completedAfter = @(Get-CompletedKeys $manifestAfter)
Assert-ExactSet $completedBefore $completedAfter 'Completed dashboard row'
$actualHeld = @($manifestAfter.heldAcquisitions)
$expectedKeys = @($expectedHeld | ForEach-Object { [string]$_.key })
$actualKeys = @($actualHeld | ForEach-Object { ([string]$_.identity) + '|' + (Property-Text $_ 'domain') })
Assert-ExactSet $expectedKeys $actualKeys 'Held acquisition-domain row'
$actualByKey = @{}
foreach ($row in $actualHeld) { $actualByKey[([string]$row.identity) + '|' + (Property-Text $row 'domain')] = $row }
foreach ($expected in $expectedHeld) {
    $actual = $actualByKey[[string]$expected.key]
    foreach ($pair in @(
        @('holdReason', [string]$expected.reason),
        @('holdDetail', [string]$expected.detail),
        @('holdSource', [string]$expected.source),
        @('currentJobKey', [string]$expected.jobKey),
        @('historicalCompletedRows', [string]$expected.historicalCompletedRows)
    )) {
        if ((Property-Text $actual $pair[0]) -cne $pair[1]) { throw "Held row exact $($pair[0]) mismatch: $($expected.key)" }
    }
    $holdReasonValue = Property-Text $actual 'holdReason'
    if ([string]::IsNullOrWhiteSpace($holdReasonValue)) { throw "Held row reason is empty: $($expected.key)" }
}

$catalogPhysicalKeys = @($catalog.acquisitions | ForEach-Object { (Property-Text $_ 'physicalIdentity') + '|' + (Property-Text $_ 'domain') })
$heldPhysicalKeys = @($actualHeld | ForEach-Object { (Property-Text $_ 'physicalIdentity') + '|' + (Property-Text $_ 'domain') })
Assert-ExactSet $catalogPhysicalKeys @($completedAfter + $heldPhysicalKeys) 'Catalog coverage'
if ([int]$readinessAfter.includedWafers -ne $completedAfter.Count -or [int]$readinessAfter.heldWafers -ne $actualHeld.Count) {
    throw 'Dashboard readiness counts disagree with the manifest.'
}

$guiAfter = @(Get-GuiHashRows)
$runtimeAfter = @(Get-RuntimeSnapshot)
$tasksAfter = @(Get-TaskSnapshot)
Assert-SnapshotUnchanged $guiBefore $guiAfter 'GUI bytes'
Assert-SnapshotUnchanged $runtimeBefore $runtimeAfter 'Installed-root process snapshot'
Assert-SnapshotUnchanged $tasksBefore $tasksAfter 'Argos task snapshot'
if ((Get-Sha256 $updaterPath) -ne $targetUpdaterSha256) { throw 'Installed updater changed during execution.' }

$reasonCounts = @(
    $actualHeld | Group-Object holdReason | Sort-Object Name | ForEach-Object {
        [ordered]@{ reason = [string]$_.Name; count = [int]$_.Count }
    }
)
[ordered]@{
    schema = 'argos_guidu1_updater_only_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIDU1_UPDATER_INSTALLED_RAN_AND_COMPLETE_HOLD_SET_VALIDATED'
    rehearsal = $isFixture
    catalogAcquisitions = @($catalog.acquisitions).Count
    completedRowsBefore = $completedBefore.Count
    completedRowsAfter = $completedAfter.Count
    completedRowsRegressed = 0
    heldRows = $actualHeld.Count
    exactReasonRowsValidated = $actualHeld.Count
    catalogCoverageRows = ($completedAfter.Count + $actualHeld.Count)
    reasonCounts = $reasonCounts
    dashboardCreatedUtc = [string]$manifestAfter.createdUtc
    dashboardStatusUpdatedUtc = [string]$readinessAfter.updatedUtc
    updaterOutput = $updaterOutput.Trim()
    updaterSha256 = Get-Sha256 $updaterPath
    guiBytesChanged = $false
    taskActions = 0
    processActions = 0
    detectorScoring = $false
    imageProcessing = $false
    xmlExportEnabled = $false
    sourceMutation = $false
    retry = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 10
