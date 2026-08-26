#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$revision='R3S16_20260826T002500Z_8A6DE04B'
$engineSha='8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB'
$jobSha='331AF56A56DC65C78A68555EB5F11849ECBDB4C7203EAD3019994088390F33EE'
$refsSha='56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installSha='1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$bfSha='5F4E99C88FF42293AFDC7D3A2F9110C12262C4C3707055B99B054EFC603E541C'
$dfSha='B6C059B35AC64DD7B8D3FBB72388A60680B014E286901CAEB956880F989D86D1'
$proposalSha='C57380C95187610807C6BCE5C32A88E3A5F49E446C2D0C58B9B3CF855B115A0F'
$summarySha='FDC869DD292A15D69B9BFAAE0F077A799E535F5BE4A4614A14DE1148F91B059E'
$work='D:\A2\w\ocv\R3S16_20260826T002500Z_8A6DE04B'
$partial=$work+'.partial'
$output='D:\A2\o\ocv\R3S16_20260826T002500Z_8A6DE04B'
$zip='D:\A2\x\R3S16R_20260826T002500Z_8A6DE04B.zip'
$runtime='D:\AFCV1\rt\python.exe'
$installation='D:\AFCV1\INSTALLATION.json'
$refs='D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip'
$engine=Join-Path $PSScriptRoot 'ArgosOpenCvScribeV1R3.py'
$jobPath=Join-Path $PSScriptRoot 'R3_SLOT16_DIRECT_JOB.json'
$manifestPath=Join-Path $PSScriptRoot 'PAYLOAD_MANIFEST.json'
$resultPath=Join-Path $output 'RESULT.json'
$gatePath=Join-Path $output 'RUN_GATE.json'
$executionPath=Join-Path $output 'EXECUTION.json'
$failurePath=Join-Path $output 'FAILURE.json'

function Assert-Exact([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-ExactSha([string]$Path){$stream=[IO.File]::OpenRead($Path);$hasher=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','')}finally{$hasher.Dispose();$stream.Dispose()}}
function Assert-PathBudget([string]$Path,[int]$Reserve=32){$full=[IO.Path]::GetFullPath($Path);$parts=@($full.Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries));$longest=if($parts.Count){[int](($parts|ForEach-Object{$_.Length}|Measure-Object -Maximum).Maximum)}else{0};Assert-Exact (($full.Length+$Reserve)-lt 200) "Unsafe effective path: $full";Assert-Exact ($longest-le 80) "Unsafe component: $full"}
function Write-JsonNew([string]$Path,[object]$Value,[int]$Depth=16){Assert-Exact (-not(Test-Path -LiteralPath $Path)) "Create-new JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
function Invoke-Python([string]$Python,[string]$Engine,[string]$Job,[string]$Result){$si=New-Object Diagnostics.ProcessStartInfo;$si.FileName=$Python;$si.Arguments='"'+$Engine+'" --job "'+$Job+'" --result "'+$Result+'"';$si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true;$p=New-Object Diagnostics.Process;$p.StartInfo=$si;Assert-Exact ($p.Start()) 'Python did not start';$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(1800000)){try{$p.Kill()}catch{};throw'Python exceeded 1800000 milliseconds'};$r=[pscustomobject]@{exitCode=$p.ExitCode;stdout=$out.Result;stderr=$err.Result};$p.Dispose();return $r}

Assert-Exact ($env:COMPUTERNAME-eq'A1025645101') "Wrong host: $($env:COMPUTERNAME)"
foreach($p in @($engine,$jobPath,$manifestPath,$runtime,$installation,$refs)){Assert-Exact (Test-Path -LiteralPath $p -PathType Leaf) "Required file absent: $p";Assert-PathBudget $p 32}
foreach($p in @($work,$partial,$output,$zip,($zip+'.partial'),$resultPath,$gatePath,$executionPath)){Assert-PathBudget $p 32}
Assert-Exact ((Get-ExactSha $engine)-eq$engineSha) 'Engine hash changed'
Assert-Exact ((Get-ExactSha $jobPath)-eq$jobSha) 'Job hash changed'
Assert-Exact ((Get-ExactSha $refs)-eq$refsSha) 'Reference bundle changed'
Assert-Exact ((Get-ExactSha $installation)-eq$installSha) 'Runtime installation changed'
$manifest=Get-Content -Raw -LiteralPath $manifestPath|ConvertFrom-Json
Assert-Exact ([string]$manifest.schema-eq'argos_r3_slot16_direct_payload_manifest_v1') 'Payload manifest schema changed'
foreach($row in @($manifest.files)){$p=Join-Path $PSScriptRoot ([string]$row.path);Assert-Exact (Test-Path -LiteralPath $p -PathType Leaf) "Payload leaf absent: $($row.path)";Assert-Exact ((Get-Item -LiteralPath $p).Length-eq[int64]$row.bytes) "Payload bytes changed: $($row.path)";Assert-Exact ((Get-ExactSha $p)-eq[string]$row.sha256) "Payload hash changed: $($row.path)"}
$job=Get-Content -Raw -LiteralPath $jobPath|ConvertFrom-Json
Assert-Exact ([string]$job.inputMode-eq'QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT') 'Input mode changed'
Assert-Exact ([bool]$job.authority.reviewOnly-and-not[bool]$job.authority.automaticIdentityAuthority-and-not[bool]$job.authority.productionEligible-and-not[bool]$job.authority.mayClearHolds) 'Authority changed'
Assert-Exact ([string]$job.outputRoot-eq$output) 'Output root changed'
foreach($channel in @('bf','df')){$src=$job.inputs.$channel;Assert-Exact (Test-Path -LiteralPath ([string]$src.path) -PathType Leaf) "Source absent: $channel";Assert-Exact ((Get-Item -LiteralPath ([string]$src.path)).Length-eq[int64]$src.bytes) "Source bytes changed: $channel";Assert-Exact ((Get-ExactSha ([string]$src.path))-eq[string]$src.sha256) "Source hash changed: $channel"}
Assert-Exact ((Get-ExactSha ([string]$job.inputQualification.proposalPath))-eq$proposalSha) 'Installed proposal changed'
Assert-Exact ((Get-ExactSha ([string]$job.inputQualification.multiChannelSummaryPath))-eq$summarySha) 'Installed multi-channel summary changed'
Assert-Exact ([string]$job.inputs.bf.sha256-eq$bfSha-and[string]$job.inputs.df.sha256-eq$dfSha) 'Pinned crop hash changed'
foreach($p in @($work,$partial,$output,$zip,($zip+'.partial'))){Assert-Exact (-not(Test-Path -LiteralPath $p)) "Create-new target exists: $p"}
$d=Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction Stop
Assert-Exact ($null-ne$d-and[int64]$d.FreeSpace-ge 5368709120) 'D free-space floor failed'
if($Preflight){[ordered]@{schema='argos_r3_slot16_direct_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R3_SLOT16_DIRECT_PREFLIGHT';revision=$revision;computerName=$env:COMPUTERNAME;engineSha256=$engineSha;jobSha256=$jobSha;referenceBundleSha256=$refsSha;bfSha256=$bfSha;dfSha256=$dfSha;sourceImageBytesRead=$true;pixelsDecoded=$false;targetExecuted=$false;mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

try{
  [void](New-Item -ItemType Directory -Path $partial)
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::ExtractToDirectory($refs,$partial)
  Copy-Item -LiteralPath $engine -Destination (Join-Path $partial 'ArgosOpenCvScribeV1R3.py')
  Copy-Item -LiteralPath $jobPath -Destination (Join-Path $partial 'JOB.json')
  Assert-Exact ((Get-ExactSha (Join-Path $partial 'ArgosOpenCvScribeV1R3.py'))-eq$engineSha) 'Staged engine changed'
  Assert-Exact ((Get-ExactSha (Join-Path $partial 'JOB.json'))-eq$jobSha) 'Staged job changed'
  Move-Item -LiteralPath $partial -Destination $work -ErrorAction Stop
  [void](New-Item -ItemType Directory -Path $output)
  $run=Invoke-Python -Python $runtime -Engine (Join-Path $work 'ArgosOpenCvScribeV1R3.py') -Job (Join-Path $work 'JOB.json') -Result $resultPath
  Assert-Exact ($run.exitCode-eq 0) ('Provider failed: '+$run.stderr.Trim())
  Assert-Exact (Test-Path -LiteralPath $resultPath -PathType Leaf) 'Result absent'
  $result=Get-Content -Raw -LiteralPath $resultPath|ConvertFrom-Json
  Assert-Exact ([string]$result.schema-eq'argos_opencv_scribe_result_v2'-and[string]$result.revision-eq'ARGOS_OPENCV_SCRIBE_V1R3_20260825') 'Result schema or revision changed'
  Assert-Exact (-not[bool]$result.eligibleIdentity-and[bool]$result.authority.reviewOnly-and-not[bool]$result.authority.automaticIdentityAuthority-and-not[bool]$result.authority.productionEligible-and-not[bool]$result.authority.mayClearHolds) 'Result authority changed'
  Assert-Exact ([string]$result.provenance.inputMode-eq'QUALIFIED_INSTALLED_ORIENTED_DETECTOR_INPUT') 'Result input mode changed'
  Assert-Exact ([string]$result.provenance.sources.bf.sha256-eq$bfSha-and[string]$result.provenance.sources.df.sha256-eq$dfSha) 'Result source provenance changed'
  Assert-Exact ([int]$result.provenance.references.referenceCount-eq 456-and-not[bool]$result.provenance.references.referenceCoverageComplete-and[string]$result.provenance.references.missingBodyReferenceLabels-eq'IJKOQVWXYZ') 'Reference provenance changed'
  Assert-Exact (@($result.holds|Where-Object{[string]$_.code-eq'SCRIBE_REFERENCE_COVERAGE_HOLD'}).Count-eq 1) 'Reference coverage hold absent'
  $gate=[ordered]@{schema='argos_r3_slot16_opencv_development_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R3_SLOT16_OPENCV_DEVELOPMENT_EXECUTED';disposition='PENDING_GATE';revision=$revision;engineSha256=$engineSha;jobSha256=$jobSha;referenceBundleSha256=$refsSha;resultSha256=Get-ExactSha $resultPath;resultState=[string]$result.state;imageFirstString=[string]$result.imageFirstString;proposedString=[string]$result.proposedString;checksumState=[string]$result.checksumState;candidates=@($result.candidates);holds=@($result.holds);localization=$result.localization;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false}
  Write-JsonNew $gatePath $gate 16
  Write-JsonNew $executionPath ([ordered]@{schema='argos_r3_slot16_direct_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R3_SLOT16_DIRECT_EXECUTION';revision=$revision;computerName=$env:COMPUTERNAME;workRoot=$work;outputRoot=$output;resultSha256=Get-ExactSha $resultPath;gateSha256=Get-ExactSha $gatePath;sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 10
  [IO.Compression.ZipFile]::CreateFromDirectory($output,($zip+'.partial'),[IO.Compression.CompressionLevel]::Optimal,$false)
  Move-Item -LiteralPath ($zip+'.partial') -Destination $zip -ErrorAction Stop
  [ordered]@{schema='argos_r3_slot16_direct_terminal_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R3_SLOT16_DIRECT_ADMIN_DEVELOPMENT';revision=$revision;resultState=[string]$result.state;imageFirstString=[string]$result.imageFirstString;proposedString=[string]$result.proposedString;checksumState=[string]$result.checksumState;candidateStrings=@($result.candidates|ForEach-Object{[string]$_.string});holdCodes=@($result.holds|ForEach-Object{[string]$_.code});localResultPath=$zip;localResultSha256=Get-ExactSha $zip;taskOrProcessRestarted=$false;providerActivated=$false;sourceMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Compress -Depth 10
}
catch{
  $detail=$_.Exception.Message
  if(-not(Test-Path -LiteralPath $output -PathType Container)){[void](New-Item -ItemType Directory -Path $output)}
  if(-not(Test-Path -LiteralPath $failurePath)){Write-JsonNew $failurePath ([ordered]@{schema='argos_r3_slot16_direct_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_R3_SLOT16_DIRECT_EXECUTION_FAILURE';detail=$detail;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}) 8}
  throw
}
