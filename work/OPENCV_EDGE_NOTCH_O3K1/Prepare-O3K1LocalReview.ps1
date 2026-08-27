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
    Assert-True ($null -ne $entry -and [int64]$entry.Length -le $MaximumBytes) "O3K1 local-review ZIP entry is absent or unbounded: $Name"
    $reader = New-Object IO.StreamReader($entry.Open(),[Text.Encoding]::UTF8,$true)
    try { return ($reader.ReadToEnd() | ConvertFrom-Json) }
    finally { $reader.Dispose() }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$expectedInvocationPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'O3K1_LOCAL_REVIEW_PREPARE_INVOCATION.json'))
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($invocationPath.Equals($expectedInvocationPath,[StringComparison]::OrdinalIgnoreCase)) 'O3K1 local-review invocation path changed.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o3k1_local_review_prepare_invocation_v1' -and [string]$invocation.state -eq 'FROZEN_EXACT_LOCAL_REVIEW_PREPARE') 'O3K1 local-review invocation state changed.'
Assert-True ([string]$invocation.prepareScriptSha256 -eq (Get-Sha256 $PSCommandPath)) 'O3K1 local-review invocation does not pin the exact preparer.'
Assert-True (-not [bool]$invocation.imagePixelsDecoded -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O3K1 local-review authority widened.'

$collectionGatePath = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.collectionGate).Replace('/','\')))
Assert-True (Test-Path -LiteralPath $collectionGatePath -PathType Leaf) 'O3K1 local-review collection gate is absent.'
Assert-True ((Get-Sha256 $collectionGatePath) -eq [string]$invocation.collectionGateSha256) 'O3K1 local-review collection gate changed.'
$collectionGate = Get-Content -LiteralPath $collectionGatePath -Raw | ConvertFrom-Json
Assert-True ([string]$collectionGate.state -eq 'PASS_O3K1_MATCHING_SIGNED_DATA_PULL_RESPONSE_COLLECTED' -and [bool]$collectionGate.signatureVerified) 'O3K1 local-review signed response proof changed.'
$reviewZip = [IO.Path]::GetFullPath([string]$collectionGate.reviewZipPath)
Assert-True (Test-Path -LiteralPath $reviewZip -PathType Leaf) 'O3K1 local-review ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $reviewZip).Length -eq [int64]$invocation.reviewZipBytes -and (Get-Sha256 $reviewZip) -eq [string]$invocation.reviewZipSha256) 'O3K1 local-review ZIP identity changed.'

$reviewRoot = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.localReviewRoot).Replace('/','\')))
$reviewPartial = $reviewRoot + '.partial'
$assetsRoot = Join-Path $reviewRoot 'assets'
$assetsPartial = Join-Path $reviewPartial 'assets'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
Assert-True (Test-Path -LiteralPath $pathTool -PathType Leaf) 'O3K1 local-review path guard is absent.'
foreach ($target in @($reviewRoot,$reviewPartial)) {
    Assert-True (-not (Test-Path -LiteralPath $target)) "O3K1 local-review create-new root exists: $target"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($reviewZip)
try {
    $entries = @($archive.Entries)
    Assert-True ($entries.Count -eq 19) 'O3K1 local-review ZIP entry cardinality changed.'
    $names = @($entries | ForEach-Object { [string]$_.FullName })
    Assert-True ($names.Count -eq (@($names | Sort-Object -Unique).Count) -and $names -contains 'RENDER_MANIFEST.json') 'O3K1 local-review ZIP entry uniqueness changed.'
    foreach ($name in $names) {
        Assert-True (-not [IO.Path]::IsPathRooted($name) -and $name -notmatch '(^|/|\\)\.\.(/|\\|$)') "O3K1 local-review ZIP entry path is unsafe: $name"
    }
    $renderManifest = Read-BoundedZipJson -Archive $archive -Name 'RENDER_MANIFEST.json' -MaximumBytes 65536
}
finally { $archive.Dispose() }
Assert-True ([string]$renderManifest.schema -eq 'argos_ocv03_notch_review_render_v1' -and [string]$renderManifest.revision -eq 'FMOCV03_O3K1_20260827T200000Z' -and [string]$renderManifest.state -eq 'PASS_O3K1_NOTCH_REVIEW_RENDERED') 'O3K1 local-review render manifest state changed.'
$groups = @($renderManifest.assetGroups)
Assert-True ($groups.Count -eq 6 -and [int]$renderManifest.assetFileCount -eq 18) 'O3K1 local-review asset cardinality changed.'

$plannedLeaves = @($names | ForEach-Object { Join-Path $assetsRoot $_.Replace('/','\') })
$plannedLeaves += @(
    (Join-Path $reviewRoot 'gallery.html'),
    (Join-Path $reviewRoot 'RASTER_PROVENANCE_MANIFEST.json'),
    (Join-Path $reviewRoot 'RENDERED_RASTER_AUDIT.json'),
    (Join-Path $reviewRoot 'EXTRACTION_GATE.json')
)
$pathGate = & $pathTool -CandidatePath $plannedLeaves -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$pathGate.state -eq 'PASS_PATH_BUDGET') 'O3K1 local-review path budget failed.'
$maximumEffective = [int](($pathGate.candidates | Measure-Object effectiveLength -Maximum).Maximum)
$maximumComponent = [int](($pathGate.candidates | Measure-Object longestComponentLength -Maximum).Maximum)

if ($Preflight) {
    [ordered]@{
        schema='argos_o3k1_local_review_prepare_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3K1_LOCAL_REVIEW_PREPARE_PREFLIGHT';reviewZip=$reviewZip;reviewZipBytes=[int64]$invocation.reviewZipBytes
        reviewZipSha256=[string]$invocation.reviewZipSha256;entryCount=19;assetFileCount=18;assetGroupCount=6
        maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;mutationsPerformed=$false
        imagePixelsDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

[void][IO.Directory]::CreateDirectory($assetsPartial)
[IO.Compression.ZipFile]::ExtractToDirectory($reviewZip,$assetsPartial)
$extractedFiles = @(Get-ChildItem -LiteralPath $assetsPartial -File -ErrorAction Stop)
Assert-True ($extractedFiles.Count -eq 19) 'O3K1 local-review extracted file cardinality changed.'
foreach ($group in $groups) {
    foreach ($role in @('clean','currentMask','currentOverlay')) {
        $record = $group.$role
        $asset = Join-Path $assetsPartial ([string]$record.path).Replace('/','\')
        Assert-True (Test-Path -LiteralPath $asset -PathType Leaf) "O3K1 local-review asset is absent: $($record.path)"
        Assert-True ((Get-Item -LiteralPath $asset).Length -eq [int64]$record.bytes -and (Get-Sha256 $asset) -eq [string]$record.sha256) "O3K1 local-review asset identity changed: $($record.path)"
    }
    Assert-True ([int64]$group.changedPixelsOutsideCurrentMask -eq 0 -and [int64]$group.changedPixelsInsideCurrentMask -gt 0 -and -not [bool]$group.operatorFeedbackRasterized -and -not [bool]$group.inheritedReviewRasterUsed) "O3K1 local-review raster semantics changed: $($group.candidateId)/$($group.channel)"
}
Assert-True ((Get-Sha256 (Join-Path $assetsPartial 'RENDER_MANIFEST.json')) -eq [string]$collectionGate.renderManifestSha256) 'O3K1 local-review extracted render manifest hash changed.'
$extractionGate = [ordered]@{
    schema='argos_o3k1_local_review_extraction_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O3K1_LOCAL_REVIEW_EXACT_ASSETS_PREPARED'
    reviewZipPath=$reviewZip;reviewZipBytes=[int64]$invocation.reviewZipBytes;reviewZipSha256=[string]$invocation.reviewZipSha256
    renderManifestSha256=[string]$collectionGate.renderManifestSha256;assetRoot=(Join-Path $reviewRoot 'assets');entryCount=19;assetFileCount=18;assetGroupCount=6
    allEntryHashesVerified=$true;allCleanBasesSeparate=$true;allCurrentMasksSeparate=$true;allCurrentOverlaysSeparate=$true
    changedPixelsOutsideCurrentMask=0;operatorFeedbackRasterized=$false;inheritedReviewRasterUsed=$false
    maximumEffectiveLength=$maximumEffective;maximumComponentLength=$maximumComponent;imagePixelsDecoded=$false
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
}
Write-JsonCreateNew -Path (Join-Path $reviewPartial 'EXTRACTION_GATE.json') -Value $extractionGate
[IO.Directory]::Move($reviewPartial,$reviewRoot)
$extractionGate | ConvertTo-Json -Depth 14
