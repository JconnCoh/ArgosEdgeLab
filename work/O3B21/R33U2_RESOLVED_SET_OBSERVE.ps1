$ErrorActionPreference='Stop'
$path='D:\R33U2\SUMMARY.json'
$s=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
$states=@{};$resolved=@();$multi=0
foreach($x in @($s.results)){
  $d=$x.multiPairExteriorCleanResolution
  if($null -ne $d -and [int]$d.inputPairCount -gt 1){
    $multi++
    $name=[string]$d.state
    if(-not $states.ContainsKey($name)){$states[$name]=0}
    $states[$name]=[int]$states[$name]+1
    if($name -eq 'PASS_UNIQUE_BOTH_CHANNELS_EXTERIOR_CLEAR_PAIR'){
      $resolved+=[pscustomobject][ordered]@{ordinal=[int]$x.ordinal;id=$x.id;group=$x.group;expected=[int]$x.expectedPairedCandidateCount;actual=[int]$x.pairedCandidateCount;input=[int]$d.inputPairCount;clean=[int]$d.bothChannelsExteriorClearPairCount;rows=$d.rows;resultSha256=$x.resultSha256}
    }
  }
}
[ordered]@{state='PASS_R33U2_RESOLVED_SET_OBSERVED';summarySha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash;resultCount=@($s.results).Count;multiPairCaseCount=$multi;resolutionStateCounts=$states;resolvedCount=$resolved.Count;resolved=$resolved;mutationsPerformed=$false}|ConvertTo-Json -Depth 8 -Compress
