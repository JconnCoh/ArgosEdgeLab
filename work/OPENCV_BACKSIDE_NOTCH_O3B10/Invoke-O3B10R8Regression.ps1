#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R8.py'
$engineHash = '64970C7E12DC80AA6934D41E6328FF964E44ACF81AAD75A8A6CDA2BB6FB90096'
$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG.json'
$configHash = 'D52E9DC5A328E83A482DAD6A30349E9AC771650F142112EA1CC24D7CFB58403C'
$cases = @(
    [ordered]@{
        id = '62627-193_SLOT01_CHIPOUT'
        bf = 'D:\KLARFExport\B8R1\BF.bmp'
        bfSha256 = 'F41BDF5CAAFDABF4C8A9BFCE21B0CB0587AA74C93354C3B41B099713B4CB290B'
        df = 'D:\KLARFExport\B8R1\DF.bmp'
        dfSha256 = '8546F979E83B9749CCFEB1241DAF0393D24534DB8F5E94706DFCD8D3FDC9BB7C'
        output = 'D:\B10R8A'
    },
    [ordered]@{
        id = '62607-215_SLOT25'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62607-215\62607-215_20260730053038\Slot25\BrightfieldBacksideWafer\resizedImage\62607-215_Slot25_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = '9C23FA7C86F42E265B0E287AE2496CE9DF71E9AECD6F2D690B2AF1EA2347816A'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62607-215\62607-215_20260730053038\Slot25\DarkfieldBacksideWafer\resizedImage\62607-215_Slot25_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '39587D3AE1DFFC225FC13ADEEAA1E0B56AFD7A00098E1EFA7C7831C8AFB1D615'
        output = 'D:\B10R8B'
    },
    [ordered]@{
        id = '62625-956_SLOT17'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot17\BrightfieldBacksideWafer\resizedImage\62625-956_Slot17_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = 'D076C8847ACC0B80330121D9F57814B17C89AF824A20190DF68CFD7C4ECDFBA1'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot17\DarkfieldBacksideWafer\resizedImage\62625-956_Slot17_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '8CFE760B0F5020CC554D428797E2B3F53C2BDD38988AD4565421443DF19F8521'
        output = 'D:\B10R8C'
    }
)

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R8 regression reached the wrong computer.'
Require ((Sha $python) -eq $pythonHash) 'Pinned Python runtime changed.'
Require ((Sha $engine) -eq $engineHash) 'R8 detector changed.'
Require ((Sha $configPath) -eq $configHash) 'Backside configuration changed.'
foreach ($case in $cases) {
    Require ((Sha $case.bf) -eq $case.bfSha256) "BF source changed: $($case.id)"
    Require ((Sha $case.df) -eq $case.dfSha256) "DF source changed: $($case.id)"
    Require (-not (Test-Path -LiteralPath $case.output)) "Create-new output exists: $($case.output)"
    Require (-not (Test-Path -LiteralPath ($case.output + '.job.json'))) "Create-new job exists: $($case.output)"
}
if ($Preflight) {
    [ordered]@{ state = 'PASS_O3B10_R8_REGRESSION_PREFLIGHT'; caseCount = $cases.Count; processStarted = $false; imageBytesRead = $false; reviewOnly = $true } | ConvertTo-Json -Compress
    return
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$results = @()
foreach ($case in $cases) {
    $jobPath = $case.output + '.job.json'
    $job = [ordered]@{ bf=$case.bf; df=$case.df; bfSha256=$case.bfSha256; dfSha256=$case.dfSha256; output=$case.output; radialEngine=$config.radialEngine; radialEngineSha256=$config.radialEngineSha256; radialParameters=$config.radialParameters; maximumDimension=2400 }
    [IO.File]::WriteAllText($jobPath, ($job | ConvertTo-Json -Depth 16), [Text.UTF8Encoding]::new($false))
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $python
    $start.Arguments = ('-B "{0}" --job "{1}"' -f $engine, $jobPath)
    $start.WorkingDirectory = $PSScriptRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() "R8 detector did not start: $($case.id)"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(900000)) { try { $process.Kill() } catch {}; throw "R8 detector timed out: $($case.id)" }
    $stderr = $stderrTask.Result
    $null = $stdoutTask.Result
    Require ($process.ExitCode -eq 0) ("R8 detector failed: $($case.id): " + $stderr)
    $resultPath = Join-Path $case.output 'RESULT.json'
    $bfReview = Join-Path $case.output 'BF_review.jpg'
    $dfReview = Join-Path $case.output 'DF_review.jpg'
    foreach ($path in @($resultPath,$bfReview,$dfReview)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "R8 output missing: $path" }
    $results += [ordered]@{
        id = $case.id
        detector = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        bfReviewSha256 = Sha $bfReview
        bfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview))
        dfReviewSha256 = Sha $dfReview
        dfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))
    }
}
[ordered]@{ schema='argos_ocv03_o3b10_r8_regression_v1'; state='PASS_O3B10_R8_REGRESSION_EXECUTED'; results=$results; sourceMutationPerformed=$false; existingProcessActionPerformed=$false; ownedChildProcessCount=3; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 32 -Compress
