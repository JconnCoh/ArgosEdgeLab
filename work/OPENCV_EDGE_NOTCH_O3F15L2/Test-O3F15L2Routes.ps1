#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Require([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Sha([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash}
function Required([object]$Object,[string]$Name){$property=$Object.PSObject.Properties[$Name];if($null-eq$property){throw "O3F15L2 required route property absent: $Name"};$property.Value}
function New-Json([string]$Path,[object]$Value){Require (-not(Test-Path -LiteralPath $Path)) "O3F15L2 create-new route gate exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 20)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$contractPath=Join-Path $PSScriptRoot 'O3F15L2_LAUNCH_CONTRACT.json'
$signGatePath=Join-Path $PSScriptRoot 'O3F15L2_SIGN_GATE.json'
$finalRoot=Join-Path $PSScriptRoot 'final_o3f15l2'
$outputPath=Join-Path $finalRoot 'O3F15L2_PREPUBLICATION_PATH_GATE.json'
foreach($path in @($contractPath,$signGatePath)){Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L2 route dependency absent: $path"}
$contract=Get-Content -LiteralPath $contractPath -Raw|ConvertFrom-Json
$signGate=Get-Content -LiteralPath $signGatePath -Raw|ConvertFrom-Json
Require ([string]$contract.schema-eq'argos_ocv03_o3f15l2_launch_contract_v1'-and[string]$contract.state-eq'FROZEN_FOR_BUILD') 'O3F15L2 route contract is not frozen.'
Require ([string]$signGate.state-eq'PASS_O3F15L2_SIGNED_EXACT_978_FRONT_LAUNCH_PACKAGE') 'O3F15L2 route sign gate changed.'
Require ([IO.Path]::GetFullPath([string]$signGate.finalRoot)-eq[IO.Path]::GetFullPath($finalRoot)-and[IO.Path]::GetDirectoryName([IO.Path]::GetFullPath([string]$signGate.packageZipPath))-eq[IO.Path]::GetFullPath($finalRoot)) 'O3F15L2 final ZIP is not in the path-gate directory.'
$requestId=[string]$signGate.requestId
$readyName=$requestId+'.ready'
$zipName=$requestId+'.ready.zip'
$responseName='R_0123456789AB_20260903235959999_a1b2c3d4.ready'
$route=Required $contract 'routeBudget'
Require ([int](Required $contract 'expectedPairCount')-eq978-and[int](Required $route 'canonicalSourceLeafCount')-eq1956-and[int](Required $route 'aliasSourceLeafCount')-eq1956) 'O3F15L2 route source cardinality changed.'
$suffixReserve=[int](Required $route 'pathSuffixReserve')
$maximumCanonicalLength=[int](Required $route 'maximumCanonicalSourcePathLength')
$maximumAliasLength=[int](Required $route 'maximumAliasSourcePathLength')
$maximumCanonicalEffectiveLength=[int](Required $route 'maximumCanonicalSourceEffectiveLength')
$maximumAliasEffectiveLength=[int](Required $route 'maximumAliasSourceEffectiveLength')
$maximumGeneratedComponentLength=[int](Required $route 'maximumGeneratedComponentLength')
$maximumCorpusPathLength=[int](Required $route 'maximumCorpusPathLength')
$maximumCorpusEffectivePathLength=[int](Required $route 'maximumCorpusEffectivePathLength')
$representativeCanonical=[string](Required $route 'representativeCanonicalSourcePath')
$representativeAlias=[string](Required $route 'representativeAliasSourcePath')
$maximumRuntimeRelative=[string](Required $route 'maximumRuntimeRelativeLeaf')
$maximumGateRelative=[string](Required $route 'maximumGateRelativeLeaf')
$maximumCorpusRelative=[string](Required $route 'maximumCorpusBoundaryLeaf')
$maximumMirrorRelative=[string](Required $route 'maximumMirrorRelativeLeaf')
$runFixedLeafCount=[int](Required $route 'runFixedLeafCount')
$runPerCaseLeafCount=[int](Required $route 'runPerCaseLeafCount')
$runCaseCount=[int](Required $route 'caseCount')
$runEnumeratedLeafCount=[int](Required $route 'runEnumeratedLeafCount')
$mirrorFinalLeafCount=[int](Required $route 'mirrorFinalLeafCount')
$maximumMirrorLeafBytesExclusive=[int64](Required $route 'maximumMirrorLeafBytesExclusive')
Require ($suffixReserve-eq32-and$maximumCanonicalLength-eq197-and$maximumAliasLength-eq167-and$maximumCanonicalEffectiveLength-eq229-and$maximumAliasEffectiveLength-eq199) 'O3F15L2 source path hard bounds changed.'
Require ($maximumCanonicalEffectiveLength-eq($maximumCanonicalLength+$suffixReserve)-and$maximumAliasEffectiveLength-eq($maximumAliasLength+$suffixReserve)-and$maximumGeneratedComponentLength-le80) 'O3F15L2 path reserve/component arithmetic changed.'
Require ($representativeCanonical.Replace('\','/').StartsWith('D:/KLARFExport/',[StringComparison]::OrdinalIgnoreCase)-and$representativeAlias.Replace('\','/').StartsWith('Q:/',[StringComparison]::OrdinalIgnoreCase)) 'O3F15L2 representative source route roots changed.'
Require ($representativeCanonical.Length-le$maximumCanonicalLength-and$representativeAlias.Length-le$maximumAliasLength) 'O3F15L2 representative source path exceeded its declared hard bound.'
Require ($runFixedLeafCount-eq10-and$runPerCaseLeafCount-eq16-and$runCaseCount-eq978-and$runEnumeratedLeafCount-eq($runFixedLeafCount+($runPerCaseLeafCount*$runCaseCount))-and$runEnumeratedLeafCount-eq15658) 'O3F15L2 RUN leaf accounting changed.'
Require ($maximumCorpusPathLength-eq105-and$maximumCorpusEffectivePathLength-eq137-and$maximumCorpusEffectivePathLength-eq($maximumCorpusPathLength+$suffixReserve)-and[string](Required $route 'maximumGeneratedLeaf')-eq('D:/O3F15C/'+$maximumCorpusRelative.TrimStart('/','\'))) 'O3F15L2 corpus path hard bound changed.'
Require ($mirrorFinalLeafCount-eq4-and$maximumMirrorLeafBytesExclusive-eq2097152-and[string](Required $route 'maximumAliasLeaf')-eq$representativeAlias-and[string](Required $route 'maximumMirrorRelativeLeaf')-eq'TERMINAL_FAILURE.json.partial') 'O3F15L2 result/mirror maximum contract changed.'
$inheritedRoute=Required $contract 'inheritedRoute'
Require ([string](Required $inheritedRoute 'endpointWorkerSha256')-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'-and[string](Required $inheritedRoute 'installedRouteConfigEvidenceSha256')-eq'465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB'-and[string](Required $inheritedRoute 'queueSafetyGateSha256')-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D'-and-not[bool](Required $inheritedRoute 'routeImplementationChanged')) 'O3F15L2 inherited portal route pins changed.'

$packagePath=[string]$signGate.packagePath
$manifestPath=Join-Path $packagePath 'PORTAL_REQUEST_MANIFEST.json'
Require (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O3F15L2 signed manifest absent.'
$manifest=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
Require ([string]$manifest.requestId-eq$requestId-and@($manifest.files).Count-eq[int]$signGate.payloadFileCount) 'O3F15L2 signed route manifest changed.'
$paths=New-Object Collections.Generic.List[string]
$paths.Add([string]$signGate.packageZipPath)
$paths.Add($outputPath)
foreach($path in @(
    "U:/ProjectPortalRO/requests/$zipName.upload","U:/ProjectPortalRO/requests/$zipName",
    "C:/APR/S/requests/$zipName","C:/APR/S/requests/processed/$zipName",
    "C:/ProgramData/ArgosProjectPortalRO/share/staging/$zipName","C:/ProgramData/ArgosProjectPortalRO/share/request_archive/$zipName",
    "C:/ProgramData/ArgosProjectPortalRO/requests_to_argos/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/requests_from_gateway/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_jbod/pending/$readyName/PORTAL_REQUEST_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_jbod/sent/$readyName/PORTAL_REQUEST_MANIFEST.json",
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
    ('D:/O3F15RT/'+$maximumRuntimeRelative.TrimStart('/','\')),
    ('D:/O3F15G/'+$maximumGateRelative.TrimStart('/','\')),
    ('D:/O3F15C/'+$maximumCorpusRelative.TrimStart('/','\')),
    ('D:/KLARFExport/_ArgosReview/F15S/'+$maximumMirrorRelative.TrimStart('/','\')),
    $representativeAlias,
    "C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/state/response_quarantine/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName.partial/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/pending/$responseName/MAINTENANCE.stdout.txt",
    "C:/ProgramData/ArgosProjectPortalRO/to_argos/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/from_jbod/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/to_gateway/sent/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/APR/R/pending/$responseName/PORTAL_RESPONSE_MANIFEST.json","C:/APR/A/$responseName/PORTAL_RESPONSE_MANIFEST.json",
    "C:/ProgramData/ArgosProjectPortalRO/share/response_zip_archive/$responseName.zip",
    "U:/ProjectPortalRO/responses/$responseName.zip","C:/O3F15L2C/$responseName.zip",
    "C:/O3F15L2C/$responseName/PORTAL_RESPONSE_MANIFEST.json","C:/O3F15L2C/$responseName/MAINTENANCE.stdout.txt"
)){$paths.Add([string]$path)}
foreach($record in @($manifest.files)){$paths.Add("C:/ProgramData/ArgosProjectPortalRO/endpoint_jbod/pending/$readyName/$([string]$record.path)")}
foreach($record in @($contract.payloadFiles|Where-Object{[bool]$_.copyToRuntime})){$paths.Add('D:/O3F15RT/'+[string]$record.name)}
$actionable=@($paths.ToArray()|Sort-Object -Unique)
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$actionableGate=& $pathTool -CandidatePath $actionable -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
Require ([string]$actionableGate.state-eq'PASS_PATH_BUDGET'-and@($actionableGate.candidates).Count-eq$actionable.Count) 'O3F15L2 actionable route path gate failed.'
$canonicalJson=@(& (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -NoProfile -ExecutionPolicy Bypass -File $pathTool -CandidatePath $representativeCanonical -ReservedSuffixCharacters $suffixReserve -AsJson 2>$null)-join[Environment]::NewLine
$canonicalExit=$LASTEXITCODE
$canonicalGate=$canonicalJson|ConvertFrom-Json
Require ($canonicalExit-le1-and[string]$canonicalGate.state-in@('PASS_PATH_BUDGET','SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH')) 'O3F15L2 representative canonical source path crossed a hard path stop.'
$longest=@($actionableGate.candidates|Sort-Object effectiveLength -Descending|Select-Object -First 1)[0]
$componentMaximum=[int](($actionableGate.candidates|Measure-Object longestComponentLength -Maximum).Maximum)
Require ($componentMaximum-le80-and[int]$longest.effectiveLength-lt200) 'O3F15L2 actionable route path/component maximum changed.'
$result=[ordered]@{schema='argos_ocv03_o3f15l2_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=$(if($Preflight){'PASS_O3F15L2_COMPLETE_ROUTE_PREFLIGHT'}else{'PASS_O3F15L2_SIGNED_AND_PATH_GATED'});requestId=$requestId;finalRoot=$finalRoot;packageZipPath=[string]$signGate.packageZipPath;pathGatePath=$outputPath;packageZipAndPathGateAdjacent=$true;packageZipSha256=[string]$signGate.packageZipSha256;requestManifestSha256=[string]$signGate.manifestSha256;requestSignatureSha256=[string]$signGate.signatureSha256;jobClass='MAINTENANCE_PATCH';reservedSuffixCharacters=$suffixReserve;compactRouteAccounting=$true;actionablePathCount=$actionable.Count;maximumActionableEffectiveLength=[int]$longest.effectiveLength;maximumActionableComponentLength=$componentMaximum;longestActionablePath=[string]$longest.path;representativeCanonicalSourcePath=$representativeCanonical;representativeCanonicalDisposition=[string]$canonicalGate.state;representativeCanonicalEffectiveLength=[int]@($canonicalGate.candidates)[0].effectiveLength;declaredMaximumCanonicalSourcePathLength=$maximumCanonicalLength;declaredMaximumCanonicalSourceEffectiveLength=$maximumCanonicalEffectiveLength;representativeAliasSourcePath=$representativeAlias;declaredMaximumAliasSourcePathLength=$maximumAliasLength;declaredMaximumAliasSourceEffectiveLength=$maximumAliasEffectiveLength;declaredMaximumCorpusPathLength=$maximumCorpusPathLength;declaredMaximumCorpusEffectivePathLength=$maximumCorpusEffectivePathLength;declaredMaximumGeneratedComponentLength=$maximumGeneratedComponentLength;sourcePairCount=978;canonicalSourceLeafCount=1956;aliasSourceLeafCount=1956;runFixedLeafCount=$runFixedLeafCount;runPerCaseLeafCount=$runPerCaseLeafCount;runCaseCount=$runCaseCount;runEnumeratedLeafCount=$runEnumeratedLeafCount;runtimeRoot='D:/O3F15RT';gateRoot='D:/O3F15G';corpusRoot='D:/O3F15C';portalReadableMirrorRoot='D:/KLARFExport/_ArgosReview/F15S';maximumRuntimeRelativeLeaf=$maximumRuntimeRelative;maximumGateRelativeLeaf=$maximumGateRelative;maximumCorpusBoundaryLeaf=$maximumCorpusRelative;maximumMirrorRelativeLeaf=$maximumMirrorRelative;mirrorFinalLeafCount=$mirrorFinalLeafCount;maximumMirrorLeafBytesExclusive=$maximumMirrorLeafBytesExclusive;endpointWorkerSha256=[string]$inheritedRoute.endpointWorkerSha256;installedRouteConfigEvidenceSha256=[string]$inheritedRoute.installedRouteConfigEvidenceSha256;queueSafetyGateSha256=[string]$inheritedRoute.queueSafetyGateSha256;routeImplementationChanged=$false;observedFull978SourceMaximaAvailableLaptopSide=$false;actualSourceAndOutputPlansValidatedByRunnerPreflight=$true;payloadFileCount=@($manifest.files).Count;runtimeCopyFileCount=@($contract.payloadFiles|Where-Object{[bool]$_.copyToRuntime}).Count;maximumResultBytes=[int64]$manifest.maxResultBytes;matchingSignedTerminalResponseRequired=$true;gatewayAcceptanceIsExecutionEvidence=$false;requestRetryAuthorized=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result|ConvertTo-Json -Depth 10;return}
New-Json $outputPath $result
$result|ConvertTo-Json -Depth 10
