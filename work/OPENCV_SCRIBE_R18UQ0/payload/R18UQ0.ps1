[CmdletBinding()]
param(
    [switch]$Preflight
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$VerbosePreference = 'SilentlyContinue'
$DebugPreference = 'SilentlyContinue'

$script:ExpectedComputerName = 'DESKTOP-266P787'
$script:ExpectedTaskName = 'ArgosEdgeLab.InsiteBridge.Worker.ReviewOnly.V1'
$script:ExpectedTaskPath = '\'
$script:ExpectedWorkerPath = 'C:\ProgramData\ArgosInsiteBridgeRO\query\Invoke-ArgosAutomaticInsiteBridgeWorker.ps1'
$script:InstalledSelfPath = 'C:\ProgramData\ArgosInsiteBridgeRO\hotfixes\R18UQ0.ps1'
$script:ExpectedCredentialSchema = 'argos_insite_dpapi_machine_credential_v1'
$script:ExpectedEndpointConfigSchema = 'argos_project_portal_endpoint_config_v1'
$script:ExpectedSignerStoreLocation = 'LocalMachine'
$script:ExpectedSignerThumbprint = '5C00B8E35A9F5AC21DC051D7C2D9FD68D9361E48'
$script:ExpectedSignerDerSha256 = 'ED1AD2F0AB8377EF8303EB67947B7B86B074F318F90163A87BFD7DF03C978CB7'
$script:MaximumAggregateBase64SourceBytes = [int64]1572864
$script:MaximumJsonBytes = [int64]2750000
$script:MaximumHolds = 32
$script:MaximumTaskActionCount = 8
$script:MaximumTaskArgumentCharacters = 8192
$script:MaximumProtectedPasswordBytes = 24576
$script:MaximumEntropyBytes = 4096

$script:Rules = @(
    [pscustomobject]@{ path='C:\ProgramData\ArgosProjectPortalRO\config\endpoint_argos.json'; kind='endpointConfig'; includeBase64=$true; maximumBytes=[int64]65536 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'; kind='powershell'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\Invoke-ArgosAutomaticInsiteBridgeWorker.ps1'; kind='powershell'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\Invoke-ArgosPendingInsiteRequest.ps1'; kind='powershell'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\Invoke-ArgosCandidateInsiteRequest.ps1'; kind='powershell'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\Invoke-ArgosMesVisualStateSnapshot.ps1'; kind='powershell'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\ArgosInsiteRequestCanonical.psm1'; kind='powershellModule'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\ArgosScribeCandidateInsiteContract.psm1'; kind='powershellModule'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\ArgosCandidateSnapshotEnvelope.psm1'; kind='powershellModule'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\query\ArgosScribeCandidateMesResolver.psm1'; kind='powershellModule'; includeBase64=$true; maximumBytes=[int64]524288 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\bin\ArgosBoundRelay.InsiteBridge.ReviewOnly.V2_1.exe'; kind='relayBinary'; includeBase64=$false; maximumBytes=[int64]16777216 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\secrets\insite.credential.dpapi.json'; kind='credentialEnvelope'; includeBase64=$false; maximumBytes=[int64]65536 },
    [pscustomobject]@{ path='C:\ProgramData\ArgosInsiteBridgeRO\hotfixes\R18UQ0.ps1'; kind='self'; includeBase64=$false; maximumBytes=[int64]524288 }
)

function Get-NormalizedFixedPath {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not [IO.Path]::IsPathRooted($Path)) {
        throw "HARD_NON_ROOTED_PATH:$Path"
    }
    return [IO.Path]::GetFullPath($Path).TrimEnd([char[]]@('\'))
}

function Assert-StaticContract {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($rule in $script:Rules) {
        $normalized = Get-NormalizedFixedPath -Path ([string]$rule.path)
        if (-not $seen.Add($normalized)) {
            throw "Duplicate fixed read path: $normalized"
        }
        if ([int64]$rule.maximumBytes -le 0) {
            throw "Invalid byte cap for fixed read path: $normalized"
        }
    }
    if (@($script:Rules).Count -ne 13) { throw 'The fixed read rule count must be 13.' }
    if (@($script:Rules | Where-Object { [bool]$_.includeBase64 }).Count -ne 10) { throw 'The exact-source Base64 rule count must be 10.' }
    if (@($script:Rules | Where-Object { [string]$_.kind -eq 'credentialEnvelope' }).Count -ne 1) { throw 'The credential-envelope rule must be unique.' }
    if (@($script:Rules | Where-Object { [string]$_.kind -eq 'relayBinary' }).Count -ne 1) { throw 'The relay-binary rule must be unique.' }
    if (@($script:Rules | Where-Object { [string]$_.kind -eq 'self' }).Count -ne 1) { throw 'The self-install rule must be unique.' }
    if ($script:ExpectedSignerThumbprint -notmatch '^[0-9A-F]{40}$') { throw 'The endpoint signer thumbprint constant is malformed.' }
    if ($script:ExpectedSignerDerSha256 -notmatch '^[0-9A-F]{64}$') { throw 'The endpoint signer DER hash constant is malformed.' }
    if ($script:ExpectedSignerStoreLocation -ne 'LocalMachine') { throw 'The endpoint signer store must remain LocalMachine.' }
    if ($script:MaximumAggregateBase64SourceBytes -ge $script:MaximumJsonBytes) { throw 'The aggregate source-byte cap must remain below the final JSON cap.' }
}

Assert-StaticContract

if ($Preflight) {
    $preflightResult = [ordered]@{
        schema = 'argos_r18uq0_entrypoint_preflight_v1'
        state = 'PASS_R18UQ0_ENTRYPOINT_PREFLIGHT'
        targetComputerName = $script:ExpectedComputerName
        fixedReadPathCount = @($script:Rules).Count
        exactSourceBase64PathCount = @($script:Rules | Where-Object { [bool]$_.includeBase64 }).Count
        endpointSignerStoreLocation = $script:ExpectedSignerStoreLocation
        endpointSignerThumbprint = $script:ExpectedSignerThumbprint
        endpointSignerDerSha256 = $script:ExpectedSignerDerSha256
        installedPathsAccessed = $false
        taskStateAccessed = $false
        processStateAccessed = $false
        databaseConnectionOpened = $false
        networkAccessPerformed = $false
        credentialContentAccessed = $false
        privateKeyAccessed = $false
        writesPerformed = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    $preflightJson = $preflightResult | ConvertTo-Json -Depth 6 -Compress
    [Console]::Out.WriteLine($preflightJson)
    return
}

$script:RuleByPath = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($rule in $script:Rules) {
    $script:RuleByPath.Add((Get-NormalizedFixedPath -Path ([string]$rule.path)), $rule)
}
$script:Holds = [Collections.Generic.List[object]]::new()

function Get-BoundedText {
    param(
        [AllowNull()][string]$Text,
        [int]$MaximumCharacters = 512
    )
    if ($null -eq $Text) { return '' }
    if ($Text.Length -le $MaximumCharacters) { return $Text }
    return $Text.Substring(0, $MaximumCharacters)
}

function Add-Hold {
    param(
        [Parameter(Mandatory=$true)][string]$Code,
        [Parameter(Mandatory=$true)][string]$Detail,
        [AllowNull()][string]$Path
    )
    if ($script:Holds.Count -ge $script:MaximumHolds) {
        throw 'HARD_HOLD_COUNT_CAP_EXCEEDED'
    }
    $script:Holds.Add([pscustomobject]@{
        code = Get-BoundedText -Text $Code -MaximumCharacters 96
        detail = Get-BoundedText -Text $Detail -MaximumCharacters 512
        path = if ($null -eq $Path) { '' } else { Get-BoundedText -Text $Path -MaximumCharacters 512 }
    }) | Out-Null
}

function Get-Sha256Hex {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '')
    }
    finally {
        $algorithm.Dispose()
    }
}

function Read-BoundedSnapshot {
    param([Parameter(Mandatory=$true)][string]$Path)

    $normalized = Get-NormalizedFixedPath -Path $Path
    if ($script:RuleByPath.ContainsKey($normalized)) {
        $rule = $script:RuleByPath[$normalized]
    }
    else {
        $executingSelf = Get-NormalizedFixedPath -Path ([string]$PSCommandPath)
        if (-not [string]::Equals($normalized, $executingSelf, [StringComparison]::OrdinalIgnoreCase) -or
            -not [string]::Equals([IO.Path]::GetFileName($normalized), 'R18UQ0.ps1', [StringComparison]::OrdinalIgnoreCase)) {
            throw "HARD_PATH_NOT_WHITELISTED:$normalized"
        }
        $rule = [pscustomobject]@{ path=$normalized; kind='executingSelf'; includeBase64=$false; maximumBytes=[int64]524288 }
    }
    if (-not (Test-Path -LiteralPath $normalized -PathType Leaf)) {
        throw "EXPECTED_FILE_MISSING:$normalized"
    }
    $file = Get-Item -LiteralPath $normalized -Force -ErrorAction Stop
    if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "HARD_REPARSE_POINT_REFUSED:$normalized"
    }
    if ([int64]$file.Length -gt [int64]$rule.maximumBytes) {
        throw "HARD_FILE_BYTE_CAP_EXCEEDED:$normalized"
    }

    $stream = [IO.File]::Open($normalized, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    try {
        $streamLength = [int64]$stream.Length
        if ($streamLength -gt [int64]$rule.maximumBytes -or $streamLength -gt [int]::MaxValue) {
            throw "HARD_OPEN_STREAM_BYTE_CAP_EXCEEDED:$normalized"
        }
        if ($streamLength -eq 0) {
            [byte[]]$rawBytes = @()
        }
        else {
            [byte[]]$rawBytes = New-Object byte[] ([int]$streamLength)
            $offset = 0
            while ($offset -lt $rawBytes.Length) {
                $readCount = $stream.Read($rawBytes, $offset, $rawBytes.Length - $offset)
                if ($readCount -le 0) { throw "HARD_SHORT_READ:$normalized" }
                $offset += $readCount
            }
            if ($stream.ReadByte() -ne -1) { throw "HARD_STREAM_GREW_DURING_READ:$normalized" }
        }
    }
    finally {
        $stream.Dispose()
    }

    return [pscustomobject]@{
        Path = $normalized
        Kind = [string]$rule.kind
        IncludeBase64 = [bool]$rule.includeBase64
        Bytes = [int64]$rawBytes.LongLength
        Sha256 = Get-Sha256Hex -Bytes $rawBytes
        LastWriteUtc = ([DateTime]$file.LastWriteTimeUtc).ToString('o')
        InternalBytes = $rawBytes
    }
}

function Convert-SnapshotForOutput {
    param([Parameter(Mandatory=$true)]$Snapshot)
    $result = [ordered]@{
        path = [string]$Snapshot.Path
        bytes = [int64]$Snapshot.Bytes
        sha256 = [string]$Snapshot.Sha256
        lastWriteUtc = [string]$Snapshot.LastWriteUtc
        contentEncoding = 'binary-exact'
        contentReturned = [bool]$Snapshot.IncludeBase64
    }
    if ([bool]$Snapshot.IncludeBase64) {
        $result.contentBase64 = [Convert]::ToBase64String([byte[]]$Snapshot.InternalBytes)
    }
    return $result
}

function Read-ExpectedSnapshot {
    param([Parameter(Mandatory=$true)][string]$Path)
    try {
        return Read-BoundedSnapshot -Path $Path
    }
    catch {
        $failureMessage = [string]$_.Exception.Message
        if ($failureMessage.StartsWith('HARD_', [StringComparison]::Ordinal)) { throw }
        Add-Hold -Code 'EXPECTED_SOURCE_UNAVAILABLE' -Detail $failureMessage -Path $Path
        return $null
    }
}

function Convert-BytesToStrictText {
    param([Parameter(Mandatory=$true)][byte[]]$Bytes)

    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xEF -and $Bytes[1] -eq 0xBB -and $Bytes[2] -eq 0xBF) {
        $encoding = [Text.UTF8Encoding]::new($false, $true)
        return [pscustomobject]@{ encoding='UTF-8-BOM'; text=$encoding.GetString($Bytes, 3, $Bytes.Length - 3) }
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFF -and $Bytes[1] -eq 0xFE) {
        if ((($Bytes.Length - 2) % 2) -ne 0) { throw 'Odd UTF-16LE byte count.' }
        $encoding = [Text.UnicodeEncoding]::new($false, $true, $true)
        return [pscustomobject]@{ encoding='UTF-16LE-BOM'; text=$encoding.GetString($Bytes, 2, $Bytes.Length - 2) }
    }
    if ($Bytes.Length -ge 2 -and $Bytes[0] -eq 0xFE -and $Bytes[1] -eq 0xFF) {
        if ((($Bytes.Length - 2) % 2) -ne 0) { throw 'Odd UTF-16BE byte count.' }
        $encoding = [Text.UnicodeEncoding]::new($true, $true, $true)
        return [pscustomobject]@{ encoding='UTF-16BE-BOM'; text=$encoding.GetString($Bytes, 2, $Bytes.Length - 2) }
    }
    $encoding = [Text.UTF8Encoding]::new($false, $true)
    return [pscustomobject]@{ encoding='UTF-8'; text=$encoding.GetString($Bytes) }
}

function Get-SourceAstSignature {
    param([Parameter(Mandatory=$true)]$Snapshot)

    $decoded = Convert-BytesToStrictText -Bytes ([byte[]]$Snapshot.InternalBytes)
    $tokenBuffer = $null
    $parseProblems = $null
    $sourceAst = [Management.Automation.Language.Parser]::ParseInput([string]$decoded.text, [ref]$tokenBuffer, [ref]$parseProblems)
    $scriptParameters = @()
    if ($null -ne $sourceAst.ParamBlock) {
        $scriptParameters = @($sourceAst.ParamBlock.Parameters | ForEach-Object {
            [pscustomobject]@{
                name = [string]$_.Name.VariablePath.UserPath
                type = if ($null -eq $_.StaticType) { 'System.Object' } else { [string]$_.StaticType.FullName }
            }
        })
    }
    $functionAsts = @($sourceAst.FindAll({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] }, $true))
    $commandAsts = @($sourceAst.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))
    if ($scriptParameters.Count -gt 128) { throw "HARD_AST_PARAMETER_CAP_EXCEEDED:$($Snapshot.Path)" }
    if ($functionAsts.Count -gt 256) { throw "HARD_AST_FUNCTION_CAP_EXCEEDED:$($Snapshot.Path)" }

    $commandNames = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $dynamicCommandCount = 0
    $visualInvocations = [Collections.Generic.List[object]]::new()
    foreach ($commandAst in $commandAsts) {
        $commandName = [string]$commandAst.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($commandName)) {
            $dynamicCommandCount++
            continue
        }
        $commandNames.Add($commandName) | Out-Null
        $leafName = [IO.Path]::GetFileName($commandName)
        if ([string]::Equals($leafName, 'Invoke-ArgosMesVisualStateSnapshot.ps1', [StringComparison]::OrdinalIgnoreCase)) {
            $namedParameters = @($commandAst.CommandElements | Where-Object { $_ -is [Management.Automation.Language.CommandParameterAst] } | ForEach-Object { [string]$_.ParameterName } | Sort-Object -Unique)
            $visualInvocations.Add([pscustomobject]@{
                commandName = $commandName
                namedParameters = $namedParameters
                namedParameterCount = $namedParameters.Count
                usesSplatting = [bool](@($commandAst.CommandElements | Where-Object { $_ -is [Management.Automation.Language.VariableExpressionAst] -and $_.Splatted }).Count -gt 0)
            }) | Out-Null
        }
    }
    $sortedCommandNames = @($commandNames.GetEnumerator() | Sort-Object)
    if ($sortedCommandNames.Count -gt 512) { throw "HARD_AST_COMMAND_CAP_EXCEEDED:$($Snapshot.Path)" }
    if ($visualInvocations.Count -gt 128) { throw "HARD_VISUAL_INVOCATION_CAP_EXCEEDED:$($Snapshot.Path)" }

    $boundedProblems = @($parseProblems | Select-Object -First 32 | ForEach-Object {
        [pscustomobject]@{
            errorId = Get-BoundedText -Text ([string]$_.ErrorId) -MaximumCharacters 128
            message = Get-BoundedText -Text ([string]$_.Message) -MaximumCharacters 512
            startOffset = [int]$_.Extent.StartOffset
            endOffset = [int]$_.Extent.EndOffset
        }
    })
    if (@($parseProblems).Count -gt 0) {
        Add-Hold -Code 'SOURCE_PARSE_ERRORS' -Detail ("PowerShell parser reported {0} error(s)." -f @($parseProblems).Count) -Path ([string]$Snapshot.Path)
    }

    $visualRequired = @('Scribe', 'SqlCredential', 'OutputPath')
    $parameterNames = @($scriptParameters | ForEach-Object { [string]$_.name })
    return [ordered]@{
        sourceSha256 = [string]$Snapshot.Sha256
        encoding = [string]$decoded.encoding
        scriptParameters = $scriptParameters
        functionNames = @($functionAsts | ForEach-Object { [string]$_.Name } | Sort-Object -Unique)
        staticCommandNames = $sortedCommandNames
        dynamicCommandCount = $dynamicCommandCount
        parseErrorCount = @($parseProblems).Count
        parseErrors = $boundedProblems
        visualSnapshotInvocations = $visualInvocations.ToArray()
        visualRequiredScriptParameters = [ordered]@{
            required = $visualRequired
            present = @($visualRequired | Where-Object { $parameterNames -contains $_ })
            allPresent = [bool](@($visualRequired | Where-Object { $parameterNames -notcontains $_ }).Count -eq 0)
        }
    }
}

function Get-ExternalScriptSignature {
    param([Parameter(Mandatory=$true)]$Snapshot)

    $signature = $null
    try {
        $commands = @(Microsoft.PowerShell.Core\Get-Command -Name ([string]$Snapshot.Path) -CommandType ExternalScript -ErrorAction Stop)
        if ($commands.Count -ne 1) {
            Add-Hold -Code 'GET_COMMAND_CARDINALITY_CHANGED' -Detail ("Expected one ExternalScript command, found {0}." -f $commands.Count) -Path ([string]$Snapshot.Path)
            return [ordered]@{ available=$false; sourceStable=$false; commandCount=$commands.Count }
        }
        $command = $commands[0]
        $parameterRows = @($command.Parameters.Keys | Sort-Object | ForEach-Object {
            $parameterName = [string]$_
            $metadata = $command.Parameters[$parameterName]
            [pscustomobject]@{
                name = $parameterName
                type = if ($null -eq $metadata.ParameterType) { 'System.Object' } else { [string]$metadata.ParameterType.FullName }
                aliases = @($metadata.Aliases | Sort-Object)
            }
        })
        if ($parameterRows.Count -gt 128) { throw "HARD_GET_COMMAND_PARAMETER_CAP_EXCEEDED:$($Snapshot.Path)" }
        $parameterSets = @($command.ParameterSets)
        if ($parameterSets.Count -gt 32) { throw "HARD_GET_COMMAND_PARAMETER_SET_CAP_EXCEEDED:$($Snapshot.Path)" }
        $parameterSetRows = @($parameterSets | ForEach-Object {
            $setInfo = $_
            [pscustomobject]@{
                name = [string]$setInfo.Name
                isDefault = [bool]$setInfo.IsDefault
                parameters = @($setInfo.Parameters | ForEach-Object {
                    [pscustomobject]@{
                        name = [string]$_.Name
                        mandatory = [bool]$_.IsMandatory
                        position = [int]$_.Position
                    }
                })
            }
        })
        $signature = [ordered]@{
            available = $true
            commandType = [string]$command.CommandType
            name = [string]$command.Name
            definition = [string]$command.Definition
            path = [string]$command.Path
            parameters = $parameterRows
            parameterSets = $parameterSetRows
            sourceStable = $false
        }
    }
    catch {
        $failureMessage = [string]$_.Exception.Message
        if ($failureMessage.StartsWith('HARD_', [StringComparison]::Ordinal)) { throw }
        Add-Hold -Code 'GET_COMMAND_SIGNATURE_UNAVAILABLE' -Detail $failureMessage -Path ([string]$Snapshot.Path)
        return [ordered]@{ available=$false; sourceStable=$false; commandCount=0 }
    }

    try {
        $afterSnapshot = Read-BoundedSnapshot -Path ([string]$Snapshot.Path)
    }
    catch {
        $failureMessage = [string]$_.Exception.Message
        if ($failureMessage.StartsWith('HARD_', [StringComparison]::Ordinal)) { throw }
        Add-Hold -Code 'SOURCE_UNAVAILABLE_AFTER_GET_COMMAND' -Detail $failureMessage -Path ([string]$Snapshot.Path)
        return $signature
    }
    $stable = [bool]([string]$afterSnapshot.Sha256 -eq [string]$Snapshot.Sha256 -and [int64]$afterSnapshot.Bytes -eq [int64]$Snapshot.Bytes)
    $signature.sourceStable = $stable
    $signature.sourceSha256Before = [string]$Snapshot.Sha256
    $signature.sourceSha256After = [string]$afterSnapshot.Sha256
    if (-not $stable) {
        Add-Hold -Code 'SOURCE_CHANGED_DURING_GET_COMMAND' -Detail 'The exact source hash or byte count changed while its command signature was captured.' -Path ([string]$Snapshot.Path)
    }
    return $signature
}

function Get-ScheduledTaskEvidence {
    try {
        $tasks = @(ScheduledTasks\Get-ScheduledTask -TaskPath $script:ExpectedTaskPath -TaskName $script:ExpectedTaskName -ErrorAction Stop)
    }
    catch {
        Add-Hold -Code 'TASK_AUDIT_UNAVAILABLE' -Detail (Get-BoundedText -Text ([string]$_.Exception.Message)) -Path ''
        return $null
    }
    if ($tasks.Count -ne 1) {
        Add-Hold -Code 'TASK_CARDINALITY_CHANGED' -Detail ("Expected one task, found {0}." -f $tasks.Count) -Path ''
        return [ordered]@{ name=$script:ExpectedTaskName; taskPath=$script:ExpectedTaskPath; observedCount=$tasks.Count; actions=@() }
    }
    $task = $tasks[0]
    $actions = @($task.Actions)
    if ($actions.Count -gt $script:MaximumTaskActionCount) { throw 'HARD_TASK_ACTION_CAP_EXCEEDED' }
    if ($actions.Count -ne 1) {
        Add-Hold -Code 'TASK_ACTION_CARDINALITY_CHANGED' -Detail ("Expected one task action, found {0}." -f $actions.Count) -Path ''
    }

    $actionRows = @($actions | ForEach-Object {
        $action = $_
        $argumentText = [string]$action.Arguments
        if ($argumentText.Length -gt $script:MaximumTaskArgumentCharacters) { throw 'HARD_TASK_ARGUMENT_CAP_EXCEEDED' }
        $fileMatches = [regex]::Matches($argumentText, '(?i)(?:^|\s)-File\s+(?:"([^"]+)"|([^\s]+))')
        $scriptPath = ''
        if ($fileMatches.Count -eq 1) {
            $scriptPath = if ($fileMatches[0].Groups[1].Success) { [string]$fileMatches[0].Groups[1].Value } else { [string]$fileMatches[0].Groups[2].Value }
        }
        else {
            Add-Hold -Code 'TASK_FILE_ARGUMENT_CARDINALITY_CHANGED' -Detail ("Expected one -File argument, found {0}." -f $fileMatches.Count) -Path ''
        }
        $normalizedScriptPath = ''
        if (-not [string]::IsNullOrWhiteSpace($scriptPath)) {
            try { $normalizedScriptPath = Get-NormalizedFixedPath -Path $scriptPath }
            catch { Add-Hold -Code 'TASK_FILE_ARGUMENT_INVALID' -Detail 'The task -File argument was not a valid rooted path.' -Path ''; $normalizedScriptPath = '' }
        }
        if (-not [string]::Equals($normalizedScriptPath, (Get-NormalizedFixedPath -Path $script:ExpectedWorkerPath), [StringComparison]::OrdinalIgnoreCase)) {
            Add-Hold -Code 'TASK_WORKER_PATH_CHANGED' -Detail 'The task action no longer names the fixed automatic Insite bridge worker.' -Path $normalizedScriptPath
        }
        $executeLeaf = [IO.Path]::GetFileName([string]$action.Execute)
        if (-not [string]::Equals($executeLeaf, 'powershell.exe', [StringComparison]::OrdinalIgnoreCase)) {
            Add-Hold -Code 'TASK_EXECUTABLE_CHANGED' -Detail 'The task action executable is not powershell.exe.' -Path ([string]$action.Execute)
        }
        [pscustomobject]@{
            execute = [string]$action.Execute
            arguments = $argumentText
            workingDirectory = [string]$action.WorkingDirectory
            fileArgumentCount = $fileMatches.Count
            scriptPath = $normalizedScriptPath
        }
    })

    return [ordered]@{
        name = [string]$task.TaskName
        taskPath = [string]$task.TaskPath
        state = [string]$task.State
        principal = [ordered]@{
            userId = [string]$task.Principal.UserId
            logonType = [string]$task.Principal.LogonType
            runLevel = [string]$task.Principal.RunLevel
        }
        actionCount = $actions.Count
        actions = $actionRows
    }
}

function Get-JsonPropertyValue {
    param(
        [Parameter(Mandatory=$true)]$InputObject,
        [Parameter(Mandatory=$true)][string]$Name
    )
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return [pscustomobject]@{ present=$false; value=$null } }
    return [pscustomobject]@{ present=$true; value=$property.Value }
}

function Test-BoundedBase64Value {
    param(
        [AllowNull()][object]$Value,
        [int]$MaximumDecodedBytes
    )
    if ($null -eq $Value) { return [pscustomobject]@{ valid=$false; decodedBytes=0 } }
    $encoded = [string]$Value
    $maximumCharacters = 4 * [int][Math]::Ceiling($MaximumDecodedBytes / 3.0)
    if ([string]::IsNullOrWhiteSpace($encoded) -or $encoded.Length -gt $maximumCharacters -or ($encoded.Length % 4) -ne 0 -or $encoded -notmatch '^[A-Za-z0-9+/]*={0,2}$') {
        return [pscustomobject]@{ valid=$false; decodedBytes=0 }
    }
    [byte[]]$decoded = @()
    try {
        $decoded = [Convert]::FromBase64String($encoded)
        if ($decoded.Length -gt $MaximumDecodedBytes) { return [pscustomobject]@{ valid=$false; decodedBytes=$decoded.Length } }
        return [pscustomobject]@{ valid=$true; decodedBytes=$decoded.Length }
    }
    catch {
        return [pscustomobject]@{ valid=$false; decodedBytes=0 }
    }
    finally {
        if ($decoded.Length -gt 0) { [Array]::Clear($decoded, 0, $decoded.Length) }
        $encoded = $null
    }
}

function Get-CredentialEnvelopeEvidence {
    param([AllowNull()]$Snapshot)
    if ($null -eq $Snapshot) {
        return [ordered]@{
            exists = $false
            usernameReturned = $false
            ciphertextReturned = $false
            entropyReturned = $false
            dpapiUnprotectCalled = $false
            plaintextMaterialized = $false
        }
    }

    $base = [ordered]@{
        exists = $true
        path = [string]$Snapshot.Path
        bytes = [int64]$Snapshot.Bytes
        sha256 = [string]$Snapshot.Sha256
        lastWriteUtc = [string]$Snapshot.LastWriteUtc
        schema = ''
        schemaMatchesExpected = $false
        usernamePropertyPresent = $false
        usernamePresentNonblank = $false
        protectedPasswordPropertyPresent = $false
        protectedPasswordValidBase64 = $false
        protectedPasswordDecodedBytes = 0
        entropyPropertyPresent = $false
        entropyValidBase64 = $false
        entropyDecodedBytes = 0
        usernameReturned = $false
        ciphertextReturned = $false
        entropyReturned = $false
        dpapiUnprotectCalled = $false
        plaintextMaterialized = $false
    }
    try {
        $decodedText = Convert-BytesToStrictText -Bytes ([byte[]]$Snapshot.InternalBytes)
        $record = [string]$decodedText.text | ConvertFrom-Json -ErrorAction Stop
        $schemaProperty = Get-JsonPropertyValue -InputObject $record -Name 'schema'
        $userProperty = Get-JsonPropertyValue -InputObject $record -Name 'userName'
        $passwordProperty = Get-JsonPropertyValue -InputObject $record -Name 'protectedPassword'
        $entropyProperty = Get-JsonPropertyValue -InputObject $record -Name 'entropy'
        $base.schema = if ([bool]$schemaProperty.present) { [string]$schemaProperty.value } else { '' }
        $base.schemaMatchesExpected = [bool]([bool]$schemaProperty.present -and [string]$schemaProperty.value -eq $script:ExpectedCredentialSchema)
        $base.usernamePropertyPresent = [bool]$userProperty.present
        $base.usernamePresentNonblank = [bool]([bool]$userProperty.present -and -not [string]::IsNullOrWhiteSpace([string]$userProperty.value))
        $base.protectedPasswordPropertyPresent = [bool]$passwordProperty.present
        $base.entropyPropertyPresent = [bool]$entropyProperty.present
        $passwordShape = Test-BoundedBase64Value -Value $passwordProperty.value -MaximumDecodedBytes $script:MaximumProtectedPasswordBytes
        $entropyShape = Test-BoundedBase64Value -Value $entropyProperty.value -MaximumDecodedBytes $script:MaximumEntropyBytes
        $base.protectedPasswordValidBase64 = [bool]$passwordShape.valid
        $base.protectedPasswordDecodedBytes = [int]$passwordShape.decodedBytes
        $base.entropyValidBase64 = [bool]$entropyShape.valid
        $base.entropyDecodedBytes = [int]$entropyShape.decodedBytes
        if (-not [bool]$base.schemaMatchesExpected -or -not [bool]$base.usernamePresentNonblank -or -not [bool]$base.protectedPasswordValidBase64 -or -not [bool]$base.entropyValidBase64) {
            Add-Hold -Code 'CREDENTIAL_ENVELOPE_SHAPE_CHANGED' -Detail 'The credential envelope schema or required sanitized shape did not match the fixed contract.' -Path ([string]$Snapshot.Path)
        }
        $record = $null
        $decodedText = $null
    }
    catch {
        Add-Hold -Code 'CREDENTIAL_ENVELOPE_PARSE_FAILED' -Detail 'The credential envelope could not be parsed under the fixed sanitized metadata contract.' -Path ([string]$Snapshot.Path)
    }
    finally {
        if ($Snapshot.InternalBytes.Length -gt 0) { [Array]::Clear($Snapshot.InternalBytes, 0, $Snapshot.InternalBytes.Length) }
    }
    return $base
}

function Get-EndpointConfigEvidence {
    param([AllowNull()]$Snapshot)
    if ($null -eq $Snapshot) { return $null }
    $sourceProjection = Convert-SnapshotForOutput -Snapshot $Snapshot
    $projection = [ordered]@{
        source = $sourceProjection
        parsed = $false
        schema = ''
        role = ''
        reviewOnly = $false
        productionRoutingEnabled = $null
        endpointSignerStoreLocation = ''
        endpointSignerThumbprint = ''
        signerContractMatches = $false
    }
    try {
        $decoded = Convert-BytesToStrictText -Bytes ([byte[]]$Snapshot.InternalBytes)
        $config = [string]$decoded.text | ConvertFrom-Json -ErrorAction Stop
        $schemaProperty = Get-JsonPropertyValue -InputObject $config -Name 'schema'
        $roleProperty = Get-JsonPropertyValue -InputObject $config -Name 'role'
        $reviewProperty = Get-JsonPropertyValue -InputObject $config -Name 'reviewOnly'
        $routingProperty = Get-JsonPropertyValue -InputObject $config -Name 'productionRoutingEnabled'
        $storeProperty = Get-JsonPropertyValue -InputObject $config -Name 'endpointSignerStoreLocation'
        $thumbprintProperty = Get-JsonPropertyValue -InputObject $config -Name 'endpointSignerThumbprint'
        $observedThumbprint = if ([bool]$thumbprintProperty.present) { ([string]$thumbprintProperty.value).Replace(' ', '').ToUpperInvariant() } else { '' }
        $projection.parsed = $true
        $projection.schema = if ([bool]$schemaProperty.present) { [string]$schemaProperty.value } else { '' }
        $projection.role = if ([bool]$roleProperty.present) { [string]$roleProperty.value } else { '' }
        $projection.reviewOnly = [bool]([bool]$reviewProperty.present -and [bool]$reviewProperty.value)
        $projection.productionRoutingEnabled = if ([bool]$routingProperty.present) { [bool]$routingProperty.value } else { $null }
        $projection.endpointSignerStoreLocation = if ([bool]$storeProperty.present) { [string]$storeProperty.value } else { '' }
        $projection.endpointSignerThumbprint = $observedThumbprint
        $projection.signerContractMatches = [bool]($projection.endpointSignerStoreLocation -eq $script:ExpectedSignerStoreLocation -and $observedThumbprint -eq $script:ExpectedSignerThumbprint)
        if ($projection.schema -ne $script:ExpectedEndpointConfigSchema -or $projection.role -ne 'ARGOS' -or -not [bool]$projection.reviewOnly -or [bool]$projection.productionRoutingEnabled -or -not [bool]$projection.signerContractMatches) {
            Add-Hold -Code 'ENDPOINT_CONFIG_CONTRACT_CHANGED' -Detail 'The endpoint config no longer matches the fixed ARGOS review-only signer contract.' -Path ([string]$Snapshot.Path)
        }
    }
    catch {
        Add-Hold -Code 'ENDPOINT_CONFIG_PARSE_FAILED' -Detail (Get-BoundedText -Text ([string]$_.Exception.Message)) -Path ([string]$Snapshot.Path)
    }
    return $projection
}

function Get-PublicCertificateEvidence {
    $certificatePath = "Cert:\$($script:ExpectedSignerStoreLocation)\My\$($script:ExpectedSignerThumbprint)"
    try {
        $certificateItems = @(Microsoft.PowerShell.Management\Get-Item -LiteralPath $certificatePath -ErrorAction Stop)
        if ($certificateItems.Count -ne 1) {
            Add-Hold -Code 'ENDPOINT_PUBLIC_CERTIFICATE_CARDINALITY_CHANGED' -Detail ("Expected one public certificate, found {0}." -f $certificateItems.Count) -Path $certificatePath
            return $null
        }
        $certificate = $certificateItems[0]
        [byte[]]$derBytes = $certificate.RawData
        if ($derBytes.Length -gt 16384) { throw 'HARD_PUBLIC_CERTIFICATE_BYTE_CAP_EXCEEDED' }
        $derSha256 = Get-Sha256Hex -Bytes $derBytes
        $thumbprint = ([string]$certificate.Thumbprint).Replace(' ', '').ToUpperInvariant()
        if ($thumbprint -ne $script:ExpectedSignerThumbprint -or $derSha256 -ne $script:ExpectedSignerDerSha256) {
            Add-Hold -Code 'ENDPOINT_PUBLIC_CERTIFICATE_CHANGED' -Detail 'The endpoint public certificate thumbprint or DER hash changed.' -Path $certificatePath
        }
        $publicKeyBits = $null
        try { $publicKeyBits = [int]$certificate.PublicKey.Key.KeySize }
        catch { Add-Hold -Code 'ENDPOINT_PUBLIC_KEY_METADATA_UNAVAILABLE' -Detail 'The public RSA key size could not be read.' -Path $certificatePath }
        return [ordered]@{
            providerPath = $certificatePath
            derBytes = $derBytes.Length
            derSha256 = $derSha256
            derBase64 = [Convert]::ToBase64String($derBytes)
            thumbprint = $thumbprint
            subject = [string]$certificate.Subject
            issuer = [string]$certificate.Issuer
            serialNumber = [string]$certificate.SerialNumber
            notBeforeUtc = ([DateTime]$certificate.NotBefore).ToUniversalTime().ToString('o')
            notAfterUtc = ([DateTime]$certificate.NotAfter).ToUniversalTime().ToString('o')
            publicKeyAlgorithmOid = [string]$certificate.PublicKey.Oid.Value
            publicRsaKeyBits = $publicKeyBits
            privateKeyAccessed = $false
            privateKeyExportAttempted = $false
        }
    }
    catch {
        $failureMessage = [string]$_.Exception.Message
        if ($failureMessage.StartsWith('HARD_', [StringComparison]::Ordinal)) { throw }
        Add-Hold -Code 'ENDPOINT_PUBLIC_CERTIFICATE_UNAVAILABLE' -Detail (Get-BoundedText -Text $failureMessage) -Path $certificatePath
        return $null
    }
}

if (-not [string]::Equals([Environment]::MachineName, $script:ExpectedComputerName, [StringComparison]::OrdinalIgnoreCase)) {
    throw "HARD_WRONG_COMPUTER:$([Environment]::MachineName)"
}

$executingPath = Get-NormalizedFixedPath -Path ([string]$PSCommandPath)
$executingSnapshot = Read-BoundedSnapshot -Path $executingPath
$installedSnapshot = Read-BoundedSnapshot -Path $script:InstalledSelfPath
if ([string]$executingSnapshot.Sha256 -ne [string]$installedSnapshot.Sha256 -or [int64]$executingSnapshot.Bytes -ne [int64]$installedSnapshot.Bytes) {
    throw 'HARD_SELF_INSTALL_BYTE_MISMATCH'
}

$snapshots = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase)
$aggregateBase64Bytes = [int64]0
foreach ($rule in $script:Rules | Where-Object { [string]$_.kind -ne 'self' }) {
    $snapshot = Read-ExpectedSnapshot -Path ([string]$rule.path)
    if ($null -ne $snapshot) {
        $snapshots.Add([string]$snapshot.Path, $snapshot)
        if ([bool]$snapshot.IncludeBase64) { $aggregateBase64Bytes += [int64]$snapshot.Bytes }
    }
}
if ($aggregateBase64Bytes -gt $script:MaximumAggregateBase64SourceBytes) {
    throw 'HARD_AGGREGATE_BASE64_SOURCE_BYTE_CAP_EXCEEDED'
}

$endpointConfigPath = Get-NormalizedFixedPath -Path 'C:\ProgramData\ArgosProjectPortalRO\config\endpoint_argos.json'
$endpointWorkerPath = Get-NormalizedFixedPath -Path 'C:\ProgramData\ArgosProjectPortalRO\bin\Invoke-ArgosProjectPortalEndpointWorker.ps1'
$relayPath = Get-NormalizedFixedPath -Path 'C:\ProgramData\ArgosInsiteBridgeRO\bin\ArgosBoundRelay.InsiteBridge.ReviewOnly.V2_1.exe'
$credentialPath = Get-NormalizedFixedPath -Path 'C:\ProgramData\ArgosInsiteBridgeRO\secrets\insite.credential.dpapi.json'

$endpointConfigSnapshot = if ($snapshots.ContainsKey($endpointConfigPath)) { $snapshots[$endpointConfigPath] } else { $null }
$endpointWorkerSnapshot = if ($snapshots.ContainsKey($endpointWorkerPath)) { $snapshots[$endpointWorkerPath] } else { $null }
$relaySnapshot = if ($snapshots.ContainsKey($relayPath)) { $snapshots[$relayPath] } else { $null }
$credentialSnapshot = if ($snapshots.ContainsKey($credentialPath)) { $snapshots[$credentialPath] } else { $null }

$endpointConfigEvidence = Get-EndpointConfigEvidence -Snapshot $endpointConfigSnapshot
$taskEvidence = Get-ScheduledTaskEvidence

$endpointWorkerEvidence = $null
if ($null -ne $endpointWorkerSnapshot) {
    $endpointWorkerEvidence = [ordered]@{
        source = Convert-SnapshotForOutput -Snapshot $endpointWorkerSnapshot
        ast = Get-SourceAstSignature -Snapshot $endpointWorkerSnapshot
        getCommand = Get-ExternalScriptSignature -Snapshot $endpointWorkerSnapshot
    }
}

$insiteSourceRows = [Collections.Generic.List[object]]::new()
$insiteRules = @($script:Rules | Where-Object { [string]$_.path -like 'C:\ProgramData\ArgosInsiteBridgeRO\query\*' })
foreach ($sourceRule in $insiteRules) {
    $sourcePath = Get-NormalizedFixedPath -Path ([string]$sourceRule.path)
    if (-not $snapshots.ContainsKey($sourcePath)) {
        $insiteSourceRows.Add([pscustomobject]@{ path=$sourcePath; available=$false; source=$null; ast=$null; getCommand=$null }) | Out-Null
        continue
    }
    $sourceSnapshot = $snapshots[$sourcePath]
    $getCommandSignature = $null
    if ([string]$sourceRule.kind -eq 'powershell') {
        $getCommandSignature = Get-ExternalScriptSignature -Snapshot $sourceSnapshot
    }
    $insiteSourceRows.Add([pscustomobject]@{
        path = $sourcePath
        available = $true
        source = Convert-SnapshotForOutput -Snapshot $sourceSnapshot
        ast = Get-SourceAstSignature -Snapshot $sourceSnapshot
        getCommand = $getCommandSignature
    }) | Out-Null
}

$relayEvidence = if ($null -eq $relaySnapshot) {
    $null
}
else {
    $fileVersion = ''
    try { $fileVersion = [string]([Diagnostics.FileVersionInfo]::GetVersionInfo([string]$relaySnapshot.Path).FileVersion) }
    catch { Add-Hold -Code 'RELAY_FILE_VERSION_UNAVAILABLE' -Detail (Get-BoundedText -Text ([string]$_.Exception.Message)) -Path ([string]$relaySnapshot.Path) }
    [ordered]@{
        path = [string]$relaySnapshot.Path
        bytes = [int64]$relaySnapshot.Bytes
        sha256 = [string]$relaySnapshot.Sha256
        lastWriteUtc = [string]$relaySnapshot.LastWriteUtc
        fileVersion = $fileVersion
        contentReturned = $false
    }
}

$credentialEvidence = Get-CredentialEnvelopeEvidence -Snapshot $credentialSnapshot
$certificateEvidence = Get-PublicCertificateEvidence

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
try {
    $identityEvidence = [ordered]@{
        name = [string]$identity.Name
        authenticationType = [string]$identity.AuthenticationType
        isSystem = [bool]$identity.IsSystem
    }
}
finally {
    $identity.Dispose()
}

$holdsArray = $script:Holds.ToArray()
$result = [ordered]@{
    schema = 'argos_r18uq0_argos_insite_runtime_audit_v1'
    state = 'PASS_R18UQ0_ARGOS_INSITE_RUNTIME_AUDIT'
    disposition = if ($holdsArray.Count -eq 0) { 'COMPLETE' } else { 'HOLD_INCOMPLETE' }
    createdUtc = [DateTime]::UtcNow.ToString('o')
    computerName = [Environment]::MachineName
    executionIdentity = $identityEvidence
    selfInstallation = [ordered]@{
        executingPath = $executingPath
        installedPath = [string]$installedSnapshot.Path
        executingBytes = [int64]$executingSnapshot.Bytes
        installedBytes = [int64]$installedSnapshot.Bytes
        executingSha256 = [string]$executingSnapshot.Sha256
        installedSha256 = [string]$installedSnapshot.Sha256
        exactByteIdentityVerified = $true
        installedByEndpointBeforeExecution = $true
        endpointManagedInstalledFileCount = 1
        entryPointWritesPerformed = $false
    }
    task = $taskEvidence
    endpointConfig = $endpointConfigEvidence
    endpointWorker = $endpointWorkerEvidence
    insiteSources = $insiteSourceRows.ToArray()
    relayBinary = $relayEvidence
    credentialEnvelope = $credentialEvidence
    endpointPublicCertificate = $certificateEvidence
    exactSourceBase64Bytes = $aggregateBase64Bytes
    holds = $holdsArray
    invariants = [ordered]@{
        entryPointWritesPerformed = $false
        endpointManagedInstalledFileCount = 1
        taskMutationPerformed = $false
        processMutationPerformed = $false
        taskStarted = $false
        taskStopped = $false
        taskRestarted = $false
        processStarted = $false
        processStopped = $false
        insiteQueryExecuted = $false
        databaseConnectionOpened = $false
        networkAccessPerformed = $false
        credentialDecryptionPerformed = $false
        credentialContentReturned = $false
        privateKeyAccessed = $false
        privateKeyExportAttempted = $false
        imageBytesRead = $false
        jbodContacted = $false
        sourceFilesMutated = $false
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
}

$json = $result | ConvertTo-Json -Depth 18 -Compress
$jsonBytes = [Text.UTF8Encoding]::new($false).GetByteCount($json)
if ($jsonBytes -gt $script:MaximumJsonBytes) {
    throw "HARD_FINAL_JSON_BYTE_CAP_EXCEEDED:$jsonBytes"
}
[Console]::Out.WriteLine($json)
