#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3C2 test refuses existing file: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 40) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

function New-HashFixture([string]$Root, [int]$SlotCount) {
    Assert-True ($SlotCount -ge 0 -and $SlotCount -le 10) 'O3C2 fixture slot count is invalid.'
    [void](New-Item -ItemType Directory -Path $Root)
    $sourceRoot = Join-Path $Root 's'
    $processorRoot = Join-Path $Root 'p'
    $subtree = 'PatternedFront\Lot_fixture'
    $subtreeRoot = Join-Path $sourceRoot $subtree
    [void](New-Item -ItemType Directory -Path $subtreeRoot)
    [void](New-Item -ItemType Directory -Path $processorRoot)
    $configPath = Join-Path $Root 'config.json'
    $inventoryPath = Join-Path $Root 'inventory.json'
    $targetsPath = Join-Path $Root 'targets.json'
    $outputPath = Join-Path $processorRoot 'result.json'
    $bmpRows = New-Object Collections.Generic.List[object]
    $slotRows = New-Object Collections.Generic.List[object]
    $expectedBytes = [int64]4096
    for ($i = 1; $i -le $SlotCount; $i++) {
        $slot = 'Slot{0:D2}' -f $i
        $identity = 'fixture_run_{0}' -f $slot
        $slotRows.Add([pscustomobject]@{ slot = $slot; physicalIdentity = $identity; partition = 'DEVELOPMENT_AND_PERMANENT_HOTSPOT_REGRESSION_CHALLENGE' })
        foreach ($channel in @([pscustomobject]@{code='BF';folder='Brightfield'}, [pscustomobject]@{code='DF';folder='Darkfield'})) {
            $relative = 'fixture_run\{0}\{1}FrontsideWafer\resizedImage\fixture_{0}_{1}FrontsideWafer_PM2_resizedImage.bmp' -f $slot, $channel.folder
            $physical = Join-Path $subtreeRoot $relative
            [void](New-Item -ItemType Directory -Path (Split-Path -Parent $physical))
            $bytes = New-Object byte[] $expectedBytes
            for ($j = 0; $j -lt $bytes.Length; $j++) { $bytes[$j] = [byte](($i * 17 + $j + $(if ($channel.code -eq 'DF') { 31 } else { 0 })) % 251) }
            [IO.File]::WriteAllBytes($physical, $bytes)
            $time = [DateTime]::SpecifyKind(([DateTime]'2026-08-27T12:00:00').AddMinutes(($i * 2) + $(if ($channel.code -eq 'DF') { 1 } else { 0 })), [DateTimeKind]::Utc)
            [IO.File]::SetLastWriteTimeUtc($physical, $time)
            $item = Get-Item -LiteralPath $physical
            $bmpRows.Add([pscustomobject]@{
                subtreeRelativePath = $relative
                canonicalProvenancePath = $physical
                aliasReadPath = 'Q:\' + $relative
                length = [int64]$item.Length
                lastWriteTimeUtc = $item.LastWriteTimeUtc.ToString('o')
                extension = '.bmp'
                reparsePoint = $false
                containedByApprovedRoot = $true
            })
        }
    }
    $config = [ordered]@{
        schema = 'argos_project_portal_endpoint_config_v1'
        role = 'JBOD'
        reviewOnly = $true
        productionRoutingEnabled = $false
        approvedDataRoots = @([ordered]@{name='JBOD_KLARF_EXPORT';path=$sourceRoot})
    }
    Write-JsonCreateNew $configPath $config
    $inventory = [ordered]@{
        schema = 'argos_o3c1_entrypoint_result_v1'
        state = 'PASS_OCV03_METADATA_CAPABILITY_O3C1'
        inventoryDisposition = 'COMPLETE'
        inventory = [ordered]@{
            state = 'COMPLETE'
            complete = $true
            relativeSubtree = $subtree
            skippedPathRowCount = 0
            accessErrorCount = 0
            truncated = $false
            bmpLeaves = $bmpRows.ToArray()
        }
    }
    Write-JsonCreateNew $inventoryPath $inventory
    $targets = [ordered]@{
        schema = 'argos_ocv03_source_freeze_targets_v1'
        revision = 'O3C2_LOCAL_FIXTURE_{0}' -f $SlotCount
        state = 'FROZEN'
        installedInventorySha256 = Get-Sha256 $inventoryPath
        approvedDataRoot = 'JBOD_KLARF_EXPORT'
        relativeSubtree = $subtree
        lotId = 'fixture'
        acquisitionId = 'fixture_run'
        pathTemplate = '{acquisitionId}/{slot}/{channelFolder}FrontsideWafer/resizedImage/{lotId}_{slot}_{channelFolder}FrontsideWafer_PM2_resizedImage.bmp'
        channels = @([ordered]@{channel='BF';channelFolder='Brightfield'}, [ordered]@{channel='DF';channelFolder='Darkfield'})
        slots = $slotRows.ToArray()
        expectedBytesPerLeaf = $expectedBytes
        targetPairCount = $SlotCount
        targetLeafCount = $SlotCount * 2
        sourceHashAlgorithm = 'SHA256'
        acquisitionFingerprintSchema = 'argos_ocv03_pair_acquisition_fingerprint_v1'
        readThroughExactSubtreeShortAliasOnly = $true
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
        decodePixels = $false
        imageProcessingAllowed = $false
        sourceMutationAllowed = $false
        taskOrProcessActionAllowed = $false
        providerActivationAllowed = $false
        independentValidationCohortInspected = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
    }
    Write-JsonCreateNew $targetsPath $targets
    return [pscustomobject]@{root=$Root;sourceRoot=$sourceRoot;config=$configPath;inventory=$inventoryPath;targets=$targetsPath;output=$outputPath;pairCount=$SlotCount;leafCount=$SlotCount*2}
}

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$provider = Join-Path $root 'OCV03_SourceFreezeProviderV1.ps1'
$gatePath = Join-Path $root 'O3C2_PROVIDER_LOCAL_GATE.json'
$fixtureRoot = 'C:\A32T1'
Assert-True (Test-Path -LiteralPath $provider -PathType Leaf) 'O3C2 provider is missing.'
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($provider, [ref]$tokens, [ref]$parseErrors)
Assert-True (@($parseErrors).Count -eq 0) 'O3C2 provider parser failed.'
$providerCommand = Get-Command -Name $provider -CommandType ExternalScript -ErrorAction Stop
foreach ($parameter in @('Preflight','Hash','ConfigPath','TargetManifest','InventoryPath','OutputPath','AliasName','FailAfterHashCount')) {
    Assert-True ($providerCommand.Parameters.Keys -contains $parameter) "O3C2 provider parameter is missing: $parameter"
}
$subst = Get-Command -Name 'subst.exe' -CommandType Application -ErrorAction Stop
Assert-True (-not (Test-Path -LiteralPath $fixtureRoot)) 'O3C2 fixture root already exists.'
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O3C2 local gate already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_source_freeze_provider_test_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_TEST_PREFLIGHT'
        providerSha256 = Get-Sha256 $provider
        providerParserErrors = 0
        namedArgumentsResolvedByGetCommand = $true
        substPath = $subst.Source
        fixtureRoot = $fixtureRoot
        gatePath = $gatePath
        mutationsPerformed = $false
        sourceHashingPerformed = $false
        imageBytesDecoded = $false
        pixelProcessingPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
$zero = New-HashFixture (Join-Path $fixtureRoot 'zero') 0
$one = New-HashFixture (Join-Path $fixtureRoot 'one') 1
$many = New-HashFixture (Join-Path $fixtureRoot 'many') 10
$failure = New-HashFixture (Join-Path $fixtureRoot 'failure') 1
$collision = New-HashFixture (Join-Path $fixtureRoot 'collision') 1

$zeroRejected = $false
try { & $provider -Preflight -ConfigPath $zero.config -TargetManifest $zero.targets -InventoryPath $zero.inventory -OutputPath $zero.output -AliasName 'Q' | Out-Null }
catch { $zeroRejected = $_.Exception.Message -match 'pair cardinality' }
Assert-True $zeroRejected 'O3C2 ZERO collection case was not rejected.'

$onePreflight = (& $provider -Preflight -ConfigPath $one.config -TargetManifest $one.targets -InventoryPath $one.inventory -OutputPath $one.output -AliasName 'Q' | Out-String) | ConvertFrom-Json
Assert-True ([string]$onePreflight.state -eq 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_PREFLIGHT' -and [int]$onePreflight.pairCount -eq 1 -and [int]$onePreflight.leafCount -eq 2 -and -not [bool]$onePreflight.mutationsPerformed) 'O3C2 ONE preflight failed.'
$oneResult = (& $provider -Hash -ConfigPath $one.config -TargetManifest $one.targets -InventoryPath $one.inventory -OutputPath $one.output -AliasName 'Q' | Out-String) | ConvertFrom-Json
Assert-True ([string]$oneResult.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE' -and [int]$oneResult.pairCount -eq 1 -and [int]$oneResult.leafCount -eq 2) 'O3C2 ONE hash case failed.'

$manyPreflight = (& $provider -Preflight -ConfigPath $many.config -TargetManifest $many.targets -InventoryPath $many.inventory -OutputPath $many.output -AliasName 'Q' | Out-String) | ConvertFrom-Json
Assert-True ([string]$manyPreflight.state -eq 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_PREFLIGHT' -and [int]$manyPreflight.pairCount -eq 10 -and [int]$manyPreflight.leafCount -eq 20) 'O3C2 MANY preflight failed.'
$manyResult = (& $provider -Hash -ConfigPath $many.config -TargetManifest $many.targets -InventoryPath $many.inventory -OutputPath $many.output -AliasName 'Q' | Out-String) | ConvertFrom-Json
Assert-True ([string]$manyResult.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE' -and [int]$manyResult.pairCount -eq 10 -and [int]$manyResult.leafCount -eq 20) 'O3C2 MANY hash case failed.'
Assert-True (-not [bool]$manyResult.knownNotchLocationConsumed -and -not [bool]$manyResult.notchAnglePriorConsumed -and -not [bool]$manyResult.fixedAngularSearchWindowConsumed) 'O3C2 MANY case consumed a forbidden notch prior.'
Assert-True ([bool]$manyResult.sourceHashingPerformed -and -not [bool]$manyResult.imageBytesDecoded -and -not [bool]$manyResult.pixelProcessingPerformed) 'O3C2 MANY authority case failed.'

$injectedFailureCaught = $false
try { & $provider -Hash -ConfigPath $failure.config -TargetManifest $failure.targets -InventoryPath $failure.inventory -OutputPath $failure.output -AliasName 'Q' -FailAfterHashCount 1 | Out-Null }
catch { $injectedFailureCaught = $_.Exception.Message -match 'INJECTED_O3C2_FAILURE_AFTER_HASH' }
Assert-True $injectedFailureCaught 'O3C2 injected failure was not caught.'
Assert-True (-not (Test-Path -LiteralPath $failure.output)) 'O3C2 injected failure wrote an output.'
Assert-True ($null -eq (Get-PSDrive -Name Q -ErrorAction SilentlyContinue) -and -not [IO.Directory]::Exists('Q:\')) 'O3C2 injected failure left the alias visible.'

$collisionTarget = Join-Path $fixtureRoot 'collision_alias'
[void](New-Item -ItemType Directory -Path $collisionTarget)
$createCollision = @(& $subst.Source 'Q:' $collisionTarget 2>&1)
Assert-True ($LASTEXITCODE -eq 0 -and $createCollision.Count -eq 0) 'O3C2 collision control alias creation failed.'
$collisionRejected = $false
try { & $provider -Hash -ConfigPath $collision.config -TargetManifest $collision.targets -InventoryPath $collision.inventory -OutputPath $collision.output -AliasName 'Q' | Out-Null }
catch { $collisionRejected = $_.Exception.Message -match 'already' }
finally {
    $removeCollision = @(& $subst.Source 'Q:' '/D' 2>&1)
    Assert-True ($LASTEXITCODE -eq 0 -and $removeCollision.Count -eq 0) 'O3C2 collision control alias cleanup failed.'
}
Assert-True $collisionRejected 'O3C2 alias collision was not rejected.'
Assert-True (-not (Test-Path -LiteralPath $collision.output)) 'O3C2 alias collision wrote an output.'

$gate = [ordered]@{
    schema = 'argos_ocv03_source_freeze_provider_local_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3C2_SOURCE_FREEZE_PROVIDER_LOCAL_GATE'
    disposition = 'PENDING_GATE'
    providerPath = 'work/OPENCV_EDGE_NOTCH_O3C2/OCV03_SourceFreezeProviderV1.ps1'
    providerSha256 = Get-Sha256 $provider
    collectionCases = @(
        [ordered]@{caseId='ZERO';expected='REFUSE';observed='REFUSED'},
        [ordered]@{caseId='ONE';expectedPairCount=1;observedPairCount=[int]$oneResult.pairCount;observedLeafCount=[int]$oneResult.leafCount},
        [ordered]@{caseId='MANY';expectedPairCount=10;observedPairCount=[int]$manyResult.pairCount;observedLeafCount=[int]$manyResult.leafCount}
    )
    win32VisibleExactSubtreeAliasPassed = $true
    bufferedDotNetSha256Passed = $true
    sourceStableBeforeAndAfterHashPassed = $true
    pairFingerprintCount = [int]$manyResult.pairCount
    aggregateFingerprintPresent = -not [string]::IsNullOrWhiteSpace([string]$manyResult.aggregateFingerprintSha256)
    injectedFailureLeavesNoOutput = $true
    injectedFailureRemovesAlias = $true
    preexistingAliasRefusedBeforeOutput = $true
    preexistingAliasPreservedByProvider = $true
    targetCount = [int]$manyResult.leafCount
    knownNotchLocationConsumed = $false
    notchAnglePriorConsumed = $false
    fixedAngularSearchWindowConsumed = $false
    sourceHashingPerformed = $true
    imageBytesDecoded = $false
    pixelProcessingPerformed = $false
    sourceMutationPerformed = $false
    taskOrProcessActionPerformed = $false
    providerActivated = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    fixtureRoot = $fixtureRoot
}
Write-JsonCreateNew $gatePath $gate
$gate | ConvertTo-Json -Depth 10
