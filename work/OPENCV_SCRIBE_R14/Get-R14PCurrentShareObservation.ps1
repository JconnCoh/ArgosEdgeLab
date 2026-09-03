#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Observe
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Observe)) {
    throw 'Specify exactly one of -Preflight or -Observe.'
}

$expectedRequestId = 'REQ_20260902T204408092Z_R14P'
$expectedUncRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$expectedAcceptedSinceUtc = '2026-09-01T23:06:02.9830703Z'
$expectedAcceptedBoundaryMode = 'EXCLUSIVE_PRIOR_ZERO_UNRESOLVED_GATE_CREATED_UTC'
$expectedBoundaryGateState = 'PASS_R6V2_CURRENT_ROUTE_SHARE_AND_QUEUE_GATE'
$expectedTerminalResponseStates = @('PASS_STATUS_COLLECTED','PASS_DATA_PULL','PASS_INSITE_DIAGNOSTIC','PASS_MAINTENANCE_PATCH','FAILED','FAILED_RESPONSE_CONSTRUCTION')
$expectedInvocationLeaf = 'Get-R14PCurrentShareObservation.invocation.json'
$expectedOutputLeaf = 'R14P_CURRENT_SHARE_OBSERVATION.json'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$strictUtf8 = New-Object Text.UTF8Encoding($false, $true)
$outputUtf8 = New-Object Text.UTF8Encoding($false)

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Normalize-Root {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return '' }
    return $Path.Replace('/', '\').TrimEnd('\')
}

function Limit-Text {
    param([string]$Value, [int]$MaximumLength = 512)
    if ($null -eq $Value) { return '' }
    if ($Value.Length -le $MaximumLength) { return $Value }
    return $Value.Substring(0, $MaximumLength)
}

function Get-Sha256 {
    param([string]$Path)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha256 = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-', '') }
        finally { $sha256.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-BytesSha256 {
    param([byte[]]$Bytes)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha256.Dispose() }
}

function Resolve-ProjectFile {
    param([string]$RelativePath, [string]$Label)
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) "$Label relative path is empty."
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "$Label must be project-relative."
    $full = [IO.Path]::GetFullPath((Join-Path $projectRoot $RelativePath.Replace('/', '\')))
    $prefix = $projectRoot.TrimEnd('\') + '\'
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "$Label escapes the project root."
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "$Label is absent: $full"
    return $full
}

function Read-BoundedUtf8File {
    param([string]$Path, [int64]$MaximumBytes, [string]$Label)
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    Assert-True ($item.Length -le $MaximumBytes) "$Label exceeds $MaximumBytes bytes."
    $bytes = [IO.File]::ReadAllBytes($item.FullName)
    try { return $strictUtf8.GetString($bytes).TrimStart([char]0xFEFF) }
    catch { throw "$Label is not valid UTF-8: $Path" }
}

function Get-BoundedFiles {
    param([string]$Path, [int]$Maximum, [string]$Label)
    $rows = @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction Stop | Select-Object -First ($Maximum + 1))
    Assert-True ($rows.Count -le $Maximum) "$Label exceeded its $Maximum-file bound."
    return $rows
}

function Read-ZipEntryBytes {
    param($Entry, [int64]$MaximumBytes, [string]$Label)
    Assert-True ($null -ne $Entry) "$Label entry is absent."
    Assert-True ([int64]$Entry.Length -ge 0 -and [int64]$Entry.Length -le $MaximumBytes) "$Label entry exceeds its byte bound."
    $buffer = New-Object byte[] ([int]$Entry.Length)
    $stream = $Entry.Open()
    try {
        $offset = 0
        while ($offset -lt $buffer.Length) {
            $read = $stream.Read($buffer, $offset, $buffer.Length - $offset)
            Assert-True ($read -gt 0) "$Label entry ended before its declared length."
            $offset += $read
        }
        Assert-True ($stream.ReadByte() -eq -1) "$Label entry exceeds its declared length."
    }
    finally { $stream.Dispose() }
    return ,$buffer
}

function Read-SignedZipManifest {
    param(
        [string]$PackagePath,
        [string]$ManifestEntryName,
        [string]$SignatureEntryName,
        $Certificate,
        [int]$MaximumEntries,
        [int64]$MaximumManifestBytes,
        [int64]$MaximumSignatureBytes,
        [string]$Label
    )
    $archive = [IO.Compression.ZipFile]::OpenRead($PackagePath)
    try {
        $entries = @($archive.Entries)
        Assert-True ($entries.Count -le $MaximumEntries) "$Label package exceeded its $MaximumEntries-entry bound."
        $manifestEntries = @($entries | Where-Object { $_.FullName -ceq $ManifestEntryName })
        $signatureEntries = @($entries | Where-Object { $_.FullName -ceq $SignatureEntryName })
        Assert-True ($manifestEntries.Count -eq 1) "$Label package does not contain exactly one $ManifestEntryName."
        Assert-True ($signatureEntries.Count -eq 1) "$Label package does not contain exactly one $SignatureEntryName."
        $manifestBytes = Read-ZipEntryBytes -Entry $manifestEntries[0] -MaximumBytes $MaximumManifestBytes -Label "$Label manifest"
        $signatureBytes = Read-ZipEntryBytes -Entry $signatureEntries[0] -MaximumBytes $MaximumSignatureBytes -Label "$Label signature"
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
        try {
            $signatureValid = $rsa.VerifyData(
                $manifestBytes,
                $signatureBytes,
                [Security.Cryptography.HashAlgorithmName]::SHA256,
                [Security.Cryptography.RSASignaturePadding]::Pkcs1
            )
        }
        finally { $rsa.Dispose() }
        Assert-True $signatureValid "$Label package signature is invalid."
        try { $manifestText = $strictUtf8.GetString($manifestBytes).TrimStart([char]0xFEFF) }
        catch { throw "$Label manifest is not valid UTF-8." }
        try { $manifest = $manifestText | ConvertFrom-Json }
        catch { throw "$Label manifest is not valid JSON: $($_.Exception.Message)" }
        return [pscustomobject]@{
            manifest = $manifest
            manifestSha256 = Get-BytesSha256 -Bytes $manifestBytes
            signatureBytes = [int64]$signatureBytes.Length
            packageEntryCount = $entries.Count
        }
    }
    finally { $archive.Dispose() }
}

function Get-SnapshotRows {
    param([object[]]$Files)
    return @($Files | Sort-Object -Property Name | ForEach-Object {
        '{0}|{1}|{2}' -f $_.Name, $_.Length, $_.LastWriteTimeUtc.Ticks
    })
}

function Test-SameSnapshot {
    param([object[]]$Before, [object[]]$After)
    $beforeRows = @(Get-SnapshotRows -Files $Before)
    $afterRows = @(Get-SnapshotRows -Files $After)
    $difference = @(Compare-Object -ReferenceObject $beforeRows -DifferenceObject $afterRows -SyncWindow 0)
    return ($difference.Count -eq 0)
}

function Write-NewJson {
    param([string]$Path, [object]$Value)
    $bytes = $outputUtf8.GetBytes((($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

Add-Type -AssemblyName System.IO.Compression.FileSystem

$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $expectedInvocationLeaf))
Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'R14P invocation manifest is absent.'
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.Equals($expectedInvocationPath, [StringComparison]::OrdinalIgnoreCase)) 'R14P requires its exact adjacent invocation manifest.'
$invocationText = Read-BoundedUtf8File -Path $invocationPath -MaximumBytes 65536 -Label 'R14P invocation manifest'
$invocation = $invocationText | ConvertFrom-Json

Assert-True ([string]$invocation.schema -ceq 'argos_r14p_current_share_observation_invocation_v1') 'R14P invocation schema changed.'
Assert-True ([string]$invocation.actionClassification -ceq 'OBSERVE_REMOTE_READ_ONLY_LOCAL_EVIDENCE_CREATE_NEW') 'R14P action classification changed.'
Assert-True ([string]$invocation.requestId -ceq $expectedRequestId) 'R14P request ID changed.'
Assert-True ([string]$invocation.driveName -ceq 'U') 'R14P drive name changed.'
Assert-True ((Normalize-Root ([string]$invocation.expectedInspectionRevsUnc)).Equals((Normalize-Root $expectedUncRoot), [StringComparison]::OrdinalIgnoreCase)) 'R14P InspectionRevs UNC changed.'
Assert-True ([string]$invocation.portalRelativeRoot -ceq 'ProjectPortalRO') 'R14P portal relative root changed.'
Assert-True ([string]$invocation.requestsRelativeRoot -ceq 'ProjectPortalRO\requests') 'R14P requests relative root changed.'
Assert-True ([string]$invocation.processedRelativeRoot -ceq 'ProjectPortalRO\requests\processed') 'R14P processed relative root changed.'
Assert-True ([string]$invocation.responsesRelativeRoot -ceq 'ProjectPortalRO\responses') 'R14P responses relative root changed.'
Assert-True ([string]$invocation.acceptedSinceUtc -ceq $expectedAcceptedSinceUtc) 'R14P accepted-request floor changed.'
Assert-True ([string]$invocation.acceptedSinceBoundaryMode -ceq $expectedAcceptedBoundaryMode) 'R14P accepted-request boundary mode changed.'
$declaredTerminalStates = @($invocation.terminalResponseStates | ForEach-Object { [string]$_ })
Assert-True ($declaredTerminalStates.Count -eq $expectedTerminalResponseStates.Count) 'R14P terminal response-state cardinality changed.'
for ($terminalStateIndex = 0; $terminalStateIndex -lt $expectedTerminalResponseStates.Count; $terminalStateIndex++) {
    Assert-True ($declaredTerminalStates[$terminalStateIndex] -ceq $expectedTerminalResponseStates[$terminalStateIndex]) 'R14P explicit terminal response-state set changed.'
}
Assert-True ([string]$invocation.outputLeaf -ceq $expectedOutputLeaf) 'R14P output leaf changed.'
Assert-True ([int]$invocation.scanBounds.maximumTopLevelRequestFiles -eq 1000) 'R14P top-level request bound changed.'
Assert-True ([int]$invocation.scanBounds.maximumProcessedFiles -eq 2000) 'R14P processed bound changed.'
Assert-True ([int]$invocation.scanBounds.maximumResponseFiles -eq 2000) 'R14P response bound changed.'
Assert-True ([int]$invocation.scanBounds.maximumZipEntriesPerPackage -eq 256) 'R14P ZIP-entry bound changed.'
Assert-True ([int64]$invocation.scanBounds.maximumManifestBytes -eq 1048576) 'R14P manifest byte bound changed.'
Assert-True ([int64]$invocation.scanBounds.maximumSignatureBytes -eq 8192) 'R14P signature byte bound changed.'
Assert-True ([int]$invocation.scanBounds.maximumCorrelationRows -eq 512) 'R14P correlation-row bound changed.'
Assert-True ([int]$invocation.scanBounds.maximumRecordedErrorRows -eq 64) 'R14P error-row bound changed.'
Assert-True ([bool]$invocation.requirements.requireZeroPendingRequestFiles) 'R14P zero-pending requirement changed.'
Assert-True ([bool]$invocation.requirements.requireZeroUnresolvedEarlierAcceptedRequests) 'R14P zero-unresolved requirement changed.'
Assert-True ([bool]$invocation.requirements.requireStableQueueSnapshot) 'R14P stable-snapshot requirement changed.'
Assert-True ([bool]$invocation.requirements.requireTargetAbsentFromPendingProcessedAndResponses) 'R14P target-absence requirement changed.'
Assert-True ([bool]$invocation.requirements.requirePriorZeroUnresolvedBoundary) 'R14P prior zero-unresolved boundary requirement changed.'
Assert-True ([bool]$invocation.requirements.requireOnlyExplicitTerminalResponseStates) 'R14P explicit terminal-state requirement changed.'
Assert-True (-not [bool]$invocation.requirements.shareWritesAllowed -and -not [bool]$invocation.requirements.mappingChangesAllowed -and -not [bool]$invocation.requirements.automaticRetryAllowed) 'R14P read-only/no-retry boundary changed.'
Assert-True ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.publicationAuthorizedByObservation -and -not [bool]$invocation.authority.automaticIdentityAuthority -and -not [bool]$invocation.authority.trainingEligible -and -not [bool]$invocation.authority.xmlEligible -and -not [bool]$invocation.authority.productionEligible -and -not [bool]$invocation.authority.productionRoutingEnabled -and -not [bool]$invocation.authority.mayClearHolds) 'R14P observation authority widened.'
Assert-True ($null -eq $invocation.publicationParent) 'R14P observation must not declare a publication parent.'

$referenceRows = @($invocation.referencePatterns)
Assert-True ($referenceRows.Count -eq 2) 'R14P reference-pattern cardinality changed.'
foreach ($reference in $referenceRows) {
    Assert-True ([bool]$reference.referenceOnly -and -not [bool]$reference.publicationParent) 'R14P pattern was promoted beyond reference-only use.'
    $referencePath = Resolve-ProjectFile -RelativePath ([string]$reference.path) -Label 'R14P reference pattern'
    Assert-True ((Get-Sha256 $referencePath) -ceq ([string]$reference.sha256).ToUpperInvariant()) "R14P reference pattern changed: $referencePath"
}

$priorBoundaryPath = Resolve-ProjectFile -RelativePath ([string]$invocation.priorZeroUnresolvedBoundary.path) -Label 'R14P prior zero-unresolved boundary'
Assert-True ((Get-Sha256 $priorBoundaryPath) -ceq ([string]$invocation.priorZeroUnresolvedBoundary.sha256).ToUpperInvariant()) 'R14P prior zero-unresolved boundary hash changed.'
$priorBoundary = (Read-BoundedUtf8File -Path $priorBoundaryPath -MaximumBytes 1048576 -Label 'R14P prior zero-unresolved boundary') | ConvertFrom-Json
Assert-True ([string]$invocation.priorZeroUnresolvedBoundary.stateProperty -ceq 'state') 'R14P prior boundary state selector changed.'
Assert-True ([string]$invocation.priorZeroUnresolvedBoundary.requiredState -ceq $expectedBoundaryGateState) 'R14P prior boundary required state changed.'
Assert-True ([string]$priorBoundary.state -ceq $expectedBoundaryGateState) 'R14P prior zero-unresolved boundary state changed.'
Assert-True ([string]$priorBoundary.createdUtc -ceq $expectedAcceptedSinceUtc -and [string]$invocation.priorZeroUnresolvedBoundary.createdUtc -ceq $expectedAcceptedSinceUtc) 'R14P prior boundary timestamp changed.'
Assert-True ([int]$priorBoundary.queueObservation.unresolvedEarlierAcceptedRequestCount -eq 0 -and [int]$invocation.priorZeroUnresolvedBoundary.requiredUnresolvedEarlierAcceptedRequestCount -eq 0) 'R14P prior boundary did not prove zero unresolved accepted requests.'

$requestCertificatePath = Resolve-ProjectFile -RelativePath ([string]$invocation.requestSigner.certificateRelativePath) -Label 'R14P request signer certificate'
$responseCertificatePath = Resolve-ProjectFile -RelativePath ([string]$invocation.responseSigner.certificateRelativePath) -Label 'R14P response signer certificate'
Assert-True ((Get-Sha256 $requestCertificatePath) -ceq ([string]$invocation.requestSigner.certificateSha256).ToUpperInvariant()) 'R14P request signer certificate hash changed.'
Assert-True ((Get-Sha256 $responseCertificatePath) -ceq ([string]$invocation.responseSigner.certificateSha256).ToUpperInvariant()) 'R14P response signer certificate hash changed.'
$requestCertificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($requestCertificatePath)
$responseCertificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($responseCertificatePath)

try {
    $expectedRequestThumbprint = ([string]$invocation.requestSigner.thumbprint).Replace(' ', '').ToUpperInvariant()
    $expectedResponseThumbprint = ([string]$invocation.responseSigner.thumbprint).Replace(' ', '').ToUpperInvariant()
    Assert-True ($requestCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant() -ceq $expectedRequestThumbprint) 'R14P request signer certificate thumbprint changed.'
    Assert-True ($responseCertificate.Thumbprint.Replace(' ', '').ToUpperInvariant() -ceq $expectedResponseThumbprint) 'R14P response signer certificate thumbprint changed.'
    Assert-True ([string]$invocation.responseSigner.sourceRole -ceq 'JBOD') 'R14P response source role changed.'

    $acceptedSince = [DateTimeOffset]::Parse($expectedAcceptedSinceUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
    $outputPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $expectedOutputLeaf))
    Assert-True ($outputPath.StartsWith(($PSScriptRoot.TrimEnd('\') + '\'), [StringComparison]::OrdinalIgnoreCase)) 'R14P output escaped its namespace.'
    Assert-True (-not (Test-Path -LiteralPath $outputPath)) 'R14P create-new observation already exists.'

    $drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
    $logicalRows = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop)
    Assert-True ($logicalRows.Count -eq 1) 'R14P persistent U: logical-disk cardinality changed.'
    $logical = $logicalRows[0]
    $displayRoot = Normalize-Root ([string]$drive.DisplayRoot)
    $providerRoot = Normalize-Root ([string]$logical.ProviderName)
    Assert-True ($displayRoot.Equals((Normalize-Root $expectedUncRoot), [StringComparison]::OrdinalIgnoreCase)) 'R14P U: PowerShell DisplayRoot changed.'
    Assert-True ($providerRoot.Equals((Normalize-Root $expectedUncRoot), [StringComparison]::OrdinalIgnoreCase)) 'R14P U: Win32 ProviderName changed.'
    Assert-True ([int]$logical.DriveType -eq 4) 'R14P U: is not a persistent network logical disk.'

    $portalRoot = 'U:\ProjectPortalRO'
    $requestsRoot = 'U:\ProjectPortalRO\requests'
    $processedRoot = 'U:\ProjectPortalRO\requests\processed'
    $responsesRoot = 'U:\ProjectPortalRO\responses'
    Assert-True (Test-Path -LiteralPath $portalRoot -PathType Container) 'R14P portal root is unreadable.'
    Assert-True (Test-Path -LiteralPath $requestsRoot -PathType Container) 'R14P requests root is unreadable.'
    Assert-True (Test-Path -LiteralPath $processedRoot -PathType Container) 'R14P processed root is unreadable.'
    Assert-True (Test-Path -LiteralPath $responsesRoot -PathType Container) 'R14P responses root is unreadable.'

    $observationStartedUtc = [DateTime]::UtcNow.ToString('o')
    $topLevelBefore = @(Get-BoundedFiles -Path $requestsRoot -Maximum ([int]$invocation.scanBounds.maximumTopLevelRequestFiles) -Label 'R14P top-level request scan')
    $processedBefore = @(Get-BoundedFiles -Path $processedRoot -Maximum ([int]$invocation.scanBounds.maximumProcessedFiles) -Label 'R14P processed-request scan')
    $responsesBefore = @(Get-BoundedFiles -Path $responsesRoot -Maximum ([int]$invocation.scanBounds.maximumResponseFiles) -Label 'R14P response scan')

    $pendingRows = @($topLevelBefore)
    $pendingTransportRows = @($topLevelBefore | Where-Object {
        $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) -or
        $_.Name.EndsWith('.upload', [StringComparison]::OrdinalIgnoreCase)
    })
    $targetPendingRows = @($topLevelBefore | Where-Object {
        $_.Name.Equals($expectedRequestId, [StringComparison]::OrdinalIgnoreCase) -or
        $_.Name.StartsWith(($expectedRequestId + '.'), [StringComparison]::OrdinalIgnoreCase)
    })

    $processedReadyRows = @($processedBefore | Where-Object { $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) })
    $responseReadyRows = @($responsesBefore | Where-Object { $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) })
    $processedErrors = New-Object Collections.Generic.List[object]
    $responseErrors = New-Object Collections.Generic.List[object]
    $processedErrorCount = 0
    $responseErrorCount = 0
    $acceptedRows = New-Object Collections.Generic.List[object]
    $responseManifestRows = New-Object Collections.Generic.List[object]

    foreach ($file in $processedReadyRows) {
        try {
            $signed = Read-SignedZipManifest -PackagePath $file.FullName -ManifestEntryName 'PORTAL_REQUEST_MANIFEST.json' -SignatureEntryName 'PORTAL_REQUEST_MANIFEST.sig' -Certificate $requestCertificate -MaximumEntries ([int]$invocation.scanBounds.maximumZipEntriesPerPackage) -MaximumManifestBytes ([int64]$invocation.scanBounds.maximumManifestBytes) -MaximumSignatureBytes ([int64]$invocation.scanBounds.maximumSignatureBytes) -Label ('R14P processed request ' + $file.Name)
            $manifest = $signed.manifest
            Assert-True ([string]$manifest.schema -ceq 'argos_project_portal_request_manifest_v1') 'Processed request manifest schema changed.'
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.requestId)) 'Processed request manifest has no request ID.'
            Assert-True ([string]$manifest.signatureAlgorithm -ceq 'RSA-SHA256-PKCS1') 'Processed request signature algorithm changed.'
            Assert-True (([string]$manifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -ceq $expectedRequestThumbprint) 'Processed request signer thumbprint changed.'
            $leafRequestId = $file.Name.Substring(0, $file.Name.Length - '.ready.zip'.Length)
            Assert-True ($leafRequestId -ceq [string]$manifest.requestId) 'Processed request filename and signed manifest request ID differ.'
            $createdUtc = [DateTimeOffset]::Parse([string]$manifest.createdUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
            $acceptedRows.Add([pscustomobject]@{
                requestId = [string]$manifest.requestId
                targetRole = [string]$manifest.targetRole
                jobClass = [string]$manifest.jobClass
                requestCreatedUtc = $createdUtc.ToUniversalTime().ToString('o')
                processedLastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
                processedLeaf = $file.Name
                packageBytes = [int64]$file.Length
                manifestSha256 = [string]$signed.manifestSha256
                signatureVerified = $true
                acceptedAfterProvenBoundary = ($file.LastWriteTimeUtc -gt $acceptedSince.UtcDateTime)
            })
        }
        catch {
            $processedErrorCount++
            if ($processedErrors.Count -lt [int]$invocation.scanBounds.maximumRecordedErrorRows) {
                $processedErrors.Add([pscustomobject]@{ package = $file.Name; error = Limit-Text $_.Exception.Message })
            }
        }
    }

    foreach ($file in $responseReadyRows) {
        try {
            $signed = Read-SignedZipManifest -PackagePath $file.FullName -ManifestEntryName 'PORTAL_RESPONSE_MANIFEST.json' -SignatureEntryName 'PORTAL_RESPONSE_MANIFEST.sig' -Certificate $responseCertificate -MaximumEntries ([int]$invocation.scanBounds.maximumZipEntriesPerPackage) -MaximumManifestBytes ([int64]$invocation.scanBounds.maximumManifestBytes) -MaximumSignatureBytes ([int64]$invocation.scanBounds.maximumSignatureBytes) -Label ('R14P response ' + $file.Name)
            $manifest = $signed.manifest
            Assert-True ([string]$manifest.schema -ceq 'argos_project_portal_response_manifest_v1') 'Response manifest schema changed.'
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.requestId)) 'Response manifest has no request ID.'
            Assert-True (-not [string]::IsNullOrWhiteSpace([string]$manifest.responseId)) 'Response manifest has no response ID.'
            Assert-True ([string]$manifest.sourceRole -ceq [string]$invocation.responseSigner.sourceRole) 'Response source role is not the pinned JBOD role.'
            Assert-True ([string]$manifest.signatureAlgorithm -ceq 'RSA-SHA256-PKCS1') 'Response signature algorithm changed.'
            Assert-True (([string]$manifest.signerThumbprint).Replace(' ', '').ToUpperInvariant() -ceq $expectedResponseThumbprint) 'Response signer thumbprint changed.'
            Assert-True ($declaredTerminalStates -ccontains [string]$manifest.state) "Response manifest state is not an explicit terminal state: $($manifest.state)"
            Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'Response safety flags widened.'
            $createdUtc = [DateTimeOffset]::Parse([string]$manifest.createdUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
            $responseManifestRows.Add([pscustomobject]@{
                requestId = [string]$manifest.requestId
                responseId = [string]$manifest.responseId
                responseState = [string]$manifest.state
                sourceRole = [string]$manifest.sourceRole
                responseCreatedUtc = $createdUtc.ToUniversalTime().ToString('o')
                responseLastWriteUtc = $file.LastWriteTimeUtc.ToString('o')
                responseLeaf = $file.Name
                packageBytes = [int64]$file.Length
                manifestSha256 = [string]$signed.manifestSha256
                signatureVerified = $true
            })
        }
        catch {
            $responseErrorCount++
            if ($responseErrors.Count -lt [int]$invocation.scanBounds.maximumRecordedErrorRows) {
                $responseErrors.Add([pscustomobject]@{ package = $file.Name; error = Limit-Text $_.Exception.Message })
            }
        }
    }

    $acceptedAfterBoundaryRows = @($acceptedRows.ToArray() | Where-Object { [bool]$_.acceptedAfterProvenBoundary })
    Assert-True ($acceptedAfterBoundaryRows.Count -le [int]$invocation.scanBounds.maximumCorrelationRows) 'R14P accepted-after-boundary correlations exceeded their bound.'
    $acceptedIdentityGroups = @($acceptedAfterBoundaryRows | Group-Object -Property requestId)
    $acceptedDuplicateGroups = @($acceptedIdentityGroups | Where-Object { $_.Count -ne 1 })
    $correlations = New-Object Collections.Generic.List[object]
    foreach ($accepted in $acceptedAfterBoundaryRows) {
        $requestCreated = [DateTimeOffset]::Parse([string]$accepted.requestCreatedUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal)
        $matches = @($responseManifestRows.ToArray() | Where-Object {
            $_.requestId -ceq $accepted.requestId -and
            [DateTimeOffset]::Parse([string]$_.responseCreatedUtc, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::AssumeUniversal) -ge $requestCreated
        })
        $correlations.Add([pscustomobject]@{
            requestId = $accepted.requestId
            targetRole = $accepted.targetRole
            jobClass = $accepted.jobClass
            requestCreatedUtc = $accepted.requestCreatedUtc
            processedLeaf = $accepted.processedLeaf
            signedTerminalResponseCount = $matches.Count
            resolved = ($matches.Count -eq 1)
            responseId = if ($matches.Count -eq 1) { [string]$matches[0].responseId } else { $null }
            responseState = if ($matches.Count -eq 1) { [string]$matches[0].responseState } else { $null }
            responseLeaf = if ($matches.Count -eq 1) { [string]$matches[0].responseLeaf } else { $null }
        })
    }

    $correlationRows = @($correlations.ToArray())
    $unresolvedRows = @($correlationRows | Where-Object { [int]$_.signedTerminalResponseCount -eq 0 })
    $ambiguousRows = @($correlationRows | Where-Object { [int]$_.signedTerminalResponseCount -gt 1 })
    $targetProcessedByLeaf = @($processedBefore | Where-Object {
        $_.Name.Equals($expectedRequestId, [StringComparison]::OrdinalIgnoreCase) -or
        $_.Name.StartsWith(($expectedRequestId + '.'), [StringComparison]::OrdinalIgnoreCase)
    })
    $targetProcessedByManifest = @($acceptedRows.ToArray() | Where-Object { $_.requestId -ceq $expectedRequestId })
    $targetResponseByManifest = @($responseManifestRows.ToArray() | Where-Object { $_.requestId -ceq $expectedRequestId })

    $topLevelAfter = @(Get-BoundedFiles -Path $requestsRoot -Maximum ([int]$invocation.scanBounds.maximumTopLevelRequestFiles) -Label 'R14P final top-level request scan')
    $processedAfter = @(Get-BoundedFiles -Path $processedRoot -Maximum ([int]$invocation.scanBounds.maximumProcessedFiles) -Label 'R14P final processed-request scan')
    $responsesAfter = @(Get-BoundedFiles -Path $responsesRoot -Maximum ([int]$invocation.scanBounds.maximumResponseFiles) -Label 'R14P final response scan')
    $finalPendingRows = @($topLevelAfter)
    $finalPendingTransportRows = @($topLevelAfter | Where-Object {
        $_.Name.EndsWith('.ready.zip', [StringComparison]::OrdinalIgnoreCase) -or
        $_.Name.EndsWith('.upload', [StringComparison]::OrdinalIgnoreCase)
    })
    $topLevelStable = Test-SameSnapshot -Before $topLevelBefore -After $topLevelAfter
    $processedStable = Test-SameSnapshot -Before $processedBefore -After $processedAfter
    $responsesStable = Test-SameSnapshot -Before $responsesBefore -After $responsesAfter

    $processedErrorSummary = if ($processedErrors.Count -gt 0) { ': ' + $processedErrors[0].package + ': ' + $processedErrors[0].error } else { '' }
    $responseErrorSummary = if ($responseErrors.Count -gt 0) { ': ' + $responseErrors[0].package + ': ' + $responseErrors[0].error } else { '' }
    Assert-True ($processedErrorCount -eq 0) "R14P processed-request scan had $processedErrorCount error(s)$processedErrorSummary"
    Assert-True ($responseErrorCount -eq 0) "R14P response-manifest scan had $responseErrorCount error(s)$responseErrorSummary"
    $pendingSummary = (@($pendingRows + $finalPendingRows | Select-Object -First 10 | ForEach-Object { $_.Name }) -join ',')
    Assert-True ($pendingRows.Count -eq 0 -and $finalPendingRows.Count -eq 0) "R14P share has a pending request or upload: $pendingSummary"
    Assert-True ($targetPendingRows.Count -eq 0 -and $targetProcessedByLeaf.Count -eq 0 -and $targetProcessedByManifest.Count -eq 0 -and $targetResponseByManifest.Count -eq 0) 'R14P exact request ID already exists in a portal namespace.'
    Assert-True ($acceptedDuplicateGroups.Count -eq 0) 'R14P processed requests after the proven boundary contain a duplicate signed request ID.'
    $unresolvedSummary = (@($unresolvedRows | Select-Object -First 10 | ForEach-Object { $_.requestId }) -join ',')
    $ambiguousSummary = (@($ambiguousRows | Select-Object -First 10 | ForEach-Object { $_.requestId }) -join ',')
    Assert-True ($unresolvedRows.Count -eq 0) "R14P has an earlier accepted request without one matching signed terminal response: $unresolvedSummary"
    Assert-True ($ambiguousRows.Count -eq 0) "R14P has an earlier accepted request with multiple matching signed terminal responses: $ambiguousSummary"
    Assert-True ($topLevelStable -and $processedStable -and $responsesStable) 'R14P queue changed during the bounded observation.'

    $latestAcceptedRequest = $null
    $latestTerminalResponse = $null
    if ($acceptedAfterBoundaryRows.Count -gt 0) {
        $latestAcceptedRequest = [string](@($acceptedAfterBoundaryRows | Sort-Object -Property processedLastWriteUtc -Descending)[0].requestId)
    }
    if ($responseManifestRows.Count -gt 0) {
        $latestTerminalResponse = [string](@($responseManifestRows.ToArray() | Sort-Object -Property responseCreatedUtc -Descending)[0].responseId)
    }

    $gate = [ordered]@{
        schema = 'argos_r14p_current_share_observation_v1'
        observedUtc = [DateTime]::UtcNow.ToString('o')
        observationStartedUtc = $observationStartedUtc
        state = 'PASS_R14P_CURRENT_SHARE_AND_QUEUE_OBSERVATION'
        disposition = 'PENDING_PUBLICATION_SEPARATE_GATE_REQUIRED'
        requestId = $expectedRequestId
        invocationManifest = $invocationPath
        invocationManifestSha256 = Get-Sha256 $invocationPath
        mapping = [ordered]@{
            drive = 'U:'
            expectedRoot = Normalize-Root $expectedUncRoot
            powerShellDisplayRoot = $displayRoot
            powerShellDisplayRootExact = $true
            win32LogicalDiskProviderName = $providerRoot
            win32LogicalDiskProviderExact = $true
            win32LogicalDiskDriveType = [int]$logical.DriveType
            requestsRootReadable = $true
            processedRootReadable = $true
            responsesRootReadable = $true
            mappingChanged = $false
            mappingRemoved = $false
        }
        scan = [ordered]@{
            acceptedSinceUtc = $acceptedSince.ToUniversalTime().ToString('o')
            acceptedSinceBoundaryMode = $expectedAcceptedBoundaryMode
            priorZeroUnresolvedBoundaryPath = [string]$invocation.priorZeroUnresolvedBoundary.path
            priorZeroUnresolvedBoundarySha256 = ([string]$invocation.priorZeroUnresolvedBoundary.sha256).ToUpperInvariant()
            priorZeroUnresolvedBoundaryState = [string]$priorBoundary.state
            priorZeroUnresolvedBoundaryUnresolvedCount = [int]$priorBoundary.queueObservation.unresolvedEarlierAcceptedRequestCount
            topLevelRequestFileScanCount = $topLevelBefore.Count
            topLevelRequestScanErrorCount = 0
            pendingRequestFileCount = $pendingRows.Count
            pendingReadyOrUploadCount = $pendingTransportRows.Count
            finalPendingRequestFileCount = $finalPendingRows.Count
            finalPendingReadyOrUploadCount = $finalPendingTransportRows.Count
            processedFileScanCount = $processedBefore.Count
            processedReadyPackageScanCount = $processedReadyRows.Count
            processedManifestScanErrorCount = $processedErrorCount
            processedManifestScanErrors = $processedErrors.ToArray()
            processedManifestScanErrorsTruncated = ($processedErrorCount - $processedErrors.Count)
            acceptedRequestCountAfterProvenBoundary = $acceptedAfterBoundaryRows.Count
            acceptedDuplicateRequestIdCount = $acceptedDuplicateGroups.Count
            responseFileScanCount = $responsesBefore.Count
            responseReadyPackageScanCount = $responseReadyRows.Count
            responseManifestScanCount = $responseReadyRows.Count
            responseManifestScanErrorCount = $responseErrorCount
            responseManifestScanErrors = $responseErrors.ToArray()
            responseManifestScanErrorsTruncated = ($responseErrorCount - $responseErrors.Count)
            signedResponseManifestCount = $responseManifestRows.Count
            explicitTerminalResponseStates = $declaredTerminalStates
            resolvedEarlierAcceptedRequestCount = @($correlationRows | Where-Object { [bool]$_.resolved }).Count
            unresolvedEarlierAcceptedRequestCount = $unresolvedRows.Count
            ambiguousEarlierAcceptedRequestCount = $ambiguousRows.Count
            exactRequestIdPendingMatchCount = $targetPendingRows.Count
            exactRequestIdProcessedLeafMatchCount = $targetProcessedByLeaf.Count
            exactRequestIdProcessedManifestMatchCount = $targetProcessedByManifest.Count
            exactRequestIdResponseManifestMatchCount = $targetResponseByManifest.Count
            topLevelSnapshotStable = $topLevelStable
            processedSnapshotStable = $processedStable
            responseSnapshotStable = $responsesStable
            latestAcceptedRequestId = $latestAcceptedRequest
            latestSignedTerminalResponseId = $latestTerminalResponse
            correlations = $correlationRows
        }
        signatureVerification = [ordered]@{
            requestManifestCertificateSha256 = ([string]$invocation.requestSigner.certificateSha256).ToUpperInvariant()
            requestManifestSignerThumbprint = $expectedRequestThumbprint
            responseManifestCertificateSha256 = ([string]$invocation.responseSigner.certificateSha256).ToUpperInvariant()
            responseManifestSignerThumbprint = $expectedResponseThumbprint
            responseManifestSourceRole = [string]$invocation.responseSigner.sourceRole
            requestManifestSignaturesCryptographicallyVerified = $true
            responseManifestSignaturesCryptographicallyVerified = $true
        }
        safety = [ordered]@{
            targetAbsentFromPendingProcessedAndResponses = $true
            zeroPendingRequests = $true
            zeroUnresolvedEarlierAcceptedRequests = $true
            stableBoundedSnapshot = $true
            shareWritesPerformed = $false
            mappingChangesPerformed = $false
            targetExecuted = $false
            publicationPerformed = $false
            publicationAuthorizedByObservation = $false
            automaticRetryAllowed = $false
            localEvidenceCreateNew = [bool]$Observe
        }
        authority = [ordered]@{
            reviewOnly = $true
            automaticIdentityAuthority = $false
            mayClearHolds = $false
            trainingEligible = $false
            xmlEligible = $false
            productionEligible = $false
            productionRoutingEnabled = $false
        }
    }

    if ($Preflight) {
        $gate.schema = 'argos_r14p_current_share_observation_preflight_v1'
        $gate.state = 'PASS_R14P_CURRENT_SHARE_OBSERVATION_PREFLIGHT'
        $gate.safety.localEvidenceCreateNew = $false
        $gate | ConvertTo-Json -Depth 12
        return
    }

    Write-NewJson -Path $outputPath -Value $gate
    [ordered]@{
        schema = 'argos_r14p_current_share_observation_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R14P_CURRENT_SHARE_OBSERVATION_WRITTEN_CREATE_NEW'
        requestId = $expectedRequestId
        outputPath = $outputPath
        outputSha256 = Get-Sha256 $outputPath
        shareWritesPerformed = $false
        mappingChangesPerformed = $false
        publicationPerformed = $false
        localEvidenceCreated = $true
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
}
finally {
    if ($null -ne $requestCertificate) { $requestCertificate.Dispose() }
    if ($null -ne $responseCertificate) { $responseCertificate.Dispose() }
}
