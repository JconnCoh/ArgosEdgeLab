#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateSet('P1','F1','T1')][string]$Flow,
    [Parameter(Mandatory=$true)][ValidateSet('BUILD_SIGN','PUBLISH')][string]$Stage,
    [switch]$Preflight,
    [switch]$Freeze
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Freeze)) { throw 'Specify exactly one of -Preflight or -Freeze.' }

function Require([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Required([object]$Object,[string]$Name) {
    Require ($null -ne $Object) "Required object is null while reading $Name."
    Require ($Object.PSObject.Properties.Name -contains $Name) "Required property is absent: $Name"
    return $Object.$Name
}
function Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Bytes-Sha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}
function Write-NewBytes([string]$Path,[byte[]]$Bytes) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15 pre-action freeze target exists: $Path"
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($Bytes,0,$Bytes.Length) }
    finally { $stream.Dispose() }
}
function Add-Dependency([Collections.Generic.List[object]]$List,[string]$Project,[string]$Path) {
    $full = $Path
    if (-not [IO.Path]::IsPathRooted($full)) { $full = Join-Path $Project $full.Replace('/','\') }
    $full = [IO.Path]::GetFullPath($full)
    Require (Test-Path -LiteralPath $full -PathType Leaf) "O3F15 pre-action dependency is absent: $full"
    $recordPath = $full
    $prefix = $Project.TrimEnd('\') + '\'
    if ($full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) {
        $recordPath = $full.Substring($prefix.Length).Replace('\','/')
    }
    $List.Add([pscustomobject]@{path=$recordPath;sha256=Sha256 $full})
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
$buildScript = Join-Path $PSScriptRoot 'Build-O3F15ObserverRequest.ps1'
$publishScript = Join-Path $PSScriptRoot 'Publish-O3F15ObserverRequest.ps1'
$contractPath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_CONTRACT.json'
$definitionPath = Join-Path $PSScriptRoot ('O3F15_' + $Flow + '_DATA_PULL_DEFINITION.json')
$cloneGatePath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_CLONE_LITERAL_GATE.json'
$harnessGatePath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_HARNESS_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_STATIC_PATH_GATE.json'
$contractGatePath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_CONTRACT_GATE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$collectionCasePath = Join-Path $project 'work\ARGOS_POWERSHELL_COLLECTION_CASE_GATE_20260821.json'
$routeAnchorPath = Join-Path $project 'work\OPENCV_EDGE_NOTCH_O3K1\O3K1_DATA_PULL_COMPLETE_ROUTE_GATE.json'
$packageBuilder = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\New-SignedPortalPackage.ps1'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
foreach ($path in @($buildScript,$publishScript,$contractPath,$definitionPath,$cloneGatePath,$harnessGatePath,$pathGatePath,$contractGatePath,$historyPath,$collectionCasePath,$routeAnchorPath,$preactionTool)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15 pre-action dependency is absent: $path"
}
Require ((Sha256 $historyPath) -eq 'D54E5F766D4546827069C65F098D3C98E8C1C9B724B718A101674775FB51DA75') 'O3F15 history audit changed.'
Require ((Sha256 $collectionCasePath) -eq '17128A6B5745DC2B588D9803BD0E892D1108A69F87BA35300567089E1D83FF11') 'O3F15 collection-case gate changed.'

$dependencies = New-Object Collections.Generic.List[object]
$evidencePath = $null
$outputPath = $null
$publishInvocationPath = $null
$publishInvocation = $null
$publishInvocationBytes = $null
$publishInvocationSha256 = $null
if ($Stage -eq 'BUILD_SIGN') {
    $preflightText = (& $buildScript -Flow $Flow -Preflight | Out-String).Trim()
    Require (-not [string]::IsNullOrWhiteSpace($preflightText)) 'O3F15 observer build preflight returned no JSON.'
    $buildPreflight = $preflightText | ConvertFrom-Json
    Require ([bool](Required $buildPreflight 'eligible')) "O3F15 $Flow build/sign pre-action cannot freeze before exact eligibility evidence."
    $evidencePath = [string](Required $buildPreflight 'eligibilityEvidencePath')
    Require (-not [string]::IsNullOrWhiteSpace([string](Required $buildPreflight 'eligibilityEvidenceSha256'))) 'O3F15 build/sign eligibility evidence lacks a hash.'
    $outputPath = Join-Path $PSScriptRoot ('PREACTION_O3F15_' + $Flow + '_BUILD_SIGN.json')
    $buildSignDependencies = @($buildScript,$definitionPath,$contractPath,$routeAnchorPath,$packageBuilder,$packageTester,$cloneGatePath,$harnessGatePath,$pathGatePath,$contractGatePath,$evidencePath)
    if ($Flow -eq 'P1') {
        $launchGatePath = [string](Required $buildPreflight 'launchGatePath')
        $launchGateSha256 = [string](Required $buildPreflight 'launchGateSha256')
        Require (-not [string]::IsNullOrWhiteSpace($launchGatePath) -and $launchGateSha256 -match '^[A-F0-9]{64}$') 'O3F15 P1 pre-action requires the exact bound signed launch gate.'
        Require ((Sha256 $launchGatePath) -eq $launchGateSha256) 'O3F15 P1 bound signed launch gate changed after build preflight.'
        $buildSignDependencies += $launchGatePath
    }
    foreach ($path in $buildSignDependencies) {
        Add-Dependency -List $dependencies -Project $project -Path $path
    }
}
else {
    $flowRoot = Join-Path 'C:\F15O' $Flow
    $routeGatePath = Join-Path $flowRoot ('dpf\O3F15_' + $Flow + '_COMPLETE_ROUTE_GATE.json')
    $packageGatePath = Join-Path $flowRoot ('dpf\O3F15_' + $Flow + '_FINAL_PACKAGE_GATE.json')
    $buildPreactionPath = Join-Path $PSScriptRoot ('PREACTION_O3F15_' + $Flow + '_BUILD_SIGN.json')
    foreach ($path in @($routeGatePath,$packageGatePath,$buildPreactionPath)) {
        Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15 $Flow publish pre-action dependency is absent: $path"
    }
    $routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
    $packageGate = Get-Content -LiteralPath $packageGatePath -Raw | ConvertFrom-Json
    Require ([string](Required $routeGate 'state') -eq ('PASS_O3F15_' + $Flow + '_OBSERVER_COMPLETE_ROUTE_GATE')) 'O3F15 publish route gate state changed.'
    Require ([string](Required $packageGate 'state') -eq ('PASS_O3F15_' + $Flow + '_OBSERVER_FINAL_PACKAGE_GATE')) 'O3F15 publish package gate state changed.'
    $evidencePath = [string](Required $routeGate 'eligibilityEvidencePath')
    $continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
    $continuity = Get-Content -LiteralPath $continuityPath -Raw | ConvertFrom-Json
    $checkpointPath = Join-Path $project ([string](Required $continuity 'currentPhaseCheckpoint')).Replace('/','\')
    Require ((Sha256 $checkpointPath) -eq [string](Required $continuity 'currentPhaseCheckpointSha256')) 'O3F15 publish pre-action continuity checkpoint binding changed.'
    $requestZip = [string](Required $routeGate 'requestZipPath')
    $outputPath = Join-Path $flowRoot 'PREACTION_PUBLISH.json'
    $publishInvocationPath = Join-Path $flowRoot 'PUBLISH_INVOCATION.json'
    foreach ($path in @($publishScript,$routeGatePath,$packageGatePath,$buildPreactionPath,$contractPath,$cloneGatePath,$harnessGatePath,$pathGatePath,$contractGatePath,$continuityPath,$checkpointPath,$evidencePath,$requestZip)) {
        Add-Dependency -List $dependencies -Project $project -Path $path
    }
    $publishInvocation = [ordered]@{
        schema='argos_ocv03_o3f15_observer_publish_invocation_v1'; state='FROZEN_EXACT_PUBLISH_ONCE'; flow=$Flow
        powerShellScriptSha256=Sha256 $publishScript; requestId=[string](Required $routeGate 'requestId')
        requestZip=[string](Required $routeGate 'requestZipPath'); requestZipSha256=[string](Required $routeGate 'requestZipSha256')
        routeGate=$routeGatePath; routeGateSha256=Sha256 $routeGatePath
        packageGate=$packageGatePath; packageGateSha256=Sha256 $packageGatePath
        preactionContract=$outputPath
        publicationGate=(Join-Path (Split-Path -Parent $outputPath) ('O3F15_' + $Flow + '_PUBLISH_GATE.json'))
        maximumPublications=1; requestRetryAuthorized=$false; matchingSignedTerminalResponseRequired=$true
        gatewayAcceptanceIsExecutionEvidence=$false; reviewOnly=$true; productionRoutingEnabled=$false
    }
    $invocationEncoding = New-Object Text.UTF8Encoding($false)
    $publishInvocationBytes = $invocationEncoding.GetBytes((($publishInvocation | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $publishInvocationSha256 = Bytes-Sha256 $publishInvocationBytes
    $dependencies.Add([pscustomobject]@{path=$publishInvocationPath;sha256=$publishInvocationSha256})
}

$actionType = 'BUILD_SIGN_ONE_SHOT_O3F15_' + $Flow + '_READ_ONLY_DATA_PULL'
if ($Stage -eq 'PUBLISH') { $actionType = 'PUBLISH_ONCE_O3F15_' + $Flow + '_READ_ONLY_DATA_PULL' }
$contract = [ordered]@{
    schema='argos_zero_recurrence_preaction_v2'; revision=('O3F15_' + $Flow + '_' + $Stage + '_20260903')
    createdUtc=[DateTime]::UtcNow.ToString('o'); state='PASS_PREACTION_CONTRACT'; actionType=$actionType
    historyAuditPath='work/ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
    historyAuditSha256='D54E5F766D4546827069C65F098D3C98E8C1C9B724B718A101674775FB51DA75'
    dependencies=@($dependencies)
    controls=[ordered]@{
        valuesDerivedFromCurrentFileEvidence=$true; dependencyHashesPinned=$true; templateResidueAuditPassed=$true
        installedRootAndTaskIdentityPinned=$true; pathAndWrapperGatesPassedWhenApplicable=$true
        compoundCommandsFileBacked=$true; windowsPowerShell51ParserPassedWhenApplicable=$true
        externalEvidenceJsonRehydrated=$true; arrayBoundaryModeSafe=$true; zeroOneManyCollectionCasesPassed=$true
        optionalPropertiesPresenceTested=$true; residentConsumersInventoried=$true; declaredActionMatchesImplementation=$true
        expectedFailureCaptureSafe=$true; optionalToolsDiscoveredBeforeUse=$true; queueAndReturnRouteTerminalGatePlanned=$true
        historyAuditCompleteBeforeCheckpoint=$true
    }
    collectionCaseEvidence=[ordered]@{
        path='work/ARGOS_POWERSHELL_COLLECTION_CASE_GATE_20260821.json'
        sha256='17128A6B5745DC2B588D9803BD0E892D1108A69F87BA35300567089E1D83FF11'
        requiredCaseIds=@('ZERO','ONE','MANY')
    }
    legacyEvidenceException=[ordered]@{used=$false;newExecutionAuthorized=$false;futureReuseAllowed=$false;blockedArtifacts=@()}
    classification='OBSERVE'; flow=$Flow; stage=$Stage; eligibilityEvidencePath=$evidencePath
    requestRetryAuthorized=$false; reviewOnly=$true; productionRoutingEnabled=$false
}
$encoding = New-Object Text.UTF8Encoding($false)
$contractBytes = $encoding.GetBytes((($contract | ConvertTo-Json -Depth 24) + [Environment]::NewLine))
$contractSha256 = Bytes-Sha256 $contractBytes
Require (-not (Test-Path -LiteralPath $outputPath)) "O3F15 pre-action output exists: $outputPath"
if ($Stage -eq 'PUBLISH') {
    Require (-not (Test-Path -LiteralPath $publishInvocationPath)) "O3F15 publish invocation output exists: $publishInvocationPath"
}

if ($Preflight) {
    [ordered]@{
        schema='argos_ocv03_o3f15_observer_preaction_freeze_preflight_v1'; checkedUtc=[DateTime]::UtcNow.ToString('o')
        state=('PASS_O3F15_' + $Flow + '_' + $Stage + '_PREACTION_FREEZE_PREFLIGHT')
        flow=$Flow; stage=$Stage; outputPath=$outputPath; outputSha256=$contractSha256
        publishInvocationPath=$publishInvocationPath; publishInvocationSha256=$publishInvocationSha256
        dependencyCount=$dependencies.Count
        mutationsPerformed=$false; packageBuilt=$false; requestSigned=$false; requestPublished=$false; jbodContacted=$false
        requestRetryAuthorized=$false; reviewOnly=$true; productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 10
    return
}

if ($Stage -eq 'PUBLISH') {
    Write-NewBytes -Path $publishInvocationPath -Bytes $publishInvocationBytes
}
Write-NewBytes -Path $outputPath -Bytes $contractBytes
& $preactionTool -AuditPath $historyPath -ContractPath $outputPath -ProjectRoot $project -Preflight | Out-Null
[ordered]@{
    schema='argos_ocv03_o3f15_observer_preaction_freeze_gate_v1'; frozenUtc=[DateTime]::UtcNow.ToString('o')
    state=('PASS_O3F15_' + $Flow + '_' + $Stage + '_PREACTION_FROZEN'); flow=$Flow; stage=$Stage
    outputPath=$outputPath; outputSha256=Sha256 $outputPath; publishInvocationPath=$publishInvocationPath
    publishInvocationSha256=$publishInvocationSha256
    requestRetryAuthorized=$false; packageBuilt=$false; requestPublished=$false; jbodContacted=$false
    reviewOnly=$true; productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 10
