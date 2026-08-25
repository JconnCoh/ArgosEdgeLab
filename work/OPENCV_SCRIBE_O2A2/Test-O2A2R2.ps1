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
$testRoot = 'C:\O2A2T2'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new test JSON path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Copy-Package([string]$Destination) {
    [void](New-Item -ItemType Directory -Path $Destination)
    foreach ($file in @(Get-ChildItem -LiteralPath $packageSource -File -ErrorAction Stop)) {
        Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $Destination $file.Name)
    }
}
function New-TextFile([string]$Path, [string]$Text) {
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Path $parent) }
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}
function New-CaseInvocation([string]$CaseRoot, [string]$CaseId, [int]$MatchCount) {
    $portal = Join-Path $CaseRoot 'portal'
    $pending = Join-Path $portal 'pending'
    $responses = Join-Path $portal 'responses'
    $dOutput = Join-Path $CaseRoot 'd_output'
    foreach ($path in @($portal, $pending, $responses, $dOutput, (Join-Path $CaseRoot 'return'))) { [void](New-Item -ItemType Directory -Path $path) }
    for ($index = 0; $index -lt $MatchCount; $index++) {
        $requestRoot = Join-Path $pending (if ($index -eq 0) { 'REQ_O2D4.ready' } else { 'OTHER_' + $index })
        [void](New-Item -ItemType Directory -Path $requestRoot)
        New-TextFile -Path (Join-Path $requestRoot 'PORTAL_REQUEST_MANIFEST.json') -Text ('{"requestId":"REQ_O2D4","case":' + $index + '}')
        if ($index -eq 0) { New-TextFile -Path (Join-Path $requestRoot 'image.bmp') -Text 'fixture metadata-only exclusion control' }
        $responseRoot = Join-Path $responses ('R_A2A87054A416_20260825000' + $index + '.ready')
        [void](New-Item -ItemType Directory -Path $responseRoot)
        New-TextFile -Path (Join-Path $responseRoot 'PORTAL_RESPONSE_MANIFEST.json') -Text ('{"requestId":"REQ_O2D4","case":' + $index + '}')
        New-TextFile -Path (Join-Path $responseRoot 'PORTAL_RESPONSE_MANIFEST.sig') -Text ('signature-fixture-' + $index)
        $outputRoot = Join-Path $dOutput ('O2D4_' + $index)
        [void](New-Item -ItemType Directory -Path $outputRoot)
        New-TextFile -Path (Join-Path $outputRoot 'RESULT.json') -Text ('{"case":' + $index + '}')
    }
    $pathSources = @(
        [ordered]@{id='PENDING_REQUEST';root=$pending;selection='CHILD_NAME_EXACT';matchText='REQ_O2D4.ready';maximumDepth=2;maximumRows=32;copySafeEvidence=$true},
        [ordered]@{id='RESP_PENDING';root=$responses;selection='CHILD_NAME_PREFIX';matchText='R_A2A87054A416_';maximumDepth=2;maximumRows=64;copySafeEvidence=$true},
        [ordered]@{id='D_OUTPUT';root=$dOutput;selection='CHILD_NAME_PREFIX';matchText='O2D4';maximumDepth=2;maximumRows=64;copySafeEvidence=$true}
    )
    return [ordered]@{
        schema='argos_o2a2_direct_admin_invocation_v1'
        incidentId='OCV02_O2D4_TERMINAL_STATE_20260825'
        requestId='REQ_O2D4'
        expectedResponsePrefix='R_A2A87054A416_'
        rehearsal=$true
        portalRoot=$portal
        outputRoot=(Join-Path $CaseRoot 'output')
        localResultLeaf='O2A2R_LOCAL.zip'
        returnPath=(Join-Path $CaseRoot 'return\O2A2R.zip')
        refuseComputerNames=@()
        maximumSafeFileBytes=4194304
        maximumCopyFiles=128
        maximumCopyBytes=33554432
        maximumProcessRows=64
        taskNames=@('TASK_A','TASK_B','TASK_C')
        pathSources=$pathSources
        taskFixture=@([ordered]@{name='TASK_A';present=$true;state='Ready'},[ordered]@{name='TASK_B';present=$true;state='Running'},[ordered]@{name='TASK_C';present=$true;state='Ready'})
        processFixture=@(for ($row = 0; $row -lt $MatchCount; $row++) { [ordered]@{processId=100+$row;name='powershell.exe';commandLine='fixture portal process'} })
        substFixture=@(if ($CaseId -eq 'ONE') { 'X:\: => D:\fixture' })
        reviewOnly=$true
        productionRoutingEnabled=$false
    }
}

foreach ($required in @('AUDIT_O2A2.ps1','RUN_O2A2.cmd','INVOCATION.json','README_FIRST.txt','PACKAGE_MANIFEST.json')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $packageSource $required) -PathType Leaf) "O2A2 package source is absent: $required"
}
Assert-True (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf) 'Windows PowerShell 5.1 is absent.'
Assert-True (-not (Test-Path -LiteralPath $testRoot)) "O2A2 test root must be fresh: $testRoot"
Assert-True (-not (Test-Path -LiteralPath 'C:\O2A2')) 'Live O2A2 output root exists before rehearsal.'
if ($Preflight) {
    [ordered]@{schema='argos_o2a2_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A2_TEST_PREFLIGHT';testRoot=$testRoot;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

Assert-True (-not [string]::IsNullOrWhiteSpace($GatePath)) 'Test mode requires GatePath.'
$resolvedGate = [IO.Path]::GetFullPath($GatePath)
Assert-True ($resolvedGate.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2A2 test gate must remain inside the project.'
Assert-True (-not (Test-Path -LiteralPath $resolvedGate)) 'O2A2 test gate must be create-new.'
[void](New-Item -ItemType Directory -Path $testRoot)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$caseResults = New-Object Collections.Generic.List[object]
$cases = @(
    [ordered]@{id='ZERO';matchCount=0},
    [ordered]@{id='ONE';matchCount=1},
    [ordered]@{id='MANY';matchCount=3}
)
foreach ($case in $cases) {
    $caseRoot = Join-Path $testRoot ([string]$case.id)
    [void](New-Item -ItemType Directory -Path $caseRoot)
    $package = Join-Path $caseRoot 'pkg'
    Copy-Package $package
    $invocation = New-CaseInvocation -CaseRoot $caseRoot -CaseId ([string]$case.id) -MatchCount ([int]$case.matchCount)
    $invocationPath = Join-Path $caseRoot 'INVOCATION_REHEARSAL.json'
    Write-JsonCreateNew -Path $invocationPath -Value $invocation -Depth 14
    $audit = Join-Path $package 'AUDIT_O2A2.ps1'
    $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$audit,'-InvocationManifest',$invocationPath,'-Rehearsal')
    $priorPreference = $ErrorActionPreference
    try { $ErrorActionPreference = 'Continue'; $output = @(& $windowsPowerShell @arguments 2>&1); $exitCode = $LASTEXITCODE }
    finally { $ErrorActionPreference = $priorPreference }
    Assert-True ($exitCode -eq 0) ("O2A2 case failed: " + [string]$case.id + [Environment]::NewLine + ($output -join [Environment]::NewLine))
    $returnZip = Join-Path $caseRoot 'return\O2A2R.zip'
    Assert-True (Test-Path -LiteralPath $returnZip -PathType Leaf) "O2A2 case returned no ZIP: $($case.id)"
    $extract = Join-Path $caseRoot 'extract'
    [IO.Compression.ZipFile]::ExtractToDirectory($returnZip, $extract)
    $observationPath = Join-Path $extract 'O2A2_OBSERVATION.json'
    Assert-True (Test-Path -LiteralPath $observationPath -PathType Leaf) "O2A2 case returned no observation: $($case.id)"
    $observation = Get-Content -LiteralPath $observationPath -Raw | ConvertFrom-Json
    Assert-True ([string]$observation.state -eq 'PASS_O2A2_DIRECT_ADMIN_READ_ONLY_OBSERVATION') "O2A2 case did not pass: $($case.id)"
    Assert-True (-not [bool]$observation.targetMutationsPerformed -and -not [bool]$observation.imageBytesRead) "O2A2 case violated authority: $($case.id)"
    $responseSource = @($observation.sourceResults | Where-Object { [string]$_.id -eq 'RESP_PENDING' })
    Assert-True ($responseSource.Count -eq 1) "O2A2 response source cardinality changed: $($case.id)"
    Assert-True ([int]$responseSource[0].matchedStartCount -eq [int]$case.matchCount) "O2A2 response match count changed: $($case.id)"
    $allRows = @(
        foreach ($sourceResult in @($observation.sourceResults)) {
            foreach ($sourceRow in @($sourceResult.rows)) {
                $sourceRow
            }
        }
    )
    $bmpRows = @($allRows | Where-Object { [string]$_.extension -eq '.bmp' })
    Assert-True (@($bmpRows | Where-Object { [bool]$_.safeTextOrSignatureContentRead }).Count -eq 0) "O2A2 read fixture BMP bytes: $($case.id)"
    $caseResults.Add([pscustomobject]@{id=[string]$case.id;state='PASS';matchCount=[int]$case.matchCount;copiedEvidenceCount=@($observation.copiedEvidence).Count;imageBytesRead=$false;targetMutationsPerformed=$false})
}
Assert-True (-not (Test-Path -LiteralPath 'C:\O2A2')) 'O2A2 rehearsal created the live output root.'
$gate = [ordered]@{
    schema='argos_o2a2_test_gate_r2_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_O2A2_DIRECT_ADMIN_READ_ONLY_TEST_GATE'
    cases=$caseResults.ToArray()
    requiredCaseIds=@('ZERO','ONE','MANY')
    windowsPowerShell51Passed=$true
    packageShapedExecutionPassed=$true
    imageBytesRead=$false
    targetMutationsPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path $resolvedGate -Value $gate -Depth 12
$gate | ConvertTo-Json -Depth 12
