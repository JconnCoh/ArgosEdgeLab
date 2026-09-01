#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')][switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\R21P1'
$payloadRoot = Join-Path $root 'payload'
$entrySource = Join-Path $PSScriptRoot 'R21P1_E.ps1'
$evidencePath = Join-Path $projectRoot 'work\OPENCV_SCRIBE_O2D10\O2D10_JBOD_EXACT_TERMINAL_STATE_R17.json'
$gatePath = Join-Path $PSScriptRoot 'R21P1_BUILD_GATE.json'
$expectedEntrySha = '98EDCD1B37CA01119B80E2662390C1E2115CF1A93840FABC2D142D698919A582'
$expectedEvidenceSha = 'CDCB5DCD0691B51D43CFD24FBCBF8CAC96A1F476E736C22D5A22AFD44CD363D9'
$expectedConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Write-NewUtf8Json([string]$Path, [object]$Value, [int]$Depth = 12) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

if ((Get-Sha256 $entrySource) -ne $expectedEntrySha) { throw 'R21P1 entrypoint hash changed.' }
if ((Get-Sha256 $evidencePath) -ne $expectedEvidenceSha) { throw 'R21P1 config evidence hash changed.' }
$tokens = $null; $errors = $null
[void][Management.Automation.Language.Parser]::ParseFile($entrySource, [ref]$tokens, [ref]$errors)
if (@($errors).Count -ne 0) { throw "R21P1 entrypoint parse failed: $($errors[0].Message)" }
$evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json
$configRows = @($evidence.remoteResult.files | Where-Object { [string]$_.path -eq 'C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json' })
if ($configRows.Count -ne 1) { throw 'R21P1 exact config evidence row is missing or ambiguous.' }
if ([string]$configRows[0].sha256 -ne $expectedConfigSha) { throw 'R21P1 evidence config hash changed.' }
$configBytes = (New-Object Text.UTF8Encoding($false)).GetBytes([string]$configRows[0].content)
if ($configBytes.Length -ne 3144 -or (Get-BytesSha256 $configBytes) -ne $expectedConfigSha) {
    throw 'R21P1 exact config reconstruction changed.'
}
if (Test-Path -LiteralPath $root) { throw 'R21P1 short build root already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21P1 build gate already exists.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r21p1_build_preflight_v1'
        state = 'PASS_R21P1_BUILD_PREFLIGHT'
        root = $root
        entrySha256 = $expectedEntrySha
        configBytes = $configBytes.Length
        configSha256 = $expectedConfigSha
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $payloadRoot -Force)
[IO.File]::WriteAllBytes((Join-Path $payloadRoot 'C.json'), $configBytes)
[IO.File]::Copy($entrySource, (Join-Path $payloadRoot 'E.ps1'), $false)
$definition = [ordered]@{
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    maxResultBytes = 1048576
    entryPoint = 'payload/E.ps1'
    changes = @(
        [ordered]@{
            source = 'payload/C.json'
            destination = 'C:/ProgramData/ArgosProjectPortalRO/config/endpoint_jbod.json'
            approvedPredecessorSha256 = @($expectedConfigSha)
            installedSha256 = $expectedConfigSha
            allowCreate = $false
        }
    )
    allowedTaskActions = @()
    rehearsal = [ordered]@{requiredState = 'PASS_R21P1_CURRENT_PREMISE_OBSERVED'}
}
Write-NewUtf8Json -Path (Join-Path $root 'DEFINITION.json') -Value $definition -Depth 12
$gate = [ordered]@{
    schema = 'argos_r21p1_build_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21P1_UNSIGNED_PAYLOAD_BUILT'
    root = $root
    entrySha256 = Get-Sha256 (Join-Path $payloadRoot 'E.ps1')
    configBytes = (Get-Item -LiteralPath (Join-Path $payloadRoot 'C.json')).Length
    configSha256 = Get-Sha256 (Join-Path $payloadRoot 'C.json')
    definitionSha256 = Get-Sha256 (Join-Path $root 'DEFINITION.json')
    identicalConfigSelfSwap = $true
    installedSemanticChange = $false
    taskOrProcessActionCount = 0
    detectorRerun = $false
    signed = $false
    published = $false
    mutationsPerformed = $false
}
Write-NewUtf8Json -Path $gatePath -Value $gate -Depth 8
$gate | ConvertTo-Json -Depth 8
