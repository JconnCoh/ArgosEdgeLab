#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Publish')][switch]$Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$requestId = 'REQ_20260831T200026934Z_EEFA3619E73D'
$source = 'C:\R21M1PK\REQ_20260831T200026934Z_EEFA3619E73D.ready.zip'
$sourceSha256 = '07B4B03E1715235A29057280403C2F3CD47DB075252647CF52D824DA58B366D7'
$pathGate = Join-Path $PSScriptRoot 'R21M1_PREPUBLICATION_PATH_GATE.json'
$pathGateSha256 = 'B085614E22BF97703EEF8627631ADF299D0DE2D4CD7824B7DB38E4678D40AB70'
$expectedUnc = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestsRoot = 'U:\ProjectPortalRO\requests'
$target = Join-Path $requestsRoot ($requestId + '.ready.zip')
$upload = $target + '.upload'
$gatePath = Join-Path $PSScriptRoot 'R21M1_PUBLISH_GATE.json'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-NewUtf8Json([string]$Path, [object]$Value) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $source -PathType Leaf) -or (Get-Sha256 $source) -ne $sourceSha256) { throw 'R21M1 frozen source ZIP is absent or changed.' }
if (-not (Test-Path -LiteralPath $pathGate -PathType Leaf) -or (Get-Sha256 $pathGate) -ne $pathGateSha256) { throw 'R21M1 path gate is absent or changed.' }
$pathGateValue = Get-Content -LiteralPath $pathGate -Raw | ConvertFrom-Json
if ([string]$pathGateValue.state -ne 'PASS_R21M1_SIGNED_AND_PATH_GATED' -or [string]$pathGateValue.requestId -ne $requestId) { throw 'R21M1 path gate state or identity changed.' }
$drive = Get-PSDrive -Name U -ErrorAction Stop
$logicalDisk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='U:'" -ErrorAction Stop
if ([string]$drive.DisplayRoot -ne $expectedUnc -or [string]$logicalDisk.ProviderName -ne $expectedUnc -or [int]$logicalDisk.DriveType -ne 4) { throw 'Persistent U: mapping changed.' }
if (-not (Test-Path -LiteralPath $requestsRoot -PathType Container)) { throw 'Portal request root is unavailable.' }
$pending = @(Get-ChildItem -LiteralPath $requestsRoot -File -Filter '*.ready.zip' -ErrorAction Stop)
if ($pending.Count -ne 0) { throw 'Portal request root contains an unresolved pending request.' }
if ((Test-Path -LiteralPath $target) -or (Test-Path -LiteralPath $upload)) { throw 'R21M1 publication leaf already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21M1 publication gate already exists.' }
$head = [string](& git -C (Join-Path $PSScriptRoot '..\..') rev-parse HEAD)
$origin = [string](& git -C (Join-Path $PSScriptRoot '..\..') rev-parse refs/remotes/origin/codex/fiducial-opencv-d-drive)
if ($LASTEXITCODE -ne 0 -or $head -ne $origin) { throw 'R21M1 local/origin branch tips do not match.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b21_r21m1_publish_preflight_v1'
        state = 'PASS_R21M1_PUBLISH_PREFLIGHT'
        requestId = $requestId
        sourceSha256 = $sourceSha256
        pathGateSha256 = $pathGateSha256
        pendingRequestCount = 0
        branchTip = $head
        selectedCaseCount = 15
        completedCaseRerunCount = 0
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[IO.File]::Copy($source, $upload, $false)
if ((Get-Sha256 $upload) -ne $sourceSha256) { throw 'R21M1 upload hash changed.' }
[IO.File]::Move($upload, $target)
if ((Get-Sha256 $target) -ne $sourceSha256) { throw 'R21M1 published hash changed.' }
$gate = [ordered]@{
    schema = 'argos_o3b21_r21m1_publish_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21M1_PUBLISHED_ONCE'
    requestId = $requestId
    target = $target
    zipSha256 = $sourceSha256
    publicationCount = 1
    automaticRetryAuthorized = $false
    matchingSignedTerminalResponseRequired = $true
    selectedCaseCount = 15
    completedCaseRerunCount = 0
    targetExecuted = $false
    mutationsPerformed = $true
}
Write-NewUtf8Json -Path $gatePath -Value $gate
$gate | ConvertTo-Json -Depth 8
