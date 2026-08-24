[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Get-Sha256([string]$LiteralPath) { return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$LiteralPath, [object]$Value) {
    if (Test-Path -LiteralPath $LiteralPath) { throw "OLS6 aggregate output already exists: $LiteralPath" }
    [IO.File]::WriteAllText($LiteralPath, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$responseRoot = 'C:\A6R'
$parentPath = Join-Path $project 'work\OPENCV_OLS5\OCV00_SOURCE_HASH_TARGETS.json'
$parentSha = 'EC016561994CD3FAFCB35C5ED2D9C39D6D425515C9AC4998DBFB4024327A7CA8'
$aggregatePath = Join-Path $root 'OLS6_EXACT_TWENTY_SOURCE_HASHES.json'
$gatePath = Join-Path $root 'OLS6_AGGREGATE_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$gateHashes = [ordered]@{
    CHUNK01 = '842361A026317AFC0104BA355E7E2770C24F13951942FFAA1ABB02EF055ED8C7'
    CHUNK02 = 'C588CD940BE1574213280365C38F9A4C5DC3D9527FF51D590F2DAE9C5090A380'
    CHUNK03 = '057ED620A2F751E3FD9D56EB54EB5B51C0B735E7E5AF7F39D74138768A666B96'
    CHUNK04 = 'FEB36CFD6726A8A0F771A58B621F003610D77126746112FD07CB0A2C8D859732'
    CHUNK05 = 'C56E223A32C642CECB9A31807B8B081084ACB6F5E3DA4D0162A5F33D864EBD23'
}
if (-not (Test-Path -LiteralPath $parentPath -PathType Leaf) -or (Get-Sha256 $parentPath) -ne $parentSha) { throw 'OLS6 frozen parent target manifest changed.' }
if ((Test-Path -LiteralPath $aggregatePath) -or (Test-Path -LiteralPath $gatePath)) { throw 'OLS6 aggregate target already exists.' }
$pathState = & $pathTool -CandidatePath @($aggregatePath, $gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathState.state -ne 'PASS_PATH_BUDGET') { throw 'OLS6 aggregate path budget failed.' }

$parent = Get-Content -LiteralPath $parentPath -Raw | ConvertFrom-Json
$expected = @{}
foreach ($slotRow in @($parent.slots)) {
    foreach ($channel in @($parent.channels)) {
        $key = [string]$slotRow.slot + '|' + [string]$channel
        if ($expected.ContainsKey($key)) { throw 'OLS6 frozen parent target set is duplicated.' }
        $relative = ([string]$parent.pathTemplate).Replace('{acquisitionId}', [string]$parent.acquisitionId).Replace('{slot}', [string]$slotRow.slot).Replace('{channel}', [string]$channel).Replace('{lotId}', [string]$parent.lotId).Replace('/', '\')
        $expected[$key] = [pscustomobject]@{ slot = [string]$slotRow.slot; channel = [string]$channel; partition = [string]$slotRow.partition; subtreeRelativePath = $relative }
    }
}
if ($expected.Count -ne 20 -or [int]$parent.targetCount -ne 20) { throw 'OLS6 frozen parent target cardinality changed.' }

$aggregateRows = New-Object Collections.Generic.List[object]
$terminalRows = New-Object Collections.Generic.List[object]
$seen = @{}
$totalBytes = [int64]0
foreach ($entry in $gateHashes.GetEnumerator()) {
    $chunkId = [string]$entry.Key
    $terminalPath = Join-Path $root ('OLS6_' + $chunkId + '_SIGNED_TERMINAL_GATE.json')
    if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf) -or (Get-Sha256 $terminalPath) -ne [string]$entry.Value) { throw "OLS6 terminal gate changed: $chunkId" }
    $terminal = Get-Content -LiteralPath $terminalPath -Raw | ConvertFrom-Json
    if ([string]$terminal.state -ne 'PASS_OLS6_CHUNK_SIGNED_TERMINAL' -or [string]$terminal.chunkId -ne $chunkId -or -not [bool]$terminal.signedResponseVerified -or [string]$terminal.responseState -ne 'COMPLETE' -or [int]$terminal.targetCount -ne 4 -or [bool]$terminal.pixelsDecoded -or [bool]$terminal.imageProcessingPerformed) { throw "OLS6 terminal gate is not an exact success: $chunkId" }
    $responseToken = [string]$terminal.responseToken
    if ($responseToken -notmatch '^R_[A-F0-9]{12}_[0-9]{17}_[a-f0-9]{8}\.ready$') { throw "OLS6 response token is invalid: $chunkId" }
    $stdoutPath = Join-Path (Join-Path $responseRoot $responseToken) 'MAINTENANCE.stdout.txt'
    if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -or (Get-Sha256 $stdoutPath) -ne [string]$terminal.stdoutSha256) { throw "OLS6 signed stdout changed: $chunkId" }
    $result = Get-Content -LiteralPath $stdoutPath -Raw | ConvertFrom-Json
    if ([string]$result.schema -ne 'argos_ols6_source_hash_chunk_result_v1' -or [string]$result.state -ne 'PASS_OCV00_SOURCE_HASH_CHUNK_OLS6' -or [string]$result.chunkId -ne $chunkId -or [string]$result.parentTargetManifestSha256 -ne $parentSha -or [int]$result.targetCount -ne 4 -or [bool]$result.pixelsDecoded -or [bool]$result.imageProcessingPerformed -or [bool]$result.sourceMutationPerformed) { throw "OLS6 signed stdout contract changed: $chunkId" }
    foreach ($row in @($result.hashes)) {
        $key = [string]$row.slot + '|' + [string]$row.channel
        if (-not $expected.ContainsKey($key) -or $seen.ContainsKey($key)) { throw "OLS6 aggregate contains missing/extra/duplicate target: $key" }
        $contract = $expected[$key]
        if ([string]$row.partition -ne [string]$contract.partition -or [string]$row.subtreeRelativePath -ne [string]$contract.subtreeRelativePath -or [int64]$row.bytes -ne [int64]$parent.expectedBytesPerLeaf -or [string]$row.sha256 -notmatch '^[A-F0-9]{64}$' -or -not [bool]$row.sourceStableDuringHash -or [bool]$row.pixelsDecoded -or [bool]$row.imageProcessingPerformed -or [bool]$row.sourceMutationPerformed) { throw "OLS6 aggregate row contract failed: $key" }
        $terminalMatch = @($terminal.hashes | Where-Object { [string]$_.slot -eq [string]$row.slot -and [string]$_.channel -eq [string]$row.channel })
        if ($terminalMatch.Count -ne 1 -or [string]$terminalMatch[0].sha256 -ne [string]$row.sha256) { throw "OLS6 terminal/stdout hash mismatch: $key" }
        $seen[$key] = $true
        $totalBytes += [int64]$row.bytes
        $aggregateRows.Add([pscustomobject]@{
            slot = [string]$row.slot
            channel = [string]$row.channel
            partition = [string]$row.partition
            subtreeRelativePath = [string]$row.subtreeRelativePath
            canonicalProvenancePath = [string]$row.canonicalProvenancePath
            bytes = [int64]$row.bytes
            lastWriteTimeUtc = [string]$row.lastWriteTimeUtc
            sha256 = [string]$row.sha256
            sourceStableDuringHash = [bool]$row.sourceStableDuringHash
            sourceChunkId = $chunkId
        })
    }
    $terminalRows.Add([pscustomobject]@{
        chunkId = $chunkId
        terminalGatePath = 'work/OPENCV_OLS6/' + [IO.Path]::GetFileName($terminalPath)
        terminalGateSha256 = [string]$entry.Value
        responseId = [string]$terminal.responseId
        responseZipSha256 = [string]$terminal.responseZipSha256
        capabilityOutputSha256 = [string]$terminal.capabilityOutputSha256
    })
}
if ($seen.Count -ne 20 -or @($expected.Keys | Where-Object { -not $seen.ContainsKey($_) }).Count -ne 0 -or $totalBytes -ne 9507597480) { throw 'OLS6 exact twenty-target aggregate is incomplete.' }
$orderedRows = @($aggregateRows.ToArray() | Sort-Object slot, @{Expression={if($_.channel -eq 'Brightfield'){0}else{1}}})
$aggregate = [ordered]@{
    schema = 'argos_ols6_exact_source_hash_aggregate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OCV00_EXACT_TWENTY_SOURCE_HASHES'
    revision = 'OCV00_LOT_62619_433_EXACT_SOURCE_HASHES_20260824'
    lotId = [string]$parent.lotId
    acquisitionId = [string]$parent.acquisitionId
    approvedDataRoot = [string]$parent.approvedDataRoot
    relativeSubtree = [string]$parent.relativeSubtree
    parentTargetManifestPath = 'work/OPENCV_OLS5/OCV00_SOURCE_HASH_TARGETS.json'
    parentTargetManifestSha256 = $parentSha
    inventorySourceSha256 = [string]$parent.completeInventoryOutputSha256
    sourceHashAlgorithm = 'SHA256'
    chunkCount = 5
    terminalGates = $terminalRows.ToArray()
    targetCount = 20
    developmentPairCount = 6
    independentValidationPairCount = 4
    sourceBytesRead = $totalBytes
    hashes = $orderedRows
    allSourcesStableDuringHash = $true
    sourceHashingPerformed = $true
    pixelsDecoded = $false
    imageProcessingPerformed = $false
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    inspectionTasksChanged = $false
    processorTaskChanged = $false
    waferActionPerformed = $false
    healthyProcessorTouched = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols6_aggregate_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS6_AGGREGATE_PREFLIGHT'
        terminalGateCount = 5
        targetCount = $aggregate.targetCount
        sourceBytesRead = $aggregate.sourceBytesRead
        pathState = [string]$pathState.state
        mutationsPerformed = $false
        pixelsDecoded = $false
        imageProcessingPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}
Write-JsonCreateNew $aggregatePath $aggregate
$aggregateSha = Get-Sha256 $aggregatePath
$gateResult = [ordered]@{
    schema = 'argos_ols6_aggregate_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS6_EXACT_TWENTY_SOURCE_HASH_AGGREGATE'
    aggregatePath = 'work/OPENCV_OLS6/OLS6_EXACT_TWENTY_SOURCE_HASHES.json'
    aggregateSha256 = $aggregateSha
    parentTargetManifestSha256 = $parentSha
    terminalGateCount = 5
    targetCount = 20
    uniqueTargetCount = 20
    sourceBytesRead = $totalBytes
    missingTargetCount = 0
    extraTargetCount = 0
    duplicateTargetCount = 0
    unstableSourceCount = 0
    pixelsDecoded = $false
    imageProcessingPerformed = $false
    sourceMutationPerformed = $false
    healthyProcessorTouched = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew $gatePath $gateResult
$gateResult | ConvertTo-Json -Depth 8
