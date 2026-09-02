#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedComputer = 'A1025645101'
$outputRoot = 'D:\KLARFExport\R10P2C'
$sourceBytes = [int64]475379874
$sources = @(
    [pscustomobject]@{identity='62546-481_POST2_SLOT01';channel='BF';source='D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot01\BrightfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';sha256='D03C10550401B3AC2AFE42CC066E192DA9CC8D3FFC8F1E2497FA9C7C39CA5052';output='S01B.bmp'},
    [pscustomobject]@{identity='62546-481_POST2_SLOT01';channel='DF';source='D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot01\DarkfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot01_DarkfieldFrontsideWafer_PM2_resizedImage.bmp';sha256='C1759B44CE9D7ACA18D87413D10936578A67D35C018A0D646A78C45AFE5AA536';output='S01D.bmp'},
    [pscustomobject]@{identity='62546-481_POST2_SLOT03';channel='BF';source='D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot03\BrightfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot03_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';sha256='55B290A566FC243C81D1EB5E364D56DBB4DBC7A27AE81EA40E1CBF7CB6E570B3';output='S03B.bmp'},
    [pscustomobject]@{identity='62546-481_POST2_SLOT03';channel='DF';source='D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot03\DarkfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot03_DarkfieldFrontsideWafer_PM2_resizedImage.bmp';sha256='2EF13BB346E381217F6D8DA4C732C5B97C8EABCD062CBE73FD02BD5DD064DFD5';output='S03D.bmp'},
    [pscustomobject]@{identity='62546-481_POST2_SLOT17';channel='BF';source='D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot17\BrightfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot17_BrightfieldFrontsideWafer_PM2_resizedImage.bmp';sha256='148040E21415909932DAE2C70F6F50DB025769F45238970743B421503AE86F94';output='S17B.bmp'},
    [pscustomobject]@{identity='62546-481_POST2_SLOT17';channel='DF';source='D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot17\DarkfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot17_DarkfieldFrontsideWafer_PM2_resizedImage.bmp';sha256='9AB0AA6942948F54635C51B173618FC8478C75791E9F859FDD135FFDE52C153C';output='S17D.bmp'}
)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Get-ProcessorRows {
    return @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" -ErrorAction Stop |
        Where-Object { [string]$_.CommandLine -like '*Invoke-AllWaferProcessorV2.ps1*' } |
        Sort-Object ProcessId |
        ForEach-Object { [pscustomobject]@{processId=[uint32]$_.ProcessId;creationDate=[string]$_.CreationDate;commandLine=[string]$_.CommandLine} })
}

Assert-True ($env:COMPUTERNAME.Equals($expectedComputer, [StringComparison]::OrdinalIgnoreCase)) "R10P2C wrong computer: $($env:COMPUTERNAME)"
Assert-True (-not (Test-Path -LiteralPath $outputRoot)) "R10P2C create-new output root exists: $outputRoot"
[object[]]$planned = @()
foreach ($item in $sources) {
    Assert-True (Test-Path -LiteralPath $item.source -PathType Leaf) "R10P2C exact source is absent: $($item.identity) $($item.channel)"
    Assert-True ((Get-Item -LiteralPath $item.source).Length -eq $sourceBytes) "R10P2C source byte count changed: $($item.identity) $($item.channel)"
    Assert-True ((Get-Sha256 $item.source) -eq [string]$item.sha256) "R10P2C source SHA-256 changed: $($item.identity) $($item.channel)"
    $partial = Join-Path $outputRoot ($item.output + '.partial')
    $destination = Join-Path $outputRoot $item.output
    foreach ($path in @($partial, $destination)) {
        Assert-True (($path.Length + 32) -lt 200) "R10P2C unsafe output path: $path"
        Assert-True (-not (Test-Path -LiteralPath $path)) "R10P2C create-new output exists: $path"
    }
    $planned += [pscustomobject][ordered]@{identity=$item.identity;channel=$item.channel;source=$item.source;sourceSha256=$item.sha256;sourceBytes=$sourceBytes;destination=$destination}
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{schema='argos_r10p2b_post2_pair_stage_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10P2C_POST2_PAIR_STAGE_PREFLIGHT';sourceCount=$sources.Count;sources=$planned;processorProcessCount=$processorBefore.Count;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $outputRoot)
[object[]]$outputs = @()
foreach ($item in $sources) {
    $partial = Join-Path $outputRoot ($item.output + '.partial')
    $destination = Join-Path $outputRoot $item.output
    Copy-Item -LiteralPath $item.source -Destination $partial -ErrorAction Stop
    Assert-True ((Get-Item -LiteralPath $partial).Length -eq $sourceBytes) "R10P2C staged byte count changed: $($item.identity) $($item.channel)"
    Assert-True ((Get-Sha256 $partial) -eq [string]$item.sha256) "R10P2C staged SHA-256 changed: $($item.identity) $($item.channel)"
    Move-Item -LiteralPath $partial -Destination $destination -ErrorAction Stop
    $outputs += [pscustomobject][ordered]@{identity=$item.identity;channel=$item.channel;destination=$destination;destinationSha256=Get-Sha256 $destination;destinationBytes=(Get-Item -LiteralPath $destination).Length}
}
$processorAfter = @(Get-ProcessorRows)
Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'R10P2C protected processor identity changed.'
[ordered]@{schema='argos_r10p2b_post2_pair_stage_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10P2C_POST2_PAIRS_STAGED_CREATE_NEW';sourceCount=$sources.Count;outputs=$outputs;processorProcessCount=$processorAfter.Count;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Compress -Depth 8
