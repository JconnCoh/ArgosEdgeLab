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
    Join-Path (Split-Path -Parent $PSScriptRoot) 'direct_control_r3\Get-ArgosAdminInboundRelayObservationR3.ps1'
} else { $PayloadPath }

function Assert-Payload {
    if (-not (Test-Path -LiteralPath $effectivePayloadPath -PathType Leaf)) { throw "R4 payload is absent: $effectivePayloadPath" }
    $hash = (Get-FileHash -LiteralPath $effectivePayloadPath -Algorithm SHA256).Hash
    if ($hash -ne $expectedPayloadSha256) { throw "R4 payload hash changed: $hash" }
    $text = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $effectivePayloadPath).Path)
    $tokens = $null
    $errors = $null
    [void][Management.Automation.Language.Parser]::ParseInput($text,[ref]$tokens,[ref]$errors)
    if (@($errors).Count -ne 0) { throw "R4 payload failed local parsing: $($errors[0].Message)" }
    return $text
}

function Assert-OutputPath {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { throw 'R4 execution requires an exact local OutputPath.' }
    $full = [IO.Path]::GetFullPath($OutputPath)
    $parent = Split-Path -Parent $full
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "R4 output parent is absent: $parent" }
    if (Test-Path -LiteralPath $full) { throw "R4 output must be create-new: $full" }
    return $full
}

function Write-Evidence([string]$Path,[object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "R4 evidence path already exists: $Path" }
    $json = $Value | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($Path, ($json + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$payload = Assert-Payload
if ($Preflight) {
    $resolvedOutput = $null
    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) { $resolvedOutput = Assert-OutputPath }
    [pscustomobject]@{
        schema = 'argos_admin_inbound_relay_observation_r4_runner_preflight_v1'
        state = 'PASS_ARGOS_ADMIN_INBOUND_RELAY_OBSERVATION_R4_RUNNER_PREFLIGHT'
        payloadPath = $effectivePayloadPath
        payloadSha256 = $expectedPayloadSha256
        outputPath = $resolvedOutput
        hostnameUsesShortClipboardPaste = $true
        payloadUsesClipboardSourceAndShortTypedTrigger = $true
        typedTrigger = 'iex(gcb -r)'
        structuredFailureEvidence = $true
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
public static class ArgosAdminInboundR4Native {
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
    $foregroundWindow = [ArgosAdminInboundR4Native]::GetForegroundWindow()
    [uint32]$foregroundProcessId = 0
    $foregroundThread = [ArgosAdminInboundR4Native]::GetWindowThreadProcessId($foregroundWindow,[ref]$foregroundProcessId)
    [uint32]$targetProcessId = 0
    $targetThread = [ArgosAdminInboundR4Native]::GetWindowThreadProcessId($Process.MainWindowHandle,[ref]$targetProcessId)
    $currentThread = [ArgosAdminInboundR4Native]::GetCurrentThreadId()
    $attachedForeground = $false
    $attachedTarget = $false
    try {
        if ($foregroundThread -ne $currentThread) { $attachedForeground = [ArgosAdminInboundR4Native]::AttachThreadInput($currentThread,$foregroundThread,$true) }
        if ($targetThread -ne $currentThread -and $targetThread -ne $foregroundThread) { $attachedTarget = [ArgosAdminInboundR4Native]::AttachThreadInput($currentThread,$targetThread,$true) }
        [void][ArgosAdminInboundR4Native]::BringWindowToTop($Process.MainWindowHandle)
        [void][ArgosAdminInboundR4Native]::SetActiveWindow($Process.MainWindowHandle)
        [void][ArgosAdminInboundR4Native]::SetFocus($Process.MainWindowHandle)
        [void][ArgosAdminInboundR4Native]::SetForegroundWindow($Process.MainWindowHandle)
    }
    finally {
        if ($attachedTarget) { [void][ArgosAdminInboundR4Native]::AttachThreadInput($currentThread,$targetThread,$false) }
        if ($attachedForeground) { [void][ArgosAdminInboundR4Native]::AttachThreadInput($currentThread,$foregroundThread,$false) }
    }
    Start-Sleep -Milliseconds 250
    if ([ArgosAdminInboundR4Native]::GetForegroundWindow() -ne $Process.MainWindowHandle) { throw 'Exact RustDesk desktop did not become foreground; refusing input.' }
    foreach ($key in [byte[]](0xA0,0xA1,0xA2,0xA3,0xA4,0xA5,0x5B,0x5C)) {
        [ArgosAdminInboundR4Native]::keybd_event($key,0,2,[UIntPtr]::Zero)
    }
    Start-Sleep -Milliseconds 100
}

function Send-ShortLiteralKeys([string]$Text) {
    if ($Text.Length -gt 32) { throw "R4 typed trigger exceeds the 32-character bound: $($Text.Length)" }
    $builder = [Text.StringBuilder]::new()
    foreach ($character in $Text.ToCharArray()) {
        $escaped = switch ([string]$character) {
            '+' {'{+}'} '^' {'{^}'} '%' {'{%}'} '~' {'{~}'} '(' {'{(}'} ')' {'{)}'} '{' {'{{}'} '}' {'{}}'} default {[string]$character}
        }
        [void]$builder.Append($escaped)
    }
    [Windows.Forms.SendKeys]::SendWait($builder.ToString())
}

function Send-ClipboardPaste {
    [ArgosAdminInboundR4Native]::keybd_event(0x11,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [ArgosAdminInboundR4Native]::keybd_event(0x56,0,0,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 40
    [ArgosAdminInboundR4Native]::keybd_event(0x56,0,2,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [ArgosAdminInboundR4Native]::keybd_event(0x11,0,2,[UIntPtr]::Zero)
    Start-Sleep -Milliseconds 100
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
    Send-ShortLiteralKeys 'iex(gcb -r)'
    [Windows.Forms.SendKeys]::SendWait('{ENTER}')
    return Wait-Clipboard -Seconds $Seconds -Predicate {
        param($value)
        if ([string]::IsNullOrWhiteSpace($value)) { return $false }
        $trimmed = $value.TrimStart()
        return $trimmed.StartsWith('{',[StringComparison]::Ordinal) -and $trimmed -match ('"schema"\s*:\s*"' + [regex]::Escape($ExpectedSchema) + '"')
    }
}

$stage = 'LOCAL_WINDOW_INVENTORY'
$hostnameGatePassed = $false
$adminGateSourceTransferred = $false
$adminGatePassed = $false
$fullPayloadTransferred = $false
$observationReturned = $false

try {
    $desktopPids = @(Get-CimInstance Win32_Process -Filter "Name='RustDesk.exe'" -ErrorAction Stop | Where-Object {
        [string]$_.CommandLine -match '(?i)\s--connect\s+10\.66\.81\.84(?:\s|$)' -and
        [string]$_.CommandLine -notmatch '(?i)\s--port-forward(?:\s|$)'
    } | Select-Object -ExpandProperty ProcessId)
    $rustDeskRows = @(Get-Process RustDesk -ErrorAction SilentlyContinue | Where-Object {
        $desktopPids -contains [uint32]$_.Id -and
        $_.MainWindowHandle -ne 0 -and
        $_.MainWindowTitle -eq $RustDeskWindowTitle
    })
    if ($rustDeskRows.Count -ne 1) { throw "Expected one exact RustDesk --connect $RustDeskWindowTitle desktop; observed $($rustDeskRows.Count)." }
    $rustDesk = $rustDeskRows[0]
    $rect = New-Object ArgosAdminInboundR4Native+RECT
    [void][ArgosAdminInboundR4Native]::GetWindowRect($rustDesk.MainWindowHandle,[ref]$rect)
    if ($rect.Left -ne 0 -or $rect.Top -ne 0 -or ($rect.Right-$rect.Left) -ne 1920 -or ($rect.Bottom-$rect.Top) -ne 1200) {
        throw 'RustDesk is not in the verified 1920x1200 full-screen layout.'
    }

    $stage = 'ARGOS_HOSTNAME_SHORT_CLIPBOARD_PASTE'
    $hostCommand = 'hostname|clip'
    Set-ClipboardExact $hostCommand
    Start-Sleep -Seconds 3
    Set-ExactForeground $rustDesk
    Send-ClipboardPaste
    [Windows.Forms.SendKeys]::SendWait('{ENTER}')
    $hostRaw = Wait-Clipboard -Seconds ([Math]::Min(30,$TimeoutSeconds)) -Predicate {
        param($value)
        -not [string]::IsNullOrWhiteSpace($value) -and $value.Trim() -ne $hostCommand
    }
    if (-not $hostRaw.Trim().Equals('DESKTOP-266P787',[StringComparison]::OrdinalIgnoreCase)) {
        throw "Argos identity mismatch: $($hostRaw.Trim())"
    }
    $hostnameGatePassed = $true

    $stage = 'ARGOS_ADMIN_PROTECTED_READ_GATE'
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
    $adminGateSourceTransferred = $true
    $adminRaw = Invoke-ClipboardScript -RustDesk $rustDesk -Source $adminGateSource -ExpectedSchema 'argos_admin_protected_portal_read_gate_v1' -Seconds ([Math]::Min(60,$TimeoutSeconds))
    $adminGate = $adminRaw | ConvertFrom-Json -ErrorAction Stop
    if ([string]$adminGate.state -ne 'PASS_ARGOS_ADMIN_PROTECTED_PORTAL_READ_GATE') {
        $holdEvidence = [ordered]@{
            schema = 'argos_admin_inbound_relay_observation_r4_acquisition_v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            state = 'HOLD_ARGOS_ADMIN_PROTECTED_PORTAL_READ_GATE'
            stage = $stage
            computerName = [string]$adminGate.computerName
            runnerSha256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash
            payloadSha256 = $expectedPayloadSha256
            hostnameGatePassed = $hostnameGatePassed
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
    $adminGatePassed = $true

    $stage = 'ARGOS_BOUNDED_INBOUND_RELAY_OBSERVATION'
    $fullPayloadTransferred = $true
    $observationRaw = Invoke-ClipboardScript -RustDesk $rustDesk -Source $payload -ExpectedSchema 'argos_inbound_relay_direct_observation_v3' -Seconds $TimeoutSeconds
    $observation = $observationRaw | ConvertFrom-Json -ErrorAction Stop
    $observationReturned = $true
    if (-not ([string]$observation.computerName).Equals('DESKTOP-266P787',[StringComparison]::OrdinalIgnoreCase)) { throw 'R4 observation returned the wrong computer identity.' }
    if ([string]$observation.state -ne 'OBSERVED_ARGOS_ADMIN_INBOUND_RELAY_READ_ONLY') { throw 'R4 observation returned an unexpected state.' }
    if (-not [bool]$observation.administrativeToken -or -not [bool]$observation.protectedPortalRootReadable) { throw 'R4 observation lost administrative protected-root readability.' }

    $acquisition = [ordered]@{
        schema = 'argos_admin_inbound_relay_observation_r4_acquisition_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_EXACT_ARGOS_ADMIN_INBOUND_RELAY_READ_ONLY_OBSERVATION'
        stage = 'COMPLETE'
        computerName = [string]$observation.computerName
        runnerSha256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash
        payloadSha256 = $expectedPayloadSha256
        hostnameGatePassed = $hostnameGatePassed
        adminGate = $adminGate
        fullPayloadTransferred = $fullPayloadTransferred
        observationReturned = $observationReturned
        observation = $observation
        jbodContacted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    $evidenceSha256 = Write-Evidence -Path $resolvedOutputPath -Value $acquisition
    [pscustomobject]@{
        schema = 'argos_admin_inbound_relay_observation_r4_summary_v1'
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
}
catch {
    $failure = $_
    if (-not (Test-Path -LiteralPath $resolvedOutputPath)) {
        $failureEvidence = [ordered]@{
            schema = 'argos_admin_inbound_relay_observation_r4_acquisition_v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            state = 'FAIL_O2D10_ARGOS_ADMIN_INBOUND_RELAY_R4_GATE'
            stage = $stage
            errorType = $failure.Exception.GetType().FullName
            errorMessage = $failure.Exception.Message
            runnerSha256 = (Get-FileHash -LiteralPath $MyInvocation.MyCommand.Path -Algorithm SHA256).Hash
            payloadSha256 = $expectedPayloadSha256
            hostnameGatePassed = $hostnameGatePassed
            adminGateSourceTransferred = $adminGateSourceTransferred
            adminGatePassed = $adminGatePassed
            fullPayloadTransferred = $fullPayloadTransferred
            observationReturned = $observationReturned
            jbodContacted = $false
            publicationPerformed = $false
            taskOrProcessActionPerformed = $false
            queueOrLedgerMutationPerformed = $false
            remoteFileMutationPerformed = $false
            mutationsPerformed = $false
            reviewOnly = $true
            productionRoutingEnabled = $false
        }
        $failureSha256 = Write-Evidence -Path $resolvedOutputPath -Value $failureEvidence
        [pscustomobject]@{state=$failureEvidence.state;stage=$stage;evidencePath=$resolvedOutputPath;evidenceSha256=$failureSha256;mutationsPerformed=$false} | ConvertTo-Json -Compress
    }
    throw $failure
}
