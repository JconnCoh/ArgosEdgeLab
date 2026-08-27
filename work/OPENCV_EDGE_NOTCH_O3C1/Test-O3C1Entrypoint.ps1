[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)][string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(@(@($Preflight,$Gate)|Where-Object{[bool]$_}).Count-ne1){throw 'Specify exactly one of -Preflight or -Gate.'}

function Resolve-ProjectPath([string]$Root,[string]$Value){
    if([string]::IsNullOrWhiteSpace($Value)-or$Value.IndexOfAny([char[]]'*?')-ge0){throw 'Unsafe control path.'}
    return $(if([IO.Path]::IsPathRooted($Value)){[IO.Path]::GetFullPath($Value)}else{[IO.Path]::GetFullPath((Join-Path $Root $Value))})
}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Pin([string]$Path,[string]$Sha){if(-not(Test-Path -LiteralPath $Path -PathType Leaf)-or(Get-Sha $Path)-ne$Sha){throw "Pinned test dependency changed: $Path"}}
function Assert-AliasAbsent(){if(Get-PSDrive -Name F -ErrorAction SilentlyContinue){throw 'Process-local alias F remains mounted.'}}

$projectRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$controlPath=Resolve-ProjectPath $projectRoot $InvocationManifest
$control=Get-Content -LiteralPath $controlPath -Raw|ConvertFrom-Json
if([string]$control.schema-ne'argos_o3c1_entrypoint_test_control_v1'-or[string]$control.state-ne'FROZEN_TEST_INPUT'-or-not[bool]$control.reviewOnly-or[bool]$control.productionRoutingEnabled){throw 'O3C1 entrypoint test control changed.'}
$entrypoint=Resolve-ProjectPath $projectRoot ([string]$control.entrypointPath)
$provider=Resolve-ProjectPath $projectRoot ([string]$control.providerPath)
$fixtureConfig=Resolve-ProjectPath $projectRoot ([string]$control.fixtureConfigPath)
$okInvocation=Resolve-ProjectPath $projectRoot ([string]$control.okInvocationPath)
$failureInvocation=Resolve-ProjectPath $projectRoot ([string]$control.failureInvocationPath)
$gateOutput=Resolve-ProjectPath $projectRoot ([string]$control.gateOutputPath)
Assert-Pin $entrypoint ([string]$control.entrypointSha256)
Assert-Pin $provider ([string]$control.providerSha256)
Assert-Pin $fixtureConfig ([string]$control.fixtureConfigSha256)
Assert-Pin $okInvocation ([string]$control.okInvocationSha256)
Assert-Pin $failureInvocation ([string]$control.failureInvocationSha256)
$fixtureRoot=[IO.Path]::GetFullPath([string]$control.fixtureRoot)
if(Test-Path -LiteralPath $fixtureRoot){throw 'O3C1 entrypoint fresh fixture root already exists.'}
if(Test-Path -LiteralPath $gateOutput){throw 'O3C1 entrypoint gate output already exists.'}
Assert-AliasAbsent

$preflightResult=(& $entrypoint -Preflight -InvocationManifest $okInvocation)|ConvertFrom-Json
if([string]$preflightResult.state-ne'PASS_O3C1_ENTRYPOINT_PREFLIGHT'-or[bool]$preflightResult.pathsEnumerated-or[bool]$preflightResult.mutationsPerformed){throw 'O3C1 entrypoint preflight failed.'}
if($Preflight){
    [ordered]@{schema='argos_o3c1_entrypoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_ENTRYPOINT_TEST_PREFLIGHT';entrypointSha256=[string]$control.entrypointSha256;providerSha256=[string]$control.providerSha256;fixtureRoot=$fixtureRoot;gateOutput=$gateOutput;mutationsPerformed=$false;imageBytesRead=$false;sourceHashingPerformed=$false}|ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'ok'))
[void](New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'fail'))
$failureCaptured=$false
$failureMessage=$null
try{[void](& $entrypoint -Rehearsal -InvocationManifest $failureInvocation)}catch{$failureMessage=[string]$_.Exception.Message;$failureCaptured=$failureMessage-match'INJECTED_O3C1_ENTRYPOINT_FAILURE_AFTER_PROVIDER'}
if(-not$failureCaptured){throw 'O3C1 entrypoint injected failure was not captured.'}
if(Test-Path -LiteralPath (Join-Path $fixtureRoot 'fail\OCV03_O3C1_HOTSPOT_INVENTORY.json')){throw 'O3C1 injected failure wrote an output.'}
Assert-AliasAbsent

$success=(& $entrypoint -Rehearsal -InvocationManifest $okInvocation)|ConvertFrom-Json
if([string]$success.state-ne'PASS_OCV03_METADATA_CAPABILITY_O3C1'-or[string]$success.inventoryDisposition-ne'COMPLETE'){throw 'O3C1 entrypoint rehearsal did not complete.'}
$inventory=$success.inventory
if([int]$inventory.bmpLeafCount-ne[int]$control.expectedBmpLeafCount-or[int]$inventory.directoryCount-ne[int]$control.expectedDirectoryCount-or[int]$inventory.otherLeafCount-ne[int]$control.expectedOtherLeafCount-or[int]$inventory.skippedPathRowCount-ne0-or[int]$inventory.accessErrorCount-ne0){throw 'O3C1 entrypoint rehearsal counts changed.'}
if(-not[bool]$inventory.processLocalAlias.removed-or[bool]$inventory.processLocalAlias.persistent){throw 'O3C1 entrypoint alias lifecycle failed.'}
Assert-AliasAbsent
$outputPath=Join-Path $fixtureRoot 'ok\OCV03_O3C1_HOTSPOT_INVENTORY.json'
if(-not(Test-Path -LiteralPath $outputPath -PathType Leaf)-or(Get-Sha $outputPath)-ne[string]$success.capabilityOutputSha256){throw 'O3C1 entrypoint output evidence changed.'}

$record=[ordered]@{
    schema='argos_o3c1_entrypoint_gate_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_O3C1_ENTRYPOINT_GATE'
    lifecycle='FROZEN_LOCAL_EVIDENCE'
    entrypointSha256=[string]$control.entrypointSha256
    providerSha256=[string]$control.providerSha256
    controlSha256=Get-Sha $controlPath
    preflightState=[string]$preflightResult.state
    terminalState=[string]$success.state
    inventoryDisposition=[string]$success.inventoryDisposition
    bmpLeafCount=[int]$inventory.bmpLeafCount
    directoryCount=[int]$inventory.directoryCount
    otherLeafCount=[int]$inventory.otherLeafCount
    skippedPathRowCount=[int]$inventory.skippedPathRowCount
    accessErrorCount=[int]$inventory.accessErrorCount
    injectedFailureCaptured=$failureCaptured
    injectedFailureMessage=$failureMessage
    outputWrittenAfterProducerSuccess=$true
    aliasRemovedAfterSuccess=$true
    aliasRemovedAfterFailure=$true
    sourceFixtureRoot=[string]$control.sourceFixtureRoot
    fixtureRoot=$fixtureRoot
    fixturePreserved=$true
    imageBytesRead=$false
    sourceHashingPerformed=$false
    jbodContacted=$false
    taskActions=0
    processActions=0
    reviewOnly=$true
    productionRoutingEnabled=$false
}
[IO.File]::WriteAllText($gateOutput,(($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$gateSha=Get-Sha $gateOutput
[ordered]@{schema='argos_o3c1_entrypoint_gate_result_v1';state='PASS_O3C1_ENTRYPOINT_GATE';gateOutput=$gateOutput;gateSha256=$gateSha;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 5


