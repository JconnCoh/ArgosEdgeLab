#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Gate)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of -Preflight or -Gate.' }

function Assert-O3F10([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-O3F10Hash([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

$test = Join-Path $PSScriptRoot 'Test-O3F10SelfTestContract.py'
$expectedTestHash = 'B487BEBCC3236655D08E120911029EAB2BBC63596E4FAEA485904545BB941CC3'
$expectedRuntimeHash = '4942B86A6597E5AEE0128DAA00050ED79BC21F6E709A78EB19CBFEB0C2F39AC9'
Assert-O3F10 (Test-Path -LiteralPath $test -PathType Leaf) 'O3F10 SELF_TEST contract provider is absent.'
Assert-O3F10 ((Get-O3F10Hash $test) -eq $expectedTestHash) 'O3F10 SELF_TEST contract provider hash changed.'
$pythonCommand = Get-Command python.exe -CommandType Application -ErrorAction Stop | Select-Object -First 1
$python = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
Assert-O3F10 ((Get-O3F10Hash $python) -eq $expectedRuntimeHash) 'O3F10 exact rehearsal Python changed.'

$mode = '--preflight'
$expectedState = 'PASS_O3F10_SELF_TEST_CONTRACT_PREFLIGHT'
if ($Gate) {
    $mode = '--gate'
    $expectedState = 'PASS_O3F10_REAL_AND_FIXTURE_SELF_TEST_CONTRACT'
}
$output = @(& $python -I -B $test $mode)
Assert-O3F10 ($LASTEXITCODE -eq 0) 'O3F10 SELF_TEST contract provider failed.'
$json = ($output -join [Environment]::NewLine).Trim()
Assert-O3F10 ([Text.Encoding]::UTF8.GetByteCount($json) -le 1048576) 'O3F10 SELF_TEST contract output exceeded its bound.'
try { $value = $json | ConvertFrom-Json }
catch { throw 'O3F10 SELF_TEST contract output is not one bounded JSON object.' }
Assert-O3F10 ([string]$value.state -eq $expectedState) 'O3F10 SELF_TEST contract state changed.'
if ($Preflight) {
    Assert-O3F10 (-not [bool]$value.mutationsPerformed -and [int]$value.childrenExecuted -eq 0) 'O3F10 SELF_TEST contract preflight mutated or executed a child.'
} else {
    Assert-O3F10 ([bool]$value.schemaMatchesExactly -and [int]$value.childrenExecuted -eq 2) 'O3F10 SELF_TEST schemas did not match exactly.'
    Assert-O3F10 (-not [bool]$value.realMutationsPerformed -and -not [bool]$value.fixtureMutationsPerformed -and -not [bool]$value.sourceImageBytesRead) 'O3F10 SELF_TEST contract widened behavior.'
}
$value | ConvertTo-Json -Depth 8
