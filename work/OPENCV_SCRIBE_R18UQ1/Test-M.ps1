#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [string]$TestRoot,
    [string]$GatePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }
if ([string]$PSVersionTable.PSEdition -ne 'Desktop' -or $PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) {
    throw 'R18UQ1 maintenance rehearsal requires Windows PowerShell 5.1 exactly.'
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Get-Sha256([string]$Path) {
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}
function Write-JsonCreateNew([string]$Path, [object]$Value) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes((($Value | ConvertTo-Json -Depth 14) + [Environment]::NewLine))
    $stream = New-Object IO.FileStream($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
}

$queryPath = Join-Path $PSScriptRoot 'Q.ps1'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
foreach ($path in @($queryPath, $definitionPath)) {
    Require (Test-Path -LiteralPath $path -PathType Leaf) "R18UQ1 maintenance rehearsal dependency missing: $path"
}
$queryHash = Get-Sha256 $queryPath
$definition = Get-Content -LiteralPath $definitionPath -Raw | ConvertFrom-Json
Require ([string]$definition.state -ceq 'DRAFT_UNSIGNED_ROUTE_BLOCKED') 'R18UQ1 definition state changed.'
Require (@($definition.changes).Count -eq 1) 'R18UQ1 definition change cardinality changed.'
$change = $definition.changes[0]
Require ([string]$change.source -ceq 'payload/Q.ps1') 'R18UQ1 definition source changed.'
Require ([string]$change.destination -ceq 'C:\ProgramData\ArgosInsiteBridgeRO\diagnostics\R18UQ1.ps1') 'R18UQ1 installed destination changed.'
Require ([string]$change.installedSha256 -ceq $queryHash) 'R18UQ1 installed hash changed.'
Require ([bool]$change.allowCreate) 'R18UQ1 allowCreate changed.'
Require (@($change.approvedPredecessorSha256).Count -eq 1 -and [string]$change.approvedPredecessorSha256[0] -ceq $queryHash) 'R18UQ1 idempotent-only predecessor set changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 0) 'R18UQ1 task/process action boundary changed.'

if ($Preflight) {
    [ordered]@{
        schema = 'argos_r18uq1_maintenance_rehearsal_preflight_v1'
        state = 'PASS_R18UQ1_MAINTENANCE_REHEARSAL_PREFLIGHT'
        definitionSha256 = Get-Sha256 $definitionPath
        querySha256 = $queryHash
        outputPathsCreated = $false
        installedPathAccessed = $false
        taskOrProcessActionPerformed = $false
        signingKeyAccessed = $false
        mutationsPerformed = $false
    } | ConvertTo-Json -Depth 8 -Compress
    return
}

Require (-not [string]::IsNullOrWhiteSpace($TestRoot) -and -not [string]::IsNullOrWhiteSpace($GatePath)) 'Test requires TestRoot and GatePath.'
$root = [IO.Path]::GetFullPath($TestRoot)
$gate = [IO.Path]::GetFullPath($GatePath)
Require (-not (Test-Path -LiteralPath $root)) 'R18UQ1 maintenance rehearsal root must be fresh.'
Require (-not (Test-Path -LiteralPath $gate)) 'R18UQ1 maintenance rehearsal gate must be fresh.'
[void](New-Item -ItemType Directory -Path $root)
$cases = New-Object Collections.Generic.List[object]

$createRoot = Join-Path $root 'create'
[void](New-Item -ItemType Directory -Path $createRoot)
$createDestination = Join-Path $createRoot 'R18UQ1.ps1'
Require (-not (Test-Path -LiteralPath $createDestination)) 'R18UQ1 create fixture is not absent.'
Copy-Item -LiteralPath $queryPath -Destination $createDestination -ErrorAction Stop
Require ((Get-Sha256 $createDestination) -ceq $queryHash) 'R18UQ1 absent/create case changed bytes.'
$cases.Add([pscustomobject]@{id='ABSENT_CREATE';state='PASS';before='ABSENT';after=$queryHash;mutated=$true}) | Out-Null

$createRollbackRoot = Join-Path $root 'create_rollback'
[void](New-Item -ItemType Directory -Path $createRollbackRoot)
$createRollbackDestination = Join-Path $createRollbackRoot 'R18UQ1.ps1'
$createRollbackFailed = Join-Path $createRollbackRoot 'failed_new.ps1'
Copy-Item -LiteralPath $queryPath -Destination $createRollbackDestination -ErrorAction Stop
Move-Item -LiteralPath $createRollbackDestination -Destination $createRollbackFailed -ErrorAction Stop
Require (-not (Test-Path -LiteralPath $createRollbackDestination) -and (Get-Sha256 $createRollbackFailed) -ceq $queryHash) 'R18UQ1 absent/create rollback did not restore absence and quarantine new bytes.'
$cases.Add([pscustomobject]@{id='ABSENT_CREATE_ROLLBACK';state='PASS';before='ABSENT';after='ABSENT';failedNewSha256=Get-Sha256 $createRollbackFailed;mutated=$true}) | Out-Null

$idempotentRoot = Join-Path $root 'idempotent'
[void](New-Item -ItemType Directory -Path $idempotentRoot)
$idempotentDestination = Join-Path $idempotentRoot 'R18UQ1.ps1'
Copy-Item -LiteralPath $queryPath -Destination $idempotentDestination -ErrorAction Stop
$idempotentBefore = Get-Sha256 $idempotentDestination
Copy-Item -LiteralPath $queryPath -Destination $idempotentDestination -Force -ErrorAction Stop
$idempotentAfter = Get-Sha256 $idempotentDestination
Require ($idempotentBefore -ceq $queryHash -and $idempotentAfter -ceq $queryHash) 'R18UQ1 target-idempotent case failed.'
$cases.Add([pscustomobject]@{id='TARGET_IDEMPOTENT';state='PASS';before=$idempotentBefore;after=$idempotentAfter;mutated=$true}) | Out-Null

$unapprovedRoot = Join-Path $root 'unapproved'
[void](New-Item -ItemType Directory -Path $unapprovedRoot)
$unapprovedDestination = Join-Path $unapprovedRoot 'R18UQ1.ps1'
[IO.File]::WriteAllText($unapprovedDestination, 'UNAPPROVED', (New-Object Text.UTF8Encoding($false)))
$unapprovedBefore = Get-Sha256 $unapprovedDestination
$approved = @($change.approvedPredecessorSha256) -contains $unapprovedBefore
Require (-not $approved -and (Get-Sha256 $unapprovedDestination) -ceq $unapprovedBefore) 'R18UQ1 unapproved predecessor was not refused before mutation.'
$cases.Add([pscustomobject]@{id='UNAPPROVED_REFUSED';state='PASS';before=$unapprovedBefore;after=$unapprovedBefore;mutated=$false}) | Out-Null

$rollbackRoot = Join-Path $root 'existing_rollback'
[void](New-Item -ItemType Directory -Path $rollbackRoot)
$rollbackDestination = Join-Path $rollbackRoot 'R18UQ1.ps1'
$rollbackPrior = Join-Path $rollbackRoot 'prior.ps1'
$rollbackFailed = Join-Path $rollbackRoot 'failed_current.ps1'
Copy-Item -LiteralPath $queryPath -Destination $rollbackDestination -ErrorAction Stop
Copy-Item -LiteralPath $rollbackDestination -Destination $rollbackPrior -ErrorAction Stop
[IO.File]::WriteAllText($rollbackDestination, 'INJECTED_POST_SWAP_FAILURE', (New-Object Text.UTF8Encoding($false)))
Move-Item -LiteralPath $rollbackDestination -Destination $rollbackFailed -ErrorAction Stop
Copy-Item -LiteralPath $rollbackPrior -Destination $rollbackDestination -ErrorAction Stop
Require ((Get-Sha256 $rollbackDestination) -ceq $queryHash -and (Get-Sha256 $rollbackFailed) -cne $queryHash) 'R18UQ1 existing-target rollback case failed.'
$cases.Add([pscustomobject]@{id='EXISTING_TARGET_ROLLBACK';state='PASS';before=$queryHash;after=Get-Sha256 $rollbackDestination;failedBytesQuarantined=$true;mutated=$true}) | Out-Null

$gateValue = [ordered]@{
    schema = 'argos_r18uq1_maintenance_semantics_rehearsal_gate_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_R18UQ1_LOCAL_MAINTENANCE_SEMANTICS_REHEARSAL'
    windowsPowerShell = [ordered]@{major=5;minor=1;version=$PSVersionTable.PSVersion.ToString()}
    definitionSha256 = Get-Sha256 $definitionPath
    querySha256 = $queryHash
    caseIds = @($cases | ForEach-Object { [string]$_.id })
    cases = $cases.ToArray()
    absentCreatePassed = $true
    absentCreateRollbackPassed = $true
    targetIdempotenceAccepted = $true
    unapprovedPredecessorRefusedBeforeMutation = $true
    existingTargetRollbackPassed = $true
    simulationOnly = $true
    exactEndpointWorkerInvoked = $false
    endpointQueueSafetyProved = $false
    signingKeyAccessed = $false
    portalOrShareAccessed = $false
    argosOrJbodAccessed = $false
    taskOrProcessActionPerformed = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}
Write-JsonCreateNew -Path $gate -Value $gateValue
$gateValue | ConvertTo-Json -Depth 14 -Compress
