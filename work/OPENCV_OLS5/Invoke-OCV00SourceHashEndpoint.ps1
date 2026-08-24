[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Preflight -and $Rehearsal) { throw 'OLS5 cannot combine Preflight and Rehearsal.' }

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
    if ($null -eq $property) { throw "OLS5 required property is absent: $Name" }
    return $property.Value
}

function Get-SafeChildPath([string]$Root, [string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '(^|\\)\.\.?($|\\)' -or $Relative.IndexOfAny([char[]]'*?[]') -ge 0) { throw 'OLS5 relative path is unsafe.' }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative))
    if (-not $candidate.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'OLS5 relative path escaped its root.' }
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
    if (Test-Path -LiteralPath $LiteralPath) { throw "OLS5 refuses existing output: $LiteralPath" }
    [IO.File]::WriteAllText($LiteralPath, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$targetManifestPath = Join-Path $PSScriptRoot 'OCV00_SOURCE_HASH_TARGETS.json'
$expectedTargetManifestSha256 = 'EC016561994CD3FAFCB35C5ED2D9C39D6D425515C9AC4998DBFB4024327A7CA8'
$inventorySourcePath = Join-Path $processorRoot 'OCV00_OLS4_LOT_INVENTORY.json'
$expectedInventorySourceSha256 = 'EB97918066DA4AC148C49BDB5D241443614F173E341787CFB253708316710936'
$outputPath = Join-Path $processorRoot 'OCV00_OLS5_FRONT_SOURCE_HASHES.json'
$aliasName = 'F'
$failAfterHashCount = 0

if ($Preflight -or $Rehearsal) {
    if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { throw 'OLS5 Preflight/Rehearsal requires InvocationManifest.' }
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    if (-not (Test-Path -LiteralPath $invocationPath -PathType Leaf) -or (Get-Item -LiteralPath $invocationPath).Length -gt 65536) { throw 'OLS5 invocation manifest is missing or too large.' }
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    if ([string](Get-RequiredProperty $invocation 'schema') -ne 'argos_ols5_entrypoint_invocation_v1') { throw 'OLS5 invocation schema mismatch.' }
    $portalRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'portalRoot')).TrimEnd('\')
    $processorRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'processorRoot')).TrimEnd('\')
    $targetManifestPath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'targetManifestPath'))
    $expectedTargetManifestSha256 = ([string](Get-RequiredProperty $invocation 'expectedTargetManifestSha256')).ToUpperInvariant()
    $inventorySourcePath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'inventorySourcePath'))
    $expectedInventorySourceSha256 = ([string](Get-RequiredProperty $invocation 'expectedInventorySourceSha256')).ToUpperInvariant()
    $outputPath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'outputPath'))
    $aliasName = [string](Get-RequiredProperty $invocation 'aliasName')
    if ($invocation.PSObject.Properties.Name -contains 'failAfterHashCount') { $failAfterHashCount = [int]$invocation.failAfterHashCount }
}

if ($aliasName -notmatch '^[A-Z]$') { throw 'OLS5 alias name is invalid.' }
if (-not $Rehearsal -and -not $Preflight -and $aliasName -ne 'F') { throw 'OLS5 live alias changed.' }
foreach ($pin in @(
    [pscustomobject]@{ path = $targetManifestPath; sha = $expectedTargetManifestSha256 },
    [pscustomobject]@{ path = $inventorySourcePath; sha = $expectedInventorySourceSha256 }
)) {
    if (-not (Test-Path -LiteralPath $pin.path -PathType Leaf) -or (Get-PhysicalSha256 $pin.path) -ne $pin.sha) { throw "OLS5 pinned input changed: $($pin.path)" }
}

$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw 'OLS5 endpoint config is missing.' }
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
if ([string](Get-RequiredProperty $config 'schema') -ne 'argos_project_portal_endpoint_config_v1' -or [string](Get-RequiredProperty $config 'role') -ne 'JBOD' -or -not [bool](Get-RequiredProperty $config 'reviewOnly') -or [bool](Get-RequiredProperty $config 'productionRoutingEnabled')) { throw 'OLS5 endpoint config authority failed closed.' }

$targets = Get-Content -LiteralPath $targetManifestPath -Raw | ConvertFrom-Json
if ([string](Get-RequiredProperty $targets 'schema') -ne 'argos_ocv00_source_hash_targets_v1' -or [string](Get-RequiredProperty $targets 'state') -ne 'FROZEN' -or [string](Get-RequiredProperty $targets 'sourceHashAlgorithm') -ne 'SHA256' -or [bool](Get-RequiredProperty $targets 'decodePixels') -or [bool](Get-RequiredProperty $targets 'imageProcessingAllowed') -or [bool](Get-RequiredProperty $targets 'sourceMutationAllowed') -or [bool](Get-RequiredProperty $targets 'taskOrProcessActionAllowed') -or -not [bool](Get-RequiredProperty $targets 'reviewOnly') -or [bool](Get-RequiredProperty $targets 'productionEligible')) { throw 'OLS5 target manifest authority changed.' }
$approvedDataRootName = [string](Get-RequiredProperty $targets 'approvedDataRoot')
$mapping = @($config.approvedDataRoots | Where-Object { [string]$_.name -eq $approvedDataRootName })
if ($mapping.Count -ne 1) { throw 'OLS5 approved data-root mapping cardinality changed.' }
$approvedRoot = [IO.Path]::GetFullPath([string]$mapping[0].path).TrimEnd('\')
$relativeSubtree = ([string](Get-RequiredProperty $targets 'relativeSubtree')).Replace('/', '\')
$requestedSubtreeRoot = Get-SafeChildPath $approvedRoot $relativeSubtree

$inventoryResult = Get-Content -LiteralPath $inventorySourcePath -Raw | ConvertFrom-Json
$inventory = Get-RequiredProperty $inventoryResult 'inventory'
if ([string](Get-RequiredProperty $inventoryResult 'schema') -ne 'argos_ols4_entrypoint_result_v1' -or [string](Get-RequiredProperty $inventoryResult 'state') -ne 'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_OLS4' -or [string](Get-RequiredProperty $inventoryResult 'inventoryDisposition') -ne 'COMPLETE' -or [string](Get-RequiredProperty $inventory 'state') -ne 'COMPLETE' -or -not [bool](Get-RequiredProperty $inventory 'complete') -or [string](Get-RequiredProperty $inventory 'relativeSubtree') -ne $relativeSubtree -or [int](Get-RequiredProperty $inventory 'skippedPathRowCount') -ne 0 -or [int](Get-RequiredProperty $inventory 'accessErrorCount') -ne 0 -or [bool](Get-RequiredProperty $inventory 'truncated')) { throw 'OLS5 complete inventory premise changed.' }

$rowBySubtreePath = @{}
foreach ($row in @(Get-RequiredProperty $inventory 'bmpLeaves')) {
    $key = ([string](Get-RequiredProperty $row 'subtreeRelativePath')).Replace('/', '\')
    if ($rowBySubtreePath.ContainsKey($key)) { throw "OLS5 duplicate inventory source row: $key" }
    $rowBySubtreePath[$key] = $row
}

$slotRows = @(Get-RequiredProperty $targets 'slots')
$channels = @(Get-RequiredProperty $targets 'channels' | ForEach-Object { [string]$_ })
$expectedTargetCount = [int](Get-RequiredProperty $targets 'targetCount')
if ($slotRows.Count -lt 1 -or $channels.Count -ne 2 -or $channels[0] -ne 'Brightfield' -or $channels[1] -ne 'Darkfield' -or ($slotRows.Count * $channels.Count) -ne $expectedTargetCount -or $expectedTargetCount -gt 64) { throw 'OLS5 target cardinality changed.' }
$pathTemplate = [string](Get-RequiredProperty $targets 'pathTemplate')
$lotId = [string](Get-RequiredProperty $targets 'lotId')
$acquisitionId = [string](Get-RequiredProperty $targets 'acquisitionId')
$expectedBytesPerLeaf = [int64](Get-RequiredProperty $targets 'expectedBytesPerLeaf')
$resolvedTargets = New-Object Collections.Generic.List[object]
foreach ($slotRow in $slotRows) {
    $slot = [string](Get-RequiredProperty $slotRow 'slot')
    $partition = [string](Get-RequiredProperty $slotRow 'partition')
    if ($slot -notmatch '^Slot[0-9]{2}$' -or $partition -notin @('DEVELOPMENT', 'INDEPENDENT_VALIDATION')) { throw 'OLS5 slot partition is invalid.' }
    foreach ($channel in $channels) {
        $relative = $pathTemplate.Replace('{acquisitionId}', $acquisitionId).Replace('{slot}', $slot).Replace('{channel}', $channel).Replace('{lotId}', $lotId).Replace('/', '\')
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|\\)\.\.?($|\\)' -or $relative.IndexOfAny([char[]]'*?[]') -ge 0) { throw 'OLS5 expanded source path is unsafe.' }
        if (-not $rowBySubtreePath.ContainsKey($relative)) { throw "OLS5 exact inventory source row is missing: $relative" }
        $row = $rowBySubtreePath[$relative]
        $aliasPath = $aliasName + ':\' + $relative
        $budget = Get-LexicalBudget $aliasPath
        if ($budget.effectiveLength -ge 200 -or $budget.longestComponentLength -gt 255 -or [int64](Get-RequiredProperty $row 'length') -ne $expectedBytesPerLeaf -or [bool](Get-RequiredProperty $row 'reparsePoint') -or -not [bool](Get-RequiredProperty $row 'containedByApprovedRoot') -or [string](Get-RequiredProperty $row 'extension') -ne '.bmp') { throw "OLS5 frozen source-row contract failed: $relative" }
        $resolvedTargets.Add([pscustomobject]@{ slot = $slot; channel = $channel; partition = $partition; subtreeRelativePath = $relative; aliasReadPath = $aliasPath; canonicalProvenancePath = [string](Get-RequiredProperty $row 'canonicalProvenancePath'); expectedBytes = [int64](Get-RequiredProperty $row 'length'); inventoryLastWriteTimeUtc = [string](Get-RequiredProperty $row 'lastWriteTimeUtc'); aliasEffectiveLength = [int]$budget.effectiveLength; aliasLongestComponentLength = [int]$budget.longestComponentLength })
    }
}
if ($resolvedTargets.Count -ne $expectedTargetCount) { throw 'OLS5 resolved target count changed.' }

$outputBudget = Get-LexicalBudget $outputPath
if ($outputBudget.effectiveLength -ge 200 -or $outputBudget.longestComponentLength -gt 80 -or (Test-Path -LiteralPath $outputPath)) { throw 'OLS5 output path is unsafe or already exists.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols5_entrypoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS5_SOURCE_HASH_PREFLIGHT'
        approvedDataRoot = $approvedDataRootName
        approvedRoot = $approvedRoot
        relativeSubtree = $relativeSubtree
        targetCount = $resolvedTargets.Count
        developmentPairCount = @($slotRows | Where-Object { [string]$_.partition -eq 'DEVELOPMENT' }).Count
        independentValidationPairCount = @($slotRows | Where-Object { [string]$_.partition -eq 'INDEPENDENT_VALIDATION' }).Count
        targetManifestSha256 = $expectedTargetManifestSha256
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

if (Get-PSDrive -Name $aliasName -ErrorAction SilentlyContinue) { throw "OLS5 process-local alias is already in use: $aliasName" }
$aliasCreated = $false
$hashRows = New-Object Collections.Generic.List[object]
$bytesRead = [int64]0
try {
    New-PSDrive -Name $aliasName -PSProvider FileSystem -Root $requestedSubtreeRoot -Scope Script | Out-Null
    $aliasCreated = $true
    foreach ($target in $resolvedTargets) {
        $itemBefore = Get-Item -LiteralPath $target.aliasReadPath -Force
        if ($itemBefore.PSIsContainer -or ($itemBefore.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or [int64]$itemBefore.Length -ne [int64]$target.expectedBytes) { throw "OLS5 source metadata changed before hashing: $($target.subtreeRelativePath)" }
        $lastWriteBefore = $itemBefore.LastWriteTimeUtc.ToString('o')
        $sha256 = Get-ProviderSha256 $target.aliasReadPath
        $itemAfter = Get-Item -LiteralPath $target.aliasReadPath -Force
        $lastWriteAfter = $itemAfter.LastWriteTimeUtc.ToString('o')
        if ([int64]$itemAfter.Length -ne [int64]$itemBefore.Length -or $lastWriteAfter -ne $lastWriteBefore) { throw "OLS5 source changed while hashing: $($target.subtreeRelativePath)" }
        $bytesRead += [int64]$itemAfter.Length
        $hashRows.Add([pscustomobject]@{
            slot = $target.slot
            channel = $target.channel
            partition = $target.partition
            subtreeRelativePath = $target.subtreeRelativePath
            canonicalProvenancePath = $target.canonicalProvenancePath
            aliasReadPath = $target.aliasReadPath
            bytes = [int64]$itemAfter.Length
            lastWriteTimeUtc = $lastWriteAfter
            sha256 = $sha256
            sourceStableDuringHash = $true
            pixelsDecoded = $false
            imageProcessingPerformed = $false
            sourceMutationPerformed = $false
        })
        if ($Rehearsal -and $failAfterHashCount -gt 0 -and $hashRows.Count -ge $failAfterHashCount) { throw 'INJECTED_OLS5_FAILURE_AFTER_HASH' }
    }
} finally {
    if ($aliasCreated) { Remove-PSDrive -Name $aliasName -Force -ErrorAction SilentlyContinue }
}
if (Get-PSDrive -Name $aliasName -ErrorAction SilentlyContinue) { throw 'OLS5 process-local alias cleanup failed.' }

$result = [ordered]@{
    schema = 'argos_ols5_source_hash_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OCV00_FRONT_SOURCE_HASHES_OLS5'
    rehearsal = [bool]$Rehearsal
    approvedDataRoot = $approvedDataRootName
    approvedRoot = $approvedRoot
    relativeSubtree = $relativeSubtree
    targetManifestSha256 = $expectedTargetManifestSha256
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
if ([string](Get-RequiredProperty $readback 'state') -ne 'PASS_OCV00_FRONT_SOURCE_HASHES_OLS5' -or [int](Get-RequiredProperty $readback 'targetCount') -ne $expectedTargetCount -or -not [bool](Get-RequiredProperty $readback 'sourceHashingPerformed') -or [bool](Get-RequiredProperty $readback 'pixelsDecoded') -or [bool](Get-RequiredProperty $readback 'imageProcessingPerformed')) { throw 'OLS5 output readback failed.' }
$result['capabilityOutputPath'] = $outputPath
$result['capabilityOutputBytes'] = (Get-Item -LiteralPath $outputPath).Length
$result['capabilityOutputSha256'] = Get-PhysicalSha256 $outputPath
$result | ConvertTo-Json -Depth 32
