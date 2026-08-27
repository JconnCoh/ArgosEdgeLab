#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Build)){throw 'Specify exactly one of -Preflight or -Build.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
$root=[IO.Path]::GetFullPath($PSScriptRoot)
$manifestPath=[IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)) 'O3J1 build invocation must remain under the draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O3J1 build invocation is absent.'
$invocation=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
Assert-True ([string]$invocation.schema-eq'argos_o3j1_build_request_invocation_v1'-and[string]$invocation.revision-eq'O3J1_20260827T185500000Z_62629419'-and[string]$invocation.requestId-eq'REQ_20260827T185500111Z_62629419O3J1') 'O3J1 build invocation identity changed.'
Assert-True (@($invocation.allowedActions).Count-eq2-and@($invocation.allowedActions)-contains'Preflight'-and@($invocation.allowedActions)-contains'Build') 'O3J1 build action set changed.'
Assert-True ([int]$invocation.maximumPublications-eq1-and-not[bool]$invocation.retryAuthorized-and[bool]$invocation.reviewOnly-and-not[bool]$invocation.trainingEligible-and-not[bool]$invocation.xmlEligible-and-not[bool]$invocation.productionEligible-and-not[bool]$invocation.productionRoutingEnabled) 'O3J1 build authority changed.'
$consumer=Join-Path $root 'Build-O3J1Request.ps1'
$command=Get-Command -Name $consumer -CommandType ExternalScript -ErrorAction Stop
Assert-True ($command.Parameters.Keys-contains'Preflight'-and$command.Parameters.Keys-contains'Build') 'O3J1 paired consumer arguments changed.'
Assert-True ((Get-Sha $consumer)-eq'1E5862FCB55DBD315EBF4D619CC06A6FFA6072B569F1B6C168670E0DD64853ED') 'O3J1 paired consumer changed.'
$gate=Join-Path $root 'O3J1_FINAL_PACKAGE_GATE.json';$staging='C:\A3J1';$final=Join-Path $root 'final'
Assert-True (-not(Test-Path -LiteralPath $gate)-and-not(Test-Path -LiteralPath $staging)-and-not(Test-Path -LiteralPath $final)) 'O3J1 build outputs already exist.'
$consumerPreflight=(& $consumer -Preflight|Out-String)|ConvertFrom-Json
Assert-True ([string]$consumerPreflight.state-eq'PASS_O3J1_BUILD_PREFLIGHT'-and-not[bool]$consumerPreflight.mutationsPerformed) 'O3J1 build consumer preflight changed.'
if($Preflight){[ordered]@{schema='argos_o3j1_build_orchestrator_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_BUILD_ORCHESTRATOR_PREFLIGHT';requestId=[string]$consumerPreflight.requestId;consumerState=[string]$consumerPreflight.state;namedArgumentsResolvedByGetCommand=$true;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return}
$result=(& $consumer -Build|Out-String)|ConvertFrom-Json
Assert-True ([string]$result.state-eq'PASS_O3J1_FINAL_PACKAGE_GATE'-and[string]$result.requestId-eq[string]$invocation.requestId) 'O3J1 build result changed.'
Assert-True (-not[bool]$result.sourceImageBytesRead-and-not[bool]$result.sourceMutationPerformed-and-not[bool]$result.healthyProcessorTouched-and-not[bool]$result.providerActivated-and-not[bool]$result.requestRetryAuthorized) 'O3J1 build result authority changed.'
Assert-True (Test-Path -LiteralPath $gate -PathType Leaf) 'O3J1 final package gate was not written.'
[ordered]@{schema='argos_o3j1_build_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3J1_SIGNED_REQUEST_BUILT';requestId=[string]$result.requestId;namedArgumentsResolvedByGetCommand=$true;gateSha256=Get-Sha $gate;requestZipSha256=[string]$result.requestZipSha256;maximumPublications=1;retryAuthorized=$false;sourceImageBytesRead=$false;healthyProcessorTouched=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
