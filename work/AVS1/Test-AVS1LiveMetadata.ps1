[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [string]$PayloadRoot,
    [string]$LiveSnapshotRoot = 'C:\L586R2\R_E3DAC141D1B8_20260821204234226_d8edfaff.ready\DATA_PULL_PAYLOAD\data\JBOD_PROCESSOR_REVIEW'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }
if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $resolvedPayloadRoot = Join-Path $PSScriptRoot 'payload' }
else { $resolvedPayloadRoot = [IO.Path]::GetFullPath($PayloadRoot) }

$inventoryPath = Join-Path $resolvedPayloadRoot 'Invoke-JbodAllWaferInventory.ps1'
$runnerPath = Join-Path $resolvedPayloadRoot 'Run-JbodAllWaferProcessor.ps1'
$processingPath = Join-Path $resolvedPayloadRoot 'Invoke-JbodAllWaferProcessingPass.ps1'
$dashboardPath = Join-Path $resolvedPayloadRoot 'Update-JbodDashboardManifest.ps1'
$trayPath = Join-Path $resolvedPayloadRoot 'Show-JbodAllWaferTray.ps1'
$overlayPath = Join-Path $LiveSnapshotRoot 'metadata\verified\ACTIVE_VERIFIED_METADATA_OVERLAY.json'
$catalogPath = Join-Path $LiveSnapshotRoot 'catalog\ALL_WAFER_CATALOG.json'
$ledgerPath = Join-Path $LiveSnapshotRoot 'processor\PROCESSING_LEDGER.json'
$manifestPath = Join-Path $LiveSnapshotRoot 'dashboard_manifest.json'
$required = @($runnerPath, $inventoryPath, $processingPath, $dashboardPath, $trayPath, $overlayPath, $catalogPath, $ledgerPath, $manifestPath)
foreach ($path in $required) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Live-metadata test input is missing: $path" }
}

function Get-ExactFunctionText {
    param([string]$ScriptPath, [string]$FunctionName)
    $tokens = $null
    $errors = $null
    $ast = [Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "PowerShell parse failed for $ScriptPath" }
    $matches = @($ast.FindAll({
        param($node)
        $node -is [Management.Automation.Language.FunctionDefinitionAst] -and
            [string]$node.Name -eq $FunctionName
    }, $true))
    if ($matches.Count -ne 1) { throw "Expected one $FunctionName definition in $ScriptPath; observed $($matches.Count)." }
    return [string]$matches[0].Extent.Text
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_avs1_live_metadata_test_preflight_v1'
        state = 'PASS_AVS1_LIVE_METADATA_TEST_PREFLIGHT'
        payloadFiles = 5
        liveSnapshotFiles = 4
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 4
    return
}

$parseRows = New-Object Collections.Generic.List[object]
foreach ($path in @($runnerPath, $inventoryPath, $processingPath, $dashboardPath, $trayPath)) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
    if (@($errors).Count -ne 0) { throw "PowerShell parse failed for $path" }
    $source = [IO.File]::ReadAllText($path)
    if ($source -match '(?im)\bWhere-Object[ \t]+[A-Za-z_][A-Za-z0-9_.]*[ \t]+-(?:eq|ne|gt|ge|lt|le)(?=[^\s\r\n])') {
        throw "Simplified Where-Object operator token adjacency remains in $path"
    }
    $parseRows.Add([pscustomobject]@{
        file = [IO.Path]::GetFileName($path)
        sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        parserErrors = 0
    })
}

. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $inventoryPath -FunctionName 'Normalize-AcquisitionKey')))
. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $inventoryPath -FunctionName 'Get-VerifiedMetadataOverlay')))
$script:MetadataOverlayPath = $overlayPath
$inventoryRows = Get-VerifiedMetadataOverlay
$inventoryCommand = Get-Command -Name $inventoryPath
$runnerSource = [IO.File]::ReadAllText($runnerPath)
if ($inventoryCommand.Parameters.Keys -contains 'MetadataSnapshotRoot' -or
    $runnerSource -match '(?m)^\s*-MetadataSnapshotRoot\b') {
    throw 'The corrected runner/inventory pair still carries the invalid MetadataSnapshotRoot argument contract.'
}

$overlay = Get-Content -LiteralPath $overlayPath -Raw | ConvertFrom-Json
$catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json
$ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
$dashboard = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$targetPrefix = '62631-586_20260819173317_'
$targetOverlayRows = @($overlay.rows | Where-Object { [string]$_.acquisitionKey -like ($targetPrefix + '*') })
if ($targetOverlayRows.Count -ne 10) { throw "Expected ten target verified rows; observed $($targetOverlayRows.Count)." }
if (@($targetOverlayRows | Where-Object { -not $inventoryRows.ContainsKey((Normalize-AcquisitionKey ([string]$_.acquisitionKey))) }).Count -ne 0) {
    throw 'The exact patched inventory function rejected one or more target verified rows.'
}

$catalogByPhysical = @{}
foreach ($acquisition in @($catalog.acquisitions)) {
    $key = [string]$acquisition.physicalIdentity.ToUpperInvariant()
    if (-not $catalogByPhysical.ContainsKey($key)) { $catalogByPhysical[$key] = New-Object Collections.Generic.List[object] }
    $catalogByPhysical[$key].Add($acquisition)
}
$joined = New-Object Collections.Generic.List[object]
foreach ($row in @($overlay.rows)) {
    $key = [string]$row.acquisitionKey.ToUpperInvariant()
    if (-not $catalogByPhysical.ContainsKey($key)) { continue }
    foreach ($acquisition in $catalogByPhysical[$key]) {
        $properties = [ordered]@{}
        foreach ($property in $row.PSObject.Properties) { $properties[$property.Name] = $property.Value }
        $properties.domain = [string]$acquisition.domain
        $properties.identity = [string]$acquisition.identity
        $properties.physicalIdentity = [string]$acquisition.physicalIdentity
        $joined.Add([pscustomobject]$properties)
    }
}

. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $processingPath -FunctionName 'Get-Sha256Text')))
. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $processingPath -FunctionName 'Get-OptionalPropertyText')))
. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $processingPath -FunctionName 'Reference-Family')))
$targetProcessingRows = @($joined | Where-Object {
    [string]$_.acquisitionKey -like ($targetPrefix + '*') -and [string]$_.domain -eq 'FRONTSIDE'
})
$targetFamilyRows = @($targetProcessingRows | ForEach-Object {
    [pscustomobject]@{ acquisitionKey = [string]$_.acquisitionKey; family = [string](Reference-Family $_) }
})
$targetFamilies = @($targetFamilyRows | ForEach-Object { [string]$_.family })
$emptyTargetFamilies = @($targetFamilyRows | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.family) })
if ($targetProcessingRows.Count -ne 10 -or $emptyTargetFamilies.Count -ne 0) {
    throw "The exact patched processor predicate did not accept all ten target live metadata rows: joined=$($targetProcessingRows.Count), empty=$(@($emptyTargetFamilies.acquisitionKey) -join ',')."
}
$nonFrontImageRows = @($joined | Where-Object {
    [string]$_.domain -ne 'FRONTSIDE' -and [string]$_.identityState -like 'IMAGE_CONFIRMED_*'
})
$nonFrontEligibleUnderHumanState = New-Object Collections.Generic.List[object]
$nonFrontImageAccepted = New-Object Collections.Generic.List[object]
foreach ($row in $nonFrontImageRows) {
    $properties = [ordered]@{}
    foreach ($property in $row.PSObject.Properties) { $properties[$property.Name] = $property.Value }
    $properties.identityState = 'HUMAN_CONFIRMED_REVIEW_ONLY'
    $humanBaselineFamily = [string](Reference-Family ([pscustomobject]$properties))
    $actualFamily = [string](Reference-Family $row)
    if (-not [string]::IsNullOrWhiteSpace($humanBaselineFamily)) {
        $nonFrontEligibleUnderHumanState.Add($row)
        if ($actualFamily -cne $humanBaselineFamily) {
            throw "Producer-approved identity state parity failed outside FRONT for $([string]$row.acquisitionKey)."
        }
    }
    if (-not [string]::IsNullOrWhiteSpace($actualFamily)) { $nonFrontImageAccepted.Add($row) }
}
if ($nonFrontEligibleUnderHumanState.Count -eq 0) {
    throw 'The live dataset did not exercise a non-FRONT image-confirmed row that otherwise satisfies the identity/context gate.'
}

. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $dashboardPath -FunctionName 'Get-Sha256Text')))
. ([scriptblock]::Create((Get-ExactFunctionText -ScriptPath $dashboardPath -FunctionName 'Acquisition-Fingerprint')))
$catalogByIdentity = @{}
foreach ($acquisition in @($catalog.acquisitions)) { $catalogByIdentity[[string]$acquisition.identity] = $acquisition }
$completedFrontRows = @($ledger.rows | Where-Object { [string]$_.state -eq 'COMPLETED' -and [string]$_.domain -eq 'FRONTSIDE' })
$historicalCandidates = New-Object Collections.Generic.List[string]
foreach ($group in @($completedFrontRows | Group-Object identity)) {
    if ($group.Count -ne 1 -or -not $catalogByIdentity.ContainsKey([string]$group.Name)) { continue }
    $acquisition = $catalogByIdentity[[string]$group.Name]
    $expectedJobKey = [string]$acquisition.identity + '__' + (Acquisition-Fingerprint $acquisition)
    if ([string]$group.Group[0].jobKey -ne $expectedJobKey) { $historicalCandidates.Add([string]$group.Name) }
}
$dashboardFrontIdentities = @($dashboard.scanSessions | ForEach-Object { $_.wafers } | Where-Object {
    [string]$_.metadata.domain -eq 'FRONTSIDE'
} | ForEach-Object { [string]$_.identity } | Sort-Object -Unique)
$dashboardSource = [IO.File]::ReadAllText($dashboardPath)
foreach ($token in @(
    'IMAGE_CONFIRMED_EXACT_PREVIOUS_HUMAN_SCRIBE_MATCH_REVIEW_ONLY',
    'IMAGE_CONFIRMED_CURRENT_PIXELS_EXACT_UNIQUE_MES_REVIEW_ONLY',
    'HISTORICAL_COMPLETED_SUPERSEDED_CURRENT_FINGERPRINT',
    'resultFingerprintState',
    'ledgerJobKey'
)) {
    if ($dashboardSource.IndexOf($token, [StringComparison]::Ordinal) -lt 0) { throw "Patched dashboard source is missing required token: $token" }
}

$traySource = [IO.File]::ReadAllText($trayPath)
if ($traySource -match '\$script:lastActivityKey' -or
    @([regex]::Matches($traySource, '\$form\.Tag\.LastActivityKey')).Count -ne 4) {
    throw 'The exact tray source does not contain the bounded form-state correction.'
}

[ordered]@{
    schema = 'argos_avs1_live_metadata_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_AVS1_EXACT_PREDICATES_AGAINST_SIGNED_LIVE_METADATA'
    windowsPowerShell = [ordered]@{
        major = [int]$PSVersionTable.PSVersion.Major
        minor = [int]$PSVersionTable.PSVersion.Minor
        edition = [string]$PSVersionTable.PSEdition
    }
    sources = [ordered]@{
        verifiedOverlaySha256 = (Get-FileHash -LiteralPath $overlayPath -Algorithm SHA256).Hash
        catalogSha256 = (Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash
        ledgerSha256 = (Get-FileHash -LiteralPath $ledgerPath -Algorithm SHA256).Hash
        dashboardSha256 = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
    }
    payload = $parseRows.ToArray()
    inventory = [ordered]@{
        runnerInventoryParameterSurface = 'PASS'
        verifiedRowsAccepted = $inventoryRows.Count
        targetRowsAccepted = $targetOverlayRows.Count
    }
    processing = [ordered]@{
        targetRowsAccepted = $targetProcessingRows.Count
        distinctTargetFamilies = @($targetFamilies | Sort-Object -Unique).Count
        nonFrontImageRowsObserved = $nonFrontImageRows.Count
        nonFrontImageRowsEligibleUnderHumanState = $nonFrontEligibleUnderHumanState.Count
        nonFrontImageRowsAccepted = $nonFrontImageAccepted.Count
    }
    dashboard = [ordered]@{
        completedFrontLedgerRows = $completedFrontRows.Count
        unambiguousHistoricalFrontCandidates = $historicalCandidates.Count
        currentFrontDashboardIdentities = $dashboardFrontIdentities.Count
        targetFrontLedgerRowsBeforeRepair = @($completedFrontRows | Where-Object { [string]$_.identity -like ($targetPrefix + '*') }).Count
    }
    tray = [ordered]@{
        scriptScopedLastActivityReferences = 0
        formTagLastActivityReferences = 4
    }
    mutationsPerformed = $false
    imageBytesRead = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8
