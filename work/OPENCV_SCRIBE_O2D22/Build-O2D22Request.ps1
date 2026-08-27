#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256, [string]$RequiredState = '') {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D22 build dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D22 build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Assert-True ([string]$value.state -eq $RequiredState) "O2D22 build dependency state changed: $Path"
    }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D22 build create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function New-FinalPackageGate([int64]$RequestZipBytes, [string]$RequestZipSha256, [string]$RequestManifestSha256, [string]$RequestSignatureSha256) {
    return [ordered]@{
        schema='argos_o2d22_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_SCRIBE_O2D22/final/'+$zipName
        requestZipBytes=$RequestZipBytes;requestZipSha256=$RequestZipSha256;requestManifestSha256=$RequestManifestSha256;requestSignatureSha256=$RequestSignatureSha256
        maintenanceDefinitionSha256=$definitionSha;endpointSha256=$endpointSha;engineSha256=$engineSha;jobSha256=$jobSha;payloadFileCount=3;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true
        endpointPayloadSha256=$endpointSha;declaredInstalledSha256=[string]$definition.changes[0].installedSha256;maintenanceInstalledShaMatchesPayload=$true
        entrypointTestGateState='PASS_O2D22_ENTRYPOINT_TEST_GATE_R2';entrypointTestGateSha256=$testGateSha;declaredRehearsalGateState=[string]$definition.rehearsal.gateState;declaredRehearsalGateSha256=[string]$definition.rehearsal.gateSha256
        selfPinGateState='PASS_O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE';selfPinGateSha256=$selfPinGateSha;declaredSelfPinGateState=[string]$definition.rehearsal.selfPinGateState;declaredSelfPinGateSha256=[string]$definition.rehearsal.selfPinGateSha256;endpointSelfPinCount=6;endpointSelfPinMatchCount=6;liveAssertionBranchCaseCount=3
        noArgumentFileGateSha256=$noArgumentGateSha;cloneLiteralGateSha256=$cloneGateSha;developmentParentTerminalGateSha256=$developmentParentTerminalGateSha;buildPreactionSha256=$preactionSha;pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength
        normalRequiredState='PASS_O2D22_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';outerTimeoutCoversChild=$true;uniqueRequestId=$true;installedReferenceBundleReusedByExactHash=$true
        publicationRequiresCompleteRouteGate=$true;publicationAuthorized=$false;targetExecuted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = $PSScriptRoot
$requestId = 'REQ_20260827T030200111Z_6C5C7F1FBF26'
$endpointPath = Join-Path $root 'Invoke-O2D22ScribeEndpoint.ps1'
$enginePath = Join-Path $project 'work\OPENCV_SCRIBE_V1R5\ArgosOpenCvScribeV1R5.py'
$jobPath = Join-Path $root 'O2D22_SLOT24_JOB.json'
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$signedRoot = Join-Path $root 'signed'
$partialSigned = Join-Path $root 'signed.partial'
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root 'final'
$partialFinal = Join-Path $root 'final.partial'
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$gatePath = Join-Path $root 'O2D22_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cloneManifestPath = Join-Path $root 'O2D22_CLONE_LITERAL_REMEDIATION_BUILD_FINAL.json'
$cloneGatePath = Join-Path $root 'O2D22_CLONE_LITERAL_GATE_FINAL.json'
$developmentParentTerminalGatePath = Join-Path $project 'work\OPENCV_SCRIBE_O2D21\O2D21_TERMINAL_RESPONSE_GATE.json'
$selfPinGatePath = Join-Path $root 'O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE.json'

$endpointSha = 'C3046E59AF78DC59C28B9557AE108BD62DBBF6528877D53981E27319566316C6'
$engineSha = 'F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB'
$jobSha = '227BF3F6409B3AB822E9D2091263F0BCA3A2B60F01C964816B0815B678F92EE5'
$definitionSha = '682F29824F052CFDF6C469473040309E6736D806015B50E9578B4CC8839FADC3'
$testGateSha = 'B5881EA13C82A0D7D4F9D27C61846A63361C2D134A385905DB0B08E9B240FD48'
$selfPinGateSha = '4E7F8287C426AF092B7432EFCC353C69A9FB73C06402FA4E513BA0AC57620D58'
$noArgumentGateSha = '78A8F884E3877C6677A1028E23BBD54F890172C7D706A4FFF31921E5AF5C22A9'
$developmentParentTerminalGateSha = '40A6A70324BF3D22AFD681CEBAF242B1ECBCA8C6656398B0687E8313054605FC'
$preactionSha = '94019610E1E16397DDE1632177418C0C47682AE1A25790D54E4532B0EED80E7C'

Assert-Pin $endpointPath $endpointSha
Assert-Pin $enginePath $engineSha
Assert-Pin $jobPath $jobSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'O2D22_ENTRYPOINT_TEST_GATE_R2.json') $testGateSha 'PASS_O2D22_ENTRYPOINT_TEST_GATE_R2'
Assert-Pin $selfPinGatePath $selfPinGateSha 'PASS_O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE'
Assert-Pin (Join-Path $root 'O2D22_NO_ARGUMENT_FILE_GATE.json') $noArgumentGateSha 'PASS_O2D22_EXACT_NO_ARGUMENT_WINDOWS_POWERSHELL_51_FILE'
Assert-Pin $cloneManifestPath '58C66C356CD19C73F7BA450BD6C9231E4E38C806BE3D086889D1F7ADBCBEC900'
Assert-Pin $developmentParentTerminalGatePath $developmentParentTerminalGateSha 'PASS_O2D21_EXACT_SIGNED_SLOT23_BLIND_VALIDATION_RESPONSE'
Assert-Pin (Join-Path $root 'PREACTION_BUILD_SIGN_O2D22.json') $preactionSha 'PASS_PREACTION_CONTRACT'
Assert-Pin (Join-Path $project 'work\FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1\FOI1_TERMINAL_RESPONSE_GATE.json') 'E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C' 'PASS_FOI1_SIGNED_TERMINAL_RESPONSE'
Assert-Pin (Join-Path $project 'work\OPENCV_PROVIDER_PLATFORM_V1\OCV01_PLATFORM_GATE.json') 'F0A6B44976C570FCE4CCAB28839AC4DEC702B51B9EEE87859738D1332DB11190' 'PASS_OCV01_PROVIDER_PLATFORM_DISABLED_CONTRACT'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
foreach ($tool in @($packageTester,$pathTool,$preactionTool,$windowsPowerShell,$identityPath,$publicCertificate)) { Assert-True (Test-Path -LiteralPath $tool -PathType Leaf) "O2D22 build tool absent: $tool" }

Assert-True (Test-Path -LiteralPath $cloneGatePath -PathType Leaf) 'O2D22 clone gate absent.'
$cloneGate = Get-Content -Raw -LiteralPath $cloneGatePath | ConvertFrom-Json
Assert-True ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$cloneGate.mode -eq 'GATE') 'O2D22 clone gate state changed.'
Assert-True ([string]$cloneGate.manifestSha256 -eq (Get-Sha256 $cloneManifestPath)) 'O2D22 clone gate manifest pin changed.'
$builderPair = @($cloneGate.pairs | Where-Object { [string]$_.generated -eq 'work/OPENCV_SCRIBE_O2D22/Build-O2D22Request.ps1' })
Assert-True ($builderPair.Count -eq 1 -and [string]$builderPair[0].generatedSha256 -eq (Get-Sha256 $MyInvocation.MyCommand.Path)) 'O2D22 clone gate does not bind the exact builder.'
$cloneGateSha = Get-Sha256 $cloneGatePath

$preactionJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $preactionTool -AuditPath (Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json') -ContractPath (Join-Path $root 'PREACTION_BUILD_SIGN_O2D22.json') -ProjectRoot $project -Preflight | Out-String
$preaction = $preactionJson | ConvertFrom-Json
Assert-True ([string]$preaction.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'O2D22 preaction state changed.'

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/Invoke-O2D22ScribeEndpoint.ps1') 'O2D22 definition route changed.'
Assert-True (@($definition.changes).Count -eq 1 -and @($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'O2D22 definition action cardinality changed.'
Assert-True ([string]$definition.changes[0].source -eq 'payload/Invoke-O2D22ScribeEndpoint.ps1' -and [string]$definition.changes[0].destination -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_O2D22.ps1') 'O2D22 exact maintenance change identity changed.'
Assert-True (@($definition.changes[0].approvedPredecessorSha256).Count -eq 1 -and [string]$definition.changes[0].approvedPredecessorSha256[0] -eq '08B6E76548CEE99EA11FC6245FB07C05F2E31E53B23562F8A1B15B1AC6EF6A32') 'O2D22 approved installed predecessor changed.'
Assert-True ([string]$definition.changes[0].installedSha256 -eq $endpointSha) 'O2D22 maintenance installedSha256 does not equal the exact endpoint payload.'
Assert-True ([string]$definition.rehearsal.requiredState -eq 'PASS_O2D22_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED' -and [int]$definition.timeoutContract.endpointWorkerOuterTimeoutSeconds -gt [int]$definition.timeoutContract.opencvChildTimeoutSeconds) 'O2D22 timeout or normal required-state contract changed.'
Assert-True ([string]$definition.rehearsal.gateState -eq 'PASS_O2D22_ENTRYPOINT_TEST_GATE_R2' -and [string]$definition.rehearsal.gateSha256 -eq $testGateSha) 'O2D22 declared entrypoint rehearsal evidence changed.'
Assert-True ([string]$definition.rehearsal.selfPinGateState -eq 'PASS_O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE' -and [string]$definition.rehearsal.selfPinGateSha256 -eq $selfPinGateSha) 'O2D22 declared self-pin/live-branch evidence changed.'
Assert-True ([string]$definition.sourceProcessingContract.inputMode -eq 'DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE' -and [bool]$definition.sourceProcessingContract.upstreamNotchHoldDoesNotSkipScribeDevelopment -and [bool]$definition.sourceProcessingContract.boundedExceptionSearchAllowed -and -not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed -and -not [bool]$definition.sourceProcessingContract.holdClearanceAllowed -and -not [bool]$definition.sourceProcessingContract.providerActivationAllowed) 'O2D22 processing boundary changed.'
foreach ($path in @($signedRoot,$partialSigned,$finalRoot,$partialFinal,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D22 fresh output exists: $path" }

$planned = @(
    $readyRoot,
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $readyRoot 'payload\Invoke-O2D22ScribeEndpoint.ps1'),
    (Join-Path $readyRoot 'payload\ArgosOpenCvScribeV1R5.py'),
    (Join-Path $readyRoot 'payload\O2D22_SLOT24_JOB.json'),
    $zipPath,
    (Join-Path $partialFinal 'extract\payload\Invoke-O2D22ScribeEndpoint.ps1'),
    $gatePath,
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789_00000000\package\payload\Invoke-O2D22ScribeEndpoint.ps1',
    'X:\62619-433_20260824005735\Slot24\BrightfieldFrontsideWafer\resizedImage\62619-433_Slot24_BrightfieldFrontsideWafer_PM2_resizedImage.bmp',
    'X:\62619-433_20260824005735\Slot24\DarkfieldFrontsideWafer\resizedImage\62619-433_Slot24_DarkfieldFrontsideWafer_PM2_resizedImage.bmp',
    'D:\A2\w\ocv\O2D22_20260827T030200000Z_6C5C7F1F\refs\glyphs_v5_confirmed_20260806\028_62630_456_SLOT24_P04_S.png',
    'D:\A2\o\ocv\O2D22_20260827T030200000Z_6C5C7F1F\EXECUTION.json'
)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O2D22 build path gate failed.'
$candidateRows = @($pathGate.candidates)
Assert-True ($candidateRows.Count -eq $planned.Count) 'O2D22 build path candidate cardinality changed.'
$maximumEffectiveLength = [int](($candidateRows | Measure-Object effectiveLength -Maximum).Maximum)

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ($certificate.HasPrivateKey) 'O2D22 signer private key unavailable.'

if ($Preflight) {
    $projectionHash = '0' * 64
    $projection = New-FinalPackageGate -RequestZipBytes 0 -RequestZipSha256 $projectionHash -RequestManifestSha256 $projectionHash -RequestSignatureSha256 $projectionHash
    $projectionRoundTrip = $projection | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    Assert-True ([string]$projectionRoundTrip.schema -eq 'argos_o2d22_final_package_gate_v1' -and [string]$projectionRoundTrip.cloneLiteralGateSha256 -eq $cloneGateSha) 'O2D22 final gate construction rehearsal failed.'
    [ordered]@{schema='argos_o2d22_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=3;endpointSha256=$endpointSha;engineSha256=$engineSha;jobSha256=$jobSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;signerThumbprint=$thumbprint;finalGateConstructionRehearsed=$true;mutationsPerformed=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 7
    return
}

$files = @(
    [ordered]@{source=$endpointPath;path='payload/Invoke-O2D22ScribeEndpoint.ps1';bytes=[int64](Get-Item -LiteralPath $endpointPath).Length;sha256=$endpointSha},
    [ordered]@{source=$enginePath;path='payload/ArgosOpenCvScribeV1R5.py';bytes=[int64](Get-Item -LiteralPath $enginePath).Length;sha256=$engineSha},
    [ordered]@{source=$jobPath;path='payload/O2D22_SLOT24_JOB.json';bytes=[int64](Get-Item -LiteralPath $jobPath).Length;sha256=$jobSha}
)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1'
    files=@($files | ForEach-Object { [ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256} });entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs)
    sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@($definition.allowedTaskActions);allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal
}

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
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O2D22 signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{
    'payload/Invoke-O2D22ScribeEndpoint.ps1'=$endpointSha
    'payload/ArgosOpenCvScribeV1R5.py'=$engineSha
    'payload/O2D22_SLOT24_JOB.json'=$jobSha
    'PORTAL_REQUEST_MANIFEST.json'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json')
    'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')
}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
Assert-True ($extracted.Count -eq 5) 'O2D22 final ZIP file count changed.'
foreach ($item in $expected.GetEnumerator()) {
    $path = Join-Path $extractRoot $item.Key.Replace('/', '\')
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D22 final ZIP leaf absent: $($item.Key)"
    Assert-True ((Get-Sha256 $path) -eq [string]$item.Value) "O2D22 final ZIP leaf changed: $($item.Key)"
}
$tokens = $null
$parserErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extractRoot 'payload\Invoke-O2D22ScribeEndpoint.ps1'), [ref]$tokens, [ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'O2D22 extracted endpoint parser failed.'
$extractedManifest = Get-Content -Raw -LiteralPath (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json') | ConvertFrom-Json
Assert-True (@($extractedManifest.changes).Count -eq 1 -and [string]$extractedManifest.changes[0].source -eq 'payload/Invoke-O2D22ScribeEndpoint.ps1') 'O2D22 extracted signed manifest change identity changed.'
Assert-True ([string]$extractedManifest.changes[0].installedSha256 -eq $endpointSha) 'O2D22 extracted signed manifest installedSha256 does not equal endpoint payload.'
Assert-True ([string]$extractedManifest.rehearsal.gateState -eq 'PASS_O2D22_ENTRYPOINT_TEST_GATE_R2' -and [string]$extractedManifest.rehearsal.gateSha256 -eq $testGateSha) 'O2D22 extracted signed manifest rehearsal evidence changed.'
Assert-True ([string]$extractedManifest.rehearsal.selfPinGateState -eq 'PASS_O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE' -and [string]$extractedManifest.rehearsal.selfPinGateSha256 -eq $selfPinGateSha) 'O2D22 extracted signed manifest self-pin evidence changed.'
$zipSha = Get-Sha256 $partialZip
$gate = New-FinalPackageGate -RequestZipBytes ([int64](Get-Item -LiteralPath $partialZip).Length) -RequestZipSha256 $zipSha -RequestManifestSha256 $expected['PORTAL_REQUEST_MANIFEST.json'] -RequestSignatureSha256 $expected['PORTAL_REQUEST_MANIFEST.sig']
Write-JsonNew $gatePath $gate 12
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
$gate | ConvertTo-Json -Depth 12
