#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Test)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Test)){throw 'Select exactly one O3B7 test action.'}
$provider=Join-Path $PSScriptRoot 'Invoke-O3B7ShortStage.ps1'
$root='C:\O3B7T';$src=Join-Path $root 'src';$out=Join-Path $root 'out';$manifest=Join-Path $root 'invocation.json'
$gatePath=Join-Path $PSScriptRoot 'O3B7_LOCAL_GATE.json'
if($Preflight){
  if(-not(Test-Path -LiteralPath $provider -PathType Leaf)){throw 'O3B7 provider missing.'}
  if(Test-Path -LiteralPath $gatePath){throw 'O3B7 local gate already exists.'}
  [ordered]@{schema='argos_ocv03_o3b7_test_preflight_v1';state='PASS_O3B7_TEST_PREFLIGHT';fixtureRoot=$root;fixtureCreated=$false;providerExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return
}
if(Test-Path -LiteralPath $root){throw 'O3B7 fixture root already exists.'}
[void](New-Item -ItemType Directory -Path (Join-Path $src 'bf'));[void](New-Item -ItemType Directory -Path (Join-Path $src 'df'))
$bf=Join-Path $src 'bf\source.bmp';$df=Join-Path $src 'df\source.bmp'
[IO.File]::WriteAllBytes($bf,[byte[]](0..255));[IO.File]::WriteAllBytes($df,[byte[]](255..0))
$bfTime=[DateTime]::Parse('2026-08-20T17:43:47.3679403Z').ToUniversalTime();$dfTime=[DateTime]::Parse('2026-08-20T17:44:00.8381748Z').ToUniversalTime();[IO.File]::SetLastWriteTimeUtc($bf,$bfTime);[IO.File]::SetLastWriteTimeUtc($df,$dfTime)
$inv=[ordered]@{schema='argos_ocv03_o3b7_short_stage_invocation_v1';state='FROZEN_SHORT_STAGE_CONTRACT';expectedComputerName=$env:COMPUTERNAME;sourceRoot=$src;outputRoot=$out;aliasDrive='Q:';substPath=(Join-Path $env:SystemRoot 'System32\subst.exe');sources=@([ordered]@{channel='BF_BACKSIDE';relativePath='bf/source.bmp';expectedBytes=256;expectedLastWriteTimeUtc=$bfTime.ToString('o');outputName='BF.bmp'},[ordered]@{channel='DF_BACKSIDE';relativePath='df/source.bmp';expectedBytes=256;expectedLastWriteTimeUtc=$dfTime.ToString('o');outputName='DF.bmp'});sourceImageReadAuthorized=$true;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;imageDecodeAuthorized=$false;pixelProcessingAuthorized=$false;taskActionAuthorized=$false;existingProcessActionAuthorized=$false;providerActivationAuthorized=$false;thresholdOrAlgorithmChangeAuthorized=$false;holdClearanceAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($manifest,($inv|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
$providerPreflight=& $provider -InvocationManifest $manifest -Preflight -Rehearsal|ConvertFrom-Json
if([string]$providerPreflight.state-ne'PASS_O3B7_SHORT_STAGE_PREFLIGHT'-or[bool]$providerPreflight.mutationsPerformed){throw 'O3B7 provider preflight failed.'}
$result=& $provider -InvocationManifest $manifest -Rehearsal|ConvertFrom-Json
if([string]$result.state-ne'PASS_O3B7_EXACT_BACKSIDE_PAIR_STAGED'-or-not[bool]$result.aliasRemoved-or[bool]$result.imageDecoded-or[bool]$result.sourceMutationPerformed-or[bool]$result.taskOrExistingProcessActionPerformed){throw 'O3B7 provider execution failed.'}
foreach($row in @($result.sources)){if([string]$row.sourceSha256-ne[string]$row.outputSha256){throw 'O3B7 fixture source/output hash mismatch.'}}
$gate=[ordered]@{schema='argos_ocv03_o3b7_local_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3B7_LOCAL_SHORT_ALIAS_STAGE';windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;sourceCount=@($result.sources).Count;aliasRemoved=[bool]$result.aliasRemoved;sourceAndOutputHashesMatched=$true;imageDecoded=$false;pixelProcessingPerformed=$false;sourceMutationPerformed=$false;taskOrExistingProcessActionPerformed=$false;fixtureRoot=$root;fixturePreserved=$true;reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($gatePath,(($gate|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$gate|ConvertTo-Json -Depth 8
