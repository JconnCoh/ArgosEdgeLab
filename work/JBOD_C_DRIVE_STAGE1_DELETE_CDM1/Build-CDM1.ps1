[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PackageRoot,
    [Parameter(Mandatory = $true)][string]$OutputZip,
    [Parameter(Mandatory = $true)][string]$ExtractionRoot,
    [Parameter(Mandatory = $true)][string]$BuildGate,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-Utf8CreateNewJson {
    param([string]$Path, [object]$Value, [int]$Depth = 16)
    $json = $Value | ConvertTo-Json -Depth $Depth
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}

$resolvedProject = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$resolvedPackage = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PackageRoot).Path).TrimEnd('\')
$resolvedZip = [IO.Path]::GetFullPath($OutputZip)
$resolvedExtraction = [IO.Path]::GetFullPath($ExtractionRoot).TrimEnd('\')
$resolvedGate = [IO.Path]::GetFullPath($BuildGate)
foreach ($planned in @($resolvedZip,$resolvedExtraction,$resolvedGate)) {
    Assert-True ($planned.StartsWith($resolvedProject+'\',[StringComparison]::OrdinalIgnoreCase)) "CDM1 build path left the project: $planned"
    Assert-True (-not (Test-Path -LiteralPath $planned)) "CDM1 build path must be fresh: $planned"
}

$manifestPath = Join-Path $resolvedPackage 'PACKAGE_MANIFEST.json'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'CDM1 frozen package manifest is absent.'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$manifest.schema -eq 'argos_cdm1_package_manifest_v1' -and [string]$manifest.revision -eq 'CDM1' -and [string]$manifest.lifecycle -eq 'FROZEN') 'CDM1 package is not the frozen revision.'
$expectedFiles = @('DELETE_CDM1.ps1','INVOCATION.json','PACKAGE_MANIFEST.json','README_FIRST.txt','RUN_CDM1.cmd')
$actualFiles = @((New-Object IO.DirectoryInfo($resolvedPackage)).EnumerateFiles() | ForEach-Object { $_.Name } | Sort-Object)
Assert-True (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $actualFiles).Count -eq 0) 'CDM1 package root has a missing or extra file.'
Assert-True (@((New-Object IO.DirectoryInfo($resolvedPackage)).EnumerateDirectories()).Count -eq 0) 'CDM1 package root has an unexpected directory.'
foreach ($entry in @($manifest.files)) {
    $source = Join-Path $resolvedPackage ([string]$entry.path)
    Assert-True (Test-Path -LiteralPath $source -PathType Leaf) "CDM1 package entry is absent: $($entry.path)"
    Assert-True ((Get-Item -LiteralPath $source).Length -eq [int64]$entry.bytes -and (Get-Sha256 $source) -eq [string]$entry.sha256) "CDM1 package entry changed: $($entry.path)"
}
$tokens=$null;$parserErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $resolvedPackage 'DELETE_CDM1.ps1'),[ref]$tokens,[ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'CDM1 frozen target parser failed.'

$preflightResult = [ordered]@{
    schema='argos_cdm1_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_BUILD_PREFLIGHT'
    packageRoot=$resolvedPackage;packageManifestSha256=Get-Sha256 $manifestPath;outputZip=$resolvedZip;extractionRoot=$resolvedExtraction;buildGate=$resolvedGate
    expectedFiles=$expectedFiles;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 10; return }
Assert-True ([bool]$Build) 'Specify -Preflight or -Build.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($resolvedPackage,$resolvedZip,[IO.Compression.CompressionLevel]::Optimal,$false)
[void](New-Item -ItemType Directory -Path $resolvedExtraction)
[IO.Compression.ZipFile]::ExtractToDirectory($resolvedZip,$resolvedExtraction)

$extractedFiles = @((New-Object IO.DirectoryInfo($resolvedExtraction)).EnumerateFiles() | ForEach-Object { $_.Name } | Sort-Object)
Assert-True (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $extractedFiles).Count -eq 0) 'CDM1 extracted package has a missing or extra file.'
Assert-True (@((New-Object IO.DirectoryInfo($resolvedExtraction)).EnumerateDirectories()).Count -eq 0) 'CDM1 extracted package has an unexpected directory.'
$fileRows = New-Object 'Collections.Generic.List[object]'
foreach ($name in $expectedFiles) {
    $source = Join-Path $resolvedPackage $name
    $extracted = Join-Path $resolvedExtraction $name
    $sourceHash = Get-Sha256 $source
    $extractedHash = Get-Sha256 $extracted
    Assert-True ((Get-Item -LiteralPath $source).Length -eq (Get-Item -LiteralPath $extracted).Length -and $sourceHash -eq $extractedHash) "CDM1 extracted file changed: $name"
    $fileRows.Add([pscustomobject]@{path=$name;bytes=(Get-Item -LiteralPath $source).Length;sha256=$sourceHash})
}
$archive = [IO.Compression.ZipFile]::OpenRead($resolvedZip)
try {
    $entryNames = @($archive.Entries | ForEach-Object { $_.FullName.Replace('/','\') } | Sort-Object)
    Assert-True (@(Compare-Object -ReferenceObject $expectedFiles -DifferenceObject $entryNames).Count -eq 0) 'CDM1 ZIP entry set changed.'
} finally { $archive.Dispose() }

$gateResult = [ordered]@{
    schema='argos_cdm1_build_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_EXACT_PACKAGE_BUILD'
    packageManifestSha256=Get-Sha256 $manifestPath;zipPath=$resolvedZip;zipBytes=(Get-Item -LiteralPath $resolvedZip).Length;zipSha256=Get-Sha256 $resolvedZip
    extractionRoot=$resolvedExtraction;zipEntryCount=$expectedFiles.Count;zipEntries=$expectedFiles;fileRows=$fileRows.ToArray();exactExtractionVerified=$true
    targetExecuted=$false;taskActionsPerformed=@();processActionsPerformed=@();waferActionPerformed=$false;imageBytesDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-Utf8CreateNewJson -Path $resolvedGate -Value $gateResult -Depth 14
$gateResult | ConvertTo-Json -Depth 14
