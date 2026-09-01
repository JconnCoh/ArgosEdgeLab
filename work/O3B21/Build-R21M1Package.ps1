#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')][switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\R21M1PK'
$payloadRoot = Join-Path $root 'payload'
$entrySource = Join-Path $PSScriptRoot 'Invoke-R21M1MissingOnly.ps1'
$manifestSource = Join-Path $PSScriptRoot 'R21M1_MISSING_ONLY_CASES.json'
$frozenSource = Join-Path $projectRoot 'work\OPENCV_BACKSIDE_NOTCH_O3B10\R18_REGRESSION_CASES.json'
$carrierSource = 'C:\R21P5\payload\C.json'
$gatePath = Join-Path $PSScriptRoot 'R21M1_BUILD_GATE.json'
$expectedEntrySha = 'E29608364151BB7458FA07C50CFCCE389CEF412BB231E9FF95773A5AEB5DB27F'
$expectedManifestSha = '56419244A465B6E45D7409649BB7810BFEF474E26CD6812E7108907741F8270A'
$expectedFrozenSha = '7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
$expectedCarrierSha = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Write-NewUtf8Json([string]$Path, [object]$Value, [int]$Depth = 16) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$pins = @(
    @($entrySource, $expectedEntrySha),
    @($manifestSource, $expectedManifestSha),
    @($frozenSource, $expectedFrozenSha),
    @($carrierSource, $expectedCarrierSha)
)
foreach ($pin in $pins) {
    if (-not (Test-Path -LiteralPath $pin[0] -PathType Leaf) -or (Get-Sha256 $pin[0]) -ne $pin[1]) { throw "R21M1 build dependency absent or changed: $($pin[0])" }
}
if (Test-Path -LiteralPath $root) { throw 'R21M1 short build root already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21M1 build gate already exists.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b21_r21m1_build_preflight_v1'
        state = 'PASS_R21M1_BUILD_PREFLIGHT'
        buildRoot = $root
        payloadFileCount = 4
        selectedCaseCount = 15
        completedCaseRerunCount = 0
        sameBytesCarrier = $true
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $payloadRoot -Force)
[IO.File]::Copy($entrySource, (Join-Path $payloadRoot 'Invoke-R21M1MissingOnly.ps1'), $false)
[IO.File]::Copy($manifestSource, (Join-Path $payloadRoot 'R21M1_MISSING_ONLY_CASES.json'), $false)
[IO.File]::Copy($frozenSource, (Join-Path $payloadRoot 'R18_REGRESSION_CASES.json'), $false)
[IO.File]::Copy($carrierSource, (Join-Path $payloadRoot 'C.json'), $false)
$definition = [ordered]@{
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    maxResultBytes = 67108864
    entryPoint = 'payload/Invoke-R21M1MissingOnly.ps1'
    changes = @([ordered]@{
        source = 'payload/C.json'
        destination = 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json'
        approvedPredecessorSha256 = @($expectedCarrierSha)
        installedSha256 = $expectedCarrierSha
        allowCreate = $false
    })
    allowedTaskActions = @()
    rehearsal = [ordered]@{ requiredState = 'PASS_O3B21_R21M1_MISSING_ONLY_EVIDENCE_EXECUTED' }
}
Write-NewUtf8Json -Path (Join-Path $root 'DEFINITION.json') -Value $definition -Depth 16
$gate = [ordered]@{
    schema = 'argos_o3b21_r21m1_build_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21M1_UNSIGNED_MISSING_ONLY_PACKAGE_BUILT'
    root = $root
    payloadFileCount = 4
    entrySha256 = Get-Sha256 (Join-Path $payloadRoot 'Invoke-R21M1MissingOnly.ps1')
    casesSha256 = Get-Sha256 (Join-Path $payloadRoot 'R21M1_MISSING_ONLY_CASES.json')
    frozenControlsSha256 = Get-Sha256 (Join-Path $payloadRoot 'R18_REGRESSION_CASES.json')
    carrierSha256 = Get-Sha256 (Join-Path $payloadRoot 'C.json')
    definitionSha256 = Get-Sha256 (Join-Path $root 'DEFINITION.json')
    selectedCaseCount = 15
    completedCaseRerunCount = 0
    sameBytesCarrier = $true
    installedSemanticChange = $false
    taskOrProcessActionCount = 0
    signed = $false
    published = $false
    targetExecuted = $false
    mutationsPerformed = $false
}
Write-NewUtf8Json -Path $gatePath -Value $gate -Depth 10
$gate | ConvertTo-Json -Depth 10
