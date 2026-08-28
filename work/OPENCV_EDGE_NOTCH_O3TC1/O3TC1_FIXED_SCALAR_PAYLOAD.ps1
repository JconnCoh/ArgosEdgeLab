[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$schema = 'argos_o3tc1_fresh_console_short_trigger_result_v1'
$nonce = 'O3TC1_FIXED_SCALAR_20260828_7D9332A9'
$expectedComputerName = 'A1025645101'
$expectedScalar = 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER_NATIVE_ENTER_20260828'
if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3tc1_fixed_scalar_payload_preflight_v1'
        state = 'PASS_O3TC1_FIXED_SCALAR_PAYLOAD_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        expectedScalar = $expectedScalar
        clipboardChanged = $false
        targetPersistentMutationPerformed = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
    } | ConvertTo-Json -Depth 4
    return
}
try {
    if ($env:COMPUTERNAME -ne $expectedComputerName) {
        throw "Wrong computer: $($env:COMPUTERNAME)"
    }
    $result = [ordered]@{
        schema = $schema
        state = 'PASS_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER'
        nonce = $nonce
        computerName = $env:COMPUTERNAME
        scalar = $expectedScalar
        targetPersistentMutationPerformed = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
    }
}
catch {
    $result = [ordered]@{
        schema = $schema
        state = 'FAIL_O3TC1_FRESH_CONSOLE_SHORT_TRIGGER'
        nonce = $nonce
        computerName = [string]$env:COMPUTERNAME
        scalar = ''
        errorMessage = [string]$_.Exception.Message
        targetPersistentMutationPerformed = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
    }
}
$json = $result | ConvertTo-Json -Compress
$json | clip.exe
