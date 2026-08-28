#Requires -Version 5.1
[CmdletBinding()]param([switch]$Preflight,[switch]$Gate)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest;if([bool]$Preflight-eq[bool]$Gate){throw'Specify exactly one mode.'}
$root='C:\B9T';$src=Join-Path $root 'src';$out=Join-Path $root 'out';$inv=Join-Path $root 'inv.json';foreach($p in @($root,$out,$out+'.partial',$out+'.failed')){if(Test-Path -LiteralPath $p){throw"O3B9 fixture exists: $p"}}
if($Preflight){[ordered]@{schema='argos_o3b9_local_test_preflight_v1';state='PASS_O3B9_LOCAL_TEST_PREFLIGHT';fixtureRoot=$root;mutationsPerformed=$false}|ConvertTo-Json;return}
[void](New-Item -ItemType Directory -Path $src);$utf8=New-Object Text.UTF8Encoding($false);$rows=New-Object Collections.Generic.List[object]
foreach($name in @('BF.bmp','DF.bmp')){$bytes=New-Object byte[] 256;for($i=0;$i-lt$bytes.Length;$i++){$bytes[$i]=[byte](($i+$(if($name-eq'BF.bmp'){17}else{31}))%256)};$path=Join-Path $src $name;[IO.File]::WriteAllBytes($path,$bytes);$rows.Add([ordered]@{channel=$(if($name-eq'BF.bmp'){'BF_BACKSIDE'}else{'DF_BACKSIDE'});sourceName=$name;outputName=$name;expectedBytes=256;expectedSha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash})}
$value=[ordered]@{schema='argos_ocv03_o3b9_approved_stage_invocation_v1';expectedComputerName=$env:COMPUTERNAME;sourceRoot=$src;outputRoot=$out;sources=$rows.ToArray();reviewOnly=$true;productionRoutingEnabled=$false};[IO.File]::WriteAllText($inv,(($value|ConvertTo-Json -Depth 8)+[Environment]::NewLine),$utf8)
$result=& (Join-Path $PSScriptRoot 'Invoke-O3B9ApprovedStage.ps1') -InvocationManifest $inv -Stage|ConvertFrom-Json
if([string]$result.state-ne'PASS_O3B9_EXACT_PAIR_IN_APPROVED_DATA_ROOT'-or@(Get-ChildItem -LiteralPath $out -File).Count-ne3){throw'O3B9 local stage failed.'}
[ordered]@{schema='argos_o3b9_local_test_gate_v1';state='PASS_O3B9_LOCAL_APPROVED_STAGE';sourceCount=2;hashesMatched=$true;sourceMutationPerformed=$false;imageDecoded=$false;fixturePreserved=$true}|ConvertTo-Json
