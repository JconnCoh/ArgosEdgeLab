[CmdletBinding()]
param(
    [string]$HoldCsv = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/comparison_r14_r15_complete_20260829/R15_HOLDS.csv',
    [string]$ResultRoot = 'C:\R15H8D\data\JBOD_KLARF_EXPORT',
    [string]$OutputHtml = 'work/OPENCV_BACKSIDE_NOTCH_O3B10/r15_final_hold_gallery_20260829.html'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web
$rows = @(Import-Csv -LiteralPath $HoldCsv)
if ($rows.Count -ne 55) { throw "Expected 55 hold rows; found $($rows.Count)." }

$reviewFiles = @{}
foreach ($directory in @(Get-ChildItem -LiteralPath 'C:\' -Directory -Filter 'R15H?D')) {
    foreach ($file in @(Get-ChildItem -LiteralPath $directory.FullName -Recurse -File -Filter '*_review.jpg')) {
        $marker = 'data\JBOD_KLARF_EXPORT\'
        $index = $file.FullName.IndexOf($marker, [StringComparison]::OrdinalIgnoreCase)
        if ($index -lt 0) { continue }
        $relativeRoot = $file.Directory.FullName.Substring($index + $marker.Length).Replace('\', '/')
        if (-not $reviewFiles.ContainsKey($relativeRoot)) { $reviewFiles[$relativeRoot] = @{} }
        $reviewFiles[$relativeRoot][$file.Name] = $file.FullName
    }
}

function Get-MorphologyAngles([object]$channel) {
    $angles = @($channel.candidates | Where-Object { [bool]$_.manufacturedMorphologyPassed } | ForEach-Object {
        '{0:0.000}' -f [double]$_.centerAngleDegrees
    })
    if ($angles.Count -eq 0) { return 'none' }
    return $angles -join ', '
}

$cards = foreach ($row in $rows | Sort-Object r15State, identity) {
    $prefix = 'D:\KLARFExport\'
    $relativeRoot = ([string]$row.r15DiagnosticRoot).Substring($prefix.Length).Replace('\', '/')
    $resultPath = Join-Path $ResultRoot (($relativeRoot + '/RESULT.json').Replace('/', '\'))
    $result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
    if (-not $reviewFiles.ContainsKey($relativeRoot) -or
        -not $reviewFiles[$relativeRoot].ContainsKey('BF_review.jpg') -or
        -not $reviewFiles[$relativeRoot].ContainsKey('DF_review.jpg')) {
        throw "Missing review pair: $relativeRoot"
    }
    $identity = [Web.HttpUtility]::HtmlEncode([string]$row.identity)
    $state = [Web.HttpUtility]::HtmlEncode([string]$row.r15State)
    $bfUri = ([Uri]$reviewFiles[$relativeRoot]['BF_review.jpg']).AbsoluteUri
    $dfUri = ([Uri]$reviewFiles[$relativeRoot]['DF_review.jpg']).AbsoluteUri
    $bfAngles = Get-MorphologyAngles $result.bf
    $dfAngles = Get-MorphologyAngles $result.df
    @"
<article class="card" data-state="$state">
  <h2>$identity</h2>
  <p><strong>$state</strong> · eligible BF/DF/pairs: $($result.bfEligibleCandidateCount)/$($result.dfEligibleCandidateCount)/$($result.pairedCandidateCount) · morphology BF: $bfAngles · DF: $dfAngles</p>
  <div class="pair"><figure><figcaption>BF</figcaption><a href="$bfUri"><img loading="lazy" src="$bfUri" alt="BF $identity"></a></figure><figure><figcaption>DF</figcaption><a href="$dfUri"><img loading="lazy" src="$dfUri" alt="DF $identity"></a></figure></div>
</article>
"@
}

$html = @"
<!doctype html><html><head><meta charset="utf-8"><title>R15 final 55 backside holds — diagnostic only</title>
<style>body{margin:0;background:#111;color:#eee;font:14px system-ui}header{position:sticky;top:0;z-index:3;background:#202020;padding:12px 18px;border-bottom:1px solid #555}main{padding:12px}.card{margin:0 0 18px;padding:12px;background:#1b1b1b;border:1px solid #444}.card h2{font-size:16px;margin:0 0 5px}.card p{margin:0 0 10px;color:#ddd}.pair{display:grid;grid-template-columns:1fr 1fr;gap:10px}figure{margin:0}figcaption{font-weight:700;margin-bottom:4px}img{display:block;width:100%;height:auto;background:#000;border:1px solid #555}a:focus img,a:hover img{border-color:#0ff}@media(max-width:900px){.pair{grid-template-columns:1fr}}</style></head>
<body><header><strong>DIAGNOSTIC ONLY — R15 final 55 backside holds</strong><br>Existing OpenCV review rasters; click either channel for native resolution. No operator feedback is collected here.</header><main>
$($cards -join [Environment]::NewLine)
</main></body></html>
"@
[IO.File]::WriteAllText((Join-Path (Get-Location) $OutputHtml), $html, [Text.UTF8Encoding]::new($false))

[pscustomobject]@{
    State = 'PASS_R15_FINAL_HOLD_GALLERY'
    CardCount = $rows.Count
    PairedImageCount = $rows.Count
    OutputHtml = $OutputHtml
    OutputSha256 = (Get-FileHash -LiteralPath $OutputHtml -Algorithm SHA256).Hash
}
