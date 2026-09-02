$ErrorActionPreference='Stop'
$root='D:\R34G1'
$proc=Get-CimInstance Win32_Process -Filter 'ProcessId=11348' -ErrorAction SilentlyContinue
$summary="$root\SUMMARY.json"
$union="$root\union"
if(Test-Path $summary){
  $s=Get-Content $summary -Raw|ConvertFrom-Json
  [ordered]@{observationOrdinal=6;state=$s.state;pidPresent=[bool]$proc;failedPhase=$s.failedPhase;phaseCount=$s.phaseCount;phases=$s.phases;summarySha256=(Get-FileHash $summary).Hash;sourceMutationPerformed=$s.sourceMutationPerformed;reviewOnly=$s.reviewOnly;trainingEligible=$s.trainingEligible;xmlEligible=$s.xmlEligible;productionEligible=$s.productionEligible;automaticHoldClearanceAllowed=$s.automaticHoldClearanceAllowed;mutationsPerformed=$false}|ConvertTo-Json -Depth 7 -Compress
}else{
  $jobs=if(Test-Path "$union\jobs"){@(Get-ChildItem "$union\jobs" -File -Filter 'J*.json').Count}else{0}
  $results=if(Test-Path $union){@(Get-ChildItem $union -Directory -Filter 'O*'|Where-Object{Test-Path "$($_.FullName)\RESULT.json"}).Count}else{0}
  [ordered]@{observationOrdinal=6;state='R34_UNION_RUNNING';pidPresent=[bool]$proc;unionJobCount=$jobs;unionResultCount=$results;unionSummaryPresent=(Test-Path "$union\SUMMARY.json");rotationRootPresent=(Test-Path "$root\rotation");mutationsPerformed=$false}|ConvertTo-Json -Compress
}
