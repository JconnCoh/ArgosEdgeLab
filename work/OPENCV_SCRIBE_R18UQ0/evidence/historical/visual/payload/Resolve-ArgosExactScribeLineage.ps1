Set-StrictMode -Version Latest

function Resolve-ArgosExactScribeLineage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ValidatePattern('^[A-Z0-9]{12}$')][string]$Scribe,
        [object[]]$EpiMatches=@(),
        [object[]]$IssueLineageMatches=@(),
        [object[]]$DirectContainerMatches=@()
    )

    function Get-RowText([object]$Row,[string]$Name){
        if($null-eq$Row){return $null}
        $value=$null
        if($Row-is[Data.DataRow]-and$null-ne$Row.Table-and$Row.Table.Columns.Contains($Name)){$value=$Row[$Name]}
        elseif($Row.PSObject.Properties.Name-contains$Name){$value=$Row.$Name}
        if($null-eq$value-or$value-is[DBNull]-or[string]::IsNullOrWhiteSpace([string]$value)){return $null}
        ([string]$value).Trim()
    }

    $epi=@($EpiMatches|Where-Object{$null-ne$_})
    $issue=@($IssueLineageMatches|Where-Object{$null-ne$_})
    $direct=@($DirectContainerMatches|Where-Object{$null-ne$_})
    $issued=@($issue|ForEach-Object{Get-RowText $_ 'IssuedWaferContainer'}|Where-Object{$_}|Sort-Object -Unique)
    $issueStates=@($issue|ForEach-Object{Get-RowText $_ 'MesStateContainer'}|Where-Object{$_}|Sort-Object -Unique)
    $directUnits=@($direct|ForEach-Object{Get-RowText $_ 'UnitContainer'}|Where-Object{$_-match'^.+-\d{3}$'}|Sort-Object -Unique)
    $directParents=@($direct|ForEach-Object{Get-RowText $_ 'ParentContainer'}|Where-Object{$_}|Sort-Object -Unique)

    $issueUnit=if($issued.Count-eq1){$issued[0]}else{$null}
    $directUnit=if($directUnits.Count-eq1){$directUnits[0]}else{$null}
    $issueState=if($issueStates.Count-eq1){$issueStates[0]}else{$null}
    $directParent=if($directParents.Count-eq1){$directParents[0]}else{$null}
    $unitConflict=$issueUnit-and$directUnit-and$issueUnit-ne$directUnit
    $stateConflict=$issueState-and$directParent-and$issueState-ne$directParent

    $selectedUnit=if($issueUnit){$issueUnit}else{$directUnit}
    $historyBaseLot=if($selectedUnit-match'^(.+)-\d{3}$'){$Matches[1]}else{$null}
    $selectedState=if($issueState){$issueState}elseif($directParent){$directParent}else{$historyBaseLot}

    $ambiguous=$issued.Count-gt1-or$issueStates.Count-gt1-or$directUnits.Count-gt1-or$directParents.Count-gt1-or$unitConflict-or$stateConflict
    $hasLineage=$issueUnit-or$directUnit
    $state=if($epi.Count-eq0){
        'MES_LOOKUP_HOLD_NO_ROW'
    }elseif($ambiguous){
        'MES_LOOKUP_HOLD_AMBIGUOUS_LINEAGE'
    }elseif(-not$hasLineage){
        'MES_LOOKUP_HOLD_NO_ROW'
    }else{
        'MES_SCRIBE_LINEAGE_EXACT'
    }
    $authority=if($state-ne'MES_SCRIBE_LINEAGE_EXACT'){
        'NONE_FAIL_CLOSED'
    }elseif($issueUnit-and$directUnit){
        'ISSUE_HISTORY_AND_DIRECT_UNIT_CONTAINER_AGREE'
    }elseif($issueUnit){
        'ISSUE_HISTORY_EXACT'
    }else{
        'DIRECT_INSITE_CONTAINER_SUBSTRATE_EXACT'
    }

    [pscustomobject][ordered]@{
        scribe=$Scribe;lineageState=$state;lineageResolutionAuthority=$authority
        epi=if($epi.Count){$epi[0]}else{$null};epiMatchCount=$epi.Count
        issuedWaferContainer=$selectedUnit;mesStateContainer=$selectedState;historyBaseLot=$historyBaseLot
        directUnitContainer=$directUnit;directParentContainer=$directParent
        issueLineageMatchCount=$issue.Count;directContainerMatchCount=$direct.Count
        issuedContainerCount=$issued.Count;issueStateContainerCount=$issueStates.Count
        directUnitContainerCount=$directUnits.Count;directParentContainerCount=$directParents.Count
        issueDirectUnitConflict=[bool]$unitConflict;issueDirectStateConflict=[bool]$stateConflict
        lotSlotIdentityAuthorityUsed=$false
    }
}
