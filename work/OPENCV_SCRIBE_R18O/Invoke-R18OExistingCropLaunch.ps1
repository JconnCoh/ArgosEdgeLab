#Requires -Version 5.1
# Clone-audit historical template root only: D:\KLARFExport is not read by R18O.
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = '',
    [string]$WorkRoot = 'D:\A2\w\ocv\R18O2',
    [string]$OutputRoot = 'D:\A2\o\ocv\R18O2',
    [string]$ProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals',
    [string]$PythonPath = 'D:\AFCV1\rt\python.exe',
    [string]$ExpectedPythonSha256 = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'R18O_EXISTING_CROPS_ONLY_REVIEW_ONLY_20260904A'
$manifestSha = 'C75336C215DB7FF5D6DA49AB387E9082CB3C70F515B73D103626AA5B2ABE4C8A'
$refsSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$providerSha = '3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD'
$cropSweepSha = 'EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F'
$runnerSha = 'ABEBC2F85DAFC0E4F74CABD7E1CF6E929E30BE188B3C12972342B586223DCE6F'
$baseManifestSha = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
$supplementalManifestSha = 'FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114'
$payload = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath($PayloadRoot) }
$payloadManifestPath = Join-Path $payload 'R18O_PAYLOAD_MANIFEST.json'
$partial = $WorkRoot + '.partial'
$failed = $WorkRoot + '.failed'
$runtimeConfiguration = Join-Path $WorkRoot 'RUNTIME_CONFIGURATION.json'
$runner = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18O\Run-R18OExistingCropCorpus.py'
$launchPath = Join-Path $OutputRoot 'LAUNCH.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

function Require([bool]$Condition, [string]$Message) {
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
    Require (($full.Length + $Reserve) -lt 200) "R18J unsafe effective path: $full"
    Require ($longest -le 80) "R18J unsafe path component: $full"
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18J create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Get-ProcessorRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Invoke-AllWaferProcessorV2.ps1*' } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{processId=[uint32]$_.ProcessId;creationDate=[string]$_.CreationDate;commandLine=[string]$_.CommandLine} })
}
function Get-CorpusRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Run-R18OExistingCropCorpus.py*' } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{processId=[uint32]$_.ProcessId;creationDate=[string]$_.CreationDate;commandLine=[string]$_.CommandLine} })
}

Require ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "R18J wrong computer: $($env:COMPUTERNAME)"
foreach ($path in @($payloadManifestPath,$PythonPath,$ReferenceBundlePath,$ProposalRoot)) {
    Require (Test-Path -LiteralPath $path) "R18J dependency absent: $path"
    Assert-PathBudget $path 32
}
Require ((Get-Sha256 $payloadManifestPath) -eq $manifestSha) 'R18J payload manifest changed.'
Require ((Get-Sha256 $PythonPath) -eq $ExpectedPythonSha256) 'R18J Python runtime changed.'
Require ((Get-Sha256 $ReferenceBundlePath) -eq $refsSha) 'R18J base reference bundle changed.'
if (-not $Rehearsal) {
    $installation = 'D:\AFCV1\INSTALLATION.json'
    Require (Test-Path -LiteralPath $installation -PathType Leaf) 'R18J runtime installation evidence absent.'
    Require ((Get-Sha256 $installation) -eq $installationSha) 'R18J runtime installation evidence changed.'
}
$manifest = Get-Content -Raw -LiteralPath $payloadManifestPath | ConvertFrom-Json
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18o_payload_manifest_v1' -and [string]$manifest.revision -eq $revision) 'R18O payload manifest contract changed.'
Require ([bool]$manifest.authority.reviewOnly -and -not [bool]$manifest.authority.identityAcceptanceAuthorized -and -not [bool]$manifest.authority.automaticReferenceAdmissionAuthorized -and -not [bool]$manifest.authority.trainingAuthorized -and -not [bool]$manifest.authority.activationAuthorized -and -not [bool]$manifest.authority.xmlAuthorized -and -not [bool]$manifest.authority.productionAuthorized) 'R18J payload authority changed.'
$files = @($manifest.files)
Require ($files.Count -eq 23) 'R18J payload file cardinality changed.'
foreach ($file in $files) {
    $source = Join-Path $payload ('files\' + ([string]$file.installRelativePath).Replace('/','\'))
    Require (Test-Path -LiteralPath $source -PathType Leaf) "R18J payload absent: $($file.installRelativePath)"
    Require ((Get-Item -LiteralPath $source).Length -eq [int64]$file.bytes) "R18J payload length changed: $($file.installRelativePath)"
    Require ((Get-Sha256 $source) -eq [string]$file.sha256) "R18J payload hash changed: $($file.installRelativePath)"
    Assert-PathBudget $source 32
    Assert-PathBudget (Join-Path $partial ([string]$file.installRelativePath).Replace('/','\')) 32
}
$configurationSource = Join-Path $payload 'files\OPENCV_SCRIBE_R18J\R18J_JBOD_CONFIGURATION.json'
$configuration = Get-Content -Raw -LiteralPath $configurationSource | ConvertFrom-Json
Require ([string]$configuration.schema -eq 'argos_opencv_scribe_r18j_corpus_configuration_v1') 'R18J configuration schema changed.'
Require ([bool]$configuration.authority.reviewOnly -and -not [bool]$configuration.authority.identityAcceptanceAuthorized -and -not [bool]$configuration.authority.automaticReferenceAdmissionAuthorized -and -not [bool]$configuration.authority.trainingAuthorized -and -not [bool]$configuration.authority.activationAuthorized -and -not [bool]$configuration.authority.xmlAuthorized -and -not [bool]$configuration.authority.productionAuthorized) 'R18J configuration authority changed.'
foreach ($path in @($WorkRoot,$partial,$failed,$OutputRoot,$runtimeConfiguration,$runner,$launchPath,$failurePath,(Join-Path $OutputRoot 'c\0123456789ABCDEF\RESULT.json'))) {
    Assert-PathBudget $path 32
}
foreach ($path in @($WorkRoot,$partial,$failed,$OutputRoot)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18J fresh target exists: $path"
}
$pythonCommand = Get-Command -Name $PythonPath -CommandType Application -ErrorAction Stop
Require ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($PythonPath), [StringComparison]::OrdinalIgnoreCase)) 'R18J Python resolution changed.'
$existingCorpus = @(Get-CorpusRows)
Require ($existingCorpus.Count -eq 0) 'An R18J corpus worker is already running.'
$processorBefore = @(Get-ProcessorRows)
$drive = Get-PSDrive -Name ([IO.Path]::GetPathRoot($OutputRoot).Substring(0,1)) -ErrorAction Stop
Require ([int64]$drive.Free -ge 10737418240) 'R18J output drive has less than 10 GiB free.'
if ($Preflight) {
    [ordered]@{
        schema='argos_opencv_scribe_r18o_launch_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');
        state='PASS_R18O_EXISTING_CROP_LAUNCH_PREFLIGHT';revision=$revision;rehearsal=[bool]$Rehearsal;
        payloadFileCount=$files.Count;payloadManifestSha256=$manifestSha;pythonSha256=$ExpectedPythonSha256;
        referenceBundleSha256=$refsSha;proposalRoot=$ProposalRoot;workRoot=$WorkRoot;
        outputRoot=$OutputRoot;freeBytes=[int64]$drive.Free;existingCorpusProcessCount=0;
        protectedProcessorCount=$processorBefore.Count;sourceImagesRead=$false;processStarted=$false;
        mutationsPerformed=$false;identityAccepted=$false;readerModified=$false;referenceLibraryModified=$false;
        reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$ownedProcess = $null
try {
    [void](New-Item -ItemType Directory -Path $partial)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($ReferenceBundlePath, $partial)
    foreach ($file in $files) {
        $source = Join-Path $payload ('files\' + ([string]$file.installRelativePath).Replace('/','\'))
        $destination = Join-Path $partial ([string]$file.installRelativePath).Replace('/','\')
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
        Copy-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
        Require ((Get-Sha256 $destination) -eq [string]$file.sha256) "R18J staged payload changed: $($file.installRelativePath)"
    }
    $configuration.sourceRoot = $ProposalRoot
    $configuration.proposalRoot = $ProposalRoot
    $configuration.providerPath = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18H\ArgosOpenCvScribeV1R18H.py'
    $configuration.cropSweepPath = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18J\ArgosOpenCvScribeCropSweepR18J.py'
    $configuration.references.manifestPath = Join-Path $WorkRoot 'refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $configuration.references.supplementalManifestPath = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18F\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json'
    $configuration.references.roots[0].path = Join-Path $WorkRoot 'refs\glyphs'
    $configuration.references.roots[1].path = Join-Path $WorkRoot 'refs\glyphs_v5_confirmed_20260806'
    $runtimePartial = Join-Path $partial 'RUNTIME_CONFIGURATION.json'
    Write-JsonNew $runtimePartial $configuration 20
    Require ([string]$configuration.providerSha256 -eq $providerSha -and [string]$configuration.cropSweepSha256 -eq $cropSweepSha -and [string]$configuration.references.manifestSha256 -eq $baseManifestSha -and [string]$configuration.references.supplementalManifestSha256 -eq $supplementalManifestSha) 'R18J runtime configuration pins changed.'
    Move-Item -LiteralPath $partial -Destination $WorkRoot -ErrorAction Stop
    Require ((Get-Sha256 $runner) -eq $runnerSha) 'R18J installed runner changed.'
    [void](New-Item -ItemType Directory -Path $OutputRoot)
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $PythonPath
    $startInfo.Arguments = '"' + $runner + '" --configuration "' + $runtimeConfiguration + '" --output-root "' + $OutputRoot + '"'
    $startInfo.WorkingDirectory = $WorkRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $ownedProcess = New-Object Diagnostics.Process
    $ownedProcess.StartInfo = $startInfo
    Require ($ownedProcess.Start()) 'R18J corpus worker did not start.'
    Start-Sleep -Seconds 2
    Require (-not $ownedProcess.HasExited) 'R18J corpus worker exited before launch confirmation.'
    $processorAfter = @(Get-ProcessorRows)
    Require (($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress)) 'R18J protected processor identity changed.'
    $launch = [ordered]@{
        schema='argos_opencv_scribe_r18o_existing_crop_launch_v1';createdUtc=[DateTime]::UtcNow.ToString('o');
        state='PASS_R18O_EXISTING_CROP_WORKER_STARTED';revision=$revision;computerName=$env:COMPUTERNAME;
        processId=[int]$ownedProcess.Id;processStartTimeUtc=$ownedProcess.StartTime.ToUniversalTime().ToString('o');
        processCommandLine=$startInfo.FileName+' '+$startInfo.Arguments;workRoot=$WorkRoot;outputRoot=$OutputRoot;
        proposalRoot=$ProposalRoot;fullWaferImagesRead=$false;wholeWaferFallbackAllowed=$false;payloadManifestSha256=$manifestSha;providerSha256=$providerSha;
        cropSweepSha256=$cropSweepSha;runnerSha256=$runnerSha;baseReferenceManifestSha256=$baseManifestSha;
        supplementalReferenceManifestSha256=$supplementalManifestSha;protectedProcessorCount=$processorAfter.Count;
        taskActionCount=0;existingProcessActionCount=0;ownedProcessStarted=$true;automaticRetryAllowed=$false;
        identityAccepted=$false;readerModified=$false;referenceLibraryModified=$false;sourceMutationPerformed=$false;
        reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-JsonNew $launchPath $launch 12
    $launchJson = $launch | ConvertTo-Json -Compress -Depth 12
    Write-Output -InputObject $launchJson
    $ownedProcess.Dispose()
    $ownedProcess = $null
}
catch {
    $detail = $_.Exception.Message
    if ($null -ne $ownedProcess) {
        try { if (-not $ownedProcess.HasExited) { $ownedProcess.Kill() } } catch {}
        $ownedProcess.Dispose()
        $ownedProcess = $null
    }
    if ((Test-Path -LiteralPath $partial) -and -not (Test-Path -LiteralPath $failed)) {
        Move-Item -LiteralPath $partial -Destination $failed -ErrorAction SilentlyContinue
    }
    if ((Test-Path -LiteralPath $OutputRoot -PathType Container) -and -not (Test-Path -LiteralPath $failurePath)) {
        Write-JsonNew $failurePath ([ordered]@{schema='argos_opencv_scribe_r18o_launch_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_R18O_EXISTING_CROP_LAUNCH_FAILURE';detail=$detail;ownedChildTerminated=$true;automaticRetryAllowed=$false;sourceMutationPerformed=$false;identityAccepted=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 8
    }
    throw
}
