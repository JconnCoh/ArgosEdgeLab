Set-StrictMode -Version Latest

$contractModule = Join-Path $PSScriptRoot 'ArgosScribeCandidateInsiteContract.psm1'
$canonicalModule = Join-Path $PSScriptRoot 'ArgosInsiteRequestCanonical.psm1'
foreach ($module in @($contractModule, $canonicalModule)) {
    if (-not (Test-Path -LiteralPath $module -PathType Leaf)) {
        throw "Candidate snapshot-envelope module missing: $module"
    }
}
Import-Module -Name $contractModule -ErrorAction Stop
Import-Module -Name $canonicalModule -ErrorAction Stop
foreach ($command in @('Get-ArgosPendingInsiteRequestContract', 'Get-ArgosInsiteRequestCanonicalHashV2', 'Get-ArgosInsiteRequestCanonicalDocumentV2')) {
    if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
        throw "Candidate snapshot-envelope command is unavailable: $command"
    }
}

function New-ArgosCandidateMesSnapshotEnvelope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Request,
        [Parameter(Mandatory = $true)]$RawSnapshot,
        [Parameter(Mandatory = $true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedRequestContentSha256
    )

    $contract = Get-ArgosPendingInsiteRequestContract -Request $Request
    if ([string]$contract.requestKind -ne 'CURRENT_IMAGE_CANDIDATE') {
        throw 'Candidate snapshot envelope refused a non-candidate request.'
    }
    $actualHash = Get-ArgosInsiteRequestCanonicalHashV2 -Request $Request
    if ($actualHash -cne $ExpectedRequestContentSha256.ToUpperInvariant()) {
        throw 'Candidate request canonical hash mismatch.'
    }
    $imagesIncluded = $RawSnapshot.PSObject.Properties.Name -contains 'imagesIncluded' -and
        [bool]$RawSnapshot.imagesIncluded
    $credentialsIncluded = $RawSnapshot.PSObject.Properties.Name -contains 'credentialsIncluded' -and
        [bool]$RawSnapshot.credentialsIncluded
    if ([string]$RawSnapshot.authority -ne
        'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT' -or
        $imagesIncluded -or $credentialsIncluded) {
        throw 'Raw MES snapshot safety contract refused.'
    }
    $requested = @($contract.scribes | Sort-Object -Unique)
    $returned = @($RawSnapshot.records | ForEach-Object {
        ([string]$_.scribe).Trim().ToUpperInvariant()
    } | Sort-Object -Unique)
    if ($returned.Count -ne $requested.Count -or
        @($requested | Where-Object { $returned -notcontains $_ }).Count -ne 0 -or
        @($returned | Where-Object { $requested -notcontains $_ }).Count -ne 0) {
        throw 'Raw MES snapshot does not contain the exact candidate-scribe set.'
    }

    $canonical = Get-ArgosInsiteRequestCanonicalDocumentV2 -Request $Request
    $copy = [ordered]@{}
    foreach ($property in $RawSnapshot.PSObject.Properties) {
        $copy[$property.Name] = $property.Value
    }
    $copy['lookupKey'] = 'current-image-supported canonical M12 candidate scribe'
    $copy['requestKind'] = 'CURRENT_IMAGE_CANDIDATE'
    $copy['requestSchema'] = [string]$Request.schema
    $copy['requestState'] = [string]$Request.state
    $copy['requestContentSha256'] = $actualHash
    $copy['requestRows'] = @($canonical.rows)
    $copy['currentPixelsOnly'] = $true
    $copy['exactMesVerificationRequired'] = $true
    $copy['selectionByScoreUsed'] = $false
    $copy['priorWaferIdentityAssignmentUsed'] = $false
    $copy['hardcodedIdentityUsed'] = $false
    $copy['imagesIncluded'] = $false
    $copy['credentialsIncluded'] = $false
    $copy['reviewOnly'] = $true
    $copy['trainingEligible'] = $false
    $copy['xmlEligible'] = $false
    $copy['productionEligible'] = $false
    return [pscustomobject]$copy
}

Export-ModuleMember -Function New-ArgosCandidateMesSnapshotEnvelope
