#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Apply
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Apply)) {
    throw 'Specify exactly one of -Preflight or -Apply.'
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$sourceRoot = Join-Path $project 'work\OPENCV_SCRIBE_O2D18'
$targetRoot = $PSScriptRoot
$cloneManifest = Join-Path $targetRoot 'O2D19_CLONE_LITERAL_REMEDIATION.json'
Assert-True (Test-Path -LiteralPath $sourceRoot -PathType Container) 'O2D18 source root is absent.'
Assert-True (Test-Path -LiteralPath $cloneManifest -PathType Leaf) 'O2D19 clone-remediation manifest is absent.'

$pairs = @(
    [pscustomobject]@{ source='O2D18_SLOT20_JOB.json'; target='O2D19_SLOT21_JOB.json' },
    [pscustomobject]@{ source='MAINTENANCE_DEFINITION.json'; target='MAINTENANCE_DEFINITION.json' },
    [pscustomobject]@{ source='Invoke-O2D18ScribeEndpoint.ps1'; target='Invoke-O2D19ScribeEndpoint.ps1' },
    [pscustomobject]@{ source='Test-O2D18Endpoint.ps1'; target='Test-O2D19Endpoint.ps1' },
    [pscustomobject]@{ source='Test-O2D18SelfPins.ps1'; target='Test-O2D19SelfPins.ps1' },
    [pscustomobject]@{ source='Test-O2D18NoArgumentFile.ps1'; target='Test-O2D19NoArgumentFile.ps1' },
    [pscustomobject]@{ source='Build-O2D18Request.ps1'; target='Build-O2D19Request.ps1' },
    [pscustomobject]@{ source='Test-O2D18Routes.ps1'; target='Test-O2D19Routes.ps1' },
    [pscustomobject]@{ source='Publish-O2D18.ps1'; target='Publish-O2D19.ps1' },
    [pscustomobject]@{ source='Collect-O2D18Response.ps1'; target='Collect-O2D19Response.ps1' },
    [pscustomobject]@{ source='fixtures\INSTALLATION.json'; target='fixtures\INSTALLATION.json' },
    [pscustomobject]@{ source='fixtures\LIVE_CONTRACT_GOOD.json'; target='fixtures\LIVE_CONTRACT_GOOD.json' },
    [pscustomobject]@{ source='fixtures\LIVE_CONTRACT_BAD_JOB.json'; target='fixtures\LIVE_CONTRACT_BAD_JOB.json' },
    [pscustomobject]@{ source='fixtures\LIVE_CONTRACT_BAD_INSTALLATION.json'; target='fixtures\LIVE_CONTRACT_BAD_INSTALLATION.json' }
)

$replacements = @(
    [pscustomobject]@{ from='C:\O2D18T_227E9F1C'; to='C:\O2D19T_73C073D0' },
    [pscustomobject]@{ from='C:\O2D18R_227E9F1C'; to='C:\O2D19R_73C073D0' },
    [pscustomobject]@{ from='REQ_20260827T004800111Z_227E9F1CBF26'; to='REQ_20260827T012505111Z_73C073D0BF26' },
    [pscustomobject]@{ from='O2D18_20260827T004800000Z_227E9F1C'; to='O2D19_20260827T012505000Z_73C073D0' },
    [pscustomobject]@{ from='2026-08-27T00:00:00Z'; to='2026-08-27T01:25:05Z' },
    [pscustomobject]@{ from='227E9F1CED3D6E49C10C7DEC9803EA76DC341CC64C77801453A930A9FAF3691B'; to='73C073D01127CE0BD7C2C26BB7BF10FE223200847DEE474FBEBA2E8D6882DFCE' },
    [pscustomobject]@{ from='28EDE033FEA4721E7D54DD77083428F13494A5E25D087B01DED9E76ADE87080F'; to='B5A3429B3A307991AD29E11F710E2BDD0DCEC89EE178B15F92B0370CD9ABDFC6' },
    [pscustomobject]@{ from='C0CC9FF91BAC0FEBD45EBEA335133E1BE65FA3F33310B79305C81FC3CDE456AF'; to='__O2D19_JOB_SHA256__' },
    [pscustomobject]@{ from='06FB6E82D86B98D6637A769AA82D053027016D4EFE296A6A96B03B29E67F8269'; to='__O2D19_ENDPOINT_SHA256__' },
    [pscustomobject]@{ from='858BF7DA83DCC2EF520C32D5ED4CB19FC412076135EBBB4A83D25957DB80241E'; to='__O2D19_ENTRYPOINT_GATE_SHA256__' },
    [pscustomobject]@{ from='6C0DB5755372BC157C3AFF7F23AC43CB23547A9DA3FC3000E17D9A86DB0F4EC7'; to='__O2D19_SELF_PIN_GATE_SHA256__' },
    [pscustomobject]@{ from='74DC42CDBDE8CAD62F0F06796F80D39E6376F09A232817FDD6756F8B001B8F85'; to='__O2D19_NO_ARGUMENT_GATE_SHA256__' },
    [pscustomobject]@{ from='BE54A80F50E16CC9E449D95B487067DEEDF8939C1C213A6758912AAC3DC1580B'; to='__O2D19_DEFINITION_SHA256__' },
    [pscustomobject]@{ from='5C96BBB28E2132CC493D2E01C3DB3E9749C170824567529B5C166D05F24B1899'; to='__O2D19_BUILD_PREACTION_SHA256__' },
    [pscustomobject]@{ from='C150C488065D198879D4FD6FF5D8A5180967870643A187AA904B96CD36C1EFF6'; to='__O2D19_BUILD_CLONE_MANIFEST_SHA256__' },
    [pscustomobject]@{ from='CC517BC46739D79E0BB5B9E5C02A761933A9623FBA2D63AE8049614F95B3D13B'; to='__O2D19_FINAL_PACKAGE_GATE_SHA256__' },
    [pscustomobject]@{ from='DB098D3C98F620CC6C56F34B2541B0D685D83DE983FD31FC447D0EAB7A07A4E4'; to='__O2D19_REQUEST_ZIP_SHA256__' },
    [pscustomobject]@{ from='0B7F836B5F32684E3A20A873A2DDCE75670F13758E269F0430DD82157D8DF4F4'; to='__O2D19_COMPLETE_ROUTE_GATE_SHA256__' },
    [pscustomobject]@{ from='0D1392E8FBA3296C076ED990C5A666E508BD5A35C2EF70C725A14B6F252962BD'; to='__O2D19_ALIAS_GATE_SHA256__' },
    [pscustomobject]@{ from='D9D4B1839E2002E29CAD67B7FBB62FCED41468BD1D7C5D1AD1537139331D85DA'; to='__O2D19_PUBLICATION_CHECKPOINT_SHA256__' },
    [pscustomobject]@{ from='940D0B0AB65C27A93C8B13428800359B70B12685FF0D414356B04A2A07D0A4AA'; to='__O2D19_RESPONSE_SHA256__' },
    [pscustomobject]@{ from='R_DDE1C032BD6B_20260827011029175_2677777e'; to='__O2D19_RESPONSE_ID__' },
    [pscustomobject]@{ from='77CF1C09D7B2F064FA60A41DDA377846FC1F599F85D0A8070681B6CDE49BA3E0'; to='__O2D19_INSTALLATION_FIXTURE_SHA256__' },
    [pscustomobject]@{ from='Slot20'; to='Slot21' },
    [pscustomobject]@{ from='SLOT20'; to='SLOT21' },
    [pscustomobject]@{ from='O2D18'; to='O2D19' },
    [pscustomobject]@{ from='o2d18'; to='o2d19' },
    [pscustomobject]@{ from='work\OPENCV_SCRIBE_O2D17\O2D17_TERMINAL_RESPONSE_GATE.json'; to='work\OPENCV_SCRIBE_O2D18\O2D18_TERMINAL_RESPONSE_GATE.json' },
    [pscustomobject]@{ from='D2CA85670EED654572522AB45BF9CC5D90DBBC84B47D4BAB1AA1C7842B1945E2'; to='7086F5005363A85175555603B2D4427F45BA948F219CDEE925E3B18138D09D82' },
    [pscustomobject]@{ from='PASS_O2D17_EXACT_SIGNED_SLOT19_DEVELOPMENT_RESPONSE'; to='PASS_O2D18_EXACT_SIGNED_SLOT20_DEVELOPMENT_RESPONSE' }
)

$planned = @()
foreach ($pair in $pairs) {
    $source = Join-Path $sourceRoot $pair.source
    $target = Join-Path $targetRoot $pair.target
    Assert-True (Test-Path -LiteralPath $source -PathType Leaf) "O2D19 source absent: $source"
    Assert-True (-not (Test-Path -LiteralPath $target)) "O2D19 create-new target exists: $target"
    $text = [IO.File]::ReadAllText($source)
    foreach ($replacement in $replacements) {
        $text = $text.Replace([string]$replacement.from, [string]$replacement.to)
    }
    if ($pair.target -eq 'Collect-O2D19Response.ps1') {
        $text = $text.Replace('$expectedBytes = 3683', '$expectedBytes = __O2D19_RESPONSE_BYTES__')
    }
    Assert-True ($text.IndexOf('O2D18', [StringComparison]::OrdinalIgnoreCase) -lt 0) "O2D19 predecessor product token remains: $($pair.target)"
    Assert-True ($text.IndexOf('Slot20', [StringComparison]::OrdinalIgnoreCase) -lt 0) "O2D19 predecessor slot token remains: $($pair.target)"
    $planned += [pscustomobject]@{ source=$source; target=$target; text=$text }
}

$result = [ordered]@{
    schema = 'argos_o2d19_draft_generation_v1'
    createdUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($Preflight) { 'PASS_O2D19_DRAFT_GENERATION_PREFLIGHT' } else { 'PASS_O2D19_DRAFT_GENERATED' }
    sourceRevision = 'O2D18_SIGNED_SLOT20_APPROVED_DEVELOPMENT_BASELINE'
    targetRevision = 'O2D19_20260827T012505000Z_73C073D0'
    generatedFileCount = $planned.Count
    sourceImageBytesRead = $false
    externalMutationPerformed = $false
    targetExecuted = $false
    reviewOnly = $true
    productionRoutingEnabled = $false
}

if ($Preflight) {
    $result | ConvertTo-Json -Depth 6
    return
}

$utf8 = New-Object Text.UTF8Encoding($false)
foreach ($item in $planned) {
    $parent = Split-Path -Parent $item.target
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        [void][IO.Directory]::CreateDirectory($parent)
    }
    [IO.File]::WriteAllText($item.target, $item.text, $utf8)
}
$result | ConvertTo-Json -Depth 6
