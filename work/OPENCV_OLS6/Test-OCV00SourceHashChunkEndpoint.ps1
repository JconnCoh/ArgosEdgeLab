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
$endpoint = Join-Path $PSScriptRoot 'Invoke-OCV00SourceHashChunkEndpoint.ps1'
$fixtureRoot = 'C:\O6G'
$gatePath = Join-Path $PSScriptRoot 'OLS6_SOURCE_HASH_CHUNK_LOCAL_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
if (-not (Test-Path -LiteralPath $endpoint -PathType Leaf) -or -not (Test-Path -LiteralPath $pathTool -PathType Leaf)) { throw 'OLS6 local-gate prerequisite is missing.' }
if ((Test-Path -LiteralPath $fixtureRoot) -or (Test-Path -LiteralPath $gatePath)) { throw 'OLS6 local-gate output already exists.' }
$planned = @(
    $fixtureRoot,
    (Join-Path $fixtureRoot 'portal\config\endpoint_jbod.json'),
    (Join-Path $fixtureRoot 'proc_success\OCV00_OLS6_CHUNK01_SOURCE_HASHES.json'),
    (Join-Path $fixtureRoot 'proc_injected\OCV00_OLS6_CHUNK01_SOURCE_HASHES.json'),
    $gatePath
)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw 'OLS6 local-gate path budget failed.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols6_source_hash_chunk_local_gate_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS6_SOURCE_HASH_CHUNK_LOCAL_GATE_PREFLIGHT'
        endpointSha256 = Get-Sha256 $endpoint
        fixtureRoot = $fixtureRoot
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        imageProcessingPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}

$portalRoot = Join-Path $fixtureRoot 'portal'
$sourceRoot = Join-Path $fixtureRoot 'source'
$lotRoot = Join-Path $sourceRoot 'PatternedFront\Lot_TEST'
$processorRoots = @{
    success = Join-Path $fixtureRoot 'proc_success'
    injected = Join-Path $fixtureRoot 'proc_injected'
    missing = Join-Path $fixtureRoot 'proc_missing'
}
$channels = @('Brightfield', 'Darkfield')
$slots = @('Slot01', 'Slot02')
$rows = New-Object Collections.Generic.List[object]
$expectedHashes = @{}
$seed = 0
foreach ($slot in $slots) {
    foreach ($channel in $channels) {
        $relative = 'ACQ_TEST\' + $slot + '\' + $channel + 'FrontsideWafer\resizedImage\TEST_' + $slot + '_' + $channel + 'FrontsideWafer_PM2_resizedImage.bmp'
        $path = Join-Path $lotRoot $relative
        [void](New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($path)) -Force)
        $bytes = New-Object byte[] 4096
        for ($index = 0; $index -lt $bytes.Length; $index++) { $bytes[$index] = [byte](($index + $seed) % 251) }
        [IO.File]::WriteAllBytes($path, $bytes)
        $expectedHashes["$slot|$channel"] = Get-Sha256 $path
        $rows.Add([ordered]@{
            subtreeRelativePath = $relative
            canonicalProvenancePath = 'D:\KLARFExport\PatternedFront\Lot_TEST\' + $relative
            length = 4096
            lastWriteTimeUtc = (Get-Item -LiteralPath $path).LastWriteTimeUtc.ToString('o')
            reparsePoint = $false
            containedByApprovedRoot = $true
            extension = '.bmp'
        })
        $seed += 17
    }
}

[void](New-Item -ItemType Directory -Path (Join-Path $portalRoot 'config') -Force)
foreach ($processorRoot in $processorRoots.Values) { [void](New-Item -ItemType Directory -Path $processorRoot -Force) }
$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
Write-Json $configPath ([ordered]@{ schema = 'argos_project_portal_endpoint_config_v1'; role = 'JBOD'; approvedDataRoots = @([ordered]@{ name = 'JBOD_KLARF_EXPORT'; path = $sourceRoot }); reviewOnly = $true; productionRoutingEnabled = $false })

$chunkPath = Join-Path $fixtureRoot 'chunk.json'
$chunk = [ordered]@{
    schema = 'argos_ocv00_source_hash_chunk_v1'
    revision = 'OLS6_LOCAL'
    state = 'FROZEN'
    disposition = 'LOCKED_INPUT'
    chunkId = 'CHUNK01'
    chunkOrdinal = 1
    chunkCount = 5
    parentTargetManifestPath = 'work/OPENCV_OLS5/OCV00_SOURCE_HASH_TARGETS.json'
    parentTargetManifestSha256 = 'EC016561994CD3FAFCB35C5ED2D9C39D6D425515C9AC4998DBFB4024327A7CA8'
    approvedDataRoot = 'JBOD_KLARF_EXPORT'
    relativeSubtree = 'PatternedFront/Lot_TEST'
    lotId = 'TEST'
    acquisitionId = 'ACQ_TEST'
    pathTemplate = '{acquisitionId}/{slot}/{channel}FrontsideWafer/resizedImage/{lotId}_{slot}_{channel}FrontsideWafer_PM2_resizedImage.bmp'
    channels = $channels
    slots = @(
        [ordered]@{ slot = 'Slot01'; partition = 'DEVELOPMENT' },
        [ordered]@{ slot = 'Slot02'; partition = 'DEVELOPMENT' }
    )
    expectedBytesPerLeaf = 4096
    targetCount = 4
    outputFileName = 'OCV00_OLS6_CHUNK01_SOURCE_HASHES.json'
    completeInventoryOutputSha256 = 'LOCAL'
    sourceHashAlgorithm = 'SHA256'
    decodePixels = $false
    imageProcessingAllowed = $false
    sourceMutationAllowed = $false
    taskOrProcessActionAllowed = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
}
Write-Json $chunkPath $chunk
$chunkSha = Get-Sha256 $chunkPath

$inventoryResult = [ordered]@{
    schema = 'argos_ols4_entrypoint_result_v1'
    state = 'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_OLS4'
    inventoryDisposition = 'COMPLETE'
    inventory = [ordered]@{
        state = 'COMPLETE'
        complete = $true
        relativeSubtree = 'PatternedFront\Lot_TEST'
        skippedPathRowCount = 0
        accessErrorCount = 0
        truncated = $false
        bmpLeaves = $rows
    }
}
$inventoryPaths = @{}
foreach ($name in $processorRoots.Keys) {
    $inventoryPaths[$name] = Join-Path $processorRoots[$name] 'inventory.json'
    Write-Json $inventoryPaths[$name] $inventoryResult
}

$successInvocationPath = Join-Path $fixtureRoot 'success-invocation.json'
$successInvocation = [ordered]@{
    schema = 'argos_ols6_entrypoint_invocation_v1'
    portalRoot = $portalRoot
    processorRoot = $processorRoots.success
    chunkManifestPath = $chunkPath
    expectedChunkManifestSha256 = $chunkSha
    inventorySourcePath = $inventoryPaths.success
    expectedInventorySourceSha256 = Get-Sha256 $inventoryPaths.success
    aliasName = 'Q'
    failAfterHashCount = 0
}
Write-Json $successInvocationPath $successInvocation
$preflightResult = (& $endpoint -Preflight -InvocationManifest $successInvocationPath) | ConvertFrom-Json
if ([string]$preflightResult.state -ne 'PASS_OLS6_SOURCE_HASH_CHUNK_PREFLIGHT' -or [string]$preflightResult.chunkId -ne 'CHUNK01' -or [int]$preflightResult.targetCount -ne 4 -or [bool]$preflightResult.sourceHashingPerformed -or [bool]$preflightResult.mutationsPerformed) { throw 'OLS6 local entrypoint preflight failed.' }
$successResult = (& $endpoint -Rehearsal -InvocationManifest $successInvocationPath) | ConvertFrom-Json
if ([string]$successResult.state -ne 'PASS_OCV00_SOURCE_HASH_CHUNK_OLS6' -or [string]$successResult.chunkId -ne 'CHUNK01' -or [int]$successResult.targetCount -ne 4 -or [int64]$successResult.sourceBytesRead -ne 16384 -or -not [bool]$successResult.sourceHashingPerformed -or [bool]$successResult.pixelsDecoded -or [bool]$successResult.imageProcessingPerformed -or [bool]$successResult.sourceMutationPerformed -or -not [bool]$successResult.processLocalAlias.removed -or (Get-PSDrive -Name Q -ErrorAction SilentlyContinue)) { throw 'OLS6 local success result failed.' }
$matched = 0
foreach ($row in @($successResult.hashes)) {
    if ([string]$row.sha256 -ne [string]$expectedHashes["$($row.slot)|$($row.channel)"]) { throw 'OLS6 local source hash mismatch.' }
    $matched++
}
if ($matched -ne 4) { throw 'OLS6 local exact hash count changed.' }

$injectedInvocationPath = Join-Path $fixtureRoot 'injected-invocation.json'
$injectedInvocation = [ordered]@{
    schema = 'argos_ols6_entrypoint_invocation_v1'
    portalRoot = $portalRoot
    processorRoot = $processorRoots.injected
    chunkManifestPath = $chunkPath
    expectedChunkManifestSha256 = $chunkSha
    inventorySourcePath = $inventoryPaths.injected
    expectedInventorySourceSha256 = Get-Sha256 $inventoryPaths.injected
    aliasName = 'R'
    failAfterHashCount = 1
}
Write-Json $injectedInvocationPath $injectedInvocation
$injectedFailed = $false
try { & $endpoint -Rehearsal -InvocationManifest $injectedInvocationPath | Out-Null } catch { $injectedFailed = $_.Exception.Message -eq 'INJECTED_OLS6_FAILURE_AFTER_HASH' }
$injectedOutput = Join-Path $processorRoots.injected 'OCV00_OLS6_CHUNK01_SOURCE_HASHES.json'
if (-not $injectedFailed -or (Test-Path -LiteralPath $injectedOutput) -or (Get-PSDrive -Name R -ErrorAction SilentlyContinue)) { throw 'OLS6 injected-failure cleanup gate failed.' }

$missingChunkPath = Join-Path $fixtureRoot 'missing-chunk.json'
$missingChunk = $chunk | ConvertTo-Json -Depth 24 | ConvertFrom-Json
$missingChunk.slots[1].slot = 'Slot03'
Write-Json $missingChunkPath $missingChunk
$missingInvocationPath = Join-Path $fixtureRoot 'missing-invocation.json'
$missingInvocation = [ordered]@{
    schema = 'argos_ols6_entrypoint_invocation_v1'
    portalRoot = $portalRoot
    processorRoot = $processorRoots.missing
    chunkManifestPath = $missingChunkPath
    expectedChunkManifestSha256 = Get-Sha256 $missingChunkPath
    inventorySourcePath = $inventoryPaths.missing
    expectedInventorySourceSha256 = Get-Sha256 $inventoryPaths.missing
    aliasName = 'S'
    failAfterHashCount = 0
}
Write-Json $missingInvocationPath $missingInvocation
$missingFailed = $false
try { & $endpoint -Preflight -InvocationManifest $missingInvocationPath | Out-Null } catch { $missingFailed = $_.Exception.Message -like 'OLS6 exact inventory source row is missing:*' }
$missingOutput = Join-Path $processorRoots.missing 'OCV00_OLS6_CHUNK01_SOURCE_HASHES.json'
if (-not $missingFailed -or (Test-Path -LiteralPath $missingOutput) -or (Get-PSDrive -Name S -ErrorAction SilentlyContinue)) { throw 'OLS6 missing-source preflight did not fail closed.' }

$gateResult = [ordered]@{
    schema = 'argos_ols6_source_hash_chunk_local_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS6_SOURCE_HASH_CHUNK_LOCAL_GATE'
    endpointSha256 = Get-Sha256 $endpoint
    testChunkManifestSha256 = $chunkSha
    successTargetCount = 4
    successBytesRead = 16384
    exactSha256MatchCount = 4
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
