#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InvocationManifest = (Join-Path $PSScriptRoot 'INVOCATION.json'),
    [switch]$Preflight,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$liveRevision = 'O2A3_20260825T195521Z_SLOT16'
$liveRequestId = 'DIRECT_O2A3_20260825T195521Z_SLOT16'
$liveProcessorConfigSha = 'CDFD888129D0144C9942D027B0C4583FEEF3619D6D65B060B3001686357879D8'
$liveEndpointConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$liveSenderConfigSha = '8420A302D0EE0665E9E034448A245613C6AD5E7EE2D82BF0E7F962A7F7B104E0'
$liveDependencyHashes = [ordered]@{
    processorRunner = '46661DB0FC7F12AE7146067403390AF7CC7D0DD933A67C601C56E0EECB4FE9A4'
    scribeProposalPass = '3B00E5CDE1BA28DCE347DD4BC83D28B301058E70160D70D4E23E878E5904915B'
    multiChannelReader = 'E5EA835CA3E8BE32A8E19E9CE46E1E114DFC4823D6A6F186E01AE8BFFF5D6C73'
    polarityVariants = '94DFB1B7F38A1E5BF12C41F9D8FBEEDAFFDF888365E9646F1058C58A9F5DEF0C'
    imageReader = '0E64D5FBE57556B7FC5A37D6764FDA65CBF780F96A3C994B73954CF985E67206'
    referenceManifest = 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229'
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Get-TextSha256([string]$Text) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-', '') }
    finally { $hasher.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2A3 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $components = @($full.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($components.Count -eq 0) { 0 } else { [int](($components | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) }
    Assert-True (($full.Length + $Reserve) -lt 200) "O2A3 unsafe effective path length: $full"
    Assert-True ($longest -le 80) "O2A3 unsafe path component: $full"
}

function Read-BoundedJson([string]$Path, [int64]$MaximumBytes) {
    Assert-True (Test-Path -LiteralPath $Path -PathType Leaf) "O2A3 JSON file is absent: $Path"
    $bytes = (Get-Item -LiteralPath $Path).Length
    Assert-True ($bytes -le $MaximumBytes) "O2A3 JSON byte bound exceeded: $Path"
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Get-Optional([AllowNull()][object]$Value, [string]$Name, [AllowNull()][object]$Default = $null) {
    if ($null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name) { return $Value.$Name }
    return $Default
}

function Assert-PackageFiles([object]$Manifest, [string]$Revision) {
    Assert-True ([string]$Manifest.schema -eq 'argos_o2a3_direct_package_manifest_v1') 'O2A3 package manifest schema changed.'
    Assert-True ([string]$Manifest.revision -eq $Revision) 'O2A3 package manifest revision changed.'
    $expected = @('INVOCATION.json','Invoke-O2A3Direct.ps1','README_FIRST.txt','RUN_O2A3.cmd')
    $records = @($Manifest.files)
    Assert-True ($records.Count -eq $expected.Count) 'O2A3 package manifest file count changed.'
    $names = @($records | ForEach-Object { [string]$_.path } | Sort-Object)
    Assert-True (@(Compare-Object -ReferenceObject $expected -DifferenceObject $names).Count -eq 0) 'O2A3 package manifest file set changed.'
    foreach ($record in $records) {
        $path = Join-Path $PSScriptRoot ([string]$record.path)
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2A3 package file is absent: $($record.path)"
        Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$record.bytes) "O2A3 package file bytes changed: $($record.path)"
        Assert-True ((Get-Sha256 $path) -eq [string]$record.sha256) "O2A3 package file hash changed: $($record.path)"
    }
}

function Get-Signer([object]$Config) {
    $thumbprint = ([string]$Config.endpointSignerThumbprint).Replace(' ', '').ToUpperInvariant()
    $location = [string]$Config.endpointSignerStoreLocation
    Assert-True ($location -in @('CurrentUser','LocalMachine')) 'O2A3 signer store location changed.'
    $certificate = Get-Item -LiteralPath ("Cert:\$location\My\$thumbprint") -ErrorAction Stop
    Assert-True ([bool]$certificate.HasPrivateKey) 'O2A3 signer private key is unavailable.'
    return $certificate
}

function Test-Signer([object]$Certificate) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes('O2A3_NON_MUTATING_SIGNER_ACCESS_TEST')
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    Assert-True ($null -ne $rsa) 'O2A3 signer RSA private key is unavailable.'
    try {
        $signature = $rsa.SignData($bytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        Assert-True ($rsa.VerifyData($bytes, $signature, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) 'O2A3 signer access test did not verify.'
    }
    finally { $rsa.Dispose() }
}

function New-LocalResultZip([string]$OutputRoot, [string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $partial = $ZipPath + '.partial'
    Assert-True (-not (Test-Path -LiteralPath $partial) -and -not (Test-Path -LiteralPath $ZipPath)) 'O2A3 local result path is not fresh.'
    Assert-PathBudget $partial 32
    [IO.Compression.ZipFile]::CreateFromDirectory($OutputRoot, $partial, [IO.Compression.CompressionLevel]::Optimal, $false)
    Move-Item -LiteralPath $partial -Destination $ZipPath -ErrorAction Stop
}

function New-SignedResponse([object]$Config, [object]$Certificate, [string]$RequestId, [string]$ResultRoot, [string]$State, [string]$Detail, [string]$QuarantineRoot) {
    $created = [DateTimeOffset]::UtcNow
    $hashBytes = (New-Object Text.UTF8Encoding($false)).GetBytes($RequestId)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { $short = ([BitConverter]::ToString($hasher.ComputeHash($hashBytes))).Replace('-', '').Substring(0,12) }
    finally { $hasher.Dispose() }
    $responseId = 'R_' + $short + '_' + $created.ToString('yyyyMMddHHmmssfff') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8)
    $outbox = [string]$Config.responseOutbox
    $partial = Join-Path $outbox ($responseId + '.partial')
    $ready = Join-Path $outbox ($responseId + '.ready')
    Assert-PathBudget $partial 32
    Assert-PathBudget $ready 32
    Assert-True (-not (Test-Path -LiteralPath $partial) -and -not (Test-Path -LiteralPath $ready)) 'O2A3 response package collision.'
    try {
        [void](New-Item -ItemType Directory -Path $partial)
        $sourceRoot = [IO.Path]::GetFullPath($ResultRoot).TrimEnd('\')
        foreach ($file in @((New-Object IO.DirectoryInfo($sourceRoot)).EnumerateFiles('*', [IO.SearchOption]::AllDirectories))) {
            $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
            Assert-True (-not $relative.Contains('..')) 'O2A3 response relative path changed.'
            $destination = Join-Path $partial $relative
            Assert-PathBudget $destination 32
            $parent = Split-Path -Parent $destination
            if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
            Copy-Item -LiteralPath $file.FullName -Destination $destination -ErrorAction Stop
        }
        $records = @((New-Object IO.DirectoryInfo($partial)).EnumerateFiles('*', [IO.SearchOption]::AllDirectories) | Sort-Object FullName | ForEach-Object {
            [ordered]@{path=$_.FullName.Substring($partial.TrimEnd('\').Length).TrimStart('\').Replace('\','/');bytes=$_.Length;sha256=Get-Sha256 $_.FullName}
        })
        $thumbprint = $Certificate.Thumbprint.Replace(' ', '').ToUpperInvariant()
        $manifest = [ordered]@{
            schema='argos_project_portal_response_manifest_v1';responseId=$responseId;requestId=$RequestId;createdUtc=$created.ToString('o');sourceRole=[string]$Config.role
            state=$State;detail=$Detail;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
            credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=$records
        }
        $manifestBytes = (New-Object Text.UTF8Encoding($false)).GetBytes(($manifest | ConvertTo-Json -Depth 24))
        [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.json'), $manifestBytes)
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
        try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
        finally { $rsa.Dispose() }
        [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.sig'), $signature)
        Move-Item -LiteralPath $partial -Destination $ready -ErrorAction Stop
        return [pscustomobject]@{responseId=$responseId;readyPath=$ready;manifestSha256=Get-Sha256 (Join-Path $ready 'PORTAL_RESPONSE_MANIFEST.json')}
    }
    catch {
        $responseError = $_.Exception
        if (Test-Path -LiteralPath $partial -PathType Container) {
            try {
                if (-not (Test-Path -LiteralPath $QuarantineRoot -PathType Container)) { [void](New-Item -ItemType Directory -Path $QuarantineRoot) }
                $failed = Join-Path $QuarantineRoot ($responseId + '.partial')
                Assert-True (-not (Test-Path -LiteralPath $failed)) 'O2A3 response quarantine collision.'
                Move-Item -LiteralPath $partial -Destination $failed -ErrorAction Stop
            }
            catch {}
        }
        throw $responseError
    }
}

function Get-ProcessorSnapshot([object]$Invocation, [bool]$IsRehearsal) {
    if ($IsRehearsal) { return @($Invocation.processorFixture) }
    $token = [string]$Invocation.processorCommandToken
    $rows = @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        $null -ne $_.CommandLine -and $_.CommandLine.IndexOf($token, [StringComparison]::OrdinalIgnoreCase) -ge 0
    } | Sort-Object ProcessId | Select-Object -First 4 | ForEach-Object {
        [ordered]@{
            processId=[int64]$_.ProcessId
            name=[string]$_.Name
            executablePath=[string]$_.ExecutablePath
            creationDate=if ($null -eq $_.CreationDate) { '' } else { ([DateTime]$_.CreationDate).ToUniversalTime().ToString('o') }
            commandLineSha256=Get-TextSha256 ([string]$_.CommandLine)
        }
    })
    return $rows
}

function Add-DeclaredMetadata([AllowNull()][object]$Value, [string]$JsonPath, [Collections.Generic.List[object]]$Rows, [int]$Depth) {
    if ($null -eq $Value -or $Depth -gt 16 -or $Rows.Count -ge 256) { return }
    if ($Value -is [Collections.IEnumerable] -and -not ($Value -is [string]) -and -not ($Value -is [Management.Automation.PSCustomObject])) {
        $index = 0
        foreach ($item in @($Value)) {
            Add-DeclaredMetadata -Value $item -JsonPath ($JsonPath + '[' + $index + ']') -Rows $Rows -Depth ($Depth + 1)
            $index++
            if ($index -ge 256 -or $Rows.Count -ge 256) { break }
        }
        return
    }
    $properties = @($Value.PSObject.Properties)
    if ($properties.Count -eq 0) { return }
    foreach ($property in $properties) {
        $name = [string]$property.Name
        $childPath = if ([string]::IsNullOrWhiteSpace($JsonPath)) { $name } else { $JsonPath + '.' + $name }
        $child = $property.Value
        $isScalar = $null -eq $child -or $child -is [string] -or $child -is [ValueType]
        if ($isScalar -and $name -match '(?i)(crop|roi|region|image|source|path|width|height|left|top|right|bottom|angle|rotation|channel|orientation|coordinate)') {
            $text = if ($null -eq $child) { '' } else { [string]$child }
            Assert-True ($text.Length -le 4096) "O2A3 declared metadata scalar is too long: $childPath"
            $Rows.Add([pscustomobject][ordered]@{jsonPath=$childPath;name=$name;value=$child})
        }
        elseif (-not $isScalar) {
            Add-DeclaredMetadata -Value $child -JsonPath $childPath -Rows $Rows -Depth ($Depth + 1)
        }
        if ($Rows.Count -ge 256) { break }
    }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O2A3 invocation manifest is absent.'
$invocation = Read-BoundedJson -Path $InvocationManifest -MaximumBytes 1048576
Assert-True ([string]$invocation.schema -eq 'argos_o2a3_direct_invocation_v1') 'O2A3 invocation schema changed.'
Assert-True ([bool]$invocation.rehearsal -eq [bool]$Rehearsal) 'O2A3 rehearsal switch and invocation disagree.'
Assert-True ([bool]$invocation.authority.reviewOnly -and -not [bool]$invocation.authority.productionRoutingEnabled) 'O2A3 authority changed.'
foreach ($property in @('taskOrProcessRestartAllowed','providerActivationAllowed','sourceMutationAllowed','sourceDeletionAllowed','holdClearanceAllowed','imageReadAllowed','waferActionAllowed')) {
    Assert-True (-not [bool](Get-Optional $invocation.authority $property $true)) "O2A3 prohibited authority changed: $property"
}

$revision = [string]$invocation.revision
$requestId = [string]$invocation.requestId
if (-not $Rehearsal) {
    Assert-True ($revision -eq $liveRevision -and $requestId -eq $liveRequestId) 'O2A3 live identity changed.'
    Assert-True ($env:COMPUTERNAME -eq 'A1025645101') "O2A3 refuses this computer: $($env:COMPUTERNAME)"
}

$packageManifestPath = Join-Path $PSScriptRoot 'PACKAGE_MANIFEST.json'
Assert-True (Test-Path -LiteralPath $packageManifestPath -PathType Leaf) 'O2A3 package manifest is absent.'
$packageManifest = Read-BoundedJson -Path $packageManifestPath -MaximumBytes 1048576
Assert-PackageFiles -Manifest $packageManifest -Revision $revision

$processorConfigPath = [string]$invocation.paths.processorConfigPath
$endpointConfigPath = [string]$invocation.paths.endpointConfigPath
$senderConfigPath = [string]$invocation.paths.senderConfigPath
$outputRoot = [string]$invocation.paths.outputRoot
$localResultPath = [string]$invocation.paths.localResultPath
$stateRoot = [string]$invocation.paths.stateRoot
$responseQuarantineRoot = Join-Path $outputRoot 'response_quarantine'
$observationPath = Join-Path $outputRoot 'O2A3_OBSERVATION.json'
$executionPath = Join-Path $outputRoot 'O2A3_EXECUTION.json'
$failurePath = Join-Path $outputRoot 'O2A3_FAILURE.json'

foreach ($path in @($processorConfigPath,$endpointConfigPath,$senderConfigPath,$outputRoot,$localResultPath,($localResultPath + '.partial'),$observationPath,$executionPath,$failurePath)) { Assert-PathBudget $path 32 }
foreach ($path in @($processorConfigPath,$endpointConfigPath,$senderConfigPath)) { Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2A3 required file is absent: $path" }

$processorConfigSha = Get-Sha256 $processorConfigPath
$endpointConfigSha = Get-Sha256 $endpointConfigPath
$senderConfigSha = Get-Sha256 $senderConfigPath
Assert-True ($processorConfigSha -eq [string]$invocation.pins.processorConfigSha256) 'O2A3 processor config changed.'
Assert-True ($endpointConfigSha -eq [string]$invocation.pins.endpointConfigSha256) 'O2A3 endpoint config changed.'
Assert-True ($senderConfigSha -eq [string]$invocation.pins.senderConfigSha256) 'O2A3 sender config changed.'

$processorConfig = Read-BoundedJson -Path $processorConfigPath -MaximumBytes 1048576
$endpointConfig = Read-BoundedJson -Path $endpointConfigPath -MaximumBytes 1048576
$senderConfig = Read-BoundedJson -Path $senderConfigPath -MaximumBytes 1048576
Assert-True ([string]$processorConfig.schema -eq 'argos_jbod_all_wafer_processor_config_v3') 'O2A3 processor config schema changed.'
Assert-True ([bool]$processorConfig.reviewOnly -and -not [bool]$processorConfig.xmlExportEnabled -and -not [bool]$processorConfig.productionEligible) 'O2A3 processor safety contract changed.'
Assert-True ([bool]$processorConfig.automaticScribeProposalEnabled) 'O2A3 automatic scribe proposal setting changed.'
Assert-True ([IO.Path]::GetFullPath([string]$processorConfig.stateRoot).TrimEnd('\').Equals([IO.Path]::GetFullPath($stateRoot).TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O2A3 state root changed.'
Assert-True ([string]$endpointConfig.schema -eq 'argos_project_portal_endpoint_config_v1' -and [string]$endpointConfig.role -eq 'JBOD') 'O2A3 endpoint config schema/role changed.'
Assert-True (-not [bool]$endpointConfig.productionRoutingEnabled -and [string]$endpointConfig.responseOutbox -eq [string]$senderConfig.sender.watchRoot) 'O2A3 response outbox contract changed.'
Assert-True ([bool]$senderConfig.sender.enabled -and -not [bool]$senderConfig.receiver.enabled -and [int]$senderConfig.sender.port -eq 48717) 'O2A3 sender transport contract changed.'
Assert-True (Test-Path -LiteralPath ([string]$endpointConfig.responseOutbox) -PathType Container) 'O2A3 response outbox is absent.'
Assert-PathBudget ([string]$endpointConfig.responseOutbox) 96

$dependencyRelativePaths = [ordered]@{
    processorRunner='Run-JbodAllWaferProcessor.ps1'
    scribeProposalPass='Invoke-JbodScribeProposalPass.ps1'
    multiChannelReader='runtime\scribe\Invoke-ScribeMultiChannelPolarityReader.ps1'
    polarityVariants='runtime\scribe\ScribeChannelPolarityVariants.cs'
    imageReader='runtime\scribe\SemiM12DotMatrixImageReader.cs'
    referenceManifest='runtime\scribe\references\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
}
$dependencyRows = New-Object Collections.Generic.List[object]
foreach ($name in @($dependencyRelativePaths.Keys)) {
    $path = Join-Path $stateRoot ([string]$dependencyRelativePaths[$name])
    Assert-PathBudget $path 32
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2A3 installed dependency is absent: $name"
    $sha = Get-Sha256 $path
    Assert-True ($sha -eq [string]$invocation.pins.dependencies.$name) "O2A3 installed dependency hash changed: $name"
    $dependencyRows.Add([pscustomobject][ordered]@{name=$name;path=$path;bytes=(Get-Item -LiteralPath $path).Length;sha256=$sha;imageBytesRead=$false})
}

$callerPath = Join-Path $stateRoot ([string]$dependencyRelativePaths.scribeProposalPass)
$callerText = [IO.File]::ReadAllText($callerPath)
$requiredCallerTokens = @('identity\proposals','SCRIBE_PROPOSAL.json','runtime\scribe','Invoke-ScribeMultiChannelPolarityReader.ps1','MULTI_CHANNEL_READER_SUMMARY.json','MULTI_CHANNEL_READER_HOLD.json')
$callerTokenRows = @($requiredCallerTokens | ForEach-Object {
    [ordered]@{token=$_;present=($callerText.IndexOf($_, [StringComparison]::OrdinalIgnoreCase) -ge 0)}
})
Assert-True (@($callerTokenRows | Where-Object { -not [bool]$_.present }).Count -eq 0) 'O2A3 installed caller no longer proves the expected proposal/reader path contract.'

if (-not $Rehearsal) {
    Assert-True ($processorConfigSha -eq $liveProcessorConfigSha -and $endpointConfigSha -eq $liveEndpointConfigSha -and $senderConfigSha -eq $liveSenderConfigSha) 'O2A3 live config pins changed.'
    foreach ($name in @($liveDependencyHashes.Keys)) { Assert-True ([string]$invocation.pins.dependencies.$name -eq [string]$liveDependencyHashes[$name]) "O2A3 live dependency pin changed: $name" }
    Assert-True ($stateRoot -eq 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2') 'O2A3 live state root changed.'
    Assert-True ($outputRoot -eq 'D:\A2\x\O2A3_20260825T195521Z') 'O2A3 live output root changed.'
    Assert-True ($localResultPath -eq 'D:\A2\x\O2A3R_20260825T195521Z.zip') 'O2A3 live result path changed.'
}

$certificate = Get-Signer $endpointConfig
Test-Signer $certificate
$senderRows = @(if ($Rehearsal) { @($invocation.senderProcessFixture) } else {
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        $null -ne $_.CommandLine -and $_.CommandLine.IndexOf($senderConfigPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
    } | Select-Object -First 4)
})
Assert-True ($senderRows.Count -eq 1) "O2A3 response-sender process cardinality changed: $($senderRows.Count)"
$processorBefore = @(Get-ProcessorSnapshot -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
Assert-True ($processorBefore.Count -eq 1) "O2A3 healthy processor process cardinality changed: $($processorBefore.Count)"

$catalogPath = Join-Path $stateRoot 'catalog\ALL_WAFER_CATALOG.json'
$proposalRoot = Join-Path $stateRoot 'identity\proposals'
foreach ($path in @($catalogPath,$proposalRoot)) { Assert-PathBudget $path 32 }
Assert-True (Test-Path -LiteralPath $catalogPath -PathType Leaf) 'O2A3 installed catalog is absent.'
Assert-True ((Get-Item -LiteralPath $catalogPath).Length -le [int64]$invocation.maximumCatalogBytes) 'O2A3 catalog exceeds its read bound.'
Assert-True (-not (Test-Path -LiteralPath $outputRoot)) 'O2A3 output root must be fresh.'
Assert-True (-not (Test-Path -LiteralPath $localResultPath) -and -not (Test-Path -LiteralPath ($localResultPath + '.partial'))) 'O2A3 local result path must be fresh.'

if (-not $Rehearsal) {
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction Stop
    Assert-True ($null -ne $d -and [int64]$d.FreeSpace -ge [int64]$invocation.minimumDDriveFreeBytes) 'O2A3 D free-space floor failed.'
}

if ($Preflight) {
    [ordered]@{
        schema='argos_o2a3_direct_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_DIRECT_ADMIN_READ_ONLY_PREFLIGHT';revision=$revision;requestId=$requestId
        rehearsal=[bool]$Rehearsal;computerName=$env:COMPUTERNAME;processorConfigSha256=$processorConfigSha;endpointConfigSha256=$endpointConfigSha;senderConfigSha256=$senderConfigSha
        installedDependencyCount=$dependencyRows.Count;callerPathContractVerified=$true;signerThumbprint=$certificate.Thumbprint.Replace(' ','').ToUpperInvariant();signerAccessVerified=$true
        senderProcessCount=$senderRows.Count;processorProcessId=[int64]$processorBefore[0].processId;processorCreationDate=[string]$processorBefore[0].creationDate
        outputRoot=$outputRoot;localResultPath=$localResultPath;targetExecuted=$false;mutationsPerformed=$false;imageBytesRead=$false;sourceHashingPerformed=$false
        taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 10
    return
}

$localResultCreated = $false
$responseCreated = $false
try {
    [void](New-Item -ItemType Directory -Path $outputRoot)
    $sourceCopyRoot = Join-Path $outputRoot 'source_json'
    [void](New-Item -ItemType Directory -Path $sourceCopyRoot)

    $catalog = Read-BoundedJson -Path $catalogPath -MaximumBytes ([int64]$invocation.maximumCatalogBytes)
    $catalogRows = @($catalog.acquisitions | Where-Object {
        [string](Get-Optional $_ 'lot' '') -eq [string]$invocation.target.lotId -and
        [string](Get-Optional $_ 'slot' '') -eq [string]$invocation.target.slotId -and
        [string](Get-Optional $_ 'physicalIdentity' '') -eq [string]$invocation.target.expectedPhysicalIdentity -and
        [string](Get-Optional $_ 'domain' '') -eq 'FRONTSIDE'
    })
    Assert-True ($catalogRows.Count -le 1) 'O2A3 exact catalog selector returned multiple rows.'
    $physicalIdentity = if ($catalogRows.Count -eq 1) { [string]$catalogRows[0].physicalIdentity } else { [string]$invocation.target.expectedPhysicalIdentity }
    $proposalDirectory = Join-Path $proposalRoot $physicalIdentity
    $proposalPath = Join-Path $proposalDirectory 'SCRIBE_PROPOSAL.json'
    $readerRoot = Join-Path $proposalDirectory 'scribe\multi_channel'
    $readerSummaryPath = Join-Path $readerRoot 'MULTI_CHANNEL_READER_SUMMARY.json'
    $readerHoldPath = Join-Path $readerRoot 'MULTI_CHANNEL_READER_HOLD.json'
    foreach ($path in @($proposalDirectory,$proposalPath,$readerRoot,$readerSummaryPath,$readerHoldPath)) { Assert-PathBudget $path 32 }

    $sourceRows = New-Object Collections.Generic.List[object]
    $declaredMetadata = New-Object Collections.Generic.List[object]
    foreach ($record in @(
        [ordered]@{id='PROPOSAL';path=$proposalPath;leaf='SCRIBE_PROPOSAL.json'},
        [ordered]@{id='READER_SUMMARY';path=$readerSummaryPath;leaf='MULTI_CHANNEL_READER_SUMMARY.json'},
        [ordered]@{id='READER_HOLD';path=$readerHoldPath;leaf='MULTI_CHANNEL_READER_HOLD.json'}
    )) {
        $present = Test-Path -LiteralPath ([string]$record.path) -PathType Leaf
        if ($present) {
            $bytes = (Get-Item -LiteralPath ([string]$record.path)).Length
            Assert-True ($bytes -le [int64]$invocation.maximumEvidenceJsonBytes) "O2A3 evidence JSON exceeds bound: $($record.id)"
            $sha = Get-Sha256 ([string]$record.path)
            $value = Read-BoundedJson -Path ([string]$record.path) -MaximumBytes ([int64]$invocation.maximumEvidenceJsonBytes)
            $destination = Join-Path $sourceCopyRoot ([string]$record.leaf)
            [IO.File]::Copy([string]$record.path, $destination, $false)
            Assert-True ((Get-Sha256 $destination) -eq $sha) "O2A3 evidence copy hash changed: $($record.id)"
            Add-DeclaredMetadata -Value $value -JsonPath ([string]$record.id) -Rows $declaredMetadata -Depth 0
            $sourceRows.Add([pscustomobject][ordered]@{id=$record.id;path=$record.path;present=$true;bytes=$bytes;sha256=$sha;returnedRelativePath=('source_json/' + [string]$record.leaf);jsonParsed=$true;imageBytesRead=$false})
        }
        else {
            $sourceRows.Add([pscustomobject][ordered]@{id=$record.id;path=$record.path;present=$false;bytes=$null;sha256=$null;returnedRelativePath=$null;jsonParsed=$false;imageBytesRead=$false})
        }
    }

    $processorAfter = @(Get-ProcessorSnapshot -Invocation $invocation -IsRehearsal ([bool]$Rehearsal))
    Assert-True ($processorAfter.Count -eq 1) 'O2A3 processor process cardinality changed after observation.'
    Assert-True ([int64]$processorAfter[0].processId -eq [int64]$processorBefore[0].processId -and [string]$processorAfter[0].creationDate -eq [string]$processorBefore[0].creationDate) 'O2A3 healthy processor identity changed during observation.'

    $proposalPresent = [bool](@($sourceRows.ToArray() | Where-Object { $_.id -eq 'PROPOSAL' -and $_.present }).Count -eq 1)
    $readerEvidencePresent = [bool](@($sourceRows.ToArray() | Where-Object { $_.id -in @('READER_SUMMARY','READER_HOLD') -and $_.present }).Count -ge 1)
    $observationState = if ($catalogRows.Count -eq 1 -and $proposalPresent -and $readerEvidencePresent) { 'PASS_O2A3_EXACT_SLOT16_SCRIBE_OBSERVATION' } else { 'HOLD_O2A3_EXACT_SLOT16_SCRIBE_EVIDENCE_INCOMPLETE' }
    $observation = [ordered]@{
        schema='argos_o2a3_exact_slot16_scribe_observation_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state=$observationState;incidentId=[string]$invocation.incidentId
        revision=$revision;requestId=$requestId;computerName=$env:COMPUTERNAME;target=$invocation.target;catalogPath=$catalogPath;catalogSha256=Get-Sha256 $catalogPath
        catalogExactRowCount=$catalogRows.Count;catalogExactRows=@($catalogRows);derivedPhysicalIdentity=$physicalIdentity;proposalDirectory=$proposalDirectory;proposalDirectoryExists=(Test-Path -LiteralPath $proposalDirectory -PathType Container)
        sourceJson=$sourceRows.ToArray();declaredCropAndDimensionMetadata=$declaredMetadata.ToArray();declaredMetadataCount=$declaredMetadata.Count
        installedDependencies=$dependencyRows.ToArray();callerPathContractTokens=$callerTokenRows;processorBefore=$processorBefore;processorAfter=$processorAfter
        processorIdentityUnchanged=$true;senderProcessCount=$senderRows.Count;imageFilesOpened=$false;imageBytesRead=$false;imageFilesHashed=$false;pixelsDecoded=$false
        taskActionsPerformed=@();processActionsPerformed=@();taskOrProcessRestarted=$false;queueOrLedgerMutationPerformed=$false;providerActivated=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;holdsCleared=$false
        reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false
    }
    Write-JsonCreateNew -Path $observationPath -Value $observation -Depth 28
    Write-JsonCreateNew -Path $executionPath -Value ([ordered]@{
        schema='argos_o2a3_direct_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_DIRECT_ADMIN_READ_ONLY_EXECUTION';revision=$revision;requestId=$requestId
        observationState=$observationState;observationSha256=Get-Sha256 $observationPath;processorIdentityUnchanged=$true;imageBytesRead=$false;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }) -Depth 12
    New-LocalResultZip -OutputRoot $outputRoot -ZipPath $localResultPath
    $localResultCreated = $true
    if ([bool]$invocation.injectResponseFailure) { throw 'INJECTED_O2A3_RESPONSE_CONSTRUCTION_FAILURE' }
    $response = New-SignedResponse -Config $endpointConfig -Certificate $certificate -RequestId $requestId -ResultRoot $outputRoot -State 'PASS_O2A3_DIRECT_ADMIN_READ_ONLY_OBSERVATION' -Detail 'O2A3 exact Slot16 installed scribe metadata observation completed without image access or operational mutation.' -QuarantineRoot $responseQuarantineRoot
    $responseCreated = $true
    [ordered]@{
        schema='argos_o2a3_direct_terminal_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_DIRECT_ADMIN_READ_ONLY_OBSERVATION';revision=$revision;requestId=$requestId
        observationState=$observationState;catalogExactRowCount=$catalogRows.Count;proposalPresent=$proposalPresent;readerEvidencePresent=$readerEvidencePresent;declaredMetadataCount=$declaredMetadata.Count
        localResultPath=$localResultPath;localResultSha256=Get-Sha256 $localResultPath;responseId=[string]$response.responseId;responseReadyPath=[string]$response.readyPath;responseManifestSha256=[string]$response.manifestSha256
        processorIdentityUnchanged=$true;imageBytesRead=$false;taskOrProcessRestarted=$false;providerActivated=$false;sourceMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 12
}
catch {
    $detail = $_.Exception.Message
    if (-not (Test-Path -LiteralPath $outputRoot -PathType Container)) { [void](New-Item -ItemType Directory -Path $outputRoot) }
    if (-not (Test-Path -LiteralPath $failurePath)) {
        Write-JsonCreateNew -Path $failurePath -Value ([ordered]@{
            schema='argos_o2a3_direct_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='FAIL_O2A3_DIRECT_ADMIN_READ_ONLY_OBSERVATION';detail=$detail
            imageBytesRead=$false;taskOrProcessRestarted=$false;providerActivated=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
        }) -Depth 10
    }
    if (-not $localResultCreated -and -not (Test-Path -LiteralPath $localResultPath)) {
        try { New-LocalResultZip -OutputRoot $outputRoot -ZipPath $localResultPath; $localResultCreated = $true } catch {}
    }
    if (-not $responseCreated -and -not [bool]$invocation.injectResponseFailure) {
        try {
            [void](New-SignedResponse -Config $endpointConfig -Certificate $certificate -RequestId $requestId -ResultRoot $outputRoot -State 'FAILED' -Detail $detail -QuarantineRoot $responseQuarantineRoot)
            $responseCreated = $true
        }
        catch {}
    }
    Write-Error ("O2A3 failed closed. Local result retained when possible: $localResultPath. Detail: $detail")
    throw
}
