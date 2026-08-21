[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$IntentPath,
    [string]$ProjectRoot,
    [switch]$Preflight,
    [switch]$AsJson,
    [switch]$ReturnFailureResult
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Recovery intent inspection is preflight-only.' }
$effectiveProjectRoot = if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
} else {
    $ProjectRoot
}
$effectiveProjectRoot = [IO.Path]::GetFullPath($effectiveProjectRoot).TrimEnd('\')

function Get-MemberValue([AllowNull()][object]$Object, [string]$Name, [AllowNull()][object]$Default = $null) {
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    return $Default
}
function Resolve-ProjectFile([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.IndexOfAny([char[]]'*?') -ge 0) { return $null }
    $candidate = if ([IO.Path]::IsPathRooted($Path)) { [IO.Path]::GetFullPath($Path) } else { [IO.Path]::GetFullPath((Join-Path $effectiveProjectRoot $Path.Replace('/', '\'))) }
    if (-not $candidate.StartsWith($effectiveProjectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { return $null }
    return $candidate
}

$violations = New-Object Collections.Generic.List[object]
function Add-Violation([string]$Code, [string]$Message) {
    $violations.Add([pscustomobject]@{code = $Code; message = $Message})
}
function Test-PinnedFile([AllowNull()][object]$Record, [string]$Label, [bool]$RequirePassState) {
    $pathText = [string](Get-MemberValue $Record 'path' '')
    $expected = [string](Get-MemberValue $Record 'sha256' '')
    $resolved = Resolve-ProjectFile $pathText
    if ($null -eq $resolved) { Add-Violation 'PINNED_EVIDENCE_MISSING' "$Label path is missing, unsafe, or outside the project: $pathText"; return $null }
    $actual = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
    if ($actual -ne $expected) { Add-Violation 'PINNED_EVIDENCE_HASH_MISMATCH' "$Label hash mismatch: $pathText"; return $null }
    if ($RequirePassState) {
        try { $value = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json }
        catch { Add-Violation 'PINNED_GATE_JSON_INVALID' "$Label is not valid JSON: $pathText"; return $null }
        if ([string](Get-MemberValue $value 'state' '') -notmatch '^PASS_') { Add-Violation 'PINNED_GATE_NOT_PASS' "$Label is not PASS: $pathText" }
    }
    return $resolved
}
function Test-PinnedObservationEvidence([AllowNull()][object]$Record, [string]$Label, [string]$IncidentId) {
    $resolved = Test-PinnedFile $Record $Label $true
    if ($null -eq $resolved) { return $null }
    $evidence = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
    if ([string](Get-MemberValue $evidence 'schema' '') -ne 'argos_recovery_observation_evidence_v1') { Add-Violation 'OBSERVATION_EVIDENCE_SCHEMA_INVALID' "$Label schema changed." }
    if ([string](Get-MemberValue $evidence 'incidentId' '') -ne $IncidentId) { Add-Violation 'OBSERVATION_EVIDENCE_INCIDENT_MISMATCH' "$Label incident does not match the recovery intent." }
    if (-not [bool](Get-MemberValue $evidence 'exactSourcesProved' $false) -or -not [bool](Get-MemberValue $evidence 'fieldSpecificExpectedObservedRecorded' $false)) { Add-Violation 'OBSERVATION_EVIDENCE_INCOMPLETE' "$Label did not prove exact sources and field-specific expected/observed values." }
    if (-not [bool](Get-MemberValue $evidence 'directEndpointEvidence' $false) -and -not [bool](Get-MemberValue $evidence 'matchingSignedTerminalResponse' $false)) { Add-Violation 'OBSERVATION_EVIDENCE_TERMINAL_AUTHORITY_MISSING' "$Label has neither direct endpoint evidence nor a matching signed terminal response." }
    if ([bool](Get-MemberValue $evidence 'mutationsPerformed' $true)) { Add-Violation 'OBSERVATION_EVIDENCE_MUTATED' "$Label reports a mutation." }
    return $resolved
}

$resolvedIntent = Resolve-ProjectFile $IntentPath
if ($null -eq $resolvedIntent) { throw 'Recovery intent must be an existing bounded file inside the project.' }
if ((Get-Item -LiteralPath $resolvedIntent).Length -gt 1048576) { throw 'Recovery intent exceeds 1 MiB.' }
$intent = Get-Content -LiteralPath $resolvedIntent -Raw | ConvertFrom-Json

if ([string]$intent.schema -ne 'argos_recovery_intent_v1') { Add-Violation 'INTENT_SCHEMA_INVALID' 'Recovery intent schema changed.' }
if ([bool](Get-MemberValue $intent 'productionRoutingEnabled' $false)) { Add-Violation 'PRODUCTION_ROUTING_FORBIDDEN' 'Recovery intent cannot enable production routing.' }
if (-not [bool](Get-MemberValue $intent 'reviewOnly' $false)) { Add-Violation 'REVIEW_ONLY_REQUIRED' 'Recovery intent must remain review-only.' }

$mode = [string](Get-MemberValue $intent 'mode' '')
$lifecycle = [string](Get-MemberValue $intent 'artifactLifecycle' '')
if ($mode -notin @('OBSERVE', 'MUTATE')) { Add-Violation 'RECOVERY_MODE_INVALID' 'Recovery mode must be OBSERVE or MUTATE.' }
if ($lifecycle -notin @('DRAFT', 'FROZEN', 'SIGNED', 'PUBLISHED', 'WITHDRAWN')) { Add-Violation 'ARTIFACT_LIFECYCLE_INVALID' 'Artifact lifecycle is invalid.' }
if ($lifecycle -in @('SIGNED', 'PUBLISHED', 'WITHDRAWN')) { Add-Violation 'INTENT_LIFECYCLE_NOT_DESIGNABLE' 'A signed, published, or withdrawn artifact cannot authorize new design work.' }

[void](Test-PinnedFile (Get-MemberValue $intent 'policy' $null) 'recovery policy' $false)
$failureHistory = Get-MemberValue $intent 'failureHistory' $null
$signedFailures = [int](Get-MemberValue $failureHistory 'signedPremiseFailures' 0)
$localFailures = [int](Get-MemberValue $failureHistory 'localPremiseFailures' 0)
$directObservation = [bool](Get-MemberValue $failureHistory 'directObservationAfterLastSignedFailure' $false)
$stopLossCleared = [bool](Get-MemberValue $failureHistory 'mutationStopLossExplicitlyCleared' $false)
if ($signedFailures -lt 0) { Add-Violation 'SIGNED_FAILURE_COUNT_INVALID' 'Signed premise-failure count cannot be negative.' }
if ($localFailures -lt 0) { Add-Violation 'LOCAL_FAILURE_COUNT_INVALID' 'Local premise-failure count cannot be negative.' }
$failureEvidence = @(Get-MemberValue $failureHistory 'failureEvidence' @())
$failureEvidencePaths = @($failureEvidence | ForEach-Object { [string](Get-MemberValue $_ 'path' '') })
if (@($failureEvidencePaths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique).Count -ne $failureEvidence.Count) { Add-Violation 'FAILURE_EVIDENCE_SET_INVALID' 'Failure evidence paths must be nonempty and unique.' }
$observedSignedFailures = 0
$observedLocalFailures = 0
foreach ($evidenceRecord in $failureEvidence) {
    $evidencePath = Test-PinnedFile $evidenceRecord 'failure evidence' $false
    if ($null -eq $evidencePath) { continue }
    try { $evidenceValue = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json }
    catch { Add-Violation 'FAILURE_EVIDENCE_JSON_INVALID' "Failure evidence is not valid JSON: $($evidenceRecord.path)"; continue }
    $declaredState = [string](Get-MemberValue $evidenceRecord 'state' '')
    if ($declaredState -eq 'FAILED') {
        if ([string](Get-MemberValue $evidenceValue 'state' '') -notmatch '^FAIL_' -or [string](Get-MemberValue $evidenceValue 'responseState' '') -ne 'FAILED') { Add-Violation 'SIGNED_FAILURE_EVIDENCE_STATE_INVALID' "Signed failure evidence is not a terminal failed gate: $($evidenceRecord.path)" }
        else { $observedSignedFailures++ }
    } elseif ($declaredState -eq 'WITHDRAWN_LOCAL_REHEARSAL_FAILURE') {
        if ([string](Get-MemberValue $evidenceValue 'state' '') -ne 'WITHDRAWN') { Add-Violation 'LOCAL_FAILURE_EVIDENCE_STATE_INVALID' "Local failure evidence is not withdrawn: $($evidenceRecord.path)" }
        else { $observedLocalFailures++ }
    } else {
        Add-Violation 'FAILURE_EVIDENCE_CLASS_INVALID' "Failure evidence has an unsupported state classification: $declaredState"
    }
}
if ($observedSignedFailures -ne $signedFailures) { Add-Violation 'SIGNED_FAILURE_COUNT_UNPROVED' "Intent declares $signedFailures signed premise failures but pins $observedSignedFailures valid terminal failure gates." }
if ($observedLocalFailures -ne $localFailures) { Add-Violation 'LOCAL_FAILURE_COUNT_UNPROVED' "Intent declares $localFailures local premise failures but pins $observedLocalFailures valid withdrawn local gates." }
$incidentId = [string](Get-MemberValue $intent 'incidentId' '')
$postFailureObservationPath = $null
if ($directObservation) {
    $postFailureObservationPath = Test-PinnedObservationEvidence (Get-MemberValue $failureHistory 'postFailureObservation' $null) 'post-failure observation' $incidentId
}
if ($stopLossCleared) {
    $clearancePath = Test-PinnedFile (Get-MemberValue $failureHistory 'workflowReviewClearance' $null) 'workflow-review clearance' $true
    if ($null -ne $clearancePath) {
        $clearance = Get-Content -LiteralPath $clearancePath -Raw | ConvertFrom-Json
        if ([string](Get-MemberValue $clearance 'schema' '') -ne 'argos_recovery_workflow_review_clearance_v1' -or [string](Get-MemberValue $clearance 'incidentId' '') -ne $incidentId -or -not [bool](Get-MemberValue $clearance 'singleMutationAttemptAuthorized' $false)) { Add-Violation 'WORKFLOW_REVIEW_CLEARANCE_INVALID' 'Stop-loss clearance is not exact, incident-bound, and single-attempt.' }
    }
}

$route = Get-MemberValue $intent 'route' $null
$routeType = [string](Get-MemberValue $route 'type' '')
$jobClass = [string](Get-MemberValue $route 'jobClass' '')
$taskActions = @(Get-MemberValue $route 'taskActions' @())
$processActions = @(Get-MemberValue $route 'processActions' @())
$routeCapabilities = @()

if ($mode -eq 'OBSERVE') {
    if ($routeType -notin @('STATUS', 'DATA_PULL', 'DIRECT_ADMIN_READ_ONLY')) { Add-Violation 'OBSERVATION_ROUTE_INVALID' 'OBSERVE requires STATUS, DATA_PULL, or DIRECT_ADMIN_READ_ONLY.' }
    if ($jobClass -eq 'MAINTENANCE_PATCH') { Add-Violation 'OBSERVATION_MAINTENANCE_PATCH_FORBIDDEN' 'OBSERVE cannot use MAINTENANCE_PATCH.' }
    foreach ($property in @('installedCodeChange', 'helperInstall', 'queueMutation', 'ledgerMutation', 'sourceMutation', 'imageRead', 'waferAction')) {
        if ([bool](Get-MemberValue $route $property $false)) { Add-Violation 'OBSERVATION_MUTATION_FORBIDDEN' "OBSERVE cannot enable route.$property." }
    }
    if ($taskActions.Count -ne 0 -or $processActions.Count -ne 0) { Add-Violation 'OBSERVATION_ACTION_FORBIDDEN' 'OBSERVE cannot declare task or process actions.' }
    if ($routeType -in @('STATUS', 'DATA_PULL')) {
        if (-not [bool](Get-MemberValue $route 'inheritsQualifiedEndpointGate' $false)) { Add-Violation 'ENDPOINT_GATE_INHERITANCE_REQUIRED' 'Portal observation must inherit an exact qualified endpoint gate.' }
        [void](Test-PinnedFile (Get-MemberValue $route 'endpointWorker' $null) 'endpoint worker' $false)
        [void](Test-PinnedFile (Get-MemberValue $route 'installedConfigEvidence' $null) 'installed config evidence' $false)
        [void](Test-PinnedFile (Get-MemberValue $route 'qualifiedEndpointGate' $null) 'qualified endpoint gate' $true)
    } elseif ($routeType -eq 'DIRECT_ADMIN_READ_ONLY') {
        $adminGatePath = Test-PinnedFile (Get-MemberValue $route 'qualifiedAdminGate' $null) 'qualified direct-admin gate' $true
        if ($null -ne $adminGatePath) {
            $adminGate = Get-Content -LiteralPath $adminGatePath -Raw | ConvertFrom-Json
            if ([string](Get-MemberValue $adminGate 'schema' '') -ne 'argos_direct_admin_read_only_authorization_gate_v1' -or -not [bool](Get-MemberValue $adminGate 'readOnly' $false) -or [bool](Get-MemberValue $adminGate 'taskActionsAllowed' $true) -or [bool](Get-MemberValue $adminGate 'processActionsAllowed' $true) -or [bool](Get-MemberValue $adminGate 'installedChangesAllowed' $true)) { Add-Violation 'DIRECT_ADMIN_AUTHORIZATION_GATE_INVALID' 'Direct-admin authorization is not exact and read-only.' }
        }
    }
    if ($routeType -in @('STATUS', 'DATA_PULL', 'DIRECT_ADMIN_READ_ONLY')) {
        $capabilityPath = Test-PinnedFile (Get-MemberValue $route 'capabilityEvidence' $null) 'route capability evidence' $true
        if ($null -ne $capabilityPath) {
            $capabilityInventory = Get-Content -LiteralPath $capabilityPath -Raw | ConvertFrom-Json
            if ([string]$capabilityInventory.schema -ne 'argos_endpoint_read_only_capability_inventory_v1') { Add-Violation 'CAPABILITY_INVENTORY_SCHEMA_INVALID' 'Route capability evidence schema changed.' }
            $capabilityRows = @($capabilityInventory.routes | Where-Object { [string]$_.type -eq $routeType })
            if ($capabilityRows.Count -ne 1) { Add-Violation 'ROUTE_CAPABILITY_ROW_INVALID' "Capability inventory requires exactly one $routeType row." }
            else { $routeCapabilities = @($capabilityRows[0].capabilities | ForEach-Object { [string]$_ } | Sort-Object -Unique) }
        }
    }
    $observation = Get-MemberValue $intent 'observation' $null
    $sources = @(Get-MemberValue $observation 'exactSources' @())
    if ($sources.Count -lt 1 -or $sources.Count -gt 32) { Add-Violation 'OBSERVATION_SOURCE_COUNT_INVALID' 'OBSERVE requires 1..32 exact sources.' }
    foreach ($source in $sources) {
        foreach ($property in @('sourcePath', 'sourceSchema', 'selector', 'uniquenessKey')) {
            if ([string]::IsNullOrWhiteSpace([string](Get-MemberValue $source $property ''))) { Add-Violation 'OBSERVATION_SOURCE_CONTRACT_INCOMPLETE' "Observation source omitted $property." }
        }
        $maximumRows = [int](Get-MemberValue $source 'maximumRows' 0)
        if ($maximumRows -lt 1 -or $maximumRows -gt 1000) { Add-Violation 'OBSERVATION_ROW_BOUND_INVALID' 'Observation maximumRows must be 1..1000.' }
    }
    $fields = @(Get-MemberValue $observation 'requestedFields' @())
    if ($fields.Count -lt 1 -or $fields.Count -gt 64 -or @($fields | Sort-Object -Unique).Count -ne $fields.Count) { Add-Violation 'OBSERVATION_FIELD_SET_INVALID' 'Observation requestedFields must be 1..64 unique fields.' }
    $requestedCapabilities = @(Get-MemberValue $observation 'requestedCapabilities' @() | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    if ($requestedCapabilities.Count -lt 1 -or $requestedCapabilities.Count -gt 64) { Add-Violation 'REQUESTED_CAPABILITY_SET_INVALID' 'Observation requestedCapabilities must contain 1..64 unique values.' }
    foreach ($capability in $requestedCapabilities) {
        if ($routeCapabilities -notcontains $capability) { Add-Violation 'OBSERVATION_ROUTE_CAPABILITY_GAP' "The $routeType route cannot provide requested capability: $capability" }
    }
    $options = @(Get-MemberValue $observation 'decisionOptions' @() | Sort-Object -Unique)
    if ($options.Count -ne 4 -or @(Compare-Object -ReferenceObject @('A', 'B', 'C', 'D') -DifferenceObject $options).Count -ne 0) { Add-Violation 'DECISION_OPTION_SET_INVALID' 'Observation must preserve decision options A, B, C, and D.' }
    if (-not [bool](Get-MemberValue $observation 'mutationDecisionDeferred' $false)) { Add-Violation 'MUTATION_DECISION_NOT_DEFERRED' 'OBSERVE must defer the mutation decision until evidence returns.' }
}

if ($mode -eq 'MUTATE') {
    if ($signedFailures -ge 2 -and -not $stopLossCleared) { Add-Violation 'MUTATION_STOP_LOSS_ACTIVE' 'Two signed premise failures block another mutation until explicit workflow-review clearance.' }
    if ($signedFailures -ge 1 -and -not $directObservation) { Add-Violation 'POST_FAILURE_OBSERVATION_REQUIRED' 'A direct post-failure observation is required before mutation.' }
    $mutation = Get-MemberValue $intent 'mutation' $null
    $remedy = [string](Get-MemberValue $mutation 'supportedRemedy' '')
    if ($remedy -notin @('B', 'C', 'D')) { Add-Violation 'MUTATION_REMEDY_INVALID' 'Mutation must implement exactly one supported remedy B, C, or D.' }
    $supportingObservationPath = Test-PinnedObservationEvidence (Get-MemberValue $mutation 'supportingObservation' $null) 'supporting observation' $incidentId
    if ($signedFailures -ge 1 -and $null -ne $supportingObservationPath -and $null -ne $postFailureObservationPath -and -not $supportingObservationPath.Equals($postFailureObservationPath, [StringComparison]::OrdinalIgnoreCase)) { Add-Violation 'MUTATION_OBSERVATION_EVIDENCE_MISMATCH' 'Mutation support must be the exact pinned post-failure observation.' }
    if (-not [bool](Get-MemberValue $mutation 'endpointMutationNecessary' $false) -or -not [bool](Get-MemberValue $mutation 'singleMutationAttemptAuthorized' $false)) { Add-Violation 'MUTATION_AUTHORITY_INCOMPLETE' 'Mutation necessity and single-attempt authority must both be explicit.' }
}

$result = [ordered]@{
    schema = 'argos_recovery_intent_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($violations.Count -eq 0) { 'PASS_ARGOS_RECOVERY_INTENT' } else { 'FAIL_ARGOS_RECOVERY_INTENT' }
    intentPath = $resolvedIntent
    intentSha256 = (Get-FileHash -LiteralPath $resolvedIntent -Algorithm SHA256).Hash
    incidentId = $incidentId
    mode = $mode
    artifactLifecycle = $lifecycle
    signedPremiseFailures = $signedFailures
    mutationStopLossActive = ($signedFailures -ge 2 -and -not $stopLossCleared)
    targetExecuted = $false
    mutationsPerformed = $false
    violations = $violations.ToArray()
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$json = $result | ConvertTo-Json -Depth 8
if ($AsJson) { $json } else { $result }
if ($violations.Count -gt 0 -and -not $ReturnFailureResult) { throw "Recovery intent preflight failed with $($violations.Count) violation(s)." }
