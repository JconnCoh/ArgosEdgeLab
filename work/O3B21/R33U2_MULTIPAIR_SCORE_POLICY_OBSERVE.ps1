$ErrorActionPreference='Stop'
$summary='D:\R33U2\SUMMARY.json'
$s=Get-Content -LiteralPath $summary -Raw|ConvertFrom-Json
$rows=@()
foreach($x in @($s.results|Where-Object{$_.multiPairExteriorCleanResolution.inputPairCount -gt 1 -and [int]$_.ordinal -lt 298})){
  $n=[int]$x.ordinal
  $oldPath=('D:\R31VAL2\O{0:D2}\RESULT.json'-f$n)
  $old=Get-Content -LiteralPath $oldPath -Raw|ConvertFrom-Json
  $pairs=@($old.pairedCandidates)
  $diag=@($x.multiPairExteriorCleanResolution.rows)
  if($pairs.Count -ne $diag.Count){throw "pair/diagnostic mismatch O$n"}
  $detail=@()
  for($i=0;$i -lt $pairs.Count;$i++){
    if([math]::Abs([double]$pairs[$i].meanAngleDegrees-[double]$diag[$i].meanAngleDegrees) -gt .000001){throw "pair order mismatch O$n"}
    $detail+=[ordered]@{angle=[double]$pairs[$i].meanAngleDegrees;score=[double]$pairs[$i].score;clean=[bool]$diag[$i].bothChannelsExteriorClear;bfClear=[bool]$diag[$i].bfExteriorClear;dfClear=[bool]$diag[$i].dfExteriorClear;mode=$pairs[$i].confirmationMode}
  }
  $clean=@($detail|Where-Object{$_.clean})
  $dirty=@($detail|Where-Object{-not $_.clean})
  $ranked=($clean.Count -eq 1 -and $dirty.Count -gt 0 -and [double]$clean[0].score -gt [double](($dirty|Measure-Object -Property score -Maximum).Maximum))
  $predicted=if($ranked){1}else{$pairs.Count}
  $rows+=[ordered]@{ordinal=$n;id=$x.id;expected=[int]$x.expectedPairedCandidateCount;r31Count=$pairs.Count;r33Count=[int]$x.pairedCandidateCount;r33State=$x.multiPairExteriorCleanResolution.state;cleanOutranksDirty=$ranked;predicted=$predicted;matches=($predicted -eq [int]$x.expectedPairedCandidateCount);pairs=$detail;oldSha=(Get-FileHash -LiteralPath $oldPath -Algorithm SHA256).Hash}
}
[ordered]@{state='PASS_R33U2_MULTIPAIR_SCORE_POLICY_OBSERVED';summarySha256=(Get-FileHash -LiteralPath $summary -Algorithm SHA256).Hash;caseCount=$rows.Count;mismatchCount=@($rows|Where-Object{-not $_.matches}).Count;rows=$rows;imageBytesRead=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 8 -Compress
