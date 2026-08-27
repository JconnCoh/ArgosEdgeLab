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
function Get-FileHash {
    param(
        [Parameter(Mandatory=$true)][string]$LiteralPath,
        [Parameter(Mandatory=$true)][ValidateSet('SHA256')][string]$Algorithm
    )
    return [pscustomobject]@{ Hash = Get-Sha256 $LiteralPath; Algorithm = $Algorithm; Path = $LiteralPath }
}
function Add-UniquePath([Collections.Generic.List[string]]$List, [Collections.Generic.HashSet[string]]$Set, [string]$Path) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($Path)) 'O2D23 route path is empty.'
    Assert-True ($Set.Add($Path)) "O2D23 duplicate route path: $Path"
    $List.Add($Path)
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = $PSScriptRoot
$requestId = 'REQ_20260827T035500111Z_3C97863DBF26'
$requestReadyName = $requestId + '.ready'
$responseReadyName = 'R_0123456789AB_20260827012345999_a1b2c3d4.ready'
$responsePartialName = $responseReadyName + '.partial'
$finalGatePath = Join-Path $root 'O2D23_FINAL_PACKAGE_GATE.json'
$zipPath = Join-Path $root ('final\' + $requestReadyName + '.zip')
$extractRoot = Join-Path $root 'final\extract'
$outputPath = Join-Path $root 'O2D23_COMPLETE_ROUTE_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$jeoPath = Join-Path $project 'work\JBOD_EVIDENCE_OBSERVATION_JEO1\collected\JEO1R_67AA1559\extract\JEO1_OBSERVATION.json'
$queueGatePath = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'

foreach ($dependency in @($finalGatePath,$zipPath,(Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json'),(Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig'),$pathTool,$packageTester,$publicCertificate,$jeoPath,$queueGatePath)) {
    Assert-True (Test-Path -LiteralPath $dependency -PathType Leaf) "O2D23 route dependency absent: $dependency"
}
Assert-True ((Get-Sha256 $finalGatePath) -eq '532CCF66A5BC1ACE7B2C3FBE844D50B876E13F91CEC04C20D953D494604C8B50') 'O2D23 final package gate changed.'
Assert-True ((Get-Sha256 $jeoPath) -eq '91B5A9219F72845187D7CB17DAB0F1D74AF223E7DDA11E380EEA26148C60CD01') 'O2D23 direct JBOD observation changed.'
Assert-True ((Get-Sha256 $queueGatePath) -eq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D') 'O2D23 inherited queue-safety gate changed.'

$finalGate = Get-Content -Raw -LiteralPath $finalGatePath | ConvertFrom-Json
Assert-True ([string]$finalGate.state -eq 'PASS_O2D23_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O2D23 final package identity changed.'
Assert-True (-not [bool]$finalGate.publicationAuthorized -and [bool]$finalGate.publicationRequiresCompleteRouteGate) 'O2D23 final package publication boundary changed.'
Assert-True ([bool]$finalGate.maintenanceInstalledShaMatchesPayload -and [string]$finalGate.endpointPayloadSha256 -eq '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740' -and [string]$finalGate.declaredInstalledSha256 -eq [string]$finalGate.endpointPayloadSha256) 'O2D23 endpoint payload and declared installed hashes diverged.'
Assert-True ([string]$finalGate.entrypointTestGateState -eq 'PASS_O2D23_ENTRYPOINT_TEST_GATE_R2' -and [string]$finalGate.entrypointTestGateSha256 -eq '17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1') 'O2D23 entrypoint test gate changed.'
Assert-True ([string]$finalGate.selfPinGateState -eq 'PASS_O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE' -and [string]$finalGate.selfPinGateSha256 -eq 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5' -and [int]$finalGate.endpointSelfPinCount -eq 6 -and [int]$finalGate.endpointSelfPinMatchCount -eq 6 -and [int]$finalGate.liveAssertionBranchCaseCount -eq 3) 'O2D23 self-pin or live-branch gate changed.'
Assert-True ((Get-Sha256 $zipPath) -eq [string]$finalGate.requestZipSha256) 'O2D23 final ZIP changed.'
Assert-True ((Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json')) -eq [string]$finalGate.requestManifestSha256) 'O2D23 extracted request manifest changed.'
Assert-True ((Get-Sha256 (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.sig')) -eq [string]$finalGate.requestSignatureSha256) 'O2D23 extracted request signature changed.'
$packageTest = & $packageTester -PackagePath $extractRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Assert-True ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'O2D23 exact signed package verification failed.'

$manifest = Get-Content -Raw -LiteralPath (Join-Path $extractRoot 'PORTAL_REQUEST_MANIFEST.json') | ConvertFrom-Json
Assert-True ([string]$manifest.requestId -eq $requestId -and [string]$manifest.targetRole -eq 'JBOD' -and [string]$manifest.jobClass -eq 'MAINTENANCE_PATCH') 'O2D23 request route changed.'
Assert-True ([int64]$manifest.maxResultBytes -eq 4194304 -and @($manifest.files).Count -eq 3) 'O2D23 request file or result bound changed.'
Assert-True ([string]$manifest.entryPoint -eq 'payload/Invoke-O2D23ScribeEndpoint.ps1' -and [string]$manifest.rehearsal.requiredState -eq 'PASS_O2D23_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED') 'O2D23 entrypoint contract changed.'
Assert-True ([string]$manifest.rehearsal.gateState -eq 'PASS_O2D23_ENTRYPOINT_TEST_GATE_R2' -and [string]$manifest.rehearsal.gateSha256 -eq '17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1') 'O2D23 signed rehearsal declaration changed.'
Assert-True ([string]$manifest.rehearsal.selfPinGateState -eq 'PASS_O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE' -and [string]$manifest.rehearsal.selfPinGateSha256 -eq 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5') 'O2D23 signed self-pin declaration changed.'
Assert-True (@($manifest.changes).Count -eq 1 -and [string]$manifest.changes[0].source -eq 'payload/Invoke-O2D23ScribeEndpoint.ps1' -and [string]$manifest.changes[0].installedSha256 -eq '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740') 'O2D23 signed maintenance source or installed hash changed.'
Assert-True ([int]$manifest.timeoutContract.endpointWorkerOuterTimeoutSeconds -eq 900 -and [int]$manifest.timeoutContract.opencvChildTimeoutSeconds -eq 600) 'O2D23 timeout contract changed.'
Assert-True (@($manifest.allowedTaskActions).Count -eq 0 -and @($manifest.allowedProcessActions).Count -eq 1) 'O2D23 action contract changed.'

$jeo = Get-Content -Raw -LiteralPath $jeoPath | ConvertFrom-Json
Assert-True ([string]$jeo.state -eq 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION' -and [string]$jeo.computerName -eq 'A1025645101') 'O2D23 direct JBOD observation identity changed.'
$endpointWorkerRows = @($jeo.sourceResults | Where-Object { [string]$_.id -eq 'ENDPOINT_WORKER' })
Assert-True ($endpointWorkerRows.Count -eq 1 -and @($endpointWorkerRows[0].rows).Count -eq 1 -and [string]$endpointWorkerRows[0].rows[0].sha256 -eq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'O2D23 observed endpoint worker pin changed.'
$endpointProcess = @($jeo.relevantProcesses | Where-Object { [string]$_.commandLine -like '*Invoke-ArgosProjectPortalEndpointWorker.ps1*' })
$senderProcess = @($jeo.relevantProcesses | Where-Object { [string]$_.commandLine -like '*JBOD_RESPONSE_SENDER.json*' })
Assert-True ($endpointProcess.Count -eq 1 -and $senderProcess.Count -ge 1) 'O2D23 observed JBOD portal process evidence changed.'

$requestLeaves = @(
    'PORTAL_REQUEST_MANIFEST.json',
    'PORTAL_REQUEST_MANIFEST.sig',
    'payload\Invoke-O2D23ScribeEndpoint.ps1',
    'payload\ArgosOpenCvScribeV1R5.py',
    'payload\O2D23_SLOT25_JOB.json'
)
$responseLeaves = @(
    'PORTAL_RESPONSE_MANIFEST.json',
    'PORTAL_RESPONSE_MANIFEST.sig',
    'MAINTENANCE.stdout.txt',
    'MAINTENANCE.stderr.txt',
    'RESULT.json'
)
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
foreach ($path in @(
    $finalGatePath,
    $zipPath,
    $outputPath,
    ('U:\ProjectPortalRO\requests\' + $requestReadyName + '.zip.upload'),
    ('U:\ProjectPortalRO\requests\' + $requestReadyName + '.zip'),
    ('C:\APR\S\requests\' + $requestReadyName + '.zip'),
    ('C:\APR\S\requests\processed\' + $requestReadyName + '.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\share\staging\' + $requestReadyName + '.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\share\request_archive\' + $requestReadyName + '.zip'),
    ('C:\ProgramData\ArgosProjectPortalRO\share\response_zip_archive\' + $responseReadyName + '.zip'),
    ('U:\ProjectPortalRO\responses\' + $responseReadyName + '.zip'),
    ('C:\A6R\' + $responseReadyName + '.zip')
)) { Add-UniquePath $paths $pathSet $path }
foreach ($requestRoot in $requestRoots) {
    foreach ($leaf in $requestLeaves) { Add-UniquePath $paths $pathSet (Join-Path $requestRoot $leaf) }
}
foreach ($path in @(
    'D:\KLARFExport\PatternedFront\Lot_62619-433',
    'X:\62619-433_20260824005735\Slot25\BrightfieldFrontsideWafer\resizedImage\62619-433_Slot25_BrightfieldFrontsideWafer_PM2_resizedImage.bmp',
    'X:\62619-433_20260824005735\Slot25\DarkfieldFrontsideWafer\resizedImage\62619-433_Slot25_DarkfieldFrontsideWafer_PM2_resizedImage.bmp',
    'X:\',
    'D:\O2D5\ARGOS_O2D5\O2D5_REFS.zip',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\MAINTENANCE.stdout.txt',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\MAINTENANCE.stderr.txt',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_01234567\RESULT.json',
    'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\compact\C_0123456789AB_01234567\FAILURE.json',
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\' + $requestId + '.json'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\' + $requestId + '\prior\M000_0123456789_0123456789.prior'),
    ('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\' + $requestId + '\failed_new\M000_0123456789_0123456789.rollback'),
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.stage',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.restore',
    'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV02_O2D23.ps1',
    'D:\A2\w\ocv\O2D23_20260827T035500000Z_3C97863D.partial\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json',
    'D:\A2\w\ocv\O2D23_20260827T035500000Z_3C97863D\ArgosOpenCvScribeV1R5.py',
    'D:\A2\w\ocv\O2D23_20260827T035500000Z_3C97863D\JOB.json',
    'D:\A2\w\ocv\O2D23_20260827T035500000Z_3C97863D\refs\glyphs_v5_confirmed_20260806\028_62630_456_SLOT25_P04_S.png',
    'D:\A2\o\ocv\O2D23_20260827T035500000Z_3C97863D\RESULT.json',
    'D:\A2\o\ocv\O2D23_20260827T035500000Z_3C97863D\RUN_GATE.json',
    'D:\A2\o\ocv\O2D23_20260827T035500000Z_3C97863D\EXECUTION.json'
)) { Add-UniquePath $paths $pathSet $path }
foreach ($responseRoot in $responseRoots) {
    foreach ($leaf in $responseLeaves) { Add-UniquePath $paths $pathSet (Join-Path $responseRoot $leaf) }
}
Assert-True ($paths.Count -ge 120 -and $paths.Count -le 160) "O2D23 route path cardinality changed: $($paths.Count)"

$rows = New-Object Collections.Generic.List[object]
foreach ($path in $paths) {
    $checked = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    Assert-True ([string]$checked.state -eq 'PASS_PATH_BUDGET' -and @($checked.candidates).Count -eq 1) "O2D23 route path budget failed: $path"
    $row = @($checked.candidates)[0]
    $rows.Add([pscustomobject]@{
        path = [string]$row.path
        pathLength = [int]$row.pathLength
        effectiveLength = [int]$row.effectiveLength
        longestComponentLength = [int]$row.longestComponentLength
        disposition = [string]$row.disposition
    })
}
$rowArray = $rows.ToArray()
$longest = @($rowArray | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$maximumComponentLength = [int](($rowArray | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ([int]$longest.effectiveLength -lt 200 -and $maximumComponentLength -le 80) 'O2D23 complete route exceeds the safe materialized path budget.'

$state = $(if ($Preflight) { 'HOLD_O2D23_COMPLETE_ROUTE_PREFLIGHT_ARGOS_INBOUND_RELAY_UNPROVEN' } else { 'HOLD_O2D23_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN' })
$result = [ordered]@{
    schema = 'argos_o2d23_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = $state
    requestId = $requestId
    jobClass = 'MAINTENANCE_PATCH'
    routePathRowsEvaluated = $rowArray.Count
    requestLeafCountPerExtractedHop = $requestLeaves.Count
    requestExtractedHopCount = $requestRoots.Count
    responseLeafCountPerHop = $responseLeaves.Count
    responseHopCount = $responseRoots.Count
    reservedSuffixCharacters = 32
    pathBudgetState = 'PASS_PATH_BUDGET'
    maximumEffectiveLength = [int]$longest.effectiveLength
    maximumComponentLength = $maximumComponentLength
    longestPath = [string]$longest.path
    requestZipSha256 = [string]$finalGate.requestZipSha256
    requestManifestSha256 = [string]$finalGate.requestManifestSha256
    requestSignatureSha256 = [string]$finalGate.requestSignatureSha256
    finalPackageGateSha256 = '532CCF66A5BC1ACE7B2C3FBE844D50B876E13F91CEC04C20D953D494604C8B50'
    endpointPayloadSha256 = '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'
    declaredInstalledSha256 = '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'
    maintenanceInstalledShaMatchesPayload = $true
    declaredRehearsalGateState = 'PASS_O2D23_ENTRYPOINT_TEST_GATE_R2'
    declaredRehearsalGateSha256 = '17EFFBE2B9557688BFD4181B3DC6F8F3E01687E0FF9FBC59DDA0967370B40CF1'
    declaredSelfPinGateState = 'PASS_O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE'
    declaredSelfPinGateSha256 = 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'
    endpointWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
    installedEndpointConfigSha256 = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
    inheritedQueueSafetyGateSha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
    directJbodObservationSha256 = '91B5A9219F72845187D7CB17DAB0F1D74AF223E7DDA11E380EEA26148C60CD01'
    jbodEndpointWorkerObserved = $true
    jbodResponseSenderObserved = $true
    o2d4ConfirmedAbsentFromJbod = $true
    argosInboundRelayCurrentHealthProved = $false
    routeHealthDisposition = 'HOLD_CURRENT_ARGOS_INBOUND_RELAY_HEALTH_NOT_DIRECTLY_PROVED'
    requiredNextObservation = 'DIRECT_READ_ONLY_ARGOS_INBOUND_RELAY_AND_QUEUE_HEALTH'
    retryAuthorized = $false
    publicationAuthorized = $false
    targetExecuted = $false
    targetMutationsPerformed = $false
    sourceImageBytesRead = $false
    providerActivated = $false
    localEvidenceWritten = [bool]$Gate
    rows = $rowArray
    reviewOnly = $true
    productionRoutingEnabled = $false
}
if ($Preflight) {
    $result | ConvertTo-Json -Depth 8
    return
}
Assert-True (-not (Test-Path -LiteralPath $outputPath)) 'O2D23 route gate output already exists.'
[IO.File]::WriteAllText($outputPath, (($result | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result | ConvertTo-Json -Depth 8
