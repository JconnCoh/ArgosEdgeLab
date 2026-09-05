[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$QueryPath=Join-Path $PSScriptRoot 'Q2.ps1'
$InputPath=Join-Path $PSScriptRoot 'I.json'

function Assert-True { param([bool]$Condition,[string]$Message); if (-not $Condition) { throw $Message } }
function Write-Utf8NoBom { param([string]$Path,[string]$Text); [IO.File]::WriteAllText($Path,$Text,[Text.UTF8Encoding]::new($false)) }
function Invoke-Rehearsal {
    param([string]$Root,[string]$Name,$Rows)
    $path=Join-Path $Root ($Name+'.json')
    Write-Utf8NoBom $path (($Rows | ConvertTo-Json -Depth 8 -Compress))
    return ((& $QueryPath -InputPath $InputPath -RehearsalInputPath $path) | ConvertFrom-Json)
}
function New-Rows { return [ordered]@{ schema='argos_r18uq2_sql_row_rehearsal_v1'; directRows=@(); issueHistoryRows=@(); associateHistoryRows=@(); disassociateHistoryRows=@() } }

$tempRoot=Join-Path ([IO.Path]::GetTempPath()) ('ArgosR18UQ2_'+[Guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($tempRoot)
try {
    $input=Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json
    $keys=@($input.queryKeys)
    Assert-True ($keys.Count -eq 50) 'Fixture must contain exactly 50 query lots.'

    $preflight=(& $QueryPath -InputPath $InputPath -Preflight) | ConvertFrom-Json
    Assert-True ($preflight.state -ceq 'PASS_R18UQ2_QUERY_PREFLIGHT') 'Preflight state failed.'
    Assert-True ($preflight.parameterCardinalities.sqlClientDirect -eq 50) 'SqlClient direct cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.sqlClientIssue -eq 100) 'SqlClient issue cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.sqlClientAssociate -eq 50) 'SqlClient associate cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.sqlClientDisassociate -eq 50) 'SqlClient disassociate cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.odbcDirect -eq 50) 'ODBC direct cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.odbcIssue -eq 100) 'ODBC issue cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.odbcAssociate -eq 50) 'ODBC associate cardinality failed.'
    Assert-True ($preflight.parameterCardinalities.odbcDisassociate -eq 50) 'ODBC disassociate cardinality failed.'
    Assert-True (-not $preflight.credentialAccessed -and -not $preflight.networkAccessPerformed -and -not $preflight.writesPerformed) 'Preflight mutation/access boundary failed.'

    $complete=New-Rows
    $direct=New-Object Collections.Generic.List[object]
    for ($i=0; $i -lt $keys.Count; $i++) {
        $key=[string]$keys[$i]
        if ($key -ceq '62617-215D') { continue }
        $unit=$key+'-010'; $scribe=('R{0:D10}X' -f $i)
        if ($key -ceq '62613-842A') { $unit='62613-842-030'; $scribe='67055042SUC1' }
        $direct.Add([pscustomobject]@{ ParentContainer=$key; UnitContainer=$unit; Scribe=$scribe })
    }
    $complete.directRows=$direct.ToArray()
    $complete.disassociateHistoryRows=@([pscustomobject]@{
        ParentContainer='62617-215D'; UnitContainer='62617-215-040Wafer'; Scribe='58128019SUD2'
        MembershipTxnDate='2026-08-07T22:40:43.203'; MembershipTxnServiceName='Disassociate'; MembershipTxnType='Disassociate'; MembershipEventId='1'
    })
    $completeResult=Invoke-Rehearsal $tempRoot 'complete' $complete
    Assert-True ($completeResult.disposition -ceq 'COMPLETE' -and $completeResult.state -ceq 'PASS_R18UQ2_EXHAUSTIVE_ROSTER') '50-lot COMPLETE result failed.'
    Assert-True ($completeResult.counts.representedLots -eq 50 -and $completeResult.counts.unresolvedLots -eq 0 -and $completeResult.counts.heldMembers -eq 0) 'COMPLETE counts failed.'
    $suffixLot=@($completeResult.lots | Where-Object { $_.queryLot -ceq '62613-842A' })[0]
    Assert-True ($suffixLot.resolvedMembers[0].unitContainer -ceq '62613-842-030') 'Exact suffixed parent did not accept suffixless issued unit.'
    Assert-True ($suffixLot.resolvedMembers[0].resolvedScribe -ceq '67055042SUC1') 'Suffixed-parent scribe failed.'
    $dLot=@($completeResult.lots | Where-Object { $_.queryLot -ceq '62617-215D' })[0]
    Assert-True ($dLot.resolvedMembers[0].unitContainer -ceq '62617-215-040WAFER') 'Exact disassociation child was not preserved.'
    Assert-True ($dLot.resolvedMembers[0].resolvedScribe -ceq '58128019SUD2') 'Disassociation fallback scribe failed.'
    Assert-True ($dLot.resolvedMembers[0].resolutionBasis -ceq 'FALLBACK_EXACT_HISTORICAL_PARENT_CHILD') 'Disassociation fallback basis failed.'
    Assert-True (@($dLot.resolvedMembers[0].acquisitionTimestamps) -contains '2026-08-07T22:40:43.203') 'Disassociation timestamp missing.'

    $withHold=New-Rows
    $withHold.directRows=@($complete.directRows | Where-Object { $_.ParentContainer -cne '62631-586' }) + @(
        [pscustomobject]@{ ParentContainer='62631-586'; UnitContainer='62631-586-010'; Scribe='0737S069FEB3' },
        [pscustomobject]@{ ParentContainer='62631-586'; UnitContainer='62631-586-070'; Scribe='0737S071FEB3' }
    )
    $withHold.disassociateHistoryRows=$complete.disassociateHistoryRows
    $withHold.issueHistoryRows=@([pscustomobject]@{
        ParentContainer='62631-586'; IssuedWaferContainer='62631-586-070'; Scribe='1487D014SUF5'; SourceEpiContainer='995001-180Z-0'
        IssueTxnDate='2026-07-29T15:04:52.807'; IssueTxnServiceName='ComponentIssue'; IssueTxnType='6440'
    })
    $holdResult=Invoke-Rehearsal $tempRoot 'usable_hold' $withHold
    Assert-True ($holdResult.disposition -ceq 'USABLE_WITH_HOLDS' -and $holdResult.state -ceq 'PASS_R18UQ2_USABLE_ROSTER_WITH_EXPLICIT_HELD_MEMBERS') '50-lot usable-with-holds state failed.'
    Assert-True ($holdResult.counts.representedLots -eq 50 -and $holdResult.counts.heldMembers -eq 1 -and $holdResult.counts.invalidOrNullRows -eq 0) 'Usable-with-holds counts failed.'
    $partial=@($holdResult.lots | Where-Object { $_.queryLot -ceq '62631-586' })[0]
    Assert-True ($partial.state -ceq 'PARTIAL_HOLD' -and $partial.resolvedMemberCount -ge 1 -and $partial.heldMemberCount -eq 1) 'Partial-hold lot failed.'
    $held=$partial.heldMembers[0]
    Assert-True ($null -eq $held.resolvedScribe) 'Held member exposed a resolved scribe.'
    Assert-True (@($held.holdCodes) -contains 'CURRENT_HISTORY_SCRIBE_DISAGREEMENT') 'Current/history disagreement hold code missing.'
    Assert-True (@($held.sourceSeparatedCandidates.currentContainerSubstrate) -contains '0737S071FEB3') 'Current candidate separation failed.'
    Assert-True (@($held.sourceSeparatedCandidates.issueActualsHistory) -contains '1487D014SUF5') 'History candidate separation failed.'

    $noParent=New-Rows
    $noParent.directRows=$complete.directRows
    $noParent.disassociateHistoryRows=$complete.disassociateHistoryRows
    $noParent.issueHistoryRows=@([pscustomobject]@{ ParentContainer=$null; IssuedWaferContainer='62613-842-040'; Scribe='11111111SUA1'; SourceEpiContainer='SOURCE-1' })
    $noParentResult=Invoke-Rehearsal $tempRoot 'no_parent' $noParent
    $noParentLot=@($noParentResult.lots | Where-Object { $_.queryLot -ceq '62613-842A' })[0]
    Assert-True (@($noParentLot.resolvedMembers | Where-Object { $_.unitContainer -ceq '62613-842-040' }).Count -eq 0) 'Unit-name inference mapped a no-parent row.'
    Assert-True (@($noParentResult.invalidOrNullRows | Where-Object { $_.code -ceq 'NO_EXACT_DB_PARENT_MEMBERSHIP_EVIDENCE' }).Count -eq 1) ("No-parent diagnostic missing: "+(($noParentResult.invalidOrNullRows | ConvertTo-Json -Compress)))
    Assert-True ($noParentResult.disposition -ceq 'HOLD') 'No-parent invalid row did not hold global result.'

    $contradiction=New-Rows
    $contradiction.directRows=@($complete.directRows | Where-Object { $_.ParentContainer -cne '62613-842A' }) + @([pscustomobject]@{ ParentContainer='62613-842A'; UnitContainer='62607-215-099'; Scribe='67055042SUC1' })
    $contradiction.disassociateHistoryRows=$complete.disassociateHistoryRows
    $contradictionResult=Invoke-Rehearsal $tempRoot 'contradiction' $contradiction
    $contradictionLot=@($contradictionResult.lots | Where-Object { $_.queryLot -ceq '62613-842A' })[0]
    Assert-True ($contradictionLot.heldMemberCount -eq 1 -and $contradictionLot.resolvedMemberCount -eq 0) 'Exact parent/unit catalog contradiction was not held.'
    Assert-True (@($contradictionLot.heldMembers[0].holdCodes) -contains 'PARENT_UNIT_EXACT_CATALOG_CONTRADICTION') 'Exact parent/unit contradiction code missing.'

    $outPath=Join-Path $tempRoot 'create_new.json'
    $completePath=Join-Path $tempRoot 'complete.json'
    $receipt=(& $QueryPath -InputPath $InputPath -RehearsalInputPath $completePath -OutputPath $outPath) | ConvertFrom-Json
    Assert-True ($receipt.state -ceq 'PASS_R18UQ2_RESULT_WRITTEN_CREATE_NEW' -and -not $receipt.overwritePermitted -and -not $receipt.credentialsReturned) 'Create-new receipt failed.'
    $before=(Get-FileHash -Algorithm SHA256 -LiteralPath $outPath).Hash
    $overwriteFailed=$false
    try { [void](& $QueryPath -InputPath $InputPath -RehearsalInputPath $completePath -OutputPath $outPath) }
    catch { $overwriteFailed=$true }
    Assert-True $overwriteFailed 'Overwrite attempt was not refused.'
    Assert-True ((Get-FileHash -Algorithm SHA256 -LiteralPath $outPath).Hash -ceq $before) 'Overwrite refusal changed existing output.'
    $secret='R18UQ2_DO_NOT_RETURN_SECRET'; $secure=ConvertTo-SecureString $secret -AsPlainText -Force
    $credential=[Management.Automation.PSCredential]::new('sentinel-user',$secure); $errorText=''
    try { [void](& $QueryPath -InputPath $InputPath -RehearsalInputPath $completePath -OdbcDsn 'sentinel-dsn' -Credential $credential) }
    catch { $errorText=$_.Exception.Message }
    Assert-True (-not $errorText.Contains($secret)) 'Credential material leaked in rejection text.'
    $outputText=Get-Content -LiteralPath $outPath -Raw
    Assert-True (-not $outputText.Contains($secret) -and -not $outputText.Contains('sentinel-user')) 'Credential material leaked to result.'
    Assert-True ((($outputText | ConvertFrom-Json).provenance.credentialSource) -ceq 'NONE_FILE_BACKED_SYNTHETIC_ROWS') 'Synthetic credential provenance failed.'

    [pscustomobject][ordered]@{
        schema='argos_r18uq2_focused_test_v1'; state='PASS_R18UQ2_FOCUSED_LOCAL_REHEARSAL'
        assertions=30; queryLots=50; completeDisposition=$completeResult.disposition
        usableWithHoldsDisposition=$holdResult.disposition; heldMembers=$holdResult.counts.heldMembers
        databaseAccessed=$false; networkAccessed=$false; credentialsReturned=$false; jbodAccessed=$false; imagesAccessed=$false
    } | ConvertTo-Json -Depth 4 -Compress
}
finally {
    $full=[IO.Path]::GetFullPath($tempRoot); $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if ($full.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($full).StartsWith('ArgosR18UQ2_')) { Remove-Item -LiteralPath $full -Recurse -Force }
}
