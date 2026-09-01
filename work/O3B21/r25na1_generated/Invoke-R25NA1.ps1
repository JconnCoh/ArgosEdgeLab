#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Has($Value,[string]$Name) { $null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name }
function BytesSha([byte[]]$Bytes) { $s=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($s.ComputeHash($Bytes))).Replace('-','')}finally{$s.Dispose()} }
function CircularDistance([double]$Left,[double]$Right) { $d=[Math]::Abs($Left-$Right)%360.0; [Math]::Min($d,360.0-$d) }
function AngleInsideSpan([double]$Angle,$Span) {
    $a=($Angle%360.0+360.0)%360.0;$s=([double]$Span.startAngleDegrees%360.0+360.0)%360.0;$e=([double]$Span.endAngleDegrees%360.0+360.0)%360.0
    if($s-le$e){return $a-ge$s-and$a-le$e};return $a-ge$s-or$a-le$e
}
function SpanDistance([double]$Angle,$Spans) {
    $items=@($Spans);if($items.Count-eq 0){return [pscustomobject]@{outside=$true;distance=[double]::PositiveInfinity}}
    $outside=$true;$nearest=[double]::PositiveInfinity
    foreach($span in $items){if(AngleInsideSpan $Angle $span){$outside=$false};$nearest=[Math]::Min($nearest,[Math]::Min((CircularDistance $Angle ([double]$span.startAngleDegrees)),(CircularDistance $Angle ([double]$span.endAngleDegrees))))}
    [pscustomobject]@{outside=$outside;distance=$nearest}
}

$python='D:\AFCV1\rt\python.exe';$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine=Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR25.py';$engineHash='6A7977E4DAFE692FCE6E7DE4740C94EE66D5F79ECD62FDF190CB5EE8E4862274'
$r20='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R20.py';$r20Hash='B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
$r18='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py';$r18Hash='DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
$r17='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py';$r17Hash='B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
$r15='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py';$r15Hash='F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
$configPath=Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json';$configHash='27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$manifestPath=Join-Path $PSScriptRoot 'R25NA1_CASES.json';$manifestHash='65E352134BDD905093E4F28E5B80FBC3FD3891C9C8D3F98F353CD053DCBB8998'
$selectorPath=Join-Path $PSScriptRoot 'R25_NA1_LEXICAL_PASS_SOURCE_DISCOVERY_SELECTOR.json'
$selectionPath=Join-Path $PSScriptRoot 'R25_NA1_LEXICAL_PASS_SOURCE_DISCOVERY_RESULT.json'
$freezePath=Join-Path $PSScriptRoot 'R25_NA1_EXACT_SOURCE_RECORD_FREEZE.json'

$packagePins=@(@($engine,$engineHash),@($configPath,$configHash),@($manifestPath,$manifestHash),@($selectorPath,'DD642F800ED0C5140980348E13BCD5E06EA7730671360F3BDE0B39AE56ECBD31'),@($selectionPath,'3F5BFABB7E8C9221D07537F07D26F8AA95F8C372DB353CAEFD3EB8C731534FAC'),@($freezePath,'D3481DA814F8F64EC6027FC8B9482924BDE5A2C572530FA36D8511E0C0804971'))
foreach($pin in $packagePins){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package dependency absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Package dependency changed: $($pin[0])"}
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
Require ([string]$manifest.outputRoot-eq'D:/R25NA1') 'Package output root changed.'
Require ([int]$manifest.selection.candidateCount-eq 24) 'Package candidate count changed.'
Require (-not [bool]$manifest.selection.selectorRelaxationAllowed) 'Selector relaxation was enabled.'
if($PackageLeafPreflight){[ordered]@{schema='argos_o3b21_r25na1_package_leaf_preflight_v1';state='PASS_R25NA1_EXACT_PACKAGED_ENTRY_MANIFEST_LEAF';candidateCount=24;manifestSha256=Sha $manifestPath;selectorSha256=Sha $selectorPath;selectionSha256=Sha $selectionPath;sourceFreezeSha256=Sha $freezePath;detectorSha256=Sha $engine;configSha256=Sha $configPath;imageDecoded=$false;processStarted=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5 -Compress;return}

Require ($env:COMPUTERNAME-eq'A1025645101') 'R25NA1 reached the wrong computer.'
foreach($pin in @(@($python,$pythonHash),@($r20,$r20Hash),@($r18,$r18Hash),@($r17,$r17Hash),@($r15,$r15Hash))){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Pinned dependency absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Pinned dependency changed: $($pin[0])"}
$selector=Get-Content -LiteralPath $selectorPath -Raw|ConvertFrom-Json
$selection=Get-Content -LiteralPath $selectionPath -Raw|ConvertFrom-Json
$freeze=Get-Content -LiteralPath $freezePath -Raw|ConvertFrom-Json
Require ([string]$selector.input.resultsCsvSha256-eq'B74B86ED07D9632B61A5B4BB02B61597AC364E132645648202EA92F3138D5DE5') 'Frozen R20 RESULTS pin changed.'
Require ([string]$selection.selector.sha256-eq(Sha $selectorPath)) 'Selection does not bind packaged selector.'
Require ([string]$freeze.selectionResultSha256-eq(Sha $selectionPath)) 'Freeze does not bind packaged selection.'
$selected=@($selection.selected);Require ($selected.Count-eq 24) 'Frozen selected count changed.'
$orderedIds=@($selected|ForEach-Object{[string]$_.identity});Require ((@($orderedIds|Sort-Object)-join"`n")-eq($orderedIds-join"`n")) 'Frozen selection order changed.'
Require (@($orderedIds|Select-Object -Unique).Count-eq 24) 'Frozen selection contains duplicate identities.'

$records=New-Object Collections.Generic.List[object];$cases=New-Object Collections.Generic.List[object]
foreach($row in $selected){
    $itemPath=Join-Path (Split-Path -Parent ([string]$row.diagnosticRoot)) 'result.json';Require (Test-Path -LiteralPath $itemPath -PathType Leaf) "Source record absent: $itemPath"
    $item=Get-Content -LiteralPath $itemPath -Raw|ConvertFrom-Json;Require ([string]$item.identity-eq[string]$row.identity) "Source identity changed: $($row.identity)"
    foreach($side in @('bf','df')){Require (Has $item $side) "Source side absent: $($row.identity) $side";Require ([string]$item.$side.sha256-match'^[A-Fa-f0-9]{64}$') "Source hash invalid: $($row.identity) $side";Require (Test-Path -LiteralPath ([string]$item.$side.path) -PathType Leaf) "Source image absent: $($row.identity) $side"}
    $bfItem=Get-Item -LiteralPath ([string]$item.bf.path);$dfItem=Get-Item -LiteralPath ([string]$item.df.path)
    $records.Add([ordered]@{identity=[string]$item.identity;bfPath=[string]$item.bf.path;bfBytes=[int64]$bfItem.Length;bfSha256=([string]$item.bf.sha256).ToUpperInvariant();dfPath=[string]$item.df.path;dfBytes=[int64]$dfItem.Length;dfSha256=([string]$item.df.sha256).ToUpperInvariant()})
    $cases.Add([pscustomobject][ordered]@{id=[string]$item.identity;bf=[string]$item.bf.path;bfSha256=([string]$item.bf.sha256).ToUpperInvariant();df=[string]$item.df.path;dfSha256=([string]$item.df.sha256).ToUpperInvariant();sourceRecordPath=$itemPath})
}
$canonical=$records|ConvertTo-Json -Compress -Depth 4;$canonicalBytes=(New-Object Text.UTF8Encoding($false)).GetBytes($canonical)
Require ($canonical.Length-eq[int]$manifest.sourceEvidence.canonicalSourceJsonCharacters) 'Canonical source JSON length changed.'
Require ((BytesSha $canonicalBytes)-eq[string]$manifest.sourceEvidence.canonicalSourceJsonSha256) 'Canonical source metadata hash changed.'
$outputRoot=[string]$manifest.outputRoot;Require (-not(Test-Path -LiteralPath $outputRoot)) "Create-new R25NA1 output exists: $outputRoot"
if($Preflight){[ordered]@{schema='argos_o3b21_r25na1_preflight_v1';state='PASS_O3B21_R25NA1_EXACT_24_SOURCE_PREFLIGHT';outputRoot=$outputRoot;candidateCount=24;canonicalSourceJsonCharacters=$canonical.Length;canonicalSourceJsonSha256=BytesSha $canonicalBytes;imageDecoded=$false;sourceHashingPerformed=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Depth 6 -Compress;return}

[void](New-Item -ItemType Directory -Path $outputRoot);$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
$overall=[Diagnostics.Stopwatch]::StartNew();$results=New-Object Collections.Generic.List[object];$assetPaths=New-Object Collections.Generic.List[object];$eligible=$null
for($ordinal=0;$ordinal-lt$cases.Count;$ordinal++){
    $case=$cases[$ordinal];$bfHash=Sha $case.bf;$dfHash=Sha $case.df;Require ($bfHash-eq$case.bfSha256) "BF source changed: $($case.id)";Require ($dfHash-eq$case.dfSha256) "DF source changed: $($case.id)"
    $ordinalText='{0:D2}'-f$ordinal;$caseRoot=Join-Path $outputRoot ('O'+$ordinalText);$jobPath=Join-Path $outputRoot ('J'+$ordinalText+'.json')
    $job=[ordered]@{bf=$case.bf;df=$case.df;bfSha256=$bfHash;dfSha256=$dfHash;output=$caseRoot;radialEngine=[string]$config.radialEngine;radialEngineSha256=[string]$config.radialEngineSha256;radialParameters=$config.radialParameters;maximumDimension=[int]$manifest.maximumDimension}
    [IO.File]::WriteAllText($jobPath,($job|ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
    $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}" --job "{1}"'-f$engine,$jobPath);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;$timer=[Diagnostics.Stopwatch]::StartNew();Require $process.Start() "R25NA1 detector did not start: $($case.id)";$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not$process.WaitForExit(([int]$manifest.runtimeBoundary.maximumPerCaseSeconds*1000))){try{$process.Kill()}catch{};throw "R25NA1 detector case timed out: $($case.id)"};$timer.Stop();Require ($process.ExitCode-eq 0) ("R25NA1 detector failed: $($case.id): "+$stderr.Result)
    $resultPath=Join-Path $caseRoot 'RESULT.json';Require (Test-Path -LiteralPath $resultPath -PathType Leaf) "R25NA1 result absent: $($case.id)";$detector=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
    $assets=New-Object Collections.Generic.List[object];foreach($asset in @(@('BF_REVIEW',(Join-Path $caseRoot 'BF_review.jpg')),@('DF_REVIEW',(Join-Path $caseRoot 'DF_review.jpg')),@('BF_HOLDER_MASK',(Join-Path $caseRoot 'BF_holder_exclusion.png')),@('DF_HOLDER_MASK',(Join-Path $caseRoot 'DF_holder_exclusion.png')))){Require (Test-Path -LiteralPath $asset[1] -PathType Leaf) "R25NA1 evidence asset absent: $($case.id) $($asset[0])";$i=Get-Item -LiteralPath $asset[1];$a=[pscustomobject][ordered]@{role=$asset[0];path=$i.FullName;bytes=$i.Length;sha256=Sha $i.FullName};$assets.Add($a);$assetPaths.Add($a)}
    $evaluation=[ordered]@{eligible=$false;reason='PAIRED_CANDIDATE_COUNT_NOT_ONE'}
    if([int]$detector.pairedCandidateCount-eq 1){$pair=@($detector.pairedCandidates)[0];$bfSpan=SpanDistance ([double]$pair.bfAngleDegrees) @($detector.bf.holderExclusion.spans);$dfSpan=SpanDistance ([double]$pair.dfAngleDegrees) @($detector.df.holderExclusion.spans);$ok=$bfSpan.outside-and$dfSpan.outside-and$bfSpan.distance-ge[double]$manifest.eligibility.minimumDistanceDegreesFromNearestHolderBoundaryInBothChannels-and$bfSpan.distance-le[double]$manifest.eligibility.maximumDistanceDegreesFromNearestHolderBoundaryInBothChannels-and$dfSpan.distance-ge[double]$manifest.eligibility.minimumDistanceDegreesFromNearestHolderBoundaryInBothChannels-and$dfSpan.distance-le[double]$manifest.eligibility.maximumDistanceDegreesFromNearestHolderBoundaryInBothChannels;$evaluation=[ordered]@{eligible=$ok;reason=if($ok){'PASS_FROZEN_NOTCH_ADJACENT_RULE'}else{'UNIQUE_PAIR_OUTSIDE_FROZEN_DISTANCE_OR_SPAN_RULE'};bfDistanceDegrees=$bfSpan.distance;dfDistanceDegrees=$dfSpan.distance;bfOutsideEverySpan=$bfSpan.outside;dfOutsideEverySpan=$dfSpan.outside}}
    $record=[pscustomobject][ordered]@{ordinal=$ordinal;id=$case.id;bfSha256=$bfHash;dfSha256=$dfHash;sourceRecordPath=$case.sourceRecordPath;elapsedSeconds=[Math]::Round($timer.Elapsed.TotalSeconds,3);eligibility=$evaluation;detector=$detector;assets=$assets;detectorStdout=$stdout.Result.Trim()};$results.Add($record)
    if([bool]$evaluation.eligible){$eligible=$record;break}
}
$overall.Stop();$assetBytes=[int64]0;foreach($asset in $assetPaths){$assetBytes+=[int64]$asset.bytes};$returnRasters=$assetBytes-le[int64]$manifest.maximumReturnedRasterBytes
if($returnRasters){foreach($result in $results){foreach($asset in $result.assets){$asset|Add-Member -NotePropertyName base64 -NotePropertyValue ([Convert]::ToBase64String([IO.File]::ReadAllBytes([string]$asset.path)))}}}
[ordered]@{schema='argos_ocv03_o3b21_r25na1_notch_adjacent_control_evidence_v1';state=if($null-ne$eligible){'PASS_R25NA1_LEXICAL_FIRST_ELIGIBLE_CONTROL_FOUND'}else{'HOLD_R25NA1_NO_ELIGIBLE_CONTROL_IN_FROZEN_24'};gateState='PASS_R25NA1_FROZEN_SELECTOR_EXECUTION_COMPLETE';outputRoot=$outputRoot;frozenCandidateCount=24;executedCandidateCount=$results.Count;stoppedAfterFirstEligible=$null-ne$eligible;eligibleOrdinal=if($null-ne$eligible){$eligible.ordinal}else{$null};elapsedSeconds=[Math]::Round($overall.Elapsed.TotalSeconds,3);returnedRasterBytes=$assetBytes;rasterBytesEmbedded=$returnRasters;results=$results;selectorRelaxedAfterResults=$false;automaticHoldClearancePerformed=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingTaskOrProcessActionPerformed=$false;ownedChildProcessCount=$results.Count;providerActivationPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}|ConvertTo-Json -Depth 64 -Compress
'PASS_O3B21_R25NA1_EXACT_FROZEN_SELECTOR_EXECUTED'
