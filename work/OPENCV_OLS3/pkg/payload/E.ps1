[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Preflight -and $Rehearsal) { throw 'OLS3 cannot combine Preflight and Rehearsal.' }

function Get-ArgosFileHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [ValidateSet('SHA256')][string]$Algorithm='SHA256'
    )
    $full=[IO.Path]::GetFullPath($LiteralPath)
    $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $hex=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')
        return [pscustomobject]@{Algorithm='SHA256';Hash=$hex;Path=$full}
    }finally{
        $sha.Dispose()
        $stream.Dispose()
    }
}

$priorWorkerSha256 = '1CE01F67083A989CB92AE3824DB0AE2CB6532FD6B674E74456CC495F06DCDDF8'
$targetWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$probeInvocationPath = ''
$failAfterSwap = $false
$maximumBmpLeaves = 2048

if ($Preflight -or $Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'OLS3 Preflight/Rehearsal requires InvocationManifest.' }
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    if ([string]$invocation.schema -ne 'argos_ols3_entrypoint_invocation_v1') { throw 'OLS3 entrypoint invocation schema mismatch.' }
    $portalRoot = [IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\')
    $processorRoot = [IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $probeInvocationPath = [IO.Path]::GetFullPath([string]$invocation.probeInvocationPath)
    $failAfterSwap = ($invocation.PSObject.Properties.Name -contains 'failAfterSwap') -and [bool]$invocation.failAfterSwap
    if ($Rehearsal -and ($invocation.PSObject.Properties.Name -contains 'maximumBmpLeaves')) {
        $maximumBmpLeaves = [int]$invocation.maximumBmpLeaves
        if ($maximumBmpLeaves -lt 1 -or $maximumBmpLeaves -gt 2048) { throw 'OLS3 rehearsal maximumBmpLeaves must be 1 through 2048.' }
    }
}

function Assert-PathBudget {
    param([Parameter(Mandatory = $true)][string]$Path, [int]$Reserve = 32)
    $full = [IO.Path]::GetFullPath($Path)
    $longest = 0
    foreach ($component in $full.Split(@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar), [StringSplitOptions]::RemoveEmptyEntries)) {
        if ($component.Length -gt $longest) { $longest = $component.Length }
    }
    if (($full.Length + $Reserve) -ge 200 -or $longest -gt 80) { throw "OLS3 path budget refused: effective=$($full.Length + $Reserve) component=$longest path=$full" }
    return $full
}

function Write-Utf8JsonCreateNew {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value)
    if (Test-Path -LiteralPath $Path) { throw "OLS3 refuses overwrite: $Path" }
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
    if ($LASTEXITCODE -ne 0) { throw "OLS3 installed worker probe failed with exit code $LASTEXITCODE. $text" }
    try { return ($text | ConvertFrom-Json) }
    catch { throw "OLS3 installed worker probe did not return bounded JSON. $text" }
}

$workerPath = Assert-PathBudget (Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1')
$configPath = Assert-PathBudget (Join-Path $portalRoot 'config\endpoint_jbod.json')
$payloadWorker = Assert-PathBudget (Join-Path $PSScriptRoot 'W.ps1')
$outputPath = Assert-PathBudget (Join-Path $processorRoot 'OCV00_OLS3_LOT_INVENTORY.json')
$tempProbePath = Assert-PathBudget (Join-Path $processorRoot '.OLS3.probe.json')

foreach ($path in @($workerPath, $configPath, $payloadWorker)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS3 prerequisite is missing: $path" }
}
if ((Get-ArgosFileHash -LiteralPath $payloadWorker -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OLS3 payload worker hash changed.' }
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($payloadWorker, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw "OLS3 payload worker parser failure: $($errors[0].Message)" }

$installedBefore = (Get-ArgosFileHash -LiteralPath $workerPath -Algorithm SHA256).Hash
if ($installedBefore -ne $priorWorkerSha256 -and $installedBefore -ne $targetWorkerSha256) { throw "OLS3 installed endpoint worker predecessor is not approved: $installedBefore" }
if (Test-Path -LiteralPath $outputPath) { throw "OLS3 requires a fresh capability output namespace: $outputPath" }
if (Test-Path -LiteralPath $tempProbePath) { throw "OLS3 temporary probe path collision: $tempProbePath" }

if ($Preflight) {
    if (-not (Test-Path -LiteralPath $probeInvocationPath -PathType Leaf)) { throw "OLS3 preflight probe invocation is missing: $probeInvocationPath" }
    $probe = Get-Content -LiteralPath $probeInvocationPath -Raw | ConvertFrom-Json
    if ([string]$probe.schema -ne 'argos_project_portal_environment_probe_invocation_v1') { throw 'OLS3 preflight probe schema mismatch.' }
    if (-not ([IO.Path]::GetFullPath([string]$probe.outputPath)).Equals($outputPath, [StringComparison]::OrdinalIgnoreCase)) { throw 'OLS3 preflight output path mismatch.' }
    $probeResult = Invoke-WorkerJson -WorkerPath $payloadWorker -ConfigPath $configPath -ProbePath $probeInvocationPath -WorkerPreflight
    if ([string]$probeResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT' -or [bool]$probeResult.mutationsPerformed) { throw 'OLS3 payload worker non-mutating preflight failed.' }
    [ordered]@{
        schema = 'argos_ols3_entrypoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS3_ENTRYPOINT_PREFLIGHT'
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

$evidenceRoot = Assert-PathBudget (Join-Path $portalRoot ('state\maintenance_bootstrap\OLS3_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')))
if (Test-Path -LiteralPath $evidenceRoot) { throw "OLS3 evidence root collision: $evidenceRoot" }
$priorPath = Assert-PathBudget (Join-Path $evidenceRoot 'prior.ps1')
$backupPath = Assert-PathBudget (Join-Path $evidenceRoot 'swap.bak')
$failedPath = Assert-PathBudget (Join-Path $evidenceRoot 'failed.ps1')
$failedOutputPath = Assert-PathBudget (Join-Path $evidenceRoot 'failed_probe.json')
$stagePath = Assert-PathBudget (Join-Path (Split-Path -Parent $workerPath) 'OLS3.stage.ps1')
$restorePath = Assert-PathBudget (Join-Path (Split-Path -Parent $workerPath) 'OLS3.restore.ps1')
foreach ($path in @($stagePath, $restorePath)) { if (Test-Path -LiteralPath $path) { throw "OLS3 short swap path collision: $path" } }

$changed = $false
$swapped = $false
[void](New-Item -ItemType Directory -Path $evidenceRoot)
try {
    if ($installedBefore -eq $priorWorkerSha256) {
        Copy-Item -LiteralPath $workerPath -Destination $priorPath -ErrorAction Stop
        if ((Get-ArgosFileHash -LiteralPath $priorPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OLS3 predecessor archive hash mismatch.' }
        Copy-Item -LiteralPath $payloadWorker -Destination $stagePath -ErrorAction Stop
        if ((Get-ArgosFileHash -LiteralPath $stagePath -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OLS3 staged worker hash mismatch.' }
        [IO.File]::Replace($stagePath, $workerPath, $backupPath, $true)
        $swapped = $true
        if ((Get-ArgosFileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne $targetWorkerSha256) { throw 'OLS3 installed worker target hash mismatch.' }
        if ((Get-ArgosFileHash -LiteralPath $backupPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OLS3 atomic backup predecessor hash mismatch.' }
        $changed = $true
    }
    if ($failAfterSwap) { throw 'INJECTED_OLS3_FAILURE_AFTER_SWAP' }

    $probeValue = [ordered]@{
        schema = 'argos_project_portal_environment_probe_invocation_v1'
        outputPath = $outputPath
        parameters = [ordered]@{
            environmentInventory = [ordered]@{
                enabled = $true
                approvedDataRoot = 'JBOD_KLARF_EXPORT'
                processLocalAliasName = 'F'
                boundedSubtreeInventory = [ordered]@{
                    enabled = $true
                    relativeRoot = 'PatternedFront\Lot_62619-433'
                    maximumDepth = 8
                    maximumEntries = 20000
                    maximumDirectories = 2048
                    maximumBmpLeaves = $maximumBmpLeaves
                }
            }
        }
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-Utf8JsonCreateNew -Path $tempProbePath -Value $probeValue
    $preflightResult = Invoke-WorkerJson -WorkerPath $workerPath -ConfigPath $configPath -ProbePath $tempProbePath -WorkerPreflight
    if ([string]$preflightResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT' -or [bool]$preflightResult.mutationsPerformed) { throw 'OLS3 installed producer preflight failed.' }
    $plannedInventory = $preflightResult.inventory.boundedSubtreeInventory
    if ([string]$preflightResult.inventory.schema -ne 'argos_project_portal_environment_inventory_v3' -or [string]$plannedInventory.schema -ne 'argos_bounded_subtree_inventory_v1' -or [string]$plannedInventory.state -ne 'UNOBSERVED_PREFLIGHT' -or [string]$plannedInventory.relativeRoot -ne 'PatternedFront\Lot_62619-433' -or [string]$plannedInventory.aliasReadRoot -ne 'F:\PatternedFront\Lot_62619-433' -or [int]$plannedInventory.maximumDepth -ne 8 -or [int]$plannedInventory.maximumEntries -ne 20000 -or [int]$plannedInventory.maximumDirectories -ne 2048 -or [int]$plannedInventory.maximumBmpLeaves -ne $maximumBmpLeaves -or [bool]$preflightResult.inventory.pathsEnumerated -or [bool]$plannedInventory.pathsEnumerated -or [bool]$plannedInventory.filesRead -or [bool]$plannedInventory.imageBytesRead -or [bool]$plannedInventory.sourceHashingPerformed -or [bool]$plannedInventory.mutationsPerformed) { throw 'OLS3 installed producer preflight subtree contract failed.' }
    $producerResult = Invoke-WorkerJson -WorkerPath $workerPath -ConfigPath $configPath -ProbePath $tempProbePath
    if ([string]$producerResult.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY') { throw 'OLS3 installed producer terminal status failed.' }
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) { throw 'OLS3 installed producer did not create its output.' }
    $output = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
    if ([string]$output.state -ne 'PASS_JBOD_ENVIRONMENT_INVENTORY') { throw 'OLS3 output terminal state failed.' }
    if ([string]$output.workerSha256 -ne $targetWorkerSha256) { throw 'OLS3 output worker revision mismatch.' }
    if ([bool]$output.inventory.mutationsPerformed -or -not [bool]$output.inventory.pathsEnumerated -or [bool]$output.inventory.filesRead -or [bool]$output.inventory.imageBytesRead -or [string]$output.inventory.processLocalAlias.name -ne 'F' -or -not [bool]$output.inventory.processLocalAlias.created -or -not [bool]$output.inventory.processLocalAlias.removed -or [bool]$output.inventory.processLocalAlias.persistent) { throw 'OLS3 output violated read-only inventory boundaries.' }
    $subtree = $output.inventory.boundedSubtreeInventory
    $directories = @($subtree.directories)
    $bmpLeaves = @($subtree.bmpLeaves)
    if ([string]$output.inventory.schema -ne 'argos_project_portal_environment_inventory_v3' -or [string]$subtree.schema -ne 'argos_bounded_subtree_inventory_v1' -or [string]$subtree.state -notin @('COMPLETE','HOLD_INCOMPLETE') -or ([bool]$subtree.complete -ne ([string]$subtree.state -eq 'COMPLETE')) -or [string]$subtree.relativeRoot -ne 'PatternedFront\Lot_62619-433') { throw 'OLS3 output bounded subtree contract changed.' }
    if ($directories.Count -ne [int]$subtree.directoryCount -or $bmpLeaves.Count -ne [int]$subtree.bmpLeafCount) { throw 'OLS3 output bounded subtree row counts changed.' }
    if (@($directories | Where-Object { -not [bool]$_.containedByApprovedRoot -or -not ([string]$_.relativePath).StartsWith('PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or -not ([string]$_.aliasReadPath).StartsWith('F:\PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or [int]$_.canonicalEffectiveLength -ge 230 -or [int]$_.aliasEffectiveLength -ge 200 -or [bool]$_.reparsePoint -or [bool]$_.filesRead -or [bool]$_.imageBytesRead -or [bool]$_.sourceHashingPerformed -or [bool]$_.mutationsPerformed }).Count -ne 0) { throw 'OLS3 output bounded subtree directory-row safety contract failed.' }
    if (@($bmpLeaves | Where-Object { -not [bool]$_.containedByApprovedRoot -or -not ([string]$_.relativePath).StartsWith('PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or -not ([string]$_.aliasReadPath).StartsWith('F:\PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or [int]$_.canonicalEffectiveLength -ge 230 -or [int]$_.aliasEffectiveLength -ge 200 -or [string]$_.extension -ne '.bmp' -or [bool]$_.reparsePoint -or [bool]$_.filesRead -or [bool]$_.imageBytesRead -or [bool]$_.sourceHashingPerformed -or [bool]$_.mutationsPerformed }).Count -ne 0) { throw 'OLS3 output bounded subtree BMP-row safety contract failed.' }

    $holdReasons = @()
    if (-not [bool]$subtree.rootExists) { $holdReasons += 'ROOT_MISSING' }
    if ([bool]$subtree.truncated) { $holdReasons += 'TRUNCATED' }
    if ([int]$subtree.accessErrorCount -gt 0) { $holdReasons += 'ACCESS_ERRORS' }
    if ([int]$subtree.skippedReparseSubtrees -gt 0) { $holdReasons += 'REPARSE_SUBTREES_SKIPPED' }
    if ([int]$subtree.skippedUnsafePathSubtrees -gt 0) { $holdReasons += 'UNSAFE_PATH_SUBTREES_SKIPPED' }
    if ([int]$subtree.depthBoundaryDirectoryCount -gt 0) { $holdReasons += 'DEPTH_BOUNDARY_DIRECTORIES' }
    $inventoryDisposition = if ($holdReasons.Count -eq 0 -and [bool]$subtree.complete) { 'COMPLETE' } else { 'HOLD_INCOMPLETE' }

    [ordered]@{
        schema = 'argos_ols3_entrypoint_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3'
        rehearsal = [bool]$Rehearsal
        workerPath = $workerPath
        priorWorkerSha256 = $installedBefore
        installedWorkerSha256 = (Get-ArgosFileHash -LiteralPath $workerPath -Algorithm SHA256).Hash
        workerChanged = $changed
        producerPreflightState = [string]$preflightResult.state
        producerTerminalState = [string]$producerResult.state
        capabilityOutputPath = $outputPath
        capabilityOutputSha256 = (Get-ArgosFileHash -LiteralPath $outputPath -Algorithm SHA256).Hash
        capabilityOutputBytes = (Get-Item -LiteralPath $outputPath).Length
        boundedSubtreeInventory = $subtree
        inventoryDisposition = $inventoryDisposition
        holdReasons = $holdReasons
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
        if ((Get-ArgosFileHash -LiteralPath $workerPath -Algorithm SHA256).Hash -ne $priorWorkerSha256) { throw 'OLS3 rollback failed to restore the approved predecessor.' }
    }
    throw $failure
}
finally {
    foreach ($path in @($tempProbePath, $stagePath, $restorePath)) {
        if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
    }
}
