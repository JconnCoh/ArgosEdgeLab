#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Preflight')]
param(
    [Parameter(ParameterSetName = 'Preflight')][switch]$Preflight,
    [Parameter(Mandatory = $true, ParameterSetName = 'Build')][switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$root = 'C:\R21M2PK'
$payloadRoot = Join-Path $root 'payload'
$entryTemplate = Join-Path $PSScriptRoot 'Invoke-R21M1MissingOnly.ps1'
$manifestSource = Join-Path $PSScriptRoot 'R21M2_MISSING_ONLY_CASES.json'
$frozenSource = Join-Path $projectRoot 'work\OPENCV_BACKSIDE_NOTCH_O3B10\R18_REGRESSION_CASES.json'
$detectorSource = Join-Path $projectRoot 'work\OPENCV_BACKSIDE_NOTCH_O3B10\Detect-BacksideNotchOpenCvR21.py'
$configSource = Join-Path $projectRoot 'work\OPENCV_BACKSIDE_NOTCH_O3B10\BACKSIDE_NOTCH_CONFIG_R9.json'
$carrierSource = 'C:\R21P5\payload\C.json'
$gatePath = Join-Path $PSScriptRoot 'R21M2_BUILD_GATE.json'
$expectedTemplateSha = 'E29608364151BB7458FA07C50CFCCE389CEF412BB231E9FF95773A5AEB5DB27F'
$expectedManifestSha = '9E6B44F2D17C80638772CA130C3CC4C027AAE7A935D61247A1A43CAC7735B658'
$expectedFrozenSha = '7F2BF805CC35893B307557680251A94A49F28305E20E3735931F064E82650DF4'
$expectedDetectorSha = '29B41CCE63BC91F99C4FFF24F2DFEECC9BDCDA8ED5314A7671EB40EEBA582A8E'
$expectedConfigSha = '62591703B789D3981819E9AEE36C39DD187B2BC9A02BB335367206C78A064D73'
$expectedCarrierSha = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$expectedGeneratedEntrySha = '605749E7524FF1ED682ED0F770217137B4AD3FDF8933DB26F35E1201D0C81A85'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Write-NewUtf8Json([string]$Path, [object]$Value, [int]$Depth = 16) {
    if (Test-Path -LiteralPath $Path) { throw "Create-new path exists: $Path" }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Get-GeneratedEntryBytes {
    $source = Get-Content -LiteralPath $entryTemplate -Raw
    foreach ($required in @(
        "`$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R21.py'",
        "`$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R9.json'",
        '56419244A465B6E45D7409649BB7810BFEF474E26CD6812E7108907741F8270A'
    )) {
        if (-not $source.Contains($required)) { throw "R21M2 template token absent: $required" }
    }
    $generated = $source.Replace('R21M1', 'R21M2').Replace('r21m1', 'r21m2')
    $generated = $generated.Replace(
        "`$engine = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03_BacksideNotchDevelopment_O3B10R21.py'",
        "`$engine = Join-Path `$PSScriptRoot 'Detect-BacksideNotchOpenCvR21.py'"
    )
    $generated = $generated.Replace(
        "`$configPath = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\OCV03CorpusR1\BACKSIDE_NOTCH_CONFIG_R9.json'",
        "`$configPath = Join-Path `$PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R9.json'"
    )
    $generated = $generated.Replace('56419244A465B6E45D7409649BB7810BFEF474E26CD6812E7108907741F8270A', $expectedManifestSha)
    if ($generated.Contains('OCV03_BacksideNotchDevelopment_O3B10R21.py')) { throw 'R21M2 generated entry still assumes installed R21 provider.' }
    if (-not $generated.Contains("`$engine = Join-Path `$PSScriptRoot 'Detect-BacksideNotchOpenCvR21.py'")) { throw 'R21M2 direct payload detector line absent.' }
    if (-not $generated.Contains("`$configPath = Join-Path `$PSScriptRoot 'BACKSIDE_NOTCH_CONFIG_R9.json'")) { throw 'R21M2 direct payload config line absent.' }
    (New-Object Text.UTF8Encoding($false)).GetBytes($generated)
}

$pins = @(
    @($entryTemplate, $expectedTemplateSha),
    @($manifestSource, $expectedManifestSha),
    @($frozenSource, $expectedFrozenSha),
    @($detectorSource, $expectedDetectorSha),
    @($configSource, $expectedConfigSha),
    @($carrierSource, $expectedCarrierSha)
)
foreach ($pin in $pins) {
    if (-not (Test-Path -LiteralPath $pin[0] -PathType Leaf) -or (Get-Sha256 $pin[0]) -ne $pin[1]) { throw "R21M2 build dependency absent or changed: $($pin[0])" }
}
$entryBytes = Get-GeneratedEntryBytes
if ((Get-BytesSha256 $entryBytes) -ne $expectedGeneratedEntrySha) { throw 'R21M2 generated entry bytes changed.' }
if (Test-Path -LiteralPath $root) { throw 'R21M2 short build root already exists.' }
if (Test-Path -LiteralPath $gatePath) { throw 'R21M2 build gate already exists.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o3b21_r21m2_build_preflight_v1'
        state = 'PASS_R21M2_BUILD_PREFLIGHT'
        buildRoot = $root
        payloadFileCount = 6
        generatedEntrySha256 = $expectedGeneratedEntrySha
        payloadDetectorSha256 = $expectedDetectorSha
        payloadConfigSha256 = $expectedConfigSha
        installedR21ProviderRequired = $false
        selectedCaseCount = 15
        completedCaseRerunCount = 0
        sameBytesCarrier = $true
        targetExecuted = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 5
    return
}

[void](New-Item -ItemType Directory -Path $payloadRoot -Force)
[IO.File]::WriteAllBytes((Join-Path $payloadRoot 'Invoke-R21M2MissingOnly.ps1'), $entryBytes)
[IO.File]::Copy($manifestSource, (Join-Path $payloadRoot 'R21M2_MISSING_ONLY_CASES.json'), $false)
[IO.File]::Copy($frozenSource, (Join-Path $payloadRoot 'R18_REGRESSION_CASES.json'), $false)
[IO.File]::Copy($detectorSource, (Join-Path $payloadRoot 'Detect-BacksideNotchOpenCvR21.py'), $false)
[IO.File]::Copy($configSource, (Join-Path $payloadRoot 'BACKSIDE_NOTCH_CONFIG_R9.json'), $false)
[IO.File]::Copy($carrierSource, (Join-Path $payloadRoot 'C.json'), $false)
$definition = [ordered]@{
    targetRole = 'JBOD'
    jobClass = 'MAINTENANCE_PATCH'
    maxResultBytes = 67108864
    entryPoint = 'payload/Invoke-R21M2MissingOnly.ps1'
    changes = @([ordered]@{
        source = 'payload/C.json'
        destination = 'C:/ProgramData/ArgosEdgeLabRO/AllWaferProcessorV2/PROCESSOR_CONFIG.json'
        approvedPredecessorSha256 = @($expectedCarrierSha)
        installedSha256 = $expectedCarrierSha
        allowCreate = $false
    })
    allowedTaskActions = @()
    rehearsal = [ordered]@{ requiredState = 'PASS_O3B21_R21M2_MISSING_ONLY_EVIDENCE_EXECUTED' }
}
Write-NewUtf8Json -Path (Join-Path $root 'DEFINITION.json') -Value $definition -Depth 16
$gate = [ordered]@{
    schema = 'argos_o3b21_r21m2_build_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R21M2_UNSIGNED_DIRECT_PAYLOAD_PACKAGE_BUILT'
    root = $root
    payloadFileCount = 6
    entrySha256 = Get-Sha256 (Join-Path $payloadRoot 'Invoke-R21M2MissingOnly.ps1')
    casesSha256 = Get-Sha256 (Join-Path $payloadRoot 'R21M2_MISSING_ONLY_CASES.json')
    frozenControlsSha256 = Get-Sha256 (Join-Path $payloadRoot 'R18_REGRESSION_CASES.json')
    detectorSha256 = Get-Sha256 (Join-Path $payloadRoot 'Detect-BacksideNotchOpenCvR21.py')
    configSha256 = Get-Sha256 (Join-Path $payloadRoot 'BACKSIDE_NOTCH_CONFIG_R9.json')
    carrierSha256 = Get-Sha256 (Join-Path $payloadRoot 'C.json')
    definitionSha256 = Get-Sha256 (Join-Path $root 'DEFINITION.json')
    installedR21ProviderRequired = $false
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
