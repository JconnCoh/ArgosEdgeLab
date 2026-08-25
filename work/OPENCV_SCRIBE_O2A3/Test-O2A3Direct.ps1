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
$sourceRoot = Join-Path $PSScriptRoot 'pkg'
$testRoot = 'C:\O2A3T_195521'
$windowsPowerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
function Write-JsonCreateNew([string]$Path, [object]$Value, [int]$Depth = 24) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2A3 test create-new JSON exists: $Path"
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}
function Write-TextCreateNew([string]$Path, [string]$Text) {
    Assert-True (-not (Test-Path -LiteralPath $Path)) "O2A3 test create-new text exists: $Path"
    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { [void](New-Item -ItemType Directory -Path $parent -Force) }
    [IO.File]::WriteAllText($Path, $Text, (New-Object Text.UTF8Encoding($false)))
}

function New-RehearsalCase([string]$CaseRoot, [string]$CaseId, [bool]$IncludeSummary, [bool]$IncludeHold, [bool]$IncludeProposal, [bool]$InjectResponseFailure) {
    $package = Join-Path $CaseRoot 'pkg'
    $state = Join-Path $CaseRoot 's'
    $config = Join-Path $CaseRoot 'c'
    $outbox = Join-Path $CaseRoot 'q'
    $output = Join-Path $CaseRoot 'o'
    $resultZip = Join-Path $CaseRoot 'r.zip'
    foreach ($path in @($package,$state,$config,$outbox)) { [void](New-Item -ItemType Directory -Path $path -Force) }

    foreach ($leaf in @('Invoke-O2A3Direct.ps1','RUN_O2A3.cmd','README_FIRST.txt')) {
        Copy-Item -LiteralPath (Join-Path $sourceRoot $leaf) -Destination (Join-Path $package $leaf) -ErrorAction Stop
    }

    $identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
    $thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
    $certificate = Get-Item -LiteralPath ("Cert:\CurrentUser\My\$thumbprint") -ErrorAction Stop
    Assert-True ([bool]$certificate.HasPrivateKey) 'O2A3 rehearsal signer key is absent.'

    $processorConfigPath = Join-Path $config 'processor.json'
    $endpointConfigPath = Join-Path $config 'endpoint.json'
    $senderConfigPath = Join-Path $config 'sender.json'
    Write-JsonCreateNew -Path $processorConfigPath -Value ([ordered]@{
        schema='argos_jbod_all_wafer_processor_config_v3';stateRoot=$state;automaticScribeProposalEnabled=$true;reviewOnly=$true;xmlExportEnabled=$false;productionEligible=$false
    })
    Write-JsonCreateNew -Path $endpointConfigPath -Value ([ordered]@{
        schema='argos_project_portal_endpoint_config_v1';role='JBOD';reviewOnly=$true;productionRoutingEnabled=$false;responseOutbox=$outbox;endpointSignerThumbprint=$thumbprint;endpointSignerStoreLocation='CurrentUser'
    })
    Write-JsonCreateNew -Path $senderConfigPath -Value ([ordered]@{
        schema='argos_project_portal_transport_config_v1';productionRoutingEnabled=$false;receiver=[ordered]@{enabled=$false};sender=[ordered]@{enabled=$true;watchRoot=$outbox;sentRoot=(Join-Path $CaseRoot 'sent');port=48717}
    })

    $dependencyRelativePaths = [ordered]@{
        processorRunner='Run-JbodAllWaferProcessor.ps1'
        scribeProposalPass='Invoke-JbodScribeProposalPass.ps1'
        multiChannelReader='runtime\scribe\Invoke-ScribeMultiChannelPolarityReader.ps1'
        polarityVariants='runtime\scribe\ScribeChannelPolarityVariants.cs'
        imageReader='runtime\scribe\SemiM12DotMatrixImageReader.cs'
        referenceManifest='runtime\scribe\references\PORTABLE_GLYPH_REFERENCE_MANIFEST.json'
    }
    foreach ($name in @($dependencyRelativePaths.Keys)) {
        $text = if ($name -eq 'scribeProposalPass') {
            'identity\proposals SCRIBE_PROPOSAL.json runtime\scribe Invoke-ScribeMultiChannelPolarityReader.ps1 MULTI_CHANNEL_READER_SUMMARY.json MULTI_CHANNEL_READER_HOLD.json'
        } elseif ($name -eq 'referenceManifest') {
            '{"schema":"fixture_reference_manifest","referenceCount":456,"missingLabels":"IJKOQVWXYZ"}'
        } else {
            '# O2A3 rehearsal dependency ' + $name
        }
        Write-TextCreateNew -Path (Join-Path $state ([string]$dependencyRelativePaths[$name])) -Text $text
    }

    $catalogPath = Join-Path $state 'catalog\ALL_WAFER_CATALOG.json'
    Write-JsonCreateNew -Path $catalogPath -Value ([ordered]@{
        schema='fixture_catalog';acquisitions=@([ordered]@{
            lot='62619-433';scanTimestampLocal='2026-08-24T00:57:35';slot='Slot16';domain='FRONTSIDE';identity='62619-433_20260824005735_Slot16__FRONTSIDE';physicalIdentity='62619-433_20260824005735_Slot16';routeState='HOLD_SCRIBE_CONFIRMATION_REQUIRED_BEFORE_DETECTOR'
        });reviewOnly=$true
    })

    $imagePath = Join-Path $CaseRoot 'locked_fixture.bmp'
    Write-TextCreateNew -Path $imagePath -Text 'O2A3 fixture image bytes must never be read.'
    $proposalRoot = Join-Path $state 'identity\proposals\62619-433_20260824005735_Slot16'
    if ($IncludeProposal) {
        Write-JsonCreateNew -Path (Join-Path $proposalRoot 'SCRIBE_PROPOSAL.json') -Value ([ordered]@{
            schema='fixture_proposal';state='SCRIBE_IMAGE_FIRST_CONFIRMATION_REQUIRED';proposal='0737S016FEF5';imagePath=$imagePath;crop=[ordered]@{left=120;top=240;width=640;height=220};reviewOnly=$true
        })
    }
    if ($IncludeSummary) {
        Write-JsonCreateNew -Path (Join-Path $proposalRoot 'scribe\multi_channel\MULTI_CHANNEL_READER_SUMMARY.json') -Value ([ordered]@{
            schema='fixture_summary';state='SCRIBE_M12_CANDIDATES_REQUIRE_EXACT_MES_VERIFICATION';consensusState='MULTIPLE_IMAGE_SUPPORTED_M12_CANDIDATES';candidateCount=3;uniqueImageCandidate='';sourceImagePath=$imagePath;channel='BF';region=[ordered]@{x=120;y=240;width=640;height=220};candidates=@('0737S016FEF5','0737S016FEG6')
        })
    }
    if ($IncludeHold) {
        Write-JsonCreateNew -Path (Join-Path $proposalRoot 'scribe\multi_channel\MULTI_CHANNEL_READER_HOLD.json') -Value ([ordered]@{
            schema='fixture_hold';state='SCRIBE_REFERENCE_COVERAGE_HOLD';detail='fixture';sourceImagePath=$imagePath;orientationDegrees=90
        })
    }

    $dependencyPins = [ordered]@{}
    foreach ($name in @($dependencyRelativePaths.Keys)) { $dependencyPins[$name] = Get-Sha256 (Join-Path $state ([string]$dependencyRelativePaths[$name])) }
    $revision = 'O2A3_REHEARSAL_' + $CaseId
    $requestId = 'DIRECT_O2A3_REHEARSAL_' + $CaseId
    $invocation = [ordered]@{
        schema='argos_o2a3_direct_invocation_v1';revision=$revision;requestId=$requestId;incidentId='OCV02_O2D5_SIGNED_SEMANTIC_REGRESSION_20260825';createdUtc=[DateTime]::UtcNow.ToString('o');rehearsal=$true;injectResponseFailure=$InjectResponseFailure
        minimumDDriveFreeBytes=1;maximumCatalogBytes=1048576;maximumEvidenceJsonBytes=1048576;processorCommandToken='Run-JbodAllWaferProcessor.ps1'
        paths=[ordered]@{processorConfigPath=$processorConfigPath;endpointConfigPath=$endpointConfigPath;senderConfigPath=$senderConfigPath;stateRoot=$state;outputRoot=$output;localResultPath=$resultZip}
        pins=[ordered]@{processorConfigSha256=Get-Sha256 $processorConfigPath;endpointConfigSha256=Get-Sha256 $endpointConfigPath;senderConfigSha256=Get-Sha256 $senderConfigPath;dependencies=$dependencyPins}
        target=[ordered]@{lotId='62619-433';acquisitionId='62619-433_20260824005735';slotId='Slot16';domain='FRONTSIDE';expectedPhysicalIdentity='62619-433_20260824005735_Slot16'}
        senderProcessFixture=@([ordered]@{processId=801;creationDate='2026-08-25T00:00:00Z'})
        processorFixture=@([ordered]@{processId=802;name='powershell.exe';executablePath='powershell.exe';creationDate='2026-08-25T00:00:00Z';commandLineSha256='FIXTURE'})
        authority=[ordered]@{reviewOnly=$true;productionRoutingEnabled=$false;taskOrProcessRestartAllowed=$false;providerActivationAllowed=$false;sourceMutationAllowed=$false;sourceDeletionAllowed=$false;holdClearanceAllowed=$false;imageReadAllowed=$false;waferActionAllowed=$false}
    }
    $invocationPath = Join-Path $package 'INVOCATION.json'
    Write-JsonCreateNew -Path $invocationPath -Value $invocation -Depth 24

    $manifestRows = @('INVOCATION.json','Invoke-O2A3Direct.ps1','README_FIRST.txt','RUN_O2A3.cmd' | ForEach-Object {
        $path = Join-Path $package $_
        [ordered]@{path=$_;bytes=(Get-Item -LiteralPath $path).Length;sha256=Get-Sha256 $path}
    })
    Write-JsonCreateNew -Path (Join-Path $package 'PACKAGE_MANIFEST.json') -Value ([ordered]@{
        schema='argos_o2a3_direct_package_manifest_v1';revision=$revision;createdUtc=[DateTime]::UtcNow.ToString('o');lifecycle='FROZEN';files=@($manifestRows | Sort-Object path);reviewOnly=$true;productionRoutingEnabled=$false
    }) -Depth 12

    return [pscustomobject]@{id=$CaseId;package=$package;entry=(Join-Path $package 'Invoke-O2A3Direct.ps1');invocation=$invocationPath;output=$output;zip=$resultZip;outbox=$outbox;image=$imagePath;certificate=$certificate;inject=$InjectResponseFailure;expectedState=if ($IncludeProposal -and ($IncludeSummary -or $IncludeHold)) {'PASS_O2A3_EXACT_SLOT16_SCRIBE_OBSERVATION'} else {'HOLD_O2A3_EXACT_SLOT16_SCRIBE_EVIDENCE_INCOMPLETE'}}
}

foreach ($required in @('Invoke-O2A3Direct.ps1','RUN_O2A3.cmd','INVOCATION.json','README_FIRST.txt')) {
    Assert-True (Test-Path -LiteralPath (Join-Path $sourceRoot $required) -PathType Leaf) "O2A3 source package file is absent: $required"
}
foreach ($required in @($windowsPowerShell,$identityPath)) { Assert-True (Test-Path -LiteralPath $required -PathType Leaf) "O2A3 test dependency is absent: $required" }
Assert-True (-not (Test-Path -LiteralPath $testRoot)) 'O2A3 test root must be fresh.'
Assert-True (-not (Test-Path -LiteralPath 'D:\A2\x\O2A3_20260825T195521Z')) 'O2A3 live output root exists before test.'
Assert-True (-not (Test-Path -LiteralPath 'D:\A2\x\O2A3R_20260825T195521Z.zip')) 'O2A3 live local result exists before test.'

if ($Preflight) {
    [ordered]@{schema='argos_o2a3_test_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_TEST_PREFLIGHT';testRoot=$testRoot;targetExecuted=$false;mutationsPerformed=$false;imageBytesRead=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 8
    return
}

Assert-True (-not [string]::IsNullOrWhiteSpace($GatePath)) 'O2A3 test requires GatePath.'
$resolvedGate = [IO.Path]::GetFullPath($GatePath)
Assert-True ($resolvedGate.StartsWith($project.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2A3 test gate must remain inside the project.'
Assert-True (-not (Test-Path -LiteralPath $resolvedGate)) 'O2A3 test gate must be create-new.'

$caseRows = New-Object Collections.Generic.List[object]
try {
    [void](New-Item -ItemType Directory -Path $testRoot)
    $cases = @(
        [ordered]@{id='SUMMARY';summary=$true;hold=$false;proposal=$true;inject=$false},
        [ordered]@{id='HOLD';summary=$false;hold=$true;proposal=$true;inject=$false},
        [ordered]@{id='ABSENT';summary=$false;hold=$false;proposal=$false;inject=$false},
        [ordered]@{id='OUTBOUND_FAIL';summary=$true;hold=$false;proposal=$true;inject=$true}
    )
    foreach ($case in $cases) {
        $caseRoot = Join-Path $testRoot ([string]$case.id)
        $fixture = New-RehearsalCase -CaseRoot $caseRoot -CaseId ([string]$case.id) -IncludeSummary ([bool]$case.summary) -IncludeHold ([bool]$case.hold) -IncludeProposal ([bool]$case.proposal) -InjectResponseFailure ([bool]$case.inject)
        $preflightArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$fixture.entry,'-InvocationManifest',$fixture.invocation,'-Preflight','-Rehearsal')
        $preflightText = & $windowsPowerShell @preflightArgs | Out-String
        Assert-True ($LASTEXITCODE -eq 0) "O2A3 rehearsal preflight failed: $($case.id)"
        $preflightValue = $preflightText | ConvertFrom-Json
        Assert-True ([string]$preflightValue.state -eq 'PASS_O2A3_DIRECT_ADMIN_READ_ONLY_PREFLIGHT' -and -not [bool]$preflightValue.mutationsPerformed -and -not [bool]$preflightValue.imageBytesRead) "O2A3 rehearsal preflight state changed: $($case.id)"
        Assert-True (-not (Test-Path -LiteralPath $fixture.output) -and -not (Test-Path -LiteralPath $fixture.zip) -and @((Get-ChildItem -LiteralPath $fixture.outbox -Force)).Count -eq 0) "O2A3 rehearsal preflight wrote output: $($case.id)"

        $imageLock = [IO.File]::Open($fixture.image, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
        try {
            $runArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$fixture.entry,'-InvocationManifest',$fixture.invocation,'-Rehearsal')
            $priorPreference = $ErrorActionPreference
            try { $ErrorActionPreference='Continue'; $runRows=@(& $windowsPowerShell @runArgs 2>&1); $exit=$LASTEXITCODE }
            finally { $ErrorActionPreference=$priorPreference }
        }
        finally { $imageLock.Dispose() }

        Assert-True (Test-Path -LiteralPath $fixture.zip -PathType Leaf) "O2A3 rehearsal local ZIP is absent: $($case.id)"
        $ready = @((Get-ChildItem -LiteralPath $fixture.outbox -Directory -Filter '*.ready'))
        if ([bool]$case.inject) {
            Assert-True ($exit -ne 0 -and $ready.Count -eq 0) 'O2A3 injected outbound failure did not retain only the local result.'
            $caseRows.Add([pscustomobject][ordered]@{id=[string]$case.id;state='PASS_INJECTED_OUTBOUND_FAILURE';localResultRetained=$true;signedResponseCreated=$false;imageLockHeldDuringRun=$true})
            continue
        }

        Assert-True ($exit -eq 0 -and $ready.Count -eq 1) "O2A3 rehearsal did not create one signed response: $($case.id)"
        $manifestPath = Join-Path $ready[0].FullName 'PORTAL_RESPONSE_MANIFEST.json'
        $signaturePath = Join-Path $ready[0].FullName 'PORTAL_RESPONSE_MANIFEST.sig'
        $manifestBytes = [IO.File]::ReadAllBytes($manifestPath)
        $signatureBytes = [IO.File]::ReadAllBytes($signaturePath)
        $rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($fixture.certificate)
        try { $valid = $rsa.VerifyData($manifestBytes,$signatureBytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) }
        finally { $rsa.Dispose() }
        $responseManifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        Assert-True ($valid -and [string]$responseManifest.state -eq 'PASS_O2A3_DIRECT_ADMIN_READ_ONLY_OBSERVATION') "O2A3 rehearsal signature/state changed: $($case.id)"
        $observation = Get-Content -Raw -LiteralPath (Join-Path $fixture.output 'O2A3_OBSERVATION.json') | ConvertFrom-Json
        Assert-True ([string]$observation.state -eq [string]$fixture.expectedState) "O2A3 observation state changed: $($case.id)"
        Assert-True (-not [bool]$observation.imageBytesRead -and -not [bool]$observation.taskOrProcessRestarted -and [bool]$observation.processorIdentityUnchanged) "O2A3 observation authority changed: $($case.id)"
        Assert-True (@($observation.installedDependencies).Count -eq 6 -and @($observation.callerPathContractTokens | Where-Object { -not [bool]$_.present }).Count -eq 0) "O2A3 installed source evidence changed: $($case.id)"
        if ([string]$case.id -ne 'ABSENT') { Assert-True ([int]$observation.declaredMetadataCount -gt 0) "O2A3 declared metadata projection is empty: $($case.id)" }
        $caseRows.Add([pscustomobject][ordered]@{id=[string]$case.id;state='PASS';observationState=[string]$observation.state;signedResponseVerified=$true;processorIdentityUnchanged=$true;imageLockHeldDuringRun=$true;imageBytesRead=$false})
    }

    Assert-True (-not (Test-Path -LiteralPath 'D:\A2\x\O2A3_20260825T195521Z') -and -not (Test-Path -LiteralPath 'D:\A2\x\O2A3R_20260825T195521Z.zip')) 'O2A3 test wrote live output.'
    $gate = [ordered]@{
        schema='argos_o2a3_direct_test_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2A3_DIRECT_PACKAGE_SHAPED_TEST_GATE';cases=$caseRows.ToArray();requiredCaseIds=@('SUMMARY','HOLD','ABSENT','OUTBOUND_FAIL')
        windowsPowerShell51Passed=$true;packageShapedExecutionPassed=$true;exactSummaryAndHoldAlternativesPassed=$true;exactAbsenceReturnsSignedHoldObservation=$true;injectedOutboundFailureRetainedLocalResult=$true
        lockedImageFixturePassed=$true;imageBytesRead=$false;taskOrProcessRestarted=$false;targetMutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false
    }
    Write-JsonCreateNew -Path $resolvedGate -Value $gate -Depth 16
    $gate | ConvertTo-Json -Depth 16
}
finally {
    if (Test-Path -LiteralPath $testRoot -PathType Container) {
        $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
        Assert-True ($resolvedTestRoot -eq 'C:\O2A3T_195521') 'O2A3 test cleanup root changed.'
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
