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
    Require ([string]$change.destination -ceq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZT1.ps1') "$Label launcher destination changed."
    Require ([string]$change.installedSha256 -ceq $LauncherSha256) "$Label installed launcher hash changed."
    Require ($change.PSObject.Properties['allowCreate'].Value -is [bool] -and [bool]$change.allowCreate) "$Label allowCreate changed."
    Compare-ExactStringSet @($LauncherSha256) @($change.approvedPredecessorSha256 | ForEach-Object { [string]$_ }) "$Label approved predecessor hashes"
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18ZT create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18ZT1'
$revision = 'R18ZT_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260906C'
$runnerRevision = 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906C'
$bindingPath = Join-Path $PSScriptRoot 'R18ZT_FROZEN_PACKAGE_BINDINGS_V5.json'
$launcherPath = Join-Path $PSScriptRoot 'Invoke-R18ZTBatchLaunchV3.ps1'
$payloadManifestPath = Join-Path $PSScriptRoot 'R18ZT_PAYLOAD_MANIFEST_V2.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION_V4.json'
$configurationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B\R18ZT_BATCH_CONFIGURATION.json'
$designPath = Join-Path $PSScriptRoot 'R18ZT_BATCH_PACKAGE_DESIGN_V5.json'
$importSmokePath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B\Test-R18ZTPackagedImportClosure.py'
$payloadCloneRemediationPath = Join-Path $PSScriptRoot 'R18ZT_PACKAGE_C_CLONE_REMEDIATION_V5.json'
$builderCloneRemediationPath = Join-Path $PSScriptRoot 'R18ZT_C8_REMEDIATION.json'
$publisherCloneRemediationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_B\R18ZT_PUBLISHER_CLONE_REMEDIATION.json'
$cloneRawGatePath = Join-Path $PSScriptRoot 'R18ZT_C8_RAW.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18ZT_C8_CLONE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18ZT_PATH_PLAN_GATE_V3.json'
$powerShellGatePath = Join-Path $PSScriptRoot 'R18ZT_POWERSHELL_SAFETY_GATE_V4.json'
$scienceGatePath = Join-Path $PSScriptRoot 'R18ZT_SCIENCE_GATE_V2.json'
$junctionGatePath = Join-Path $PSScriptRoot 'R18ZT_PROPOSAL_JUNCTION_GATE_V2.json'
$recoveryIntentPath = Join-Path $PSScriptRoot 'R18ZT_RECOVERY_INTENT_V2.json'
$recoveryGatePath = Join-Path $PSScriptRoot 'R18ZT_RECOVERY_INTENT_GATE_V2.json'
$preactionPath = Join-Path $PSScriptRoot 'R18ZT_C8_PREACTION.json'
$collisionGatePath = Join-Path $PSScriptRoot 'R18ZT_REQUEST_ID_COLLISION_GATE_V2.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$localPython = 'C:\ArgosPy313\Scripts\python.exe'
$localReferenceBundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$testRoot = 'C:\R18ZT1C3T'
$testWorkRoot = 'C:\R18ZT1C3TW'
$testOutputRoot = 'C:\R18ZT1C3TO'
$stageRoot = 'C:\R18ZT1C3P'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\R18ZT1C3V'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'R18ZT_FINAL_PACKAGE_GATE_V2.json'
$productionWorkRoot = 'D:\A2\w\ocv\R18ZT1'
$productionOutputRoot = 'D:\A2\o\ocv\R18ZT1'
$productionProposalAlias = 'D:\A2\w\ocv\R18ZT1\p'
$canonicalProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals'
$productionInstalledLauncher = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZT1.ps1'
$bindingSha = '23F68B7A1C744E57508D89FE10B48ADF07C50E641EC70CBA1213EDE0388C5E86'

Require-Pin $bindingPath $bindingSha -1 'FROZEN_R18ZT_PACKAGE_C_V5_BINDINGS'
$binding = Get-Content -LiteralPath $bindingPath -Raw | ConvertFrom-Json
Require ([string]$binding.schema -eq 'argos_opencv_scribe_r18zt_package_bindings_v5' -and [string]$binding.requestId -eq $requestId -and [string]$binding.packageRevision -eq $revision -and [string]$binding.runnerRevision -eq $runnerRevision) 'R18ZT V5 binding identity changed.'
Require ([string]$binding.roots.workRoot -eq $productionWorkRoot -and [string]$binding.roots.outputRoot -eq $productionOutputRoot -and [string]$binding.roots.proposalAlias -eq $productionProposalAlias -and [string]$binding.roots.canonicalProposalRoot -eq $canonicalProposalRoot -and [string]$binding.roots.installedLauncher -eq $productionInstalledLauncher) 'R18ZT frozen binding roots changed.'
Require ([int]$binding.pathContract.maximumIdentityCharacters -eq 80 -and [int]$binding.pathContract.caseIdCharacters -eq 20 -and [int]$binding.pathContract.sourceLeafSuffixReserveCharacters -eq 32 -and [int]$binding.pathContract.outputAtomicSuffixReserveCharacters -eq 52 -and [bool]$binding.pathContract.actualFourAliasLeavesCheckedBeforeFirstWrite -and [bool]$binding.pathContract.aliasOnlySourceLeafIo) 'R18ZT path binding changed.'
$boundLongestOutput = $binding.pathContract.exactLongestEffectiveCaseOutput
Require ([string]$boundLongestOutput.leaf -ceq 'CASE_RESULT.json' -and [string]$boundLongestOutput.path -ceq 'D:\A2\o\ocv\R18ZT1\cases\FFFFFFFFFFFFFFFFFFFF\CASE_RESULT.json' -and [int]$boundLongestOutput.basePathLength -eq 62 -and [int]$boundLongestOutput.suffixReserveCharacters -eq 52 -and [int]$boundLongestOutput.effectivePathLength -eq 114 -and [int]$boundLongestOutput.effectiveComponentLength -eq 68) 'R18ZT exact longest atomic case-output binding changed.'
$boundConservativeTemp = $binding.pathContract.launcherConservativeProviderTempBudget
Require ([string]$boundConservativeTemp.leaf -ceq 'PROVIDER_RESULT.json.partial' -and [string]$boundConservativeTemp.path -ceq 'D:\A2\o\ocv\R18ZT1\cases\FFFFFFFFFFFFFFFFFFFF\PROVIDER_RESULT.json.partial' -and [int]$boundConservativeTemp.basePathLength -eq 74 -and [int]$boundConservativeTemp.baseComponentLength -eq 28 -and [int]$boundConservativeTemp.conservativeSuffixReserveCharacters -eq 52 -and [int]$boundConservativeTemp.conservativeEffectivePathLength -eq 126 -and [int]$boundConservativeTemp.conservativeEffectiveComponentLength -eq 80 -and -not [bool]$boundConservativeTemp.trueAtomicWriteTarget) 'R18ZT conservative provider-temp launcher budget changed.'
Require ([string]$binding.outputSchemas.case -ceq 'argos_opencv_scribe_r18zt_batch_case_result_v2') 'R18ZT case-result schema binding changed.'
Require ([string]$binding.routeEvidence.sourceWorkerPath -ceq 'work/OPENCV_OLS3/pkg/payload/W.ps1' -and [string]$binding.routeEvidence.sourceWorkerSha256 -eq 'E070135E8C211F2869623553C04AE2DDE65244760FC60457356B2FEEEFEED4EB' -and [string]$binding.routeEvidence.currentInstalledWorkerSha256 -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250' -and [string]$binding.routeEvidence.inheritedGenericQueueSafetyTargetWorkerSha256 -eq '244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6' -and [string]$binding.routeEvidence.workerHashRelationship -ceq 'THREE_DISTINCT_PINNED_ROLES_NO_EQUALITY_OR_EQUIVALENCE_INFERRED' -and -not [bool]$binding.routeEvidence.sourceWorkerEqualsCurrentInstalledWorkerClaimed -and -not [bool]$binding.routeEvidence.genericQueueTargetEqualsCurrentInstalledWorkerClaimed -and [string]$binding.routeEvidence.queueSafetyNature -ceq 'INHERITED_GENERIC_NOT_EXACT_CURRENT_WORKER_REHEARSAL') 'R18ZT route-worker role binding changed.'
Require ([bool]$binding.workerContract.delegateRunsInEnvelopeProcess -and [int]$binding.workerContract.delegateSubprocessCount -eq 0 -and [bool]$binding.workerContract.confirmedSoleWorkerExitBeforeRollback) 'R18ZT sole-worker binding changed.'

$artifactRows = @($binding.artifacts)
$requiredArtifactNames = @(
    'launcher','payloadManifest','maintenanceDefinition','batchConfiguration','packageDesign','packageImportSmokeTest',
    'packageCloneRemediation','publisherCloneRemediation','packageV1Withdrawal','packageV2Withdrawal','packageV3Withdrawal','packageCScaffoldAbandonment','packageCV4RemediationWithdrawal','builderSourceHarness','executionEnvelope','executionEnvelopeTest','batchRunner','batchRunnerTest','batchRunnerBWithdrawal','provider','r11Analyzer',
    'developmentGate','prevalidationGate','slot21Runner','slot21Result','slot21ExecutionGate',
    'slot21Adjudication','routeWorkerSource','routePins','latestTerminalCheckpoint','returnedFileInventory','queueSafetyGate',
    'signingIdentity','signerCertificate','packageTester','localPython','referenceBundle'
)
Compare-ExactStringSet $requiredArtifactNames @($artifactRows | ForEach-Object { [string]$_.name }) 'R18ZT frozen binding artifact names'
$resolvedArtifacts = @{}
foreach ($row in $artifactRows) {
    $path = if ([IO.Path]::IsPathRooted([string]$row.path)) { [IO.Path]::GetFullPath([string]$row.path) } else { Get-SafeProjectSource $project ([string]$row.path) }
    Require-Pin $path ([string]$row.sha256) ([int64]$row.bytes) ([string]$row.state)
    $resolvedArtifacts[[string]$row.name] = $path
}
Require ($resolvedArtifacts['launcher'] -eq [IO.Path]::GetFullPath($launcherPath) -and $resolvedArtifacts['payloadManifest'] -eq [IO.Path]::GetFullPath($payloadManifestPath) -and $resolvedArtifacts['maintenanceDefinition'] -eq [IO.Path]::GetFullPath($definitionPath) -and $resolvedArtifacts['batchConfiguration'] -eq [IO.Path]::GetFullPath($configurationPath) -and $resolvedArtifacts['packageDesign'] -eq [IO.Path]::GetFullPath($designPath) -and $resolvedArtifacts['packageImportSmokeTest'] -eq [IO.Path]::GetFullPath($importSmokePath)) 'R18ZT core binding paths changed.'
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
Require ([string]$v3Withdrawal.state -ceq 'WITHDRAWN_R18ZT_PACKAGE_B_V3_HARNESS_FAILURE_NON_REUSABLE_NON_PARENT' -and [string]$v3Withdrawal.requestId -ceq $requestId -and [string]$v3Withdrawal.failureEvidence.state -ceq 'FAIL_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$v3Withdrawal.failureEvidence.violationCode -ceq 'MUTATION_BEFORE_PREFLIGHT_RETURN' -and [int]$v3Withdrawal.failureEvidence.violationLine -eq 625 -and [bool]$v3Withdrawal.failureEvidence.metadataOnly -and -not [bool]$v3Withdrawal.failureEvidence.targetExecuted -and -not [bool]$v3Withdrawal.mayBePackageParent -and -not [bool]$v3Withdrawal.mayBePublicationParent -and -not [bool]$v3Withdrawal.mayBeTemplate) 'R18ZT Package B V3 withdrawal changed.'
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

$cloneGate = Read-BoundGate $cloneGatePath 'PASS_R18ZT_PACKAGE_C_CLONE_LITERAL_GATE'
$pathGate = Read-BoundGate $pathGatePath 'PASS_R18ZT_PACKAGE_C_PATH_BUDGET'
$powerShellGate = Read-BoundGate $powerShellGatePath 'PASS_R18ZT_PACKAGE_C_POWERSHELL_SAFETY'
$scienceGate = Read-BoundGate $scienceGatePath 'PASS_R18ZT_BATCH_SCIENCE_GATE'
$junctionGate = Read-BoundGate $junctionGatePath 'PASS_R18ZT_PROPOSAL_JUNCTION_CREATION_AND_ROLLBACK'
$recoveryGate = Read-BoundGate $recoveryGatePath 'PASS_ARGOS_RECOVERY_INTENT'
$preaction = Read-BoundGate $preactionPath 'PASS_PREACTION_CONTRACT'
$collisionGate = $null
if ($Build) { $collisionGate = Read-BoundGate $collisionGatePath 'PASS_R18ZT_REQUEST_ID_ABSENT_ALL_SCOPES' }

$builderPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$builderSha = Get-Sha256 $builderPath
$expectedClonePairs = [ordered]@{
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/Build-R18ZTBatchRequestV5.ps1' = $builderSha
}
Require ([string]$cloneGate.utilityState -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [bool]$cloneGate.sourceTemplatesGuardedBeforeGeneration -and [bool]$cloneGate.generatedArtifactsGuardedAfterGeneration -and -not [bool]$cloneGate.publisherIncluded) 'R18ZT clone gate contract changed.'
Require ([string]$cloneGate.packageCloneRemediationSha256 -eq [string]($artifactRows | Where-Object { [string]$_.name -eq 'packageCloneRemediation' }).sha256 -and [string]$cloneGate.publisherCloneRemediationSha256 -eq [string]($artifactRows | Where-Object { [string]$_.name -eq 'publisherCloneRemediation' }).sha256) 'R18ZT clone remediation pins changed.'
Require ([string]$cloneGate.builderCorrectionRemediationSha256 -eq (Get-Sha256 $builderCloneRemediationPath)) 'R18ZT builder correction remediation pin changed.'
Require ([string]$cloneGate.rawUtilityGatePath -ceq 'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/R18ZT_C8_RAW.json' -and [string]$cloneGate.rawUtilityGateSha256 -cmatch '^[A-F0-9]{64}$') 'R18ZT raw clone utility gate pin is absent.'
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
foreach ($scriptPin in @([pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/Invoke-R18ZTBatchLaunchV3.ps1';sha=[string]($artifactRows | Where-Object name -eq 'launcher').sha256}, [pscustomobject]@{path='work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/Build-R18ZTBatchRequestV5.ps1';sha=$builderSha})) {
    $matches = @($scriptChecks | Where-Object { [string]$_.path -ceq [string]$scriptPin.path })
    Require ($matches.Count -eq 1 -and [string]$matches[0].sha256 -eq [string]$scriptPin.sha -and [string]$matches[0].harnessState -eq 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' -and [string]$matches[0].wrapperState -eq 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT') "R18ZT PowerShell script gate changed: $($scriptPin.path)"
}

Require ([bool]$junctionGate.soleOwnedWorkerTerminationVerified -and [bool]$junctionGate.workerTerminatedBeforeAliasRollback -and [bool]$junctionGate.exactOwnedJunctionRollbackExercised -and [int]$junctionGate.delegateSubprocessCount -eq 0 -and [string]$junctionGate.launcherSha256 -eq [string]($artifactRows | Where-Object name -eq 'launcher').sha256) 'R18ZT proposal junction gate changed.'
Require ([string]$scienceGate.exactImageFirstString -eq '13HFX135SUE3' -and [bool]$scienceGate.exactDecipheringFinish -and [bool]$scienceGate.zeroWrongAcceptedOnBoundedRegression -and [bool]$scienceGate.r11DirectInputEightAttemptOrderVerified -and [bool]$scienceGate.r11InputModeBindingVerified -and [bool]$scienceGate.runnerGeneratedLabelsNotSoleProof) 'R18ZT science result changed.'
foreach ($sciencePin in @('batchRunner','batchRunnerTest','batchRunnerBWithdrawal','provider','r11Analyzer','developmentGate','prevalidationGate','slot21Runner','slot21Result','slot21ExecutionGate','slot21Adjudication')) {
    $bindingRow = @($artifactRows | Where-Object { [string]$_.name -eq $sciencePin })[0]
    $scienceRows = @($scienceGate.artifacts | Where-Object { [string]$_.name -eq $sciencePin })
    Require ($scienceRows.Count -eq 1 -and [string]$scienceRows[0].sha256 -eq [string]$bindingRow.sha256 -and [int64]$scienceRows[0].bytes -eq [int64]$bindingRow.bytes) "R18ZT science pin changed: $sciencePin"
}
Require ([string]$scienceGate.slot21AdjudicationState -eq 'PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION' -and [string]$scienceGate.executedSlot21GateDisposition -eq 'HOLD_SUPERSEDED_BY_NO_RERUN_POST_RESULT_ADJUDICATION' -and -not [bool]$scienceGate.providerRerunForAdjudication) 'R18ZT Slot21 adjudication binding changed.'

# The package builder re-opens the hash-bound scientific authorities.  A
# package-local summary gate is never the sole evidence for deciphering.
$developmentEvidence = Get-Content -LiteralPath $resolvedArtifacts['developmentGate'] -Raw | ConvertFrom-Json
Require ([string]$developmentEvidence.state -ceq 'PASS_R18ZT_GENERIC_HOLD_RESCUE_FROZEN_BEFORE_VALIDATION' -and [string]$developmentEvidence.classification -ceq 'DIAGNOSTIC_ONLY') 'R18ZT development authority changed.'
Require ([int]$developmentEvidence.criteria.acceptedWrong -eq 0 -and [int]$developmentEvidence.criteria.acceptedCorrect -eq 312 -and [bool]$developmentEvidence.criteria.all475QueriesEvaluated -and [int]$developmentEvidence.criteria.exactFoldCount -eq 49 -and [bool]$developmentEvidence.criteria.frozenAcceptedCorrectPreserved -and [bool]$developmentEvidence.criteria.k25vDiagnosticHoldPreserved -and [bool]$developmentEvidence.criteria.hypothesisOrderingUnchanged -and -not [bool]$developmentEvidence.criteria.resultAuthorityExpanded) 'R18ZT bounded development outcomes changed.'
Require ([int]$developmentEvidence.leaveOneExactScribeLineageOut.referenceQueries -eq 475 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.acceptedWrong -eq 0 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.acceptedCorrect -eq 312 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.held -eq 163 -and [int]$developmentEvidence.leaveOneExactScribeLineageOut.exactFoldCount -eq 49) 'R18ZT direct LOO evidence changed.'
Require (-not [bool]$developmentEvidence.invariants.checksumUsedForSelectionOrAcceptance -and [bool]$developmentEvidence.invariants.frozenBeforeValidationEvaluation -and [bool]$developmentEvidence.invariants.truthComparedOnlyAfterImageRanking -and -not [bool]$developmentEvidence.invariants.hypothesisOrderingChangedByRescue -and -not [bool]$developmentEvidence.invariants.identityAccepted -and -not [bool]$developmentEvidence.invariants.productionEligible -and -not [bool]$developmentEvidence.invariants.publicationAuthorized -and -not [bool]$developmentEvidence.invariants.runtimePatchLockOrRestorationChanged) 'R18ZT development invariants changed.'

$adjudicationEvidence = Get-Content -LiteralPath $resolvedArtifacts['slot21Adjudication'] -Raw | ConvertFrom-Json
Require ([string]$adjudicationEvidence.state -ceq 'PASS_R18ZT_SLOT21_EXACT_DECIPHERING_FINISH_POST_RESULT_ADJUDICATION' -and [string]$adjudicationEvidence.classification -ceq 'DIAGNOSTIC_ONLY' -and [string]$adjudicationEvidence.scope -ceq 'READ_ONLY_POST_RESULT_ADJUDICATION_NO_PROVIDER_RERUN') 'R18ZT direct adjudication identity changed.'
$adjudicationPinMap = [ordered]@{
    'runner' = 'slot21Runner'
    'provider' = 'provider'
    'developmentGate' = 'developmentGate'
    'preValidationGate' = 'prevalidationGate'
    'executedResult' = 'slot21Result'
    'executedGate' = 'slot21ExecutionGate'
}
foreach ($adjudicationPin in $adjudicationPinMap.GetEnumerator()) {
    $directRows = @($adjudicationEvidence.pins | Where-Object { [string]$_.name -ceq [string]$adjudicationPin.Key })
    $bindingRow = @($artifactRows | Where-Object { [string]$_.name -ceq [string]$adjudicationPin.Value })
    Require ($directRows.Count -eq 1 -and $bindingRow.Count -eq 1 -and [string]$directRows[0].sha256 -eq [string]$bindingRow[0].sha256 -and [string]$directRows[0].path -ceq [string]$bindingRow[0].path) "R18ZT direct adjudication pin changed: $($adjudicationPin.Key)"
}
$finish = $adjudicationEvidence.decipheringFinish
Require ([bool]$finish.exact -and [string]$finish.criterion -ceq 'EXACT_IMAGE_FIRST_STRING_WITH_DEFENSIBLE_GENERIC_SUPPORT_AND_ZERO_WRONG_ACCEPTED' -and [string]$finish.imageFirstString -ceq '13HFX135SUE3' -and [string]$finish.truth -ceq '13HFX135SUE3' -and [string]$finish.selectedChannel -ceq 'BF' -and [string]$finish.selectedPolarity -ceq 'DARK' -and [string]$finish.selectedDirection -ceq 'FORWARD' -and ([decimal]$finish.selectionScore -eq [decimal]::Parse('0.9117836040446633', [Globalization.CultureInfo]::InvariantCulture)) -and [bool]$finish.selectedGlyphEnvelopePassed -and [int]$finish.correctImageFirstCount -eq 1 -and [int]$finish.wrongImageFirstAcceptedCount -eq 0 -and [int]$finish.developmentAcceptedWrongCount -eq 0 -and [int]$finish.validationCaseCount -eq 1 -and [bool]$finish.truthComparedOnlyAfterProviderResult) 'R18ZT exact deciphering finish changed.'
$rescueKeys = @($finish.genericHoldRescues | ForEach-Object { ([string]$_.position) + '|' + ([string]$_.label) + '|' + ([string]$_.mode) + '|' + ([string][bool]$_.passed) })
Compare-ExactStringSet @(
    '3|H|COVERED_TAIL_CROSS_MODAL_RECIPROCAL_SUPPORT|True',
    '5|X|SPARSE_MULTI_LINEAGE_THREE_MODAL_RECIPROCAL_SUPPORT|True'
) $rescueKeys 'R18ZT exact generic hold rescues'
$runEvidence = $adjudicationEvidence.executedRun
$expectedAttemptOrder = @(
    'BF|DARK|FORWARD',
    'BF|DARK|REVERSE_180',
    'BF|BRIGHT|FORWARD',
    'BF|BRIGHT|REVERSE_180',
    'DF|DARK|FORWARD',
    'DF|DARK|REVERSE_180',
    'DF|BRIGHT|FORWARD',
    'DF|BRIGHT|REVERSE_180'
)
$actualAttemptOrder = @($runEvidence.attempts | ForEach-Object { ([string]$_.channel) + '|' + ([string]$_.polarity) + '|' + ([string]$_.direction) })
Require ($actualAttemptOrder.Count -eq 8 -and (($actualAttemptOrder -join "`n") -ceq ($expectedAttemptOrder -join "`n")) -and [int]$runEvidence.attemptCount -eq 8 -and [bool]$runEvidence.orderedAttemptKeysExact -and [int]$runEvidence.analyzeImagesCallCount -eq 1 -and [int]$runEvidence.providerRunCount -eq 1 -and [int]$runEvidence.directStructuralEvaluatorCallsByHarness -eq 0 -and [bool]$runEvidence.retainedKeysEqualEvaluatedKeys -and -not [bool]$runEvidence.retryPerformed -and -not [bool]$runEvidence.providerRerunByThisAdjudication) 'R18ZT exact public-run hypothesis execution changed.'
foreach ($restorationField in @('analyze','apply','enforce','evaluate','loader','revision','sharedLockAvailableAfterRun','validate')) {
    $restorationProperty = $adjudicationEvidence.runtimeRestoration.PSObject.Properties[$restorationField]
    Require ($null -ne $restorationProperty -and $restorationProperty.Value -is [bool] -and [bool]$restorationProperty.Value) "R18ZT runtime restoration changed: $restorationField"
}
Require ([bool]$adjudicationEvidence.currentEvidenceIsUnique.passed -and [int]$adjudicationEvidence.currentEvidenceIsUnique.candidateCount -eq 1 -and [int]$adjudicationEvidence.currentEvidenceIsUnique.checksumValidRetainedHypothesisCount -eq 1 -and [string]$adjudicationEvidence.currentEvidenceIsUnique.checksumState -ceq 'SCRIBE_M12_IMAGE_FIRST_CHECKSUM_VALID_REVIEW_ONLY') 'R18ZT unique current evidence changed.'
$heldAuthority = $adjudicationEvidence.holdsAndAuthority
Require (-not [bool]$heldAuthority.coverageHoldCleared -and -not [bool]$heldAuthority.eligibleIdentity -and -not [bool]$heldAuthority.identityAccepted -and -not [bool]$heldAuthority.productionEligible -and -not [bool]$heldAuthority.providerActivationAuthorized -and -not [bool]$heldAuthority.publicationAuthorizedByThisGate -and -not [bool]$heldAuthority.trainingEligible -and -not [bool]$heldAuthority.xmlEligible -and [bool]$heldAuthority.onlyResultHoldRowIsGlobalReferenceCoverage -and [bool]$heldAuthority.reviewOnly -and [string]$heldAuthority.missingBodyReferenceLabels -ceq 'IOVY') 'R18ZT preserved hold/authority boundary changed.'
$preservedHolds = @($heldAuthority.resultHoldsPreserved)
Require ($preservedHolds.Count -eq 1 -and [string]$preservedHolds[0].code -ceq 'SCRIBE_REFERENCE_COVERAGE_HOLD') 'R18ZT global reference-coverage hold changed.'
Require (-not [bool]$adjudicationEvidence.invariants.executedGateModified -and -not [bool]$adjudicationEvidence.invariants.executedResultModified -and -not [bool]$adjudicationEvidence.invariants.externalAccessPerformed -and -not [bool]$adjudicationEvidence.invariants.providerExecutedByThisAdjudication -and -not [bool]$adjudicationEvidence.invariants.providerRerunAuthorized -and -not [bool]$adjudicationEvidence.invariants.publicationPerformed -and -not [bool]$adjudicationEvidence.invariants.truthOrChecksumUsedForSelection -and -not [bool]$adjudicationEvidence.invariants.wrongAccepted) 'R18ZT post-result adjudication invariants changed.'

$executedGateEvidence = Get-Content -LiteralPath $resolvedArtifacts['slot21ExecutionGate'] -Raw | ConvertFrom-Json
Require ([string]$executedGateEvidence.state -ceq 'HOLD_R18ZT_SLOT21_FINISH_CRITERIA_NOT_MET_NO_RETRY' -and [int]$executedGateEvidence.providerRunCount -eq 1 -and -not [bool]$executedGateEvidence.retryAuthorized -and [int]$executedGateEvidence.fullChain.attemptCount -eq 8 -and [int]$executedGateEvidence.fullChain.analyzeImagesCallCount -eq 1 -and [int]$executedGateEvidence.fullChain.directStructuralEvaluatorCallsByHarness -eq 0 -and [bool]$executedGateEvidence.fullChain.orderedAttemptKeysExact -and [string]$executedGateEvidence.fullChain.publicEntryPoint -ceq 'run_job') 'R18ZT frozen executed Slot21 gate changed.'
$executedGateOrder = @($executedGateEvidence.fullChain.attempts | ForEach-Object { ([string]$_.channel) + '|' + ([string]$_.polarity) + '|' + ([string]$_.direction) })
Require (($executedGateOrder -join "`n") -ceq ($expectedAttemptOrder -join "`n")) 'R18ZT frozen executed-gate attempt order changed.'
$executedResultEvidence = Get-Content -LiteralPath $resolvedArtifacts['slot21Result'] -Raw | ConvertFrom-Json
Require ([string]$executedResultEvidence.imageFirstString -ceq '13HFX135SUE3' -and [string]$executedResultEvidence.proposedString -ceq '13HFX135SUE3' -and [string]$executedResultEvidence.selectedHypothesis.channel -ceq 'BF' -and [string]$executedResultEvidence.selectedHypothesis.polarity -ceq 'DARK' -and [string]$executedResultEvidence.selectedHypothesis.direction -ceq 'FORWARD' -and ([decimal]$executedResultEvidence.selectedHypothesis.selectionScore -eq [decimal]::Parse('0.9117836040446633', [Globalization.CultureInfo]::InvariantCulture)) -and [bool]$executedResultEvidence.selectedHypothesis.envelopePassed -and @($executedResultEvidence.selectedHypothesis.heldPositions).Count -eq 0) 'R18ZT frozen executed result changed.'
Require (@($executedResultEvidence.holds).Count -eq 1 -and [string]$executedResultEvidence.holds[0].code -ceq 'SCRIBE_REFERENCE_COVERAGE_HOLD' -and -not [bool]$executedResultEvidence.eligibleIdentity -and [bool]$executedResultEvidence.authority.reviewOnly -and -not [bool]$executedResultEvidence.authority.automaticIdentityAuthority -and -not [bool]$executedResultEvidence.authority.productionEligible) 'R18ZT frozen result hold/authority changed.'

Require ([int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80 -and [int]$pathGate.unsafePathCount -eq 0 -and [string]$pathGate.proposalAlias -eq $productionProposalAlias -and [string]$pathGate.canonicalProposalRoot -eq $canonicalProposalRoot -and [int]$pathGate.maximumIdentityCharacters -eq 80 -and [int]$pathGate.caseIdCharacters -eq 20 -and [int]$pathGate.sourceLeafSuffixReserveCharacters -eq 32 -and [int]$pathGate.outputAtomicSuffixReserveCharacters -eq 52 -and [int]$pathGate.canonicalLexicalLongestEffectiveLength -eq 236 -and [int]$pathGate.aliasLongestEffectiveLength -eq 188 -and [bool]$pathGate.actualFourAliasLeavesCheckedByLauncherBeforeFirstWrite) 'R18ZT path gate changed.'
$pathLongestOutput = $pathGate.exactLongestEffectiveCaseOutput
Require ([string]$pathLongestOutput.leaf -ceq 'CASE_RESULT.json' -and [string]$pathLongestOutput.path -ceq 'D:\A2\o\ocv\R18ZT1\cases\FFFFFFFFFFFFFFFFFFFF\CASE_RESULT.json' -and [int]$pathLongestOutput.basePathLength -eq 62 -and [int]$pathLongestOutput.suffixReserveCharacters -eq 52 -and [int]$pathLongestOutput.effectivePathLength -eq 114 -and [int]$pathLongestOutput.effectiveComponentLength -eq 68) 'R18ZT path-gate true atomic longest-output fact changed.'
$pathConservativeTemp = $pathGate.launcherConservativeProviderTempBudget
Require ([string]$pathConservativeTemp.leaf -ceq 'PROVIDER_RESULT.json.partial' -and [string]$pathConservativeTemp.path -ceq 'D:\A2\o\ocv\R18ZT1\cases\FFFFFFFFFFFFFFFFFFFF\PROVIDER_RESULT.json.partial' -and [int]$pathConservativeTemp.basePathLength -eq 74 -and [int]$pathConservativeTemp.baseComponentLength -eq 28 -and [int]$pathConservativeTemp.conservativeSuffixReserveCharacters -eq 52 -and [int]$pathConservativeTemp.conservativeEffectivePathLength -eq 126 -and [int]$pathConservativeTemp.conservativeEffectiveComponentLength -eq 80 -and -not [bool]$pathConservativeTemp.trueAtomicWriteTarget) 'R18ZT path-gate conservative provider-temp fact changed.'
$boundCasePathKeys = @($binding.pathContract.caseOutputLeaves | ForEach-Object { ([string]$_.leaf) + '|' + ([string]$_.writer) + '|' + ([string]$_.basePathLength) + '|' + ([string]$_.baseComponentLength) + '|' + ([string]$_.suffixReserveCharacters) + '|' + ([string]$_.effectivePathLength) + '|' + ([string]$_.effectiveComponentLength) })
$gatedCasePathKeys = @($pathGate.caseOutputLeaves | ForEach-Object { ([string]$_.leaf) + '|' + ([string]$_.writer) + '|' + ([string]$_.basePathLength) + '|' + ([string]$_.baseComponentLength) + '|' + ([string]$_.suffixReserveCharacters) + '|' + ([string]$_.effectivePathLength) + '|' + ([string]$_.effectiveComponentLength) })
Compare-ExactStringSet $boundCasePathKeys $gatedCasePathKeys 'R18ZT exact case-output path facts'
Require ([bool]$recoveryGate.mutationsPerformed -eq $false -and [bool]$recoveryGate.targetExecuted -eq $false -and [string]$recoveryGate.intentSha256 -eq (Get-Sha256 $recoveryIntentPath)) 'R18ZT recovery gate changed.'
$recoveryIntent = Get-Content -LiteralPath $recoveryIntentPath -Raw | ConvertFrom-Json
Require ([string]$recoveryIntent.state -eq 'FROZEN_R18ZT_PACKAGE_C_RECOVERY_INTENT' -and [string]$recoveryIntent.requestId -eq $requestId -and [string]$recoveryIntent.bindingRecordSha256 -eq $bindingSha -and -not [bool]$recoveryIntent.mutation.publicationAuthorized -and -not [bool]$recoveryIntent.mutation.automaticRetryAuthorized) 'R18ZT recovery intent changed.'

$preactionResult = (& $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18ZT package C preaction utility changed.'
$bindingDependency = @($preaction.dependencies | Where-Object { [string]$_.path -eq 'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/R18ZT_FROZEN_PACKAGE_BINDINGS_V5.json' })
$builderDependency = @($preaction.dependencies | Where-Object { [string]$_.path -eq 'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/Build-R18ZTBatchRequestV5.ps1' })
Require ($bindingDependency.Count -eq 1 -and [string]$bindingDependency[0].sha256 -eq $bindingSha -and $builderDependency.Count -eq 1 -and [string]$builderDependency[0].sha256 -eq $builderSha -and [string]$preaction.historyAuditSha256 -eq 'F3E7AF05017BF00ADEDFFA7A06D89155E2E5C1BF76A64E643E4972F00737BC9C') 'R18ZT package C preaction dependencies changed.'

$requiredCollisionScopes = @('LIVE_REQUEST_ROOT','LIVE_PROCESSED_ARCHIVE','GATEWAY_REQUEST_INVENTORY','LOCAL_PUBLICATION_ARCHIVE')
if ($Build) {
    Compare-ExactStringSet $requiredCollisionScopes @($collisionGate.scopes | ForEach-Object { [string]$_.name }) 'R18ZT collision scopes'
    foreach ($scope in @($collisionGate.scopes)) { Require ([bool]$scope.scanned -and [int]$scope.matchCount -eq 0) "R18ZT collision scope not proven absent: $($scope.name)" }
    Require ([int]$collisionGate.matchCount -eq 0 -and [bool]$collisionGate.allFourScopesActuallyScanned -and -not [bool]$collisionGate.gatewayInventoryUnavailable) 'R18ZT collision gate changed.'
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
Require ([bool]$definition.ownedWorkerContract.executionEnvelopeInvokesDelegateInProcess -and -not [bool]$definition.ownedWorkerContract.delegateSubprocessAllowed -and [bool]$definition.ownedWorkerContract.postStartFailureRequiresConfirmedWorkerExitBeforeAliasOrWorkRollback) 'R18ZT owned-worker definition changed.'
Assert-ReviewAuthority $definition.authority 'R18ZT maintenance definition'
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18zt_payload_manifest_v2' -and [string]$manifest.revision -eq $revision -and [string]$manifest.state -eq 'FROZEN_UNPUBLISHED' -and [bool]$manifest.finalizationComplete) 'R18ZT payload manifest changed.'
Assert-ReviewAuthority $manifest.authority 'R18ZT payload manifest'
Require ([string]$design.schema -ceq 'argos_opencv_scribe_r18zt_batch_package_design_v5' -and [string]$design.state -eq 'FROZEN_UNPUBLISHED' -and [string]$design.artifactLifecycle -eq 'FROZEN' -and [string]$design.requestId -eq $requestId -and [string]$design.revision -eq $revision -and [string]$design.launchSemantics.executionEnvelopeDelegateMode -eq 'IN_PROCESS_PUBLIC_MAIN_NO_SUBPROCESS') 'R18ZT package design changed.'
Require ([string]$design.route.sourceWorkerSha256 -eq [string]$binding.routeEvidence.sourceWorkerSha256 -and [string]$design.route.currentInstalledWorkerSha256 -eq [string]$binding.routeEvidence.currentInstalledWorkerSha256 -and [string]$design.route.queueSafetyGateTargetWorkerSha256 -eq [string]$binding.routeEvidence.inheritedGenericQueueSafetyTargetWorkerSha256 -and [string]$design.route.workerHashRelationship -ceq 'THREE_DISTINCT_PINNED_ROLES_NO_EQUALITY_OR_EQUIVALENCE_INFERRED' -and -not [bool]$design.route.sourceWorkerEqualsCurrentInstalledWorkerClaimed -and -not [bool]$design.route.queueSafetyTargetEqualsCurrentInstalledWorkerClaimed) 'R18ZT package-design worker roles changed.'
Require ([int]$design.proposalAliasContract.caseIdCharacters -eq 20 -and [int]$design.proposalAliasContract.sourceLeafSuffixReserveCharacters -eq 32 -and [int]$design.proposalAliasContract.outputAtomicSuffixReserveCharacters -eq 52 -and [int]$design.proposalAliasContract.exactLongestAtomicOutputLeaf.basePathLength -eq 62 -and [int]$design.proposalAliasContract.exactLongestAtomicOutputLeaf.effectivePathLength -eq 114 -and [int]$design.proposalAliasContract.exactLongestAtomicOutputLeaf.effectiveComponentLength -eq 68 -and [int]$design.proposalAliasContract.launcherConservativeProviderTempBudget.conservativeEffectivePathLength -eq 126 -and [int]$design.proposalAliasContract.launcherConservativeProviderTempBudget.conservativeEffectiveComponentLength -eq 80 -and -not [bool]$design.proposalAliasContract.launcherConservativeProviderTempBudget.trueAtomicWriteTarget) 'R18ZT package-design path facts changed.'
Require ([string]$configuration.schema -eq [string]$binding.runnerConfigSchema -and [string]$configuration.revision -eq $runnerRevision -and [string]$configuration.canonicalProposalRoot -eq $canonicalProposalRoot -and [string]$configuration.proposalRoot -eq $productionProposalAlias -and [int]$configuration.limits.maximumIdentityCharacters -eq 80) 'R18ZT runner configuration changed.'

$outputs = @($definition.entryPointOutputs)
foreach ($outputPin in @(
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZT1\LAUNCH.json';schema='argos_opencv_scribe_r18zt_batch_launch_v2'},
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZT1\RUNNING.json';schema=[string]$binding.outputSchemas.progress},
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZT1\COMPLETE.json';schema=[string]$binding.outputSchemas.complete},
    [pscustomobject]@{path='D:\A2\o\ocv\R18ZT1\STATUS.json';schema=[string]$binding.outputSchemas.status}
)) {
    $matches = @($outputs | Where-Object { [string]$_.path -ceq [string]$outputPin.path })
    Require ($matches.Count -eq 1 -and [string]$matches[0].schema -eq [string]$outputPin.schema) "R18ZT output schema changed: $($outputPin.path)"
}
$runningOutput = @($outputs | Where-Object { [string]$_.path -ceq 'D:\A2\o\ocv\R18ZT1\RUNNING.json' })[0]
Compare-ExactStringSet @($binding.progressPointerAllowedStates) @($runningOutput.allowedStates) 'R18ZT progress-pointer states'
Require ([bool]$runningOutput.terminalStateMayAppearInAtomicProgressPointer -and -not [bool]$runningOutput.terminalSubstitute) 'R18ZT progress-pointer semantics changed.'
$failureOutput = @($outputs | Where-Object { [string]$_.path -ceq 'D:\A2\o\ocv\R18ZT1\FAILURE.json' })[0]
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
$expectedLeafSetSha = Get-TextSha256 ((@($expectedLeafArray | Sort-Object) -join "`n") + "`n")
Require ([int]$pathGate.plannedFinalZipMemberCount -eq $expectedLeafArray.Count -and [string]$pathGate.plannedFinalZipMemberSetSha256 -eq $expectedLeafSetSha) 'R18ZT path-gate membership changed.'
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
        schema = 'argos_opencv_scribe_r18zt_batch_build_preflight_v2'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_PACKAGE_C_BUILD_PREFLIGHT'
        requestId = $requestId
        bindingRecordSha256 = $bindingSha
        payloadFileCount = $payloadFiles.Count
        plannedZipMemberCount = $expectedLeafArray.Count
        collisionScopeCount = $requiredCollisionScopes.Count
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
$runnerSha = [string]($artifactRows | Where-Object name -eq 'batchRunner').sha256
$providerSha = [string]($artifactRows | Where-Object name -eq 'provider').sha256
$r11AnalyzerSha = [string]($artifactRows | Where-Object name -eq 'r11Analyzer').sha256
Assert-ExactLauncherChange @($definition.changes) $launcherSha 'R18ZT maintenance definition'
$stagedPreflight = (& (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1') -Preflight -Rehearsal -PackageValidationOnly -PayloadRoot $activePayload -WorkRoot $testWorkRoot -OutputRoot $testOutputRoot -CanonicalProposalRoot 'C:\R18ZT1C3_PROPOSALS_NOT_ACCESSED' -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$stagedPreflight.state -eq 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' -and -not [bool]$stagedPreflight.targetWritesPerformed -and -not [bool]$stagedPreflight.processStarted -and -not [bool]$stagedPreflight.completionClaimed) 'R18ZT staged static launcher preflight failed.'
$stagedImportSmokeText = (& $localPython -B $importSmokePath --payload-files-root (Join-Path $activePayload 'files') --runner-sha256 $runnerSha --provider-sha256 $providerSha --r11-sha256 $r11AnalyzerSha | Out-String)
Require ($LASTEXITCODE -eq 0) 'R18ZT staged payload import-closure smoke returned nonzero.'
$stagedImportSmoke = $stagedImportSmokeText | ConvertFrom-Json
Require ([string]$stagedImportSmoke.state -eq 'PASS_R18ZT_PACKAGED_IMPORT_CLOSURE_NO_IMAGE' -and [string]$stagedImportSmoke.runnerSha256 -eq $runnerSha -and [string]$stagedImportSmoke.providerSha256 -eq $providerSha -and [string]$stagedImportSmoke.r11AnalyzerSha256 -eq $r11AnalyzerSha -and -not [bool]$stagedImportSmoke.runJobCalled -and -not [bool]$stagedImportSmoke.analyzeImagesCalled -and -not [bool]$stagedImportSmoke.imageBytesRead) 'R18ZT staged payload import-closure smoke failed.'

if ($Test) {
    $stagedJunctionGate = (& (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1') -JunctionGate -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
    Require ([string]$stagedJunctionGate.state -eq 'PASS_R18ZT_PROPOSAL_JUNCTION_CREATION_AND_ROLLBACK' -and [string]$stagedJunctionGate.launcherSha256 -eq $launcherSha -and [bool]$stagedJunctionGate.sleepingWorkerRollbackCasePassed -and [bool]$stagedJunctionGate.fastCompleteReportingFailureCasePassed -and [bool]$stagedJunctionGate.invalidCompleteQuarantineCasePassed -and [bool]$stagedJunctionGate.preexistingRootCollisionRejectedBeforeProcess -and [bool]$stagedJunctionGate.secondFreshControlPassed -and [int]$stagedJunctionGate.completeFailureCoexistenceCount -eq 0 -and [int]$stagedJunctionGate.delegateSubprocessCount -eq 0 -and -not [bool]$stagedJunctionGate.residualTestRootPresent) 'R18ZT staged production launcher gate failed.'
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_unsigned_test_v2'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_PACKAGE_C_UNSIGNED_TEST'
        requestId = $requestId
        bindingRecordSha256 = $bindingSha
        stagedPayloadFileCount = $manifestFiles.Count
        staticEntrypointPreflight = $stagedPreflight
        stagedImportClosure = $stagedImportSmoke
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
$actualLeafSetSha = Get-TextSha256 ((@($actualLeaves | Sort-Object) -join "`n") + "`n")
Require ($actualLeafSetSha -eq $expectedLeafSetSha) 'R18ZT extracted ZIP set hash changed.'
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
$extractedPreflightText = (& $windowsPowerShell51 -NoProfile -ExecutionPolicy Bypass -File $extractedLauncher -Preflight -Rehearsal -PackageValidationOnly -PayloadRoot $extractedPayload -WorkRoot $testWorkRoot -OutputRoot $testOutputRoot -CanonicalProposalRoot 'C:\R18ZT1C3_PROPOSALS_NOT_ACCESSED' -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String)
Require ($LASTEXITCODE -eq 0) 'R18ZT extracted launcher Windows PowerShell 5.1 preflight returned nonzero.'
$extractedPreflight = $extractedPreflightText | ConvertFrom-Json
Require ([string]$extractedPreflight.state -eq 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' -and -not [bool]$extractedPreflight.targetWritesPerformed -and -not [bool]$extractedPreflight.processStarted -and -not [bool]$extractedPreflight.completionClaimed -and -not [bool]$extractedPreflight.sourceImageBytesRead) 'R18ZT extracted launcher Windows PowerShell 5.1 preflight failed.'
$extractedImportSmokeText = (& $localPython -B $importSmokePath --payload-files-root (Join-Path $extractedPayload 'files') --runner-sha256 $runnerSha --provider-sha256 $providerSha --r11-sha256 $r11AnalyzerSha | Out-String)
Require ($LASTEXITCODE -eq 0) 'R18ZT extracted payload import-closure smoke returned nonzero.'
$extractedImportSmoke = $extractedImportSmokeText | ConvertFrom-Json
Require ([string]$extractedImportSmoke.state -eq 'PASS_R18ZT_PACKAGED_IMPORT_CLOSURE_NO_IMAGE' -and [string]$extractedImportSmoke.runnerSha256 -eq $runnerSha -and [string]$extractedImportSmoke.providerSha256 -eq $providerSha -and [string]$extractedImportSmoke.r11AnalyzerSha256 -eq $r11AnalyzerSha -and -not [bool]$extractedImportSmoke.runJobCalled -and -not [bool]$extractedImportSmoke.analyzeImagesCalled -and -not [bool]$extractedImportSmoke.imageBytesRead) 'R18ZT extracted payload import-closure smoke failed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
Copy-Item -LiteralPath $stageZip -Destination (Join-Path $finalPartial $zipName)
foreach ($gate in @($bindingPath,$cloneGatePath,$pathGatePath,$powerShellGatePath,$scienceGatePath,$junctionGatePath,$recoveryIntentPath,$recoveryGatePath,$preactionPath,$collisionGatePath)) {
    Copy-Item -LiteralPath $gate -Destination (Join-Path $finalPartial ([IO.Path]::GetFileName($gate)))
}
$routeGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18zt_complete_route_gate_v2'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18ZT_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED'
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
    publicationMustRecheckAllFourCollisionScopes = $true
    publicationAuthorized = $false
    conditionalPublicationAuthorityText = 'Do the work, if it is successful - as in deciphering correctly. PUBLISH the package to JBOD.'
    exactSlot21ImageFirstString = '13HFX135SUE3'
    slot21AdjudicationSha256 = [string]($artifactRows | Where-Object name -eq 'slot21Adjudication').sha256
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
    schema = 'argos_opencv_scribe_r18zt_final_package_gate_v2'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18ZT_SIGNED_UNPUBLISHED_PACKAGE_GATE'
    requestId = $requestId
    revision = $revision
    bindingRecordSha256 = $bindingSha
    requestZip = 'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE_C/final/REQ_R18ZT1.ready.zip'
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
    recoveryIntentGateSha256 = Get-Sha256 $recoveryGatePath
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
    stagedPackagedImportClosurePassed = $true
    extractedPackagedImportClosurePassed = $true
    executionEnvelopeDelegateMode = 'IN_PROCESS_PUBLIC_MAIN_NO_SUBPROCESS'
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
