[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [string]$ResponsePath=''
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest

function Write-AtomicJson {
    param([string]$Path,[object]$Value,[int]$Depth=14)
    $parent=Split-Path -Parent $Path
    if(-not(Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent -Force)}
    $temp=$Path+'.partial.'+[Guid]::NewGuid().ToString('N')
    $encoding=New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($temp,(($Value|ConvertTo-Json -Depth $Depth)+[Environment]::NewLine),$encoding)
    if([IO.File]::Exists($Path)){
        for($attempt=1;$attempt-le5;$attempt++){
            $backup=$Path+'.replace-backup.'+[Guid]::NewGuid().ToString('N')
            try{
                [IO.File]::Replace($temp,$Path,$backup,$true)
                [IO.File]::Delete($backup)
                break
            }catch [IO.IOException]{
                if($attempt-eq5){throw}
                Start-Sleep -Milliseconds 100
            }catch [UnauthorizedAccessException]{
                if($attempt-eq5){throw}
                Start-Sleep -Milliseconds 100
            }
        }
    }else{
        [IO.File]::Move($temp,$Path)
    }
}

$config=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
if([string]$config.schema-notin@('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3') -or
   [string]$config.metadataLookupAuthority-ne'CONFIRMED_SCRIBE_ONLY' -or
   -not[bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled){throw 'Scribe response import config safety contract refused.'}
if([string]::IsNullOrWhiteSpace($ResponsePath)){
    $downloads=Join-Path $env:USERPROFILE 'Downloads'
    $candidates=@(Get-ChildItem $downloads -File -Filter 'SCRIBE_VERIFICATION_RESPONSE*.json' -ErrorAction SilentlyContinue|Sort-Object CreationTimeUtc -Descending)
    if($candidates.Count-eq0){throw 'No SCRIBE_VERIFICATION_RESPONSE*.json was found in Downloads.'}
    Add-Type -AssemblyName System.Windows.Forms
    $dialog=New-Object Windows.Forms.OpenFileDialog
    $dialog.Title='Select the scribe response JSON you just saved'
    $dialog.InitialDirectory=$downloads
    $dialog.Filter='Scribe response JSON (SCRIBE_VERIFICATION_RESPONSE*.json)|SCRIBE_VERIFICATION_RESPONSE*.json|JSON files (*.json)|*.json'
    $dialog.FileName=$candidates[0].Name
    $dialog.CheckFileExists=$true
    $dialog.Multiselect=$false
    try{
        if($dialog.ShowDialog()-ne[Windows.Forms.DialogResult]::OK){throw 'Scribe response import cancelled; no identity state was changed.'}
        $ResponsePath=$dialog.FileName
    }finally{$dialog.Dispose()}
}
$responsePathResolved=(Resolve-Path -LiteralPath $ResponsePath).Path
$response=Get-Content -LiteralPath $responsePathResolved -Raw|ConvertFrom-Json
if([string]$response.schema-ne'argos_jbod_scribe_operator_response_v1'){throw 'Scribe response schema refused.'}
$stateRoot=[IO.Path]::GetFullPath([string]$config.stateRoot)
$queue=Get-Content -LiteralPath (Join-Path $stateRoot 'identity\SCRIBE_IDENTITY_QUEUE.json') -Raw|ConvertFrom-Json
$queueByPhysical=@{}
foreach($row in @($queue.rows)){$queueByPhysical[[string]$row.physicalIdentity]=$row}

$readerSource=Join-Path ([string]$config.appRoot) 'runtime\scribe\SemiM12DotMatrixImageReader.cs'
if($null-eq('ArgosScribeReview.SemiM12DotMatrixImageReader' -as [type])){
    Add-Type -Path $readerSource -ReferencedAssemblies 'System.Drawing'
}
$activePath=Join-Path $stateRoot 'identity\confirmed\ACTIVE_CONFIRMED_SCRIBE_OVERLAY.json'
$existing=@{}
if(Test-Path -LiteralPath $activePath -PathType Leaf){
    $prior=Get-Content -LiteralPath $activePath -Raw|ConvertFrom-Json
    if([string]$prior.schema-ne'argos_confirmed_scribe_overlay_v1' -or-not[bool]$prior.reviewOnly){throw 'Existing confirmed-scribe overlay refused.'}
    foreach($row in @($prior.rows)){$existing[[string]$row.acquisitionKey]=$row}
}
$noncanonicalPath=Join-Path $stateRoot 'identity\noncanonical\ACTIVE_HUMAN_VISIBLE_SCRIBE_HOLDS.json'
$noncanonical=@{}
if(Test-Path -LiteralPath $noncanonicalPath -PathType Leaf){
    $priorNoncanonical=Get-Content -LiteralPath $noncanonicalPath -Raw|ConvertFrom-Json
    if([string]$priorNoncanonical.schema-ne'argos_human_visible_noncanonical_scribe_hold_overlay_v1' -or-not[bool]$priorNoncanonical.reviewOnly){throw 'Existing noncanonical-scribe hold overlay refused.'}
    foreach($row in @($priorNoncanonical.rows)){$noncanonical[[string]$row.acquisitionKey]=$row}
}
$confirmedBefore=$existing.Count
$noncanonicalBefore=$noncanonical.Count
$auditRows=New-Object Collections.Generic.List[object]
foreach($answer in @($response.rows)){
    $physical=[string]$answer.physicalIdentity
    if(-not$queueByPhysical.ContainsKey($physical)){throw "Response identity is not in the active queue: $physical"}
    if([string]$answer.disposition-eq'NOT_REVIEWED'){throw "Response remains not reviewed: $physical"}
    if([string]$answer.disposition-eq'HOLD_UNREADABLE_OR_CONFLICT'){
        $auditRows.Add([pscustomobject]@{acquisitionKey=$physical;state='HOLD_UNREADABLE_OR_CONFLICT';note=[string]$answer.note})
        continue
    }
    if([string]$answer.disposition-notin@('CONFIRMED_VISIBLE_STRING','CONFIRMED_VISIBLE_NONCANONICAL_CHECKSUM_HOLD')){throw "Unknown disposition for $physical"}
    $scribe=([string]$answer.visibleScribe).Trim().ToUpperInvariant()
    if($scribe-notmatch'^[A-Z0-9]{12}$'){throw "Confirmed scribe must contain exactly 12 A-Z/0-9 characters: $physical"}
    $expected=[ArgosScribeReview.SemiM12DotMatrixImageReader]::GetM12CheckCharactersForValidation($scribe.Substring(0,10))
    $checksumValid=$expected-eq$scribe.Substring(10,2)-and[ArgosScribeReview.SemiM12DotMatrixImageReader]::GetM12RemainderForValidation($scribe)-eq0
    if(-not$checksumValid){
        if($existing.ContainsKey($physical)){throw "A canonical confirmed scribe already exists for the noncanonical response identity: $physical"}
        if($noncanonical.ContainsKey($physical)){
            if([string]$noncanonical[$physical].visibleScribe-ne$scribe){throw "A different human-visible noncanonical scribe hold already exists for $physical"}
            $auditRows.Add([pscustomobject]@{acquisitionKey=$physical;state='NONCANONICAL_CHECKSUM_HOLD_ALREADY_RECORDED';visibleScribe=$scribe;expectedCheckPair=$expected;observedCheckPair=$scribe.Substring(10,2);note=[string]$answer.note})
            continue
        }
        $noncanonical[$physical]=[pscustomobject][ordered]@{
            acquisitionKey=$physical;visibleScribe=$scribe;waferId=''
            identityState='HUMAN_VISIBLE_NONCANONICAL_CHECKSUM_HOLD';scribeChecksumState='SEMI_M12_CANONICAL_CHECKSUM_FAILED_HUMAN_VISIBLE_STRING'
            expectedCheckPair=$expected;observedCheckPair=$scribe.Substring(10,2)
            metadataState='NOT_QUERIED_NONCANONICAL_CHECKSUM_HOLD';routeState='HOLD_NONCANONICAL_SCRIBE_REQUIRES_SEPARATE_IDENTITY_AUTHORITY'
            operatorDisposition=[string]$answer.disposition;operatorId=[Security.Principal.WindowsIdentity]::GetCurrent().Name
            confirmedVisibleUtc=[DateTime]::UtcNow.ToString('o');sourceResponse=$responsePathResolved;note=[string]$answer.note
            reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false
        }
        $auditRows.Add([pscustomobject]@{acquisitionKey=$physical;state='HUMAN_VISIBLE_NONCANONICAL_CHECKSUM_HOLD_RECORDED';visibleScribe=$scribe;expectedCheckPair=$expected;observedCheckPair=$scribe.Substring(10,2);note=[string]$answer.note})
        continue
    }
    if($existing.ContainsKey($physical)){
        if([string]$existing[$physical].scribe-ne$scribe){throw "A different confirmed scribe already exists for $physical"}
        $auditRows.Add([pscustomobject]@{acquisitionKey=$physical;state='ALREADY_CONFIRMED_UNCHANGED';scribe=$scribe;note=[string]$answer.note})
        continue
    }
    $existing[$physical]=[pscustomobject][ordered]@{
        acquisitionKey=$physical;scribe=$scribe;waferId=$scribe
        identityState='HUMAN_CONFIRMED_REVIEW_ONLY';scribeChecksumState='SEMI_M12_CHECKSUM_VALID_CONFIRMED_VISIBLE_STRING'
        metadataState='SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING';operatorDisposition='CONFIRMED_VISIBLE_STRING'
        operatorId=[Security.Principal.WindowsIdentity]::GetCurrent().Name;confirmedUtc=[DateTime]::UtcNow.ToString('o')
        sourceResponse=$responsePathResolved;note=[string]$answer.note;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false
    }
    if($noncanonical.ContainsKey($physical)){[void]$noncanonical.Remove($physical)}
    $auditRows.Add([pscustomobject]@{acquisitionKey=$physical;state='CONFIRMED_VISIBLE_STRING';scribe=$scribe;note=[string]$answer.note})
}
$confirmedRoot=Split-Path -Parent $activePath
$versionPath=Join-Path $confirmedRoot ('CONFIRMED_SCRIBES_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'.json')
$overlay=[ordered]@{schema='argos_confirmed_scribe_overlay_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HUMAN_CONFIRMED_REVIEW_ONLY_INSITE_PENDING';lookupAuthority='CONFIRMED_12_CHARACTER_SCRIBE_ONLY';rows=@($existing.Values|Sort-Object acquisitionKey);reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
Write-AtomicJson $versionPath $overlay 14;Write-AtomicJson $activePath $overlay 14
$noncanonicalRoot=Split-Path -Parent $noncanonicalPath
$noncanonicalVersionPath=Join-Path $noncanonicalRoot ('HUMAN_VISIBLE_NONCANONICAL_SCRIBE_HOLDS_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'.json')
$noncanonicalOverlay=[ordered]@{schema='argos_human_visible_noncanonical_scribe_hold_overlay_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HUMAN_VISIBLE_STRINGS_HELD_NOT_IDENTITY_AUTHORITY';lookupAuthority='NOT_IDENTITY_AUTHORITY';rows=@($noncanonical.Values|Sort-Object acquisitionKey);reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false}
Write-AtomicJson $noncanonicalVersionPath $noncanonicalOverlay 14;Write-AtomicJson $noncanonicalPath $noncanonicalOverlay 14
$glyphReferenceUpdate='NOT_RUN'
$glyphReferenceDetail=''
$glyphReferenceScript=Join-Path ([string]$config.appRoot) 'Update-JbodHumanConfirmedScribeGlyphReferences.ps1'
if(Test-Path -LiteralPath $glyphReferenceScript -PathType Leaf){
    try{
        $glyphReferenceDetail=((& $glyphReferenceScript -ConfigPath $ConfigPath 6>&1|Out-String).Trim())
        $glyphReferenceUpdate='COMPLETED_REVIEW_ONLY'
    }catch{
        # The canonical identity import remains authoritative and atomic even
        # when an optional glyph crop cannot be safely harvested. Record the
        # hold explicitly; never roll back or silently reinterpret the human
        # confirmation as reader authority.
        $glyphReferenceUpdate='HOLD_GLYPH_REFERENCE_UPDATE_FAILED'
        $glyphReferenceDetail=$_.Exception.Message
        $auditRows.Add([pscustomobject]@{acquisitionKey='REFERENCE_LAYER';state=$glyphReferenceUpdate;note=$glyphReferenceDetail})
    }
}
$auditPath=Join-Path $confirmedRoot ('IMPORT_AUDIT_'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')+'.json')
Write-AtomicJson $auditPath ([ordered]@{schema='argos_scribe_response_import_audit_v1';createdUtc=[DateTime]::UtcNow.ToString('o');sourceResponse=$responsePathResolved;rows=$auditRows.ToArray();reviewOnly=$true}) 10
$queueScript=Join-Path ([string]$config.appRoot) 'Update-JbodScribeIdentityQueue.ps1'
$galleryScript=Join-Path ([string]$config.appRoot) 'Build-JbodScribeReviewGallery.ps1'
& $queueScript -ConfigPath $ConfigPath|Out-Null
& $galleryScript -ConfigPath $ConfigPath|Out-Null
[pscustomobject]@{
    State='SCRIBE_RESPONSE_IMPORTED_REVIEW_ONLY'
    SourceResponse=$responsePathResolved
    ResponseRows=@($response.rows).Count
    NewlyConfirmed=$existing.Count-$confirmedBefore
    AlreadyConfirmed=@($auditRows|Where-Object{$_.state-eq'ALREADY_CONFIRMED_UNCHANGED'}).Count
    NoncanonicalHoldsAdded=$noncanonical.Count-$noncanonicalBefore
    NoncanonicalHoldsTotal=$noncanonical.Count
    ConfirmedTotal=$existing.Count
    GlyphReferenceUpdate=$glyphReferenceUpdate
    GlyphReferenceDetail=$glyphReferenceDetail
    ActiveOverlay=$activePath
    NoncanonicalHoldOverlay=$noncanonicalPath
    Audit=$auditPath
    GalleryQueueRefreshed=$true
    Next='Canonical confirmed scribes remain pending for read-only Insite lookup. Human-visible noncanonical checksum strings remain held and are not identity authority.'
}|Format-List
