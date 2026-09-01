#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expectedComputer = 'A1025645101'
$portalRoot = 'C:\ProgramData\ArgosProjectPortalRO'
$configPath = Join-Path $portalRoot 'config\endpoint_jbod.json'
$workerPath = Join-Path $portalRoot 'bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
$taskName = 'ArgosProjectPortal.JBOD.Endpoint.RO'
$processorRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$processorScriptLeaf = 'Run-JbodAllWaferProcessor.ps1'
$desiredPath = Join-Path $PSScriptRoot 'N.json'
$expectedConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$expectedWorkerSha = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$expectedDesiredSha = '3496F1D868C76943451914B173E2582D8705F3A4176AC98ECDDDF5ECFDE37A52'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Get-CanonicalJson([object]$Value) { return ($Value | ConvertTo-Json -Depth 32 -Compress) }
function Get-TextSha256([string]$Text) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}
function Convert-CreationUtc([object]$Value) {
    if ($Value -is [DateTime]) { return ([DateTime]$Value).ToUniversalTime().ToString('o') }
    return ([Management.ManagementDateTimeConverter]::ToDateTime([string]$Value)).ToUniversalTime().ToString('o')
}

foreach ($command in @('Get-FileHash','Get-ScheduledTask','Export-ScheduledTask','Get-CimInstance')) {
    if ($null -eq (Get-Command $command -ErrorAction Stop)) { throw "Required command is absent: $command" }
}
if ($Preflight) {
    [ordered]@{schema='argos_r21p3_capability_preflight_v1';state='PASS_R21P3_CAPABILITY_PREFLIGHT';expectedConfigSha256=$expectedConfigSha;expectedWorkerSha256=$expectedWorkerSha;desiredConfigSha256=$expectedDesiredSha;mutationsPerformed=$false} | ConvertTo-Json -Depth 5
    return
}
if ($env:COMPUTERNAME -ne $expectedComputer) { throw "Wrong computer: $($env:COMPUTERNAME)" }
foreach ($path in @($configPath,$workerPath,$desiredPath)) { if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is absent: $path" } }
if ((Get-Sha256 $configPath) -ne $expectedConfigSha) { throw 'Current endpoint config hash changed.' }
if ((Get-Sha256 $workerPath) -ne $expectedWorkerSha) { throw 'Current endpoint worker hash changed.' }
if ((Get-Sha256 $desiredPath) -ne $expectedDesiredSha) { throw 'Desired endpoint config payload hash changed.' }

$current = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$desired = Get-Content -LiteralPath $desiredPath -Raw | ConvertFrom-Json
if ([string]$current.schema -ne 'argos_project_portal_endpoint_config_v1' -or [string]$current.role -ne 'JBOD' -or -not [bool]$current.reviewOnly -or [bool]$current.productionRoutingEnabled) { throw 'Current endpoint safety identity changed.' }
$expected = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$expected.approvedDataRoots = @($expected.approvedDataRoots) + [pscustomobject]@{name='JBOD_R21_TARGETED_OUTPUT';path='D:\R21TG1'}
$extraHashes = @()
foreach ($index in 0..33) {
    $i = '{0:D2}' -f $index
    $extraHashes += "D:\R21TG1\J$i.json"
    foreach ($leaf in @('RESULT.json','BF_review.jpg','DF_review.jpg','BF_holder_exclusion.png','DF_holder_exclusion.png')) { $extraHashes += "D:\R21TG1\O$i\$leaf" }
}
$expected.status.hashFiles = @($expected.status.hashFiles) + $extraHashes
if ($extraHashes.Count -ne 204) { throw 'R21P3 exact hash inventory construction changed.' }
if ((Get-CanonicalJson $desired) -cne (Get-CanonicalJson $expected)) { throw 'Desired endpoint config delta is not the exact authorized addition.' }

$tasks = @(Get-ScheduledTask -TaskName $taskName -ErrorAction Stop)
if ($tasks.Count -ne 1 -or [string]$tasks[0].Principal.UserId -ne 'SYSTEM') { throw 'Exact endpoint task identity or principal changed.' }
$actions = @($tasks[0].Actions)
if ($actions.Count -ne 1) { throw 'Exact endpoint task action count changed.' }
$actionText = ([string]$actions[0].Execute) + ' ' + ([string]$actions[0].Arguments)
if ($actionText.IndexOf($workerPath,[StringComparison]::OrdinalIgnoreCase) -lt 0 -or $actionText.IndexOf($configPath,[StringComparison]::OrdinalIgnoreCase) -lt 0 -or $actionText.IndexOf('-Once',[StringComparison]::OrdinalIgnoreCase) -lt 0) { throw 'Endpoint task is not the pinned one-shot config-reloading action.' }
$definition = [string](Export-ScheduledTask -TaskName $taskName -ErrorAction Stop)
$processorRows = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { [string]$_.Name -in @('powershell.exe','powershell_ise.exe') -and ([string]$_.CommandLine).IndexOf($processorScriptLeaf,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and ([string]$_.CommandLine).IndexOf($processorRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0 } | ForEach-Object { [ordered]@{processId=[int]$_.ProcessId;sessionId=[int]$_.SessionId;creationUtc=Convert-CreationUtc $_.CreationDate} })
$processorBefore = @($processorRows | Sort-Object processId)

$token = [Guid]::NewGuid().ToString('N')
$stage = Join-Path (Split-Path -Parent $configPath) ('.R21P3_'+$token+'.stage')
$backup = Join-Path (Split-Path -Parent $configPath) ('.R21P3_'+$token+'.backup')
$installed = $false
try {
    [IO.File]::Copy($desiredPath,$stage,$false)
    if ((Get-Sha256 $stage) -ne $expectedDesiredSha) { throw 'Staged config hash changed.' }
    [IO.File]::Replace($stage,$configPath,$backup)
    $installed = $true
    if ((Get-Sha256 $configPath) -ne $expectedDesiredSha) { throw 'Installed endpoint config hash changed.' }
    $processorAfter = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { [string]$_.Name -in @('powershell.exe','powershell_ise.exe') -and ([string]$_.CommandLine).IndexOf($processorScriptLeaf,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and ([string]$_.CommandLine).IndexOf($processorRoot,[StringComparison]::OrdinalIgnoreCase) -ge 0 } | ForEach-Object { [ordered]@{processId=[int]$_.ProcessId;sessionId=[int]$_.SessionId;creationUtc=Convert-CreationUtc $_.CreationDate} } | Sort-Object processId)
    if ((Get-CanonicalJson $processorAfter) -cne (Get-CanonicalJson $processorBefore)) { throw 'Processor process selector state changed during config-only install.' }
    [ordered]@{schema='argos_r21p3_read_capability_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R21P3_CONFIG_ONLY_READ_CAPABILITY_INSTALLED';endpointConfigBeforeSha256=$expectedConfigSha;endpointConfigAfterSha256=$expectedDesiredSha;endpointWorkerSha256=$expectedWorkerSha;endpointTask=[ordered]@{name=$taskName;principal=[string]$tasks[0].Principal.UserId;state=[string]$tasks[0].State;definitionSha256=Get-TextSha256 $definition;oneShotConfigReload=$true};processorProcessSelector=[ordered]@{unchanged=$true;rows=$processorBefore};approvedDataRootAdded='JBOD_R21_TARGETED_OUTPUT';statusHashFilesAdded=204;taskOrProcessActionPerformed=$false;detectorRerun=$false;sourceOrR21OutputBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 10 -Compress
    'PASS_R21P3_CONFIG_ONLY_READ_CAPABILITY_INSTALLED'
} catch {
    if ($installed -and (Test-Path -LiteralPath $backup -PathType Leaf)) { [IO.File]::Replace($backup,$configPath,$stage) }
    throw
} finally {
    foreach ($path in @($stage,$backup)) { if (Test-Path -LiteralPath $path -PathType Leaf) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } }
}
