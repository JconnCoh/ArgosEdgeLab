#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expectedComputerName = 'A1025645101'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$requestId = 'REQ_20260826T015418549Z_F5D3732576F9'
$taskNames = @(
    'ArgosProjectPortal.JBOD.Endpoint.RO',
    'ArgosProjectPortal.JBOD.ResponseSender.RO',
    'ArgosProjectPortal.JBOD.RequestReceiver.RO'
)

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d10_jbod_receiver_admin_observation_preflight_v1'
        state = 'PASS_O2D10_JBOD_RECEIVER_ADMIN_OBSERVATION_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        portalRoot = $portalRoot
        requestId = $requestId
        remoteInputSent = $false
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 4
    return
}

$errors = New-Object 'System.Collections.Generic.List[object]'
$tasks = New-Object 'System.Collections.Generic.List[object]'
$processes = New-Object 'System.Collections.Generic.List[object]'
$connections = New-Object 'System.Collections.Generic.List[object]'

function Add-ErrorRow([string]$Section, [string]$Path, [Exception]$Exception) {
    $errors.Add([pscustomobject]@{section=$Section;path=$Path;errorType=$Exception.GetType().FullName;errorMessage=$Exception.Message})
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$administrativeToken = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$portalRootReadable = $false
try {
    if (Test-Path -LiteralPath $portalRoot -PathType Container -ErrorAction Stop) {
        [void]@(Get-ChildItem -LiteralPath $portalRoot -Force -ErrorAction Stop | Select-Object -First 1)
        $portalRootReadable = $true
    }
}
catch { Add-ErrorRow -Section 'PORTAL_ROOT' -Path $portalRoot -Exception $_.Exception }

foreach ($taskName in $taskNames) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        $action = @($task.Actions | Select-Object -First 1)
        $tasks.Add([pscustomobject]@{
            name = $taskName
            present = $true
            state = [string]$task.State
            principal = [string]$task.Principal.UserId
            execute = if ($action.Count) { [string]$action[0].Execute } else { '' }
            arguments = if ($action.Count) { [string]$action[0].Arguments } else { '' }
            lastRunUtc = if ($info.LastRunTime.Year -gt 1900) { $info.LastRunTime.ToUniversalTime().ToString('o') } else { $null }
            lastTaskResult = [int64]$info.LastTaskResult
        })
    }
    catch {
        $tasks.Add([pscustomobject]@{name=$taskName;present=$false;state='ABSENT';principal='';execute='';arguments='';lastRunUtc=$null;lastTaskResult=$null})
        Add-ErrorRow -Section 'PORTAL_TASK' -Path $taskName -Exception $_.Exception
    }
}

try {
    $rows = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        [string]$_.CommandLine -match '(?i)ArgosProjectPortal|JBOD_REQUEST_RECEIVER'
    } | Select-Object -First 32)
    foreach ($row in $rows) {
        $processes.Add([pscustomobject]@{
            processId = [int]$row.ProcessId
            parentProcessId = [int]$row.ParentProcessId
            name = [string]$row.Name
            executablePath = [string]$row.ExecutablePath
            commandLine = [string]$row.CommandLine
            creationDate = if ($null -eq $row.CreationDate) { $null } else { ([datetime]$row.CreationDate).ToUniversalTime().ToString('o') }
        })
    }
}
catch { Add-ErrorRow -Section 'PORTAL_PROCESS' -Path 'Win32_Process' -Exception $_.Exception }

try {
    $rows = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.LocalPort -eq 48716 -or $_.RemotePort -eq 48717 } | Select-Object -First 16)
    foreach ($row in $rows) {
        $connections.Add([pscustomobject]@{
            localAddress=[string]$row.LocalAddress;localPort=[int]$row.LocalPort
            remoteAddress=[string]$row.RemoteAddress;remotePort=[int]$row.RemotePort
            state=[string]$row.State;owningProcess=[int]$row.OwningProcess
        })
    }
}
catch { Add-ErrorRow -Section 'PORTAL_CONNECTION' -Path 'TCP48716' -Exception $_.Exception }

$configPath = Join-Path $portalRoot 'config\JBOD_REQUEST_RECEIVER.json'
$configRow = $null
$receiverOutputRoot = $null
try {
    $config = Get-Content -Raw -LiteralPath $configPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    $receiverOutputRoot = [string]$config.receiver.outputRoot
    $configRow = [pscustomobject]@{
        path=$configPath;bytes=(Get-Item -LiteralPath $configPath).Length;sha256=Get-Sha256 $configPath
        nodeName=[string]$config.nodeName;receiverEnabled=[bool]$config.receiver.enabled
        bindIp=[string]$config.receiver.bindIp;port=[int]$config.receiver.port;outputRoot=$receiverOutputRoot
        productionRoutingEnabled=[bool]$config.productionRoutingEnabled
    }
}
catch { Add-ErrorRow -Section 'RECEIVER_CONFIG' -Path $configPath -Exception $_.Exception }

$exactRequestRows = @()
if (-not [string]::IsNullOrWhiteSpace($receiverOutputRoot)) {
    try {
        if (Test-Path -LiteralPath $receiverOutputRoot -PathType Container -ErrorAction Stop) {
            $exactRequestRows = @(Get-ChildItem -LiteralPath $receiverOutputRoot -Force -ErrorAction Stop | Where-Object {
                $_.Name.IndexOf($requestId,[StringComparison]::OrdinalIgnoreCase) -ge 0
            } | Select-Object -First 8 Name,FullName,PSIsContainer,Length,LastWriteTimeUtc)
        }
    }
    catch { Add-ErrorRow -Section 'RECEIVER_OUTPUT' -Path $receiverOutputRoot -Exception $_.Exception }
}

$taskArray = @($tasks.ToArray())
$processArray = @($processes.ToArray())
$connectionArray = @($connections.ToArray())
$errorArray = @($errors.ToArray())
$receiverTask = @($taskArray | Where-Object { $_.name -eq 'ArgosProjectPortal.JBOD.RequestReceiver.RO' })
$receiverProcesses = @($processArray | Where-Object { $_.commandLine -match '(?i)JBOD_REQUEST_RECEIVER' })
$listenerRows = @($connectionArray | Where-Object { $_.localPort -eq 48716 -and $_.state -eq 'Listen' })
$disposition = if ($receiverTask.Count -eq 1 -and $receiverTask[0].present -and $receiverTask[0].state -eq 'Running' -and $receiverProcesses.Count -ge 1 -and $listenerRows.Count -eq 1) {
    'RECEIVER_HEALTHY'
} elseif ($receiverTask.Count -eq 1 -and $receiverTask[0].present -and $receiverTask[0].state -ne 'Running') {
    'RECEIVER_TASK_NOT_RUNNING'
} elseif ($receiverTask.Count -eq 1 -and -not $receiverTask[0].present) {
    'RECEIVER_TASK_ABSENT'
} else {
    'RECEIVER_PROCESS_OR_LISTENER_MISSING'
}
$state = if ($env:COMPUTERNAME -eq $expectedComputerName -and $administrativeToken -and $portalRootReadable) {
    'PASS_O2D10_JBOD_RECEIVER_ADMIN_READ_ONLY_OBSERVATION'
} else {
    'HOLD_O2D10_JBOD_RECEIVER_ADMIN_READ_ONLY_OBSERVATION'
}

[ordered]@{
    schema='argos_o2d10_jbod_receiver_admin_read_only_observation_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state=$state
    disposition=$disposition
    computerName=$env:COMPUTERNAME
    userName=$identity.Name
    administrativeToken=$administrativeToken
    portalRootReadable=$portalRootReadable
    requestId=$requestId
    tasks=$taskArray
    processes=$processArray
    tcp48716=$connectionArray
    receiverConfig=$configRow
    exactRequestRows=$exactRequestRows
    sectionErrors=$errorArray
    sectionErrorCount=$errorArray.Count
    requestRetried=$false
    queueMutationPerformed=$false
    taskOrProcessActionPerformed=$false
    imageBytesRead=$false
    providerActivated=$false
    healthyProcessorTouched=$false
    mutationsPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 10 -Compress | Set-Clipboard
