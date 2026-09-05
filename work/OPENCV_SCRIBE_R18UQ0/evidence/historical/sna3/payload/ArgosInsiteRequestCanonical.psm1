Set-StrictMode -Version Latest

$contractModule = Join-Path $PSScriptRoot 'ArgosScribeCandidateInsiteContract.psm1'
if (-not (Test-Path -LiteralPath $contractModule -PathType Leaf)) {
    throw "Insite request contract module missing: $contractModule"
}
Import-Module -Name $contractModule -ErrorAction Stop

function Get-ArgosSha256Text {
    param([Parameter(Mandatory = $true)][string]$Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '')
    } finally { $sha.Dispose() }
}

function Get-ArgosInsiteRequestCanonicalDocumentV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Request)

    $base = Get-ArgosPendingInsiteCanonicalDocument -Request $Request
    $retryEpoch = ''
    if ($Request.PSObject.Properties.Name -contains 'retryEpochUtc') {
        $parsed = [DateTime]::MinValue
        if (-not [DateTime]::TryParse([string]$Request.retryEpochUtc, [ref]$parsed)) {
            throw 'Pending Insite retry epoch is invalid.'
        }
        $retryEpoch = $parsed.ToUniversalTime().ToString('o')
    }
    [pscustomobject][ordered]@{
        schema = [string]$base.schema
        state = [string]$base.state
        lookupKey = [string]$base.lookupKey
        retryEpochUtc = $retryEpoch
        rows = @($base.rows)
    }
}

function Get-ArgosInsiteRequestCanonicalHashV2 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Request)

    $canonical = Get-ArgosInsiteRequestCanonicalDocumentV2 -Request $Request
    return Get-ArgosSha256Text -Text ($canonical | ConvertTo-Json -Depth 10 -Compress)
}

Export-ModuleMember -Function Get-ArgosInsiteRequestCanonicalDocumentV2, Get-ArgosInsiteRequestCanonicalHashV2
