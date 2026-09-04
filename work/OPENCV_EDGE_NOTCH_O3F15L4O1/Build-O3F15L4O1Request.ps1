#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Build)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }
function Require([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-Utf8([string]$Path,[string]$Text) { [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260903T154613372Z_3D45D4C3F418'
$requestReadyName = $requestId + '.ready'
$zipName = $requestReadyName + '.zip'
$stageRoot = 'C:\O3F15L4O1PK'
$partial = Join-Path $stageRoot 'p'
$ready = Join-Path (Join-Path $stageRoot 's') $requestReadyName
$finalRoot = Join-Path $PSScriptRoot 'final_o3f15l4o1'
$finalZip = Join-Path $finalRoot $zipName
$buildGatePath = Join-Path $PSScriptRoot 'O3F15L4O1_BUILD_SIGN_GATE.json'
$routeGatePath = Join-Path $finalRoot 'O3F15L4O1_PREPUBLICATION_PATH_GATE.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_O3F15L4O1_BUILD_SIGN.json'
$entry = Join-Path $PSScriptRoot 'Invoke-O3F15L4O1GateJsonEndpoint.ps1'
$provider = Join-Path (Split-Path -Parent $PSScriptRoot) 'OPENCV_EDGE_NOTCH_O3J1\OCV03_ResultJsonProviderV1.ps1'
$config = Join-Path $PSScriptRoot 'O3F15L4O1_GATE_JSON_CONFIG.json'
$invocation = Join-Path $PSScriptRoot 'O3F15L4O1_GATE_JSON_INVOCATION.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$entryGatePath = Join-Path $PSScriptRoot 'O3F15L4O1_ENTRYPOINT_GATE.json'
$recoveryIntentPath = Join-Path $PSScriptRoot 'RECOVERY_INTENT_O3F15L4O1.json'
$inheritedRouteGatePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'OPENCV_EDGE_NOTCH_O3F15L4E1\final_o3f15l4e1\O3F15L4E1_PREPUBLICATION_PATH_R4_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$certificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$historyAudit = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'

$pins = @{
    entry = '515F7D9617FF2A404F91718C8AA384BC7251488B2D1EFB21930F201017212897'
    provider = 'EF9773ADAC624A7A8A689989AB0EE404C2863B4E32B2666F437331E8CC9CAE67'
    config = 'A4B1ACF76F1BE60506AAA9EFD61521AC87C44DB0A92AA906D5C3789EDE1CB3DB'
    invocation = '6183F6AE88E719665EC41867AD18BD80A5B7DD18604CE6A8DB374CAA3C4B0D08'
    definition = '4AC05FDBA9F85DB41EE4C0E1C827025169C8E2069AE55D690ED55FAA8E85BE86'
    entryGate = '4C05A3D0D2B30FA7875869E74824ED03FBDE1C47C7FF0940B6E3641D26EDF8AA'
    recoveryIntent = '148A30946A9385CEC1F1CF3229AA7D14441DF1C8F2A17FA147E7AA3D544FE665'
    inheritedRoute = 'C7C27F7D45265C08578C74BD644A8350DC33F6C8A2D5169321C131D1241A7BED'
}
$pinPaths = @{entry=$entry;provider=$provider;config=$config;invocation=$invocation;definition=$definitionPath;entryGate=$entryGatePath;recoveryIntent=$recoveryIntentPath;inheritedRoute=$inheritedRouteGatePath}
foreach ($name in $pinPaths.Keys) { Require (Test-Path -LiteralPath $pinPaths[$name] -PathType Leaf) "O3F15L4O1 dependency absent: $name"; Require ((Sha $pinPaths[$name]) -eq $pins[$name]) "O3F15L4O1 dependency changed: $name" }
Require (Test-Path -LiteralPath $preactionPath -PathType Leaf) 'O3F15L4O1 build preaction is absent.'
& $preactionTool -ContractPath $preactionPath -AuditPath $historyAudit -ProjectRoot $project -Preflight | Out-Null
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Require ([string]$definition.state -eq 'FROZEN_FOR_SIGNING' -and [string]$definition.entryPoint -eq 'payload/Invoke-O3F15L4O1GateJsonEndpoint.ps1') 'O3F15L4O1 definition changed.'
Require (@($definition.changes).Count -eq 2 -and @($definition.entryPointMutations).Count -eq 0 -and @($definition.entryPointOutputs).Count -eq 0) 'O3F15L4O1 change/output cardinality changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 0 -and -not [bool]$definition.requestRetryAuthorized) 'O3F15L4O1 authority widened.'

$files = @(
    [pscustomobject]@{source=$entry;path='payload/Invoke-O3F15L4O1GateJsonEndpoint.ps1';sha256=$pins.entry},
    [pscustomobject]@{source=$provider;path='payload/OCV03_ResultJsonProviderV1.ps1';sha256=$pins.provider},
    [pscustomobject]@{source=$config;path='payload/O3F15L4O1_GATE_JSON_CONFIG.json';sha256=$pins.config},
    [pscustomobject]@{source=$invocation;path='payload/O3F15L4O1_GATE_JSON_INVOCATION.json';sha256=$pins.invocation}
)
$planned = @($stageRoot,$ready,$finalRoot,$finalZip,$buildGatePath,$routeGatePath)
foreach ($file in $files) { $planned += Join-Path $ready $file.path.Replace('/','\') }
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3F15L4O1 local package path gate failed.'
foreach ($path in @($stageRoot,$finalRoot,$finalZip,$buildGatePath)) { Require (-not (Test-Path -LiteralPath $path)) "O3F15L4O1 create-new target exists: $path" }
if ($Preflight) {
    [ordered]@{schema='argos_o3f15l4o1_build_preflight_v1';state='PASS_O3F15L4O1_BUILD_PREFLIGHT';requestId=$requestId;payloadFileCount=$files.Count;entrypointSha256=$pins.entry;providerSha256=$pins.provider;configurationSha256=$pins.config;invocationSha256=$pins.invocation;definitionSha256=$pins.definition;preactionSha256=Sha $preactionPath;pathState=[string]$pathGate.state;mutationsPerformed=$false;targetExecuted=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6 -Compress
    return
}

$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My',[Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try { $certs = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant() -eq $thumbprint }); Require ($certs.Count -eq 1 -and $certs[0].HasPrivateKey) 'O3F15L4O1 signer certificate is unavailable.'; $signer = $certs[0] }
finally { $store.Close(); $store.Dispose() }

$payloadRoot = Join-Path (Join-Path $partial $requestReadyName) 'payload'
[void](New-Item -ItemType Directory -Path $payloadRoot)
foreach ($file in $files) { [IO.File]::Copy($file.source,(Join-Path (Join-Path $partial $requestReadyName) $file.path.Replace('/','\')),$false) }
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($files | ForEach-Object {[ordered]@{path=$_.path;bytes=[int64](Get-Item -LiteralPath $_.source).Length;sha256=$_.sha256}});entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@();entryPointOutputs=@();jsonReadContract=$definition.jsonReadContract;allowedTaskActions=@();allowedProcessActions=@();rehearsal=$definition.rehearsal;requestRetryAuthorized=$false}
$requestRoot = Join-Path $partial $requestReadyName
$manifestPath = Join-Path $requestRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $requestRoot 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer)
try { $signature = $rsa.SignData($manifestBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath,$signature)
[void](New-Item -ItemType Directory -Path (Split-Path -Parent $ready))
Move-Item -LiteralPath $requestRoot -Destination $ready
$packageTest = & $packageTester -PackagePath $ready -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F15L4O1 signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipStage = Join-Path $stageRoot 'z'
[void](New-Item -ItemType Directory -Path $zipStage)
$partialZip = Join-Path $zipStage $zipName
[IO.Compression.ZipFile]::CreateFromDirectory($ready,$partialZip,[IO.Compression.CompressionLevel]::Optimal,$false)
$extract = Join-Path $zipStage 'x'
[IO.Compression.ZipFile]::ExtractToDirectory($partialZip,$extract)
$expected = @{'payload/Invoke-O3F15L4O1GateJsonEndpoint.ps1'=$pins.entry;'payload/OCV03_ResultJsonProviderV1.ps1'=$pins.provider;'payload/O3F15L4O1_GATE_JSON_CONFIG.json'=$pins.config;'payload/O3F15L4O1_GATE_JSON_INVOCATION.json'=$pins.invocation;'PORTAL_REQUEST_MANIFEST.json'=Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.json');'PORTAL_REQUEST_MANIFEST.sig'=Sha (Join-Path $ready 'PORTAL_REQUEST_MANIFEST.sig')}
$extracted = @(Get-ChildItem -LiteralPath $extract -Recurse -File)
Require ($extracted.Count -eq 6) 'O3F15L4O1 extracted file count changed.'
foreach ($item in $expected.GetEnumerator()) { $leaf = Join-Path $extract $item.Key.Replace('/','\'); Require (Test-Path -LiteralPath $leaf -PathType Leaf) "O3F15L4O1 extracted leaf absent: $($item.Key)"; Require ((Sha $leaf) -eq [string]$item.Value) "O3F15L4O1 extracted leaf changed: $($item.Key)" }
$extractedEntry = Join-Path $extract 'payload\Invoke-O3F15L4O1GateJsonEndpoint.ps1'
$extractedProvider = Join-Path $extract 'payload\OCV03_ResultJsonProviderV1.ps1'
$extractedConfig = Join-Path $extract 'payload\O3F15L4O1_GATE_JSON_CONFIG.json'
$extractedInvocation = Join-Path $extract 'payload\O3F15L4O1_GATE_JSON_INVOCATION.json'
$entryPreflight = & $extractedEntry -Preflight -ProviderPath $extractedProvider -ConfigurationPath $extractedConfig -InvocationPath $extractedInvocation -ExpectedProviderSha256 $pins.provider -ExpectedConfigurationSha256 $pins.config -ExpectedInvocationSha256 $pins.invocation | ConvertFrom-Json
Require ([string]$entryPreflight.state -eq 'PASS_O3F15L4O1_ENTRYPOINT_PREFLIGHT') 'O3F15L4O1 extracted entrypoint preflight failed.'

$zipSha = Sha $partialZip
[void](New-Item -ItemType Directory -Path $finalRoot)
[IO.File]::Copy($partialZip,$finalZip,$false)
Require ((Sha $finalZip) -eq $zipSha) 'O3F15L4O1 final ZIP changed.'

$inherited = Get-Content -LiteralPath $inheritedRouteGatePath -Raw | ConvertFrom-Json
$oldRequestId = [string]$inherited.requestId
$routeItems = New-Object Collections.Generic.List[object]
$requestLeafNames = @($files.path) + @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig')
foreach ($row in @($inherited.routePaths)) {
    $stage = [string]$row.stage
    if ($stage -match '^pinned_target_' -or $stage -match '^laptop_' -or $stage -in @('jbod_carrier_restore','jbod_carrier_stage','jbod_same_bytes_carrier')) { continue }
    $path = [string]$row.path
    if ($path.Contains($oldRequestId) -and $path -match '[\\/]payload[\\/]') {
        $markerIndex = $path.IndexOf('\payload\',[StringComparison]::OrdinalIgnoreCase)
        $separator = '\'
        if ($markerIndex -lt 0) { $markerIndex = $path.IndexOf('/payload/',[StringComparison]::OrdinalIgnoreCase); $separator = '/' }
        $prefix = $path.Substring(0,$markerIndex + 9).Replace($oldRequestId,$requestId)
        foreach ($leafName in @($files.path | ForEach-Object { ($_ -split '/')[1] })) { $routeItems.Add([pscustomobject]@{stage=$stage;path=$prefix+$leafName}) }
    } else {
        $routeItems.Add([pscustomobject]@{stage=$stage;path=$path.Replace($oldRequestId,$requestId)})
    }
}
$routeItems.Add([pscustomobject]@{stage='pinned_target_gate-summary';path='D:\O3F15L4G\SUMMARY.json'})
$routeItems.Add([pscustomobject]@{stage='jbod_same_bytes_carrier';path='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_ResultJsonProviderV1.ps1'})
$routeItems.Add([pscustomobject]@{stage='jbod_config_install';path='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_O3F15L4_GATE_JSON_CONFIG.json'})
foreach ($path in @($finalZip,$routeGatePath,$buildGatePath,(Join-Path $stageRoot 'response.partial\PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $stageRoot 'response.ready\PORTAL_RESPONSE_MANIFEST.json'))) { $routeItems.Add([pscustomobject]@{stage='laptop_local';path=$path}) }
$uniqueRouteItems = @($routeItems | Sort-Object stage,path -Unique)
$routePathGate = & $pathTool -CandidatePath @($uniqueRouteItems.path) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$routePathGate.state -eq 'PASS_PATH_BUDGET') 'O3F15L4O1 complete route path gate failed.'
$longest = @($routePathGate.candidates | Sort-Object effectiveLength -Descending)[0]
$routeGate = [ordered]@{schema='argos_ocv03_o3f15l4o1_prepublication_path_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4O1_PREPUBLICATION_PATH_GATE';requestId=$requestId;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];signedPackageZipSha256=$zipSha;installedRouteConfigRevisionSha256=[string]$inherited.installedRouteConfigRevisionSha256;endpointWorkerSha256=[string]$inherited.endpointWorkerSha256;queueSafetyGateSha256=[string]$inherited.queueSafetyGateSha256;suffixReserve=32;requestPayloadFileCount=$files.Count;longestRelativeRequestLeaf=(@($requestLeafNames | Sort-Object Length -Descending)[0]);maximumResponseResultBytes=8388608;evaluatedPathCount=$uniqueRouteItems.Count;maximumEffectiveLength=[int]$longest.effectiveLength;maximumComponentLength=[int](($routePathGate.candidates | Measure-Object maximumComponentLength -Maximum).Maximum);longestPath=[string]$longest.path;routePaths=$uniqueRouteItems;pathDisposition='PASS';publicationCountMaximum=1;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;requestRetryAuthorized=$false;rustDeskAllowed=$false;operatorInputRequired=$false;sourceImageBytesRead=$false;sourceMutationOrDeletionAuthorized=$false;existingTaskOrProcessActionAuthorized=$false;providerActivationAuthorized=$false;automaticHoldClearanceAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mutationsPerformed=$false}
Write-Utf8 $routeGatePath (($routeGate | ConvertTo-Json -Depth 12) + [Environment]::NewLine)
$buildGate = [ordered]@{schema='argos_o3f15l4o1_build_sign_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4O1_SIGNED_REQUEST_READY';requestId=$requestId;packageZipPath=('work/OPENCV_EDGE_NOTCH_O3F15L4O1/final_o3f15l4o1/'+$zipName);packageZipBytes=[int64](Get-Item -LiteralPath $finalZip).Length;packageZipSha256=$zipSha;requestManifestSha256=$expected['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expected['PORTAL_REQUEST_MANIFEST.sig'];payloadFileCount=$files.Count;entrypointSha256=$pins.entry;providerSha256=$pins.provider;configurationSha256=$pins.config;invocationSha256=$pins.invocation;definitionSha256=$pins.definition;entrypointGateSha256=$pins.entryGate;recoveryIntentSha256=$pins.recoveryIntent;routeGateSha256=Sha $routeGatePath;exactFinalZipExtractionPassed=$true;exactFinalZipPayloadHashesPassed=$true;exactPackageSignaturePassed=$true;extractedEntrypointPreflightPassed=$true;signed=$true;published=$false;targetExecuted=$false;requestRetryAuthorized=$false;taskOrProcessActionAuthorized=$false;sourceMutationAuthorized=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-Utf8 $buildGatePath (($buildGate | ConvertTo-Json -Depth 8) + [Environment]::NewLine)
[IO.Directory]::Delete($stageRoot,$true)
$buildGate | ConvertTo-Json -Depth 8
