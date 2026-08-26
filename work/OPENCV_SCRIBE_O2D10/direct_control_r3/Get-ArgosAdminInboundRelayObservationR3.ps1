[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Preflight) {
    [pscustomobject]@{
        schema = 'argos_admin_inbound_relay_direct_observation_r3_preflight_v1'
        state = 'PASS_ARGOS_ADMIN_INBOUND_RELAY_DIRECT_OBSERVATION_R3_PREFLIGHT'
        targetComputerName = 'DESKTOP-266P787'
        administrativeTokenRequired = $true
        targetExecuted = $false
        remoteInputSent = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 3
    return
}

if (-not $env:COMPUTERNAME.Equals('DESKTOP-266P787',[StringComparison]::OrdinalIgnoreCase)) {
    throw "Wrong Argos computer identity: $env:COMPUTERNAME"
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
$isAdministrator = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdministrator) { throw 'Argos observation requires an administrative token.' }

$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
if (-not (Test-Path -LiteralPath $portalRoot -PathType Container -ErrorAction Stop)) {
    throw "Protected portal root is absent: $portalRoot"
}
[void]@(Get-ChildItem -LiteralPath $portalRoot -Force -ErrorAction Stop | Select-Object -First 1)

$sectionErrors = New-Object Collections.Generic.List[object]

function Get-OptionalValue {
    param([AllowNull()][object]$Object,[string]$Name)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    return $null
}

function Add-SectionError {
    param([string]$Section,[string]$Path,[Exception]$Exception)
    $script:sectionErrors.Add([pscustomobject]@{
        section = $Section
        path = $Path
        exceptionType = $Exception.GetType().FullName
        message = $Exception.Message
        accessDenied = ($Exception -is [UnauthorizedAccessException] -or $Exception.Message -match '(?i)access.*denied|unauthorized')
    })
}

function Get-BoundedChildObservation {
    param([string]$Section,[string]$RelativeRoot,[int]$Limit)
    $path = Join-Path $portalRoot $RelativeRoot
    try {
        if (-not (Test-Path -LiteralPath $path -PathType Container -ErrorAction Stop)) {
            return [pscustomobject]@{ relativeRoot=$RelativeRoot; exists=$false; truncated=$false; rows=@() }
        }
        $observed = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop |
            Sort-Object Name |
            Select-Object -First ($Limit + 1))
        return [pscustomobject]@{
            relativeRoot = $RelativeRoot
            exists = $true
            truncated = ($observed.Count -gt $Limit)
            rows = @($observed | Select-Object -First $Limit | ForEach-Object {
                [pscustomobject]@{
                    name = $_.Name
                    isContainer = [bool]$_.PSIsContainer
                    length = if ($_.PSIsContainer) { $null } else { [long]$_.Length }
                    lastWriteUtc = $_.LastWriteTimeUtc.ToString('o')
                }
            })
        }
    }
    catch {
        Add-SectionError -Section $Section -Path $path -Exception $_.Exception
        return [pscustomobject]@{ relativeRoot=$RelativeRoot; exists=$null; truncated=$false; rows=@() }
    }
}

$taskRows = @()
$taskRowsTruncated = $false
try {
    $taskCandidates = @(Get-ScheduledTask -ErrorAction Stop |
        Where-Object { $_.TaskName -like 'ArgosProjectPortal*' } |
        Sort-Object TaskPath,TaskName |
        Select-Object -First 17)
    $taskRowsTruncated = $taskCandidates.Count -gt 16
    $taskRows = @($taskCandidates | Select-Object -First 16 | ForEach-Object {
        $task = $_
        $info = $null
        $infoError = $null
        try { $info = Get-ScheduledTaskInfo -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction Stop }
        catch { $infoError = $_.Exception.Message }
        [pscustomobject]@{
            taskPath = $task.TaskPath
            taskName = $task.TaskName
            state = [string]$task.State
            principal = [string]$task.Principal.UserId
            execute = if (@($task.Actions).Count) { [string]$task.Actions[0].Execute } else { $null }
            arguments = if (@($task.Actions).Count) { [string]$task.Actions[0].Arguments } else { $null }
            workingDirectory = if (@($task.Actions).Count) { [string]$task.Actions[0].WorkingDirectory } else { $null }
            lastRunUtc = if ($null -ne $info) { $info.LastRunTime.ToUniversalTime().ToString('o') } else { $null }
            lastTaskResult = if ($null -ne $info) { $info.LastTaskResult } else { $null }
            observationError = $infoError
        }
    })
}
catch { Add-SectionError -Section 'TASKS' -Path 'TaskScheduler:ArgosProjectPortal*' -Exception $_.Exception }

$configRows = @()
$configRowsTruncated = $false
$configRoot = Join-Path $portalRoot 'config'
try {
    if (-not (Test-Path -LiteralPath $configRoot -PathType Container -ErrorAction Stop)) { throw "Required config root is absent: $configRoot" }
    $configFiles = @(Get-ChildItem -LiteralPath $configRoot -File -Filter '*.json' -Force -ErrorAction Stop |
        Sort-Object Name |
        Select-Object -First 33)
    $configRowsTruncated = $configFiles.Count -gt 32
    $configRows = @($configFiles | Select-Object -First 32 | ForEach-Object {
        $file = $_
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            $config = $raw | ConvertFrom-Json -ErrorAction Stop
            $receiver = Get-OptionalValue $config 'receiver'
            $sender = Get-OptionalValue $config 'sender'
            [pscustomobject]@{
                name = $file.Name
                length = [long]$file.Length
                sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                nodeName = [string](Get-OptionalValue $config 'nodeName')
                testOnly = Get-OptionalValue $config 'testOnly'
                productionRoutingEnabled = Get-OptionalValue $config 'productionRoutingEnabled'
                receiverEnabled = Get-OptionalValue $receiver 'enabled'
                receiverBindIp = [string](Get-OptionalValue $receiver 'bindIp')
                receiverPort = Get-OptionalValue $receiver 'port'
                receiverOutputRoot = [string](Get-OptionalValue $receiver 'outputRoot')
                senderEnabled = Get-OptionalValue $sender 'enabled'
                senderWatchRoot = [string](Get-OptionalValue $sender 'watchRoot')
                senderSentRoot = [string](Get-OptionalValue $sender 'sentRoot')
                senderLocalBindIp = [string](Get-OptionalValue $sender 'localBindIp')
                senderRemoteIp = [string](Get-OptionalValue $sender 'remoteIp')
                senderPort = Get-OptionalValue $sender 'port'
            }
        }
        catch { Add-SectionError -Section 'CONFIG_FILE' -Path $file.FullName -Exception $_.Exception }
    })
}
catch { Add-SectionError -Section 'CONFIG_ROOT' -Path $configRoot -Exception $_.Exception }

$workerRows = @()
$workerRowsTruncated = $false
$binRoot = Join-Path $portalRoot 'bin'
try {
    if (-not (Test-Path -LiteralPath $binRoot -PathType Container -ErrorAction Stop)) { throw "Required bin root is absent: $binRoot" }
    $workerFiles = @(Get-ChildItem -LiteralPath $binRoot -File -Force -ErrorAction Stop |
        Where-Object { $_.Name -like 'ArgosProjectPortal*' } |
        Sort-Object Name |
        Select-Object -First 33)
    $workerRowsTruncated = $workerFiles.Count -gt 32
    $workerRows = @($workerFiles | Select-Object -First 32 | ForEach-Object {
        try {
            [pscustomobject]@{
                name = $_.Name
                length = [long]$_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash
                lastWriteUtc = $_.LastWriteTimeUtc.ToString('o')
            }
        }
        catch { Add-SectionError -Section 'WORKER_FILE' -Path $_.FullName -Exception $_.Exception }
    })
}
catch { Add-SectionError -Section 'BIN_ROOT' -Path $binRoot -Exception $_.Exception }

$processRows = @()
try {
    $processRows = @(Get-CimInstance Win32_Process -ErrorAction Stop |
        Where-Object {
            [string]$_.Name -like 'ArgosProjectPortal*' -or
            [string]$_.ExecutablePath -like "$portalRoot*" -or
            [string]$_.CommandLine -like "*$portalRoot*"
        } |
        Sort-Object ProcessId |
        Select-Object -First 32 |
        ForEach-Object {
            [pscustomobject]@{
                processId = $_.ProcessId
                parentProcessId = $_.ParentProcessId
                name = $_.Name
                executablePath = $_.ExecutablePath
                commandLine = $_.CommandLine
                creationDate = if ($null -ne $_.CreationDate) { ([DateTime]$_.CreationDate).ToUniversalTime().ToString('o') } else { $null }
            }
        })
}
catch { Add-SectionError -Section 'PROCESSES' -Path 'Win32_Process:ArgosProjectPortal*' -Exception $_.Exception }

$connectionRows = @()
try {
    $connectionRows = @(Get-NetTCPConnection -ErrorAction Stop |
        Where-Object { $_.LocalPort -in 48716,48717,48718 -or $_.RemotePort -in 48716,48717,48718 } |
        Sort-Object LocalPort,RemotePort,OwningProcess |
        Select-Object -First 64 LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess)
}
catch { Add-SectionError -Section 'CONNECTIONS' -Path 'TCP:48716-48718' -Exception $_.Exception }

$queueRows = @()
foreach ($parent in @('requests_from_gateway','to_jbod')) {
    $parentObservation = Get-BoundedChildObservation -Section 'QUEUE_PARENT' -RelativeRoot $parent -Limit 64
    $queueRows += $parentObservation
    if ($parentObservation.exists -eq $true) {
        $parentPath = Join-Path $portalRoot $parent
        try {
            $subroots = @(Get-ChildItem -LiteralPath $parentPath -Directory -Force -ErrorAction Stop |
                Sort-Object Name |
                Select-Object -First 17)
            if ($subroots.Count -gt 16) {
                Add-SectionError -Section 'QUEUE_ROOT_LIMIT' -Path $parentPath -Exception ([InvalidOperationException]::new('Queue root count exceeded the 16-row bound.'))
            }
            foreach ($subroot in @($subroots | Select-Object -First 16)) {
                $queueRows += Get-BoundedChildObservation -Section 'QUEUE_ROOT' -RelativeRoot "$parent\$($subroot.Name)" -Limit 64
            }
        }
        catch { Add-SectionError -Section 'QUEUE_SUBROOTS' -Path $parentPath -Exception $_.Exception }
    }
}

$errorRows = @($sectionErrors.ToArray())
$result = [ordered]@{
    schema = 'argos_inbound_relay_direct_observation_v3'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'OBSERVED_ARGOS_ADMIN_INBOUND_RELAY_READ_ONLY'
    computerName = $env:COMPUTERNAME
    administrativeToken = $isAdministrator
    protectedPortalRootReadable = $true
    portalRoot = $portalRoot
    taskRows = $taskRows
    taskRowsTruncated = $taskRowsTruncated
    configRows = $configRows
    configRowsTruncated = $configRowsTruncated
    workerRows = $workerRows
    workerRowsTruncated = $workerRowsTruncated
    processRows = $processRows
    connectionRows = $connectionRows
    queueRows = $queueRows
    sectionErrors = $errorRows
    sectionErrorCount = $errorRows.Count
    accessDenied = (@($errorRows | Where-Object accessDenied).Count -gt 0)
    imageBytesRead = $false
    jbodContacted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$result | ConvertTo-Json -Depth 9 -Compress | Set-Clipboard
