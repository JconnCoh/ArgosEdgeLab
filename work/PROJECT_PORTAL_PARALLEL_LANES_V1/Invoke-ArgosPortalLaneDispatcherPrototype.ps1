#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [Parameter(Mandatory=$true)][ValidateSet('CONTROL','REVIEW_A','REVIEW_B')][string]$LaneId,
    [Parameter(ParameterSetName='Preflight')][switch]$Preflight,
    [Parameter(ParameterSetName='RunOne')][switch]$RunOne,
    [Parameter(ParameterSetName='EvaluatePath',Mandatory=$true)][string]$EvaluatePath,
    [Parameter(ParameterSetName='EvaluatePath')][switch]$ShortAliasVerified
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PplHash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
}

function ConvertTo-PplJsonBytes($Value) {
    $json = $Value | ConvertTo-Json -Depth 20 -Compress
    [Text.UTF8Encoding]::new($false).GetBytes($json)
}

function Write-PplCreateNewJson([string]$Path, $Value) {
    $bytes = ConvertTo-PplJsonBytes $Value
    $stream = [IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
}

function Test-PplContained([string]$Child, [string]$Parent) {
    $childFull = [IO.Path]::GetFullPath($Child).TrimEnd('\')
    $parentFull = [IO.Path]::GetFullPath($Parent).TrimEnd('\')
    $childFull.Equals($parentFull,[StringComparison]::OrdinalIgnoreCase) -or
        $childFull.StartsWith($parentFull + '\',[StringComparison]::OrdinalIgnoreCase)
}

function Get-PplPathState([string]$Path, [bool]$AliasVerified, [int]$Reserve) {
    $full = [IO.Path]::GetFullPath($Path)
    $effective = $full.Length + $Reserve
    $componentMaximum = @($full.Split([IO.Path]::DirectorySeparatorChar) | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $state = if ($componentMaximum -gt 80 -or $effective -ge 230) {
        'HARD_STOP'
    } elseif ($effective -ge 200 -and -not $AliasVerified) {
        'SHORT_ALIAS_REQUIRED'
    } else {
        'PASS'
    }
    [ordered]@{state=$state;path=$full;pathLength=$full.Length;reservedSuffixCharacters=$Reserve;effectiveLength=$effective;maximumComponentLength=[int]$componentMaximum;shortAliasVerified=$AliasVerified}
}

function Get-PplHmac([string]$Text, [byte[]]$Key) {
    $hmac = [Security.Cryptography.HMACSHA256]::new($Key)
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        ([BitConverter]::ToString($hmac.ComputeHash($bytes))).Replace('-','')
    } finally { $hmac.Dispose() }
}

function New-PplTerminalEnvelope($Manifest, [byte[]]$Key) {
    $manifestJson = $Manifest | ConvertTo-Json -Depth 16 -Compress
    [ordered]@{
        schema = 'argos_project_portal_parallel_lane_terminal_envelope_v1'
        manifest = $Manifest
        signature = [ordered]@{
            algorithm = 'HMACSHA256_OFFLINE_FIXTURE_ONLY'
            signer = 'PPL1_EPHEMERAL_FIXTURE_KEY_NOT_LIVE_TRUST'
            value = Get-PplHmac $manifestJson $Key
        }
    }
}

function Write-PplTerminal([string]$ReadyRoot, $Manifest, [byte[]]$Key) {
    $final = Join-Path $ReadyRoot ($Manifest.requestId + '.terminal.json')
    if (Test-Path -LiteralPath $final -PathType Leaf) { return $final }
    $partial = Join-Path $ReadyRoot ($Manifest.requestId + '.partial')
    if (Test-Path -LiteralPath $partial) { throw "Deterministic response partial collision: $partial" }
    Write-PplCreateNewJson $partial (New-PplTerminalEnvelope $Manifest $Key)
    [IO.File]::Move($partial,$final)
    $final
}

function Write-PplLedgerState([string]$LedgerRoot, [string]$RequestId, [string]$Leaf, $Value) {
    $requestLedger = Join-Path $LedgerRoot $RequestId
    if (-not (Test-Path -LiteralPath $requestLedger -PathType Container)) {
        [void][IO.Directory]::CreateDirectory($requestLedger)
    }
    $path = Join-Path $requestLedger $Leaf
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Write-PplCreateNewJson $path $Value }
    $path
}

function Assert-PplAuthority($Request, [string]$CurrentLane) {
    if ([string]$Request.schema -ne 'argos_project_portal_parallel_lane_request_v1') { throw 'Request schema is not authorized.' }
    if ([string]::IsNullOrWhiteSpace([string]$Request.requestId) -or ([string]$Request.requestId).Length -gt 52 -or [string]$Request.requestId -notmatch '^REQ_[A-Z0-9_]+$') { throw 'Request identity violates the bounded filename contract.' }
    if ([string]$Request.laneId -ne $CurrentLane) { throw 'Request lane does not match the owning queue.' }
    $computeClasses = @('REVIEW_DETECTOR','REVIEW_OCR')
    $controlClasses = @('STATUS','DATA_PULL','MAINTENANCE_PATCH','CONFIG_ACTION','TASK_ACTION','PROCESS_ACTION')
    $jobClass = [string]$Request.jobClass
    if ($CurrentLane -eq 'CONTROL') {
        if ($jobClass -notin $controlClasses) { throw 'Compute job was submitted to CONTROL.' }
    } elseif ($jobClass -notin $computeClasses) { throw 'Non-compute job was submitted to a REVIEW lane.' }
    $a = $Request.authority
    if (-not [bool]$a.reviewOnly -or [bool]$a.trainingEligible -or [bool]$a.xmlEligible -or [bool]$a.productionEligible -or [bool]$a.sourceMutationAllowed) {
        throw 'Request authority is broader than review-only.'
    }
    if ($CurrentLane -ne 'CONTROL' -and [bool]$a.taskProcessActionAllowed) { throw 'Review compute cannot act on tasks or processes.' }
    if ($CurrentLane -eq 'CONTROL' -and $jobClass -in @('STATUS','DATA_PULL') -and [bool]$a.taskProcessActionAllowed) { throw 'Read-only control job requests a task/process action.' }
}

function Assert-PplBudgetAndPath($Request, $Lane, $BudgetConfig) {
    $budget = $BudgetConfig.lanes.$LaneId
    if ([int]$Request.budget.cpuSeconds -gt [int]$budget.maximumCpuSeconds) { throw 'CPU budget exceeds the lane ceiling.' }
    if ([int]$Request.budget.memoryMiB -gt [int]$budget.maximumMemoryMiB) { throw 'Memory budget exceeds the lane ceiling.' }
    if ([int]$Request.budget.diskMiB -gt [int]$budget.maximumDiskMiB) { throw 'Disk budget exceeds the lane ceiling.' }
    if (-not (Test-PplContained ([string]$Request.outputRoot) ([string]$Lane.outputRoot))) { throw 'Output root escapes the owning lane.' }
    $pathState = Get-PplPathState ([string]$Request.outputRoot) ([bool]$Request.shortAliasVerified) ([int]$BudgetConfig.reservedSuffixCharacters)
    if ($pathState.state -ne 'PASS') { throw "Output path gate refused: $($pathState.state)" }
    $pathState
}

$configFull = [IO.Path]::GetFullPath($ConfigPath)
if (-not (Test-Path -LiteralPath $configFull -PathType Leaf)) { throw 'Runtime config is absent.' }
$config = Get-Content -LiteralPath $configFull -Raw | ConvertFrom-Json
if ([string]$config.schema -ne 'argos_project_portal_parallel_lanes_offline_runtime_v1') { throw 'Runtime config schema changed.' }
if (-not [bool]$config.offlineFixtureOnly -or [bool]$config.liveQualified) { throw 'Prototype refuses non-fixture or live-qualified configuration.' }
$fixtureRoot = [IO.Path]::GetFullPath([string]$config.fixtureRoot)
$lane = $config.lanes.$LaneId
if ($null -eq $lane) { throw 'Runtime lane is absent.' }
foreach ($property in @('incomingRoot','workRoot','readyRoot','quarantineRoot','ledgerRoot','outputRoot','processedRoot')) {
    if (-not (Test-PplContained ([string]$lane.$property) $fixtureRoot)) { throw "Lane property escapes fixture root: $property" }
}
$budgetPath = [IO.Path]::GetFullPath([string]$config.budgetsPath)
$budgetConfig = Get-Content -LiteralPath $budgetPath -Raw | ConvertFrom-Json
if ([string]$budgetConfig.schema -ne 'argos_project_portal_parallel_lanes_budgets_v1') { throw 'Budget schema changed.' }
$key = [Convert]::FromBase64String([string]$config.fixtureHmacKeyBase64)
if ($key.Length -lt 32) { throw 'Fixture HMAC key is too short.' }

if ($PSCmdlet.ParameterSetName -eq 'EvaluatePath') {
    Get-PplPathState $EvaluatePath ([bool]$ShortAliasVerified) ([int]$budgetConfig.reservedSuffixCharacters) | ConvertTo-Json -Compress
    return
}

$requiredRoots = @($config.globalLockRoot,[string]$lane.incomingRoot,[string]$lane.workRoot,[string]$lane.readyRoot,[string]$lane.quarantineRoot,[string]$lane.ledgerRoot,[string]$lane.outputRoot,[string]$lane.processedRoot)
if ($Preflight) {
    [ordered]@{
        schema='argos_project_portal_parallel_lane_preflight_v1'
        state='PASS_OFFLINE_FIXTURE_DISPATCHER_PREFLIGHT'
        laneId=$LaneId
        fixtureRoot=$fixtureRoot
        requiredRoots=$requiredRoots
        rootsExist=@($requiredRoots | ForEach-Object { Test-Path -LiteralPath $_ -PathType Container })
        mutationsPerformed=$false
        liveQualified=$false
    } | ConvertTo-Json -Depth 6 -Compress
    return
}

if (-not $RunOne) { throw 'RunOne is required for fixture execution.' }
foreach ($root in $requiredRoots) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) { throw "Fixture runtime root is absent: $root" }
}
$globalLockPath = Join-Path ([string]$config.globalLockRoot) 'global.lock'
$laneLockPath = Join-Path ([string]$config.globalLockRoot) ($LaneId + '.lock')
$globalShare = if ($LaneId -eq 'CONTROL') { [IO.FileShare]::None } else { [IO.FileShare]::Read }
$globalAccess = if ($LaneId -eq 'CONTROL') { [IO.FileAccess]::ReadWrite } else { [IO.FileAccess]::Read }
$globalLock = $null
$laneLock = $null
try {
    try { $globalLock = [IO.File]::Open($globalLockPath,[IO.FileMode]::Open,$globalAccess,$globalShare) }
    catch [IO.IOException] {
        [ordered]@{state='LANE_BUSY_GLOBAL_LOCK';laneId=$LaneId;mutationsPerformed=$false} | ConvertTo-Json -Compress
        return
    }
    try { $laneLock = [IO.File]::Open($laneLockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None) }
    catch [IO.IOException] {
        [ordered]@{state='LANE_BUSY_OWN_LOCK';laneId=$LaneId;mutationsPerformed=$false} | ConvertTo-Json -Compress
        return
    }

    $workRows = @(Get-ChildItem -LiteralPath ([string]$lane.workRoot) -Filter '*.work.json' -File | Sort-Object Name)
    $item = $null
    if ($workRows.Count -gt 0) {
        $item = $workRows[0]
    } else {
        $incomingRows = @(Get-ChildItem -LiteralPath ([string]$lane.incomingRoot) -Filter '*.ready.json' -File | Sort-Object Name)
        if ($incomingRows.Count -gt 0) { $item = $incomingRows[0] }
    }
    if ($null -eq $item) {
        [ordered]@{state='LANE_IDLE';laneId=$LaneId;mutationsPerformed=$false} | ConvertTo-Json -Compress
        return
    }

    $ownedPath = $item.FullName
    if ($item.DirectoryName -eq [string]$lane.incomingRoot) {
        $ownedPath = Join-Path ([string]$lane.workRoot) ($item.BaseName.Replace('.ready','') + '.work.json')
        if (Test-Path -LiteralPath $ownedPath) {
            $collisionLeaf = $item.BaseName + '.collision.' + (Get-PplHash $item.FullName).Substring(0,12) + '.json'
            [IO.File]::Move($item.FullName,(Join-Path ([string]$lane.quarantineRoot) $collisionLeaf))
            [ordered]@{state='WORK_COLLISION_QUARANTINED';laneId=$LaneId;mutationsPerformed=$true} | ConvertTo-Json -Compress
            return
        }
        [IO.File]::Move($item.FullName,$ownedPath)
    }

    $requestSha = Get-PplHash $ownedPath
    $request = $null
    $requestId = 'REQ_POISON_' + $requestSha.Substring(0,12)
    $jobClass = 'UNKNOWN'
    try {
        $request = Get-Content -LiteralPath $ownedPath -Raw | ConvertFrom-Json
        if (-not [string]::IsNullOrWhiteSpace([string]$request.requestId)) { $requestId = [string]$request.requestId }
        if (-not [string]::IsNullOrWhiteSpace([string]$request.jobClass)) { $jobClass = [string]$request.jobClass }
        Assert-PplAuthority $request $LaneId
        $pathState = Assert-PplBudgetAndPath $request $lane $budgetConfig
        $terminalPath = Join-Path ([string]$lane.readyRoot) ($requestId + '.terminal.json')
        if (Test-Path -LiteralPath $terminalPath -PathType Leaf) {
            $replayLeaf = $requestId + '.replay.' + $requestSha.Substring(0,12) + '.json'
            [IO.File]::Move($ownedPath,(Join-Path ([string]$lane.processedRoot) $replayLeaf))
            [ordered]@{state='EXACT_REPLAY_NO_DUPLICATE_RESPONSE';laneId=$LaneId;requestId=$requestId;mutationsPerformed=$true} | ConvertTo-Json -Compress
            return
        }
        [void](Write-PplLedgerState ([string]$lane.ledgerRoot) $requestId '010_RECEIVED.json' ([ordered]@{state='RECEIVED';requestId=$requestId;laneId=$LaneId;requestSha256=$requestSha;receivedUtc=[DateTime]::UtcNow.ToString('o')}))
        $handlerState = Join-Path (Join-Path ([string]$lane.ledgerRoot) $requestId) '020_HANDLER_COMPLETE.json'
        if (-not (Test-Path -LiteralPath $handlerState -PathType Leaf)) {
            if ([int]$request.fixture.delayMilliseconds -gt 0) { Start-Sleep -Milliseconds ([int]$request.fixture.delayMilliseconds) }
            [void](Write-PplLedgerState ([string]$lane.ledgerRoot) $requestId '020_HANDLER_COMPLETE.json' ([ordered]@{state='HANDLER_COMPLETE';requestId=$requestId;laneId=$LaneId;jobClass=$jobClass;completedUtc=[DateTime]::UtcNow.ToString('o')}))
        }
        if ([string]$request.fixture.fault -eq 'PROCESS_TERMINATION_AFTER_HANDLER') {
            $faultMarker = Join-Path (Join-Path ([string]$lane.ledgerRoot) $requestId) 'FAULT_PROCESS_TERMINATION_INJECTED'
            if (-not (Test-Path -LiteralPath $faultMarker)) {
                [IO.File]::WriteAllText($faultMarker,'OFFLINE_FIXTURE_FAULT',[Text.UTF8Encoding]::new($false))
                [Environment]::Exit(71)
            }
        }
        if ([string]$request.fixture.fault -eq 'RESPONSE_CONSTRUCTION_FAILURE') {
            $responseFaultMarker = Join-Path (Join-Path ([string]$lane.ledgerRoot) $requestId) 'FAULT_RESPONSE_CONSTRUCTION_INJECTED'
            if (-not (Test-Path -LiteralPath $responseFaultMarker)) {
                [IO.File]::WriteAllText($responseFaultMarker,'OFFLINE_FIXTURE_FAULT',[Text.UTF8Encoding]::new($false))
                throw 'INJECTED_RESPONSE_CONSTRUCTION_FAILURE'
            }
        }
        $manifest = [ordered]@{
            schema='argos_project_portal_parallel_lane_terminal_manifest_v1';requestId=$requestId;laneId=$LaneId;jobClass=$jobClass
            terminalState='PASS_REVIEW_ONLY_FIXTURE';requestSha256=$requestSha;compactFailure=$false
            completedUtc=[DateTime]::UtcNow.ToString('o');reviewOnly=$true;productionRoutingEnabled=$false;liveQualified=$false
        }
        $responsePath = Write-PplTerminal ([string]$lane.readyRoot) $manifest $key
        [void](Write-PplLedgerState ([string]$lane.ledgerRoot) $requestId '030_TERMINAL.json' ([ordered]@{state='TERMINAL_PASS';responsePath=$responsePath;responseSha256=(Get-PplHash $responsePath)}))
        [IO.File]::Move($ownedPath,(Join-Path ([string]$lane.processedRoot) ($requestId + '.processed.json')))
        [ordered]@{state='TERMINAL_PASS';laneId=$LaneId;requestId=$requestId;responsePath=$responsePath;mutationsPerformed=$true} | ConvertTo-Json -Compress
    }
    catch {
        $errorMessage = $_.Exception.Message
        $quarantinePath = Join-Path ([string]$lane.quarantineRoot) ($requestId + '.' + $requestSha.Substring(0,12) + '.failed.json')
        if (Test-Path -LiteralPath $ownedPath -PathType Leaf) {
            if (Test-Path -LiteralPath $quarantinePath) { $quarantinePath = $quarantinePath + '.' + [Guid]::NewGuid().ToString('N') }
            [IO.File]::Move($ownedPath,$quarantinePath)
        }
        $manifest = [ordered]@{
            schema='argos_project_portal_parallel_lane_terminal_manifest_v1';requestId=$requestId;laneId=$LaneId;jobClass=$jobClass
            terminalState='FAILED_REVIEW_ONLY_FIXTURE';requestSha256=$requestSha;compactFailure=$true;failureReason=$errorMessage
            completedUtc=[DateTime]::UtcNow.ToString('o');reviewOnly=$true;productionRoutingEnabled=$false;liveQualified=$false
        }
        $responsePath = Write-PplTerminal ([string]$lane.readyRoot) $manifest $key
        [void](Write-PplLedgerState ([string]$lane.ledgerRoot) $requestId '030_TERMINAL.json' ([ordered]@{state='TERMINAL_FAILED';responsePath=$responsePath;responseSha256=(Get-PplHash $responsePath);failureReason=$errorMessage}))
        [ordered]@{state='TERMINAL_FAILED_COMPACT_RESPONSE';laneId=$LaneId;requestId=$requestId;responsePath=$responsePath;failureReason=$errorMessage;mutationsPerformed=$true} | ConvertTo-Json -Compress
    }
}
finally {
    if ($laneLock) { $laneLock.Dispose() }
    if ($globalLock) { $globalLock.Dispose() }
}
