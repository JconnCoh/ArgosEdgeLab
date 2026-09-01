#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}

$python='D:\AFCV1\rt\python.exe'
$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$runner=Join-Path $PSScriptRoot 'Diagnose-R28RotationHolderAblation.py'
$runnerHash='0E5A872FCC8C175F2E3B6BD6F6F5CE885F277ABDDA74C85F1C04A424652D80D5'
$cases=Join-Path $PSScriptRoot 'R28ROT1_CASES.json'
$casesHash='90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB'
$detector=Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR28.py'
$detectorHash='4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466'
$config=Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json'
$configHash='27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$test=Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR28.py'
$testHash='0BF3E7DE98D586833FA392D686ADFA4CB341F73672B6C7113728604E2AD4901F'
$output='D:\R28ROT1'

foreach($pin in @(@($runner,$runnerHash),@($cases,$casesHash),@($detector,$detectorHash),@($config,$configHash),@($test,$testHash))){
    Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package dependency absent: $($pin[0])"
    Require ((Sha $pin[0])-eq$pin[1]) "Package dependency changed: $($pin[0])"
}
if($PackageLeafPreflight){
    [ordered]@{schema='argos_o3b21_r28rot1_package_leaf_preflight_v1';state='PASS_R28ROT1_EXACT_PACKAGED_LEAVES';caseCount=2;executionCount=8;maximumPerExecutionSeconds=75;maximumRunnerSeconds=720;imageDecoded=$false;processStarted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
    return
}
Require ($env:COMPUTERNAME-eq'A1025645101') 'R28ROT1 reached the wrong computer.'
Require (Test-Path -LiteralPath $python -PathType Leaf) 'Pinned Python runtime absent.'
Require ((Sha $python)-eq$pythonHash) 'Pinned Python runtime changed.'
Require (-not(Test-Path -LiteralPath $output)) 'Create-new R28ROT1 output exists.'
if($Preflight){
    [ordered]@{schema='argos_o3b21_r28rot1_target_preflight_v1';state='PASS_R28ROT1_TARGET_PREFLIGHT';outputRoot=$output;caseCount=2;executionCount=8;maximumTotalSeconds=840;imageDecoded=$false;sourceHashingPerformed=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress
    return
}

$testStart=New-Object Diagnostics.ProcessStartInfo
$testStart.FileName=$python;$testStart.Arguments=('-B "{0}"'-f$test);$testStart.WorkingDirectory=$PSScriptRoot
$testStart.UseShellExecute=$false;$testStart.CreateNoWindow=$true;$testStart.RedirectStandardOutput=$true;$testStart.RedirectStandardError=$true
$testProcess=New-Object Diagnostics.Process;$testProcess.StartInfo=$testStart
Require $testProcess.Start() 'R28ROT1 synthetic test did not start.'
$testOut=$testProcess.StandardOutput.ReadToEndAsync();$testErr=$testProcess.StandardError.ReadToEndAsync()
Require ($testProcess.WaitForExit(120000)) 'R28ROT1 synthetic test timed out.'
Require ($testProcess.ExitCode-eq0) ('R28ROT1 synthetic test failed: '+$testErr.Result)
Require ($testOut.Result.Trim()-eq'PASS_R28_PACKAGED_SYNTHETIC_33_OF_33') 'R28ROT1 synthetic test state changed.'

$start=New-Object Diagnostics.ProcessStartInfo
$start.FileName=$python
$start.Arguments=('-B "{0}" --cases "{1}" --detector "{2}" --config "{3}" --output "{4}"'-f$runner,$cases,$detector,$config,$output)
$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true
$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
$process=New-Object Diagnostics.Process;$process.StartInfo=$start
$timer=[Diagnostics.Stopwatch]::StartNew()
Require $process.Start() 'R28ROT1 diagnostic runner did not start.'
$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
if(-not$process.WaitForExit(720000)){try{$process.Kill()}catch{};throw 'R28ROT1 diagnostic runner timed out.'}
$timer.Stop()
Require ($process.ExitCode-eq0) ('R28ROT1 diagnostic runner failed: '+$stderr.Result)
$summaryPath=Join-Path $output 'SUMMARY.json'
Require (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'R28ROT1 summary absent.'
$summary=Get-Content -LiteralPath $summaryPath -Raw|ConvertFrom-Json
Require ([string]$summary.state-eq'COMPLETE_DIAGNOSTIC_ONLY_NO_AUTOMATIC_DISPOSITION') 'R28ROT1 summary state changed.'
Require ([int]$summary.executionCount-eq8) 'R28ROT1 execution cardinality changed.'
Require (@($summary.sourceHashesAfter|Where-Object{-not$_.bfUnchanged-or-not$_.dfUnchanged}).Count-eq0) 'R28ROT1 source hash preservation failed.'
Require (-not[bool]$summary.productionEligible) 'R28ROT1 production authority changed.'
$assets=New-Object Collections.Generic.List[object]
foreach($variant in @('C0_original_exact','C0_original_noholder','C0_ccw90_exact','C0_ccw90_noholder')){
    foreach($leaf in @('BF_review.jpg','DF_review.jpg')){
        $path=Join-Path (Join-Path $output $variant) $leaf
        Require (Test-Path -LiteralPath $path -PathType Leaf) "R28ROT1 review asset absent: $variant/$leaf"
        $item=Get-Item -LiteralPath $path
        $assets.Add([pscustomobject][ordered]@{variant=$variant;leaf=$leaf;bytes=$item.Length;sha256=Sha $path;path=$path})
    }
}
$assetBytes=[int64]0;foreach($asset in $assets){$assetBytes+=[int64]$asset.bytes}
$embed=$assetBytes-le12582912
if($embed){foreach($asset in $assets){$asset|Add-Member -NotePropertyName base64 -NotePropertyValue ([Convert]::ToBase64String([IO.File]::ReadAllBytes([string]$asset.path)))}}
[ordered]@{schema='argos_o3b21_r28rot1_rotation_holder_ablation_v1';state='PASS_O3B21_R28ROT1_EIGHT_DIAGNOSTIC_EXECUTIONS';outputRoot=$output;elapsedSeconds=[Math]::Round($timer.Elapsed.TotalSeconds,3);executionCount=8;summary=$summary;failedCaseReviewAssets=$assets;failedCaseReviewBytes=$assetBytes;failedCaseReviewAssetsEmbedded=$embed;syntheticTestState=$testOut.Result.Trim();sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingTaskOrProcessActionPerformed=$false;providerActivationPerformed=$false;noHolderMayClearHold=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}|ConvertTo-Json -Depth 32 -Compress
'PASS_O3B21_R28ROT1_EIGHT_DIAGNOSTIC_EXECUTIONS'
