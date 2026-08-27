#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$consumer = Join-Path $root 'Build-O3C1Request.ps1'
$gate = Join-Path $root 'O3C1_FINAL_PACKAGE_GATE.json'
$signed = 'C:\A31'
$final = Join-Path $root 'final_o3c1'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O3C1 build invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O3C1 build invocation manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3c1_build_request_invocation_v1') 'O3C1 build invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O3C1_20260827T141000000Z_62629419') 'O3C1 build invocation revision changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260827T141000111Z_62629419C3A1') 'O3C1 build invocation request changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Build') 'O3C1 build invocation action set changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O3C1 build invocation authority changed.'

$command = Get-Command -Name $consumer -CommandType ExternalScript -ErrorAction Stop
Assert-True ($command.Parameters.Keys -contains 'Preflight' -and $command.Parameters.Keys -contains 'Build') 'O3C1 build paired-consumer arguments changed.'
Assert-True ((Get-Sha256 $consumer) -eq 'C6014CF714065F982A3B6B2DF9F131069059C14210218B36550CA0C96FBA7695') 'O3C1 build paired consumer changed.'
Assert-True (-not (Test-Path -LiteralPath $gate) -and -not (Test-Path -LiteralPath $signed) -and -not (Test-Path -LiteralPath $final)) 'O3C1 build outputs already exist.'

$consumerPreflight = (& $consumer -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$consumerPreflight.state -eq 'PASS_O3C1_BUILD_PREFLIGHT' -and -not [bool]$consumerPreflight.mutationsPerformed) 'O3C1 build consumer preflight changed.'
if ($Preflight) {
    [ordered]@{schema='argos_o3c1_build_request_orchestrator_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_BUILD_REQUEST_ORCHESTRATOR_PREFLIGHT';requestId=[string]$consumerPreflight.requestId;namedArgumentsResolvedByGetCommand=$true;consumerState=[string]$consumerPreflight.state;mutationsPerformed=$false;sourceImageBytesRead=$false;sourceHashingPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

$result = (& $consumer -Build | Out-String) | ConvertFrom-Json
Assert-True ([string]$result.state -eq 'PASS_O3C1_FINAL_PACKAGE_GATE') 'O3C1 build consumer result changed.'
Assert-True ([bool]$result.maintenanceInstalledShaMatchesPayload -and -not [bool]$result.sourceImageBytesRead -and -not [bool]$result.sourceHashingPerformed) 'O3C1 build metadata-only capability contract changed.'
Assert-True (Test-Path -LiteralPath $gate -PathType Leaf) 'O3C1 final package gate was not written.'
[ordered]@{schema='argos_o3c1_build_request_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3C1_SIGNED_REQUEST_BUILT';requestId=[string]$result.requestId;namedArgumentsResolvedByGetCommand=$true;gateSha256=Get-Sha256 $gate;requestZipSha256=[string]$result.requestZipSha256;installedProviderCapability=$true;maximumPublications=1;retryAuthorized=$false;sourceImageBytesRead=$false;sourceHashingPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
