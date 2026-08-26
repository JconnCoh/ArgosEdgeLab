#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$requestId = 'REQ_20260826T015418549Z_F5D3732576F9'
$responsePrefix = 'R_AAB6C504C28E_'
$expectedComputerName = 'DESKTOP-266P787'
$maximumItemsPerRoot = 256
$sectionErrors = New-Object 'System.Collections.Generic.List[object]'
$rootRows = New-Object 'System.Collections.Generic.List[object]'
$matchRows = New-Object 'System.Collections.Generic.List[object]'
$taskRows = New-Object 'System.Collections.Generic.List[object]'
$connectionRows = New-Object 'System.Collections.Generic.List[object]'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d10_exact_request_route_observation_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D10_EXACT_REQUEST_ROUTE_OBSERVATION_PREFLIGHT'
        expectedComputerName = $expectedComputerName
        portalRoot = $portalRoot
        requestId = $requestId
        responsePrefix = $responsePrefix
        maximumItemsPerRoot = $maximumItemsPerRoot
        targetExecuted = $false
        remoteInputSent = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 4
    return
}

function Add-SectionError([string]$Section, [string]$Path, [Exception]$Exception) {
    $sectionErrors.Add([pscustomobject]@{
        section = $Section
        path = $Path
        errorType = $Exception.GetType().FullName
        errorMessage = $Exception.Message
    })
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
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
        [void]@(Get-ChildItem -LiteralPath $portalRoot -Directory -Force -ErrorAction Stop | Select-Object -First 1)
        $portalRootReadable = $true
    }
}
catch { Add-SectionError -Section 'PORTAL_ROOT' -Path $portalRoot -Exception $_.Exception }

$relativeRoots = @(
    'requests_from_gateway\pending',
    'requests_from_gateway\receipts',
    'to_jbod\pending',
    'to_jbod\sent',
    'to_jbod\sent\acks',
    'from_jbod\pending',
    'from_jbod\receipts',
    'responses_from_jbod\pending',
    'responses_from_jbod\receipts',
    'to_gateway\pending',
    'to_gateway\sent',
    'to_gateway\sent\acks'
)

foreach ($relativeRoot in $relativeRoots) {
    $fullRoot = Join-Path $portalRoot $relativeRoot
    try {
        $exists = Test-Path -LiteralPath $fullRoot -PathType Container -ErrorAction Stop
        $enumeratedCount = 0
        $truncated = $false
        if ($exists) {
            $items = @(Get-ChildItem -LiteralPath $fullRoot -Force -ErrorAction Stop | Select-Object -First ($maximumItemsPerRoot + 1))
            $truncated = $items.Count -gt $maximumItemsPerRoot
            if ($truncated) { $items = @($items | Select-Object -First $maximumItemsPerRoot) }
            $enumeratedCount = $items.Count
            foreach ($item in $items) {
                if ($item.Name -eq ($requestId + '.ready') -or
                    $item.Name -eq ($requestId + '.receipt.json') -or
                    $item.Name.StartsWith($responsePrefix, [StringComparison]::OrdinalIgnoreCase) -or
                    $item.Name.IndexOf($requestId, [StringComparison]::OrdinalIgnoreCase) -ge 0) {
                    $relativePath = $relativeRoot + '\' + $item.Name
                    $row = [ordered]@{
                        relativeRoot = $relativeRoot
                        relativePath = $relativePath
                        name = $item.Name
                        isContainer = [bool]$item.PSIsContainer
                        length = if ($item.PSIsContainer) { $null } else { [int64]$item.Length }
                        lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
                        sha256 = $null
                    }
                    if (-not $item.PSIsContainer -and [int64]$item.Length -le 1048576) {
                        $row.sha256 = Get-Sha256 -Path $item.FullName
                    }
                    $matchRows.Add([pscustomobject]$row)
                }
            }
        }
        $rootRows.Add([pscustomobject]@{
            relativeRoot = $relativeRoot
            exists = $exists
            enumeratedCount = $enumeratedCount
            truncated = $truncated
        })
    }
    catch { Add-SectionError -Section 'QUEUE_ROOT' -Path $fullRoot -Exception $_.Exception }
}

$taskNames = @(
    'ArgosProjectPortal.Argos.Endpoint.RO',
    'ArgosProjectPortal.Argos.RequestReceiver.RO',
    'ArgosProjectPortal.Argos.RequestSender.RO',
    'ArgosProjectPortal.Argos.ResponseRelay.RO',
    'ArgosProjectPortal.Argos.Router.RO'
)
foreach ($taskName in $taskNames) {
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        $info = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
        $taskRows.Add([pscustomobject]@{
            taskName = $taskName
            state = [string]$task.State
            principal = [string]$task.Principal.UserId
            lastRunUtc = if ($info.LastRunTime.Year -gt 1900) { $info.LastRunTime.ToUniversalTime().ToString('o') } else { $null }
            lastTaskResult = [int64]$info.LastTaskResult
        })
    }
    catch { Add-SectionError -Section 'PORTAL_TASK' -Path $taskName -Exception $_.Exception }
}

try {
    $connections = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object {
        $_.LocalPort -in @(48715, 48717) -or $_.RemotePort -in @(48716, 48718)
    } | Select-Object -First 32)
    foreach ($connection in $connections) {
        $connectionRows.Add([pscustomobject]@{
            localAddress = [string]$connection.LocalAddress
            localPort = [int]$connection.LocalPort
            remoteAddress = [string]$connection.RemoteAddress
            remotePort = [int]$connection.RemotePort
            state = [string]$connection.State
            owningProcess = [int]$connection.OwningProcess
        })
    }
}
catch { Add-SectionError -Section 'PORTAL_CONNECTION' -Path 'Get-NetTCPConnection' -Exception $_.Exception }

$matchArray = @($matchRows.ToArray())
$responseRows = @($matchArray | Where-Object { $_.name.StartsWith($responsePrefix, [StringComparison]::OrdinalIgnoreCase) })
$sentToJbodRows = @($matchArray | Where-Object { $_.relativeRoot -eq 'to_jbod\sent' -and $_.name -eq ($requestId + '.ready') })
$pendingBeforeJbodRows = @($matchArray | Where-Object {
    $_.name -like ($requestId + '*') -and $_.relativeRoot -in @('requests_from_gateway\pending', 'to_jbod\pending')
})
$receiptRows = @($matchArray | Where-Object { $_.name -eq ($requestId + '.receipt.json') })

$disposition = 'HOLD_O2D10_ROUTE_IDENTITY_NOT_FOUND'
if ($responseRows.Count -gt 0) { $disposition = 'TERMINAL_RESPONSE_PRESENT_IN_ARGOS_RETURN_ROUTE' }
elseif ($sentToJbodRows.Count -eq 1) { $disposition = 'REQUEST_SENT_TO_JBOD_RESPONSE_PENDING' }
elseif ($pendingBeforeJbodRows.Count -gt 0) { $disposition = 'REQUEST_STALLED_BEFORE_JBOD' }

$sectionErrorArray = @($sectionErrors.ToArray())
$requiredTasksHealthy = @($taskRows.ToArray() | Where-Object { $_.state -ne 'Running' -or $_.principal -ne 'SYSTEM' }).Count -eq 0 -and $taskRows.Count -eq 5
$state = if ($env:COMPUTERNAME -eq $expectedComputerName -and $administrativeToken -and $portalRootReadable -and $sectionErrorArray.Count -eq 0) {
    'PASS_O2D10_EXACT_REQUEST_ROUTE_READ_ONLY_OBSERVATION'
} else {
    'HOLD_O2D10_EXACT_REQUEST_ROUTE_READ_ONLY_OBSERVATION'
}

$result = [ordered]@{
    schema = 'argos_o2d10_exact_request_route_observation_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = $state
    disposition = $disposition
    computerName = $env:COMPUTERNAME
    userName = $identity.Name
    administrativeToken = $administrativeToken
    portalRoot = $portalRoot
    portalRootReadable = $portalRootReadable
    requestId = $requestId
    responsePrefix = $responsePrefix
    rootRows = @($rootRows.ToArray())
    matchRows = $matchArray
    receiptRows = $receiptRows
    responseRows = $responseRows
    sentToJbodRows = $sentToJbodRows
    pendingBeforeJbodRows = $pendingBeforeJbodRows
    taskRows = @($taskRows.ToArray())
    requiredTasksHealthy = $requiredTasksHealthy
    connectionRows = @($connectionRows.ToArray())
    sectionErrors = $sectionErrorArray
    sectionErrorCount = $sectionErrorArray.Count
    accessDenied = @($sectionErrorArray | Where-Object { $_.errorMessage -match '(?i)access.*denied|unauthorized' }).Count -gt 0
    requestRetried = $false
    jbodContactedByObservation = $false
    imageBytesRead = $false
    queueMutationPerformed = $false
    taskOrProcessActionPerformed = $false
    providerActivated = $false
    healthyProcessorTouched = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

$result | ConvertTo-Json -Depth 12 -Compress | Set-Clipboard
