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
$requestId = 'REQ_OLS2'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
if ([string]$invocation.schema -ne 'argos_ols2_failure_response_collection_invocation_v1' -or [string]$invocation.requestId -ne $requestId) { throw 'OLS2 failure-response invocation contract changed.' }

$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$approvedResponseRoot = [IO.Path]::GetFullPath('U:\ProjectPortalRO\responses').TrimEnd('\')
if (-not $sourceZip.StartsWith($approvedResponseRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or -not ([IO.Path]::GetDirectoryName($sourceZip)).Equals($approvedResponseRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetExtension($sourceZip) -ine '.zip') { throw 'OLS2 failure response is outside the exact approved response root.' }
$responseToken = [IO.Path]::GetFileNameWithoutExtension($sourceZip)
if ($responseToken -notmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}\.ready$') { throw 'OLS2 failure-response token format changed.' }

$expectedZipBytes = [int64]$invocation.expectedZipBytes
$expectedZipSha256 = ([string]$invocation.expectedZipSha256).ToUpperInvariant()
if ($expectedZipBytes -lt 1 -or $expectedZipBytes -gt 2097152 -or $expectedZipSha256 -notmatch '^[0-9A-F]{64}$') { throw 'OLS2 failure-response size or hash is invalid.' }
$collectionRoot = [IO.Path]::GetFullPath([string]$invocation.collectionRoot).TrimEnd('\')
if (-not $collectionRoot.Equals('C:\AS2F', [StringComparison]::OrdinalIgnoreCase)) { throw 'OLS2 failure-response collection root changed.' }
$terminalGatePath = [IO.Path]::GetFullPath([string]$invocation.terminalGatePath)
$expectedTerminalGatePath = Join-Path $project 'work\OPENCV_OLS2\OLS2_SIGNED_FAILURE_GATE.json'
if (-not $terminalGatePath.Equals($expectedTerminalGatePath, [StringComparison]::OrdinalIgnoreCase)) { throw 'OLS2 failure-response terminal gate path changed.' }

$localZip = $collectionRoot + '\' + $responseToken + '.zip'
$readyRoot = $collectionRoot + '\' + $responseToken
$partialRoot = $readyRoot + '.partial'
$responseVerifier = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalResponse.ps1'
$endpointCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\active\JBOD_ENDPOINT_SIGNER.cer'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'

foreach ($path in @($sourceZip,$responseVerifier,$endpointCertificate,$pathTool)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS2 failure-response prerequisite is missing: $path" }
}
if ((Get-Item -LiteralPath $sourceZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $sourceZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OLS2 source failure-response ZIP changed.' }
foreach ($path in @($collectionRoot,$localZip,$readyRoot,$partialRoot,$terminalGatePath)) { if (Test-Path -LiteralPath $path) { throw "OLS2 failure-response output already exists: $path" } }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $entries = @($archive.Entries)
    if ($entries.Count -ne 5) { throw 'OLS2 bounded failure-response ZIP entry count changed.' }
    $manifestEntry = $archive.GetEntry('PORTAL_RESPONSE_MANIFEST.json')
    if ($null -eq $manifestEntry -or $manifestEntry.Length -gt 1048576) { throw 'OLS2 bounded failure-response manifest entry is missing or too large.' }
    $stream = $manifestEntry.Open()
    $reader = New-Object IO.StreamReader($stream, (New-Object Text.UTF8Encoding($false, $true)))
    try { $manifest = $reader.ReadToEnd() | ConvertFrom-Json }
    finally { $reader.Dispose(); $stream.Dispose() }
}
finally { $archive.Dispose() }
if ([string]$manifest.requestId -ne $requestId -or [string]$manifest.sourceRole -ne 'JBOD' -or [string]$manifest.state -ne 'FAILED' -or -not [bool]$manifest.reviewOnly -or [bool]$manifest.productionRoutingEnabled) { throw 'OLS2 failure-response terminal contract changed.' }
$declaredFiles = @($manifest.files | ForEach-Object { [string]$_.path } | Sort-Object)
$expectedFiles = @('FAILURE.json','MAINTENANCE.stderr.txt','MAINTENANCE.stdout.txt')
if (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $declaredFiles).Count -ne 0) { throw 'OLS2 failure-response file set changed.' }

$planned = @(
    $localZip,
    $readyRoot + '\PORTAL_RESPONSE_MANIFEST.json',
    $readyRoot + '\PORTAL_RESPONSE_MANIFEST.sig',
    $readyRoot + '\FAILURE.json',
    $readyRoot + '\MAINTENANCE.stderr.txt',
    $readyRoot + '\MAINTENANCE.stdout.txt',
    $partialRoot + '\PORTAL_RESPONSE_MANIFEST.json',
    $terminalGatePath
)
$pathGate = & $pathTool -CandidatePath $planned -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
if ([string]$pathGate.state -ne 'PASS_PATH_BUDGET') { throw "OLS2 failure-response collection path gate failed: $($pathGate.state)" }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols2_failure_response_collection_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS2_FAILURE_RESPONSE_COLLECTION_PREFLIGHT'
        requestId = $requestId
        responseToken = $responseToken
        untrustedEndpointState = [string]$manifest.state
        sourceZipBytes = $expectedZipBytes
        sourceZipSha256 = $expectedZipSha256
        responseFiles = $declaredFiles.Count
        pathState = [string]$pathGate.state
        mutationsPerformed = $false
        signedResponseVerified = $false
        imageBytesRead = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $collectionRoot)
Copy-Item -LiteralPath $sourceZip -Destination $localZip -ErrorAction Stop
if ((Get-Item -LiteralPath $localZip).Length -ne $expectedZipBytes -or (Get-FileHash -LiteralPath $localZip -Algorithm SHA256).Hash -ne $expectedZipSha256) { throw 'OLS2 local failure-response ZIP changed during copy.' }
[void](New-Item -ItemType Directory -Path $partialRoot)
[IO.Compression.ZipFile]::ExtractToDirectory($localZip, $partialRoot)
& $responseVerifier -PackagePath $partialRoot -EndpointCertificatePath $endpointCertificate -ExpectedSourceRole JBOD -ExpectedRequestId $requestId | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'OLS2 signed failure-response verification failed.' }
$extractedManifest = Get-Content -LiteralPath (Join-Path $partialRoot 'PORTAL_RESPONSE_MANIFEST.json') -Raw | ConvertFrom-Json
if ([string]$extractedManifest.state -ne 'FAILED' -or @($extractedManifest.files).Count -ne 3) { throw 'OLS2 extracted signed terminal-failure contract changed.' }
$responseRows = New-Object Collections.Generic.List[object]
foreach ($name in $expectedFiles) {
    $path = Join-Path $partialRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -gt 1048576) { throw "OLS2 bounded failure-response file is missing or too large: $name" }
    $responseRows.Add([pscustomobject]@{path=$name;bytes=[int64](Get-Item -LiteralPath $path).Length;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash})
}
$failure = Get-Content -LiteralPath (Join-Path $partialRoot 'FAILURE.json') -Raw | ConvertFrom-Json
Move-Item -LiteralPath $partialRoot -Destination $readyRoot

$gate = [ordered]@{
    schema = 'argos_ols2_terminal_failure_gate_v1'
    collectedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS2_SIGNED_TERMINAL_FAILURE_COLLECTED'
    disposition = 'SIGNED_TERMINAL_FAILURE'
    requestId = $requestId
    responseToken = $responseToken
    endpointState = [string]$extractedManifest.state
    sourceRole = [string]$extractedManifest.sourceRole
    signedResponseVerified = $true
    failureSchema = [string]$failure.schema
    failureState = [string]$failure.state
    failureMessage = [string]$failure.message
    responseFileCount = @($extractedManifest.files).Count
    responseFiles = $responseRows.ToArray()
    sourceZipBytes = $expectedZipBytes
    sourceZipSha256 = $expectedZipSha256
    collectedRoot = $readyRoot
    pathState = [string]$pathGate.state
    inventoryPassClaimed = $false
    sourceHashesAccepted = $false
    pixelScoringAllowed = $false
    terminalFailureRequiresDirectObservationBeforeMutation = $true
    filesReadFromLot = $false
    imageBytesRead = $false
    sourceHashingPerformed = $false
    inspectionTasksChanged = $false
    processorTaskChanged = $false
    sourceDeletionPerformed = $false
    currentWaferAborted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
[IO.File]::WriteAllText($terminalGatePath, (($gate | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$gate | ConvertTo-Json -Depth 8
