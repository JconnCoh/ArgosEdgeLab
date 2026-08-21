[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InvocationManifest,
    [switch]$Preflight
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $InvocationManifest -PathType Leaf)) {
    throw "Invocation manifest does not exist: $InvocationManifest"
}
$manifestPath = [IO.Path]::GetFullPath(
    (Resolve-Path -LiteralPath $InvocationManifest).Path
)
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 'argos_wrapper_template_invocation_v1') {
    throw "Unexpected invocation schema: $($manifest.schema)"
}

if (-not $Preflight) {
    throw 'This template is non-operational. Copy it and implement an explicit target before use.'
}

[pscustomobject]@{
    State = 'PASS_ARGOS_WRAPPER_TEMPLATE_PREFLIGHT'
    InvocationManifest = $manifestPath
    MutationPerformed = $false
} | Format-List

