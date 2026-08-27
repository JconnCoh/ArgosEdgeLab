#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$PayloadRoot = '',
    [string]$RuntimeRoot = 'D:\AFCV1\rt',
    [string]$RuntimeInstallationPath = 'D:\AFCV1\INSTALLATION.json',
    [string]$WorkRoot = 'D:\A2\w\ocv\O3D3R4_20260827T165500000Z_62629419',
    [string]$OutputRoot = 'D:\A2\o\ocv\O3D3R4_20260827T165500000Z_62629419',
    [string]$SourceAliasRoot = 'D:\KLARFExport\PatternedFront\Lot_62629-419_NotchBad_Hotspot',
    [string]$RehearsalJobPath = '',
    [string]$LiveContractFixtureManifest = '',
    [string]$ExpectedComputerName = 'A1025645101'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'O3D3R4_20260827T165500000Z_62629419'
$effectivePayloadRoot = if ([string]::IsNullOrWhiteSpace($PayloadRoot)) { $PSScriptRoot } else { $PayloadRoot }
$coreSha = '304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC'
$r5Sha = '47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24'
$r6Sha = '90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'
$liveJobSha = 'F7DB6FE811D58DAA3F410C5AD8E4F063BBD6E961004BDAF1BF2470BB74392717'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$sourceFreezeGateSha = '665C1DDDFD1E1FBDECED11C5C9F382D147E3AB1F7904BF191A5F9026E43063AD'
$sourceFingerprintSha = 'EB45C81DB9A4A3B220B0D4161C2F280A7FB402A40296FB94110223692073BAA0'
$aliasName = 'F:'
$aliasPath = 'F:\'

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
    Assert-True (($full.Length + $Reserve) -lt 200) "O3D3R4 unsafe effective path: $full"
    Assert-True ($longest -le 80) "O3D3R4 unsafe component: $full"
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3D3R4 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Assert-LiveSelfPins([string]$JobPath, [string]$ExpectedJobSha, [string]$InstallationPath, [string]$ExpectedInstallationSha) {
    Assert-True (Test-Path -LiteralPath $JobPath -PathType Leaf) 'O3D3R4 live job absent.'
    Assert-True ((Get-Sha256 $JobPath) -eq $ExpectedJobSha) 'O3D3R4 live job changed.'
    Assert-True (Test-Path -LiteralPath $InstallationPath -PathType Leaf) 'O3D3R4 runtime installation evidence absent.'
    Assert-True ((Get-Sha256 $InstallationPath) -eq $ExpectedInstallationSha) 'O3D3R4 runtime installation evidence changed.'
}
function Get-ProcessorRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Invoke-AllWaferProcessorV2.ps1*' } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{ processId=[uint32]$_.ProcessId; creationDate=[string]$_.CreationDate; commandLine=[string]$_.CommandLine } })
}
function Get-ForbiddenJobKeys([object]$Value, [string]$Path = '$') {
    $rows = New-Object Collections.Generic.List[string]
    if ($null -eq $Value) { return @() }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($key in @($Value.Keys)) {
            $name = [string]$key
            if ($name.ToLowerInvariant() -in @('knownnotchangle','knownnotchlocation','expectednotchangle','searchwindow','fixedangularwindow','groundtruth','labels')) {
                $rows.Add($Path + '.' + $name)
            }
            foreach ($child in @(Get-ForbiddenJobKeys -Value $Value[$key] -Path ($Path + '.' + $name))) { $rows.Add($child) }
        }
    }
    elseif ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        $index = 0
        foreach ($item in $Value) {
            foreach ($child in @(Get-ForbiddenJobKeys -Value $item -Path ($Path + '[' + $index + ']'))) { $rows.Add($child) }
            $index++
        }
    }
    elseif ($Value.PSObject -and @($Value.PSObject.Properties).Count -gt 0 -and $Value -isnot [ValueType] -and $Value -isnot [string]) {
        foreach ($property in @($Value.PSObject.Properties)) {
            $name = [string]$property.Name
            if ($name.ToLowerInvariant() -in @('knownnotchangle','knownnotchlocation','expectednotchangle','searchwindow','fixedangularwindow','groundtruth','labels')) {
                $rows.Add($Path + '.' + $name)
            }
            foreach ($child in @(Get-ForbiddenJobKeys -Value $property.Value -Path ($Path + '.' + $name))) { $rows.Add($child) }
        }
    }
    return @($rows)
}
function Invoke-BoundedPython([string]$Python, [string]$Engine, [string]$Job, [string]$TargetOutputRoot) {
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $startInfo.Arguments = '"' + $Engine + '" --run --job "' + $Job + '" --output-root "' + $TargetOutputRoot + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-True ($process.Start()) 'O3D3R4 Python did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(780000)) {
        try { $process.Kill() } catch {}
        [void]$process.WaitForExit(5000)
        throw 'O3D3R4 Python exceeded the 780-second child timeout.'
    }
    $process.WaitForExit()
    $result = [pscustomobject]@{ exitCode=$process.ExitCode; stdout=[string]$stdoutTask.Result; stderr=[string]$stderrTask.Result }
    $process.Dispose()
    Assert-True ($result.stdout.Length -le 1048576 -and $result.stderr.Length -le 1048576) 'O3D3R4 child output exceeded its bounded capture.'
    return $result
}

if (-not [string]::IsNullOrWhiteSpace($LiveContractFixtureManifest)) {
    Assert-True ([bool]$Preflight -and -not [bool]$Rehearsal) 'O3D3R4 live-contract fixture is preflight-only.'
    Assert-True (Test-Path -LiteralPath $LiveContractFixtureManifest -PathType Leaf) 'O3D3R4 live-contract fixture absent.'
    $fixture = Get-Content -LiteralPath $LiveContractFixtureManifest -Raw | ConvertFrom-Json
    Assert-True ([string]$fixture.schema -eq 'argos_o3d3_live_contract_fixture_v1' -and [string]$fixture.state -eq 'FROZEN') 'O3D3R4 live-contract fixture changed.'
    Assert-LiveSelfPins -JobPath ([string]$fixture.jobPath) -ExpectedJobSha ([string]$fixture.jobSha256) -InstallationPath ([string]$fixture.installationPath) -ExpectedInstallationSha ([string]$fixture.installationSha256)
    [ordered]@{
        schema='argos_o3d3_live_contract_fixture_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R4_LIVE_CONTRACT_FIXTURE';revision=$revision
        liveJobAssertionExecuted=$true;liveInstallationAssertionExecuted=$true;sourceImageBytesRead=$false;pixelsDecoded=$false;processStarted=$false
        mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$coreSource = Join-Path $effectivePayloadRoot 'NativeFrontsideWaferPoseOpenCvV2.py'
$r5Source = Join-Path $effectivePayloadRoot 'NativeFrontsideWaferPoseOpenCvV2R5.py'
$r6Source = Join-Path $effectivePayloadRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py'
$jobSource = if ($Rehearsal -and -not [string]::IsNullOrWhiteSpace($RehearsalJobPath)) { $RehearsalJobPath } else { Join-Path $effectivePayloadRoot 'O3D3R4_HOTSPOT_JOB.json' }
$python = Join-Path $RuntimeRoot 'python.exe'
$subst = Join-Path $env:SystemRoot 'System32\subst.exe'
$workPartial = $WorkRoot + '.partial'
$workFailed = $WorkRoot + '.failed'
$outputFailed = $OutputRoot + '.failed'
$summaryPath = Join-Path $OutputRoot 'SUMMARY.json'
$gatePath = Join-Path $OutputRoot 'RUN_GATE.json'
$executionPath = Join-Path $OutputRoot 'EXECUTION.json'

Assert-True ($env:COMPUTERNAME.Equals($ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "O3D3R4 wrong computer: $($env:COMPUTERNAME)"
foreach ($path in @($coreSource,$r5Source,$r6Source,$jobSource,$python,$subst,$RuntimeInstallationPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O3D3R4 dependency absent: $path"
    Assert-PathBudget $path 32
}
Assert-True ((Get-Sha256 $coreSource) -eq $coreSha) 'O3D3R4 core changed.'
Assert-True ((Get-Sha256 $r5Source) -eq $r5Sha) 'O3D3R4 R5 base changed.'
Assert-True ((Get-Sha256 $r6Source) -eq $r6Sha) 'O3D3R4 R6 entrypoint changed.'
if (-not $Rehearsal) { Assert-LiveSelfPins -JobPath $jobSource -ExpectedJobSha $liveJobSha -InstallationPath $RuntimeInstallationPath -ExpectedInstallationSha $installationSha }
$pythonCommand = Get-Command -Name $python -CommandType Application -ErrorAction Stop
$substCommand = Get-Command -Name $subst -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($python), [StringComparison]::OrdinalIgnoreCase)) 'O3D3R4 Python resolution changed.'
Assert-True ([IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($subst), [StringComparison]::OrdinalIgnoreCase)) 'O3D3R4 subst resolution changed.'
Assert-True (Test-Path -LiteralPath $SourceAliasRoot -PathType Container) 'O3D3R4 source alias root absent.'
Assert-True (-not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name F -ErrorAction SilentlyContinue)) 'O3D3R4 F: is already in use.'

$job = Get-Content -LiteralPath $jobSource -Raw | ConvertFrom-Json
Assert-True ([string]$job.schema -eq 'argos_native_frontside_wafer_pose_opencv_v2_job') 'O3D3R4 job schema changed.'
Assert-True ([string]$job.inferenceScope -eq 'FULL_360_PERIMETER_NO_LOCATION_PRIOR' -and -not [bool]$job.scorerInputsPresent) 'O3D3R4 full-perimeter inference scope changed.'
Assert-True (-not [bool]$job.knownNotchLocationConsumed -and -not [bool]$job.notchAnglePriorConsumed -and -not [bool]$job.fixedAngularSearchWindowConsumed -and -not [bool]$job.regressionLabelsConsumed) 'O3D3R4 job consumed forbidden prior or label inputs.'
Assert-True ([bool]$job.reviewOnly -and -not [bool]$job.trainingEligible -and -not [bool]$job.xmlEligible -and -not [bool]$job.productionEligible) 'O3D3R4 job authority widened.'
Assert-True (@(Get-ForbiddenJobKeys -Value $job).Count -eq 0) 'O3D3R4 job contains a forbidden location or scorer key.'
$inputs = @($job.inputs)
Assert-True ($inputs.Count -ge 1 -and $inputs.Count -le 32) 'O3D3R4 job input cardinality is invalid.'
if (-not $Rehearsal) {
    Assert-True ($inputs.Count -eq 10 -and [string]$job.sourceFreezeGateSha256 -eq $sourceFreezeGateSha -and [string]$job.sourceAcquisitionFingerprintSha256 -eq $sourceFingerprintSha) 'O3D3R4 live source-freeze binding changed.'
}
$identities = New-Object Collections.Generic.HashSet[string]([StringComparer]::OrdinalIgnoreCase)
foreach ($input in $inputs) {
    Assert-True ($identities.Add([string]$input.identity)) 'O3D3R4 duplicate input identity.'
    foreach ($channel in @('bf','df')) {
        $sourcePath = [string]$input.($channel + 'Path')
        $sourceBytes = [int64]$input.($channel + 'Bytes')
        $sourceSha = [string]$input.($channel + 'Sha256')
        Assert-True ($sourcePath.StartsWith($aliasPath, [StringComparison]::OrdinalIgnoreCase)) "O3D3R4 source is not under F: $sourcePath"
        Assert-True ($sourceBytes -gt 0 -and $sourceSha -match '^[A-F0-9]{64}$') "O3D3R4 source pin invalid: $sourcePath"
        Assert-PathBudget $sourcePath 32
    }
}
if (-not $Rehearsal) {
    Assert-True (@($inputs | Where-Object { [string]$_.identity -notmatch '^62629-419_20260824112405_SLOT(16|17|18|19|20|21|22|23|24|25)$' }).Count -eq 0) 'O3D3R4 live identity set changed.'
}
foreach ($path in @($WorkRoot,$workPartial,$workFailed,$OutputRoot,$outputFailed,$summaryPath,$gatePath,$executionPath)) {
    Assert-PathBudget $path 32
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3D3R4 create-new target exists: $path"
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{
        schema='argos_o3d3_endpoint_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R4_ENDPOINT_PREFLIGHT';revision=$revision;rehearsal=[bool]$Rehearsal
        computerName=$env:COMPUTERNAME;coreSha256=$coreSha;r5Sha256=$r5Sha;r6Sha256=$r6Sha;jobSha256=Get-Sha256 $jobSource;inputCount=$inputs.Count
        processorProcessCount=$processorBefore.Count;sourceImageBytesRead=$false;sourceHashesComputed=$false;pixelsDecoded=$false;processStarted=$false;sourceAliasPresentBefore=$false
        mutationsPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;waferActionPerformed=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false
        fixedAngularSearchWindowConsumed=$false;regressionLabelsConsumed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$aliasCreated = $false
try {
    $createOutput = & $subst $aliasName $SourceAliasRoot 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $aliasPath -PathType Container)) ('O3D3R4 alias creation failed: ' + $createOutput.Trim())
    $aliasCreated = $true
    $mappingRows = @((& $subst 2>&1 | Out-String) -split '\r?\n' | Where-Object { $_ -match '(?i)^\s*F:\\:\s*=>\s*(.+?)\s*$' })
    Assert-True ($mappingRows.Count -eq 1) 'O3D3R4 F: mapping cardinality changed.'
    $aliasMatch = [regex]::Match($mappingRows[0], '(?i)^\s*F:\\:\s*=>\s*(.+?)\s*$')
    Assert-True ($aliasMatch.Groups[1].Value.Trim().TrimEnd('\').Equals($SourceAliasRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O3D3R4 F: target changed.'

    $verifiedSources = New-Object Collections.Generic.List[object]
    foreach ($input in $inputs) {
        foreach ($channel in @('bf','df')) {
            $sourcePath = [string]$input.($channel + 'Path')
            $expectedBytes = [int64]$input.($channel + 'Bytes')
            $expectedSha = [string]$input.($channel + 'Sha256')
            Assert-True (Test-Path -LiteralPath $sourcePath -PathType Leaf) "O3D3R4 source absent: $sourcePath"
            Assert-True ((Get-Item -LiteralPath $sourcePath).Length -eq $expectedBytes) "O3D3R4 source bytes changed: $sourcePath"
            Assert-True ((Get-Sha256 $sourcePath) -eq $expectedSha) "O3D3R4 source SHA-256 changed: $sourcePath"
            $verifiedSources.Add([pscustomobject]@{ identity=[string]$input.identity; channel=$channel.ToUpperInvariant(); bytes=$expectedBytes; sha256=$expectedSha })
        }
    }
    Assert-True ($verifiedSources.Count -eq ($inputs.Count * 2)) 'O3D3R4 verified source cardinality changed.'

    [void](New-Item -ItemType Directory -Path $workPartial)
    foreach ($name in @('NativeFrontsideWaferPoseOpenCvV2.py','NativeFrontsideWaferPoseOpenCvV2R5.py','NativeFrontsideWaferPoseOpenCvV2R6.py')) {
        Copy-Item -LiteralPath (Join-Path $effectivePayloadRoot $name) -Destination (Join-Path $workPartial $name) -ErrorAction Stop
    }
    Copy-Item -LiteralPath $jobSource -Destination (Join-Path $workPartial 'JOB.json') -ErrorAction Stop
    Assert-True ((Get-Sha256 (Join-Path $workPartial 'NativeFrontsideWaferPoseOpenCvV2.py')) -eq $coreSha) 'O3D3R4 staged core changed.'
    Assert-True ((Get-Sha256 (Join-Path $workPartial 'NativeFrontsideWaferPoseOpenCvV2R5.py')) -eq $r5Sha) 'O3D3R4 staged R5 changed.'
    Assert-True ((Get-Sha256 (Join-Path $workPartial 'NativeFrontsideWaferPoseOpenCvV2R6.py')) -eq $r6Sha) 'O3D3R4 staged R6 changed.'
    Assert-True ((Get-Sha256 (Join-Path $workPartial 'JOB.json')) -eq (Get-Sha256 $jobSource)) 'O3D3R4 staged job changed.'
    Move-Item -LiteralPath $workPartial -Destination $WorkRoot -ErrorAction Stop

    $run = Invoke-BoundedPython -Python $python -Engine (Join-Path $WorkRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py') -Job (Join-Path $WorkRoot 'JOB.json') -TargetOutputRoot $OutputRoot
    Assert-True ($run.exitCode -eq 0) ('O3D3R4 OpenCV provider failed: ' + $run.stderr.Trim())
    Assert-True (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'O3D3R4 summary absent.'
    $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
    Assert-True ([string]$summary.schema -eq 'argos_native_frontside_wafer_pose_opencv_v2_summary' -and [string]$summary.state -eq 'COMPLETE_REVIEW_ONLY_DEVELOPMENT') 'O3D3R4 summary schema or state changed.'
    Assert-True ([int]$summary.inputCount -eq $inputs.Count -and @($summary.rows).Count -eq $inputs.Count) 'O3D3R4 summary cardinality changed.'
    Assert-True ([bool]$summary.fullPerimeterInference -and [bool]$summary.bfDfIndependent -and -not [bool]$summary.bfDfPoseAveragingAllowed -and -not [bool]$summary.rotationAuthorityGranted) 'O3D3R4 summary geometry authority changed.'
    Assert-True (-not [bool]$summary.knownNotchLocationConsumed -and -not [bool]$summary.notchAnglePriorConsumed -and -not [bool]$summary.fixedAngularSearchWindowConsumed -and -not [bool]$summary.regressionLabelsConsumed) 'O3D3R4 summary consumed forbidden prior or scorer inputs.'
    Assert-True ([bool]$summary.reviewOnly -and -not [bool]$summary.trainingEligible -and -not [bool]$summary.xmlEligible -and -not [bool]$summary.productionEligible) 'O3D3R4 summary authority widened.'

    $resultRows = New-Object Collections.Generic.List[object]
    foreach ($input in $inputs) {
        $identity = [string]$input.identity
        $resultPath = Join-Path (Join-Path $OutputRoot $identity) 'NATIVE_WAFER_POSE_OPENCV_V2.json'
        Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) "O3D3R4 result absent: $identity"
        $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        Assert-True ([string]$result.schema -eq 'argos_native_frontside_wafer_pose_opencv_v2' -and [string]$result.identity -eq $identity) "O3D3R4 result identity changed: $identity"
        Assert-True (-not [bool]$result.rotationAuthorityGranted -and -not [bool]$result.bfDfPoseAveraged -and [bool]$result.fullPerimeterInference) "O3D3R4 result geometry authority changed: $identity"
        Assert-True (-not [bool]$result.knownNotchLocationConsumed -and -not [bool]$result.notchAnglePriorConsumed -and -not [bool]$result.fixedAngularSearchWindowConsumed -and -not [bool]$result.historicalNotchLabelsConsumed) "O3D3R4 result consumed forbidden inputs: $identity"
        Assert-True ([bool]$result.reviewOnly -and -not [bool]$result.trainingEligible -and -not [bool]$result.xmlEligible -and -not [bool]$result.productionEligible) "O3D3R4 result authority widened: $identity"
        Assert-True ([string]$result.sources.bfSha256 -eq [string]$input.bfSha256 -and [string]$result.sources.dfSha256 -eq [string]$input.dfSha256) "O3D3R4 result provenance changed: $identity"
        $selected = $result.selectedReviewOnlyManufacturedNotch
        $resultRows.Add([pscustomobject][ordered]@{
            identity=$identity;state=[string]$result.state;resultSha256=Get-Sha256 $resultPath
            bfQualified=[bool]$result.bf.qualified;bfCenterX=[double]$result.bf.fit.centerX;bfCenterY=[double]$result.bf.fit.centerY;bfRadius=[double]$result.bf.fit.radius;bfCoverage=[double]$result.bf.fit.angularCoverageFraction;bfRmsResidualPx=[double]$result.bf.fit.rmsResidualPx;bfCandidateCount=@($result.bf.candidates).Count
            dfQualified=[bool]$result.df.qualified;dfCenterX=[double]$result.df.fit.centerX;dfCenterY=[double]$result.df.fit.centerY;dfRadius=[double]$result.df.fit.radius;dfCoverage=[double]$result.df.fit.angularCoverageFraction;dfRmsResidualPx=[double]$result.df.fit.rmsResidualPx;dfCandidateCount=@($result.df.candidates).Count
            channelCenterDifferencePx=[double]$result.channelComparison.centerDifferencePx;channelRadiusDifferencePx=[double]$result.channelComparison.radiusDifferencePx;physicalCandidateCount=@($result.physicalIndentationCandidates).Count
            manufacturedMorphologyCount=@($result.physicalIndentationCandidates | Where-Object { [bool]$_.manufacturedNotchMorphologyEligible }).Count;manufacturedNotchSelectedForReview=[bool]$result.manufacturedNotchSelectedForReview
            reviewAngleDegrees=if ($null -eq $selected) { $null } else { [double]$selected.reviewAngleDegrees };reviewAngleChannel=if ($null -eq $selected) { $null } else { [string]$selected.reviewAngleChannel }
            selectedWidthDegrees=if ($null -eq $selected) { $null } else { [double]$selected.combinedWidthDegrees };selectedCrossChannelOverlap=if ($null -eq $selected) { $null } else { [double]$selected.crossChannelOverlapFraction }
        })
    }
    Assert-True ($resultRows.Count -eq $inputs.Count) 'O3D3R4 bounded result row cardinality changed.'

    $removeOutput = & $subst $aliasName '/D' 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and -not (Test-Path -LiteralPath $aliasPath)) ('O3D3R4 alias removal failed: ' + $removeOutput.Trim())
    $aliasCreated = $false
    $processorAfter = @(Get-ProcessorRows)
    Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'O3D3R4 protected processor process identity changed.'

    $gate = [ordered]@{
        schema='argos_o3d3_hotspot_edge_notch_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R4_HOTSPOT_EDGE_NOTCH_EXECUTED';disposition='DIAGNOSTIC_ONLY';revision=$revision;rehearsal=[bool]$Rehearsal
        coreSha256=$coreSha;r5Sha256=$r5Sha;r6Sha256=$r6Sha;jobSha256=Get-Sha256 (Join-Path $WorkRoot 'JOB.json');sourceFreezeGateSha256=if ($Rehearsal) { $null } else { $sourceFreezeGateSha }
        sourceAcquisitionFingerprintSha256=if ($Rehearsal) { $null } else { $sourceFingerprintSha };inputCount=$inputs.Count;verifiedSourceCount=$verifiedSources.Count;sourceHashesComputed=$true;allSourceHashesMatched=$true
        summarySha256=Get-Sha256 $summaryPath;summaryState=[string]$summary.state;rows=$resultRows.ToArray();sourceAliasName=$aliasName;sourceAliasRoot=$SourceAliasRoot;sourceAliasRemoved=$true;processorProcessCount=$processorAfter.Count;processorIdentityUnchanged=$true
        sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;fullPerimeterInference=$true;bfDfIndependent=$true;rotationAuthorityGranted=$false;knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;regressionLabelsConsumed=$false
        independentValidationCohortInspected=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;waferActionPerformed=$false;holdsCleared=$false
        reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    }
    Write-JsonNew $gatePath $gate 20
    Write-JsonNew $executionPath ([ordered]@{
        schema='argos_o3d3_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R4_EXECUTION';revision=$revision;computerName=$env:COMPUTERNAME
        workRoot=$WorkRoot;outputRoot=$OutputRoot;summarySha256=Get-Sha256 $summaryPath;gateSha256=Get-Sha256 $gatePath;sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true
        processorIdentityUnchanged=$true;taskOrProcessRestarted=$false;providerActivated=$false;waferActionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }) 10
    $gate | ConvertTo-Json -Compress -Depth 20
}
catch {
    $detail = $_.Exception.Message
    if (Test-Path -LiteralPath $workPartial) {
        if (-not (Test-Path -LiteralPath $workFailed)) { Move-Item -LiteralPath $workPartial -Destination $workFailed -ErrorAction SilentlyContinue }
    }
    elseif ((Test-Path -LiteralPath $WorkRoot) -and -not (Test-Path -LiteralPath $workFailed)) {
        Move-Item -LiteralPath $WorkRoot -Destination $workFailed -ErrorAction SilentlyContinue
    }
    if ((Test-Path -LiteralPath $OutputRoot) -and -not (Test-Path -LiteralPath $outputFailed)) {
        Move-Item -LiteralPath $OutputRoot -Destination $outputFailed -ErrorAction SilentlyContinue
    }
    throw ('O3D3R4_EXECUTION_FAILED: ' + $detail)
}
finally {
    if ($aliasCreated) {
        & $subst $aliasName '/D' 2>&1 | Out-Null
        $aliasCreated = $false
    }
}


