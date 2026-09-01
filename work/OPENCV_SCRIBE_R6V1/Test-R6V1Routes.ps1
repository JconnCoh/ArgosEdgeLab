#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}
function Add-UniquePath([Collections.Generic.List[string]]$List, [Collections.Generic.HashSet[string]]$Set, [string]$Path) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) 'R6V1 route path is empty.'
    Assert-True ($Set.Add($Path)) "R6V1 duplicate route path: $Path"
    $List.Add($Path)
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = $PSScriptRoot
$requestId = 'REQ_20260901T160000111Z_7F77B8EFE092'
$requestReadyName = $requestId + '.ready'
$responseReadyName = 'R_0123456789AB_20260901160135999_a1b2c3d4.ready'
$responsePartialName = $responseReadyName + '.partial'
$finalGatePath = Join-Path $root 'R6V1_FINAL_PACKAGE_GATE.json'
$zipPath = Join-Path $root ('final\' + $requestReadyName + '.zip')
$extractRoot = Join-Path $root 'final\extract'
$outputPath = Join-Path $root 'R6V1_PATH_ROUTE_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$queueGatePath = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$inheritedRoutePath = Join-Path $project 'work\OPENCV_SCRIBE_O2D23\O2D23_COMPLETE_ROUTE_GATE.json'

foreach ($dependency in @($finalGatePath,$zipPath,(Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig'),$pathTool,$packageTester,$publicCertificate,$queueGatePath,$inheritedRoutePath)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "R6V1 route dependency absent: $dependency"
}
Assert-True ((Get-Sha256 $finalGatePath) -eq '04E8330DAF95AE6274626F50284B1312118402BD5565F44EEDBD56F940D9BFB4') 'R6V1 final package gate changed.'
Assert-True ((Get-Sha256 $queueGatePath) -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'R6V1 inherited queue-safety gate changed.'
Assert-True ((Get-Sha256 $inheritedRoutePath) -eq 'D161C4891688D6A76F7AD84EBBC935B7D14488CF21D7CF91E6F9944197B8706E') 'R6V1 inherited route-root evidence changed.'
$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_R6V1_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId -and -not [bool]$finalGate.publicationAuthorized) 'R6V1 final package identity/authority changed.'
Assert-True ((Get-Sha256 $zipPath) -eq [string]$finalGate.requestZipSha256) 'R6V1 final ZIP changed.'
Assert-True ((Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json')) -eq [string]$finalGate.requestManifestSha256) 'R6V1 extracted manifest changed.'
Assert-True ((Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig')) -eq [string]$finalGate.requestSignatureSha256) 'R6V1 extracted signature changed.'
$packageTest = & $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R6V1 exact signed package verification failed.'
$manifest = Get-Content -Raw -LiteralPath (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json') | ConvertFrom-Json
Assert-True ([string]$manifest.requestId -eq $requestId -and [int64]$manifest.maxResultBytes -eq 16777216 -and @($manifest.files).Count -eq 7) 'R6V1 manifest route/result bound changed.'
Assert-True ([int]$manifest.timeoutContract.maximumSequentialChildren -eq 4 -and [int]$manifest.timeoutContract.endpointWorkerOuterTimeoutSeconds -eq 3000) 'R6V1 timeout contract changed.'
Assert-True (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1) 'R6V1 action contract changed.'

$requestLeaves = @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload\Invoke-R6V1ScribeBatch.ps1','payload\ArgosOpenCvScribeV1R6.py','payload\BATCH.json','payload\S22.json','payload\S23.json','payload\S24.json','payload\S25.json')
$responseLeaves = @('PORTAL_RESPONSE_MANIFEST.json','PORTAL_RESPONSE_MANIFEST.sig','MAINTENANCE.stdout.txt','MAINTENANCE.stderr.txt','RESULT.json')
$requestRoots = @(
    $extractRoot,
    ('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_jbod\sent\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\failed\' + $requestReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\replayed\' + $requestReadyName)
)
$responseRoots = @(
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\response_quarantine\' + $responsePartialName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responsePartialName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReadyName),
    ('C:\ProgramData\ArgosProjectPortalRO\to_gateway\sent\' + $responseReadyName),
    ('C:\APR\R\pending\' + $responseReadyName),
    ('C:\APR\A\' + $responseReadyName),
    ('C:\A6R\' + $responseReadyName)
)
$paths = New-Object Collections.Generic.List[string]
$pathSet = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
foreach ($path in @($finalGatePath,$zipPath,$outputPath,('U:\ProjectPortalRO\requests\' + $requestReadyName + '.zip.upload'),('U:\ProjectPortalRO\requests\' + $requestReadyName + '.zip'),('C:\APR\S\requests\' + $requestReadyName + '.zip'),('C:\APR\S\requests\processed\' + $requestReadyName + '.zip'),('C:\ProgramData\ArgosProjectPortalRO\share\staging\' + $requestReadyName + '.zip'),('C:\ProgramData\ArgosProjectPortalRO\share\request_archive\' + $requestReadyName + '.zip'),('C:\ProgramData\ArgosProjectPortalRO\share\response_zip_archive\' + $responseReadyName + '.zip'),('U:\ProjectPortalRO\responses\' + $responseReadyName + '.zip'),('C:\A6R\' + $responseReadyName + '.zip'))) { Add-UniquePath $paths $pathSet $path }
foreach ($requestRoot in $requestRoots) { foreach ($leaf in $requestLeaves) { Add-UniquePath $paths $pathSet (Join-Path $requestRoot $leaf) } }
foreach ($path in @(
    'D:\KLARFExport\PatternedFront\Lot_62619-433','X:\','D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\MAINTENANCE.stdout.txt',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\MAINTENANCE.stderr.txt',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\RESULT.json',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\compact\C_0123456789AB_01234567\FAILURE.json',
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\' + $requestId + '.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\' + $requestId + '\prior\M000_0123456789_0123456789.prior'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\' + $requestId + '\failed_new\M000_0123456789_0123456789.rollback'),
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.stage',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.restore',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_R6V1.ps1',
    'D:\A2\w\ocv\R6V1A.partial\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json',
    'D:\A2\w\ocv\R6V1A\ArgosOpenCvScribeV1R6.py','D:\A2\w\ocv\R6V1A\BATCH.json','D:\A2\w\ocv\R6V1A\S25.json',
    'D:\A2\w\ocv\R6V1A\refs\glyphs_v5_confirmed_20260806\028_62630_456_SLOT25_P04_S.png',
    'D:\A2\o\ocv\R6V1A\Slot22\RESULT.json','D:\A2\o\ocv\R6V1A\Slot23\RESULT.json','D:\A2\o\ocv\R6V1A\Slot24\RESULT.json','D:\A2\o\ocv\R6V1A\Slot25\RESULT.json','D:\A2\o\ocv\R6V1A\BATCH_GATE.json','D:\A2\o\ocv\R6V1A\EXECUTION.json'
)) { Add-UniquePath $paths $pathSet $path }
foreach ($slot in 22..25) {
    foreach ($channel in @('Brightfield','Darkfield')) {
        $folder = if ($channel -eq 'Brightfield') { 'BrightfieldFrontsideWafer' } else { 'DarkfieldFrontsideWafer' }
        $file = if ($channel -eq 'Brightfield') { "62619-433_Slot${slot}_BrightfieldFrontsideWafer_PM2_resizedImage.bmp" } else { "62619-433_Slot${slot}_DarkfieldFrontsideWafer_PM2_resizedImage.bmp" }
        Add-UniquePath $paths $pathSet ("X:\62619-433_20260824005735\Slot${slot}\$folder\resizedImage\$file")
    }
}
foreach ($responseRoot in $responseRoots) { foreach ($leaf in $responseLeaves) { Add-UniquePath $paths $pathSet (Join-Path $responseRoot $leaf) } }
Assert-True ($paths.Count -ge 160 -and $paths.Count -le 190) "R6V1 route path cardinality changed: $($paths.Count)"
$rows = New-Object Collections.Generic.List[object]
foreach ($path in $paths) {
    $checked = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    Assert-True ([string]$checked.state -eq 'PASS_PATH_BUDGET' -and @($checked.candidates).Count -eq 1) "R6V1 route path budget failed: $path"
    $row = @($checked.candidates)[0]
    $rows.Add([pscustomobject]@{path=[string]$row.path;pathLength=[int]$row.pathLength;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;disposition=[string]$row.disposition})
}
$rowArray = $rows.ToArray()
$longest = @($rowArray | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$maximumComponentLength = [int](($rowArray | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ([int]$longest.effectiveLength -lt 200 -and $maximumComponentLength -le 80) 'R6V1 complete route exceeds safe path budget.'
$state = if ($Preflight) { 'PASS_R6V1_PATH_ROUTE_PREFLIGHT' } else { 'PASS_R6V1_PATH_ROUTE_GATE' }
$result = [ordered]@{schema='argos_r6v1_path_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=$state;requestId=$requestId;jobClass='MAINTENANCE_PATCH';routePathRowsEvaluated=$rowArray.Count;requestLeafCountPerExtractedHop=$requestLeaves.Count;requestExtractedHopCount=$requestRoots.Count;responseLeafCountPerHop=$responseLeaves.Count;responseHopCount=$responseRoots.Count;reservedSuffixCharacters=32;pathBudgetState='PASS_PATH_BUDGET';maximumEffectiveLength=[int]$longest.effectiveLength;maximumComponentLength=$maximumComponentLength;longestPath=[string]$longest.path;requestZipSha256=[string]$finalGate.requestZipSha256;requestManifestSha256=[string]$finalGate.requestManifestSha256;requestSignatureSha256=[string]$finalGate.requestSignatureSha256;finalPackageGateSha256=Get-Sha256 $finalGatePath;endpointPayloadSha256=[string]$finalGate.endpointSha256;inheritedQueueSafetyGateSha256=Get-Sha256 $queueGatePath;inheritedRouteRootGateSha256=Get-Sha256 $inheritedRoutePath;routeRootsRediscovered=$false;currentRouteHealthObservationRequiredBeforePublication=$true;publicationAuthorized=$false;retryAuthorized=$false;targetExecuted=$false;targetMutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;localEvidenceWritten=[bool]$Gate;rows=$rowArray;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 10; return }
Assert-True (-not (Test-Path -LiteralPath $outputPath)) 'R6V1 route gate exists.'
[IO.File]::WriteAllText($outputPath, (($result | ConvertTo-Json -Depth 10) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result | ConvertTo-Json -Depth 10
