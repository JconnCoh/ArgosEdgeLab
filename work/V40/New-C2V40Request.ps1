[CmdletBinding()]
param([switch]$Preflight,[switch]$Apply)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Apply)) { throw 'Specify exactly one of -Preflight or -Apply.' }
$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot=Join-Path $project 'work\V40'
$requestId='REQ_V40_0821_1615_X1'
$sourceRoot=$workRoot
$definitionPath=Join-Path $sourceRoot 'pkg\MAINTENANCE_DEFINITION.json'
$payloadRoot=Join-Path $sourceRoot 'pkg\payload'
$outputRoot=Join-Path $workRoot 'signed_short'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
if ($requestId -notmatch '^REQ_[A-Z0-9_]{1,19}$' -or $requestId.Length -gt 23) { throw 'Short C2V request identity contract refused.' }
foreach ($path in @($definitionPath,$payloadRoot,$identityPath,$pathTool)) { if (-not (Test-Path -LiteralPath $path)) { throw "C2V signing input missing: $path" } }
$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH' -or @($definition.changes).Count -ne 1 -or @($definition.allowedTaskActions).Count -ne 0) { throw 'C2V maintenance definition contract refused.' }
$payloadFiles=@(Get-ChildItem -LiteralPath $payloadRoot -File|Sort-Object Name|ForEach-Object{[pscustomobject]@{source=$_.FullName;path=('payload/'+$_.Name);bytes=[int64]$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}})
if ($payloadFiles.Count -ne 2 -or @($payloadFiles.path) -notcontains 'payload/C2V.ps1' -or @($payloadFiles.path) -notcontains 'payload/PROCESSOR_CONFIG.json') { throw 'C2V payload set changed.' }
$payloadScript=@($payloadFiles|Where-Object{[string]$_.path-eq'payload/C2V.ps1'})[0];$payloadConfig=@($payloadFiles|Where-Object{[string]$_.path-eq'payload/PROCESSOR_CONFIG.json'})[0];$change=@($definition.changes)[0]
if([string]$definition.entryPoint-ne'payload/C2V.ps1'-or[string]$change.source-ne'payload/PROCESSOR_CONFIG.json'-or[string]$change.installedSha256-ne[string]$payloadConfig.sha256-or@($change.approvedPredecessorSha256).Count-ne1-or[string]@($change.approvedPredecessorSha256)[0]-ne[string]$payloadConfig.sha256){throw 'C2V predecessor/target contract changed.'}
$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json;$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant();$certificate=Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if(-not$certificate.HasPrivateKey){throw 'Portal signer private key is unavailable.'}
$ready=Join-Path $outputRoot ($requestId+'.ready');$partial=Join-Path $outputRoot ($requestId+'.partial');foreach($path in @($ready,$partial)){if(Test-Path -LiteralPath $path){throw "Refusing existing C2V request path: $path"}}
$planned=@((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'))+@($payloadFiles|ForEach-Object{Join-Path $partial ([string]$_.path).Replace('/','\')})+@($payloadFiles|ForEach-Object{Join-Path $ready ([string]$_.path).Replace('/','\')})
$pathGate=&$pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json;if([string]$pathGate.state-ne'PASS_PATH_BUDGET'){throw 'C2V signing path gate failed.'}
if($Preflight){[ordered]@{schema='argos_jbod_lot_validate_c2v_signing_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_C2V_SIGNING_PREFLIGHT';requestId=$requestId;payloadScriptSha256=[string]$payloadScript.sha256;configSha256=[string]$payloadConfig.sha256;payloadFileCount=$payloadFiles.Count;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return}
$created=[DateTimeOffset]::UtcNow;$manifest=[ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($payloadFiles|ForEach-Object{[ordered]@{path=$_.path;bytes=$_.bytes;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);allowedTaskActions=@($definition.allowedTaskActions);rehearsal=$definition.rehearsal}
[void](New-Item -ItemType Directory -Path (Join-Path $partial 'payload') -Force);foreach($row in $payloadFiles){Copy-Item -LiteralPath $row.source -Destination (Join-Path $partial ([string]$row.path).Replace('/','\'))}
$bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($manifest|ConvertTo-Json -Depth 32));[IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.json'),$bytes);$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_REQUEST_MANIFEST.sig'),$signature);Move-Item -LiteralPath $partial -Destination $ready
[ordered]@{schema='argos_jbod_lot_validate_c2v_signing_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_C2V_SIGNED_REQUEST';requestId=$requestId;packagePath=$ready;manifestSha256=(Get-FileHash -LiteralPath (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json') -Algorithm SHA256).Hash;signatureSha256=(Get-FileHash -LiteralPath (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig') -Algorithm SHA256).Hash;payloadScriptSha256=[string]$payloadScript.sha256;configSha256=[string]$payloadConfig.sha256;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
