[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [Parameter(Mandatory=$true)][string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$modeCount=@(@($Preflight,$Gate)|Where-Object{[bool]$_}).Count
if($modeCount-ne1){throw 'Specify exactly one of -Preflight or -Gate.'}

function Resolve-RepoPath([string]$ProjectRoot,[string]$Value){
    if([string]::IsNullOrWhiteSpace($Value)-or$Value.IndexOfAny([char[]]'*?')-ge0){throw 'Unsafe repository path value.'}
    $candidate=if([IO.Path]::IsPathRooted($Value)){[IO.Path]::GetFullPath($Value)}else{[IO.Path]::GetFullPath((Join-Path $ProjectRoot $Value))}
    return $candidate
}

function Require-Property([object]$Object,[string]$Name){
    if(-not($Object.PSObject.Properties.Name-contains$Name)){throw "Invocation manifest is missing property: $Name"}
}

function Invoke-Inventory([string]$Provider,[object]$Config,[string]$RelativeSubtree,[switch]$FailAfterAlias){
    $arguments=@{
        Inventory=$true
        ApprovedRoot=[string]$Config.fixtureRoot
        RelativeSubtree=$RelativeSubtree
        AliasName=[string]$Config.aliasName
        MaximumDepth=[int]$Config.maximumDepth
        MaximumEntries=[int]$Config.maximumEntries
        MaximumDirectories=[int]$Config.maximumDirectories
        MaximumBmpLeaves=[int]$Config.maximumBmpLeaves
        CanonicalProvenanceRoot=[string]$Config.canonicalProvenanceRoot
        Rehearsal=$true
    }
    if($FailAfterAlias){$arguments['FailAfterAlias']=$true}
    $text=& $Provider @arguments
    return ($text|ConvertFrom-Json)
}

function Assert-AliasAbsent([string]$Name){
    if(Get-PSDrive -Name $Name -ErrorAction SilentlyContinue){throw "Process-local alias remains mounted: $Name"}
}

function Assert-CompleteCase([object]$Result,[string]$CaseId,[int]$ExpectedBmpLeaves){
    if([string]$Result.state-ne'COMPLETE'-or-not[bool]$Result.complete){throw "$CaseId did not return COMPLETE."}
    if([int]$Result.bmpLeafCount-ne$ExpectedBmpLeaves){throw "$CaseId BMP leaf count changed."}
    if([int]$Result.skippedPathRowCount-ne0-or[int]$Result.accessErrorCount-ne0-or[bool]$Result.truncated-or[int]$Result.depthBoundaryDirectoryCount-ne0){throw "$CaseId returned an incomplete-inventory condition."}
    if(-not[bool]$Result.processLocalAlias.created-or-not[bool]$Result.processLocalAlias.removed-or[bool]$Result.processLocalAlias.persistent){throw "$CaseId alias lifecycle failed."}
}

$projectRoot=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$manifestPath=Resolve-RepoPath $projectRoot $InvocationManifest
if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'Invocation manifest is missing.'}
if((Get-Item -LiteralPath $manifestPath).Length-gt65536){throw 'Invocation manifest is too large.'}
$config=Get-Content -LiteralPath $manifestPath -Raw|ConvertFrom-Json
foreach($name in @('schema','state','providerPath','providerSha256','fixtureRoot','relativeSubtree','missingRelativeSubtree','aliasName','canonicalProvenanceRoot','maximumDepth','maximumEntries','maximumDirectories','maximumBmpLeaves','gateOutputPath','fixtureFiles','reviewOnly','productionRoutingEnabled')){Require-Property $config $name}
if([string]$config.schema-ne'argos_ocv00_deepest_alias_local_rehearsal_invocation_v1'-or[string]$config.state-ne'FROZEN_LOCAL_REHEARSAL_INPUT'){throw 'Invocation manifest identity changed.'}
if(-not[bool]$config.reviewOnly-or[bool]$config.productionRoutingEnabled){throw 'Invocation authority changed.'}

$providerPath=Resolve-RepoPath $projectRoot ([string]$config.providerPath)
$gateOutputPath=Resolve-RepoPath $projectRoot ([string]$config.gateOutputPath)
$fixtureRoot=[IO.Path]::GetFullPath([string]$config.fixtureRoot).TrimEnd('\')
$fixtureSubtree=[IO.Path]::GetFullPath((Join-Path $fixtureRoot ([string]$config.relativeSubtree)))
$providerHash=(Get-FileHash -LiteralPath $providerPath -Algorithm SHA256).Hash
$manifestHash=(Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
if($providerHash-ne[string]$config.providerSha256){throw 'Provider hash does not match the frozen invocation manifest.'}
if(Test-Path -LiteralPath $fixtureRoot){throw 'Fresh fixture root already exists; do not delete or reuse it.'}
if(Test-Path -LiteralPath $gateOutputPath){throw 'Gate output already exists; do not overwrite it.'}
Assert-AliasAbsent ([string]$config.aliasName)

$selfTest=(& $providerPath -SelfTest -ApprovedRoot $fixtureRoot -RelativeSubtree ([string]$config.relativeSubtree) -AliasName ([string]$config.aliasName) -Rehearsal)|ConvertFrom-Json
if([string]$selfTest.state-ne'PASS_OCV00_DEEPEST_ALIAS_PROVIDER_SELF_TEST'){throw 'Provider self-test failed.'}
$providerPreflight=(& $providerPath -Preflight -ApprovedRoot $fixtureRoot -RelativeSubtree ([string]$config.relativeSubtree) -AliasName ([string]$config.aliasName) -CanonicalProvenanceRoot ([string]$config.canonicalProvenanceRoot) -Rehearsal)|ConvertFrom-Json
if([string]$providerPreflight.state-ne'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_PREFLIGHT'-or[string]$providerPreflight.aliasAnchor-ne'EXACT_REQUESTED_SUBTREE_ROOT'){throw 'Provider preflight failed.'}

if($Preflight){
    [ordered]@{
        schema='argos_ocv00_deepest_alias_local_rehearsal_preflight_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_OCV00_DEEPEST_ALIAS_LOCAL_REHEARSAL_PREFLIGHT'
        projectRoot=$projectRoot
        providerPath=$providerPath
        providerSha256=$providerHash
        invocationManifest=$manifestPath
        invocationManifestSha256=$manifestHash
        fixtureRoot=$fixtureRoot
        gateOutputPath=$gateOutputPath
        aliasName=[string]$config.aliasName
        selfTestState=[string]$selfTest.state
        providerPreflightState=[string]$providerPreflight.state
        mutationsPerformed=$false
        filesCreated=0
        imageBytesRead=$false
        sourceHashingPerformed=$false
    }|ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $fixtureSubtree)
$zero=Invoke-Inventory $providerPath $config ([string]$config.relativeSubtree)
Assert-CompleteCase $zero 'ZERO' 0
Assert-AliasAbsent ([string]$config.aliasName)

[void](New-Item -ItemType File -Path (Join-Path $fixtureSubtree 'one.bmp'))
$one=Invoke-Inventory $providerPath $config ([string]$config.relativeSubtree)
Assert-CompleteCase $one 'ONE' 1
Assert-AliasAbsent ([string]$config.aliasName)

[void](New-Item -ItemType Directory -Path (Join-Path $fixtureSubtree 'A'))
[void](New-Item -ItemType Directory -Path (Join-Path $fixtureSubtree 'B'))
[void](New-Item -ItemType File -Path (Join-Path $fixtureSubtree 'A\a.bmp'))
[void](New-Item -ItemType File -Path (Join-Path $fixtureSubtree 'B\b.bmp'))
[void](New-Item -ItemType File -Path (Join-Path $fixtureSubtree 'note.txt'))
$many=Invoke-Inventory $providerPath $config ([string]$config.relativeSubtree)
Assert-CompleteCase $many 'MANY' 3
if([int]$many.directoryCount-ne2-or[int]$many.otherLeafCount-ne1){throw 'MANY directory or other-leaf count changed.'}
$manyBmp=@($many.bmpLeaves)
if(@($manyBmp|Where-Object{[int]$_.canonicalEffectiveLength-lt230-or[bool]$_.canonicalIoAllowed-or[int]$_.aliasEffectiveLength-ge200}).Count-ne0){throw 'MANY did not keep long canonical provenance separate from short alias I/O.'}
Assert-AliasAbsent ([string]$config.aliasName)

$injectedFailureCaptured=$false
$injectedFailureMessage=$null
try{[void](Invoke-Inventory $providerPath $config ([string]$config.relativeSubtree) -FailAfterAlias)}catch{$injectedFailureMessage=[string]$_.Exception.Message;$injectedFailureCaptured=$injectedFailureMessage-match'INJECTED_OLS4_FAILURE_AFTER_ALIAS'}
if(-not$injectedFailureCaptured){throw 'Injected post-alias failure was not captured exactly.'}
Assert-AliasAbsent ([string]$config.aliasName)

$missing=Invoke-Inventory $providerPath $config ([string]$config.missingRelativeSubtree)
if([string]$missing.state-ne'HOLD_INCOMPLETE'-or[bool]$missing.rootExists-or[bool]$missing.processLocalAlias.created-or-not[bool]$missing.processLocalAlias.removed){throw 'Missing-subtree hold semantics failed.'}
Assert-AliasAbsent ([string]$config.aliasName)

$gateRecord=[ordered]@{
    schema='argos_ocv00_deepest_alias_provider_gate_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_OCV00_DEEPEST_ALIAS_PROVIDER_LOCAL_GATE'
    lifecycle='FROZEN_LOCAL_EVIDENCE'
    providerPath=$providerPath
    providerSha256=$providerHash
    invocationManifest=$manifestPath
    invocationManifestSha256=$manifestHash
    fixtureRoot=$fixtureRoot
    fixturePreserved=$true
    aliasName=[string]$config.aliasName
    aliasAnchor='EXACT_REQUESTED_SUBTREE_ROOT'
    caseIds=@('ZERO','ONE','MANY')
    cases=[ordered]@{
        ZERO=[ordered]@{state=[string]$zero.state;bmpLeafCount=[int]$zero.bmpLeafCount;skippedPathRowCount=[int]$zero.skippedPathRowCount}
        ONE=[ordered]@{state=[string]$one.state;bmpLeafCount=[int]$one.bmpLeafCount;skippedPathRowCount=[int]$one.skippedPathRowCount}
        MANY=[ordered]@{state=[string]$many.state;bmpLeafCount=[int]$many.bmpLeafCount;directoryCount=[int]$many.directoryCount;otherLeafCount=[int]$many.otherLeafCount;skippedPathRowCount=[int]$many.skippedPathRowCount}
    }
    canonical230AliasUnder200Accepted=$true
    exactUnsafeSkipIdentitySelfTestPassed=[bool]$selfTest.alias200ExactIdentityHold
    existingSourceComponentAbove80AdvisorySelfTestPassed=[bool]$selfTest.existingSourceComponentAbove80Advisory
    filesystemImpossibleComponentExactIdentityHoldSelfTestPassed=[bool]$selfTest.filesystemImpossibleComponentExactIdentityHold
    injectedPostAliasFailureCaptured=$injectedFailureCaptured
    injectedFailureMessage=$injectedFailureMessage
    aliasRemovedAfterInjectedFailure=$true
    missingSubtreeState=[string]$missing.state
    missingSubtreeRootExists=[bool]$missing.rootExists
    sourceFilesCreatedAsZeroByteMetadataFixtures=4
    sourceFileContentWritten=$false
    sourceFilesRead=$false
    imageBytesRead=$false
    sourceHashingPerformed=$false
    jbodContacted=$false
    endpointRequests=0
    healthyProcessorActions=0
    reviewOnly=$true
    productionRoutingEnabled=$false
}
$json=$gateRecord|ConvertTo-Json -Depth 10
$utf8=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText($gateOutputPath,$json+[Environment]::NewLine,$utf8)
if(-not(Test-Path -LiteralPath $gateOutputPath -PathType Leaf)){throw 'Gate output was not written.'}
$readback=Get-Content -LiteralPath $gateOutputPath -Raw|ConvertFrom-Json
if([string]$readback.state-ne'PASS_OCV00_DEEPEST_ALIAS_PROVIDER_LOCAL_GATE'){throw 'Gate output readback failed.'}
$gateSha=(Get-FileHash -LiteralPath $gateOutputPath -Algorithm SHA256).Hash
[ordered]@{schema='argos_ocv00_deepest_alias_provider_gate_result_v1';state='PASS_OCV00_DEEPEST_ALIAS_PROVIDER_LOCAL_GATE';gateOutputPath=$gateOutputPath;gateOutputSha256=$gateSha;fixtureRoot=$fixtureRoot;fixturePreserved=$true;jbodContacted=$false;imageBytesRead=$false}|ConvertTo-Json -Depth 6
