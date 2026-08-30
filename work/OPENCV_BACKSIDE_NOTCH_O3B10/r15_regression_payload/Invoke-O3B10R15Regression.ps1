#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py'
$engineHash = 'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R3.json'
$configHash = 'B3AD3EBDA8B89A6862E99E38D68BB05B939742A38A86A5B3A982745B1801B821'
$cases = @(
    [ordered]@{
        id = '62627-193_SLOT01_CHIPOUT'
        bf = 'D:\KLARFExport\B8R1\BF.bmp'
        bfSha256 = 'F41BDF5CAAFDABF4C8A9BFCE21B0CB0587AA74C93354C3B41B099713B4CB290B'
        df = 'D:\KLARFExport\B8R1\DF.bmp'
        dfSha256 = '8546F979E83B9749CCFEB1241DAF0393D24534DB8F5E94706DFCD8D3FDC9BB7C'
        output = 'D:\B10R15A'
        expectedPairs = 1
        expectCoverageCompensation = $false
    },
    [ordered]@{
        id = '62607-215_SLOT25'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62607-215\62607-215_20260730053038\Slot25\BrightfieldBacksideWafer\resizedImage\62607-215_Slot25_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = '9C23FA7C86F42E265B0E287AE2496CE9DF71E9AECD6F2D690B2AF1EA2347816A'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62607-215\62607-215_20260730053038\Slot25\DarkfieldBacksideWafer\resizedImage\62607-215_Slot25_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '39587D3AE1DFFC225FC13ADEEAA1E0B56AFD7A00098E1EFA7C7831C8AFB1D615'
        output = 'D:\B10R15B'
        expectedPairs = 1
        expectCoverageCompensation = $false
    },
    [ordered]@{
        id = '62625-956_SLOT17'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot17\BrightfieldBacksideWafer\resizedImage\62625-956_Slot17_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = 'D076C8847ACC0B80330121D9F57814B17C89AF824A20190DF68CFD7C4ECDFBA1'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot17\DarkfieldBacksideWafer\resizedImage\62625-956_Slot17_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '8CFE760B0F5020CC554D428797E2B3F53C2BDD38988AD4565421443DF19F8521'
        output = 'D:\B10R15C'
        expectedPairs = 1
        expectCoverageCompensation = $false
    },
    [ordered]@{
        id = '62625-956_SLOT22'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot22\BrightfieldBacksideWafer\resizedImage\62625-956_Slot22_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = '41F521E4F739B256E5AEA45BBDE8CD76028818FCA1D3AF8C24A93936EDBA1823'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot22\DarkfieldBacksideWafer\resizedImage\62625-956_Slot22_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = 'DB2FF6AE8F6CC9EF62FC03EA32B70E146FFE75D6129B7859A2515736134134A9'
        output = 'D:\B10R15D'
        expectedPairs = 1
        expectCoverageCompensation = $false
    },
    [ordered]@{
        id = '62631-544_SLOT06_MIN_DF_COVERAGE'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62631-544\62631-544_20260803105445\Slot06\BrightfieldBacksideWafer\resizedImage\62631-544_Slot06_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = 'AFD1BA3F6F9F522336A47A71F72C11C8732C877B463D06C9659CA0DBA335D8B0'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62631-544\62631-544_20260803105445\Slot06\DarkfieldBacksideWafer\resizedImage\62631-544_Slot06_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '5AE34D078EDE9A8BF091BB2F3AF3C1319DC98AAC03E82EC3447E9AB9D62E3D32'
        output = 'D:\B10R15E'
        expectedPairs = 1
        expectCoverageCompensation = $true
    },
    [ordered]@{
        id = '62627-127_SLOT17_SPLIT_DF_NOTCH'
        bf = 'D:\KLARFExport\Coherent_W2W\Lot-62627-127\62627-127_20260728152158\Slot17\BrightfieldBacksideWafer\resizedImage\LotIDStringNotSet_Slot17_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = '33D75979611ACBD814754EFCD80F160C223E286BDBE24417AE712177B7FAA39C'
        df = 'D:\KLARFExport\Coherent_W2W\Lot-62627-127\62627-127_20260728152158\Slot17\DarkfieldBacksideWafer\resizedImage\LotIDStringNotSet_Slot17_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '29C67C860924A3A5B3DB023071FEE3A812850010A0232A617417FC442A7BD3D4'
        output = 'D:\B10R15F'
        expectedPairs = 1
        expectCoverageCompensation = $false
    },
    [ordered]@{
        id = '62631-544_SLOT01_SAME_LOT_PASS'
        bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62631-544\62631-544_20260803105445\Slot01\BrightfieldBacksideWafer\resizedImage\62631-544_Slot01_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = '31344302ABC841C0843BF904FDEB1D781CD874A53878A4776217D048BD4CDE84'
        df = 'D:\KLARFExport\BackSide_BowComp\Lot_62631-544\62631-544_20260803105445\Slot01\DarkfieldBacksideWafer\resizedImage\62631-544_Slot01_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '31515D07FCF3A6780D46398E246CA56DC639DBC172627DF7EFB195D1F0310143'
        output = 'D:\B10R15G'
        expectedPairs = 1
        expectCoverageCompensation = $false
    },
    [ordered]@{
        id = '62626-015_SLOT07_BROAD_DF_HOLD'
        bf = 'D:\KLARFExport\Coherent_W2W\Lot_62626-015\62626-015_20260728180702\Slot07\BrightfieldBacksideWafer\resizedImage\62626-015_Slot07_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
        bfSha256 = 'CF087F15D58CE0A6683B46C16B2C5F127DDEA5E6E35E053015C5E155F507F62F'
        df = 'D:\KLARFExport\Coherent_W2W\Lot_62626-015\62626-015_20260728180702\Slot07\DarkfieldBacksideWafer\resizedImage\62626-015_Slot07_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
        dfSha256 = '01A6D9D031A2C36FDF7EAEFE100ED3BCF0D7531249A7AE72179BB32EC937DE62'
        output = 'D:\B10R15H'
        expectedPairs = 0
        expectCoverageCompensation = $false
    }
)

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R15 regression reached the wrong computer.'
Require ((Sha $python) -eq $pythonHash) 'Pinned Python runtime changed.'
Require ((Sha $engine) -eq $engineHash) 'R15 detector changed.'
Require ((Sha $configPath) -eq $configHash) 'Backside configuration changed.'
foreach ($case in $cases) {
    Require ((Sha $case.bf) -eq $case.bfSha256) "BF source changed: $($case.id)"
    Require ((Sha $case.df) -eq $case.dfSha256) "DF source changed: $($case.id)"
    Require (-not (Test-Path -LiteralPath $case.output)) "Create-new output exists: $($case.output)"
    Require (-not (Test-Path -LiteralPath ($case.output + '.job.json'))) "Create-new job exists: $($case.output)"
}
if ($Preflight) {
    [ordered]@{ state = 'PASS_O3B10_R15_REGRESSION_PREFLIGHT'; caseCount = $cases.Count; processStarted = $false; imageBytesRead = $false; reviewOnly = $true } | ConvertTo-Json -Compress
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
    Require $process.Start() "R15 detector did not start: $($case.id)"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(900000)) { try { $process.Kill() } catch {}; throw "R15 detector timed out: $($case.id)" }
    $stderr = $stderrTask.Result
    $null = $stdoutTask.Result
    Require ($process.ExitCode -eq 0) ("R15 detector failed: $($case.id): " + $stderr)
    $resultPath = Join-Path $case.output 'RESULT.json'
    $bfReview = Join-Path $case.output 'BF_review.jpg'
    $dfReview = Join-Path $case.output 'DF_review.jpg'
    foreach ($path in @($resultPath,$bfReview,$dfReview)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "R15 output missing: $path" }
    $detector = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Require ([int]$detector.pairedCandidateCount -eq [int]$case.expectedPairs) "R15 pair-count regression failed: $($case.id)"
    $coverageCompensated = $false
    if ($detector.PSObject.Properties.Name -contains 'df' -and $detector.df.backsideTraceQualification.PSObject.Properties.Name -contains 'coverageCompensatedByUniqueCrossChannelPair') {
        $coverageCompensated = [bool]$detector.df.backsideTraceQualification.coverageCompensatedByUniqueCrossChannelPair
    }
    Require ($coverageCompensated -eq [bool]$case.expectCoverageCompensation) "R15 coverage-compensation regression failed: $($case.id)"
    $results += [ordered]@{
        id = $case.id
        detector = $detector
        bfReviewSha256 = Sha $bfReview
        bfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview))
        dfReviewSha256 = Sha $dfReview
        dfReviewBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))
    }
}
[ordered]@{ schema='argos_ocv03_o3b10_r15_regression_v1'; state='PASS_O3B10_R15_REGRESSION_EXECUTED'; results=$results; sourceMutationPerformed=$false; existingProcessActionPerformed=$false; ownedChildProcessCount=8; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 32 -Compress
