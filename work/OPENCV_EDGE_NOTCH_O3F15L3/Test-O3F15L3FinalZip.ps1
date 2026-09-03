#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Sha-Text([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}
function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L3 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Quote([string]$Value) { if ($Value -notmatch '[\s"]') { return $Value }; return '"' + $Value.Replace('"','\"') + '"' }
function Invoke-Captured([string]$Executable, [string[]]$Arguments, [string]$WorkingDirectory) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = (@($Arguments | ForEach-Object { Quote ([string]$_) }) -join ' ')
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() 'O3F15L3 rehearsal child did not start.'
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ exitCode = [int]$process.ExitCode; stdout = $stdout; stderr = $stderr }
}
function Parse-OneJson([string]$Text, [string]$Label) {
    $lines = @($Text -split '\r?\n' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Require ($lines.Count -eq 1) "O3F15L3 $Label stdout line count changed."
    try { $lines[0] | ConvertFrom-Json } catch { throw "O3F15L3 $Label stdout is not JSON: $($_.Exception.Message)" }
}
function New-DiagnosticInvocation([string]$Path, [string]$Mode, [int]$TimeoutSeconds, [string]$Python, [string]$PythonHash) {
    Write-NewJson $Path ([ordered]@{
        schema = 'argos_ocv03_o3f15l3_rehearsal_invocation_v1'
        fixtureMode = $Mode
        pythonPath = $Python
        pythonSha256 = $PythonHash
        timeoutSeconds = $TimeoutSeconds
    })
}
function Invoke-DiagnosticCase([string]$Mode, [int]$TimeoutSeconds, [string]$CasesRoot, [string]$PowerShell, [string]$Python, [string]$PythonHash, [string]$Endpoint) {
    $invocation = Join-Path $CasesRoot ($Mode + '.json')
    New-DiagnosticInvocation $invocation $Mode $TimeoutSeconds $Python $PythonHash
    $capture = Invoke-Captured $PowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Endpoint,'-Rehearsal','-InvocationManifest',$invocation) (Split-Path -Parent $Endpoint)
    Require ($capture.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($capture.stderr)) "O3F15L3 packaged diagnostic outer process failed: $Mode"
    $result = Parse-OneJson $capture.stdout "packaged $Mode diagnostic"
    Require ([string]$result.schema -ceq 'argos_ocv03_o3f15l3_preflight_diagnostic_v1' -and [string]$result.state -ceq 'COMPLETE_O3F15L3_PREFLIGHT_DIAGNOSTIC_CAPTURED') "O3F15L3 packaged diagnostic envelope changed: $Mode"
    Require ([bool]$result.rehearsal -and [int]$result.ownedChildCount -eq 1 -and [int]$result.maximumOwnedChildCount -eq 1) "O3F15L3 packaged one-child evidence changed: $Mode"
    $fixture = Join-Path (Split-Path -Parent $Endpoint) 'O3F15L3DiagnosticFixture.py'
    Require ([string]::Join('|', @($result.childArguments)) -ceq "-I|-B|$fixture|PREFLIGHT") "O3F15L3 packaged child arguments changed: $Mode"
    Require (-not [bool]$result.selfTestStarted -and -not [bool]$result.gateStarted -and -not [bool]$result.runStarted -and -not [bool]$result.detectorResultRootCreated -and -not [bool]$result.corpusStarted -and -not [bool]$result.imageBytesRead -and -not [bool]$result.sourceMutation -and -not [bool]$result.providerActivated -and -not [bool]$result.mutationsPerformed) "O3F15L3 packaged authority widened: $Mode"
    Require ([int]$result.stdoutTailCharacters -le 2000 -and [int]$result.stdoutTailBytes -le 8000 -and [int]$result.stderrTailCharacters -le 2000 -and [int]$result.stderrTailBytes -le 8000) "O3F15L3 packaged tail bound changed: $Mode"
    Require ([int]$result.stdoutBytes -le 1048576 -and [int]$result.stderrBytes -le 1048576 -and ([int]$result.stdoutBytes + [int]$result.stderrBytes) -le 1048576) "O3F15L3 packaged stream bound changed: $Mode"
    if (-not [bool]$result.stdoutTruncated) { Require ([string]$result.stdoutSha256 -ceq (Sha-Text ([string]$result.stdoutTail))) "O3F15L3 packaged stdout was not preserved: $Mode" }
    if (-not [bool]$result.stderrTruncated) { Require ([string]$result.stderrSha256 -ceq (Sha-Text ([string]$result.stderrTail))) "O3F15L3 packaged stderr was not preserved: $Mode" }
    $result
}
function New-MaintenanceFixture([string]$TemplateRoot, [string]$RequestRoot, [string]$CaseRequestId, [string]$Destination, [object]$Signer) {
    Require (-not (Test-Path -LiteralPath $RequestRoot)) "O3F15L3 installer fixture request exists: $RequestRoot"
    Copy-Item -LiteralPath $TemplateRoot -Destination $RequestRoot -Recurse
    $manifestPath = Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.json'
    $signaturePath = Join-Path $RequestRoot 'PORTAL_REQUEST_MANIFEST.sig'
    $payloadRoot = Join-Path $RequestRoot 'payload'
    $fixtureEntry = Join-Path $payloadRoot 'O3F15MaintenanceValidationFixture.ps1'
    $fixtureText = "#Requires -Version 5.1`r`n[ordered]@{state='PASS_O3F15_MAINTENANCE_VALIDATION_ENTRYPOINT';taskActionCount=0;existingProcessActionCount=0;providerActivated=`$false;sourceImageBytesRead=`$false;reviewOnly=`$true;productionRoutingEnabled=`$false}|ConvertTo-Json -Compress`r`n"
    [IO.File]::WriteAllText($fixtureEntry, $fixtureText, (New-Object Text.UTF8Encoding($false)))
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $created = [DateTimeOffset]::UtcNow
    $manifest.requestId = $CaseRequestId
    $manifest.createdUtc = $created.ToString('o')
    $manifest.expiresUtc = $created.AddHours(2).ToString('o')
    $manifest.entryPoint = 'payload/O3F15MaintenanceValidationFixture.ps1'
    $manifest.changes[0].destination = $Destination.Replace('\','/')
    $manifest.rehearsal.requiredState = 'PASS_O3F15_MAINTENANCE_VALIDATION_ENTRYPOINT'
    $manifest.signerThumbprint = ([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant()
    $manifest.entryPointMutations = @()
    $manifest.entryPointOutputs = @()
    $manifest.allowedTaskActions = @()
    $manifest.allowedProcessActions = @()
    $manifest.files = @(Get-ChildItem -LiteralPath $payloadRoot -File | Sort-Object Name | ForEach-Object { [ordered]@{ path = 'payload/' + $_.Name; bytes = [int64]$_.Length; sha256 = Sha $_.FullName } })
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 32))
    [IO.File]::WriteAllBytes($manifestPath, $bytes)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Signer)
    try { [IO.File]::WriteAllBytes($signaturePath, $rsa.SignData($bytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) }
    finally { $rsa.Dispose() }
    [ordered]@{ requestId = $CaseRequestId; manifestSha256 = Sha $manifestPath; signatureSha256 = Sha $signaturePath }
}
function Invoke-MaintenanceCase([string]$Name, [string]$TemplateRoot, [string]$CasesRoot, [string]$Carrier, [bool]$Approved, [object]$Signer, [string]$Worker, [string]$RequestVerifier, [string]$ResponseVerifier, [string]$PublicCertificate) {
    $caseRoot = Join-Path $CasesRoot $Name
    $installRoot = Join-Path $caseRoot 'install'
    $target = Join-Path $installRoot 'OCV03_NotchReviewOpenCvV1.py'
    foreach ($relative in @('incoming','processed','responses','state','install')) { [void](New-Item -ItemType Directory -Path (Join-Path $caseRoot $relative)) }
    if ($Approved) { Copy-Item -LiteralPath $Carrier -Destination $target } else { [IO.File]::WriteAllText($target, 'O3F15L3_UNAPPROVED_PREDECESSOR', (New-Object Text.UTF8Encoding($false))) }
    $beforeSha = Sha $target
    $caseRequestId = 'REQ_O3F15L3_IR_' + $Name
    $requestRoot = Join-Path (Join-Path $caseRoot 'incoming') ($caseRequestId + '.ready')
    $fixture = New-MaintenanceFixture $TemplateRoot $requestRoot $caseRequestId $target $Signer
    $configPath = Join-Path $caseRoot 'ENDPOINT_CONFIG.json'
    Write-NewJson $configPath ([ordered]@{ schema='argos_project_portal_endpoint_config_v1'; role='JBOD'; reviewOnly=$true; productionRoutingEnabled=$false; incomingRoot=Join-Path $caseRoot 'incoming'; processedRoot=Join-Path $caseRoot 'processed'; responseOutbox=Join-Path $caseRoot 'responses'; stateRoot=Join-Path $caseRoot 'state'; requestVerifierPath=$RequestVerifier; laptopSignerCertificatePath=$PublicCertificate; endpointSignerThumbprint=([string]$Signer.Thumbprint).Replace(' ','').ToUpperInvariant(); endpointSignerStoreLocation='CurrentUser'; approvedMaintenanceRoots=@($installRoot); approvedDataRoots=@(); status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()}; handlers=@() })
    & $Worker -ConfigPath $configPath -Once | Out-Null
    $responses = @(Get-ChildItem -LiteralPath (Join-Path $caseRoot 'responses') -Directory -Filter '*.ready')
    Require ($responses.Count -eq 1) "O3F15L3 installer response cardinality changed: $Name"
    & $ResponseVerifier -PackagePath $responses[0].FullName -EndpointCertificatePath $PublicCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $caseRequestId | Out-Null
    $response = Get-Content -LiteralPath (Join-Path $responses[0].FullName 'PORTAL_RESPONSE_MANIFEST.json') -Raw | ConvertFrom-Json
    $afterSha = Sha $target
    $installLeaves = @(Get-ChildItem -LiteralPath $installRoot -File)
    Require ($installLeaves.Count -eq 1 -and $installLeaves[0].FullName -eq $target) "O3F15L3 installer wrote an undeclared leaf: $Name"
    if ($Approved) {
        Require ([string]$response.state -ceq 'PASS_MAINTENANCE_PATCH' -and $afterSha -ceq (Sha $Carrier)) "O3F15L3 approved installer case failed: $Name"
        $result = Get-Content -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json') -Raw | ConvertFrom-Json
        Require ([string]$result.state -ceq 'PASS_MAINTENANCE_PATCH' -and [int]$result.changedFiles -eq 1 -and [bool]$result.changes[0].predecessorExisted -and [string]$result.changes[0].installedSha256 -ceq $afterSha) "O3F15L3 maintenance result changed: $Name"
    } else {
        Require ([string]$response.state -ceq 'FAILED' -and ([string]$response.detail) -like '*Installed predecessor is not approved*' -and $afterSha -ceq $beforeSha -and -not (Test-Path -LiteralPath (Join-Path $responses[0].FullName 'RESULT.json'))) 'O3F15L3 unapproved predecessor was not refused before mutation.'
    }
    [ordered]@{ case=$Name; endpointState=[string]$response.state; requestManifestSha256=[string]$fixture.manifestSha256; approvedPredecessor=$Approved; beforeSha256=$beforeSha; afterSha256=$afterSha; installLeafCount=$installLeaves.Count; refusedBeforeMutation=(-not $Approved) }
}

Require ($Preflight -xor $Test) 'Specify exactly one of -Preflight or -Test.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'O3F15L3 final-ZIP rehearsal requires exact Windows PowerShell 5.1.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$signGatePath = Join-Path $PSScriptRoot 'O3F15L3_SIGN_GATE.json'
$certificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$endpointWorker = Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$queueGate = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$python = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage\python.exe'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$fixtureRoot = 'C:\O3F15L3V1'
$extract = Join-Path $fixtureRoot 'x'
$casesRoot = Join-Path $fixtureRoot 'd'
$gatePath = Join-Path $PSScriptRoot 'O3F15L3_FINAL_ZIP_REHEARSAL_GATE.json'
foreach ($path in @($signGatePath,$certificate,$packageTester,$responseVerifier,$identityPath,$endpointWorker,$queueGate,$python,$windowsPowerShell)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 final-ZIP dependency absent: $path" }
$signGate = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
Require ([string]$signGate.state -ceq 'PASS_O3F15L3_SIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE') 'O3F15L3 sign gate changed.'
$requestId = [string]$signGate.requestId
$zip = [string]$signGate.packageZipPath
Require (Test-Path -LiteralPath $zip -PathType Leaf) 'O3F15L3 signed ZIP absent.'
Require ((Get-Item -LiteralPath $zip).Length -eq [int64]$signGate.packageZipBytes -and (Sha $zip) -ceq [string]$signGate.packageZipSha256) 'O3F15L3 signed ZIP changed.'
Require ((Sha $python) -ceq '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1') 'O3F15L3 local rehearsal runtime changed.'
Require ((Sha $certificate) -ceq '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF' -and (Sha $packageTester) -ceq '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B' -and (Sha $responseVerifier) -ceq '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C' -and (Sha $identityPath) -ceq '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289') 'O3F15L3 signed-package dependencies changed.'
Require ((Sha $endpointWorker) -ceq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250' -and (Sha $queueGate) -ceq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O3F15L3 inherited endpoint evidence changed.'
foreach ($path in @($fixtureRoot,$gatePath)) { Require (-not (Test-Path -LiteralPath $path)) "O3F15L3 create-new rehearsal target exists: $path" }
$planned = @((Join-Path $extract 'payload\Invoke-O3F15L3.ps1'),(Join-Path $casesRoot 'NONZERO_BOTH.json'),(Join-Path $fixtureRoot 'installer\UNAPPROVED\state\maintenance\REQ_O3F15L3_IR_UNAPPROVED\failed_new\M000_0123456789_0123456789.rollback'),$gatePath)
$pathGate = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'O3F15L3 exact-package path gate failed.'

if ($Preflight) {
    [ordered]@{ schema='argos_ocv03_o3f15l3_final_zip_rehearsal_preflight_v1'; state='PASS_O3F15L3_FINAL_ZIP_REHEARSAL_PREFLIGHT'; requestId=$requestId; packageZipSha256=[string]$signGate.packageZipSha256; fixtureRoot=$fixtureRoot; pathState=[string]$pathGate.state; exactFixtureCaseCount=5; installerCaseCount=3; endpointWorkerSha256=Sha $endpointWorker; queueSafetyGateSha256=Sha $queueGate; targetOrJbodAccessed=$false; sourceImageBytesRead=$false; existingProcessesQueried=$false; existingProcessOrTaskActionPerformed=$false; mutationsPerformed=$false; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $fixtureRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::ExtractToDirectory($zip, $extract)
[void](New-Item -ItemType Directory -Path $casesRoot)
$packageTest = & $packageTester -PackagePath $extract -SignerCertificatePath $certificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$packageTest.State -ceq 'PASS_SIGNED_PORTAL_PACKAGE') 'O3F15L3 exact package signature failed.'
$manifest = Get-Content -LiteralPath (Join-Path $extract 'PORTAL_REQUEST_MANIFEST.json') -Raw | ConvertFrom-Json
$payload = Join-Path $extract 'payload'
Require ([string]$manifest.requestId -ceq $requestId -and @($manifest.files).Count -eq [int]$signGate.payloadFileCount -and @($manifest.changes).Count -eq 1 -and [string]$manifest.entryPoint -ceq 'payload/Invoke-O3F15L3.ps1') 'O3F15L3 signed manifest identity changed.'
Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.requestRetryAuthorized) 'O3F15L3 signed authority widened.'
Require (@($manifest.entryPointMutations).Count -eq 0 -and @($manifest.entryPointOutputs).Count -eq 0 -and @($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1 -and [string]$manifest.allowedProcessActions[0] -ceq 'START_EXACTLY_ONE_BOUNDED_OWNED_O3F15_PREFLIGHT_CHILD_ONLY') 'O3F15L3 signed action boundary changed.'
Require ([string]::Join('|', @($manifest.sourceProcessingContract.exactChildArguments)) -ceq '-I|-B|Run-O3F15FrontReconcile.py|PREFLIGHT' -and [int]$manifest.sourceProcessingContract.maximumOwnedChildCount -eq 1 -and -not [bool]$manifest.sourceProcessingContract.selfTestAllowed -and -not [bool]$manifest.sourceProcessingContract.gateAllowed -and -not [bool]$manifest.sourceProcessingContract.runAllowed -and -not [bool]$manifest.sourceProcessingContract.imageBytesReadAllowed) 'O3F15L3 signed diagnostic boundary changed.'
foreach ($record in @($manifest.files)) {
    $relative = [string]$record.path
    Require (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') 'O3F15L3 signed payload path is unsafe.'
    $file = Join-Path $extract $relative
    Require (Test-Path -LiteralPath $file -PathType Leaf) "O3F15L3 signed payload absent: $relative"
    Require ((Get-Item -LiteralPath $file).Length -eq [int64]$record.bytes -and (Sha $file) -ceq [string]$record.sha256) "O3F15L3 signed payload changed: $relative"
}
$change = @($manifest.changes)[0]
$carrier = Join-Path $payload 'OCV03_NotchReviewOpenCvV1.py'
$carrierHash = Sha $carrier
Require ([string]$change.source -ceq 'payload/OCV03_NotchReviewOpenCvV1.py' -and [string]$change.installedSha256 -ceq $carrierHash -and @($change.approvedPredecessorSha256).Count -eq 1 -and [string]$change.approvedPredecessorSha256[0] -ceq $carrierHash -and -not [bool]$change.allowCreate) 'O3F15L3 same-bytes carrier changed.'
$contract = Get-Content -LiteralPath (Join-Path $payload 'O3F15L3_DIAGNOSTIC_CONTRACT.json') -Raw | ConvertFrom-Json
Require ([string]$contract.schema -ceq 'argos_ocv03_o3f15l3_diagnostic_contract_v1' -and [string]$contract.state -ceq 'FROZEN_FOR_BUILD' -and [int]$contract.maximumOwnedChildCount -eq 1 -and [string]$contract.expectedResultState -ceq 'COMPLETE_O3F15L3_PREFLIGHT_DIAGNOSTIC_CAPTURED') 'O3F15L3 extracted contract changed.'
Require ([string]$contract.inheritedRoute.endpointWorkerSha256 -ceq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250' -and [string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256 -ceq '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB' -and [string]$contract.inheritedRoute.queueSafetyGateSha256 -ceq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' -and -not [bool]$contract.inheritedRoute.routeImplementationChanged) 'O3F15L3 inherited route pins changed.'
$endpoint = Join-Path $payload 'Invoke-O3F15L3.ps1'
$leafCapture = Invoke-Captured $windowsPowerShell @('-NoProfile','-ExecutionPolicy','Bypass','-File',$endpoint,'-PackageLeafPreflight') $payload
$leaf = Parse-OneJson $leafCapture.stdout 'package-leaf preflight'
Require ($leafCapture.exitCode -eq 0 -and [string]::IsNullOrWhiteSpace($leafCapture.stderr) -and [string]$leaf.state -ceq 'PASS_O3F15L3_EXACT_PACKAGED_DIAGNOSTIC_LEAVES' -and -not [bool]$leaf.mutationsPerformed) 'O3F15L3 exact packaged leaf preflight failed.'
$modes = @('PASS','NONZERO_BOTH','ZERO_STDERR','MALFORMED','TIMEOUT')
$diagnostics = [ordered]@{}
foreach ($mode in $modes) { $diagnostics[$mode] = Invoke-DiagnosticCase $mode $(if ($mode -ceq 'TIMEOUT') { 1 } else { 10 }) $casesRoot $windowsPowerShell $python (Sha $python) $endpoint }
Require ([string]$diagnostics.PASS.childOutcome -ceq 'PASS' -and [int]$diagnostics.PASS.childExitCode -eq 0 -and [bool]$diagnostics.PASS.expectedRunnerResultMatched) 'O3F15L3 packaged PASS projection changed.'
Require ([string]$diagnostics.NONZERO_BOTH.childOutcome -ceq 'FAIL' -and [int]$diagnostics.NONZERO_BOTH.childExitCode -eq 7 -and [int]$diagnostics.NONZERO_BOTH.stdoutBytes -gt 0 -and [int]$diagnostics.NONZERO_BOTH.stderrBytes -gt 0) 'O3F15L3 packaged NONZERO_BOTH projection changed.'
Require ([string]$diagnostics.ZERO_STDERR.childOutcome -ceq 'FAIL' -and [int]$diagnostics.ZERO_STDERR.childExitCode -eq 0 -and [int]$diagnostics.ZERO_STDERR.stderrBytes -gt 0 -and [bool]$diagnostics.ZERO_STDERR.expectedRunnerResultMatched) 'O3F15L3 packaged ZERO_STDERR projection changed.'
Require ([string]$diagnostics.MALFORMED.childOutcome -ceq 'FAIL' -and -not [bool]$diagnostics.MALFORMED.parsedJsonObject) 'O3F15L3 packaged MALFORMED projection changed.'
Require ([string]$diagnostics.TIMEOUT.childOutcome -ceq 'FAIL' -and [bool]$diagnostics.TIMEOUT.childTimedOut -and [int]$diagnostics.TIMEOUT.stdoutBytes -gt 0 -and [int]$diagnostics.TIMEOUT.stderrBytes -gt 0) 'O3F15L3 packaged TIMEOUT projection changed.'
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$signer = Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + ([string]$identity.thumbprint).Replace(' ','')) -ErrorAction Stop
Require ([bool]$signer.HasPrivateKey) 'O3F15L3 installer-rehearsal signing key is absent.'
$installerRoot = Join-Path $fixtureRoot 'installer'
[void](New-Item -ItemType Directory -Path $installerRoot)
$installerCases = @(
    Invoke-MaintenanceCase 'APPROVED' $extract $installerRoot $carrier $true $signer $endpointWorker $packageTester $responseVerifier $certificate
    Invoke-MaintenanceCase 'IDEMPOTENT' $extract $installerRoot $carrier $true $signer $endpointWorker $packageTester $responseVerifier $certificate
    Invoke-MaintenanceCase 'UNAPPROVED' $extract $installerRoot $carrier $false $signer $endpointWorker $packageTester $responseVerifier $certificate
)
Require ($installerCases.Count -eq 3 -and @($installerCases | Where-Object { [string]$_.endpointState -ceq 'PASS_MAINTENANCE_PATCH' }).Count -eq 2 -and @($installerCases | Where-Object { [bool]$_.refusedBeforeMutation }).Count -eq 1) 'O3F15L3 maintenance case set changed.'
$gate = [ordered]@{ schema='argos_ocv03_o3f15l3_final_zip_rehearsal_gate_v1'; createdUtc=[DateTime]::UtcNow.ToString('o'); state='PASS_O3F15L3_FINAL_ZIP_WINDOWS_PS51_REHEARSAL'; requestId=$requestId; packageZipPath=$zip; packageZipBytes=[int64](Get-Item -LiteralPath $zip).Length; packageZipSha256=[string]$signGate.packageZipSha256; windowsPowerShell=@{major=5;minor=1}; exactSignedZipExtracted=$true; signatureVerified=$true; payloadHashCount=@($manifest.files).Count; packageLeafState=[string]$leaf.state; exactDiagnosticCaseCount=$modes.Count; diagnosticCases=@($modes | ForEach-Object { [ordered]@{mode=$_;childOutcome=[string]$diagnostics[$_].childOutcome;childExitCode=[int]$diagnostics[$_].childExitCode;childTimedOut=[bool]$diagnostics[$_].childTimedOut;stdoutSha256=[string]$diagnostics[$_].stdoutSha256;stderrSha256=[string]$diagnostics[$_].stderrSha256} }); rawStreamsProjectedBeforeSuccessPredicate=$true; exactOwnedChildCountPerCase=1; selfTestStarted=$false; gateStarted=$false; runStarted=$false; detectorResultRootCreated=$false; imageBytesRead=$false; maintenanceValidationCaseCount=$installerCases.Count; maintenanceValidationCases=$installerCases; approvedPredecessorExercisedThroughEndpointWorker=$true; targetHashIdempotentCasePassed=$true; unapprovedPredecessorRefusedBeforeMutation=$true; endpointWorkerSha256=[string]$contract.inheritedRoute.endpointWorkerSha256; installedRouteConfigEvidenceSha256=[string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256; queueSafetyGateSha256=[string]$contract.inheritedRoute.queueSafetyGateSha256; exactEndpointQueueRollbackRehearsalInherited=$true; fixtureRoot=$fixtureRoot; fixturePreserved=$true; targetOrJbodAccessed=$false; sourceImageBytesRead=$false; existingProcessesQueried=$false; existingProcessOrTaskActionPerformed=$false; providerActivated=$false; requestRetryAuthorized=$false; mutationsPerformed=$false; reviewOnly=$true; trainingEligible=$false; xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false }
Write-NewJson $gatePath $gate
$gate | ConvertTo-Json -Depth 12
