

#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskName = 'ArgosProjectPortal.JBOD.RequestReceiver.RO'
$endpointTaskName = 'ArgosProjectPortal.JBOD.Endpoint.RO'
$responseTaskName = 'ArgosProjectPortal.JBOD.ResponseSender.RO'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$transportPath = Join-Path $portalRoot 'bin\ArgosProjectPortal.Transport.ReviewOnly.V1.exe'
$hostPath = Join-Path $portalRoot 'bin\Invoke-ProjectPortalTaskHost.ps1'
$configPath = Join-Path $portalRoot 'config\JBOD_REQUEST_RECEIVER.json'
$expectedTaskXmlSha256 = '4BFCB64B8DB8934D727C13C12F37E15017CD630E973A751BD6188E9C825EF86C'
$expectedFileHashes = [ordered]@{
    $transportPath = '843629F44D8C310FAE201EAD808509FBECF3FC3C04D8D16B0D67CCADEFAE2DDB'
    $hostPath = '2D77E8E973B86E789C3A54702550B2A67E80E1E7EBB0AF51575F69ACEB157253'
    $configPath = '4DBB3677D26F6452EE6EFB295FECD951C59A9A2CCE40E3B6A262E9C5060259F0'
}
$expectedProcessorPid = 8504
$expectedProcessorCreatedUtc = [DateTime]::Parse('2026-08-25T15:38:27.7160450Z').ToUniversalTime()
$expectedProcessorCommandLine = '"powershell.exe" -WindowStyle Hidden -NoProfile -STA -ExecutionPolicy Bypass -File "C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Show-JbodAllWaferTray.ps1" -StateRoot "C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2" -StartHidden'

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-UnicodeTextSha256([string]$Text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::Unicode.GetBytes($Text)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Get-TaskRow([string]$Name) {
    $task = Get-ScheduledTask -TaskName $Name -ErrorAction Stop
    [pscustomobject]@{name=$Name;state=[string]$task.State;principal=[string]$task.Principal.UserId}
}

function Get-PortalResidentRows {
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        $line = [string]$_.CommandLine
        $line -match '(?i)endpoint_jbod\.json' -or $line -match '(?i)JBOD_RESPONSE_SENDER\.json'
    } | Sort-Object ProcessId | ForEach-Object {
        [pscustomobject]@{
            processId=[int]$_.ProcessId
            parentProcessId=[int]$_.ParentProcessId
            name=[string]$_.Name
            creationUtc=([DateTime]$_.CreationDate).ToUniversalTime().ToString('o')
            commandLine=[string]$_.CommandLine
        }
    })
}

function Get-ReceiverRows {
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        [string]$_.CommandLine -match '(?i)JBOD_REQUEST_RECEIVER\.json'
    } | Sort-Object ProcessId | ForEach-Object {
        [pscustomobject]@{
            processId=[int]$_.ProcessId
            parentProcessId=[int]$_.ParentProcessId
            name=[string]$_.Name
            creationUtc=([DateTime]$_.CreationDate).ToUniversalTime().ToString('o')
            commandLine=[string]$_.CommandLine
        }
    })
}

function Get-ProcessorRow {
    $rows = @(Get-CimInstance Win32_Process -Filter "ProcessId=$expectedProcessorPid" -ErrorAction Stop)
    if ($rows.Count -ne 1) { throw "Healthy processor PID cardinality changed: $($rows.Count)" }
    $row = $rows[0]
    $created = ([DateTime]$row.CreationDate).ToUniversalTime()
    if ($created -ne $expectedProcessorCreatedUtc) { throw "Healthy processor creation time changed: $($created.ToString('o'))" }
    if ([string]$row.CommandLine -cne $expectedProcessorCommandLine) { throw 'Healthy processor command line changed.' }
    [pscustomobject]@{
        processId=[int]$row.ProcessId
        parentProcessId=[int]$row.ParentProcessId
        name=[string]$row.Name
        creationUtc=$created.ToString('o')
        commandLine=[string]$row.CommandLine
    }
}

function Assert-StaticPremises {
    if (-not $env:COMPUTERNAME.Equals('A1025645101',[StringComparison]::OrdinalIgnoreCase)) { throw "Wrong computer: $env:COMPUTERNAME" }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'Administrative token is required.' }
    foreach ($entry in $expectedFileHashes.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $entry.Key -PathType Leaf)) { throw "Pinned installed file is absent: $($entry.Key)" }
        $actual = Get-Sha256 $entry.Key
        if ($actual -ne $entry.Value) { throw "Pinned installed file hash changed: $($entry.Key) => $actual" }
    }
    $taskXmlSha = Get-UnicodeTextSha256 (Export-ScheduledTask -TaskName $taskName -ErrorAction Stop)
    if ($taskXmlSha -ne $expectedTaskXmlSha256) { throw "Receiver task XML hash changed: $taskXmlSha" }
    $receiverTask = Get-TaskRow $taskName
    if ($receiverTask.principal -ne 'SYSTEM') { throw "Receiver task principal changed: $($receiverTask.principal)" }
    $endpointTask = Get-TaskRow $endpointTaskName
    $responseTask = Get-TaskRow $responseTaskName
    if ($endpointTask.state -ne 'Running' -or $endpointTask.principal -ne 'SYSTEM') { throw 'Endpoint task is not the pinned running SYSTEM task.' }
    if ($responseTask.state -ne 'Running' -or $responseTask.principal -ne 'SYSTEM') { throw 'Response sender task is not the pinned running SYSTEM task.' }
    $processor = Get-ProcessorRow
    [pscustomobject]@{receiverTask=$receiverTask;endpointTask=$endpointTask;responseTask=$responseTask;processor=$processor}
}

$startCount = 0
$mutationAttempted = $false
try {
    $static = Assert-StaticPremises
    $residentBefore = @(Get-PortalResidentRows)
    if ($residentBefore.Count -ne 2) { throw "Endpoint/response resident process cardinality changed before action: $($residentBefore.Count)" }
    $residentBeforeJson = $residentBefore | ConvertTo-Json -Depth 6 -Compress
    $receiverBefore = @(Get-ReceiverRows)
    $listenerBefore = @(Get-NetTCPConnection -State Listen -LocalPort 48716 -ErrorAction SilentlyContinue)
    if ($receiverBefore.Count -ne 0) { throw "Receiver process is no longer absent: $($receiverBefore.Count)" }
    if ($listenerBefore.Count -ne 0) { throw "Receiver listener is no longer absent: $($listenerBefore.Count)" }
    if ($static.receiverTask.state -ne 'Ready') { throw "Receiver task is no longer in the observed Ready state: $($static.receiverTask.state)" }

    if ($Preflight) {
        [ordered]@{
            schema='argos_o2d10_jbod_receiver_recovery_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
            state='PASS_O2D10_JBOD_RECEIVER_RECOVERY_PREFLIGHT';computerName=$env:COMPUTERNAME
            receiverTask=$static.receiverTask;endpointTask=$static.endpointTask;responseTask=$static.responseTask
            residentPortalProcesses=$residentBefore;healthyProcessor=$static.processor
            receiverProcessCount=0;listener48716Count=0;targetExecuted=$false;mutationsPerformed=$false
            requestRetryPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
        } | ConvertTo-Json -Depth 8
        return
    }

    $mutationAttempted = $true
    $startCount = 1
    Start-ScheduledTask -TaskName $taskName -ErrorAction Stop

    $receiverAfter = @()
    $listenerAfter = @()
    $receiverTaskAfter = $null
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 500
        $receiverTaskAfter = Get-TaskRow $taskName
        $receiverAfter = @(Get-ReceiverRows)
        $listenerAfter = @(Get-NetTCPConnection -State Listen -LocalPort 48716 -ErrorAction SilentlyContinue)
        if ($receiverTaskAfter.state -eq 'Running' -and $receiverAfter.Count -eq 1 -and $listenerAfter.Count -eq 1) { break }
    } while ([DateTime]::UtcNow -lt $deadline)

    if ($receiverTaskAfter.state -ne 'Running') { throw "Receiver task failed to remain Running: $($receiverTaskAfter.state)" }
    if ($receiverAfter.Count -ne 1) { throw "Receiver process cardinality after start is $($receiverAfter.Count), expected 1." }
    if ($listenerAfter.Count -ne 1) { throw "Port 48716 listener cardinality after start is $($listenerAfter.Count), expected 1." }
    $listenerOwner = [int]$listenerAfter[0].OwningProcess
    if ($receiverAfter.processId -notcontains $listenerOwner) { throw "Port 48716 listener owner is not an exact receiver process: $listenerOwner" }

    $residentAfter = @(Get-PortalResidentRows)
    $residentAfterJson = $residentAfter | ConvertTo-Json -Depth 6 -Compress
    if ($residentAfterJson -cne $residentBeforeJson) { throw 'Endpoint/response resident processes changed during receiver recovery.' }
    $processorAfter = Get-ProcessorRow
    $endpointAfter = Get-TaskRow $endpointTaskName
    $responseAfter = Get-TaskRow $responseTaskName
    if ($endpointAfter.state -ne 'Running' -or $responseAfter.state -ne 'Running') { throw 'Endpoint or response-sender task changed during receiver recovery.' }

    [ordered]@{
        schema='argos_o2d10_jbod_receiver_recovery_terminal_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O2D10_JBOD_REQUEST_RECEIVER_RECOVERED';computerName=$env:COMPUTERNAME
        receiverTask=$receiverTaskAfter;receiverProcesses=$receiverAfter
        listener48716=[ordered]@{localAddress=[string]$listenerAfter[0].LocalAddress;localPort=[int]$listenerAfter[0].LocalPort;owningProcess=$listenerOwner}
        endpointTask=$endpointAfter;responseSenderTask=$responseAfter;residentPortalProcessesUnchanged=$true
        healthyProcessor=$processorAfter;healthyProcessorUnchanged=$true
        receiverTaskStartCount=$startCount;requestRetryPerformed=$false;requestRepublished=$false
        queueMutationPerformed=$false;otherTaskOrProcessActionPerformed=$false;installedBytesChanged=$false
        sourceMutationPerformed=$false;imageBytesRead=$false;providerActivated=$false
        reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 9 -Compress | Set-Clipboard
}
catch {
    if ($Preflight) { throw }
    [ordered]@{
        schema='argos_o2d10_jbod_receiver_recovery_terminal_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='HOLD_O2D10_JBOD_REQUEST_RECEIVER_RECOVERY';computerName=$env:COMPUTERNAME
        errorType=$_.Exception.GetType().FullName;errorMessage=$_.Exception.Message
        mutationAttempted=$mutationAttempted;receiverTaskStartCount=$startCount
        requestRetryPerformed=$false;requestRepublished=$false;queueMutationPerformed=$false
        otherTaskOrProcessActionPerformed=$false;installedBytesChanged=$false;sourceMutationPerformed=$false
        imageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 7 -Compress | Set-Clipboard
}


