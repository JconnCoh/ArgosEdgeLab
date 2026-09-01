#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param([Parameter(ParameterSetName='Preflight')][switch]$Preflight,[Parameter(Mandatory=$true,ParameterSetName='Build')][switch]$Build)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot=Join-Path $project 'work\OPENCV_BACKSIDE_NOTCH_O3B10'
$root='C:\R27B32PK';$payload=Join-Path $root 'payload';$gatePath=Join-Path $PSScriptRoot 'R27B32_BUILD_GATE.json'
$entrySource=Join-Path $PSScriptRoot 'r27b32_generated\Invoke-R27B32.ps1'
$carrier='C:\R21P5\payload\C.json'
$sources=[ordered]@{
 'R27B32_CASES.json'=@((Join-Path $PSScriptRoot 'R27B32_CASES.json'),'8BA92F3351D21A3E58AD05C12574C4ECDF37F7BE7C38056C9A118F9F64567DA4')
 'R18_REGRESSION_CASES.json'=@((Join-Path $sourceRoot 'R18_REGRESSION_CASES.json'),'7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4')
 'BACKSIDE_NOTCH_CONFIG_R13.json'=@((Join-Path $sourceRoot 'BACKSIDE_NOTCH_CONFIG_R13.json'),'27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3')
 'C.json'=@($carrier,'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8')
 'Detect-BacksideNotchOpenCvR27.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR27.py'),'656F7705752F64CDAEBB88B195DB6E47A689B2727CB0113E168A72B8898F9FDF')
 'Detect-BacksideNotchOpenCvR26.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR26.py'),'05534929ECCCB18EA8E2E68A66CF33FA7AAF6B43CA80B6BBBD1970C3946FC1D6')
 'Detect-BacksideNotchOpenCvR25.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR25.py'),'6A7977E4DAFE692FCE6E7DE4740C94EE66D5F79ECD62FDF190CB5EE8E4862274')
 'Detect-BacksideNotchOpenCvR24.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR24.py'),'BDEAA9DBA4AA5FB1DEDF5FBBFA7C8F02C1860522E713EA1BE0BDB36539401477')
 'Detect-BacksideNotchOpenCvR23.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR23.py'),'AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C')
 'Detect-BacksideNotchOpenCvR22.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR22.py'),'DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94')
 'Detect-BacksideNotchOpenCvR21.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR21.py'),'29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E')
 'Detect-BacksideNotchOpenCvR20.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR20.py'),'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C')
 'Detect-BacksideNotchOpenCvR18.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR18.py'),'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A')
 'Detect-BacksideNotchOpenCvR17.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR17.py'),'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713')
 'Detect-BacksideNotchOpenCvR15.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR15.py'),'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C')
}
$entrySourceSha='3E40A772BBEE8FD32C729D392EF887B9148F516926C285C5F53A60F1C751F620'
$expectedEntrySha='3E40A772BBEE8FD32C729D392EF887B9148F516926C285C5F53A60F1C751F620'
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function BytesSha([byte[]]$Bytes){$s=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($s.ComputeHash($Bytes))).Replace('-','')}finally{$s.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){if(Test-Path -LiteralPath $Path){throw "Create-new path exists: $Path"};[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
if(-not(Test-Path -LiteralPath $entrySource -PathType Leaf)-or(Sha $entrySource)-ne$entrySourceSha){throw 'R27B32 entry source absent or changed.'}
foreach($name in $sources.Keys){$source=[string]$sources[$name][0];$hash=[string]$sources[$name][1];if(-not(Test-Path -LiteralPath $source -PathType Leaf)-or(Sha $source)-ne$hash){throw "R27B32 dependency absent or changed: $name"}}
$text=Get-Content -LiteralPath $entrySource -Raw
$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($text);$entrySha=BytesSha $bytes
if($Preflight){[ordered]@{schema='argos_o3b21_r27b32_build_preflight_v1';state='PASS_R27B32_BUILD_PREFLIGHT';buildRoot=$root;payloadFileCount=16;entrySha256=$entrySha;selectedOrdinals=@(0..31);targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5;return}
if($entrySha-ne$expectedEntrySha){throw "R27B32 entry is not frozen: $entrySha"};if(Test-Path -LiteralPath $root){throw 'R27B32 root exists.'};if(Test-Path -LiteralPath $gatePath){throw 'R27B32 gate exists.'}
[void](New-Item -ItemType Directory -Path $payload -Force)
[IO.File]::WriteAllBytes((Join-Path $payload 'Invoke-R27B32.ps1'),$bytes)
foreach($name in $sources.Keys){[IO.File]::Copy([string]$sources[$name][0],(Join-Path $payload $name),$false)}
$expected=@('Invoke-R27B32.ps1')+@($sources.Keys);$expected=@($expected|Sort-Object)
$actual=@(Get-ChildItem -LiteralPath $payload -Recurse -File|ForEach-Object{$_.FullName.Substring($payload.Length+1).Replace('\','/')}|Sort-Object)
if(@(Compare-Object -ReferenceObject $expected -DifferenceObject $actual).Count -ne 0){throw 'R27B32 exact clean payload inventory failed.'}
$definition=[ordered]@{targetRole='JBOD';jobClass='MAINTENANCE_PATCH';maxResultBytes=33554432;entryPoint='payload/Invoke-R27B32.ps1';changes=@([ordered]@{source='payload/C.json';destination='C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json';approvedPredecessorSha256=@($sources['C.json'][1]);installedSha256=$sources['C.json'][1];allowCreate=$false});allowedTaskActions=@();rehearsal=[ordered]@{requiredState='PASS_O3B21_R27B32_ALL_32_BATCHED_REGRESSION'}}
Write-NewJson (Join-Path $root 'DEFINITION.json') $definition
$gate=[ordered]@{schema='argos_o3b21_r27b32_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R27B32_UNSIGNED_ALL_32_BATCH_PACKAGE_BUILT';root=$root;payloadFileCount=$actual.Count;payloadRelativePaths=$actual;entrySha256=Sha (Join-Path $payload 'Invoke-R27B32.ps1');casesSha256=$sources['R27B32_CASES.json'][1];detectorSha256=$sources['Detect-BacksideNotchOpenCvR27.py'][1];frozenR25Sha256=$sources['Detect-BacksideNotchOpenCvR25.py'][1];configSha256=$sources['BACKSIDE_NOTCH_CONFIG_R13.json'][1];definitionSha256=Sha (Join-Path $root 'DEFINITION.json');selectedCaseCount=32;completedCaseRerunCount=32;sameBytesCarrier=$true;installedSemanticChange=$false;taskOrProcessActionCount=0;pythonCacheLeafCount=0;signed=$false;published=$false;targetExecuted=$false;mutationsPerformed=$false}
Write-NewJson $gatePath $gate;$gate|ConvertTo-Json -Depth 10
