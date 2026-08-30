#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}

$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R20.py';$engineHash='B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
$r18='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py';$r18Hash='DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$r17='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py';$r17Hash='B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
$r15='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py';$r15Hash='F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R8.json';$configHash='CEECD910C2EE7CFE0DA1486B72DEC5F59CE3F66C4219CB55BB4C10263D436E2A'
$casesPath=Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json';$casesHash='7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
Require ($env:COMPUTERNAME-eq'A1025645101') 'R20 regression reached the wrong computer.'
foreach($pin in @(@($python,$pythonHash),@($engine,$engineHash),@($r18,$r18Hash),@($r17,$r17Hash),@($r15,$r15Hash),@($configPath,$configHash),@($casesPath,$casesHash))){Require ((Sha $pin[0])-eq$pin[1]) "Pinned dependency changed: $($pin[0])"}
$cases=@((Get-Content -LiteralPath $casesPath -Raw|ConvertFrom-Json).cases);Require ($cases.Count-eq10) 'R20 regression case cardinality changed.'
for($index=0;$index-lt$cases.Count;$index++){
  $case=$cases[$index];foreach($field in @('bfSha256','dfSha256')){Require ([string]$case.$field-match'^[A-F0-9]{64}$') "Invalid frozen SHA-256 field: $($case.id) $field"}
  $output=('D:/B20{0}'-f[char](65+$index));$case|Add-Member -NotePropertyName r20Output -NotePropertyValue $output -Force
  Require ((Sha ([string]$case.bf))-eq[string]$case.bfSha256) "BF source changed: $($case.id)"
  Require ((Sha ([string]$case.df))-eq[string]$case.dfSha256) "DF source changed: $($case.id)"
  Require (-not(Test-Path -LiteralPath $output)) "Create-new output exists: $output"
  Require (-not(Test-Path -LiteralPath ($output+'.job.json'))) "Create-new job exists: $output"
}
if($Preflight){[ordered]@{state='PASS_O3B10_R20_REGRESSION_PREFLIGHT';caseCount=$cases.Count;frozenCaseManifestSha256=$casesHash;onlyDerivedField='r20Output';processStarted=$false;imageDecoded=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json;$results=@()
foreach($case in $cases){
  $output=[string]$case.r20Output;$jobPath=$output+'.job.json';$job=[ordered]@{bf=[string]$case.bf;df=[string]$case.df;bfSha256=[string]$case.bfSha256;dfSha256=[string]$case.dfSha256;output=$output;radialEngine=[string]$config.radialEngine;radialEngineSha256=[string]$config.radialEngineSha256;radialParameters=$config.radialParameters;maximumDimension=2400}
  [IO.File]::WriteAllText($jobPath,($job|ConvertTo-Json -Depth 16),[Text.UTF8Encoding]::new($false))
  $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}" --job "{1}"'-f$engine,$jobPath);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
  $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() "R20 detector did not start: $($case.id)";$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync();if(-not$process.WaitForExit(900000)){try{$process.Kill()}catch{};throw "R20 detector timed out: $($case.id)"};Require ($process.ExitCode-eq0) ("R20 detector failed: $($case.id): "+$stderr.Result)
  $resultPath=Join-Path $output 'RESULT.json';$bfReview=Join-Path $output 'BF_review.jpg';$dfReview=Join-Path $output 'DF_review.jpg';foreach($path in @($resultPath,$bfReview,$dfReview)){Require (Test-Path -LiteralPath $path -PathType Leaf) "R20 output missing: $path"}
  $detector=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json;$pairCount=[int]$detector.pairedCandidateCount
  if([string]$case.expected-eq'UNIQUE'){Require ($pairCount-eq1-and[string]$detector.state-ne'HOLD_BACKSIDE_NOTCH_ANALYSIS_FAILED') "R20 unique control failed: $($case.id)"}
  if([string]$case.expected-eq'ZERO'){Require ($pairCount-eq0) "R20 damaged negative produced a notch: $($case.id)"}
  $results+=[ordered]@{id=[string]$case.id;expected=[string]$case.expected;detector=$detector;bfReviewSha256=Sha $bfReview;bfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($bfReview));dfReviewSha256=Sha $dfReview;dfReviewBase64=[Convert]::ToBase64String([IO.File]::ReadAllBytes($dfReview))}
}
[ordered]@{schema='argos_ocv03_o3b10_r20_actual_wafer_regression_v1';state='PASS_O3B10_R20_ACTUAL_WAFER_REGRESSION_EXECUTED';results=$results;frozenR18CaseManifestSha256=$casesHash;sourceMutationPerformed=$false;existingProcessActionPerformed=$false;ownedChildProcessCount=10;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 32 -Compress
