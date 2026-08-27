#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$consumer = Join-Path $root 'Test-O2D23Endpoint.ps1'
$gate = Join-Path $root 'O2D23_ENTRYPOINT_TEST_GATE_R2.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 endpoint-test invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 endpoint-test invocation manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_endpoint_test_invocation_v1') 'O2D23 endpoint-test invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 endpoint-test invocation revision changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Test') 'O2D23 endpoint-test invocation action set changed.'
Assert-True (-not [bool]$invocation.jbodExecution -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 endpoint-test invocation authority changed.'

$command = Get-Command -Name $consumer -CommandType ExternalScript -ErrorAction Stop
Assert-True ($command.Parameters.Keys -contains 'Preflight' -and $command.Parameters.Keys -contains 'Test') 'O2D23 endpoint-test paired-consumer arguments changed.'
Assert-True ((Get-Sha256 $consumer) -eq '893A4BA914927495D70229E1D77210FE1E537E567994B0D1730654D6575FE8C4') 'O2D23 endpoint-test paired consumer changed.'
Assert-True (-not (Test-Path -LiteralPath $gate)) 'O2D23 endpoint-test gate already exists.'

$consumerPreflight = (& $consumer -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$consumerPreflight.state -eq 'PASS_O2D23_ENTRYPOINT_TEST_PREFLIGHT_R2' -and -not [bool]$consumerPreflight.mutationsPerformed) 'O2D23 endpoint-test consumer preflight changed.'
if ($Preflight) {
    [ordered]@{schema='argos_o2d23_endpoint_test_orchestrator_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ENDPOINT_TEST_ORCHESTRATOR_PREFLIGHT';namedArgumentsResolvedByGetCommand=$true;consumerState=[string]$consumerPreflight.state;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

$result = (& $consumer -Test | Out-String) | ConvertFrom-Json
Assert-True ([string]$result.state -eq 'PASS_O2D23_ENTRYPOINT_TEST_GATE_R2') 'O2D23 endpoint-test consumer result changed.'
Assert-True (Test-Path -LiteralPath $gate -PathType Leaf) 'O2D23 endpoint-test gate was not written.'
[ordered]@{schema='argos_o2d23_endpoint_test_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ENDPOINT_TEST';namedArgumentsResolvedByGetCommand=$true;gateSha256=Get-Sha256 $gate;sourceImageBytesRead=$false;targetSlot25ImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
