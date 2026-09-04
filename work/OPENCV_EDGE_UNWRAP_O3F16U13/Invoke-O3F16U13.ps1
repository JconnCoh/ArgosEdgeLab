#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$PackageLeafPreflight
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Read-Json([string]$Text, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Text)) "O3F16U13 $Label emitted no JSON."
    try { $Text | ConvertFrom-Json }
    catch { throw "O3F16U13 $Label emitted invalid JSON." }
}

$runtime = 'D:\AFCV1\rt\python.exe'
$runtimeHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$developmentRoot = 'D:\O3F15L4E5RT'
$r10 = 'D:\O3F15L4E5RT\AnnularUnwrapDiagnosticOpenCvR10.py'
$r10Hash = '6B28925E04839D411838CB3D6C7D39E523AFC3AE89EDBAC83034351D27ED814C'
$baseR12 = 'D:\O3F15L4E5RT\AnnularUnwrapDiagnosticOpenCvR12.py'
$baseR12Hash = '1696DBE407E4461B351C6B939C591A4E652E558DF15BF4AC5CEFB369950FF7F6'
$front = 'D:\O3F15L4E5RT\Run-O3F15L4FrontReconcile.py'
$frontHash = '3C403376521B74E3A6DB1C4E008CE8DB36D8D99AE9A0FD7C1FA51481024DBEF4'
$payloadR13 = Join-Path $PSScriptRoot 'AnnularUnwrapDiagnosticOpenCvR13.py'
$r13Hash = '35940B211AEB51898B7BA9F279004D404D1C0AF2013B933414D1F58B30EF7748'
$installedR13 = 'D:\O3F15L4E5RT\AnnularUnwrapDiagnosticOpenCvR13.py'
$outputRoot = 'D:\O3F16U13'
$archiveRoot = 'D:\KLARFExport\_ArgosReview'
$archivePath = 'D:\KLARFExport\_ArgosReview\O3F16U13_20260904.zip'
$partialArchive = $archivePath + '.partial'
$safeIds = @(
    'PatternedFront_Lot_62629-419_NotchBad_Hots_5b0a0bfeaa',
    'PatternedFront_Lot_62629-419_NotchBad_Hots_4b0fc7f2d9',
    'PatternedFront_Lot_62629-419_NotchBad_Hots_c6083929e8',
    'PatternedFront_Lot_62629-419_NotchBad_Hots_d0339fcc45'
)

Require (Test-Path -LiteralPath $payloadR13 -PathType Leaf) 'O3F16U13 packaged R13 is absent.'
Require ((Sha $payloadR13) -ceq $r13Hash) 'O3F16U13 packaged R13 hash changed.'
Require ($safeIds.Count -eq 4 -and @($safeIds | Sort-Object -Unique).Count -eq 4) 'O3F16U13 four-case set changed.'

if ($PackageLeafPreflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f16u13_package_leaf_preflight_v1'
        state = 'PASS_O3F16U13_PACKAGE_LEAVES'
        r13Sha256 = $r13Hash
        requestedCaseCount = 4
        targetReadPerformed = $false
        imageBytesRead = $false
        mutationsPerformed = $false
        reviewOnly = $true
    } | ConvertTo-Json -Compress
    return
}

Require ($env:COMPUTERNAME -ceq 'A1025645101') 'O3F16U13 target computer changed.'
foreach ($pin in @(
    @($runtime, $runtimeHash),
    @($r10, $r10Hash),
    @($baseR12, $baseR12Hash),
    @($front, $frontHash)
)) {
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "O3F16U13 target dependency absent: $($pin[0])"
    Require ((Sha $pin[0]) -ceq $pin[1]) "O3F16U13 target dependency hash changed: $($pin[0])"
}
Require (Test-Path -LiteralPath $archiveRoot -PathType Container) 'O3F16U13 portal-readable archive root is absent.'
Require (-not (Test-Path -LiteralPath $installedR13)) 'O3F16U13 installed R13 destination already exists.'
Require (-not (Test-Path -LiteralPath $outputRoot)) 'O3F16U13 fresh output root already exists.'
Require (-not (Test-Path -LiteralPath $archivePath)) 'O3F16U13 return archive already exists.'
Require (-not (Test-Path -LiteralPath $partialArchive)) 'O3F16U13 partial return archive already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f16u13_target_preflight_v1'
        state = 'PASS_O3F16U13_TARGET_PREFLIGHT'
        runtimeSha256 = Sha $runtime
        r10Sha256 = Sha $r10
        baseR12Sha256 = Sha $baseR12
        frontReconcileSha256 = Sha $front
        r13Sha256 = $r13Hash
        requestedCaseCount = 4
        imageBytesRead = $false
        processStarted = $false
        mutationsPerformed = $false
        reviewOnly = $true
    } | ConvertTo-Json -Compress
    return
}

[IO.File]::Copy($payloadR13, $installedR13, $false)
Require ((Sha $installedR13) -ceq $r13Hash) 'O3F16U13 installed R13 verification failed.'

$arguments = New-Object 'Collections.Generic.List[string]'
$arguments.Add('-I')
$arguments.Add('-B')
$arguments.Add($installedR13)
foreach ($safeId in $safeIds) {
    $arguments.Add('--safe-id')
    $arguments.Add($safeId)
}
$arguments.Add('--output-root')
$arguments.Add($outputRoot)
Require (@($arguments | Where-Object { $_ -match '[\s"\r\n]' }).Count -eq 0) 'O3F16U13 child argument quoting changed.'

$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $runtime
$start.Arguments = ($arguments -join ' ')
$start.WorkingDirectory = $developmentRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
$start.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
$start.EnvironmentVariables['PYTHONUTF8'] = '1'
$process = New-Object Diagnostics.Process
$process.StartInfo = $start
Require $process.Start() 'O3F16U13 detector child did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(1800000)) {
    $process.Kill()
    $process.WaitForExit()
    throw 'O3F16U13 detector child exceeded 1800 seconds.'
}
$stdout = [string]$stdoutTask.Result
$stderr = [string]$stderrTask.Result
$exitCode = $process.ExitCode
$process.Dispose()
Require ($exitCode -eq 0) ("O3F16U13 detector child failed: " + $stderr.Trim())
$child = Read-Json $stdout.Trim() 'detector child'
Require ([string]$child.state -ceq 'COMPLETE_DIAGNOSTIC_ONLY_ANNULAR_UNWRAP' -and [int]$child.completedCount -eq 4) 'O3F16U13 detector child did not complete all four cases.'

$summaryPath = Join-Path $outputRoot 'SUMMARY.json'
Require (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'O3F16U13 summary is absent.'
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
Require ([string]$summary.schema -ceq 'argos_ocv03_annular_unwrap_diagnostic_v1') 'O3F16U13 summary schema changed.'
Require ([string]$summary.state -ceq 'COMPLETE_DIAGNOSTIC_ONLY_ANNULAR_UNWRAP') 'O3F16U13 summary state changed.'
Require ([string]$summary.engineSha256 -ceq $r13Hash -and [int]$summary.requestedCount -eq 4 -and [int]$summary.completedCount -eq 4) 'O3F16U13 summary identity changed.'
Require (@($summary.results | Where-Object { [string]$_.state -cne 'DIAGNOSTIC_ONLY_ANNULAR_UNWRAP_COMPLETE' }).Count -eq 0) 'O3F16U13 contains a held/error case.'
Require (-not [bool]$summary.candidateSelectionPerformed -and -not [bool]$summary.selectorThresholdRelaxationPerformed -and -not [bool]$summary.sourceMutationPerformed -and -not [bool]$summary.providerActivated) 'O3F16U13 authority widened in summary.'
Require (@($summary.results | Where-Object { @($_.channels.BF.assets.psobject.Properties).Count -ne 12 -or @($_.channels.DF.assets.psobject.Properties).Count -ne 12 }).Count -eq 0) 'O3F16U13 asset role count changed.'
Require (@($summary.results | Where-Object { [bool]$_.channels.BF.annularEvidence.trackingEnhancementChangedFromR12 -or [bool]$_.channels.DF.annularEvidence.trackingEnhancementChangedFromR12 -or [bool]$_.channels.BF.annularEvidence.heldInterpolatedPathRenderedAcrossImage -or [bool]$_.channels.DF.annularEvidence.heldInterpolatedPathRenderedAcrossImage -or [bool]$_.channels.BF.annularEvidence.postResultSelectorRelaxationPerformed -or [bool]$_.channels.DF.annularEvidence.postResultSelectorRelaxationPerformed }).Count -eq 0) 'O3F16U13 evidence semantics changed.'

$files = @(Get-ChildItem -LiteralPath $outputRoot -Recurse -File)
Require ($files.Count -eq 97) "O3F16U13 output file count changed: $($files.Count)"
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($outputRoot, $partialArchive, [IO.Compression.CompressionLevel]::Optimal, $false)
Move-Item -LiteralPath $partialArchive -Destination $archivePath

[ordered]@{
    schema = 'argos_ocv03_o3f16u13_launch_result_v1'
    state = 'PASS_O3F16U13_FOUR_CASE_DIAGNOSTIC_AND_ARCHIVE'
    r13InstalledPath = $installedR13
    r13Sha256 = Sha $installedR13
    outputRoot = $outputRoot
    summaryPath = $summaryPath
    summarySha256 = Sha $summaryPath
    completedCaseCount = 4
    outputFileCount = $files.Count
    archivePath = $archivePath
    archiveBytes = [int64](Get-Item -LiteralPath $archivePath).Length
    archiveSha256 = Sha $archivePath
    sourceMutationPerformed = $false
    existingTaskOrProcessActionPerformed = $false
    providerActivated = $false
    retryAuthorized = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
} | ConvertTo-Json -Compress
