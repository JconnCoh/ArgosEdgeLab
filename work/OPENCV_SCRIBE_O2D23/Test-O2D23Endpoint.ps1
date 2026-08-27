#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D23 test create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpoint = Join-Path $PSScriptRoot 'Invoke-O2D23ScribeEndpoint.ps1'
$engine = Join-Path $project 'work\OPENCV_SCRIBE_V1R5\ArgosOpenCvScribeV1R5.py'
$liveJob = Join-Path $PSScriptRoot 'O2D23_SLOT25_JOB.json'
$bundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D4\final\extract\payload\O2D4_REFS.zip'
$runtime = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$sampleRoot = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\outputs\review_only\FS15_NOTCH_RELATIVE_SCRIBE_SEARCH_V2_20260804T181500Z\A01'
$sampleBf = Join-Path $sampleRoot 'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$sampleDf = $sampleBf
$selfPinGate = Join-Path $PSScriptRoot 'O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE.json'
$root = 'C:\O2D23T_3C97863D'
$payload = Join-Path $root 'p'
$input = Join-Path $root 'i'
$normal = Join-Path $root 'n'
$failure = Join-Path $root 'f'
$gatePath = Join-Path $PSScriptRoot 'O2D23_ENTRYPOINT_TEST_GATE_R2.json'
$bfSha = '50ABDA519730E4CAD1014A14080264A403F19BB8CB1A7EE69821604652B8A150'
$dfSha = '50ABDA519730E4CAD1014A14080264A403F19BB8CB1A7EE69821604652B8A150'
$selfPinGateSha = 'F00DED7060A9E8FB269670B0D89AEEA50241A82D1E6C0D5B74571B9AB91E1FD5'

foreach ($path in @($endpoint,$engine,$liveJob,$bundle,(Join-Path $runtime 'python.exe'),$sampleBf,$sampleDf,$selfPinGate)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D23 test dependency absent: $path"
}
Assert-True ((Get-Sha256 $endpoint) -eq '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740') 'O2D23 endpoint changed.'
Assert-True ((Get-Sha256 $engine) -eq 'F61F5954A77E6F730A2BF0D110A468535C4595D25DB21AFFE1573EF08B8139AB') 'O2D23 test engine changed.'
Assert-True ((Get-Sha256 $bundle) -eq '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6') 'O2D23 test bundle changed.'
Assert-True ((Get-Sha256 $sampleBf) -eq $bfSha -and (Get-Sha256 $sampleDf) -eq $dfSha) 'O2D23 test sample changed.'
Assert-True ((Get-Sha256 $selfPinGate) -eq $selfPinGateSha) 'O2D23 self-pin gate changed.'
$selfPin = Get-Content -Raw -LiteralPath $selfPinGate | ConvertFrom-Json
Assert-True ([string]$selfPin.state -eq 'PASS_O2D23_SELF_PIN_AND_LIVE_BRANCH_GATE' -and [int]$selfPin.pinMatchCount -eq 6 -and @($selfPin.liveBranchCases | Where-Object { [string]$_.state -eq 'PASS' }).Count -eq 3) 'O2D23 self-pin/live-branch contract changed.'
foreach ($path in @($root,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D23 test target exists: $path" }
$tokens = $null
$parserErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($endpoint, [ref]$tokens, [ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'O2D23 endpoint Windows PowerShell parser failed.'

if ($Preflight) {
    [ordered]@{schema='argos_o2d23_entrypoint_test_preflight_v2';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ENTRYPOINT_TEST_PREFLIGHT_R2';endpointSha256=Get-Sha256 $endpoint;engineSha256=Get-Sha256 $engine;bundleSha256=Get-Sha256 $bundle;selfPinGateSha256=$selfPinGateSha;mutationsPerformed=$false;processStarted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

try {
    [void](New-Item -ItemType Directory -Path $payload)
    [void](New-Item -ItemType Directory -Path $input)
    Copy-Item -LiteralPath $engine -Destination (Join-Path $payload 'ArgosOpenCvScribeV1R5.py')
    Copy-Item -LiteralPath $sampleBf -Destination (Join-Path $input 'BF.png')
    Copy-Item -LiteralPath $sampleDf -Destination (Join-Path $input 'DF.png')
    $job = Get-Content -Raw -LiteralPath $liveJob | ConvertFrom-Json
    $job.revision = 'OCV02_O2D23_REHEARSAL_73C073D0'
    $job.jobId = 'O2D23_REHEARSAL_73C073D0'
    $job.identity.lotId = '62631-535'
    $job.identity.acquisitionId = '62631-535_20260730105033'
    $job.identity.slotId = 'Slot16'
    $job.identity.physicalIdentity = '62631-535_20260730105033_Slot16'
    $job.inputs.bf.path = 'X:\BF.png'
    $job.inputs.bf.canonicalProvenancePath = Join-Path $input 'BF.png'
    $job.inputs.bf.aliasAnchorCanonicalPath = $input
    $job.inputs.bf.sha256 = $bfSha
    $job.inputs.bf.bytes = [int64](Get-Item -LiteralPath $job.inputs.bf.canonicalProvenancePath).Length
    $job.inputs.df.path = 'X:\DF.png'
    $job.inputs.df.canonicalProvenancePath = Join-Path $input 'DF.png'
    $job.inputs.df.aliasAnchorCanonicalPath = $input
    $job.inputs.df.sha256 = $dfSha
    $job.inputs.df.bytes = [int64](Get-Item -LiteralPath $job.inputs.df.canonicalProvenancePath).Length
    $job.references.excludedPhysicalIdentity = $job.identity.physicalIdentity
    $job.references.manifestPath = Join-Path $normal 'w\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $job.references.roots[0].path = Join-Path $normal 'w\refs\glyphs'
    $job.references.roots[1].path = Join-Path $normal 'w\refs\glyphs_v5_confirmed_20260806'
    $job.outputRoot = Join-Path $normal 'o'
    $jobPath = Join-Path $payload 'O2D23_SLOT25_JOB.json'
    Write-JsonNew $jobPath $job 20

    $preflightJson = & $endpoint -Preflight -Rehearsal -PayloadRoot $payload -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $normal 'w') -OutputRoot (Join-Path $normal 'o') -SourceAliasRoot $input -RehearsalJobPath $jobPath -ExpectedComputerName $env:COMPUTERNAME | Out-String
    $endpointPreflight = $preflightJson | ConvertFrom-Json
    Assert-True ([string]$endpointPreflight.state -eq 'PASS_O2D23_ENDPOINT_PREFLIGHT' -and -not [bool]$endpointPreflight.processStarted -and -not [bool]$endpointPreflight.mutationsPerformed) 'O2D23 endpoint preflight changed.'

    $normalJson = & $endpoint -Rehearsal -PayloadRoot $payload -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $normal 'w') -OutputRoot (Join-Path $normal 'o') -SourceAliasRoot $input -RehearsalJobPath $jobPath -ExpectedComputerName $env:COMPUTERNAME | Out-String
    $normalResult = $normalJson | ConvertFrom-Json
    Assert-True ([string]$normalResult.state -eq 'PASS_O2D23_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED') 'O2D23 normal rehearsal state changed.'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$normalResult.imageFirstString) -and [string]$normalResult.checksumState -ne 'NOT_EVALUATED' -and [int]$normalResult.localization.autoLocalizedPromotedCandidateCount -gt 0) 'O2D23 normal rehearsal did not evaluate an auto-localized scribe.'
    Assert-True (@($normalResult.holds | Where-Object { [string]$_.code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' }).Count -eq 1) 'O2D23 normal rehearsal coverage hold changed.'
    Assert-True ([bool]$normalResult.upstreamNotchHoldDidNotSkipScribe -and [string]$normalResult.upstreamProposalState -eq 'SCRIBE_IDENTITY_CONFIRMATION_HOLD') 'O2D23 upstream-hold boundary changed.'
    Assert-True ([bool]$normalResult.sourceAliasRemoved -and -not (Test-Path -LiteralPath 'X:\')) 'O2D23 source alias was not removed.'
    Assert-True (-not [bool]$normalResult.taskOrProcessRestarted -and -not [bool]$normalResult.providerActivated -and -not [bool]$normalResult.productionEligible) 'O2D23 normal rehearsal authority changed.'

    [void](New-Item -ItemType Directory -Path $failure)
    $bad = Get-Content -Raw -LiteralPath $jobPath | ConvertFrom-Json
    $bad.inputs.bf.sha256 = '0000000000000000000000000000000000000000000000000000000000000000'
    $bad.references.manifestPath = Join-Path $failure 'w\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $bad.references.roots[0].path = Join-Path $failure 'w\refs\glyphs'
    $bad.references.roots[1].path = Join-Path $failure 'w\refs\glyphs_v5_confirmed_20260806'
    $bad.outputRoot = Join-Path $failure 'o'
    $badPath = Join-Path $failure 'BAD_JOB.json'
    Write-JsonNew $badPath $bad 20
    $caught = $false
    try {
        & $endpoint -Rehearsal -PayloadRoot $payload -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $failure 'w') -OutputRoot (Join-Path $failure 'o') -SourceAliasRoot $input -RehearsalJobPath $badPath -ExpectedComputerName $env:COMPUTERNAME 2>&1 | Out-Null
    }
    catch {
        if ($_.Exception.Message -match 'source hash changed: bf') { $caught = $true }
    }
    Assert-True ($caught -and -not (Test-Path -LiteralPath (Join-Path $failure 'w')) -and -not (Test-Path -LiteralPath (Join-Path $failure 'o'))) 'O2D23 injected source-hash failure did not fail before write.'

    $gate = [ordered]@{
        schema='argos_o2d23_entrypoint_test_gate_v2';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_ENTRYPOINT_TEST_GATE_R2';revision='O2D23_20260827T035500000Z_3C97863D'
        endpointSha256=Get-Sha256 $endpoint;engineSha256=Get-Sha256 $engine;bundleSha256=Get-Sha256 $bundle;selfPinGateSha256=$selfPinGateSha;normalResultState=[string]$normalResult.resultState
        normalImageFirstString=[string]$normalResult.imageFirstString;normalChecksumState=[string]$normalResult.checksumState;readerEvaluated=$true;referenceCoverageHoldPreserved=$true;automaticLocalizationHoldPreserved=$true;upstreamNotchHoldDidNotSkipScribe=$true;sourceAliasRemoved=$true;injectedHashMismatchFailedBeforeWrite=$true
        processorIdentityUnchanged=$true;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false
    }
    Write-JsonNew $gatePath $gate 10
    $gate | ConvertTo-Json -Depth 10
}
finally {
    if (Test-Path -LiteralPath $root) {
        $resolved = [IO.Path]::GetFullPath($root)
        Assert-True ($resolved -eq 'C:\O2D23T_3C97863D') 'O2D23 test cleanup root changed.'
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
