[CmdletBinding()]
param([switch]$Preflight,[switch]$Build)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Build)){throw 'Specify exactly one of -Preflight or -Build.'}
function Get-Sha256([string]$LiteralPath){return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash}
function Write-NewJson([string]$LiteralPath,[object]$Value){if(Test-Path -LiteralPath $LiteralPath){throw "O5OBS1 refuses existing output: $LiteralPath"};[IO.File]::WriteAllText($LiteralPath,(($Value|ConvertTo-Json -Depth 24)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project='C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root=Join-Path $project 'work\OPENCV_OLS5'
$requestId='REQ_O5OBS1'
$definitionPath=Join-Path $root 'O5OBS1_DATA_PULL_DEFINITION.json'
$intentPath=Join-Path $root 'O5OBS1_RECOVERY_INTENT_R4.json'
$signedRoot=Join-Path $root 'signed_o5obs1'
$partialSigned=Join-Path $root 'signed_o5obs1.partial'
$readyRoot=Join-Path $signedRoot ($requestId+'.ready')
$finalRoot=Join-Path $root 'final_o5obs1'
$partialFinal=Join-Path $root 'final_o5obs1.partial'
$zipPath=Join-Path $finalRoot ($requestId+'.ready.zip')
$packageGatePath=Join-Path $root 'O5OBS1_EXACT_PACKAGE_GATE.json'
$routeGatePath=Join-Path $root 'O5OBS1_COMPLETE_ROUTE_GATE.json'
$identityPath=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester=Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$definitionSha='E0216CC90FBDECF3C27483B651104970D57065206DFA4F0CD350D4AC9CA48608'
$intentSha='7888778CA8EAC9C6081092CB723B58106D8E0D11BE0B2AE8E54DEEC457AC6771'
foreach($pin in @(@($definitionPath,$definitionSha),@($intentPath,$intentSha))){if(-not(Test-Path -LiteralPath $pin[0] -PathType Leaf)-or(Get-Sha256 $pin[0])-ne$pin[1]){throw "O5OBS1 pinned input changed: $($pin[0])"}}
$definition=Get-Content -LiteralPath $definitionPath -Raw|ConvertFrom-Json
$relativePaths=@($definition.parameters.relativePaths|ForEach-Object{[string]$_})
if([string]$definition.targetRole-ne'JBOD'-or[string]$definition.jobClass-ne'DATA_PULL'-or[string]$definition.parameters.approvedRoot-ne'JBOD_PROCESSOR_REVIEW'-or$relativePaths.Count-ne1-or$relativePaths[0]-ne'OCV00_OLS5_FRONT_SOURCE_HASHES.json'-or[int]$definition.parameters.maximumFiles-ne1-or[int64]$definition.parameters.maximumBytes-ne1048576-or[int64]$definition.maxResultBytes-ne1048576){throw 'O5OBS1 DATA_PULL definition changed.'}
$intent=Get-Content -LiteralPath $intentPath -Raw|ConvertFrom-Json
if([string]$intent.mode-ne'OBSERVE'-or[string]$intent.route.jobClass-ne'DATA_PULL'-or[bool]$intent.route.installedCodeChange-or[bool]$intent.route.imageRead-or[bool]$intent.route.sourceMutation){throw 'O5OBS1 recovery intent changed.'}
foreach($path in @($signedRoot,$partialSigned,$finalRoot,$partialFinal,$packageGatePath,$routeGatePath)){if(Test-Path -LiteralPath $path){throw "O5OBS1 fresh output already exists: $path"}}

$response='R_0123456789AB_20260824205959999_a1b2c3d4.ready'
$routePaths=@(
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),$zipPath,($zipPath+'.path_gate.json'),
    ('U:\ProjectPortalRO\requests\'+$requestId+'.ready.zip.upload'),('U:\ProjectPortalRO\requests\'+$requestId+'.ready.zip'),('C:\APR\S\requests\processed\'+$requestId+'.ready.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\'+$requestId+'.ready\PORTAL_REQUEST_MANIFEST.json'),('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\'+$requestId+'.ready\PORTAL_REQUEST_MANIFEST.json'),('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\'+$requestId+'.ready\PORTAL_REQUEST_MANIFEST.json'),('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\'+$requestId+'.ready\PORTAL_REQUEST_MANIFEST.json'),('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\'+$requestId+'.ready\PORTAL_REQUEST_MANIFEST.json'),
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial',
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\'+$response+'\DATA_PULL_PAYLOAD.zip'),('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\'+$response+'\PORTAL_RESPONSE_MANIFEST.json'),('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\'+$response+'\PORTAL_RESPONSE_MANIFEST.json'),('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\'+$response+'\PORTAL_RESPONSE_MANIFEST.json'),('C:\APR\R\pending\'+$response+'\DATA_PULL_PAYLOAD.zip'),('C:\APR\A\'+$response+'\PORTAL_RESPONSE_MANIFEST.json'),('U:\ProjectPortalRO\responses\'+$response+'.zip'),('C:\A5O\'+$response+'\PORTAL_RESPONSE_MANIFEST.json'),('C:\A5O\'+$response+'\DATA_PULL_PAYLOAD.zip'),('C:\A5O\'+$response+'\data\JBOD_PROCESSOR_REVIEW\OCV00_OLS5_FRONT_SOURCE_HASHES.json')
)
$pathBudget=& $pathTool -CandidatePath $routePaths -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
if([string]$pathBudget.state-ne'PASS_PATH_BUDGET'){throw 'O5OBS1 complete route path budget failed.'}
$maximumEffective=[int](($pathBudget.candidates|Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent=[int](($pathBudget.candidates|Measure-Object longestComponentLength -Maximum).Maximum)
if($Preflight){[ordered]@{schema='argos_o5obs1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O5OBS1_BUILD_PREFLIGHT';requestId=$requestId;relativePath=$relativePaths[0];routePathCount=$routePaths.Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;mutationsPerformed=$false;imageBytesRequested=0;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6;return}

$identity=Get-Content -LiteralPath $identityPath -Raw|ConvertFrom-Json
$thumbprint=([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$certificate=Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
if(-not$certificate.HasPrivateKey){throw 'O5OBS1 signer private key unavailable.'}
$created=[DateTimeOffset]::UtcNow
$manifest=[ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='DATA_PULL';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@();parameters=$definition.parameters}
$partialReady=Join-Path $partialSigned ($requestId+'.ready')
[void](New-Item -ItemType Directory -Path $partialReady)
$utf8=New-Object Text.UTF8Encoding($false)
$manifestBytes=$utf8.GetBytes(($manifest|ConvertTo-Json -Depth 24))
[IO.File]::WriteAllBytes((Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'),$manifestBytes)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try{$signature=$rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
[IO.File]::WriteAllBytes((Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'),$signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath $partialReady -Destination $readyRoot
Remove-Item -LiteralPath $partialSigned -Force
$test=& $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
if([string]$test.State-ne'PASS_SIGNED_PORTAL_PACKAGE'){throw 'O5OBS1 signed package verification failed.'}
Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip=Join-Path $partialFinal ($requestId+'.ready.zip')
$extractRoot=Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extractRoot)
$extractTest=& $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
if([string]$extractTest.State-ne'PASS_SIGNED_PORTAL_PACKAGE'){throw 'O5OBS1 extracted package verification failed.'}
if(@(Get-ChildItem -LiteralPath $extractRoot -File).Count-ne2){throw 'O5OBS1 extracted file count changed.'}
$zipSha=Get-Sha256 $partialZip
$manifestSha=Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha=Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig')
$packageGate=[ordered]@{schema='argos_o5obs1_exact_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O5OBS1_EXACT_SIGNED_DATA_PULL_PACKAGE';requestId=$requestId;requestZip='work/OPENCV_OLS5/final_o5obs1/REQ_O5OBS1.ready.zip';requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$manifestSha;requestSignatureSha256=$signatureSha;definitionSha256=$definitionSha;recoveryIntentSha256=$intentSha;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;payloadFileCount=0;requestedImageFiles=0;reviewOnly=$true;productionRoutingEnabled=$false}
$routeGate=[ordered]@{schema='argos_o5obs1_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O5OBS1_COMPLETE_ROUTE_GATE';requestId=$requestId;jobClass='DATA_PULL';requestZipSha256=$zipSha;requestManifestSha256=$manifestSha;requestSignatureSha256=$signatureSha;routePathCount=$routePaths.Count;maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;reservedSuffixCharacters=32;relativePath=$relativePaths[0];exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;publicationAuthorized=$true;maximumRequestsAuthorized=1;retryOnFailure=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-NewJson (Join-Path $partialFinal ($requestId+'.ready.zip.path_gate.json')) $routeGate
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
Write-NewJson $packageGatePath $packageGate
Write-NewJson $routeGatePath $routeGate
[ordered]@{schema='argos_o5obs1_build_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O5OBS1_EXACT_SIGNED_DATA_PULL_READY';requestId=$requestId;requestZip=$zipPath;requestZipBytes=$packageGate.requestZipBytes;requestZipSha256=$zipSha;packageGateSha256=Get-Sha256 $packageGatePath;routeGateSha256=Get-Sha256 $routeGatePath;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
