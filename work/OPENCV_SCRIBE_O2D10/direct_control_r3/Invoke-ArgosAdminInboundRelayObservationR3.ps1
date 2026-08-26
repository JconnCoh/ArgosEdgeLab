[CmdletBinding()]
param(
    [switch]$Preflight,
    [ValidateRange(30,300)][int]$TimeoutSeconds = 120,
    [string]$RustDeskWindowTitle = '10.66.81.84',
    [string]$PayloadPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expectedPayloadSha256 = '0A5FC6DC9D403C9E28FC12CA20498E547B88FD87A1BA961A3841C80975353A43'
$effectivePayloadPath = if ([string]::IsNullOrWhiteSpace($PayloadPath)) {
    Join-Path $PSScriptRoot 'Get-ArgosAdminInboundRelayObservationR3.ps1'
} else { $PayloadPath }

function Assert-Payload {
    if (-not (Test-Path -LiteralPath $effectivePayloadPath -PathType Leaf)) { throw "R3 payload is absent: $effectivePayloadPath" }
    $hash = (Get-FileHash -LiteralPath $effectivePayloadPath -Algorithm SHA256).Hash
    if ($hash -ne $expectedPayloadSha256) { throw "R3 payload hash changed: $hash" }
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $effectivePayloadPath).Path)
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -ne 0) { throw "R3 payload failed local parsing: $($errors[0].Message)" }
    return $text
}

function Assert-OutputPath {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'R3 execution requires an exact local OutputPath.' }
    $full = [IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "R3 output parent is absent: $parent" }
    if (Test-Path -LiteralPath $full) { throw "R3 output must be create-new: $full" }
    return $full
}

function Write-Evidence([string]$Path,[object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "R3 evidence path already exists: $Path" }
    $json = $Value | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($Path, ($json + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$payload = Assert-Payload
if ($Preflight) {
    $resolvedOutput = $null
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $resolvedOutput = Assert-OutputPath }
    [pscustomobject]@{
        schema = 'argos_admin_inbound_relay_observation_r3_runner_preflight_v1'
        state = 'PASS_ARGOS_ADMIN_INBOUND_RELAY_OBSERVATION_R3_RUNNER_PREFLIGHT'
        payloadPath = $effectivePayloadPath
        payloadSha256 = $expectedPayloadSha256
        outputPath = $resolvedOutput
        reusesOperatorConfirmedArgosAdministrativePowerShell = $true
        hostnameGateBeforeAdminGate = $true
        adminAndProtectedReadGateBeforeFullPayload = $true
        rustDeskFocused = $false
        remoteInputSent = $false
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 4
    return
}
$resolvedOutputPath = Assert-OutputPath

Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class ArgosAdminInboundR3Native {
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint attachThread, uint attachToThread, bool attach);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SetActiveWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern IntPtr SetFocus(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
    [DllImport("user32.dll")] public static extern void keybd_event(byte key, byte scan, uint flags, UIntPtr extra);
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
'@

function Set-ExactForeground([Diagnostics.Process]$Process) {
    $foregroundWindow = [ArgosAdminInboundR3Native]::GetForegroundWindow()
    [uint32]$foregroundProcessId = 0
    $foregroundThread = [ArgosAdminInboundR3Native]::GetWindowThreadProcessId($foregroundWindow,[ref]$foregroundProcessId)
    [uint32]$targetProcessId = 0
    $targetThread = [ArgosAdminInboundR3Native]::GetWindowThreadProcessId($Process.MainWindowHandle,[ref]$targetProcessId)
    $currentThread = [ArgosAdminInboundR3Native]::GetCurrentThreadId()
    $attachedForeground = $false
    $attachedTarget = $false
    try {
        if ($foregroundThread -ne $currentThread) { $attachedForeground = [ArgosAdminInboundR3Native]::AttachThreadInput($currentThread,$foregroundThread,$true) }
        if ($targetThread -ne $currentThread -and $targetThread -ne $foregroundThread) { $attachedTarget = [ArgosAdminInboundR3Native]::AttachThreadInput($currentThread,$targetThread,$true) }
        [void][ArgosAdminInboundR3Native]::BringWindowToTop($Process.MainWindowHandle)
        [void][ArgosAdminInboundR3Native]::SetActiveWindow($Process.MainWindowHandle)
        [void][ArgosAdminInboundR3Native]::SetFocus($Process.MainWindowHandle)
        [void][ArgosAdminInboundR3Native]::SetForegroundWindow($Process.MainWindowHandle)
    }
    finally {
        if ($attachedTarget) { [void][ArgosAdminInboundR3Native]::AttachThreadInput($currentThread,$targetThread,$false) }
        if ($attachedForeground) { [void][ArgosAdminInboundR3Native]::AttachThreadInput($currentThread,$foregroundThread,$false) }
    }
    Start-Sleep -Milliseconds 250
    if ([ArgosAdminInboundR3Native]::GetForegroundWindow() -ne $Process.MainWindowHandle) { throw 'Exact RustDesk desktop did not become foreground; refusing input.' }
    foreach ($key in [byte[]](0xA0,0xA1,0xA2,0xA3,0xA4,0xA5,0x5B,0x5C)) {
        [ArgosAdminInboundR3Native]::keybd_event($key,0,2,[UIntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 100
}

function Send-RawLiteralKeys([string]$Text) {
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        $escaped = switch ([string]$character) {
            '+' {'{+}'} '^' {'{^}'} '%' {'{%}'} '~' {'{~}'} '(' {'{(}'} ')' {'{)}'} '{' {'{{}'} '}' {'{}}'} default {[string]$character}
        }
        [void]$builder.Append($escaped)
    }
    [Windows.Forms.SendKeys]::SendWait($builder.ToString())
}

function Send-ShiftedVirtualKey([byte]$VirtualKey) {
    [ArgosAdminInboundR3Native]::keybd_event(0x10,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [ArgosAdminInboundR3Native]::keybd_event($VirtualKey,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 30
    [ArgosAdminInboundR3Native]::keybd_event($VirtualKey,0,2,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
    [ArgosAdminInboundR3Native]::keybd_event(0x10,0,2,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 60
}

function Send-RemoteCommandText([string]$Text) {
    $segment = [Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        $virtualKey = switch ([string]$character) {
            '!' {[byte]0x31} '@' {[byte]0x32} '#' {[byte]0x33} '$' {[byte]0x34} '%' {[byte]0x35} '^' {[byte]0x36} '|' {[byte]0xDC}
            '>' {[byte]0xBE} '&' {[byte]0x37} '*' {[byte]0x38} '(' {[byte]0x39} ')' {[byte]0x30} '_' {[byte]0xBD} '+' {[byte]0xBB}
            '{' {[byte]0xDB} '}' {[byte]0xDD} ':' {[byte]0xBA} '"' {[byte]0xDE} '<' {[byte]0xBC} '?' {[byte]0xBF} '~' {[byte]0xC0}
            default {$null}
        }
        if ($null -eq $virtualKey) { [void]$segment.Append($character); continue }
        if ($segment.Length -gt 0) { Send-RawLiteralKeys $segment.ToString(); [void]$segment.Clear() }
        Send-ShiftedVirtualKey $virtualKey
    }
    if ($segment.Length -gt 0) { Send-RawLiteralKeys $segment.ToString() }
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
    throw "Unable to acquire the local clipboard: $lastError"
}

function Wait-Clipboard([scriptblock]$Predicate,[int]$Seconds) {
    $deadline = [DateTime]::UtcNow.AddSeconds($Seconds)
    do {
        Start-Sleep -Milliseconds 250
        $value = [string](Get-Clipboard -Raw -ErrorAction SilentlyContinue)
        if (& $Predicate $value) { return $value }
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "Timed out waiting for the exact Argos clipboard response after $Seconds seconds."
}

function Invoke-ClipboardScript([Diagnostics.Process]$RustDesk,[string]$Source,[string]$ExpectedSchema,[int]$Seconds) {
    Set-ClipboardExact $Source
    Start-Sleep -Seconds 3
    Set-ExactForeground $RustDesk
    Send-RemoteCommandText '&([scriptblock]::create((get-clipboard -raw)))'
    [Windows.Forms.SendKeys]::SendWait('{ENTER}')
    return Wait-Clipboard -Seconds $Seconds -Predicate {
        param($value)
        if ([string]::IsNullOrWhiteSpace($value)) { return $false }
        $trimmed = $value.TrimStart()
        return $trimmed.StartsWith('{',[StringComparison]::Ordinal) -and $trimmed -match ('"schema"\s*:\s*"' + [regex]::Escape($ExpectedSchema) + '"')
    }
}

$desktopPids = @(Get-CimInstance Win32_Process -Filter "Name='RustDesk.exe'" -ErrorAction Stop | Where-Object {
    [string]$_.CommandLine -match '(?i)\s--connect\s+10\.66\.81\.84(?:\s|$)' -and
    [string]$_.CommandLine -notmatch '(?i)\s--port-forward(?:\s|$)'
} | Select-Object -ExpandProperty ProcessId)
$matches = @(Get-Process RustDesk -ErrorAction SilentlyContinue | Where-Object {
    $desktopPids -contains [uint32]$_.Id -and
    $_.MainWindowHandle -ne 0 -and
    $_.MainWindowTitle -eq $RustDeskWindowTitle
})
if ($matches.Count -ne 1) { throw "Expected one exact RustDesk --connect $RustDeskWindowTitle desktop; observed $($matches.Count)." }
$rustDesk = $matches[0]
$rect = New-Object ArgosAdminInboundR3Native+RECT
[void][ArgosAdminInboundR3Native]::GetWindowRect($rustDesk.MainWindowHandle,[ref]$rect)
if ($rect.Left -ne 0 -or $rect.Top -ne 0 -or ($rect.Right-$rect.Left) -ne 1920 -or ($rect.Bottom-$rect.Top) -ne 1200) {
    throw 'RustDesk is not in the verified 1920x1200 full-screen layout.'
}

$hostSentinel = 'ARGOS_ADMIN_R3_HOST|' + [Guid]::NewGuid().ToString('N')
Set-ClipboardExact $hostSentinel
Set-ExactForeground $rustDesk
Send-RemoteCommandText 'hostname|clip'
[Windows.Forms.SendKeys]::SendWait('{ENTER}')
$hostRaw = Wait-Clipboard -Seconds ([Math]::Min(30,$TimeoutSeconds)) -Predicate {
    param($value)
    -not [string]::IsNullOrWhiteSpace($value) -and $value.Trim() -ne $hostSentinel
}
if (-not $hostRaw.Trim().Equals('DESKTOP-266P787',[StringComparison]::OrdinalIgnoreCase)) {
    throw "Argos identity mismatch: $($hostRaw.Trim())"
}

$adminGateSource = @'
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$portalRoot='C:\ProgramData\ArgosProjectPortalRO'
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$principal=New-Object Security.Principal.WindowsPrincipal($identity)
$isAdmin=$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$rootExists=$false
$rootReadable=$false
$probeCount=0
$errorType=$null
$errorMessage=$null
try {
    $rootExists=Test-Path -LiteralPath $portalRoot -PathType Container -ErrorAction Stop
    if($rootExists){$probe=@(Get-ChildItem -LiteralPath $portalRoot -Force -ErrorAction Stop|Select-Object -First 1);$probeCount=$probe.Count;$rootReadable=$true}
}
catch {$errorType=$_.Exception.GetType().FullName;$errorMessage=$_.Exception.Message}
$state=if($env:COMPUTERNAME -eq 'DESKTOP-266P787' -and $isAdmin -and $rootExists -and $rootReadable){'PASS_ARGOS_ADMIN_PROTECTED_PORTAL_READ_GATE'}else{'HOLD_ARGOS_ADMIN_PROTECTED_PORTAL_READ_GATE'}
[ordered]@{schema='argos_admin_protected_portal_read_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=$state;computerName=$env:COMPUTERNAME;userName=$identity.Name;administrativeToken=$isAdmin;portalRoot=$portalRoot;portalRootExists=$rootExists;portalRootReadable=$rootReadable;entryProbeCount=$probeCount;errorType=$errorType;errorMessage=$errorMessage;mutationsPerformed=$false}|ConvertTo-Json -Depth 4 -Compress|Set-Clipboard
'@
$adminRaw = Invoke-ClipboardScript -RustDesk $rustDesk -Source $adminGateSource -ExpectedSchema 'argos_admin_protected_portal_read_gate_v1' -Seconds ([Math]::Min(60,$TimeoutSeconds))
$adminGate = $adminRaw | ConvertFrom-Json -ErrorAction Stop
if ([string]$adminGate.state -ne 'PASS_ARGOS_ADMIN_PROTECTED_PORTAL_READ_GATE') {
    $holdEvidence = [ordered]@{
        schema = 'argos_admin_inbound_relay_observation_r3_acquisition_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'HOLD_ARGOS_ADMIN_PROTECTED_PORTAL_READ_GATE'
        computerName = [string]$adminGate.computerName
        runnerSha256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash
        payloadSha256 = $expectedPayloadSha256
        adminGate = $adminGate
        fullPayloadTransferred = $false
        observationReturned = $false
        jbodContacted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    $holdSha256 = Write-Evidence -Path $resolvedOutputPath -Value $holdEvidence
    [pscustomobject]@{state=$holdEvidence.state;evidencePath=$resolvedOutputPath;evidenceSha256=$holdSha256;fullPayloadTransferred=$false;mutationsPerformed=$false} | ConvertTo-Json -Compress
    throw 'Argos administrative/protected-root read gate did not pass; full observation payload was not sent.'
}

$observationRaw = Invoke-ClipboardScript -RustDesk $rustDesk -Source $payload -ExpectedSchema 'argos_inbound_relay_direct_observation_v3' -Seconds $TimeoutSeconds
$observation = $observationRaw | ConvertFrom-Json -ErrorAction Stop
if (-not ([string]$observation.computerName).Equals('DESKTOP-266P787',[StringComparison]::OrdinalIgnoreCase)) { throw 'R3 observation returned the wrong computer identity.' }
if ([string]$observation.state -ne 'OBSERVED_ARGOS_ADMIN_INBOUND_RELAY_READ_ONLY') { throw 'R3 observation returned an unexpected state.' }
if (-not [bool]$observation.administrativeToken -or -not [bool]$observation.protectedPortalRootReadable) { throw 'R3 observation lost administrative protected-root readability.' }

$acquisition = [ordered]@{
    schema = 'argos_admin_inbound_relay_observation_r3_acquisition_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_EXACT_ARGOS_ADMIN_INBOUND_RELAY_READ_ONLY_OBSERVATION'
    computerName = [string]$observation.computerName
    runnerSha256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash
    payloadSha256 = $expectedPayloadSha256
    adminGate = $adminGate
    fullPayloadTransferred = $true
    observationReturned = $true
    observation = $observation
    jbodContacted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$evidenceSha256 = Write-Evidence -Path $resolvedOutputPath -Value $acquisition
[pscustomobject]@{
    schema = 'argos_admin_inbound_relay_observation_r3_summary_v1'
    state = $acquisition.state
    computerName = $acquisition.computerName
    evidencePath = $resolvedOutputPath
    evidenceSha256 = $evidenceSha256
    taskRowCount = @($observation.taskRows).Count
    configRowCount = @($observation.configRows).Count
    workerRowCount = @($observation.workerRows).Count
    processRowCount = @($observation.processRows).Count
    connectionRowCount = @($observation.connectionRows).Count
    queueRootCount = @($observation.queueRows).Count
    sectionErrorCount = [int]$observation.sectionErrorCount
    accessDenied = [bool]$observation.accessDenied
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 4
