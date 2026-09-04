#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-Utf8([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false))) }

$entry = Join-Path $PSScriptRoot 'Invoke-O3F15L4O1GateJsonEndpoint.ps1'
$provider = Join-Path (Split-Path -Parent $PSScriptRoot) 'OPENCV_EDGE_NOTCH_O3J1\OCV03_ResultJsonProviderV1.ps1'
$entrySha = '515F7D9617FF2A404F91718C8AA384BC7251488B2D1EFB21930F201017212897'
$providerSha = 'EF9773ADAC624A7A8A689989AB0EE404C2863B4E32B2666F437331E8CC9CAE67'
$fixtureRoot = 'C:\O3F15L4O1Q'
$gatePath = Join-Path $PSScriptRoot 'O3F15L4O1_ENTRYPOINT_GATE.json'
Require (Test-Path -LiteralPath $entry -PathType Leaf) 'O3F15L4O1 entrypoint is absent.'
Require (Test-Path -LiteralPath $provider -PathType Leaf) 'O3F15L4O1 provider is absent.'
Require ((Sha $entry) -eq $entrySha -and (Sha $provider) -eq $providerSha) 'O3F15L4O1 test dependency hash changed.'
Require (-not (Test-Path -LiteralPath $fixtureRoot)) 'O3F15L4O1 fixture root already exists.'
Require (-not (Test-Path -LiteralPath $gatePath)) 'O3F15L4O1 entrypoint gate already exists.'
if ($Preflight) {
    [ordered]@{schema='argos_o3f15l4o1_entrypoint_test_preflight_v1';state='PASS_O3F15L4O1_ENTRYPOINT_TEST_PREFLIGHT';entrypointSha256=$entrySha;providerSha256=$providerSha;fixtureRoot=$fixtureRoot;mutationsPerformed=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5 -Compress
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
try {
    $summaryPath = Join-Path $fixtureRoot 'SUMMARY.json'
    $configPath = Join-Path $fixtureRoot 'CONFIG.json'
    $invocationPath = Join-Path $fixtureRoot 'INVOCATION.json'
    $summaryText = '{"schema":"argos_ocv03_o3f15l4_gate_result_v1","state":"HOLD_O3F15L4_GATE","commands":[{"name":"FOCUSED","returnCode":1,"stderr":"fixture"}]}'
    Write-Utf8 $summaryPath $summaryText
    $summarySha = Sha $summaryPath
    $config = [ordered]@{schema='argos_ocv03_review_json_provider_config_v1';revision='O3F15L4O1_FIXTURE';state='FROZEN_CONFIG';approvedRootName='O3F15L4_GATE_EVIDENCE';approvedRootPath=$fixtureRoot;allowedExtension='.json';maximumFiles=1;maximumFileBytes=4194304;maximumTotalBytes=4194304;allowedRelativePaths=@('SUMMARY.json');imageExtensionsAllowed=$false;sourceMutationAllowed=$false;taskOrProcessActionAllowed=$false;providerActivationAllowed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    $invocation = [ordered]@{schema='argos_ocv03_review_json_provider_invocation_v1';revision='O3F15L4O1_FIXTURE';approvedRootName='O3F15L4_GATE_EVIDENCE';relativePaths=@('SUMMARY.json');expectedFileCount=1;returnRawJsonText=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    Write-Utf8 $configPath (($config | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    Write-Utf8 $invocationPath (($invocation | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
    $configSha = Sha $configPath
    $invocationSha = Sha $invocationPath
    $result = (& $entry -Rehearsal -ProviderPath $provider -ConfigurationPath $configPath -InvocationPath $invocationPath -ExpectedProviderSha256 $providerSha -ExpectedConfigurationSha256 $configSha -ExpectedInvocationSha256 $invocationSha) | ConvertFrom-Json
    Require ([string]$result.state -eq 'PASS_O3F15L4O1_GATE_JSON_CAPABILITY') 'O3F15L4O1 rehearsal result state changed.'
    Require ([int]$result.collection.fileCount -eq 1 -and [string]$result.collection.files[0].rawJsonText -eq $summaryText) 'O3F15L4O1 rehearsal did not return the exact JSON text.'
    $injected = ''
    try { [void](& $entry -Rehearsal -InjectFailureAfterCollect -ProviderPath $provider -ConfigurationPath $configPath -InvocationPath $invocationPath -ExpectedProviderSha256 $providerSha -ExpectedConfigurationSha256 $configSha -ExpectedInvocationSha256 $invocationSha) }
    catch { $injected = [string]$_.Exception.Message }
    Require ($injected -eq 'INJECTED_O3F15L4O1_FAILURE_AFTER_COLLECT') 'O3F15L4O1 injected failure was not exact.'
    Require ((Sha $summaryPath) -eq $summarySha) 'O3F15L4O1 fixture source changed.'
    $gateResult = [ordered]@{schema='argos_o3f15l4o1_entrypoint_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4O1_ENTRYPOINT_GATE';entrypointSha256=$entrySha;providerSha256=$providerSha;successState=[string]$result.state;exactJsonTextReturned=$true;injectedFailureCaptured=$true;taskOrProcessActionPerformed=$false;sourceMutationPerformed=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-Utf8 $gatePath (($gateResult | ConvertTo-Json -Depth 6) + [Environment]::NewLine)
    $gateResult | ConvertTo-Json -Depth 6
}
finally {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
