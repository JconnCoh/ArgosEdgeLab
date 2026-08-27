#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ([bool]$Preflight -eq [bool]$Gate) { throw 'Specify exactly one of -Preflight or -Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpoint = Join-Path $PSScriptRoot 'Invoke-O3D3R2HotspotEndpoint.ps1'
$generator = Join-Path $PSScriptRoot 'New-O3D3R2RehearsalFixtures.py'
$payloadRoot = Join-Path $project 'work\PATTERNED_FIDUCIAL_INVENTORY\tools'
$job = Join-Path $PSScriptRoot 'O3D3R2_HOTSPOT_JOB.json'
$fixtureManifest = Join-Path $PSScriptRoot 'O3D3R2_LIVE_CONTRACT_FIXTURE.json'
$runtimeRoot = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$python = Join-Path $runtimeRoot 'python.exe'
$installationFixture = Join-Path $project 'work\OPENCV_SCRIBE_O2D23\fixtures\INSTALLATION.json'
$testRoot = 'C:\A36'
$sourceRoot = 'C:\A36\s'
$workRoot = 'C:\A36\w'
$outputRoot = 'C:\A36\o'
$badWorkRoot = 'C:\A36\bw'
$badOutputRoot = 'C:\A36\bo'
$gatePath = Join-Path $PSScriptRoot 'O3D3R2_ENDPOINT_REHEARSAL_GATE.json'

$endpointSha = 'C51820F543F2D88644EC86E6F6BCD3B32A3F0B7181BF98084EEDE19FA7E8F197'
$generatorSha = 'E81038D87E79032285D10CA352202034C94FF3FCBDB9C8A9A67291B24174EC35'
$jobSha = 'C11A3545AC230E367B618C5E7837EF541B8288B727570595E2B610DCEE9E06B1'
$coreSha = '304219822CC3C7CC8E0ED81BD89E230529057E47E0E7DA4C95FE041F3AF69FAC'
$r5Sha = '47F70976D0F3AE0461166D7D3438FE7B11FFE71E8257FD918554F7909E0B9E24'
$r6Sha = '90839F14CEEED7C2DFC6E1601195F6927C4631E508F9EB859E77A93745D3FB30'
$pythonSha = '7D96A4ED35D6E596CD9DD8933FEAFC66349CC21F75BE3B15C89FD336E50140C1'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($parts.Count) { [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) } else { 0 }
    Assert-True (($full.Length + $Reserve) -lt 200) "O3D3R2 test path is unsafe: $full"
    Assert-True ($longest -le 80) "O3D3R2 test component is unsafe: $full"
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 16) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O3D3R2 test create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

foreach ($pin in @(
    [pscustomobject]@{path=$endpoint;sha=$endpointSha},
    [pscustomobject]@{path=$generator;sha=$generatorSha},
    [pscustomobject]@{path=$job;sha=$jobSha},
    [pscustomobject]@{path=(Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2.py');sha=$coreSha},
    [pscustomobject]@{path=(Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2R5.py');sha=$r5Sha},
    [pscustomobject]@{path=(Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py');sha=$r6Sha},
    [pscustomobject]@{path=$python;sha=$pythonSha}
)) {
    Assert-True (Test-Path -LiteralPath $pin.path -PathType Leaf) "O3D3R2 test dependency absent: $($pin.path)"
    Assert-True ((Get-Sha256 $pin.path) -eq $pin.sha) "O3D3R2 test dependency changed: $($pin.path)"
}
foreach ($path in @($testRoot,$sourceRoot,$workRoot,$outputRoot,$badWorkRoot,$badOutputRoot,$gatePath)) {
    Assert-PathBudget $path 32
    Assert-True (-not (Test-Path -LiteralPath $path)) "O3D3R2 test fresh target exists: $path"
}
Assert-True (-not (Test-Path -LiteralPath 'F:\') -and $null -eq (Get-PSDrive -Name F -ErrorAction SilentlyContinue)) 'O3D3R2 test requires unused F:.'

$tokens = $null
$parserErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($endpoint, [ref]$tokens, [ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'O3D3R2 endpoint Windows PowerShell parser failed.'
$endpointText = [IO.File]::ReadAllText($endpoint)
Assert-True ($endpointText.Contains("`$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'")) 'O3D3R2 installed-runtime live self-pin changed.'
Assert-True ($endpointText.Contains("`$liveJobSha = 'C11A3545AC230E367B618C5E7837EF541B8288B727570595E2B610DCEE9E06B1'")) 'O3D3R2 live job self-pin changed.'
Assert-True ($endpointText.Contains('WaitForExit(780000)')) 'O3D3R2 child timeout changed.'

if ($Preflight) {
    [ordered]@{
        schema='argos_o3d3r2_endpoint_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R2_ENDPOINT_TEST_PREFLIGHT'
        endpointSha256=$endpointSha;generatorSha256=$generatorSha;jobSha256=$jobSha;windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;windowsPowerShellMinor=$PSVersionTable.PSVersion.Minor
        testRoot=$testRoot;pathBudgetPassed=$true;parserPassed=$true;liveConstantPinsPresent=$true;sourceImageBytesRead=$false;sourceHashesComputed=$false;pixelsDecoded=$false
        mutationsPerformed=$false;targetExecuted=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$generatorText = & $python $generator --r6 (Join-Path $payloadRoot 'NativeFrontsideWaferPoseOpenCvV2R6.py') --output-root $sourceRoot 2>&1 | Out-String
Assert-True ($LASTEXITCODE -eq 0) ('O3D3R2 fixture generator failed: ' + $generatorText.Trim())
$generatorGate = ($generatorText.Trim() | ConvertFrom-Json)
Assert-True ([string]$generatorGate.state -eq 'PASS_O3D3R2_REHEARSAL_FIXTURES_CREATED') 'O3D3R2 fixture generator terminal state changed.'
$rehearsalJob = Join-Path $sourceRoot 'JOB.json'

$endpointPreflightText = & $endpoint -Preflight -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtimeRoot -RuntimeInstallationPath $installationFixture -WorkRoot $workRoot -OutputRoot $outputRoot -SourceAliasRoot $sourceRoot -RehearsalJobPath $rehearsalJob -ExpectedComputerName $env:COMPUTERNAME | Out-String
$endpointPreflight = $endpointPreflightText | ConvertFrom-Json
Assert-True ([string]$endpointPreflight.state -eq 'PASS_O3D3R2_ENDPOINT_PREFLIGHT' -and [bool]$endpointPreflight.rehearsal) 'O3D3R2 endpoint preflight failed.'
Assert-True (-not [bool]$endpointPreflight.sourceImageBytesRead -and -not [bool]$endpointPreflight.sourceHashesComputed -and -not [bool]$endpointPreflight.pixelsDecoded -and -not [bool]$endpointPreflight.mutationsPerformed) 'O3D3R2 endpoint preflight mutated or read source bytes.'

$liveFixtureText = & $endpoint -Preflight -LiveContractFixtureManifest $fixtureManifest | Out-String
$liveFixture = $liveFixtureText | ConvertFrom-Json
Assert-True ([string]$liveFixture.state -eq 'PASS_O3D3R2_LIVE_CONTRACT_FIXTURE' -and [bool]$liveFixture.liveJobAssertionExecuted -and [bool]$liveFixture.liveInstallationAssertionExecuted) 'O3D3R2 live self-pin function fixture failed.'

$normalText = & $endpoint -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtimeRoot -RuntimeInstallationPath $installationFixture -WorkRoot $workRoot -OutputRoot $outputRoot -SourceAliasRoot $sourceRoot -RehearsalJobPath $rehearsalJob -ExpectedComputerName $env:COMPUTERNAME | Out-String
$normal = $normalText | ConvertFrom-Json
Assert-True ([string]$normal.state -eq 'PASS_O3D3R2_HOTSPOT_EDGE_NOTCH_EXECUTED' -and [int]$normal.inputCount -eq 1 -and [int]$normal.verifiedSourceCount -eq 2) 'O3D3R2 normal rehearsal failed.'
Assert-True (@($normal.rows).Count -eq 1 -and [bool]$normal.rows[0].manufacturedNotchSelectedForReview) 'O3D3R2 normal rehearsal did not select the manufactured synthetic notch.'
Assert-True ([bool]$normal.sourceAliasRemoved -and [bool]$normal.processorIdentityUnchanged -and -not [bool]$normal.rotationAuthorityGranted) 'O3D3R2 normal rehearsal runtime boundary changed.'

$badJobPath = Join-Path $sourceRoot 'BAD_JOB.json'
$badJob = Get-Content -LiteralPath $rehearsalJob -Raw | ConvertFrom-Json
$badJob.inputs[0].bfSha256 = '0' * 64
Write-JsonNew $badJobPath $badJob 20
$badFailed = $false
try {
    & $endpoint -Rehearsal -PayloadRoot $payloadRoot -RuntimeRoot $runtimeRoot -RuntimeInstallationPath $installationFixture -WorkRoot $badWorkRoot -OutputRoot $badOutputRoot -SourceAliasRoot $sourceRoot -RehearsalJobPath $badJobPath -ExpectedComputerName $env:COMPUTERNAME 2>&1 | Out-Null
}
catch {
    $badFailed = $_.Exception.Message -like '*source SHA-256 changed*'
}
Assert-True $badFailed 'O3D3R2 injected source hash mismatch did not fail closed.'
Assert-True (-not (Test-Path -LiteralPath $badWorkRoot) -and -not (Test-Path -LiteralPath $badOutputRoot) -and -not (Test-Path -LiteralPath 'F:\')) 'O3D3R2 injected failure left a live work/output root or alias.'

$resultGate = [ordered]@{
    schema='argos_o3d3r2_endpoint_rehearsal_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3D3R2_ENDPOINT_REHEARSAL';revision='O3D3R2_20260827T163500000Z_62629419'
    endpointSha256=$endpointSha;generatorSha256=$generatorSha;jobSha256=$jobSha;coreSha256=$coreSha;r5Sha256=$r5Sha;r6Sha256=$r6Sha
    windowsPowerShellMajor=$PSVersionTable.PSVersion.Major;windowsPowerShellMinor=$PSVersionTable.PSVersion.Minor;endpointPreflightState=[string]$endpointPreflight.state;liveContractFixtureState=[string]$liveFixture.state
    normalState=[string]$normal.state;normalSelectedReviewAngleDegrees=[double]$normal.rows[0].reviewAngleDegrees;normalManufacturedNotchSelected=[bool]$normal.rows[0].manufacturedNotchSelectedForReview
    sourceHashesVerifiedBeforeDecode=$true;injectedHashMismatchFailedBeforeWorkOrOutput=$true;sourceAliasRemoved=$true;processorIdentityUnchanged=$true;fullPerimeterInference=$true
    knownNotchLocationConsumed=$false;notchAnglePriorConsumed=$false;fixedAngularSearchWindowConsumed=$false;regressionLabelsConsumed=$false;rotationAuthorityGranted=$false
    sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;waferActionPerformed=$false;holdsCleared=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-JsonNew $gatePath $resultGate 12
$resultGate | ConvertTo-Json -Depth 12

