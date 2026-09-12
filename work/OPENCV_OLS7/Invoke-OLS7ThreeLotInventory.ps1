#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Preflight -and $Rehearsal) { throw 'OLS7 cannot combine Preflight and Rehearsal.' }

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open([IO.Path]::GetFullPath($Path), [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Assert-NewOutputPath([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $components = @($full.Split('\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $longest = if ($components.Count) { [int](($components | Measure-Object Length -Maximum).Maximum) } else { 0 }
    Require (($full.Length + 32) -lt 200 -and $longest -le 80) 'OLS7 output path budget failed.'
    Require (-not (Test-Path -LiteralPath $full)) "OLS7 refuses existing output: $full"
    return $full
}

function Write-Utf8JsonCreateNew([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "OLS7 refuses overwrite: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$providerPath = Join-Path $processorRoot 'OCV03_MetadataProviderV1.ps1'
$targetManifestPath = Join-Path $PSScriptRoot 'OLS7_TARGETS.json'
$failAfterTargetIndex = -1

if ($Preflight -or $Rehearsal) {
    Require (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) 'OLS7 Preflight/Rehearsal requires InvocationManifest.'
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    Require ((Test-Path -LiteralPath $invocationPath -PathType Leaf) -and (Get-Item -LiteralPath $invocationPath).Length -le 65536) 'OLS7 invocation manifest is missing or too large.'
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    Require ([string]$invocation.schema -ceq 'argos_ols7_entrypoint_invocation_v1') 'OLS7 invocation schema mismatch.'
    $portalRoot = [IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\')
    $processorRoot = [IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $providerPath = [IO.Path]::GetFullPath([string]$invocation.providerPath)
    $targetManifestPath = [IO.Path]::GetFullPath([string]$invocation.targetManifestPath)
    if ($invocation.PSObject.Properties.Name -contains 'failAfterTargetIndex') { $failAfterTargetIndex = [int]$invocation.failAfterTargetIndex }
}
Require ($Rehearsal -or $failAfterTargetIndex -eq -1) 'OLS7 failure injection is rehearsal-only.'
Require ($failAfterTargetIndex -ge -1 -and $failAfterTargetIndex -le 2) 'OLS7 failure injection index is out of range.'

$expectedProviderSha = 'DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
$expectedTargetsSha = 'E884974593D0696EAC86EAEE39B8D6AFFF3608EDFC4273883C5A1E32C0542BD9'
$expectedIds = @('UNPATTERNED_NO_DIELECTRIC_62636_134', 'UNPATTERNED_DIELECTRIC_62631_586', 'PATTERNED_NO_METAL_CHIPOUT_62628_279')
$expectedRoots = @('UnpatternedFront\Lot_62636-134', 'UnpatternedFront\Lot_62631-586', 'PatternedFront\Lot_62628-279')
$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
$outputPath = Assert-NewOutputPath (Join-Path $processorRoot 'OCV03_OLS7_THREE_LOT_INVENTORY.json')
foreach ($path in @($configPath, $providerPath, $targetManifestPath)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "OLS7 prerequisite is missing: $path" }
Require ((Get-Sha256 $providerPath) -ceq $expectedProviderSha) 'OLS7 installed provider hash changed.'
Require ((Get-Sha256 $targetManifestPath) -ceq $expectedTargetsSha) 'OLS7 target manifest hash changed.'

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($providerPath, [ref]$tokens, [ref]$parseErrors)
Require (@($parseErrors).Count -eq 0) 'OLS7 provider parser failed.'
$targets = Get-Content -LiteralPath $targetManifestPath -Raw | ConvertFrom-Json
Require ([string]$targets.schema -ceq 'argos_ols7_three_lot_inventory_targets_v1' -and [string]$targets.state -ceq 'FROZEN_FOR_PACKAGE') 'OLS7 target contract identity changed.'
Require ([string]$targets.approvedDataRootName -ceq 'JBOD_KLARF_EXPORT' -and [string]$targets.aliasName -ceq 'F') 'OLS7 target root or alias changed.'
Require ([int]$targets.maximumDepth -eq 8 -and [int]$targets.maximumEntries -eq 20000 -and [int]$targets.maximumDirectories -eq 2048 -and [int]$targets.maximumBmpLeaves -eq 2048) 'OLS7 inventory bounds changed.'
Require (-not [bool]$targets.fileContentReadAllowed -and -not [bool]$targets.imageBytesReadAllowed -and -not [bool]$targets.sourceHashingAllowed -and -not [bool]$targets.taskOrProcessActionAllowed) 'OLS7 metadata-only authority changed.'
$targetRows = @($targets.targets)
Require ($targetRows.Count -eq 3) 'OLS7 target cardinality changed.'
for ($i = 0; $i -lt 3; $i++) {
    Require ([string]$targetRows[$i].id -ceq $expectedIds[$i] -and [string]$targetRows[$i].relativeSubtree -ceq $expectedRoots[$i]) "OLS7 target row $i changed."
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Require ([string]$config.schema -ceq 'argos_project_portal_endpoint_config_v1' -and [string]$config.role -ceq 'JBOD' -and [bool]$config.reviewOnly -and -not [bool]$config.productionRoutingEnabled) 'OLS7 endpoint config authority failed closed.'
$mapping = @($config.approvedDataRoots | Where-Object { [string]$_.name -ceq 'JBOD_KLARF_EXPORT' })
Require ($mapping.Count -eq 1) 'OLS7 approved data-root mapping cardinality changed.'
$approvedRoot = [IO.Path]::GetFullPath([string]$mapping[0].path).TrimEnd('\')

$preflightRows = New-Object Collections.Generic.List[object]
foreach ($target in $targetRows) {
    $providerPreflight = (& $providerPath -Preflight -ApprovedRoot $approvedRoot -RelativeSubtree ([string]$target.relativeSubtree) -AliasName F -MaximumDepth 8 -MaximumEntries 20000 -MaximumDirectories 2048 -MaximumBmpLeaves 2048) | ConvertFrom-Json
    Require ([string]$providerPreflight.state -ceq 'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_PREFLIGHT' -and [string]$providerPreflight.aliasAnchor -ceq 'EXACT_REQUESTED_SUBTREE_ROOT') 'OLS7 provider preflight identity changed.'
    Require (-not [bool]$providerPreflight.pathsEnumerated -and -not [bool]$providerPreflight.filesRead -and -not [bool]$providerPreflight.imageBytesRead -and -not [bool]$providerPreflight.sourceHashingPerformed -and -not [bool]$providerPreflight.mutationsPerformed) 'OLS7 provider preflight crossed the observation boundary.'
    $preflightRows.Add([pscustomobject]@{ id = [string]$target.id; relativeSubtree = [string]$target.relativeSubtree; requestedSubtreeRoot = [string]$providerPreflight.requestedSubtreeRoot })
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols7_entrypoint_preflight_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OLS7_ENTRYPOINT_PREFLIGHT'
        providerSha256 = $expectedProviderSha; targetManifestSha256 = $expectedTargetsSha; targetCount = 3; targets = $preflightRows.ToArray()
        outputPath = $outputPath; pathsEnumerated = $false; filesRead = $false; imageBytesRead = $false; sourceHashingPerformed = $false
        mutationsPerformed = $false; reviewOnly = $true; productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$caseResults = New-Object Collections.Generic.List[object]
for ($i = 0; $i -lt $targetRows.Count; $i++) {
    $target = $targetRows[$i]
    $inventory = (& $providerPath -Inventory -ApprovedRoot $approvedRoot -RelativeSubtree ([string]$target.relativeSubtree) -AliasName F -MaximumDepth 8 -MaximumEntries 20000 -MaximumDirectories 2048 -MaximumBmpLeaves 2048 -Rehearsal:$Rehearsal) | ConvertFrom-Json
    Require ([string]$inventory.schema -ceq 'argos_ocv00_deepest_alias_inventory_v1' -and [string]$inventory.state -in @('COMPLETE', 'HOLD_INCOMPLETE')) 'OLS7 provider terminal identity changed.'
    Require ([bool]$inventory.complete -eq ([string]$inventory.state -ceq 'COMPLETE')) 'OLS7 provider completion semantics changed.'
    Require ([string]$inventory.relativeSubtree -ceq [string]$target.relativeSubtree -and [string]$inventory.aliasRoot -ceq 'F:\' -and [string]$inventory.aliasAnchor -ceq 'EXACT_REQUESTED_SUBTREE_ROOT') 'OLS7 provider target or alias identity changed.'
    Require (-not [bool]$inventory.processLocalAlias.persistent -and [bool]$inventory.processLocalAlias.removed) 'OLS7 provider did not remove its process-local alias.'
    Require (-not [bool]$inventory.filesRead -and -not [bool]$inventory.imageBytesRead -and -not [bool]$inventory.sourceHashingPerformed -and -not [bool]$inventory.mutationsPerformed) 'OLS7 provider crossed the metadata-only boundary.'
    Require (@($inventory.directories).Count -eq [int]$inventory.directoryCount -and @($inventory.bmpLeaves).Count -eq [int]$inventory.bmpLeafCount -and @($inventory.skippedPathRows).Count -eq [int]$inventory.skippedPathRowCount) 'OLS7 provider row counts changed.'
    $caseResults.Add([pscustomobject]@{ id = [string]$target.id; relativeSubtree = [string]$target.relativeSubtree; disposition = [string]$inventory.state; inventory = $inventory })
    if ($i -eq $failAfterTargetIndex) { throw "INJECTED_OLS7_FAILURE_AFTER_TARGET_$i" }
}

$allComplete = @($caseResults | Where-Object { [string]$_.disposition -ne 'COMPLETE' }).Count -eq 0
$result = [ordered]@{
    schema = 'argos_ols7_three_lot_inventory_result_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_OCV03_THREE_LOT_METADATA_OLS7'
    rehearsal = [bool]$Rehearsal; overallDisposition = if ($allComplete) { 'COMPLETE' } else { 'HOLD_INCOMPLETE' }
    approvedDataRoot = 'JBOD_KLARF_EXPORT'; approvedRoot = $approvedRoot; providerSha256 = $expectedProviderSha; targetManifestSha256 = $expectedTargetsSha
    targetCount = 3; completedTargetCount = $caseResults.Count; targets = $caseResults.ToArray(); pathsEnumerated = $true
    filesRead = $false; imageBytesRead = $false; sourceHashingPerformed = $false; sourceDeletionPerformed = $false
    inspectionTasksChanged = $false; processorTaskChanged = $false; processActions = @(); waferActionPerformed = $false
    reviewOnly = $true; productionRoutingEnabled = $false
}
Write-Utf8JsonCreateNew $outputPath $result
$readback = Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json
Require ([string]$readback.state -ceq 'PASS_OCV03_THREE_LOT_METADATA_OLS7' -and [int]$readback.targetCount -eq 3 -and [int]$readback.completedTargetCount -eq 3) 'OLS7 output readback failed.'
$result['capabilityOutputPath'] = $outputPath
$result['capabilityOutputSha256'] = Get-Sha256 $outputPath
$result['capabilityOutputBytes'] = (Get-Item -LiteralPath $outputPath).Length
$result | ConvertTo-Json -Depth 40
