#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Get-TextSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '') }
    finally { $sha.Dispose() }
}

function Write-Utf8CreateNewJson {
    param([string]$Path, [object]$Value, [int]$Depth = 20)
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new JSON path already exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

function Verify-Package {
    param([string]$Root)
    $manifestPath = Join-Path $Root 'PACKAGE_MANIFEST.json'
    Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'PACKAGE_MANIFEST.json is absent.'
    $package = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-True ([string]$package.schema -eq 'argos_jeo1_direct_admin_package_manifest_v1') 'JEO1 package schema changed.'
    Assert-True ([string]$package.revision -eq 'JEO1') 'JEO1 package revision changed.'
    Assert-True ([bool]$package.reviewOnly -and -not [bool]$package.productionRoutingEnabled) 'JEO1 package safety flags changed.'
    $prefix = [IO.Path]::GetFullPath($Root).TrimEnd('\') + '\'
    foreach ($file in @($package.files)) {
        $relative = [string]$file.path
        Assert-True ($relative.IndexOfAny([char[]]'*?') -lt 0) "Package path contains a wildcard: $relative"
        $candidate = [IO.Path]::GetFullPath((Join-Path $Root $relative.Replace('/', '\')))
        Assert-True ($candidate.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) "Package path escaped: $relative"
        Assert-True (Test-Path -LiteralPath $candidate -PathType Leaf) "Package file is absent: $relative"
        Assert-True ((Get-Item -LiteralPath $candidate).Length -eq [int64]$file.bytes) "Package byte count changed: $relative"
        Assert-True ((Get-Sha256 $candidate) -eq [string]$file.sha256) "Package file hash changed: $relative"
    }
    return $package
}

function Read-Invocation {
    param([string]$Path, [bool]$IsRehearsal)
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "Invocation manifest is absent: $Path"
    Assert-True ((Get-Item -LiteralPath $Path).Length -le 1048576) 'Invocation manifest exceeds 1 MiB.'
    $value = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Assert-True ([string]$value.schema -eq 'argos_jeo1_direct_admin_invocation_v1') 'JEO1 invocation schema changed.'
    Assert-True ([bool]$value.rehearsal -eq $IsRehearsal) 'JEO1 invocation rehearsal mode changed.'
    Assert-True ([bool]$value.reviewOnly -and -not [bool]$value.productionRoutingEnabled) 'JEO1 invocation safety flags changed.'
    Assert-True ([string]$value.incidentId -eq 'JBOD_CDM1_POST_RUN_EVIDENCE_20260825') 'JEO1 incident identity changed.'
    Assert-True ([string]$value.requestId -eq 'REQ_O2D4') 'JEO1 request identity changed.'
    Assert-True ([string]$value.expectedResponsePrefix -eq 'R_A2A87054A416_') 'JEO1 response prefix changed.'
    Assert-True (@($value.pathSources).Count -ge 1 -and @($value.pathSources).Count -le 32) 'JEO1 path-source count is outside 1..32.'
    Assert-True (@($value.treeSources).Count -eq 3) 'JEO1 exact retired-tree source count changed.'
    return $value
}

function Test-SafeEvidenceExtension {
    param([string]$Extension)
    return $Extension.ToLowerInvariant() -in @('.json', '.jsonl', '.txt', '.log', '.sig', '.ps1', '.cmd')
}

function Get-PathRows {
    param(
        [object]$Source,
        [Collections.Generic.List[object]]$CopyCandidates,
        [int64]$MaximumSafeFileBytes,
        [int64]$MaximumBinaryEvidenceBytes
    )
    $sourceId = [string]$Source.id
    Assert-True ($sourceId -match '^[A-Z0-9_]{1,32}$') "Unsafe JEO1 source id: $sourceId"
    $rootText = [string]$Source.root
    Assert-True (-not [string]::IsNullOrWhiteSpace($rootText)) "JEO1 source root is empty: $sourceId"
    Assert-True ($rootText.IndexOfAny([char[]]'*?') -lt 0) "JEO1 source root contains a wildcard: $sourceId"
    Assert-True ([IO.Path]::IsPathRooted($rootText)) "JEO1 source root is not absolute: $sourceId"
    $root = [IO.Path]::GetFullPath($rootText).TrimEnd('\')
    $selection = [string]$Source.selection
    Assert-True ($selection -in @('EXACT_PATH', 'CHILD_NAME_EXACT', 'CHILD_NAME_PREFIX')) "JEO1 source selection changed: $sourceId"
    $maximumDepth = [int]$Source.maximumDepth
    $maximumRows = [int]$Source.maximumRows
    Assert-True ($maximumDepth -ge 0 -and $maximumDepth -le 8) "JEO1 source depth is outside 0..8: $sourceId"
    Assert-True ($maximumRows -ge 1 -and $maximumRows -le 1000) "JEO1 source row bound is outside 1..1000: $sourceId"
    $copySafe = [bool]$Source.copySafeEvidence
    $copyExactZip = [bool]$Source.copyExactZip
    Assert-True (-not $copyExactZip -or $selection -eq 'EXACT_PATH') "JEO1 binary ZIP copy must use an exact path: $sourceId"
    $rows = New-Object Collections.Generic.List[object]
    $errors = New-Object Collections.Generic.List[object]
    $queue = New-Object Collections.Generic.Queue[object]
    $startItems = @()
    if ($selection -eq 'EXACT_PATH') {
        if (Test-Path -LiteralPath $root) { $startItems = @((Get-Item -LiteralPath $root -Force -ErrorAction Stop)) }
    }
    elseif (Test-Path -LiteralPath $root -PathType Container) {
        $matchText = [string]$Source.matchText
        Assert-True (-not [string]::IsNullOrWhiteSpace($matchText)) "JEO1 child match is empty: $sourceId"
        $children = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop)
        if ($selection -eq 'CHILD_NAME_EXACT') {
            $startItems = @($children | Where-Object { [string]$_.Name -eq $matchText })
        }
        else {
            $startItems = @($children | Where-Object { ([string]$_.Name).StartsWith($matchText, [StringComparison]::OrdinalIgnoreCase) })
        }
    }
    foreach ($item in @($startItems)) { $queue.Enqueue([pscustomobject]@{ item = $item; depth = 0 }) }
    $truncated = $false
    while ($queue.Count -gt 0) {
        $record = $queue.Dequeue()
        $item = $record.item
        $depth = [int]$record.depth
        if ($rows.Count -ge $maximumRows) { $truncated = $true; break }
        try {
            $isDirectory = [bool]$item.PSIsContainer
            $extension = ''
            if (-not $isDirectory) { $extension = [IO.Path]::GetExtension([string]$item.Name).ToLowerInvariant() }
            $safeContentType = (-not $isDirectory) -and (Test-SafeEvidenceExtension $extension)
            $bytes = $null
            if (-not $isDirectory) { $bytes = [int64]$item.Length }
            $hash = $null
            $contentRead = $false
            $binaryCopied = $false
            if ($safeContentType -and $bytes -le $MaximumSafeFileBytes) {
                $hash = Get-Sha256 $item.FullName
                $contentRead = $true
                if ($copySafe) {
                    $CopyCandidates.Add([pscustomobject]@{ sourceId = $sourceId; sourcePath = [string]$item.FullName; extension = $extension; bytes = $bytes; sha256 = $hash; kind = 'SAFE_TEXT' })
                }
            }
            elseif ($copyExactZip -and $extension -eq '.zip' -and $bytes -le $MaximumBinaryEvidenceBytes) {
                $hash = Get-Sha256 $item.FullName
                $binaryCopied = $true
                $CopyCandidates.Add([pscustomobject]@{ sourceId = $sourceId; sourcePath = [string]$item.FullName; extension = '.zip'; bytes = $bytes; sha256 = $hash; kind = 'EXACT_EVIDENCE_ZIP' })
            }
            $rows.Add([pscustomobject]@{
                name = [string]$item.Name
                fullPath = [string]$item.FullName
                depth = $depth
                pathType = if ($isDirectory) { 'DIRECTORY' } else { 'FILE' }
                bytes = $bytes
                extension = $extension
                attributes = [string]$item.Attributes
                creationUtc = $item.CreationTimeUtc.ToString('o')
                lastWriteUtc = $item.LastWriteTimeUtc.ToString('o')
                sha256 = $hash
                safeTextOrSignatureContentRead = $contentRead
                exactEvidenceZipCopied = $binaryCopied
                imageBytesRead = $false
            })
            if ($isDirectory -and $depth -lt $maximumDepth) {
                $children = @(Get-ChildItem -LiteralPath $item.FullName -Force -ErrorAction Stop)
                foreach ($child in @($children | Sort-Object FullName)) { $queue.Enqueue([pscustomobject]@{ item = $child; depth = $depth + 1 }) }
            }
        }
        catch {
            $errors.Add([pscustomobject]@{ path = [string]$item.FullName; detail = $_.Exception.Message })
        }
    }
    return [pscustomobject]@{
        id = $sourceId
        root = $root
        selection = $selection
        matchText = if ($Source.PSObject.Properties.Name -contains 'matchText') { [string]$Source.matchText } else { '' }
        maximumDepth = $maximumDepth
        maximumRows = $maximumRows
        matchedStartCount = @($startItems).Count
        returnedRowCount = $rows.Count
        truncated = $truncated
        accessErrors = $errors.ToArray()
        rows = $rows.ToArray()
    }
}

function Get-TreeSummary {
    param([object]$Source, [bool]$IsRehearsal)
    $id = [string]$Source.id
    $root = [IO.Path]::GetFullPath([string]$Source.root).TrimEnd('\')
    Assert-True ($id -in @('CACHE', 'METADATA', 'DASHBOARD_OUTPUTS')) "JEO1 tree identity changed: $id"
    $maximumFiles = [int64]$Source.maximumFiles
    $maximumDirectories = [int64]$Source.maximumDirectories
    Assert-True ($maximumFiles -ge 1 -and $maximumFiles -le 250000) "JEO1 tree file bound changed: $id"
    Assert-True ($maximumDirectories -ge 1 -and $maximumDirectories -le 300000) "JEO1 tree directory bound changed: $id"
    if (-not $IsRehearsal) {
        $expected = [ordered]@{
            CACHE = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\cache'
            METADATA = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\metadata'
            DASHBOARD_OUTPUTS = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\dashboard_outputs'
        }
        Assert-True ($root.Equals([string]$expected[$id], [StringComparison]::OrdinalIgnoreCase)) "JEO1 tree root changed: $id"
    }
    $fileCount = [int64]0
    $directoryCount = [int64]0
    $logicalBytes = [int64]0
    $errors = New-Object Collections.Generic.List[object]
    $queue = New-Object Collections.Generic.Queue[string]
    $exists = Test-Path -LiteralPath $root -PathType Container
    if ($exists) { $queue.Enqueue($root) }
    $truncated = $false
    while ($queue.Count -gt 0) {
        $directory = $queue.Dequeue()
        $directoryCount++
        if ($directoryCount -gt $maximumDirectories) { $truncated = $true; break }
        try { $children = @(Get-ChildItem -LiteralPath $directory -Force -ErrorAction Stop) }
        catch { $errors.Add([pscustomobject]@{ path = $directory; detail = $_.Exception.Message }); continue }
        foreach ($child in $children) {
            if ([bool]$child.PSIsContainer) { $queue.Enqueue([string]$child.FullName); continue }
            $fileCount++
            $logicalBytes += [int64]$child.Length
            if ($fileCount -gt $maximumFiles) { $truncated = $true; break }
        }
        if ($truncated) { break }
    }
    return [pscustomobject]@{
        id = $id
        root = $root
        exists = [bool]$exists
        fileCount = $fileCount
        directoryCount = $directoryCount
        logicalBytes = $logicalBytes
        maximumFiles = $maximumFiles
        maximumDirectories = $maximumDirectories
        truncated = $truncated
        accessErrors = $errors.ToArray()
        imageBytesRead = $false
    }
}

function Get-TaskRows {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return @($Invocation.taskFixture) }
    $rows = New-Object Collections.Generic.List[object]
    foreach ($name in @($Invocation.taskNames)) {
        try {
            $task = Get-ScheduledTask -TaskName ([string]$name) -ErrorAction Stop
            $info = Get-ScheduledTaskInfo -TaskName ([string]$name) -ErrorAction Stop
            $definition = [string](Export-ScheduledTask -TaskName ([string]$name) -ErrorAction Stop)
            $rows.Add([pscustomobject]@{
                name = [string]$name; present = $true; state = [string]$task.State; principal = [string]$task.Principal.UserId
                actionCount = @($task.Actions).Count; actionExecutables = @($task.Actions | ForEach-Object { [string]$_.Execute })
                actionArguments = @($task.Actions | ForEach-Object { [string]$_.Arguments }); lastRunTime = $info.LastRunTime.ToUniversalTime().ToString('o')
                lastTaskResult = [int64]$info.LastTaskResult; nextRunTime = $info.NextRunTime.ToUniversalTime().ToString('o')
                numberOfMissedRuns = [int64]$info.NumberOfMissedRuns; definitionSha256 = Get-TextSha256 $definition; error = $null
            })
        }
        catch { $rows.Add([pscustomobject]@{ name = [string]$name; present = $false; error = $_.Exception.Message }) }
    }
    return $rows.ToArray()
}

function Get-ProcessRows {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return @($Invocation.processFixture) }
    $tokens = @([string]$Invocation.portalRoot, [string]$Invocation.processorRunnerPath)
    $maximumRows = [int]$Invocation.maximumProcessRows
    $rows = New-Object Collections.Generic.List[object]
    foreach ($process in @(Get-CimInstance -ClassName Win32_Process -ErrorAction Stop | Sort-Object ProcessId)) {
        $commandLine = [string]$process.CommandLine
        if ([string]::IsNullOrWhiteSpace($commandLine)) { continue }
        $matched = $false
        foreach ($token in $tokens) {
            if ($commandLine.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0) { $matched = $true; break }
        }
        if (-not $matched) { continue }
        if ($rows.Count -ge $maximumRows) { break }
        $rows.Add([pscustomobject]@{
            processId = [int64]$process.ProcessId; parentProcessId = [int64]$process.ParentProcessId; name = [string]$process.Name
            executablePath = [string]$process.ExecutablePath; commandLine = $commandLine; commandLineSha256 = Get-TextSha256 $commandLine
            creationDate = if ($null -ne $process.CreationDate) { ([DateTime]$process.CreationDate).ToUniversalTime().ToString('o') } else { $null }
        })
    }
    return $rows.ToArray()
}

function Get-DriveRows {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return @($Invocation.driveFixture) }
    $rows = @(
        Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction Stop |
        Where-Object { [string]$_.DeviceID -in @('C:', 'D:') } |
        Sort-Object DeviceID |
        ForEach-Object { [pscustomobject]@{ deviceId = [string]$_.DeviceID; volumeName = [string]$_.VolumeName; sizeBytes = [int64]$_.Size; freeBytes = [int64]$_.FreeSpace } }
    )
    return $rows
}

function Get-SubstRows {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return @($Invocation.substFixture) }
    $subst = Join-Path $env:SystemRoot 'System32\subst.exe'
    Assert-True (Test-Path -LiteralPath $subst -PathType Leaf) 'subst.exe is absent.'
    $lines = @(& $subst 2>$null)
    return @($lines | ForEach-Object { [string]$_ })
}

function Invoke-JEO1Preflight {
    param([object]$Invocation, [string]$PackageRoot, [bool]$IsRehearsal)
    if (-not $IsRehearsal) {
        foreach ($command in @('Get-ScheduledTask', 'Get-ScheduledTaskInfo', 'Export-ScheduledTask', 'Get-CimInstance')) {
            Assert-True ($null -ne (Get-Command $command -ErrorAction Stop)) "Required command is absent: $command"
        }
        foreach ($blocked in @($Invocation.refuseComputerNames)) {
            Assert-True (-not $env:COMPUTERNAME.Equals([string]$blocked, [StringComparison]::OrdinalIgnoreCase)) "JEO1 refuses this computer: $env:COMPUTERNAME"
        }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        Assert-True ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'JEO1 live observation requires an elevated administrator token.'
        $configPath = Join-Path ([string]$Invocation.portalRoot) 'config\endpoint_jbod.json'
        Assert-True (Test-Path -LiteralPath $configPath -PathType Leaf) 'JBOD endpoint config is absent; JEO1 refuses a non-JBOD host.'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        Assert-True ([string]$config.schema -eq 'argos_project_portal_endpoint_config_v1' -and [string]$config.role -eq 'JBOD') 'JEO1 endpoint config is not the JBOD role.'
        Assert-True ([bool]$config.reviewOnly -and -not [bool]$config.productionRoutingEnabled) 'JEO1 endpoint config safety flags changed.'
    }
    $outputRoot = [IO.Path]::GetFullPath([string]$Invocation.outputRoot).TrimEnd('\')
    $localZip = [IO.Path]::GetFullPath([string]$Invocation.localResultPath)
    $returnPath = [IO.Path]::GetFullPath([string]$Invocation.returnPath)
    Assert-True (-not (Test-Path -LiteralPath $outputRoot)) "JEO1 output root must be fresh: $outputRoot"
    Assert-True (-not (Test-Path -LiteralPath $localZip)) "JEO1 local result ZIP must be fresh: $localZip"
    Assert-True (-not (Test-Path -LiteralPath $returnPath)) "JEO1 return ZIP must be fresh: $returnPath"
    if (-not $IsRehearsal) {
        Assert-True ($outputRoot.Equals('D:\A2\x\JEO1', [StringComparison]::OrdinalIgnoreCase)) 'JEO1 live output root changed.'
        Assert-True ($localZip.Equals('D:\A2\x\JEO1R_LOCAL.zip', [StringComparison]::OrdinalIgnoreCase)) 'JEO1 live local result changed.'
        Assert-True ((Split-Path -Leaf $returnPath) -eq 'JEO1R.zip') 'JEO1 return leaf changed.'
        Assert-True (Test-Path -LiteralPath 'D:\A2\x' -PathType Container) 'JEO1 D-side evidence parent is absent.'
    }
    return [pscustomobject]@{
        schema = 'argos_jeo1_direct_admin_preflight_v1'; createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_PREFLIGHT'; computerName = $env:COMPUTERNAME; packageRoot = $PackageRoot
        outputRoot = $outputRoot; localResultZip = $localZip; returnPath = $returnPath; pathSourceCount = @($Invocation.pathSources).Count
        treeSourceCount = @($Invocation.treeSources).Count; targetExecuted = $false; mutationsPerformed = $false
        reviewOnly = $true; productionRoutingEnabled = $false
    }
}

$packageRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
[void](Verify-Package $packageRoot)
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Read-Invocation -Path $invocationPath -IsRehearsal ([bool]$Rehearsal)
$preflightResult = Invoke-JEO1Preflight -Invocation $invocation -PackageRoot $packageRoot -IsRehearsal ([bool]$Rehearsal)
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 12; return }

$outputRoot = [string]$preflightResult.outputRoot
$localResultZip = [string]$preflightResult.localResultZip
$returnPath = [string]$preflightResult.returnPath
[void](New-Item -ItemType Directory -Path $outputRoot)
$transcriptPath = Join-Path $outputRoot 'JEO1_TRANSCRIPT.log'
Start-Transcript -LiteralPath $transcriptPath -NoClobber | Out-Null
$runFailure = $null
$returnFailure = $null
$completed = $false
try {
    $copyCandidates = New-Object Collections.Generic.List[object]
    $sourceResults = New-Object Collections.Generic.List[object]
    foreach ($source in @($invocation.pathSources)) {
        $sourceResults.Add((Get-PathRows -Source $source -CopyCandidates $copyCandidates -MaximumSafeFileBytes ([int64]$invocation.maximumSafeFileBytes) -MaximumBinaryEvidenceBytes ([int64]$invocation.maximumBinaryEvidenceBytes)))
    }
    Assert-True ($copyCandidates.Count -le [int]$invocation.maximumCopyFiles) 'JEO1 evidence copy count exceeded its bound.'
    [int64]$copyBytes = 0
    foreach ($copyCandidate in $copyCandidates.ToArray()) { $copyBytes += [int64]$copyCandidate.bytes }
    Assert-True ($copyBytes -le [int64]$invocation.maximumCopyBytes) 'JEO1 evidence copy bytes exceeded its bound.'
    $copyRows = New-Object Collections.Generic.List[object]
    $copyIndex = 0
    foreach ($candidate in $copyCandidates.ToArray()) {
        $sourceFolder = Join-Path $outputRoot ('copies\' + [string]$candidate.sourceId)
        if (-not (Test-Path -LiteralPath $sourceFolder -PathType Container)) { [void](New-Item -ItemType Directory -Path $sourceFolder) }
        $leaf = 'F_{0:D3}_{1}{2}' -f $copyIndex, ([string]$candidate.sha256).Substring(0, 12), [string]$candidate.extension
        $destination = Join-Path $sourceFolder $leaf
        Assert-True (-not (Test-Path -LiteralPath $destination)) "JEO1 evidence destination collision: $destination"
        [IO.File]::Copy([string]$candidate.sourcePath, $destination, $false)
        Assert-True ((Get-Sha256 $destination) -eq [string]$candidate.sha256) "JEO1 evidence copy hash changed: $destination"
        $copyRows.Add([pscustomobject]@{ sourceId = [string]$candidate.sourceId; sourcePath = [string]$candidate.sourcePath; kind = [string]$candidate.kind; returnedRelativePath = $destination.Substring($outputRoot.TrimEnd('\').Length).TrimStart('\').Replace('\', '/'); bytes = [int64]$candidate.bytes; sha256 = [string]$candidate.sha256 })
        $copyIndex++
    }
    $treeResults = New-Object Collections.Generic.List[object]
    foreach ($tree in @($invocation.treeSources)) { $treeResults.Add((Get-TreeSummary -Source $tree -IsRehearsal ([bool]$Rehearsal))) }
    $taskRows = @(Get-TaskRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $processRows = @(Get-ProcessRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $driveRows = @(Get-DriveRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $substRows = @(Get-SubstRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $truncatedSources = @($sourceResults.ToArray() | Where-Object { [bool]$_.truncated })
    $truncatedTrees = @($treeResults.ToArray() | Where-Object { [bool]$_.truncated })
    $sourceAccessErrorCount = [int](($sourceResults.ToArray() | ForEach-Object { @($_.accessErrors).Count } | Measure-Object -Sum).Sum)
    $treeAccessErrorCount = [int](($treeResults.ToArray() | ForEach-Object { @($_.accessErrors).Count } | Measure-Object -Sum).Sum)
    $observationState = 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION'
    if ($truncatedSources.Count -gt 0 -or $truncatedTrees.Count -gt 0 -or $sourceAccessErrorCount -gt 0 -or $treeAccessErrorCount -gt 0) { $observationState = 'HOLD_JEO1_OBSERVATION_INCOMPLETE' }
    $observation = [ordered]@{
        schema = 'argos_jeo1_direct_admin_observation_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = $observationState
        incidentId = [string]$invocation.incidentId; requestId = [string]$invocation.requestId; expectedResponsePrefix = [string]$invocation.expectedResponsePrefix
        computerName = $env:COMPUTERNAME; userName = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        scriptPath = $MyInvocation.MyCommand.Path; scriptSha256 = Get-Sha256 $MyInvocation.MyCommand.Path; invocationManifestSha256 = Get-Sha256 $invocationPath
        driveFreeSpace = $driveRows; retiredTreeSummaries = $treeResults.ToArray(); sourceResults = $sourceResults.ToArray(); copiedEvidence = $copyRows.ToArray(); copiedEvidenceBytes = $copyBytes
        tasks = $taskRows; relevantProcesses = $processRows; substRows = $substRows; truncatedSourceCount = $truncatedSources.Count; truncatedTreeCount = $truncatedTrees.Count
        sourceAccessErrorCount = $sourceAccessErrorCount; treeAccessErrorCount = $treeAccessErrorCount
        targetMutationsPerformed = $false; evidenceOutputWritesOnly = $true; taskActionsPerformed = @(); processActionsPerformed = @()
        queueMutationPerformed = $false; ledgerMutationPerformed = $false; sourceMutationPerformed = $false; imageBytesRead = $false; waferActionPerformed = $false
        providerActivated = $false; inspectionTaskChanged = $false; reviewOnly = $true; productionRoutingEnabled = $false
    }
    $observationPath = Join-Path $outputRoot 'JEO1_OBSERVATION.json'
    Write-Utf8CreateNewJson -Path $observationPath -Value $observation -Depth 22
    Write-Output ([ordered]@{ state = [string]$observation.state; observationPath = $observationPath; copiedEvidenceCount = $copyRows.Count; retiredTreeCount = $treeResults.Count; taskCount = $taskRows.Count; processCount = $processRows.Count; targetMutationsPerformed = $false } | ConvertTo-Json -Depth 8)
    $completed = $true
}
catch {
    $runFailure = $_
    $failurePath = Join-Path $outputRoot 'JEO1_FAILURE.json'
    if (-not (Test-Path -LiteralPath $failurePath)) {
        Write-Utf8CreateNewJson -Path $failurePath -Value ([ordered]@{ schema = 'argos_jeo1_direct_admin_failure_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'FAIL_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION'; detail = $_.Exception.Message; scriptStack = $_.ScriptStackTrace; targetMutationsPerformed = $false; imageBytesRead = $false; reviewOnly = $true; productionRoutingEnabled = $false })
    }
}
finally { Stop-Transcript | Out-Null }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($outputRoot, $localResultZip, [IO.Compression.CompressionLevel]::Optimal, $false)
try {
    Assert-True (Test-Path -LiteralPath (Split-Path -Parent $returnPath) -PathType Container) 'JEO1 return root is unavailable.'
    [IO.File]::Copy($localResultZip, $returnPath, $false)
    Assert-True ((Get-Sha256 $returnPath) -eq (Get-Sha256 $localResultZip)) 'JEO1 returned ZIP hash changed.'
}
catch {
    $returnFailure = $_
    $returnFailurePath = Join-Path $outputRoot 'JEO1_RETURN_FAILURE.json'
    Write-Utf8CreateNewJson -Path $returnFailurePath -Value ([ordered]@{ schema = 'argos_jeo1_return_failure_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'FAIL_JEO1_EVIDENCE_RETURN'; detail = $_.Exception.Message; localResultZip = $localResultZip; intendedReturnPath = $returnPath; targetMutationsPerformed = $false; reviewOnly = $true; productionRoutingEnabled = $false })
    [IO.File]::Delete($localResultZip)
    [IO.Compression.ZipFile]::CreateFromDirectory($outputRoot, $localResultZip, [IO.Compression.CompressionLevel]::Optimal, $false)
}

if ($null -ne $runFailure) { throw $runFailure }
if ($null -ne $returnFailure) { throw $returnFailure }
Assert-True $completed 'JEO1 observation did not complete.'
[ordered]@{
    schema = 'argos_jeo1_direct_admin_return_v1'; createdUtc = [DateTime]::UtcNow.ToString('o'); state = 'PASS_JEO1_DIRECT_ADMIN_READ_ONLY_OBSERVATION_RETURNED'
    localResultZip = $localResultZip; returnPath = $returnPath; resultZipBytes = (Get-Item -LiteralPath $returnPath).Length; resultZipSha256 = Get-Sha256 $returnPath
    targetMutationsPerformed = $false; imageBytesRead = $false; reviewOnly = $true; productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8
