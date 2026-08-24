[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('CHUNK01','CHUNK02','CHUNK03','CHUNK04','CHUNK05')]
    [string]$ChunkId,
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

function Get-ProviderSha256([string]$LiteralPath) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576 | ForEach-Object {
            [byte[]]$block = $_
            if ($block.Length) { [void]$sha.TransformBlock($block, 0, $block.Length, $block, 0) }
        }
        [void]$sha.TransformFinalBlock((New-Object byte[] 0), 0, 0)
        return ([BitConverter]::ToString($sha.Hash)).Replace('-', '')
    } finally { $sha.Dispose() }
}

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$root = Join-Path $project 'work\OPENCV_OLS6'
$ordinal = [int]$ChunkId.Substring(5, 2)
$suffix = '{0:D2}' -f $ordinal
$requestId = 'REQ_OLS6C' + $suffix
$source = Join-Path $root ('final_c' + $suffix + '\' + $requestId + '.ready.zip')
$finalGatePath = Join-Path $root ('OLS6_' + $ChunkId + '_FINAL_PACKAGE_GATE.json')
$routeGatePath = Join-Path $root ('OLS6_' + $ChunkId + '_COMPLETE_ROUTE_GATE.json')
$intentPath = Join-Path $root 'OLS6_LIVE_RECOVERY_INTENT.json'
$publishGatePath = Join-Path $root ('OLS6_' + $ChunkId + '_PUBLISH_GATE.json')
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$zipHashes = @{
    CHUNK01 = 'FB95D39C6C1CC4F510657DE7156085AAD47049BE665056686A056633B50EACE5'
    CHUNK02 = '13E87D7C778A913ACC209C7A612DBD579FA1E9D4DDE4E67871A406BFD4221EE7'
    CHUNK03 = 'D2316CD5A939200E0344EB2205253552D503E922B1E37A722B4D65235CD28B2E'
    CHUNK04 = 'B069C19377C6A2E892E762DF37DAA859D0C5261C8A096F92D9081BCB943705F4'
    CHUNK05 = '571704CC7C28A5DC663B5E46E3F63312667C0006B5B1E1B6D22DA23041C087D1'
}
$finalGateHashes = @{
    CHUNK01 = 'B2787F1563DFE09FE26F6A73593AF6556B4265C33A7ACE160AAA2DC2B93C4C92'
    CHUNK02 = '911893F0DA616551372D73BC11E7F4C252AEEC829776F79009EEDFC779C1DBAA'
    CHUNK03 = '2CD9C16B4AFE223527AFB08001BA5FFCA77F3A1FA1AE551CFC65112AA7A28290'
    CHUNK04 = '218830241AF4FCA3B3AF77CAD37EE029B6D15514F2B87FAE2DA45098A8D23488'
    CHUNK05 = 'C56F8601179F5E6CEE8798AB878018A2B7673F36F52892FDBEC98BB4D3593479'
}
$routeGateHashes = @{
    CHUNK01 = 'F330139B91B6A426F3279ED695C8BA4C338B340EBAFDAB4F2700FD6A1538D354'
    CHUNK02 = '4D8923D3BFC4DA91B21EF29E1E0CAA4BAFD50EFB5C3FE65733FA1611C5439238'
    CHUNK03 = '22B8F79F65080679ABB5117F5EB6E9FEC48A1F1B6C928FA2594A094441EEA5D4'
    CHUNK04 = 'DAFF813CED0117AFFD09BCCE4FFF1EB3DC0B61D1690916827FD12F32030DE286'
    CHUNK05 = 'AB91296FAF634D4677B04CCA96B82F5310D6226F520A4CD4DDF73844193B2933'
}
$expectedZipSha = [string]$zipHashes[$ChunkId]
$expectedFinalGateSha = [string]$finalGateHashes[$ChunkId]
$expectedRouteGateSha = [string]$routeGateHashes[$ChunkId]
$expectedIntentSha = 'A4B7EF0739300D01FF403D4D7D2889E0FAE2D27ED067C52105DE83F5663A0751'
foreach ($pin in @(
    @($source, $expectedZipSha),
    @($finalGatePath, $expectedFinalGateSha),
    @($routeGatePath, $expectedRouteGateSha),
    @($intentPath, $expectedIntentSha)
)) {
    if (-not (Test-Path -LiteralPath $pin[0] -PathType Leaf) -or (Get-ProviderSha256 $pin[0]) -ne [string]$pin[1]) { throw "OLS6 publish input changed: $($pin[0])" }
}
if (Test-Path -LiteralPath $publishGatePath) { throw 'OLS6 publish gate already exists.' }

$expectedBytes = [int64](Get-Item -LiteralPath $source).Length
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
$intent = Get-Content -LiteralPath $intentPath -Raw | ConvertFrom-Json
if ([string]$finalGate.state -ne 'PASS_OLS6_CHUNK_FINAL_PACKAGE_GATE' -or [string]$finalGate.chunkId -ne $ChunkId -or [string]$finalGate.requestId -ne $requestId -or [string]$finalGate.requestZipSha256 -ne $expectedZipSha -or [int64]$finalGate.requestZipBytes -ne $expectedBytes -or -not [bool]$finalGate.publicationRequiresCompleteRouteGate -or [bool]$finalGate.publicationAuthorized) { throw 'OLS6 final package gate changed.' }
if ([string]$routeGate.state -ne 'PASS_OLS6_CHUNK_COMPLETE_ROUTE_GATE' -or [string]$routeGate.chunkId -ne $ChunkId -or [string]$routeGate.requestId -ne $requestId -or [string]$routeGate.requestZipSha256 -ne $expectedZipSha -or -not [bool]$routeGate.exactFinalZipExtractionPassed -or -not [bool]$routeGate.exactFinalZipSignaturePassed) { throw 'OLS6 complete route gate changed.' }
if ([string]$finalGate.requestManifestSha256 -ne [string]$routeGate.requestManifestSha256 -or [string]$finalGate.requestSignatureSha256 -ne [string]$routeGate.requestSignatureSha256) { throw 'OLS6 package and route gates do not describe the same request.' }
if ([string]$intent.artifactLifecycle -ne 'FROZEN' -or -not [bool]$intent.authorizationBoundary.livePublicationAuthorized -or [int]$intent.authorizationBoundary.liveEndpointRequestsMaximum -ne 5 -or -not [bool]$intent.authorizationBoundary.publishNextOnlyAfterPriorSignedTerminalSuccess -or -not [bool]$intent.route.imageRead -or [bool]$intent.route.sourceMutation) { throw 'OLS6 live authorization boundary changed.' }

$priorTerminalGatePath = ''
$priorTerminalGateSha256 = ''
if ($ordinal -gt 1) {
    $priorSuffix = '{0:D2}' -f ($ordinal - 1)
    $priorChunkId = 'CHUNK' + $priorSuffix
    $priorRequestId = 'REQ_OLS6C' + $priorSuffix
    $priorTerminalGatePath = Join-Path $root ('OLS6_' + $priorChunkId + '_SIGNED_TERMINAL_GATE.json')
    if (-not (Test-Path -LiteralPath $priorTerminalGatePath -PathType Leaf)) { throw 'OLS6 prior signed terminal gate is missing.' }
    $priorTerminalGateSha256 = Get-ProviderSha256 $priorTerminalGatePath
    $prior = Get-Content -LiteralPath $priorTerminalGatePath -Raw | ConvertFrom-Json
    if ([string]$prior.state -ne 'PASS_OLS6_CHUNK_SIGNED_TERMINAL' -or [string]$prior.chunkId -ne $priorChunkId -or [string]$prior.requestId -ne $priorRequestId -or -not [bool]$prior.signedResponseVerified -or [string]$prior.responseState -ne 'COMPLETE' -or [int]$prior.targetCount -ne 4 -or [bool]$prior.pixelsDecoded -or [bool]$prior.imageProcessingPerformed) { throw 'OLS6 prior signed terminal gate is not an exact success.' }
}

$continuity = Get-Content -LiteralPath $continuityPath -Raw | ConvertFrom-Json
if ([string]$continuity.activePhase -notin @('OCV00_OLS5_POST_FAILURE_OBSERVATION_COMPLETE_OLS6_CHUNKED_HASH_IN_PROGRESS','OCV00_OLS6_CHUNKED_HASH_IN_PROGRESS') -or [bool]$continuity.productionEligible -or [bool]$continuity.xmlEligible -or [bool]$continuity.trainingEligible) { throw 'OLS6 continuity authority changed.' }
$branch = (& git -C $project branch --show-current | Out-String).Trim()
$local = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteLine = (& git -C $project ls-remote --heads origin ('refs/heads/' + $branch) | Out-String).Trim()
$remote = if ([string]::IsNullOrWhiteSpace($remoteLine)) { '' } else { ($remoteLine -split '\s+')[0] }
if ($branch -ne 'codex/fiducial-opencv-d-drive' -or $local -ne 'ecbda3205852550d7f9fdb4a4daf99b4a001e7da' -or $remote -ne $local) { throw 'OLS6 local/GitHub branch authority mismatch.' }

$requestRoot = 'U:\ProjectPortalRO\requests'
$uncRequestRoot = $shareRoot.TrimEnd('\') + '\ProjectPortalRO\requests'
if (-not (Test-Path -LiteralPath $uncRequestRoot -PathType Container)) { throw 'OLS6 portal request share is unavailable.' }
$pending = @(Get-ChildItem -LiteralPath $uncRequestRoot | Where-Object { -not $_.PSIsContainer -and $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
if ($pending.Count) { throw ('Another portal request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', ')) }
$ready = $requestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$upload = $ready + '.upload'
$processed = $requestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$uncReady = $uncRequestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
$uncUpload = $uncReady + '.upload'
$uncProcessed = $uncRequestRoot.TrimEnd('\') + '\processed\' + $requestId + '.ready.zip'
$pathGate = & $pathTool -CandidatePath @($source, $upload, $ready, $processed) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw 'OLS6 publish path gate failed.' }
foreach ($path in @($uncUpload, $uncReady, $uncProcessed)) { if (Test-Path -LiteralPath $path) { throw "OLS6 share artifact already exists: $path" } }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols6_chunk_publish_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS6_CHUNK_PUBLISH_PREFLIGHT'
        chunkId = $ChunkId
        requestId = $requestId
        sourceSha256 = $expectedZipSha
        sourceBytes = $expectedBytes
        finalGateSha256 = $expectedFinalGateSha
        completeRouteGateSha256 = $expectedRouteGateSha
        recoveryIntentSha256 = $expectedIntentSha
        priorTerminalGatePath = $priorTerminalGatePath
        priorTerminalGateSha256 = $priorTerminalGateSha256
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
    if ([string]::IsNullOrWhiteSpace($mappedRoot) -or -not $mappedRoot.TrimEnd('\').Equals($shareRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'U: does not map to the approved InspectionRevs gateway root.' }
    $pending = @(Get-ChildItem -LiteralPath $requestRoot | Where-Object { -not $_.PSIsContainer -and $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
    if ($pending.Count) { throw ('Another portal request appeared after preflight: ' + (($pending | ForEach-Object { $_.Name }) -join ', ')) }
    foreach ($path in @($upload, $ready, $processed)) { if (Test-Path -LiteralPath $path) { throw "OLS6 share artifact appeared after preflight: $path" } }
    Copy-Item -LiteralPath $source -Destination $upload -ErrorAction Stop
    if ((Get-Item -LiteralPath $upload).Length -ne $expectedBytes -or (Get-ProviderSha256 $upload) -ne $expectedZipSha) { throw 'OLS6 uploaded ZIP hash mismatch.' }
    Move-Item -LiteralPath $upload -Destination $ready -ErrorAction Stop
    if ((Get-Item -LiteralPath $ready).Length -ne $expectedBytes -or (Get-ProviderSha256 $ready) -ne $expectedZipSha) { throw 'OLS6 published ZIP hash mismatch.' }
    $record = [ordered]@{
        schema = 'argos_ols6_chunk_publish_gate_v1'
        publishedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS6_EXACT_SIGNED_CHUNK_REQUEST_PUBLISHED_CREATE_NEW'
        disposition = 'PENDING_GATE'
        chunkId = $ChunkId
        requestId = $requestId
        source = $source
        publishedPath = $ready
        bytes = $expectedBytes
        sha256 = $expectedZipSha
        finalGateSha256 = $expectedFinalGateSha
        completeRouteGateSha256 = $expectedRouteGateSha
        recoveryIntentSha256 = $expectedIntentSha
        priorTerminalGatePath = $priorTerminalGatePath
        priorTerminalGateSha256 = $priorTerminalGateSha256
        branch = $branch
        localTip = $local
        remoteTip = $remote
        tipsMatch = $true
        pendingRequestsBefore = 0
        shortShareMapping = 'U:'
        shortShareMappingVerified = $true
        createNew = $true
        overwritePerformed = $false
        sourceHashingAuthorized = $true
        pixelDecodeAuthorized = $false
        imageProcessingAuthorized = $false
        pathState = [string]$pathGate.state
        sourceDeletionPerformed = $false
        inspectionTasksChanged = $false
        currentWaferAborted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    [IO.File]::WriteAllText($publishGatePath, (($record | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    $record | ConvertTo-Json -Depth 8
} finally {
    if ($shareDriveCreated) { Remove-PSDrive -Name U -Scope Script -Force -ErrorAction Stop }
}
