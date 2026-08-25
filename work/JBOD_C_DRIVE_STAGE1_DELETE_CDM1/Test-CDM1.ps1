[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$PackageRoot,
    [Parameter(Mandatory = $true)][string]$RehearsalRoot,
    [Parameter(Mandatory = $true)][string]$GatePath,
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-Utf8CreateNewJson {
    param([string]$Path, [object]$Value, [int]$Depth = 16)
    $json = $Value | ConvertTo-Json -Depth $Depth
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}

function Write-Utf8CreateNewLines {
    param([string]$Path, [string[]]$Lines)
    $text = ($Lines -join [Environment]::NewLine) + [Environment]::NewLine
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($text)
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}

function New-FixtureFile {
    param([string]$Path, [int]$Length, [byte]$Seed)
    $bytes = New-Object byte[] $Length
    for ($index=0; $index -lt $bytes.Length; $index++) { $bytes[$index] = [byte](($Seed + $index) % 251) }
    [IO.File]::WriteAllBytes($Path,$bytes)
}

function New-CDM1Case {
    param([string]$Root, [bool]$CorruptDestination, [bool]$UnsafeRelative)
    [void](New-Item -ItemType Directory -Path $Root)
    $sourceBase = Join-Path $Root 'retired'
    $destinationBase = Join-Path $Root 'mirror'
    $cacheSource = Join-Path $sourceBase 'cache'
    $metadataSource = Join-Path $sourceBase 'metadata'
    $dashboardSource = Join-Path $sourceBase 'dashboard_outputs'
    $cacheDestination = Join-Path $destinationBase 'c'
    $metadataDestination = Join-Path $destinationBase 'm'
    $dashboardDestination = Join-Path $destinationBase 'd'
    $historicalRoot = Join-Path $sourceBase 'outputs'
    $tempRoot = Join-Path $Root 'temp'
    $returnRoot = Join-Path $Root 'return'
    foreach ($directory in @($cacheSource,$metadataSource,$dashboardSource,$cacheDestination,$metadataDestination,$dashboardDestination,$historicalRoot,$tempRoot,$returnRoot)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
    $definitions = @(
        [pscustomobject]@{tree='cache';relative='one.bin';length=11;seed=1;source=$cacheSource;destination=$cacheDestination},
        [pscustomobject]@{tree='metadata';relative='a\one.bin';length=3;seed=2;source=$metadataSource;destination=$metadataDestination},
        [pscustomobject]@{tree='metadata';relative='a\two.bin';length=5;seed=3;source=$metadataSource;destination=$metadataDestination},
        [pscustomobject]@{tree='metadata';relative='three.bin';length=7;seed=4;source=$metadataSource;destination=$metadataDestination},
        [pscustomobject]@{tree='dashboard_outputs';relative='one.bin';length=13;seed=5;source=$dashboardSource;destination=$dashboardDestination},
        [pscustomobject]@{tree='dashboard_outputs';relative='nested\two.bin';length=17;seed=6;source=$dashboardSource;destination=$dashboardDestination}
    )
    $manifestLines = New-Object 'Collections.Generic.List[string]'
    $destinationRows = New-Object 'Collections.Generic.List[object]'
    $definitionIndex = 0
    foreach ($definition in $definitions) {
        $sourcePath = Join-Path $definition.source $definition.relative
        $destinationPath = Join-Path $definition.destination $definition.relative
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $sourcePath) -Force)
        [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destinationPath) -Force)
        New-FixtureFile -Path $sourcePath -Length ([int]$definition.length) -Seed ([byte]$definition.seed)
        New-FixtureFile -Path $destinationPath -Length ([int]$definition.length) -Seed ([byte]$definition.seed)
        $sourceItem = Get-Item -LiteralPath $sourcePath
        $sha = Get-Sha256 $sourcePath
        $manifestRelative = [string]$definition.relative
        if ($UnsafeRelative -and $definitionIndex -eq 0) { $manifestRelative = '..\escape.bin' }
        $row = [ordered]@{tree=[string]$definition.tree;relative=$manifestRelative;source=$sourcePath;destination=$destinationPath;bytes=[int64]$definition.length;sha256=$sha;sourceLastWriteUtc=$sourceItem.LastWriteTimeUtc.ToString('o');state='COPIED_HASH_VERIFIED'}
        $manifestLines.Add(($row | ConvertTo-Json -Compress))
        $destinationRows.Add([pscustomobject]@{path=$destinationPath;bytes=[int64]$definition.length;sha256=$sha})
        $definitionIndex++
    }
    New-FixtureFile -Path (Join-Path $historicalRoot 'KEEP.bin') -Length 23 -Seed 9
    $historicalHash = Get-Sha256 (Join-Path $historicalRoot 'KEEP.bin')
    $manifestPath = Join-Path $Root 'LOCKED.jsonl'
    Write-Utf8CreateNewLines -Path $manifestPath -Lines $manifestLines.ToArray()
    if ($CorruptDestination) { New-FixtureFile -Path ([string]$destinationRows[0].path) -Length 11 -Seed 99 }
    $config = [ordered]@{schema='argos_jbod_all_wafer_processor_config_v3';outputRoot='D:\A2\o';dashboardOutputRoot='D:\A2\d';cacheRoot='D:\A2\c';metadataSnapshotRoot='D:\A2\m\verified';reviewOnly=$true;xmlExportEnabled=$false;productionRoutingEnabled=$false}
    $configPath = Join-Path $Root 'PROCESSOR_CONFIG.json'
    Write-Utf8CreateNewJson -Path $configPath -Value $config
    $outputRoot = Join-Path $Root 'output'
    $localZip = Join-Path $Root 'CDM1R_LOCAL.zip'
    $returnZip = Join-Path $returnRoot 'CDM1R.zip'
    $invocationPath = Join-Path $Root 'INVOCATION_REHEARSAL.json'
    $snapshot = [ordered]@{taskName='Fixture.Processor';taskState='Running';taskLastRunUtc='2026-08-25T00:00:00.0000000Z';taskLastResult=267009;processes=@([ordered]@{processId=1234;parentProcessId=100;creationUtc='2026-08-25T00:00:00.0000000Z';executablePath='powershell.exe';commandLineSha256=('A' * 64);commandLineLength=128})}
    $invocation = [ordered]@{
        schema='argos_cdm1_direct_admin_delete_invocation_v1';incidentId='JBOD_C_DRIVE_FULL_20260825_REHEARSAL';rehearsal=$true
        processorConfigPath=$configPath;expectedProcessorConfigSha256=Get-Sha256 $configPath;processorTaskName='Fixture.Processor';processorRunnerPath=(Join-Path $Root 'Fixture-Runner.ps1')
        lockedManifestPath=$manifestPath;lockedManifestSha256=Get-Sha256 $manifestPath;maximumManifestBytes=1048576;expectedFiles=6;expectedLogicalBytes=56
        trees=@(
            [ordered]@{name='cache';source=$cacheSource;destination=$cacheDestination;expectedFiles=1;expectedLogicalBytes=11},
            [ordered]@{name='metadata';source=$metadataSource;destination=$metadataDestination;expectedFiles=3;expectedLogicalBytes=15},
            [ordered]@{name='dashboard_outputs';source=$dashboardSource;destination=$dashboardDestination;expectedFiles=2;expectedLogicalBytes=30}
        )
        historicalOutputRoot=$historicalRoot;tempRoot=$tempRoot;outputRoot=$outputRoot;localResultPath=$localZip;returnPath=$returnZip;refuseComputerNames=@();maximumSourceDirectories=100;maximumVerificationSeconds=60;maximumDeleteErrors=16;processorSnapshotFixture=$snapshot
        driveFixture=@([ordered]@{name='C';isReady=$true;totalBytes=100000;availableFreeBytes=0},[ordered]@{name='D';isReady=$true;totalBytes=200000;availableFreeBytes=100000})
        deletionAuthorized=$true;singleAttemptAuthorized=$true;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-Utf8CreateNewJson -Path $invocationPath -Value $invocation -Depth 18
    return [pscustomobject]@{root=$Root;invocationPath=$invocationPath;sourceRoots=@($cacheSource,$metadataSource,$dashboardSource);destinationRows=$destinationRows.ToArray();historicalPath=(Join-Path $historicalRoot 'KEEP.bin');historicalHash=$historicalHash;outputRoot=$outputRoot;localZip=$localZip;returnZip=$returnZip}
}

$resolvedProject = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$resolvedPackage = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PackageRoot).Path).TrimEnd('\')
$resolvedRehearsal = [IO.Path]::GetFullPath($RehearsalRoot).TrimEnd('\')
$resolvedGate = [IO.Path]::GetFullPath($GatePath)
Assert-True ($resolvedRehearsal.StartsWith($resolvedProject+'\',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 rehearsal root must stay in the project.'
Assert-True ($resolvedGate.StartsWith($resolvedProject+'\',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 test gate must stay in the project.'
Assert-True (-not (Test-Path -LiteralPath $resolvedRehearsal)) 'CDM1 rehearsal root must be fresh.'
Assert-True (-not (Test-Path -LiteralPath $resolvedGate)) 'CDM1 test gate must be fresh.'
$target = Join-Path $resolvedPackage 'DELETE_CDM1.ps1'
$packageManifest = Join-Path $resolvedPackage 'PACKAGE_MANIFEST.json'
Assert-True (Test-Path -LiteralPath $target -PathType Leaf) 'CDM1 target is absent.'
Assert-True (Test-Path -LiteralPath $packageManifest -PathType Leaf) 'CDM1 package manifest is absent.'
$manifest = Get-Content -LiteralPath $packageManifest -Raw | ConvertFrom-Json
Assert-True ([string]$manifest.schema -eq 'argos_cdm1_package_manifest_v1' -and @($manifest.files).Count -eq 4) 'CDM1 package manifest changed.'
foreach ($entry in @($manifest.files)) {
    $path = Join-Path $resolvedPackage ([string]$entry.path)
    Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$entry.bytes -and (Get-Sha256 $path) -eq [string]$entry.sha256) "CDM1 package entry changed: $($entry.path)"
}
$tokens=$null;$parserErrors=$null;[void][Management.Automation.Language.Parser]::ParseFile($target,[ref]$tokens,[ref]$parserErrors)
Assert-True (@($parserErrors).Count -eq 0) 'CDM1 target parser failed.'
$preflightResult=[ordered]@{schema='argos_cdm1_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_TEST_PREFLIGHT';targetSha256=Get-Sha256 $target;packageManifestSha256=Get-Sha256 $packageManifest;rehearsalRoot=$resolvedRehearsal;gatePath=$resolvedGate;targetExecuted=$false;mutationsPerformed=$false}
if($Preflight){$preflightResult|ConvertTo-Json -Depth 8;return}
Assert-True ([bool]$Gate) 'Specify -Preflight or -Gate.'

[void](New-Item -ItemType Directory -Path $resolvedRehearsal)
$negative = New-CDM1Case -Root (Join-Path $resolvedRehearsal 'negative') -CorruptDestination $true -UnsafeRelative $false
$negativeInputRows = @($negative.sourceRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse | ForEach-Object { [pscustomobject]@{path=$_.FullName;sha256=Get-Sha256 $_.FullName} } })
$negativePreflightText = @(& $target -InvocationManifest $negative.invocationPath -Preflight -Rehearsal)
Assert-True ($negativePreflightText.Count -eq 1 -and [string](($negativePreflightText[0]|ConvertFrom-Json).state) -eq 'PASS_CDM1_EXACT_STAGE1_DELETE_PREFLIGHT') 'CDM1 negative preflight failed unexpectedly.'
$negativeFailed = $false
try { $negativeOutput = @(& $target -InvocationManifest $negative.invocationPath -Rehearsal) }
catch { $negativeFailed = $true }
Assert-True $negativeFailed 'CDM1 corrupted D mirror did not fail closed.'
foreach ($row in $negativeInputRows) { Assert-True (Test-Path -LiteralPath $row.path -PathType Leaf) "CDM1 negative source was deleted: $($row.path)"; Assert-True ((Get-Sha256 $row.path) -eq [string]$row.sha256) "CDM1 negative source changed: $($row.path)" }
Assert-True (Test-Path -LiteralPath $negative.returnZip -PathType Leaf) 'CDM1 negative evidence ZIP was not returned.'
Assert-True ((Get-Sha256 $negative.historicalPath) -eq [string]$negative.historicalHash) 'CDM1 negative historical control changed.'

$traversal = New-CDM1Case -Root (Join-Path $resolvedRehearsal 'traversal') -CorruptDestination $false -UnsafeRelative $true
$traversalInputRows = @($traversal.sourceRoots | ForEach-Object { Get-ChildItem -LiteralPath $_ -File -Recurse | ForEach-Object { [pscustomobject]@{path=$_.FullName;sha256=Get-Sha256 $_.FullName} } })
$traversalFailed = $false
try { $traversalOutput = @(& $target -InvocationManifest $traversal.invocationPath -Rehearsal) }
catch { $traversalFailed = $true }
Assert-True $traversalFailed 'CDM1 unsafe relative path was not rejected.'
foreach ($row in $traversalInputRows) { Assert-True (Test-Path -LiteralPath $row.path -PathType Leaf) "CDM1 traversal source was deleted: $($row.path)"; Assert-True ((Get-Sha256 $row.path) -eq [string]$row.sha256) "CDM1 traversal source changed: $($row.path)" }
Assert-True (Test-Path -LiteralPath $traversal.returnZip -PathType Leaf) 'CDM1 traversal evidence ZIP was not returned.'
Assert-True ((Get-Sha256 $traversal.historicalPath) -eq [string]$traversal.historicalHash) 'CDM1 traversal historical control changed.'

$positive = New-CDM1Case -Root (Join-Path $resolvedRehearsal 'positive') -CorruptDestination $false -UnsafeRelative $false
$positiveDestinationRows = @($positive.destinationRows)
$positivePreflightText = @(& $target -InvocationManifest $positive.invocationPath -Preflight -Rehearsal)
Assert-True ($positivePreflightText.Count -eq 1 -and [string](($positivePreflightText[0]|ConvertFrom-Json).state) -eq 'PASS_CDM1_EXACT_STAGE1_DELETE_PREFLIGHT') 'CDM1 positive preflight failed.'
$positiveOutput = @(& $target -InvocationManifest $positive.invocationPath -Rehearsal)
Assert-True ($positiveOutput.Count -le 8) 'CDM1 positive output exceeded its bound.'
$resultPath = Join-Path $positive.outputRoot 'CDM1_RESULT.json'
Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) 'CDM1 positive result is absent.'
$result = Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
Assert-True ([string]$result.state -eq 'PASS_CDM1_EXACT_STAGE1_DUPLICATES_DELETED') 'CDM1 positive result did not pass.'
Assert-True ([int64]$result.deletedFiles -eq 6 -and [int64]$result.deletedLogicalBytes -eq 56 -and [int64]$result.remainingSourceFiles -eq 0) 'CDM1 positive deletion totals changed.'
foreach ($sourceRoot in $positive.sourceRoots) { Assert-True (-not (Test-Path -LiteralPath $sourceRoot)) "CDM1 positive retired root remained: $sourceRoot" }
foreach ($row in $positiveDestinationRows) { Assert-True (Test-Path -LiteralPath $row.path -PathType Leaf) "CDM1 D mirror disappeared: $($row.path)"; Assert-True ((Get-Sha256 $row.path) -eq [string]$row.sha256) "CDM1 D mirror changed: $($row.path)" }
Assert-True ((Get-Sha256 $positive.historicalPath) -eq [string]$positive.historicalHash) 'CDM1 historical output control changed.'
Assert-True (Test-Path -LiteralPath $positive.returnZip -PathType Leaf) 'CDM1 positive return ZIP is absent.'
Assert-True (-not [bool]$result.waferActionPerformed -and [bool]$result.historicalOutputRootExcluded -and [bool]$result.processorUnchanged) 'CDM1 positive safety flags changed.'

$gateResult=[ordered]@{schema='argos_cdm1_exact_package_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_EXACT_DELETE_REHEARSAL';targetSha256=Get-Sha256 $target;packageManifestSha256=Get-Sha256 $packageManifest;caseIds=@('DESTINATION_HASH_MISMATCH_FAILS_BEFORE_DELETE','UNSAFE_RELATIVE_PATH_FAILS_BEFORE_DELETE','EXACT_DELETE_PASS');zeroOneManyEvidence=@('ZERO','ONE','MANY');negativeSourceFilesUnchanged=$true;negativeEvidenceReturned=$true;unsafeRelativeSourceFilesUnchanged=$true;unsafeRelativeEvidenceReturned=$true;positiveDeletedFiles=6;positiveDeletedLogicalBytes=56;positiveRemainingFiles=0;destinationFilesUnchanged=$true;historicalOutputControlUnchanged=$true;processorUnchanged=$true;taskActionsPerformed=@();processActionsPerformed=@();waferActionPerformed=$false;imageBytesDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false}
Write-Utf8CreateNewJson -Path $resolvedGate -Value $gateResult -Depth 12
$gateResult|ConvertTo-Json -Depth 12
