#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$selfPins = Join-Path $root 'Test-O2D23SelfPins.ps1'
$noArgument = Join-Path $root 'Test-O2D23NoArgumentFile.ps1'
$selfPinGate = Join-Path $root 'O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE.json'
$noArgumentGate = Join-Path $root 'O2D23_NO_ARGUMENT_FILE_GATE.json'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 core-test invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 core-test invocation manifest is absent.'
Assert-True ((Get-Item -LiteralPath $manifestPath).Length -le 16384) 'O2D23 core-test invocation manifest exceeds 16 KiB.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_core_test_invocation_v1') 'O2D23 core-test invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 core-test invocation revision changed.'
Assert-True ([string]$invocation.script -eq 'work/OPENCV_SCRIBE_O2D23/Invoke-O2D23CoreTests.ps1') 'O2D23 core-test invocation script changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Test') 'O2D23 core-test invocation action set changed.'
Assert-True (-not [bool]$invocation.jbodExecution -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 core-test invocation authority changed.'

$selfCommand = Get-Command -Name $selfPins -CommandType ExternalScript -ErrorAction Stop
$noArgumentCommand = Get-Command -Name $noArgument -CommandType ExternalScript -ErrorAction Stop
foreach ($entry in @($selfCommand, $noArgumentCommand)) {
    Assert-True ($entry.Parameters.Keys -contains 'Preflight') "O2D23 paired consumer lacks Preflight: $($entry.Name)"
    Assert-True ($entry.Parameters.Keys -contains 'Test') "O2D23 paired consumer lacks Test: $($entry.Name)"
}
Assert-True ((Get-Sha256 $selfPins) -eq '423CEBD527488258299DE9D7739A5DD160C60313CE535E0E8FC27BF8B1C70320') 'O2D23 self-pin test changed.'
Assert-True ((Get-Sha256 $noArgument) -eq '63F616A8419A7B4C6E569BF1EA4E636258AECB9D408312B531AFB19287AC6308') 'O2D23 no-argument test changed.'
Assert-True (-not (Test-Path -LiteralPath $selfPinGate)) 'O2D23 self-pin gate already exists.'
Assert-True (-not (Test-Path -LiteralPath $noArgumentGate)) 'O2D23 no-argument gate already exists.'

$selfPreflight = (& $selfPins -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$selfPreflight.state -eq 'PASS_O2D23_SELF_PIN_PREFLIGHT' -and -not [bool]$selfPreflight.mutationsPerformed) 'O2D23 self-pin preflight changed.'
$noArgumentPreflight = (& $noArgument -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$noArgumentPreflight.state -eq 'PASS_O2D23_NO_ARGUMENT_FILE_PREFLIGHT' -and -not [bool]$noArgumentPreflight.mutationsPerformed) 'O2D23 no-argument preflight changed.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d23_core_test_orchestrator_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_CORE_TEST_ORCHESTRATOR_PREFLIGHT'
        pairedConsumerCount=2;namedArgumentsResolvedByGetCommand=$true;selfPinState=[string]$selfPreflight.state;noArgumentState=[string]$noArgumentPreflight.state
        targetExecuted=$false;mutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 6
    return
}

$selfResult = (& $selfPins -Test | Out-String) | ConvertFrom-Json
Assert-True ([string]$selfResult.state -eq 'PASS_O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE') 'O2D23 self-pin exact test changed.'
$noArgumentResult = (& $noArgument -Test | Out-String) | ConvertFrom-Json
Assert-True ([string]$noArgumentResult.state -eq 'PASS_O2D23_EXACT_NO_ARGUMENT_WINDOWS_POWERSHELL_51_FILE') 'O2D23 no-argument exact test changed.'
Assert-True (Test-Path -LiteralPath $selfPinGate -PathType Leaf) 'O2D23 self-pin gate was not written.'
Assert-True (Test-Path -LiteralPath $noArgumentGate -PathType Leaf) 'O2D23 no-argument gate was not written.'

[ordered]@{
    schema='argos_o2d23_core_test_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_CORE_TESTS'
    pairedConsumerCount=2;namedArgumentsResolvedByGetCommand=$true;selfPinGateSha256=Get-Sha256 $selfPinGate;noArgumentGateSha256=Get-Sha256 $noArgumentGate
    targetExecuted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 6
