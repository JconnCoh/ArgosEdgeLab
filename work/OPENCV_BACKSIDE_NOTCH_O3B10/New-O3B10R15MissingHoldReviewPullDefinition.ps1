[CmdletBinding()]
param(
    [string]$InputCsv = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/comparison_r14_r15_complete_20260829/R15_HOLDS.csv',
    [string]$OutputJson = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/R15_MISSING_HOLD_REVIEWS_PULL.json'
)

$ErrorActionPreference = 'Stop'
$rows = @(Import-Csv -LiteralPath $InputCsv)
if ($rows.Count -ne 55) { throw "Expected 55 R15 hold rows; found $($rows.Count)." }

$wanted = @{}
foreach ($row in $rows) {
    $root = [string]$row.r15DiagnosticRoot
    $prefix = 'D:\KLARFExport\'
    if (-not $root.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected diagnostic root: $root"
    }
    $wanted[$root.Substring($prefix.Length).Replace('\', '/')] = $true
}

$seen = @{}
foreach ($directory in @(Get-ChildItem -LiteralPath 'C:\' -Directory -Filter 'R15H?D')) {
    foreach ($file in @(Get-ChildItem -LiteralPath $directory.FullName -Recurse -File -Filter '*_review.jpg')) {
        $marker = 'data\JBOD_KLARF_EXPORT\'
        $index = $file.FullName.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
        if ($index -lt 0) { continue }
        $relativeRoot = $file.Directory.FullName.Substring($index + $marker.Length).Replace('\', '/')
        if (-not $wanted.ContainsKey($relativeRoot)) { continue }
        if (-not $seen.ContainsKey($relativeRoot)) { $seen[$relativeRoot] = @{} }
        $seen[$relativeRoot][$file.Name] = $true
    }
}

$missingRoots = @(
    $wanted.Keys | Where-Object {
        -not $seen.ContainsKey($_) -or
        -not $seen[$_].ContainsKey('BF_review.jpg') -or
        -not $seen[$_].ContainsKey('DF_review.jpg')
    } | Sort-Object
)
if ($missingRoots.Count -ne 31) { throw "Expected 31 missing review pairs; found $($missingRoots.Count)." }

$relativePaths = @()
foreach ($root in $missingRoots) {
    $relativePaths += "$root/BF_review.jpg"
    $relativePaths += "$root/DF_review.jpg"
}

$definition = [ordered]@{
    targetRole = 'JBOD'
    jobClass = 'DATA_PULL'
    maxResultBytes = 134217728
    parameters = [ordered]@{
        approvedRoot = 'JBOD_KLARF_EXPORT'
        relativePaths = $relativePaths
        maximumFiles = 62
        maximumBytes = 134217728
    }
}
$json = $definition | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path (Get-Location) $OutputJson), $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    State = 'PASS_R15_MISSING_HOLD_REVIEW_PULL_DEFINITION'
    MissingPairCount = $missingRoots.Count
    RelativePathCount = $relativePaths.Count
    OutputJson = $OutputJson
    OutputSha256 = (Get-FileHash -LiteralPath $OutputJson -Algorithm SHA256).Hash
}
