#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or
    $PSVersionTable.PSVersion.Major -ne 5 -or
    $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18T builder requires Windows PowerShell 5.1 exactly.'
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

function Require-Pin([string]$Path, [string]$Sha256, [string]$State = '') {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18T build dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18T build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        Require ([string]$record.state -eq $State) "R18T build dependency state changed: $Path"
    }
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18T create-new JSON exists: $Path"
    [IO.File]::WriteAllText(
        $Path,
        (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine),
        (New-Object Text.UTF8Encoding($false))
    )
}

function Get-SafeProjectSource([string]$Project, [string]$Relative) {
    Require (-not [string]::IsNullOrWhiteSpace($Relative)) 'R18T payload source path is empty.'
    Require (-not [IO.Path]::IsPathRooted($Relative) -and $Relative -notmatch '(^|[/\\])\.\.([/\\]|$)') "R18T unsafe project source: $Relative"
    $full = [IO.Path]::GetFullPath((Join-Path $Project $Relative.Replace('/', '\')))
    Require ($full.StartsWith($Project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) "R18T source escaped project: $Relative"
    return $full
}

function Get-SafeChild([string]$Root, [string]$Relative) {
    Require (-not [string]::IsNullOrWhiteSpace($Relative)) 'R18T package path is empty.'
    Require (-not [IO.Path]::IsPathRooted($Relative) -and $Relative -notmatch '(^|[/\\])\.\.([/\\]|$)') "R18T unsafe package path: $Relative"
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $full = [IO.Path]::GetFullPath((Join-Path $rootFull $Relative.Replace('/', '\')))
    Require ($full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) "R18T package path escaped root: $Relative"
    return $full
}

function Assert-ReviewAuthority([object]$Authority, [string]$Label) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) "$Label is not review-only."
    foreach ($field in @(
        'identityAcceptanceAuthorized',
        'automaticReferenceAdmissionAuthorized',
        'trainingAuthorized',
        'activationAuthorized',
        'xmlAuthorized',
        'productionAuthorized'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "$Label authority changed: $field"
    }
}

function Invoke-JsonPython([string]$Python, [string[]]$Arguments, [string]$ExpectedState) {
    $text = (& $Python @Arguments | Out-String)
    Require ($LASTEXITCODE -eq 0) "R18T Python gate exited nonzero: $($Arguments[0])"
    $result = $text | ConvertFrom-Json
    Require ([string]$result.state -eq $ExpectedState) "R18T Python gate state changed: $($Arguments[0])"
    return $result
}

function Compare-ExactStringSet([string[]]$Expected, [string[]]$Actual, [string]$Label) {
    $expectedSorted = @($Expected | Sort-Object)
    $actualSorted = @($Actual | Sort-Object)
    Require ($expectedSorted.Count -eq $actualSorted.Count) "$Label count differs."
    Require (($expectedSorted -join "`n") -ceq ($actualSorted -join "`n")) "$Label members differ."
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18T1'
$revision = 'R18T_LIVE_ONLY_EXECUTION_ENVELOPE_CORRECTION_REVIEW_ONLY_20260904A'
$entrypoint = Join-Path $PSScriptRoot 'Invoke-R18TLiveOnlyLaunch.ps1'
$payloadManifestPath = Join-Path $PSScriptRoot 'R18T_PAYLOAD_MANIFEST.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$cohortPath = Join-Path $PSScriptRoot 'R18T_LIVE_REVIEW_COHORT.json'
$recoveryIntentPath = Join-Path $PSScriptRoot 'R18T_RECOVERY_INTENT.json'
$recoveryGatePath = Join-Path $PSScriptRoot 'R18T_RECOVERY_INTENT_GATE.json'
$bindingGatePath = Join-Path $PSScriptRoot 'R18T_LIVE_BINDING_GATE.json'
$envelopeGatePath = Join-Path $PSScriptRoot 'R18T_EXECUTION_ENVELOPE_GATE.json'
$stagedEnvelopeGatePath = Join-Path $PSScriptRoot 'R18T_STAGED_EXECUTION_ENVELOPE_GATE.json'
$staticPreflightGatePath = Join-Path $PSScriptRoot 'R18T_STATIC_PACKAGE_PREFLIGHT_GATE.json'
$referenceIsolationGatePath = Join-Path $PSScriptRoot 'R18T_REFERENCE_ISOLATION_RERUN_GATE.json'
$contaminationGatePath = Join-Path $PSScriptRoot 'R18T_SOURCE_PACKAGE_CONTAMINATION_GATE.json'
$scienceGatePath = Join-Path $PSScriptRoot 'R18T_FROZEN_SCIENCE_PREPACKAGE_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18T_PATH_PLAN_GATE.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18T_CLONE_GATE.json'
$powerShellSafetyGatePath = Join-Path $PSScriptRoot 'R18T_POWERSHELL_SAFETY_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18T_SIGNED_UNPUBLISHED_PACKAGE.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$historyAudit = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$referenceTest = Join-Path $PSScriptRoot 'Test-R18TReferenceIsolation.py'
$contaminationTest = Join-Path $PSScriptRoot 'Test-R18TPackageContamination.py'
$envelopeTest = Join-Path $PSScriptRoot 'Test-R18TExecutionEnvelope.py'
$localPython = 'C:\ArgosPy313\Scripts\python.exe'
$localReferenceBundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$stageRoot = 'C:\R18T1P'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\R18T1V'
$staticWorkRoot = 'C:\R18T1SW'
$staticOutputRoot = 'C:\R18T1SO'
$nonexistentProposalRoot = 'C:\R18T_PROPOSALS_NOT_ACCESSED'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'R18T_FINAL_PACKAGE_GATE.json'

$entrypointSha = '8667C009631D49916B1A1CFCC78FFA67FF10D7088DCA6FFADD9E28D71DEBE00C'
$payloadManifestSha = '1B0CBDA330DF8756EE57F6B7C6F14EC1F271BB67F3C047DC0ECD0D0FB443F5AD'
$definitionSha = 'D0182E3A5548A3044D549555BC57B66A4E69935ABAB8AE011F7271CE69D5F794'
$cohortSha = '62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661'
$recoveryIntentSha = '0FDAFD81135ADD3396A64843D98B3DD83D74DADDA6650E3C43963EF35A0549C7'
$recoveryGateSha = '2C264EA96DB29CDB42800656282CDA290927EF6415C66E3DE88205C5BB285E0C'
$bindingGateSha = 'C812C22D9D3553B5E1C9827106101193F752A59CDC8AD23E976CCABB8834E8F0'
$envelopeGateSha = 'EF9D1821A3C4F1924B84215DA3BD814FB1AA3693D7E97E0A82EBBF78FF272FDA'
$stagedEnvelopeGateSha = '64664AD9DF558EA134B76A2B163DC9BAEA6B8D5F6D859749B855ED6F32FD57CA'
$staticPreflightGateSha = 'CDE071049A1C476FA015A2E8167619C61865ABD4300BDB1191472B6B1015A62E'
$referenceIsolationGateSha = 'B8C23DF2749F88FC2B8176C31BF21A80C7832DC3F7F5CD18F1AA86C733FA2376'
$contaminationGateSha = 'C2899604411EC7E260695E7B21059084AFDB09FC9938DF21A0C4A4E0C109B64E'
$scienceGateSha = '604FC1E946B1029F887C4C631D74AD079FDFA5D84EDA213964C520D1A31FD978'
$pathGateSha = '98B26B8AF73F290D9B52D6178B735C6747565AFF493AA0AD9F61EB8F4A59ABB9'
$referenceTestSha = '27097B795B293763DC0638F3504013DE1BF367AF827BEAE8DE8B5987E9355CB5'
$contaminationTestSha = 'D5C71D8D29A9BB64EEAFC94E28F4B256197251E8F307BDE51D963290858C11D8'
$envelopeTestSha = '55265D29296EA895E6764127E6C4EE9E7B596E9C2A2B8B15C0E0018E871C6F28'
$localPythonSha = 'D70FCED7F461F38F9F224D8673FB74E96E4FACB4283FF4E8697543B457FEA8A0'
$baseReferenceSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$baseManifestSha = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
$supplementalManifestSha = 'FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114'
$identitySha = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$certificateSha = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$packageTesterSha = '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'

foreach ($pin in @(
    [pscustomobject]@{path=$entrypoint;sha=$entrypointSha;state=''},
    [pscustomobject]@{path=$payloadManifestPath;sha=$payloadManifestSha;state=''},
    [pscustomobject]@{path=$definitionPath;sha=$definitionSha;state='FROZEN_UNPUBLISHED'},
    [pscustomobject]@{path=$cohortPath;sha=$cohortSha;state='FROZEN_CONFIGURATION_SELECTED_COHORT'},
    [pscustomobject]@{path=$recoveryIntentPath;sha=$recoveryIntentSha;state=''},
    [pscustomobject]@{path=$recoveryGatePath;sha=$recoveryGateSha;state='PASS_ARGOS_RECOVERY_INTENT'},
    [pscustomobject]@{path=$bindingGatePath;sha=$bindingGateSha;state='PASS_R18T_LIVE_BINDING_GATE'},
    [pscustomobject]@{path=$envelopeGatePath;sha=$envelopeGateSha;state='PASS_R18T_EXECUTION_ENVELOPE_GATE'},
    [pscustomobject]@{path=$stagedEnvelopeGatePath;sha=$stagedEnvelopeGateSha;state='PASS_R18T_EXECUTION_ENVELOPE_GATE'},
    [pscustomobject]@{path=$staticPreflightGatePath;sha=$staticPreflightGateSha;state='PASS_R18T_STATIC_PACKAGE_PREFLIGHT'},
    [pscustomobject]@{path=$referenceIsolationGatePath;sha=$referenceIsolationGateSha;state='PASS_R18T_REFERENCE_ISOLATION_GATE'},
    [pscustomobject]@{path=$contaminationGatePath;sha=$contaminationGateSha;state='PASS_R18T_PACKAGE_CONTAMINATION_GATE'},
    [pscustomobject]@{path=$scienceGatePath;sha=$scienceGateSha;state='PASS_R18T_FROZEN_SCIENCE_PREPACKAGE_GATE'},
    [pscustomobject]@{path=$pathGatePath;sha=$pathGateSha;state='PASS_PATH_BUDGET'},
    [pscustomobject]@{path=$referenceTest;sha=$referenceTestSha;state=''},
    [pscustomobject]@{path=$contaminationTest;sha=$contaminationTestSha;state=''},
    [pscustomobject]@{path=$envelopeTest;sha=$envelopeTestSha;state=''},
    [pscustomobject]@{path=$localPython;sha=$localPythonSha;state=''},
    [pscustomobject]@{path=$localReferenceBundle;sha=$baseReferenceSha;state=''}
)) {
    Require-Pin $pin.path $pin.sha $pin.state
}

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $payloadManifestPath -Raw | ConvertFrom-Json
$cohort = Get-Content -LiteralPath $cohortPath -Raw | ConvertFrom-Json
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
$recoveryIntent = Get-Content -LiteralPath $recoveryIntentPath -Raw | ConvertFrom-Json
Require ([string]$definition.schema -eq 'argos_opencv_scribe_r18t_maintenance_definition_v1' -and [string]$definition.revision -eq $revision) 'R18T maintenance definition changed.'
Require ([string]$definition.requestId -eq $requestId) 'R18T maintenance request ID changed.'
Require ([string]$definition.entryPoint -eq 'payload/Invoke-R18TLiveOnlyLaunch.ps1') 'R18T maintenance entry point changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and
    @($definition.allowedProcessActions).Count -eq 1 -and
    [string]$definition.allowedProcessActions[0] -eq 'START_ONE_OWNED_BACKGROUND_R18T_EXECUTION_ENVELOPE_WORKER') 'R18T task/process action boundary changed.'
Require (-not [bool]$definition.publication.publicationAuthorized -and -not [bool]$definition.publication.explicitOperatorAuthorityPresent -and -not [bool]$definition.publication.retryAuthorized) 'R18T publication authority changed.'
Assert-ReviewAuthority $definition.authority 'R18T maintenance definition'
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18t_payload_manifest_v1' -and [string]$manifest.revision -eq $revision) 'R18T payload manifest changed.'
Assert-ReviewAuthority $manifest.authority 'R18T payload manifest'
Require ([int]$cohort.caseCount -eq @($cohort.reviewCases).Count -and @($cohort.reviewCases).Count -gt 0) 'R18T cohort cardinality is not collection-derived.'
Require ([string]$recoveryIntent.mode -eq 'MUTATE' -and [string]$recoveryIntent.mutation.supportedRemedy -eq 'B') 'R18T recovery classification changed.'
Require ([string]$recoveryIntent.scope.requestId -eq $requestId -and
    [string]$recoveryIntent.scope.revision -eq $revision -and
    [string]$recoveryIntent.scope.workRoot -eq 'D:/A2/w/ocv/R18T1' -and
    [string]$recoveryIntent.scope.outputRoot -eq 'D:/A2/o/ocv/R18T1' -and
    [string]$recoveryIntent.scope.installedLauncher -eq 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV02_R18T1.ps1' -and
    [bool]$recoveryIntent.scope.stopAtSignedUnpublished) 'R18T recovery intent scope changed.'
Require (-not [bool]$recoveryIntent.authority.publicationAuthorized -and
    -not [bool]$recoveryIntent.mutation.publicationAuthorized -and
    -not [bool]$recoveryIntent.mutation.externalMutationAttemptAuthorized -and
    -not [bool]$recoveryIntent.mutation.automaticRetryAuthorized) 'R18T recovery intent gained external, publication, or retry authority.'
$requiredPublishLiteral = [string]$recoveryIntent.authority.freshLiteralPublishRequired
Require ($requiredPublishLiteral -ceq 'PUBLISH for REQ_R18T1') 'R18T required publication literal changed.'
$changeRows = @($definition.changes)
$mutationRows = @($definition.entryPointMutations)
Require ($changeRows.Count -eq 1 -and
    [string]$changeRows[0].destination -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18T1.ps1') 'R18T installed launcher destination changed.'
Require ($mutationRows.Count -eq 3 -and
    [string]$mutationRows[0].targetRoot -eq 'D:\A2\w\ocv\R18T1' -and
    [string]$mutationRows[1].targetRoot -eq 'D:\A2\o\ocv\R18T1' -and
    [string]$mutationRows[2].mode -eq 'START_ONE_OWNED_BACKGROUND_R18T_EXECUTION_ENVELOPE_WORKER' -and
    [int]$mutationRows[2].maximumOwnedWorkerCount -eq 1 -and
    -not [bool]$mutationRows[2].automaticRetryAllowed) 'R18T execution mutation envelope changed.'

$payloadFiles = @($manifest.files)
Require ($payloadFiles.Count -gt 0) 'R18T payload manifest is empty.'
$installSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $payloadFiles) {
    $relative = [string]$file.installRelativePath
    Require ($installSet.Add($relative)) "R18T duplicate payload install path: $relative"
    $source = Get-SafeProjectSource $project ([string]$file.sourcePath)
    Require-Pin $source ([string]$file.sha256)
    Require ((Get-Item -LiteralPath $source).Length -eq [int64]$file.bytes) "R18T payload source length changed: $($file.sourcePath)"
}

$expectedLeaves = New-Object Collections.Generic.List[string]
foreach ($leaf in @(
    'PORTAL_REQUEST_MANIFEST.json',
    'PORTAL_REQUEST_MANIFEST.sig',
    'payload/Invoke-R18TLiveOnlyLaunch.ps1',
    'payload/R18T_PAYLOAD_MANIFEST.json'
)) { $expectedLeaves.Add($leaf) }
foreach ($file in $payloadFiles) { $expectedLeaves.Add('payload/files/' + ([string]$file.installRelativePath).Replace('\', '/')) }
$expectedLeafArray = @($expectedLeaves.ToArray())
$expectedLeafSetSha = Get-TextSha256 ((@($expectedLeafArray | Sort-Object) -join "`n") + "`n")
Require ([int]$pathGate.plannedFinalZipMemberCount -eq $expectedLeafArray.Count) 'R18T path-gate package count changed.'
Require ([string]$pathGate.plannedFinalZipMemberSetSha256 -eq $expectedLeafSetSha) 'R18T path-gate member set changed.'
Compare-ExactStringSet $expectedLeafArray @($pathGate.plannedFinalZipMembers) 'R18T path-gate planned package set'
Require ([int]$pathGate.unsafePathCount -eq 0 -and [int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80) 'R18T path gate is unsafe.'

Require (Test-Path -LiteralPath $cloneGatePath -PathType Leaf) 'R18T clone gate is absent.'
Require (Test-Path -LiteralPath $powerShellSafetyGatePath -PathType Leaf) 'R18T PowerShell safety gate is absent.'
Require (Test-Path -LiteralPath $preactionPath -PathType Leaf) 'R18T final preaction contract is absent.'
$cloneGate = Get-Content -LiteralPath $cloneGatePath -Raw | ConvertFrom-Json
$powerShellSafetyGate = Get-Content -LiteralPath $powerShellSafetyGatePath -Raw | ConvertFrom-Json
$preaction = Get-Content -LiteralPath $preactionPath -Raw | ConvertFrom-Json
Require ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION') 'R18T clone gate did not pass.'
Require ([string]$powerShellSafetyGate.state -eq 'PASS_R18T_POWERSHELL_SAFETY_GATE') 'R18T PowerShell safety gate did not pass.'
Require ([string]$preaction.state -eq 'PASS_PREACTION_CONTRACT') 'R18T final preaction contract did not pass.'
$builderSelf = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$builderRelative = $builderSelf.Substring($project.TrimEnd('\').Length + 1).Replace('\', '/')
$builderSha = Get-Sha256 $builderSelf
$builderClonePins = @($cloneGate.pairs | Where-Object { [string]$_.generated -eq $builderRelative })
Require ($builderClonePins.Count -eq 1 -and [string]$builderClonePins[0].generatedSha256 -eq $builderSha) 'R18T clone gate does not bind this exact builder.'
$builderPreactionPins = @($preaction.dependencies | Where-Object { [string]$_.path -eq $builderRelative })
Require ($builderPreactionPins.Count -eq 1 -and [string]$builderPreactionPins[0].sha256 -eq $builderSha) 'R18T final preaction does not pin this exact builder.'
$preactionResult = (& $preactionTool -AuditPath $historyAudit -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18T final zero-recurrence preaction failed.'

# Public verification material is safe to pin during preflight. The CurrentUser
# certificate store and private key remain untouched until all staged gates pass.
Require-Pin $identityPath $identitySha
Require-Pin $publicCertificate $certificateSha
Require-Pin $packageTester $packageTesterSha

foreach ($path in @(
    $stageRoot,
    $readyRoot,
    $stageZip,
    $verifyRoot,
    $staticWorkRoot,
    $staticOutputRoot,
    $finalRoot,
    $finalPartial,
    $finalGatePath
)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18T fresh build output exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18t_build_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18T_BUILD_PREFLIGHT'
        requestId = $requestId
        revision = $revision
        builderSha256 = $builderSha
        entrypointSha256 = $entrypointSha
        payloadManifestSha256 = $payloadManifestSha
        maintenanceDefinitionSha256 = $definitionSha
        cohortSha256 = $cohortSha
        payloadManifestFileCount = $payloadFiles.Count
        finalZipMemberCount = $expectedLeafArray.Count
        finalZipMemberSetSha256 = $expectedLeafSetSha
        pathCandidateCount = [int]$pathGate.evaluatedCandidateCount
        maximumEffectiveLength = [int]$pathGate.maximumEffectiveLength
        allCardinalitiesDerivedFromCollections = $true
        preactionState = [string]$preactionResult.state
        cloneGateState = [string]$cloneGate.state
        powerShellSafetyGateState = [string]$powerShellSafetyGate.state
        publicSigningDependenciesVerified = $true
        signerCertificateStoreAccessed = $false
        privateKeyAccessed = $false
        zipCreated = $false
        sourceWaferImagesRead = $false
        pixelsDecoded = $false
        targetExecuted = $false
        mutationsPerformed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12
    return
}

[void](New-Item -ItemType Directory -Path $stageRoot)
[void](New-Item -ItemType Directory -Path $readyRoot)
[void](New-Item -ItemType Directory -Path (Join-Path $readyRoot 'payload\files'))
Copy-Item -LiteralPath $entrypoint -Destination (Join-Path $readyRoot 'payload\Invoke-R18TLiveOnlyLaunch.ps1')
Copy-Item -LiteralPath $payloadManifestPath -Destination (Join-Path $readyRoot 'payload\R18T_PAYLOAD_MANIFEST.json')
$manifestFiles = New-Object Collections.Generic.List[object]
$manifestFiles.Add([ordered]@{
    path = 'payload/Invoke-R18TLiveOnlyLaunch.ps1'
    bytes = [int64](Get-Item -LiteralPath $entrypoint).Length
    sha256 = $entrypointSha
})
$manifestFiles.Add([ordered]@{
    path = 'payload/R18T_PAYLOAD_MANIFEST.json'
    bytes = [int64](Get-Item -LiteralPath $payloadManifestPath).Length
    sha256 = $payloadManifestSha
})
foreach ($file in $payloadFiles) {
    $source = Get-SafeProjectSource $project ([string]$file.sourcePath)
    $packagePath = 'payload/files/' + ([string]$file.installRelativePath).Replace('\', '/')
    $destination = Get-SafeChild $readyRoot $packagePath
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath $source -Destination $destination
    Require-Pin $destination ([string]$file.sha256)
    $manifestFiles.Add([ordered]@{path=$packagePath;bytes=[int64]$file.bytes;sha256=[string]$file.sha256})
}
Require ($manifestFiles.Count -eq ($payloadFiles.Count + 2)) 'R18T signed file collection was not derived from the payload collection.'

$stagedPayload = Join-Path $readyRoot 'payload'
$stagedLauncher = Join-Path $stagedPayload 'Invoke-R18TLiveOnlyLaunch.ps1'
$stagedManifest = Join-Path $stagedPayload 'R18T_PAYLOAD_MANIFEST.json'
$stagedFiles = Join-Path $stagedPayload 'files'
$stagedCohort = Join-Path $stagedFiles 'OPENCV_SCRIBE_R18T\R18T_LIVE_REVIEW_COHORT.json'
$stagedWorker = Join-Path $stagedFiles 'OPENCV_SCRIBE_R18T\Run-R18TExecutionEnvelope.py'
$stagedRunner = Join-Path $stagedFiles 'OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py'
$stagedSupplemental = Join-Path $stagedFiles 'OPENCV_SCRIBE_R18F\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json'

$stagedStaticPreflight = (& $stagedLauncher -Preflight -Rehearsal -PackageValidationOnly `
    -PayloadRoot $stagedPayload -WorkRoot $staticWorkRoot -OutputRoot $staticOutputRoot `
    -ProposalRoot $nonexistentProposalRoot -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha `
    -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$stagedStaticPreflight.state -eq 'PASS_R18T_STATIC_PACKAGE_PREFLIGHT') 'R18T staged static entrypoint preflight failed.'
Require ([bool]$stagedStaticPreflight.liveBindingDeferredToEndpoint -and -not [bool]$stagedStaticPreflight.sourceImageBytesHashed -and -not [bool]$stagedStaticPreflight.processStarted -and -not [bool]$stagedStaticPreflight.targetWritesPerformed) 'R18T staged static preflight exceeded its boundary.'

$stagedReferenceGate = Invoke-JsonPython $localPython @(
    '-B', $referenceTest,
    '--runner', $stagedRunner,
    '--payload-manifest', $stagedManifest,
    '--payload-files-root', $stagedFiles,
    '--cohort', $stagedCohort,
    '--base-bundle', $localReferenceBundle,
    '--base-bundle-sha256', $baseReferenceSha,
    '--base-manifest-sha256', $baseManifestSha,
    '--supplemental-manifest', $stagedSupplemental,
    '--supplemental-manifest-sha256', $supplementalManifestSha
) 'PASS_R18T_REFERENCE_ISOLATION_GATE'
$stagedContaminationGate = Invoke-JsonPython $localPython @(
    '-B', $contaminationTest,
    '--payload-root', $stagedPayload,
    '--payload-manifest', $stagedManifest,
    '--launcher', $stagedLauncher,
    '--launcher-sha256', $entrypointSha
) 'PASS_R18T_PACKAGE_CONTAMINATION_GATE'
$stagedWorkerGate = Invoke-JsonPython $localPython @(
    '-B', $envelopeTest,
    '--worker', $stagedWorker
) 'PASS_R18T_EXECUTION_ENVELOPE_GATE'
Require ([bool]$stagedReferenceGate.allCardinalitiesDerivedFromCollections -and -not [bool]$stagedReferenceGate.imageBytesRead) 'R18T staged reference gate changed.'
Require ([int]$stagedContaminationGate.slot24OrLocalFixtureTokenCount -eq 0 -and [int]$stagedContaminationGate.fixedExpectedCorpusCountTokenCount -eq 0 -and [int]$stagedContaminationGate.runtimeOverrideCount -eq 0 -and [int]$stagedContaminationGate.anonymousPipeRedirectCount -eq 0) 'R18T staged contamination gate failed.'
Require ([bool]$stagedWorkerGate.atomicFailureCommit -and [int]$stagedWorkerGate.falseCompleteCount -eq 0) 'R18T staged worker failure gate changed.'

# Signing material is intentionally inaccessible until every exact staged-byte
# preflight and rehearsal above has passed.
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store(
    'My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $certificateMatches = @($store.Certificates | Where-Object {
        ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint
    })
    Require ($certificateMatches.Count -eq 1 -and $certificateMatches[0].HasPrivateKey) 'R18T signer certificate/private key changed.'
    $certificate = $certificateMatches[0]
}
finally {
    $store.Close()
    $store.Dispose()
}

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
    changes = @($definition.changes)
    entryPointMutations = @($definition.entryPointMutations)
    entryPointOutputs = @($definition.entryPointOutputs)
    workerEnvelopeContract = $definition.workerEnvelopeContract
    liveInputBindingContract = $definition.liveInputBindingContract
    sourceProcessingContract = $definition.sourceProcessingContract
    timeoutContract = $definition.timeoutContract
    allowedTaskActions = @($definition.allowedTaskActions)
    allowedProcessActions = @($definition.allowedProcessActions)
    publication = $definition.publication
}
$requestManifestPath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($requestManifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($requestManifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
Require ($null -ne $rsa) 'R18T signer certificate has no RSA private key.'
try {
    $signature = $rsa.SignData(
        $manifestBytes,
        [Security.Cryptography.HashAlgorithmName]::SHA256,
        [Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
}
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
$stagedSignatureRows = @(& $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH)
Require ($stagedSignatureRows.Count -eq 1) 'R18T staged signed-package verifier returned an unexpected result count.'
$stagedSignatureGate = $stagedSignatureRows[0]
Require ([string]$stagedSignatureGate.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and
    [string]$stagedSignatureGate.RequestId -eq $requestId -and
    [string]$stagedSignatureGate.TargetRole -eq 'JBOD' -and
    [string]$stagedSignatureGate.JobClass -eq 'MAINTENANCE_PATCH' -and
    [int]$stagedSignatureGate.PayloadFiles -eq $manifestFiles.Count -and
    [bool]$stagedSignatureGate.ReviewOnly -and
    -not [bool]$stagedSignatureGate.ProductionRoutingEnabled) 'R18T staged signed-package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $stageZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($stageZip, $verifyRoot)
$extractedFiles = @(Get-ChildItem -LiteralPath $verifyRoot -Recurse -File)
$actualLeaves = @($extractedFiles | ForEach-Object {
    $_.FullName.Substring($verifyRoot.Length + 1).Replace('\', '/')
})
Compare-ExactStringSet $expectedLeafArray $actualLeaves 'R18T extracted ZIP'
$actualLeafSetSha = Get-TextSha256 ((@($actualLeaves | Sort-Object) -join "`n") + "`n")
Require ($actualLeafSetSha -eq $expectedLeafSetSha) 'R18T extracted ZIP set hash changed.'
foreach ($row in $manifestFiles) {
    $path = Get-SafeChild $verifyRoot ([string]$row.path)
    Require-Pin $path ([string]$row.sha256)
    Require ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes) "R18T extracted payload length changed: $($row.path)"
}
Require-Pin (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json') (Get-Sha256 $requestManifestPath)
Require-Pin (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig') (Get-Sha256 $signaturePath)
$extractedSignatureRows = @(& $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH)
Require ($extractedSignatureRows.Count -eq 1) 'R18T extracted signed-package verifier returned an unexpected result count.'
$extractedSignatureGate = $extractedSignatureRows[0]
Require ([string]$extractedSignatureGate.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and
    [string]$extractedSignatureGate.RequestId -eq $requestId -and
    [string]$extractedSignatureGate.TargetRole -eq 'JBOD' -and
    [string]$extractedSignatureGate.JobClass -eq 'MAINTENANCE_PATCH' -and
    [int]$extractedSignatureGate.PayloadFiles -eq $manifestFiles.Count -and
    [bool]$extractedSignatureGate.ReviewOnly -and
    -not [bool]$extractedSignatureGate.ProductionRoutingEnabled) 'R18T extracted signed-package verification failed.'

$extractedPayload = Join-Path $verifyRoot 'payload'
$extractedLauncher = Join-Path $extractedPayload 'Invoke-R18TLiveOnlyLaunch.ps1'
$extractedManifest = Join-Path $extractedPayload 'R18T_PAYLOAD_MANIFEST.json'
$extractedPayloadFiles = Join-Path $extractedPayload 'files'
$extractedCohort = Join-Path $extractedPayloadFiles 'OPENCV_SCRIBE_R18T\R18T_LIVE_REVIEW_COHORT.json'
$extractedWorker = Join-Path $extractedPayloadFiles 'OPENCV_SCRIBE_R18T\Run-R18TExecutionEnvelope.py'
$extractedRunner = Join-Path $extractedPayloadFiles 'OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py'
$extractedSupplemental = Join-Path $extractedPayloadFiles 'OPENCV_SCRIBE_R18F\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json'
$extractedStaticPreflight = (& $extractedLauncher -Preflight -Rehearsal -PackageValidationOnly `
    -PayloadRoot $extractedPayload -WorkRoot $staticWorkRoot -OutputRoot $staticOutputRoot `
    -ProposalRoot $nonexistentProposalRoot -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha `
    -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$extractedStaticPreflight.state -eq 'PASS_R18T_STATIC_PACKAGE_PREFLIGHT' -and -not [bool]$extractedStaticPreflight.sourceImageBytesHashed) 'R18T extracted static entrypoint preflight failed.'
$extractedReferenceGate = Invoke-JsonPython $localPython @(
    '-B', $referenceTest,
    '--runner', $extractedRunner,
    '--payload-manifest', $extractedManifest,
    '--payload-files-root', $extractedPayloadFiles,
    '--cohort', $extractedCohort,
    '--base-bundle', $localReferenceBundle,
    '--base-bundle-sha256', $baseReferenceSha,
    '--base-manifest-sha256', $baseManifestSha,
    '--supplemental-manifest', $extractedSupplemental,
    '--supplemental-manifest-sha256', $supplementalManifestSha
) 'PASS_R18T_REFERENCE_ISOLATION_GATE'
$extractedContaminationGate = Invoke-JsonPython $localPython @(
    '-B', $contaminationTest,
    '--payload-root', $extractedPayload,
    '--payload-manifest', $extractedManifest,
    '--launcher', $extractedLauncher,
    '--launcher-sha256', $entrypointSha
) 'PASS_R18T_PACKAGE_CONTAMINATION_GATE'
$extractedWorkerGate = Invoke-JsonPython $localPython @(
    '-B', $envelopeTest,
    '--worker', $extractedWorker
) 'PASS_R18T_EXECUTION_ENVELOPE_GATE'
Require ([int]$extractedContaminationGate.slot24OrLocalFixtureTokenCount -eq 0 -and [int]$extractedContaminationGate.runtimeTestArtifactCount -eq 0 -and [int]$extractedContaminationGate.fixedExpectedCorpusCountTokenCount -eq 0 -and [int]$extractedContaminationGate.runtimeOverrideCount -eq 0 -and [int]$extractedContaminationGate.anonymousPipeRedirectCount -eq 0) 'R18T extracted contamination gate failed.'
Require ([bool]$extractedWorkerGate.atomicFailureCommit -and [int]$extractedWorkerGate.falseCompleteCount -eq 0) 'R18T extracted worker failure gate changed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
Copy-Item -LiteralPath $stageZip -Destination (Join-Path $finalPartial $zipName)
foreach ($gateCopy in @(
    [pscustomobject]@{source=$pathGatePath;name=($zipName + '.path_gate.json')},
    [pscustomobject]@{source=$recoveryGatePath;name=($zipName + '.recovery_intent_gate.json')},
    [pscustomobject]@{source=$scienceGatePath;name=($zipName + '.frozen_science_gate.json')},
    [pscustomobject]@{source=$cloneGatePath;name=($zipName + '.clone_gate.json')},
    [pscustomobject]@{source=$powerShellSafetyGatePath;name=($zipName + '.powershell_safety_gate.json')},
    [pscustomobject]@{source=$preactionPath;name=($zipName + '.preaction.json')}
)) {
    Copy-Item -LiteralPath $gateCopy.source -Destination (Join-Path $finalPartial $gateCopy.name)
}

$packagedRuntimeGatePath = Join-Path $finalPartial 'R18T_PACKAGED_RUNTIME_GATE.json'
$packagedRuntimeGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18t_packaged_runtime_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18T_PACKAGED_RUNTIME_GATE'
    requestId = $requestId
    requestZipSha256 = Get-Sha256 $stageZip
    requestManifestSha256 = Get-Sha256 $requestManifestPath
    finalZipMemberCount = $actualLeaves.Count
    finalZipMemberSetSha256 = $actualLeafSetSha
    payloadManifestFileCount = $payloadFiles.Count
    pythonRuntimeSourceCount = @($payloadFiles | Where-Object { [IO.Path]::GetExtension([string]$_.installRelativePath) -eq '.py' }).Count
    stagedStaticPreflight = $stagedStaticPreflight
    extractedStaticPreflight = $extractedStaticPreflight
    stagedReferenceIsolation = $stagedReferenceGate
    extractedReferenceIsolation = $extractedReferenceGate
    stagedContamination = $stagedContaminationGate
    extractedContamination = $extractedContaminationGate
    stagedExecutionEnvelope = $stagedWorkerGate
    extractedExecutionEnvelope = $extractedWorkerGate
    stagedSignatureState = [string]$stagedSignatureGate.State
    extractedSignatureState = [string]$extractedSignatureGate.State
    allCardinalitiesDerivedFromCollections = $true
    slot24PackageExcluded = $true
    frozenScientificHashesMatched = $true
    sourceWaferImagesRead = $false
    frozenReferenceAssetsCopiedAndHashedWithoutPixelDecode = $true
    pixelsDecoded = $false
    targetExecuted = $false
    publicationAuthorized = $false
    publicationPerformed = $false
    identityAccepted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonNew $packagedRuntimeGatePath $packagedRuntimeGate
$packagedRuntimeGateSha = Get-Sha256 $packagedRuntimeGatePath

$completeRouteGatePath = Join-Path $finalPartial ($zipName + '.complete_route_gate.json')
$completeRouteGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18t_complete_route_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18T_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED'
    requestId = $requestId
    requestZipSha256 = Get-Sha256 $stageZip
    requestZipBytes = [int64](Get-Item -LiteralPath $stageZip).Length
    requestManifestSha256 = Get-Sha256 $requestManifestPath
    pathPlanGateSha256 = $pathGateSha
    actualFinalZipMemberCount = $actualLeaves.Count
    actualFinalZipMemberSetSha256 = $actualLeafSetSha
    actualFinalZipMembers = @($actualLeaves | Sort-Object)
    evaluatedPathCandidateCount = [int]$pathGate.evaluatedCandidateCount
    maximumEffectiveLength = [int]$pathGate.maximumEffectiveLength
    maximumComponentLength = [int]$pathGate.maximumComponentLength
    longestConstructedLeaf = [string]$pathGate.longestConstructedLeaf
    reservedSuffixCharacters = [int]$pathGate.reservedSuffixCharacters
    unsafePathCount = [int]$pathGate.unsafePathCount
    externalExistenceChecked = $false
    queueState = 'NOT_OBSERVED_BY_LOCAL_BUILDER'
    requestNamespaceState = 'NOT_OBSERVED_BY_LOCAL_BUILDER'
    publicationMustRecheckQueueAndNamespace = $true
    publicationAuthorized = $false
    explicitPublishStillRequired = $true
    requiredLiteral = $requiredPublishLiteral
    maximumPublicationsAfterFreshAuthority = 1
    retryAuthorized = $false
    targetExecuted = $false
    sourceWaferImagesRead = $false
    pixelsDecoded = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonNew $completeRouteGatePath $completeRouteGate
$completeRouteGateSha = Get-Sha256 $completeRouteGatePath

Move-Item -LiteralPath $finalPartial -Destination $finalRoot
$finalZipPath = Join-Path $finalRoot $zipName
Require-Pin $finalZipPath (Get-Sha256 $stageZip)
foreach ($gateCopy in @(
    [pscustomobject]@{source=$pathGatePath;name=($zipName + '.path_gate.json')},
    [pscustomobject]@{source=$recoveryGatePath;name=($zipName + '.recovery_intent_gate.json')},
    [pscustomobject]@{source=$scienceGatePath;name=($zipName + '.frozen_science_gate.json')},
    [pscustomobject]@{source=$cloneGatePath;name=($zipName + '.clone_gate.json')},
    [pscustomobject]@{source=$powerShellSafetyGatePath;name=($zipName + '.powershell_safety_gate.json')},
    [pscustomobject]@{source=$preactionPath;name=($zipName + '.preaction.json')}
)) {
    Require-Pin (Join-Path $finalRoot $gateCopy.name) (Get-Sha256 $gateCopy.source)
}
Require-Pin (Join-Path $finalRoot 'R18T_PACKAGED_RUNTIME_GATE.json') $packagedRuntimeGateSha
Require-Pin (Join-Path $finalRoot ($zipName + '.complete_route_gate.json')) $completeRouteGateSha

$finalGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18t_final_package_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18T_SIGNED_UNPUBLISHED_PACKAGE_GATE'
    requestId = $requestId
    revision = $revision
    requestZip = 'work/OPENCV_SCRIBE_R18T/final/REQ_R18T1.ready.zip'
    requestZipBytes = [int64](Get-Item -LiteralPath $finalZipPath).Length
    requestZipSha256 = Get-Sha256 $finalZipPath
    requestManifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
    requestSignatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
    expiresUtc = [string]$requestManifest.expiresUtc
    builderSha256 = $builderSha
    launcherSha256 = $entrypointSha
    payloadManifestSha256 = $payloadManifestSha
    maintenanceDefinitionSha256 = $definitionSha
    cohortSha256 = $cohortSha
    recoveryIntentSha256 = $recoveryIntentSha
    recoveryIntentGateSha256 = $recoveryGateSha
    pathPlanGateSha256 = $pathGateSha
    sciencePrepackageGateSha256 = $scienceGateSha
    cloneGateSha256 = Get-Sha256 $cloneGatePath
    powerShellSafetyGateSha256 = Get-Sha256 $powerShellSafetyGatePath
    preactionSha256 = Get-Sha256 $preactionPath
    packagedRuntimeGateSha256 = $packagedRuntimeGateSha
    completeRouteGateSha256 = $completeRouteGateSha
    payloadManifestFileCount = $payloadFiles.Count
    signedPayloadFileCount = $manifestFiles.Count
    finalZipMemberCount = $actualLeaves.Count
    finalZipMemberSetSha256 = $actualLeafSetSha
    allCardinalitiesDerivedFromCollections = $true
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    preSignatureStaticEntrypointPreflightPassed = $true
    extractedStaticEntrypointPreflightPassed = $true
    stagedReferenceIsolationPassed = $true
    extractedReferenceIsolationPassed = $true
    stagedExecutionEnvelopeFailurePassed = $true
    extractedExecutionEnvelopeFailurePassed = $true
    slot24PackageExcluded = $true
    frozenScientificHashesMatched = $true
    checksumVerificationRequired = $true
    checksumUsedForImageFirst = $false
    syntheticDotsAllowed = $false
    notchDependenceAllowed = $false
    wholeWaferFallbackAllowed = $false
    sourceWaferImagesRead = $false
    frozenReferenceAssetsCopiedAndHashedWithoutPixelDecode = $true
    pixelsDecoded = $false
    signerAccessOccurredAfterExactStagedPreflights = $true
    targetExecuted = $false
    backgroundProcessStarted = $false
    publicationAuthorized = $false
    publicationPerformed = $false
    explicitPublishStillRequired = $true
    requiredLiteral = $requiredPublishLiteral
    maximumPublicationsAfterFreshAuthority = 1
    retryAuthorized = $false
    r18sBuildAuthorized = $false
    r18sPublicationAuthorized = $false
    identityAccepted = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
Write-JsonNew $finalGatePath $finalGate
$finalGate | ConvertTo-Json -Depth 32
