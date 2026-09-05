[CmdletBinding()]
param(
    [string]$BridgeRoot='C:\ProgramData\ArgosInsiteBridgeRO',
    [string]$WorkerTaskName='ArgosEdgeLab.InsiteBridge.Worker.ReviewOnly.V1',
    [string]$RehearsalControlPath='',
    [switch]$Preflight,
    [switch]$Rehearsal
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

if(-not$Rehearsal-and-not[string]::IsNullOrWhiteSpace($RehearsalControlPath)){throw 'SNA1 rehearsal control is allowed only with -Rehearsal.'}

function Get-Optional([object]$Object,[string]$Name,$Default){
    $property=$Object.PSObject.Properties[$Name]
    if($null-eq$property){return $Default}
    return $property.Value
}
function Get-Sha([string]$Path){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
function Get-TextSha([string]$Text){
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')}finally{$sha.Dispose()}
}
function Assert-Parse([string]$Path){
    $tokens=$null
    $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count-ne0){throw "SNA1 PowerShell parse failure: $Path $($errors.Message -join ' | ')"}
}
function Write-AtomicJson([string]$Path,[object]$Value,[int]$Depth=16){
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    $temp=Join-Path $parent ('sna1.'+[Guid]::NewGuid().ToString('N')+'.tmp')
    [IO.File]::WriteAllText($temp,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    if(Test-Path -LiteralPath $Path){
        $backup=Join-Path $parent ('sna1.'+[Guid]::NewGuid().ToString('N')+'.bak')
        [IO.File]::Replace($temp,$Path,$backup,$true)
        if(Test-Path -LiteralPath $backup){Remove-Item -LiteralPath $backup -Force}
    }else{[IO.File]::Move($temp,$Path)}
}
function Get-TaskSnapshot([string]$TaskName){
    $task=Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    $principal=[string]$task.Principal.UserId
    if([string]::IsNullOrWhiteSpace($principal)){throw "SNA1 task principal is empty: $TaskName"}
    $actions=@($task.Actions)
    if($actions.Count-eq0-or-not(@($actions|Where-Object{[string]$_.Arguments-match'Invoke-ArgosAutomaticInsiteBridgeWorker\.ps1'}))){throw "SNA1 task action refused: $TaskName"}
    $xml=Export-ScheduledTask -TaskName $TaskName -TaskPath $task.TaskPath
    return [pscustomobject]@{
        taskName=$TaskName;taskPath=[string]$task.TaskPath;principal=$principal
        definitionSha256=Get-TextSha $xml;state=[string]$task.State
    }
}

$root=[IO.Path]::GetFullPath($BridgeRoot).TrimEnd('\')
$live=-not$Rehearsal
if($live){
    if($root-ne'C:\ProgramData\ArgosInsiteBridgeRO'){throw "Live SNA1 bridge root refused: $root"}
    if($WorkerTaskName-ne'ArgosEdgeLab.InsiteBridge.Worker.ReviewOnly.V1'){throw "Live SNA1 worker task refused: $WorkerTaskName"}
}
$query=Join-Path $root 'query'
$pendingPath=Join-Path $query 'Invoke-ArgosPendingInsiteRequest.ps1'
$visualPath=Join-Path $query 'Invoke-ArgosMesVisualStateSnapshot.ps1'
$relayPath=Join-Path $root 'bin\ArgosBoundRelay.InsiteBridge.ReviewOnly.V2_1.exe'
$secretPath=Join-Path $root 'secrets\insite.credential.dpapi.json'
foreach($invariantPath in @($pendingPath,$visualPath,$relayPath,$secretPath)){
    if(-not(Test-Path -LiteralPath $invariantPath -PathType Leaf)){throw "SNA1 installed invariant missing: $invariantPath"}
}
if((Get-Sha $pendingPath)-ne'F25A7C828041A8D84FECE1DBFE0A7BD5E6D709521881F85CD8ADF1F2AB75472C'){throw 'SNA1 confirmed-scribe query path changed.'}
if((Get-Sha $visualPath)-ne'D15DA5FEE86B528F12B61B5DD0B4A510593D1A7AA5B60D6491DD951AEF4053CB'){throw 'SNA3 MES visual-state query changed.'}
$secret=Get-Content -LiteralPath $secretPath -Raw|ConvertFrom-Json
if([string]$secret.schema-ne'argos_insite_dpapi_machine_credential_v1'-or[string]::IsNullOrWhiteSpace([string]$secret.userName)-or[string]$secret.scope-ne'LocalMachine'){
    throw 'SNA1 credential envelope metadata refused.'
}
[void][Convert]::FromBase64String([string]$secret.entropy)
[void][Convert]::FromBase64String([string]$secret.protectedPassword)
$invariantBefore=[ordered]@{pending=Get-Sha $pendingPath;visual=Get-Sha $visualPath;relay=Get-Sha $relayPath;secret=Get-Sha $secretPath}

$specs=@(
    [pscustomobject]@{key='worker';source=Join-Path $PSScriptRoot 'Invoke-ArgosAutomaticInsiteBridgeWorker.ps1';destination=Join-Path $query 'Invoke-ArgosAutomaticInsiteBridgeWorker.ps1';target='38CEF173CD4D4F9C8357C3F1879D27C16BC31B26AD3E3CE369473A3D5C608402';allowed=@('D84EAF81973233FC0696E27677C385D30D0A197AB7DA0FAB8D487A944F2F1C23','38CEF173CD4D4F9C8357C3F1879D27C16BC31B26AD3E3CE369473A3D5C608402');allowAbsent=$false}
    [pscustomobject]@{key='candidate';source=Join-Path $PSScriptRoot 'Invoke-ArgosCandidateInsiteRequest.ps1';destination=Join-Path $query 'Invoke-ArgosCandidateInsiteRequest.ps1';target='826ED301EF8197E17BD2AA4DD3389B4FC2B4EFDB2B7B4236DBC0B33BC732300F';allowed=@('826ED301EF8197E17BD2AA4DD3389B4FC2B4EFDB2B7B4236DBC0B33BC732300F');allowAbsent=$true}
    [pscustomobject]@{key='contract';source=Join-Path $PSScriptRoot 'ArgosScribeCandidateInsiteContract.psm1';destination=Join-Path $query 'ArgosScribeCandidateInsiteContract.psm1';target='AFAB222E8C59CD2681D3525739BBD88EE76D3C7323EE6CAB6BA2AB0261BC83D7';allowed=@('AFAB222E8C59CD2681D3525739BBD88EE76D3C7323EE6CAB6BA2AB0261BC83D7');allowAbsent=$true}
    [pscustomobject]@{key='canonical';source=Join-Path $PSScriptRoot 'ArgosInsiteRequestCanonical.psm1';destination=Join-Path $query 'ArgosInsiteRequestCanonical.psm1';target='E1DF58C58A14B9BC0D98729CC839AE59D9380FE74A3E1E3301778C6172B455B2';allowed=@('E1DF58C58A14B9BC0D98729CC839AE59D9380FE74A3E1E3301778C6172B455B2');allowAbsent=$true}
    [pscustomobject]@{key='envelope';source=Join-Path $PSScriptRoot 'ArgosCandidateSnapshotEnvelope.psm1';destination=Join-Path $query 'ArgosCandidateSnapshotEnvelope.psm1';target='03F518AE42CB3F2E09BB1806C9E76C647D644CA2E17550748F788FCCAEB5EAD4';allowed=@('03F518AE42CB3F2E09BB1806C9E76C647D644CA2E17550748F788FCCAEB5EAD4');allowAbsent=$true}
    [pscustomobject]@{key='mesres';source=Join-Path $PSScriptRoot 'ArgosScribeCandidateMesResolver.psm1';destination=Join-Path $query 'ArgosScribeCandidateMesResolver.psm1';target='18D550F47103C3735536B1CA60600A4F0341E0F0E957F75C2D904CEC824AB541';allowed=@('18D550F47103C3735536B1CA60600A4F0341E0F0E957F75C2D904CEC824AB541');allowAbsent=$true}
)

$injectAfterKey=''
if(-not[string]::IsNullOrWhiteSpace($RehearsalControlPath)){
    $resolvedControl=[IO.Path]::GetFullPath($RehearsalControlPath)
    if(-not(Test-Path -LiteralPath $resolvedControl -PathType Leaf)){throw "SNA1 rehearsal control missing: $resolvedControl"}
    $control=Get-Content -LiteralPath $resolvedControl -Raw|ConvertFrom-Json
    if([string]$control.schema-ne'argos_sna1_rehearsal_control_v1'){throw 'SNA1 rehearsal control schema changed.'}
    $injectAfterKey=[string](Get-Optional $control 'injectFailureAfterKey' '')
    if(-not[string]::IsNullOrWhiteSpace($injectAfterKey)-and@($specs.key)-notcontains$injectAfterKey){throw "SNA1 injection key refused: $injectAfterKey"}
}

$preflightRows=New-Object Collections.Generic.List[object]
foreach($spec in $specs){
    if(-not(Test-Path -LiteralPath $spec.source -PathType Leaf)){throw "SNA1 payload missing: $($spec.source)"}
    $sourceHash=Get-Sha $spec.source
    if($sourceHash-ne$spec.target){throw "SNA1 payload hash mismatch: $($spec.key)"}
    Assert-Parse $spec.source
    $priorExists=Test-Path -LiteralPath $spec.destination -PathType Leaf
    if(-not$priorExists-and-not[bool]$spec.allowAbsent){throw "SNA1 predecessor missing: $($spec.destination)"}
    $priorHash=if($priorExists){Get-Sha $spec.destination}else{''}
    if($priorExists-and$spec.allowed-notcontains$priorHash){throw "SNA1 predecessor refused: $($spec.key) actual=$priorHash"}
    $preflightRows.Add([pscustomobject]@{key=$spec.key;priorState=if($priorExists){'PRESENT'}else{'ABSENT'};priorSha256=$priorHash;targetSha256=$spec.target})
}

$taskBefore=$null
if($live){$taskBefore=Get-TaskSnapshot $WorkerTaskName}
if($Preflight){
    [ordered]@{
        schema='argos_sna1_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_SNA3_ARGOS_PREFLIGHT';bridgeRoot=$root;queryRoot=$query;files=$preflightRows.Count
        task=if($null-eq$taskBefore){$null}else{[ordered]@{taskName=$taskBefore.taskName;taskPath=$taskBefore.taskPath;principal=$taskBefore.principal;definitionSha256=$taskBefore.definitionSha256;state=$taskBefore.state}}
        invariantSha256=$invariantBefore;priorFiles=$preflightRows.ToArray();credentialsChanged=$false
        writesPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }|ConvertTo-Json -Depth 12
    return
}

if($live-and[string]$taskBefore.state-eq'Running'){
    Stop-ScheduledTask -TaskName $WorkerTaskName
    $deadline=(Get-Date).AddSeconds(30)
    do{Start-Sleep -Milliseconds 250;$task=Get-ScheduledTask -TaskName $WorkerTaskName}while([string]$task.State-eq'Running'-and(Get-Date)-lt$deadline)
    if([string]$task.State-eq'Running'){throw "SNA1 task did not stop: $WorkerTaskName"}
}

$stamp=[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
$auditRoot=Join-Path $root ('hotfixes\SNA3_'+$stamp)
$priorRoot=Join-Path $auditRoot 'prior'
$failedRoot=Join-Path $auditRoot 'failed'
[void](New-Item -ItemType Directory -Path $priorRoot,$failedRoot -Force)
$changed=New-Object Collections.Generic.List[object]
try{
    foreach($spec in $specs){
        $destinationParent=Split-Path -Parent $spec.destination
        if(-not(Test-Path -LiteralPath $destinationParent)){[void](New-Item -ItemType Directory -Path $destinationParent -Force)}
        $priorExists=Test-Path -LiteralPath $spec.destination -PathType Leaf
        $prior=Join-Path $priorRoot ($spec.key+'.bin')
        if($priorExists){Copy-Item -LiteralPath $spec.destination -Destination $prior -ErrorAction Stop}
        $stage=Join-Path $destinationParent ('sna1.'+$spec.key+'.'+[Guid]::NewGuid().ToString('N')+'.tmp')
        Copy-Item -LiteralPath $spec.source -Destination $stage -ErrorAction Stop
        if((Get-Sha $stage)-ne$spec.target){throw "SNA1 staged hash mismatch: $($spec.key)"}
        if($priorExists){
            $replaceBackup=Join-Path $destinationParent ('sna1.'+$spec.key+'.bak')
            if(Test-Path -LiteralPath $replaceBackup){Remove-Item -LiteralPath $replaceBackup -Force}
            [IO.File]::Replace($stage,$spec.destination,$replaceBackup,$true)
            if(Test-Path -LiteralPath $replaceBackup){Remove-Item -LiteralPath $replaceBackup -Force}
        }else{[IO.File]::Move($stage,$spec.destination)}
        $changed.Add([pscustomobject]@{spec=$spec;prior=$prior;priorExisted=$priorExists})
        if(-not[string]::IsNullOrWhiteSpace($injectAfterKey)-and$spec.key-eq$injectAfterKey){throw "SNA1 injected rollback rehearsal after key: $injectAfterKey"}
    }
    foreach($spec in $specs){
        if((Get-Sha $spec.destination)-ne$spec.target){throw "SNA1 post-install hash mismatch: $($spec.key)"}
        Assert-Parse $spec.destination
    }
    & (Join-Path $query 'Invoke-ArgosAutomaticInsiteBridgeWorker.ps1') -BridgeRoot $root -Preflight|Out-Null
}catch{
    for($index=$changed.Count-1;$index-ge0;$index--){
        $item=$changed[$index]
        if(Test-Path -LiteralPath $item.spec.destination -PathType Leaf){Copy-Item -LiteralPath $item.spec.destination -Destination (Join-Path $failedRoot ($item.spec.key+'.bin')) -Force -ErrorAction SilentlyContinue}
        if([bool]$item.priorExisted){
            $restore=Join-Path (Split-Path -Parent $item.spec.destination) ('sna1.restore.'+[Guid]::NewGuid().ToString('N')+'.tmp')
            Copy-Item -LiteralPath $item.prior -Destination $restore -ErrorAction SilentlyContinue
            if(Test-Path -LiteralPath $restore){
                if(Test-Path -LiteralPath $item.spec.destination){
                    $failedBackup=Join-Path (Split-Path -Parent $item.spec.destination) ('sna1.failed.'+[Guid]::NewGuid().ToString('N')+'.bak')
                    [IO.File]::Replace($restore,$item.spec.destination,$failedBackup,$true)
                    if(Test-Path -LiteralPath $failedBackup){Remove-Item -LiteralPath $failedBackup -Force}
                }else{[IO.File]::Move($restore,$item.spec.destination)}
            }
        }elseif(Test-Path -LiteralPath $item.spec.destination){Remove-Item -LiteralPath $item.spec.destination -Force}
    }
    throw
}finally{
    if($live){
        $task=Get-ScheduledTask -TaskName $WorkerTaskName -ErrorAction SilentlyContinue
        if($null-ne$task-and[string]$task.State-ne'Running'){Start-ScheduledTask -TaskName $WorkerTaskName}
    }
}

$invariantAfter=[ordered]@{pending=Get-Sha $pendingPath;visual=Get-Sha $visualPath;relay=Get-Sha $relayPath;secret=Get-Sha $secretPath}
foreach($name in $invariantBefore.Keys){if($invariantAfter[$name]-ne$invariantBefore[$name]){throw "SNA1 invariant changed: $name"}}
$taskResult=$null
if($live){
    $taskAfter=Get-TaskSnapshot $WorkerTaskName
    if($taskAfter.principal-ne$taskBefore.principal-or$taskAfter.definitionSha256-ne$taskBefore.definitionSha256){throw 'SNA1 worker task definition or principal changed.'}
    $taskResult=[ordered]@{taskName=$taskBefore.taskName;taskPath=$taskBefore.taskPath;principal=$taskBefore.principal;definitionSha256=$taskBefore.definitionSha256;stateBefore=$taskBefore.state;stateAfter=$taskAfter.state}
}
$result=[ordered]@{
    schema='argos_sna3_candidate_mes_query_patch_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
    state=if($Rehearsal){'PASS_SNA3_ARGOS_REHEARSAL'}else{'PASS_SNA3_ARGOS_CANDIDATE_MES_QUERY_PATCH_REVIEW_ONLY'}
    installedFiles=@($specs|ForEach-Object{[ordered]@{key=$_.key;path=$_.destination;sha256=Get-Sha $_.destination}})
    task=$taskResult;invariantSha256=$invariantAfter;credentialEnvelopeChanged=$false
    confirmedScribeQueryChanged=$false;mesVisualStateQueryChanged=$false;relayChanged=$false
    candidateLookupDispatchEnabled=$true;imagesIncluded=$false;credentialsIncluded=$false
    rawImagesChanged=$false;waferInspectionRun=$false;reviewOnly=$true;trainingEligible=$false
    xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-AtomicJson (Join-Path $auditRoot 'HOTFIX_RESULT.json') $result 16
$result|ConvertTo-Json -Depth 16
