#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [switch]$PackageValidationOnly,
    [string]$PayloadRoot = '',
    [string]$WorkRoot = 'D:\A2\w\ocv\R18T1',
    [string]$OutputRoot = 'D:\A2\o\ocv\R18T1',
    [string]$ProposalRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\identity\proposals',
    [string]$PythonPath = 'D:\AFCV1\rt\python.exe',
    [string]$ExpectedPythonSha256 = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1',
    [string]$ReferenceBundlePath = 'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'R18T_LIVE_ONLY_EXECUTION_ENVELOPE_CORRECTION_REVIEW_ONLY_20260904A'
$payloadManifestSha = '1B0CBDA330DF8756EE57F6B7C6F14EC1F271BB67F3C047DC0ECD0D0FB443F5AD'
$referenceBundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$readerSha = '3AF68D778E297531DD527DD9D65C75FD17BD1FB9C2EC797CB840B10A674532AD'
$cropSha = 'EF4C58589CA8885B5CBDE0A989D3F94EE8C447925818DC0FA4E50B26B87A8B9F'
$r18pEnvelopeSha = '5B6AA224E844FCEA22DEC6A9D10C863437F039CA73EC258C263DF539905791D0'
$delegateSha = 'B826767EA21BB148DD30A719595B23DD818FD9CFC08B347FEAFD9FD4959F4E3C'
$providerSha = '51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5'
$r18qProviderSha = 'AB20CFB25D223D40D31237118436446018AE213F800ECF1652213EB942C40DC1'
$cohortSha = '62A5E864C174A6E2C7F368E784E8DD0F86A11828036401351B2FCBB6336A2661'
$bindingModuleSha = 'A4CC721663B69CB44CE52EC5155FCFA9576309A74E5ADBADF81BE2403C732670'
$workerSha = '23F52C8FEC096F6587521B78AF8242C80E8687040457F9AE197858DB0B00AED7'
$configurationSha = '6209774A20E8C9A085C7A96D438946CC0FD5143D43C79A6BA65A275E85E37C2B'
$baseManifestSha = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
$supplementalManifestSha = 'FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114'
$installedLauncher = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R18T1.ps1'
$payload = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) {
    $PSScriptRoot
}
else {
    [IO.Path]::GetFullPath($PayloadRoot)
}
$payloadFilesRoot = Join-Path $payload 'files'
$payloadManifestPath = Join-Path $payload 'R18T_PAYLOAD_MANIFEST.json'
$partialRoot = $WorkRoot + '.partial'
$failedRoot = $WorkRoot + '.failed'
$runtimeConfiguration = Join-Path $WorkRoot 'RUNTIME_CONFIGURATION.json'
$cohortRelativePath = 'OPENCV_SCRIBE_R18T\R18T_LIVE_REVIEW_COHORT.json'
$moduleRelativePath = 'OPENCV_SCRIBE_R18T\R18T.LiveBinding.psm1'
$workerRelativePath = 'OPENCV_SCRIBE_R18T\Run-R18TExecutionEnvelope.py'
$delegateRelativePath = 'OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py'
$configurationRelativePath = 'OPENCV_SCRIBE_R18J\R18J_JBOD_CONFIGURATION.json'
$cohortSource = Join-Path $payloadFilesRoot $cohortRelativePath
$moduleSource = Join-Path $payloadFilesRoot $moduleRelativePath
$configurationSource = Join-Path $payloadFilesRoot $configurationRelativePath
$cohortPath = Join-Path $WorkRoot $cohortRelativePath
$workerPath = Join-Path $WorkRoot $workerRelativePath
$delegatePath = Join-Path $WorkRoot $delegateRelativePath
$launchPath = Join-Path $OutputRoot 'LAUNCH.json'
$failurePath = Join-Path $OutputRoot 'FAILURE.json'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
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
    $longest = if ($parts.Count -eq 0) {
        0
    }
    else {
        [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    }
    Require (($full.Length + $Reserve) -lt 200) "R18T unsafe effective path: $full"
    Require ($longest -le 80) "R18T unsafe path component: $full"
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18T create-new JSON exists: $Path"
    $json = ($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

function Assert-ReviewOnlyAuthority([object]$Authority, [string]$Label) {
    Require ($null -ne $Authority -and [bool]$Authority.reviewOnly) "$Label is not review-only."
    foreach ($field in @(
        'identityAcceptanceAuthorized',
        'automaticReferenceAdmissionAuthorized',
        'trainingAuthorized',
        'activationAuthorized',
        'xmlAuthorized',
        'productionAuthorized'
    )) {
        $property = $Authority.PSObject.Properties[$field]
        Require (
            $null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value
        ) "$Label authority changed: $field"
    }
}

function Get-SafeRelativePath([string]$Value, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Value)) "$Label is empty."
    $relative = $Value.Replace('/', '\')
    Require (-not [IO.Path]::IsPathRooted($relative)) "$Label is rooted: $Value"
    $parts = @($relative.Split([char[]]@('\'), [StringSplitOptions]::None))
    Require ($parts.Count -gt 0) "$Label is empty."
    foreach ($part in $parts) {
        Require (
            -not [string]::IsNullOrWhiteSpace($part) -and $part -ne '.' -and $part -ne '..'
        ) "$Label contains an unsafe component: $Value"
        Require ($part.Length -le 80) "$Label contains an overlong component: $Value"
    }
    return $relative
}

function Assert-ContainedPath([string]$Root, [string]$Candidate, [string]$Label) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $candidateFull = [IO.Path]::GetFullPath($Candidate)
    Require (
        $candidateFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase)
    ) "$Label escaped its root: $candidateFull"
}

function Assert-NoRuntimeEnvironmentOverrides {
    $forbidden = @([Environment]::GetEnvironmentVariables().Keys |
        ForEach-Object { [string]$_ } |
        Where-Object { $_ -match '^(PYTHONPATH|PYTHONHOME|PYTHONSTARTUP|PYTHONINSPECT)$' } |
        Sort-Object -Unique)
    Require ($forbidden.Count -eq 0) (
        'R18T forbidden Python runtime environment variable(s): ' + ($forbidden -join ', ')
    )
}

function Quote-ProcessArgument([string]$Value) {
    Require ($Value.IndexOf('"') -lt 0) 'R18T process argument contains a quote.'
    return '"' + $Value + '"'
}

Require (
    -not $PackageValidationOnly -or ($Preflight -and $Rehearsal)
) 'R18T package-only validation requires both -Preflight and -Rehearsal.'
Require (
    $env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)
) "R18T wrong computer: $($env:COMPUTERNAME)"

$requiredDependencies = @(
    $payloadManifestPath,
    $payloadFilesRoot,
    $PythonPath,
    $ReferenceBundlePath
)
if (-not $PackageValidationOnly) { $requiredDependencies += $ProposalRoot }
foreach ($path in $requiredDependencies) {
    Require (Test-Path -LiteralPath $path) "R18T dependency absent: $path"
    Assert-PathBudget $path
}
Require ((Get-Sha256 $payloadManifestPath) -eq $payloadManifestSha) 'R18T payload manifest changed.'
Require ((Get-Sha256 $PythonPath) -eq $ExpectedPythonSha256) 'R18T Python runtime changed.'
Require ((Get-Sha256 $ReferenceBundlePath) -eq $referenceBundleSha) 'R18T reference bundle changed.'
if (-not $Rehearsal) {
    $installationPath = 'D:\AFCV1\INSTALLATION.json'
    Require (Test-Path -LiteralPath $installationPath -PathType Leaf) 'R18T runtime installation evidence absent.'
    Require ((Get-Sha256 $installationPath) -eq $installationSha) 'R18T runtime installation evidence changed.'
}

$manifest = Get-Content -LiteralPath $payloadManifestPath -Raw | ConvertFrom-Json
Require (
    [string]$manifest.schema -eq 'argos_opencv_scribe_r18t_payload_manifest_v1' -and
    [string]$manifest.revision -eq $revision
) 'R18T payload manifest contract changed.'
Assert-ReviewOnlyAuthority $manifest.authority 'R18T payload manifest'
$files = @($manifest.files)
Require ($files.Count -gt 0) 'R18T payload manifest has no files.'
$payloadPathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$payloadRows = New-Object Collections.Generic.List[object]
foreach ($file in $files) {
    $relative = Get-SafeRelativePath ([string]$file.installRelativePath) 'R18T payload path'
    Require ($payloadPathSet.Add($relative)) "R18T duplicate payload path: $relative"
    Require (
        -not ([IO.Path]::GetFileName($relative)).Equals(
            'R18R_REVIEW_COHORT.json', [StringComparison]::OrdinalIgnoreCase
        )
    ) 'R18T payload contains the withdrawn predecessor cohort.'
    $expectedHash = [string]$file.sha256
    Require ($expectedHash -cmatch '^[A-F0-9]{64}$') "R18T invalid payload hash: $relative"
    $source = Join-Path $payloadFilesRoot $relative
    $destination = Join-Path $partialRoot $relative
    Assert-ContainedPath $payloadFilesRoot $source 'R18T payload source'
    Assert-ContainedPath $partialRoot $destination 'R18T payload destination'
    Require (Test-Path -LiteralPath $source -PathType Leaf) "R18T payload file absent: $relative"
    $sourceItem = Get-Item -LiteralPath $source -Force
    Require (-not $sourceItem.Attributes.HasFlag([IO.FileAttributes]::ReparsePoint)) "R18T payload reparse file: $relative"
    Require ($sourceItem.Length -eq [int64]$file.bytes) "R18T payload length changed: $relative"
    Require ((Get-Sha256 $source) -eq $expectedHash) "R18T payload hash changed: $relative"
    Assert-PathBudget $source
    Assert-PathBudget $destination
    $payloadRows.Add([pscustomobject]@{ relativePath=$relative; source=$source; destination=$destination; sha256=$expectedHash })
}

$requiredPayloadHashes = [ordered]@{
    'OPENCV_SCRIBE_R18T\R18T_LIVE_REVIEW_COHORT.json' = $cohortSha
    'OPENCV_SCRIBE_R18T\R18T.LiveBinding.psm1' = $bindingModuleSha
    'OPENCV_SCRIBE_R18T\Run-R18TExecutionEnvelope.py' = $workerSha
    'OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py' = $delegateSha
    'OPENCV_SCRIBE_R18R\ArgosOpenCvScribeV1R18R.py' = $providerSha
    'OPENCV_SCRIBE_R18Q\ArgosOpenCvScribeV1R18Q.py' = $r18qProviderSha
    'OPENCV_SCRIBE_R18H\ArgosOpenCvScribeV1R18H.py' = $readerSha
    'OPENCV_SCRIBE_R18J\ArgosOpenCvScribeCropSweepR18J.py' = $cropSha
    'OPENCV_SCRIBE_R18J\R18J_JBOD_CONFIGURATION.json' = $configurationSha
    'OPENCV_SCRIBE_R18P\Run-R18PReferenceIsolatedCorpus.py' = $r18pEnvelopeSha
    'OPENCV_SCRIBE_R18F\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json' = $supplementalManifestSha
}
foreach ($required in $requiredPayloadHashes.GetEnumerator()) {
    $matches = @($payloadRows | Where-Object {
        $_.relativePath.Equals([string]$required.Key, [StringComparison]::OrdinalIgnoreCase)
    })
    Require ($matches.Count -eq 1) "R18T required payload member changed: $($required.Key)"
    Require ($matches[0].sha256 -eq [string]$required.Value) "R18T frozen payload hash changed: $($required.Key)"
}

$requiredExternal = [ordered]@{
    'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip' = $referenceBundleSha
    'D:\AFCV1\rt\python.exe' = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'
    'D:\AFCV1\INSTALLATION.json' = $installationSha
}
$externalRows = @($manifest.externalDependencies)
$externalPathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
foreach ($external in $externalRows) {
    $declaredPath = [IO.Path]::GetFullPath(([string]$external.path).Replace('/', '\'))
    Require ($externalPathSet.Add($declaredPath)) "R18T duplicate external dependency: $declaredPath"
    $matches = @($requiredExternal.GetEnumerator() | Where-Object {
        [IO.Path]::GetFullPath([string]$_.Key).Equals($declaredPath, [StringComparison]::OrdinalIgnoreCase)
    })
    Require ($matches.Count -eq 1) "R18T unexpected external dependency: $declaredPath"
    Require ([string]$external.sha256 -eq [string]$matches[0].Value) "R18T external dependency hash changed: $declaredPath"
}
foreach ($required in $requiredExternal.GetEnumerator()) {
    $requiredPath = [IO.Path]::GetFullPath([string]$required.Key)
    Require ($externalPathSet.Contains($requiredPath)) "R18T required external dependency absent: $requiredPath"
}

Require ((Get-Sha256 $moduleSource) -eq $bindingModuleSha) 'R18T live-binding module changed.'
Import-Module -Name $moduleSource -Force -ErrorAction Stop
$configuration = Get-Content -LiteralPath $configurationSource -Raw | ConvertFrom-Json
$cohort = Get-Content -LiteralPath $cohortSource -Raw | ConvertFrom-Json
Require ([string]$configuration.schema -eq 'argos_opencv_scribe_r18j_corpus_configuration_v1') 'R18T configuration schema changed.'
Assert-ReviewOnlyAuthority $configuration.authority 'R18T configuration'
Require ((Get-Sha256 $cohortSource) -eq $cohortSha) 'R18T cohort changed.'
Require ([string]$cohort.state -eq 'FROZEN_CONFIGURATION_SELECTED_COHORT') 'R18T cohort state changed.'
Assert-ReviewOnlyAuthority $cohort.authority 'R18T cohort'
$cohortCases = @($cohort.reviewCases)
Require ($cohortCases.Count -gt 0) 'R18T cohort has no review cases.'
Require ([int]$cohort.caseCount -eq $cohortCases.Count) 'R18T cohort declared count changed.'
Assert-NoRuntimeEnvironmentOverrides

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($ReferenceBundlePath)
$archiveEntryCount = 0
$archivePathSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
$baseManifestEntries = New-Object Collections.Generic.List[object]
try {
    foreach ($entry in $archive.Entries) {
        $entryName = ([string]$entry.FullName).Replace('/', '\').TrimEnd('\')
        $relative = Get-SafeRelativePath $entryName 'R18T reference archive path'
        Require ($archivePathSet.Add($relative)) "R18T duplicate reference archive path: $relative"
        $destination = Join-Path $partialRoot $relative
        Assert-ContainedPath $partialRoot $destination 'R18T reference archive destination'
        Assert-PathBudget $destination
        $archiveEntryCount++
        if ($relative.Equals('refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json', [StringComparison]::OrdinalIgnoreCase)) {
            $baseManifestEntries.Add($entry)
        }
    }
    Require ($archiveEntryCount -gt 0) 'R18T reference archive is empty.'
    Require ($baseManifestEntries.Count -eq 1) 'R18T base reference manifest member changed.'
    $baseManifestStream = $baseManifestEntries[0].Open()
    try {
        Require ((Get-StreamSha256 $baseManifestStream) -eq $baseManifestSha) 'R18T base reference manifest changed.'
    }
    finally { $baseManifestStream.Dispose() }
}
finally { $archive.Dispose() }

foreach ($path in @(
    $WorkRoot,
    $partialRoot,
    $failedRoot,
    $OutputRoot,
    $runtimeConfiguration,
    $cohortPath,
    $workerPath,
    $delegatePath,
    $launchPath,
    $failurePath,
    $installedLauncher,
    (Join-Path $OutputRoot 'c\0123456789ABCDEF\RESULT.json'),
    (Join-Path $OutputRoot 'WORKER.stdout.log'),
    (Join-Path $OutputRoot 'WORKER.stderr.log'),
    (Join-Path $OutputRoot 'COMPLETE.json')
)) {
    Assert-PathBudget $path
}
foreach ($path in @($WorkRoot, $partialRoot, $failedRoot, $OutputRoot)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18T fresh target exists: $path"
}
$pythonCommand = Get-Command -Name $PythonPath -CommandType Application -ErrorAction Stop
Require (
    [IO.Path]::GetFullPath($pythonCommand.Source).Equals(
        [IO.Path]::GetFullPath($PythonPath), [StringComparison]::OrdinalIgnoreCase
    )
) 'R18T Python resolution changed.'
$outputDriveName = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($OutputRoot)).Substring(0, 1)
$outputDrive = Get-PSDrive -Name $outputDriveName -ErrorAction Stop
Require ([int64]$outputDrive.Free -ge 10737418240) 'R18T output drive has less than the required free space.'

$bindingFirst = $null
$bindingSecond = $null
if (-not $PackageValidationOnly) {
    # Both complete bindings occur at the final read-only boundary. Nothing
    # above creates a target or starts a process; the first target write is below.
    $bindingFirst = Get-R18TLiveBinding -CohortPath $cohortSource -ProposalRoot $ProposalRoot
    $bindingSecond = Get-R18TLiveBinding -CohortPath $cohortSource -ProposalRoot $ProposalRoot
    Require (
        [string]$bindingFirst.state -eq 'PASS_R18T_LIVE_INPUT_BINDING' -and
        [string]$bindingSecond.state -eq 'PASS_R18T_LIVE_INPUT_BINDING'
    ) 'R18T live binding did not pass twice.'
    Require (
        [string]$bindingFirst.bindingSha256 -eq [string]$bindingSecond.bindingSha256 -and
        [string]$bindingFirst.cohortSha256 -eq [string]$bindingSecond.cohortSha256 -and
        [int]$bindingFirst.caseCount -eq [int]$bindingSecond.caseCount -and
        [int]$bindingFirst.uniqueCasefoldIdentityCount -eq [int]$bindingSecond.uniqueCasefoldIdentityCount -and
        [int]$bindingFirst.uniqueBfDfPairCount -eq [int]$bindingSecond.uniqueBfDfPairCount
    ) 'R18T live bindings changed between reconciliations.'
    Require ([string]$bindingFirst.cohortSha256 -eq $cohortSha) 'R18T live binding cohort changed.'
}

if ($PackageValidationOnly) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18t_static_package_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18T_STATIC_PACKAGE_PREFLIGHT'
        revision = $revision
        rehearsal = $true
        packageValidationOnly = $true
        installedLauncher = $installedLauncher
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        referenceBundleSha256 = $referenceBundleSha
        referenceArchiveEntryCount = $archiveEntryCount
        baseReferenceManifestSha256 = $baseManifestSha
        supplementalReferenceManifestSha256 = $supplementalManifestSha
        pythonSha256 = $ExpectedPythonSha256
        cohortSha256 = $cohortSha
        cohortCaseCount = $cohortCases.Count
        proposalRoot = $ProposalRoot
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        freeBytes = [int64]$outputDrive.Free
        liveBindingDeferredToEndpoint = $true
        sourceImageBytesHashed = $false
        pixelsDecoded = $false
        targetWritesPerformed = $false
        processInspectionPerformed = $false
        processStarted = $false
        taskActionsPerformed = $false
        automaticRetryAllowed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        identityAccepted = $false
        readerModified = $false
        cropModified = $false
        referenceLibraryModified = $false
        sourceMutationPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 10
    return
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r18t_launch_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18T_LIVE_ONLY_LAUNCH_PREFLIGHT'
        revision = $revision
        rehearsal = [bool]$Rehearsal
        installedLauncher = $installedLauncher
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        referenceBundleSha256 = $referenceBundleSha
        referenceArchiveEntryCount = $archiveEntryCount
        baseReferenceManifestSha256 = $baseManifestSha
        supplementalReferenceManifestSha256 = $supplementalManifestSha
        pythonSha256 = $ExpectedPythonSha256
        cohortSha256 = $cohortSha
        cohortCaseCount = [int]$bindingFirst.caseCount
        uniqueCasefoldIdentityCount = [int]$bindingFirst.uniqueCasefoldIdentityCount
        uniqueBfDfPairCount = [int]$bindingFirst.uniqueBfDfPairCount
        liveBindingSha256 = [string]$bindingFirst.bindingSha256
        liveBindingPassCount = @($bindingFirst, $bindingSecond).Count
        proposalRoot = $ProposalRoot
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        freeBytes = [int64]$outputDrive.Free
        sourceImageBytesHashed = $true
        pixelsDecoded = $false
        targetWritesPerformed = $false
        processInspectionPerformed = $false
        processStarted = $false
        taskActionsPerformed = $false
        automaticRetryAllowed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        identityAccepted = $false
        readerModified = $false
        cropModified = $false
        referenceLibraryModified = $false
        sourceMutationPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 10
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
        Require ((Get-Sha256 $row.destination) -eq $row.sha256) "R18T staged payload changed: $($row.relativePath)"
    }

    $configuration.revision = $revision
    $configuration.sourceRoot = $ProposalRoot
    $configuration.proposalRoot = $ProposalRoot
    $configuration.providerPath = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18R\ArgosOpenCvScribeV1R18R.py'
    $configuration.providerSha256 = $providerSha
    $configuration.cropSweepPath = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18J\ArgosOpenCvScribeCropSweepR18J.py'
    $configuration.references.manifestPath = Join-Path $WorkRoot 'refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $configuration.references.supplementalManifestPath = Join-Path $WorkRoot 'OPENCV_SCRIBE_R18F\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json'
    $configuration.references.roots[0].path = Join-Path $WorkRoot 'refs\glyphs'
    $configuration.references.roots[1].path = Join-Path $WorkRoot 'refs\glyphs_v5_confirmed_20260806'
    $configuration | Add-Member -NotePropertyName reviewCases -NotePropertyValue @($cohort.reviewCases) -Force
    Assert-ReviewOnlyAuthority $configuration.authority 'R18T runtime configuration'
    $runtimeConfigurationPartial = Join-Path $partialRoot 'RUNTIME_CONFIGURATION.json'
    Write-JsonNew $runtimeConfigurationPartial $configuration
    Require (
        [string]$configuration.revision -eq $revision -and
        [string]$configuration.providerSha256 -eq $providerSha -and
        [string]$configuration.cropSweepSha256 -eq $cropSha -and
        [string]$configuration.references.manifestSha256 -eq $baseManifestSha -and
        [string]$configuration.references.supplementalManifestSha256 -eq $supplementalManifestSha -and
        @($configuration.reviewCases).Count -eq [int]$bindingFirst.caseCount
    ) 'R18T runtime configuration pins changed.'

    Move-Item -LiteralPath $partialRoot -Destination $WorkRoot -ErrorAction Stop
    foreach ($row in $payloadRows) {
        $staged = Join-Path $WorkRoot $row.relativePath
        Require ((Get-Sha256 $staged) -eq $row.sha256) "R18T committed payload changed: $($row.relativePath)"
    }
    Require ((Get-Sha256 $workerPath) -eq $workerSha) 'R18T execution-envelope worker changed.'
    Require ((Get-Sha256 $delegatePath) -eq $delegateSha) 'R18T frozen delegate changed.'
    [void](New-Item -ItemType Directory -Path $OutputRoot)

    $arguments = @(
        (Quote-ProcessArgument $workerPath),
        '--delegate', (Quote-ProcessArgument $delegatePath),
        '--delegate-sha256', (Quote-ProcessArgument $delegateSha),
        '--configuration', (Quote-ProcessArgument $runtimeConfiguration),
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
    Require ($ownedProcess.Start()) 'R18T execution-envelope worker did not start.'
    $ownedProcessStarted = $true
    Start-Sleep -Seconds 2
    $ownedProcess.Refresh()
    Require (-not $ownedProcess.HasExited) 'R18T execution-envelope worker exited before launch confirmation.'

    $launch = [ordered]@{
        schema = 'argos_opencv_scribe_r18t_live_only_launch_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18T_LIVE_ONLY_WORKER_STARTED'
        revision = $revision
        computerName = $env:COMPUTERNAME
        processId = [int]$ownedProcess.Id
        processStartTimeUtc = $ownedProcess.StartTime.ToUniversalTime().ToString('o')
        processCommandLine = $startInfo.FileName + ' ' + $startInfo.Arguments
        installedLauncher = $installedLauncher
        workRoot = $WorkRoot
        outputRoot = $OutputRoot
        proposalRoot = $ProposalRoot
        payloadManifestSha256 = $payloadManifestSha
        payloadFileCount = $files.Count
        referenceArchiveEntryCount = $archiveEntryCount
        pythonSha256 = $ExpectedPythonSha256
        referenceBundleSha256 = $referenceBundleSha
        baseReferenceManifestSha256 = $baseManifestSha
        supplementalReferenceManifestSha256 = $supplementalManifestSha
        readerSha256 = $readerSha
        cropSha256 = $cropSha
        providerSha256 = $providerSha
        delegateSha256 = $delegateSha
        workerSha256 = $workerSha
        cohortSha256 = $cohortSha
        cohortCaseCount = [int]$bindingFirst.caseCount
        liveBindingSha256 = [string]$bindingFirst.bindingSha256
        liveBindingPassCount = @($bindingFirst, $bindingSecond).Count
        sourceImageBytesHashed = $true
        pixelsDecodedByLauncher = $false
        processInspectionPerformed = $false
        taskActionCount = 0
        existingProcessActionCount = 0
        ownedProcessStarted = $true
        automaticRetryAllowed = $false
        publicationAuthorized = $false
        publicationPerformed = $false
        identityAccepted = $false
        readerModified = $false
        cropModified = $false
        referenceLibraryModified = $false
        sourceMutationPerformed = $false
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
                schema = 'argos_opencv_scribe_r18t_launch_failure_v1'
                createdUtc = [DateTime]::UtcNow.ToString('o')
                state = 'HOLD_R18T_LAUNCH_FAILURE'
                detail = $detail
                ownedProcessStarted = $ownedProcessStarted
                ownedChildTerminated = $ownedChildTerminated
                automaticRetryAllowed = $false
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
