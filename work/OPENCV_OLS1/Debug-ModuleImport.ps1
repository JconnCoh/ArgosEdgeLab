[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [switch]$Once,
    [switch]$Preflight,
    [string]$EnvironmentProbeManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Import-Module Microsoft.PowerShell.Utility -ErrorAction Stop
[void](Get-Command -Name Get-FileHash -CommandType Function -ErrorAction Stop)
'PASS'
