#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'FMOCV03_O3K1_20260827T200000Z'
$liveInvocationSha256 = '6CA796CFF22092DE1899BA2FCB6C67D21457D0118F854115B8B337F2C8D83E3E'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($parts.Count) { [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) } else { 0 }
    Assert-True (($full.Length + $Reserve) -lt 200) "O3K1 unsafe effective path: $full"
    Assert-True ($longest -le 80) "O3K1 unsafe path component: $full"
}
function Write-NewJson([string]$Path, [object]$Value, [int]$Depth = 20) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3K1 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Get-ProcessorRows([string]$Token) {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like ('*' + $Token + '*') } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{ processId=[uint32]$_.ProcessId; creationDate=[string]$_.CreationDate; commandLine=[string]$_.CommandLine } })
}
function Invoke-BoundedPython([string]$Python, [string]$Provider, [string]$Job, [string]$OutputRoot, [bool]$PreflightOnly) {
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $suffix = if ($PreflightOnly) { ' --preflight' } else { '' }
    $startInfo.Arguments = '"' + $Provider + '" --job "' + $Job + '" --output-root "' + $OutputRoot + '"' + $suffix
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-True ($process.Start()) 'O3K1 OpenCV provider did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(780000)) {
        try { $process.Kill() } catch {}
        [void]$process.WaitForExit(5000)
        throw 'O3K1 OpenCV provider exceeded the 780-second child timeout.'
    }
    $process.WaitForExit()
    $result = [pscustomobject]@{ exitCode=$process.ExitCode; stdout=[string]$stdoutTask.Result; stderr=[string]$stderrTask.Result }
    $process.Dispose()
    Assert-True ($result.stdout.Length -le 1048576 -and $result.stderr.Length -le 1048576) 'O3K1 child output exceeded its bounded capture.'
    return $result
}
function Get-ZipEntrySha256([IO.Compression.ZipArchiveEntry]$Entry) {
    $stream = $Entry.Open()
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

$manifestPath = if ([string]::IsNullOrWhiteSpace($InvocationManifest)) { Join-Path $PSScriptRoot 'O3K1_ENDPOINT_LIVE_INVOCATION.json' } else { [IO.Path]::GetFullPath($InvocationManifest) }
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O3K1 invocation manifest is absent.'
if (-not $Rehearsal) { Assert-True ((Get-Sha256 $manifestPath) -eq $liveInvocationSha256) 'O3K1 live invocation manifest changed.' }
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$expectedState = if ($Rehearsal) { 'FROZEN_REHEARSAL_CONTRACT' } else { 'FROZEN_LIVE_CONTRACT' }
Assert-True ([string]$invocation.schema -eq 'argos_o3k1_endpoint_invocation_v1' -and [string]$invocation.state -eq $expectedState) 'O3K1 invocation identity changed.'
Assert-True ([bool]$invocation.sourceImageReadAuthorized -and -not [bool]$invocation.detectorRerunAuthorized -and -not [bool]$invocation.thresholdOrAlgorithmChangeAuthorized) 'O3K1 source-read or no-retune authority changed.'
Assert-True (-not [bool]$invocation.requestRetryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O3K1 authority widened.'
Assert-True ($env:COMPUTERNAME.Equals([string]$invocation.expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O3K1 wrong computer: $($env:COMPUTERNAME)"

$payloadRoot = if ([string]::IsNullOrWhiteSpace([string]$invocation.payloadRoot)) { $PSScriptRoot } else { [IO.Path]::GetFullPath([string]$invocation.payloadRoot) }
$providerPath = [IO.Path]::GetFullPath([string]$invocation.providerPath)
$jobPath = if ([string]::IsNullOrWhiteSpace([string]$invocation.jobPath)) { Join-Path $payloadRoot 'O3K1_RENDER_JOB.json' } else { [IO.Path]::GetFullPath([string]$invocation.jobPath) }
$runtimePath = [IO.Path]::GetFullPath([string]$invocation.runtimePath)
$runtimeInstallationPath = [IO.Path]::GetFullPath([string]$invocation.runtimeInstallationPath)
$sourceRoot = [IO.Path]::GetFullPath([string]$invocation.sourceRoot)
$outputRoot = [IO.Path]::GetFullPath([string]$invocation.outputRoot)
$outputPartial = $outputRoot + '.partial'
$outputFailed = $outputRoot + '.failed'
$exportRoot = [IO.Path]::GetFullPath([string]$invocation.exportRoot)
$exportPartial = $exportRoot + '.partial'
$exportFailed = $exportRoot + '.failed'
$exportZipName = [string]$invocation.exportZipName
$exportZipPartial = Join-Path $exportPartial $exportZipName
$exportZipFinal = Join-Path $exportRoot $exportZipName
$exportManifestPartial = Join-Path $exportPartial 'EXPORT_MANIFEST.json'
$renderManifestFinal = Join-Path $outputRoot 'RENDER_MANIFEST.json'
$aliasDrive = [string]$invocation.sourceAliasDrive
$aliasPath = $aliasDrive + '\'
$subst = Join-Path $env:SystemRoot 'System32\subst.exe'

Assert-True ($aliasDrive -eq 'F:') 'O3K1 source alias changed.'
Assert-True ($exportZipName -eq 'O3K1_REVIEW.zip') 'O3K1 export ZIP name changed.'
foreach ($path in @($providerPath,$jobPath,$runtimePath,$runtimeInstallationPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3K1 dependency absent: $path"
    Assert-PathBudget $path 32
}
Assert-True ((Get-Sha256 $providerPath) -eq [string]$invocation.providerSha256) 'O3K1 provider changed.'
Assert-True ((Get-Sha256 $jobPath) -eq [string]$invocation.jobSha256) 'O3K1 job changed.'
Assert-True ((Get-Sha256 $runtimePath) -eq [string]$invocation.runtimeSha256) 'O3K1 runtime changed.'
Assert-True ((Get-Sha256 $runtimeInstallationPath) -eq [string]$invocation.runtimeInstallationSha256) 'O3K1 runtime installation evidence changed.'
$runtimeCommand = Get-Command -Name $runtimePath -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($runtimeCommand.Source).Equals($runtimePath, [StringComparison]::OrdinalIgnoreCase)) 'O3K1 runtime command resolution changed.'
foreach ($resultFile in @($invocation.resultFiles)) {
    $resultPath = Join-Path $payloadRoot ([string]$resultFile.path)
    Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) "O3K1 result dependency absent: $resultPath"
    Assert-True ((Get-Sha256 $resultPath) -eq [string]$resultFile.sha256) "O3K1 result dependency changed: $resultPath"
    Assert-PathBudget $resultPath 32
}
Assert-True (@($invocation.resultFiles).Count -eq 2) 'O3K1 result dependency cardinality changed.'
Assert-True (Test-Path -LiteralPath $sourceRoot -PathType Container) 'O3K1 source root is absent.'
foreach ($path in @($sourceRoot,$outputRoot,$outputPartial,$outputFailed,$exportRoot,$exportPartial,$exportFailed,$exportZipPartial,$exportZipFinal,$exportManifestPartial,$renderManifestFinal)) { Assert-PathBudget $path 32 }
foreach ($path in @($outputRoot,$outputPartial,$outputFailed,$exportRoot,$exportPartial,$exportFailed)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O3K1 create-new target exists: $path" }
if ([bool]$invocation.useSourceAlias) {
    Assert-True (Test-Path -LiteralPath $subst -PathType Leaf) 'O3K1 subst.exe is absent.'
    $substCommand = Get-Command -Name $subst -CommandType Application -ErrorAction Stop
    Assert-True ([IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($subst), [StringComparison]::OrdinalIgnoreCase)) 'O3K1 subst command resolution changed.'
    Assert-True (-not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name F -ErrorAction SilentlyContinue)) 'O3K1 F: is already in use.'
}

$processorBefore = @(Get-ProcessorRows -Token ([string]$invocation.processorCommandToken))
$providerPreflight = Invoke-BoundedPython -Python $runtimePath -Provider $providerPath -Job $jobPath -OutputRoot $outputRoot -PreflightOnly $true
Assert-True ($providerPreflight.exitCode -eq 0) ('O3K1 provider preflight failed: ' + $providerPreflight.stderr.Trim())
$providerPreflightResult = $providerPreflight.stdout.Trim() | ConvertFrom-Json
Assert-True ([string]$providerPreflightResult.state -eq 'PASS_O3K1_NOTCH_REVIEW_RENDERER_PREFLIGHT' -and -not [bool]$providerPreflightResult.sourceImageBytesRead -and -not [bool]$providerPreflightResult.outputCreated) 'O3K1 provider preflight contract changed.'
if ($Preflight) {
    [ordered]@{
        schema='argos_o3k1_endpoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_ENDPOINT_PREFLIGHT';revision=$revision;rehearsal=[bool]$Rehearsal
        invocationSha256=Get-Sha256 $manifestPath;providerSha256=[string]$invocation.providerSha256;jobSha256=[string]$invocation.jobSha256;resultFileCount=2
        processorProcessCount=$processorBefore.Count;sourceImageBytesRead=$false;sourceHashesComputed=$false;pixelsDecoded=$false;outputCreated=$false
        mutationsPerformed=$false;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false;taskOrProcessActionPerformed=$false;providerActivated=$false
        requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$aliasCreated = $false
$outputCommitted = $false
$exportCommitted = $false
$terminal = $null
try {
    if ([bool]$invocation.useSourceAlias) {
        $aliasText = & $subst $aliasDrive $sourceRoot 2>&1 | Out-String
        Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $aliasPath -PathType Container)) ('O3K1 alias creation failed: ' + $aliasText.Trim())
        $aliasCreated = $true
        $mappingRows = @((& $subst 2>&1 | Out-String) -split '\r?\n' | Where-Object { $_ -match '(?i)^\s*F:\\:\s*=>\s*(.+?)\s*$' })
        Assert-True ($mappingRows.Count -eq 1) 'O3K1 F: mapping cardinality changed.'
        $match = [regex]::Match($mappingRows[0], '(?i)^\s*F:\\:\s*=>\s*(.+?)\s*$')
        Assert-True ($match.Groups[1].Value.Trim().TrimEnd('\').Equals($sourceRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O3K1 F: target changed.'
    }
    $run = Invoke-BoundedPython -Python $runtimePath -Provider $providerPath -Job $jobPath -OutputRoot $outputPartial -PreflightOnly $false
    Assert-True ($run.exitCode -eq 0) ('O3K1 OpenCV render failed: ' + $run.stderr.Trim())
    $runResult = $run.stdout.Trim() | ConvertFrom-Json
    Assert-True ([string]$runResult.state -eq 'PASS_O3K1_NOTCH_REVIEW_RENDERED') 'O3K1 provider terminal state changed.'
    $renderManifestPartial = Join-Path $outputPartial 'RENDER_MANIFEST.json'
    Assert-True (Test-Path -LiteralPath $renderManifestPartial -PathType Leaf) 'O3K1 render manifest is absent.'
    $render = Get-Content -LiteralPath $renderManifestPartial -Raw | ConvertFrom-Json
    Assert-True ([string]$render.schema -eq 'argos_ocv03_notch_review_render_v1' -and [string]$render.state -eq 'PASS_O3K1_NOTCH_REVIEW_RENDERED') 'O3K1 render manifest identity changed.'
    Assert-True ([int]$render.sourceImageReadCount -eq 4 -and [bool]$render.allSourceHashesMatched -and @($render.assetGroups).Count -eq 6 -and [int]$render.assetFileCount -eq 18) 'O3K1 render cardinality or source proof changed.'
    Assert-True (-not [bool]$render.detectorRerunPerformed -and -not [bool]$render.thresholdOrAlgorithmChanged -and -not [bool]$render.taskOrProcessActionPerformed -and -not [bool]$render.providerActivated) 'O3K1 render authority widened.'
    Assert-True (@($render.assetGroups | Where-Object { [int]$_.changedPixelsOutsideCurrentMask -ne 0 -or [int]$_.changedPixelsInsideCurrentMask -le 0 }).Count -eq 0) 'O3K1 overlay mask invariant changed.'
    Move-Item -LiteralPath $outputPartial -Destination $outputRoot -ErrorAction Stop
    $outputCommitted = $true

    [void][IO.Directory]::CreateDirectory($exportPartial)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($outputRoot,$exportZipPartial,[IO.Compression.CompressionLevel]::Optimal,$false)
    $zipItem = Get-Item -LiteralPath $exportZipPartial
    Assert-True ($zipItem.Length -gt 0 -and $zipItem.Length -le [int64]$invocation.maximumExportZipBytes) 'O3K1 export ZIP byte contract changed.'
    $expected = @{}
    foreach ($group in @($render.assetGroups)) {
        foreach ($field in @('clean','currentMask','currentOverlay')) { $expected[[string]$group.$field.path] = [string]$group.$field.sha256 }
    }
    $expected['RENDER_MANIFEST.json'] = Get-Sha256 $renderManifestFinal
    $archive = [IO.Compression.ZipFile]::OpenRead($exportZipPartial)
    try {
        $entries = @($archive.Entries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) })
        Assert-True ($entries.Count -eq 19 -and $expected.Count -eq 19) 'O3K1 export ZIP entry cardinality changed.'
        foreach ($entry in $entries) {
            $name = $entry.FullName.Replace('\','/')
            Assert-True ($expected.ContainsKey($name)) "O3K1 unexpected export ZIP entry: $name"
            Assert-True ((Get-ZipEntrySha256 $entry) -eq [string]$expected[$name]) "O3K1 export ZIP entry hash changed: $name"
        }
    } finally { $archive.Dispose() }
    $zipSha = Get-Sha256 $exportZipPartial
    $exportManifest = [ordered]@{
        schema='argos_o3k1_review_export_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_REVIEW_EXPORT';revision=$revision
        renderManifestSha256=$expected['RENDER_MANIFEST.json'];zipName=$exportZipName;zipBytes=[int64]$zipItem.Length;zipSha256=$zipSha;zipEntryCount=19
        sourceImageReadCount=4;sourceHashesMatched=$true;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false;sourceMutationPerformed=$false
        taskOrProcessActionPerformed=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-NewJson -Path $exportManifestPartial -Value $exportManifest 10
    Move-Item -LiteralPath $exportPartial -Destination $exportRoot -ErrorAction Stop
    $exportCommitted = $true
    $terminal = [ordered]@{
        schema='argos_o3k1_endpoint_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_NOTCH_REVIEW_RENDERED_FOR_DATA_PULL';revision=$revision;rehearsal=[bool]$Rehearsal
        renderManifestPath=$renderManifestFinal;renderManifestSha256=$expected['RENDER_MANIFEST.json'];exportRelativePath='OCV03ReviewExports/O3K1_20260827T200000Z/O3K1_REVIEW.zip'
        exportZipPath=$exportZipFinal;exportZipBytes=[int64]$zipItem.Length;exportZipSha256=$zipSha;assetFileCount=18;candidateCount=3;channelRenderCount=6
        sourceImageReadCount=4;sourceHashesMatched=$true;detectorRerunPerformed=$false;thresholdOrAlgorithmChanged=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false
        taskOrProcessActionPerformed=$false;providerActivated=$false;requestRetryAuthorized=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
} catch {
    if ($exportCommitted -and (Test-Path -LiteralPath $exportRoot) -and -not (Test-Path -LiteralPath $exportFailed)) { Move-Item -LiteralPath $exportRoot -Destination $exportFailed -ErrorAction SilentlyContinue }
    elseif (Test-Path -LiteralPath $exportPartial) { Move-Item -LiteralPath $exportPartial -Destination $exportFailed -ErrorAction SilentlyContinue }
    if ($outputCommitted -and (Test-Path -LiteralPath $outputRoot) -and -not (Test-Path -LiteralPath $outputFailed)) { Move-Item -LiteralPath $outputRoot -Destination $outputFailed -ErrorAction SilentlyContinue }
    elseif (Test-Path -LiteralPath $outputPartial) { Move-Item -LiteralPath $outputPartial -Destination $outputFailed -ErrorAction SilentlyContinue }
    throw
} finally {
    if ($aliasCreated) {
        $removeText = & $subst $aliasDrive /D 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath $aliasPath) -or $null -ne (Get-PSDrive -Name F -ErrorAction SilentlyContinue)) { throw ('O3K1 owned source alias removal failed: ' + $removeText.Trim()) }
    }
}
$processorAfter = @(Get-ProcessorRows -Token ([string]$invocation.processorCommandToken))
Assert-True (($processorBefore | ConvertTo-Json -Depth 6 -Compress) -eq ($processorAfter | ConvertTo-Json -Depth 6 -Compress)) 'O3K1 processor identity changed.'
$terminal.processorProcessCount = $processorAfter.Count
$terminal.processorIdentityUnchanged = $true
$terminal.sourceAliasRemoved = (-not (Test-Path -LiteralPath $aliasPath))
$terminal | ConvertTo-Json -Depth 10
