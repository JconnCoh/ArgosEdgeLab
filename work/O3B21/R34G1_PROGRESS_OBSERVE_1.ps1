$ErrorActionPreference='Stop'
$root='D:\R34G1'
$pidRow=Get-CimInstance Win32_Process -Filter 'ProcessId=11348' -ErrorAction SilentlyContinue
$summary=Join-Path $root 'SUMMARY.json'
$progress=Join-Path $root 'PROGRESS.json'
if(Test-Path -LiteralPath $summary){
  $s=Get-Content -LiteralPath $summary -Raw|ConvertFrom-Json
  [ordered]@{state=$s.state;pidPresent=[bool]$pidRow;failedPhase=$s.failedPhase;phaseCount=$s.phaseCount;phases=$s.phases;sourceMutationPerformed=$s.sourceMutationPerformed;reviewOnly=$s.reviewOnly;trainingEligible=$s.trainingEligible;xmlEligible=$s.xmlEligible;productionEligible=$s.productionEligible;automaticHoldClearanceAllowed=$s.automaticHoldClearanceAllowed;summarySha256=(Get-FileHash -LiteralPath $summary -Algorithm SHA256).Hash;mutationsPerformed=$false}|ConvertTo-Json -Depth 7 -Compress
}elseif(Test-Path -LiteralPath $progress){
  $p=Get-Content -LiteralPath $progress -Raw|ConvertFrom-Json
  [ordered]@{state=$p.state;pidPresent=[bool]$pidRow;completedPhaseCount=$p.completedPhaseCount;phases=$p.phases;reviewOnly=$p.reviewOnly;trainingEligible=$p.trainingEligible;xmlEligible=$p.xmlEligible;productionEligible=$p.productionEligible;automaticHoldClearanceAllowed=$p.automaticHoldClearanceAllowed;progressSha256=(Get-FileHash -LiteralPath $progress -Algorithm SHA256).Hash;mutationsPerformed=$false}|ConvertTo-Json -Depth 7 -Compress
}else{
  [ordered]@{state='RUNNING_BEFORE_FIRST_PROGRESS';pidPresent=[bool]$pidRow;pid=11348;outputRootPresent=(Test-Path -LiteralPath $root);mutationsPerformed=$false}|ConvertTo-Json -Compress
}
