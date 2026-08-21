[CmdletBinding()]
param(
    [ValidateRange(15, 3600)]
    [int]$IntervalSeconds = 240
)

$ErrorActionPreference = 'Stop'

if ($env:OS -ne 'Windows_NT') {
    throw 'Keep-CodexAwake requires Windows.'
}

$nativeMethods = @'
using System;
using System.Runtime.InteropServices;

public static class KeepCodexAwakeNative
{
    private const byte VK_F15 = 0x7E;
    private const uint KEYEVENTF_KEYUP = 0x0002;

    public const uint ES_SYSTEM_REQUIRED = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
    public const uint ES_CONTINUOUS = 0x80000000;

    [DllImport("user32.dll")]
    private static extern void keybd_event(
        byte virtualKey,
        byte scanCode,
        uint flags,
        UIntPtr extraInfo);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint executionState);

    public static void PulseF15()
    {
        keybd_event(VK_F15, 0, 0, UIntPtr.Zero);
        keybd_event(VK_F15, 0, KEYEVENTF_KEYUP, UIntPtr.Zero);
    }
}
'@

Add-Type -TypeDefinition $nativeMethods

$keepAwakeState = (
    [KeepCodexAwakeNative]::ES_CONTINUOUS -bor
    [KeepCodexAwakeNative]::ES_SYSTEM_REQUIRED -bor
    [KeepCodexAwakeNative]::ES_DISPLAY_REQUIRED
)

$stateResult = [KeepCodexAwakeNative]::SetThreadExecutionState($keepAwakeState)
if ($stateResult -eq 0) {
    throw 'Windows rejected the request to keep the system awake.'
}

try {
    $Host.UI.RawUI.WindowTitle = 'Codex Keep Awake - Ctrl+C to stop'
} catch {
    # A non-console PowerShell host may not expose a window title.
}

Write-Host ''
Write-Host 'Codex Keep Awake is running.' -ForegroundColor Green
Write-Host "Sending an unassigned F15 key pulse every $IntervalSeconds seconds."
Write-Host 'Keep this window open. Press Ctrl+C or close it to stop.'
Write-Host ''

try {
    while ($true) {
        Start-Sleep -Seconds $IntervalSeconds

        [KeepCodexAwakeNative]::PulseF15()
        $stateResult = [KeepCodexAwakeNative]::SetThreadExecutionState($keepAwakeState)
        if ($stateResult -eq 0) {
            throw 'Windows stopped accepting keep-awake requests.'
        }

        Write-Host ("[{0}] F15 pulse sent." -f (Get-Date -Format 'HH:mm:ss'))
    }
}
finally {
    [void][KeepCodexAwakeNative]::SetThreadExecutionState(
        [KeepCodexAwakeNative]::ES_CONTINUOUS
    )
    Write-Host ''
    Write-Host 'Codex Keep Awake stopped; normal sleep behavior is restored.' -ForegroundColor Yellow
}
