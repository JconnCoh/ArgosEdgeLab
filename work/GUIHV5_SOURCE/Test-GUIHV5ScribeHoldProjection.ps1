[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$DashboardPath,
    [Parameter(Mandatory=$true)][string]$QueuePath,
    [Parameter(Mandatory=$true)][string]$SourceRoot,
    [Parameter(Mandatory=$true)][string]$OutputRoot
)
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
if(Test-Path -LiteralPath $OutputRoot){throw "Output root already exists: $OutputRoot"}
$dashboard=Get-Content -LiteralPath $DashboardPath -Raw|ConvertFrom-Json
$queue=Get-Content -LiteralPath $QueuePath -Raw|ConvertFrom-Json
$queueByPhysical=@{}
foreach($row in @($queue.rows)){
    $key=[string]$row.physicalIdentity
    if([string]::IsNullOrWhiteSpace($key)-or$queueByPhysical.ContainsKey($key)){throw "Queue identity missing or duplicate: $key"}
    $queueByPhysical[$key]=$row
}
$scribeReason='HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'
$held=@($dashboard.heldAcquisitions);$scribe=@($held|Where-Object{$_.holdReason-eq$scribeReason})
$unrelatedBefore=@($held|Where-Object{$_.holdReason-ne$scribeReason}|ConvertTo-Json -Depth 14 -Compress)
$joins=0
foreach($row in $scribe){
    $physical=[string]$row.physicalIdentity
    if(-not$queueByPhysical.ContainsKey($physical)){throw "Missing exact queue join: $physical"}
    $queueRow=$queueByPhysical[$physical];$state=[string]$queueRow.state
    $actionability=switch($state){
        'PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED'{'OPERATOR_REVIEW_READY'}
        'PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL'{'AUTOMATIC_PROPOSAL_PENDING'}
        'SCRIBE_IDENTITY_CONFIRMATION_HOLD'{'INPUT_HOLD_NOT_REVIEWABLE'}
        'HOLD_HUMAN_VISIBLE_NONCANONICAL_CHECKSUM'{'SEPARATE_AUTHORITY_REQUIRED'}
        default{'SCRIBE_STATE_NOT_REVIEWABLE'}
    }
    Add-Member -InputObject $row -NotePropertyName scribeQueueState -NotePropertyValue $state -Force
    Add-Member -InputObject $row -NotePropertyName scribeNextAction -NotePropertyValue ([string]$queueRow.nextAction) -Force
    Add-Member -InputObject $row -NotePropertyName scribeProposalSource -NotePropertyValue ([string]$queueRow.proposalSource) -Force
    Add-Member -InputObject $row -NotePropertyName scribeActionability -NotePropertyValue $actionability -Force
    $joins++
}
$unrelatedAfter=@($held|Where-Object{$_.holdReason-ne$scribeReason}|ConvertTo-Json -Depth 14 -Compress)
if($unrelatedBefore.Count-ne$unrelatedAfter.Count-or(Compare-Object $unrelatedBefore $unrelatedAfter)){throw 'Unrelated hold rows changed.'}
$physicalGroups=@($scribe|Group-Object physicalIdentity)
$stateCounts=@($physicalGroups|ForEach-Object{$_.Group[0]}|Group-Object scribeQueueState)
$expected=@{SCRIBE_IDENTITY_CONFIRMATION_HOLD=126;PENDING_AUTOMATIC_NOTCH_AND_SEMI_M12_PROPOSAL=55;PROPOSAL_READY_OPERATOR_CONFIRMATION_REQUIRED=5;HOLD_HUMAN_VISIBLE_NONCANONICAL_CHECKSUM=4}
foreach($name in $expected.Keys){if([int](@($stateCounts|Where-Object{$_.Name-eq$name})[0].Count)-ne$expected[$name]){throw "State split changed: $name"}}
if($held.Count-ne1722-or$scribe.Count-ne380-or$physicalGroups.Count-ne190-or$joins-ne380){throw 'Exact signed hold cardinality changed.'}
if(@($physicalGroups|Where-Object{$_.Count-ne2}).Count-ne0){throw 'Scribe domain duplication changed.'}
if(@($physicalGroups|Where-Object{(@($_.Group.domain|Sort-Object -Unique)-join',')-ne'BACKSIDE_PENDING_REGIME,FRONTSIDE'}).Count-ne0){throw 'Scribe domain set changed.'}
if(@($held|Where-Object{$_.holdReason-ne$scribeReason}).Count-ne1342){throw 'Unrelated hold cardinality changed.'}
$producer=Get-Content -LiteralPath (Join-Path $SourceRoot 'Update-JbodDashboardManifest.ps1') -Raw
$viewer=Get-Content -LiteralPath (Join-Path $SourceRoot 'Program.cs') -Raw
foreach($token in @('scribeQueueState','scribeNextAction','scribeProposalSource','scribeActionability','Scribe hold has no exact queue row')){if($producer-notmatch[regex]::Escape($token)){throw "Producer token missing: $token"}}
foreach($token in @('ProjectHeldRows','Affected domains','OPERATOR_REVIEW_READY','--hold-projection-check')){if($viewer-notmatch[regex]::Escape($token)){throw "Viewer token missing: $token"}}
[void](New-Item -ItemType Directory -Path $OutputRoot)
$encoding=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $OutputRoot 'dashboard_manifest.json'),(($dashboard|ConvertTo-Json -Depth 30)+[Environment]::NewLine),$encoding)
[ordered]@{state='PASS_GUIHV5_EXACT_SIGNED_SCRIBE_HOLD_REGRESSION';acquisitionHoldRows=380;physicalScribeRows=190;displayHoldRows=1532;unrelatedHoldRows=1342;missingQueueJoins=0;queueStateCounts=@($stateCounts|Sort-Object Name|ForEach-Object{[ordered]@{state=$_.Name;count=$_.Count}});operatorReviewReady=5;dashboardSha256=(Get-FileHash $DashboardPath -Algorithm SHA256).Hash;queueSha256=(Get-FileHash $QueuePath -Algorithm SHA256).Hash;mutationsPerformed=$false}|ConvertTo-Json -Depth 8
