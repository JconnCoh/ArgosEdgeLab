[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$schema = 'argos_o3ro3_process_state_result_v1'
$progressSchema = 'argos_o3ro3_process_state_progress_v1'
$nonce = 'O3RO3_PROCESS_STATE_20260828_912FB64C'
$expectedComputerName = 'A1025645101'
$pythonPath = 'D:\AFCV1\rt\python.exe'
$commandMarker = 'import json,platform,cv2,numpy as np'
$scalar = 'PASS_O3RO3_EXACT_PROCESS_STATE_OBSERVATION_20260828'
$maximumRows = 8
$maximumCommandLineCharacters = 2048

function New-ResultBase([string]$State,[string]$ResultScalar,[string]$ComputerName) {
    return [ordered]@{
        schema = $schema
        state = $State
        nonce = $nonce
        computerName = $ComputerName
        scalar = $ResultScalar
        taskOrProcessManagementPerformed = $false
        processManagementPerformed = $false
        imageBytesRead = $false
        sourceMutationPerformed = $false
        targetPersistentMutationPerformed = $false
    }
}

function Test-O3TC1ConsumerFields([Collections.Specialized.OrderedDictionary]$Value) {
    $required = @('schema','state','nonce','computerName','scalar','taskOrProcessManagementPerformed','imageBytesRead','targetPersistentMutationPerformed')
    foreach ($property in $required) {
        if (-not $Value.Contains($property)) { throw "O3TC1 consumer property is absent: $property" }
    }
    [void][string]$Value.schema
    [void][string]$Value.state
    [void][string]$Value.nonce
    [void][string]$Value.computerName
    [void][string]$Value.scalar
    [void][bool]$Value.taskOrProcessManagementPerformed
    [void][bool]$Value.imageBytesRead
    [void][bool]$Value.targetPersistentMutationPerformed
    return $required
}

if ($Preflight) {
    $successFixture = New-ResultBase -State 'PASS_O3RO3_PROCESS_STATE_OBSERVATION' -ResultScalar $scalar -ComputerName $expectedComputerName
    $failureFixture = New-ResultBase -State 'FAIL_O3RO3_PROCESS_STATE_OBSERVATION' -ResultScalar '' -ComputerName $expectedComputerName
    $successFields = @(Test-O3TC1ConsumerFields -Value $successFixture)
    $failureFields = @(Test-O3TC1ConsumerFields -Value $failureFixture)
    [pscustomobject]@{
        schema = 'argos_o3ro3_process_state_payload_preflight_v1'
        state = 'PASS_O3RO3_PROCESS_STATE_PAYLOAD_AND_CALLER_CONSUMER_CONTRACT_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        processName = 'python.exe'
        exactExecutablePath = $pythonPath
        exactCommandMarker = $commandMarker
        maximumRows = $maximumRows
        maximumCommandLineCharacters = $maximumCommandLineCharacters
        successConsumerFields = $successFields
        failureConsumerFields = $failureFields
        targetQueryPerformed = $false
        clipboardChanged = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

function Send-ClipboardJson([object]$Value) {
    $Value | ConvertTo-Json -Compress -Depth 8 | clip.exe
    if ($LASTEXITCODE -ne 0) { throw 'clip.exe failed to synchronize O3RO3 result.' }
}

try {
    if ($env:COMPUTERNAME -ne $expectedComputerName) { throw "Wrong computer: $($env:COMPUTERNAME)" }
    Send-ClipboardJson -Value ([ordered]@{
        schema = $progressSchema
        state = 'STARTED_O3RO3_PROCESS_STATE_OBSERVATION'
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
    $result = New-ResultBase -State 'PASS_O3RO3_PROCESS_STATE_OBSERVATION' -ResultScalar $scalar -ComputerName $env:COMPUTERNAME
    $result.Add('pythonProcessCount',$pythonRows.Count)
    $result.Add('exactRuntimePathProcessCount',$pathRows.Count)
    $result.Add('exactO3RO1ProcessCount',$exactRows.Count)
    $result.Add('rows',$returnedRows)
}
catch {
    $result = New-ResultBase -State 'FAIL_O3RO3_PROCESS_STATE_OBSERVATION' -ResultScalar '' -ComputerName ([string]$env:COMPUTERNAME)
    $result.Add('errorMessage',[string]$_.Exception.Message)
}
[void](Test-O3TC1ConsumerFields -Value $result)
Send-ClipboardJson -Value $result
