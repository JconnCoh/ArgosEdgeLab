#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$modes = New-Object Collections.Generic.List[string]
if ($Preflight) { $modes.Add('Preflight') }
if ($Test) { $modes.Add('Test') }
if ($Build) { $modes.Add('Build') }
if ($modes.Count -ne 1) { throw 'Specify exactly one of -Preflight, -Test, or -Build.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18ZT builder requires Windows PowerShell 5.1 exactly.'
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
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18ZT build dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18ZT build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $record = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        Require ([string]$record.state -eq $State) "R18ZT build dependency state changed: $Path"
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

function Assert-ReviewAuthority([object]$Authority, [string]$Label) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) "$Label is not review-only."
    foreach ($field in @(
        'identityAcceptanceAuthorized',
        'automaticReferenceAdmissionAuthorized',
        'holdClearanceAuthorized',
        'trainingAuthorized',
        'activationAuthorized',
        'xmlAuthorized',
        'productionAuthorized',
        'sourceMutationAuthorized',
        'sourceDeletionAuthorized'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "$Label authority changed: $field"
    }
}

function Compare-ExactStringSet([string[]]$Expected, [string[]]$Actual, [string]$Label) {
    $expectedSorted = @($Expected | Sort-Object)
    $actualSorted = @($Actual | Sort-Object)
    Require ($expectedSorted.Count -eq $actualSorted.Count) "$Label count differs."
    Require (($expectedSorted -join "`n") -ceq ($actualSorted -join "`n")) "$Label members differ."
}

function Get-UniqueOutputContract([object[]]$Outputs, [string]$Path) {
    $matches = @($Outputs | Where-Object { [string]$_.path -ceq $Path })
    Require ($matches.Count -eq 1) "R18ZT output contract count changed: $Path"
    return $matches[0]
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18ZT create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18ZT1'
$revision = 'R18ZT_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260906'
$productionWorkRoot = 'D:\A2\w\ocv\R18ZT1'
$productionOutputRoot = 'D:\A2\o\ocv\R18ZT1'
$productionInstalledLauncher = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZT1.ps1'
$launcherPath = Join-Path $PSScriptRoot 'Invoke-R18ZTBatchLaunch.ps1'
$payloadManifestPath = Join-Path $PSScriptRoot 'R18ZT_PAYLOAD_MANIFEST.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$configurationPath = Join-Path $PSScriptRoot 'R18ZT_BATCH_CONFIGURATION.json'
$designPath = Join-Path $PSScriptRoot 'R18ZT_BATCH_PACKAGE_DESIGN.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18ZT_CLONE_GATE_V2.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18ZT_PATH_PLAN_GATE.json'
$powerShellGatePath = Join-Path $PSScriptRoot 'R18ZT_POWERSHELL_SAFETY_GATE.json'
$scienceGatePath = Join-Path $PSScriptRoot 'R18ZT_SCIENCE_GATE.json'
$recoveryGatePath = Join-Path $PSScriptRoot 'R18ZT_RECOVERY_INTENT_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18ZT_SIGNED_UNPUBLISHED_PACKAGE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$localPython = 'C:\ArgosPy313\Scripts\python.exe'
$localReferenceBundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$testRoot = 'C:\R18ZT1T'
$testWorkRoot = 'C:\R18ZT1TW'
$testOutputRoot = 'C:\R18ZT1TO'
$stageRoot = 'C:\R18ZT1P'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\R18ZT1V'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$finalGatePath = Join-Path $PSScriptRoot 'R18ZT_FINAL_PACKAGE_GATE.json'

$launcherSha = '1AB69CB2DE9D03BCDF5C346AE2D6B37FEFFD450FF9A8CFF511ED3EAA5883A999'
$payloadManifestSha = '0C8A0A36DD8B4950022D04FDBC2065C3EB41D3C258CDD7D1435E4B68A7159E40'
$definitionSha = '471C4F8B64F3126C727F40C2FD8D528FFAA2CE4E94C8E7FC4BC18C05B9031B4E'
$configurationSha = '67A5D3B4BA3FA2187CEE4E4DA002CC2E72D1D7C3DE5D45C4C056D49579090844'
$designSha = '00BB94203C06D8C4FF3089847C02288A909130678C1BD90A1272A0670D1E1FB2'
$identitySha = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$certificateSha = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$packageTesterSha = '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'
$localPythonSha = 'D70FCED7F461F38F9F224D8673FB74E96E4FACB4283FF4E8697543B457FEA8A0'
$baseReferenceSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'

$pending = New-Object Collections.Generic.List[string]
foreach ($pin in @(
    [pscustomobject]@{value=$launcherSha;label='launcher'},
    [pscustomobject]@{value=$payloadManifestSha;label='payload manifest'},
    [pscustomobject]@{value=$definitionSha;label='maintenance definition'},
    [pscustomobject]@{value=$configurationSha;label='batch configuration'},
    [pscustomobject]@{value=$designSha;label='package design'}
)) {
    if ([string]$pin.value -cnotmatch '^[A-F0-9]{64}$') { $pending.Add([string]$pin.label) }
}
if ($pending.Count -gt 0) {
    if ($Preflight) {
        [ordered]@{
            schema = 'argos_opencv_scribe_r18zt_batch_build_preflight_v1'
            checkedUtc = [DateTime]::UtcNow.ToString('o')
            state = 'HOLD_R18ZT_BATCH_PACKAGE_HASHES_PENDING'
            requestId = $requestId
            pendingPins = $pending.ToArray()
            targetWritesPerformed = $false
            signerAccessed = $false
            packageBuilt = $false
            publicationPerformed = $false
            reviewOnly = $true
            productionRoutingEnabled = $false
        } | ConvertTo-Json -Depth 8
        return
    }
    throw ('R18ZT package hashes are not finalized: ' + ($pending -join ', '))
}

foreach ($pin in @(
    [pscustomobject]@{path=$launcherPath;sha=$launcherSha;state=''},
    [pscustomobject]@{path=$payloadManifestPath;sha=$payloadManifestSha;state='FROZEN_UNPUBLISHED'},
    [pscustomobject]@{path=$definitionPath;sha=$definitionSha;state='FROZEN_UNPUBLISHED'},
    [pscustomobject]@{path=$configurationPath;sha=$configurationSha;state=''},
    [pscustomobject]@{path=$designPath;sha=$designSha;state='FROZEN_UNPUBLISHED'},
    [pscustomobject]@{path=$identityPath;sha=$identitySha;state=''},
    [pscustomobject]@{path=$publicCertificate;sha=$certificateSha;state=''},
    [pscustomobject]@{path=$packageTester;sha=$packageTesterSha;state=''},
    [pscustomobject]@{path=$localPython;sha=$localPythonSha;state=''},
    [pscustomobject]@{path=$localReferenceBundle;sha=$baseReferenceSha;state=''}
)) { Require-Pin ([string]$pin.path) ([string]$pin.sha) ([string]$pin.state) }

$gatePins = @(
    [pscustomobject]@{path=$cloneGatePath;state='PASS_ARGOS_CLONE_LITERAL_REMEDIATION'},
    [pscustomobject]@{path=$pathGatePath;state='PASS_PATH_BUDGET'},
    [pscustomobject]@{path=$powerShellGatePath;state='PASS_R18ZT_POWERSHELL_SAFETY_GATE'},
    [pscustomobject]@{path=$scienceGatePath;state='PASS_R18ZT_BATCH_SCIENCE_GATE'},
    [pscustomobject]@{path=$recoveryGatePath;state='PASS_ARGOS_RECOVERY_INTENT'},
    [pscustomobject]@{path=$preactionPath;state='PASS_PREACTION_CONTRACT'}
)
foreach ($gatePin in $gatePins) {
    Require (Test-Path -LiteralPath $gatePin.path -PathType Leaf) "R18ZT gate absent: $($gatePin.path)"
    $gateRecord = Get-Content -LiteralPath $gatePin.path -Raw | ConvertFrom-Json
    Require ([string]$gateRecord.state -eq [string]$gatePin.state) "R18ZT gate state changed: $($gatePin.path)"
}
$cloneGateSha = Get-Sha256 $cloneGatePath
$pathGateSha = Get-Sha256 $pathGatePath
$powerShellGateSha = Get-Sha256 $powerShellGatePath
$scienceGateSha = Get-Sha256 $scienceGatePath
$recoveryGateSha = Get-Sha256 $recoveryGatePath
$preactionSha = Get-Sha256 $preactionPath

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$manifest = Get-Content -LiteralPath $payloadManifestPath -Raw | ConvertFrom-Json
$design = Get-Content -LiteralPath $designPath -Raw | ConvertFrom-Json
$configuration = Get-Content -LiteralPath $configurationPath -Raw | ConvertFrom-Json
$cloneGate = Get-Content -LiteralPath $cloneGatePath -Raw | ConvertFrom-Json
$pathGate = Get-Content -LiteralPath $pathGatePath -Raw | ConvertFrom-Json
$builderPath = [IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)
$expectedClonePairs = [ordered]@{
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE/Invoke-R18ZTBatchLaunch.ps1' = $launcherSha
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE/Build-R18ZTBatchRequest.ps1' = (Get-Sha256 $builderPath)
    'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE/Run-R18ZTBatchExecutionEnvelope.py' = 'E34C78C52B30AA7745DC71008E35BE97B4CB3256C46C20FEBCF579C15C9E2240'
}
Require ([string]$cloneGate.mode -eq 'GATE' -and [bool]$cloneGate.metadataOnly -and -not [bool]$cloneGate.targetExecuted -and [bool]$cloneGate.evidenceWritten) 'R18ZT clone gate execution contract changed.'
$clonePairs = @($cloneGate.pairs)
Require ($clonePairs.Count -eq $expectedClonePairs.Count) 'R18ZT clone gate pair count changed.'
foreach ($expectedPair in $expectedClonePairs.GetEnumerator()) {
    $matches = @($clonePairs | Where-Object { [string]$_.generated -ceq [string]$expectedPair.Key })
    Require ($matches.Count -eq 1 -and [string]$matches[0].generatedSha256 -eq [string]$expectedPair.Value) "R18ZT stale clone gate pair: $($expectedPair.Key)"
}
Require ([string]$definition.schema -eq 'argos_opencv_scribe_r18zt_maintenance_definition_v1' -and [string]$definition.revision -eq $revision -and [string]$definition.requestId -eq $requestId) 'R18ZT maintenance definition changed.'
Require ([string]$definition.entryPoint -eq 'payload/Invoke-R18ZTBatchLaunch.ps1' -and [string]$definition.rehearsal.requiredState -eq 'PASS_R18ZT_BATCH_WORKER_STARTED' -and -not [bool]$definition.rehearsal.completionClaimed) 'R18ZT launch-only endpoint contract changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1 -and [string]$definition.allowedProcessActions[0] -eq 'START_ONE_OWNED_BACKGROUND_R18ZT_BATCH_WORKER') 'R18ZT task/process action boundary changed.'
Require (-not [bool]$definition.publication.publicationAuthorized -and -not [bool]$definition.publication.retryAuthorized) 'R18ZT definition gained publication or retry authority.'
Assert-ReviewAuthority $definition.authority 'R18ZT maintenance definition'
$outputs = @($definition.entryPointOutputs)
$launchOutput = Get-UniqueOutputContract $outputs 'D:\A2\o\ocv\R18ZT1\LAUNCH.json'
$runningOutput = Get-UniqueOutputContract $outputs 'D:\A2\o\ocv\R18ZT1\RUNNING.json'
$completeOutput = Get-UniqueOutputContract $outputs 'D:\A2\o\ocv\R18ZT1\COMPLETE.json'
$failureOutput = Get-UniqueOutputContract $outputs 'D:\A2\o\ocv\R18ZT1\FAILURE.json'
$statusOutput = Get-UniqueOutputContract $outputs 'D:\A2\o\ocv\R18ZT1\STATUS.json'
Require ([string]$launchOutput.schema -eq 'argos_opencv_scribe_r18zt_batch_launch_v1' -and [string]$launchOutput.requiredState -eq 'PASS_R18ZT_BATCH_WORKER_STARTED' -and [string]$launchOutput.proves -eq 'ASYNC_WORKER_LAUNCH_ONLY' -and -not [bool]$launchOutput.completionClaimed) 'R18ZT LAUNCH producer contract changed.'
Require ([string]$runningOutput.schema -eq 'argos_opencv_scribe_r18zt_batch_progress_v1' -and [string]$runningOutput.requiredState -eq 'RUNNING_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY') 'R18ZT RUNNING producer contract changed.'
Require ([string]$completeOutput.schema -eq 'argos_opencv_scribe_r18zt_batch_complete_v1' -and [string]$completeOutput.requiredState -eq 'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY') 'R18ZT COMPLETE producer contract changed.'
Require ([string]$failureOutput.mode -eq 'CREATE_NEW_TERMINAL_FAILURE_BY_EXACT_OWNING_PRODUCER' -and [bool]$failureOutput.mutuallyExclusiveCreateNewLeaf) 'R18ZT FAILURE ownership contract changed.'
$failureVariants = @($failureOutput.variants)
Require ($failureVariants.Count -eq 2) 'R18ZT FAILURE variant count changed.'
$failureVariantKeys = @($failureVariants | ForEach-Object { ([string]$_.producer) + '|' + ([string]$_.schema) + '|' + ([string]$_.requiredState) })
Compare-ExactStringSet @(
    'LAUNCHER|argos_opencv_scribe_r18zt_batch_launch_failure_v1|HOLD_R18ZT_BATCH_LAUNCH_FAILURE',
    'WORKER_EXECUTION_ENVELOPE|argos_opencv_scribe_r18zt_batch_worker_failure_v1|HOLD_R18ZT_BATCH_WORKER_FAILURE'
) $failureVariantKeys 'R18ZT FAILURE producer variants'
Require ([string]$statusOutput.schema -eq 'argos_opencv_scribe_r18zt_batch_status_v1' -and [string]$statusOutput.mode -eq 'OPTIONAL_ADDITIONAL_WORKER_STATUS_NOT_A_TERMINAL_SUBSTITUTE') 'R18ZT optional STATUS contract changed.'
Compare-ExactStringSet @('LAUNCH.json','RUNNING.json','COMPLETE.json','FAILURE.json') @($definition.boundedFollowupContract.singleExactLeafProbe) 'R18ZT exact follow-up probe leaves'
Require (-not [bool]$definition.boundedFollowupContract.processOrTaskQueryAllowed -and -not [bool]$definition.boundedFollowupContract.resultTreeEnumerationAllowed -and -not [bool]$definition.boundedFollowupContract.klarfOrProposalTreeEnumerationAllowed -and -not [bool]$definition.boundedFollowupContract.statusJsonMaySubstituteForComplete) 'R18ZT bounded follow-up prohibition changed.'
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18zt_payload_manifest_v1' -and [string]$manifest.revision -eq $revision -and [string]$manifest.state -eq 'FROZEN_UNPUBLISHED' -and [bool]$manifest.finalizationComplete) 'R18ZT payload manifest changed.'
Assert-ReviewAuthority $manifest.authority 'R18ZT payload manifest'
Require ([string]$configuration.schema -eq 'argos_opencv_scribe_r18zt_batch_configuration_v1' -and [string]$configuration.batchId -eq 'R18ZT1' -and [string]$configuration.revision -eq 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906A' -and [string]$configuration.provider.sha256 -eq 'AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793') 'R18ZT frozen runner configuration changed.'
Require ([string]$design.state -eq 'FROZEN_UNPUBLISHED' -and [string]$design.requestId -eq $requestId -and -not [bool]$design.launchSemantics.launchResponseIsCompletion -and -not [bool]$design.launchSemantics.automaticRetryAllowed) 'R18ZT package design changed.'
Require ([IO.Path]::GetFullPath([string]$design.roots.workRoot).Equals($productionWorkRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFullPath([string]$design.roots.outputRoot).Equals($productionOutputRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFullPath([string]$design.roots.installedLauncher).Equals($productionInstalledLauncher, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT package design production roots changed.'

$payloadFiles = @($manifest.files)
Require ($payloadFiles.Count -ge 4 -and $payloadFiles.Count -le 96) 'R18ZT payload file count is outside the bound.'
$installSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($file in $payloadFiles) {
    $relative = [string]$file.installRelativePath
    Require ($installSet.Add($relative)) "R18ZT duplicate payload install path: $relative"
    Require ([string]$file.sha256 -cmatch '^[A-F0-9]{64}$' -and [int64]$file.bytes -gt 0) "R18ZT payload pin is incomplete: $relative"
    $source = Get-SafeProjectSource $project ([string]$file.sourcePath)
    Require-Pin $source ([string]$file.sha256)
    Require ((Get-Item -LiteralPath $source).Length -eq [int64]$file.bytes) "R18ZT payload source length changed: $($file.sourcePath)"
}

$expectedLeaves = New-Object Collections.Generic.List[string]
foreach ($leaf in @('PORTAL_REQUEST_MANIFEST.json', 'PORTAL_REQUEST_MANIFEST.sig', 'payload/Invoke-R18ZTBatchLaunch.ps1', 'payload/R18ZT_PAYLOAD_MANIFEST.json')) { $expectedLeaves.Add($leaf) }
foreach ($file in $payloadFiles) { $expectedLeaves.Add('payload/files/' + ([string]$file.installRelativePath).Replace('\', '/')) }
$expectedLeafArray = @($expectedLeaves.ToArray())
$expectedLeafSetSha = Get-TextSha256 ((@($expectedLeafArray | Sort-Object) -join "`n") + "`n")
Require ([int]$pathGate.plannedFinalZipMemberCount -eq $expectedLeafArray.Count -and [string]$pathGate.plannedFinalZipMemberSetSha256 -eq $expectedLeafSetSha) 'R18ZT path-gate package membership changed.'
Compare-ExactStringSet $expectedLeafArray @($pathGate.plannedFinalZipMembers) 'R18ZT path-gate planned package set'
Require ([int]$pathGate.unsafePathCount -eq 0 -and [int]$pathGate.maximumEffectiveLength -lt 200 -and [int]$pathGate.maximumComponentLength -le 80) 'R18ZT path gate is unsafe.'

$freshPaths = if ($Test) {
    @($testRoot, $testWorkRoot, $testOutputRoot)
} elseif ($Build) {
    @($stageRoot, $readyRoot, $stageZip, $verifyRoot, $finalRoot, $finalPartial, $finalGatePath)
} else {
    @($testRoot, $testWorkRoot, $testOutputRoot, $stageRoot, $readyRoot, $stageZip, $verifyRoot, $finalRoot, $finalPartial, $finalGatePath)
}
foreach ($path in $freshPaths) {
    Require (-not (Test-Path -LiteralPath $path)) "R18ZT fresh local output exists: $path"
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_build_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_BATCH_BUILD_PREFLIGHT'
        requestId = $requestId
        payloadFileCount = $payloadFiles.Count
        plannedZipMemberCount = $expectedLeafArray.Count
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

$activeRoot = if ($Test) { $testRoot } else { $stageRoot }
$activeReady = if ($Test) { Join-Path $testRoot ($requestId + '.unsigned-test') } else { $readyRoot }
[void](New-Item -ItemType Directory -Path (Join-Path $activeReady 'payload\files') -Force)
$activePayload = Join-Path $activeReady 'payload'
Copy-Item -LiteralPath $launcherPath -Destination (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1')
Copy-Item -LiteralPath $payloadManifestPath -Destination (Join-Path $activePayload 'R18ZT_PAYLOAD_MANIFEST.json')
$manifestFiles = New-Object Collections.Generic.List[object]
foreach ($fixed in @(
    [pscustomobject]@{path='payload/Invoke-R18ZTBatchLaunch.ps1';source=$launcherPath},
    [pscustomobject]@{path='payload/R18ZT_PAYLOAD_MANIFEST.json';source=$payloadManifestPath}
)) {
    $manifestFiles.Add([ordered]@{path=[string]$fixed.path;bytes=[int64](Get-Item -LiteralPath $fixed.source).Length;sha256=Get-Sha256 $fixed.source})
}
foreach ($file in $payloadFiles) {
    $source = Get-SafeProjectSource $project ([string]$file.sourcePath)
    $relative = 'payload/files/' + ([string]$file.installRelativePath).Replace('\', '/')
    $destination = Get-SafeChild $activeReady $relative
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath $source -Destination $destination
    Require-Pin $destination ([string]$file.sha256)
    $manifestFiles.Add([ordered]@{path=$relative;bytes=[int64](Get-Item -LiteralPath $destination).Length;sha256=[string]$file.sha256})
}

$stagedPreflight = (& (Join-Path $activePayload 'Invoke-R18ZTBatchLaunch.ps1') -Preflight -Rehearsal -PackageValidationOnly -PayloadRoot $activePayload -WorkRoot $testWorkRoot -OutputRoot $testOutputRoot -ProposalRoot 'C:\R18ZT_PROPOSALS_NOT_ACCESSED' -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localReferenceBundle -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$stagedPreflight.state -eq 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' -and -not [bool]$stagedPreflight.targetWritesPerformed -and -not [bool]$stagedPreflight.processStarted -and -not [bool]$stagedPreflight.completionClaimed) 'R18ZT staged static entrypoint preflight failed.'

if ($Test) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_unsigned_test_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_BATCH_UNSIGNED_PACKAGE_TEST'
        requestId = $requestId
        stagedPayloadFileCount = $manifestFiles.Count
        staticEntrypointPreflight = $stagedPreflight
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
$extractedSignatureRows = @(& $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH)
Require ($extractedSignatureRows.Count -eq 1 -and [string]$extractedSignatureRows[0].State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and [string]$extractedSignatureRows[0].RequestId -eq $requestId) 'R18ZT extracted signed-package verification failed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
Copy-Item -LiteralPath $stageZip -Destination (Join-Path $finalPartial $zipName)
foreach ($gate in @($cloneGatePath, $pathGatePath, $powerShellGatePath, $scienceGatePath, $recoveryGatePath, $preactionPath)) {
    Copy-Item -LiteralPath $gate -Destination (Join-Path $finalPartial ([IO.Path]::GetFileName($gate)))
}
$completeRouteGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18zt_complete_route_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18ZT_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED'
    requestId = $requestId
    requestZipSha256 = Get-Sha256 $stageZip
    requestZipBytes = [int64](Get-Item -LiteralPath $stageZip).Length
    requestManifestSha256 = Get-Sha256 $requestManifestPath
    actualFinalZipMemberCount = $actualLeaves.Count
    actualFinalZipMemberSetSha256 = $actualLeafSetSha
    actualFinalZipMembers = @($actualLeaves | Sort-Object)
    pathPlanGateSha256 = $pathGateSha
    maximumEffectiveLength = [int]$pathGate.maximumEffectiveLength
    maximumComponentLength = [int]$pathGate.maximumComponentLength
    unsafePathCount = [int]$pathGate.unsafePathCount
    publicationMustRecheckAllCollisionScopes = $true
    publicationAuthorized = $false
    explicitPublishStillRequired = $true
    conditionalPublicationAuthorityText = 'Do the work, if it is successful - as in deciphering correctly. PUBLISH the package to JBOD.'
    conditionalPublicationAuthorityRequiresExactSlot21Pass = $true
    freshRequestIdSpecificLiteralRequired = $false
    retryAuthorized = $false
    targetExecuted = $false
    completionClaimed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$completeRouteGatePath = Join-Path $finalPartial ($zipName + '.complete_route_gate.json')
Write-JsonNew $completeRouteGatePath $completeRouteGate
Move-Item -LiteralPath $finalPartial -Destination $finalRoot

$finalZipPath = Join-Path $finalRoot $zipName
$finalGate = [ordered]@{
    schema = 'argos_opencv_scribe_r18zt_final_package_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18ZT_SIGNED_UNPUBLISHED_PACKAGE_GATE'
    requestId = $requestId
    revision = $revision
    requestZip = 'work/OPENCV_SCRIBE_R18ZT_BATCH_PACKAGE/final/REQ_R18ZT1.ready.zip'
    requestZipBytes = [int64](Get-Item -LiteralPath $finalZipPath).Length
    requestZipSha256 = Get-Sha256 $finalZipPath
    requestManifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
    requestSignatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
    expiresUtc = [string]$requestManifest.expiresUtc
    builderSha256 = Get-Sha256 ([IO.Path]::GetFullPath($MyInvocation.MyCommand.Path))
    launcherSha256 = $launcherSha
    payloadManifestSha256 = $payloadManifestSha
    maintenanceDefinitionSha256 = $definitionSha
    packageDesignSha256 = $designSha
    cloneGateSha256 = $cloneGateSha
    pathPlanGateSha256 = $pathGateSha
    powerShellSafetyGateSha256 = $powerShellGateSha
    scienceGateSha256 = $scienceGateSha
    recoveryIntentGateSha256 = $recoveryGateSha
    preactionSha256 = $preactionSha
    payloadManifestFileCount = $payloadFiles.Count
    signedPayloadFileCount = $manifestFiles.Count
    finalZipMemberCount = $actualLeaves.Count
    finalZipMemberSetSha256 = $actualLeafSetSha
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    stagedStaticEntrypointPreflightPassed = $true
    asynchronousLaunchOnly = $true
    completionClaimed = $false
    targetExecuted = $false
    backgroundProcessStarted = $false
    publicationAuthorized = $false
    publicationPerformed = $false
    explicitPublishStillRequired = $true
    conditionalPublicationAuthorityText = 'Do the work, if it is successful - as in deciphering correctly. PUBLISH the package to JBOD.'
    conditionalPublicationAuthorityRequiresExactSlot21Pass = $true
    freshRequestIdSpecificLiteralRequired = $false
    maximumPublicationsAfterFreshAuthority = 1
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
