#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param([Parameter(ParameterSetName='Preflight')][switch]$Preflight,[Parameter(Mandatory=$true,ParameterSetName='Build')][switch]$Build)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root='C:\R21M4PK';$payload=Join-Path $root 'payload';$gatePath=Join-Path $PSScriptRoot 'R21M4_BUILD_GATE.json'
$entrySource=Join-Path $PSScriptRoot 'r21m3_generated\Invoke-R21M3MissingOnly.ps1'
$cases=Join-Path $PSScriptRoot 'R21M4_MISSING_ONLY_CASES.json'
$sourceRoot=Join-Path $project 'work\OPENCV_BACKSIDE_NOTCH_O3B10'
$frozen=Join-Path $sourceRoot 'R18_REGRESSION_CASES.json';$config=Join-Path $sourceRoot 'BACKSIDE_NOTCH_CONFIG_R9.json';$carrier='C:\R21P5\payload\C.json'
$modules=[ordered]@{
 'Detect-BacksideNotchOpenCvR21.py'='29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E'
 'Detect-BacksideNotchOpenCvR20.py'='B10AC6F0E0500AC3D14713232FCEDC5C209FBACF56AD7826AF87443C2587C46C'
 'Detect-BacksideNotchOpenCvR18.py'='DA1305841E8592FCD8AC5C6A4C5981A4BEC7AC741BA75BC47CAE3B16F5DF372A'
 'Detect-BacksideNotchOpenCvR17.py'='B480B40435EE80527B00074FC4E7A69F423033D5AF02DA659E9193145B6CD713'
 'Detect-BacksideNotchOpenCvR15.py'='F16A024EEA34F01502BD62B9C750FD6AA95D6BD75D9F8A03D07FBF7B2A0EB64C'
}
$pins=[ordered]@{
 $entrySource='7FA4986DDAEB44E2BAE31F07E48261426C92815E6696598734FCD1650A65CAA0'
 $cases='4BA6CFE1DA2AA401B7A8B40D833231AADD000564949EB1E1CD8805303BAF3989'
 $frozen='7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
 $config='62591703B789D3981819E9AEE36C39DD187B2BC9A02BB335367206C78A064D73'
 $carrier='CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
}
$expectedEntrySha='17EA55A07CC1079918BB92798BFF7DB9FF1E171110F7ABA7838BEB13E19ED03C'
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function BytesSha([byte[]]$Bytes){$s=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($s.ComputeHash($Bytes))).Replace('-','')}finally{$s.Dispose()}}
function Write-NewJson([string]$Path,[object]$Value){if(Test-Path -LiteralPath $Path){throw "Create-new path exists: $Path"};[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
foreach($path in $pins.Keys){if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Sha $path)-ne $pins[$path]){throw "R21M4 dependency absent or changed: $path"}}
foreach($name in $modules.Keys){$path=Join-Path $sourceRoot $name;if(-not(Test-Path -LiteralPath $path -PathType Leaf)-or(Sha $path)-ne $modules[$name]){throw "R21M4 frozen module absent or changed: $name"}}
$text=Get-Content -LiteralPath $entrySource -Raw
$text=$text.Replace('R21M3','R21M4').Replace('r21m3','r21m4').Replace('B6D936439156C9B3113FC7914F53A66A28ABE8A7874801BC656730A127E5F5FB','4BA6CFE1DA2AA401B7A8B40D833231AADD000564949EB1E1CD8805303BAF3989')
$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($text);$entrySha=BytesSha $bytes
if($Preflight){[ordered]@{schema='argos_o3b21_r21m4_build_preflight_v1';state='PASS_R21M4_BUILD_PREFLIGHT';buildRoot=$root;payloadFileCount=10;generatedEntrySha256=$entrySha;frozenImportClosureCount=4;selectedCaseCount=13;completedCaseRerunCount=0;targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Depth 5;return}
if([string]::IsNullOrWhiteSpace($expectedEntrySha)-or $entrySha-ne$expectedEntrySha){throw "R21M4 generated entry is not frozen: $entrySha"}
if(Test-Path -LiteralPath $root){throw 'R21M4 build root exists.'};if(Test-Path -LiteralPath $gatePath){throw 'R21M4 build gate exists.'}
[void](New-Item -ItemType Directory -Path $payload -Force)
[IO.File]::WriteAllBytes((Join-Path $payload 'Invoke-R21M4MissingOnly.ps1'),$bytes)
[IO.File]::Copy($cases,(Join-Path $payload 'R21M4_MISSING_ONLY_CASES.json'),$false);[IO.File]::Copy($frozen,(Join-Path $payload 'R18_REGRESSION_CASES.json'),$false);[IO.File]::Copy($config,(Join-Path $payload 'BACKSIDE_NOTCH_CONFIG_R9.json'),$false);[IO.File]::Copy($carrier,(Join-Path $payload 'C.json'),$false)
foreach($name in $modules.Keys){[IO.File]::Copy((Join-Path $sourceRoot $name),(Join-Path $payload $name),$false)}
$definition=[ordered]@{targetRole='JBOD';jobClass='MAINTENANCE_PATCH';maxResultBytes=67108864;entryPoint='payload/Invoke-R21M4MissingOnly.ps1';changes=@([ordered]@{source='payload/C.json';destination='C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json';approvedPredecessorSha256=@($pins[$carrier]);installedSha256=$pins[$carrier];allowCreate=$false});allowedTaskActions=@();rehearsal=[ordered]@{requiredState='PASS_O3B21_R21M4_MISSING_ONLY_EVIDENCE_EXECUTED'}}
Write-NewJson (Join-Path $root 'DEFINITION.json') $definition
$gate=[ordered]@{schema='argos_o3b21_r21m4_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R21M4_UNSIGNED_DIRECT_PAYLOAD_IMPORT_CLOSURE_PACKAGE_BUILT';root=$root;payloadFileCount=10;entrySha256=Sha (Join-Path $payload 'Invoke-R21M4MissingOnly.ps1');casesSha256=Sha (Join-Path $payload 'R21M4_MISSING_ONLY_CASES.json');detectorSha256=$modules['Detect-BacksideNotchOpenCvR21.py'];configSha256=$pins[$config];frozenImportClosure=$modules;definitionSha256=Sha (Join-Path $root 'DEFINITION.json');selectedCaseCount=13;completedCaseRerunCount=0;newControlCount=0;newControlsRemainHeld=$true;sameBytesCarrier=$true;installedSemanticChange=$false;taskOrProcessActionCount=0;signed=$false;published=$false;targetExecuted=$false;mutationsPerformed=$false}
Write-NewJson $gatePath $gate;$gate|ConvertTo-Json -Depth 10
