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
    param([string]$Path, [object]$Value, [int]$Depth = 16)
    Assert-True (-not (Test-Path -LiteralPath $Path)) "Create-new JSON path already exists: $Path"
    $json = $Value | ConvertTo-Json -Depth $Depth
    [IO.File]::WriteAllText($Path, $json + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
}

function Verify-Package {
    param([string]$Root)
    $manifestPath = Join-Path $Root 'PACKAGE_MANIFEST.json'
    Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'PACKAGE_MANIFEST.json is absent.'
    $package = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-True ([string]$package.schema -eq 'argos_o2a1_direct_admin_package_manifest_v1') 'O2A1 package schema changed.'
    Assert-True ([string]$package.revision -eq 'O2A1') 'O2A1 package revision changed.'
    Assert-True ([bool]$package.reviewOnly -and -not [bool]$package.productionRoutingEnabled) 'O2A1 package safety flags changed.'
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
    Assert-True ([string]$value.schema -eq 'argos_o2a1_direct_admin_invocation_v1') 'O2A1 invocation schema changed.'
    Assert-True ([bool]$value.rehearsal -eq $IsRehearsal) 'O2A1 invocation rehearsal mode changed.'
    Assert-True ([bool]$value.reviewOnly -and -not [bool]$value.productionRoutingEnabled) 'O2A1 invocation safety flags changed.'
    Assert-True ([string]$value.incidentId -eq 'OCV02_O2D4_TERMINAL_STATE_20260825') 'O2A1 incident identity changed.'
    Assert-True ([string]$value.requestId -eq 'REQ_O2D4') 'O2A1 request identity changed.'
    Assert-True ([string]$value.expectedResponsePrefix -eq 'R_A2A87054A416_') 'O2A1 response prefix changed.'
    Assert-True (@($value.pathSources).Count -ge 1 -and @($value.pathSources).Count -le 32) 'O2A1 path-source count is outside 1..32.'
    return $value
}

function Test-SafeEvidenceExtension {
    param([string]$Extension)
    return $Extension.ToLowerInvariant() -in @('.json', '.txt', '.log', '.sig', '.ps1', '.cmd')
}

function Get-PathRows {
    param(
        [object]$Source,
        [Collections.Generic.List[object]]$CopyCandidates,
        [int64]$MaximumSafeFileBytes
    )
    $sourceId = [string]$Source.id
    Assert-True ($sourceId -match '^[A-Z0-9_]{1,32}$') "Unsafe O2A1 source id: $sourceId"
    $rootText = [string]$Source.root
    Assert-True (-not [string]::IsNullOrWhiteSpace($rootText)) "O2A1 source root is empty: $sourceId"
    Assert-True ($rootText.IndexOfAny([char[]]'*?') -lt 0) "O2A1 source root contains a wildcard: $sourceId"
    Assert-True ([IO.Path]::IsPathRooted($rootText)) "O2A1 source root is not absolute: $sourceId"
    $root = [IO.Path]::GetFullPath($rootText).TrimEnd('\')
    $selection = [string]$Source.selection
    Assert-True ($selection -in @('EXACT_PATH', 'CHILD_NAME_EXACT', 'CHILD_NAME_PREFIX')) "O2A1 source selection changed: $sourceId"
    $maximumDepth = [int]$Source.maximumDepth
    $maximumRows = [int]$Source.maximumRows
    Assert-True ($maximumDepth -ge 0 -and $maximumDepth -le 8) "O2A1 source depth is outside 0..8: $sourceId"
    Assert-True ($maximumRows -ge 1 -and $maximumRows -le 1000) "O2A1 source row bound is outside 1..1000: $sourceId"
    $copySafe = [bool]$Source.copySafeEvidence
    $rows = New-Object Collections.Generic.List[object]
    $errors = New-Object Collections.Generic.List[object]
    $queue = New-Object Collections.Generic.Queue[object]
    $startItems = @()
    if ($selection -eq 'EXACT_PATH') {
        if (Test-Path -LiteralPath $root) { $startItems = @((Get-Item -LiteralPath $root -Force -ErrorAction Stop)) }
    }
    else {
        if (Test-Path -LiteralPath $root -PathType Container) {
            $matchText = [string]$Source.matchText
            Assert-True (-not [string]::IsNullOrWhiteSpace($matchText)) "O2A1 child match is empty: $sourceId"
            $children = @(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop)
            if ($selection -eq 'CHILD_NAME_EXACT') {
                $startItems = @($children | Where-Object { [string]$_.Name -eq $matchText })
            }
            else {
                $startItems = @($children | Where-Object { ([string]$_.Name).StartsWith($matchText, [StringComparison]::OrdinalIgnoreCase) })
            }
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
            $extension = if ($isDirectory) { '' } else { [IO.Path]::GetExtension([string]$item.Name).ToLowerInvariant() }
            $safeContentType = (-not $isDirectory) -and (Test-SafeEvidenceExtension $extension)
            $bytes = if ($isDirectory) { $null } else { [int64]$item.Length }
            $hash = $null
            $contentRead = $false
            if ($safeContentType -and $bytes -le $MaximumSafeFileBytes) {
                $hash = Get-Sha256 $item.FullName
                $contentRead = $true
                if ($copySafe) {
                    $CopyCandidates.Add([pscustomobject]@{ sourceId = $sourceId; sourcePath = [string]$item.FullName; extension = $extension; bytes = $bytes; sha256 = $hash })
                }
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
                name = [string]$name
                present = $true
                state = [string]$task.State
                principal = [string]$task.Principal.UserId
                actionCount = @($task.Actions).Count
                actionExecutables = @($task.Actions | ForEach-Object { [string]$_.Execute })
                actionArguments = @($task.Actions | ForEach-Object { [string]$_.Arguments })
                lastRunTime = $info.LastRunTime.ToUniversalTime().ToString('o')
                lastTaskResult = [int64]$info.LastTaskResult
                nextRunTime = $info.NextRunTime.ToUniversalTime().ToString('o')
                numberOfMissedRuns = [int64]$info.NumberOfMissedRuns
                definitionSha256 = Get-TextSha256 $definition
                error = $null
            })
        }
        catch {
            $rows.Add([pscustomobject]@{ name = [string]$name; present = $false; error = $_.Exception.Message })
        }
    }
    return $rows.ToArray()
}

function Get-ProcessRows {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return @($Invocation.processFixture) }
    $portalToken = [string]$Invocation.portalRoot
    $maximumRows = [int]$Invocation.maximumProcessRows
    $rows = @(
        Get-CimInstance -ClassName Win32_Process -ErrorAction Stop |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and ([string]$_.CommandLine).IndexOf($portalToken, [StringComparison]::OrdinalIgnoreCase) -ge 0 } |
        Sort-Object ProcessId |
        Select-Object -First $maximumRows |
        ForEach-Object {
            [pscustomobject]@{
                processId = [int64]$_.ProcessId
                parentProcessId = [int64]$_.ParentProcessId
                name = [string]$_.Name
                executablePath = [string]$_.ExecutablePath
                commandLine = [string]$_.CommandLine
                creationDate = if ($null -ne $_.CreationDate) { ([DateTime]$_.CreationDate).ToUniversalTime().ToString('o') } else { $null }
            }
        }
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

function Invoke-O2A1Preflight {
    param([object]$Invocation, [string]$PackageRoot, [bool]$IsRehearsal)
    foreach ($command in @('Get-ScheduledTask', 'Get-ScheduledTaskInfo', 'Export-ScheduledTask', 'Get-CimInstance')) {
        if (-not $IsRehearsal) { Assert-True ($null -ne (Get-Command $command -ErrorAction Stop)) "Required command is absent: $command" }
    }
    if (-not $IsRehearsal) {
        foreach ($blocked in @($Invocation.refuseComputerNames)) {
            Assert-True (-not $env:COMPUTERNAME.Equals([string]$blocked, [StringComparison]::OrdinalIgnoreCase)) "O2A1 refuses this computer: $env:COMPUTERNAME"
        }
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        Assert-True ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'O2A1 live observation requires an elevated administrator token.'
        $configPath = Join-Path ([string]$Invocation.portalRoot) 'config\endpoint_jbod.json'
        Assert-True (Test-Path -LiteralPath $configPath -PathType Leaf) 'JBOD endpoint config is absent; O2A1 refuses a non-JBOD host.'
        $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        Assert-True ([string]$config.schema -eq 'argos_project_portal_endpoint_config_v1' -and [string]$config.role -eq 'JBOD') 'O2A1 endpoint config is not the JBOD role.'
        Assert-True ([bool]$config.reviewOnly -and -not [bool]$config.productionRoutingEnabled) 'O2A1 endpoint config safety flags changed.'
    }
    $outputRoot = [IO.Path]::GetFullPath([string]$Invocation.outputRoot).TrimEnd('\')
    $localZip = Join-Path $PackageRoot ([string]$Invocation.localResultLeaf)
    $returnPath = [IO.Path]::GetFullPath([string]$Invocation.returnPath)
    Assert-True (-not (Test-Path -LiteralPath $outputRoot)) "O2A1 output root must be fresh: $outputRoot"
    Assert-True (-not (Test-Path -LiteralPath $localZip)) "O2A1 local result ZIP must be fresh: $localZip"
    Assert-True (-not (Test-Path -LiteralPath $returnPath)) "O2A1 return ZIP must be fresh: $returnPath"
    Assert-True (Test-Path -LiteralPath (Split-Path -Parent $returnPath) -PathType Container) 'O2A1 return root is unavailable.'
    Assert-True ([string]$Invocation.localResultLeaf -eq 'O2A1R_LOCAL.zip') 'O2A1 local result leaf changed.'
    Assert-True ((Split-Path -Leaf $returnPath) -eq 'O2A1R.zip') 'O2A1 return leaf changed.'
    return [pscustomobject]@{
        schema = 'argos_o2a1_direct_admin_preflight_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_O2A1_DIRECT_ADMIN_READ_ONLY_PREFLIGHT'
        computerName = $env:COMPUTERNAME
        packageRoot = $PackageRoot
        outputRoot = $outputRoot
        localResultZip = $localZip
        returnPath = $returnPath
        pathSourceCount = @($Invocation.pathSources).Count
        targetExecuted = $false
        mutationsPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
}

$packageRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\')
[void](Verify-Package $packageRoot)
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Read-Invocation -Path $invocationPath -IsRehearsal ([bool]$Rehearsal)
$preflightResult = Invoke-O2A1Preflight -Invocation $invocation -PackageRoot $packageRoot -IsRehearsal ([bool]$Rehearsal)
if ($Preflight) {
    $preflightResult | ConvertTo-Json -Depth 12
    return
}

$outputRoot = [string]$preflightResult.outputRoot
$localResultZip = [string]$preflightResult.localResultZip
$returnPath = [string]$preflightResult.returnPath
[void](New-Item -ItemType Directory -Path $outputRoot)
$transcriptPath = Join-Path $outputRoot 'O2A1_TRANSCRIPT.log'
Start-Transcript -LiteralPath $transcriptPath -NoClobber | Out-Null
$completed = $false
try {
    $copyCandidates = New-Object Collections.Generic.List[object]
    $sourceResults = New-Object Collections.Generic.List[object]
    foreach ($source in @($invocation.pathSources)) {
        $sourceResults.Add((Get-PathRows -Source $source -CopyCandidates $copyCandidates -MaximumSafeFileBytes ([int64]$invocation.maximumSafeFileBytes)))
    }
    Assert-True ($copyCandidates.Count -le [int]$invocation.maximumCopyFiles) 'O2A1 safe-evidence copy count exceeded its bound.'
    $copyBytes = [int64](($copyCandidates.ToArray() | Measure-Object -Property bytes -Sum).Sum)
    Assert-True ($copyBytes -le [int64]$invocation.maximumCopyBytes) 'O2A1 safe-evidence copy bytes exceeded its bound.'
    $copyRows = New-Object Collections.Generic.List[object]
    $copyIndex = 0
    foreach ($candidate in $copyCandidates.ToArray()) {
        $sourceFolder = Join-Path $outputRoot ('copies\' + [string]$candidate.sourceId)
        if (-not (Test-Path -LiteralPath $sourceFolder -PathType Container)) { [void](New-Item -ItemType Directory -Path $sourceFolder) }
        $leaf = 'F_{0:D3}_{1}{2}' -f $copyIndex, ([string]$candidate.sha256).Substring(0, 12), [string]$candidate.extension
        $destination = Join-Path $sourceFolder $leaf
        Assert-True (-not (Test-Path -LiteralPath $destination)) "O2A1 evidence destination collision: $destination"
        [IO.File]::Copy([string]$candidate.sourcePath, $destination, $false)
        Assert-True ((Get-Sha256 $destination) -eq [string]$candidate.sha256) "O2A1 evidence copy hash changed: $destination"
        $copyRows.Add([pscustomobject]@{
            sourceId = [string]$candidate.sourceId
            sourcePath = [string]$candidate.sourcePath
            returnedRelativePath = $destination.Substring($outputRoot.TrimEnd('\').Length).TrimStart('\').Replace('\', '/')
            bytes = [int64]$candidate.bytes
            sha256 = [string]$candidate.sha256
        })
        $copyIndex++
    }
    $taskRows = @(Get-TaskRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $processRows = @(Get-ProcessRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $substRows = @(Get-SubstRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $truncatedSources = @($sourceResults.ToArray() | Where-Object { [bool]$_.truncated })
    $accessErrorCount = [int](($sourceResults.ToArray() | ForEach-Object { @($_.accessErrors).Count } | Measure-Object -Sum).Sum)
    $observation = [ordered]@{
        schema = 'argos_o2a1_direct_admin_observation_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = if ($truncatedSources.Count -eq 0 -and $accessErrorCount -eq 0) { 'PASS_O2A1_DIRECT_ADMIN_READ_ONLY_OBSERVATION' } else { 'HOLD_O2A1_OBSERVATION_INCOMPLETE' }
        incidentId = [string]$invocation.incidentId
        requestId = [string]$invocation.requestId
        expectedResponsePrefix = [string]$invocation.expectedResponsePrefix
        computerName = $env:COMPUTERNAME
        userName = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        scriptPath = $MyInvocation.MyCommand.Path
        scriptSha256 = Get-Sha256 $MyInvocation.MyCommand.Path
        invocationManifestSha256 = Get-Sha256 $invocationPath
        sourceResults = $sourceResults.ToArray()
        copiedEvidence = $copyRows.ToArray()
        copiedEvidenceBytes = $copyBytes
        tasks = $taskRows
        portalProcesses = $processRows
        substRows = $substRows
        truncatedSourceCount = $truncatedSources.Count
        accessErrorCount = $accessErrorCount
        targetMutationsPerformed = $false
        evidenceOutputWritesOnly = $true
        taskActionsPerformed = @()
        processActionsPerformed = @()
        queueMutationPerformed = $false
        ledgerMutationPerformed = $false
        sourceMutationPerformed = $false
        imageBytesRead = $false
        waferActionPerformed = $false
        providerActivated = $false
        inspectionTaskChanged = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    $observationPath = Join-Path $outputRoot 'O2A1_OBSERVATION.json'
    Write-Utf8CreateNewJson -Path $observationPath -Value $observation -Depth 18
    Write-Output ([ordered]@{ state = [string]$observation.state; observationPath = $observationPath; copiedEvidenceCount = $copyRows.Count; taskCount = $taskRows.Count; processCount = $processRows.Count; targetMutationsPerformed = $false } | ConvertTo-Json -Depth 6)
    $completed = $true
}
catch {
    $failurePath = Join-Path $outputRoot 'O2A1_FAILURE.json'
    if (-not (Test-Path -LiteralPath $failurePath)) {
        Write-Utf8CreateNewJson -Path $failurePath -Value ([ordered]@{
            schema = 'argos_o2a1_direct_admin_failure_v1'
            createdUtc = [DateTime]::UtcNow.ToString('o')
            state = 'FAIL_O2A1_DIRECT_ADMIN_READ_ONLY_OBSERVATION'
            detail = $_.Exception.Message
            scriptStack = $_.ScriptStackTrace
            targetMutationsPerformed = $false
            imageBytesRead = $false
            reviewOnly = $true
            productionRoutingEnabled = $false
        })
    }
    throw
}
finally {
    Stop-Transcript | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path -LiteralPath $localResultZip)) {
        [IO.Compression.ZipFile]::CreateFromDirectory($outputRoot, $localResultZip, [IO.Compression.CompressionLevel]::Optimal, $false)
    }
    if (-not (Test-Path -LiteralPath $returnPath)) {
        [IO.File]::Copy($localResultZip, $returnPath, $false)
    }
    if (Test-Path -LiteralPath $returnPath -PathType Leaf) {
        Assert-True ((Get-Sha256 $returnPath) -eq (Get-Sha256 $localResultZip)) 'O2A1 returned ZIP hash changed.'
    }
}

Assert-True $completed 'O2A1 observation did not complete.'
[ordered]@{
    schema = 'argos_o2a1_direct_admin_return_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_O2A1_DIRECT_ADMIN_READ_ONLY_OBSERVATION_RETURNED'
    localResultZip = $localResultZip
    returnPath = $returnPath
    resultZipBytes = (Get-Item -LiteralPath $returnPath).Length
    resultZipSha256 = Get-Sha256 $returnPath
    targetMutationsPerformed = $false
    imageBytesRead = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
} | ConvertTo-Json -Depth 8

