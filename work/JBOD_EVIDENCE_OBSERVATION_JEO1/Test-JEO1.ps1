#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [string]$GatePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$packageSource = Join-Path $PSScriptRoot 'pkg'
$testRoot = 'C:\JEO1T1'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new JSON path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Write-Text([string]$Path, [string]$Value) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Path $parent) }
    [IO.File]::WriteAllText($Path, $Value, (New-Object Text.UTF8Encoding($false)))
}
function Copy-Package([string]$Destination) {
    [void](New-Item -ItemType Directory -Path $Destination)
    foreach ($file in @(Get-ChildItem -LiteralPath $packageSource -File -ErrorAction Stop)) { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $Destination $file.Name) }
}
function New-CaseInvocation([string]$CaseRoot, [string]$CaseId, [int]$MatchCount) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $portal = Join-Path $CaseRoot 'portal'
    $pending = Join-Path $portal 'pending'
    $responses = Join-Path $portal 'responses'
    $cdmOutput = Join-Path $CaseRoot 'cdm1'
    $cdmZipSource = Join-Path $CaseRoot 'cdm_zip_source'
    $treesRoot = Join-Path $CaseRoot 'trees'
    foreach ($path in @($portal, $pending, $responses, $cdmOutput, $cdmZipSource, $treesRoot, (Join-Path $CaseRoot 'return'))) { [void](New-Item -ItemType Directory -Path $path) }
    Write-Text -Path (Join-Path $CaseRoot 'CDM1_LAUNCH.log') -Value "fixture launch $CaseId"
    Write-Text -Path (Join-Path $cdmOutput 'DELETE_AUDIT.json') -Value ('{"state":"fixture","case":"' + $CaseId + '"}')
    Write-Text -Path (Join-Path $cdmOutput 'image.png') -Value 'image-byte exclusion fixture; metadata only'
    Write-Text -Path (Join-Path $cdmZipSource 'CDM1_RESULT.json') -Value ('{"case":"' + $CaseId + '"}')
    $cdmLocalZip = Join-Path $CaseRoot 'CDM1R_LOCAL.zip'
    [IO.Compression.ZipFile]::CreateFromDirectory($cdmZipSource, $cdmLocalZip, [IO.Compression.CompressionLevel]::Optimal, $false)
    foreach ($treeId in @('cache', 'metadata', 'dashboard_outputs')) {
        $treeRoot = Join-Path $treesRoot $treeId
        [void](New-Item -ItemType Directory -Path $treeRoot)
        for ($index = 0; $index -lt $MatchCount; $index++) { Write-Text -Path (Join-Path $treeRoot ('F_{0:D2}.bin' -f $index)) -Value ('fixture-' + $index) }
    }
    for ($index = 0; $index -lt $MatchCount; $index++) {
        $responseRoot = Join-Path $responses ('R_A2A87054A416_20260825000' + $index + '.ready')
        [void](New-Item -ItemType Directory -Path $responseRoot)
        Write-Text -Path (Join-Path $responseRoot 'PORTAL_RESPONSE_MANIFEST.json') -Value ('{"requestId":"REQ_O2D4","case":' + $index + '}')
        Write-Text -Path (Join-Path $responseRoot 'PORTAL_RESPONSE_MANIFEST.sig') -Value ('signature-' + $index)
    }
    $pathSources = @(
        [ordered]@{id='CDM1_LAUNCH';root=(Join-Path $CaseRoot 'CDM1_LAUNCH.log');selection='EXACT_PATH';matchText='';maximumDepth=0;maximumRows=1;copySafeEvidence=$true;copyExactZip=$false},
        [ordered]@{id='CDM1_OUTPUT';root=$cdmOutput;selection='EXACT_PATH';matchText='';maximumDepth=2;maximumRows=32;copySafeEvidence=$true;copyExactZip=$false},
        [ordered]@{id='CDM1_LOCAL_ZIP';root=$cdmLocalZip;selection='EXACT_PATH';matchText='';maximumDepth=0;maximumRows=1;copySafeEvidence=$false;copyExactZip=$true},
        [ordered]@{id='RESP_PENDING';root=$responses;selection='CHILD_NAME_PREFIX';matchText='R_A2A87054A416_';maximumDepth=2;maximumRows=64;copySafeEvidence=$true;copyExactZip=$false}
    )
    $treeSources = @(
        [ordered]@{id='CACHE';root=(Join-Path $treesRoot 'cache');maximumFiles=250000;maximumDirectories=300000},
        [ordered]@{id='METADATA';root=(Join-Path $treesRoot 'metadata');maximumFiles=250000;maximumDirectories=300000},
        [ordered]@{id='DASHBOARD_OUTPUTS';root=(Join-Path $treesRoot 'dashboard_outputs');maximumFiles=250000;maximumDirectories=300000}
    )
    return [ordered]@{
        schema='argos_jeo1_direct_admin_invocation_v1'; incidentId='JBOD_CDM1_POST_RUN_EVIDENCE_20260825'; requestId='REQ_O2D4'; expectedResponsePrefix='R_A2A87054A416_'
        rehearsal=$true; portalRoot=$portal; processorRunnerPath='D:\fixture\processor.ps1'; outputRoot=(Join-Path $CaseRoot 'output')
        localResultPath=(Join-Path $CaseRoot 'JEO1R_LOCAL.zip'); returnPath=(Join-Path $CaseRoot 'return\JEO1R.zip'); refuseComputerNames=@()
        maximumSafeFileBytes=4194304; maximumBinaryEvidenceBytes=67108864; maximumCopyFiles=160; maximumCopyBytes=100663296; maximumProcessRows=64
        taskNames=@('TASK_A','TASK_B','TASK_C','TASK_D'); treeSources=$treeSources; pathSources=$pathSources
        taskFixture=@([ordered]@{name='TASK_A';present=$true;state='Ready'},[ordered]@{name='TASK_B';present=$true;state='Running'},[ordered]@{name='TASK_C';present=$true;state='Ready'},[ordered]@{name='TASK_D';present=$true;state='Running'})
        processFixture=@([ordered]@{processId=100;name='powershell.exe';commandLine='D:\fixture\processor.ps1'}); driveFixture=@([ordered]@{deviceId='C:';sizeBytes=690169573376;freeBytes=1751461888},[ordered]@{deviceId='D:';sizeBytes=1000000000000;freeBytes=500000000000})
        substFixture=@('X:\: => D:\fixture'); reviewOnly=$true; productionRoutingEnabled=$false
    }
}

foreach ($required in @('AUDIT_JEO1.ps1','RUN_JEO1.cmd','INVOCATION.json','README_FIRST.txt','PACKAGE_MANIFEST.json')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $packageSource $required) -PathType Leaf) "JEO1 package source is absent: $required"
}
Assert-True (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) 'Windows PowerShell 5.1 is absent.'
Assert-True (-not (Test-Path -LiteralPath $testRoot)) "JEO1 test root must be fresh: $testRoot"
if ($Preflight) {
    [ordered]@{schema='argos_jeo1_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_TEST_PREFLIGHT';testRoot=$testRoot;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

Assert-True (-not [string]::IsNullOrWhiteSpace($GatePath)) 'Test mode requires GatePath.'
$resolvedGate = [IO.Path]::GetFullPath($GatePath)
Assert-True ($resolvedGate.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'JEO1 test gate must remain inside the project.'
Assert-True (-not (Test-Path -LiteralPath $resolvedGate)) 'JEO1 test gate must be create-new.'
[void](New-Item -ItemType Directory -Path $testRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$caseResults = New-Object Collections.Generic.List[object]
$cases = @([ordered]@{id='ZERO';matchCount=0},[ordered]@{id='ONE';matchCount=1},[ordered]@{id='MANY';matchCount=3})
foreach ($case in $cases) {
    $caseRoot = Join-Path $testRoot ([string]$case.id)
    [void](New-Item -ItemType Directory -Path $caseRoot)
    $package = Join-Path $caseRoot 'pkg'
    Copy-Package $package
    $invocation = New-CaseInvocation -CaseRoot $caseRoot -CaseId ([string]$case.id) -MatchCount ([int]$case.matchCount)
    $invocationPath = Join-Path $caseRoot 'INVOCATION_REHEARSAL.json'
    Write-JsonCreateNew -Path $invocationPath -Value $invocation -Depth 22
    $audit = Join-Path $package 'AUDIT_JEO1.ps1'
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$audit,'-InvocationManifest',$invocationPath,'-Rehearsal')
    $priorPreference = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; $output = @(& $windowsPowerShell @arguments 2>&1); $exitCode = $LASTEXITCODE }
    finally { $ErrorActionPreference = $priorPreference }
    Assert-True ($exitCode -eq 0) ("JEO1 case failed: $($case.id)" + [Environment]::NewLine + ($output -join [Environment]::NewLine))
    $returnZip = Join-Path $caseRoot 'return\JEO1R.zip'
    Assert-True (Test-Path -LiteralPath $returnZip -PathType Leaf) "JEO1 case returned no ZIP: $($case.id)"
    $extract = Join-Path $caseRoot 'extract'
    [IO.Compression.ZipFile]::ExtractToDirectory($returnZip, $extract)
    $observation = Get-Content -LiteralPath (Join-Path $extract 'JEO1_OBSERVATION.json') -Raw | ConvertFrom-Json
    Assert-True ([string]$observation.state -eq 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION') "JEO1 case did not pass: $($case.id)"
    Assert-True (-not [bool]$observation.targetMutationsPerformed -and -not [bool]$observation.imageBytesRead) "JEO1 case violated authority: $($case.id)"
    $responseSource = @($observation.sourceResults | Where-Object { [string]$_.id -eq 'RESP_PENDING' })
    Assert-True ($responseSource.Count -eq 1 -and [int]$responseSource[0].matchedStartCount -eq [int]$case.matchCount) "JEO1 response cardinality changed: $($case.id)"
    foreach ($tree in @($observation.retiredTreeSummaries)) { Assert-True ([int64]$tree.fileCount -eq [int64]$case.matchCount) "JEO1 tree count changed: $($case.id)/$($tree.id)" }
    $binaryCopies = @($observation.copiedEvidence | Where-Object { [string]$_.kind -eq 'EXACT_EVIDENCE_ZIP' })
    Assert-True ($binaryCopies.Count -eq 1) "JEO1 exact CDM1 ZIP copy count changed: $($case.id)"
    $pngRows = @()
    foreach ($sourceResult in @($observation.sourceResults)) { $pngRows += @($sourceResult.rows | Where-Object { [string]$_.extension -eq '.png' }) }
    Assert-True (@($pngRows | Where-Object { [bool]$_.safeTextOrSignatureContentRead -or [bool]$_.exactEvidenceZipCopied }).Count -eq 0) "JEO1 read fixture image bytes: $($case.id)"
    $caseResults.Add([pscustomobject]@{id=[string]$case.id;state='PASS';matchCount=[int]$case.matchCount;returnedZipSha256=Get-Sha256 $returnZip;binaryEvidenceZipCopies=$binaryCopies.Count;imageBytesRead=$false;targetMutationsPerformed=$false})
}
$gate = [ordered]@{
    schema='argos_jeo1_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_DIRECT_ADMIN_READ_ONLY_TEST_GATE';cases=$caseResults.ToArray();requiredCaseIds=@('ZERO','ONE','MANY')
    windowsPowerShell51Passed=$true;packageShapedExecutionPassed=$true;aggregateTreeCountsPassed=$true;exactEvidenceZipCopyPassed=$true;imageBytesRead=$false;targetMutationsPerformed=$false
    testRoot=$testRoot;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path $resolvedGate -Value $gate -Depth 14
$gate | ConvertTo-Json -Depth 14
