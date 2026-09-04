$ErrorActionPreference = 'Stop'
$runner = 'D:\A2\w\ocv\R18N1\OPENCV_SCRIBE_R18J\Run-R18JScribeCorpus.py'
$output = 'D:\A2\o\ocv\R18N1'
$rows = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" | Where-Object {
    [string]$_.CommandLine -like ('*' + $runner + '*') -and
    [string]$_.CommandLine -like ('*--output-root*' + $output + '*')
})
if ($rows.Count -gt 1) { throw "Multiple R18N-owned workers matched: $($rows.Count)" }
$stopped = @()
if ($rows.Count -eq 1) {
    $stopped = @([pscustomobject]@{
        processId = [uint32]$rows[0].ProcessId
        creationDate = [string]$rows[0].CreationDate
        commandLine = [string]$rows[0].CommandLine
    })
    Stop-Process -Id $rows[0].ProcessId -Force -ErrorAction Stop
    Start-Sleep -Seconds 1
}
$remaining = @(Get-CimInstance Win32_Process -Filter "Name='python.exe' OR Name='pythonw.exe'" | Where-Object {
    [string]$_.CommandLine -like ('*' + $runner + '*') -and
    [string]$_.CommandLine -like ('*--output-root*' + $output + '*')
})
if ($remaining.Count -ne 0) { throw 'R18N-owned worker remains after stop.' }
[ordered]@{
    schema = 'argos_opencv_scribe_r18n_stop_v1'
    state = 'PASS_R18N_OWNED_WORKER_STOPPED'
    computerName = $env:COMPUTERNAME
    matchedBefore = $rows.Count
    stopped = $stopped
    matchedAfter = $remaining.Count
    outputRoot = $output
    unrelatedProcessesTouched = $false
    taskActions = @()
    sourceMutationPerformed = $false
    retryPerformed = $false
} | ConvertTo-Json -Depth 5 -Compress
