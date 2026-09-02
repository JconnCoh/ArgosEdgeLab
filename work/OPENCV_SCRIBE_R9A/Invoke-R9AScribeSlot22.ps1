#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = '',
    [string]$BatchManifestPath = '',
    [string]$RuntimeRoot = 'D:\AFCV1\rt',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$WorkRoot = 'D:\A2\w\ocv\R9A',
    [string]$OutputRoot = 'D:\A2\o\ocv\R9A',
    [string]$SourceAliasRoot = 'D:\KLARFExport\PatternedFront\Lot_62619-433',
    [string]$LiveContractFixtureManifest = '',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$payload = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath($PayloadRoot) }
$batchPath = if ([string]::IsNullOrWhiteSpace($BatchManifestPath)) { Join-Path $payload 'BATCH.json' } else { [IO.Path]::GetFullPath($BatchManifestPath) }
$revision = 'OCV02_R9A_20260902A'
$engineRevision = 'ARGOS_OPENCV_SCRIBE_V1R9_20260902'
$engineSha = '4955AAAAD4C07D3B7BD87332E8956ECDCD291F5ACF1C6FC0E30B937DCB4C8E9F'
$batchSha = '6807B84AB3B84E915FBBF340ADE13D0B01989E1CA0F1331E3344D85F2CDBC015'
$configurationSha = '4733CDB0ED14D08D8742F4F481DE51BC7A9B1A717E43087EC0994095EA76CF7E'
$refsSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($parts.Count -gt 0) { [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) } else { 0 }
    Assert-True (($full.Length + $Reserve) -lt 200) "R9A unsafe effective path: $full"
    Assert-True ($longest -le 80) "R9A unsafe component: $full"
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "R9A create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Get-ProcessorRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Invoke-AllWaferProcessorV2.ps1*' } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{ processId=[uint32]$_.ProcessId; creationDate=[string]$_.CreationDate; commandLine=[string]$_.CommandLine } })
}
function Invoke-BoundedPython([string]$Python, [string]$Engine, [string]$Job, [string]$ResultPath) {
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $startInfo.Arguments = '"' + $Engine + '" --job "' + $Job + '" --result "' + $ResultPath + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-True ($process.Start()) 'R9A Python did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(1200000)) {
        try { $process.Kill() } catch {}
        throw 'R9A Python exceeded 1200000 milliseconds.'
    }
    $row = [pscustomobject]@{ exitCode=$process.ExitCode; stdout=[string]$stdoutTask.Result; stderr=[string]$stderrTask.Result }
    $process.Dispose()
    return $row
}

if (-not [string]::IsNullOrWhiteSpace($LiveContractFixtureManifest)) {
    Assert-True ([bool]$Preflight -and -not [bool]$Rehearsal) 'R9A live-contract fixture is preflight-only.'
    $fixturePath = [IO.Path]::GetFullPath($LiveContractFixtureManifest)
    Assert-True (Test-Path -LiteralPath $fixturePath -PathType Leaf) 'R9A live-contract fixture manifest absent.'
    Assert-PathBudget $fixturePath 32
    $fixture = Get-Content -Raw -LiteralPath $fixturePath | ConvertFrom-Json
    Assert-True ([string]$fixture.schema -eq 'argos_r9a_live_contract_fixture_v1' -and [string]$fixture.state -eq 'FROZEN') 'R9A live-contract fixture changed.'
    Assert-True ([bool]$fixture.reviewOnly -and -not [bool]$fixture.productionRoutingEnabled) 'R9A live-contract fixture authority changed.'
    $fixtureRoot = Split-Path -Parent $fixturePath
    $fixtureBatch = [IO.Path]::GetFullPath((Join-Path $fixtureRoot ([string]$fixture.batchPath)))
    $fixtureInstallation = [IO.Path]::GetFullPath((Join-Path $fixtureRoot ([string]$fixture.installationPath)))
    Assert-True (Test-Path -LiteralPath $fixtureBatch -PathType Leaf) 'R9A fixture batch absent.'
    Assert-True ((Get-Sha256 $fixtureBatch) -eq [string]$fixture.expectedBatchSha256) 'R9A live batch manifest changed.'
    Assert-True (Test-Path -LiteralPath $fixtureInstallation -PathType Leaf) 'R9A fixture installation absent.'
    Assert-True ((Get-Sha256 $fixtureInstallation) -eq [string]$fixture.expectedInstallationSha256) 'R9A runtime installation changed.'
    [ordered]@{schema='argos_r9a_live_contract_fixture_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9A_LIVE_CONTRACT_FIXTURE';revision=$revision;batchSha256=Get-Sha256 $fixtureBatch;installationSha256=Get-Sha256 $fixtureInstallation;batchAssertionExecuted=$true;installationAssertionExecuted=$true;sourceImageBytesRead=$false;pixelsDecoded=$false;processStarted=$false;mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$engineSource = Join-Path $payload 'ArgosOpenCvScribeV1R9.py'
$configurationSource = Join-Path $payload 'R9A_CONFIGURATION.json'
$python = Join-Path $RuntimeRoot 'python.exe'
$subst = Join-Path $env:SystemRoot 'System32\subst.exe'
$installation = 'D:\AFCV1\INSTALLATION.json'
$aliasName = 'X:'
$aliasPath = 'X:\'
$partial = $WorkRoot + '.partial'
$failed = $WorkRoot + '.failed'
$batchGatePath = Join-Path $OutputRoot 'BATCH_GATE.json'
$executionPath = Join-Path $OutputRoot 'EXECUTION.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

Assert-True ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "R9A wrong computer: $($env:COMPUTERNAME)"
foreach ($path in @($engineSource,$configurationSource,$batchPath,$python,$subst,$ReferenceBundlePath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R9A dependency absent: $path"
    Assert-PathBudget $path 32
}
Assert-True ((Get-Sha256 $engineSource) -eq $engineSha) 'R9A engine changed.'
Assert-True ((Get-Sha256 $configurationSource) -eq $configurationSha) 'R9A configuration changed.'
Assert-True ((Get-Sha256 $ReferenceBundlePath) -eq $refsSha) 'R9A reference bundle changed.'
if (-not $Rehearsal) {
    Assert-True ((Get-Sha256 $batchPath) -eq $batchSha) 'R9A live batch manifest changed.'
    Assert-True (Test-Path -LiteralPath $installation -PathType Leaf) 'R9A runtime installation evidence absent.'
    Assert-True ((Get-Sha256 $installation) -eq $installationSha) 'R9A runtime installation changed.'
}
$pythonCommand = Get-Command -Name $python -CommandType Application -ErrorAction Stop
$substCommand = Get-Command -Name $subst -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($python), [StringComparison]::OrdinalIgnoreCase)) 'R9A Python resolution changed.'
Assert-True ([IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($subst), [StringComparison]::OrdinalIgnoreCase)) 'R9A subst resolution changed.'
Assert-True (Test-Path -LiteralPath $SourceAliasRoot -PathType Container) 'R9A source alias anchor absent.'
Assert-True (-not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name X -ErrorAction SilentlyContinue)) 'R9A X: is already in use.'

$batch = Get-Content -Raw -LiteralPath $batchPath | ConvertFrom-Json
Assert-True ([string]$batch.schema -eq 'argos_opencv_scribe_batch_v1' -and [string]$batch.revision -eq $revision) 'R9A batch contract changed.'
Assert-True ([bool]$batch.authority.reviewOnly -and -not [bool]$batch.authority.automaticIdentityAuthority -and -not [bool]$batch.authority.mayClearHolds -and -not [bool]$batch.authority.trainingEligible -and -not [bool]$batch.authority.xmlEligible -and -not [bool]$batch.authority.productionEligible) 'R9A batch authority changed.'
Assert-True ([int]$batch.serialization.maximumConcurrentProviderChildren -eq 1 -and -not [bool]$batch.serialization.automaticRetryAllowed -and [bool]$batch.serialization.caseFailureStopsBatch) 'R9A serialization changed.'
Assert-True ([string]$batch.engine.sha256 -eq $engineSha -and [string]$batch.engine.revision -eq $engineRevision) 'R9A batch engine pin changed.'
Assert-True ([string]$batch.configuration.sha256 -eq $configurationSha -and [double]$batch.configuration.minimumObservedHeightRatio -eq 0.9 -and [bool]$batch.configuration.algorithmBytesChangedFromR6V1) 'R9A batch configuration pin changed.'
Assert-True ([string]$batch.referenceBundle.sha256 -eq $refsSha -and [int]$batch.referenceBundle.expectedReferenceCount -eq 456 -and -not [bool]$batch.referenceBundle.referenceCoverageComplete -and [string]$batch.referenceBundle.missingBodyReferenceLabels -eq 'IJKOQVWXYZ') 'R9A reference contract changed.'
if (-not $Rehearsal) {
    Assert-True ([string]$batch.referenceBundle.path -eq $ReferenceBundlePath) 'R9A live reference path changed.'
    Assert-True ([string]$batch.sourceAlias.name -eq $aliasName -and [string]$batch.sourceAlias.root -eq $SourceAliasRoot) 'R9A live source-alias contract changed.'
    Assert-True ([string]$batch.workRoot -eq $WorkRoot -and [string]$batch.outputRoot -eq $OutputRoot) 'R9A live work/output roots changed.'
}
$cases = @($batch.cases)
Assert-True ($cases.Count -eq 1 -and [string]$cases[0].slot -eq 'Slot22') 'R9A exact case set changed.'

$jobs = New-Object Collections.Generic.List[object]
foreach ($case in $cases) {
    $jobPath = Join-Path $payload ([string]$case.jobFile)
    Assert-True (Test-Path -LiteralPath $jobPath -PathType Leaf) "R9A job absent: $($case.slot)"
    Assert-PathBudget $jobPath 32
    Assert-True ((Get-Sha256 $jobPath) -eq [string]$case.jobSha256) "R9A job changed: $($case.slot)"
    $job = Get-Content -Raw -LiteralPath $jobPath | ConvertFrom-Json
    Assert-True ([string]$job.schema -eq 'argos_opencv_scribe_job_v1' -and [string]$job.revision -eq $revision) "R9A job schema changed: $($case.slot)"
    Assert-True ([string]$job.identity.slotId -eq [string]$case.slot -and [string]$job.identity.physicalIdentity -eq [string]$case.physicalIdentity) "R9A job identity changed: $($case.slot)"
    Assert-True ([string]$job.inputMode -eq 'DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE' -and @($job.search.expectedRegions).Count -eq 0 -and [bool]$job.search.boundedExceptionSearch) "R9A localization mode changed: $($case.slot)"
    Assert-True ([int]$job.search.developmentMaximumRegions -eq 8 -and [double]$job.search.developmentMinimumObservedHeightRatio -eq 0.9 -and [double]$job.search.developmentMinimumObservedWidthRatio -eq 0.9 -and [double]$job.search.developmentMaximumObservedWidthRatio -eq 1.1) "R9A observed-geometry boundary changed: $($case.slot)"
    Assert-True ([bool]$job.authority.reviewOnly -and -not [bool]$job.authority.automaticIdentityAuthority -and -not [bool]$job.authority.mayClearHolds -and -not [bool]$job.authority.trainingEligible -and -not [bool]$job.authority.xmlEligible -and -not [bool]$job.authority.productionEligible) "R9A job authority changed: $($case.slot)"
    foreach ($channel in @('bf','df')) {
        $source = $job.inputs.$channel
        $canonical = [string]$source.canonicalProvenancePath
        Assert-True ([string]$source.ioPathClass -eq 'SHORT_DOS_DEVICE_ALIAS' -and [string]$source.aliasName -eq $aliasName -and [string]$source.aliasAnchorCanonicalPath -eq $SourceAliasRoot) "R9A source class changed: $($case.slot)/$channel"
        Assert-True ([string]$source.path -eq ($aliasPath + $canonical.Substring($SourceAliasRoot.Length).TrimStart('\'))) "R9A alias mapping changed: $($case.slot)/$channel"
        Assert-PathBudget ([string]$source.path) 32
    }
    $jobs.Add([pscustomobject]@{case=$case;job=$job;sourcePath=$jobPath})
}
foreach ($path in @($WorkRoot,$partial,$failed,$OutputRoot,$batchGatePath,$executionPath)) {
    Assert-PathBudget $path 32
    Assert-True (-not (Test-Path -LiteralPath $path)) "R9A create-new target exists: $path"
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{schema='argos_r9a_scribe_batch_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9A_SCRIBE_BATCH_PREFLIGHT';revision=$revision;rehearsal=[bool]$Rehearsal;caseCount=$jobs.Count;engineSha256=$engineSha;configurationSha256=$configurationSha;minimumObservedHeightRatio=0.9;batchSha256=Get-Sha256 $batchPath;referenceBundleSha256=$refsSha;processorProcessCount=$processorBefore.Count;sourceImageBytesRead=$false;pixelsDecoded=$false;processStarted=$false;mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$aliasCreated = $false
try {
    $createOutput = & $subst $aliasName $SourceAliasRoot 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $aliasPath -PathType Container)) ('R9A alias creation failed: ' + $createOutput.Trim())
    $aliasCreated = $true
    $mappings = & $subst 2>&1 | Out-String
    $matching = @(($mappings -split '\r?\n') | Where-Object { $_ -match '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$' })
    Assert-True ($matching.Count -eq 1) 'R9A alias mapping cardinality changed.'
    $target = [regex]::Match($matching[0], '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$').Groups[1].Value.Trim().TrimEnd('\')
    Assert-True ($target.Equals($SourceAliasRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'R9A alias target changed.'
    foreach ($entry in $jobs) {
        foreach ($channel in @('bf','df')) {
            $source = $entry.job.inputs.$channel
            Assert-True (Test-Path -LiteralPath ([string]$source.path) -PathType Leaf) "R9A source absent: $($entry.case.slot)/$channel"
            Assert-True ((Get-Item -LiteralPath ([string]$source.path)).Length -eq [int64]$source.bytes) "R9A source bytes changed: $($entry.case.slot)/$channel"
            Assert-True ((Get-Sha256 ([string]$source.path)) -eq [string]$source.sha256) "R9A source hash changed: $($entry.case.slot)/$channel"
        }
    }
    [void](New-Item -ItemType Directory -Path $partial)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($ReferenceBundlePath, $partial)
    Copy-Item -LiteralPath $engineSource -Destination (Join-Path $partial 'ArgosOpenCvScribeV1R9.py')
    Copy-Item -LiteralPath $configurationSource -Destination (Join-Path $partial 'R9A_CONFIGURATION.json')
    Copy-Item -LiteralPath $batchPath -Destination (Join-Path $partial 'BATCH.json')
    foreach ($entry in $jobs) { Copy-Item -LiteralPath $entry.sourcePath -Destination (Join-Path $partial ([string]$entry.case.jobFile)) }
    Move-Item -LiteralPath $partial -Destination $WorkRoot -ErrorAction Stop
    [void](New-Item -ItemType Directory -Path $OutputRoot)
    $resultRows = New-Object Collections.Generic.List[object]
    foreach ($entry in $jobs) {
        $caseOutput = Join-Path $OutputRoot ([string]$entry.case.slot)
        [void](New-Item -ItemType Directory -Path $caseOutput)
        $resultPath = Join-Path $caseOutput 'RESULT.json'
        $run = Invoke-BoundedPython -Python $python -Engine (Join-Path $WorkRoot 'ArgosOpenCvScribeV1R9.py') -Job (Join-Path $WorkRoot ([string]$entry.case.jobFile)) -ResultPath $resultPath
        Assert-True ($run.exitCode -eq 0) "R9A provider failed: $($entry.case.slot): $($run.stderr.Trim())"
        $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
        Assert-True ([string]$result.schema -eq 'argos_opencv_scribe_result_v2' -and [string]$result.revision -eq $engineRevision) "R9A result contract changed: $($entry.case.slot)"
        Assert-True (-not [bool]$result.eligibleIdentity -and [bool]$result.authority.reviewOnly -and -not [bool]$result.authority.automaticIdentityAuthority -and -not [bool]$result.authority.productionEligible -and -not [bool]$result.authority.mayClearHolds) "R9A result authority changed: $($entry.case.slot)"
        Assert-True ([int]$result.provenance.references.referenceCount -eq 456 -and -not [bool]$result.provenance.references.referenceCoverageComplete -and [string]$result.provenance.references.missingBodyReferenceLabels -eq 'IJKOQVWXYZ') "R9A reference provenance changed: $($entry.case.slot)"
        Assert-True (@($result.holds | Where-Object { [string]$_.code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' }).Count -eq 1) "R9A reference hold absent: $($entry.case.slot)"
        Assert-True (@($result.holds | Where-Object { [string]$_.code -eq 'SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD' }).Count -eq 1) "R9A localization hold absent: $($entry.case.slot)"
        $resultRows.Add([pscustomobject]@{slot=[string]$entry.case.slot;physicalIdentity=[string]$entry.case.physicalIdentity;state=[string]$result.state;eligibleIdentity=[bool]$result.eligibleIdentity;imageFirstString=[string]$result.imageFirstString;proposedString=[string]$result.proposedString;checksumState=[string]$result.checksumState;resultPath=$resultPath;resultSha256=Get-Sha256 $resultPath;holds=@($result.holds);localization=$result.localization})
    }
    $removeOutput = & $subst $aliasName '/D' 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $aliasPath)) ('R9A alias removal failed: ' + $removeOutput.Trim())
    $aliasCreated = $false
    $processorAfter = @(Get-ProcessorRows)
    Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'R9A protected processor identity changed.'
    $gate = [ordered]@{schema='argos_r9a_scribe_batch_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9A_REAL_IMAGE_REVIEW_ONLY_BATCH';disposition='PENDING_GATE';revision=$revision;caseCount=$resultRows.Count;identityEligibleCount=@($resultRows | Where-Object { $_.eligibleIdentity }).Count;engineSha256=$engineSha;configurationSha256=$configurationSha;minimumObservedHeightRatio=0.9;batchSha256=Get-Sha256 (Join-Path $WorkRoot 'BATCH.json');referenceBundleSha256=$refsSha;results=$resultRows.ToArray();sourceAliasRemoved=$true;maximumConcurrentProviderChildren=1;automaticRetryAllowed=$false;processorProcessCount=$processorAfter.Count;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
    Write-JsonNew $batchGatePath $gate 24
    Write-JsonNew $executionPath ([ordered]@{schema='argos_r9a_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R9A_EXECUTION';revision=$revision;computerName=$env:COMPUTERNAME;workRoot=$WorkRoot;outputRoot=$OutputRoot;batchGateSha256=Get-Sha256 $batchGatePath;sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 10
    $gate | ConvertTo-Json -Compress -Depth 24
}
catch {
    $detail = $_.Exception.Message
    if ((Test-Path -LiteralPath $partial) -and -not (Test-Path -LiteralPath $failed)) { Move-Item -LiteralPath $partial -Destination $failed -ErrorAction SilentlyContinue }
    if ((Test-Path -LiteralPath $OutputRoot -PathType Container) -and -not (Test-Path -LiteralPath $failurePath)) {
        Write-JsonNew $failurePath ([ordered]@{schema='argos_r9a_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_R9A_EXECUTION_FAILURE';detail=$detail;automaticRetryAllowed=$false;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 8
    }
    throw
}
finally {
    if ($aliasCreated) { & $subst $aliasName '/D' 2>&1 | Out-Null }
}
