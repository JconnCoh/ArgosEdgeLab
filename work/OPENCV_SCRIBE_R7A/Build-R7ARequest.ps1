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
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R7A build dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R7A build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Assert-True ([string]$value.state -eq $RequiredState) "R7A build dependency state changed: $Path"
    }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "R7A build create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = $PSScriptRoot
$requestId = 'REQ_20260902T011500444Z_22R7A'
$endpointPath = Join-Path $root 'Invoke-R7AScribeSlot22.ps1'
$enginePath = Join-Path $root 'ArgosOpenCvScribeV1R7.py'
$configurationPath = Join-Path $root 'R7A_CONFIGURATION.json'
$batchPath = Join-Path $root 'BATCH.json'
$jobPaths = @(@('S22.json') | ForEach-Object { Join-Path $root $_ })
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$testGatePath = Join-Path $project 'work\OPENCV_SCRIBE_V1R7\R7_MARKED_SLOT22_LOCAL_GATE.json'
$selfPinGatePath = Join-Path $root 'R7A_STATIC_PACKAGE_GATE.json'
$stageRoot = 'C:\R7A1'
$signedRoot = Join-Path $stageRoot 'signed'
$partialSigned = Join-Path $stageRoot 'signed.partial'
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root 'final'
$partialFinal = Join-Path $stageRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$gatePath = Join-Path $root 'R7A_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$endpointSha = 'A1E80FC5BC02DF7290F1166647F35D504015B78F39945434990A8CD71427E312'
$engineSha = '7202937B06296B7E36AD4E44E90FF946A47B30DC4B5CF3EE9656DB6003807316'
$configurationSha = '7D77C1E44975A38F480D3C329E9F86AACBFB4377D9182C62E61C0D42D3395292'
$batchSha = '92E768FADE776A36A897E3A032876CD10576D147E6247D705994C4F6E1DDAAA3'
$jobShas = @('DCC307913078F6562A9057F445963FD9F19EF21E3C1A1BA9FEC0B0C648DDB0B7')
$definitionSha = 'E05E2C1EBC4747B130B7D39834D8C2CD9E2911D3F7C8EB6AA705F36184C11F29'
$testGateSha = '714E024B7A33B25137587A2F2D83A30DCBD314656ACB04D18DBC13B33E48C91D'
$selfPinGateSha = '07E4E51F0C8AAAD1D36EBCDA972EFBEFD937EA60385B4C0533569B62216F5BBF'

Assert-Pin $endpointPath $endpointSha
Assert-Pin $enginePath $engineSha
Assert-Pin $configurationPath $configurationSha
Assert-Pin $batchPath $batchSha
for ($index = 0; $index -lt $jobPaths.Count; $index++) { Assert-Pin $jobPaths[$index] $jobShas[$index] }
Assert-Pin $definitionPath $definitionSha
Assert-Pin $testGatePath $testGateSha 'PASS_R7_MARKED_SLOT22_LOCATION_AND_DETERMINISM'
Assert-Pin $selfPinGatePath $selfPinGateSha 'PASS_R7A_STATIC_PACKAGE_GATE'
Assert-Pin (Join-Path $project 'work\FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1\FOI1_TERMINAL_RESPONSE_GATE.json') 'E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C' 'PASS_FOI1_SIGNED_TERMINAL_RESPONSE'
Assert-Pin (Join-Path $project 'work\OPENCV_PROVIDER_PLATFORM_V1\OCV01_PLATFORM_GATE.json') '47A45819DD0C09A62FE1AF22A0A7655552A222677DD545F29817D6C630428430' 'PASS_OCV01_PROVIDER_PLATFORM_DISABLED_CONTRACT'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
Assert-Pin $identityPath '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
Assert-Pin $publicCertificate '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
Assert-Pin $packageTester '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/Invoke-R7AScribeSlot22.ps1') 'R7A definition route changed.'
Assert-True (@($definition.changes).Count -eq 1 -and [string]$definition.changes[0].installedSha256 -eq $endpointSha -and [bool]$definition.changes[0].allowCreate) 'R7A maintenance change changed.'
Assert-True (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'R7A action cardinality changed.'
Assert-True ([int]$definition.timeoutContract.endpointWorkerOuterTimeoutSeconds -gt ([int]$definition.timeoutContract.opencvChildTimeoutSeconds * [int]$definition.timeoutContract.maximumSequentialChildren)) 'R7A outer timeout does not cover all children.'
Assert-True ([string]$definition.rehearsal.gateSha256 -eq $testGateSha -and [string]$definition.rehearsal.selfPinGateSha256 -eq $selfPinGateSha) 'R7A declared rehearsal evidence changed.'
Assert-True (-not [bool]$definition.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed -and -not [bool]$definition.sourceProcessingContract.holdClearanceAllowed -and -not [bool]$definition.sourceProcessingContract.providerActivationAllowed) 'R7A processing authority changed.'
foreach ($path in @($stageRoot,$signedRoot,$partialSigned,$finalRoot,$partialFinal,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R7A fresh output exists: $path" }

$planned = @($readyRoot,(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),$zipPath,(Join-Path $partialFinal 'extract\payload\Invoke-R7AScribeSlot22.ps1'),$gatePath,'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789_00000000\package\payload\Invoke-R7AScribeSlot22.ps1','D:\A2\w\ocv\R7A.partial\refs\glyphs_v5_confirmed_20260806\028_62630_456_SLOT25_P04_S.png','D:\A2\o\ocv\R7A\Slot22\RESULT.json')
foreach ($path in @($endpointPath,$enginePath,$configurationPath,$batchPath)+$jobPaths) { $planned += $path }
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET' -and @($pathGate.candidates).Count -eq $planned.Count) 'R7A build path gate changed.'
$maximumEffectiveLength = [int]((@($pathGate.candidates) | Measure-Object effectiveLength -Maximum).Maximum)

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $certificateMatches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint })
    Assert-True ($certificateMatches.Count -eq 1 -and $certificateMatches[0].HasPrivateKey) 'R7A signer certificate changed or private key is absent.'
    $certificate = $certificateMatches[0]
}
finally { $store.Close(); $store.Dispose() }

if ($Preflight) {
    [ordered]@{schema='argos_r7a_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R7A_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=5;endpointSha256=$endpointSha;engineSha256=$engineSha;configurationSha256=$configurationSha;batchSha256=$batchSha;jobCount=1;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;signerThumbprint=$thumbprint;mutationsPerformed=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$files = New-Object Collections.Generic.List[object]
$files.Add([ordered]@{source=$endpointPath;path='payload/Invoke-R7AScribeSlot22.ps1';bytes=[int64](Get-Item -LiteralPath $endpointPath).Length;sha256=$endpointSha})
$files.Add([ordered]@{source=$enginePath;path='payload/ArgosOpenCvScribeV1R7.py';bytes=[int64](Get-Item -LiteralPath $enginePath).Length;sha256=$engineSha})
$files.Add([ordered]@{source=$configurationPath;path='payload/R7A_CONFIGURATION.json';bytes=[int64](Get-Item -LiteralPath $configurationPath).Length;sha256=$configurationSha})
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
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R7A signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{'payload/Invoke-R7AScribeSlot22.ps1'=$endpointSha;'payload/ArgosOpenCvScribeV1R7.py'=$engineSha;'payload/R7A_CONFIGURATION.json'=$configurationSha;'payload/BATCH.json'=$batchSha;'payload/S22.json'=$jobShas[0];'PORTAL_REQUEST_MANIFEST.json'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
Assert-True ($extracted.Count -eq 7) 'R7A final ZIP file count changed.'
foreach ($item in $expected.GetEnumerator()) {
    $path = Join-Path $extractRoot $item.Key.Replace('/', '\')
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R7A final ZIP leaf absent: $($item.Key)"
    Assert-True ((Get-Sha256 $path) -eq [string]$item.Value) "R7A final ZIP leaf changed: $($item.Key)"
}
$extractedManifest = Get-Content -Raw -LiteralPath (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json') | ConvertFrom-Json
Assert-True (@($extractedManifest.files).Count -eq 5 -and [string]$extractedManifest.changes[0].installedSha256 -eq $endpointSha) 'R7A extracted manifest payload/change contract changed.'
Assert-True ([string]$extractedManifest.rehearsal.gateSha256 -eq $testGateSha -and [string]$extractedManifest.rehearsal.selfPinGateSha256 -eq $selfPinGateSha) 'R7A extracted manifest gate pins changed.'
$gate = [ordered]@{schema='argos_r7a_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R7A_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_R7A/final/'+$zipName);requestZipBytes=[int64](Get-Item -LiteralPath $partialZip).Length;requestZipSha256=Get-Sha256 $partialZip;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;endpointSha256=$endpointSha;engineSha256=$engineSha;configurationSha256=$configurationSha;minimumObservedHeightRatio=0.9;batchSha256=$batchSha;jobSha256=$jobShas;payloadFileCount=5;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;maintenanceInstalledShaMatchesPayload=$true;markedLocalizationGateSha256=$testGateSha;staticPackageGateSha256=$selfPinGateSha;pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;caseCount=1;maximumConcurrentProviderChildren=1;automaticIdentityAuthority=$false;maximumPublications=1;retryAuthorized=$false;publicationRequiresCompleteRouteGate=$true;publicationAuthorized=$false;targetExecuted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
Write-JsonNew $gatePath $gate 16
[void](New-Item -ItemType Directory -Path $finalRoot)
Move-Item -LiteralPath $partialZip -Destination $zipPath
$gate | ConvertTo-Json -Depth 16
