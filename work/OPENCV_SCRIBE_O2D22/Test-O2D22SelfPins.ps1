#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

$root = $PSScriptRoot
$project = Split-Path -Parent (Split-Path -Parent $root)
$endpoint = Join-Path $root 'Invoke-O2D22ScribeEndpoint.ps1'
$engine = Join-Path $project 'work\OPENCV_SCRIBE_V1R5\ArgosOpenCvScribeV1R5.py'
$job = Join-Path $root 'O2D22_SLOT24_JOB.json'
$ols6Path = Join-Path $project 'work\OPENCV_OLS6\OLS6_EXACT_TWENTY_SOURCE_HASHES.json'
$o2d5InvocationPath = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\INVOCATION.json'
$continuityPath = Join-Path $project 'work\ARGOS_CONTINUITY_STATE.json'
$goodFixture = Join-Path $root 'fixtures\LIVE_CONTRACT_GOOD.json'
$badJobFixture = Join-Path $root 'fixtures\LIVE_CONTRACT_BAD_JOB.json'
$badInstallationFixture = Join-Path $root 'fixtures\LIVE_CONTRACT_BAD_INSTALLATION.json'
$gatePath = Join-Path $root 'O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE.json'
$expectedEndpointSourceSha256 = '08B6E76548CEE99EA11FC6245FB07C05F2E31E53B23562F8A1B15B1AC6EF6A32'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-LiteralPin([string]$Text, [string]$Name) {
    $pattern = '(?m)^\s*' + [regex]::Escape('$' + $Name) + "\s*=\s*'([0-9A-F]{64})'\s*$"
    $matches = [regex]::Matches($Text, $pattern)
    Assert-True ($matches.Count -eq 1) "O2D22 endpoint requires exactly one literal pin: $Name"
    return $matches[0].Groups[1].Value
}
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }

foreach ($path in @($endpoint,$engine,$job,$ols6Path,$o2d5InvocationPath,$continuityPath,$goodFixture,$badJobFixture,$badInstallationFixture)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D22 self-pin prerequisite absent: $path"
}
$endpointText = Get-Content -Raw -LiteralPath $endpoint
Assert-True ((Get-Sha256 (Join-Path $project 'work\OPENCV_SCRIBE_O2D13\Invoke-O2D13ScribeEndpoint.ps1')) -eq $expectedEndpointSourceSha256) 'O2D22 approved O2D13 endpoint source changed.'
Assert-True ([regex]::Matches($endpointText, [regex]::Escape('Assert-LiveSelfPins -JobPath $jobSource -ExpectedJobSha256 $jobSha -InstallationPath $installation -ExpectedInstallationSha256 $installationSha')).Count -eq 1) 'O2D22 normal live self-pin call changed.'
Assert-True ([regex]::Matches($endpointText, [regex]::Escape('Assert-LiveSelfPins -JobPath ([string]$fixture.jobPath)')).Count -eq 1) 'O2D22 fixture self-pin call changed.'

$ols6 = Get-Content -Raw -LiteralPath $ols6Path | ConvertFrom-Json
$slot24 = @($ols6.hashes | Where-Object { [string]$_.slot -eq 'Slot24' })
Assert-True ($slot24.Count -eq 2) 'O2D22 OLS6 Slot24 source row cardinality changed.'
$bfRows = @($slot24 | Where-Object { [string]$_.channel -eq 'Brightfield' })
$dfRows = @($slot24 | Where-Object { [string]$_.channel -eq 'Darkfield' })
Assert-True ($bfRows.Count -eq 1 -and $dfRows.Count -eq 1) 'O2D22 OLS6 Slot24 channel cardinality changed.'
$o2d5Invocation = Get-Content -Raw -LiteralPath $o2d5InvocationPath | ConvertFrom-Json
$continuityText = Get-Content -Raw -LiteralPath $continuityPath
$installationMatches = [regex]::Matches($continuityText, '"jbodInstallationManifestSha256"\s*:\s*"([0-9A-F]{64})"')
Assert-True ($installationMatches.Count -eq 1) 'O2D22 continuity installation pin cardinality changed.'

$expected = [ordered]@{
    engineSha = Get-Sha256 $engine
    jobSha = Get-Sha256 $job
    refsSha = [string]$o2d5Invocation.payload.referenceBundleSha256
    installationSha = $installationMatches[0].Groups[1].Value
    bfSha = [string]$bfRows[0].sha256
    dfSha = [string]$dfRows[0].sha256
}
$rows = New-Object Collections.Generic.List[object]
foreach ($name in @('engineSha','jobSha','refsSha','installationSha','bfSha','dfSha')) {
    $observed = Get-LiteralPin $endpointText $name
    $expectedValue = [string]$expected[$name]
    Assert-True ($observed -eq $expectedValue) "O2D22 endpoint self-pin mismatch: $name"
    $rows.Add([pscustomobject]@{id=$name;endpointValue=$observed;evidenceValue=$expectedValue;match=$true})
}

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d22_self_pin_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_SELF_PIN_PREFLIGHT'
        endpointSha256=Get-Sha256 $endpoint;approvedBaseSha256=$expectedEndpointSourceSha256;pinCount=$rows.Count;plannedLiveBranchCases=3
        targetExecuted=$false;mutationsPerformed=$false;imageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

Assert-True (-not (Test-Path -LiteralPath $gatePath)) "O2D22 create-new self-pin gate exists: $gatePath"
$good = & $endpoint -Preflight -LiveContractFixtureManifest $goodFixture | ConvertFrom-Json
Assert-True ([string]$good.state -eq 'PASS_O2D22_LIVE_CONTRACT_FIXTURE' -and [bool]$good.jobAssertionExecuted -and [bool]$good.installationAssertionExecuted -and [bool]$good.mutationsPerformed -eq $false) 'O2D22 positive live-contract fixture failed.'
$badJobRefused = $false
try { & $endpoint -Preflight -LiveContractFixtureManifest $badJobFixture | Out-Null }
catch { $badJobRefused = $_.Exception.Message -eq 'O2D22 live job changed.' }
Assert-True $badJobRefused 'O2D22 bad-job live-contract fixture was not refused by the exact job assertion.'
$badInstallationRefused = $false
try { & $endpoint -Preflight -LiveContractFixtureManifest $badInstallationFixture | Out-Null }
catch { $badInstallationRefused = $_.Exception.Message -eq 'O2D22 runtime installation changed.' }
Assert-True $badInstallationRefused 'O2D22 bad-installation live-contract fixture was not refused by the exact installation assertion.'

$gate = [ordered]@{
    schema='argos_o2d22_self_pin_and_live_branch_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D22_SELF_PIN_AND_LIVE_BRANCH_GATE'
    endpointSha256=Get-Sha256 $endpoint;approvedBasePath='work/OPENCV_SCRIBE_O2D13/Invoke-O2D13ScribeEndpoint.ps1';approvedBaseSha256=$expectedEndpointSourceSha256
    pins=$rows.ToArray();pinCount=$rows.Count;pinMatchCount=@($rows | Where-Object { $_.match }).Count
    liveBranchCases=@(
        [pscustomobject]@{id='GOOD_JOB_AND_INSTALLATION';state='PASS';jobAssertionExecuted=$true;installationAssertionExecuted=$true},
        [pscustomobject]@{id='BAD_JOB_HASH_REFUSED';state='PASS';failureBeforeAliasOrImageRead=$true},
        [pscustomobject]@{id='BAD_INSTALLATION_HASH_REFUSED';state='PASS';failureBeforeAliasOrImageRead=$true}
    )
    normalLiveSelfPinCallCount=1;fixtureSelfPinCallCount=1;rehearsalBranchAloneSufficient=$false
    targetExecuted=$false;mutationsPerformed=$false;imageBytesRead=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
[IO.File]::WriteAllText($gatePath, (($gate | ConvertTo-Json -Depth 12) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$gate | ConvertTo-Json -Depth 12
