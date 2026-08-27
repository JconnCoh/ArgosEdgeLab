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
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3C2 entrypoint test refuses existing output: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$entrypoint = Join-Path $root 'Invoke-O3C2SourceFreezeEndpoint.ps1'
$successInvocation = Join-Path $root 'O3C2_ENTRYPOINT_SUCCESS.invocation.json'
$failureInvocation = Join-Path $root 'O3C2_ENTRYPOINT_FAILURE.invocation.json'
$gatePath = Join-Path $root 'O3C2_ENTRYPOINT_GATE.json'
$expectedEntrypointSha256 = '6AB42475C59238F4282FD76AB8A61D7D589C367C2037C6D90505AF5444C4D3BE'
foreach ($path in @($entrypoint,$successInvocation,$failureInvocation)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3C2 entrypoint test prerequisite is missing: $path"
}
Assert-True ((Get-Sha256 $entrypoint) -eq $expectedEntrypointSha256) 'O3C2 entrypoint bytes changed.'
$command = Get-Command -Name $entrypoint -CommandType ExternalScript -ErrorAction Stop
foreach ($parameter in @('Preflight','Rehearsal','InvocationManifest')) {
    Assert-True ($command.Parameters.Keys -contains $parameter) "O3C2 entrypoint parameter is missing: $parameter"
}
$success = Get-Content -LiteralPath $successInvocation -Raw | ConvertFrom-Json
$failure = Get-Content -LiteralPath $failureInvocation -Raw | ConvertFrom-Json
foreach ($invocation in @($success,$failure)) {
    Assert-True ([string]$invocation.schema -eq 'argos_o3c2_entrypoint_invocation_v1') 'O3C2 entrypoint invocation schema changed.'
    Assert-True ([string]$invocation.aliasName -eq 'Q') 'O3C2 entrypoint fixture alias changed.'
    Assert-True (Test-Path -LiteralPath ([string]$invocation.targetManifestPath) -PathType Leaf) 'O3C2 entrypoint fixture target manifest is missing.'
    Assert-True (Test-Path -LiteralPath ([string]$invocation.inventoryPath) -PathType Leaf) 'O3C2 entrypoint fixture inventory is missing.'
}
Assert-True (-not (Test-Path -LiteralPath ([string]$success.outputPath))) 'O3C2 success output already exists.'
Assert-True (-not (Test-Path -LiteralPath ([string]$failure.outputPath))) 'O3C2 failure output already exists.'
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O3C2 entrypoint gate already exists.'

$fixtureConfigRows = New-Object Collections.Generic.List[object]
foreach ($invocation in @($success,$failure)) {
    $configSource = Join-Path (Split-Path -Parent ([string]$invocation.targetManifestPath)) 'config.json'
    $configDestination = Join-Path ([string]$invocation.portalRoot) 'config\endpoint_jbod.json'
    Assert-True (Test-Path -LiteralPath $configSource -PathType Leaf) 'O3C2 fixture config source is missing.'
    Assert-True (-not (Test-Path -LiteralPath $configDestination)) 'O3C2 fixture endpoint config already exists.'
    $fixtureConfigRows.Add([pscustomobject]@{source=$configSource;destination=$configDestination})
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3c2_entrypoint_test_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3C2_ENTRYPOINT_TEST_PREFLIGHT'
        entrypointSha256 = $expectedEntrypointSha256
        namedArgumentsResolvedByGetCommand = $true
        successOutput = [string]$success.outputPath
        failureOutput = [string]$failure.outputPath
        mutationsPerformed = $false
        sourceHashingPerformed = $false
        imageBytesDecoded = $false
        pixelProcessingPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

# The provider resolves its paired config through the invocation portal root.
foreach ($configRow in $fixtureConfigRows) {
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $configRow.destination))
    Copy-Item -LiteralPath $configRow.source -Destination $configRow.destination
}

$preflightResult = (& $entrypoint -Preflight -InvocationManifest $successInvocation | Out-String) | ConvertFrom-Json
Assert-True ([string]$preflightResult.state -eq 'PASS_O3C2_ENTRYPOINT_PREFLIGHT') 'O3C2 exact entrypoint preflight failed.'
Assert-True (-not [bool]$preflightResult.mutationsPerformed -and -not [bool]$preflightResult.sourceHashingPerformed) 'O3C2 exact entrypoint preflight mutated or hashed.'
$successResult = (& $entrypoint -Rehearsal -InvocationManifest $successInvocation | Out-String) | ConvertFrom-Json
Assert-True ([string]$successResult.state -eq 'PASS_O3C2_HOTSPOT_SOURCE_FREEZE' -and [int]$successResult.pairCount -eq 10 -and [int]$successResult.leafCount -eq 20) 'O3C2 exact entrypoint success rehearsal failed.'
Assert-True (-not [bool]$successResult.knownNotchLocationConsumed -and -not [bool]$successResult.notchAnglePriorConsumed -and -not [bool]$successResult.fixedAngularSearchWindowConsumed) 'O3C2 exact entrypoint consumed a forbidden notch prior.'

$failureCaught = $false
try { & $entrypoint -Rehearsal -InvocationManifest $failureInvocation | Out-Null }
catch { $failureCaught = $_.Exception.Message -match 'INJECTED_O3C2_FAILURE_AFTER_HASH' }
Assert-True $failureCaught 'O3C2 exact entrypoint injected failure was not caught.'
Assert-True (-not (Test-Path -LiteralPath ([string]$failure.outputPath))) 'O3C2 exact entrypoint injected failure wrote an output.'
Assert-True ($null -eq (Get-PSDrive -Name Q -ErrorAction SilentlyContinue) -and -not [IO.Directory]::Exists('Q:\')) 'O3C2 exact entrypoint injected failure left the alias visible.'

$gate = [ordered]@{
    schema = 'argos_o3c2_entrypoint_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3C2_ENTRYPOINT_GATE'
    disposition = 'PENDING_GATE'
    entrypointPath = 'work/OPENCV_EDGE_NOTCH_O3C2/Invoke-O3C2SourceFreezeEndpoint.ps1'
    entrypointSha256 = $expectedEntrypointSha256
    namedArgumentsResolvedByGetCommand = $true
    preflightState = [string]$preflightResult.state
    preflightNonMutating = $true
    successPairCount = [int]$successResult.pairCount
    successLeafCount = [int]$successResult.leafCount
    sourceBytesRead = [int64]$successResult.sourceBytesRead
    injectedFailureCaught = $true
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
}
Write-JsonCreateNew $gatePath $gate
$gate | ConvertTo-Json -Depth 8
