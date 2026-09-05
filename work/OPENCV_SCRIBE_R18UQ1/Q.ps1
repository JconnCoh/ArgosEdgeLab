[CmdletBinding()]
param(
    [switch]$Preflight,
    [string]$InputPath,
    [string]$RehearsalInputPath,
    [string]$OdbcDsn,
    [Management.Automation.PSCredential]$Credential,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'

$script:ExpectedInputSchema = 'argos_r18uq1_roster_query_input_v1'
$script:ExpectedSourceCatalogSha256 = '89F37687D0E669A11671C2222CC495333C932C9CCCAA0BE277946AE30EBCDAB5'
$script:ExpectedQueryKeyFingerprintSha256 = '8A4F3176D0169931A01B039DA340084697A7FBDE402D0889E23FB971BDEBCA12'
$script:ExpectedQueryKeyCount = 50
$script:SqlServer = 'TXSH-OCSQL.AMER.II-VI.NET,1433'
$script:Database = 'INSITE'
$script:OdbcDatabase = 'Insite'
$script:CredentialPath = 'C:\ProgramData\ArgosInsiteBridgeRO\secrets\insite.credential.dpapi.json'
$script:CredentialSchema = 'argos_insite_dpapi_machine_credential_v1'
$script:MaximumInputBytes = [int64]65536
$script:MaximumRehearsalBytes = [int64]4194304
$script:MaximumSqlRowsPerSource = 10000
$script:MaximumDiagnosticRows = 2000
$script:MaximumOutputBytes = [int64]16777216

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $resolvedInputPath = Join-Path $PSScriptRoot 'I.json'
}
else {
    $resolvedInputPath = $InputPath
}
if ($Preflight -and -not [string]::IsNullOrWhiteSpace($RehearsalInputPath)) {
    throw 'Preflight cannot be combined with RehearsalInputPath.'
}

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '')
    }
    finally {
        $algorithm.Dispose()
    }
}

function Read-BoundedJson {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][int64]$MaximumBytes
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "Required JSON file is missing: $resolved"
    }
    $item = Get-Item -LiteralPath $resolved -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Reparse-point JSON input refused: $resolved"
    }
    if ([int64]$item.Length -le 0 -or [int64]$item.Length -gt $MaximumBytes) {
        throw "JSON input byte bound refused: $resolved bytes=$($item.Length)"
    }
    [byte[]]$bytes = [IO.File]::ReadAllBytes($resolved)
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $offset = 3
    }
    $text = $encoding.GetString($bytes, $offset, $bytes.Length - $offset)
    try {
        $value = $text | ConvertFrom-Json
    }
    catch {
        throw "JSON input parse failed: $resolved"
    }
    return [pscustomobject]@{
        Path = $resolved
        Bytes = [int64]$bytes.LongLength
        Sha256 = Get-Sha256Hex -Bytes $bytes
        Value = $value
    }
}

function Write-NewUtf8JsonResult {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Json
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetDirectoryName($resolved)
    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw 'Output parent must already exist.'
    }
    if (((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw 'Reparse-point output parent refused.'
    }
    if ([IO.Path]::GetExtension($resolved) -cne '.json' -or [IO.Path]::GetFileName($resolved).Length -gt 80 -or $resolved.Length -ge 200) {
        throw 'Output JSON path safety bound refused.'
    }
    [byte[]]$bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($Json)
    if ($bytes.LongLength -le 0 -or $bytes.LongLength -gt $script:MaximumOutputBytes) {
        throw "Output JSON byte bound refused: $($bytes.LongLength)"
    }
    $stream = [IO.FileStream]::new($resolved, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    }
    finally { $stream.Dispose() }
    return [pscustomobject][ordered]@{
        schema = 'argos_r18uq1_result_write_receipt_v1'
        state = 'PASS_R18UQ1_RESULT_WRITTEN_CREATE_NEW'
        path = $resolved
        bytes = [int64]$bytes.LongLength
        sha256 = Get-Sha256Hex -Bytes $bytes
        overwritePermitted = $false
        credentialsReturned = $false
    }
}

function Get-QueryInput {
    param([Parameter(Mandatory=$true)][string]$Path)
    $snapshot = Read-BoundedJson -Path $Path -MaximumBytes $script:MaximumInputBytes
    $inputValue = $snapshot.Value
    if ([string]$inputValue.schema -cne $script:ExpectedInputSchema) {
        throw 'R18UQ1 input schema mismatch.'
    }
    if ([string]$inputValue.sourceCatalogSha256 -cne $script:ExpectedSourceCatalogSha256) {
        throw 'R18UQ1 source catalog hash identity mismatch.'
    }
    if ([string]$inputValue.queryKeyFingerprintSha256 -cne $script:ExpectedQueryKeyFingerprintSha256) {
        throw 'R18UQ1 declared query-key fingerprint mismatch.'
    }
    $keys = @($inputValue.queryKeys | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() })
    if ($keys.Count -ne $script:ExpectedQueryKeyCount) {
        throw "R18UQ1 requires exactly $($script:ExpectedQueryKeyCount) query keys."
    }
    if (@($keys | Sort-Object -Unique).Count -ne $script:ExpectedQueryKeyCount) {
        throw 'R18UQ1 query keys must be unique.'
    }
    foreach ($key in $keys) {
        if ($key -notmatch '^\d{5}-\d{3}[A-Z]?$') {
            throw "R18UQ1 query key is malformed: $key"
        }
    }
    $keyBytes = [Text.UTF8Encoding]::new($false).GetBytes(($keys -join "`n"))
    $actualFingerprint = Get-Sha256Hex -Bytes $keyBytes
    if ($actualFingerprint -cne $script:ExpectedQueryKeyFingerprintSha256) {
        throw 'R18UQ1 exact ordered query-key set mismatch.'
    }
    return [pscustomobject]@{
        Path = $snapshot.Path
        Bytes = $snapshot.Bytes
        Sha256 = $snapshot.Sha256
        Keys = $keys
        FingerprintSha256 = $actualFingerprint
    }
}

function Get-RowValue {
    param(
        [AllowNull()][object]$Row,
        [Parameter(Mandatory=$true)][string]$Name
    )
    if ($null -eq $Row) { return $null }
    $value = $null
    if ($Row -is [Data.DataRow] -and $null -ne $Row.Table -and $Row.Table.Columns.Contains($Name)) {
        $value = $Row[$Name]
    }
    else {
        $property = $Row.PSObject.Properties[$Name]
        if ($null -ne $property) { $value = $property.Value }
    }
    if ($null -eq $value -or $value -is [DBNull]) { return $null }
    $text = ([string]$value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text
}

function Get-FixedSqlCredential {
    Add-Type -AssemblyName System.Security
    $snapshot = Read-BoundedJson -Path $script:CredentialPath -MaximumBytes ([int64]65536)
    $record = $snapshot.Value
    if ([string]$record.schema -cne $script:CredentialSchema) {
        throw 'Stored Insite credential schema refused.'
    }
    $userName = [string]$record.userName
    if ([string]::IsNullOrWhiteSpace($userName) -or $userName.Length -gt 256) {
        throw 'Stored Insite credential user identity refused.'
    }
    [byte[]]$entropy = $null
    [byte[]]$protected = $null
    [byte[]]$plain = $null
    $password = $null
    try {
        $entropy = [Convert]::FromBase64String([string]$record.entropy)
        $protected = [Convert]::FromBase64String([string]$record.protectedPassword)
        if ($entropy.Length -le 0 -or $entropy.Length -gt 4096 -or $protected.Length -le 0 -or $protected.Length -gt 24576) {
            throw 'Stored Insite credential protected material bounds refused.'
        }
        $plain = [Security.Cryptography.ProtectedData]::Unprotect(
            $protected,
            $entropy,
            [Security.Cryptography.DataProtectionScope]::LocalMachine
        )
        if ($plain.Length -le 0 -or $plain.Length -gt 4096) {
            throw 'Stored Insite credential plaintext bounds refused.'
        }
        $password = [Text.UTF8Encoding]::new($false, $true).GetString($plain)
        $secure = ConvertTo-SecureString $password -AsPlainText -Force
        return [Management.Automation.PSCredential]::new($userName, $secure)
    }
    finally {
        if ($null -ne $plain) { [Array]::Clear($plain, 0, $plain.Length) }
        if ($null -ne $protected) { [Array]::Clear($protected, 0, $protected.Length) }
        if ($null -ne $entropy) { [Array]::Clear($entropy, 0, $entropy.Length) }
        $password = $null
        $userName = $null
        $record = $null
        $snapshot = $null
    }
}

function Add-QueryParameters {
    param(
        [Parameter(Mandatory=$true)][Data.SqlClient.SqlCommand]$Command,
        [Parameter(Mandatory=$true)][string[]]$Keys
    )
    $names = New-Object Collections.Generic.List[string]
    for ($index = 0; $index -lt $Keys.Count; $index++) {
        $name = '@lot' + $index
        $parameter = $Command.Parameters.Add($name, [Data.SqlDbType]::NVarChar, 128)
        $parameter.Value = $Keys[$index]
        $names.Add($name)
    }
    return $names.ToArray()
}

function Read-SqlTable {
    param(
        [Parameter(Mandatory=$true)][Data.SqlClient.SqlConnection]$Connection,
        [Parameter(Mandatory=$true)][string]$SqlTemplate,
        [Parameter(Mandatory=$true)][string[]]$Keys
    )
    $command = $Connection.CreateCommand()
    try {
        $command.CommandTimeout = 60
        $parameterNames = Add-QueryParameters -Command $command -Keys $Keys
        $likePredicates = @($parameterNames | ForEach-Object { "cf.ContainerName like $_ + '-[0-9][0-9][0-9]'" })
        $command.CommandText = $SqlTemplate.Replace('__PARAMETERS__', ($parameterNames -join ','))
        $command.CommandText = $command.CommandText.Replace('__ISSUED_LIKE_PREDICATES__', ($likePredicates -join ' or '))
        $adapter = [Data.SqlClient.SqlDataAdapter]::new($command)
        try {
            $table = [Data.DataTable]::new()
            [void]$adapter.Fill($table)
        }
        finally {
            $adapter.Dispose()
        }
        if ($table.Rows.Count -gt $script:MaximumSqlRowsPerSource) {
            throw "SQL row cap exceeded: $($table.Rows.Count)"
        }
        return ,$table
    }
    finally {
        $command.Dispose()
    }
}

function Get-OdbcQueryPlan {
    param(
        [Parameter(Mandatory=$true)][string]$SqlTemplate,
        [Parameter(Mandatory=$true)][string[]]$Keys
    )
    $markers = @($Keys | ForEach-Object { '?' })
    $values = New-Object Collections.Generic.List[string]
    foreach ($key in $Keys) { $values.Add($key) }
    $text = $SqlTemplate.Replace('__PARAMETERS__', ($markers -join ','))
    if ($text.Contains('__ISSUED_LIKE_PREDICATES__')) {
        $predicates = @($Keys | ForEach-Object { "cf.ContainerName like ? + '-[0-9][0-9][0-9]'" })
        $text = $text.Replace('__ISSUED_LIKE_PREDICATES__', ($predicates -join ' or '))
        foreach ($key in $Keys) { $values.Add($key) }
    }
    if ($text.Contains('__PARAMETERS__') -or $text.Contains('__ISSUED_LIKE_PREDICATES__')) {
        throw 'ODBC SQL placeholder expansion incomplete.'
    }
    return [pscustomobject]@{ CommandText=$text; ParameterValues=$values.ToArray() }
}

function Read-OdbcTable {
    param(
        [Parameter(Mandatory=$true)][Data.Odbc.OdbcConnection]$Connection,
        [Parameter(Mandatory=$true)]$QueryPlan
    )
    $command = $Connection.CreateCommand()
    try {
        $command.CommandTimeout = 60
        $command.CommandText = [string]$QueryPlan.CommandText
        $index = 0
        foreach ($value in @($QueryPlan.ParameterValues)) {
            $parameter = $command.CreateParameter()
            $parameter.ParameterName = 'p' + $index
            $parameter.OdbcType = [Data.Odbc.OdbcType]::NVarChar
            $parameter.Size = 128
            $parameter.Value = [string]$value
            [void]$command.Parameters.Add($parameter)
            $index++
        }
        if ($command.Parameters.Count -ne @($QueryPlan.ParameterValues).Count) {
            throw 'ODBC positional parameter cardinality mismatch.'
        }
        $adapter = [Data.Odbc.OdbcDataAdapter]::new($command)
        try {
            $table = [Data.DataTable]::new()
            [void]$adapter.Fill($table)
        }
        finally { $adapter.Dispose() }
        if ($table.Rows.Count -gt $script:MaximumSqlRowsPerSource) {
            throw "ODBC row cap exceeded: $($table.Rows.Count)"
        }
        return ,$table
    }
    finally { $command.Dispose() }
}

$script:DirectSqlTemplate = @"
select distinct
    p.ContainerName as ParentContainer,
    c.ContainerName as UnitContainer,
    replace(c.Substrate, ' ', '') as Scribe
from Insite.Container c
join Insite.Container p on c.ParentContainerId = p.ContainerId
where p.ContainerName in (__PARAMETERS__)
order by ParentContainer, UnitContainer, Scribe
"@

$script:IssueHistorySqlTemplate = @"
select distinct
    replace(ce.Substrate, ' ', '') as Scribe,
    ce.ContainerName as SourceEpiContainer,
    cf.ContainerName as IssuedWaferContainer,
    pc.ContainerName as ParentContainer
from Insite.Container ce
join Insite.IssueActualsHistory ia on ia.FromContainerId = ce.ContainerId
join Insite.Container cf on ia.ToContainerId = cf.ContainerId
left join Insite.Container pc on cf.ParentContainerId = pc.ContainerId
where pc.ContainerName in (__PARAMETERS__)
   or (__ISSUED_LIKE_PREDICATES__)
order by IssuedWaferContainer, Scribe, SourceEpiContainer
"@

function Get-LiveSqlRows {
    param([Parameter(Mandatory=$true)][string[]]$Keys)
    $fixedCredential = $null
    $builder = $null
    $connection = $null
    try {
        $fixedCredential = Get-FixedSqlCredential
        $builder = [Data.SqlClient.SqlConnectionStringBuilder]::new()
        $builder['Data Source'] = "tcp:$($script:SqlServer)"
        $builder['Initial Catalog'] = $script:Database
        $builder['User ID'] = $fixedCredential.UserName
        $builder['Password'] = $fixedCredential.GetNetworkCredential().Password
        $builder['Integrated Security'] = $false
        $builder['Encrypt'] = $true
        $builder['TrustServerCertificate'] = $true
        $builder['Connect Timeout'] = 10
        $builder['Application Name'] = 'ArgosEdgeLabR18UQ1ReadOnlyRoster'
        $builder['ApplicationIntent'] = 'ReadOnly'
        $builder['Persist Security Info'] = $false
        $connection = [Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
        $builder['Password'] = ''
        $fixedCredential = $null
        $connection.Open()
        $directTable = Read-SqlTable -Connection $connection -SqlTemplate $script:DirectSqlTemplate -Keys $Keys
        $historyTable = Read-SqlTable -Connection $connection -SqlTemplate $script:IssueHistorySqlTemplate -Keys $Keys
        return [pscustomobject]@{
            DirectRows = @($directTable.Rows | ForEach-Object { $_ })
            IssueHistoryRows = @($historyTable.Rows | ForEach-Object { $_ })
            ExecutionMode = 'LIVE_READ_ONLY_SQL'
            CredentialSource = 'FIXED_ARGOS_DPAPI_LOCAL_MACHINE_ENVELOPE'
            OdbcDsn = $null
            Database = $script:Database
            RehearsalInputPath = $null
            RehearsalInputSha256 = $null
        }
    }
    finally {
        if ($null -ne $connection) {
            if ($connection.State -ne [Data.ConnectionState]::Closed) { $connection.Close() }
            $connection.Dispose()
        }
        if ($null -ne $builder) { $builder['Password'] = '' }
        $fixedCredential = $null
    }
}

function Get-LiveOdbcRows {
    param(
        [Parameter(Mandatory=$true)][string[]]$Keys,
        [Parameter(Mandatory=$true)][string]$Dsn,
        [Parameter(Mandatory=$true)][Management.Automation.PSCredential]$SuppliedCredential
    )
    if ([string]::IsNullOrWhiteSpace($Dsn) -or $Dsn.Length -gt 128 -or $Dsn.IndexOfAny([char[]]"`r`n`0") -ge 0) {
        throw 'Caller-supplied ODBC DSN refused.'
    }
    if ([string]::IsNullOrWhiteSpace($SuppliedCredential.UserName) -or $SuppliedCredential.UserName.Length -gt 256) {
        throw 'Caller-supplied ODBC credential user identity refused.'
    }
    $builder = [Data.Odbc.OdbcConnectionStringBuilder]::new()
    $connection = $null
    try {
        $builder['Dsn'] = $Dsn
        $builder['Database'] = $script:OdbcDatabase
        $builder['Uid'] = $SuppliedCredential.UserName
        $builder['Pwd'] = $SuppliedCredential.GetNetworkCredential().Password
        $builder['APP'] = 'ArgosEdgeLabR18UQ1ReadOnlyRoster'
        $connection = [Data.Odbc.OdbcConnection]::new($builder.ConnectionString)
        $builder['Pwd'] = ''
        $connection.Open()
        $directPlan = Get-OdbcQueryPlan -SqlTemplate $script:DirectSqlTemplate -Keys $Keys
        $historyPlan = Get-OdbcQueryPlan -SqlTemplate $script:IssueHistorySqlTemplate -Keys $Keys
        $directTable = Read-OdbcTable -Connection $connection -QueryPlan $directPlan
        $historyTable = Read-OdbcTable -Connection $connection -QueryPlan $historyPlan
        return [pscustomobject]@{
            DirectRows = @($directTable.Rows | ForEach-Object { $_ })
            IssueHistoryRows = @($historyTable.Rows | ForEach-Object { $_ })
            ExecutionMode = 'LIVE_READ_ONLY_ODBC_DSN'
            CredentialSource = 'CALLER_SUPPLIED_PSCREDENTIAL_NOT_RETURNED'
            OdbcDsn = $Dsn
            Database = $script:OdbcDatabase
            RehearsalInputPath = $null
            RehearsalInputSha256 = $null
        }
    }
    finally {
        if ($null -ne $connection) {
            if ($connection.State -ne [Data.ConnectionState]::Closed) { $connection.Close() }
            $connection.Dispose()
        }
        if ($null -ne $builder) { $builder['Pwd'] = '' }
        $SuppliedCredential = $null
    }
}

function Get-RehearsalRows {
    param([Parameter(Mandatory=$true)][string]$Path)
    $snapshot = Read-BoundedJson -Path $Path -MaximumBytes $script:MaximumRehearsalBytes
    if ([string]$snapshot.Value.schema -cne 'argos_r18uq1_sql_row_rehearsal_v1') {
        throw 'R18UQ1 rehearsal input schema mismatch.'
    }
    $directRows = @($snapshot.Value.directRows)
    $historyRows = @($snapshot.Value.issueHistoryRows)
    if ($directRows.Count -gt $script:MaximumSqlRowsPerSource -or $historyRows.Count -gt $script:MaximumSqlRowsPerSource) {
        throw 'R18UQ1 rehearsal SQL-row cap exceeded.'
    }
    return [pscustomobject]@{
        DirectRows = $directRows
        IssueHistoryRows = $historyRows
        ExecutionMode = 'FILE_BACKED_SYNTHETIC_SQL_ROW_REHEARSAL'
        CredentialSource = 'NONE_FILE_BACKED_SYNTHETIC_ROWS'
        OdbcDsn = $null
        Database = $null
        RehearsalInputPath = $snapshot.Path
        RehearsalInputSha256 = $snapshot.Sha256
    }
}

function New-StringSet {
    $set = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    return ,$set
}

function Get-UnitLot {
    param(
        [AllowNull()][string]$UnitContainer,
        [Parameter(Mandatory=$true)][Collections.Generic.HashSet[string]]$CatalogSet
    )
    if ([string]::IsNullOrWhiteSpace($UnitContainer)) { return $null }
    $unit = $UnitContainer.Trim().ToUpperInvariant()
    if ($unit -notmatch '^(.+)-(\d{3})$') { return $null }
    $candidate = $Matches[1]
    if (-not $CatalogSet.Contains($candidate)) { return $null }
    return $candidate
}

function New-DiagnosticRow {
    param(
        [Parameter(Mandatory=$true)][string]$Source,
        [Parameter(Mandatory=$true)][int]$SourceRow,
        [Parameter(Mandatory=$true)][string]$Code,
        [AllowNull()][string]$QueryLot,
        [AllowNull()][string]$Scribe,
        [AllowNull()][string]$UnitContainer,
        [AllowNull()][string]$ParentContainer,
        [AllowNull()][string]$SourceEpiContainer
    )
    return [pscustomobject][ordered]@{
        source = $Source
        sourceRow = $SourceRow
        code = $Code
        queryLot = $QueryLot
        scribe = $Scribe
        unitContainer = $UnitContainer
        parentContainer = $ParentContainer
        sourceEpiContainer = $SourceEpiContainer
    }
}

function Build-RosterResult {
    param(
        [Parameter(Mandatory=$true)]$InputSnapshot,
        [Parameter(Mandatory=$true)]$SqlRows
    )
    $keys = @($InputSnapshot.Keys)
    $catalogSet = New-StringSet
    foreach ($key in $keys) { [void]$catalogSet.Add($key) }
    $evidence = New-Object Collections.Generic.List[object]
    $invalidRows = New-Object Collections.Generic.List[object]
    $conflicts = New-Object Collections.Generic.List[object]

    $directIndex = 0
    foreach ($row in @($SqlRows.DirectRows)) {
        $directIndex++
        $parent = Get-RowValue -Row $row -Name 'ParentContainer'
        $unit = Get-RowValue -Row $row -Name 'UnitContainer'
        $scribe = Get-RowValue -Row $row -Name 'Scribe'
        if ($null -ne $parent) { $parent = $parent.ToUpperInvariant() }
        if ($null -ne $unit) { $unit = $unit.ToUpperInvariant() }
        if ($null -ne $scribe) { $scribe = ($scribe -replace ' ', '').ToUpperInvariant() }
        $unitLot = Get-UnitLot -UnitContainer $unit -CatalogSet $catalogSet
        $codes = New-Object Collections.Generic.List[string]
        if ($null -eq $parent -or -not $catalogSet.Contains($parent)) { $codes.Add('DIRECT_PARENT_NOT_QUERY_LOT') }
        if ($null -eq $unitLot) { $codes.Add('DIRECT_UNIT_CONTAINER_INVALID_OR_OUTSIDE_CATALOG') }
        if ($null -eq $scribe -or $scribe -notmatch '^[A-Z0-9]{12}$') { $codes.Add('DIRECT_SCRIBE_NULL_OR_INVALID') }
        if ($codes.Count -gt 0) {
            foreach ($code in $codes) {
                $invalidRows.Add((New-DiagnosticRow -Source 'DIRECT_CURRENT_CONTAINMENT' -SourceRow $directIndex -Code $code -QueryLot $parent -Scribe $scribe -UnitContainer $unit -ParentContainer $parent -SourceEpiContainer $null))
            }
            continue
        }
        if ($unitLot -cne $parent) {
            $conflicts.Add((New-DiagnosticRow -Source 'DIRECT_CURRENT_CONTAINMENT' -SourceRow $directIndex -Code 'DIRECT_PARENT_UNIT_LOT_MISMATCH' -QueryLot $parent -Scribe $scribe -UnitContainer $unit -ParentContainer $parent -SourceEpiContainer $null))
        }
        $evidence.Add([pscustomobject][ordered]@{
            queryLot = $parent
            scribe = $scribe
            unitContainer = $unit
            parentContainer = $parent
            sourceEpiContainer = $null
            source = 'DIRECT_CURRENT_CONTAINMENT'
            sourceRow = $directIndex
        })
    }

    $historyIndex = 0
    foreach ($row in @($SqlRows.IssueHistoryRows)) {
        $historyIndex++
        $parent = Get-RowValue -Row $row -Name 'ParentContainer'
        $unit = Get-RowValue -Row $row -Name 'IssuedWaferContainer'
        $scribe = Get-RowValue -Row $row -Name 'Scribe'
        $sourceEpi = Get-RowValue -Row $row -Name 'SourceEpiContainer'
        if ($null -ne $parent) { $parent = $parent.ToUpperInvariant() }
        if ($null -ne $unit) { $unit = $unit.ToUpperInvariant() }
        if ($null -ne $scribe) { $scribe = ($scribe -replace ' ', '').ToUpperInvariant() }
        $unitLot = Get-UnitLot -UnitContainer $unit -CatalogSet $catalogSet
        $parentLot = if ($null -ne $parent -and $catalogSet.Contains($parent)) { $parent } else { $null }
        $queryLot = if ($null -ne $unitLot) { $unitLot } else { $parentLot }
        $codes = New-Object Collections.Generic.List[string]
        if ($null -eq $queryLot) { $codes.Add('HISTORY_LOT_UNRESOLVED') }
        if ($null -eq $unitLot) { $codes.Add('HISTORY_ISSUED_UNIT_INVALID_OR_OUTSIDE_CATALOG') }
        if ($null -eq $scribe -or $scribe -notmatch '^[A-Z0-9]{12}$') { $codes.Add('HISTORY_SCRIBE_NULL_OR_INVALID') }
        if ($null -eq $sourceEpi) { $codes.Add('HISTORY_SOURCE_EPI_NULL') }
        if ($codes.Count -gt 0) {
            foreach ($code in $codes) {
                $invalidRows.Add((New-DiagnosticRow -Source 'ISSUE_ACTUALS_HISTORY' -SourceRow $historyIndex -Code $code -QueryLot $queryLot -Scribe $scribe -UnitContainer $unit -ParentContainer $parent -SourceEpiContainer $sourceEpi))
            }
            continue
        }
        if ($null -ne $parentLot -and $parentLot -cne $unitLot) {
            $conflicts.Add((New-DiagnosticRow -Source 'ISSUE_ACTUALS_HISTORY' -SourceRow $historyIndex -Code 'HISTORY_PARENT_UNIT_LOT_MISMATCH' -QueryLot $queryLot -Scribe $scribe -UnitContainer $unit -ParentContainer $parent -SourceEpiContainer $sourceEpi))
        }
        $evidence.Add([pscustomobject][ordered]@{
            queryLot = $queryLot
            scribe = $scribe
            unitContainer = $unit
            parentContainer = $parent
            sourceEpiContainer = $sourceEpi
            source = 'ISSUE_ACTUALS_HISTORY'
            sourceRow = $historyIndex
        })
    }

    if ($invalidRows.Count -gt $script:MaximumDiagnosticRows -or $conflicts.Count -gt $script:MaximumDiagnosticRows) {
        throw 'R18UQ1 diagnostic row cap exceeded.'
    }

    $unitGroups = @($evidence | Group-Object unitContainer)
    foreach ($group in $unitGroups) {
        $scribes = @($group.Group.scribe | Sort-Object -Unique)
        if ($scribes.Count -gt 1) {
            $conflicts.Add([pscustomobject][ordered]@{
                source = 'CROSS_SOURCE_RECONCILIATION'
                sourceRow = 0
                code = 'UNIT_CONTAINER_MULTIPLE_SCRIBES'
                queryLot = @($group.Group.queryLot | Sort-Object -Unique) -join '|'
                scribe = $scribes -join '|'
                unitContainer = [string]$group.Name
                parentContainer = @($group.Group.parentContainer | Where-Object { $_ } | Sort-Object -Unique) -join '|'
                sourceEpiContainer = @($group.Group.sourceEpiContainer | Where-Object { $_ } | Sort-Object -Unique) -join '|'
            })
        }
    }
    $scribeGroups = @($evidence | Group-Object scribe)
    foreach ($group in $scribeGroups) {
        $lots = @($group.Group.queryLot | Sort-Object -Unique)
        if ($lots.Count -gt 1) {
            $conflicts.Add([pscustomobject][ordered]@{
                source = 'CROSS_SOURCE_RECONCILIATION'
                sourceRow = 0
                code = 'SCRIBE_MULTIPLE_QUERY_LOTS'
                queryLot = $lots -join '|'
                scribe = [string]$group.Name
                unitContainer = @($group.Group.unitContainer | Sort-Object -Unique) -join '|'
                parentContainer = @($group.Group.parentContainer | Where-Object { $_ } | Sort-Object -Unique) -join '|'
                sourceEpiContainer = @($group.Group.sourceEpiContainer | Where-Object { $_ } | Sort-Object -Unique) -join '|'
            })
        }
        foreach ($lotGroup in @($group.Group | Group-Object queryLot)) {
            $units = @($lotGroup.Group.unitContainer | Sort-Object -Unique)
            if ($units.Count -gt 1) {
                $conflicts.Add([pscustomobject][ordered]@{
                    source = 'CROSS_SOURCE_RECONCILIATION'
                    sourceRow = 0
                    code = 'SCRIBE_MULTIPLE_UNIT_CONTAINERS_IN_LOT'
                    queryLot = [string]$lotGroup.Name
                    scribe = [string]$group.Name
                    unitContainer = $units -join '|'
                    parentContainer = @($lotGroup.Group.parentContainer | Where-Object { $_ } | Sort-Object -Unique) -join '|'
                    sourceEpiContainer = @($lotGroup.Group.sourceEpiContainer | Where-Object { $_ } | Sort-Object -Unique) -join '|'
                })
            }
        }
    }
    if ($conflicts.Count -gt $script:MaximumDiagnosticRows) {
        throw 'R18UQ1 conflict row cap exceeded.'
    }

    $lots = New-Object Collections.Generic.List[object]
    $unmatched = New-Object Collections.Generic.List[string]
    foreach ($key in $keys) {
        $lotEvidence = @($evidence | Where-Object { [string]$_.queryLot -ceq $key })
        $scribeRecords = New-Object Collections.Generic.List[object]
        foreach ($scribeGroup in @($lotEvidence | Group-Object scribe | Sort-Object Name)) {
            $rows = @($scribeGroup.Group)
            $scribeRecords.Add([pscustomobject][ordered]@{
                scribe = [string]$scribeGroup.Name
                unitContainers = @($rows.unitContainer | Sort-Object -Unique)
                parentContainers = @($rows.parentContainer | Where-Object { $_ } | Sort-Object -Unique)
                sourceEpiContainers = @($rows.sourceEpiContainer | Where-Object { $_ } | Sort-Object -Unique)
                evidenceSources = @($rows.source | Sort-Object -Unique)
                directCurrentContainmentRowCount = @($rows | Where-Object { $_.source -ceq 'DIRECT_CURRENT_CONTAINMENT' }).Count
                issueActualsHistoryRowCount = @($rows | Where-Object { $_.source -ceq 'ISSUE_ACTUALS_HISTORY' }).Count
            })
        }
        $lotConflicts = @($conflicts | Where-Object { ([string]$_.queryLot -split '\|') -contains $key })
        $lotInvalid = @($invalidRows | Where-Object { [string]$_.queryLot -ceq $key })
        if ($scribeRecords.Count -eq 0) { $unmatched.Add($key) }
        $lotState = if ($scribeRecords.Count -eq 0) {
            'HOLD_NO_VALID_SCRIBE_ROWS'
        }
        elseif ($lotConflicts.Count -gt 0 -or $lotInvalid.Count -gt 0) {
            'HOLD_CONFLICT_OR_INVALID_ROW'
        }
        else {
            'COMPLETE'
        }
        $lots.Add([pscustomobject][ordered]@{
            queryLot = $key
            state = $lotState
            validScribeCount = $scribeRecords.Count
            validEvidenceRowCount = $lotEvidence.Count
            conflictCount = $lotConflicts.Count
            invalidRowCount = $lotInvalid.Count
            scribes = $scribeRecords.ToArray()
        })
    }

    $holds = New-Object Collections.Generic.List[object]
    if ($unmatched.Count -gt 0) {
        $holds.Add([pscustomobject]@{ code='UNMATCHED_QUERY_LOTS'; count=$unmatched.Count })
    }
    if ($conflicts.Count -gt 0) {
        $holds.Add([pscustomobject]@{ code='ROSTER_IDENTITY_CONFLICTS'; count=$conflicts.Count })
    }
    if ($invalidRows.Count -gt 0) {
        $holds.Add([pscustomobject]@{ code='INVALID_OR_NULL_SQL_ROWS'; count=$invalidRows.Count })
    }
    $complete = $holds.Count -eq 0
    return [pscustomobject][ordered]@{
        schema = 'argos_r18uq1_exhaustive_lot_scribe_roster_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        executionState = 'PASS_R18UQ1_READ_ONLY_QUERY_EXECUTED'
        disposition = if ($complete) { 'COMPLETE' } else { 'HOLD' }
        state = if ($complete) { 'PASS_R18UQ1_EXHAUSTIVE_ROSTER' } else { 'HOLD_R18UQ1_ROSTER_NOT_EXHAUSTIVE' }
        executionMode = [string]$SqlRows.ExecutionMode
        input = [ordered]@{
            path = [string]$InputSnapshot.Path
            bytes = [int64]$InputSnapshot.Bytes
            sha256 = [string]$InputSnapshot.Sha256
            sourceCatalogSha256 = $script:ExpectedSourceCatalogSha256
            queryKeyFingerprintSha256 = [string]$InputSnapshot.FingerprintSha256
            queryKeyCount = $keys.Count
        }
        provenance = [ordered]@{
            historicalRoutePattern = 'REQ_20260809T043954120Z_08C7947D2870'
            serverTarget = $script:SqlServer
            database = $SqlRows.Database
            odbcDsn = $SqlRows.OdbcDsn
            sourceTables = @('Insite.Container', 'Insite.IssueActualsHistory')
            directCurrentContainmentSqlSha256 = Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($script:DirectSqlTemplate))
            issueActualsHistorySqlSha256 = Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($script:IssueHistorySqlTemplate))
            credentialSource = [string]$SqlRows.CredentialSource
            credentialMaterialReturned = $false
            rehearsalInputPath = $SqlRows.RehearsalInputPath
            rehearsalInputSha256 = $SqlRows.RehearsalInputSha256
        }
        counts = [ordered]@{
            queryLots = $keys.Count
            directCurrentContainmentRows = @($SqlRows.DirectRows).Count
            issueActualsHistoryRows = @($SqlRows.IssueHistoryRows).Count
            validEvidenceRows = $evidence.Count
            uniqueValidScribes = @($evidence.scribe | Sort-Object -Unique).Count
            unmatchedLots = $unmatched.Count
            conflicts = $conflicts.Count
            invalidOrNullRows = $invalidRows.Count
        }
        lots = $lots.ToArray()
        unmatchedLots = $unmatched.ToArray()
        conflicts = @($conflicts | Sort-Object code, queryLot, scribe, unitContainer)
        invalidOrNullRows = @($invalidRows | Sort-Object source, sourceRow, code)
        holds = $holds.ToArray()
        invariants = [ordered]@{
            readOnlySql = $true
            parameterizedLotKeys = $true
            lotSlotIdentityInferenceUsed = $false
            imagesAccessed = $false
            jbodAccessed = $false
            credentialsReturned = $false
            tasksOrProcessesAccessed = $false
            queuesAccessed = $false
            sourceMutationPerformed = $false
            productionRoutingEnabled = $false
        }
    }
}

$queryInput = Get-QueryInput -Path $resolvedInputPath

if ($Preflight) {
    $directOdbcPlan = Get-OdbcQueryPlan -SqlTemplate $script:DirectSqlTemplate -Keys $queryInput.Keys
    $historyOdbcPlan = Get-OdbcQueryPlan -SqlTemplate $script:IssueHistorySqlTemplate -Keys $queryInput.Keys
    $historyOdbcValues = @($historyOdbcPlan.ParameterValues)
    $odbcFingerprint = {
        param([string[]]$Values)
        Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes(($Values -join "`n")))
    }
    $preflightResult = [ordered]@{
        schema = 'argos_r18uq1_query_preflight_v1'
        state = 'PASS_R18UQ1_QUERY_PREFLIGHT'
        inputPath = $queryInput.Path
        inputBytes = $queryInput.Bytes
        inputSha256 = $queryInput.Sha256
        sourceCatalogSha256 = $script:ExpectedSourceCatalogSha256
        queryKeyFingerprintSha256 = $queryInput.FingerprintSha256
        queryKeyCount = $queryInput.Keys.Count
        historicalRoutePattern = 'REQ_20260809T043954120Z_08C7947D2870'
        defaultCredentialSource = 'FIXED_ARGOS_DPAPI_LOCAL_MACHINE_ENVELOPE'
        optionalExecutionMode = 'LIVE_READ_ONLY_ODBC_DSN'
        optionalCredentialSource = 'CALLER_SUPPLIED_PSCREDENTIAL_NOT_RETURNED'
        optionalOdbcDatabase = $script:OdbcDatabase
        odbcPositionalParameters = $true
        odbcDirectParameterCount = @($directOdbcPlan.ParameterValues).Count
        odbcIssueHistoryParameterCount = @($historyOdbcPlan.ParameterValues).Count
        odbcDirectKeyFingerprintSha256 = & $odbcFingerprint @($directOdbcPlan.ParameterValues)
        odbcIssueHistoryParentKeyFingerprintSha256 = & $odbcFingerprint @($historyOdbcValues[0..49])
        odbcIssueHistoryIssuedKeyFingerprintSha256 = & $odbcFingerprint @($historyOdbcValues[50..99])
        readOnlySql = $true
        parameterizedLotKeys = $true
        inputFileRead = $true
        credentialAccessed = $false
        databaseConnectionOpened = $false
        networkAccessPerformed = $false
        writesPerformed = $false
        imagesAccessed = $false
        jbodAccessed = $false
        productionRoutingEnabled = $false
    }
    Write-Output -NoEnumerate ($preflightResult | ConvertTo-Json -Depth 8 -Compress)
    return
}

if (-not [string]::IsNullOrWhiteSpace($RehearsalInputPath)) {
    if (-not [string]::IsNullOrWhiteSpace($OdbcDsn) -or $null -ne $Credential) {
        throw 'RehearsalInputPath cannot be combined with OdbcDsn or Credential.'
    }
    $rows = Get-RehearsalRows -Path $RehearsalInputPath
}
elseif (-not [string]::IsNullOrWhiteSpace($OdbcDsn) -or $null -ne $Credential) {
    if ([string]::IsNullOrWhiteSpace($OdbcDsn) -or $null -eq $Credential) {
        throw 'Live ODBC execution requires both OdbcDsn and Credential.'
    }
    $rows = Get-LiveOdbcRows -Keys $queryInput.Keys -Dsn $OdbcDsn -SuppliedCredential $Credential
}
else {
    $rows = Get-LiveSqlRows -Keys $queryInput.Keys
}
$result = Build-RosterResult -InputSnapshot $queryInput -SqlRows $rows
$resultJson = $result | ConvertTo-Json -Depth 16 -Compress
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    Write-Output -NoEnumerate $resultJson
}
else {
    $receipt = Write-NewUtf8JsonResult -Path $OutputPath -Json $resultJson
    Write-Output -NoEnumerate ($receipt | ConvertTo-Json -Depth 4 -Compress)
}
