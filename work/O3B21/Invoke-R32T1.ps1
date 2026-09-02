#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$contract=Join-Path $PSScriptRoot 'R32T1_CONTRACT.json';$contractHash='8CA83D75B3337013FC7FF582B332CE26D7CD5DF400A332BED0461CEE372E4C2E'
$runner=Join-Path $PSScriptRoot 'Run-R32TargetedValidation.py';$runnerHash='80AA946E0FA9FD8C09E37FB715F5D9CE73DCBFA485EC890D390AFC3A1DC6FF0D'
$detector=Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR32.py';$detectorHash='2E9D19DDCCCA751C21C545AF5E2B6AB62596E86891374AB0E13C84BEDEA48012'
$config=Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json';$configHash='27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$tests=@(
 @((Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR28.py'),'0BF3E7DE98D586833FA392D686ADFA4CB341F73672B6C7113728604E2AD4901F','PASS_R28_PACKAGED_SYNTHETIC_33_OF_33'),
 @((Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR29.py'),'C62054EFC2C2F573D48C452196D28B18B6BC5C0045DCA45CD2ABA1269FD1E1E7','PASS_R29_PACKAGED_SYNTHETIC_13_OF_13'),
 @((Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR30.py'),'E22233AEA4FA9757448B6BE27119E557C16D05CFEE05E67BD4941BFD29EBEA8B','PASS_R30_PACKAGED_SYNTHETIC_13_OF_13'),
 @((Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR31.py'),'AB66EA7229238195BABF48AB11BB21922FDF2F807EEB52B5C9B8C828B0272A9D','PASS_R31_PACKAGED_SYNTHETIC_21_OF_21'),
 @((Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR32.py'),'A59F9C85D8AB210FAEA78F458342AEE29D1B38E460EFEE9A700085D2AB6B49D2','PASS_R32_PACKAGED_SYNTHETIC_15_OF_15')
)
$output='D:\R32T1'
foreach($pin in @(@($contract,$contractHash),@($runner,$runnerHash),@($detector,$detectorHash),@($config,$configHash))+$tests){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package dependency absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Package dependency changed: $($pin[0])"}
if($PackageLeafPreflight){[ordered]@{schema='argos_o3b21_r32t1_package_leaf_preflight_v1';state='PASS_R32T1_EXACT_PACKAGED_LEAVES';caseCount=1;syntheticTestCount=95;maximumTotalSeconds=240;imageDecoded=$false;processStarted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress;return}
Require ($env:COMPUTERNAME-eq'A1025645101') 'R32T1 reached the wrong computer.'
Require (Test-Path -LiteralPath $python -PathType Leaf) 'Pinned Python runtime absent.'
Require ((Sha $python)-eq$pythonHash) 'Pinned Python runtime changed.'
Require (-not(Test-Path -LiteralPath $output)) 'Create-new R32T1 output exists.'
if($Preflight){[ordered]@{schema='argos_o3b21_r32t1_target_preflight_v1';state='PASS_R32T1_TARGET_PREFLIGHT';outputRoot=$output;caseCount=1;maximumTotalSeconds=240;imageDecoded=$false;sourceHashingPerformed=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
foreach($test in $tests){$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}"'-f$test[0]);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'R32T1 synthetic test did not start.';$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();Require ($process.WaitForExit(120000)) 'R32T1 synthetic test timed out.';Require ($process.ExitCode-eq0) ('R32T1 synthetic test failed: '+$stderr.Result);Require ($stdout.Result.Trim()-eq$test[2]) 'R32T1 synthetic test state changed.';$process.Dispose()}
$arguments=('-B "{0}" --contract "{1}" --detector "{2}" --config "{3}" --python "{4}" --output "{5}"'-f$runner,$contract,$detector,$config,$python,$output)
$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=$arguments;$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true;$process=New-Object Diagnostics.Process;$process.StartInfo=$start;$timer=[Diagnostics.Stopwatch]::StartNew();Require $process.Start() 'R32T1 validation runner did not start.';$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(240000)){try{$process.Kill()}catch{};throw 'R32T1 validation runner timed out.'};$timer.Stop();Require ($process.ExitCode-eq0) ('R32T1 validation runner failed: '+$stderr.Result)
$summaryPath=Join-Path $output 'SUMMARY.json';Require (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'R32T1 summary absent.';$summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json;Require ([string]$summary.state-in@('PASS_R32T1_RESIDUE_ALIGNMENT','HOLD_R32T1_TARGET_OUTCOME')) 'R32T1 result state invalid.';Require (-not[bool]$summary.sourceMutationPerformed) 'R32T1 source mutation reported.'
[ordered]@{schema='argos_o3b21_r32t1_signed_execution_v1';state='PASS_O3B21_R32T1_ONE_EXECUTION_COMPLETE';detectorGateState=[string]$summary.state;outputRoot=$output;elapsedSeconds=[Math]::Round($timer.Elapsed.TotalSeconds,3);caseCount=1;syntheticTestCount=95;summary=$summary;summarySha256=Sha $summaryPath;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingTaskOrProcessActionPerformed=$false;providerActivationPerformed=$false;holdsAutomaticallyCleared=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}|ConvertTo-Json -Depth 32 -Compress
'PASS_O3B21_R32T1_ONE_EXECUTION_COMPLETE'
