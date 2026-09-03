#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L3 create-new route gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function New-BoundaryPath([int]$Length) {
    $value = 'C:\O3F15L3B\'
    while (($Length - $value.Length) -gt 11) { $value += '1234567890\' }
    $remaining = $Length - $value.Length
    Require ($remaining -ge 1) 'O3F15L3 boundary path target is too short.'
    $value + ('x' * $remaining)
}
function Test-Boundary([int]$EffectiveLength, [string]$PowerShell, [string]$PathTool, [int]$Reserve) {
    $candidate = New-BoundaryPath ($EffectiveLength - $Reserve)
    $json = @(& $PowerShell -NoProfile -ExecutionPolicy Bypass -File $PathTool -CandidatePath $candidate -ReservedSuffixCharacters $Reserve -AsJson 2>$null) -join [Environment]::NewLine
    $exitCode = $LASTEXITCODE
    $result = $json | ConvertFrom-Json
    $expectedState = if ($EffectiveLength -lt 200) { 'PASS_PATH_BUDGET' } elseif ($EffectiveLength -lt 230) { 'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH' } else { 'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH' }
    $expectedExit = if ($EffectiveLength -lt 200) { 0 } elseif ($EffectiveLength -lt 230) { 1 } else { 2 }
    Require ($exitCode -eq $expectedExit -and [string]$result.state -ceq $expectedState -and [int]$result.candidates[0].effectiveLength -eq $EffectiveLength -and [bool]$result.metadataOnly -and -not [bool]$result.fileContentRead) "O3F15L3 path boundary failed: $EffectiveLength"
    [ordered]@{ effectiveLength=$EffectiveLength; state=$expectedState; exitCode=$expectedExit; candidate=[string]$result.candidates[0].path }
}

Require ($Preflight -xor $Gate) 'Specify exactly one of -Preflight or -Gate.'
Require ([string]$PSVersionTable.PSEdition -ceq 'Desktop' -and [int]$PSVersionTable.PSVersion.Major -eq 5 -and [int]$PSVersionTable.PSVersion.Minor -eq 1) 'O3F15L3 route gate requires exact Windows PowerShell 5.1.'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath = Join-Path $PSScriptRoot 'O3F15L3_DIAGNOSTIC_CONTRACT.json'
$signGatePath = Join-Path $PSScriptRoot 'O3F15L3_SIGN_GATE.json'
$queueGatePath = Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$finalRoot = Join-Path $PSScriptRoot 'final_o3f15l3'
$outputPath = Join-Path $finalRoot 'O3F15L3_PREPUBLICATION_PATH_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
foreach ($path in @($contractPath,$signGatePath,$queueGatePath,$pathTool,$windowsPowerShell)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 route dependency absent: $path" }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
$signGate = Get-Content -LiteralPath $signGatePath -Raw | ConvertFrom-Json
$queueGate = Get-Content -LiteralPath $queueGatePath -Raw | ConvertFrom-Json
Require ([string]$contract.schema -ceq 'argos_ocv03_o3f15l3_diagnostic_contract_v1' -and [string]$contract.state -ceq 'FROZEN_FOR_BUILD') 'O3F15L3 route contract changed.'
Require ([string]$signGate.state -ceq 'PASS_O3F15L3_SIGNED_PREFLIGHT_DIAGNOSTIC_PACKAGE') 'O3F15L3 route sign gate changed.'
Require ((Sha $queueGatePath) -ceq '170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D' -and [string]$queueGate.state -ceq 'PASS_JBOD_PORTAL_QUEUE_RECOVERY_V2_1_REHEARSAL' -and [int]$queueGate.checkCount -eq 16 -and @($queueGate.checks | Where-Object { [string]$_.state -cne 'PASS' }).Count -eq 0) 'O3F15L3 inherited queue-safety evidence changed.'
$requiredQueueChecks = @('PATH_BOUNDARIES_199_200_229_230','STALE_WORK_COLLISION_AND_SECOND_QUEUE_ITEM','INJECTED_RESPONSE_FAILURE_COMPACT_AND_QUEUE_ADVANCE','FORCED_TERMINATION_AND_RESTART','REQUEST_REPLAY_NO_DUPLICATE_RESPONSE','UNAPPROVED_PREDECESSOR_REFUSED_BEFORE_MUTATION')
foreach ($name in $requiredQueueChecks) { Require (@($queueGate.checks | Where-Object { [string]$_.name -ceq $name -and [string]$_.state -ceq 'PASS' }).Count -eq 1) "O3F15L3 inherited queue check absent: $name" }
Require ([string]$contract.inheritedRoute.endpointWorkerSha256 -ceq 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250' -and [string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256 -ceq '465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB' -and [string]$contract.inheritedRoute.queueSafetyGateSha256 -ceq (Sha $queueGatePath) -and -not [bool]$contract.inheritedRoute.routeImplementationChanged) 'O3F15L3 inherited route pins changed.'
Require ([IO.Path]::GetFullPath([string]$signGate.finalRoot) -ceq [IO.Path]::GetFullPath($finalRoot) -and [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath([string]$signGate.packageZipPath)) -ceq [IO.Path]::GetFullPath($finalRoot)) 'O3F15L3 final ZIP is not adjacent to its path gate.'
$packagePath = [IO.Path]::GetFullPath([string]$signGate.packagePath)
$manifestPath = Join-Path $packagePath 'PORTAL_REQUEST_MANIFEST.json'
Require (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O3F15L3 signed manifest absent.'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Require ((Sha $manifestPath) -ceq [string]$signGate.manifestSha256 -and [string]$manifest.requestId -ceq [string]$signGate.requestId -and @($manifest.files).Count -eq 16 -and [int64]$manifest.maxResultBytes -eq 1048576) 'O3F15L3 signed route manifest changed.'
$requestId = [string]$manifest.requestId
$readyName = $requestId + '.ready'
$zipName = $readyName + '.zip'
$responseName = 'R_0123456789AB_20260903235959999_a1b2c3d4.ready'
$responseZip = $responseName + '.zip'
$partialPackage = [IO.Path]::GetFullPath($packagePath.Substring(0, $packagePath.Length - '.ready'.Length) + '.partial')
$paths = New-Object Collections.Generic.List[string]
foreach ($path in @(
    [string]$signGate.packageZipPath, $outputPath,
    (Join-Path $packagePath 'PORTAL_REQUEST_MANIFEST.json'), (Join-Path $packagePath 'PORTAL_REQUEST_MANIFEST.sig'),
    (Join-Path $partialPackage 'PORTAL_REQUEST_MANIFEST.json'),
    "U:/ProjectPortalRO/requests/$zipName.upload", "U:/ProjectPortalRO/requests/$zipName",
    "C:/APR/S/requests/$zipName", "C:/APR/S/requests/processed/$zipName",
    "C:/ProgramData/ArgosProjectPortalRO/share/staging/$zipName", "C:/ProgramData/ArgosProjectPortalRO/share/request_archive/$zipName",
    "C:/ProgramData/ArgosProjectPortalRO/requests_to_argos/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/requests_from_gateway/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_jbod/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_jbod/sent/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/processed/completed/$readyName/PORTAL_REQUEST_MANIFEST.json",
    'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/MAINTENANCE.stdout.txt',
    'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/MAINTENANCE.stderr.txt',
    'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/RESULT.json',
    'C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/compact/C_0123456789AB_01234567/FAILURE.json',
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/ledger/$requestId.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/maintenance/$requestId/prior/M000_0123456789_0123456789.prior",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/maintenance/$requestId/failed_new/M000_0123456789_0123456789.rollback",
    'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/.M000_0123456789_0123456789.stage',
    'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/.M000_0123456789_0123456789.restore',
    'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py',
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/response_quarantine/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/MAINTENANCE.stdout.txt",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/MAINTENANCE.stderr.txt",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/PORTAL_RESPONSE_MANIFEST.sig",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/from_jbod/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/APR/R/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/APR/A/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/share/response_zip_archive/$responseZip",
    "U:/ProjectPortalRO/responses/$responseZip", "C:/O3F15L3C/$responseZip",
    "C:/O3F15L3C/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/O3F15L3C/$responseName/MAINTENANCE.stdout.txt",
    "C:/O3F15L3C/$responseName/MAINTENANCE.stderr.txt", "C:/O3F15L3C/$responseName/RESULT.json"
)) { $paths.Add([string]$path) }
foreach ($record in @($manifest.files)) {
    $paths.Add((Join-Path $packagePath ([string]$record.path)))
    $paths.Add((Join-Path $partialPackage ([string]$record.path)))
    $paths.Add("C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending/$readyName/$([string]$record.path)")
}
foreach ($pin in @($contract.targetPins)) { $paths.Add([string]$pin.path) }
$actionable = @($paths.ToArray() | Sort-Object -Unique)
$actionableGate = & $pathTool -CandidatePath $actionable -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Require ([string]$actionableGate.state -ceq 'PASS_PATH_BUDGET' -and @($actionableGate.candidates).Count -eq $actionable.Count) 'O3F15L3 actionable round-trip path gate failed.'
$longest = @($actionableGate.candidates | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$componentMaximum = [int](($actionableGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)
Require ([int]$longest.effectiveLength -lt 200 -and $componentMaximum -le 80) 'O3F15L3 actionable route exceeded a safe path bound.'
$boundaries = @(199,200,229,230 | ForEach-Object { Test-Boundary $_ $windowsPowerShell $pathTool 32 })
$result = [ordered]@{
    schema = 'argos_ocv03_o3f15l3_complete_route_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = $(if ($Preflight) { 'PASS_O3F15L3_COMPLETE_ROUTE_PREFLIGHT' } else { 'PASS_O3F15L3_SIGNED_AND_PATH_GATED' })
    requestId = $requestId
    finalRoot = $finalRoot
    packageZipPath = [string]$signGate.packageZipPath
    pathGatePath = $outputPath
    packageZipAndPathGateAdjacent = $true
    packageZipSha256 = [string]$signGate.packageZipSha256
    requestManifestSha256 = [string]$signGate.manifestSha256
    requestSignatureSha256 = [string]$signGate.signatureSha256
    installedRouteConfigRevisionSha256 = [string]$contract.inheritedRoute.installedRouteConfigEvidenceSha256
    endpointWorkerSha256 = [string]$contract.inheritedRoute.endpointWorkerSha256
    queueSafetyGateSha256 = [string]$contract.inheritedRoute.queueSafetyGateSha256
    queueSafetyChecksInherited = $requiredQueueChecks
    reservedSuffixCharacters = 32
    actionablePathCount = $actionable.Count
    maximumActionableEffectiveLength = [int]$longest.effectiveLength
    maximumActionableComponentLength = $componentMaximum
    longestActionablePath = [string]$longest.path
    exactBoundaryTests = $boundaries
    payloadFileCount = @($manifest.files).Count
    longestRelativePayloadLeaf = [string]@($manifest.files | Sort-Object { ([string]$_.path).Length } -Descending | Select-Object -First 1)[0].path
    maximumResultBytes = [int64]$manifest.maxResultBytes
    expandedSigningRootIsShortPhysicalRoot = $packagePath.StartsWith('C:\O3F15L3PK\signed\',[StringComparison]::OrdinalIgnoreCase)
    resultRootCreationAuthorized = $false
    imageReadsAuthorized = $false
    matchingSignedTerminalResponseRequired = $true
    gatewayAcceptanceIsExecutionEvidence = $false
    requestRetryAuthorized = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Require ([bool]$result.expandedSigningRootIsShortPhysicalRoot) 'O3F15L3 expanded signing tree is not on its short physical root.'
if ($Preflight) { $result | ConvertTo-Json -Depth 12; return }
Write-NewJson $outputPath $result
$result | ConvertTo-Json -Depth 12
