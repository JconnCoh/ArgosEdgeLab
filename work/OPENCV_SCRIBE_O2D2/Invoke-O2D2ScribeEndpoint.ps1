[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = $PSScriptRoot,
    [string]$RuntimeRoot = 'D:\AFCV1\rt',
    [string]$WorkRoot = 'D:\A2\w\ocv\O2D2',
    [string]$OutputRoot = 'D:\A2\o\ocv\O2D2',
    [string]$SourceAliasRoot = 'D:\KLARFExport\PatternedFront\Lot_62619-433',
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
    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) { throw "O2D2 required file is missing: $LiteralPath" }
    if ((Get-Sha256 $LiteralPath) -ne $ExpectedSha256) { throw "O2D2 required file changed: $LiteralPath" }
}
function Invoke-BoundedPython([string]$PythonPath, [string]$EnginePath, [string]$JobPath, [string]$ResultPath, [int]$TimeoutMilliseconds) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $PythonPath
    $start.Arguments = '"' + $EnginePath + '" --job "' + $JobPath + '" --result "' + $ResultPath + '"'
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    if (-not $process.Start()) { throw 'O2D2 portable Python process did not start.' }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMilliseconds)) {
        try { $process.Kill() } catch { }
        throw "O2D2 portable Python process exceeded $TimeoutMilliseconds milliseconds."
    }
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
    $process.Dispose()
    return [pscustomobject]@{ExitCode=$exitCode;Stdout=$stdout;Stderr=$stderr}
}

$engineSource = Join-Path $PayloadRoot 'ArgosOpenCvScribeV1.py'
$referenceBundle = Join-Path $PayloadRoot 'O2D2_REFS.zip'
$jobSource = if ($Rehearsal -and -not [string]::IsNullOrWhiteSpace($RehearsalJobPath)) { $RehearsalJobPath } else { Join-Path $PayloadRoot 'O2D2_SLOT16_JOB.json' }
$pythonPath = Join-Path $RuntimeRoot 'python.exe'
$substPath = Join-Path $env:SystemRoot 'System32\subst.exe'
$installationPath = 'D:\AFCV1\INSTALLATION.json'
$engineSha256 = '3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'
$referenceBundleSha256 = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$liveJobSha256 = '7E908B95911BD6741FC6AA6C65E839F5D28243D4631D593A09EC243D94A08E8B'
$installationSha256 = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$aliasName = 'X:'
$aliasPath = 'X:\'
$workPartial = $WorkRoot + '.partial'
$workFailed = $WorkRoot + '.failed'
$resultPath = Join-Path $OutputRoot 'RESULT.json'
$runGatePath = Join-Path $OutputRoot 'RUN_GATE.json'

Assert-File $engineSource $engineSha256
Assert-File $referenceBundle $referenceBundleSha256
if ($Rehearsal) {
    if (-not (Test-Path -LiteralPath $jobSource -PathType Leaf)) { throw 'O2D2 rehearsal job is missing.' }
} else {
    Assert-File $jobSource $liveJobSha256
    Assert-File $installationPath $installationSha256
}
if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) { throw "O2D2 portable Python runtime is missing: $pythonPath" }
if (-not (Test-Path -LiteralPath $substPath -PathType Leaf)) { throw 'O2D2 subst.exe is missing.' }
if (-not (Test-Path -LiteralPath $SourceAliasRoot -PathType Container)) { throw "O2D2 source alias anchor is missing: $SourceAliasRoot" }
$pythonCommand = Get-Command -Name $pythonPath -CommandType Application -ErrorAction Stop
$substCommand = Get-Command -Name $substPath -CommandType Application -ErrorAction Stop
if (-not [IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($pythonPath), [StringComparison]::OrdinalIgnoreCase) -or -not [IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($substPath), [StringComparison]::OrdinalIgnoreCase)) { throw 'O2D2 resolved executable changed.' }
if ((Test-Path -LiteralPath $aliasPath) -or $null -ne (Get-PSDrive -Name X -ErrorAction SilentlyContinue)) { throw 'O2D2 source alias X: is already in use.' }
$job = Get-Content -Raw -LiteralPath $jobSource | ConvertFrom-Json
if ([string]$job.schema -ne 'argos_opencv_scribe_job_v1' -or -not [bool]$job.authority.reviewOnly -or [bool]$job.authority.automaticIdentityAuthority -or [bool]$job.authority.trainingEligible -or [bool]$job.authority.xmlEligible -or [bool]$job.authority.productionEligible -or [bool]$job.authority.mayClearHolds -or -not [bool]$job.search.boundedExceptionSearch) { throw 'O2D2 job authority or search contract changed.' }
foreach ($channel in @('bf','df')) {
    $source = $job.inputs.$channel
    if ([string]$source.ioPathClass -ne 'SHORT_DOS_DEVICE_ALIAS' -or [string]$source.aliasName -ne $aliasName -or [string]$source.aliasAnchorCanonicalPath -ne $SourceAliasRoot -or -not ([string]$source.path).StartsWith($aliasPath, [StringComparison]::OrdinalIgnoreCase) -or -not ([string]$source.canonicalProvenancePath).StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase)) { throw "O2D2 source alias contract changed: $channel" }
}
if (-not $Rehearsal) {
    if ([string]$job.identity.lotId -ne '62619-433' -or [string]$job.identity.slotId -ne 'Slot16' -or @($job.search.expectedRegions).Count -ne 0 -or [string]$job.outputRoot -ne $OutputRoot) { throw 'O2D2 live job identity or output contract changed.' }
}
foreach ($path in @($WorkRoot,$workPartial,$workFailed,$OutputRoot,$resultPath,$runGatePath)) { if (Test-Path -LiteralPath $path) { throw "O2D2 create-new target exists: $path" } }

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d2_endpoint_preflight_v1';state='PASS_O2D2_ENDPOINT_PREFLIGHT';rehearsal=[bool]$Rehearsal
        runtimeExecutable=$pythonPath;substExecutable=$substPath;engineSha256=$engineSha256;referenceBundleSha256=$referenceBundleSha256
        jobSha256=Get-Sha256 $jobSource;workRoot=$WorkRoot;outputRoot=$OutputRoot;sourceAliasName=$aliasName;sourceAliasRoot=$SourceAliasRoot
        sourceAliasPresentBefore=$false;sourceImageBytesRead=$false;imagePixelsDecoded=$false;processStarted=$false;mutationsPerformed=$false
        reviewOnly=$true;productionEligible=$false
    } | ConvertTo-Json -Depth 6
    return
}

$aliasCreated = $false
$caught = $null
$result = $null
try {
    [void](New-Item -ItemType Directory -Path $workPartial -Force)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($referenceBundle, $workPartial)
    $enginePath = Join-Path $workPartial 'ArgosOpenCvScribeV1.py'
    $jobPath = Join-Path $workPartial 'JOB.json'
    Copy-Item -LiteralPath $engineSource -Destination $enginePath -ErrorAction Stop
    Copy-Item -LiteralPath $jobSource -Destination $jobPath -ErrorAction Stop
    if ((Get-Sha256 $enginePath) -ne $engineSha256 -or (Get-Sha256 $jobPath) -ne (Get-Sha256 $jobSource)) { throw 'O2D2 staged engine or job changed.' }
    Move-Item -LiteralPath $workPartial -Destination $WorkRoot -ErrorAction Stop
    $enginePath = Join-Path $WorkRoot 'ArgosOpenCvScribeV1.py'
    $jobPath = Join-Path $WorkRoot 'JOB.json'
    $aliasOutput = & $substPath $aliasName $SourceAliasRoot 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $aliasPath -PathType Container)) { throw ('O2D2 source alias creation failed: ' + $aliasOutput.Trim()) }
    $aliasCreated = $true
    $aliasEvidence = (& $substPath $aliasName 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0 -or $aliasEvidence.IndexOf($SourceAliasRoot, [StringComparison]::OrdinalIgnoreCase) -lt 0) { throw 'O2D2 source alias target verification failed.' }
    $invocation = Invoke-BoundedPython -PythonPath $pythonPath -EnginePath $enginePath -JobPath $jobPath -ResultPath $resultPath -TimeoutMilliseconds 1800000
    if ($invocation.ExitCode -ne 0) { throw ('O2D2 provider failed with exit ' + $invocation.ExitCode + ': ' + $invocation.Stderr.Trim()) }
    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) { throw 'O2D2 provider result is missing.' }
    $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    if ([string]$result.schema -ne 'argos_opencv_scribe_result_v1' -or [string]$result.revision -ne 'ARGOS_OPENCV_SCRIBE_V1R2_20260824' -or [bool]$result.eligibleIdentity -or -not [bool]$result.authority.reviewOnly -or [bool]$result.authority.automaticIdentityAuthority -or [bool]$result.authority.productionEligible -or [bool]$result.authority.mayClearHolds) { throw 'O2D2 provider result authority contract changed.' }
    foreach ($channel in @('bf','df')) {
        $sourceEvidence = $result.provenance.sources.$channel
        if ([string]$sourceEvidence.ioPathClass -ne 'SHORT_DOS_DEVICE_ALIAS' -or [string]$sourceEvidence.aliasName -ne $aliasName -or [string]$sourceEvidence.aliasAnchorCanonicalPath -ne $SourceAliasRoot -or [string]::IsNullOrWhiteSpace([string]$sourceEvidence.canonicalProvenancePath)) { throw "O2D2 result source provenance changed: $channel" }
    }
    if ([int]$result.provenance.references.referenceCount -ne 456 -or [string]$result.provenance.references.missingBodyReferenceLabels -ne 'IJKOQVWXYZ' -or -not [bool]$result.provenance.bfDfIndependent -or -not [bool]$result.provenance.boundedExceptionSearchUsed -or [bool]$result.provenance.fixedImageRectangleUsed) { throw 'O2D2 result provider provenance changed.' }
} catch {
    $caught = $_
} finally {
    if ($aliasCreated) {
        $removeOutput = & $substPath $aliasName '/D' 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -and $null -eq $caught) { $caught = New-Object Management.Automation.ErrorRecord((New-Object InvalidOperationException('O2D2 source alias removal failed: ' + $removeOutput.Trim())), 'O2D2AliasRemoval', [Management.Automation.ErrorCategory]::InvalidOperation, $aliasName) }
    }
}
$aliasRemoved = -not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name X -ErrorAction SilentlyContinue)
if (-not $aliasRemoved -and $null -eq $caught) { $caught = New-Object Management.Automation.ErrorRecord((New-Object InvalidOperationException('O2D2 source alias remains after provider exit.')), 'O2D2AliasStillPresent', [Management.Automation.ErrorCategory]::InvalidOperation, $aliasName) }
if ($null -ne $caught) {
    if (Test-Path -LiteralPath $workPartial) { if (-not (Test-Path -LiteralPath $workFailed)) { Move-Item -LiteralPath $workPartial -Destination $workFailed -ErrorAction SilentlyContinue } }
    [ordered]@{schema='argos_o2d2_endpoint_failure_v1';state='HOLD_O2D2_OPENCV_SCRIBE_ENDPOINT_ERROR';detail=$caught.Exception.Message;sourceAliasName=$aliasName;sourceAliasRemoved=$aliasRemoved;inspectionTasksChanged=$false;processorTaskChanged=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;reviewOnly=$true;productionEligible=$false} | ConvertTo-Json -Depth 6 -Compress | Write-Error
    throw $caught
}

$candidateRows = @($result.candidates | ForEach-Object { [ordered]@{string=[string]$_.string;directImageFirstSupport=[bool]$_.directImageFirstSupport;channels=@($_.channels);polarities=@($_.polarities);maximumScore=[double]$_.maximumScore} })
$gate = [ordered]@{
    schema='argos_o2d2_opencv_scribe_development_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D2_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';disposition='PENDING_GATE';rehearsal=[bool]$Rehearsal
    lotId=[string]$job.identity.lotId;acquisitionId=[string]$job.identity.acquisitionId;slotId=[string]$job.identity.slotId
    engineSha256=$engineSha256;jobSha256=Get-Sha256 $jobPath;referenceBundleSha256=$referenceBundleSha256;resultPath=$resultPath;resultSha256=Get-Sha256 $resultPath
    resultState=[string]$result.state;imageFirstString=[string]$result.imageFirstString;checksumState=[string]$result.checksumState;localization=$result.localization;candidates=$candidateRows;holds=@($result.holds);inputProvenance=$result.provenance.sources
    sourceAliasName=$aliasName;sourceAliasRoot=$SourceAliasRoot;sourceAliasCreated=$true;sourceAliasTargetVerified=$true;sourceAliasRemoved=$true
    referenceCoverageComplete=[bool]$result.provenance.references.referenceCoverageComplete;missingReferenceLabels=[string]$result.provenance.references.missingBodyReferenceLabels
    boundedExceptionSearchUsed=[bool]$result.provenance.boundedExceptionSearchUsed;fixedImageRectangleUsed=[bool]$result.provenance.fixedImageRectangleUsed
    inspectionTasksChanged=$false;processorTaskChanged=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false
}
[IO.File]::WriteAllText($runGatePath, (($gate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$gate | ConvertTo-Json -Depth 12 -Compress
