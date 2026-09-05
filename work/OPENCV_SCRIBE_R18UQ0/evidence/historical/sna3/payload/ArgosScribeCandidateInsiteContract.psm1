Set-StrictMode -Version Latest

$resolverModule = Join-Path $PSScriptRoot 'ArgosScribeCandidateMesResolver.psm1'
if (-not (Test-Path -LiteralPath $resolverModule -PathType Leaf)) {
    throw "Candidate resolver module missing: $resolverModule"
}
Import-Module -Name $resolverModule -ErrorAction Stop

function Assert-ArgosReviewOnlyInsiteSafety {
    param([Parameter(Mandatory = $true)]$Document)

    if ([bool]$Document.imagesIncluded -or [bool]$Document.credentialsIncluded -or
        -not [bool]$Document.reviewOnly -or [bool]$Document.trainingEligible -or
        [bool]$Document.xmlEligible -or [bool]$Document.productionEligible) {
        throw 'Pending Insite request safety contract refused.'
    }
}

function New-ArgosCurrentImageScribeCandidateInsiteRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][object[]]$ReaderRows
    )

    $seenKeys = @{}
    $requestRows = foreach ($row in $ReaderRows) {
        $acquisitionKey = ([string]$row.acquisitionKey).Trim().ToUpperInvariant()
        if ($acquisitionKey -cnotmatch '^.+_\d{14}_SLOT\d+$') {
            throw "Current-image candidate acquisition key is invalid: $acquisitionKey"
        }
        if ($seenKeys.ContainsKey($acquisitionKey)) {
            throw "Duplicate current-image candidate acquisition key: $acquisitionKey"
        }
        $seenKeys[$acquisitionKey] = $true

        $reader = $row.readerSummary
        if ($null -eq $reader -or
            [string]$reader.schema -ne 'argos_scribe_multi_channel_polarity_reader_v1' -or
            -not [bool]$reader.currentPixelsOnly -or
            [bool]$reader.priorWaferIdentityAssignmentUsed -or
            -not [bool]$reader.exactMesVerificationRequired) {
            throw "Current-image reader safety contract refused: $acquisitionKey"
        }
        $candidates = @($reader.candidates | ForEach-Object {
            ([string]$_.string).Trim().ToUpperInvariant()
        } | Where-Object { $_ } | Sort-Object -Unique)
        if ($candidates.Count -eq 0) {
            throw "Current-image reader produced no MES-query candidate: $acquisitionKey"
        }
        foreach ($candidate in $candidates) {
            if (-not (Test-ArgosCanonicalSemiM12 $candidate)) {
                throw "Current-image reader candidate is not canonical SEMI M12: $candidate"
            }
        }
        [ordered]@{
            acquisitionKey = $acquisitionKey
            candidateScribes = $candidates
            candidateCount = $candidates.Count
            readerSchema = [string]$reader.schema
            currentPixelsOnly = $true
            exactMesVerificationRequired = $true
            priorWaferIdentityAssignmentUsed = $false
            hardcodedIdentityUsed = $false
        }
    }
    $uniqueCandidates = @($requestRows.candidateScribes | Sort-Object -Unique)
    [pscustomobject][ordered]@{
        schema = 'argos_jbod_current_image_scribe_candidate_insite_request_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PENDING_CURRENT_IMAGE_CANONICAL_M12_CANDIDATE_READ_ONLY_INSITE_LOOKUP'
        lookupKey = 'current-image-supported canonical M12 candidate scribe'
        pendingScribes = $uniqueCandidates.Count
        pendingAcquisitions = @($requestRows).Count
        rows = @($requestRows)
        imagesIncluded = $false
        credentialsIncluded = $false
        currentPixelsOnly = $true
        exactMesVerificationRequired = $true
        priorWaferIdentityAssignmentUsed = $false
        hardcodedIdentityUsed = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
    }
}

function Get-ArgosPendingInsiteRequestContract {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Request)

    Assert-ArgosReviewOnlyInsiteSafety -Document $Request
    $schema = [string]$Request.schema
    $state = [string]$Request.state
    $lookupKey = [string]$Request.lookupKey
    $requestKind = ''
    $pairs = New-Object Collections.Generic.List[object]

    if ($schema -eq 'argos_jbod_pending_insite_request_v1' -and
        $state -eq 'PENDING_CONFIRMED_SCRIBE_READ_ONLY_INSITE_LOOKUP' -and
        $lookupKey -eq 'confirmed 12-character wafer scribe') {
        $requestKind = 'CONFIRMED_SCRIBE'
        foreach ($row in @($Request.rows)) {
            $scribe = ([string]$row.scribe).Trim().ToUpperInvariant()
            if ($scribe -cnotmatch '^[A-Z0-9]{12}$') { throw "Invalid confirmed scribe: $scribe" }
            foreach ($keyValue in @($row.acquisitionKeys)) {
                $key = ([string]$keyValue).Trim().ToUpperInvariant()
                if ($key) { $pairs.Add([pscustomobject]@{ scribe = $scribe; acquisitionKey = $key }) }
            }
        }
    } elseif ($schema -eq 'argos_jbod_current_image_scribe_candidate_insite_request_v1' -and
        $state -eq 'PENDING_CURRENT_IMAGE_CANONICAL_M12_CANDIDATE_READ_ONLY_INSITE_LOOKUP' -and
        $lookupKey -eq 'current-image-supported canonical M12 candidate scribe') {
        $requestKind = 'CURRENT_IMAGE_CANDIDATE'
        if (-not [bool]$Request.currentPixelsOnly -or
            -not [bool]$Request.exactMesVerificationRequired -or
            [bool]$Request.priorWaferIdentityAssignmentUsed -or
            [bool]$Request.hardcodedIdentityUsed) {
            throw 'Current-image candidate request identity contract refused.'
        }
        $seenKeys = @{}
        foreach ($row in @($Request.rows)) {
            $key = ([string]$row.acquisitionKey).Trim().ToUpperInvariant()
            if ($key -cnotmatch '^.+_\d{14}_SLOT\d+$' -or $seenKeys.ContainsKey($key)) {
                throw "Invalid or duplicate current-image acquisition key: $key"
            }
            $seenKeys[$key] = $true
            $candidates = @($row.candidateScribes | ForEach-Object {
                ([string]$_).Trim().ToUpperInvariant()
            } | Where-Object { $_ } | Sort-Object -Unique)
            if ($candidates.Count -eq 0 -or $candidates.Count -ne [int]$row.candidateCount) {
                throw "Current-image candidate count mismatch: $key"
            }
            foreach ($candidate in $candidates) {
                if (-not (Test-ArgosCanonicalSemiM12 $candidate)) {
                    throw "Invalid current-image canonical M12 candidate: $candidate"
                }
                $pairs.Add([pscustomobject]@{ scribe = $candidate; acquisitionKey = $key })
            }
        }
    } else {
        throw 'Pending Insite request contract refused.'
    }

    $pairArray = @($pairs.ToArray())
    $scribes = @($pairArray.scribe | Sort-Object -Unique)
    $acquisitions = @($pairArray.acquisitionKey | Sort-Object -Unique)
    if ($scribes.Count -eq 0) { throw 'Pending Insite request contains no scribes.' }
    if ($scribes.Count -ne [int]$Request.pendingScribes) {
        throw 'Pending scribe count does not match the request manifest.'
    }
    if ($Request.PSObject.Properties.Name -contains 'pendingAcquisitions' -and
        $acquisitions.Count -ne [int]$Request.pendingAcquisitions) {
        throw 'Pending acquisition count does not match the request manifest.'
    }

    $requestByScribe = @{}
    foreach ($pair in $pairArray) {
        if (-not $requestByScribe.ContainsKey($pair.scribe)) {
            $requestByScribe[$pair.scribe] = New-Object Collections.Generic.List[string]
        }
        $requestByScribe[$pair.scribe].Add($pair.acquisitionKey)
    }
    foreach ($scribe in @($requestByScribe.Keys)) {
        $requestByScribe[$scribe] = [string[]]@($requestByScribe[$scribe].ToArray() | Sort-Object -Unique)
    }

    [pscustomobject][ordered]@{
        requestKind = $requestKind
        lookupKey = $lookupKey
        scribes = [string[]]$scribes
        acquisitionKeys = [string[]]$acquisitions
        requestByScribe = $requestByScribe
        currentPixelsOnly = $requestKind -eq 'CURRENT_IMAGE_CANDIDATE'
        priorWaferIdentityAssignmentUsed = $false
        hardcodedIdentityUsed = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
    }
}

function Get-ArgosPendingInsiteCanonicalDocument {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Request)

    $contract = Get-ArgosPendingInsiteRequestContract -Request $Request
    $rows = if ($contract.requestKind -eq 'CURRENT_IMAGE_CANDIDATE') {
        @($Request.rows | Sort-Object acquisitionKey | ForEach-Object {
            $relativePath = ([string]$_.readerSummaryRelativePath).Trim()
            $hash = ([string]$_.readerSummarySha256).Trim().ToUpperInvariant()
            $components = @($relativePath -split '[\\/]')
            if ([string]::IsNullOrWhiteSpace($relativePath) -or
                [IO.Path]::IsPathRooted($relativePath) -or
                $components -contains '..' -or $components -contains '.' -or
                $relativePath.IndexOfAny([char[]]'*?') -ge 0 -or
                $hash -cnotmatch '^[A-F0-9]{64}$') {
                throw "Candidate reader-summary provenance contract refused: $($_.acquisitionKey)"
            }
            [pscustomobject][ordered]@{
                acquisitionKey = ([string]$_.acquisitionKey).Trim().ToUpperInvariant()
                candidateScribes = @($_.candidateScribes | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Sort-Object -Unique)
                readerSummaryRelativePath = $relativePath.Replace('/', '\')
                readerSummarySha256 = $hash
            }
        })
    } else {
        @($Request.rows | Sort-Object scribe | ForEach-Object {
            [pscustomobject][ordered]@{
                scribe = ([string]$_.scribe).Trim().ToUpperInvariant()
                acquisitionKeys = @($_.acquisitionKeys | ForEach-Object { ([string]$_).Trim().ToUpperInvariant() } | Sort-Object -Unique)
            }
        })
    }
    [pscustomobject][ordered]@{
        schema = [string]$Request.schema
        state = [string]$Request.state
        lookupKey = [string]$Request.lookupKey
        rows = $rows
    }
}

Export-ModuleMember -Function New-ArgosCurrentImageScribeCandidateInsiteRequest, Get-ArgosPendingInsiteRequestContract, Get-ArgosPendingInsiteCanonicalDocument
