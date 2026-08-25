[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Collect
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Assert-True {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-Utf8CreateNewJson {
    param([string]$Path,[object]$Value,[int]$Depth = 16)
    $json = $Value | ConvertTo-Json -Depth $Depth
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$manifestPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($manifestPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'JEO1R invocation left the project.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_jeo1r_collection_invocation_v1') 'JEO1R invocation schema changed.'
Assert-True (-not [bool]$invocation.overwriteAuthorized) 'JEO1R overwrite authority changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'JEO1R safety flags changed.'

$sourceZip = [IO.Path]::GetFullPath([string]$invocation.sourceZip)
$destinationRoot = [IO.Path]::GetFullPath((Join-Path $project ([string]$invocation.destinationRoot)))
Assert-True ($destinationRoot.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'JEO1R destination left the project.'
$destinationZip = Join-Path $destinationRoot 'JEO1R.zip'
$extractRoot = Join-Path $destinationRoot 'extract'
$collectionGate = Join-Path $destinationRoot 'JEO1R_COLLECTION_GATE.json'
Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'JEO1R source ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes) 'JEO1R source size changed.'
Assert-True ((Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'JEO1R source hash changed.'
Assert-True (-not (Test-Path -LiteralPath $destinationRoot)) 'JEO1R destination root must be fresh.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($sourceZip)
try {
    $actual = @($archive.Entries | ForEach-Object {
        [pscustomobject]@{ path=$_.FullName.Replace('\','/'); bytes=[int64]$_.Length; entry=$_ }
    })
    $expected = @($invocation.expectedEntries)
    Assert-True ($actual.Count -eq $expected.Count) 'JEO1R entry count changed.'
    $totalBytes = [int64]0
    foreach ($expectedRow in $expected) {
        $matches = @($actual | Where-Object { [string]$_.path -ceq [string]$expectedRow.path -and [int64]$_.bytes -eq [int64]$expectedRow.bytes })
        Assert-True ($matches.Count -eq 1) "JEO1R expected entry changed: $($expectedRow.path)"
        $totalBytes += [int64]$expectedRow.bytes
    }
    Assert-True ($totalBytes -le 1048576) 'JEO1R expanded bytes exceed the bounded 1 MiB limit.'
    foreach ($actualRow in $actual) {
        $relative = [string]$actualRow.path
        Assert-True (-not [string]::IsNullOrWhiteSpace($relative)) 'JEO1R contains an empty entry.'
        Assert-True (-not [IO.Path]::IsPathRooted($relative) -and $relative.IndexOf(':') -lt 0) "JEO1R contains a rooted entry: $relative"
        Assert-True (@($relative.Split('/') | Where-Object { $_ -eq '..' }).Count -eq 0) "JEO1R contains traversal: $relative"
        $target = [IO.Path]::GetFullPath((Join-Path $extractRoot $relative.Replace('/','\')))
        Assert-True ($target.StartsWith($extractRoot+'\',[StringComparison]::OrdinalIgnoreCase)) "JEO1R extraction escaped: $relative"
    }

    $preflightResult = [ordered]@{
        schema='argos_jeo1r_collection_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1R_COLLECTION_PREFLIGHT'
        sourceZip=$sourceZip;sourceZipBytes=[int64]$invocation.sourceZipBytes;sourceZipSha256=[string]$invocation.sourceZipSha256
        destinationRoot=$destinationRoot;entryCount=$actual.Count;expandedBytes=$totalBytes;targetExecuted=$false;mutationsPerformed=$false
        imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 12; return }

    [void][IO.Directory]::CreateDirectory($destinationRoot)
    [IO.File]::Copy($sourceZip,$destinationZip,$false)
    Assert-True ((Get-Sha256 $destinationZip) -eq [string]$invocation.sourceZipSha256) 'JEO1R local copy hash changed.'
    [void][IO.Directory]::CreateDirectory($extractRoot)
    $fileRows = @()
    foreach ($actualRow in $actual) {
        $relative = [string]$actualRow.path
        $target = [IO.Path]::GetFullPath((Join-Path $extractRoot $relative.Replace('/','\')))
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void][IO.Directory]::CreateDirectory($parent) }
        $inputStream = $actualRow.entry.Open()
        $outputStream = New-Object IO.FileStream($target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try { $inputStream.CopyTo($outputStream) }
        finally { $outputStream.Dispose(); $inputStream.Dispose() }
        Assert-True ((Get-Item -LiteralPath $target).Length -eq [int64]$actualRow.bytes) "JEO1R extracted size changed: $relative"
        $fileRows += [pscustomobject]@{path=$relative;bytes=[int64]$actualRow.bytes;sha256=Get-Sha256 $target}
    }

    $result = [ordered]@{
        schema='argos_jeo1r_collection_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1R_EXACT_COLLECTION'
        sourceZip=$sourceZip;sourceZipBytes=[int64]$invocation.sourceZipBytes;sourceZipSha256=[string]$invocation.sourceZipSha256
        localZip=$destinationZip;localZipSha256=Get-Sha256 $destinationZip;extractRoot=$extractRoot;entryCount=$fileRows.Count;expandedBytes=$totalBytes
        fileRows=$fileRows;targetExecuted=$false;targetMutationsPerformed=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-Utf8CreateNewJson -Path $collectionGate -Value $result -Depth 16
    $result | ConvertTo-Json -Depth 16
} finally {
    $archive.Dispose()
}
