[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Get-Sha256([string]$LiteralPath) {
    $stream = [IO.File]::OpenRead($LiteralPath)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

$project = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
$root = $PSScriptRoot
$manifestPath = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\scratch\SCRIBE_READER_V5_MERGED_REFERENCES_20260806T203000Z\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
$baseRoot = Join-Path $project 'work\STANDALONE_APP\packages\review_only\ARGOS_JBOD_ALL_WAFER_PROCESSOR_V2_20260806T145608Z\runtime\scribe\references\glyphs'
$v5Root = Join-Path $project 'work\STANDALONE_APP\packages\hotfixes\ARGOS_JBOD_V2_4_SCRIBE_READER_V5_HOTFIX_20260806T174804Z\payload\runtime\scribe\references\glyphs_v5_confirmed_20260806'
$zipPath = Join-Path $root 'O2D1_REFS.zip'
$partialPath = $zipPath + '.partial'
$gatePath = Join-Path $root 'O2D1_REFS_GATE.json'
$expectedManifestSha256 = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'

if ((Get-Sha256 $manifestPath) -ne $expectedManifestSha256) { throw 'O2D1 reference manifest changed.' }
$manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
if ([string]$manifest.schema -ne 'argos_portable_scribe_glyph_references_v1' -or @($manifest.references).Count -ne 456 -or [bool]$manifest.trainingEligible -or [bool]$manifest.productionEligible) { throw 'O2D1 reference manifest contract changed.' }
if ((Test-Path -LiteralPath $zipPath) -or (Test-Path -LiteralPath $partialPath) -or (Test-Path -LiteralPath $gatePath)) { throw 'O2D1 reference-bundle output already exists.' }

$entries = New-Object Collections.Generic.List[object]
$labels = New-Object Collections.Generic.HashSet[string]([StringComparer]::Ordinal)
foreach ($row in @($manifest.references)) {
    $relative = ([string]$row.relativePath).Replace('/', '\')
    $separatorIndex = $relative.IndexOf('\')
    if ($separatorIndex -le 0 -or $separatorIndex -ge ($relative.Length - 1)) { throw "O2D1 unsafe reference path: $relative" }
    $prefix = $relative.Substring(0, $separatorIndex)
    $tail = $relative.Substring($separatorIndex + 1)
    if ($prefix -notin @('glyphs','glyphs_v5_confirmed_20260806')) { throw "O2D1 unsafe reference prefix: $relative" }
    $sourceRoot = if ($prefix -eq 'glyphs') { $baseRoot } else { $v5Root }
    $source = Join-Path $sourceRoot $tail
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "O2D1 reference missing: $source" }
    $actual = Get-Sha256 $source
    if ($actual -ne ([string]$row.sha256).ToUpperInvariant()) { throw "O2D1 reference hash mismatch: $source" }
    [void]$labels.Add(([string]$row.label).ToUpperInvariant().Substring(0, 1))
    $entries.Add([pscustomobject]@{
        source = $source
        name = ('refs/' + $relative.Replace('\', '/'))
        bytes = [int64](Get-Item -LiteralPath $source).Length
        sha256 = $actual
    })
}
$manifestEntry = [pscustomobject]@{
    source = $manifestPath
    name = 'refs/PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    bytes = [int64](Get-Item -LiteralPath $manifestPath).Length
    sha256 = $expectedManifestSha256
}
$allEntries = @($manifestEntry) + @($entries.ToArray() | Sort-Object name)
$totalBytes = [int64](($allEntries | Measure-Object bytes -Sum).Sum)
$covered = (@($labels) | Sort-Object) -join ''
$expectedLabels = @([char[]]'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ' | ForEach-Object { [string]$_ })
$missing = (@($expectedLabels | Where-Object { -not $labels.Contains($_) })) -join ''

if ($Preflight) {
    [ordered]@{
        schema = 'argos_o2d1_reference_bundle_preflight_v1'
        state = 'PASS_O2D1_REFERENCE_BUNDLE_PREFLIGHT'
        manifestSha256 = $expectedManifestSha256
        referenceCount = $entries.Count
        archiveEntryCount = $allEntries.Count
        expandedBytes = $totalBytes
        coveredLabels = $covered
        missingLabels = $missing
        outputPath = $zipPath
        mutationsPerformed = $false
        reviewOnly = $true
        productionEligible = $false
    } | ConvertTo-Json -Depth 5
    return
}

Add-Type -AssemblyName System.IO.Compression
$file = [IO.File]::Open($partialPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
try {
    $archive = New-Object IO.Compression.ZipArchive($file, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($entryRow in $allEntries) {
            $entry = $archive.CreateEntry([string]$entryRow.name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::Parse('2026-08-24T00:00:00Z')
            $input = [IO.File]::OpenRead([string]$entryRow.source)
            $output = $entry.Open()
            try { $input.CopyTo($output) }
            finally { $output.Dispose(); $input.Dispose() }
        }
    } finally { $archive.Dispose() }
} finally { $file.Dispose() }
Move-Item -LiteralPath $partialPath -Destination $zipPath

$read = [IO.File]::OpenRead($zipPath)
try {
    $archive = New-Object IO.Compression.ZipArchive($read, [IO.Compression.ZipArchiveMode]::Read, $true)
    try {
        if ($archive.Entries.Count -ne $allEntries.Count) { throw 'O2D1 reference ZIP entry count changed.' }
        foreach ($entryRow in $allEntries) {
            $entry = $archive.GetEntry([string]$entryRow.name)
            if ($null -eq $entry -or [int64]$entry.Length -ne [int64]$entryRow.bytes) { throw "O2D1 reference ZIP entry changed: $($entryRow.name)" }
            $sha = [Security.Cryptography.SHA256]::Create()
            $stream = $entry.Open()
            try { $actual = ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
            finally { $stream.Dispose(); $sha.Dispose() }
            if ($actual -ne [string]$entryRow.sha256) { throw "O2D1 reference ZIP hash mismatch: $($entryRow.name)" }
        }
    } finally { $archive.Dispose() }
} finally { $read.Dispose() }

$gate = [ordered]@{
    schema = 'argos_o2d1_reference_bundle_gate_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2D1_REFERENCE_BUNDLE_GATE'
    bundlePath = 'work/OPENCV_SCRIBE_O2D1/O2D1_REFS.zip'
    bundleBytes = [int64](Get-Item -LiteralPath $zipPath).Length
    bundleSha256 = Get-Sha256 $zipPath
    manifestSha256 = $expectedManifestSha256
    referenceCount = $entries.Count
    archiveEntryCount = $allEntries.Count
    expandedBytes = $totalBytes
    coveredLabels = $covered
    missingLabels = $missing
    exactEntryReadbackPassed = $true
    imagePixelsDecoded = $false
    trainingEligible = $false
    productionEligible = $false
}
[IO.File]::WriteAllText($gatePath, (($gate | ConvertTo-Json -Depth 6) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
$gate | ConvertTo-Json -Depth 6
