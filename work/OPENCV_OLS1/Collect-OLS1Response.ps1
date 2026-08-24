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
$workRoot = Join-Path $project 'work\OPENCV_OLS1'
$requestId = 'REQ_OLS1'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_ols1_response_collection_invocation_v1' -or [string]$invocation.requestId -ne $requestId) { throw 'OLS1 response collection invocation contract changed.' }
$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = [IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\')
if (-not $sourceZip.StartsWith($approvedResponseRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedResponseRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($sourceZip) -ine '.zip') { throw 'OLS1 response source is outside the exact approved response root.' }
$responseToken = [IO.Path]::GetFileNameWithoutExtension($sourceZip)
if ($responseToken -notmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready$') { throw 'OLS1 response token format changed.' }
$expectedZipBytes = [int64]$invocation.expectedZipBytes
$expectedZipSha256 = ([string]$invocation.expectedZipSha256).ToUpperInvariant()
if ($expectedZipBytes -lt 1 -or $expectedZipBytes -gt 2097152 -or $expectedZipSha256 -notmatch '^[0-9A-F]{64}$') { throw 'OLS1 response invocation size or hash is invalid.' }
$collectionRoot = 'C:\AS1R'
$localZip = $collectionRoot.TrimEnd('\') + '\' + $responseToken + '.zip'
$readyRoot = $collectionRoot.TrimEnd('\') + '\' + $responseToken
$partialRoot = $readyRoot + '.partial'
$terminalGatePath = Join-Path $workRoot 'OLS1_TERMINAL_RESPONSE_GATE.json'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

foreach ($path in @($sourceZip, $responseVerifier, $endpointCertificate, $pathTool)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS1 response prerequisite is missing: $path" }
}
if ((Get-Item -LiteralPath $sourceZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OLS1 source response ZIP changed.' }
foreach ($path in @($localZip, $readyRoot, $partialRoot, $terminalGatePath)) { if (Test-Path -LiteralPath $path) { throw "OLS1 response output already exists: $path" } }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $manifestEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    if ($null -eq $manifestEntry -or $manifestEntry.Length -gt 1048576) { throw 'OLS1 bounded response manifest entry is missing or too large.' }
    $stream = $manifestEntry.Open()
    $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false, $true)))
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose(); $stream.Dispose() }
}
finally { $archive.Dispose() }
if ([string]$manifest.requestId -ne $requestId -or [string]$manifest.sourceRole -ne 'JBOD' -or [string]$manifest.state -ne 'PASS_MAINTENANCE_PATCH' -or -not [bool]$manifest.reviewOnly -or [bool]$manifest.productionRoutingEnabled) { throw 'OLS1 response manifest terminal contract changed.' }

$planned = @($localZip, $readyRoot + '\PORTAL_RESPONSE_MANIFEST.json', $readyRoot + '\PORTAL_RESPONSE_MANIFEST.sig', $readyRoot + '\MAINTENANCE.stdout.txt', $partialRoot + '\PORTAL_RESPONSE_MANIFEST.json', $terminalGatePath)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OLS1 response collection path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols1_response_collection_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS1_RESPONSE_COLLECTION_PREFLIGHT'
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
if ((Get-Item -LiteralPath $localZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OLS1 local response ZIP changed during copy.' }
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
& $responseVerifier -PackagePath $partialRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'OLS1 signed response verification failed.' }
$extractedManifest = Get-Content -LiteralPath (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json') -Raw | ConvertFrom-Json
if ([string]$extractedManifest.state -ne 'PASS_MAINTENANCE_PATCH' -or @($extractedManifest.files).Count -ne 3) { throw 'OLS1 extracted terminal response contract changed.' }
$stdoutPath = Join-Path $partialRoot 'MAINTENANCE.stdout.txt'
if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -or (Get-Item -LiteralPath $stdoutPath).Length -gt 2097152) { throw 'OLS1 bounded maintenance stdout is missing or too large.' }
$entryResult = Get-Content -LiteralPath $stdoutPath -Raw | ConvertFrom-Json
$search = $entryResult.boundedPathNameSearch
$matches = @($search.matches)
if ([string]$entryResult.state -ne 'PASS_OCV00_BOUNDED_LOT_PATH_SEARCH_OLS1' -or -not [bool]$entryResult.metadataOnly -or -not [bool]$entryResult.pathsEnumerated -or [bool]$entryResult.filesRead -or [bool]$entryResult.imageBytesRead -or [bool]$entryResult.sourceHashingPerformed -or [bool]$entryResult.inspectionTasksChanged -or [bool]$entryResult.processorTaskChanged -or @($entryResult.processActions).Count -ne 0 -or [bool]$entryResult.sourceDeletionPerformed -or [bool]$entryResult.waferActionPerformed) { throw 'OLS1 signed maintenance stdout violated the exact metadata-only terminal contract.' }
if ([string]$search.schema -ne 'argos_bounded_path_name_search_v1' -or [string]$search.state -ne 'COMPLETE' -or -not [bool]$search.complete -or [string]$search.literalToken -ne '62616-115' -or [bool]$search.truncated -or [int]$search.accessErrorCount -ne 0 -or [int]$search.skippedReparseSubtrees -ne 0 -or [int]$search.skippedUnsafePathSubtrees -ne 0 -or $matches.Count -ne [int]$search.matchCount) { throw 'OLS1 signed bounded path-name search did not complete safely.' }
for ($index = 0; $index -lt $matches.Count; $index++) {
    if (-not [bool]$matches[$index].containedByApprovedRoot -or ([string]$matches[$index].name).IndexOf('62616-115',[StringComparison]::OrdinalIgnoreCase) -lt 0 -or [bool]$matches[$index].filesRead -or [bool]$matches[$index].imageBytesRead -or [bool]$matches[$index].sourceHashingPerformed -or [bool]$matches[$index].mutationsPerformed) { throw "OLS1 signed path-name row contract failed at index $index." }
}
Move-Item -LiteralPath $partialRoot -Destination $readyRoot

$gate = [ordered]@{
    schema = 'argos_ols1_terminal_response_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS1_SIGNED_TERMINAL_RESPONSE'
    requestId = $requestId
    responseToken = $responseToken
    endpointState = [string]$extractedManifest.state
    sourceRole = [string]$extractedManifest.sourceRole
    signedResponseVerified = $true
    responseFileCount = @($extractedManifest.files).Count
    sourceZipBytes = $expectedZipBytes
    sourceZipSha256 = $expectedZipSha256
    boundedPathNameSearch = $search
    metadataOnly = $true
    pathsEnumerated = $true
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
