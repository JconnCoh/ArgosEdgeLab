Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$schema = 'argos_exact_o2d4_pending_quarantine_r5_terminal_v1'
$source = 'C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\REQ_O2D4.ready'
$sentPath = 'C:\ProgramData\ArgosProjectPortalRO\to_jbod\sent\REQ_O2D4.ready'
$quarantineParent = 'C:\ProgramData\ArgosProjectPortalRO\to_jbod\quarantine'
$destination = 'C:\ProgramData\ArgosProjectPortalRO\to_jbod\quarantine\REQ_O2D4.ready.WITHDRAWN_20260826T180500Z'
$expectedLastWriteUtc = [DateTime]::Parse('2026-08-24T23:00:52.4597358Z').ToUniversalTime()
$expectedFiles = @(
    [pscustomobject]@{relativePath='payload/ArgosOpenCvScribeV1.py';bytes=38290L;sha256='3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'},
    [pscustomobject]@{relativePath='payload/Invoke-O2D4ScribeEndpoint.ps1';bytes=13658L;sha256='7FB8B54B18D4D446F4C7AC2FFCB3898721222B93FE4B17E69B681B6E6F85C8C2'},
    [pscustomobject]@{relativePath='payload/O2D4_REFS.zip';bytes=14855150L;sha256='56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'},
    [pscustomobject]@{relativePath='payload/O2D4_SLOT16_JOB.json';bytes=2316L;sha256='10FA06D089A7F0918AFA3073033D8F92C0F7D94A625FD8DB4F2C730B12BF3669'},
    [pscustomobject]@{relativePath='PORTAL_REQUEST_MANIFEST.json';bytes=8145L;sha256='63E93EFC681EAE63E84F9306F57D581E865BB1E1B06D58FDAC8D4586E645F818'},
    [pscustomobject]@{relativePath='PORTAL_REQUEST_MANIFEST.sig';bytes=384L;sha256='707C1C3A320E133798BA514A216AC99A31BE940B626A2F5C67CFAF728DD26FE8'}
)

function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-ExactTreeRows([string]$Root) {
    $resolvedRoot = (Resolve-Path -LiteralPath $Root -ErrorAction Stop).Path.TrimEnd('\')
    $rows = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Force -ErrorAction Stop | ForEach-Object {
        [pscustomobject]@{
            relativePath = $_.FullName.Substring($resolvedRoot.Length + 1).Replace('\','/')
            bytes = [int64]$_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } | Sort-Object relativePath)
    return $rows
}

function Assert-ExactTree([string]$Root) {
    $rows = @(Get-ExactTreeRows -Root $Root)
    Assert-True ($rows.Count -eq $expectedFiles.Count) "Exact O2D4 tree file count changed: $($rows.Count)"
    $directories = @(Get-ChildItem -LiteralPath $Root -Recurse -Directory -Force -ErrorAction Stop)
    Assert-True ($directories.Count -eq 1) "Exact O2D4 tree directory count changed: $($directories.Count)"
    Assert-True ($directories[0].Name -eq 'payload') "Exact O2D4 tree contains an unexpected directory: $($directories[0].FullName)"
    foreach ($expected in $expectedFiles) {
        $matches = @($rows | Where-Object { $_.relativePath -eq $expected.relativePath })
        Assert-True ($matches.Count -eq 1) "Exact O2D4 file missing or duplicated: $($expected.relativePath)"
        Assert-True ([int64]$matches[0].bytes -eq [int64]$expected.bytes) "Exact O2D4 byte count changed: $($expected.relativePath)"
        Assert-True ([string]$matches[0].sha256 -eq [string]$expected.sha256) "Exact O2D4 hash changed: $($expected.relativePath)"
    }
    return $rows
}

function Set-TerminalClipboard([object]$Value) {
    $Value | ConvertTo-Json -Depth 10 -Compress | Set-Clipboard
}

$parentCreated = $false
$moved = $false
$rollbackAttempted = $false
$rollbackSucceeded = $false
$preMoveRows = @()
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    Assert-True ($env:COMPUTERNAME -eq 'DESKTOP-266P787') "Wrong target computer: $env:COMPUTERNAME"
    Assert-True $isAdmin 'Administrative token is required.'
    Assert-True (Test-Path -LiteralPath $source -PathType Container) "Exact pending O2D4 source is absent: $source"
    Assert-True (-not (Test-Path -LiteralPath $sentPath)) "Exact O2D4 sent path already exists: $sentPath"
    Assert-True (-not (Test-Path -LiteralPath $destination)) "Create-new quarantine destination already exists: $destination"
    $sourceItem = Get-Item -LiteralPath $source -Force -ErrorAction Stop
    Assert-True ($sourceItem.LastWriteTimeUtc -eq $expectedLastWriteUtc) "Exact pending O2D4 last-write time changed: $($sourceItem.LastWriteTimeUtc.ToString('o'))"
    $preMoveRows = @(Assert-ExactTree -Root $source)
    $manifest = Get-Content -LiteralPath (Join-Path $source 'PORTAL_REQUEST_MANIFEST.json') -Raw -ErrorAction Stop | ConvertFrom-Json
    Assert-True ([string]$manifest.schema -eq 'argos_project_portal_request_manifest_v1') 'O2D4 manifest schema changed.'
    Assert-True ([string]$manifest.requestId -eq 'REQ_O2D4') 'O2D4 manifest request identity changed.'
    Assert-True ([string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'O2D4 manifest job class changed.'

    if (-not (Test-Path -LiteralPath $quarantineParent -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $quarantineParent -ErrorAction Stop)
        $parentCreated = $true
    }
    Move-Item -LiteralPath $source -Destination $destination -ErrorAction Stop
    $moved = $true
    Assert-True (-not (Test-Path -LiteralPath $source)) 'O2D4 source remained after quarantine move.'
    Assert-True (Test-Path -LiteralPath $destination -PathType Container) 'O2D4 quarantine destination is absent after move.'
    $postMoveRows = @(Assert-ExactTree -Root $destination)

    Set-TerminalClipboard ([ordered]@{
        schema = $schema
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_EXACT_O2D4_PENDING_MOVED_TO_QUARANTINE'
        computerName = $env:COMPUTERNAME
        userName = $identity.Name
        administrativeToken = $isAdmin
        sourcePath = $source
        destinationPath = $destination
        sourceAbsentAfter = (-not (Test-Path -LiteralPath $source))
        destinationPresentAfter = (Test-Path -LiteralPath $destination -PathType Container)
        verifiedFileCount = $postMoveRows.Count
        verifiedFiles = $postMoveRows
        quarantineParentCreated = $parentCreated
        queueMutation = 'MOVE_EXACT_STALE_O2D4_PENDING_TO_CREATE_NEW_QUARANTINE'
        taskActions = @()
        processActions = @()
        jbodContacted = $false
        sourceImageBytesRead = $false
        providerActivated = $false
        mutationsPerformed = $true
        reviewOnly = $true
        productionRoutingEnabled = $false
    })
}
catch {
    $errorType = $_.Exception.GetType().FullName
    $errorMessage = $_.Exception.Message
    if ($moved -and (Test-Path -LiteralPath $destination -PathType Container) -and -not (Test-Path -LiteralPath $source)) {
        $rollbackAttempted = $true
        try {
            Move-Item -LiteralPath $destination -Destination $source -ErrorAction Stop
            $rollbackSucceeded = (Test-Path -LiteralPath $source -PathType Container) -and -not (Test-Path -LiteralPath $destination)
        }
        catch { $rollbackSucceeded = $false }
    }
    if ($parentCreated -and (Test-Path -LiteralPath $quarantineParent -PathType Container)) {
        try {
            if (@(Get-ChildItem -LiteralPath $quarantineParent -Force -ErrorAction Stop).Count -eq 0) {
                Remove-Item -LiteralPath $quarantineParent -Force -ErrorAction Stop
            }
        }
        catch { }
    }
    Set-TerminalClipboard ([ordered]@{
        schema = $schema
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'FAIL_EXACT_O2D4_PENDING_QUARANTINE'
        computerName = $env:COMPUTERNAME
        sourcePath = $source
        destinationPath = $destination
        errorType = $errorType
        errorMessage = $errorMessage
        preMoveVerifiedFileCount = $preMoveRows.Count
        moveAttempted = $moved
        rollbackAttempted = $rollbackAttempted
        rollbackSucceeded = $rollbackSucceeded
        sourcePresentAfter = (Test-Path -LiteralPath $source -PathType Container)
        destinationPresentAfter = (Test-Path -LiteralPath $destination -PathType Container)
        jbodContacted = $false
        sourceImageBytesRead = $false
        providerActivated = $false
        mutationsPerformed = ($moved -and -not $rollbackSucceeded)
        reviewOnly = $true
        productionRoutingEnabled = $false
    })
}
