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
    throw 'Unable to resolve the O3TR2 entry-point path.'
}
if ($Preflight.IsPresent -eq $Gate.IsPresent) {
    throw 'Select exactly one of -Preflight or -Gate.'
}

function Get-DotNetSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Hash target is absent: $resolved"
    }
    $stream = [IO.File]::Open(
        $resolved,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::Read
    )
    try {
        $algorithm = [Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $algorithm.ComputeHash($stream)
            return ([BitConverter]::ToString($bytes).Replace('-', ''))
        }
        finally {
            $algorithm.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-TransportMetrics {
    param(
        [Parameter(Mandatory = $true)][string]$CommandSource,
        [Parameter(Mandatory = $true)][string]$ExpectedComputerName,
        [Parameter(Mandatory = $true)][int]$MaximumResultCharacters
    )
    $nonce = '00000000000000000000000000000000'
    $transport = @(
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
        $transport,
        [ref]$tokens,
        [ref]$errors
    )
    if (@($errors).Count -ne 0) {
        throw "Constructed transport wrapper does not parse: $($errors[0].Message)"
    }
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($transport))
    $typed = 'powershell.exe -NoProfile -EncodedCommand ' + $encoded + ';exit'
    return [pscustomobject]@{
        commandSourceCharacters = $CommandSource.Length
        transportCommandCharacters = $transport.Length
        encodedCommandCharacters = $encoded.Length
        completePastedCommandCharacters = $typed.Length
    }
}

function Assert-Metrics {
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

function Resolve-ExactFile {
    param(
        [Parameter(Mandatory = $true)][string]$ProjectRoot,
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)][string]$ExpectedSha256
    )
    if ([IO.Path]::IsPathRooted($RelativePath)) {
        throw "Expected a project-relative file path: $RelativePath"
    }
    $resolved = [IO.Path]::GetFullPath((Join-Path $ProjectRoot $RelativePath.Replace('/', '\')))
    $prefix = $ProjectRoot.TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "File escapes the project root: $RelativePath"
    }
    $observedSha256 = Get-DotNetSha256 -Path $resolved
    if ($observedSha256 -ne $ExpectedSha256) {
        throw "File hash changed for $RelativePath`: $observedSha256"
    }
    return $resolved
}

function Get-O3TR2Plan {
    $manifestPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
    if ((Get-Item -LiteralPath $manifestPath).Length -gt 65536) {
        throw 'O3TR2 invocation manifest exceeds 65,536 bytes.'
    }
    $manifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
    if ([string]$manifest.schema -ne 'argos_o3tr2_equal_length_invocation_v1') {
        throw "Unexpected O3TR2 invocation schema: $($manifest.schema)"
    }
    $projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd('\')
    if ($projectRoot -ne 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab') {
        throw "Unexpected project root: $projectRoot"
    }
    $selfPath = [IO.Path]::GetFullPath($entryPointPath)
    $selfSha256 = Get-DotNetSha256 -Path $selfPath
    if ($selfSha256 -ne [string]$manifest.entrypointSha256) {
        throw "O3TR2 entrypoint hash changed: $selfSha256"
    }
    $runnerPath = [IO.Path]::GetFullPath([string]$manifest.directRunnerPath)
    $runnerSha256 = Get-DotNetSha256 -Path $runnerPath
    if ($runnerSha256 -ne [string]$manifest.directRunnerSha256) {
        throw "Direct runner hash changed: $runnerSha256"
    }
    $commandPath = Resolve-ExactFile `
        -ProjectRoot $projectRoot `
        -RelativePath ([string]$manifest.rehearsalCommandPath) `
        -ExpectedSha256 ([string]$manifest.rehearsalCommandSha256)
    $referencePath = Resolve-ExactFile `
        -ProjectRoot $projectRoot `
        -RelativePath ([string]$manifest.referenceCommandPath) `
        -ExpectedSha256 ([string]$manifest.referenceCommandSha256)
    $commandSource = [IO.File]::ReadAllText($commandPath)
    $referenceSource = [IO.File]::ReadAllText($referencePath)
    if ($commandSource.Length -gt 2048) {
        throw "O3TR2 command source exceeds 2,048 characters: $($commandSource.Length)"
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
    Assert-Metrics -Observed $referenceMetrics -Expected $manifest.referenceMetrics -Label 'Reference'
    Assert-Metrics -Observed $rehearsalMetrics -Expected $manifest.rehearsalMetrics -Label 'O3TR2 rehearsal'
    if ($rehearsalMetrics.completePastedCommandCharacters -lt $referenceMetrics.completePastedCommandCharacters) {
        throw 'O3TR2 complete pasted command is shorter than the failed observation.'
    }
    if ($rehearsalMetrics.completePastedCommandCharacters -gt 8192) {
        throw 'O3TR2 complete pasted command exceeds the 8,192-character bound.'
    }
    $runnerSource = [IO.File]::ReadAllText($runnerPath)
    $pattern = "Send-ControlVirtualKey\s+-VirtualKey\s+0x56\s+Start-Sleep\s+-Milliseconds\s+(?<delay>\d+)\s+\[Windows\.Forms\.SendKeys\]::SendWait\('\{ENTER\}'\)"
    $matches = [regex]::Matches($runnerSource, $pattern)
    if ($matches.Count -ne 1) {
        throw "Expected one Invoke delay match; observed $($matches.Count)."
    }
    $delay = [int]$matches[0].Groups['delay'].Value
    if ($delay -ne [int]$manifest.pasteToEnterDelayMilliseconds) {
        throw "Paste-to-Enter delay changed: $delay"
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
    $requiredParameters = @(
        'Action',
        'CommandPath',
        'ExpectedComputerName',
        'TimeoutSeconds',
        'MaximumResultCharacters'
    )
    foreach ($requiredParameter in $requiredParameters) {
        if (-not $runnerCommands[0].Parameters.ContainsKey($requiredParameter)) {
            throw "Direct runner omits parameter $requiredParameter."
        }
    }
    $terminalGatePath = [IO.Path]::GetFullPath((Join-Path $projectRoot ([string]$manifest.terminalGatePath).Replace('/', '\')))
    $projectPrefix = $projectRoot + '\'
    if (-not $terminalGatePath.StartsWith($projectPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'O3TR2 terminal gate escapes the project root.'
    }
    if (Test-Path -LiteralPath $terminalGatePath) {
        throw "O3TR2 terminal gate already exists: $terminalGatePath"
    }
    return [pscustomobject]@{
        manifest = $manifest
        manifestPath = $manifestPath
        manifestSha256 = Get-DotNetSha256 -Path $manifestPath
        selfPath = $selfPath
        selfSha256 = $selfSha256
        runnerPath = $runnerPath
        runnerSha256 = $runnerSha256
        commandPath = $commandPath
        commandSha256 = [string]$manifest.rehearsalCommandSha256
        referenceSha256 = [string]$manifest.referenceCommandSha256
        referenceMetrics = $referenceMetrics
        rehearsalMetrics = $rehearsalMetrics
        pasteToEnterDelayMilliseconds = $delay
        terminalGatePath = $terminalGatePath
    }
}

$plan = Get-O3TR2Plan

if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3tr2_equal_length_preflight_v1'
        state = 'PASS_O3TR2_EQUAL_LENGTH_PREFLIGHT'
        artifactLifecycle = [string]$plan.manifest.artifactLifecycle
        invocationManifestSha256 = $plan.manifestSha256
        entrypointSha256 = $plan.selfSha256
        directRunnerSha256 = $plan.runnerSha256
        rehearsalCommandSha256 = $plan.commandSha256
        referenceCommandSha256 = $plan.referenceSha256
        pasteToEnterDelayMilliseconds = $plan.pasteToEnterDelayMilliseconds
        referenceMetrics = $plan.referenceMetrics
        rehearsalMetrics = $plan.rehearsalMetrics
        dotNetHashHelperUsed = $true
        originalConsoleUntouched = $true
        freshConsoleRequired = $true
        remoteInputSent = $false
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 8
    return
}

if ([string]$plan.manifest.artifactLifecycle -ne 'FROZEN') {
    throw 'O3TR2 gate requires artifactLifecycle FROZEN.'
}

$terminal = [ordered]@{
    schema = 'argos_o3tr2_equal_length_terminal_v1'
    revision = [string]$plan.manifest.revision
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'FAIL_O3TR2_EQUAL_LENGTH_REHEARSAL'
    invocationManifestSha256 = $plan.manifestSha256
    entrypointSha256 = $plan.selfSha256
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
    $rows = @(
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
    $exitCode = $LASTEXITCODE
    $text = @($rows | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    if ($text.Length -gt 65536) {
        $text = $text.Substring(0, 65536)
    }
    if ($exitCode -ne 0) {
        throw "Direct runner exited ${exitCode}: $text"
    }
    $result = $text | ConvertFrom-Json
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
        throw 'O3TR2 result was truncated.'
    }
    if ([string]$result.nonce -notmatch '^[0-9a-f]{32}$') {
        throw 'O3TR2 result nonce is malformed.'
    }
    $scalar = ([string]$result.result).Trim()
    if ($scalar -ne [string]$plan.manifest.expectedResultScalar) {
        throw "O3TR2 scalar mismatch: $scalar"
    }
    $terminal.state = 'PASS_O3TR2_EQUAL_LENGTH_REHEARSAL'
    $terminal.targetExecutionConfirmed = $true
    $terminal.resultReturned = $true
    $terminal.resultNonce = [string]$result.nonce
    $terminal.commandSha256 = [string]$result.commandSha256
    $terminal.resultTruncated = [bool]$result.truncated
    $terminal.resultScalar = $scalar
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
    $encoding = New-Object Text.UTF8Encoding($false)
    $bytes = $encoding.GetBytes($json + [Environment]::NewLine)
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
if ([string]$terminal.state -ne 'PASS_O3TR2_EQUAL_LENGTH_REHEARSAL') {
    exit 1
}
