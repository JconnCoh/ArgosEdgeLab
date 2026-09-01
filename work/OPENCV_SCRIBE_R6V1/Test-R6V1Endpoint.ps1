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
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "R6V1 test create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpoint = Join-Path $PSScriptRoot 'Invoke-R6V1ScribeBatch.ps1'
$engine = Join-Path $project 'work\OPENCV_SCRIBE_V1R6\ArgosOpenCvScribeV1R6.py'
$batchSource = Join-Path $PSScriptRoot 'BATCH.json'
$bundle = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$runtime = 'C:\ArgosPy313\Scripts'
$sample = 'C:\Users\joshua.conn\Desktop\ArgosDev\ArgosEdgeLab\work\SCRIBE_REVIEW_ONLY\outputs\review_only\FS15_NOTCH_RELATIVE_SCRIBE_SEARCH_V2_20260804T181500Z\A01\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
$root = 'C:\R6V1T'
$payload = Join-Path $root 'p'
$input = Join-Path $root 'i'
$normal = Join-Path $root 'n'
$failure = Join-Path $root 'f'
$gatePath = Join-Path $PSScriptRoot 'R6V1_ENTRYPOINT_TEST_GATE_R2.json'
$expectedEngineSha = '1E4C55AA4ECFB4DA3CEA9DF577DCFE86C4A2FADCB23D29F78719F3E0AC55E0E9'
$expectedBundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$expectedSampleSha = '50ABDA519730E4CAD1014A14080264A403F19BB8CB1A7EE69821604652B8A150'

foreach ($path in @($endpoint,$engine,$batchSource,$bundle,(Join-Path $runtime 'python.exe'),$sample)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R6V1 test dependency absent: $path"
}
Assert-True ((Get-Sha256 $engine) -eq $expectedEngineSha) 'R6V1 test engine changed.'
Assert-True ((Get-Sha256 $bundle) -eq $expectedBundleSha) 'R6V1 test reference bundle changed.'
Assert-True ((Get-Sha256 $sample) -eq $expectedSampleSha) 'R6V1 test sample changed.'
foreach ($path in @($root,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R6V1 test target exists: $path" }

if ($Preflight) {
    [ordered]@{schema='argos_r6v1_endpoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V1_ENDPOINT_TEST_PREFLIGHT';endpointSha256=Get-Sha256 $endpoint;engineSha256=$expectedEngineSha;bundleSha256=$expectedBundleSha;sampleSha256=$expectedSampleSha;plannedCaseCount=4;mutationsPerformed=$false;processStarted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

try {
    [void](New-Item -ItemType Directory -Path $payload)
    [void](New-Item -ItemType Directory -Path $input)
    Copy-Item -LiteralPath $engine -Destination (Join-Path $payload 'ArgosOpenCvScribeV1R6.py')
    $batch = Get-Content -Raw -LiteralPath $batchSource | ConvertFrom-Json
    $batch.sourceAlias.root = $input
    $batch.workRoot = Join-Path $normal 'w'
    $batch.outputRoot = Join-Path $normal 'o'
    $batch.referenceBundle.path = $bundle
    foreach ($case in @($batch.cases)) {
        $slot = [string]$case.slot
        $sourceJob = Join-Path $PSScriptRoot ([string]$case.jobFile)
        $job = Get-Content -Raw -LiteralPath $sourceJob | ConvertFrom-Json
        $bfName = $slot + '_BF.png'
        $dfName = $slot + '_DF.png'
        Copy-Item -LiteralPath $sample -Destination (Join-Path $input $bfName)
        Copy-Item -LiteralPath $sample -Destination (Join-Path $input $dfName)
        foreach ($channel in @('bf','df')) {
            $name = if ($channel -eq 'bf') { $bfName } else { $dfName }
            $job.inputs.$channel.path = 'X:\' + $name
            $job.inputs.$channel.canonicalProvenancePath = Join-Path $input $name
            $job.inputs.$channel.aliasAnchorCanonicalPath = $input
            $job.inputs.$channel.sha256 = $expectedSampleSha
            $job.inputs.$channel.bytes = [int64](Get-Item -LiteralPath (Join-Path $input $name)).Length
        }
        $job.references.manifestPath = Join-Path $normal 'w\refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
        $job.references.roots[0].path = Join-Path $normal 'w\refs\glyphs'
        $job.references.roots[1].path = Join-Path $normal 'w\refs\glyphs_v5_confirmed_20260806'
        $job.outputRoot = Join-Path (Join-Path $normal 'o') $slot
        $jobPath = Join-Path $payload ([string]$case.jobFile)
        Write-JsonNew $jobPath $job
        $case.jobSha256 = Get-Sha256 $jobPath
    }
    $batchPath = Join-Path $payload 'BATCH.json'
    Write-JsonNew $batchPath $batch
    $endpointPreflight = (& $endpoint -Preflight -Rehearsal -PayloadRoot $payload -BatchManifestPath $batchPath -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $normal 'w') -OutputRoot (Join-Path $normal 'o') -SourceAliasRoot $input -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
    Assert-True ([string]$endpointPreflight.state -eq 'PASS_R6V1_SCRIBE_BATCH_PREFLIGHT' -and [int]$endpointPreflight.caseCount -eq 4 -and -not [bool]$endpointPreflight.mutationsPerformed) 'R6V1 exact endpoint preflight changed.'
    $result = (& $endpoint -Rehearsal -PayloadRoot $payload -BatchManifestPath $batchPath -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $normal 'w') -OutputRoot (Join-Path $normal 'o') -SourceAliasRoot $input -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
    Assert-True ([string]$result.state -eq 'PASS_R6V1_REAL_IMAGE_REVIEW_ONLY_BATCH' -and [int]$result.caseCount -eq 4 -and [int]$result.identityEligibleCount -eq 0) 'R6V1 normal four-case rehearsal changed.'
    Assert-True (@($result.results).Count -eq 4 -and @($result.results | Where-Object { @($_.holds | Where-Object { [string]$_.code -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD' }).Count -eq 1 }).Count -eq 4) 'R6V1 normal reference holds changed.'
    Assert-True ([bool]$result.sourceAliasRemoved -and -not (Test-Path -LiteralPath 'X:\')) 'R6V1 normal alias cleanup changed.'

    [void](New-Item -ItemType Directory -Path $failure)
    $badBatch = Get-Content -Raw -LiteralPath $batchPath | ConvertFrom-Json
    $badJobPath = Join-Path $failure 'S22_BAD.json'
    $badJob = Get-Content -Raw -LiteralPath (Join-Path $payload 'S22.json') | ConvertFrom-Json
    $badJob.inputs.bf.sha256 = '0000000000000000000000000000000000000000000000000000000000000000'
    Write-JsonNew $badJobPath $badJob
    $badBatch.cases[0].jobFile = 'S22_BAD.json'
    $badBatch.cases[0].jobSha256 = Get-Sha256 $badJobPath
    foreach ($case in @($badBatch.cases | Select-Object -Skip 1)) {
        Copy-Item -LiteralPath (Join-Path $payload ([string]$case.jobFile)) -Destination (Join-Path $failure ([string]$case.jobFile))
    }
    Copy-Item -LiteralPath $engine -Destination (Join-Path $failure 'ArgosOpenCvScribeV1R6.py')
    $badBatchPath = Join-Path $failure 'BATCH.json'
    Write-JsonNew $badBatchPath $badBatch
    $caught = $false
    try {
        & $endpoint -Rehearsal -PayloadRoot $failure -BatchManifestPath $badBatchPath -RuntimeRoot $runtime -ReferenceBundlePath $bundle -WorkRoot (Join-Path $failure 'w') -OutputRoot (Join-Path $failure 'o') -SourceAliasRoot $input -ExpectedComputerName $env:COMPUTERNAME 2>&1 | Out-Null
    }
    catch { if ($_.Exception.Message -match 'source hash changed: Slot22/bf') { $caught = $true } }
    Assert-True ($caught -and -not (Test-Path -LiteralPath (Join-Path $failure 'w')) -and -not (Test-Path -LiteralPath (Join-Path $failure 'o')) -and -not (Test-Path -LiteralPath 'X:\')) 'R6V1 injected source-hash failure did not fail before write with alias cleanup.'

    $gate = [ordered]@{schema='argos_r6v1_entrypoint_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V1_ENTRYPOINT_TEST_GATE_R2';endpointSha256=Get-Sha256 $endpoint;engineSha256=$expectedEngineSha;bundleSha256=$expectedBundleSha;caseCount=4;identityEligibleCount=0;referenceCoverageHoldCount=4;serializedProviderChildren=$true;automaticRetryAllowed=$false;sourceAliasRemovedOnSuccess=$true;sourceHashMismatchFailedBeforeWrite=$true;sourceAliasRemovedOnFailure=$true;processorIdentityUnchanged=$true;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false;providerActivated=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
    Write-JsonNew $gatePath $gate 12
    $gate | ConvertTo-Json -Depth 12
}
finally {
    if (Test-Path -LiteralPath $root) {
        $resolved = [IO.Path]::GetFullPath($root)
        Assert-True ($resolved -eq 'C:\R6V1T') 'R6V1 test cleanup root changed.'
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
