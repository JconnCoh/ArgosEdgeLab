[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$schema = 'argos_o3ro2_process_state_result_v1'
$progressSchema = 'argos_o3ro2_process_state_progress_v1'
$nonce = 'O3RO2_PROCESS_STATE_20260828_6C41E7B2'
$expectedComputerName = 'A1025645101'
$pythonPath = 'D:\AFCV1\rt\python.exe'
$commandMarker = 'import json,platform,cv2,numpy as np'
$scalar = 'PASS_O3RO2_EXACT_PROCESS_STATE_OBSERVATION_20260828'
$maximumRows = 8
$maximumCommandLineCharacters = 2048

if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_o3ro2_process_state_payload_preflight_v1'
        state = 'PASS_O3RO2_PROCESS_STATE_PAYLOAD_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        processName = 'python.exe'
        exactExecutablePath = $pythonPath
        exactCommandMarker = $commandMarker
        maximumRows = $maximumRows
        maximumCommandLineCharacters = $maximumCommandLineCharacters
        targetQueryPerformed = $false
        clipboardChanged = $false
        processManagementPerformed = $false
        imageBytesRead = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 4
    return
}

function Send-ClipboardJson([object]$Value) {
    $Value | ConvertTo-Json -Compress -Depth 8 | clip.exe
    if ($LASTEXITCODE -ne 0) { throw 'clip.exe failed to synchronize O3RO2 result.' }
}

try {
    if ($env:COMPUTERNAME -ne $expectedComputerName) { throw "Wrong computer: $($env:COMPUTERNAME)" }
    Send-ClipboardJson -Value ([ordered]@{
        schema = $progressSchema
        state = 'STARTED_O3RO2_PROCESS_STATE_OBSERVATION'
        nonce = $nonce
        computerName = $env:COMPUTERNAME
        targetPersistentMutationPerformed = $false
    })

    $pythonRows = @(Get-CimInstance Win32_Process -Filter "Name='python.exe'" -ErrorAction Stop)
    $pathRows = @($pythonRows | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_.ExecutablePath) -and
        ([IO.Path]::GetFullPath([string]$_.ExecutablePath)).Equals($pythonPath,[StringComparison]::OrdinalIgnoreCase)
    })
    $exactRows = @($pathRows | Where-Object {
        -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and
        ([string]$_.CommandLine).IndexOf($commandMarker,[StringComparison]::Ordinal) -ge 0
    })
    if ($exactRows.Count -gt $maximumRows) { throw "Exact O3RO1 process rows exceed $maximumRows." }

    $returnedRows = @(
        foreach ($row in $exactRows) {
            $commandLine = [string]$row.CommandLine
            if ($commandLine.Length -gt $maximumCommandLineCharacters) { throw 'Exact O3RO1 process command line exceeds the bounded length.' }
            $created = $row.CreationDate
            $creationUtc = if ($created -is [datetime]) {
                ([datetime]$created).ToUniversalTime().ToString('o')
            } else {
                ([Management.ManagementDateTimeConverter]::ToDateTime([string]$created)).ToUniversalTime().ToString('o')
            }
            [ordered]@{
                processId = [uint32]$row.ProcessId
                executablePath = [string]$row.ExecutablePath
                commandLine = $commandLine
                creationUtc = $creationUtc
            }
        }
    )

    $result = [ordered]@{
        schema = $schema
        state = 'PASS_O3RO2_PROCESS_STATE_OBSERVATION'
        nonce = $nonce
        computerName = $env:COMPUTERNAME
        scalar = $scalar
        pythonProcessCount = $pythonRows.Count
        exactRuntimePathProcessCount = $pathRows.Count
        exactO3RO1ProcessCount = $exactRows.Count
        rows = $returnedRows
        processManagementPerformed = $false
        imageBytesRead = $false
        sourceMutationPerformed = $false
        targetPersistentMutationPerformed = $false
    }
}
catch {
    $result = [ordered]@{
        schema = $schema
        state = 'FAIL_O3RO2_PROCESS_STATE_OBSERVATION'
        nonce = $nonce
        computerName = [string]$env:COMPUTERNAME
        scalar = ''
        errorMessage = [string]$_.Exception.Message
        processManagementPerformed = $false
        imageBytesRead = $false
        sourceMutationPerformed = $false
        targetPersistentMutationPerformed = $false
    }
}
Send-ClipboardJson -Value $result
