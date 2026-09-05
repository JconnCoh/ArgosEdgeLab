#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18W3'
$branch = 'codex/opencv-scribe-deciphering'
$definitionPath = Join-Path $PSScriptRoot 'R18W3_DATA_PULL_DEFINITION.json'
$selectionPath = Join-Path $PSScriptRoot 'R18W3_SELECTION.json'
$routePinsPath = Join-Path $PSScriptRoot 'R18W3_ROUTE_PINS.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18W3_LOCAL_PACKAGE_PREPARATION.json'
$cloneManifestPath = Join-Path $PSScriptRoot 'R18W3_CLONE_LITERAL_REMEDIATION_V2.json'
$cloneGatePath = Join-Path $PSScriptRoot 'R18W3_CLONE_LITERAL_GATE.json'
$harnessGatePath = Join-Path $PSScriptRoot 'R18W3_HARNESS_GATE.json'
$wrapperGatePath = Join-Path $PSScriptRoot 'R18W3_WRAPPER_APPLICABILITY_GATE.json'
$rosterPath = Join-Path $project 'work\OPENCV_SCRIBE_R18UQ3\R18UQ3_LIVE_INSITEREAD_ROSTER.json'
$reconciliationPath = Join-Path $project 'work\OPENCV_SCRIBE_R18UJ3\R18UJ3_LIVE_RECONCILIATION.json'
$referenceCrosswalkPath = Join-Path $project 'work\OPENCV_SCRIBE_R18X\R18X_EXACT_SCRIBE_LINEAGE_CROSSWALK.json'
$historyPath = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificatePath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$stageRoot = 'C:\R18W3B'
$verifyRoot = 'C:\R18W3V'
$responseExtractRoot = 'C:\R18W3R'
$localExtractRoot = 'C:\R18W3'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalZip = Join-Path $finalRoot ($requestId + '.ready.zip')
$packageGatePath = Join-Path $PSScriptRoot 'R18W3_FINAL_PACKAGE_GATE.json'
$routeGatePath = Join-Path $PSScriptRoot 'R18W3_COMPLETE_ROUTE_GATE.json'
$pathSidecar = $finalZip + '.path_gate.json'
$maximumBytes = [int64]50331648
$definitionSha256 = '5D7A8B30462AED9B29CE1C94BB5559305283E5D1E694DF1D22BE9723A0747372'
$selectionSha256 = '48795396398ED73F73C87509803FC1B647389872CDDC5F31B532995906181D7E'
$routePinsSha256 = '898EBFA7DE906B89CACE0CD20E03656C7B4A917F401C49EB3FB8579426F52728'
$preactionSha256 = '3EE6E9D5EA74C40FB11AC7A5EA9728B46379932DB78C6C9880E10D8978971382'
$cloneManifestSha256 = 'CFA99769E19D57BE0122E57EC9A3961DD67A7CE8D17A9A4366B4269B575E6FDB'
$rosterSha256 = 'CE108A3726EFDD53651453CB3310E06051D6E53DDD3654A304446D9070C19DAB'
$reconciliationSha256 = '419A6A0172C675F4A8DF42EE5ED152846E690D3A667435A89F91B344AD4A5B64'
$referenceCrosswalkSha256 = 'EAF725D04C899CCEFC70E29DDA990D4058F226D7C602C1607D7ADB2E9CED1099'
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
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "R18W3 dependency is absent: $Path"
    Assert-True ((Get-Sha256 $Path) -eq $Sha256) "R18W3 dependency changed: $Path"
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
Assert-Pin $selectionPath $selectionSha256
Assert-Pin $routePinsPath $routePinsSha256
Assert-Pin $preactionPath $preactionSha256
Assert-Pin $cloneManifestPath $cloneManifestSha256
Assert-Pin $rosterPath $rosterSha256
Assert-Pin $reconciliationPath $reconciliationSha256
Assert-Pin $referenceCrosswalkPath $referenceCrosswalkSha256

$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
$selection = Get-Content -LiteralPath $selectionPath -Raw | ConvertFrom-Json
$routePins = Get-Content -LiteralPath $routePinsPath -Raw | ConvertFrom-Json
$roster = Get-Content -LiteralPath $rosterPath -Raw | ConvertFrom-Json
$reconciliation = Get-Content -LiteralPath $reconciliationPath -Raw | ConvertFrom-Json
$referenceCrosswalk = Get-Content -LiteralPath $referenceCrosswalkPath -Raw | ConvertFrom-Json

Assert-True ([string]$selection.state -eq 'PASS_R18W3_CORRECTED_EIGHT_SELECTION_VALIDATED') 'R18W3 selection state changed.'
$selected = @($selection.selected | Sort-Object { [int]$_.ordinal })
Assert-True ([int]$selection.selectedCount -eq 8 -and $selected.Count -eq 8) 'R18W3 selection cardinality changed.'
$resolvedRosterMembers = @($roster.lots | ForEach-Object { @($_.resolvedMembers) })
$acquisitionKeys = New-Object Collections.Generic.HashSet[string] ([StringComparer]::Ordinal)
$requestIdentities = New-Object Collections.Generic.HashSet[string] ([StringComparer]::Ordinal)
$lineageKeys = New-Object Collections.Generic.HashSet[string] ([StringComparer]::Ordinal)
$selectionTruths = New-Object Collections.Generic.HashSet[string] ([StringComparer]::Ordinal)
for ($i = 0; $i -lt $selected.Count; $i++) {
    $row = $selected[$i]
    $ordinal = [int]$row.ordinal
    $acquisitionKey = [string]$row.sourceAcquisitionKey
    $requestIdentity = [string]$row.requestIdentity
    $queryLot = [string]$row.queryLot
    $unit = [string]$row.issuedWaferContainer
    $scribe = [string]$row.scribe
    $lineageKey = [string]$row.independentLineageKey
    Assert-True ($ordinal -eq ($i + 1)) 'R18W3 selection ordinal changed.'
    Assert-True ($scribe -cmatch '^[A-Z0-9]{12}$') 'R18W3 exact scribe format changed.'
    Assert-True ($lineageKey -ceq ($queryLot + '|' + $unit + '|' + $scribe)) 'R18W3 physical-lineage key changed.'
    Assert-True ($acquisitionKeys.Add($acquisitionKey) -and $requestIdentities.Add($requestIdentity) -and $lineageKeys.Add($lineageKey) -and $selectionTruths.Add($scribe)) 'R18W3 selection contains a duplicate acquisition, identity, physical lineage, or exact scribe.'
    $j3Matches = @($reconciliation.resolvedRosterToAcquisitionRows | Where-Object { [string]$_.acquisitionKey -ceq $acquisitionKey -and [string]$_.queryLot -ceq $queryLot -and [string]$_.issuedWaferContainer -ceq $unit -and [string]$_.scribe -ceq $scribe -and [string]$_.independentLineageKey -ceq $lineageKey })
    Assert-True ($j3Matches.Count -eq 1) 'R18W3 selection row does not bind one exact J3 acquisition/physical-lineage row.'
    $q3Matches = @($resolvedRosterMembers | Where-Object { [string]$_.queryLot -ceq $queryLot -and [string]$_.unitContainer -ceq $unit -and [string]$_.resolvedScribe -ceq $scribe })
    Assert-True ($q3Matches.Count -eq 1) 'R18W3 selection row does not bind one exact Q3 MES member.'
}
Assert-True ($acquisitionKeys.Count -eq 8 -and $requestIdentities.Count -eq 8 -and $lineageKeys.Count -eq 8 -and $selectionTruths.Count -eq 8) 'R18W3 selection uniqueness changed.'
Assert-True (-not $requestIdentities.Contains('62546-481-POST_20260708155428_Slot21')) 'R18W3 same-truth POST Slot21 leaked into development.'
Assert-True (-not $requestIdentities.Contains('62546-481_20260707164232_Slot21')) 'R18W3 current Slot21 validation leaked into development.'
Assert-True (-not $requestIdentities.Contains('62629-401_20260902002921_Slot24')) 'R18W3 local-only Slot24 fixture leaked into the package.'
Assert-True (-not $selectionTruths.Contains('13HFX135SUE3') -and -not $selectionTruths.Contains('5565R022FEG5')) 'R18W3 removed W1 truth leaked into the corrected selection.'
$xRow = @($selected | Where-Object { [string]$_.requestIdentity -ceq '62625-907-POST-20260714155300_20260714155354_Slot14' -and [string]$_.issuedWaferContainer -ceq '62625-907-060' -and [string]$_.scribe -ceq '146XF109SUG7' -and [string]$_.independentLineageKey -ceq '62625-907|62625-907-060|146XF109SUG7' })
$rRow = @($selected | Where-Object { [string]$_.requestIdentity -ceq '62619-451-PRE_20260717143452_Slot01' -and [string]$_.issuedWaferContainer -ceq '62619-451-010' -and [string]$_.scribe -ceq '146AR068SUC7' -and [string]$_.independentLineageKey -ceq '62619-451|62619-451-010|146AR068SUC7' })
Assert-True ($xRow.Count -eq 1 -and $rRow.Count -eq 1) 'R18W3 required X/R physical-lineage replacements changed.'

$referenceTruths = @($referenceCrosswalk.baseLineages + $referenceCrosswalk.supplementalLineages | ForEach-Object { [string]$_.exactScribeLineage } | Sort-Object -Unique)
Assert-True ([int]$referenceCrosswalk.summary.combinedExactScribeLineages -eq 41 -and $referenceTruths.Count -eq 41) 'R18W3 frozen R18X reference-lineage cardinality changed.'
$referenceOverlap = @($selectionTruths | Where-Object { $referenceTruths -ccontains [string]$_ } | Sort-Object -Unique)
$reservedValidationTruth = [string]$referenceCrosswalk.currentSlot21Separation.currentExactMesTruth
Assert-True ([string]$referenceCrosswalk.currentSlot21Separation.currentAcquisitionKey -ceq '62546-481_20260707164232_SLOT21' -and $reservedValidationTruth -ceq '13HFX135SUE3') 'R18W3 reserved current Slot21 truth changed.'
$validationOverlap = @($selectionTruths | Where-Object { [string]$_ -ceq $reservedValidationTruth })
Assert-True ($referenceOverlap.Count -eq 0 -and $validationOverlap.Count -eq 0) 'R18W3 selection truth overlaps a frozen reference or reserved validation truth.'
Assert-True ([int]$selection.overlapContract.referenceCrosswalkExpectedExactScribeLineages -eq 41 -and [int]$selection.overlapContract.selectionIndependentLineageCount -eq 8 -and [int]$selection.overlapContract.selectionReferenceTruthOverlapRequired -eq 0 -and [int]$selection.overlapContract.selectionReservedValidationTruthOverlapRequired -eq 0) 'R18W3 overlap contract changed.'

$expectedPaths = New-Object Collections.Generic.List[string]
foreach ($row in $selected) {
    $base = 'identity/proposals/' + [string]$row.requestIdentity
    $expectedPaths.Add($base + '/SCRIBE_PROPOSAL.json')
    $expectedPaths.Add($base + '/scribe/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png')
    $expectedPaths.Add($base + '/scribe/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png')
}
$relativePaths = @($definition.parameters.relativePaths | ForEach-Object { [string]$_ })
Assert-StringArrayExact -Actual $relativePaths -Expected $expectedPaths.ToArray() -Message 'R18W3 DATA_PULL leaves do not exactly match the corrected ordered selection.'
Assert-True ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'DATA_PULL' -and [string]$definition.parameters.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R18W3 route changed.'
Assert-True ([int]$definition.parameters.maximumFiles -eq 24 -and [int64]$definition.parameters.maximumBytes -eq $maximumBytes -and [int64]$definition.maxResultBytes -eq $maximumBytes) 'R18W3 bounds changed.'
Assert-True ($relativePaths.Count -eq 24 -and @($relativePaths | Sort-Object -Unique).Count -eq 24) 'R18W3 exact file cardinality changed.'
Assert-True (@($relativePaths | Where-Object { $_ -like '*/SCRIBE_PROPOSAL.json' }).Count -eq 8 -and @($relativePaths | Where-Object { $_ -like '*/BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png' }).Count -eq 8 -and @($relativePaths | Where-Object { $_ -like '*/DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png' }).Count -eq 8) 'R18W3 proposal/BF/DF cardinality changed.'
Assert-True (@($relativePaths | Where-Object { $_ -like '*ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json' -or $_ -like '*62546-481-POST_20260708155428_Slot21*' -or $_ -like '*62546-481_20260707164232_Slot21*' -or $_ -like '*62629-401_20260902002921_Slot24*' }).Count -eq 0) 'R18W3 excluded overlay, validation, or fixture leaf entered the definition.'

Assert-True ([string]$routePins.state -eq 'PASS_R18W3_INHERITED_ROUTE_PINS') 'R18W3 route-pin state changed.'
Assert-True ([string]$routePins.requestId -eq $requestId -and [string]$routePins.route.targetRole -eq 'JBOD' -and [string]$routePins.route.jobClass -eq 'DATA_PULL' -and [string]$routePins.route.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW') 'R18W3 route pins changed.'
Assert-True ([string]$routePins.route.installedEndpointWorkerSha256 -eq $installedWorkerSha256) 'R18W3 installed worker pin changed.'
Assert-True (-not [bool]$routePins.authority.publicationAuthorized -and [int]$routePins.authority.maximumPublications -eq 0 -and -not [bool]$routePins.authority.retryAuthorized) 'R18W3 publication or retry authority widened.'
Assert-Pin (Join-Path $project ([string]$routePins.route.r18gCompleteRouteGate.path)) $r18gRouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.r15eInheritedRouteGate.path)) $inheritedRouteSha256
Assert-Pin (Join-Path $project ([string]$routePins.route.c1eQueueSafetyGate.path)) $queueSafetySha256
Assert-Pin (Join-Path $project ([string]$routePins.route.c1eReadOnlyCapabilityInventory.path)) $capabilityInventorySha256
Assert-Pin (Join-Path $project ([string]$routePins.route.workerSource.path)) ([string]$routePins.route.workerSource.sha256)
Assert-Pin (Join-Path $project ([string]$routePins.selectionEvidence.reconciliation.path)) $reconciliationSha256
Assert-Pin (Join-Path $project ([string]$routePins.selectionEvidence.mesRoster.path)) $rosterSha256
Assert-Pin (Join-Path $project ([string]$routePins.selectionEvidence.referenceCrosswalk.path)) $referenceCrosswalkSha256
Assert-Pin $identityPath ([string]$routePins.signing.identitySha256)
Assert-Pin $publicCertificatePath ([string]$routePins.signing.publicCertificateSha256)
Assert-Pin $packageTester ([string]$routePins.signing.packageVerifierSha256)
$r18gRoute = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r18gCompleteRouteGate.path)) -Raw | ConvertFrom-Json
$r15eRoute = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.r15eInheritedRouteGate.path)) -Raw | ConvertFrom-Json
$queueSafety = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.c1eQueueSafetyGate.path)) -Raw | ConvertFrom-Json
$capability = Get-Content -LiteralPath (Join-Path $project ([string]$routePins.route.c1eReadOnlyCapabilityInventory.path)) -Raw | ConvertFrom-Json
Assert-True ([string]$r18gRoute.state -eq 'PASS_R18G_COMPLETE_ROUTE_GATE' -and [string]$r18gRoute.approvedRoot -eq 'JBOD_PROCESSOR_REVIEW' -and [string]$r18gRoute.installedEndpointWorkerSha256 -eq $installedWorkerSha256) 'R18W3 inherited R18G route evidence changed.'
Assert-True ([string]$r15eRoute.state -eq 'PASS_R15E_COMPLETE_ROUTE_GATE' -and [string]$queueSafety.state -eq 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL') 'R18W3 inherited route or queue gate changed.'
$dataPullCapability = @($capability.routes | Where-Object { [string]$_.type -eq 'DATA_PULL' })
Assert-True ($dataPullCapability.Count -eq 1 -and @($dataPullCapability[0].capabilities) -contains 'approvedRootExactFiles') 'R18W3 DATA_PULL capability is not pinned.'

$preactionJson = & $preactionTool -AuditPath $historyPath -ContractPath $preactionPath -ProjectRoot $project -Preflight
$preactionResult = $preactionJson | ConvertFrom-Json
Assert-True ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18W3 preaction gate failed.'

$currentBranch = (& git -C $project branch --show-current | Out-String).Trim()
$localTip = (& git -C $project rev-parse HEAD | Out-String).Trim()
$remoteTip = (& git -C $project rev-parse ('refs/remotes/origin/' + $branch) | Out-String).Trim()
$status = @(& git -C $project status --porcelain=v1)
Assert-True ($currentBranch -eq $branch -and $localTip -eq $remoteTip) 'R18W3 requires the dedicated branch to match the recorded origin tip.'

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
foreach ($relativePath in $relativePaths) {
    $routePaths.Add(($localExtractRoot + '\data\JBOD_PROCESSOR_REVIEW\' + $relativePath.Replace('/', '\')))
}
$pathGate = & $pathTool -CandidatePath $routePaths.ToArray() -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'R18W3 complete route path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True ($maximumEffective -lt 200 -and $maximumComponent -le 80) 'R18W3 route requires a shorter namespace.'

foreach ($path in @($stageRoot, $verifyRoot, $finalPartial, $finalRoot, $packageGatePath, $routeGatePath, $pathSidecar)) {
    Assert-True (-not (Test-Path -LiteralPath $path)) "R18W3 fresh output exists: $path"
}
$identity = Get-Content -LiteralPath $identityPath -Raw | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ', '').ToUpperInvariant()
Assert-True ($thumbprint -eq [string]$routePins.signing.signerThumbprint) 'R18W3 signer thumbprint changed.'
$certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
Assert-True ([bool]$certificate.HasPrivateKey) 'R18W3 signer private key is unavailable.'

$selfHash = Get-Sha256 $PSCommandPath
if ($Build) {
    foreach ($gatePath in @($cloneGatePath, $harnessGatePath, $wrapperGatePath)) { Assert-True (Test-Path -LiteralPath $gatePath -PathType Leaf) "R18W3 prerequisite gate is absent: $gatePath" }
    $cloneGate = Get-Content -LiteralPath $cloneGatePath -Raw | ConvertFrom-Json
    $harnessGate = Get-Content -LiteralPath $harnessGatePath -Raw | ConvertFrom-Json
    $wrapperGate = Get-Content -LiteralPath $wrapperGatePath -Raw | ConvertFrom-Json
    Assert-True ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$cloneGate.pairs[0].generatedSha256 -eq $selfHash) 'R18W3 clone-remediation gate is stale.'
    Assert-True ([string]$harnessGate.state -eq 'PASS_R18W3_SOURCE_AND_GENERATED_HARNESS_SAFETY' -and [string]$harnessGate.generatedPowerShellScriptSha256 -eq $selfHash) 'R18W3 harness gate is stale.'
    Assert-True ([string]$wrapperGate.state -eq 'PASS_R18W3_WRAPPER_NOT_APPLICABLE' -and -not [bool]$wrapperGate.cmdWrapperCreated) 'R18W3 wrapper applicability changed.'
}

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r18w3_build_preflight_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_R18W3_BUILD_PREFLIGHT_LOCAL_ONLY'
        requestId = $requestId
        selectedAcquisitionCount = 8
        independentPhysicalLineageCount = 8
        exactScribeTruthCount = 8
        referenceExactScribeLineageCount = 41
        selectionReferenceTruthOverlapCount = $referenceOverlap.Count
        selectionReservedValidationTruthOverlapCount = $validationOverlap.Count
        reservedValidationTruth = $reservedValidationTruth
        requestedFileCount = 24
        proposalFileCount = 8
        imageFileCount = 16
        overlayFileCount = 0
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
        acquisitionIdentityUsedAsPhysicalLineageAuthority = $false
        sameTruthPostSlot21Excluded = $true
        currentValidationSlot21Excluded = $true
        localOnlyFixtureSlot24Excluded = $true
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
Assert-True ([string]$folderTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18W3 signed folder validation failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[void](New-Item -ItemType Directory -Path $finalPartial)
$zipPartial = Join-Path $finalPartial ($requestId + '.ready.zip')
[IO.Compression.ZipFile]::CreateFromDirectory($stageRoot, $zipPartial, [IO.Compression.CompressionLevel]::Optimal, $false)
$archive = [IO.Compression.ZipFile]::OpenRead($zipPartial)
try { $actualPackageMembership = @($archive.Entries | ForEach-Object { [string]$_.FullName.Replace('\', '/') } | Sort-Object) } finally { $archive.Dispose() }
Assert-StringArrayExact -Actual $actualPackageMembership -Expected $plannedPackageMembership -Message 'R18W3 final ZIP membership changed.'
$actualPackageMembershipSha256 = Get-StringSha256 (($actualPackageMembership -join "`n") + "`n")
Assert-True ($actualPackageMembershipSha256 -eq $plannedPackageMembershipSha256) 'R18W3 final ZIP membership fingerprint changed.'
[IO.Compression.ZipFile]::ExtractToDirectory($zipPartial, $verifyRoot)
$extractTest = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificatePath -ExpectedTargetRole JBOD -ExpectedJobClass DATA_PULL
Assert-True ([string]$extractTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE' -and @(Get-ChildItem -LiteralPath $verifyRoot -File).Count -eq 2) 'R18W3 exact ZIP validation failed.'
$zipSha256 = Get-Sha256 $zipPartial
$zipBytes = [int64](Get-Item -LiteralPath $zipPartial).Length
$manifestSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json')
$signatureSha256 = Get-Sha256 (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig')
$routeRows = @($pathGate.candidates | ForEach-Object { [ordered]@{path=[string]$_.path;pathLength=[int]$_.pathLength;effectiveLength=[int]$_.effectiveLength;longestComponentLength=[int]$_.longestComponentLength;state='PASS_PATH_BUDGET'} })
$selectionRows = @($selected | ForEach-Object { [ordered]@{ordinal=[int]$_.ordinal;sourceAcquisitionKey=[string]$_.sourceAcquisitionKey;requestIdentity=[string]$_.requestIdentity;queryLot=[string]$_.queryLot;issuedWaferContainer=[string]$_.issuedWaferContainer;scribe=[string]$_.scribe;independentLineageKey=[string]$_.independentLineageKey;requestedGlyphLabels=@($_.requestedGlyphLabels)} })
$cloneGateSha256 = Get-Sha256 $cloneGatePath
$harnessGateSha256 = Get-Sha256 $harnessGatePath
$wrapperGateSha256 = Get-Sha256 $wrapperGatePath
$packageGate = [ordered]@{
    schema = 'argos_r18w3_final_package_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18W3_FINAL_PACKAGE_GATE_SIGNED_UNPUBLISHED'
    requestId = $requestId
    requestZip = 'work/OPENCV_SCRIBE_R18W3/final/REQ_R18W3.ready.zip'
    requestZipBytes = $zipBytes
    requestZipSha256 = $zipSha256
    requestManifestSha256 = $manifestSha256
    requestSignatureSha256 = $signatureSha256
    packageMembership = $actualPackageMembership
    packageMembershipSha256 = $actualPackageMembershipSha256
    definitionSha256 = $definitionSha256
    selectionSha256 = $selectionSha256
    mesRosterSha256 = $rosterSha256
    reconciliationSha256 = $reconciliationSha256
    referenceCrosswalkSha256 = $referenceCrosswalkSha256
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
    selectedAcquisitionCount = 8
    independentPhysicalLineageCount = 8
    exactScribeTruthCount = 8
    referenceExactScribeLineageCount = 41
    selectionReferenceTruthOverlapCount = $referenceOverlap.Count
    selectionReservedValidationTruthOverlapCount = $validationOverlap.Count
    reservedValidationTruth = $reservedValidationTruth
    requestedFileCount = 24
    proposalFileCount = 8
    imageFileCount = 16
    overlayFileCount = 0
    maximumFiles = 24
    maximumBytes = $maximumBytes
    acquisitionIdentityUsedAsPhysicalLineageAuthority = $false
    sameTruthPostSlot21Excluded = $true
    currentValidationSlot21Excluded = $true
    localOnlyFixtureSlot24Excluded = $true
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
    schema = 'argos_r18w3_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18W3_COMPLETE_ROUTE_GATE_SIGNED_UNPUBLISHED'
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
    selection = $selectionRows
    selectionSha256 = $selectionSha256
    referenceCrosswalkSha256 = $referenceCrosswalkSha256
    referenceExactScribeLineageCount = 41
    selectionReferenceTruthOverlapCount = $referenceOverlap.Count
    selectionReservedValidationTruthOverlapCount = $validationOverlap.Count
    reservedValidationTruth = $reservedValidationTruth
    relativePaths = $relativePaths
    selectedAcquisitionCount = 8
    independentPhysicalLineageCount = 8
    proposalFileCount = 8
    imageFileCount = 16
    overlayFileCount = 0
    maximumFiles = 24
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
    acquisitionIdentityUsedAsPhysicalLineageAuthority = $false
    sameTruthPostSlot21Excluded = $true
    currentValidationSlot21Excluded = $true
    localOnlyFixtureSlot24Excluded = $true
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
Assert-True (Test-Path -LiteralPath $finalZip -PathType Leaf) 'R18W3 exact release ZIP is absent after finalization.'
Assert-True ((Get-Sha256 $finalZip) -eq $zipSha256) 'R18W3 exact release ZIP changed after finalization.'
[ordered]@{
    schema = 'argos_r18w3_build_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18W3_EXACT_SIGNED_DATA_PULL_LOCAL_ONLY_UNPUBLISHED'
    requestId = $requestId
    requestZip = $finalZip
    requestZipBytes = $zipBytes
    requestZipSha256 = $zipSha256
    packageGate = $packageGatePath
    routeGate = $routeGatePath
    selectedAcquisitionCount = 8
    independentPhysicalLineageCount = 8
    requestedFileCount = 24
    proposalFileCount = 8
    imageFileCount = 16
    overlayFileCount = 0
    referenceExactScribeLineageCount = 41
    selectionReferenceTruthOverlapCount = $referenceOverlap.Count
    selectionReservedValidationTruthOverlapCount = $validationOverlap.Count
    acquisitionIdentityUsedAsPhysicalLineageAuthority = $false
    sameTruthPostSlot21Excluded = $true
    currentValidationSlot21Excluded = $true
    localOnlyFixtureSlot24Excluded = $true
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
