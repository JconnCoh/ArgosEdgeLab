#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}
function Assert-Pin([string]$Path, [string]$Sha256, [string]$RequiredState = '') {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R6V1 build dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R6V1 build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Assert-True ([string]$value.state -eq $RequiredState) "R6V1 build dependency state changed: $Path"
    }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "R6V1 build create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = $PSScriptRoot
$requestId = 'REQ_20260901T160000111Z_7F77B8EFE092'
$endpointPath = Join-Path $root 'Invoke-R6V1ScribeBatch.ps1'
$enginePath = Join-Path $project 'work\OPENCV_SCRIBE_V1R6\ArgosOpenCvScribeV1R6.py'
$batchPath = Join-Path $root 'BATCH.json'
$jobPaths = @('S22.json','S23.json','S24.json','S25.json') | ForEach-Object { Join-Path $root $_ }
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$preactionPath = Join-Path $root 'PREACTION_BUILD_SIGN_R6V1.json'
$testGatePath = Join-Path $root 'R6V1_ENTRYPOINT_TEST_GATE_R2.json'
$selfPinGatePath = Join-Path $root 'R6V1_SELF_PIN_GATE.json'
$signedRoot = Join-Path $root 'signed'
$partialSigned = Join-Path $root 'signed.partial'
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root 'final'
$partialFinal = Join-Path $root 'final.partial'
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$gatePath = Join-Path $root 'R6V1_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'

$endpointSha = 'F805E8336FF0A1847D0326ED8A77FFC39207128E8C69177559D0F6BE9E888A25'
$engineSha = '1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9'
$batchSha = '7F77B8EFE0926E4AD37A737F07C98E1A3DF2E8F1392D0B47B886E05F9F52143B'
$jobShas = @('CBE13E1B27C818E9B2FA610E1A01792991B371145AC6A4BE5C848078EECBCAA0','A05400FDC7E378205A0B6975626EECDDA1F1942AB4417AB1881DFA029C49F083','3315AFC2DC2B7674B2C9A0EFC799758A8D37E0726E34607580A5AD01A2A9E6C9','30D6AEC2A200772E0B1DE15E99261F9742CEA8A845A5B3A4D1113C2B18490442')
$definitionSha = 'B4920DD4F2F087C05B4FA9E5CC73280509856BA030A13D6547D1350D6F750DA3'
$preactionSha = 'A0C0C8039240B7108CB4B9595B0E54E3A722D4B7753121206FAC0CE8C1A143E8'
$testGateSha = '2831A8F082E1B6B6D43B460665E875200B6D666B84E9320E49D51AB9C03859DA'
$selfPinGateSha = '58A296205B0A8398087E4059539932F0E5A1570488C601902ADF8D952D0E5A46'

Assert-Pin $endpointPath $endpointSha
Assert-Pin $enginePath $engineSha
Assert-Pin $batchPath $batchSha
for ($index = 0; $index -lt $jobPaths.Count; $index++) { Assert-Pin $jobPaths[$index] $jobShas[$index] }
Assert-Pin $definitionPath $definitionSha
Assert-Pin $preactionPath $preactionSha 'PASS_PREACTION_CONTRACT'
Assert-Pin $testGatePath $testGateSha 'PASS_R6V1_ENTRYPOINT_TEST_GATE_R2'
Assert-Pin $selfPinGatePath $selfPinGateSha 'PASS_R6V1_SELF_PIN_AND_LIVE_BRANCH_GATE'
Assert-Pin (Join-Path $project 'work\FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1\FOI1_TERMINAL_RESPONSE_GATE.json') 'E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C' 'PASS_FOI1_SIGNED_TERMINAL_RESPONSE'
Assert-Pin (Join-Path $project 'work\OPENCV_PROVIDER_PLATFORM_V1\OCV01_PLATFORM_GATE.json') '47A45819DD0C09A62FE1AF22A0A7655552A222677DD545F29817D6C630428430' 'PASS_OCV01_PROVIDER_PLATFORM_DISABLED_CONTRACT'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
Assert-Pin $identityPath '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
Assert-Pin $publicCertificate '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
Assert-Pin $packageTester '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'

$preaction = (& $preactionTool -AuditPath (Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json') -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$preaction.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R6V1 build preaction changed.'
$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/Invoke-R6V1ScribeBatch.ps1') 'R6V1 definition route changed.'
Assert-True (@($definition.changes).Count -eq 1 -and [string]$definition.changes[0].installedSha256 -eq $endpointSha -and [bool]$definition.changes[0].allowCreate) 'R6V1 maintenance change changed.'
Assert-True (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'R6V1 action cardinality changed.'
Assert-True ([int]$definition.timeoutContract.endpointWorkerOuterTimeoutSeconds -gt ([int]$definition.timeoutContract.opencvChildTimeoutSeconds * [int]$definition.timeoutContract.maximumSequentialChildren)) 'R6V1 outer timeout does not cover all children.'
Assert-True ([string]$definition.rehearsal.gateSha256 -eq $testGateSha -and [string]$definition.rehearsal.selfPinGateSha256 -eq $selfPinGateSha) 'R6V1 declared rehearsal evidence changed.'
Assert-True (-not [bool]$definition.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed -and -not [bool]$definition.sourceProcessingContract.holdClearanceAllowed -and -not [bool]$definition.sourceProcessingContract.providerActivationAllowed) 'R6V1 processing authority changed.'
foreach ($path in @($signedRoot,$partialSigned,$finalRoot,$partialFinal,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R6V1 fresh output exists: $path" }

$planned = @($readyRoot,(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),$zipPath,(Join-Path $partialFinal 'extract\payload\Invoke-R6V1ScribeBatch.ps1'),$gatePath,'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789_00000000\package\payload\Invoke-R6V1ScribeBatch.ps1','D:\A2\w\ocv\R6V1A.partial\refs\glyphs_v5_confirmed_20260806\028_62630_456_SLOT25_P04_S.png','D:\A2\o\ocv\R6V1A\Slot25\RESULT.json')
foreach ($path in @($endpointPath,$enginePath,$batchPath)+$jobPaths) { $planned += $path }
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET' -and @($pathGate.candidates).Count -eq $planned.Count) 'R6V1 build path gate changed.'
$maximumEffectiveLength = [int]((@($pathGate.candidates) | Measure-Object effectiveLength -Maximum).Maximum)

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $certificateMatches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint })
    Assert-True ($certificateMatches.Count -eq 1 -and $certificateMatches[0].HasPrivateKey) 'R6V1 signer certificate changed or private key is absent.'
    $certificate = $certificateMatches[0]
}
finally { $store.Close(); $store.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_r6v1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V1_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=7;endpointSha256=$endpointSha;engineSha256=$engineSha;batchSha256=$batchSha;jobCount=4;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;signerThumbprint=$thumbprint;mutationsPerformed=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$files = New-Object Collections.Generic.List[object]
$files.Add([ordered]@{source=$endpointPath;path='payload/Invoke-R6V1ScribeBatch.ps1';bytes=[int64](Get-Item -LiteralPath $endpointPath).Length;sha256=$endpointSha})
$files.Add([ordered]@{source=$enginePath;path='payload/ArgosOpenCvScribeV1R6.py';bytes=[int64](Get-Item -LiteralPath $enginePath).Length;sha256=$engineSha})
$files.Add([ordered]@{source=$batchPath;path='payload/BATCH.json';bytes=[int64](Get-Item -LiteralPath $batchPath).Length;sha256=$batchSha})
for ($index = 0; $index -lt $jobPaths.Count; $index++) { $files.Add([ordered]@{source=$jobPaths[$index];path=('payload/S'+(22+$index)+'.json');bytes=[int64](Get-Item -LiteralPath $jobPaths[$index]).Length;sha256=$jobShas[$index]}) }
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files.ToArray() | ForEach-Object { [ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256} });entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@($definition.allowedTaskActions);allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal}

$partialReady = Join-Path $partialSigned ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partialReady 'payload'))
foreach ($file in $files) { Copy-Item -LiteralPath $file.source -Destination (Join-Path $partialReady $file.path.Replace('/', '\')) -ErrorAction Stop }
$manifestPath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
[void](New-Item -ItemType Directory -Path $signedRoot)
Move-Item -LiteralPath $partialReady -Destination $readyRoot
Remove-Item -LiteralPath $partialSigned -Force
$packageTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R6V1 signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{'payload/Invoke-R6V1ScribeBatch.ps1'=$endpointSha;'payload/ArgosOpenCvScribeV1R6.py'=$engineSha;'payload/BATCH.json'=$batchSha;'payload/S22.json'=$jobShas[0];'payload/S23.json'=$jobShas[1];'payload/S24.json'=$jobShas[2];'payload/S25.json'=$jobShas[3];'PORTAL_REQUEST_MANIFEST.json'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
Assert-True ($extracted.Count -eq 9) 'R6V1 final ZIP file count changed.'
foreach ($item in $expected.GetEnumerator()) {
    $path = Join-Path $extractRoot $item.Key.Replace('/', '\')
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R6V1 final ZIP leaf absent: $($item.Key)"
    Assert-True ((Get-Sha256 $path) -eq [string]$item.Value) "R6V1 final ZIP leaf changed: $($item.Key)"
}
$extractedManifest = Get-Content -Raw -LiteralPath (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json') | ConvertFrom-Json
Assert-True (@($extractedManifest.files).Count -eq 7 -and [string]$extractedManifest.changes[0].installedSha256 -eq $endpointSha) 'R6V1 extracted manifest payload/change contract changed.'
Assert-True ([string]$extractedManifest.rehearsal.gateSha256 -eq $testGateSha -and [string]$extractedManifest.rehearsal.selfPinGateSha256 -eq $selfPinGateSha) 'R6V1 extracted manifest gate pins changed.'
$gate = [ordered]@{schema='argos_r6v1_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V1_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_R6V1/final/'+$zipName);requestZipBytes=[int64](Get-Item -LiteralPath $partialZip).Length;requestZipSha256=Get-Sha256 $partialZip;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;endpointSha256=$endpointSha;engineSha256=$engineSha;batchSha256=$batchSha;jobSha256=$jobShas;payloadFileCount=7;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;maintenanceInstalledShaMatchesPayload=$true;entrypointTestGateSha256=$testGateSha;selfPinGateSha256=$selfPinGateSha;buildPreactionSha256=$preactionSha;pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;caseCount=4;maximumConcurrentProviderChildren=1;automaticIdentityAuthority=$false;maximumPublications=1;retryAuthorized=$false;publicationRequiresCompleteRouteGate=$true;publicationAuthorized=$false;targetExecuted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
Write-JsonNew $gatePath $gate 16
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
$gate | ConvertTo-Json -Depth 16
