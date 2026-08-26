[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,

    [switch]$Preflight,

    [switch]$Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-TerminalResult {
    param(
        [Parameter(Mandatory = $true)][string]$State,
        [Parameter(Mandatory = $true)][bool]$MutationsPerformed,
        [AllowNull()][object]$Detail
    )
    [pscustomobject]@{
        schema = 'argos_o2d10_argos_tunnel_terminal_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = $State
        detail = $Detail
        mutationsPerformed = $MutationsPerformed
        argosOrJbodProcessActionPerformed = $false
        remoteFileMutationPerformed = $false
        jbodContacted = $false
        publicationPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 7
}

if ($Preflight -eq $Apply) {
    throw 'Specify exactly one of -Preflight or -Apply.'
}
if (-not (Test-Path -LiteralPath $InvocationManifest -PathType Leaf)) {
    throw "Invocation manifest is absent: $InvocationManifest"
}

$invocation = Get-Content -LiteralPath $InvocationManifest -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_o2d10_argos_tunnel_invocation_v1') {
    throw 'Invocation manifest schema changed.'
}
if (-not [bool]$invocation.reviewOnly -or [bool]$invocation.productionRoutingEnabled) {
    throw 'Invocation authority changed.'
}

$rustDeskPath = [IO.Path]::GetFullPath([string]$invocation.rustDeskPath)
$expectedRustDeskHash = ([string]$invocation.rustDeskSha256).ToUpperInvariant()
$gatewayPeer = [string]$invocation.gatewayPeer
$localPort = [int]$invocation.localPort
$targetHost = [string]$invocation.targetHost
$targetPort = [int]$invocation.targetPort
$waitSeconds = [int]$invocation.waitSeconds
$preservedPredecessorPort = [int]$invocation.preservedPredecessorPort

if ($gatewayPeer -ne '10.66.81.84' -or $targetHost -ne '10.20.70.241') {
    throw 'Tunnel peer or target host changed.'
}
if ($localPort -ne 15986 -or $targetPort -ne 5985 -or $preservedPredecessorPort -ne 15985) {
    throw 'Tunnel port contract changed.'
}
if ($waitSeconds -lt 5 -or $waitSeconds -gt 30) {
    throw 'Tunnel waitSeconds is outside the bounded range.'
}
if (-not (Test-Path -LiteralPath $rustDeskPath -PathType Leaf)) {
    throw "RustDesk executable is absent: $rustDeskPath"
}
$actualRustDeskHash = (Get-FileHash -LiteralPath $rustDeskPath -Algorithm SHA256).Hash
if ($actualRustDeskHash -ne $expectedRustDeskHash) {
    throw "RustDesk executable hash changed: $actualRustDeskHash"
}
foreach ($requiredCommand in @('Get-NetTCPConnection', 'Get-CimInstance', 'Start-Process', 'Stop-Process')) {
    if (-not (Get-Command $requiredCommand -ErrorAction SilentlyContinue)) {
        throw "Required command is unavailable: $requiredCommand"
    }
}

$predecessorListener = @(Get-NetTCPConnection -State Listen -LocalPort $preservedPredecessorPort -ErrorAction SilentlyContinue)
if ($predecessorListener.Count -ne 1) {
    throw "Preserved predecessor listener cardinality changed: $($predecessorListener.Count)"
}
$newPortListener = @(Get-NetTCPConnection -State Listen -LocalPort $localPort -ErrorAction SilentlyContinue)
if ($newPortListener.Count -ne 0) {
    throw "Fresh local port is already occupied: $localPort"
}
$interactiveRows = @(Get-Process -Name RustDesk -ErrorAction SilentlyContinue | Where-Object {
    $_.MainWindowTitle -eq $gatewayPeer
})
if ($interactiveRows.Count -ne 1) {
    throw "Exact interactive RustDesk session cardinality changed: $($interactiveRows.Count)"
}

$argumentList = @('--port-forward', $gatewayPeer, [string]$localPort, $targetHost, [string]$targetPort)
$expectedCommandToken = "--port-forward $gatewayPeer $localPort $targetHost $targetPort"
$baselineTunnelRows = @(Get-CimInstance Win32_Process -Filter "Name='RustDesk.exe'" | Where-Object {
    [string]$_.CommandLine -match [regex]::Escape($expectedCommandToken)
})
if ($baselineTunnelRows.Count -ne 0) {
    throw 'A matching fresh tunnel process already exists.'
}

if ($Preflight) {
    Write-TerminalResult -State 'PASS_O2D10_ARGOS_TUNNEL_PREFLIGHT' -MutationsPerformed $false -Detail ([pscustomobject]@{
        rustDeskPath = $rustDeskPath
        rustDeskSha256 = $actualRustDeskHash
        interactiveRustDeskProcessId = $interactiveRows[0].Id
        gatewayPeer = $gatewayPeer
        localPort = $localPort
        targetHost = $targetHost
        targetPort = $targetPort
        preservedPredecessorPort = $preservedPredecessorPort
        predecessorListenerProcessId = $predecessorListener[0].OwningProcess
        newPortAvailable = $true
        targetExecuted = $false
    })
    return
}

$startedProcess = $null
$newTunnelRows = @()
try {
    $startedProcess = Start-Process -FilePath $rustDeskPath -ArgumentList $argumentList -WindowStyle Hidden -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds($waitSeconds)
    do {
        Start-Sleep -Milliseconds 250
        $newPortListener = @(Get-NetTCPConnection -State Listen -LocalPort $localPort -ErrorAction SilentlyContinue)
        $newTunnelRows = @(Get-CimInstance Win32_Process -Filter "Name='RustDesk.exe'" | Where-Object {
            [string]$_.CommandLine -match [regex]::Escape($expectedCommandToken)
        })
    } while (($newPortListener.Count -ne 1 -or $newTunnelRows.Count -ne 1) -and [DateTime]::UtcNow -lt $deadline)

    if ($newPortListener.Count -ne 1 -or $newTunnelRows.Count -ne 1) {
        throw "Fresh tunnel did not reach one listener and one process within $waitSeconds seconds."
    }
    if ([int]$newPortListener[0].OwningProcess -ne [int]$newTunnelRows[0].ProcessId) {
        throw 'Fresh listener owner does not match the exact new tunnel process.'
    }

    Write-TerminalResult -State 'PASS_O2D10_ARGOS_TUNNEL_STARTED' -MutationsPerformed $true -Detail ([pscustomobject]@{
        tunnelProcessId = [int]$newTunnelRows[0].ProcessId
        tunnelCommandLine = [string]$newTunnelRows[0].CommandLine
        localPort = $localPort
        targetHost = $targetHost
        targetPort = $targetPort
        predecessorPortPreserved = [bool](@(Get-NetTCPConnection -State Listen -LocalPort $preservedPredecessorPort -ErrorAction SilentlyContinue).Count -eq 1)
    })
    exit 0
}
catch {
    $rollbackIds = @($newTunnelRows | ForEach-Object { [int]$_.ProcessId } | Sort-Object -Unique)
    if ($startedProcess -and -not $startedProcess.HasExited) {
        $rollbackIds = @($rollbackIds + [int]$startedProcess.Id | Sort-Object -Unique)
    }
    foreach ($rollbackId in $rollbackIds) {
        Stop-Process -Id $rollbackId -Force -ErrorAction SilentlyContinue
    }
    Write-TerminalResult -State 'FAIL_O2D10_ARGOS_TUNNEL_START_ROLLED_BACK' -MutationsPerformed ([bool]($rollbackIds.Count -gt 0)) -Detail ([pscustomobject]@{
        message = $_.Exception.Message
        rolledBackProcessIds = $rollbackIds
        predecessorPortPreserved = [bool](@(Get-NetTCPConnection -State Listen -LocalPort $preservedPredecessorPort -ErrorAction SilentlyContinue).Count -eq 1)
    })
    exit 1
}
