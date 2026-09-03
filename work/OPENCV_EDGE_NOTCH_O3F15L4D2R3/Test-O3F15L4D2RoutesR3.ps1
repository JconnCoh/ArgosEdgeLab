#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash.ToUpperInvariant()
}

function Get-RequiredProperty([object]$Value, [string]$Name) {
    $property = $Value.PSObject.Properties[$Name]
    if ($null -eq $property) { throw "D2 route invocation is missing $Name." }
    $property.Value
}

function Resolve-RepositoryFile([string]$ProjectRoot, [string]$RelativePath) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'D2 route dependency path is empty.'
    Assert-True (-not [IO.Path]::IsPathRooted($RelativePath)) "D2 route dependency must be repository-relative: $RelativePath"
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
    $resolved = [IO.Path]::GetFullPath((Join-Path $root $RelativePath.Replace('/', '\')))
    Assert-True ($resolved.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) "D2 route dependency escapes the repository: $RelativePath"
    $resolved
}

function Assert-PinnedFile([string]$Path, [string]$ExpectedSha256, [string]$Label) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "D2 route $Label is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -ceq $ExpectedSha256) "D2 route $Label hash changed."
}

function Add-RoutePath([Collections.Generic.List[object]]$Items, [string]$Stage, [string]$Path) {
    $Items.Add([pscustomobject]@{ stage = $Stage; path = $Path })
}

function Add-ExpandedLeaves(
    [Collections.Generic.List[object]]$Items,
    [string]$Stage,
    [string]$Root,
    [string[]]$Leaves
) {
    foreach ($leaf in $Leaves) { Add-RoutePath $Items $Stage (Join-Path $Root $leaf.Replace('/', '\')) }
}

function Write-NewUtf8Json([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "D2 route gate already exists: $Path"
    $json = ($Value | ConvertTo-Json -Depth 32) + [Environment]::NewLine
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

Assert-True ($Preflight -xor $Gate) 'Specify exactly one of -Preflight or -Gate.'
Assert-True ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'D2 route gate requires Windows PowerShell 5.1.'

$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocation = Join-Path $PSScriptRoot 'O3F15L4D2_ROUTE_GATE_R3_INVOCATION.json'
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocation, [StringComparison]::OrdinalIgnoreCase)) 'D2 route invocation path changed.'
Assert-True (Test-Path -LiteralPath $invocationPath -PathType Leaf) 'D2 route invocation is absent.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string](Get-RequiredProperty $invocation 'schema') -ceq 'argos_ocv03_o3f15l4d2_route_gate_r3_invocation_v1') 'D2 R3 route invocation schema changed.'
Assert-True ([string](Get-RequiredProperty $invocation 'state') -ceq 'FROZEN_O3F15L4D2_ROUTE_GATE_R3_INVOCATION') 'D2 R3 route invocation is not frozen.'
Assert-True ([string](Get-RequiredProperty $invocation 'revision') -ceq 'O3F15L4D2') 'D2 route invocation revision changed.'
Assert-True ([string](Get-RequiredProperty $invocation 'routeScriptSha256') -ceq (Get-Sha256 $PSCommandPath)) 'D2 route script is not the frozen invocation byte set.'

$contractPath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'contractPath'))
$signGatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'signGatePath'))
$queueGatePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'queueSafetyGatePath'))
$routeInventoryPath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'routeCapabilityInventoryPath'))
$configEvidencePath = Resolve-RepositoryFile $projectRoot ([string](Get-RequiredProperty $invocation 'installedRouteConfigEvidencePath'))
$pathTool = Join-Path $projectRoot 'utilities\Confirm-ArgosPathBudget.ps1'
Assert-PinnedFile $contractPath ([string](Get-RequiredProperty $invocation 'contractSha256')) 'contract'
Assert-PinnedFile $signGatePath ([string](Get-RequiredProperty $invocation 'signGateSha256')) 'sign gate'
Assert-PinnedFile $queueGatePath '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' 'queue-safety gate'
Assert-PinnedFile $routeInventoryPath ([string](Get-RequiredProperty $invocation 'routeCapabilityInventorySha256')) 'route capability inventory'
Assert-PinnedFile $configEvidencePath '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB' 'installed route configuration evidence'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'D2 path-budget utility is absent.'

$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$signGate = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
$queueGate = Get-Content -LiteralPath $queueGatePath -Raw | ConvertFrom-Json
$routeInventory = Get-Content -LiteralPath $routeInventoryPath -Raw | ConvertFrom-Json
Assert-True ([string]$contract.schema -ceq 'argos_ocv03_o3f15l4d2_diagnostic_contract_v1' -and [string]$contract.lifecycle -ceq 'FROZEN' -and [string]$contract.revision -ceq 'O3F15L4D2') 'D2 frozen diagnostic contract changed.'
Assert-True ([string]$signGate.state -ceq [string](Get-RequiredProperty $invocation 'expectedSignGateState')) 'D2 sign-gate state changed.'
Assert-True ([string]$queueGate.state -ceq 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL' -and [int]$queueGate.checkCount -eq 16 -and @($queueGate.checks | Where-Object { [string]$_.state -cne 'PASS' }).Count -eq 0) 'D2 inherited queue-safety gate changed.'
$requiredQueueChecks = @(
    'PATH_BOUNDARIES_199_200_229_230',
    'STALE_WORK_COLLISION_AND_SECOND_QUEUE_ITEM',
    'INJECTED_RESPONSE_FAILURE_COMPACT_AND_QUEUE_ADVANCE',
    'FORCED_TERMINATION_AND_RESTART',
    'REQUEST_REPLAY_NO_DUPLICATE_RESPONSE',
    'UNAPPROVED_PREDECESSOR_REFUSED_BEFORE_MUTATION'
)
foreach ($name in $requiredQueueChecks) {
    Assert-True (@($queueGate.checks | Where-Object { [string]$_.name -ceq $name -and [string]$_.state -ceq 'PASS' }).Count -eq 1) "D2 inherited queue-safety check is absent: $name"
}
Assert-True ([string]$routeInventory.state -ceq 'PASS_O3F15L4D2_WORKER_HASH_BOUND_ROUTE_CAPABILITY_INVENTORY') 'D2 route capability inventory changed.'
Assert-True ([string]$contract.routePins.endpointWorkerSha256 -ceq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250') 'D2 endpoint-worker pin changed.'
Assert-True ([string]$contract.routePins.installedRouteConfigEvidenceSha256 -ceq (Get-Sha256 $configEvidencePath)) 'D2 installed-route pin changed.'
Assert-True ([string]$contract.routePins.queueSafetyGateSha256 -ceq (Get-Sha256 $queueGatePath)) 'D2 queue-safety pin changed.'
Assert-True ([int64]$contract.response.maximumConstructedResponseBytes -eq 8388608 -and [int64]$contract.response.maximumEmittedJsonBytes -eq 7340032) 'D2 response byte contract changed.'
Assert-True ([int]$contract.classification.pairCount -eq 978 -and [int]$contract.classification.sourceLeafCount -eq 1956 -and [int]$contract.classification.pathSuffixReserve -eq 32) 'D2 classification/path contract changed.'

$requestId = [string](Get-RequiredProperty $invocation 'requestId')
Assert-True ($requestId -cmatch '^REQ_[0-9]{8}T[0-9]{9}Z_[0-9A-F]{12}$') 'D2 request ID shape changed.'
Assert-True ([string]$signGate.requestId -ceq $requestId) 'D2 sign gate belongs to another request.'
$signedPackageRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'signedPackageRoot'))
$signedPackageZip = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'signedPackageZipPath'))
$localCollectionRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'localCollectionRoot'))
$gateOutputPath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'gateOutputPath'))
$publishGatePath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'publishGatePath'))
$publicationAttemptPath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'publicationAttemptPath'))
$collectionGatePath = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'collectionGatePath'))
Assert-True ($gateOutputPath.Equals((Join-Path $projectRoot 'work\OPENCV_EDGE_NOTCH_O3F15L4D2\final_o3f15l4d2\O3F15L4D2_PREPUBLICATION_PATH_R3_GATE.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 R3 route gate output is not beside the final ZIP.'
Assert-True ($publishGatePath.Equals((Join-Path $projectRoot 'work\OPENCV_EDGE_NOTCH_O3F15L4D2\O3F15L4D2_PUBLISH_GATE.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 publication gate path changed.'
Assert-True ($publicationAttemptPath.Equals((Join-Path $projectRoot 'work\OPENCV_EDGE_NOTCH_O3F15L4D2\O3F15L4D2_PUBLISH_ATTEMPT.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 publication-attempt receipt path changed.'
Assert-True ($collectionGatePath.Equals((Join-Path $projectRoot 'work\OPENCV_EDGE_NOTCH_O3F15L4D2\O3F15L4D2_RESPONSE_COLLECTION_GATE.json'), [StringComparison]::OrdinalIgnoreCase)) 'D2 collection gate path changed.'
Assert-True ($localCollectionRoot -ceq 'C:\O3F15D2C') 'D2 response collection root is not the frozen short root.'
Assert-PinnedFile $signedPackageZip ([string](Get-RequiredProperty $invocation 'signedPackageZipSha256')) 'signed request ZIP'
Assert-True ((Get-Item -LiteralPath $signedPackageZip).Length -eq [int64](Get-RequiredProperty $invocation 'signedPackageZipBytes')) 'D2 signed request ZIP byte count changed.'
Assert-True ([IO.Path]::GetFullPath([string]$signGate.packageZipPath).Equals($signedPackageZip, [StringComparison]::OrdinalIgnoreCase) -and [string]$signGate.packageZipSha256 -ceq (Get-Sha256 $signedPackageZip)) 'D2 sign gate no longer pins the final ZIP.'

$manifestPath = Join-Path $signedPackageRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $signedPackageRoot 'PORTAL_REQUEST_MANIFEST.sig'
Assert-PinnedFile $manifestPath ([string](Get-RequiredProperty $invocation 'requestManifestSha256')) 'request manifest'
Assert-True (Test-Path -LiteralPath $signaturePath -PathType Leaf) 'D2 request signature is absent.'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$manifest.schema -ceq 'argos_project_portal_request_manifest_v1' -and [string]$manifest.requestId -ceq $requestId -and [string]$manifest.targetRole -ceq 'JBOD' -and [string]$manifest.jobClass -ceq 'MAINTENANCE_PATCH') 'D2 signed request identity changed.'
Assert-True ([bool]$manifest.reviewOnly -and -not [bool]$manifest.trainingEligible -and -not [bool]$manifest.xmlEligible -and -not [bool]$manifest.productionEligible -and -not [bool]$manifest.productionRoutingEnabled -and -not [bool]$manifest.credentialsIncluded) 'D2 signed request authority widened.'
Assert-True ([int64]$manifest.maxResultBytes -eq 8388608 -and [string]$manifest.entryPoint -ceq 'payload/Invoke-O3F15L4D2.ps1' -and -not [bool]$manifest.requestRetryAuthorized) 'D2 request execution/result contract changed.'
$manifestFiles = @($manifest.files)
Assert-True ($manifestFiles.Count -eq (@($contract.payloadFiles).Count + 1)) 'D2 signed payload cardinality changed.'
Assert-True (@($manifestFiles | Where-Object { [string]$_.path -ceq 'payload/O3F15L4D2_DIAGNOSTIC_CONTRACT.json' }).Count -eq 1) 'D2 signed payload lacks its frozen contract.'
$manifestLeaves = @('PORTAL_REQUEST_MANIFEST.json', 'PORTAL_REQUEST_MANIFEST.sig') + @($manifestFiles | ForEach-Object { [string]$_.path })
Assert-True ($manifestLeaves.Count -eq @($manifestLeaves | Sort-Object -Unique).Count) 'D2 signed request contains duplicate paths.'

$responseToken = [string](Get-RequiredProperty $invocation 'maximumResponseIdToken')
Assert-True ($responseToken -cmatch '^R_[0-9A-F]{12}_[0-9]{17}_[0-9a-f]{8}$') 'D2 maximum response token shape changed.'
$requestReadyName = $requestId + '.ready'
$requestZipName = $requestReadyName + '.zip'
$responseReadyName = $responseToken + '.ready'
$responseZipName = $responseReadyName + '.zip'
$signedPartialRoot = [IO.Path]::GetFullPath([string](Get-RequiredProperty $invocation 'signedPackagePartialRoot'))
$responseLeaves = @('MAINTENANCE.stdout.txt', 'MAINTENANCE.stderr.txt', 'RESULT.json', 'FAILURE.json', 'PORTAL_RESPONSE_MANIFEST.json', 'PORTAL_RESPONSE_MANIFEST.sig')
$items = New-Object Collections.Generic.List[object]

Add-RoutePath $items 'laptop_final_zip' $signedPackageZip
Add-RoutePath $items 'laptop_prepublication_gate' $gateOutputPath
Add-RoutePath $items 'laptop_publication_gate' $publishGatePath
Add-RoutePath $items 'laptop_publication_attempt_receipt' $publicationAttemptPath
Add-RoutePath $items 'laptop_collection_gate' $collectionGatePath
Add-ExpandedLeaves $items 'laptop_expanded_signing_partial' $signedPartialRoot $manifestLeaves
Add-ExpandedLeaves $items 'laptop_expanded_signing_ready' $signedPackageRoot $manifestLeaves
foreach ($path in @(
    "U:\ProjectPortalRO\requests\$requestZipName.upload",
    "U:\ProjectPortalRO\requests\$requestZipName",
    "C:\APR\S\requests\$requestZipName",
    "C:\APR\S\requests\processed\$requestZipName",
    "C:\ProgramData\ArgosProjectPortalRO\share\staging\$requestZipName",
    "C:\ProgramData\ArgosProjectPortalRO\share\request_archive\$requestZipName"
)) { Add-RoutePath $items 'request_zip_hop' $path }

$requestExpandedRoots = [ordered]@{
    gateway_to_argos_pending = "C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\$requestReadyName"
    gateway_to_argos_sent = "C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\sent\$requestReadyName"
    argos_from_gateway_pending = "C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\$requestReadyName"
    argos_to_jbod_pending = "C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\$requestReadyName"
    argos_to_jbod_sent = "C:\ProgramData\ArgosProjectPortalRO\to_jbod\sent\$requestReadyName"
    jbod_endpoint_pending = "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\$requestReadyName"
    jbod_endpoint_completed = "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\$requestReadyName"
    jbod_endpoint_failed = "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\failed\$requestReadyName"
    jbod_endpoint_replayed = "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\replayed\$requestReadyName"
}
foreach ($property in $requestExpandedRoots.GetEnumerator()) { Add-ExpandedLeaves $items ([string]$property.Key) ([string]$property.Value) $manifestLeaves }

$workToken = 'J_0123456789AB_01234567'
$compactToken = 'C_0123456789AB_01234567'
$maintenanceRoot = "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\maintenance\$requestId"
foreach ($leaf in @('MAINTENANCE.stdout.txt', 'MAINTENANCE.stderr.txt', 'RESULT.json', 'FAILURE.json')) {
    Add-RoutePath $items 'jbod_attempt_work' "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\$workToken\$leaf"
}
Add-RoutePath $items 'jbod_compact_failure' "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\compact\$compactToken\FAILURE.json"
Add-RoutePath $items 'jbod_terminal_ledger' "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger\$requestId.json"
Add-RoutePath $items 'jbod_ledger_quarantine' 'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\ledger_quarantine\L_0123456789AB_20260903T235959999Z_01234567.json'
Add-RoutePath $items 'jbod_maintenance_prior' (Join-Path $maintenanceRoot 'prior\M000_0123456789_0123456789.prior')
Add-RoutePath $items 'jbod_maintenance_failed_current' (Join-Path $maintenanceRoot 'failed_new\M000_0123456789_0123456789.rollback')
Add-RoutePath $items 'jbod_maintenance_failed_created' (Join-Path $maintenanceRoot 'failed_new\M000_0123456789_0123456789.created')
Add-RoutePath $items 'jbod_carrier_stage' 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.stage'
Add-RoutePath $items 'jbod_carrier_restore' 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\.M000_0123456789_0123456789.restore'
Add-RoutePath $items 'jbod_same_bytes_carrier' 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_NotchReviewOpenCvV1.py'

$responseExpandedRoots = [ordered]@{
    jbod_response_quarantine = "C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\response_quarantine\$responseReadyName.partial"
    jbod_response_outbox_partial = "C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\$responseReadyName.partial"
    jbod_response_outbox_ready = "C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\$responseReadyName"
    jbod_response_sender_sent = "C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\$responseReadyName"
    argos_from_jbod_pending = "C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\$responseReadyName"
    argos_to_gateway_pending = "C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\$responseReadyName"
    argos_to_gateway_sent = "C:\ProgramData\ArgosProjectPortalRO\to_gateway\sent\$responseReadyName"
    gateway_response_pending = "C:\APR\R\pending\$responseReadyName"
    gateway_response_archive = "C:\APR\A\$responseReadyName"
    laptop_extract_partial = (Join-Path $localCollectionRoot ($responseToken + '.partial'))
    laptop_extract_ready = (Join-Path $localCollectionRoot ($responseToken + '.ready'))
}
foreach ($property in $responseExpandedRoots.GetEnumerator()) { Add-ExpandedLeaves $items ([string]$property.Key) ([string]$property.Value) $responseLeaves }
foreach ($path in @(
    "C:\ProgramData\ArgosProjectPortalRO\share\response_zip_archive\$responseZipName",
    "U:\ProjectPortalRO\responses\$responseZipName",
    (Join-Path $localCollectionRoot $responseZipName)
)) { Add-RoutePath $items 'response_zip_hop' $path }

foreach ($target in @($contract.targetPins)) { Add-RoutePath $items ('pinned_target_' + [string]$target.label) ([string]$target.path) }
$distinctItems = @($items.ToArray() | Sort-Object stage, path -Unique)
$candidatePaths = @($distinctItems | ForEach-Object { [string]$_.path } | Sort-Object -Unique)
$pathResult = & $pathTool -CandidatePath $candidatePaths -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathResult.state -ceq 'PASS_PATH_BUDGET') 'D2 complete round-trip path budget failed.'
Assert-True (@($pathResult.candidates).Count -eq $candidatePaths.Count) 'D2 path utility did not return every constructed route path.'
$measurements = @{}
foreach ($row in @($pathResult.candidates)) { $measurements[[string]$row.path] = $row }
$routeRows = foreach ($item in $distinctItems) {
    $measurement = $measurements[[string]$item.path]
    Assert-True ($null -ne $measurement) "D2 route measurement is absent: $($item.path)"
    [pscustomobject][ordered]@{
        stage = [string]$item.stage
        path = [string]$item.path
        rawLength = [int]$measurement.pathLength
        effectiveLength = [int]$measurement.effectiveLength
        maximumComponentLength = [int]$measurement.longestComponentLength
        disposition = [string]$measurement.disposition
    }
}
$longest = @($routeRows | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$longestResult = @($routeRows | Where-Object { $_.stage -match 'response|attempt|compact|extract|collection' } | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
Assert-True ([int]$longest.effectiveLength -lt 200 -and [int]$longest.maximumComponentLength -le 80) 'D2 route exceeds the direct-safe output budget.'

$result = [ordered]@{
    schema = 'argos_ocv03_o3f15l4d2_complete_route_path_r3_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    lifecycle = $(if ($Preflight) { 'DRAFT_PREFLIGHT' } else { 'FROZEN_GATE_OUTPUT' })
    state = $(if ($Preflight) { 'PASS_O3F15L4D2_COMPLETE_ROUTE_PATH_R3_PREFLIGHT' } else { 'PASS_O3F15L4D2_COMPLETE_ROUTE_PATH_R3_GATE' })
    revision = 'O3F15L4D2'
    requestId = $requestId
    requestManifestSha256 = Get-Sha256 $manifestPath
    requestSignatureSha256 = Get-Sha256 $signaturePath
    signedPackageZipSha256 = Get-Sha256 $signedPackageZip
    installedRouteConfigRevisionSha256 = Get-Sha256 $configEvidencePath
    endpointWorkerSha256 = [string]$contract.routePins.endpointWorkerSha256
    queueSafetyGateSha256 = Get-Sha256 $queueGatePath
    queueSafetyChecksInherited = $requiredQueueChecks
    suffixReserve = 32
    requestPayloadFileCount = $manifestFiles.Count
    longestRelativeRequestLeaf = [string]@($manifestLeaves | Sort-Object Length -Descending | Select-Object -First 1)[0]
    maximumResponseResultBytes = [int64]$contract.response.maximumConstructedResponseBytes
    maximumResponseEntryBytes = 8388608
    responseLeafSet = $responseLeaves
    evaluatedRouteRootCount = @(@($distinctItems | ForEach-Object { Split-Path -Parent ([string]$_.path) } | Sort-Object -Unique)).Count
    evaluatedPathCount = $routeRows.Count
    maximumEffectiveLength = [int]$longest.effectiveLength
    maximumComponentLength = [int]($routeRows | Measure-Object maximumComponentLength -Maximum).Maximum
    longestPath = [string]$longest.path
    longestResultLeaf = $longestResult
    routePaths = @($routeRows)
    routeRowRuntimeType = $routeRows[0].GetType().FullName
    pathDisposition = 'PASS_ALL_CONSTRUCTED_LEAVES_EFFECTIVE_LT_200_COMPONENT_LE_80'
    publicationCountMaximum = 1
    matchingSignedTerminalResponseRequired = $true
    gatewayAcceptanceIsExecutionEvidence = $false
    requestRetryAuthorized = $false
    rustDeskAllowed = $false
    operatorInputRequired = $false
    sourceImageBytesRead = $false
    sourceMutationOrDeletionAuthorized = $false
    existingTaskOrProcessActionAuthorized = $false
    providerActivationAuthorized = $false
    selectorOrThresholdChangeAuthorized = $false
    automaticHoldClearanceAuthorized = $false
    fullFrontsideHoldCountPreserved = 184
    patternedFrontHoldCountPreserved = 12
    slot02AmbiguityPreserved = $true
    slot16RareHotspotPreserved = $true
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    mutationsPerformed = $false
}

if ($Preflight) {
    $result | ConvertTo-Json -Depth 32
    return
}
Write-NewUtf8Json $gateOutputPath $result
$result | ConvertTo-Json -Depth 32
