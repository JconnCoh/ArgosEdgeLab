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

$project = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path).TrimEnd('\')
$invocationPath = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $InvocationManifest).Path)
Assert-True ($invocationPath.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) 'CDM1 publish invocation left the project.'
$invocation = Get-Content -LiteralPath $invocationPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_cdm1_publish_invocation_v1' -and [string]$invocation.revision -eq 'CDM1') 'CDM1 publish invocation changed.'
Assert-True ([bool]$invocation.singlePublicationAuthorized -and -not [bool]$invocation.overwriteAuthorized) 'CDM1 publication authority changed.'
Assert-True ([bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'CDM1 publication safety flags changed.'

function Resolve-ProjectPath {
    param([string]$Relative)
    $path = [IO.Path]::GetFullPath((Join-Path $project $Relative))
    Assert-True ($path.StartsWith($project+'\',[StringComparison]::OrdinalIgnoreCase)) "CDM1 project path escaped: $Relative"
    return $path
}

$sourceZip = Resolve-ProjectPath ([string]$invocation.sourceZip)
$sourcePathGate = Resolve-ProjectPath ([string]$invocation.sourcePathGate)
$prepublicationGate = Resolve-ProjectPath ([string]$invocation.prepublicationGate)
$publicationGate = Resolve-ProjectPath ([string]$invocation.publicationGate)
$destinationZip = [IO.Path]::GetFullPath([string]$invocation.destinationZip)
$destinationPathGate = [IO.Path]::GetFullPath([string]$invocation.destinationPathGate)
$expectedParent = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
Assert-True ((Split-Path -Parent $destinationZip).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'CDM1 destination ZIP parent changed.'
Assert-True ((Split-Path -Parent $destinationPathGate).Equals($expectedParent,[StringComparison]::OrdinalIgnoreCase)) 'CDM1 destination path-gate parent changed.'
Assert-True ([IO.Path]::GetFileName($destinationZip) -eq 'ARGOS_CDM1.zip' -and [IO.Path]::GetFileName($destinationPathGate) -eq 'ARGOS_CDM1_PATH_GATE.json') 'CDM1 destination name changed.'
Assert-True (Test-Path -LiteralPath $sourceZip -PathType Leaf) 'CDM1 source ZIP is absent.'
Assert-True ((Get-Item -LiteralPath $sourceZip).Length -eq [int64]$invocation.sourceZipBytes -and (Get-Sha256 $sourceZip) -eq [string]$invocation.sourceZipSha256) 'CDM1 source ZIP changed.'
Assert-True (Test-Path -LiteralPath $sourcePathGate -PathType Leaf) 'CDM1 source path gate is absent.'
Assert-True ((Get-Sha256 $sourcePathGate) -eq [string]$invocation.sourcePathGateSha256) 'CDM1 source path gate changed.'
Assert-True (Test-Path -LiteralPath $prepublicationGate -PathType Leaf) 'CDM1 prepublication gate is absent.'
Assert-True ((Get-Sha256 $prepublicationGate) -eq [string]$invocation.prepublicationGateSha256) 'CDM1 prepublication gate changed.'
$prepublication = Get-Content -LiteralPath $prepublicationGate -Raw | ConvertFrom-Json
Assert-True ([string]$prepublication.state -eq 'PASS_CDM1_PREPUBLICATION') 'CDM1 prepublication gate is not PASS.'
Assert-True (Test-Path -LiteralPath $expectedParent -PathType Container) 'CDM1 engineering share publication root is unavailable.'
foreach ($freshPath in @($destinationZip,$destinationPathGate,$publicationGate,$destinationZip+'.partial.CDM1',$destinationPathGate+'.partial.CDM1')) {
    Assert-True (-not (Test-Path -LiteralPath $freshPath)) "CDM1 publication path must be fresh: $freshPath"
}

$preflightResult = [ordered]@{
    schema='argos_cdm1_publish_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_PUBLISH_PREFLIGHT'
    sourceZip=$sourceZip;sourceZipSha256=[string]$invocation.sourceZipSha256;sourcePathGate=$sourcePathGate;destinationZip=$destinationZip;destinationPathGate=$destinationPathGate
    publicationGate=$publicationGate;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
if ($Preflight) { $preflightResult | ConvertTo-Json -Depth 10; return }
Assert-True ([bool]$Publish) 'Specify -Preflight or -Publish.'

$zipPartial = $destinationZip+'.partial.CDM1'
$gatePartial = $destinationPathGate+'.partial.CDM1'
$zipFinalCreated = $false
$gateFinalCreated = $false
try {
    [IO.File]::Copy($sourceZip,$zipPartial,$false)
    Assert-True ((Get-Sha256 $zipPartial) -eq [string]$invocation.sourceZipSha256) 'CDM1 staged ZIP hash changed.'
    [IO.File]::Move($zipPartial,$destinationZip)
    $zipFinalCreated = $true
    [IO.File]::Copy($sourcePathGate,$gatePartial,$false)
    Assert-True ((Get-Sha256 $gatePartial) -eq [string]$invocation.sourcePathGateSha256) 'CDM1 staged path-gate hash changed.'
    [IO.File]::Move($gatePartial,$destinationPathGate)
    $gateFinalCreated = $true
    Assert-True ((Get-Sha256 $destinationZip) -eq [string]$invocation.sourceZipSha256) 'CDM1 published ZIP readback changed.'
    Assert-True ((Get-Sha256 $destinationPathGate) -eq [string]$invocation.sourcePathGateSha256) 'CDM1 published path-gate readback changed.'
} catch {
    if (Test-Path -LiteralPath $zipPartial -PathType Leaf) { [IO.File]::Delete($zipPartial) }
    if (Test-Path -LiteralPath $gatePartial -PathType Leaf) { [IO.File]::Delete($gatePartial) }
    if ($gateFinalCreated -and (Test-Path -LiteralPath $destinationPathGate -PathType Leaf)) { [IO.File]::Delete($destinationPathGate) }
    if ($zipFinalCreated -and (Test-Path -LiteralPath $destinationZip -PathType Leaf)) { [IO.File]::Delete($destinationZip) }
    throw
}

$result = [ordered]@{
    schema='argos_cdm1_publication_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_CDM1_PUBLISHED'
    destinationZip=$destinationZip;destinationZipBytes=(Get-Item -LiteralPath $destinationZip).Length;destinationZipSha256=Get-Sha256 $destinationZip
    destinationPathGate=$destinationPathGate;destinationPathGateSha256=Get-Sha256 $destinationPathGate;singlePublicationPerformed=$true;overwritePerformed=$false
    taskActionsPerformed=@();processActionsPerformed=@();waferActionPerformed=$false;imageBytesDecoded=$false;reviewOnly=$true;productionRoutingEnabled=$false
}
Write-Utf8CreateNewJson -Path $publicationGate -Value $result -Depth 12
$result | ConvertTo-Json -Depth 12
