[CmdletBinding()]
param(
    [string]$ProjectRoot
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        throw 'Cannot resolve the continuity script path.'
    }
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}

function Resolve-ProjectPath {
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $native = $RelativePath.Replace('/', [IO.Path]::DirectorySeparatorChar)
    Join-Path $ProjectRoot $native
}

$statePath = Join-Path $ProjectRoot 'work\ARGOS_CONTINUITY_STATE.json'
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    throw "Missing continuity state: $statePath"
}

$state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
$required = @(
    'AGENTS.md',
    $state.activeStatePath,
    $state.memoryIndexPath,
    $state.revisionLedgerPath,
    $state.currentPhaseCheckpoint,
    $state.canonicalReviewerLock,
    $state.lockedFeedback.path,
    $state.latestDiagnostic.path
)
if ($state.PSObject.Properties.Name -contains 'latestReviewer') {
    $required += $state.latestReviewer.path
    foreach ($property in @('launcher','page','manifest')) {
        if ($state.latestReviewer.PSObject.Properties.Name -contains $property) {
            $required += $state.latestReviewer.$property
        }
    }
    if ($state.latestReviewer.PSObject.Properties.Name -contains 'artifacts') {
        foreach ($artifact in @($state.latestReviewer.artifacts)) {
            $required += $artifact.path
        }
    }
}
if ($state.PSObject.Properties.Name -contains 'latestOperatorFeedback') {
    $required += $state.latestOperatorFeedback.path
    $required += $state.latestOperatorFeedback.saveCompletePath
}
if ($state.PSObject.Properties.Name -contains 'sessionSafety') {
    $required += $state.sessionSafety.policyPath
    $required += $state.sessionSafety.guardScriptPath
    if ($state.sessionSafety.PSObject.Properties.Name -contains 'healthProbeScriptPath') {
        $required += $state.sessionSafety.healthProbeScriptPath
    }
}
if ($state.PSObject.Properties.Name -contains 'pathSafety') {
    $required += $state.pathSafety.policyPath
    $required += $state.pathSafety.guardScriptPath
}
if ($state.PSObject.Properties.Name -contains 'powerShellWrapperSafety') {
    $required += $state.powerShellWrapperSafety.policyPath
    $required += $state.powerShellWrapperSafety.guardScriptPath
    $required += $state.powerShellWrapperSafety.templateScriptPath
    $required += $state.powerShellWrapperSafety.templateWrapperPath
    $required += $state.powerShellWrapperSafety.templateManifestPath
}
if ($state.PSObject.Properties.Name -contains 'rasterProvenanceSafety') {
    $required += $state.rasterProvenanceSafety.policyPath
    $required += $state.rasterProvenanceSafety.guardScriptPath
}

$rows = foreach ($relative in $required) {
    $full = Resolve-ProjectPath $relative
    [pscustomobject]@{
        Path = $relative
        Exists = Test-Path -LiteralPath $full
        Type = if (Test-Path -LiteralPath $full -PathType Container) { 'Directory' } else { 'File' }
    }
}

$missing = @($rows | Where-Object { -not $_.Exists })
if ($missing.Count -gt 0) {
    $missing.Path | ForEach-Object { Write-Error "Missing continuity dependency: $_" }
    throw "Argos continuity check failed: $($missing.Count) required path(s) missing."
}

$feedbackPath = Resolve-ProjectPath $state.lockedFeedback.path
$feedbackHash = (Get-FileHash -LiteralPath $feedbackPath -Algorithm SHA256).Hash
if ($feedbackHash -ne $state.lockedFeedback.sha256) {
    throw "Locked feedback hash mismatch. Expected $($state.lockedFeedback.sha256); found $feedbackHash"
}

$diagnosticPath = Resolve-ProjectPath $state.latestDiagnostic.path
$diagnosticHash = (Get-FileHash -LiteralPath $diagnosticPath -Algorithm SHA256).Hash
if ($diagnosticHash -ne $state.latestDiagnostic.sha256) {
    throw "Latest diagnostic hash mismatch. Expected $($state.latestDiagnostic.sha256); found $diagnosticHash"
}

$reviewerHash = $null
$reviewerArtifactHashes = @()
if ($state.PSObject.Properties.Name -contains 'latestReviewer') {
    $reviewerPath = Resolve-ProjectPath $state.latestReviewer.path
    $reviewerHash = (Get-FileHash -LiteralPath $reviewerPath -Algorithm SHA256).Hash
    if ($reviewerHash -ne $state.latestReviewer.sha256) {
        throw "Latest reviewer hash mismatch. Expected $($state.latestReviewer.sha256); found $reviewerHash"
    }
    if ($state.latestReviewer.PSObject.Properties.Name -contains 'artifacts') {
        foreach ($artifact in @($state.latestReviewer.artifacts)) {
            $artifactPath = Resolve-ProjectPath $artifact.path
            $artifactHash = (
                Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256
            ).Hash
            if ($artifactHash -ne [string]$artifact.sha256) {
                throw "Latest reviewer artifact hash mismatch for $($artifact.path). Expected $($artifact.sha256); found $artifactHash"
            }
            $reviewerArtifactHashes += $artifactHash
        }
    }
}

$phaseCheckpointHash = $null
if ($state.PSObject.Properties.Name -contains 'currentPhaseCheckpointSha256') {
    $phaseCheckpointHash = (
        Get-FileHash -LiteralPath (
            Resolve-ProjectPath $state.currentPhaseCheckpoint
        ) -Algorithm SHA256
    ).Hash
    if ($phaseCheckpointHash -ne $state.currentPhaseCheckpointSha256) {
        throw "Current phase checkpoint hash mismatch. Expected $($state.currentPhaseCheckpointSha256); found $phaseCheckpointHash"
    }
}

$operatorFeedbackHash = $null
$saveCompleteHash = $null
if ($state.PSObject.Properties.Name -contains 'latestOperatorFeedback') {
    $operatorFeedbackPath = Resolve-ProjectPath $state.latestOperatorFeedback.path
    $operatorFeedbackHash = (
        Get-FileHash -LiteralPath $operatorFeedbackPath -Algorithm SHA256
    ).Hash
    if ($operatorFeedbackHash -ne $state.latestOperatorFeedback.sha256) {
        throw "Latest operator feedback hash mismatch. Expected $($state.latestOperatorFeedback.sha256); found $operatorFeedbackHash"
    }
    $saveCompletePath = Resolve-ProjectPath `
        $state.latestOperatorFeedback.saveCompletePath
    $saveCompleteHash = (
        Get-FileHash -LiteralPath $saveCompletePath -Algorithm SHA256
    ).Hash
    if ($saveCompleteHash -ne $state.latestOperatorFeedback.saveCompleteSha256) {
        throw "Latest feedback completion hash mismatch. Expected $($state.latestOperatorFeedback.saveCompleteSha256); found $saveCompleteHash"
    }
}

$sessionPolicyHash = $null
$sessionGuardHash = $null
$sessionHealthProbeHash = $null
if ($state.PSObject.Properties.Name -contains 'sessionSafety') {
    $sessionPolicyPath = Resolve-ProjectPath $state.sessionSafety.policyPath
    $sessionPolicyHash = (
        Get-FileHash -LiteralPath $sessionPolicyPath -Algorithm SHA256
    ).Hash
    if ($sessionPolicyHash -ne $state.sessionSafety.policySha256) {
        throw "Session-safety policy hash mismatch. Expected $($state.sessionSafety.policySha256); found $sessionPolicyHash"
    }
    $sessionGuardPath = Resolve-ProjectPath $state.sessionSafety.guardScriptPath
    $sessionGuardHash = (
        Get-FileHash -LiteralPath $sessionGuardPath -Algorithm SHA256
    ).Hash
    if ($sessionGuardHash -ne $state.sessionSafety.guardScriptSha256) {
        throw "Session-safety guard hash mismatch. Expected $($state.sessionSafety.guardScriptSha256); found $sessionGuardHash"
    }
    if ($state.sessionSafety.PSObject.Properties.Name -contains 'healthProbeScriptPath') {
        $sessionHealthProbePath = Resolve-ProjectPath `
            $state.sessionSafety.healthProbeScriptPath
        $sessionHealthProbeHash = (
            Get-FileHash -LiteralPath $sessionHealthProbePath -Algorithm SHA256
        ).Hash
        if ($sessionHealthProbeHash -ne $state.sessionSafety.healthProbeScriptSha256) {
            throw "Session-health probe hash mismatch. Expected $($state.sessionSafety.healthProbeScriptSha256); found $sessionHealthProbeHash"
        }
    }
}

$pathPolicyHash = $null
$pathGuardHash = $null
if ($state.PSObject.Properties.Name -contains 'pathSafety') {
    $pathPolicyPath = Resolve-ProjectPath $state.pathSafety.policyPath
    $pathPolicyHash = (
        Get-FileHash -LiteralPath $pathPolicyPath -Algorithm SHA256
    ).Hash
    if ($pathPolicyHash -ne $state.pathSafety.policySha256) {
        throw "Path-safety policy hash mismatch. Expected $($state.pathSafety.policySha256); found $pathPolicyHash"
    }
    $pathGuardPath = Resolve-ProjectPath $state.pathSafety.guardScriptPath
    $pathGuardHash = (
        Get-FileHash -LiteralPath $pathGuardPath -Algorithm SHA256
    ).Hash
    if ($pathGuardHash -ne $state.pathSafety.guardScriptSha256) {
        throw "Path-safety guard hash mismatch. Expected $($state.pathSafety.guardScriptSha256); found $pathGuardHash"
    }
}

$wrapperPolicyHash = $null
$wrapperGuardHash = $null
$wrapperTemplateScriptHash = $null
$wrapperTemplateWrapperHash = $null
$wrapperTemplateManifestHash = $null
if ($state.PSObject.Properties.Name -contains 'powerShellWrapperSafety') {
    $wrapperPolicyPath = Resolve-ProjectPath `
        $state.powerShellWrapperSafety.policyPath
    $wrapperPolicyHash = (
        Get-FileHash -LiteralPath $wrapperPolicyPath -Algorithm SHA256
    ).Hash
    if ($wrapperPolicyHash -ne $state.powerShellWrapperSafety.policySha256) {
        throw "PowerShell-wrapper policy hash mismatch. Expected $($state.powerShellWrapperSafety.policySha256); found $wrapperPolicyHash"
    }
    $wrapperGuardPath = Resolve-ProjectPath `
        $state.powerShellWrapperSafety.guardScriptPath
    $wrapperGuardHash = (
        Get-FileHash -LiteralPath $wrapperGuardPath -Algorithm SHA256
    ).Hash
    if ($wrapperGuardHash -ne $state.powerShellWrapperSafety.guardScriptSha256) {
        throw "PowerShell-wrapper guard hash mismatch. Expected $($state.powerShellWrapperSafety.guardScriptSha256); found $wrapperGuardHash"
    }
    $wrapperTemplateScriptHash = (
        Get-FileHash -LiteralPath (
            Resolve-ProjectPath $state.powerShellWrapperSafety.templateScriptPath
        ) -Algorithm SHA256
    ).Hash
    if ($wrapperTemplateScriptHash -ne $state.powerShellWrapperSafety.templateScriptSha256) {
        throw "PowerShell-wrapper template script hash mismatch. Expected $($state.powerShellWrapperSafety.templateScriptSha256); found $wrapperTemplateScriptHash"
    }
    $wrapperTemplateWrapperHash = (
        Get-FileHash -LiteralPath (
            Resolve-ProjectPath $state.powerShellWrapperSafety.templateWrapperPath
        ) -Algorithm SHA256
    ).Hash
    if ($wrapperTemplateWrapperHash -ne $state.powerShellWrapperSafety.templateWrapperSha256) {
        throw "PowerShell-wrapper template CMD hash mismatch. Expected $($state.powerShellWrapperSafety.templateWrapperSha256); found $wrapperTemplateWrapperHash"
    }
    $wrapperTemplateManifestHash = (
        Get-FileHash -LiteralPath (
            Resolve-ProjectPath $state.powerShellWrapperSafety.templateManifestPath
        ) -Algorithm SHA256
    ).Hash
    if ($wrapperTemplateManifestHash -ne $state.powerShellWrapperSafety.templateManifestSha256) {
        throw "PowerShell-wrapper template manifest hash mismatch. Expected $($state.powerShellWrapperSafety.templateManifestSha256); found $wrapperTemplateManifestHash"
    }
}

$rasterPolicyHash = $null
$rasterGuardHash = $null
if ($state.PSObject.Properties.Name -contains 'rasterProvenanceSafety') {
    $rasterPolicyPath = Resolve-ProjectPath `
        $state.rasterProvenanceSafety.policyPath
    $rasterPolicyHash = (
        Get-FileHash -LiteralPath $rasterPolicyPath -Algorithm SHA256
    ).Hash
    if ($rasterPolicyHash -ne $state.rasterProvenanceSafety.policySha256) {
        throw "Raster-provenance policy hash mismatch. Expected $($state.rasterProvenanceSafety.policySha256); found $rasterPolicyHash"
    }
    $rasterGuardPath = Resolve-ProjectPath `
        $state.rasterProvenanceSafety.guardScriptPath
    $rasterGuardHash = (
        Get-FileHash -LiteralPath $rasterGuardPath -Algorithm SHA256
    ).Hash
    if ($rasterGuardHash -ne $state.rasterProvenanceSafety.guardScriptSha256) {
        throw "Raster-provenance guard hash mismatch. Expected $($state.rasterProvenanceSafety.guardScriptSha256); found $rasterGuardHash"
    }
}

$lockPath = Resolve-ProjectPath $state.canonicalReviewerLock
$lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
foreach ($entry in $lock.files) {
    $source = Resolve-ProjectPath (Join-Path $lock.sourceRoot $entry.name)
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Canonical reviewer source missing: $source"
    }
    $actual = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
    if ($actual -ne $entry.sha256) {
        throw "Canonical reviewer hash mismatch for $($entry.name). Expected $($entry.sha256); found $actual"
    }
}

$ledgerText = Get-Content -LiteralPath (Resolve-ProjectPath $state.revisionLedgerPath) -Raw
foreach ($withdrawn in $state.withdrawnArtifacts) {
    $leaf = Split-Path $withdrawn -Leaf
    if ($ledgerText -notmatch [regex]::Escape($leaf) -or $ledgerText -notmatch 'WITHDRAWN') {
        throw "Withdrawn artifact is not recorded in the revision ledger: $withdrawn"
    }
}

[pscustomobject]@{
    State = 'PASS_ARGOS_PROJECT_CONTINUITY'
    ActiveFamily = $state.activeFamily
    ActivePhase = $state.activePhase
    FeedbackSha256 = $feedbackHash
    DiagnosticSha256 = $diagnosticHash
    ReviewerSha256 = $reviewerHash
    ReviewerArtifactsVerified = @($reviewerArtifactHashes).Count
    PhaseCheckpointSha256 = $phaseCheckpointHash
    OperatorFeedbackSha256 = $operatorFeedbackHash
    FeedbackSaveCompleteSha256 = $saveCompleteHash
    SessionSafetyPolicySha256 = $sessionPolicyHash
    SessionSafetyGuardSha256 = $sessionGuardHash
    SessionHealthProbeSha256 = $sessionHealthProbeHash
    PathSafetyPolicySha256 = $pathPolicyHash
    PathSafetyGuardSha256 = $pathGuardHash
    PowerShellWrapperPolicySha256 = $wrapperPolicyHash
    PowerShellWrapperGuardSha256 = $wrapperGuardHash
    PowerShellWrapperTemplateScriptSha256 = $wrapperTemplateScriptHash
    PowerShellWrapperTemplateCmdSha256 = $wrapperTemplateWrapperHash
    PowerShellWrapperTemplateManifestSha256 = $wrapperTemplateManifestHash
    RasterProvenancePolicySha256 = $rasterPolicyHash
    RasterProvenanceGuardSha256 = $rasterGuardHash
    CanonicalReviewer = $lock.canonicalId
    CanonicalFilesVerified = @($lock.files).Count
    RequiredPathsVerified = $rows.Count
    ReviewOnly = $state.reviewOnly
    TrainingEligible = $state.trainingEligible
    XmlEligible = $state.xmlEligible
    ProductionEligible = $state.productionEligible
    NextAction = $state.nextAction
} | Format-List
