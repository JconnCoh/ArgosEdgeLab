#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}

$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$contract=Join-Path $PSScriptRoot 'R30VAL1_CONTRACT.json';$contractHash='B4E4A64253AECB61575EF1C76068094DBE12DFEDA6A53A768912144150C88DB5'
$runner=Join-Path $PSScriptRoot 'Run-R30ValidationBatch.py';$runnerHash='CD87CB23EACC0CF45A0B565DE8B77613222E5840B19B37EA92DC2A0442C636BC'
$detector=Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR30.py';$detectorHash='A300D2667DE021A9C1E177CF475E4A04ED3B87F41D7BFA9DCEF0A1DB06BE8625'
$config=Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json';$configHash='27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$frozen=Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json';$frozenHash='7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
$r28Test=Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR28.py';$r28TestHash='0BF3E7DE98D586833FA392D686ADFA4CB341F73672B6C7113728604E2AD4901F'
$r29Test=Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR29.py';$r29TestHash='C62054EFC2C2F573D48C452196D28B18B6BC5C0045DCA45CD2ABA1269FD1E1E7'
$r30Test=Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR30.py';$r30TestHash='E22233AEA4FA9757448B6BE27119E557C16D05CFEE05E67BD4941BFD29EBEA8B'
$output='D:\R30VAL1'
foreach($pin in @(@($contract,$contractHash),@($runner,$runnerHash),@($detector,$detectorHash),@($config,$configHash),@($frozen,$frozenHash),@($r28Test,$r28TestHash),@($r29Test,$r29TestHash),@($r30Test,$r30TestHash))){
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package dependency absent: $($pin[0])"
    Require ((Sha $pin[0])-eq$pin[1]) "Package dependency changed: $($pin[0])"
}
if($PackageLeafPreflight){
    [ordered]@{schema='argos_o3b21_r30val1_package_leaf_preflight_v1';state='PASS_R30VAL1_EXACT_PACKAGED_LEAVES';caseCount=70;frozenCaseCount=32;currentPatternedFrontCount=25;currentUnpatternedFrontCount=12;syntheticTestCount=59;imageDecoded=$false;processStarted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
    return
}
Require ($env:COMPUTERNAME-eq'A1025645101') 'R30VAL1 reached the wrong computer.'
Require (Test-Path -LiteralPath $python -PathType Leaf) 'Pinned Python runtime absent.'
Require ((Sha $python)-eq$pythonHash) 'Pinned Python runtime changed.'
Require (-not(Test-Path -LiteralPath $output)) 'Create-new R30VAL1 output exists.'
if($Preflight){
    [ordered]@{schema='argos_o3b21_r30val1_target_preflight_v1';state='PASS_R30VAL1_TARGET_PREFLIGHT';outputRoot=$output;caseCount=70;maximumConcurrentChildren=3;maximumTotalSeconds=1200;imageDecoded=$false;sourceHashingPerformed=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress
    return
}
foreach($test in @(@($r28Test,'PASS_R28_PACKAGED_SYNTHETIC_33_OF_33'),@($r29Test,'PASS_R29_PACKAGED_SYNTHETIC_13_OF_13'),@($r30Test,'PASS_R30_PACKAGED_SYNTHETIC_13_OF_13'))){
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}"'-f$test[0]);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'R30VAL1 synthetic test did not start.';$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();Require ($process.WaitForExit(120000)) 'R30VAL1 synthetic test timed out.';Require ($process.ExitCode-eq0) ('R30VAL1 synthetic test failed: '+$stderr.Result);Require ($stdout.Result.Trim()-eq$test[1]) 'R30VAL1 synthetic test state changed.';$process.Dispose()
}
$arguments=('-B "{0}" --contract "{1}" --frozen-cases "{2}" --detector "{3}" --config "{4}" --python "{5}" --output "{6}" --maximum-dimension 2400 --maximum-per-case-seconds 180'-f$runner,$contract,$frozen,$detector,$config,$python,$output)
$start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=$arguments;$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$process=New-Object Diagnostics.Process;$process.StartInfo=$start;$timer=[Diagnostics.Stopwatch]::StartNew();Require $process.Start() 'R30VAL1 validation runner did not start.';$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(1200000)){try{$process.Kill()}catch{};throw 'R30VAL1 validation runner timed out.'};$timer.Stop();Require ($process.ExitCode-eq0) ('R30VAL1 validation runner failed: '+$stderr.Result)
$summaryPath=Join-Path $output 'SUMMARY.json';Require (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'R30VAL1 summary absent.';$summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json
Require ([int]$summary.caseCount-eq70) 'R30VAL1 result cardinality changed.';Require ([string]$summary.state-in@('PASS_R30VAL1_ALL_EXPECTED_OUTCOMES','HOLD_R30VAL1_OUTCOME_MISMATCH')) 'R30VAL1 result state invalid.';Require (-not[bool]$summary.sourceMutationPerformed) 'R30VAL1 source mutation reported.'
[ordered]@{schema='argos_o3b21_r30val1_signed_execution_v1';state='PASS_O3B21_R30VAL1_70_EXECUTIONS_COMPLETE';detectorGateState=[string]$summary.state;outputRoot=$output;elapsedSeconds=[Math]::Round($timer.Elapsed.TotalSeconds,3);caseCount=70;frozenCaseCount=32;sameScanControlCount=1;currentPatternedFrontCount=25;currentUnpatternedFrontCount=12;syntheticTestCount=59;summary=$summary;summarySha256=Sha $summaryPath;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingTaskOrProcessActionPerformed=$false;providerActivationPerformed=$false;holdsAutomaticallyCleared=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}|ConvertTo-Json -Depth 64 -Compress
'PASS_O3B21_R30VAL1_70_EXECUTIONS_COMPLETE'
