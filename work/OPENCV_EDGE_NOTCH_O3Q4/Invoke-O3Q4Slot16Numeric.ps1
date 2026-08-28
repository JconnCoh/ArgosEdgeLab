#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$liveInvocationSha256 = '8C50CE2945F2E2B33F3EED04A3F804721053A7AFE05D5FD14EA9E7B794A50705'

function Assert-Condition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-FileSha256 {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Assert-FilePin {
    param([string]$Path, [string]$Sha256, [string]$Label)
    Assert-Condition (Test-Path -LiteralPath $Path -PathType Leaf) "O3Q4 $Label is absent: $Path"
    Assert-Condition ((Get-FileSha256 $Path) -eq $Sha256) "O3Q4 $Label hash changed: $Path"
}

function Assert-SafePath {
    param([string]$Path, [int]$SuffixReserve = 32)
    $full = [IO.Path]::GetFullPath($Path)
    $components = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $maximumComponent = 0
    if ($components.Count -gt 0) {
        $maximumComponent = [int](($components | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    }
    Assert-Condition (($full.Length + $SuffixReserve) -lt 200) "O3Q4 unsafe path: $full"
    Assert-Condition ($maximumComponent -le 80) "O3Q4 unsafe path component: $full"
}

function Write-NewJson {
    param([string]$Path, [object]$Value, [int]$Depth = 64)
    Assert-Condition (-not (Test-Path -LiteralPath $Path)) "O3Q4 create-new JSON exists: $Path"
    $json = ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

function Invoke-OwnedPython {
    param(
        [string]$Python,
        [string]$Engine,
        [string]$Job,
        [string]$ModuleRoot,
        [int]$TimeoutSeconds,
        [int]$MaximumOutputBytes
    )
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $startInfo.Arguments = '"' + $Engine + '" --job "' + $Job + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $startInfo.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $startInfo.EnvironmentVariables['PYTHONPATH'] = $ModuleRoot
    $child = New-Object Diagnostics.Process
    $child.StartInfo = $startInfo
    Assert-Condition $child.Start() 'O3Q4 owned Python child did not start.'
    $ownedChildProcessId = [int]$child.Id
    $startedUtc = $child.StartTime.ToUniversalTime().ToString('o')
    $stdoutTask = $child.StandardOutput.ReadToEndAsync()
    $stderrTask = $child.StandardError.ReadToEndAsync()
    $timedOut = -not $child.WaitForExit($TimeoutSeconds * 1000)
    $killed = $false
    if ($timedOut) {
        try { $child.Kill(); $killed = $true } catch { $killed = $false }
        [void]$child.WaitForExit(5000)
    }
    if (-not $timedOut) { $child.WaitForExit() }
    $result = [pscustomobject]@{
        processId = $ownedChildProcessId
        startedUtc = $startedUtc
        exitCode = if ($timedOut) { $null } else { [int]$child.ExitCode }
        timedOut = $timedOut
        killedOnTimeout = $killed
        stdout = [string]$stdoutTask.Result
        stderr = [string]$stderrTask.Result
    }
    $child.Dispose()
    Assert-Condition ($result.stdout.Length -le $MaximumOutputBytes) 'O3Q4 Python stdout exceeded the bound.'
    Assert-Condition ($result.stderr.Length -le $MaximumOutputBytes) 'O3Q4 Python stderr exceeded the bound.'
    if ($timedOut) { throw 'O3Q4 owned Python child exceeded its bounded timeout.' }
    return $result
}

function Assert-SeedProjection {
    param([object]$Seed, [object]$SeedSource, [object]$SourceRecord, [object]$Contract, [int]$ExpectedCount)
    Assert-Condition ([string]$Seed.schema -eq 'argos_ocv03_o3q4_slot16_seed_projection_v1') 'O3Q4 seed schema changed.'
    Assert-Condition ([string]$Seed.identity -eq [string]$Contract.input.identity) 'O3Q4 seed identity changed.'
    Assert-Condition ([string]$SourceRecord.identity -eq [string]$Contract.input.identity) 'O3Q4 source identity changed.'
    Assert-Condition (@($Seed.physicalIndentationCandidates).Count -eq 0) 'O3Q4 projected physical candidates are not empty.'
    Assert-Condition (@($Seed.dfOnlyBoundaryCandidates).Count -eq $ExpectedCount) 'O3Q4 DF seed count changed.'
    Assert-Condition ([int]$Seed.seedCandidateCount -eq $ExpectedCount) 'O3Q4 declared seed count changed.'
    $pairId = [string]$Seed.seedSource.pairId
    $sourceRows = @($SeedSource.results | Where-Object { [string]$_.pairId -eq $pairId })
    Assert-Condition ($sourceRows.Count -eq 1) 'O3Q4 seed source cardinality changed.'
    $sourceCandidates = @($sourceRows[0].df.candidates)
    Assert-Condition ($sourceCandidates.Count -eq $ExpectedCount) 'O3Q4 source candidate count changed.'
    for ($index = 0; $index -lt $ExpectedCount; $index++) {
        $projected = $Seed.dfOnlyBoundaryCandidates[$index]
        $source = $sourceCandidates[$index]
        Assert-Condition ([int]$projected.sourceOrdinal -eq $index) "O3Q4 source ordinal changed: $index"
        Assert-Condition ([double]$projected.centerAngleDegrees -eq [double]$source.axisCenterAngleDegrees) "O3Q4 source angle changed: $index"
        Assert-Condition ([double]$projected.widthDegrees -eq [double]$source.widthDegrees) "O3Q4 source width changed: $index"
        Assert-Condition ([double]$projected.maximumDepthPx -eq [double]$source.peakDepthPx) "O3Q4 source depth changed: $index"
    }
    Assert-Condition ([int]$Seed.bf.widthPx -eq [int]$SourceRecord.bf.widthPx) 'O3Q4 BF width changed.'
    Assert-Condition ([int]$Seed.bf.heightPx -eq [int]$SourceRecord.bf.heightPx) 'O3Q4 BF height changed.'
    Assert-Condition (($Seed.bf.fit | ConvertTo-Json -Depth 8 -Compress) -ceq ($SourceRecord.bf.fit | ConvertTo-Json -Depth 8 -Compress)) 'O3Q4 BF fit changed.'
    Assert-Condition ([string]$Contract.input.bf.sha256 -eq [string]$SourceRecord.sources.bfSha256) 'O3Q4 BF hash contract changed.'
    Assert-Condition ([string]$Contract.input.df.sha256 -eq [string]$SourceRecord.sources.dfSha256) 'O3Q4 DF hash contract changed.'
    Assert-Condition ([bool]$Seed.fullPerimeterInference) 'O3Q4 full-perimeter inference changed.'
    Assert-Condition (-not [bool]$Seed.knownNotchLocationConsumed) 'O3Q4 consumed a known notch location.'
    Assert-Condition (-not [bool]$Seed.argosRotationOrientationLocationInputConsumed) 'O3Q4 consumed Argos orientation metadata.'
    Assert-Condition (-not [bool]$Seed.hotspotMembershipConsumed) 'O3Q4 consumed hotspot membership.'
    Assert-Condition (-not [bool]$Seed.backsidePixelsConsumed) 'O3Q4 consumed backside pixels.'
}

function New-TerminalResult {
    param([object]$EngineTerminal, [object]$Output, [string]$FinalOutputPath, [string]$OutputSha256, [int]$ExpectedSeeds, [bool]$IsRehearsal, [object]$OwnedChild)
    Assert-Condition ([string]$EngineTerminal.state -eq 'COMPLETE_O3P8_POST2_BF_TOPOLOGY_DF_RADIAL_REVIEW_ONLY') 'O3Q4 engine terminal state changed.'
    Assert-Condition ([int]$EngineTerminal.inputCount -eq 1) 'O3Q4 engine terminal input count changed.'
    Assert-Condition ([string]$Output.schema -eq 'argos_ocv03_o3p8_front_split_notch_result_v1') 'O3Q4 engine output schema changed.'
    Assert-Condition ([int]$Output.inputCount -eq 1 -and @($Output.rows).Count -eq 1) 'O3Q4 engine output cardinality changed.'
    Assert-Condition ([int]$Output.dfTopologyInvocationCount -eq 0) 'O3Q4 invoked DF topology.'
    $row = $Output.rows[0]
    Assert-Condition ([int]$row.seedCount -eq $ExpectedSeeds) 'O3Q4 output seed count changed.'
    Assert-Condition (-not [bool]$Output.knownNotchLocationConsumed) 'O3Q4 output consumed notch location.'
    Assert-Condition (-not [bool]$Output.scorerInputsConsumed) 'O3Q4 output consumed scorer inputs.'
    Assert-Condition (-not [bool]$Output.backsidePixelsConsumed) 'O3Q4 output consumed backside pixels.'
    Assert-Condition (-not [bool]$Output.rasterOutputCreated) 'O3Q4 created raster output.'
    Assert-Condition (-not [bool]$Output.sourceMutationPerformed) 'O3Q4 mutated source state.'
    $numericPass = ([string]$row.state -eq 'PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH' -and [int]$row.eligibleCount -eq 1 -and $null -ne $row.selected)
    return [ordered]@{
        schema = 'argos_ocv03_o3q4_endpoint_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'COMPLETE_O3Q4_NUMERIC_REVIEW_ONLY'
        revision = 'FMOCV03_O3Q4_20260828T151900Z'
        rehearsal = $IsRehearsal
        engineState = [string]$Output.state
        numericDecision = [string]$row.state
        numericIndependentPass = $numericPass
        identity = [string]$row.identity
        seedCount = [int]$row.seedCount
        eligibleCount = [int]$row.eligibleCount
        candidateLocalTopologyInsufficiencyCount = [int]$row.candidateLocalTopologyInsufficiencyCount
        selected = $row.selected
        engineOutputPath = $FinalOutputPath
        engineOutputSha256 = $OutputSha256
        numericResult = $Output
        ownedChildProcessId = if ($null -eq $OwnedChild) { $null } else { $OwnedChild.processId }
        ownedChildStartedUtc = if ($null -eq $OwnedChild) { $null } else { $OwnedChild.startedUtc }
        ownedChildTimedOut = if ($null -eq $OwnedChild) { $false } else { $OwnedChild.timedOut }
        ownedChildKilledOnTimeout = if ($null -eq $OwnedChild) { $false } else { $OwnedChild.killedOnTimeout }
        existingProcessQueryCount = 0
        taskActionCount = 0
        protectedProcessorTouched = $false
        allFrozenDfSeedsConsumed = $true
        knownNotchLocationConsumed = $false
        hotspotMembershipConsumed = $false
        argosRotationMetadataConsumed = $false
        backsidePixelsConsumed = $false
        dfTopologyInvocationCount = 0
        rasterOutputCreated = $false
        sourceMutationPerformed = $false
        sourceDeletionPerformed = $false
        providerActivated = $false
        requestRetryAuthorized = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
        productionRoutingEnabled = $false
    }
}

$manifestPath = if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { Join-Path $PSScriptRoot 'O3Q4_ENDPOINT_LIVE_INVOCATION.json' } else { [IO.Path]::GetFullPath($InvocationManifest) }
$expectedManifestSha256 = if ($Rehearsal) { Get-FileSha256 $manifestPath } else { $liveInvocationSha256 }
Assert-FilePin $manifestPath $expectedManifestSha256 'invocation manifest'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedState = if ($Rehearsal) { 'FROZEN_REHEARSAL_CONTRACT' } else { 'FROZEN_LIVE_CONTRACT' }
Assert-Condition ([string]$invocation.schema -eq 'argos_ocv03_o3q4_endpoint_invocation_v1') 'O3Q4 invocation schema changed.'
Assert-Condition ([string]$invocation.state -eq $expectedState) 'O3Q4 invocation state changed.'
Assert-Condition ($env:COMPUTERNAME.Equals([string]$invocation.expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O3Q4 wrong computer: $env:COMPUTERNAME"
Assert-Condition ([bool]$invocation.sourceImageReadAuthorized -and [bool]$invocation.detectorRerunAuthorized) 'O3Q4 image-read authority is absent.'
Assert-Condition (-not [bool]$invocation.thresholdOrAlgorithmChangeAuthorized) 'O3Q4 threshold/algorithm authority widened.'
Assert-Condition (-not [bool]$invocation.taskOrExistingProcessActionAuthorized) 'O3Q4 task/process authority widened.'
Assert-Condition (-not [bool]$invocation.providerActivationAuthorized) 'O3Q4 provider authority widened.'
Assert-Condition (-not [bool]$invocation.requestRetryAuthorized) 'O3Q4 retry authority widened.'
Assert-Condition ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3Q4 authority flags widened.'

$payloadRoot = if ([string]::IsNullOrWhiteSpace([string]$invocation.payloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath([string]$invocation.payloadRoot) }
$fileBindings = @(
    @('engine', 'engineFile', 'engineSha256'),
    @('topology', 'topologyFile', 'topologySha256'),
    @('crop', 'cropFile', 'cropSha256'),
    @('seed', 'seedFile', 'seedSha256'),
    @('seed source', 'seedSourceFile', 'seedSourceSha256'),
    @('source record', 'sourceRecordFile', 'sourceRecordSha256'),
    @('runtime gate', 'runtimeGateFile', 'runtimeGateSha256'),
    @('job contract', 'jobContractFile', 'jobContractSha256'),
    @('terminal fixture', 'terminalFixtureFile', 'terminalFixtureSha256'),
    @('config gate', 'configGateFile', 'configGateSha256')
)
$resolved = @{}
foreach ($binding in $fileBindings) {
    $path = Join-Path $payloadRoot ([string]$invocation.($binding[1]))
    Assert-FilePin $path ([string]$invocation.($binding[2])) $binding[0]
    Assert-SafePath $path
    $resolved[$binding[0]] = $path
}
$python = [IO.Path]::GetFullPath([string]$invocation.runtimePath)
$installation = [IO.Path]::GetFullPath([string]$invocation.runtimeInstallationPath)
Assert-FilePin $python ([string]$invocation.runtimeSha256) 'Python runtime'
Assert-FilePin $installation ([string]$invocation.runtimeInstallationSha256) 'runtime installation manifest'
$runtimeGate = Get-Content -LiteralPath $resolved['runtime gate'] -Raw | ConvertFrom-Json
Assert-Condition ([string]$runtimeGate.state -eq [string]$invocation.expectedRuntimeGateState) 'O3Q4 runtime-gate state changed.'
Assert-Condition ([string]$runtimeGate.opencvVersion -eq [string]$invocation.expectedOpenCvVersion) 'O3Q4 OpenCV premise changed.'
Assert-Condition ([string]$runtimeGate.numpyVersion -eq [string]$invocation.expectedNumpyVersion) 'O3Q4 NumPy premise changed.'
Assert-Condition ([string]$runtimeGate.python.sha256 -eq [string]$invocation.runtimeSha256) 'O3Q4 runtime-gate Python hash changed.'
Assert-Condition ([string]$runtimeGate.installation.sha256 -eq [string]$invocation.runtimeInstallationSha256) 'O3Q4 runtime-gate installation hash changed.'

$contract = Get-Content -LiteralPath $resolved['job contract'] -Raw | ConvertFrom-Json
$seed = Get-Content -LiteralPath $resolved['seed'] -Raw | ConvertFrom-Json
$seedSource = Get-Content -LiteralPath $resolved['seed source'] -Raw | ConvertFrom-Json
$sourceRecord = Get-Content -LiteralPath $resolved['source record'] -Raw | ConvertFrom-Json
$configGate = Get-Content -LiteralPath $resolved['config gate'] -Raw | ConvertFrom-Json
Assert-Condition ([string]$contract.schema -eq 'argos_ocv03_o3q4_job_contract_v1') 'O3Q4 job-contract schema changed.'
Assert-Condition ([int]$contract.expectedInputCount -eq 1) 'O3Q4 expected input count changed.'
Assert-Condition ([int]$contract.expectedSeedCandidateCount -eq [int]$invocation.expectedSeedCandidateCount) 'O3Q4 expected seed count changed.'
Assert-Condition ([string]$configGate.state -eq 'PASS_O3P8_DETECTOR_CONFIG_EQUIVALENCE') 'O3Q4 config-equivalence gate changed.'
Assert-SeedProjection $seed $seedSource $sourceRecord $contract ([int]$invocation.expectedSeedCandidateCount)

$sourceRoot = [IO.Path]::GetFullPath([string]$invocation.sourceRoot)
$outputRoot = [IO.Path]::GetFullPath([string]$invocation.outputRoot)
$partialRoot = $outputRoot + '.partial'
$failedRoot = $outputRoot + '.failed'
$outputParent = Split-Path -Parent $outputRoot
$alias = [string]$invocation.sourceAliasDrive
$aliasPath = $alias + '\'
$subst = Join-Path $env:SystemRoot 'System32\subst.exe'
$jobPath = Join-Path $partialRoot 'O3Q4_JOB.json'
$resultPartial = Join-Path $partialRoot 'O3Q4_RESULT.json'
$resultFinal = Join-Path $outputRoot 'O3Q4_RESULT.json'
Assert-Condition (Test-Path -LiteralPath $sourceRoot -PathType Container) 'O3Q4 source root is absent.'
Assert-Condition (Test-Path -LiteralPath $outputParent -PathType Container) 'O3Q4 output parent is absent.'
foreach ($path in @($sourceRoot, $outputRoot, $partialRoot, $failedRoot, $jobPath, $resultPartial, $resultFinal)) { Assert-SafePath $path }
foreach ($path in @($outputRoot, $partialRoot, $failedRoot)) { Assert-Condition (-not (Test-Path -LiteralPath $path)) "O3Q4 create-new output exists: $path" }
Assert-Condition (-not (Test-Path -LiteralPath $aliasPath)) 'O3Q4 source alias is already in use.'
Assert-Condition ($null -eq (Get-PSDrive -Name $alias.TrimEnd(':') -ErrorAction SilentlyContinue)) 'O3Q4 source PSDrive is already in use.'

if ($Preflight) {
    $fixture = Get-Content -LiteralPath $resolved['terminal fixture'] -Raw | ConvertFrom-Json
    Assert-Condition ([string]$fixture.schema -eq 'argos_ocv03_o3q4_terminal_gate_fixture_v1') 'O3Q4 terminal fixture changed.'
    $fixtureTerminal = New-TerminalResult $fixture.engineTerminal $fixture.engineOutput ([string]$fixture.engineTerminal.outputPath) ([string]$fixture.engineTerminal.outputSha256) ([int]$invocation.expectedSeedCandidateCount) ([bool]$Rehearsal) $null
    Assert-Condition ([string]$fixtureTerminal.state -eq [string]$fixture.expectedTerminal.state) 'O3Q4 fixture terminal state changed.'
    Assert-Condition ([bool]$fixtureTerminal.numericIndependentPass -eq [bool]$fixture.expectedTerminal.numericIndependentPass) 'O3Q4 fixture decision changed.'
    [ordered]@{
        schema = 'argos_ocv03_o3q4_endpoint_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3Q4_ENDPOINT_PREFLIGHT'
        rehearsal = [bool]$Rehearsal
        expectedNumpyVersion = [string]$invocation.expectedNumpyVersion
        seedCandidateCount = [int]$invocation.expectedSeedCandidateCount
        terminalFixturePassed = $true
        existingProcessQueryCount = 0
        sourceMetadataRead = $false
        sourceImageBytesRead = $false
        outputCreated = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

$aliasCreated = $false
$outputCommitted = $false
$ownedChild = $null
try {
    $substOutput = & $subst $alias $sourceRoot 2>&1 | Out-String
    Assert-Condition ($LASTEXITCODE -eq 0) ('O3Q4 source alias creation failed: ' + $substOutput.Trim())
    Assert-Condition (Test-Path -LiteralPath $aliasPath -PathType Container) 'O3Q4 source alias is not visible.'
    $aliasCreated = $true
    [void][IO.Directory]::CreateDirectory($partialRoot)
    $job = [ordered]@{
        schema = [string]$contract.engineJobSchema
        revision = [string]$contract.revision
        runtimeRoot = [IO.Path]::GetFullPath([string]$invocation.runtimeRoot)
        runtimeGate = [ordered]@{path = $resolved['runtime gate']; sha256 = [string]$invocation.runtimeGateSha256}
        topologyEngine = [ordered]@{path = $resolved['topology']; sha256 = [string]$invocation.topologySha256}
        cropEngine = [ordered]@{path = $resolved['crop']; sha256 = [string]$invocation.cropSha256}
        expectedOpenCvVersion = [string]$invocation.expectedOpenCvVersion
        expectedNumpyVersion = [string]$invocation.expectedNumpyVersion
        channelMethods = $contract.channelMethods
        crop = $contract.crop
        topologyConfig = $contract.topologyConfig
        corroboration = $contract.corroboration
        candidateLocalTopologyErrors = @($contract.candidateLocalTopologyErrors)
        outputPath = $resultPartial
        expectedInputCount = 1
        inputs = @([ordered]@{identity=[string]$contract.input.identity;r6SeedResult=[ordered]@{path=$resolved['seed'];sha256=[string]$invocation.seedSha256};bf=$contract.input.bf;df=$contract.input.df})
        knownNotchLocationConsumed = $false
        notchAnglePriorConsumed = $false
        fixedAngularSearchWindowConsumed = $false
        scorerInputsPresent = $false
        sourceMutationAllowed = $false
        rasterOutputAllowed = $false
        liveProviderActivation = $false
        backsidePixelsConsumed = $false
        dfTopologyInvocationAllowed = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
        productionRoutingEnabled = $false
    }
    Write-NewJson $jobPath $job 32
    $ownedChild = Invoke-OwnedPython $python $resolved['engine'] $jobPath ([IO.Path]::GetFullPath([string]$invocation.pythonModuleRoot)) ([int]$invocation.pythonChildTimeoutSeconds) ([int]$invocation.maximumStdoutBytes)
    Assert-Condition ([int]$ownedChild.exitCode -eq 0) ('O3Q4 engine failed: ' + $ownedChild.stderr.Trim())
    $engineTerminal = $ownedChild.stdout.Trim() | ConvertFrom-Json
    Assert-FilePin $resultPartial ([string]$engineTerminal.outputSha256) 'engine output'
    $output = Get-Content -LiteralPath $resultPartial -Raw | ConvertFrom-Json
    $terminal = New-TerminalResult $engineTerminal $output $resultFinal ([string]$engineTerminal.outputSha256) ([int]$invocation.expectedSeedCandidateCount) ([bool]$Rehearsal) $ownedChild
    Move-Item -LiteralPath $partialRoot -Destination $outputRoot
    $outputCommitted = $true
    Assert-FilePin $resultFinal ([string]$engineTerminal.outputSha256) 'committed engine output'
}
catch {
    if ($outputCommitted -and (Test-Path -LiteralPath $outputRoot) -and -not (Test-Path -LiteralPath $failedRoot)) {
        Move-Item -LiteralPath $outputRoot -Destination $failedRoot -ErrorAction SilentlyContinue
    }
    elseif (Test-Path -LiteralPath $partialRoot) {
        Move-Item -LiteralPath $partialRoot -Destination $failedRoot -ErrorAction SilentlyContinue
    }
    throw
}
finally {
    if ($aliasCreated) {
        $removeOutput = & $subst $alias /D 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $aliasPath) -or $null -ne (Get-PSDrive -Name $alias.TrimEnd(':') -ErrorAction SilentlyContinue)) {
            throw ('O3Q4 source alias removal failed: ' + $removeOutput.Trim())
        }
    }
}
$terminal.sourceAliasRemoved = $true
$terminal | ConvertTo-Json -Depth 64
