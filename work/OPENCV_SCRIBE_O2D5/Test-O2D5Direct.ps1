#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Test,
    [string]$GatePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Test)) { throw 'Specify exactly one of -Preflight or -Test.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$testRoot = 'C:\O2D5T_54B4C08C'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$entrySource = Join-Path $PSScriptRoot 'Invoke-O2D5Direct.ps1'
$engineSource = Join-Path $project 'work\OPENCV_SCRIBE_V1\ArgosOpenCvScribeV1.py'
$bundleSource = Join-Path $project 'work\OPENCV_SCRIBE_O2D4\final\extract\payload\O2D4_REFS.zip'
$jobTemplate = Join-Path $project 'work\OPENCV_SCRIBE_O2D4\O2D4_REHEARSAL_JOB.json'
$readmeSource = Join-Path $PSScriptRoot 'README_FIRST.txt'
$wrapperSource = Join-Path $PSScriptRoot 'RUN_O2D5.cmd'
$invocationSource = Join-Path $PSScriptRoot 'INVOCATION.json'
$runtimeRoot = Join-Path $project 'work\FIDUCIAL_OPENCV_V1\portable\stage'
$imageSource = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\diagnostics\SCRIBE_READER_FAILURE_DIAGNOSTIC_V1_20260806T201825Z\62631-535_20260730105033_Slot16'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$engineSha = '3CE7E93B9C922B02DE8E8BF712FC715BE24FF7D232B7EC3DDBB86EC7A05273B9'
$bundleSha = '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
$bfSha = '094353365C010DA2C1AB67EBAE1097D3F783E80379BBB585D1F4B531C29EA2EE'
$dfSha = '79232E8A8FAC6634048CFE9EDAFF34467EBF21BEACC55A47E2B3CAA91B82426C'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 20) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2D5 test create-new path exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

function New-RehearsalCase([string]$CaseRoot, [bool]$InjectResponseFailure) {
    $package = Join-Path $CaseRoot 'pkg'
    $inputRoot = Join-Path $CaseRoot 'i'
    $workRoot = Join-Path $CaseRoot 'w'
    $outputRoot = Join-Path $CaseRoot 'o'
    $resultZip = Join-Path $CaseRoot 'r.zip'
    $outbox = Join-Path $CaseRoot 'q'
    $configRoot = Join-Path $CaseRoot 'c'
    foreach ($path in @($CaseRoot,$package,$inputRoot,$outbox,$configRoot)) { if (-not (Test-Path -LiteralPath $path)) { [void](New-Item -ItemType Directory -Path $path) } }
    Copy-Item -LiteralPath (Join-Path $imageSource 'BF_SCRIBE_ORIENTED_DETECTOR_INPUT.png') -Destination (Join-Path $inputRoot 'BF.png')
    Copy-Item -LiteralPath (Join-Path $imageSource 'DF_SCRIBE_ORIENTED_DETECTOR_INPUT.png') -Destination (Join-Path $inputRoot 'DF.png')
    Assert-True ((Get-Sha256 (Join-Path $inputRoot 'BF.png')) -eq $bfSha -and (Get-Sha256 (Join-Path $inputRoot 'DF.png')) -eq $dfSha) 'O2D5 rehearsal images changed.'

    $copyMap = @{
        'Invoke-O2D5Direct.ps1'=$entrySource
        'ArgosOpenCvScribeV1.py'=$engineSource
        'O2D5_REFS.zip'=$bundleSource
        'README_FIRST.txt'=$readmeSource
        'RUN_O2D5.cmd'=$wrapperSource
        'INVOCATION.json'=$invocationSource
    }
    foreach ($name in $copyMap.Keys) { Copy-Item -LiteralPath $copyMap[$name] -Destination (Join-Path $package $name) }

    $job = Get-Content -Raw -LiteralPath $jobTemplate | ConvertFrom-Json
    $job.revision = 'OCV02_SCRIBE_O2D5_REHEARSAL_20260825'
    $job.jobId = 'O2D5_REHEARSAL_' + (Split-Path -Leaf $CaseRoot)
    $job.inputs.bf.path = 'X:\BF.png'; $job.inputs.bf | Add-Member -NotePropertyName relativePath -NotePropertyValue 'BF.png'
    $job.inputs.df.path = 'X:\DF.png'; $job.inputs.df | Add-Member -NotePropertyName relativePath -NotePropertyValue 'DF.png'
    $job.inputs.bf.aliasAnchorCanonicalPath = $inputRoot; $job.inputs.df.aliasAnchorCanonicalPath = $inputRoot
    $job.inputs.bf.canonicalProvenancePath = 'D:\LOCKED_HISTORICAL_REHEARSAL\62631-535\Slot16\BF.png'
    $job.inputs.df.canonicalProvenancePath = 'D:\LOCKED_HISTORICAL_REHEARSAL\62631-535\Slot16\DF.png'
    $job.references.manifestPath = Join-Path $workRoot 'refs\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    $job.references.roots[0].path = Join-Path $workRoot 'refs\glyphs'
    $job.references.roots[1].path = Join-Path $workRoot 'refs\glyphs_v5_confirmed_20260806'
    $job.outputRoot = $outputRoot
    $jobPath = Join-Path $package 'O2D5_SLOT16_JOB.json'
    Write-JsonCreateNew -Path $jobPath -Value $job -Depth 18
    $jobSha = Get-Sha256 $jobPath

    $identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
    $thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
    $certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
    Assert-True ($certificate.HasPrivateKey) 'O2D5 rehearsal signer key is absent.'
    $endpointConfigPath = Join-Path $configRoot 'endpoint.json'
    $senderConfigPath = Join-Path $configRoot 'sender.json'
    $workerPath = Join-Path $configRoot 'worker.ps1'
    $installationPath = Join-Path $configRoot 'installation.json'
    Write-JsonCreateNew -Path $endpointConfigPath -Value ([ordered]@{schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false;responseOutbox=$outbox;stateRoot=(Join-Path $configRoot 'state');endpointSignerThumbprint=$thumbprint;endpointSignerStoreLocation='CurrentUser'}) -Depth 8
    Write-JsonCreateNew -Path $senderConfigPath -Value ([ordered]@{schema='argos_project_portal_transport_config_v1';productionRoutingEnabled=$false;receiver=[ordered]@{enabled=$false};sender=[ordered]@{enabled=$true;watchRoot=$outbox;sentRoot=(Join-Path $CaseRoot 'sent');localBindIp='127.0.0.1';remoteIp='127.0.0.1';port=48717;pollSeconds=2;maxPackageBytes=536870912}}) -Depth 8
    [IO.File]::WriteAllText($workerPath, '# rehearsal worker fixture', (New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($installationPath, '{"rehearsal":true}', (New-Object Text.UTF8Encoding($false)))

    $manifestFiles = @('ArgosOpenCvScribeV1.py','INVOCATION.json','Invoke-O2D5Direct.ps1','O2D5_REFS.zip','O2D5_SLOT16_JOB.json','README_FIRST.txt','RUN_O2D5.cmd')
    $manifest = [ordered]@{schema='argos_o2d5_direct_package_manifest_v1';revision='O2D5_20260825T190855Z_54B4C08C';files=@($manifestFiles | ForEach-Object { $path=Join-Path $package $_; [ordered]@{path=$_;bytes=(Get-Item -LiteralPath $path).Length;sha256=Get-Sha256 $path} });reviewOnly=$true;productionRoutingEnabled=$false}
    Write-JsonCreateNew -Path (Join-Path $package 'PACKAGE_MANIFEST.json') -Value $manifest -Depth 10

    $externalInvocation = [ordered]@{
        schema='argos_o2d5_direct_invocation_v1';revision=('O2D5_REHEARSAL_' + (Split-Path -Leaf $CaseRoot));requestId=('DIRECT_O2D5_REHEARSAL_' + (Split-Path -Leaf $CaseRoot));createdUtc=[DateTime]::UtcNow.ToString('o')
        rehearsal=$true;injectResponseFailure=$InjectResponseFailure;childTimeoutMilliseconds=1800000;minimumDDriveFreeBytes=1
        paths=[ordered]@{runtimeRoot=$runtimeRoot;installationPath=$installationPath;workRoot=$workRoot;outputRoot=$outputRoot;localResultPath=$resultZip;sourceAliasRoot=$inputRoot;endpointConfigPath=$endpointConfigPath;endpointWorkerPath=$workerPath;senderConfigPath=$senderConfigPath}
        sourceAlias=[ordered]@{name='X:'};payload=[ordered]@{engineSha256=$engineSha;referenceBundleSha256=$bundleSha;jobSha256=$jobSha};senderProcessFixture=@([ordered]@{processId=1234;commandLine=$senderConfigPath})
        authority=[ordered]@{reviewOnly=$true;productionRoutingEnabled=$false;taskOrProcessRestartAllowed=$false;providerActivationAllowed=$false;sourceMutationAllowed=$false;sourceDeletionAllowed=$false;holdClearanceAllowed=$false}
    }
    $externalPath = Join-Path $CaseRoot 'INVOCATION_REHEARSAL.json'
    Write-JsonCreateNew -Path $externalPath -Value $externalInvocation -Depth 18
    return [pscustomobject]@{package=$package;entry=(Join-Path $package 'Invoke-O2D5Direct.ps1');invocation=$externalPath;work=$workRoot;output=$outputRoot;zip=$resultZip;outbox=$outbox;certificate=$certificate;inject=$InjectResponseFailure}
}

foreach ($required in @($entrySource,$engineSource,$bundleSource,$jobTemplate,$readmeSource,$wrapperSource,$invocationSource,$windowsPowerShell,(Join-Path $runtimeRoot 'python.exe'),$identityPath)) {
    Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2D5 test dependency is absent: $required"
}
Assert-True ((Get-Sha256 $engineSource) -eq $engineSha -and (Get-Sha256 $bundleSource) -eq $bundleSha) 'O2D5 test payload dependency changed.'
Assert-True (-not (Test-Path -LiteralPath $testRoot)) "O2D5 exact test root is not fresh: $testRoot"
if ($Preflight) {
    [ordered]@{schema='argos_o2d5_direct_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_DIRECT_TEST_PREFLIGHT';testRoot=$testRoot;targetExecuted=$false;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 6
    return
}

Assert-True (-not [string]::IsNullOrWhiteSpace($GatePath)) 'O2D5 test mode requires GatePath.'
$resolvedGate = [IO.Path]::GetFullPath($GatePath)
Assert-True ($resolvedGate.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase) -and -not (Test-Path -LiteralPath $resolvedGate)) 'O2D5 test gate path is unsafe or occupied.'
$caseRows = New-Object Collections.Generic.List[object]
try {
    [void](New-Item -ItemType Directory -Path $testRoot)
    foreach ($case in @([ordered]@{id='SUCCESS';inject=$false},[ordered]@{id='RESPONSE_FAILURE';inject=$true})) {
        $caseRoot = Join-Path $testRoot ([string]$case.id)
        $fixture = New-RehearsalCase -CaseRoot $caseRoot -InjectResponseFailure ([bool]$case.inject)
        $preflightArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$fixture.entry,'-InvocationManifest',$fixture.invocation,'-Preflight','-Rehearsal')
        $preflightText = & $windowsPowerShell @preflightArgs | Out-String
        Assert-True ($LASTEXITCODE -eq 0) "O2D5 rehearsal preflight failed: $($case.id)"
        $preflightResult = $preflightText | ConvertFrom-Json
        Assert-True ([string]$preflightResult.state -eq 'PASS_O2D5_DIRECT_PREFLIGHT' -and -not [bool]$preflightResult.mutationsPerformed -and -not (Test-Path -LiteralPath $fixture.work) -and -not (Test-Path -LiteralPath $fixture.output)) "O2D5 rehearsal preflight mutated or changed: $($case.id)"

        $runArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$fixture.entry,'-InvocationManifest',$fixture.invocation,'-Rehearsal')
        $priorPreference = $ErrorActionPreference
        try { $ErrorActionPreference='Continue'; $runRows=@(& $windowsPowerShell @runArgs 2>&1); $exit=$LASTEXITCODE }
        finally { $ErrorActionPreference=$priorPreference }
        Assert-True (Test-Path -LiteralPath $fixture.zip -PathType Leaf) "O2D5 rehearsal local ZIP missing: $($case.id)"
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $archive = [IO.Compression.ZipFile]::OpenRead($fixture.zip)
        try { $entries = @($archive.Entries | ForEach-Object { $_.FullName } | Sort-Object) }
        finally { $archive.Dispose() }
        Assert-True ($entries -contains 'RESULT.json' -and $entries -contains 'RUN_GATE.json' -and $entries -contains 'EXECUTION.json') ("O2D5 rehearsal ZIP content changed: $($case.id); exit=$exit; entries=" + ($entries -join ',') + '; output=' + ($runRows -join ' | '))
        $ready = @((New-Object IO.DirectoryInfo($fixture.outbox)).EnumerateDirectories('*.ready'))
        if (-not [bool]$case.inject) {
            Assert-True ($exit -eq 0 -and $ready.Count -eq 1) 'O2D5 success case did not create one response.'
            $manifestPath = Join-Path $ready[0].FullName 'PORTAL_RESPONSE_MANIFEST.json'
            $signaturePath = Join-Path $ready[0].FullName 'PORTAL_RESPONSE_MANIFEST.sig'
            $bytes = [IO.File]::ReadAllBytes($manifestPath); $signature = [IO.File]::ReadAllBytes($signaturePath)
            $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($fixture.certificate)
            try { $valid = $rsa.VerifyData($bytes,$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
            finally { $rsa.Dispose() }
            $responseManifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
            Assert-True ($valid -and [string]$responseManifest.state -eq 'PASS_O2D5_DIRECT_ADMIN_SLOT16') 'O2D5 success response signature/state changed.'
        }
        else {
            $runText = $runRows -join [Environment]::NewLine
            Assert-True ($exit -ne 0 -and $runText.Contains('INJECTED_O2D5_RESPONSE_CONSTRUCTION_FAILURE') -and $ready.Count -eq 0) 'O2D5 injected response failure did not fail closed.'
            Assert-True (Test-Path -LiteralPath (Join-Path $fixture.output 'OUTBOUND_FAILURE.json') -PathType Leaf) 'O2D5 injected response failure evidence is absent.'
        }
        $gate = Get-Content -Raw -LiteralPath (Join-Path $fixture.output 'RUN_GATE.json') | ConvertFrom-Json
        Assert-True ([string]$gate.state -eq 'PASS_O2D5_OPENCV_SCRIBE_DEVELOPMENT_EXECUTED' -and [string]$gate.resultState -eq 'SCRIBE_REFERENCE_COVERAGE_HOLD') "O2D5 rehearsal gate changed: $($case.id)"
        Assert-True ([string]$gate.imageFirstString -eq '0438S004FEH0' -and -not [bool]$gate.referenceCoverageComplete -and [string]$gate.missingReferenceLabels -eq 'IJKOQVWXYZ') "O2D5 rehearsal result changed: $($case.id)"
        Assert-True (-not [bool]$gate.taskOrProcessRestarted -and -not [bool]$gate.providerActivated -and -not [bool]$gate.sourceMutationPerformed) "O2D5 rehearsal authority changed: $($case.id)"
        $caseRows.Add([pscustomobject]@{id=[string]$case.id;state='PASS';preflightNonMutating=$true;localResultRetained=$true;signedResponseCreated=($ready.Count -eq 1);injectedResponseFailure=[bool]$case.inject;taskOrProcessRestarted=$false;providerActivated=$false})
    }
    $gateValue = [ordered]@{
        schema='argos_o2d5_direct_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D5_DIRECT_PACKAGE_SHAPED_TEST_GATE';cases=$caseRows.ToArray()
        windowsPowerShell51Passed=$true;exactEngineExecuted=$true;successResponseSignedAndVerified=$true;responseFailureLocalResultRetained=$true;referenceCoverageHoldPreserved=$true
        taskOrProcessRestarted=$false;providerActivated=$false;sourceMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-JsonCreateNew -Path $resolvedGate -Value $gateValue -Depth 12
    $gateValue | ConvertTo-Json -Depth 12
}
finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    if ($resolvedTestRoot -eq 'C:\O2D5T_54B4C08C' -and (Test-Path -LiteralPath $resolvedTestRoot -PathType Container)) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
