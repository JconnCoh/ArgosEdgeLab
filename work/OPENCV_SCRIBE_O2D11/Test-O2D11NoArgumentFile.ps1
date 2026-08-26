#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Test)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function ConvertTo-ProcessArgument([string]$Value) {
    if ($Value -notmatch '[\s"]') { return $Value }
    return '"' + $Value.Replace('"', '\"') + '"'
}

$endpoint = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Invoke-O2D11ScribeEndpoint.ps1'))
$expectedHash = '17C01B42278D7750EAD56CCE5035FEB6F5DBE25520D43CD4293E56F5351837B9'
$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
Assert-True ((Test-Path -LiteralPath $endpoint -PathType Leaf) -and (Get-FileHash -LiteralPath $endpoint -Algorithm SHA256).Hash -eq $expectedHash) 'O2D11 no-argument test endpoint changed.'
Assert-True (Test-Path -LiteralPath $powershell -PathType Leaf) 'Windows PowerShell 5.1 is absent.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d11_no_argument_file_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2D11_NO_ARGUMENT_FILE_PREFLIGHT'
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
Assert-True ($process.Start()) 'O2D11 no-argument child did not start.'
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
Assert-True ($process.WaitForExit(30000)) 'O2D11 no-argument child timed out.'
$process.WaitForExit()
$exitCode = $process.ExitCode
$stdout = [string]$stdoutTask.Result
$stderr = [string]$stderrTask.Result
$process.Dispose()

Assert-True ($exitCode -ne 0) 'O2D11 no-argument laptop control unexpectedly executed the JBOD target.'
Assert-True ($stderr -notmatch "Cannot bind argument to parameter 'Path' because it is an empty string") 'O2D11 retained the PSScriptRoot parameter-default defect.'
Assert-True ($stderr -match "Cannot find drive.+drive with the name 'D' does not exist") 'O2D11 did not advance to the expected laptop-only missing-D boundary.'
[ordered]@{
    schema = 'argos_o2d11_no_argument_file_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D11_EXACT_NO_ARGUMENT_WINDOWS_POWERSHELL_51_FILE'
    endpointSha256 = $expectedHash
    childExitCode = $exitCode
    payloadRootEmptyFailureAbsent = $true
    advancedToExpectedLaptopMissingDriveBoundary = $true
    targetExecuted = $false
    mutationsPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6
