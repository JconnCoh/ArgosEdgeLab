#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L3 create-new JSON exists: $Path"
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine),
        (New-Object Text.UTF8Encoding($false))
    )
}

Require (([bool]$Preflight) -xor ([bool]$Build)) 'Specify exactly one of -Preflight or -Build.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath = Join-Path $PSScriptRoot 'O3F15L3_DIAGNOSTIC_CONTRACT.json'
$definitionSource = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$intentPath = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3F15L2\O3F15L3_RECOVERY_INTENT.json'
$intentGatePath = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3F15L2\O3F15L3_RECOVERY_INTENT_GATE.json'
$contractHash = 'B548FCBE7245F6CF376F10294583022E9F0F28CAF8037D4C5C4C559EE4481015'
$definitionHash = '152B5156EF007098305B92240E8DEEC8A51C17813EB01A0EE42CA5A17A01F719'
$intentHash = '9863D76D28988595EDC11C8745B6E2C1263380FECABA1C26AFD65CAD1A9818C9'
$intentGateHash = '4D0F8D767F509D150EFE1AAC5DFEFD9ADDB3AEAB23BBA4AA7259F45E9D4CE000'
$root = 'C:\O3F15L3PK'
$payloadRoot = Join-Path $root 'payload'
$definitionTarget = Join-Path $root 'DEFINITION.json'
$gatePath = Join-Path $PSScriptRoot 'O3F15L3_BUILD_GATE.json'

foreach ($path in @($contractPath, $definitionSource, $intentPath, $intentGatePath)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 build dependency absent: $path"
}
Require ((Sha $contractPath) -ceq $contractHash) 'O3F15L3 diagnostic contract changed.'
Require ((Sha $definitionSource) -ceq $definitionHash) 'O3F15L3 maintenance definition changed.'
Require ((Sha $intentPath) -ceq $intentHash -and (Sha $intentGatePath) -ceq $intentGateHash) 'O3F15L3 recovery authority changed.'

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionSource -Raw | ConvertFrom-Json
$intent = Get-Content -LiteralPath $intentPath -Raw | ConvertFrom-Json
$intentGate = Get-Content -LiteralPath $intentGatePath -Raw | ConvertFrom-Json
Require ([string]$contract.schema -ceq 'argos_ocv03_o3f15l3_diagnostic_contract_v1' -and [string]$contract.state -ceq 'FROZEN_FOR_BUILD') 'O3F15L3 diagnostic contract is not frozen.'
Require ([string]$definition.schema -ceq 'argos_ocv03_o3f15l3_maintenance_definition_v1' -and [string]$definition.state -ceq 'FROZEN_FOR_SIGNING' -and [string]$definition.entryPoint -ceq 'payload/Invoke-O3F15L3.ps1') 'O3F15L3 maintenance definition is not frozen.'
Require ([string]$intentGate.state -ceq 'PASS_ARGOS_RECOVERY_INTENT' -and [string]$intent.mode -ceq 'MUTATE' -and [bool]$intent.mutation.singleMutationAttemptAuthorized) 'O3F15L3 recovery intent is not executable.'
Require ([int]$intent.preservedHolds.fullFrontsideHoldCount -eq 184 -and [int]$intent.preservedHolds.currentPatternedFrontHoldCount -eq 12 -and [bool]$intent.preservedHolds.slot02MultipleCandidateAmbiguity -and [bool]$intent.preservedHolds.rareHotspotSlot16) 'O3F15L3 preserved hold contract changed.'
Require ([int]$contract.maximumOwnedChildCount -eq 1 -and [string]::Join('|', @($contract.childArguments)) -ceq '-I|-B|Run-O3F15FrontReconcile.py|PREFLIGHT') 'O3F15L3 sole-child contract changed.'
Require (-not [bool]$contract.selfTestAllowed -and -not [bool]$contract.focusedTestAllowed -and -not [bool]$contract.gateAllowed -and -not [bool]$contract.runAllowed -and -not [bool]$contract.resultRootCreationAllowed -and -not [bool]$contract.imageBytesReadAllowed) 'O3F15L3 authority widened.'
Require (@($definition.changes).Count -eq 1 -and @($definition.entryPointMutations).Count -eq 0 -and @($definition.entryPointOutputs).Count -eq 0 -and @($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'O3F15L3 maintenance bounds changed.'
Require ([string]$definition.allowedProcessActions[0] -ceq 'START_EXACTLY_ONE_BOUNDED_OWNED_O3F15_PREFLIGHT_CHILD_ONLY' -and -not [bool]$definition.requestRetryAuthorized) 'O3F15L3 process or retry authority changed.'

$rows = New-Object Collections.Generic.List[object]
foreach ($record in @($contract.payloadFiles)) {
    $name = [string]$record.name
    $source = Join-Path $project ([string]$record.source)
    Require (-not [string]::IsNullOrWhiteSpace($name) -and -not [IO.Path]::IsPathRooted($name) -and $name -notmatch '[\\/]' -and $name -notmatch '^\.') "O3F15L3 unsafe payload name: $name"
    Require (Test-Path -LiteralPath $source -PathType Leaf) "O3F15L3 payload source absent: $source"
    $hash = Sha $source
    Require ($hash -ceq [string]$record.sha256) "O3F15L3 payload source changed: $name"
    $rows.Add([pscustomobject]@{ path = $name; source = $source; bytes = [int64](Get-Item -LiteralPath $source).Length; sha256 = $hash })
}
$rows.Add([pscustomobject]@{ path = 'O3F15L3_DIAGNOSTIC_CONTRACT.json'; source = $contractPath; bytes = [int64](Get-Item -LiteralPath $contractPath).Length; sha256 = $contractHash })
$sources = $rows.ToArray()
Require ($sources.Count -eq 16 -and @($sources.path | Sort-Object -Unique).Count -eq 16) 'O3F15L3 payload cardinality or uniqueness changed.'
foreach ($name in @('Invoke-O3F15L3.ps1', 'O3F15L3_DIAGNOSTIC_CONTRACT.json', 'O3F15L3DiagnosticFixture.py', 'Run-O3F15FrontReconcile.py', 'FullPerimeterWaferTopologyOpenCvR11.py', 'OCV03_NotchReviewOpenCvV1.py')) {
    Require (@($sources | Where-Object { [string]$_.path -ceq $name }).Count -eq 1) "O3F15L3 required payload absent: $name"
}
foreach ($path in @($root, $gatePath)) {
    Require (-not (Test-Path -LiteralPath $path)) "O3F15L3 create-new build target exists: $path"
}
$longestName = @($sources | Sort-Object { ([string]$_.path).Length } -Descending | Select-Object -First 1)[0].path
$planned = @($root, $payloadRoot, $definitionTarget, $gatePath, (Join-Path $payloadRoot $longestName))
$pathGate = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'O3F15L3 local build path gate failed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f15l3_build_preflight_v1'
        state = 'PASS_O3F15L3_BUILD_PREFLIGHT'
        contractSha256 = $contractHash
        definitionSha256 = $definitionHash
        recoveryIntentSha256 = $intentHash
        payloadFileCount = $sources.Count
        maximumOwnedChildCount = 1
        exactStage = 'PREFLIGHT'
        fullFrontsideHoldCount = 184
        currentPatternedFrontHoldCount = 12
        pathState = [string]$pathGate.state
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $payloadRoot -Force)
foreach ($row in $sources) {
    [IO.File]::Copy([string]$row.source, (Join-Path $payloadRoot ([string]$row.path)), $false)
}
[IO.File]::Copy($definitionSource, $definitionTarget, $false)
$actual = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
Require ($actual.Count -eq 16) 'O3F15L3 built payload cardinality changed.'
$payloadFiles = @($actual | ForEach-Object { [ordered]@{ path = $_.Name; bytes = [int64]$_.Length; sha256 = Sha $_.FullName } })
$gate = [ordered]@{
    schema = 'argos_ocv03_o3f15l3_build_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3F15L3_UNSIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE_BUILT'
    buildRoot = $root
    payloadFileCount = $payloadFiles.Count
    payloadFiles = $payloadFiles
    contractSha256 = $contractHash
    definitionSha256 = Sha $definitionTarget
    entrySha256 = Sha (Join-Path $payloadRoot 'Invoke-O3F15L3.ps1')
    runnerSha256 = Sha (Join-Path $payloadRoot 'Run-O3F15FrontReconcile.py')
    detectorSha256 = Sha (Join-Path $payloadRoot 'FullPerimeterWaferTopologyOpenCvR11.py')
    carrierSha256 = Sha (Join-Path $payloadRoot 'OCV03_NotchReviewOpenCvV1.py')
    endpointWorkerSha256 = [string]$contract.inheritedRoute.endpointWorkerSha256
    installedRouteConfigEvidenceSha256 = [string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256
    queueSafetyGateSha256 = [string]$contract.inheritedRoute.queueSafetyGateSha256
    maximumOwnedChildCount = 1
    exactStage = 'PREFLIGHT'
    fullFrontsideHoldCount = 184
    currentPatternedFrontHoldCount = 12
    sameBytesCarrier = $true
    installedSemanticChange = $false
    taskActionCount = 0
    signed = $false
    published = $false
    targetExecuted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-NewJson $gatePath $gate
$gate | ConvertTo-Json -Depth 10
