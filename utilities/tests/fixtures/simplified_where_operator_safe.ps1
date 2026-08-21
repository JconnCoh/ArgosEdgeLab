[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference = 'Stop'
if ($Preflight) {
    [pscustomobject]@{ State = 'PASS_SIMPLIFIED_WHERE_OPERATOR_SAFE'; MutationPerformed = $false }
    return
}

@([pscustomobject]@{ Count = 1 }) | Where-Object Count -ge 1
