#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F9([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F9Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-O3F9Json([string]$Path, [object]$Value) { Assert-O3F9 (-not (Test-Path -LiteralPath $Path)) "O3F9 route gate exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F9_PACKAGE_SPEC.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$finalGatePath = Join-Path $PSScriptRoot 'O3F9_FINAL_PACKAGE_GATE.json'
$outputPath = Join-Path (Join-Path $PSScriptRoot 'final_o3f9') 'O3F9_PREPUBLICATION_PATH_GATE.json'
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$requestId = [string]$spec.requestId
$readyName = [string]$spec.requestReadyName
$zipName = $readyName + '.zip'
$responseName = 'R_0123456789AB_20260902235959999_a1b2c3d4.ready'
$payloadLeaves = @('Invoke-O3F9StagedEndpoint.ps1','Run-O3F9Staged.py','Run-O3F8Staged.py','FullPerimeterWaferTopologyOpenCvR10.py','FullPerimeterWaferTopologyOpenCvR9.py','FullPerimeterWaferTopologyOpenCvR8.py','Detect-O3P8FrontSplitNotches.py','Test-O3F8SymmetricRecovery.py','O3P8_POST2_SHORT_ALIAS_JOB.json','O3M9_SLOT16_JOB.json','OCV03_NotchReviewOpenCvV1.py','O3F9FixtureRunner.py','O3F9_ENDPOINT_LIVE_INVOCATION.json')
$paths = New-Object Collections.Generic.List[string]
foreach ($leaf in $payloadLeaves) { $paths.Add("C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending/$readyName/payload/$leaf") }
foreach ($path in @(
    (Join-Path $project "work/OPENCV_EDGE_NOTCH_O3F9/final_o3f9/$zipName"),
    "U:/ProjectPortalRO/requests/$zipName.upload", "U:/ProjectPortalRO/requests/$zipName",
    "C:/APR/S/requests/$zipName", "C:/APR/S/requests/processed/$zipName",
    "C:/ProgramData/ArgosProjectPortalRO/share/staging/$zipName", "C:/ProgramData/ArgosProjectPortalRO/share/request_archive/$zipName",
    "C:/ProgramData/ArgosProjectPortalRO/requests_to_argos/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/requests_from_gateway/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_jbod/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_jbod/sent/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/processed/completed/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/MAINTENANCE.stdout.txt",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/MAINTENANCE.stderr.txt",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/work/J_0123456789AB_01234567/RESULT.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/compact/C_0123456789AB_01234567/FAILURE.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/ledger/$requestId.json",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/maintenance/$requestId/prior/M000_0123456789_0123456789.prior",
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/maintenance/$requestId/failed_new/M000_0123456789_0123456789.rollback",
    'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/.M000_0123456789_0123456789.stage',
    'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/.M000_0123456789_0123456789.restore',
    'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/OCV03_NotchReviewOpenCvV1.py',
    'D:/O3F9G1/SUMMARY.json.partial', 'D:/O3F9G1.failed/SUMMARY.json',
    'D:/O3F9D1/cases/C0006/0123456789abcdef_df_r10_recovery_enhanced.png', 'D:/O3F9D1/SUMMARY.json.partial', 'D:/O3F9D1.failed/SUMMARY.json',
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/response_quarantine/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/MAINTENANCE.stdout.txt",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/from_jbod/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/APR/R/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/APR/A/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/share/response_zip_archive/$responseName.zip",
    "U:/ProjectPortalRO/responses/$responseName.zip", "C:/A9C/$responseName.zip",
    "C:/A9C/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/A9C/$responseName/MAINTENANCE.stdout.txt"
)) { $paths.Add([string]$path) }
$pathRows = New-Object Collections.Generic.List[object]
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($path in $paths.ToArray()) { $one = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json; Assert-O3F9 ([string]$one.state -eq 'PASS_PATH_BUDGET') "O3F9 route path failed: $path"; $row=@($one.candidates)[0]; $pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state=[string]$row.disposition}) }
$rows = $pathRows.ToArray()
Assert-O3F9 ($rows.Count -ge 50 -and @($rows.path | Sort-Object -Unique).Count -eq $rows.Count) 'O3F9 complete route cardinality changed.'
$longest = @($rows | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$result = [ordered]@{schema='argos_ocv03_o3f9_complete_route_gate_v1';state=$(if($Preflight){'PASS_O3F9_COMPLETE_ROUTE_PREFLIGHT'}else{'PASS_O3F9_COMPLETE_ROUTE_GATE'});requestId=$requestId;jobClass='MAINTENANCE_PATCH';routePathRowsEvaluated=$rows.Count;reservedSuffixCharacters=32;maximumPlannedEffectiveLength=[int]$longest.effectiveLength;maximumPlannedComponentLength=[int](($rows|Measure-Object longestComponentLength -Maximum).Maximum);longestPath=[string]$longest.path;payloadLeaves=$payloadLeaves;maximumResultBytes=[int64]$spec.maximumPortalResultBytes;endpointWorkerSha256=[string]$spec.inheritedRoute.endpointWorkerSha256;installedConfigEvidenceSha256=[string]$spec.inheritedRoute.installedRouteConfigEvidenceSha256;inheritedQueueSafetyGateSha256=[string]$spec.inheritedRoute.queueSafetyGateSha256;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;requestRetryAuthorized=$false;rows=$rows;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 10; return }
Assert-O3F9 (Test-Path -LiteralPath $finalGatePath -PathType Leaf) 'O3F9 final package gate is absent.'
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-O3F9 ([string]$finalGate.state -eq 'PASS_O3F9_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O3F9 final package gate changed.'
$result.requestZipSha256 = [string]$finalGate.requestZipSha256
$result.requestManifestSha256 = [string]$finalGate.requestManifestSha256
$result.requestSignatureSha256 = [string]$finalGate.requestSignatureSha256
Write-O3F9Json $outputPath $result
$result | ConvertTo-Json -Depth 10
