#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of Preflight or Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260828T143500111Z_O3EI1R01'
$responseId = 'R_43E71FD9A091_20260828144836355_489915ba'
$sourceZip = 'U:\ProjectPortalRO\responses\R_43E71FD9A091_20260828144836355_489915ba.ready.zip'
$expectedBytes = 2945
$expectedSha256 = '5867DF273446D5CE564466F2696DD8610D359B13F276E3A59B848A09D57BBE26'
$expectedInvocationSha256 = '9CFF92632B9000FCC4090E6A597D9D868135D51864A72924ED8F0375B79417C6'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$tempRoot = 'C:\O3EI1R'
$tempZip = Join-Path $tempRoot ($responseId + '.ready.zip')
$tempExtract = Join-Path $tempRoot ($responseId + '.ready')
$collectedRoot = Join-Path $PSScriptRoot 'collected'
$archiveDir = Join-Path $collectedRoot '_transport_archive'
$archivePath = Join-Path $archiveDir ($responseId + '.ready.zip')
$extractionRoot = Join-Path $collectedRoot ($responseId + '.ready')
$collectionGatePath = Join-Path $PSScriptRoot 'O3EI1_EXACT_RESPONSE_COLLECTION_GATE.json'

function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { $stream=New-Object IO.FileStream($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read);$sha=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}finally{$sha.Dispose();$stream.Dispose()} }
function Write-JsonCreateNew([string]$Path,[object]$Value,[int]$Depth=16) { $jsonBytes=(New-Object Text.UTF8Encoding($false)).GetBytes((($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine));$stream=New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$stream.Write($jsonBytes,0,$jsonBytes.Length)}finally{$stream.Dispose()} }

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O3EI1 response invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ((Get-Sha256 $invocationPath) -eq $expectedInvocationSha256) 'O3EI1 response invocation manifest changed.'
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3ei1_exact_response_collection_invocation_v1') 'O3EI1 response invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq $requestId -and [string]$invocation.responseId -eq $responseId) 'O3EI1 response invocation identity changed.'
Assert-True ([string]$invocation.sourceZipSha256 -eq $expectedSha256 -and [int64]$invocation.sourceZipBytes -eq $expectedBytes -and [int]$invocation.maximumSourceZips -eq 1) 'O3EI1 response invocation archive pin changed.'
Assert-True ([string]$invocation.expectedSourceRole -eq 'JBOD' -and [string]$invocation.expectedEndpointState -eq 'PASS_MAINTENANCE_PATCH' -and [string]$invocation.expectedDisposition -eq 'HOLD_O3EI1_RUNTIME_VERSION_MISMATCH' -and [bool]$invocation.matchingSignedTerminalResponseOnly -and -not [bool]$invocation.requestRetryAuthorized -and -not [bool]$invocation.numericSuccessorAuthorized) 'O3EI1 response invocation authority changed.'
Assert-True ([string]$invocation.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$invocation.maximumEffectivePathLength -lt 200 -and [int]$invocation.maximumComponentLength -le 80) 'O3EI1 response invocation path evidence changed.'
Assert-True (-not [bool]$invocation.imageBytesRead -and -not [bool]$invocation.sourceHashingPerformed -and -not [bool]$invocation.sourceDeletionPerformed -and [int]$invocation.existingProcessActions -eq 0) 'O3EI1 response collection source/process boundary changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionRoutingEnabled) 'O3EI1 response collection authority widened.'
foreach ($dependency in @($sourceZip,$certificate,$verifier)) { Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O3EI1 response dependency absent: $dependency" }
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq $expectedBytes -and (Get-Sha256 $sourceZip) -eq $expectedSha256) 'O3EI1 response ZIP changed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $names = @($zip.Entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
    $expectedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
    Assert-True ($names.Count -eq $expectedNames.Count -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $names).Count -eq 0) 'O3EI1 response ZIP entry set changed.'
    $manifestEntry = $zip.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    Assert-True ($null -ne $manifestEntry -and $manifestEntry.Length -le 65536) 'O3EI1 response manifest entry is absent or unbounded.'
    $reader = New-Object IO.StreamReader($manifestEntry.Open(),[Text.Encoding]::UTF8,$true)
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose() }
}
finally { $zip.Dispose() }
Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.responseId -eq $responseId -and [string]$manifest.sourceRole -eq 'JBOD' -and [string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') 'O3EI1 response manifest identity or terminal state changed.'

if ($Preflight) {
    [ordered]@{schema='argos_o3ei1_response_collection_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_EXACT_RESPONSE_COLLECTION_PREFLIGHT';requestId=$requestId;responseId=$responseId;invocationManifestSha256=$expectedInvocationSha256;sourceZipSha256=$expectedSha256;sourceZipBytes=$expectedBytes;endpointState=[string]$manifest.state;signatureVerified=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 6
    return
}

foreach ($path in @($tempRoot,$archivePath,$extractionRoot,$collectionGatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O3EI1 create-new collection target exists: $path" }
$archiveCreated = $false
$extractionMoved = $false
$collectionGateCreated = $false
$archiveDirExisted = Test-Path -LiteralPath $archiveDir -PathType Container
try {
    [void][IO.Directory]::CreateDirectory($tempRoot)
    [IO.File]::Copy($sourceZip,$tempZip,$false)
    Assert-True ((Get-Sha256 $tempZip) -eq $expectedSha256) 'O3EI1 temporary response copy changed.'
    Expand-Archive -LiteralPath $tempZip -DestinationPath $tempExtract
    $verification = & $verifier -PackagePath $tempExtract -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.RequestId -eq $requestId -and [string]$verification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3EI1 signed response verification failed.'
    Assert-True ([string]$verification.SignerThumbprint -eq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3EI1 JBOD signer changed.'
    $stdoutPath = Join-Path $tempExtract 'MAINTENANCE.stdout.txt'
    Assert-True ((Get-Item -LiteralPath $stdoutPath).Length -le 65536) 'O3EI1 stdout exceeded its bound.'
    $endpointResult = Get-Content -Raw -LiteralPath $stdoutPath | ConvertFrom-Json
    Assert-True ([string]$endpointResult.state -eq 'PASS_O3EI1_RUNTIME_CAPABILITY' -and [string]$endpointResult.disposition -eq 'HOLD_O3EI1_RUNTIME_VERSION_MISMATCH' -and -not [bool]$endpointResult.runtimePremisePass) 'O3EI1 runtime disposition changed.'
    $probe = $endpointResult.probe
    $versions = $probe.versions
    Assert-True ([string]$probe.state -eq 'HOLD_O3EI1_RUNTIME_VERSION_MISMATCH' -and [string]$probe.pythonSha256 -eq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1' -and [string]$probe.installationSha256 -eq '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596') 'O3EI1 runtime hash premise changed.'
    Assert-True ([string]$versions.pythonVersion -eq '3.13.2' -and [string]$versions.opencvVersion -eq '5.0.0' -and [string]$versions.numpyVersion -eq '2.5.2') 'O3EI1 observed runtime versions changed.'
    Assert-True ([int]$probe.child.exitCode -eq 0 -and -not [bool]$probe.child.timedOut -and -not [bool]$probe.child.killedOnTimeout -and @($probe.taskActions).Count -eq 0 -and @($probe.existingProcessActions).Count -eq 0) 'O3EI1 child/process boundary changed.'
    Assert-True (-not [bool]$probe.imageBytesRead -and -not [bool]$probe.sourceMutationPerformed -and -not [bool]$endpointResult.protectedProcessorTouched -and @($endpointResult.taskActions).Count -eq 0 -and @($endpointResult.existingProcessActions).Count -eq 0) 'O3EI1 endpoint crossed its authority boundary.'

    [void][IO.Directory]::CreateDirectory($archiveDir)
    [IO.File]::Copy($tempZip,$archivePath,$false)
    $archiveCreated = $true
    Assert-True ((Get-Sha256 $archivePath) -eq $expectedSha256) 'O3EI1 archived response changed.'
    [IO.Directory]::Move($tempExtract,$extractionRoot)
    $extractionMoved = $true
    $finalVerification = & $verifier -PackagePath $extractionRoot -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId
    Assert-True ([string]$finalVerification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$finalVerification.EndpointState -eq 'PASS_MAINTENANCE_PATCH') 'O3EI1 final collected response verification failed.'
    $result = [ordered]@{schema='argos_o3ei1_exact_response_collection_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3EI1_EXACT_SIGNED_TERMINAL_RESPONSE_COLLECTED';disposition='HOLD_O3EI1_RUNTIME_VERSION_MISMATCH';requestId=$requestId;responseId=$responseId;invocationManifestSha256=$expectedInvocationSha256;responseZipBytes=$expectedBytes;responseZipSha256=$expectedSha256;archivePath=$archivePath;extractionRoot=$extractionRoot;endpointState=[string]$finalVerification.EndpointState;sourceRole=[string]$finalVerification.SourceRole;signerThumbprint=[string]$finalVerification.SignerThumbprint;signedFileCount=[int]$finalVerification.Files;signatureVerified=$true;endpointResultState=[string]$endpointResult.state;runtimePremisePass=$false;pythonVersion=[string]$versions.pythonVersion;opencvVersion=[string]$versions.opencvVersion;numpyVersion=[string]$versions.numpyVersion;expectedOpenCvVersion=[string]$probe.expectedOpenCvVersion;expectedNumpyVersion=[string]$probe.expectedNumpyVersion;pythonSha256=[string]$probe.pythonSha256;installationSha256=[string]$probe.installationSha256;ownedChildPid=[int]$probe.child.pid;ownedChildExitCode=[int]$probe.child.exitCode;ownedChildTimedOut=[bool]$probe.child.timedOut;ownedChildKilledOnTimeout=[bool]$probe.child.killedOnTimeout;capabilityOutputPath=[string]$endpointResult.capabilityOutputPath;capabilityOutputSha256=[string]$endpointResult.capabilityOutputSha256;capabilityOutputBytes=[int64]$endpointResult.capabilityOutputBytes;temporaryCDriveRootRemoved=$true;requestRetryAuthorized=$false;numericSuccessorAuthorized=$false;imageBytesRead=$false;sourceHashingPerformed=$false;sourceDeletionPerformed=$false;inspectionTasksChanged=$false;existingProcessActions=0;healthyProcessorTouched=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionRoutingEnabled=$false}
    Write-JsonCreateNew -Path $collectionGatePath -Value $result -Depth 10
    $collectionGateCreated = $true
    $result | ConvertTo-Json -Depth 10
}
catch {
    if ($collectionGateCreated -and (Test-Path -LiteralPath $collectionGatePath -PathType Leaf)) { [IO.File]::Delete($collectionGatePath) }
    if ($extractionMoved -and (Test-Path -LiteralPath $extractionRoot -PathType Container)) { [IO.Directory]::Delete($extractionRoot,$true) }
    if ($archiveCreated -and (Test-Path -LiteralPath $archivePath -PathType Leaf)) { [IO.File]::Delete($archivePath) }
    if (-not $archiveDirExisted -and (Test-Path -LiteralPath $archiveDir -PathType Container) -and @(Get-ChildItem -LiteralPath $archiveDir -Force).Count -eq 0) { [IO.Directory]::Delete($archiveDir) }
    throw
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
        Assert-True ($resolvedTemp -eq 'C:\O3EI1R') 'O3EI1 temporary cleanup root changed.'
        [IO.Directory]::Delete($resolvedTemp,$true)
    }
}
