#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-O3B7([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-O3B7Sha256([string]$LiteralPath) {
    $stream = New-Object IO.FileStream($LiteralPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, 8388608, [IO.FileOptions]::SequentialScan)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-O3B7SubstMappings([string]$SubstPath) {
    $rows = @(& $SubstPath 2>&1)
    Assert-O3B7 ($LASTEXITCODE -eq 0) 'O3B7 subst inventory failed.'
    $map = @{}
    foreach ($row in $rows) {
        $text = [string]$row
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $match = [regex]::Match($text, '^([A-Za-z]):\\: => (.+)$')
        Assert-O3B7 $match.Success "O3B7 malformed subst row: $text"
        $name = $match.Groups[1].Value.ToUpperInvariant()
        Assert-O3B7 (-not $map.ContainsKey($name)) "O3B7 duplicate subst drive: $name"
        $map[$name] = [IO.Path]::GetFullPath($match.Groups[2].Value).TrimEnd('\')
    }
    return $map
}

function Get-O3B7SafeRelative([string]$RelativePath) {
    Assert-O3B7 (-not [string]::IsNullOrWhiteSpace($RelativePath)) 'O3B7 source relative path is empty.'
    Assert-O3B7 (-not [IO.Path]::IsPathRooted($RelativePath)) 'O3B7 source relative path is rooted.'
    $normalized = $RelativePath.Replace('/', '\')
    Assert-O3B7 ($normalized -notmatch '(^|\\)\.\.?($|\\)') 'O3B7 source relative path contains traversal.'
    Assert-O3B7 ($normalized.IndexOfAny([char[]]'*?[]') -lt 0) 'O3B7 source relative path contains wildcard syntax.'
    return $normalized
}

function Copy-O3B7AndHash([string]$Source, [string]$Destination) {
    $input = New-Object IO.FileStream($Source, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read, 8388608, [IO.FileOptions]::SequentialScan)
    $output = New-Object IO.FileStream($Destination, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None, 8388608, [IO.FileOptions]::SequentialScan)
    $sha = [Security.Cryptography.SHA256]::Create()
    $buffer = New-Object byte[] 8388608
    $total = [int64]0
    try {
        while (($count = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
            [void]$sha.TransformBlock($buffer, 0, $count, $null, 0)
            $output.Write($buffer, 0, $count)
            $total += $count
        }
        [void]$sha.TransformFinalBlock($buffer, 0, 0)
        $output.Flush($true)
        $hash = ([BitConverter]::ToString($sha.Hash)).Replace('-', '')
    } finally {
        $sha.Dispose()
        $output.Dispose()
        $input.Dispose()
    }
    return [pscustomobject]@{ bytes = $total; sha256 = $hash }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-O3B7 (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O3B7 invocation manifest is missing.'
Assert-O3B7 ((Get-Item -LiteralPath $manifestPath).Length -le 1048576) 'O3B7 invocation manifest is too large.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

Assert-O3B7 ([string]$invocation.schema -eq 'argos_ocv03_o3b7_short_stage_invocation_v1') 'O3B7 invocation schema changed.'
Assert-O3B7 ([string]$invocation.state -eq 'FROZEN_SHORT_STAGE_CONTRACT') 'O3B7 invocation is not frozen.'
Assert-O3B7 ([bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O3B7 authority contract failed.'
foreach ($property in @('sourceMutationAuthorized','sourceDeletionAuthorized','imageDecodeAuthorized','pixelProcessingAuthorized','taskActionAuthorized','existingProcessActionAuthorized','providerActivationAuthorized','thresholdOrAlgorithmChangeAuthorized','holdClearanceAuthorized')) {
    Assert-O3B7 (-not [bool]$invocation.$property) "O3B7 forbidden authority is true: $property"
}
Assert-O3B7 ([bool]$invocation.sourceImageReadAuthorized) 'O3B7 source image read is not authorized.'
Assert-O3B7 ([string]$invocation.aliasDrive -match '^[A-Z]:$') 'O3B7 alias drive is invalid.'
Assert-O3B7 (@($invocation.sources).Count -eq 2) 'O3B7 requires exactly two source leaves.'

$sourceRoot = [IO.Path]::GetFullPath([string]$invocation.sourceRoot).TrimEnd('\')
$outputRoot = [IO.Path]::GetFullPath([string]$invocation.outputRoot).TrimEnd('\')
$partialRoot = $outputRoot + '.partial'
$failedRoot = $outputRoot + '.failed'
$aliasDrive = [string]$invocation.aliasDrive
$aliasName = $aliasDrive.TrimEnd(':')
$aliasRoot = $aliasDrive + '\'
$substPath = [IO.Path]::GetFullPath([string]$invocation.substPath)
Assert-O3B7 ($outputRoot.Length + 32 -lt 200 -and $partialRoot.Length + 32 -lt 200 -and $failedRoot.Length + 32 -lt 200) 'O3B7 output path budget failed.'

$sourceRows = @()
$channels = @{}
$outputs = @{}
foreach ($row in @($invocation.sources)) {
    $channel = [string]$row.channel
    Assert-O3B7 ($channel -in @('BF_BACKSIDE','DF_BACKSIDE') -and -not $channels.ContainsKey($channel)) 'O3B7 source channel is invalid or duplicated.'
    $channels[$channel] = $true
    $relative = Get-O3B7SafeRelative ([string]$row.relativePath)
    $outputName = [string]$row.outputName
    Assert-O3B7 ($outputName -match '^[A-Za-z0-9_-]{1,32}\.bmp$' -and -not $outputs.ContainsKey($outputName.ToUpperInvariant())) 'O3B7 output name is invalid or duplicated.'
    $outputs[$outputName.ToUpperInvariant()] = $true
    $aliasPath = [IO.Path]::GetFullPath($aliasRoot + $relative)
    Assert-O3B7 ($aliasPath.Length + 32 -lt 200) 'O3B7 alias source path budget failed.'
    $sourceRows += [pscustomobject]@{ channel=$channel; relativePath=$relative; aliasPath=$aliasPath; outputName=$outputName; expectedBytes=[int64]$row.expectedBytes; expectedLastWriteTimeUtc=[string]$row.expectedLastWriteTimeUtc }
}
Assert-O3B7 ($channels.Count -eq 2) 'O3B7 BF/DF channel cardinality changed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_ocv03_o3b7_short_stage_preflight_v1'
        state = 'PASS_O3B7_SHORT_STAGE_PREFLIGHT'
        sourceCount = $sourceRows.Count
        aliasDrive = $aliasDrive
        aliasAnchor = 'EXACT_SLOT_RELATIVE_ROOT'
        outputRoot = $outputRoot
        sourceImageBytesRead = $false
        outputCreated = $false
        aliasCreated = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 8
    return
}

Assert-O3B7 ([string]$env:COMPUTERNAME -eq [string]$invocation.expectedComputerName) 'O3B7 computer identity mismatch.'
Assert-O3B7 (Test-Path -LiteralPath $sourceRoot -PathType Container) 'O3B7 exact source root is absent.'
Assert-O3B7 (Test-Path -LiteralPath $substPath -PathType Leaf) 'O3B7 subst.exe is absent.'
foreach ($path in @($outputRoot,$partialRoot,$failedRoot)) { Assert-O3B7 (-not (Test-Path -LiteralPath $path)) "O3B7 create-new output exists: $path" }
$beforeMappings = Get-O3B7SubstMappings $substPath
Assert-O3B7 (-not $beforeMappings.ContainsKey($aliasName) -and -not (Test-Path -LiteralPath $aliasRoot)) 'O3B7 alias is already in use.'

[void](New-Item -ItemType Directory -Path $partialRoot)
$aliasCreated = $false
$results = New-Object Collections.Generic.List[object]
try {
    $createOutput = @(& $substPath $aliasDrive $sourceRoot 2>&1)
    Assert-O3B7 ($LASTEXITCODE -eq 0 -and $createOutput.Count -eq 0) 'O3B7 alias creation failed.'
    $aliasCreated = $true
    $createdMappings = Get-O3B7SubstMappings $substPath
    Assert-O3B7 ($createdMappings.ContainsKey($aliasName) -and [string]$createdMappings[$aliasName] -eq $sourceRoot) 'O3B7 alias target mismatch.'

    foreach ($row in $sourceRows) {
        $before = Get-Item -LiteralPath $row.aliasPath -Force
        Assert-O3B7 (-not $before.PSIsContainer -and ($before.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) 'O3B7 source is not a regular file.'
        Assert-O3B7 ([int64]$before.Length -eq [int64]$row.expectedBytes) "O3B7 source length changed: $($row.channel)"
        $beforeWrite = $before.LastWriteTimeUtc.ToString('o')
        Assert-O3B7 ($beforeWrite -eq [string]$row.expectedLastWriteTimeUtc) "O3B7 source timestamp changed: $($row.channel)"
        $destination = Join-Path $partialRoot $row.outputName
        $copy = Copy-O3B7AndHash -Source $row.aliasPath -Destination $destination
        $after = Get-Item -LiteralPath $row.aliasPath -Force
        Assert-O3B7 ([int64]$copy.bytes -eq [int64]$row.expectedBytes -and [int64]$after.Length -eq [int64]$before.Length -and $after.LastWriteTimeUtc.ToString('o') -eq $beforeWrite) "O3B7 source changed during copy: $($row.channel)"
        $outputHash = Get-O3B7Sha256 $destination
        Assert-O3B7 ($outputHash -eq [string]$copy.sha256) "O3B7 staged output hash mismatch: $($row.channel)"
        $results.Add([pscustomobject]@{channel=$row.channel;sourceRelativePath=$row.relativePath;sourceBytes=[int64]$copy.bytes;sourceLastWriteTimeUtc=$beforeWrite;sourceSha256=[string]$copy.sha256;outputName=$row.outputName;outputBytes=(Get-Item -LiteralPath $destination).Length;outputSha256=$outputHash;sourceStableDuringCopy=$true})
    }
} catch {
    if (Test-Path -LiteralPath $partialRoot -PathType Container) { Move-Item -LiteralPath $partialRoot -Destination $failedRoot }
    throw
} finally {
    if ($aliasCreated) {
        $removeOutput = @(& $substPath $aliasDrive '/D' 2>&1)
        Assert-O3B7 ($LASTEXITCODE -eq 0 -and $removeOutput.Count -eq 0 -and -not (Test-Path -LiteralPath $aliasRoot)) 'O3B7 alias cleanup failed.'
    }
}

$result = [ordered]@{
    schema = 'argos_ocv03_o3b7_short_stage_result_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O3B7_EXACT_BACKSIDE_PAIR_STAGED'
    sourceRoot = $sourceRoot
    aliasDrive = $aliasDrive
    aliasRemoved = $true
    outputRoot = $outputRoot
    sources = @($results)
    sourceImageReadCount = $results.Count
    imageDecoded = $false
    pixelProcessingPerformed = $false
    sourceMutationPerformed = $false
    sourceDeletionPerformed = $false
    taskOrExistingProcessActionPerformed = $false
    providerActivated = $false
    thresholdOrAlgorithmChanged = $false
    holdsCleared = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
[IO.File]::WriteAllText((Join-Path $partialRoot 'O3B7_RESULT.json'), (($result | ConvertTo-Json -Depth 16) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $partialRoot -Destination $outputRoot
$result | ConvertTo-Json -Depth 16
