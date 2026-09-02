$ErrorActionPreference='Stop'
function D($id,$path){
 $z=Get-Content $path -Raw|ConvertFrom-Json;$d=$z.bf.multiPairExteriorCleanResolution;$p=@($z.pairedCandidates);$r=@($d.rows)
 [ordered]@{identity=$id;pairCount=$p.Count;state=$d.state;cleanCount=$d.bothChannelsExteriorClearPairCount;cleanScore=$d.uniqueBothChannelsExteriorClearPairScore;dirtyMax=$d.maximumExteriorDirtyPairScore;dominant=$d.strictScoreDominancePassed;pairs=@(for($i=0;$i-lt$p.Count;$i++){[ordered]@{angle=$p[$i].meanAngleDegrees;score=$p[$i].score;mode=$p[$i].confirmationMode;bfClear=if($i-lt$r.Count){$r[$i].bfExteriorClear}else{$null};dfClear=if($i-lt$r.Count){$r[$i].dfExteriorClear}else{$null};bothClear=if($i-lt$r.Count){$r[$i].bothChannelsExteriorClear}else{$null}}})}
}
$s=Get-Content 'D:\R34C953R2\SUMMARY.json' -Raw|ConvertFrom-Json
$m=@($s.failures|Where-Object{$_.stage-eq'notch'-and$_.state-eq'HOLD_BACK_NOTCH_MULTIPLE_BF_DF_MATCHES'})
$rows=@($m|ForEach-Object{D ([string]$_.identity) (Join-Path $_.diagnosticRoot 'RESULT.json')})
[ordered]@{state='PASS_R34_MULTIPLE_DIAGNOSTIC_OBSERVATION';completed=$s.pairCount;multiple=$rows.Count;rows=$rows;o005=(D 'O005_CONTROL' 'D:\R34G1\targeted\O005\RESULT.json');imageBytesReturned=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 7 -Compress
