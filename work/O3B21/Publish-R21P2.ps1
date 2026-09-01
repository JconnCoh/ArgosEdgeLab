#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Publish')][switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$requestId = 'REQ_20260831T184443635Z_1A1BDA397F24'
$source = 'C:\R21P2\REQ_20260831T184443635Z_1A1BDA397F24.ready.zip'
$sourceSha256 = 'C585E035BEB6477CD9BA1D02CC0D73BADFB42EF981566A9A36C3250F4BF73F9B'
$expectedUnc = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestsRoot = 'U:\ProjectPortalRO\requests'
$target = Join-Path $requestsRoot ($requestId + '.ready.zip')
$upload = $target + '.upload'
$gatePath = Join-Path $PSScriptRoot 'R21P2_PUBLISH_GATE.json'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-NewUtf8Json([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Get-Sha256 $source) -ne $sourceSha256) { throw 'R21P2 frozen source ZIP is absent or changed.' }
$drive = Get-PSDrive -Name U -ErrorAction Stop
$logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
if ([string]$drive.DisplayRoot -ne $expectedUnc -or [string]$logicalDisk.ProviderName -ne $expectedUnc -or [int]$logicalDisk.DriveType -ne 4) { throw 'Persistent U: mapping changed.' }
if (-not (Test-Path -LiteralPath $requestsRoot -PathType Container)) { throw 'Portal request root is unavailable.' }
$pending = @(Get-ChildItem -LiteralPath $requestsRoot -File -Filter '*.ready.zip' -ErrorAction Stop)
if ($pending.Count -ne 0) { throw 'Portal request root contains an unresolved pending request.' }
if ((Test-Path -LiteralPath $target) -or (Test-Path -LiteralPath $upload)) { throw 'R21P2 publication leaf already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21P2 publication gate already exists.' }
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$head = [string](& git -C $projectRoot rev-parse HEAD)
$origin = [string](& git -C $projectRoot rev-parse refs/remotes/origin/codex/fiducial-opencv-d-drive)
if ($LASTEXITCODE -ne 0 -or $head -ne $origin) { throw 'R21P2 local/origin branch tips do not match.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r21p2_publish_preflight_v1'
        state = 'PASS_R21P2_PUBLISH_PREFLIGHT'
        requestId = $requestId
        sourceSha256 = $sourceSha256
        pendingRequestCount = 0
        branchTip = $head
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[IO.File]::Copy($source, $upload, $false)
if ((Get-Sha256 $upload) -ne $sourceSha256) { throw 'R21P2 upload hash changed.' }
[IO.File]::Move($upload, $target)
if ((Get-Sha256 $target) -ne $sourceSha256) { throw 'R21P2 published hash changed.' }
$gate = [ordered]@{
    schema = 'argos_r21p2_publish_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21P2_PUBLISHED_ONCE'
    requestId = $requestId
    target = $target
    zipSha256 = $sourceSha256
    publicationCount = 1
    automaticRetryAuthorized = $false
    matchingSignedTerminalResponseRequired = $true
    targetExecuted = $false
    mutationsPerformed = $true
}
Write-NewUtf8Json -Path $gatePath -Value $gate
$gate | ConvertTo-Json -Depth 8
