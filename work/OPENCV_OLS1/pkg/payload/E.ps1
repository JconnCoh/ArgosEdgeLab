[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Preflight -and $Rehearsal) { throw 'OLS1 cannot combine Preflight and Rehearsal.' }

$priorWorkerSha256 = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$targetWorkerSha256 = '2EC51AE77151C97910BAA93069E2CE90677813B1630F3BA1C48C60CB4B290A68'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$probeInvocationPath = ''
$failAfterSwap = $false

if ($Preflight -or $Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'OLS1 Preflight/Rehearsal requires InvocationManifest.' }
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    if ([string]$invocation.schema -ne 'argos_ols1_entrypoint_invocation_v1') { throw 'OLS1 entrypoint invocation schema mismatch.' }
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
    if (($full.Length + $Reserve) -ge 200 -or $longest -gt 80) { throw "OLS1 path budget refused: effective=$($full.Length + $Reserve) component=$longest path=$full" }
    return $full
}

function Write-Utf8JsonCreateNew {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value)
    if (Test-Path -LiteralPath $Path) { throw "OLS1 refuses overwrite: $Path" }
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
    if ($LASTEXITCODE -ne 0) { throw "OLS1 installed worker probe failed with exit code $LASTEXITCODE. $text" }
    try { return ($text | ConvertFrom-Json) }
    catch { throw "OLS1 installed worker probe did not return bounded JSON. $text" }
}

$workerPath = Assert-PathBudget (Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1')
$configPath = Assert-PathBudget (Join-Path $portalRoot 'config\endpoint_jbod.json')
$payloadWorker = Assert-PathBudget (Join-Path $PSScriptRoot 'W.ps1')
$outputPath = Assert-PathBudget (Join-Path $processorRoot 'OCV00_OLS1_LOT_PATHS.json')
$tempProbePath = Assert-PathBudget (Join-Path $processorRoot '.OLS1.probe.json')

foreach ($path in @($workerPath, $configPath, $payloadWorker)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS1 prerequisite is missing: $path" }
}
if ((Get-FileHash -LiteralPath $payloadWorker -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OLS1 payload worker hash changed.' }
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($payloadWorker, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw "OLS1 payload worker parser failure: $($errors[0].Message)" }

$installedBefore = (Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash
if ($installedBefore -ne $priorWorkerSha256 -and $installedBefore -ne $targetWorkerSha256) { throw "OLS1 installed endpoint worker predecessor is not approved: $installedBefore" }
if (Test-Path -LiteralPath $outputPath) { throw "OLS1 requires a fresh capability output namespace: $outputPath" }
if (Test-Path -LiteralPath $tempProbePath) { throw "OLS1 temporary probe path collision: $tempProbePath" }

if ($Preflight) {
    if (-not (Test-Path -LiteralPath $probeInvocationPath -PathType Leaf)) { throw "OLS1 preflight probe invocation is missing: $probeInvocationPath" }
    $probe = Get-Content -LiteralPath $probeInvocationPath -Raw | ConvertFrom-Json
    if ([string]$probe.schema -ne 'argos_project_portal_environment_probe_invocation_v1') { throw 'OLS1 preflight probe schema mismatch.' }
    if (-not ([IO.Path]::GetFullPath([string]$probe.outputPath)).Equals($outputPath, [StringComparison]::OrdinalIgnoreCase)) { throw 'OLS1 preflight output path mismatch.' }
    $probeResult = Invoke-WorkerJson -WorkerPath $payloadWorker -ConfigPath $configPath -ProbePath $probeInvocationPath -WorkerPreflight
    if ([string]$probeResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT' -or [bool]$probeResult.mutationsPerformed) { throw 'OLS1 payload worker non-mutating preflight failed.' }
    [ordered]@{
        schema = 'argos_ols1_entrypoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS1_ENTRYPOINT_PREFLIGHT'
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

$evidenceRoot = Assert-PathBudget (Join-Path $portalRoot ('state\maintenance_bootstrap\OLS1_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')))
if (Test-Path -LiteralPath $evidenceRoot) { throw "OLS1 evidence root collision: $evidenceRoot" }
$priorPath = Assert-PathBudget (Join-Path $evidenceRoot 'prior.ps1')
$backupPath = Assert-PathBudget (Join-Path $evidenceRoot 'swap.bak')
$failedPath = Assert-PathBudget (Join-Path $evidenceRoot 'failed.ps1')
$failedOutputPath = Assert-PathBudget (Join-Path $evidenceRoot 'failed_probe.json')
$stagePath = Assert-PathBudget (Join-Path (Split-Path -Parent $workerPath) 'OLS1.stage.ps1')
$restorePath = Assert-PathBudget (Join-Path (Split-Path -Parent $workerPath) 'OLS1.restore.ps1')
foreach ($path in @($stagePath, $restorePath)) { if (Test-Path -LiteralPath $path) { throw "OLS1 short swap path collision: $path" } }

$changed = $false
$swapped = $false
[void](New-Item -ItemType Directory -Path $evidenceRoot)
try {
    if ($installedBefore -eq $priorWorkerSha256) {
        Copy-Item -LiteralPath $workerPath -Destination $priorPath -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $priorPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OLS1 predecessor archive hash mismatch.' }
        Copy-Item -LiteralPath $payloadWorker -Destination $stagePath -ErrorAction Stop
        if ((Get-FileHash -LiteralPath $stagePath -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OLS1 staged worker hash mismatch.' }
        [IO.File]::Replace($stagePath, $workerPath, $backupPath, $true)
        $swapped = $true
        if ((Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OLS1 installed worker target hash mismatch.' }
        if ((Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OLS1 atomic backup predecessor hash mismatch.' }
        $changed = $true
    }
    if ($failAfterSwap) { throw 'INJECTED_OLS1_FAILURE_AFTER_SWAP' }

    $probeValue = [ordered]@{
        schema = 'argos_project_portal_environment_probe_invocation_v1'
        outputPath = $outputPath
        parameters = [ordered]@{
            environmentInventory = [ordered]@{
                enabled = $true
                approvedDataRoot = 'JBOD_KLARF_EXPORT'
                boundedPathNameSearch = [ordered]@{
                    enabled = $true
                    literalToken = '62616-115'
                    maximumDepth = 3
                    maximumEntries = 50000
                    maximumMatches = 128
                }
            }
        }
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-Utf8JsonCreateNew -Path $tempProbePath -Value $probeValue
    $preflightResult = Invoke-WorkerJson -WorkerPath $workerPath -ConfigPath $configPath -ProbePath $tempProbePath -WorkerPreflight
    if ([string]$preflightResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT' -or [bool]$preflightResult.mutationsPerformed) { throw 'OLS1 installed producer preflight failed.' }
    $plannedSearch = $preflightResult.inventory.boundedPathNameSearch
    if ([string]$preflightResult.inventory.schema -ne 'argos_project_portal_environment_inventory_v3' -or [string]$plannedSearch.state -ne 'UNOBSERVED_PREFLIGHT' -or [string]$plannedSearch.literalToken -ne '62616-115' -or [int]$plannedSearch.maximumDepth -ne 3 -or [int]$plannedSearch.maximumEntries -ne 50000 -or [int]$plannedSearch.maximumMatches -ne 128 -or [bool]$preflightResult.inventory.pathsEnumerated -or [bool]$plannedSearch.filesRead -or [bool]$plannedSearch.imageBytesRead -or [bool]$plannedSearch.mutationsPerformed) { throw 'OLS1 installed producer preflight search contract failed.' }
    $producerResult = Invoke-WorkerJson -WorkerPath $workerPath -ConfigPath $configPath -ProbePath $tempProbePath
    if ([string]$producerResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY') { throw 'OLS1 installed producer terminal status failed.' }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'OLS1 installed producer did not create its output.' }
    $output = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
    if ([string]$output.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY') { throw 'OLS1 output terminal state failed.' }
    if ([string]$output.workerSha256 -ne $targetWorkerSha256) { throw 'OLS1 output worker revision mismatch.' }
    if ([bool]$output.inventory.mutationsPerformed -or -not [bool]$output.inventory.pathsEnumerated -or [bool]$output.inventory.filesRead -or [bool]$output.inventory.imageBytesRead) { throw 'OLS1 output violated read-only inventory boundaries.' }
    $search = $output.inventory.boundedPathNameSearch
    $matches = @($search.matches)
    if ([string]$output.inventory.schema -ne 'argos_project_portal_environment_inventory_v3' -or [string]$search.schema -ne 'argos_bounded_path_name_search_v1' -or [string]$search.state -ne 'COMPLETE' -or -not [bool]$search.complete -or [string]$search.literalToken -ne '62616-115' -or [bool]$search.truncated -or [int]$search.accessErrorCount -ne 0 -or [int]$search.skippedReparseSubtrees -ne 0 -or [int]$search.skippedUnsafePathSubtrees -ne 0) { throw 'OLS1 output bounded path-name search did not complete safely.' }
    if ($matches.Count -ne [int]$search.matchCount -or @($matches | Where-Object { -not [bool]$_.containedByApprovedRoot -or ([string]$_.name).IndexOf('62616-115',[StringComparison]::OrdinalIgnoreCase) -lt 0 -or [bool]$_.filesRead -or [bool]$_.imageBytesRead -or [bool]$_.sourceHashingPerformed -or [bool]$_.mutationsPerformed }).Count -ne 0) { throw 'OLS1 output bounded path-name result safety contract failed.' }

    [ordered]@{
        schema = 'argos_ols1_entrypoint_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OCV00_BOUNDED_LOT_PATH_SEARCH_OLS1'
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
        boundedPathNameSearch = $search
        metadataOnly = $true
        pathsEnumerated = $true
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
        if ((Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OLS1 rollback failed to restore the approved predecessor.' }
    }
    throw $failure
}
finally {
    foreach ($path in @($tempProbePath, $stagePath, $restorePath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    }
}
