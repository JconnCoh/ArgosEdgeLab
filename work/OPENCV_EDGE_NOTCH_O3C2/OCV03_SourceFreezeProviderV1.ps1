#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Hash,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ConfigPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TargetManifest,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InventoryPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$OutputPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Z]$')][string]$AliasName,
    [ValidateRange(0, 64)][int]$FailAfterHashCount = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Hash)) { throw 'Specify exactly one of -Preflight or -Hash.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RequiredProperty([object]$InputObject, [string]$Name) {
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "O3C2 required property is absent: $Name" }
    return $property.Value
}

function Get-PhysicalSha256([string]$LiteralPath) {
    $stream = New-Object IO.FileStream($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, 8388608, [IO.FileOptions]::SequentialScan)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-StringSha256([string]$Value) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Value)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    } finally { $sha.Dispose() }
}

function Get-LexicalBudget([string]$Path, [int]$Reserve = 32) {
    $text = $Path.Replace('/', '\')
    $tail = if ($text -match '^[A-Za-z]:\\') {
        $text.Substring(3)
    } elseif ($text -match '^\\\\[^\\]+\\[^\\]+(?:\\|$)') {
        $text.Substring(([regex]::Match($text, '^\\\\[^\\]+\\[^\\]+(?:\\|$)')).Length)
    } else {
        $text.TrimStart('\')
    }
    $components = @($tail.Split('\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $longest = if ($components.Count) { [int](($components | Measure-Object Length -Maximum).Maximum) } else { 0 }
    return [pscustomobject]@{ effectiveLength = [int]$text.Length + $Reserve; longestComponentLength = $longest }
}

function Get-SafeChildPath([string]$Root, [string]$Relative) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($Relative)) 'O3C2 relative subtree is empty.'
    Assert-True (-not [IO.Path]::IsPathRooted($Relative)) 'O3C2 relative subtree is rooted.'
    Assert-True ($Relative -notmatch '(^|\\)\.\.?($|\\)') 'O3C2 relative subtree contains traversal.'
    Assert-True ($Relative.IndexOfAny([char[]]'*?[]') -lt 0) 'O3C2 relative subtree contains wildcard syntax.'
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidate = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative.Replace('/', '\')))
    Assert-True ($candidate.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) 'O3C2 relative subtree escaped its approved root.'
    return $candidate
}

function Get-SubstMappings([string]$SubstExe) {
    $rows = @(& $SubstExe 2>&1)
    Assert-True ($LASTEXITCODE -eq 0) 'O3C2 subst inventory failed.'
    $mapping = @{}
    foreach ($row in $rows) {
        $text = [string]$row
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $match = [regex]::Match($text, '^([A-Za-z]):\\: => (.+)$')
        Assert-True $match.Success "O3C2 subst inventory row is malformed: $text"
        $name = $match.Groups[1].Value.ToUpperInvariant()
        Assert-True (-not $mapping.ContainsKey($name)) "O3C2 subst inventory duplicated drive $name."
        $mapping[$name] = [IO.Path]::GetFullPath($match.Groups[2].Value).TrimEnd('\')
    }
    return $mapping
}

function Write-Utf8JsonCreateNew([string]$LiteralPath, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $LiteralPath)) "O3C2 refuses existing output: $LiteralPath"
    [IO.File]::WriteAllText($LiteralPath, (($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$configFull = [IO.Path]::GetFullPath($ConfigPath)
$targetsFull = [IO.Path]::GetFullPath($TargetManifest)
$inventoryFull = [IO.Path]::GetFullPath($InventoryPath)
$outputFull = [IO.Path]::GetFullPath($OutputPath)
foreach ($path in @($configFull, $targetsFull, $inventoryFull)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3C2 prerequisite is missing: $path"
}
Assert-True ((Get-Item -LiteralPath $configFull).Length -le 1048576) 'O3C2 config is too large.'
Assert-True ((Get-Item -LiteralPath $targetsFull).Length -le 1048576) 'O3C2 target manifest is too large.'
Assert-True ((Get-Item -LiteralPath $inventoryFull).Length -le 16777216) 'O3C2 inventory is too large.'

$config = Get-Content -LiteralPath $configFull -Raw | ConvertFrom-Json
$targets = Get-Content -LiteralPath $targetsFull -Raw | ConvertFrom-Json
$inventoryResult = Get-Content -LiteralPath $inventoryFull -Raw | ConvertFrom-Json
$inventory = Get-RequiredProperty $inventoryResult 'inventory'

Assert-True ([string](Get-RequiredProperty $config 'schema') -eq 'argos_project_portal_endpoint_config_v1') 'O3C2 endpoint config schema changed.'
Assert-True ([string](Get-RequiredProperty $config 'role') -eq 'JBOD') 'O3C2 endpoint role changed.'
Assert-True ([bool](Get-RequiredProperty $config 'reviewOnly')) 'O3C2 endpoint is not review-only.'
Assert-True (-not [bool](Get-RequiredProperty $config 'productionRoutingEnabled')) 'O3C2 endpoint enables production routing.'

Assert-True ([string](Get-RequiredProperty $targets 'schema') -eq 'argos_ocv03_source_freeze_targets_v1') 'O3C2 target schema changed.'
Assert-True ([string](Get-RequiredProperty $targets 'state') -eq 'FROZEN') 'O3C2 targets are not frozen.'
Assert-True ([string](Get-RequiredProperty $targets 'sourceHashAlgorithm') -eq 'SHA256') 'O3C2 hash algorithm changed.'
Assert-True ([string](Get-RequiredProperty $targets 'acquisitionFingerprintSchema') -eq 'argos_ocv03_pair_acquisition_fingerprint_v1') 'O3C2 fingerprint schema changed.'
Assert-True ([bool](Get-RequiredProperty $targets 'readThroughExactSubtreeShortAliasOnly')) 'O3C2 short-alias contract changed.'
Assert-True (-not [bool](Get-RequiredProperty $targets 'knownNotchLocationConsumed')) 'O3C2 target manifest consumes a known notch location.'
Assert-True (-not [bool](Get-RequiredProperty $targets 'notchAnglePriorConsumed')) 'O3C2 target manifest consumes a notch-angle prior.'
Assert-True (-not [bool](Get-RequiredProperty $targets 'fixedAngularSearchWindowConsumed')) 'O3C2 target manifest consumes a fixed angular search window.'
foreach ($property in @('decodePixels', 'imageProcessingAllowed', 'sourceMutationAllowed', 'taskOrProcessActionAllowed', 'providerActivationAllowed', 'productionEligible', 'trainingEligible', 'xmlEligible')) {
    Assert-True (-not [bool](Get-RequiredProperty $targets $property)) "O3C2 forbidden target authority is true: $property"
}
Assert-True ([bool](Get-RequiredProperty $targets 'reviewOnly')) 'O3C2 targets are not review-only.'

$expectedInventorySha256 = ([string](Get-RequiredProperty $targets 'installedInventorySha256')).ToUpperInvariant()
Assert-True ((Get-PhysicalSha256 $inventoryFull) -eq $expectedInventorySha256) 'O3C2 installed inventory hash changed.'
Assert-True ([string](Get-RequiredProperty $inventoryResult 'schema') -eq 'argos_o3c1_entrypoint_result_v1') 'O3C2 installed inventory result schema changed.'
Assert-True ([string](Get-RequiredProperty $inventoryResult 'state') -eq 'PASS_OCV03_METADATA_CAPABILITY_O3C1') 'O3C2 installed inventory result state changed.'
Assert-True ([string](Get-RequiredProperty $inventoryResult 'inventoryDisposition') -eq 'COMPLETE') 'O3C2 installed inventory is incomplete.'
Assert-True ([string](Get-RequiredProperty $inventory 'state') -eq 'COMPLETE') 'O3C2 nested inventory is incomplete.'
Assert-True ([bool](Get-RequiredProperty $inventory 'complete')) 'O3C2 nested inventory complete flag is false.'
Assert-True ([int](Get-RequiredProperty $inventory 'skippedPathRowCount') -eq 0) 'O3C2 inventory contains skipped paths.'
Assert-True ([int](Get-RequiredProperty $inventory 'accessErrorCount') -eq 0) 'O3C2 inventory contains access errors.'
Assert-True (-not [bool](Get-RequiredProperty $inventory 'truncated')) 'O3C2 inventory was truncated.'

$approvedDataRootName = [string](Get-RequiredProperty $targets 'approvedDataRoot')
$rootMatches = @($config.approvedDataRoots | Where-Object { [string]$_.name -eq $approvedDataRootName })
Assert-True ($rootMatches.Count -eq 1) 'O3C2 approved data-root cardinality changed.'
$approvedRoot = [IO.Path]::GetFullPath([string]$rootMatches[0].path).TrimEnd('\')
$relativeSubtree = ([string](Get-RequiredProperty $targets 'relativeSubtree')).Replace('/', '\')
Assert-True ([string](Get-RequiredProperty $inventory 'relativeSubtree') -eq $relativeSubtree) 'O3C2 inventory subtree changed.'
$requestedSubtreeRoot = Get-SafeChildPath $approvedRoot $relativeSubtree

$channels = @(Get-RequiredProperty $targets 'channels')
$slotRows = @(Get-RequiredProperty $targets 'slots')
$expectedPairCount = [int](Get-RequiredProperty $targets 'targetPairCount')
$expectedLeafCount = [int](Get-RequiredProperty $targets 'targetLeafCount')
Assert-True ($channels.Count -eq 2) 'O3C2 requires exactly two channels.'
Assert-True (@($channels | Where-Object { [string]$_.channel -eq 'BF' -and [string]$_.channelFolder -eq 'Brightfield' }).Count -eq 1) 'O3C2 BF channel contract changed.'
Assert-True (@($channels | Where-Object { [string]$_.channel -eq 'DF' -and [string]$_.channelFolder -eq 'Darkfield' }).Count -eq 1) 'O3C2 DF channel contract changed.'
Assert-True ($slotRows.Count -ge 1 -and $slotRows.Count -le 32) 'O3C2 pair cardinality is outside 1..32.'
Assert-True ($slotRows.Count -eq $expectedPairCount -and ($slotRows.Count * 2) -eq $expectedLeafCount -and $expectedLeafCount -le 64) 'O3C2 target cardinality is inconsistent.'

$rowByRelativePath = @{}
foreach ($row in @(Get-RequiredProperty $inventory 'bmpLeaves')) {
    $key = ([string](Get-RequiredProperty $row 'subtreeRelativePath')).Replace('/', '\')
    Assert-True (-not $rowByRelativePath.ContainsKey($key)) "O3C2 duplicate inventory row: $key"
    $rowByRelativePath[$key] = $row
}

$lotId = [string](Get-RequiredProperty $targets 'lotId')
$acquisitionId = [string](Get-RequiredProperty $targets 'acquisitionId')
$pathTemplate = [string](Get-RequiredProperty $targets 'pathTemplate')
$expectedBytesPerLeaf = [int64](Get-RequiredProperty $targets 'expectedBytesPerLeaf')
$resolved = New-Object Collections.Generic.List[object]
$identities = @{}
foreach ($slotRow in $slotRows) {
    $slot = [string](Get-RequiredProperty $slotRow 'slot')
    $physicalIdentity = [string](Get-RequiredProperty $slotRow 'physicalIdentity')
    $partition = [string](Get-RequiredProperty $slotRow 'partition')
    Assert-True ($slot -match '^Slot[0-9]{2}$') 'O3C2 slot identity is invalid.'
    Assert-True (-not [string]::IsNullOrWhiteSpace($physicalIdentity) -and $physicalIdentity.Length -le 128 -and $physicalIdentity.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -lt 0) 'O3C2 physical identity is invalid.'
    Assert-True (-not $identities.ContainsKey($physicalIdentity)) 'O3C2 physical identity is duplicated.'
    Assert-True ($partition -eq 'DEVELOPMENT_AND_PERMANENT_HOTSPOT_REGRESSION_CHALLENGE') 'O3C2 partition changed.'
    $identities[$physicalIdentity] = $true
    foreach ($channelRow in $channels) {
        $channel = [string](Get-RequiredProperty $channelRow 'channel')
        $channelFolder = [string](Get-RequiredProperty $channelRow 'channelFolder')
        $relative = $pathTemplate.Replace('{acquisitionId}', $acquisitionId).Replace('{slot}', $slot).Replace('{channelFolder}', $channelFolder).Replace('{lotId}', $lotId).Replace('/', '\')
        Assert-True (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|\\)\.\.?($|\\)' -and $relative.IndexOfAny([char[]]'*?[]') -lt 0) 'O3C2 expanded source path is unsafe.'
        Assert-True ($rowByRelativePath.ContainsKey($relative)) "O3C2 exact inventory source row is missing: $relative"
        $inventoryRow = $rowByRelativePath[$relative]
        $aliasReadPath = $AliasName + ':\' + $relative
        $budget = Get-LexicalBudget $aliasReadPath
        Assert-True ($budget.effectiveLength -lt 200 -and $budget.longestComponentLength -le 255) "O3C2 alias path is unsafe: $relative"
        Assert-True ([int64](Get-RequiredProperty $inventoryRow 'length') -eq $expectedBytesPerLeaf) "O3C2 source byte length changed: $relative"
        Assert-True ([string](Get-RequiredProperty $inventoryRow 'extension') -eq '.bmp') "O3C2 source extension changed: $relative"
        Assert-True (-not [bool](Get-RequiredProperty $inventoryRow 'reparsePoint')) "O3C2 inventory source is a reparse point: $relative"
        Assert-True ([bool](Get-RequiredProperty $inventoryRow 'containedByApprovedRoot')) "O3C2 inventory source escaped its approved root: $relative"
        $resolved.Add([pscustomobject]@{
            slot = $slot
            physicalIdentity = $physicalIdentity
            partition = $partition
            channel = $channel
            subtreeRelativePath = $relative
            canonicalProvenancePath = [string](Get-RequiredProperty $inventoryRow 'canonicalProvenancePath')
            aliasReadPath = $aliasReadPath
            expectedBytes = [int64](Get-RequiredProperty $inventoryRow 'length')
            inventoryLastWriteTimeUtc = [string](Get-RequiredProperty $inventoryRow 'lastWriteTimeUtc')
            aliasEffectiveLength = [int]$budget.effectiveLength
        })
    }
}
Assert-True ($resolved.Count -eq $expectedLeafCount) 'O3C2 resolved target count changed.'
Assert-True (@($resolved | Where-Object { $_.channel -eq 'BF' }).Count -eq $expectedPairCount) 'O3C2 BF target count changed.'
Assert-True (@($resolved | Where-Object { $_.channel -eq 'DF' }).Count -eq $expectedPairCount) 'O3C2 DF target count changed.'

$outputBudget = Get-LexicalBudget $outputFull
Assert-True ($outputBudget.effectiveLength -lt 200 -and $outputBudget.longestComponentLength -le 80) 'O3C2 output path budget failed.'
Assert-True (-not (Test-Path -LiteralPath $outputFull)) 'O3C2 output already exists.'
$subst = Get-Command -Name 'subst.exe' -CommandType Application -ErrorAction Stop

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_source_freeze_provider_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_PREFLIGHT'
        targetManifestSha256 = Get-PhysicalSha256 $targetsFull
        inventorySha256 = $expectedInventorySha256
        pairCount = $expectedPairCount
        leafCount = $expectedLeafCount
        aliasName = $AliasName
        aliasAnchor = 'EXACT_REQUESTED_SUBTREE_ROOT'
        aliasMutationPerformed = $false
        sourceBytesRead = 0
        sourceHashingPerformed = $false
        imageBytesDecoded = $false
        pixelProcessingPerformed = $false
        mutationsPerformed = $false
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$aliasRoot = $AliasName + ':\'
$preexistingMappings = Get-SubstMappings $subst.Source
Assert-True (-not $preexistingMappings.ContainsKey($AliasName)) "O3C2 subst alias is already mapped: $AliasName"
Assert-True (-not [IO.Directory]::Exists($aliasRoot)) "O3C2 alias root is already visible: $aliasRoot"
Assert-True ($null -eq (Get-PSDrive -Name $AliasName -ErrorAction SilentlyContinue)) "O3C2 alias drive is already present: $AliasName"

$aliasCreated = $false
$hashRows = New-Object Collections.Generic.List[object]
$bytesRead = [int64]0
try {
    $createOutput = @(& $subst.Source ($AliasName + ':') $requestedSubtreeRoot 2>&1)
    Assert-True ($LASTEXITCODE -eq 0 -and $createOutput.Count -eq 0) 'O3C2 subst alias creation failed.'
    $aliasCreated = $true
    $createdMappings = Get-SubstMappings $subst.Source
    Assert-True ($createdMappings.ContainsKey($AliasName)) 'O3C2 created subst alias is absent from inventory.'
    Assert-True ([string]$createdMappings[$AliasName] -eq $requestedSubtreeRoot) 'O3C2 subst alias mapped to the wrong exact subtree.'
    Assert-True ([IO.Directory]::Exists($aliasRoot)) 'O3C2 created alias is not Win32-visible.'

    foreach ($target in @($resolved | Sort-Object physicalIdentity, channel)) {
        $itemBefore = Get-Item -LiteralPath $target.aliasReadPath -Force
        Assert-True (-not $itemBefore.PSIsContainer) "O3C2 source is not a file: $($target.subtreeRelativePath)"
        Assert-True (($itemBefore.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "O3C2 source is a reparse point: $($target.subtreeRelativePath)"
        Assert-True ([int64]$itemBefore.Length -eq [int64]$target.expectedBytes) "O3C2 source length changed before hashing: $($target.subtreeRelativePath)"
        $lastWriteBefore = $itemBefore.LastWriteTimeUtc.ToString('o')
        Assert-True ($lastWriteBefore -eq [string]$target.inventoryLastWriteTimeUtc) "O3C2 source last-write changed since inventory: $($target.subtreeRelativePath)"
        $sha256 = Get-PhysicalSha256 $target.aliasReadPath
        $itemAfter = Get-Item -LiteralPath $target.aliasReadPath -Force
        $lastWriteAfter = $itemAfter.LastWriteTimeUtc.ToString('o')
        Assert-True ([int64]$itemAfter.Length -eq [int64]$itemBefore.Length -and $lastWriteAfter -eq $lastWriteBefore) "O3C2 source changed while hashing: $($target.subtreeRelativePath)"
        $bytesRead += [int64]$itemAfter.Length
        $hashRows.Add([pscustomobject]@{
            physicalIdentity = $target.physicalIdentity
            slot = $target.slot
            partition = $target.partition
            channel = $target.channel
            subtreeRelativePath = $target.subtreeRelativePath
            canonicalProvenancePath = $target.canonicalProvenancePath
            aliasReadPath = $target.aliasReadPath
            bytes = [int64]$itemAfter.Length
            lastWriteTimeUtc = $lastWriteAfter
            sha256 = $sha256
            sourceStableDuringHash = $true
        })
        if ($FailAfterHashCount -gt 0 -and $hashRows.Count -ge $FailAfterHashCount) { throw 'INJECTED_O3C2_FAILURE_AFTER_HASH' }
    }
} finally {
    if ($aliasCreated) {
        $removeOutput = @(& $subst.Source ($AliasName + ':') '/D' 2>&1)
        if ($LASTEXITCODE -ne 0 -or $removeOutput.Count -ne 0) { throw 'O3C2 subst alias cleanup failed.' }
    }
}
$remainingMappings = Get-SubstMappings $subst.Source
Assert-True (-not $remainingMappings.ContainsKey($AliasName) -and -not [IO.Directory]::Exists($aliasRoot)) 'O3C2 alias remained after cleanup.'

$pairs = New-Object Collections.Generic.List[object]
foreach ($slotRow in @($slotRows | Sort-Object physicalIdentity)) {
    $identity = [string]$slotRow.physicalIdentity
    $rows = @($hashRows | Where-Object { $_.physicalIdentity -eq $identity })
    Assert-True ($rows.Count -eq 2) "O3C2 pair is incomplete: $identity"
    $bf = @($rows | Where-Object { $_.channel -eq 'BF' })
    $df = @($rows | Where-Object { $_.channel -eq 'DF' })
    Assert-True ($bf.Count -eq 1 -and $df.Count -eq 1) "O3C2 pair channel cardinality changed: $identity"
    $newline = "`n"
    $preimage = 'schema=argos_ocv03_pair_acquisition_fingerprint_v1' + $newline +
        'physicalIdentity=' + $identity + $newline +
        'partition=' + [string]$slotRow.partition + $newline +
        'bf.relativePath=' + [string]$bf[0].subtreeRelativePath + $newline +
        'bf.bytes=' + ([string]$bf[0].bytes) + $newline +
        'bf.lastWriteTimeUtc=' + [string]$bf[0].lastWriteTimeUtc + $newline +
        'bf.sha256=' + [string]$bf[0].sha256 + $newline +
        'df.relativePath=' + [string]$df[0].subtreeRelativePath + $newline +
        'df.bytes=' + ([string]$df[0].bytes) + $newline +
        'df.lastWriteTimeUtc=' + [string]$df[0].lastWriteTimeUtc + $newline +
        'df.sha256=' + [string]$df[0].sha256 + $newline
    $pairs.Add([pscustomobject]@{
        physicalIdentity = $identity
        slot = [string]$slotRow.slot
        partition = [string]$slotRow.partition
        bf = $bf[0]
        df = $df[0]
        acquisitionFingerprintSchema = 'argos_ocv03_pair_acquisition_fingerprint_v1'
        acquisitionFingerprintSha256 = Get-StringSha256 $preimage
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
    })
}
$aggregatePreimage = 'schema=argos_ocv03_hotspot_source_freeze_v1' + "`n" + ((@($pairs | Sort-Object physicalIdentity | ForEach-Object { $_.physicalIdentity + '=' + $_.acquisitionFingerprintSha256 })) -join "`n") + "`n"
$result = [ordered]@{
    schema = 'argos_ocv03_hotspot_source_freeze_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE'
    disposition = 'LOCKED_INPUT'
    targetManifestSha256 = Get-PhysicalSha256 $targetsFull
    inventorySha256 = $expectedInventorySha256
    approvedDataRoot = $approvedDataRootName
    approvedRoot = $approvedRoot
    relativeSubtree = $relativeSubtree
    pairCount = $pairs.Count
    leafCount = $hashRows.Count
    sourceBytesRead = $bytesRead
    sourceHashAlgorithm = 'SHA256'
    pairs = $pairs
    aggregateFingerprintSchema = 'argos_ocv03_hotspot_source_freeze_v1'
    aggregateFingerprintSha256 = Get-StringSha256 $aggregatePreimage
    allSourcesStableDuringHash = $true
    processLocalAlias = [ordered]@{ name = $AliasName; type = 'SUBST_WIN32_VISIBLE'; anchor = 'EXACT_REQUESTED_SUBTREE_ROOT'; persistent = $false; removed = $true }
    sourceHashingPerformed = $true
    imageBytesDecoded = $false
    pixelProcessingPerformed = $false
    knownNotchLocationConsumed = $false
    notchAnglePriorConsumed = $false
    fixedAngularSearchWindowConsumed = $false
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    inspectionTasksChanged = $false
    processorTaskChanged = $false
    processActions = @()
    providerActivated = $false
    waferActionPerformed = $false
    independentValidationCohortInspected = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-Utf8JsonCreateNew $outputFull $result
$readback = Get-Content -LiteralPath $outputFull -Raw | ConvertFrom-Json
Assert-True ([string]$readback.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE') 'O3C2 output state readback failed.'
Assert-True ([int]$readback.pairCount -eq $expectedPairCount -and [int]$readback.leafCount -eq $expectedLeafCount) 'O3C2 output cardinality readback failed.'
Assert-True ([bool]$readback.sourceHashingPerformed -and -not [bool]$readback.imageBytesDecoded -and -not [bool]$readback.pixelProcessingPerformed) 'O3C2 output authority readback failed.'
$result['outputPath'] = $outputFull
$result['outputBytes'] = (Get-Item -LiteralPath $outputFull).Length
$result['outputSha256'] = Get-PhysicalSha256 $outputFull
$result | ConvertTo-Json -Depth 40
