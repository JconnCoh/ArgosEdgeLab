#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R9.py'
$engineHash = 'D652180407690925D2049A125B253F544C722DED5D2B5F9B6EF18CB82BC29F9F'
$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG.json'
$configHash = 'D52E9DC5A328E83A482DAD6A30349E9AC771650F142112EA1CC24D7CFB58403C'
$cases = @(
    [ordered]@{
        id = '62625-956_SLOT17'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot17\BrightfieldBacksideWafer\resizedImage\62625-956_Slot17_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = 'D076C8847ACC0B80330121D9F57814B17C89AF824A20190DF68CFD7C4ECDFBA1'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot17\DarkfieldBacksideWafer\resizedImage\62625-956_Slot17_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '8CFE760B0F5020CC554D428797E2B3F53C2BDD38988AD4565421443DF19F8521'
        output = 'D:\B10R9A'
    }
)

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R9 diagnostic reached the wrong computer.'
Require ((Sha $python) -eq $pythonHash) 'Pinned Python runtime changed.'
Require ((Sha $engine) -eq $engineHash) 'R9 detector changed.'
Require ((Sha $configPath) -eq $configHash) 'Backside configuration changed.'
foreach ($case in $cases) {
    Require ((Sha $case.bf) -eq $case.bfSha256) "BF source changed: $($case.id)"
    Require ((Sha $case.df) -eq $case.dfSha256) "DF source changed: $($case.id)"
    Require (-not (Test-Path -LiteralPath $case.output)) "Create-new output exists: $($case.output)"
    Require (-not (Test-Path -LiteralPath ($case.output + '.job.json'))) "Create-new job exists: $($case.output)"
}
if ($Preflight) {
    [ordered]@{ state = 'PASS_O3B10_R9_DIAGNOSTIC_PREFLIGHT'; caseCount = $cases.Count; processStarted = $false; imageBytesRead = $false; reviewOnly = $true } | ConvertTo-Json -Compress
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
    Require $process.Start() "R9 detector did not start: $($case.id)"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(900000)) { try { $process.Kill() } catch {}; throw "R9 detector timed out: $($case.id)" }
    $stderr = $stderrTask.Result
    $null = $stdoutTask.Result
    Require ($process.ExitCode -eq 0) ("R9 detector failed: $($case.id): " + $stderr)
    $resultPath = Join-Path $case.output 'RESULT.json'
    $bfReview = Join-Path $case.output 'BF_review.jpg'
    $dfReview = Join-Path $case.output 'DF_review.jpg'
    foreach ($path in @($resultPath,$bfReview,$dfReview)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "R9 output missing: $path" }
    $results += [ordered]@{
        id = $case.id
        detector = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        bfReviewSha256 = Sha $bfReview
        bfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview))
        dfReviewSha256 = Sha $dfReview
        dfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))
    }
}
[ordered]@{ schema='argos_ocv03_o3b10_r9_diagnostic_v1'; state='PASS_O3B10_R9_DIAGNOSTIC_EXECUTED'; results=$results; sourceMutationPerformed=$false; existingProcessActionPerformed=$false; ownedChildProcessCount=1; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 32 -Compress
