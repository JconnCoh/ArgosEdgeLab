#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Build) { throw 'Specify exactly one of -Preflight or -Build.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Resolve-ProjectFile([string]$ProjectRoot, [string]$RelativePath, [string]$Label) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) "$Label path is empty."
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "$Label path must be project-relative: $RelativePath"
    $normalized = $RelativePath.Replace('/', '\')
    Assert-True ($normalized -notmatch '(^|\\)\.\.(\\|$)') "$Label path traverses outside the project: $RelativePath"
    $projectPrefix = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $normalized))
    Assert-True ($full.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) "$Label path escapes the project: $RelativePath"
    return $full
}

function Assert-PinnedFile([string]$Path, [string]$ExpectedSha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $ExpectedSha256.ToUpperInvariant()) "$Label hash changed: $Path"
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Get-SafePackageChild([string]$Root, [string]$RelativePath) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'Package-relative path is empty.'
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "Package path is rooted: $RelativePath"
    $normalized = $RelativePath.Replace('/', '\')
    Assert-True ($normalized -notmatch '(^|\\)\.\.(\\|$)') "Package path traverses outside package: $RelativePath"
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $Root $normalized))
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "Package path escapes package: $RelativePath"
    return $full
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'R13B build invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_r13b_build_invocation_v1') 'R13B build invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260902T204408092Z_R13B') 'R13B build request identity changed.'
Assert-True ([string]$invocation.requiredBranch -eq 'codex/opencv-scribe-deciphering') 'R13B build branch changed.'
Assert-True ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.automaticIdentityAuthority -and -not [bool]$invocation.authority.trainingEligible -and -not [bool]$invocation.authority.xmlEligible -and -not [bool]$invocation.authority.productionEligible -and -not [bool]$invocation.authority.productionRoutingEnabled -and -not [bool]$invocation.authority.providerActivationAllowed) 'R13B build authority widened.'
Assert-True ([int]$invocation.authority.maximumPublications -eq 1 -and -not [bool]$invocation.authority.retryAuthorized) 'R13B publication count or retry boundary changed.'
Assert-True ((Get-Sha256 $MyInvocation.MyCommand.Path) -eq [string]$invocation.builderSha256) 'R13B builder self-pin changed.'

$contractPath = Resolve-ProjectFile $project ([string]$invocation.requestContract.path) 'request contract'
$definitionPath = Resolve-ProjectFile $project ([string]$invocation.maintenanceDefinition.path) 'maintenance definition'
Assert-PinnedFile $contractPath ([string]$invocation.requestContract.sha256) 'R13B request contract'
Assert-PinnedFile $definitionPath ([string]$invocation.maintenanceDefinition.sha256) 'R13B maintenance definition'
$contract = Get-Content -Raw -LiteralPath $contractPath | ConvertFrom-Json
$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Assert-True ([string]$contract.requestId -eq [string]$invocation.requestId -and [string]$contract.classification -match '^FROZEN') 'R13B request contract is not the frozen request.'
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH') 'R13B maintenance route changed.'
Assert-True ([string]$definition.entryPoint -eq [string]$invocation.entryPoint) 'R13B maintenance entrypoint changed.'
Assert-True ([int64]$definition.maxResultBytes -eq 16777216) 'R13B maximum portal result bytes changed.'

$payloadRows = @($invocation.payloads)
Assert-True ($payloadRows.Count -eq 7) 'R13B payload cardinality changed.'
$payloadFiles = New-Object Collections.Generic.List[object]
$seenPackagePaths = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($row in $payloadRows) {
    $source = Resolve-ProjectFile $project ([string]$row.sourcePath) 'payload source'
    Assert-PinnedFile $source ([string]$row.sha256) 'R13B payload'
    $packagePath = ([string]$row.packagePath).Replace('\', '/')
    Assert-True ($packagePath -match '^payload/[A-Za-z0-9._-]+$') "R13B payload package path is not a single safe leaf: $packagePath"
    Assert-True ($packagePath -notmatch '(?i)(__pycache__|\.pyc$)') "R13B cache bytecode is forbidden: $packagePath"
    Assert-True ($seenPackagePaths.Add($packagePath)) "R13B duplicate payload package path: $packagePath"
    $payloadFiles.Add([ordered]@{source=$source;path=$packagePath;bytes=[int64](Get-Item -LiteralPath $source).Length;sha256=([string]$row.sha256).ToUpperInvariant()})
}
Assert-True ($seenPackagePaths.Contains([string]$definition.entryPoint)) 'R13B entrypoint is not one exact payload.'

$endpointRow = @($payloadRows | Where-Object { ([string]$_.packagePath).Replace('\','/') -eq [string]$definition.entryPoint })
Assert-True ($endpointRow.Count -eq 1) 'R13B endpoint payload cardinality changed.'
Assert-True (@($definition.changes).Count -eq 1) 'R13B maintenance change cardinality changed.'
$change = $definition.changes[0]
Assert-True ([string]$change.source -eq [string]$definition.entryPoint -and [string]$change.destination -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R13B.ps1') 'R13B installed endpoint identity changed.'
Assert-True ([bool]$change.allowCreate -and [string]$change.installedSha256 -eq [string]$endpointRow[0].sha256) 'R13B installed endpoint hash does not match payload.'
Assert-True (@($change.approvedPredecessorSha256).Count -eq 1 -and [string]$change.approvedPredecessorSha256[0] -eq '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740') 'R13B approved installed predecessor changed.'
Assert-True (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'R13B task/process action boundary changed.'
Assert-True ([int]$definition.timeoutContract.maximumSequentialChildren -eq 4 -and [int]$definition.timeoutContract.maximumConcurrentChildren -eq 1 -and [int]$definition.timeoutContract.opencvChildTimeoutSeconds -eq 600 -and [int]$definition.timeoutContract.endpointWorkerOuterTimeoutSeconds -eq 3000) 'R13B timeout contract changed.'
Assert-True ([int]$definition.timeoutContract.endpointWorkerOuterTimeoutSeconds -gt ([int]$definition.timeoutContract.maximumSequentialChildren * [int]$definition.timeoutContract.opencvChildTimeoutSeconds)) 'R13B outer timeout does not cover all serialized children.'
Assert-True (-not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed -and -not [bool]$definition.sourceProcessingContract.holdClearanceAllowed -and -not [bool]$definition.sourceProcessingContract.providerActivationAllowed -and -not [bool]$definition.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$definition.sourceProcessingContract.fullSourceImageReturnAllowed) 'R13B source-processing authority widened.'

$requiredGateEvidence = New-Object Collections.Generic.List[object]
foreach ($gatePin in @($invocation.requiredGates)) {
    $gatePath = Resolve-ProjectFile $project ([string]$gatePin.path) 'required gate'
    Assert-PinnedFile $gatePath ([string]$gatePin.sha256) 'R13B required gate'
    $gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json
    $propertyName = [string]$gatePin.stateProperty
    Assert-True ($gate.PSObject.Properties.Name -contains $propertyName) "R13B gate state property is absent: $propertyName"
    Assert-True ([string]$gate.$propertyName -eq [string]$gatePin.requiredState) "R13B required gate state changed: $($gatePin.path)"
    $requiredGateEvidence.Add([ordered]@{path=[string]$gatePin.path;sha256=([string]$gatePin.sha256).ToUpperInvariant();stateProperty=$propertyName;requiredState=[string]$gatePin.requiredState})
}
$routeGatePins = @($requiredGateEvidence.ToArray() | Where-Object { [string]$_.requiredState -eq 'PASS_R13B_COMPLETE_ROUTE_GATE' })
Assert-True ($routeGatePins.Count -eq 1) 'R13B build requires exactly one complete route gate pin.'

$identityPath = Resolve-ProjectFile $project ([string]$invocation.signing.identityPath) 'signing identity'
$publicCertificatePath = Resolve-ProjectFile $project ([string]$invocation.signing.publicCertificatePath) 'public certificate'
$packageTesterPath = Resolve-ProjectFile $project ([string]$invocation.signing.packageTesterPath) 'package tester'
Assert-PinnedFile $identityPath ([string]$invocation.signing.identitySha256) 'R13B signing identity'
Assert-PinnedFile $publicCertificatePath ([string]$invocation.signing.publicCertificateSha256) 'R13B public certificate'
Assert-PinnedFile $packageTesterPath ([string]$invocation.signing.packageTesterSha256) 'R13B package tester'
$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
Assert-True ($thumbprint -eq ([string]$invocation.signing.expectedThumbprint).Replace(' ', '').ToUpperInvariant()) 'R13B laptop signing thumbprint changed.'

$signedRoot = Resolve-ProjectFile $project ([string]$invocation.outputs.signedRoot) 'signed root'
$signedPartial = $signedRoot + '.partial'
$readyRoot = Join-Path $signedRoot ([string]$invocation.requestId + '.ready')
$partialReady = Join-Path $signedPartial ([string]$invocation.requestId + '.ready')
$finalRoot = Resolve-ProjectFile $project ([string]$invocation.outputs.finalRoot) 'final root'
$finalPartial = $finalRoot + '.partial'
$zipName = [string]$invocation.requestId + '.ready.zip'
$zipPath = Join-Path $finalRoot $zipName
$partialZip = Join-Path $finalPartial $zipName
$extractRoot = Join-Path $finalPartial 'extract'
$finalGatePath = Resolve-ProjectFile $project ([string]$invocation.outputs.finalGatePath) 'final package gate'
foreach ($path in @($signedRoot,$signedPartial,$finalRoot,$finalPartial,$finalGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R13B build create-new target exists: $path" }

$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'R13B path-budget tool is absent.'
$plannedPaths = New-Object Collections.Generic.List[string]
foreach ($path in @($partialReady,(Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'),$readyRoot,(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'),$zipPath,$finalGatePath,(Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig'))) { $plannedPaths.Add($path) }
foreach ($payload in $payloadFiles) {
    $plannedPaths.Add((Get-SafePackageChild $partialReady ([string]$payload.path)))
    $plannedPaths.Add((Get-SafePackageChild $readyRoot ([string]$payload.path)))
    $plannedPaths.Add((Get-SafePackageChild $extractRoot ([string]$payload.path)))
    $plannedPaths.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789_00000000\package\' + ([string]$payload.path).Replace('/','\')))
}
$remoteFinalLeaves = @($invocation.pathPlan.remoteFinalLeaves | ForEach-Object { [string]$_ })
Assert-True ($remoteFinalLeaves -contains 'D:\A2\w\ocv\R13B\jobs\JQ20V.json') 'R13B runtime-job route changed.'
Assert-True ($remoteFinalLeaves -contains 'C:\R13BR\R13B_RETURN.zip') 'R13B short decoded-bundle staging route changed.'
foreach ($remotePath in $remoteFinalLeaves) { $plannedPaths.Add($remotePath) }
$pathJson = & $pathTool -CandidatePath $plannedPaths.ToArray() -ReservedSuffixCharacters 32 -AsJson | Out-String
$pathGate = $pathJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R13B exact package path budget failed.'
$maximumEffectiveLength = [int]((@($pathGate.candidates) | Measure-Object effectiveLength -Maximum).Maximum)
Assert-True ($maximumEffectiveLength -lt 200) 'R13B package effective path length reached 200.'

$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $matches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ', '').ToUpperInvariant() -eq $thumbprint })
    Assert-True ($matches.Count -eq 1 -and $matches[0].HasPrivateKey) 'R13B signing certificate/private key is unavailable or ambiguous.'
    $certificate = $matches[0]
}
finally { $store.Close(); $store.Dispose() }

$preflightResult = [ordered]@{
    schema='argos_r13b_build_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_BUILD_PREFLIGHT';requestId=[string]$invocation.requestId
    invocationManifestSha256=Get-Sha256 $invocationPath;payloadFileCount=$payloadFiles.Count;maintenanceDefinitionSha256=[string]$invocation.maintenanceDefinition.sha256
    pathState=[string]$pathGate.state;pathCount=@($pathGate.candidates).Count;maximumEffectiveLength=$maximumEffectiveLength;signerThumbprint=$thumbprint
    requiredGateCount=$requiredGateEvidence.Count;completeRouteGateSha256=[string]$routeGatePins[0].sha256;finalTargetsAbsent=$true;mutationsPerformed=$false;targetExecuted=$false;maximumPublications=1;retryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 10; return }

$signedPartialCreated = $false
$finalPartialCreated = $false
try {
    [void][IO.Directory]::CreateDirectory((Join-Path $partialReady 'payload'))
    $signedPartialCreated = $true
    foreach ($payload in $payloadFiles) {
        $destination = Get-SafePackageChild $partialReady ([string]$payload.path)
        [IO.File]::Copy([string]$payload.source, $destination, $false)
        Assert-True ((Get-Sha256 $destination) -eq [string]$payload.sha256) "R13B copied payload changed: $($payload.path)"
    }
    $created = [DateTimeOffset]::UtcNow
    $manifest = [ordered]@{
        schema='argos_project_portal_request_manifest_v1';requestId=[string]$invocation.requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours([int]$invocation.expiresAfterHours).ToString('o')
        targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false
        signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=@($payloadFiles.ToArray() | ForEach-Object { [ordered]@{path=[string]$_.path;bytes=[int64]$_.bytes;sha256=[string]$_.sha256} })
        entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);entryPointOutputs=@($definition.entryPointOutputs)
        sourceProcessingContract=$definition.sourceProcessingContract;timeoutContract=$definition.timeoutContract;allowedTaskActions=@($definition.allowedTaskActions);allowedProcessActions=@($definition.allowedProcessActions);rehearsal=$definition.rehearsal
    }
    $manifestPath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.json'
    $signaturePath = Join-Path $partialReady 'PORTAL_REQUEST_MANIFEST.sig'
    $manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 40))
    [IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    try { $signatureBytes = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
    finally { $rsa.Dispose() }
    [IO.File]::WriteAllBytes($signaturePath, $signatureBytes)
    $packageTest = & $packageTesterPath -PackagePath $partialReady -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
    Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R13B signed package verification failed.'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [void][IO.Directory]::CreateDirectory($finalPartial)
    $finalPartialCreated = $true
    [IO.Compression.ZipFile]::CreateFromDirectory($partialReady, $partialZip, [IO.Compression.CompressionLevel]::Optimal, $false)
    [IO.Compression.ZipFile]::ExtractToDirectory($partialZip, $extractRoot)
    $expectedFiles = @{}
    foreach ($payload in $payloadFiles) { $expectedFiles[[string]$payload.path] = [string]$payload.sha256 }
    $expectedFiles['PORTAL_REQUEST_MANIFEST.json'] = Get-Sha256 $manifestPath
    $expectedFiles['PORTAL_REQUEST_MANIFEST.sig'] = Get-Sha256 $signaturePath
    $extractedFiles = @(Get-ChildItem -LiteralPath $extractRoot -Recurse -File | Select-Object -First ($expectedFiles.Count + 1))
    Assert-True ($extractedFiles.Count -eq $expectedFiles.Count) 'R13B final ZIP file cardinality changed.'
    foreach ($expected in $expectedFiles.GetEnumerator()) {
        $leaf = Get-SafePackageChild $extractRoot ([string]$expected.Key)
        Assert-True (Test-Path -LiteralPath $leaf -PathType Leaf) "R13B final ZIP leaf is absent: $($expected.Key)"
        Assert-True ((Get-Sha256 $leaf) -eq [string]$expected.Value) "R13B final ZIP leaf changed: $($expected.Key)"
    }
    $extractedTest = & $packageTesterPath -PackagePath $extractRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
    Assert-True ([string]$extractedTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R13B exact final ZIP signature verification failed.'

    [IO.Directory]::Move($signedPartial, $signedRoot)
    $signedPartialCreated = $false
    [IO.Directory]::Move($finalPartial, $finalRoot)
    $finalPartialCreated = $false
    Assert-True (Test-Path -LiteralPath $zipPath -PathType Leaf) 'R13B final ZIP disappeared after commit.'
    $gate = [ordered]@{
        schema='argos_r13b_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_FINAL_SIGNED_PACKAGE';classification='FROZEN_REVIEW_ONLY';requestId=[string]$invocation.requestId
        invocationManifestSha256=Get-Sha256 $invocationPath;requestZip=('work/OPENCV_SCRIBE_R13B/final/' + $zipName);requestZipBytes=[int64](Get-Item -LiteralPath $zipPath).Length;requestZipSha256=Get-Sha256 $zipPath
        requestManifestSha256=$expectedFiles['PORTAL_REQUEST_MANIFEST.json'];requestSignatureSha256=$expectedFiles['PORTAL_REQUEST_MANIFEST.sig'];maintenanceDefinitionSha256=[string]$invocation.maintenanceDefinition.sha256
        payloadFileCount=$payloadFiles.Count;payloads=@($payloadFiles.ToArray() | ForEach-Object { [ordered]@{path=[string]$_.path;bytes=[int64]$_.bytes;sha256=[string]$_.sha256} });exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true
        requiredGates=$requiredGateEvidence.ToArray();completeRouteGateSha256=[string]$routeGatePins[0].sha256;completeRoutePackageBindingPassed=$true;pathState=[string]$pathGate.state;pathCount=@($pathGate.candidates).Count;maximumEffectiveLength=$maximumEffectiveLength;maximumPublications=1;retryAuthorized=$false;publicationAuthorized=$false;targetExecuted=$false
        sourceImagesRead=$false;sourceMutationPerformed=$false;providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    }
    Write-JsonCreateNew $finalGatePath $gate 20
    $gate | ConvertTo-Json -Depth 20
}
catch {
    if ($signedPartialCreated -and (Test-Path -LiteralPath $signedPartial -PathType Container)) { [IO.Directory]::Delete($signedPartial, $true) }
    if ($finalPartialCreated -and (Test-Path -LiteralPath $finalPartial -PathType Container)) { [IO.Directory]::Delete($finalPartial, $true) }
    throw
}
