#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Has($Value,[string]$Name){$null-ne$Value-and$Value.PSObject.Properties.Name-contains$Name}
function Write-NewJson([string]$Path,$Value){
    Require (-not(Test-Path -LiteralPath $Path)) "Create-new path exists: $Path"
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 32),(New-Object Text.UTF8Encoding($false)))
}
function CaseFromItem($Item,[string]$Id,[string]$Group,[string]$Expected,[string]$SourceRecordPath){
    Require ([string]$Item.identity-eq$Id) "Corpus item identity changed: $Id"
    foreach($side in @('bf','df')){
        Require (Has $Item $side) "Corpus item source record absent: $Id $side"
        Require ([string]$Item.$side.sha256-match'^[A-Fa-f0-9]{64}$') "Corpus item source hash invalid: $Id $side"
    }
    [pscustomobject][ordered]@{
        id=$Id;group=$Group;expected=$Expected
        bf=[string]$Item.bf.path;bfSha256=([string]$Item.bf.sha256).ToUpperInvariant()
        df=[string]$Item.df.path;dfSha256=([string]$Item.df.sha256).ToUpperInvariant()
        sourceRecordPath=$SourceRecordPath
    }
}
function ItemForDiagnostic([string]$DiagnosticRoot){
    $itemPath=Join-Path (Split-Path -Parent $DiagnosticRoot) 'result.json'
    Require (Test-Path -LiteralPath $itemPath -PathType Leaf) "Corpus item result absent: $itemPath"
    [pscustomobject]@{Path=$itemPath;Value=(Get-Content -LiteralPath $itemPath -Raw|ConvertFrom-Json)}
}
function Compact-Channel($Channel,[bool]$Full){
    if($null-eq$Channel){return $null}
    $row=[ordered]@{
        channel=$Channel.channel;circle=$Channel.circle;profileThresholdPx=$Channel.profileThresholdPx
        profileMaximumDepthPx=$Channel.profileMaximumDepthPx;candidateCount=$Channel.candidateCount
        radialQualification=$Channel.radialQualification;holderExclusion=$Channel.holderExclusion
        backsideTraceQualification=$Channel.backsideTraceQualification
    }
    if(Has $Channel 'dfStrongAnchorAppearanceDiagnostics'){
        $strong=$Channel.dfStrongAnchorAppearanceDiagnostics
        $row.dfStrongAnchorAppearanceDiagnostics=[ordered]@{
            state=$strong.state;qualifiedAnchorCount=$strong.qualifiedAnchorCount
            proposedPairCount=$strong.proposedPairCount;anchors=if($Full){$strong.anchors}else{$null}
        }
    }
    if(Has $Channel 'bfShallowDepthRatioNegativeControl'){$row.bfShallowDepthRatioNegativeControl=$Channel.bfShallowDepthRatioNegativeControl}
    if(Has $Channel 'dfGeometryBfFullPerimeterCompensation'){$row.dfGeometryBfFullPerimeterCompensation=$Channel.dfGeometryBfFullPerimeterCompensation}
    if($Full){$row.candidates=$Channel.candidates}
    [pscustomobject]$row
}
function Compact-Detector($Detector,[bool]$Full){
    [pscustomobject][ordered]@{
        state=$Detector.state;opencvVersion=$Detector.opencvVersion
        fullPerimeterInference=$Detector.fullPerimeterInference
        knownNotchLocationConsumed=$Detector.knownNotchLocationConsumed
        patternSuppression=$Detector.patternSuppression
        bfEligibleCandidateCount=$Detector.bfEligibleCandidateCount
        dfEligibleCandidateCount=$Detector.dfEligibleCandidateCount
        pairedCandidateCount=$Detector.pairedCandidateCount
        pairedCandidates=$Detector.pairedCandidates
        bf=Compact-Channel $Detector.bf $Full
        df=Compact-Channel $Detector.df $Full
        sourceMutationPerformed=$Detector.sourceMutationPerformed
        reviewOnly=$Detector.reviewOnly
    }
}

$python='D:\AFCV1\rt\python.exe'
$pythonHash='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
$engine=Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR27.py'
$engineHash='656F7705752F64CDAEBB88B195DB6E47A689B2727CB0113E168A72B8898F9FDF'
$configPath=Join-Path $PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R13.json'
$configHash='27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3'
$manifestPath=Join-Path $PSScriptRoot 'R27B32R2_CASES.json'
$manifestHash='3E2F5DF2F5E97FA1CA82527DC3D235F61FCBF4245C8D09B44BC6D6140A41B8D0'
$frozenPath=Join-Path $PSScriptRoot 'R18_REGRESSION_CASES.json'
$packagePins=@(
    @($engine,$engineHash),@($configPath,$configHash),@($manifestPath,$manifestHash),
    @($frozenPath,'7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR26.py'),'05534929ECCCB18EA8E2E68A66CF33FA7AAF6B43CA80B6BBBD1970C3946FC1D6'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR25.py'),'6A7977E4DAFE692FCE6E7DE4740C94EE66D5F79ECD62FDF190CB5EE8E4862274'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR24.py'),'BDEAA9DBA4AA5FB1DEDF5FBBFA7C8F02C1860522E713EA1BE0BDB36539401477'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR23.py'),'AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR22.py'),'DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR21.py'),'29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR20.py'),'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR18.py'),'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR17.py'),'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'),
    @((Join-Path $PSScriptRoot 'Detect-BacksideNotchOpenCvR15.py'),'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C')
)

if($PackageLeafPreflight){
    foreach($pin in $packagePins){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Package-local dependency absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Package-local dependency changed: $($pin[0])"}
    $m=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
    Require ([string]$m.outputRoot-eq'D:/R27B32R2') 'Package output root changed.'
    Require ([int]$m.caseSelection.selectedCount-eq32) 'Package batch count changed.'
    Require ([int]$m.runtimeBoundary.maximumConcurrentChildren-eq3) 'Package concurrency changed.'
    [ordered]@{schema='argos_o3b21_r27b32r2_package_leaf_preflight_v1';state='PASS_R27B32R2_EXACT_PACKAGED_ENTRY_MANIFEST_LEAF';manifestSha256=Sha $manifestPath;detectorSha256=Sha $engine;selectedCaseCount=32;maximumConcurrentChildren=3;imageDecoded=$false;processStarted=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5 -Compress
    return
}

Require ($env:COMPUTERNAME-eq'A1025645101') 'R27B32R2 batched evidence reached the wrong computer.'
foreach($pin in $packagePins){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Pinned package dependency absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Pinned package dependency changed: $($pin[0])"}
foreach($pin in @(
    @($python,$pythonHash),
    @('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R20.py','B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'),
    @('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R18.py','DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'),
    @('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R17.py','B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'),
    @('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R15.py','F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C')
)){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Pinned runtime dependency absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Pinned runtime dependency changed: $($pin[0])"}

$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
$corpusRoot=[string]$manifest.r20Corpus.root
$summaryPath=Join-Path $corpusRoot 'SUMMARY.json';$resultsCsvPath=Join-Path $corpusRoot 'RESULTS.csv';$failuresPath=Join-Path $corpusRoot 'FAILURES.json'
foreach($pin in @(@($summaryPath,[string]$manifest.r20Corpus.summarySha256),@($resultsCsvPath,[string]$manifest.r20Corpus.resultsCsvSha256),@($failuresPath,[string]$manifest.r20Corpus.failuresSha256))){Require (Test-Path -LiteralPath $pin[0] -PathType Leaf) "Frozen R20 corpus evidence absent: $($pin[0])";Require ((Sha $pin[0])-eq$pin[1]) "Frozen R20 corpus evidence changed: $($pin[0])"}

$allCases=New-Object Collections.Generic.List[object];$seen=@{}
$frozen=@((Get-Content -LiteralPath $frozenPath -Raw|ConvertFrom-Json).cases)
Require ($frozen.Count-eq[int]$manifest.frozenControls.count) 'Frozen control cardinality changed.'
foreach($case in $frozen){$allCases.Add([pscustomobject][ordered]@{id=[string]$case.id;group='FROZEN_R20_CONTROL';expected=[string]$case.expected;bf=[string]$case.bf;bfSha256=[string]$case.bfSha256;df=[string]$case.df;dfSha256=[string]$case.dfSha256;sourceRecordPath=$frozenPath});$seen[[string]$case.id]=$true}
$failures=@((Get-Content -LiteralPath $failuresPath -Raw|ConvertFrom-Json).rows)
Require ($failures.Count-eq[int]$manifest.r20Corpus.holdCount) 'R20 hold cardinality changed.'
foreach($failure in $failures|Sort-Object identity){$record=ItemForDiagnostic ([string]$failure.diagnosticRoot);$case=CaseFromItem $record.Value ([string]$failure.identity) 'R20_CURRENT_HOLD' 'OBSERVE' $record.Path;if(-not$seen.ContainsKey($case.id)){$allCases.Add($case);$seen[$case.id]=$true}}
Require ($allCases.Count-eq32) 'R27B32R2 all-case cardinality changed.'
$selectedCases=@(foreach($ordinal in @($manifest.caseSelection.selectedOrdinals|ForEach-Object{[int]$_})){$case=$allCases[$ordinal];[pscustomobject][ordered]@{ordinal=$ordinal;id=[string]$case.id;group=[string]$case.group;expected=[string]$case.expected;bf=[string]$case.bf;bfSha256=([string]$case.bfSha256).ToUpperInvariant();df=[string]$case.df;dfSha256=([string]$case.dfSha256).ToUpperInvariant();sourceRecordPath=[string]$case.sourceRecordPath}})
Require ($selectedCases.Count-eq32) 'R27B32R2 selected cardinality changed.'
Require (@($selectedCases|Where-Object{$_.group-eq'FROZEN_R20_CONTROL'}).Count-eq10) 'R27B32R2 frozen-control cardinality changed.'
Require (@($selectedCases|Where-Object{$_.group-eq'R20_CURRENT_HOLD'}).Count-eq22) 'R27B32R2 hold cardinality changed.'
foreach($case in $selectedCases){Require ([string]$case.bfSha256-match'^[A-F0-9]{64}$') "Invalid BF hash: $($case.id)";Require ([string]$case.dfSha256-match'^[A-F0-9]{64}$') "Invalid DF hash: $($case.id)";Require (Test-Path -LiteralPath $case.bf -PathType Leaf) "BF source absent: $($case.id)";Require (Test-Path -LiteralPath $case.df -PathType Leaf) "DF source absent: $($case.id)"}

$outputRoot=[string]$manifest.outputRoot
Require (-not(Test-Path -LiteralPath $outputRoot)) "Create-new R27B32R2 output exists: $outputRoot"
if($Preflight){[ordered]@{schema='argos_o3b21_r27b32r2_preflight_v1';state='PASS_O3B21_R27B32R2_BATCHED_PREFLIGHT';outputRoot=$outputRoot;selectedCaseCount=32;frozenControlCount=10;r20CurrentHoldCount=22;maximumConcurrentChildren=3;imageDecoded=$false;sourceHashingPerformed=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Depth 6 -Compress;return}

[void](New-Item -ItemType Directory -Path $outputRoot)
$overall=[Diagnostics.Stopwatch]::StartNew()
$pending=New-Object Collections.Generic.Queue[object]
foreach($case in $selectedCases){$pending.Enqueue($case)}
$running=New-Object Collections.Generic.List[object]
$resultByOrdinal=@{};$allAssetBytes=[int64]0
try{
    while($pending.Count-gt0-or$running.Count-gt0){
        while($pending.Count-gt0-and$running.Count-lt[int]$manifest.runtimeBoundary.maximumConcurrentChildren){
            $case=$pending.Dequeue();$bfHash=Sha ([string]$case.bf);$dfHash=Sha ([string]$case.df)
            Require ($bfHash-eq[string]$case.bfSha256) "BF source changed: $($case.id)";Require ($dfHash-eq[string]$case.dfSha256) "DF source changed: $($case.id)"
            $ordinalText='{0:D2}'-f[int]$case.ordinal;$caseRoot=Join-Path $outputRoot ('O'+$ordinalText);$jobPath=Join-Path $outputRoot ('J'+$ordinalText+'.json')
            $job=[ordered]@{bf=[string]$case.bf;df=[string]$case.df;bfSha256=$bfHash;dfSha256=$dfHash;output=$caseRoot;radialEngine=[string]$config.radialEngine;radialEngineSha256=[string]$config.radialEngineSha256;radialParameters=$config.radialParameters;maximumDimension=[int]$manifest.maximumDimension}
            Write-NewJson $jobPath $job
            $start=New-Object Diagnostics.ProcessStartInfo;$start.FileName=$python;$start.Arguments=('-B "{0}" --job "{1}"'-f$engine,$jobPath);$start.WorkingDirectory=$PSScriptRoot;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
            $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() "R27B32R2 detector did not start: $($case.id)"
            $running.Add([pscustomobject]@{Case=$case;BfHash=$bfHash;DfHash=$dfHash;CaseRoot=$caseRoot;Process=$process;Stdout=$process.StandardOutput.ReadToEndAsync();Stderr=$process.StandardError.ReadToEndAsync();Timer=[Diagnostics.Stopwatch]::StartNew()})
        }
        foreach($run in $running.ToArray()){
            if(-not$run.Process.HasExited){if($run.Timer.Elapsed.TotalSeconds-ge[int]$manifest.runtimeBoundary.maximumPerCaseSeconds){try{$run.Process.Kill()}catch{};throw "R27B32R2 detector case timed out: $($run.Case.id)"};continue}
            $run.Process.WaitForExit();$run.Timer.Stop();Require ($run.Process.ExitCode-eq0) ("R27B32R2 detector failed: $($run.Case.id): "+$run.Stderr.Result)
            $resultPath=Join-Path $run.CaseRoot 'RESULT.json';Require (Test-Path -LiteralPath $resultPath -PathType Leaf) "R27B32R2 result absent: $($run.Case.id)";$detector=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
            $assets=New-Object Collections.Generic.List[object]
            foreach($asset in @(@('BF_REVIEW',(Join-Path $run.CaseRoot 'BF_review.jpg')),@('DF_REVIEW',(Join-Path $run.CaseRoot 'DF_review.jpg')),@('BF_HOLDER_MASK',(Join-Path $run.CaseRoot 'BF_holder_exclusion.png')),@('DF_HOLDER_MASK',(Join-Path $run.CaseRoot 'DF_holder_exclusion.png')))){
                Require (Test-Path -LiteralPath $asset[1] -PathType Leaf) "R27B32R2 evidence asset absent: $($run.Case.id) $($asset[0])";$item=Get-Item -LiteralPath $asset[1];$record=[pscustomobject][ordered]@{role=$asset[0];path=$item.FullName;bytes=$item.Length;sha256=Sha $item.FullName};$assets.Add($record);$allAssetBytes+=[int64]$item.Length
            }
            $full=[int]$run.Case.ordinal-eq[int]$manifest.targetGate.o23Ordinal
            $resultByOrdinal[[int]$run.Case.ordinal]=[pscustomobject][ordered]@{ordinal=[int]$run.Case.ordinal;id=[string]$run.Case.id;group=[string]$run.Case.group;expected=[string]$run.Case.expected;bfSha256=$run.BfHash;dfSha256=$run.DfHash;sourceRecordPath=[string]$run.Case.sourceRecordPath;elapsedSeconds=[Math]::Round($run.Timer.Elapsed.TotalSeconds,3);detector=Compact-Detector $detector $full;assets=$assets}
            $run.Process.Dispose();[void]$running.Remove($run)
        }
        if($running.Count-gt0){Start-Sleep -Milliseconds 100}
    }
}catch{foreach($run in $running.ToArray()){try{if(-not$run.Process.HasExited){$run.Process.Kill()}}catch{};try{$run.Process.Dispose()}catch{}};throw}
$overall.Stop();$results=@(0..31|ForEach-Object{$resultByOrdinal[$_]});Require (@($results|Where-Object{$null-ne$_}).Count-eq32) 'R27B32R2 completed result cardinality failed.'
$expected=@($manifest.targetGate.expectedPairedCandidateCountsByOrdinal)
foreach($result in $results){$ordinal=[int]$result.ordinal;Require ([int]$result.detector.pairedCandidateCount-eq[int]$expected[$ordinal]) "R27B32R2 exact paired cardinality failed at ordinal $ordinal";Require (-not[bool]$result.detector.knownNotchLocationConsumed) "R27B32R2 notch location consumed at ordinal $ordinal";Require (-not[bool]$result.detector.sourceMutationPerformed) "R27B32R2 source mutation reported at ordinal $ordinal"}
$o23=$resultByOrdinal[23];Require ([string]$o23.detector.bf.dfGeometryBfFullPerimeterCompensation.state-eq[string]$manifest.targetGate.o23RequiredCompensationState) 'R27B32R2 O23 compensation state failed.'
Require ([string]$resultByOrdinal[8].detector.bf.bfShallowDepthRatioNegativeControl.state-eq[string]$manifest.targetGate.ordinal8RequiredNegativeControlState) 'R27B32R2 ordinal 8 negative control changed.'
$o11bf=@($resultByOrdinal[11].assets|Where-Object{$_.role-eq'BF_HOLDER_MASK'})[0];$o11df=@($resultByOrdinal[11].assets|Where-Object{$_.role-eq'DF_HOLDER_MASK'})[0]
Require ([string]$o11bf.sha256-eq[string]$manifest.targetGate.ordinal11RequiredBfHolderMaskSha256) 'R27B32R2 ordinal 11 BF holder mask changed.';Require ([string]$o11df.sha256-eq[string]$manifest.targetGate.ordinal11RequiredDfHolderMaskSha256) 'R27B32R2 ordinal 11 DF holder mask changed.'
$o23AssetBytes=[int64]0;foreach($asset in $o23.assets){$o23AssetBytes+=[int64]$asset.bytes};$returnO23=$o23AssetBytes-le[int64]$manifest.maximumReturnedRasterBytes
if($returnO23){foreach($asset in $o23.assets){$asset|Add-Member -NotePropertyName base64 -NotePropertyValue ([Convert]::ToBase64String([IO.File]::ReadAllBytes([string]$asset.path)))}}
[ordered]@{schema='argos_ocv03_o3b21_r27b32r2_batched_real_image_evidence_v1';state='PASS_O3B21_R27B32R2_ALL_32_BATCHED_REGRESSION';gateState='PASS_O3B21_R27B32R2_EXACT_ALL_32_AND_O23_GATE';outputRoot=$outputRoot;caseCount=32;frozenControlCount=10;r20CurrentHoldCount=22;maximumConcurrentChildren=3;elapsedSeconds=[Math]::Round($overall.Elapsed.TotalSeconds,3);allAssetBytes=$allAssetBytes;o23ReturnedRasterBytes=$o23AssetBytes;o23RasterBytesEmbedded=$returnO23;results=$results;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;existingTaskOrProcessActionPerformed=$false;ownedChildProcessCount=32;providerActivationPerformed=$false;fresh953CorpusExecuted=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}|ConvertTo-Json -Depth 64 -Compress
'PASS_O3B21_R27B32R2_ALL_32_BATCHED_REGRESSION'
