#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InvocationManifest,
    [switch]$Preflight,
    [switch]$Build
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (([bool]$Preflight) -eq ([bool]$Build)) { throw 'Specify exactly one of -Preflight or -Build.' }

$root = [IO.Path]::GetFullPath($PSScriptRoot)
$consumer = Join-Path $root 'Build-O2D23Request.ps1'
$gate = Join-Path $root 'O2D23_FINAL_PACKAGE_GATE.json'
$signed = Join-Path $root 'signed'
$final = Join-Path $root 'final'

function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha256.ComputeHash($stream))).Replace('-','') }
    finally { $sha256.Dispose(); $stream.Dispose() }
}

$manifestPath = [IO.Path]::GetFullPath($InvocationManifest)
Assert-True ($manifestPath.StartsWith($root.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) 'O2D23 build invocation manifest must remain under the exact draft root.'
Assert-True (Test-Path -LiteralPath $manifestPath -PathType Leaf) 'O2D23 build invocation manifest absent.'
$invocation = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
Assert-True ([string]$invocation.schema -eq 'argos_o2d23_build_request_invocation_v1') 'O2D23 build invocation schema changed.'
Assert-True ([string]$invocation.revision -eq 'O2D23_20260827T035500000Z_3C97863D') 'O2D23 build invocation revision changed.'
Assert-True ([string]$invocation.requestId -eq 'REQ_20260827T035500111Z_3C97863DBF26') 'O2D23 build invocation request changed.'
Assert-True (@($invocation.allowedActions).Count -eq 2 -and @($invocation.allowedActions) -contains 'Preflight' -and @($invocation.allowedActions) -contains 'Build') 'O2D23 build invocation action set changed.'
Assert-True ([int]$invocation.maximumPublications -eq 1 -and -not [bool]$invocation.retryAuthorized -and [bool]$invocation.reviewOnly -and -not [bool]$invocation.productionRoutingEnabled) 'O2D23 build invocation authority changed.'

$command = Get-Command -Name $consumer -CommandType ExternalScript -ErrorAction Stop
Assert-True ($command.Parameters.Keys -contains 'Preflight' -and $command.Parameters.Keys -contains 'Build') 'O2D23 build paired-consumer arguments changed.'
Assert-True ((Get-Sha256 $consumer) -eq 'F76522539AA455AB91B753F1211FA2AEF6972897CD5DB1B86BD3409FD03D7C7C') 'O2D23 build paired consumer changed.'
Assert-True (-not (Test-Path -LiteralPath $gate) -and -not (Test-Path -LiteralPath $signed) -and -not (Test-Path -LiteralPath $final)) 'O2D23 build outputs already exist.'

$consumerPreflight = (& $consumer -Preflight | Out-String) | ConvertFrom-Json
Assert-True ([string]$consumerPreflight.state -eq 'PASS_O2D23_BUILD_PREFLIGHT' -and -not [bool]$consumerPreflight.mutationsPerformed) 'O2D23 build consumer preflight changed.'
if ($Preflight) {
    [ordered]@{schema='argos_o2d23_build_request_orchestrator_preflight_v1';checkedUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_BUILD_REQUEST_ORCHESTRATOR_PREFLIGHT';requestId=[string]$consumerPreflight.requestId;namedArgumentsResolvedByGetCommand=$true;consumerState=[string]$consumerPreflight.state;mutationsPerformed=$false;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
    return
}

$result = (& $consumer -Build | Out-String) | ConvertFrom-Json
Assert-True ([string]$result.state -eq 'PASS_O2D23_FINAL_PACKAGE_GATE') 'O2D23 build consumer result changed.'
Assert-True ([string]$result.validationQualification -eq 'INDEPENDENT_VALIDATION_OUTCOME_BLIND_METADATA_DISCLOSED') 'O2D23 build qualification changed.'
Assert-True ([bool]$result.slot25SourceMetadataPrematurelyExposed -and -not [bool]$result.slot25ImageBytesRead -and -not [bool]$result.slot25OutcomeSeen) 'O2D23 build blindness disclosure changed.'
Assert-True (Test-Path -LiteralPath $gate -PathType Leaf) 'O2D23 final package gate was not written.'
[ordered]@{schema='argos_o2d23_build_request_orchestrator_result_v1';createdUtc=[DateTime]::UtcNow.ToString('o');state='PASS_O2D23_SIGNED_REQUEST_BUILT';requestId=[string]$result.requestId;namedArgumentsResolvedByGetCommand=$true;gateSha256=Get-Sha256 $gate;requestZipSha256=[string]$result.requestZipSha256;validationQualification=[string]$result.validationQualification;maximumPublications=1;retryAuthorized=$false;slot25ImageBytesRead=$false;slot25OutcomeSeen=$false;providerActivated=$false;reviewOnly=$true;productionRoutingEnabled=$false} | ConvertTo-Json -Depth 5
