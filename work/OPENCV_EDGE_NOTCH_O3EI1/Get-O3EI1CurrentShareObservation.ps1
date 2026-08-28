#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$Gate
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Gate)) { throw 'Specify exactly one of Preflight or Gate.' }

$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$requestId = 'REQ_20260828T143500111Z_O3EI1R01'
$uncRoot = '\\shm-cifs\Department\DE-1302_FAB_BE_Engineering\60_Saw_VI_Sort\600_General\Joshua.conn\AVI_Images\Argos\Uploads\InspectionRevs'
$requestsRoot = 'U:\ProjectPortalRO\requests'
$responsesRoot = 'U:\ProjectPortalRO\responses'
$target = Join-Path $requestsRoot ($requestId + '.ready.zip')
$upload = $target + '.upload'
$priorResponse = Join-Path $responsesRoot 'R_1B7D26E4FA16_20260828034551022_4d1f22f6.ready.zip'
$observationPath = Join-Path $PSScriptRoot 'O3EI1_CURRENT_SHARE_OBSERVATION.json'
$aliasGatePath = Join-Path $PSScriptRoot 'O3EI1_INSPECTIONREVS_U_ALIAS_GATE.json'
$pathTool = Join-Path $project 'utilities\Confirm-ArgosPathBudget.ps1'
$utf8 = New-Object Text.UTF8Encoding($false)

function Assert-True([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) { $stream=[IO.File]::OpenRead($Path);$sha256=[Security.Cryptography.SHA256]::Create();try{return([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','')}finally{$sha256.Dispose();$stream.Dispose()} }
function Write-NewJson([string]$Path,[object]$Value) { Assert-True (-not (Test-Path -LiteralPath $Path)) "O3EI1 create-new share evidence exists: $Path";[IO.File]::WriteAllText($Path,(($Value|ConvertTo-Json -Depth 8)+[Environment]::NewLine),$utf8) }

$drive = Get-PSDrive -Name U -PSProvider FileSystem -ErrorAction Stop
$displayRoot = ([string]$drive.DisplayRoot).TrimEnd('\')
Assert-True ($displayRoot.Equals($uncRoot,[StringComparison]::OrdinalIgnoreCase)) 'O3EI1 U: PowerShell DisplayRoot changed.'
Assert-True (Test-Path -LiteralPath $requestsRoot -PathType Container) 'O3EI1 requests root is unreadable.'
Assert-True (Test-Path -LiteralPath $responsesRoot -PathType Container) 'O3EI1 responses root is unreadable.'
$requestFiles = @(Get-ChildItem -LiteralPath $requestsRoot -File -Force -ErrorAction Stop | Select-Object -First 21)
Assert-True ($requestFiles.Count -le 20) 'O3EI1 top-level request observation exceeded 20 files.'
$readyRows = @($requestFiles | Where-Object { $_.Name.EndsWith('.ready.zip',[StringComparison]::OrdinalIgnoreCase) })
$uploadRows = @($requestFiles | Where-Object { $_.Name.EndsWith('.upload',[StringComparison]::OrdinalIgnoreCase) })
Assert-True ($readyRows.Count -eq 0 -and $uploadRows.Count -eq 0) 'O3EI1 share has a pending request or upload.'
Assert-True (-not (Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $upload)) 'O3EI1 target request or upload already exists.'
Assert-True (Test-Path -LiteralPath $priorResponse -PathType Leaf) 'O3EI1 prior O3Q2 response is absent.'
Assert-True ((Get-Item -LiteralPath $priorResponse).Length -eq 2620 -and (Get-Sha256 $priorResponse) -eq '519E0B1C9EB6A2F0EE036E356E9CDB1FC3A6D72D0B38DF9AE7831CCF25C2A23E') 'O3EI1 prior O3Q2 response changed.'
$aliasBudget = & $pathTool -CandidatePath @($target,$upload,$observationPath,$aliasGatePath) -ProjectRoot $project -ReservedSuffixCharacters 32 -AsJson | ConvertFrom-Json
Assert-True ([string]$aliasBudget.state -eq 'PASS_PATH_BUDGET' -and @($aliasBudget.candidates).Count -eq 4) 'O3EI1 alias path budget failed.'
$rawTarget = Join-Path (Join-Path $uncRoot 'ProjectPortalRO\requests') ($requestId + '.ready.zip')
$rawUpload = $rawTarget + '.upload'
$componentRows = @(@($target,$upload) | ForEach-Object { @($_.Split([IO.Path]::DirectorySeparatorChar) | ForEach-Object Length | Measure-Object -Maximum).Maximum })
$maxComponent = [int](($componentRows | Measure-Object -Maximum).Maximum)
$now = [DateTime]::UtcNow.ToString('o')
$normalizedRoot = $uncRoot.Replace('\','/')
$observation = [ordered]@{schema='argos_o3ei1_current_share_observation_v1';observedUtc=$now;state='PASS_O3EI1_CURRENT_SHARE_ZERO_PENDING';alias='U:';aliasRoot=$normalizedRoot;powerShellDisplayRootExact=$true;requestsRoot=$requestsRoot.Replace('\','/');responsesRoot=$responsesRoot.Replace('\','/');requestsRootReadable=$true;responsesRootReadable=$true;topLevelPendingReadyZipCount=$readyRows.Count;topLevelPendingUploadCount=$uploadRows.Count;targetAbsent=$true;uploadAbsent=$true;priorO3Q2ResponsePresent=$true;priorO3Q2ResponseBytes=2620;priorO3Q2ResponseSha256='519E0B1C9EB6A2F0EE036E356E9CDB1FC3A6D72D0B38DF9AE7831CCF25C2A23E';requestId=$requestId;targetExecuted=$false;remoteMutationsPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false}
$aliasGate = [ordered]@{schema='argos_o3ei1_publication_alias_gate_v1';createdUtc=$now;state='PASS_O3EI1_EXACT_INSPECTIONREVS_U_ALIAS_GATE';alias='U:';aliasRoot=$normalizedRoot;aliasResolvedExact=$true;persistentMappingVerified=$true;requestsRootReadable=$true;rawUncTargetLength=$rawTarget.Length;rawUncTargetEffectiveLength=($rawTarget.Length+32);rawUncUploadLength=$rawUpload.Length;rawUncUploadEffectiveLength=($rawUpload.Length+32);rawUncDisposition='HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH';aliasTarget=$target.Replace('\','/');aliasTargetLength=$target.Length;aliasTargetEffectiveLength=($target.Length+32);aliasUpload=$upload.Replace('\','/');aliasUploadLength=$upload.Length;aliasUploadEffectiveLength=($upload.Length+32);maximumComponentLength=$maxComponent;aliasPathBudgetState='PASS_PATH_BUDGET';pendingRequestCountAtGate=0;targetAbsentAtGate=$true;uploadAbsentAtGate=$true;publicationPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false}
if ($Preflight) { [ordered]@{schema='argos_o3ei1_current_share_observation_preflight_v1';checkedUtc=$now;state='PASS_O3EI1_CURRENT_SHARE_OBSERVATION_PREFLIGHT';pendingRequestCount=0;targetAbsent=$true;uploadAbsent=$true;persistentMappingVerified=$true;remoteMutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5;return }
Write-NewJson $observationPath $observation
Write-NewJson $aliasGatePath $aliasGate
[ordered]@{schema='argos_o3ei1_current_share_observation_result_v1';createdUtc=$now;state='PASS_O3EI1_CURRENT_SHARE_OBSERVATION_WRITTEN';observationSha256=Get-Sha256 $observationPath;aliasGateSha256=Get-Sha256 $aliasGatePath;remoteMutationsPerformed=$false;mappingRemoved=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 5
