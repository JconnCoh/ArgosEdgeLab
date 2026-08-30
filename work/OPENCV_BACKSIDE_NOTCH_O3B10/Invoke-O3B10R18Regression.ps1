#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}

$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py'
$engineHash='DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$base='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py'
$baseHash='F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R6.json'
$configHash='ACBD63E620349DD83A417F4DC29DCEDDC07765036D49D57DDB305F2C637BF2A0'
$casesPath=Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json'
$casesHash='7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
Require ($env:COMPUTERNAME-eq'A1025645101') 'R18 regression reached the wrong computer.'
foreach($pin in @(@($python,$pythonHash),@($engine,$engineHash),@($base,$baseHash),@($configPath,$configHash),@($casesPath,$casesHash))){Require ((Sha $pin[0])-eq$pin[1]) "Pinned dependency changed: $($pin[0])"}
$cases=@((Get-Content -LiteralPath $casesPath -Raw|ConvertFrom-Json).cases)
Require ($cases.Count-eq10) 'R18 regression case cardinality changed.'
foreach($case in $cases){
  Require ((Sha ([string]$case.bf))-eq[string]$case.bfSha256) "BF source changed: $($case.id)"
  Require ((Sha ([string]$case.df))-eq[string]$case.dfSha256) "DF source changed: $($case.id)"
  Require (-not(Test-Path -LiteralPath ([string]$case.output))) "Create-new output exists: $($case.output)"
  Require (-not(Test-Path -LiteralPath ([string]$case.output+'.job.json'))) "Create-new job exists: $($case.output)"
}
if($Preflight){[ordered]@{state='PASS_O3B10_R18_REGRESSION_PREFLIGHT';caseCount=$cases.Count;processStarted=$false;imageDecoded=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json;$results=@()
foreach($case in $cases){
  $jobPath=[string]$case.output+'.job.json';$job=[ordered]@{bf=[string]$case.bf;df=[string]$case.df;bfSha256=[string]$case.bfSha256;dfSha256=[string]$case.dfSha256;output=[string]$case.output;radialEngine=[string]$config.radialEngine;radialEngineSha256=[string]$config.radialEngineSha256;radialParameters=$config.radialParameters;maximumDimension=2400}
  [IO.File]::WriteAllText($jobPath,($job|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
  $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}" --job "{1}"'-f$engine,$jobPath);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
  $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() "R18 detector did not start: $($case.id)";$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(900000)){try{$process.Kill()}catch{};throw "R18 detector timed out: $($case.id)"};Require ($process.ExitCode-eq0) ("R18 detector failed: $($case.id): "+$stderr.Result)
  $resultPath=Join-Path ([string]$case.output) 'RESULT.json';$bfReview=Join-Path ([string]$case.output) 'BF_review.jpg';$dfReview=Join-Path ([string]$case.output) 'DF_review.jpg';foreach($path in @($resultPath,$bfReview,$dfReview)){Require (Test-Path -LiteralPath $path -PathType Leaf) "R18 output missing: $path"}
  $detector=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json;$pairCount=[int]$detector.pairedCandidateCount
  if([string]$case.expected-eq'UNIQUE'){Require ($pairCount-eq1-and[string]$detector.state-ne'HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED') "R18 unique control failed: $($case.id)"}
  if([string]$case.expected-eq'ZERO'){Require ($pairCount-eq0) "R18 damaged negative produced a notch: $($case.id)"}
  $results+=[ordered]@{id=[string]$case.id;expected=[string]$case.expected;detector=$detector;bfReviewSha256=Sha $bfReview;bfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview));dfReviewSha256=Sha $dfReview;dfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))}
}
[ordered]@{schema='argos_ocv03_o3b10_r18_actual_wafer_regression_v1';state='PASS_O3B10_R18_ACTUAL_WAFER_REGRESSION_EXECUTED';results=$results;sourceMutationPerformed=$false;existingProcessActionPerformed=$false;ownedChildProcessCount=10;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 32 -Compress
