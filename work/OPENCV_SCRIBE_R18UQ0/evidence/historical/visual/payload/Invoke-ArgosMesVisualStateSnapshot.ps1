[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Scribe,

    [Parameter(Mandatory = $true)]
    [System.Management.Automation.PSCredential] $SqlCredential,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string] $OutputPath,

    [string] $SqlServer = 'TXSH-OCSQL.AMER.II-VI.NET,1433',

    [string] $Database = 'INSITE'
)

$ErrorActionPreference = 'Stop'

$scribes = @(
    $Scribe |
        ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } |
        Sort-Object -Unique
)

if ($scribes.Count -eq 0) {
    throw 'No scribes were supplied.'
}

foreach ($key in $scribes) {
    if ($key -notmatch '^[A-Z0-9]{12}$') {
        throw "Refusing invalid 12-character scribe: $key"
    }
}

$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $resolvedOutput) {
    throw "Refusing to overwrite existing output: $resolvedOutput"
}

$outputParent = Split-Path -Parent $resolvedOutput
if (-not (Test-Path -LiteralPath $outputParent)) {
    New-Item -ItemType Directory -Path $outputParent | Out-Null
}

$builder = [Data.SqlClient.SqlConnectionStringBuilder]::new()
$builder['Data Source'] = "tcp:$SqlServer"
$builder['Initial Catalog'] = $Database
$builder['User ID'] = $SqlCredential.UserName
$builder['Password'] = $SqlCredential.GetNetworkCredential().Password
$builder['Integrated Security'] = $false
$builder['TrustServerCertificate'] = $true
$builder['Connect Timeout'] = 10
$builder['Application Name'] = 'ArgosEdgeLabReadOnlyVisualStateSnapshot'

$connection = [Data.SqlClient.SqlConnection]::new($builder.ConnectionString)
$snapshotUtc = [DateTime]::UtcNow.ToString('o')
$resolverPath = Join-Path $PSScriptRoot 'Resolve-ArgosExactScribeLineage.ps1'
$expectedResolverHash = '45DEDB48B7DAFA634A8CB86ABE46314E0644ED9DA5506999A8FAA7BB022E0186'
if (-not (Test-Path -LiteralPath $resolverPath -PathType Leaf)) { throw "Exact-scribe lineage resolver is missing: $resolverPath" }
if ((Get-FileHash -LiteralPath $resolverPath -Algorithm SHA256).Hash -ne $expectedResolverHash) { throw 'Exact-scribe lineage resolver hash mismatch.' }
. $resolverPath

function Add-StringParameters {
    param(
        [Parameter(Mandatory = $true)]
        [Data.SqlClient.SqlCommand] $Command,
        [Parameter(Mandatory = $true)]
        [string] $Prefix,
        [Parameter(Mandatory = $true)]
        [string[]] $Values
    )

    $names = for ($index = 0; $index -lt $Values.Count; $index++) {
        $name = "@$Prefix$index"
        $parameter = $Command.Parameters.Add($name, [Data.SqlDbType]::NVarChar, 128)
        $parameter.Value = $Values[$index]
        $name
    }
    return ,$names
}

function Read-Table {
    param(
        [Parameter(Mandatory = $true)]
        [Data.SqlClient.SqlConnection] $Connection,
        [Parameter(Mandatory = $true)]
        [string] $Sql,
        [Parameter(Mandatory = $true)]
        [string] $ParameterPrefix,
        [Parameter(Mandatory = $true)]
        [string[]] $ParameterValues
    )

    $command = $Connection.CreateCommand()
    $command.CommandTimeout = 30
    $placeholder = Add-StringParameters -Command $command -Prefix $ParameterPrefix -Values $ParameterValues
    $command.CommandText = $Sql.Replace('__PARAMETERS__', ($placeholder -join ','))
    $adapter = [Data.SqlClient.SqlDataAdapter]::new($command)
    $table = [Data.DataTable]::new()
    [void] $adapter.Fill($table)
    $command.Dispose()
    return ,$table
}

function Value-OrNull([object] $value) {
    if ($null -eq $value -or $value -is [DBNull] -or [string]::IsNullOrWhiteSpace([string]$value)) {
        return $null
    }
    if ($value -is [DateTime]) {
        return $value.ToString('yyyy-MM-ddTHH:mm:ss')
    }
    return $value
}

function Row-ValueOrNull {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Row,
        [Parameter(Mandatory = $true)]
        [string] $Column
    )
    if ($Row -is [Data.DataRow] -and $null -ne $Row.Table -and $Row.Table.Columns.Contains($Column)) {
        return Value-OrNull $Row[$Column]
    }
    $property = $Row.PSObject.Properties[$Column]
    if ($null -eq $property) { return $null }
    return Value-OrNull $property.Value
}

function Rows-ByKey {
    param(
        [Parameter(Mandatory = $true)]
        [Data.DataTable] $Table,
        [Parameter(Mandatory = $true)]
        [string] $Column
    )

    $map = @{}
    foreach ($row in $Table.Rows) {
        $key = [string]$row[$Column]
        if (-not $map.ContainsKey($key)) {
            $map[$key] = [Collections.Generic.List[object]]::new()
        }
        $map[$key].Add($row)
    }
    return $map
}

try {
    $connection.Open()

    $epiSql = @"
select
    replace(SCRIBE_NUMBER, ' ', '') as Scribe,
    CONTAINERNAME as EpiWaferNumber,
    finProcessResourceName as EpiProcessResource,
    RESOURCENAME as MeasurementResource,
    PRODUCTNAME as EpiProductName,
    TXNDATE as EpiTransactionDate,
    DataCollectionHistoryID as DataCollectionHistoryId
from Insite.view_EPI_SCRIBENUMBER
where replace(SCRIBE_NUMBER, ' ', '') in (__PARAMETERS__)
order by Scribe, TXNDATE desc
"@
    $epiTable = Read-Table -Connection $connection -Sql $epiSql -ParameterPrefix 'scribe' -ParameterValues $scribes

    $lineageSql = @"
select distinct
    replace(ce.Substrate, ' ', '') as Scribe,
    ce.ContainerName as SourceEpiWafer,
    cf.ContainerName as IssuedWaferContainer,
    pc.ContainerName as MesStateContainer
from Insite.Container ce
join Insite.IssueActualsHistory ia on ia.FromContainerId = ce.ContainerId
left join Insite.Container cf on ia.ToContainerId = cf.ContainerId
left join Insite.Container pc on cf.ParentContainerId = pc.ContainerId
where replace(ce.Substrate, ' ', '') in (__PARAMETERS__)
order by Scribe, IssuedWaferContainer
"@
    $lineageTable = Read-Table -Connection $connection -Sql $lineageSql -ParameterPrefix 'lineageScribe' -ParameterValues $scribes

    # The portal's Unit Containers table is backed by current Insite.Container
    # rows.  Query those rows by the exact human-confirmed scribe.  This is a
    # second exact lineage path when IssueActualsHistory is incomplete; it is
    # never a lot, slot, or acquisition-position identity fallback.
    $directContainerSql = @"
select distinct
    replace(c.Substrate, ' ', '') as Scribe,
    c.ContainerName as UnitContainer,
    p.ContainerName as ParentContainer
from Insite.Container c
left join Insite.Container p on c.ParentContainerId = p.ContainerId
where replace(c.Substrate, ' ', '') in (__PARAMETERS__)
  and c.ContainerName like '%-[0-9][0-9][0-9]'
order by Scribe, UnitContainer
"@
    $directContainerTable = Read-Table -Connection $connection -Sql $directContainerSql -ParameterPrefix 'directScribe' -ParameterValues $scribes

    $epiByScribe = Rows-ByKey -Table $epiTable -Column 'Scribe'
    $lineageByScribe = Rows-ByKey -Table $lineageTable -Column 'Scribe'
    $directContainerByScribe = Rows-ByKey -Table $directContainerTable -Column 'Scribe'

    $resolved = foreach ($scribeKey in $scribes) {
        $epiMatches = @()
        if ($epiByScribe.ContainsKey($scribeKey)) {
            $epiMatches = @($epiByScribe[$scribeKey].ToArray() | Where-Object { $null -ne $_ })
        }
        $lineageMatches = @()
        if ($lineageByScribe.ContainsKey($scribeKey)) {
            $lineageMatches = @($lineageByScribe[$scribeKey].ToArray() | Where-Object { $null -ne $_ })
        }
        $directContainerMatches = @()
        if ($directContainerByScribe.ContainsKey($scribeKey)) {
            $directContainerMatches = @($directContainerByScribe[$scribeKey].ToArray() | Where-Object { $null -ne $_ })
        }
        Resolve-ArgosExactScribeLineage -Scribe $scribeKey -EpiMatches $epiMatches -IssueLineageMatches $lineageMatches -DirectContainerMatches $directContainerMatches
    }

    $stateKeys = @(
        $resolved |
            ForEach-Object { @($_.mesStateContainer, $_.historyBaseLot) } |
            Where-Object { $_ } |
            Sort-Object -Unique
    )

    $wipTable = [Data.DataTable]::new()
    $wipTable.Columns.Add('ContainerName') | Out-Null
    if ($stateKeys.Count -gt 0) {
        $wipSql = @"
select
    CONTAINERNAME as ContainerName,
    ProductName,
    ProductRevision,
    PRODUCTFAMILYNAME as ProdFamily,
    MAIN_WORKFLOW as DeviceWorkflow,
    SUBWORKFLOWNAME as ProcessBlockWorkflow,
    [PROCESS BLOCK] as ProcessBlock,
    STEPNAME as StepName,
    InProcess,
    OperationName,
    RESOURCENAME as ResourceName,
    InRework,
    LastActivityDate,
    LASTMOVEDATE as LastMoveDate
from Insite.RPT_VW_SHM_WIP
where CONTAINERNAME in (__PARAMETERS__)
order by CONTAINERNAME
"@
        $wipTable = Read-Table -Connection $connection -Sql $wipSql -ParameterPrefix 'stateContainer' -ParameterValues $stateKeys
    }
    $wipByContainer = Rows-ByKey -Table $wipTable -Column 'ContainerName'

    $historyTable = [Data.DataTable]::new()
    $historyTable.Columns.Add('ContainerName') | Out-Null
    $historyKeys = @($resolved.historyBaseLot | Where-Object { $_ } | Sort-Object -Unique)
    if ($historyKeys.Count -gt 0) {
        $historySql = @"
select
    c.ContainerName,
    ws.WorkflowStepName,
    pb.WorkflowStepName as ProcessBlockName,
    hm.TxnServiceName,
    hm.TxnType,
    hm.TxnDate,
    hm.HistoryMainlineId,
    cast(null as nvarchar(128)) as ResourceName,
    hm.TxnSummary
from Insite.HistoryMainline hm
join Insite.Container c on c.ContainerId = hm.ContainerId
left join Insite.WorkflowStep ws on ws.WorkflowStepId = hm.WorkflowStepId
left join Insite.WorkflowStep pb on pb.WorkflowStepId = hm.fnsr_ProcessBlockId
where c.ContainerName in (__PARAMETERS__)
  and ws.WorkflowStepName = 'SPUTTER BOW COMP DEP'
  and hm.TxnServiceName = 'MoveIn'
  and hm.TxnType = 2650
order by c.ContainerName, hm.TxnDate
"@
        $historyTable = Read-Table -Connection $connection -Sql $historySql -ParameterPrefix 'historyContainer' -ParameterValues $historyKeys
    }
    $historyByContainer = Rows-ByKey -Table $historyTable -Column 'ContainerName'

    $records = foreach ($item in $resolved) {
        $stateRow = $null
        if ($item.mesStateContainer -and $wipByContainer.ContainsKey([string]$item.mesStateContainer)) {
            $stateRow = $wipByContainer[[string]$item.mesStateContainer][0]
        }
        elseif ($item.historyBaseLot -and $wipByContainer.ContainsKey([string]$item.historyBaseLot)) {
            $stateRow = $wipByContainer[[string]$item.historyBaseLot][0]
        }

        $bowCompRows = @()
        if ($item.historyBaseLot -and $historyByContainer.ContainsKey([string]$item.historyBaseLot)) {
            $bowCompRows = @($historyByContainer[[string]$item.historyBaseLot].ToArray() | Where-Object { $null -ne $_ })
        }

        $statusSemantic = if ($null -eq $stateRow -or $stateRow.InProcess -is [DBNull]) {
            'Unknown'
        }
        elseif ([bool]$stateRow.InProcess) {
            'In Process'
        }
        else {
            'In Queue'
        }

        $visualFields = if ($stateRow) {
            @(
                (Value-OrNull $stateRow.DeviceWorkflow)
                (Value-OrNull $stateRow.ProdFamily)
                (Value-OrNull $stateRow.ProductName)
                (Value-OrNull $stateRow.ProductRevision)
                (Value-OrNull $stateRow.ProcessBlockWorkflow)
                (Value-OrNull $stateRow.ProcessBlock)
                (Value-OrNull $stateRow.StepName)
            )
        }
        else { @() }
        $visualComplete = $stateRow -and $statusSemantic -ne 'Unknown' -and @($visualFields | Where-Object { $null -eq $_ }).Count -eq 0
        $visualKey = if ($visualComplete) {
            $keyParts = @(
                'v1',
                [string]$stateRow.DeviceWorkflow,
                [string]$stateRow.ProdFamily,
                "$([string]$stateRow.ProductName)/$([string]$stateRow.ProductRevision)",
                [string]$stateRow.ProcessBlockWorkflow,
                [string]$stateRow.ProcessBlock,
                [string]$stateRow.StepName,
                $statusSemantic
            ) | ForEach-Object { $_.Trim().ToUpperInvariant() }
            $keyParts -join '|'
        }
        else { $null }

        $regimeState = if ($item.lineageState -ne 'MES_SCRIBE_LINEAGE_EXACT' -or -not $item.historyBaseLot) {
            'BACKSIDE_REGIME_HOLD_HISTORY_INCOMPLETE'
        }
        elseif ($bowCompRows.Count -gt 0) {
            'BACKSIDE_REGIME_BOWCOMP'
        }
        else {
            'BACKSIDE_REGIME_BARE'
        }

        [ordered]@{
            scribe = $item.scribe
            queryState = if ($stateRow) { 'MES_READ_ONLY_SNAPSHOT' } else { 'VISUAL_STATE_HOLD_INCOMPLETE_MES_STATE' }
            lineage = [ordered]@{
                state = $item.lineageState
                resolutionAuthority = $item.lineageResolutionAuthority
                epiWaferNumber = if ($item.epi) { Value-OrNull $item.epi.EpiWaferNumber } else { $null }
                issuedWaferContainer = $item.issuedWaferContainer
                mesStateContainer = $item.mesStateContainer
                historyBaseLot = $item.historyBaseLot
                directUnitContainer = $item.directUnitContainer
                directParentContainer = $item.directParentContainer
                directContainerMatchCount = $item.directContainerMatchCount
                lotSlotIdentityAuthorityUsed = $false
                epiProcessResource = if ($item.epi) { Value-OrNull $item.epi.EpiProcessResource } else { $null }
                measurementResource = if ($item.epi) { Value-OrNull $item.epi.MeasurementResource } else { $null }
            }
            visualState = [ordered]@{
                state = if ($visualComplete) { 'COMPLETE' } else { 'HOLD_INCOMPLETE' }
                keyVersion = 1
                key = $visualKey
                deviceWorkflow = if ($stateRow) { Value-OrNull $stateRow.DeviceWorkflow } else { $null }
                prodFamily = if ($stateRow) { Value-OrNull $stateRow.ProdFamily } else { $null }
                productName = if ($stateRow) { Value-OrNull $stateRow.ProductName } else { $null }
                productRevision = if ($stateRow) { Value-OrNull $stateRow.ProductRevision } else { $null }
                processBlockWorkflow = if ($stateRow) { Value-OrNull $stateRow.ProcessBlockWorkflow } else { $null }
                processBlock = if ($stateRow) { Value-OrNull $stateRow.ProcessBlock } else { $null }
                step = if ($stateRow) { Value-OrNull $stateRow.StepName } else { $null }
                statusSemantic = $statusSemantic
                rawInProcess = if ($stateRow -and $stateRow.InProcess -isnot [DBNull]) { [bool]$stateRow.InProcess } else { $null }
                operation = if ($stateRow) { Value-OrNull $stateRow.OperationName } else { $null }
                resource = if ($stateRow) { Value-OrNull $stateRow.ResourceName } else { $null }
                inRework = if ($stateRow) { Value-OrNull $stateRow.InRework } else { $null }
                lastActivityDate = if ($stateRow) { Value-OrNull $stateRow.LastActivityDate } else { $null }
                lastMoveDate = if ($stateRow) { Value-OrNull $stateRow.LastMoveDate } else { $null }
            }
            backsideRegime = [ordered]@{
                state = $regimeState
                ruleVersion = 1
                evidence = @($bowCompRows | ForEach-Object {
                    [ordered]@{
                        container = Value-OrNull $_.ContainerName
                        workflowStep = Value-OrNull $_.WorkflowStepName
                        processBlock = Value-OrNull $_.ProcessBlockName
                        txnServiceName = Value-OrNull $_.TxnServiceName
                        txnType = Value-OrNull $_.TxnType
                        txnDate = Value-OrNull $_.TxnDate
                        historyMainlineId = Value-OrNull $_.HistoryMainlineId
                        resource = Value-OrNull $_.ResourceName
                        summary = Value-OrNull $_.TxnSummary
                    }
                })
            }
        }
    }

    $document = [ordered]@{
        schemaVersion = 1
        authority = 'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT'
        snapshotUtc = $snapshotUtc
        serverTarget = $SqlServer
        database = $Database
        sourceTables = @(
            'Insite.view_EPI_SCRIBENUMBER',
            'Insite.Container',
            'Insite.IssueActualsHistory',
            'Insite.RPT_VW_SHM_WIP',
            'Insite.HistoryMainline',
            'Insite.WorkflowStep'
        )
        lookupKey = 'confirmed 12-character wafer scribe'
        statusContract = 'InProcess=true => In Process; false => In Queue; missing => hold'
        bowCompContract = 'SPUTTER BOW COMP DEP + MoveIn + TxnType 2650 on the scribe-linked history base lot'
        records = @($records)
    }

    $json = $document | ConvertTo-Json -Depth 12
    [IO.File]::WriteAllText($resolvedOutput, $json, [Text.UTF8Encoding]::new($false))
    Get-Item -LiteralPath $resolvedOutput
}
finally {
    if ($connection.State -ne 'Closed') {
        $connection.Close()
    }
    $connection.Dispose()
    $builder['Password'] = ''
}
