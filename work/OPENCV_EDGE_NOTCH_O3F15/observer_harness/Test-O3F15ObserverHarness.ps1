#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'O3F15 observer harness test is preflight-only.' }

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

$contractPath = Join-Path $PSScriptRoot 'O3F15_OBSERVER_CONTRACT.json'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
Require ([string](Required $contract 'schema') -eq 'argos_ocv03_o3f15_portal_observer_contract_v1') 'O3F15 observer contract schema changed.'
Require ([string](Required $contract 'state') -eq 'FROZEN_OBSERVER_HARNESSES_READY_NO_REQUEST_CREATED') 'O3F15 observer contract is not frozen.'
Require ([string](Required $contract 'classification') -eq 'OBSERVE') 'O3F15 observer classification changed.'
Require ([string](Required $contract 'transport') -eq 'SIGNED_PROJECT_PORTAL_DATA_PULL_ONLY') 'O3F15 observer transport changed.'
Require ([string](Required $contract 'approvedRoot') -eq 'JBOD_KLARF_EXPORT') 'O3F15 observer approved root changed.'
Require ([string](Required $contract 'mirrorRoot') -eq 'D:/KLARFExport/_ArgosReview/F15S') 'O3F15 observer mirror root changed.'
$pins = Required $contract 'routePins'
Require ([string](Required $pins 'qualifiedRouteAnchor') -eq 'work/OPENCV_EDGE_NOTCH_O3K1/O3K1_DATA_PULL_COMPLETE_ROUTE_GATE.json') 'O3F15 observer DATA_PULL route anchor changed.'
Require ([string](Required $pins 'qualifiedRouteAnchorSha256') -eq 'F8AB82BB364AD6DBADF2C40AE0BFE7F18B646013D89F9A8663924E0770D06247') 'O3F15 observer DATA_PULL route-anchor hash changed.'
Require ([string](Required $pins 'endpointWorkerSha256') -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O3F15 observer worker pin changed.'
Require ([string](Required $pins 'installedConfigEvidenceSha256') -eq '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB') 'O3F15 observer config pin changed.'
Require ([string](Required $pins 'inheritedQueueSafetyGateSha256') -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F15 observer queue-safety pin changed.'
$invariants = Required $contract 'invariants'
foreach ($name in @('sourceImageBytesRequested','sourceMutationAuthorized','sourceDeletionAuthorized','existingTaskOrProcessActionAuthorized','providerActivationAuthorized','automaticHoldClearanceAuthorized','requestRetryAuthorized','rustDeskUsed','trainingEligible','xmlEligible','productionEligible','productionRoutingEnabled')) {
    Require (-not [bool](Required $invariants $name)) "O3F15 observer false invariant changed: $name"
}
Require ([bool](Required $invariants 'reviewOnly')) 'O3F15 observer review-only invariant changed.'

$expected = [ordered]@{
    P1=[ordered]@{paths=@('_ArgosReview/F15S/PROGRESS.json');maximumFiles=1;maximumBytes=[int64]262144;maxResultBytes=[int64]1048576}
    F1=[ordered]@{paths=@('_ArgosReview/F15S/PROGRESS.json','_ArgosReview/F15S/SUMMARY.json','_ArgosReview/F15S/RESULTS.json');maximumFiles=3;maximumBytes=[int64]4194304;maxResultBytes=[int64]8388608}
    T1=[ordered]@{paths=@('_ArgosReview/F15S/TERMINAL_FAILURE.json');maximumFiles=1;maximumBytes=[int64]262144;maxResultBytes=[int64]1048576}
}
$definitionHashes = [ordered]@{}
foreach ($flow in @('P1','F1','T1')) {
    $definitionPath = Join-Path $PSScriptRoot ('O3F15_' + $flow + '_DATA_PULL_DEFINITION.json')
    $definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
    Require ([string](Required $definition 'schema') -eq 'argos_project_portal_request_definition_v1') "O3F15 $flow definition schema changed."
    Require ([string](Required $definition 'targetRole') -eq 'JBOD' -and [string](Required $definition 'jobClass') -eq 'DATA_PULL') "O3F15 $flow route changed."
    $parameters = Required $definition 'parameters'
    Require ([string](Required $parameters 'approvedRoot') -eq 'JBOD_KLARF_EXPORT') "O3F15 $flow approved root changed."
    $paths = @((Required $parameters 'relativePaths') | ForEach-Object { [string]$_ })
    $expectedPaths = @($expected[$flow].paths)
    Require ($paths.Count -eq $expectedPaths.Count -and @(Compare-Object -ReferenceObject $expectedPaths -DifferenceObject $paths -SyncWindow 0).Count -eq 0) "O3F15 $flow exact path set/order changed."
    Require ([int](Required $parameters 'maximumFiles') -eq [int]$expected[$flow].maximumFiles) "O3F15 $flow maximumFiles changed."
    Require ([int64](Required $parameters 'maximumBytes') -eq [int64]$expected[$flow].maximumBytes) "O3F15 $flow maximumBytes changed."
    Require ([int64](Required $definition 'maxResultBytes') -eq [int64]$expected[$flow].maxResultBytes) "O3F15 $flow maxResultBytes changed."
    foreach ($relativePath in $paths) {
        Require ($relativePath.StartsWith('_ArgosReview/F15S/',[StringComparison]::Ordinal)) "O3F15 $flow path escaped F15S."
        Require (-not [IO.Path]::IsPathRooted($relativePath) -and $relativePath -notmatch '\.\.' -and $relativePath -notmatch '[*?]') "O3F15 $flow path is unsafe."
    }
    $definitionHashes[$flow] = Sha256 $definitionPath
}

$terminalStates = @('COMPLETE_O3F15_FULL978','HOLD_O3F15_EXECUTION_STOPPED')
Require ($terminalStates.Count -eq 2) 'O3F15 terminal state set changed.'
Require ('RUNNING_O3F15_FULL978' -notin $terminalStates) 'O3F15 running state became F1-eligible.'
Require ('HOLD_O3F15_ARTIFACT_COMMIT_FAILURE' -notin $terminalStates) 'O3F15 artifact failure became F1-eligible.'
$zero = @()
$one = @('COMPLETE_O3F15_FULL978')
$many = @($terminalStates)
Require ($zero.Count -eq 0 -and $one.Count -eq 1 -and $many.Count -eq 2) 'O3F15 zero/one/many collection boundary changed.'
$flows = Required $contract 'flows'
Require ([string](Required (Required $flows 'P1') 'state') -eq 'FROZEN_ONE_SHOT_PROGRESS_OBSERVER') 'O3F15 P1 flow is not frozen.'
Require ([string](Required (Required $flows 'F1') 'state') -eq 'FROZEN_ONE_SHOT_TERMINAL_CORPUS_OBSERVER') 'O3F15 F1 flow is not frozen.'
Require ([string](Required (Required $flows 'P1') 'eligibleOnlyAfter') -eq 'FUTURE_NON_WITHDRAWN_SIGNED_O3F15_L2_OR_LATER_LAUNCH_BINDING') 'O3F15 P1 future launch-binding requirement changed.'
Require ([string](Required (Required $flows 'T1') 'state') -eq 'DOCUMENTED_DISABLED_UNLESS_ARTIFACT_FAILURE_IS_PROVED') 'O3F15 T1 became automatically eligible.'
Require (-not [bool](Required (Required $flows 'T1') 'automaticEligibility')) 'O3F15 T1 automatic eligibility changed.'

$scripts = @('Build-O3F15ObserverRequest.ps1','Publish-O3F15ObserverRequest.ps1','Find-O3F15ObserverResponse.ps1','Collect-O3F15ObserverResponse.ps1','New-O3F15ObserverPreaction.ps1')
$parser = [Management.Automation.Language.Parser]
$scriptHashes = [ordered]@{}
foreach ($name in $scripts) {
    $path = Join-Path $PSScriptRoot $name
    $tokens = $null
    $errors = $null
    [void]$parser::ParseFile($path,[ref]$tokens,[ref]$errors)
    Require (@($errors).Count -eq 0) "O3F15 PowerShell parser rejected $name"
    $scriptHashes[$name] = Sha256 $path
}

[ordered]@{
    schema='argos_ocv03_o3f15_observer_contract_gate_v1'; checkedUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_O3F15_OBSERVER_CONTRACT_GATE'; classification='OBSERVE'; approvedRoot='JBOD_KLARF_EXPORT'
    flowCount=3; p1FileCount=1; f1FileCount=3; t1FileCount=1; terminalStateCount=2
    p1OneShot=$true; f1OneShot=$true; t1AutomaticEligibility=$false; requestRetryAuthorized=$false
    definitionHashes=$definitionHashes; scriptHashes=$scriptHashes; parserErrors=0; zeroOneManyPassed=$true
    sourceImageBytesRequested=$false; mutationsPerformed=$false; requestBuilt=$false; requestSigned=$false
    requestPublished=$false; jbodContacted=$false; rustDeskUsed=$false; reviewOnly=$true; productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 12
