[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-OptionalValue {
    param([AllowNull()][object]$Object, [string]$Name, [AllowNull()][object]$Default = $null)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name) { return $Object.$Name }
    return $Default
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead([IO.Path]::GetFullPath($Path))
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

function Get-NormalizedDirectoryPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $root = [IO.Path]::GetPathRoot($full)
    if ($full.Equals($root,[StringComparison]::OrdinalIgnoreCase)) { return $root }
    return $full.TrimEnd('\')
}

function Write-Utf8CreateNewJson {
    param([string]$Path, [object]$Value, [int]$Depth = 16)
    $json = $Value | ConvertTo-Json -Depth $Depth
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}

function Verify-Package {
    param([string]$PackageRoot)
    $manifestPath = Join-Path $PackageRoot 'PACKAGE_MANIFEST.json'
    Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'CDM1 package manifest is absent.'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Assert-True ([string]$manifest.schema -eq 'argos_cdm1_package_manifest_v1') 'CDM1 package manifest schema changed.'
    Assert-True ([string]$manifest.revision -eq 'CDM1') 'CDM1 package revision changed.'
    Assert-True ([string]$manifest.lifecycle -eq 'FROZEN') 'CDM1 package is not frozen.'
    Assert-True ([string]$manifest.authorization.gateSha256 -eq '7FF20EE1C6FADBF6617836AAD96B69F8B0D73083856B9C952E57C6DA49D9EB6A') 'CDM1 authorization gate hash changed.'
    Assert-True ([bool]$manifest.authorization.singleAttemptAuthorized -and [bool]$manifest.authorization.exactSourceDeletionAuthorized -and -not [bool]$manifest.authorization.historicalOutputDeletionAuthorized) 'CDM1 authorization boundary changed.'
    Assert-True ([int64]$manifest.expectedDeletion.files -eq 93709 -and [int64]$manifest.expectedDeletion.logicalBytes -eq 232912232897 -and [int]$manifest.expectedDeletion.sourceRoots -eq 3 -and [int]$manifest.expectedDeletion.mirrorRoots -eq 3) 'CDM1 manifest deletion boundary changed.'
    Assert-True ([bool]$manifest.safety.historicalOutputRootExcluded -and -not [bool]$manifest.safety.broadCDriveCleanup -and [bool]$manifest.safety.reviewOnly -and -not [bool]$manifest.safety.productionRoutingEnabled) 'CDM1 manifest safety boundary changed.'
    Assert-True (@($manifest.safety.taskActions).Count -eq 0 -and @($manifest.safety.processActions).Count -eq 0 -and @($manifest.safety.installedChanges).Count -eq 0) 'CDM1 package declares a forbidden task, process, or installed-file action.'
    Assert-True (-not [bool]$manifest.safety.queueMutation -and -not [bool]$manifest.safety.ledgerMutation -and -not [bool]$manifest.safety.waferAction -and -not [bool]$manifest.safety.imageBytesDecoded) 'CDM1 package declares a forbidden non-delete action.'
    Assert-True (@($manifest.files).Count -eq 4) 'CDM1 package file count changed.'
    foreach ($entry in @($manifest.files)) {
        $relative = [string]$entry.path
        Assert-True (-not [IO.Path]::IsPathRooted($relative) -and $relative -notmatch '(^|[\\/])\.\.([\\/]|$)') "Unsafe CDM1 package path: $relative"
        $path = [IO.Path]::GetFullPath((Join-Path $PackageRoot $relative))
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "CDM1 package file is absent: $relative"
        Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$entry.bytes) "CDM1 package length changed: $relative"
        Assert-True ((Get-Sha256 $path) -eq [string]$entry.sha256) "CDM1 package hash changed: $relative"
    }
    return $manifest
}

function Read-Invocation {
    param([string]$Path, [bool]$IsRehearsal)
    $full = [IO.Path]::GetFullPath($Path)
    Assert-True (Test-Path -LiteralPath $full -PathType Leaf) 'CDM1 invocation manifest is absent.'
    Assert-True ((Get-Item -LiteralPath $full).Length -le 1048576) 'CDM1 invocation manifest exceeds 1 MiB.'
    $value = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json
    Assert-True ([string]$value.schema -eq 'argos_cdm1_direct_admin_delete_invocation_v1') 'CDM1 invocation schema changed.'
    Assert-True ([bool]$value.rehearsal -eq $IsRehearsal) 'CDM1 invocation rehearsal mode changed.'
    Assert-True ([bool]$value.reviewOnly -and -not [bool]$value.productionRoutingEnabled) 'CDM1 authority flags changed.'
    Assert-True ([bool]$value.deletionAuthorized -and [bool]$value.singleAttemptAuthorized) 'CDM1 exact deletion authority is absent.'
    Assert-True (@($value.trees).Count -eq 3) 'CDM1 tree set changed.'
    if (-not $IsRehearsal) {
        Assert-True ([int64]$value.expectedFiles -eq 93709 -and [int64]$value.expectedLogicalBytes -eq 232912232897) 'CDM1 aggregate deletion boundary changed.'
        Assert-True ([string]$value.incidentId -eq 'JBOD_C_DRIVE_FULL_20260825') 'CDM1 incident identity changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.processorConfigPath).Equals('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\PROCESSOR_CONFIG.json',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 processor config path changed.'
        Assert-True ([string]$value.expectedProcessorConfigSha256 -eq 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8') 'CDM1 processor config hash premise changed.'
        Assert-True ([string]$value.processorTaskName -eq 'ArgosEdgeLab.AllWaferProcessor.ReviewOnly.V2') 'CDM1 processor task changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.processorRunnerPath).Equals('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\Run-JbodAllWaferProcessor.ps1',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 processor runner changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.lockedManifestPath).Equals('D:\A2\x\manifests\M1_20260819T172439962Z.jsonl',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 locked manifest path changed.'
        Assert-True ([string]$value.lockedManifestSha256 -eq '5C42EFF1431867076DC3F3DEE15FA0FB20A0B0C204C2AA38B5E5BDBCD0806DEB') 'CDM1 locked manifest hash changed.'
        Assert-True ([int64]$value.maximumManifestBytes -eq 268435456 -and [int64]$value.maximumSourceDirectories -eq 300000 -and [int]$value.maximumVerificationSeconds -eq 21600 -and [int]$value.maximumDeleteErrors -eq 128) 'CDM1 execution bounds changed.'
        $expectedTrees = @(
            [pscustomobject]@{name='cache';source='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\cache';destination='D:\A2\c';files=1444;bytes=83174610824},
            [pscustomobject]@{name='metadata';source='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\metadata';destination='D:\A2\m';files=92021;bytes=149443376410},
            [pscustomobject]@{name='dashboard_outputs';source='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\dashboard_outputs';destination='D:\A2\d';files=244;bytes=294245663}
        )
        foreach ($expectedTree in $expectedTrees) {
            $actualTrees = @($value.trees | Where-Object { [string]$_.name -eq [string]$expectedTree.name })
            Assert-True ($actualTrees.Count -eq 1) "CDM1 exact tree identity changed: $($expectedTree.name)"
            $actualTree = $actualTrees[0]
            Assert-True ([IO.Path]::GetFullPath([string]$actualTree.source).Equals([string]$expectedTree.source,[StringComparison]::OrdinalIgnoreCase)) "CDM1 exact source root changed: $($expectedTree.name)"
            Assert-True ([IO.Path]::GetFullPath([string]$actualTree.destination).Equals([string]$expectedTree.destination,[StringComparison]::OrdinalIgnoreCase)) "CDM1 exact D mirror root changed: $($expectedTree.name)"
            Assert-True ([int64]$actualTree.expectedFiles -eq [int64]$expectedTree.files -and [int64]$actualTree.expectedLogicalBytes -eq [int64]$expectedTree.bytes) "CDM1 exact tree totals changed: $($expectedTree.name)"
        }
        Assert-True ([IO.Path]::GetFullPath([string]$value.historicalOutputRoot).Equals('C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2\outputs',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 excluded historical output root changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.tempRoot).Equals('D:\A2\x',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 temp root changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.outputRoot).Equals('D:\A2\x\CDM1',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 evidence root changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.localResultPath).Equals('D:\A2\x\CDM1R_LOCAL.zip',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 local result path changed.'
        Assert-True ([IO.Path]::GetFullPath([string]$value.returnPath).Equals('\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs\CDM1R.zip',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 return path changed.'
        $refusedNames = @($value.refuseComputerNames)
        Assert-True ($refusedNames.Count -eq 1 -and [string]$refusedNames[0] -eq 'TXSH-LUPW0JLTPR') 'CDM1 laptop refusal identity changed.'
        Assert-True ($null -eq $value.processorSnapshotFixture -and @($value.driveFixture).Count -eq 0) 'CDM1 production invocation contains rehearsal fixtures.'
    } else {
        Assert-True ([int64]$value.expectedFiles -ge 1 -and [int64]$value.expectedFiles -le 100) 'CDM1 rehearsal file bound changed.'
        Assert-True ([int64]$value.expectedLogicalBytes -ge 1 -and [int64]$value.expectedLogicalBytes -le 1048576) 'CDM1 rehearsal byte bound changed.'
    }
    return $value
}

function Get-SafeRelative {
    param([string]$Relative)
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative) -or $Relative.Replace('/','\') -match '(^|\\)\.\.(\\|$)') { throw "CDM1 unsafe relative path: $Relative" }
    return $Relative.Replace('/','\')
}

function Get-Key {
    param([string]$Tree, [string]$Relative)
    return $Tree + '|' + (Get-SafeRelative $Relative)
}

function Get-ExpectedPath {
    param([string]$Root, [string]$Relative)
    $rootFull = Get-NormalizedDirectoryPath $Root
    $expected = [IO.Path]::GetFullPath((Join-Path $rootFull (Get-SafeRelative $Relative)))
    Assert-True ($expected.StartsWith($rootFull + '\',[StringComparison]::OrdinalIgnoreCase)) "CDM1 path escapes root: $Relative"
    return $expected
}

function Get-TreeMapping {
    param([object]$Invocation, [string]$Name)
    $rows = @($Invocation.trees | Where-Object { [string]$_.name -eq $Name })
    Assert-True ($rows.Count -eq 1) "CDM1 tree mapping is not unique: $Name"
    return $rows[0]
}

function Convert-CreationUtc {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [DateTime]) { return ([DateTime]$Value).ToUniversalTime().ToString('o') }
    $text = [string]$Value
    if ($text -match '^\d{14}\.\d{6}[+-]\d{3}$') {
        try { return [Management.ManagementDateTimeConverter]::ToDateTime($text).ToUniversalTime().ToString('o') }
        catch { return '' }
    }
    $parsed = [DateTimeOffset]::MinValue
    if ([DateTimeOffset]::TryParse($text,[ref]$parsed)) { return $parsed.UtcDateTime.ToString('o') }
    return ''
}

function Get-ProcessorSnapshot {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return $Invocation.processorSnapshotFixture }
    $task = Get-ScheduledTask -TaskName ([string]$Invocation.processorTaskName) -ErrorAction Stop
    $taskInfo = Get-ScheduledTaskInfo -TaskName ([string]$Invocation.processorTaskName) -ErrorAction Stop
    $runner = [IO.Path]::GetFullPath([string]$Invocation.processorRunnerPath)
    $selectedList = New-Object 'Collections.Generic.List[object]'
    foreach ($candidateProcess in @(Get-CimInstance Win32_Process -ErrorAction Stop)) {
        if ([string]$candidateProcess.Name -ine 'powershell.exe') { continue }
        if ([string]::IsNullOrWhiteSpace([string]$candidateProcess.CommandLine)) { continue }
        if (([string]$candidateProcess.CommandLine).IndexOf($runner,[StringComparison]::OrdinalIgnoreCase) -ge 0) { $selectedList.Add($candidateProcess) }
    }
    $selected = @($selectedList.ToArray())
    Assert-True ($selected.Count -eq 1) "CDM1 requires exactly one healthy processor process; observed $($selected.Count)."
    $processRows = New-Object 'Collections.Generic.List[object]'
    foreach ($process in $selected) {
        $commandLine = [string]$process.CommandLine
        $processRows.Add([pscustomobject]@{
            processId = [int]$process.ProcessId
            parentProcessId = [int]$process.ParentProcessId
            creationUtc = Convert-CreationUtc $process.CreationDate
            executablePath = [string](Get-OptionalValue $process 'ExecutablePath' '')
            commandLineSha256 = Get-TextSha256 $commandLine
            commandLineLength = $commandLine.Length
        })
    }
    return [pscustomobject]@{
        taskName = [string]$task.TaskName
        taskState = [string]$task.State
        taskLastRunUtc = $taskInfo.LastRunTime.ToUniversalTime().ToString('o')
        taskLastResult = [int]$taskInfo.LastTaskResult
        processes = $processRows.ToArray()
    }
}

function Assert-ProcessorUnchanged {
    param([object]$Before, [object]$After)
    Assert-True ([string]$Before.taskName -eq [string]$After.taskName) 'CDM1 processor task identity changed.'
    $beforeRows = @($Before.processes | Sort-Object processId)
    $afterRows = @($After.processes | Sort-Object processId)
    Assert-True ($beforeRows.Count -eq 1 -and $afterRows.Count -eq 1) 'CDM1 processor singleton changed.'
    Assert-True ([int]$beforeRows[0].processId -eq [int]$afterRows[0].processId) 'CDM1 processor PID changed.'
    Assert-True ([string]$beforeRows[0].creationUtc -eq [string]$afterRows[0].creationUtc) 'CDM1 processor creation time changed.'
    Assert-True ([string]$beforeRows[0].commandLineSha256 -eq [string]$afterRows[0].commandLineSha256) 'CDM1 processor command line changed.'
}

function Assert-InstalledConfig {
    param([object]$Invocation)
    $path = [IO.Path]::GetFullPath([string]$Invocation.processorConfigPath)
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'CDM1 installed processor config is absent.'
    $hash = Get-Sha256 $path
    Assert-True ($hash -eq [string]$Invocation.expectedProcessorConfigSha256) "CDM1 installed processor config hash changed: $hash"
    $config = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    Assert-True ([string]$config.schema -eq 'argos_jbod_all_wafer_processor_config_v3') 'CDM1 processor config schema changed.'
    Assert-True ([bool]$config.reviewOnly -and -not [bool]$config.xmlExportEnabled) 'CDM1 processor review-only safety flags changed.'
    Assert-True (-not [bool](Get-OptionalValue $config 'productionRoutingEnabled' $false)) 'CDM1 refuses production routing.'
    Assert-True ([string]$config.outputRoot -eq 'D:\A2\o') 'CDM1 active output root changed.'
    Assert-True ([string]$config.dashboardOutputRoot -eq 'D:\A2\d') 'CDM1 active dashboard root changed.'
    Assert-True ([string]$config.cacheRoot -eq 'D:\A2\c') 'CDM1 active cache root changed.'
    Assert-True ([string]$config.metadataSnapshotRoot -eq 'D:\A2\m\verified') 'CDM1 active metadata root changed.'
    return $hash
}

function Read-LockedManifest {
    param([object]$Invocation)
    $path = [IO.Path]::GetFullPath([string]$Invocation.lockedManifestPath)
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) 'CDM1 locked final-delta manifest is absent.'
    Assert-True ((Get-Item -LiteralPath $path).Length -le [int64]$Invocation.maximumManifestBytes) 'CDM1 locked manifest exceeds its byte bound.'
    Assert-True ((Get-Sha256 $path) -eq [string]$Invocation.lockedManifestSha256) 'CDM1 locked manifest hash changed.'
    $records = New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    $reader = New-Object IO.StreamReader($path,(New-Object Text.UTF8Encoding($false,$true)))
    [int64]$bytes = 0
    try {
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            Assert-True (-not [string]::IsNullOrWhiteSpace($line)) 'CDM1 locked manifest contains an empty record.'
            $row = $line | ConvertFrom-Json
            $treeName = [string]$row.tree
            $mapping = Get-TreeMapping -Invocation $Invocation -Name $treeName
            $relative = Get-SafeRelative ([string]$row.relative)
            $key = Get-Key -Tree $treeName -Relative $relative
            Assert-True (-not $records.ContainsKey($key)) "CDM1 duplicate locked-manifest key: $key"
            Assert-True ([string]$row.sha256 -match '^[A-Fa-f0-9]{64}$') "CDM1 invalid locked hash: $key"
            Assert-True ([string]$row.state -in @('COPIED_HASH_VERIFIED','VERIFIED_EXISTING')) "CDM1 invalid locked row state: $key"
            $expectedSource = Get-ExpectedPath -Root ([string]$mapping.source) -Relative $relative
            $expectedDestination = Get-ExpectedPath -Root ([string]$mapping.destination) -Relative $relative
            Assert-True ([IO.Path]::GetFullPath([string]$row.source).Equals($expectedSource,[StringComparison]::OrdinalIgnoreCase)) "CDM1 locked source path changed: $key"
            Assert-True ([IO.Path]::GetFullPath([string]$row.destination).Equals($expectedDestination,[StringComparison]::OrdinalIgnoreCase)) "CDM1 locked destination path changed: $key"
            [void]$records.Add($key,$row)
            $bytes += [int64]$row.bytes
        }
    } finally { $reader.Dispose() }
    Assert-True ($records.Count -eq [int64]$Invocation.expectedFiles) 'CDM1 locked manifest file count changed.'
    Assert-True ($bytes -eq [int64]$Invocation.expectedLogicalBytes) 'CDM1 locked manifest logical bytes changed.'
    return $records
}

function Test-SourceTrees {
    param([object]$Invocation, [object]$Records)
    $visited = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $summaryRows = New-Object 'Collections.Generic.List[object]'
    [int64]$aggregateFiles = 0
    [int64]$aggregateBytes = 0
    foreach ($mapping in @($Invocation.trees)) {
        $root = Get-NormalizedDirectoryPath ([string]$mapping.source)
        Assert-True (Test-Path -LiteralPath $root -PathType Container) "CDM1 retired source root is absent: $root"
        $rootItem = Get-Item -LiteralPath $root -Force
        Assert-True (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "CDM1 retired source root is a reparse point: $root"
        $stack = New-Object 'Collections.Generic.Stack[string]'
        $stack.Push($root)
        [int64]$files = 0
        [int64]$bytes = 0
        [int64]$directories = 0
        while ($stack.Count -gt 0) {
            $directory = $stack.Pop()
            $info = New-Object IO.DirectoryInfo($directory)
            foreach ($item in $info.EnumerateFileSystemInfos()) {
                $isDirectory = (($item.Attributes -band [IO.FileAttributes]::Directory) -ne 0)
                $isReparse = (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
                Assert-True (-not $isReparse) "CDM1 source reparse entry refused: $($item.FullName)"
                if ($isDirectory) {
                    $directories++
                    Assert-True ($directories -le [int64]$Invocation.maximumSourceDirectories) "CDM1 source directory bound exceeded: $root"
                    $stack.Push($item.FullName)
                    continue
                }
                $relative = $item.FullName.Substring($root.Length).TrimStart('\')
                $key = Get-Key -Tree ([string]$mapping.name) -Relative $relative
                Assert-True ($Records.ContainsKey($key)) "CDM1 found an unmirrored source file: $key"
                $row = $Records[$key]
                $recordedWriteUtc = ([DateTime]::Parse([string]$row.sourceLastWriteUtc)).ToUniversalTime()
                Assert-True ([int64]$item.Length -eq [int64]$row.bytes) "CDM1 source length changed: $key"
                Assert-True ($item.LastWriteTimeUtc -eq $recordedWriteUtc) "CDM1 source write time changed: $key"
                Assert-True ($visited.Add($key)) "CDM1 duplicate source identity: $key"
                $files++
                $bytes += [int64]$item.Length
            }
        }
        Assert-True ($files -eq [int64]$mapping.expectedFiles -and $bytes -eq [int64]$mapping.expectedLogicalBytes) "CDM1 source tree totals changed: $($mapping.name)"
        $summaryRows.Add([pscustomobject]@{name=[string]$mapping.name;root=$root;files=$files;directories=$directories;logicalBytes=$bytes;metadataStable=$true;unmirroredFiles=0;reparseEntries=0})
        $aggregateFiles += $files
        $aggregateBytes += $bytes
    }
    Assert-True ($visited.Count -eq $Records.Count) 'CDM1 current source exact set differs from the locked manifest.'
    Assert-True ($aggregateFiles -eq [int64]$Invocation.expectedFiles -and $aggregateBytes -eq [int64]$Invocation.expectedLogicalBytes) 'CDM1 current source aggregate changed.'
    return [pscustomobject]@{files=$aggregateFiles;logicalBytes=$aggregateBytes;trees=$summaryRows.ToArray();exactSet=$true;metadataStable=$true}
}

function Test-DestinationHashes {
    param([object]$Invocation, [object]$Records)
    $watch = [Diagnostics.Stopwatch]::StartNew()
    [int64]$files = 0
    [int64]$bytes = 0
    foreach ($row in @($Records.Values | Sort-Object tree,relative)) {
        Assert-True ($watch.Elapsed.TotalSeconds -le [int]$Invocation.maximumVerificationSeconds) 'CDM1 destination verification exceeded its time bound.'
        $mapping = Get-TreeMapping -Invocation $Invocation -Name ([string]$row.tree)
        $path = Get-ExpectedPath -Root ([string]$mapping.destination) -Relative ([string]$row.relative)
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "CDM1 verified D mirror file is absent: $path"
        $before = Get-Item -LiteralPath $path -Force
        Assert-True (($before.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "CDM1 D mirror reparse file refused: $path"
        Assert-True ([int64]$before.Length -eq [int64]$row.bytes) "CDM1 D mirror length changed: $path"
        $beforeWrite = $before.LastWriteTimeUtc
        $hash = Get-Sha256 $path
        $after = Get-Item -LiteralPath $path -Force
        Assert-True ([int64]$after.Length -eq [int64]$row.bytes -and $after.LastWriteTimeUtc -eq $beforeWrite) "CDM1 D mirror changed during hashing: $path"
        Assert-True ($hash -eq ([string]$row.sha256).ToUpperInvariant()) "CDM1 D mirror hash changed: $path"
        $files++
        $bytes += [int64]$row.bytes
        if (($files % 1000) -eq 0) { Write-Host ("CDM1 verified D mirror files={0} bytes={1}" -f $files,$bytes) }
    }
    $watch.Stop()
    Assert-True ($files -eq [int64]$Invocation.expectedFiles -and $bytes -eq [int64]$Invocation.expectedLogicalBytes) 'CDM1 D mirror aggregate changed.'
    return [pscustomobject]@{files=$files;logicalBytes=$bytes;sha256Matches=$files;stableDuringHash=$files;elapsedSeconds=[Math]::Round($watch.Elapsed.TotalSeconds,3)}
}

function Remove-ExactRetiredSources {
    param([object]$Invocation, [object]$Records)
    $errors = New-Object 'Collections.Generic.List[object]'
    [int64]$deletedFiles = 0
    [int64]$deletedBytes = 0
    foreach ($row in @($Records.Values | Sort-Object tree,relative)) {
        $mapping = Get-TreeMapping -Invocation $Invocation -Name ([string]$row.tree)
        $path = Get-ExpectedPath -Root ([string]$mapping.source) -Relative ([string]$row.relative)
        try {
            $item = Get-Item -LiteralPath $path -Force
            $recordedWriteUtc = ([DateTime]::Parse([string]$row.sourceLastWriteUtc)).ToUniversalTime()
            Assert-True ([int64]$item.Length -eq [int64]$row.bytes -and $item.LastWriteTimeUtc -eq $recordedWriteUtc) "CDM1 source changed at deletion boundary: $path"
            if (($item.Attributes -band [IO.FileAttributes]::ReadOnly) -ne 0) { [IO.File]::SetAttributes($path,($item.Attributes -bxor [IO.FileAttributes]::ReadOnly)) }
            [IO.File]::Delete($path)
            Assert-True (-not (Test-Path -LiteralPath $path)) "CDM1 exact file remained after delete: $path"
            $deletedFiles++
            $deletedBytes += [int64]$row.bytes
        } catch {
            if ($errors.Count -lt [int]$Invocation.maximumDeleteErrors) { $errors.Add([pscustomobject]@{path=$path;detail=$_.Exception.Message.Substring(0,[Math]::Min(512,$_.Exception.Message.Length))}) }
        }
        if (($deletedFiles % 1000) -eq 0 -and $deletedFiles -gt 0) { Write-Host ("CDM1 deleted retired C files={0} bytes={1}" -f $deletedFiles,$deletedBytes) }
    }
    [int64]$deletedDirectories = 0
    foreach ($mapping in @($Invocation.trees)) {
        $root = Get-NormalizedDirectoryPath ([string]$mapping.source)
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $directories = New-Object 'Collections.Generic.List[string]'
        $stack = New-Object 'Collections.Generic.Stack[string]'
        $stack.Push($root)
        while ($stack.Count -gt 0) {
            $directory = $stack.Pop()
            $directories.Add($directory)
            foreach ($child in (New-Object IO.DirectoryInfo($directory)).EnumerateDirectories()) {
                Assert-True (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "CDM1 directory reparse appeared at deletion boundary: $($child.FullName)"
                $stack.Push($child.FullName)
            }
        }
        foreach ($directory in @($directories.ToArray() | Sort-Object Length -Descending)) {
            try { [IO.Directory]::Delete($directory,$false); $deletedDirectories++ }
            catch { if ($errors.Count -lt [int]$Invocation.maximumDeleteErrors) { $errors.Add([pscustomobject]@{path=$directory;detail=$_.Exception.Message.Substring(0,[Math]::Min(512,$_.Exception.Message.Length))}) } }
        }
    }
    return [pscustomobject]@{deletedFiles=$deletedFiles;deletedLogicalBytes=$deletedBytes;deletedDirectories=$deletedDirectories;errors=$errors.ToArray();errorCount=$errors.Count}
}

function Measure-RemainingSources {
    param([object]$Invocation)
    [int64]$files = 0
    [int64]$bytes = 0
    $remainingRoots = New-Object 'Collections.Generic.List[string]'
    foreach ($mapping in @($Invocation.trees)) {
        $root = Get-NormalizedDirectoryPath ([string]$mapping.source)
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $remainingRoots.Add($root)
        $rootItem = Get-Item -LiteralPath $root -Force
        Assert-True (($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "CDM1 remaining source root became a reparse point: $root"
        $stack = New-Object 'Collections.Generic.Stack[string]'
        $stack.Push($root)
        [int64]$directories = 0
        while ($stack.Count -gt 0) {
            $directory = $stack.Pop()
            foreach ($item in (New-Object IO.DirectoryInfo($directory)).EnumerateFileSystemInfos()) {
                Assert-True (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) "CDM1 remaining source reparse entry refused: $($item.FullName)"
                if (($item.Attributes -band [IO.FileAttributes]::Directory) -ne 0) {
                    $directories++
                    Assert-True ($directories -le [int64]$Invocation.maximumSourceDirectories) "CDM1 remaining directory bound exceeded: $root"
                    $stack.Push($item.FullName)
                } else {
                    $files++
                    $bytes += [int64]$item.Length
                }
            }
        }
    }
    return [pscustomobject]@{files=$files;logicalBytes=$bytes;roots=$remainingRoots.ToArray()}
}

function Get-DriveRows {
    param([object]$Invocation, [bool]$IsRehearsal)
    if ($IsRehearsal) { return @($Invocation.driveFixture) }
    $rows = New-Object 'Collections.Generic.List[object]'
    foreach ($name in @('C','D')) {
        $drive = New-Object IO.DriveInfo($name)
        $rows.Add([pscustomobject]@{name=$name;isReady=[bool]$drive.IsReady;totalBytes=if($drive.IsReady){[int64]$drive.TotalSize}else{0};availableFreeBytes=if($drive.IsReady){[int64]$drive.AvailableFreeSpace}else{0}})
    }
    return $rows.ToArray()
}

function Invoke-CDM1Preflight {
    param([object]$Invocation, [string]$PackageRoot, [bool]$IsRehearsal)
    $outputRoot = Get-NormalizedDirectoryPath ([string]$Invocation.outputRoot)
    $localZip = [IO.Path]::GetFullPath([string]$Invocation.localResultPath)
    $returnPath = [IO.Path]::GetFullPath([string]$Invocation.returnPath)
    $tempRoot = Get-NormalizedDirectoryPath ([string]$Invocation.tempRoot)
    if (-not $IsRehearsal) {
        foreach ($blocked in @($Invocation.refuseComputerNames)) { Assert-True (-not $env:COMPUTERNAME.Equals([string]$blocked,[StringComparison]::OrdinalIgnoreCase)) "CDM1 refuses this computer: $env:COMPUTERNAME" }
    }
    Assert-True (-not (Test-Path -LiteralPath $outputRoot)) "CDM1 output root must be fresh: $outputRoot"
    Assert-True (-not (Test-Path -LiteralPath $localZip)) "CDM1 local result ZIP must be fresh: $localZip"
    Assert-True (-not (Test-Path -LiteralPath $returnPath)) "CDM1 return ZIP must be fresh: $returnPath"
    Assert-True (Test-Path -LiteralPath $tempRoot -PathType Container) 'CDM1 D-side temp root is unavailable.'
    Assert-True (Test-Path -LiteralPath (Split-Path -Parent $returnPath) -PathType Container) 'CDM1 return root is unavailable.'
    Assert-True (Test-Path -LiteralPath ([string]$Invocation.lockedManifestPath) -PathType Leaf) 'CDM1 locked manifest is unavailable.'
    Assert-True ((Get-Sha256 ([string]$Invocation.lockedManifestPath)) -eq [string]$Invocation.lockedManifestSha256) 'CDM1 locked manifest hash changed.'
    foreach ($mapping in @($Invocation.trees)) {
        Assert-True (Test-Path -LiteralPath ([string]$mapping.source) -PathType Container) "CDM1 retired source root is absent: $($mapping.source)"
        Assert-True (Test-Path -LiteralPath ([string]$mapping.destination) -PathType Container) "CDM1 D mirror root is absent: $($mapping.destination)"
        Assert-True (-not ([string]$mapping.source).Equals([string]$Invocation.historicalOutputRoot,[StringComparison]::OrdinalIgnoreCase)) 'CDM1 historical outputs entered deletion scope.'
    }
    if (-not $IsRehearsal) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        Assert-True ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) 'CDM1 requires an elevated administrator token.'
        Assert-True ([IO.Path]::GetPathRoot($PackageRoot).Equals('D:\',[StringComparison]::OrdinalIgnoreCase)) 'Extract and run CDM1 from JBOD D:, never C:.'
        Assert-True ([IO.Path]::GetPathRoot($outputRoot).Equals('D:\',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 evidence output must remain on D:.'
        Assert-True ([IO.Path]::GetPathRoot($localZip).Equals('D:\',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 local result must remain on D:.'
        Assert-True ([IO.Path]::GetPathRoot($tempRoot).Equals('D:\',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 temp root must remain on D:.'
        foreach ($commandName in @('Get-ScheduledTask','Get-ScheduledTaskInfo','Get-CimInstance')) { Assert-True ($null -ne (Get-Command $commandName -ErrorAction Stop)) "CDM1 required command is absent: $commandName" }
        $d = New-Object IO.DriveInfo('D')
        Assert-True ($d.IsReady -and [int64]$d.AvailableFreeSpace -ge 1073741824) 'CDM1 requires at least 1 GiB available on D:.'
    }
    $configHash = Assert-InstalledConfig -Invocation $Invocation
    $processor = Get-ProcessorSnapshot -Invocation $Invocation -IsRehearsal $IsRehearsal
    return [pscustomobject]@{schema='argos_cdm1_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_EXACT_STAGE1_DELETE_PREFLIGHT';packageRoot=$PackageRoot;outputRoot=$outputRoot;localResultZip=$localZip;returnPath=$returnPath;tempRoot=$tempRoot;processorConfigSha256=$configHash;processor=$processor;expectedFiles=[int64]$Invocation.expectedFiles;expectedLogicalBytes=[int64]$Invocation.expectedLogicalBytes;targetExecuted=$false;mutationsPerformed=$false;deletionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
}

$packageRoot = Get-NormalizedDirectoryPath $PSScriptRoot
[void](Verify-Package -PackageRoot $packageRoot)
$invocationPath = [IO.Path]::GetFullPath($InvocationManifest)
$invocation = Read-Invocation -Path $invocationPath -IsRehearsal ([bool]$Rehearsal)
$preflightResult = Invoke-CDM1Preflight -Invocation $invocation -PackageRoot $packageRoot -IsRehearsal ([bool]$Rehearsal)
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 12; return }

$env:TEMP = [string]$preflightResult.tempRoot
$env:TMP = [string]$preflightResult.tempRoot
$outputRoot = [string]$preflightResult.outputRoot
$localResultZip = [string]$preflightResult.localResultZip
$returnPath = [string]$preflightResult.returnPath
[void](New-Item -ItemType Directory -Path $outputRoot)
$transcriptPath = Join-Path $outputRoot 'CDM1_TRANSCRIPT.log'
$transcriptStarted = $false
$completed = $false
try {
    Start-Transcript -LiteralPath $transcriptPath -NoClobber | Out-Null
    $transcriptStarted = $true
    Write-Host 'CDM1 verification started. No retired C file will be deleted until the exact D mirror hashes pass.'
    $driveBefore = @(Get-DriveRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $records = Read-LockedManifest -Invocation $invocation
    $sourceInitial = Test-SourceTrees -Invocation $invocation -Records $records
    $destinationVerification = Test-DestinationHashes -Invocation $invocation -Records $records
    $sourceFinal = Test-SourceTrees -Invocation $invocation -Records $records
    $configHashBeforeDelete = Assert-InstalledConfig -Invocation $invocation
    $processorBeforeDelete = Get-ProcessorSnapshot -Invocation $invocation -IsRehearsal ([bool]$Rehearsal)
    Assert-ProcessorUnchanged -Before $preflightResult.processor -After $processorBeforeDelete
    $verification = [ordered]@{schema='argos_cdm1_predelete_verification_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_PREDELETE_EXACT_D_MIRROR_VERIFICATION';lockedManifestSha256=[string]$invocation.lockedManifestSha256;sourceInitial=$sourceInitial;destinationVerification=$destinationVerification;sourceFinal=$sourceFinal;processorConfigSha256=$configHashBeforeDelete;processorBefore=$preflightResult.processor;processorBeforeDelete=$processorBeforeDelete;processorUnchanged=$true;deletionStarted=$false;historicalOutputRootExcluded=$true;fileContentUsedOnlyForSha256=$true;imageBytesDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-Utf8CreateNewJson -Path (Join-Path $outputRoot 'CDM1_PREDELETE_VERIFICATION.json') -Value $verification -Depth 16
    Write-Host 'CDM1 exact D mirror verification passed. Deleting only manifest-bound retired C files.'
    $deletion = Remove-ExactRetiredSources -Invocation $invocation -Records $records
    $remaining = Measure-RemainingSources -Invocation $invocation
    $driveAfter = @(Get-DriveRows -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    $configHashAfterDelete = Assert-InstalledConfig -Invocation $invocation
    $processorAfterDelete = Get-ProcessorSnapshot -Invocation $invocation -IsRehearsal ([bool]$Rehearsal)
    Assert-ProcessorUnchanged -Before $preflightResult.processor -After $processorAfterDelete
    $pass = ([int64]$deletion.deletedFiles -eq [int64]$invocation.expectedFiles -and [int64]$deletion.deletedLogicalBytes -eq [int64]$invocation.expectedLogicalBytes -and [int]$deletion.errorCount -eq 0 -and [int64]$remaining.files -eq 0)
    $result = [ordered]@{schema='argos_cdm1_exact_stage1_delete_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=if($pass){'PASS_CDM1_EXACT_STAGE1_DUPLICATES_DELETED'}else{'HOLD_CDM1_PARTIAL_EXACT_DELETE'};lockedManifestSha256=[string]$invocation.lockedManifestSha256;expectedFiles=[int64]$invocation.expectedFiles;expectedLogicalBytes=[int64]$invocation.expectedLogicalBytes;deletedFiles=[int64]$deletion.deletedFiles;deletedLogicalBytes=[int64]$deletion.deletedLogicalBytes;deletedDirectories=[int64]$deletion.deletedDirectories;deleteErrorCount=[int]$deletion.errorCount;deleteErrors=@($deletion.errors);remainingSourceFiles=[int64]$remaining.files;remainingSourceLogicalBytes=[int64]$remaining.logicalBytes;remainingSourceRoots=@($remaining.roots);driveBefore=$driveBefore;driveAfter=$driveAfter;processorConfigSha256BeforeDelete=$configHashBeforeDelete;processorConfigSha256AfterDelete=$configHashAfterDelete;processorBefore=$preflightResult.processor;processorAfter=$processorAfterDelete;processorUnchanged=$true;historicalOutputRootExcluded=$true;historicalOutputRoot=[string]$invocation.historicalOutputRoot;taskActionsPerformed=@();processActionsPerformed=@();installedFilesChanged=@();queueMutationPerformed=$false;ledgerMutationPerformed=$false;waferActionPerformed=$false;fileContentUsedOnlyForSha256=$true;imageBytesDecoded=$false;o2d4Retried=$false;o2a2Retried=$false;cdo1Executed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-Utf8CreateNewJson -Path (Join-Path $outputRoot 'CDM1_RESULT.json') -Value $result -Depth 18
    if (-not $pass) { throw 'CDM1 exact deletion was incomplete; see returned CDM1_RESULT.json.' }
    $completed = $true
} catch {
    $failurePath = Join-Path $outputRoot 'CDM1_FAILURE.json'
    if (-not (Test-Path -LiteralPath $failurePath)) { Write-Utf8CreateNewJson -Path $failurePath -Value ([ordered]@{schema='argos_cdm1_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='FAIL_CDM1_EXACT_STAGE1_DELETE';detail=$_.Exception.Message;scriptStack=$_.ScriptStackTrace;taskActionsPerformed=@();processActionsPerformed=@();historicalOutputRootExcluded=$true;waferActionPerformed=$false;imageBytesDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false}) }
    throw
} finally {
    if ($transcriptStarted) { Stop-Transcript | Out-Null }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (-not (Test-Path -LiteralPath $localResultZip)) { [IO.Compression.ZipFile]::CreateFromDirectory($outputRoot,$localResultZip,[IO.Compression.CompressionLevel]::Optimal,$false) }
    if (-not (Test-Path -LiteralPath $returnPath)) { [IO.File]::Copy($localResultZip,$returnPath,$false) }
    if (Test-Path -LiteralPath $returnPath -PathType Leaf) { Assert-True ((Get-Sha256 $returnPath) -eq (Get-Sha256 $localResultZip)) 'CDM1 returned ZIP hash changed.' }
}

Assert-True $completed 'CDM1 did not complete.'
[ordered]@{schema='argos_cdm1_return_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_EXACT_STAGE1_DELETE_RETURNED';returnPath=$returnPath;resultZipBytes=(Get-Item -LiteralPath $returnPath).Length;resultZipSha256=Get-Sha256 $returnPath;deletedFiles=[int64]$invocation.expectedFiles;deletedLogicalBytes=[int64]$invocation.expectedLogicalBytes;historicalOutputRootExcluded=$true;processorUnchanged=$true;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 10
