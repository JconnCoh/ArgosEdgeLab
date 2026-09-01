#Requires -Version 5.1
[CmdletBinding()]
param([switch]$Preflight)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$expectedComputer = 'A1025645101'
$root = 'D:\R21TG1'
$configPath = 'C:\ProgramData\ArgosProjectPortalRO\config\endpoint_jbod.json'
$workerPath = 'C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
$expectedConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$expectedWorkerSha = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'

function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }

$relativePaths = @()
foreach ($index in 0..33) {
    $i = '{0:D2}' -f $index
    $relativePaths += "J$i.json"
    foreach ($leaf in @('RESULT.json','BF_review.jpg','DF_review.jpg','BF_holder_exclusion.png','DF_holder_exclusion.png')) { $relativePaths += "O$i\$leaf" }
}
if ($relativePaths.Count -ne 204 -or @($relativePaths | Sort-Object -Unique).Count -ne 204) { throw 'Exact R21 inventory identity set changed.' }
if ($Preflight) {
    [ordered]@{schema='argos_r21p4_exact_inventory_preflight_v1';state='PASS_R21P4_EXACT_INVENTORY_PREFLIGHT';root=$root;exactLeafCount=204;rootEnumeration=$false;mutationsPerformed=$false} | ConvertTo-Json -Depth 5
    return
}
if ($env:COMPUTERNAME -ne $expectedComputer) { throw "Wrong computer: $($env:COMPUTERNAME)" }
if ((Get-Sha256 $configPath) -ne $expectedConfigSha) { throw 'Endpoint config premise changed.' }
if ((Get-Sha256 $workerPath) -ne $expectedWorkerSha) { throw 'Endpoint worker premise changed.' }
$rows = @()
foreach ($relative in $relativePaths) {
    $full = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $full.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'R21 inventory path escaped exact root.' }
    $exists = Test-Path -LiteralPath $full -PathType Leaf
    if ($exists) {
        $item = Get-Item -LiteralPath $full -ErrorAction Stop
        $rows += [ordered]@{relativePath=$relative.Replace('\','/');exists=$true;bytes=[int64]$item.Length;sha256=Get-Sha256 $full}
    } else {
        $rows += [ordered]@{relativePath=$relative.Replace('\','/');exists=$false;bytes=$null;sha256=$null}
    }
}
$present = @($rows | Where-Object { [bool]$_.exists })
$result = [ordered]@{schema='argos_r21p4_exact_inventory_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R21P4_EXACT_INVENTORY';root=$root;expectedLeafCount=204;presentLeafCount=$present.Count;absentLeafCount=(204-$present.Count);rows=$rows;rootEnumerated=$false;detectorRerun=$false;taskOrProcessActionPerformed=$false;sourceMutationPerformed=$false;r21OutputMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$result | ConvertTo-Json -Depth 8 -Compress
'PASS_R21P4_EXACT_INVENTORY'
