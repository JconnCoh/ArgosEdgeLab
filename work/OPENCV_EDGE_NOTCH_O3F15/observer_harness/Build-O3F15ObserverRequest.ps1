#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('P1','F1','T1')][string]$Flow,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$expectedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$expectedConfigSha256 = '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'
$expectedQueueSafetySha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$expectedContractSha256 = '7FE49D22B0D79DB9D1398718447826C5B760379AF0988803E7E09F6A3E0F149B'
$expectedRouteAnchorSha256 = 'F8AB82BB364AD6DBADF2C40AE0BFE7F18B646013D89F9A8663924E0770D06247'
$expectedPackageBuilderSha256 = '8AF7AF26B6899CB6475735FEE8AB6E5A29231AAED8EDA898F1E7F4B04A2A403F'
$expectedPackageTesterSha256 = '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'
$expectedIdentitySha256 = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$expectedPublicCertificateSha256 = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$branchName = 'codex/fiducial-opencv-d-drive'
$localObserverRoot = 'C:\F15O'

function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}
function Require-Pin([string]$Path,[string]$ExpectedSha256,[string]$Label) {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    Require ((Sha256 $Path) -eq $ExpectedSha256) "$Label changed: $Path"
}
function Required([object]$Object,[string]$Name) {
    Require ($null -ne $Object) "Required object is null while reading $Name."
    Require ($Object.PSObject.Properties.Name -contains $Name) "Required property is absent: $Name"
    return $Object.$Name
}
function Write-NewJson([string]$Path,[object]$Value,[int]$Depth=24) {
    Require (-not (Test-Path -LiteralPath $Path)) "Create-new JSON target exists: $Path"
    $encoding = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($Path,(($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine),$encoding)
}
function Get-Eligibility([string]$FlowId,[string]$ObserverDir) {
    $eligible = $false
    $state = 'HOLD_ELIGIBILITY_EVIDENCE_PENDING'
    $evidencePath = $null
    $evidenceSha256 = $null
    $evidenceState = $null
    $launchGatePath = $null
    $launchGateSha256 = $null
    $launchGateState = $null
    $launchRequestId = $null
    $detail = $null
    if ($FlowId -eq 'P1') {
        $evidencePath = Join-Path $ObserverDir 'O3F15_P1_LAUNCH_BINDING_GATE.json'
        if (Test-Path -LiteralPath $evidencePath -PathType Leaf) {
            $binding = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
            $evidenceSha256 = Sha256 $evidencePath
            $evidenceState = [string](Required $binding 'state')
            Require ($evidenceState -eq 'PASS_O3F15_P1_FUTURE_SIGNED_LAUNCH_BOUND') 'P1 future launch-binding state changed.'
            $launchRevision = [string](Required $binding 'launchRevision')
            Require ($launchRevision -match '^O3F15L([2-9]|[1-9][0-9]+)$') 'P1 refuses the withdrawn first launch revision.'
            $launchGatePath = [IO.Path]::GetFullPath([string](Required $binding 'signedLaunchGatePath'))
            Require (Test-Path -LiteralPath $launchGatePath -PathType Leaf) 'P1 bound signed launch gate is absent.'
            $launchGateSha256 = Sha256 $launchGatePath
            Require ($launchGateSha256 -eq [string](Required $binding 'signedLaunchGateSha256')) 'P1 bound signed launch gate changed.'
            $value = Get-Content -LiteralPath $launchGatePath -Raw | ConvertFrom-Json
            $launchGateState = [string](Required $value 'state')
            Require ($launchGateState -eq [string](Required $binding 'signedLaunchGateState')) 'P1 bound signed launch state changed.'
            Require ($launchGateState -match '^PASS_O3F15L([2-9]|[1-9][0-9]+)_SIGNED_EXACT_978_FRONT_CORPUS_LAUNCHED$') 'P1 bound launch is not a non-withdrawn signed 978-front launch pass.'
            $launchRequestId = [string](Required $value 'requestId')
            Require ($launchRequestId -eq [string](Required $binding 'requestId')) 'P1 bound launch request identity changed.'
            Require ([bool](Required $value 'signedResponseVerified')) 'P1 bound launch evidence is not signature verified.'
            Require ([string](Required $value 'mirrorRoot') -eq 'D:/KLARFExport/_ArgosReview/F15S') 'P1 launch mirror root changed.'
            Require ([int](Required $value 'expectedPairCount') -eq 978 -and [string](Required $value 'side') -eq 'FRONT') 'P1 launch corpus identity changed.'
            Require ([bool](Required $value 'reviewOnly') -and -not [bool](Required $value 'productionRoutingEnabled')) 'P1 launch authority widened.'
            Require (-not [bool](Required $value 'sourceMutationPerformed') -and -not [bool](Required $value 'sourceDeletionPerformed')) 'P1 launch crossed a source boundary.'
            Require (-not [bool](Required $value 'existingProcessOrTaskActionPerformed') -and -not [bool](Required $value 'providerActivationPerformed')) 'P1 launch crossed a protected runtime boundary.'
            Require (-not [bool](Required $value 'holdsAutomaticallyCleared') -and -not [bool](Required $value 'automaticRetryAuthorized')) 'P1 launch changed hold or retry authority.'
            $eligible = $true
            $state = 'PASS_O3F15_P1_BUILD_ELIGIBLE_AFTER_FUTURE_SIGNED_LAUNCH_BINDING'
        }
    }
    elseif ($FlowId -eq 'F1') {
        $evidencePath = Join-Path $ObserverDir 'O3F15_P1_SIGNED_RESPONSE_GATE.json'
        if (Test-Path -LiteralPath $evidencePath -PathType Leaf) {
            $value = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
            $evidenceSha256 = Sha256 $evidencePath
            $evidenceState = [string](Required $value 'state')
            Require ($evidenceState -eq 'PASS_O3F15_P1_SIGNED_DATA_PULL_COLLECTED') 'F1 eligibility evidence is not the matching signed P1 collection.'
            $progressState = [string](Required $value 'progressState')
            Require ($progressState -in @('COMPLETE_O3F15_FULL978','HOLD_O3F15_EXECUTION_STOPPED')) 'F1 requires terminal COMPLETE/HOLD execution progress.'
            Require ([bool](Required $value 'signatureVerified') -and [bool](Required $value 'fullPullEligible')) 'F1 signed P1 evidence is not eligible for the terminal pull.'
            Require (-not [bool](Required $value 'requestRetryAuthorized')) 'F1 P1 evidence changed retry authority.'
            $eligible = $true
            $state = 'PASS_O3F15_F1_BUILD_ELIGIBLE_AFTER_TERMINAL_P1'
        }
    }
    else {
        $evidencePath = Join-Path $ObserverDir 'O3F15_T1_ELIGIBILITY_GATE.json'
        if (Test-Path -LiteralPath $evidencePath -PathType Leaf) {
            $value = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
            $evidenceSha256 = Sha256 $evidencePath
            $evidenceState = [string](Required $value 'state')
            Require ($evidenceState -eq 'PASS_O3F15_T1_ARTIFACT_FAILURE_PULL_ELIGIBLE') 'T1 eligibility gate state changed.'
            Require ([string](Required $value 'failureClass') -eq 'O3F15_ARTIFACT_FAILURE') 'T1 is restricted to explicit artifact failure evidence.'
            Require ([bool](Required $value 'signedEvidenceVerified') -and -not [bool](Required $value 'automaticEligibility')) 'T1 eligibility evidence is not explicit and signed.'
            Require (-not [bool](Required $value 'requestRetryAuthorized')) 'T1 eligibility changed retry authority.'
            $eligible = $true
            $state = 'PASS_O3F15_T1_BUILD_ELIGIBLE_AFTER_EXPLICIT_ARTIFACT_FAILURE'
        }
        else {
            $detail = 'T1 remains disabled until a separate exact gate binds signed launch or signed P1 artifact-failure evidence.'
        }
    }
    return [pscustomobject]@{
        eligible=$eligible; state=$state; evidencePath=$evidencePath; evidenceSha256=$evidenceSha256
        evidenceState=$evidenceState; launchGatePath=$launchGatePath; launchGateSha256=$launchGateSha256
        launchGateState=$launchGateState; launchRequestId=$launchRequestId; detail=$detail
    }
}
function Get-RoutePaths([string]$RequestId,[string]$FlowId,[string[]]$RelativePaths) {
    $responseId = 'R_0123456789AB_20260903235959999_a1b2c3d4'
    $responseReady = $responseId + '.ready'
    $flowRoot = Join-Path $localObserverRoot $FlowId
    $collectionRoot = Join-Path $localObserverRoot ($FlowId + 'C')
    $rows = New-Object Collections.Generic.List[string]
    $rows.Add((Join-Path $flowRoot ('dp\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json')))
    $rows.Add((Join-Path $flowRoot ('dp\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.sig')))
    $rows.Add((Join-Path $flowRoot ('dpf\' + $RequestId + '.ready.zip')))
    $rows.Add((Join-Path $flowRoot ('dpf\' + $RequestId + '.ready.zip.path_gate.json')))
    $rows.Add(('U:\ProjectPortalRO\requests\' + $RequestId + '.ready.zip.upload'))
    $rows.Add(('U:\ProjectPortalRO\requests\' + $RequestId + '.ready.zip'))
    $rows.Add(('C:\APR\S\requests\processed\' + $RequestId + '.ready.zip'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\share\staging\' + $RequestId + '.ready.zip'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\share\request_archive\' + $RequestId + '.ready.zip'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\to_jbod\sent\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $RequestId + '.ready\PORTAL_REQUEST_MANIFEST.json'))
    $rows.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial')
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\' + $RequestId + '.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\response_quarantine\' + $responseId + '.partial\PORTAL_RESPONSE_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\DATA_PULL_PAYLOAD.zip'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\to_gateway\sent\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
    $rows.Add(('C:\APR\R\pending\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'))
    $rows.Add(('C:\APR\A\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
    $rows.Add(('C:\ProgramData\ArgosProjectPortalRO\share\response_zip_archive\' + $responseReady + '.zip'))
    $rows.Add(('U:\ProjectPortalRO\responses\' + $responseReady + '.zip'))
    $rows.Add((Join-Path $collectionRoot 'R.zip'))
    $rows.Add((Join-Path $collectionRoot ('R\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json')))
    foreach ($relativePath in $RelativePaths) {
        $windowsRelative = $relativePath.Replace('/','\')
        $rows.Add(('D:\KLARFExport\' + $windowsRelative))
        $rows.Add((Join-Path $collectionRoot ('D\data\JBOD_KLARF_EXPORT\' + $windowsRelative)))
    }
    return @($rows)
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$contractPath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_CONTRACT.json'
$routeAnchorPath = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3K1\O3K1_DATA_PULL_COMPLETE_ROUTE_GATE.json'
$packageBuilder = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\New-SignedPortalPackage.ps1'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'

Require-Pin $contractPath $expectedContractSha256 'O3F15 observer contract'
Require-Pin $routeAnchorPath $expectedRouteAnchorSha256 'O3F15 qualified route anchor'
Require-Pin $packageBuilder $expectedPackageBuilderSha256 'O3F15 package builder'
Require-Pin $packageTester $expectedPackageTesterSha256 'O3F15 package tester'
Require-Pin $identityPath $expectedIdentitySha256 'O3F15 signing identity'
Require-Pin $publicCertificatePath $expectedPublicCertificateSha256 'O3F15 laptop signer certificate'
Require (Test-Path -LiteralPath $pathTool -PathType Leaf) 'O3F15 path-budget tool is absent.'
Require (Test-Path -LiteralPath $historyPath -PathType Leaf) 'O3F15 history audit is absent.'
Require (Test-Path -LiteralPath $preactionTool -PathType Leaf) 'O3F15 zero-recurrence pre-action tool is absent.'

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
Require ([string](Required $contract 'state') -eq 'FROZEN_OBSERVER_HARNESSES_READY_NO_REQUEST_CREATED') 'O3F15 observer contract lifecycle changed.'
Require ([string](Required $contract 'classification') -eq 'OBSERVE' -and [string](Required $contract 'transport') -eq 'SIGNED_PROJECT_PORTAL_DATA_PULL_ONLY') 'O3F15 observer route/classification changed.'
Require ([string](Required $contract 'approvedRoot') -eq 'JBOD_KLARF_EXPORT' -and [string](Required $contract 'mirrorRoot') -eq 'D:/KLARFExport/_ArgosReview/F15S') 'O3F15 observer source root changed.'
$routePins = Required $contract 'routePins'
Require ([string](Required $routePins 'endpointWorkerSha256') -eq $expectedWorkerSha256) 'O3F15 endpoint worker pin changed.'
Require ([string](Required $routePins 'installedConfigEvidenceSha256') -eq $expectedConfigSha256) 'O3F15 endpoint config-evidence pin changed.'
Require ([string](Required $routePins 'inheritedQueueSafetyGateSha256') -eq $expectedQueueSafetySha256) 'O3F15 queue-safety pin changed.'
$routeAnchor = Get-Content -LiteralPath $routeAnchorPath -Raw | ConvertFrom-Json
Require ([string](Required $routeAnchor 'state') -eq 'PASS_O3K1_DATA_PULL_COMPLETE_ROUTE_GATE') 'O3F15 route anchor is not a qualified DATA_PULL route.'
Require ([string](Required $routeAnchor 'endpointWorkerSha256') -eq $expectedWorkerSha256) 'O3F15 route anchor worker changed.'
Require ([string](Required $routeAnchor 'installedEndpointConfigSha256') -eq $expectedConfigSha256) 'O3F15 route anchor config evidence changed.'
Require ([string](Required $routeAnchor 'inheritedQueueSafetyGateSha256') -eq $expectedQueueSafetySha256) 'O3F15 route anchor queue-safety evidence changed.'
Require (-not [bool](Required $routeAnchor 'retryOnFailure') -and [bool](Required $routeAnchor 'matchingSignedTerminalResponseCollectionOnly')) 'O3F15 route retry/collection semantics changed.'
Require (-not [bool](Required $routeAnchor 'gatewayAcceptanceIsExecutionEvidence')) 'O3F15 route execution-evidence semantics changed.'

$definitionName = 'O3F15_' + $Flow + '_DATA_PULL_DEFINITION.json'
$definitionPath = Join-Path $PSScriptRoot $definitionName
$expectedDefinitionSha256 = $null
$expectedRelativePaths = @()
$expectedMaximumFiles = 0
$expectedMaximumBytes = [int64]0
$expectedMaxResultBytes = [int64]0
if ($Flow -eq 'P1') {
    $expectedDefinitionSha256 = '5F9DB8A1B877BF2082BF091F8F33D81143ED1E89511C2029FE17CCBDD5EDDEBD'
    $expectedRelativePaths = @('_ArgosReview/F15S/PROGRESS.json')
    $expectedMaximumFiles = 1; $expectedMaximumBytes = 262144; $expectedMaxResultBytes = 1048576
}
elseif ($Flow -eq 'F1') {
    $expectedDefinitionSha256 = '87E5A165A3E5E6526011D06A50F4A15F0D16CE458D94FFF74F76EDFCE9ACCD59'
    $expectedRelativePaths = @('_ArgosReview/F15S/PROGRESS.json','_ArgosReview/F15S/SUMMARY.json','_ArgosReview/F15S/RESULTS.json')
    $expectedMaximumFiles = 3; $expectedMaximumBytes = 4194304; $expectedMaxResultBytes = 8388608
}
else {
    $expectedDefinitionSha256 = 'DE67AB7C3BD8B9B20865EAE7CF84F1C0B7E150307C0DAC7DD09AE9495194A6E2'
    $expectedRelativePaths = @('_ArgosReview/F15S/TERMINAL_FAILURE.json')
    $expectedMaximumFiles = 1; $expectedMaximumBytes = 262144; $expectedMaxResultBytes = 1048576
}
Require-Pin $definitionPath $expectedDefinitionSha256 "O3F15 $Flow DATA_PULL definition"
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Require ([string](Required $definition 'schema') -eq 'argos_project_portal_request_definition_v1') 'O3F15 observer definition schema changed.'
Require ([string](Required $definition 'targetRole') -eq 'JBOD' -and [string](Required $definition 'jobClass') -eq 'DATA_PULL') 'O3F15 observer target or job class changed.'
Require ([int64](Required $definition 'maxResultBytes') -eq $expectedMaxResultBytes) 'O3F15 observer maxResultBytes changed.'
$parameters = Required $definition 'parameters'
Require ([string](Required $parameters 'approvedRoot') -eq 'JBOD_KLARF_EXPORT') 'O3F15 observer approved root changed.'
$relativePaths = @((Required $parameters 'relativePaths') | ForEach-Object { [string]$_ })
Require ($relativePaths.Count -eq $expectedRelativePaths.Count -and @(Compare-Object -ReferenceObject $expectedRelativePaths -DifferenceObject $relativePaths -SyncWindow 0).Count -eq 0) 'O3F15 observer exact relative path order changed.'
Require ([int](Required $parameters 'maximumFiles') -eq $expectedMaximumFiles -and [int64](Required $parameters 'maximumBytes') -eq $expectedMaximumBytes) 'O3F15 observer bounds changed.'
foreach ($relativePath in $relativePaths) {
    Require (-not [IO.Path]::IsPathRooted($relativePath) -and $relativePath -notmatch '(^|/|\\)\.\.($|/|\\)' -and $relativePath -notmatch '[*?]') 'O3F15 observer relative path is unsafe.'
    Require ($relativePath.StartsWith('_ArgosReview/F15S/',[StringComparison]::Ordinal)) 'O3F15 observer path escaped the exact mirror subtree.'
}

$eligibility = Get-Eligibility -FlowId $Flow -ObserverDir $PSScriptRoot
$preactionPath = Join-Path $PSScriptRoot ('PREACTION_O3F15_' + $Flow + '_BUILD_SIGN.json')
$preactionPresent = Test-Path -LiteralPath $preactionPath -PathType Leaf
$preactionSha256 = $null
$preactionState = 'HOLD_PREACTION_CONTRACT_PENDING'
if ($preactionPresent) {
    & $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-Null
    $preactionSha256 = Sha256 $preactionPath
    $preactionState = 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION'
}
$placeholderRequestId = 'REQ_20260903T235900111Z_F15' + $Flow + '0123456'
$plannedPaths = @(Get-RoutePaths -RequestId $placeholderRequestId -FlowId $Flow -RelativePaths $relativePaths)
$plannedPathGate = & $pathTool -CandidatePath $plannedPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string](Required $plannedPathGate 'state') -eq 'PASS_PATH_BUDGET') 'O3F15 observer planned round-trip path budget failed.'
$maximumEffectiveLength = [int](($plannedPathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponentLength = [int](($plannedPathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('origin/' + $branchName) | Out-String).Trim()
Require ($currentBranch -eq $branchName -and $localTip -eq $remoteTip) 'O3F15 observer build requires matching local/origin branch tips.'

$flowRoot = Join-Path $localObserverRoot $Flow
$flowPartial = $flowRoot + '.partial'
foreach ($path in @($flowRoot,$flowPartial)) {
    Require (-not (Test-Path -LiteralPath $path)) "O3F15 $Flow create-new build target exists: $path"
}

if ($Preflight) {
    $preflightState = [string]$eligibility.state
    if ([bool]$eligibility.eligible -and $preactionPresent) { $preflightState = 'PASS_O3F15_' + $Flow + '_OBSERVER_BUILD_PREFLIGHT' }
    elseif ([bool]$eligibility.eligible) { $preflightState = $preactionState }
    [ordered]@{
        schema='argos_ocv03_o3f15_observer_build_preflight_v1'; checkedUtc=[DateTime]::UtcNow.ToString('o')
        state=$preflightState
        flow=$Flow; eligible=[bool]$eligibility.eligible; eligibilityEvidencePath=$eligibility.evidencePath
        eligibilityEvidenceSha256=$eligibility.evidenceSha256; eligibilityEvidenceState=$eligibility.evidenceState
        launchGatePath=$eligibility.launchGatePath; launchGateSha256=$eligibility.launchGateSha256
        launchGateState=$eligibility.launchGateState; launchRequestId=$eligibility.launchRequestId
        preactionContractPath=$preactionPath; preactionContractPresent=$preactionPresent
        preactionContractSha256=$preactionSha256; preactionState=$preactionState
        definitionSha256=$expectedDefinitionSha256; relativePaths=$relativePaths; maximumFiles=$expectedMaximumFiles
        maximumBytes=$expectedMaximumBytes; maxResultBytes=$expectedMaxResultBytes; routePathCount=$plannedPaths.Count
        maximumEffectiveLength=$maximumEffectiveLength; maximumComponentLength=$maximumComponentLength
        endpointWorkerSha256=$expectedWorkerSha256; installedConfigEvidenceSha256=$expectedConfigSha256
        inheritedQueueSafetyGateSha256=$expectedQueueSafetySha256; branch=$currentBranch; localTip=$localTip; remoteTip=$remoteTip
        mutationsPerformed=$false; signedPackageCreated=$false; requestPublished=$false; jbodContacted=$false
        requestRetryAuthorized=$false; reviewOnly=$true; productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 10
    return
}

Require ([bool]$eligibility.eligible) "O3F15 $Flow observer is not eligible: $($eligibility.state)"
Require ($preactionPresent) "O3F15 $Flow build/sign pre-action contract is absent: $preactionPath"
[void][IO.Directory]::CreateDirectory($localObserverRoot)
[void][IO.Directory]::CreateDirectory($flowPartial)
$signedRoot = Join-Path $flowPartial 'dp'
$finalRoot = Join-Path $flowPartial 'dpf'
[void][IO.Directory]::CreateDirectory($finalRoot)
$built = & $packageBuilder -DefinitionPath $definitionPath -OutputRoot $signedRoot -IdentityStatePath $identityPath
Require ([string](Required $built 'State') -eq 'SIGNED_PORTAL_PACKAGE_READY') 'O3F15 observer signed package builder failed.'
$requestId = [string](Required $built 'RequestId')
$readyRoot = [IO.Path]::GetFullPath([string](Required $built 'PackagePath'))
Require ($requestId -match '^REQ_[0-9]{8}T[0-9]{9}Z_[A-F0-9]{12}$') 'O3F15 observer generated request ID is invalid.'
$folderTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Require ([string](Required $folderTest 'State') -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F15 observer signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPartial = Join-Path $finalRoot ($requestId + '.ready.zip')
$extractRoot = Join-Path $finalRoot 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot,$zipPartial,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial,$extractRoot)
$extractTest = & $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Require ([string](Required $extractTest 'State') -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F15 observer exact ZIP signature validation failed.'
Require (@(Get-ChildItem -LiteralPath $extractRoot -File).Count -eq 2) 'O3F15 observer exact ZIP entry cardinality changed.'
$zipSha256 = Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig')
$actualPaths = @(Get-RoutePaths -RequestId $requestId -FlowId $Flow -RelativePaths $relativePaths)
$actualPathGate = & $pathTool -CandidatePath $actualPaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string](Required $actualPathGate 'state') -eq 'PASS_PATH_BUDGET') 'O3F15 observer exact round-trip path budget failed.'
$routeRows = @($actualPathGate.candidates | ForEach-Object {
    [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'}
})
$finalZipPath = Join-Path $flowRoot ('dpf\' + $requestId + '.ready.zip')
$pathGatePath = Join-Path $finalRoot ($requestId + '.ready.zip.path_gate.json')
$packageGatePath = Join-Path $finalRoot ('O3F15_' + $Flow + '_FINAL_PACKAGE_GATE.json')
$routeGatePath = Join-Path $finalRoot ('O3F15_' + $Flow + '_COMPLETE_ROUTE_GATE.json')
$routeGate = [ordered]@{
    schema='argos_ocv03_o3f15_observer_complete_route_gate_v1'; createdUtc=[DateTime]::UtcNow.ToString('o')
    state=('PASS_O3F15_' + $Flow + '_OBSERVER_COMPLETE_ROUTE_GATE'); flow=$Flow; requestId=$requestId; jobClass='DATA_PULL'
    requestZipPath=$finalZipPath; requestZipBytes=$zipBytes; requestZipSha256=$zipSha256
    requestManifestSha256=$manifestSha256; requestSignatureSha256=$signatureSha256
    definitionPath=('work/OPENCV_EDGE_NOTCH_O3F15/observer_harness/' + $definitionName); definitionSha256=$expectedDefinitionSha256
    eligibilityEvidencePath=$eligibility.evidencePath; eligibilityEvidenceSha256=$eligibility.evidenceSha256; eligibilityEvidenceState=$eligibility.evidenceState
    launchGatePath=$eligibility.launchGatePath; launchGateSha256=$eligibility.launchGateSha256
    launchGateState=$eligibility.launchGateState; launchRequestId=$eligibility.launchRequestId
    preactionContractPath=$preactionPath; preactionContractSha256=$preactionSha256
    endpointWorkerSha256=$expectedWorkerSha256; installedConfigEvidenceSha256=$expectedConfigSha256
    inheritedQueueSafetyGateSha256=$expectedQueueSafetySha256; approvedRoot='JBOD_KLARF_EXPORT'; relativePaths=$relativePaths
    maximumFiles=$expectedMaximumFiles; maximumBytes=$expectedMaximumBytes; maxResultBytes=$expectedMaxResultBytes
    routePathCount=$routeRows.Count; routeRows=$routeRows
    maximumEffectiveLength=[int](($actualPathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
    maximumComponentLength=[int](($actualPathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
    reservedSuffixCharacters=32; exactFinalZipExtractionPassed=$true; exactFinalZipSignaturePassed=$true
    publicationAuthorized=$false; maximumRequestsAuthorized=1; retryOnFailure=$false; matchingSignedTerminalResponseRequired=$true
    gatewayAcceptanceIsExecutionEvidence=$false; sourceImageBytesRequested=$false; detectorRerunPerformed=$false
    sourceMutationPerformed=$false; sourceDeletionPerformed=$false; existingTaskOrProcessActionPerformed=$false
    providerActivated=$false; automaticHoldClearancePerformed=$false; reviewOnly=$true; trainingEligible=$false
    xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false
}
$packageGate = [ordered]@{
    schema='argos_ocv03_o3f15_observer_final_package_gate_v1'; createdUtc=[DateTime]::UtcNow.ToString('o')
    state=('PASS_O3F15_' + $Flow + '_OBSERVER_FINAL_PACKAGE_GATE'); flow=$Flow; requestId=$requestId
    requestZipPath=$finalZipPath; requestZipBytes=$zipBytes; requestZipSha256=$zipSha256
    requestManifestSha256=$manifestSha256; requestSignatureSha256=$signatureSha256
    definitionSha256=$expectedDefinitionSha256; contractSha256=$expectedContractSha256; routeAnchorSha256=$expectedRouteAnchorSha256
    eligibilityEvidencePath=$eligibility.evidencePath; eligibilityEvidenceSha256=$eligibility.evidenceSha256
    launchGatePath=$eligibility.launchGatePath; launchGateSha256=$eligibility.launchGateSha256
    preactionContractPath=$preactionPath; preactionContractSha256=$preactionSha256
    exactFinalZipExtractionPassed=$true; exactFinalZipSignaturePassed=$true; publicationAuthorized=$false
    requestRetryAuthorized=$false; reviewOnly=$true; productionRoutingEnabled=$false
}
Write-NewJson -Path $pathGatePath -Value $routeGate -Depth 32
Write-NewJson -Path $routeGatePath -Value $routeGate -Depth 32
Write-NewJson -Path $packageGatePath -Value $packageGate -Depth 16
[IO.Directory]::Delete($extractRoot,$true)
[IO.Directory]::Move($flowPartial,$flowRoot)
$packageGate.requestZipPath = $finalZipPath
$packageGate | ConvertTo-Json -Depth 16
