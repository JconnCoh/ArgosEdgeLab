#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [switch]$InjectFailureAfterCollect,
    [string]$ProviderPath,
    [string]$ConfigurationPath,
    [string]$InvocationPath,
    [string]$ExpectedProviderSha256,
    [string]$ExpectedConfigurationSha256,
    [string]$ExpectedInvocationSha256
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($Preflight -and $Rehearsal) { throw 'O3F15L4O1 cannot combine Preflight and Rehearsal.' }
if ($InjectFailureAfterCollect -and -not $Rehearsal) { throw 'Failure injection is rehearsal-only.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }

$live = -not $Preflight -and -not $Rehearsal
if ($live) {
    Require ([string]::IsNullOrWhiteSpace($ProviderPath) -and [string]::IsNullOrWhiteSpace($ConfigurationPath) -and [string]::IsNullOrWhiteSpace($InvocationPath)) 'O3F15L4O1 live paths are fixed.'
    $effectiveProviderPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_ResultJsonProviderV1.ps1'
    $effectiveConfigurationPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_O3F15L4_GATE_JSON_CONFIG.json'
    $effectiveInvocationPath = Join-Path $PSScriptRoot 'O3F15L4O1_GATE_JSON_INVOCATION.json'
    $effectiveProviderSha256 = 'EF9773ADAC624A7A8A689989AB0EE404C2863B4E32B2666F437331E8CC9CAE67'
    $effectiveConfigurationSha256 = 'A4B1ACF76F1BE60506AAA9EFD61521AC87C44DB0A92AA906D5C3789EDE1CB3DB'
    $effectiveInvocationSha256 = '6183F6AE88E719665EC41867AD18BD80A5B7DD18604CE6A8DB374CAA3C4B0D08'
} else {
    foreach ($value in @($ProviderPath,$ConfigurationPath,$InvocationPath,$ExpectedProviderSha256,$ExpectedConfigurationSha256,$ExpectedInvocationSha256)) {
        Require (-not [string]::IsNullOrWhiteSpace($value)) 'O3F15L4O1 test paths and hashes are required.'
    }
    $effectiveProviderPath = $ProviderPath
    $effectiveConfigurationPath = $ConfigurationPath
    $effectiveInvocationPath = $InvocationPath
    $effectiveProviderSha256 = $ExpectedProviderSha256
    $effectiveConfigurationSha256 = $ExpectedConfigurationSha256
    $effectiveInvocationSha256 = $ExpectedInvocationSha256
}

foreach ($path in @($effectiveProviderPath,$effectiveConfigurationPath,$effectiveInvocationPath)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4O1 dependency absent: $path" }
Require ((Sha $effectiveProviderPath) -eq $effectiveProviderSha256) 'O3F15L4O1 provider hash changed.'
Require ((Sha $effectiveConfigurationPath) -eq $effectiveConfigurationSha256) 'O3F15L4O1 configuration hash changed.'
Require ((Sha $effectiveInvocationPath) -eq $effectiveInvocationSha256) 'O3F15L4O1 invocation hash changed.'

$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($effectiveProviderPath,[ref]$tokens,[ref]$parseErrors)
Require (@($parseErrors).Count -eq 0) 'O3F15L4O1 provider parser failed.'
$providerPreflight = (& $effectiveProviderPath -Preflight -ConfigurationPath $effectiveConfigurationPath -InvocationPath $effectiveInvocationPath) | ConvertFrom-Json
Require ([string]$providerPreflight.state -eq 'PASS_O3J1_RESULT_JSON_PROVIDER_PREFLIGHT') 'O3F15L4O1 provider preflight state changed.'
Require ([int]$providerPreflight.requestedFileCount -eq 1 -and -not [bool]$providerPreflight.sourceFilesRead -and -not [bool]$providerPreflight.imageBytesRead -and -not [bool]$providerPreflight.mutationsPerformed) 'O3F15L4O1 provider preflight authority changed.'

if ($Preflight) {
    [ordered]@{schema='argos_o3f15l4o1_entrypoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4O1_ENTRYPOINT_PREFLIGHT';providerSha256=$effectiveProviderSha256;configurationSha256=$effectiveConfigurationSha256;invocationSha256=$effectiveInvocationSha256;requestedFileCount=1;sourceFilesRead=$false;imageBytesRead=$false;mutationsPerformed=$false;taskOrProcessActionPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5 -Compress
    return
}

$collection = (& $effectiveProviderPath -Collect -ConfigurationPath $effectiveConfigurationPath -InvocationPath $effectiveInvocationPath) | ConvertFrom-Json
if ($InjectFailureAfterCollect) { throw 'INJECTED_O3F15L4O1_FAILURE_AFTER_COLLECT' }
Require ([string]$collection.state -eq 'PASS_O3J1_EXACT_RESULT_JSON_COLLECTED' -and [int]$collection.fileCount -eq 1 -and @($collection.files).Count -eq 1) 'O3F15L4O1 collection terminal contract changed.'
Require ([bool]$collection.jsonTextOnly -and -not [bool]$collection.imageBytesRead -and -not [bool]$collection.sourceMutationPerformed -and -not [bool]$collection.taskOrProcessActionPerformed -and -not [bool]$collection.providerActivated) 'O3F15L4O1 collection authority changed.'
[ordered]@{schema='argos_o3f15l4o1_entrypoint_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4O1_GATE_JSON_CAPABILITY';revision='O3F15L4O1_20260903_GATE_SUMMARY';providerSha256=$effectiveProviderSha256;configurationSha256=$effectiveConfigurationSha256;invocationSha256=$effectiveInvocationSha256;collection=$collection;sourceJsonFilesRead=$true;sourceImageBytesRead=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessActionPerformed=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 12 -Compress
