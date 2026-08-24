[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('CHUNK01','CHUNK02','CHUNK03','CHUNK04','CHUNK05')]
    [string]$ChunkId,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Get-Sha256([string]$LiteralPath) { return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash }

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$ordinal = [int]$ChunkId.Substring(5, 2)
$suffix = '{0:D2}' -f $ordinal
$requestId = 'REQ_OLS6C' + $suffix
$finalRoot = Join-Path $root ('final_c' + $suffix)
$zipPath = Join-Path $finalRoot ($requestId + '.ready.zip')
$extractRoot = Join-Path $finalRoot 'extract'
$manifestPath = Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig'
$finalGatePath = Join-Path $root ('OLS6_' + $ChunkId + '_FINAL_PACKAGE_GATE.json')
$outputPath = Join-Path $root ('OLS6_' + $ChunkId + '_COMPLETE_ROUTE_GATE.json')
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
if (-not (Test-Path -LiteralPath $finalGatePath -PathType Leaf)) { throw 'OLS6 final package gate is missing.' }
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
if ([string]$finalGate.state -ne 'PASS_OLS6_CHUNK_FINAL_PACKAGE_GATE' -or [string]$finalGate.chunkId -ne $ChunkId -or [string]$finalGate.requestId -ne $requestId) { throw 'OLS6 final package gate identity changed.' }
foreach ($pin in @(
    @($zipPath, [string]$finalGate.requestZipSha256),
    @($manifestPath, [string]$finalGate.requestManifestSha256),
    @($signaturePath, [string]$finalGate.requestSignatureSha256)
)) {
    if (-not (Test-Path -LiteralPath $pin[0] -PathType Leaf) -or (Get-Sha256 $pin[0]) -ne [string]$pin[1]) { throw "OLS6 exact route artifact changed: $($pin[0])" }
}
$packageTest = & $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
if ([string]$packageTest.State -ne 'PASS_SIGNED_PORTAL_PACKAGE') { throw 'OLS6 exact extracted package signature verification failed.' }

$responseToken = 'R_0123456789AB_20260824215959999_a1b2c3d4.ready'
$paths = @(
    $finalGatePath,
    $zipPath,
    $manifestPath,
    $signaturePath,
    (Join-Path $extractRoot 'payload\Invoke-OCV00SourceHashChunkEndpoint.ps1'),
    (Join-Path $extractRoot 'payload\OCV00_SOURCE_HASH_CHUNK.json'),
    ('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip.upload'),
    ('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip'),
    ('C:\APR\S\requests\' + $requestId + '.ready.zip'),
    ('C:\APR\S\requests\processed\' + $requestId + '.ready.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\share\staging\' + $requestId + '.ready.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\share\request_archive\' + $requestId + '.ready.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $requestId + '.ready\payload\OCV00_SOURCE_HASH_CHUNK.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\sent\' + $requestId + '.ready\payload\Invoke-OCV00SourceHashChunkEndpoint.ps1'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $requestId + '.ready\payload\Invoke-OCV00SourceHashChunkEndpoint.ps1'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $requestId + '.ready\PORTAL_REQUEST_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\MAINTENANCE.stdout.txt'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\MAINTENANCE.stderr.txt'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\RESULT.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\compact\C_0123456789AB_01234567\FAILURE.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\' + $requestId + '.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\' + $requestId + '\prior\M000_0123456789_0123456789.prior'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\' + $requestId + '\failed_new\M000_0123456789_0123456789.rollback'),
    ('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.stage'),
    ('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.restore'),
    ('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV00_OLS6.ps1'),
    ('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV00_OLS6_' + $ChunkId + '_SOURCE_HASHES.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\response_quarantine\' + $responseToken + '.partial\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseToken + '.partial\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseToken + '\MAINTENANCE.stdout.txt'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\sent\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\APR\R\pending\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\APR\A\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\share\response_zip_archive\' + $responseToken + '.zip'),
    ('U:\ProjectPortalRO\responses\' + $responseToken + '.zip'),
    ('C:\A6R\' + $responseToken + '.zip'),
    ('C:\A6R\' + $responseToken + '\PORTAL_RESPONSE_MANIFEST.json'),
    ('C:\A6R\' + $responseToken + '\MAINTENANCE.stdout.txt'),
    $outputPath
)
if ($paths.Count -lt 40 -or $paths.Count -gt 128 -or @($paths | Sort-Object -Unique).Count -ne $paths.Count) { throw 'OLS6 route path set is incomplete or duplicated.' }
$rows = New-Object Collections.Generic.List[object]
foreach ($path in $paths) {
    $one = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    if ([string]$one.state -ne 'PASS_PATH_BUDGET' -or @($one.candidates).Count -ne 1) { throw "OLS6 route path budget failed: $path" }
    $row = @($one.candidates)[0]
    $rows.Add([pscustomobject]@{
        path = [string]$row.path
        pathLength = [int]$row.pathLength
        effectiveLength = [int]$row.effectiveLength
        longestComponentLength = [int]$row.longestComponentLength
        state = [string]$row.disposition
    })
}
$rowArray = $rows.ToArray()
$longest = @($rowArray | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$result = [ordered]@{
    schema = 'argos_ols6_chunk_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_OLS6_CHUNK_COMPLETE_ROUTE_PREFLIGHT' } else { 'PASS_OLS6_CHUNK_COMPLETE_ROUTE_GATE' }
    chunkId = $ChunkId
    requestId = $requestId
    jobClass = 'MAINTENANCE_PATCH'
    routePathRowsEvaluated = $rowArray.Count
    reservedSuffixCharacters = 32
    maximumPlannedEffectiveLength = [int]$longest.effectiveLength
    maximumPlannedComponentLength = [int](($rowArray | Measure-Object longestComponentLength -Maximum).Maximum)
    longestPath = [string]$longest.path
    endpointWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
    installedConfigEvidenceSha256 = '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'
    requestZipPath = [IO.Path]::GetFullPath($zipPath)
    requestZipSha256 = [string]$finalGate.requestZipSha256
    requestManifestSha256 = [string]$finalGate.requestManifestSha256
    requestSignatureSha256 = [string]$finalGate.requestSignatureSha256
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    inheritedQueueSafetyGateSha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
    rows = $rowArray
    mutationsPerformed = $false
    imageProcessingPerformed = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) { $result | ConvertTo-Json -Depth 8; return }
if (Test-Path -LiteralPath $outputPath) { throw 'OLS6 route gate output already exists.' }
[IO.File]::WriteAllText($outputPath, (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result.mutationsPerformed = $true
$result | ConvertTo-Json -Depth 8
