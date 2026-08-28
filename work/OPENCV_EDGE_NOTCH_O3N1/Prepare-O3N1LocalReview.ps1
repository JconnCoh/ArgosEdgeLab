#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Prepare
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Prepare)) { throw 'Specify exactly one of -Preflight or -Prepare.' }

function Assert-True([bool]$Condition,[string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Write-JsonCreateNew([string]$Path,[object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 16) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}
function Read-BoundedZipJson([IO.Compression.ZipArchive]$Archive,[string]$Name,[int64]$MaximumBytes) {
    $entry = $Archive.GetEntry($Name)
    Assert-True ($null -ne $entry -and [int64]$entry.Length -le $MaximumBytes) "O3N1 local-review ZIP entry is absent or unbounded: $Name"
    $reader = New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8,$true)
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) }
    finally { $reader.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3N1_LOCAL_REVIEW_PREPARE_INVOCATION.json'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3N1 local-review invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3n1_local_review_prepare_invocation_v1' -and [string]$invocation.state -eq 'FROZEN_EXACT_LOCAL_REVIEW_PREPARE') 'O3N1 local-review invocation state changed.'
Assert-True ([string]$invocation.prepareScriptSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3N1 local-review invocation does not pin the exact preparer.'
Assert-True (-not [bool]$invocation.imagePixelsDecoded -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O3N1 local-review authority widened.'

$collectionGatePath = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.collectionGate).Replace('/','\')))
Assert-True (Test-Path -LiteralPath $collectionGatePath -PathType Leaf) 'O3N1 local-review collection gate is absent.'
Assert-True ((Get-Sha256 $collectionGatePath) -eq [string]$invocation.collectionGateSha256) 'O3N1 local-review collection gate changed.'
$collectionGate = Get-Content -LiteralPath $collectionGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$collectionGate.state -eq 'PASS_O3N1_MATCHING_SIGNED_DATA_PULL_RESPONSE_COLLECTED' -and [bool]$collectionGate.signatureVerified) 'O3N1 local-review signed response proof changed.'
$reviewZip = [IO.Path]::GetFullPath([string]$collectionGate.reviewZipPath)
Assert-True (Test-Path -LiteralPath $reviewZip -PathType Leaf) 'O3N1 local-review ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $reviewZip).Length -eq [int64]$invocation.reviewZipBytes -and (Get-Sha256 $reviewZip) -eq [string]$invocation.reviewZipSha256) 'O3N1 local-review ZIP identity changed.'

$reviewRoot = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.localReviewRoot).Replace('/','\')))
$reviewPartial = $reviewRoot + '.partial'
$assetsRoot = Join-Path $reviewRoot 'assets'
$assetsPartial = Join-Path $reviewPartial 'assets'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'O3N1 local-review path guard is absent.'
foreach ($target in @($reviewRoot,$reviewPartial)) {
    Assert-True (-not (Test-Path -LiteralPath $target)) "O3N1 local-review create-new root exists: $target"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($reviewZip)
try {
    $entries = @($archive.Entries)
    Assert-True ($entries.Count -eq 91) 'O3N1 local-review ZIP entry cardinality changed.'
    $names = @($entries | ForEach-Object { [string]$_.FullName })
    Assert-True ($names.Count -eq (@($names | Sort-Object -Unique).Count) -and $names -contains 'MANIFEST.json') 'O3N1 local-review ZIP entry uniqueness changed.'
    foreach ($name in $names) {
        Assert-True (-not [IO.Path]::IsPathRooted($name) -and $name -notmatch '(^|/|\\)\.\.(/|\\|$)') "O3N1 local-review ZIP entry path is unsafe: $name"
    }
    $renderManifest = Read-BoundedZipJson -Archive $archive -Name 'MANIFEST.json' -MaximumBytes 131072
}
finally { $archive.Dispose() }
Assert-True ([string]$renderManifest.schema -eq 'argos_ocv03_full_perimeter_topology_manifest_v1' -and [string]$renderManifest.revision -eq 'O3M7_SLOT16_SPLIT_METHOD_FULL_PERIMETER_R7_20260827' -and [string]$renderManifest.state -eq 'COMPLETE_REVIEW_ONLY_FULL_PERIMETER_TOPOLOGY') 'O3N1 local-review render manifest state changed.'
$results = @($renderManifest.results)
Assert-True ($results.Count -eq 1 -and [string]$results[0].pairId -eq '62629-419_SLOT16' -and [string]$results[0].state -eq 'HOLD_NO_BF_TOPOLOGY_DF_RADIAL_NOTCH') 'O3N1 local-review Slot16 hold changed.'
$slot16 = $results[0]
Assert-True ([int]$slot16.bf.candidateCount -eq 1 -and @($slot16.bf.candidates).Count -eq 1 -and [int]$slot16.df.candidateCount -eq 21 -and @($slot16.df.candidates).Count -eq 21) 'O3N1 local-review candidate cardinality changed.'
$assetRecords = New-Object 'Collections.Generic.List[object]'
[void]$assetRecords.Add($slot16.bf.overview)
[void]$assetRecords.Add($slot16.df.overview)
foreach ($channelName in @('bf','df')) {
    foreach ($candidate in @($slot16.$channelName.candidates)) {
        foreach ($role in @('clean','enhanced','overlay','mask')) {
            $record = $candidate.assets.$role
            Assert-True (-not [bool]$record.operatorFeedbackRasterized -and -not [bool]$record.inheritedReviewRasterUsed) "O3N1 local-review raster lineage changed: $($record.path)"
            [void]$assetRecords.Add($record)
        }
    }
}
Assert-True ($assetRecords.Count -eq 90) 'O3N1 local-review asset cardinality changed.'
$assetPaths = @($assetRecords | ForEach-Object { [string]$_.path })
Assert-True ($assetPaths.Count -eq @($assetPaths | Sort-Object -Unique).Count -and @(Compare-Object -ReferenceObject @($names | Where-Object { $_ -ne 'MANIFEST.json' } | Sort-Object) -DifferenceObject @($assetPaths | Sort-Object)).Count -eq 0) 'O3N1 local-review manifest/file asset set changed.'

$plannedLeaves = @($names | ForEach-Object { Join-Path $assetsRoot $_.Replace('/','\') })
$plannedLeaves += @(
    (Join-Path $reviewRoot 'gallery.html'),
    (Join-Path $reviewRoot 'RASTER_PROVENANCE_MANIFEST.json'),
    (Join-Path $reviewRoot 'RENDERED_RASTER_AUDIT.json'),
    (Join-Path $reviewRoot 'EXTRACTION_GATE.json')
)
$pathGate = & $pathTool -CandidatePath $plannedLeaves -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3N1 local-review path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)

if ($Preflight) {
    [ordered]@{
        schema='argos_o3n1_local_review_prepare_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3N1_LOCAL_REVIEW_PREPARE_PREFLIGHT';reviewZip=$reviewZip;reviewZipBytes=[int64]$invocation.reviewZipBytes
        reviewZipSha256=[string]$invocation.reviewZipSha256;entryCount=91;assetFileCount=90;candidateGroupCount=22
        maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;mutationsPerformed=$false
        imagePixelsDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[void][IO.Directory]::CreateDirectory($assetsPartial)
[IO.Compression.ZipFile]::ExtractToDirectory($reviewZip,$assetsPartial)
$extractedFiles = @(Get-ChildItem -LiteralPath $assetsPartial -File -ErrorAction Stop)
Assert-True ($extractedFiles.Count -eq 91) 'O3N1 local-review extracted file cardinality changed.'
foreach ($record in $assetRecords) {
    $asset = Join-Path $assetsPartial ([string]$record.path).Replace('/','\')
    Assert-True (Test-Path -LiteralPath $asset -PathType Leaf) "O3N1 local-review asset is absent: $($record.path)"
    Assert-True ((Get-Item -LiteralPath $asset).Length -eq [int64]$record.bytes -and (Get-Sha256 $asset) -eq [string]$record.sha256) "O3N1 local-review asset identity changed: $($record.path)"
}
Assert-True ((Get-Sha256 (Join-Path $assetsPartial 'MANIFEST.json')) -eq [string]$collectionGate.renderManifestSha256) 'O3N1 local-review extracted render manifest hash changed.'
$extractionGate = [ordered]@{
    schema='argos_o3n1_local_review_extraction_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3N1_LOCAL_REVIEW_EXACT_ASSETS_PREPARED'
    reviewZipPath=$reviewZip;reviewZipBytes=[int64]$invocation.reviewZipBytes;reviewZipSha256=[string]$invocation.reviewZipSha256
    renderManifestSha256=[string]$collectionGate.renderManifestSha256;assetRoot=(Join-Path $reviewRoot 'assets');entryCount=91;assetFileCount=90;candidateGroupCount=22
    allEntryHashesVerified=$true;allCleanBasesSeparate=$true;allCurrentMasksSeparate=$true;allCurrentOverlaysSeparate=$true
    changedPixelsOutsideCurrentMask='PENDING_OPENCV_RASTER_AUDIT';operatorFeedbackRasterized=$false;inheritedReviewRasterUsed=$false
    maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;imagePixelsDecoded=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path (Join-Path $reviewPartial 'EXTRACTION_GATE.json') -Value $extractionGate
[IO.Directory]::Move($reviewPartial,$reviewRoot)
$extractionGate | ConvertTo-Json -Depth 14
