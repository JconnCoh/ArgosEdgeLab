$s = Get-Content -LiteralPath 'D:\O3F16U10\SUMMARY.json' -Raw | ConvertFrom-Json
$o = @()
foreach ($r in $s.results) {
    foreach ($c in @('BF', 'DF')) {
        $p = $r.channels.$c.annularEvidence.cyclicPath
        $o += [pscustomobject]@{
            n = $r.ordinal
            id = $r.safeId
            c = $c
            measured = $p.measuredColumnCount
            rescued = $p.offLaneMaximumVetoAvoidedColumnCount
            gaps = @($p.largestImputedRuns | ForEach-Object {
                [pscustomobject]@{
                    columns = $_.columnCount
                    startDeg = [math]::Round($_.startDegrees, 3)
                    endDeg = [math]::Round($_.endDegrees, 3)
                    centerDeg = [math]::Round($_.centerDegrees, 3)
                }
            })
        }
    }
}
$o | ConvertTo-Json -Depth 6 -Compress
