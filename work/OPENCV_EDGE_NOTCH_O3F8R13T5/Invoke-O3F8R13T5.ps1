#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$PackageLeafPreflight,[switch]$Rehearsal,[string]$InvocationManifest)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:fixtureMode=''
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Arg([string]$Value,[string]$Label){Require (-not[string]::IsNullOrWhiteSpace($Value)-and$Value-notmatch '[\s"\r\n]') "Unsafe child argument: $Label"}
function ChildJson([string]$Text,[string]$Label){Require (-not[string]::IsNullOrWhiteSpace($Text)) "$Label emitted no JSON";try{$Text|ConvertFrom-Json}catch{throw "$Label emitted invalid JSON"}}
function Invoke-Python([string]$Python,[string[]]$Arguments,[string]$Working,[int]$Timeout,[string]$Label){
    foreach($item in $Arguments){Arg $item $Label}
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$Python;$start.Arguments=($Arguments-join' ');$start.WorkingDirectory=$Working
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1';$start.EnvironmentVariables['PYTHONNOUSERSITE']='1';$start.EnvironmentVariables['PYTHONUTF8']='1'
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() "$Label did not start"
    $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
    if(-not$process.WaitForExit($Timeout*1000)){$process.Kill();$process.WaitForExit();throw "$Label timed out"}
    $result=[pscustomobject]@{ExitCode=$process.ExitCode;Stdout=([string]$stdout.Result).Trim();Stderr=([string]$stderr.Result).Trim()};$process.Dispose();$result
}
function Start-Python([string]$Python,[string[]]$Arguments,[string]$Working,[int]$Probe,[string]$Mode){
    foreach($item in $Arguments){Arg $item 'RUN worker'}
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=$Python;$start.Arguments=($Arguments-join' ');$start.WorkingDirectory=$Working
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1';$start.EnvironmentVariables['PYTHONNOUSERSITE']='1';$start.EnvironmentVariables['PYTHONUTF8']='1'
    if($Mode){$start.EnvironmentVariables['ARGOS_O3F8R13T5_FIXTURE_MODE']=$Mode}
    $process=New-Object Diagnostics.Process;$process.StartInfo=$start;Require $process.Start() 'RUN worker did not start'
    Start-Sleep -Seconds $Probe
    if($process.HasExited){$code=$process.ExitCode;$process.Dispose();throw "RUN worker exited immediately: $code"}
    [pscustomobject]@{Process=$process;Pid=$process.Id;CreationTimeUtc=$process.StartTime.ToUniversalTime().ToString('o')}
}
function Bootstrap([Diagnostics.Process]$Process,[string]$Progress,[int]$Timeout){
    $deadline=[DateTime]::UtcNow.AddSeconds($Timeout)
    while([DateTime]::UtcNow-lt$deadline){
        if(Test-Path -LiteralPath $Progress -PathType Leaf){$value=Get-Content -LiteralPath $Progress -Raw|ConvertFrom-Json;Require ([string]$value.schema-eq'argos_ocv03_o3f8_r13_targeted_progress_v1'-and[string]$value.state-eq'RUNNING_O3F8_R13_TARGETED'-and[int]$value.scheduledCount-eq11) 'Bootstrap progress changed';return $value}
        if($Process.HasExited){$code=$Process.ExitCode;$Process.Dispose();throw "RUN worker exited before progress: $code"}
        Start-Sleep -Milliseconds 250
    }
    if(-not$Process.HasExited){$Process.Kill();$Process.WaitForExit()};$Process.Dispose();throw 'RUN bootstrap timed out'
}
function Contract([object]$Value){
    Require ([string]$Value.schema-eq'argos_ocv03_o3f8r13t5_launch_contract_v1'-and[string]$Value.state-eq'FROZEN_FOR_BUILD') 'Contract identity changed'
    Require ([string]$Value.expectedComputerName-eq'A1025645101'-and[int]$Value.expectedPairCount-eq11-and[int]$Value.hotspotCount-eq10-and[int]$Value.providerErrorCount-eq5) 'Target cohort changed'
    Require ([string]$Value.runtimeRoot-eq'D:/O3F8R13T5RT'-and[string]$Value.corpusRoot-eq'D:/O3F8R13T5C'-and[string]$Value.mirrorRoot-eq'D:/KLARFExport/_ArgosReview/F8R13T5S') 'Target roots changed'
    Require ([string]$Value.runtimePath-eq'D:/AFCV1/rt/python.exe'-and[string]$Value.runtimeSha256-eq'7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'Runtime pin changed'
    Require ([string]$Value.expectedLaunchState-eq'PASS_O3F8R13T5_TARGETED_WORKER_LAUNCHED'-and[string]$Value.expectedRehearsalState-eq'PASS_O3F8R13T5_REHEARSAL_WORKER_LAUNCHED') 'Launch states changed'
    Require (-not[bool]$Value.requestRetryAuthorized-and[bool]$Value.reviewOnly-and-not[bool]$Value.productionRoutingEnabled) 'Authority widened'
}
function Payload([object]$Value){
    $rows=@($Value.payloadFiles);Require ($rows.Count-ge20) 'Payload is incomplete'
    foreach($row in $rows){$name=[string]$row.name;Require (-not[IO.Path]::IsPathRooted($name)-and$name-notmatch'[\\/]') "Unsafe payload name: $name";$path=Join-Path $PSScriptRoot $name;Require (Test-Path -LiteralPath $path -PathType Leaf) "Payload missing: $name";Require ((Sha $path)-eq[string]$row.sha256) "Payload changed: $name"}
    $rows
}
function Main{
    Require (-not($PackageLeafPreflight-and($Preflight-or$Rehearsal-or$InvocationManifest))) 'Package-leaf mode cannot be combined'
    Require ($Rehearsal-or[string]::IsNullOrWhiteSpace($InvocationManifest)) 'Invocation manifest is rehearsal-only'
    $contractPath=Join-Path $PSScriptRoot 'O3F8R13T5_LAUNCH_CONTRACT.json';Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'Contract missing'
    $contract=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json;Contract $contract;$payload=@(Payload $contract)
    if($PackageLeafPreflight){[ordered]@{schema='argos_ocv03_o3f8r13t5_package_leaf_preflight_v1';state='PASS_O3F8R13T5_PACKAGE_LEAVES';payloadPinCount=$payload.Count;expectedPairCount=11;imageBytesRead=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
    if($Rehearsal){
        Require (-not[string]::IsNullOrWhiteSpace($InvocationManifest)) 'Rehearsal invocation missing';$inv=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
        Require ([string]$inv.schema-eq'argos_ocv03_o3f8r13t5_rehearsal_invocation_v1'-and[string]$inv.fixtureMode-in@('NORMAL','IMMEDIATE_EXIT')) 'Rehearsal invocation changed'
        $script:fixtureMode=[string]$inv.fixtureMode;$python=[IO.Path]::GetFullPath([string]$inv.pythonPath);Require ((Sha $python)-eq[string]$inv.pythonSha256) 'Rehearsal Python changed'
        $runtime=[IO.Path]::GetFullPath([string]$inv.runtimeRoot);$corpus=[IO.Path]::GetFullPath([string]$inv.corpusRoot);$mirror=[IO.Path]::GetFullPath([string]$inv.mirrorRoot)
        foreach($root in @($runtime,$corpus,$mirror)){Require ($root-notmatch'(?i)^D:\\') 'Rehearsal root entered JBOD D:'}
        $runnerName='O3F8R13T5LaunchFixture.py'
    }else{
        Require ([Environment]::MachineName-eq[string]$contract.expectedComputerName) 'Wrong computer'
        $python=[string]$contract.runtimePath;Require ((Sha $python)-eq[string]$contract.runtimeSha256) 'Runtime changed'
        foreach($pin in @($contract.targetPins)){Require (Test-Path -LiteralPath ([string]$pin.path) -PathType Leaf) "Target pin missing: $($pin.path)";Require ((Sha ([string]$pin.path))-eq[string]$pin.sha256) "Target pin changed: $($pin.path)"}
        Require (-not([Environment]::GetLogicalDrives()-contains'Q:\')) 'Q: alias is occupied'
        $runtime=[string]$contract.runtimeRoot;$corpus=[string]$contract.corpusRoot;$mirror=[string]$contract.mirrorRoot;$runnerName='Run-O3F8R13Targeted.py'
    }
    foreach($root in @($runtime,$corpus,$mirror)){Require (-not(Test-Path -LiteralPath $root)) "Create-new root exists: $root";Require (Test-Path -LiteralPath (Split-Path -Parent $root) -PathType Container) "Root parent missing: $root"}
    if($Preflight){[ordered]@{schema='argos_ocv03_o3f8r13t5_target_preflight_v1';state='PASS_O3F8R13T5_TARGET_PREFLIGHT';expectedPairCount=11;hotspotCount=10;providerErrorCount=5;imageBytesRead=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}|ConvertTo-Json -Compress;return}
    [void](New-Item -ItemType Directory -Path $runtime)
    foreach($row in @($payload|Where-Object{[bool]$_.copyToRuntime})){[IO.File]::Copy((Join-Path $PSScriptRoot ([string]$row.name)),(Join-Path $runtime ([string]$row.name)),$false)}
    if(-not$Rehearsal){
        $test=Invoke-Python $python @('-I','-B',(Join-Path $runtime 'Test-O3F8R13DfCandidateLimitT2.py')) $runtime ([int]$contract.testTimeoutSeconds) 'R13 limit test';if($test.ExitCode-ne0-or$test.Stderr){$detail=([string]$test.Stderr);if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ('R13 limit test failed: '+$detail)};$testJson=ChildJson $test.Stdout 'R13 limit test';Require ([string]$testJson.state-eq'PASS_O3F8_R13_DF_CANDIDATE_LIMIT_T2') 'R13 limit test state changed'
        $pin=Invoke-Python $python @('-I','-B',(Join-Path $runtime 'Test-O3F8R13TargetedPinIsolationT3.py')) $runtime ([int]$contract.testTimeoutSeconds) 'R13 pin test';if($pin.ExitCode-ne0-or$pin.Stderr){$detail=([string]$pin.Stderr);if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ('R13 pin test failed: '+$detail)};$pinJson=ChildJson $pin.Stdout 'R13 pin test';Require ([string]$pinJson.state-eq'PASS_O3F8_R13_TARGETED_PIN_ISOLATION_T3') 'R13 pin test state changed'
        $binding=Invoke-Python $python @('-I','-B',(Join-Path $runtime 'Test-O3F8R13ExecutionBindingT5.py')) $runtime ([int]$contract.testTimeoutSeconds) 'R13 execution binding test';if($binding.ExitCode-ne0-or$binding.Stderr){$detail=([string]$binding.Stderr);if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ('R13 execution binding test failed: '+$detail)};$bindingJson=ChildJson $binding.Stdout 'R13 execution binding test';Require ([string]$bindingJson.state-eq'PASS_O3F8_R13_EXECUTION_BINDING_T5') 'R13 execution binding test state changed'
        $closure=Invoke-Python $python @('-I','-B',(Join-Path $runtime 'Test-O3F8R13PackageClosureT4.py')) $runtime ([int]$contract.testTimeoutSeconds) 'R13 closure test';if($closure.ExitCode-ne0-or$closure.Stderr){$detail=([string]$closure.Stderr);if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ('R13 closure test failed: '+$detail)};$closureJson=ChildJson $closure.Stdout 'R13 closure test';Require ([string]$closureJson.state-eq'PASS_O3F8_R13_PACKAGE_CLOSURE_T4') 'R13 closure test state changed'
        $self=Invoke-Python $python @('-I','-B',(Join-Path $runtime $runnerName),'SELF_TEST') $runtime ([int]$contract.testTimeoutSeconds) 'Targeted SELF_TEST';if($self.ExitCode-ne0-or$self.Stderr){$detail=([string]$self.Stderr);if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ('Targeted SELF_TEST failed: '+$detail)};$selfJson=ChildJson $self.Stdout 'Targeted SELF_TEST';Require ([string]$selfJson.state-eq'PASS_O3F8_R13_TARGETED_SELF_TEST') 'Targeted SELF_TEST changed'
        $pre=Invoke-Python $python @('-I','-B',(Join-Path $runtime $runnerName),'PREFLIGHT') $runtime ([int]$contract.preflightTimeoutSeconds) 'Targeted PREFLIGHT';if($pre.ExitCode-ne0-or$pre.Stderr){$detail=([string]$pre.Stderr);if($detail.Length-gt800){$detail=$detail.Substring(0,800)};throw ('Targeted PREFLIGHT failed: '+$detail)};$preJson=ChildJson $pre.Stdout 'Targeted PREFLIGHT';Require ([string]$preJson.state-eq'PASS_O3F8_R13_TARGETED_PREFLIGHT'-and[int]$preJson.unionCount-eq11) 'Targeted PREFLIGHT changed'
    }else{$testJson=[pscustomobject]@{state='PASS_O3F8_R13_DF_CANDIDATE_LIMIT_T2'};$pinJson=[pscustomobject]@{state='PASS_O3F8_R13_TARGETED_PIN_ISOLATION_T3'};$bindingJson=[pscustomobject]@{state='PASS_O3F8_R13_EXECUTION_BINDING_T5'};$closureJson=[pscustomobject]@{state='PASS_O3F8_R13_PACKAGE_CLOSURE_T4'};$selfJson=[pscustomobject]@{state='PASS_O3F8_R13_TARGETED_SELF_TEST'};$preJson=[pscustomobject]@{state='PASS_O3F8_R13_TARGETED_PREFLIGHT'}}
    $worker=Start-Python $python @('-I','-B',(Join-Path $runtime $runnerName),'RUN','--output-root',$corpus,'--mirror-root',$mirror) $runtime ([int]$contract.survivalProbeSeconds) $script:fixtureMode
    $bootstrap=Bootstrap $worker.Process (Join-Path $mirror 'PROGRESS.json') ([int]$contract.bootstrapProgressTimeoutSeconds);$worker.Process.Dispose()
    [ordered]@{schema=$(if($Rehearsal){'argos_ocv03_o3f8r13t5_rehearsal_launch_v1'}else{'argos_ocv03_o3f8r13t5_launch_v1'});state=$(if($Rehearsal){[string]$contract.expectedRehearsalState}else{[string]$contract.expectedLaunchState});fixtureMode=$(if($Rehearsal){$script:fixtureMode}else{$null});testState=[string]$testJson.state;pinTestState=[string]$pinJson.state;bindingTestState=[string]$bindingJson.state;closureTestState=[string]$closureJson.state;selfTestState=[string]$selfJson.state;preflightState=[string]$preJson.state;pid=$worker.Pid;creationTimeUtc=$worker.CreationTimeUtc;runtimeRoot=$runtime;corpusRoot=$corpus;mirrorRoot=$mirror;bootstrapProgressState=[string]$bootstrap.state;bootstrapScheduledCount=[int]$bootstrap.scheduledCount;sourceImagesReadByEndpoint=$false;existingProcessesQueried=$false;existingProcessOrTaskActionPerformed=$false;ownedProcessStarted=$true;automaticRetryAuthorized=$false;holdsCleared=$false;mutationsPerformed=$true;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6 -Compress
}
try{Main}catch{if($Rehearsal){$message=[string]$_.Exception.Message;[ordered]@{schema='argos_ocv03_o3f8r13t5_rehearsal_launch_v1';state=$(if($message-match'Create-new root exists'){'HOLD_O3F8R13T5_REHEARSAL_CREATE_NEW_COLLISION'}elseif($message-match'exited immediately'){'HOLD_O3F8R13T5_REHEARSAL_WORKER_EXITED_IMMEDIATELY'}else{'HOLD_O3F8R13T5_REHEARSAL_FAILURE'});fixtureMode=$script:fixtureMode;error=$message;imageBytesRead=$false;reviewOnly=$true}|ConvertTo-Json -Compress;exit 2};throw}
