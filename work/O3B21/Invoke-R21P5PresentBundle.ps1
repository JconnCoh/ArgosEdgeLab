#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = 'D:\R21TG1'
$manifestPath = Join-Path $PSScriptRoot 'M.json'
$configPath = 'C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json'
$workerPath = 'C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
$expectedManifestSha = '9518C6847553B5D876A1B8977E92C96D804E9C6BC7C24A7DF334F0D8E0118CB7'
$expectedConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$expectedWorkerSha = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Get-BytesSha256([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

if ((Get-Sha256 $manifestPath) -ne $expectedManifestSha) { throw 'R21P5 present manifest hash changed.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([string]$manifest.schema -ne 'argos_r21p5_present_manifest_v1' -or [int]$manifest.fileCount -ne 114 -or @($manifest.files).Count -ne 114) { throw 'R21P5 present manifest identity changed.' }
if ($Preflight) {
    [ordered]@{schema='argos_r21p5_present_bundle_preflight_v1';state='PASS_R21P5_PRESENT_BUNDLE_PREFLIGHT';fileCount=114;sourceBytes=[int64]$manifest.totalBytes;diskStagingUsed=$false;mutationsPerformed=$false} | ConvertTo-Json -Depth 5
    return
}
if ($env:COMPUTERNAME -ne 'A1025645101') { throw "Wrong computer: $($env:COMPUTERNAME)" }
if ((Get-Sha256 $configPath) -ne $expectedConfigSha -or (Get-Sha256 $workerPath) -ne $expectedWorkerSha) { throw 'R21P5 route premise changed.' }
Add-Type -AssemblyName System.IO.Compression
$memory = New-Object IO.MemoryStream
$archive = New-Object IO.Compression.ZipArchive($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
try {
    foreach ($record in @($manifest.files)) {
        $relative = ([string]$record.relativePath).Replace('/','\')
        $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $full.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $full -PathType Leaf)) { throw "R21P5 source path failed: $relative" }
        $item = Get-Item -LiteralPath $full -ErrorAction Stop
        if ([int64]$item.Length -ne [int64]$record.bytes -or (Get-Sha256 $full) -ne [string]$record.sha256) { throw "R21P5 source changed: $relative" }
        $entry = $archive.CreateEntry(([string]$record.relativePath),[IO.Compression.CompressionLevel]::Optimal)
        $source = [IO.File]::OpenRead($full)
        $target = $entry.Open()
        try { $source.CopyTo($target) } finally { $target.Dispose(); $source.Dispose() }
    }
} finally { $archive.Dispose() }
$zipBytes = $memory.ToArray()
$memory.Dispose()
$result = [ordered]@{schema='argos_r21p5_present_bundle_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R21P5_PRESENT_BUNDLE';sourceManifestSha256=$expectedManifestSha;fileCount=114;sourceBytes=[int64]$manifest.totalBytes;containerBytes=$zipBytes.Length;containerSha256=Get-BytesSha256 $zipBytes;containerBase64=[Convert]::ToBase64String($zipBytes);diskStagingUsed=$false;taskOrProcessActionPerformed=$false;detectorRerun=$false;sourceMutationPerformed=$false;r21OutputMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$result | ConvertTo-Json -Depth 6 -Compress
'PASS_R21P5_PRESENT_BUNDLE'
