#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D10 test create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpoint = Join-Path $PSScriptRoot 'Invoke-O2D10ScribeEndpoint.ps1'
$engine = Join-Path $project 'work\OPENCV_SCRIBE_V1R3\ArgosOpenCvScribeV1R3.py'
$liveJob = Join-Path $PSScriptRoot 'O2D10_SLOT16_JOB.json'
$bundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D4\final\extract\payload\O2D4_REFS.zip'
$runtime = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$sampleRoot = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\diagnostics\SCRIBE_READER_FAILURE_DIAGNOSTIC_V1_20260806T201825Z\62631-535_20260730105033_Slot16'
$sampleBf = Join-Path $sampleRoot 'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$sampleDf = Join-Path $sampleRoot 'DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$root = 'C:\O2D10T_F5D37325'
$payload = Join-Path $root 'p'
$input = Join-Path $root 'i'
$normal = Join-Path $root 'n'
$failure = Join-Path $root 'f'
$gatePath = Join-Path $PSScriptRoot 'O2D10_ENTRYPOINT_TEST_GATE.json'
$bfSha = '094353365C010DA2C1AB67EBAE1097D3F783E80379BBB585D1F4B531C29EA2EE'
$dfSha = '79232E8A8FAC6634048CFE9EDAFF34467EBF21BEACC55A47E2B3CAA91B82426C'

foreach ($path in @($endpoint,$engine,$liveJob,$bundle,(Join-Path $runtime 'python.exe'),$sampleBf,$sampleDf)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D10 test dependency absent: $path"
}
Assert-True ((Get-Sha256 $engine) -eq '8A6DE04B7DD08EFA717AF606FD0D04622ABE84C753B690C4590B0E95D8B31BAB') 'O2D10 test engine changed.'
Assert-True ((Get-Sha256 $bundle) -eq '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6') 'O2D10 test bundle changed.'
Assert-True ((Get-Sha256 $sampleBf) -eq $bfSha -and (Get-Sha256 $sampleDf) -eq $dfSha) 'O2D10 test sample changed.'
foreach ($path in @($root,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "O2D10 test target exists: $path" }
$tokens = $null
$parserErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($endpoint, [ref]$tokens, [ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'O2D10 endpoint Windows PowerShell parser failed.'

if ($Preflight) {
    [ordered]@{schema='argos_o2d10_entrypoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_ENTRYPOINT_TEST_PREFLIGHT';endpointSha256=Get-Sha256 $endpoint;engineSha256=Get-Sha256 $engine;bundleSha256=Get-Sha256 $bundle;mutationsPerformed=$false;processStarted=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

try {
    [void](New-Item -ItemType Directory -Path $payload)
    [void](New-Item -ItemType Directory -Path $input)
    Copy-Item -LiteralPath $engine -Destination (Join-Path $payload 'ArgosOpenCvScribeV1R3.py')
    Copy-Item -LiteralPath $sampleBf -Destination (Join-Path $input 'BF.png')
    Copy-Item -LiteralPath $sampleDf -Destination (Join-Path $input 'DF.png')
    $proposalPath = Join-Path $input 'P.json'
    $summaryPath = Join-Path $input 'S.json'
    Write-JsonNew $proposalPath ([ordered]@{schema='rehearsal_proposal_v1';eligibleIdentity=$false}) 4
    Write-JsonNew $summaryPath ([ordered]@{schema='rehearsal_summary_v1';consensusState='MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES'}) 4

    $job = Get-Content -Raw -LiteralPath $liveJob | ConvertFrom-Json
    $job.revision = 'OCV02_O2D10_REHEARSAL_F5D37325'
    $job.jobId = 'O2D10_REHEARSAL_F5D37325'
    $job.identity.lotId = '62631-535'
    $job.identity.acquisitionId = '62631-535_20260730105033'
    $job.identity.slotId = 'Slot16'
    $job.identity.physicalIdentity = '62631-535_20260730105033_Slot16'
    $job.inputQualification.physicalIdentity = '62631-535_20260730105033_Slot16'
    $job.inputQualification.proposalPath = $proposalPath
    $job.inputQualification.proposalSha256 = Get-Sha256 $proposalPath
    $job.inputQualification.multiChannelSummaryPath = $summaryPath
    $job.inputQualification.multiChannelSummarySha256 = Get-Sha256 $summaryPath
    $job.inputs.bf.path = Join-Path $input 'BF.png'
    $job.inputs.bf.canonicalProvenancePath = $job.inputs.bf.path
    $job.inputs.bf.sha256 = $bfSha
    $job.inputs.bf.bytes = [int64](Get-Item -LiteralPath $job.inputs.bf.path).Length
    $job.inputs.df.path = Join-Path $input 'DF.png'
    $job.inputs.df.canonicalProvenancePath = $job.inputs.df.path
    $job.inputs.df.sha256 = $dfSha
    $job.inputs.df.bytes = [int64](Get-Item -LiteralPath $job.inputs.df.path).Length
    $job.references.excludedPhysicalIdentity = $job.identity.physicalIdentity
    $job.references.manifestPath = Join-Path $normal 'w\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $job.references.roots[0].path = Join-Path $normal 'w\refs\glyphs'
    $job.references.roots[1].path = Join-Path $normal 'w\refs\glyphs_v5_confirmed_20260806'
    $job.outputRoot = Join-Path $normal 'o'
    $jobPath = Join-Path $payload 'O2D10_SLOT16_JOB.json'
    Write-JsonNew $jobPath $job 20

    $preflightJson = & $endpoint -Preflight -Rehearsal -PayloadRoot $payload -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $normal 'w') -OutputRoot (Join-Path $normal 'o') -RehearsalJobPath $jobPath -ExpectedComputerName $env:COMPUTERNAME | Out-String
    $endpointPreflight = $preflightJson | ConvertFrom-Json
    Assert-True ([string]$endpointPreflight.state -eq 'PASS_O2D10_ENDPOINT_PREFLIGHT' -and -not [bool]$endpointPreflight.processStarted -and -not [bool]$endpointPreflight.mutationsPerformed) 'O2D10 endpoint preflight changed.'

    $normalJson = & $endpoint -Rehearsal -PayloadRoot $payload -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $normal 'w') -OutputRoot (Join-Path $normal 'o') -RehearsalJobPath $jobPath -ExpectedComputerName $env:COMPUTERNAME | Out-String
    $normalResult = $normalJson | ConvertFrom-Json
    Assert-True ([string]$normalResult.state -eq 'PASS_O2D10_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED') 'O2D10 normal rehearsal state changed.'
    Assert-True (@($normalResult.holds | Where-Object { [string]$_.code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' }).Count -eq 1) 'O2D10 normal rehearsal coverage hold changed.'
    Assert-True (-not [bool]$normalResult.installedProposalEligibleIdentity -and [string]$normalResult.installedConsensusState -eq 'MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES') 'O2D10 installed ambiguity preservation changed.'
    Assert-True (-not [bool]$normalResult.taskOrProcessRestarted -and -not [bool]$normalResult.providerActivated -and -not [bool]$normalResult.productionEligible) 'O2D10 normal rehearsal authority changed.'

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
        & $endpoint -Rehearsal -PayloadRoot $payload -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $failure 'w') -OutputRoot (Join-Path $failure 'o') -RehearsalJobPath $badPath -ExpectedComputerName $env:COMPUTERNAME 2>&1 | Out-Null
    }
    catch {
        if ($_.Exception.Message -match 'source hash changed: bf') { $caught = $true }
    }
    Assert-True ($caught -and -not (Test-Path -LiteralPath (Join-Path $failure 'w')) -and -not (Test-Path -LiteralPath (Join-Path $failure 'o'))) 'O2D10 injected source-hash failure did not fail before write.'

    $gate = [ordered]@{
        schema='argos_o2d10_entrypoint_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D10_ENTRYPOINT_TEST_GATE';revision='O2D10_20260826T015418549Z_F5D37325'
        endpointSha256=Get-Sha256 $endpoint;engineSha256=Get-Sha256 $engine;bundleSha256=Get-Sha256 $bundle;normalResultState=[string]$normalResult.resultState
        normalImageFirstString=[string]$normalResult.imageFirstString;referenceCoverageHoldPreserved=$true;installedAmbiguityPreserved=$true;injectedHashMismatchFailedBeforeWrite=$true
        processorIdentityUnchanged=$true;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false
    }
    Write-JsonNew $gatePath $gate 10
    $gate | ConvertTo-Json -Depth 10
}
finally {
    if (Test-Path -LiteralPath $root) {
        $resolved = [IO.Path]::GetFullPath($root)
        Assert-True ($resolved -eq 'C:\O2D10T_F5D37325') 'O2D10 test cleanup root changed.'
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
