[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Write-Utf8CreateNewJson {
    param([string]$Path, [object]$Value, [int]$Depth = 16)
    $json = $Value | ConvertTo-Json -Depth $Depth
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($json + [Environment]::NewLine)
    $stream = New-Object IO.FileStream($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try { $stream.Write($bytes,0,$bytes.Length) }
    finally { $stream.Dispose() }
}

if (([bool]$Preflight) -eq ([bool]$Publish)) { throw 'Specify exactly one of -Preflight or -Publish.' }
$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'JEO1 publish invocation left the project.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_jeo1_publish_invocation_v1' -and [string]$invocation.revision -eq 'JEO1') 'JEO1 publish invocation changed.'
Assert-True ([bool]$invocation.singlePublicationAuthorized -and -not [bool]$invocation.overwriteAuthorized) 'JEO1 publication authority changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'JEO1 publication safety flags changed.'

function Resolve-ProjectPath {
    param([string]$Relative)
    $path = [IO.Path]::GetFullPath((Join-Path $project $Relative))
    Assert-True ($path.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) "JEO1 project path escaped: $Relative"
    return $path
}

$sourceZip = Resolve-ProjectPath ([string]$invocation.sourceZip)
$sourcePathGate = Resolve-ProjectPath ([string]$invocation.sourcePathGate)
$prepublicationGate = Resolve-ProjectPath ([string]$invocation.prepublicationGate)
$publicationGate = Resolve-ProjectPath ([string]$invocation.publicationGate)
$destinationZip = [IO.Path]::GetFullPath([string]$invocation.destinationZip)
$destinationPathGate = [IO.Path]::GetFullPath([string]$invocation.destinationPathGate)
$returnZip = [IO.Path]::GetFullPath([string]$invocation.returnZip)
$expectedParent = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
Assert-True ((Split-Path -Parent $destinationZip).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'JEO1 destination ZIP parent changed.'
Assert-True ((Split-Path -Parent $destinationPathGate).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'JEO1 destination path-gate parent changed.'
Assert-True ((Split-Path -Parent $returnZip).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'JEO1 return ZIP parent changed.'
Assert-True ([IO.Path]::GetFileName($destinationZip) -eq 'ARGOS_JEO1.zip') 'JEO1 destination ZIP name changed.'
Assert-True ([IO.Path]::GetFileName($destinationPathGate) -eq 'ARGOS_JEO1_PATH_GATE.json') 'JEO1 destination path-gate name changed.'
Assert-True ([IO.Path]::GetFileName($returnZip) -eq 'JEO1R.zip') 'JEO1 return ZIP name changed.'
Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'JEO1 source ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes -and (Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'JEO1 source ZIP changed.'
Assert-True (Test-Path -LiteralPath $sourcePathGate -PathType Leaf) 'JEO1 source path gate is absent.'
Assert-True ((Get-Sha256 $sourcePathGate) -eq [string]$invocation.sourcePathGateSha256) 'JEO1 source path gate changed.'
Assert-True (Test-Path -LiteralPath $prepublicationGate -PathType Leaf) 'JEO1 prepublication gate is absent.'
Assert-True ((Get-Sha256 $prepublicationGate) -eq [string]$invocation.prepublicationGateSha256) 'JEO1 prepublication gate changed.'
$prepublication = Get-Content -LiteralPath $prepublicationGate -Raw | ConvertFrom-Json
Assert-True ([string]$prepublication.state -eq 'PASS_JEO1_PREPUBLICATION') 'JEO1 prepublication gate is not PASS.'
Assert-True (Test-Path -LiteralPath $expectedParent -PathType Container) 'JEO1 engineering share publication root is unavailable.'
foreach ($freshPath in @($destinationZip,$destinationPathGate,$returnZip,$publicationGate,$destinationZip+'.partial.JEO1',$destinationPathGate+'.partial.JEO1')) {
    Assert-True (-not (Test-Path -LiteralPath $freshPath)) "JEO1 publication path must be fresh: $freshPath"
}

$preflightResult = [ordered]@{
    schema='argos_jeo1_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_PUBLISH_PREFLIGHT'
    sourceZip=$sourceZip;sourceZipSha256=[string]$invocation.sourceZipSha256;sourcePathGate=$sourcePathGate;destinationZip=$destinationZip;destinationPathGate=$destinationPathGate;returnZip=$returnZip
    publicationGate=$publicationGate;targetExecuted=$false;mutationsPerformed=$false;jbodContacted=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 10; return }

$zipPartial = $destinationZip+'.partial.JEO1'
$gatePartial = $destinationPathGate+'.partial.JEO1'
$zipFinalCreated = $false
$gateFinalCreated = $false
try {
    [IO.File]::Copy($sourceZip,$zipPartial,$false)
    Assert-True ((Get-Sha256 $zipPartial) -eq [string]$invocation.sourceZipSha256) 'JEO1 staged ZIP hash changed.'
    [IO.File]::Move($zipPartial,$destinationZip)
    $zipFinalCreated = $true
    [IO.File]::Copy($sourcePathGate,$gatePartial,$false)
    Assert-True ((Get-Sha256 $gatePartial) -eq [string]$invocation.sourcePathGateSha256) 'JEO1 staged path-gate hash changed.'
    [IO.File]::Move($gatePartial,$destinationPathGate)
    $gateFinalCreated = $true
    Assert-True ((Get-Sha256 $destinationZip) -eq [string]$invocation.sourceZipSha256) 'JEO1 published ZIP readback changed.'
    Assert-True ((Get-Sha256 $destinationPathGate) -eq [string]$invocation.sourcePathGateSha256) 'JEO1 published path-gate readback changed.'
} catch {
    if (Test-Path -LiteralPath $zipPartial -PathType Leaf) { [IO.File]::Delete($zipPartial) }
    if (Test-Path -LiteralPath $gatePartial -PathType Leaf) { [IO.File]::Delete($gatePartial) }
    if ($gateFinalCreated -and (Test-Path -LiteralPath $destinationPathGate -PathType Leaf)) { [IO.File]::Delete($destinationPathGate) }
    if ($zipFinalCreated -and (Test-Path -LiteralPath $destinationZip -PathType Leaf)) { [IO.File]::Delete($destinationZip) }
    throw
}

$result = [ordered]@{
    schema='argos_jeo1_publication_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_JEO1_PUBLISHED'
    destinationZip=$destinationZip;destinationZipBytes=(Get-Item -LiteralPath $destinationZip).Length;destinationZipSha256=Get-Sha256 $destinationZip
    destinationPathGate=$destinationPathGate;destinationPathGateSha256=Get-Sha256 $destinationPathGate;returnZipAbsent=(-not (Test-Path -LiteralPath $returnZip))
    singlePublicationPerformed=$true;overwritePerformed=$false;taskActionsPerformed=@();processActionsPerformed=@();waferActionPerformed=$false
    imageBytesDecoded=$false;targetExecuted=$false;jbodContacted=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-Utf8CreateNewJson -Path $publicationGate -Value $result -Depth 12
$result | ConvertTo-Json -Depth 12
