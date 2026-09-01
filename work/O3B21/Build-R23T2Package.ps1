#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param([Parameter(ParameterSetName='Preflight')][switch]$Preflight,[Parameter(Mandatory=$true,ParameterSetName='Build')][switch]$Build)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot=Join-Path $project 'work\OPENCV_BACKSIDE_NOTCH_O3B10'
$root='C:\R23T2PK';$payload=Join-Path $root 'payload';$gatePath=Join-Path $PSScriptRoot 'R23T2_BUILD_GATE.json'
$entrySource=Join-Path $PSScriptRoot 'r23t1_generated\Invoke-R23T1.ps1'
$carrier='C:\R21P5\payload\C.json'
$sources=[ordered]@{
 'R23T2_TARGET_CASES.json'=@((Join-Path $PSScriptRoot 'R23T2_TARGET_CASES.json'),'86A41655BA6475AE7AE8E74ECB84937ABA9DB1C23340790B8E0427FCB973FD6A')
 'R18_REGRESSION_CASES.json'=@((Join-Path $sourceRoot 'R18_REGRESSION_CASES.json'),'7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4')
 'BACKSIDE_NOTCH_CONFIG_R11.json'=@((Join-Path $sourceRoot 'BACKSIDE_NOTCH_CONFIG_R11.json'),'60498159EA39BBA209F97414977A12CF5F275D4C5559B8EC0A80E83BBBCEDC49')
 'C.json'=@($carrier,'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8')
 'Detect-BacksideNotchOpenCvR23.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR23.py'),'AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C')
 'Detect-BacksideNotchOpenCvR22.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR22.py'),'DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94')
 'Detect-BacksideNotchOpenCvR21.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR21.py'),'29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E')
 'Detect-BacksideNotchOpenCvR20.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR20.py'),'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C')
 'Detect-BacksideNotchOpenCvR18.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR18.py'),'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A')
 'Detect-BacksideNotchOpenCvR17.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR17.py'),'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713')
 'Detect-BacksideNotchOpenCvR15.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR15.py'),'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C')
}
$entrySourceSha='591D3BCFA25C2AC146ACA496BAA42664976A81537C551733A05250807064AC65'
$expectedEntrySha='A111572F28D24A456613A21EA8610E6D4F3EC9855A8949CAFEAF2F0411B1CE60'
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function BytesSha([byte[]]$Bytes){$s=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($s.ComputeHash($Bytes))).Replace('-','')}finally{$s.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){if(Test-Path -LiteralPath $Path){throw "Create-new path exists: $Path"};[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
if(-not(Test-Path -LiteralPath $entrySource -PathType Leaf)-or(Sha $entrySource)-ne$entrySourceSha){throw 'R23T2 entry predecessor absent or changed.'}
foreach($name in $sources.Keys){$source=[string]$sources[$name][0];$hash=[string]$sources[$name][1];if(-not(Test-Path -LiteralPath $source -PathType Leaf)-or(Sha $source)-ne$hash){throw "R23T2 dependency absent or changed: $name"}}
$text=(Get-Content -LiteralPath $entrySource -Raw).Replace('R23T1','R23T2').Replace('r23t1','r23t2').Replace('47DBFB09C4946A34E0CFF0559D79628A4292C3EA4FC3F971739AD66DC4B184F5','86A41655BA6475AE7AE8E74ECB84937ABA9DB1C23340790B8E0427FCB973FD6A')
$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($text);$entrySha=BytesSha $bytes
if($Preflight){[ordered]@{schema='argos_o3b21_r23t2_build_preflight_v1';state='PASS_R23T2_BUILD_PREFLIGHT';buildRoot=$root;payloadFileCount=12;entrySha256=$entrySha;selectedOrdinals=@(24,25,26,27,29,30,31);targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5;return}
if($entrySha-ne$expectedEntrySha){throw "R23T2 entry is not frozen: $entrySha"};if(Test-Path -LiteralPath $root){throw 'R23T2 root exists.'};if(Test-Path -LiteralPath $gatePath){throw 'R23T2 gate exists.'}
[void](New-Item -ItemType Directory -Path $payload -Force)
[IO.File]::WriteAllBytes((Join-Path $payload 'Invoke-R23T2.ps1'),$bytes)
foreach($name in $sources.Keys){[IO.File]::Copy([string]$sources[$name][0],(Join-Path $payload $name),$false)}
$expected=@('Invoke-R23T2.ps1')+@($sources.Keys);$expected=@($expected|Sort-Object)
$actual=@(Get-ChildItem -LiteralPath $payload -Recurse -File|ForEach-Object{$_.FullName.Substring($payload.Length+1).Replace('\','/')}|Sort-Object)
if(@(Compare-Object -ReferenceObject $expected -DifferenceObject $actual).Count -ne 0){throw 'R23T2 exact clean payload inventory failed.'}
$definition=[ordered]@{targetRole='JBOD';jobClass='MAINTENANCE_PATCH';maxResultBytes=67108864;entryPoint='payload/Invoke-R23T2.ps1';changes=@([ordered]@{source='payload/C.json';destination='C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json';approvedPredecessorSha256=@($sources['C.json'][1]);installedSha256=$sources['C.json'][1];allowCreate=$false});allowedTaskActions=@();rehearsal=[ordered]@{requiredState='PASS_O3B21_R23T2_MISSING_ONLY_EVIDENCE_EXECUTED'}}
Write-NewJson (Join-Path $root 'DEFINITION.json') $definition
$gate=[ordered]@{schema='argos_o3b21_r23t2_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R23T2_UNSIGNED_CLEAN_TARGET_PACKAGE_BUILT';root=$root;payloadFileCount=$actual.Count;payloadRelativePaths=$actual;entrySha256=Sha (Join-Path $payload 'Invoke-R23T2.ps1');casesSha256=$sources['R23T2_TARGET_CASES.json'][1];detectorSha256=$sources['Detect-BacksideNotchOpenCvR23.py'][1];configSha256=$sources['BACKSIDE_NOTCH_CONFIG_R11.json'][1];definitionSha256=Sha (Join-Path $root 'DEFINITION.json');selectedCaseCount=7;completedCaseRerunCount=0;sameBytesCarrier=$true;installedSemanticChange=$false;taskOrProcessActionCount=0;pythonCacheLeafCount=0;signed=$false;published=$false;targetExecuted=$false;mutationsPerformed=$false}
Write-NewJson $gatePath $gate;$gate|ConvertTo-Json -Depth 10
