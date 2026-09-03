#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$actionCount = [int][bool]$Preflight + [int][bool]$Collect + [int][bool]$Rehearsal
if ($actionCount -ne 1) { throw 'Specify exactly one of -Preflight, -Collect, or -Rehearsal.' }

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

function Resolve-ZipEntryByNormalizedName([IO.Compression.ZipArchive]$Archive, [string]$Name, [string]$Label) {
    $normalizedName = $Name.Replace('\','/').TrimEnd('/')
    Assert-True (-not [string]::IsNullOrWhiteSpace($normalizedName)) "$Label normalized entry name is empty."
    $matches = New-Object 'Collections.Generic.List[IO.Compression.ZipArchiveEntry]'
    foreach ($candidate in @($Archive.Entries)) {
        $candidateName = ([string]$candidate.FullName).Replace('\','/').TrimEnd('/')
        if ([string]::Equals($candidateName, $normalizedName, [StringComparison]::OrdinalIgnoreCase)) { $matches.Add($candidate) }
    }
    Assert-True ($matches.Count -eq 1) "$Label normalized entry is absent or duplicated: $normalizedName"
    return $matches[0]
}

function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Archive, [string]$Name, [int64]$MaximumBytes, [string]$Label) {
    $entry = Resolve-ZipEntryByNormalizedName $Archive $Name $Label
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
        Assert-True ($actualNames.Count -eq $expectedNames.Count -and @(Compare-Object -ReferenceObject $expectedNames -DifferenceObject $actualNames).Count -eq 0) 'R14P response ZIP exact entry set changed.'
        $signatureBytes = Read-ZipEntryBytes $archive 'PORTAL_RESPONSE_MANIFEST.sig' ([int64]$Limits.maximumSignatureBytes) 'response'
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
        try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
        finally { $rsa.Dispose() }
        Assert-True $signatureValid 'R14P matching response signature is invalid.'
        Assert-True ([string]$manifest.schema -eq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.sourceRole -eq 'JBOD') 'R14P matching response schema/source role changed.'
        Assert-True ([string]$manifest.signatureAlgorithm -eq 'RSA-SHA256-PKCS1' -and ([string]$manifest.signerThumbprint).Replace(' ','').ToUpperInvariant() -eq $Certificate.Thumbprint.Replace(' ','').ToUpperInvariant()) 'R14P matching response signer changed.'
        Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'R14P matching response authority widened.'
        $records = @($manifest.files)
        Assert-True ($records.Count -eq 3) 'R14P matching response signed-file cardinality changed.'
        $signedNames = @($records | ForEach-Object { [string]$_.path } | Sort-Object)
        $expectedSignedNames = @('MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt','RESULT.json') | Sort-Object
        Assert-True (@(Compare-Object -ReferenceObject $expectedSignedNames -DifferenceObject $signedNames).Count -eq 0) 'R14P matching response signed-file names changed.'
        foreach ($record in $records) {
            $name = [string]$record.path
            $limit = if ($name -eq 'MAINTENANCE.stdout.txt') { [int64]$Limits.maximumStdoutBytes } else { [int64]$Limits.maximumSmallResponseFileBytes }
            $bytes = Read-ZipEntryBytes $archive $name $limit 'signed response'
            Assert-True ([int64]$bytes.Length -eq [int64]$record.bytes -and (Get-ByteSha256 $bytes) -eq ([string]$record.sha256).ToUpperInvariant()) "R14P matching signed response leaf changed: $name"
        }
        $stdoutBytes = Read-ZipEntryBytes $archive 'MAINTENANCE.stdout.txt' ([int64]$Limits.maximumStdoutBytes) 'maintenance stdout'
        return [pscustomobject]@{Path=$Path;Manifest=$manifest;ManifestBytes=$manifestBytes;StdoutBytes=$stdoutBytes;ZipBytes=[int64](Get-Item -LiteralPath $Path).Length;ZipSha256=Get-Sha256 $Path}
    }
    finally { $archive.Dispose() }
}

function Test-BundleBytes([byte[]]$BundleBytes, [object]$Envelope, [object]$Limits, [string[]]$ExpectedCaseIds) {
    Assert-True ([int64]$BundleBytes.Length -eq [int64]$Envelope.bundleBytes) 'R14P decoded bundle byte count changed.'
    Assert-True ((Get-ByteSha256 $BundleBytes) -eq ([string]$Envelope.bundleSha256).ToUpperInvariant()) 'R14P decoded bundle hash changed.'
    $memory = New-Object IO.MemoryStream
    $memory.Write($BundleBytes, 0, $BundleBytes.Length)
    $memory.Position = 0
    $archive = New-Object IO.Compression.ZipArchive($memory, [IO.Compression.ZipArchiveMode]::Read, $false)
    try {
        $allEntries = @($archive.Entries)
        Assert-True ($allEntries.Count -le [int]$Limits.maximumBundleEntries) 'R14P bundle entry bound was exceeded.'
        foreach ($archiveEntry in $allEntries) {
            $archiveName = ([string]$archiveEntry.FullName).Replace('\','/').TrimEnd('/')
            Assert-True (-not [string]::IsNullOrWhiteSpace($archiveName)) 'R14P bundle contains an empty archive path.'
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$archiveEntry.Name)) "R14P bundle directory entries are not allowed: $archiveName"
            [void](Get-SafeChildPath 'C:\R14R\b' $archiveName)
        }
        $entries = @($allEntries | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Name) })
        $total = [int64]0
        $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($entry in $entries) {
            $name = ([string]$entry.FullName).Replace('\','/')
            Assert-True ($seen.Add($name)) "R14P duplicate bundle path: $name"
            Assert-True ([int64]$entry.Length -le [int64]$Limits.maximumBundleEntryBytes) "R14P bundle entry is too large: $name"
            $total += [int64]$entry.Length
            Assert-True ($total -le [int64]$Limits.maximumBundleExpandedBytes) 'R14P expanded bundle byte bound was exceeded.'
        }
        foreach ($required in @('BATCH_GATE.json','EXECUTION.json')) { Assert-True ($seen.Contains($required)) "R14P bundle required leaf is absent: $required" }
        foreach ($caseId in $ExpectedCaseIds) { Assert-True ($seen.Contains($caseId + '/CASE_RESULT.json')) "R14P case result is absent: $caseId" }
        $expectedFiles = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        foreach ($required in @('BATCH_GATE.json','EXECUTION.json')) { [void]$expectedFiles.Add($required) }
        foreach ($caseId in $ExpectedCaseIds) { [void]$expectedFiles.Add($caseId + '/CASE_RESULT.json') }
        $batchBytes = Read-ZipEntryBytes $archive 'BATCH_GATE.json' ([int64]$Limits.maximumJsonBytes) 'bundle'
        $executionBytes = Read-ZipEntryBytes $archive 'EXECUTION.json' ([int64]$Limits.maximumJsonBytes) 'bundle'
        $batch = (New-Object Text.UTF8Encoding($false, $true)).GetString($batchBytes) | ConvertFrom-Json
        $execution = (New-Object Text.UTF8Encoding($false, $true)).GetString($executionBytes) | ConvertFrom-Json
        Assert-True ([string]$batch.schema -eq 'argos_opencv_scribe_r14p_batch_gate_v1' -and [string]$batch.state -eq 'PASS_R14P_BATCH_COMPLETE' -and [string]$batch.requestId -eq 'REQ_20260902T204408092Z_R14P' -and -not [bool]$batch.rehearsal) 'R14P returned batch gate changed.'
        Assert-True ([string]$execution.schema -eq 'argos_opencv_scribe_r14p_execution_v1' -and [string]$execution.state -eq 'PASS_R14P_EXECUTION' -and [string]$execution.requestId -eq 'REQ_20260902T204408092Z_R14P' -and -not [bool]$execution.rehearsal) 'R14P returned execution evidence changed.'
        Assert-True ([string]$execution.batchGateSha256 -eq (Get-ByteSha256 $batchBytes)) 'R14P execution does not bind the returned batch gate.'
        Assert-True ([int]$batch.caseCount -eq $ExpectedCaseIds.Count -and @($batch.cases).Count -eq $ExpectedCaseIds.Count -and [int]$execution.caseCount -eq $ExpectedCaseIds.Count) 'R14P returned case cardinality changed.'
        foreach ($object in @($batch,$execution)) { Assert-True (-not [bool]$object.sourceMutationPerformed -and -not [bool]$object.sourceDeletionPerformed -and -not [bool]$object.taskOrProcessRestarted -and -not [bool]$object.providerActivated -and [bool]$object.reviewOnly -and -not [bool]$object.trainingEligible -and -not [bool]$object.xmlEligible -and -not [bool]$object.productionEligible -and -not [bool]$object.productionRoutingEnabled) 'R14P returned execution authority widened.' }
        foreach ($caseId in $ExpectedCaseIds) {
            $row = @($batch.cases | Where-Object { [string]$_.caseId -eq $caseId })
            Assert-True ($row.Count -eq 1) "R14P batch case identity is absent or duplicated: $caseId"
            $caseBytes = Read-ZipEntryBytes $archive ($caseId + '/CASE_RESULT.json') ([int64]$Limits.maximumJsonBytes) 'case result'
            Assert-True ((Get-ByteSha256 $caseBytes) -eq ([string]$row[0].caseResultSha256).ToUpperInvariant()) "R14P batch does not bind case result: $caseId"
            $case = (New-Object Text.UTF8Encoding($false, $true)).GetString($caseBytes) | ConvertFrom-Json
            Assert-True ([string]$case.schema -eq 'argos_opencv_scribe_alphabet_crop_case_result_v1' -and [string]$case.caseId -eq $caseId -and [string]$case.state -like 'HOLD_*') "R14P case contract changed: $caseId"
            if ([string]$case.state -eq 'HOLD_R14P_CASE_LAUNCH_FAILURE') {
                Assert-True ([bool]$case.authority.reviewOnly -and -not [bool]$case.authority.automaticIdentityAuthority -and -not [bool]$case.authority.automaticReferenceAdmissionAllowed -and -not [bool]$case.authority.trainingEligible -and -not [bool]$case.authority.xmlEligible -and -not [bool]$case.authority.productionEligible -and -not [bool]$case.authority.productionRoutingEnabled -and -not [bool]$case.authority.mayClearHolds) "R14P launch-failure case authority widened: $caseId"
            }
            else {
                Assert-True ([string]$case.classification -eq 'PENDING_GATE' -and -not [bool]$case.eligibleIdentity -and -not [bool]$case.referenceAdmissionEligible) "R14P case authority widened: $caseId"
            }
            foreach ($artifact in @($case.artifacts)) {
                $artifactName = $caseId + '/' + ([string]$artifact.relativePath).Replace('\','/')
                Assert-True ($expectedFiles.Add($artifactName)) "R14P declared artifact path is duplicated: $artifactName"
                Assert-True ($seen.Contains($artifactName)) "R14P declared artifact is absent: $artifactName"
                $artifactBytes = Read-ZipEntryBytes $archive $artifactName ([int64]$Limits.maximumBundleEntryBytes) 'case artifact'
                Assert-True ((Get-ByteSha256 $artifactBytes) -eq ([string]$artifact.sha256).ToUpperInvariant()) "R14P declared artifact hash changed: $artifactName"
            }
        }
        Assert-True ($seen.SetEquals($expectedFiles)) ('R14P bundle normalized file set is not exactly closed; expected=' + $expectedFiles.Count + ';actual=' + $seen.Count)
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

function Invoke-CollectorZipLookupRehearsal([string]$ProjectRoot, [object]$Invocation, [string]$InvocationPath, [string]$CollectorPath) {
    Assert-True ([string]$PSVersionTable.PSEdition -eq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'R14P collector ZIP lookup rehearsal requires Windows PowerShell 5.1 Desktop.'
    Assert-True ([string]$Invocation.rehearsal.normalizedNestedEntry -eq 'CASE01/CASE_RESULT.json' -and [string]$Invocation.rehearsal.rawNestedEntry -eq 'CASE01\CASE_RESULT.json') 'R14P collector ZIP lookup rehearsal entry contract changed.'
    $gatePath = Resolve-ProjectFile $ProjectRoot ([string]$Invocation.rehearsal.gatePath) 'collector ZIP lookup rehearsal gate'
    Assert-True (-not (Test-Path -LiteralPath $gatePath)) "R14P collector ZIP lookup rehearsal gate already exists: $gatePath"
    $tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
    $testRoot = Join-Path $tempBase ('ArgosR14PCollectorZipLookup_' + [Guid]::NewGuid().ToString('N'))
    Assert-True ($testRoot.StartsWith($tempBase + '\', [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($testRoot) -match '^ArgosR14PCollectorZipLookup_[0-9a-f]{32}$') 'R14P collector ZIP lookup rehearsal temporary root is unsafe.'
    $sourceRoot = Join-Path $testRoot 'source'
    $zipPath = Join-Path $testRoot 'bundle.zip'
    $extraZipPath = Join-Path $testRoot 'bundle-extra.zip'
    $directoryZipPath = Join-Path $testRoot 'bundle-directory.zip'
    $duplicateZipPath = Join-Path $testRoot 'bundle-duplicate.zip'
    $rawEntryName = $null
    $readBytes = $null
    $positiveEvidence = $null
    $expectedBytes = (New-Object Text.UTF8Encoding($false)).GetBytes('R14P_BACKSLASH_ENTRY_BYTES_20260902')
    $extraRejected = $false
    $directoryRejected = $false
    $duplicateRejected = $false
    try {
        [void][IO.Directory]::CreateDirectory((Join-Path $sourceRoot 'CASE01'))
        [IO.File]::WriteAllBytes((Join-Path $sourceRoot 'CASE01\preview.bin'), $expectedBytes)
        $artifactSha = Get-ByteSha256 $expectedBytes
        $caseObject = [ordered]@{schema='argos_opencv_scribe_alphabet_crop_case_result_v1';caseId='CASE01';state='HOLD_R14P_REVIEW_REQUIRED';classification='PENDING_GATE';eligibleIdentity=$false;referenceAdmissionEligible=$false;artifacts=@([ordered]@{relativePath='preview.bin';sha256=$artifactSha})}
        $caseBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($caseObject | ConvertTo-Json -Depth 12))
        [IO.File]::WriteAllBytes((Join-Path $sourceRoot 'CASE01\CASE_RESULT.json'), $caseBytes)
        $caseSha = Get-ByteSha256 $caseBytes
        $authority = [ordered]@{sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
        $batchObject = [ordered]@{schema='argos_opencv_scribe_r14p_batch_gate_v1';state='PASS_R14P_BATCH_COMPLETE';requestId='REQ_20260902T204408092Z_R14P';rehearsal=$false;caseCount=1;cases=@([ordered]@{caseId='CASE01';caseResultSha256=$caseSha})}
        foreach ($property in $authority.GetEnumerator()) { $batchObject[$property.Key] = $property.Value }
        $batchBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($batchObject | ConvertTo-Json -Depth 12))
        [IO.File]::WriteAllBytes((Join-Path $sourceRoot 'BATCH_GATE.json'), $batchBytes)
        $executionObject = [ordered]@{schema='argos_opencv_scribe_r14p_execution_v1';state='PASS_R14P_EXECUTION';requestId='REQ_20260902T204408092Z_R14P';rehearsal=$false;caseCount=1;batchGateSha256=(Get-ByteSha256 $batchBytes)}
        foreach ($property in $authority.GetEnumerator()) { $executionObject[$property.Key] = $property.Value }
        $executionBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($executionObject | ConvertTo-Json -Depth 12))
        [IO.File]::WriteAllBytes((Join-Path $sourceRoot 'EXECUTION.json'), $executionBytes)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [IO.Compression.ZipFile]::CreateFromDirectory($sourceRoot, $zipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
        $zipBytes = [IO.File]::ReadAllBytes($zipPath)
        $envelope = [pscustomobject]@{bundleBytes=[int64]$zipBytes.Length;bundleSha256=Get-ByteSha256 $zipBytes}
        $positiveEvidence = Test-BundleBytes $zipBytes $envelope $Invocation.limits @('CASE01')
        $archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $rawMatches = @($archive.Entries | Where-Object { [string]::Equals(([string]$_.FullName).Replace('\','/'), [string]$Invocation.rehearsal.normalizedNestedEntry, [StringComparison]::OrdinalIgnoreCase) })
            Assert-True ($rawMatches.Count -eq 1) 'R14P collector ZIP lookup rehearsal nested entry cardinality changed.'
            $rawEntryName = [string]$rawMatches[0].FullName
            Assert-True ([string]::Equals($rawEntryName, [string]$Invocation.rehearsal.rawNestedEntry, [StringComparison]::Ordinal)) 'R14P WinPS 5.1 CreateFromDirectory did not emit the expected raw backslash entry name.'
            Assert-True ($null -eq $archive.GetEntry([string]$Invocation.rehearsal.normalizedNestedEntry)) 'R14P native forward-slash GetEntry unexpectedly resolved the raw backslash entry.'
            $readBytes = Read-ZipEntryBytes $archive ([string]$Invocation.rehearsal.normalizedNestedEntry) ([int64]$Invocation.limits.maximumJsonBytes) 'collector ZIP lookup rehearsal'
        }
        finally { $archive.Dispose() }
        Assert-True ((Get-ByteSha256 $readBytes) -eq (Get-ByteSha256 $caseBytes) -and [int64]$readBytes.Length -eq [int64]$caseBytes.Length) 'R14P normalized collector lookup did not read the exact nested bytes.'

        [IO.File]::WriteAllBytes((Join-Path $sourceRoot 'UNDECLARED.bin'), $expectedBytes)
        [IO.Compression.ZipFile]::CreateFromDirectory($sourceRoot, $extraZipPath, [IO.Compression.CompressionLevel]::Optimal, $false)
        $extraZipBytes = [IO.File]::ReadAllBytes($extraZipPath)
        $extraEnvelope = [pscustomobject]@{bundleBytes=[int64]$extraZipBytes.Length;bundleSha256=Get-ByteSha256 $extraZipBytes}
        try { [void](Test-BundleBytes $extraZipBytes $extraEnvelope $Invocation.limits @('CASE01')) }
        catch { $extraRejected = $_.Exception.Message -like 'R14P bundle normalized file set is not exactly closed*' }
        Assert-True $extraRejected 'R14P collector ZIP lookup rehearsal did not reject an undeclared normalized file entry.'

        $sourceArchive = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $directoryStream = New-Object IO.FileStream($directoryZipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                $directoryArchive = New-Object IO.Compression.ZipArchive($directoryStream, [IO.Compression.ZipArchiveMode]::Create, $true)
                try {
                    foreach ($sourceEntry in @($sourceArchive.Entries)) {
                        $targetEntry = $directoryArchive.CreateEntry([string]$sourceEntry.FullName)
                        $sourceStream = $sourceEntry.Open(); $targetStream = $targetEntry.Open()
                        try { $sourceStream.CopyTo($targetStream) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
                    }
                    [void]$directoryArchive.CreateEntry('EMPTY/')
                }
                finally { $directoryArchive.Dispose() }
            }
            finally { $directoryStream.Dispose() }
        }
        finally { $sourceArchive.Dispose() }
        $directoryZipBytes = [IO.File]::ReadAllBytes($directoryZipPath)
        $directoryEnvelope = [pscustomobject]@{bundleBytes=[int64]$directoryZipBytes.Length;bundleSha256=Get-ByteSha256 $directoryZipBytes}
        try { [void](Test-BundleBytes $directoryZipBytes $directoryEnvelope $Invocation.limits @('CASE01')) }
        catch { $directoryRejected = $_.Exception.Message -like 'R14P bundle directory entries are not allowed*' }
        Assert-True $directoryRejected 'R14P collector ZIP lookup rehearsal did not reject a directory entry.'

        $sourceArchive = [IO.Compression.ZipFile]::OpenRead($zipPath)
        try {
            $duplicateStream = New-Object IO.FileStream($duplicateZipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
            try {
                $duplicateArchive = New-Object IO.Compression.ZipArchive($duplicateStream, [IO.Compression.ZipArchiveMode]::Create, $true)
                try {
                    foreach ($sourceEntry in @($sourceArchive.Entries)) {
                        $targetEntry = $duplicateArchive.CreateEntry([string]$sourceEntry.FullName)
                        $sourceStream = $sourceEntry.Open(); $targetStream = $targetEntry.Open()
                        try { $sourceStream.CopyTo($targetStream) } finally { $targetStream.Dispose(); $sourceStream.Dispose() }
                    }
                    $duplicateEntry = $duplicateArchive.CreateEntry('CASE01/CASE_RESULT.json')
                    $duplicateEntryStream = $duplicateEntry.Open()
                    try { $duplicateEntryStream.Write($caseBytes, 0, $caseBytes.Length) } finally { $duplicateEntryStream.Dispose() }
                }
                finally { $duplicateArchive.Dispose() }
            }
            finally { $duplicateStream.Dispose() }
        }
        finally { $sourceArchive.Dispose() }
        $duplicateZipBytes = [IO.File]::ReadAllBytes($duplicateZipPath)
        $duplicateEnvelope = [pscustomobject]@{bundleBytes=[int64]$duplicateZipBytes.Length;bundleSha256=Get-ByteSha256 $duplicateZipBytes}
        try { [void](Test-BundleBytes $duplicateZipBytes $duplicateEnvelope $Invocation.limits @('CASE01')) }
        catch { $duplicateRejected = $_.Exception.Message -like 'R14P duplicate bundle path:*' }
        Assert-True $duplicateRejected 'R14P collector ZIP lookup rehearsal did not reject a normalized duplicate entry.'
    }
    finally {
        if (Test-Path -LiteralPath $testRoot -PathType Container) { [IO.Directory]::Delete($testRoot, $true) }
    }
    Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'R14P collector ZIP lookup rehearsal temporary root remains.'
    $gate = [ordered]@{
        schema='argos_r14p_collector_zip_lookup_rehearsal_gate_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R14P_COLLECTOR_ZIP_LOOKUP_REHEARSAL';classification='FROZEN_REVIEW_ONLY'
        collectorPath='work/OPENCV_SCRIBE_R14/Collect-R14PResponse.ps1';collectorSha256=Get-Sha256 $CollectorPath;rehearsalInvocationPath='work/OPENCV_SCRIBE_R14/Test-R14PCollector.invocation.json';rehearsalInvocationSha256=Get-Sha256 $InvocationPath
        windowsPowerShellVersion=$PSVersionTable.PSVersion.ToString();windowsPowerShellEdition=[string]$PSVersionTable.PSEdition;clrVersion=[Environment]::Version.ToString();zipWriter='System.IO.Compression.ZipFile.CreateFromDirectory'
        rawNestedEntry=$rawEntryName;normalizedNestedEntry=[string]$Invocation.rehearsal.normalizedNestedEntry;nativeForwardSlashGetEntryReturnedNull=$true;normalizedLookupUnique=$true;exactNestedBytesRead=$true;nestedBytes=[int64]$readBytes.Length;nestedSha256=Get-ByteSha256 $readBytes
        expectedNormalizedFileEntries=@('BATCH_GATE.json','CASE01/CASE_RESULT.json','CASE01/preview.bin','EXECUTION.json');exactNormalizedFileSetClosed=$true;normalizedFileEntryCount=[int]$positiveEvidence.EntryNames.Count;undeclaredExtraEntryRejected=$true;directoryEntryRejected=$true;normalizedDuplicateEntryRejected=$true;temporaryRootRemoved=$true
        targetExecuted=$false;externalShareRead=$false;externalMutationPerformed=$false;requestPublished=$false;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-JsonCreateNew $gatePath $gate
    return $gate
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'R14P response collection invocation is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
if ($Rehearsal) { Assert-True ([string]$invocation.schema -eq 'argos_r14p_collector_r2_rehearsal_invocation_v1') 'R14P collector rehearsal invocation schema changed.' }
else { Assert-True ([string]$invocation.schema -eq 'argos_r14p_response_collection_r3_invocation_v1') 'R14P R3 response collection invocation schema changed.' }
Assert-True ([string]$invocation.requestId -eq 'REQ_20260902T204408092Z_R14P') 'R14P response collection request identity changed.'
Assert-True ((Get-Sha256 $MyInvocation.MyCommand.Path) -eq [string]$invocation.collectorSha256) 'R14P response collector self-pin changed.'
Assert-True ([int]$invocation.maximumMatchingResponses -eq 1 -and -not [bool]$invocation.requestRetryAuthorized -and [bool]$invocation.matchingSignedTerminalResponseOnly) 'R14P response correlation/retry boundary changed.'
Assert-True ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.automaticIdentityAuthority -and -not [bool]$invocation.authority.trainingEligible -and -not [bool]$invocation.authority.xmlEligible -and -not [bool]$invocation.authority.productionEligible -and -not [bool]$invocation.authority.productionRoutingEnabled -and -not [bool]$invocation.authority.providerActivationAllowed) 'R14P response collection authority widened.'

if ($Rehearsal) {
    $rehearsalGate = Invoke-CollectorZipLookupRehearsal $project $invocation $invocationPath $MyInvocation.MyCommand.Path
    $rehearsalGate | ConvertTo-Json -Depth 12
    return
}

foreach ($gatePin in @($invocation.requiredGates)) {
    $gatePath = Resolve-ProjectFile $project ([string]$gatePin.path) 'collection gate dependency'
    Assert-PinnedFile $gatePath ([string]$gatePin.sha256) 'R14P collection gate dependency'
    $gate = Get-Content -Raw -LiteralPath $gatePath | ConvertFrom-Json
    $property = [string]$gatePin.stateProperty
    Assert-True ([string]$gate.$property -eq [string]$gatePin.requiredState) "R14P collection dependency state changed: $($gatePin.path)"
}

$publishGatePath = Resolve-ProjectFile $project ([string]$invocation.publicationGate.path) 'R14P publication gate'
Assert-True (Test-Path -LiteralPath $publishGatePath -PathType Leaf) 'R14P publication gate is absent; response collection cannot precede exact one-time publication.'
$publishGate = Get-Content -Raw -LiteralPath $publishGatePath | ConvertFrom-Json
$currentInvocationSha256 = Get-Sha256 $invocationPath
Assert-True ([string]$publishGate.schema -eq 'argos_r14p_publish_gate_v1' -and [string]$publishGate.state -eq 'PASS_R14P_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW' -and [string]$publishGate.requestId -eq [string]$invocation.requestId) 'R14P publication gate identity/state changed.'
Assert-True ([string]$publishGate.sha256 -eq [string]$invocation.requestZip.sha256 -and [string]$publishGate.responseCollectorSha256 -eq [string]$invocation.publicationGate.publishedCollectorSha256 -and [string]$publishGate.responseCollectorInvocationSha256 -eq [string]$invocation.publicationGate.publishedCollectorInvocationSha256 -and [string]$publishGate.responseCollectorRehearsalGateSha256 -eq [string]$invocation.publicationGate.collectorRehearsalGateSha256) 'R14P publication gate does not bind the published request and frozen predecessor collector.'

$certificatePath = Resolve-ProjectFile $project ([string]$invocation.responseSigner.certificatePath) 'JBOD response signer certificate'
$verifierPath = Resolve-ProjectFile $project ([string]$invocation.responseSigner.verifierPath) 'signed response verifier'
Assert-PinnedFile $certificatePath ([string]$invocation.responseSigner.certificateSha256) 'R14P JBOD response signer certificate'
Assert-PinnedFile $verifierPath ([string]$invocation.responseSigner.verifierSha256) 'R14P signed response verifier'
$certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certificatePath)
try {
    Assert-True ($certificate.Thumbprint.Replace(' ','').ToUpperInvariant() -eq ([string]$invocation.responseSigner.thumbprint).Replace(' ','').ToUpperInvariant()) 'R14P JBOD response signer thumbprint changed.'
    $shareRoot = [string]$invocation.route.inspectionRevsUnc
    Assert-True ($shareRoot -eq '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs') 'R14P response route changed.'
    $psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
    Assert-True ((Normalize-Root ([string]$psDrive.DisplayRoot)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R14P response U: PowerShell mapping changed.'
    Assert-True ([int]$logicalDisk.DriveType -eq 4 -and (Normalize-Root ([string]$logicalDisk.ProviderName)).Equals((Normalize-Root $shareRoot), [StringComparison]::OrdinalIgnoreCase)) 'R14P response U: is not the exact persistent network mapping.'
    $responseRoot = 'U:\ProjectPortalRO\responses'
    Assert-True (Test-Path -LiteralPath $responseRoot -PathType Container) 'R14P response share is unavailable.'
    $responseLeaf = [string]$invocation.exactResponse.fileName
    Assert-True ($responseLeaf -match '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready\.zip$' -and [IO.Path]::GetFileName($responseLeaf) -ceq $responseLeaf) 'R14P exact response leaf is unsafe.'
    $responsePath = Join-Path $responseRoot $responseLeaf
    Assert-PinnedFile $responsePath ([string]$invocation.exactResponse.sha256) 'R14P exact observed response ZIP'
    Assert-True ((Get-Item -LiteralPath $responsePath).Length -eq [int64]$invocation.exactResponse.bytes) 'R14P exact observed response ZIP byte count changed.'
    $match = Read-ResponseCandidate $responsePath ([string]$invocation.requestId) $certificate $invocation.limits
    Assert-True ($null -ne $match) 'R14P exact observed response does not contain the matching signed request identity.'
    $manifest = $match.Manifest
    Assert-True (@($invocation.allowedTerminalStates) -contains [string]$manifest.state) "R14P response state is not an allowed terminal state: $($manifest.state)"
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.responseId)) 'R14P matching response ID is empty.'
    $responseSnapshot = Get-Item -LiteralPath $match.Path
    Assert-True ([int64]$responseSnapshot.Length -eq [int64]$match.ZipBytes -and (Get-Sha256 $match.Path) -eq [string]$match.ZipSha256) 'R14P matching response changed during bounded collection preflight.'

    $envelope = $null
    $bundleBytes = $null
    $bundleEvidence = $null
    if ([string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') {
        $stdoutText = (New-Object Text.UTF8Encoding($false, $true)).GetString([byte[]]$match.StdoutBytes)
        $envelope = $stdoutText | ConvertFrom-Json
        Assert-True ([string]$envelope.schema -eq 'argos_opencv_scribe_r14p_maintenance_envelope_v1' -and [string]$envelope.state -eq 'PASS_R14P_SIGNED_RETURN_READY' -and [string]$envelope.requestId -eq [string]$invocation.requestId -and -not [bool]$envelope.rehearsal) 'R14P maintenance envelope changed.'
        Assert-True ([int]$envelope.caseCount -eq 4 -and [int64]$envelope.bundleBytes -le [int64]$invocation.limits.maximumBundleBytes -and [int]$envelope.bundleBase64Characters -le [int]$invocation.limits.maximumBundleBase64Characters) 'R14P maintenance envelope bounds/cardinality changed.'
        Assert-True ([string]$envelope.bundleBase64 -ne '' -and ([string]$envelope.bundleBase64).Length -eq [int]$envelope.bundleBase64Characters) 'R14P maintenance envelope Base64 length changed.'
        Assert-True (-not [bool]$envelope.automaticRetryAllowed -and -not [bool]$envelope.sourceMutationPerformed -and -not [bool]$envelope.sourceDeletionPerformed -and -not [bool]$envelope.taskOrProcessRestarted -and -not [bool]$envelope.providerActivated -and -not [bool]$envelope.holdsCleared -and [bool]$envelope.reviewOnly -and -not [bool]$envelope.trainingEligible -and -not [bool]$envelope.xmlEligible -and -not [bool]$envelope.productionEligible -and -not [bool]$envelope.productionRoutingEnabled) 'R14P maintenance envelope authority widened.'
        $bundleBytes = [Convert]::FromBase64String([string]$envelope.bundleBase64)
        $bundleEvidence = Test-BundleBytes $bundleBytes $envelope $invocation.limits @($invocation.expectedCaseIds)
    }

    $collectionRoot = Resolve-ProjectFile $project ([string]$invocation.outputRoot) 'response collection root'
    $partialRoot = $collectionRoot + '.partial'
    $collectionGatePath = Join-Path $collectionRoot 'R14P_EXACT_RESPONSE_COLLECTION_GATE.json'
    $shortRoot = [string]$invocation.shortExtractionRoot
    Assert-True ($shortRoot -eq 'C:\R14R2') 'R14P short extraction root changed.'
    foreach ($path in @($collectionRoot,$partialRoot,$shortRoot)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R14P create-new response collection target exists: $path" }
    $plannedPaths = New-Object Collections.Generic.List[string]
    foreach ($path in @((Join-Path $shortRoot 'z.zip'),(Join-Path $shortRoot 'r\PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $shortRoot 'b\BATCH_GATE.json'),(Join-Path $partialRoot 'response\transport.ready.zip'),(Join-Path $partialRoot 'response\PORTAL_RESPONSE_MANIFEST.json'),(Join-Path $partialRoot 'evidence\R14P_RETURN.zip'),$collectionGatePath)) { $plannedPaths.Add($path) }
    if ($null -ne $bundleEvidence) { foreach ($entryName in @($bundleEvidence.EntryNames)) { $plannedPaths.Add((Get-SafeChildPath (Join-Path $partialRoot 'evidence\bundle') ([string]$entryName))) } }
    $pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
    $pathJson = & $pathTool -CandidatePath $plannedPaths.ToArray() -ReservedSuffixCharacters 32 -AsJson | Out-String
    $pathGate = $pathJson | ConvertFrom-Json
    Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R14P response collection path budget failed.'
    $maximumEffectiveLength = [int]((@($pathGate.candidates) | Measure-Object effectiveLength -Maximum).Maximum)
    Assert-True ($maximumEffectiveLength -lt 200) 'R14P response collection path reached effective length 200.'

    $preflightResult = [ordered]@{
        schema='argos_r14p_response_collection_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R14P_EXACT_RESPONSE_COLLECTION_PREFLIGHT';requestId=[string]$invocation.requestId;responseId=[string]$manifest.responseId
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
        Assert-True ((Get-Sha256 $shortZip) -eq [string]$match.ZipSha256) 'R14P short response copy changed.'
        [IO.Compression.ZipFile]::ExtractToDirectory($shortZip, $shortResponse)
        $verification = & $verifierPath -PackagePath $shortResponse -EndpointCertificatePath $certificatePath -ExpectedSourceRole JBOD -ExpectedRequestId ([string]$invocation.requestId)
        Assert-True ([string]$verification.State -eq 'PASS_SIGNED_PORTAL_RESPONSE' -and [string]$verification.EndpointState -eq [string]$manifest.state -and ([string]$verification.SignerThumbprint).Replace(' ','').ToUpperInvariant() -eq $certificate.Thumbprint.Replace(' ','').ToUpperInvariant()) 'R14P official signed response verification failed.'
        $shortBundle = $null
        if ($null -ne $bundleEvidence) {
            $shortBundle = Join-Path $shortRoot 'R14P_RETURN.zip'
            [IO.File]::WriteAllBytes($shortBundle, [byte[]]$bundleBytes)
            Assert-True ((Get-Sha256 $shortBundle) -eq [string]$envelope.bundleSha256) 'R14P short decoded bundle changed.'
            [IO.Compression.ZipFile]::ExtractToDirectory($shortBundle, (Join-Path $shortRoot 'b'))
        }

        [void][IO.Directory]::CreateDirectory((Join-Path $partialRoot 'response'))
        [void][IO.Directory]::CreateDirectory((Join-Path $partialRoot 'evidence'))
        $partialCreated = $true
        [IO.File]::Copy($shortZip, (Join-Path $partialRoot 'response\transport.ready.zip'), $false)
        foreach ($leaf in @('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','MAINTENANCE.stdout.txt','MAINTENANCE.stderr.txt','RESULT.json')) { [IO.File]::Copy((Join-Path $shortResponse $leaf), (Join-Path $partialRoot ('response\' + $leaf)), $false) }
        if ($null -ne $bundleEvidence) {
            [IO.File]::Copy($shortBundle, (Join-Path $partialRoot 'evidence\R14P_RETURN.zip'), $false)
            [IO.Directory]::Move((Join-Path $shortRoot 'b'), (Join-Path $partialRoot 'evidence\bundle'))
        }
        [IO.Directory]::Move($partialRoot, $collectionRoot)
        $partialCreated = $false
        [IO.Directory]::Delete($shortRoot, $true)
        $shortCreated = $false
        $gate = [ordered]@{
            schema='argos_r14p_exact_response_collection_gate_v1';collectedUtc=[DateTime]::UtcNow.ToString('o');state=if ([string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') {'PASS_R14P_EXACT_SIGNED_TERMINAL_RESPONSE_AND_BUNDLE_COLLECTED'} else {'PASS_R14P_EXACT_SIGNED_TERMINAL_FAILURE_COLLECTED'}
            disposition=if ([string]$manifest.state -eq 'PASS_MAINTENANCE_PATCH') {'PENDING_OPERATOR_CROP_REVIEW'} else {'PENDING_GATE'};requestId=[string]$invocation.requestId;responseId=[string]$manifest.responseId;invocationManifestSha256=Get-Sha256 $invocationPath
            responseZipBytes=[int64]$match.ZipBytes;responseZipSha256=[string]$match.ZipSha256;endpointState=[string]$manifest.state;sourceRole=[string]$manifest.sourceRole;signerThumbprint=$certificate.Thumbprint;signatureVerified=$true
            bundleCollected=($null -ne $bundleEvidence);bundleSha256=if ($null -eq $envelope) {$null} else {[string]$envelope.bundleSha256};bundleBytes=if ($null -eq $envelope) {0} else {[int64]$envelope.bundleBytes};bundleEntryCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.EntryCount}
            caseCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.Batch.caseCount};caseLaunchFailureCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.Batch.caseLaunchFailureCount};providerCompletedCount=if ($null -eq $bundleEvidence) {0} else {[int]$bundleEvidence.Batch.providerCompletedCount}
            pathState=[string]$pathGate.state;maximumEffectiveLength=$maximumEffectiveLength;shortExtractionRootRemoved=$true;requestRetryAuthorized=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;automaticIdentityAuthority=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
        }
        Write-JsonCreateNew (Join-Path $collectionRoot 'R14P_EXACT_RESPONSE_COLLECTION_GATE.json') $gate
        $gate | ConvertTo-Json -Depth 20
    }
    catch {
        throw
    }
}
finally { if ($null -ne $certificate) { $certificate.Dispose() } }
