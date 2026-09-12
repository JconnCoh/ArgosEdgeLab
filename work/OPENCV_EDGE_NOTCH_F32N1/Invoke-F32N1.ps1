#Requires -Version 5.1
[CmdletBinding()]
param([switch]$PackageLeafPreflight,[switch]$Rehearsal,[string]$InvocationManifest)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
Require (-not($PackageLeafPreflight-and$Rehearsal)) 'Package-leaf preflight and rehearsal cannot be combined'
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Arg([string]$Value,[string]$Label){Require (-not[string]::IsNullOrWhiteSpace($Value)-and$Value-notmatch '[\s"\r\n]') "Unsafe child argument: $Label"}
function Invoke-Python([string]$Python,[string[]]$Arguments,[string]$Working,[int]$TimeoutSeconds,[string]$Label){
    foreach($value in $Arguments){Arg $value $Label}
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$Python;$start.Arguments=($Arguments-join' ');$start.WorkingDirectory=$Working
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1';$start.EnvironmentVariables['PYTHONNOUSERSITE']='1';$start.EnvironmentVariables['PYTHONUTF8']='1'
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() "$Label did not start"
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not$process.WaitForExit($TimeoutSeconds*1000)){try{$process.Kill()}catch{};$process.WaitForExit();$process.Dispose();throw "$Label timed out"}
    $process.WaitForExit();$result=[pscustomobject]@{exitCode=$process.ExitCode;stdout=([string]$stdout.Result).Trim();stderr=([string]$stderr.Result).Trim()};$process.Dispose()
    if($result.exitCode-ne0-or-not[string]::IsNullOrWhiteSpace($result.stderr)){$detail=[string]$result.stderr;if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ("$Label failed: "+$detail)}
    Require ($result.stdout.Length-le1048576) "$Label output exceeded 1 MiB"
    try{return($result.stdout|ConvertFrom-Json)}catch{throw "$Label emitted invalid JSON"}
}
function Start-Python([string]$Python,[string[]]$Arguments,[string]$Working,[int]$Probe,[string]$Mode){
    foreach($value in $Arguments){Arg $value 'F32N1 RUN worker'}
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$Python;$start.Arguments=($Arguments-join' ');$start.WorkingDirectory=$Working
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1';$start.EnvironmentVariables['PYTHONNOUSERSITE']='1';$start.EnvironmentVariables['PYTHONUTF8']='1'
    if($Mode){$start.EnvironmentVariables['ARGOS_O3F8R13T5_FIXTURE_MODE']=$Mode}
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'F32N1 RUN worker did not start'
    Start-Sleep -Seconds $Probe
    if($process.HasExited){$code=$process.ExitCode;$process.Dispose();throw "F32N1 RUN worker exited immediately: $code"}
    [pscustomobject]@{Process=$process;Pid=$process.Id;CreationTimeUtc=$process.StartTime.ToUniversalTime().ToString('o')}
}
function Bootstrap([Diagnostics.Process]$Process,[string]$Progress,[int]$Timeout,[bool]$Fixture){
    $deadline=[DateTime]::UtcNow.AddSeconds($Timeout)
    while([DateTime]::UtcNow-lt$deadline){
        if(Test-Path -LiteralPath $Progress -PathType Leaf){$value=Get-Content -LiteralPath $Progress -Raw|ConvertFrom-Json;if($Fixture){Require ([string]$value.state-eq'RUNNING_O3F8_R13_TARGETED') 'Fixture bootstrap changed'}else{Require ([string]$value.schema-eq'argos_ocv03_o3f16r32_neutral_progress_v1'-and[string]$value.state-eq'RUNNING_R32_FOUR_PAIR_NEUTRAL'-and[int]$value.scheduledCount-eq4-and[int]$value.pid-eq$Process.Id-and-not[bool]$value.sourceImageDecoded-and-not[bool]$value.scorerLabelsRead-and-not[bool]$value.terminal) 'Live bootstrap changed'};return $value}
        if($Process.HasExited){$code=$Process.ExitCode;$Process.Dispose();throw "F32N1 RUN worker exited before bootstrap: $code"}
        Start-Sleep -Milliseconds 250
    }
    if(-not$Process.HasExited){$Process.Kill();$Process.WaitForExit()};$Process.Dispose();throw 'F32N1 RUN bootstrap timed out'
}

$contractPath=Join-Path $PSScriptRoot 'F32N1_LAUNCH_CONTRACT.json'
Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'F32N1 launch contract is absent'
$contract=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json
Require ([string]$contract.schema-eq'argos_ocv03_f32n1_launch_contract_v1'-and[string]$contract.state-eq'FROZEN_FOR_BUILD') 'F32N1 contract identity changed'
Require ([int]$contract.expectedPairCount-eq4-and[int]$contract.expectedSourceLeafCount-eq8-and[string]$contract.side-eq'FRONT') 'F32N1 population changed'
Require ([string]$contract.expectedComputerName-eq'A1025645101'-and[string]$contract.runtimeRoot-eq'D:\F32N1RT') 'F32N1 target changed'
Require ([string]$contract.outputRoot-eq'D:\ArgosProjectPortalRO\OCV03ReviewExports\F32N1'-and[string]$contract.mirrorRoot-eq'D:\F32N1S') 'F32N1 result roots changed'
Require ([string]$contract.lockedSourceRoot-eq'D:\KLARFExport'-and[bool]$contract.reviewOnly-and-not[bool]$contract.trainingEligible-and-not[bool]$contract.xmlEligible-and-not[bool]$contract.productionEligible-and-not[bool]$contract.productionRoutingEnabled-and-not[bool]$contract.requestRetryAuthorized) 'F32N1 authority widened'
$rows=@($contract.payloadFiles);Require ($rows.Count-eq36-and@($rows|Where-Object{[bool]$_.copyToRuntime}).Count-eq33) 'F32N1 payload closure changed'
$seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach($row in $rows){
    $name=[string]$row.name;Require (-not[IO.Path]::IsPathRooted($name)-and$name-notmatch'[\\/]'-and$seen.Add($name)) "Unsafe or duplicate payload name: $name"
    $path=Join-Path $PSScriptRoot $name;Require (Test-Path -LiteralPath $path -PathType Leaf) "F32N1 payload absent: $name"
    Require ((Get-Item -LiteralPath $path).Length-eq[int64]$row.bytes-and(Sha $path)-eq[string]$row.sha256) "F32N1 payload changed: $name"
}
$actual=@(Get-ChildItem -LiteralPath $PSScriptRoot -Force);Require ($actual.Count-eq$rows.Count+1-and@($actual|Where-Object{-not$_.PSIsContainer}).Count-eq$actual.Count) 'F32N1 payload cardinality changed'
Require (@($actual|Where-Object{$_.Name-eq'F32N1_LAUNCH_CONTRACT.json'}).Count-eq1) 'F32N1 contract leaf changed'
foreach($required in @('Invoke-F32N1.ps1','Run-O3F16R32FourPairNeutral.py','O3F16R32_FOUR_PAIR_NEUTRAL_JOB.json','O3F16R32_UNREAD_HOLDOUTS.json','AnnularUnwrapCandidateFirstOpenCvR32.py','AnnularUnwrapCandidateFirstOpenCvR31.py','AnnularUnwrapCandidateFirstOpenCvR30.py','AnnularUnwrapCandidateFirstOpenCvR27.py','AnnularUnwrapDiagnosticOpenCvR18.py','Run-O3F16R28FullKlarfReview.py','O3F8R13T5LaunchFixture.py')){Require $seen.Contains($required) "F32N1 required payload absent: $required"}
if($PackageLeafPreflight){[ordered]@{schema='argos_ocv03_f32n1_package_leaf_preflight_v1';state='PASS_F32N1_EXACT_PACKAGE_LEAVES';payloadPinCount=$rows.Count;runtimeCopyFileCount=33;sourceImageBytesRead=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
if($Rehearsal){Require (-not[string]::IsNullOrWhiteSpace($InvocationManifest)) 'F32N1 rehearsal invocation missing';$inv=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json;Require ([string]$inv.schema-eq'argos_ocv03_f32n1_rehearsal_invocation_v1'-and[string]$inv.fixtureMode-in@('NORMAL','IMMEDIATE_EXIT')) 'F32N1 rehearsal invocation changed';$mode=[string]$inv.fixtureMode;$python=[IO.Path]::GetFullPath([string]$inv.pythonPath);$expectedPythonHash=[string]$inv.pythonSha256;$runtime=[IO.Path]::GetFullPath([string]$inv.runtimeRoot);$output=[IO.Path]::GetFullPath([string]$inv.outputRoot);$mirror=[IO.Path]::GetFullPath([string]$inv.mirrorRoot);foreach($root in @($runtime,$output,$mirror)){Require ($root-notmatch'(?i)^D:\\') 'F32N1 rehearsal entered JBOD D:'};$runnerName='O3F8R13T5LaunchFixture.py'}else{Require ([string]::IsNullOrWhiteSpace($InvocationManifest)) 'Invocation manifest is rehearsal-only';Require ([Environment]::MachineName-eq[string]$contract.expectedComputerName) 'F32N1 wrong computer';foreach($pin in @($contract.targetPins)){Require (Test-Path -LiteralPath ([string]$pin.path) -PathType Leaf) "F32N1 target pin absent: $($pin.path)";Require ((Sha ([string]$pin.path))-eq[string]$pin.sha256) "F32N1 target pin changed: $($pin.path)"};$mode='';$python=[string]$contract.runtimePath;$expectedPythonHash=[string]$contract.runtimeSha256;$runtime=[string]$contract.runtimeRoot;$output=[string]$contract.outputRoot;$mirror=[string]$contract.mirrorRoot;$runnerName='Run-O3F16R32FourPairNeutral.py'}
Require (Test-Path -LiteralPath $python -PathType Leaf) 'F32N1 Python runtime is absent';Require ((Sha $python)-eq$expectedPythonHash) 'F32N1 Python runtime changed'
$command=Get-Command -Name $python -CommandType Application -ErrorAction Stop;Require ([IO.Path]::GetFullPath($command.Source)-eq[IO.Path]::GetFullPath($python)) 'F32N1 Python command resolution changed'
if(-not$Rehearsal){foreach($path in @([string]$contract.lockedSourceRoot,(Split-Path -Parent $runtime),(Split-Path -Parent $output),(Split-Path -Parent $mirror))){Require (Test-Path -LiteralPath $path -PathType Container) "F32N1 required parent absent: $path"};$drive=New-Object IO.DriveInfo 'D:';Require ([int64]$drive.AvailableFreeSpace-ge 64GB) 'F32N1 JBOD D: reserve below 64 GiB'}
foreach($path in @($runtime,$output,$mirror)){Require (-not(Test-Path -LiteralPath $path)) "F32N1 create-new root exists: $path";Require (Test-Path -LiteralPath (Split-Path -Parent $path) -PathType Container) "F32N1 root parent absent: $path"}
[void](New-Item -ItemType Directory -Path $runtime)
foreach($row in @($rows|Where-Object{[bool]$_.copyToRuntime})){[IO.File]::Copy((Join-Path $PSScriptRoot ([string]$row.name)),(Join-Path $runtime ([string]$row.name)),$false)}
$runner=Join-Path $runtime $runnerName
if(-not$Rehearsal){$pre=Invoke-Python $python @('-I','-B',$runner,'PREFLIGHT') $runtime 120 'F32N1 provider PREFLIGHT';Require ([string]$pre.state-eq'PASS_R32_FOUR_PAIR_NEUTRAL_PREFLIGHT'-and[int]$pre.pairCount-eq4-and-not[bool]$pre.sourceImageBytesRead-and-not[bool]$pre.scorerLabelsRead-and-not[bool]$pre.mutationsPerformed-and[bool]$pre.reviewOnly) 'F32N1 provider preflight changed'}else{$pre=[pscustomobject]@{state='PASS_F32N1_REHEARSAL_PROVIDER_BYPASS'}}
$workerArgs=@(if($Rehearsal){'-I';'-B';$runner;'RUN';'--output-root';$output;'--mirror-root';$mirror}else{'-I';'-B';$runner;'RUN'})
$worker=Start-Python $python $workerArgs $runtime 3 $mode
$bootstrap=Bootstrap $worker.Process (Join-Path $mirror 'PROGRESS.json') 60 ([bool]$Rehearsal);$worker.Process.Dispose()
[ordered]@{schema=$(if($Rehearsal){'argos_ocv03_f32n1_rehearsal_launch_v1'}else{'argos_ocv03_f32n1_launch_v1'});state=$(if($Rehearsal){'PASS_F32N1_REHEARSAL_WORKER_AT_BOOTSTRAP'}else{'PASS_F32N1_R32_WORKER_AT_BOOTSTRAP'});fixtureMode=$(if($Rehearsal){$mode}else{$null});providerPreflightState=[string]$pre.state;pid=$worker.Pid;creationTimeUtc=$worker.CreationTimeUtc;runtimeRoot=$runtime;outputRoot=$output;mirrorRoot=$mirror;bootstrapState=[string]$bootstrap.state;bootstrapScheduledCount=[int]$bootstrap.scheduledCount;completionClaimed=$false;sourceImagesReadByEndpoint=$false;existingProcessesQueried=$false;existingProcessOrTaskActionPerformed=$false;ownedProcessStarted=$true;automaticRetryAuthorized=$false;holdsCleared=$false;mutationsPerformed=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5 -Compress
