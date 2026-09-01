#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}

$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$contract=Join-Path $PSScriptRoot 'R29VAL1_CONTRACT.json';$contractHash='9A1702545D199D77719DD3AE3426B47B6BF6FC0A19701D794F8D13D91928C6D6'
$runner=Join-Path $PSScriptRoot 'Run-R29ValidationBatch.py';$runnerHash='F0296EDEC3845C1D4833DCA06588BA6D8D225CD907A1A12586E0DB08CDEF6F2B'
$detector=Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR29.py';$detectorHash='72F0DAAE7DC66D4627F03A265B65C137D7362A60C27AA649BAFE564FC515EB65'
$config=Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json';$configHash='27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$frozen=Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json';$frozenHash='7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
$r28Test=Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR28.py';$r28TestHash='0BF3E7DE98D586833FA392D686ADFA4CB341F73672B6C7113728604E2AD4901F'
$r29Test=Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR29.py';$r29TestHash='C62054EFC2C2F573D48C452196D28B18B6BC5C0045DCA45CD2ABA1269FD1E1E7'
$output='D:\R29VAL1'
foreach($pin in @(@($contract,$contractHash),@($runner,$runnerHash),@($detector,$detectorHash),@($config,$configHash),@($frozen,$frozenHash),@($r28Test,$r28TestHash),@($r29Test,$r29TestHash))){
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package dependency absent: $($pin[0])"
    Require ((Sha $pin[0])-eq$pin[1]) "Package dependency changed: $($pin[0])"
}
if($PackageLeafPreflight){
    [ordered]@{schema='argos_o3b21_r29val1_package_leaf_preflight_v1';state='PASS_R29VAL1_EXACT_PACKAGED_LEAVES';caseCount=39;frozenCaseCount=32;currentRecipeSmokeCount=6;syntheticTestCount=46;imageDecoded=$false;processStarted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
    return
}
Require ($env:COMPUTERNAME-eq'A1025645101') 'R29VAL1 reached the wrong computer.'
Require (Test-Path -LiteralPath $python -PathType Leaf) 'Pinned Python runtime absent.'
Require ((Sha $python)-eq$pythonHash) 'Pinned Python runtime changed.'
Require (-not(Test-Path -LiteralPath $output)) 'Create-new R29VAL1 output exists.'
if($Preflight){
    [ordered]@{schema='argos_o3b21_r29val1_target_preflight_v1';state='PASS_R29VAL1_TARGET_PREFLIGHT';outputRoot=$output;caseCount=39;maximumConcurrentChildren=3;maximumTotalSeconds=840;imageDecoded=$false;sourceHashingPerformed=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress
    return
}
foreach($test in @(@($r28Test,'PASS_R28_PACKAGED_SYNTHETIC_33_OF_33'),@($r29Test,'PASS_R29_PACKAGED_SYNTHETIC_13_OF_13'))){
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}"'-f$test[0]);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'R29VAL1 synthetic test did not start.';$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();Require ($process.WaitForExit(120000)) 'R29VAL1 synthetic test timed out.';Require ($process.ExitCode-eq0) ('R29VAL1 synthetic test failed: '+$stderr.Result);Require ($stdout.Result.Trim()-eq$test[1]) 'R29VAL1 synthetic test state changed.';$process.Dispose()
}
$arguments=('-B "{0}" --contract "{1}" --frozen-cases "{2}" --detector "{3}" --config "{4}" --python "{5}" --output "{6}" --maximum-dimension 2400 --maximum-per-case-seconds 180'-f$runner,$contract,$frozen,$detector,$config,$python,$output)
$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=$arguments;$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$process=New-Object Diagnostics.Process;$process.StartInfo=$start;$timer=[Diagnostics.Stopwatch]::StartNew();Require $process.Start() 'R29VAL1 validation runner did not start.';$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(840000)){try{$process.Kill()}catch{};throw 'R29VAL1 validation runner timed out.'};$timer.Stop();Require ($process.ExitCode-eq0) ('R29VAL1 validation runner failed: '+$stderr.Result)
$summaryPath=Join-Path $output 'SUMMARY.json';Require (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'R29VAL1 summary absent.';$summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json
Require ([int]$summary.caseCount-eq39) 'R29VAL1 result cardinality changed.';Require ([string]$summary.state-in@('PASS_R29VAL1_ALL_EXPECTED_OUTCOMES','HOLD_R29VAL1_OUTCOME_MISMATCH')) 'R29VAL1 result state invalid.';Require (-not[bool]$summary.sourceMutationPerformed) 'R29VAL1 source mutation reported.'
[ordered]@{schema='argos_o3b21_r29val1_signed_execution_v1';state='PASS_O3B21_R29VAL1_39_EXECUTIONS_COMPLETE';detectorGateState=[string]$summary.state;outputRoot=$output;elapsedSeconds=[Math]::Round($timer.Elapsed.TotalSeconds,3);caseCount=39;frozenCaseCount=32;sameScanControlCount=1;currentRecipeSmokeCount=6;syntheticTestCount=46;summary=$summary;summarySha256=Sha $summaryPath;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingTaskOrProcessActionPerformed=$false;providerActivationPerformed=$false;holdsAutomaticallyCleared=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}|ConvertTo-Json -Depth 64 -Compress
'PASS_O3B21_R29VAL1_39_EXECUTIONS_COMPLETE'
