#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Preflight -and $Rehearsal) { throw 'O3C2 cannot combine Preflight and Rehearsal.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$providerPath = Join-Path $processorRoot 'OCV03_SourceFreezeProviderV1.ps1'
$targetManifestPath = Join-Path $PSScriptRoot 'O3C2_SOURCE_TARGETS.json'
$inventoryPath = Join-Path $processorRoot 'OCV03_O3C1_HOTSPOT_INVENTORY.json'
$outputPath = Join-Path $processorRoot 'OCV03_O3C2_SOURCE_FREEZE.json'
$aliasName = 'F'
$failAfterHashCount = 0
$expectedProviderSha256 = '1A73D69F38C1E578734E30376845DF308636A893A846CF86FB9531144FE04B88'
$expectedTargetManifestSha256 = 'AF94AAF89093781624C5A113BC58147CA1E94F030EC5132E2C00F1A26A1F79A4'
$expectedInventorySha256 = '3B79EE01AE98C2C5A5E5A69BBC837E67D228DFD652F6B348AD16C10F5B928F49'

if ($Preflight -or $Rehearsal) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3C2 Preflight/Rehearsal requires InvocationManifest.'
    $invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'O3C2 invocation manifest is missing.'
    Assert-True ((Get-Item -LiteralPath $invocationPath).Length -le 65536) 'O3C2 invocation manifest is too large.'
    $invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
    Assert-True ([string]$invocation.schema -eq 'argos_o3c2_entrypoint_invocation_v1') 'O3C2 invocation schema changed.'
    $portalRoot = [IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\')
    $processorRoot = [IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $providerPath = [IO.Path]::GetFullPath([string]$invocation.providerPath)
    $targetManifestPath = [IO.Path]::GetFullPath([string]$invocation.targetManifestPath)
    $inventoryPath = [IO.Path]::GetFullPath([string]$invocation.inventoryPath)
    $outputPath = [IO.Path]::GetFullPath([string]$invocation.outputPath)
    $aliasName = [string]$invocation.aliasName
    $expectedProviderSha256 = ([string]$invocation.expectedProviderSha256).ToUpperInvariant()
    $expectedTargetManifestSha256 = ([string]$invocation.expectedTargetManifestSha256).ToUpperInvariant()
    $expectedInventorySha256 = ([string]$invocation.expectedInventorySha256).ToUpperInvariant()
    if ($invocation.PSObject.Properties.Name -contains 'failAfterHashCount') { $failAfterHashCount = [int]$invocation.failAfterHashCount }
}

Assert-True ($aliasName -match '^[A-Z]$') 'O3C2 alias identity is invalid.'
if (-not $Preflight -and -not $Rehearsal) {
    Assert-True ($aliasName -eq 'F') 'O3C2 live alias changed.'
    Assert-True ($providerPath -eq (Join-Path $processorRoot 'OCV03_SourceFreezeProviderV1.ps1')) 'O3C2 live provider path changed.'
    Assert-True ($targetManifestPath -eq (Join-Path $PSScriptRoot 'O3C2_SOURCE_TARGETS.json')) 'O3C2 live target manifest path changed.'
    Assert-True ($inventoryPath -eq (Join-Path $processorRoot 'OCV03_O3C1_HOTSPOT_INVENTORY.json')) 'O3C2 live inventory path changed.'
    Assert-True ($outputPath -eq (Join-Path $processorRoot 'OCV03_O3C2_SOURCE_FREEZE.json')) 'O3C2 live output path changed.'
}

foreach ($pin in @(
    [pscustomobject]@{path=$providerPath;sha256=$expectedProviderSha256;label='provider'},
    [pscustomobject]@{path=$targetManifestPath;sha256=$expectedTargetManifestSha256;label='target manifest'},
    [pscustomobject]@{path=$inventoryPath;sha256=$expectedInventorySha256;label='inventory'}
)) {
    Assert-True (Test-Path -LiteralPath $pin.path -PathType Leaf) "O3C2 pinned $($pin.label) is missing."
    Assert-True ((Get-Sha256 $pin.path) -eq $pin.sha256) "O3C2 pinned $($pin.label) changed."
}
$providerCommand = Get-Command -Name $providerPath -CommandType ExternalScript -ErrorAction Stop
foreach ($parameter in @('Preflight','Hash','ConfigPath','TargetManifest','InventoryPath','OutputPath','AliasName','FailAfterHashCount')) {
    Assert-True ($providerCommand.Parameters.Keys -contains $parameter) "O3C2 provider argument is missing: $parameter"
}
$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
Assert-True (Test-Path -LiteralPath $configPath -PathType Leaf) 'O3C2 endpoint config is missing.'
$providerPreflight = (& $providerPath -Preflight -ConfigPath $configPath -TargetManifest $targetManifestPath -InventoryPath $inventoryPath -OutputPath $outputPath -AliasName $aliasName | Out-String) | ConvertFrom-Json
Assert-True ([string]$providerPreflight.state -eq 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_PREFLIGHT') 'O3C2 provider preflight failed.'
Assert-True ([int]$providerPreflight.pairCount -eq 10 -and [int]$providerPreflight.leafCount -eq 20) 'O3C2 provider preflight cardinality changed.'
Assert-True (-not [bool]$providerPreflight.sourceHashingPerformed -and -not [bool]$providerPreflight.imageBytesDecoded -and -not [bool]$providerPreflight.pixelProcessingPerformed -and -not [bool]$providerPreflight.mutationsPerformed) 'O3C2 provider preflight mutated or read source bytes.'
Assert-True (-not [bool]$providerPreflight.knownNotchLocationConsumed -and -not [bool]$providerPreflight.notchAnglePriorConsumed -and -not [bool]$providerPreflight.fixedAngularSearchWindowConsumed) 'O3C2 provider preflight consumed a forbidden notch prior.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3c2_entrypoint_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C2_ENTRYPOINT_PREFLIGHT'
        providerSha256 = $expectedProviderSha256
        targetManifestSha256 = $expectedTargetManifestSha256
        inventorySha256 = $expectedInventorySha256
        pairCount = 10
        leafCount = 20
        outputPath = $outputPath
        namedArgumentsResolvedByGetCommand = $true
        sourceBytesRead = 0
        sourceHashingPerformed = $false
        imageBytesDecoded = $false
        pixelProcessingPerformed = $false
        mutationsPerformed = $false
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
        providerActivated = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

try {
    $providerJson = & $providerPath -Hash -ConfigPath $configPath -TargetManifest $targetManifestPath -InventoryPath $inventoryPath -OutputPath $outputPath -AliasName $aliasName -FailAfterHashCount $failAfterHashCount | Out-String
} catch {
    throw ('O3C2_PROVIDER_EXECUTION_FAILED: ' + $_.Exception.Message)
}
$result = $providerJson | ConvertFrom-Json
Assert-True ([string]$result.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE') 'O3C2 provider terminal state changed.'
Assert-True ([int]$result.pairCount -eq 10 -and [int]$result.leafCount -eq 20) 'O3C2 provider terminal cardinality changed.'
Assert-True ([bool]$result.sourceHashingPerformed -and -not [bool]$result.imageBytesDecoded -and -not [bool]$result.pixelProcessingPerformed) 'O3C2 provider terminal authority changed.'
Assert-True (-not [bool]$result.knownNotchLocationConsumed -and -not [bool]$result.notchAnglePriorConsumed -and -not [bool]$result.fixedAngularSearchWindowConsumed) 'O3C2 provider terminal consumed a forbidden notch prior.'
Assert-True (-not [bool]$result.sourceMutationPerformed -and -not [bool]$result.sourceDeletionPerformed -and -not [bool]$result.inspectionTasksChanged -and -not [bool]$result.processorTaskChanged -and -not [bool]$result.providerActivated -and -not [bool]$result.waferActionPerformed) 'O3C2 provider terminal mutated a protected surface.'
$result | ConvertTo-Json -Depth 40
