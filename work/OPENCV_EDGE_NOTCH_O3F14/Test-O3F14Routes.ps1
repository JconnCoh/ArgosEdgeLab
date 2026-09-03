#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }
function Assert-O3F14([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-O3F14Hash([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-O3F14TextSha256([string]$Value) { $algorithm=[Security.Cryptography.SHA256]::Create(); try { return [BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value))).Replace('-','').ToLowerInvariant() } finally { $algorithm.Dispose() } }
function Get-O3F14SafeId([string]$Identity) { $clean=[regex]::Replace($Identity,'[^A-Za-z0-9_.-]+','_').Trim([char[]]@('_','.')); $suffix=(Get-O3F14TextSha256 $Identity).Substring(0,10); if([string]::IsNullOrWhiteSpace($clean)){return $suffix}; $prefix=$(if($clean.Length-gt42){$clean.Substring(0,42)}else{$clean}); return ($prefix+'_'+$suffix) }
function Write-O3F14Json([string]$Path, [object]$Value) { Assert-O3F14 (-not (Test-Path -LiteralPath $Path)) "O3F14 route gate exists: $Path"; [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false))) }
function Get-O3F14RegexRoots([string]$Text,[string]$Pattern) { return @([regex]::Matches($Text,$Pattern)|ForEach-Object{$_.Groups[1].Value}|Sort-Object -Unique) }
function Test-O3F14ExactSet([object[]]$Actual,[object[]]$Expected) { return ([string]::Join('|',@($Actual|Sort-Object -Unique)) -ceq [string]::Join('|',@($Expected|Sort-Object -Unique))) }
function Confirm-O3F14SupplementalCloneRoots([string]$Project,[string]$ManifestPath,[string]$GatePath) {
    foreach($path in @($ManifestPath,$GatePath)){Assert-O3F14 (Test-Path -LiteralPath $path -PathType Leaf) "O3F14 supplemental clone dependency is absent: $path"}
    $manifest=Get-Content -LiteralPath $ManifestPath -Raw|ConvertFrom-Json
    $cloneGate=Get-Content -LiteralPath $GatePath -Raw|ConvertFrom-Json
    Assert-O3F14 ([bool]$manifest.forwardSlashRootAccountingComplete -and -not[bool]$manifest.diagnosticDiffSource.futureReuseAllowed -and -not[bool]$manifest.diagnosticDiffSource.publicationParentAllowed -and [bool]$manifest.diagnosticDiffSource.provenSourceStructureCloneAllowed) 'O3F14 clone authority accounting changed.'
    Assert-O3F14 ([string]$cloneGate.state -eq 'PASS_ARGOS_CLONE_LITERAL_REMEDIATION' -and [string]$cloneGate.mode -eq 'GATE' -and [string]$cloneGate.manifestSha256 -eq (Get-O3F14Hash $ManifestPath)) 'O3F14 generic clone gate is absent or stale.'
    $forwardCount=0;$bareCount=0
    foreach($pair in @($manifest.pairs)) {
        $sourcePath=Join-Path $Project ([string]$pair.source);$generatedPath=Join-Path $Project ([string]$pair.generated)
        $source=Get-Content -LiteralPath $sourcePath -Raw;$generated=Get-Content -LiteralPath $generatedPath -Raw
        $gatePair=@($cloneGate.pairs|Where-Object{[string]$_.source-ceq[string]$pair.source-and[string]$_.generated-ceq[string]$pair.generated})
        Assert-O3F14 ($gatePair.Count-eq1-and[string]$gatePair[0].sourceSha256-eq(Get-O3F14Hash $sourcePath)-and[string]$gatePair[0].generatedSha256-eq(Get-O3F14Hash $generatedPath)) "O3F14 generic clone pair hash changed: $($pair.generated)"
        foreach($kind in @(
            [pscustomobject]@{name='forwardSlashRootRules';pattern='(?i)(?<![A-Z0-9_])([A-Z]:/(?:[A-Z0-9_.-]+)?)'},
            [pscustomobject]@{name='bareDriveRootRules';pattern='(?i)(?<![A-Z0-9_])([A-Z]:)(?![\\/])'}
        )) {
            Assert-O3F14 ($pair.PSObject.Properties.Name -contains [string]$kind.name) "O3F14 supplemental root rule set is absent: $($pair.generated) $($kind.name)"
            $rules=@($pair.([string]$kind.name));$sourceRoots=Get-O3F14RegexRoots $source ([string]$kind.pattern);$generatedRoots=Get-O3F14RegexRoots $generated ([string]$kind.pattern)
            $declaredSource=@($rules|ForEach-Object{[string]$_.sourceRoot});$declaredGenerated=@($rules|ForEach-Object{[string]$_.generatedRoot})
            Assert-O3F14 (Test-O3F14ExactSet $sourceRoots $declaredSource) "O3F14 supplemental source-root set changed: $($pair.generated) $($kind.name)"
            Assert-O3F14 (Test-O3F14ExactSet $generatedRoots $declaredGenerated) "O3F14 supplemental generated-root set changed: $($pair.generated) $($kind.name)"
            foreach($rule in $rules) {
                $from=[string]$rule.sourceRoot;$to=[string]$rule.generatedRoot;$disposition=[string]$rule.disposition
                if($disposition-eq'REPLACED'){Assert-O3F14 ($from-cne$to-and$sourceRoots-ccontains$from-and$generatedRoots-ccontains$to-and$generatedRoots-cnotcontains$from) "O3F14 supplemental replacement failed: $($pair.generated) $from"}
                elseif($disposition-eq'UNCHANGED_ALLOWED'){Assert-O3F14 ($from-ceq$to-and$sourceRoots-ccontains$from-and$generatedRoots-ccontains$to) "O3F14 supplemental unchanged root failed: $($pair.generated) $from"}
                else{throw "O3F14 supplemental disposition changed: $($pair.generated) $disposition"}
            }
            if([string]$kind.name-eq'forwardSlashRootRules'){$forwardCount+=$rules.Count}else{$bareCount+=$rules.Count}
        }
    }
    return [ordered]@{manifest=$ManifestPath.Replace('\\','/');manifestSha256=Get-O3F14Hash $ManifestPath;genericGate=$GatePath.Replace('\\','/');genericGateSha256=Get-O3F14Hash $GatePath;pairCount=@($manifest.pairs).Count;forwardSlashRuleCount=$forwardCount;bareDriveRuleCount=$bareCount;exactSetsVerified=$true;dispositionsVerified=$true}
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$cloneRootAccounting=@(
    (Confirm-O3F14SupplementalCloneRoots $project (Join-Path $PSScriptRoot 'O3F14_CLONE_LITERAL_REMEDIATION.json') (Join-Path $PSScriptRoot 'O3F14_CLONE_LITERAL_GATE_R3.json')),
    (Confirm-O3F14SupplementalCloneRoots $project (Join-Path $PSScriptRoot 'O3F14_PORTAL_CLONE_LITERAL_REMEDIATION.json') (Join-Path $PSScriptRoot 'O3F14_PORTAL_CLONE_LITERAL_GATE_R4.json'))
)
$specPath = Join-Path $PSScriptRoot 'O3F14_PACKAGE_SPEC.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$finalGatePath = Join-Path $PSScriptRoot 'O3F14_FINAL_PACKAGE_GATE.json'
$outputPath = Join-Path (Join-Path $PSScriptRoot 'final_o3f14') 'O3F14_PREPUBLICATION_PATH_GATE.json'
$spec = Get-Content -LiteralPath $specPath -Raw | ConvertFrom-Json
$requestId = [string]$spec.requestId
$readyName = [string]$spec.requestReadyName
$zipName = $readyName + '.zip'
$responseName = 'R_0123456789AB_20260902235959999_a1b2c3d4.ready'
$payloadLeaves = @('Invoke-O3F14StagedEndpoint.ps1','Run-O3F14Staged.py','Run-O3F8Staged.py','FullPerimeterWaferTopologyOpenCvR11.py','FullPerimeterWaferTopologyOpenCvR10.py','FullPerimeterWaferTopologyOpenCvR9.py','FullPerimeterWaferTopologyOpenCvR8.py','Detect-O3P8FrontSplitNotches.py','Test-O3F14R11SeedAngles.py','O3P8_POST2_SHORT_ALIAS_JOB.json','O3M9_SLOT16_JOB.json','OCV03_NotchReviewOpenCvV1.py','O3F14FixtureRunner.py','O3F14RootContractProbe.py','O3F12_DEV6_SOURCE_ALIAS_PLAN.json','O3F14_ENDPOINT_LIVE_INVOCATION.json')
$aliasPlanPath = Join-Path $project ([string]$spec.sourceAliasPlanSource)
$aliasPlan = Get-Content -LiteralPath $aliasPlanPath -Raw | ConvertFrom-Json
Assert-O3F14 ((Get-O3F14Hash $aliasPlanPath) -eq [string]$spec.sourceAliasPlanSha256 -and [string]$aliasPlan.state -eq 'FROZEN_FOR_BUILD' -and [int]$aliasPlan.caseCount -eq 6 -and [int]$aliasPlan.sourceLeafCount -eq 12) 'O3F14 route source-alias plan changed.'
$canonicalSources = @($aliasPlan.cases | ForEach-Object { @($_.sources) | ForEach-Object { [string]$_.canonicalPath } })
$aliasSources = @($aliasPlan.cases | ForEach-Object { @($_.sources) | ForEach-Object { [string]$_.aliasPath } })
Assert-O3F14 ($canonicalSources.Count -eq 12 -and $aliasSources.Count -eq 12 -and @($canonicalSources | Sort-Object -Unique).Count -eq 12 -and @($aliasSources | Sort-Object -Unique).Count -eq 12) 'O3F14 route source path cardinality changed.'
$safeIdRows = New-Object Collections.Generic.List[object]
$exactDev6Leaves = New-Object Collections.Generic.List[string]
foreach($devRoot in @('D:/O3F9D14','D:/O3F9D14.failed')) {
    $exactDev6Leaves.Add("$devRoot/SUMMARY.json.partial")
    foreach($case in @($aliasPlan.cases)) {
        $ordinal=[int]$case.ordinal
        $identity=([string]$case.identity).Replace('/','\')
        $safeId=Get-O3F14SafeId $identity
        $stem=$safeId.ToLowerInvariant().Replace('-','')
        $digest=(Get-O3F14TextSha256 $safeId).Substring(0,16)
        $caseRoot=("$devRoot/cases/C{0:D4}" -f $ordinal)
        if($devRoot-eq'D:/O3F9D14'){$safeIdRows.Add([pscustomobject]@{ordinal=$ordinal;identity=$identity;safeId=$safeId;stem=$stem;digest=$digest})}
        $exactDev6Leaves.Add(("$devRoot/jobs/J{0:D4}.json.partial" -f $ordinal))
        $exactDev6Leaves.Add(("$devRoot/jobs/J{0:D4}.json" -f $ordinal))
        $exactDev6Leaves.Add(("$devRoot/C{0:D4}.stdout.txt" -f $ordinal))
        $exactDev6Leaves.Add(("$devRoot/C{0:D4}.stderr.txt" -f $ordinal))
        $exactDev6Leaves.Add("$caseRoot/MANIFEST.json.partial")
        $exactDev6Leaves.Add("$caseRoot/MANIFEST.json")
        $exactDev6Leaves.Add("$caseRoot/${stem}_bf_overview.png")
        $exactDev6Leaves.Add("$caseRoot/${stem}_df_overview.png")
        foreach($candidateIndex in 1..24) {
            $candidateTag=('c{0:D2}' -f $candidateIndex)
            foreach($suffix in @('clean.png','enhanced.png','overlay.png','mask.png')) {
                $exactDev6Leaves.Add("$caseRoot/${stem}_bf_${candidateTag}_$suffix")
                $exactDev6Leaves.Add("$caseRoot/${stem}_df_${candidateTag}_$suffix")
            }
        }
        foreach($suffix in @('clean.png','enhanced.png','overlay.png','mask.png')) {
            $exactDev6Leaves.Add("$caseRoot/${digest}_bf_o3p8_recovery_$suffix")
            $exactDev6Leaves.Add("$caseRoot/${digest}_df_r10_recovery_$suffix")
        }
    }
}
$safeIds=$safeIdRows.ToArray()
Assert-O3F14 ($safeIds.Count-eq6-and@($safeIds.safeId|Sort-Object -Unique).Count-eq6-and[string]$safeIds[4].safeId-eq'PatternedFront_Lot_62616-131_62616-131_202_aae0de7fdf') 'O3F14 exact O3F6 safe-ID derivation changed.'
$exactGateLeaves=@('SUMMARY.json.partial','R11_SEED_ANGLE_GATE.json','LOCAL.stdout.txt','LOCAL.stderr.txt','INHERITED.stdout.txt','INHERITED.stderr.txt','R11_INHERITED_SYNTHETIC/upper_right_315_df_c01_clean.png','R11_INHERITED_SYNTHETIC/upper_right_315_df_c01_enhanced.png','R11_INHERITED_SYNTHETIC/upper_right_315_df_c01_overlay.png','R11_INHERITED_SYNTHETIC/upper_right_315_df_c01_mask.png','R11_INHERITED_SYNTHETIC/SYNTHETIC_GATE.json.partial','R11_INHERITED_SYNTHETIC/SYNTHETIC_GATE.json')|ForEach-Object{"D:/O3F9G14/$_","D:/O3F9G14.failed/$_"}
$paths = New-Object Collections.Generic.List[string]
foreach ($leaf in $payloadLeaves) { $paths.Add("C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending/$readyName/payload/$leaf") }
foreach($leaf in $exactGateLeaves){$paths.Add([string]$leaf)}
foreach($leaf in $exactDev6Leaves.ToArray()){$paths.Add([string]$leaf)}
foreach ($path in @(
    (Join-Path $project "work/OPENCV_EDGE_NOTCH_O3F14/final_o3f14/$zipName"),
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
    'D:/O3F9G14/SUMMARY.json', 'D:/O3F9G14.failed/SUMMARY.json',
    'D:/O3F9D14/SUMMARY.json', 'D:/O3F9D14.failed/SUMMARY.json',
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/response_quarantine/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/MAINTENANCE.stdout.txt",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/from_jbod/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/APR/R/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/APR/A/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/share/response_zip_archive/$responseName.zip",
    "U:/ProjectPortalRO/responses/$responseName.zip", "C:/A14C/$responseName.zip",
    "C:/A14C/$responseName/PORTAL_RESPONSE_MANIFEST.json", "C:/A14C/$responseName/MAINTENANCE.stdout.txt"
)) { $paths.Add([string]$path) }
$pathRows = New-Object Collections.Generic.List[object]
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$plannedGate=& $pathTool -CandidatePath @($paths.ToArray()) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Assert-O3F14 ([string]$plannedGate.state-eq'PASS_PATH_BUDGET'-and@($plannedGate.candidates).Count-eq$paths.Count) 'O3F14 complete planned path batch failed.'
foreach($row in @($plannedGate.candidates)){$pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state=[string]$row.disposition})}
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
Assert-O3F14 (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) 'O3F14 Windows PowerShell 5.1 path gate host is absent.'
foreach ($path in $canonicalSources) {
    $json = @(& $windowsPowerShell -NoProfile -ExecutionPolicy Bypass -File $pathTool -CandidatePath $path -ReservedSuffixCharacters 32 -AsJson 2>$null) -join [Environment]::NewLine
    $exit = $LASTEXITCODE
    $one = $json | ConvertFrom-Json
    Assert-O3F14 ($exit -eq 1 -and [string]$one.state -eq 'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH') "O3F14 canonical source did not require its frozen alias: $path"
    $row = @($one.candidates)[0]
    Assert-O3F14 ([int]$row.effectiveLength -ge 200 -and [int]$row.effectiveLength -lt 230 -and [int]$row.longestComponentLength -le 80) "O3F14 canonical source crossed an unhandled path boundary: $path"
    $pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state='CANONICAL_PROVENANCE_SHORT_ALIAS_REQUIRED'})
}
    $aliasGate=& $pathTool -CandidatePath @($aliasSources) -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
    Assert-O3F14 ([string]$aliasGate.state-eq'PASS_PATH_BUDGET'-and@($aliasGate.candidates).Count-eq12) 'O3F14 actionable source alias path batch failed.'
foreach ($row in @($aliasGate.candidates)) {
    $pathRows.Add([pscustomobject]@{path=[string]$row.path;effectiveLength=[int]$row.effectiveLength;longestComponentLength=[int]$row.longestComponentLength;state='ACTIONABLE_TEMPORARY_Q_ALIAS_PASS'})
}
$rows = $pathRows.ToArray()
Assert-O3F14 ($rows.Count -eq 2602 -and @($rows.path | Sort-Object -Unique).Count -eq $rows.Count) "O3F14 complete route cardinality changed: $($rows.Count)."
$longest = @($rows | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$actionableLongest = @($rows | Where-Object { $_.state -ne 'CANONICAL_PROVENANCE_SHORT_ALIAS_REQUIRED' } | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
$result = [ordered]@{schema='argos_ocv03_o3f14_complete_route_gate_v1';state=$(if($Preflight){'PASS_O3F14_COMPLETE_ROUTE_PREFLIGHT'}else{'PASS_O3F14_COMPLETE_ROUTE_GATE'});requestId=$requestId;jobClass='MAINTENANCE_PATCH';routePathRowsEvaluated=$rows.Count;reservedSuffixCharacters=32;maximumPlannedEffectiveLength=[int]$longest.effectiveLength;maximumActionableEffectiveLength=[int]$actionableLongest.effectiveLength;maximumPlannedComponentLength=[int](($rows|Measure-Object longestComponentLength -Maximum).Maximum);longestPath=[string]$longest.path;longestActionablePath=[string]$actionableLongest.path;canonicalAliasRequiredCount=12;actionableAliasPassCount=12;sourceAliasPlanSha256=Get-O3F14Hash $aliasPlanPath;safeIdAlgorithm='REGEX_CLEAN_PREFIX42_PLUS_SHA256_UTF8_PREFIX10';dev6SafeIds=$safeIds;exactGateOutputLeafCount=@($exactGateLeaves).Count;exactDev6OutputLeafCount=$exactDev6Leaves.Count;maximumCandidateCountPerChannel=24;candidateAssetSuffixCount=4;partialAndFinalJsonLeavesIncluded=$true;cloneRootAccounting=$cloneRootAccounting;payloadLeaves=$payloadLeaves;maximumResultBytes=[int64]$spec.maximumPortalResultBytes;endpointWorkerSha256=[string]$spec.inheritedRoute.endpointWorkerSha256;installedConfigEvidenceSha256=[string]$spec.inheritedRoute.installedRouteConfigEvidenceSha256;inheritedQueueSafetyGateSha256=[string]$spec.inheritedRoute.queueSafetyGateSha256;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;requestRetryAuthorized=$false;rows=$rows;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 10; return }
Assert-O3F14 (Test-Path -LiteralPath $finalGatePath -PathType Leaf) 'O3F14 final package gate is absent.'
$finalGate = Get-Content -LiteralPath $finalGatePath -Raw | ConvertFrom-Json
Assert-O3F14 ([string]$finalGate.state -eq 'PASS_O3F14_FINAL_PACKAGE_GATE' -and [string]$finalGate.requestId -eq $requestId) 'O3F14 final package gate changed.'
$result.requestZipSha256 = [string]$finalGate.requestZipSha256
$result.requestManifestSha256 = [string]$finalGate.requestManifestSha256
$result.requestSignatureSha256 = [string]$finalGate.requestSignatureSha256
Write-O3F14Json $outputPath $result
$result | ConvertTo-Json -Depth 10
