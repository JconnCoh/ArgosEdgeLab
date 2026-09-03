#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$PackageLeafPreflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Sha([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Sha-Text([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Value)
        ([BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace('-', '')
    } finally {
        $algorithm.Dispose()
    }
}

function Get-BoundedTail([string]$Value, [int]$MaximumCharacters, [int]$MaximumBytes) {
    $tail = if ($Value.Length -le $MaximumCharacters) { $Value } else { $Value.Substring($Value.Length - $MaximumCharacters) }
    while ([Text.Encoding]::UTF8.GetByteCount($tail) -gt $MaximumBytes -and $tail.Length -gt 0) {
        $tail = $tail.Substring(1)
    }
    [ordered]@{
        value = $tail
        characters = $tail.Length
        bytes = [Text.Encoding]::UTF8.GetByteCount($tail)
        truncated = ($tail.Length -ne $Value.Length)
    }
}

function Assert-ChildArgument([string]$Value, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Value)) "O3F15L3 empty child argument: $Label"
    Require ($Value.IndexOfAny([char[]]@('"', "`r", "`n")) -lt 0) "O3F15L3 child argument contains a forbidden character: $Label"
}

function Invoke-OwnedPreflight(
    [string]$Python,
    [string]$Runner,
    [string]$WorkingDirectory,
    [int]$TimeoutSeconds,
    [int]$MaximumOutputBytes,
    [string]$FixtureMode
) {
    $arguments = @('-I', '-B', $Runner, 'PREFLIGHT')
    foreach ($value in @($Python, $WorkingDirectory) + $arguments) { Assert-ChildArgument $value 'PREFLIGHT' }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Python
    $start.Arguments = [string]::Join(' ', @($arguments | ForEach-Object { '"' + $_ + '"' }))
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $start.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $start.EnvironmentVariables['PYTHONUTF8'] = '1'
    if (-not [string]::IsNullOrWhiteSpace($FixtureMode)) {
        $start.EnvironmentVariables['ARGOS_O3F15L3_FIXTURE_MODE'] = $FixtureMode
    }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() 'O3F15L3 PREFLIGHT child did not start.'
    $processId = [int]$process.Id
    $startedUtc = $process.StartTime.ToUniversalTime().ToString('o')
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill() } catch { }
        $process.WaitForExit()
    }
    $stdout = [string]$stdoutTask.Result
    $stderr = [string]$stderrTask.Result
    $exitCode = [int]$process.ExitCode
    $process.Dispose()
    $stdoutBytes = [Text.Encoding]::UTF8.GetByteCount($stdout)
    $stderrBytes = [Text.Encoding]::UTF8.GetByteCount($stderr)
    Require (($stdoutBytes + $stderrBytes) -le $MaximumOutputBytes) 'O3F15L3 child output exceeded its frozen bound.'
    [ordered]@{
        processId = $processId
        startedUtc = $startedUtc
        timedOut = $timedOut
        exitCode = $exitCode
        stdout = $stdout
        stderr = $stderr
        stdoutBytes = $stdoutBytes
        stderrBytes = $stderrBytes
        stdoutSha256 = Sha-Text $stdout
        stderrSha256 = Sha-Text $stderr
        arguments = $arguments
        workingDirectory = $WorkingDirectory
        executable = $Python
    }
}

function Assert-FrozenContract([object]$Contract) {
    Require ([string]$Contract.schema -ceq 'argos_ocv03_o3f15l3_diagnostic_contract_v1') 'O3F15L3 contract schema changed.'
    Require ([string]$Contract.state -ceq 'FROZEN_FOR_BUILD') 'O3F15L3 contract is not frozen.'
    Require ([string]$Contract.expectedComputerName -ceq 'A1025645101') 'O3F15L3 target identity changed.'
    Require ([string]$Contract.runnerSha256 -ceq 'DCE1E1F3B42FBD38ED73FF7D346F19C3BAE013EE3003B3485E91A41DAF573C48') 'O3F15L3 runner pin changed.'
    Require ([string]$Contract.detectorSha256 -ceq 'B477C290EC9D3AE388BE4EE31049B2B8094F5F30FC6E0DD68AB4A03926EE4059') 'O3F15L3 detector pin changed.'
    Require ([string]$Contract.recoveryIntentSha256 -ceq '9863D76D28988595EDC11C8745B6E2C1263380FECABA1C26AFD65CAD1A9818C9') 'O3F15L3 recovery intent pin changed.'
    Require ([string]$Contract.recoveryIntentGateSha256 -ceq '4D0F8D767F509D150EFE1AAC5DFEFD9ADDB3AEAB23BBA4AA7259F45E9D4CE000') 'O3F15L3 recovery gate pin changed.'
    Require ([int]$Contract.maximumOwnedChildCount -eq 1 -and @($Contract.childArguments).Count -eq 4) 'O3F15L3 one-child contract changed.'
    Require ([string]::Join('|', @($Contract.childArguments)) -ceq '-I|-B|Run-O3F15FrontReconcile.py|PREFLIGHT') 'O3F15L3 exact child arguments changed.'
    Require (-not [bool]$Contract.selfTestAllowed -and -not [bool]$Contract.gateAllowed -and -not [bool]$Contract.runAllowed -and -not [bool]$Contract.imageBytesReadAllowed) 'O3F15L3 authority widened.'
    Require ([int]$Contract.maximumTailCharacters -eq 2000 -and [int]$Contract.maximumTailBytes -eq 8000) 'O3F15L3 diagnostic tail bound changed.'
}

function Assert-Payload([object]$Contract) {
    $records = @($Contract.payloadFiles)
    Require ($records.Count -eq 15) 'O3F15L3 payload cardinality changed.'
    Require (@($records.name | Sort-Object -Unique).Count -eq $records.Count) 'O3F15L3 payload names are not unique.'
    foreach ($record in $records) {
        $name = [string]$record.name
        Require (-not [string]::IsNullOrWhiteSpace($name) -and -not [IO.Path]::IsPathRooted($name) -and $name -notmatch '[\\/]' -and $name -notmatch '^\.') "O3F15L3 unsafe payload name: $name"
        $path = Join-Path $PSScriptRoot $name
        Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 package payload absent: $name"
        Require ((Sha $path) -ceq [string]$record.sha256) "O3F15L3 package payload changed: $name"
    }
    foreach ($name in @('Invoke-O3F15L3.ps1','O3F15L3DiagnosticFixture.py','Run-O3F15FrontReconcile.py','Test-O3F15FrontReconcile.py','Run-O3F8Staged.py','Run-O3F14Staged.py','FullPerimeterWaferTopologyOpenCvR11.py','OCV03_NotchReviewOpenCvV1.py')) {
        Require (@($records | Where-Object { [string]$_.name -ceq $name }).Count -eq 1) "O3F15L3 required payload absent: $name"
    }
    return $records
}

function Assert-Target([object]$Contract) {
    Require ([Environment]::MachineName -ceq [string]$Contract.expectedComputerName) 'O3F15L3 diagnostic reached the wrong computer.'
    Require (Test-Path -LiteralPath ([string]$Contract.sourceRoot) -PathType Container) 'O3F15L3 source root is absent.'
    foreach ($pin in @($Contract.targetPins)) {
        $path = [string]$pin.path
        Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 target pin is absent: $path"
        Require ((Sha $path) -ceq [string]$pin.sha256) "O3F15L3 target pin changed: $path"
    }
}

function Invoke-O3F15L3Main {
    Require (-not ($PackageLeafPreflight -and ($Preflight -or $Rehearsal -or -not [string]::IsNullOrWhiteSpace($InvocationManifest)))) 'O3F15L3 package-leaf preflight cannot be combined.'
    Require ($Rehearsal -or [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3F15L3 invocation manifest is rehearsal-only.'
    $contractPath = Join-Path $PSScriptRoot 'O3F15L3_DIAGNOSTIC_CONTRACT.json'
    Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'O3F15L3 diagnostic contract is absent.'
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Assert-FrozenContract $contract
    $payload = @(Assert-Payload $contract)

    if ($PackageLeafPreflight) {
        [ordered]@{
            schema = 'argos_ocv03_o3f15l3_package_leaf_preflight_v1'
            state = 'PASS_O3F15L3_EXACT_PACKAGED_DIAGNOSTIC_LEAVES'
            payloadPinCount = $payload.Count
            maximumOwnedChildCount = 1
            imageBytesRead = $false
            processStarted = $false
            mutationsPerformed = $false
            reviewOnly = $true
        } | ConvertTo-Json -Depth 6 -Compress
        return
    }

    $fixtureMode = ''
    if ($Rehearsal) {
        Require (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3F15L3 rehearsal requires an invocation manifest.'
        $invocation = Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw | ConvertFrom-Json
        Require ([string]$invocation.schema -ceq 'argos_ocv03_o3f15l3_rehearsal_invocation_v1') 'O3F15L3 rehearsal invocation schema changed.'
        $fixtureMode = [string]$invocation.fixtureMode
        Require ($fixtureMode -in @('PASS','NONZERO_BOTH','ZERO_STDERR','MALFORMED','TIMEOUT')) 'O3F15L3 rehearsal fixture mode changed.'
        $python = [IO.Path]::GetFullPath([string]$invocation.pythonPath)
        Require (Test-Path -LiteralPath $python -PathType Leaf) 'O3F15L3 rehearsal Python is absent.'
        Require ((Sha $python) -ceq [string]$invocation.pythonSha256) 'O3F15L3 rehearsal Python changed.'
        $runner = Join-Path $PSScriptRoot 'O3F15L3DiagnosticFixture.py'
        $timeoutSeconds = [int]$invocation.timeoutSeconds
        Require ($timeoutSeconds -ge 1 -and $timeoutSeconds -le 30) 'O3F15L3 rehearsal timeout is outside its bound.'
    } else {
        Assert-Target $contract
        $python = [string]$contract.runtimePath
        $runner = Join-Path $PSScriptRoot 'Run-O3F15FrontReconcile.py'
        $timeoutSeconds = [int]$contract.preflightTimeoutSeconds
    }

    if ($Preflight) {
        [ordered]@{
            schema = 'argos_ocv03_o3f15l3_target_preflight_v1'
            state = 'PASS_O3F15L3_TARGET_PREFLIGHT'
            rehearsal = [bool]$Rehearsal
            maximumOwnedChildCount = 1
            exactStage = 'PREFLIGHT'
            imageBytesRead = $false
            processStarted = $false
            mutationsPerformed = $false
            reviewOnly = $true
        } | ConvertTo-Json -Depth 6 -Compress
        return
    }

    $child = Invoke-OwnedPreflight $python $runner $PSScriptRoot $timeoutSeconds ([int]$contract.maximumChildOutputBytes) $fixtureMode
    $parsed = $null
    $parsedJson = $false
    $parsedSchema = $null
    $parsedState = $null
    $parsedMutations = $null
    try {
        $parsed = ([string]$child.stdout).Trim() | ConvertFrom-Json
        $parsedJson = $null -ne $parsed -and $parsed -is [System.Management.Automation.PSCustomObject]
    } catch { $parsedJson = $false }
    if ($parsedJson) {
        if ($null -ne $parsed.PSObject.Properties['schema']) { $parsedSchema = [string]$parsed.schema }
        if ($null -ne $parsed.PSObject.Properties['state']) { $parsedState = [string]$parsed.state }
        if ($null -ne $parsed.PSObject.Properties['mutationsPerformed']) { $parsedMutations = [bool]$parsed.mutationsPerformed }
    }
    $matchesExpected = $null -ne $parsedSchema -and $null -ne $parsedState -and $null -ne $parsedMutations -and $parsedSchema -ceq [string]$contract.expectedRunnerSchema -and $parsedState -ceq [string]$contract.expectedRunnerState -and -not $parsedMutations
    $childPassed = -not [bool]$child.timedOut -and [int]$child.exitCode -eq 0 -and [int]$child.stderrBytes -eq 0 -and $matchesExpected
    $stdoutTail = Get-BoundedTail ([string]$child.stdout) ([int]$contract.maximumTailCharacters) ([int]$contract.maximumTailBytes)
    $stderrTail = Get-BoundedTail ([string]$child.stderr) ([int]$contract.maximumTailCharacters) ([int]$contract.maximumTailBytes)
    [ordered]@{
        schema = 'argos_ocv03_o3f15l3_preflight_diagnostic_v1'
        state = 'COMPLETE_O3F15L3_PREFLIGHT_DIAGNOSTIC_CAPTURED'
        childOutcome = $(if ($childPassed) { 'PASS' } else { 'FAIL' })
        rehearsal = [bool]$Rehearsal
        childProcessId = [int]$child.processId
        childStartedUtc = [string]$child.startedUtc
        childTimedOut = [bool]$child.timedOut
        childExitCode = [int]$child.exitCode
        childExecutable = [string]$child.executable
        childArguments = @($child.arguments)
        childWorkingDirectory = [string]$child.workingDirectory
        stdoutBytes = [int]$child.stdoutBytes
        stdoutSha256 = [string]$child.stdoutSha256
        stdoutTail = [string]$stdoutTail.value
        stdoutTailCharacters = [int]$stdoutTail.characters
        stdoutTailBytes = [int]$stdoutTail.bytes
        stdoutTruncated = [bool]$stdoutTail.truncated
        stderrBytes = [int]$child.stderrBytes
        stderrSha256 = [string]$child.stderrSha256
        stderrTail = [string]$stderrTail.value
        stderrTailCharacters = [int]$stderrTail.characters
        stderrTailBytes = [int]$stderrTail.bytes
        stderrTruncated = [bool]$stderrTail.truncated
        parsedJsonObject = [bool]$parsedJson
        parsedSchema = $parsedSchema
        parsedState = $parsedState
        expectedRunnerResultMatched = [bool]$matchesExpected
        maximumOwnedChildCount = 1
        ownedChildCount = 1
        selfTestStarted = $false
        gateStarted = $false
        runStarted = $false
        detectorResultRootCreated = $false
        corpusStarted = $false
        imageBytesRead = $false
        sourceMutation = $false
        providerActivated = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8 -Compress
}

Invoke-O3F15L3Main
