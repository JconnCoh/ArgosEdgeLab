#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'OCV02_R13B_ALPHABET_CROP_20260902A'
$providerRevision = 'ARGOS_OPENCV_SCRIBE_ALPHABET_CROP_R13B_20260902'
$requestId = 'REQ_20260902T204408092Z_R13B'
$liveComputerName = 'A1025645101'
$liveRuntimeInstallationSha256 = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$rehearsalRuntimeInstallationSha256 = '7EA60AC1E8867B1BCA06408CFB8B29FBC63BE946BD83C2D696BCBCCDBA2B7CED'
$liveProviderSha256 = '995587862B6FA280C1D48907254AA82B5C4120F4B26A10CFE559A1E27BD9E0B3'
$configurationSha256 = '1F58C66A18C4ED58B5ED3EEE27BACF9D65948140F8609A194CFE8A68501D6F42'
$referenceBundleSha256 = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$referenceManifestSha256 = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
$maximumBundleBytes = 8388608
$maximumBundleBase64Characters = 12582912
$liveSourceBytesPerImage = [int64]475379874
$maximumRehearsalSourceBytesPerImage = [int64]1048576

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-RequiredProperty([object]$Object, [string]$Name, [string]$Context) {
    Assert-True ($null -ne $Object) "R13B missing object: $Context"
    $property = $Object.PSObject.Properties[$Name]
    Assert-True ($null -ne $property) "R13B missing property: $Context.$Name"
    return $property.Value
}

function Assert-Sha256Text([string]$Value, [string]$Context) {
    Assert-True ($Value -match '^[0-9A-F]{64}$') "R13B invalid SHA-256: $Context"
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Get-TextSha256([string]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Value)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Get-FullPath([string]$Path, [string]$Context) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) "R13B empty path: $Context"
    Assert-True ($Path.IndexOf('"') -lt 0 -and $Path.IndexOf("`r") -lt 0 -and $Path.IndexOf("`n") -lt 0) "R13B unsafe path text: $Context"
    $full = [IO.Path]::GetFullPath($Path)
    Assert-True ([IO.Path]::IsPathRooted($full)) "R13B path is not rooted: $Context"
    return $full
}

function Join-WindowsPath([string]$Root, [string]$Relative) {
    return $Root.TrimEnd('\') + '\' + $Relative.TrimStart('\')
}

function Assert-PathComponents([string]$Path, [string]$Context) {
    $parts = @($Path.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($parts.Count -gt 0) { [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) } else { 0 }
    Assert-True ($longest -le 80) "R13B path component exceeds 80 characters: $Context"
}

function Assert-PathBudget([string]$Path, [string]$Context, [int]$Reserve = 32) {
    $full = Get-FullPath $Path $Context
    Assert-PathComponents $full $Context
    Assert-True (($full.Length + $Reserve) -lt 200) "R13B unsafe effective path: $Context"
}

function Assert-CanonicalSourcePath([string]$Path, [string]$Context) {
    Assert-PathComponents $Path $Context
    Assert-True ($Path.Length -lt 230) "R13B canonical source path reaches hard stop: $Context"
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    $json = $Value | ConvertTo-Json -Depth $Depth
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Get-ProcessorRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Invoke-AllWaferProcessorV2.ps1*' } |
        Sort-Object ProcessId |
        ForEach-Object {
            [pscustomobject]@{
                processId = [uint32]$_.ProcessId
                creationDate = [string]$_.CreationDate
                commandLine = [string]$_.CommandLine
            }
        })
}

function Get-SubstRows([string]$SubstPath) {
    $output = & $SubstPath 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0) ('R13B subst inventory failed: ' + $output.Trim())
    return @(($output -split '\r?\n') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}

function Assert-XAliasAbsent([string]$SubstPath) {
    $rows = @(Get-SubstRows $SubstPath)
    $matching = @($rows | Where-Object { $_ -match '(?i)^\s*X:\\:\s*=>' })
    Assert-True ($matching.Count -eq 0) 'R13B X: subst alias is already in use.'
    Assert-True ($null -eq (Get-PSDrive -Name X -ErrorAction SilentlyContinue)) 'R13B X: PowerShell drive is already in use.'
    Assert-True (-not (Test-Path -LiteralPath 'X:\')) 'R13B X: filesystem path is already in use.'
}

function Assert-Authority([object]$Authority, [string]$Context, [string[]]$FalseFields) {
    Assert-True ([bool](Get-RequiredProperty $Authority 'reviewOnly' $Context)) "R13B review-only authority changed: $Context"
    foreach ($field in $FalseFields) {
        Assert-True (-not [bool](Get-RequiredProperty $Authority $field $Context)) "R13B forbidden authority enabled: $Context.$field"
    }
}

function Assert-TargetPositions([object[]]$Actual, [object[]]$Expected, [string]$Context) {
    $actualRows = @($Actual)
    $expectedRows = @($Expected)
    Assert-True ($actualRows.Count -eq $expectedRows.Count) "R13B target-position count changed: $Context"
    for ($index = 0; $index -lt $expectedRows.Count; $index++) {
        Assert-True ([int]$actualRows[$index].position -eq [int]$expectedRows[$index].position) "R13B target position changed: $Context"
        Assert-True ([string]$actualRows[$index].label -ceq [string]$expectedRows[$index].label) "R13B target label changed: $Context"
    }
}

function Get-BoundedText([string]$Value, [int]$MaximumCharacters = 65536) {
    if ($null -eq $Value) { return '' }
    if ($Value.Length -le $MaximumCharacters) { return $Value }
    return $Value.Substring(0, $MaximumCharacters)
}

function Invoke-BoundedPython([string]$Python, [string]$Provider, [string]$Job, [string]$OutputRoot, [int]$TimeoutSeconds) {
    foreach ($path in @($Python,$Provider,$Job,$OutputRoot)) {
        Assert-True ($path.IndexOf('"') -lt 0 -and $path.IndexOf("`r") -lt 0 -and $path.IndexOf("`n") -lt 0) 'R13B process argument contains unsafe text.'
    }
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $startInfo.Arguments = '"' + $Provider + '" --job "' + $Job + '" --output-root "' + $OutputRoot + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $started = $false
    $timedOut = $false
    $exitCode = $null
    $stdout = ''
    $stderr = ''
    $launchError = ''
    $stdoutTask = $null
    $stderrTask = $null
    try {
        $started = [bool]$process.Start()
        if (-not $started) { throw 'Python process returned false from Start().' }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $timedOut = $true
            try { $process.Kill() } catch {}
            [void]$process.WaitForExit(5000)
        }
        if ($process.HasExited) {
            $stdout = [string]$stdoutTask.Result
            $stderr = [string]$stderrTask.Result
        }
        else { $launchError = 'Python did not exit within five seconds after the single bounded kill.' }
        if (-not $timedOut -and $process.HasExited) { $exitCode = [int]$process.ExitCode }
    }
    catch {
        $launchError = $_.Exception.Message
        if ($started -and -not $process.HasExited) {
            try { $process.Kill() } catch {}
            [void]$process.WaitForExit(5000)
        }
    }
    finally { $process.Dispose() }
    return [pscustomobject]@{
        started = $started
        timedOut = $timedOut
        exitCode = $exitCode
        launchError = Get-BoundedText $launchError 4096
        stdout = Get-BoundedText $stdout
        stderr = Get-BoundedText $stderr
        stdoutSha256 = Get-TextSha256 $stdout
        stderrSha256 = Get-TextSha256 $stderr
    }
}

function Get-SafeArtifactPath([string]$CaseRoot, [string]$RelativePath) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'R13B artifact relative path is empty.'
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) 'R13B artifact path is rooted.'
    Assert-True ($RelativePath.IndexOf(':') -lt 0 -and $RelativePath.IndexOf('"') -lt 0) 'R13B artifact path contains forbidden text.'
    $normalizedRelative = $RelativePath.Replace('/', '\')
    $segments = @($normalizedRelative.Split([char[]]@('\'), [StringSplitOptions]::RemoveEmptyEntries))
    Assert-True ($segments.Count -gt 0 -and @($segments | Where-Object { $_ -eq '..' -or $_ -eq '.' }).Count -eq 0) 'R13B artifact path traverses its case root.'
    $full = [IO.Path]::GetFullPath((Join-WindowsPath $CaseRoot $normalizedRelative))
    $prefix = [IO.Path]::GetFullPath($CaseRoot).TrimEnd('\') + '\'
    Assert-True ($full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) 'R13B artifact escaped its case root.'
    Assert-PathBudget $full 'case artifact' 32
    return $full
}

$expectedCases = @(
    [ordered]@{caseId='K25V';physicalIdentity='62546-481_20260707164232_Slot25';purpose='INDEPENDENT_VALIDATION';confirmedScribe='13DCK076SUG1';targetPositions=@([ordered]@{position=5;label='K'});aliasAnchorCanonicalPath='D:\KLARFExport\PST_BRKFULLMETAL\Lot_62546-481\62546-481';bfRelativePath='Slot25\BrightfieldFrontsideWafer\resizedImage\62546-481_Slot25_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';dfRelativePath='Slot25\DarkfieldFrontsideWafer\resizedImage\62546-481_Slot25_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'},
    [ordered]@{caseId='X18V';physicalIdentity='62625-907-PRE_20260709123021_Slot18';purpose='INDEPENDENT_VALIDATION';confirmedScribe='146XF111SUG7';targetPositions=@([ordered]@{position=4;label='X'});aliasAnchorCanonicalPath='D:\KLARFExport\PST_BREAK_BARE\Lot_62625-907_PRE\62625-907_PRE';bfRelativePath='Slot18\BrightfieldFrontsideWafer\resizedImage\62625-907_PRE_Slot18_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';dfRelativePath='Slot18\DarkfieldFrontsideWafer\resizedImage\62625-907_PRE_Slot18_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'},
    [ordered]@{caseId='JQ16D';physicalIdentity='62625-956_20260729122701_Slot16';purpose='DEVELOPMENT';confirmedScribe='147JQ122SUB6';targetPositions=@([ordered]@{position=4;label='J'},[ordered]@{position=5;label='Q'});aliasAnchorCanonicalPath='D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701';bfRelativePath='Slot16\BrightfieldFrontsideWafer\resizedImage\62625-956_Slot16_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';dfRelativePath='Slot16\DarkfieldFrontsideWafer\resizedImage\62625-956_Slot16_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'},
    [ordered]@{caseId='JQ20V';physicalIdentity='62625-956_20260729122701_Slot20';purpose='INDEPENDENT_VALIDATION';confirmedScribe='147JQ117SUD6';targetPositions=@([ordered]@{position=4;label='J'},[ordered]@{position=5;label='Q'});aliasAnchorCanonicalPath='D:\KLARFExport\BackSide_BowComp\Lot_62625-956\62625-956_20260729122701';bfRelativePath='Slot20\BrightfieldFrontsideWafer\resizedImage\62625-956_Slot20_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';dfRelativePath='Slot20\DarkfieldFrontsideWafer\resizedImage\62625-956_Slot20_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'}
)

$explicitInvocation = -not [string]::IsNullOrWhiteSpace($InvocationManifest)
Assert-True (-not [bool]$Rehearsal -or $explicitInvocation) 'R13B rehearsal requires explicit -InvocationManifest.'
if ($explicitInvocation) {
    $invocationPath = Get-FullPath $InvocationManifest 'invocation manifest'
}
else {
    $shortDefault = Join-Path $PSScriptRoot 'LIVE.json'
    $longDefault = Join-Path $PSScriptRoot 'R13B_LIVE_INVOCATION.json'
    $invocationPath = if (Test-Path -LiteralPath $shortDefault -PathType Leaf) { $shortDefault } else { $longDefault }
}
Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) "R13B invocation manifest absent: $invocationPath"
Assert-True ((Get-Item -LiteralPath $invocationPath).Length -le 262144) 'R13B invocation manifest exceeds 256 KiB.'
$invocationSha256 = Get-Sha256 $invocationPath
$invocation = Get-Content -Raw -LiteralPath $invocationPath | ConvertFrom-Json
$payloadRoot = Split-Path -Parent $invocationPath

Assert-True ([string]$invocation.schema -eq 'argos_opencv_scribe_alphabet_crop_live_invocation_v1') 'R13B invocation schema changed.'
Assert-True ([string]$invocation.revision -eq $revision -and [string]$invocation.requestId -eq $requestId) 'R13B invocation identity changed.'
Assert-True ([string]$invocation.state -eq 'FROZEN') 'R13B invocation is not frozen.'
Assert-Authority $invocation.authority 'invocation.authority' @('automaticIdentityAuthority','trainingAuthorized','trainingEligible','trainingExecuted','xmlEligible','productionEligible','productionRoutingEnabled','mayClearHolds','sourceMutationAllowed','sourceDeletionAllowed','taskOrProcessRestartAllowed','providerActivationAllowed','retryAuthorized')
Assert-True ([int]$invocation.authority.maximumPublications -eq 1) 'R13B publication count changed.'

$expectedComputerName = [string]$invocation.expectedComputerName
Assert-True (-not [string]::IsNullOrWhiteSpace($expectedComputerName)) 'R13B expected computer is absent.'
if (-not $Rehearsal) { Assert-True ($expectedComputerName -eq $liveComputerName) 'R13B live computer contract changed.' }
Assert-True ($env:COMPUTERNAME.Equals($expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) "R13B wrong computer: $($env:COMPUTERNAME)"

$runtimeRoot = Get-FullPath ([string]$invocation.runtime.root) 'runtime root'
$pythonPath = Get-FullPath ([string]$invocation.runtime.python) 'runtime Python'
$installationPath = Get-FullPath ([string]$invocation.runtime.installationEvidence) 'runtime installation evidence'
$referenceBundlePath = Get-FullPath ([string]$invocation.referenceBundle.path) 'reference bundle'
Assert-True ($pythonPath.Equals((Join-WindowsPath $runtimeRoot 'python.exe'), [StringComparison]::OrdinalIgnoreCase)) 'R13B Python is outside the exact runtime root.'
$runtimeInstallationSha256 = [string]$invocation.runtime.installationSha256
Assert-Sha256Text $runtimeInstallationSha256 'runtime installation'
if ($Rehearsal) {
    Assert-True ($runtimeInstallationSha256 -eq $rehearsalRuntimeInstallationSha256) 'R13B rehearsal runtime installation fixture pin changed.'
}
else {
    Assert-True ($runtimeInstallationSha256 -eq $liveRuntimeInstallationSha256) 'R13B live runtime installation pin changed.'
}
Assert-True ([string]$invocation.referenceBundle.sha256 -eq $referenceBundleSha256) 'R13B reference bundle pin changed.'
Assert-True ([string]$invocation.referenceBundle.manifestSha256 -eq $referenceManifestSha256 -and [int]$invocation.referenceBundle.referenceCount -eq 456 -and [string]$invocation.referenceBundle.missingLabels -eq 'IJKOQVWXYZ') 'R13B reference contract changed.'
foreach ($path in @($pythonPath,$installationPath,$referenceBundlePath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R13B dependency absent: $path"
    Assert-PathBudget $path 'runtime/reference dependency' 32
}
Assert-True ((Get-Sha256 $installationPath) -eq $runtimeInstallationSha256) 'R13B runtime installation evidence changed.'
Assert-True ((Get-Sha256 $referenceBundlePath) -eq $referenceBundleSha256) 'R13B reference bundle bytes changed.'
$pythonCommand = Get-Command -Name $pythonPath -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($pythonCommand.Source).Equals($pythonPath, [StringComparison]::OrdinalIgnoreCase)) 'R13B Python command resolution changed.'

$substPath = Join-Path $env:SystemRoot 'System32\subst.exe'
Assert-True (Test-Path -LiteralPath $substPath -PathType Leaf) 'R13B subst.exe is absent.'
$substCommand = Get-Command -Name $substPath -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($substPath), [StringComparison]::OrdinalIgnoreCase)) 'R13B subst command resolution changed.'

$workRoot = Get-FullPath ([string]$invocation.roots.work) 'work root'
$workPartial = Get-FullPath ([string]$invocation.roots.workPartial) 'work partial root'
$workFailed = Get-FullPath ([string]$invocation.roots.workFailed) 'work failed root'
$outputRoot = Get-FullPath ([string]$invocation.roots.output) 'output root'
$outputPartial = Get-FullPath ([string]$invocation.roots.outputPartial) 'output partial root'
$bundlePath = Get-FullPath ([string]$invocation.roots.bundle) 'return bundle'
$bundlePartial = $bundlePath + '.partial'
Assert-True ([string]$invocation.roots.sourceAlias -eq 'X:') 'R13B source alias changed.'
Assert-True ($workPartial.Equals(($workRoot + '.partial'), [StringComparison]::OrdinalIgnoreCase) -and $workFailed.Equals(($workRoot + '.failed'), [StringComparison]::OrdinalIgnoreCase)) 'R13B work lifecycle roots changed.'
Assert-True ($outputPartial.Equals(($outputRoot + '.partial'), [StringComparison]::OrdinalIgnoreCase)) 'R13B output lifecycle root changed.'
if (-not $Rehearsal) {
    Assert-True ($workRoot -eq 'D:\A2\w\ocv\R13B' -and $outputRoot -eq 'D:\A2\o\ocv\R13B' -and $bundlePath -eq 'D:\A2\o\ocv\R13B_RETURN.zip') 'R13B live roots changed.'
    foreach ($path in @($workRoot,$workPartial,$workFailed,$outputRoot,$outputPartial,$bundlePath,$bundlePartial)) {
        Assert-True ($path.StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase)) 'R13B live create-new path left D:.'
    }
}
Assert-True ([IO.Path]::GetPathRoot($workRoot).Equals([IO.Path]::GetPathRoot($workPartial), [StringComparison]::OrdinalIgnoreCase)) 'R13B work atomic move crosses volumes.'
Assert-True ([IO.Path]::GetPathRoot($outputRoot).Equals([IO.Path]::GetPathRoot($outputPartial), [StringComparison]::OrdinalIgnoreCase)) 'R13B output atomic move crosses volumes.'
foreach ($path in @($workRoot,$workPartial,$workFailed,$outputRoot,$outputPartial,$bundlePath,$bundlePartial)) {
    Assert-PathBudget $path 'create-new root' 32
    Assert-True (-not (Test-Path -LiteralPath $path)) "R13B create-new root exists: $path"
}
foreach ($parent in @((Split-Path -Parent $workRoot),(Split-Path -Parent $outputRoot),(Split-Path -Parent $bundlePath))) {
    Assert-True (Test-Path -LiteralPath $parent -PathType Container) "R13B required parent root absent: $parent"
}

Assert-True ([int]$invocation.execution.maximumSequentialProviderChildren -eq 4 -and [int]$invocation.execution.maximumConcurrentProviderChildren -eq 1) 'R13B provider serialization changed.'
Assert-True ([int]$invocation.execution.providerChildTimeoutSeconds -eq 600 -and [int]$invocation.execution.endpointWorkerOuterTimeoutSeconds -eq 3000 -and -not [bool]$invocation.execution.automaticRetryAllowed -and -not [bool]$invocation.execution.caseFailureStopsBatch) 'R13B provider timeout/retry contract changed.'
Assert-True ([bool]$invocation.execution.sourceHashBeforeOpenCvDecodeRequired -and [bool]$invocation.execution.sourceImagesProcessedReadOnlyInPlace -and -not [bool]$invocation.execution.fullSourceImageReturnAllowed) 'R13B source-read contract changed.'
Assert-True ([int64]$invocation.outputContract.maximumBundleBytes -eq $maximumBundleBytes -and [int]$invocation.outputContract.maximumBundleBase64Characters -eq $maximumBundleBase64Characters) 'R13B bundle bounds changed.'
Assert-True ([string]$invocation.outputContract.portalResponseTransport -eq 'MAINTENANCE_STDOUT_COMPACT_JSON_BASE64' -and [bool]$invocation.outputContract.sourceToGridToCellToTargetSha256Required) 'R13B output provenance contract changed.'

$providerPin = $invocation.payload.provider
$configurationPin = $invocation.payload.configuration
Assert-True ([string]$providerPin.file -eq 'R13B.py' -and [string]$configurationPin.file -eq 'CFG.json') 'R13B short payload filenames changed.'
Assert-Sha256Text ([string]$providerPin.sha256) 'payload.provider'
Assert-Sha256Text ([string]$configurationPin.sha256) 'payload.configuration'
if (-not $Rehearsal) { Assert-True ([string]$providerPin.sha256 -eq $liveProviderSha256) 'R13B live provider pin changed.' }
Assert-True ([string]$configurationPin.sha256 -eq $configurationSha256) 'R13B configuration pin changed.'
$providerSource = Join-Path $payloadRoot ([string]$providerPin.file)
$configurationSource = Join-Path $payloadRoot ([string]$configurationPin.file)
$payloadPins = New-Object Collections.Generic.List[object]
$payloadPins.Add([pscustomobject]@{id='provider';file=[string]$providerPin.file;path=$providerSource;sha256=[string]$providerPin.sha256})
$payloadPins.Add([pscustomobject]@{id='configuration';file=[string]$configurationPin.file;path=$configurationSource;sha256=[string]$configurationPin.sha256})
$dependencyExpectations = @(
    [ordered]@{id='r11';file='R11.py';sha256='7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9'},
    [ordered]@{id='r12a';file='R12A.py';sha256='F5EB8FB3281D7D55CDD9FA4A3530A32BD33BBA3B8DB69E0A247C20935F6AD429'},
    [ordered]@{id='r12b';file='R12B.py';sha256='D670CFCE64BF5FDF5307E69ED69A05CB7B404A78B521AB889C7F35044D666FDC'}
)
foreach ($expectedDependency in $dependencyExpectations) {
    $dependency = Get-RequiredProperty $invocation.payload.dependencies ([string]$expectedDependency.id) 'invocation.payload.dependencies'
    Assert-True ([string]$dependency.file -eq [string]$expectedDependency.file -and [string]$dependency.sha256 -eq [string]$expectedDependency.sha256) "R13B dependency pin changed: $($expectedDependency.id)"
    $dependencyPath = Join-Path $payloadRoot ([string]$dependency.file)
    $payloadPins.Add([pscustomobject]@{id=[string]$expectedDependency.id;file=[string]$dependency.file;path=$dependencyPath;sha256=[string]$dependency.sha256})
}
foreach ($pin in $payloadPins) {
    Assert-True (Test-Path -LiteralPath $pin.path -PathType Leaf) "R13B payload absent: $($pin.id)"
    Assert-PathBudget $pin.path "payload $($pin.id)" 32
    Assert-True ((Get-Sha256 $pin.path) -eq $pin.sha256) "R13B payload hash changed: $($pin.id)"
}
$configuration = Get-Content -Raw -LiteralPath $configurationSource | ConvertFrom-Json
Assert-True ([string]$configuration.schema -eq 'argos_opencv_scribe_alphabet_crop_configuration_v1' -and [string]$configuration.revision -eq $revision) 'R13B configuration contract changed.'
Assert-Authority $configuration.authority 'configuration.authority' @('automaticIdentityAuthority','automaticReferenceAdmissionAllowed','trainingAuthorized','trainingEligible','xmlEligible','productionEligible','productionRoutingEnabled','mayClearHolds')

$invocationCases = @($invocation.cases)
Assert-True ($invocationCases.Count -eq 4) 'R13B exact case count changed.'
$validatedCases = New-Object Collections.Generic.List[object]
$sourceMetadataRows = New-Object Collections.Generic.List[object]
for ($caseIndex = 0; $caseIndex -lt $expectedCases.Count; $caseIndex++) {
    $actualCase = $invocationCases[$caseIndex]
    $expectedCase = $expectedCases[$caseIndex]
    foreach ($field in @('caseId','physicalIdentity','purpose','confirmedScribe','aliasAnchorCanonicalPath','bfRelativePath','dfRelativePath')) {
        Assert-True ([string]$actualCase.$field -ceq [string]$expectedCase.$field) "R13B case descriptor changed: $($expectedCase.caseId)/$field"
    }
    $caseSourceBytes = [int64]$actualCase.sourceBytesPerImage
    if ($Rehearsal) {
        Assert-True ($caseSourceBytes -ge 1 -and $caseSourceBytes -le $maximumRehearsalSourceBytesPerImage) "R13B rehearsal source-byte fixture bound changed: $($expectedCase.caseId)"
    }
    else {
        Assert-True ($caseSourceBytes -eq $liveSourceBytesPerImage) "R13B live source-byte contract changed: $($expectedCase.caseId)"
    }
    Assert-True (-not [bool]$actualCase.referenceAdmissionEligible) "R13B case admission contract changed: $($expectedCase.caseId)"
    Assert-TargetPositions @($actualCase.targetPositions) @($expectedCase.targetPositions) ([string]$expectedCase.caseId)
    $sourceRoot = [string]$expectedCase.aliasAnchorCanonicalPath
    $sourceRootProperty = $actualCase.PSObject.Properties['sourceRoot']
    if ($null -ne $sourceRootProperty -and -not [string]::IsNullOrWhiteSpace([string]$sourceRootProperty.Value)) {
        Assert-True ([bool]$Rehearsal -or ([string]$sourceRootProperty.Value -eq [string]$expectedCase.aliasAnchorCanonicalPath)) "R13B live source-root override refused: $($expectedCase.caseId)"
        $sourceRoot = Get-FullPath ([string]$sourceRootProperty.Value) "source root $($expectedCase.caseId)"
    }
    Assert-True (Test-Path -LiteralPath $sourceRoot -PathType Container) "R13B source root absent: $($expectedCase.caseId)"
    $bfCanonical = Join-WindowsPath $sourceRoot ([string]$expectedCase.bfRelativePath)
    $dfCanonical = Join-WindowsPath $sourceRoot ([string]$expectedCase.dfRelativePath)
    Assert-CanonicalSourcePath $bfCanonical "$($expectedCase.caseId)/BF"
    Assert-CanonicalSourcePath $dfCanonical "$($expectedCase.caseId)/DF"
    foreach ($sourceSpec in @([pscustomobject]@{channel='bf';path=$bfCanonical;relative=[string]$expectedCase.bfRelativePath},[pscustomobject]@{channel='df';path=$dfCanonical;relative=[string]$expectedCase.dfRelativePath})) {
        Assert-True (Test-Path -LiteralPath $sourceSpec.path -PathType Leaf) "R13B source absent: $($expectedCase.caseId)/$($sourceSpec.channel)"
        $item = Get-Item -LiteralPath $sourceSpec.path
        Assert-True ([int64]$item.Length -eq $caseSourceBytes) "R13B source byte metadata changed: $($expectedCase.caseId)/$($sourceSpec.channel)"
        Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "R13B source is a reparse point: $($expectedCase.caseId)/$($sourceSpec.channel)"
        $aliasSourcePath = Join-WindowsPath 'X:\' ([string]$sourceSpec.relative)
        Assert-PathBudget $aliasSourcePath "alias source $($expectedCase.caseId)/$($sourceSpec.channel)" 32
        $sourceMetadataRows.Add([pscustomobject]@{caseId=[string]$expectedCase.caseId;channel=[string]$sourceSpec.channel;canonicalProvenancePath=Join-WindowsPath ([string]$expectedCase.aliasAnchorCanonicalPath) ([string]$sourceSpec.relative);executionSourcePath=[string]$sourceSpec.path;bytes=[int64]$item.Length;lastWriteTimeUtc=$item.LastWriteTimeUtc.ToString('o');sha256State='NOT_READ_IN_PREFLIGHT'})
    }
    $validatedCases.Add([pscustomobject]@{descriptor=$actualCase;expected=$expectedCase;sourceRoot=$sourceRoot;sourceBytes=$caseSourceBytes;bfCanonical=$bfCanonical;dfCanonical=$dfCanonical})
}

Assert-XAliasAbsent $substPath
$processorBefore = @(Get-ProcessorRows)
$processorBeforeJson = if ($processorBefore.Count -eq 0) { '[]' } else { [string]($processorBefore | ConvertTo-Json -Compress -Depth 6) }
$processorBeforeSha256 = Get-TextSha256 $processorBeforeJson

if ($Preflight) {
    [ordered]@{
        schema = 'argos_opencv_scribe_r13b_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R13B_STRICTLY_NONMUTATING_PREFLIGHT'
        revision = $revision
        requestId = $requestId
        rehearsal = [bool]$Rehearsal
        invocationManifestSha256 = Get-Sha256 $invocationPath
        caseCount = $validatedCases.Count
        sourceMetadata = $sourceMetadataRows.ToArray()
        runtimeInstallationSha256 = $runtimeInstallationSha256
        referenceBundleSha256 = $referenceBundleSha256
        processorRowsSha256 = $processorBeforeSha256
        sourceImageBytesRead = $false
        sourceHashingPerformed = $false
        pixelsDecoded = $false
        processStarted = $false
        filesystemMutationPerformed = $false
        aliasMutationPerformed = $false
        taskOrProcessRestarted = $false
        providerActivated = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Compress -Depth 20
    return
}

$workPartialCreated = $false
$workCommitted = $false
$outputPartialCreated = $false
try {
    [void](New-Item -ItemType Directory -Path $workPartial)
    $workPartialCreated = $true
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($referenceBundlePath, $workPartial)
    foreach ($pin in $payloadPins) {
        Copy-Item -LiteralPath $pin.path -Destination (Join-Path $workPartial $pin.file)
        Assert-True ((Get-Sha256 (Join-Path $workPartial $pin.file)) -eq $pin.sha256) "R13B staged payload changed: $($pin.id)"
    }
    Copy-Item -LiteralPath $invocationPath -Destination (Join-Path $workPartial 'LIVE.json')
    Assert-True ((Get-Sha256 (Join-Path $workPartial 'LIVE.json')) -eq $invocationSha256) 'R13B staged live manifest changed.'
    $stagedReferenceManifest = Join-Path $workPartial 'refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    Assert-True (Test-Path -LiteralPath $stagedReferenceManifest -PathType Leaf) 'R13B extracted reference manifest is absent.'
    Assert-True ((Get-Sha256 $stagedReferenceManifest) -eq $referenceManifestSha256) 'R13B extracted reference manifest changed.'
    foreach ($relativeRoot in @('refs\glyphs','refs\glyphs_v5_confirmed_20260806')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $workPartial $relativeRoot) -PathType Container) "R13B extracted reference root absent: $relativeRoot"
    }
    Move-Item -LiteralPath $workPartial -Destination $workRoot -ErrorAction Stop
    $workPartialCreated = $false
    $workCommitted = $true
    $runtimeJobRoot = Join-Path $workRoot 'jobs'
    $failedAttemptRoot = Join-Path $workRoot 'failed'
    Assert-PathBudget $failedAttemptRoot 'failed-attempt root' 32
    [void](New-Item -ItemType Directory -Path $runtimeJobRoot)
    [void](New-Item -ItemType Directory -Path $failedAttemptRoot)
    [void](New-Item -ItemType Directory -Path $outputPartial)
    $outputPartialCreated = $true

    $caseRows = New-Object Collections.Generic.List[object]
    foreach ($entry in $validatedCases) {
        $caseId = [string]$entry.expected.caseId
        $caseOutput = Join-Path $outputPartial $caseId
        $caseOutputPartial = $caseOutput + '.partial'
        $caseAttemptQuarantine = Join-Path $failedAttemptRoot $caseId
        $finalCaseOutput = Join-Path $outputRoot $caseId
        $caseResultPath = Join-Path $caseOutput 'CASE_RESULT.json'
        $runtimeJobPath = Join-Path $runtimeJobRoot ($caseId + '.json')
        foreach ($path in @($caseOutput,$caseOutputPartial,$caseAttemptQuarantine,$runtimeJobPath)) {
            Assert-True (-not (Test-Path -LiteralPath $path)) "R13B case create-new path exists: $caseId/$path"
            Assert-PathBudget $path "case create-new path $caseId" 32
        }
        $aliasCreated = $false
        $aliasCleanupFailure = ''
        $attemptQuarantined = $false
        $bfSha256 = ''
        $dfSha256 = ''
        $sourcePairSha256 = ''
        $runtimeJobSha256 = ''
        $providerRun = $null
        $providerResultAccepted = $false
        $pixelsDecodedByOpenCv = $false
        $caseState = 'HOLD_R13B_CASE_LAUNCH_FAILURE'
        $caseDetail = ''
        $artifactRows = @()
        try {
            Assert-XAliasAbsent $substPath
            $createOutput = & $substPath 'X:' ([string]$entry.sourceRoot) 2>&1 | Out-String
            Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath 'X:\' -PathType Container)) ('R13B alias creation failed: ' + $createOutput.Trim())
            $aliasCreated = $true
            $mappingRows = @(Get-SubstRows $substPath)
            $matchingRows = @($mappingRows | Where-Object { $_ -match '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$' })
            Assert-True ($matchingRows.Count -eq 1) 'R13B alias mapping cardinality changed.'
            $mappedTarget = [regex]::Match($matchingRows[0], '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$').Groups[1].Value.Trim().TrimEnd('\')
            Assert-True ($mappedTarget.Equals(([string]$entry.sourceRoot).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) "R13B alias target changed: $caseId"
            $bfAliasPath = Join-WindowsPath 'X:\' ([string]$entry.expected.bfRelativePath)
            $dfAliasPath = Join-WindowsPath 'X:\' ([string]$entry.expected.dfRelativePath)
            foreach ($sourcePath in @($bfAliasPath,$dfAliasPath)) {
                Assert-True (Test-Path -LiteralPath $sourcePath -PathType Leaf) "R13B alias source absent: $caseId"
                Assert-True ([int64](Get-Item -LiteralPath $sourcePath).Length -eq [int64]$entry.sourceBytes) "R13B alias source byte metadata changed: $caseId"
            }
            $bfSha256 = Get-Sha256 $bfAliasPath
            $dfSha256 = Get-Sha256 $dfAliasPath
            $sourcePairSha256 = Get-TextSha256 ("BF=$bfSha256`nDF=$dfSha256`n")

            $runtimeJob = [ordered]@{
                schema = 'argos_opencv_scribe_alphabet_crop_job_v1'
                revision = $revision
                jobId = 'R13B_' + $caseId
                caseId = $caseId
                physicalIdentity = [string]$entry.expected.physicalIdentity
                purpose = [string]$entry.expected.purpose
                canonicalTruth = [string]$entry.expected.confirmedScribe
                targetPositions = @($entry.expected.targetPositions | ForEach-Object { [ordered]@{position=[int]$_.position;label=[string]$_.label} })
                inputMode = 'DEVELOPMENT_AUTO_LOCALIZED_WHOLE_IMAGE'
                inputs = [ordered]@{
                    bf = [ordered]@{path=$bfAliasPath;canonicalProvenancePath=(Join-WindowsPath ([string]$entry.expected.aliasAnchorCanonicalPath) ([string]$entry.expected.bfRelativePath));ioPathClass='SHORT_DOS_DEVICE_ALIAS_HASH_PINNED_READ_ONLY';aliasName='X:';aliasAnchorCanonicalPath=[string]$entry.expected.aliasAnchorCanonicalPath;bytes=[int64]$entry.sourceBytes;sha256=$bfSha256}
                    df = [ordered]@{path=$dfAliasPath;canonicalProvenancePath=(Join-WindowsPath ([string]$entry.expected.aliasAnchorCanonicalPath) ([string]$entry.expected.dfRelativePath));ioPathClass='SHORT_DOS_DEVICE_ALIAS_HASH_PINNED_READ_ONLY';aliasName='X:';aliasAnchorCanonicalPath=[string]$entry.expected.aliasAnchorCanonicalPath;bytes=[int64]$entry.sourceBytes;sha256=$dfSha256}
                }
                references = [ordered]@{
                    manifestPath = Join-Path $workRoot 'refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
                    manifestSha256 = $referenceManifestSha256
                    excludedPhysicalIdentity = [string]$entry.expected.physicalIdentity
                    roots = @(
                        [ordered]@{relativePrefix='glyphs';path=(Join-Path $workRoot 'refs\glyphs')},
                        [ordered]@{relativePrefix='glyphs_v5_confirmed_20260806';path=(Join-Path $workRoot 'refs\glyphs_v5_confirmed_20260806')}
                    )
                }
                search = [ordered]@{
                    expectedRegions = @()
                    boundedExceptionSearch = $true
                    maximumWorkingDimension = [int]$configuration.automaticLocalization.maximumWorkingDimension
                    maximumCandidates = [int]$configuration.automaticLocalization.maximumCandidates
                    orientationStepDegrees = [int]$configuration.automaticLocalization.orientationStepDegrees
                    developmentMaximumRegions = [int]$configuration.automaticLocalization.developmentMaximumRegions
                    developmentMinimumLocalizationScore = [double]$configuration.automaticLocalization.developmentMinimumLocalizationScore
                    developmentMinimumBandWidthPixels = [int]$configuration.automaticLocalization.developmentMinimumBandWidthPixels
                    developmentOcrRegionWidthPixels = [int]$configuration.automaticLocalization.developmentOcrRegionWidthPixels
                    developmentOcrRegionHeightPixels = [int]$configuration.automaticLocalization.developmentOcrRegionHeightPixels
                    developmentMinimumObservedHeightRatio = [double]$configuration.automaticLocalization.developmentMinimumObservedHeightRatio
                    developmentMinimumObservedWidthRatio = [double]$configuration.automaticLocalization.developmentMinimumObservedWidthRatio
                    developmentMaximumObservedWidthRatio = [double]$configuration.automaticLocalization.developmentMaximumObservedWidthRatio
                }
                blobGrid = [ordered]@{
                    minimumDotSize = [double]$configuration.blobGrid.minimumDotSize
                    maximumDotSize = [double]$configuration.blobGrid.maximumDotSize
                    maximumPairedRegionsEvaluated = [int]$configuration.blobGrid.maximumPairedRegionsEvaluated
                    directions = @($configuration.blobGrid.directions | ForEach-Object { [string]$_ })
                }
                outputRoot = $caseOutput
                runtimeBinding = [ordered]@{requestId=$requestId;runtimeInstallationSha256=$runtimeInstallationSha256;liveRuntimeInstallationSha256=$liveRuntimeInstallationSha256;referenceBundleSha256=$referenceBundleSha256;sourcePairSha256=$sourcePairSha256;finalOutputRoot=$finalCaseOutput;sourceHashesCompletedBeforeProviderStart=$true}
                authority = [ordered]@{reviewOnly=$true;automaticIdentityAuthority=$false;automaticReferenceAdmissionAllowed=$false;trainingAuthorized=$false;trainingEligible=$false;trainingExecuted=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mayClearHolds=$false;sourceMutationAllowed=$false;sourceDeletionAllowed=$false;taskOrProcessRestartAllowed=$false;providerActivationAllowed=$false;retryAuthorized=$false}
            }
            Write-JsonNew $runtimeJobPath $runtimeJob 32
            $runtimeJobSha256 = Get-Sha256 $runtimeJobPath

            $providerRun = Invoke-BoundedPython -Python $pythonPath -Provider (Join-Path $workRoot 'R13B.py') -Job $runtimeJobPath -OutputRoot $caseOutput -TimeoutSeconds 600
            Assert-True ([bool]$providerRun.started) "R13B provider launch failed: $caseId`: $($providerRun.launchError)"
            Assert-True (-not [bool]$providerRun.timedOut) "R13B provider timed out: $caseId"
            Assert-True ($null -ne $providerRun.exitCode -and [int]$providerRun.exitCode -in @(0,2)) "R13B provider exit code changed: $caseId`: $($providerRun.stderr)"
            Assert-True (Test-Path -LiteralPath $caseResultPath -PathType Leaf) "R13B CASE_RESULT absent: $caseId"

            $caseResult = Get-Content -Raw -LiteralPath $caseResultPath | ConvertFrom-Json
            Assert-True ([string]$caseResult.schema -eq 'argos_opencv_scribe_alphabet_crop_case_result_v1' -and [string]$caseResult.revision -eq $providerRevision) "R13B case-result contract changed: $caseId"
            Assert-True ([string]$caseResult.caseId -eq $caseId -and [string]$caseResult.physicalIdentity -eq [string]$entry.expected.physicalIdentity) "R13B case-result identity changed: $caseId"
            Assert-Authority $caseResult.authority "case result $caseId.authority" @('automaticIdentityAuthority','automaticReferenceAdmissionAllowed','trainingAuthorized','trainingEligible','trainingExecuted','xmlEligible','productionEligible','productionRoutingEnabled','mayClearHolds')
            Assert-True ([string]$caseResult.provenance.sources.bf.sha256 -eq $bfSha256 -and [string]$caseResult.provenance.sources.df.sha256 -eq $dfSha256) "R13B case-result source hashes changed: $caseId"
            Assert-True ([string]$caseResult.provenance.sourcePairSha256 -eq $sourcePairSha256) "R13B case-result source-pair hash changed: $caseId"
            $artifactRows = @($caseResult.artifacts)
            Assert-True ($artifactRows.Count -le 15) "R13B artifact count exceeds contract: $caseId"
            if ($artifactRows.Count -eq 0) {
                Assert-True ([string]$caseResult.state -like 'HOLD_*') "R13B empty-artifact result is not a hold: $caseId"
                if ([int]$providerRun.exitCode -eq 2 -and $null -ne $caseResult.PSObject.Properties['failure']) { $caseDetail = Get-BoundedText ([string]$caseResult.failure.detail) 4096 }
            }
            else {
                Assert-True ([int]$providerRun.exitCode -eq 0) "R13B nonzero provider exit returned artifacts: $caseId"
                $gridRows = @($artifactRows | Where-Object { [string]$_.kind -eq 'ORIENTED_GRID' })
                $cellRows = @($artifactRows | Where-Object { [string]$_.kind -eq 'AUDIT_CELL' })
                $targetRows = @($artifactRows | Where-Object { [string]$_.kind -eq 'TARGET_GLYPH' })
                Assert-True ($gridRows.Count -eq 1 -and $cellRows.Count -eq 12 -and $targetRows.Count -eq @($entry.expected.targetPositions).Count) "R13B evaluable artifact cardinality changed: $caseId"
                Assert-True ([string]$gridRows[0].relativePath -eq 'selected_grid.png') "R13B grid filename changed: $caseId"
                Assert-True ([string]$gridRows[0].sourceChannel -eq 'BF_DF_DERIVED' -and [string]$gridRows[0].sourceSha256 -eq $sourcePairSha256) "R13B grid source binding changed: $caseId"
                $gridSha256 = [string]$gridRows[0].sha256
                for ($position = 1; $position -le 12; $position++) {
                    $label = ([string]$entry.expected.confirmedScribe).Substring($position - 1, 1)
                    $expectedRelative = 'cells/P{0:D2}_{1}.png' -f $position,$label
                    $cell = @($cellRows | Where-Object { [string]$_.relativePath -eq $expectedRelative })
                    Assert-True ($cell.Count -eq 1 -and [string]$cell[0].sourceChannel -eq 'SELECTED_GRID' -and [string]$cell[0].sourceSha256 -eq $gridSha256) "R13B cell lineage changed: $caseId/P$position"
                }
                foreach ($targetPosition in @($entry.expected.targetPositions)) {
                    $expectedRelative = 'targets/P{0:D2}_{1}.png' -f [int]$targetPosition.position,[string]$targetPosition.label
                    $cellRelative = 'cells/P{0:D2}_{1}.png' -f [int]$targetPosition.position,[string]$targetPosition.label
                    $cell = @($cellRows | Where-Object { [string]$_.relativePath -eq $cellRelative })
                    $target = @($targetRows | Where-Object { [string]$_.relativePath -eq $expectedRelative })
                    Assert-True ($target.Count -eq 1 -and [string]$target[0].sourceChannel -eq 'AUDIT_CELL' -and [string]$target[0].sourceSha256 -eq [string]$cell[0].sha256) "R13B target lineage changed: $caseId/$($targetPosition.label)"
                }
                foreach ($artifact in $artifactRows) {
                    Assert-Sha256Text ([string]$artifact.sha256) "$caseId artifact"
                    Assert-Sha256Text ([string]$artifact.sourceSha256) "$caseId artifact source"
                    $artifactPath = Get-SafeArtifactPath $caseOutput ([string]$artifact.relativePath)
                    Assert-True (Test-Path -LiteralPath $artifactPath -PathType Leaf) "R13B artifact absent: $caseId/$($artifact.relativePath)"
                    Assert-True ((Get-Sha256 $artifactPath) -eq [string]$artifact.sha256) "R13B artifact hash changed: $caseId/$($artifact.relativePath)"
                }
            }
            $declaredPaths = @($artifactRows | ForEach-Object { ([string]$_.relativePath).Replace('/', '\') })
            $actualFiles = @(Get-ChildItem -LiteralPath $caseOutput -Recurse -File -ErrorAction Stop)
            Assert-True ($actualFiles.Count -le 16) "R13B case file count exceeds contract: $caseId"
            foreach ($file in $actualFiles) {
                Assert-True ($file.Extension -in @('.json','.png')) "R13B forbidden case output type: $caseId/$($file.Name)"
                Assert-True ([int64]$file.Length -le $maximumBundleBytes) "R13B case output exceeds bundle bound: $caseId/$($file.Name)"
                if (-not $file.FullName.Equals($caseResultPath, [StringComparison]::OrdinalIgnoreCase)) {
                    $relative = $file.FullName.Substring($caseOutput.TrimEnd('\').Length + 1)
                    Assert-True ($declaredPaths -contains $relative) "R13B undeclared case output: $caseId/$relative"
                }
            }
            $caseState = [string]$caseResult.state
            $providerResultAccepted = $true
            $pixelsDecodedByOpenCv = ($artifactRows.Count -gt 0)
        }
        catch {
            $caseDetail = Get-BoundedText $_.Exception.Message 4096
            if ((Test-Path -LiteralPath $caseOutput) -or (Test-Path -LiteralPath $caseOutputPartial)) {
                [void](New-Item -ItemType Directory -Path $caseAttemptQuarantine)
                if (Test-Path -LiteralPath $caseOutput) { Move-Item -LiteralPath $caseOutput -Destination (Join-Path $caseAttemptQuarantine 'committed') -ErrorAction Stop }
                if (Test-Path -LiteralPath $caseOutputPartial) { Move-Item -LiteralPath $caseOutputPartial -Destination (Join-Path $caseAttemptQuarantine 'partial') -ErrorAction Stop }
                $attemptQuarantined = $true
            }
            [void](New-Item -ItemType Directory -Path $caseOutput)
            $failureSources = [ordered]@{
                bf = [ordered]@{sha256=$bfSha256;bytes=[int64]$entry.sourceBytes}
                df = [ordered]@{sha256=$dfSha256;bytes=[int64]$entry.sourceBytes}
            }
            Write-JsonNew $caseResultPath ([ordered]@{
                schema='argos_opencv_scribe_alphabet_crop_case_result_v1';revision=$providerRevision;createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_R13B_CASE_LAUNCH_FAILURE';caseId=$caseId;physicalIdentity=[string]$entry.expected.physicalIdentity;purpose=[string]$entry.expected.purpose;canonicalTruth=[string]$entry.expected.confirmedScribe;detail=$caseDetail
                provenance=[ordered]@{sources=$failureSources;sourcePairSha256=$sourcePairSha256;sourceHashesCompletedBeforeProviderStart=(-not [string]::IsNullOrWhiteSpace($sourcePairSha256))}
                artifacts=@();authority=[ordered]@{reviewOnly=$true;automaticIdentityAuthority=$false;automaticReferenceAdmissionAllowed=$false;trainingAuthorized=$false;trainingEligible=$false;trainingExecuted=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;mayClearHolds=$false}
            }) 16
            $caseState = 'HOLD_R13B_CASE_LAUNCH_FAILURE'
        }
        finally {
            if ($aliasCreated) {
                $removeOutput = & $substPath 'X:' '/D' 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0 -or (Test-Path -LiteralPath 'X:\')) { $aliasCleanupFailure = 'R13B X: alias removal failed: ' + $removeOutput.Trim() }
                $aliasCreated = $false
            }
        }
        Assert-True ([string]::IsNullOrWhiteSpace($aliasCleanupFailure)) $aliasCleanupFailure
        $caseResultSha256 = if (Test-Path -LiteralPath $caseResultPath -PathType Leaf) { Get-Sha256 $caseResultPath } else { '' }
        $caseRows.Add([pscustomobject]@{
            caseId=$caseId;physicalIdentity=[string]$entry.expected.physicalIdentity;purpose=[string]$entry.expected.purpose;state=$caseState;detail=$caseDetail
            bfSha256=$bfSha256;dfSha256=$dfSha256;sourcePairSha256=$sourcePairSha256;runtimeJobPath=$runtimeJobPath;runtimeJobSha256=$runtimeJobSha256;attemptQuarantined=$attemptQuarantined;attemptQuarantinePath=if ($attemptQuarantined) {$caseAttemptQuarantine} else {''};caseResultPath=(Join-Path $finalCaseOutput 'CASE_RESULT.json');caseResultSha256=$caseResultSha256
            providerStarted=if ($null -eq $providerRun) {$false} else {[bool]$providerRun.started};providerTimedOut=if ($null -eq $providerRun) {$false} else {[bool]$providerRun.timedOut};providerExitCode=if ($null -eq $providerRun) {$null} else {$providerRun.exitCode}
            providerProcessCompleted=if ($null -eq $providerRun) {$false} else {[bool]$providerRun.started -and -not [bool]$providerRun.timedOut -and $null -ne $providerRun.exitCode -and [string]::IsNullOrWhiteSpace([string]$providerRun.launchError)}
            providerCompleted=$providerResultAccepted;pixelsDecodedByOpenCv=$pixelsDecodedByOpenCv
            providerStdoutSha256=if ($null -eq $providerRun) {Get-TextSha256 ''} else {$providerRun.stdoutSha256};providerStderrSha256=if ($null -eq $providerRun) {Get-TextSha256 ''} else {$providerRun.stderrSha256}
        })
    }

    Assert-XAliasAbsent $substPath
    $processorAfter = @(Get-ProcessorRows)
    $processorAfterJson = if ($processorAfter.Count -eq 0) { '[]' } else { [string]($processorAfter | ConvertTo-Json -Compress -Depth 6) }
    $processorAfterSha256 = Get-TextSha256 $processorAfterJson
    Assert-True ($processorAfterJson -ceq $processorBeforeJson) 'R13B protected processor rows changed.'
    $failureCount = @($caseRows.ToArray() | Where-Object { [string]$_.state -like 'HOLD_R13B_CASE_LAUNCH_FAILURE' }).Count
    $providerCompletedCount = @($caseRows.ToArray() | Where-Object { [bool]$_.providerCompleted }).Count
    $pixelsDecodedCaseCount = @($caseRows.ToArray() | Where-Object { [bool]$_.pixelsDecodedByOpenCv }).Count
    $sourceHashesCompletedCount = @($caseRows.ToArray() | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.sourcePairSha256) }).Count
    $batchGatePath = Join-Path $outputPartial 'BATCH_GATE.json'
    $executionPath = Join-Path $outputPartial 'EXECUTION.json'
    $batchGate = [ordered]@{
        schema='argos_opencv_scribe_r13b_batch_gate_v1';revision=$revision;createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_BATCH_COMPLETE';disposition='PENDING_GATE';requestId=$requestId;rehearsal=[bool]$Rehearsal
        caseCount=$caseRows.Count;caseLaunchFailureCount=$failureCount;providerCompletedCount=$providerCompletedCount;pixelsDecodedCaseCount=$pixelsDecodedCaseCount;sourceHashesCompletedCount=$sourceHashesCompletedCount;cases=$caseRows.ToArray();invocationSha256=$invocationSha256;runtimeInstallationSha256=$runtimeInstallationSha256;liveRuntimeInstallationSha256=$liveRuntimeInstallationSha256;referenceBundleSha256=$referenceBundleSha256;referenceManifestSha256=$referenceManifestSha256
        sourceHashBeforeOpenCvDecodeRequired=$true;maximumConcurrentProviderChildren=1;automaticRetryAllowed=$false;caseFailureStopsBatch=$false;sourceAliasRemoved=$true;processorRowsBeforeSha256=$processorBeforeSha256;processorRowsAfterSha256=$processorAfterSha256
        sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;holdsCleared=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    }
    Write-JsonNew $batchGatePath $batchGate 32
    Write-JsonNew $executionPath ([ordered]@{
        schema='argos_opencv_scribe_r13b_execution_v1';revision=$revision;createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R13B_EXECUTION';requestId=$requestId;computerName=$env:COMPUTERNAME;rehearsal=[bool]$Rehearsal
        workRoot=$workRoot;outputRoot=$outputRoot;returnBundle=$bundlePath;batchGateSha256=Get-Sha256 $batchGatePath;caseCount=$caseRows.Count;caseLaunchFailureCount=$failureCount;providerCompletedCount=$providerCompletedCount;pixelsDecodedCaseCount=$pixelsDecodedCaseCount;sourceHashesCompletedCount=$sourceHashesCompletedCount;processorRowsBefore=$processorBefore;processorRowsAfter=$processorAfter
        sourceImageBytesRead=($sourceHashesCompletedCount -gt 0);sourceHashingPerformed=($sourceHashesCompletedCount -gt 0);pixelsDecodedByOpenCv=($pixelsDecodedCaseCount -gt 0);sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    }) 24
    Move-Item -LiteralPath $outputPartial -Destination $outputRoot -ErrorAction Stop
    $outputPartialCreated = $false

    [IO.Compression.ZipFile]::CreateFromDirectory($outputRoot, $bundlePartial, [IO.Compression.CompressionLevel]::Optimal, $false)
    $bundleBytes = [int64](Get-Item -LiteralPath $bundlePartial).Length
    Assert-True ($bundleBytes -le $maximumBundleBytes) "R13B return bundle exceeds $maximumBundleBytes bytes."
    $bundleSha256 = Get-Sha256 $bundlePartial
    Move-Item -LiteralPath $bundlePartial -Destination $bundlePath -ErrorAction Stop
    $bundleData = [IO.File]::ReadAllBytes($bundlePath)
    $bundleBase64 = [Convert]::ToBase64String($bundleData)
    Assert-True ($bundleBase64.Length -le $maximumBundleBase64Characters) "R13B return Base64 exceeds $maximumBundleBase64Characters characters."
    [ordered]@{
        schema='argos_opencv_scribe_r13b_maintenance_envelope_v1';revision=$revision;state='PASS_R13B_SIGNED_RETURN_READY';requestId=$requestId;rehearsal=[bool]$Rehearsal
        bundleBase64=$bundleBase64;bundleSha256=$bundleSha256;bundleBytes=$bundleBytes;bundleBase64Characters=$bundleBase64.Length;caseCount=$caseRows.Count;caseLaunchFailureCount=$failureCount;providerCompletedCount=$providerCompletedCount
        automaticRetryAllowed=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;holdsCleared=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    } | ConvertTo-Json -Compress -Depth 8
}
catch {
    if ($workPartialCreated -and (Test-Path -LiteralPath $workPartial) -and -not (Test-Path -LiteralPath $workFailed)) {
        Move-Item -LiteralPath $workPartial -Destination $workFailed -ErrorAction SilentlyContinue
    }
    throw
}
