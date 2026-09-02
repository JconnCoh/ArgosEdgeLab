$out=@()
foreach($slot in 17,21,24){
 $r20=Get-Content -LiteralPath "D:\R32M1\R20_S$slot\RESULT.json" -Raw|ConvertFrom-Json
 $r21=Get-Content -LiteralPath "D:\R32M1\R21_S$slot\RESULT.json" -Raw|ConvertFrom-Json
 $r23=Get-Content -LiteralPath "D:\R32M1\R23_S$slot\RESULT.json" -Raw|ConvertFrom-Json
 $r25=Get-Content -LiteralPath "D:\R32M1\R25_S$slot\RESULT.json" -Raw|ConvertFrom-Json
 $p20=@($r20.pairedCandidates)[0];$p23=@($r23.pairedCandidates)[0]
 $out+=[ordered]@{slot=$slot;r20=[ordered]@{mode=$p20.confirmationMode;angle=$p20.meanAngleDegrees;bfDepth=$p20.bfDepthNativePx;dfDepth=$p20.dfDepthNativePx};r21=[ordered]@{bfHolder=@($r21.bf.holderExclusion.spans|ForEach-Object{"$($_.startAngleDegrees)+$($_.widthDegrees)"});dfHolder=@($r21.df.holderExclusion.spans|ForEach-Object{"$($_.startAngleDegrees)+$($_.widthDegrees)"});bfRaw=$r21.bf.holderExclusion.rawCandidateCountBeforeExclusion;bfRetained=$r21.bf.holderExclusion.retainedCandidateCountAfterExclusion;dfRaw=$r21.df.holderExclusion.rawCandidateCountBeforeExclusion;dfRetained=$r21.df.holderExclusion.retainedCandidateCountAfterExclusion};r23=[ordered]@{mode=$p23.confirmationMode;angle=$p23.meanAngleDegrees;bfAngle=$p23.bfAngleDegrees;dfAngle=$p23.dfAngleDegrees;bfDepth=$p23.bfDepthNativePx;dfDepth=$p23.dfDepthNativePx;anchorState=$r23.bf.dfStrongAnchorAppearanceDiagnostics.state;qualifiedAnchors=$r23.bf.dfStrongAnchorAppearanceDiagnostics.qualifiedAnchorCount};r25=$r25.bf.bfShallowDepthRatioNegativeControl}
}
[ordered]@{state='PASS_R32_R23_R25_CAUSE_READ';rows=$out;imageBytesRead=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 8 -Compress
