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
if ([string]$invocation.schema -ne 'argos_ocv03_o3p7_short_alias_launch_invocation_v1') {
    throw 'O3P7 launch invocation schema changed.'
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
    throw 'O3P7 launch authority or channel split widened.'
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
$outputFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.output.relativePath)))
$launchGateFull = [IO.Path]::GetFullPath((Join-Path $workspaceRoot ([string]$invocation.launchGate.relativePath)))

if (
    $workspaceRoot -cne 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab' -or
    $aliasDrive -cne 'R:' -or
    $outputFull -cne 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\work\OPENCV_EDGE_NOTCH_O3P7\O3P7_POST2_RESULT.json'
) {
    throw 'O3P7 workspace, alias, or output contract changed.'
}
Require-ExactFile -Path $pythonPath -Sha256 ([string]$invocation.python.sha256) -Label 'Python runtime'
Require-ExactFile -Path $substPath -Sha256 ([string]$invocation.subst.sha256) -Label 'subst executable'
Require-ExactFile -Path $sentinelFull -Sha256 ([string]$invocation.sentinel.sha256) -Label 'workspace sentinel'
Require-ExactFile -Path $engineFull -Sha256 ([string]$invocation.engine.sha256) -Label 'O3P7 engine'
Require-ExactFile -Path $jobFull -Sha256 ([string]$invocation.job.sha256) -Label 'O3P7 job'
Require-ExactFile -Path $syntheticGateFull -Sha256 ([string]$invocation.syntheticGate.sha256) -Label 'O3P7 synthetic gate'
$syntheticGate = Get-Content -Raw -LiteralPath $syntheticGateFull | ConvertFrom-Json
if (
    [string]$syntheticGate.state -ne 'PASS_O3P7_FRONT_SPLIT_NOTCH_SYNTHETIC_GATE' -or
    [int]$syntheticGate.dfTopologyInvocationCount -ne 0 -or
    [bool]$syntheticGate.maximumDfRadialIntervalWidthEnabled
) {
    throw 'O3P7 synthetic gate is not the exact split-method PASS.'
}
if (Test-Path -LiteralPath $outputFull) {
    throw "Create-new O3P7 output already exists: $outputFull"
}
if (Test-Path -LiteralPath ($outputFull + '.partial')) {
    throw "Create-new O3P7 partial output already exists: $outputFull.partial"
}
if (Test-Path -LiteralPath $launchGateFull) {
    throw "Create-new O3P7 launch gate already exists: $launchGateFull"
}
if (Test-Path -LiteralPath ($launchGateFull + '.partial')) {
    throw "Create-new O3P7 partial launch gate already exists: $launchGateFull.partial"
}
$existingTarget = Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive
if ($null -ne $existingTarget -or (Test-Path -LiteralPath $aliasRoot)) {
    throw "O3P7 alias drive is not unused: $aliasDrive"
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3p7_short_alias_launch_preflight_v1'
        state = 'PASS_O3P7_SHORT_ALIAS_LAUNCH_PREFLIGHT'
        invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
        invocationSha256 = Get-Sha256 -Path $InvocationManifest
        workspaceRoot = $workspaceRoot
        aliasDrive = $aliasDrive
        aliasUnused = $true
        sentinelSha256 = [string]$invocation.sentinel.sha256
        engineSha256 = [string]$invocation.engine.sha256
        jobSha256 = [string]$invocation.job.sha256
        syntheticGateSha256 = [string]$invocation.syntheticGate.sha256
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
        throw "O3P7 alias maps to the wrong target: $mappedTarget"
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
            throw "O3P7 alias Python preflight failed with exit $preflightExit and $($preflightRows.Count) rows."
        }
        $pythonPreflight = [string]$preflightRows[0] | ConvertFrom-Json
        if (
            [string]$pythonPreflight.state -ne 'PASS_O3P7_FRONT_SPLIT_NOTCH_PREFLIGHT' -or
            [int]$pythonPreflight.dfTopologyInvocationCount -ne 0 -or
            [bool]$pythonPreflight.imageBytesDecoded -or
            [bool]$pythonPreflight.outputCreated
        ) {
            throw 'O3P7 alias Python preflight did not pass exactly.'
        }
        $engineRows = @(& $pythonPath -B $engineAlias --job $jobAlias)
        $engineExit = $LASTEXITCODE
    } finally {
        [Environment]::SetEnvironmentVariable('PYTHONPATH', $priorPythonPath, 'Process')
        [Environment]::SetEnvironmentVariable('PYTHONDONTWRITEBYTECODE', $priorDontWrite, 'Process')
    }
    if ($engineExit -ne 0 -or $engineRows.Count -ne 1) {
        throw "O3P7 engine failed with exit $engineExit and $($engineRows.Count) rows."
    }
    $engineResult = [string]$engineRows[0] | ConvertFrom-Json
    if (
        [string]$engineResult.state -ne 'COMPLETE_O3P7_POST2_BF_TOPOLOGY_DF_RADIAL_REVIEW_ONLY' -or
        [int]$engineResult.dfTopologyInvocationCount -ne 0
    ) {
        throw 'O3P7 engine terminal state or split-method invariant changed.'
    }
    Require-ExactFile -Path $outputFull -Sha256 ([string]$engineResult.outputSha256) -Label 'O3P7 engine output'
    $aliasOutput = [IO.Path]::GetFullPath((Join-Path $aliasRoot ([string]$invocation.output.relativePath)))
    Require-ExactFile -Path $aliasOutput -Sha256 ([string]$engineResult.outputSha256) -Label 'O3P7 alias output'
} finally {
    if ($aliasCreated) {
        $mappedBeforeDelete = Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive
        if ($null -eq $mappedBeforeDelete -or [IO.Path]::GetFullPath($mappedBeforeDelete).TrimEnd('\') -cne $workspaceRoot) {
            throw "O3P7 refuses to remove a non-matching alias: $mappedBeforeDelete"
        }
        & $substPath $aliasDrive /D
        if ($LASTEXITCODE -ne 0) {
            throw "subst delete failed with exit code $LASTEXITCODE."
        }
    }
}
if ($null -ne (Get-SubstTarget -SubstPath $substPath -Drive $aliasDrive) -or (Test-Path -LiteralPath $aliasRoot)) {
    throw 'O3P7 alias remained after bounded execution.'
}

$output = Get-Content -Raw -LiteralPath $outputFull | ConvertFrom-Json
$states = @($output.rows | ForEach-Object { [string]$_.state })
if ($states.Count -ne 3 -or [int]$output.dfTopologyInvocationCount -ne 0) {
    throw "O3P7 output member count or split-method invariant changed: $($states.Count)"
}
$launchResult = [ordered]@{
    schema = 'argos_ocv03_o3p7_short_alias_launch_gate_v1'
    state = 'PASS_O3P7_POST2_SHORT_ALIAS_EXECUTION'
    invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
    invocationSha256 = Get-Sha256 -Path $InvocationManifest
    workspaceRoot = $workspaceRoot
    aliasDrive = $aliasDrive
    aliasTargetVerified = $true
    aliasSentinelSha256 = $aliasSentinelHash
    aliasRemoved = $true
    engineState = [string]$engineResult.state
    engineOutputPath = $outputFull
    engineOutputSha256 = [string]$engineResult.outputSha256
    memberCount = $states.Count
    memberStates = $states
    candidateLocalTopologyInsufficiencyCount = [int]$engineResult.candidateLocalTopologyInsufficiencyCount
    dfTopologyInvocationCount = [int]$engineResult.dfTopologyInvocationCount
    sourceMutationPerformed = $false
    imageBytesEmittedToStdout = $false
    networkUsed = $false
    backsidePixelsConsumed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$launchJson = $launchResult | ConvertTo-Json -Depth 7
$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($launchGateFull + '.partial', $launchJson + [Environment]::NewLine, $utf8NoBom)
Move-Item -LiteralPath ($launchGateFull + '.partial') -Destination $launchGateFull
$launchJson
