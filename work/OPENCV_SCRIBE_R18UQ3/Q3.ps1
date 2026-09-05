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

$script:ExpectedInputSchema = 'argos_r18uq3_roster_query_input_v1'
$script:ExpectedCatalogSha256 = '89F37687D0E669A11671C2222CC495333C932C9CCCAA0BE277946AE30EBCDAB5'
$script:ExpectedKeyFingerprintSha256 = '8A4F3176D0169931A01B039DA340084697A7FBDE402D0889E23FB971BDEBCA12'
$script:ExpectedKeyCount = 50
$script:SqlServer = 'TXSH-OCSQL.AMER.II-VI.NET,1433'
$script:Database = 'INSITE'
$script:OdbcDatabase = 'Insite'
$script:CredentialPath = 'C:\ProgramData\ArgosInsiteBridgeRO\secrets\insite.credential.dpapi.json'
$script:CredentialSchema = 'argos_insite_dpapi_machine_credential_v1'
$script:MaximumInputBytes = [int64]65536
$script:MaximumRehearsalBytes = [int64]8388608
$script:MaximumRowsPerSource = 20000
$script:MaximumDiagnosticRows = 4000
$script:MaximumOutputBytes = [int64]33554432

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    $resolvedInputPath = Join-Path $PSScriptRoot 'I.json'
}
else { $resolvedInputPath = $InputPath }
if ($Preflight -and -not [string]::IsNullOrWhiteSpace($RehearsalInputPath)) {
    throw 'Preflight cannot be combined with RehearsalInputPath.'
}

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}

function Read-BoundedJson {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][int64]$MaximumBytes
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "Required JSON file is missing: $resolved" }
    $item = Get-Item -LiteralPath $resolved -Force
    if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Reparse-point JSON input refused: $resolved" }
    if ([int64]$item.Length -le 0 -or [int64]$item.Length -gt $MaximumBytes) { throw "JSON input byte bound refused: $resolved" }
    [byte[]]$bytes = [IO.File]::ReadAllBytes($resolved)
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    $offset = 0
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $offset = 3 }
    try { $value = $encoding.GetString($bytes, $offset, $bytes.Length - $offset) | ConvertFrom-Json }
    catch { throw "JSON input parse failed: $resolved" }
    return [pscustomobject]@{ Path=$resolved; Bytes=[int64]$bytes.LongLength; Sha256=(Get-Sha256Hex -Bytes $bytes); Value=$value }
}

function Write-NewUtf8JsonResult {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Json
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    $parent = [IO.Path]::GetDirectoryName($resolved)
    if ([string]::IsNullOrWhiteSpace($parent) -or -not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Output parent must already exist.' }
    if (((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Reparse-point output parent refused.' }
    if ([IO.Path]::GetExtension($resolved) -cne '.json' -or [IO.Path]::GetFileName($resolved).Length -gt 80 -or $resolved.Length -ge 200) { throw 'Output JSON path safety bound refused.' }
    [byte[]]$bytes = [Text.UTF8Encoding]::new($false, $true).GetBytes($Json)
    if ($bytes.LongLength -le 0 -or $bytes.LongLength -gt $script:MaximumOutputBytes) { throw "Output JSON byte bound refused: $($bytes.LongLength)" }
    $stream = [IO.FileStream]::new($resolved, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length); $stream.Flush($true) }
    finally { $stream.Dispose() }
    return [pscustomobject][ordered]@{
        schema='argos_r18uq3_result_write_receipt_v1'
        state='PASS_R18UQ3_RESULT_WRITTEN_CREATE_NEW'
        path=$resolved
        bytes=[int64]$bytes.LongLength
        sha256=Get-Sha256Hex -Bytes $bytes
        overwritePermitted=$false
        credentialsReturned=$false
    }
}

function Get-QueryInput {
    param([Parameter(Mandatory=$true)][string]$Path)
    $snapshot = Read-BoundedJson -Path $Path -MaximumBytes $script:MaximumInputBytes
    $value = $snapshot.Value
    if ([string]$value.schema -cne $script:ExpectedInputSchema) { throw 'R18UQ3 input schema mismatch.' }
    if ([string]$value.sourceCatalogSha256 -cne $script:ExpectedCatalogSha256) { throw 'R18UQ3 source catalog hash mismatch.' }
    if ([string]$value.queryKeyFingerprintSha256 -cne $script:ExpectedKeyFingerprintSha256) { throw 'R18UQ3 declared key fingerprint mismatch.' }
    $keys = @($value.queryKeys | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() })
    if ($keys.Count -ne $script:ExpectedKeyCount -or @($keys | Sort-Object -Unique).Count -ne $script:ExpectedKeyCount) { throw 'R18UQ3 requires exactly 50 unique query keys.' }
    foreach ($key in $keys) { if ($key -notmatch '^\d{5}-\d{3}[A-Z]?$') { throw "Malformed R18UQ3 query key: $key" } }
    $fingerprint = Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes(($keys -join "`n")))
    if ($fingerprint -cne $script:ExpectedKeyFingerprintSha256) { throw 'R18UQ3 exact ordered key set mismatch.' }
    return [pscustomobject]@{ Path=$snapshot.Path; Bytes=$snapshot.Bytes; Sha256=$snapshot.Sha256; Keys=$keys; FingerprintSha256=$fingerprint }
}

function Get-RowValue {
    param([AllowNull()][object]$Row, [Parameter(Mandatory=$true)][string]$Name)
    if ($null -eq $Row) { return $null }
    $value = $null
    if ($Row -is [Data.DataRow] -and $null -ne $Row.Table -and $Row.Table.Columns.Contains($Name)) { $value = $Row[$Name] }
    else { $property = $Row.PSObject.Properties[$Name]; if ($null -ne $property) { $value = $property.Value } }
    if ($null -eq $value -or $value -is [DBNull]) { return $null }
    if ($value -is [DateTime]) { return $value.ToString('yyyy-MM-ddTHH:mm:ss.fffffff', [Globalization.CultureInfo]::InvariantCulture) }
    $text = ([string]$value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $null }
    return $text
}

function Get-FixedSqlCredential {
    Add-Type -AssemblyName System.Security
    $snapshot = Read-BoundedJson -Path $script:CredentialPath -MaximumBytes ([int64]65536)
    $record = $snapshot.Value
    if ([string]$record.schema -cne $script:CredentialSchema) { throw 'Stored credential schema refused.' }
    $userName = [string]$record.userName
    [byte[]]$entropy = $null; [byte[]]$protected = $null; [byte[]]$plain = $null; $password = $null
    try {
        $entropy = [Convert]::FromBase64String([string]$record.entropy)
        $protected = [Convert]::FromBase64String([string]$record.protectedPassword)
        $plain = [Security.Cryptography.ProtectedData]::Unprotect($protected, $entropy, [Security.Cryptography.DataProtectionScope]::LocalMachine)
        $password = [Text.UTF8Encoding]::new($false, $true).GetString($plain)
        return [Management.Automation.PSCredential]::new($userName, (ConvertTo-SecureString $password -AsPlainText -Force))
    }
    finally {
        if ($null -ne $plain) { [Array]::Clear($plain, 0, $plain.Length) }
        if ($null -ne $protected) { [Array]::Clear($protected, 0, $protected.Length) }
        if ($null -ne $entropy) { [Array]::Clear($entropy, 0, $entropy.Length) }
        $password=$null; $userName=$null; $record=$null; $snapshot=$null
    }
}

$script:DirectSqlTemplate = @"
select distinct
    p.ContainerName as ParentContainer,
    c.ContainerName as UnitContainer,
    replace(c.Substrate, ' ', '') as Scribe
from Insite.Container c
join Insite.Container p on c.ParentContainerId = p.ContainerId
where p.ContainerName in (__PARENT_PARAMETERS__)
order by ParentContainer, UnitContainer, Scribe
"@

$script:IssueSqlTemplate = @"
select distinct
    replace(ce.Substrate, ' ', '') as Scribe,
    ce.ContainerName as SourceEpiContainer,
    cf.ContainerName as IssuedWaferContainer,
    pc.ContainerName as ParentContainer,
    hm.TxnDate as IssueTxnDate,
    hm.TxnServiceName as IssueTxnServiceName,
    hm.TxnType as IssueTxnType
from Insite.Container ce
join Insite.IssueActualsHistory ia on ia.FromContainerId = ce.ContainerId
join Insite.Container cf on ia.ToContainerId = cf.ContainerId
left join Insite.Container pc on cf.ParentContainerId = pc.ContainerId
left join Insite.IssueHistoryDetail ihd on ia.IssueHistoryDetailId = ihd.IssueHistoryDetailId
left join Insite.ComponentIssueHistory cih on ihd.ComponentIssueHistoryId = cih.ComponentIssueHistoryId
left join Insite.HistoryMainline hm on cih.HistoryMainlineId = hm.HistoryMainlineId
where pc.ContainerName in (__PARENT_PARAMETERS__)
   or (__ISSUED_KEY_PREDICATES__)
order by IssuedWaferContainer, Scribe, SourceEpiContainer
"@

$script:AssociateSqlTemplate = @"
select distinct
    p.ContainerName as ParentContainer,
    chc.ContainerName as UnitContainer,
    replace(chc.Substrate, ' ', '') as Scribe,
    hm.TxnDate as MembershipTxnDate,
    hm.TxnServiceName as MembershipTxnServiceName,
    hm.TxnType as MembershipTxnType,
    ah.AssociateHistoryId as MembershipEventId
from Insite.AssociateHistory ah
join Insite.AssociateHistoryChildCnts ahc on ahc.AssociateHistoryId = ah.AssociateHistoryId
join Insite.Container p on p.ContainerId = ah.ParentContainerId
join Insite.Container chc on chc.ContainerId = ahc.ChildContainersId
left join Insite.HistoryMainline hm on hm.HistoryMainlineId = ah.HistoryMainlineId
where p.ContainerName in (__PARENT_PARAMETERS__)
order by ParentContainer, UnitContainer, MembershipTxnDate
"@

$script:DisassociateSqlTemplate = @"
select distinct
    p.ContainerName as ParentContainer,
    chc.ContainerName as UnitContainer,
    replace(chc.Substrate, ' ', '') as Scribe,
    hm.TxnDate as MembershipTxnDate,
    hm.TxnServiceName as MembershipTxnServiceName,
    hm.TxnType as MembershipTxnType,
    dh.DisassociateHistoryId as MembershipEventId
from Insite.DisassociateHistory dh
join Insite.DisassociateHistoryChildCnts dhc on dhc.DisassociateHistoryId = dh.DisassociateHistoryId
join Insite.Container p on p.ContainerId = dh.ParentContainerId
join Insite.Container chc on chc.ContainerId = dhc.ChildContainersId
left join Insite.HistoryMainline hm on hm.HistoryMainlineId = dh.HistoryMainlineId
where p.ContainerName in (__PARENT_PARAMETERS__)
order by ParentContainer, UnitContainer, MembershipTxnDate
"@

function New-QueryPlan {
    param(
        [Parameter(Mandatory=$true)][string]$Template,
        [Parameter(Mandatory=$true)][string[]]$Keys,
        [Parameter(Mandatory=$true)][ValidateSet('SQLCLIENT','ODBC')][string]$Provider,
        [switch]$IncludeIssuedPredicates
    )
    $parameters = New-Object Collections.Generic.List[object]
    if ($Provider -ceq 'SQLCLIENT') {
        $parentNames = New-Object Collections.Generic.List[string]
        for ($i=0; $i -lt $Keys.Count; $i++) {
            $name='@lot'+$i; $parentNames.Add($name); $parameters.Add([pscustomobject]@{ Name=$name; Value=$Keys[$i] })
        }
        $text = $Template.Replace('__PARENT_PARAMETERS__', ($parentNames.ToArray() -join ','))
        if ($IncludeIssuedPredicates) {
            $predicates = New-Object Collections.Generic.List[string]
            for ($i=0; $i -lt $Keys.Count; $i++) {
                $name='@issued'+$i; $predicates.Add("cf.ContainerName like $name + '-[0-9][0-9][0-9]'"); $parameters.Add([pscustomobject]@{ Name=$name; Value=$Keys[$i] })
            }
            $text = $text.Replace('__ISSUED_KEY_PREDICATES__', ($predicates.ToArray() -join ' or '))
        }
    }
    else {
        $markers = @($Keys | ForEach-Object { '?' })
        $text = $Template.Replace('__PARENT_PARAMETERS__', ($markers -join ','))
        foreach ($key in $Keys) { $parameters.Add([pscustomobject]@{ Name='?'; Value=$key }) }
        if ($IncludeIssuedPredicates) {
            $predicates = @($Keys | ForEach-Object { "cf.ContainerName like ? + '-[0-9][0-9][0-9]'" })
            $text = $text.Replace('__ISSUED_KEY_PREDICATES__', ($predicates -join ' or '))
            foreach ($key in $Keys) { $parameters.Add([pscustomobject]@{ Name='?'; Value=$key }) }
        }
    }
    if ($text.Contains('__PARENT_PARAMETERS__') -or $text.Contains('__ISSUED_KEY_PREDICATES__')) { throw 'SQL placeholder expansion incomplete.' }
    return [pscustomobject]@{ CommandText=$text; Parameters=$parameters.ToArray() }
}

function Read-SqlClientTable {
    param([Data.SqlClient.SqlConnection]$Connection, $Plan)
    $command=$Connection.CreateCommand()
    try {
        $command.CommandTimeout=60; $command.CommandText=[string]$Plan.CommandText
        foreach ($spec in @($Plan.Parameters)) { $p=$command.Parameters.Add([string]$spec.Name,[Data.SqlDbType]::NVarChar,128); $p.Value=[string]$spec.Value }
        if ($command.Parameters.Count -ne @($Plan.Parameters).Count) { throw 'SqlClient parameter cardinality mismatch.' }
        $adapter=[Data.SqlClient.SqlDataAdapter]::new($command)
        try { $table=[Data.DataTable]::new(); [void]$adapter.Fill($table) } finally { $adapter.Dispose() }
        if ($table.Rows.Count -gt $script:MaximumRowsPerSource) { throw 'SqlClient row cap exceeded.' }
        return ,$table
    }
    finally { $command.Dispose() }
}

function Read-OdbcTable {
    param([Data.Odbc.OdbcConnection]$Connection, $Plan)
    $command=$Connection.CreateCommand()
    try {
        $command.CommandTimeout=60; $command.CommandText=[string]$Plan.CommandText; $index=0
        foreach ($spec in @($Plan.Parameters)) {
            $p=$command.CreateParameter(); $p.ParameterName='p'+$index; $p.OdbcType=[Data.Odbc.OdbcType]::NVarChar; $p.Size=128; $p.Value=[string]$spec.Value
            [void]$command.Parameters.Add($p); $index++
        }
        if ($command.Parameters.Count -ne @($Plan.Parameters).Count) { throw 'ODBC positional parameter cardinality mismatch.' }
        $adapter=[Data.Odbc.OdbcDataAdapter]::new($command)
        try { $table=[Data.DataTable]::new(); [void]$adapter.Fill($table) } finally { $adapter.Dispose() }
        if ($table.Rows.Count -gt $script:MaximumRowsPerSource) { throw 'ODBC row cap exceeded.' }
        return ,$table
    }
    finally { $command.Dispose() }
}

function Get-LiveSqlRows {
    param([Parameter(Mandatory=$true)][string[]]$Keys)
    $fixedCredential=$null; $builder=$null; $connection=$null
    try {
        $fixedCredential=Get-FixedSqlCredential
        $builder=[Data.SqlClient.SqlConnectionStringBuilder]::new()
        $builder['Data Source']="tcp:$($script:SqlServer)"; $builder['Initial Catalog']=$script:Database
        $builder['User ID']=$fixedCredential.UserName; $builder['Password']=$fixedCredential.GetNetworkCredential().Password
        $builder['Integrated Security']=$false; $builder['Encrypt']=$true; $builder['TrustServerCertificate']=$true
        $builder['Connect Timeout']=10; $builder['Application Name']='ArgosEdgeLabR18UQ3ReadOnlyRoster'
        $builder['ApplicationIntent']='ReadOnly'; $builder['Persist Security Info']=$false
        $connection=[Data.SqlClient.SqlConnection]::new($builder.ConnectionString); $builder['Password']=''; $fixedCredential=$null
        $connection.Open()
        $direct=Read-SqlClientTable -Connection $connection -Plan (New-QueryPlan -Template $script:DirectSqlTemplate -Keys $Keys -Provider SQLCLIENT)
        $issue=Read-SqlClientTable -Connection $connection -Plan (New-QueryPlan -Template $script:IssueSqlTemplate -Keys $Keys -Provider SQLCLIENT -IncludeIssuedPredicates)
        $associate=Read-SqlClientTable -Connection $connection -Plan (New-QueryPlan -Template $script:AssociateSqlTemplate -Keys $Keys -Provider SQLCLIENT)
        $disassociate=Read-SqlClientTable -Connection $connection -Plan (New-QueryPlan -Template $script:DisassociateSqlTemplate -Keys $Keys -Provider SQLCLIENT)
        return [pscustomobject]@{
            DirectRows=@($direct.Rows | ForEach-Object { $_ }); IssueRows=@($issue.Rows | ForEach-Object { $_ })
            AssociateRows=@($associate.Rows | ForEach-Object { $_ }); DisassociateRows=@($disassociate.Rows | ForEach-Object { $_ })
            ExecutionMode='LIVE_READ_ONLY_SQL'; CredentialSource='FIXED_ARGOS_DPAPI_LOCAL_MACHINE_ENVELOPE'
            OdbcDsn=$null; Database=$script:Database; RehearsalInputPath=$null; RehearsalInputSha256=$null
        }
    }
    finally {
        if ($null -ne $connection) { if ($connection.State -ne [Data.ConnectionState]::Closed) { $connection.Close() }; $connection.Dispose() }
        if ($null -ne $builder) { $builder['Password']='' }
        $fixedCredential=$null
    }
}

function Get-LiveOdbcRows {
    param(
        [Parameter(Mandatory=$true)][string[]]$Keys,
        [Parameter(Mandatory=$true)][string]$Dsn,
        [Parameter(Mandatory=$true)][Management.Automation.PSCredential]$SuppliedCredential
    )
    if ([string]::IsNullOrWhiteSpace($Dsn) -or $Dsn.Length -gt 128 -or $Dsn.IndexOfAny([char[]]"`r`n`0") -ge 0) { throw 'Caller-supplied ODBC DSN refused.' }
    if ([string]::IsNullOrWhiteSpace($SuppliedCredential.UserName) -or $SuppliedCredential.UserName.Length -gt 256) { throw 'Caller-supplied ODBC user identity refused.' }
    $builder=[Data.Odbc.OdbcConnectionStringBuilder]::new(); $connection=$null
    try {
        $builder['Dsn']=$Dsn; $builder['Database']=$script:OdbcDatabase; $builder['Uid']=$SuppliedCredential.UserName
        $builder['Pwd']=$SuppliedCredential.GetNetworkCredential().Password; $builder['APP']='ArgosEdgeLabR18UQ3ReadOnlyRoster'
        $connection=[Data.Odbc.OdbcConnection]::new($builder.ConnectionString); $builder['Pwd']=''; $connection.Open()
        $direct=Read-OdbcTable -Connection $connection -Plan (New-QueryPlan -Template $script:DirectSqlTemplate -Keys $Keys -Provider ODBC)
        $issue=Read-OdbcTable -Connection $connection -Plan (New-QueryPlan -Template $script:IssueSqlTemplate -Keys $Keys -Provider ODBC -IncludeIssuedPredicates)
        $associate=Read-OdbcTable -Connection $connection -Plan (New-QueryPlan -Template $script:AssociateSqlTemplate -Keys $Keys -Provider ODBC)
        $disassociate=Read-OdbcTable -Connection $connection -Plan (New-QueryPlan -Template $script:DisassociateSqlTemplate -Keys $Keys -Provider ODBC)
        return [pscustomobject]@{
            DirectRows=@($direct.Rows | ForEach-Object { $_ }); IssueRows=@($issue.Rows | ForEach-Object { $_ })
            AssociateRows=@($associate.Rows | ForEach-Object { $_ }); DisassociateRows=@($disassociate.Rows | ForEach-Object { $_ })
            ExecutionMode='LIVE_READ_ONLY_ODBC_DSN'; CredentialSource='CALLER_SUPPLIED_PSCREDENTIAL_NOT_RETURNED'
            OdbcDsn=$Dsn; Database=$script:OdbcDatabase; RehearsalInputPath=$null; RehearsalInputSha256=$null
        }
    }
    finally {
        if ($null -ne $connection) { if ($connection.State -ne [Data.ConnectionState]::Closed) { $connection.Close() }; $connection.Dispose() }
        if ($null -ne $builder) { $builder['Pwd']='' }
        $SuppliedCredential=$null
    }
}

function Get-RehearsalRows {
    param([Parameter(Mandatory=$true)][string]$Path)
    $snapshot=Read-BoundedJson -Path $Path -MaximumBytes $script:MaximumRehearsalBytes
    if ([string]$snapshot.Value.schema -cne 'argos_r18uq3_sql_row_rehearsal_v1') { throw 'R18UQ3 rehearsal schema mismatch.' }
    $direct=@($snapshot.Value.directRows); $issue=@($snapshot.Value.issueHistoryRows)
    $associate=@($snapshot.Value.associateHistoryRows); $disassociate=@($snapshot.Value.disassociateHistoryRows)
    foreach ($rows in @($direct,$issue,$associate,$disassociate)) { if ($rows.Count -gt $script:MaximumRowsPerSource) { throw 'R18UQ3 rehearsal row cap exceeded.' } }
    return [pscustomobject]@{
        DirectRows=$direct; IssueRows=$issue; AssociateRows=$associate; DisassociateRows=$disassociate
        ExecutionMode='FILE_BACKED_SYNTHETIC_SQL_ROW_REHEARSAL'; CredentialSource='NONE_FILE_BACKED_SYNTHETIC_ROWS'
        OdbcDsn=$null; Database=$null; RehearsalInputPath=$snapshot.Path; RehearsalInputSha256=$snapshot.Sha256
    }
}

function New-StringSet { return ,[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase) }

function Test-UnitContainerSyntax {
    param([AllowNull()][string]$Unit)
    if ([string]::IsNullOrWhiteSpace($Unit)) { return $false }
    return $Unit -match '^\d{5}-\d{3}[A-Z]?-\d{3}(?:WAFER)?$'
}

function Get-ExactEmbeddedCatalogLot {
    param([Parameter(Mandatory=$true)][string]$Unit, [Parameter(Mandatory=$true)][string[]]$Keys)
    foreach ($key in @($Keys | Sort-Object Length -Descending)) {
        if ($Unit -match ('^'+[Text.RegularExpressions.Regex]::Escape($key)+'-\d{3}(?:WAFER)?$')) { return $key }
    }
    return $null
}

function Get-ExactIssuedUnitCatalogLot {
    param([Parameter(Mandatory=$true)][string]$Unit, [Parameter(Mandatory=$true)][string[]]$Keys)
    foreach ($key in $Keys) {
        if ($key -notmatch '^\d{5}-\d{3}$') { continue }
        if ($Unit -match ('^'+[Text.RegularExpressions.Regex]::Escape($key)+'-\d{3}$')) { return $key }
    }
    return $null
}

function New-InvalidRow {
    param([string]$Source,[int]$SourceRow,[string]$Code,[AllowNull()][string]$QueryLot,[AllowNull()][string]$Unit,[AllowNull()][string]$Scribe,[AllowNull()][string]$Parent)
    return [pscustomobject][ordered]@{ source=$Source; sourceRow=$SourceRow; code=$Code; queryLot=$QueryLot; unitContainer=$Unit; scribe=$Scribe; parentContainer=$Parent }
}

function New-EvidenceRow {
    param(
        [string]$Source,[int]$SourceRow,[string]$QueryLot,[string]$Unit,[string]$Scribe,[string]$ScribeKind,
        [string]$Parent,[AllowNull()][string]$SourceEpi,[string]$MembershipBasis,[AllowNull()][string]$Timestamp,
        [AllowNull()][string]$TimestampBasis,[AllowNull()][string]$EventService,[AllowNull()][string]$EventType,[AllowNull()][string]$EventId
    )
    return [pscustomobject][ordered]@{
        source=$Source; sourceRow=$SourceRow; queryLot=$QueryLot; unitContainer=$Unit; scribe=$Scribe
        scribeEvidenceClass=$ScribeKind; parentContainer=$Parent; sourceEpiContainer=$SourceEpi
        membershipEvidenceBasis=$MembershipBasis; timestamp=$Timestamp; timestampBasis=$TimestampBasis
        eventService=$EventService; eventType=$EventType; eventId=$EventId
    }
}

function Resolve-MemberGroup {
    param(
        [Parameter(Mandatory=$true)][string]$QueryLot,
        [Parameter(Mandatory=$true)][string]$Unit,
        [Parameter(Mandatory=$true)][object[]]$Rows,
        [Parameter(Mandatory=$true)][string]$ResolutionBasis,
        [Parameter(Mandatory=$true)][string[]]$ExactParentCandidates,
        [Parameter(Mandatory=$true)][string[]]$CatalogKeys
    )
    $currentCandidates=@($Rows | Where-Object { $_.scribeEvidenceClass -ceq 'CURRENT_CONTAINER_SUBSTRATE' } | ForEach-Object { $_.scribe } | Sort-Object -Unique)
    $historyCandidates=@($Rows | Where-Object { $_.scribeEvidenceClass -ceq 'ISSUE_ACTUALS_HISTORY' } | ForEach-Object { $_.scribe } | Sort-Object -Unique)
    $holdCodes=New-Object Collections.Generic.List[string]
    $parents=@($ExactParentCandidates | Where-Object { $_ } | Sort-Object -Unique)
    if ($parents.Count -gt 1) { $holdCodes.Add('EXACT_PARENT_MEMBERSHIP_CONTRADICTION') }
    $embedded=Get-ExactEmbeddedCatalogLot -Unit $Unit -Keys $CatalogKeys
    if ($null -ne $embedded -and $embedded -cne $QueryLot) { $holdCodes.Add('PARENT_UNIT_EXACT_CATALOG_CONTRADICTION') }
    if ($currentCandidates.Count -gt 1) { $holdCodes.Add('CURRENT_SCRIBE_AMBIGUITY') }
    if ($historyCandidates.Count -gt 1) { $holdCodes.Add('HISTORY_SCRIBE_AMBIGUITY') }
    if ($currentCandidates.Count -eq 1 -and $historyCandidates.Count -eq 1 -and $currentCandidates[0] -cne $historyCandidates[0]) {
        $holdCodes.Add('CURRENT_HISTORY_SCRIBE_DISAGREEMENT')
    }
    if ($currentCandidates.Count -eq 0 -and $historyCandidates.Count -eq 0) { $holdCodes.Add('NO_VALID_SCRIBE_CANDIDATE') }
    $allCandidates=@($currentCandidates + $historyCandidates | Sort-Object -Unique)
    if ($allCandidates.Count -gt 1 -and $holdCodes.Count -eq 0) { $holdCodes.Add('CROSS_SOURCE_SCRIBE_AMBIGUITY') }
    $orderedRows=@($Rows | Sort-Object source,sourceRow)
    $timestamps=@($orderedRows | ForEach-Object { $_.timestamp } | Where-Object { $_ } | Sort-Object -Unique)
    $common=[ordered]@{
        queryLot=$QueryLot
        unitContainer=$Unit
        resolutionBasis=$ResolutionBasis
        parentContainers=@($orderedRows.parentContainer | Where-Object { $_ } | Sort-Object -Unique)
        sourceEpiContainers=@($orderedRows.sourceEpiContainer | Where-Object { $_ } | Sort-Object -Unique)
        evidenceSources=@($orderedRows.source | Sort-Object -Unique)
        acquisitionTimestamps=$timestamps
        evidence=$orderedRows
    }
    if ($holdCodes.Count -gt 0) {
        return [pscustomobject]@{
            IsResolved=$false
            Record=[pscustomobject][ordered]@{
                queryLot=$common.queryLot; unitContainer=$common.unitContainer; resolvedScribe=$null
                resolutionBasis=$common.resolutionBasis; holdCodes=@($holdCodes | Sort-Object -Unique)
                sourceSeparatedCandidates=[ordered]@{ currentContainerSubstrate=$currentCandidates; issueActualsHistory=$historyCandidates }
                parentContainers=$common.parentContainers; sourceEpiContainers=$common.sourceEpiContainers
                evidenceSources=$common.evidenceSources; acquisitionTimestamps=$common.acquisitionTimestamps; evidence=$common.evidence
            }
        }
    }
    return [pscustomobject]@{
        IsResolved=$true
        Record=[pscustomobject][ordered]@{
            queryLot=$common.queryLot; unitContainer=$common.unitContainer; resolvedScribe=[string]$allCandidates[0]
            resolutionBasis=$common.resolutionBasis; parentContainers=$common.parentContainers
            sourceEpiContainers=$common.sourceEpiContainers; evidenceSources=$common.evidenceSources
            acquisitionTimestamps=$common.acquisitionTimestamps; evidence=$common.evidence
        }
    }
}

function Build-RosterResult {
    param([Parameter(Mandatory=$true)]$InputSnapshot, [Parameter(Mandatory=$true)]$SqlRows)
    $keys=@($InputSnapshot.Keys); $catalog=New-StringSet; foreach ($key in $keys) { [void]$catalog.Add($key) }
    $evidence=New-Object Collections.Generic.List[object]
    $invalid=New-Object Collections.Generic.List[object]
    $ignoredHistoricalRows=New-Object Collections.Generic.List[object]

    $rowIndex=0
    foreach ($row in @($SqlRows.DirectRows)) {
        $rowIndex++
        $parent=Get-RowValue $row 'ParentContainer'; $unit=Get-RowValue $row 'UnitContainer'; $scribe=Get-RowValue $row 'Scribe'
        if ($parent) { $parent=$parent.ToUpperInvariant() }; if ($unit) { $unit=$unit.ToUpperInvariant() }; if ($scribe) { $scribe=($scribe -replace ' ','').ToUpperInvariant() }
        $codes=New-Object Collections.Generic.List[string]
        if ($null -eq $parent -or -not $catalog.Contains($parent)) { $codes.Add('DIRECT_PARENT_NOT_EXACT_QUERY_LOT') }
        if (-not (Test-UnitContainerSyntax $unit)) { $codes.Add('DIRECT_UNIT_CONTAINER_INVALID') }
        if ($null -eq $scribe -or $scribe -notmatch '^[A-Z0-9]{12}$') { $codes.Add('DIRECT_SCRIBE_NULL_OR_INVALID') }
        if ($codes.Count -gt 0) { foreach ($code in $codes) { $invalid.Add((New-InvalidRow 'DIRECT_CURRENT_CONTAINMENT' $rowIndex $code $parent $unit $scribe $parent)) }; continue }
        $evidence.Add((New-EvidenceRow 'DIRECT_CURRENT_CONTAINMENT' $rowIndex $parent $unit $scribe 'CURRENT_CONTAINER_SUBSTRATE' $parent $null 'EXACT_CURRENT_PARENT_CHILD' $null $null $null $null $null))
    }

    $rowIndex=0
    foreach ($row in @($SqlRows.IssueRows)) {
        $rowIndex++
        $parent=Get-RowValue $row 'ParentContainer'; $unit=Get-RowValue $row 'IssuedWaferContainer'; $scribe=Get-RowValue $row 'Scribe'
        $sourceEpi=Get-RowValue $row 'SourceEpiContainer'; $timestamp=Get-RowValue $row 'IssueTxnDate'
        $service=Get-RowValue $row 'IssueTxnServiceName'; $eventType=Get-RowValue $row 'IssueTxnType'
        if ($parent) { $parent=$parent.ToUpperInvariant() }; if ($unit) { $unit=$unit.ToUpperInvariant() }; if ($scribe) { $scribe=($scribe -replace ' ','').ToUpperInvariant() }
        $codes=New-Object Collections.Generic.List[string]
        if (-not (Test-UnitContainerSyntax $unit)) { $codes.Add('ISSUE_UNIT_CONTAINER_INVALID') }
        if ($null -eq $scribe -or $scribe -notmatch '^[A-Z0-9]{12}$') { $codes.Add('ISSUE_SCRIBE_NULL_OR_INVALID') }
        if ($codes.Count -gt 0) { foreach ($code in $codes) { $invalid.Add((New-InvalidRow 'ISSUE_ACTUALS_HISTORY' $rowIndex $code $null $unit $scribe $parent)) }; continue }
        $queryLot=$null; $membershipBasis='NO_EXACT_CATALOG_PARENT_OR_UNIT_IDENTITY'
        $exactUnitLot=Get-ExactIssuedUnitCatalogLot -Unit $unit -Keys $keys
        if ($null -ne $parent -and $catalog.Contains($parent)) {
            $queryLot=$parent
            $membershipBasis='EXACT_CURRENT_PARENT_FROM_ISSUE_ROW'
        }
        elseif ($null -ne $exactUnitLot) {
            $queryLot=$exactUnitLot
            $membershipBasis='EXACT_ISSUED_UNIT_CATALOG_KEY'
        }
        $evidence.Add((New-EvidenceRow 'ISSUE_ACTUALS_HISTORY' $rowIndex $queryLot $unit $scribe 'ISSUE_ACTUALS_HISTORY' $parent $sourceEpi $membershipBasis $timestamp 'ISSUE_HISTORY_TRANSACTION' $service $eventType $null))
    }

    foreach ($sourceSpec in @(
        [pscustomobject]@{ Name='ASSOCIATE_HISTORY'; Rows=@($SqlRows.AssociateRows); EventId='MembershipEventId' },
        [pscustomobject]@{ Name='DISASSOCIATE_HISTORY'; Rows=@($SqlRows.DisassociateRows); EventId='MembershipEventId' }
    )) {
        $rowIndex=0
        foreach ($row in @($sourceSpec.Rows)) {
            $rowIndex++
            $parent=Get-RowValue $row 'ParentContainer'; $unit=Get-RowValue $row 'UnitContainer'; $scribe=Get-RowValue $row 'Scribe'
            $timestamp=Get-RowValue $row 'MembershipTxnDate'; $service=Get-RowValue $row 'MembershipTxnServiceName'
            $eventType=Get-RowValue $row 'MembershipTxnType'; $eventId=Get-RowValue $row ([string]$sourceSpec.EventId)
            if ($parent) { $parent=$parent.ToUpperInvariant() }; if ($unit) { $unit=$unit.ToUpperInvariant() }; if ($scribe) { $scribe=($scribe -replace ' ','').ToUpperInvariant() }
            $codes=New-Object Collections.Generic.List[string]
            if ($null -eq $parent -or -not $catalog.Contains($parent)) { $codes.Add('HISTORICAL_PARENT_NOT_EXACT_QUERY_LOT') }
            if (-not (Test-UnitContainerSyntax $unit)) {
                if ($null -ne $parent -and $catalog.Contains($parent)) {
                    $ignoredHistoricalRows.Add([pscustomobject][ordered]@{
                        source=[string]$sourceSpec.Name; sourceRow=$rowIndex; code='IGNORED_NON_WAFER_HISTORICAL_CHILD'
                        queryLot=$parent; childContainer=$unit; childSubstrate=$scribe; eventTimestamp=$timestamp
                        evidenceBasis='EXACT_HISTORICAL_PARENT_WITH_NON_WAFER_CHILD_NOT_APPLICABLE_TO_ROSTER'
                    })
                    continue
                }
                $codes.Add('HISTORICAL_CHILD_CONTAINER_INVALID')
            }
            if ($null -eq $scribe -or $scribe -notmatch '^[A-Z0-9]{12}$') { $codes.Add('HISTORICAL_CHILD_SCRIBE_NULL_OR_INVALID') }
            if ($codes.Count -gt 0) { foreach ($code in $codes) { $invalid.Add((New-InvalidRow ([string]$sourceSpec.Name) $rowIndex $code $parent $unit $scribe $parent)) }; continue }
            $evidence.Add((New-EvidenceRow ([string]$sourceSpec.Name) $rowIndex $parent $unit $scribe 'CURRENT_CONTAINER_SUBSTRATE' $parent $null 'EXACT_HISTORICAL_PARENT_CHILD' $timestamp 'MEMBERSHIP_HISTORY_TRANSACTION' $service $eventType $eventId))
        }
    }

    if ($invalid.Count -gt $script:MaximumDiagnosticRows) { throw 'R18UQ3 invalid-row cap exceeded.' }
    $primary=@($evidence | Where-Object { $_.source -ceq 'DIRECT_CURRENT_CONTAINMENT' -or ($_.source -ceq 'ISSUE_ACTUALS_HISTORY' -and -not [string]::IsNullOrWhiteSpace([string]$_.queryLot)) })
    $orphanIssue=@($evidence | Where-Object { $_.source -ceq 'ISSUE_ACTUALS_HISTORY' -and [string]::IsNullOrWhiteSpace([string]$_.queryLot) })
    $historicalMembership=@($evidence | Where-Object { $_.source -ceq 'ASSOCIATE_HISTORY' -or $_.source -ceq 'DISASSOCIATE_HISTORY' })
    $attachedIssueRows=New-StringSet; $usedHistoricalRows=New-StringSet
    $lots=New-Object Collections.Generic.List[object]; $allResolved=New-Object Collections.Generic.List[object]; $allHeld=New-Object Collections.Generic.List[object]

    foreach ($key in $keys) {
        $resolved=New-Object Collections.Generic.List[object]; $held=New-Object Collections.Generic.List[object]
        $primaryLot=@($primary | Where-Object { $_.queryLot -ceq $key })
        $primaryUnits=@($primaryLot | ForEach-Object { $_.unitContainer } | Sort-Object -Unique)
        $selectedBasis='PRIMARY_EXACT_DB_PARENT'; $selectedRows=$primary; $selectedUnits=$primaryUnits
        if ($primaryUnits.Count -eq 0) {
            $fallbackLot=@($historicalMembership | Where-Object { $_.queryLot -ceq $key })
            $selectedBasis='FALLBACK_EXACT_HISTORICAL_PARENT_CHILD'; $selectedRows=$historicalMembership
            $selectedUnits=@($fallbackLot | ForEach-Object { $_.unitContainer } | Sort-Object -Unique)
        }
        foreach ($unit in $selectedUnits) {
            $groupRows=@($selectedRows | Where-Object { $_.queryLot -ceq $key -and $_.unitContainer -ceq $unit })
            $issueRows=@($evidence | Where-Object { $_.source -ceq 'ISSUE_ACTUALS_HISTORY' -and $_.unitContainer -ceq $unit -and ([string]::IsNullOrWhiteSpace([string]$_.queryLot) -or $_.queryLot -ceq $key) })
            foreach ($issueRow in $issueRows) { [void]$attachedIssueRows.Add([string]$issueRow.sourceRow) }
            $groupRows=@($groupRows + $issueRows | Sort-Object source,sourceRow -Unique)
            if ($selectedBasis -ceq 'PRIMARY_EXACT_DB_PARENT') {
                $parentCandidates=@($primary | Where-Object { $_.unitContainer -ceq $unit } | ForEach-Object { $_.queryLot } | Where-Object { $_ } | Sort-Object -Unique)
            }
            else {
                $parentCandidates=@($historicalMembership | Where-Object { $_.unitContainer -ceq $unit } | ForEach-Object { $_.queryLot } | Where-Object { $_ } | Sort-Object -Unique)
                foreach ($historyRow in @($historicalMembership | Where-Object { $_.queryLot -ceq $key -and $_.unitContainer -ceq $unit })) { [void]$usedHistoricalRows.Add("$($historyRow.source):$($historyRow.sourceRow)") }
            }
            $outcome=Resolve-MemberGroup -QueryLot $key -Unit $unit -Rows $groupRows -ResolutionBasis $selectedBasis -ExactParentCandidates $parentCandidates -CatalogKeys $keys
            if ($outcome.IsResolved) { $resolved.Add($outcome.Record); $allResolved.Add($outcome.Record) }
            else { $held.Add($outcome.Record); $allHeld.Add($outcome.Record) }
        }
        $lotState=if ($resolved.Count -eq 0) { 'HOLD_NO_RESOLVED_MEMBERS' } elseif ($held.Count -gt 0) { 'PARTIAL_HOLD' } else { 'COMPLETE' }
        $lots.Add([pscustomobject][ordered]@{
            queryLot=$key; state=$lotState; resolvedMemberCount=$resolved.Count; heldMemberCount=$held.Count
            resolvedMembers=$resolved.ToArray(); heldMembers=$held.ToArray()
        })
    }

    foreach ($issueRow in $orphanIssue) {
        if (-not $attachedIssueRows.Contains([string]$issueRow.sourceRow)) {
            $invalid.Add((New-InvalidRow 'ISSUE_ACTUALS_HISTORY' ([int]$issueRow.sourceRow) 'NO_EXACT_DB_PARENT_MEMBERSHIP_EVIDENCE' $null ([string]$issueRow.unitContainer) ([string]$issueRow.scribe) ([string]$issueRow.parentContainer)))
        }
    }
    if ($invalid.Count -gt $script:MaximumDiagnosticRows) { throw 'R18UQ3 diagnostic cap exceeded after reconciliation.' }
    $unresolvedLots=@($lots | Where-Object { $_.resolvedMemberCount -eq 0 } | ForEach-Object { $_.queryLot })
    $unisolated=@()
    $represented=$keys.Count-$unresolvedLots.Count
    $zeroHoldComplete=($represented -eq $keys.Count -and $allHeld.Count -eq 0 -and $invalid.Count -eq 0 -and $unisolated.Count -eq 0)
    $usableWithHolds=($represented -eq $keys.Count -and $allHeld.Count -gt 0 -and $invalid.Count -eq 0 -and $unisolated.Count -eq 0)
    if ($zeroHoldComplete) { $disposition='COMPLETE'; $state='PASS_R18UQ3_EXHAUSTIVE_ROSTER' }
    elseif ($usableWithHolds) { $disposition='USABLE_WITH_HOLDS'; $state='PASS_R18UQ3_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS' }
    else { $disposition='HOLD'; $state='HOLD_R18UQ3_ROSTER_NOT_USABLE' }
    $holds=New-Object Collections.Generic.List[object]
    if ($unresolvedLots.Count -gt 0) { $holds.Add([pscustomobject]@{ code='LOTS_WITH_ZERO_RESOLVED_MEMBERS'; count=$unresolvedLots.Count }) }
    if ($allHeld.Count -gt 0) { $holds.Add([pscustomobject]@{ code='ISOLATED_HELD_MEMBERS'; count=$allHeld.Count }) }
    if ($invalid.Count -gt 0) { $holds.Add([pscustomobject]@{ code='INVALID_OR_UNMAPPED_SOURCE_ROWS'; count=$invalid.Count }) }
    if ($unisolated.Count -gt 0) { $holds.Add([pscustomobject]@{ code='UNISOLATED_AMBIGUITIES'; count=$unisolated.Count }) }
    $ignoredApplicableHistoricalMembership=$historicalMembership.Count-$usedHistoricalRows.Count

    return [pscustomobject][ordered]@{
        schema='argos_r18uq3_exhaustive_lot_scribe_roster_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        executionState='PASS_R18UQ3_READ_ONLY_QUERY_EXECUTED'
        disposition=$disposition
        state=$state
        executionMode=[string]$SqlRows.ExecutionMode
        input=[ordered]@{ path=$InputSnapshot.Path; bytes=[int64]$InputSnapshot.Bytes; sha256=$InputSnapshot.Sha256; sourceCatalogSha256=$script:ExpectedCatalogSha256; queryKeyFingerprintSha256=$InputSnapshot.FingerprintSha256; queryKeyCount=$keys.Count }
        provenance=[ordered]@{
            serverTarget=$script:SqlServer; database=$SqlRows.Database; odbcDsn=$SqlRows.OdbcDsn
            sourceTables=@('Insite.Container','Insite.IssueActualsHistory','Insite.IssueHistoryDetail','Insite.ComponentIssueHistory','Insite.HistoryMainline','Insite.AssociateHistory','Insite.AssociateHistoryChildCnts','Insite.DisassociateHistory','Insite.DisassociateHistoryChildCnts')
            directSqlSha256=Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($script:DirectSqlTemplate))
            issueSqlSha256=Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($script:IssueSqlTemplate))
            associateSqlSha256=Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($script:AssociateSqlTemplate))
            disassociateSqlSha256=Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes($script:DisassociateSqlTemplate))
            credentialSource=[string]$SqlRows.CredentialSource; credentialMaterialReturned=$false
            rehearsalInputPath=$SqlRows.RehearsalInputPath; rehearsalInputSha256=$SqlRows.RehearsalInputSha256
        }
        counts=[ordered]@{
            queryLots=$keys.Count; representedLots=$represented; resolvedMembers=$allResolved.Count; heldMembers=$allHeld.Count
            invalidOrNullRows=$invalid.Count; unresolvedLots=$unresolvedLots.Count; unisolatedAmbiguities=$unisolated.Count
            directCurrentContainmentRows=@($SqlRows.DirectRows).Count; issueActualsHistoryRows=@($SqlRows.IssueRows).Count
            associateHistoryRows=@($SqlRows.AssociateRows).Count; disassociateHistoryRows=@($SqlRows.DisassociateRows).Count
            ignoredHistoricalRows=$ignoredHistoricalRows.Count
            ignoredApplicableHistoricalMembershipRows=$ignoredApplicableHistoricalMembership
        }
        lots=$lots.ToArray()
        invalidOrNullRows=@($invalid | Sort-Object source,sourceRow,code)
        ignoredHistoricalRows=@($ignoredHistoricalRows | Sort-Object source,sourceRow,code)
        unresolvedLots=$unresolvedLots
        unisolatedAmbiguities=$unisolated
        holds=$holds.ToArray()
        invariants=[ordered]@{
            readOnlySql=$true; parameterizedLotKeys=$true; exactDatabaseParentOrIssuedUnitEvidenceRequired=$true
            exactUnsuffixedIssuedUnitCatalogKeyEvidenceAccepted=$true; issueWaferSuffixIdentityAccepted=$false
            issuedUnitSuffixInferenceUsed=$false; historicalMembershipFallbackOnly=$true
            heldMembersExcludedFromResolvedScribes=$true; credentialsReturned=$false
            imagesAccessed=$false; jbodAccessed=$false; tasksOrProcessesAccessed=$false; queuesAccessed=$false
            sourceMutationPerformed=$false; productionRoutingEnabled=$false
        }
    }
}

$queryInput=Get-QueryInput -Path $resolvedInputPath

if ($Preflight) {
    $plans=[ordered]@{
        directSqlClient=New-QueryPlan -Template $script:DirectSqlTemplate -Keys $queryInput.Keys -Provider SQLCLIENT
        issueSqlClient=New-QueryPlan -Template $script:IssueSqlTemplate -Keys $queryInput.Keys -Provider SQLCLIENT -IncludeIssuedPredicates
        associateSqlClient=New-QueryPlan -Template $script:AssociateSqlTemplate -Keys $queryInput.Keys -Provider SQLCLIENT
        disassociateSqlClient=New-QueryPlan -Template $script:DisassociateSqlTemplate -Keys $queryInput.Keys -Provider SQLCLIENT
        directOdbc=New-QueryPlan -Template $script:DirectSqlTemplate -Keys $queryInput.Keys -Provider ODBC
        issueOdbc=New-QueryPlan -Template $script:IssueSqlTemplate -Keys $queryInput.Keys -Provider ODBC -IncludeIssuedPredicates
        associateOdbc=New-QueryPlan -Template $script:AssociateSqlTemplate -Keys $queryInput.Keys -Provider ODBC
        disassociateOdbc=New-QueryPlan -Template $script:DisassociateSqlTemplate -Keys $queryInput.Keys -Provider ODBC
    }
    $fingerprint={ param($Plan) Get-Sha256Hex -Bytes ([Text.UTF8Encoding]::new($false).GetBytes((@($Plan.Parameters | ForEach-Object { $_.Value }) -join "`n"))) }
    $preflightResult=[ordered]@{
        schema='argos_r18uq3_query_preflight_v1'; state='PASS_R18UQ3_QUERY_PREFLIGHT'
        inputPath=$queryInput.Path; inputBytes=$queryInput.Bytes; inputSha256=$queryInput.Sha256
        sourceCatalogSha256=$script:ExpectedCatalogSha256; queryKeyFingerprintSha256=$queryInput.FingerprintSha256; queryKeyCount=$queryInput.Keys.Count
        parameterCardinalities=[ordered]@{
            sqlClientDirect=@($plans.directSqlClient.Parameters).Count; sqlClientIssue=@($plans.issueSqlClient.Parameters).Count
            sqlClientAssociate=@($plans.associateSqlClient.Parameters).Count; sqlClientDisassociate=@($plans.disassociateSqlClient.Parameters).Count
            odbcDirect=@($plans.directOdbc.Parameters).Count; odbcIssue=@($plans.issueOdbc.Parameters).Count
            odbcAssociate=@($plans.associateOdbc.Parameters).Count; odbcDisassociate=@($plans.disassociateOdbc.Parameters).Count
        }
        parameterFingerprints=[ordered]@{
            sqlClientDirect=& $fingerprint $plans.directSqlClient; sqlClientIssue=& $fingerprint $plans.issueSqlClient
            sqlClientAssociate=& $fingerprint $plans.associateSqlClient; sqlClientDisassociate=& $fingerprint $plans.disassociateSqlClient
            odbcDirect=& $fingerprint $plans.directOdbc; odbcIssue=& $fingerprint $plans.issueOdbc
            odbcAssociate=& $fingerprint $plans.associateOdbc; odbcDisassociate=& $fingerprint $plans.disassociateOdbc
        }
        sourceTables=@('Insite.Container','Insite.IssueActualsHistory','Insite.IssueHistoryDetail','Insite.ComponentIssueHistory','Insite.HistoryMainline','Insite.AssociateHistory','Insite.AssociateHistoryChildCnts','Insite.DisassociateHistory','Insite.DisassociateHistoryChildCnts')
        defaultCredentialSource='FIXED_ARGOS_DPAPI_LOCAL_MACHINE_ENVELOPE'; optionalCredentialSource='CALLER_SUPPLIED_PSCREDENTIAL_NOT_RETURNED'
        optionalExecutionMode='LIVE_READ_ONLY_ODBC_DSN'; optionalOdbcDatabase=$script:OdbcDatabase
        exactDatabaseParentOrIssuedUnitEvidenceRequired=$true; exactUnsuffixedIssuedUnitCatalogKeyEvidenceAccepted=$true
        issueWaferSuffixIdentityAccepted=$false
        issuedUnitSuffixInferenceUsed=$false; historicalMembershipFallbackOnly=$true
        credentialAccessed=$false; databaseConnectionOpened=$false; networkAccessPerformed=$false; writesPerformed=$false
        imagesAccessed=$false; jbodAccessed=$false; productionRoutingEnabled=$false
    }
    Write-Output -NoEnumerate ($preflightResult | ConvertTo-Json -Depth 8 -Compress)
    return
}

if (-not [string]::IsNullOrWhiteSpace($RehearsalInputPath)) {
    if (-not [string]::IsNullOrWhiteSpace($OdbcDsn) -or $null -ne $Credential) { throw 'RehearsalInputPath cannot be combined with OdbcDsn or Credential.' }
    $rows=Get-RehearsalRows -Path $RehearsalInputPath
}
elseif (-not [string]::IsNullOrWhiteSpace($OdbcDsn) -or $null -ne $Credential) {
    if ([string]::IsNullOrWhiteSpace($OdbcDsn) -or $null -eq $Credential) { throw 'Live ODBC execution requires both OdbcDsn and Credential.' }
    $rows=Get-LiveOdbcRows -Keys $queryInput.Keys -Dsn $OdbcDsn -SuppliedCredential $Credential
}
else { $rows=Get-LiveSqlRows -Keys $queryInput.Keys }

$result=Build-RosterResult -InputSnapshot $queryInput -SqlRows $rows
$json=$result | ConvertTo-Json -Depth 20 -Compress
if ([string]::IsNullOrWhiteSpace($OutputPath)) { Write-Output -NoEnumerate $json }
else { Write-Output -NoEnumerate ((Write-NewUtf8JsonResult -Path $OutputPath -Json $json) | ConvertTo-Json -Depth 4 -Compress) }
