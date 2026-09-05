[CmdletBinding()]
param(
    [string]$BridgeRoot='C:\ProgramData\ArgosInsiteBridgeRO',
    [ValidateRange(5,300)][int]$PollSeconds=10,
    [switch]$Once,
    [switch]$Preflight
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Security

function Write-AtomicJson([string]$Path,[object]$Value,[int]$Depth=10){
    $temp=$Path+'.partial.'+[Guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
    if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temp,$Path,$null,$true)}else{[IO.File]::Move($temp,$Path)}
}
function Write-Log([string]$Message){
    $path=Join-Path $BridgeRoot 'state\argos-worker.log'
    if((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length-gt1048576){Move-Item -LiteralPath $path -Destination ($path+'.previous') -Force}
    Add-Content -LiteralPath $path -Value ((Get-Date).ToString('s')+' '+$Message) -Encoding UTF8
}
function Get-StoredCredential{
    $record=Get-Content -LiteralPath (Join-Path $BridgeRoot 'secrets\insite.credential.dpapi.json') -Raw|ConvertFrom-Json
    if([string]$record.schema-ne'argos_insite_dpapi_machine_credential_v1'){throw 'Stored Insite credential schema refused.'}
    $entropy=[Convert]::FromBase64String([string]$record.entropy)
    $protected=[Convert]::FromBase64String([string]$record.protectedPassword)
    $plain=[Security.Cryptography.ProtectedData]::Unprotect($protected,$entropy,[Security.Cryptography.DataProtectionScope]::LocalMachine)
    try{
        $password=[Text.Encoding]::UTF8.GetString($plain)
        $secure=ConvertTo-SecureString $password -AsPlainText -Force
        return [Management.Automation.PSCredential]::new([string]$record.userName,$secure)
    }finally{
        if($plain){[Array]::Clear($plain,0,$plain.Length)}
        if($protected){[Array]::Clear($protected,0,$protected.Length)}
        if($entropy){[Array]::Clear($entropy,0,$entropy.Length)}
        $password=$null
    }
}
function Assert-RelayPackage([string]$Path){
    & (Join-Path $BridgeRoot 'bin\ArgosBoundRelay.InsiteBridge.ReviewOnly.V2_1.exe') --package-check $Path|Out-Null
    if($LASTEXITCODE-ne0){throw "Relay package validation failed: $Path"}
}
function Process-Requests{
    $pending=Join-Path $BridgeRoot 'request_inbox\pending'
    $processed=Join-Path $BridgeRoot 'request_inbox\processed'
    $responsePending=Join-Path $BridgeRoot 'response_queue\pending'
    $responseSent=Join-Path $BridgeRoot 'response_queue\sent'
    foreach($package in @(Get-ChildItem -LiteralPath $pending -Directory -Filter 'INSITE_REQ__*.ready' -ErrorAction SilentlyContinue|Sort-Object Name)){
        Assert-RelayPackage $package.FullName
        $manifest=Get-Content -LiteralPath (Join-Path $package.FullName 'INSITE_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
        $hash=([string]$manifest.requestContentSha256).ToUpperInvariant()
        if($hash-notmatch'^[A-F0-9]{64}$'){throw "Invalid request content hash: $($package.Name)"}
        $requestPath=Join-Path $package.FullName 'PENDING_INSITE_REQUEST.json'
        $request=Get-Content -LiteralPath $requestPath -Raw|ConvertFrom-Json
        if((Get-ArgosInsiteRequestCanonicalHashV2 -Request $request)-cne$hash){throw "Request canonical hash mismatch: $($package.Name)"}
        $responseId='INSITE_RESP__'+$hash.Substring(0,32)
        $ready=Join-Path $responsePending ($responseId+'.ready')
        $sent=Join-Path $responseSent ($responseId+'.ready')
        if(-not(Test-Path -LiteralPath $ready) -and -not(Test-Path -LiteralPath $sent)){
            $credential=Get-StoredCredential
            $partial=Join-Path $responsePending ($responseId+'.partial.'+[Guid]::NewGuid().ToString('N'))
            [void](New-Item -ItemType Directory -Path $partial)
            $payload=Join-Path $partial 'INSITE_RESPONSE.json'
            try{
                if([string]$request.lookupKey-eq'current-image-supported canonical M12 candidate scribe'){
                    & (Join-Path $BridgeRoot 'query\Invoke-ArgosCandidateInsiteRequest.ps1') -RequestPath $requestPath -SqlCredential $credential -OutputPath $payload -ExpectedRequestContentSha256 $hash|Out-Null
                }elseif([string]$request.lookupKey-eq'confirmed 12-character wafer scribe'){
                    & (Join-Path $BridgeRoot 'query\Invoke-ArgosPendingInsiteRequest.ps1') -RequestPath $requestPath -SqlCredential $credential -OutputPath $payload|Out-Null
                }else{throw "Request lookup key refused: $($request.lookupKey)"}
                $snapshot=Get-Content -LiteralPath $payload -Raw|ConvertFrom-Json
                if([string]$snapshot.authority-ne'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT'){throw 'Generated Insite snapshot authority refused.'}
                $responseManifest=[ordered]@{
                    schema='argos_insite_response_relay_manifest_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
                    requestPackageId=($package.Name -replace '\.ready$','');requestContentSha256=$hash;payloadFile='INSITE_RESPONSE.json'
                    bytes=(Get-Item -LiteralPath $payload).Length;sha256=(Get-FileHash -LiteralPath $payload -Algorithm SHA256).Hash
                    recordCount=@($snapshot.records).Count;imagesIncluded=$false;credentialsIncluded=$false
                    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
                }
                [IO.File]::WriteAllText((Join-Path $partial 'INSITE_RESPONSE_MANIFEST.json'),(($responseManifest|ConvertTo-Json -Depth 10)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
                Move-Item -LiteralPath $partial -Destination $ready
                Assert-RelayPackage $ready
                Write-Log ('QUERIED '+$package.Name+' records='+@($snapshot.records).Count)
            }catch{
                if(Test-Path -LiteralPath $partial){Remove-Item -LiteralPath $partial -Recurse -Force}
                throw
            }finally{$credential=$null}
        }
        $destination=Join-Path $processed $package.Name
        if(-not(Test-Path -LiteralPath $destination)){Move-Item -LiteralPath $package.FullName -Destination $destination}
    }
}

$canonicalModulePath=Join-Path $BridgeRoot 'query\ArgosInsiteRequestCanonical.psm1'
$workerDependencies=@($canonicalModulePath,(Join-Path $BridgeRoot 'query\Invoke-ArgosCandidateInsiteRequest.ps1'),(Join-Path $BridgeRoot 'query\Invoke-ArgosPendingInsiteRequest.ps1'),(Join-Path $BridgeRoot 'bin\ArgosBoundRelay.InsiteBridge.ReviewOnly.V2_1.exe'),(Join-Path $BridgeRoot 'secrets\insite.credential.dpapi.json'))
foreach($dependency in $workerDependencies){if(-not(Test-Path -LiteralPath $dependency -PathType Leaf)){throw "Argos Insite bridge dependency is missing: $dependency"}}
Import-Module -Name $canonicalModulePath -ErrorAction Stop
if($Preflight){[pscustomobject]@{State='PASS_ARGOS_AUTOMATIC_INSITE_BRIDGE_CANDIDATE_PREFLIGHT';MutationPerformed=$false};return}
foreach($relative in @('state','request_inbox\pending','request_inbox\processed','response_queue\pending','response_queue\sent')){
    $path=Join-Path $BridgeRoot $relative
    if(-not(Test-Path -LiteralPath $path)){[void](New-Item -ItemType Directory -Path $path -Force)}
}
do{
    try{Process-Requests}catch{Write-Log ('ERROR '+$_.Exception.Message)}
    if(-not$Once){Start-Sleep -Seconds $PollSeconds}
}while(-not$Once)
