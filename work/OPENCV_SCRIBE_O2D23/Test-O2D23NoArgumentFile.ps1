#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}
function Write-JsonNew([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D23 no-argument create-new gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function ConvertTo-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

$endpoint = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Invoke-O2D23ScribeEndpoint.ps1'))
$expectedHash = '159BD82528E505DE69BDEEE4C3A3B29402BA9281939C57F6187587E9047D9740'
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$gatePath = Join-Path $PSScriptRoot 'O2D23_NO_ARGUMENT_FILE_GATE.json'
Assert-True ((Test-Path -LiteralPath $endpoint -PathType Leaf) -and (Get-Sha256 $endpoint) -eq $expectedHash) 'O2D23 no-argument test endpoint changed.'
Assert-True (Test-Path -LiteralPath $powershell -PathType Leaf) 'Windows PowerShell 5.1 is absent.'
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O2D23 no-argument gate already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d23_no_argument_file_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D23_NO_ARGUMENT_FILE_PREFLIGHT'
        endpointSha256 = $expectedHash
        exactArguments = '-NoProfile -ExecutionPolicy Bypass -File <endpoint>'
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

$list = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $endpoint)
$startInfo = New-Object Diagnostics.ProcessStartInfo
$startInfo.FileName = $powershell
$startInfo.Arguments = (@($list | ForEach-Object { ConvertTo-ProcessArgument ([string]$_) }) -join ' ')
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$process = New-Object Diagnostics.Process
$process.StartInfo = $startInfo
Assert-True ($process.Start()) 'O2D23 no-argument child did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
Assert-True ($process.WaitForExit(30000)) 'O2D23 no-argument child timed out.'
$process.WaitForExit()
$exitCode = $process.ExitCode
$stdout = [string]$stdoutTask.Result
$stderr = [string]$stderrTask.Result
$process.Dispose()

Assert-True ($exitCode -ne 0) 'O2D23 no-argument laptop control unexpectedly executed the JBOD target.'
Assert-True ($stderr -notmatch "Cannot bind argument to parameter 'Path' because it is an empty string") 'O2D23 retained the PSScriptRoot parameter-default defect.'
$safeBoundary = ($stderr -match "Cannot find drive.+drive with the name 'D' does not exist") -or ($stderr -match 'O2D23 dependency absent:')
Assert-True $safeBoundary 'O2D23 did not advance to an expected laptop-only dependency boundary.'
$gate = [ordered]@{
    schema = 'argos_o2d23_no_argument_file_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D23_EXACT_NO_ARGUMENT_WINDOWS_POWERSHELL_51_FILE'
    endpointSha256 = $expectedHash
    childExitCode = $exitCode
    payloadRootEmptyFailureAbsent = $true
    advancedToExpectedLaptopDependencyBoundary = $true
    targetExecuted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonNew $gatePath $gate
$gate | ConvertTo-Json -Depth 6
