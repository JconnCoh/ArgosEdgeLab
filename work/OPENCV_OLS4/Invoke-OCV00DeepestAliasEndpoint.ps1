[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if($Preflight-and$Rehearsal){throw 'OLS4 cannot combine Preflight and Rehearsal.'}

function Get-Sha256([string]$Path){
    $full=[IO.Path]::GetFullPath($Path)
    $stream=[IO.File]::Open($full,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')}
    finally{$sha.Dispose();$stream.Dispose()}
}

function Assert-NewOutputPath([string]$Path){
    $full=[IO.Path]::GetFullPath($Path)
    $components=@($full.Split('\')|Where-Object{-not[string]::IsNullOrWhiteSpace($_)})
    $longest=if($components.Count){[int](($components|Measure-Object Length -Maximum).Maximum)}else{0}
    if(($full.Length+32)-ge200-or$longest-gt80){throw 'OLS4 output path budget failed.'}
    if(Test-Path -LiteralPath $full){throw "OLS4 refuses existing output: $full"}
    return $full
}

function Write-Utf8JsonCreateNew([string]$Path,[object]$Value){
    if(Test-Path -LiteralPath $Path){throw "OLS4 refuses overwrite: $Path"}
    [IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 40)+[Environment]::NewLine),(New-Object Text.UTF8Encoding($false)))
}

$portalRoot='C:\ProgramData\ArgosProjectPortalRO'
$processorRoot='C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2'
$relativeSubtree='PatternedFront\Lot_62619-433'
$approvedDataRootName='JBOD_KLARF_EXPORT'
$aliasName='F'
$maximumDepth=8
$maximumEntries=20000
$maximumDirectories=2048
$maximumBmpLeaves=2048
$failAfterProvider=$false

if($Preflight-or$Rehearsal){
    if([string]::IsNullOrWhiteSpace($InvocationManifest)){throw 'OLS4 Preflight/Rehearsal requires InvocationManifest.'}
    $invocationPath=[IO.Path]::GetFullPath($InvocationManifest)
    if(-not(Test-Path -LiteralPath $invocationPath -PathType Leaf)-or(Get-Item -LiteralPath $invocationPath).Length-gt65536){throw 'OLS4 invocation manifest is missing or too large.'}
    $invocation=Get-Content -LiteralPath $invocationPath -Raw|ConvertFrom-Json
    if([string]$invocation.schema-ne'argos_ols4_entrypoint_invocation_v1'){throw 'OLS4 invocation schema mismatch.'}
    $portalRoot=[IO.Path]::GetFullPath([string]$invocation.portalRoot).TrimEnd('\')
    $processorRoot=[IO.Path]::GetFullPath([string]$invocation.processorRoot).TrimEnd('\')
    $relativeSubtree=[string]$invocation.relativeSubtree
    $approvedDataRootName=[string]$invocation.approvedDataRootName
    $aliasName=[string]$invocation.aliasName
    $maximumDepth=[int]$invocation.maximumDepth
    $maximumEntries=[int]$invocation.maximumEntries
    $maximumDirectories=[int]$invocation.maximumDirectories
    $maximumBmpLeaves=[int]$invocation.maximumBmpLeaves
    $failAfterProvider=($invocation.PSObject.Properties.Name-contains'failAfterProvider')-and[bool]$invocation.failAfterProvider
}

if($relativeSubtree-ne'PatternedFront\Lot_62619-433'-and-not$Rehearsal-and-not$Preflight){throw 'OLS4 live lot boundary changed.'}
if($approvedDataRootName-ne'JBOD_KLARF_EXPORT'){throw 'OLS4 approved data-root identity changed.'}
if($aliasName-ne'F'){throw 'OLS4 alias identity changed.'}
if($maximumDepth-ne8-or$maximumEntries-ne20000-or$maximumDirectories-ne2048-or$maximumBmpLeaves-ne2048){throw 'OLS4 inventory bounds changed.'}

$configPath=[IO.Path]::GetFullPath((Join-Path $portalRoot 'config\endpoint_jbod.json'))
$providerPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'Invoke-OCV00DeepestAliasInventory.ps1'))
$outputPath=Assert-NewOutputPath (Join-Path $processorRoot 'OCV00_OLS4_LOT_INVENTORY.json')
$expectedProviderSha='DFF2B3A54E9C6D30A003CF4CFC283FECA0F104B5D5A2929296A81D283CAA5675'
foreach($path in @($configPath,$providerPath)){if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "OLS4 prerequisite is missing: $path"}}
if((Get-Sha256 $providerPath)-ne$expectedProviderSha){throw 'OLS4 provider hash changed.'}
$tokens=$null
$parseErrors=$null
[void][Management.Automation.Language.Parser]::ParseFile($providerPath,[ref]$tokens,[ref]$parseErrors)
if(@($parseErrors).Count-ne0){throw 'OLS4 provider parser failed.'}

$config=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
if([string]$config.schema-ne'argos_project_portal_endpoint_config_v1'-or[string]$config.role-ne'JBOD'-or-not[bool]$config.reviewOnly-or[bool]$config.productionRoutingEnabled){throw 'OLS4 endpoint config authority failed closed.'}
$mapping=@($config.approvedDataRoots|Where-Object{[string]$_.name-eq$approvedDataRootName})
if($mapping.Count-ne1){throw 'OLS4 approved data-root mapping cardinality changed.'}
$approvedRoot=[IO.Path]::GetFullPath([string]$mapping[0].path).TrimEnd('\')

$providerPreflight=(& $providerPath -Preflight -ApprovedRoot $approvedRoot -RelativeSubtree $relativeSubtree -AliasName $aliasName -MaximumDepth $maximumDepth -MaximumEntries $maximumEntries -MaximumDirectories $maximumDirectories -MaximumBmpLeaves $maximumBmpLeaves)|ConvertFrom-Json
if([string]$providerPreflight.state-ne'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_PREFLIGHT'-or[string]$providerPreflight.aliasAnchor-ne'EXACT_REQUESTED_SUBTREE_ROOT'-or[bool]$providerPreflight.pathsEnumerated-or[bool]$providerPreflight.filesRead-or[bool]$providerPreflight.imageBytesRead-or[bool]$providerPreflight.sourceHashingPerformed-or[bool]$providerPreflight.mutationsPerformed){throw 'OLS4 provider preflight contract failed.'}

if($Preflight){
    [ordered]@{
        schema='argos_ols4_entrypoint_preflight_v1'
        createdUtc=[DateTime]::UtcNow.ToString('o')
        state='PASS_OLS4_ENTRYPOINT_PREFLIGHT'
        approvedDataRoot=$approvedDataRootName
        approvedRoot=$approvedRoot
        relativeSubtree=$relativeSubtree
        aliasName=$aliasName
        aliasAnchor='EXACT_REQUESTED_SUBTREE_ROOT'
        providerSha256=$expectedProviderSha
        outputPath=$outputPath
        pathsEnumerated=$false
        filesRead=$false
        imageBytesRead=$false
        sourceHashingPerformed=$false
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    }|ConvertTo-Json -Depth 8
    return
}

$inventory=(& $providerPath -Inventory -ApprovedRoot $approvedRoot -RelativeSubtree $relativeSubtree -AliasName $aliasName -MaximumDepth $maximumDepth -MaximumEntries $maximumEntries -MaximumDirectories $maximumDirectories -MaximumBmpLeaves $maximumBmpLeaves -Rehearsal:$Rehearsal)|ConvertFrom-Json
if($failAfterProvider){throw 'INJECTED_OLS4_ENTRYPOINT_FAILURE_AFTER_PROVIDER'}
$inventoryState=[string]$inventory.state
$inventoryComplete=[bool]$inventory.complete
if(
    [string]$inventory.schema -ne 'argos_ocv00_deepest_alias_inventory_v1' -or
    $inventoryState -notin @('COMPLETE','HOLD_INCOMPLETE') -or
    $inventoryComplete -ne ($inventoryState -eq 'COMPLETE')
){throw 'OLS4 provider terminal contract changed.'}
if([string]$inventory.aliasAnchor-ne'EXACT_REQUESTED_SUBTREE_ROOT'-or[string]$inventory.relativeSubtree-ne$relativeSubtree-or[string]$inventory.aliasRoot-ne'F:\'){throw 'OLS4 provider alias contract changed.'}
if([bool]$inventory.processLocalAlias.persistent-or-not[bool]$inventory.processLocalAlias.removed){throw 'OLS4 provider alias cleanup failed.'}
if([bool]$inventory.filesRead-or[bool]$inventory.imageBytesRead-or[bool]$inventory.sourceHashingPerformed-or[bool]$inventory.mutationsPerformed){throw 'OLS4 provider crossed the metadata-only boundary.'}
$directories=@($inventory.directories)
$bmpLeaves=@($inventory.bmpLeaves)
$skipRows=@($inventory.skippedPathRows)
if($directories.Count-ne[int]$inventory.directoryCount-or$bmpLeaves.Count-ne[int]$inventory.bmpLeafCount-or$skipRows.Count-ne[int]$inventory.skippedPathRowCount){throw 'OLS4 provider row counts changed.'}
if($skipRows.Count-ne([int]$inventory.skippedUnsafePathSubtrees+[int]$inventory.skippedReparseSubtrees)){throw 'OLS4 skip classification count changed.'}
if(@(($directories+$bmpLeaves)|Where-Object{[int]$_.aliasEffectiveLength-ge200-or-not([string]$_.aliasReadPath).StartsWith('F:\',[StringComparison]::OrdinalIgnoreCase)-or-not[bool]$_.containedByApprovedRoot-or[bool]$_.reparsePoint-or[bool]$_.filesRead-or[bool]$_.imageBytesRead-or[bool]$_.sourceHashingPerformed-or[bool]$_.mutationsPerformed}).Count-ne0){throw 'OLS4 accepted-row safety contract failed.'}
if(@($skipRows|Where-Object{([string]::IsNullOrWhiteSpace([string]$_.parentRelativePath)-and[string]::IsNullOrWhiteSpace([string]$_.childName))-or[string]::IsNullOrWhiteSpace([string]$_.canonicalProvenancePath)-or[string]::IsNullOrWhiteSpace([string]$_.aliasReadPath)-or[string]$_.rejectionReason -notin @('ALIAS_EFFECTIVE_LENGTH_AT_OR_ABOVE_200','ALIAS_COMPONENT_ABOVE_FILESYSTEM_MAXIMUM','REPARSE_CHILD_NOT_TRAVERSED')}).Count-ne0){throw 'OLS4 exact skip identity contract failed.'}

$result=[ordered]@{
    schema='argos_ols4_entrypoint_result_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_OCV00_DEEPEST_ALIAS_INVENTORY_OLS4'
    rehearsal=[bool]$Rehearsal
    approvedDataRoot=$approvedDataRootName
    approvedRoot=$approvedRoot
    relativeSubtree=$relativeSubtree
    providerSha256=$expectedProviderSha
    inventoryDisposition=[string]$inventory.state
    inventory=$inventory
    pathsEnumerated=$true
    filesRead=$false
    imageBytesRead=$false
    sourceHashingPerformed=$false
    sourceDeletionPerformed=$false
    inspectionTasksChanged=$false
    processorTaskChanged=$false
    processActions=@()
    waferActionPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}
Write-Utf8JsonCreateNew $outputPath $result
$readback=Get-Content -LiteralPath $outputPath -Raw|ConvertFrom-Json
if([string]$readback.state-ne'PASS_OCV00_DEEPEST_ALIAS_INVENTORY_OLS4'-or[string]$readback.inventoryDisposition-ne[string]$inventory.state){throw 'OLS4 output readback failed.'}
$result['capabilityOutputPath']=$outputPath
$result['capabilityOutputSha256']=Get-Sha256 $outputPath
$result['capabilityOutputBytes']=(Get-Item -LiteralPath $outputPath).Length
$result|ConvertTo-Json -Depth 40
