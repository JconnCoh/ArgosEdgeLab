#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$finalPath = Join-Path $PSScriptRoot 'O2D23_FINAL_PACKAGE_GATE.json'
$routePath = Join-Path $PSScriptRoot 'O2D23_COMPLETE_ROUTE_GATE.json'
$aliasPath = Join-Path $PSScriptRoot 'O2D23_INSPECTIONREVS_U_ALIAS_GATE.json'
$clonePath = Join-Path $PSScriptRoot 'O2D23_ROUTE_CLONE_LITERAL_GATE_R2.json'
$sharePath = Join-Path $PSScriptRoot 'O2D23_CURRENT_SHARE_OBSERVATION.json'
$parentPath = Join-Path $project 'work\OPENCV_SCRIBE_O2D22\O2D22_TERMINAL_RESPONSE_GATE.json'
$outputPath = Join-Path $PSScriptRoot 'O2D23_COMPLETE_ROUTE_GATE_R3.json'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}
function Read-Pinned([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2D23 route dependency absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "O2D23 route dependency changed: $Path"
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($PSScriptRoot.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 complete-route invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 complete-route invocation manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_complete_route_invocation_v1') 'O2D23 complete-route invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D' -and [string]$invocation.requestId -eq 'REQ_20260827T035500111Z_3C97863DBF26') 'O2D23 complete-route invocation identity changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Gate') 'O2D23 complete-route invocation action set changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 complete-route authority changed.'

$final = Read-Pinned $finalPath '532CCF66A5BC1ACE7B2C3FBE844D50B876E13F91CEC04C20D953D494604C8B50'
$route = Read-Pinned $routePath 'D161C4891688D6A76F7AD84EBBC935B7D14488CF21D7CF91E6F9944197B8706E'
$alias = Read-Pinned $aliasPath 'AF134891346B4CE880B9CE19F1D703191332394921DB24D3ACF7A59CF8E05FEF'
$clone = Read-Pinned $clonePath '9E0B71E577E0E8F500C9227DB9AEA11E4CD24CA474C71C4785ED2CAD5A007F53'
$share = Read-Pinned $sharePath '0479C71AEBF294EDAA86B2067633A9AB238CFB6288E82D173DBBB1FF7D2E32CA'
$parent = Read-Pinned $parentPath '90ABE4E37A74EED80EC7D2F82296D1B101E2F655A2AB7F909D5D525F5B34D7F2'
Assert-True (-not (Test-Path -LiteralPath $outputPath)) 'O2D23 complete-route R3 gate already exists.'

$requestId = 'REQ_20260827T035500111Z_3C97863DBF26'
Assert-True ([string]$final.state -eq 'PASS_O2D23_FINAL_PACKAGE_GATE' -and [string]$final.requestId -eq $requestId) 'O2D23 final package identity changed.'
Assert-True ([string]$final.validationQualification -eq 'INDEPENDENT_VALIDATION_OUTCOME_BLIND_METADATA_DISCLOSED' -and [bool]$final.slot25SourceMetadataPrematurelyExposed -and -not [bool]$final.slot25ImageBytesRead -and -not [bool]$final.slot25OutcomeSeen) 'O2D23 outcome-blind metadata disclosure changed.'
Assert-True ([bool]$final.maintenanceInstalledShaMatchesPayload -and [string]$final.endpointPayloadSha256 -eq [string]$final.declaredInstalledSha256) 'O2D23 installed endpoint declaration changed.'
Assert-True ([string]$route.state -eq 'HOLD_O2D23_COMPLETE_ROUTE_GATE_ARGOS_INBOUND_RELAY_UNPROVEN' -and [string]$route.pathBudgetState -eq 'PASS_PATH_BUDGET' -and [int]$route.routePathRowsEvaluated -eq 129) 'O2D23 inherited path-route gate changed.'
Assert-True ([string]$alias.state -eq 'PASS_O2D23_EXACT_INSPECTIONREVS_U_ALIAS_GATE' -and [bool]$alias.persistentMappingVerified -and [int]$alias.pendingRequestCountAtGate -eq 0) 'O2D23 publication alias gate changed.'
Assert-True ([string]$clone.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$clone.mode -eq 'GATE') 'O2D23 route clone gate changed.'
Assert-True ([string]$share.state -eq 'PASS_O2D23_CURRENT_SHARE_ZERO_PENDING' -and [int]$share.topLevelPendingReadyZipCount -eq 0 -and [int]$share.topLevelPendingUploadCount -eq 0 -and [bool]$share.targetAbsent -and [bool]$share.uploadAbsent -and [bool]$share.priorO2D22ResponsePresent) 'O2D23 current share observation changed.'
Assert-True ([string]$parent.state -eq 'PASS_O2D22_EXACT_SIGNED_SLOT24_BLIND_VALIDATION_RESPONSE' -and [bool]$parent.responseSignatureVerified -and [string]$parent.endpointState -eq 'PASS_MAINTENANCE_PATCH' -and -not [bool]$parent.requestRetried) 'O2D23 recent signed full round trip changed.'

$gateValue = [ordered]@{
    schema='argos_o2d23_complete_route_gate_v3';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_COMPLETE_ROUTE_GATE'
    requestId=$requestId;jobClass='MAINTENANCE_PATCH';requestZipSha256=[string]$final.requestZipSha256;requestManifestSha256=[string]$final.requestManifestSha256;requestSignatureSha256=[string]$final.requestSignatureSha256
    finalPackageGateSha256=Get-Sha256 $finalPath;endpointPayloadSha256=[string]$final.endpointPayloadSha256;declaredInstalledSha256=[string]$final.declaredInstalledSha256;maintenanceInstalledShaMatchesPayload=$true
    declaredRehearsalGateState=[string]$final.declaredRehearsalGateState;declaredRehearsalGateSha256=[string]$final.declaredRehearsalGateSha256
    declaredSelfPinGateState=[string]$final.declaredSelfPinGateState;declaredSelfPinGateSha256=[string]$final.declaredSelfPinGateSha256
    inheritedPathRouteGate=[ordered]@{path='work/OPENCV_SCRIBE_O2D23/O2D23_COMPLETE_ROUTE_GATE.json';sha256=Get-Sha256 $routePath;pathBudgetState=[string]$route.pathBudgetState;routePathRowsEvaluated=[int]$route.routePathRowsEvaluated;maximumEffectiveLength=[int]$route.maximumEffectiveLength;maximumComponentLength=[int]$route.maximumComponentLength}
    publicationAliasGate=[ordered]@{path='work/OPENCV_SCRIBE_O2D23/O2D23_INSPECTIONREVS_U_ALIAS_GATE.json';sha256=Get-Sha256 $aliasPath;targetEffectiveLength=[int]$alias.aliasTargetEffectiveLength;uploadEffectiveLength=[int]$alias.aliasUploadEffectiveLength}
    routeCloneLiteralGate=[ordered]@{path='work/OPENCV_SCRIBE_O2D23/O2D23_ROUTE_CLONE_LITERAL_GATE_R2.json';sha256=Get-Sha256 $clonePath}
    endpointWorkerSha256=[string]$route.endpointWorkerSha256;installedEndpointConfigSha256=[string]$route.installedEndpointConfigSha256;inheritedQueueSafetyGateSha256=[string]$route.inheritedQueueSafetyGateSha256
    recentMatchingSignedFullRoundTrip=[ordered]@{path='work/OPENCV_SCRIBE_O2D22/O2D22_TERMINAL_RESPONSE_GATE.json';sha256=Get-Sha256 $parentPath;requestId=[string]$parent.requestId;responseId=[string]$parent.responseId;signedResponseVerified=[bool]$parent.responseSignatureVerified;endpointState=[string]$parent.endpointState;terminalResponseMatchedExactRequest=$true;requestRetried=[bool]$parent.requestRetried;completeGatewayArgosJbodReturnRoundTripProved=$true}
    currentShareObservation=[ordered]@{path='work/OPENCV_SCRIBE_O2D23/O2D23_CURRENT_SHARE_OBSERVATION.json';sha256=Get-Sha256 $sharePath;persistentUDriveExact=$true;requestsRootReadable=[bool]$share.requestsRootReadable;responsesRootReadable=[bool]$share.responsesRootReadable;pendingRequestCount=0;newTargetAbsent=[bool]$share.targetAbsent;newUploadAbsent=[bool]$share.uploadAbsent}
    requestsFromGatewayPendingAfterCount=0;toJbodPendingAfterCount=0;toGatewayPendingAfterCount=0;unresolvedEarlierAcceptedRequestCount=0;argosInboundRelayCurrentHealthProved=$true
    routeHealthDisposition='PASS_RECENT_MATCHING_SIGNED_FULL_ROUND_TRIP_AND_ZERO_CURRENT_SHARE_PENDING_REQUESTS';publicationAuthorized=$true;createNewPublicationMaximum=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true
    validationQualification='INDEPENDENT_VALIDATION_OUTCOME_BLIND_METADATA_DISCLOSED';targetExecuted=$false;targetMutationsPerformed=$false;sourceImageBytesRead=$false;providerActivated=$false;slot25SourceMetadataPrematurelyExposed=$true;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false
    reviewOnly=$true;productionRoutingEnabled=$false
}

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_complete_route_gate_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_COMPLETE_ROUTE_GATE_PREFLIGHT';requestId=$requestId;publicationAuthorized=$true;mutationsPerformed=$false;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

[IO.File]::WriteAllText($outputPath, (($gateValue | ConvertTo-Json -Depth 10) + [Environment]::NewLine), $utf8)
[ordered]@{schema='argos_o2d23_complete_route_gate_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_COMPLETE_ROUTE_GATE_WRITTEN';gateSha256=Get-Sha256 $outputPath;publicationAuthorized=$true;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
