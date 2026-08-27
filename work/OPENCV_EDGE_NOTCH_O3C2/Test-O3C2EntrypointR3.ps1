#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3C2 R3 refuses existing output: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$entrypoint = Join-Path $root 'Invoke-O3C2SourceFreezeEndpoint.ps1'
$successInvocation = Join-Path $root 'O3C2_ENTRYPOINT_R3_SUCCESS.invocation.json'
$failureInvocation = Join-Path $root 'O3C2_ENTRYPOINT_R3_FAILURE.invocation.json'
$r1Withdrawal = Join-Path $root 'O3C2_ENTRYPOINT_TEST_R1_WITHDRAWAL.json'
$r2Withdrawal = Join-Path $root 'O3C2_ENTRYPOINT_TEST_R2_WITHDRAWAL.json'
$gatePath = Join-Path $root 'O3C2_ENTRYPOINT_R3_GATE.json'
$outputRoot = 'C:\A32E2'
$expectedEntrypointSha256 = 'B6561FECE5570EC7A21CBB6BD56871871C1C4C829C781B4924893B36BCAE76F0'
foreach ($path in @($entrypoint,$successInvocation,$failureInvocation,$r1Withdrawal,$r2Withdrawal)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3C2 R3 prerequisite is missing: $path"
}
Assert-True ((Get-Sha256 $entrypoint) -eq $expectedEntrypointSha256) 'O3C2 R3 entrypoint bytes changed.'
$command = Get-Command -Name $entrypoint -CommandType ExternalScript -ErrorAction Stop
foreach ($parameter in @('Preflight','Rehearsal','InvocationManifest')) {
    Assert-True ($command.Parameters.Keys -contains $parameter) "O3C2 R3 entrypoint parameter is missing: $parameter"
}
$success = Get-Content -LiteralPath $successInvocation -Raw | ConvertFrom-Json
$failure = Get-Content -LiteralPath $failureInvocation -Raw | ConvertFrom-Json
foreach ($invocation in @($success,$failure)) {
    Assert-True ([string]$invocation.schema -eq 'argos_o3c2_entrypoint_invocation_v1') 'O3C2 R3 invocation schema changed.'
    Assert-True ([string]$invocation.processorRoot -eq 'C:/A32E2') 'O3C2 R3 output root changed.'
    Assert-True (Test-Path -LiteralPath ([string]$invocation.targetManifestPath) -PathType Leaf) 'O3C2 R3 fixture targets are missing.'
    Assert-True (Test-Path -LiteralPath ([string]$invocation.inventoryPath) -PathType Leaf) 'O3C2 R3 fixture inventory is missing.'
    Assert-True (Test-Path -LiteralPath (Join-Path ([string]$invocation.portalRoot) 'config\endpoint_jbod.json') -PathType Leaf) 'O3C2 R3 fixture endpoint config is missing.'
}
Assert-True ([int]$success.failAfterHashCount -eq 0) 'O3C2 R3 success injection changed.'
Assert-True ([int]$failure.failAfterHashCount -eq 1) 'O3C2 R3 failure injection changed.'
Assert-True (-not (Test-Path -LiteralPath $outputRoot)) 'O3C2 R3 output root already exists.'
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O3C2 R3 gate already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3c2_entrypoint_r3_test_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C2_ENTRYPOINT_R3_TEST_PREFLIGHT'
        entrypointSha256 = $expectedEntrypointSha256
        namedArgumentsResolvedByGetCommand = $true
        exactLiveCardinalityFixturePairCount = 10
        exactLiveCardinalityFixtureLeafCount = 20
        outputRoot = $outputRoot
        mutationsPerformed = $false
        sourceHashingPerformed = $false
        imageBytesDecoded = $false
        pixelProcessingPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $outputRoot)
$preflightResult = (& $entrypoint -Preflight -InvocationManifest $successInvocation | Out-String) | ConvertFrom-Json
Assert-True ([string]$preflightResult.state -eq 'PASS_O3C2_ENTRYPOINT_PREFLIGHT' -and -not [bool]$preflightResult.mutationsPerformed) 'O3C2 R3 exact preflight failed.'
$successResult = (& $entrypoint -Rehearsal -InvocationManifest $successInvocation | Out-String) | ConvertFrom-Json
Assert-True ([string]$successResult.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE' -and [int]$successResult.pairCount -eq 10 -and [int]$successResult.leafCount -eq 20) 'O3C2 R3 success rehearsal failed.'
Assert-True (-not [bool]$successResult.knownNotchLocationConsumed -and -not [bool]$successResult.notchAnglePriorConsumed -and -not [bool]$successResult.fixedAngularSearchWindowConsumed) 'O3C2 R3 success consumed a forbidden notch prior.'

$failureCaught = $false
$failureMessage = ''
try { & $entrypoint -Rehearsal -InvocationManifest $failureInvocation | Out-Null }
catch {
    $failureMessage = $_.Exception.Message
    $failureCaught = $failureMessage -match '^O3C2_PROVIDER_EXECUTION_FAILED: .*INJECTED_O3C2_FAILURE_AFTER_HASH'
}
Assert-True $failureCaught "O3C2 R3 exact injected failure token was not observed: $failureMessage"
Assert-True (-not (Test-Path -LiteralPath ([string]$failure.outputPath))) 'O3C2 R3 injected failure wrote an output.'
Assert-True ($null -eq (Get-PSDrive -Name Q -ErrorAction SilentlyContinue) -and -not [IO.Directory]::Exists('Q:\')) 'O3C2 R3 injected failure left the alias visible.'

$gate = [ordered]@{
    schema = 'argos_o3c2_entrypoint_r3_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3C2_ENTRYPOINT_R3_GATE'
    disposition = 'PENDING_GATE'
    entrypointSha256 = $expectedEntrypointSha256
    r1WithdrawalSha256 = Get-Sha256 $r1Withdrawal
    r2WithdrawalSha256 = Get-Sha256 $r2Withdrawal
    namedArgumentsResolvedByGetCommand = $true
    exactLiveCardinalityFixturePairCount = 10
    exactLiveCardinalityFixtureLeafCount = 20
    preflightState = [string]$preflightResult.state
    preflightNonMutating = $true
    successPairCount = [int]$successResult.pairCount
    successLeafCount = [int]$successResult.leafCount
    explicitFailurePrefixObserved = $true
    injectedFailureTokenObserved = $true
    injectedFailureLeavesNoOutput = $true
    injectedFailureRemovesAlias = $true
    knownNotchLocationConsumed = $false
    notchAnglePriorConsumed = $false
    fixedAngularSearchWindowConsumed = $false
    imageBytesDecoded = $false
    pixelProcessingPerformed = $false
    sourceMutationPerformed = $false
    taskOrProcessActionPerformed = $false
    providerActivated = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    outputRoot = $outputRoot
}
Write-JsonCreateNew $gatePath $gate
$gate | ConvertTo-Json -Depth 8
