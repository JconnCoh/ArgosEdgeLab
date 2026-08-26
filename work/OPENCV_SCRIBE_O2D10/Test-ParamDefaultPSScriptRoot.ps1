#Requires -Version 5.1
[CmdletBinding()]
param([string]$PayloadRoot = $PSScriptRoot)
[pscustomobject]@{
    payloadRoot = $PayloadRoot
    scriptRoot = $PSScriptRoot
    payloadRootEmpty = [string]::IsNullOrEmpty($PayloadRoot)
} | ConvertTo-Json -Compress
