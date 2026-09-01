#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight, [switch]$Apply)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-R25G1Direct([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-R25G1DirectHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

$selected = 0
if ($Preflight) { $selected++ }
if ($Apply) { $selected++ }
Assert-R25G1Direct ($selected -eq 1) 'Select exactly one R25G1 direct action.'

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$computerName = 'txsh-dpmz0295hr.amer.ii-vi.net'
$endpointName = 'ArgosGatewayMaintenance'
$requestId = 'REQ_20260901T161846627Z_6B71EECCA831'
$zipPath = 'C:\R25G1A\REQ_20260901T161846627Z_6B71EECCA831.ready.zip'
$zipBytes = 3991
$zipSha256 = 'F08FE0DD6E2A4ED7C54132239ED411D5F3F5D0445BB8C29B63AA04C3193A6F2B'
$branch = 'codex/fiducial-opencv-d-drive'

Assert-R25G1Direct (Test-Path -LiteralPath $zipPath -PathType Leaf) 'Frozen R25G1 ZIP is absent.'
Assert-R25G1Direct ((Get-Item -LiteralPath $zipPath).Length -eq $zipBytes) 'Frozen R25G1 ZIP length changed.'
Assert-R25G1Direct ((Get-R25G1DirectHash $zipPath) -eq $zipSha256) 'Frozen R25G1 ZIP hash changed.'
Assert-R25G1Direct ((git -C $project branch --show-current) -eq $branch) 'R25G1 branch changed.'
$localCommit = git -C $project rev-parse HEAD
$originCommit = git -C $project rev-parse "refs/remotes/origin/$branch"
Assert-R25G1Direct ($localCommit -eq $originCommit) 'R25G1 local and origin commits differ.'
Assert-R25G1Direct (-not [bool](git -C $project status --porcelain)) 'R25G1 worktree is not clean.'

if ($Preflight) {
    [ordered]@{
        state = 'PASS_R25G1_DIRECT_PREFLIGHT'
        computerName = $computerName
        endpointName = $endpointName
        requestId = $requestId
        zipBytes = $zipBytes
        zipSha256 = $zipSha256
        localCommit = $localCommit
        originCommit = $originCommit
        endpointContacted = $false
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
    return
}

$session = $null
$proxyModule = $null
try {
    $session = New-PSSession -ComputerName $computerName -ConfigurationName $endpointName -Authentication Kerberos -ErrorAction Stop
    $proxyModule = Import-PSSession -Session $session -CommandName Receive-ArgosGatewayMaintenancePackage,Invoke-ArgosGatewayMaintenancePackage,Get-ArgosGatewayMaintenanceResponse -Prefix R25G1 -DisableNameChecking -AllowClobber -ErrorAction Stop
    $packageBytes = [IO.File]::ReadAllBytes($zipPath)
    $received = Receive-R25G1ArgosGatewayMaintenancePackage -PackageBytes $packageBytes -PackageSha256 $zipSha256 -ErrorAction Stop
    Assert-R25G1Direct ([string]$received.State -eq 'PASS_SIGNED_GATEWAY_PACKAGE_RECEIVED') 'R25G1 gateway package receipt did not pass.'
    Assert-R25G1Direct ([string]$received.RequestId -eq $requestId) 'R25G1 gateway receipt request ID changed.'
    $invoked = Invoke-R25G1ArgosGatewayMaintenancePackage -RequestId $requestId -ErrorAction Stop
    Assert-R25G1Direct ([string]$invoked.State -eq 'PASS_ARGOS_GATEWAY_MAINTENANCE_REQUEST_PROCESSED') 'R25G1 gateway invocation did not pass.'
    $response = Get-R25G1ArgosGatewayMaintenanceResponse -RequestId $requestId -ErrorAction Stop
    Assert-R25G1Direct ([string]$response.State -eq 'PASS_ARGOS_GATEWAY_MAINTENANCE_RESPONSE_READ') 'R25G1 gateway response read did not pass.'
    Assert-R25G1Direct ([string]$response.RequestId -eq $requestId) 'R25G1 response request ID changed.'
    [ordered]@{
        state = 'PASS_R25G1_DIRECT_SINGLE_ATTEMPT'
        received = $received
        invoked = $invoked
        response = $response
        requestRetryAuthorized = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 12 -Compress
}
finally {
    if ($null -ne $proxyModule) { Remove-Module -Name $proxyModule.Name -Force -ErrorAction SilentlyContinue }
    if ($null -ne $session) { Remove-PSSession -Session $session -ErrorAction SilentlyContinue }
}
