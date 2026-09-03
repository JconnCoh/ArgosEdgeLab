#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F12([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F12Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-O3F12TextSha256([string]$Value) { $algorithm=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))).Replace('-','').ToLowerInvariant() } finally { $algorithm.Dispose() } }
function Get-O3F12SafeId([string]$Identity) { $clean=[regex]::Replace($Identity,'[^A-Za-z0-9_.-]+','_').Trim([char[]]@('_','.')); $suffix=(Get-O3F12TextSha256 $Identity).Substring(0,10); if([string]::IsNullOrWhiteSpace($clean)){return $suffix}; $prefix=$(if($clean.Length-gt42){$clean.Substring(0,42)}else{$clean}); return ($prefix+'_'+$suffix) }
function Write-O3F12Json([string]$Path, [object]$Value) { Assert-O3F12 (-not (Test-Path -LiteralPath $Path)) "O3F12 route gate exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$specPath = Join-Path $PSScriptRoot 'O3F12_PACKAGE_SPEC.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$finalGatePath = Join-Path $PSScriptRoot 'O3F12_FINAL_PACKAGE_GATE.json'
$outputPath = Join-Path (Join-Path $PSScriptRoot 'final_o3f12') 'O3F12_PREPUBLICATION_PATH_GATE.json'
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$requestId = [string]$spec.requestId
$readyName = [string]$spec.requestReadyName
$zipName = $readyName + '.zip'
$responseName = 'R_0123456789AB_20260902235959999_a1b2c3d4.ready'
$payloadLeaves = @('Invoke-O3F12StagedEndpoint.ps1','Run-O3F12Staged.py','Run-O3F8Staged.py','FullPerimeterWaferTopologyOpenCvR10.py','FullPerimeterWaferTopologyOpenCvR9.py','FullPerimeterWaferTopologyOpenCvR8.py','Detect-O3P8FrontSplitNotches.py','Test-O3F8SymmetricRecovery.py','O3P8_POST2_SHORT_ALIAS_JOB.json','O3M9_SLOT16_JOB.json','OCV03_NotchReviewOpenCvV1.py','O3F12FixtureRunner.py','O3F12RootContractProbe.py','O3F12_DEV6_SOURCE_ALIAS_PLAN.json','O3F12_ENDPOINT_LIVE_INVOCATION.json')
$aliasPlanPath = Join-Path $PSScriptRoot 'O3F12_DEV6_SOURCE_ALIAS_PLAN.json'
$aliasPlan = Get-Content -LiteralPath $aliasPlanPath -Raw | ConvertFrom-Json
Assert-O3F12 ((Get-O3F12Hash $aliasPlanPath) -eq [string]$spec.sourceAliasPlanSha256 -and [string]$aliasPlan.state -eq 'FROZEN_FOR_BUILD' -and [int]$aliasPlan.caseCount -eq 6 -and [int]$aliasPlan.sourceLeafCount -eq 12) 'O3F12 route source-alias plan changed.'
$canonicalSources = @($aliasPlan.cases | ForEach-Object { @($_.sources) | ForEach-Object { [string]$_.canonicalPath } })
$aliasSources = @($aliasPlan.cases | ForEach-Object { @($_.sources) | ForEach-Object { [string]$_.aliasPath } })
Assert-O3F12 ($canonicalSources.Count -eq 12 -and $aliasSources.Count -eq 12 -and @($canonicalSources | Sort-Object -Unique).Count -eq 12 -and @($aliasSources | Sort-Object -Unique).Count -eq 12) 'O3F12 route source path cardinality changed.'
$safeIdRows = New-Object Collections.Generic.List[object]
$exactDev6Leaves = New-Object Collections.Generic.List[string]
foreach($devRoot in @('D:/O3F9D12','D:/O3F9D12.failed')) {
    $exactDev6Leaves.Add("$devRoot/SUMMARY.json.partial")
    foreach($case in @($aliasPlan.cases)) {
        $ordinal=[int]$case.ordinal
        $identity=([string]$case.identity).Replace('/','\')
        $safeId=Get-O3F12SafeId $identity
        $stem=$safeId.ToLowerInvariant().Replace('-','')
        $digest=(Get-O3F12TextSha256 $safeId).Substring(0,16)
        $caseRoot=("$devRoot/cases/C{0:D4}" -f $ordinal)
        if($devRoot-eq'D:/O3F9D12'){$safeIdRows.Add([pscustomobject]@{ordinal=$ordinal;identity=$identity;safeId=$safeId;stem=$stem;digest=$digest})}
        $exactDev6Leaves.Add(("$devRoot/jobs/J{0:D4}.json.partial" -f $ordinal))
        $exactDev6Leaves.Add(("$devRoot/C{0:D4}.stdout.txt" -f $ordinal))
        $exactDev6Leaves.Add(("$devRoot/C{0:D4}.stderr.txt" -f $ordinal))
        $exactDev6Leaves.Add("$caseRoot/MANIFEST.json.partial")
        $exactDev6Leaves.Add("$caseRoot/${stem}_bf_overview.png")
        $exactDev6Leaves.Add("$caseRoot/${stem}_df_overview.png")
        foreach($suffix in @('clean.png','enhanced.png','overlay.png','mask.png')) {
            $exactDev6Leaves.Add("$caseRoot/${stem}_bf_c24_$suffix")
            $exactDev6Leaves.Add("$caseRoot/${stem}_df_c24_$suffix")
            $exactDev6Leaves.Add("$caseRoot/${digest}_bf_o3p8_recovery_$suffix")
            $exactDev6Leaves.Add("$caseRoot/${digest}_df_r10_recovery_$suffix")
        }
    }
}
$safeIds=$safeIdRows.ToArray()
Assert-O3F12 ($safeIds.Count-eq6-and@($safeIds.safeId|Sort-Object -Unique).Count-eq6-and[string]$safeIds[4].safeId-eq'PatternedFront_Lot_62616-131_62616-131_202_aae0de7fdf') 'O3F12 exact O3F6 safe-ID derivation changed.'
$exactGateLeaves=@('SUMMARY.json.partial','R10_SYMMETRIC_GATE.json','LOCAL.stdout.txt','LOCAL.stderr.txt','INHERITED.stdout.txt','INHERITED.stderr.txt','R10_INHERITED_SYNTHETIC/upper_right_315_df_c01_enhanced.png','R10_INHERITED_SYNTHETIC/SYNTHETIC_GATE.json.partial')|ForEach-Object{"D:/O3F9G12/$_","D:/O3F9G12.failed/$_"}
$paths = New-Object Collections.Generic.List[string]
foreach ($leaf in $payloadLeaves) { $paths.Add("C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending/$readyName/payload/$leaf") }
foreach($leaf in $exactGateLeaves){$paths.Add([string]$leaf)}
foreach($leaf in $exactDev6Leaves.ToArray()){$paths.Add([string]$leaf)}
foreach ($path in @(
    (Join-Path $project "work/OPENCV_EDGE_NOTCH_O3F12/final_o3f12/$zipName"),
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
    'D:/O3F9G12/SUMMARY.json', 'D:/O3F9G12.failed/SUMMARY.json',
    'D:/O3F9D12/SUMMARY.json', 'D:/O3F9D12.failed/SUMMARY.json',
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/response_quarantine/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/MAINTENANCE.stdout.txt",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/from_jbod/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/APR/R/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/APR/A/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/share/response_zip_archive/$responseName.zip",
    "U:/ProjectPortalRO/responses/$responseName.zip", "C:/A12C/$responseName.zip",
    "C:/A12C/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/A12C/$responseName/MAINTENANCE.stdout.txt"
)) { $paths.Add([string]$path) }
$pathRows = New-Object Collections.Generic.List[object]
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
foreach ($path in $paths.ToArray()) { $one = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json; Assert-O3F12 ([string]$one.state -eq 'PASS_PATH_BUDGET') "O3F12 route path failed: $path"; $row=@($one.candidates)[0]; $pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state=[string]$row.disposition}) }
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
Assert-O3F12 (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) 'O3F12 Windows PowerShell 5.1 path gate host is absent.'
foreach ($path in $canonicalSources) {
    $json = @(& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson 2>$null) -join [Environment]::NewLine
    $exit = $LASTEXITCODE
    $one = $json | ConvertFrom-Json
    Assert-O3F12 ($exit -eq 1 -and [string]$one.state -eq 'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH') "O3F12 canonical source did not require its frozen alias: $path"
    $row = @($one.candidates)[0]
    Assert-O3F12 ([int]$row.effectiveLength -ge 200 -and [int]$row.effectiveLength -lt 230 -and [int]$row.longestComponentLength -le 80) "O3F12 canonical source crossed an unhandled path boundary: $path"
    $pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state='CANONICAL_PROVENANCE_SHORT_ALIAS_REQUIRED'})
}
foreach ($path in $aliasSources) {
    $one = & $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
    Assert-O3F12 ([string]$one.state -eq 'PASS_PATH_BUDGET') "O3F12 actionable source alias path failed: $path"
    $row = @($one.candidates)[0]
    $pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state='ACTIONABLE_TEMPORARY_Q_ALIAS_PASS'})
}
$rows = $pathRows.ToArray()
Assert-O3F12 ($rows.Count -ge 75 -and @($rows.path | Sort-Object -Unique).Count -eq $rows.Count) 'O3F12 complete route cardinality changed.'
$longest = @($rows | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$actionableLongest = @($rows | Where-Object { $_.state -ne 'CANONICAL_PROVENANCE_SHORT_ALIAS_REQUIRED' } | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$result = [ordered]@{schema='argos_ocv03_o3f12_complete_route_gate_v1';state=$(if($Preflight){'PASS_O3F12_COMPLETE_ROUTE_PREFLIGHT'}else{'PASS_O3F12_COMPLETE_ROUTE_GATE'});requestId=$requestId;jobClass='MAINTENANCE_PATCH';routePathRowsEvaluated=$rows.Count;reservedSuffixCharacters=32;maximumPlannedEffectiveLength=[int]$longest.effectiveLength;maximumActionableEffectiveLength=[int]$actionableLongest.effectiveLength;maximumPlannedComponentLength=[int](($rows|Measure-Object longestComponentLength -Maximum).Maximum);longestPath=[string]$longest.path;longestActionablePath=[string]$actionableLongest.path;canonicalAliasRequiredCount=12;actionableAliasPassCount=12;sourceAliasPlanSha256=Get-O3F12Hash $aliasPlanPath;safeIdAlgorithm='REGEX_CLEAN_PREFIX42_PLUS_SHA256_UTF8_PREFIX10';dev6SafeIds=$safeIds;exactGateOutputLeafCount=@($exactGateLeaves).Count;exactDev6OutputLeafCount=$exactDev6Leaves.Count;payloadLeaves=$payloadLeaves;maximumResultBytes=[int64]$spec.maximumPortalResultBytes;endpointWorkerSha256=[string]$spec.inheritedRoute.endpointWorkerSha256;installedConfigEvidenceSha256=[string]$spec.inheritedRoute.installedRouteConfigEvidenceSha256;inheritedQueueSafetyGateSha256=[string]$spec.inheritedRoute.queueSafetyGateSha256;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;requestRetryAuthorized=$false;rows=$rows;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 10; return }
Assert-O3F12 (Test-Path -LiteralPath $finalGatePath -PathType Leaf) 'O3F12 final package gate is absent.'
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-O3F12 ([string]$finalGate.state -eq 'PASS_O3F12_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O3F12 final package gate changed.'
$result.requestZipSha256 = [string]$finalGate.requestZipSha256
$result.requestManifestSha256 = [string]$finalGate.requestManifestSha256
$result.requestSignatureSha256 = [string]$finalGate.requestSignatureSha256
Write-O3F12Json $outputPath $result
$result | ConvertTo-Json -Depth 10
