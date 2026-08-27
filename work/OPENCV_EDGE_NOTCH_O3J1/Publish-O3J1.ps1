#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([bool]$Preflight -eq [bool]$Publish) {
    throw 'Specify exactly one of -Preflight or -Publish.'
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260827T185500111Z_62629419O3J1'
$requestZip = Join-Path $PSScriptRoot ('final\' + $requestId + '.ready.zip')
$requestZipSha256 = '71E3BA51EF387C91D8F1425CD7703B3F3606B4C6043166E1907069F4A803DF94'
$expectedShareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestShare = 'U:\ProjectPortalRO\requests'
$destination = $requestShare + '\' + $requestId + '.ready.zip'
$upload = $destination + '.upload'
$processed = $requestShare + '\processed\' + $requestId + '.ready.zip'
$gatePath = Join-Path $PSScriptRoot 'O3J1_PUBLISH_GATE.json'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Normalize-UncRoot {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }
    return $Value.Trim().TrimEnd('\')
}

function Get-PublishPreflight {
    $pins = @(
        [pscustomobject]@{ path = $requestZip; sha256 = $requestZipSha256 },
        [pscustomobject]@{ path = (Join-Path $PSScriptRoot 'O3J1_FINAL_PACKAGE_GATE.json'); sha256 = 'A3FA6E981DF350B435CE22EB214E1EAD940697A649563D9766E300424C2C0E45' },
        [pscustomobject]@{ path = (Join-Path $PSScriptRoot 'O3J1_EXACT_PACKAGE_REHEARSAL_GATE.json'); sha256 = '56C396A7A0342FA1F4316AAEBC8209FD77F6696F00527A3E93B04D599B8A1461' },
        [pscustomobject]@{ path = (Join-Path $PSScriptRoot 'O3J1_COMPLETE_ROUTE_GATE.json'); sha256 = '3D13D478282302A75BDD2BD32D70D44E8F994C46210AD366B73A70AAB62E5E14' },
        [pscustomobject]@{ path = (Join-Path $PSScriptRoot 'O3J1_CURRENT_SHARE_OBSERVATION.json'); sha256 = '38CE80C19FE5690E72A9BED47B17F64534E555838E455F266CC91CEA0108DCBF' },
        [pscustomobject]@{ path = (Join-Path $project 'work\FRONTSIDE_INSPECTION_REVIEW_ONLY\OCV03_O3J1_RESULT_JSON_CAPABILITY_PUBLISH_READY_20260827.md'); sha256 = '0E1D6271FBD3E03BD4F5804B4CAD426E6B5C54D42BCC6A572212120752A86281' }
    )
    foreach ($pin in $pins) {
        Assert-True (Test-Path -LiteralPath $pin.path -PathType Leaf) "O3J1 publisher dependency absent: $($pin.path)"
        Assert-True ((Get-Sha256 -Path $pin.path) -eq $pin.sha256) "O3J1 publisher dependency changed: $($pin.path)"
    }

    $psDrive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
    $displayRoot = Normalize-UncRoot -Value ([string]$psDrive.DisplayRoot)
    Assert-True ($displayRoot.Equals((Normalize-UncRoot -Value $expectedShareRoot), [StringComparison]::OrdinalIgnoreCase)) 'Persistent U: PowerShell DisplayRoot changed.'

    $logicalDisk = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
    Assert-True ($null -ne $logicalDisk) 'Persistent U: operating-system logical disk is absent.'
    $providerName = Normalize-UncRoot -Value ([string]$logicalDisk.ProviderName)
    Assert-True ($providerName.Equals((Normalize-UncRoot -Value $expectedShareRoot), [StringComparison]::OrdinalIgnoreCase)) 'Persistent U: logical-disk ProviderName changed.'
    Assert-True ([int]$logicalDisk.DriveType -eq 4) 'Persistent U: logical disk is not a network drive.'

    Assert-True (Test-Path -LiteralPath $requestShare -PathType Container) 'Persistent U: request share is absent.'
    $queueRows = @(
        Get-ChildItem -LiteralPath $requestShare -File -Force -ErrorAction Stop |
            Where-Object { $_.Name -like '*.ready.zip' -or $_.Name -like '*.upload' }
    )
    $readyRows = @($queueRows | Where-Object { $_.Name -like '*.ready.zip' })
    $uploadRows = @($queueRows | Where-Object { $_.Name -like '*.upload' })
    Assert-True ($readyRows.Count -eq 0) 'Persistent U: contains a pending ready request; publication is blocked.'
    Assert-True ($uploadRows.Count -eq 0) 'Persistent U: contains a pending upload request; publication is blocked.'
    Assert-True (-not (Test-Path -LiteralPath $destination)) 'Exact O3J1 ready request already exists; retry is prohibited.'
    Assert-True (-not (Test-Path -LiteralPath $upload)) 'Exact O3J1 upload already exists; retry is prohibited.'
    Assert-True (-not (Test-Path -LiteralPath $processed)) 'Exact O3J1 request is already processed; retry is prohibited.'
    Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O3J1 publisher gate already exists; retry is prohibited.'

    $gitCommand = Get-Command -Name git -CommandType Application -ErrorAction Stop
    $branch = (& $gitCommand.Path -C $project branch --show-current | Out-String).Trim()
    Assert-True ($branch -eq 'codex/fiducial-opencv-d-drive') 'O3J1 publisher branch changed.'
    $status = (& $gitCommand.Path -C $project status --porcelain=v1 | Out-String).Trim()
    Assert-True ([string]::IsNullOrWhiteSpace($status)) 'O3J1 publisher requires a clean worktree.'
    $localTip = (& $gitCommand.Path -C $project rev-parse HEAD | Out-String).Trim()
    $remoteTip = (& $gitCommand.Path -C $project rev-parse refs/remotes/origin/codex/fiducial-opencv-d-drive | Out-String).Trim()
    Assert-True ($localTip -eq $remoteTip) 'O3J1 local and remote branch tips differ.'

    return [ordered]@{
        schema = 'argos_o3j1_publish_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3J1_PUBLISH_PREFLIGHT'
        requestId = $requestId
        requestZipSha256 = $requestZipSha256
        branch = $branch
        commit = $localTip
        powerShellDriveDisplayRoot = $displayRoot
        logicalDiskProviderName = $providerName
        logicalDiskDriveType = [int]$logicalDisk.DriveType
        requestShare = $requestShare
        readyRequestCount = $readyRows.Count
        uploadRequestCount = $uploadRows.Count
        destination = $destination
        requestRetryAuthorized = $false
        mutationsPerformed = $false
        gatewayAcceptanceIsExecutionEvidence = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
}

function Write-NewJson {
    param([string]$Path, [object]$Value)
    $json = ($Value | ConvertTo-Json -Depth 10) + [Environment]::NewLine
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

$preflightResult = Get-PublishPreflight
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 10
    return
}

$sourceStream = [IO.File]::Open($requestZip, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    $targetStream = [IO.File]::Open($upload, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $sourceStream.CopyTo($targetStream)
        $targetStream.Flush()
    }
    finally {
        $targetStream.Dispose()
    }
}
finally {
    $sourceStream.Dispose()
}

Assert-True ((Get-Sha256 -Path $upload) -eq $requestZipSha256) 'O3J1 upload copy changed.'
[IO.File]::Move($upload, $destination)
Assert-True ((Get-Sha256 -Path $destination) -eq $requestZipSha256) 'O3J1 published ZIP changed.'

$gate = [ordered]@{
    schema = 'argos_o3j1_publish_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3J1_PUBLISHED_ONCE'
    requestId = $requestId
    requestZipSha256 = $requestZipSha256
    destination = $destination
    destinationSha256 = Get-Sha256 -Path $destination
    branch = $preflightResult.branch
    commit = $preflightResult.commit
    powerShellDriveDisplayRoot = $preflightResult.powerShellDriveDisplayRoot
    logicalDiskProviderName = $preflightResult.logicalDiskProviderName
    logicalDiskDriveType = $preflightResult.logicalDiskDriveType
    readyRequestCountBefore = $preflightResult.readyRequestCount
    uploadRequestCountBefore = $preflightResult.uploadRequestCount
    publicationCount = 1
    requestRetryAuthorized = $false
    matchingSignedTerminalResponseRequired = $true
    gatewayAcceptanceIsExecutionEvidence = $false
    providerActivated = $false
    protectedProcessorTouched = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-NewJson -Path $gatePath -Value $gate
$gate | ConvertTo-Json -Depth 10
