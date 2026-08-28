#Requires -Version 5.1
[CmdletBinding()]
param(
  [switch]$Preflight,
  [switch]$Rehearsal,
  [string]$InvocationManifest
)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$provider=Join-Path $PSScriptRoot 'Invoke-O3B8ShortStage.ps1'
if(-not(Test-Path -LiteralPath $provider -PathType Leaf)){throw 'O3B8 staged-copy provider is absent.'}
$manifest=if([string]::IsNullOrWhiteSpace($InvocationManifest)){Join-Path $PSScriptRoot 'O3B8_LIVE_INVOCATION.json'}else{[IO.Path]::GetFullPath($InvocationManifest)}
if(-not(Test-Path -LiteralPath $manifest -PathType Leaf)){throw 'O3B8 invocation manifest is absent.'}
if($Preflight){& $provider -InvocationManifest $manifest -Preflight -Rehearsal:$Rehearsal;return}
& $provider -InvocationManifest $manifest -Rehearsal:$Rehearsal
