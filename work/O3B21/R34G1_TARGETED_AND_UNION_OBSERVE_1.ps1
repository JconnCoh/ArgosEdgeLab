$ErrorActionPreference='Stop'
$root='D:\R34G1'
$proc=Get-CimInstance Win32_Process -Filter 'ProcessId=11348' -ErrorAction SilentlyContinue
$target=Get-Content -LiteralPath "$root\targeted\SUMMARY.json" -Raw|ConvertFrom-Json
$rows=@($target.results|ForEach-Object{
  $d=$_.multiPairExteriorCleanResolution
  [pscustomobject][ordered]@{ordinal=$_.ordinal;id=$_.id;count=$_.pairedCandidateCount;angles=$_.meanAnglesDegrees;modes=$_.confirmationModes;ratioGate=$_.shallowModeRatioGateApplies;resolutionState=$d.state;cleanScore=$d.uniqueBothChannelsExteriorClearPairScore;maximumDirtyScore=$d.maximumExteriorDirtyPairScore;strictDominance=$d.strictScoreDominancePassed;passed=$_.passed}
})
$union="$root\union"
$jobs=if(Test-Path "$union\jobs"){@(Get-ChildItem -LiteralPath "$union\jobs" -File -Filter 'J*.json').Count}else{0}
$results=if(Test-Path $union){@(Get-ChildItem -LiteralPath $union -Directory -Filter 'O*'|Where-Object{Test-Path (Join-Path $_.FullName 'RESULT.json')}).Count}else{0}
[ordered]@{state='PASS_R34_TARGETED_DETAILS_UNION_PROGRESS_OBSERVED';pidPresent=[bool]$proc;targetedState=$target.state;targetedSummarySha256=(Get-FileHash "$root\targeted\SUMMARY.json").Hash;targetedRows=$rows;unionJobCount=$jobs;unionResultCount=$results;unionSummaryPresent=(Test-Path "$union\SUMMARY.json");mutationsPerformed=$false}|ConvertTo-Json -Depth 7 -Compress
