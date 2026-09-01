#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedComputerName = 'A1025645101'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$endpointConfigPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
$endpointWorkerPath = Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
$endpointTaskName = 'ArgosProjectPortal.JBOD.Endpoint.RO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$processorScriptLeaf = 'Run-JbodAllWaferProcessor.ps1'

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Convert-CimCreationDateToUtcString {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { throw 'Process CreationDate is null.' }
    if ($Value -is [DateTime]) {
        return ([DateTime]$Value).ToUniversalTime().ToString('o')
    }
    $dmtfText = [string]$Value
    if ($dmtfText -notmatch '^\d{14}\.\d{6}[+-]\d{3}$') {
        throw 'Process CreationDate is neither a DateTime nor an exact DMTF timestamp.'
    }
    return ([Management.ManagementDateTimeConverter]::ToDateTime($dmtfText)).ToUniversalTime().ToString('o')
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r21_current_premise_observation_preflight_v1'
        state = 'PASS_R21_CURRENT_PREMISE_OBSERVATION_PREFLIGHT'
        targetComputerName = $expectedComputerName
        endpointConfigPath = $endpointConfigPath
        endpointWorkerPath = $endpointWorkerPath
        endpointTaskName = $endpointTaskName
        processorRoot = $processorRoot
        mutationsPerformed = $false
        taskOrProcessActionPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}

if ($env:COMPUTERNAME -ne $expectedComputerName) {
    throw "Wrong computer: $($env:COMPUTERNAME)"
}
foreach ($path in @($endpointConfigPath, $endpointWorkerPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required premise file is absent: $path"
    }
}

$configBytes = [IO.File]::ReadAllBytes($endpointConfigPath)
$config = [Text.Encoding]::UTF8.GetString($configBytes) | ConvertFrom-Json -ErrorAction Stop
if ([string]$config.schema -ne 'argos_project_portal_endpoint_config_v1' -or [string]$config.role -ne 'JBOD') {
    throw 'Current endpoint configuration identity is invalid.'
}

$endpointTasks = @(Get-ScheduledTask -TaskName $endpointTaskName -ErrorAction Stop)
if ($endpointTasks.Count -ne 1) { throw 'Exact endpoint task is missing or ambiguous.' }
$endpointTask = $endpointTasks[0]
$taskDefinition = [string](Export-ScheduledTask -TaskName $endpointTaskName -ErrorAction Stop)
$taskDefinitionBytes = [Text.Encoding]::UTF8.GetBytes($taskDefinition)
$taskDefinitionSha = [BitConverter]::ToString(
    ([Security.Cryptography.SHA256]::Create()).ComputeHash($taskDefinitionBytes)
).Replace('-', '')
$taskActions = @(
    $endpointTask.Actions | ForEach-Object {
        [ordered]@{
            execute = [string]$_.Execute
            arguments = [string]$_.Arguments
            workingDirectory = [string]$_.WorkingDirectory
        }
    }
)

$consoleHostName = 'power' + 'shell.exe'
$iseHostName = 'power' + 'shell_ise.exe'
$processorRows = @(
    Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            [string]$_.Name -eq $consoleHostName -or [string]$_.Name -eq $iseHostName
        } |
        ForEach-Object {
            $commandLine = [string]$_.CommandLine
            if (
                $commandLine.IndexOf($processorScriptLeaf, [StringComparison]::OrdinalIgnoreCase) -ge 0 -and
                $commandLine.IndexOf($processorRoot, [StringComparison]::OrdinalIgnoreCase) -ge 0
            ) {
                [ordered]@{
                    processId = [int]$_.ProcessId
                    sessionId = [int]$_.SessionId
                    creationUtc = Convert-CimCreationDateToUtcString -Value $_.CreationDate
                    name = [string]$_.Name
                    commandLine = $commandLine
                }
            }
        }
)
if ($processorRows.Count -ne 1) { throw 'Healthy processor premise is missing or ambiguous.' }

[ordered]@{
    schema = 'argos_r21_current_premise_observation_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21_CURRENT_PREMISE_OBSERVATION'
    computerName = $env:COMPUTERNAME
    endpointConfig = [ordered]@{
        path = $endpointConfigPath
        bytes = $configBytes.Length
        sha256 = Get-Sha256 -Path $endpointConfigPath
        contentBase64 = [Convert]::ToBase64String($configBytes)
        schema = [string]$config.schema
        role = [string]$config.role
    }
    endpointWorker = [ordered]@{
        path = $endpointWorkerPath
        bytes = (Get-Item -LiteralPath $endpointWorkerPath -ErrorAction Stop).Length
        sha256 = Get-Sha256 -Path $endpointWorkerPath
    }
    endpointTask = [ordered]@{
        name = [string]$endpointTask.TaskName
        taskPath = [string]$endpointTask.TaskPath
        principal = [string]$endpointTask.Principal.UserId
        state = [string]$endpointTask.State
        definitionSha256 = $taskDefinitionSha
        actions = $taskActions
    }
    healthyProcessor = $processorRows[0]
    processorSelectorSource = [ordered]@{
        path = 'work/GUIR9C3_PORTAL/payload/Apply-GUIR9C3DirectGuiPatch.ps1'
        sha256 = '0F9E1B32DE20CB8E6C04AC052853AB658C63EE08F5E480DAB8E588B079BA6872'
        lines = '189-226'
    }
    configOrWorkerChanged = $false
    taskOrProcessActionPerformed = $false
    imageBytesRead = $false
    sourceOrOutputBytesRead = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 12 -Compress | Set-Clipboard
