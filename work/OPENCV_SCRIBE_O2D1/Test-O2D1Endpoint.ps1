[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Get-Sha256([string]$LiteralPath) { return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash }

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$endpoint = Join-Path $root 'Invoke-O2D1ScribeEndpoint.ps1'
$jobPath = Join-Path $root 'O2D1_REHEARSAL_JOB.json'
$runtimeRoot = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$sourceRoot = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\diagnostics\SCRIBE_READER_FAILURE_DIAGNOSTIC_V1_20260806T201825Z\62631-535_20260730105033_Slot16'
$inputRoot = 'C:\O2D1I'
$normalRoot = 'C:\O2D1T'
$failureRoot = 'C:\O2D1F'
$gatePath = Join-Path $root 'O2D1_ENTRYPOINT_TEST_GATE.json'
$bfName = 'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$dfName = 'DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$bfSha = '094353365C010DA2C1AB67EBAE1097D3F783E80379BBB585D1F4B531C29EA2EE'
$dfSha = '79232E8A8FAC6634048CFE9EDAFF34467EBF21BEACC55A47E2B3CAA91B82426C'

foreach ($path in @($endpoint, $jobPath, (Join-Path $runtimeRoot 'python.exe'), (Join-Path $root 'O2D1_REFS.zip'))) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "O2D1 test dependency is missing: $path" }
}
foreach ($path in @($inputRoot, $normalRoot, $failureRoot, $gatePath)) {
    if (Test-Path -LiteralPath $path) { throw "O2D1 test create-new target already exists: $path" }
}
$tokens = $null
$errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($endpoint, [ref]$tokens, [ref]$errors)
if (@($errors).Count -ne 0) { throw 'O2D1 endpoint does not parse under Windows PowerShell 5.1.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d1_entrypoint_test_preflight_v1'
        state = 'PASS_O2D1_ENTRYPOINT_TEST_PREFLIGHT'
        endpointSha256 = Get-Sha256 $endpoint
        rehearsalJobSha256 = Get-Sha256 $jobPath
        runtimePythonPath = Join-Path $runtimeRoot 'python.exe'
        sourceAliasAnchor = $sourceRoot
        sourceAliasName = 'Q'
        inputRoot = $inputRoot
        normalRoot = $normalRoot
        injectedFailureRoot = $failureRoot
        mutationsPerformed = $false
        processStarted = $false
        reviewOnly = $true
        productionEligible = $false
    } | ConvertTo-Json -Depth 5
    return
}

$driveCreated = $false
try {
    if ($null -ne (Get-PSDrive -Name Q -ErrorAction SilentlyContinue)) { throw 'O2D1 process-local source alias Q: is already in use.' }
    [void](New-PSDrive -Name Q -PSProvider FileSystem -Root $sourceRoot -Scope Script -ErrorAction Stop)
    $driveCreated = $true
    [void](New-Item -ItemType Directory -Path $inputRoot)
    Copy-Item -LiteralPath ('Q:\' + $bfName) -Destination (Join-Path $inputRoot 'BF.png') -ErrorAction Stop
    Copy-Item -LiteralPath ('Q:\' + $dfName) -Destination (Join-Path $inputRoot 'DF.png') -ErrorAction Stop
    if ((Get-Sha256 (Join-Path $inputRoot 'BF.png')) -ne $bfSha -or (Get-Sha256 (Join-Path $inputRoot 'DF.png')) -ne $dfSha) { throw 'O2D1 short staged rehearsal input changed.' }

    $preflightText = & $endpoint -Preflight -Rehearsal -PayloadRoot $root -RuntimeRoot $runtimeRoot -WorkRoot (Join-Path $normalRoot 'w') -OutputRoot (Join-Path $normalRoot 'o') -RehearsalJobPath $jobPath | Out-String
    $endpointPreflight = $preflightText | ConvertFrom-Json
    if ([string]$endpointPreflight.state -ne 'PASS_O2D1_ENDPOINT_PREFLIGHT' -or [bool]$endpointPreflight.mutationsPerformed -or [bool]$endpointPreflight.processStarted) { throw 'O2D1 exact endpoint preflight contract changed.' }

    $normalText = & $endpoint -Rehearsal -PayloadRoot $root -RuntimeRoot $runtimeRoot -WorkRoot (Join-Path $normalRoot 'w') -OutputRoot (Join-Path $normalRoot 'o') -RehearsalJobPath $jobPath | Out-String
    $normal = $normalText | ConvertFrom-Json
    if ([string]$normal.state -ne 'PASS_O2D1_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED' -or -not [bool]$normal.rehearsal -or [string]$normal.resultState -ne 'SCRIBE_REFERENCE_COVERAGE_HOLD' -or [string]$normal.imageFirstString -ne '0438S004FEH0' -or [bool]$normal.referenceCoverageComplete -or [string]$normal.missingReferenceLabels -ne 'IJKOQVWXYZ' -or [bool]$normal.inspectionTasksChanged -or [bool]$normal.processorTaskChanged -or [bool]$normal.sourceMutationPerformed -or [bool]$normal.sourceDeletionPerformed -or [bool]$normal.waferActionPerformed -or [bool]$normal.holdsCleared -or [bool]$normal.providerActivated -or [bool]$normal.productionEligible) { throw 'O2D1 normal rehearsal terminal contract changed.' }

    [void](New-Item -ItemType Directory -Path $failureRoot)
    $badJobPath = Join-Path $failureRoot 'BAD_JOB.json'
    $badJob = Get-Content -Raw -LiteralPath $jobPath | ConvertFrom-Json
    $badJob.inputs.bf.sha256 = '0000000000000000000000000000000000000000000000000000000000000000'
    $badJob.references.manifestPath = 'C:\O2D1F\w\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $badJob.references.roots[0].path = 'C:\O2D1F\w\refs\glyphs'
    $badJob.references.roots[1].path = 'C:\O2D1F\w\refs\glyphs_v5_confirmed_20260806'
    $badJob.outputRoot = 'C:\O2D1F\o'
    [IO.File]::WriteAllText($badJobPath, (($badJob | ConvertTo-Json -Depth 16) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    $injectedFailureCaught = $false
    try {
        & $endpoint -Rehearsal -PayloadRoot $root -RuntimeRoot $runtimeRoot -WorkRoot (Join-Path $failureRoot 'w') -OutputRoot (Join-Path $failureRoot 'o') -RehearsalJobPath $badJobPath 2>&1 | Out-Null
    } catch {
        if ($_.Exception.Message -match 'Source SHA-256 mismatch|provider failed with exit') { $injectedFailureCaught = $true }
    }
    if (-not $injectedFailureCaught -or (Test-Path -LiteralPath (Join-Path $failureRoot 'o\RESULT.json'))) { throw 'O2D1 injected provenance failure did not fail closed.' }

    $gate = [ordered]@{
        schema = 'argos_o2d1_entrypoint_test_gate_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D1_ENTRYPOINT_TEST_GATE'
        endpointSha256 = Get-Sha256 $endpoint
        rehearsalJobSha256 = Get-Sha256 $jobPath
        referenceBundleSha256 = Get-Sha256 (Join-Path $root 'O2D1_REFS.zip')
        runtimePythonSha256 = Get-Sha256 (Join-Path $runtimeRoot 'python.exe')
        sourceAliasAnchor = $sourceRoot
        sourceAliasName = 'Q'
        sourceAliasRemoved = $false
        normalResultState = [string]$normal.resultState
        normalImageFirstString = [string]$normal.imageFirstString
        normalReferenceCoverageHoldPreserved = [string]$normal.resultState -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD'
        normalResultSha256 = [string]$normal.resultSha256
        injectedSourceHashMismatchFailedClosed = $injectedFailureCaught
        injectedFailureResultAbsent = -not (Test-Path -LiteralPath (Join-Path $failureRoot 'o\RESULT.json'))
        inspectionTasksChanged = $false
        processorTaskChanged = $false
        sourceDeletionPerformed = $false
        waferActionPerformed = $false
        holdsCleared = $false
        providerActivated = $false
        reviewOnly = $true
        productionEligible = $false
    }
    [IO.File]::WriteAllText($gatePath, (($gate | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    $gate | ConvertTo-Json -Depth 8
} finally {
    if ($driveCreated) { Remove-PSDrive -Name Q -Scope Script -Force -ErrorAction Stop }
}
