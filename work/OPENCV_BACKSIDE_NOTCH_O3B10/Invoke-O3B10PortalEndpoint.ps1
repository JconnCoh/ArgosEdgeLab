#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$python = 'D:\AFCV1\rt\python.exe'
$pythonSha256 = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R5.py'
$engineSha256 = '147E67CB4048653769BD9906251D1B670B6803BE28D592D8368717C4ECCFEA0C'
$job = Join-Path $PSScriptRoot 'O3B10_PORTAL_JOB.json'
$output = 'D:\B10R5'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'O3B10 endpoint reached the wrong computer.'
Require (Test-Path -LiteralPath $python -PathType Leaf) 'O3B10 Python runtime is absent.'
Require ((Get-Sha256 $python) -eq $pythonSha256) 'O3B10 Python runtime changed.'
Require (Test-Path -LiteralPath $engine -PathType Leaf) 'O3B10 detector is absent.'
Require ((Get-Sha256 $engine) -eq $engineSha256) 'O3B10 detector hash changed.'
Require (Test-Path -LiteralPath $job -PathType Leaf) 'O3B10 job is absent.'
Require (-not (Test-Path -LiteralPath $output)) 'O3B10 create-new output already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3b10_portal_preflight_v1'
        state = 'PASS_O3B10_PORTAL_PREFLIGHT'
        computer = $env:COMPUTERNAME
        pythonSha256 = $pythonSha256
        output = $output
        imageBytesRead = $false
        processStarted = $false
        mutationsPerformed = $false
        reviewOnly = $true
    } | ConvertTo-Json -Compress
    return
}

$start = New-Object Diagnostics.ProcessStartInfo
$start.FileName = $python
$start.Arguments = ('-B "{0}" --job "{1}"' -f $engine, $job)
$start.WorkingDirectory = $PSScriptRoot
$start.UseShellExecute = $false
$start.CreateNoWindow = $true
$start.RedirectStandardOutput = $true
$start.RedirectStandardError = $true
$process = New-Object Diagnostics.Process
$process.StartInfo = $start
Require $process.Start() 'O3B10 Python child did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(900000)) {
    try { $process.Kill() } catch {}
    throw 'O3B10 Python child exceeded 900 seconds.'
}
$stdout = $stdoutTask.Result
$stderr = $stderrTask.Result
Require ($process.ExitCode -eq 0) ("O3B10 Python child failed: " + $stderr)

$resultPath = Join-Path $output 'RESULT.json'
$bfReview = Join-Path $output 'BF_review.jpg'
$dfReview = Join-Path $output 'DF_review.jpg'
foreach ($path in @($resultPath, $bfReview, $dfReview)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "O3B10 output missing: $path"
}
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
[ordered]@{
    schema = 'argos_ocv03_o3b10_backside_chipout_result_v1'
    state = 'PASS_O3B10_BACKSIDE_CHIPOUT_DETECTOR_EXECUTED'
    detector = $result
    detectorStdout = $stdout.Trim()
    bfReviewName = 'BF_review.jpg'
    bfReviewSha256 = Get-Sha256 $bfReview
    bfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview))
    dfReviewName = 'DF_review.jpg'
    dfReviewSha256 = Get-Sha256 $dfReview
    dfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    existingProcessActionPerformed = $false
    ownedChildProcessCount = 1
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 32 -Compress
