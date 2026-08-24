[CmdletBinding()]
param([switch]$Preflight,[switch]$Test)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if(([bool]$Preflight)-eq([bool]$Test)){throw 'Specify exactly one of -Preflight or -Test.'}
function Get-Sha256([string]$LiteralPath){return (Get-FileHash -LiteralPath $LiteralPath -Algorithm SHA256).Hash}

$project=Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root=$PSScriptRoot
$endpoint=Join-Path $root 'Invoke-O2D2ScribeEndpoint.ps1'
$engine=Join-Path $project 'work\OPENCV_SCRIBE_V1\ArgosOpenCvScribeV1.py'
$bundle=Join-Path $project 'work\OPENCV_SCRIBE_O2D1\O2D1_REFS.zip'
$jobTemplate=Join-Path $root 'O2D2_REHEARSAL_JOB.json'
$runtime=Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$sourceRoot=Join-Path $project 'work\SCRIBE_REVIEW_ONLY\diagnostics\SCRIBE_READER_FAILURE_DIAGNOSTIC_V1_20260806T201825Z\62631-535_20260730105033_Slot16'
$inputRoot='C:\O2D2I'
$payloadRoot='C:\O2D2P'
$normalRoot='C:\O2D2T'
$failureRoot='C:\O2D2F'
$gatePath=Join-Path $root 'O2D2_ENTRYPOINT_TEST_GATE.json'
$bfSha='094353365C010DA2C1AB67EBAE1097D3F783E80379BBB585D1F4B531C29EA2EE'
$dfSha='79232E8A8FAC6634048CFE9EDAFF34467EBF21BEACC55A47E2B3CAA91B82426C'
foreach($p in @($endpoint,$engine,$bundle,$jobTemplate,(Join-Path $runtime 'python.exe'))){if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "O2D2 test dependency missing: $p"}}
foreach($p in @($inputRoot,$payloadRoot,$normalRoot,$failureRoot,$gatePath)){if(Test-Path -LiteralPath $p){throw "O2D2 test target exists: $p"}}
if((Test-Path -LiteralPath 'X:\')-or $null-ne(Get-PSDrive -Name X -ErrorAction SilentlyContinue)){throw 'O2D2 test requires X: to be unused.'}
$tokens=$null;$errors=$null
[void][Management.Automation.Language.Parser]::ParseFile($endpoint,[ref]$tokens,[ref]$errors)
if(@($errors).Count-ne 0){throw 'O2D2 endpoint PS5 parser failed.'}
if($Preflight){
    [ordered]@{schema='argos_o2d2_entrypoint_test_preflight_v1';state='PASS_O2D2_ENTRYPOINT_TEST_PREFLIGHT';endpointSha256=Get-Sha256 $endpoint;engineSha256=Get-Sha256 $engine;bundleSha256=Get-Sha256 $bundle;sourceAliasAnchor=$sourceRoot;sourceAlias='Q:';childAlias='X:';mutationsPerformed=$false;processStarted=$false;reviewOnly=$true;productionEligible=$false}|ConvertTo-Json -Depth 5
    return
}

$qCreated=$false
try{
    if($null-ne(Get-PSDrive -Name Q -ErrorAction SilentlyContinue)){throw 'O2D2 process-local Q: alias is in use.'}
    [void](New-PSDrive -Name Q -PSProvider FileSystem -Root $sourceRoot -Scope Script -ErrorAction Stop);$qCreated=$true
    [void](New-Item -ItemType Directory -Path $inputRoot)
    Copy-Item -LiteralPath ('Q:\'+'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png') -Destination (Join-Path $inputRoot 'BF.png') -ErrorAction Stop
    Copy-Item -LiteralPath ('Q:\'+'DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png') -Destination (Join-Path $inputRoot 'DF.png') -ErrorAction Stop
    if((Get-Sha256 (Join-Path $inputRoot 'BF.png'))-ne $bfSha-or(Get-Sha256 (Join-Path $inputRoot 'DF.png'))-ne $dfSha){throw 'O2D2 staged inputs changed.'}
    [void](New-Item -ItemType Directory -Path $payloadRoot)
    Copy-Item -LiteralPath $engine -Destination (Join-Path $payloadRoot 'ArgosOpenCvScribeV1.py')
    Copy-Item -LiteralPath $bundle -Destination (Join-Path $payloadRoot 'O2D2_REFS.zip')
    Copy-Item -LiteralPath $jobTemplate -Destination (Join-Path $payloadRoot 'O2D2_SLOT16_JOB.json')
    $jobPath=Join-Path $payloadRoot 'O2D2_SLOT16_JOB.json'
    $endpointPreflight=(& $endpoint -Preflight -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtime -WorkRoot (Join-Path $normalRoot 'w') -OutputRoot (Join-Path $normalRoot 'o') -SourceAliasRoot $inputRoot -RehearsalJobPath $jobPath|Out-String)|ConvertFrom-Json
    if([string]$endpointPreflight.state-ne'PASS_O2D2_ENDPOINT_PREFLIGHT'-or[bool]$endpointPreflight.mutationsPerformed-or[bool]$endpointPreflight.processStarted){throw 'O2D2 endpoint preflight changed.'}
    $normal=(& $endpoint -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtime -WorkRoot (Join-Path $normalRoot 'w') -OutputRoot (Join-Path $normalRoot 'o') -SourceAliasRoot $inputRoot -RehearsalJobPath $jobPath|Out-String)|ConvertFrom-Json
    if([string]$normal.state-ne'PASS_O2D2_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED'-or[string]$normal.resultState-ne'SCRIBE_REFERENCE_COVERAGE_HOLD'-or[string]$normal.imageFirstString-ne'0438S004FEH0'-or-not[bool]$normal.sourceAliasRemoved-or[bool]$normal.referenceCoverageComplete-or[string]$normal.missingReferenceLabels-ne'IJKOQVWXYZ'-or[bool]$normal.inspectionTasksChanged-or[bool]$normal.processorTaskChanged-or[bool]$normal.sourceDeletionPerformed-or[bool]$normal.holdsCleared-or[bool]$normal.providerActivated-or[bool]$normal.productionEligible){throw 'O2D2 normal rehearsal contract changed.'}
    if((Test-Path -LiteralPath 'X:\')-or $null-ne(Get-PSDrive -Name X -ErrorAction SilentlyContinue)){throw 'O2D2 X: alias remained after normal rehearsal.'}

    [void](New-Item -ItemType Directory -Path $failureRoot)
    $bad=Get-Content -Raw -LiteralPath $jobPath|ConvertFrom-Json
    $bad.inputs.bf.sha256='0000000000000000000000000000000000000000000000000000000000000000'
    $bad.references.manifestPath='C:\O2D2F\w\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $bad.references.roots[0].path='C:\O2D2F\w\refs\glyphs'
    $bad.references.roots[1].path='C:\O2D2F\w\refs\glyphs_v5_confirmed_20260806'
    $bad.outputRoot='C:\O2D2F\o'
    $badPath=Join-Path $failureRoot 'BAD_JOB.json'
    [IO.File]::WriteAllText($badPath,(($bad|ConvertTo-Json -Depth 16)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    $failureCaught=$false
    try{& $endpoint -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtime -WorkRoot (Join-Path $failureRoot 'w') -OutputRoot (Join-Path $failureRoot 'o') -SourceAliasRoot $inputRoot -RehearsalJobPath $badPath 2>&1|Out-Null}catch{if($_.Exception.Message-match'Source SHA-256 mismatch|provider failed with exit'){$failureCaught=$true}}
    $aliasAbsentAfterFailure=(-not(Test-Path -LiteralPath 'X:\'))-and $null-eq(Get-PSDrive -Name X -ErrorAction SilentlyContinue)
    if(-not $failureCaught-or-not $aliasAbsentAfterFailure-or(Test-Path -LiteralPath (Join-Path $failureRoot 'o\RESULT.json'))){throw 'O2D2 injected failure did not fail closed and remove alias.'}
    $gate=[ordered]@{schema='argos_o2d2_entrypoint_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D2_ENTRYPOINT_TEST_GATE';endpointSha256=Get-Sha256 $endpoint;engineSha256=Get-Sha256 $engine;bundleSha256=Get-Sha256 $bundle;normalResultState=[string]$normal.resultState;normalImageFirstString=[string]$normal.imageFirstString;referenceCoverageHoldPreserved=$true;normalAliasRemoved=$true;injectedHashMismatchFailedClosed=$true;injectedFailureAliasRemoved=$aliasAbsentAfterFailure;injectedFailureResultAbsent=$true;inspectionTasksChanged=$false;processorTaskChanged=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false}
    [IO.File]::WriteAllText($gatePath,(($gate|ConvertTo-Json -Depth 8)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
    $gate|ConvertTo-Json -Depth 8
}finally{if($qCreated){Remove-PSDrive -Name Q -Scope Script -Force -ErrorAction Stop}}
