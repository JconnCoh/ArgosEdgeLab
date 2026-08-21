[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$ManifestPath,
    [string]$ProjectRoot,
    [switch]$Preflight,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Need-Scalar([object]$Value, [string]$Label) {
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "Missing scalar: $Label"
    }
    return $text
}

function Read-BoundedJson([string]$Path, [string]$Label) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -gt 1048576) {
        throw "$Label exceeds 1 MiB: $Path"
    }
    return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json)
}

function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToUpperInvariant()
}

if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $scriptPath = Need-Scalar $MyInvocation.MyCommand.Path 'script path'
    $ProjectRoot = Split-Path -Parent (Split-Path -Parent $scriptPath)
}

$root = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$rootPrefix = $root + '\'

function Resolve-ProjectPath([string]$Value, [string]$Label) {
    $text = Need-Scalar $Value $Label
    if ([IO.Path]::IsPathRooted($text)) {
        $full = [IO.Path]::GetFullPath($text)
    } else {
        $full = [IO.Path]::GetFullPath((Join-Path $root $text))
    }
    if ($full -ne $root -and -not $full.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label escapes the project root: $full"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        throw "$Label is missing: $full"
    }
    return $full
}

$manifestFull = Resolve-ProjectPath $ManifestPath 'manifest'
$manifest = Read-BoundedJson $manifestFull 'raster provenance manifest'
if ([string]$manifest.schema -ne 'argos_raster_provenance_manifest_v1') {
    throw "Unexpected raster provenance schema: $($manifest.schema)"
}

$revisionId = Need-Scalar $manifest.revisionId 'revisionId'
if ($revisionId -notmatch '^FM[0-9A-Z_]+_[0-9]{8}T[0-9]{4,6}Z$') {
    throw "Invalid revisionId: $revisionId"
}

$entries = @($manifest.entries)
if ($entries.Count -lt 2) {
    throw 'Raster provenance manifest must contain at least two entries.'
}

$ids = @{}
$cleanCount = 0
$heatmapCount = 0
$verifiedMasks = 0

foreach ($entry in $entries) {
    $id = Need-Scalar $entry.id 'entry.id'
    if ($ids.ContainsKey($id)) {
        throw "Duplicate raster entry id: $id"
    }
    $ids[$id] = $true

    $role = Need-Scalar $entry.role "$id.role"
    if ($role -notin @('CLEAN_BASE', 'CURRENT_HEATMAP')) {
        throw "Unsupported raster role for $id`: $role"
    }

    $file = Resolve-ProjectPath $entry.path "$id.path"
    $expectedHash = (Need-Scalar $entry.sha256 "$id.sha256").ToUpperInvariant()
    $actualHash = Get-Sha256 $file
    if ($actualHash -ne $expectedHash) {
        throw "Raster hash mismatch for $id. Expected $expectedHash actual $actualHash"
    }

    if ($role -eq 'CLEAN_BASE') {
        $cleanCount++
        $source = Resolve-ProjectPath $entry.cleanSourcePath "$id.cleanSourcePath"
        $sourceExpected = (Need-Scalar $entry.cleanSourceSha256 "$id.cleanSourceSha256").ToUpperInvariant()
        $sourceActual = Get-Sha256 $source
        if ($sourceActual -ne $sourceExpected) {
            throw "Clean-source hash mismatch for $id."
        }
        if ($actualHash -ne $sourceActual) {
            throw "Baked raster contamination detected in CLEAN_BASE $id."
        }
        if ([bool]$entry.operatorFeedbackRasterized -or [bool]$entry.inheritedReviewRasterUsed) {
            throw "Clean base $id declares feedback or inherited raster content."
        }
        continue
    }

    $heatmapCount++
    if ([string]$entry.sourceRevisionId -ne $revisionId) {
        throw "Heatmap $id is not attributed to current revision $revisionId."
    }
    if ([bool]$entry.operatorFeedbackRasterized) {
        throw "Heatmap $id rasterizes operator feedback."
    }
    if ([bool]$entry.inheritedReviewRasterUsed) {
        throw "Heatmap $id uses an inherited review raster."
    }
    if ([int64]$entry.changedPixelsOutsideCurrentMask -ne 0) {
        throw "Heatmap $id changes pixels outside its current mask."
    }
    if ([int64]$entry.changedPixelsInsideCurrentMask -le 0) {
        throw "Heatmap $id has no visible current-mask pixels."
    }

    $maskRows = @($entry.currentMaskLineage)
    if ($maskRows.Count -lt 1) {
        throw "Heatmap $id has no current mask lineage."
    }
    foreach ($mask in $maskRows) {
        $maskPath = Resolve-ProjectPath $mask.path "$id.currentMaskLineage.path"
        $maskExpected = (Need-Scalar $mask.sha256 "$id.currentMaskLineage.sha256").ToUpperInvariant()
        if ((Get-Sha256 $maskPath) -ne $maskExpected) {
            throw "Current mask hash mismatch for heatmap $id."
        }
        $verifiedMasks++
    }
}

if ($cleanCount -lt 1 -or $heatmapCount -lt 1) {
    throw 'Raster provenance manifest requires CLEAN_BASE and CURRENT_HEATMAP entries.'
}

$renderedAuditVerified = $false
if (-not $Preflight) {
    $auditPath = Resolve-ProjectPath $manifest.renderedAudit.path 'renderedAudit.path'
    $auditExpected = (Need-Scalar $manifest.renderedAudit.sha256 'renderedAudit.sha256').ToUpperInvariant()
    if ((Get-Sha256 $auditPath) -ne $auditExpected) {
        throw 'Rendered audit hash mismatch.'
    }
    $audit = Read-BoundedJson $auditPath 'rendered audit'
    if ([string]$audit.state -ne 'PASS_RENDERED_RASTER_PROVENANCE' -or
        [string]$audit.revisionId -ne $revisionId -or
        -not [bool]$audit.exactRevisionLoaded -or
        -not [bool]$audit.importedFeedbackHiddenByDefault -or
        -not [bool]$audit.fullWaferCurrentHeatmapsVisible -or
        -not [bool]$audit.heatmapTogglesIsolated -or
        -not [bool]$audit.feedbackToggleIsolated -or
        -not [bool]$audit.cleanBaseUnchangedWhenLayersHidden -or
        -not [bool]$audit.noPredecessorRasterReferenced) {
        throw 'Rendered raster-provenance audit contract failed.'
    }
    $renderedAuditVerified = $true
}

$result = [ordered]@{
    state = if ($Preflight) { 'PASS_RASTER_PROVENANCE_PREFLIGHT' } else { 'PASS_RASTER_PROVENANCE_RELEASE_GATE' }
    metadataOnly = $false
    imageBytesEmitted = $false
    revisionId = $revisionId
    manifest = $manifestFull
    entriesVerified = $entries.Count
    cleanBasesVerified = $cleanCount
    currentHeatmapsVerified = $heatmapCount
    currentMasksVerified = $verifiedMasks
    renderedAuditVerified = $renderedAuditVerified
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 10
} else {
    [pscustomobject]$result | Format-List
}
