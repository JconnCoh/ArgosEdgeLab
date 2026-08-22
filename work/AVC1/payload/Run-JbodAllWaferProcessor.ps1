[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string] $ConfigPath,
    [switch] $Once,
    [switch] $PlanOnly
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Read-SafeProcessorConfig {
    param([Parameter(Mandatory=$true)][string]$Path)
    $value=Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json
    $productionRoutingEnabled=($value.PSObject.Properties.Name-contains'productionRoutingEnabled')-and[bool]$value.productionRoutingEnabled
    if([string]$value.schema-notin@('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3') -or
       -not[bool]$value.reviewOnly -or [bool]$value.xmlExportEnabled -or
       $productionRoutingEnabled){throw 'Processor runner safety contract refused.'}
    return $value
}

$config=Read-SafeProcessorConfig -Path $ConfigPath
$inventory=Join-Path $PSScriptRoot 'Invoke-JbodAllWaferInventory.ps1'
$processor=Join-Path $PSScriptRoot 'Invoke-JbodAllWaferProcessingPass.ps1'
$scribeQueue=Join-Path $PSScriptRoot 'Update-JbodScribeIdentityQueue.ps1'
$createdNew=$false
$mutex=New-Object Threading.Mutex($true,'Global\ArgosEdgeLabAllWaferProcessorReviewOnlyV2',[ref]$createdNew)
if(-not$createdNew){exit 0}
try{
    do{
        $orderedConsumer='CONFIG_RELOAD'
        try{
            $config=Read-SafeProcessorConfig -Path $ConfigPath
            $cooperativeHold=($config.PSObject.Properties.Name-contains'processorCooperativeHold')-and[bool]$config.processorCooperativeHold
            if($cooperativeHold){
                # The processing pass owns the acknowledgement contract.  It
                # must run before inventory/scribe consumers while held so an
                # idle safe boundary cannot be masked by a downstream error.
                $orderedConsumer='COOPERATIVE_HOLD_PROCESSING_BOUNDARY'
                & $processor -ConfigPath $ConfigPath -MaximumJobs $(if($PlanOnly){20}else{[int]$config.maximumJobsPerCatalogPass}) -PlanOnly:$PlanOnly
            }else{
                $orderedConsumer='INVENTORY'
                & $inventory -RawSearchRoot ([string]$config.rawSearchRoot) -StateRoot ([string]$config.stateRoot) `
                    -RelayQueueRoot ([string]$config.relayQueueRoot) -StableAgeSeconds ([int]$config.stableAgeSeconds) `
                    -StablePasses ([int]$config.stablePasses) -QueueRelaySummary:([bool]$config.queueRelaySummary)|Out-Null
                $orderedConsumer='SCRIBE_IDENTITY_QUEUE'
                & $scribeQueue -ConfigPath $ConfigPath|Out-Null
                $orderedConsumer='PROCESSING_PASS'
                & $processor -ConfigPath $ConfigPath -MaximumJobs $(if($PlanOnly){20}else{[int]$config.maximumJobsPerCatalogPass}) -PlanOnly:$PlanOnly
            }
        } catch {
            $failurePath=Join-Path ([string]$config.stateRoot) 'processor\PROCESSOR_LOOP_FAILURE.txt'
            ("Ordered consumer: $orderedConsumer"+[Environment]::NewLine+($_|Out-String))|Set-Content -LiteralPath $failurePath -Encoding UTF8
            if($Once){throw}
        }
        if(-not$Once){Start-Sleep -Seconds ([int]$config.pollSeconds)}
    }while(-not$Once)
} finally {
    $mutex.ReleaseMutex();$mutex.Dispose()
}
