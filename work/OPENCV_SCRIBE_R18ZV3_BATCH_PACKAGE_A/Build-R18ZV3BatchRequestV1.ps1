#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$modeCount = ([int][bool]$Preflight) + ([int][bool]$Test) + ([int][bool]$Build)
if ($modeCount -ne 1) { throw 'Specify exactly one of -Preflight, -Test, or -Build.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18ZT package C builder requires Windows PowerShell 5.1 exactly.'
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Get-TextSha256([string]$Text) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
        return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '')
    }
    finally { $hasher.Dispose() }
}

function Require-Pin([string]$Path, [string]$Sha256, [int64]$Bytes = -1, [string]$State = '') {
    Require ($Sha256 -cmatch '^[A-F0-9]{64}$') "R18ZT package C pin is not final: $Path"
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18ZT package C dependency absent: $Path"
    if ($Bytes -ge 0) { Require ((Get-Item -LiteralPath $Path).Length -eq $Bytes) "R18ZT package C dependency length changed: $Path" }
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18ZT package C dependency hash changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        Require ([string]$record.state -eq $State) "R18ZT package C dependency state changed: $Path"
    }
}

function Get-SafeProjectSource([string]$Project, [string]$Relative) {
    Require (-not [string]::IsNullOrWhiteSpace($Relative)) 'R18ZT payload source path is empty.'
    Require (-not [IO.Path]::IsPathRooted($Relative) -and $Relative -notmatch '(^|[/\\])\.\.([/\\]|$)') "R18ZT unsafe project source: $Relative"
    $full = [IO.Path]::GetFullPath((Join-Path $Project $Relative.Replace('/', '\')))
    Require ($full.StartsWith($Project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) "R18ZT source escaped project: $Relative"
    return $full
}

function Get-SafeChild([string]$Root, [string]$Relative) {
    Require (-not [string]::IsNullOrWhiteSpace($Relative)) 'R18ZT package path is empty.'
    Require (-not [IO.Path]::IsPathRooted($Relative) -and $Relative -notmatch '(^|[/\\])\.\.([/\\]|$)') "R18ZT unsafe package path: $Relative"
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $full = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative.Replace('/', '\')))
    Require ($full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) "R18ZT package path escaped root: $Relative"
    return $full
}

function Compare-ExactStringSet([string[]]$Expected, [string[]]$Actual, [string]$Label) {
    $expectedSorted = @($Expected | Sort-Object)
    $actualSorted = @($Actual | Sort-Object)
    Require ($expectedSorted.Count -eq $actualSorted.Count) "$Label count differs."
    Require (($expectedSorted -join "`n") -ceq ($actualSorted -join "`n")) "$Label members differ."
}

function Assert-ReviewAuthority([object]$Authority, [string]$Label) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) "$Label is not review-only."
    foreach ($field in @(
        'identityAcceptanceAuthorized', 'automaticReferenceAdmissionAuthorized',
        'holdClearanceAuthorized', 'trainingAuthorized', 'activationAuthorized',
        'xmlAuthorized', 'productionAuthorized', 'sourceMutationAuthorized',
        'sourceDeletionAuthorized'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "$Label authority changed: $field"
    }
}

function Assert-ExactLauncherChange([object[]]$Changes, [string]$LauncherSha256, [string]$Label) {
    Require ($Changes.Count -eq 1) "$Label change count changed."
    $change = $Changes[0]
    Compare-ExactStringSet @('source','destination','approvedPredecessorSha256','installedSha256','allowCreate') @($change.PSObject.Properties.Name) "$Label field set"
    Require ([string]$change.source -ceq 'payload/Invoke-R18ZTBatchLaunch.ps1') "$Label launcher source changed."
    Require ([string]$change.destination -ceq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZV3.ps1') "$Label launcher destination changed."
    Require ([string]$change.installedSha256 -ceq $LauncherSha256) "$Label installed launcher hash changed."
    Require ($change.PSObject.Properties['allowCreate'].Value -is [bool] -and [bool]$change.allowCreate) "$Label allowCreate changed."
    Compare-ExactStringSet @($LauncherSha256) @($change.approvedPredecessorSha256 | ForEach-Object { [string]$_ }) "$Label approved predecessor hashes"
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18ZT create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_RZV3'
$revision = 'R18ZV3_EXISTING_ORIENTED_CROPS_FIXED_PARALLEL_20260911A'
$runnerRevision = 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260908D'
$bindingPath = Join-Path $PSScriptRoot 'R18ZV3_FROZEN_PACKAGE_BINDINGS_V1.json'
$launcherPath = Join-Path $PSScriptRoot 'Invoke-R18ZV3BatchLaunchV1.ps1'
$payloadManifestPath = Join-Path $PSScriptRoot 'R18ZV3_PAYLOAD_MANIFEST.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION_R18ZV3.json'
$configurationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A\R18ZV3_BATCH_CONFIGURATION.json'
$designPath = Join-Path $PSScriptRoot 'R18ZV3_BATCH_PACKAGE_DESIGN_V1.json'
$importSmokePath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B\Test-R18ZTPackagedImportClosure.py'
$payloadCloneRemediationPath = Join-Path $PSScriptRoot 'R18ZV3_A1_CLONE_REMEDIATION.json'
$builderCloneRemediationPath = Join-Path $PSScriptRoot 'R18ZV3_A1_CLONE_REMEDIATION.json'
$publisherCloneRemediationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A\R18ZV3_A1_CLONE_REMEDIATION.json'
$cloneRawGatePath = Join-Path $PSScriptRoot 'R18ZV3_A1_CLONE_RAW_GATE_LOCKED_V2.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18ZV3_A1_CLONE_GATE_LOCKED_V2.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18ZV3_PATH_PLAN_GATE.json'
$powerShellGatePath = Join-Path $PSScriptRoot 'R18ZV3_POWERSHELL_SAFETY_GATE_V3.json'
$scienceGatePath = Join-Path $PSScriptRoot 'R18ZV3_SCIENCE_GATE.json'
$junctionGatePath = Join-Path $PSScriptRoot 'R18ZV3_PROPOSAL_JUNCTION_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'R18ZV3_PREACTION_GATE_V2.json'
$collisionGatePath = Join-Path $PSScriptRoot 'R18ZV3_REQUEST_ID_COLLISION_GATE_V2.json'
$collisionScannerPath = Join-Path $PSScriptRoot 'Test-R18ZV3RequestIdUniquenessV1.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$localPython = 'C:\ArgosPy313\Scripts\python.exe'
$localReferenceBundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$testRoot = 'C:\RZV3A1T'
$testWorkRoot = 'C:\RZV3A1TW'
$testOutputRoot = 'C:\RZV3A1TO'
$stageRoot = 'C:\RZV3A1P'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\RZV3A1V'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'R18ZV3_FINAL_PACKAGE_GATE.json'
$productionWorkRoot = 'D:\A2\w\ocv\R18ZV3'
$productionOutputRoot = 'D:\A2\o\ocv\R18ZV3'
$productionProposalAlias = 'D:\A2\w\ocv\R18ZV3\p'
$canonicalProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals'
$productionInstalledLauncher = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZV3.ps1'
$bindingSha = '07315387419E5396A73D23C79228682EF547E813CDC32000AAE242448B37B4E6'

Require-Pin $bindingPath $bindingSha -1 'FROZEN_R18ZV3_PACKAGE_A_V1_BINDINGS'
$binding = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
Require ([string]$binding.schema -eq 'argos_opencv_scribe_r18zv3_package_bindings_v1' -and [string]$binding.requestId -eq $requestId -and [string]$binding.packageRevision -eq $revision -and [string]$binding.runnerRevision -eq $runnerRevision) 'R18ZV3 binding changed.'
Require ([string]$binding.roots.workRoot -eq $productionWorkRoot -and [string]$binding.roots.outputRoot -eq $productionOutputRoot -and [string]$binding.roots.proposalAlias -eq $productionProposalAlias -and [string]$binding.roots.canonicalProposalRoot -eq $canonicalProposalRoot -and [string]$binding.roots.installedLauncher -eq $productionInstalledLauncher) 'R18ZT frozen binding roots changed.'
Require ([int]$binding.pathContract.maximumIdentityCharacters -eq 80 -and [int]$binding.pathContract.caseIdCharacters -eq 20 -and [int]$binding.pathContract.sourceLeafSuffixReserveCharacters -eq 32 -and [int]$binding.pathContract.outputAtomicSuffixReserveCharacters -eq 52 -and [bool]$binding.pathContract.actualFourAliasLeavesCheckedBeforeFirstWrite -and [bool]$binding.pathContract.aliasOnlySourceLeafIo) 'R18ZT path binding changed.'
$boundLongestOutput = $binding.pathContract.exactLongestEffectiveCaseOutput
Require ([string]$boundLongestOutput.leaf -ceq 'CASE_RESULT.json' -and [string]$boundLongestOutput.path -ceq 'D:\A2\o\ocv\R18ZV3\cases\FFFFFFFFFFFFFFFFFFFF\CASE_RESULT.json' -and [int]$boundLongestOutput.basePathLength -eq 62 -and [int]$boundLongestOutput.suffixReserveCharacters -eq 52 -and [int]$boundLongestOutput.effectivePathLength -eq 114 -and [int]$boundLongestOutput.effectiveComponentLength -eq 68) 'R18ZT exact longest atomic case-output binding changed.'
$boundConservativeTemp = $binding.pathContract.launcherConservativeProviderTempBudget
Require ([string]$boundConservativeTemp.leaf -ceq 'PROVIDER_RESULT.json.partial' -and [string]$boundConservativeTemp.path -ceq 'D:\A2\o\ocv\R18ZV3\cases\FFFFFFFFFFFFFFFFFFFF\PROVIDER_RESULT.json.partial' -and [int]$boundConservativeTemp.basePathLength -eq 74 -and [int]$boundConservativeTemp.baseComponentLength -eq 28 -and [int]$boundConservativeTemp.conservativeSuffixReserveCharacters -eq 52 -and [int]$boundConservativeTemp.conservativeEffectivePathLength -eq 126 -and [int]$boundConservativeTemp.conservativeEffectiveComponentLength -eq 80 -and -not [bool]$boundConservativeTemp.trueAtomicWriteTarget) 'R18ZT conservative provider-temp launcher budget changed.'
Require ([string]$binding.outputSchemas.case -ceq 'argos_opencv_scribe_r18zt_batch_case_result_v2') 'R18ZT case-result schema binding changed.'
Require ([string]$binding.routeEvidence.sourceWorkerPath -ceq 'work/OPENCV_OLS3/pkg/payload/W.ps1' -and [string]$binding.routeEvidence.sourceWorkerSha256 -eq 'E070135E8C211F2869623553C04AE2DDE65244760FC60457356B2FEEEFEED4EB' -and [string]$binding.routeEvidence.currentInstalledWorkerSha256 -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250' -and [string]$binding.routeEvidence.inheritedGenericQueueSafetyTargetWorkerSha256 -eq '244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6' -and [string]$binding.routeEvidence.workerHashRelationship -ceq 'THREE_DISTINCT_PINNED_ROLES_NO_EQUALITY_OR_EQUIVALENCE_INFERRED' -and -not [bool]$binding.routeEvidence.sourceWorkerEqualsCurrentInstalledWorkerClaimed -and -not [bool]$binding.routeEvidence.genericQueueTargetEqualsCurrentInstalledWorkerClaimed -and [string]$binding.routeEvidence.queueSafetyNature -ceq 'INHERITED_GENERIC_NOT_EXACT_CURRENT_WORKER_REHEARSAL') 'R18ZT route-worker role binding changed.'
Require ([bool]$binding.workerContract.delegateRunsInEnvelopeProcess -and [bool]$binding.workerContract.delegateSubprocessAllowed -and [int]$binding.workerContract.maximumDelegateChildProcessCount -eq 8 -and [bool]$binding.workerContract.delegateChildrenMustExitBeforeReturn -and [bool]$binding.workerContract.parentOnlyKillForbidden -and [bool]$binding.workerContract.launchedFailurePreservesResources -and [bool]$binding.workerContract.rollbackAllowedOnlyBeforeEnvelopeStart) 'parallel binding'

$artifactRows = @($binding.artifacts)
$requiredArtifactNames = @(
    'launcher','payloadManifest','maintenanceDefinition','batchConfiguration','packageDesign','packageImportSmokeTest',
    'packageCloneRemediation','publisherCloneRemediation','packageV1Withdrawal','packageV2Withdrawal','packageV3Withdrawal','packageCScaffoldAbandonment','packageCV4RemediationWithdrawal','builderSourceHarness','executionEnvelope','executionEnvelopeTest','parallelCoordinator','parallelQualificationGate','batchRunner','batchRunnerTest','batchRunnerBWithdrawal','provider','r11Analyzer',
    'developmentGate','prevalidationGate','slot21Runner','slot21Result','slot21ExecutionGate',
    'slot21Adjudication','routeWorkerSource','routePins','latestTerminalCheckpoint','returnedFileInventory','queueSafetyGate',
    'signingIdentity','signerCertificate','packageTester','localPython','referenceBundle',
    'runnerNonImageTestGate','r18ztProvider','canonicalZDevelopmentGate','r18zuNonImageRegressionGate',
    'heldOutZDiagnosticGate','r18zuReviewBatchScienceGate','approvedSourceGuard','r18zv2RunningCoexistenceGate','r18zuProvider','r18zv1DevelopmentFreeze','r18zv1Slot21Job','r18zv1Slot21Result','r18zv1Slot21CompactGate','r18zv1Slot21CorrectionGate','collectorFailure','collectorRemediationBinding','packageAPreflightWithdrawal','batchAdapter','adapterQualificationGate'
)
Compare-ExactStringSet $requiredArtifactNames @($artifactRows | ForEach-Object { [string]$_.name }) 'R18ZT frozen binding artifact names'
$resolvedArtifacts = @{}
foreach ($row in $artifactRows) {
    $path = if ([IO.Path]::IsPathRooted([string]$row.path)) { [IO.Path]::GetFullPath([string]$row.path) } else { Get-SafeProjectSource $project ([string]$row.path) }
    Require-Pin $path ([string]$row.sha256) ([int64]$row.bytes) ([string]$row.state)
    $resolvedArtifacts[[string]$row.name] = $path
}
Require ($resolvedArtifacts['launcher'] -eq [IO.Path]::GetFullPath($launcherPath) -and $resolvedArtifacts['payloadManifest'] -eq [IO.Path]::GetFullPath($payloadManifestPath) -and $resolvedArtifacts['maintenanceDefinition'] -eq [IO.Path]::GetFullPath($definitionPath) -and $resolvedArtifacts['batchConfiguration'] -eq [IO.Path]::GetFullPath($configurationPath) -and $resolvedArtifacts['packageDesign'] -eq [IO.Path]::GetFullPath($designPath) -and $resolvedArtifacts['packageImportSmokeTest'] -eq [IO.Path]::GetFullPath($importSmokePath) -and $resolvedArtifacts['executionEnvelope'] -eq [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Run-R18ZV3BatchExecutionEnvelopeV1.py')) -and $resolvedArtifacts['parallelCoordinator'] -eq [IO.Path]::GetFullPath((Join-Path $project 'work\OPENCV_SCRIBE_R18ZV3\r18zv3_parallel_batch.py')) -and -not [bool](@($artifactRows|Where-Object name -eq 'packageImportSmokeTest')[0].executedForCurrentPackage)) 'R18ZV3 core binding changed.'
Require ($resolvedArtifacts['batchAdapter'] -eq [IO.Path]::GetFullPath((Join-Path $project 'work\OPENCV_SCRIBE_R18ZV1\ArgosOpenCvScribeV1R18ZV1BatchAdapter.py')) -and $resolvedArtifacts['adapterQualificationGate'] -eq [IO.Path]::GetFullPath((Join-Path $project 'work\OPENCV_SCRIBE_R18ZV2_BATCH_PACKAGE_A\R18ZV2_ADAPTER_QUALIFICATION_GATE.json'))) 'R18ZV3 batch-adapter binding changed.'
Require ($resolvedArtifacts['packageCloneRemediation'] -eq [IO.Path]::GetFullPath($payloadCloneRemediationPath) -and $resolvedArtifacts['publisherCloneRemediation'] -eq [IO.Path]::GetFullPath($publisherCloneRemediationPath)) 'R18ZT clone-remediation binding paths changed.'
Require ($resolvedArtifacts['signingIdentity'] -eq [IO.Path]::GetFullPath($identityPath) -and $resolvedArtifacts['signerCertificate'] -eq [IO.Path]::GetFullPath($publicCertificate) -and $resolvedArtifacts['packageTester'] -eq [IO.Path]::GetFullPath($packageTester) -and $resolvedArtifacts['localPython'] -eq [IO.Path]::GetFullPath($localPython) -and $resolvedArtifacts['referenceBundle'] -eq [IO.Path]::GetFullPath($localReferenceBundle)) 'R18ZT signing/runtime binding paths changed.'
$v2Withdrawal = Get-Content -LiteralPath $resolvedArtifacts['packageV2Withdrawal'] -Raw | ConvertFrom-Json
Require ([string]$v2Withdrawal.state -ceq 'WITHDRAWN_R18ZT_PACKAGE_B_V2_BINDING_AND_DESIGN_NON_REUSABLE_NON_PARENT' -and -not [bool]$v2Withdrawal.v2SignatureCreated -and -not [bool]$v2Withdrawal.v2PublicationPerformed -and -not [bool]$v2Withdrawal.v2TargetExecuted -and -not [bool]$v2Withdrawal.v2MayBePublicationParent -and -not [bool]$v2Withdrawal.v2MayBeTemplate) 'R18ZT V2 withdrawal changed.'
$v2WithdrawalKeys = @($v2Withdrawal.withdrawn | ForEach-Object { ([string]$_.path) + '|' + ([string]$_.sha256) })
Compare-ExactStringSet @(
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_FROZEN_PACKAGE_BINDINGS_V2.json|876EA004765EB5BD1A9F456CB5E2C63E8DCA33FBC985180AB2261536C3D4C6F7',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_BATCH_PACKAGE_DESIGN_V2.json|7AB32D088ACDD5EF77B0B5EB2CD4E10BE312C17FD11B60E0E570F523170923C2'
) $v2WithdrawalKeys 'R18ZT exact V2 withdrawn artifacts'
$v3Withdrawal = Get-Content -LiteralPath $resolvedArtifacts['packageV3Withdrawal'] -Raw | ConvertFrom-Json
Require ([string]$v3Withdrawal.state -ceq 'WITHDRAWN_R18ZT_PACKAGE_B_V3_HARNESS_FAILURE_NON_REUSABLE_NON_PARENT' -and [string]$v3Withdrawal.requestId -ceq 'REQ_R18ZT1' -and [string]$v3Withdrawal.failureEvidence.state -ceq 'FAIL_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$v3Withdrawal.failureEvidence.violationCode -ceq 'MUTATION_BEFORE_PREFLIGHT_RETURN' -and [int]$v3Withdrawal.failureEvidence.violationLine -eq 625 -and [bool]$v3Withdrawal.failureEvidence.metadataOnly -and -not [bool]$v3Withdrawal.failureEvidence.targetExecuted -and -not [bool]$v3Withdrawal.mayBePackageParent -and -not [bool]$v3Withdrawal.mayBePublicationParent -and -not [bool]$v3Withdrawal.mayBeTemplate) 'R18ZT Package B V3 withdrawal changed.'
$v3WithdrawalKeys = @($v3Withdrawal.withdrawn | ForEach-Object { ([string]$_.path) + '|' + ([string]$_.sha256) })
Compare-ExactStringSet @(
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/Invoke-R18ZTBatchLaunch.ps1|4CB92574D45A36F819E565DE04482AE9CE79430E3B1C93F2FD621C9EF10549A2',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/MAINTENANCE_DEFINITION_V2.json|3BAE55419BF753F35691E6E21AFD987103F890444DA3B906DF320CA11D470DF6',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_BATCH_PACKAGE_DESIGN_V3.json|68FE5BBEEC2ECEB804065CE6EE742CDBD71D5618EEDE2E567161E2121BCA2A5D',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_FROZEN_PACKAGE_BINDINGS_V3.json|FF7B2C75B0A3C7DD29A5249D92E947424DDB407243B52C5B04FAC36DCF9AE3F1',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_PACKAGE_B_CLONE_REMEDIATION_V2.json|423C8C9EA538D6F371FAC8070259742CD577570DC6C8B33FD8EB1B509A30630C',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_PACKAGE_B_CLONE_LITERAL_RAW_GATE_V2.json|734B22B98E7FF143E948B043D662A744FC25375A5D98B0A369D873E36DA3092E',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_PACKAGE_B_CLONE_GATE_V2.json|85DE643E89ECD63464D8CF4C5613C827599532AC5446134B798771C6451B1B9E',
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B/R18ZT_PATH_PLAN_GATE_V2.json|8E300734FD99EB28729D50AE8683B5CDF948A07730BD44B506A876EBBDE9EF2B'
) $v3WithdrawalKeys 'R18ZT exact Package B V3 withdrawn artifacts'
$scaffoldAbandonment = Get-Content -LiteralPath $resolvedArtifacts['packageCScaffoldAbandonment'] -Raw | ConvertFrom-Json
Require ([string]$scaffoldAbandonment.state -ceq 'ABANDONED_R18ZT_PACKAGE_C_PRE_REMEDIATION_SCAFFOLD_NON_REUSABLE_NON_PARENT' -and -not [bool]$scaffoldAbandonment.mayBePackageParent -and -not [bool]$scaffoldAbandonment.mayBePublicationParent -and -not [bool]$scaffoldAbandonment.mayBeTemplate -and [int]$scaffoldAbandonment.actions.gatesRun -eq 0 -and [int]$scaffoldAbandonment.actions.testsRun -eq 0) 'R18ZT Package C scaffold abandonment changed.'
$v4RemediationWithdrawal = Get-Content -LiteralPath $resolvedArtifacts['packageCV4RemediationWithdrawal'] -Raw | ConvertFrom-Json
Require ([string]$v4RemediationWithdrawal.state -ceq 'WITHDRAWN_R18ZT_PACKAGE_C_CLONE_REMEDIATION_V4_NON_REUSABLE_NON_PARENT' -and [string]$v4RemediationWithdrawal.builderSourceGuard.state -ceq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and -not [bool]$v4RemediationWithdrawal.mayBePackageParent -and -not [bool]$v4RemediationWithdrawal.mayBePublicationParent -and -not [bool]$v4RemediationWithdrawal.mayBeTemplate) 'R18ZT Package C V4 remediation withdrawal changed.'
$builderSourceHarness = Get-Content -LiteralPath $resolvedArtifacts['builderSourceHarness'] -Raw | ConvertFrom-Json
Require ([string]$builderSourceHarness.state -ceq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$builderSourceHarness.powerShellScriptSha256 -ceq '882679584A018B93DA351A9481FE8C18EC194782EA16FABCFF4F1C881148468C' -and [int]$builderSourceHarness.parserErrors -eq 0 -and @($builderSourceHarness.violations).Count -eq 0 -and @($builderSourceHarness.warnings).Count -eq 0 -and [bool]$builderSourceHarness.metadataOnly -and -not [bool]$builderSourceHarness.targetExecuted) 'R18ZT Package B builder source harness evidence changed.'
$routePins = Get-Content -LiteralPath $resolvedArtifacts['routePins'] -Raw | ConvertFrom-Json
Require ([string]$routePins.route.workerSource.path -ceq [string]$binding.routeEvidence.sourceWorkerPath -and [string]$routePins.route.workerSource.sha256 -eq [string]$binding.routeEvidence.sourceWorkerSha256 -and [string]$routePins.route.installedEndpointWorkerSha256 -eq [string]$binding.routeEvidence.currentInstalledWorkerSha256 -and [string]$routePins.route.c1eQueueSafetyGate.sha256 -eq [string]($artifactRows | Where-Object name -eq 'queueSafetyGate').sha256) 'R18ZT inherited route evidence changed.'
Require ((Get-Sha256 $resolvedArtifacts['routeWorkerSource']) -eq [string]$binding.routeEvidence.sourceWorkerSha256) 'R18ZT route source-worker bytes changed.'
$queueGateEvidence = Get-Content -LiteralPath $resolvedArtifacts['queueSafetyGate'] -Raw | ConvertFrom-Json
Require ([string]$queueGateEvidence.targetWorkerSha256 -eq [string]$binding.routeEvidence.inheritedGenericQueueSafetyTargetWorkerSha256 -and [string]$queueGateEvidence.targetWorkerSha256 -ne [string]$binding.routeEvidence.currentInstalledWorkerSha256) 'R18ZT inherited generic queue target role changed.'

function Read-BoundGate([string]$Path, [string]$State) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18ZT package C gate absent: $Path"
    $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Require ([string]$record.state -eq $State -and [string]$record.requestId -eq $requestId -and [string]$record.bindingRecordSha256 -eq $bindingSha) "R18ZT package C gate binding changed: $Path"
    return $record
}

$cloneGate = Read-BoundGate $cloneGatePath 'PASS_R18ZV3_PACKAGE_A_CLONE_LITERAL_GATE'
$pathGate = Read-BoundGate $pathGatePath 'PASS_R18ZV3_PACKAGE_A_PATH_BUDGET'
$powerShellGate = Read-BoundGate $powerShellGatePath 'PASS_R18ZV3_PACKAGE_A_POWERSHELL_SAFETY'
$scienceGate = Read-BoundGate $scienceGatePath 'PASS_R18ZV3_BATCH_SCIENCE_AND_ADAPTER_EQUIVALENCE_GATE'
$junctionGate = Read-BoundGate $junctionGatePath 'PASS_R18ZV3_PARALLEL_ENVELOPE_RESOURCE_PRESERVATION_GATE'
$preaction = Read-BoundGate $preactionPath 'PASS_PREACTION_CONTRACT'
$collisionGate = $null
if ($Build) { $collisionGate = Read-BoundGate $collisionGatePath 'PASS_R18ZV3_REQUEST_ID_UNIQUENESS_ZERO_COLLISIONS' }

$builderPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$builderSha = Get-Sha256 $builderPath
$expectedClonePairs = [ordered]@{
    'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Build-R18ZV3BatchRequestV1.ps1' = $builderSha
    'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Collect-R18ZV3LaunchResponseV1.ps1' = Get-Sha256 (Join-Path $PSScriptRoot 'Collect-R18ZV3LaunchResponseV1.ps1')
    'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Invoke-R18ZV3BatchLaunchV1.ps1' = Get-Sha256 $launcherPath
    'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Publish-R18ZV3V2.ps1' = Get-Sha256 (Join-Path $PSScriptRoot 'Publish-R18ZV3V2.ps1')
    'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Test-R18ZV3RequestIdUniquenessV1.ps1' = Get-Sha256 $collisionScannerPath
    'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Run-R18ZV3BatchExecutionEnvelopeV1.py' = Get-Sha256 (Join-Path $PSScriptRoot 'Run-R18ZV3BatchExecutionEnvelopeV1.py')
}
Require ([string]$cloneGate.utilityState -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [bool]$cloneGate.sourceTemplatesGuardedBeforeGeneration -and [bool]$cloneGate.generatedArtifactsGuardedAfterGeneration -and [bool]$cloneGate.publisherIncluded) 'R18ZT clone gate contract changed.'
Require ([string]$cloneGate.packageCloneRemediationSha256 -eq [string]($artifactRows | Where-Object { [string]$_.name -eq 'packageCloneRemediation' }).sha256 -and [string]$cloneGate.publisherCloneRemediationSha256 -eq [string]($artifactRows | Where-Object { [string]$_.name -eq 'publisherCloneRemediation' }).sha256) 'R18ZT clone remediation pins changed.'
Require ([string]$cloneGate.builderCorrectionRemediationSha256 -eq (Get-Sha256 $builderCloneRemediationPath)) 'R18ZT builder correction remediation pin changed.'
Require ([string]$cloneGate.rawUtilityGatePath -ceq 'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/R18ZV3_A1_CLONE_RAW_GATE_LOCKED_V2.json' -and [string]$cloneGate.rawUtilityGateSha256 -cmatch '^[A-F0-9]{64}$') 'R18ZT raw clone utility gate pin is absent.'
Require-Pin $cloneRawGatePath ([string]$cloneGate.rawUtilityGateSha256) -1 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION'
$cloneRemediation = Get-Content -LiteralPath $builderCloneRemediationPath -Raw | ConvertFrom-Json
$rawCloneGate = Get-Content -LiteralPath $cloneRawGatePath -Raw | ConvertFrom-Json
Require ([string]$rawCloneGate.manifestSha256 -eq (Get-Sha256 $builderCloneRemediationPath) -and [int]$rawCloneGate.pairCount -eq $expectedClonePairs.Count -and @($rawCloneGate.violations).Count -eq 0 -and [bool]$rawCloneGate.metadataOnly -and -not [bool]$rawCloneGate.targetExecuted) 'R18ZT raw clone utility gate changed.'
foreach ($expectedPair in $expectedClonePairs.GetEnumerator()) {
    $matches = @($cloneGate.generatedArtifacts | Where-Object { [string]$_.path -ceq [string]$expectedPair.Key })
    Require ($matches.Count -eq 1 -and [string]$matches[0].sha256 -eq [string]$expectedPair.Value) "R18ZT clone gate artifact changed: $($expectedPair.Key)"
    $rawMatches = @($rawCloneGate.pairs | Where-Object { [string]$_.generated -ceq [string]$expectedPair.Key })
    $manifestMatches = @($cloneRemediation.pairs | Where-Object { [string]$_.generated -ceq [string]$expectedPair.Key })
    Require ($rawMatches.Count -eq 1 -and $manifestMatches.Count -eq 1 -and [string]$rawMatches[0].generatedSha256 -eq [string]$expectedPair.Value -and [string]$rawMatches[0].source -ceq [string]$manifestMatches[0].source -and [string]$rawMatches[0].sourceSha256 -eq [string]$manifestMatches[0].sourceGuardSha256) "R18ZT raw clone pair changed: $($expectedPair.Key)"
}

Require ([bool]$powerShellGate.windowsPowerShell51 -and [bool]$powerShellGate.allParserChecksPassed -and [bool]$powerShellGate.allHarnessChecksPassed -and [bool]$powerShellGate.allWrapperChecksPassed -and [bool]$powerShellGate.allCallerConsumerChecksPassed -and [string]$powerShellGate.cloneGateSha256 -eq (Get-Sha256 $cloneGatePath)) 'R18ZT PowerShell gate changed.'
$scriptChecks = @($powerShellGate.scriptChecks)
foreach ($scriptPin in @(
    [pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Invoke-R18ZV3BatchLaunchV1.ps1';sha=[string]($artifactRows | Where-Object name -eq 'launcher').sha256},
    [pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Build-R18ZV3BatchRequestV1.ps1';sha=$builderSha},
    [pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Publish-R18ZV3V2.ps1';sha=(Get-Sha256 (Join-Path $PSScriptRoot 'Publish-R18ZV3V2.ps1'))},
    [pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Collect-R18ZV3LaunchResponseV1.ps1';sha=(Get-Sha256 (Join-Path $PSScriptRoot 'Collect-R18ZV3LaunchResponseV1.ps1'))},
    [pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Test-R18ZV3RequestIdUniquenessV1.ps1';sha=(Get-Sha256 $collisionScannerPath)}
)) {
    $matches = @($scriptChecks | Where-Object { [string]$_.path -ceq [string]$scriptPin.path })
    Require ($matches.Count -eq 1 -and [string]$matches[0].sha256 -eq [string]$scriptPin.sha -and [string]$matches[0].harnessState -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$matches[0].wrapperState -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') "R18ZT PowerShell script gate changed: $($scriptPin.path)"
}

Require ([string]$junctionGate.state -eq 'PASS_R18ZV3_PARALLEL_ENVELOPE_RESOURCE_PRESERVATION_GATE' -and [bool]$junctionGate.activeEnvelopePreservedWithoutParentOnlyKill -and [bool]$junctionGate.aliasAndWorkPreservedWhileEnvelopeActive -and [int]$junctionGate.maximumDelegateChildProcessCount -eq 8 -and [bool]$junctionGate.delegateSubprocessAllowed -and [string]$junctionGate.launcherSha256 -eq [string]($artifactRows | Where-Object name -eq 'launcher').sha256) 'R18ZV3 parallel resource gate changed.'
Require ([string]$scienceGate.exactImageFirstString -eq '13HFX135SUE3' -and [bool]$scienceGate.exactDecipheringFinish -and [bool]$scienceGate.zeroWrongAcceptedOnBoundedRegression -and [int]$scienceGate.developmentAcceptedCorrect -eq 312 -and [int]$scienceGate.developmentAcceptedWrong -eq 0 -and [int]$scienceGate.developmentHeld -eq 163 -and -not [bool]$scienceGate.newSingleTargetImageFirstGain -and [bool]$scienceGate.allEightNormalViewsPresent -and [bool]$scienceGate.runnerGeneratedLabelsNotSoleProof) 'R18ZV1 science changed.'
foreach ($sciencePin in @('batchRunner','batchRunnerTest','batchRunnerBWithdrawal','provider','r18zuProvider','r11Analyzer','developmentGate','r18zv1DevelopmentFreeze','prevalidationGate','slot21Runner','slot21Result','slot21ExecutionGate','slot21Adjudication','r18zv1Slot21Job','r18zv1Slot21Result','r18zv1Slot21CompactGate','r18zv1Slot21CorrectionGate')) {
    $bindingRow = @($artifactRows | Where-Object { [string]$_.name -eq $sciencePin })[0]
    $scienceRows = @($scienceGate.artifacts | Where-Object { [string]$_.name -eq $sciencePin })
    Require ($scienceRows.Count -eq 1 -and [string]$scienceRows[0].sha256 -eq [string]$bindingRow.sha256 -and [int64]$scienceRows[0].bytes -eq [int64]$bindingRow.bytes) "R18ZT science pin changed: $sciencePin"
}
Require ([string]$scienceGate.slot21AdjudicationState -eq 'PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION' -and [string]$scienceGate.executedSlot21GateDisposition -eq 'HOLD_SUPERSEDED_BY_NO_RERUN_POST_RESULT_ADJUDICATION' -and -not [bool]$scienceGate.providerRerunForAdjudication) 'R18ZT Slot21 adjudication binding changed.'

foreach ($sciencePin in @('runnerNonImageTestGate','canonicalZDevelopmentGate','r18zuNonImageRegressionGate','heldOutZDiagnosticGate','r18zuReviewBatchScienceGate','r18zv2RunningCoexistenceGate','parallelCoordinator','parallelQualificationGate','executionEnvelopeTest','batchAdapter','adapterQualificationGate')) {
    $bindingRow = @($artifactRows | Where-Object { [string]$_.name -eq $sciencePin })[0]
    $scienceRows = @($scienceGate.artifacts | Where-Object { [string]$_.name -eq $sciencePin })
    Require ($scienceRows.Count -eq 1 -and [string]$scienceRows[0].sha256 -eq [string]$bindingRow.sha256 -and [int64]$scienceRows[0].bytes -eq [int64]$bindingRow.bytes) "R18ZU science pin changed: $sciencePin"
}
$parallelQualification = Get-Content -LiteralPath $resolvedArtifacts['parallelQualificationGate'] -Raw | ConvertFrom-Json; Require ([string]$parallelQualification.state -ceq 'PASS_R18ZV3_LOCAL_PARALLEL_COORDINATOR_QUALIFICATION' -and [int]$parallelQualification.parallelContract.defaultWorkerCount -eq 8 -and [int]$parallelQualification.parallelContract.maximumWorkerCount -eq 16 -and [bool]$parallelQualification.parallelContract.remainingLiveWorkersTerminatedAndJoined -and -not [bool]$parallelQualification.parallelContract.retryAllowed -and [int]$parallelQualification.frozenScienceBinding.acceptedWrongCount -eq 0 -and [string]$parallelQualification.frozenScienceBinding.slot21.imageFirstString -ceq '13HFX135SUE3') 'parallel qualification'
$envelopeRegression = Get-Content -LiteralPath $resolvedArtifacts['executionEnvelopeTest'] -Raw | ConvertFrom-Json; Require ([string]$envelopeRegression.state -ceq 'PASS_R18ZV3_MULTIPROCESSING_NON_IMAGE_REGRESSION_GATE' -and [int]$envelopeRegression.envelopeCases.explicitWorkerArgument -eq 8 -and [bool]$envelopeRegression.envelopeCases.successExactComplete -and [bool]$envelopeRegression.envelopeCases.leakedChildTerminatedAndJoined -and [int]$envelopeRegression.envelopeCases.residualChildCount -eq 0 -and -not [bool]$envelopeRegression.envelopeCases.falseCompleteWrittenOnChildCase -and [bool]$envelopeRegression.r18zv2RemainsUntouched -and -not [bool]$envelopeRegression.publicationPerformed) 'envelope cleanup'
$r18zuScience = Get-Content -LiteralPath $resolvedArtifacts['r18zuReviewBatchScienceGate'] -Raw | ConvertFrom-Json
Require ([string]$r18zuScience.state -ceq 'PASS_R18ZU_REVIEW_BATCH_SCIENCE_WITH_STRICT_RETENTION_HOLD' -and
    [string]$r18zuScience.decipheringFinish.slot21.imageFirstString -ceq '13HFX135SUE3' -and
    [string]$r18zuScience.decipheringFinish.heldOutZ.imageFirstString -ceq '147Z6157SUA5' -and
    [string]$r18zuScience.decipheringFinish.heldOutZ.position4 -ceq 'Z' -and
    [bool]$r18zuScience.decipheringFinish.heldOutZ.canonicalGeometryPassed -and
    [int]$r18zuScience.boundedRegression.acceptedWrong -eq 0 -and
    [int]$r18zuScience.boundedRegression.r18zuRealNonZFalseAcceptances -eq 0 -and
    [int]$r18zuScience.boundedRegression.r18zuRenderedNonZFalseAcceptances -eq 0 -and
    [bool]$r18zuScience.adjudication.exactImageFirstDecipheringFinishSatisfied -and
    [bool]$r18zuScience.adjudication.reviewBatchScienceConditionSatisfied -and
    -not [bool]$r18zuScience.adjudication.strictEightRetainedHypothesisQualificationSatisfied -and
    -not [bool]$r18zuScience.adjudication.overallProviderQualificationClaimed -and
    -not [bool]$r18zuScience.adjudication.identityAccepted -and
    -not [bool]$r18zuScience.adjudication.productionAuthorized) 'R18ZU review-batch science authority changed.'
$coexistence = Get-Content -LiteralPath $resolvedArtifacts['r18zv2RunningCoexistenceGate'] -Raw | ConvertFrom-Json
Require ([string]$coexistence.state -ceq 'PASS_R18ZV2_RUNNING_STATE_BOUND_FOR_LOCAL_SUCCESSOR_PREPARATION' -and [string]$coexistence.predecessorRequestId -ceq 'REQ_RZV2' -and [string]$coexistence.successorRequestId -ceq 'REQ_RZV3' -and [bool]$coexistence.latestAuthenticatedDirectObservation.pending -and [string]$coexistence.latestAuthenticatedDirectObservation.workerState -ceq 'RUNNING' -and [int]$coexistence.latestAuthenticatedDirectObservation.qualifiedCaseCount -eq 1044 -and [int]$coexistence.latestAuthenticatedDirectObservation.completedCount -eq 53 -and -not [bool]$coexistence.latestAuthenticatedDirectObservation.completeObserved -and -not [bool]$coexistence.latestAuthenticatedDirectObservation.failureObserved -and [bool]$coexistence.coexistenceContract.r18zv2MustNotBeStoppedBeforeCompleteR18zv3PackagePass -and [bool]$coexistence.coexistenceContract.successorMayBePreparedAndSignedLocally -and -not [bool]$coexistence.coexistenceContract.successorMayBePublishedFromThisGate -and [bool]$coexistence.coexistenceContract.freshDirectQueueAndEndpointHealthAuditRequiredBeforeAnyPublication -and -not [bool]$coexistence.r18zv2StopPerformed -and -not [bool]$coexistence.externalAccessPerformedForThisGate) 'R18ZV2 running coexistence gate changed.'
$adapterGate = Get-Content -LiteralPath $resolvedArtifacts['adapterQualificationGate'] -Raw | ConvertFrom-Json
Require ([string]$adapterGate.state -ceq 'PASS_R18ZV2_BATCH_ADAPTER_EXACT_SEAM_ALGORITHM_UNCHANGED' -and [string]$adapterGate.requestId -ceq 'REQ_RZV2' -and
    [string]$adapterGate.adapter.sha256 -ceq [string]($artifactRows | Where-Object name -eq 'batchAdapter').sha256 -and
    [string]$adapterGate.wrappedProvider.sha256 -ceq [string]($artifactRows | Where-Object name -eq 'provider').sha256 -and
    [bool]$adapterGate.entryProviderTranslation.runJobIdentityPreserved -and [bool]$adapterGate.entryProviderTranslation.r18zvIdentityPreserved -and
    [bool]$adapterGate.entryProviderTranslation.r18hIdentityPreserved -and -not [bool]$adapterGate.behavioralBoundary.rankingLogicChanged -and
    -not [bool]$adapterGate.behavioralBoundary.envelopeLogicChanged -and -not [bool]$adapterGate.behavioralBoundary.referenceLogicChanged -and
    -not [bool]$adapterGate.behavioralBoundary.resultLogicChanged -and
    -not [bool]$adapterGate.tests.imageBytesRead -and -not [bool]$adapterGate.tests.providerRunPerformed) 'R18ZV3 adapter qualification changed.'

$r18zv1Development = Get-Content -LiteralPath $resolvedArtifacts['r18zv1DevelopmentFreeze'] -Raw | ConvertFrom-Json; Require ([string]$r18zv1Development.state -ceq 'PASS_R18ZV1_TARGET_EXCLUDED_GENERIC_BOUNDARY_FROZEN_BEFORE_BATCH_VALIDATION' -and [decimal]$r18zv1Development.boundaryDerivation.frozenMaximumNormalizedDistance -eq [decimal]::Parse('0.83',[Globalization.CultureInfo]::InvariantCulture) -and [int]$r18zv1Development.developmentOutcomeAtFrozenBoundary.r18ztAcceptedCorrect -eq 312 -and [int]$r18zv1Development.developmentOutcomeAtFrozenBoundary.r18ztAcceptedWrong -eq 0 -and [int]$r18zv1Development.developmentOutcomeAtFrozenBoundary.r18ztHeld -eq 163 -and -not [bool]$r18zv1Development.runtimeRule.sparseOrUnobservedAdmissionAdded -and -not [bool]$r18zv1Development.authority.productionAuthorized) 'R18ZV1 development changed.'
$r18zv1Compact = Get-Content -LiteralPath $resolvedArtifacts['r18zv1Slot21CompactGate'] -Raw | ConvertFrom-Json; Require ([string]$r18zv1Compact.state -ceq 'PASS_R18ZV1_SLOT21_EXACT_IMAGE_FIRST_DIAGNOSTIC' -and [string]$r18zv1Compact.result.selectedHypothesis.imageFirstString -ceq '13HFX135SUE3' -and [bool]$r18zv1Compact.fullChain.allEightNormalViewsPresent -and [int]$r18zv1Compact.fullChain.attemptCount -eq 8 -and [int]$r18zv1Compact.providerRunCount -eq 1 -and -not [bool]$r18zv1Compact.wrongAccepted -and -not [bool]$r18zv1Compact.result.eligibleIdentity) 'R18ZV1 Slot21 gate changed.'
$r18zv1Correction = Get-Content -LiteralPath $resolvedArtifacts['r18zv1Slot21CorrectionGate'] -Raw | ConvertFrom-Json; Require ([string]$r18zv1Correction.state -ceq 'PASS_CORRECTION_A_FIRST_COMPLETED_B_DUPLICATE_EXCLUDED_SCIENCE_UNCHANGED' -and [string]$r18zv1Correction.authoritativeFirstCompletion.result.sha256 -ceq [string](@($artifactRows|Where-Object name -eq 'r18zv1Slot21Result')[0].sha256) -and [string]$r18zv1Correction.authoritativeFirstCompletion.compactGate.sha256 -ceq [string](@($artifactRows|Where-Object name -eq 'r18zv1Slot21CompactGate')[0].sha256) -and [bool]$r18zv1Correction.correctedOutcome.slot21Exact -and -not [bool]$r18zv1Correction.correctedOutcome.newSingleTargetImageFirstGain -and -not [bool]$r18zv1Correction.authority.productionAuthorized) 'R18ZV1 correction changed.'
$developmentEvidence = Get-Content -LiteralPath $resolvedArtifacts['developmentGate'] -Raw | ConvertFrom-Json
Require ([string]$developmentEvidence.state -ceq 'PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION' -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.referenceQueries -eq 475 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.exactFoldCount -eq 49 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.acceptedCorrect -eq 312 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.acceptedWrong -eq 0 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.held -eq 163 -and [bool]$developmentEvidence.criteria.k25vDiagnosticHoldPreserved -and [bool]$developmentEvidence.criteria.k25vWrongPositions2And4NotRescued -and -not [bool]$developmentEvidence.criteria.resultAuthorityExpanded -and -not [bool]$developmentEvidence.invariants.checksumUsedForSelectionOrAcceptance) 'R18ZT inherited development changed.'
$adjudicationEvidence = Get-Content -LiteralPath $resolvedArtifacts['slot21Adjudication'] -Raw | ConvertFrom-Json
Require ([string]$adjudicationEvidence.state -ceq 'PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION' -and [string]$adjudicationEvidence.decipheringFinish.imageFirstString -ceq '13HFX135SUE3' -and [bool]$adjudicationEvidence.decipheringFinish.exact -and [int]$adjudicationEvidence.decipheringFinish.wrongImageFirstAcceptedCount -eq 0 -and [int]$adjudicationEvidence.executedRun.providerRunCount -eq 1 -and [int]$adjudicationEvidence.executedRun.attemptCount -eq 8 -and [int]$adjudicationEvidence.executedRun.directStructuralEvaluatorCallsByHarness -eq 0 -and -not [bool]$adjudicationEvidence.invariants.truthOrChecksumUsedForSelection -and -not [bool]$adjudicationEvidence.authority.publicationSelfAuthority -and @($adjudicationEvidence.holdsAndAuthority.resultHoldsPreserved).Count -eq 1 -and [string]$adjudicationEvidence.holdsAndAuthority.resultHoldsPreserved[0].code -ceq 'SCRIBE_REFERENCE_COVERAGE_HOLD') 'R18ZT inherited adjudication changed.'
$executedGateEvidence = Get-Content -LiteralPath $resolvedArtifacts['slot21ExecutionGate'] -Raw | ConvertFrom-Json
Require ([string]$executedGateEvidence.state -ceq 'HOLD_R18ZT_SLOT21_FINISH_CRITERIA_NOT_MET_NO_RETRY' -and [int]$executedGateEvidence.providerRunCount -eq 1 -and [int]$executedGateEvidence.fullChain.attemptCount -eq 8 -and [int]$executedGateEvidence.fullChain.directStructuralEvaluatorCallsByHarness -eq 0 -and -not [bool]$executedGateEvidence.retryAuthorized) 'R18ZT inherited execution gate changed.'
$executedResultEvidence = Get-Content -LiteralPath $resolvedArtifacts['slot21Result'] -Raw | ConvertFrom-Json
Require ([string]$executedResultEvidence.imageFirstString -ceq '13HFX135SUE3' -and [string]$executedResultEvidence.selectedHypothesis.channel -ceq 'BF' -and [string]$executedResultEvidence.selectedHypothesis.polarity -ceq 'DARK' -and [string]$executedResultEvidence.selectedHypothesis.direction -ceq 'FORWARD' -and [decimal]$executedResultEvidence.selectedHypothesis.selectionScore -eq [decimal]::Parse('0.9117836040446633',[Globalization.CultureInfo]::InvariantCulture) -and @($executedResultEvidence.holds).Count -eq 1 -and [string]$executedResultEvidence.holds[0].code -ceq 'SCRIBE_REFERENCE_COVERAGE_HOLD' -and -not [bool]$executedResultEvidence.eligibleIdentity) 'R18ZT inherited result changed.'

Require ([int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80 -and [int]$pathGate.unsafePathCount -eq 0 -and [string]$pathGate.proposalAlias -eq $productionProposalAlias -and [string]$pathGate.canonicalProposalRoot -eq $canonicalProposalRoot -and [int]$pathGate.maximumIdentityCharacters -eq 80 -and [int]$pathGate.caseIdCharacters -eq 20 -and [int]$pathGate.sourceLeafSuffixReserveCharacters -eq 32 -and [int]$pathGate.outputAtomicSuffixReserveCharacters -eq 52 -and [int]$pathGate.canonicalLexicalLongestEffectiveLength -eq 236 -and [int]$pathGate.aliasLongestEffectiveLength -eq 188 -and [bool]$pathGate.actualFourAliasLeavesCheckedByLauncherBeforeFirstWrite) 'R18ZT path gate changed.'
$pathLongestOutput = $pathGate.exactLongestEffectiveCaseOutput
Require ([string]$pathLongestOutput.leaf -ceq 'CASE_RESULT.json' -and [string]$pathLongestOutput.path -ceq 'D:\A2\o\ocv\R18ZV3\cases\FFFFFFFFFFFFFFFFFFFF\CASE_RESULT.json' -and [int]$pathLongestOutput.basePathLength -eq 62 -and [int]$pathLongestOutput.suffixReserveCharacters -eq 52 -and [int]$pathLongestOutput.effectivePathLength -eq 114 -and [int]$pathLongestOutput.effectiveComponentLength -eq 68) 'R18ZT path-gate true atomic longest-output fact changed.'
$pathConservativeTemp = $pathGate.launcherConservativeProviderTempBudget
Require ([string]$pathConservativeTemp.leaf -ceq 'PROVIDER_RESULT.json.partial' -and [string]$pathConservativeTemp.path -ceq 'D:\A2\o\ocv\R18ZV3\cases\FFFFFFFFFFFFFFFFFFFF\PROVIDER_RESULT.json.partial' -and [int]$pathConservativeTemp.basePathLength -eq 74 -and [int]$pathConservativeTemp.baseComponentLength -eq 28 -and [int]$pathConservativeTemp.conservativeSuffixReserveCharacters -eq 52 -and [int]$pathConservativeTemp.conservativeEffectivePathLength -eq 126 -and [int]$pathConservativeTemp.conservativeEffectiveComponentLength -eq 80 -and -not [bool]$pathConservativeTemp.trueAtomicWriteTarget) 'R18ZT path-gate conservative provider-temp fact changed.'
$boundCasePathKeys = @($binding.pathContract.caseOutputLeaves | ForEach-Object { ([string]$_.leaf) + '|' + ([string]$_.writer) + '|' + ([string]$_.basePathLength) + '|' + ([string]$_.baseComponentLength) + '|' + ([string]$_.suffixReserveCharacters) + '|' + ([string]$_.effectivePathLength) + '|' + ([string]$_.effectiveComponentLength) })
$gatedCasePathKeys = @($pathGate.caseOutputLeaves | ForEach-Object { ([string]$_.leaf) + '|' + ([string]$_.writer) + '|' + ([string]$_.basePathLength) + '|' + ([string]$_.baseComponentLength) + '|' + ([string]$_.suffixReserveCharacters) + '|' + ([string]$_.effectivePathLength) + '|' + ([string]$_.effectiveComponentLength) })
Compare-ExactStringSet $boundCasePathKeys $gatedCasePathKeys 'R18ZT exact case-output path facts'
$preactionResult = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18ZT package C preaction utility changed.'
$bindingDependency = @($preaction.dependencies | Where-Object { [string]$_.path -eq 'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/R18ZV3_FROZEN_PACKAGE_BINDINGS_V1.json' })
$builderDependency = @($preaction.dependencies | Where-Object { [string]$_.path -eq 'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/Build-R18ZV3BatchRequestV1.ps1' })
Require ($bindingDependency.Count -eq 1 -and [string]$bindingDependency[0].sha256 -eq $bindingSha -and $builderDependency.Count -eq 1 -and [string]$builderDependency[0].sha256 -eq $builderSha -and [string]$preaction.historyAuditSha256 -eq 'F3E7AF05017BF00ADEDFFA7A06D89155E2E5C1BF76A64E643E4972F00737BC9C') 'R18ZT package C preaction dependencies changed.'

$requiredCollisionNamespaces = @('SHARE_REQUEST_UPLOAD_PROCESSED_ARCHIVE','SHARE_RESPONSE_ARCHIVE')
$optionalCollisionNamespaces = @('LOCAL_ROUTE_REQUEST_TO_ARGOS','LOCAL_ROUTE_REQUEST_FROM_GATEWAY','LOCAL_ROUTE_TO_JBOD','LOCAL_ENDPOINT_LEDGER','LOCAL_ROUTE_TO_ARGOS','LOCAL_ROUTE_FROM_JBOD','LOCAL_ROUTE_TO_GATEWAY')
if ($Build) {
    Require ([string]$collisionGate.schema -ceq 'argos_r18zv3_request_id_uniqueness_gate_v1' -and [string]$collisionGate.requestId -ceq $requestId -and [string]$collisionGate.scannerSha256 -ceq (Get-Sha256 $collisionScannerPath) -and [string]$collisionGate.scanPurpose -ceq 'PRE_SIGNATURE') 'R18ZV3 collision gate changed.'
    Compare-ExactStringSet @($requiredCollisionNamespaces + $optionalCollisionNamespaces) @($collisionGate.namespaces | ForEach-Object { [string]$_.id }) 'R18ZT collision namespaces'
    foreach ($name in $requiredCollisionNamespaces) {
        $row = @($collisionGate.namespaces | Where-Object { [string]$_.id -ceq $name })
        Require ($row.Count -eq 1 -and [bool]$row[0].available -and [int]$row[0].errors -eq 0) "R18ZT required collision namespace not scanned: $name"
    }
    foreach ($row in @($collisionGate.namespaces)) { Require ((-not [bool]$row.available) -or [int]$row.errors -eq 0) "R18ZT accessible collision namespace scan failed: $($row.id)" }
    Require ([int]$collisionGate.collisionCount -eq 0 -and [bool]$collisionGate.requestUploadProcessedAndArchiveScanned -and [bool]$collisionGate.responseArchiveScanned -and [bool]$collisionGate.endpointLedgerNamespaceChecked -and [bool]$collisionGate.allAccessibleNamespacesScanned -and -not [bool]$collisionGate.imageMembersRead -and [bool]$collisionGate.noOtherPendingRequests -and [bool]$collisionGate.localGateMutationPerformed -and -not [bool]$collisionGate.externalMutationsPerformed -and [bool]$collisionGate.mutationsPerformed) 'R18ZT collision gate changed.'
    $collisionChecked = [DateTimeOffset]::Parse([string]$collisionGate.checkedUtc)
    Require ($collisionChecked -le [DateTimeOffset]::UtcNow.AddMinutes(5) -and $collisionChecked -ge [DateTimeOffset]::UtcNow.AddHours(-2)) 'R18ZT collision gate is stale or future-dated.'
}

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $payloadManifestPath -Raw | ConvertFrom-Json
$design = Get-Content -LiteralPath $designPath -Raw | ConvertFrom-Json
$configuration = Get-Content -LiteralPath $configurationPath -Raw | ConvertFrom-Json
Require ([string]$definition.schema -eq 'argos_opencv_scribe_r18zt_maintenance_definition_v2' -and [string]$definition.revision -eq $revision -and [string]$definition.requestId -eq $requestId -and [string]$definition.state -eq 'FROZEN_UNPUBLISHED') 'R18ZT maintenance definition changed.'
Require ([string]$definition.entryPoint -eq 'payload/Invoke-R18ZTBatchLaunch.ps1' -and [string]$definition.rehearsal.requiredState -eq 'PASS_R18ZT_BATCH_WORKER_STARTED' -and -not [bool]$definition.rehearsal.completionClaimed) 'R18ZT launch-only endpoint contract changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1 -and [string]$definition.allowedProcessActions[0] -eq 'START_ONE_OWNED_BACKGROUND_R18ZT_BATCH_WORKER') 'R18ZT task/process boundary changed.'
Require ([bool]$definition.ownedWorkerContract.executionEnvelopeInvokesDelegateInProcess -and [bool]$definition.ownedWorkerContract.delegateSubprocessAllowed -and [int]$definition.ownedWorkerContract.maximumDelegateChildProcessCount -eq 8 -and [bool]$definition.ownedWorkerContract.delegateChildrenMustExitBeforeReturn -and [bool]$definition.ownedWorkerContract.parentOnlyKillForbidden -and [bool]$definition.ownedWorkerContract.launchedFailurePreservesResources -and [bool]$definition.ownedWorkerContract.rollbackAllowedOnlyBeforeEnvelopeStart) 'parallel definition'
Assert-ReviewAuthority $definition.authority 'R18ZT maintenance definition'
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18zt_payload_manifest_v2' -and [string]$manifest.revision -eq $revision -and [string]$manifest.state -eq 'FROZEN_UNPUBLISHED' -and [bool]$manifest.finalizationComplete) 'R18ZT payload manifest changed.'
Assert-ReviewAuthority $manifest.authority 'R18ZT payload manifest'
Require ([string]$design.schema -ceq 'argos_opencv_scribe_r18zt_batch_package_design_v5' -and [string]$design.state -eq 'FROZEN_UNPUBLISHED' -and [string]$design.artifactLifecycle -eq 'FROZEN' -and [string]$design.requestId -eq $requestId -and [string]$design.revision -eq $revision -and [string]$design.launchSemantics.executionEnvelopeDelegateMode -eq 'IN_PROCESS_PUBLIC_MAIN_WITH_FIXED_PROCESS_ISOLATED_CHILDREN' -and [bool]$design.launchSemantics.delegateChildrenMustExitBeforeReturn -and [bool]$design.launchSemantics.parentOnlyKillForbidden -and [bool]$design.launchSemantics.launchedFailurePreservesAliasWorkAndOutput -and [bool]$design.launchSemantics.rollbackAllowedOnlyBeforeEnvelopeStart) 'package design'
Require ([string]$design.route.sourceWorkerSha256 -eq [string]$binding.routeEvidence.sourceWorkerSha256 -and [string]$design.route.currentInstalledWorkerSha256 -eq [string]$binding.routeEvidence.currentInstalledWorkerSha256 -and [string]$design.route.queueSafetyGateTargetWorkerSha256 -eq [string]$binding.routeEvidence.inheritedGenericQueueSafetyTargetWorkerSha256 -and [string]$design.route.workerHashRelationship -ceq 'THREE_DISTINCT_PINNED_ROLES_NO_EQUALITY_OR_EQUIVALENCE_INFERRED' -and -not [bool]$design.route.sourceWorkerEqualsCurrentInstalledWorkerClaimed -and -not [bool]$design.route.queueSafetyTargetEqualsCurrentInstalledWorkerClaimed) 'R18ZT package-design worker roles changed.'
Require ([int]$design.proposalAliasContract.caseIdCharacters -eq 20 -and [int]$design.proposalAliasContract.sourceLeafSuffixReserveCharacters -eq 32 -and [int]$design.proposalAliasContract.outputAtomicSuffixReserveCharacters -eq 52 -and [int]$design.proposalAliasContract.exactLongestAtomicOutputLeaf.basePathLength -eq 62 -and [int]$design.proposalAliasContract.exactLongestAtomicOutputLeaf.effectivePathLength -eq 114 -and [int]$design.proposalAliasContract.exactLongestAtomicOutputLeaf.effectiveComponentLength -eq 68 -and [int]$design.proposalAliasContract.launcherConservativeProviderTempBudget.conservativeEffectivePathLength -eq 126 -and [int]$design.proposalAliasContract.launcherConservativeProviderTempBudget.conservativeEffectiveComponentLength -eq 80 -and -not [bool]$design.proposalAliasContract.launcherConservativeProviderTempBudget.trueAtomicWriteTarget) 'R18ZT package-design path facts changed.'
Require ([string]$configuration.schema -eq [string]$binding.runnerConfigSchema -and [string]$configuration.revision -eq $runnerRevision -and [string]$configuration.canonicalProposalRoot -eq $canonicalProposalRoot -and [string]$configuration.proposalRoot -eq $productionProposalAlias -and [int]$configuration.limits.maximumIdentityCharacters -eq 80) 'R18ZT runner configuration changed.'

$outputs = @($definition.entryPointOutputs)
foreach ($outputPin in @(
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZV3\LAUNCH.json';schema='argos_opencv_scribe_r18zt_batch_launch_v2'},
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZV3\RUNNING.json';schema=[string]$binding.outputSchemas.progress},
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZV3\COMPLETE.json';schema=[string]$binding.outputSchemas.complete},
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZV3\STATUS.json';schema=[string]$binding.outputSchemas.status}
)) {
    $matches = @($outputs | Where-Object { [string]$_.path -ceq [string]$outputPin.path })
    Require ($matches.Count -eq 1 -and [string]$matches[0].schema -eq [string]$outputPin.schema) "R18ZT output schema changed: $($outputPin.path)"
}
$runningOutput = @($outputs | Where-Object { [string]$_.path -ceq 'D:\A2\o\ocv\R18ZV3\RUNNING.json' })[0]
Compare-ExactStringSet @($binding.progressPointerAllowedStates) @($runningOutput.allowedStates) 'R18ZT progress-pointer states'
Require ([bool]$runningOutput.terminalStateMayAppearInAtomicProgressPointer -and -not [bool]$runningOutput.terminalSubstitute) 'R18ZT progress-pointer semantics changed.'
$failureOutput = @($outputs | Where-Object { [string]$_.path -ceq 'D:\A2\o\ocv\R18ZV3\FAILURE.json' })[0]
$failureKeys = @($failureOutput.variants | ForEach-Object { ([string]$_.producer) + '|' + ([string]$_.schema) + '|' + ([string]$_.requiredState) })
Compare-ExactStringSet @('LAUNCHER|argos_opencv_scribe_r18zt_batch_launch_failure_v2|HOLD_R18ZT_BATCH_LAUNCH_FAILURE','WORKER_EXECUTION_ENVELOPE|argos_opencv_scribe_r18zt_batch_worker_failure_v2|HOLD_R18ZT_BATCH_WORKER_FAILURE') $failureKeys 'R18ZT FAILURE variants'
Compare-ExactStringSet @('LAUNCH.json','RUNNING.json','COMPLETE.json','FAILURE.json') @($definition.boundedFollowupContract.singleExactLeafProbe) 'R18ZT +12h exact probe leaves'
Require (-not [bool]$definition.boundedFollowupContract.processOrTaskQueryAllowed -and -not [bool]$definition.boundedFollowupContract.resultTreeEnumerationAllowed -and -not [bool]$definition.boundedFollowupContract.klarfOrProposalTreeEnumerationAllowed -and -not [bool]$definition.boundedFollowupContract.statusJsonMaySubstituteForComplete) 'R18ZT +12h probe prohibitions changed.'

$payloadFiles = @($manifest.files)
Require ($payloadFiles.Count -ge 4 -and $payloadFiles.Count -le 96) 'R18ZT payload count is outside the bound.'
$installSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $payloadFiles) {
    $relative = [string]$file.installRelativePath
    Require ($installSet.Add($relative)) "R18ZT duplicate payload install path: $relative"
    $source = Get-SafeProjectSource $project ([string]$file.sourcePath)
    Require-Pin $source ([string]$file.sha256) ([int64]$file.bytes)
}

$expectedLeaves = New-Object Collections.Generic.List[string]
foreach ($leaf in @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload/Invoke-R18ZTBatchLaunch.ps1','payload/R18ZT_PAYLOAD_MANIFEST.json')) { $expectedLeaves.Add($leaf) }
foreach ($file in $payloadFiles) { $expectedLeaves.Add('payload/files/' + ([string]$file.installRelativePath).Replace('\', '/')) }
$expectedLeafArray = @($expectedLeaves.ToArray())
$expectedLeafSetSha = 'BCF9FEAE961DBFD8F06F60D76EECD9A3C4BDE8ABCB016726673AEA66D206A9ED'
$computedExpectedLeafSetSha = Get-TextSha256 ((@($pathGate.plannedFinalZipMembers) -join "`n") + "`n")
Require ($computedExpectedLeafSetSha -ceq $expectedLeafSetSha) 'R18ZU expected ZIP member-set hash changed.'
Require ([int]$pathGate.plannedFinalZipMemberCount -eq $expectedLeafArray.Count -and [string]$pathGate.plannedFinalZipMemberSetSha256 -ceq $expectedLeafSetSha) 'R18ZT path-gate membership changed.'
Compare-ExactStringSet $expectedLeafArray @($pathGate.plannedFinalZipMembers) 'R18ZT path-gate package members'

$freshPathList = New-Object Collections.Generic.List[string]
if ($Test) {
    foreach ($path in @($testRoot,$testWorkRoot,$testOutputRoot)) { $freshPathList.Add($path) }
}
elseif ($Build) {
    foreach ($path in @($stageRoot,$readyRoot,$stageZip,$verifyRoot,$finalRoot,$finalPartial,$finalGatePath)) { $freshPathList.Add($path) }
}
else {
    foreach ($path in @($testRoot,$testWorkRoot,$testOutputRoot,$stageRoot,$readyRoot,$stageZip,$verifyRoot,$finalRoot,$finalPartial,$finalGatePath)) { $freshPathList.Add($path) }
}
$freshPaths = @($freshPathList.ToArray())
foreach ($path in $freshPaths) { Require (-not (Test-Path -LiteralPath $path)) "R18ZT fresh local output exists: $path" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zv3_batch_build_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZV3_PACKAGE_A_BUILD_PREFLIGHT'
        requestId = $requestId
        bindingRecordSha256 = $bindingSha
        payloadFileCount = $payloadFiles.Count
        plannedZipMemberCount = $expectedLeafArray.Count
        collisionScopeCount = ($requiredCollisionNamespaces.Count + $optionalCollisionNamespaces.Count)
        targetWritesPerformed = $false
        signerAccessed = $false
        packageBuilt = $false
        publicationPerformed = $false
        completionClaimed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$activeReady = if ($Test) { Join-Path $testRoot ($requestId + '.unsigned-test') } else { $readyRoot }
[void](New-Item -ItemType Directory -Path (Join-Path $activeReady 'payload\files') -Force)
$activePayload = Join-Path $activeReady 'payload'
Copy-Item -LiteralPath $launcherPath -Destination (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1')
Copy-Item -LiteralPath $payloadManifestPath -Destination (Join-Path $activePayload 'R18ZT_PAYLOAD_MANIFEST.json')
$manifestFiles = New-Object Collections.Generic.List[object]
foreach ($fixed in @([pscustomobject]@{path='payload/Invoke-R18ZTBatchLaunch.ps1';source=$launcherPath},[pscustomobject]@{path='payload/R18ZT_PAYLOAD_MANIFEST.json';source=$payloadManifestPath})) {
    $manifestFiles.Add([ordered]@{path=[string]$fixed.path;bytes=[int64](Get-Item -LiteralPath $fixed.source).Length;sha256=Get-Sha256 $fixed.source})
}
foreach ($file in $payloadFiles) {
    $source = Get-SafeProjectSource $project ([string]$file.sourcePath)
    $relative = 'payload/files/' + ([string]$file.installRelativePath).Replace('\', '/')
    $destination = Get-SafeChild $activeReady $relative
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath $source -Destination $destination
    Require-Pin $destination ([string]$file.sha256) ([int64]$file.bytes)
    $manifestFiles.Add([ordered]@{path=$relative;bytes=[int64]$file.bytes;sha256=[string]$file.sha256})
}

$launcherSha = [string]($artifactRows | Where-Object name -eq 'launcher').sha256
$localPythonSha = [string]($artifactRows | Where-Object name -eq 'localPython').sha256
$runnerSha = [string]($artifactRows | Where-Object name -eq 'batchRunner').sha256; $coordinatorSha = [string]($artifactRows | Where-Object name -eq 'parallelCoordinator').sha256
$providerSha = [string]($artifactRows | Where-Object name -eq 'batchAdapter').sha256
$wrappedProviderSha = [string]($artifactRows | Where-Object name -eq 'provider').sha256
$r11AnalyzerSha = [string]($artifactRows | Where-Object name -eq 'r11Analyzer').sha256
Assert-ExactLauncherChange @($definition.changes) $launcherSha 'R18ZT maintenance definition'
$stagedPreflight = (& (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1') -Preflight -Rehearsal -PackageValidationOnly -PayloadRoot $activePayload -WorkRoot $testWorkRoot -OutputRoot $testOutputRoot -CanonicalProposalRoot 'C:\RZV3A1_PROPOSALS_NOT_ACCESSED' -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$stagedPreflight.state -eq 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' -and [bool]$stagedPreflight.sourceInventoryAndHashingDeferredToOwnedWorker -and -not [bool]$stagedPreflight.sourceImageBytesHashed -and -not [bool]$stagedPreflight.pixelsDecoded -and -not [bool]$stagedPreflight.targetWritesPerformed -and -not [bool]$stagedPreflight.processStarted -and -not [bool]$stagedPreflight.completionClaimed) 'R18ZT staged static launcher preflight failed.'
$stagedPackageHashClosure = [ordered]@{
    state = 'PASS_R18ZV3_STAGED_PACKAGED_HASH_CLOSURE_NO_IMAGE'
    runnerSha256 = $runnerSha; parallelCoordinatorSha256 = $coordinatorSha; workerCount = 8; parallelExecutionMode = 'FIXED_PROCESS_ISOLATED_SHARDS'
    providerSha256 = $providerSha
    wrappedProviderSha256 = $wrappedProviderSha
    r18ztProviderSha256 = [string]($artifactRows | Where-Object name -eq 'r18ztProvider').sha256
    canonicalZDevelopmentGateSha256 = [string]($artifactRows | Where-Object name -eq 'canonicalZDevelopmentGate').sha256
    sourceFullChainPreviouslyExecuted = $true
    runJobCalled = $false
    analyzeImagesCalled = $false
    imageBytesRead = $false
}

if ($Test) {
    $stagedJunctionGate = (& (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1') -JunctionGate -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
    Require ([string]$stagedJunctionGate.state -eq 'PASS_R18ZV3_PARALLEL_ENVELOPE_RESOURCE_PRESERVATION_GATE' -and [string]$stagedJunctionGate.launcherSha256 -eq $launcherSha -and [bool]$stagedJunctionGate.activeEnvelopeHoldCasePassed -and [bool]$stagedJunctionGate.fastCompleteReportingFailureCasePassed -and [bool]$stagedJunctionGate.invalidCompletePreservationCasePassed -and [bool]$stagedJunctionGate.preexistingRootCollisionRejectedBeforeProcess -and [bool]$stagedJunctionGate.secondFreshControlPassed -and [int]$stagedJunctionGate.completeFailureCoexistenceCount -eq 0 -and [int]$stagedJunctionGate.maximumDelegateChildProcessCount -eq 8 -and [bool]$stagedJunctionGate.delegateSubprocessAllowed -and -not [bool]$stagedJunctionGate.residualTestRootPresent) 'R18ZV3 staged production launcher gate failed.'
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zv3_batch_unsigned_test_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZV3_PACKAGE_A_UNSIGNED_TEST'
        requestId = $requestId
        bindingRecordSha256 = $bindingSha
        stagedPayloadFileCount = $manifestFiles.Count
        staticEntrypointPreflight = $stagedPreflight
        stagedPackageHashClosure = $stagedPackageHashClosure
        productionLauncherGate = $stagedJunctionGate
        proposalJunctionGateSha256 = Get-Sha256 $junctionGatePath
        executionEnvelopeInProcessDelegate = $true
        signerAccessed = $false
        signatureCreated = $false
        publicationPerformed = $false
        completionClaimed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12
    return
}

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $certificateMatches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint })
    Require ($certificateMatches.Count -eq 1 -and $certificateMatches[0].HasPrivateKey) 'R18ZT signer certificate/private key changed.'
    $certificate = $certificateMatches[0]
}
finally { $store.Close(); $store.Dispose() }

$created = [DateTimeOffset]::UtcNow
$requestManifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = $requestId
    createdUtc = $created.ToString('o')
    expiresUtc = $created.AddDays(7).ToString('o')
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    handler = ''
    maxResultBytes = [int64]$definition.maxResultBytes
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    credentialsIncluded = $false
    signerThumbprint = $thumbprint
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    files = $manifestFiles.ToArray()
    entryPoint = [string]$definition.entryPoint
    rehearsal = $definition.rehearsal
    changes = @($definition.changes)
    entryPointMutations = @($definition.entryPointMutations)
    entryPointOutputs = @($definition.entryPointOutputs)
    sourceProcessingContract = $definition.sourceProcessingContract
    timeoutContract = $definition.timeoutContract
    collisionContract = $definition.collisionContract
    allowedTaskActions = @($definition.allowedTaskActions)
    allowedProcessActions = @($definition.allowedProcessActions)
    publication = $definition.publication
}
Assert-ExactLauncherChange @($requestManifest.changes) $launcherSha 'R18ZT staged signed manifest'
$requestManifestPath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($requestManifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($requestManifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
Require ($null -ne $rsa) 'R18ZT signer certificate has no RSA private key.'
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)

$signatureRows = @(& $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH)
Require ($signatureRows.Count -eq 1 -and [string]$signatureRows[0].State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and [string]$signatureRows[0].RequestId -eq $requestId) 'R18ZT staged signed-package verification failed.'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $stageZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($stageZip, $verifyRoot)
$extractedFiles = @(Get-ChildItem -LiteralPath $verifyRoot -Recurse -File)
$actualLeaves = @($extractedFiles | ForEach-Object { $_.FullName.Substring($verifyRoot.Length + 1).Replace('\', '/') })
Compare-ExactStringSet $expectedLeafArray $actualLeaves 'R18ZT extracted ZIP'
$actualLeafSetSha = Get-TextSha256 ((@($pathGate.plannedFinalZipMembers) -join "`n") + "`n")
Require ($actualLeafSetSha -ceq $expectedLeafSetSha) 'R18ZU extracted ZIP member-set hash changed.'
foreach ($leaf in $expectedLeafArray) {
    $stagedMember = Get-SafeChild $readyRoot $leaf
    $extractedMember = Get-SafeChild $verifyRoot $leaf
    Require ((Test-Path -LiteralPath $stagedMember -PathType Leaf) -and (Test-Path -LiteralPath $extractedMember -PathType Leaf)) "R18ZT exact extracted member absent: $leaf"
    Require ((Get-Item -LiteralPath $stagedMember).Length -eq (Get-Item -LiteralPath $extractedMember).Length -and (Get-Sha256 $stagedMember) -eq (Get-Sha256 $extractedMember)) "R18ZT exact extracted member changed: $leaf"
}
$extractedSignatureRows = @(& $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH)
Require ($extractedSignatureRows.Count -eq 1 -and [string]$extractedSignatureRows[0].State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and [string]$extractedSignatureRows[0].RequestId -eq $requestId) 'R18ZT extracted signed-package verification failed.'
$extractedRequestManifest = Get-Content -LiteralPath (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
Assert-ExactLauncherChange @($extractedRequestManifest.changes) $launcherSha 'R18ZT extracted signed manifest'
$resolvedPsHome = [IO.Path]::GetFullPath($PSHOME).TrimEnd([IO.Path]::DirectorySeparatorChar)
$psHomeParent = [IO.Directory]::GetParent($resolvedPsHome)
Require ($null -ne $psHomeParent -and [IO.Path]::GetFileName($resolvedPsHome) -ceq 'v1.0' -and [string]$psHomeParent.Name -ceq 'WindowsPowerShell') 'R18ZT current host PSHOME lineage changed.'
$psHomeGrandparent = $psHomeParent.Parent
Require ($null -ne $psHomeGrandparent -and [string]$psHomeGrandparent.Name -ceq 'System32') 'R18ZT current host is not the exact Windows PowerShell 5.1 installation.'
$windowsPowerShell51 = [IO.Path]::GetFullPath((Join-Path $resolvedPsHome 'powershell.exe'))
Require (Test-Path -LiteralPath $windowsPowerShell51 -PathType Leaf) 'R18ZT Windows PowerShell 5.1 executable is absent.'
$windowsPowerShellCommands = @(Get-Command -Name $windowsPowerShell51 -CommandType Application -ErrorAction Stop)
Require ($windowsPowerShellCommands.Count -eq 1 -and [IO.Path]::GetFullPath([string]$windowsPowerShellCommands[0].Path) -eq $windowsPowerShell51) 'R18ZT Windows PowerShell 5.1 executable resolution changed.'
$extractedPayload = Join-Path $verifyRoot 'payload'
$extractedLauncher = Join-Path $extractedPayload 'Invoke-R18ZTBatchLaunch.ps1'
$extractedPreflightText = (& $windowsPowerShell51 -NoProfile -ExecutionPolicy Bypass -File $extractedLauncher -Preflight -Rehearsal -PackageValidationOnly -PayloadRoot $extractedPayload -WorkRoot $testWorkRoot -OutputRoot $testOutputRoot -CanonicalProposalRoot 'C:\RZV3A1_PROPOSALS_NOT_ACCESSED' -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String)
Require ($LASTEXITCODE -eq 0) 'R18ZT extracted launcher Windows PowerShell 5.1 preflight returned nonzero.'
$extractedPreflight = $extractedPreflightText | ConvertFrom-Json
Require ([string]$extractedPreflight.state -eq 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' -and [bool]$extractedPreflight.sourceInventoryAndHashingDeferredToOwnedWorker -and -not [bool]$extractedPreflight.sourceImageBytesHashed -and -not [bool]$extractedPreflight.pixelsDecoded -and -not [bool]$extractedPreflight.targetWritesPerformed -and -not [bool]$extractedPreflight.processStarted -and -not [bool]$extractedPreflight.completionClaimed) 'R18ZT extracted launcher Windows PowerShell 5.1 preflight failed.'
$extractedRunner = Join-Path $extractedPayload 'files\OPENCV_SCRIBE_R18ZV3\r18zv3_parallel_batch.py'; $extractedBaseRunner = Join-Path $extractedPayload 'files\OPENCV_SCRIBE_R18ZV3\Run-R18ZTExistingOrientedCropsV2.py'
$extractedProvider = Join-Path $extractedPayload 'files\OPENCV_SCRIBE_R18ZV1\ArgosOpenCvScribeV1R18ZV1BatchAdapter.py'
$extractedWrappedProvider = Join-Path $extractedPayload 'files\OPENCV_SCRIBE_R18ZV1\ArgosOpenCvScribeV1R18ZV1.py'
$extractedR18zuProvider = Join-Path $extractedPayload 'files\OPENCV_SCRIBE_R18ZU\ArgosOpenCvScribeV1R18ZU.py'
$extractedDevelopment = Join-Path $extractedPayload 'files\OPENCV_SCRIBE_R18ZV1\R18ZV1_GENERIC_ALTERNATIVE_ENVELOPE_DEVELOPMENT_FREEZE.json'
Require ((Get-Sha256 $extractedRunner) -eq $coordinatorSha -and (Get-Sha256 $extractedBaseRunner) -eq $runnerSha -and (Get-Sha256 $extractedProvider) -eq $providerSha -and (Get-Sha256 $extractedWrappedProvider) -eq $wrappedProviderSha -and
    (Get-Sha256 $extractedR18zuProvider) -eq [string]($artifactRows | Where-Object name -eq 'r18zuProvider').sha256 -and
    (Get-Sha256 $extractedDevelopment) -eq [string]($artifactRows | Where-Object name -eq 'r18zv1DevelopmentFreeze').sha256) 'R18ZV1 extracted closure changed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
Copy-Item -LiteralPath $stageZip -Destination (Join-Path $finalPartial $zipName)
foreach ($gate in @($bindingPath,$cloneGatePath,$pathGatePath,$powerShellGatePath,$scienceGatePath,$junctionGatePath,$preactionPath,$collisionGatePath)) {
    Copy-Item -LiteralPath $gate -Destination (Join-Path $finalPartial ([IO.Path]::GetFileName($gate)))
}
$routeGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18zv3_complete_route_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18ZV3_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED'
    requestId = $requestId
    bindingRecordSha256 = $bindingSha
    requestZipSha256 = Get-Sha256 $stageZip
    requestZipBytes = [int64](Get-Item -LiteralPath $stageZip).Length
    requestManifestSha256 = Get-Sha256 $requestManifestPath
    actualFinalZipMemberCount = $actualLeaves.Count
    actualFinalZipMemberSetSha256 = $actualLeafSetSha
    maximumEffectiveLength = [int]$pathGate.maximumEffectiveLength
    maximumComponentLength = [int]$pathGate.maximumComponentLength
    unsafePathCount = [int]$pathGate.unsafePathCount
    collisionGateSha256 = Get-Sha256 $collisionGatePath
    publicationMustRecheckAllAccessibleCollisionNamespaces = $true
    publicationAuthorized = $false
    conditionalPublicationAuthorityText = 'Do the work, if it is successful - as in deciphering correctly. PUBLISH the package to JBOD.'
    exactSlot21ImageFirstString = '13HFX135SUE3'
    slot21CorrectionSha256 = [string]($artifactRows | Where-Object name -eq 'r18zv1Slot21CorrectionGate').sha256
    retryAuthorized = $false
    targetExecuted = $false
    completionClaimed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$routeGatePath = Join-Path $finalPartial ($zipName + '.complete_route_gate.json')
Write-JsonNew $routeGatePath $routeGate
Move-Item -LiteralPath $finalPartial -Destination $finalRoot

$finalZipPath = Join-Path $finalRoot $zipName
$finalGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18zv3_final_package_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18ZV3_SIGNED_UNPUBLISHED_PACKAGE_GATE'
    requestId = $requestId
    revision = $revision
    bindingRecordSha256 = $bindingSha
    requestZip = 'work/OPENCV_SCRIBE_R18ZV3_BATCH_PACKAGE_A/final/REQ_RZV3.ready.zip'
    requestZipBytes = [int64](Get-Item -LiteralPath $finalZipPath).Length
    requestZipSha256 = Get-Sha256 $finalZipPath
    requestManifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
    requestSignatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
    expiresUtc = [string]$requestManifest.expiresUtc
    builderSha256 = $builderSha
    launcherSha256 = $launcherSha
    cloneGateSha256 = Get-Sha256 $cloneGatePath
    pathPlanGateSha256 = Get-Sha256 $pathGatePath
    powerShellSafetyGateSha256 = Get-Sha256 $powerShellGatePath
    scienceGateSha256 = Get-Sha256 $scienceGatePath
    proposalJunctionGateSha256 = Get-Sha256 $junctionGatePath
    r18zv2RunningCoexistenceGateSha256 = Get-Sha256 $resolvedArtifacts['r18zv2RunningCoexistenceGate']
    preactionSha256 = Get-Sha256 $preactionPath
    collisionGateSha256 = Get-Sha256 $collisionGatePath
    payloadManifestFileCount = $payloadFiles.Count
    signedPayloadFileCount = $manifestFiles.Count
    finalZipMemberCount = $actualLeaves.Count
    finalZipMemberSetSha256 = $actualLeafSetSha
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    stagedStaticEntrypointPreflightPassed = $true
    extractedWindowsPowerShell51EntrypointPreflightPassed = $true
    stagedPackagedHashClosurePassed = $true
    extractedPackagedHashClosurePassed = $true
    executionEnvelopeDelegateMode = 'IN_PROCESS_PUBLIC_MAIN_WITH_FIXED_PROCESS_ISOLATED_CHILDREN'; delegateChildrenMustExitBeforeReturn = $true; parentOnlyKillForbidden = $true; launchedFailurePreservesResources = $true; rollbackAllowedOnlyBeforeEnvelopeStart = $true
    asynchronousLaunchOnly = $true
    completionClaimed = $false
    targetExecuted = $false
    publicationAuthorized = $false
    publicationPerformed = $false
    conditionalPublicationAuthorityText = 'Do the work, if it is successful - as in deciphering correctly. PUBLISH the package to JBOD.'
    exactSlot21ImageFirstString = '13HFX135SUE3'
    exactSlot21AdjudicationVerified = $true
    maximumPublications = 1
    retryAuthorized = $false
    sourceMutationPerformed = $false
    identityAccepted = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-JsonNew $finalGatePath $finalGate
$finalGate | ConvertTo-Json -Depth 32
