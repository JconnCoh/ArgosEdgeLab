#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [string]$PackageRoot = 'C:\O3F15L4D3PK'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}
function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "D2 create-new JSON already exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 24) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Quote-Argument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    '"' + $Value.Replace('"','\"') + '"'
}
function Invoke-CapturedProcess([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory, [hashtable]$Environment) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = (@($Arguments | ForEach-Object { Quote-Argument ([string]$_) }) -join ' ')
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in @($Environment.Keys)) { $start.EnvironmentVariables[[string]$name] = [string]$Environment[$name] }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() 'D2 rehearsal child did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    Require $process.WaitForExit(30000) 'D2 rehearsal outer process exceeded 30 seconds.'
    [pscustomobject]@{exitCode=[int]$process.ExitCode;stdout=$stdoutTask.Result.Trim();stderr=$stderrTask.Result.Trim()}
}
function Read-OneJson([string]$Text, [string]$Label) {
    $lines = @($Text -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Require ($lines.Count -eq 1) "D2 $Label stdout line count changed."
    try { $lines[0] | ConvertFrom-Json } catch { throw "D2 $Label stdout is not JSON: $($_.Exception.Message)" }
}
function Invoke-DiagnosticCase([string]$Mode, [string]$CaseRoot, [string]$EntryPoint, [string]$Fixture, [string]$Contract, [string]$PowerShell, [string]$Python) {
    [void](New-Item -ItemType Directory -Path $CaseRoot)
    $runner = Join-Path $CaseRoot 'Run-O3F15L4FrontReconcile.py'
    [IO.File]::Copy($Fixture, $runner, $false)
    [IO.File]::Copy($Contract, (Join-Path $CaseRoot 'O3F15L4D3_DIAGNOSTIC_CONTRACT.json'), $false)
    $capture = Invoke-CapturedProcess $PowerShell @(
        '-NoProfile','-ExecutionPolicy','Bypass','-File',$EntryPoint,
        '-PackageRoot',$CaseRoot,'-RuntimePath',$Python,'-RunnerPath',$runner,
        '-ExpectedRunnerSha256',(Get-Sha256 $Fixture),'-Rehearsal','-RehearsalTimeoutSeconds','2'
    ) (Split-Path -Parent $EntryPoint) @{O3F15L4D3_FIXTURE_MODE=$Mode}
    Require ([string]::IsNullOrWhiteSpace($capture.stderr)) "D2 entrypoint wrote outer stderr: $Mode"
    $value = Read-OneJson $capture.stdout $Mode
    $success = $Mode -like 'PASS*'
    Require (($capture.exitCode -eq 0) -eq $success) "D2 exit classification changed: $Mode"
    $expectedFailure = @{
        CLASSIFICATION_OVERSIZE='CLASSIFICATION_INVALID'; ZERO_STDERR='CHILD_STDERR'; NONZERO='CHILD_NONZERO'
        MALFORMED='CHILD_JSON_MALFORMED'; TIMEOUT='CHILD_TIMEOUT'; OVERSIZE='CHILD_OUTPUT_OVERSIZE'
        EXACT_CAP='CHILD_JSON_MALFORMED'; SPLIT_OVER='CHILD_OUTPUT_OVERSIZE'
    }
    if ($success) {
        Require ([string]$value.state -ceq 'COMPLETE_O3F15L4D3_METADATA_DIAGNOSTIC' -and [int]$value.classification.identityCount -eq 978 -and [int]$value.classification.sourceLeafCount -eq 1956) "D2 success contract changed: $Mode"
    } else {
        Require ([string]$value.state -ceq 'HOLD_O3F15L4D3_METADATA_DIAGNOSTIC' -and [string]$value.failureCode -ceq [string]$expectedFailure[$Mode]) "D2 hold contract changed: $Mode"
    }
    foreach ($flag in @('selectorOrThresholdChanged','sourceImageBytesRead','detectorResultRootCreated','qSubstUsed','selfTestUsed','focusedTestUsed','gateUsed','runUsed','backgroundLaunchUsed','providerActivated','sourceMutationPerformed','sourceDeletionPerformed','holdCleared','retryUsed','mutationsPerformed')) {
        Require ($value.$flag -eq $false) "D2 prohibited flag changed for ${Mode}: $flag"
    }
    Require ([int]$value.existingTaskActionCount -eq 0 -and [int]$value.existingProcessActionCount -eq 0) "D2 existing action count changed: $Mode"
    [ordered]@{mode=$Mode;state=[string]$value.state;failureCode=$(if($success){$null}else{[string]$value.failureCode});emittedJsonBytes=[Text.Encoding]::UTF8.GetByteCount($capture.stdout);combinedChildBytes=[int64]$value.child.combinedBytes}
}
function New-SignedWorkerFixture([string]$ExtractedPackage, [string]$RequestRoot, [string]$RequestId, [string]$Destination, [object]$Signer) {
    Require (-not (Test-Path -LiteralPath $RequestRoot)) "D2 worker fixture already exists: $RequestRoot"
    Copy-Item -LiteralPath $ExtractedPackage -Destination $RequestRoot -Recurse
    $manifestPath = Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.json'
    $signaturePath = Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.sig'
    $payloadRoot = Join-Path $RequestRoot 'payload'
    $fixtureEntry = Join-Path $payloadRoot 'O3F15L4D3MaintenanceFixture.ps1'
    $fixtureSource = "#Requires -Version 5.1`r`n[ordered]@{state='PASS_O3F15L4D3_LOCAL_MAINTENANCE_FIXTURE';taskActionCount=0;existingProcessActionCount=0;providerActivated=`$false;sourceImageBytesRead=`$false;reviewOnly=`$true;productionRoutingEnabled=`$false}|ConvertTo-Json -Compress`r`n"
    [IO.File]::WriteAllText($fixtureEntry, $fixtureSource, (New-Object Text.UTF8Encoding($false)))
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $created = [DateTimeOffset]::UtcNow
    $manifest.requestId = $RequestId
    $manifest.createdUtc = $created.ToString('o')
    $manifest.expiresUtc = $created.AddHours(2).ToString('o')
    $manifest.entryPoint = 'payload/O3F15L4D3MaintenanceFixture.ps1'
    $manifest.changes[0].destination = $Destination.Replace('\','/')
    $manifest.rehearsal.requiredState = 'PASS_O3F15L4D3_LOCAL_MAINTENANCE_FIXTURE'
    $manifest.signerThumbprint = ([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant()
    $manifest.entryPointMutations = @()
    $manifest.entryPointOutputs = @()
    $manifest.allowedTaskActions = @()
    $manifest.allowedProcessActions = @()
    $manifest.files = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name | ForEach-Object {
        [ordered]@{path='payload/' + $_.Name;bytes=[int64]$_.Length;sha256=Get-Sha256 $_.FullName}
    })
    $manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes($manifestPath, $manifestBytes)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Signer)
    try { [IO.File]::WriteAllBytes($signaturePath, $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) }
    finally { $rsa.Dispose() }
    [ordered]@{manifestSha256=Get-Sha256 $manifestPath;signatureSha256=Get-Sha256 $signaturePath;payloadFileCount=@($manifest.files).Count}
}
function Invoke-ExactWorkerCase([string]$Name, [string]$ExtractedPackage, [string]$CasesRoot, [string]$Carrier, [ValidateSet('APPROVED','IDEMPOTENT','UNAPPROVED','ABSENT')][string]$Disposition, [object]$Signer, [string]$Worker, [string]$RequestVerifier, [string]$ResponseVerifier, [string]$LocalPublicCertificate) {
    $caseRoot = Join-Path $CasesRoot $Name
    $installRoot = Join-Path $caseRoot 'install'
    foreach ($leaf in @('incoming','processed','responses','state','install')) { [void](New-Item -ItemType Directory -Path (Join-Path $caseRoot $leaf) -Force) }
    $target = Join-Path $installRoot 'OCV03_NotchReviewOpenCvV1.py'
    if ($Disposition -in @('APPROVED','IDEMPOTENT')) { [IO.File]::Copy($Carrier, $target, $false) }
    elseif ($Disposition -ceq 'UNAPPROVED') { [IO.File]::WriteAllText($target, 'O3F15L4D3_UNAPPROVED_PREDECESSOR', (New-Object Text.UTF8Encoding($false))) }
    $beforeExists = Test-Path -LiteralPath $target -PathType Leaf
    $beforeHash = if ($beforeExists) { Get-Sha256 $target } else { $null }
    $requestId = 'REQ_O3F15L4D3_LOCAL_' + $Name
    $requestRoot = Join-Path (Join-Path $caseRoot 'incoming') ($requestId + '.ready')
    $fixture = New-SignedWorkerFixture $ExtractedPackage $requestRoot $requestId $target $Signer
    $configPath = Join-Path $caseRoot 'ENDPOINT_CONFIG.json'
    Write-NewJson $configPath ([ordered]@{
        schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false
        incomingRoot=Join-Path $caseRoot 'incoming';processedRoot=Join-Path $caseRoot 'processed';responseOutbox=Join-Path $caseRoot 'responses';stateRoot=Join-Path $caseRoot 'state'
        requestVerifierPath=$RequestVerifier;laptopSignerCertificatePath=$LocalPublicCertificate
        endpointSignerThumbprint=([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant();endpointSignerStoreLocation='CurrentUser'
        approvedMaintenanceRoots=@($installRoot);approvedDataRoots=@();status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()};handlers=@()
    })
    & $Worker -ConfigPath $configPath -Once | Out-Null
    $responses = @(Get-ChildItem -LiteralPath (Join-Path $caseRoot 'responses') -Directory -Filter '*.ready')
    Require ($responses.Count -eq 1) "D2 exact worker response count changed: $Name"
    & $ResponseVerifier -PackagePath $responses[0].FullName -EndpointCertificatePath $LocalPublicCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
    $response = Get-Content -LiteralPath (Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.json') -Raw | ConvertFrom-Json
    $afterExists = Test-Path -LiteralPath $target -PathType Leaf
    $afterHash = if ($afterExists) { Get-Sha256 $target } else { $null }
    $responseSignature = Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.sig'
    if ($Disposition -in @('APPROVED','IDEMPOTENT')) {
        Require ([string]$response.state -ceq 'PASS_MAINTENANCE_PATCH' -and $afterHash -ceq (Get-Sha256 $Carrier)) "D2 exact worker approved case failed: $Name"
        $result = Get-Content -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json') -Raw | ConvertFrom-Json
        Require ([string]$result.state -ceq 'PASS_MAINTENANCE_PATCH' -and [int]$result.changedFiles -eq 1) "D2 exact worker result changed: $Name"
    } elseif ($Disposition -ceq 'UNAPPROVED') {
        Require ([string]$response.state -ceq 'FAILED' -and ([string]$response.detail) -like '*Installed predecessor is not approved*' -and $afterExists -and $afterHash -ceq $beforeHash) 'D2 exact worker did not refuse unapproved predecessor before mutation.'
    } else {
        Require ([string]$response.state -ceq 'FAILED' -and ([string]$response.detail) -like '*allowCreate is false*' -and -not $afterExists) 'D2 exact worker did not refuse absent destination before mutation.'
    }
    [ordered]@{case=$Name;disposition=$Disposition;endpointState=[string]$response.state;beforeExists=$beforeExists;afterExists=$afterExists;beforeSha256=$beforeHash;afterSha256=$afterHash;requestManifestSha256=[string]$fixture.manifestSha256;requestSignatureSha256=[string]$fixture.signatureSha256;responseSignatureSha256=Get-Sha256 $responseSignature;localRehearsalRequestSignatureCount=1;localRehearsalResponseSignatureCount=1;refusedBeforeMutation=($Disposition -in @('UNAPPROVED','ABSENT'))}
}

Require ($Preflight -xor $Test) 'Specify exactly one of -Preflight or -Test.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) 'D2 final-ZIP rehearsal requires exact Windows PowerShell 5.1.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$signGatePath = Join-Path $PSScriptRoot 'final_o3f15l4d3\O3F15L4D3_SIGN_GATE.json'
$certificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$endpointCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$signingIdentityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$packageVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$queueGatePath = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$workerPath = Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$python = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$testRoot = Join-Path $PackageRoot 'rehearsal'
$extractRoot = Join-Path $testRoot 'signed'
$gatePath = Join-Path $PSScriptRoot 'O3F15L4D3_FINAL_ZIP_REHEARSAL_GATE.json'
foreach ($path in @($signGatePath,$certificatePath,$endpointCertificatePath,$signingIdentityPath,$packageVerifier,$responseVerifier,$queueGatePath,$workerPath,$python,$windowsPowerShell)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "D2 final rehearsal dependency absent: $path" }
$signGate = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
Require ([string]$signGate.state -ceq 'PASS_O3F15L4D3_SIGNED_METADATA_DIAGNOSTIC_PACKAGE' -and [int]$signGate.signatureCount -eq 1 -and [int]$signGate.payloadFileCount -eq 18) 'D2 sign gate changed.'
$zip = [IO.Path]::GetFullPath([string]$signGate.packageZipPath)
Require (Test-Path -LiteralPath $zip -PathType Leaf) 'D2 signed ZIP is absent.'
Require ((Get-Item -LiteralPath $zip).Length -eq [int64]$signGate.packageZipBytes -and (Get-Sha256 $zip) -ceq [string]$signGate.packageZipSha256) 'D2 signed ZIP changed.'
Require ((Get-Sha256 $workerPath) -ceq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250' -and (Get-Sha256 $queueGatePath) -ceq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'D2 inherited endpoint evidence changed.'
Require ((Get-Sha256 $endpointCertificatePath) -ceq '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B') 'D2 active JBOD endpoint certificate changed.'
Require (-not (Test-Path -LiteralPath $testRoot) -and -not (Test-Path -LiteralPath $gatePath)) 'D2 create-new rehearsal output already exists.'
$planned = @(
    (Join-Path $extractRoot 'payload\Invoke-O3F15L4D3.ps1'),
    (Join-Path $testRoot 'diagnostic\CLASSIFICATION_OVERSIZE\O3F15L4D3_DIAGNOSTIC_CONTRACT.json'),
    (Join-Path $testRoot 'exact-worker\UNAPPROVED\incoming\REQ_O3F15L4D3_LOCAL_UNAPPROVED.ready\payload\O3F15L4D3_DIAGNOSTIC_CONTRACT.json'),
    (Join-Path $testRoot 'exact-worker\UNAPPROVED\state\maintenance\REQ_O3F15L4D3_LOCAL_UNAPPROVED\failed_new\M000_0123456789_0123456789.rollback'),
    (Join-Path $testRoot 'response-layout\PORTAL_RESPONSE_MANIFEST.json'),
    $gatePath
)
$pathResult = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathResult.state -ceq 'PASS_PATH_BUDGET') 'D2 final rehearsal path gate failed.'

if ($Preflight) {
    [ordered]@{schema='argos_ocv03_o3f15l4d3_final_zip_rehearsal_preflight_v1';state='PASS_O3F15L4D3_FINAL_ZIP_REHEARSAL_PREFLIGHT';requestId=[string]$signGate.requestId;packageZipSha256=[string]$signGate.packageZipSha256;testRoot=$testRoot;pathState=[string]$pathResult.state;diagnosticCaseCount=11;exactEndpointWorkerCaseCount=4;releaseSignatureCount=[int]$signGate.signatureCount;plannedLocalRehearsalRequestSignatureCount=4;plannedLocalRehearsalResponseSignatureCount=4;mutationsPerformed=$false;targetOrJbodAccessed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $testRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $extractRoot)
$verified = & $packageVerifier -PackagePath $extractRoot -SignerCertificatePath $certificatePath -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$verified.State -ceq 'PASS_SIGNED_PORTAL_PACKAGE') 'D2 exact signed package verification failed.'
$manifest = Get-Content -LiteralPath (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
Require ([string]$manifest.requestId -ceq [string]$signGate.requestId -and @($manifest.files).Count -eq 18 -and @($manifest.changes).Count -eq 1 -and [int64]$manifest.maxResultBytes -eq 8388608) 'D2 signed manifest identity changed.'
Require ([string]$manifest.entryPoint -ceq 'payload/Invoke-O3F15L4D3.ps1' -and [string]::Join('|',@($manifest.sourceProcessingContract.exactChildArguments)) -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT') 'D2 signed entrypoint selector changed.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.requestRetryAuthorized) 'D2 signed authority widened.'
foreach ($fileRecord in @($manifest.files)) {
    $file = Join-Path $extractRoot ([string]$fileRecord.path)
    Require (Test-Path -LiteralPath $file -PathType Leaf) "D2 extracted payload absent: $($fileRecord.path)"
    Require ((Get-Item -LiteralPath $file).Length -eq [int64]$fileRecord.bytes -and (Get-Sha256 $file) -ceq [string]$fileRecord.sha256) "D2 extracted payload changed: $($fileRecord.path)"
}
$payloadRoot = Join-Path $extractRoot 'payload'
$contractPath = Join-Path $payloadRoot 'O3F15L4D3_DIAGNOSTIC_CONTRACT.json'
$entryPoint = Join-Path $payloadRoot 'Invoke-O3F15L4D3.ps1'
$fixture = Join-Path $payloadRoot 'O3F15L4D3DiagnosticFixture.py'
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
Require ([string]$contract.lifecycle -ceq 'FROZEN' -and [string]$contract.state -ceq 'FROZEN_O3F15L4D3_METADATA_DIAGNOSTIC_CONTRACT') 'D2 packaged contract is not frozen.'
$diagnosticRoot = Join-Path $testRoot 'diagnostic'; [void](New-Item -ItemType Directory -Path $diagnosticRoot)
$diagnosticCases = @()
foreach ($mode in @('PASS','PASS_ONE_ALIAS','PASS_MANY_ALIAS','CLASSIFICATION_OVERSIZE','ZERO_STDERR','NONZERO','MALFORMED','TIMEOUT','OVERSIZE','EXACT_CAP','SPLIT_OVER')) {
    $diagnosticCases += Invoke-DiagnosticCase $mode (Join-Path $diagnosticRoot $mode) $entryPoint $fixture $contractPath $windowsPowerShell $python
}
Require (($diagnosticCases | Measure-Object -Property emittedJsonBytes -Maximum).Maximum -le [int64]$contract.response.maximumEmittedJsonBytes) 'D2 emitted JSON cap failed.'
$workerCasesRoot = Join-Path $testRoot 'exact-worker'; [void](New-Item -ItemType Directory -Path $workerCasesRoot)
$identity = Get-Content -LiteralPath $signingIdentityPath -Raw | ConvertFrom-Json
$signerThumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
Require ($signerThumbprint -ceq 'C82181052919C475CF888F49427C1B55AE65DC12') 'D2 local rehearsal signer identity changed.'
$localSigner = Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + $signerThumbprint) -ErrorAction Stop
Require ([bool]$localSigner.HasPrivateKey) 'D2 local rehearsal signing private key is absent.'
$carrier = Join-Path $payloadRoot 'OCV03_NotchReviewOpenCvV1.py'
$workerCases = @(
    (Invoke-ExactWorkerCase 'APPROVED' $extractRoot $workerCasesRoot $carrier 'APPROVED' $localSigner $workerPath $packageVerifier $responseVerifier $certificatePath),
    (Invoke-ExactWorkerCase 'IDEMPOTENT' $extractRoot $workerCasesRoot $carrier 'IDEMPOTENT' $localSigner $workerPath $packageVerifier $responseVerifier $certificatePath),
    (Invoke-ExactWorkerCase 'UNAPPROVED' $extractRoot $workerCasesRoot $carrier 'UNAPPROVED' $localSigner $workerPath $packageVerifier $responseVerifier $certificatePath),
    (Invoke-ExactWorkerCase 'ABSENT' $extractRoot $workerCasesRoot $carrier 'ABSENT' $localSigner $workerPath $packageVerifier $responseVerifier $certificatePath)
)
Require ($workerCases.Count -eq 4 -and @($workerCases | Where-Object {$_.endpointState -ceq 'PASS_MAINTENANCE_PATCH'}).Count -eq 2 -and @($workerCases | Where-Object {$_.refusedBeforeMutation}).Count -eq 2) 'D2 exact worker case matrix changed.'
$queueGate = Get-Content -LiteralPath $queueGatePath -Raw | ConvertFrom-Json
$requiredQueueChecks = @('PATH_BOUNDARIES_199_200_229_230','TARGET_HASH_IDEMPOTENCY','REQUEST_REPLAY_NO_DUPLICATE_RESPONSE','STALE_WORK_COLLISION_AND_SECOND_QUEUE_ITEM','INJECTED_RESPONSE_FAILURE_COMPACT_AND_QUEUE_ADVANCE','FORCED_TERMINATION_AND_RESTART','UNAPPROVED_PREDECESSOR_REFUSED_BEFORE_MUTATION','INJECTED_FAILURE_ROLLBACK_AND_TASK_RESTART')
Require ([int]$queueGate.checkCount -eq 16 -and @($queueGate.checks | Where-Object {$_.state -ceq 'PASS'}).Count -eq 16) 'D2 inherited queue gate no longer has 16 PASS checks.'
foreach ($name in $requiredQueueChecks) { Require (@($queueGate.checks | Where-Object {$_.name -ceq $name -and $_.state -ceq 'PASS'}).Count -eq 1) "D2 inherited queue check absent: $name" }
$layoutRoot = Join-Path $testRoot 'response-layout'; [void](New-Item -ItemType Directory -Path $layoutRoot)
$stdoutPath = Join-Path $layoutRoot 'MAINTENANCE.stdout.txt'
[IO.File]::WriteAllBytes($stdoutPath, (New-Object byte[] ([int]$contract.response.maximumEmittedJsonBytes)))
$stderrPath = Join-Path $layoutRoot 'MAINTENANCE.stderr.txt'; [IO.File]::WriteAllBytes($stderrPath, (New-Object byte[] 0))
Write-NewJson (Join-Path $layoutRoot 'RESULT.json') ([ordered]@{schema='argos_project_portal_maintenance_result_v1';state='PASS_MAINTENANCE_PATCH';changedFiles=1;entryPoint=[string]$manifest.entryPoint;exitCode=0;reviewOnly=$true;productionRoutingEnabled=$false})
$responseFiles = @(Get-ChildItem -LiteralPath $layoutRoot -File | Sort-Object Name | ForEach-Object {[ordered]@{path=$_.Name;bytes=[int64]$_.Length;sha256=Get-Sha256 $_.FullName}})
Write-NewJson (Join-Path $layoutRoot 'PORTAL_RESPONSE_MANIFEST.json') ([ordered]@{schema='argos_project_portal_response_manifest_v1';requestId=[string]$manifest.requestId;sourceRole='JBOD';state='PASS_MAINTENANCE_PATCH';files=$responseFiles;reviewOnly=$true;productionRoutingEnabled=$false})
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($endpointCertificatePath)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
try { $responseSignatureBytes = [int]($rsa.KeySize / 8) } finally { $rsa.Dispose(); $certificate.Dispose() }
$responseTotal = [int64](Get-ChildItem -LiteralPath $layoutRoot -File | Measure-Object -Property Length -Sum).Sum + $responseSignatureBytes
Require ($responseTotal -le [int64]$manifest.maxResultBytes -and $responseTotal -le [int64]$contract.response.maximumConstructedResponseBytes) 'D2 constructed response exceeds the signed ceiling.'
$record = [ordered]@{schema='argos_ocv03_o3f15l4d3_final_zip_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3F15L4D3_FINAL_ZIP_WINDOWS_PS51_REHEARSAL';requestId=[string]$manifest.requestId;packageZipPath=$zip;packageZipBytes=[int64](Get-Item -LiteralPath $zip).Length;packageZipSha256=Get-Sha256 $zip;exactSignedZipExtracted=$true;signatureVerified=$true;releaseSignatureCount=[int]$signGate.signatureCount;localRehearsalRequestSignatureCount=[int](($workerCases | Measure-Object -Property localRehearsalRequestSignatureCount -Sum).Sum);localRehearsalResponseSignatureCount=[int](($workerCases | Measure-Object -Property localRehearsalResponseSignatureCount -Sum).Sum);payloadHashCount=@($manifest.files).Count;diagnosticCases=$diagnosticCases;exactEndpointWorkerCases=$workerCases;approvedPredecessorPassed=$true;targetHashIdempotentPassed=$true;unapprovedPredecessorRefusedBeforeMutation=$true;allowCreateFalseRefusedBeforeMutation=$true;exactEndpointWorkerCasesExecuted=$true;endpointWorkerSha256=Get-Sha256 $workerPath;queueSafetyGateSha256=Get-Sha256 $queueGatePath;queueSafetyCheckCount=[int]$queueGate.checkCount;constructedResponseBytes=$responseTotal;maximumResultBytes=[int64]$manifest.maxResultBytes;responseSignatureBytesDerivedFromActiveJbodEndpointCertificate=$responseSignatureBytes;activeJbodEndpointCertificateSha256=Get-Sha256 $endpointCertificatePath;activeJbodEndpointSignerThumbprint='DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC';targetOrJbodAccessed=$false;sourceImageBytesRead=$false;existingProcessOrTaskActionPerformed=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
Write-NewJson $gatePath $record
$record | ConvertTo-Json -Depth 16
