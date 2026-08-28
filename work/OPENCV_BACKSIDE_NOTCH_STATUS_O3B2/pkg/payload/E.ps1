[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($Preflight-and$Rehearsal){throw 'O3B2 cannot combine Preflight and Rehearsal.'}

$priorWorkerSha='750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08'
$targetWorkerSha='70010A341A50369049AAE1FFCFB92CCF74555231582BE11793648758C054A7C1'
$priorConfigSha='55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$targetConfigSha='DA034E3B1C060E09412A643E387DDBF2FFC695C4757EFC9CD2EC50E7B9FFA0E1'
$providerSha='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
$portalRoot='C:\ProgramData\ArgosProjectPortalRO'
$processorRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$failAfterWorkerSwap=$false
$failAfterConfigSwap=$false

if($Preflight-or$Rehearsal){
    if([string]::IsNullOrWhiteSpace($InvocationManifest)){throw 'O3B2 Preflight/Rehearsal requires InvocationManifest.'}
    $invocation=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
    if([string]$invocation.schema-ne'argos_o3b2_entrypoint_invocation_v1'){throw 'O3B2 invocation schema mismatch.'}
    $portalRoot=[IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\')
    $processorRoot=[IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $failAfterWorkerSwap=[bool]$invocation.failAfterWorkerSwap
    $failAfterConfigSwap=[bool]$invocation.failAfterConfigSwap
}

function Get-Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Assert-ShortPath([string]$Path){
    $full=[IO.Path]::GetFullPath($Path)
    $longest=[int](($full.Split('\')|Where-Object{$_}|Measure-Object Length -Maximum).Maximum)
    if(($full.Length+32)-ge200-or$longest-gt80){throw "O3B2 path budget failed: $full"}
    return $full
}
function Assert-TargetConfig([string]$Path){
    $config=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json
    if([string]$config.schema-ne'argos_project_portal_endpoint_config_v1'-or[string]$config.role-ne'JBOD'-or-not[bool]$config.reviewOnly-or[bool]$config.productionRoutingEnabled){throw 'O3B2 endpoint config authority changed.'}
    $cap=$config.metadataInventory
    if($null-eq$cap-or-not[bool]$cap.enabled-or[string]$cap.providerSha256-ne$providerSha-or[string]$cap.approvedDataRoot-ne'JBOD_KLARF_EXPORT'-or[string]$cap.aliasName-ne'F'-or[int]$cap.maximumDepth-ne8-or[int]$cap.maximumEntries-ne20000-or[int]$cap.maximumDirectories-ne2048-or[int]$cap.maximumBmpLeaves-ne2048-or[int]$cap.timeoutSeconds-ne120){throw 'O3B2 metadata inventory configuration changed.'}
    if(@($config.approvedDataRoots|Where-Object{[string]$_.name-eq'JBOD_KLARF_EXPORT'-and[string]$_.path-eq'D:\KLARFExport'}).Count-ne1){throw 'O3B2 approved data root changed.'}
}

$workerPath=Assert-ShortPath (Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1')
$configPath=Assert-ShortPath (Join-Path $portalRoot 'config\endpoint_jbod.json')
$providerPath=Assert-ShortPath (Join-Path $processorRoot 'OCV03_MetadataProviderV1.ps1')
$payloadWorker=Assert-ShortPath (Join-Path $PSScriptRoot 'W.ps1')
$payloadConfig=Assert-ShortPath (Join-Path $PSScriptRoot 'C.json')
$outputPath=Assert-ShortPath (Join-Path $processorRoot 'OCV03_O3B2_STATUS_CAPABILITY.json')
foreach($path in @($workerPath,$configPath,$providerPath,$payloadWorker,$payloadConfig)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "O3B2 prerequisite missing: $path"}}
if((Get-Sha $payloadWorker)-ne$targetWorkerSha-or(Get-Sha $payloadConfig)-ne$targetConfigSha){throw 'O3B2 payload hash mismatch.'}
if((Get-Sha $providerPath)-ne$providerSha){throw 'O3B2 installed provider hash mismatch.'}
Assert-TargetConfig $payloadConfig
$installedWorkerSha=Get-Sha $workerPath
$installedConfigSha=Get-Sha $configPath
if($installedWorkerSha-notin@($priorWorkerSha,$targetWorkerSha)){throw "O3B2 worker predecessor refused: $installedWorkerSha"}
if($installedConfigSha-notin@($priorConfigSha,$targetConfigSha)){throw "O3B2 config predecessor refused: $installedConfigSha"}
if(($installedWorkerSha-eq$targetWorkerSha)-xor($installedConfigSha-eq$targetConfigSha)){throw 'O3B2 refuses a partial predecessor state.'}
if(Test-Path -LiteralPath $outputPath){throw "O3B2 refuses existing output: $outputPath"}

if($Preflight){
    [ordered]@{schema='argos_o3b2_entrypoint_preflight_v1';state='PASS_O3B2_ENTRYPOINT_PREFLIGHT';installedWorkerSha256=$installedWorkerSha;installedConfigSha256=$installedConfigSha;targetWorkerSha256=$targetWorkerSha;targetConfigSha256=$targetConfigSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$evidenceRoot=Assert-ShortPath (Join-Path $portalRoot ('state\maintenance_bootstrap\O3B2_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')))
$workerStage=Assert-ShortPath (Join-Path (Split-Path -Parent $workerPath) 'O3B2W.stage.ps1')
$workerBackup=Assert-ShortPath (Join-Path $evidenceRoot 'worker.bak')
$configStage=Assert-ShortPath (Join-Path (Split-Path -Parent $configPath) 'O3B2C.stage.json')
$configBackup=Assert-ShortPath (Join-Path $evidenceRoot 'config.bak')
foreach($path in @($evidenceRoot,$workerStage,$configStage)){if(Test-Path -LiteralPath $path){throw "O3B2 fresh path collision: $path"}}
$workerSwapped=$false;$configSwapped=$false
[void](New-Item -ItemType Directory -Path $evidenceRoot)
try{
    if($installedWorkerSha-eq$priorWorkerSha){
        Copy-Item -LiteralPath $payloadWorker -Destination $workerStage
        [IO.File]::Replace($workerStage,$workerPath,$workerBackup,$true)
        $workerSwapped=$true
        if((Get-Sha $workerPath)-ne$targetWorkerSha-or(Get-Sha $workerBackup)-ne$priorWorkerSha){throw 'O3B2 worker atomic swap failed.'}
    }
    if($failAfterWorkerSwap){throw 'INJECTED_O3B2_FAILURE_AFTER_WORKER_SWAP'}
    if($installedConfigSha-eq$priorConfigSha){
        Copy-Item -LiteralPath $payloadConfig -Destination $configStage
        [IO.File]::Replace($configStage,$configPath,$configBackup,$true)
        $configSwapped=$true
        if((Get-Sha $configPath)-ne$targetConfigSha-or(Get-Sha $configBackup)-ne$priorConfigSha){throw 'O3B2 config atomic swap failed.'}
    }
    if($failAfterConfigSwap){throw 'INJECTED_O3B2_FAILURE_AFTER_CONFIG_SWAP'}
    Assert-TargetConfig $configPath
    $record=[ordered]@{schema='argos_o3b2_status_capability_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3B2_STATUS_METADATA_CAPABILITY_INSTALLED';rehearsal=[bool]$Rehearsal;workerSha256=(Get-Sha $workerPath);configSha256=(Get-Sha $configPath);providerSha256=(Get-Sha $providerPath);workerChanged=$workerSwapped;configChanged=$configSwapped;taskActions=@();processActions=@();imageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    [IO.File]::WriteAllText($outputPath,(($record|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    $record|ConvertTo-Json -Depth 8
}catch{
    $failure=$_
    if(Test-Path -LiteralPath $outputPath){Move-Item -LiteralPath $outputPath -Destination (Join-Path $evidenceRoot 'failed_output.json') -ErrorAction SilentlyContinue}
    if($configSwapped){[IO.File]::Replace($configBackup,$configPath,(Join-Path $evidenceRoot 'failed_config.json'),$true)}
    if($workerSwapped){[IO.File]::Replace($workerBackup,$workerPath,(Join-Path $evidenceRoot 'failed_worker.ps1'),$true)}
    if((Get-Sha $workerPath)-ne$installedWorkerSha-or(Get-Sha $configPath)-ne$installedConfigSha){throw 'O3B2 rollback failed.'}
    throw $failure
}finally{
    foreach($path in @($workerStage,$configStage)){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue}}
}
