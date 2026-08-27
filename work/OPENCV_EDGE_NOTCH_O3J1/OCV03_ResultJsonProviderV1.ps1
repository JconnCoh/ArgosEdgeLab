#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Collect,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ConfigurationPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Collect)) { throw 'Specify exactly one of -Preflight or -Collect.' }

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256Bytes([byte[]]$Bytes) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Read-BoundedUtf8([string]$Path, [int64]$MaximumBytes) {
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    Assert-True (-not $item.PSIsContainer) "JSON source is not a leaf: $Path"
    Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "JSON source is a reparse point: $Path"
    Assert-True ($item.Length -le $MaximumBytes) "JSON source exceeds its byte limit: $Path"
    $stream = [IO.File]::Open($item.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $bytes = New-Object byte[] ([int]$item.Length)
        $offset = 0
        while ($offset -lt $bytes.Length) {
            $read = $stream.Read($bytes, $offset, $bytes.Length - $offset)
            if ($read -le 0) { throw "Unexpected end of JSON source: $Path" }
            $offset += $read
        }
    }
    finally { $stream.Dispose() }
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    $text = $encoding.GetString($bytes)
    [void]($text | ConvertFrom-Json)
    return [pscustomobject]@{ bytes=$bytes; text=$text; sha256=Get-Sha256Bytes $bytes }
}

function Normalize-RelativePath([string]$Value) {
    Assert-True (-not [string]::IsNullOrWhiteSpace($Value)) 'An empty relative path is not allowed.'
    Assert-True (-not [IO.Path]::IsPathRooted($Value)) "A rooted relative path is not allowed: $Value"
    Assert-True ($Value.IndexOfAny([char[]]'*?') -lt 0) "A wildcard relative path is not allowed: $Value"
    $normalized = $Value.Replace('\','/').Trim('/')
    $components = @($normalized.Split('/') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-True ($components.Count -gt 0) "An empty normalized relative path is not allowed: $Value"
    Assert-True (@($components | Where-Object { $_ -eq '.' -or $_ -eq '..' }).Count -eq 0) "Traversal is not allowed: $Value"
    Assert-True ([int](($components | Measure-Object Length -Maximum).Maximum) -le 80) "A relative-path component exceeds 80 characters: $Value"
    return ($components -join '/')
}

function Assert-NoReparseLineage([string]$Root, [string]$Leaf) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\')
    $leafFull = [IO.Path]::GetFullPath($Leaf)
    $prefix = $rootFull + '\'
    Assert-True ($leafFull.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "JSON source escaped the approved root: $leafFull"
    $current = $rootFull
    $relative = $leafFull.Substring($prefix.Length)
    foreach ($component in $relative.Split('\')) {
        $current = Join-Path $current $component
        if (Test-Path -LiteralPath $current) {
            $attributes = [IO.File]::GetAttributes($current)
            Assert-True (($attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Reparse lineage is not allowed: $current"
        }
    }
}

function Read-Control([string]$Path, [int64]$MaximumBytes) {
    $full = [IO.Path]::GetFullPath($Path)
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) "Control file is absent: $full"
    Assert-True ((Get-Item -LiteralPath $full).Length -le $MaximumBytes) "Control file is too large: $full"
    return (Get-Content -LiteralPath $full -Raw | ConvertFrom-Json)
}

$config = Read-Control $ConfigurationPath 65536
$invocation = Read-Control $InvocationPath 65536
Assert-True ([string]$config.schema -eq 'argos_ocv03_review_json_provider_config_v1') 'Provider configuration schema changed.'
Assert-True ([string]$config.state -eq 'FROZEN_CONFIG') 'Provider configuration is not frozen.'
Assert-True ([string]$invocation.schema -eq 'argos_ocv03_review_json_provider_invocation_v1') 'Provider invocation schema changed.'
Assert-True ([string]$config.revision -eq [string]$invocation.revision) 'Provider revision mismatch.'
Assert-True ([string]$config.approvedRootName -eq [string]$invocation.approvedRootName) 'Approved root identity mismatch.'
Assert-True ([string]$config.allowedExtension -eq '.json') 'Only JSON is allowed.'
Assert-True (-not [bool]$config.imageExtensionsAllowed -and -not [bool]$config.sourceMutationAllowed -and -not [bool]$config.taskOrProcessActionAllowed -and -not [bool]$config.providerActivationAllowed) 'Provider safety authority changed.'
Assert-True ([bool]$config.reviewOnly -and -not [bool]$config.trainingEligible -and -not [bool]$config.xmlEligible -and -not [bool]$config.productionEligible -and -not [bool]$config.productionRoutingEnabled) 'Provider authority changed.'
Assert-True ([bool]$invocation.returnRawJsonText -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.trainingEligible -and -not [bool]$invocation.xmlEligible -and -not [bool]$invocation.productionEligible -and -not [bool]$invocation.productionRoutingEnabled) 'Invocation authority changed.'

$maximumFiles = [int]$config.maximumFiles
$maximumFileBytes = [int64]$config.maximumFileBytes
$maximumTotalBytes = [int64]$config.maximumTotalBytes
Assert-True ($maximumFiles -ge 1 -and $maximumFiles -le 128) 'Maximum file count is invalid.'
Assert-True ($maximumFileBytes -ge 2 -and $maximumFileBytes -le 16777216) 'Maximum per-file bytes is invalid.'
Assert-True ($maximumTotalBytes -ge $maximumFileBytes -and $maximumTotalBytes -le 67108864) 'Maximum total bytes is invalid.'

$allowed = @($config.allowedRelativePaths | ForEach-Object { Normalize-RelativePath ([string]$_) })
$requested = @($invocation.relativePaths | ForEach-Object { Normalize-RelativePath ([string]$_) })
Assert-True ($allowed.Count -le $maximumFiles -and $requested.Count -le $maximumFiles) 'Provider file count exceeds its bound.'
Assert-True ([int]$invocation.expectedFileCount -eq $requested.Count) 'Expected file count changed.'
Assert-True (@($allowed | Sort-Object -Unique).Count -eq $allowed.Count) 'Allowed JSON paths contain duplicates.'
Assert-True (@($requested | Sort-Object -Unique).Count -eq $requested.Count) 'Requested JSON paths contain duplicates.'
Assert-True (@($allowed | Where-Object { [IO.Path]::GetExtension($_) -ine '.json' }).Count -eq 0) 'An allowed path is not JSON.'
Assert-True (@($requested | Where-Object { [IO.Path]::GetExtension($_) -ine '.json' }).Count -eq 0) 'A requested path is not JSON.'
$allowedSet = @{}; foreach ($path in $allowed) { $allowedSet[$path.ToUpperInvariant()] = $true }
Assert-True (@($requested | Where-Object { -not $allowedSet.ContainsKey($_.ToUpperInvariant()) }).Count -eq 0) 'Invocation requested an unapproved JSON path.'
Assert-True (@($allowed | Where-Object { $requested -inotcontains $_ }).Count -eq 0 -and $requested.Count -eq $allowed.Count) 'Invocation must request the complete exact allowlist.'

$root = [IO.Path]::GetFullPath([string]$config.approvedRootPath).TrimEnd('\')
Assert-True (-not [string]::IsNullOrWhiteSpace($root) -and $root.IndexOfAny([char[]]'*?') -lt 0) 'Approved root path is invalid.'
$planned = @()
foreach ($relative in $requested) {
    $leaf = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $relative.Replace('/','\')))
    Assert-True ($leaf.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) "Planned JSON source escaped the approved root: $relative"
    $components = @($leaf.Split('\') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    Assert-True (($leaf.Length + 32) -lt 200) "Planned JSON source exceeds the path budget: $relative"
    Assert-True ([int](($components | Measure-Object Length -Maximum).Maximum) -le 80) "Planned JSON source component exceeds 80 characters: $relative"
    $planned += [pscustomobject]@{ relativePath=$relative; fullPath=$leaf }
}

if ($Preflight) {
    [ordered]@{
        schema='argos_ocv03_review_json_provider_preflight_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_O3J1_RESULT_JSON_PROVIDER_PREFLIGHT'
        approvedRootName=[string]$config.approvedRootName
        approvedRootPath=$root
        requestedFileCount=$requested.Count
        maximumFileBytes=$maximumFileBytes
        maximumTotalBytes=$maximumTotalBytes
        sourceFilesRead=$false
        imageBytesRead=$false
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 6 -Compress
    return
}

Assert-True (Test-Path -LiteralPath $root -PathType Container) "Approved JSON root is absent: $root"
$rootAttributes = [IO.File]::GetAttributes($root)
Assert-True (($rootAttributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "Approved JSON root is a reparse point: $root"
$rows = @()
$total = [int64]0
foreach ($row in $planned) {
    Assert-True (Test-Path -LiteralPath $row.fullPath -PathType Leaf) "Required JSON source is absent: $($row.relativePath)"
    Assert-NoReparseLineage $root $row.fullPath
    $content = Read-BoundedUtf8 $row.fullPath $maximumFileBytes
    $total += [int64]$content.bytes.Length
    Assert-True ($total -le $maximumTotalBytes) 'JSON sources exceeded the total byte limit.'
    $rows += [pscustomobject]@{
        relativePath=[string]$row.relativePath
        bytes=[int64]$content.bytes.Length
        sha256=[string]$content.sha256
        rawJsonText=[string]$content.text
    }
}

[ordered]@{
    schema='argos_ocv03_review_json_provider_result_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_O3J1_EXACT_RESULT_JSON_COLLECTED'
    revision=[string]$config.revision
    approvedRootName=[string]$config.approvedRootName
    approvedRootPath=$root
    fileCount=$rows.Count
    totalBytes=$total
    files=$rows
    exactAllowlistConsumed=$true
    sourceFilesRead=$true
    jsonTextOnly=$true
    imageBytesRead=$false
    sourceImageBytesRead=$false
    sourceMutationPerformed=$false
    sourceDeletionPerformed=$false
    taskOrProcessActionPerformed=$false
    providerActivated=$false
    reviewOnly=$true
    trainingEligible=$false
    xmlEligible=$false
    productionEligible=$false
    productionRoutingEnabled=$false
} | ConvertTo-Json -Depth 8 -Compress
