[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if(@($Preflight,$Gate|Where-Object{$_}).Count-ne1){throw 'Specify exactly one of -Preflight or -Gate.'}
$root=Split-Path -Parent $MyInvocation.MyCommand.Path
$entry=Join-Path $root 'pkg\payload\E.ps1'
$worker=Join-Path $root 'pkg\payload\W.ps1'
$config=Join-Path $root 'pkg\payload\C.json'
$priorWorker=Join-Path (Split-Path -Parent $root) 'FIDUCIAL_JBOD_INVENTORY_CAPABILITY_FIC1\pkg\payload\W.ps1'
$priorConfigEvidence=Join-Path (Split-Path -Parent $root) 'JBOD_ENDPOINT_ROOT_DIAGNOSTIC_C1F0\C1F0_LIVE_ENDPOINT_CONFIG.json'
$provider=Join-Path (Split-Path -Parent $root) 'OPENCV_OLS4\Invoke-OCV00DeepestAliasInventory.ps1'
$fixtureRoot='C:\O3B2T'
$gatePath=Join-Path $root 'O3B2_ENTRYPOINT_REHEARSAL_GATE.json'
$hashes=[ordered]@{entry='D5FA66B9B47D2BBBCD30534CA5CBEA204372ADE5B318A9BD557B2A932C51E469';worker='70010A341A50369049AAE1FFCFB92CCF74555231582BE11793648758C054A7C1';config='DA034E3B1C060E09412A643E387DDBF2FFC695C4757EFC9CD2EC50E7B9FFA0E1';priorWorker='750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08';priorConfig='55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F';provider='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'}
function Sha([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
foreach($pair in @(@($entry,$hashes.entry),@($worker,$hashes.worker),@($config,$hashes.config),@($priorWorker,$hashes.priorWorker),@($provider,$hashes.provider))){if((Sha $pair[0])-ne$pair[1]){throw "O3B2 test dependency changed: $($pair[0])"}}
$evidence=Get-Content -LiteralPath $priorConfigEvidence -Raw|ConvertFrom-Json
if([string]$evidence.endpointConfigSha256-ne$hashes.priorConfig){throw 'O3B2 prior config evidence changed.'}
if($Preflight){
    if(Test-Path -LiteralPath $fixtureRoot){throw 'O3B2 fixture root already exists.'}
    if(Test-Path -LiteralPath $gatePath){throw 'O3B2 gate already exists.'}
    [ordered]@{schema='argos_o3b2_entrypoint_test_preflight_v1';state='PASS_O3B2_ENTRYPOINT_TEST_PREFLIGHT';mutationsPerformed=$false}|ConvertTo-Json
    return
}
if(Test-Path -LiteralPath $fixtureRoot){throw 'O3B2 fixture root collision.'};[void](New-Item -ItemType Directory -Path $fixtureRoot)
function New-Case([string]$Name,[bool]$TargetInstalled=$false,[bool]$CorruptWorker=$false){
    $case=Join-Path $fixtureRoot $Name;$portal=Join-Path $case 'portal';$processor=Join-Path $case 'processor'
    [void](New-Item -ItemType Directory -Path (Join-Path $portal 'bin') -Force);[void](New-Item -ItemType Directory -Path (Join-Path $portal 'config') -Force);[void](New-Item -ItemType Directory -Path $processor -Force)
    Copy-Item -LiteralPath $(if($TargetInstalled){$worker}else{$priorWorker}) -Destination (Join-Path $portal 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1')
    if($TargetInstalled){Copy-Item -LiteralPath $config -Destination (Join-Path $portal 'config\endpoint_jbod.json')}else{[IO.File]::WriteAllText((Join-Path $portal 'config\endpoint_jbod.json'),([string]$evidence.endpointConfig|ConvertTo-Json -Depth 20)+[Environment]::NewLine,(New-Object Text.UTF8Encoding($false)))}
    Copy-Item -LiteralPath $provider -Destination (Join-Path $processor 'OCV03_MetadataProviderV1.ps1')
    if($CorruptWorker){[IO.File]::AppendAllText((Join-Path $portal 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'),'X',(New-Object Text.UTF8Encoding($false)))}
    [pscustomobject]@{case=$case;portal=$portal;processor=$processor;worker=Join-Path $portal 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1';config=Join-Path $portal 'config\endpoint_jbod.json';output=Join-Path $processor 'OCV03_O3B2_STATUS_CAPABILITY.json'}
}
function Write-Invocation([object]$Case,[bool]$AfterWorker=$false,[bool]$AfterConfig=$false){
    $path=Join-Path $Case.case 'invocation.json';$value=[ordered]@{schema='argos_o3b2_entrypoint_invocation_v1';portalRoot=$Case.portal;processorRoot=$Case.processor;failAfterWorkerSwap=$AfterWorker;failAfterConfigSwap=$AfterConfig}
    [IO.File]::WriteAllText($path,($value|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)));$path
}
function Invoke-Json([string]$Manifest,[switch]$AsPreflight){$args=@{InvocationManifest=$Manifest};if($AsPreflight){$args.Preflight=$true}else{$args.Rehearsal=$true};$text=& $entry @args|Out-String;$text|ConvertFrom-Json}
$success=New-Case 'success';$successResult=Invoke-Json (Write-Invocation $success)
if([string]$successResult.state-ne'PASS_O3B2_STATUS_METADATA_CAPABILITY_INSTALLED'-or(Sha $success.worker)-ne$hashes.worker-or(Sha $success.config)-ne$hashes.config-or-not(Test-Path $success.output)){throw 'O3B2 success case failed.'}
$afterWorker=New-Case 'fail_worker';$failedWorker=$false;try{[void](Invoke-Json (Write-Invocation $afterWorker $true $false))}catch{$failedWorker=$_.Exception.Message-like'*INJECTED_O3B2_FAILURE_AFTER_WORKER_SWAP*'}
if(-not$failedWorker-or(Sha $afterWorker.worker)-ne$hashes.priorWorker-or(Sha $afterWorker.config)-ne$hashes.priorConfig-or(Test-Path $afterWorker.output)){throw 'O3B2 worker rollback case failed.'}
$afterConfig=New-Case 'fail_config';$failedConfig=$false;try{[void](Invoke-Json (Write-Invocation $afterConfig $false $true))}catch{$failedConfig=$_.Exception.Message-like'*INJECTED_O3B2_FAILURE_AFTER_CONFIG_SWAP*'}
if(-not$failedConfig-or(Sha $afterConfig.worker)-ne$hashes.priorWorker-or(Sha $afterConfig.config)-ne$hashes.priorConfig-or(Test-Path $afterConfig.output)){throw 'O3B2 config rollback case failed.'}
$idempotent=New-Case 'idempotent' $true;$idempotentResult=Invoke-Json (Write-Invocation $idempotent)
if([bool]$idempotentResult.workerChanged-or[bool]$idempotentResult.configChanged-or(Sha $idempotent.worker)-ne$hashes.worker-or(Sha $idempotent.config)-ne$hashes.config){throw 'O3B2 idempotent case failed.'}
$refusal=New-Case 'unapproved' $false $true;$refusalManifest=Write-Invocation $refusal;$refused=$false;try{[void](Invoke-Json $refusalManifest -AsPreflight)}catch{$refused=$_.Exception.Message-like'*worker predecessor refused*'}
if(-not$refused-or(Test-Path $refusal.output)){throw 'O3B2 refusal-before-mutation case failed.'}
$gateRecord=[ordered]@{schema='argos_o3b2_entrypoint_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3B2_ENTRYPOINT_REHEARSAL';entrypointSha256=$hashes.entry;workerSha256=$hashes.worker;configSha256=$hashes.config;cases=@('SUCCESS','ROLLBACK_AFTER_WORKER','ROLLBACK_AFTER_CONFIG','IDEMPOTENT_TARGET','UNAPPROVED_REFUSAL');taskActions=@();processActions=@();imageBytesRead=$false;sourceHashingPerformed=$false;mutationsPerformed='LOCAL_FIXTURE_ONLY';reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($gatePath,($gateRecord|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)));$gateRecord|ConvertTo-Json -Depth 8
