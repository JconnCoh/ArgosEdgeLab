#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }
function Assert-O3F10([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F10Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F10Json([string]$Path, [object]$Value) { Assert-O3F10 (-not (Test-Path -LiteralPath $Path)) "O3F10 create-new JSON exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F10_PACKAGE_SPEC.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
foreach ($path in @($specPath, $definitionPath)) { Assert-O3F10 (Test-Path -LiteralPath $path -PathType Leaf) "O3F10 package dependency is absent: $path" }
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Assert-O3F10 ([string]$spec.schema -eq 'argos_ocv03_o3f10_package_spec_v1' -and [string]$spec.requestId -eq 'REQ_O3F10_20260902A') 'O3F10 package identity changed.'
Assert-O3F10 ([string]$definition.entryPoint -eq [string]$spec.entryPoint -and @($definition.changes).Count -eq 1 -and @($definition.allowedTaskActions).Count -eq 0) 'O3F10 maintenance contract changed.'
Assert-O3F10 ([bool]$spec.reviewOnly -and -not [bool]$spec.productionRoutingEnabled -and -not [bool]$spec.requestRetryAuthorized) 'O3F10 package authority widened.'

$sourceRows = New-Object Collections.Generic.List[object]
$endpointSource = Join-Path $project ([string]$spec.endpointSource)
$runnerSource = Join-Path $project ([string]$spec.runnerSource)
$candidateRows = @(
    [pscustomobject]@{role='endpoint';source=$endpointSource;path='Invoke-O3F10StagedEndpoint.ps1';expected=''},
    [pscustomobject]@{role='runner';source=$runnerSource;path='Run-O3F9Staged.py';expected=''}
)
foreach ($row in @($spec.payloadSources)) {
    $expected = ''
    if ($null -ne $row.PSObject.Properties['sha256']) { $expected = [string]$row.sha256 }
    $candidateRows += [pscustomobject]@{role=[string]$row.role;source=(Join-Path $project ([string]$row.source));path=[string]$row.path;expected=$expected}
}
foreach ($row in $candidateRows) {
    Assert-O3F10 (Test-Path -LiteralPath $row.source -PathType Leaf) "O3F10 payload source is absent: $($row.source)"
    $hash = Get-O3F10Hash $row.source
    if (-not [string]::IsNullOrWhiteSpace([string]$row.expected)) { Assert-O3F10 ($hash -eq [string]$row.expected) "O3F10 inherited payload hash changed: $($row.source)" }
    $sourceRows.Add([pscustomobject]@{role=[string]$row.role;source=[string]$row.source;path=[string]$row.path;bytes=[int64](Get-Item -LiteralPath $row.source).Length;sha256=$hash})
}
$sources = $sourceRows.ToArray()
Assert-O3F10 ($sources.Count -eq 12 -and @($sources.role | Sort-Object -Unique).Count -eq 12 -and @($sources.path | Sort-Object -Unique).Count -eq 12) 'O3F10 payload source cardinality changed.'

$stageRoot = [IO.Path]::GetFullPath([string]$spec.stageRoot)
Assert-O3F10 ($stageRoot -eq 'C:\A10F') 'O3F10 staging root changed.'
$payloadRoot = Join-Path $stageRoot 'p'
$requestPartial = Join-Path $stageRoot (([string]$spec.requestId) + '.partial')
$requestReady = Join-Path $stageRoot ([string]$spec.requestReadyName)
$finalRoot = Join-Path $project ([string]$spec.finalRoot)
$finalZip = Join-Path $finalRoot (([string]$spec.requestReadyName) + '.zip')
$finalGate = Join-Path $PSScriptRoot 'O3F10_FINAL_PACKAGE_GATE.json'
foreach ($path in @($stageRoot, $requestPartial, $requestReady, $finalRoot, $finalZip, $finalGate)) { Assert-O3F10 (-not (Test-Path -LiteralPath $path)) "O3F10 create-new build target exists: $path" }
$planned = @($stageRoot, $requestPartial, $requestReady, (Join-Path $requestReady 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $requestReady 'payload\Run-O3F9Staged.py'), $finalRoot, $finalZip, $finalGate, [string]$spec.gateOutputRoot, [string]$spec.dev6OutputRoot)
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-O3F10 ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3F10 build path gate failed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f10_build_preflight_v1'
        state = 'PASS_O3F10_BUILD_PREFLIGHT'
        requestId = [string]$spec.requestId
        payloadSourceCount = $sources.Count
        payloadSources = @($sources | ForEach-Object { [ordered]@{role=$_.role;path=$_.path;bytes=$_.bytes;sha256=$_.sha256} })
        endpointInvocationGeneratedAtBuild = $true
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        packageSigned = $false
        publicationCount = 0
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 10
    return
}

Assert-O3F10 ([string]$spec.state -eq 'FROZEN_FOR_BUILD' -and [string]$definition.state -eq 'FROZEN_FOR_BUILD') 'O3F10 draft spec/definition must be frozen only after all gates pass.'
[void](New-Item -ItemType Directory -Path $payloadRoot)
foreach ($row in $sources) { Copy-Item -LiteralPath $row.source -Destination (Join-Path $payloadRoot $row.path) }
$endpointRow = @($sources | Where-Object { $_.role -eq 'endpoint' })[0]
$invocationFiles = @($sources | Where-Object { $_.role -ne 'endpoint' } | ForEach-Object { [ordered]@{role=$_.role;path=$_.path;bytes=$_.bytes;sha256=$_.sha256} })
$liveInvocation = [ordered]@{
    schema='argos_ocv03_o3f10_endpoint_invocation_v1';state='FROZEN_LIVE_CONTRACT';revision=[string]$spec.revision;expectedComputerName=[string]$spec.expectedComputerName;payloadRoot='';endpointSha256=[string]$endpointRow.sha256;files=$invocationFiles;runtimePath=[string]$spec.runtimePath;runtimeSha256=[string]$spec.runtimeSha256;gateOutputRoot=[string]$spec.gateOutputRoot;dev6OutputRoot=[string]$spec.dev6OutputRoot;expectedSelfTestState=[string]$spec.expectedSelfTestState;expectedPreflightState=[string]$spec.expectedPreflightState;expectedGateState=[string]$spec.expectedGateState;expectedDev6State=[string]$spec.expectedDev6State;selfTestTimeoutSeconds=[int]$spec.timeouts.selfTestSeconds;preflightTimeoutSeconds=[int]$spec.timeouts.preflightSeconds;gateTimeoutSeconds=[int]$spec.timeouts.gateSeconds;dev6TimeoutSeconds=[int]$spec.timeouts.dev6Seconds;maximumChildOutputBytes=[int]$spec.maximumChildOutputBytes;maximumTerminalOutputBytes=[int]$spec.maximumTerminalOutputBytes;detectorDevelopmentAuthorized=$true;taskOrExistingProcessActionAuthorized=$false;sourceMutationAuthorized=$false;sourceDeletionAuthorized=$false;providerActivationAuthorized=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
$invocationPath = Join-Path $payloadRoot 'O3F10_ENDPOINT_LIVE_INVOCATION.json'
Write-O3F10Json $invocationPath $liveInvocation
[void](New-Item -ItemType Directory -Path (Join-Path $requestPartial 'payload'))
$stagedPayloadFiles = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name)
foreach ($stagedPayloadFile in $stagedPayloadFiles) { Copy-Item -LiteralPath $stagedPayloadFile.FullName -Destination (Join-Path $requestPartial 'payload') }
$records = @(Get-ChildItem -LiteralPath (Join-Path $requestPartial 'payload') -File | Sort-Object Name | ForEach-Object { [ordered]@{path=('payload/' + $_.Name);bytes=[int64]$_.Length;sha256=Get-O3F10Hash $_.FullName} })
Assert-O3F10 ($records.Count -eq 13) 'O3F10 staged payload count changed.'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint")
Assert-O3F10 ([bool]$certificate.HasPrivateKey) 'O3F10 signer private key is absent.'
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{schema='argos_project_portal_request_manifest_v1';requestId=[string]$spec.requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=$records;entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@();allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal;requestRetryAuthorized=$false}
$manifestPath = Join-Path $requestPartial 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $requestPartial 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
Move-Item -LiteralPath $requestPartial -Destination $requestReady
[void](New-Item -ItemType Directory -Path $finalRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zipPartial = Join-Path $stageRoot (([string]$spec.requestReadyName) + '.zip.partial')
[IO.Compression.ZipFile]::CreateFromDirectory($requestReady, $zipPartial, [IO.Compression.CompressionLevel]::Optimal, $false)
Move-Item -LiteralPath $zipPartial -Destination $finalZip
$gate = [ordered]@{schema='argos_ocv03_o3f10_final_package_gate_v1';state='PASS_O3F10_FINAL_PACKAGE_GATE';requestId=[string]$spec.requestId;requestZip=$finalZip;requestZipBytes=[int64](Get-Item -LiteralPath $finalZip).Length;requestZipSha256=Get-O3F10Hash $finalZip;requestManifestSha256=Get-O3F10Hash (Join-Path $requestReady 'PORTAL_REQUEST_MANIFEST.json');requestSignatureSha256=Get-O3F10Hash (Join-Path $requestReady 'PORTAL_REQUEST_MANIFEST.sig');endpointSha256=[string]$endpointRow.sha256;runnerSha256=[string](@($sources | Where-Object {$_.role -eq 'runner'})[0].sha256);r10Sha256=[string](@($sources | Where-Object {$_.role -eq 'r10Detector'})[0].sha256);localGateSha256=[string](@($sources | Where-Object {$_.role -eq 'localGate'})[0].sha256);payloadFileCount=13;publicationAuthorized=$false;publicationCount=0;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-O3F10Json $finalGate $gate
$gate | ConvertTo-Json -Depth 10

