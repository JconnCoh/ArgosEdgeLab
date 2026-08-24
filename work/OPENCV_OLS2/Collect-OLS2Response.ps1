[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory = $true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Get-FileHash {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath,[ValidateSet('SHA256')][string]$Algorithm='SHA256')
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        Get-Content -LiteralPath $LiteralPath -Encoding Byte -ReadCount 1048576|ForEach-Object{
            [byte[]]$block=@($_)
            if($block.Length-gt0){[void]$sha.TransformBlock($block,0,$block.Length,$block,0)}
        }
        [void]$sha.TransformFinalBlock([byte[]]@(),0,0)
        return [pscustomobject]@{Algorithm='SHA256';Hash=([BitConverter]::ToString($sha.Hash)).Replace('-','');Path=$LiteralPath}
    }finally{$sha.Dispose()}
}

$project = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab'
$workRoot = Join-Path $project 'work\OPENCV_OLS2'
$requestId = 'REQ_OLS2'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_ols2_response_collection_invocation_v1' -or [string]$invocation.requestId -ne $requestId) { throw 'OLS2 response collection invocation contract changed.' }
$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = [IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\')
if (-not $sourceZip.StartsWith($approvedResponseRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedResponseRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($sourceZip) -ine '.zip') { throw 'OLS2 response source is outside the exact approved response root.' }
$responseToken = [IO.Path]::GetFileNameWithoutExtension($sourceZip)
if ($responseToken -notmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready$') { throw 'OLS2 response token format changed.' }
$expectedZipBytes = [int64]$invocation.expectedZipBytes
$expectedZipSha256 = ([string]$invocation.expectedZipSha256).ToUpperInvariant()
if ($expectedZipBytes -lt 1 -or $expectedZipBytes -gt 2097152 -or $expectedZipSha256 -notmatch '^[0-9A-F]{64}$') { throw 'OLS2 response invocation size or hash is invalid.' }
$collectionRoot = 'C:\AS2R'
$localZip = $collectionRoot.TrimEnd('\') + '\' + $responseToken + '.zip'
$readyRoot = $collectionRoot.TrimEnd('\') + '\' + $responseToken
$partialRoot = $readyRoot + '.partial'
$terminalGatePath = Join-Path $workRoot 'OLS2_TERMINAL_RESPONSE_GATE.json'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

foreach ($path in @($sourceZip, $responseVerifier, $endpointCertificate, $pathTool)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS2 response prerequisite is missing: $path" }
}
if ((Get-Item -LiteralPath $sourceZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OLS2 source response ZIP changed.' }
foreach ($path in @($localZip, $readyRoot, $partialRoot, $terminalGatePath)) { if (Test-Path -LiteralPath $path) { throw "OLS2 response output already exists: $path" } }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $manifestEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    if ($null -eq $manifestEntry -or $manifestEntry.Length -gt 1048576) { throw 'OLS2 bounded response manifest entry is missing or too large.' }
    $stream = $manifestEntry.Open()
    $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false, $true)))
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose(); $stream.Dispose() }
}
finally { $archive.Dispose() }
if ([string]$manifest.requestId -ne $requestId -or [string]$manifest.sourceRole -ne 'JBOD' -or [string]$manifest.state -ne 'PASS_MAINTENANCE_PATCH' -or -not [bool]$manifest.reviewOnly -or [bool]$manifest.productionRoutingEnabled) { throw 'OLS2 response manifest terminal contract changed.' }

$planned = @($localZip, $readyRoot + '\PORTAL_RESPONSE_MANIFEST.json', $readyRoot + '\PORTAL_RESPONSE_MANIFEST.sig', $readyRoot + '\MAINTENANCE.stdout.txt', $partialRoot + '\PORTAL_RESPONSE_MANIFEST.json', $terminalGatePath)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OLS2 response collection path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols2_response_collection_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS2_RESPONSE_COLLECTION_PREFLIGHT'
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
if ((Get-Item -LiteralPath $localZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OLS2 local response ZIP changed during copy.' }
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
& $responseVerifier -PackagePath $partialRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'OLS2 signed response verification failed.' }
$extractedManifest = Get-Content -LiteralPath (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json') -Raw | ConvertFrom-Json
if ([string]$extractedManifest.state -ne 'PASS_MAINTENANCE_PATCH' -or @($extractedManifest.files).Count -ne 3) { throw 'OLS2 extracted terminal response contract changed.' }
$stdoutPath = Join-Path $partialRoot 'MAINTENANCE.stdout.txt'
if (-not (Test-Path -LiteralPath $stdoutPath -PathType Leaf) -or (Get-Item -LiteralPath $stdoutPath).Length -gt 2097152) { throw 'OLS2 bounded maintenance stdout is missing or too large.' }
$entryResult = Get-Content -LiteralPath $stdoutPath -Raw | ConvertFrom-Json
$subtree = $entryResult.boundedSubtreeInventory
$directories = @($subtree.directories)
$bmpLeaves = @($subtree.bmpLeaves)
if ([string]$entryResult.state -ne 'PASS_OCV00_BOUNDED_LOT_SUBTREE_INVENTORY_OLS2' -or -not [bool]$entryResult.metadataOnly -or -not [bool]$entryResult.pathsEnumerated -or [bool]$entryResult.filesRead -or [bool]$entryResult.imageBytesRead -or [bool]$entryResult.sourceHashingPerformed -or [bool]$entryResult.inspectionTasksChanged -or [bool]$entryResult.processorTaskChanged -or @($entryResult.processActions).Count -ne 0 -or [bool]$entryResult.sourceDeletionPerformed -or [bool]$entryResult.waferActionPerformed) { throw 'OLS2 signed maintenance stdout violated the exact metadata-only terminal contract.' }
if ([string]$subtree.schema -ne 'argos_bounded_subtree_inventory_v1' -or [string]$subtree.state -ne 'COMPLETE' -or -not [bool]$subtree.complete -or [string]$subtree.relativeRoot -ne 'PatternedFront\Lot_62619-433' -or [string]$subtree.aliasReadRoot -ne 'F:\PatternedFront\Lot_62619-433' -or [bool]$subtree.truncated -or [int]$subtree.accessErrorCount -ne 0 -or [int]$subtree.skippedReparseSubtrees -ne 0 -or [int]$subtree.skippedUnsafePathSubtrees -ne 0 -or [int]$subtree.depthBoundaryDirectoryCount -ne 0 -or $directories.Count -ne [int]$subtree.directoryCount -or $bmpLeaves.Count -ne [int]$subtree.bmpLeafCount) { throw 'OLS2 signed bounded subtree inventory did not complete safely.' }
for ($index = 0; $index -lt $directories.Count; $index++) {
    if (-not [bool]$directories[$index].containedByApprovedRoot -or -not ([string]$directories[$index].relativePath).StartsWith('PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or -not ([string]$directories[$index].aliasReadPath).StartsWith('F:\PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or [int]$directories[$index].canonicalEffectiveLength -ge 230 -or [int]$directories[$index].aliasEffectiveLength -ge 200 -or [bool]$directories[$index].reparsePoint -or [bool]$directories[$index].filesRead -or [bool]$directories[$index].imageBytesRead -or [bool]$directories[$index].sourceHashingPerformed -or [bool]$directories[$index].mutationsPerformed) { throw "OLS2 signed directory metadata row contract failed at index $index." }
}
for ($index = 0; $index -lt $bmpLeaves.Count; $index++) {
    if (-not [bool]$bmpLeaves[$index].containedByApprovedRoot -or -not ([string]$bmpLeaves[$index].relativePath).StartsWith('PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or -not ([string]$bmpLeaves[$index].aliasReadPath).StartsWith('F:\PatternedFront\Lot_62619-433\',[StringComparison]::OrdinalIgnoreCase) -or [string]$bmpLeaves[$index].extension -ne '.bmp' -or [int]$bmpLeaves[$index].canonicalEffectiveLength -ge 230 -or [int]$bmpLeaves[$index].aliasEffectiveLength -ge 200 -or [bool]$bmpLeaves[$index].reparsePoint -or [bool]$bmpLeaves[$index].filesRead -or [bool]$bmpLeaves[$index].imageBytesRead -or [bool]$bmpLeaves[$index].sourceHashingPerformed -or [bool]$bmpLeaves[$index].mutationsPerformed) { throw "OLS2 signed BMP metadata row contract failed at index $index." }
}
Move-Item -LiteralPath $partialRoot -Destination $readyRoot

$gate = [ordered]@{
    schema = 'argos_ols2_terminal_response_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS2_SIGNED_TERMINAL_RESPONSE'
    requestId = $requestId
    responseToken = $responseToken
    endpointState = [string]$extractedManifest.state
    sourceRole = [string]$extractedManifest.sourceRole
    signedResponseVerified = $true
    responseFileCount = @($extractedManifest.files).Count
    sourceZipBytes = $expectedZipBytes
    sourceZipSha256 = $expectedZipSha256
    boundedSubtreeInventory = $subtree
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
