#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha256, [string]$RequiredState = '') {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D9 build dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D9 build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($RequiredState)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Assert-True ([string]$value.state -eq $RequiredState) "O2D9 build dependency state changed: $Path"
    }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D9 build create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = $PSScriptRoot
$requestId = 'REQ_20260826T014322494Z_85B91FC365FB'
$endpointPath = Join-Path $root 'Invoke-O2D9ScribeEndpoint.ps1'
$enginePath = Join-Path $project 'work\OPENCV_SCRIBE_V1R3\ArgosOpenCvScribeV1R3.py'
$jobPath = Join-Path $root 'O2D9_SLOT16_JOB.json'
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$signedRoot = Join-Path $root 'signed'
$partialSigned = Join-Path $root 'signed.partial'
$readyRoot = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root 'final'
$partialFinal = Join-Path $root 'final.partial'
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$gatePath = Join-Path $root 'O2D9_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$recoveryTool = Join-Path $project 'utilities\Confirm-ArgosRecoveryIntent.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cloneManifestPath = Join-Path $root 'O2D9_CLONE_LITERAL_REMEDIATION.json'
$cloneGatePath = Join-Path $root 'O2D9_CLONE_LITERAL_GATE.json'

$endpointSha = '3334A28434C6AC09CDDA3BF748C6AD5E1FF418243785BABA4AE62134D25A8883'
$engineSha = '8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB'
$jobSha = 'B288062204BF5079F885CD64A2F2F576A8A770F732FB3B572A226A4F0C4ED29F'
$definitionSha = '4CC1C9B8EDB9624AC5612FE37A1269DF56E293DD10E341A1852ADD0AB57B1EB1'
$testGateSha = '33487FFDF56E7F6805649EB1FA8FB9FF270E07C9CE099105496B15A7166BBD75'
$recoveryIntentSha = '5F2DAB14A144B55A260F4D10A4FB16A5FB39046B1CF5A00FD1D5F43AA17898EC'
$preactionSha = 'C978B20BB8E867575BAF4A2DB1582BA986B9F77D43D934AE9B543FB7F1E86F01'

Assert-Pin $endpointPath $endpointSha
Assert-Pin $enginePath $engineSha
Assert-Pin $jobPath $jobSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'O2D9_ENTRYPOINT_TEST_GATE.json') $testGateSha 'PASS_O2D9_ENTRYPOINT_TEST_GATE'
Assert-Pin $cloneManifestPath '03FC9946C2174416BE2CC16EC9417CD5D1819031447CECCD2CE5614385F24061'
Assert-Pin (Join-Path $root 'O2D9_RECOVERY_INTENT.json') $recoveryIntentSha
Assert-Pin (Join-Path $root 'PREACTION_BUILD_SIGN_O2D9.json') $preactionSha 'PASS_PREACTION_CONTRACT'
Assert-Pin (Join-Path $project 'work\FIDUCIAL_OPENCV_JBOD_INSTALL_FOI1\FOI1_TERMINAL_RESPONSE_GATE.json') 'E54585857204BDC2FE9A4632BAF3308987F195F91FFE00B9E98A0D78E56B169C' 'PASS_FOI1_SIGNED_TERMINAL_RESPONSE'
Assert-Pin (Join-Path $project 'work\OPENCV_PROVIDER_PLATFORM_V1\OCV01_PLATFORM_GATE.json') 'F0A6B44976C570FCE4CCAB28839AC4DEC702B51B9EEE87859738D1332DB11190' 'PASS_OCV01_PROVIDER_PLATFORM_DISABLED_CONTRACT'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'
foreach ($tool in @($packageTester,$pathTool,$recoveryTool,$preactionTool,$windowsPowerShell,$identityPath,$publicCertificate)) { Assert-True (Test-Path -LiteralPath $tool -PathType Leaf) "O2D9 build tool absent: $tool" }

Assert-True (Test-Path -LiteralPath $cloneGatePath -PathType Leaf) 'O2D9 clone gate absent.'
$cloneGate = Get-Content -Raw -LiteralPath $cloneGatePath | ConvertFrom-Json
Assert-True ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$cloneGate.mode -eq 'GATE') 'O2D9 clone gate state changed.'
Assert-True ([string]$cloneGate.manifestSha256 -eq (Get-Sha256 $cloneManifestPath)) 'O2D9 clone gate manifest pin changed.'
$builderPair = @($cloneGate.pairs | Where-Object { [string]$_.generated -eq 'work/OPENCV_SCRIBE_O2D9/Build-O2D9Request.ps1' })
Assert-True ($builderPair.Count -eq 1 -and [string]$builderPair[0].generatedSha256 -eq (Get-Sha256 $MyInvocation.MyCommand.Path)) 'O2D9 clone gate does not bind the exact builder.'

$recoveryJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $recoveryTool -IntentPath (Join-Path $root 'O2D9_RECOVERY_INTENT.json') -ProjectRoot $project -Preflight -AsJson
Assert-True ($LASTEXITCODE -eq 0) 'O2D9 recovery intent guard failed.'
$recovery = $recoveryJson | ConvertFrom-Json
Assert-True ([string]$recovery.state -eq 'PASS_ARGOS_RECOVERY_INTENT') 'O2D9 recovery intent state changed.'
$preactionJson = & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $preactionTool -AuditPath (Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json') -ContractPath (Join-Path $root 'PREACTION_BUILD_SIGN_O2D9.json') -ProjectRoot $project -Preflight | Out-String
$preaction = $preactionJson | ConvertFrom-Json
Assert-True ([string]$preaction.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'O2D9 preaction state changed.'

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/Invoke-O2D9ScribeEndpoint.ps1') 'O2D9 definition route changed.'
Assert-True (@($definition.changes).Count -eq 1 -and @($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'O2D9 definition action cardinality changed.'
Assert-True ([string]$definition.rehearsal.requiredState -eq 'PASS_O2D9_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED' -and [int]$definition.timeoutContract.endpointWorkerOuterTimeoutSeconds -gt [int]$definition.timeoutContract.opencvChildTimeoutSeconds) 'O2D9 timeout or normal required-state contract changed.'
Assert-True (-not [bool]$definition.sourceProcessingContract.boundedExceptionSearchAllowed -and -not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed -and -not [bool]$definition.sourceProcessingContract.holdClearanceAllowed -and -not [bool]$definition.sourceProcessingContract.providerActivationAllowed) 'O2D9 processing boundary changed.'
foreach ($path in @($signedRoot,$partialSigned,$finalRoot,$partialFinal,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D9 fresh output exists: $path" }

$planned = @(
    $readyRoot,
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),
    (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $readyRoot 'payload\Invoke-O2D9ScribeEndpoint.ps1'),
    (Join-Path $readyRoot 'payload\ArgosOpenCvScribeV1R3.py'),
    (Join-Path $readyRoot 'payload\O2D9_SLOT16_JOB.json'),
    $zipPath,
    (Join-Path $partialFinal 'extract\payload\Invoke-O2D9ScribeEndpoint.ps1'),
    $gatePath,
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789_00000000\package\payload\Invoke-O2D9ScribeEndpoint.ps1',
    'D:\A2\w\ocv\O2D9_20260826T014322494Z_85B91FC3\refs\glyphs_v5_confirmed_20260806\028_62630_456_SLOT21_P04_S.png',
    'D:\A2\o\ocv\O2D9_20260826T014322494Z_85B91FC3\EXECUTION.json'
)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O2D9 build path gate failed.'

$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ($certificate.HasPrivateKey) 'O2D9 signer private key unavailable.'

if ($Preflight) {
    [ordered]@{schema='argos_o2d9_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D9_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=3;endpointSha256=$endpointSha;engineSha256=$engineSha;jobSha256=$jobSha;definitionSha256=$definitionSha;pathState=[string]$pathGate.state;signerThumbprint=$thumbprint;mutationsPerformed=$false;targetExecuted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 7
    return
}

$files = @(
    [ordered]@{source=$endpointPath;path='payload/Invoke-O2D9ScribeEndpoint.ps1';bytes=[int64](Get-Item -LiteralPath $endpointPath).Length;sha256=$endpointSha},
    [ordered]@{source=$enginePath;path='payload/ArgosOpenCvScribeV1R3.py';bytes=[int64](Get-Item -LiteralPath $enginePath).Length;sha256=$engineSha},
    [ordered]@{source=$jobPath;path='payload/O2D9_SLOT16_JOB.json';bytes=[int64](Get-Item -LiteralPath $jobPath).Length;sha256=$jobSha}
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
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O2D9 signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extractRoot = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
$expected = @{
    'payload/Invoke-O2D9ScribeEndpoint.ps1'=$endpointSha
    'payload/ArgosOpenCvScribeV1R3.py'=$engineSha
    'payload/O2D9_SLOT16_JOB.json'=$jobSha
    'PORTAL_REQUEST_MANIFEST.json'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json')
    'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha256 (Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig')
}
$extracted = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File)
Assert-True ($extracted.Count -eq 5) 'O2D9 final ZIP file count changed.'
foreach ($item in $expected.GetEnumerator()) {
    $path = Join-Path $extractRoot $item.Key.Replace('/', '\')
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D9 final ZIP leaf absent: $($item.Key)"
    Assert-True ((Get-Sha256 $path) -eq [string]$item.Value) "O2D9 final ZIP leaf changed: $($item.Key)"
}
$tokens = $null
$parserErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extractRoot 'payload\Invoke-O2D9ScribeEndpoint.ps1'), [ref]$tokens, [ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'O2D9 extracted endpoint parser failed.'
$zipSha = Get-Sha256 $partialZip
$gate = [ordered]@{
    schema='argos_o2d9_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D9_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip='work/OPENCV_SCRIBE_O2D9/final/'+$zipName
    requestZipBytes=[int64](Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig']
    maintenanceDefinitionSha256=$definitionSha;endpointSha256=$endpointSha;engineSha256=$engineSha;jobSha256=$jobSha;payloadFileCount=3;exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true
    entrypointTestGateSha256=$testGateSha;cloneLiteralGateSha256=$cloneGateSha;recoveryIntentSha256=$recoveryIntentSha;buildPreactionSha256=$preactionSha;pathState=[string]$pathGate.state;maximumEffectiveLength=[int]$pathGate.maximumEffectiveLength
    normalRequiredState='PASS_O2D9_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';outerTimeoutCoversChild=$true;uniqueRequestId=$true;installedReferenceBundleReusedByExactHash=$true
    publicationRequiresCompleteRouteGate=$true;publicationAuthorized=$false;targetExecuted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
  }
Write-JsonNew $gatePath $gate 12
Move-Item -LiteralPath $partialFinal -Destination $finalRoot
$gate | ConvertTo-Json -Depth 12
