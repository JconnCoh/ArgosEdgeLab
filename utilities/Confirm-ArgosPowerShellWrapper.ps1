[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PowerShellScript,
    [string]$CmdWrapper,
    [string]$InvocationManifest,
    [ValidateRange(1024, 1048576)]
    [int]$MaximumManifestBytes = 1048576,
    [switch]$RequirePreflightSwitch,
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RequiredFile {
    param(
        [Parameter(Mandatory = $true)][string]$Value,
        [Parameter(Mandatory = $true)][string]$ExpectedExtension,
        [Parameter(Mandatory = $true)][string]$Label
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        throw "$Label path is null or empty."
    }
    if ($Value.IndexOfAny([char[]]'*?') -ge 0) {
        throw "$Label path contains a wildcard: $Value"
    }
    if (-not (Test-Path -LiteralPath $Value -PathType Leaf)) {
        throw "$Label does not exist: $Value"
    }
    $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Value).Path)
    if ([IO.Path]::GetExtension($resolved) -ine $ExpectedExtension) {
        throw "$Label must have a $ExpectedExtension extension: $resolved"
    }
    return $resolved
}

function Read-BoundedUtf8File {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][long]$MaximumBytes,
        [Parameter(Mandatory = $true)][string]$Label
    )
    $length = (Get-Item -LiteralPath $Path).Length
    if ($length -gt $MaximumBytes) {
        throw "$Label is too large for wrapper preflight: $length bytes exceeds $MaximumBytes."
    }
    $bytes = [IO.File]::ReadAllBytes($Path)
    $utf8 = New-Object Text.UTF8Encoding($false, $true)
    try {
        $text = $utf8.GetString($bytes)
    }
    catch {
        throw "$Label is not valid UTF-8: $Path"
    }
    return $text.TrimStart([char]0xFEFF)
}

function Assert-NoPowerShellBooleanStrings {
    param(
        $Value,
        [Parameter(Mandatory = $true)][string]$JsonPath
    )
    if ($null -eq $Value) {
        return
    }
    if ($Value -is [string]) {
        if ($Value -ceq '$true' -or $Value -ceq '$false') {
            throw "Invocation manifest contains serialized PowerShell Boolean text at ${JsonPath}: $Value"
        }
        return
    }
    if (
        $Value -is [bool] -or
        $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64] -or
        $Value -is [single] -or
        $Value -is [double] -or
        $Value -is [decimal] -or
        $Value -is [datetime]
    ) {
        return
    }
    if ($Value -is [System.Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            Assert-NoPowerShellBooleanStrings -Value $Value[$key] -JsonPath "$JsonPath.$key"
        }
        return
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        $index = 0
        foreach ($item in $Value) {
            Assert-NoPowerShellBooleanStrings -Value $item -JsonPath "${JsonPath}[$index]"
            $index++
        }
        return
    }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.MemberType -in @('NoteProperty', 'Property')) {
            Assert-NoPowerShellBooleanStrings `
                -Value $property.Value `
                -JsonPath "$JsonPath.$($property.Name)"
        }
    }
}

$resolvedScript = Resolve-RequiredFile `
    -Value $PowerShellScript `
    -ExpectedExtension '.ps1' `
    -Label 'PowerShell script'

$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile(
    $resolvedScript,
    [ref]$tokens,
    [ref]$parseErrors
)
if (@($parseErrors).Count -gt 0) {
    $messages = @($parseErrors | ForEach-Object { $_.Message }) -join '; '
    throw "PowerShell script has parser errors: $messages"
}

$parameterNames = @()
if ($null -ne $ast.ParamBlock) {
    $parameterNames = @(
        $ast.ParamBlock.Parameters | ForEach-Object {
            $_.Name.VariablePath.UserPath
        }
    )
}
if (
    $RequirePreflightSwitch -and
    -not (
        $parameterNames -icontains 'Preflight' -or
        $parameterNames -icontains 'Rehearsal'
    )
) {
    throw 'PowerShell script must declare a Preflight or Rehearsal parameter.'
}

$resolvedManifest = $null
$manifestHash = $null
$manifestSchema = $null
if (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) {
    $resolvedManifest = Resolve-RequiredFile `
        -Value $InvocationManifest `
        -ExpectedExtension '.json' `
        -Label 'Invocation manifest'
    $manifestText = Read-BoundedUtf8File `
        -Path $resolvedManifest `
        -MaximumBytes $MaximumManifestBytes `
        -Label 'Invocation manifest'
    try {
        $manifest = $manifestText | ConvertFrom-Json
    }
    catch {
        throw "Invocation manifest is not valid JSON: $($_.Exception.Message)"
    }
    if ($null -eq $manifest -or $manifest -is [System.Collections.IEnumerable]) {
        throw 'Invocation manifest top level must be one JSON object.'
    }
    if (
        -not ($manifest.PSObject.Properties.Name -contains 'schema') -or
        [string]::IsNullOrWhiteSpace([string]$manifest.schema)
    ) {
        throw 'Invocation manifest must contain a non-empty schema property.'
    }
    if (-not ($parameterNames -icontains 'InvocationManifest')) {
        throw 'PowerShell script must declare InvocationManifest when a manifest is supplied.'
    }
    Assert-NoPowerShellBooleanStrings -Value $manifest -JsonPath '$'
    $manifestSchema = [string]$manifest.schema
    $manifestHash = (
        Get-FileHash -LiteralPath $resolvedManifest -Algorithm SHA256
    ).Hash
}

$resolvedWrapper = $null
if (-not [string]::IsNullOrWhiteSpace($CmdWrapper)) {
    $resolvedWrapper = Resolve-RequiredFile `
        -Value $CmdWrapper `
        -ExpectedExtension '.cmd' `
        -Label 'CMD wrapper'
    $cmdText = Read-BoundedUtf8File `
        -Path $resolvedWrapper `
        -MaximumBytes 65536 `
        -Label 'CMD wrapper'
    if ($cmdText -notmatch '(?i)%SystemRoot%\\System32\\WindowsPowerShell\\v1\.0\\powershell\.exe') {
        throw 'CMD wrapper must invoke the explicit Windows PowerShell 5.1 executable under %SystemRoot%.'
    }
    if ($cmdText -notmatch '(?i)-NoProfile(?:\s|$)') {
        throw 'CMD wrapper is missing -NoProfile.'
    }
    if ($cmdText -notmatch '(?i)-ExecutionPolicy\s+Bypass(?:\s|$)') {
        throw 'CMD wrapper is missing -ExecutionPolicy Bypass.'
    }
    if ($cmdText -notmatch '(?i)-File\s+"%ARGOS_SCRIPT%"(?:\s|$)') {
        throw 'CMD wrapper must pass exactly one quoted ARGOS_SCRIPT value after -File.'
    }
    if ($cmdText -notmatch '(?i)set\s+"ARGOS_SCRIPT=%~dp0[^"\r\n]+\.ps1"') {
        throw 'CMD wrapper must resolve ARGOS_SCRIPT from quoted %~dp0.'
    }
    if ($cmdText -notmatch '(?i)if\s+not\s+exist\s+"%ARGOS_SCRIPT%"') {
        throw 'CMD wrapper must refuse a missing ARGOS_SCRIPT before launch.'
    }
    if ($cmdText -match '%\*') {
        throw 'CMD wrapper must not forward arbitrary %* arguments.'
    }
    if ($cmdText -match '(?im)^\s*start(?:\s|$)' -or $cmdText -match '(?i)Start-Process') {
        throw 'CMD wrapper must not add a start/Start-Process process hop.'
    }
    if ($cmdText -match '(?i)powershell(?:\.exe)?[^\r\n]*\s-Command(?:\s|$)') {
        throw 'CMD wrapper must use -File, not -Command.'
    }
    $scriptLeaf = [regex]::Escape((Split-Path $resolvedScript -Leaf))
    if ($cmdText -notmatch "(?i)set\s+`"ARGOS_SCRIPT=%~dp0$scriptLeaf`"") {
        throw 'CMD wrapper ARGOS_SCRIPT does not identify the validated PowerShell script.'
    }
    if ($null -ne $resolvedManifest) {
        $manifestLeaf = [regex]::Escape((Split-Path $resolvedManifest -Leaf))
        if ($cmdText -notmatch "(?i)set\s+`"ARGOS_MANIFEST=%~dp0$manifestLeaf`"") {
            throw 'CMD wrapper ARGOS_MANIFEST does not identify the validated invocation manifest.'
        }
        if ($cmdText -notmatch '(?i)if\s+not\s+exist\s+"%ARGOS_MANIFEST%"') {
            throw 'CMD wrapper must refuse a missing ARGOS_MANIFEST before launch.'
        }
        if ($cmdText -notmatch '(?i)-InvocationManifest\s+"%ARGOS_MANIFEST%"(?:\s|$)') {
            throw 'CMD wrapper must pass the quoted invocation manifest path.'
        }
    }
}

$windowsPowerShell = Join-Path `
    $env:SystemRoot `
    'System32\WindowsPowerShell\v1.0\powershell.exe'
if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
    throw "Windows PowerShell 5.1 executable is missing: $windowsPowerShell"
}

$result = [pscustomobject]@{
    schema = 'argos_powershell_wrapper_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = 'PASS_ARGOS_POWERSHELL_WRAPPER_PREFLIGHT'
    metadataOnly = $true
    targetExecuted = $false
    windowsPowerShellExecutable = $windowsPowerShell
    powerShellScript = $resolvedScript
    powerShellScriptSha256 = (
        Get-FileHash -LiteralPath $resolvedScript -Algorithm SHA256
    ).Hash
    declaredParameters = $parameterNames
    preflightParameterRequired = [bool]$RequirePreflightSwitch
    cmdWrapper = $resolvedWrapper
    invocationManifest = $resolvedManifest
    invocationManifestSchema = $manifestSchema
    invocationManifestSha256 = $manifestHash
    arbitraryArgumentForwarding = $false
    startProcessWrapperHop = $false
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 6
}
else {
    $result | Format-List
}

