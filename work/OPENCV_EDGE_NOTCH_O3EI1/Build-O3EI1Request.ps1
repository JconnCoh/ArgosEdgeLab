[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of Preflight or Build.' }

function Get-Sha([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-Pin([string]$Path, [string]$Sha, [string]$State = '') {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Sha $Path) -ne $Sha) { throw "O3EI1 pinned dependency changed: $Path" }
    if (-not [string]::IsNullOrWhiteSpace($State)) { $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json; if ([string]$value.state -ne $State) { throw "O3EI1 pinned gate state changed: $Path" } }
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$requestId = 'REQ_20260828T143500111Z_O3EI1R01'
$definitionPath = Join-Path $root 'MAINTENANCE_DEFINITION.json'
$entrypointPath = Join-Path $root 'Invoke-O3EI1RuntimeCapability.ps1'
$providerPath = Join-Path $root 'Invoke-O3EI1RuntimeProbe.ps1'
$stagingRoot = 'C:\AEI1'
$signedRoot = Join-Path $stagingRoot 's'
$partialSigned = Join-Path $stagingRoot 'sp'
$ready = Join-Path $signedRoot ($requestId + '.ready')
$finalRoot = Join-Path $root 'final_o3ei1'
$partialFinal = Join-Path $stagingRoot 'f'
$zipName = $requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$packageGatePath = Join-Path $root 'O3EI1_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

$entrypointSha = 'B7453E74C1DF80DB4BAAA5F398870B6C5C99A71959EAD4C8F038B9A4B3812CAA'
$providerSha = 'C4BCE3DBC9ABF91E99AE1E1DEB971EEB60610C2A117E645B5903EC4BAD744E8D'
$definitionSha = '47E728969D9A507BF0481F270535D7C52B57A8F77416EED781717E3A373F143C'
$entrypointGateSha = '38F5608758D083D9F0951F3F53E6B5AA109685F26A064A3BC55BF315574395FF'
$recoveryIntentSha = '662F73AC13ACB607997A4EF48ED917DE85A8C95C0DFF61B16AF7363BA2CDDE52'
Assert-Pin $entrypointPath $entrypointSha
Assert-Pin $providerPath $providerSha
Assert-Pin $definitionPath $definitionSha
Assert-Pin (Join-Path $root 'O3EI1_ENTRYPOINT_GATE.json') $entrypointGateSha 'PASS_O3EI1_ENTRYPOINT_GATE'
Assert-Pin (Join-Path $root 'O3EI1_RECOVERY_INTENT.json') $recoveryIntentSha
Assert-Pin (Join-Path $project 'work\OPENCV_SCRIBE_O2D23\O2D23_COMPLETE_ROUTE_GATE_R3.json') '04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3' 'PASS_O2D23_COMPLETE_ROUTE_GATE'
Assert-Pin (Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json') '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL'

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
if ([string]$definition.targetRole -ne 'JBOD' -or [string]$definition.jobClass -ne 'MAINTENANCE_PATCH' -or [string]$definition.entryPoint -ne 'payload/Invoke-O3EI1RuntimeCapability.ps1' -or @($definition.changes).Count -ne 1 -or @($definition.entryPointMutations).Count -ne 0 -or @($definition.entryPointOutputs).Count -ne 1 -or @($definition.allowedTaskActions).Count -ne 0 -or @($definition.allowedProcessActions).Count -ne 2 -or -not [bool]$definition.reviewOnly -or [bool]$definition.productionRoutingEnabled) { throw 'O3EI1 maintenance definition contract changed.' }
$change = $definition.changes[0]
if ([string]$change.source -ne 'payload/Invoke-O3EI1RuntimeProbe.ps1' -or [string]$change.destination -ne 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Invoke-O3EI1RuntimeProbe.ps1' -or [string]$change.installedSha256 -ne $providerSha -or @($change.approvedPredecessorSha256).Count -ne 1 -or @($change.approvedPredecessorSha256) -notcontains $providerSha -or -not [bool]$change.allowCreate) { throw 'O3EI1 install contract changed.' }
$runtimeContract = $definition.runtimeQueryContract
if ([string]$runtimeContract.pythonExecutable -ne 'D:/AFCV1/rt/python.exe' -or [string]$runtimeContract.pythonExecutableSha256 -ne '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1' -or [string]$runtimeContract.installationManifestSha256 -ne '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596' -or -not [bool]$runtimeContract.externallyEnforcedTimeout -or -not [bool]$runtimeContract.timeoutCleanupOwnershipPinned -or [bool]$runtimeContract.imageBytesReadAllowed -or [bool]$runtimeContract.existingProcessActionAllowed -or [bool]$runtimeContract.taskActionAllowed) { throw 'O3EI1 runtime query contract changed.' }

foreach ($path in @($stagingRoot, $signedRoot, $partialSigned, $finalRoot, $partialFinal, $packageGatePath)) { if (Test-Path -LiteralPath $path) { throw "O3EI1 fresh output already exists: $path" } }
$planned = @($ready, (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig'), (Join-Path $ready 'payload\Invoke-O3EI1RuntimeCapability.ps1'), (Join-Path $ready 'payload\Invoke-O3EI1RuntimeProbe.ps1'), $zipPath, (Join-Path $partialFinal 'extract\payload\Invoke-O3EI1RuntimeCapability.ps1'), (Join-Path $partialFinal 'extract\payload\Invoke-O3EI1RuntimeProbe.ps1'), $packageGatePath)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw 'O3EI1 package path gate failed.' }

if ($Preflight) {
    [ordered]@{schema='argos_o3ei1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_BUILD_PREFLIGHT';requestId=$requestId;entrypointSha256=$entrypointSha;providerSha256=$providerSha;definitionSha256=$definitionSha;recoveryIntentSha256=$recoveryIntentSha;pathState=[string]$pathGate.state;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try { $certificateMatches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint }); if ($certificateMatches.Count -ne 1) { throw 'O3EI1 signer certificate cardinality changed.' }; $certificate = $certificateMatches[0] }
finally { $store.Close(); $store.Dispose() }
if (-not $certificate.HasPrivateKey) { throw 'O3EI1 signer private key is unavailable.' }
$files = @(
    [ordered]@{source=$entrypointPath;path='payload/Invoke-O3EI1RuntimeCapability.ps1';bytes=(Get-Item -LiteralPath $entrypointPath).Length;sha256=$entrypointSha},
    [ordered]@{source=$providerPath;path='payload/Invoke-O3EI1RuntimeProbe.ps1';bytes=(Get-Item -LiteralPath $providerPath).Length;sha256=$providerSha}
)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files|ForEach-Object{[ordered]@{path=$_.path;bytes=[int64]$_.bytes;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@();entryPointOutputs=@($definition.entryPointOutputs);runtimeQueryContract=$definition.runtimeQueryContract;allowedTaskActions=@();allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal
}
$partialReady = Join-Path $partialSigned ($requestId + '.ready')
[void](New-Item -ItemType Directory -Path (Join-Path $partialReady 'payload'))
foreach ($file in $files) { Copy-Item -LiteralPath $file.source -Destination (Join-Path $partialReady $file.path.Replace('/', '\')) }
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
Move-Item -LiteralPath $partialReady -Destination $ready
Remove-Item -LiteralPath $partialSigned -Force
$packageTest = & $packageTester -PackagePath $ready -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if ([string]$packageTest.State -ne 'PASS_SIGNED_PORTAL_PACKAGE') { throw 'O3EI1 signed package verification failed.' }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $partialFinal)
$partialZip = Join-Path $partialFinal $zipName
$extract = Join-Path $partialFinal 'extract'
[IO.Compression.ZipFile]::CreateFromDirectory($ready, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extract)
$expected = @{'payload/Invoke-O3EI1RuntimeCapability.ps1'=$entrypointSha;'payload/Invoke-O3EI1RuntimeProbe.ps1'=$providerSha;'PORTAL_REQUEST_MANIFEST.json'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Get-Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted = @(Get-ChildItem -LiteralPath $extract -Recurse -File)
if ($extracted.Count -ne 4) { throw 'O3EI1 final ZIP file count changed.' }
foreach ($item in $expected.GetEnumerator()) { $path = Join-Path $extract $item.Key.Replace('/', '\'); if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Sha $path) -ne [string]$item.Value) { throw "O3EI1 final ZIP file changed: $($item.Key)" } }
foreach ($payload in @('payload\Invoke-O3EI1RuntimeCapability.ps1','payload\Invoke-O3EI1RuntimeProbe.ps1')) { $tokens=$null; $errors=$null; [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $extract $payload),[ref]$tokens,[ref]$errors); if (@($errors).Count -ne 0) { throw "O3EI1 extracted payload parser failed: $payload" } }
$zipSha = Get-Sha $partialZip
$gate = [ordered]@{schema='argos_o3ei1_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_FINAL_PACKAGE_GATE';requestId=$requestId;requestZip=('work/OPENCV_EDGE_NOTCH_O3EI1/final_o3ei1/'+$zipName);requestZipBytes=(Get-Item -LiteralPath $partialZip).Length;requestZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=$definitionSha;entrypointSha256=$entrypointSha;providerSha256=$providerSha;providerInstalledDestination='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Invoke-O3EI1RuntimeProbe.ps1';maintenanceInstalledShaMatchesPayload=$true;entrypointGateSha256=$entrypointGateSha;recoveryIntentSha256=$recoveryIntentSha;inheritedCompleteRouteGateSha256='04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3';inheritedQueueGateSha256='170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D';exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;windowsPowerShell51ParserPassedForPayloadScripts=2;externallyEnforcedTimeoutRehearsalPassed=$true;ownedChildCleanupRehearsalPassed=$true;shortLocalStagingRoot=$stagingRoot;sourceImageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;protectedProcessorTouched=$false;currentWaferAborted=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;publicationAuthorized=$false;publicationRequiresCompleteRouteGate=$true}
[void](New-Item -ItemType Directory -Path $finalRoot)
Move-Item -LiteralPath $partialZip -Destination $zipPath
if ((Get-Sha $zipPath) -ne $zipSha) { throw 'O3EI1 final ZIP move changed bytes.' }
[IO.File]::WriteAllText((Join-Path $finalRoot ($zipName + '.gate.json')), (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
$resolvedStaging = [IO.Path]::GetFullPath($stagingRoot).TrimEnd('\')
if (-not $resolvedStaging.Equals('C:\AEI1', [StringComparison]::OrdinalIgnoreCase)) { throw 'O3EI1 staging cleanup target changed.' }
[IO.Directory]::Delete($resolvedStaging, $true)
[IO.File]::WriteAllText($packageGatePath, (($gate | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
$gate | ConvertTo-Json -Depth 10
