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
function Get-LiteralPin([string]$Text, [string]$Name) {
    $pattern = '(?m)^\s*' + [regex]::Escape('$' + $Name) + "\s*=\s*'([0-9A-F]{64})'\s*$"
    $matches = [regex]::Matches($Text, $pattern)
    Assert-True ($matches.Count -eq 1) "R6V2 endpoint requires exactly one literal pin: $Name"
    return $matches[0].Groups[1].Value
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$endpoint = Join-Path $PSScriptRoot 'Invoke-R6V2ScribeBatch.ps1'
$engine = Join-Path $project 'work\OPENCV_SCRIBE_V1R6\ArgosOpenCvScribeV1R6.py'
$configuration = Join-Path $PSScriptRoot 'R6V2_CONFIGURATION.json'
$batchPath = Join-Path $PSScriptRoot 'BATCH.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$o2d5InvocationPath = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\INVOCATION.json'
$goodFixture = Join-Path $PSScriptRoot 'fixtures\LIVE_GOOD.json'
$badBatchFixture = Join-Path $PSScriptRoot 'fixtures\LIVE_BAD_BATCH.json'
$badInstallationFixture = Join-Path $PSScriptRoot 'fixtures\LIVE_BAD_INSTALLATION.json'
$gatePath = Join-Path $PSScriptRoot 'R6V2_SELF_PIN_GATE.json'

foreach ($path in @($endpoint,$engine,$configuration,$batchPath,$continuityPath,$o2d5InvocationPath,$goodFixture,$badBatchFixture,$badInstallationFixture)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "R6V2 self-pin dependency absent: $path"
}
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'R6V2 self-pin gate exists.'
$endpointText = Get-Content -Raw -LiteralPath $endpoint
$batch = Get-Content -Raw -LiteralPath $batchPath | ConvertFrom-Json
$continuityText = Get-Content -Raw -LiteralPath $continuityPath
$installationMatches = [regex]::Matches($continuityText, '"jbodInstallationManifestSha256"\s*:\s*"([0-9A-F]{64})"')
Assert-True ($installationMatches.Count -eq 1) 'R6V2 continuity installation pin cardinality changed.'
$o2d5 = Get-Content -Raw -LiteralPath $o2d5InvocationPath | ConvertFrom-Json

$expected = [ordered]@{
    engineSha = Get-Sha256 $engine
    configurationSha = Get-Sha256 $configuration
    batchSha = Get-Sha256 $batchPath
    refsSha = [string]$o2d5.payload.referenceBundleSha256
    installationSha = $installationMatches[0].Groups[1].Value
}
$rows = New-Object Collections.Generic.List[object]
foreach ($name in @('engineSha','configurationSha','batchSha','refsSha','installationSha')) {
    $observed = Get-LiteralPin $endpointText $name
    $expectedValue = [string]$expected[$name]
    Assert-True ($observed -eq $expectedValue) "R6V2 endpoint self-pin mismatch: $name"
    $rows.Add([pscustomobject]@{id=$name;endpointValue=$observed;evidenceValue=$expectedValue;match=$true})
}
Assert-True (@($batch.cases).Count -eq 4) 'R6V2 batch case count changed.'
foreach ($case in @($batch.cases)) {
    $jobPath = Join-Path $PSScriptRoot ([string]$case.jobFile)
    Assert-True ((Get-Sha256 $jobPath) -eq [string]$case.jobSha256) "R6V2 batch job self-pin changed: $($case.slot)"
}

if ($Preflight) {
    [ordered]@{schema='argos_r6v2_self_pin_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V2_SELF_PIN_PREFLIGHT';endpointSha256=Get-Sha256 $endpoint;pinCount=$rows.Count;jobPinCount=4;plannedLiveBranchCases=3;mutationsPerformed=$false;processStarted=$false;sourceImageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

$good = (& $endpoint -Preflight -LiveContractFixtureManifest $goodFixture | Out-String) | ConvertFrom-Json
Assert-True ([string]$good.state -eq 'PASS_R6V2_LIVE_CONTRACT_FIXTURE' -and [bool]$good.batchAssertionExecuted -and [bool]$good.installationAssertionExecuted -and -not [bool]$good.mutationsPerformed) 'R6V2 positive live-contract fixture failed.'
$badBatchRefused = $false
try { & $endpoint -Preflight -LiveContractFixtureManifest $badBatchFixture 2>&1 | Out-Null }
catch { $badBatchRefused = $_.Exception.Message -eq 'R6V2 live batch manifest changed.' }
Assert-True $badBatchRefused 'R6V2 bad-batch fixture was not refused by the exact assertion.'
$badInstallationRefused = $false
try { & $endpoint -Preflight -LiveContractFixtureManifest $badInstallationFixture 2>&1 | Out-Null }
catch { $badInstallationRefused = $_.Exception.Message -eq 'R6V2 runtime installation changed.' }
Assert-True $badInstallationRefused 'R6V2 bad-installation fixture was not refused by the exact assertion.'

$gate = [ordered]@{schema='argos_r6v2_self_pin_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R6V2_SELF_PIN_AND_LIVE_BRANCH_GATE';endpointSha256=Get-Sha256 $endpoint;pins=$rows.ToArray();pinCount=$rows.Count;pinMatchCount=@($rows | Where-Object { $_.match }).Count;jobPinCount=4;liveBranchCases=@([pscustomobject]@{id='GOOD_BATCH_AND_INSTALLATION';state='PASS'},[pscustomobject]@{id='BAD_BATCH_HASH_REFUSED';state='PASS';failureBeforeImageRead=$true},[pscustomobject]@{id='BAD_INSTALLATION_HASH_REFUSED';state='PASS';failureBeforeImageRead=$true});normalLiveFixtureCallCount=3;rehearsalBranchAloneSufficient=$false;targetExecuted=$false;mutationsPerformed=$false;imageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false}
[IO.File]::WriteAllText($gatePath, (($gate | ConvertTo-Json -Depth 16) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$gate | ConvertTo-Json -Depth 16
