#Requires -Version 5.1
$ErrorActionPreference='Stop';Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSCommandPath
& (Join-Path $root 'Invoke-O3B9ApprovedStage.ps1') -InvocationManifest (Join-Path $root 'O3B9_LIVE_INVOCATION.json') -Stage
