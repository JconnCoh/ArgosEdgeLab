#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}

$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R19.py';$engineHash='FD6ED2A8C52584490EAEBA6836581A15BAD9479732746039F14E4C175A9004B8'
$r18='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py';$r18Hash='DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$r17='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py';$r17Hash='B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
$r15='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py';$r15Hash='F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R7.json';$configHash='9C40E9FE99735B8E49BC3713204E0A301A82D68D3A80EEA37894F66EB284DE03'
$casesPath=Join-Path $PSScriptRoot 'R19_REGRESSION_CASES.json';$casesHash='9FCE3CC7274FC54BB188427D24C129FC89E6F7222825468B9E464D91F73551C7'
Require ($env:COMPUTERNAME-eq'A1025645101') 'R19 regression reached the wrong computer.'
foreach($pin in @(@($python,$pythonHash),@($engine,$engineHash),@($r18,$r18Hash),@($r17,$r17Hash),@($r15,$r15Hash),@($configPath,$configHash),@($casesPath,$casesHash))){Require ((Sha $pin[0])-eq$pin[1]) "Pinned dependency changed: $($pin[0])"}
$cases=@((Get-Content -LiteralPath $casesPath -Raw|ConvertFrom-Json).cases);Require ($cases.Count-eq10) 'R19 regression case cardinality changed.'
foreach($case in $cases){
  Require ((Sha ([string]$case.bf))-eq[string]$case.bfSha256) "BF source changed: $($case.id)"
  Require ((Sha ([string]$case.df))-eq[string]$case.dfSha256) "DF source changed: $($case.id)"
  Require (-not(Test-Path -LiteralPath ([string]$case.output))) "Create-new output exists: $($case.output)"
  Require (-not(Test-Path -LiteralPath ([string]$case.output+'.job.json'))) "Create-new job exists: $($case.output)"
}
if($Preflight){[ordered]@{state='PASS_O3B10_R19_REGRESSION_PREFLIGHT';caseCount=$cases.Count;processStarted=$false;imageDecoded=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json;$results=@()
foreach($case in $cases){
  $jobPath=[string]$case.output+'.job.json';$job=[ordered]@{bf=[string]$case.bf;df=[string]$case.df;bfSha256=[string]$case.bfSha256;dfSha256=[string]$case.dfSha256;output=[string]$case.output;radialEngine=[string]$config.radialEngine;radialEngineSha256=[string]$config.radialEngineSha256;radialParameters=$config.radialParameters;maximumDimension=2400}
  [IO.File]::WriteAllText($jobPath,($job|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
  $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}" --job "{1}"'-f$engine,$jobPath);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
  $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() "R19 detector did not start: $($case.id)";$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(900000)){try{$process.Kill()}catch{};throw "R19 detector timed out: $($case.id)"};Require ($process.ExitCode-eq0) ("R19 detector failed: $($case.id): "+$stderr.Result)
  $resultPath=Join-Path ([string]$case.output) 'RESULT.json';$bfReview=Join-Path ([string]$case.output) 'BF_review.jpg';$dfReview=Join-Path ([string]$case.output) 'DF_review.jpg';foreach($path in @($resultPath,$bfReview,$dfReview)){Require (Test-Path -LiteralPath $path -PathType Leaf) "R19 output missing: $path"}
  $detector=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json;$pairCount=[int]$detector.pairedCandidateCount
  if([string]$case.expected-eq'UNIQUE'){Require ($pairCount-eq1-and[string]$detector.state-ne'HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED') "R19 unique control failed: $($case.id)"}
  if([string]$case.expected-eq'ZERO'){Require ($pairCount-eq0) "R19 damaged negative produced a notch: $($case.id)"}
  $results+=[ordered]@{id=[string]$case.id;expected=[string]$case.expected;detector=$detector;bfReviewSha256=Sha $bfReview;bfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview));dfReviewSha256=Sha $dfReview;dfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))}
}
[ordered]@{schema='argos_ocv03_o3b10_r19_actual_wafer_regression_v1';state='PASS_O3B10_R19_ACTUAL_WAFER_REGRESSION_EXECUTED';results=$results;sourceMutationPerformed=$false;existingProcessActionPerformed=$false;ownedChildProcessCount=10;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 32 -Compress
