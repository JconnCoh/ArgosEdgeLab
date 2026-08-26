#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$TargetScript,
    [switch]$CapturedChild,
    [switch]$ChildPreflight,
    [switch]$NoTargetArguments
)

$ErrorActionPreference = 'Stop'
if ($CapturedChild) {
    function ConvertTo-ProcessArgument {
        param([AllowEmptyString()][string]$Value)
        if ($Value -notmatch '[\s"]') { return $Value }
        return '"' + $Value.Replace('"', '\"') + '"'
    }
    $targetArguments = if ($ChildPreflight) { @('-Preflight', '-ExpectedComputerName', $env:COMPUTERNAME) } else { @() }
    $list = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $TargetScript) + @($targetArguments)
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $startInfo.Arguments = (@($list | ForEach-Object { ConvertTo-ProcessArgument ([string]$_) }) -join ' ')
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    [pscustomobject]@{ arguments = $startInfo.Arguments; exitCode = $process.ExitCode; stdout = $stdout; stderr = $stderr } | ConvertTo-Json -Compress
    $process.Dispose()
    return
}
try {
    if ($NoTargetArguments) { & $TargetScript }
    else { & $TargetScript -Preflight -ExpectedComputerName $env:COMPUTERNAME }
}
catch {
    [pscustomobject]@{
        message = $_.Exception.Message
        position = $_.InvocationInfo.PositionMessage
        scriptStack = $_.ScriptStackTrace
        targetObject = [string]$_.TargetObject
        fullyQualifiedErrorId = $_.FullyQualifiedErrorId
    } | ConvertTo-Json -Compress
}
