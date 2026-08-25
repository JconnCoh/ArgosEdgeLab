#Requires -Version 5.1
[CmdletBinding()]
param(
    [string]$InvocationManifest = (Join-Path $PSScriptRoot 'INVOCATION.json'),
    [switch]$Preflight,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$liveRevision = 'O2D5_20260825T190855Z_54B4C08C'
$liveRequestId = 'DIRECT_O2D5_20260825T190855Z_54B4C08C'
$engineSha = '3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'
$referenceBundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$liveJobSha = 'C05B48D1FFF96B28BC6D5C3393FB7E1F8F84844DA92DAF90FC04F983BA5C2A98'
$installationSha = '1289EC11F092233D3AAB5ACF416B0212F1874F698F9BBC2B474829939BCDF596'
$endpointConfigSha = '55A106E8F29F89C99CC51DACAA1466C0E076AB1DE40AAEB2E5638EFC4F02DE1F'
$endpointWorkerSha = 'CB6700714E20DAC2D3C097095A2800C92ECAAC75F29878F4C86326493B246250'
$senderConfigSha = '8420A302D0EE0665E9E034448A245613C6AD5E7EE2D82BF0E7F962A7F7B104E0'
$liveBfSha = 'CE5502F33D54A12FEF1A082A0B18C1635169B2F5D0BE98C402EA8238D86C2E53'
$liveDfSha = '6FAC812536C19F07D1C3DAD5263741350E94460A07867F2AEE0D2EEEA8C19ED9'

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-', '') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}

function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 18) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D5 create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

function Assert-PathBudget([string]$Path, [int]$Reserve = 32) {
    $full = [IO.Path]::GetFullPath($Path)
    $components = @($full.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
    $longest = if ($components.Count -eq 0) { 0 } else { [int](($components | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) }
    Assert-True (($full.Length + $Reserve) -lt 200) "O2D5 unsafe effective path length: $full"
    Assert-True ($longest -le 80) "O2D5 unsafe path component: $full"
}

function Assert-PackageFiles([object]$Manifest) {
    Assert-True ([string]$Manifest.schema -eq 'argos_o2d5_direct_package_manifest_v1') 'O2D5 package manifest schema changed.'
    Assert-True ([string]$Manifest.revision -eq $liveRevision) 'O2D5 package manifest revision changed.'
    $expected = @('ArgosOpenCvScribeV1.py','INVOCATION.json','Invoke-O2D5Direct.ps1','O2D5_REFS.zip','O2D5_SLOT16_JOB.json','README_FIRST.txt','RUN_O2D5.cmd')
    $records = @($Manifest.files)
    Assert-True ($records.Count -eq $expected.Count) 'O2D5 package manifest file count changed.'
    $names = @($records | ForEach-Object { [string]$_.path } | Sort-Object)
    Assert-True (@(Compare-Object -ReferenceObject $expected -DifferenceObject $names).Count -eq 0) 'O2D5 package manifest file set changed.'
    foreach ($record in $records) {
        $path = Join-Path $PSScriptRoot ([string]$record.path)
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D5 package file is absent: $($record.path)"
        Assert-True ((Get-Item -LiteralPath $path).Length -eq [int64]$record.bytes) "O2D5 package file bytes changed: $($record.path)"
        Assert-True ((Get-Sha256 $path) -eq [string]$record.sha256) "O2D5 package file hash changed: $($record.path)"
    }
}

function Invoke-BoundedPython([string]$Python, [string]$Engine, [string]$Job, [string]$Result, [int]$TimeoutMs) {
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Python
    $startInfo.Arguments = '"' + $Engine + '" --job "' + $Job + '" --result "' + $Result + '"'
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-True ($process.Start()) 'O2D5 Python did not start.'
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutMs)) {
        try { $process.Kill() } catch {}
        throw "O2D5 Python exceeded $TimeoutMs milliseconds."
    }
    $value = [pscustomobject]@{exitCode=$process.ExitCode;stdout=$stdoutTask.Result;stderr=$stderrTask.Result}
    $process.Dispose()
    return $value
}

function Get-Signer([object]$Config) {
    $thumbprint = ([string]$Config.endpointSignerThumbprint).Replace(' ', '').ToUpperInvariant()
    $location = [string]$Config.endpointSignerStoreLocation
    Assert-True ($location -in @('CurrentUser','LocalMachine')) 'O2D5 signer store location changed.'
    $certificate = Get-Item -LiteralPath ("Cert:\$location\My\$thumbprint") -ErrorAction Stop
    Assert-True ([bool]$certificate.HasPrivateKey) 'O2D5 signer private key is unavailable.'
    return $certificate
}

function Test-Signer([object]$Certificate) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes('O2D5_NON_MUTATING_SIGNER_ACCESS_TEST')
    $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($Certificate)
    Assert-True ($null -ne $rsa) 'O2D5 signer RSA private key is unavailable.'
    try {
        $signature = $rsa.SignData($bytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
        Assert-True ($rsa.VerifyData($bytes, $signature, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)) 'O2D5 signer access test did not verify.'
    }
    finally { $rsa.Dispose() }
}

function New-LocalResultZip([string]$OutputRoot, [string]$ZipPath) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $partial = $ZipPath + '.partial'
    Assert-True (-not (Test-Path -LiteralPath $partial) -and -not (Test-Path -LiteralPath $ZipPath)) 'O2D5 local result path is not fresh.'
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
    Assert-True (-not (Test-Path -LiteralPath $partial) -and -not (Test-Path -LiteralPath $ready)) 'O2D5 response package collision.'
    try {
        [void](New-Item -ItemType Directory -Path $partial)
        $sourceRoot = [IO.Path]::GetFullPath($ResultRoot).TrimEnd('\')
        foreach ($file in @((New-Object IO.DirectoryInfo($sourceRoot)).EnumerateFiles('*', [IO.SearchOption]::AllDirectories))) {
            $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\')
            Assert-True (-not $relative.Contains('..')) 'O2D5 response relative path changed.'
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
                Assert-True (-not (Test-Path -LiteralPath $failed)) 'O2D5 response quarantine collision.'
                Move-Item -LiteralPath $partial -Destination $failed -ErrorAction Stop
            }
            catch {}
        }
        throw $responseError
    }
}

Assert-True (Test-Path -LiteralPath $InvocationManifest -PathType Leaf) 'O2D5 invocation manifest is absent.'
$invocation = Get-Content -Raw -LiteralPath $InvocationManifest | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d5_direct_invocation_v1') 'O2D5 invocation schema changed.'
Assert-True ([bool]$invocation.rehearsal -eq [bool]$Rehearsal) 'O2D5 rehearsal switch and invocation disagree.'
Assert-True (-not [bool]$invocation.authority.productionRoutingEnabled -and [bool]$invocation.authority.reviewOnly) 'O2D5 authority changed.'
Assert-True (-not [bool]$invocation.authority.taskOrProcessRestartAllowed -and -not [bool]$invocation.authority.providerActivationAllowed -and -not [bool]$invocation.authority.sourceMutationAllowed) 'O2D5 prohibited authority changed.'
if (-not $Rehearsal) {
    Assert-True ([string]$invocation.revision -eq $liveRevision -and [string]$invocation.requestId -eq $liveRequestId) 'O2D5 live identity changed.'
    Assert-True ($env:COMPUTERNAME -eq 'A1025645101') "O2D5 refuses this computer: $($env:COMPUTERNAME)"
}

$packageManifestPath = Join-Path $PSScriptRoot 'PACKAGE_MANIFEST.json'
Assert-True (Test-Path -LiteralPath $packageManifestPath -PathType Leaf) 'O2D5 package manifest is absent.'
$packageManifest = Get-Content -Raw -LiteralPath $packageManifestPath | ConvertFrom-Json
Assert-PackageFiles $packageManifest

$revision = [string]$invocation.revision
$requestId = [string]$invocation.requestId
$runtimeRoot = [string]$invocation.paths.runtimeRoot
$workRoot = [string]$invocation.paths.workRoot
$partialWorkRoot = $workRoot + '.partial'
$failedWorkRoot = $workRoot + '.failed'
$outputRoot = [string]$invocation.paths.outputRoot
$localResultPath = [string]$invocation.paths.localResultPath
$sourceAliasRoot = [string]$invocation.paths.sourceAliasRoot
$endpointConfigPath = [string]$invocation.paths.endpointConfigPath
$endpointWorkerPath = [string]$invocation.paths.endpointWorkerPath
$senderConfigPath = [string]$invocation.paths.senderConfigPath
$installationPath = [string]$invocation.paths.installationPath
$python = Join-Path $runtimeRoot 'python.exe'
$subst = Join-Path $env:SystemRoot 'System32\subst.exe'
$engineSource = Join-Path $PSScriptRoot 'ArgosOpenCvScribeV1.py'
$bundleSource = Join-Path $PSScriptRoot 'O2D5_REFS.zip'
$jobSource = Join-Path $PSScriptRoot 'O2D5_SLOT16_JOB.json'
$resultPath = Join-Path $outputRoot 'RESULT.json'
$gatePath = Join-Path $outputRoot 'RUN_GATE.json'
$executionPath = Join-Path $outputRoot 'EXECUTION.json'
$failurePath = Join-Path $outputRoot 'FAILURE.json'
$outboundFailurePath = Join-Path $outputRoot 'OUTBOUND_FAILURE.json'
$responseQuarantineRoot = Join-Path $outputRoot 'response_quarantine'
$aliasName = [string]$invocation.sourceAlias.name
$aliasPath = $aliasName + '\'
$jobExpectedSha = [string]$invocation.payload.jobSha256

foreach ($path in @($workRoot,$partialWorkRoot,$failedWorkRoot,$outputRoot,$localResultPath,($localResultPath + '.partial'),$resultPath,$gatePath,$executionPath)) { Assert-PathBudget $path 32 }
foreach ($path in @($engineSource,$bundleSource,$jobSource,$installationPath,$endpointConfigPath,$endpointWorkerPath,$senderConfigPath,$python,$subst)) {
    Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "O2D5 required file is absent: $path"
}
Assert-True ((Get-Sha256 $engineSource) -eq $engineSha) 'O2D5 engine changed.'
Assert-True ((Get-Sha256 $bundleSource) -eq $referenceBundleSha) 'O2D5 reference bundle changed.'
Assert-True ((Get-Sha256 $jobSource) -eq $jobExpectedSha) 'O2D5 job changed.'

if (-not $Rehearsal) {
    Assert-True ($revision -eq $liveRevision -and $requestId -eq $liveRequestId) 'O2D5 live identity changed.'
    Assert-True ($jobExpectedSha -eq $liveJobSha) 'O2D5 live job pin changed.'
    Assert-True ($env:COMPUTERNAME -eq 'A1025645101') "O2D5 refuses this computer: $($env:COMPUTERNAME)"
    Assert-True ($runtimeRoot -eq 'D:\AFCV1\rt') 'O2D5 live runtime root changed.'
    Assert-True ($workRoot -eq 'D:\A2\w\ocv\O2D5_20260825T190855Z_54B4C08C') 'O2D5 live work root changed.'
    Assert-True ($outputRoot -eq 'D:\A2\o\ocv\O2D5_20260825T190855Z_54B4C08C') 'O2D5 live output root changed.'
    Assert-True ($localResultPath -eq 'D:\A2\x\O2D5R_20260825T190855Z_54B4C08C.zip') 'O2D5 live result path changed.'
    Assert-True ($sourceAliasRoot -eq 'D:\KLARFExport\PatternedFront\Lot_62619-433') 'O2D5 live source root changed.'
    Assert-True ((Get-Sha256 $installationPath) -eq $installationSha) 'O2D5 runtime installation changed.'
    Assert-True ((Get-Sha256 $endpointConfigPath) -eq $endpointConfigSha) 'O2D5 endpoint config changed.'
    Assert-True ((Get-Sha256 $endpointWorkerPath) -eq $endpointWorkerSha) 'O2D5 endpoint worker changed.'
    Assert-True ((Get-Sha256 $senderConfigPath) -eq $senderConfigSha) 'O2D5 sender config changed.'
}

$endpointConfig = Get-Content -Raw -LiteralPath $endpointConfigPath | ConvertFrom-Json
$senderConfig = Get-Content -Raw -LiteralPath $senderConfigPath | ConvertFrom-Json
Assert-True ([string]$endpointConfig.schema -eq 'argos_project_portal_endpoint_config_v1' -and [string]$endpointConfig.role -eq 'JBOD') 'O2D5 endpoint config schema/role changed.'
Assert-True (-not [bool]$endpointConfig.productionRoutingEnabled -and [string]$endpointConfig.responseOutbox -eq [string]$senderConfig.sender.watchRoot) 'O2D5 response outbox contract changed.'
Assert-True ([bool]$senderConfig.sender.enabled -and -not [bool]$senderConfig.receiver.enabled -and [int]$senderConfig.sender.port -eq 48717) 'O2D5 sender transport contract changed.'
Assert-True (Test-Path -LiteralPath ([string]$endpointConfig.responseOutbox) -PathType Container) 'O2D5 response outbox is absent.'
Assert-PathBudget ([string]$endpointConfig.responseOutbox) 96

$certificate = Get-Signer $endpointConfig
Test-Signer $certificate
$pythonCommand = Get-Command -Name $python -CommandType Application -ErrorAction Stop
$substCommand = Get-Command -Name $subst -CommandType Application -ErrorAction Stop
Assert-True ([IO.Path]::GetFullPath($pythonCommand.Source).Equals([IO.Path]::GetFullPath($python), [StringComparison]::OrdinalIgnoreCase)) 'O2D5 Python resolution changed.'
Assert-True ([IO.Path]::GetFullPath($substCommand.Source).Equals([IO.Path]::GetFullPath($subst), [StringComparison]::OrdinalIgnoreCase)) 'O2D5 subst resolution changed.'
Assert-True (Test-Path -LiteralPath $sourceAliasRoot -PathType Container) 'O2D5 source alias root is absent.'
Assert-True (-not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name $aliasName.TrimEnd(':') -ErrorAction SilentlyContinue)) 'O2D5 X: is already in use.'

$job = Get-Content -Raw -LiteralPath $jobSource | ConvertFrom-Json
Assert-True ([string]$job.schema -eq 'argos_opencv_scribe_job_v1' -and [bool]$job.authority.reviewOnly -and -not [bool]$job.authority.automaticIdentityAuthority -and -not [bool]$job.authority.productionEligible -and -not [bool]$job.authority.mayClearHolds) 'O2D5 job authority changed.'
Assert-True ([string]$job.outputRoot -eq $outputRoot) 'O2D5 job output root changed.'
foreach ($channel in @('bf','df')) {
    $source = $job.inputs.$channel
    Assert-True ([string]$source.ioPathClass -eq 'SHORT_DOS_DEVICE_ALIAS' -and [string]$source.aliasName -eq $aliasName -and [string]$source.aliasAnchorCanonicalPath -eq $sourceAliasRoot) "O2D5 source alias contract changed: $channel"
    Assert-True ([string]$source.path -eq ($aliasPath + [string]$source.relativePath)) "O2D5 source relative path changed: $channel"
    $canonical = [string]$source.canonicalProvenancePath
    if ($Rehearsal) { Assert-True ($canonical.StartsWith('D:\', [StringComparison]::OrdinalIgnoreCase)) "O2D5 rehearsal canonical provenance is not JBOD-shaped: $channel" }
    else { Assert-True ($canonical.StartsWith($sourceAliasRoot + '\', [StringComparison]::OrdinalIgnoreCase)) "O2D5 canonical source escaped root: $channel" }
    $physicalSource = Join-Path $sourceAliasRoot ([string]$source.relativePath)
    Assert-True (Test-Path -LiteralPath $physicalSource -PathType Leaf) "O2D5 source is absent: $channel"
    Assert-True ((Get-Item -LiteralPath $physicalSource).Length -eq [int64]$source.bytes) "O2D5 source bytes changed: $channel"
    Assert-True ((Get-Sha256 $physicalSource) -eq [string]$source.sha256) "O2D5 source hash changed: $channel"
}
if (-not $Rehearsal) {
    Assert-True ([string]$job.identity.lotId -eq '62619-433' -and [string]$job.identity.slotId -eq 'Slot16') 'O2D5 live identity contract changed.'
    Assert-True ([string]$job.inputs.bf.sha256 -eq $liveBfSha -and [string]$job.inputs.df.sha256 -eq $liveDfSha) 'O2D5 live source hash contract changed.'
}

$senderRows = @(if ($Rehearsal) { @($invocation.senderProcessFixture) } else {
    @(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object {
        $null -ne $_.CommandLine -and $_.CommandLine.IndexOf($senderConfigPath, [StringComparison]::OrdinalIgnoreCase) -ge 0
    } | Select-Object -First 4)
})
Assert-True ($senderRows.Count -eq 1) "O2D5 response-sender process cardinality changed: $($senderRows.Count)"
foreach ($target in @($workRoot,$partialWorkRoot,$failedWorkRoot,$outputRoot,$localResultPath,($localResultPath + '.partial'))) {
    Assert-True (-not (Test-Path -LiteralPath $target)) "O2D5 create-new target exists: $target"
}
if (-not $Rehearsal) {
    $d = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='D:'" -ErrorAction Stop
    Assert-True ($null -ne $d -and [int64]$d.FreeSpace -ge [int64]$invocation.minimumDDriveFreeBytes) 'O2D5 D free-space floor failed.'
}

if ($Preflight) {
    [ordered]@{
        schema='argos_o2d5_direct_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_DIRECT_PREFLIGHT';revision=$revision;requestId=$requestId
        rehearsal=[bool]$Rehearsal;computerName=$env:COMPUTERNAME;engineSha256=$engineSha;referenceBundleSha256=$referenceBundleSha;jobSha256=$jobExpectedSha
        bfSha256=[string]$job.inputs.bf.sha256;dfSha256=[string]$job.inputs.df.sha256;sourceImageBytesRead=$true;pixelsDecoded=$false
        signerThumbprint=$certificate.Thumbprint.Replace(' ','').ToUpperInvariant();signerAccessVerified=$true;senderProcessCount=$senderRows.Count
        workRoot=$workRoot;outputRoot=$outputRoot;localResultPath=$localResultPath;targetExecuted=$false;mutationsPerformed=$false
        taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 8
    return
}

$aliasCreated = $false
$engineCompleted = $false
$engineFailureDetail = ''
$localResultCreated = $false
$responseCreated = $false
$response = $null
try {
    [void](New-Item -ItemType Directory -Path $partialWorkRoot)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::ExtractToDirectory($bundleSource, $partialWorkRoot)
    Copy-Item -LiteralPath $engineSource -Destination (Join-Path $partialWorkRoot 'ArgosOpenCvScribeV1.py')
    Copy-Item -LiteralPath $jobSource -Destination (Join-Path $partialWorkRoot 'JOB.json')
    Assert-True ((Get-Sha256 (Join-Path $partialWorkRoot 'ArgosOpenCvScribeV1.py')) -eq $engineSha) 'O2D5 staged engine changed.'
    Assert-True ((Get-Sha256 (Join-Path $partialWorkRoot 'JOB.json')) -eq $jobExpectedSha) 'O2D5 staged job changed.'
    Move-Item -LiteralPath $partialWorkRoot -Destination $workRoot -ErrorAction Stop
    [void](New-Item -ItemType Directory -Path $outputRoot)

    $aliasOutput = & $subst $aliasName $sourceAliasRoot 2>&1 | Out-String
    Assert-True ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $aliasPath -PathType Container)) ('O2D5 alias creation failed: ' + $aliasOutput.Trim())
    $aliasCreated = $true
    $mappings = & $subst 2>&1 | Out-String
    $matching = @(($mappings -split '\r?\n') | Where-Object { $_ -match '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$' })
    Assert-True ($matching.Count -eq 1) 'O2D5 alias mapping cardinality changed.'
    $target = [regex]::Match($matching[0], '(?i)^\s*X:\\:\s*=>\s*(.+?)\s*$').Groups[1].Value.Trim().TrimEnd('\')
    Assert-True ($target.Equals($sourceAliasRoot.TrimEnd('\'), [StringComparison]::OrdinalIgnoreCase)) 'O2D5 alias target changed.'

    $enginePath = Join-Path $workRoot 'ArgosOpenCvScribeV1.py'
    $jobPath = Join-Path $workRoot 'JOB.json'
    $run = Invoke-BoundedPython -Python $python -Engine $enginePath -Job $jobPath -Result $resultPath -TimeoutMs ([int]$invocation.childTimeoutMilliseconds)
    Assert-True ($run.exitCode -eq 0) ('O2D5 provider failed with exit ' + $run.exitCode + ': ' + $run.stderr.Trim())
    Assert-True (Test-Path -LiteralPath $resultPath -PathType Leaf) 'O2D5 result is absent.'
    $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    Assert-True ([string]$result.schema -eq 'argos_opencv_scribe_result_v1' -and [string]$result.revision -eq 'ARGOS_OPENCV_SCRIBE_V1R2_20260824') 'O2D5 result schema/revision changed.'
    Assert-True (-not [bool]$result.eligibleIdentity -and [bool]$result.authority.reviewOnly -and -not [bool]$result.authority.automaticIdentityAuthority -and -not [bool]$result.authority.productionEligible -and -not [bool]$result.authority.mayClearHolds) 'O2D5 result authority changed.'
    foreach ($channel in @('bf','df')) {
        $evidence = $result.provenance.sources.$channel
        Assert-True ([string]$evidence.sha256 -eq [string]$job.inputs.$channel.sha256) "O2D5 result source hash changed: $channel"
        Assert-True ([string]$evidence.canonicalProvenancePath -eq [string]$job.inputs.$channel.canonicalProvenancePath) "O2D5 result canonical provenance changed: $channel"
    }
    Assert-True ([int]$result.provenance.references.referenceCount -eq 456 -and [string]$result.provenance.references.missingBodyReferenceLabels -eq 'IJKOQVWXYZ') 'O2D5 reference provenance changed.'
    Assert-True ([bool]$result.provenance.bfDfIndependent -and [bool]$result.provenance.boundedExceptionSearchUsed -and -not [bool]$result.provenance.fixedImageRectangleUsed) 'O2D5 processing provenance changed.'
    $engineCompleted = $true
}
catch {
    $engineFailureDetail = $_.Exception.Message
}
finally {
    if ($aliasCreated) {
        $removeOutput = & $subst $aliasName '/D' 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            $aliasFailure = 'O2D5 alias removal failed: ' + $removeOutput.Trim()
            $engineFailureDetail = if ([string]::IsNullOrWhiteSpace($engineFailureDetail)) { $aliasFailure } else { $engineFailureDetail + '; ' + $aliasFailure }
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($engineFailureDetail)) {
    if (-not (Test-Path -LiteralPath $outputRoot -PathType Container)) { [void](New-Item -ItemType Directory -Path $outputRoot) }
    Write-JsonCreateNew -Path $failurePath -Value ([ordered]@{
        schema='argos_o2d5_direct_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_O2D5_DIRECT_EXECUTION_FAILURE';detail=$engineFailureDetail
        sourceAliasRemoved=(-not (Test-Path -LiteralPath $aliasPath));taskOrProcessRestarted=$false;sourceMutationPerformed=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }) -Depth 8
    try { New-LocalResultZip -OutputRoot $outputRoot -ZipPath $localResultPath; $localResultCreated = $true } catch {}
    if (-not [bool]$invocation.injectResponseFailure) {
        try {
            $failureResponse = New-SignedResponse -Config $endpointConfig -Certificate $certificate -RequestId $requestId -ResultRoot $outputRoot -State 'FAILED' -Detail $engineFailureDetail -QuarantineRoot $responseQuarantineRoot
            $responseCreated = $true
        }
        catch {}
    }
    Write-Error ("O2D5 failed closed. Local result retained: $localResultPath. Detail: $engineFailureDetail")
    throw $engineFailureDetail
}

try {
    Assert-True ($engineCompleted) 'O2D5 engine did not complete.'
    Assert-True (-not (Test-Path -LiteralPath $aliasPath) -and $null -eq (Get-PSDrive -Name $aliasName.TrimEnd(':') -ErrorAction SilentlyContinue)) 'O2D5 alias remains after provider exit.'
    $result = Get-Content -Raw -LiteralPath $resultPath | ConvertFrom-Json
    $gate = [ordered]@{
        schema='argos_o2d5_opencv_scribe_development_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED';disposition='PENDING_GATE'
        revision=$revision;requestId=$requestId;lotId=[string]$job.identity.lotId;acquisitionId=[string]$job.identity.acquisitionId;slotId=[string]$job.identity.slotId
        engineSha256=$engineSha;jobSha256=$jobExpectedSha;referenceBundleSha256=$referenceBundleSha;resultSha256=Get-Sha256 $resultPath;resultState=[string]$result.state
        imageFirstString=[string]$result.imageFirstString;checksumState=[string]$result.checksumState;localization=$result.localization;candidates=@($result.candidates);holds=@($result.holds)
        sourceAliasName=$aliasName;sourceAliasRoot=$sourceAliasRoot;sourceAliasCreated=$true;sourceAliasTargetVerified=$true;sourceAliasRemoved=$true
        inputProvenance=$result.provenance.sources;referenceCoverageComplete=[bool]$result.provenance.references.referenceCoverageComplete;missingReferenceLabels=[string]$result.provenance.references.missingBodyReferenceLabels
        inspectionTasksChanged=$false;processorTaskChanged=$false;taskOrProcessRestarted=$false;sourceMutationPerformed=$false;sourceDeletionPerformed=$false;waferActionPerformed=$false
        holdsCleared=$false;providerActivated=$false;reviewOnly=$true;productionEligible=$false
    }
    Write-JsonCreateNew -Path $gatePath -Value $gate -Depth 16
    Write-JsonCreateNew -Path $executionPath -Value ([ordered]@{
        schema='argos_o2d5_direct_execution_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_DIRECT_EXECUTION';revision=$revision;requestId=$requestId
        computerName=$env:COMPUTERNAME;workRoot=$workRoot;outputRoot=$outputRoot;resultSha256=Get-Sha256 $resultPath;gateSha256=Get-Sha256 $gatePath
        sourceImageBytesRead=$true;pixelsDecodedByOpenCv=$true;taskOrProcessRestarted=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }) -Depth 10
    New-LocalResultZip -OutputRoot $outputRoot -ZipPath $localResultPath
    $localResultCreated = $true
    if ([bool]$invocation.injectResponseFailure) { throw 'INJECTED_O2D5_RESPONSE_CONSTRUCTION_FAILURE' }
    $response = New-SignedResponse -Config $endpointConfig -Certificate $certificate -RequestId $requestId -ResultRoot $outputRoot -State 'PASS_O2D5_DIRECT_ADMIN_SLOT16' -Detail 'O2D5 Slot16 development result completed under review-only authority.' -QuarantineRoot $responseQuarantineRoot
    $responseCreated = $true
    [ordered]@{
        schema='argos_o2d5_direct_terminal_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_DIRECT_ADMIN_SLOT16';revision=$revision;requestId=$requestId
        resultState=[string]$result.state;imageFirstString=[string]$result.imageFirstString;checksumState=[string]$result.checksumState;localResultPath=$localResultPath;localResultSha256=Get-Sha256 $localResultPath
        responseId=[string]$response.responseId;responseReadyPath=[string]$response.readyPath;responseManifestSha256=[string]$response.manifestSha256
        taskOrProcessRestarted=$false;providerActivated=$false;sourceMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 12
}
catch {
    $detail = $_.Exception.Message
    if (-not (Test-Path -LiteralPath $outputRoot -PathType Container)) { [void](New-Item -ItemType Directory -Path $outputRoot) }
    if ($engineCompleted) {
        if (-not (Test-Path -LiteralPath $outboundFailurePath)) {
            Write-JsonCreateNew -Path $outboundFailurePath -Value ([ordered]@{schema='argos_o2d5_outbound_failure_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='HOLD_O2D5_OUTBOUND_RETURN_FAILURE';detail=$detail;localResultCreated=$localResultCreated;taskOrProcessRestarted=$false;reviewOnly=$true;productionRoutingEnabled=$false}) -Depth 8
        }
    }
    else { throw 'O2D5 internal engine terminal-state inconsistency.' }
    if (-not $localResultCreated -and -not (Test-Path -LiteralPath $localResultPath)) {
        try { New-LocalResultZip -OutputRoot $outputRoot -ZipPath $localResultPath; $localResultCreated = $true } catch {}
    }
    if (-not $responseCreated -and -not [bool]$invocation.injectResponseFailure) {
        try {
            $failureResponse = New-SignedResponse -Config $endpointConfig -Certificate $certificate -RequestId $requestId -ResultRoot $outputRoot -State 'FAILED' -Detail $detail -QuarantineRoot $responseQuarantineRoot
            $responseCreated = $true
        }
        catch {}
    }
    Write-Error ("O2D5 failed closed. Local result retained: $localResultPath. Detail: $detail")
    throw
}
