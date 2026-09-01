#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param([Parameter(ParameterSetName='Preflight')][switch]$Preflight,[Parameter(Mandatory=$true,ParameterSetName='Build')][switch]$Build)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot=Join-Path $project 'work\OPENCV_BACKSIDE_NOTCH_O3B10'
$root='C:\R28ROT1PK';$payload=Join-Path $root 'payload';$gatePath=Join-Path $PSScriptRoot 'R28ROT1_BUILD_GATE.json'
$sources=[ordered]@{
 'Invoke-R28ROT1.ps1'=@((Join-Path $PSScriptRoot 'Invoke-R28ROT1.ps1'),'39895AF8B0233BD0D976D83A3BA7247A4C8D456A03965392F648902BEBBDCBAE')
 'Diagnose-R28RotationHolderAblation.py'=@((Join-Path $PSScriptRoot 'Diagnose-R28RotationHolderAblation.py'),'0E5A872FCC8C175F2E3B6BD6F6F5CE885F277ABDDA74C85F1C04A424652D80D5')
 'R28ROT1_CASES.json'=@((Join-Path $PSScriptRoot 'R28ROT1_CASES.json'),'90D4DC156D85F2F684E616248E23729E3E0F0111D64E456891DDDB519F2AD6AB')
 'Test-BacksideNotchOpenCvR28.py'=@((Join-Path $PSScriptRoot 'Test-BacksideNotchOpenCvR28.py'),'0BF3E7DE98D586833FA392D686ADFA4CB341F73672B6C7113728604E2AD4901F')
 'BACKSIDE_NOTCH_CONFIG_R13.json'=@((Join-Path $sourceRoot 'BACKSIDE_NOTCH_CONFIG_R13.json'),'27010B75F2E5CCB601E710A63D73F5483072F6EB797F9D72A0632F993E6E4AD3')
 'C.json'=@('C:\R21P5\payload\C.json','CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8')
 'Detect-BacksideNotchOpenCvR15.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR15.py'),'F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C')
 'Detect-BacksideNotchOpenCvR17.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR17.py'),'B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713')
 'Detect-BacksideNotchOpenCvR18.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR18.py'),'DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A')
 'Detect-BacksideNotchOpenCvR20.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR20.py'),'B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C')
 'Detect-BacksideNotchOpenCvR21.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR21.py'),'29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E')
 'Detect-BacksideNotchOpenCvR22.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR22.py'),'DB6C62727BB7E2EBBB5E8B669C5EE86D4B8960912BB66A0138F157538B59EC94')
 'Detect-BacksideNotchOpenCvR23.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR23.py'),'AAE38F93C7C1FE16E0967713A3773E33D61488E4D02BE6794E2811624D6DCE4C')
 'Detect-BacksideNotchOpenCvR24.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR24.py'),'BDEAA9DBA4AA5FB1DEDF5FBBFA7C8F02C1860522E713EA1BE0BDB36539401477')
 'Detect-BacksideNotchOpenCvR25.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR25.py'),'6A7977E4DAFE692FCE6E7DE4740C94EE66D5F79ECD62FDF190CB5EE8E4862274')
 'Detect-BacksideNotchOpenCvR26.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR26.py'),'05534929ECCCB18EA8E2E68A66CF33FA7AAF6B43CA80B6BBBD1970C3946FC1D6')
 'Detect-BacksideNotchOpenCvR27.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR27.py'),'656F7705752F64CDAEBB88B195DB6E47A689B2727CB0113E168A72B8898F9FDF')
 'Detect-BacksideNotchOpenCvR28.py'=@((Join-Path $sourceRoot 'Detect-BacksideNotchOpenCvR28.py'),'4F51BA7E8D261BF196CE559C420A4F511F0D06B39BE5F512D2E6ABF585681466')
}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Write-NewJson([string]$Path,[object]$Value){if(Test-Path -LiteralPath $Path){throw "Create-new path exists: $Path"};[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
foreach($name in $sources.Keys){$path=[string]$sources[$name][0];if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Sha $path)-ne[string]$sources[$name][1]){throw "R28ROT1 source absent or changed: $name"}}
if($Preflight){[ordered]@{schema='argos_o3b21_r28rot1_build_preflight_v1';state='PASS_R28ROT1_BUILD_PREFLIGHT';buildRoot=$root;payloadFileCount=$sources.Count;caseCount=2;executionCount=8;maximumTotalSeconds=840;targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json;return}
if(Test-Path -LiteralPath $root){throw 'R28ROT1 build root exists.'};if(Test-Path -LiteralPath $gatePath){throw 'R28ROT1 build gate exists.'}
[void](New-Item -ItemType Directory -Path $payload -Force);foreach($name in $sources.Keys){[IO.File]::Copy([string]$sources[$name][0],(Join-Path $payload $name),$false)}
$actual=@(Get-ChildItem -LiteralPath $payload -File|Sort-Object Name);if($actual.Count-ne$sources.Count){throw 'R28ROT1 payload cardinality failed.'}
$definition=[ordered]@{targetRole='JBOD';jobClass='MAINTENANCE_PATCH';maxResultBytes=26214400;entryPoint='payload/Invoke-R28ROT1.ps1';changes=@([ordered]@{source='payload/C.json';destination='C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json';approvedPredecessorSha256=@($sources['C.json'][1]);installedSha256=$sources['C.json'][1];allowCreate=$false});allowedTaskActions=@();rehearsal=[ordered]@{requiredState='PASS_O3B21_R28ROT1_EIGHT_DIAGNOSTIC_EXECUTIONS'}}
Write-NewJson (Join-Path $root 'DEFINITION.json') $definition
$gate=[ordered]@{schema='argos_o3b21_r28rot1_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R28ROT1_UNSIGNED_EIGHT_EXECUTION_DIAGNOSTIC_PACKAGE_BUILT';root=$root;payloadFileCount=$actual.Count;payloadRelativePaths=@($actual.Name);entrySha256=Sha (Join-Path $payload 'Invoke-R28ROT1.ps1');runnerSha256=$sources['Diagnose-R28RotationHolderAblation.py'][1];casesSha256=$sources['R28ROT1_CASES.json'][1];detectorSha256=$sources['Detect-BacksideNotchOpenCvR28.py'][1];configSha256=$sources['BACKSIDE_NOTCH_CONFIG_R13.json'][1];definitionSha256=Sha (Join-Path $root 'DEFINITION.json');caseCount=2;executionCount=8;maximumPerExecutionSeconds=75;maximumTotalSeconds=840;sameBytesCarrier=$true;installedSemanticChange=$false;taskOrProcessActionCount=0;pythonCacheLeafCount=0;signed=$false;published=$false;targetExecuted=$false;mutationsPerformed=$false}
Write-NewJson $gatePath $gate;$gate|ConvertTo-Json -Depth 10
