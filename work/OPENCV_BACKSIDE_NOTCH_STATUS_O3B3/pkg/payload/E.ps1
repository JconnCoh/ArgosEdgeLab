[CmdletBinding()]
param([switch]$Preflight,[switch]$Rehearsal,[string]$InvocationManifest)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if($Preflight-and$Rehearsal){throw 'O3B3 cannot combine Preflight and Rehearsal.'}
$priorWorkerSha='750022568C62C2C049D04CE0D49E2FD52B5030A9701D8E453152129EB48D6F08'
$targetWorkerSha='047BB0D79999F1FF2A9FF9373C9B34C9A7BDE82AAFE0605E1929A10ACBEBF988'
$providerSha='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
$portalRoot='C:\ProgramData\ArgosProjectPortalRO';$processorRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2';$failAfterSwap=$false
if($Preflight-or$Rehearsal){
    if([string]::IsNullOrWhiteSpace($InvocationManifest)){throw 'O3B3 Preflight/Rehearsal requires InvocationManifest.'}
    $invocation=Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw|ConvertFrom-Json
    if([string]$invocation.schema-ne'argos_o3b3_entrypoint_invocation_v1'){throw 'O3B3 invocation schema mismatch.'}
    $portalRoot=[IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\');$processorRoot=[IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\');$failAfterSwap=[bool]$invocation.failAfterSwap
}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Short([string]$Path){$full=[IO.Path]::GetFullPath($Path);$longest=[int](($full.Split('\')|Where-Object{$_}|Measure-Object Length -Maximum).Maximum);if(($full.Length+32)-ge200-or$longest-gt80){throw "O3B3 path budget failed: $full"};$full}
$workerPath=Short (Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1')
$providerPath=Short (Join-Path $processorRoot 'OCV03_MetadataProviderV1.ps1')
$payloadWorker=Short (Join-Path $PSScriptRoot 'W.ps1')
$outputPath=Short (Join-Path $processorRoot 'OCV03_O3B3_STATUS_CAPABILITY.json')
foreach($path in @($workerPath,$providerPath,$payloadWorker)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "O3B3 prerequisite missing: $path"}}
if((Sha $payloadWorker)-ne$targetWorkerSha){throw 'O3B3 payload worker hash mismatch.'};if((Sha $providerPath)-ne$providerSha){throw 'O3B3 installed provider hash mismatch.'}
$installedWorkerSha=Sha $workerPath;if($installedWorkerSha-notin@($priorWorkerSha,$targetWorkerSha)){throw "O3B3 worker predecessor refused: $installedWorkerSha"};if(Test-Path -LiteralPath $outputPath){throw "O3B3 refuses existing output: $outputPath"}
if($Preflight){[ordered]@{schema='argos_o3b3_entrypoint_preflight_v1';state='PASS_O3B3_ENTRYPOINT_PREFLIGHT';installedWorkerSha256=$installedWorkerSha;targetWorkerSha256=$targetWorkerSha;providerSha256=$providerSha;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json;return}
$evidenceRoot=Short (Join-Path $portalRoot ('state\maintenance_bootstrap\O3B3_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')));$stage=Short (Join-Path (Split-Path -Parent $workerPath) 'O3B3.stage.ps1');$backup=Short (Join-Path $evidenceRoot 'worker.bak')
foreach($path in @($evidenceRoot,$stage)){if(Test-Path -LiteralPath $path){throw "O3B3 fresh path collision: $path"}};$swapped=$false;[void](New-Item -ItemType Directory -Path $evidenceRoot)
try{
    if($installedWorkerSha-eq$priorWorkerSha){Copy-Item -LiteralPath $payloadWorker -Destination $stage;[IO.File]::Replace($stage,$workerPath,$backup,$true);$swapped=$true;if((Sha $workerPath)-ne$targetWorkerSha-or(Sha $backup)-ne$priorWorkerSha){throw 'O3B3 atomic swap failed.'}}
    if($failAfterSwap){throw 'INJECTED_O3B3_FAILURE_AFTER_SWAP'}
    $record=[ordered]@{schema='argos_o3b3_status_capability_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3B3_STATUS_METADATA_CAPABILITY_INSTALLED';rehearsal=[bool]$Rehearsal;workerSha256=(Sha $workerPath);providerSha256=(Sha $providerPath);workerChanged=$swapped;taskActions=@();processActions=@();imageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    [IO.File]::WriteAllText($outputPath,(($record|ConvertTo-Json -Depth 6)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)));$record|ConvertTo-Json -Depth 6
}catch{
    $failure=$_;if(Test-Path -LiteralPath $outputPath){Move-Item -LiteralPath $outputPath -Destination (Join-Path $evidenceRoot 'failed_output.json') -ErrorAction SilentlyContinue};if($swapped){[IO.File]::Replace($backup,$workerPath,(Join-Path $evidenceRoot 'failed_worker.ps1'),$true)};if((Sha $workerPath)-ne$installedWorkerSha){throw 'O3B3 rollback failed.'};throw $failure
}finally{if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue}}
