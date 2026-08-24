[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Preflight -and $Rehearsal) { throw 'OLS6 cannot combine Preflight and Rehearsal.' }

function Get-PhysicalSha256([string]$LiteralPath) {
    $stream = New-Object IO.FileStream($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, 8388608, [IO.FileOptions]::SequentialScan)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-ProviderSha256([string]$LiteralPath) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576 | ForEach-Object {
            [byte[]]$block = $_
            if ($block.Length -gt 0) { [void]$sha.TransformBlock($block, 0, $block.Length, $block, 0) }
        }
        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
        return ([BitConverter]::ToString($sha.Hash)).Replace('-', '')
    } finally { $sha.Dispose() }
}

function Get-RequiredProperty([object]$InputObject, [string]$Name) {
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "OLS6 required property is absent: $Name" }
    return $property.Value
}

function Get-SafeChildPath([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|\\)\.\.?($|\\)' -or $Relative.IndexOfAny([char[]]'*?[]') -ge 0) { throw 'OLS6 relative path is unsafe.' }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative))
    if (-not $candidate.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OLS6 relative path escaped its root.' }
    return $candidate
}

function Get-LexicalBudget([string]$Path, [int]$Reserve = 32) {
    $text = $Path.Replace('/', '\')
    $tail = if ($text -match '^[A-Za-z]:\\') { $text.Substring(3) } elseif ($text -match '^\\\\[^\\]+\\[^\\]+(?:\\|$)') { $text.Substring(([regex]::Match($text, '^\\\\[^\\]+\\[^\\]+(?:\\|$)')).Length) } else { $text.TrimStart('\') }
    $components = @($tail.Split('\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $longest = if ($components.Count) { [int](($components | Measure-Object Length -Maximum).Maximum) } else { 0 }
    return [pscustomobject]@{ effectiveLength = [int]$text.Length + $Reserve; longestComponentLength = $longest }
}

function Write-Utf8JsonCreateNew([string]$LiteralPath, [object]$Value) {
    if (Test-Path -LiteralPath $LiteralPath) { throw "OLS6 refuses existing output: $LiteralPath" }
    [IO.File]::WriteAllText($LiteralPath, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$chunkManifestPath = Join-Path $PSScriptRoot 'OCV00_SOURCE_HASH_CHUNK.json'
$inventorySourcePath = Join-Path $processorRoot 'OCV00_OLS4_LOT_INVENTORY.json'
$expectedInventorySourceSha256 = 'EB97918066DA4AC148C49BDB5D241443614F173E341787CFB253708316710936'
$expectedParentTargetManifestSha256 = 'EC016561994CD3FAFCB35C5ED2D9C39D6D425515C9AC4998DBFB4024327A7CA8'
$liveChunkHashes = @{
    'CHUNK01' = '2E16F86A61A54EDE87B43EECE96AFA6BF8F2C97305E8889D4A1416CAE74A85FE'
    'CHUNK02' = 'F91E3460FD93C194D9CBA89AB3FB3E1930CC495B6A3A48C1C0D5D9C94EFEDD4B'
    'CHUNK03' = '82CFD74AC32597F905F22B49B2FD5F9673DFDB1CA35D8416EBA0EDC9D7D9691D'
    'CHUNK04' = '9AFC8F72CA61D83B207E8E7288B904ACCA37DA4A2038636960833478886B33F3'
    'CHUNK05' = '02F470F23FC7189CA1A8CD921507B5E09D2748F90E829F61E4AEA0CCD5B77F55'
}
$aliasName = 'F'
$failAfterHashCount = 0
$expectedChunkManifestSha256 = ''

if ($Preflight -or $Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'OLS6 Preflight/Rehearsal requires InvocationManifest.' }
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    if (-not (Test-Path -LiteralPath $invocationPath -PathType Leaf) -or (Get-Item -LiteralPath $invocationPath).Length -gt 65536) { throw 'OLS6 invocation manifest is missing or too large.' }
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    if ([string](Get-RequiredProperty $invocation 'schema') -ne 'argos_ols6_entrypoint_invocation_v1') { throw 'OLS6 invocation schema mismatch.' }
    $portalRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'portalRoot')).TrimEnd('\')
    $processorRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'processorRoot')).TrimEnd('\')
    $chunkManifestPath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'chunkManifestPath'))
    $expectedChunkManifestSha256 = ([string](Get-RequiredProperty $invocation 'expectedChunkManifestSha256')).ToUpperInvariant()
    $inventorySourcePath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'inventorySourcePath'))
    $expectedInventorySourceSha256 = ([string](Get-RequiredProperty $invocation 'expectedInventorySourceSha256')).ToUpperInvariant()
    $aliasName = [string](Get-RequiredProperty $invocation 'aliasName')
    if ($invocation.PSObject.Properties.Name -contains 'failAfterHashCount') { $failAfterHashCount = [int]$invocation.failAfterHashCount }
}

if ($aliasName -notmatch '^[A-Z]$') { throw 'OLS6 alias name is invalid.' }
if (-not $Rehearsal -and -not $Preflight -and $aliasName -ne 'F') { throw 'OLS6 live alias changed.' }
if (-not (Test-Path -LiteralPath $chunkManifestPath -PathType Leaf)) { throw 'OLS6 chunk manifest is missing.' }
$actualChunkManifestSha256 = Get-PhysicalSha256 $chunkManifestPath
$chunk = Get-Content -LiteralPath $chunkManifestPath -Raw | ConvertFrom-Json
$chunkId = [string](Get-RequiredProperty $chunk 'chunkId')
if ($Preflight -or $Rehearsal) {
    if ($actualChunkManifestSha256 -ne $expectedChunkManifestSha256) { throw 'OLS6 rehearsal chunk manifest changed.' }
} else {
    if (-not $liveChunkHashes.ContainsKey($chunkId) -or $actualChunkManifestSha256 -ne [string]$liveChunkHashes[$chunkId]) { throw 'OLS6 live chunk manifest is not one of the five frozen chunks.' }
}
if (-not (Test-Path -LiteralPath $inventorySourcePath -PathType Leaf) -or (Get-PhysicalSha256 $inventorySourcePath) -ne $expectedInventorySourceSha256) { throw 'OLS6 pinned inventory changed.' }

$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'OLS6 endpoint config is missing.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string](Get-RequiredProperty $config 'schema') -ne 'argos_project_portal_endpoint_config_v1' -or [string](Get-RequiredProperty $config 'role') -ne 'JBOD' -or -not [bool](Get-RequiredProperty $config 'reviewOnly') -or [bool](Get-RequiredProperty $config 'productionRoutingEnabled')) { throw 'OLS6 endpoint config authority failed closed.' }

if ([string](Get-RequiredProperty $chunk 'schema') -ne 'argos_ocv00_source_hash_chunk_v1' -or [string](Get-RequiredProperty $chunk 'state') -ne 'FROZEN' -or [int](Get-RequiredProperty $chunk 'chunkCount') -ne 5 -or [int](Get-RequiredProperty $chunk 'chunkOrdinal') -lt 1 -or [int](Get-RequiredProperty $chunk 'chunkOrdinal') -gt 5 -or [string](Get-RequiredProperty $chunk 'parentTargetManifestSha256') -ne $expectedParentTargetManifestSha256 -or [string](Get-RequiredProperty $chunk 'sourceHashAlgorithm') -ne 'SHA256' -or [bool](Get-RequiredProperty $chunk 'decodePixels') -or [bool](Get-RequiredProperty $chunk 'imageProcessingAllowed') -or [bool](Get-RequiredProperty $chunk 'sourceMutationAllowed') -or [bool](Get-RequiredProperty $chunk 'taskOrProcessActionAllowed') -or -not [bool](Get-RequiredProperty $chunk 'reviewOnly') -or [bool](Get-RequiredProperty $chunk 'productionEligible')) { throw 'OLS6 chunk authority changed.' }
$expectedChunkId = 'CHUNK{0:D2}' -f [int](Get-RequiredProperty $chunk 'chunkOrdinal')
$expectedOutputFileName = 'OCV00_OLS6_{0}_SOURCE_HASHES.json' -f $expectedChunkId
if ($chunkId -ne $expectedChunkId -or [string](Get-RequiredProperty $chunk 'outputFileName') -ne $expectedOutputFileName) { throw 'OLS6 chunk identity/output mismatch.' }

$approvedDataRootName = [string](Get-RequiredProperty $chunk 'approvedDataRoot')
$mapping = @($config.approvedDataRoots | Where-Object { [string]$_.name -eq $approvedDataRootName })
if ($mapping.Count -ne 1) { throw 'OLS6 approved data-root mapping cardinality changed.' }
$approvedRoot = [IO.Path]::GetFullPath([string]$mapping[0].path).TrimEnd('\')
$relativeSubtree = ([string](Get-RequiredProperty $chunk 'relativeSubtree')).Replace('/', '\')
$requestedSubtreeRoot = Get-SafeChildPath $approvedRoot $relativeSubtree

$inventoryResult = Get-Content -LiteralPath $inventorySourcePath -Raw | ConvertFrom-Json
$inventory = Get-RequiredProperty $inventoryResult 'inventory'
if ([string](Get-RequiredProperty $inventoryResult 'schema') -ne 'argos_ols4_entrypoint_result_v1' -or [string](Get-RequiredProperty $inventoryResult 'state') -ne 'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_OLS4' -or [string](Get-RequiredProperty $inventoryResult 'inventoryDisposition') -ne 'COMPLETE' -or [string](Get-RequiredProperty $inventory 'state') -ne 'COMPLETE' -or -not [bool](Get-RequiredProperty $inventory 'complete') -or [string](Get-RequiredProperty $inventory 'relativeSubtree') -ne $relativeSubtree -or [int](Get-RequiredProperty $inventory 'skippedPathRowCount') -ne 0 -or [int](Get-RequiredProperty $inventory 'accessErrorCount') -ne 0 -or [bool](Get-RequiredProperty $inventory 'truncated')) { throw 'OLS6 complete inventory premise changed.' }

$rowBySubtreePath = @{}
foreach ($row in @(Get-RequiredProperty $inventory 'bmpLeaves')) {
    $key = ([string](Get-RequiredProperty $row 'subtreeRelativePath')).Replace('/', '\')
    if ($rowBySubtreePath.ContainsKey($key)) { throw "OLS6 duplicate inventory source row: $key" }
    $rowBySubtreePath[$key] = $row
}

$slotRows = @(Get-RequiredProperty $chunk 'slots')
$channels = @(Get-RequiredProperty $chunk 'channels' | ForEach-Object { [string]$_ })
$expectedTargetCount = [int](Get-RequiredProperty $chunk 'targetCount')
if ($slotRows.Count -ne 2 -or $channels.Count -ne 2 -or $channels[0] -ne 'Brightfield' -or $channels[1] -ne 'Darkfield' -or $expectedTargetCount -ne 4) { throw 'OLS6 chunk cardinality changed.' }
$pathTemplate = [string](Get-RequiredProperty $chunk 'pathTemplate')
$lotId = [string](Get-RequiredProperty $chunk 'lotId')
$acquisitionId = [string](Get-RequiredProperty $chunk 'acquisitionId')
$expectedBytesPerLeaf = [int64](Get-RequiredProperty $chunk 'expectedBytesPerLeaf')
$resolvedTargets = New-Object Collections.Generic.List[object]
foreach ($slotRow in $slotRows) {
    $slot = [string](Get-RequiredProperty $slotRow 'slot')
    $partition = [string](Get-RequiredProperty $slotRow 'partition')
    if ($slot -notmatch '^Slot[0-9]{2}$' -or $partition -notin @('DEVELOPMENT', 'INDEPENDENT_VALIDATION')) { throw 'OLS6 slot partition is invalid.' }
    foreach ($channel in $channels) {
        $relative = $pathTemplate.Replace('{acquisitionId}', $acquisitionId).Replace('{slot}', $slot).Replace('{channel}', $channel).Replace('{lotId}', $lotId).Replace('/', '\')
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|\\)\.\.?($|\\)' -or $relative.IndexOfAny([char[]]'*?[]') -ge 0) { throw 'OLS6 expanded source path is unsafe.' }
        if (-not $rowBySubtreePath.ContainsKey($relative)) { throw "OLS6 exact inventory source row is missing: $relative" }
        $row = $rowBySubtreePath[$relative]
        $aliasPath = $aliasName + ':\' + $relative
        $budget = Get-LexicalBudget $aliasPath
        if ($budget.effectiveLength -ge 200 -or $budget.longestComponentLength -gt 255 -or [int64](Get-RequiredProperty $row 'length') -ne $expectedBytesPerLeaf -or [bool](Get-RequiredProperty $row 'reparsePoint') -or -not [bool](Get-RequiredProperty $row 'containedByApprovedRoot') -or [string](Get-RequiredProperty $row 'extension') -ne '.bmp') { throw "OLS6 frozen source-row contract failed: $relative" }
        $resolvedTargets.Add([pscustomobject]@{ slot = $slot; channel = $channel; partition = $partition; subtreeRelativePath = $relative; aliasReadPath = $aliasPath; canonicalProvenancePath = [string](Get-RequiredProperty $row 'canonicalProvenancePath'); expectedBytes = [int64](Get-RequiredProperty $row 'length'); aliasEffectiveLength = [int]$budget.effectiveLength; aliasLongestComponentLength = [int]$budget.longestComponentLength })
    }
}
if ($resolvedTargets.Count -ne 4) { throw 'OLS6 resolved target count changed.' }

$outputPath = Join-Path $processorRoot $expectedOutputFileName
$outputBudget = Get-LexicalBudget $outputPath
if ($outputBudget.effectiveLength -ge 200 -or $outputBudget.longestComponentLength -gt 80 -or (Test-Path -LiteralPath $outputPath)) { throw 'OLS6 output path is unsafe or already exists.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols6_entrypoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS6_SOURCE_HASH_CHUNK_PREFLIGHT'
        chunkId = $chunkId
        targetCount = $resolvedTargets.Count
        chunkManifestSha256 = $actualChunkManifestSha256
        parentTargetManifestSha256 = $expectedParentTargetManifestSha256
        inventorySourceSha256 = $expectedInventorySourceSha256
        outputPath = $outputPath
        sourceBytesRead = 0
        sourceHashingPerformed = $false
        pixelsDecoded = $false
        imageProcessingPerformed = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

if (Get-PSDrive -Name $aliasName -ErrorAction SilentlyContinue) { throw "OLS6 process-local alias is already in use: $aliasName" }
$aliasCreated = $false
$hashRows = New-Object Collections.Generic.List[object]
$bytesRead = [int64]0
try {
    New-PSDrive -Name $aliasName -PSProvider FileSystem -Root $requestedSubtreeRoot -Scope Script | Out-Null
    $aliasCreated = $true
    foreach ($target in $resolvedTargets) {
        $itemBefore = Get-Item -LiteralPath $target.aliasReadPath -Force
        if ($itemBefore.PSIsContainer -or ($itemBefore.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or [int64]$itemBefore.Length -ne [int64]$target.expectedBytes) { throw "OLS6 source metadata changed before hashing: $($target.subtreeRelativePath)" }
        $lastWriteBefore = $itemBefore.LastWriteTimeUtc.ToString('o')
        $sha256 = Get-ProviderSha256 $target.aliasReadPath
        $itemAfter = Get-Item -LiteralPath $target.aliasReadPath -Force
        $lastWriteAfter = $itemAfter.LastWriteTimeUtc.ToString('o')
        if ([int64]$itemAfter.Length -ne [int64]$itemBefore.Length -or $lastWriteAfter -ne $lastWriteBefore) { throw "OLS6 source changed while hashing: $($target.subtreeRelativePath)" }
        $bytesRead += [int64]$itemAfter.Length
        $hashRows.Add([pscustomobject]@{ slot = $target.slot; channel = $target.channel; partition = $target.partition; subtreeRelativePath = $target.subtreeRelativePath; canonicalProvenancePath = $target.canonicalProvenancePath; aliasReadPath = $target.aliasReadPath; bytes = [int64]$itemAfter.Length; lastWriteTimeUtc = $lastWriteAfter; sha256 = $sha256; sourceStableDuringHash = $true; pixelsDecoded = $false; imageProcessingPerformed = $false; sourceMutationPerformed = $false })
        if ($Rehearsal -and $failAfterHashCount -gt 0 -and $hashRows.Count -ge $failAfterHashCount) { throw 'INJECTED_OLS6_FAILURE_AFTER_HASH' }
    }
} finally {
    if ($aliasCreated) { Remove-PSDrive -Name $aliasName -Force -ErrorAction SilentlyContinue }
}
if (Get-PSDrive -Name $aliasName -ErrorAction SilentlyContinue) { throw 'OLS6 process-local alias cleanup failed.' }

$result = [ordered]@{
    schema = 'argos_ols6_source_hash_chunk_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OCV00_SOURCE_HASH_CHUNK_OLS6'
    rehearsal = [bool]$Rehearsal
    chunkId = $chunkId
    chunkOrdinal = [int]$chunk.chunkOrdinal
    chunkCount = 5
    approvedDataRoot = $approvedDataRootName
    approvedRoot = $approvedRoot
    relativeSubtree = $relativeSubtree
    chunkManifestSha256 = $actualChunkManifestSha256
    parentTargetManifestSha256 = $expectedParentTargetManifestSha256
    inventorySourceSha256 = $expectedInventorySourceSha256
    sourceHashAlgorithm = 'SHA256'
    targetCount = $hashRows.Count
    sourceBytesRead = $bytesRead
    hashes = $hashRows
    processLocalAlias = [ordered]@{ name = $aliasName; anchor = 'EXACT_REQUESTED_SUBTREE_ROOT'; persistent = $false; removed = $true }
    sourceHashingPerformed = $true
    pixelsDecoded = $false
    imageProcessingPerformed = $false
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    inspectionTasksChanged = $false
    processorTaskChanged = $false
    processActions = @()
    waferActionPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-Utf8JsonCreateNew $outputPath $result
$readback = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
if ([string](Get-RequiredProperty $readback 'state') -ne 'PASS_OCV00_SOURCE_HASH_CHUNK_OLS6' -or [string](Get-RequiredProperty $readback 'chunkId') -ne $chunkId -or [int](Get-RequiredProperty $readback 'targetCount') -ne 4 -or -not [bool](Get-RequiredProperty $readback 'sourceHashingPerformed') -or [bool](Get-RequiredProperty $readback 'pixelsDecoded') -or [bool](Get-RequiredProperty $readback 'imageProcessingPerformed')) { throw 'OLS6 output readback failed.' }
$result['capabilityOutputPath'] = $outputPath
$result['capabilityOutputBytes'] = (Get-Item -LiteralPath $outputPath).Length
$result['capabilityOutputSha256'] = Get-PhysicalSha256 $outputPath
$result | ConvertTo-Json -Depth 32
