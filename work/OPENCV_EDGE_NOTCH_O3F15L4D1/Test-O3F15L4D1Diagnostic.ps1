#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Test)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Write-NewJson([string]$Path,[object]$Value){Require (-not(Test-Path -LiteralPath $Path)) "D1 create-new path exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}
function Quote([string]$Value){'"'+$Value.Replace('"','\"')+'"'}
function Invoke-Captured([string]$PowerShell,[string[]]$Arguments,[string]$WorkingDirectory){$s=New-Object Diagnostics.ProcessStartInfo;$s.FileName=$PowerShell;$s.Arguments=(@($Arguments|ForEach-Object{Quote $_})-join ' ');$s.WorkingDirectory=$WorkingDirectory;$s.UseShellExecute=$false;$s.CreateNoWindow=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;$p=New-Object Diagnostics.Process;$p.StartInfo=$s;Require $p.Start() 'D1 test child did not start.';$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$p.WaitForExit();$r=[ordered]@{exitCode=[int]$p.ExitCode;stdout=[string]$o.Result;stderr=[string]$e.Result};$p.Dispose();$r}
function Parse-One([string]$Text,[string]$Label){$lines=@($Text -split '\r?\n'|Where-Object{-not[string]::IsNullOrWhiteSpace($_)});Require ($lines.Count -eq 1) "D1 $Label line count changed.";try{$lines[0]|ConvertFrom-Json}catch{throw "D1 $Label malformed JSON."}}
function Invoke-Case([string]$Mode,[int]$Timeout,[string]$Root,[string]$Endpoint,[string]$PowerShell,[string]$Python,[string]$PythonSha){$m=Join-Path $Root ($Mode+'.json');Write-NewJson $m ([ordered]@{schema='argos_ocv03_o3f15l4d1_rehearsal_invocation_v1';fixtureMode=$Mode;pythonPath=$Python;pythonSha256=$PythonSha;timeoutSeconds=$Timeout});$c=Invoke-Captured $PowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Endpoint,'-Rehearsal','-InvocationManifest',$m) (Split-Path -Parent $Endpoint);Require ($c.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($c.stderr)) "D1 outer case failed: $Mode";$bytes=[Text.Encoding]::UTF8.GetByteCount($c.stdout);Require ($bytes -le 7340032) "D1 emitted JSON bound failed: $Mode";$r=Parse-One $c.stdout $Mode;[ordered]@{mode=$Mode;bytes=$bytes;result=$r}}
Require ($Preflight -xor $Test) 'Specify exactly one action.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) 'D1 diagnostic test requires Windows PowerShell 5.1.'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath=Join-Path $PSScriptRoot 'O3F15L4D1_DIAGNOSTIC_CONTRACT.json'
$contract=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json
$powerShell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$python=(Get-Command python.exe -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source
$gatePath=Join-Path $PSScriptRoot 'O3F15L4D1_LOCAL_DIAGNOSTIC_GATE.json'
$root='C:\O3F15L4D1T'
foreach($path in @($contractPath,$powerShell,$python)){Require(Test-Path -LiteralPath $path -PathType Leaf) "D1 test dependency absent: $path"}
foreach($record in @($contract.payloadFiles)){$source=Join-Path $project ([string]$record.source);Require((Sha $source)-ceq[string]$record.sha256) "D1 source payload changed: $($record.name)"}
if($Preflight){[ordered]@{schema='argos_ocv03_o3f15l4d1_local_test_preflight_v1';state='PASS_O3F15L4D1_LOCAL_TEST_PREFLIGHT';caseCount=9;root=$root;targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress;return}
foreach($path in @($root,$gatePath)){Require(-not(Test-Path -LiteralPath $path)) "D1 create-new test target exists: $path"}
$payload=Join-Path $root 'payload';[void](New-Item -ItemType Directory -Path $payload -Force)
foreach($record in @($contract.payloadFiles)){[IO.File]::Copy((Join-Path $project ([string]$record.source)),(Join-Path $payload ([string]$record.name)),$false)}
[IO.File]::Copy($contractPath,(Join-Path $payload 'O3F15L4D1_DIAGNOSTIC_CONTRACT.json'),$false)
$endpoint=Join-Path $payload 'Invoke-O3F15L4D1.ps1';$pythonSha=Sha $python;$cases=[ordered]@{}
foreach($mode in @('PASS','PASS_ONE_ALIAS','PASS_MANY_ALIAS','CLASSIFICATION_OVERSIZE','ZERO_STDERR','NONZERO','MALFORMED','TIMEOUT','OVERSIZE')){$cases[$mode]=Invoke-Case $mode $(if($mode-ceq'TIMEOUT'){1}else{20}) $root $endpoint $powerShell $python $pythonSha}
foreach($mode in @('PASS','PASS_ONE_ALIAS','PASS_MANY_ALIAS')){$r=$cases[$mode].result;Require([string]$r.state-ceq'COMPLETE_O3F15L4D1_METADATA_DIAGNOSTIC' -and [string]$r.childOutcome-ceq'PASS' -and [int]$r.ownedChildCount-eq 1 -and [int]$r.actualFrozen978LexicalClassification.identityCount-eq 978 -and [int]$r.actualFrozen978LexicalClassification.sourceLeafCount-eq 1956) "D1 valid case failed: $mode"}
Require([int]$cases.PASS.result.actualFrozen978LexicalClassification.sourceLeafClassificationCounts.VERIFIED_SHORT_ALIAS_REQUIRED-eq 0) 'D1 ZERO collection case failed.'
Require([int]$cases.PASS_ONE_ALIAS.result.actualFrozen978LexicalClassification.sourceLeafClassificationCounts.VERIFIED_SHORT_ALIAS_REQUIRED-eq 1) 'D1 ONE collection case failed.'
Require([int]$cases.PASS_MANY_ALIAS.result.actualFrozen978LexicalClassification.sourceLeafClassificationCounts.VERIFIED_SHORT_ALIAS_REQUIRED-eq 17) 'D1 MANY collection case failed.'
foreach($mode in @('CLASSIFICATION_OVERSIZE','ZERO_STDERR','NONZERO','MALFORMED','TIMEOUT','OVERSIZE')){Require([string]$cases[$mode].result.state-ceq'HOLD_O3F15L4D1_METADATA_DIAGNOSTIC' -and [string]$cases[$mode].result.childOutcome-ceq'FAIL') "D1 hold case failed: $mode"}
Require([bool]$cases.OVERSIZE.result.childOutputExceededBound -and [int64]$cases.OVERSIZE.result.childOutputBytes -eq 5242881) 'D1 combined child oversize was not rejected.'
Require([bool]$cases.TIMEOUT.result.childTimedOut) 'D1 timeout was not captured.'
$pinRoot=Join-Path $root 'pin';[void](New-Item -ItemType Directory -Path $pinRoot);foreach($leaf in @(Get-ChildItem -LiteralPath $payload -File)){[IO.File]::Copy($leaf.FullName,(Join-Path $pinRoot $leaf.Name),$false)}
[IO.File]::WriteAllText((Join-Path $pinRoot 'Run-O3F15L4FrontReconcile.py'),'PIN_FAILURE',(New-Object Text.UTF8Encoding($false)))
$pin=Invoke-Captured $powerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $pinRoot 'Invoke-O3F15L4D1.ps1'),'-PackageLeafPreflight') $pinRoot
Require($pin.exitCode-eq 0 -and [string]::IsNullOrWhiteSpace($pin.stderr)) 'D1 pre-child pin case outer process failed.';$pinResult=Parse-One $pin.stdout 'pin failure'
Require([string]$pinResult.state-ceq'HOLD_O3F15L4D1_METADATA_DIAGNOSTIC' -and [string]$pinResult.childOutcome-ceq'NOT_STARTED' -and [bool]$pinResult.preChildFailure -and [int]$pinResult.ownedChildCount-eq 0) 'D1 pre-child pin failure was not bounded.'
$gate=[ordered]@{schema='argos_ocv03_o3f15l4d1_local_diagnostic_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4D1_COMPLETE_METADATA_DIAGNOSTIC_REHEARSAL';windowsPowerShell=@{major=5;minor=1};caseCount=9;zeroOneMany=@{ZERO='PASS';ONE='PASS';MANY='PASS'};cases=@($cases.Keys|ForEach-Object{[ordered]@{mode=$_;state=[string]$cases[$_].result.state;childOutcome=[string]$cases[$_].result.childOutcome;emittedJsonBytes=[int]$cases[$_].bytes}});maximumChildOutputBytes=5242880;maximumEmittedJsonBytes=7340032;oversizeRejected=$true;preChildPinFailureBounded=$true;selfTestStarted=$false;focusedTestStarted=$false;gateStarted=$false;runStarted=$false;qSubstCreated=$false;detectorResultRootCreated=$false;backgroundLaunchStarted=$false;imageBytesRead=$false;sourceMutation=$false;existingTaskOrProcessAction=$false;providerActivated=$false;selectorThresholdRelaxed=$false;holdsAutomaticallyCleared=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson $gatePath $gate;$gate|ConvertTo-Json -Depth 10 -Compress
