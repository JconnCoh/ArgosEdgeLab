[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $Preflight) { throw 'R4 transport test is non-mutating and requires -Preflight.' }

$runnerPath = Join-Path $PSScriptRoot 'Invoke-ArgosAdminInboundRelayObservationR4.ps1'
if (-not (Test-Path -LiteralPath $runnerPath -PathType Leaf)) { throw "R4 runner is absent: $runnerPath" }
$runnerText = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $runnerPath).Path)

$runnerTokens = $null
$runnerErrors = $null
[void][Management.Automation.Language.Parser]::ParseInput($runnerText,[ref]$runnerTokens,[ref]$runnerErrors)
if (@($runnerErrors).Count -ne 0) { throw "R4 runner parser failure: $($runnerErrors[0].Message)" }

$trigger = 'iex(gcb -r)'
$triggerTokens = $null
$triggerErrors = $null
[void][Management.Automation.Language.Parser]::ParseInput($trigger,[ref]$triggerTokens,[ref]$triggerErrors)
if (@($triggerErrors).Count -ne 0) { throw "R4 trigger parser failure: $($triggerErrors[0].Message)" }
if ($trigger.Length -gt 32) { throw 'R4 trigger exceeds its static transport bound.' }

$gcb = Get-Command gcb -CommandType Alias -ErrorAction Stop
$iex = Get-Command iex -CommandType Alias -ErrorAction Stop
if ([string]$gcb.Definition -ne 'Get-Clipboard') { throw 'gcb no longer resolves to Get-Clipboard.' }
if ([string]$iex.Definition -ne 'Invoke-Expression') { throw 'iex no longer resolves to Invoke-Expression.' }
$rawParameter = (Get-Command Get-Clipboard -ErrorAction Stop).Parameters['Raw']
if ($null -eq $rawParameter) { throw 'Get-Clipboard no longer exposes -Raw.' }

$adminMatch = [regex]::Match($runnerText, '(?s)\$adminGateSource\s*=\s*@''\r?\n(?<source>.*?)\r?\n''@')
if (-not $adminMatch.Success) { throw 'R4 admin-gate source block was not found.' }
$adminTokens = $null
$adminErrors = $null
[void][Management.Automation.Language.Parser]::ParseInput($adminMatch.Groups['source'].Value,[ref]$adminTokens,[ref]$adminErrors)
if (@($adminErrors).Count -ne 0) { throw "R4 admin-gate parser failure: $($adminErrors[0].Message)" }

$requiredTokens = @(
    'hostnameUsesShortClipboardPaste = $true',
    "Send-ShortLiteralKeys 'iex(gcb -r)'",
    "`$hostCommand = 'hostname|clip'",
    'Send-ClipboardPaste',
    'structuredFailureEvidence = $true',
    "state = 'FAIL_O2D10_ARGOS_ADMIN_INBOUND_RELAY_R4_GATE'"
)
$missingTokens = @($requiredTokens | Where-Object { $runnerText.IndexOf($_,[StringComparison]::Ordinal) -lt 0 })
if ($missingTokens.Count -ne 0) { throw "R4 required transport token count missing: $($missingTokens.Count)" }

[pscustomobject]@{
    schema = 'argos_admin_inbound_relay_observation_r4_transport_test_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_ADMIN_INBOUND_RELAY_OBSERVATION_R4_TRANSPORT_TEST'
    runnerPath = $runnerPath
    runnerSha256 = (Get-FileHash -LiteralPath $runnerPath -Algorithm SHA256).Hash
    runnerParserErrors = @($runnerErrors).Count
    trigger = $trigger
    triggerLength = $trigger.Length
    triggerParserErrors = @($triggerErrors).Count
    gcbResolvedCommand = [string]$gcb.Definition
    iexResolvedCommand = [string]$iex.Definition
    getClipboardRawPresent = $true
    adminGateParserErrors = @($adminErrors).Count
    requiredTokenCount = $requiredTokens.Count
    missingTokenCount = $missingTokens.Count
    remoteInputSent = $false
    targetExecuted = $false
    mutationsPerformed = $false
} | ConvertTo-Json -Depth 5
