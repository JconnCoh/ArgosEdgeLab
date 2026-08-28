#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight,[switch]$Gate)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Gate)){throw 'Specify exactly one of -Preflight or -Gate.'}
function Assert-True([bool]$Condition,[string]$Message){if(-not$Condition){throw $Message}}
function Get-Sha256([string]$Path){return(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}

$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$invocationPath=Join-Path $PSScriptRoot 'O3Q4_ROUTE_INVOCATION.json'
$finalGatePath=Join-Path $PSScriptRoot 'O3Q4_FINAL_PACKAGE_GATE.json'
$packageGatePath=Join-Path $PSScriptRoot 'O3Q4_EXACT_PACKAGE_REHEARSAL_GATE.json'
$workerPath=Join-Path $project 'work\OPENCV_OLS3\pkg\payload\W.ps1'
$configPath=Join-Path $project 'work\JBOD_ENDPOINT_ROOT_DIAGNOSTIC_C1F0\C1F0_LIVE_ENDPOINT_CONFIG.json'
$queueGatePath=Join-Path $project 'work\JBOD_ENDPOINT_MAINTENANCE_PATH_C1E\C1E_QUEUE_SAFETY_PASS.json'
$inheritedRoutePath=Join-Path $project 'work\OPENCV_SCRIBE_O2D23\O2D23_COMPLETE_ROUTE_GATE_R3.json'
$pathTool=Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$dependencies=@($invocationPath,$finalGatePath,$packageGatePath,$workerPath,$configPath,$queueGatePath,$inheritedRoutePath,$pathTool)
foreach($path in $dependencies){Assert-True(Test-Path -LiteralPath $path -PathType Leaf)"O3Q4 route dependency absent: $path"}
Assert-True((Get-Sha256 $invocationPath)-eq'DC32750FCAA65B03FFA9F838BF6D5BBD066CD1F36D063C651C128536C9C79058')'O3Q4 route invocation changed.'
Assert-True((Get-Sha256 $workerPath)-eq'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250')'O3Q4 endpoint worker changed.'
Assert-True((Get-Sha256 $configPath)-eq'465107D861E8D2C376A419B1C15841BE3A5757C6498C36CA56B9A95A2F0B76DB')'O3Q4 installed endpoint config evidence changed.'
Assert-True((Get-Sha256 $queueGatePath)-eq'170015C259C3EC8FC0B369F070748A555336F8FB312636819B7F99EBCE85A65D')'O3Q4 inherited queue gate changed.'
Assert-True((Get-Sha256 $inheritedRoutePath)-eq'04AC15694066C3CE4971DC946F77AF3CDB6814920CAB8B3DCCEA4CDCE4B535D3')'O3Q4 inherited complete route gate changed.'

$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
Assert-True([string]$invocation.schema-eq'argos_o3q4_route_invocation_v1'-and[string]$invocation.requestId-eq'REQ_20260828T152800444Z_62629419O3Q4')'O3Q4 route identity changed.'
Assert-True(@($invocation.paths).Count-eq53)'O3Q4 complete route path cardinality changed.'
$outputPath=[IO.Path]::GetFullPath([string]$invocation.outputPath)
Assert-True(-not(Test-Path -LiteralPath $outputPath))'O3Q4 complete route gate already exists.'
$finalGate=Get-Content -LiteralPath $finalGatePath -Raw|ConvertFrom-Json
$packageGate=Get-Content -LiteralPath $packageGatePath -Raw|ConvertFrom-Json
Assert-True([string]$finalGate.state-eq'PASS_O3Q4_FINAL_PACKAGE_GATE'-and[string]$finalGate.requestId-eq[string]$invocation.requestId-and[string]$finalGate.requestZipSha256-eq'648F5F8F278DA6BE3718386E0BC99EC043C41E77E7808101CB2214A5533F96F1')'O3Q4 final package gate changed.'
Assert-True([string]$packageGate.state-eq'PASS_O3Q4_EXACT_PACKAGE_REHEARSAL'-and[bool]$packageGate.exactPackagedEndpointPreflightPassed-and[bool]$packageGate.sourceAliasRemovedAfterTimeout)'O3Q4 exact package rehearsal gate changed.'
foreach($property in @('requestZipPath','requestManifestPath','requestSignaturePath')){$path=[IO.Path]::GetFullPath([string]$invocation.$property);Assert-True(Test-Path -LiteralPath $path -PathType Leaf)"O3Q4 exact route artifact absent: $path"}
Assert-True((Get-Sha256 ([string]$invocation.requestZipPath))-eq[string]$finalGate.requestZipSha256)'O3Q4 route ZIP changed.'
Assert-True((Get-Sha256 ([string]$invocation.requestManifestPath))-eq[string]$finalGate.requestManifestSha256)'O3Q4 route manifest changed.'
Assert-True((Get-Sha256 ([string]$invocation.requestSignaturePath))-eq[string]$finalGate.requestSignatureSha256)'O3Q4 route signature changed.'
Assert-True([bool]$invocation.exactFinalZipExtractionPassed-and[bool]$invocation.exactFinalZipSignaturePassed)'O3Q4 exact final ZIP qualification changed.'

$pathResult=& $pathTool -CandidatePath @($invocation.paths) -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson|ConvertFrom-Json
$rows=@($pathResult.candidates)
$nonPass=@($rows|Where-Object{[string]$_.disposition-ne'PASS_PATH_BUDGET'})
$canonicalBf='D:\KLARFExport\PatternedFront\Lot_62629-419_NotchBad_Hotspot\62629-419_20260824112405\Slot16\BrightfieldFrontsideWafer\resizedImage\62629-419_Slot16_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
$canonicalDf='D:\KLARFExport\PatternedFront\Lot_62629-419_NotchBad_Hotspot\62629-419_20260824112405\Slot16\DarkfieldFrontsideWafer\resizedImage\62629-419_Slot16_DarkfieldFrontsideWafer_PM2_resizedImage.bmp'
Assert-True($nonPass.Count-eq2)'O3Q4 route has an unexpected non-PASS path.'
foreach($row in $nonPass){Assert-True([string]$row.disposition-eq'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH')'O3Q4 route has a hard-stop path.';Assert-True(([string]$row.path-eq$canonicalBf)-or([string]$row.path-eq$canonicalDf))'O3Q4 unexpected path requires an alias.'}
$aliasRows=@($rows|Where-Object{([string]$_.path).StartsWith('F:\',[StringComparison]::OrdinalIgnoreCase)})
Assert-True($aliasRows.Count-eq2-and@($aliasRows|Where-Object{[string]$_.disposition-ne'PASS_PATH_BUDGET'}).Count-eq0)'O3Q4 exact source alias paths are unsafe.'
$actionRows=@($rows|Where-Object{([string]$_.path-ne$canonicalBf)-and([string]$_.path-ne$canonicalDf)})
$maximumActionEffective=[int](($actionRows|Measure-Object effectiveLength -Maximum).Maximum)
$maximumCanonicalEffective=[int](($rows|Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent=[int](($rows|Measure-Object longestComponentLength -Maximum).Maximum)
Assert-True($maximumActionEffective-lt200-and$maximumCanonicalEffective-lt230-and$maximumComponent-le80)'O3Q4 route path boundary changed.'

$result=[ordered]@{schema='argos_o3q4_complete_route_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3Q4_COMPLETE_ROUTE_GATE';requestId=[string]$invocation.requestId;jobClass='MAINTENANCE_PATCH';routePathRowsEvaluated=$rows.Count;reservedSuffixCharacters=32;maximumActionEffectiveLength=$maximumActionEffective;maximumCanonicalSourceEffectiveLength=$maximumCanonicalEffective;maximumComponentLength=$maximumComponent;canonicalSourcePathsRequiringAlias=2;verifiedShortSourceAlias='F:';shortSourceAliasPathsPassed=2;endpointCreatesAliasBeforeImageRead=$true;endpointRemovesAliasInFinally=$true;endpointWorkerSha256=Get-Sha256 $workerPath;installedConfigEvidenceSha256=Get-Sha256 $configPath;requestZipPath=[string]$invocation.requestZipPath;requestZipSha256=Get-Sha256 ([string]$invocation.requestZipPath);requestManifestSha256=Get-Sha256 ([string]$invocation.requestManifestPath);requestSignatureSha256=Get-Sha256 ([string]$invocation.requestSignaturePath);exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;exactPackageRehearsalGateSha256=Get-Sha256 $packageGatePath;inheritedCompleteRouteGateSha256=Get-Sha256 $inheritedRoutePath;inheritedQueueSafetyGateSha256=Get-Sha256 $queueGatePath;allRequestAndResponseHopsEnumerated=$true;compactFailureRouteEnumerated=$true;responseQuarantineRouteEnumerated=$true;laptopExtractionRouteEnumerated=$true;publicationAuthorized=$false;maximumPublications=1;retryAuthorized=$false;matchingSignedTerminalResponseCollectionOnly=$true;targetExecuted=$false;targetMutationsPerformed=$false;sourceImageBytesRead=$false;existingProcessQueryCount=0;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if($Preflight){$result.state='PASS_O3Q4_COMPLETE_ROUTE_PREFLIGHT';$result|ConvertTo-Json -Depth 8;return}
[IO.File]::WriteAllText($outputPath,(($result|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
$result|ConvertTo-Json -Depth 8
