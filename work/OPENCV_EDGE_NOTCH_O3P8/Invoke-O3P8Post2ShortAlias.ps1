[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [Parameter(Mandatory = $true, ParameterSetName = 'Preflight')]
    [switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Apply')]
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Require-ExactFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Sha256,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label is absent: $Path"
    }
    if ((Get-Sha256 -Path $Path) -cne $Sha256) {
        throw "$Label SHA-256 changed: $Path"
    }
}

function Require-Properties {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names,
        [Parameter(Mandatory = $true)][string]$Label
    )
    foreach ($name in $Names) {
        if ($Object.PSObject.Properties.Name -notcontains $name) {
            throw "$Label is missing required property: $name"
        }
    }
}

function New-O3P8LaunchGateRecord {
    param(
        [Parameter(Mandatory = $true)][object]$EngineResult,
        [Parameter(Mandatory = $true)][object]$Output,
        [Parameter(Mandatory = $true)][string]$InvocationPath,
        [Parameter(Mandatory = $true)][string]$InvocationSha256,
        [Parameter(Mandatory = $true)][string]$WorkspaceRoot,
        [Parameter(Mandatory = $true)][string]$AliasDrive,
        [Parameter(Mandatory = $true)][string]$AliasSentinelSha256,
        [Parameter(Mandatory = $true)][string]$EngineOutputPath
    )
    Require-Properties -Object $EngineResult -Names @('state', 'outputSha256', 'inputCount', 'states', 'dfTopologyInvocationCount') -Label 'O3P8 engine terminal object'
    Require-Properties -Object $Output -Names @('state', 'rows', 'dfTopologyInvocationCount') -Label 'O3P8 output object'
    $states = @($Output.rows | ForEach-Object {
        Require-Properties -Object $_ -Names @('state', 'candidateLocalTopologyInsufficiencyCount') -Label 'O3P8 output row'
        [string]$_.state
    })
    if ($states.Count -ne 3 -or [int]$EngineResult.inputCount -ne 3) {
        throw "O3P8 output or terminal member count changed: $($states.Count)"
    }
    $engineStates = @($EngineResult.states | ForEach-Object { [string]$_ })
    if ($engineStates.Count -ne $states.Count -or ($engineStates -join '|') -cne ($states -join '|')) {
        throw 'O3P8 engine terminal member states do not match the output rows.'
    }
    if (
        [string]$EngineResult.state -ne [string]$Output.state -or
        [int]$EngineResult.dfTopologyInvocationCount -ne 0 -or
        [int]$Output.dfTopologyInvocationCount -ne 0
    ) {
        throw 'O3P8 engine terminal state or split-method invariant does not match the output.'
    }
    $insufficiencyCount = 0
    foreach ($row in @($Output.rows)) {
        $insufficiencyCount += [int]$row.candidateLocalTopologyInsufficiencyCount
    }
    return [ordered]@{
        schema = 'argos_ocv03_o3p8_short_alias_launch_gate_v1'
        state = 'PASS_O3P8_POST2_SHORT_ALIAS_EXECUTION'
        invocationPath = $InvocationPath
        invocationSha256 = $InvocationSha256
        workspaceRoot = $WorkspaceRoot
        aliasDrive = $AliasDrive
        aliasTargetVerified = $true
        aliasSentinelSha256 = $AliasSentinelSha256
        aliasRemoved = $true
        engineState = [string]$EngineResult.state
        engineOutputPath = $EngineOutputPath
        engineOutputSha256 = [string]$EngineResult.outputSha256
        memberCount = $states.Count
        memberStates = $states
        candidateLocalTopologyInsufficiencyCount = $insufficiencyCount
        candidateLocalTopologyInsufficiencySource = 'SUM_OF_HASH_VERIFIED_OUTPUT_ROWS'
        dfTopologyInvocationCount = [int]$EngineResult.dfTopologyInvocationCount
        sourceMutationPerformed = $false
        imageBytesEmittedToStdout = $false
        networkUsed = $false
        backsidePixelsConsumed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
}

function Get-SubstTarget {
    param(
        [Parameter(Mandatory = $true)][string]$SubstPath,
        [Parameter(Mandatory = $true)][string]$Drive
    )
    $rows = @(& $SubstPath)
    if ($LASTEXITCODE -ne 0) {
        throw "subst inventory failed with exit code $LASTEXITCODE."
    }
    $prefix = $Drive.ToUpperInvariant() + '\: => '
    $matches = @($rows | Where-Object { ([string]$_).StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) })
    if ($matches.Count -eq 0) {
        return $null
    }
    if ($matches.Count -ne 1) {
        throw "subst returned multiple mappings for $Drive."
    }
    return ([string]$matches[0]).Substring($prefix.Length).TrimEnd('\')
}

if (-not (Test-Path -LiteralPath $InvocationManifest -PathType Leaf)) {
    throw "Invocation manifest is absent: $InvocationManifest"
}
$invocation = Get-Content -Raw -LiteralPath $InvocationManifest | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_ocv03_o3p8_short_alias_launch_invocation_v1') {
    throw 'O3P8 launch invocation schema changed.'
}
if (
    -not [bool]$invocation.reviewOnly -or
    [bool]$invocation.productionRoutingEnabled -or
    [bool]$invocation.sourceMutationAllowed -or
    [bool]$invocation.networkAllowed -or
    [bool]$invocation.liveProviderActivation -or
    [bool]$invocation.backsidePixelsConsumed -or
    [bool]$invocation.dfTopologyInvocationAllowed
) {
    throw 'O3P8 launch authority or channel split widened.'
}

$workspaceRoot = [IO.Path]::GetFullPath([string]$invocation.workspaceRoot).TrimEnd('\')
$aliasDrive = ([string]$invocation.aliasDrive).ToUpperInvariant()
$aliasRoot = $aliasDrive + '\'
$pythonPath = [IO.Path]::GetFullPath([string]$invocation.python.path)
$substPath = [IO.Path]::GetFullPath([string]$invocation.subst.path)
$sentinelFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.sentinel.relativePath)))
$engineFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.engine.relativePath)))
$jobFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.job.relativePath)))
$syntheticGateFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.syntheticGate.relativePath)))
$terminalFixtureFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.terminalFixture.relativePath)))
$outputFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.output.relativePath)))
$launchGateFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.launchGate.relativePath)))

if (
    $workspaceRoot -cne 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab' -or
    $aliasDrive -cne 'R:' -or
    $outputFull -cne 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\work\OPENCV_EDGE_NOTCH_O3P8\O3P8_POST2_RESULT.json'
) {
    throw 'O3P8 workspace, alias, or output contract changed.'
}
Require-ExactFile -Path $pythonPath -Sha256 ([string]$invocation.python.sha256) -Label 'Python runtime'
Require-ExactFile -Path $substPath -Sha256 ([string]$invocation.subst.sha256) -Label 'subst executable'
Require-ExactFile -Path $sentinelFull -Sha256 ([string]$invocation.sentinel.sha256) -Label 'workspace sentinel'
Require-ExactFile -Path $engineFull -Sha256 ([string]$invocation.engine.sha256) -Label 'O3P8 engine'
Require-ExactFile -Path $jobFull -Sha256 ([string]$invocation.job.sha256) -Label 'O3P8 job'
Require-ExactFile -Path $syntheticGateFull -Sha256 ([string]$invocation.syntheticGate.sha256) -Label 'O3P8 synthetic gate'
Require-ExactFile -Path $terminalFixtureFull -Sha256 ([string]$invocation.terminalFixture.sha256) -Label 'O3P8 engine terminal gate fixture'
$syntheticGate = Get-Content -Raw -LiteralPath $syntheticGateFull | ConvertFrom-Json
if (
    [string]$syntheticGate.state -ne 'PASS_O3P8_FRONT_SPLIT_NOTCH_SYNTHETIC_GATE' -or
    [int]$syntheticGate.dfTopologyInvocationCount -ne 0 -or
    [bool]$syntheticGate.maximumDfRadialIntervalWidthEnabled
) {
    throw 'O3P8 synthetic gate is not the exact split-method PASS.'
}
if (Test-Path -LiteralPath $outputFull) {
    throw "Create-new O3P8 output already exists: $outputFull"
}
if (Test-Path -LiteralPath ($outputFull + '.partial')) {
    throw "Create-new O3P8 partial output already exists: $outputFull.partial"
}
if (Test-Path -LiteralPath $launchGateFull) {
    throw "Create-new O3P8 launch gate already exists: $launchGateFull"
}
if (Test-Path -LiteralPath ($launchGateFull + '.partial')) {
    throw "Create-new O3P8 partial launch gate already exists: $launchGateFull.partial"
}
$existingTarget = Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive
if ($null -ne $existingTarget -or (Test-Path -LiteralPath $aliasRoot)) {
    throw "O3P8 alias drive is not unused: $aliasDrive"
}

if ($Preflight) {
    $terminalFixture = Get-Content -Raw -LiteralPath $terminalFixtureFull | ConvertFrom-Json
    if ([string]$terminalFixture.schema -ne 'argos_ocv03_o3p8_engine_terminal_gate_fixture_v1') {
        throw 'O3P8 engine terminal gate fixture schema changed.'
    }
    $fixtureGate = New-O3P8LaunchGateRecord `
        -EngineResult $terminalFixture.engineResult `
        -Output $terminalFixture.output `
        -InvocationPath ([IO.Path]::GetFullPath($InvocationManifest)) `
        -InvocationSha256 (Get-Sha256 -Path $InvocationManifest) `
        -WorkspaceRoot $workspaceRoot `
        -AliasDrive $aliasDrive `
        -AliasSentinelSha256 ([string]$invocation.sentinel.sha256) `
        -EngineOutputPath $outputFull
    if (
        [int]$fixtureGate.memberCount -ne [int]$terminalFixture.expectedGate.memberCount -or
        [int]$fixtureGate.candidateLocalTopologyInsufficiencyCount -ne [int]$terminalFixture.expectedGate.candidateLocalTopologyInsufficiencyCount -or
        [int]$fixtureGate.dfTopologyInvocationCount -ne [int]$terminalFixture.expectedGate.dfTopologyInvocationCount -or
        [string]$fixtureGate.engineState -ne [string]$terminalFixture.expectedGate.engineState
    ) {
        throw 'O3P8 post-engine gate construction did not match the frozen terminal fixture.'
    }
    [ordered]@{
        schema = 'argos_ocv03_o3p8_short_alias_launch_preflight_v1'
        state = 'PASS_O3P8_SHORT_ALIAS_LAUNCH_PREFLIGHT'
        invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
        invocationSha256 = Get-Sha256 -Path $InvocationManifest
        workspaceRoot = $workspaceRoot
        aliasDrive = $aliasDrive
        aliasUnused = $true
        sentinelSha256 = [string]$invocation.sentinel.sha256
        engineSha256 = [string]$invocation.engine.sha256
        jobSha256 = [string]$invocation.job.sha256
        syntheticGateSha256 = [string]$invocation.syntheticGate.sha256
        terminalFixtureSha256 = [string]$invocation.terminalFixture.sha256
        terminalGateConstructionFixturePassed = $true
        candidateLocalTopologyInsufficiencySource = 'SUM_OF_HASH_VERIFIED_OUTPUT_ROWS'
        outputAbsent = $true
        launchGateAbsent = $true
        dfTopologyInvocationAllowed = $false
        backsidePixelsConsumed = $false
        imageBytesDecoded = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

if (-not $Apply) {
    throw 'Either -Preflight or -Apply is required.'
}

$aliasCreated = $false
$aliasSentinelHash = $null
$engineResult = $null
try {
    & $substPath $aliasDrive $workspaceRoot
    if ($LASTEXITCODE -ne 0) {
        throw "subst create failed with exit code $LASTEXITCODE."
    }
    $aliasCreated = $true
    $mappedTarget = Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive
    if ($null -eq $mappedTarget -or [IO.Path]::GetFullPath($mappedTarget).TrimEnd('\') -cne $workspaceRoot) {
        throw "O3P8 alias maps to the wrong target: $mappedTarget"
    }
    $aliasSentinel = [IO.Path]::GetFullPath((Join-Path $aliasRoot ([string]$invocation.sentinel.relativePath)))
    Require-ExactFile -Path $aliasSentinel -Sha256 ([string]$invocation.sentinel.sha256) -Label 'alias sentinel'
    $aliasSentinelHash = Get-Sha256 -Path $aliasSentinel

    $engineAlias = [IO.Path]::GetFullPath((Join-Path $aliasRoot ([string]$invocation.engine.relativePath)))
    $jobAlias = [IO.Path]::GetFullPath((Join-Path $aliasRoot ([string]$invocation.job.relativePath)))
    Require-ExactFile -Path $engineAlias -Sha256 ([string]$invocation.engine.sha256) -Label 'alias engine'
    Require-ExactFile -Path $jobAlias -Sha256 ([string]$invocation.job.sha256) -Label 'alias job'

    $priorPythonPath = [Environment]::GetEnvironmentVariable('PYTHONPATH', 'Process')
    $priorDontWrite = [Environment]::GetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', 'Process')
    try {
        [Environment]::SetEnvironmentVariable('PYTHONPATH', [string]$invocation.runtimeRoot, 'Process')
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', '1', 'Process')
        $preflightRows = @(& $pythonPath -B $engineAlias --job $jobAlias --preflight)
        $preflightExit = $LASTEXITCODE
        if ($preflightExit -ne 0 -or $preflightRows.Count -ne 1) {
            throw "O3P8 alias Python preflight failed with exit $preflightExit and $($preflightRows.Count) rows."
        }
        $pythonPreflight = [string]$preflightRows[0] | ConvertFrom-Json
        if (
            [string]$pythonPreflight.state -ne 'PASS_O3P8_FRONT_SPLIT_NOTCH_PREFLIGHT' -or
            [int]$pythonPreflight.dfTopologyInvocationCount -ne 0 -or
            [bool]$pythonPreflight.imageBytesDecoded -or
            [bool]$pythonPreflight.outputCreated
        ) {
            throw 'O3P8 alias Python preflight did not pass exactly.'
        }
        $engineRows = @(& $pythonPath -B $engineAlias --job $jobAlias)
        $engineExit = $LASTEXITCODE
    } finally {
        [Environment]::SetEnvironmentVariable('PYTHONPATH', $priorPythonPath, 'Process')
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', $priorDontWrite, 'Process')
    }
    if ($engineExit -ne 0 -or $engineRows.Count -ne 1) {
        throw "O3P8 engine failed with exit $engineExit and $($engineRows.Count) rows."
    }
    $engineResult = [string]$engineRows[0] | ConvertFrom-Json
    if (
        [string]$engineResult.state -ne 'COMPLETE_O3P8_POST2_BF_TOPOLOGY_DF_RADIAL_REVIEW_ONLY' -or
        [int]$engineResult.dfTopologyInvocationCount -ne 0
    ) {
        throw 'O3P8 engine terminal state or split-method invariant changed.'
    }
    Require-ExactFile -Path $outputFull -Sha256 ([string]$engineResult.outputSha256) -Label 'O3P8 engine output'
    $aliasOutput = [IO.Path]::GetFullPath((Join-Path $aliasRoot ([string]$invocation.output.relativePath)))
    Require-ExactFile -Path $aliasOutput -Sha256 ([string]$engineResult.outputSha256) -Label 'O3P8 alias output'
} finally {
    if ($aliasCreated) {
        $mappedBeforeDelete = Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive
        if ($null -eq $mappedBeforeDelete -or [IO.Path]::GetFullPath($mappedBeforeDelete).TrimEnd('\') -cne $workspaceRoot) {
            throw "O3P8 refuses to remove a non-matching alias: $mappedBeforeDelete"
        }
        & $substPath $aliasDrive /D
        if ($LASTEXITCODE -ne 0) {
            throw "subst delete failed with exit code $LASTEXITCODE."
        }
    }
}
if ($null -ne (Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive) -or (Test-Path -LiteralPath $aliasRoot)) {
    throw 'O3P8 alias remained after bounded execution.'
}

$output = Get-Content -Raw -LiteralPath $outputFull | ConvertFrom-Json
$launchResult = New-O3P8LaunchGateRecord `
    -EngineResult $engineResult `
    -Output $output `
    -InvocationPath ([IO.Path]::GetFullPath($InvocationManifest)) `
    -InvocationSha256 (Get-Sha256 -Path $InvocationManifest) `
    -WorkspaceRoot $workspaceRoot `
    -AliasDrive $aliasDrive `
    -AliasSentinelSha256 $aliasSentinelHash `
    -EngineOutputPath $outputFull
$launchJson = $launchResult | ConvertTo-Json -Depth 7
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($launchGateFull + '.partial', $launchJson + [Environment]::NewLine, $utf8NoBom)
Move-Item -LiteralPath ($launchGateFull + '.partial') -Destination $launchGateFull
$launchJson
