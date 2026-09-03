#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Sha-Bytes([byte[]]$Bytes) {
    if ($null -eq $Bytes) { $Bytes = [byte[]]::new(0) }
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash([byte[]]$Bytes))).Replace('-','') }
    finally { $algorithm.Dispose() }
}
function Sha-Text([string]$Value) {
    [byte[]]$bytes = [Text.Encoding]::UTF8.GetBytes($Value)
    Sha-Bytes $bytes
}
function Required([object]$Object, [string]$Name) {
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "O3F15L3 R2 required response property absent: $Name" }
    $property.Value
}
function Read-EntryBytes([IO.Compression.ZipArchiveEntry]$Entry, [int64]$MaximumBytes) {
    Require ($Entry.Length -le $MaximumBytes) "O3F15L3 R2 response entry exceeds its bound: $($Entry.FullName)"
    $stream = $Entry.Open()
    $memory = New-Object IO.MemoryStream
    try { $stream.CopyTo($memory); return ,([byte[]]$memory.ToArray()) }
    finally { $memory.Dispose(); $stream.Dispose() }
}
function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L3 R2 create-new collection gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

Require ($Preflight -xor $Collect) 'Specify exactly one of -Preflight or -Collect.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'O3F15L3 R2 collector requires exact Windows PowerShell 5.1.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocation = Join-Path $PSScriptRoot 'O3F15L3_RESPONSE_COLLECTION_R2_INVOCATION.json'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require ($invocationPath.Equals($expectedInvocation, [StringComparison]::OrdinalIgnoreCase)) 'O3F15L3 R2 response collection invocation path changed.'
$signGatePath = Join-Path $PSScriptRoot 'O3F15L3_SIGN_GATE.json'
$publishGatePath = Join-Path $PSScriptRoot 'O3F15L3_PUBLISH_GATE.json'
$verifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
foreach ($path in @($invocationPath,$signGatePath,$publishGatePath,$verifier)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 R2 collection dependency absent: $path" }
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
$signGate = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
$publishGate = Get-Content -LiteralPath $publishGatePath -Raw | ConvertFrom-Json
Require ([string]$invocation.schema -ceq 'argos_ocv03_o3f15l3_response_collection_r2_invocation_v1' -and [string]$invocation.state -ceq 'FROZEN_EXACT_RESPONSE_COLLECTION_R2_INVOCATION') 'O3F15L3 R2 collection invocation is not frozen.'
Require ([string]$invocation.collectorSha256 -ceq (Sha $PSCommandPath) -and -not [bool]$invocation.requestRetryAuthorized) 'O3F15L3 R2 collector authority changed.'
$requestId = [string](Required $invocation 'requestId')
$responseId = [string](Required $invocation 'responseId')
$sourceZip = [IO.Path]::GetFullPath([string](Required $invocation 'sourceZip'))
$zipBytes = [int64](Required $invocation 'sourceZipBytes')
$zipHash = [string](Required $invocation 'sourceZipSha256')
$localRoot = [IO.Path]::GetFullPath([string](Required $invocation 'localRoot'))
$certificate = Join-Path $project ([string](Required $invocation 'endpointCertificate'))
Require ($localRoot -ceq 'C:\O3F15L3C2') 'O3F15L3 R2 collection root changed.'
Require ([string]$signGate.state -ceq 'PASS_O3F15L3_SIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE' -and [string]$signGate.requestId -ceq $requestId) 'O3F15L3 R2 sign gate does not match collection invocation.'
Require ([string]$publishGate.state -ceq 'PASS_O3F15L3_PUBLISHED_EXACTLY_ONCE_AWAITING_SIGNED_DIAGNOSTIC_RESPONSE' -and [string]$publishGate.requestId -ceq $requestId -and [int]$publishGate.publicationCount -eq 1 -and -not [bool]$publishGate.automaticRetryAuthorized) 'O3F15L3 R2 publish gate does not match collection invocation.'
Require (Test-Path -LiteralPath $certificate -PathType Leaf) 'O3F15L3 R2 endpoint certificate is absent.'
Require ((Sha $certificate) -ceq [string]$invocation.endpointCertificateSha256 -and [string]$invocation.endpointCertificateSha256 -ceq '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B') 'O3F15L3 R2 endpoint certificate changed.'
$cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2([IO.Path]::GetFullPath($certificate))
Require ($cert.Thumbprint.ToUpperInvariant() -ceq ([string]$invocation.expectedSignerThumbprint).Replace(' ','').ToUpperInvariant() -and $cert.Thumbprint.ToUpperInvariant() -ceq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'O3F15L3 R2 endpoint signer changed.'
$expectedShare = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -ceq $expectedShare -and [string]$disk.ProviderName -ceq $expectedShare -and [int]$disk.DriveType -eq 4) 'O3F15L3 R2 qualified persistent U: mapping changed.'
$responses = [IO.Path]::GetFullPath('U:\ProjectPortalRO\responses')
Require ($sourceZip.StartsWith(($responses.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) 'O3F15L3 R2 response ZIP is outside the qualified response root.'
Require (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'O3F15L3 R2 response ZIP is absent.'
Require ((Get-Item -LiteralPath $sourceZip).Length -eq $zipBytes -and (Sha $sourceZip) -ceq $zipHash) 'O3F15L3 R2 response ZIP changed.'
$localZip = Join-Path $localRoot ([IO.Path]::GetFileName($sourceZip))
$partial = Join-Path $localRoot ($responseId + '.partial')
$ready = Join-Path $localRoot ($responseId + '.ready')
$gatePath = Join-Path $PSScriptRoot 'O3F15L3_RESPONSE_COLLECTION_R2_GATE.json'
foreach ($path in @($localRoot,$gatePath)) { Require (-not (Test-Path -LiteralPath $path)) "O3F15L3 R2 create-new collection target exists: $path" }
$pathGate = & (Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1') -CandidatePath @($localZip,(Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $partial 'MAINTENANCE.stdout.txt'),(Join-Path $ready 'PORTAL_RESPONSE_MANIFEST.sig'),$gatePath) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$pathGate.state -ceq 'PASS_PATH_BUDGET') 'O3F15L3 R2 response collection path gate failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $fileEntries = @($archive.Entries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) })
    Require ($fileEntries.Count -ge 3 -and $fileEntries.Count -le 8) 'O3F15L3 R2 response ZIP file cardinality is outside its bound.'
    Require (@($fileEntries.FullName | Sort-Object -Unique).Count -eq $fileEntries.Count) 'O3F15L3 R2 response ZIP contains duplicate paths.'
    foreach ($entry in $fileEntries) { Require (-not [IO.Path]::IsPathRooted($entry.FullName) -and $entry.FullName -notmatch '(^|[\/])\.\.([\/]|$)' -and $entry.FullName.Length -le 80 -and $entry.Length -le 1048576) "O3F15L3 R2 unsafe response ZIP entry: $($entry.FullName)" }
    $manifestEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    $signatureEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.sig')
    Require ($null -ne $manifestEntry -and $null -ne $signatureEntry) 'O3F15L3 R2 response manifest or signature entry is absent.'
    $manifestBytes = Read-EntryBytes $manifestEntry 65536
    $signatureBytes = Read-EntryBytes $signatureEntry 16384
    $manifest = [Text.Encoding]::UTF8.GetString([byte[]]$manifestBytes) | ConvertFrom-Json
    $manifestSha = Sha-Bytes ([byte[]]$manifestBytes)
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
    try { $signatureValid = $rsa.VerifyData([byte[]]$manifestBytes, [byte[]]$signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
    Require $signatureValid 'O3F15L3 R2 response signature is invalid.'
    Require ([string](Required $manifest 'schema') -ceq 'argos_project_portal_response_manifest_v1' -and [string](Required $manifest 'requestId') -ceq $requestId -and [string](Required $manifest 'responseId') -ceq $responseId -and [string](Required $manifest 'sourceRole') -ceq 'JBOD') 'O3F15L3 R2 response identity changed.'
    Require ([bool](Required $manifest 'reviewOnly') -and -not [bool](Required $manifest 'trainingEligible') -and -not [bool](Required $manifest 'xmlEligible') -and -not [bool](Required $manifest 'productionEligible') -and -not [bool](Required $manifest 'productionRoutingEnabled')) 'O3F15L3 R2 response authority widened.'
    $endpointState = [string](Required $manifest 'state')
    Require ($endpointState -in @('PASS_MAINTENANCE_PATCH','FAILED','FAILED_RESPONSE_CONSTRUCTION')) 'O3F15L3 R2 response is not a recognized terminal state.'
    $expectedEntries = @('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig') + @($manifest.files | ForEach-Object { [string]$_.path })
    Require ($expectedEntries.Count -eq $fileEntries.Count -and @(Compare-Object ($expectedEntries | Sort-Object) ($fileEntries.FullName | Sort-Object)).Count -eq 0) 'O3F15L3 R2 response ZIP entry set differs from its signed manifest.'
    foreach ($record in @($manifest.files)) {
        $entry = $archive.GetEntry([string]$record.path)
        Require ($null -ne $entry -and $entry.Length -eq [int64]$record.bytes) "O3F15L3 R2 signed response entry length changed: $($record.path)"
        Require ((Sha-Bytes ([byte[]](Read-EntryBytes $entry 1048576))) -ceq [string]$record.sha256) "O3F15L3 R2 signed response entry hash changed: $($record.path)"
    }
} finally { $archive.Dispose() }

if ($Preflight) {
    [ordered]@{ schema='argos_ocv03_o3f15l3_response_collection_r2_preflight_v1'; state='PASS_O3F15L3_RESPONSE_COLLECTION_R2_PREFLIGHT'; requestId=$requestId; responseId=$responseId; endpointState=$endpointState; sourceZipBytes=$zipBytes; sourceZipSha256=$zipHash; sourceManifestSha256=$manifestSha; signedEntryCount=$fileEntries.Count; signatureVerified=$true; pathState=[string]$pathGate.state; mutationsPerformed=$false; requestRetryAuthorized=$false; imageBytesRead=$false; reviewOnly=$true; productionRoutingEnabled=$false } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $localRoot)
[IO.File]::Copy($sourceZip, $localZip, $false)
Require ((Sha $localZip) -ceq $zipHash) 'O3F15L3 R2 local response ZIP changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partial)
Require ((Sha (Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.json')) -ceq $manifestSha) 'O3F15L3 R2 extracted response manifest changed.'
& $verifier -PackagePath $partial -EndpointCertificatePath $certificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
$diagnosticCaptured = $false; $childOutcome = $null; $childExitCode = $null; $childTimedOut = $null; $stdoutSha = $null; $stderrSha = $null; $maintenanceState = $null
if ($endpointState -ceq 'PASS_MAINTENANCE_PATCH') {
    $stdoutPath = Join-Path $partial 'MAINTENANCE.stdout.txt'; $stderrPath = Join-Path $partial 'MAINTENANCE.stderr.txt'; $resultPath = Join-Path $partial 'RESULT.json'
    foreach ($path in @($stdoutPath,$stderrPath,$resultPath)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 R2 successful response file absent: $path" }
    Require ((Get-Item -LiteralPath $stderrPath).Length -eq 0 -and (Get-Item -LiteralPath $stdoutPath).Length -le 1048576) 'O3F15L3 R2 maintenance output bounds changed.'
    $lines = @(Get-Content -LiteralPath $stdoutPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Require ($lines.Count -eq 1) 'O3F15L3 R2 diagnostic stdout line count changed.'
    $diagnostic = $lines[0] | ConvertFrom-Json; $maintenance = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    Require ([string](Required $maintenance 'state') -ceq 'PASS_MAINTENANCE_PATCH' -and [int](Required $maintenance 'exitCode') -eq 0 -and [int](Required $maintenance 'changedFiles') -eq 1 -and [bool](Required $maintenance 'reviewOnly') -and -not [bool](Required $maintenance 'productionRoutingEnabled')) 'O3F15L3 R2 maintenance result changed.'
    Require ([string](Required $diagnostic 'schema') -ceq 'argos_ocv03_o3f15l3_preflight_diagnostic_v1' -and [string](Required $diagnostic 'state') -ceq 'COMPLETE_O3F15L3_PREFLIGHT_DIAGNOSTIC_CAPTURED' -and -not [bool](Required $diagnostic 'rehearsal')) 'O3F15L3 R2 signed diagnostic envelope changed.'
    Require ([string](Required $diagnostic 'childOutcome') -in @('PASS','FAIL') -and [int](Required $diagnostic 'ownedChildCount') -eq 1 -and [int](Required $diagnostic 'maximumOwnedChildCount') -eq 1) 'O3F15L3 R2 signed one-child result changed.'
    $args = @((Required $diagnostic 'childArguments'))
    Require ($args.Count -eq 4 -and [string]$args[0] -ceq '-I' -and [string]$args[1] -ceq '-B' -and [IO.Path]::GetFileName([string]$args[2]) -ceq 'Run-O3F15FrontReconcile.py' -and [string]$args[3] -ceq 'PREFLIGHT' -and [IO.Path]::GetDirectoryName([string]$args[2]) -ceq [string](Required $diagnostic 'childWorkingDirectory')) 'O3F15L3 R2 signed child command changed.'
    Require ([string](Required $diagnostic 'childExecutable') -ceq 'D:/AFCV1/rt/python.exe' -and -not [bool](Required $diagnostic 'selfTestStarted') -and -not [bool](Required $diagnostic 'gateStarted') -and -not [bool](Required $diagnostic 'runStarted') -and -not [bool](Required $diagnostic 'detectorResultRootCreated') -and -not [bool](Required $diagnostic 'corpusStarted') -and -not [bool](Required $diagnostic 'imageBytesRead') -and -not [bool](Required $diagnostic 'sourceMutation') -and -not [bool](Required $diagnostic 'providerActivated') -and -not [bool](Required $diagnostic 'mutationsPerformed')) 'O3F15L3 R2 signed diagnostic authority widened.'
    Require ([int](Required $diagnostic 'stdoutTailCharacters') -le 2000 -and [int](Required $diagnostic 'stdoutTailBytes') -le 8000 -and [int](Required $diagnostic 'stderrTailCharacters') -le 2000 -and [int](Required $diagnostic 'stderrTailBytes') -le 8000) 'O3F15L3 R2 signed diagnostic tails exceeded their bounds.'
    if (-not [bool](Required $diagnostic 'stdoutTruncated')) { Require (([string](Required $diagnostic 'stdoutSha256')) -ceq (Sha-Text ([string](Required $diagnostic 'stdoutTail')))) 'O3F15L3 R2 signed diagnostic stdout hash changed.' }
    if (-not [bool](Required $diagnostic 'stderrTruncated')) { Require (([string](Required $diagnostic 'stderrSha256')) -ceq (Sha-Text ([string](Required $diagnostic 'stderrTail')))) 'O3F15L3 R2 signed diagnostic stderr hash changed.' }
    $diagnosticCaptured = $true; $childOutcome = [string]$diagnostic.childOutcome; $childExitCode = [int]$diagnostic.childExitCode; $childTimedOut = [bool]$diagnostic.childTimedOut; $stdoutSha = [string]$diagnostic.stdoutSha256; $stderrSha = [string]$diagnostic.stderrSha256; $maintenanceState = [string]$maintenance.state
} else {
    $failurePath = Join-Path $partial 'FAILURE.json'; Require (Test-Path -LiteralPath $failurePath -PathType Leaf) 'O3F15L3 R2 signed terminal failure lacks FAILURE.json.'
    $failure = Get-Content -LiteralPath $failurePath -Raw | ConvertFrom-Json
    Require ([string](Required $failure 'state') -in @('FAILED','FAILED_RESPONSE_CONSTRUCTION') -and [bool](Required $failure 'reviewOnly') -and -not [bool](Required $failure 'productionRoutingEnabled')) 'O3F15L3 R2 signed terminal failure changed.'
}
[IO.Directory]::Move($partial, $ready)
$gate = [ordered]@{ schema='argos_ocv03_o3f15l3_response_collection_r2_gate_v1'; collectedUtc=[DateTime]::UtcNow.ToString('o'); state='COMPLETE_O3F15L3_MATCHING_SIGNED_TERMINAL_RESPONSE_COLLECTED'; collectorRevision='R2'; requestId=$requestId; responseId=$responseId; responseZipPath=$localZip; responseZipBytes=$zipBytes; responseZipSha256=$zipHash; responseManifestSha256=$manifestSha; responseSignatureVerified=$true; endpointState=$endpointState; diagnosticCaptured=$diagnosticCaptured; childOutcome=$childOutcome; childExitCode=$childExitCode; childTimedOut=$childTimedOut; childStdoutSha256=$stdoutSha; childStderrSha256=$stderrSha; maintenanceState=$maintenanceState; exactOwnedChildCount=$(if ($diagnosticCaptured) {1} else {$null}); fullFrontsideHoldCount=184; currentPatternedFrontHoldCount=12; slot02AmbiguityPreserved=$true; rareHotspotSlot16Preserved=$true; selfTestStarted=$false; gateStarted=$false; runStarted=$false; resultRootCreated=$false; corpusStarted=$false; imageBytesRead=$false; sourceMutationPerformed=$false; sourceDeletionPerformed=$false; existingTaskActionCount=0; existingProcessActionCount=0; providerActivated=$false; holdsAutomaticallyCleared=$false; requestRetryAuthorized=$false; reviewOnly=$true; trainingEligible=$false; xmlEligible=$false; productionEligible=$false; productionRoutingEnabled=$false }
Write-NewJson $gatePath $gate
$gate | ConvertTo-Json -Depth 10
