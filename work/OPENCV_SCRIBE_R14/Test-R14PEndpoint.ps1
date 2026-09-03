#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$revision = 'OCV02_R14P_ALPHABET_CROP_20260902A'
$endpointSha256 = '65BEC4B588BD7E35C597B133087E7758432A8763BBE7F424CDD80B45B028D4D2'
$configurationSha256 = 'F4D8C7CC631F351D4FEF680C30AF228942E9B9E2CCC0ABE458CB186A612EE601'
$installationSha256 = '7EA60AC1E8867B1BCA06408CFB8B29FBC63BE946BD83C2D696BCBCCDBA2B7CED'
$referenceBundleSha256 = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$dependencyPins = @(
    [ordered]@{name='R11.py';source='work\OPENCV_SCRIBE_R11A\ArgosOpenCvScribeV1R11.py';sha256='7C6632B2D1C56DA4CA565DAB5BF7D46A366BCAE6663793CE5AB1ABB4739F72C9'},
    [ordered]@{name='R12A.py';source='work\OPENCV_SCRIBE_R12A\Run-ArgosOpenCvScribeR12BlobDiagnostic.py';sha256='F5EB8FB3281D7D55CDD9FA4A3530A32BD33BBA3B8DB69E0A247C20935F6AD429'},
    [ordered]@{name='R12B.py';source='work\OPENCV_SCRIBE_R12B\Run-ArgosOpenCvScribeR12BBlobTopology.py';sha256='D670CFCE64BF5FDF5307E69ED69A05CB7B404A78B521AB889C7F35044D666FDC'}
)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToUpperInvariant()
}

function Write-TextNew([string]$Path, [string]$Text) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Write-TextNew $Path (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine)
}

function Write-SourceFixture([string]$Path, [string]$Seed, [int]$Length) {
    [void][IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    $seedBytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Seed)
    $bytes = New-Object byte[] $Length
    for ($index = 0; $index -lt $bytes.Length; $index++) { $bytes[$index] = $seedBytes[$index % $seedBytes.Length] }
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) }
    finally { $stream.Dispose() }
}

function Copy-Pinned([string]$Source, [string]$Destination, [string]$Sha256) {
    Assert-True ((Get-Sha256 $Source) -eq $Sha256) "R14P endpoint-test source pin changed: $Source"
    [IO.File]::Copy($Source, $Destination, $false)
    Assert-True ((Get-Sha256 $Destination) -eq $Sha256) "R14P endpoint-test copy changed: $Destination"
}

function New-Scenario(
    [string]$Name,
    [string]$ScenarioRoot,
    [string]$SourceRoot,
    [string]$StubSource,
    [string]$ProjectRoot,
    [string]$Endpoint,
    [string]$Configuration,
    [string]$BaseInvocation,
    [string]$Installation,
    [string]$ReferenceBundle
) {
    [void][IO.Directory]::CreateDirectory($ScenarioRoot)
    $payloadRoot = Join-Path $ScenarioRoot 'p'
    [void][IO.Directory]::CreateDirectory($payloadRoot)
    Copy-Pinned $Endpoint (Join-Path $payloadRoot 'Invoke-R14P.ps1') $endpointSha256
    Copy-Pinned $Configuration (Join-Path $payloadRoot 'CFG.json') $configurationSha256
    foreach ($pin in $dependencyPins) {
        Copy-Pinned (Join-Path $ProjectRoot ([string]$pin.source)) (Join-Path $payloadRoot ([string]$pin.name)) ([string]$pin.sha256)
    }
    Write-TextNew (Join-Path $payloadRoot 'R14P.py') $StubSource
    $providerSha256 = Get-Sha256 (Join-Path $payloadRoot 'R14P.py')

    $invocation = Get-Content -Raw -LiteralPath $BaseInvocation | ConvertFrom-Json
    $invocation.expectedComputerName = $env:COMPUTERNAME
    $invocation.runtime.root = 'C:\Python314'
    $invocation.runtime.python = 'C:\Python314\python.exe'
    $invocation.runtime.installationEvidence = $Installation
    $invocation.runtime.installationSha256 = $installationSha256
    $invocation.referenceBundle.path = $ReferenceBundle
    $invocation.roots.work = Join-Path $ScenarioRoot 'w'
    $invocation.roots.workPartial = (Join-Path $ScenarioRoot 'w.partial')
    $invocation.roots.workFailed = (Join-Path $ScenarioRoot 'w.failed')
    $invocation.roots.output = Join-Path $ScenarioRoot 'o'
    $invocation.roots.outputPartial = (Join-Path $ScenarioRoot 'o.partial')
    $invocation.roots.bundle = Join-Path $ScenarioRoot 'r.zip'
    $invocation.payload.provider.sha256 = $providerSha256
    foreach ($case in @($invocation.cases)) {
        $case.sourceBytesPerImage = 4096
        $case | Add-Member -MemberType NoteProperty -Name sourceRoot -Value $SourceRoot
    }
    $livePath = Join-Path $payloadRoot 'LIVE.json'
    Write-JsonNew $livePath $invocation 32
    $payloadLeaves = @(Get-ChildItem -LiteralPath $payloadRoot -File)
    Assert-True ($payloadLeaves.Count -eq 7) "R14P $Name fixture does not contain exactly seven payload leaves."
    foreach ($expectedLeaf in @('Invoke-R14P.ps1','R14P.py','R11.py','R12A.py','R12B.py','CFG.json','LIVE.json')) {
        Assert-True (@($payloadLeaves | Where-Object { $_.Name -ceq $expectedLeaf }).Count -eq 1) "R14P $Name fixture leaf changed: $expectedLeaf"
    }
    return [pscustomobject]@{
        name=$Name
        root=$ScenarioRoot
        endpoint=(Join-Path $payloadRoot 'Invoke-R14P.ps1')
        invocation=$livePath
        invocationSha256=Get-Sha256 $livePath
        providerSha256=$providerSha256
        output=(Join-Path $ScenarioRoot 'o')
        work=(Join-Path $ScenarioRoot 'w')
        bundle=(Join-Path $ScenarioRoot 'r.zip')
    }
}

function Invoke-EndpointJson([object]$Scenario, [switch]$OnlyPreflight) {
    $rows = @(if ($OnlyPreflight) {
        @(& $Scenario.endpoint -Rehearsal -Preflight -InvocationManifest $Scenario.invocation)
    }
    else {
        @(& $Scenario.endpoint -Rehearsal -InvocationManifest $Scenario.invocation)
    })
    $text = [string]($rows -join [Environment]::NewLine)
    Assert-True (-not [string]::IsNullOrWhiteSpace($text)) "R14P $($Scenario.name) endpoint emitted no JSON."
    return $text | ConvertFrom-Json
}

Assert-True ([bool]$Preflight -xor [bool]$Gate) 'Specify exactly one of -Preflight or -Gate.'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpointPath = Join-Path $PSScriptRoot 'Invoke-R14P.ps1'
$configurationPath = Join-Path $PSScriptRoot 'R14P_CONFIGURATION.json'
$baseInvocationPath = Join-Path $PSScriptRoot 'R14P_LIVE_INVOCATION.json'
$installationPath = Join-Path $projectRoot 'work\OPENCV_SCRIBE_O2D23\fixtures\INSTALLATION.json'
$referenceBundlePath = Join-Path $projectRoot 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$pythonPath = 'C:\Python314\python.exe'
$successEvidencePath = Join-Path $PSScriptRoot 'R14P_ENDPOINT_SUCCESS_REHEARSAL_INVOCATION.json'
$failureEvidencePath = Join-Path $PSScriptRoot 'R14P_ENDPOINT_FAILURE_REHEARSAL_INVOCATION.json'
$gatePath = Join-Path $PSScriptRoot 'R14P_ENDPOINT_REHEARSAL_GATE.json'

foreach ($path in @($endpointPath,$configurationPath,$baseInvocationPath,$installationPath,$referenceBundlePath,$pythonPath)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R14P endpoint-test dependency absent: $path"
}
Assert-True ((Get-Sha256 $endpointPath) -eq $endpointSha256) 'R14P endpoint changed after the endpoint-test self pin.'
Assert-True ((Get-Sha256 $configurationPath) -eq $configurationSha256) 'R14P configuration changed before endpoint test.'
Assert-True ((Get-Sha256 $installationPath) -eq $installationSha256) 'R14P rehearsal installation fixture changed.'
Assert-True ((Get-Sha256 $referenceBundlePath) -eq $referenceBundleSha256) 'R14P rehearsal reference ZIP changed.'
foreach ($pin in $dependencyPins) { Assert-True ((Get-Sha256 (Join-Path $projectRoot ([string]$pin.source))) -eq [string]$pin.sha256) "R14P dependency changed: $($pin.name)" }

if ($Preflight) {
    [ordered]@{
        schema='argos_opencv_scribe_r14p_endpoint_test_preflight_v1';revision=$revision;checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R14P_ENDPOINT_TEST_PREFLIGHT'
        endpointSha256=$endpointSha256;configurationSha256=$configurationSha256;installationFixtureSha256=$installationSha256;referenceBundleSha256=$referenceBundleSha256
        sourceImageBytesRead=$false;pixelsDecoded=$false;childProcessStarted=$false;filesystemMutationPerformed=$false;aliasMutationPerformed=$false;productionRoutingEnabled=$false
    } | ConvertTo-Json -Compress -Depth 8
    return
}

foreach ($path in @($successEvidencePath,$failureEvidencePath,$gatePath)) { Assert-True (-not (Test-Path -LiteralPath $path)) "R14P endpoint-test create-new evidence exists: $path" }
$substPath = Join-Path $env:SystemRoot 'System32\subst.exe'
$substBefore = & $substPath 2>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0 -and $substBefore -notmatch '(?im)^\s*X:\\:\s*=>') 'R14P endpoint test requires X: to be unused.'
$testRoot = 'C:\R14PG_' + $PID + '_' + [DateTime]::UtcNow.ToString('HHmmss')
Assert-True ($testRoot -match '^C:\\R14PG_[0-9]+_[0-9]{6}$' -and -not (Test-Path -LiteralPath $testRoot)) 'R14P endpoint-test root is not fresh and bounded.'

$successStub = @'
import hashlib, json, sys
from pathlib import Path

job = json.loads(Path(sys.argv[sys.argv.index("--job") + 1]).read_text(encoding="utf-8"))
output = Path(sys.argv[sys.argv.index("--output-root") + 1])
partial = Path(str(output) + ".partial")
partial.mkdir()
artifacts = []

def put(relative, payload):
    path = partial / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(payload)
    return hashlib.sha256(payload).hexdigest().upper()

pair = job["runtimeBinding"]["sourcePairSha256"]
grid_sha = put("selected_grid.png", ("GRID:" + job["caseId"]).encode("ascii"))
artifacts.append({"kind":"ORIENTED_GRID","relativePath":"selected_grid.png","sha256":grid_sha,"sourceChannel":"BF_DF_DERIVED","sourceSha256":pair})
cell_hashes = {}
for position, label in enumerate(job["canonicalTruth"], 1):
    relative = f"cells/P{position:02d}_{label}.png"
    cell_sha = put(relative, f"CELL:{job['caseId']}:{position}:{label}".encode("ascii"))
    cell_hashes[position] = cell_sha
    artifacts.append({"kind":"AUDIT_CELL","relativePath":relative,"sha256":cell_sha,"sourceChannel":"SELECTED_GRID","sourceSha256":grid_sha})
for target in job["targetPositions"]:
    position = int(target["position"])
    label = target["label"]
    relative = f"targets/P{position:02d}_{label}.png"
    target_sha = put(relative, f"CELL:{job['caseId']}:{position}:{label}".encode("ascii"))
    artifacts.append({"kind":"TARGET_GLYPH","relativePath":relative,"sha256":target_sha,"sourceChannel":"AUDIT_CELL","sourceSha256":cell_hashes[position]})
authority = {"reviewOnly":True,"automaticIdentityAuthority":False,"automaticReferenceAdmissionAllowed":False,"trainingAuthorized":False,"trainingEligible":False,"trainingExecuted":False,"xmlEligible":False,"productionEligible":False,"productionRoutingEnabled":False,"mayClearHolds":False}
result = {"schema":"argos_opencv_scribe_alphabet_crop_case_result_v1","revision":"ARGOS_OPENCV_SCRIBE_ALPHABET_CROP_R14P_20260902","classification":"PENDING_GATE","state":"HOLD_R14P_REVIEW_ONLY_GRID_SELECTED","caseId":job["caseId"],"jobId":job["jobId"],"physicalIdentity":job["physicalIdentity"],"purpose":job["purpose"],"canonicalTruth":job["canonicalTruth"],"provenance":{"sources":{"bf":{"sha256":job["inputs"]["bf"]["sha256"]},"df":{"sha256":job["inputs"]["df"]["sha256"]}},"sourcePairSha256":pair},"artifacts":artifacts,"authority":authority}
(partial / "CASE_RESULT.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
partial.rename(output)
print(json.dumps({"state":result["state"],"caseId":job["caseId"],"artifactCount":len(artifacts)}))
'@

$failureStub = @'
import json, sys
from pathlib import Path
job = json.loads(Path(sys.argv[sys.argv.index("--job") + 1]).read_text(encoding="utf-8"))
output = Path(sys.argv[sys.argv.index("--output-root") + 1])
output.mkdir()
(output / "CASE_RESULT.json").write_text('{"schema":"INJECTED_INVALID_RESULT"}\n', encoding="utf-8")
print(json.dumps({"state":"INJECTED_INVALID_RESULT","caseId":job["caseId"]}))
'@

$sourceRows = New-Object Collections.Generic.List[object]
$sourceRoot = Join-Path $testRoot 's'
$success = $null
$failure = $null
try {
    [void][IO.Directory]::CreateDirectory($testRoot)
    $baseInvocation = Get-Content -Raw -LiteralPath $baseInvocationPath | ConvertFrom-Json
    foreach ($case in @($baseInvocation.cases)) {
        foreach ($channel in @('bf','df')) {
            $relative = if ($channel -eq 'bf') { [string]$case.bfRelativePath } else { [string]$case.dfRelativePath }
            $path = Join-Path $sourceRoot $relative
            Write-SourceFixture $path (([string]$case.caseId) + ':' + $channel) 4096
            $sourceRows.Add([pscustomobject]@{caseId=[string]$case.caseId;channel=$channel;path=$path;bytes=[int64](Get-Item -LiteralPath $path).Length;sha256=Get-Sha256 $path})
        }
    }

    $success = New-Scenario 'SUCCESS' (Join-Path $testRoot 'a') $sourceRoot $successStub $projectRoot $endpointPath $configurationPath $baseInvocationPath $installationPath $referenceBundlePath
    $successPreflight = Invoke-EndpointJson $success -OnlyPreflight
    Assert-True ([string]$successPreflight.state -eq 'PASS_R14P_STRICTLY_NONMUTATING_PREFLIGHT' -and [int]$successPreflight.caseCount -eq 4 -and -not [bool]$successPreflight.sourceImageBytesRead -and -not [bool]$successPreflight.filesystemMutationPerformed) 'R14P success rehearsal preflight contract failed.'
    $successResponse = Invoke-EndpointJson $success
    Assert-True ([string]$successResponse.state -eq 'PASS_R14P_SIGNED_RETURN_READY' -and [int]$successResponse.caseCount -eq 4 -and [int]$successResponse.caseLaunchFailureCount -eq 0 -and [int]$successResponse.providerCompletedCount -eq 4) 'R14P success endpoint envelope failed.'
    $successBatchPath = Join-Path $success.output 'BATCH_GATE.json'
    $successBatch = Get-Content -Raw -LiteralPath $successBatchPath | ConvertFrom-Json
    Assert-True ([int]$successBatch.caseCount -eq 4 -and [int]$successBatch.providerCompletedCount -eq 4 -and [int]$successBatch.pixelsDecodedCaseCount -eq 4 -and [int]$successBatch.caseLaunchFailureCount -eq 0) 'R14P success batch gate failed.'
    foreach ($case in @($successBatch.cases)) {
        Assert-True ([bool]$case.providerCompleted -and [bool]$case.pixelsDecodedByOpenCv -and -not [bool]$case.attemptQuarantined) "R14P success case state failed: $($case.caseId)"
        $result = Get-Content -Raw -LiteralPath (Join-Path $success.output (([string]$case.caseId) + '\CASE_RESULT.json')) | ConvertFrom-Json
        $targetCount = 1
        if ([string]$case.caseId -in @('JQ16D','JQ20V')) { $targetCount = 2 }
        Assert-True ([string]$result.state -eq 'HOLD_R14P_REVIEW_ONLY_GRID_SELECTED' -and @($result.artifacts).Count -eq (13 + $targetCount)) "R14P success result failed: $($case.caseId)"
    }

    $failure = New-Scenario 'FAILURE' (Join-Path $testRoot 'b') $sourceRoot $failureStub $projectRoot $endpointPath $configurationPath $baseInvocationPath $installationPath $referenceBundlePath
    $failurePreflight = Invoke-EndpointJson $failure -OnlyPreflight
    Assert-True ([string]$failurePreflight.state -eq 'PASS_R14P_STRICTLY_NONMUTATING_PREFLIGHT' -and [int]$failurePreflight.caseCount -eq 4 -and -not [bool]$failurePreflight.sourceImageBytesRead -and -not [bool]$failurePreflight.filesystemMutationPerformed) 'R14P failure rehearsal preflight contract failed.'
    $failureResponse = Invoke-EndpointJson $failure
    Assert-True ([string]$failureResponse.state -eq 'PASS_R14P_SIGNED_RETURN_READY' -and [int]$failureResponse.caseCount -eq 4 -and [int]$failureResponse.caseLaunchFailureCount -eq 4 -and [int]$failureResponse.providerCompletedCount -eq 0) 'R14P injected-failure endpoint envelope failed.'
    $failureBatchPath = Join-Path $failure.output 'BATCH_GATE.json'
    $failureBatch = Get-Content -Raw -LiteralPath $failureBatchPath | ConvertFrom-Json
    Assert-True ([int]$failureBatch.caseCount -eq 4 -and [int]$failureBatch.providerCompletedCount -eq 0 -and [int]$failureBatch.pixelsDecodedCaseCount -eq 0 -and [int]$failureBatch.caseLaunchFailureCount -eq 4) 'R14P injected-failure batch gate failed.'
    foreach ($case in @($failureBatch.cases)) {
        $caseId = [string]$case.caseId
        Assert-True (-not [bool]$case.providerCompleted -and -not [bool]$case.pixelsDecodedByOpenCv -and [bool]$case.attemptQuarantined) "R14P injected-failure quarantine state failed: $caseId"
        $caseFiles = @(Get-ChildItem -LiteralPath (Join-Path $failure.output $caseId) -File)
        Assert-True ($caseFiles.Count -eq 1 -and $caseFiles[0].Name -eq 'CASE_RESULT.json') "R14P injected-failure compact output failed: $caseId"
        $result = Get-Content -Raw -LiteralPath $caseFiles[0].FullName | ConvertFrom-Json
        Assert-True ([string]$result.state -eq 'HOLD_R14P_CASE_LAUNCH_FAILURE' -and @($result.artifacts).Count -eq 0) "R14P injected-failure result failed: $caseId"
        Assert-True (Test-Path -LiteralPath (Join-Path $failure.work ('failed\' + $caseId + '\committed\CASE_RESULT.json')) -PathType Leaf) "R14P injected-failure recoverable quarantine absent: $caseId"
    }

    foreach ($source in $sourceRows.ToArray()) {
        Assert-True ([int64](Get-Item -LiteralPath $source.path).Length -eq [int64]$source.bytes -and (Get-Sha256 $source.path) -eq [string]$source.sha256) "R14P source fixture changed: $($source.caseId)/$($source.channel)"
    }
    $substAfter = & $substPath 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and $substAfter -notmatch '(?im)^\s*X:\\:\s*=>') 'R14P endpoint left the X: alias mapped.'

    [IO.File]::Copy([string]$success.invocation, $successEvidencePath, $false)
    [IO.File]::Copy([string]$failure.invocation, $failureEvidencePath, $false)
    $gateResult = [ordered]@{
        schema='argos_opencv_scribe_r14p_endpoint_rehearsal_gate_v1';revision=$revision;classification='PENDING_GATE';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R14P_ENDPOINT_REHEARSAL'
        endpoint=[ordered]@{path='work/OPENCV_SCRIBE_R14/Invoke-R14P.ps1';sha256=$endpointSha256;windowsPowerShellVersion=$PSVersionTable.PSVersion.ToString();sevenPayloadPackageShapePassed=$true;liveRuntimeAndSourcePinsRemainRequired=$true}
        preflight=[ordered]@{successState=[string]$successPreflight.state;failureState=[string]$failurePreflight.state;sourceImageBytesRead=$false;pixelsDecoded=$false;childProcessStarted=$false;filesystemMutationPerformed=$false}
        success=[ordered]@{invocationEvidence='work/OPENCV_SCRIBE_R14P/R14P_ENDPOINT_SUCCESS_REHEARSAL_INVOCATION.json';invocationSha256=Get-Sha256 $successEvidencePath;providerStubSha256=[string]$success.providerSha256;bundleSha256=[string]$successResponse.bundleSha256;caseCount=4;providerCompletedCount=4;caseLaunchFailureCount=0;artifactAndLineageValidationPassed=$true}
        injectedFailure=[ordered]@{invocationEvidence='work/OPENCV_SCRIBE_R14P/R14P_ENDPOINT_FAILURE_REHEARSAL_INVOCATION.json';invocationSha256=Get-Sha256 $failureEvidencePath;providerStubSha256=[string]$failure.providerSha256;bundleSha256=[string]$failureResponse.bundleSha256;caseCount=4;providerCompletedCount=0;caseLaunchFailureCount=4;compactFailureConstructionPassed=$true;recoverableQuarantinePassed=$true;laterCasesProcessed=$true}
        exactDependencies=[ordered]@{configurationSha256=$configurationSha256;installationFixtureSha256=$installationSha256;referenceBundleSha256=$referenceBundleSha256;dependencySha256=@($dependencyPins | ForEach-Object { [ordered]@{name=[string]$_.name;sha256=[string]$_.sha256} })}
        invariants=[ordered]@{sourceFixtureHashesUnchanged=$true;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;aliasRemoved=$true;taskOrProcessRestarted=$false;providerActivated=$false;automaticRetryPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
        disposition='PASS_LOCAL_ENDPOINT_CONSTRUCTION_GATES_FOR_PACKAGE_FREEZE'
    }
    Write-JsonNew $gatePath $gateResult 32
    [ordered]@{state=[string]$gateResult.state;gatePath=$gatePath;gateSha256=Get-Sha256 $gatePath;endpointSha256=$endpointSha256} | ConvertTo-Json -Compress
}
finally {
    $substRows = & $substPath 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $match = [regex]::Match($substRows, '(?im)^\s*X:\\:\s*=>\s*(.+?)\s*$')
        if ($match.Success -and $match.Groups[1].Value.Trim().TrimEnd('\').Equals($sourceRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) { [void](& $substPath 'X:' '/D' 2>&1) }
    }
    if (Test-Path -LiteralPath $testRoot) {
        Assert-True ($testRoot -match '^C:\\R14PG_[0-9]+_[0-9]{6}$') 'R14P endpoint-test cleanup target escaped its exact root.'
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
