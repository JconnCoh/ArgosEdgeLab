#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Write-JsonNew([string]$Path, [object]$Value) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D19 no-argument create-new gate exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 8) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function ConvertTo-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

$endpoint = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Invoke-O2D19ScribeEndpoint.ps1'))
$expectedHash = '6961BC0D73216CC661BA8B5ED9FC814D56B5374AB3882DDBFDD5C1783CF8ED2D'
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$gatePath = Join-Path $PSScriptRoot 'O2D19_NO_ARGUMENT_FILE_GATE.json'
Assert-True ((Test-Path -LiteralPath $endpoint -PathType Leaf) -and (Get-FileHash -LiteralPath $endpoint -Algorithm SHA256).Hash -eq $expectedHash) 'O2D19 no-argument test endpoint changed.'
Assert-True (Test-Path -LiteralPath $powershell -PathType Leaf) 'Windows PowerShell 5.1 is absent.'
Assert-True (-not (Test-Path -LiteralPath $gatePath)) 'O2D19 no-argument gate already exists.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d19_no_argument_file_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D19_NO_ARGUMENT_FILE_PREFLIGHT'
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
Assert-True ($process.Start()) 'O2D19 no-argument child did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
Assert-True ($process.WaitForExit(30000)) 'O2D19 no-argument child timed out.'
$process.WaitForExit()
$exitCode = $process.ExitCode
$stdout = [string]$stdoutTask.Result
$stderr = [string]$stderrTask.Result
$process.Dispose()

Assert-True ($exitCode -ne 0) 'O2D19 no-argument laptop control unexpectedly executed the JBOD target.'
Assert-True ($stderr -notmatch "Cannot bind argument to parameter 'Path' because it is an empty string") 'O2D19 retained the PSScriptRoot parameter-default defect.'
$safeBoundary = ($stderr -match "Cannot find drive.+drive with the name 'D' does not exist") -or ($stderr -match 'O2D19 dependency absent:')
Assert-True $safeBoundary 'O2D19 did not advance to an expected laptop-only dependency boundary.'
$gate = [ordered]@{
    schema = 'argos_o2d19_no_argument_file_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D19_EXACT_NO_ARGUMENT_WINDOWS_POWERSHELL_51_FILE'
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
