[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Gate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FileSha256([string]$Path) {
    $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
        finally { $sha.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Resolve-Pin([string]$ProjectRoot, [object]$Pin, [string]$Label) {
    $value = [string]$Pin.path
    if (-not [IO.Path]::IsPathRooted($value)) { $value = Join-Path $ProjectRoot $value.Replace('/', '\') }
    $value = [IO.Path]::GetFullPath($value)
    if (-not (Test-Path -LiteralPath $value -PathType Leaf)) { throw "$Label is absent: $value" }
    if ((Get-FileSha256 -Path $value) -cne [string]$Pin.sha256) { throw "$Label hash mismatch." }
    return $value
}

function Get-PropertyNames([object]$Value) {
    if ($Value -is [Collections.IDictionary]) { return @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object) }
    return @($Value.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object)
}

function Assert-ExactProperties([object]$Value, [string[]]$Expected, [string]$Context) {
    $actual = @(Get-PropertyNames -Value $Value)
    $expectedSorted = @($Expected | Sort-Object)
    $missing = @($expectedSorted | Where-Object { $actual -notcontains $_ })
    $extra = @($actual | Where-Object { $expectedSorted -notcontains $_ })
    if ($missing.Count -ne 0 -or $extra.Count -ne 0) { throw "$Context properties changed. Missing=$($missing -join ',') Extra=$($extra -join ',')" }
}

function Assert-MatchingResult([object]$Result, [object]$Manifest, [object]$Request, [string[]]$RequiredProperties) {
    Assert-ExactProperties -Value $Result -Expected $RequiredProperties -Context 'Collected result'
    if ([string]$Result.schema -cne [string]$Manifest.expectedResult.schema) { throw 'Collected result schema mismatch.' }
    if ([string]$Result.nonce -cne [string]$Manifest.expectedResult.nonce) { throw 'Collected result nonce mismatch.' }
    if ([string]$Result.computerName -cne [string]$Manifest.expectedComputerName) { throw 'Collected result computer mismatch.' }
    if ([string]$Result.requestSha256 -cne [string]$Manifest.expectedResult.requestSha256) { throw 'Collected result request hash mismatch.' }
    if ([string]$Result.requestSchemaSha256 -cne [string]$Request.requestSchemaSha256) { throw 'Collected request-schema hash mismatch.' }
    if ([string]$Result.resultSchemaSha256 -cne [string]$Request.resultSchemaSha256) { throw 'Collected result-schema hash mismatch.' }
    if ([string]$Result.operation -cne [string]$Request.operation) { throw 'Collected operation mismatch.' }
    if ([int]$Result.operationTimeoutSeconds -ne [int]$Request.operationTimeoutSeconds) { throw 'Collected operation timeout mismatch.' }
    if (@('PASS_ARGOS_DIRECT_OBSERVATION','FAIL_ARGOS_DIRECT_OBSERVATION') -cnotcontains [string]$Result.state) { throw 'Collected result state is unsupported.' }
    if ([string]$Result.state -ceq 'PASS_ARGOS_DIRECT_OBSERVATION') {
        if ([string]$Result.scalar -cne [string]$Manifest.expectedResult.scalar) { throw 'Collected PASS scalar mismatch.' }
        if ([string]$Result.operationState -cne 'OBSERVED') { throw 'Collected PASS operation state mismatch.' }
    }
    else {
        if (-not [string]::IsNullOrEmpty([string]$Result.scalar)) { throw 'Collected FAIL scalar must be empty.' }
        if (@('ERROR','TIMEOUT') -cnotcontains [string]$Result.operationState) { throw 'Collected FAIL operation state mismatch.' }
    }
    foreach ($property in @(
        'taskOrProcessManagementPerformed','processManagementPerformed','imageBytesRead',
        'sourceMutationPerformed','targetPersistentMutationPerformed','providerActivationPerformed',
        'productionRoutingEnabled'
    )) {
        if ([bool]$Result.$property) { throw "Collected result reports prohibited action: $property" }
    }
    $rows = @($Result.rows)
    if ($rows.Count -gt [int]$Request.maximumRows) { throw 'Collected row count exceeds the request maximum.' }
    if ([int]$Result.exactMatchCount -ne $rows.Count) { throw 'Collected exact-match count mismatch.' }
    foreach ($row in $rows) {
        Assert-ExactProperties -Value $row -Expected @('processId','executablePath','commandLine','creationUtc') -Context 'Collected row'
        if ([string]$row.executablePath.Length -gt [int]$Request.maximumFieldCharacters) { throw 'Collected executable path is overlong.' }
        if ([string]$row.commandLine.Length -gt [int]$Request.maximumFieldCharacters) { throw 'Collected command line is overlong.' }
        if ([string]$row.creationUtc.Length -gt 64) { throw 'Collected creation timestamp is overlong.' }
    }
}

$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Gate) { $modeCount++ }
if ($modeCount -ne 1) { throw 'Select exactly one of -Preflight or -Gate.' }

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Collector invocation is absent: $manifestPath" }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$manifest.schema -cne 'argos_direct_observation_collector_invocation_v1') { throw 'Unexpected collector invocation schema.' }
$lifecycle = [string]$manifest.artifactLifecycle
if (@('DRAFT','FROZEN') -cnotcontains $lifecycle) { throw 'Collector invocation lifecycle is not designable.' }
if ($Gate -and $lifecycle -cne 'FROZEN') { throw 'Collector gate requires a frozen invocation.' }
$projectRoot = [IO.Path]::GetFullPath([string]$manifest.projectRoot).TrimEnd('\')
$collectorPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.collector -Label 'Collector'
if (-not $collectorPath.Equals([IO.Path]::GetFullPath($PSCommandPath), [StringComparison]::OrdinalIgnoreCase)) { throw 'Collector invocation pins a different entrypoint.' }
$transportInvocationPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.transportInvocation -Label 'Transport invocation'
$requestPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.request -Label 'Request'
$resultSchemaPath = Resolve-Pin -ProjectRoot $projectRoot -Pin $manifest.resultSchema -Label 'Result schema'
$transportInvocation = Get-Content -LiteralPath $transportInvocationPath -Raw | ConvertFrom-Json -ErrorAction Stop
$request = Get-Content -LiteralPath $requestPath -Raw | ConvertFrom-Json -ErrorAction Stop
$resultSchema = Get-Content -LiteralPath $resultSchemaPath -Raw | ConvertFrom-Json -ErrorAction Stop
$requiredProperties = @($resultSchema.required | ForEach-Object { [string]$_ } | Sort-Object)
if ($requiredProperties.Count -ne 23) { throw 'Result-schema required property count changed.' }
if ([string]$transportInvocation.expectedResult.schema -cne [string]$manifest.expectedResult.schema -or
    [string]$transportInvocation.expectedResult.nonce -cne [string]$manifest.expectedResult.nonce -or
    [string]$transportInvocation.expectedResult.scalar -cne [string]$manifest.expectedResult.scalar) { throw 'Transport and collector expected result contracts differ.' }
if ([string]$request.nonce -cne [string]$manifest.expectedResult.nonce -or [string]$request.expectedScalar -cne [string]$manifest.expectedResult.scalar) { throw 'Request and collector expected result contracts differ.' }

$terminalPath = [string]$transportInvocation.terminalGatePath
if (-not [IO.Path]::IsPathRooted($terminalPath)) { $terminalPath = Join-Path $projectRoot $terminalPath.Replace('/', '\') }
$terminalPath = [IO.Path]::GetFullPath($terminalPath)
$outputPath = [string]$manifest.outputPath
if (-not [IO.Path]::IsPathRooted($outputPath)) { $outputPath = Join-Path $projectRoot $outputPath.Replace('/', '\') }
$outputPath = [IO.Path]::GetFullPath($outputPath)

if ($Preflight) {
    if (Test-Path -LiteralPath $terminalPath) { throw "Preflight refuses an existing terminal gate: $terminalPath" }
    if (Test-Path -LiteralPath $outputPath) { throw "Preflight refuses existing collector output: $outputPath" }
    [ordered]@{
        schema = 'argos_direct_observation_collector_preflight_v1'
        state = 'PASS_ARGOS_DIRECT_OBSERVATION_COLLECTOR_PREFLIGHT'
        invocationManifestSha256 = Get-FileSha256 -Path $manifestPath
        collectorSha256 = [string]$manifest.collector.sha256
        transportInvocationSha256 = [string]$manifest.transportInvocation.sha256
        requestFileSha256 = [string]$manifest.request.sha256
        resultSchemaSha256 = [string]$manifest.resultSchema.sha256
        requiredResultPropertyCount = $requiredProperties.Count
        terminalPath = $terminalPath
        outputPath = $outputPath
        clipboardRead = $false
        clipboardChanged = $false
        remoteInputSent = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 6
    return
}

if (-not (Test-Path -LiteralPath $terminalPath -PathType Leaf)) { throw "Matching terminal gate is absent: $terminalPath" }
if (Test-Path -LiteralPath $outputPath) { throw "Create-new collector output already exists: $outputPath" }
$terminal = Get-Content -LiteralPath $terminalPath -Raw | ConvertFrom-Json -ErrorAction Stop
if ([string]$terminal.invocationManifestSha256 -cne [string]$manifest.transportInvocation.sha256) { throw 'Terminal invocation hash mismatch.' }
if (-not [bool]$terminal.resultReturned) { throw 'Terminal gate does not prove a matching result returned.' }
if ([string]$terminal.resultNonce -cne [string]$manifest.expectedResult.nonce) { throw 'Terminal result nonce mismatch.' }

$clipboardText = Get-Clipboard -Raw -ErrorAction Stop
if ([string]::IsNullOrWhiteSpace($clipboardText)) { throw 'Clipboard has no result.' }
if ($clipboardText.Length -gt [int]$manifest.maximumClipboardCharacters) { throw 'Clipboard result exceeds its character bound.' }
$result = $clipboardText | ConvertFrom-Json -ErrorAction Stop
Assert-MatchingResult -Result $result -Manifest $manifest -Request $request -RequiredProperties $requiredProperties

$collection = [ordered]@{
    schema = 'argos_direct_observation_collection_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_DIRECT_OBSERVATION_RESULT_COLLECTED'
    invocationManifestSha256 = Get-FileSha256 -Path $manifestPath
    terminalGateSha256 = Get-FileSha256 -Path $terminalPath
    transportInvocationSha256 = [string]$manifest.transportInvocation.sha256
    requestFileSha256 = [string]$manifest.request.sha256
    resultSchemaSha256 = [string]$manifest.resultSchema.sha256
    result = $result
    clipboardCharacters = $clipboardText.Length
    clipboardChanged = $false
    remoteInputSent = $false
    taskOrProcessManagementPerformed = $false
    imageBytesRead = $false
    sourceMutationPerformed = $false
    targetPersistentMutationPerformed = $false
    providerActivationPerformed = $false
    productionRoutingEnabled = $false
}
$json = $collection | ConvertTo-Json -Depth 12
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($json + [Environment]::NewLine)
$stream = [IO.File]::Open($outputPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $stream.Write($bytes, 0, $bytes.Length) }
finally { $stream.Dispose() }
$json
