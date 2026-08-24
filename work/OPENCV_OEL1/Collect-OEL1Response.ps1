[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory = $true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OEL1'
$requestId = 'REQ_OEL1'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_oel1_response_collection_invocation_v1' -or [string]$invocation.requestId -ne $requestId) { throw 'OEL1 response collection invocation contract changed.' }
$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = [IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\')
if (-not $sourceZip.StartsWith($approvedResponseRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedResponseRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($sourceZip) -ine '.zip') { throw 'OEL1 response source is outside the exact approved response root.' }
$responseToken = [IO.Path]::GetFileNameWithoutExtension($sourceZip)
if ($responseToken -notmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready$') { throw 'OEL1 response token format changed.' }
$expectedZipBytes = [int64]$invocation.expectedZipBytes
$expectedZipSha256 = ([string]$invocation.expectedZipSha256).ToUpperInvariant()
if ($expectedZipBytes -lt 1 -or $expectedZipBytes -gt 2097152 -or $expectedZipSha256 -notmatch '^[0-9A-F]{64}$') { throw 'OEL1 response invocation size or hash is invalid.' }
$collectionRoot = 'C:\AO1R'
$localZip = $collectionRoot.TrimEnd('\') + '\' + $responseToken + '.zip'
$readyRoot = $collectionRoot.TrimEnd('\') + '\' + $responseToken
$partialRoot = $readyRoot + '.partial'
$terminalGatePath = Join-Path $workRoot 'OEL1_TERMINAL_RESPONSE_GATE.json'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

foreach ($path in @($sourceZip, $responseVerifier, $endpointCertificate, $pathTool)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OEL1 response prerequisite is missing: $path" }
}
if ((Get-Item -LiteralPath $sourceZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OEL1 source response ZIP changed.' }
foreach ($path in @($localZip, $readyRoot, $partialRoot, $terminalGatePath)) { if (Test-Path -LiteralPath $path) { throw "OEL1 response output already exists: $path" } }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $manifestEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    if ($null -eq $manifestEntry -or $manifestEntry.Length -gt 1048576) { throw 'OEL1 bounded response manifest entry is missing or too large.' }
    $stream = $manifestEntry.Open()
    $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false, $true)))
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose(); $stream.Dispose() }
}
finally { $archive.Dispose() }
if ([string]$manifest.requestId -ne $requestId -or [string]$manifest.sourceRole -ne 'JBOD' -or [string]$manifest.state -ne 'PASS_MAINTENANCE_PATCH' -or -not [bool]$manifest.reviewOnly -or [bool]$manifest.productionRoutingEnabled) { throw 'OEL1 response manifest terminal contract changed.' }

$planned = @($localZip, $readyRoot + '\PORTAL_RESPONSE_MANIFEST.json', $readyRoot + '\PORTAL_RESPONSE_MANIFEST.sig', $readyRoot + '\MAINTENANCE.stdout.txt', $partialRoot + '\PORTAL_RESPONSE_MANIFEST.json', $terminalGatePath)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OEL1 response collection path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_oel1_response_collection_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OEL1_RESPONSE_COLLECTION_PREFLIGHT'
        requestId = $requestId
        responseToken = $responseToken
        endpointState = [string]$manifest.state
        sourceZipBytes = $expectedZipBytes
        sourceZipSha256 = $expectedZipSha256
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $collectionRoot)
Copy-Item -LiteralPath $sourceZip -Destination $localZip -ErrorAction Stop
if ((Get-Item -LiteralPath $localZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OEL1 local response ZIP changed during copy.' }
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
& $responseVerifier -PackagePath $partialRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'OEL1 signed response verification failed.' }
$extractedManifest = Get-Content -LiteralPath (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json') -Raw | ConvertFrom-Json
if ([string]$extractedManifest.state -ne 'PASS_MAINTENANCE_PATCH' -or @($extractedManifest.files).Count -ne 3) { throw 'OEL1 extracted terminal response contract changed.' }
$stdoutPath = Join-Path $partialRoot 'MAINTENANCE.stdout.txt'
if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -or (Get-Item -LiteralPath $stdoutPath).Length -gt 2097152) { throw 'OEL1 bounded maintenance stdout is missing or too large.' }
$entryResult = Get-Content -LiteralPath $stdoutPath -Raw | ConvertFrom-Json
$leaves = @($entryResult.exactRelativeLeaves)
if ([string]$entryResult.state -ne 'PASS_FIDCV1_JBOD_INVENTORY_CAPABILITY_OEL1' -or $leaves.Count -ne 4 -or -not [bool]$entryResult.metadataOnly -or [bool]$entryResult.pathsEnumerated -or [bool]$entryResult.filesRead -or [bool]$entryResult.imageBytesRead -or [bool]$entryResult.sourceHashingPerformed -or [bool]$entryResult.inspectionTasksChanged -or [bool]$entryResult.processorTaskChanged -or @($entryResult.processActions).Count -ne 0 -or [bool]$entryResult.sourceDeletionPerformed -or [bool]$entryResult.waferActionPerformed) { throw 'OEL1 signed maintenance stdout violated the exact metadata-only terminal contract.' }
$expectedLeaves = @(
    'PatternedFront/Lot_62628-281/62628-281_20260813112015/Slot02/BrightfieldFrontsideWafer/resizedImage/62628-281_Slot02_BrightfieldFrontsideWafer_PM2_resizedImage.bmp',
    'PatternedFront/Lot_62628-281/62628-281_20260813112015/Slot02/DarkfieldFrontsideWafer/resizedImage/62628-281_Slot02_DarkfieldFrontsideWafer_PM2_resizedImage.bmp',
    'PatternedFront/Lot_62616-115/62616-115_20260807120245/Slot23/BrightfieldFrontsideWafer/resizedImage/62616-115_Slot23_BrightfieldFrontsideWafer_PM2_resizedImage.bmp',
    'PatternedFront/Lot_62616-115/62616-115_20260807120245/Slot23/DarkfieldFrontsideWafer/resizedImage/62616-115_Slot23_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'
)
for ($index = 0; $index -lt $expectedLeaves.Count; $index++) {
    if (([string]$leaves[$index].relativePath).Replace('\','/') -ne $expectedLeaves[$index] -or [bool]$leaves[$index].enumerated -or [bool]$leaves[$index].filesRead -or [bool]$leaves[$index].imageBytesRead -or [bool]$leaves[$index].mutationsPerformed) { throw "OEL1 signed exact-leaf row contract failed at index $index." }
}
Move-Item -LiteralPath $partialRoot -Destination $readyRoot

$gate = [ordered]@{
    schema = 'argos_oel1_terminal_response_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OEL1_SIGNED_TERMINAL_RESPONSE'
    requestId = $requestId
    responseToken = $responseToken
    endpointState = [string]$extractedManifest.state
    sourceRole = [string]$extractedManifest.sourceRole
    signedResponseVerified = $true
    responseFileCount = @($extractedManifest.files).Count
    sourceZipBytes = $expectedZipBytes
    sourceZipSha256 = $expectedZipSha256
    exactRelativeLeaves = $leaves
    metadataOnly = $true
    pathsEnumerated = $false
    filesRead = $false
    imageBytesRead = $false
    sourceHashingPerformed = $false
    collectedRoot = $readyRoot
    pathState = [string]$pathGate.state
    endpointCapabilityImprovementExecuted = $true
    inspectionTasksChanged = $false
    processorTaskChanged = $false
    processActions = @()
    sourceDeletionPerformed = $false
    currentWaferAborted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
[IO.File]::WriteAllText($terminalGatePath, (($gate | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$gate | ConvertTo-Json -Depth 8
