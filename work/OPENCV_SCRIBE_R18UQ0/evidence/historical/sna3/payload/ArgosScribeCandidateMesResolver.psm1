Set-StrictMode -Version Latest

function Get-SemiM12Value([char]$Character) {
    $value = [int]$Character - 32
    if ($value -lt 0 -or $value -gt 58) { return -1 }
    return $value
}

function Test-ArgosCanonicalSemiM12([string]$Text) {
    if ($Text -cnotmatch '^[0-9A-Z]{12}$') { return $false }
    $remainder = 0
    foreach ($character in $Text.ToCharArray()) {
        $value = Get-SemiM12Value $character
        if ($value -lt 0) { return $false }
        $remainder = (8 * $remainder + $value) % 59
    }
    $bodyRemainder = 0
    foreach ($character in ($Text.Substring(0, 10) + 'A0').ToCharArray()) {
        $bodyRemainder = (8 * $bodyRemainder + (Get-SemiM12Value $character)) % 59
    }
    $correction = if ($bodyRemainder -eq 0) { 0 } else { 59 - $bodyRemainder }
    $expected = [string]([char]([int][char]'A' + (($correction -shr 3) -band 7))) +
        [string]([char]([int][char]'0' + ($correction -band 7)))
    return $remainder -eq 0 -and $Text.Substring(10, 2) -ceq $expected
}

function Resolve-ArgosScribeCandidateMesMatch {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$ReaderSummary,
        [Parameter(Mandatory = $true)]$MesSnapshot,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$AcquisitionKey
    )

    if ([string]$ReaderSummary.schema -ne 'argos_scribe_multi_channel_polarity_reader_v1' -or
        -not [bool]$ReaderSummary.currentPixelsOnly -or
        [bool]$ReaderSummary.priorWaferIdentityAssignmentUsed -or
        -not [bool]$ReaderSummary.exactMesVerificationRequired) {
        throw 'Current-image reader summary safety contract refused.'
    }
    if ([string]$MesSnapshot.authority -ne 'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT' -or
        [string]$MesSnapshot.lookupKey -ne 'current-image-supported canonical M12 candidate scribe') {
        throw 'Candidate MES snapshot authority contract refused.'
    }

    $candidates = @($ReaderSummary.candidates | ForEach-Object {
        ([string]$_.string).Trim().ToUpperInvariant()
    } | Sort-Object -Unique)
    foreach ($candidate in $candidates) {
        if (-not (Test-ArgosCanonicalSemiM12 $candidate)) {
            throw "Reader candidate is not canonical SEMI M12: $candidate"
        }
    }

    $qualified = @($MesSnapshot.records | Where-Object {
        $scribe = ([string]$_.scribe).Trim().ToUpperInvariant()
        if ($candidates -notcontains $scribe) { return $false }
        if ([string]$_.queryState -ne 'MES_READ_ONLY_SNAPSHOT' -or
            [string]$_.lineage.state -ne 'MES_SCRIBE_LINEAGE_EXACT') { return $false }
        $contexts = @($_.acquisitionContexts | Where-Object {
            ([string]$_.acquisitionKey).Trim().ToUpperInvariant() -ceq $AcquisitionKey.Trim().ToUpperInvariant() -and
            [string]$_.state -eq 'EXACT_PRIOR_MOVEIN_FOUND' -and
            [string]$_.authority -eq 'LAST_INSITE_MOVEIN_PRECEDING_ARGOS_SCAN'
        })
        return $contexts.Count -eq 1
    })

    $resolved = if ($qualified.Count -eq 1) { $qualified[0] } else { $null }
    $resolvedContext = if ($null -ne $resolved) {
        @($resolved.acquisitionContexts | Where-Object {
            ([string]$_.acquisitionKey).Trim().ToUpperInvariant() -ceq $AcquisitionKey.Trim().ToUpperInvariant()
        })[0]
    } else { $null }
    $routeState = if ($null -ne $resolvedContext -and
        $resolvedContext.PSObject.Properties.Name -contains 'frontsideScratchTestRoute') {
        [string]$resolvedContext.frontsideScratchTestRoute.state
    } else { 'HOLD_FRONTSIDE_SCRATCH_TEST_ROUTE_NOT_INCLUDED' }

    [pscustomobject][ordered]@{
        schema = 'argos_scribe_candidate_mes_resolution_v1'
        acquisitionKey = $AcquisitionKey.Trim().ToUpperInvariant()
        state = if ($qualified.Count -eq 1) {
            'SCRIBE_CURRENT_IMAGE_MES_EXACT_UNIQUE_REVIEW_ONLY'
        } elseif ($qualified.Count -eq 0) {
            'HOLD_SCRIBE_CURRENT_IMAGE_NO_EXACT_MES_MATCH'
        } else {
            'HOLD_SCRIBE_CURRENT_IMAGE_MULTIPLE_EXACT_MES_MATCHES'
        }
        candidateCount = $candidates.Count
        exactMesMatchCount = $qualified.Count
        resolvedScribe = if ($null -ne $resolved) { ([string]$resolved.scribe).Trim().ToUpperInvariant() } else { '' }
        frontsideScratchTestRouteState = $routeState
        detectorAdmissionState = if ($qualified.Count -eq 1 -and
            $routeState -eq 'FRONTSIDE_SCRATCH_TEST_NITRIDE_DIELECTRIC_ROUTE_CONFIRMED') {
            'READY_FRONTSIDE_SCRATCH_TEST_REVIEW_ONLY_PROCESSING'
        } elseif ($qualified.Count -eq 1) {
            'HOLD_FRONTSIDE_APPEARANCE_ROUTE_NOT_YET_QUALIFIED'
        } else {
            'HOLD_SCRIBE_IDENTITY_NOT_EXACTLY_RESOLVED'
        }
        currentPixelsOnly = $true
        exactMesLookupUsed = $true
        priorWaferIdentityAssignmentUsed = $false
        hardcodedIdentityUsed = $false
        reviewOnly = $true
        trainingEligible = $false
        xmlEligible = $false
        productionEligible = $false
    }
}

Export-ModuleMember -Function Resolve-ArgosScribeCandidateMesMatch, Test-ArgosCanonicalSemiM12
