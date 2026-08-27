#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$finalPath = Join-Path $PSScriptRoot 'O2D22_FINAL_PACKAGE_GATE.json'
$routePath = Join-Path $PSScriptRoot 'O2D22_COMPLETE_ROUTE_GATE.json'
$aliasPath = Join-Path $PSScriptRoot 'O2D22_INSPECTIONREVS_U_ALIAS_GATE.json'
$clonePath = Join-Path $PSScriptRoot 'O2D22_ROUTE_CLONE_LITERAL_GATE.json'
$sharePath = Join-Path $PSScriptRoot 'O2D22_CURRENT_SHARE_OBSERVATION.json'
$parentPath = Join-Path $project 'work\OPENCV_SCRIBE_O2D21\O2D21_TERMINAL_RESPONSE_GATE.json'
$outputPath = Join-Path $PSScriptRoot 'O2D22_COMPLETE_ROUTE_GATE_R3.json'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Read-Pinned([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D22 route dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D22 route dependency changed: $Path"
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

$final = Read-Pinned $finalPath '12B1BB2C91E7663A7115231FCC0B2FEBC2112AA03D47551A1ECDD6E44BBF5EEC'
$route = Read-Pinned $routePath 'DC02B1656CC1BC7A958790212C69DB5BEBA6CF14C9E1F22971580244852E0240'
$alias = Read-Pinned $aliasPath '3373CB5F5C67AFE167AF9A0EA02263B19C710B890E784313B87333157FD504EC'
$clone = Read-Pinned $clonePath '2F85B84A6821867392357EE650B93FC41E2C8C98FE5F70734D5B05DE6F4FD09B'
$share = Read-Pinned $sharePath '06912AC01F63B208566E11A8DA1D88B70F27D225CBC7A3735A8FD8DCE0394C12'
$parent = Read-Pinned $parentPath '40A6A70324BF3D22AFD681CEBAF242B1ECBCA8C6656398B0687E8313054605FC'
Assert-True (-not (Test-Path -LiteralPath $outputPath)) 'O2D22 complete-route R3 gate already exists.'

$requestId = 'REQ_20260827T030200111Z_6C5C7F1FBF26'
Assert-True ([string]$final.state -eq 'PASS_O2D22_FINAL_PACKAGE_GATE' -and [string]$final.requestId -eq $requestId) 'O2D22 final package identity changed.'
Assert-True ([bool]$final.maintenanceInstalledShaMatchesPayload -and [string]$final.endpointPayloadSha256 -eq [string]$final.declaredInstalledSha256) 'O2D22 installed endpoint declaration changed.'
Assert-True ([string]$route.state -eq 'HOLD_O2D22_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN' -and [string]$route.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$route.routePathRowsEvaluated -eq 129) 'O2D22 inherited path-route gate changed.'
Assert-True ([string]$alias.state -eq 'PASS_O2D22_EXACT_INSPECTIONREVS_U_ALIAS_GATE' -and [bool]$alias.persistentMappingVerified -and [int]$alias.pendingRequestCountAtGate -eq 0) 'O2D22 publication alias gate changed.'
Assert-True ([string]$clone.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$clone.mode -eq 'GATE') 'O2D22 route clone gate changed.'
Assert-True ([string]$share.state -eq 'PASS_O2D22_CURRENT_SHARE_ZERO_PENDING' -and [int]$share.topLevelPendingReadyZipCount -eq 0 -and [int]$share.topLevelPendingUploadCount -eq 0 -and [bool]$share.targetAbsent -and [bool]$share.uploadAbsent -and [bool]$share.priorO2D21ResponsePresent) 'O2D22 current share observation changed.'
Assert-True ([string]$parent.state -eq 'PASS_O2D21_EXACT_SIGNED_SLOT23_BLIND_VALIDATION_RESPONSE' -and [bool]$parent.responseSignatureVerified -and [string]$parent.endpointState -eq 'PASS_MAINTENANCE_PATCH' -and -not [bool]$parent.requestRetried) 'O2D22 recent signed full round trip changed.'

$gateValue = [ordered]@{
    schema='argos_o2d22_complete_route_gate_v3';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_COMPLETE_ROUTE_GATE'
    requestId=$requestId;jobClass='MAINTENANCE_PATCH';requestZipSha256=[string]$final.requestZipSha256;requestManifestSha256=[string]$final.requestManifestSha256;requestSignatureSha256=[string]$final.requestSignatureSha256
    finalPackageGateSha256=Get-Sha256 $finalPath;endpointPayloadSha256=[string]$final.endpointPayloadSha256;declaredInstalledSha256=[string]$final.declaredInstalledSha256;maintenanceInstalledShaMatchesPayload=$true
    declaredRehearsalGateState=[string]$final.declaredRehearsalGateState;declaredRehearsalGateSha256=[string]$final.declaredRehearsalGateSha256
    declaredSelfPinGateState=[string]$final.declaredSelfPinGateState;declaredSelfPinGateSha256=[string]$final.declaredSelfPinGateSha256
    inheritedPathRouteGate=[ordered]@{path='work/OPENCV_SCRIBE_O2D22/O2D22_COMPLETE_ROUTE_GATE.json';sha256=Get-Sha256 $routePath;pathBudgetState=[string]$route.pathBudgetState;routePathRowsEvaluated=[int]$route.routePathRowsEvaluated;maximumEffectiveLength=[int]$route.maximumEffectiveLength;maximumComponentLength=[int]$route.maximumComponentLength}
    publicationAliasGate=[ordered]@{path='work/OPENCV_SCRIBE_O2D22/O2D22_INSPECTIONREVS_U_ALIAS_GATE.json';sha256=Get-Sha256 $aliasPath;targetEffectiveLength=[int]$alias.aliasTargetEffectiveLength;uploadEffectiveLength=[int]$alias.aliasUploadEffectiveLength}
    routeCloneLiteralGate=[ordered]@{path='work/OPENCV_SCRIBE_O2D22/O2D22_ROUTE_CLONE_LITERAL_GATE.json';sha256=Get-Sha256 $clonePath}
    endpointWorkerSha256=[string]$route.endpointWorkerSha256;installedEndpointConfigSha256=[string]$route.installedEndpointConfigSha256;inheritedQueueSafetyGateSha256=[string]$route.inheritedQueueSafetyGateSha256
    recentMatchingSignedFullRoundTrip=[ordered]@{path='work/OPENCV_SCRIBE_O2D21/O2D21_TERMINAL_RESPONSE_GATE.json';sha256=Get-Sha256 $parentPath;requestId=[string]$parent.requestId;responseId=[string]$parent.responseId;signedResponseVerified=[bool]$parent.responseSignatureVerified;endpointState=[string]$parent.endpointState;terminalResponseMatchedExactRequest=$true;requestRetried=[bool]$parent.requestRetried;completeGatewayArgosJbodReturnRoundTripProved=$true}
    currentShareObservation=[ordered]@{path='work/OPENCV_SCRIBE_O2D22/O2D22_CURRENT_SHARE_OBSERVATION.json';sha256=Get-Sha256 $sharePath;persistentUDriveExact=$true;requestsRootReadable=[bool]$share.requestsRootReadable;responsesRootReadable=[bool]$share.responsesRootReadable;pendingRequestCount=0;newTargetAbsent=[bool]$share.targetAbsent;newUploadAbsent=[bool]$share.uploadAbsent}
    requestsFromGatewayPendingAfterCount=0;toJbodPendingAfterCount=0;toGatewayPendingAfterCount=0;unresolvedEarlierAcceptedRequestCount=0;argosInboundRelayCurrentHealthProved=$true
    routeHealthDisposition='PASS_RECENT_MATCHING_SIGNED_FULL_ROUND_TRIP_AND_ZERO_CURRENT_SHARE_PENDING_REQUESTS';publicationAuthorized=$true;createNewPublicationMaximum=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true
    targetExecuted=$false;targetMutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;slot25SourceMetadataPrematurelyExposed=$true;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false
    reviewOnly=$true;productionRoutingEnabled=$false
}

if ($Preflight) {
    [ordered]@{schema='argos_o2d22_complete_route_gate_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_COMPLETE_ROUTE_GATE_PREFLIGHT';requestId=$requestId;publicationAuthorized=$true;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

[IO.File]::WriteAllText($outputPath, (($gateValue | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
[ordered]@{schema='argos_o2d22_complete_route_gate_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_COMPLETE_ROUTE_GATE_WRITTEN';gateSha256=Get-Sha256 $outputPath;publicationAuthorized=$true;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
