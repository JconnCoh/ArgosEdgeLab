[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ([string]$Actual -cne [string]$Expected) {
        throw "$Message expected=$Expected actual=$Actual"
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$queryPath = Join-Path $PSScriptRoot 'Q.ps1'
$inputPath = Join-Path $PSScriptRoot 'I.json'
$tokens = $null
$parseErrors = $null
[void][Management.Automation.Language.Parser]::ParseFile($queryPath, [ref]$tokens, [ref]$parseErrors)
if (@($parseErrors).Count -ne 0) {
    throw "Q.ps1 parse failed: $($parseErrors.Message -join ' | ')"
}

$preflightText = (& $queryPath -Preflight -InputPath $inputPath | Out-String).Trim()
$queryPreflight = $preflightText | ConvertFrom-Json
Assert-Equal $queryPreflight.state 'PASS_R18UQ1_QUERY_PREFLIGHT' 'Preflight state mismatch.'
Assert-Equal $queryPreflight.queryKeyCount 50 'Preflight query-key count mismatch.'
Assert-True (-not [bool]$queryPreflight.databaseConnectionOpened) 'Preflight opened a database connection.'
Assert-True (-not [bool]$queryPreflight.credentialAccessed) 'Preflight accessed the credential.'
Assert-True (-not [bool]$queryPreflight.writesPerformed) 'Preflight performed a write.'
Assert-Equal $queryPreflight.optionalExecutionMode 'LIVE_READ_ONLY_ODBC_DSN' 'ODBC live mode mismatch.'
Assert-Equal $queryPreflight.optionalCredentialSource 'CALLER_SUPPLIED_PSCREDENTIAL_NOT_RETURNED' 'ODBC credential-source token mismatch.'
Assert-Equal $queryPreflight.optionalOdbcDatabase 'Insite' 'ODBC database override mismatch.'
Assert-True ([bool]$queryPreflight.odbcPositionalParameters) 'ODBC parameters are not positional.'
Assert-Equal $queryPreflight.odbcDirectParameterCount 50 'Direct ODBC parameter count mismatch.'
Assert-Equal $queryPreflight.odbcIssueHistoryParameterCount 100 'History ODBC parameter count mismatch.'
Assert-Equal $queryPreflight.odbcDirectKeyFingerprintSha256 '8A4F3176D0169931A01B039DA340084697A7FBDE402D0889E23FB971BDEBCA12' 'Direct ODBC key order mismatch.'
Assert-Equal $queryPreflight.odbcIssueHistoryParentKeyFingerprintSha256 '8A4F3176D0169931A01B039DA340084697A7FBDE402D0889E23FB971BDEBCA12' 'History parent ODBC key order mismatch.'
Assert-Equal $queryPreflight.odbcIssueHistoryIssuedKeyFingerprintSha256 '8A4F3176D0169931A01B039DA340084697A7FBDE402D0889E23FB971BDEBCA12' 'History issued ODBC key order mismatch.'
$syntheticSecure = ConvertTo-SecureString 'NOT_A_LIVE_CREDENTIAL' -AsPlainText -Force
$syntheticCredential = [Management.Automation.PSCredential]::new('NOT_A_LIVE_IDENTITY', $syntheticSecure)
$odbcPreflight = ((& $queryPath -Preflight -InputPath $inputPath -OdbcDsn 'InsiteMisc' -Credential $syntheticCredential | Out-String).Trim() | ConvertFrom-Json)
Assert-True (-not [bool]$odbcPreflight.credentialAccessed) 'ODBC preflight accessed the synthetic credential.'
Assert-True (-not [bool]$odbcPreflight.databaseConnectionOpened) 'ODBC preflight opened a database connection.'
$syntheticCredential = $null
$syntheticSecure = $null

if ($Preflight -and $Test) {
    throw 'Choose exactly one of -Preflight or -Test.'
}
if ($Preflight) {
    [pscustomobject][ordered]@{
        schema = 'argos_r18uq1_focused_local_rehearsal_preflight_v1'
        state = 'PASS_R18UQ1_FOCUSED_LOCAL_REHEARSAL_PREFLIGHT'
        queryParseErrors = 0
        queryPreflightPassed = $true
        exactQueryKeyCount = 50
        temporaryRootCreated = $false
        writesPerformed = $false
        liveSqlExecuted = $false
        credentialAccessed = $false
        imagesAccessed = $false
        jbodAccessed = $false
    } | ConvertTo-Json -Depth 8 -Compress
    return
}
if (-not $Test) {
    throw 'Specify -Preflight or -Test.'
}

$input = Get-Content -LiteralPath $inputPath -Raw | ConvertFrom-Json
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ArgosR18UQ1Test_' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -ItemType Directory -Path $tempRoot)
try {
    $direct = New-Object Collections.Generic.List[object]
    $history = New-Object Collections.Generic.List[object]
    for ($index = 0; $index -lt @($input.queryKeys).Count; $index++) {
        $lot = [string]$input.queryKeys[$index]
        $scribe = 'R' + ($index + 1).ToString('D11')
        $unit = $lot + '-001'
        $direct.Add([ordered]@{
            ParentContainer = $lot
            UnitContainer = $unit
            Scribe = $scribe
        })
        $history.Add([ordered]@{
            Scribe = $scribe
            SourceEpiContainer = 'EPI-' + ($index + 1).ToString('D4')
            IssuedWaferContainer = $unit
            ParentContainer = $lot
        })
    }

    $passFixture = [ordered]@{
        schema = 'argos_r18uq1_sql_row_rehearsal_v1'
        directRows = $direct.ToArray()
        issueHistoryRows = $history.ToArray()
    }
    $passPath = Join-Path $tempRoot 'pass.json'
    [IO.File]::WriteAllText($passPath, ($passFixture | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $passText = (& $queryPath -InputPath $inputPath -RehearsalInputPath $passPath | Out-String).Trim()
    $pass = $passText | ConvertFrom-Json
    Assert-Equal $pass.executionState 'PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED' 'PASS rehearsal execution token mismatch.'
    Assert-Equal $pass.disposition 'COMPLETE' 'PASS rehearsal disposition mismatch.'
    Assert-Equal $pass.state 'PASS_R18UQ1_EXHAUSTIVE_ROSTER' 'PASS rehearsal state mismatch.'
    Assert-Equal $pass.counts.queryLots 50 'PASS rehearsal query-lot count mismatch.'
    Assert-Equal $pass.counts.uniqueValidScribes 50 'PASS rehearsal unique-scribe count mismatch.'
    Assert-Equal $pass.counts.unmatchedLots 0 'PASS rehearsal unmatched count mismatch.'
    Assert-Equal $pass.counts.conflicts 0 'PASS rehearsal conflict count mismatch.'
    Assert-Equal $pass.counts.invalidOrNullRows 0 'PASS rehearsal invalid-row count mismatch.'
    Assert-True (-not [bool]$pass.invariants.credentialsReturned) 'PASS rehearsal returned credentials.'
    Assert-True (-not [bool]$pass.invariants.imagesAccessed) 'PASS rehearsal accessed images.'
    Assert-True (-not [bool]$pass.invariants.jbodAccessed) 'PASS rehearsal accessed JBOD.'
    Assert-Equal $pass.provenance.credentialSource 'NONE_FILE_BACKED_SYNTHETIC_ROWS' 'Synthetic credential source mismatch.'

    $holdDirect = @($direct.ToArray())
    $holdHistory = @($history.ToArray())
    $lastLot = [string]$input.queryKeys[@($input.queryKeys).Count - 1]
    $holdDirect = @($holdDirect | Where-Object { [string]$_.ParentContainer -cne $lastLot })
    $holdHistory = @($holdHistory | Where-Object { [string]$_.ParentContainer -cne $lastLot })
    $firstLot = [string]$input.queryKeys[0]
    $firstUnit = $firstLot + '-001'
    $holdHistory[0] = [ordered]@{
        Scribe = 'Z99999999999'
        SourceEpiContainer = 'EPI-CONFLICT'
        IssuedWaferContainer = $firstUnit
        ParentContainer = $firstLot
    }
    $holdDirect += [ordered]@{
        ParentContainer = $firstLot
        UnitContainer = $firstLot + '-002'
        Scribe = $null
    }
    $holdFixture = [ordered]@{
        schema = 'argos_r18uq1_sql_row_rehearsal_v1'
        directRows = $holdDirect
        issueHistoryRows = $holdHistory
    }
    $holdPath = Join-Path $tempRoot 'hold.json'
    [IO.File]::WriteAllText($holdPath, ($holdFixture | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $holdText = (& $queryPath -InputPath $inputPath -RehearsalInputPath $holdPath | Out-String).Trim()
    $hold = $holdText | ConvertFrom-Json
    Assert-Equal $hold.executionState 'PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED' 'HOLD rehearsal execution token mismatch.'
    Assert-Equal $hold.disposition 'HOLD' 'HOLD rehearsal disposition mismatch.'
    Assert-Equal $hold.state 'HOLD_R18UQ1_ROSTER_NOT_EXHAUSTIVE' 'HOLD rehearsal state mismatch.'
    Assert-Equal $hold.counts.unmatchedLots 1 'HOLD rehearsal unmatched count mismatch.'
    Assert-True ([int]$hold.counts.conflicts -ge 1) 'HOLD rehearsal did not retain identity conflict.'
    Assert-True ([int]$hold.counts.invalidOrNullRows -ge 1) 'HOLD rehearsal did not retain invalid row.'
    Assert-True (@($hold.unmatchedLots) -contains $lastLot) 'HOLD rehearsal omitted unmatched lot identity.'

    $savedPath = Join-Path $tempRoot 'saved-roster.json'
    $receiptText = (& $queryPath -InputPath $inputPath -RehearsalInputPath $passPath -OutputPath $savedPath | Out-String).Trim()
    $receipt = $receiptText | ConvertFrom-Json
    Assert-Equal $receipt.state 'PASS_R18UQ1_RESULT_WRITTEN_CREATE_NEW' 'Create-new receipt state mismatch.'
    Assert-True (Test-Path -LiteralPath $savedPath -PathType Leaf) 'Create-new output is missing.'
    $saved = Get-Content -LiteralPath $savedPath -Raw | ConvertFrom-Json
    Assert-Equal $saved.state 'PASS_R18UQ1_EXHAUSTIVE_ROSTER' 'Saved roster state mismatch.'
    $savedHash = (Get-FileHash -LiteralPath $savedPath -Algorithm SHA256).Hash
    Assert-Equal $receipt.sha256 $savedHash 'Create-new receipt hash mismatch.'
    $overwriteRefused = $false
    try {
        & $queryPath -InputPath $inputPath -RehearsalInputPath $passPath -OutputPath $savedPath | Out-Null
    }
    catch { $overwriteRefused = $true }
    Assert-True $overwriteRefused 'Existing output was not refused.'
    Assert-Equal (Get-FileHash -LiteralPath $savedPath -Algorithm SHA256).Hash $savedHash 'Refused overwrite changed output bytes.'

    $allJson = $passText + $holdText + $preflightText
    Assert-True ($allJson -notmatch '(?i)protectedPassword|"password"|"entropy"|"userName"') 'Output exposed a credential field.'

    [pscustomobject][ordered]@{
        schema = 'argos_r18uq1_focused_local_rehearsal_v1'
        state = 'PASS_R18UQ1_FOCUSED_LOCAL_REHEARSAL'
        powershellVersion = $PSVersionTable.PSVersion.ToString()
        queryParseErrors = 0
        preflightPassed = $true
        completeCasePassed = $true
        holdCasePassed = $true
        exactQueryKeyCount = 50
        completeUniqueScribeCount = [int]$pass.counts.uniqueValidScribes
        holdUnmatchedLotCount = [int]$hold.counts.unmatchedLots
        holdConflictCount = [int]$hold.counts.conflicts
        holdInvalidRowCount = [int]$hold.counts.invalidOrNullRows
        credentialFieldsExposed = $false
        odbcDirectPositionalParameterCount = 50
        odbcIssueHistoryPositionalParameterCount = 100
        createNewOutputPassed = $true
        overwriteRefusalPassed = $true
        writesOutsideTemporaryTestRoot = $false
        liveSqlExecuted = $false
        imagesAccessed = $false
        jbodAccessed = $false
    } | ConvertTo-Json -Depth 8 -Compress
}
finally {
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $resolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolvedTemp.StartsWith($resolvedSystemTemp, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($resolvedTemp) -notmatch '^ArgosR18UQ1Test_[a-f0-9]{32}$') {
        throw "Temporary cleanup target refused: $resolvedTemp"
    }
    if (Test-Path -LiteralPath $resolvedTemp -PathType Container) {
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
