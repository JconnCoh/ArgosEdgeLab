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
$root=[IO.Path]::GetFullPath($PSScriptRoot)
$consumer=Join-Path $root 'Build-O3C2Request.ps1'
$gate=Join-Path $root 'O3C2_FINAL_PACKAGE_GATE.json'
$staging='C:\A33'
$final=Join-Path $root 'final_o3c2'
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){$s=[IO.File]::OpenRead($Path);$h=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$h.Dispose();$s.Dispose()}}

$manifestPath=[IO.Path]::GetFullPath($InvocationManifest)
Assert-True($manifestPath.StartsWith($root.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase))'O3C2 build invocation manifest must remain under the exact draft root.'
Assert-True(Test-Path -LiteralPath $manifestPath -PathType Leaf)'O3C2 build invocation manifest absent.'
$invocation=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
Assert-True([string]$invocation.schema-eq'argos_o3c2_build_request_invocation_v1')'O3C2 build invocation schema changed.'
Assert-True([string]$invocation.revision-eq'O3C2_20260827T151200000Z_62629419')'O3C2 build invocation revision changed.'
Assert-True([string]$invocation.requestId-eq'REQ_20260827T151200111Z_62629419C3F2')'O3C2 build invocation request changed.'
Assert-True(@($invocation.allowedActions).Count-eq2-and@($invocation.allowedActions)-contains'Preflight'-and@($invocation.allowedActions)-contains'Build')'O3C2 build invocation action set changed.'
Assert-True([int]$invocation.maximumPublications-eq1-and-not[bool]$invocation.retryAuthorized-and[bool]$invocation.reviewOnly-and-not[bool]$invocation.productionRoutingEnabled)'O3C2 build invocation authority changed.'
$command=Get-Command -Name $consumer -CommandType ExternalScript -ErrorAction Stop
Assert-True($command.Parameters.Keys-contains'Preflight'-and$command.Parameters.Keys-contains'Build')'O3C2 build paired-consumer arguments changed.'
Assert-True((Get-Sha256 $consumer)-eq'FA48F985C303EFF47D5F9354B4E3CACDF1891206BA3DAF576CE78DD23523F73A')'O3C2 build paired consumer changed.'
Assert-True(-not(Test-Path -LiteralPath $gate)-and-not(Test-Path -LiteralPath $staging)-and-not(Test-Path -LiteralPath $final))'O3C2 build outputs already exist.'
$consumerPreflight=(& $consumer -Preflight|Out-String)|ConvertFrom-Json
Assert-True([string]$consumerPreflight.state-eq'PASS_O3C2_BUILD_PREFLIGHT'-and-not[bool]$consumerPreflight.mutationsPerformed)'O3C2 build consumer preflight changed.'
Assert-True(-not[bool]$consumerPreflight.knownNotchLocationConsumed-and-not[bool]$consumerPreflight.notchAnglePriorConsumed-and-not[bool]$consumerPreflight.fixedAngularSearchWindowConsumed)'O3C2 build preflight consumed a forbidden notch prior.'
if($Preflight){[ordered]@{schema='argos_o3c2_build_request_orchestrator_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_BUILD_REQUEST_ORCHESTRATOR_PREFLIGHT';requestId=[string]$consumerPreflight.requestId;namedArgumentsResolvedByGetCommand=$true;consumerState=[string]$consumerPreflight.state;mutationsPerformed=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}
$result=(& $consumer -Build|Out-String)|ConvertFrom-Json
Assert-True([string]$result.state-eq'PASS_O3C2_FINAL_PACKAGE_GATE')'O3C2 build consumer result changed.'
Assert-True([bool]$result.maintenanceInstalledShaMatchesPayload-and-not[bool]$result.sourceHashingPerformed-and-not[bool]$result.imageBytesDecoded-and-not[bool]$result.pixelProcessingPerformed)'O3C2 build capability contract changed.'
Assert-True(-not[bool]$result.knownNotchLocationConsumed-and-not[bool]$result.notchAnglePriorConsumed-and-not[bool]$result.fixedAngularSearchWindowConsumed)'O3C2 build result consumed a forbidden notch prior.'
Assert-True(Test-Path -LiteralPath $gate -PathType Leaf)'O3C2 final package gate was not written.'
[ordered]@{schema='argos_o3c2_build_request_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C2_SIGNED_REQUEST_BUILT';requestId=[string]$result.requestId;namedArgumentsResolvedByGetCommand=$true;gateSha256=Get-Sha256 $gate;requestZipSha256=[string]$result.requestZipSha256;installedProviderCapability=$true;maximumPublications=1;retryAuthorized=$false;sourceHashingPerformed=$false;imageBytesDecoded=$false;pixelProcessingPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
