[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OLS1'
$requestId = 'REQ_OLS1'
$source = Join-Path $workRoot ('final\' + $requestId + '.ready.zip')
$finalGatePath = $source + '.gate.json'
$routeGatePath = Join-Path $workRoot 'OLS1_COMPLETE_ROUTE_GATE.json'
$publishGatePath = Join-Path $workRoot 'OLS1_PUBLISH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'

foreach ($path in @($source, $finalGatePath, $routeGatePath, $pathTool)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS1 publish input is missing: $path" }
}
if (Test-Path -LiteralPath $publishGatePath) { throw "OLS1 publish gate already exists: $publishGatePath" }
$expectedSha = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
$expectedBytes = [int64](Get-Item -LiteralPath $source).Length
$expectedFinalGateSha = (Get-FileHash -LiteralPath $finalGatePath -Algorithm SHA256).Hash
$expectedRouteGateSha = (Get-FileHash -LiteralPath $routeGatePath -Algorithm SHA256).Hash
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
$routeGate = Get-Content -LiteralPath $routeGatePath -Raw | ConvertFrom-Json
if ([string]$finalGate.state -ne 'PASS_OLS1_FINAL_PACKAGE_GATE' -or [string]$finalGate.requestId -ne $requestId -or [string]$finalGate.requestZipSha256 -ne $expectedSha -or [int64]$finalGate.requestZipBytes -ne $expectedBytes -or -not [bool]$finalGate.publicationRequiresCompleteRouteGate -or [bool]$finalGate.publicationAuthorized) { throw 'OLS1 final package gate contract changed.' }
if ([string]$routeGate.state -ne 'PASS_OLS1_COMPLETE_ROUTE_GATE' -or [string]$routeGate.requestId -ne $requestId -or [string]$routeGate.requestZipSha256 -ne $expectedSha -or -not [bool]$routeGate.exactFinalZipExtractionPassed -or -not [bool]$routeGate.exactFinalZipSignaturePassed) { throw 'OLS1 complete route gate contract changed.' }
if ([string]$finalGate.requestManifestSha256 -ne [string]$routeGate.requestManifestSha256 -or [string]$finalGate.requestSignatureSha256 -ne [string]$routeGate.requestSignatureSha256 -or [string]$finalGate.oldEndpointWorkerSha256 -ne [string]$routeGate.endpointWorkerPredecessorSha256 -or [string]$finalGate.targetEndpointWorkerSha256 -ne [string]$routeGate.endpointWorkerTargetSha256) { throw 'OLS1 final-package and complete-route evidence do not describe the same exact request.' }

try {
    $existing = Get-PSDrive -Name U -ErrorAction Stop
    $mappedRoot = [string]$existing.DisplayRoot
    if ([string]::IsNullOrWhiteSpace($mappedRoot) -or -not $mappedRoot.TrimEnd('\').Equals($shareRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'U: does not map to the approved InspectionRevs root.' }
    $requestRoot = [IO.Path]::GetFullPath('U:\ProjectPortalRO\requests')
    if (-not (Test-Path -LiteralPath $requestRoot -PathType Container)) { throw "Portal request share is unavailable: $requestRoot" }
    $pending = @(Get-ChildItem -LiteralPath $requestRoot -File | Where-Object { $_.Name -match '\.ready\.zip(\.upload)?$' } | Select-Object -First 21)
    if ($pending.Count) { throw ('Another portal request is pending: ' + (($pending | ForEach-Object { $_.Name }) -join ', ')) }
    $ready = $requestRoot.TrimEnd('\') + '\' + $requestId + '.ready.zip'
    $upload = $ready + '.upload'
    $pathGate = & $pathTool -CandidatePath @($source, $upload, $ready) -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OLS1 publish path gate failed: $($pathGate.state)" }
    foreach ($path in @($upload, $ready)) { if (Test-Path -LiteralPath $path) { throw "Refusing existing OLS1 share artifact: $path" } }

    if ($Preflight) {
        [ordered]@{
            schema = 'argos_ols1_publish_preflight_v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            state = 'PASS_OLS1_PUBLISH_PREFLIGHT'
            requestId = $requestId
            sourceSha256 = $expectedSha
            sourceBytes = $expectedBytes
            finalGateSha256 = $expectedFinalGateSha
            completeRouteGateSha256 = $expectedRouteGateSha
            pendingRequests = 0
            shortShareMapping = 'U:'
            shortShareMappingVerified = $true
            pathState = [string]$pathGate.state
            mutationsPerformed = $false
            reviewOnly = $true
            productionRoutingEnabled = $false
        } | ConvertTo-Json -Depth 6
        return
    }

    Copy-Item -LiteralPath $source -Destination $upload -ErrorAction Stop
    if ((Get-Item -LiteralPath $upload).Length -ne $expectedBytes -or (Get-FileHash -LiteralPath $upload -Algorithm SHA256).Hash -ne $expectedSha) { throw 'OLS1 uploaded request ZIP hash mismatch.' }
    Move-Item -LiteralPath $upload -Destination $ready -ErrorAction Stop
    if ((Get-Item -LiteralPath $ready).Length -ne $expectedBytes -or (Get-FileHash -LiteralPath $ready -Algorithm SHA256).Hash -ne $expectedSha) { throw 'OLS1 published request ZIP hash mismatch.' }
    $gate = [ordered]@{
        schema = 'argos_ols1_publish_gate_v1'
        publishedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS1_EXACT_SIGNED_REQUEST_PUBLISHED_CREATE_NEW'
        disposition = 'PENDING_GATE'
        requestId = $requestId
        source = $source
        publishedPath = $ready
        bytes = $expectedBytes
        sha256 = $expectedSha
        finalGateSha256 = $expectedFinalGateSha
        completeRouteGateSha256 = $expectedRouteGateSha
        shortShareMapping = 'U:'
        shortShareMappingVerified = $true
        createNew = $true
        overwritePerformed = $false
        pathState = [string]$pathGate.state
        sourceDeletionPerformed = $false
        inspectionTasksChanged = $false
        currentWaferAborted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    [IO.File]::WriteAllText($publishGatePath, (($gate | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
    $gate | ConvertTo-Json -Depth 8
}
finally { }

