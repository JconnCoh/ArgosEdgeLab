[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptPath = [IO.Path]::GetFullPath($PSCommandPath)
$sourceTemplateLiteralRoot = 'C:\ProgramData'

function Get-Sha256File([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($resolved)) { throw "Required file is absent: $resolved" }
    $stream = [IO.File]::OpenRead($resolved)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-ExactJson([string]$Path) {
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not [IO.File]::Exists($resolved)) { throw "JSON file is absent: $resolved" }
    $bytes = [IO.File]::ReadAllBytes($resolved)
    if ($bytes.Length -gt 65536) { throw "JSON file exceeds 65,536 bytes: $resolved" }
    return ([Text.Encoding]::UTF8.GetString($bytes) | ConvertFrom-Json -ErrorAction Stop)
}

function Test-PowerShellSource([string]$Path) {
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    return @($errors)
}

function Get-Plan {
    if ([bool]$Preflight -eq [bool]$Gate) { throw 'Specify exactly one of -Preflight or -Gate.' }
    $manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
    $manifest = Get-ExactJson -Path $manifestPath
    if ([string]$manifest.schema -ne 'argos_o3tc1_fresh_console_short_trigger_invocation_v1') {
        throw "Unexpected invocation schema: $($manifest.schema)"
    }
    if ([string]$manifest.artifactLifecycle -notin @('DRAFT','FROZEN')) { throw 'Invocation manifest lifecycle is invalid.' }
    if ($Gate -and [string]$manifest.artifactLifecycle -ne 'FROZEN') { throw 'Gate requires a FROZEN invocation manifest.' }
    if ([string]$manifest.entrypoint.path -ne 'work/OPENCV_EDGE_NOTCH_O3TC1/Invoke-O3TC1FreshConsoleShortTrigger.ps1') {
        throw 'Entrypoint path changed.'
    }
    if ((Get-Sha256File -Path $scriptPath) -ne [string]$manifest.entrypoint.sha256) {
        throw 'Entrypoint hash changed.'
    }
    $payloadPath = [IO.Path]::GetFullPath((Join-Path ([string]$manifest.projectRoot) ([string]$manifest.payload.path)))
    if ((Get-Sha256File -Path $payloadPath) -ne [string]$manifest.payload.sha256) { throw 'Payload hash changed.' }
    $payload = [IO.File]::ReadAllText($payloadPath)
    if ($payload.Length -ne [int]$manifest.payload.characters) { throw 'Payload character count changed.' }
    $payloadErrors = @(Test-PowerShellSource -Path $payloadPath)
    if ($payloadErrors.Count -ne 0) { throw "Payload parser error: $($payloadErrors[0].Message)" }
    if ([string]$manifest.expectedComputerName -ne 'A1025645101') { throw 'Expected computer name changed.' }
    if ([string]$manifest.rustDeskWindowTitle -ne '10.66.81.84') { throw 'RustDesk window title changed.' }
    if ([string]$manifest.typedHostnameGate -ne 'hostname|clip') { throw 'Typed hostname gate changed.' }
    if ([string]$manifest.typedPayloadTrigger -ne 'iex(gcb -r)') { throw 'Typed payload trigger changed.' }
    if ([int]$manifest.maximumTypedCharacters -ne 32) { throw 'Typed-character bound changed.' }
    if ([int]$manifest.timeoutSeconds -lt 30 -or [int]$manifest.timeoutSeconds -gt 180) { throw 'Timeout is outside 30..180 seconds.' }
    if ([int]$manifest.freshConsole.taskbarX -ne 337 -or [int]$manifest.freshConsole.taskbarY -ne 1118) {
        throw 'Fresh-console taskbar coordinates changed.'
    }
    if ([int]$manifest.freshConsole.fullScreenWidth -ne 1920 -or [int]$manifest.freshConsole.fullScreenHeight -ne 1200) {
        throw 'Verified full-screen dimensions changed.'
    }
    $terminalPath = [IO.Path]::GetFullPath((Join-Path ([string]$manifest.projectRoot) ([string]$manifest.terminalGatePath)))
    [pscustomobject]@{
        ManifestPath = $manifestPath
        Manifest = $manifest
        PayloadPath = $payloadPath
        Payload = $payload
        TerminalPath = $terminalPath
    }
}

$plan = Get-Plan
$requiredCommands = @('Get-CimInstance','Get-Process','Get-Clipboard','Set-Clipboard')
$commandEvidence = @($requiredCommands | ForEach-Object {
    $cmd = @(Get-Command -Name $_ -ErrorAction SilentlyContinue)
    [pscustomobject]@{ name = $_; available = ($cmd.Count -gt 0) }
})
if (@($commandEvidence | Where-Object { -not $_.available }).Count -ne 0) {
    throw 'One or more required local commands are unavailable.'
}

if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3tc1_fresh_console_short_trigger_preflight_v1'
        state = 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER_PREFLIGHT'
        artifactLifecycle = [string]$plan.Manifest.artifactLifecycle
        invocationManifestSha256 = Get-Sha256File -Path $plan.ManifestPath
        entrypointSha256 = Get-Sha256File -Path $scriptPath
        payloadSha256 = Get-Sha256File -Path $plan.PayloadPath
        payloadCharacters = $plan.Payload.Length
        typedHostnameGateCharacters = ([string]$plan.Manifest.typedHostnameGate).Length
        typedPayloadTriggerCharacters = ([string]$plan.Manifest.typedPayloadTrigger).Length
        nativeEnterKey = 'VK_RETURN_0x0D_KEYDOWN_KEYUP'
        completePasteRequired = $false
        fileBackedClipboardPayload = $true
        freshConsoleRequired = $true
        originalConsolesUntouched = $true
        sourceTemplateLiteralRoot = $sourceTemplateLiteralRoot
        commandEvidence = $commandEvidence
        remoteInputSent = $false
        targetExecuted = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 8
    return
}

if (Test-Path -LiteralPath $plan.TerminalPath) { throw "Terminal gate already exists: $($plan.TerminalPath)" }

Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ArgosO3TC1Native {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attachThread, uint attachToThread, bool attach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SetActiveWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@

function Set-ExactForeground([Diagnostics.Process]$Process) {
    $foregroundWindow = [ArgosO3TC1Native]::GetForegroundWindow()
    [uint32]$foregroundProcessId = 0
    $foregroundThread = [ArgosO3TC1Native]::GetWindowThreadProcessId($foregroundWindow,[ref]$foregroundProcessId)
    [uint32]$targetProcessId = 0
    $targetThread = [ArgosO3TC1Native]::GetWindowThreadProcessId($Process.MainWindowHandle,[ref]$targetProcessId)
    $currentThread = [ArgosO3TC1Native]::GetCurrentThreadId()
    $attachedForeground = $false
    $attachedTarget = $false
    try {
        if ($foregroundThread -ne $currentThread) {
            $attachedForeground = [ArgosO3TC1Native]::AttachThreadInput($currentThread,$foregroundThread,$true)
        }
        if ($targetThread -ne $currentThread -and $targetThread -ne $foregroundThread) {
            $attachedTarget = [ArgosO3TC1Native]::AttachThreadInput($currentThread,$targetThread,$true)
        }
        [void][ArgosO3TC1Native]::BringWindowToTop($Process.MainWindowHandle)
        [void][ArgosO3TC1Native]::SetActiveWindow($Process.MainWindowHandle)
        [void][ArgosO3TC1Native]::SetFocus($Process.MainWindowHandle)
        [void][ArgosO3TC1Native]::SetForegroundWindow($Process.MainWindowHandle)
    }
    finally {
        if ($attachedTarget) { [void][ArgosO3TC1Native]::AttachThreadInput($currentThread,$targetThread,$false) }
        if ($attachedForeground) { [void][ArgosO3TC1Native]::AttachThreadInput($currentThread,$foregroundThread,$false) }
    }
    Start-Sleep -Milliseconds 250
    if ([ArgosO3TC1Native]::GetForegroundWindow() -ne $Process.MainWindowHandle) {
        throw 'Exact RustDesk desktop did not become foreground; refusing input.'
    }
    foreach ($key in [byte[]](0xA0,0xA1,0xA2,0xA3,0xA4,0xA5,0x5B,0x5C)) {
        [ArgosO3TC1Native]::keybd_event($key,0,2,[UIntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 100
}

function Assert-FullScreen([Diagnostics.Process]$Process) {
    $rect = New-Object ArgosO3TC1Native+RECT
    [void][ArgosO3TC1Native]::GetWindowRect($Process.MainWindowHandle,[ref]$rect)
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    if ($rect.Left -ne 0 -or $rect.Top -ne 0 -or $width -ne 1920 -or $height -ne 1200) {
        throw "RustDesk is not in the verified full-screen layout: ${width}x${height}."
    }
}

function Open-FreshConsole([Diagnostics.Process]$Process) {
    Set-ExactForeground -Process $Process
    Assert-FullScreen -Process $Process
    [void][ArgosO3TC1Native]::SetCursorPos([int]$plan.Manifest.freshConsole.taskbarX,[int]$plan.Manifest.freshConsole.taskbarY)
    Start-Sleep -Milliseconds 250
    [ArgosO3TC1Native]::mouse_event(0x20,0,0,0,[UIntPtr]::Zero)
    [ArgosO3TC1Native]::mouse_event(0x40,0,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 750
    Set-ExactForeground -Process $Process
}

function Send-ShortLiteralKeys([string]$Text) {
    if ($Text.Length -gt [int]$plan.Manifest.maximumTypedCharacters) {
        throw "Typed text exceeds the frozen bound: $($Text.Length)"
    }
    $builder = New-Object Text.StringBuilder
    foreach ($character in $Text.ToCharArray()) {
        $escaped = switch ([string]$character) {
            '+' {'{+}'} '^' {'{^}'} '%' {'{%}'} '~' {'{~}'} '(' {'{(}'} ')' {'{)}'}
            '{' {'{{}'} '}' {'{}}'} default {[string]$character}
        }
        [void]$builder.Append($escaped)
    }
    [Windows.Forms.SendKeys]::SendWait($builder.ToString())
}

function Send-NativeEnter {
    [ArgosO3TC1Native]::keybd_event(0x0D,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [ArgosO3TC1Native]::keybd_event(0x0D,0,2,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 300
}

function Set-ClipboardExact([string]$Value) {
    $lastError = 'clipboard round-trip mismatch'
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        try {
            Set-Clipboard -Value $Value -ErrorAction Stop
            Start-Sleep -Milliseconds 75
            if ([string](Get-Clipboard -Raw -ErrorAction Stop) -eq $Value) { return }
        }
        catch { $lastError = $_.Exception.Message }
        Start-Sleep -Milliseconds 125
    }
    throw "Unable to acquire exact local clipboard: $lastError"
}

function Wait-Clipboard([scriptblock]$Predicate,[int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        Start-Sleep -Milliseconds 250
        $value = [string](Get-Clipboard -Raw -ErrorAction SilentlyContinue)
        if (& $Predicate $value) { return $value }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for exact O3TC1 clipboard evidence after $Seconds seconds."
}

function Write-CreateNewJson([string]$Path,[object]$Value) {
    if ([IO.File]::Exists($Path)) { throw "Create-new output already exists: $Path" }
    $json = $Value | ConvertTo-Json -Depth 16
    [IO.File]::WriteAllText($Path,($json + [Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}

$stage = 'LOCAL_WINDOW_INVENTORY'
$remoteInputAttempted = $false
$freshConsoleOpened = $false
$hostnameGatePassed = $false
$payloadTriggerSubmitted = $false
$resultReturned = $false
$terminalState = 'FAIL_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER'
$errorMessage = ''
$remoteResult = $null
try {
    $desktopPids = @(Get-CimInstance Win32_Process -Filter "Name='RustDesk.exe'" -ErrorAction Stop | Where-Object {
        [string]$_.CommandLine -match '(?i)\s--connect\s+10\.66\.81\.84(?:\s|$)' -and
        [string]$_.CommandLine -notmatch '(?i)\s--port-forward(?:\s|$)'
    } | Select-Object -ExpandProperty ProcessId)
    $matches = @(Get-Process RustDesk -ErrorAction SilentlyContinue | Where-Object {
        $desktopPids -contains [uint32]$_.Id -and $_.MainWindowHandle -ne 0 -and
        $_.MainWindowTitle -eq [string]$plan.Manifest.rustDeskWindowTitle
    })
    if ($matches.Count -ne 1) { throw "Expected one exact RustDesk desktop; observed $($matches.Count)." }
    $rustDesk = $matches[0]

    $stage = 'OPEN_DISPOSABLE_FRESH_CONSOLE'
    Open-FreshConsole -Process $rustDesk
    $freshConsoleOpened = $true

    $stage = 'TYPED_HOSTNAME_GATE'
    $hostMarker = 'O3TC1_HOST_GATE_PENDING_7D9332A9'
    Set-ClipboardExact -Value $hostMarker
    Set-ExactForeground -Process $rustDesk
    Send-ShortLiteralKeys -Text ([string]$plan.Manifest.typedHostnameGate)
    $remoteInputAttempted = $true
    Send-NativeEnter
    $hostRaw = Wait-Clipboard -Seconds 30 -Predicate {
        param($value) -not [string]::IsNullOrWhiteSpace($value) -and $value -ne $hostMarker
    }
    if (-not $hostRaw.Trim().Equals([string]$plan.Manifest.expectedComputerName,[StringComparison]::OrdinalIgnoreCase)) {
        throw "JBOD identity mismatch: $($hostRaw.Trim())"
    }
    $hostnameGatePassed = $true

    $stage = 'FILE_BACKED_CLIPBOARD_PAYLOAD'
    Set-ClipboardExact -Value $plan.Payload
    Start-Sleep -Seconds 3
    Set-ExactForeground -Process $rustDesk
    Send-ShortLiteralKeys -Text ([string]$plan.Manifest.typedPayloadTrigger)
    Send-NativeEnter
    $payloadTriggerSubmitted = $true

    $stage = 'WAIT_EXACT_NONCE_RESULT'
    $expectedSchema = [string]$plan.Manifest.expectedResult.schema
    $expectedNonce = [string]$plan.Manifest.expectedResult.nonce
    $raw = Wait-Clipboard -Seconds ([int]$plan.Manifest.timeoutSeconds) -Predicate {
        param($value)
        if ([string]::IsNullOrWhiteSpace($value)) { return $false }
        $trimmed = $value.TrimStart()
        return $trimmed.StartsWith('{',[StringComparison]::Ordinal) -and
            $trimmed -match ('"schema"\s*:\s*"' + [regex]::Escape($expectedSchema) + '"') -and
            $trimmed -match ('"nonce"\s*:\s*"' + [regex]::Escape($expectedNonce) + '"')
    }
    $remoteResult = $raw | ConvertFrom-Json -ErrorAction Stop
    $resultReturned = $true
    if ([string]$remoteResult.schema -ne $expectedSchema) { throw 'Remote result schema changed.' }
    if ([string]$remoteResult.nonce -ne $expectedNonce) { throw 'Remote result nonce changed.' }
    if ([string]$remoteResult.computerName -ne [string]$plan.Manifest.expectedComputerName) { throw 'Remote result hostname changed.' }
    if ([string]$remoteResult.state -ne [string]$plan.Manifest.expectedResult.state) { throw "Remote result failed: $($remoteResult.state)" }
    if ([string]$remoteResult.scalar -ne [string]$plan.Manifest.expectedResult.scalar) { throw 'Remote fixed scalar changed.' }
    if ([bool]$remoteResult.targetPersistentMutationPerformed) { throw 'Remote result reports target mutation.' }
    if ([bool]$remoteResult.taskOrProcessManagementPerformed) { throw 'Remote result reports task/process management.' }
    if ([bool]$remoteResult.imageBytesRead) { throw 'Remote result reports image-byte read.' }
    $stage = 'COMPLETE'
    $terminalState = 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER'
}
catch {
    $errorMessage = [string]$_.Exception.Message
}

$terminal = [ordered]@{
    schema = 'argos_o3tc1_fresh_console_short_trigger_terminal_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = $terminalState
    stage = $stage
    invocationManifestSha256 = Get-Sha256File -Path $plan.ManifestPath
    entrypointSha256 = Get-Sha256File -Path $scriptPath
    payloadSha256 = Get-Sha256File -Path $plan.PayloadPath
    payloadCharacters = $plan.Payload.Length
    typedHostnameGate = [string]$plan.Manifest.typedHostnameGate
    typedPayloadTrigger = [string]$plan.Manifest.typedPayloadTrigger
    nativeEnterKey = 'VK_RETURN_0x0D_KEYDOWN_KEYUP'
    remoteInputAttempted = $remoteInputAttempted
    freshConsoleOpened = $freshConsoleOpened
    hostnameGatePassed = $hostnameGatePassed
    payloadTriggerSubmitted = $payloadTriggerSubmitted
    resultReturned = $resultReturned
    resultNonce = if ($null -eq $remoteResult) { '' } else { [string]$remoteResult.nonce }
    resultScalar = if ($null -eq $remoteResult) { '' } else { [string]$remoteResult.scalar }
    errorMessage = $errorMessage
    originalTwoStrandedConsolesInputSent = $false
    targetPersistentMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-CreateNewJson -Path $plan.TerminalPath -Value $terminal
$terminal | ConvertTo-Json -Depth 12
if ($terminalState -ne 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER') { exit 1 }
