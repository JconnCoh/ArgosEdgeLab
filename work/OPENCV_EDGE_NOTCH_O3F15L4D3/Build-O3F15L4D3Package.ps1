#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build,
    [string]$PackageRoot = 'C:\O3F15L4D3PK'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

function Write-NewUtf8Json([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "Refusing existing output: $Path"
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($Value | ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes($Path, $bytes)
}

Require (($Preflight -and -not $Build) -or ($Build -and -not $Preflight)) 'Select exactly one of -Preflight or -Build.'

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$d2 = [IO.Path]::GetFullPath($PSScriptRoot)
$root = [IO.Path]::GetFullPath($PackageRoot)
Require ($root -ceq 'C:\O3F15L4D3PK') 'O3F15L4D3 package root changed.'

$contractPath = Join-Path $d2 'O3F15L4D3_DIAGNOSTIC_CONTRACT.json'
$definitionPath = Join-Path $d2 'MAINTENANCE_DEFINITION.json'
$intentPath = Join-Path $d2 'O3F15L4D3_RECOVERY_INTENT.json'
$intentGatePath = Join-Path $d2 'O3F15L4D3_RECOVERY_INTENT_GATE.json'
$routeInventoryPath = Join-Path $d2 'O3F15L4D3_ROUTE_CAPABILITY_INVENTORY.json'
foreach ($path in @($contractPath, $definitionPath, $intentPath, $intentGatePath, $routeInventoryPath)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "Required D2 input is absent: $path"
}

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$intentGate = Get-Content -LiteralPath $intentGatePath -Raw | ConvertFrom-Json
$routeInventory = Get-Content -LiteralPath $routeInventoryPath -Raw | ConvertFrom-Json

Require ([string]$contract.schema -ceq 'argos_ocv03_o3f15l4d3_diagnostic_contract_v1' -and [string]$contract.revision -ceq 'O3F15L4D3') 'D2 diagnostic contract identity changed.'
Require ([string]$definition.schema -ceq 'argos_maintenance_definition_v1' -and [string]$definition.revision -ceq 'O3F15L4D3') 'D2 maintenance definition identity changed.'
$isDraft = [string]$contract.lifecycle -ceq 'DRAFT' -and [string]$contract.state -ceq 'DRAFT_O3F15L4D3_METADATA_DIAGNOSTIC_CONTRACT' -and [string]$definition.lifecycle -ceq 'DRAFT' -and [string]$definition.state -ceq 'DRAFT_O3F15L4D3_MAINTENANCE_DEFINITION'
$isFrozen = [string]$contract.lifecycle -ceq 'FROZEN' -and [string]$contract.state -ceq 'FROZEN_O3F15L4D3_METADATA_DIAGNOSTIC_CONTRACT' -and [string]$definition.lifecycle -ceq 'FROZEN' -and [string]$definition.state -ceq 'FROZEN_O3F15L4D3_MAINTENANCE_DEFINITION'
Require ($isDraft -or $isFrozen) 'D2 contract and definition lifecycle pairing changed.'
if ($Build) { Require $isFrozen 'The sole build requires the once-frozen D2 contract and definition.' }

Require ([string]$intentGate.state -ceq 'PASS_ARGOS_RECOVERY_INTENT') 'D2 recovery-intent gate is not PASS.'
Require ((Get-Sha256 $intentPath) -ceq [string]$contract.routePins.recoveryIntentSha256) 'D2 recovery-intent pin changed.'
Require ((Get-Sha256 $intentGatePath) -ceq [string]$contract.routePins.recoveryIntentGateSha256) 'D2 recovery-intent-gate pin changed.'
Require ((Get-Sha256 $routeInventoryPath) -ceq [string]$contract.routePins.routeCapabilityInventorySha256) 'D2 route inventory pin changed.'
Require ([string]$routeInventory.endpointWorker.sha256 -ceq [string]$contract.routePins.endpointWorkerSha256 -and [string]$routeInventory.installedConfigEvidence.sha256 -ceq [string]$contract.routePins.installedRouteConfigEvidenceSha256 -and [string]$routeInventory.qualifiedQueueSafetyGate.sha256 -ceq [string]$contract.routePins.queueSafetyGateSha256) 'D2 inherited route pins disagree.'

$endpointWorker = Join-Path $project ([string]$routeInventory.endpointWorker.path)
$installedConfigEvidence = Join-Path $project ([string]$routeInventory.installedConfigEvidence.path)
$queueSafetyGate = Join-Path $project ([string]$routeInventory.qualifiedQueueSafetyGate.path)
Require ((Get-Sha256 $endpointWorker) -ceq [string]$contract.routePins.endpointWorkerSha256) 'Endpoint worker bytes changed.'
Require ((Get-Sha256 $installedConfigEvidence) -ceq [string]$contract.routePins.installedRouteConfigEvidenceSha256) 'Installed route evidence bytes changed.'
Require ((Get-Sha256 $queueSafetyGate) -ceq [string]$contract.routePins.queueSafetyGateSha256) 'Queue-safety evidence bytes changed.'
$memoryPath = Join-Path $project ([string]$contract.pins.failurePreventionMemory.path)
Require ((Get-Sha256 $memoryPath) -ceq [string]$contract.pins.failurePreventionMemory.sha256) 'Failure-prevention memory pin changed.'

Require (@($contract.payloadFiles).Count -eq 17) 'D2 payload pin count changed.'
Require (@($contract.payloadFiles.relativePath | Sort-Object -Unique).Count -eq 17) 'D2 payload names are not unique.'
Require ([int]$contract.child.maximumCount -eq 1 -and [string]$contract.child.executable -ceq 'D:/AFCV1/rt/python.exe' -and [string]::Join('|', @($contract.child.arguments)) -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT' -and [int]$contract.child.timeoutSeconds -eq 600) 'D2 sole-child contract changed.'
Require ([int64]$contract.child.maximumCombinedStdoutStderrBytes -eq 5242880 -and [int64]$contract.classification.maximumSerializedCoreBytes -eq 4194304 -and [int64]$contract.response.maximumEmittedJsonBytes -eq 7340032 -and [int64]$contract.response.maximumConstructedResponseBytes -eq 8388608) 'D2 byte limits changed.'
Require ([int]$contract.classification.pairCount -eq 978 -and [int]$contract.classification.identityCount -eq 978 -and [int]$contract.classification.sourceLeafCount -eq 1956 -and [int]$contract.classification.uniqueOrderedSourceLeafCount -eq 1956) 'D2 frozen-corpus cardinality changed.'
Require ([bool]$contract.prohibitions.selfTest -and [bool]$contract.prohibitions.focusedTestLive -and [bool]$contract.prohibitions.gate -and [bool]$contract.prohibitions.run -and [bool]$contract.prohibitions.qSubst -and [bool]$contract.prohibitions.detectorResultRoot -and [bool]$contract.prohibitions.imageRead -and [bool]$contract.prohibitions.backgroundLaunch -and [bool]$contract.prohibitions.sourceMutation -and [bool]$contract.prohibitions.taskOrExistingProcessAction -and [bool]$contract.prohibitions.providerActivation -and [bool]$contract.prohibitions.thresholdOrSelectorChange -and [bool]$contract.prohibitions.holdClearance -and [bool]$contract.prohibitions.retry) 'D2 prohibitions changed.'
Require ([int]$contract.holds.fullFrontside -eq 184 -and [int]$contract.holds.patternedFront -eq 12 -and [bool]$contract.holds.slot02MultipleCandidateAmbiguity -and [bool]$contract.holds.slot16RareHotspot -and [bool]$contract.holds.laterPrerequisitesPreserved) 'D2 hold preservation changed.'
Require ([bool]$contract.reviewOnly -and -not [bool]$contract.trainingEligible -and -not [bool]$contract.xmlEligible -and -not [bool]$contract.productionEligible -and -not [bool]$contract.productionRoutingEnabled) 'D2 authority widened.'

Require ([string]$definition.entrypoint -ceq 'Invoke-O3F15L4D3.ps1' -and [int]$definition.timeoutSeconds -eq 630 -and [int64]$definition.maximumResultBytes -eq 8388608) 'D2 maintenance execution bounds changed.'
Require (@($definition.installedFiles).Count -eq 1 -and [string]$definition.installedFiles[0].source -ceq 'OCV03_NotchReviewOpenCvV1.py' -and [string]$definition.installedFiles[0].destination -ceq 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py') 'D2 same-byte carrier definition changed.'
Require ([bool]$definition.installedFiles[0].sameBytesOnly -and -not [bool]$definition.installedFiles[0].allowCreate -and [string]$definition.installedFiles[0].expectedInstalledSha256 -ceq '6B7CC6E643265545297BA4DED1E6B37AB262349572194B13F79264EF77D8DCE4' -and @($definition.installedFiles[0].approvedPredecessorSha256).Count -eq 1 -and [string]$definition.installedFiles[0].approvedPredecessorSha256[0] -ceq [string]$definition.installedFiles[0].expectedInstalledSha256) 'D2 carrier is not exact same-byte/idempotent-only.'
Require ([int]$definition.ownedChild.maximumCount -eq 1 -and [string]$definition.ownedChild.executable -ceq [string]$contract.child.executable -and [string]::Join('|', @($definition.ownedChild.arguments)) -ceq [string]::Join('|', @($contract.child.arguments))) 'D2 definition child contract changed.'
Require ([bool]$definition.reviewOnly -and -not [bool]$definition.trainingEligible -and -not [bool]$definition.xmlEligible -and -not [bool]$definition.productionEligible -and -not [bool]$definition.productionRoutingEnabled -and -not [bool]$definition.automaticRetry) 'D2 definition authority widened.'

$sourceMap = [ordered]@{
    'Invoke-O3F15L4D3.ps1' = 'work/OPENCV_EDGE_NOTCH_O3F15L4D3/Invoke-O3F15L4D3.ps1'
    'O3F15L4D3DiagnosticFixture.py' = 'work/OPENCV_EDGE_NOTCH_O3F15L4D3/O3F15L4D3DiagnosticFixture.py'
    'Run-O3F15L4FrontReconcile.py' = 'work/OPENCV_EDGE_NOTCH_O3F15L4D3/Run-O3F15L4FrontReconcile.py'
    'Test-O3F15L4PathHolds.py' = 'work/OPENCV_EDGE_NOTCH_O3F15L4D3/Test-O3F15L4PathHolds.py'
    'Run-O3F15FrontReconcile.py' = 'work/O3F8/Run-O3F15FrontReconcile.py'
    'Test-O3F15FrontReconcile.py' = 'work/O3F8/Test-O3F15FrontReconcile.py'
    'Run-O3F8Staged.py' = 'work/O3F8/Run-O3F8Staged.py'
    'Run-O3F14Staged.py' = 'work/O3F8/Run-O3F14Staged.py'
    'FullPerimeterWaferTopologyOpenCvR11.py' = 'work/O3F8/FullPerimeterWaferTopologyOpenCvR11.py'
    'FullPerimeterWaferTopologyOpenCvR9.py' = 'work/O3F8/FullPerimeterWaferTopologyOpenCvR9.py'
    'FullPerimeterWaferTopologyOpenCvR8.py' = 'work/O3F8/bundle_verify_r4/FullPerimeterWaferTopologyOpenCvR8.py'
    'Detect-O3P8FrontSplitNotches.py' = 'work/OPENCV_EDGE_NOTCH_O3P8/Detect-O3P8FrontSplitNotches.py'
    'Test-O3F14R11SeedAngles.py' = 'work/O3F8/Test-O3F14R11SeedAngles.py'
    'O3P8_POST2_SHORT_ALIAS_JOB.json' = 'work/OPENCV_EDGE_NOTCH_O3P8/O3P8_POST2_SHORT_ALIAS_JOB.json'
    'O3M9_SLOT16_JOB.json' = 'work/OPENCV_EDGE_NOTCH_O3M9/O3M9_SLOT16_JOB.json'
    'O3F12_DEV6_SOURCE_ALIAS_PLAN.json' = 'work/OPENCV_EDGE_NOTCH_O3F12/O3F12_DEV6_SOURCE_ALIAS_PLAN.json'
    'OCV03_NotchReviewOpenCvV1.py' = 'work/OPENCV_EDGE_NOTCH_O3K1/OCV03_NotchReviewOpenCvV1.py'
}
Require ($sourceMap.Count -eq 17) 'D2 source map count changed.'
$sourceRows = New-Object Collections.Generic.List[object]
foreach ($pin in @($contract.payloadFiles)) {
    $name = [string]$pin.relativePath
    Require ($sourceMap.Contains($name)) "Unmapped D2 payload name: $name"
    Require (-not [IO.Path]::IsPathRooted($name) -and $name -notmatch '[\\/]' -and $name -notmatch '^\.') "Unsafe D2 payload name: $name"
    $source = Join-Path $project ([string]$sourceMap[$name])
    Require (Test-Path -LiteralPath $source -PathType Leaf) "D2 payload source is absent: $source"
    $hash = Get-Sha256 $source
    Require ($hash -ceq [string]$pin.sha256) "D2 payload source hash changed: $name"
    $sourceRows.Add([pscustomobject]@{ name=$name; source=$source; bytes=[int64](Get-Item -LiteralPath $source).Length; sha256=$hash })
}
$contractHash = Get-Sha256 $contractPath
$sources = @($sourceRows.ToArray()) + @([pscustomobject]@{ name='O3F15L4D3_DIAGNOSTIC_CONTRACT.json'; source=$contractPath; bytes=[int64](Get-Item -LiteralPath $contractPath).Length; sha256=$contractHash })
Require ($sources.Count -eq 18 -and @($sources.name | Sort-Object -Unique).Count -eq 18) 'D2 built-payload cardinality changed.'

$partial = Join-Path $root 'build.partial'
$ready = Join-Path $root 'build.ready'
$payloadRoot = Join-Path $partial 'payload'
$definitionTarget = Join-Path $partial 'MAINTENANCE_DEFINITION.json'
$buildGateTarget = Join-Path $partial 'O3F15L4D3_BUILD_GATE.json'
$longest = @($sources | Sort-Object { ([string]$_.name).Length } -Descending | Select-Object -First 1)[0].name
$planned = @($root, $partial, $ready, $payloadRoot, $definitionTarget, $buildGateTarget, (Join-Path $payloadRoot $longest))
$pathGate = & (Join-Path $project 'utilities/Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'D2 short build-root path gate failed.'
Require (-not (Test-Path -LiteralPath $root)) 'D2 one-shot package root already exists.'

if ($Preflight) {
    [ordered]@{
        schema='argos_ocv03_o3f15l4d3_build_preflight_v1'
        state=$(if ($isFrozen) { 'PASS_O3F15L4D3_BUILD_PREFLIGHT_FROZEN' } else { 'PASS_O3F15L4D3_BUILD_PREFLIGHT_DRAFT' })
        lifecycle=[string]$contract.lifecycle
        buildAuthorizedNow=[bool]$isFrozen
        payloadPinCount=17
        packagedPayloadCount=18
        contractSha256=$contractHash
        definitionSha256=Get-Sha256 $definitionPath
        recoveryIntentSha256=Get-Sha256 $intentPath
        recoveryIntentGateSha256=Get-Sha256 $intentGatePath
        endpointWorkerSha256=Get-Sha256 $endpointWorker
        pathState=[string]$pathGate.state
        buildRoot=$root
        buildCount=0
        targetExecuted=$false
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $payloadRoot -Force)
foreach ($row in $sources) {
    [IO.File]::Copy([string]$row.source, (Join-Path $payloadRoot ([string]$row.name)), $false)
}
[IO.File]::Copy($definitionPath, $definitionTarget, $false)
$actual = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
Require ($actual.Count -eq 18) 'D2 copied-payload count changed.'
foreach ($row in $sources) {
    $target = Join-Path $payloadRoot ([string]$row.name)
    Require ((Get-Item -LiteralPath $target).Length -eq [int64]$row.bytes -and (Get-Sha256 $target) -ceq [string]$row.sha256) "D2 copied payload changed: $($row.name)"
}
$builtFiles = @($actual | ForEach-Object { [ordered]@{path=$_.Name;bytes=[int64]$_.Length;sha256=Get-Sha256 $_.FullName} })
$gate = [ordered]@{
    schema='argos_ocv03_o3f15l4d3_build_gate_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_O3F15L4D3_UNSIGNED_METADATA_DIAGNOSTIC_PACKAGE_BUILT'
    lifecycle='FROZEN'
    buildCount=1
    buildRoot=$ready
    payloadPinCount=17
    payloadFileCount=18
    payloadFiles=$builtFiles
    contractSha256=$contractHash
    definitionSha256=Get-Sha256 $definitionTarget
    recoveryIntentSha256=Get-Sha256 $intentPath
    recoveryIntentGateSha256=Get-Sha256 $intentGatePath
    routeCapabilityInventorySha256=Get-Sha256 $routeInventoryPath
    endpointWorkerSha256=[string]$contract.routePins.endpointWorkerSha256
    installedRouteConfigEvidenceSha256=[string]$contract.routePins.installedRouteConfigEvidenceSha256
    queueSafetyGateSha256=[string]$contract.routePins.queueSafetyGateSha256
    carrierSha256=[string]$definition.installedFiles[0].expectedInstalledSha256
    maximumResultBytes=[int64]$definition.maximumResultBytes
    maximumOwnedChildCount=1
    exactChildArguments=@($contract.child.arguments)
    fullFrontsideHoldCount=184
    patternedFrontHoldCount=12
    pathState=[string]$pathGate.state
    signed=$false
    published=$false
    targetExecuted=$false
    imageBytesRead=$false
    mutationsPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}
Write-NewUtf8Json $buildGateTarget $gate
Move-Item -LiteralPath $partial -Destination $ready
$gate | ConvertTo-Json -Depth 10
