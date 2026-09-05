#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18W2'
$branch = 'codex/opencv-scribe-deciphering'
$definitionPath = Join-Path $PSScriptRoot 'R18W2_DATA_PULL_DEFINITION.json'
$scopePath = Join-Path $PSScriptRoot 'R18W2_CROSSWALK_SCOPE.json'
$routePinsPath = Join-Path $PSScriptRoot 'R18W2_ROUTE_PINS.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18W2_LOCAL_PACKAGE_PREPARATION_V2.json'
$cloneManifestPath = Join-Path $PSScriptRoot 'R18W2_CLONE_LITERAL_REMEDIATION.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18W2_CLONE_LITERAL_GATE_V2.json'
$harnessGatePath = Join-Path $PSScriptRoot 'R18W2_HARNESS_GATE_V2.json'
$wrapperGatePath = Join-Path $PSScriptRoot 'R18W2_WRAPPER_APPLICABILITY_GATE_V2.json'
$rosterPath = Join-Path $project 'work\OPENCV_SCRIBE_R18UQ3\R18UQ3_LIVE_INSITEREAD_ROSTER.json'
$reconciliationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18UJ3\R18UJ3_LIVE_RECONCILIATION.json'
$priorOverlayEvidencePath = Join-Path $project 'work\OPENCV_SCRIBE_R18U\R18U_EXISTING_VERIFIED_ROSTER_EVIDENCE.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$stageRoot = 'C:\R18W2B'
$verifyRoot = 'C:\R18W2V'
$responseExtractRoot = 'C:\R18W2R'
$localExtractRoot = 'C:\R18W2'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18W2_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W2_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $finalZip + '.path_gate.json'
$requestedLeaf = 'identity/confirmed/ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json'
$maximumBytes = [int64]16777216
$definitionSha256 = 'A69CD37017378C3D7DD6EAEB08FA9BEDB75B83746BC1EA569ABB31AE9A38C460'
$scopeSha256 = '0A6CF71F00AB4CA895E61A14A55933CD2EB6D86C91388B0CA8DD66CEDA3E6AF3'
$routePinsSha256 = '5C244B674CEF0CBE14899013B8371CD57302549A64F55D72E879C660D58A9BE0'
$preactionSha256 = 'AC0DBE2FBBAB2A649E768382B40E6DF1FB8AC2414DE436AC49845CDA27276362'
$cloneManifestSha256 = 'E5BA596AFC87AF7399919DBC0BFC5ECFC565C34323B647CB1D3024CCD089E9C6'
$rosterSha256 = 'CE108A3726EFDD53651453CB3310E06051D6E53DDD3654A304446D9070C19DAB'
$reconciliationSha256 = '419A6A0172C675F4A8DF42EE5ED152846E690D3A667435A89F91B344AD4A5B64'
$priorOverlayEvidenceSha256 = 'FE554020619F4D3B3B58E440EEB19037561A5DB26B91D6916E30E47BDFC5AC3C'
$r18gRouteSha256 = '5F4E1434B142EED5C85517AEFD11614D0D8380424219BB5B6A9BE219403E2646'
$inheritedRouteSha256 = 'E0EAE7BBECDE766E6E78D86074A098465F3117B737146DDF4FF32D1D4953ED2C'
$queueSafetySha256 = '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'
$capabilityInventorySha256 = '381D3E9C4F17218DF37D8E8CE029853216E9BEA5A2FBDABC6AEB7861A29DC8A2'
$installedWorkerSha256 = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$shareRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$packageMembers = @('PORTAL_REQUEST_MANIFEST.json', 'PORTAL_REQUEST_MANIFEST.sig')

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Get-StringSha256([string]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Value)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') } finally { $sha.Dispose() }
}

function Assert-Pin([string]$Path, [string]$Sha256) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R18W2 dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R18W2 dependency changed: $Path"
}

function Assert-StringArrayExact([object[]]$Actual, [object[]]$Expected, [string]$Message) {
    $a = @($Actual | ForEach-Object { [string]$_ })
    $e = @($Expected | ForEach-Object { [string]$_ })
    Assert-True ($a.Count -eq $e.Count) $Message
    for ($i = 0; $i -lt $e.Count; $i++) { Assert-True ($a[$i] -ceq $e[$i]) $Message }
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

Assert-Pin $definitionPath $definitionSha256
Assert-Pin $scopePath $scopeSha256
Assert-Pin $routePinsPath $routePinsSha256
Assert-Pin $preactionPath $preactionSha256
Assert-Pin $cloneManifestPath $cloneManifestSha256
Assert-Pin $rosterPath $rosterSha256
Assert-Pin $reconciliationPath $reconciliationSha256
Assert-Pin $priorOverlayEvidencePath $priorOverlayEvidenceSha256

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$scope = Get-Content -LiteralPath $scopePath -Raw | ConvertFrom-Json
$routePins = Get-Content -LiteralPath $routePinsPath -Raw | ConvertFrom-Json
$roster = Get-Content -LiteralPath $rosterPath -Raw | ConvertFrom-Json
$reconciliation = Get-Content -LiteralPath $reconciliationPath -Raw | ConvertFrom-Json
$priorOverlayEvidence = Get-Content -LiteralPath $priorOverlayEvidencePath -Raw | ConvertFrom-Json

Assert-True ([string]$scope.state -eq 'PASS_R18W2_EXACT_UNRESOLVED_QWZ_SCOPE_FROZEN') 'R18W2 crosswalk scope state changed.'
$scopeMembers = @($scope.members)
Assert-True ($scopeMembers.Count -eq 14 -and [int]$scope.counts.total -eq 14 -and [int]$scope.counts.Q -eq 6 -and [int]$scope.counts.W -eq 5 -and [int]$scope.counts.Z -eq 3) 'R18W2 Q/W/Z scope cardinality changed.'
Assert-True ([string]$scope.requestedCurrentLeaf -ceq $requestedLeaf) 'R18W2 current overlay leaf changed.'
Assert-StringArrayExact -Actual @($scope.crosswalkContract.joinKey) -Expected @('queryLot','scribe','issuedWaferContainer') -Message 'R18W2 exact join key changed.'
Assert-True (-not [bool]$scope.crosswalkContract.acquisitionKeyInferenceAllowed -and -not [bool]$scope.crosswalkContract.unitSuffixToSlotConversionAllowed -and -not [bool]$scope.crosswalkContract.lotPrefixMatchAllowed) 'R18W2 inference prohibition changed.'
Assert-True ([bool]$scope.crosswalkContract.unmatchedMembersRemainHold -and [bool]$scope.crosswalkContract.multipleExactMatchesRemainHold -and [bool]$scope.crosswalkContract.currentReturnedOverlayRequired) 'R18W2 hold or current-overlay contract changed.'

$resolvedRosterMembers = @($roster.lots | ForEach-Object { @($_.resolvedMembers) })
$lineageKeys = New-Object Collections.Generic.List[string]
foreach ($member in $scopeMembers) {
    $queryLot = [string]$member.queryLot
    $unit = [string]$member.unitContainer
    $scribe = [string]$member.scribe
    $character = [string]$member.character
    Assert-True (@('Q','W','Z') -ccontains $character -and $scribe.Contains($character)) 'R18W2 character/member binding changed.'
    $matches = @($resolvedRosterMembers | Where-Object { [string]$_.queryLot -ceq $queryLot -and [string]$_.unitContainer -ceq $unit -and [string]$_.resolvedScribe -ceq $scribe })
    Assert-True ($matches.Count -eq 1) 'R18W2 scope member does not bind one exact resolved MES roster member.'
    $lineageKey = $queryLot + '|' + $unit + '|' + $scribe
    Assert-True (-not $lineageKeys.Contains($lineageKey)) 'R18W2 scope contains a duplicate MES lineage.'
    $lineageKeys.Add($lineageKey)
    $existingTriples = @($reconciliation.resolvedRosterToAcquisitionRows | Where-Object { [string]$_.queryLot -ceq $queryLot -and [string]$_.issuedWaferContainer -ceq $unit -and [string]$_.scribe -ceq $scribe })
    Assert-True ($existingTriples.Count -eq 0) 'R18W2 scope member already has an exact acquisition triple in the frozen reconciliation.'
}

Assert-True ([string]$priorOverlayEvidence.verifiedMetadataLeaf.canonicalSourcePath -eq 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/identity/confirmed/ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json') 'R18W2 prior exact-leaf path evidence changed.'
Assert-True ([string]$priorOverlayEvidence.verifiedMetadataLeaf.schema -eq 'argos_verified_scribe_mes_metadata_overlay_v1' -and [bool]$priorOverlayEvidence.verifiedMetadataLeaf.localHashMatched) 'R18W2 prior overlay evidence changed.'

$relativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
Assert-StringArrayExact -Actual $relativePaths -Expected @($requestedLeaf) -Message 'R18W2 DATA_PULL leaf changed.'
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R18W2 route changed.'
Assert-True ([int]$definition.parameters.maximumFiles -eq 1 -and [int64]$definition.parameters.maximumBytes -eq $maximumBytes -and [int64]$definition.maxResultBytes -eq $maximumBytes) 'R18W2 bounds changed.'
Assert-True ($relativePaths.Count -eq 1 -and @($relativePaths | Sort-Object -Unique).Count -eq 1) 'R18W2 exact file cardinality changed.'

Assert-True ([string]$routePins.state -eq 'PASS_R18W2_INHERITED_ROUTE_PINS') 'R18W2 route-pin state changed.'
Assert-True ([string]$routePins.requestId -eq $requestId -and [string]$routePins.route.targetRole -eq 'JBOD' -and [string]$routePins.route.jobClass -eq 'DATA_PULL' -and [string]$routePins.route.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R18W2 route pins changed.'
Assert-True ([string]$routePins.route.installedEndpointWorkerSha256 -eq $installedWorkerSha256) 'R18W2 installed worker pin changed.'
Assert-True (-not [bool]$routePins.authority.publicationAuthorized -and [int]$routePins.authority.maximumPublications -eq 0 -and -not [bool]$routePins.authority.retryAuthorized) 'R18W2 publication or retry authority widened.'
Assert-Pin (Join-Path $project ([string]$routePins.route.r18gCompleteRouteGate.path)) $r18gRouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.r15eInheritedRouteGate.path)) $inheritedRouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.c1eQueueSafetyGate.path)) $queueSafetySha256
Assert-Pin (Join-Path $project ([string]$routePins.route.c1eReadOnlyCapabilityInventory.path)) $capabilityInventorySha256
Assert-Pin (Join-Path $project ([string]$routePins.route.workerSource.path)) ([string]$routePins.route.workerSource.sha256)
Assert-Pin (Join-Path $project ([string]$routePins.route.priorExactLeafEvidence.path)) $priorOverlayEvidenceSha256
Assert-Pin $identityPath ([string]$routePins.signing.identitySha256)
Assert-Pin $publicCertificatePath ([string]$routePins.signing.publicCertificateSha256)
Assert-Pin $packageTester ([string]$routePins.signing.packageVerifierSha256)
$r18gRoute = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r18gCompleteRouteGate.path)) -Raw | ConvertFrom-Json
$r15eRoute = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r15eInheritedRouteGate.path)) -Raw | ConvertFrom-Json
$queueSafety = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.c1eQueueSafetyGate.path)) -Raw | ConvertFrom-Json
$capability = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.c1eReadOnlyCapabilityInventory.path)) -Raw | ConvertFrom-Json
Assert-True ([string]$r18gRoute.state -eq 'PASS_R18G_COMPLETE_ROUTE_GATE' -and [string]$r18gRoute.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [string]$r18gRoute.installedEndpointWorkerSha256 -eq $installedWorkerSha256) 'R18W2 inherited R18G route evidence changed.'
Assert-True ([string]$r15eRoute.state -eq 'PASS_R15E_COMPLETE_ROUTE_GATE' -and [string]$queueSafety.state -eq 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL') 'R18W2 inherited route or queue gate changed.'
$dataPullCapability = @($capability.routes | Where-Object { [string]$_.type -eq 'DATA_PULL' })
Assert-True ($dataPullCapability.Count -eq 1 -and @($dataPullCapability[0].capabilities) -contains 'approvedRootExactFiles') 'R18W2 DATA_PULL capability is not pinned.'

$preactionJson = & $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight
$preactionResult = $preactionJson | ConvertFrom-Json
Assert-True ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18W2 preaction gate failed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('refs/remotes/origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'R18W2 requires the dedicated branch to match the recorded origin tip.'

$responseId = 'R_0123456789AB_20260905235959999_a1b2c3d4'
$responseReady = $responseId + '.ready'
$requestReady = $requestId + '.ready'
$plannedPackageMembership = @($packageMembers | Sort-Object)
$plannedPackageMembershipSha256 = Get-StringSha256 (($plannedPackageMembership -join "`n") + "`n")
$routePaths = New-Object Collections.Generic.List[string]
foreach ($member in $packageMembers) {
    $routePaths.Add((Join-Path $stageRoot $member))
    $routePaths.Add((Join-Path $verifyRoot $member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\requests_to_argos\pending\' + $requestReady + '\' + $member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\requests_from_gateway\pending\' + $requestReady + '\' + $member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_jbod\pending\' + $requestReady + '\' + $member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\' + $requestReady + '\' + $member))
    $routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\processed\completed\' + $requestReady + '\' + $member))
}
$routePaths.Add($finalZip)
$routePaths.Add($pathSidecar)
$routePaths.Add($packageGatePath)
$routePaths.Add($routeGatePath)
$routePaths.Add(('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip.upload'))
$routePaths.Add(('U:\ProjectPortalRO\requests\' + $requestId + '.ready.zip'))
$routePaths.Add(('C:\APR\S\requests\processed\' + $requestId + '.ready.zip'))
$routePaths.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip.partial')
$routePaths.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\DATA_PULL_PAYLOAD.zip')
$routePaths.Add('C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\state\work\J_0123456789AB_a1b2c3d4\RESULT.json')
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\PORTAL_RESPONSE_MANIFEST.sig'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\pending\' + $responseId + '.partial\DATA_PULL_PAYLOAD.zip'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_argos\sent\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\from_jbod\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('C:\ProgramData\ArgosProjectPortalRO\to_gateway\pending\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('C:\APR\R\pending\' + $responseReady + '\DATA_PULL_PAYLOAD.zip'))
$routePaths.Add(('C:\APR\A\' + $responseReady + '\PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add(('U:\ProjectPortalRO\responses\' + $responseReady + '.zip'))
$routePaths.Add((Join-Path $responseExtractRoot 'PORTAL_RESPONSE_MANIFEST.json'))
$routePaths.Add((Join-Path $responseExtractRoot 'PORTAL_RESPONSE_MANIFEST.sig'))
$routePaths.Add((Join-Path $responseExtractRoot 'DATA_PULL_PAYLOAD.zip'))
$routePaths.Add(($localExtractRoot + '\data\JBOD_PROCESSOR_REVIEW\' + $requestedLeaf.Replace('/', '\')))
$pathGate = & $pathTool -CandidatePath $routePaths.ToArray() -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R18W2 complete route path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ($maximumEffective -lt 200 -and $maximumComponent -le 80) 'R18W2 route requires a shorter namespace.'

foreach ($path in @($stageRoot, $verifyRoot, $finalPartial, $finalRoot, $packageGatePath, $routeGatePath, $pathSidecar)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "R18W2 fresh output exists: $path"
}
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
Assert-True ($thumbprint -eq [string]$routePins.signing.signerThumbprint) 'R18W2 signer thumbprint changed.'
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ([bool]$certificate.HasPrivateKey) 'R18W2 signer private key is unavailable.'

$selfHash = Get-Sha256 $PSCommandPath
if ($Build) {
    foreach ($gatePath in @($cloneGatePath, $harnessGatePath, $wrapperGatePath)) { Assert-True (Test-Path -LiteralPath $gatePath -PathType Leaf) "R18W2 prerequisite gate is absent: $gatePath" }
    $cloneGate = Get-Content -LiteralPath $cloneGatePath -Raw | ConvertFrom-Json
    $harnessGate = Get-Content -LiteralPath $harnessGatePath -Raw | ConvertFrom-Json
    $wrapperGate = Get-Content -LiteralPath $wrapperGatePath -Raw | ConvertFrom-Json
    Assert-True ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$cloneGate.pairs[0].generatedSha256 -eq $selfHash) 'R18W2 clone-remediation gate is stale.'
    Assert-True ([string]$harnessGate.state -eq 'PASS_R18W2_SOURCE_AND_GENERATED_HARNESS_SAFETY' -and [string]$harnessGate.generatedPowerShellScriptSha256 -eq $selfHash) 'R18W2 harness gate is stale.'
    Assert-True ([string]$wrapperGate.state -eq 'PASS_R18W2_WRAPPER_NOT_APPLICABLE' -and -not [bool]$wrapperGate.cmdWrapperCreated) 'R18W2 wrapper applicability changed.'
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r18w2_build_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18W2_BUILD_PREFLIGHT_LOCAL_ONLY'
        requestId = $requestId
        requestedLeaf = $requestedLeaf
        crosswalkMemberCount = 14
        requestedFileCount = 1
        maximumBytes = $maximumBytes
        plannedPackageMembership = $plannedPackageMembership
        plannedPackageMembershipSha256 = $plannedPackageMembershipSha256
        routePathCount = $routePaths.Count
        maximumEffectiveLength = $maximumEffective
        maximumComponentLength = $maximumComponent
        branch = $branch
        localTip = $localTip
        recordedOriginTip = $remoteTip
        worktreeStatusRowCount = $status.Count
        worktreeCleanRequiredBeforeLocalSigning = $false
        exactDependenciesPinned = $true
        acquisitionKeyInferenceAllowed = $false
        publicationAuthorized = $false
        retryAuthorized = $false
        externalRouteContacted = $false
        imageFilesOpened = $false
        pixelsDecoded = $false
        sourceMutation = $false
        taskProcessOrQueueManagement = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $stageRoot)
$created = [DateTimeOffset]::UtcNow
$manifest = [ordered]@{
    schema = 'argos_project_portal_request_manifest_v1'
    requestId = $requestId
    createdUtc = $created.ToString('o')
    expiresUtc = $created.AddHours(24).ToString('o')
    targetRole = 'JBOD'
    jobClass = 'DATA_PULL'
    handler = ''
    maxResultBytes = $maximumBytes
    reviewOnly = $true
    trainingEligible = $false
    xmlEligible = $false
    productionEligible = $false
    productionRoutingEnabled = $false
    credentialsIncluded = $false
    signerThumbprint = $thumbprint
    signatureAlgorithm = 'RSA-SHA256-PKCS1'
    files = @()
    parameters = $definition.parameters
}
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($manifest | ConvertTo-Json -Depth 24))
[IO.File]::WriteAllBytes((Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.json'), $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes((Join-Path $stageRoot 'PORTAL_REQUEST_MANIFEST.sig'), $signature)
$folderTest = & $packageTester -PackagePath $stageRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18W2 signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial = Join-Path $finalPartial ($requestId + '.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $zipPartial, [IO.Compression.CompressionLevel]::Optimal, $false)
$archive = [IO.Compression.ZipFile]::OpenRead($zipPartial)
try { $actualPackageMembership = @($archive.Entries | ForEach-Object { [string]$_.FullName.Replace('\', '/') } | Sort-Object) } finally { $archive.Dispose() }
Assert-StringArrayExact -Actual $actualPackageMembership -Expected $plannedPackageMembership -Message 'R18W2 final ZIP membership changed.'
$actualPackageMembershipSha256 = Get-StringSha256 (($actualPackageMembership -join "`n") + "`n")
Assert-True ($actualPackageMembershipSha256 -eq $plannedPackageMembershipSha256) 'R18W2 final ZIP membership fingerprint changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial, $verifyRoot)
$extractTest = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and @(Get-ChildItem -LiteralPath $verifyRoot -File).Count -eq 2) 'R18W2 exact ZIP validation failed.'
$zipSha256 = Get-Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
$routeRows = @($pathGate.candidates | ForEach-Object { [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'} })
$scopeRows = @($scopeMembers | ForEach-Object { [ordered]@{character=[string]$_.character;queryLot=[string]$_.queryLot;unitContainer=[string]$_.unitContainer;scribe=[string]$_.scribe} })
$cloneGateSha256 = Get-Sha256 $cloneGatePath
$harnessGateSha256 = Get-Sha256 $harnessGatePath
$wrapperGateSha256 = Get-Sha256 $wrapperGatePath
$packageGate = [ordered]@{
    schema = 'argos_r18w2_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18W2_FINAL_PACKAGE_GATE_SIGNED_UNPUBLISHED'
    requestId = $requestId
    requestZip = 'work/OPENCV_SCRIBE_R18W2/final/REQ_R18W2.ready.zip'
    requestZipBytes = $zipBytes
    requestZipSha256 = $zipSha256
    requestManifestSha256 = $manifestSha256
    requestSignatureSha256 = $signatureSha256
    packageMembership = $actualPackageMembership
    packageMembershipSha256 = $actualPackageMembershipSha256
    definitionSha256 = $definitionSha256
    crosswalkScopeSha256 = $scopeSha256
    mesRosterSha256 = $rosterSha256
    reconciliationSha256 = $reconciliationSha256
    routePinsSha256 = $routePinsSha256
    preactionSha256 = $preactionSha256
    cloneManifestSha256 = $cloneManifestSha256
    cloneGateSha256 = $cloneGateSha256
    harnessGateSha256 = $harnessGateSha256
    wrapperApplicabilityGateSha256 = $wrapperGateSha256
    builderSha256 = $selfHash
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    exactFinalZipMembershipPassed = $true
    requestedLeaf = $requestedLeaf
    requestedFileCount = 1
    maximumFiles = 1
    maximumBytes = $maximumBytes
    crosswalkMemberCount = 14
    acquisitionKeyInferenceAllowed = $false
    publicationAuthorized = $false
    maximumPublications = 0
    retryAuthorized = $false
    externalRouteContacted = $false
    imageFilesOpened = $false
    pixelsDecoded = $false
    sourceMutation = $false
    taskProcessOrQueueManagement = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$routeGate = [ordered]@{
    schema = 'argos_r18w2_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18W2_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED'
    requestId = $requestId
    targetRole = 'JBOD'
    jobClass = 'DATA_PULL'
    approvedRoot = 'JBOD_PROCESSOR_REVIEW'
    requestZipSha256 = $zipSha256
    requestManifestSha256 = $manifestSha256
    requestSignatureSha256 = $signatureSha256
    installedEndpointWorkerSha256 = $installedWorkerSha256
    inheritedR18gRouteGateSha256 = $r18gRouteSha256
    inheritedR15eRouteGateSha256 = $inheritedRouteSha256
    c1eQueueSafetyGateSha256 = $queueSafetySha256
    c1eCapabilityInventorySha256 = $capabilityInventorySha256
    packageMembership = $actualPackageMembership
    packageMembershipSha256 = $actualPackageMembershipSha256
    crosswalkMembers = $scopeRows
    relativePaths = $relativePaths
    maximumFiles = 1
    maximumBytes = $maximumBytes
    maxResultBytes = $maximumBytes
    routePathCount = $routeRows.Count
    routeRows = $routeRows
    maximumEffectiveLength = $maximumEffective
    maximumComponentLength = $maximumComponent
    reservedSuffixCharacters = 32
    exactFinalZipExtractionPassed = $true
    exactFinalZipSignaturePassed = $true
    exactFinalZipMembershipPassed = $true
    deepSourcePathsPreserved = $true
    filesystemReturnPathsFlattened = $false
    acquisitionKeyInferenceAllowed = $false
    unmatchedOrAmbiguousRemainHold = $true
    publicationAuthorized = $false
    maximumRequests = 0
    retryOnFailure = $false
    matchingSignedTerminalResponseCollectionOnly = $true
    externalRouteContacted = $false
    imageFilesOpened = $false
    pixelsDecoded = $false
    sourceMutation = $false
    taskProcessOrQueueManagement = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path (Join-Path $finalPartial ($requestId + '.ready.zip.path_gate.json')) -Value $routeGate
[IO.Directory]::Move($finalPartial, $finalRoot)
Write-JsonCreateNew -Path $packageGatePath -Value $packageGate
Write-JsonCreateNew -Path $routeGatePath -Value $routeGate
[IO.Directory]::Delete($stageRoot, $true)
[IO.Directory]::Delete($verifyRoot, $true)
Assert-True (Test-Path -LiteralPath $finalZip -PathType Leaf) 'R18W2 exact release ZIP is absent after finalization.'
Assert-True ((Get-Sha256 $finalZip) -eq $zipSha256) 'R18W2 exact release ZIP changed after finalization.'
[ordered]@{
    schema = 'argos_r18w2_build_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18W2_EXACT_SIGNED_DATA_PULL_LOCAL_ONLY_UNPUBLISHED'
    requestId = $requestId
    requestZip = $finalZip
    requestZipBytes = $zipBytes
    requestZipSha256 = $zipSha256
    packageGate = $packageGatePath
    routeGate = $routeGatePath
    requestedLeaf = $requestedLeaf
    requestedFileCount = 1
    crosswalkMemberCount = 14
    acquisitionKeyInferenceAllowed = $false
    publicationAuthorized = $false
    retryAuthorized = $false
    externalRouteContacted = $false
    imageFilesOpened = $false
    sourceMutation = $false
    taskProcessOrQueueManagement = $false
    temporaryRootsRemoved = @($stageRoot, $verifyRoot)
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8
