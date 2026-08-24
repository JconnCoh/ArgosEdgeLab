[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = $PSScriptRoot,
    [string]$RuntimeRoot = 'D:\AFCV1\rt',
    [string]$WorkRoot = 'D:\A2\w\ocv\O2D1',
    [string]$OutputRoot = 'D:\A2\o\ocv\O2D1',
    [string]$RehearsalJobPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-Sha256([string]$LiteralPath) {
    $stream = [IO.File]::OpenRead($LiteralPath)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Assert-File([string]$LiteralPath, [string]$ExpectedSha256) {
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { throw "O2D1 required file is missing: $LiteralPath" }
    if ((Get-Sha256 $LiteralPath) -ne $ExpectedSha256) { throw "O2D1 required file changed: $LiteralPath" }
}

function Invoke-BoundedPython(
    [string]$PythonPath,
    [string]$EnginePath,
    [string]$JobPath,
    [string]$ResultPath,
    [int]$TimeoutMilliseconds
) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $PythonPath
    $start.Arguments = '"' + $EnginePath + '" --job "' + $JobPath + '" --result "' + $ResultPath + '"'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'O2D1 portable Python process did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMilliseconds)) {
        try { $process.Kill() } catch { }
        throw "O2D1 portable Python process exceeded $TimeoutMilliseconds milliseconds."
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
    $process.Dispose()
    return [pscustomobject]@{ ExitCode = $exitCode; Stdout = $stdout; Stderr = $stderr }
}

$engineSource = Join-Path $PayloadRoot 'ArgosOpenCvScribeV1.py'
$referenceBundle = Join-Path $PayloadRoot 'O2D1_REFS.zip'
$jobSource = if ($Rehearsal -and -not [string]::IsNullOrWhiteSpace($RehearsalJobPath)) { $RehearsalJobPath } else { Join-Path $PayloadRoot 'O2D1_SLOT16_JOB.json' }
$pythonPath = Join-Path $RuntimeRoot 'python.exe'
$installationPath = 'D:\AFCV1\INSTALLATION.json'
$engineSha256 = '0756EC2FA9279AA7AF915BC3F6D8B2810AC1268A64FC626233FAFE3DC5DDB53D'
$referenceBundleSha256 = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$liveJobSha256 = '3056646A019D155908A125503E17E024FD0DA74AB744CB2F31502197AE14BD9B'
$installationSha256 = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$workPartial = $WorkRoot + '.partial'
$workFailed = $WorkRoot + '.failed'
$resultPath = Join-Path $OutputRoot 'RESULT.json'
$runGatePath = Join-Path $OutputRoot 'RUN_GATE.json'

Assert-File $engineSource $engineSha256
Assert-File $referenceBundle $referenceBundleSha256
if ($Rehearsal) {
    if (-not (Test-Path -LiteralPath $jobSource -PathType Leaf)) { throw 'O2D1 rehearsal job is missing.' }
} else {
    Assert-File $jobSource $liveJobSha256
    Assert-File $installationPath $installationSha256
}
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) { throw "O2D1 portable Python runtime is missing: $pythonPath" }
$pythonCommand = Get-Command -Name $pythonPath -CommandType Application -ErrorAction Stop
if (-not [IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($pythonPath), [StringComparison]::OrdinalIgnoreCase)) { throw 'O2D1 resolved Python runtime changed.' }
$job = Get-Content -Raw -LiteralPath $jobSource | ConvertFrom-Json
if ([string]$job.schema -ne 'argos_opencv_scribe_job_v1' -or -not [bool]$job.authority.reviewOnly -or [bool]$job.authority.automaticIdentityAuthority -or [bool]$job.authority.trainingEligible -or [bool]$job.authority.xmlEligible -or [bool]$job.authority.productionEligible -or [bool]$job.authority.mayClearHolds -or -not [bool]$job.search.boundedExceptionSearch) { throw 'O2D1 job authority or search contract changed.' }
if (-not $Rehearsal) {
    if ([string]$job.identity.lotId -ne '62619-433' -or [string]$job.identity.slotId -ne 'Slot16' -or @($job.search.expectedRegions).Count -ne 0 -or [string]$job.outputRoot -ne $OutputRoot) { throw 'O2D1 live job identity or output contract changed.' }
}
foreach ($path in @($WorkRoot, $workPartial, $workFailed, $OutputRoot, $resultPath, $runGatePath)) {
    if (Test-Path -LiteralPath $path) { throw "O2D1 create-new target already exists: $path" }
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d1_endpoint_preflight_v1'
        state = 'PASS_O2D1_ENDPOINT_PREFLIGHT'
        rehearsal = [bool]$Rehearsal
        runtimeExecutable = $pythonPath
        engineSha256 = $engineSha256
        referenceBundleSha256 = $referenceBundleSha256
        jobSha256 = Get-Sha256 $jobSource
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        boundedExceptionSearch = $true
        expectedRegionCount = @($job.search.expectedRegions).Count
        sourceImageBytesRead = $false
        imagePixelsDecoded = $false
        processStarted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionEligible = $false
    } | ConvertTo-Json -Depth 6
    return
}

try {
    [void](New-Item -ItemType Directory -Path $workPartial -Force)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($referenceBundle, $workPartial)
    $enginePath = Join-Path $workPartial 'ArgosOpenCvScribeV1.py'
    $jobPath = Join-Path $workPartial 'JOB.json'
    Copy-Item -LiteralPath $engineSource -Destination $enginePath -ErrorAction Stop
    Copy-Item -LiteralPath $jobSource -Destination $jobPath -ErrorAction Stop
    if ((Get-Sha256 $enginePath) -ne $engineSha256 -or (Get-Sha256 $jobPath) -ne (Get-Sha256 $jobSource)) { throw 'O2D1 staged engine or job changed.' }
    Move-Item -LiteralPath $workPartial -Destination $WorkRoot -ErrorAction Stop
    $enginePath = Join-Path $WorkRoot 'ArgosOpenCvScribeV1.py'
    $jobPath = Join-Path $WorkRoot 'JOB.json'
    $invocation = Invoke-BoundedPython -PythonPath $pythonPath -EnginePath $enginePath -JobPath $jobPath -ResultPath $resultPath -TimeoutMilliseconds 1800000
    if ($invocation.ExitCode -ne 0) { throw ('O2D1 provider failed with exit ' + $invocation.ExitCode + ': ' + $invocation.Stderr.Trim()) }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'O2D1 provider result is missing.' }
    $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    if ([string]$result.schema -ne 'argos_opencv_scribe_result_v1' -or [string]$result.revision -ne 'ARGOS_OPENCV_SCRIBE_V1_20260824' -or [string]$result.jobId -ne [string]$job.jobId -or [bool]$result.eligibleIdentity -or -not [bool]$result.authority.reviewOnly -or [bool]$result.authority.automaticIdentityAuthority -or [bool]$result.authority.trainingEligible -or [bool]$result.authority.xmlEligible -or [bool]$result.authority.productionEligible -or [bool]$result.authority.mayClearHolds) { throw 'O2D1 provider result authority contract changed.' }
    if ([string]$result.provenance.references.manifestSha256 -ne 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229' -or [int]$result.provenance.references.referenceCount -ne 456 -or [string]$result.provenance.references.missingBodyReferenceLabels -ne 'IJKOQVWXYZ' -or -not [bool]$result.provenance.bfDfIndependent -or -not [bool]$result.provenance.boundedExceptionSearchUsed -or [bool]$result.provenance.fixedImageRectangleUsed) { throw 'O2D1 result provenance contract changed.' }
    $candidateRows = @($result.candidates | ForEach-Object { [ordered]@{ string = [string]$_.string; directImageFirstSupport = [bool]$_.directImageFirstSupport; channels = @($_.channels); polarities = @($_.polarities); maximumScore = [double]$_.maximumScore } })
    $gate = [ordered]@{
        schema = 'argos_o2d1_opencv_scribe_development_gate_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D1_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED'
        disposition = 'PENDING_GATE'
        rehearsal = [bool]$Rehearsal
        lotId = [string]$job.identity.lotId
        acquisitionId = [string]$job.identity.acquisitionId
        slotId = [string]$job.identity.slotId
        engineSha256 = $engineSha256
        jobSha256 = Get-Sha256 $jobPath
        referenceBundleSha256 = $referenceBundleSha256
        referenceManifestSha256 = [string]$result.provenance.references.manifestSha256
        resultPath = $resultPath
        resultSha256 = Get-Sha256 $resultPath
        resultState = [string]$result.state
        imageFirstString = [string]$result.imageFirstString
        checksumState = [string]$result.checksumState
        localization = $result.localization
        candidates = $candidateRows
        holds = @($result.holds)
        inputProvenance = $result.provenance.sources
        referenceCoverageComplete = [bool]$result.provenance.references.referenceCoverageComplete
        missingReferenceLabels = [string]$result.provenance.references.missingBodyReferenceLabels
        boundedExceptionSearchUsed = [bool]$result.provenance.boundedExceptionSearchUsed
        fixedImageRectangleUsed = [bool]$result.provenance.fixedImageRectangleUsed
        inspectionTasksChanged = $false
        processorTaskChanged = $false
        sourceMutationPerformed = $false
        sourceDeletionPerformed = $false
        waferActionPerformed = $false
        holdsCleared = $false
        providerActivated = $false
        reviewOnly = $true
        productionEligible = $false
    }
    [IO.File]::WriteAllText($runGatePath, (($gate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    $gate | ConvertTo-Json -Depth 12 -Compress
} catch {
    if (Test-Path -LiteralPath $workPartial) {
        if (-not (Test-Path -LiteralPath $workFailed)) { Move-Item -LiteralPath $workPartial -Destination $workFailed -ErrorAction SilentlyContinue }
    }
    [ordered]@{
        schema = 'argos_o2d1_endpoint_failure_v1'
        state = 'HOLD_O2D1_OPENCV_SCRIBE_ENDPOINT_ERROR'
        errorType = $_.Exception.GetType().FullName
        detail = $_.Exception.Message
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        inspectionTasksChanged = $false
        processorTaskChanged = $false
        sourceDeletionPerformed = $false
        waferActionPerformed = $false
        reviewOnly = $true
        productionEligible = $false
    } | ConvertTo-Json -Depth 6 -Compress | Write-Error
    throw
}
