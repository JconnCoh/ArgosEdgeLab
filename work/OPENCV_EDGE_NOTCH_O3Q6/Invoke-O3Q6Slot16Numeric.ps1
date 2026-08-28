#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Rehearsal,[string]$InvocationManifest='')
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$liveInvocationSha256='88CFE656E307B2D0EEBF5E962E57C8AE7A71918FBC8153AEC9E74AFC40E4839F'

function Assert-O3Q6([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Get-O3Q6Hash([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-O3Q6Pin([string]$Path,[string]$Hash,[string]$Label){
  Assert-O3Q6 (Test-Path -LiteralPath $Path -PathType Leaf) "O3Q6 $Label is absent: $Path"
  Assert-O3Q6 ((Get-O3Q6Hash $Path)-eq$Hash) "O3Q6 $Label hash changed: $Path"
}
function Assert-O3Q6Path([string]$Path){
  $full=[IO.Path]::GetFullPath($Path); $parts=@($full.Split([char[]]@('\','/'),[StringSplitOptions]::RemoveEmptyEntries))
  $maximum=if($parts.Count){[int](($parts|ForEach-Object{$_.Length}|Measure-Object -Maximum).Maximum)}else{0}
  Assert-O3Q6 (($full.Length+32)-lt 200) "O3Q6 path budget failed: $full"
  Assert-O3Q6 ($maximum-le80) "O3Q6 path component budget failed: $full"
}
function Write-O3Q6Json([string]$Path,[object]$Value){
  Assert-O3Q6 (-not(Test-Path -LiteralPath $Path)) "O3Q6 create-new file exists: $Path"
  [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 64)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}
function Invoke-O3Q6Child([string]$Executable,[string]$Runner,[string]$Job,[string]$ModuleRoot,[int]$Timeout,[int]$MaximumBytes){
  foreach($value in @($Executable,$Runner,$Job)){Assert-O3Q6 (-not $value.Contains('"')) 'O3Q6 child path contains a quote.'}
  $info=New-Object Diagnostics.ProcessStartInfo; $info.FileName=$Executable; $info.Arguments='"'+$Runner+'" --job "'+$Job+'"'
  $info.UseShellExecute=$false; $info.CreateNoWindow=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
  $info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1'; $info.EnvironmentVariables['PYTHONNOUSERSITE']='1'; $info.EnvironmentVariables['PYTHONPATH']=$ModuleRoot
  $child=New-Object Diagnostics.Process; $child.StartInfo=$info; Assert-O3Q6 $child.Start() 'O3Q6 owned child did not start.'
  $identifier=[int]$child.Id; $started=$child.StartTime.ToUniversalTime().ToString('o'); $outTask=$child.StandardOutput.ReadToEndAsync(); $errTask=$child.StandardError.ReadToEndAsync()
  $timedOut=-not $child.WaitForExit($Timeout*1000); if($timedOut){try{$child.Kill()}catch{}; $child.WaitForExit()}
  $stdout=$outTask.Result; $stderr=$errTask.Result; $exitCode=$child.ExitCode; $child.Dispose()
  Assert-O3Q6 (([Text.Encoding]::UTF8.GetByteCount($stdout)+[Text.Encoding]::UTF8.GetByteCount($stderr))-le$MaximumBytes) 'O3Q6 child output exceeded its bound.'
  return [ordered]@{processId=$identifier;startedUtc=$started;timedOut=$timedOut;exitCode=$exitCode;stdout=$stdout;stderr=$stderr}
}
function Get-O3Q6Terminal([object]$EngineTerminal,[object]$Output,[string]$CommittedPath,[object]$Child){
  Assert-O3Q6 ([string]$EngineTerminal.state-eq'COMPLETE_O3P8_POST2_BF_TOPOLOGY_DF_RADIAL_REVIEW_ONLY') 'O3Q6 producer terminal state failed.'
  Assert-O3Q6 ([int]$EngineTerminal.inputCount-eq1-and[int]$EngineTerminal.dfTopologyInvocationCount-eq0) 'O3Q6 producer terminal counts failed.'
  Assert-O3Q6 ([string]$Output.schema-eq'argos_ocv03_o3p8_front_split_notch_result_v1'-and[string]$Output.state-eq[string]$EngineTerminal.state) 'O3Q6 producer output schema/state failed.'
  Assert-O3Q6 ([int]$Output.inputCount-eq1-and@($Output.rows).Count-eq1-and[int]$Output.dfTopologyInvocationCount-eq0) 'O3Q6 producer output counts failed.'
  $row=$Output.rows[0]; Assert-O3Q6 ([string]$row.identity-eq'62629-419_20260824112405_SLOT16'-and[int]$row.seedCount-eq21) 'O3Q6 locked identity/seed count failed.'
  Assert-O3Q6 (-not[bool]$Output.knownNotchLocationConsumed-and-not[bool]$Output.backsidePixelsConsumed-and-not[bool]$Output.sourceMutationPerformed) 'O3Q6 forbidden input or mutation was reported.'
  Assert-O3Q6 ([bool]$Output.reviewOnly-and-not[bool]$Output.trainingEligible-and-not[bool]$Output.xmlEligible-and-not[bool]$Output.productionEligible-and-not[bool]$Output.productionRoutingEnabled) 'O3Q6 authority widened.'
  return [ordered]@{schema='argos_ocv03_o3q6_numeric_terminal_v1';state='COMPLETE_O3Q6_NUMERIC_REVIEW_ONLY';resultPath=$CommittedPath;resultSha256=[string]$EngineTerminal.outputSha256;rowState=[string]$row.state;seedCount=[int]$row.seedCount;eligibleCount=[int]$row.eligibleCount;numericIndependentPass=([string]$row.state-eq'PASS_REVIEW_ONLY_UNIQUE_BF_TOPOLOGY_DF_RADIAL_NOTCH'-and[int]$row.eligibleCount-eq1);ownedChild=$Child;sourceAliasRemoved=$false;existingProcessQueryCount=0;taskActionCount=0;reviewOnly=$true;productionRoutingEnabled=$false}
}

$manifestPath=if([string]::IsNullOrWhiteSpace($InvocationManifest)){Join-Path $PSScriptRoot 'O3Q6_ENDPOINT_LIVE_INVOCATION.json'}else{[IO.Path]::GetFullPath($InvocationManifest)}
$manifestHash=if($Rehearsal){Get-O3Q6Hash $manifestPath}else{$liveInvocationSha256}; Assert-O3Q6Pin $manifestPath $manifestHash 'invocation manifest'
$invoke=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json; $expectedState=if($Rehearsal){'FROZEN_REHEARSAL_CONTRACT'}else{'FROZEN_LIVE_CONTRACT'}
Assert-O3Q6 ([string]$invoke.schema-eq'argos_ocv03_o3q6_endpoint_invocation_v1'-and[string]$invoke.state-eq$expectedState) 'O3Q6 invocation schema/state changed.'
Assert-O3Q6 ($env:COMPUTERNAME.Equals([string]$invoke.expectedComputerName,[StringComparison]::OrdinalIgnoreCase)) "O3Q6 wrong computer: $env:COMPUTERNAME"
Assert-O3Q6 (-not[bool]$invoke.thresholdOrAlgorithmChangeAuthorized-and-not[bool]$invoke.taskOrExistingProcessActionAuthorized-and-not[bool]$invoke.sourceMutationAuthorized-and-not[bool]$invoke.sourceDeletionAuthorized-and-not[bool]$invoke.providerActivationAuthorized-and-not[bool]$invoke.requestRetryAuthorized) 'O3Q6 authority widened.'
Assert-O3Q6 ([bool]$invoke.reviewOnly-and-not[bool]$invoke.trainingEligible-and-not[bool]$invoke.xmlEligible-and-not[bool]$invoke.productionEligible-and-not[bool]$invoke.productionRoutingEnabled) 'O3Q6 eligibility widened.'
$payload=if([string]::IsNullOrWhiteSpace([string]$invoke.payloadRoot)){$PSScriptRoot}else{[IO.Path]::GetFullPath([string]$invoke.payloadRoot)}
$bindings=@(@('adapter','adapterFile','adapterSha256'),@('engine','engineFile','engineSha256'),@('topology','topologyFile','topologySha256'),@('crop','cropFile','cropSha256'),@('seed','seedFile','seedSha256'),@('seed source','seedSourceFile','seedSourceSha256'),@('source record','sourceRecordFile','sourceRecordSha256'),@('runtime gate','runtimeGateFile','runtimeGateSha256'),@('runtime contract','runtimeContractFile','runtimeContractSha256'),@('job contract','jobContractFile','jobContractSha256'),@('terminal fixture','terminalFixtureFile','terminalFixtureSha256'),@('config gate','configGateFile','configGateSha256'))
$files=@{}; foreach($binding in $bindings){$path=Join-Path $payload ([string]$invoke.($binding[1])); Assert-O3Q6Pin $path ([string]$invoke.($binding[2])) $binding[0]; Assert-O3Q6Path $path; $files[$binding[0]]=$path}
$gate=Get-Content -LiteralPath $files['runtime gate'] -Raw|ConvertFrom-Json; $runtimeContract=Get-Content -LiteralPath $files['runtime contract'] -Raw|ConvertFrom-Json
Assert-O3Q6 ([string]$gate.schema-eq[string]$invoke.expectedRuntimeGateSchema-and[string]$gate.state-eq[string]$invoke.expectedRuntimeGateState-and[string]$gate.targetRole-eq'JBOD') 'O3Q6 file-backed runtime gate changed.'
Assert-O3Q6 ([string]$gate.python.version-eq[string]$invoke.expectedPythonVersion-and[string]$gate.python.sha256-eq[string]$invoke.runtimeSha256-and[string]$gate.installation.sha256-eq[string]$invoke.runtimeInstallationSha256-and[string]$gate.opencvVersion-eq[string]$invoke.expectedOpenCvVersion-and[string]$gate.numpyVersion-eq[string]$invoke.expectedNumpyVersion) 'O3Q6 runtime premise changed.'
$required=$runtimeContract.requiredJobFields; Assert-O3Q6 ([string]$required.expectedRuntimeGateSchema-eq[string]$invoke.expectedRuntimeGateSchema-and[string]$required.expectedRuntimeGateState-eq[string]$invoke.expectedRuntimeGateState-and[string]$required.expectedRuntimeSha256-eq[string]$invoke.runtimeSha256-and[string]$required.expectedRuntimeInstallationSha256-eq[string]$invoke.runtimeInstallationSha256) 'O3Q6 consumer runtime contract changed.'
$contract=Get-Content -LiteralPath $files['job contract'] -Raw|ConvertFrom-Json; $seed=Get-Content -LiteralPath $files['seed'] -Raw|ConvertFrom-Json; $source=Get-Content -LiteralPath $files['source record'] -Raw|ConvertFrom-Json; $config=Get-Content -LiteralPath $files['config gate'] -Raw|ConvertFrom-Json
Assert-O3Q6 ([string]$contract.schema-eq'argos_ocv03_o3q6_job_contract_v1'-and[int]$contract.expectedSeedCandidateCount-eq21-and[string]$contract.sourceAliasDrive-eq'Q:') 'O3Q6 job contract changed.'
Assert-O3Q6 ([string]$seed.identity-eq[string]$contract.input.identity-and@($seed.dfOnlyBoundaryCandidates).Count-eq21-and@($seed.physicalIndentationCandidates).Count-eq0) 'O3Q6 seed projection changed.'
Assert-O3Q6 ([string]$contract.input.bf.sha256-eq'3F98D5B506B3EF6E18BF9C24A64DC4516F024248DE994BD3DCBD5C8680EB7E90'-and[string]$contract.input.df.sha256-eq'E293D3155A50554104A232C1FF9F1BDA7E6935D798C7266A2C8A0F90FC0A098B') 'O3Q6 source hashes changed.'
Assert-O3Q6 ([string]$config.state-eq'PASS_O3P8_DETECTOR_CONFIG_EQUIVALENCE') 'O3Q6 detector config equivalence changed.'
Assert-O3Q6 ([string]$invoke.sourceAliasDrive-eq[string]$contract.sourceAliasDrive-and[string]$invoke.sourceAliasDrive-eq'Q:') 'O3Q6 source alias binding changed.'
$bfRelative=[string]$contract.input.bf.relativePath; $dfRelative=[string]$contract.input.df.relativePath
foreach($relative in @($bfRelative,$dfRelative)){Assert-O3Q6 (-not[IO.Path]::IsPathRooted($relative)-and$relative-notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3Q6 unsafe or rooted source-relative path.'}
$fixture=Get-Content -LiteralPath $files['terminal fixture'] -Raw|ConvertFrom-Json; $fixtureTerminal=Get-O3Q6Terminal $fixture.engineTerminal $fixture.engineOutput ([string]$fixture.engineTerminal.outputPath) $null
Assert-O3Q6 ([string]$fixture.schema-eq'argos_ocv03_o3q6_terminal_gate_fixture_v1'-and[string]$fixtureTerminal.state-eq[string]$fixture.expectedTerminal.state-and[bool]$fixtureTerminal.numericIndependentPass-eq[bool]$fixture.expectedTerminal.numericIndependentPass) 'O3Q6 terminal fixture failed.'
if($Preflight){[ordered]@{schema='argos_ocv03_o3q6_endpoint_preflight_v1';state='PASS_O3Q6_ENDPOINT_PREFLIGHT';rehearsal=[bool]$Rehearsal;payloadPinsPassed=$true;runtimePremiseConsumedFromFile=$true;runtimeReobserved=$false;sourceAliasDrive='Q:';constructedDrives=@('Q:');terminalFixturePassed=$true;sourceImageBytesRead=$false;outputCreated=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 8; return}

Assert-O3Q6 ([bool]$invoke.detectorRerunAuthorized) 'O3Q6 detector rerun authority is absent.'; Assert-O3Q6 ([bool]$invoke.sourceImageReadAuthorized-xor[bool]$Rehearsal) 'O3Q6 source-image authority does not match live/rehearsal mode.'
$sourceRoot=[IO.Path]::GetFullPath([string]$invoke.sourceRoot); $outputRoot=[IO.Path]::GetFullPath([string]$invoke.outputRoot); $partial=$outputRoot+'.partial'; $failed=$outputRoot+'.failed'; $parent=Split-Path -Parent $outputRoot
$alias=[string]$invoke.sourceAliasDrive; $aliasRoot=$alias+'\'; $jobPath=Join-Path $partial 'O3Q6_JOB.json'; $partialResult=Join-Path $partial 'O3Q6_RESULT.json'; $finalResult=Join-Path $outputRoot 'O3Q6_RESULT.json'
foreach($path in @($sourceRoot,$outputRoot,$partial,$failed,$jobPath,$partialResult,$finalResult)){Assert-O3Q6Path $path}; Assert-O3Q6 (Test-Path -LiteralPath $sourceRoot -PathType Container) 'O3Q6 source root is absent.'; Assert-O3Q6 (Test-Path -LiteralPath $parent -PathType Container) 'O3Q6 output parent is absent.'
foreach($path in @($outputRoot,$partial,$failed)){Assert-O3Q6 (-not(Test-Path -LiteralPath $path)) "O3Q6 create-new output exists: $path"}; Assert-O3Q6 (-not(Test-Path -LiteralPath $aliasRoot)) 'O3Q6 Q: alias is already in use.'
$executable=if($Rehearsal){[IO.Path]::GetFullPath([string]$invoke.rehearsalRuntimePath)}else{[IO.Path]::GetFullPath([string]$invoke.runtimePath)}; $runner=if($Rehearsal){Join-Path $payload ([string]$invoke.rehearsalProducerFile)}else{$files['adapter']}
if($Rehearsal){Assert-O3Q6Pin $executable ([string]$invoke.rehearsalRuntimeSha256) 'rehearsal runtime'; Assert-O3Q6Pin $runner ([string]$invoke.rehearsalProducerSha256) 'rehearsal producer'}else{Assert-O3Q6Pin $executable ([string]$invoke.runtimeSha256) 'runtime'; Assert-O3Q6Pin ([IO.Path]::GetFullPath([string]$invoke.runtimeInstallationPath)) ([string]$invoke.runtimeInstallationSha256) 'runtime installation'}
$aliasCreated=$false; $committed=$false; $terminal=$null
try{
  $subst=Join-Path $env:SystemRoot 'System32\subst.exe'; $aliasText=& $subst $alias $sourceRoot 2>&1|Out-String; Assert-O3Q6 ($LASTEXITCODE-eq0) ('O3Q6 alias creation failed: '+$aliasText.Trim()); Assert-O3Q6 (Test-Path -LiteralPath $aliasRoot -PathType Container) 'O3Q6 Q: alias is not visible.'; $aliasCreated=$true
  [void][IO.Directory]::CreateDirectory($partial); $bfPath=$alias+('/'+$bfRelative.Replace('\','/')); $dfPath=$alias+('/'+$dfRelative.Replace('\','/')); Assert-O3Q6 (([IO.Path]::GetPathRoot($bfPath))-eq'Q:\'-and([IO.Path]::GetPathRoot($dfPath))-eq'Q:\') 'O3Q6 constructed source drive is not Q:.'
  $job=[ordered]@{schema=[string]$contract.engineJobSchema;revision=[string]$contract.revision;runtimeRoot=[string]$invoke.runtimeRoot;runtimeGate=[ordered]@{path=$files['runtime gate'];sha256=[string]$invoke.runtimeGateSha256};topologyEngine=[ordered]@{path=$files['topology'];sha256=[string]$invoke.topologySha256};cropEngine=[ordered]@{path=$files['crop'];sha256=[string]$invoke.cropSha256};expectedRuntimeGateSchema=[string]$invoke.expectedRuntimeGateSchema;expectedRuntimeGateState=[string]$invoke.expectedRuntimeGateState;expectedRuntimeTargetRole='JBOD';expectedPythonVersion=[string]$invoke.expectedPythonVersion;expectedRuntimeSha256=[string]$invoke.runtimeSha256;expectedRuntimeInstallationSha256=[string]$invoke.runtimeInstallationSha256;expectedOpenCvVersion=[string]$invoke.expectedOpenCvVersion;expectedNumpyVersion=[string]$invoke.expectedNumpyVersion;channelMethods=$contract.channelMethods;crop=$contract.crop;topologyConfig=$contract.topologyConfig;corroboration=$contract.corroboration;candidateLocalTopologyErrors=@($contract.candidateLocalTopologyErrors);outputPath=$partialResult;expectedInputCount=1;inputs=@([ordered]@{identity=[string]$contract.input.identity;r6SeedResult=[ordered]@{path=$files['seed'];sha256=[string]$invoke.seedSha256};bf=[ordered]@{path=$bfPath;bytes=[int64]$contract.input.bf.bytes;sha256=[string]$contract.input.bf.sha256};df=[ordered]@{path=$dfPath;bytes=[int64]$contract.input.df.bytes;sha256=[string]$contract.input.df.sha256}});knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;scorerInputsPresent=$false;sourceMutationAllowed=$false;rasterOutputAllowed=$false;liveProviderActivation=$false;backsidePixelsConsumed=$false;dfTopologyInvocationAllowed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
  Write-O3Q6Json $jobPath $job; $child=Invoke-O3Q6Child $executable $runner $jobPath (Split-Path -Parent $executable) ([int]$invoke.pythonChildTimeoutSeconds) ([int]$invoke.maximumStdoutBytes); Assert-O3Q6 (-not[bool]$child.timedOut-and[int]$child.exitCode-eq0) ('O3Q6 producer failed: '+[string]$child.stderr)
  $engineTerminal=([string]$child.stdout).Trim()|ConvertFrom-Json; Assert-O3Q6Pin $partialResult ([string]$engineTerminal.outputSha256) 'producer output'; $output=Get-Content -LiteralPath $partialResult -Raw|ConvertFrom-Json; $terminal=Get-O3Q6Terminal $engineTerminal $output $finalResult $child
  Move-Item -LiteralPath $partial -Destination $outputRoot; $committed=$true; Assert-O3Q6Pin $finalResult ([string]$engineTerminal.outputSha256) 'committed producer output'
}catch{if($committed-and(Test-Path -LiteralPath $outputRoot)-and-not(Test-Path -LiteralPath $failed)){Move-Item -LiteralPath $outputRoot -Destination $failed -ErrorAction SilentlyContinue}elseif(Test-Path -LiteralPath $partial){Move-Item -LiteralPath $partial -Destination $failed -ErrorAction SilentlyContinue}; throw}
finally{if($aliasCreated){$removed=& (Join-Path $env:SystemRoot 'System32\subst.exe') $alias /D 2>&1|Out-String; if($LASTEXITCODE-ne0-or(Test-Path -LiteralPath $aliasRoot)){throw ('O3Q6 alias removal failed: '+$removed.Trim())}}}
$terminal.sourceAliasRemoved=$true; $terminal|ConvertTo-Json -Depth 16
