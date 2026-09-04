#Requires -Version 5.1
# Clone-audit historical rehearsal root only: U:\ProjectPortalRO is not accessed by the R18R build.
# DRAFT only. This builder cannot reach signer access or create a package until
# the R18R cohort/definition/path plan are frozen and exact preaction and
# canonical-checksum gate hashes replace the deliberately empty pins below.
[CmdletBinding()]
param([switch]$Preflight, [switch]$Build)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($stream))).Replace('-','') }
    finally { $hasher.Dispose(); $stream.Dispose() }
}
function Get-TextSha256([string]$Text) {
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($Text)
    $hasher = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash($bytes))).Replace('-','') }
    finally { $hasher.Dispose() }
}
function Require-Pin([string]$Path, [string]$Sha256, [string]$State = '') {
    Require (Test-Path -LiteralPath $Path -PathType Leaf) "R18R build dependency absent: $Path"
    Require ((Get-Sha256 $Path) -eq $Sha256) "R18R build dependency changed: $Path"
    if (-not [string]::IsNullOrWhiteSpace($State)) {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
        Require ([string]$value.state -eq $State) "R18R build dependency state changed: $Path"
    }
}
function Test-ExactPin([string]$Path, [string]$Sha256) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try { return (Get-Sha256 $Path) -eq $Sha256 }
    catch { return $false }
}
function Write-JsonNew([string]$Path, [object]$Value, [int]$Depth = 32) {
    Require (-not (Test-Path -LiteralPath $Path)) "R18R build create-new JSON exists: $Path"
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth $Depth) + [Environment]::NewLine), (New-Object Text.UTF8Encoding($false)))
}

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_R18R1'
$revision = 'R18R_RECIPROCAL_MARGIN_REFERENCE_ISOLATED_REVIEW_ONLY_20260904A'
$payloadRevision = $revision
$entrypoint = Join-Path $PSScriptRoot 'Invoke-R18RReferenceIsolatedLaunch.ps1'
$payloadManifestPath = Join-Path $PSScriptRoot 'R18R_PAYLOAD_MANIFEST.json'
$definitionPath = Join-Path $PSScriptRoot 'MAINTENANCE_DEFINITION.json'
$cohortPath = Join-Path $PSScriptRoot 'R18R_REVIEW_COHORT.json'
$localGatePath = Join-Path $PSScriptRoot 'R18R_LOCAL_GATE.json'
$pathGatePath = Join-Path $PSScriptRoot 'R18R_PATH_PLAN_GATE.json'
$cohortBindingGatePath = Join-Path $PSScriptRoot 'R18R_COHORT_BINDING_GATE.json'
$referenceIsolationGatePath = Join-Path $PSScriptRoot 'R18R_REFERENCE_ISOLATION_LOCAL_GATE.json'
$canonicalChecksumGatePath = Join-Path $PSScriptRoot 'R18R_CANONICAL_CHECKSUM_GATE.json'
$referenceGateTest = Join-Path $project 'work\OPENCV_SCRIBE_R18R\Test-R18RReferenceIsolation.py'
$semanticBaselinePath = Join-Path $project 'work\OPENCV_SCRIBE_V1\OCV02_SCRIBE_SEMANTIC_BASELINE.json'
$semiMethodPath = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\SEMI_M12_SCRIBE_VALIDATION_METHOD.md'
$canonicalVectorPath = Join-Path $project 'work\SCRIBE_REVIEW_ONLY\SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv'
$r18qProviderPath = Join-Path $project 'work\OPENCV_SCRIBE_R18Q\ArgosOpenCvScribeV1R18Q.py'
$r18rProviderPath = Join-Path $project 'work\OPENCV_SCRIBE_R18R\ArgosOpenCvScribeV1R18R.py'
$r18rRunnerPath = Join-Path $project 'work\OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py'
$stageRoot = 'C:\R18RP'
$readyRoot = Join-Path $stageRoot ($requestId + '.ready')
$stageZip = Join-Path $stageRoot ($requestId + '.ready.zip')
$verifyRoot = 'C:\R18RV'
$finalRoot = Join-Path $PSScriptRoot 'final'
$finalPartial = Join-Path $PSScriptRoot 'final.partial'
$zipName = $requestId + '.ready.zip'
$finalZip = Join-Path $finalRoot $zipName
$finalGatePath = Join-Path $PSScriptRoot 'R18R_FINAL_PACKAGE_GATE.json'
$identityPath = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\state\LAPTOP_SIGNING_IDENTITY.json'
$publicCertificate = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\enrollment\ARGOS_PROJECT_PORTAL_LAPTOP_SIGNER_PUBLIC.cer'
$packageTester = Join-Path $project 'work\PROJECT_PORTAL_REVIEW_ONLY\scripts\Test-SignedPortalPackage.ps1'
$preactionTool = Join-Path $project 'utilities\Confirm-ArgosZeroRecurrencePreaction.ps1'
$historyAudit = Join-Path $project 'work\ARGOS_HISTORY_NO_REPEAT_AUDIT_20260820.json'
$preactionPath = Join-Path $PSScriptRoot 'PREACTION_R18R_REFERENCE_ISOLATED_PREPARATION.json'
$localPython = 'C:\ArgosPy313\Scripts\python.exe'
$localPythonSha = 'D70FCED7F461F38F9F224D8673FB74E96E4FACB4283FF4E8697543B457FEA8A0'
$localRefs = Join-Path $project 'work\OPENCV_SCRIBE_O2D5\final\extract\O2D5_REFS.zip'
$localProposals = 'C:\R18J_CORPUS_FIXTURE\proposals'

$entrypointSha = 'CC31B338074A0C00C53E8980F775C8D90280A4AF14DBC5D20A22AEB38F2147DA'
$payloadManifestSha = '251F028EFC852B74FAB961CF92E36538D01345C58D03757DDFB81B5EA4EA141B'
$definitionSha = '8345C4EE0D20BE2541D5D67DD1CE896A3C21523CD58070F51358768D55D41146'
$cohortSha = '78771AA262F5663AAAB3BFCCFD3E7ACC0EC0AC337DDA879BA2AF7F29C271425C'
$localGateSha = '566EB33649697713F5E0EFD3E0F04F9861333103BBBC1C1BACFEDE3CD184C82A'
$pathGateSha = 'A3F6FA6F12A2AFBDD4A5084F74FA36C91E3F30BDCF16321DC25147B270D9692F'
$cohortBindingGateSha = 'FFA962D6EE01C9A2F3D25B871A0E63DDD23DACE2577DC51A870B7C0899C84B25'
$referenceIsolationGateSha = 'E48CDD6FBE0F73A5CA38605AE642AFCC2F041E6A83583B7DDAF43A7CDCBA8472'
$referenceGateTestSha = '657E7F780AA69D5E2AF0601C36A73424E387A6BB5735C051ED1B59D2EFB23EE5'
$semanticBaselineSha = 'CE1EDE3164D204173DFDC17E9AF4A6F15E4C9C7B4DCD634CB00337A74784A0CD'
$semiMethodSha = 'E5B78AFBA2614A3D4186298C84CF8E46F4816B0A9F3B2BC3DE751E854C014C2C'
$canonicalVectorSha = '6911A0E12E81AEFBF59D7EE4FCC99457362DE0834949431E26C27566F6E93F16'
$r18qProviderSha = 'AB20CFB25D223D40D31237118436446018AE213F800ECF1652213EB942C40DC1'
$r18rProviderSha = '51C95B3279D253EF717F663F3860CC6B4CA38517706E08E9FE2302BE02CD2BB5'
$r18rRunnerSha = 'B826767EA21BB148DD30A719595B23DD818FD9CFC08B347FEAFD9FD4959F4E3C'
$identitySha = '3FD8164D1869375156FB7566D206FEAB97AE8A9E7D377B0AD4E03739ED697289'
$certificateSha = '2B434D0CF6A0D6D69AAE3D280032EFF00807D423CA3B3D7F2EFC1C6BB628BFFF'
$testerSha = '6CA21D7DE97EDE88F2C41F91D5B7801C688982C8C5A422987EB9528E1E9A084B'
$expectedLeafSetSha = 'CD49F02C4708E66DF6807D96A8E99E942536C150864F20794B6B852FBEB3E994'

# Intentionally empty in this DRAFT. They must be replaced by exact hashes in a
# new reviewed builder revision; existence or a state-only check cannot enable Build.
$preactionSha = ''
$canonicalChecksumGateSha = ''

function Confirm-R18RRuntimeAllowlist(
    [string]$Phase,
    [object[]]$PayloadFiles,
    [string[]]$ExpectedLeaves,
    [string]$PackageRoot = ''
) {
    Require ($Phase -in @('SOURCE_PRE_SIGNER','EXTRACTED_FINAL_ZIP')) "R18R unknown runtime allowlist phase: $Phase"
    $expectedSet = @{}
    foreach ($leaf in $ExpectedLeaves) {
        Require (-not $expectedSet.ContainsKey($leaf)) "R18R duplicate planned ZIP member: $leaf"
        $expectedSet[$leaf] = $true
    }
    $plannedSetSha = Get-TextSha256 ((@($ExpectedLeaves | Sort-Object) -join "`n") + "`n")
    Require ($ExpectedLeaves.Count -eq 31 -and $plannedSetSha -eq $expectedLeafSetSha) 'R18R runtime allowlist planned ZIP membership changed.'

    $rows = New-Object Collections.Generic.List[object]
    $actualLeaves = @($ExpectedLeaves | Sort-Object)
    if ($Phase -eq 'SOURCE_PRE_SIGNER') {
        $rows.Add([pscustomobject]@{member='payload/Invoke-R18RReferenceIsolatedLaunch.ps1';path=$entrypoint})
        $rows.Add([pscustomobject]@{member='payload/R18R_PAYLOAD_MANIFEST.json';path=$payloadManifestPath})
        foreach ($file in $PayloadFiles) {
            $rows.Add([pscustomobject]@{
                member=('payload/files/' + [string]$file.installRelativePath)
                path=(Join-Path $project ([string]$file.sourcePath).Replace('/','\'))
            })
        }
    }
    else {
        Require (Test-Path -LiteralPath $PackageRoot -PathType Container) 'R18R extracted runtime gate root absent.'
        $extracted = @(Get-ChildItem -LiteralPath $PackageRoot -Recurse -File)
        $actualLeaves = @($extracted | ForEach-Object { $_.FullName.Substring($PackageRoot.Length + 1).Replace('\','/') } | Sort-Object)
        $actualSetSha = Get-TextSha256 (($actualLeaves -join "`n") + "`n")
        Require ($actualLeaves.Count -eq 31 -and $actualSetSha -eq $expectedLeafSetSha) 'R18R extracted runtime membership is outside the exact allowlist.'
        foreach ($file in $extracted) {
            $rows.Add([pscustomobject]@{member=$file.FullName.Substring($PackageRoot.Length + 1).Replace('\','/');path=$file.FullName})
        }
    }

    $forbiddenPaths = New-Object Collections.Generic.List[string]
    foreach ($member in $actualLeaves) {
        Require ($expectedSet.ContainsKey($member)) "R18R runtime member is not allowlisted: $member"
        $name = [IO.Path]::GetFileName($member)
        if (
            $name -match '(?i)^Test.*\.py$' -or
            $member -match '(?i)(^|/)(fixtures?|[^/]*fixture[^/]*)(/|$)' -or
            $member -match '(?i)(^|/)(hooks?|[^/]*hook[^/]*)(/|$)' -or
            $member -match '(?i)(^|/)__pycache__(/|$)' -or
            $member -match '(?i)\.pyc$' -or
            $member -match '(?i)(LOCAL_GATE|SUPERSEDED)'
        ) { $forbiddenPaths.Add($member) }
    }
    Require ($forbiddenPaths.Count -eq 0) ("R18R test/gate artifact entered runtime allowlist: " + ($forbiddenPaths -join ', '))

    $forbiddenContent = New-Object Collections.Generic.List[string]
    $productionLiterals = New-Object Collections.Generic.List[string]
    $textSourceCount = 0
    $contentPatterns = @(
        [pscustomobject]@{name='MetadataProxy';pattern='(?i)MetadataProxy'},
        [pscustomobject]@{name='INVERT';pattern='(?i)(?<![A-Z0-9_])INVERT(?![A-Z0-9_])'},
        [pscustomobject]@{name='SELECTIVE_MISSING_CHECKSUM';pattern='(?i)SELECTIVE_MISSING_CHECKSUM'},
        [pscustomobject]@{name='INJECTED_CONTROL';pattern='(?i)INJECTED_CONTROL'},
        [pscustomobject]@{name='INJECTED_PROVIDER_FAILURE';pattern='(?i)INJECTED_PROVIDER_FAILURE'},
        [pscustomobject]@{name='INJECTED_RUNNER_FAILURE';pattern='(?i)INJECTED_RUNNER_FAILURE'},
        [pscustomobject]@{name='adapter_restoration_gate';pattern='(?i)adapter_restoration_gate'},
        [pscustomobject]@{name='provider_sentinel';pattern='(?i)provider_sentinel'},
        [pscustomobject]@{name='runner_sentinel';pattern='(?i)runner_sentinel'}
    )
    $productionPattern = '(?i)(?<![A-Z0-9])(?:lot[-_])?\d{5,6}[-_]\d{3}(?![A-Z0-9])|(?<![A-Z0-9])slot\d+(?![A-Z0-9])'
    foreach ($row in $rows) {
        Require (Test-Path -LiteralPath $row.path -PathType Leaf) "R18R runtime allowlist source absent: $($row.member)"
        $extension = [IO.Path]::GetExtension([string]$row.member).ToLowerInvariant()
        if ($extension -in @('.py','.ps1','.json','.md','.txt','.csv')) {
            $textSourceCount++
            $text = [IO.File]::ReadAllText([string]$row.path)
            foreach ($control in $contentPatterns) {
                if ($text -match [string]$control.pattern) { $forbiddenContent.Add("$($row.member):$($control.name)") }
            }
            if ($extension -in @('.py','.ps1')) {
                foreach ($match in [regex]::Matches($text, $productionPattern)) {
                    $productionLiterals.Add("$($row.member):$($match.Value)")
                }
            }
        }
    }
    Require ($forbiddenContent.Count -eq 0) ("R18R injected test/adapter control entered runtime: " + ($forbiddenContent -join ', '))
    Require ($productionLiterals.Count -eq 0) ("R18R executable contains a hard-coded lot/slot identity: " + ($productionLiterals -join ', '))

    $pythonMembers = @($ExpectedLeaves | Where-Object { $_ -like 'payload/files/*.py' })
    Require ($pythonMembers.Count -eq 15) 'R18R runtime Python source cardinality changed.'
    $pinMembers = [ordered]@{
        r18q='payload/files/OPENCV_SCRIBE_R18Q/ArgosOpenCvScribeV1R18Q.py'
        provider='payload/files/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py'
        runner='payload/files/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py'
        launcher='payload/Invoke-R18RReferenceIsolatedLaunch.ps1'
    }
    $pinHashes = [ordered]@{r18q=$r18qProviderSha;provider=$r18rProviderSha;runner=$r18rRunnerSha;launcher=$entrypointSha}
    foreach ($key in $pinMembers.Keys) {
        $matches = @($rows | Where-Object { [string]$_.member -eq [string]$pinMembers[$key] })
        Require ($matches.Count -eq 1) "R18R packaged runtime pin member missing or duplicated: $key"
        Require ((Get-Sha256 ([string]$matches[0].path)) -eq [string]$pinHashes[$key]) "R18R packaged runtime pin changed: $key"
    }

    $launcherRow = @($rows | Where-Object { [string]$_.member -eq [string]$pinMembers.launcher })[0]
    $launcherText = [IO.File]::ReadAllText([string]$launcherRow.path)
    Require ($launcherText.Contains('$runner = Join-Path $WorkRoot ''OPENCV_SCRIBE_R18R\Run-R18RReferenceIsolatedCorpus.py''')) 'R18R launcher does not select the R18R runner.'
    Require ($launcherText.Contains('$configuration.revision = $revision')) 'R18R launcher does not replace the inherited revision.'
    Require ($launcherText.Contains('$configuration.providerPath = Join-Path $WorkRoot ''OPENCV_SCRIBE_R18R\ArgosOpenCvScribeV1R18R.py''')) 'R18R launcher does not replace providerPath.'
    Require ($launcherText.Contains('$configuration.providerSha256 = $providerSha')) 'R18R launcher does not replace providerSha256.'
    $guardCalls = @([regex]::Matches($launcherText, '(?im)^\s*Assert-NoRuntimeOverrideHooks\s+\$configuration\s*$'))
    Require ($guardCalls.Count -eq 2) 'R18R launcher runtime override guard call count changed.'
    $configurationOverrides = @([regex]::Matches($launcherText, '(?im)^\s*\$configuration(?:\.[A-Z0-9_]+)*\.(?:checksum[^.\s=]*|threshold[^.\s=]*|test[^.\s=]*|hook[^.\s=]*|monkeypatch[^.\s=]*|override[^.\s=]*)\s*='))
    $argumentOverrides = @([regex]::Matches($launcherText, '(?i)--[^\s"'']*(?:checksum|threshold|test|hook|monkeypatch|override)'))
    Require ($configurationOverrides.Count -eq 0 -and $argumentOverrides.Count -eq 0) 'R18R launcher contains a checksum, threshold, or test override.'

    return [ordered]@{
        schema='argos_opencv_scribe_r18r_runtime_allowlist_phase_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');
        state='PASS_R18R_RUNTIME_CONTAMINATION_ALLOWLIST';phase=$Phase;
        allowlistedFinalZipMemberCount=31;allowlistedFinalZipMemberSetSha256=$expectedLeafSetSha;
        runtimePythonSourceCount=$pythonMembers.Count;textSourceCount=$textSourceCount;
        forbiddenPathArtifactCount=0;forbiddenContentTokenCount=0;executableProductionIdentityLiteralCount=0;
        r18qProviderSha256=$r18qProviderSha;r18rProviderSha256=$r18rProviderSha;r18rRunnerSha256=$r18rRunnerSha;
        launcherSha256=$entrypointSha;launcherSelectsR18RRunner=$true;launcherReplacesRevision=$true;
        launcherReplacesProviderPath=$true;launcherReplacesProviderSha256=$true;
        checksumOverrideCount=0;thresholdOverrideCount=0;testOrAdapterOverrideCount=0;
        checksumVerificationRequired=$true;checksumUsedForImageFirst=$false;identityAccepted=$false;
        reviewOnly=$true;productionRoutingEnabled=$false
    }
}

# Static package and tested-runtime pins. No identity, certificate, or private
# key material is accessed in this section.
Require-Pin $entrypoint $entrypointSha
Require-Pin $payloadManifestPath $payloadManifestSha
Require-Pin $definitionPath $definitionSha
Require-Pin $cohortPath $cohortSha 'DRAFT_CONFIGURATION_SELECTED_COHORT'
Require-Pin $localGatePath $localGateSha 'PASS_R18R_LOCAL_SLOT24_RESOLUTION_REMOTE_AMBIGUITY_CONTROLS_PENDING'
Require-Pin $pathGatePath $pathGateSha 'PASS_PATH_BUDGET'
Require-Pin $cohortBindingGatePath $cohortBindingGateSha 'PASS_R18R_COHORT_BINDING_GATE'
Require-Pin $referenceIsolationGatePath $referenceIsolationGateSha 'PASS_R18R_REFERENCE_ISOLATION_LOCAL_GATE'
Require-Pin $r18qProviderPath $r18qProviderSha
Require-Pin $r18rProviderPath $r18rProviderSha
Require-Pin $r18rRunnerPath $r18rRunnerSha

# Canonical semantic/checksum prerequisites are deliberately ahead of every
# identity, public-certificate, certificate-store, and private-key access.
Require-Pin $semanticBaselinePath $semanticBaselineSha 'LOCKED_INPUT'
$semanticBaseline = Get-Content -Raw -LiteralPath $semanticBaselinePath | ConvertFrom-Json
Require ([string]$semanticBaseline.schema -eq 'argos_opencv_scribe_semantic_baseline_v1') 'R18R semantic baseline schema changed.'
Require ([string]$semanticBaseline.semiM12Method.path -eq 'work/SCRIBE_REVIEW_ONLY/SEMI_M12_SCRIBE_VALIDATION_METHOD.md' -and [string]$semanticBaseline.semiM12Method.sha256 -eq $semiMethodSha) 'R18R SEMI M12 method binding changed.'
Require ([string]$semanticBaseline.semiM12Method.valueMethod -eq 'ASCII_MINUS_32_MOD_59' -and [int]$semanticBaseline.semiM12Method.bodyLength -eq 10 -and [int]$semanticBaseline.semiM12Method.totalLength -eq 12) 'R18R SEMI M12 dimensions or value method changed.'
Require ([bool]$semanticBaseline.semiM12Method.canonicalCheckPairRequired -and -not [bool]$semanticBaseline.semiM12Method.checksumMayInventUnsupportedCharacter) 'R18R canonical checksum role changed.'
Require ([string]$semanticBaseline.semiM12Method.verifiedVectorPath -eq 'work/SCRIBE_REVIEW_ONLY/SEMI_M12_VERIFIED_TEST_VECTORS_20260730.csv' -and [string]$semanticBaseline.semiM12Method.verifiedVectorSha256 -eq $canonicalVectorSha) 'R18R canonical checksum vector binding changed.'
Require ([int]$semanticBaseline.semiM12Method.verifiedVectorCount -eq 19 -and [int]$semanticBaseline.semiM12Method.verifiedVectorPassCount -eq 19) 'R18R canonical checksum vector count/pass evidence changed.'

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
$cohort = Get-Content -Raw -LiteralPath $cohortPath | ConvertFrom-Json
$pathGate = Get-Content -Raw -LiteralPath $pathGatePath | ConvertFrom-Json
$cohortBindingGate = Get-Content -Raw -LiteralPath $cohortBindingGatePath | ConvertFrom-Json
$referenceIsolationGate = Get-Content -Raw -LiteralPath $referenceIsolationGatePath | ConvertFrom-Json
$payloadManifest = Get-Content -Raw -LiteralPath $payloadManifestPath | ConvertFrom-Json
Require ([string]$payloadManifest.schema -eq 'argos_opencv_scribe_r18r_payload_manifest_v1' -and [string]$payloadManifest.revision -eq $payloadRevision -and @($payloadManifest.files).Count -eq 27) 'R18R payload manifest shape changed.'
Require ([bool]$payloadManifest.authority.reviewOnly -and -not [bool]$payloadManifest.authority.identityAcceptanceAuthorized -and -not [bool]$payloadManifest.authority.automaticReferenceAdmissionAuthorized -and -not [bool]$payloadManifest.authority.trainingAuthorized -and -not [bool]$payloadManifest.authority.activationAuthorized -and -not [bool]$payloadManifest.authority.xmlAuthorized -and -not [bool]$payloadManifest.authority.productionAuthorized) 'R18R payload authority changed.'
$payloadFiles = @($payloadManifest.files)
Require (@($payloadFiles | Where-Object { [IO.Path]::GetExtension([string]$_.installRelativePath) -eq '.py' }).Count -eq 15) 'R18R payload Python source count changed.'
foreach ($file in $payloadFiles) {
    Require (-not [IO.Path]::IsPathRooted([string]$file.installRelativePath) -and [string]$file.installRelativePath -notmatch '(^|/)\.\.(/|$)') "R18R unsafe payload member: $($file.installRelativePath)"
    $source = Join-Path $project ([string]$file.sourcePath).Replace('/','\')
    Require-Pin $source ([string]$file.sha256)
    Require ((Get-Item -LiteralPath $source).Length -eq [int64]$file.bytes) "R18R payload length changed: $($file.sourcePath)"
}
$expectedLeaves = @('PORTAL_REQUEST_MANIFEST.json','PORTAL_REQUEST_MANIFEST.sig','payload/Invoke-R18RReferenceIsolatedLaunch.ps1','payload/R18R_PAYLOAD_MANIFEST.json') + @($payloadFiles | ForEach-Object { 'payload/files/' + [string]$_.installRelativePath })
$sourceRuntimeGate = Confirm-R18RRuntimeAllowlist 'SOURCE_PRE_SIGNER' $payloadFiles $expectedLeaves
$canonicalMethodExact = Test-ExactPin $semiMethodPath $semiMethodSha
$canonicalVectorExact = Test-ExactPin $canonicalVectorPath $canonicalVectorSha
$canonicalChecksumGateExact = (-not [string]::IsNullOrWhiteSpace($canonicalChecksumGateSha)) -and (Test-ExactPin $canonicalChecksumGatePath $canonicalChecksumGateSha)
$draftBlockers = New-Object Collections.Generic.List[string]
if (-not $canonicalMethodExact) { $draftBlockers.Add('CANONICAL_SEMI_M12_METHOD_ABSENT_OR_HASH_MISMATCH') }
if (-not $canonicalVectorExact) { $draftBlockers.Add('CANONICAL_SEMI_M12_VECTOR_ABSENT_OR_HASH_MISMATCH') }
if (-not $canonicalChecksumGateExact) { $draftBlockers.Add('CANONICAL_CHECKSUM_GATE_EXACT_HASH_NOT_ESTABLISHED') }
if ([string]$definition.state -ne 'FROZEN_UNPUBLISHED') { $draftBlockers.Add('MAINTENANCE_DEFINITION_NOT_FROZEN') }
if ([string]$cohort.state -ne 'FROZEN_CONFIGURATION_SELECTED_COHORT') { $draftBlockers.Add('COHORT_NOT_FROZEN') }
if ([string]$pathGate.artifactLifecycle -ne 'FROZEN') { $draftBlockers.Add('PATH_PLAN_NOT_FROZEN') }
if ([string]$cohortBindingGate.artifactLifecycle -ne 'FROZEN') { $draftBlockers.Add('COHORT_BINDING_GATE_NOT_FROZEN') }
if ([string]$referenceIsolationGate.artifactLifecycle -ne 'FROZEN') { $draftBlockers.Add('REFERENCE_ISOLATION_GATE_NOT_FROZEN') }
if ([string]::IsNullOrWhiteSpace($preactionSha)) { $draftBlockers.Add('PREACTION_EXACT_HASH_NOT_ESTABLISHED') }
if ($Preflight -and $draftBlockers.Count -gt 0) {
    [ordered]@{
        schema='argos_opencv_scribe_r18r_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');
        state='BLOCKED_R18R_BUILD_DRAFT_PREREQUISITES';requestId=$requestId;blockerCount=$draftBlockers.Count;
        blockers=$draftBlockers.ToArray();definitionState=[string]$definition.state;cohortState=[string]$cohort.state;
        pathPlanLifecycle=[string]$pathGate.artifactLifecycle;cohortBindingLifecycle=[string]$cohortBindingGate.artifactLifecycle;
        referenceIsolationLifecycle=[string]$referenceIsolationGate.artifactLifecycle;
        canonicalMethodExact=$canonicalMethodExact;canonicalVectorExact=$canonicalVectorExact;
        canonicalChecksumGateExact=$canonicalChecksumGateExact;sourceRuntimeAllowlist=$sourceRuntimeGate;
        preactionExactPinEstablished=(-not [string]::IsNullOrWhiteSpace($preactionSha));
        cohortBindingExactPinEstablished=$true;referenceIsolationExactPinEstablished=$true;
        signerIdentityAccessed=$false;certificateAccessed=$false;privateKeyAccessed=$false;
        zipCreated=$false;mutationsPerformed=$false;targetExecuted=$false;publicationAuthorized=$false;
        reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 12
    return
}
if ($Build -and $draftBlockers.Count -gt 0) {
    throw ('R18R Build blocked before signer access: ' + ($draftBlockers -join ', '))
}
Require-Pin $semiMethodPath $semiMethodSha
Require-Pin $canonicalVectorPath $canonicalVectorSha
Require-Pin $canonicalChecksumGatePath $canonicalChecksumGateSha 'PASS_R18R_CANONICAL_CHECKSUM_GATE'
$canonicalChecksumGate = Get-Content -Raw -LiteralPath $canonicalChecksumGatePath | ConvertFrom-Json
Require ([string]$canonicalChecksumGate.schema -eq 'argos_opencv_scribe_r18r_canonical_checksum_gate_v1') 'R18R canonical checksum gate schema changed.'
Require ([string]$canonicalChecksumGate.semiM12MethodSha256 -eq $semiMethodSha -and [string]$canonicalChecksumGate.canonicalVectorSha256 -eq $canonicalVectorSha) 'R18R canonical checksum gate input binding changed.'
Require ([int]$canonicalChecksumGate.vectorCount -eq 19 -and [int]$canonicalChecksumGate.passCount -eq 19 -and [int]$canonicalChecksumGate.failureCount -eq 0) 'R18R canonical checksum vectors did not pass 19 of 19.'
foreach ($field in @('checksumVerificationRequired','checksumUsedForImageFirst','checksumMutationAllowed')) {
    $property = $canonicalChecksumGate.PSObject.Properties[$field]
    Require ($null -ne $property -and $property.Value -is [bool]) "R18R canonical checksum gate Boolean is absent or invalid: $field"
}
Require ([bool]$canonicalChecksumGate.checksumVerificationRequired -and -not [bool]$canonicalChecksumGate.checksumUsedForImageFirst -and -not [bool]$canonicalChecksumGate.checksumMutationAllowed) 'R18R canonical checksum role changed.'

Require-Pin $referenceGateTest $referenceGateTestSha
Require-Pin $localPython $localPythonSha
Require-Pin $localRefs '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6'
Require (Test-Path -LiteralPath $localProposals -PathType Container) 'R18R local rehearsal proposal root absent.'

$localGate = Get-Content -Raw -LiteralPath $localGatePath | ConvertFrom-Json
Require ([string]$localGate.schema -eq 'argos_opencv_scribe_r18r_local_gate_v1' -and [string]$localGate.classification -eq 'PENDING_GATE') 'R18R tested local gate contract changed.'
Require ([string]$localGate.provider.path -eq 'work/OPENCV_SCRIBE_R18R/ArgosOpenCvScribeV1R18R.py' -and [string]$localGate.provider.sha256 -eq $r18rProviderSha) 'R18R tested provider binding changed.'
Require ([string]$localGate.runner.path -eq 'work/OPENCV_SCRIBE_R18R/Run-R18RReferenceIsolatedCorpus.py' -and [string]$localGate.runner.sha256 -eq $r18rRunnerSha) 'R18R tested runner binding changed.'
Require ([string]$localGate.checksumRegression.classification -eq 'SUPPLEMENTAL_NOT_CANONICAL_ARCHIVED_VECTOR_SET' -and [string]$localGate.checksumRegression.canonicalArchivedVectorLocalState -eq 'ABSENT') 'R18R local supplemental checksum evidence was silently reclassified as canonical.'
Require ([bool]$localGate.authority.reviewOnly -and -not [bool]$localGate.authority.identityAcceptanceAuthorized -and -not [bool]$localGate.authority.automaticReferenceAdmissionAuthorized -and -not [bool]$localGate.authority.trainingAuthorized -and -not [bool]$localGate.authority.activationAuthorized -and -not [bool]$localGate.authority.xmlAuthorized -and -not [bool]$localGate.authority.productionAuthorized -and -not [bool]$localGate.authority.publicationAuthorized) 'R18R local gate authority changed.'

$definition = Get-Content -Raw -LiteralPath $definitionPath | ConvertFrom-Json
Require ([string]$definition.schema -eq 'argos_opencv_scribe_r18r_maintenance_definition_v1' -and [string]$definition.revision -eq $revision) 'R18R maintenance definition contract changed.'
Require ([string]$definition.targetRole -eq 'JBOD' -and [string]$definition.jobClass -eq 'MAINTENANCE_PATCH' -and [string]$definition.entryPoint -eq 'payload/Invoke-R18RReferenceIsolatedLaunch.ps1') 'R18R maintenance route changed.'
Require (@($definition.changes).Count -eq 1 -and [string]$definition.changes[0].installedSha256 -eq $entrypointSha -and [bool]$definition.changes[0].allowCreate) 'R18R maintenance change changed.'
Require (@($definition.changes[0].approvedPredecessorSha256).Count -eq 1 -and [string]$definition.changes[0].approvedPredecessorSha256[0] -eq $entrypointSha) 'R18R create-only idempotent installed-hash boundary changed.'
Require (@($definition.allowedTaskActions).Count -eq 0 -and @($definition.allowedProcessActions).Count -eq 1) 'R18R process/task action cardinality changed.'
Require ([int]$definition.sourceProcessingContract.configuredCaseCount -eq 21 -and [int]$definition.sourceProcessingContract.uniqueSourcePairCount -eq 21 -and [string]$definition.sourceProcessingContract.cohortSha256 -eq $cohortSha) 'R18R bounded cohort contract changed.'
Require ([string]$definition.sourceProcessingContract.providerSha256 -eq $r18rProviderSha -and [string]$definition.sourceProcessingContract.structuralProviderSha256 -eq $r18qProviderSha) 'R18R provider chain changed.'
Require ([bool]$definition.sourceProcessingContract.checksumVerificationRequired -and -not [bool]$definition.sourceProcessingContract.checksumUsedForImageFirst -and -not [bool]$definition.sourceProcessingContract.runtimeChecksumOverrideAllowed -and -not [bool]$definition.sourceProcessingContract.runtimeThresholdOverrideAllowed -and -not [bool]$definition.sourceProcessingContract.runtimeTestOrMonkeypatchHookAllowed) 'R18R checksum or runtime-override boundary changed.'
Require ([string]$definition.entryPointMutations[0].targetRoot -eq 'D:\A2\w\ocv\R18R1' -and [string]$definition.entryPointMutations[1].targetRoot -eq 'D:\A2\o\ocv\R18R1') 'R18R declared roots changed.'
Require (-not [bool]$definition.publication.explicitOperatorAuthorityPresent) 'R18R preparation cannot claim publication authority.'
Require ([bool]$definition.reviewOnly -and -not [bool]$definition.productionRoutingEnabled -and -not [bool]$definition.sourceProcessingContract.automaticIdentityAuthority -and -not [bool]$definition.sourceProcessingContract.sourceMutationAllowed -and -not [bool]$definition.sourceProcessingContract.sourceDeletionAllowed) 'R18R authority changed.'

$cohort = Get-Content -Raw -LiteralPath $cohortPath | ConvertFrom-Json
Require ([string]$cohort.schema -eq 'argos_opencv_scribe_r18r_review_cohort_v1' -and [string]$cohort.revision -eq $revision -and [int]$cohort.caseCount -eq 21 -and @($cohort.reviewCases).Count -eq 21) 'R18R cohort shape changed.'
Require (@($cohort.reviewCases.physicalIdentity | Sort-Object -Unique).Count -eq 21) 'R18R cohort physical identities are not unique.'
Require ([bool]$cohort.authority.reviewOnly -and -not [bool]$cohort.authority.identityAcceptanceAuthorized -and -not [bool]$cohort.authority.automaticReferenceAdmissionAuthorized -and -not [bool]$cohort.authority.trainingAuthorized -and -not [bool]$cohort.authority.activationAuthorized -and -not [bool]$cohort.authority.xmlAuthorized -and -not [bool]$cohort.authority.productionAuthorized) 'R18R cohort authority changed.'

$pathGate = Get-Content -Raw -LiteralPath $pathGatePath | ConvertFrom-Json
Require ([string]$pathGate.schema -eq 'argos_opencv_scribe_r18r_exact_membership_path_plan_v1' -and [string]$pathGate.requestId -eq $requestId) 'R18R path plan identity changed.'
Require ([int]$pathGate.plannedFinalZipMemberCount -eq 31 -and [string]$pathGate.plannedFinalZipMemberSetSha256 -eq $expectedLeafSetSha -and [int]$pathGate.payloadManifestFileCount -eq 27 -and [int]$pathGate.pythonEngineSourceCount -eq 15) 'R18R path plan membership changed.'
Require ([int]$pathGate.expandedCandidateCount -eq 147 -and [int]$pathGate.maximumEffectiveLength -eq 196 -and [int]$pathGate.unsafePathCount -eq 0) 'R18R path plan budget changed.'

$referenceGateResult = (& $localPython -B $referenceGateTest --runner $r18rRunnerPath --payload-manifest $payloadManifestPath --project-root $project --cohort $cohortPath --base-bundle $localRefs --base-bundle-sha256 '56DF00E37A195E7BC3E026E4950DFB5A0AA7E7AF49A6FF39020B071840CCFBD6' --base-manifest-sha256 'AECAF49BD0ACFC07C4B2973AF1889ABD9F3708C1411820A667FD6330B90F1229' --supplemental-manifest (Join-Path $project 'work\OPENCV_SCRIBE_R18F\reference_bank\SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json') --supplemental-manifest-sha256 'FD60D494A25B489A8F1D8581217457AD67B02C98D54CA0A5400FAC0611537114' | Out-String) | ConvertFrom-Json
Require ([string]$referenceGateResult.state -eq 'PASS_R18R_REFERENCE_ISOLATION_LOCAL_GATE' -and [bool]$referenceGateResult.packageExcluded -and [int]$referenceGateResult.caseCount -eq 21 -and [int]$referenceGateResult.uniqueSourcePairCount -eq 21 -and [int]$referenceGateResult.knownTruthControlCount -eq 2 -and [int]$referenceGateResult.engineSourceCount -eq 15 -and [int]$referenceGateResult.engineHashMismatchCount -eq 0 -and [int]$referenceGateResult.hardCodedEngineLiteralCount -eq 0 -and [int]$referenceGateResult.configurationLiteralLeakCount -eq 0 -and [int]$referenceGateResult.sameLineageReferenceSurvivorCount -eq 0 -and -not [bool]$referenceGateResult.imageBytesRead -and -not [bool]$referenceGateResult.mutationsPerformed) 'R18R executable package-excluded reference-isolation gate failed.'

# If a later builder revision supplies every frozen prerequisite and exact
# preaction pin, its preflight remains non-mutating and avoids signer access.
if ($Preflight) {
    [ordered]@{
        schema='argos_opencv_scribe_r18r_build_preflight_v1';createdUtc=[DateTime]::UtcNow.ToString('o');
        state='PASS_R18R_BUILD_PREFLIGHT';requestId=$requestId;
        definitionState=[string]$definition.state;cohortState=[string]$cohort.state;pathPlanLifecycle=[string]$pathGate.artifactLifecycle;
        preactionExactPinEstablished=(-not [string]::IsNullOrWhiteSpace($preactionSha));
        cohortBindingExactPinEstablished=(-not [string]::IsNullOrWhiteSpace($cohortBindingGateSha));
        payloadManifestFileCount=27;packagedPayloadFileCount=29;pythonEngineSourceCount=15;
        finalZipMemberCount=31;expandedCandidateCount=147;maximumEffectiveLength=196;
        semanticBaselineSha256=$semanticBaselineSha;semiM12MethodSha256=$semiMethodSha;
        canonicalVectorSha256=$canonicalVectorSha;canonicalVectorCount=19;canonicalVectorPassCount=19;
        localGateSha256=$localGateSha;pathPlanGateSha256=$pathGateSha;sourceRuntimeAllowlist=$sourceRuntimeGate;
        cohortBindingGateSha256=$cohortBindingGateSha;referenceIsolationGateSha256=$referenceIsolationGateSha;
        signerIdentityAccessed=$false;certificateAccessed=$false;privateKeyAccessed=$false;
        publicationAuthorized=$false;mutationsPerformed=$false;targetExecuted=$false;
        reviewOnly=$true;productionRoutingEnabled=$false
    } | ConvertTo-Json -Depth 16
    return
}

Require ([string]$definition.state -eq 'FROZEN_UNPUBLISHED') 'R18R Build is blocked while the maintenance definition is DRAFT.'
Require ([string]$cohort.state -eq 'FROZEN_CONFIGURATION_SELECTED_COHORT') 'R18R Build is blocked while the cohort is DRAFT.'
Require ([string]$pathGate.artifactLifecycle -eq 'FROZEN') 'R18R Build is blocked while the path plan is DRAFT.'
Require ([string]$cohortBindingGate.artifactLifecycle -eq 'FROZEN') 'R18R Build is blocked while the cohort-binding gate is DRAFT.'
Require ([string]$referenceIsolationGate.artifactLifecycle -eq 'FROZEN') 'R18R Build is blocked while the reference-isolation gate is DRAFT.'
Require (-not [string]::IsNullOrWhiteSpace($preactionSha)) 'R18R Build is blocked until the exact preaction gate hash is pinned in a new builder revision.'
Require-Pin $preactionPath $preactionSha 'PASS_PREACTION_CONTRACT'
Require-Pin $cohortBindingGatePath $cohortBindingGateSha 'PASS_R18R_COHORT_BINDING_GATE'
$preactionResult = (& $preactionTool -AuditPath $historyAudit -ContractPath $preactionPath -ProjectRoot $project -Preflight | Out-String) | ConvertFrom-Json
Require ([string]$preactionResult.state -eq 'PASS_ARGOS_ZERO_RECURRENCE_PREACTION') 'R18R preaction gate changed.'

# Signing material is inaccessible until every gate above passes.
Require-Pin $identityPath $identitySha
Require-Pin $publicCertificate $certificateSha
Require-Pin $packageTester $testerSha
$identity = Get-Content -Raw -LiteralPath $identityPath | ConvertFrom-Json
$thumbprint = ([string]$identity.thumbprint).Replace(' ','').ToUpperInvariant()
$store = New-Object Security.Cryptography.X509Certificates.X509Store('My', [Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)
$store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
try {
    $matches = @($store.Certificates | Where-Object { ([string]$_.Thumbprint).Replace(' ','').ToUpperInvariant() -eq $thumbprint })
    Require ($matches.Count -eq 1 -and $matches[0].HasPrivateKey) 'R18R signer certificate or private key changed.'
    $certificate = $matches[0]
}
finally { $store.Close(); $store.Dispose() }

foreach ($path in @($stageRoot,$readyRoot,$stageZip,$verifyRoot,$finalRoot,$finalPartial,$finalGatePath)) {
    Require (-not (Test-Path -LiteralPath $path)) "R18R build fresh output exists: $path"
}

[void](New-Item -ItemType Directory -Path (Join-Path $readyRoot 'payload\files'))
Copy-Item -LiteralPath $entrypoint -Destination (Join-Path $readyRoot 'payload\Invoke-R18RReferenceIsolatedLaunch.ps1')
Copy-Item -LiteralPath $payloadManifestPath -Destination (Join-Path $readyRoot 'payload\R18R_PAYLOAD_MANIFEST.json')
$manifestFiles = New-Object Collections.Generic.List[object]
$manifestFiles.Add([ordered]@{path='payload/Invoke-R18RReferenceIsolatedLaunch.ps1';bytes=[int64](Get-Item -LiteralPath $entrypoint).Length;sha256=$entrypointSha})
$manifestFiles.Add([ordered]@{path='payload/R18R_PAYLOAD_MANIFEST.json';bytes=[int64](Get-Item -LiteralPath $payloadManifestPath).Length;sha256=$payloadManifestSha})
foreach ($file in $payloadFiles) {
    $source = Join-Path $project ([string]$file.sourcePath).Replace('/','\')
    $packagePath = 'payload/files/' + [string]$file.installRelativePath
    $destination = Join-Path $readyRoot $packagePath.Replace('/','\')
    [void](New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force)
    Copy-Item -LiteralPath $source -Destination $destination
    $manifestFiles.Add([ordered]@{path=$packagePath;bytes=[int64]$file.bytes;sha256=[string]$file.sha256})
}
Require ($manifestFiles.Count -eq 29) 'R18R signed request payload-file cardinality changed.'
$created = [DateTimeOffset]::UtcNow
$requestManifest = [ordered]@{
    schema='argos_project_portal_request_manifest_v1';requestId=$requestId;createdUtc=$created.ToString('o');expiresUtc=$created.AddHours(24).ToString('o');
    targetRole='JBOD';jobClass='MAINTENANCE_PATCH';handler='';maxResultBytes=[int64]$definition.maxResultBytes;
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;
    credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=$manifestFiles.ToArray();
    entryPoint=[string]$definition.entryPoint;changes=@($definition.changes);entryPointMutations=@($definition.entryPointMutations);
    entryPointOutputs=@($definition.entryPointOutputs);sourceProcessingContract=$definition.sourceProcessingContract;
    timeoutContract=$definition.timeoutContract;allowedTaskActions=@($definition.allowedTaskActions);
    allowedProcessActions=@($definition.allowedProcessActions);publication=$definition.publication
}
$requestManifestPath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.json'
$signaturePath = Join-Path $readyRoot 'PORTAL_REQUEST_MANIFEST.sig'
$utf8 = New-Object Text.UTF8Encoding($false)
$manifestBytes = $utf8.GetBytes(($requestManifest | ConvertTo-Json -Depth 32))
[IO.File]::WriteAllBytes($requestManifestPath, $manifestBytes)
$rsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
try { $signature = $rsa.SignData($manifestBytes, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1) }
finally { $rsa.Dispose() }
[IO.File]::WriteAllBytes($signaturePath, $signature)
$packageTest = & $packageTester -PackagePath $readyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$packageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18R signed package verification failed.'

Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($readyRoot, $stageZip, [IO.Compression.CompressionLevel]::Optimal, $false)
[IO.Compression.ZipFile]::ExtractToDirectory($stageZip, $verifyRoot)
$extracted = @(Get-ChildItem -LiteralPath $verifyRoot -Recurse -File)
Require ($extracted.Count -eq 31) 'R18R extracted final ZIP file count changed.'
foreach ($row in $manifestFiles) {
    $path = Join-Path $verifyRoot ([string]$row.path).Replace('/','\')
    Require-Pin $path ([string]$row.sha256)
    Require ((Get-Item -LiteralPath $path).Length -eq [int64]$row.bytes) "R18R extracted payload length changed: $($row.path)"
}
Require-Pin (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.json') (Get-Sha256 $requestManifestPath)
Require-Pin (Join-Path $verifyRoot 'PORTAL_REQUEST_MANIFEST.sig') (Get-Sha256 $signaturePath)
$exactPackageTest = & $packageTester -PackagePath $verifyRoot -SignerCertificatePath $publicCertificate -ExpectedTargetRole JBOD -ExpectedJobClass MAINTENANCE_PATCH
Require ([string]$exactPackageTest.State -eq 'PASS_SIGNED_PORTAL_PACKAGE') 'R18R extracted signed package verification failed.'
$actualLeaves = @($extracted | ForEach-Object { $_.FullName.Substring($verifyRoot.Length + 1).Replace('\','/') } | Sort-Object)
$actualLeafSetSha = Get-TextSha256 (($actualLeaves -join "`n") + "`n")
Require ($actualLeaves.Count -eq 31 -and $actualLeafSetSha -eq $expectedLeafSetSha) 'R18R final ZIP membership differs from the path plan.'
$extractedRuntimeGate = Confirm-R18RRuntimeAllowlist 'EXTRACTED_FINAL_ZIP' $payloadFiles $expectedLeaves $verifyRoot

$priorFailureLeaf = 'payload/files/OPENCV_SCRIBE_R18F/reference_bank/SUPPLEMENTAL_GLYPH_REFERENCE_MANIFEST.json'
Require ($actualLeaves -contains $priorFailureLeaf) 'R18R prior failing leaf is absent from exact enumeration.'
$expandedRoots = @($readyRoot,$verifyRoot,'C:\ProgramData\ArgosProjectPortalRO\endpoint_jbod\pending\REQ_R18R1.ready')
$pathRows = New-Object Collections.Generic.List[object]
foreach ($expandedRoot in $expandedRoots) {
    foreach ($leaf in $actualLeaves) {
        $candidate = [IO.Path]::Combine($expandedRoot, $leaf.Replace('/','\'))
        $parts = @($candidate.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
        $component = if ($parts.Count -eq 0) { 0 } else { [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum) }
        $pathRows.Add([pscustomobject]@{path=$candidate;length=$candidate.Length;effectiveLength=$candidate.Length+32;maximumComponentLength=$component})
    }
}
foreach ($workRoot in @('D:\A2\w\ocv\R18R1.partial','D:\A2\w\ocv\R18R1')) {
    foreach ($file in $payloadFiles) {
        $candidate = [IO.Path]::Combine($workRoot, ([string]$file.installRelativePath).Replace('/','\'))
        $parts = @($candidate.Split([char[]]@('\','/'), [StringSplitOptions]::RemoveEmptyEntries))
        $component = [int](($parts | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum)
        $pathRows.Add([pscustomobject]@{path=$candidate;length=$candidate.Length;effectiveLength=$candidate.Length+32;maximumComponentLength=$component})
    }
}
$longest = @($pathRows | Sort-Object effectiveLength -Descending | Select-Object -First 1)[0]
Require ($pathRows.Count -eq 147) 'R18R exact expanded path cardinality changed.'
Require ([int]$longest.effectiveLength -eq 196 -and [int]$longest.effectiveLength -lt 200) "R18R exact final ZIP member path budget changed: $($longest.path)"
Require ([int](($pathRows | Measure-Object maximumComponentLength -Maximum).Maximum) -le 80) 'R18R exact final ZIP member component exceeds path budget.'
$packagedPreflight = (& (Join-Path $verifyRoot 'payload\Invoke-R18RReferenceIsolatedLaunch.ps1') -Preflight -Rehearsal -PayloadRoot (Join-Path $verifyRoot 'payload') -WorkRoot 'C:\R18RFW' -OutputRoot 'C:\R18RFO' -ProposalRoot $localProposals -PythonPath $localPython -ExpectedPythonSha256 $localPythonSha -ReferenceBundlePath $localRefs -ExpectedComputerName $env:COMPUTERNAME | Out-String) | ConvertFrom-Json
Require ([string]$packagedPreflight.state -eq 'PASS_R18R_REFERENCE_ISOLATED_LAUNCH_PREFLIGHT' -and -not [bool]$packagedPreflight.mutationsPerformed -and -not [bool]$packagedPreflight.processStarted -and [bool]$packagedPreflight.checksumVerificationRequired -and -not [bool]$packagedPreflight.checksumUsedForImageFirst -and [int]$packagedPreflight.runtimeOverrideCount -eq 0) 'R18R exact packaged entrypoint preflight failed.'

[void](New-Item -ItemType Directory -Path $finalPartial)
Copy-Item -LiteralPath $stageZip -Destination (Join-Path $finalPartial $zipName)
Copy-Item -LiteralPath $pathGatePath -Destination (Join-Path $finalPartial ($zipName + '.path_gate.json'))
Copy-Item -LiteralPath $localGatePath -Destination (Join-Path $finalPartial ($zipName + '.local_gate.json'))
Copy-Item -LiteralPath $cohortBindingGatePath -Destination (Join-Path $finalPartial ($zipName + '.cohort_binding_gate.json'))
Copy-Item -LiteralPath $referenceIsolationGatePath -Destination (Join-Path $finalPartial ($zipName + '.reference_isolation_gate.json'))
$packagedRuntimeGatePath = Join-Path $finalPartial 'R18R_PACKAGED_RUNTIME_GATE.json'
$packagedRuntimeGate = [ordered]@{
    schema='argos_opencv_scribe_r18r_packaged_runtime_gate_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R_PACKAGED_RUNTIME_GATE';
    requestId=$requestId;requestZipSha256=Get-Sha256 $stageZip;requestManifestSha256=Get-Sha256 $requestManifestPath;
    finalZipMemberCount=31;finalZipMemberSetSha256=$actualLeafSetSha;payloadManifestFileCount=27;pythonEngineSourceCount=15;
    sourcePreSignerAllowlist=$sourceRuntimeGate;extractedFinalZipAllowlist=$extractedRuntimeGate;
    semanticBaselineSha256=$semanticBaselineSha;semiM12MethodSha256=$semiMethodSha;canonicalVectorSha256=$canonicalVectorSha;
    canonicalVectorCount=19;canonicalVectorPassCount=19;checksumVerificationRequired=$true;checksumUsedForImageFirst=$false;
    runtimeOverrideCount=0;testArtifactCount=0;identityAccepted=$false;sourceImagesRead=$false;targetExecuted=$false;
    reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonNew $packagedRuntimeGatePath $packagedRuntimeGate 32
$packagedRuntimeGateSha = Get-Sha256 $packagedRuntimeGatePath

$exactRouteGatePath = Join-Path $finalPartial ($zipName + '.complete_route_gate.json')
$exactRouteGate = [ordered]@{
    schema='argos_opencv_scribe_r18r_complete_route_gate_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R_COMPLETE_ROUTE_GATE';
    requestId=$requestId;requestZipSha256=Get-Sha256 $stageZip;requestZipBytes=[int64](Get-Item -LiteralPath $stageZip).Length;
    requestManifestSha256=Get-Sha256 $requestManifestPath;pathPlanGateSha256=$pathGateSha;
    actualFinalZipMemberCount=$actualLeaves.Count;actualFinalZipMemberSetSha256=$actualLeafSetSha;actualFinalZipMembers=$actualLeaves;
    actualPriorFailureLeafIncluded=$true;expandedRootCount=$expandedRoots.Count;expandedCandidateCount=$pathRows.Count;
    maximumPathLength=[int]$longest.length;maximumEffectiveLength=[int]$longest.effectiveLength;
    maximumComponentLength=[int](($pathRows | Measure-Object maximumComponentLength -Maximum).Maximum);
    longestConstructedLeaf=[string]$longest.path;reservedSuffixCharacters=32;unsafePathCount=0;
    entrypointDefaultsMatchDefinition=$true;queueState='NOT_OBSERVED_BY_LOCAL_BUILDER';pendingRequestCount=$null;requestNamespaceState='NOT_OBSERVED';
    publicationMustRecheckQueueAndNamespace=$true;
    publicationAuthorized=$false;explicitPublishStillRequired=$true;maximumRequests=1;retryAuthorized=$false;
    sourceMutationAllowed=$false;identityAcceptanceAuthorized=$false;readerModified=$false;referenceLibraryModified=$false;
    reviewOnly=$true;productionRoutingEnabled=$false
}
Write-JsonNew $exactRouteGatePath $exactRouteGate 32
$exactRouteGateSha = Get-Sha256 $exactRouteGatePath
$finalGate = [ordered]@{
    schema='argos_opencv_scribe_r18r_final_package_gate_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_R18R_FINAL_PACKAGE_GATE';
    requestId=$requestId;requestZip=('work/OPENCV_SCRIBE_R18R/final/'+$zipName);
    requestZipBytes=[int64](Get-Item -LiteralPath $stageZip).Length;requestZipSha256=Get-Sha256 $stageZip;
    requestManifestSha256=Get-Sha256 $requestManifestPath;requestSignatureSha256=Get-Sha256 $signaturePath;
    entrypointSha256=$entrypointSha;payloadManifestSha256=$payloadManifestSha;definitionSha256=$definitionSha;
    cohortSha256=$cohortSha;localGateSha256=$localGateSha;pathPlanGateSha256=$pathGateSha;
    preactionSha256=$preactionSha;cohortBindingGateSha256=$cohortBindingGateSha;referenceIsolationGateSha256=$referenceIsolationGateSha;
    completeRouteGateSha256=$exactRouteGateSha;packagedRuntimeGatePath='work/OPENCV_SCRIBE_R18R/final/R18R_PACKAGED_RUNTIME_GATE.json';
    packagedRuntimeGateSha256=$packagedRuntimeGateSha;semanticBaselineSha256=$semanticBaselineSha;
    semiM12MethodSha256=$semiMethodSha;canonicalVectorSha256=$canonicalVectorSha;canonicalVectorCount=19;canonicalVectorPassCount=19;
    payloadManifestFileCount=27;packagedPayloadFileCount=29;finalZipFileCount=31;engineSourceCount=15;
    hardCodedEngineLiteralCount=0;configurationLiteralLeakCount=0;runtimeTestArtifactCount=0;runtimeOverrideCount=0;
    exactFinalZipExtractionPassed=$true;exactFinalZipSignaturePassed=$true;exactPackagedEntrypointPreflightPassed=$true;
    packagedPreflightState=[string]$packagedPreflight.state;finalZipMemberSetSha256=$actualLeafSetSha;
    expandedCandidateCount=147;maximumEffectiveLength=[int]$longest.effectiveLength;
    checksumVerificationRequired=$true;checksumUsedForImageFirst=$false;publicationAuthorized=$false;
    explicitPublishStillRequired=$true;maximumPublications=1;retryAuthorized=$false;targetExecuted=$false;sourceImagesRead=$false;
    backgroundProcessStarted=$false;identityAccepted=$false;readerModified=$false;referenceLibraryModified=$false;
    reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false
}
Write-JsonNew $finalGatePath $finalGate 32
Move-Item -LiteralPath $finalPartial -Destination $finalRoot
$finalGate | ConvertTo-Json -Depth 32
