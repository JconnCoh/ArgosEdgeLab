#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R13.py'
$engineHash = '36D7D19469A41598FCA07CBBD289B26F9FD45305633E3E9F99047A9C38D62ABA'
$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R2.json'
$configHash = '38F9DFD4724EF12674FB27408539BF8525173B91DF9066573829DC02F6D20184'
$bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot22\BrightfieldBacksideWafer\resizedImage\62625-956_Slot22_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
$bfHash = '41F521E4F739B256E5AEA45BBDE8CD76028818FCA1D3AF8C24A93936EDBA1823'
$df = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot22\DarkfieldBacksideWafer\resizedImage\62625-956_Slot22_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
$dfHash = 'DB2FF6AE8F6CC9EF62FC03EA32B70E146FFE75D6129B7859A2515736134134A9'
$output = 'D:\B10R13D'
$jobPath = 'D:\B10R13D.job.json'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R13 trace reached the wrong computer.'
foreach ($dependency in @(
    @{Path=$python; Hash=$pythonHash},
    @{Path=$engine; Hash=$engineHash},
    @{Path=$configPath; Hash=$configHash},
    @{Path=$bf; Hash=$bfHash},
    @{Path=$df; Hash=$dfHash}
)) {
    Require (Test-Path -LiteralPath $dependency.Path -PathType Leaf) "R13 trace dependency absent: $($dependency.Path)"
    Require ((Sha $dependency.Path) -eq $dependency.Hash) "R13 trace dependency changed: $($dependency.Path)"
}
Require (-not (Test-Path -LiteralPath $output)) 'Create-new R13 output exists.'
Require (-not (Test-Path -LiteralPath $jobPath)) 'Create-new R13 job exists.'
if ($Preflight) {
    [ordered]@{state='PASS_O3B10_R13_SLOT22_TRACE_PREFLIGHT';processStarted=$false;imageBytesRead=$false;reviewOnly=$true} | ConvertTo-Json -Compress
    return
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$job = [ordered]@{bf=$bf;df=$df;bfSha256=$bfHash;dfSha256=$dfHash;output=$output;radialEngine=$config.radialEngine;radialEngineSha256=$config.radialEngineSha256;radialParameters=$config.radialParameters;maximumDimension=2400}
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
Require $process.Start() 'R13 trace did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(900000)) { try { $process.Kill() } catch {}; throw 'R13 trace timed out.' }
$stderr = $stderrTask.Result
$null = $stdoutTask.Result
Require ($process.ExitCode -eq 0) ('R13 trace failed: ' + $stderr)
$resultPath = Join-Path $output 'RESULT.json'
Require (Test-Path -LiteralPath $resultPath -PathType Leaf) 'R13 result is absent.'
$bfReview = Join-Path $output 'BF_review.jpg'
$dfReview = Join-Path $output 'DF_review.jpg'
foreach ($path in @($bfReview,$dfReview)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "R13 trace output missing: $path" }
[ordered]@{schema='argos_ocv03_o3b10_r13_slot22_trace_v1';state='PASS_O3B10_R13_SLOT22_TRACE_EXECUTED';detector=(Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json);bfReviewSha256=(Sha $bfReview);bfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview));dfReviewSha256=(Sha $dfReview);dfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview));sourceMutationPerformed=$false;existingProcessActionPerformed=$false;ownedChildProcessCount=1;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 32 -Compress
