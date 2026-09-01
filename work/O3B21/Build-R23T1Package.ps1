#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param([Parameter(ParameterSetName='Preflight')][switch]$Preflight,[Parameter(Mandatory=$true,ParameterSetName='Build')][switch]$Build)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root='C:\R23T1PK';$payload=Join-Path $root 'payload';$gatePath=Join-Path $PSScriptRoot 'R23T1_BUILD_GATE.json'
$entrySource=Join-Path $PSScriptRoot 'r22t1_generated\Invoke-R22T1.ps1';$cases=Join-Path $PSScriptRoot 'R23T1_TARGET_CASES.json'
$sourceRoot=Join-Path $project 'work\OPENCV_BACKSIDE_NOTCH_O3B10';$frozen=Join-Path $sourceRoot 'R18_REGRESSION_CASES.json';$config=Join-Path $sourceRoot 'BACKSIDE_NOTCH_CONFIG_R11.json';$carrier='C:\R21P5\payload\C.json'
$modules=[ordered]@{
 'Detect-BacksideNotchOpenCvR23.py'='AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C'
 'Detect-BacksideNotchOpenCvR22.py'='DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94'
 'Detect-BacksideNotchOpenCvR21.py'='29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E'
 'Detect-BacksideNotchOpenCvR20.py'='B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
 'Detect-BacksideNotchOpenCvR18.py'='DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
 'Detect-BacksideNotchOpenCvR17.py'='B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
 'Detect-BacksideNotchOpenCvR15.py'='F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
}
$pins=[ordered]@{$entrySource='0302FE02ED72E51AA3C9AEE674A866FB59871F0AA085DECEE0D950A81A0746E2';$cases='47DBFB09C4946A34E0CFF0559D79628A4292C3EA4FC3F971739AD66DC4B184F5';$frozen='7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4';$config='60498159EA39BBA209F97414977A12CF5F275D4C5559B8EC0A80E83BBBCEDC49';$carrier='CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'}
$expectedEntrySha='591D3BCFA25C2AC146ACA496BAA42664976A81537C551733A05250807064AC65'
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function BytesSha([byte[]]$Bytes){$s=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($s.ComputeHash($Bytes))).Replace('-','')}finally{$s.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){if(Test-Path -LiteralPath $Path){throw "Create-new path exists: $Path"};[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
foreach($path in $pins.Keys){if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Sha $path)-ne$pins[$path]){throw "R23T1 dependency absent or changed: $path"}}
foreach($name in $modules.Keys){$path=Join-Path $sourceRoot $name;if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Sha $path)-ne$modules[$name]){throw "R23T1 module absent or changed: $name"}}
$text=Get-Content -LiteralPath $entrySource -Raw
$text=$text.Replace('R22T1','R23T1').Replace('r22t1','r23t1')
$text=$text.Replace("`$engine = Join-Path `$PSScriptRoot 'Detect-BacksideNotchOpenCvR22.py'","`$engine = Join-Path `$PSScriptRoot 'Detect-BacksideNotchOpenCvR23.py'").Replace('DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94','AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C')
$text=$text.Replace("`$configPath = Join-Path `$PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R10.json'","`$configPath = Join-Path `$PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R11.json'").Replace('66680048EC05C73AAE4213A3BA750C7AEF862F9AB07F401684F1050CE0BABFB2','60498159EA39BBA209F97414977A12CF5F275D4C5559B8EC0A80E83BBBCEDC49')
$text=$text.Replace("`$manifestPath = Join-Path `$PSScriptRoot 'R23T1_TARGET_CASES.json'","`$manifestPath = Join-Path `$PSScriptRoot 'R23T1_TARGET_CASES.json'").Replace('FEF0D2E1618209D7F4C1EF21C95D8CB8F38BABDEB98435B9FF340C0C9E5D9892','47DBFB09C4946A34E0CFF0559D79628A4292C3EA4FC3F971739AD66DC4B184F5')
$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($text);$entrySha=BytesSha $bytes
if($Preflight){[ordered]@{schema='argos_o3b21_r23t1_build_preflight_v1';state='PASS_R23T1_BUILD_PREFLIGHT';buildRoot=$root;payloadFileCount=12;entrySha256=$entrySha;selectedOrdinals=@(24,25,26,27,29,30,31);targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5;return}
if([string]::IsNullOrWhiteSpace($expectedEntrySha)-or$entrySha-ne$expectedEntrySha){throw "R23T1 entry is not frozen: $entrySha"};if(Test-Path -LiteralPath $root){throw 'R23T1 root exists.'};if(Test-Path -LiteralPath $gatePath){throw 'R23T1 gate exists.'}
[void](New-Item -ItemType Directory -Path $payload -Force);[IO.File]::WriteAllBytes((Join-Path $payload 'Invoke-R23T1.ps1'),$bytes);[IO.File]::Copy($cases,(Join-Path $payload 'R23T1_TARGET_CASES.json'),$false);[IO.File]::Copy($frozen,(Join-Path $payload 'R18_REGRESSION_CASES.json'),$false);[IO.File]::Copy($config,(Join-Path $payload 'BACKSIDE_NOTCH_CONFIG_R11.json'),$false);[IO.File]::Copy($carrier,(Join-Path $payload 'C.json'),$false);foreach($name in $modules.Keys){[IO.File]::Copy((Join-Path $sourceRoot $name),(Join-Path $payload $name),$false)}
$definition=[ordered]@{targetRole='JBOD';jobClass='MAINTENANCE_PATCH';maxResultBytes=67108864;entryPoint='payload/Invoke-R23T1.ps1';changes=@([ordered]@{source='payload/C.json';destination='C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json';approvedPredecessorSha256=@($pins[$carrier]);installedSha256=$pins[$carrier];allowCreate=$false});allowedTaskActions=@();rehearsal=[ordered]@{requiredState='PASS_O3B21_R23T1_MISSING_ONLY_EVIDENCE_EXECUTED'}}
Write-NewJson (Join-Path $root 'DEFINITION.json') $definition
$gate=[ordered]@{schema='argos_o3b21_r23t1_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R23T1_UNSIGNED_TARGET_PACKAGE_BUILT';root=$root;payloadFileCount=12;entrySha256=Sha (Join-Path $payload 'Invoke-R23T1.ps1');casesSha256=Sha (Join-Path $payload 'R23T1_TARGET_CASES.json');detectorSha256=$modules['Detect-BacksideNotchOpenCvR23.py'];configSha256=$pins[$config];moduleClosure=$modules;definitionSha256=Sha (Join-Path $root 'DEFINITION.json');selectedCaseCount=7;completedCaseRerunCount=0;sameBytesCarrier=$true;installedSemanticChange=$false;taskOrProcessActionCount=0;signed=$false;published=$false;targetExecuted=$false;mutationsPerformed=$false}
Write-NewJson $gatePath $gate;$gate|ConvertTo-Json -Depth 10
