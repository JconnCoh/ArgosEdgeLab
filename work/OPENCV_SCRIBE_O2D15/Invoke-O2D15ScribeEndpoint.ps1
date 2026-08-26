#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = '',
    [string]$RuntimeRoot = 'D:\AFCV1\rt',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$WorkRoot = 'D:\A2\w\ocv\O2D15_20260826T225708001Z_9A8661E9',
    [string]$OutputRoot = 'D:\A2\o\ocv\O2D15_20260826T225708001Z_9A8661E9',
    [string]$SourceAliasRoot = 'D:\KLARFExport\PatternedFront\Lot_62619-433',
    [string]$RehearsalJobPath = '',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$effectivePayloadRoot = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PSScriptRoot } else { $PayloadRoot }

$revision = 'O2D15_20260826T225708001Z_9A8661E9'
$engineRevision = 'ARGOS_OPENCV_SCRIBE_V1R5_20260826'
$engineSha = 'F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB'
$jobSha = 'D14E47EF05FAF9FD8EC1C687E005BEC878C13FC69DF3B738B5B4762492A6B089'
$refsSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$bfSha = '83362565391B7245DAB450B67A6EF79062CAC431D6E7259E0ECEA594DCA3C239'
$dfSha = '3F1CF8D84C5E4C3F4DFADD6368A0DE667B06D956F664CD69C5B4390F5ABC5256'

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
    Assert-True (($full.Length + $Reserve) -lt 200) "O2D15 unsafe effective path: $full"
    Assert-True ($longest -le 80) "O2D15 unsafe component: $full"
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D15 create-new JSON exists: $Path"
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
    Assert-True ($process.Start()) 'O2D15 Python did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(600000)) {
        try { $process.Kill() } catch {}
        throw 'O2D15 Python exceeded 600000 milliseconds.'
    }
    $invocation = [pscustomobject]@{ exitCode=$process.ExitCode; stdout=$stdoutTask.Result; stderr=$stderrTask.Result }
    $process.Dispose()
    return $invocation
}

$engineSource = Join-Path $effectivePayloadRoot 'ArgosOpenCvScribeV1R5.py'
$jobSource = if ($Rehearsal -and -not [string]::IsNullOrWhiteSpace($RehearsalJobPath)) { $RehearsalJobPath } else { Join-Path $effectivePayloadRoot 'O2D15_SLOT19_JOB.json' }
$python = Join-Path $RuntimeRoot 'python.exe'
$subst = Join-Path $env:SystemRoot 'System32\subst.exe'
$aliasName = 'X:'
$aliasPath = 'X:\'
$installation = 'D:\AFCV1\INSTALLATION.json'
$partial = $WorkRoot + '.partial'
$failed = $WorkRoot + '.failed'
$resultPath = Join-Path $OutputRoot 'RESULT.json'
$gatePath = Join-Path $OutputRoot 'RUN_GATE.json'
$executionPath = Join-Path $OutputRoot 'EXECUTION.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

Assert-True ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O2D15 wrong computer: $($env:COMPUTERNAME)"
foreach ($path in @($engineSource, $jobSource, $python, $subst, $ReferenceBundlePath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D15 dependency absent: $path"
    Assert-PathBudget $path 32
}
Assert-True ((Get-Sha256 $engineSource) -eq $engineSha) 'O2D15 engine changed.'
Assert-True ((Get-Sha256 $ReferenceBundlePath) -eq $refsSha) 'O2D15 reference bundle changed.'
if (-not $Rehearsal) {
    Assert-True ((Get-Sha256 $jobSource) -eq $jobSha) 'O2D15 live job changed.'
    Assert-True (Test-Path -LiteralPath $installation -PathType Leaf) 'O2D15 runtime installation evidence absent.'
    Assert-True ((Get-Sha256 $installation) -eq $installationSha) 'O2D15 runtime installation changed.'
}
$pythonCommand = Get-Command -Name $python -CommandType Application -ErrorAction Stop
$substCommand = Get-Command -Name $subst -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($python), [StringComparison]::OrdinalIgnoreCase)) 'O2D15 Python resolution changed.'
Assert-True ([IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($subst), [StringComparison]::OrdinalIgnoreCase)) 'O2D15 subst resolution changed.'
Assert-True (Test-Path -LiteralPath $SourceAliasRoot -PathType Container) 'O2D15 source alias anchor absent.'
Assert-True (-not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name X -ErrorAction SilentlyContinue)) 'O2D15 X: is already in use.'

$job = Get-Content -Raw -LiteralPath $jobSource | ConvertFrom-Json
Assert-True ([string]$job.schema -eq 'argos_opencv_scribe_job_v1') 'O2D15 job schema changed.'
Assert-True ([string]$job.inputMode -eq 'DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE') 'O2D15 input mode changed.'
Assert-True ([string]$job.rawSourceBinding.state -eq 'PASS_OCV00_EXACT_TWENTY_SOURCE_HASHES' -and [bool]$job.rawSourceBinding.upstreamHoldDoesNotSkipScribeDevelopment) 'O2D15 raw source binding changed.'
Assert-True (@($job.search.expectedRegions).Count -eq 0 -and [bool]$job.search.boundedExceptionSearch -and [int]$job.search.developmentMaximumRegions -eq 4 -and [int]$job.search.developmentMinimumBandWidthPixels -eq 500 -and [int]$job.search.developmentOcrRegionWidthPixels -eq 1600 -and [int]$job.search.developmentOcrRegionHeightPixels -eq 400) 'O2D15 localization boundary changed.'
Assert-True ([bool]$job.authority.reviewOnly -and -not [bool]$job.authority.automaticIdentityAuthority -and -not [bool]$job.authority.trainingEligible -and -not [bool]$job.authority.xmlEligible -and -not [bool]$job.authority.productionEligible -and -not [bool]$job.authority.mayClearHolds) 'O2D15 authority changed.'
Assert-True ([string]$job.outputRoot -eq $OutputRoot) 'O2D15 output root changed.'
foreach ($channel in @('bf','df')) {
    $source = $job.inputs.$channel
    $canonical = [string]$source.canonicalProvenancePath
    Assert-True ([string]$source.ioPathClass -eq 'SHORT_DOS_DEVICE_ALIAS' -and [string]$source.aliasName -eq $aliasName -and [string]$source.aliasAnchorCanonicalPath -eq $SourceAliasRoot) "O2D15 input class changed: $channel"
    Assert-True ([string]$source.path -like 'X:\*' -and $canonical.StartsWith($SourceAliasRoot + '\', [StringComparison]::OrdinalIgnoreCase)) "O2D15 source path mapping changed: $channel"
    $expectedAliasPath = $aliasPath + $canonical.Substring($SourceAliasRoot.Length).TrimStart('\')
    Assert-True ([string]$source.path -eq $expectedAliasPath) "O2D15 exact alias-relative source mapping changed: $channel"
    Assert-PathBudget ([string]$source.path) 32
}
if (-not $Rehearsal) {
    Assert-True ([string]$job.identity.lotId -eq '62619-433' -and [string]$job.identity.acquisitionId -eq '62619-433_20260824005735' -and [string]$job.identity.slotId -eq 'Slot19') 'O2D15 live identity changed.'
    Assert-True ([string]$job.inputs.bf.sha256 -eq $bfSha -and [string]$job.inputs.df.sha256 -eq $dfSha) 'O2D15 raw source pins changed.'
}
foreach ($path in @($WorkRoot, $partial, $failed, $OutputRoot, $resultPath, $gatePath, $executionPath)) {
    Assert-PathBudget $path 32
    Assert-True (-not (Test-Path -LiteralPath $path)) "O2D15 create-new target exists: $path"
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{
        schema='argos_o2d15_endpoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D15_ENDPOINT_PREFLIGHT';revision=$revision;rehearsal=[bool]$Rehearsal
        computerName=$env:COMPUTERNAME;engineSha256=$engineSha;jobSha256=Get-Sha256 $jobSource;referenceBundleSha256=$refsSha;processorProcessCount=$processorBefore.Count
        sourceImageBytesRead=$false;pixelsDecoded=$false;processStarted=$false;sourceAliasPresentBefore=$false;mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$aliasCreated = $false
try {
    $createOutput = & $subst $aliasName $SourceAliasRoot 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $aliasPath -PathType Container)) ('O2D15 alias creation failed: ' + $createOutput.Trim())
    $aliasCreated = $true
    $allMappings = & $subst 2>&1 | Out-String
    $matching = @(($allMappings -split '\r?\n') | Where-Object { $_ -match '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$' })
    Assert-True ($matching.Count -eq 1) 'O2D15 alias mapping cardinality changed.'
    $aliasMatch = [regex]::Match($matching[0], '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$')
    Assert-True ($aliasMatch.Groups[1].Value.Trim().TrimEnd('\').Equals($SourceAliasRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O2D15 alias target changed.'
    foreach ($channel in @('bf','df')) {
        $source = $job.inputs.$channel
        Assert-True (Test-Path -LiteralPath ([string]$source.path) -PathType Leaf) "O2D15 aliased source absent: $channel"
        Assert-True ((Get-Item -LiteralPath ([string]$source.path)).Length -eq [int64]$source.bytes) "O2D15 source byte count changed: $channel"
        Assert-True ((Get-Sha256 ([string]$source.path)) -eq [string]$source.sha256) "O2D15 source hash changed: $channel"
    }
    [void](New-Item -ItemType Directory -Path $partial)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($ReferenceBundlePath, $partial)
    Copy-Item -LiteralPath $engineSource -Destination (Join-Path $partial 'ArgosOpenCvScribeV1R5.py')
    Copy-Item -LiteralPath $jobSource -Destination (Join-Path $partial 'JOB.json')
    Assert-True ((Get-Sha256 (Join-Path $partial 'ArgosOpenCvScribeV1R5.py')) -eq $engineSha) 'O2D15 staged engine changed.'
    Assert-True ((Get-Sha256 (Join-Path $partial 'JOB.json')) -eq (Get-Sha256 $jobSource)) 'O2D15 staged job changed.'
    Move-Item -LiteralPath $partial -Destination $WorkRoot -ErrorAction Stop
    [void](New-Item -ItemType Directory -Path $OutputRoot)
    $run = Invoke-BoundedPython -Python $python -Engine (Join-Path $WorkRoot 'ArgosOpenCvScribeV1R5.py') -Job (Join-Path $WorkRoot 'JOB.json') -ResultPath $resultPath
    Assert-True ($run.exitCode -eq 0) ('O2D15 provider failed: ' + $run.stderr.Trim())
    Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) 'O2D15 result absent.'
    $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    Assert-True ([string]$result.schema -eq 'argos_opencv_scribe_result_v2' -and [string]$result.revision -eq $engineRevision) 'O2D15 result schema or revision changed.'
    Assert-True (-not [bool]$result.eligibleIdentity -and [bool]$result.authority.reviewOnly -and -not [bool]$result.authority.automaticIdentityAuthority -and -not [bool]$result.authority.productionEligible -and -not [bool]$result.authority.mayClearHolds) 'O2D15 result authority changed.'
    Assert-True ([string]$result.provenance.inputMode -eq 'DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE') 'O2D15 result input mode changed.'
    Assert-True ([int]$result.provenance.references.referenceCount -eq 456 -and -not [bool]$result.provenance.references.referenceCoverageComplete -and [string]$result.provenance.references.missingBodyReferenceLabels -eq 'IJKOQVWXYZ') 'O2D15 reference provenance changed.'
    Assert-True (@($result.holds | Where-Object { [string]$_.code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' }).Count -eq 1) 'O2D15 reference coverage hold absent.'
    Assert-True (@($result.holds | Where-Object { [string]$_.code -eq 'SCRIBE_AUTO_LOCALIZATION_DEVELOPMENT_HOLD' }).Count -eq 1) 'O2D15 automatic-localization hold absent.'
    $removeOutput = & $subst $aliasName '/D' 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $aliasPath)) ('O2D15 alias removal failed: ' + $removeOutput.Trim())
    $aliasCreated = $false
    $processorAfter = @(Get-ProcessorRows)
    Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'O2D15 protected processor process identity changed.'
    $gate = [ordered]@{
        schema='argos_o2d15_opencv_scribe_development_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D15_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';disposition='PENDING_GATE';revision=$revision;rehearsal=[bool]$Rehearsal
        engineSha256=$engineSha;jobSha256=Get-Sha256 (Join-Path $WorkRoot 'JOB.json');referenceBundleSha256=$refsSha;resultSha256=Get-Sha256 $resultPath;resultState=[string]$result.state
        imageFirstString=[string]$result.imageFirstString;proposedString=[string]$result.proposedString;checksumState=[string]$result.checksumState;candidates=@($result.candidates);holds=@($result.holds);localization=$result.localization
        upstreamProposalState='SCRIBE_IDENTITY_CONFIRMATION_HOLD';upstreamNotchHoldDidNotSkipScribe=$true;sourceAliasName=$aliasName;sourceAliasRoot=$SourceAliasRoot;sourceAliasRemoved=$true;processorProcessCount=$processorAfter.Count;taskOrProcessRestarted=$false
        sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false
    }
    Write-JsonNew $gatePath $gate 16
    Write-JsonNew $executionPath ([ordered]@{schema='argos_o2d15_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D15_EXECUTION';revision=$revision;computerName=$env:COMPUTERNAME;workRoot=$WorkRoot;outputRoot=$OutputRoot;resultSha256=Get-Sha256 $resultPath;gateSha256=Get-Sha256 $gatePath;sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 10
    $gate | ConvertTo-Json -Compress -Depth 16
}
catch {
    $detail = $_.Exception.Message
    if (Test-Path -LiteralPath $partial) {
        if (-not (Test-Path -LiteralPath $failed)) { Move-Item -LiteralPath $partial -Destination $failed -ErrorAction SilentlyContinue }
    }
    if ((Test-Path -LiteralPath $OutputRoot -PathType Container) -and -not (Test-Path -LiteralPath $failurePath)) {
        Write-JsonNew $failurePath ([ordered]@{schema='argos_o2d15_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_O2D15_EXECUTION_FAILURE';detail=$detail;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 8
    }
    throw
}
finally {
    if ($aliasCreated) {
        & $subst $aliasName '/D' 2>&1 | Out-Null
        $aliasCreated = $false
    }
}
