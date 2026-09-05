#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [string]$TestRoot,
    [string]$GatePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18UQ1 entrypoint rehearsal requires Windows PowerShell 5.1 exactly.'
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$entryPath = Join-Path $PSScriptRoot 'E.ps1'
$queryPath = Join-Path $PSScriptRoot 'Q.ps1'
$inputPath = Join-Path $PSScriptRoot 'I.json'
foreach ($path in @($entryPath, $queryPath, $inputPath)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "R18UQ1 rehearsal dependency missing: $path"
}
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($entryPath, [ref]$tokens, [ref]$parseErrors)
Require (@($parseErrors).Count -eq 0) 'R18UQ1 E.ps1 parse failed.'

$preflightText = (& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entryPath -Preflight | Out-String).Trim()
Require ($LASTEXITCODE -eq 0) 'R18UQ1 entrypoint preflight exited nonzero.'
$entryPreflight = $preflightText | ConvertFrom-Json
Require ([string]$entryPreflight.state -ceq 'PASS_R18UQ1_ENTRYPOINT_PREFLIGHT') 'R18UQ1 entrypoint preflight state changed.'
Require (-not [bool]$entryPreflight.installedPathAccessed -and -not [bool]$entryPreflight.credentialAccessed -and -not [bool]$entryPreflight.networkAccessPerformed -and -not [bool]$entryPreflight.writesPerformed) 'R18UQ1 entrypoint preflight boundary changed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r18uq1_entrypoint_rehearsal_preflight_v1'
        state = 'PASS_R18UQ1_ENTRYPOINT_REHEARSAL_PREFLIGHT'
        entrypointSha256 = Get-Sha256 $entryPath
        querySha256 = Get-Sha256 $queryPath
        inputSha256 = Get-Sha256 $inputPath
        entrypointParseErrors = 0
        entrypointPreflightPassed = $true
        testRootCreated = $false
        gateCreated = $false
        liveSqlExecuted = $false
        signingKeyAccessed = $false
        writesPerformed = $false
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

Require (-not [string]::IsNullOrWhiteSpace($TestRoot) -and -not [string]::IsNullOrWhiteSpace($GatePath)) 'Test requires TestRoot and GatePath.'
$root = [IO.Path]::GetFullPath($TestRoot)
$gate = [IO.Path]::GetFullPath($GatePath)
Require (-not (Test-Path -LiteralPath $root)) 'R18UQ1 entrypoint rehearsal root must be fresh.'
Require (-not (Test-Path -LiteralPath $gate)) 'R18UQ1 entrypoint rehearsal gate must be fresh.'
[void](New-Item -ItemType Directory -Path $root)

$input = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json
$directRows = New-Object Collections.Generic.List[object]
$historyRows = New-Object Collections.Generic.List[object]
for ($index = 0; $index -lt @($input.queryKeys).Count; $index++) {
    $lot = [string]$input.queryKeys[$index]
    $scribe = 'R' + ($index + 1).ToString('D11')
    $unit = $lot + '-001'
    $directRows.Add([ordered]@{ParentContainer=$lot;UnitContainer=$unit;Scribe=$scribe}) | Out-Null
    $historyRows.Add([ordered]@{Scribe=$scribe;SourceEpiContainer=('EPI-' + ($index + 1).ToString('D4'));IssuedWaferContainer=$unit;ParentContainer=$lot}) | Out-Null
}
$fixture = [ordered]@{
    schema = 'argos_r18uq1_sql_row_rehearsal_v1'
    directRows = $directRows.ToArray()
    issueHistoryRows = $historyRows.ToArray()
}
$fixturePath = Join-Path $root 'R.json'
Write-JsonCreateNew -Path $fixturePath -Value $fixture

$priorRehearsal = [Environment]::GetEnvironmentVariable('ARGOS_R18UQ1_LOCAL_REHEARSAL_INPUT', 'Process')
try {
    [Environment]::SetEnvironmentVariable('ARGOS_R18UQ1_LOCAL_REHEARSAL_INPUT', $fixturePath, 'Process')
    $argumentList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $entryPath)
    $resultText = (& powershell.exe @argumentList | Out-String).Trim()
    Require ($LASTEXITCODE -eq 0) 'R18UQ1 no-argument packaged entrypoint rehearsal exited nonzero.'
}
finally {
    [Environment]::SetEnvironmentVariable('ARGOS_R18UQ1_LOCAL_REHEARSAL_INPUT', $priorRehearsal, 'Process')
}
$result = $resultText | ConvertFrom-Json
Require ([string]$result.state -ceq 'PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED') 'R18UQ1 no-argument entrypoint state changed.'
Require ([string]$result.queryDisposition -ceq 'COMPLETE') 'R18UQ1 no-argument entrypoint did not preserve COMPLETE.'
Require ([bool]$result.localFileBackedRehearsal -and -not [bool]$result.installedQueryVerified) 'R18UQ1 no-argument rehearsal lane changed.'
Require (@($result.queryResult.lots).Count -eq 50 -and [int]$result.queryResult.counts.queryLots -eq 50) 'R18UQ1 no-argument entrypoint lot cardinality changed.'
Require (-not [bool]$result.taskOrProcessActionPerformed -and -not [bool]$result.imagesAccessed -and -not [bool]$result.jbodAccessed -and -not [bool]$result.sourceMutationPerformed) 'R18UQ1 no-argument entrypoint widened its action boundary.'

$gateValue = [ordered]@{
    schema = 'argos_r18uq1_entrypoint_rehearsal_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18UQ1_EXACT_NO_ARGUMENT_ENTRYPOINT_REHEARSAL'
    windowsPowerShell = [ordered]@{major=5;minor=1;version=$PSVersionTable.PSVersion.ToString()}
    entrypointSha256 = Get-Sha256 $entryPath
    querySha256 = Get-Sha256 $queryPath
    inputSha256 = Get-Sha256 $inputPath
    exactNoScriptArguments = $true
    fileBackedSyntheticRows = $true
    queryLotCount = [int]$result.queryResult.counts.queryLots
    queryDisposition = [string]$result.queryDisposition
    queryExecutionState = [string]$result.state
    credentialScopePropertyRequired = $false
    liveSqlExecuted = $false
    credentialAccessed = $false
    taskOrProcessActionPerformed = $false
    imagesAccessed = $false
    jbodAccessed = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path $gate -Value $gateValue
$gateValue | ConvertTo-Json -Depth 12 -Compress
