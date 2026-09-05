#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'

$expectedComputerName = 'DESKTOP-266P787'
$installedQueryPath = 'C:\ProgramData\ArgosInsiteBridgeRO\diagnostics\R18UQ1.ps1'
$queryPath = Join-Path $PSScriptRoot 'Q.ps1'
$inputPath = Join-Path $PSScriptRoot 'I.json'
$expectedQuerySha256 = 'B74E4C5FA522C896E08CE15517C94A14C2FFA36802DB8927C1E9F0B81018DF76'
$expectedInputSha256 = '68947C5434B844A65EF094FBF29E85901ADE66F844254940C9D243FC19F5B84A'

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

Require (Test-Path -LiteralPath $queryPath -PathType Leaf) 'R18UQ1 packaged query is missing.'
Require (Test-Path -LiteralPath $inputPath -PathType Leaf) 'R18UQ1 packaged input is missing.'
Require ((Get-Sha256 $queryPath) -ceq $expectedQuerySha256) 'R18UQ1 packaged query hash changed.'
Require ((Get-Sha256 $inputPath) -ceq $expectedInputSha256) 'R18UQ1 packaged input hash changed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r18uq1_entrypoint_preflight_v1'
        state = 'PASS_R18UQ1_ENTRYPOINT_PREFLIGHT'
        querySha256 = $expectedQuerySha256
        inputSha256 = $expectedInputSha256
        installedQueryPath = $installedQueryPath
        installedPathAccessed = $false
        credentialAccessed = $false
        databaseConnectionOpened = $false
        networkAccessPerformed = $false
        writesPerformed = $false
        imagesAccessed = $false
        jbodAccessed = $false
        tasksOrProcessesAccessed = $false
        queuesAccessed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

$rehearsalPath = [Environment]::GetEnvironmentVariable('ARGOS_R18UQ1_LOCAL_REHEARSAL_INPUT', 'Process')
$localRehearsal = -not [string]::IsNullOrWhiteSpace($rehearsalPath)
if ($localRehearsal) {
    Require (-not [string]::Equals([string]$env:COMPUTERNAME, $expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) 'R18UQ1 local rehearsal is forbidden on the Argos endpoint host.'
    $queryInvocationPath = $queryPath
    $queryText = (& $queryInvocationPath -InputPath $inputPath -RehearsalInputPath $rehearsalPath | Out-String).Trim()
}
else {
    Require ([string]::Equals([string]$env:COMPUTERNAME, $expectedComputerName, [StringComparison]::OrdinalIgnoreCase)) 'R18UQ1 live execution requires the exact Argos endpoint host.'
    Require (Test-Path -LiteralPath $installedQueryPath -PathType Leaf) 'R18UQ1 installed query is missing after endpoint apply.'
    Require ((Get-Sha256 $installedQueryPath) -ceq $expectedQuerySha256) 'R18UQ1 installed query hash changed after endpoint apply.'
    $queryInvocationPath = $installedQueryPath
    $queryText = (& $queryInvocationPath -InputPath $inputPath | Out-String).Trim()
}

Require (-not [string]::IsNullOrWhiteSpace($queryText)) 'R18UQ1 query returned no JSON.'
Require ($queryText.Length -le 33554432) 'R18UQ1 query JSON exceeded the bounded result cap.'
try { $queryResult = $queryText | ConvertFrom-Json }
catch { throw 'R18UQ1 query returned malformed JSON.' }
Require ([string]$queryResult.executionState -ceq 'PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED') 'R18UQ1 query execution token changed.'
Require ([string]$queryResult.disposition -in @('COMPLETE', 'HOLD')) 'R18UQ1 query disposition changed.'
Require (@($queryResult.lots).Count -eq 50) 'R18UQ1 query did not return exactly 50 lot rows.'

[ordered]@{
    schema = 'argos_r18uq1_entrypoint_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED'
    queryDisposition = [string]$queryResult.disposition
    queryState = [string]$queryResult.state
    queryExecutionMode = [string]$queryResult.executionMode
    queryResult = $queryResult
    installedQueryVerified = -not $localRehearsal
    localFileBackedRehearsal = $localRehearsal
    taskOrProcessActionPerformed = $false
    imagesAccessed = $false
    jbodAccessed = $false
    sourceMutationPerformed = $false
    credentialsReturned = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 24 -Compress
