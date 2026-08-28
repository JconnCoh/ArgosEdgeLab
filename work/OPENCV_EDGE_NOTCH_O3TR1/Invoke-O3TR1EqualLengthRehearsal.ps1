[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$entryPointPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($entryPointPath)) {
    throw 'Unable to resolve the rehearsal entry-point path.'
}

if ($Preflight.IsPresent -eq $Gate.IsPresent) {
    throw 'Select exactly one of -Preflight or -Gate.'
}

function Get-Sha256File {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Read-BoundedJson {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][int]$MaximumBytes
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "JSON file is absent: $Path"
    }
    $item = Get-Item -LiteralPath $Path
    if ($item.Length -gt $MaximumBytes) {
        throw "JSON file exceeds $MaximumBytes bytes: $Path"
    }
    $bytes = [IO.File]::ReadAllBytes($item.FullName)
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    $text = $utf8.GetString($bytes).TrimStart([char]0xFEFF)
    return ($text | ConvertFrom-Json)
}

function Resolve-ProjectFile {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ([IO.Path]::IsPathRooted($RelativePath)) {
        throw "Project file path must be relative: $RelativePath"
    }
    $resolved = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $RelativePath.Replace('/', '\')))
    $prefix = $ProjectRoot.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Project file escapes the project root: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Project file is absent: $RelativePath"
    }
    return $resolved
}

function Resolve-ProjectOutput {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath
    )
    if ([IO.Path]::IsPathRooted($RelativePath)) {
        throw "Project output path must be relative: $RelativePath"
    }
    $resolved = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $RelativePath.Replace('/', '\')))
    $prefix = $ProjectRoot.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Project output escapes the project root: $RelativePath"
    }
    $parent = Split-Path -Parent $resolved
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Project output parent is absent: $parent"
    }
    return $resolved
}

function Get-TransportMetrics {
    param(
        [Parameter(Mandatory = $true)][string]$CommandSource,
        [Parameter(Mandatory = $true)][string]$ExpectedComputerName,
        [Parameter(Mandatory = $true)][int]$MaximumResultCharacters
    )
    $nonce = '00000000000000000000000000000000'
    $transportCommand = @(
        "try{if(`$env:COMPUTERNAME-ne'$ExpectedComputerName'){throw'Wrong computer'};"
        "`$x=[string]((&{$CommandSource}|Out-String -Width 240));`$t=`$x.Length-gt$MaximumResultCharacters;"
        "if(`$t){`$x=`$x.Substring(0,$MaximumResultCharacters)};"
        "`$d=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(`$x));"
        "('ARGOS_JBOD_RESULT|$nonce|PASS|'+`$t+'|'+`$d)|clip.exe}"
        "catch{`$x=[string]`$_.Exception.Message;if(`$x.Length-gt$MaximumResultCharacters){`$x=`$x.Substring(0,$MaximumResultCharacters)};"
        "`$d=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(`$x));"
        "('ARGOS_JBOD_RESULT|$nonce|FAIL|False|'+`$d)|clip.exe};exit"
    ) -join ''
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput(
        $transportCommand,
        [ref]$tokens,
        [ref]$errors
    )
    if (@($errors).Count -ne 0) {
        throw "Constructed transport wrapper does not parse: $($errors[0].Message)"
    }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($transportCommand))
    $typed = 'powershell.exe -NoProfile -EncodedCommand ' + $encoded + ';exit'
    return [pscustomobject]@{
        commandSourceCharacters = $CommandSource.Length
        transportCommandCharacters = $transportCommand.Length
        encodedCommandCharacters = $encoded.Length
        completePastedCommandCharacters = $typed.Length
    }
}

function Assert-TransportMetrics {
    param(
        [Parameter(Mandatory = $true)][object]$Observed,
        [Parameter(Mandatory = $true)][object]$Expected,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $names = @(
        'commandSourceCharacters',
        'transportCommandCharacters',
        'encodedCommandCharacters',
        'completePastedCommandCharacters'
    )
    foreach ($name in $names) {
        if (-not ($Expected.PSObject.Properties.Name -contains $name)) {
            throw "$Label expected metrics omit $name."
        }
        if ([int]$Observed.$name -ne [int]$Expected.$name) {
            throw "$Label metric $name changed: observed $($Observed.$name), expected $($Expected.$name)."
        }
    }
}

function Get-RehearsalPlan {
    $manifestPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
    $manifest = Read-BoundedJson -Path $manifestPath -MaximumBytes 65536
    if ([string]$manifest.schema -ne 'argos_o3tr1_equal_length_invocation_v1') {
        throw "Unexpected invocation schema: $($manifest.schema)"
    }
    $projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd('\')
    if ($projectRoot -ne 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab') {
        throw "Unexpected project root: $projectRoot"
    }
    $selfPath = [IO.Path]::GetFullPath($entryPointPath)
    $selfHash = Get-Sha256File -Path $selfPath
    if ($selfHash -ne [string]$manifest.rehearsalWrapperSha256) {
        throw "Rehearsal wrapper hash changed: $selfHash"
    }
    $runnerPath = [IO.Path]::GetFullPath([string]$manifest.directRunnerPath)
    if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) {
        throw "Direct runner is absent: $runnerPath"
    }
    $runnerHash = Get-Sha256File -Path $runnerPath
    if ($runnerHash -ne [string]$manifest.directRunnerSha256) {
        throw "Direct runner hash changed: $runnerHash"
    }
    $commandPath = Resolve-ProjectFile -ProjectRoot $projectRoot -RelativePath ([string]$manifest.rehearsalCommandPath)
    $referencePath = Resolve-ProjectFile -ProjectRoot $projectRoot -RelativePath ([string]$manifest.referenceCommandPath)
    $commandHash = Get-Sha256File -Path $commandPath
    $referenceHash = Get-Sha256File -Path $referencePath
    if ($commandHash -ne [string]$manifest.rehearsalCommandSha256) {
        throw "Rehearsal command hash changed: $commandHash"
    }
    if ($referenceHash -ne [string]$manifest.referenceCommandSha256) {
        throw "Reference command hash changed: $referenceHash"
    }
    $commandSource = [IO.File]::ReadAllText($commandPath)
    $referenceSource = [IO.File]::ReadAllText($referencePath)
    if ($commandSource.Length -ne [int]$manifest.rehearsalCommandCharacters) {
        throw "Rehearsal source length changed: $($commandSource.Length)"
    }
    if ($referenceSource.Length -ne [int]$manifest.referenceCommandCharacters) {
        throw "Reference source length changed: $($referenceSource.Length)"
    }
    if ($commandSource.Length -gt 2048) {
        throw "Rehearsal source exceeds the direct-control source bound: $($commandSource.Length)"
    }
    $runnerSource = [IO.File]::ReadAllText($runnerPath)
    $delayPattern = "Send-ControlVirtualKey\s+-VirtualKey\s+0x56\s+Start-Sleep\s+-Milliseconds\s+(?<delay>\d+)\s+\[Windows\.Forms\.SendKeys\]::SendWait\('\{ENTER\}'\)"
    $delayMatches = [regex]::Matches($runnerSource, $delayPattern)
    if ($delayMatches.Count -ne 1) {
        throw "Expected exactly one Invoke paste-to-Enter delay match; observed $($delayMatches.Count)."
    }
    $pasteDelay = [int]$delayMatches[0].Groups['delay'].Value
    if ($pasteDelay -ne [int]$manifest.pasteToEnterDelayMilliseconds) {
        throw "Paste-to-Enter delay changed: $pasteDelay"
    }
    $expectedComputerName = [string]$manifest.expectedComputerName
    $maximumResultCharacters = [int]$manifest.maximumResultCharacters
    $referenceMetrics = Get-TransportMetrics `
        -CommandSource $referenceSource `
        -ExpectedComputerName $expectedComputerName `
        -MaximumResultCharacters $maximumResultCharacters
    $rehearsalMetrics = Get-TransportMetrics `
        -CommandSource $commandSource `
        -ExpectedComputerName $expectedComputerName `
        -MaximumResultCharacters $maximumResultCharacters
    Assert-TransportMetrics `
        -Observed $referenceMetrics `
        -Expected $manifest.referenceMetrics `
        -Label 'Reference command'
    Assert-TransportMetrics `
        -Observed $rehearsalMetrics `
        -Expected $manifest.rehearsalMetrics `
        -Label 'Rehearsal command'
    if ($rehearsalMetrics.commandSourceCharacters -lt $referenceMetrics.commandSourceCharacters) {
        throw 'Rehearsal source is shorter than the failed observation source.'
    }
    if ($rehearsalMetrics.completePastedCommandCharacters -lt $referenceMetrics.completePastedCommandCharacters) {
        throw 'Rehearsal pasted command is shorter than the failed observation pasted command.'
    }
    if ($rehearsalMetrics.completePastedCommandCharacters -gt 8192) {
        throw 'Rehearsal pasted command exceeds the direct-control transport bound.'
    }
    $runnerCommands = @(
        Get-Command `
            -Name $runnerPath `
            -CommandType ExternalScript `
            -ErrorAction Stop
    )
    if ($runnerCommands.Count -ne 1) {
        throw "Expected one direct runner command; observed $($runnerCommands.Count)."
    }
    $runnerCommand = $runnerCommands[0]
    $requiredParameters = @(
        'Action',
        'CommandPath',
        'ExpectedComputerName',
        'TimeoutSeconds',
        'MaximumResultCharacters',
        'Preflight'
    )
    foreach ($requiredParameter in $requiredParameters) {
        if (-not $runnerCommand.Parameters.ContainsKey($requiredParameter)) {
            throw "Direct runner does not declare required parameter $requiredParameter."
        }
    }
    $runnerPreflightRows = @(
        & $runnerPath `
            -Action Invoke `
            -CommandPath $commandPath `
            -ExpectedComputerName $expectedComputerName `
            -TimeoutSeconds ([int]$manifest.timeoutSeconds) `
            -MaximumResultCharacters $maximumResultCharacters `
            -Preflight
    )
    $runnerPreflightText = @($runnerPreflightRows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    $runnerPreflight = $runnerPreflightText | ConvertFrom-Json
    if ([string]$runnerPreflight.state -ne 'PASS_ARGOS_JBOD_DIRECT_LOCAL_PREFLIGHT') {
        throw "Direct runner preflight did not pass: $($runnerPreflight.state)"
    }
    if ([string]$runnerPreflight.runnerSha256 -ne $runnerHash) {
        throw 'Direct runner preflight returned a different runner hash.'
    }
    if ([bool]$runnerPreflight.remoteInputSent -or [bool]$runnerPreflight.targetExecuted -or [bool]$runnerPreflight.mutationsPerformed) {
        throw 'Direct runner preflight reported an external action.'
    }
    $terminalGatePath = Resolve-ProjectOutput -ProjectRoot $projectRoot -RelativePath ([string]$manifest.terminalGatePath)
    if (Test-Path -LiteralPath $terminalGatePath) {
        throw "Terminal gate path already exists: $terminalGatePath"
    }
    return [pscustomobject]@{
        manifest = $manifest
        manifestPath = $manifestPath
        manifestSha256 = Get-Sha256File -Path $manifestPath
        projectRoot = $projectRoot
        selfPath = $selfPath
        selfSha256 = $selfHash
        runnerPath = $runnerPath
        runnerSha256 = $runnerHash
        commandPath = $commandPath
        commandSha256 = $commandHash
        referencePath = $referencePath
        referenceSha256 = $referenceHash
        pasteToEnterDelayMilliseconds = $pasteDelay
        referenceMetrics = $referenceMetrics
        rehearsalMetrics = $rehearsalMetrics
        terminalGatePath = $terminalGatePath
    }
}

$plan = Get-RehearsalPlan

if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3tr1_equal_length_preflight_v1'
        state = 'PASS_O3TR1_EQUAL_LENGTH_PREFLIGHT'
        artifactLifecycle = [string]$plan.manifest.artifactLifecycle
        invocationManifestSha256 = $plan.manifestSha256
        rehearsalWrapperSha256 = $plan.selfSha256
        directRunnerSha256 = $plan.runnerSha256
        rehearsalCommandSha256 = $plan.commandSha256
        referenceCommandSha256 = $plan.referenceSha256
        pasteToEnterDelayMilliseconds = $plan.pasteToEnterDelayMilliseconds
        referenceMetrics = $plan.referenceMetrics
        rehearsalMetrics = $plan.rehearsalMetrics
        rehearsalAtLeastReferenceLength = $true
        originalConsoleUntouched = $true
        freshConsoleRequired = $true
        remoteInputSent = $false
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 8
    return
}

if ([string]$plan.manifest.artifactLifecycle -ne 'FROZEN') {
    throw 'Gate execution requires artifactLifecycle FROZEN.'
}

$terminal = [ordered]@{
    schema = 'argos_o3tr1_equal_length_terminal_v1'
    revision = [string]$plan.manifest.revision
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'FAIL_O3TR1_EQUAL_LENGTH_REHEARSAL'
    invocationManifestSha256 = $plan.manifestSha256
    rehearsalWrapperSha256 = $plan.selfSha256
    directRunnerSha256 = $plan.runnerSha256
    rehearsalCommandSha256 = $plan.commandSha256
    referenceCommandSha256 = $plan.referenceSha256
    pasteToEnterDelayMilliseconds = $plan.pasteToEnterDelayMilliseconds
    referenceMetrics = $plan.referenceMetrics
    rehearsalMetrics = $plan.rehearsalMetrics
    originalConsoleUntouched = $true
    freshConsoleRequired = $true
    remoteInputAttempted = $false
    targetExecutionConfirmed = $false
    resultReturned = $false
    resultNonce = ''
    commandSha256 = ''
    resultTruncated = $null
    resultScalar = ''
    errorMessage = ''
    targetPersistentMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

try {
    $windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        throw "Windows PowerShell 5.1 is absent: $windowsPowerShell"
    }
    $terminal.remoteInputAttempted = $true
    $outputRows = @(
        & $windowsPowerShell `
            -NoProfile `
            -ExecutionPolicy Bypass `
            -File $plan.runnerPath `
            -Action Invoke `
            -CommandPath $plan.commandPath `
            -ExpectedComputerName ([string]$plan.manifest.expectedComputerName) `
            -TimeoutSeconds ([int]$plan.manifest.timeoutSeconds) `
            -MaximumResultCharacters ([int]$plan.manifest.maximumResultCharacters) 2>&1
    )
    $runnerExitCode = $LASTEXITCODE
    $outputText = @($outputRows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ($outputText.Length -gt 65536) {
        $outputText = $outputText.Substring(0, 65536)
    }
    if ($runnerExitCode -ne 0) {
        throw "Direct runner exited ${runnerExitCode}: $outputText"
    }
    $result = $outputText | ConvertFrom-Json
    if ([string]$result.schema -ne 'argos_jbod_direct_control_result_v1') {
        throw "Unexpected direct result schema: $($result.schema)"
    }
    if ([string]$result.state -ne 'PASS_EXACT_JBOD_DIRECT_COMMAND') {
        throw "Direct result did not pass: $($result.state)"
    }
    if ([string]$result.remoteState -ne 'PASS') {
        throw "Direct remote state did not pass: $($result.remoteState)"
    }
    if ([string]$result.computerName -ne [string]$plan.manifest.expectedComputerName) {
        throw "Direct result computer name mismatch: $($result.computerName)"
    }
    if ([string]$result.commandSha256 -ne $plan.commandSha256) {
        throw 'Direct result command hash mismatch.'
    }
    if ([bool]$result.truncated) {
        throw 'Fixed-scalar rehearsal result was truncated.'
    }
    if ([string]$result.nonce -notmatch '^[0-9a-f]{32}$') {
        throw 'Direct result nonce is malformed.'
    }
    $trimmedResult = ([string]$result.result).Trim()
    if ($trimmedResult -ne [string]$plan.manifest.expectedResultScalar) {
        throw "Fixed-scalar result mismatch: $trimmedResult"
    }
    $terminal.state = 'PASS_O3TR1_EQUAL_LENGTH_REHEARSAL'
    $terminal.targetExecutionConfirmed = $true
    $terminal.resultReturned = $true
    $terminal.resultNonce = [string]$result.nonce
    $terminal.commandSha256 = [string]$result.commandSha256
    $terminal.resultTruncated = [bool]$result.truncated
    $terminal.resultScalar = $trimmedResult
}
catch {
    $message = [string]$_.Exception.Message
    if ($message.Length -gt 4096) {
        $message = $message.Substring(0, 4096)
    }
    $terminal.errorMessage = $message
}
finally {
    $json = $terminal | ConvertTo-Json -Depth 10
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    $bytes = $utf8NoBom.GetBytes($json + [Environment]::NewLine)
    $stream = [IO.File]::Open(
        $plan.terminalGatePath,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

$terminal | ConvertTo-Json -Depth 10
if ([string]$terminal.state -ne 'PASS_O3TR1_EQUAL_LENGTH_REHEARSAL') {
    exit 1
}
