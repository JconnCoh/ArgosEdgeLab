#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedComputer = 'A1025645101'
$outputRoot = 'D:\KLARFExport\R10P2'
$sourceBytes = [int64]475379874
$sources = @(
    [pscustomobject]@{
        identity = '62546-481_POST2_SLOT01'
        source = 'D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot01\BrightfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot01_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
        sha256 = 'D03C10550401B3AC2AFE42CC066E192DA9CC8D3FFC8F1E2497FA9C7C39CA5052'
        output = 'S01B.bmp'
    },
    [pscustomobject]@{
        identity = '62546-481_POST2_SLOT03'
        source = 'D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot03\BrightfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot03_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
        sha256 = '55B290A566FC243C81D1EB5E364D56DBB4DBC7A27AE81EA40E1CBF7CB6E570B3'
        output = 'S03B.bmp'
    },
    [pscustomobject]@{
        identity = '62546-481_POST2_SLOT17'
        source = 'D:\KLARFExport\PST_BRKFULLMETAL\Lot_Lot_62546-481_POST2\Lot_62546-481_POST2\Slot17\BrightfieldFrontsideWafer\resizedImage\Lot_62546-481_POST2_Slot17_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
        sha256 = '148040E21415909932DAE2C70F6F50DB025769F45238970743B421503AE86F94'
        output = 'S17B.bmp'
    }
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

Assert-True ($env:COMPUTERNAME.Equals($expectedComputer, [StringComparison]::OrdinalIgnoreCase)) "R10P2 wrong computer: $($env:COMPUTERNAME)"
Assert-True (-not (Test-Path -LiteralPath $outputRoot)) "R10P2 create-new output root exists: $outputRoot"
$planned = New-Object Collections.Generic.List[object]
foreach ($item in $sources) {
    Assert-True (Test-Path -LiteralPath $item.source -PathType Leaf) "R10P2 exact source is absent: $($item.identity)"
    Assert-True ((Get-Item -LiteralPath $item.source).Length -eq $sourceBytes) "R10P2 source byte count changed: $($item.identity)"
    Assert-True ((Get-Sha256 $item.source) -eq [string]$item.sha256) "R10P2 source SHA-256 changed: $($item.identity)"
    $partial = Join-Path $outputRoot ($item.output + '.partial')
    $destination = Join-Path $outputRoot $item.output
    foreach ($path in @($partial, $destination)) {
        Assert-True (($path.Length + 32) -lt 200) "R10P2 unsafe output path: $path"
        Assert-True (-not (Test-Path -LiteralPath $path)) "R10P2 create-new output exists: $path"
    }
    $planned.Add([ordered]@{identity=$item.identity;source=$item.source;sourceSha256=$item.sha256;sourceBytes=$sourceBytes;destination=$destination})
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{schema='argos_r10p2_post2_bf_stage_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10P2_POST2_BF_STAGE_PREFLIGHT';sourceCount=$sources.Count;sources=@($planned);processorProcessCount=$processorBefore.Count;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

[void](New-Item -ItemType Directory -Path $outputRoot)
$outputs = New-Object Collections.Generic.List[object]
foreach ($item in $sources) {
    $partial = Join-Path $outputRoot ($item.output + '.partial')
    $destination = Join-Path $outputRoot $item.output
    Copy-Item -LiteralPath $item.source -Destination $partial -ErrorAction Stop
    Assert-True ((Get-Item -LiteralPath $partial).Length -eq $sourceBytes) "R10P2 staged byte count changed: $($item.identity)"
    Assert-True ((Get-Sha256 $partial) -eq [string]$item.sha256) "R10P2 staged SHA-256 changed: $($item.identity)"
    Move-Item -LiteralPath $partial -Destination $destination -ErrorAction Stop
    $outputs.Add([ordered]@{identity=$item.identity;destination=$destination;destinationSha256=Get-Sha256 $destination;destinationBytes=(Get-Item -LiteralPath $destination).Length})
}
$processorAfter = @(Get-ProcessorRows)
Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'R10P2 protected processor identity changed.'
[ordered]@{schema='argos_r10p2_post2_bf_stage_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R10P2_POST2_BF_STAGED_CREATE_NEW';sourceCount=$sources.Count;outputs=@($outputs);processorProcessCount=$processorAfter.Count;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Compress -Depth 8
