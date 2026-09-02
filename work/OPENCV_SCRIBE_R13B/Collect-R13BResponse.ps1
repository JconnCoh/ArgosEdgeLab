#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Collect) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-ByteSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Resolve-ProjectFile([string]$ProjectRoot, [string]$RelativePath, [string]$Label) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) "$Label path is empty."
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "$Label path must be project-relative: $RelativePath"
    $normalized = $RelativePath.Replace('/', '\')
    Assert-True ($normalized -notmatch '(^|\\)\.\.(\\|$)') "$Label path traverses outside the project: $RelativePath"
    $prefix = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $normalized))
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "$Label path escapes the project: $RelativePath"
    return $full
}

function Assert-PinnedFile([string]$Path, [string]$ExpectedSha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $ExpectedSha256.ToUpperInvariant()) "$Label hash changed: $Path"
}

function Normalize-Root([string]$Path) {
    return $Path.Replace('/', '\').TrimEnd('\')
}

function Get-SafeChildPath([string]$Root, [string]$RelativePath) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'Archive-relative path is empty.'
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "Archive path is rooted: $RelativePath"
    $normalized = $RelativePath.Replace('/', '\')
    Assert-True ($normalized -notmatch '(^|\\)\.\.(\\|$)') "Archive path traverses outside the root: $RelativePath"
    foreach ($component in $normalized.Split('\')) { Assert-True ($component.Length -le 80) "Archive path component exceeds 80 characters: $component" }
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath((Join-Path $Root $normalized))
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "Archive path escapes the root: $RelativePath"
    return $full
}

function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Archive, [string]$Name, [int64]$MaximumBytes, [string]$Label) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry) "$Label entry is absent: $Name"
    Assert-True ([int64]$entry.Length -le $MaximumBytes) "$Label entry exceeds its byte bound: $Name"
    $stream = $entry.Open()
    $memory = New-Object IO.MemoryStream
    try {
        $stream.CopyTo($memory)
        $bytes = $memory.ToArray()
    }
    finally { $memory.Dispose(); $stream.Dispose() }
    Assert-True ([int64]$bytes.Length -eq [int64]$entry.Length) "$Label entry read length changed: $Name"
    return ,([byte[]]$bytes)
}

function Read-ResponseCandidate([string]$Path, [string]$ExpectedRequestId, [Security.Cryptography.X509Certificates.X509Certificate2]$Certificate, [object]$Limits) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entries = @($archive.Entries)
        Assert-True ($entries.Count -le [int]$Limits.maximumResponseZipEntries) 'Response ZIP entry bound was exceeded.'
        $manifestBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.json' ([int64]$Limits.maximumManifestBytes) 'response'
        $manifestText = (New-Object Text.UTF8Encoding($false, $true)).GetString($manifestBytes)
        $manifest = $manifestText | ConvertFrom-Json
        if ([string]$manifest.requestId -ne $ExpectedRequestId) { return $null }
        $expectedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','RESULT.json') | Sort-Object
        $actualNames = @($entries | ForEach-Object { [string]$_.FullName } | Sort-Object)
        Assert-True ($actualNames.Count -eq $expectedNames.Count -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $actualNames).Count -eq 0) 'R13B response ZIP exact entry set changed.'
        $signatureBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' ([int64]$Limits.maximumSignatureBytes) 'response'
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
        try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
        finally { $rsa.Dispose() }
        Assert-True $signatureValid 'R13B matching response signature is invalid.'
        Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.sourceRole -eq 'JBOD') 'R13B matching response schema/source role changed.'
        Assert-True ([string]$manifest.signatureAlgorithm -eq 'RSA-SHA256-PKCS1' -and ([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $Certificate.Thumbprint.Replace(' ','').ToUpperInvariant()) 'R13B matching response signer changed.'
        Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R13B matching response authority widened.'
        $records = @($manifest.files)
        Assert-True ($records.Count -eq 3) 'R13B matching response signed-file cardinality changed.'
        $signedNames = @($records | ForEach-Object { [string]$_.path } | Sort-Object)
        $expectedSignedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','RESULT.json') | Sort-Object
        Assert-True (@(Compare-Object -ReferenceObject $expectedSignedNames -DifferenceObject $signedNames).Count -eq 0) 'R13B matching response signed-file names changed.'
        foreach ($record in $records) {
            $name = [string]$record.path
            $limit = if ($name -eq 'MAINTENANCE.stdout.txt') { [int64]$Limits.maximumStdoutBytes } else { [int64]$Limits.maximumSmallResponseFileBytes }
            $bytes = Read-ZipEntryBytes $archive $name $limit 'signed response'
            Assert-True ([int64]$bytes.Length -eq [int64]$record.bytes -and (Get-ByteSha256 $bytes) -eq ([string]$record.sha256).ToUpperInvariant()) "R13B matching signed response leaf changed: $name"
        }
        $stdoutBytes = Read-ZipEntryBytes $archive 'MAINTENANCE.stdout.txt' ([int64]$Limits.maximumStdoutBytes) 'maintenance stdout'
        return [pscustomobject]@{Path=$Path;Manifest=$manifest;ManifestBytes=$manifestBytes;StdoutBytes=$stdoutBytes;ZipBytes=[int64](Get-Item -LiteralPath $Path).Length;ZipSha256=Get-Sha256 $Path}
    }
    finally { $archive.Dispose() }
}

function Test-BundleBytes([byte[]]$BundleBytes, [object]$Envelope, [object]$Limits, [string[]]$ExpectedCaseIds) {
    Assert-True ([int64]$BundleBytes.Length -eq [int64]$Envelope.bundleBytes) 'R13B decoded bundle byte count changed.'
    Assert-True ((Get-ByteSha256 $BundleBytes) -eq ([string]$Envelope.bundleSha256).ToUpperInvariant()) 'R13B decoded bundle hash changed.'
    $memory = New-Object IO.MemoryStream
    $memory.Write($BundleBytes, 0, $BundleBytes.Length)
    $memory.Position = 0
    $archive = New-Object IO.Compression.ZipArchive($memory, [IO.Compression.ZipArchiveMode]::Read, $false)
    try {
        $allEntries = @($archive.Entries)
        Assert-True ($allEntries.Count -le [int]$Limits.maximumBundleEntries) 'R13B bundle entry bound was exceeded.'
        foreach ($archiveEntry in $allEntries) {
            $archiveName = ([string]$archiveEntry.FullName).Replace('\','/').TrimEnd('/')
            Assert-True (-not [string]::IsNullOrWhiteSpace($archiveName)) 'R13B bundle contains an empty archive path.'
            [void](Get-SafeChildPath 'C:\R13BR\b' $archiveName)
        }
        $entries = @($allEntries | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Name) })
        $total = [int64]0
        $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $entries) {
            $name = ([string]$entry.FullName).Replace('\','/')
            Assert-True ($seen.Add($name)) "R13B duplicate bundle path: $name"
            Assert-True ([int64]$entry.Length -le [int64]$Limits.maximumBundleEntryBytes) "R13B bundle entry is too large: $name"
            $total += [int64]$entry.Length
            Assert-True ($total -le [int64]$Limits.maximumBundleExpandedBytes) 'R13B expanded bundle byte bound was exceeded.'
        }
        foreach ($required in @('BATCH_GATE.json','EXECUTION.json')) { Assert-True ($seen.Contains($required)) "R13B bundle required leaf is absent: $required" }
        foreach ($caseId in $ExpectedCaseIds) { Assert-True ($seen.Contains($caseId + '/CASE_RESULT.json')) "R13B case result is absent: $caseId" }
        $batchBytes = Read-ZipEntryBytes $archive 'BATCH_GATE.json' ([int64]$Limits.maximumJsonBytes) 'bundle'
        $executionBytes = Read-ZipEntryBytes $archive 'EXECUTION.json' ([int64]$Limits.maximumJsonBytes) 'bundle'
        $batch = (New-Object Text.UTF8Encoding($false, $true)).GetString($batchBytes) | ConvertFrom-Json
        $execution = (New-Object Text.UTF8Encoding($false, $true)).GetString($executionBytes) | ConvertFrom-Json
        Assert-True ([string]$batch.schema -eq 'argos_opencv_scribe_r13b_batch_gate_v1' -and [string]$batch.state -eq 'PASS_R13B_BATCH_COMPLETE' -and [string]$batch.requestId -eq 'REQ_20260902T204408092Z_R13B' -and -not [bool]$batch.rehearsal) 'R13B returned batch gate changed.'
        Assert-True ([string]$execution.schema -eq 'argos_opencv_scribe_r13b_execution_v1' -and [string]$execution.state -eq 'PASS_R13B_EXECUTION' -and [string]$execution.requestId -eq 'REQ_20260902T204408092Z_R13B' -and -not [bool]$execution.rehearsal) 'R13B returned execution evidence changed.'
        Assert-True ([string]$execution.batchGateSha256 -eq (Get-ByteSha256 $batchBytes)) 'R13B execution does not bind the returned batch gate.'
        Assert-True ([int]$batch.caseCount -eq $ExpectedCaseIds.Count -and @($batch.cases).Count -eq $ExpectedCaseIds.Count -and [int]$execution.caseCount -eq $ExpectedCaseIds.Count) 'R13B returned case cardinality changed.'
        foreach ($object in @($batch,$execution)) { Assert-True (-not [bool]$object.sourceMutationPerformed -and -not [bool]$object.sourceDeletionPerformed -and -not [bool]$object.taskOrProcessRestarted -and -not [bool]$object.providerActivated -and [bool]$object.reviewOnly -and -not [bool]$object.trainingEligible -and -not [bool]$object.xmlEligible -and -not [bool]$object.productionEligible -and -not [bool]$object.productionRoutingEnabled) 'R13B returned execution authority widened.' }
        foreach ($caseId in $ExpectedCaseIds) {
            $row = @($batch.cases | Where-Object { [string]$_.caseId -eq $caseId })
            Assert-True ($row.Count -eq 1) "R13B batch case identity is absent or duplicated: $caseId"
            $caseBytes = Read-ZipEntryBytes $archive ($caseId + '/CASE_RESULT.json') ([int64]$Limits.maximumJsonBytes) 'case result'
            Assert-True ((Get-ByteSha256 $caseBytes) -eq ([string]$row[0].caseResultSha256).ToUpperInvariant()) "R13B batch does not bind case result: $caseId"
            $case = (New-Object Text.UTF8Encoding($false, $true)).GetString($caseBytes) | ConvertFrom-Json
            Assert-True ([string]$case.schema -eq 'argos_opencv_scribe_alphabet_crop_case_result_v1' -and [string]$case.caseId -eq $caseId -and [string]$case.state -like 'HOLD_*') "R13B case contract changed: $caseId"
            if ([string]$case.state -eq 'HOLD_R13B_CASE_LAUNCH_FAILURE') {
                Assert-True ([bool]$case.authority.reviewOnly -and -not [bool]$case.authority.automaticIdentityAuthority -and -not [bool]$case.authority.automaticReferenceAdmissionAllowed -and -not [bool]$case.authority.trainingEligible -and -not [bool]$case.authority.xmlEligible -and -not [bool]$case.authority.productionEligible -and -not [bool]$case.authority.productionRoutingEnabled -and -not [bool]$case.authority.mayClearHolds) "R13B launch-failure case authority widened: $caseId"
            }
            else {
                Assert-True ([string]$case.classification -eq 'PENDING_GATE' -and -not [bool]$case.eligibleIdentity -and -not [bool]$case.referenceAdmissionEligible) "R13B case authority widened: $caseId"
            }
            foreach ($artifact in @($case.artifacts)) {
                $artifactName = $caseId + '/' + ([string]$artifact.relativePath).Replace('\','/')
                Assert-True ($seen.Contains($artifactName)) "R13B declared artifact is absent: $artifactName"
                $artifactBytes = Read-ZipEntryBytes $archive $artifactName ([int64]$Limits.maximumBundleEntryBytes) 'case artifact'
                Assert-True ((Get-ByteSha256 $artifactBytes) -eq ([string]$artifact.sha256).ToUpperInvariant()) "R13B declared artifact hash changed: $artifactName"
            }
        }
        return [pscustomobject]@{EntryCount=$allEntries.Count;ExpandedBytes=$total;Batch=$batch;Execution=$execution;EntryNames=@($allEntries | ForEach-Object { ([string]$_.FullName).Replace('\','/').TrimEnd('/') })}
    }
    finally { $archive.Dispose(); $memory.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'R13B response collection invocation is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_r13b_response_collection_invocation_v1') 'R13B response collection invocation schema changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260902T204408092Z_R13B') 'R13B response collection request identity changed.'
Assert-True ((Get-Sha256 $MyInvocation.MyCommand.Path) -eq [string]$invocation.collectorSha256) 'R13B response collector self-pin changed.'
Assert-True ([int]$invocation.maximumMatchingResponses -eq 1 -and -not [bool]$invocation.requestRetryAuthorized -and [bool]$invocation.matchingSignedTerminalResponseOnly) 'R13B response correlation/retry boundary changed.'
Assert-True ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.automaticIdentityAuthority -and -not [bool]$invocation.authority.trainingEligible -and -not [bool]$invocation.authority.xmlEligible -and -not [bool]$invocation.authority.productionEligible -and -not [bool]$invocation.authority.productionRoutingEnabled -and -not [bool]$invocation.authority.providerActivationAllowed) 'R13B response collection authority widened.'

foreach ($gatePin in @($invocation.requiredGates)) {
    $gatePath = Resolve-ProjectFile $project ([string]$gatePin.path) 'collection gate dependency'
    Assert-PinnedFile $gatePath ([string]$gatePin.sha256) 'R13B collection gate dependency'
    $gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json
    $property = [string]$gatePin.stateProperty
    Assert-True ([string]$gate.$property -eq [string]$gatePin.requiredState) "R13B collection dependency state changed: $($gatePin.path)"
}

$certificatePath = Resolve-ProjectFile $project ([string]$invocation.responseSigner.certificatePath) 'JBOD response signer certificate'
$verifierPath = Resolve-ProjectFile $project ([string]$invocation.responseSigner.verifierPath) 'signed response verifier'
Assert-PinnedFile $certificatePath ([string]$invocation.responseSigner.certificateSha256) 'R13B JBOD response signer certificate'
Assert-PinnedFile $verifierPath ([string]$invocation.responseSigner.verifierSha256) 'R13B signed response verifier'
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
try {
    Assert-True ($certificate.Thumbprint.Replace(' ','').ToUpperInvariant() -eq ([string]$invocation.responseSigner.thumbprint).Replace(' ','').ToUpperInvariant()) 'R13B JBOD response signer thumbprint changed.'
    $shareRoot = [string]$invocation.route.inspectionRevsUnc
    Assert-True ($shareRoot -eq '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs') 'R13B response route changed.'
    $psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
    Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R13B response U: PowerShell mapping changed.'
    Assert-True ([int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R13B response U: is not the exact persistent network mapping.'
    $responseRoot = 'U:\ProjectPortalRO\responses'
    Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'R13B response share is unavailable.'
    $responseFiles = @(Get-ChildItem -LiteralPath $responseRoot -File -ErrorAction Stop | Where-Object { $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) } | Select-Object -First ([int]$invocation.limits.maximumResponseFiles + 1))
    Assert-True ($responseFiles.Count -le [int]$invocation.limits.maximumResponseFiles) 'R13B response file scan bound was exceeded.'
    $matches = New-Object Collections.Generic.List[object]
    foreach ($file in $responseFiles) {
        $candidate = Read-ResponseCandidate $file.FullName ([string]$invocation.requestId) $certificate $invocation.limits
        if ($null -ne $candidate) { $matches.Add($candidate) }
    }
    Assert-True ($matches.Count -eq 1) "R13B requires exactly one matching signed response; found $($matches.Count)."
    $match = $matches[0]
    $manifest = $match.Manifest
    Assert-True (@($invocation.allowedTerminalStates) -contains [string]$manifest.state) "R13B response state is not an allowed terminal state: $($manifest.state)"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.responseId)) 'R13B matching response ID is empty.'
    $responseSnapshot = Get-Item -LiteralPath $match.Path
    Assert-True ([int64]$responseSnapshot.Length -eq [int64]$match.ZipBytes -and (Get-Sha256 $match.Path) -eq [string]$match.ZipSha256) 'R13B matching response changed during bounded collection preflight.'

    $envelope = $null
    $bundleBytes = $null
    $bundleEvidence = $null
    if ([string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') {
        $stdoutText = (New-Object Text.UTF8Encoding($false, $true)).GetString([byte[]]$match.StdoutBytes)
        $envelope = $stdoutText | ConvertFrom-Json
        Assert-True ([string]$envelope.schema -eq 'argos_opencv_scribe_r13b_maintenance_envelope_v1' -and [string]$envelope.state -eq 'PASS_R13B_SIGNED_RETURN_READY' -and [string]$envelope.requestId -eq [string]$invocation.requestId -and -not [bool]$envelope.rehearsal) 'R13B maintenance envelope changed.'
        Assert-True ([int]$envelope.caseCount -eq 4 -and [int64]$envelope.bundleBytes -le [int64]$invocation.limits.maximumBundleBytes -and [int]$envelope.bundleBase64Characters -le [int]$invocation.limits.maximumBundleBase64Characters) 'R13B maintenance envelope bounds/cardinality changed.'
        Assert-True ([string]$envelope.bundleBase64 -ne '' -and ([string]$envelope.bundleBase64).Length -eq [int]$envelope.bundleBase64Characters) 'R13B maintenance envelope Base64 length changed.'
        Assert-True (-not [bool]$envelope.automaticRetryAllowed -and -not [bool]$envelope.sourceMutationPerformed -and -not [bool]$envelope.sourceDeletionPerformed -and -not [bool]$envelope.taskOrProcessRestarted -and -not [bool]$envelope.providerActivated -and -not [bool]$envelope.holdsCleared -and [bool]$envelope.reviewOnly -and -not [bool]$envelope.trainingEligible -and -not [bool]$envelope.xmlEligible -and -not [bool]$envelope.productionEligible -and -not [bool]$envelope.productionRoutingEnabled) 'R13B maintenance envelope authority widened.'
        $bundleBytes = [Convert]::FromBase64String([string]$envelope.bundleBase64)
        $bundleEvidence = Test-BundleBytes $bundleBytes $envelope $invocation.limits @($invocation.expectedCaseIds)
    }

    $collectionRoot = Resolve-ProjectFile $project ([string]$invocation.outputRoot) 'response collection root'
    $partialRoot = $collectionRoot + '.partial'
    $collectionGatePath = Join-Path $collectionRoot 'R13B_EXACT_RESPONSE_COLLECTION_GATE.json'
    $shortRoot = [string]$invocation.shortExtractionRoot
    Assert-True ($shortRoot -eq 'C:\R13BR') 'R13B short extraction root changed.'
    foreach ($path in @($collectionRoot,$partialRoot,$shortRoot)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R13B create-new response collection target exists: $path" }
    $plannedPaths = New-Object Collections.Generic.List[string]
    foreach ($path in @((Join-Path $shortRoot 'z.zip'),(Join-Path $shortRoot 'r\PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $shortRoot 'b\BATCH_GATE.json'),(Join-Path $partialRoot 'response\transport.ready.zip'),(Join-Path $partialRoot 'response\PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $partialRoot 'evidence\R13B_RETURN.zip'),$collectionGatePath)) { $plannedPaths.Add($path) }
    if ($null -ne $bundleEvidence) { foreach ($entryName in @($bundleEvidence.EntryNames)) { $plannedPaths.Add((Get-SafeChildPath (Join-Path $partialRoot 'evidence\bundle') ([string]$entryName))) } }
    $pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
    $pathJson = & $pathTool -CandidatePath $plannedPaths.ToArray() -ReservedSuffixCharacters 32 -AsJson | Out-String
    $pathGate = $pathJson | ConvertFrom-Json
    Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R13B response collection path budget failed.'
    $maximumEffectiveLength = [int]((@($pathGate.candidates) | Measure-Object effectiveLength -Maximum).Maximum)
    Assert-True ($maximumEffectiveLength -lt 200) 'R13B response collection path reached effective length 200.'

    $preflightResult = [ordered]@{
        schema='argos_r13b_response_collection_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_EXACT_RESPONSE_COLLECTION_PREFLIGHT';requestId=[string]$invocation.requestId;responseId=[string]$manifest.responseId
        invocationManifestSha256=Get-Sha256 $invocationPath;responseZipBytes=[int64]$match.ZipBytes;responseZipSha256=[string]$match.ZipSha256;endpointState=[string]$manifest.state;sourceRole=[string]$manifest.sourceRole;signerThumbprint=$certificate.Thumbprint
        matchingResponseCount=1;signatureVerifiedInMemory=$true;bundleVerifiedInMemory=($null -ne $bundleEvidence);bundleSha256=if ($null -eq $envelope) {$null} else {[string]$envelope.bundleSha256};bundleBytes=if ($null -eq $envelope) {0} else {[int64]$envelope.bundleBytes}
        pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;mutationsPerformed=$false;requestRetryAuthorized=$false;providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 12; return }

    $shortCreated = $false
    $partialCreated = $false
    try {
        [void][IO.Directory]::CreateDirectory($shortRoot)
        $shortCreated = $true
        $shortZip = Join-Path $shortRoot 'z.zip'
        $shortResponse = Join-Path $shortRoot 'r'
        [IO.File]::Copy([string]$match.Path, $shortZip, $false)
        Assert-True ((Get-Sha256 $shortZip) -eq [string]$match.ZipSha256) 'R13B short response copy changed.'
        [IO.Compression.ZipFile]::ExtractToDirectory($shortZip, $shortResponse)
        $verification = & $verifierPath -PackagePath $shortResponse -EndpointCertificatePath $certificatePath -ExpectedSourceRole JBOD -ExpectedRequestId ([string]$invocation.requestId)
        Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.EndpointState -eq [string]$manifest.state -and ([string]$verification.SignerThumbprint).Replace(' ','').ToUpperInvariant() -eq $certificate.Thumbprint.Replace(' ','').ToUpperInvariant()) 'R13B official signed response verification failed.'
        $shortBundle = $null
        if ($null -ne $bundleEvidence) {
            $shortBundle = Join-Path $shortRoot 'R13B_RETURN.zip'
            [IO.File]::WriteAllBytes($shortBundle, [byte[]]$bundleBytes)
            Assert-True ((Get-Sha256 $shortBundle) -eq [string]$envelope.bundleSha256) 'R13B short decoded bundle changed.'
            [IO.Compression.ZipFile]::ExtractToDirectory($shortBundle, (Join-Path $shortRoot 'b'))
        }

        [void][IO.Directory]::CreateDirectory((Join-Path $partialRoot 'response'))
        [void][IO.Directory]::CreateDirectory((Join-Path $partialRoot 'evidence'))
        $partialCreated = $true
        [IO.File]::Copy($shortZip, (Join-Path $partialRoot 'response\transport.ready.zip'), $false)
        foreach ($leaf in @('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','MAINTENANCE.stdout.txt','MAINTENANCE.stderr.txt','RESULT.json')) { [IO.File]::Copy((Join-Path $shortResponse $leaf), (Join-Path $partialRoot ('response\' + $leaf)), $false) }
        if ($null -ne $bundleEvidence) {
            [IO.File]::Copy($shortBundle, (Join-Path $partialRoot 'evidence\R13B_RETURN.zip'), $false)
            [IO.Directory]::Move((Join-Path $shortRoot 'b'), (Join-Path $partialRoot 'evidence\bundle'))
        }
        [IO.Directory]::Move($partialRoot, $collectionRoot)
        $partialCreated = $false
        [IO.Directory]::Delete($shortRoot, $true)
        $shortCreated = $false
        $gate = [ordered]@{
            schema='argos_r13b_exact_response_collection_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state=if ([string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') {'PASS_R13B_EXACT_SIGNED_TERMINAL_RESPONSE_AND_BUNDLE_COLLECTED'} else {'PASS_R13B_EXACT_SIGNED_TERMINAL_FAILURE_COLLECTED'}
            disposition=if ([string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') {'PENDING_OPERATOR_CROP_REVIEW'} else {'PENDING_GATE'};requestId=[string]$invocation.requestId;responseId=[string]$manifest.responseId;invocationManifestSha256=Get-Sha256 $invocationPath
            responseZipBytes=[int64]$match.ZipBytes;responseZipSha256=[string]$match.ZipSha256;endpointState=[string]$manifest.state;sourceRole=[string]$manifest.sourceRole;signerThumbprint=$certificate.Thumbprint;signatureVerified=$true
            bundleCollected=($null -ne $bundleEvidence);bundleSha256=if ($null -eq $envelope) {$null} else {[string]$envelope.bundleSha256};bundleBytes=if ($null -eq $envelope) {0} else {[int64]$envelope.bundleBytes};bundleEntryCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.EntryCount}
            caseCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.Batch.caseCount};caseLaunchFailureCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.Batch.caseLaunchFailureCount};providerCompletedCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.Batch.providerCompletedCount}
            pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;shortExtractionRootRemoved=$true;requestRetryAuthorized=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
        }
        Write-JsonCreateNew (Join-Path $collectionRoot 'R13B_EXACT_RESPONSE_COLLECTION_GATE.json') $gate
        $gate | ConvertTo-Json -Depth 20
    }
    catch {
        throw
    }
}
finally { if ($null -ne $certificate) { $certificate.Dispose() } }
