Set-StrictMode -Version Latest

function Assert-R18TCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R18TSha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '')
    }
    finally {
        $hasher.Dispose()
        $stream.Dispose()
    }
}

function Get-R18TTextSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
        return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '')
    }
    finally {
        $hasher.Dispose()
    }
}

function Assert-R18TPathBudget {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateRange(0, 128)][int]$Reserve = 32
    )
    $full = [IO.Path]::GetFullPath($Path)
    $parts = @($full.Split([char[]]@('\', '/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($parts.Count -eq 0) {
        0
    }
    else {
        [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
    }
    Assert-R18TCondition (($full.Length + $Reserve) -lt 200) "Unsafe effective path: $full"
    Assert-R18TCondition ($longest -le 80) "Unsafe path component: $full"
}

function Get-R18TLiveBinding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$CohortPath,
        [Parameter(Mandatory = $true)][string]$ProposalRoot,
        [string]$BfRelativeLeaf = 'scribe\BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png',
        [string]$DfRelativeLeaf = 'scribe\DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png'
    )

    Assert-R18TCondition (Test-Path -LiteralPath $CohortPath -PathType Leaf) "Cohort is absent: $CohortPath"
    Assert-R18TCondition (Test-Path -LiteralPath $ProposalRoot -PathType Container) "Proposal root is absent: $ProposalRoot"
    Assert-R18TPathBudget $CohortPath
    Assert-R18TPathBudget $ProposalRoot

    $cohort = Get-Content -LiteralPath $CohortPath -Raw | ConvertFrom-Json
    $cases = @($cohort.reviewCases)
    Assert-R18TCondition ($cases.Count -gt 0) 'Cohort must contain at least one review case.'
    Assert-R18TCondition ([int]$cohort.caseCount -eq $cases.Count) 'Declared cohort count differs from the actual collection.'
    Assert-R18TCondition ([bool]$cohort.authority.reviewOnly) 'Cohort must remain review-only.'
    foreach ($field in @('identityAcceptanceAuthorized', 'automaticReferenceAdmissionAuthorized', 'trainingAuthorized', 'activationAuthorized', 'xmlAuthorized', 'productionAuthorized')) {
        $property = $cohort.authority.PSObject.Properties[$field]
        Assert-R18TCondition ($null -ne $property -and $property.Value -is [bool] -and -not [bool]$property.Value) "Cohort authority changed: $field"
    }

    $root = [IO.Path]::GetFullPath($ProposalRoot).TrimEnd('\')
    $rootPrefix = $root + '\'
    $identitySet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $pairSet = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $rows = New-Object Collections.Generic.List[object]

    foreach ($case in $cases) {
        $identity = [string]$case.physicalIdentity
        Assert-R18TCondition (-not [string]::IsNullOrWhiteSpace($identity)) 'A cohort identity is empty.'
        Assert-R18TCondition ($identity -cmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$') "Unsafe cohort identity: $identity"
        Assert-R18TCondition ($identity -ne '.' -and $identity -ne '..') "Unsafe cohort identity: $identity"
        Assert-R18TCondition ($identitySet.Add($identity)) "Duplicate case-insensitive cohort identity: $identity"

        $expectedBf = [string]$case.bfSha256
        $expectedDf = [string]$case.dfSha256
        Assert-R18TCondition ($expectedBf -cmatch '^[A-F0-9]{64}$' -and $expectedDf -cmatch '^[A-F0-9]{64}$') "Invalid source hash for cohort identity: $identity"
        Assert-R18TCondition ($pairSet.Add($expectedBf + '|' + $expectedDf)) "Duplicate configured BF/DF pair: $identity"

        $identityRoot = [IO.Path]::GetFullPath([IO.Path]::Combine($root, $identity))
        Assert-R18TCondition ($identityRoot.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) "Identity escaped the proposal root: $identity"
        $bfPath = [IO.Path]::GetFullPath([IO.Path]::Combine($identityRoot, $BfRelativeLeaf))
        $dfPath = [IO.Path]::GetFullPath([IO.Path]::Combine($identityRoot, $DfRelativeLeaf))
        foreach ($path in @($identityRoot, (Split-Path -Parent $bfPath), $bfPath, $dfPath)) {
            Assert-R18TPathBudget $path
            Assert-R18TCondition (Test-Path -LiteralPath $path) "Required live input is absent: $path"
            $item = Get-Item -LiteralPath $path -Force
            Assert-R18TCondition (-not (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq [IO.FileAttributes]::ReparsePoint)) "Reparse input is forbidden: $path"
        }
        Assert-R18TCondition (Test-Path -LiteralPath $bfPath -PathType Leaf) "BF leaf is not a file: $bfPath"
        Assert-R18TCondition (Test-Path -LiteralPath $dfPath -PathType Leaf) "DF leaf is not a file: $dfPath"

        $actualBf = Get-R18TSha256 $bfPath
        $actualDf = Get-R18TSha256 $dfPath
        Assert-R18TCondition ($actualBf -eq $expectedBf) "BF source hash mismatch: $identity"
        Assert-R18TCondition ($actualDf -eq $expectedDf) "DF source hash mismatch: $identity"
        $rows.Add([pscustomobject][ordered]@{
            physicalIdentity = $identity
            bfPath = $bfPath
            bfBytes = [int64](Get-Item -LiteralPath $bfPath).Length
            bfSha256 = $actualBf
            dfPath = $dfPath
            dfBytes = [int64](Get-Item -LiteralPath $dfPath).Length
            dfSha256 = $actualDf
        })
    }

    $canonicalLines = @($rows | ForEach-Object {
        ([string]$_.physicalIdentity).ToLowerInvariant() + '|' +
        ([string]$_.bfPath).ToLowerInvariant() + '|' + [string]$_.bfBytes + '|' + [string]$_.bfSha256 + '|' +
        ([string]$_.dfPath).ToLowerInvariant() + '|' + [string]$_.dfBytes + '|' + [string]$_.dfSha256
    })
    $canonical = [string]::Join("`n", $canonicalLines)
    return [pscustomobject][ordered]@{
        schema = 'argos_opencv_scribe_r18t_live_binding_v1'
        state = 'PASS_R18T_LIVE_INPUT_BINDING'
        cohortSha256 = Get-R18TSha256 $CohortPath
        caseCount = $rows.Count
        uniqueCasefoldIdentityCount = $identitySet.Count
        uniqueBfDfPairCount = $pairSet.Count
        bindingSha256 = Get-R18TTextSha256 $canonical
        rows = $rows.ToArray()
        sourceImageBytesHashed = $true
        pixelsDecoded = $false
        sourceMutationPerformed = $false
        identityAccepted = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
}

Export-ModuleMember -Function Get-R18TSha256, Get-R18TTextSha256, Assert-R18TPathBudget, Get-R18TLiveBinding
