[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Preflight -and $Rehearsal) { throw 'OEL1 cannot combine Preflight and Rehearsal.' }

$priorWorkerSha256 = '750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08'
$targetWorkerSha256 = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$probeInvocationPath = ''
$failAfterSwap = $false

if ($Preflight -or $Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'OEL1 Preflight/Rehearsal requires InvocationManifest.' }
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    if ([string]$invocation.schema -ne 'argos_oel1_entrypoint_invocation_v1') { throw 'OEL1 entrypoint invocation schema mismatch.' }
    $portalRoot = [IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\')
    $processorRoot = [IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $probeInvocationPath = [IO.Path]::GetFullPath([string]$invocation.probeInvocationPath)
    $failAfterSwap = ($invocation.PSObject.Properties.Name -contains 'failAfterSwap') -and [bool]$invocation.failAfterSwap
}

function Assert-PathBudget {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$Reserve = 32)
    $full = [IO.Path]::GetFullPath($Path)
    $longest = 0
    foreach ($component in $full.Split(@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar), [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($component.Length -gt $longest) { $longest = $component.Length }
    }
    if (($full.Length + $Reserve) -ge 200 -or $longest -gt 80) { throw "OEL1 path budget refused: effective=$($full.Length + $Reserve) component=$longest path=$full" }
    return $full
}

function Write-Utf8JsonCreateNew {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value)
    if (Test-Path -LiteralPath $Path) { throw "OEL1 refuses overwrite: $Path" }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), (New-Object Text.UTF8Encoding($false)))
}

function Invoke-WorkerJson {
    param(
        [Parameter(Mandatory = $true)][string]$WorkerPath,
        [Parameter(Mandatory = $true)][string]$ConfigPath,
        [Parameter(Mandatory = $true)][string]$ProbePath,
        [switch]$WorkerPreflight
    )
    $exe = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $WorkerPath, '-ConfigPath', $ConfigPath)
    if ($WorkerPreflight) { $arguments += '-Preflight' }
    $arguments += @('-EnvironmentProbeManifest', $ProbePath)
    $text = & $exe @arguments 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "OEL1 installed worker probe failed with exit code $LASTEXITCODE. $text" }
    try { return ($text | ConvertFrom-Json) }
    catch { throw "OEL1 installed worker probe did not return bounded JSON. $text" }
}

$workerPath = Assert-PathBudget (Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1')
$configPath = Assert-PathBudget (Join-Path $portalRoot 'config\endpoint_jbod.json')
$payloadWorker = Assert-PathBudget (Join-Path $PSScriptRoot 'W.ps1')
$outputPath = Assert-PathBudget (Join-Path $processorRoot 'OCV00_OEL1_EXACT_LEAF_STATUS.json')
$tempProbePath = Assert-PathBudget (Join-Path $processorRoot '.OEL1.probe.json')

foreach ($path in @($workerPath, $configPath, $payloadWorker)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OEL1 prerequisite is missing: $path" }
}
if ((Get-FileHash -LiteralPath $payloadWorker -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OEL1 payload worker hash changed.' }
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($payloadWorker, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw "OEL1 payload worker parser failure: $($errors[0].Message)" }

$installedBefore = (Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash
if ($installedBefore -ne $priorWorkerSha256 -and $installedBefore -ne $targetWorkerSha256) { throw "OEL1 installed endpoint worker predecessor is not approved: $installedBefore" }
if (Test-Path -LiteralPath $outputPath) { throw "OEL1 requires a fresh capability output namespace: $outputPath" }
if (Test-Path -LiteralPath $tempProbePath) { throw "OEL1 temporary probe path collision: $tempProbePath" }

if ($Preflight) {
    if (-not (Test-Path -LiteralPath $probeInvocationPath -PathType Leaf)) { throw "OEL1 preflight probe invocation is missing: $probeInvocationPath" }
    $probe = Get-Content -LiteralPath $probeInvocationPath -Raw | ConvertFrom-Json
    if ([string]$probe.schema -ne 'argos_project_portal_environment_probe_invocation_v1') { throw 'OEL1 preflight probe schema mismatch.' }
    if (-not ([IO.Path]::GetFullPath([string]$probe.outputPath)).Equals($outputPath, [StringComparison]::OrdinalIgnoreCase)) { throw 'OEL1 preflight output path mismatch.' }
    $probeResult = Invoke-WorkerJson -WorkerPath $payloadWorker -ConfigPath $configPath -ProbePath $probeInvocationPath -WorkerPreflight
    if ([string]$probeResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT' -or [bool]$probeResult.mutationsPerformed) { throw 'OEL1 payload worker non-mutating preflight failed.' }
    [ordered]@{
        schema = 'argos_oel1_entrypoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OEL1_ENTRYPOINT_PREFLIGHT'
        installedWorkerSha256 = $installedBefore
        targetWorkerSha256 = $targetWorkerSha256
        outputPath = $outputPath
        payloadWorkerPreflightState = [string]$probeResult.state
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$evidenceRoot = Assert-PathBudget (Join-Path $portalRoot ('state\maintenance_bootstrap\OEL1_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')))
if (Test-Path -LiteralPath $evidenceRoot) { throw "OEL1 evidence root collision: $evidenceRoot" }
$priorPath = Assert-PathBudget (Join-Path $evidenceRoot 'prior.ps1')
$backupPath = Assert-PathBudget (Join-Path $evidenceRoot 'swap.bak')
$failedPath = Assert-PathBudget (Join-Path $evidenceRoot 'failed.ps1')
$failedOutputPath = Assert-PathBudget (Join-Path $evidenceRoot 'failed_probe.json')
$stagePath = Assert-PathBudget (Join-Path (Split-Path -Parent $workerPath) 'OEL1.stage.ps1')
$restorePath = Assert-PathBudget (Join-Path (Split-Path -Parent $workerPath) 'OEL1.restore.ps1')
foreach ($path in @($stagePath, $restorePath)) { if (Test-Path -LiteralPath $path) { throw "OEL1 short swap path collision: $path" } }

$changed = $false
$swapped = $false
[void](New-Item -ItemType Directory -Path $evidenceRoot)
try {
    if ($installedBefore -eq $priorWorkerSha256) {
        Copy-Item -LiteralPath $workerPath -Destination $priorPath -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $priorPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OEL1 predecessor archive hash mismatch.' }
        Copy-Item -LiteralPath $payloadWorker -Destination $stagePath -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $stagePath -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OEL1 staged worker hash mismatch.' }
        [IO.File]::Replace($stagePath, $workerPath, $backupPath, $true)
        $swapped = $true
        if ((Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OEL1 installed worker target hash mismatch.' }
        if ((Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OEL1 atomic backup predecessor hash mismatch.' }
        $changed = $true
    }
    if ($failAfterSwap) { throw 'INJECTED_OEL1_FAILURE_AFTER_SWAP' }

    $probeValue = [ordered]@{
        schema = 'argos_project_portal_environment_probe_invocation_v1'
        outputPath = $outputPath
        parameters = [ordered]@{
            environmentInventory = [ordered]@{
                enabled = $true
                approvedDataRoot = 'JBOD_KLARF_EXPORT'
                processLocalAliasName = 'F'
                approvedRootRelativeLeafPaths = @(
                    'PatternedFront/Lot_62628-281/62628-281_20260813112015/Slot02/BrightfieldFrontsideWafer/resizedImage/62628-281_Slot02_BrightfieldFrontsideWafer_PM2_resizedImage.bmp',
                    'PatternedFront/Lot_62628-281/62628-281_20260813112015/Slot02/DarkfieldFrontsideWafer/resizedImage/62628-281_Slot02_DarkfieldFrontsideWafer_PM2_resizedImage.bmp',
                    'PatternedFront/Lot_62616-115/62616-115_20260807120245/Slot23/BrightfieldFrontsideWafer/resizedImage/62616-115_Slot23_BrightfieldFrontsideWafer_PM2_resizedImage.bmp',
                    'PatternedFront/Lot_62616-115/62616-115_20260807120245/Slot23/DarkfieldFrontsideWafer/resizedImage/62616-115_Slot23_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'
                )
            }
        }
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-Utf8JsonCreateNew -Path $tempProbePath -Value $probeValue
    $preflightResult = Invoke-WorkerJson -WorkerPath $workerPath -ConfigPath $configPath -ProbePath $tempProbePath -WorkerPreflight
    if ([string]$preflightResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT' -or [bool]$preflightResult.mutationsPerformed) { throw 'OEL1 installed producer preflight failed.' }
    $plannedLeaves = @($preflightResult.inventory.exactRelativeLeaves)
    if ([string]$preflightResult.inventory.schema -ne 'argos_project_portal_environment_inventory_v2' -or $plannedLeaves.Count -ne 4 -or @($plannedLeaves | Where-Object { [string]$_.pathType -ne 'UNOBSERVED_PREFLIGHT' -or [bool]$_.enumerated -or [bool]$_.filesRead -or [bool]$_.imageBytesRead -or [bool]$_.mutationsPerformed }).Count -ne 0) { throw 'OEL1 installed producer preflight leaf contract failed.' }
    $producerResult = Invoke-WorkerJson -WorkerPath $workerPath -ConfigPath $configPath -ProbePath $tempProbePath
    if ([string]$producerResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY') { throw 'OEL1 installed producer terminal status failed.' }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'OEL1 installed producer did not create its output.' }
    $output = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
    if ([string]$output.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY') { throw 'OEL1 output terminal state failed.' }
    if ([string]$output.workerSha256 -ne $targetWorkerSha256) { throw 'OEL1 output worker revision mismatch.' }
    if ([bool]$output.inventory.mutationsPerformed -or [bool]$output.inventory.pathsEnumerated -or [bool]$output.inventory.filesRead -or [bool]$output.inventory.imageBytesRead) { throw 'OEL1 output violated read-only inventory boundaries.' }
    $leaves = @($output.inventory.exactRelativeLeaves)
    if ([string]$output.inventory.schema -ne 'argos_project_portal_environment_inventory_v2' -or $leaves.Count -ne 4) { throw 'OEL1 output exact-leaf cardinality or schema failed.' }
    if (@($leaves | Where-Object { -not [bool]$_.containedByApprovedRoot -or [bool]$_.enumerated -or [bool]$_.filesRead -or [bool]$_.imageBytesRead -or [bool]$_.mutationsPerformed }).Count -ne 0) { throw 'OEL1 output exact-leaf safety contract failed.' }
    if ([string]$output.inventory.processLocalAlias.name -ne 'F' -or -not [bool]$output.inventory.processLocalAlias.created -or -not [bool]$output.inventory.processLocalAlias.removed -or [bool]$output.inventory.processLocalAlias.persistent) { throw 'OEL1 output process-local alias lifecycle failed.' }

    [ordered]@{
        schema = 'argos_oel1_entrypoint_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_FIDCV1_JBOD_INVENTORY_CAPABILITY_OEL1'
        rehearsal = [bool]$Rehearsal
        workerPath = $workerPath
        priorWorkerSha256 = $installedBefore
        installedWorkerSha256 = (Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash
        workerChanged = $changed
        producerPreflightState = [string]$preflightResult.state
        producerTerminalState = [string]$producerResult.state
        capabilityOutputPath = $outputPath
        capabilityOutputSha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
        capabilityOutputBytes = (Get-Item -LiteralPath $outputPath).Length
        exactRelativeLeaves = $leaves
        metadataOnly = $true
        pathsEnumerated = $false
        filesRead = $false
        inspectionTasksChanged = $false
        processorTaskChanged = $false
        processActions = @()
        imageBytesRead = $false
        sourceHashingPerformed = $false
        sourceDeletionPerformed = $false
        waferActionPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
}
catch {
    $failure = $_
    if (Test-Path -LiteralPath $outputPath -PathType Leaf) { Move-Item -LiteralPath $outputPath -Destination $failedOutputPath -ErrorAction SilentlyContinue }
    if ($swapped) {
        Copy-Item -LiteralPath $priorPath -Destination $restorePath -ErrorAction Stop
        [IO.File]::Replace($restorePath, $workerPath, $failedPath, $true)
        if ((Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OEL1 rollback failed to restore the approved predecessor.' }
    }
    throw $failure
}
finally {
    foreach ($path in @($tempProbePath, $stagePath, $restorePath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    }
}
