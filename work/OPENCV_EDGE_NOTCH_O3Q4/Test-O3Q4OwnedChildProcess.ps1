#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate,
    [string]$OutputPath = 'work/OPENCV_EDGE_NOTCH_O3Q4/O3Q4_OWNED_CHILD_PROCESS_GATE.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Gate) { $modeCount++ }
if ($modeCount -ne 1) { throw 'Specify exactly one of -Preflight or -Gate.' }

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3q4_owned_child_process_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O3Q4_OWNED_CHILD_PROCESS_PREFLIGHT'
        ownedProcessStarted = $false
        existingProcessQueried = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 6
    return
}

$startInfo = New-Object Diagnostics.ProcessStartInfo
$startInfo.FileName = $env:ComSpec
$startInfo.Arguments = '/d /c echo O3Q4_OWNED_CHILD_FIXTURE_PASS'
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$ownedChild = New-Object Diagnostics.Process
$ownedChild.StartInfo = $startInfo
if (-not $ownedChild.Start()) { throw 'O3Q4 benign owned child did not start.' }
$ownedChildProcessId = [int]$ownedChild.Id
$startedUtc = $ownedChild.StartTime.ToUniversalTime().ToString('o')
$stdoutTask = $ownedChild.StandardOutput.ReadToEndAsync()
$stderrTask = $ownedChild.StandardError.ReadToEndAsync()
$timedOut = -not $ownedChild.WaitForExit(5000)
if ($timedOut) {
    try { $ownedChild.Kill() } catch {}
    [void]$ownedChild.WaitForExit(2000)
}
if (-not $timedOut) { $ownedChild.WaitForExit() }
$exitCode = if ($timedOut) { $null } else { [int]$ownedChild.ExitCode }
$stdout = [string]$stdoutTask.Result
$stderr = [string]$stderrTask.Result
$ownedChild.Dispose()
if ($timedOut) { throw 'O3Q4 benign owned child exceeded five seconds.' }
if ($exitCode -ne 0) { throw "O3Q4 benign owned child failed: $stderr" }
if ($stdout.Trim() -ne 'O3Q4_OWNED_CHILD_FIXTURE_PASS') { throw 'O3Q4 benign owned child output changed.' }

$result = [ordered]@{
    schema = 'argos_ocv03_o3q4_owned_child_process_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3Q4_OWNED_CHILD_PROCESS_ASSIGNMENT_AND_COLLECTION'
    ownedChildProcessId = $ownedChildProcessId
    ownedChildStartedUtc = $startedUtc
    ownedChildExitCode = $exitCode
    ownedChildTimedOut = $false
    expectedStdoutMatched = $true
    existingProcessQueried = $false
    existingProcessQueryCount = 0
    taskActionPerformed = $false
    imageBytesRead = $false
    sourceMutationPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
$full = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $full) { throw "O3Q4 owned-child gate exists: $full" }
$parent = Split-Path -Parent $full
if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw "O3Q4 owned-child gate parent is absent: $parent" }
[IO.File]::WriteAllText($full, (($result | ConvertTo-Json -Depth 6) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$result | ConvertTo-Json -Depth 6
