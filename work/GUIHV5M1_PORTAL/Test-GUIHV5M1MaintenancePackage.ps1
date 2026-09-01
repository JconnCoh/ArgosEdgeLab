[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath = '',
    [string]$PackageSource = '',
    [string]$PackageRoot = 'C:\G5MP3\REQ_GUIHV5M1_TEST3.ready',
    [string]$SuccessRoot = 'C:\G5MS3',
    [string]$FailureRoot = 'C:\G5MF3',
    [string]$RefusalRoot = 'C:\G5MR3',
    [string]$SuccessFixture = '',
    [string]$FailureFixture = '',
    [string]$RefusalFixture = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = if ([string]::IsNullOrWhiteSpace($PackageSource)) { Join-Path $PSScriptRoot 'source' } else { [IO.Path]::GetFullPath($PackageSource) }
$payloadSource = Join-Path $sourceRoot 'payload'
$definitionSource = Join-Path $sourceRoot 'MAINTENANCE_DEFINITION.json'
$signedManifestSource = Join-Path $sourceRoot 'PORTAL_REQUEST_MANIFEST.json'
$signedSignatureSource = Join-Path $sourceRoot 'PORTAL_REQUEST_MANIFEST.sig'
$signedPullZip = 'C:\G4I\DATA_PULL_PAYLOAD.zip'
$signedPullZipSha256 = 'CBBBD2F5B83CF646271878BE99A825D7EFD20BC583F8C8DAB82D2326CAE7C91C'
$currentObservationZip = 'C:\G5Q\R_D916784B1D97_20260901001518698_12b4bc19.ready\DATA_PULL_PAYLOAD.zip'
$currentObservationZipSha256 = 'ACBE3FAC7EF2070A14B4CE46EE19558C37D9A84C38F18090759E581F9DD02ACF'
$resolvedPackageRoot = [IO.Path]::GetFullPath($PackageRoot)
$roots = [ordered]@{ success = [IO.Path]::GetFullPath($SuccessRoot); failure = [IO.Path]::GetFullPath($FailureRoot); refusal = [IO.Path]::GetFullPath($RefusalRoot) }
$fixturePaths = [ordered]@{
    success = if ([string]::IsNullOrWhiteSpace($SuccessFixture)) { Join-Path $PSScriptRoot 'fixture_success.json' } else { [IO.Path]::GetFullPath($SuccessFixture) }
    failure = if ([string]::IsNullOrWhiteSpace($FailureFixture)) { Join-Path $PSScriptRoot 'fixture_failure.json' } else { [IO.Path]::GetFullPath($FailureFixture) }
    refusal = if ([string]::IsNullOrWhiteSpace($RefusalFixture)) { Join-Path $PSScriptRoot 'fixture_refusal.json' } else { [IO.Path]::GetFullPath($RefusalFixture) }
}
$targetHashes = [ordered]@{
    viewer = '018A74CB5EFA08D59810B09BD16EEF5E3F0345A4C4335CB59ABE334ABE888AA7'
    program = '776BDD0F5D8F644851A8495187178417B021CF5350A988FD0DBFE94D0CFDEF0A'
    updater = 'C6A862FE32BB1013626A2C70D97173732F24724D644F44D084EC67DBB3351299'
}
$priorHashes = [ordered]@{
    viewer = 'D893CA3C8F7C4F2993BA4D412986EC30D8B113408039EF8E381F4025C1A04D82'
    program = 'DFEC0EA9E7A3C309CD7BD845099B23AB725A760035EBAC787340570C34181C76'
    updater = '73C2289B58F6F6B23DD2FA12E847AFF171B3FAC45153202E93EE00E0B7533FBA'
    dashboard = 'E55F21FF680DD70AD2D71084B199F21862D91E9C4FC83D4943D0FF510846F16B'
    status = '787BD3107214E3C50FF8589310D7C77AFE0A9D1584E733372F928A4AB671A189'
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Assert-FileHash([string]$Path, [string]$Expected) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or (Get-Sha256 $Path) -ne $Expected) {
        throw "Fixture file hash mismatch: $Path"
    }
}

function Invoke-Child([string[]]$Arguments) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $start.Arguments = ($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join ' '
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) { throw 'Windows PowerShell 5.1 child did not start.' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(180000)) { try { $process.Kill() } catch {}; throw 'Windows PowerShell 5.1 child timed out.' }
        return [pscustomobject]@{
            exitCode = [int]$process.ExitCode
            stdout = [string]$stdoutTask.Result
            stderr = [string]$stderrTask.Result
        }
    }
    finally { $process.Dispose() }
}

function New-FixtureTree([string]$Root, [bool]$InstallTargets, [bool]$UnapprovedViewer) {
    [void](New-Item -ItemType Directory -Path $Root)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($signedPullZip)
    try {
        $prefix = 'data/JBOD_PROCESSOR_REVIEW/'
        foreach ($entry in @($archive.Entries | Where-Object { $_.FullName.StartsWith($prefix, [StringComparison]::Ordinal) -and -not [string]::IsNullOrWhiteSpace($_.Name) })) {
            $relative = $entry.FullName.Substring($prefix.Length).Replace('/', '\')
            $destination = Join-Path $Root $relative
            $parent = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $false)
        }
    }
    finally { $archive.Dispose() }

    $observationArchive = [IO.Compression.ZipFile]::OpenRead($currentObservationZip)
    try {
        $prefix = 'data/JBOD_PROCESSOR_REVIEW/'
        foreach ($entry in @($observationArchive.Entries | Where-Object { $_.FullName.StartsWith($prefix, [StringComparison]::Ordinal) -and -not [string]::IsNullOrWhiteSpace($_.Name) })) {
            $relative = $entry.FullName.Substring($prefix.Length).Replace('/', '\')
            $destination = Join-Path $Root $relative
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $destination, $true)
        }
    }
    finally { $observationArchive.Dispose() }

    $configPath = Join-Path $Root 'PROCESSOR_CONFIG.json'
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    $config.appRoot = $Root
    $config.stateRoot = $Root
    $config.rawSearchRoot = Join-Path $Root 'raw'
    $config.relayQueueRoot = Join-Path $Root 'q'
    $config.outputRoot = Join-Path $Root 'o'
    $config.dashboardOutputRoot = Join-Path $Root 'd'
    $config.cacheRoot = Join-Path $Root 'c'
    $config.metadataSnapshotRoot = Join-Path $Root 'm'
    $config.referenceRoot = Join-Path $Root 'refs'
    $config.bowCompReferenceCacheRoot = Join-Path $Root 'bc'
    [IO.File]::WriteAllText($configPath, (($config | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    foreach ($directory in @($config.rawSearchRoot, $config.relayQueueRoot, $config.outputRoot, $config.dashboardOutputRoot, $config.cacheRoot, $config.metadataSnapshotRoot, $config.referenceRoot, $config.bowCompReferenceCacheRoot)) {
        [void](New-Item -ItemType Directory -Path ([string]$directory) -Force)
    }

    $ledgerPath = Join-Path $Root 'processor\PROCESSING_LEDGER.json'
    $ledger = Get-Content -LiteralPath $ledgerPath -Raw | ConvertFrom-Json
    $resultIndex = 0
    foreach ($row in @($ledger.rows | Where-Object { [string]$_.state -eq 'COMPLETED' })) {
        $resultIndex++
        $resultRoot = Join-Path $Root ('r\' + $resultIndex.ToString('D4'))
        [void](New-Item -ItemType Directory -Path $resultRoot -Force)
        $review = [ordered]@{}
        foreach ($name in @('backsideBfRaw', 'backsideDfRaw', 'backsideCompositeAcceptedBf', 'backsideCompositeAcceptedDf', 'backsideCompositeAcceptedDfDisplay', 'frontsideBfRaw', 'frontsideDfRaw', 'frontsideCompositeAcceptedBf', 'frontsideCompositeAcceptedDf', 'frontsideCompositeAcceptedDfDisplay')) {
            $assetPath = Join-Path $resultRoot ($name + '.png')
            [IO.File]::WriteAllBytes($assetPath, [byte[]]@())
            $review[$name] = $assetPath
        }
        $resultPath = Join-Path $resultRoot 'RESULT.json'
        $result = [ordered]@{
            state = 'PASS_GUIHV5M1_FIXTURE_REVIEW_ONLY'
            reviewOnly = $true
            xmlWritten = $false
            scratchRulesChanged = $false
            geometryDisposition = 'FIXTURE_UNCHANGED'
            geometry = [ordered]@{ state = 'FIXTURE_UNCHANGED' }
            review = $review
        }
        [IO.File]::WriteAllText($resultPath, (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
        $row.resultPath = $resultPath
    }
    [IO.File]::WriteAllText($ledgerPath, (($ledger | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))

    Copy-Item -LiteralPath (Join-Path $payloadSource 'p\i') -Destination (Join-Path $Root 'Import-JbodScribeVerificationResponse.ps1')
    $viewerSource = if ($InstallTargets) { Join-Path $payloadSource 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe' } else { Join-Path $payloadSource 'p\1' }
    $programSource = if ($InstallTargets) { Join-Path $payloadSource 'Program.cs' } else { Join-Path $payloadSource 'p\3' }
    $updaterSource = if ($InstallTargets) { Join-Path $payloadSource 'Update-JbodDashboardManifest.ps1' } else { Join-Path $payloadSource 'p\4' }
    if ($UnapprovedViewer) { $viewerSource = Join-Path $payloadSource 'Program.cs' }
    Copy-Item -LiteralPath $viewerSource -Destination (Join-Path $Root 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe') -Force
    [void](New-Item -ItemType Directory -Path (Join-Path $Root 'runtime\viewer') -Force)
    Copy-Item -LiteralPath $viewerSource -Destination (Join-Path $Root 'runtime\viewer\ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe') -Force
    Copy-Item -LiteralPath $programSource -Destination (Join-Path $Root 'runtime\viewer\Program.cs') -Force
    Copy-Item -LiteralPath $updaterSource -Destination (Join-Path $Root 'Update-JbodDashboardManifest.ps1') -Force
}

foreach ($required in @($signedPullZip, $currentObservationZip, (Join-Path $payloadSource 'Apply-GUIHV5M1DirectGuiPatch.ps1'), (Join-Path $payloadSource 'p\d'), (Join-Path $payloadSource 'p\s'), (Join-Path $payloadSource 'p\i'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Required GUIHV5M1 rehearsal input is missing: $required" }
}
if (-not (Test-Path -LiteralPath $definitionSource -PathType Leaf)) {
    foreach ($signedLeaf in @($signedManifestSource, $signedSignatureSource)) {
        if (-not (Test-Path -LiteralPath $signedLeaf -PathType Leaf)) { throw "Signed GUIHV5M1 package input is missing: $signedLeaf" }
    }
}
if ((Get-Sha256 $signedPullZip) -ne $signedPullZipSha256) { throw 'Signed complete fixture pull ZIP changed.' }
if ((Get-Sha256 $currentObservationZip) -ne $currentObservationZipSha256) { throw 'Signed GUIHV5O1 observation ZIP changed.' }
foreach ($path in @($resolvedPackageRoot, $roots.success, $roots.failure, $roots.refusal)) {
    if (Test-Path -LiteralPath $path) { throw "Fresh GUIHV5M1 rehearsal path already exists: $path" }
}

$preflightResult = [ordered]@{
    schema = 'argos_guihv5m1_maintenance_package_rehearsal_preflight_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIHV5M1_MAINTENANCE_PACKAGE_REHEARSAL_PREFLIGHT'
    signedPullZipSha256 = $signedPullZipSha256
    currentObservationZipSha256 = $currentObservationZipSha256
    packageRoot = $resolvedPackageRoot
    fixtureRoots = @($roots.Values)
    mutationsPerformed = $false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 6; return }
if ([string]::IsNullOrWhiteSpace($OutputPath) -or (Test-Path -LiteralPath $OutputPath)) { throw 'Fresh OutputPath is required for -Gate.' }

[void](New-Item -ItemType Directory -Path $resolvedPackageRoot -Force)
Copy-Item -LiteralPath $payloadSource -Destination $resolvedPackageRoot -Recurse
if (Test-Path -LiteralPath $definitionSource -PathType Leaf) {
    Copy-Item -LiteralPath $definitionSource -Destination $resolvedPackageRoot
}
else {
    Copy-Item -LiteralPath $signedManifestSource -Destination $resolvedPackageRoot
    Copy-Item -LiteralPath $signedSignatureSource -Destination $resolvedPackageRoot
}
New-FixtureTree -Root $roots.success -InstallTargets $true -UnapprovedViewer $false
New-FixtureTree -Root $roots.failure -InstallTargets $true -UnapprovedViewer $false
New-FixtureTree -Root $roots.refusal -InstallTargets $false -UnapprovedViewer $true

$entryPoint = Join-Path $resolvedPackageRoot 'payload\Apply-GUIHV5M1DirectGuiPatch.ps1'
$entryPreflightResult = Invoke-Child @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPoint, '-Preflight', '-InvocationManifest', $fixturePaths.success)
if ($entryPreflightResult.exitCode -ne 0 -or $entryPreflightResult.stdout -notmatch 'PASS_GUIHV5M1_SCRIBE_HOLD_PROJECTION_MAINTENANCE_PATCH_PREFLIGHT') { throw "GUIHV5M1 exact preflight failed: $($entryPreflightResult.stderr)" }
$success = Invoke-Child @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPoint, '-Rehearsal', '-InvocationManifest', $fixturePaths.success)
if ($success.exitCode -ne 0 -or $success.stdout -notmatch 'PASS_GUIHV5M1_SCRIBE_HOLD_PROJECTION_PRODUCED_VALIDATED_AND_TRAY_ACTIVATED') { throw "GUIHV5M1 success rehearsal failed: $($success.stderr)" }
Assert-FileHash (Join-Path $roots.success 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe') $targetHashes.viewer
Assert-FileHash (Join-Path $roots.success 'runtime\viewer\Program.cs') $targetHashes.program
Assert-FileHash (Join-Path $roots.success 'Update-JbodDashboardManifest.ps1') $targetHashes.updater

$failure = Invoke-Child @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPoint, '-Rehearsal', '-InvocationManifest', $fixturePaths.failure)
if ($failure.exitCode -eq 0 -or ($failure.stdout + $failure.stderr) -notmatch 'INJECTED_GUIHV5M1_POST_PRODUCER_VALIDATION_FAILURE') { throw 'GUIHV5M1 injected failure control did not fail exactly.' }
Assert-FileHash (Join-Path $roots.failure 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe') $priorHashes.viewer
Assert-FileHash (Join-Path $roots.failure 'runtime\viewer\Program.cs') $priorHashes.program
Assert-FileHash (Join-Path $roots.failure 'Update-JbodDashboardManifest.ps1') $priorHashes.updater
Assert-FileHash (Join-Path $roots.failure 'dashboard_manifest.json') $priorHashes.dashboard
Assert-FileHash (Join-Path $roots.failure 'dashboard\DASHBOARD_CATALOG_STATUS.json') $priorHashes.status

$refusalDashboardBefore = Get-Sha256 (Join-Path $roots.refusal 'dashboard_manifest.json')
$refusal = Invoke-Child @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPoint, '-Preflight', '-InvocationManifest', $fixturePaths.refusal)
if ($refusal.exitCode -eq 0 -or ($refusal.stdout + $refusal.stderr) -notmatch 'destination predecessor is unapproved') { throw 'GUIHV5M1 unapproved predecessor was not refused.' }
if ((Get-Sha256 (Join-Path $roots.refusal 'dashboard_manifest.json')) -ne $refusalDashboardBefore) { throw 'GUIHV5M1 refusal mutated the dashboard.' }

$result = [ordered]@{
    schema = 'argos_guihv5m1_maintenance_package_rehearsal_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_GUIHV5M1_MAINTENANCE_PACKAGE_REHEARSAL'
    windowsPowerShell51Preflight = 'PASS_GUIHV5M1_SCRIBE_HOLD_PROJECTION_MAINTENANCE_PATCH_PREFLIGHT'
    successState = 'PASS_GUIHV5M1_SCRIBE_HOLD_PROJECTION_PRODUCED_VALIDATED_AND_TRAY_ACTIVATED'
    injectedFailure = 'INJECTED_GUIHV5M1_POST_PRODUCER_VALIDATION_FAILURE'
    installedSourceRollbackVerified = $true
    producerOutputRollbackVerified = $true
    unapprovedPredecessorRefusedBeforeMutation = $true
    exactRegression = [ordered]@{ acquisitionRows = 380; physicalRows = 190; stateSplit = @(126, 55, 3, 5, 1); readyRows = 3; missingJoins = 0; unrelatedRows = 1342 }
    taskActions = @('STOP_IF_RUNNING:ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2', 'START_ALWAYS:ArgosEdgeLab.AllWaferMonitor.ReviewOnly.V2')
    processorTaskAction = $false
    processorRestarted = $false
    sourceMutation = $false
    imageRead = $false
    retry = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
[IO.File]::WriteAllText([IO.Path]::GetFullPath($OutputPath), (($result | ConvertTo-Json -Depth 10) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result | ConvertTo-Json -Depth 10
