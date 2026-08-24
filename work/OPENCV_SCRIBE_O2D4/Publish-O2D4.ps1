[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) {
    throw 'Specify exactly one of -Preflight or -Publish.'
}

function Get-ProviderSha256([string]$LiteralPath) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576 | ForEach-Object {
            [byte[]]$block = $_
            if ($block.Length) {
                [void]$sha.TransformBlock($block, 0, $block.Length, $block, 0)
            }
        }
        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
        return ([BitConverter]::ToString($sha.Hash)).Replace('-', '')
    }
    finally {
        $sha.Dispose()
    }
}

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root = Join-Path $project 'work\OPENCV_SCRIBE_O2D4'
$requestId = 'REQ_O2D4'
$source = Join-Path $root 'final\REQ_O2D4.ready.zip'
$finalGatePath = Join-Path $root 'O2D4_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $root 'O2D4_COMPLETE_ROUTE_GATE.json'
$publishGatePath = Join-Path $root 'O2D4_PUBLISH_GATE.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$expectedZipSha = 'D2411AE50ED33AEE4B6EC8DF1D8B771E228C082C21338B6A4373289EB744C994'
$expectedFinalGateSha = 'D6D91C47E86D5009E5472699AAC21C844B1C92C0C9DCBBD3886636632B126DE1'
$expectedRouteGateSha = 'AFE9A1306D90C5B54042388901F6FD6902DD8C1637A99714B451EF1F14F8CA34'

foreach ($pin in @(
    @($source, $expectedZipSha),
    @($finalGatePath, $expectedFinalGateSha),
    @($routeGatePath, $expectedRouteGateSha)
)) {
    if (-not (Test-Path -LiteralPath $pin[0] -PathType Leaf) -or (Get-ProviderSha256 $pin[0]) -ne [string]$pin[1]) {
        throw "O2D4 publish input changed: $($pin[0])"
    }
}
if (Test-Path -LiteralPath $publishGatePath) {
    throw 'O2D4 publish gate already exists.'
}

$expectedBytes = [int64](Get-Item -LiteralPath $source).Length
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
if ([string]$finalGate.state -ne 'PASS_O2D4_FINAL_PACKAGE_GATE' -or
    [string]$finalGate.requestId -ne $requestId -or
    [string]$finalGate.requestZipSha256 -ne $expectedZipSha -or
    [int64]$finalGate.requestZipBytes -ne $expectedBytes -or
    -not [bool]$finalGate.publicationRequiresCompleteRouteGate -or
    [bool]$finalGate.publicationAuthorized) {
    throw 'O2D4 final package gate changed.'
}
if ([string]$routeGate.state -ne 'PASS_O2D4_COMPLETE_ROUTE_GATE' -or
    [string]$routeGate.requestId -ne $requestId -or
    [string]$routeGate.requestZipSha256 -ne $expectedZipSha -or
    -not [bool]$routeGate.exactFinalZipExtractionPassed -or
    -not [bool]$routeGate.exactFinalZipSignaturePassed -or
    -not [bool]$routeGate.canonicalSourcePathsRequireAlias -or
    -not [bool]$routeGate.childIoAliasPathsPassBelow200 -or
    [int]$routeGate.maximumMaterializedEffectiveLength -ge 200) {
    throw 'O2D4 complete route gate changed.'
}
if ([string]$finalGate.requestManifestSha256 -ne [string]$routeGate.requestManifestSha256 -or
    [string]$finalGate.requestSignatureSha256 -ne [string]$routeGate.requestSignatureSha256) {
    throw 'O2D4 package and route gates do not describe the same request.'
}

$continuity = Get-Content -LiteralPath $continuityPath -Raw | ConvertFrom-Json
if ([string]$continuity.activePhase -ne 'OCV02_SCRIBE_PROVIDER_DEVELOPMENT_START' -or
    [bool]$continuity.productionEligible -or
    [bool]$continuity.xmlEligible -or
    [bool]$continuity.trainingEligible) {
    throw 'O2D4 continuity authority changed.'
}
$branch = (& git -C $project branch --show-current | Out-String).Trim()
$local = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteLine = (& git -C $project ls-remote --heads origin ('refs/heads/' + $branch) | Out-String).Trim()
$remote = if ([string]::IsNullOrWhiteSpace($remoteLine)) { '' } else { ($remoteLine -split '\s+')[0] }
if ($branch -ne 'codex/fiducial-opencv-d-drive' -or
    $local -ne 'ecbda3205852550d7f9fdb4a4daf99b4a001e7da' -or
    $remote -ne $local) {
    throw 'O2D4 local/GitHub branch authority mismatch.'
}

$requestRoot = 'U:\ProjectPortalRO\requests'
$uncRequestRoot = $shareRoot.TrimEnd('\') + '\ProjectPortalRO\requests'
if (-not (Test-Path -LiteralPath $uncRequestRoot -PathType Container)) {
    throw 'O2D4 portal request share is unavailable.'
}
$pending = @(Get-ChildItem -LiteralPath $uncRequestRoot | Where-Object { -not $_.PSIsContainer -and $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
if ($pending.Count) {
    throw ('Another portal request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
}
$ready = $requestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$upload = $ready + '.upload'
$processed = $requestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$uncReady = $uncRequestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$uncUpload = $uncReady + '.upload'
$uncProcessed = $uncRequestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$pathGate = & $pathTool -CandidatePath @($source, $upload, $ready, $processed) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') {
    throw 'O2D4 publish path gate failed.'
}
foreach ($path in @($uncUpload, $uncReady, $uncProcessed)) {
    if (Test-Path -LiteralPath $path) {
        throw "O2D4 share artifact already exists: $path"
    }
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d4_publish_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D4_PUBLISH_PREFLIGHT'
        requestId = $requestId
        sourceSha256 = $expectedZipSha
        sourceBytes = $expectedBytes
        finalGateSha256 = $expectedFinalGateSha
        completeRouteGateSha256 = $expectedRouteGateSha
        branch = $branch
        localTip = $local
        remoteTip = $remote
        tipsMatch = $true
        pendingRequests = 0
        existingRequestArtifacts = 0
        gatewayShareRoot = $shareRoot
        gatewayShareObserved = $true
        shortShareMapping = 'U:'
        shortShareMappingPlanned = $true
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        imageProcessingAuthorized = $true
        sourceMutationAuthorized = $false
        sourceDeletionAuthorized = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

$shareDriveCreated = $false
try {
    $drive = Get-PSDrive -Name U -ErrorAction SilentlyContinue
    if ($null -eq $drive) {
        [void](New-PSDrive -Name U -PSProvider FileSystem -Root $shareRoot -Scope Script -ErrorAction Stop)
        $shareDriveCreated = $true
        $drive = Get-PSDrive -Name U -ErrorAction Stop
    }
    $mappedRoot = if ([string]::IsNullOrWhiteSpace([string]$drive.DisplayRoot)) { [string]$drive.Root } else { [string]$drive.DisplayRoot }
    if ([string]::IsNullOrWhiteSpace($mappedRoot) -or
        -not $mappedRoot.TrimEnd('\').Equals($shareRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) {
        throw 'U: does not map to the approved InspectionRevs gateway root.'
    }
    $pending = @(Get-ChildItem -LiteralPath $requestRoot | Where-Object { -not $_.PSIsContainer -and $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
    if ($pending.Count) {
        throw ('Another portal request appeared after preflight: ' + (($pending | ForEach-Object { $_.Name }) -join ', '))
    }
    foreach ($path in @($upload, $ready, $processed)) {
        if (Test-Path -LiteralPath $path) {
            throw "O2D4 share artifact appeared after preflight: $path"
        }
    }
    Copy-Item -LiteralPath $source -Destination $upload -ErrorAction Stop
    if ((Get-Item -LiteralPath $upload).Length -ne $expectedBytes -or (Get-ProviderSha256 $upload) -ne $expectedZipSha) {
        throw 'O2D4 uploaded ZIP hash mismatch.'
    }
    Move-Item -LiteralPath $upload -Destination $ready -ErrorAction Stop
    if ((Get-Item -LiteralPath $ready).Length -ne $expectedBytes -or (Get-ProviderSha256 $ready) -ne $expectedZipSha) {
        throw 'O2D4 published ZIP hash mismatch.'
    }
    $record = [ordered]@{
        schema = 'argos_o2d4_publish_gate_v1'
        publishedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D4_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'
        disposition = 'PENDING_GATE'
        requestId = $requestId
        source = $source
        publishedPath = $ready
        bytes = $expectedBytes
        sha256 = $expectedZipSha
        finalGateSha256 = $expectedFinalGateSha
        completeRouteGateSha256 = $expectedRouteGateSha
        branch = $branch
        localTip = $local
        remoteTip = $remote
        tipsMatch = $true
        pendingRequestsBefore = 0
        shortShareMapping = 'U:'
        shortShareMappingVerified = $true
        createNew = $true
        overwritePerformed = $false
        imageProcessingAuthorized = $true
        sourceMutationAuthorized = $false
        sourceDeletionAuthorized = $false
        inspectionTasksChanged = $false
        processorTaskChanged = $false
        currentWaferAborted = $false
        holdsMayBeCleared = $false
        providerActivationAuthorized = $false
        pathState = [string]$pathGate.state
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    [IO.File]::WriteAllText($publishGatePath, (($record | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    $record | ConvertTo-Json -Depth 8
}
finally {
    if ($shareDriveCreated) {
        Remove-PSDrive -Name U -Scope Script -Force -ErrorAction Stop
    }
}

