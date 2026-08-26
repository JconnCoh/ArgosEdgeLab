#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = $PSScriptRoot,
    [string]$RuntimeRoot = 'D:\AFCV1\rt',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$WorkRoot = 'D:\A2\w\ocv\O2D6_20260826T012455503Z_D6F9980F',
    [string]$OutputRoot = 'D:\A2\o\ocv\O2D6_20260826T012455503Z_D6F9980F',
    [string]$RehearsalJobPath = '',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'O2D6_20260826T012455503Z_D6F9980F'
$engineRevision = 'ARGOS_OPENCV_SCRIBE_V1R3_20260825'
$engineSha = '8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB'
$jobSha = '527597AE7A9B7D66447289458C429218D1C8CCA8BF84839058487D2DC4B1C0DF'
$refsSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$proposalSha = 'C57380C95187610807C6BCE5C32A88E3A5F49E446C2D0C58B9B3CF855B115A0F'
$summarySha = 'FDC869DD292A15D69B9BFAAE0F077A799E535F5BE4A4614A14DE1148F91B059E'
$bfSha = '5F4E99C88FF42293AFDC7D3A2F9110C12262C4C3707055B99B054EFC603E541C'
$dfSha = 'B6C059B35AC64DD7B8D3FBB72388A60680B014E286901CAEB956880F989D86D1'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($parts.Count) { [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) } else { 0 }
    Assert-True (($full.Length + $Reserve) -lt 200) "O2D6 unsafe effective path: $full"
    Assert-True ($longest -le 80) "O2D6 unsafe component: $full"
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D6 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Get-ProcessorRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Invoke-AllWaferProcessorV2.ps1*' } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{ processId=[uint32]$_.ProcessId; creationDate=[string]$_.CreationDate; commandLine=[string]$_.CommandLine } })
}
function Invoke-BoundedPython([string]$Python, [string]$Engine, [string]$Job, [string]$Result) {
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $startInfo.Arguments = '"' + $Engine + '" --job "' + $Job + '" --result "' + $Result + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-True ($process.Start()) 'O2D6 Python did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(600000)) {
        try { $process.Kill() } catch {}
        throw 'O2D6 Python exceeded 600000 milliseconds.'
    }
    $result = [pscustomobject]@{ exitCode=$process.ExitCode; stdout=$stdoutTask.Result; stderr=$stderrTask.Result }
    $process.Dispose()
    return $result
}

$engineSource = Join-Path $PayloadRoot 'ArgosOpenCvScribeV1R3.py'
$jobSource = if ($Rehearsal -and -not [string]::IsNullOrWhiteSpace($RehearsalJobPath)) { $RehearsalJobPath } else { Join-Path $PayloadRoot 'O2D6_SLOT16_JOB.json' }
$python = Join-Path $RuntimeRoot 'python.exe'
$installation = 'D:\AFCV1\INSTALLATION.json'
$partial = $WorkRoot + '.partial'
$failed = $WorkRoot + '.failed'
$resultPath = Join-Path $OutputRoot 'RESULT.json'
$gatePath = Join-Path $OutputRoot 'RUN_GATE.json'
$executionPath = Join-Path $OutputRoot 'EXECUTION.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

Assert-True ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O2D6 wrong computer: $($env:COMPUTERNAME)"
foreach ($path in @($engineSource, $jobSource, $python, $ReferenceBundlePath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D6 dependency absent: $path"
    Assert-PathBudget $path 32
}
Assert-True ((Get-Sha256 $engineSource) -eq $engineSha) 'O2D6 engine changed.'
Assert-True ((Get-Sha256 $ReferenceBundlePath) -eq $refsSha) 'O2D6 reference bundle changed.'
if (-not $Rehearsal) {
    Assert-True ((Get-Sha256 $jobSource) -eq $jobSha) 'O2D6 live job changed.'
    Assert-True (Test-Path -LiteralPath $installation -PathType Leaf) 'O2D6 runtime installation evidence absent.'
    Assert-True ((Get-Sha256 $installation) -eq $installationSha) 'O2D6 runtime installation changed.'
}
$pythonCommand = Get-Command -Name $python -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($python), [StringComparison]::OrdinalIgnoreCase)) 'O2D6 Python resolution changed.'

$job = Get-Content -Raw -LiteralPath $jobSource | ConvertFrom-Json
Assert-True ([string]$job.schema -eq 'argos_opencv_scribe_job_v1') 'O2D6 job schema changed.'
Assert-True ([string]$job.inputMode -eq 'QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT') 'O2D6 input mode changed.'
Assert-True ([string]$job.inputQualification.state -eq 'QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT') 'O2D6 qualification state changed.'
Assert-True (@($job.search.expectedRegions).Count -eq 0 -and -not [bool]$job.search.boundedExceptionSearch) 'O2D6 localization boundary changed.'
Assert-True ([bool]$job.authority.reviewOnly -and -not [bool]$job.authority.automaticIdentityAuthority -and -not [bool]$job.authority.trainingEligible -and -not [bool]$job.authority.xmlEligible -and -not [bool]$job.authority.productionEligible -and -not [bool]$job.authority.mayClearHolds) 'O2D6 authority changed.'
Assert-True ([string]$job.outputRoot -eq $OutputRoot) 'O2D6 output root changed.'
foreach ($channel in @('bf','df')) {
    $source = $job.inputs.$channel
    Assert-True ([string]$source.ioPathClass -eq 'INSTALLED_HASH_PINNED_REVIEW_ONLY') "O2D6 input class changed: $channel"
    Assert-True (Test-Path -LiteralPath ([string]$source.path) -PathType Leaf) "O2D6 source absent: $channel"
    Assert-True ((Get-Item -LiteralPath ([string]$source.path)).Length -eq [int64]$source.bytes) "O2D6 source byte count changed: $channel"
    Assert-True ((Get-Sha256 ([string]$source.path)) -eq [string]$source.sha256) "O2D6 source hash changed: $channel"
}
foreach ($qualification in @(
    @([string]$job.inputQualification.proposalPath, [string]$job.inputQualification.proposalSha256),
    @([string]$job.inputQualification.multiChannelSummaryPath, [string]$job.inputQualification.multiChannelSummarySha256)
)) {
    Assert-True (Test-Path -LiteralPath $qualification[0] -PathType Leaf) "O2D6 qualification evidence absent: $($qualification[0])"
    Assert-True ((Get-Sha256 $qualification[0]) -eq $qualification[1]) "O2D6 qualification evidence changed: $($qualification[0])"
}
if (-not $Rehearsal) {
    Assert-True ([string]$job.identity.lotId -eq '62619-433' -and [string]$job.identity.acquisitionId -eq '62619-433_20260824005735' -and [string]$job.identity.slotId -eq 'Slot16') 'O2D6 live identity changed.'
    Assert-True ([string]$job.inputQualification.proposalSha256 -eq $proposalSha -and [string]$job.inputQualification.multiChannelSummarySha256 -eq $summarySha) 'O2D6 installed qualification pins changed.'
    Assert-True ([string]$job.inputs.bf.sha256 -eq $bfSha -and [string]$job.inputs.df.sha256 -eq $dfSha) 'O2D6 installed crop pins changed.'
}
foreach ($path in @($WorkRoot, $partial, $failed, $OutputRoot, $resultPath, $gatePath, $executionPath)) {
    Assert-PathBudget $path 32
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D6 create-new target exists: $path"
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{
        schema='argos_o2d6_endpoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D6_ENDPOINT_PREFLIGHT';revision=$revision;rehearsal=[bool]$Rehearsal
        computerName=$env:COMPUTERNAME;engineSha256=$engineSha;jobSha256=Get-Sha256 $jobSource;referenceBundleSha256=$refsSha;processorProcessCount=$processorBefore.Count
        sourceImageBytesRead=$true;pixelsDecoded=$false;processStarted=$false;mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

try {
    [void](New-Item -ItemType Directory -Path $partial)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($ReferenceBundlePath, $partial)
    Copy-Item -LiteralPath $engineSource -Destination (Join-Path $partial 'ArgosOpenCvScribeV1R3.py')
    Copy-Item -LiteralPath $jobSource -Destination (Join-Path $partial 'JOB.json')
    Assert-True ((Get-Sha256 (Join-Path $partial 'ArgosOpenCvScribeV1R3.py')) -eq $engineSha) 'O2D6 staged engine changed.'
    Assert-True ((Get-Sha256 (Join-Path $partial 'JOB.json')) -eq (Get-Sha256 $jobSource)) 'O2D6 staged job changed.'
    Move-Item -LiteralPath $partial -Destination $WorkRoot -ErrorAction Stop
    [void](New-Item -ItemType Directory -Path $OutputRoot)
    $run = Invoke-BoundedPython -Python $python -Engine (Join-Path $WorkRoot 'ArgosOpenCvScribeV1R3.py') -Job (Join-Path $WorkRoot 'JOB.json') -Result $resultPath
    Assert-True ($run.exitCode -eq 0) ('O2D6 provider failed: ' + $run.stderr.Trim())
    Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) 'O2D6 result absent.'
    $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    Assert-True ([string]$result.schema -eq 'argos_opencv_scribe_result_v2' -and [string]$result.revision -eq $engineRevision) 'O2D6 result schema or revision changed.'
    Assert-True (-not [bool]$result.eligibleIdentity -and [bool]$result.authority.reviewOnly -and -not [bool]$result.authority.automaticIdentityAuthority -and -not [bool]$result.authority.productionEligible -and -not [bool]$result.authority.mayClearHolds) 'O2D6 result authority changed.'
    Assert-True ([string]$result.provenance.inputMode -eq 'QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT') 'O2D6 result input mode changed.'
    Assert-True ([int]$result.provenance.references.referenceCount -eq 456 -and -not [bool]$result.provenance.references.referenceCoverageComplete -and [string]$result.provenance.references.missingBodyReferenceLabels -eq 'IJKOQVWXYZ') 'O2D6 reference provenance changed.'
    Assert-True (@($result.holds | Where-Object { [string]$_.code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' }).Count -eq 1) 'O2D6 reference coverage hold absent.'
    $processorAfter = @(Get-ProcessorRows)
    Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'O2D6 protected processor process identity changed.'
    $gate = [ordered]@{
        schema='argos_o2d6_opencv_scribe_development_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D6_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';disposition='PENDING_GATE';revision=$revision;rehearsal=[bool]$Rehearsal
        engineSha256=$engineSha;jobSha256=Get-Sha256 (Join-Path $WorkRoot 'JOB.json');referenceBundleSha256=$refsSha;resultSha256=Get-Sha256 $resultPath;resultState=[string]$result.state
        imageFirstString=[string]$result.imageFirstString;proposedString=[string]$result.proposedString;checksumState=[string]$result.checksumState;candidates=@($result.candidates);holds=@($result.holds);localization=$result.localization
        installedProposalEligibleIdentity=$false;installedConsensusState='MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES';processorProcessCount=$processorAfter.Count;taskOrProcessRestarted=$false
        sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false
    }
    Write-JsonNew $gatePath $gate 16
    Write-JsonNew $executionPath ([ordered]@{schema='argos_o2d6_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D6_EXECUTION';revision=$revision;computerName=$env:COMPUTERNAME;workRoot=$WorkRoot;outputRoot=$OutputRoot;resultSha256=Get-Sha256 $resultPath;gateSha256=Get-Sha256 $gatePath;sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 10
    $gate | ConvertTo-Json -Compress -Depth 16
}
catch {
    $detail = $_.Exception.Message
    if (Test-Path -LiteralPath $partial) {
        if (-not (Test-Path -LiteralPath $failed)) { Move-Item -LiteralPath $partial -Destination $failed -ErrorAction SilentlyContinue }
    }
    if ((Test-Path -LiteralPath $OutputRoot -PathType Container) -and -not (Test-Path -LiteralPath $failurePath)) {
        Write-JsonNew $failurePath ([ordered]@{schema='argos_o2d6_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_O2D6_EXECUTION_FAILURE';detail=$detail;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 8
    }
    throw
}
