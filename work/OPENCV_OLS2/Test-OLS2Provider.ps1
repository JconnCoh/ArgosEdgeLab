[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [Parameter(Mandatory=$true)][string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Test)){throw 'Specify exactly one of -Preflight or -Test.'}

$invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
$invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
if([string]$invocation.schema-ne'argos_ols2_provider_test_invocation_v1'-or-not[bool]$invocation.reviewOnly-or[bool]$invocation.productionRoutingEnabled){throw 'OLS2 provider test invocation contract failed.'}
$testRoot=[IO.Path]::GetFullPath([string]$invocation.testRoot)
$dataRoot=[IO.Path]::GetFullPath([string]$invocation.dataRoot)
$gatePath=[IO.Path]::GetFullPath([string]$invocation.gatePath)
$workerPath=[IO.Path]::GetFullPath([string]$invocation.workerPath)
$workerSha256=[string]$invocation.workerSha256
$utf8=New-Object Text.UTF8Encoding($false)

function Assert-PathBudget {
    param([string]$Path,[int]$Reserve=32)
    $full=[IO.Path]::GetFullPath($Path)
    $components=@($full.Split(@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))
    $maximumComponent=if($components.Count){[int](($components|Measure-Object Length -Maximum).Maximum)}else{0}
    if(($full.Length+$Reserve)-ge200-or$maximumComponent-gt80){throw "OLS2 provider test path budget failed: $full"}
    return $full
}
function Assert-AliasedSourceBudget {
    param([string]$CanonicalPath,[string]$AliasPath)
    $canonical=[IO.Path]::GetFullPath($CanonicalPath)
    $alias=[IO.Path]::GetFullPath($AliasPath)
    $canonicalComponents=@($canonical.Split(@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))
    $aliasComponents=@($alias.Split(@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))
    $canonicalMaximum=if($canonicalComponents.Count){[int](($canonicalComponents|Measure-Object Length -Maximum).Maximum)}else{0}
    $aliasMaximum=if($aliasComponents.Count){[int](($aliasComponents|Measure-Object Length -Maximum).Maximum)}else{0}
    if(($canonical.Length+32)-ge230-or$canonicalMaximum-gt80-or($alias.Length+32)-ge200-or$aliasMaximum-gt80){throw 'OLS2 provider aliased source path budget failed.'}
}
function Write-JsonCreateNew {
    param([string]$Path,$Value)
    if(Test-Path -LiteralPath $Path){throw "OLS2 provider test refuses overwrite: $Path"}
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent)}
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 30),$utf8)
}
function Assert-True {
    param([bool]$Condition,[string]$Message)
    if(-not$Condition){throw $Message}
}
function Invoke-WorkerJson {
    param([string]$ConfigPath,[string]$ProbePath,[switch]$WorkerPreflight,[switch]$ExpectFailure)
    $exe="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$workerPath,'-ConfigPath',$ConfigPath)
    if($WorkerPreflight){$arguments+='-Preflight'}
    $arguments+=@('-EnvironmentProbeManifest',$ProbePath)
    $priorPreference=$ErrorActionPreference
    try{
        $ErrorActionPreference='Continue'
        $text=& $exe @arguments 2>&1|Out-String
        $exitCode=$LASTEXITCODE
    }finally{$ErrorActionPreference=$priorPreference}
    if($ExpectFailure){return [pscustomobject]@{exitCode=$exitCode;text=$text}}
    if($exitCode-ne0){throw "OLS2 provider worker failed with exit code $exitCode. $text"}
    try{return ($text|ConvertFrom-Json)}catch{throw "OLS2 provider worker returned non-JSON output. $text"}
}
function New-Case {
    param([string]$CaseId,[ValidateSet('ABSENT','ONE','PAIRED')][string]$Mode='PAIRED')
    $root=Join-Path $testRoot $CaseId
    $portal=Join-Path $root 'portal'
    $processor=Join-Path $root 'processor'
    $configRoot=Join-Path $portal 'config'
    $data=Join-Path $dataRoot $CaseId
    foreach($path in @($processor,$configRoot,$data)){[void](New-Item -ItemType Directory -Path $path -Force)}
    if($Mode-ne'ABSENT'){
        $slot=Join-Path $data 'PatternedFront\Lot_62619-433\62619-433_20260823120000\Slot01'
        $bf=Join-Path $slot 'BrightfieldFrontsideWafer\resizedImage'
        [void](New-Item -ItemType Directory -Path $bf -Force)
        [void](New-Item -ItemType File -Path (Join-Path $bf '62619-433_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp') -Force)
        if($Mode-eq'PAIRED'){
            $df=Join-Path $slot 'DarkfieldFrontsideWafer\resizedImage'
            [void](New-Item -ItemType Directory -Path $df -Force)
            [void](New-Item -ItemType File -Path (Join-Path $df '62619-433_Slot01_DarkfieldFrontsideWafer_PM2_resizedImage.bmp') -Force)
            [IO.File]::WriteAllText((Join-Path $slot 'metadata.txt'),'metadata-only fixture',$utf8)
        }
    }
    $configPath=Join-Path $configRoot 'endpoint_jbod.json'
    Write-JsonCreateNew -Path $configPath -Value ([ordered]@{schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false;incomingRoot=(Join-Path $portal 'pending');processedRoot=(Join-Path $portal 'processed');responseOutbox=(Join-Path $portal 'outbox');stateRoot=(Join-Path $portal 'state');approvedMaintenanceRoots=@($processor);approvedDataRoots=@([ordered]@{name='JBOD_KLARF_EXPORT';path=$data});status=[ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()};handlers=@()})
    $outputPath=Join-Path $processor 'INVENTORY.json'
    $probePath=Join-Path $root 'PROBE.json'
    Write-JsonCreateNew -Path $probePath -Value ([ordered]@{schema='argos_project_portal_environment_probe_invocation_v1';outputPath=$outputPath;parameters=[ordered]@{environmentInventory=[ordered]@{enabled=$true;approvedDataRoot='JBOD_KLARF_EXPORT';processLocalAliasName='F';boundedSubtreeInventory=[ordered]@{enabled=$true;relativeRoot='PatternedFront\Lot_62619-433';maximumDepth=8;maximumEntries=20000;maximumDirectories=2048;maximumBmpLeaves=2048}}};reviewOnly=$true;productionRoutingEnabled=$false})
    return [pscustomobject]@{root=$root;portal=$portal;processor=$processor;data=$data;configPath=$configPath;probePath=$probePath;outputPath=$outputPath}
}
function Assert-SafeInventory {
    param($Result,[bool]$RootExists,[int]$BmpCount,[int]$OtherCount)
    Assert-True ([string]$Result.state-eq'PASS_JBOD_ENVIRONMENT_INVENTORY') 'OLS2 provider terminal state failed.'
    $inventory=$Result.inventory.boundedSubtreeInventory
    Assert-True ([string]$Result.inventory.schema-eq'argos_project_portal_environment_inventory_v3'-and[string]$inventory.schema-eq'argos_bounded_subtree_inventory_v1'-and[string]$inventory.state-eq'COMPLETE'-and[bool]$inventory.complete-and[bool]$inventory.rootExists-eq$RootExists) 'OLS2 provider completion contract failed.'
    Assert-True ([int]$inventory.bmpLeafCount-eq$BmpCount-and[int]$inventory.otherLeafCount-eq$OtherCount-and@($inventory.bmpLeaves).Count-eq$BmpCount) 'OLS2 provider leaf counts failed.'
    Assert-True (-not[bool]$inventory.truncated-and[int]$inventory.accessErrorCount-eq0-and[int]$inventory.skippedReparseSubtrees-eq0-and[int]$inventory.skippedUnsafePathSubtrees-eq0-and[int]$inventory.depthBoundaryDirectoryCount-eq0) 'OLS2 provider completeness diagnostics failed.'
    Assert-True ([bool]$inventory.pathsEnumerated-and-not[bool]$inventory.filesRead-and-not[bool]$inventory.imageBytesRead-and-not[bool]$inventory.sourceHashingPerformed-and-not[bool]$inventory.mutationsPerformed) 'OLS2 provider metadata-only flags failed.'
    Assert-True ([string]$Result.inventory.processLocalAlias.name-eq'F'-and[bool]$Result.inventory.processLocalAlias.created-and[bool]$Result.inventory.processLocalAlias.removed-and-not[bool]$Result.inventory.processLocalAlias.persistent) 'OLS2 provider process-local alias cleanup failed.'
    Assert-True (@($inventory.bmpLeaves|Where-Object{[string]$_.extension-ne'.bmp'-or-not[bool]$_.containedByApprovedRoot-or[bool]$_.filesRead-or[bool]$_.imageBytesRead-or[bool]$_.sourceHashingPerformed-or[bool]$_.mutationsPerformed}).Count-eq0) 'OLS2 provider BMP row safety failed.'
    return $inventory
}

foreach($path in @($workerPath,$invocationPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "OLS2 provider test prerequisite missing: $path"}}
if((Get-FileHash -LiteralPath $workerPath -Algorithm SHA256).Hash-ne$workerSha256){throw 'OLS2 provider worker hash changed.'}
foreach($path in @($testRoot,$dataRoot,$gatePath)){if(Test-Path -LiteralPath $path){throw "OLS2 provider test requires a fresh path: $path"}}
$longest=Join-Path (Join-Path $dataRoot 'PAIRED') 'PatternedFront\Lot_62619-433\62619-433_20260823120000\Slot01\BrightfieldFrontsideWafer\resizedImage\62619-433_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
[void](Assert-PathBudget $testRoot)
[void](Assert-PathBudget $dataRoot)
[void](Assert-PathBudget $gatePath)
[void](Assert-AliasedSourceBudget -CanonicalPath $longest -AliasPath 'F:\PatternedFront\Lot_62619-433\62619-433_20260823120000\Slot01\BrightfieldFrontsideWafer\resizedImage\62619-433_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp')

if($Preflight){
    [ordered]@{schema='argos_ols2_provider_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_PROVIDER_TEST_PREFLIGHT';workerSha256=$workerSha256;testRoot=$testRoot;dataRoot=$dataRoot;gatePath=$gatePath;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $testRoot)
[void](New-Item -ItemType Directory -Path $dataRoot)
$cases=New-Object 'Collections.Generic.List[object]'

$absent=New-Case -CaseId 'ABSENT' -Mode ABSENT
$absentPreflight=Invoke-WorkerJson -ConfigPath $absent.configPath -ProbePath $absent.probePath -WorkerPreflight
Assert-True ([string]$absentPreflight.state-eq'PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT'-and-not[bool]$absentPreflight.mutationsPerformed-and-not(Test-Path -LiteralPath $absent.outputPath)) 'OLS2 provider preflight mutated or failed.'
$absentInventory=Assert-SafeInventory -Result (Invoke-WorkerJson -ConfigPath $absent.configPath -ProbePath $absent.probePath) -RootExists $false -BmpCount 0 -OtherCount 0
$cases.Add([pscustomobject]@{caseId='ABSENT';state='PASS';bmpLeafCount=0})

$one=New-Case -CaseId 'ONE' -Mode ONE
[void](Assert-SafeInventory -Result (Invoke-WorkerJson -ConfigPath $one.configPath -ProbePath $one.probePath) -RootExists $true -BmpCount 1 -OtherCount 0)
$cases.Add([pscustomobject]@{caseId='ONE_BMP';state='PASS';bmpLeafCount=1})

$paired=New-Case -CaseId 'PAIRED' -Mode PAIRED
[void](Assert-SafeInventory -Result (Invoke-WorkerJson -ConfigPath $paired.configPath -ProbePath $paired.probePath) -RootExists $true -BmpCount 2 -OtherCount 1)
$cases.Add([pscustomobject]@{caseId='PAIRED_BF_DF';state='PASS';bmpLeafCount=2;otherLeafCount=1})

$truncate=New-Case -CaseId 'TRUNCATE' -Mode PAIRED
$truncateProbe=Get-Content -LiteralPath $truncate.probePath -Raw|ConvertFrom-Json
$truncateProbe.outputPath=Join-Path $truncate.processor 'TRUNCATED.json'
$truncateProbe.parameters.environmentInventory.boundedSubtreeInventory.maximumBmpLeaves=1
$truncateProbePath=Join-Path $truncate.root 'TRUNCATED_PROBE.json'
Write-JsonCreateNew -Path $truncateProbePath -Value $truncateProbe
$truncateResult=Invoke-WorkerJson -ConfigPath $truncate.configPath -ProbePath $truncateProbePath
$truncateInventory=$truncateResult.inventory.boundedSubtreeInventory
Assert-True ([string]$truncateInventory.state-eq'HOLD_INCOMPLETE'-and-not[bool]$truncateInventory.complete-and[bool]$truncateInventory.truncated-and[int]$truncateInventory.bmpLeafCount-eq1-and-not[bool]$truncateInventory.filesRead-and-not[bool]$truncateInventory.imageBytesRead-and-not[bool]$truncateInventory.sourceHashingPerformed) 'OLS2 provider truncation hold failed.'
$cases.Add([pscustomobject]@{caseId='TRUNCATION_HOLD';state='PASS'})

$depth=New-Case -CaseId 'DEPTH' -Mode ONE
$depthProbe=Get-Content -LiteralPath $depth.probePath -Raw|ConvertFrom-Json
$depthProbe.outputPath=Join-Path $depth.processor 'DEPTH.json'
$depthProbe.parameters.environmentInventory.boundedSubtreeInventory.maximumDepth=2
$depthProbePath=Join-Path $depth.root 'DEPTH_PROBE.json'
Write-JsonCreateNew -Path $depthProbePath -Value $depthProbe
$depthInventory=(Invoke-WorkerJson -ConfigPath $depth.configPath -ProbePath $depthProbePath).inventory.boundedSubtreeInventory
Assert-True ([string]$depthInventory.state-eq'HOLD_INCOMPLETE'-and[int]$depthInventory.depthBoundaryDirectoryCount-gt0-and-not[bool]$depthInventory.complete) 'OLS2 provider depth-boundary hold failed.'
$cases.Add([pscustomobject]@{caseId='DEPTH_BOUNDARY_HOLD';state='PASS'})

$reparse=New-Case -CaseId 'REPARSE' -Mode ONE
$reparseTarget=Join-Path $reparse.data 'REPARSE_TARGET'
[void](New-Item -ItemType Directory -Path $reparseTarget)
$lotRoot=Join-Path $reparse.data 'PatternedFront\Lot_62619-433'
[void](New-Item -ItemType Junction -Path (Join-Path $lotRoot 'REPARSE_LINK') -Target $reparseTarget)
$reparseInventory=(Invoke-WorkerJson -ConfigPath $reparse.configPath -ProbePath $reparse.probePath).inventory.boundedSubtreeInventory
Assert-True ([string]$reparseInventory.state-eq'HOLD_INCOMPLETE'-and[int]$reparseInventory.skippedReparseSubtrees-eq1-and-not[bool]$reparseInventory.complete) 'OLS2 provider reparse hold failed.'
$cases.Add([pscustomobject]@{caseId='REPARSE_HOLD';state='PASS'})

$unsafe=New-Case -CaseId 'UNSAFE' -Mode ABSENT
$unsafeProbe=Get-Content -LiteralPath $unsafe.probePath -Raw|ConvertFrom-Json
$unsafeProbe.outputPath=Join-Path $unsafe.processor 'UNSAFE.json'
$unsafeProbe.parameters.environmentInventory.boundedSubtreeInventory.relativeRoot='../escape'
$unsafeProbePath=Join-Path $unsafe.root 'UNSAFE_PROBE.json'
Write-JsonCreateNew -Path $unsafeProbePath -Value $unsafeProbe
$unsafeFailure=Invoke-WorkerJson -ConfigPath $unsafe.configPath -ProbePath $unsafeProbePath -WorkerPreflight -ExpectFailure
Assert-True ($unsafeFailure.exitCode-ne0-and$unsafeFailure.text-like'*bounded subtree relative root is unsafe*'-and-not(Test-Path -LiteralPath ([string]$unsafeProbe.outputPath))) 'OLS2 provider unsafe-root refusal failed.'
$cases.Add([pscustomobject]@{caseId='UNSAFE_ROOT_REFUSAL';state='PASS'})

$pathCase=New-Case -CaseId 'PATH_BUDGET' -Mode ABSENT
$pathProbe=Get-Content -LiteralPath $pathCase.probePath -Raw|ConvertFrom-Json
$pathProbe.outputPath=Join-Path $pathCase.processor 'PATH.json'
$pathProbe.parameters.environmentInventory.boundedSubtreeInventory.relativeRoot=('A'*81)
$pathProbePath=Join-Path $pathCase.root 'PATH_PROBE.json'
Write-JsonCreateNew -Path $pathProbePath -Value $pathProbe
$pathFailure=Invoke-WorkerJson -ConfigPath $pathCase.configPath -ProbePath $pathProbePath -WorkerPreflight -ExpectFailure
Assert-True ($pathFailure.exitCode-ne0-and$pathFailure.text-like'*bounded subtree root path budget failed*'-and-not(Test-Path -LiteralPath ([string]$pathProbe.outputPath))) 'OLS2 provider path-budget refusal failed.'
$cases.Add([pscustomobject]@{caseId='PATH_BUDGET_REFUSAL';state='PASS'})

$gate=[ordered]@{schema='argos_ols2_provider_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_OLS2_PROVIDER_TEST_GATE';workerSha256=$workerSha256;caseCount=$cases.Count;passCount=@($cases|Where-Object{[string]$_.state-eq'PASS'}).Count;cases=$cases.ToArray();windowsPowerShellVersion=[string]$PSVersionTable.PSVersion;filesRead=$false;imageBytesRead=$false;sourceHashingPerformed=$false;processorTaskChanged=$false;processActions=@();reviewOnly=$true;productionRoutingEnabled=$false}
Write-JsonCreateNew -Path $gatePath -Value $gate
$gate.mutationsPerformed=$true
$gate|ConvertTo-Json -Depth 8
