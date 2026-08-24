[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Get-Sha256([string]$LiteralPath) {
    $stream = [IO.File]::Open($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-Json([string]$LiteralPath, [object]$Value) {
    [IO.File]::WriteAllText($LiteralPath, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$endpoint = Join-Path $PSScriptRoot 'Invoke-OCV00SourceHashEndpoint.ps1'
$fixtureRoot = 'C:\O5G'
$gatePath = Join-Path $PSScriptRoot 'OLS5_SOURCE_HASH_LOCAL_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
if (-not (Test-Path -LiteralPath $endpoint -PathType Leaf) -or -not (Test-Path -LiteralPath $pathTool -PathType Leaf)) { throw 'OLS5 local-gate prerequisite is missing.' }
if ((Test-Path -LiteralPath $fixtureRoot) -or (Test-Path -LiteralPath $gatePath)) { throw 'OLS5 local-gate output already exists.' }
$planned = @($fixtureRoot, (Join-Path $fixtureRoot 'portal\config\endpoint_jbod.json'), (Join-Path $fixtureRoot 'proc\success.json'), (Join-Path $fixtureRoot 'proc\injected.json'), $gatePath)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw 'OLS5 local-gate path budget failed.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols5_source_hash_local_gate_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS5_SOURCE_HASH_LOCAL_GATE_PREFLIGHT'
        endpointSha256 = Get-Sha256 $endpoint
        fixtureRoot = $fixtureRoot
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        imageProcessingPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}

$portalRoot = Join-Path $fixtureRoot 'portal'
$processorRoot = Join-Path $fixtureRoot 'proc'
$sourceRoot = Join-Path $fixtureRoot 'source'
$lotRoot = Join-Path $sourceRoot 'PatternedFront\Lot_TEST'
$bfRelative = 'ACQ_TEST\Slot01\BrightfieldFrontsideWafer\resizedImage\TEST_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
$dfRelative = 'ACQ_TEST\Slot01\DarkfieldFrontsideWafer\resizedImage\TEST_Slot01_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'
$bfPath = Join-Path $lotRoot $bfRelative
$dfPath = Join-Path $lotRoot $dfRelative
foreach ($directory in @((Join-Path $portalRoot 'config'), $processorRoot, [IO.Path]::GetDirectoryName($bfPath), [IO.Path]::GetDirectoryName($dfPath))) { [void](New-Item -ItemType Directory -Path $directory) }
$bfBytes = New-Object byte[] 4096
$dfBytes = New-Object byte[] 4096
for ($index = 0; $index -lt 4096; $index++) { $bfBytes[$index] = [byte]($index % 251); $dfBytes[$index] = [byte](255 - ($index % 251)) }
[IO.File]::WriteAllBytes($bfPath, $bfBytes)
[IO.File]::WriteAllBytes($dfPath, $dfBytes)

$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
Write-Json $configPath ([ordered]@{ schema = 'argos_project_portal_endpoint_config_v1'; role = 'JBOD'; approvedDataRoots = @([ordered]@{ name = 'JBOD_KLARF_EXPORT'; path = $sourceRoot }); reviewOnly = $true; productionRoutingEnabled = $false })
$targetsPath = Join-Path $fixtureRoot 'targets.json'
$targets = [ordered]@{
    schema = 'argos_ocv00_source_hash_targets_v1'; revision = 'OLS5_LOCAL'; state = 'FROZEN'; disposition = 'LOCKED_INPUT'; approvedDataRoot = 'JBOD_KLARF_EXPORT'; relativeSubtree = 'PatternedFront/Lot_TEST'; lotId = 'TEST'; acquisitionId = 'ACQ_TEST'; pathTemplate = '{acquisitionId}/{slot}/{channel}FrontsideWafer/resizedImage/{lotId}_{slot}_{channel}FrontsideWafer_PM2_resizedImage.bmp'; channels = @('Brightfield', 'Darkfield'); slots = @([ordered]@{ slot = 'Slot01'; partition = 'DEVELOPMENT' }); expectedBytesPerLeaf = 4096; targetCount = 2; sourceHashAlgorithm = 'SHA256'; decodePixels = $false; imageProcessingAllowed = $false; sourceMutationAllowed = $false; taskOrProcessActionAllowed = $false; reviewOnly = $true; trainingEligible = $false; xmlEligible = $false; productionEligible = $false
}
Write-Json $targetsPath $targets

$inventoryPath = Join-Path $processorRoot 'inventory.json'
$bmpRows = @(
    [ordered]@{ subtreeRelativePath = $bfRelative; canonicalProvenancePath = 'D:\KLARFExport\PatternedFront\Lot_TEST\' + $bfRelative; length = 4096; lastWriteTimeUtc = (Get-Item -LiteralPath $bfPath).LastWriteTimeUtc.ToString('o'); reparsePoint = $false; containedByApprovedRoot = $true; extension = '.bmp' },
    [ordered]@{ subtreeRelativePath = $dfRelative; canonicalProvenancePath = 'D:\KLARFExport\PatternedFront\Lot_TEST\' + $dfRelative; length = 4096; lastWriteTimeUtc = (Get-Item -LiteralPath $dfPath).LastWriteTimeUtc.ToString('o'); reparsePoint = $false; containedByApprovedRoot = $true; extension = '.bmp' }
)
$inventoryResult = [ordered]@{ schema = 'argos_ols4_entrypoint_result_v1'; state = 'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_OLS4'; inventoryDisposition = 'COMPLETE'; inventory = [ordered]@{ state = 'COMPLETE'; complete = $true; relativeSubtree = 'PatternedFront\Lot_TEST'; skippedPathRowCount = 0; accessErrorCount = 0; truncated = $false; bmpLeaves = $bmpRows } }
Write-Json $inventoryPath $inventoryResult

$targetsSha = Get-Sha256 $targetsPath
$inventorySha = Get-Sha256 $inventoryPath
$successOutput = Join-Path $processorRoot 'success.json'
$successInvocationPath = Join-Path $fixtureRoot 'success-invocation.json'
$successInvocation = [ordered]@{ schema = 'argos_ols5_entrypoint_invocation_v1'; portalRoot = $portalRoot; processorRoot = $processorRoot; targetManifestPath = $targetsPath; expectedTargetManifestSha256 = $targetsSha; inventorySourcePath = $inventoryPath; expectedInventorySourceSha256 = $inventorySha; outputPath = $successOutput; aliasName = 'Q'; failAfterHashCount = 0 }
Write-Json $successInvocationPath $successInvocation
$preflightResult = (& $endpoint -Preflight -InvocationManifest $successInvocationPath) | ConvertFrom-Json
if ([string]$preflightResult.state -ne 'PASS_OLS5_SOURCE_HASH_PREFLIGHT' -or [int]$preflightResult.targetCount -ne 2 -or [bool]$preflightResult.sourceHashingPerformed -or [bool]$preflightResult.mutationsPerformed) { throw 'OLS5 local entrypoint preflight failed.' }
$successResult = (& $endpoint -Rehearsal -InvocationManifest $successInvocationPath) | ConvertFrom-Json
if ([string]$successResult.state -ne 'PASS_OCV00_FRONT_SOURCE_HASHES_OLS5' -or [int]$successResult.targetCount -ne 2 -or [int64]$successResult.sourceBytesRead -ne 8192 -or -not [bool]$successResult.sourceHashingPerformed -or [bool]$successResult.pixelsDecoded -or [bool]$successResult.imageProcessingPerformed -or [bool]$successResult.sourceMutationPerformed -or -not [bool]$successResult.processLocalAlias.removed -or (Get-PSDrive -Name Q -ErrorAction SilentlyContinue)) { throw 'OLS5 local success result failed.' }
$hashByChannel = @{}
foreach ($row in @($successResult.hashes)) { $hashByChannel[[string]$row.channel] = [string]$row.sha256 }
if ($hashByChannel['Brightfield'] -ne (Get-Sha256 $bfPath) -or $hashByChannel['Darkfield'] -ne (Get-Sha256 $dfPath)) { throw 'OLS5 local source hash mismatch.' }

$injectedOutput = Join-Path $processorRoot 'injected.json'
$injectedInvocationPath = Join-Path $fixtureRoot 'injected-invocation.json'
$injectedInvocation = [ordered]@{ schema = 'argos_ols5_entrypoint_invocation_v1'; portalRoot = $portalRoot; processorRoot = $processorRoot; targetManifestPath = $targetsPath; expectedTargetManifestSha256 = $targetsSha; inventorySourcePath = $inventoryPath; expectedInventorySourceSha256 = $inventorySha; outputPath = $injectedOutput; aliasName = 'R'; failAfterHashCount = 1 }
Write-Json $injectedInvocationPath $injectedInvocation
$injectedFailed = $false
try { & $endpoint -Rehearsal -InvocationManifest $injectedInvocationPath | Out-Null } catch { $injectedFailed = $_.Exception.Message -eq 'INJECTED_OLS5_FAILURE_AFTER_HASH' }
if (-not $injectedFailed -or (Test-Path -LiteralPath $injectedOutput) -or (Get-PSDrive -Name R -ErrorAction SilentlyContinue)) { throw 'OLS5 injected-failure cleanup gate failed.' }

$missingTargetsPath = Join-Path $fixtureRoot 'missing-targets.json'
$missingTargets = $targets | ConvertTo-Json -Depth 24 | ConvertFrom-Json
$missingTargets.slots[0].slot = 'Slot02'
Write-Json $missingTargetsPath $missingTargets
$missingInvocationPath = Join-Path $fixtureRoot 'missing-invocation.json'
$missingInvocation = [ordered]@{ schema = 'argos_ols5_entrypoint_invocation_v1'; portalRoot = $portalRoot; processorRoot = $processorRoot; targetManifestPath = $missingTargetsPath; expectedTargetManifestSha256 = Get-Sha256 $missingTargetsPath; inventorySourcePath = $inventoryPath; expectedInventorySourceSha256 = $inventorySha; outputPath = (Join-Path $processorRoot 'missing.json'); aliasName = 'S'; failAfterHashCount = 0 }
Write-Json $missingInvocationPath $missingInvocation
$missingFailed = $false
try { & $endpoint -Preflight -InvocationManifest $missingInvocationPath | Out-Null } catch { $missingFailed = $_.Exception.Message -like 'OLS5 exact inventory source row is missing:*' }
if (-not $missingFailed -or (Test-Path -LiteralPath $missingInvocation.outputPath) -or (Get-PSDrive -Name S -ErrorAction SilentlyContinue)) { throw 'OLS5 missing-source preflight did not fail closed.' }

$gateResult = [ordered]@{
    schema = 'argos_ols5_source_hash_local_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS5_SOURCE_HASH_LOCAL_GATE'
    endpointSha256 = Get-Sha256 $endpoint
    targetManifestSha256 = $targetsSha
    inventorySourceSha256 = $inventorySha
    successTargetCount = 2
    successBytesRead = 8192
    exactSha256MatchCount = 2
    preflightNonMutating = $true
    missingTargetFailedBeforeHash = $true
    injectedFailureAfterHashCount = 1
    injectedFailureOutputAbsent = $true
    aliasesRemoved = @('Q', 'R', 'S')
    pixelsDecoded = $false
    imageProcessingPerformed = $false
    sourceMutationPerformed = $false
    pathState = [string]$pathGate.state
    fixtureRoot = $fixtureRoot
}
Write-Json $gatePath $gateResult
$gateResult | ConvertTo-Json -Depth 8
