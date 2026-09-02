$ErrorActionPreference='Stop'
$root='D:\R33ROT1'
$summary=Join-Path $root 'SUMMARY.json'
$proc=Get-CimInstance Win32_Process -Filter 'ProcessId=36080' -ErrorAction SilentlyContinue
if(-not (Test-Path -LiteralPath $summary)){
  [pscustomobject]@{state='RUNNING_OR_NO_SUMMARY';pidPresent=[bool]$proc;pid=36080;summaryPresent=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress
  exit
}
$s=Get-Content -LiteralPath $summary -Raw|ConvertFrom-Json
$rows=@($s.results|ForEach-Object{[pscustomobject]@{id=$_.caseId;orientation=$_.orientation;mode=$_.mode;count=$_.pairedCandidateCount;angles=$_.pairedAnglesDegrees;confirmation=$_.pairedConfirmationModes;poseError=$_.poseErrorDegrees;violations=$_.gateViolations}})
[pscustomobject]@{
  state=$s.state
  pidPresent=[bool]$proc
  executionCount=$s.executionCount
  violationCount=@($s.violations).Count
  violations=$s.violations
  rows=$rows
  ablation=$s.ablationComparisons
  rotation=$s.rotationComparisons
  sourceHashesUnchanged=$s.sourceHashesUnchanged
  detectorHashUnchanged=$s.detectorHashUnchanged
  sourceMutationPerformed=$s.sourceMutationPerformed
  detectorMutationPerformed=$s.detectorMutationPerformed
  reviewOnly=$s.reviewOnly
  trainingEligible=$s.trainingEligible
  xmlEligible=$s.xmlEligible
  productionEligible=$s.productionEligible
  automaticHoldClearanceAllowed=$s.automaticHoldClearanceAllowed
  summarySha256=(Get-FileHash -LiteralPath $summary -Algorithm SHA256).Hash
  mutationsPerformed=$false
}|ConvertTo-Json -Depth 8 -Compress
