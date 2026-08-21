[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$AuditPath,
    [Parameter(Mandatory = $true)][string]$ContractPath,
    [string]$ProjectRoot,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Zero-recurrence pre-action inspection is preflight-only.' }

$effectiveProjectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
} else {
    $ProjectRoot
}
$effectiveProjectRoot = [IO.Path]::GetFullPath($effectiveProjectRoot).TrimEnd('\')

function Resolve-ArgosPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $effectiveProjectRoot $Path.Replace('/', [IO.Path]::DirectorySeparatorChar))
}

function Read-JsonFile {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = Resolve-ArgosPath $Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Missing required JSON file: $resolved"
    }
    return (Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json)
}

function Require-True {
    param([Parameter(Mandatory = $true)][object]$Object,[Parameter(Mandatory = $true)][string]$Property)
    if (-not ($Object.PSObject.Properties.Name -contains $Property)) {
        throw "Missing required Boolean control: $Property"
    }
    if (-not [bool]$Object.$Property) {
        throw "Required Boolean control is not true: $Property"
    }
}

$audit = Read-JsonFile $AuditPath
$contract = Read-JsonFile $ContractPath

if ([string]$audit.schema -ne 'argos_history_no_repeat_audit_v1') { throw 'History audit schema changed.' }
if ([string]$audit.state -ne 'PASS_HISTORY_AUDIT_WITH_DISCLOSED_NONREUSABLE_LEGACY_ARTIFACT') { throw 'History audit is not terminal.' }
if ([int]$audit.openUnclassifiedIssueCount -ne 0) { throw 'History audit has unclassified issues.' }
if ([int]$audit.issueCount -ne @($audit.issueIds).Count) { throw 'History audit issue count changed.' }

$requiredIssueIds = @(
    'OPS_PORTAL_QUEUE_POISON','OPS_STORAGE_C_TO_D_PATHS','OPS_COMPLETED_LOT_VIEWER_AND_REFRESH',
    'OPS_INSITE_ATTEMPT_IDENTITY','OPS_RESIDENT_RUNNER_REFRESH','OPS_TASK_PRINCIPAL_AND_SINGLETON',
    'OPS_DOWNLOADS_LOG_DURABILITY','OPS_PATH_LENGTH_AND_SHORT_NAMES','VIS_NOTCH_THUMBNAIL_AUTHORITY',
    'VIS_FIDUCIAL_SITE_MAP_SEMANTICS','VIS_FULL_RES_STRAIGHT_CROP','VIS_CORNER_IGNORE_ENFORCED',
    'VIS_COLOR_POLARITY','VIS_OPERATOR_DRAWING_SEMANTICS','PKG_INSTALLED_ROOT_GUESS',
    'PKG_OPTIONAL_STRICT_PROPERTY','PKG_TARGET_NOT_APPROVED','PKG_CLONE_RESIDUE',
    'PKG_GUESSED_STATE_SWITCH_OR_PRINCIPAL','PKG_ARRAY_ARGUMENT_BOUNDARY','CMD_STATEMENT_PIPE',
    'CMD_INCOMPLETE_LITERAL_OR_BRACE','CMD_COLON_INTERPOLATION','CMD_WILDCARD_ROOT',
    'CMD_EXTERNAL_FORMATTED_OUTPUT','CMD_EMPTY_OR_SINGLE_COLLECTION','CMD_EXPECTED_STDERR_PROMOTION',
    'CMD_FIXED_ROOT_OR_BROAD_CLEANUP','CMD_OPTIONAL_TOOL_NOT_DISCOVERED','PKG_TASK_ACTION_DECLARATION_MISMATCH',
    'CHECKPOINT_PROMOTED_BEFORE_HISTORY_AUDIT'
)
foreach ($issueId in $requiredIssueIds) {
    if (@($audit.issueIds) -notcontains $issueId) { throw "History audit omitted required issue: $issueId" }
}

$blocked = @($audit.blockedArtifacts | Where-Object {
    [string]$_.path -eq 'work/JBOD_INSPECTOR_OPEN_C2O1/final/REQ_C2O1.ready.zip'
})
if ($blocked.Count -ne 1 -or [bool]$blocked[0].futureReuseAllowed -or [bool]$blocked[0].replayAllowed -or [bool]$blocked[0].successorParentAllowed) {
    throw 'C2O1 mismatch artifact is not completely blocked from future reuse.'
}
if ([string]$audit.legacyEvidence.declaredAction -eq [string]$audit.legacyEvidence.implementedAction) {
    throw 'Legacy action mismatch disclosure disappeared.'
}
if ([int]$audit.legacyEvidence.exactInspectorProcessCountBefore -ne 0 -or [int]$audit.legacyEvidence.exactInspectorProcessCountAfter -ne 1 -or -not [bool]$audit.legacyEvidence.taskStartIssued -or [bool]$audit.legacyEvidence.protectedTasksChanged -or [bool]$audit.legacyEvidence.processorTaskChanged -or [bool]$audit.legacyEvidence.futureReuseAllowed) {
    throw 'Legacy action evidence no longer proves the bounded non-reusable start.'
}

$contractSchema = [string]$contract.schema
if ($contractSchema -notin @('argos_zero_recurrence_preaction_v1', 'argos_zero_recurrence_preaction_v2')) { throw 'Pre-action contract schema changed.' }
$policyV2EffectiveUtc = [DateTimeOffset]::Parse('2026-08-21T19:15:00Z')
$contractCreatedUtc = [DateTimeOffset]::MinValue
if (-not [DateTimeOffset]::TryParse([string]$contract.createdUtc, [ref]$contractCreatedUtc)) { throw 'Pre-action contract createdUtc is invalid.' }
$isV2 = $contractSchema -eq 'argos_zero_recurrence_preaction_v2'
if (-not $isV2 -and $contractCreatedUtc -ge $policyV2EffectiveUtc) { throw 'New execution contracts must use evidence-backed pre-action schema v2.' }
if ([string]$contract.state -ne 'PASS_PREACTION_CONTRACT') { throw 'Pre-action contract is not PASS.' }
if ([bool]$contract.productionRoutingEnabled) { throw 'Production routing is prohibited.' }
if (-not [bool]$contract.reviewOnly) { throw 'Pre-action contract must remain review-only.' }

$resolvedAudit = Resolve-ArgosPath $AuditPath
$auditHash = (Get-FileHash -LiteralPath $resolvedAudit -Algorithm SHA256).Hash
if ([string]$contract.historyAuditSha256 -ne $auditHash) { throw 'Pre-action contract history-audit hash mismatch.' }

$controlNames = @(
    'valuesDerivedFromCurrentFileEvidence','dependencyHashesPinned','templateResidueAuditPassed',
    'installedRootAndTaskIdentityPinned','pathAndWrapperGatesPassedWhenApplicable','compoundCommandsFileBacked',
    'windowsPowerShell51ParserPassedWhenApplicable','externalEvidenceJsonRehydrated','arrayBoundaryModeSafe',
    'zeroOneManyCollectionCasesPassed','optionalPropertiesPresenceTested','residentConsumersInventoried',
    'declaredActionMatchesImplementation','expectedFailureCaptureSafe','optionalToolsDiscoveredBeforeUse','queueAndReturnRouteTerminalGatePlanned',
    'historyAuditCompleteBeforeCheckpoint'
)
foreach ($controlName in $controlNames) { Require-True $contract.controls $controlName }

$dependencyRows = @($contract.dependencies)
if ($dependencyRows.Count -lt 1) { throw 'Pre-action contract has no pinned dependencies.' }
foreach ($dependency in $dependencyRows) {
    $resolved = Resolve-ArgosPath ([string]$dependency.path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Missing dependency: $($dependency.path)" }
    $actualHash = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
    if ($actualHash -ne [string]$dependency.sha256) { throw "Dependency hash mismatch: $($dependency.path)" }
}

$collectionEvidenceVerified = $false
$collectionCaseIds = @()
if ($isV2) {
    if (-not ($contract.PSObject.Properties.Name -contains 'collectionCaseEvidence')) { throw 'Pre-action v2 omitted collection-case evidence.' }
    $collectionEvidence = $contract.collectionCaseEvidence
    $collectionPathText = [string]$collectionEvidence.path
    $collectionPath = Resolve-ArgosPath $collectionPathText
    if (-not (Test-Path -LiteralPath $collectionPath -PathType Leaf)) { throw "Collection-case gate is missing: $collectionPathText" }
    $collectionHash = (Get-FileHash -LiteralPath $collectionPath -Algorithm SHA256).Hash
    if ($collectionHash -ne [string]$collectionEvidence.sha256) { throw 'Collection-case gate hash mismatch.' }
    $collectionGate = Get-Content -LiteralPath $collectionPath -Raw | ConvertFrom-Json
    if ([string]$collectionGate.schema -ne 'argos_powershell_collection_case_gate_v1') { throw 'Collection-case gate schema changed.' }
    if ([string]$collectionGate.state -ne 'PASS_ARGOS_POWERSHELL_COLLECTION_CASES') { throw 'Collection-case gate is not PASS.' }
    if ([int]$collectionGate.windowsPowerShell.major -ne 5 -or [int]$collectionGate.windowsPowerShell.minor -ne 1) { throw 'Collection-case gate did not run under Windows PowerShell 5.1.' }
    $requiredCaseIds = @($collectionEvidence.requiredCaseIds | ForEach-Object { ([string]$_).ToUpperInvariant() } | Sort-Object -Unique)
    if ($requiredCaseIds.Count -ne 3 -or @(Compare-Object -ReferenceObject @('MANY', 'ONE', 'ZERO') -DifferenceObject $requiredCaseIds).Count -ne 0) { throw 'Pre-action v2 must require ZERO, ONE, and MANY collection cases.' }
    $collectionCaseIds = @($collectionGate.caseIds | ForEach-Object { ([string]$_).ToUpperInvariant() } | Sort-Object -Unique)
    if (@(Compare-Object -ReferenceObject $requiredCaseIds -DifferenceObject $collectionCaseIds).Count -ne 0) { throw 'Collection-case gate did not prove the required case IDs.' }
    $collectionSources = @($collectionGate.sourceFiles)
    if ($collectionSources.Count -lt 1) { throw 'Collection-case gate has no pinned source files.' }
    foreach ($source in $collectionSources) {
        $sourcePath = Resolve-ArgosPath ([string]$source.path)
        if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "Collection-case source is missing: $($source.path)" }
        if ((Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash -ne [string]$source.sha256) { throw "Collection-case source hash mismatch: $($source.path)" }
    }
    $collectionEvidenceVerified = $true
}

if ([bool]$contract.legacyEvidenceException.used) {
    if ([string]$contract.actionType -ne 'CHECKPOINT_SUPERSESSION_ONLY') { throw 'Legacy exception cannot authorize execution.' }
    if ([bool]$contract.legacyEvidenceException.newExecutionAuthorized -or [bool]$contract.legacyEvidenceException.futureReuseAllowed) { throw 'Legacy exception widened authority.' }
    if (@($contract.legacyEvidenceException.blockedArtifacts) -notcontains 'work/JBOD_INSPECTOR_OPEN_C2O1/final/REQ_C2O1.ready.zip') { throw 'Legacy exception omitted the blocked C2O1 artifact.' }
}

$result = [ordered]@{
    schema = if ($isV2) { 'argos_zero_recurrence_preaction_result_v2' } else { 'argos_zero_recurrence_preaction_result_v1' }
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION'
    revision = [string]$contract.revision
    actionType = [string]$contract.actionType
    auditedIssueCount = @($audit.issueIds).Count
    dependencyCount = $dependencyRows.Count
    evidenceBackedContract = $isV2
    collectionCaseEvidenceVerified = $collectionEvidenceVerified
    collectionCaseIds = $collectionCaseIds
    legacyMismatchDisclosed = $true
    legacyArtifactReuseBlocked = $true
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$result | ConvertTo-Json -Depth 6
