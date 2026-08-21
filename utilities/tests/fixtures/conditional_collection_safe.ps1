[CmdletBinding()]
param([switch]$Preflight, [ValidateSet(0, 1, 3)][int]$Cardinality = 0)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rows = @(if ($Cardinality -gt 0) { 1..$Cardinality })
$result = [ordered]@{state='PASS_CONDITIONAL_COLLECTION_SAFE';cardinality=$Cardinality;observedCount=$rows.Count;values=$rows;mutationsPerformed=$false}
if ($Preflight) { $result | ConvertTo-Json -Depth 4; return }
throw 'The conditional-collection fixture is preflight-only.'
