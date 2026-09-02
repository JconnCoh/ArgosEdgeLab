#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expectedComputer = 'A1025645101'
$source = 'D:\KLARFExport\PatternedFront\Lot_62619-433\62619-433_20260824005735\Slot22\BrightfieldFrontsideWafer\resizedImage\62619-433_Slot22_BrightfieldFrontsideWafer_PM2_resizedImage.bmp'
$sourceSha = '5B7ADC1B1A52BE73A3C32D6663E92FC467C640D5502AA77A8309A059C444CDF5'
$sourceBytes = [int64]475379874
$outputRoot = 'D:\KLARFExport\R8E1'
$partial = Join-Path $outputRoot 'S22U.partial.bmp'
$destination = Join-Path $outputRoot 'S22U.bmp'

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

Assert-True ($env:COMPUTERNAME.Equals($expectedComputer, [StringComparison]::OrdinalIgnoreCase)) "R8E1 wrong computer: $($env:COMPUTERNAME)"
Assert-True (Test-Path -LiteralPath $source -PathType Leaf) 'R8E1 exact source is absent.'
Assert-True ((Get-Item -LiteralPath $source).Length -eq $sourceBytes) 'R8E1 source byte count changed.'
Assert-True ((Get-Sha256 $source) -eq $sourceSha) 'R8E1 source SHA-256 changed.'
foreach ($path in @($outputRoot,$partial,$destination)) {
    Assert-True (($path.Length + 32) -lt 200) "R8E1 unsafe path: $path"
    Assert-True (-not (Test-Path -LiteralPath $path)) "R8E1 create-new target exists: $path"
}
$processorBefore = @(Get-ProcessorRows)
if ($Preflight) {
    [ordered]@{schema='argos_r8e1_slot22_bf_stage_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R8E1_SLOT22_BF_STAGE_PREFLIGHT';source=$source;sourceSha256=$sourceSha;sourceBytes=$sourceBytes;destination=$destination;processorProcessCount=$processorBefore.Count;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

[void](New-Item -ItemType Directory -Path $outputRoot)
Copy-Item -LiteralPath $source -Destination $partial -ErrorAction Stop
Assert-True ((Get-Item -LiteralPath $partial).Length -eq $sourceBytes) 'R8E1 staged byte count changed.'
Assert-True ((Get-Sha256 $partial) -eq $sourceSha) 'R8E1 staged SHA-256 changed.'
Move-Item -LiteralPath $partial -Destination $destination -ErrorAction Stop
$processorAfter = @(Get-ProcessorRows)
Assert-True ((($processorBefore | ConvertTo-Json -Compress) -eq ($processorAfter | ConvertTo-Json -Compress))) 'R8E1 protected processor identity changed.'
[ordered]@{schema='argos_r8e1_slot22_bf_stage_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R8E1_SLOT22_BF_STAGED_CREATE_NEW';source=$source;sourceSha256=$sourceSha;sourceBytes=$sourceBytes;destination=$destination;destinationSha256=Get-Sha256 $destination;destinationBytes=(Get-Item -LiteralPath $destination).Length;processorProcessCount=$processorAfter.Count;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Compress -Depth 6
