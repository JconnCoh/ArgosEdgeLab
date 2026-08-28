[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [ValidateSet('ZERO','ONE','MANY','ERROR','TIMEOUT')][string]$RehearsalCase = 'ONE'
)
$directObserverExecutor = {
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory = $true, ParameterSetName = 'Path')][string]$RequestPath,
    [Parameter(Mandatory = $true, ParameterSetName = 'Json')][string]$RequestJson,
    [switch]$Preflight,
    [switch]$Rehearsal,
    [ValidateSet('ZERO','ONE','MANY','ERROR','TIMEOUT')][string]$RehearsalCase = 'ZERO',
    [switch]$Execute,
    [switch]$EmitClipboard
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$requestSchemaSha256 = 'EAF4AE35296570B95DF885F9AC88D980BFFFED3AC657F1E1642BA3A2F1D8D50F'
$resultSchemaSha256 = 'B8FDE1122A182ABB7B2D96C79230CEC9C0591D5DC259FF409DF90FB0B3AD615A'
$requestSchema = 'argos_direct_observation_request_v1'
$resultSchema = 'argos_direct_observation_result_v1'
$progressSchema = 'argos_direct_observation_progress_v1'
$operationName = 'WINDOWS_PROCESS_SNAPSHOT'

function Get-TextSha256([string]$Text) {
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Get-ExactPropertyNames([object]$Value) {
    if ($Value -is [Collections.IDictionary]) {
        return @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    }
    return @($Value.PSObject.Properties | ForEach-Object { [string]$_.Name } | Sort-Object)
}

function Assert-ExactPropertySet([object]$Value, [string[]]$Expected, [string]$Context) {
    $actualNames = @(Get-ExactPropertyNames -Value $Value)
    $expectedNames = @($Expected | Sort-Object)
    $missing = @($expectedNames | Where-Object { $actualNames -notcontains $_ })
    $extra = @($actualNames | Where-Object { $expectedNames -notcontains $_ })
    if ($missing.Count -ne 0 -or $extra.Count -ne 0) {
        throw "$Context property mismatch. Missing=$($missing -join ',') Extra=$($extra -join ',')"
    }
}

function Assert-BoundedString([string]$Value, [int]$Minimum, [int]$Maximum, [string]$Name) {
    if ($null -eq $Value -or $Value.Length -lt $Minimum -or $Value.Length -gt $Maximum) {
        throw "$Name length is outside [$Minimum,$Maximum]."
    }
}

function Read-RequestText {
    if ($PSCmdlet.ParameterSetName -eq 'Path') {
        $resolvedRequestPath = [IO.Path]::GetFullPath($RequestPath)
        if (-not (Test-Path -LiteralPath $resolvedRequestPath -PathType Leaf)) {
            throw "Request file is absent: $resolvedRequestPath"
        }
        $text = [IO.File]::ReadAllText($resolvedRequestPath, [Text.UTF8Encoding]::new($false))
    }
    else {
        $text = $RequestJson
    }
    $text = $text.Trim()
    Assert-BoundedString -Value $text -Minimum 2 -Maximum 8192 -Name 'RequestJson'
    return $text
}

function Read-And-ValidateRequest([string]$Text) {
    $request = $Text | ConvertFrom-Json -ErrorAction Stop
    $rootProperties = @(
        'schema','revision','requestSchemaSha256','resultSchemaSha256','nonce',
        'expectedComputerName','operation','operationTimeoutSeconds','maximumRows',
        'maximumFieldCharacters','expectedScalar','parameters','authority'
    )
    Assert-ExactPropertySet -Value $request -Expected $rootProperties -Context 'Request root'
    Assert-ExactPropertySet -Value $request.parameters -Expected @('processName','exactExecutablePath','commandLineContains') -Context 'Request parameters'
    Assert-ExactPropertySet -Value $request.authority -Expected @(
        'reviewOnly','taskOrProcessManagementAllowed','imageReadAllowed','sourceMutationAllowed',
        'targetPersistentMutationAllowed','providerActivationAllowed','productionRoutingAllowed',
        'retryAuthorized','maximumExecutions'
    ) -Context 'Request authority'

    if ([string]$request.schema -cne $requestSchema) { throw 'Unexpected request schema.' }
    if ([string]$request.requestSchemaSha256 -cne $requestSchemaSha256) { throw 'Request schema hash mismatch.' }
    if ([string]$request.resultSchemaSha256 -cne $resultSchemaSha256) { throw 'Result schema hash mismatch.' }
    if ([string]$request.operation -cne $operationName) { throw 'Unsupported operation.' }
    if ([string]$request.revision -cnotmatch '^[A-Z0-9_]{8,96}$') { throw 'Invalid revision.' }
    if ([string]$request.nonce -cnotmatch '^[A-Z0-9_]{16,96}$') { throw 'Invalid nonce.' }
    if ([string]$request.expectedComputerName -cnotmatch '^[A-Z0-9-]{1,32}$') { throw 'Invalid expected computer name.' }
    if ([string]$request.expectedScalar -cnotmatch '^PASS_[A-Z0-9_]{8,120}$') { throw 'Invalid expected scalar.' }
    if ([int]$request.operationTimeoutSeconds -lt 1 -or [int]$request.operationTimeoutSeconds -gt 15) { throw 'Invalid operation timeout.' }
    if ([int]$request.maximumRows -lt 1 -or [int]$request.maximumRows -gt 16) { throw 'Invalid maximum rows.' }
    if ([int]$request.maximumFieldCharacters -lt 64 -or [int]$request.maximumFieldCharacters -gt 4096) { throw 'Invalid maximum field characters.' }
    if ([string]$request.parameters.processName -cnotmatch '^[A-Za-z0-9_.-]{1,64}$') { throw 'Invalid process name.' }
    Assert-BoundedString -Value ([string]$request.parameters.exactExecutablePath) -Minimum 3 -Maximum 260 -Name 'exactExecutablePath'
    Assert-BoundedString -Value ([string]$request.parameters.commandLineContains) -Minimum 1 -Maximum 512 -Name 'commandLineContains'

    if (-not [bool]$request.authority.reviewOnly) { throw 'reviewOnly must be true.' }
    foreach ($property in @(
        'taskOrProcessManagementAllowed','imageReadAllowed','sourceMutationAllowed',
        'targetPersistentMutationAllowed','providerActivationAllowed','productionRoutingAllowed',
        'retryAuthorized'
    )) {
        if ([bool]$request.authority.$property) { throw "$property must be false." }
    }
    if ([int]$request.authority.maximumExecutions -ne 1) { throw 'maximumExecutions must equal one.' }
    return $request
}

function New-Result(
    [object]$Request,
    [string]$RequestSha256,
    [string]$State,
    [string]$OperationState,
    [string]$Scalar,
    [int]$CandidateProcessCount,
    [int]$ExactPathCount,
    [object[]]$Rows,
    [string]$ErrorMessage,
    [string]$ComputerName
) {
    return [ordered]@{
        schema = $resultSchema
        state = $State
        nonce = [string]$Request.nonce
        computerName = $ComputerName
        scalar = $Scalar
        requestSha256 = $RequestSha256
        requestSchemaSha256 = $requestSchemaSha256
        resultSchemaSha256 = $resultSchemaSha256
        operation = $operationName
        operationState = $OperationState
        operationTimeoutSeconds = [int]$Request.operationTimeoutSeconds
        candidateProcessCount = $CandidateProcessCount
        exactExecutablePathProcessCount = $ExactPathCount
        exactMatchCount = @($Rows).Count
        rows = @($Rows)
        errorMessage = $ErrorMessage
        taskOrProcessManagementPerformed = $false
        processManagementPerformed = $false
        imageBytesRead = $false
        sourceMutationPerformed = $false
        targetPersistentMutationPerformed = $false
        providerActivationPerformed = $false
        productionRoutingEnabled = $false
    }
}

function Assert-ResultContract([object]$Result, [object]$Request) {
    $resultProperties = @(
        'schema','state','nonce','computerName','scalar','requestSha256',
        'requestSchemaSha256','resultSchemaSha256','operation','operationState',
        'operationTimeoutSeconds','candidateProcessCount','exactExecutablePathProcessCount',
        'exactMatchCount','rows','errorMessage','taskOrProcessManagementPerformed',
        'processManagementPerformed','imageBytesRead','sourceMutationPerformed',
        'targetPersistentMutationPerformed','providerActivationPerformed','productionRoutingEnabled'
    )
    Assert-ExactPropertySet -Value $Result -Expected $resultProperties -Context 'Result root'
    if ([string]$Result.schema -cne $resultSchema) { throw 'Unexpected result schema.' }
    if ([string]$Result.nonce -cne [string]$Request.nonce) { throw 'Result nonce mismatch.' }
    if ([string]$Result.requestSha256 -cnotmatch '^[A-F0-9]{64}$') { throw 'Invalid request hash in result.' }
    if ([string]$Result.requestSchemaSha256 -cne $requestSchemaSha256) { throw 'Result request-schema hash mismatch.' }
    if ([string]$Result.resultSchemaSha256 -cne $resultSchemaSha256) { throw 'Result schema hash mismatch.' }
    if ([string]$Result.operation -cne $operationName) { throw 'Result operation mismatch.' }
    if ([int]$Result.operationTimeoutSeconds -ne [int]$Request.operationTimeoutSeconds) { throw 'Result timeout mismatch.' }
    if ([int]$Result.candidateProcessCount -lt 0) { throw 'Invalid candidate process count.' }
    if ([int]$Result.exactExecutablePathProcessCount -lt 0 -or [int]$Result.exactExecutablePathProcessCount -gt [int]$Request.maximumRows) { throw 'Invalid exact-path count.' }
    $rows = @($Result.rows)
    if ($rows.Count -gt [int]$Request.maximumRows) { throw 'Result row count exceeds request maximum.' }
    if ([int]$Result.exactMatchCount -ne $rows.Count) { throw 'Result exact-match count mismatch.' }
    foreach ($row in $rows) {
        Assert-ExactPropertySet -Value $row -Expected @('processId','executablePath','commandLine','creationUtc') -Context 'Result row'
        if ([uint64]$row.processId -lt 1 -or [uint64]$row.processId -gt 4294967295) { throw 'Invalid process ID.' }
        Assert-BoundedString -Value ([string]$row.executablePath) -Minimum 1 -Maximum ([int]$Request.maximumFieldCharacters) -Name 'row.executablePath'
        Assert-BoundedString -Value ([string]$row.commandLine) -Minimum 1 -Maximum ([int]$Request.maximumFieldCharacters) -Name 'row.commandLine'
        Assert-BoundedString -Value ([string]$row.creationUtc) -Minimum 1 -Maximum 64 -Name 'row.creationUtc'
    }
    foreach ($safetyProperty in @(
        'taskOrProcessManagementPerformed','processManagementPerformed','imageBytesRead',
        'sourceMutationPerformed','targetPersistentMutationPerformed','providerActivationPerformed',
        'productionRoutingEnabled'
    )) {
        if ([bool]$Result.$safetyProperty) { throw "$safetyProperty must be false." }
    }
    if ([string]$Result.state -ceq 'PASS_ARGOS_DIRECT_OBSERVATION') {
        if ([string]$Result.operationState -cne 'OBSERVED') { throw 'PASS result must be OBSERVED.' }
        if ([string]$Result.scalar -cne [string]$Request.expectedScalar) { throw 'PASS scalar mismatch.' }
        if (-not [string]::IsNullOrEmpty([string]$Result.errorMessage)) { throw 'PASS result has an error message.' }
    }
    elseif ([string]$Result.state -ceq 'FAIL_ARGOS_DIRECT_OBSERVATION') {
        if (@('ERROR','TIMEOUT') -cnotcontains [string]$Result.operationState) { throw 'FAIL result must be ERROR or TIMEOUT.' }
        if (-not [string]::IsNullOrEmpty([string]$Result.scalar)) { throw 'FAIL result scalar must be empty.' }
        Assert-BoundedString -Value ([string]$Result.errorMessage) -Minimum 1 -Maximum 1024 -Name 'errorMessage'
    }
    else {
        throw 'Unexpected result state.'
    }

    $resultPropertyNames = @(Get-ExactPropertyNames -Value $Result)
    foreach ($consumerProperty in @(
        'schema','state','nonce','computerName','scalar',
        'taskOrProcessManagementPerformed','imageBytesRead','targetPersistentMutationPerformed'
    )) {
        if ($resultPropertyNames -notcontains $consumerProperty) {
            throw "Transport consumer property is absent: $consumerProperty"
        }
    }
    [void][string]$Result.schema
    [void][string]$Result.state
    [void][string]$Result.nonce
    [void][string]$Result.computerName
    [void][string]$Result.scalar
    [void][bool]$Result.taskOrProcessManagementPerformed
    [void][bool]$Result.imageBytesRead
    [void][bool]$Result.targetPersistentMutationPerformed
}

function New-FixtureRow([int]$Index, [object]$Request) {
    return [pscustomobject][ordered]@{
        processId = [uint32](9000 + $Index)
        executablePath = [string]$Request.parameters.exactExecutablePath
        commandLine = "fixture-$Index $([string]$Request.parameters.commandLineContains)"
        creationUtc = '2026-08-28T00:00:00.0000000Z'
    }
}

function Send-ClipboardJson([object]$Value) {
    $Value | ConvertTo-Json -Compress -Depth 8 | clip.exe
    if ($LASTEXITCODE -ne 0) { throw 'clip.exe failed to synchronize the direct-observation result.' }
}

function Invoke-WindowsProcessSnapshot([object]$Request, [string]$RequestSha256) {
    $candidateCount = 0
    $exactPathRows = @()
    $resultRows = @()
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    try {
        if ($env:COMPUTERNAME -cne [string]$Request.expectedComputerName) {
            throw "Wrong computer: $($env:COMPUTERNAME)"
        }
        $processBaseName = [IO.Path]::GetFileNameWithoutExtension([string]$Request.parameters.processName)
        $candidateRows = @(Get-Process -Name $processBaseName -ErrorAction SilentlyContinue)
        $candidateCount = $candidateRows.Count
        $exactPathList = New-Object 'System.Collections.Generic.List[object]'
        foreach ($candidate in $candidateRows) {
            $candidatePath = ''
            try { $candidatePath = [string]$candidate.Path }
            catch { $candidatePath = '' }
            if (-not [string]::IsNullOrWhiteSpace($candidatePath)) {
                $normalizedCandidatePath = [IO.Path]::GetFullPath($candidatePath)
                if ($normalizedCandidatePath.Equals([string]$Request.parameters.exactExecutablePath, [StringComparison]::OrdinalIgnoreCase)) {
                    $exactPathList.Add($candidate)
                }
            }
        }
        $exactPathRows = @($exactPathList.ToArray())
        if ($exactPathRows.Count -gt [int]$Request.maximumRows) {
            throw "Exact executable-path process count exceeds $([int]$Request.maximumRows)."
        }

        $resultList = New-Object 'System.Collections.Generic.List[object]'
        foreach ($candidate in $exactPathRows) {
            $remainingMilliseconds = ([int]$Request.operationTimeoutSeconds * 1000) - [int]$stopwatch.ElapsedMilliseconds
            if ($remainingMilliseconds -le 0) { throw [TimeoutException]::new('Process snapshot exceeded its total operation timeout before the next CIM query.') }
            $remainingSeconds = [Math]::Max(1, [Math]::Ceiling($remainingMilliseconds / 1000.0))
            $pidFilter = "ProcessId=$([uint32]$candidate.Id)"
            $cimRows = @(Get-CimInstance -ClassName Win32_Process -Filter $pidFilter -OperationTimeoutSec $remainingSeconds -ErrorAction Stop)
            if ($cimRows.Count -gt 1) { throw "CIM returned multiple rows for process ID $([uint32]$candidate.Id)." }
            if ($cimRows.Count -eq 1) {
                $commandLine = [string]$cimRows[0].CommandLine
                if (-not [string]::IsNullOrWhiteSpace($commandLine) -and
                    $commandLine.IndexOf([string]$Request.parameters.commandLineContains, [StringComparison]::Ordinal) -ge 0) {
                    Assert-BoundedString -Value $commandLine -Minimum 1 -Maximum ([int]$Request.maximumFieldCharacters) -Name 'observed commandLine'
                    $creationValue = $cimRows[0].CreationDate
                    $creationUtc = if ($creationValue -is [datetime]) {
                        ([datetime]$creationValue).ToUniversalTime().ToString('o')
                    }
                    else {
                        ([Management.ManagementDateTimeConverter]::ToDateTime([string]$creationValue)).ToUniversalTime().ToString('o')
                    }
                    $resultList.Add([pscustomobject][ordered]@{
                        processId = [uint32]$cimRows[0].ProcessId
                        executablePath = [string]$cimRows[0].ExecutablePath
                        commandLine = $commandLine
                        creationUtc = $creationUtc
                    })
                }
            }
        }
        $resultRows = @($resultList.ToArray())
        if ($stopwatch.Elapsed.TotalSeconds -gt [double]$Request.operationTimeoutSeconds) {
            throw [TimeoutException]::new('Process snapshot exceeded its total operation timeout.')
        }
        return New-Result -Request $Request -RequestSha256 $RequestSha256 -State 'PASS_ARGOS_DIRECT_OBSERVATION' -OperationState 'OBSERVED' -Scalar ([string]$Request.expectedScalar) -CandidateProcessCount $candidateCount -ExactPathCount $exactPathRows.Count -Rows $resultRows -ErrorMessage '' -ComputerName ([string]$env:COMPUTERNAME)
    }
    catch [TimeoutException] {
        return New-Result -Request $Request -RequestSha256 $RequestSha256 -State 'FAIL_ARGOS_DIRECT_OBSERVATION' -OperationState 'TIMEOUT' -Scalar '' -CandidateProcessCount $candidateCount -ExactPathCount @($exactPathRows).Count -Rows @() -ErrorMessage ([string]$_.Exception.Message) -ComputerName ([string]$env:COMPUTERNAME)
    }
    catch {
        $message = [string]$_.Exception.Message
        $operationState = if ($message -match '(?i)timed?\s*out|timeout') { 'TIMEOUT' } else { 'ERROR' }
        return New-Result -Request $Request -RequestSha256 $RequestSha256 -State 'FAIL_ARGOS_DIRECT_OBSERVATION' -OperationState $operationState -Scalar '' -CandidateProcessCount $candidateCount -ExactPathCount @($exactPathRows).Count -Rows @() -ErrorMessage $message -ComputerName ([string]$env:COMPUTERNAME)
    }
    finally {
        $stopwatch.Stop()
    }
}

$modeCount = 0
if ($Preflight) { $modeCount++ }
if ($Rehearsal) { $modeCount++ }
if ($Execute) { $modeCount++ }
if ($modeCount -ne 1) { throw 'Select exactly one of -Preflight, -Rehearsal, or -Execute.' }
if (($Preflight -or $Rehearsal) -and $EmitClipboard) { throw 'Preflight and rehearsal must not change the clipboard.' }

$requestText = Read-RequestText
$requestObject = Read-And-ValidateRequest -Text $requestText
$requestSha256 = Get-TextSha256 -Text $requestText

if ($Preflight) {
    $cimCommandRows = @(Get-Command -Name Get-CimInstance -CommandType Cmdlet -ErrorAction Stop)
    if ($cimCommandRows.Count -ne 1) { throw 'Get-CimInstance did not resolve exactly once.' }
    if (-not $cimCommandRows[0].Parameters.ContainsKey('OperationTimeoutSec')) { throw 'Get-CimInstance lacks OperationTimeoutSec.' }
    $caseRows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($caseId in @('ZERO','ONE','MANY','ERROR','TIMEOUT')) {
        if ($caseId -eq 'ZERO') { $fixtureRows = @() }
        elseif ($caseId -eq 'ONE') { $fixtureRows = @(New-FixtureRow -Index 1 -Request $requestObject) }
        elseif ($caseId -eq 'MANY') { $fixtureRows = @(1..3 | ForEach-Object { New-FixtureRow -Index $_ -Request $requestObject }) }
        else { $fixtureRows = @() }
        if ($caseId -eq 'ERROR' -or $caseId -eq 'TIMEOUT') {
            $fixture = New-Result -Request $requestObject -RequestSha256 $requestSha256 -State 'FAIL_ARGOS_DIRECT_OBSERVATION' -OperationState $caseId -Scalar '' -CandidateProcessCount 0 -ExactPathCount 0 -Rows @() -ErrorMessage "Injected $caseId fixture." -ComputerName ([string]$requestObject.expectedComputerName)
        }
        else {
            $fixture = New-Result -Request $requestObject -RequestSha256 $requestSha256 -State 'PASS_ARGOS_DIRECT_OBSERVATION' -OperationState 'OBSERVED' -Scalar ([string]$requestObject.expectedScalar) -CandidateProcessCount $fixtureRows.Count -ExactPathCount $fixtureRows.Count -Rows $fixtureRows -ErrorMessage '' -ComputerName ([string]$requestObject.expectedComputerName)
        }
        Assert-ResultContract -Result $fixture -Request $requestObject
        $caseRows.Add([pscustomobject]@{caseId=$caseId;state=[string]$fixture.state;operationState=[string]$fixture.operationState;rowCount=@($fixture.rows).Count})
    }
    [ordered]@{
        schema = 'argos_direct_observer_preflight_v1'
        state = 'PASS_ARGOS_DIRECT_OBSERVER_PREFLIGHT'
        requestSha256 = $requestSha256
        requestSchemaSha256 = $requestSchemaSha256
        resultSchemaSha256 = $resultSchemaSha256
        operation = $operationName
        operationTimeoutParameter = 'OperationTimeoutSec'
        getProcessPrefilter = $true
        exactPidCimQuery = $true
        cases = @($caseRows.ToArray())
        targetQueryPerformed = $false
        clipboardChanged = $false
        taskOrProcessManagementPerformed = $false
        imageBytesRead = $false
        targetPersistentMutationPerformed = $false
    } | ConvertTo-Json -Depth 8
    return
}

if ($Rehearsal) {
    if ($RehearsalCase -eq 'ZERO') { $rehearsalRows = @() }
    elseif ($RehearsalCase -eq 'ONE') { $rehearsalRows = @(New-FixtureRow -Index 1 -Request $requestObject) }
    elseif ($RehearsalCase -eq 'MANY') { $rehearsalRows = @(1..3 | ForEach-Object { New-FixtureRow -Index $_ -Request $requestObject }) }
    else { $rehearsalRows = @() }
    if ($RehearsalCase -eq 'ERROR' -or $RehearsalCase -eq 'TIMEOUT') {
        $rehearsalResult = New-Result -Request $requestObject -RequestSha256 $requestSha256 -State 'FAIL_ARGOS_DIRECT_OBSERVATION' -OperationState $RehearsalCase -Scalar '' -CandidateProcessCount 0 -ExactPathCount 0 -Rows @() -ErrorMessage "Injected $RehearsalCase rehearsal." -ComputerName ([string]$requestObject.expectedComputerName)
    }
    else {
        $rehearsalResult = New-Result -Request $requestObject -RequestSha256 $requestSha256 -State 'PASS_ARGOS_DIRECT_OBSERVATION' -OperationState 'OBSERVED' -Scalar ([string]$requestObject.expectedScalar) -CandidateProcessCount $rehearsalRows.Count -ExactPathCount $rehearsalRows.Count -Rows $rehearsalRows -ErrorMessage '' -ComputerName ([string]$requestObject.expectedComputerName)
    }
    Assert-ResultContract -Result $rehearsalResult -Request $requestObject
    $rehearsalResult | ConvertTo-Json -Compress -Depth 8
    return
}

if ($EmitClipboard) {
    Send-ClipboardJson -Value ([ordered]@{
        schema = $progressSchema
        state = 'STARTED_ARGOS_DIRECT_OBSERVATION'
        nonce = [string]$requestObject.nonce
        computerName = [string]$env:COMPUTERNAME
        requestSha256 = $requestSha256
        operation = $operationName
        targetPersistentMutationPerformed = $false
    })
}
$executionResult = Invoke-WindowsProcessSnapshot -Request $requestObject -RequestSha256 $requestSha256
Assert-ResultContract -Result $executionResult -Request $requestObject
if ($EmitClipboard) {
    Send-ClipboardJson -Value $executionResult
}
else {
    $executionResult | ConvertTo-Json -Compress -Depth 8
}
}
$directObserverRequestJson = '{
  "schema": "argos_direct_observation_request_v1",
  "revision": "ARGOS_DIRECT_OBSERVER_V1_LOCAL_PS51_GATE_20260828",
  "requestSchemaSha256": "EAF4AE35296570B95DF885F9AC88D980BFFFED3AC657F1E1642BA3A2F1D8D50F",
  "resultSchemaSha256": "B8FDE1122A182ABB7B2D96C79230CEC9C0591D5DC259FF409DF90FB0B3AD615A",
  "nonce": "ARGOS_DIRECT_OBSERVER_LOCAL_20260828_02",
  "expectedComputerName": "TXSH-LUPW0JLTPR",
  "operation": "WINDOWS_PROCESS_SNAPSHOT",
  "operationTimeoutSeconds": 8,
  "maximumRows": 16,
  "maximumFieldCharacters": 4096,
  "expectedScalar": "PASS_ARGOS_DIRECT_OBSERVER_LOCAL_PS51_GATE_20260828",
  "parameters": {
    "processName": "powershell.exe",
    "exactExecutablePath": "C:\\WINDOWS\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
    "commandLineContains": "Invoke-ArgosDirectObservation.ps1"
  },
  "authority": {
    "reviewOnly": true,
    "taskOrProcessManagementAllowed": false,
    "imageReadAllowed": false,
    "sourceMutationAllowed": false,
    "targetPersistentMutationAllowed": false,
    "providerActivationAllowed": false,
    "productionRoutingAllowed": false,
    "retryAuthorized": false,
    "maximumExecutions": 1
  }
}'
if ($Preflight) {
    & $directObserverExecutor -RequestJson $directObserverRequestJson -Preflight
    return
}
if ($Rehearsal) {
    & $directObserverExecutor -RequestJson $directObserverRequestJson -Rehearsal -RehearsalCase $RehearsalCase
    return
}
& $directObserverExecutor -RequestJson $directObserverRequestJson -Execute -EmitClipboard