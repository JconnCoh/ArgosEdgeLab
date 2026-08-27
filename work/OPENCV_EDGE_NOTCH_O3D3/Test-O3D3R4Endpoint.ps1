#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if([bool]$Preflight -eq [bool]$Gate){throw 'Specify exactly one of -Preflight or -Gate.'}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpoint=Join-Path $PSScriptRoot 'Invoke-O3D3R4HotspotEndpoint.ps1'
$generator=Join-Path $PSScriptRoot 'New-O3D3R4RehearsalFixtures.py'
$payloadRoot=Join-Path $project 'work\PATTERNED_FIDUCIAL_INVENTORY\tools'
$job=Join-Path $PSScriptRoot 'O3D3R4_HOTSPOT_JOB.json'
$fixtureManifest=Join-Path $PSScriptRoot 'O3D3R4_LIVE_CONTRACT_FIXTURE.json'
$runtimeRoot=Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$python=Join-Path $runtimeRoot 'python.exe'
$installationFixture=Join-Path $project 'work\OPENCV_SCRIBE_O2D23\fixtures\INSTALLATION.json'
$testRoot='C:\A38';$sourceRoot='C:\A38\s';$workRoot='C:\A38\w';$outputRoot='C:\A38\o';$badWorkRoot='C:\A38\bw';$badOutputRoot='C:\A38\bo'
$gatePath=Join-Path $PSScriptRoot 'O3D3R4_ENDPOINT_REHEARSAL_GATE.json'

$endpointSha='588839399168B016AD619DEF1BEDF09F2434385BA2B28A5C68E9D63416641211'
$generatorSha='735B8FE71F6F264D66440C1D35A078A01BF57E2821B5F079C1103FE83BF0785E'
$jobSha='F7DB6FE811D58DAA3F410C5AD8E4F063BBD6E961004BDAF1BF2470BB74392717'
$fixtureManifestSha='AA13EACF875AEE3F01142B7A33B5DE492DC271852C04F169712E933AD2F8D6CA'
$coreSha='304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC'
$r5Sha='47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24'
$r6Sha='90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'
$pythonSha='7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'

function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-Path([string]$Path){$full=[IO.Path]::GetFullPath($Path);$parts=@($full.Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries));$longest=if($parts.Count){[int](($parts|ForEach-Object{$_.Length}|Measure-Object -Maximum).Maximum)}else{0};Assert-True (($full.Length+32)-lt 200) "Unsafe O3D3R4 test path: $full";Assert-True ($longest-le80) "Unsafe O3D3R4 test component: $full"}
function Write-NewJson([string]$Path,[object]$Value,[int]$Depth=16){Assert-True (-not(Test-Path -LiteralPath $Path)) "Create-new O3D3R4 JSON exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$pins=@(
 [pscustomobject]@{path=$endpoint;sha=$endpointSha},[pscustomobject]@{path=$generator;sha=$generatorSha},[pscustomobject]@{path=$job;sha=$jobSha},[pscustomobject]@{path=$fixtureManifest;sha=$fixtureManifestSha},
 [pscustomobject]@{path=(Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2.py');sha=$coreSha},[pscustomobject]@{path=(Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2R5.py');sha=$r5Sha},[pscustomobject]@{path=(Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py');sha=$r6Sha},[pscustomobject]@{path=$python;sha=$pythonSha}
)
foreach($pin in $pins){Assert-True (Test-Path -LiteralPath $pin.path -PathType Leaf) "Missing O3D3R4 dependency: $($pin.path)";Assert-True ((Get-Sha $pin.path)-eq$pin.sha) "Changed O3D3R4 dependency: $($pin.path)"}
foreach($path in @($testRoot,$sourceRoot,$workRoot,$outputRoot,$badWorkRoot,$badOutputRoot,$gatePath)){Assert-Path $path;Assert-True (-not(Test-Path -LiteralPath $path)) "O3D3R4 fresh target exists: $path"}
Assert-True (-not(Test-Path -LiteralPath 'F:\')-and$null-eq(Get-PSDrive -Name F -ErrorAction SilentlyContinue)) 'O3D3R4 requires unused F:.'

$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile($endpoint,[ref]$tokens,[ref]$errors);Assert-True (@($errors).Count-eq0) 'O3D3R4 endpoint parser failed.'
$endpointText=[IO.File]::ReadAllText($endpoint);$fixture=Get-Content -LiteralPath $fixtureManifest -Raw|ConvertFrom-Json
$fixtureSchemaMatch=[regex]::Match($endpointText,"fixture\.schema -eq '([^']+)'")
Assert-True ($fixtureSchemaMatch.Success) 'O3D3R4 endpoint fixture-schema assertion absent.'
Assert-True ($fixtureSchemaMatch.Groups[1].Value-eq[string]$fixture.schema) 'O3D3R4 endpoint/fixture schema literals differ.'
Assert-True ($endpointText.Contains("[string]`$result.schema -eq 'argos_native_frontside_wafer_pose_opencv_v2'")) 'O3D3R4 exact result schema assertion changed.'
Assert-True ($endpointText.Contains("[string]`$summary.schema -eq 'argos_native_frontside_wafer_pose_opencv_v2_summary'")) 'O3D3R4 exact summary schema assertion changed.'

if($Preflight){[ordered]@{schema='argos_o3d3r3_endpoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R4_ENDPOINT_TEST_PREFLIGHT';endpointSha256=$endpointSha;generatorSha256=$generatorSha;jobSha256=$jobSha;fixtureSchema=[string]$fixture.schema;fixtureSchemaEqualityPassed=$true;resultSchemaEqualityPassed=$true;summarySchemaEqualityPassed=$true;windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;windowsPowerShellMinor=$PSVersionTable.PSVersion.Minor;testRoot=$testRoot;sourceImageBytesRead=$false;pixelsDecoded=$false;mutationsPerformed=$false;targetExecuted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8;return}

$liveText=& $endpoint -Preflight -LiveContractFixtureManifest $fixtureManifest|Out-String;$live=$liveText|ConvertFrom-Json
Assert-True ([string]$live.state-eq'PASS_O3D3R4_LIVE_CONTRACT_FIXTURE') 'O3D3R4 live-contract fixture failed.'
$generatorText=& $python $generator --r6 (Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py') --output-root $sourceRoot 2>&1|Out-String
Assert-True ($LASTEXITCODE-eq0) ('O3D3R4 fixture generation failed: '+$generatorText.Trim());$generatorGate=$generatorText.Trim()|ConvertFrom-Json;Assert-True ([string]$generatorGate.state-eq'PASS_O3D3R4_REHEARSAL_FIXTURES_CREATED') 'O3D3R4 fixture state changed.'
$rehearsalJob=Join-Path $sourceRoot 'JOB.json'
$preText=& $endpoint -Preflight -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtimeRoot -RuntimeInstallationPath $installationFixture -WorkRoot $workRoot -OutputRoot $outputRoot -SourceAliasRoot $sourceRoot -RehearsalJobPath $rehearsalJob -ExpectedComputerName $env:COMPUTERNAME|Out-String;$pre=$preText|ConvertFrom-Json
Assert-True ([string]$pre.state-eq'PASS_O3D3R4_ENDPOINT_PREFLIGHT'-and-not[bool]$pre.sourceImageBytesRead-and-not[bool]$pre.mutationsPerformed) 'O3D3R4 endpoint preflight changed.'
$normalText=& $endpoint -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtimeRoot -RuntimeInstallationPath $installationFixture -WorkRoot $workRoot -OutputRoot $outputRoot -SourceAliasRoot $sourceRoot -RehearsalJobPath $rehearsalJob -ExpectedComputerName $env:COMPUTERNAME|Out-String;$normal=$normalText|ConvertFrom-Json
Assert-True ([string]$normal.state-eq'PASS_O3D3R4_HOTSPOT_EDGE_NOTCH_EXECUTED'-and[int]$normal.inputCount-eq1-and[int]$normal.verifiedSourceCount-eq2) 'O3D3R4 normal rehearsal failed.'
Assert-True (@($normal.rows).Count-eq1-and[bool]$normal.rows[0].manufacturedNotchSelectedForReview-and[bool]$normal.sourceAliasRemoved-and[bool]$normal.processorIdentityUnchanged) 'O3D3R4 normal result boundary changed.'

$badJobPath=Join-Path $sourceRoot 'BAD_JOB.json';$badJob=Get-Content -LiteralPath $rehearsalJob -Raw|ConvertFrom-Json;$badJob.inputs[0].bfSha256='0'*64;Write-NewJson $badJobPath $badJob 20
$badFailed=$false;try{& $endpoint -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtimeRoot -RuntimeInstallationPath $installationFixture -WorkRoot $badWorkRoot -OutputRoot $badOutputRoot -SourceAliasRoot $sourceRoot -RehearsalJobPath $badJobPath -ExpectedComputerName $env:COMPUTERNAME 2>&1|Out-Null}catch{$badFailed=$_.Exception.Message-like'*source SHA-256 changed*'}
Assert-True $badFailed 'O3D3R4 injected hash mismatch did not fail closed.';Assert-True (-not(Test-Path -LiteralPath $badWorkRoot)-and-not(Test-Path -LiteralPath $badOutputRoot)-and-not(Test-Path -LiteralPath 'F:\')) 'O3D3R4 injected failure left active artifacts.'

$resultGate=[ordered]@{schema='argos_o3d3r3_endpoint_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R4_ENDPOINT_REHEARSAL';revision='O3D3R4_20260827T165500000Z_62629419';endpointSha256=$endpointSha;generatorSha256=$generatorSha;jobSha256=$jobSha;coreSha256=$coreSha;r5Sha256=$r5Sha;r6Sha256=$r6Sha;fixtureSchemaEqualityPassed=$true;resultSchemaEqualityPassed=$true;summarySchemaEqualityPassed=$true;normalState=[string]$normal.state;normalReviewAngleDegrees=[double]$normal.rows[0].reviewAngleDegrees;normalManufacturedNotchSelected=[bool]$normal.rows[0].manufacturedNotchSelectedForReview;sourceHashesVerifiedBeforeDecode=$true;injectedHashMismatchFailedBeforeWorkOrOutput=$true;sourceAliasRemoved=$true;processorIdentityUnchanged=$true;fullPerimeterInference=$true;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;regressionLabelsConsumed=$false;rotationAuthorityGranted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;waferActionPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $gatePath $resultGate 12;$resultGate|ConvertTo-Json -Depth 12

