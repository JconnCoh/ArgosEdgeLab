#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [switch]$PackageValidationOnly,
    [string]$PayloadRoot = '',
    [string]$WorkRoot = 'D:\A2\w\ocv\R18ZT1',
    [string]$OutputRoot = 'D:\A2\o\ocv\R18ZT1',
    [string]$ProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals',
    [string]$PythonPath = 'D:\AFCV1\rt\python.exe',
    [string]$ExpectedPythonSha256 = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packageRevision = 'R18ZT_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260906'
$runnerRevision = 'R18ZT_EXISTING_ORIENTED_CROPS_PUBLIC_PROVIDER_BATCH_20260906A'
$envelopeRevision = 'R18ZT_EXISTING_ORIENTED_CROPS_ASYNC_REVIEW_ONLY_20260906'
$payloadManifestSha = '0C8A0A36DD8B4950022D04FDBC2065C3EB41D3C258CDD7D1435E4B68A7159E40'
$configurationSha = '67A5D3B4BA3FA2187CEE4E4DA002CC2E72D1D7C3DE5D45C4C056D49579090844'
$envelopeSha = 'E34C78C52B30AA7745DC71008E35BE97B4CB3256C46C20FEBCF579C15C9E2240'
$delegateSha = '4BC2EC71CCB58EEA0901B9534A5B585CE3C12BC8413EE208031CA3D498E70132'
$providerSha = 'AEF048D3CCEAF378A9FF43D5844DD1A28431E662F5BC54AFF384C4DB73A2C793'
$providerRevision = 'ARGOS_OPENCV_SCRIBE_V1R18ZT_GENERIC_HOLD_RESCUE_DIAGNOSTIC_20260906'
$referenceBundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$baseManifestSha = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
$supplementalManifestSha = 'C7BD53925A522C21B8BAAE3E7A9B8B3817234A0665239FC1629CA3B09C9741DD'
$crosswalkSha = '84637040AF7920706616C6769D9AFEEC969895FBCE5070C52AA2ADAD1FF1ABA2'
$looGateSha = 'D8F0C0923BFDD6B82C4B0B0C57142825C08C0DB3F5395210A5DD7FE2E6E8DAD8'
$installedLauncher = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18ZT1.ps1'
$configuredWorkRoot = 'D:\A2\w\ocv\R18ZT1'
$configuredOutputRoot = 'D:\A2\o\ocv\R18ZT1'
$configuredProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals'
$configuredProviderPath = 'D:\A2\w\ocv\R18ZT1\OPENCV_SCRIBE_R18ZT\ArgosOpenCvScribeV1R18ZT.py'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Require-FinalSha([string]$Value, [string]$Label) {
    Require ($Value -cmatch '^[A-F0-9]{64}$') "R18ZT final hash is absent: $Label"
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Get-StreamSha256([IO.Stream]$Stream) {
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($Stream))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = 0
    if ($parts.Count -gt 0) {
        $longest = [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    }
    Require (($full.Length + $Reserve) -lt 200) "R18ZT unsafe effective path: $full"
    Require ($longest -le 80) "R18ZT unsafe path component: $full"
}

function Get-SafeRelativePath([string]$Value, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is empty."
    $relative = $Value.Replace('/', '\')
    Require (-not [IO.Path]::IsPathRooted($relative)) "$Label is rooted: $Value"
    $parts = @($relative.Split([char[]]@('\'), [StringSplitOptions]::None))
    Require ($parts.Count -gt 0) "$Label is empty."
    foreach ($part in $parts) {
        Require (-not [string]::IsNullOrWhiteSpace($part) -and $part -ne '.' -and $part -ne '..') "$Label contains an unsafe component: $Value"
        Require ($part.Length -le 80) "$Label contains an overlong component: $Value"
    }
    return $relative
}

function Assert-ContainedPath([string]$Root, [string]$Candidate, [string]$Label) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    Require ($candidateFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)) "$Label escaped its root: $candidateFull"
}

function Assert-ReviewOnlyAuthority([object]$Authority, [string]$Label) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) "$Label is not review-only."
    foreach ($field in @(
        'identityAcceptanceAuthorized',
        'automaticReferenceAdmissionAuthorized',
        'holdClearanceAuthorized',
        'trainingAuthorized',
        'activationAuthorized',
        'xmlAuthorized',
        'productionAuthorized',
        'sourceMutationAuthorized',
        'sourceDeletionAuthorized'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "$Label authority changed: $field"
    }
}

function Assert-RunnerAuthority([object]$Authority) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) 'R18ZT runner configuration is not review-only.'
    foreach ($field in @(
        'automaticIdentityAuthority',
        'automaticReferenceAdmissionAuthorized',
        'trainingEligible',
        'activationAuthorized',
        'xmlEligible',
        'productionEligible',
        'mayClearHolds',
        'sourceMutationAllowed',
        'automaticRetryAllowed'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "R18ZT runner authority changed: $field"
    }
}

function Assert-ExactFieldSet([object]$Value, [string[]]$Expected, [string]$Label) {
    Require ($null -ne $Value) "$Label is absent."
    $actual = @($Value.PSObject.Properties.Name | Sort-Object)
    $expectedSorted = @($Expected | Sort-Object)
    Require ($actual.Count -eq $expectedSorted.Count -and ($actual -join "`n") -ceq ($expectedSorted -join "`n")) "$Label field set changed."
}

function Assert-NoRuntimeEnvironmentOverrides {
    $forbidden = @([Environment]::GetEnvironmentVariables().Keys |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ -match '^(PYTHONPATH|PYTHONHOME|PYTHONSTARTUP|PYTHONINSPECT)$' } |
        Sort-Object -Unique)
    Require ($forbidden.Count -eq 0) ('R18ZT forbidden Python runtime environment variable(s): ' + ($forbidden -join ', '))
}

function Quote-ProcessArgument([string]$Value) {
    Require ($Value.IndexOf('"') -lt 0) 'R18ZT process argument contains a quote.'
    return '"' + $Value + '"'
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18ZT create-new JSON exists: $Path"
    $json = ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

Require (-not $PackageValidationOnly -or ($Preflight -and $Rehearsal)) 'R18ZT package-only validation requires both -Preflight and -Rehearsal.'
Require (-not $Rehearsal -or $Preflight) 'R18ZT rehearsal is non-mutating and requires -Preflight.'
Require ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "R18ZT wrong computer: $($env:COMPUTERNAME)"
if (-not $PackageValidationOnly) {
    Require ([IO.Path]::GetFullPath($WorkRoot).Equals($configuredWorkRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT live work root override is refused.'
    Require ([IO.Path]::GetFullPath($OutputRoot).Equals($configuredOutputRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT live output root override is refused.'
    Require ([IO.Path]::GetFullPath($ProposalRoot).Equals($configuredProposalRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT live proposal root override is refused.'
}
foreach ($pin in @(
    [pscustomobject]@{value=$payloadManifestSha;label='payload manifest'},
    [pscustomobject]@{value=$configurationSha;label='configuration'},
    [pscustomobject]@{value=$envelopeSha;label='execution envelope'},
    [pscustomobject]@{value=$delegateSha;label='batch runner'},
    [pscustomobject]@{value=$providerSha;label='provider'}
)) { Require-FinalSha ([string]$pin.value) ([string]$pin.label) }
Require ($providerRevision -notmatch '^PENDING_') 'R18ZT provider revision is not finalized.'

$payload = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath($PayloadRoot) }
$payloadFilesRoot = Join-Path $payload 'files'
$payloadManifestPath = Join-Path $payload 'R18ZT_PAYLOAD_MANIFEST.json'
$partialRoot = $WorkRoot + '.partial'
$failedRoot = $WorkRoot + '.failed'
$configurationRelative = 'OPENCV_SCRIBE_R18ZT_BATCH\R18ZT_BATCH_CONFIGURATION.json'
$envelopeRelative = 'OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTBatchExecutionEnvelope.py'
$delegateRelative = 'OPENCV_SCRIBE_R18ZT_BATCH\Run-R18ZTExistingOrientedCrops.py'
$providerRelative = 'OPENCV_SCRIBE_R18ZT\ArgosOpenCvScribeV1R18ZT.py'
$configurationPath = Join-Path $WorkRoot $configurationRelative
$envelopePath = Join-Path $WorkRoot $envelopeRelative
$delegatePath = Join-Path $WorkRoot $delegateRelative
$providerPath = Join-Path $WorkRoot $providerRelative
$launchPath = Join-Path $OutputRoot 'LAUNCH.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

$requiredDependencies = @($payloadManifestPath, $payloadFilesRoot, $PythonPath, $ReferenceBundlePath)
if (-not $PackageValidationOnly) { $requiredDependencies += $ProposalRoot }
foreach ($path in $requiredDependencies) {
    Require (Test-Path -LiteralPath $path) "R18ZT dependency absent: $path"
    Assert-PathBudget $path
}
Require ((Get-Sha256 $payloadManifestPath) -eq $payloadManifestSha) 'R18ZT payload manifest changed.'
Require ((Get-Sha256 $PythonPath) -eq $ExpectedPythonSha256) 'R18ZT Python runtime changed.'
Require ((Get-Sha256 $ReferenceBundlePath) -eq $referenceBundleSha) 'R18ZT reference bundle changed.'
if (-not $Rehearsal) {
    $installationPath = 'D:\AFCV1\INSTALLATION.json'
    Require (Test-Path -LiteralPath $installationPath -PathType Leaf) 'R18ZT runtime installation evidence absent.'
    Require ((Get-Sha256 $installationPath) -eq $installationSha) 'R18ZT runtime installation evidence changed.'
}

$manifest = Get-Content -LiteralPath $payloadManifestPath -Raw | ConvertFrom-Json
Require ([string]$manifest.schema -eq 'argos_opencv_scribe_r18zt_payload_manifest_v1' -and [string]$manifest.revision -eq $packageRevision) 'R18ZT payload manifest contract changed.'
Require ([string]$manifest.state -eq 'FROZEN_UNPUBLISHED' -and [bool]$manifest.finalizationComplete) 'R18ZT payload manifest is not finalized.'
Assert-ReviewOnlyAuthority $manifest.authority 'R18ZT payload manifest'
foreach ($field in @(
    'providerTransitiveClosureComplete',
    'runnerHashPinned',
    'providerHashPinned',
    'configurationHashPinned',
    'executionEnvelopeHashPinned',
    'allPayloadBytesAndHashesPinned',
    'allDevelopmentAndRegressionGatesPinned'
)) {
    $property = $manifest.finalization.PSObject.Properties[$field]
    Require ($null -ne $property -and [bool]$property.Value) "R18ZT payload finalization is incomplete: $field"
}

$files = @($manifest.files)
Require ($files.Count -ge 4 -and $files.Count -le 96) 'R18ZT payload manifest file count is outside the bounded range.'
$payloadPathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$payloadRows = New-Object Collections.Generic.List[object]
foreach ($file in $files) {
    $relative = Get-SafeRelativePath ([string]$file.installRelativePath) 'R18ZT payload path'
    Require ($payloadPathSet.Add($relative)) "R18ZT duplicate payload path: $relative"
    Require ($relative -notmatch '(^|\\)(__pycache__|tests?|fixtures?)(\\|$)' -and $relative -notmatch '\.(pyc|pyo)$') "R18ZT prohibited runtime payload member: $relative"
    $expectedHash = [string]$file.sha256
    Require-FinalSha $expectedHash "payload member $relative"
    Require ([int64]$file.bytes -gt 0 -and [int64]$file.bytes -le 67108864) "R18ZT payload member byte bound changed: $relative"
    $source = Join-Path $payloadFilesRoot $relative
    $destination = Join-Path $partialRoot $relative
    Assert-ContainedPath $payloadFilesRoot $source 'R18ZT payload source'
    Assert-ContainedPath $partialRoot $destination 'R18ZT payload destination'
    Require (Test-Path -LiteralPath $source -PathType Leaf) "R18ZT payload file absent: $relative"
    $sourceItem = Get-Item -LiteralPath $source -Force
    Require (-not $sourceItem.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) "R18ZT payload reparse file: $relative"
    Require ($sourceItem.Length -eq [int64]$file.bytes) "R18ZT payload length changed: $relative"
    Require ((Get-Sha256 $source) -eq $expectedHash) "R18ZT payload hash changed: $relative"
    Assert-PathBudget $source
    Assert-PathBudget $destination
    $payloadRows.Add([pscustomobject]@{relativePath=$relative;source=$source;destination=$destination;sha256=$expectedHash})
}

$requiredPayloadHashes = [ordered]@{
    $configurationRelative = $configurationSha
    $envelopeRelative = $envelopeSha
    $delegateRelative = $delegateSha
    $providerRelative = $providerSha
}
foreach ($required in $requiredPayloadHashes.GetEnumerator()) {
    $matches = @($payloadRows | Where-Object { $_.relativePath.Equals([string]$required.Key, [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1) "R18ZT required payload member changed: $($required.Key)"
    Require ([string]$matches[0].sha256 -eq [string]$required.Value) "R18ZT required payload hash changed: $($required.Key)"
}

$requiredExternal = [ordered]@{
    'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip' = $referenceBundleSha
    'D:\AFCV1\rt\python.exe' = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
    'D:\AFCV1\INSTALLATION.json' = $installationSha
}
$externalRows = @($manifest.externalDependencies)
Require ($externalRows.Count -eq $requiredExternal.Count) 'R18ZT external dependency count changed.'
foreach ($required in $requiredExternal.GetEnumerator()) {
    $matches = @($externalRows | Where-Object { [IO.Path]::GetFullPath(([string]$_.path).Replace('/', '\')).Equals([IO.Path]::GetFullPath([string]$required.Key), [StringComparison]::OrdinalIgnoreCase) })
    Require ($matches.Count -eq 1 -and [string]$matches[0].sha256 -eq [string]$required.Value) "R18ZT external dependency changed: $($required.Key)"
}

$configurationSource = Join-Path $payloadFilesRoot $configurationRelative
$configuration = Get-Content -LiteralPath $configurationSource -Raw | ConvertFrom-Json
Require ((Get-Sha256 $configurationSource) -eq $configurationSha) 'R18ZT configuration changed.'
Assert-ExactFieldSet $configuration @('schema','batchId','revision','proposalRoot','outputRoot','provider','references','limits','authority') 'R18ZT configuration'
Assert-ExactFieldSet $configuration.provider @('path','sha256','revision') 'R18ZT provider binding'
Assert-ExactFieldSet $configuration.references @('manifestPath','manifestSha256','roots','supplementalManifestPath','supplementalManifestSha256','r18zExactLineageLooGatePath','r18zExactLineageLooGateSha256','exactScribeLineageCrosswalkPath','exactScribeLineageCrosswalkSha256') 'R18ZT references'
Assert-ExactFieldSet $configuration.limits @('maximumDirectChildren','maximumIdentityCharacters','maximumJsonBytes','maximumOrientedInputBytes','maximumProviderResultBytes') 'R18ZT limits'
Assert-ExactFieldSet $configuration.authority @('reviewOnly','automaticIdentityAuthority','automaticReferenceAdmissionAuthorized','trainingEligible','activationAuthorized','xmlEligible','productionEligible','mayClearHolds','sourceMutationAllowed','automaticRetryAllowed') 'R18ZT runner authority'
Require ([string]$configuration.schema -eq 'argos_opencv_scribe_r18zt_batch_configuration_v1' -and [string]$configuration.batchId -eq 'R18ZT1' -and [string]$configuration.revision -eq $runnerRevision) 'R18ZT configuration contract changed.'
Require ([IO.Path]::GetFullPath([string]$configuration.outputRoot).Equals($configuredOutputRoot, [StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFullPath([string]$configuration.proposalRoot).Equals($configuredProposalRoot, [StringComparison]::OrdinalIgnoreCase)) 'R18ZT configuration roots changed.'
Require ([IO.Path]::GetFullPath([string]$configuration.provider.path).Equals($configuredProviderPath, [StringComparison]::OrdinalIgnoreCase) -and [string]$configuration.provider.sha256 -eq $providerSha -and [string]$configuration.provider.revision -eq $providerRevision) 'R18ZT provider binding changed.'
Require ([string]$configuration.references.manifestSha256 -eq $baseManifestSha -and [string]$configuration.references.supplementalManifestSha256 -eq $supplementalManifestSha -and [string]$configuration.references.exactScribeLineageCrosswalkSha256 -eq $crosswalkSha -and [string]$configuration.references.r18zExactLineageLooGateSha256 -eq $looGateSha) 'R18ZT reference pins changed.'
Require ([int]$configuration.limits.maximumDirectChildren -eq 10000 -and [int]$configuration.limits.maximumIdentityCharacters -eq 160 -and [int64]$configuration.limits.maximumJsonBytes -eq 16777216 -and [int64]$configuration.limits.maximumOrientedInputBytes -eq 67108864 -and [int64]$configuration.limits.maximumProviderResultBytes -eq 67108864) 'R18ZT bounded runner limits changed.'
Assert-RunnerAuthority $configuration.authority
Assert-NoRuntimeEnvironmentOverrides

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($ReferenceBundlePath)
$archiveEntryCount = 0
$archivePathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$baseManifestEntries = New-Object Collections.Generic.List[object]
try {
    foreach ($entry in $archive.Entries) {
        Require ($archiveEntryCount -lt 10000) 'R18ZT reference archive entry bound exceeded.'
        $entryName = ([string]$entry.FullName).Replace('/', '\').TrimEnd('\')
        $relative = Get-SafeRelativePath $entryName 'R18ZT reference archive path'
        Require ($archivePathSet.Add($relative)) "R18ZT duplicate reference archive path: $relative"
        $destination = Join-Path $partialRoot $relative
        Assert-ContainedPath $partialRoot $destination 'R18ZT reference archive destination'
        Assert-PathBudget $destination
        $archiveEntryCount++
        if ($relative.Equals('refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json', [StringComparison]::OrdinalIgnoreCase)) { $baseManifestEntries.Add($entry) }
    }
    Require ($archiveEntryCount -gt 0) 'R18ZT reference archive is empty.'
    Require ($baseManifestEntries.Count -eq 1) 'R18ZT base reference manifest member changed.'
    $baseManifestStream = $baseManifestEntries[0].Open()
    try { Require ((Get-StreamSha256 $baseManifestStream) -eq $baseManifestSha) 'R18ZT base reference manifest changed.' }
    finally { $baseManifestStream.Dispose() }
}
finally { $archive.Dispose() }

foreach ($path in @(
    $WorkRoot,
    $partialRoot,
    $failedRoot,
    $OutputRoot,
    $configurationPath,
    $envelopePath,
    $delegatePath,
    $providerPath,
    $launchPath,
    $failurePath,
    $installedLauncher,
    (Join-Path $OutputRoot 'STATUS.json'),
    (Join-Path $OutputRoot 'RUNNING.json'),
    (Join-Path $OutputRoot 'COMPLETE.json'),
    (Join-Path $OutputRoot 'WORKER.stdout.log'),
    (Join-Path $OutputRoot 'WORKER.stderr.log'),
    (Join-Path $OutputRoot 'INVENTORY.json'),
    (Join-Path $OutputRoot 'CASE_INDEX.json'),
    (Join-Path $OutputRoot 'AGGREGATE.json'),
    (Join-Path $OutputRoot 'cases\0123456789ABCDEF\RESULT.json')
)) { Assert-PathBudget $path }
foreach ($path in @($WorkRoot, $partialRoot, $failedRoot, $OutputRoot)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18ZT fresh target exists: $path"
}
$pythonCommand = Get-Command -Name $PythonPath -CommandType Application -ErrorAction Stop
Require ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($PythonPath), [StringComparison]::OrdinalIgnoreCase)) 'R18ZT Python resolution changed.'
$outputDriveName = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($OutputRoot)).Substring(0, 1)
$outputDrive = Get-PSDrive -Name $outputDriveName -ErrorAction Stop
Require ([int64]$outputDrive.Free -ge 10737418240) 'R18ZT output drive has less than the required free space.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_launch_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = $(if ($PackageValidationOnly) { 'PASS_R18ZT_STATIC_PACKAGE_PREFLIGHT' } else { 'PASS_R18ZT_BATCH_LAUNCH_PREFLIGHT' })
        revision = $packageRevision
        runnerRevision = $runnerRevision
        envelopeRevision = $envelopeRevision
        rehearsal = [bool]$Rehearsal
        packageValidationOnly = [bool]$PackageValidationOnly
        installedLauncher = $installedLauncher
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        pythonSha256 = $ExpectedPythonSha256
        referenceBundleSha256 = $referenceBundleSha
        referenceArchiveEntryCount = $archiveEntryCount
        proposalRoot = $ProposalRoot
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        sourceInventoryDeferredToOwnedWorker = $true
        sourceImageBytesHashed = $false
        pixelsDecoded = $false
        targetWritesPerformed = $false
        processInspectionPerformed = $false
        processStarted = $false
        taskActionsPerformed = $false
        automaticRetryAllowed = $false
        completionClaimed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        sourceMutationPerformed = $false
        identityAccepted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12
    return
}

$ownedProcess = $null
$ownedProcessStarted = $false
$ownedChildTerminated = $false
try {
    [void](New-Item -ItemType Directory -Path $partialRoot)
    [IO.Compression.ZipFile]::ExtractToDirectory($ReferenceBundlePath, $partialRoot)
    foreach ($row in $payloadRows) {
        $destinationParent = Split-Path -Parent $row.destination
        [void](New-Item -ItemType Directory -Path $destinationParent -Force)
        Copy-Item -LiteralPath $row.source -Destination $row.destination -ErrorAction Stop
        Require ((Get-Sha256 $row.destination) -eq $row.sha256) "R18ZT staged payload changed: $($row.relativePath)"
    }
    Move-Item -LiteralPath $partialRoot -Destination $WorkRoot -ErrorAction Stop
    foreach ($row in $payloadRows) {
        $staged = Join-Path $WorkRoot $row.relativePath
        Require ((Get-Sha256 $staged) -eq $row.sha256) "R18ZT committed payload changed: $($row.relativePath)"
    }
    Require ((Get-Sha256 $configurationPath) -eq $configurationSha) 'R18ZT staged configuration changed.'
    Require ((Get-Sha256 $envelopePath) -eq $envelopeSha) 'R18ZT staged execution envelope changed.'
    Require ((Get-Sha256 $delegatePath) -eq $delegateSha) 'R18ZT staged batch runner changed.'
    Require ((Get-Sha256 $providerPath) -eq $providerSha) 'R18ZT staged provider changed.'
    [void](New-Item -ItemType Directory -Path $OutputRoot)

    $arguments = @(
        (Quote-ProcessArgument $envelopePath),
        '--delegate', (Quote-ProcessArgument $delegatePath),
        '--delegate-sha256', (Quote-ProcessArgument $delegateSha),
        '--configuration', (Quote-ProcessArgument $configurationPath),
        '--output-root', (Quote-ProcessArgument $OutputRoot)
    ) -join ' '
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $PythonPath
    $startInfo.Arguments = $arguments
    $startInfo.WorkingDirectory = $WorkRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $false
    $startInfo.RedirectStandardError = $false
    $ownedProcess = New-Object Diagnostics.Process
    $ownedProcess.StartInfo = $startInfo
    Require ($ownedProcess.Start()) 'R18ZT batch worker did not start.'
    $ownedProcessStarted = $true
    Start-Sleep -Seconds 2
    $ownedProcess.Refresh()
    Require (-not $ownedProcess.HasExited) 'R18ZT batch worker exited before launch confirmation.'

    $launch = [ordered]@{
        schema = 'argos_opencv_scribe_r18zt_batch_launch_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18ZT_BATCH_WORKER_STARTED'
        proves = 'ASYNC_WORKER_LAUNCH_ONLY'
        completionClaimed = $false
        terminalStatusStateExpected = 'COMPLETE_R18ZT_EXISTING_ORIENTED_CROPS_REVIEW_ONLY'
        terminalPointerLeaf = 'COMPLETE.json'
        revision = $packageRevision
        runnerRevision = $runnerRevision
        envelopeRevision = $envelopeRevision
        computerName = $env:COMPUTERNAME
        processId = [int]$ownedProcess.Id
        processStartTimeUtc = $ownedProcess.StartTime.ToUniversalTime().ToString('o')
        installedLauncher = $installedLauncher
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        proposalRoot = $ProposalRoot
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        pythonSha256 = $ExpectedPythonSha256
        referenceBundleSha256 = $referenceBundleSha
        providerSha256 = $providerSha
        delegateSha256 = $delegateSha
        executionEnvelopeSha256 = $envelopeSha
        sourceInventoryDeferredToOwnedWorker = $true
        sourceImageBytesHashedByLauncher = $false
        pixelsDecodedByLauncher = $false
        processInspectionPerformed = $false
        taskActionCount = 0
        existingProcessActionCount = 0
        ownedProcessStarted = $true
        automaticRetryAllowed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        sourceMutationPerformed = $false
        identityAccepted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    Write-JsonNew $launchPath $launch 12
    Write-Output -InputObject ($launch | ConvertTo-Json -Compress -Depth 12)
    $ownedProcess.Dispose()
    $ownedProcess = $null
}
catch {
    $detail = $_.Exception.Message
    if ($null -ne $ownedProcess) {
        try {
            if (-not $ownedProcess.HasExited) {
                $ownedProcess.Kill()
                $ownedChildTerminated = $true
            }
        }
        catch {}
        $ownedProcess.Dispose()
        $ownedProcess = $null
    }
    if ((Test-Path -LiteralPath $partialRoot) -and -not (Test-Path -LiteralPath $failedRoot)) {
        Move-Item -LiteralPath $partialRoot -Destination $failedRoot -ErrorAction SilentlyContinue
    }
    if ((Test-Path -LiteralPath $OutputRoot -PathType Container) -and -not (Test-Path -LiteralPath $failurePath)) {
        try {
            Write-JsonNew $failurePath ([ordered]@{
                schema = 'argos_opencv_scribe_r18zt_batch_launch_failure_v1'
                createdUtc = [DateTime]::UtcNow.ToString('o')
                state = 'HOLD_R18ZT_BATCH_LAUNCH_FAILURE'
                detail = $detail
                ownedProcessStarted = $ownedProcessStarted
                ownedChildTerminated = $ownedChildTerminated
                automaticRetryAllowed = $false
                completionClaimed = $false
                publicationAuthorized = $false
                publicationPerformed = $false
                sourceMutationPerformed = $false
                identityAccepted = $false
                reviewOnly = $true
                productionRoutingEnabled = $false
            }) 8
        }
        catch {}
    }
    throw
}
