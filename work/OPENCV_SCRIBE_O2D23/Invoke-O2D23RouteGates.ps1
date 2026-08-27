#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$routeConsumer = Join-Path $root 'Test-O2D23Routes.ps1'
$shareConsumer = Join-Path $root 'Get-O2D23CurrentShareObservation.ps1'
$routeGate = Join-Path $root 'O2D23_COMPLETE_ROUTE_GATE.json'
$shareGate = Join-Path $root 'O2D23_CURRENT_SHARE_OBSERVATION.json'
$aliasGate = Join-Path $root 'O2D23_INSPECTIONREVS_U_ALIAS_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 route-gate invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 route-gate invocation manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_route_gate_invocation_v1') 'O2D23 route-gate invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 route-gate invocation revision changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260827T035500111Z_3C97863DBF26') 'O2D23 route-gate invocation request changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Gate') 'O2D23 route-gate invocation action set changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 route-gate authority changed.'

$routeCommand = Get-Command -Name $routeConsumer -CommandType ExternalScript -ErrorAction Stop
$shareCommand = Get-Command -Name $shareConsumer -CommandType ExternalScript -ErrorAction Stop
foreach ($command in @($routeCommand,$shareCommand)) {
    Assert-True ($command.Parameters.Keys -contains 'Preflight' -and $command.Parameters.Keys -contains 'Gate') "O2D23 route paired-consumer arguments changed: $($command.Name)"
}
Assert-True ((Get-Sha256 $routeConsumer) -eq '518AE5E64CA869F3918F0F90DECCC626F177B67A003ACFF17BD9728E9D836813') 'O2D23 route-test paired consumer changed.'
Assert-True ((Get-Sha256 $shareConsumer) -eq 'DBEACF2A613D7750BEB55A229BD50C13CC75335206A68B529359D4B57D5FCDD3') 'O2D23 share-observation paired consumer changed.'
foreach ($path in @($routeGate,$shareGate,$aliasGate)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D23 route gate output already exists: $path" }

$routePreflight = (& $routeConsumer -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$routePreflight.state -eq 'HOLD_O2D23_COMPLETE_ROUTE_PREFLIGHT_ARGOS_INBOUND_RELAY_UNPROVEN' -and -not [bool]$routePreflight.targetExecuted) 'O2D23 route consumer preflight changed.'
$sharePreflight = (& $shareConsumer -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$sharePreflight.state -eq 'PASS_O2D23_CURRENT_SHARE_OBSERVATION_PREFLIGHT' -and [int]$sharePreflight.pendingRequestCount -eq 0 -and [bool]$sharePreflight.targetAbsent -and [bool]$sharePreflight.uploadAbsent -and [bool]$sharePreflight.persistentMappingVerified -and -not [bool]$sharePreflight.mutationsPerformed) 'O2D23 share consumer preflight changed.'

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_route_gate_orchestrator_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ROUTE_GATE_ORCHESTRATOR_PREFLIGHT';namedArgumentsResolvedByGetCommand=$true;routeState=[string]$routePreflight.state;shareState=[string]$sharePreflight.state;pendingRequestCount=0;targetAbsent=$true;uploadAbsent=$true;mutationsPerformed=$false;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

$routeResult = (& $routeConsumer -Gate | Out-String) | ConvertFrom-Json
Assert-True ([string]$routeResult.state -eq 'HOLD_O2D23_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN') 'O2D23 route consumer gate changed.'
$shareResult = (& $shareConsumer -Gate | Out-String) | ConvertFrom-Json
Assert-True ([string]$shareResult.state -eq 'PASS_O2D23_CURRENT_SHARE_OBSERVATION_WRITTEN') 'O2D23 share consumer gate changed.'
foreach ($path in @($routeGate,$shareGate,$aliasGate)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D23 route gate output was not written: $path" }
[ordered]@{schema='argos_o2d23_route_gate_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ROUTE_EVIDENCE_WRITTEN';namedArgumentsResolvedByGetCommand=$true;routeGateSha256=Get-Sha256 $routeGate;shareObservationSha256=Get-Sha256 $shareGate;aliasGateSha256=Get-Sha256 $aliasGate;pendingRequestCount=0;targetAbsent=$true;uploadAbsent=$true;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
