[CmdletBinding()]
param(
    [string]$InputCsv = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/comparison_r14_r15_complete_20260829/R15_HOLDS.csv',
    [string]$OutputJson = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/R15_FINAL_HOLD_ENGINE_RESULTS_PULL.json'
)

$ErrorActionPreference = 'Stop'
$rows = @(Import-Csv -LiteralPath $InputCsv)
if ($rows.Count -ne 55) {
    throw "Expected 55 R15 hold rows; found $($rows.Count)."
}

$prefix = 'D:\KLARFExport\'
$relativePaths = @(
    $rows | ForEach-Object {
        $root = [string]$_.r15DiagnosticRoot
        if (-not $root.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Unexpected diagnostic root: $root"
        }
        (($root.Substring($prefix.Length) -replace '\\', '/') + '/RESULT.json')
    } | Sort-Object -Unique
)
if ($relativePaths.Count -ne 55) {
    throw "Expected 55 unique result paths; found $($relativePaths.Count)."
}
if ($relativePaths | Where-Object { $_ -notlike '_ArgosReview/C15RUN2/i/*/back_notch/RESULT.json' }) {
    throw 'A result path escaped the frozen R15 output layout.'
}

$definition = [ordered]@{
    targetRole = 'JBOD'
    jobClass = 'DATA_PULL'
    maxResultBytes = 67108864
    parameters = [ordered]@{
        approvedRoot = 'JBOD_KLARF_EXPORT'
        relativePaths = $relativePaths
        maximumFiles = 55
        maximumBytes = 67108864
    }
}
$json = $definition | ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path (Get-Location) $OutputJson), $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    State = 'PASS_R15_FINAL_HOLD_PULL_DEFINITION'
    InputCount = $rows.Count
    RelativePathCount = $relativePaths.Count
    OutputJson = $OutputJson
    OutputSha256 = (Get-FileHash -LiteralPath $OutputJson -Algorithm SHA256).Hash
}
