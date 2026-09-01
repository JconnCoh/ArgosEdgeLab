[CmdletBinding()]
param(
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedComputer = 'TXSH-DPMZ0295HR'
$taskName = 'ArgosProjectPortal.Gateway.ShareBridge.RO'
$expectedPrincipal = 'fab.op'
$expectedBridgeSha256 = 'EBEBA79A71402B55B5AAFBCD1A7A202BADA0E95ED6D55DBD7A05609C71879D23'
$expectedConfigSha256 = '05E0DBD9234F74A2754E6EF3E5BE5C67C6529C2FC9034F980C94029FC396683B'
$currentRequestId = 'REQ_20260901T153112935Z_6B71EECCA83C'
$currentRequestZipSha256 = 'A96E29988C4DC9DE3FF4495823409BA14A54E6138616A2D9E873A4EBB0461D0D'

function Get-R25G1Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}
function Assert-R25G1([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

if ($Rehearsal) {
    Assert-R25G1 (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) 'R25G1 rehearsal requires an invocation manifest.'
    $invocation = Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw | ConvertFrom-Json
    Assert-R25G1 ([string]$invocation.schema -eq 'argos_r25g1_rehearsal_invocation_v1') 'R25G1 rehearsal schema changed.'
    Assert-R25G1 ([string]$invocation.computerName -eq $expectedComputer) 'R25G1 rehearsal computer changed.'
    Assert-R25G1 ([string]$invocation.taskName -eq $taskName) 'R25G1 rehearsal task changed.'
    Assert-R25G1 ([string]$invocation.taskPrincipal -eq $expectedPrincipal) 'R25G1 rehearsal principal changed.'
    Assert-R25G1 ([string]$invocation.taskState -in @('Ready', 'Running')) 'R25G1 rehearsal task state is ineligible.'
    Assert-R25G1 ([string]$invocation.requestId -eq $currentRequestId) 'R25G1 rehearsal request changed.'
    Assert-R25G1 ([string]$invocation.requestZipSha256 -eq $currentRequestZipSha256) 'R25G1 rehearsal request hash changed.'
    [ordered]@{
        state = 'PASS_R25G1_CURRENT_REQUEST_SHAREBRIDGE_RESTART_REHEARSAL'
        taskName = $taskName
        taskPrincipal = $expectedPrincipal
        action = 'RESTART'
        requestId = $currentRequestId
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
    return
}

$computerName = [Environment]::MachineName
Assert-R25G1 ($computerName -eq $expectedComputer) "Gateway computer changed: $computerName"
$bridgePath = 'C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-GatewayPortalShareBridge.ps1'
$configPath = 'C:\ProgramData\ArgosProjectPortalRO\config\gateway_share.json'
Assert-R25G1 (Test-Path -LiteralPath $bridgePath -PathType Leaf) 'Gateway ShareBridge is absent.'
Assert-R25G1 ((Get-R25G1Hash $bridgePath) -eq $expectedBridgeSha256) 'Gateway ShareBridge hash changed.'
Assert-R25G1 (Test-Path -LiteralPath $configPath -PathType Leaf) 'Gateway share config is absent.'
Assert-R25G1 ((Get-R25G1Hash $configPath) -eq $expectedConfigSha256) 'Gateway share config hash changed.'
$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
Assert-R25G1 ([string]$config.schema -eq 'argos_project_portal_gateway_share_config_v1') 'Gateway share config schema changed.'
Assert-R25G1 ([bool]$config.reviewOnly -and -not [bool]$config.productionRoutingEnabled) 'Gateway share config authority changed.'

$pendingZip = Join-Path ([string]$config.shareRequestRoot) ($currentRequestId + '.ready.zip')
$processedZip = Join-Path ([string]$config.shareRequestProcessed) ($currentRequestId + '.ready.zip')
Assert-R25G1 (Test-Path -LiteralPath $pendingZip -PathType Leaf) 'Exact current R25NA1 request is absent from the gateway share pending root.'
Assert-R25G1 ((Get-R25G1Hash $pendingZip) -eq $currentRequestZipSha256) 'Exact current R25NA1 pending ZIP hash changed.'
Assert-R25G1 (-not (Test-Path -LiteralPath $processedZip)) 'Exact current R25NA1 request already exists in the processed root.'

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
Assert-R25G1 ([string]$task.Principal.UserId -eq $expectedPrincipal) "Gateway ShareBridge principal changed: $($task.Principal.UserId)"
Assert-R25G1 ([string]$task.State -in @('Ready', 'Running')) "Gateway ShareBridge state is ineligible: $($task.State)"
$taskBefore = [string]$task.State

Stop-ScheduledTask -TaskName $taskName -ErrorAction Stop
$deadline = (Get-Date).AddSeconds(30)
do {
    $state = [string](Get-ScheduledTask -TaskName $taskName -ErrorAction Stop).State
    if ($state -eq 'Running') { Start-Sleep -Milliseconds 250 }
} while ($state -eq 'Running' -and (Get-Date) -lt $deadline)
Assert-R25G1 ($state -ne 'Running') 'Gateway ShareBridge did not stop within 30 seconds.'

Start-ScheduledTask -TaskName $taskName -ErrorAction Stop
$deadline = (Get-Date).AddSeconds(30)
do {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
    $state = [string]$task.State
    if ($state -ne 'Running') { Start-Sleep -Milliseconds 250 }
} while ($state -ne 'Running' -and (Get-Date) -lt $deadline)
Assert-R25G1 ($state -eq 'Running') "Gateway ShareBridge did not enter Running state: $state"

[ordered]@{
    state = 'PASS_R25G1_CURRENT_REQUEST_SHAREBRIDGE_RESTART'
    computerName = $computerName
    taskName = $taskName
    taskPrincipal = [string]$task.Principal.UserId
    taskBefore = $taskBefore
    taskAfter = $state
    action = 'RESTART'
    requestId = $currentRequestId
    requestZipSha256 = $currentRequestZipSha256
    pendingPathVerifiedBeforeRestart = $pendingZip
    processedPathAbsentBeforeRestart = $true
    bridgeSha256 = $expectedBridgeSha256
    configSha256 = $expectedConfigSha256
    requestRetryAuthorized = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 6
