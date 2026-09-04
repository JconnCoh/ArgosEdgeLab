#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Require-Pin([string]$Path, [string]$Sha256, [string]$State = '') {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18L build dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18L build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Require ([string]$value.state -eq $State) "R18L build dependency state changed: $Path"
    }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18L build create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18L_20260904A'
$revision = 'R18L_FULL_KLARF_JBOD_REVIEW_ONLY_20260904A'
$payloadRevision = 'R18J_FULL_KLARF_JBOD_REVIEW_ONLY_20260904A'
$entrypoint = Join-Path $PSScriptRoot '..\OPENCV_SCRIBE_R18J\Invoke-R18JCorpusLaunch.ps1'
$payloadManifestPath = Join-Path $PSScriptRoot '..\OPENCV_SCRIBE_R18J\R18J_PAYLOAD_MANIFEST.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$localGatePath = Join-Path $PSScriptRoot '..\OPENCV_SCRIBE_R18J\R18J_CORPUS_LOCAL_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18L_PATH_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18L_FULL_KLARF_PUBLICATION.json'
$stageRoot = 'C:\R18LP'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\R18LV'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$finalZip = Join-Path $finalRoot $zipName
$finalGatePath = Join-Path $PSScriptRoot 'R18L_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$historyAudit = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$localPython = 'C:\Python314\python.exe'
$localPythonSha = '4942B86A6597E5AEE0128DAA00050ED79BC21F6E709A78EB19CBFEB0C2F39AC9'
$localRefs = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$localSource = 'U:\ProjectPortalRO\responses\Lot_62629-401\62629-401_20260902002921\Slot24'
$localProposals = 'C:\R18J_CORPUS_FIXTURE\proposals'

$entrypointSha = '00805DF38D1F78D576CE6245A5534E26E19706B1F02A08A65B67E2DBDD1BA24A'
$payloadManifestSha = 'BF2D0E809915ADEB503E2B7ADEFB3DCAC30903025D851B26067C9FB5B90DC57D'
$definitionSha = 'DF5B71C592E3CD4F44910C8748BCD2FDC2A952F3643C3A9AB6DA7F7E54A7EC24'
$localGateSha = '2803AEE7EF2C1C8993BF279F4F3C1F305B375E4018E1DFC344A8A678A76EA03E'
$pathGateSha = '29C89DF900DCC13D2F07A996DED07B5E4367A7FD5795C7A1DD7298955CEDEA7D'
$preactionSha = '17534BB2C680B1762AAC09A41ABF0B3D8F850A1DD7AF9B5175EC7689F6509658'
$identitySha = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$certificateSha = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$testerSha = '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'

Require-Pin $entrypoint $entrypointSha
Require-Pin $payloadManifestPath $payloadManifestSha
Require-Pin $definitionPath $definitionSha
Require-Pin $localGatePath $localGateSha 'PASS_R18J_CORPUS_LOCAL_GATE'
Require-Pin $pathGatePath $pathGateSha 'PASS_PATH_BUDGET'
Require-Pin $preactionPath $preactionSha 'PASS_PREACTION_CONTRACT'
Require-Pin $identityPath $identitySha
Require-Pin $publicCertificate $certificateSha
Require-Pin $packageTester $testerSha
Require-Pin $localPython $localPythonSha
Require-Pin $localRefs '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
Require (Test-Path -LiteralPath $localSource -PathType Container) 'R18L local rehearsal source absent.'
Require (Test-Path -LiteralPath $localProposals -PathType Container) 'R18L local rehearsal proposal root absent.'

$preactionResult = (& $preactionTool -AuditPath $historyAudit -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18L preaction gate changed.'
$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Require ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/Invoke-R18JCorpusLaunch.ps1') 'R18L maintenance route changed.'
Require (@($definition.changes).Count -eq 1 -and [string]$definition.changes[0].installedSha256 -eq $entrypointSha -and [bool]$definition.changes[0].allowCreate) 'R18L maintenance change changed.'
Require (@($definition.changes[0].approvedPredecessorSha256).Count -eq 1 -and [string]$definition.changes[0].approvedPredecessorSha256[0] -eq $entrypointSha) 'R18L create-only idempotent installed-hash boundary changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'R18L process/task action cardinality changed.'
Require ([string]$definition.sourceProcessingContract.proposalRoot -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals') 'R18L observed proposal root changed.'
Require ([bool]$definition.reviewOnly -and -not [bool]$definition.productionRoutingEnabled -and -not [bool]$definition.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed) 'R18L authority changed.'
$payloadManifest = Get-Content -Raw -LiteralPath $payloadManifestPath | ConvertFrom-Json
Require ([string]$payloadManifest.schema -eq 'argos_opencv_scribe_r18j_payload_manifest_v1' -and [string]$payloadManifest.revision -eq $payloadRevision -and @($payloadManifest.files).Count -eq 23) 'R18L inherited payload manifest shape changed.'
$payloadFiles = @($payloadManifest.files)
foreach ($file in $payloadFiles) {
    $source = Join-Path $project ([string]$file.sourcePath).Replace('/','\')
    Require-Pin $source ([string]$file.sha256)
    Require ((Get-Item -LiteralPath $source).Length -eq [int64]$file.bytes) "R18L payload length changed: $($file.sourcePath)"
}

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $matches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant() -eq $thumbprint })
    Require ($matches.Count -eq 1 -and $matches[0].HasPrivateKey) 'R18L signer certificate or private key changed.'
    $certificate = $matches[0]
}
finally { $store.Close(); $store.Dispose() }

foreach ($path in @($stageRoot,$readyRoot,$stageZip,$verifyRoot,$finalRoot,$finalPartial,$finalGatePath)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18L build fresh output exists: $path"
}
if ($Preflight) {
    [ordered]@{schema='argos_opencv_scribe_r18l_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18L_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=25;entrypointSha256=$entrypointSha;payloadManifestSha256=$payloadManifestSha;definitionSha256=$definitionSha;localGateSha256=$localGateSha;pathGateSha256=$pathGateSha;preactionSha256=$preactionSha;signerThumbprint=$thumbprint;mutationsPerformed=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path (Join-Path $readyRoot 'payload\files'))
Copy-Item -LiteralPath $entrypoint -Destination (Join-Path $readyRoot 'payload\Invoke-R18JCorpusLaunch.ps1')
Copy-Item -LiteralPath $payloadManifestPath -Destination (Join-Path $readyRoot 'payload\R18J_PAYLOAD_MANIFEST.json')
$manifestFiles = New-Object Collections.Generic.List[object]
$manifestFiles.Add([ordered]@{path='payload/Invoke-R18JCorpusLaunch.ps1';bytes=[int64](Get-Item -LiteralPath $entrypoint).Length;sha256=$entrypointSha})
$manifestFiles.Add([ordered]@{path='payload/R18J_PAYLOAD_MANIFEST.json';bytes=[int64](Get-Item -LiteralPath $payloadManifestPath).Length;sha256=$payloadManifestSha})
foreach ($file in $payloadFiles) {
    $source = Join-Path $project ([string]$file.sourcePath).Replace('/','\')
    $packagePath = 'payload/files/' + [string]$file.installRelativePath
    $destination = Join-Path $readyRoot $packagePath.Replace('/','\')
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath $source -Destination $destination
    $manifestFiles.Add([ordered]@{path=$packagePath;bytes=[int64]$file.bytes;sha256=[string]$file.sha256})
}
$created = [DateTimeOffset]::UtcNow
$requestManifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');
    targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;
    credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=$manifestFiles.ToArray();
    entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);
    entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;
    timeoutContract=$definition.timeoutContract;allowedTaskActions=@($definition.allowedTaskActions);
    allowedProcessActions=@($definition.allowedProcessActions);publication=$definition.publication
}
$requestManifestPath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($requestManifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($requestManifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
$packageTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18L signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $stageZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($stageZip, $verifyRoot)
$extracted = @(Get-ChildItem -LiteralPath $verifyRoot -Recurse -File)
Require ($extracted.Count -eq 27) 'R18L extracted final ZIP file count changed.'
foreach ($row in $manifestFiles) {
    $path = Join-Path $verifyRoot ([string]$row.path).Replace('/','\')
    Require-Pin $path ([string]$row.sha256)
    Require ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes) "R18L extracted payload length changed: $($row.path)"
}
Require-Pin (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json') (Get-Sha256 $requestManifestPath)
Require-Pin (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig') (Get-Sha256 $signaturePath)
$exactPackageTest = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$exactPackageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18L extracted signed package verification failed.'
$packagedPreflight = (& (Join-Path $verifyRoot 'payload\Invoke-R18JCorpusLaunch.ps1') -Preflight -Rehearsal -PayloadRoot (Join-Path $verifyRoot 'payload') -WorkRoot 'C:\R18LFW' -OutputRoot 'C:\R18LFO' -SourceRoot $localSource -ProposalRoot $localProposals -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localRefs -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$packagedPreflight.state -eq 'PASS_R18J_CORPUS_LAUNCH_PREFLIGHT' -and -not [bool]$packagedPreflight.mutationsPerformed -and -not [bool]$packagedPreflight.processStarted) 'R18L exact packaged entrypoint preflight failed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
Copy-Item -LiteralPath $stageZip -Destination (Join-Path $finalPartial $zipName)
Copy-Item -LiteralPath $pathGatePath -Destination (Join-Path $finalPartial ($zipName + '.path_gate.json'))
$finalGate = [ordered]@{
    schema='argos_opencv_scribe_r18l_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');
    state='PASS_R18L_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_R18L/final/'+$zipName);
    requestZipBytes=[int64](Get-Item -LiteralPath $stageZip).Length;requestZipSha256=Get-Sha256 $stageZip;
    requestManifestSha256=Get-Sha256 $requestManifestPath;requestSignatureSha256=Get-Sha256 $signaturePath;
    entrypointSha256=$entrypointSha;payloadManifestSha256=$payloadManifestSha;definitionSha256=$definitionSha;
    localGateSha256=$localGateSha;pathGateSha256=$pathGateSha;preactionSha256=$preactionSha;
    payloadFileCount=25;finalZipFileCount=27;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;
    exactPackagedEntrypointPreflightPassed=$true;packagedPreflightState=[string]$packagedPreflight.state;
    maximumPublications=1;retryAuthorized=$false;targetExecuted=$false;sourceImagesRead=$false;
    backgroundProcessStarted=$false;identityAccepted=$false;readerModified=$false;referenceLibraryModified=$false;
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false
}
Write-JsonNew $finalGatePath $finalGate 16
Move-Item -LiteralPath $finalPartial -Destination $finalRoot
$finalGate | ConvertTo-Json -Depth 16
