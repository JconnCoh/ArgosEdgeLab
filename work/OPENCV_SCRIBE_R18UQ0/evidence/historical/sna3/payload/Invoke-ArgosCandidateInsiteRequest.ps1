[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$RequestPath,
    [Management.Automation.PSCredential]$SqlCredential,
    [Parameter(Mandatory = $true)][string]$OutputPath,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedRequestContentSha256,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$requestFile = (Get-Item -LiteralPath $RequestPath -ErrorAction Stop).FullName
$outputFile = [IO.Path]::GetFullPath($OutputPath)
if (Test-Path -LiteralPath $outputFile) { throw "Refusing existing candidate query output: $outputFile" }
$contractModule = Join-Path $PSScriptRoot 'ArgosScribeCandidateInsiteContract.psm1'
$canonicalModule = Join-Path $PSScriptRoot 'ArgosInsiteRequestCanonical.psm1'
$envelopeModule = Join-Path $PSScriptRoot 'ArgosCandidateSnapshotEnvelope.psm1'
$queryScript = Join-Path $PSScriptRoot 'Invoke-ArgosMesVisualStateSnapshot.ps1'
foreach ($path in @($contractModule, $canonicalModule, $envelopeModule, $queryScript)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Candidate query dependency missing: $path" }
}
Import-Module -Name $contractModule -ErrorAction Stop
Import-Module -Name $canonicalModule -ErrorAction Stop
Import-Module -Name $envelopeModule -ErrorAction Stop
$request = Get-Content -LiteralPath $requestFile -Raw | ConvertFrom-Json
$contract = Get-ArgosPendingInsiteRequestContract -Request $request
if ([string]$contract.requestKind -ne 'CURRENT_IMAGE_CANDIDATE') {
    throw 'Candidate query refused a non-candidate request.'
}
$actualHash = Get-ArgosInsiteRequestCanonicalHashV2 -Request $request
if ($actualHash -cne $ExpectedRequestContentSha256.ToUpperInvariant()) {
    throw 'Candidate query request-content hash mismatch.'
}
if ($Preflight) {
    [pscustomobject]@{
        State = 'PASS_ARGOS_CANDIDATE_INSITE_QUERY_PREFLIGHT'
        CandidateScribes = @($contract.scribes).Count
        CandidateAcquisitions = @($contract.acquisitionKeys).Count
        OutputPath = $outputFile
        MutationPerformed = $false
    }
    return
}
if ($null -eq $SqlCredential) { throw 'SqlCredential is required outside preflight.' }

& $queryScript -Scribe ([string[]]$contract.scribes) -SqlCredential $SqlCredential -OutputPath $outputFile | Out-Null
$raw = Get-Content -LiteralPath $outputFile -Raw | ConvertFrom-Json
$envelope = New-ArgosCandidateMesSnapshotEnvelope -Request $request -RawSnapshot $raw -ExpectedRequestContentSha256 $actualHash
$temporary = $outputFile + '.envelope.' + [Guid]::NewGuid().ToString('N')
[IO.File]::WriteAllText($temporary, ($envelope | ConvertTo-Json -Depth 16) + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$backup = $outputFile + '.raw-backup.' + [Guid]::NewGuid().ToString('N')
try {
    [IO.File]::Replace($temporary, $outputFile, $backup, $true)
} catch {
    if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    throw
}
if (Test-Path -LiteralPath $backup) { Remove-Item -LiteralPath $backup -Force -ErrorAction SilentlyContinue }
[pscustomobject]@{
    State = 'PASS_CURRENT_IMAGE_CANDIDATE_INSITE_QUERY_REVIEW_ONLY'
    CandidateScribes = @($contract.scribes).Count
    CandidateAcquisitions = @($contract.acquisitionKeys).Count
    OutputPath = $outputFile
    SHA256 = (Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash
}
