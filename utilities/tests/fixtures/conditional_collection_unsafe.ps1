[CmdletBinding()]
param([switch]$Preflight, [ValidateSet(0, 1, 3)][int]$Cardinality = 0)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rows = if ($Cardinality -gt 0) { @(1..$Cardinality) } else { @() }
$result = [ordered]@{state='UNSAFE_CONDITIONAL_COLLECTION';cardinality=$Cardinality;observedCount=$rows.Count;mutationsPerformed=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 4; return }
throw 'The unsafe conditional-collection fixture must never execute.'
