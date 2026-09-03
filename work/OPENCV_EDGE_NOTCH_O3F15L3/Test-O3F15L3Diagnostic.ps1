#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Sha-Text([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}
function Write-NewJson([string]$Path, [object]$Value) {
    Require (-not (Test-Path -LiteralPath $Path)) "O3F15L3 test create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 10) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Invoke-FixtureCase([string]$Mode, [int]$TimeoutSeconds, [string]$Root, [string]$PowerShell, [string]$Python, [string]$PythonSha, [string]$Endpoint) {
    $manifestPath = Join-Path $Root ("$Mode.json")
    Write-NewJson $manifestPath ([ordered]@{
        schema = 'argos_ocv03_o3f15l3_rehearsal_invocation_v1'
        fixtureMode = $Mode
        pythonPath = $Python
        pythonSha256 = $PythonSha
        timeoutSeconds = $TimeoutSeconds
    })
    $stdoutPath = Join-Path $Root ("$Mode.stdout.txt")
    $stderrPath = Join-Path $Root ("$Mode.stderr.txt")
    $process = Start-Process -FilePath $PowerShell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$Endpoint,'-Rehearsal','-InvocationManifest',$manifestPath) -Wait -PassThru -WindowStyle Hidden -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
    Require ($process.ExitCode -eq 0) "O3F15L3 endpoint fixture failed: $Mode"
    $outerStderr = [IO.File]::ReadAllText($stderrPath)
    Require ([Text.Encoding]::UTF8.GetByteCount($outerStderr) -eq 0) "O3F15L3 endpoint fixture wrote outer stderr: $Mode"
    $outerStdout = [IO.File]::ReadAllText($stdoutPath)
    try { $result = $outerStdout.Trim() | ConvertFrom-Json }
    catch { throw "O3F15L3 endpoint fixture did not return one JSON object: $Mode" }
    Require ([string]$result.schema -ceq 'argos_ocv03_o3f15l3_preflight_diagnostic_v1' -and [string]$result.state -ceq 'COMPLETE_O3F15L3_PREFLIGHT_DIAGNOSTIC_CAPTURED') "O3F15L3 diagnostic envelope changed: $Mode"
    Require ([bool]$result.rehearsal -and [int]$result.ownedChildCount -eq 1 -and [int]$result.maximumOwnedChildCount -eq 1) "O3F15L3 one-child evidence changed: $Mode"
    Require (@($result.childArguments).Count -eq 4 -and [string]::Join('|', @($result.childArguments)) -ceq "-I|-B|$((Join-Path (Split-Path -Parent $Endpoint) 'O3F15L3DiagnosticFixture.py'))|PREFLIGHT") "O3F15L3 fixture child arguments changed: $Mode"
    Require (-not [bool]$result.selfTestStarted -and -not [bool]$result.gateStarted -and -not [bool]$result.runStarted -and -not [bool]$result.detectorResultRootCreated -and -not [bool]$result.corpusStarted -and -not [bool]$result.imageBytesRead -and -not [bool]$result.sourceMutation -and -not [bool]$result.providerActivated -and -not [bool]$result.mutationsPerformed) "O3F15L3 fixture authority widened: $Mode"
    Require ([int]$result.stdoutTailCharacters -le 2000 -and [int]$result.stdoutTailBytes -le 8000 -and [int]$result.stderrTailCharacters -le 2000 -and [int]$result.stderrTailBytes -le 8000) "O3F15L3 bounded-tail contract changed: $Mode"
    Require (-not [bool]$result.stdoutTruncated -and -not [bool]$result.stderrTruncated) "O3F15L3 small fixture stream was unexpectedly truncated: $Mode"
    Require ([int]$result.stdoutBytes -eq [Text.Encoding]::UTF8.GetByteCount([string]$result.stdoutTail) -and [string]$result.stdoutSha256 -ceq (Sha-Text ([string]$result.stdoutTail))) "O3F15L3 raw stdout was not preserved: $Mode"
    Require ([int]$result.stderrBytes -eq [Text.Encoding]::UTF8.GetByteCount([string]$result.stderrTail) -and [string]$result.stderrSha256 -ceq (Sha-Text ([string]$result.stderrTail))) "O3F15L3 raw stderr was not preserved: $Mode"
    return $result
}

Require ($Preflight -xor $Test) 'Specify exactly one of -Preflight or -Test.'
$sourceEndpoint = Join-Path $PSScriptRoot 'Invoke-O3F15L3.ps1'
$contractPath = Join-Path $PSScriptRoot 'O3F15L3_DIAGNOSTIC_CONTRACT.json'
$fixture = Join-Path $PSScriptRoot 'O3F15L3DiagnosticFixture.py'
foreach ($path in @($sourceEndpoint,$contractPath,$fixture)) { Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L3 test dependency absent: $path" }
$contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
Require ([string]$contract.schema -ceq 'argos_ocv03_o3f15l3_diagnostic_contract_v1' -and [int]$contract.maximumOwnedChildCount -eq 1) 'O3F15L3 test contract changed.'
$powershell = Join-Path $PSHOME 'powershell.exe'
Require (Test-Path -LiteralPath $powershell -PathType Leaf) 'O3F15L3 Windows PowerShell executable is absent.'
$pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
$python = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
$pythonSha = Sha $python
$gatePath = Join-Path $PSScriptRoot 'O3F15L3_LOCAL_DIAGNOSTIC_GATE.json'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3f15l3_local_test_preflight_v1'
        state = 'PASS_O3F15L3_LOCAL_TEST_PREFLIGHT'
        endpointSha256 = Sha $sourceEndpoint
        contractSha256 = Sha $contractPath
        fixtureSha256 = Sha $fixture
        windowsPowerShell = $powershell
        pythonPath = $python
        pythonSha256 = $pythonSha
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 6 -Compress
    return
}

Require (-not (Test-Path -LiteralPath $gatePath)) 'O3F15L3 local diagnostic gate already exists.'
$testRoot = Join-Path 'C:\O3F15L3T' ([Guid]::NewGuid().ToString('N').Substring(0,12))
[void](New-Item -ItemType Directory -Path $testRoot)
$payloadRoot = Join-Path $testRoot 'payload'
[void](New-Item -ItemType Directory -Path $payloadRoot)
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
foreach ($record in @($contract.payloadFiles)) {
    $source = Join-Path $repoRoot ([string]$record.source)
    $destination = Join-Path $payloadRoot ([string]$record.name)
    Require (Test-Path -LiteralPath $source -PathType Leaf) "O3F15L3 staged-test payload source absent: $source"
    Require ((Sha $source) -ceq [string]$record.sha256) "O3F15L3 staged-test payload source changed: $($record.name)"
    [IO.File]::Copy($source, $destination, $false)
}
[IO.File]::Copy($contractPath, (Join-Path $payloadRoot 'O3F15L3_DIAGNOSTIC_CONTRACT.json'), $false)
$endpoint = Join-Path $payloadRoot 'Invoke-O3F15L3.ps1'
$results = [ordered]@{}
$results.PASS = Invoke-FixtureCase 'PASS' 10 $testRoot $powershell $python $pythonSha $endpoint
$results.NONZERO_BOTH = Invoke-FixtureCase 'NONZERO_BOTH' 10 $testRoot $powershell $python $pythonSha $endpoint
$results.ZERO_STDERR = Invoke-FixtureCase 'ZERO_STDERR' 10 $testRoot $powershell $python $pythonSha $endpoint
$results.MALFORMED = Invoke-FixtureCase 'MALFORMED' 10 $testRoot $powershell $python $pythonSha $endpoint
$results.TIMEOUT = Invoke-FixtureCase 'TIMEOUT' 1 $testRoot $powershell $python $pythonSha $endpoint
Require ([string]$results.PASS.childOutcome -ceq 'PASS' -and [int]$results.PASS.childExitCode -eq 0 -and [bool]$results.PASS.parsedJsonObject -and [bool]$results.PASS.expectedRunnerResultMatched) 'O3F15L3 PASS projection changed.'
Require ([string]$results.NONZERO_BOTH.childOutcome -ceq 'FAIL' -and [int]$results.NONZERO_BOTH.childExitCode -eq 7 -and [int]$results.NONZERO_BOTH.stdoutBytes -gt 0 -and [int]$results.NONZERO_BOTH.stderrBytes -gt 0) 'O3F15L3 NONZERO_BOTH projection changed.'
Require ([string]$results.ZERO_STDERR.childOutcome -ceq 'FAIL' -and [int]$results.ZERO_STDERR.childExitCode -eq 0 -and [int]$results.ZERO_STDERR.stderrBytes -gt 0 -and [bool]$results.ZERO_STDERR.expectedRunnerResultMatched) 'O3F15L3 ZERO_STDERR projection changed.'
Require ([string]$results.MALFORMED.childOutcome -ceq 'FAIL' -and [int]$results.MALFORMED.childExitCode -eq 0 -and -not [bool]$results.MALFORMED.parsedJsonObject) 'O3F15L3 MALFORMED projection changed.'
Require ([string]$results.TIMEOUT.childOutcome -ceq 'FAIL' -and [bool]$results.TIMEOUT.childTimedOut -and [int]$results.TIMEOUT.stdoutBytes -gt 0 -and [int]$results.TIMEOUT.stderrBytes -gt 0) 'O3F15L3 TIMEOUT projection changed.'
$gate = [ordered]@{
    schema = 'argos_ocv03_o3f15l3_local_diagnostic_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3F15L3_BOUNDED_PREFLIGHT_DIAGNOSTIC_PROJECTION'
    endpointSha256 = Sha $endpoint
    contractSha256 = Sha $contractPath
    fixtureSha256 = Sha $fixture
    windowsPowerShell = $powershell
    pythonPath = $python
    pythonSha256 = $pythonSha
    testRoot = $testRoot
    cases = @($results.Keys | ForEach-Object { [ordered]@{ mode = $_; childOutcome = [string]$results[$_].childOutcome; childExitCode = [int]$results[$_].childExitCode; childTimedOut = [bool]$results[$_].childTimedOut; stdoutBytes = [int]$results[$_].stdoutBytes; stdoutSha256 = [string]$results[$_].stdoutSha256; stderrBytes = [int]$results[$_].stderrBytes; stderrSha256 = [string]$results[$_].stderrSha256 } })
    exactFixtureCaseCount = 5
    exactOwnedChildCountPerCase = 1
    rawStreamsPreservedBeforeInterpretation = $true
    selfTestStarted = $false
    gateStarted = $false
    runStarted = $false
    detectorResultRootCreated = $false
    imageBytesRead = $false
    targetExecuted = $false
    sourceMutation = $false
    providerActivated = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-NewJson $gatePath $gate
$gate | ConvertTo-Json -Depth 8 -Compress
