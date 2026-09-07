#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Read-JsonFile([string]$Path, [int64]$MaximumBytes) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    Require (-not $item.PSIsContainer -and [int64]$item.Length -le $MaximumBytes) "Missing or oversized JSON file: $Path"
    $text = (New-Object Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($Path))
    try { return ($text | ConvertFrom-Json) }
    catch { throw "Invalid JSON file: $Path :: $($_.Exception.Message)" }
}

function Resolve-DeclaredLocalPath([string]$ProjectRoot, [string]$Declared, [string[]]$AllowedAbsoluteRoots) {
    Require (-not [string]::IsNullOrWhiteSpace($Declared)) 'A declared local path is empty.'
    if ([IO.Path]::IsPathRooted($Declared)) {
        $full = [IO.Path]::GetFullPath($Declared)
        $allowed = $false
        foreach ($root in @($AllowedAbsoluteRoots)) {
            $rootFull = [IO.Path]::GetFullPath([string]$root).TrimEnd('\')
            if ($full.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase) -or
                $full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) {
                $allowed = $true
                break
            }
        }
        Require $allowed "Absolute local dependency is outside the frozen read roots: $Declared"
        return $full
    }
    Require ($Declared -notmatch '(^|[/\\])\.\.([/\\]|$)') "Project-relative dependency contains traversal: $Declared"
    $projectFull = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\')
    $full = [IO.Path]::GetFullPath((Join-Path $projectFull $Declared.Replace('/', '\')))
    Require ($full.StartsWith($projectFull + '\', [StringComparison]::OrdinalIgnoreCase)) "Dependency escaped the project root: $Declared"
    return $full
}

function Require-PinnedFile([string]$Path, [string]$Sha256, [object]$Bytes, [string]$Label) {
    Require ($Sha256 -cmatch '^[A-F0-9]{64}$') "$Label SHA-256 is not finalized."
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "$Label is absent: $Path"
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($null -ne $Bytes) {
        Require ([string]$Bytes -match '^\d+$' -and [int64]$item.Length -eq [int64]$Bytes) "$Label byte length changed."
    }
    Require ((Get-Sha256 $Path) -ceq $Sha256) "$Label SHA-256 changed."
}

function Get-NestedValue([object]$Object, [string]$PropertyPath, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($PropertyPath)) "$Label property path is empty."
    $current = $Object
    foreach ($segment in $PropertyPath.Split('.')) {
        Require ($null -ne $current) "$Label property is absent: $PropertyPath"
        $property = $current.PSObject.Properties[$segment]
        Require ($null -ne $property) "$Label property is absent: $PropertyPath"
        $current = $property.Value
    }
    return $current
}

function Read-ZipEntryBytes([IO.Compression.ZipArchive]$Zip, [string]$Name, [int64]$MaximumBytes) {
    $matches = @($Zip.Entries | Where-Object {
        [string]::Equals(([string]$_.FullName).Replace('\', '/'), $Name, [StringComparison]::Ordinal)
    })
    Require ($matches.Count -eq 1) "Missing or duplicated response ZIP member: $Name"
    Require ([int64]$matches[0].Length -le $MaximumBytes) "Oversized response ZIP member: $Name"
    $input = $matches[0].Open()
    $memory = New-Object IO.MemoryStream
    try {
        $input.CopyTo($memory)
        return ,([byte[]]$memory.ToArray())
    }
    finally { $memory.Dispose(); $input.Dispose() }
}

function Get-ZipEntrySha256([IO.Compression.ZipArchiveEntry]$Entry) {
    $input = $Entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($input))).Replace('-', '') }
    finally { $sha.Dispose(); $input.Dispose() }
}

function Get-SafeExtractPath([string]$Root, [string]$Relative) {
    Require (-not [string]::IsNullOrWhiteSpace($Relative) -and -not [IO.Path]::IsPathRooted($Relative)) "Unsafe response member: $Relative"
    $normalized = $Relative.Replace('/', '\')
    Require ($normalized -notmatch '(^|\\)\.\.(\\|$)') "Response member contains traversal: $Relative"
    foreach ($component in $normalized.Split('\')) {
        if (-not [string]::IsNullOrEmpty($component)) { Require ($component.Length -le 80) "Response member component exceeds 80 characters: $Relative" }
    }
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $full = [IO.Path]::GetFullPath((Join-Path $rootFull $normalized))
    Require ($full.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase) -and $full.Length -lt 200) "Response member escaped the short extraction root or exceeded path budget: $Relative"
    return $full
}

function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally { $stream.Dispose() }
}

function Write-JsonAtomicCreateNew([string]$PartialPath, [string]$FinalPath, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $PartialPath) -and -not (Test-Path -LiteralPath $FinalPath)) 'R18ZT atomic collection-gate destination already exists.'
    Write-JsonCreateNew $PartialPath $Value
    [IO.File]::Move($PartialPath, $FinalPath)
}

Require (([bool]$Preflight) -ne ([bool]$Collect)) 'Specify exactly one of -Preflight or -Collect.'
Require ($PSVersionTable.PSEdition -eq 'Desktop' -and $PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) 'R18ZT launch-response collection requires Windows PowerShell 5.1 Desktop exactly.'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$fixedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'R18ZT_PUBLICATION_INVOCATION_V4.json'))
$providedInvocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Require ($providedInvocationPath.Equals($fixedInvocationPath, [StringComparison]::OrdinalIgnoreCase)) 'Only the fixed R18ZT publication invocation manifest is accepted.'
Require (Test-Path -LiteralPath $fixedInvocationPath -PathType Leaf) 'The fixed R18ZT publication invocation manifest is absent.'
$invocationSha256 = Get-Sha256 $fixedInvocationPath
$invocation = Read-JsonFile $fixedInvocationPath 1048576
Require ([string]$invocation.schema -ceq 'argos_opencv_scribe_r18zt_publication_invocation_v4' -and
    [string]$invocation.state -ceq 'FROZEN_R18ZT1_PUBLICATION_INVOCATION_V4' -and [string]$invocation.lifecycle -ceq 'FROZEN') 'R18ZT publication invocation is not frozen; collection refused.'
Require ([string]$invocation.requestId -ceq 'REQ_R18ZT1' -and -not [bool]$invocation.authority.retryAuthorized -and
    [int]$invocation.authority.maximumPublications -eq 1) 'R18ZT collection request/retry contract changed.'

$allowedAbsoluteRoots = @($invocation.allowedAbsoluteLocalReadRoots | ForEach-Object { [string]$_ })
$validated = @{}
foreach ($dependency in @($invocation.dependencies)) {
    $name = [string]$dependency.name
    Require ($name -cmatch '^[A-Za-z][A-Za-z0-9]*$' -and -not $validated.ContainsKey($name)) "Invalid or duplicated R18ZT dependency name: $name"
    $path = Resolve-DeclaredLocalPath $projectRoot ([string]$dependency.path) $allowedAbsoluteRoots
    Require-PinnedFile $path ([string]$dependency.sha256) $dependency.bytes "R18ZT dependency $name"
    $validated[$name] = [pscustomobject]@{ row=$dependency; path=$path; sha256=[string]$dependency.sha256 }
}

function Get-ValidatedDependency([string]$Name) {
    Require ($validated.ContainsKey($Name)) "Required R18ZT dependency is not declared: $Name"
    return $validated[$Name]
}

$selfPath = [IO.Path]::GetFullPath([string]$MyInvocation.MyCommand.Path)
$selfSha256 = Get-Sha256 $selfPath
$collectorDependency = Get-ValidatedDependency ([string]$invocation.tools.collectorDependency)
Require ($selfPath.Equals([string]$collectorDependency.path, [StringComparison]::OrdinalIgnoreCase) -and
    $selfSha256 -ceq [string]$collectorDependency.sha256) 'R18ZT collector runtime path/self-hash differs from the invocation pin.'
$publisherDependency = Get-ValidatedDependency ([string]$invocation.tools.publisherDependency)
$responseVerifierDependency = Get-ValidatedDependency 'responseVerifier'
$responseSignerDependency = Get-ValidatedDependency 'responseSignerCertificate'
Require ([string]$responseVerifierDependency.sha256 -ceq '4AF5901A7B9DFFF5A4DAF128960173D67501ABF6FF87C586BA526643B1C1449C') 'R18ZT response verifier changed.'
Require ([string]$responseSignerDependency.sha256 -ceq '5220D138831BC1CD97ABF6E37F7E67D5C0569B8CE8EED2F6EF35A24C4A88F08B') 'R18ZT JBOD response signer certificate changed.'

$publishGatePath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.publishGatePath) $allowedAbsoluteRoots
$applyIntentPath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.applyIntentPath) $allowedAbsoluteRoots
Require (Test-Path -LiteralPath $applyIntentPath -PathType Leaf) 'R18ZT durable publication apply intent is absent.'
$applyIntentSha256 = Get-Sha256 $applyIntentPath
$applyIntent = Read-JsonFile $applyIntentPath 1048576
Require ([string]$applyIntent.schema -ceq 'argos_opencv_scribe_r18zt1_publication_apply_intent_v4' -and
    [string]$applyIntent.state -ceq 'FROZEN_R18ZT1V4_APPLY_INTENT_BEFORE_EXTERNAL_WRITE' -and
    [string]$applyIntent.requestId -ceq 'REQ_R18ZT1' -and [string]$applyIntent.invocationManifestSha256 -ceq $invocationSha256 -and
    [string]$applyIntent.publisherSha256 -ceq [string]$publisherDependency.sha256 -and [string]$applyIntent.collectorSha256 -ceq $selfSha256 -and
    [string]$applyIntent.requestZipSha256 -ceq [string](Get-ValidatedDependency 'requestZip').sha256 -and
    -not [bool]$applyIntent.retryAuthorized -and -not [bool]$applyIntent.externalWritePerformedAtCreation) 'R18ZT durable publication apply intent changed.'
$publishGate = $null
$publishGateSha256 = $null
$publicationRecoveredFromApplyIntent = $false
$publishedUtc = [DateTimeOffset]::Parse([string]$applyIntent.createdUtc)
if (Test-Path -LiteralPath $publishGatePath -PathType Leaf) {
    try {
        $publishGateSha256 = Get-Sha256 $publishGatePath
        $publishGate = Read-JsonFile $publishGatePath 4194304
        Require ([string]$publishGate.schema -ceq 'argos_opencv_scribe_r18zt1_publish_gate_v4' -and
            [string]$publishGate.state -ceq 'PASS_R18ZT1V4_EXACT_SIGNED_MAINTENANCE_PUBLISHED_CREATE_NEW' -and
            [string]$publishGate.requestId -ceq 'REQ_R18ZT1') 'R18ZT publisher gate identity changed.'
        Require ([string]$publishGate.invocationManifestSha256 -ceq $invocationSha256 -and
            [string]$publishGate.applyIntentSha256 -ceq $applyIntentSha256 -and
            [string]$publishGate.publisherSha256 -ceq [string]$publisherDependency.sha256 -and
            [string]$publishGate.collectorSha256 -ceq $selfSha256) 'R18ZT publisher gate does not bind this invocation/tooling pair.'
        Require ([string]$publishGate.requestZipSha256 -ceq [string](Get-ValidatedDependency 'requestZip').sha256 -and
            [string]$publishGate.packageBindingSha256 -ceq [string](Get-ValidatedDependency ([string]$invocation.packageBinding.dependency)).sha256) 'R18ZT publisher gate package binding changed.'
        Require ([bool]$publishGate.signatureVerified -and [bool]$publishGate.allAccessibleNamespacesScanned -and
            [bool]$publishGate.requiredShareNamespacesAvailable -and [int]$publishGate.collisionCount -eq 0 -and
            -not [bool]$publishGate.collisionScanPendingApply -and [bool]$publishGate.mutationsPerformed -and
            -not [bool]$publishGate.retryAuthorized -and [bool]$publishGate.asynchronousLaunchOnly -and
            -not [bool]$publishGate.completionClaimed) 'R18ZT publisher gate safety/launch-only contract changed.'
        $publishedUtc = [DateTimeOffset]::Parse([string]$publishGate.publishedUtc)
    }
    catch {
        $publishGate = $null
        $publishGateSha256 = $null
    }
}

$shareRoot = [string]$invocation.route.shareRoot
$responseRoot = [string]$invocation.route.responseRoot
Require ($shareRoot -ceq '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs' -and
    $responseRoot -ceq 'U:\ProjectPortalRO\responses') 'R18ZT response route changed.'
$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
Require ([string]$drive.DisplayRoot -ceq $shareRoot -and [string]$disk.ProviderName -ceq $shareRoot -and [int]$disk.DriveType -eq 4) 'R18ZT persistent U: mapping changed.'
Require (Test-Path -LiteralPath $responseRoot -PathType Container) 'R18ZT portal response root is unavailable.'
Require ([int]$invocation.collector.maximumTopLevelResponseFiles -gt 0 -and
    [int]$invocation.collector.maximumTopLevelResponseFiles -le 4096) 'R18ZT response metadata snapshot cap changed.'
Require ([int]$invocation.collector.maximumNewResponseCandidates -gt 0 -and
    [int]$invocation.collector.maximumNewResponseCandidates -le 16) 'R18ZT recent response candidate cap changed.'
if ($null -eq $publishGate) {
    $publicationLeaves = @([string]$invocation.route.readyPath, [string]$invocation.route.processedPath)
    $readyOrProcessed = @($publicationLeaves | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    Require ($readyOrProcessed.Count -eq 1) 'R18ZT missing publish-gate recovery requires exactly one ready or processed request artifact.'
    $publishedItem = Get-Item -LiteralPath $readyOrProcessed[0] -ErrorAction Stop
    Require ([int64]$publishedItem.Length -eq [int64]$applyIntent.requestZipBytes -and
        (Get-Sha256 ([string]$publishedItem.FullName)) -ceq [string]$applyIntent.requestZipSha256 -and
        $publishedItem.LastWriteTimeUtc -ge $publishedUtc.UtcDateTime.AddSeconds(-[int]$invocation.collector.clockSkewAllowanceSeconds)) 'R18ZT missing publish-gate recovery artifact does not match the durable apply intent.'
    $publishedUtc = [DateTimeOffset]$publishedItem.LastWriteTimeUtc
    $publicationRecoveredFromApplyIntent = $true
}

$partialRoot = [IO.Path]::GetFullPath([string]$invocation.collector.partialExtractionRoot)
$finalRoot = [IO.Path]::GetFullPath([string]$invocation.collector.finalExtractionRoot)
$collectionGatePath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.collectionGatePath) $allowedAbsoluteRoots
$collectionGatePartialPath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.collectionGatePartialPath) $allowedAbsoluteRoots
$collectionGateRecoveryPartialPath = Resolve-DeclaredLocalPath $projectRoot ([string]$invocation.outputs.collectionGateRecoveryPartialPath) $allowedAbsoluteRoots
$allowedWriteRoots = @($invocation.collector.allowedAbsoluteLocalWriteRoots | ForEach-Object { [IO.Path]::GetFullPath([string]$_) })
Require ($allowedWriteRoots.Count -eq 2 -and @($allowedWriteRoots | Where-Object { $_.Equals($partialRoot, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 1 -and
    @($allowedWriteRoots | Where-Object { $_.Equals($finalRoot, [StringComparison]::OrdinalIgnoreCase) }).Count -eq 1) 'R18ZT extraction roots are outside the frozen exact write allowlist.'
Require ($partialRoot.Length -lt 200 -and $finalRoot.Length -lt 200 -and
    [IO.Path]::GetDirectoryName($partialRoot).Equals([IO.Path]::GetDirectoryName($finalRoot), [StringComparison]::OrdinalIgnoreCase)) 'R18ZT extraction roots do not satisfy the short same-parent contract.'
Require (-not (Test-Path -LiteralPath $partialRoot) -and -not (Test-Path -LiteralPath $collectionGatePath)) 'R18ZT response partial extraction or collection gate already exists; retry refused.'
$recoverFinalRoot = Test-Path -LiteralPath $finalRoot -PathType Container
if (-not $recoverFinalRoot) {
    Require (-not (Test-Path -LiteralPath $collectionGatePartialPath) -and
        -not (Test-Path -LiteralPath $collectionGateRecoveryPartialPath)) 'R18ZT collection-gate partial already exists before first collection attempt.'
}
Require (Test-Path -LiteralPath ([IO.Path]::GetDirectoryName($partialRoot)) -PathType Container) 'R18ZT extraction parent is absent; collector will not create it implicitly.'

# One bounded top-level snapshot only. There is no polling, sleep, recursion,
# or repeated historical scan in this collector.
$snapshot = @([IO.Directory]::EnumerateFiles($responseRoot, [string]$invocation.collector.responseFilePattern, [IO.SearchOption]::TopDirectoryOnly) |
    Select-Object -First ([int]$invocation.collector.maximumTopLevelResponseFiles + 1))
Require ($snapshot.Count -le [int]$invocation.collector.maximumTopLevelResponseFiles) 'R18ZT response root exceeds the frozen one-snapshot cap.'
$skewSeconds = [int]$invocation.collector.clockSkewAllowanceSeconds
$candidates = New-Object Collections.Generic.List[object]
foreach ($path in $snapshot) {
    $item = Get-Item -LiteralPath $path -ErrorAction Stop
    if ($item.LastWriteTimeUtc -lt $publishedUtc.UtcDateTime.AddSeconds(-$skewSeconds)) { continue }
    if ([int64]$item.Length -gt [int64]$invocation.collector.maximumResponseZipBytes) { continue }
    $candidates.Add([pscustomobject]@{ path=[string]$item.FullName; item=$item })
}
Require ($candidates.Count -le [int]$invocation.collector.maximumNewResponseCandidates) 'R18ZT new response candidate count exceeds the frozen cap.'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$matches = New-Object Collections.Generic.List[object]
foreach ($candidate in $candidates) {
    $zip = $null
    try { $zip = [IO.Compression.ZipFile]::OpenRead([string]$candidate.path) }
    catch { continue }
    try {
        if ($zip.Entries.Count -gt [int]$invocation.collector.maximumResponseEntries) { continue }
        try {
            $manifestBytes = Read-ZipEntryBytes $zip 'PORTAL_RESPONSE_MANIFEST.json' 1048576
            $manifestText = (New-Object Text.UTF8Encoding($false, $true)).GetString($manifestBytes)
            $manifest = $manifestText | ConvertFrom-Json
        }
        catch { continue }
        if ($null -eq $manifest.PSObject.Properties['requestId']) { continue }
        if ([string]$manifest.requestId -cne 'REQ_R18ZT1') { continue }
        $signatureBytes = Read-ZipEntryBytes $zip 'PORTAL_RESPONSE_MANIFEST.sig' 8192
        $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2([string]$responseSignerDependency.path)
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($certificate)
        Require ($null -ne $rsa) 'Pinned JBOD response signer certificate has no RSA key.'
        try { $signatureValid = $rsa.VerifyData($manifestBytes, $signatureBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
        finally { $rsa.Dispose() }
        Require $signatureValid 'Matching R18ZT response signature is invalid.'
        Require ([string]$manifest.schema -ceq 'argos_project_portal_response_manifest_v1' -and [string]$manifest.sourceRole -ceq 'JBOD' -and
            [string]$manifest.state -ceq [string]$invocation.collector.expectedResponseState) 'Matching R18ZT response identity/state changed.'
        Require ([string]$manifest.signatureAlgorithm -ceq 'RSA-SHA256-PKCS1' -and
            ([string]$manifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -ceq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'Matching R18ZT response signer changed.'
        Require ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and
            -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'Matching R18ZT response authority widened.'
        $responseCreatedUtc = [DateTimeOffset]::Parse([string]$manifest.createdUtc)
        Require ($responseCreatedUtc -ge $publishedUtc.AddSeconds(-$skewSeconds)) 'Matching signed R18ZT response predates publication outside the frozen skew allowance.'
        $declaredArchiveBytes = [int64]0
        foreach ($archiveEntry in @($zip.Entries)) {
            if (([string]$archiveEntry.FullName).Replace('\','/').EndsWith('/')) { continue }
            $entryLength = [int64]$archiveEntry.Length
            Require ($entryLength -ge 0 -and $entryLength -le ([int64]::MaxValue - $declaredArchiveBytes)) 'Matching R18ZT response ZIP length arithmetic overflow.'
            $declaredArchiveBytes += $entryLength
        }
        Require ($declaredArchiveBytes -le [int64]$invocation.collector.maximumExtractedBytes) 'Matching R18ZT response ZIP declared extraction bytes exceed the frozen cap.'
        $expectedPayloads = @($invocation.collector.expectedPayloadPaths | Sort-Object)
        $actualPayloads = @($manifest.files | ForEach-Object { [string]$_.path } | Sort-Object)
        Require ($expectedPayloads.Count -eq $actualPayloads.Count -and ($expectedPayloads -join "`n") -ceq ($actualPayloads -join "`n")) 'Matching R18ZT response payload membership changed.'
        $zipPayloadNames = @($zip.Entries | ForEach-Object { ([string]$_.FullName).Replace('\','/') } |
            Where-Object { $_ -cne 'PORTAL_RESPONSE_MANIFEST.json' -and $_ -cne 'PORTAL_RESPONSE_MANIFEST.sig' } | Sort-Object)
        Require ($zipPayloadNames.Count -eq $expectedPayloads.Count -and ($zipPayloadNames -join "`n") -ceq ($expectedPayloads -join "`n")) 'Matching R18ZT response ZIP payload membership changed.'
        $seenPayloads = @{}
        foreach ($record in @($manifest.files)) {
            $relative = [string]$record.path
            Require (-not $seenPayloads.ContainsKey($relative)) "Duplicate matching R18ZT response payload record: $relative"
            $seenPayloads[$relative] = $true
            Require ([int64]$record.bytes -ge 0 -and [int64]$record.bytes -le [int64]$invocation.collector.maximumExtractedBytes) "Matching R18ZT response payload record exceeds the byte cap: $relative"
            $entryRows = @($zip.Entries | Where-Object { ([string]$_.FullName).Replace('\','/') -ceq $relative })
            Require ($entryRows.Count -eq 1 -and [int64]$entryRows[0].Length -eq [int64]$record.bytes -and
                (Get-ZipEntrySha256 $entryRows[0]) -ceq [string]$record.sha256) "Matching R18ZT response payload bytes/hash changed: $relative"
        }
        $matches.Add([pscustomobject]@{
            path=[string]$candidate.path
            item=$candidate.item
            manifest=$manifest
            manifestBytes=$manifestBytes
            signatureBytes=$signatureBytes
            responseCreatedUtc=$responseCreatedUtc
        })
    }
    finally { $zip.Dispose() }
}
Require ($matches.Count -eq 1) "Expected exactly one new authenticated R18ZT response; found $($matches.Count)."
$match = $matches[0]
$responseZipSha256 = Get-Sha256 ([string]$match.path)
$responseZipBytes = [int64]$match.item.Length
$responseManifestSha256 = ([Security.Cryptography.SHA256]::Create())
try { $responseManifestHash = ([BitConverter]::ToString($responseManifestSha256.ComputeHash([byte[]]$match.manifestBytes))).Replace('-', '') }
finally { $responseManifestSha256.Dispose() }
$responseSignatureHasher = [Security.Cryptography.SHA256]::Create()
try { $responseSignatureHash = ([BitConverter]::ToString($responseSignatureHasher.ComputeHash([byte[]]$match.signatureBytes))).Replace('-', '') }
finally { $responseSignatureHasher.Dispose() }

$preflightResult = [ordered]@{
    schema = 'argos_opencv_scribe_r18zt1_launch_response_collection_gate_v4'
    collectedUtc = [DateTimeOffset]::UtcNow.ToString('o')
    state = $(if ($Preflight) { 'PASS_R18ZT1V4_ONE_SIGNED_LAUNCH_RESPONSE_PREFLIGHT' } else { 'PASS_R18ZT1V4_SIGNED_LAUNCH_RESPONSE_COLLECTED' })
    requestId = 'REQ_R18ZT1'
    publishGatePath = [string]$invocation.outputs.publishGatePath
    publishGateSha256 = $publishGateSha256
    applyIntentPath = [string]$invocation.outputs.applyIntentPath
    applyIntentSha256 = $applyIntentSha256
    publicationRecoveredFromApplyIntent = $publicationRecoveredFromApplyIntent
    publicationUtc = $publishedUtc.ToString('o')
    sourceResponseZip = [string]$match.path
    sourceResponseZipBytes = $responseZipBytes
    sourceResponseZipSha256 = $responseZipSha256
    responseCreatedUtc = $match.responseCreatedUtc.ToString('o')
    responseManifestSha256 = $responseManifestHash
    responseSignatureSha256 = $responseSignatureHash
    signedResponseVerified = $true
    signerThumbprint = 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC'
    sourceRole = 'JBOD'
    endpointState = [string]$match.manifest.state
    matchingAuthenticatedRequestIdResponseCount = 1
    matchingPayloadMembershipBytesAndHashesValidatedInMemory = $true
    oneBoundedTopLevelSnapshot = $true
    topLevelFilesExamined = $snapshot.Count
    newCandidateCount = $candidates.Count
    pollingPerformed = $false
    retryPerformed = $false
    taskOrProcessQueryPerformed = $false
    outputTreeEnumerationPerformed = $false
    launchState = $null
    launchOnly = $true
    completionClaimed = $false
    finalExtractionRoot = $finalRoot
    reviewOnly = $true
    productionRoutingEnabled = $false
    mutationsPerformed = $false
}
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 32
    return
}

# One create-new extraction attempt, or exact recovery of a previously verified
# final root when only the final local collection-gate commit was interrupted.
$verificationRoot = $finalRoot
if (-not $recoverFinalRoot) {
    [void][IO.Directory]::CreateDirectory($partialRoot)
    $zip = [IO.Compression.ZipFile]::OpenRead([string]$match.path)
    try {
        $totalBytes = [int64]0
        foreach ($entry in $zip.Entries) {
            $relative = ([string]$entry.FullName).Replace('\', '/')
            Require (-not [string]::IsNullOrWhiteSpace($relative)) 'R18ZT response ZIP contains an empty member name.'
            $unixType = ([int64]$entry.ExternalAttributes -shr 16) -band 0xF000
            Require ($unixType -ne 0xA000) "R18ZT response ZIP symlink member refused: $relative"
            if ($relative.EndsWith('/')) { continue }
            $entryLength = [int64]$entry.Length
            Require ($entryLength -le ([int64]::MaxValue - $totalBytes)) 'R18ZT response extraction length arithmetic overflow.'
            $totalBytes += $entryLength
            Require ($totalBytes -le [int64]$invocation.collector.maximumExtractedBytes) 'R18ZT response extraction exceeds the frozen total-byte cap.'
            $target = Get-SafeExtractPath $partialRoot $relative
            $parent = [IO.Path]::GetDirectoryName($target)
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void][IO.Directory]::CreateDirectory($parent) }
            $input = $entry.Open()
            $output = New-Object IO.FileStream($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
            try {
                $input.CopyTo($output)
                $output.Flush($true)
            }
            finally { $output.Dispose(); $input.Dispose() }
        }
    }
    finally { $zip.Dispose() }
    $verificationRoot = $partialRoot
}

$verificationRows = @(& ([string]$responseVerifierDependency.path) -PackagePath $verificationRoot -EndpointCertificatePath ([string]$responseSignerDependency.path) -ExpectedSourceRole JBOD -ExpectedRequestId 'REQ_R18ZT1')
Require ($verificationRows.Count -eq 1 -and [string]$verificationRows[0].State -ceq 'PASS_SIGNED_PORTAL_RESPONSE' -and
    [string]$verificationRows[0].EndpointState -ceq [string]$invocation.collector.expectedResponseState -and
    [string]$verificationRows[0].SignerThumbprint -ceq 'DF46FA4B81065AB273A88F4E1FA8AC0F2EE518CC') 'Extracted R18ZT signed response verification failed.'

$expectedExtractedNames = @('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig') + @($invocation.collector.expectedPayloadPaths)
$actualExtractedFiles = @(Get-ChildItem -LiteralPath $verificationRoot -File -Recurse -ErrorAction Stop | Select-Object -First ($expectedExtractedNames.Count + 1))
$actualExtractedNames = @($actualExtractedFiles | ForEach-Object { $_.FullName.Substring($verificationRoot.TrimEnd('\').Length + 1).Replace('\','/') } | Sort-Object)
Require ($actualExtractedFiles.Count -eq $expectedExtractedNames.Count -and
    ($actualExtractedNames -join "`n") -ceq (@($expectedExtractedNames | Sort-Object) -join "`n")) 'R18ZT extracted response membership changed.'
foreach ($record in @($match.manifest.files)) {
    $localPayload = Get-SafeExtractPath $verificationRoot ([string]$record.path)
    Require ((Get-Item -LiteralPath $localPayload -ErrorAction Stop).Length -eq [int64]$record.bytes -and
        (Get-Sha256 $localPayload) -ceq [string]$record.sha256) "R18ZT extracted response payload bytes/hash changed: $($record.path)"
}
$resultPath = Get-SafeExtractPath $verificationRoot ([string]$invocation.collector.resultPayloadPath)
$stdoutPath = Get-SafeExtractPath $verificationRoot ([string]$invocation.collector.stdoutPayloadPath)
$resultObject = Read-JsonFile $resultPath ([int64]$invocation.collector.maximumResultJsonBytes)
$stdoutObject = Read-JsonFile $stdoutPath ([int64]$invocation.collector.maximumStdoutJsonBytes)
Require ([string](Get-NestedValue $resultObject ([string]$invocation.collector.resultRequestIdProperty) 'R18ZT endpoint RESULT') -ceq 'REQ_R18ZT1') 'R18ZT endpoint RESULT request identity changed.'
Require ([string](Get-NestedValue $resultObject ([string]$invocation.collector.resultStateProperty) 'R18ZT endpoint RESULT') -ceq [string]$invocation.collector.expectedResultState) 'R18ZT endpoint RESULT state changed.'
Require ([string]$stdoutObject.schema -ceq 'argos_opencv_scribe_r18zt_batch_launch_v2' -and
    [string]$stdoutObject.state -ceq 'PASS_R18ZT_BATCH_WORKER_STARTED' -and [string]$stdoutObject.proves -ceq 'ASYNC_WORKER_LAUNCH_ONLY') 'R18ZT launcher stdout state changed.'
Require ([string]$stdoutObject.revision -ceq [string]$invocation.packageRevision -and
    [string]$stdoutObject.outputRoot -ceq [string]$invocation.collector.expectedJbodOutputRoot -and
    [bool]$stdoutObject.ownedProcessStarted -and -not [bool]$stdoutObject.automaticRetryAllowed -and
    -not [bool]$stdoutObject.completionClaimed -and [bool]$stdoutObject.reviewOnly -and
    -not [bool]$stdoutObject.productionRoutingEnabled) 'R18ZT launcher stdout launch-only/authority contract changed.'
Require ([string]$stdoutObject.workerStateAtConfirmation -in @('RUNNING','COMPLETED_EXACT_TERMINAL')) 'R18ZT launcher stdout worker confirmation state changed.'

$resultHash = Get-Sha256 $resultPath
$stdoutHash = Get-Sha256 $stdoutPath
if (-not $recoverFinalRoot) { [IO.Directory]::Move($partialRoot, $finalRoot) }
$preflightResult.launchState = [string]$stdoutObject.state
$preflightResult.workerStateAtConfirmation = [string]$stdoutObject.workerStateAtConfirmation
$preflightResult.resultPayloadPath = [string]$invocation.collector.resultPayloadPath
$preflightResult.resultPayloadSha256 = $resultHash
$preflightResult.stdoutPayloadPath = [string]$invocation.collector.stdoutPayloadPath
$preflightResult.stdoutPayloadSha256 = $stdoutHash
$preflightResult.finalRootRecoveryPerformed = $recoverFinalRoot
$preflightResult.mutationsPerformed = $true
$collectionGateStagingPath = if ($recoverFinalRoot) { $collectionGateRecoveryPartialPath } else { $collectionGatePartialPath }
Write-JsonAtomicCreateNew $collectionGateStagingPath $collectionGatePath $preflightResult
$preflightResult | ConvertTo-Json -Depth 32
