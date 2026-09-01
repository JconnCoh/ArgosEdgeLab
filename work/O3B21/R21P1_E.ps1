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
$expectedConfigSha256 = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$expectedWorkerSha256 = '244A5ECD88020BF80C217271368C836E0AB82E7B76FDEA9D0D9AC07E0AA034E6'

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function Get-TextSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Convert-CimCreationDateToUtcString {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { throw 'Process CreationDate is null.' }
    if ($Value -is [DateTime]) { return ([DateTime]$Value).ToUniversalTime().ToString('o') }
    $dmtfText = [string]$Value
    if ($dmtfText -notmatch '^\d{14}\.\d{6}[+-]\d{3}$') {
        throw 'Process CreationDate is neither a DateTime nor an exact DMTF timestamp.'
    }
    return ([Management.ManagementDateTimeConverter]::ToDateTime($dmtfText)).ToUniversalTime().ToString('o')
}

if ($Preflight) {
    foreach ($command in @('Get-FileHash', 'Get-ScheduledTask', 'Export-ScheduledTask', 'Get-CimInstance')) {
        if ($null -eq (Get-Command $command -ErrorAction Stop)) { throw "Required command is absent: $command" }
    }
    [ordered]@{
        schema = 'argos_r21p1_current_premise_preflight_v1'
        state = 'PASS_R21P1_CURRENT_PREMISE_PREFLIGHT'
        targetComputerName = $expectedComputerName
        expectedConfigSha256 = $expectedConfigSha256
        expectedWorkerSha256 = $expectedWorkerSha256
        taskOrProcessActionPerformed = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

if ($env:COMPUTERNAME -ne $expectedComputerName) { throw "Wrong computer: $($env:COMPUTERNAME)" }
foreach ($path in @($endpointConfigPath, $endpointWorkerPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required premise file is absent: $path" }
}
if ((Get-Sha256 -Path $endpointConfigPath) -ne $expectedConfigSha256) { throw 'Current endpoint configuration hash changed.' }
if ((Get-Sha256 -Path $endpointWorkerPath) -ne $expectedWorkerSha256) { throw 'Current endpoint worker hash changed.' }

$configBytes = [IO.File]::ReadAllBytes($endpointConfigPath)
$config = [Text.Encoding]::UTF8.GetString($configBytes) | ConvertFrom-Json -ErrorAction Stop
if (
    [string]$config.schema -ne 'argos_project_portal_endpoint_config_v1' -or
    [string]$config.role -ne 'JBOD' -or
    -not [bool]$config.reviewOnly -or
    [bool]$config.productionRoutingEnabled
) { throw 'Current endpoint configuration identity or authority changed.' }

$endpointTasks = @(Get-ScheduledTask -TaskName $endpointTaskName -ErrorAction Stop)
if ($endpointTasks.Count -ne 1) { throw 'Exact endpoint task is missing or ambiguous.' }
$endpointTask = $endpointTasks[0]
$taskDefinition = [string](Export-ScheduledTask -TaskName $endpointTaskName -ErrorAction Stop)
$taskActions = @(
    $endpointTask.Actions | ForEach-Object {
        [ordered]@{
            execute = [string]$_.Execute
            arguments = [string]$_.Arguments
            workingDirectory = [string]$_.WorkingDirectory
        }
    }
)
if ([string]$endpointTask.Principal.UserId -ne 'SYSTEM' -or [string]$endpointTask.State -ne 'Running') {
    throw 'Exact endpoint task principal or state changed.'
}
if ($taskActions.Count -ne 1) { throw 'Exact endpoint task action count changed.' }
$taskCommand = ([string]$taskActions[0].execute) + ' ' + ([string]$taskActions[0].arguments)
if (
    $taskCommand.IndexOf($endpointWorkerPath, [StringComparison]::OrdinalIgnoreCase) -lt 0 -or
    $taskCommand.IndexOf($endpointConfigPath, [StringComparison]::OrdinalIgnoreCase) -lt 0
) { throw 'Exact endpoint task action no longer binds the pinned worker and configuration.' }

$consoleHostName = 'power' + 'shell.exe'
$iseHostName = 'power' + 'shell_ise.exe'
$processorRows = @(
    Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object { [string]$_.Name -eq $consoleHostName -or [string]$_.Name -eq $iseHostName } |
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

$result = [ordered]@{
    schema = 'argos_r21p1_current_premise_observation_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21P1_CURRENT_PREMISE_OBSERVED'
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
        definitionSha256 = Get-TextSha256 -Text $taskDefinition
        actions = $taskActions
    }
    healthyProcessor = $processorRows[0]
    processorSelectorSource = [ordered]@{
        path = 'work/GUIR9C3_PORTAL/payload/Apply-GUIR9C3DirectGuiPatch.ps1'
        sha256 = '0F9E1B32DE20CB8E6C04AC052853AB658C63EE08F5E480DAB8E588B079BA6872'
        lines = '189-226'
    }
    identicalConfigSelfSwapPerformedByQualifiedEndpoint = $true
    endpointConfigPreAndPostSha256Identical = $true
    taskOrProcessActionPerformed = $false
    processorTouched = $false
    imageBytesRead = $false
    sourceOrR21OutputBytesRead = $false
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
}
$result | ConvertTo-Json -Depth 12 -Compress
'PASS_R21P1_CURRENT_PREMISE_OBSERVED'
