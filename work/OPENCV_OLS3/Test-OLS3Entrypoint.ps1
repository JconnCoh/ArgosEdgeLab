[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [Parameter(Mandatory = $true)][string]$InvocationManifest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Get-FileHash {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$LiteralPath,[ValidateSet('SHA256')][string]$Algorithm='SHA256')
    $full=[IO.Path]::GetFullPath($LiteralPath)
    $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return [pscustomobject]@{Algorithm='SHA256';Hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','');Path=$full}}
    finally{$sha.Dispose();$stream.Dispose()}
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.schema -ne 'argos_ols3_entrypoint_test_invocation_v1') { throw 'OLS3 test invocation schema mismatch.' }
$testRoot = [IO.Path]::GetFullPath([string]$manifest.testRoot)
$dataRoot = [IO.Path]::GetFullPath([string]$manifest.dataRoot)
$gatePath = [IO.Path]::GetFullPath([string]$manifest.gatePath)
$entrypoint = [IO.Path]::GetFullPath([string]$manifest.entrypointPath)
$priorWorker = [IO.Path]::GetFullPath([string]$manifest.priorWorkerPath)
$targetWorker = [IO.Path]::GetFullPath([string]$manifest.targetWorkerPath)
$priorHash = [string]$manifest.priorWorkerSha256
$targetHash = [string]$manifest.targetWorkerSha256
$utf8 = New-Object Text.UTF8Encoding($false)

foreach ($path in @($entrypoint, $priorWorker, $targetWorker)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "OLS3 test prerequisite missing: $path" }
}
if ((Get-FileHash -LiteralPath $priorWorker -Algorithm SHA256).Hash -ne $priorHash) { throw 'OLS3 test predecessor hash changed.' }
if ((Get-FileHash -LiteralPath $targetWorker -Algorithm SHA256).Hash -ne $targetHash) { throw 'OLS3 test target hash changed.' }
if ((Test-Path -LiteralPath $testRoot) -or (Test-Path -LiteralPath $dataRoot) -or (Test-Path -LiteralPath $gatePath)) { throw 'OLS3 test requires fresh test, data, and gate paths.' }

$caseIds = @('OLD_PREDECESSOR','TARGET_IDEMPOTENT','ZERO_MATCH','ONE_MATCH','UNAPPROVED_PREDECESSOR','ROLLBACK_AFTER_SWAP','UNSAFE_ROOT','TRUNCATED','BAD_ROOT')
$longestRelativeLeaf = 'PatternedFront\Lot_62619-433\62619-433_20260823120000\Slot01\BrightfieldFrontsideWafer\resizedImage\62619-433_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
$plannedCanonicalPaths = @($caseIds | ForEach-Object { [IO.Path]::GetFullPath((Join-Path (Join-Path $dataRoot $_) $longestRelativeLeaf)) })
$maximumCanonicalEffectiveLength = [int](($plannedCanonicalPaths | ForEach-Object { $_.Length + 32 } | Measure-Object -Maximum).Maximum)
$aliasEffectiveLength = ('F:\' + $longestRelativeLeaf).Length + 32
if ($maximumCanonicalEffectiveLength -ge 230 -or $aliasEffectiveLength -ge 200) { throw 'OLS3 planned canonical or process-local alias path budget failed before test write.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ols3_entrypoint_test_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_OLS3_ENTRYPOINT_TEST_PREFLIGHT'
        testRoot = $testRoot
        dataRoot = $dataRoot
        gatePath = $gatePath
        maximumCanonicalEffectiveLength = $maximumCanonicalEffectiveLength
        aliasEffectiveLength = $aliasEffectiveLength
        priorWorkerSha256 = $priorHash
        targetWorkerSha256 = $targetHash
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
    return
}

function Write-Json {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][object]$Value)
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 30), $utf8)
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function New-Case {
    param([string]$CaseId, [string]$WorkerSource, [bool]$FailAfterSwap, [ValidateSet('ZERO','ONE','MANY')][string]$MatchMode = 'MANY', [int]$MaximumBmpLeaves = 2048)
    $root = Join-Path $testRoot $CaseId
    $portal = Join-Path $root 'portal'
    $processor = Join-Path $root 'processor'
    $bin = Join-Path $portal 'bin'
    $configRoot = Join-Path $portal 'config'
    $volumeData = Join-Path $dataRoot $CaseId
    foreach ($path in @($bin, $configRoot, $processor, $volumeData)) { [void](New-Item -ItemType Directory -Path $path -Force) }
    $controlRoot = Join-Path $volumeData 'PatternedFront\Lot_99999-999\99999-999_20260823120000'
    [void](New-Item -ItemType Directory -Path $controlRoot -Force)
    if ($MatchMode -ne 'ZERO') {
        $lotRoot = Join-Path $volumeData 'PatternedFront\Lot_62619-433'
        [void](New-Item -ItemType Directory -Path $lotRoot -Force)
        $slotRoot = Join-Path $lotRoot '62619-433_20260823120000\Slot01'
        $bfRoot = Join-Path $slotRoot 'BrightfieldFrontsideWafer\resizedImage'
        [void](New-Item -ItemType Directory -Path $bfRoot -Force)
        [void](New-Item -ItemType File -Path (Join-Path $bfRoot '62619-433_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp') -Force)
        if ($MatchMode -eq 'MANY') {
            $dfRoot = Join-Path $slotRoot 'DarkfieldFrontsideWafer\resizedImage'
            [void](New-Item -ItemType Directory -Path $dfRoot -Force)
            [void](New-Item -ItemType File -Path (Join-Path $dfRoot '62619-433_Slot01_DarkfieldFrontsideWafer_PM2_resizedImage.bmp') -Force)
            [IO.File]::WriteAllText((Join-Path $slotRoot 'metadata.txt'),'fixture metadata only',$utf8)
        }
    }
    $workerPath = Join-Path $bin 'Invoke-ArgosProjectPortalEndpointWorker.ps1'
    Copy-Item -LiteralPath $WorkerSource -Destination $workerPath
    $configPath = Join-Path $configRoot 'endpoint_jbod.json'
    Write-Json -Path $configPath -Value ([ordered]@{
        schema = 'argos_project_portal_endpoint_config_v1'
        role = 'JBOD'
        reviewOnly = $true
        productionRoutingEnabled = $false
        incomingRoot = (Join-Path $portal 'endpoint\pending')
        processedRoot = (Join-Path $portal 'endpoint\processed')
        responseOutbox = (Join-Path $portal 'outbox')
        stateRoot = (Join-Path $portal 'state')
        approvedMaintenanceRoots = @($processor)
        approvedDataRoots = @([ordered]@{name='JBOD_KLARF_EXPORT';path=$volumeData})
        status = [ordered]@{tasks=@();hashFiles=@();jsonFiles=@();logs=@()}
        handlers = @()
    })
    $outputPath = Join-Path $processor 'OCV00_OLS3_LOT_INVENTORY.json'
    $probePath = Join-Path $root 'PROBE.json'
    Write-Json -Path $probePath -Value ([ordered]@{
        schema = 'argos_project_portal_environment_probe_invocation_v1'
        outputPath = $outputPath
        parameters = [ordered]@{environmentInventory=[ordered]@{
            enabled=$true
            approvedDataRoot='JBOD_KLARF_EXPORT'
            processLocalAliasName='F'
            boundedSubtreeInventory=[ordered]@{enabled=$true;relativeRoot='PatternedFront\Lot_62619-433';maximumDepth=8;maximumEntries=20000;maximumDirectories=2048;maximumBmpLeaves=2048}
        }}
        reviewOnly = $true
        productionRoutingEnabled = $false
    })
    $entryInvocation = Join-Path $root 'ENTRY.json'
    Write-Json -Path $entryInvocation -Value ([ordered]@{
        schema = 'argos_ols3_entrypoint_invocation_v1'
        portalRoot = $portal
        processorRoot = $processor
        probeInvocationPath = $probePath
        failAfterSwap = $FailAfterSwap
        maximumBmpLeaves = $MaximumBmpLeaves
        reviewOnly = $true
        productionRoutingEnabled = $false
    })
    return [pscustomobject]@{root=$root;portal=$portal;processor=$processor;workerPath=$workerPath;configPath=$configPath;outputPath=$outputPath;probePath=$probePath;entryInvocation=$entryInvocation}
}

[void](New-Item -ItemType Directory -Path $testRoot)
$cases = New-Object Collections.Generic.List[object]

$oldCase = New-Case -CaseId 'OLD_PREDECESSOR' -WorkerSource $priorWorker -FailAfterSwap $false
$entryPreflightResult = & $entrypoint -Preflight -InvocationManifest $oldCase.entryInvocation | ConvertFrom-Json
Assert-True ([string]$entryPreflightResult.state -eq 'PASS_OLS3_ENTRYPOINT_PREFLIGHT') 'OLS3 entrypoint preflight failed.'
Assert-True (-not(Test-Path -LiteralPath $oldCase.outputPath)) 'OLS3 entrypoint preflight mutated output.'
Assert-True (-not[bool](Get-PSDrive -Name F -ErrorAction SilentlyContinue)) 'OLS3 entrypoint preflight created process-local alias F.'
$oldResult = & $entrypoint -Rehearsal -InvocationManifest $oldCase.entryInvocation | ConvertFrom-Json
Assert-True ([string]$oldResult.state -eq 'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3') 'OLS3 old-predecessor rehearsal failed.'
Assert-True ((Get-FileHash -LiteralPath $oldCase.workerPath -Algorithm SHA256).Hash -eq $targetHash) 'OLS3 old predecessor did not install target.'
Assert-True (Test-Path -LiteralPath $oldCase.outputPath -PathType Leaf) 'OLS3 old-predecessor case omitted capability output.'
Assert-True (-not[bool](Get-PSDrive -Name F -ErrorAction SilentlyContinue)) 'OLS3 unexpectedly created process-local alias F.'
$oldOutput = Get-Content -LiteralPath $oldCase.outputPath -Raw | ConvertFrom-Json
$oldInventory = $oldOutput.inventory.boundedSubtreeInventory
$oldBmpLeaves = @($oldInventory.bmpLeaves)
$signedInventory = $oldResult.boundedSubtreeInventory
Assert-True ([string]$oldInventory.state -eq 'COMPLETE' -and [bool]$oldInventory.complete -and [bool]$oldInventory.rootExists -and -not [bool]$oldInventory.truncated) 'OLS3 bounded lot subtree inventory did not complete.'
Assert-True ($oldBmpLeaves.Count -eq 2 -and [int]$oldInventory.bmpLeafCount -eq 2 -and [int]$signedInventory.bmpLeafCount -eq 2 -and [int]$oldInventory.otherLeafCount -eq 1) 'OLS3 bounded lot subtree inventory did not return the expected BF/DF metadata rows.'
Assert-True ([string]$oldOutput.inventory.processLocalAlias.name -eq 'F' -and [bool]$oldOutput.inventory.processLocalAlias.created -and [bool]$oldOutput.inventory.processLocalAlias.removed -and -not [bool]$oldOutput.inventory.processLocalAlias.persistent) 'OLS3 process-local alias cleanup failed.'
Assert-True (@($oldBmpLeaves | Where-Object { -not [bool]$_.containedByApprovedRoot -or -not ([string]$_.aliasReadPath).StartsWith('F:\',[StringComparison]::OrdinalIgnoreCase) -or [int]$_.canonicalEffectiveLength -ge 230 -or [int]$_.aliasEffectiveLength -ge 200 -or [string]$_.extension -ne '.bmp' -or [bool]$_.filesRead -or [bool]$_.imageBytesRead -or [bool]$_.sourceHashingPerformed -or [bool]$_.mutationsPerformed }).Count -eq 0) 'OLS3 bounded lot subtree inventory violated metadata-only boundaries.'
Assert-True ([bool]$oldResult.metadataOnly -and [bool]$oldResult.pathsEnumerated -and -not[bool]$oldResult.filesRead -and -not[bool]$oldResult.imageBytesRead -and -not[bool]$oldResult.sourceHashingPerformed) 'OLS3 entrypoint result did not preserve signed-response metadata-only controls.'
$cases.Add([pscustomobject]@{caseId='OLD_PREDECESSOR';state='PASS';workerChanged=[bool]$oldResult.workerChanged})

$targetCase = New-Case -CaseId 'TARGET_IDEMPOTENT' -WorkerSource $targetWorker -FailAfterSwap $false
$targetResult = & $entrypoint -Rehearsal -InvocationManifest $targetCase.entryInvocation | ConvertFrom-Json
Assert-True ([string]$targetResult.state -eq 'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3') 'OLS3 target-idempotent rehearsal failed.'
Assert-True (-not[bool]$targetResult.workerChanged) 'OLS3 target-idempotent case reported a change.'
Assert-True ((Get-FileHash -LiteralPath $targetCase.workerPath -Algorithm SHA256).Hash -eq $targetHash) 'OLS3 target-idempotent worker changed unexpectedly.'
$cases.Add([pscustomobject]@{caseId='TARGET_IDEMPOTENT';state='PASS';workerChanged=[bool]$targetResult.workerChanged})

$zeroCase = New-Case -CaseId 'ZERO_MATCH' -WorkerSource $targetWorker -FailAfterSwap $false -MatchMode ZERO
$zeroResult = & $entrypoint -Rehearsal -InvocationManifest $zeroCase.entryInvocation | ConvertFrom-Json
Assert-True ([string]$zeroResult.state -eq 'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3' -and [string]$zeroResult.inventoryDisposition -eq 'HOLD_INCOMPLETE' -and @($zeroResult.holdReasons) -contains 'ROOT_MISSING' -and -not [bool]$zeroResult.boundedSubtreeInventory.rootExists -and [int]$zeroResult.boundedSubtreeInventory.bmpLeafCount -eq 0) 'OLS3 absent-subtree hold case failed.'
$cases.Add([pscustomobject]@{caseId='ABSENT_SUBTREE';state='PASS';bmpLeafCount=0})

$oneCase = New-Case -CaseId 'ONE_MATCH' -WorkerSource $targetWorker -FailAfterSwap $false -MatchMode ONE
$oneResult = & $entrypoint -Rehearsal -InvocationManifest $oneCase.entryInvocation | ConvertFrom-Json
Assert-True ([string]$oneResult.state -eq 'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3' -and [string]$oneResult.inventoryDisposition -eq 'COMPLETE' -and [bool]$oneResult.boundedSubtreeInventory.rootExists -and [int]$oneResult.boundedSubtreeInventory.bmpLeafCount -eq 1) 'OLS3 one-BMP collection case failed.'
$cases.Add([pscustomobject]@{caseId='ONE_BMP';state='PASS';bmpLeafCount=1})

$cases.Add([pscustomobject]@{caseId='PAIRED_BF_DF';state='PASS';bmpLeafCount=2})

$unapprovedSource = Join-Path $testRoot 'UNAPPROVED.ps1'
[IO.File]::WriteAllText($unapprovedSource, "param()`n'UNAPPROVED'`n", $utf8)
$unapprovedCase = New-Case -CaseId 'UNAPPROVED_PREDECESSOR' -WorkerSource $unapprovedSource -FailAfterSwap $false
$unapprovedFailed = $false
try { [void](& $entrypoint -Rehearsal -InvocationManifest $unapprovedCase.entryInvocation) }
catch { $unapprovedFailed = $_.Exception.Message -like '*predecessor is not approved*' }
Assert-True $unapprovedFailed 'OLS3 unapproved predecessor was not refused.'
Assert-True (-not(Test-Path -LiteralPath $unapprovedCase.outputPath)) 'OLS3 unapproved case created output.'
$cases.Add([pscustomobject]@{caseId='UNAPPROVED_PREDECESSOR';state='PASS';refusedBeforeMutation=$true})

$rollbackCase = New-Case -CaseId 'ROLLBACK_AFTER_SWAP' -WorkerSource $priorWorker -FailAfterSwap $true
$rollbackFailed = $false
try { [void](& $entrypoint -Rehearsal -InvocationManifest $rollbackCase.entryInvocation) }
catch { $rollbackFailed = $_.Exception.Message -like '*INJECTED_OLS3_FAILURE_AFTER_SWAP*' }
Assert-True $rollbackFailed 'OLS3 injected rollback case did not fail as expected.'
Assert-True ((Get-FileHash -LiteralPath $rollbackCase.workerPath -Algorithm SHA256).Hash -eq $priorHash) 'OLS3 rollback did not restore predecessor.'
Assert-True (-not(Test-Path -LiteralPath $rollbackCase.outputPath)) 'OLS3 rollback case left capability output.'
$cases.Add([pscustomobject]@{caseId='ROLLBACK_AFTER_SWAP';state='PASS';predecessorRestored=$true})

$unsafeCase = New-Case -CaseId 'UNSAFE_ROOT' -WorkerSource $targetWorker -FailAfterSwap $false
$unsafeProbe = Get-Content -LiteralPath $unsafeCase.probePath -Raw | ConvertFrom-Json
$unsafeProbe.parameters.environmentInventory.boundedSubtreeInventory.relativeRoot = '../escape'
Write-Json -Path (Join-Path $unsafeCase.root 'UNSAFE_PROBE.json') -Value $unsafeProbe
$unsafeFailed = $false
try { [void](& $targetWorker -ConfigPath $unsafeCase.configPath -Preflight -EnvironmentProbeManifest (Join-Path $unsafeCase.root 'UNSAFE_PROBE.json')) }
catch { $unsafeFailed = $_.Exception.Message -like '*bounded subtree relative root is unsafe*' }
Assert-True $unsafeFailed 'OLS3 unsafe subtree root was not refused.'
Assert-True (-not(Test-Path -LiteralPath $unsafeCase.outputPath)) 'OLS3 unsafe-root preflight created output.'
$cases.Add([pscustomobject]@{caseId='UNSAFE_SUBTREE_ROOT_REFUSAL';state='PASS';mutationsPerformed=$false})

$truncatedCase = New-Case -CaseId 'TRUNCATED' -WorkerSource $targetWorker -FailAfterSwap $false -MaximumBmpLeaves 1
$truncatedResult = & $entrypoint -Rehearsal -InvocationManifest $truncatedCase.entryInvocation | ConvertFrom-Json
$truncatedInventory = $truncatedResult.boundedSubtreeInventory
Assert-True ([string]$truncatedResult.state -eq 'PASS_OCV00_BOUNDED_LOT_SUBTREE_OBSERVED_OLS3' -and [string]$truncatedResult.inventoryDisposition -eq 'HOLD_INCOMPLETE' -and @($truncatedResult.holdReasons) -contains 'TRUNCATED' -and [string]$truncatedInventory.state -eq 'HOLD_INCOMPLETE' -and [bool]$truncatedInventory.truncated -and -not [bool]$truncatedInventory.complete -and [int]$truncatedInventory.bmpLeafCount -eq 1 -and -not [bool]$truncatedInventory.filesRead -and -not [bool]$truncatedInventory.imageBytesRead -and -not [bool]$truncatedInventory.sourceHashingPerformed) 'OLS3 entrypoint truncation hold case failed.'
$cases.Add([pscustomobject]@{caseId='TRUNCATION_HOLD';state='PASS';bmpLeafCount=1;complete=$false})

$unapprovedRootCase = New-Case -CaseId 'BAD_ROOT' -WorkerSource $targetWorker -FailAfterSwap $false
$rootProbe = Get-Content -LiteralPath $unapprovedRootCase.probePath -Raw | ConvertFrom-Json
$rootProbe.parameters.environmentInventory.approvedDataRoot = 'NOT_CONFIGURED'
Write-Json -Path (Join-Path $unapprovedRootCase.root 'ROOT_PROBE.json') -Value $rootProbe
$rootFailed = $false
try { [void](& $targetWorker -ConfigPath $unapprovedRootCase.configPath -Preflight -EnvironmentProbeManifest (Join-Path $unapprovedRootCase.root 'ROOT_PROBE.json')) }
catch { $rootFailed = $_.Exception.Message -like '*approved data root is not configured*' }
Assert-True $rootFailed 'OLS3 unapproved data root was not refused.'
Assert-True (-not(Test-Path -LiteralPath $unapprovedRootCase.outputPath)) 'OLS3 unapproved-root preflight created output.'
$cases.Add([pscustomobject]@{caseId='UNAPPROVED_ROOT_REFUSAL';state='PASS';mutationsPerformed=$false})

$gate = [ordered]@{
    schema = 'argos_ols3_entrypoint_test_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_OLS3_ENTRYPOINT_TEST_GATE'
    caseCount = $cases.Count
    passCount = @($cases | Where-Object { [string]$_.state -eq 'PASS' }).Count
    cases = $cases.ToArray()
    priorWorkerSha256 = $priorHash
    targetWorkerSha256 = $targetHash
    dataRoot = $dataRoot
    maximumCanonicalEffectiveLength = $maximumCanonicalEffectiveLength
    aliasEffectiveLength = $aliasEffectiveLength
    installedProducerPreflightExecuted = $true
    installedProducerTerminalStatusReadBeforeOutputValidation = $true
    inspectionTasksChanged = $false
    processActions = @()
    imageBytesRead = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-Json -Path $gatePath -Value $gate
$gate | ConvertTo-Json -Depth 10
