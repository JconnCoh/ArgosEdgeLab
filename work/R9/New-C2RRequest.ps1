[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Apply)){throw 'Specify exactly one of -Preflight or -Apply.'}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$requestId='REQ_R9'
$definitionPath=Join-Path $project 'work\R9\pkg\MAINTENANCE_DEFINITION.json'
$payloadRoot=Join-Path $project 'work\R9\pkg\payload'
$outputRoot=Join-Path $project 'work\R9\signed_short'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
if($requestId-notmatch'^REQ_[A-Z0-9_]{1,19}$'-or$requestId.Length-gt23){throw 'Short request identity contract refused.'}
$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
if([string]$definition.targetRole-ne'JBOD'-or[string]$definition.jobClass-ne'MAINTENANCE_PATCH'){throw 'C2R maintenance definition contract refused.'}
$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$certificate=Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if(-not$certificate.HasPrivateKey){throw 'Portal signer private key is unavailable.'}

$payloadFiles=@(Get-ChildItem -LiteralPath $payloadRoot -Recurse -File|Sort-Object FullName|ForEach-Object{
    $relative=$_.FullName.Substring($payloadRoot.TrimEnd('\').Length).TrimStart('\').Replace('\','/')
    [pscustomobject]@{source=$_.FullName;path=('payload/'+$relative);bytes=[int64]$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
})
if($payloadFiles.Count-ne2){throw 'R9 payload file count changed.'}
$payloadNames=@($payloadFiles|ForEach-Object{[string]$_.path})
if($payloadNames-notcontains[string]$definition.entryPoint){throw 'R9 entry point is absent from the payload.'}
foreach($change in @($definition.changes)){
    if($payloadNames-notcontains[string]$change.source){throw "C2R change source is absent: $($change.source)"}
    if(@($change.approvedPredecessorSha256).Count-lt1-or@($change.approvedPredecessorSha256)-notcontains[string]$change.installedSha256){throw 'R9 predecessor set must include its idempotent target hash.'}
    $sourceRow=@($payloadFiles|Where-Object{[string]$_.path-eq[string]$change.source})
    if($sourceRow.Count-ne1-or[string]$sourceRow[0].sha256-ne[string]$change.installedSha256){throw "C2R target hash mismatch: $($change.source)"}
}
if($Preflight){
    [ordered]@{schema='argos_c2i4_signing_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_C2R_SIGNING_PREFLIGHT';requestId=$requestId;requestIdLength=$requestId.Length;payloadFiles=$payloadFiles.Count;changes=@($definition.changes).Count;allowedTaskActions=@($definition.allowedTaskActions).Count;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o')
    targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false
    signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1'
    files=@($payloadFiles|ForEach-Object{[ordered]@{path=$_.path;bytes=$_.bytes;sha256=$_.sha256}})
    entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);allowedTaskActions=@($definition.allowedTaskActions);rehearsal=$definition.rehearsal
}
$ready=Join-Path $outputRoot ($requestId+'.ready')
$partial=Join-Path $outputRoot ($requestId+'.partial')
foreach($path in @($ready,$partial)){if(Test-Path -LiteralPath $path){throw "Refusing existing short request path: $path"}}
[void](New-Item -ItemType Directory -Path $partial -Force)
try{
    foreach($file in $payloadFiles){
        $destination=Join-Path $partial $file.path.Replace('/','\')
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
        Copy-Item -LiteralPath $file.source -Destination $destination
    }
    $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($manifest|ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'),$bytes)
    $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    try{$signature=$rsa.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
    [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'),$signature)
    Move-Item -LiteralPath $partial -Destination $ready
}catch{throw}
[ordered]@{schema='argos_c2i4_signing_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_C2R_SIGNED_REQUEST';requestId=$requestId;packagePath=$ready;payloadFiles=$payloadFiles.Count;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
