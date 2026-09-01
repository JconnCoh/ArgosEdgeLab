#Requires -Version 5.1
[CmdletBinding(DefaultParameterSetName='Preflight')]
param(
    [Parameter(Mandatory=$true)][string]$ArtifactRoot,
    [Parameter(Mandatory=$true)][string]$FixtureRoot,
    [Parameter(ParameterSetName='Preflight')][switch]$Preflight,
    [Parameter(ParameterSetName='Gate')][switch]$Gate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-PplTest([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Write-PplTestJson([string]$Path, $Value) {
    $json = $Value | ConvertTo-Json -Depth 24
    [IO.File]::WriteAllText($Path,$json,[Text.UTF8Encoding]::new($false))
}

function New-PplRequest([string]$RequestId,[string]$LaneId,[string]$JobClass,[string]$OutputRoot,[int]$Delay,[string]$Fault='NONE') {
    $taskAction = $LaneId -eq 'CONTROL' -and $JobClass -in @('MAINTENANCE_PATCH','CONFIG_ACTION','TASK_ACTION','PROCESS_ACTION')
    [ordered]@{
        schema='argos_project_portal_parallel_lane_request_v1';requestId=$RequestId;laneId=$LaneId;jobClass=$JobClass
        authority=[ordered]@{reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;sourceMutationAllowed=$false;taskProcessActionAllowed=$taskAction}
        budget=[ordered]@{cpuSeconds=30;memoryMiB=128;diskMiB=32}
        outputRoot=$OutputRoot;shortAliasVerified=$false
        fixture=[ordered]@{delayMilliseconds=$Delay;fault=$Fault}
    }
}

function Start-PplChild([string]$LaneId) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $info.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $script:dispatcherPath + '" -ConfigPath "' + $script:runtimeConfigPath + '" -LaneId ' + $LaneId + ' -RunOne'
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    Assert-PplTest $process.Start() 'Failed to start Windows PowerShell 5.1 dispatcher child.'
    $process
}

function Complete-PplChild([Diagnostics.Process]$Process) {
    Assert-PplTest $Process.WaitForExit(30000) 'Dispatcher child exceeded 30 seconds.'
    $stdout = $Process.StandardOutput.ReadToEnd().Trim()
    $stderr = $Process.StandardError.ReadToEnd().Trim()
    [pscustomobject]@{exitCode=$Process.ExitCode;stdout=$stdout;stderr=$stderr}
}

function Invoke-PplChild([string]$LaneId) {
    Complete-PplChild (Start-PplChild $LaneId)
}

function Add-PplCheck([string]$Name, [string]$State, $Evidence) {
    $script:checks.Add([pscustomobject]@{name=$Name;state=$State;evidence=$Evidence})
}

function Get-PplExactLengthPath([int]$Length) {
    $value = 'C:\'
    $index = 0
    while ($value.Length -lt $Length) {
        $remaining = $Length - $value.Length
        if ($remaining -eq 1) { $value += 'x'; break }
        if ($value.Length -gt 3) { $value += '\'; $remaining-- }
        $take = [Math]::Min(20,$remaining)
        $value += ([char](97 + ($index % 20))).ToString() * $take
        $index++
    }
    Assert-PplTest ($value.Length -eq $Length) "Failed to construct exact path length $Length."
    $value
}

function Invoke-PplPathEvaluation([int]$EffectiveLength,[bool]$Alias) {
    $physicalLength = $EffectiveLength - 32
    $path = Get-PplExactLengthPath $physicalLength
    $output = $null
    if ($Alias) {
        $output = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $script:dispatcherPath -ConfigPath $script:runtimeConfigPath -LaneId REVIEW_A -EvaluatePath $path -ShortAliasVerified
    } else {
        $output = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $script:dispatcherPath -ConfigPath $script:runtimeConfigPath -LaneId REVIEW_A -EvaluatePath $path
    }
    $output | ConvertFrom-Json
}

function Test-PplEnvelope([string]$Path,[byte[]]$Key) {
    $envelope = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    Assert-PplTest ([string]$envelope.schema -eq 'argos_project_portal_parallel_lane_terminal_envelope_v1') 'Terminal envelope schema changed.'
    $manifestJson = $envelope.manifest | ConvertTo-Json -Depth 16 -Compress
    $hmac = [Security.Cryptography.HMACSHA256]::new($Key)
    try {
        $actual = ([BitConverter]::ToString($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($manifestJson)))).Replace('-','')
    } finally { $hmac.Dispose() }
    Assert-PplTest ($actual -eq [string]$envelope.signature.value) "Offline fixture terminal integrity failed: $Path"
    $envelope
}

$artifactFull = [IO.Path]::GetFullPath($ArtifactRoot)
$fixtureFull = [IO.Path]::GetFullPath($FixtureRoot)
$script:dispatcherPath = Join-Path $artifactFull 'Invoke-ArgosPortalLaneDispatcherPrototype.ps1'
$topologyPath = Join-Path $artifactFull 'PORTAL_PARALLEL_LANES_V1_TOPOLOGY.json'
$lockPath = Join-Path $artifactFull 'PORTAL_PARALLEL_LANES_V1_LOCK_MATRIX.json'
$budgetPath = Join-Path $artifactFull 'PORTAL_PARALLEL_LANES_V1_BUDGETS.json'
$schemaPath = Join-Path $artifactFull 'PORTAL_PARALLEL_LANES_V1_REQUEST.schema.json'
foreach ($path in @($script:dispatcherPath,$topologyPath,$lockPath,$budgetPath,$schemaPath)) {
    Assert-PplTest (Test-Path -LiteralPath $path -PathType Leaf) "Required PPL1 artifact is absent: $path"
}
Assert-PplTest ((Get-Content -LiteralPath $topologyPath -Raw | ConvertFrom-Json).offlineFixtureOnly) 'Topology is not fixture-only.'
Assert-PplTest (-not (Get-Content -LiteralPath $topologyPath -Raw | ConvertFrom-Json).liveQualified) 'Topology incorrectly claims live qualification.'
Assert-PplTest ([string](Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json).schema -eq 'argos_project_portal_parallel_lanes_lock_matrix_v1') 'Lock schema changed.'
Assert-PplTest ([string](Get-Content -LiteralPath $budgetPath -Raw | ConvertFrom-Json).schema -eq 'argos_project_portal_parallel_lanes_budgets_v1') 'Budget schema changed.'

if ($Preflight) {
    [ordered]@{
        schema='argos_project_portal_parallel_lanes_rehearsal_preflight_v1';state='PASS_PPL1_NON_MUTATING_PREFLIGHT'
        artifactRoot=$artifactFull;fixtureRoot=$fixtureFull;fixtureExists=(Test-Path -LiteralPath $fixtureFull)
        dispatcherSha256=(Get-FileHash -LiteralPath $script:dispatcherPath -Algorithm SHA256).Hash
        topologySha256=(Get-FileHash -LiteralPath $topologyPath -Algorithm SHA256).Hash
        mutationsPerformed=$false;liveQualified=$false
    } | ConvertTo-Json -Depth 5 -Compress
    return
}

if (-not $Gate) { throw 'Gate is required for fixture execution.' }
Assert-PplTest (-not (Test-Path -LiteralPath $fixtureFull)) 'Fixture root must be fresh.'
[void][IO.Directory]::CreateDirectory($fixtureFull)
$lockRoot = Join-Path $fixtureFull 'locks'
[void][IO.Directory]::CreateDirectory($lockRoot)
foreach ($leaf in @('global.lock','CONTROL.lock','REVIEW_A.lock','REVIEW_B.lock')) {
    [IO.File]::WriteAllText((Join-Path $lockRoot $leaf),'PPL1',[Text.UTF8Encoding]::new($false))
}
$lanes = [ordered]@{}
foreach ($laneId in @('CONTROL','REVIEW_A','REVIEW_B')) {
    $laneRoot = Join-Path $fixtureFull $laneId
    $lane = [ordered]@{}
    foreach ($pair in @(@('incomingRoot','i'),@('workRoot','w'),@('readyRoot','r'),@('quarantineRoot','q'),@('ledgerRoot','l'),@('outputRoot','o'),@('processedRoot','d'))) {
        $path = Join-Path $laneRoot $pair[1]
        [void][IO.Directory]::CreateDirectory($path)
        $lane[$pair[0]] = $path
    }
    $lanes[$laneId] = $lane
}
$key = [byte[]](1..32)
$script:runtimeConfigPath = Join-Path $fixtureFull 'runtime.json'
Write-PplTestJson $script:runtimeConfigPath ([ordered]@{
    schema='argos_project_portal_parallel_lanes_offline_runtime_v1';offlineFixtureOnly=$true;liveQualified=$false
    fixtureRoot=$fixtureFull;globalLockRoot=$lockRoot;budgetsPath=$budgetPath;fixtureHmacKeyBase64=[Convert]::ToBase64String($key);lanes=$lanes
})
$script:checks = [Collections.Generic.List[object]]::new()

foreach ($laneId in @('CONTROL','REVIEW_A','REVIEW_B')) {
    $pre = & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File $script:dispatcherPath -ConfigPath $script:runtimeConfigPath -LaneId $laneId -Preflight | ConvertFrom-Json
    Assert-PplTest ([string]$pre.state -eq 'PASS_OFFLINE_FIXTURE_DISPATCHER_PREFLIGHT') "Dispatcher preflight failed for $laneId."
}
Add-PplCheck 'WINDOWS_POWERSHELL_5_1_EXACT_PREFLIGHT_ALL_LANES' 'PASS' @{laneCount=3}
$zeroRows = @(foreach ($laneId in @('CONTROL','REVIEW_A','REVIEW_B')) { Invoke-PplChild $laneId })
Assert-PplTest (@($zeroRows | Where-Object { ($_.stdout | ConvertFrom-Json).state -ne 'LANE_IDLE' }).Count -eq 0) 'ZERO collection case did not remain idle.'
Add-PplCheck 'COLLECTION_CASE_ZERO' 'PASS' @{caseId='ZERO';laneCount=3;requestCount=0}

# Two compute lanes overlap in wall time and return lane-correlated terminals.
Write-PplTestJson (Join-Path $lanes.REVIEW_A.incomingRoot '001_A_SIM.ready.json') (New-PplRequest 'REQ_A_SIM_0001' 'REVIEW_A' 'REVIEW_DETECTOR' (Join-Path $lanes.REVIEW_A.outputRoot 'sim') 1200)
Write-PplTestJson (Join-Path $lanes.REVIEW_B.incomingRoot '001_B_SIM.ready.json') (New-PplRequest 'REQ_B_SIM_0001' 'REVIEW_B' 'REVIEW_OCR' (Join-Path $lanes.REVIEW_B.outputRoot 'sim') 1200)
$clock = [Diagnostics.Stopwatch]::StartNew()
$pa = Start-PplChild 'REVIEW_A'; $pb = Start-PplChild 'REVIEW_B'
$ra = Complete-PplChild $pa; $rb = Complete-PplChild $pb
$clock.Stop()
Assert-PplTest ($ra.exitCode -eq 0 -and $rb.exitCode -eq 0) 'Simultaneous compute child failed.'
$aReceived = [DateTime]::Parse((Get-Content -LiteralPath (Join-Path $lanes.REVIEW_A.ledgerRoot 'REQ_A_SIM_0001\010_RECEIVED.json') -Raw | ConvertFrom-Json).receivedUtc).ToUniversalTime()
$aComplete = [DateTime]::Parse((Get-Content -LiteralPath (Join-Path $lanes.REVIEW_A.ledgerRoot 'REQ_A_SIM_0001\020_HANDLER_COMPLETE.json') -Raw | ConvertFrom-Json).completedUtc).ToUniversalTime()
$bReceived = [DateTime]::Parse((Get-Content -LiteralPath (Join-Path $lanes.REVIEW_B.ledgerRoot 'REQ_B_SIM_0001\010_RECEIVED.json') -Raw | ConvertFrom-Json).receivedUtc).ToUniversalTime()
$bComplete = [DateTime]::Parse((Get-Content -LiteralPath (Join-Path $lanes.REVIEW_B.ledgerRoot 'REQ_B_SIM_0001\020_HANDLER_COMPLETE.json') -Raw | ConvertFrom-Json).completedUtc).ToUniversalTime()
$overlapStart = $bReceived
if ($aReceived -gt $bReceived) { $overlapStart = $aReceived }
$overlapEnd = $bComplete
if ($aComplete -lt $bComplete) { $overlapEnd = $aComplete }
$overlapMilliseconds = [int]($overlapEnd - $overlapStart).TotalMilliseconds
Assert-PplTest ($overlapMilliseconds -ge 1000) "Compute handler intervals did not overlap: ${overlapMilliseconds}ms"
Add-PplCheck 'SIMULTANEOUS_REVIEW_DETECTOR_AND_OCR' 'PASS' @{processWallMilliseconds=$clock.ElapsedMilliseconds;handlerOverlapMilliseconds=$overlapMilliseconds}
Add-PplCheck 'COLLECTION_CASE_ONE' 'PASS' @{caseId='ONE';requestCountPerComputeLane=1}

# REVIEW_A terminates after handler completion while REVIEW_B still succeeds; restart resumes A exactly once.
Write-PplTestJson (Join-Path $lanes.REVIEW_A.incomingRoot '002_A_CRASH.ready.json') (New-PplRequest 'REQ_A_CRASH_01' 'REVIEW_A' 'REVIEW_DETECTOR' (Join-Path $lanes.REVIEW_A.outputRoot 'crash') 300 'PROCESS_TERMINATION_AFTER_HANDLER')
Write-PplTestJson (Join-Path $lanes.REVIEW_B.incomingRoot '002_B_OK.ready.json') (New-PplRequest 'REQ_B_CRASHPEER_01' 'REVIEW_B' 'REVIEW_OCR' (Join-Path $lanes.REVIEW_B.outputRoot 'peer') 300)
$pa = Start-PplChild 'REVIEW_A'; $pb = Start-PplChild 'REVIEW_B'
$ra = Complete-PplChild $pa; $rb = Complete-PplChild $pb
Assert-PplTest ($ra.exitCode -eq 71) "Crash fixture exit changed: $($ra.exitCode)"
Assert-PplTest ($rb.exitCode -eq 0 -and ($rb.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS') 'Peer compute lane was blocked by the crash.'
$restart = Invoke-PplChild 'REVIEW_A'
Assert-PplTest ($restart.exitCode -eq 0 -and ($restart.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS') 'Crash restart did not resume to terminal response.'
Add-PplCheck 'COMPUTE_CRASH_RESTART_AND_SECOND_LANE_SUCCESS' 'PASS' @{crashExit=71;peerTerminal=$true;restartTerminal=$true}

# Normal response construction fails inside the per-request boundary and commits a compact terminal.
Write-PplTestJson (Join-Path $lanes.REVIEW_B.incomingRoot '003_B_RFAIL.ready.json') (New-PplRequest 'REQ_B_RFAIL_01' 'REVIEW_B' 'REVIEW_OCR' (Join-Path $lanes.REVIEW_B.outputRoot 'rfail') 0 'RESPONSE_CONSTRUCTION_FAILURE')
$rfail = Invoke-PplChild 'REVIEW_B'
Assert-PplTest (($rfail.stdout | ConvertFrom-Json).state -eq 'TERMINAL_FAILED_COMPACT_RESPONSE') 'Response failure did not commit compact terminal.'
Add-PplCheck 'RESPONSE_CONSTRUCTION_FAILURE_COMPACT_TERMINAL' 'PASS' @{requestId='REQ_B_RFAIL_01'}

# Malformed queue head is quarantined and cannot poison the next valid request.
[IO.File]::WriteAllText((Join-Path $lanes.REVIEW_A.incomingRoot '003_000_POISON.ready.json'),'{broken',[Text.UTF8Encoding]::new($false))
Write-PplTestJson (Join-Path $lanes.REVIEW_A.incomingRoot '003_100_AFTER.ready.json') (New-PplRequest 'REQ_A_AFTER_POISON_01' 'REVIEW_A' 'REVIEW_DETECTOR' (Join-Path $lanes.REVIEW_A.outputRoot 'after') 0)
$poison = Invoke-PplChild 'REVIEW_A'; $afterPoison = Invoke-PplChild 'REVIEW_A'
Assert-PplTest (($poison.stdout | ConvertFrom-Json).state -eq 'TERMINAL_FAILED_COMPACT_RESPONSE') 'Poison did not reach a compact terminal.'
Assert-PplTest (($afterPoison.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS') 'Valid request behind poison did not complete.'
Add-PplCheck 'QUEUE_HEAD_POISON_ADVANCES_TO_NEXT_REQUEST' 'PASS' @{poisonTerminal=$true;nextTerminal=$true}

# A pre-existing work collision is terminalized independently, then the queued request succeeds.
[IO.File]::WriteAllText((Join-Path $lanes.REVIEW_A.workRoot '004_COLLISION.work.json'),'{stale',[Text.UTF8Encoding]::new($false))
Write-PplTestJson (Join-Path $lanes.REVIEW_A.incomingRoot '004_COLLISION.ready.json') (New-PplRequest 'REQ_A_COLLISION_01' 'REVIEW_A' 'REVIEW_DETECTOR' (Join-Path $lanes.REVIEW_A.outputRoot 'collision') 0)
$stale = Invoke-PplChild 'REVIEW_A'; $collisionNext = Invoke-PplChild 'REVIEW_A'
Assert-PplTest (($stale.stdout | ConvertFrom-Json).state -eq 'TERMINAL_FAILED_COMPACT_RESPONSE') 'Stale work did not terminalize.'
Assert-PplTest (($collisionNext.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS') 'Queued request after stale work did not succeed.'
Add-PplCheck 'PREEXISTING_WORK_COLLISION_DOES_NOT_POISON_LANE' 'PASS' @{staleTerminal=$true;nextTerminal=$true}

# Replay the exact processed request: no second terminal response is created.
$processedCollision = Join-Path $lanes.REVIEW_A.processedRoot 'REQ_A_COLLISION_01.processed.json'
[IO.File]::Copy($processedCollision,(Join-Path $lanes.REVIEW_A.incomingRoot '005_REPLAY.ready.json'))
$beforeReplay = @(Get-ChildItem -LiteralPath $lanes.REVIEW_A.readyRoot -Filter 'REQ_A_COLLISION_01.terminal.json').Count
$replay = Invoke-PplChild 'REVIEW_A'
$afterReplay = @(Get-ChildItem -LiteralPath $lanes.REVIEW_A.readyRoot -Filter 'REQ_A_COLLISION_01.terminal.json').Count
Assert-PplTest (($replay.stdout | ConvertFrom-Json).state -eq 'EXACT_REPLAY_NO_DUPLICATE_RESPONSE' -and $beforeReplay -eq 1 -and $afterReplay -eq 1) 'Exactly-once replay gate failed.'
Add-PplCheck 'PROCESS_RESTART_IDEMPOTENT_RECEIPT' 'PASS' @{terminalBefore=1;terminalAfter=1}

# CONTROL admits only one worker, and a CONTROL request excludes compute until terminal.
Write-PplTestJson (Join-Path $lanes.CONTROL.incomingRoot '001_C_ONE.ready.json') (New-PplRequest 'REQ_C_SERIAL_01' 'CONTROL' 'STATUS' (Join-Path $lanes.CONTROL.outputRoot 'c1') 3000)
Write-PplTestJson (Join-Path $lanes.CONTROL.incomingRoot '002_C_TWO.ready.json') (New-PplRequest 'REQ_C_SERIAL_02' 'CONTROL' 'DATA_PULL' (Join-Path $lanes.CONTROL.outputRoot 'c2') 0)
$pc1 = Start-PplChild 'CONTROL'
$serialReceived = Join-Path $lanes.CONTROL.ledgerRoot 'REQ_C_SERIAL_01\010_RECEIVED.json'
$deadline = [DateTime]::UtcNow.AddSeconds(10)
while (-not (Test-Path -LiteralPath $serialReceived) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
Assert-PplTest (Test-Path -LiteralPath $serialReceived) 'First CONTROL worker did not acquire its request in time.'
$pc2 = Start-PplChild 'CONTROL'
$rc2 = Complete-PplChild $pc2; $rc1 = Complete-PplChild $pc1
Assert-PplTest (($rc2.stdout | ConvertFrom-Json).state -in @('LANE_BUSY_GLOBAL_LOCK','LANE_BUSY_OWN_LOCK')) 'Second CONTROL worker was not serialized.'
$c2 = Invoke-PplChild 'CONTROL'
Assert-PplTest (($rc1.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS' -and ($c2.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS') 'Serialized CONTROL requests did not both terminate.'
Add-PplCheck 'CONTROL_LANE_SERIALIZED' 'PASS' @{secondWorkerBusy=$true;terminalCount=2}
Add-PplCheck 'COLLECTION_CASE_MANY' 'PASS' @{caseId='MANY';controlQueueCount=2;serialized=$true}

Write-PplTestJson (Join-Path $lanes.CONTROL.incomingRoot '003_C_BLOCK.ready.json') (New-PplRequest 'REQ_C_BLOCK_01' 'CONTROL' 'MAINTENANCE_PATCH' (Join-Path $lanes.CONTROL.outputRoot 'cb') 3000)
Write-PplTestJson (Join-Path $lanes.REVIEW_B.incomingRoot '004_B_BLOCKED.ready.json') (New-PplRequest 'REQ_B_AFTER_CONTROL_01' 'REVIEW_B' 'REVIEW_OCR' (Join-Path $lanes.REVIEW_B.outputRoot 'blocked') 0)
$pc = Start-PplChild 'CONTROL'
$blockReceived = Join-Path $lanes.CONTROL.ledgerRoot 'REQ_C_BLOCK_01\010_RECEIVED.json'
$deadline = [DateTime]::UtcNow.AddSeconds(10)
while (-not (Test-Path -LiteralPath $blockReceived) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 50 }
Assert-PplTest (Test-Path -LiteralPath $blockReceived) 'CONTROL exclusive worker did not acquire its request in time.'
$blocked = Invoke-PplChild 'REVIEW_B'; $controlDone = Complete-PplChild $pc
Assert-PplTest (($blocked.stdout | ConvertFrom-Json).state -eq 'LANE_BUSY_GLOBAL_LOCK') 'Compute entered during CONTROL exclusive resource ownership.'
$afterControl = Invoke-PplChild 'REVIEW_B'
Assert-PplTest (($controlDone.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS' -and ($afterControl.stdout | ConvertFrom-Json).state -eq 'TERMINAL_PASS') 'Compute did not continue after CONTROL terminal.'
Add-PplCheck 'CONTROL_EXCLUSIVE_RESOURCE_LOCK_MATRIX' 'PASS' @{computeBlockedDuringControl=$true;computeSucceededAfter=$true}

# Exact effective path boundaries: 199 passes, 200/229 require alias, and 230 hard-stops.
$p199 = Invoke-PplPathEvaluation 199 $false
$p200n = Invoke-PplPathEvaluation 200 $false
$p200y = Invoke-PplPathEvaluation 200 $true
$p229n = Invoke-PplPathEvaluation 229 $false
$p229y = Invoke-PplPathEvaluation 229 $true
$p230 = Invoke-PplPathEvaluation 230 $true
Assert-PplTest ($p199.state -eq 'PASS' -and $p200n.state -eq 'SHORT_ALIAS_REQUIRED' -and $p200y.state -eq 'PASS' -and $p229n.state -eq 'SHORT_ALIAS_REQUIRED' -and $p229y.state -eq 'PASS' -and $p230.state -eq 'HARD_STOP') 'Path boundary matrix failed.'
Add-PplCheck 'PATH_EFFECTIVE_BOUNDARIES_199_200_229_230' 'PASS' @{at199=$p199.state;at200NoAlias=$p200n.state;at200Alias=$p200y.state;at229NoAlias=$p229n.state;at229Alias=$p229y.state;at230=$p230.state}

$terminalFiles = @(foreach ($laneId in @('CONTROL','REVIEW_A','REVIEW_B')) { Get-ChildItem -LiteralPath $lanes[$laneId].readyRoot -Filter '*.terminal.json' -File })
Assert-PplTest ($terminalFiles.Count -eq 13) "Terminal response count changed: $($terminalFiles.Count)"
$terminalRows = @($terminalFiles | ForEach-Object { Test-PplEnvelope $_.FullName $key })
$correlationMismatch = @($terminalRows | Where-Object { [string]$_.manifest.laneId -notin @('CONTROL','REVIEW_A','REVIEW_B') -or [string]::IsNullOrWhiteSpace([string]$_.manifest.requestId) }).Count
Assert-PplTest ($correlationMismatch -eq 0) 'Terminal lane/request correlation failed.'
$ledgerTerminalCount = @(foreach ($laneId in @('CONTROL','REVIEW_A','REVIEW_B')) { Get-ChildItem -LiteralPath $lanes[$laneId].ledgerRoot -Filter '030_TERMINAL.json' -File -Recurse }).Count
Assert-PplTest ($ledgerTerminalCount -eq $terminalFiles.Count) 'Per-lane exactly-once ledger/terminal cardinality differs.'
Add-PplCheck 'OFFLINE_INTEGRITY_SEALED_TERMINALS_NOT_LOST' 'PASS' @{terminalCount=$terminalFiles.Count;ledgerTerminalCount=$ledgerTerminalCount;correlationMismatchCount=0;signatureMode='HMACSHA256_OFFLINE_FIXTURE_ONLY'}

$result = [ordered]@{
    schema='argos_project_portal_parallel_lanes_v1_rehearsal_gate';createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_PPL1_OFFLINE_PARALLEL_LANE_REHEARSAL';windowsPowerShell=$PSVersionTable.PSVersion.ToString()
    fixtureRoot=$fixtureFull;checkCount=$script:checks.Count;checks=@($script:checks)
    collectionCaseIds=@('ZERO','ONE','MANY')
    terminalResponseCount=$terminalFiles.Count;perLaneLedgerTerminalCount=$ledgerTerminalCount
    offlineSignatureMode='HMACSHA256_OFFLINE_FIXTURE_ONLY';liveSignerQualified=$false
    installedRouteChanged=$false;liveGatewayContacted=$false;liveArgosContacted=$false;liveJbodContacted=$false
    fallbackSingleLaneChanged=$false;reviewOnly=$true;productionRoutingEnabled=$false;liveQualified=$false
}
$result | ConvertTo-Json -Depth 12
