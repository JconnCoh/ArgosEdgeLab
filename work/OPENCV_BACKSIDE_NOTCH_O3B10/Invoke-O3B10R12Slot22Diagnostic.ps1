#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

$python = 'D:\AFCV1\rt\python.exe'
$pythonHash = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R12.py'
$engineHash = 'D3D53827AEDA01658188CDC1ED3FC34ADC5BF73B427227FE00D55563B756B8A6'
$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R2.json'
$configHash = '38F9DFD4724EF12674FB27408539BF8525173B91DF9066573829DC02F6D20184'
$bf = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot22\BrightfieldBacksideWafer\resizedImage\62625-956_Slot22_BrightfieldBacksideWafer_PM2_resizedImage.bmp'
$bfHash = '41F521E4F739B256E5AEA45BBDE8CD76028818FCA1D3AF8C24A93936EDBA1823'
$df = 'D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701\Slot22\DarkfieldBacksideWafer\resizedImage\62625-956_Slot22_DarkfieldBacksideWafer_PM2_resizedImage.bmp'
$dfHash = 'DB2FF6AE8F6CC9EF62FC03EA32B70E146FFE75D6129B7859A2515736134134A9'
$output = 'D:\B10R12D'
$jobPath = 'D:\B10R12D.job.json'

Require ($env:COMPUTERNAME -eq 'A1025645101') 'R12 diagnostic reached the wrong computer.'
foreach ($dependency in @(
    @{Path=$python; Hash=$pythonHash},
    @{Path=$engine; Hash=$engineHash},
    @{Path=$configPath; Hash=$configHash},
    @{Path=$bf; Hash=$bfHash},
    @{Path=$df; Hash=$dfHash}
)) {
    Require (Test-Path -LiteralPath $dependency.Path -PathType Leaf) "R12 diagnostic dependency absent: $($dependency.Path)"
    Require ((Sha $dependency.Path) -eq $dependency.Hash) "R12 diagnostic dependency changed: $($dependency.Path)"
}
Require (-not (Test-Path -LiteralPath $output)) 'Create-new R12 output exists.'
Require (-not (Test-Path -LiteralPath $jobPath)) 'Create-new R12 job exists.'
if ($Preflight) {
    [ordered]@{state='PASS_O3B10_R12_SLOT22_DIAGNOSTIC_PREFLIGHT';processStarted=$false;imageBytesRead=$false;reviewOnly=$true} | ConvertTo-Json -Compress
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
Require $process.Start() 'R12 diagnostic did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
if (-not $process.WaitForExit(900000)) { try { $process.Kill() } catch {}; throw 'R12 diagnostic timed out.' }
$stderr = $stderrTask.Result
$null = $stdoutTask.Result
Require ($process.ExitCode -eq 0) ('R12 diagnostic failed: ' + $stderr)
$resultPath = Join-Path $output 'RESULT.json'
Require (Test-Path -LiteralPath $resultPath -PathType Leaf) 'R12 result is absent.'
[ordered]@{schema='argos_ocv03_o3b10_r12_slot22_diagnostic_v1';state='PASS_O3B10_R12_SLOT22_DIAGNOSTIC_EXECUTED';detector=(Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json);sourceMutationPerformed=$false;existingProcessActionPerformed=$false;ownedChildProcessCount=1;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 32 -Compress
