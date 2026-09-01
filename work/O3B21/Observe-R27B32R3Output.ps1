#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='D:\R27B32R3'
if($Preflight){[ordered]@{schema='argos_r27b32r3_output_observation_preflight_v1';state='PASS_R27B32R3_OUTPUT_OBSERVATION_PREFLIGHT';root=$root;imageBytesRead=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress;return}
if($env:COMPUTERNAME-ne'A1025645101'){throw 'Observation reached the wrong computer.'}
$rows=@()
foreach($ordinal in 0..31){
  $number='{0:D2}'-f$ordinal;$job=Join-Path $root ('J'+$number+'.json');$result=Join-Path $root ('O'+$number+'\RESULT.json')
  $row=[ordered]@{ordinal=$ordinal;jobExists=Test-Path -LiteralPath $job -PathType Leaf;resultExists=Test-Path -LiteralPath $result -PathType Leaf}
  if($row.resultExists){$value=Get-Content -LiteralPath $result -Raw|ConvertFrom-Json;$row.pairedCandidateCount=[int]$value.pairedCandidateCount;$row.compensationState=if($value.bf.PSObject.Properties.Name-contains'dfGeometryBfFullPerimeterCompensation'){[string]$value.bf.dfGeometryBfFullPerimeterCompensation.state}else{''}}
  $rows += [pscustomobject]$row
}
[ordered]@{schema='argos_r27b32r3_output_observation_v1';state='PASS_R27B32R3_OUTPUT_OBSERVED';computerName=$env:COMPUTERNAME;outputRootExists=Test-Path -LiteralPath $root -PathType Container;completeCount=@($rows|Where-Object resultExists).Count;partialOrStartedCount=@($rows|Where-Object jobExists).Count;rows=$rows;imageBytesRead=$false;taskOrProcessActionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6 -Compress
