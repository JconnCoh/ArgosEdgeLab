[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$PowerShellScript,
    [switch]$Preflight,
    [switch]$AsJson,
    [switch]$ReturnFailureResult
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if (-not $Preflight) { throw 'Harness safety inspection is preflight-only.' }

if ($PowerShellScript.IndexOfAny([char[]]'*?') -ge 0) { throw 'Harness path cannot contain wildcards.' }
if (-not (Test-Path -LiteralPath $PowerShellScript -PathType Leaf)) { throw "Harness script does not exist: $PowerShellScript" }
$resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $PowerShellScript).Path)
if ([IO.Path]::GetExtension($resolved) -ine '.ps1') { throw "Harness must be a .ps1 file: $resolved" }
$length = (Get-Item -LiteralPath $resolved).Length
if ($length -gt 1048576) { throw "Harness exceeds the 1 MiB bounded source limit: $length" }

$bytes = [IO.File]::ReadAllBytes($resolved)
$utf8 = New-Object Text.UTF8Encoding($false, $true)
try { $source = $utf8.GetString($bytes).TrimStart([char]0xFEFF) }
catch { throw "Harness is not valid UTF-8: $resolved" }

$tokens = $null
$parserErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseInput($source, $resolved, [ref]$tokens, [ref]$parserErrors)
$violations = New-Object Collections.Generic.List[object]
$warnings = New-Object Collections.Generic.List[object]

function Add-Violation([string]$Code, [int]$Line, [string]$Message) {
    $violations.Add([pscustomobject]@{ code = $Code; line = $Line; message = $Message })
}
function Add-Warning([string]$Code, [int]$Line, [string]$Message) {
    $warnings.Add([pscustomobject]@{ code = $Code; line = $Line; message = $Message })
}
function Test-HasFunctionAncestor([Management.Automation.Language.Ast]$Node) {
    $current = $Node.Parent
    while ($null -ne $current) {
        if ($current -is [Management.Automation.Language.FunctionDefinitionAst]) { return $true }
        $current = $current.Parent
    }
    return $false
}

foreach ($errorRecord in @($parserErrors)) {
    Add-Violation 'POWERSHELL_PARSE_ERROR' ([int]$errorRecord.Extent.StartLineNumber) ([string]$errorRecord.Message)
}

$simplifiedWhereTokenAdjacency = @([regex]::Matches(
    $source,
    '(?im)\bWhere-Object[ \t]+[A-Za-z_][A-Za-z0-9_.]*[ \t]+-(?:eq|ne|gt|ge|lt|le)(?=[^\s\r\n])'
))
foreach ($match in $simplifiedWhereTokenAdjacency) {
    $line = 1 + @([regex]::Matches($source.Substring(0, $match.Index), "`n")).Count
    Add-Violation 'SIMPLIFIED_WHERE_OPERATOR_TOKEN_BOUNDARY' $line 'Simplified Where-Object syntax requires whitespace between the comparison operator and its operand.'
}

$parameterNames = @()
if ($null -ne $ast.ParamBlock) { $parameterNames = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
$hasPreflight = $parameterNames -contains 'Preflight'
$hasRehearsal = $parameterNames -contains 'Rehearsal'
if (-not $hasPreflight -and -not $hasRehearsal) {
    Add-Violation 'MISSING_NON_MUTATING_MODE' 1 'Harness must declare Preflight or Rehearsal.'
}

$formatCommands = @($ast.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
    $name = $node.GetCommandName()
    return $name -in @('Format-Table', 'Format-List', 'Format-Wide', 'ft', 'fl', 'fw')
}, $true))
foreach ($command in $formatCommands) {
    Add-Violation 'RENDERED_TABLE_IS_NOT_GATE_EVIDENCE' ([int]$command.Extent.StartLineNumber) 'Machine gate scripts must emit bounded objects/JSON or explicit scalar rows, not rendered formatting records.'
}

$broadRecursiveCommands = @($ast.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
    $name = $node.GetCommandName()
    if ($name -notin @('Get-ChildItem', 'gci', 'dir', 'ls')) { return $false }
    $text = $node.Extent.Text
    if ($text -notmatch '(?i)(^|\s)-Recurse(\s|$)') { return $false }
    return $text -match '(?i)(["'']work["'']|\$project(\s|$)|Resolve-Path\s+["'']\.["''])'
}, $true))
foreach ($command in $broadRecursiveCommands) {
    Add-Violation 'BROAD_RECURSIVE_WORKSPACE_ENUMERATION' ([int]$command.Extent.StartLineNumber) 'Do not recursively enumerate the whole work/project tree. Use rg or one exact bounded subroot with explicit row/error caps.'
}

$plannedDriveLetters = New-Object Collections.Generic.HashSet[string] ([StringComparer]::OrdinalIgnoreCase)
foreach ($match in [regex]::Matches($source, '(?im)\bNew-PSDrive\b[^\r\n]*\s-Name\s+[''\"]?([A-Z])[''\"]?')) { [void]$plannedDriveLetters.Add($match.Groups[1].Value) }
$aliasPathVariables = @{}
$stringAssignments = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] }, $true))
foreach ($assignment in $stringAssignments) {
    if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
    $rightText = $assignment.Right.Extent.Text.Trim().Trim('''', '"')
    if ($rightText -match '^([A-Z]):\\' -and $plannedDriveLetters.Contains($matches[1])) { $aliasPathVariables[$assignment.Left.VariablePath.UserPath] = $matches[1] }
}
$joinPathCommands = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Join-Path' }, $true))
foreach ($command in $joinPathCommands) {
    foreach ($variableName in $aliasPathVariables.Keys) {
        if ($command.Extent.Text -match ('(?i)\$' + [regex]::Escape([string]$variableName) + '(\W|$)')) {
            Add-Violation 'JOIN_PATH_USES_NOT_YET_CREATED_DRIVE' ([int]$command.Extent.StartLineNumber) "Join-Path resolves `$$variableName through planned drive $($aliasPathVariables[$variableName]): before New-PSDrive may exist. Use provider-independent composition."
        }
    }
}

$externalAssignments = New-Object Collections.Generic.List[object]
$assignments = @($ast.FindAll({ param($node) $node -is [Management.Automation.Language.AssignmentStatementAst] }, $true))
foreach ($assignment in $assignments) {
    if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
    $variableName = $assignment.Left.VariablePath.UserPath
    if ($parameterNames -icontains $variableName) {
        Add-Violation 'PARAMETER_VARIABLE_REASSIGNED' ([int]$assignment.Extent.StartLineNumber) "Declared parameter `$$variableName is reassigned. PowerShell variables are case-insensitive and typed parameters can reject the new value."
    }
}

$conditionalCollectionAssignments = New-Object Collections.Generic.List[object]
foreach ($assignment in $assignments) {
    if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
    if ($assignment.Right -isnot [Management.Automation.Language.IfStatementAst]) { continue }
    $arrayExpressions = @($assignment.Right.FindAll({ param($node) $node -is [Management.Automation.Language.ArrayExpressionAst] }, $true))
    $variableName = $assignment.Left.VariablePath.UserPath
    $laterCountUses = @($ast.FindAll({
        param($node)
        if ($node -isnot [Management.Automation.Language.MemberExpressionAst]) { return $false }
        if ($node.Extent.StartOffset -le $assignment.Extent.EndOffset) { return $false }
        if ($node.Expression -isnot [Management.Automation.Language.VariableExpressionAst]) { return $false }
        if ($node.Expression.VariablePath.UserPath -ine $variableName) { return $false }
        return [string]$node.Member.Value -ieq 'Count'
    }, $true))
    if ($arrayExpressions.Count -eq 0 -and $laterCountUses.Count -eq 0) { continue }
    $conditionalCollectionAssignments.Add([pscustomobject]@{
        variable = $variableName
        line = [int]$assignment.Extent.StartLineNumber
        branchArrayExpressionCount = $arrayExpressions.Count
        laterCountUseCount = $laterCountUses.Count
    })
    Add-Violation 'CONDITIONAL_COLLECTION_ASSIGNMENT_CAN_SCALARIZE' ([int]$assignment.Extent.StartLineNumber) "Conditional output assigned directly to `$$variableName can unwrap zero or one items under StrictMode. Put the array boundary around the complete conditional: `$$variableName = @(if (...) { ... })."
}

foreach ($assignment in $assignments) {
    if ($assignment.Left -isnot [Management.Automation.Language.VariableExpressionAst]) { continue }
    $commands = @($assignment.Right.FindAll({ param($node) $node -is [Management.Automation.Language.CommandAst] }, $true))
    $external = $false
    foreach ($command in $commands) {
        $name = $command.GetCommandName()
        $text = $command.Extent.Text
        if ((-not [string]::IsNullOrWhiteSpace($name) -and [IO.Path]::GetFileName($name) -match '^(?i)powershell(?:\.exe)?$') -or $text -match '(?i)(^|[\\/"''])powershell(?:\.exe)?(["'']|\s|$)') { $external = $true; break }
    }
    if (-not $external) { continue }
    $variableName = $assignment.Left.VariablePath.UserPath
    $memberUses = @($ast.FindAll({
        param($node)
        if ($node -isnot [Management.Automation.Language.MemberExpressionAst]) { return $false }
        if ($node.Expression -isnot [Management.Automation.Language.VariableExpressionAst]) { return $false }
        return $node.Expression.VariablePath.UserPath -ceq $variableName
    }, $true))
    $rehydrated = $source -match ('(?is)\$' + [regex]::Escape($variableName) + '.{0,240}ConvertFrom-Json')
    $externalAssignments.Add([pscustomobject]@{ variable = $variableName; line = [int]$assignment.Extent.StartLineNumber; memberUses = $memberUses.Count; explicitJsonRehydration = $rehydrated })
    if ($memberUses.Count -gt 0 -and -not $rehydrated) {
        Add-Violation 'EXTERNAL_POWERSHELL_TEXT_USED_AS_OBJECT' ([int]$assignment.Extent.StartLineNumber) "External powershell.exe stdout assigned to `$$variableName is later dereferenced as an object without explicit JSON rehydration."
    }
}

$mutationCommandNames = @('New-Item', 'Copy-Item', 'Move-Item', 'Remove-Item', 'Rename-Item', 'Set-Content', 'Add-Content', 'Out-File', 'New-PSDrive', 'Remove-PSDrive', 'New-SmbMapping', 'Remove-SmbMapping', 'Start-Process', 'Register-ScheduledTask', 'Set-ScheduledTask', 'Unregister-ScheduledTask')
$topLevelMutationLines = New-Object Collections.Generic.List[int]
$commandMutations = @($ast.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.CommandAst]) { return $false }
    return $node.GetCommandName() -in $mutationCommandNames
}, $true))
foreach ($node in $commandMutations) { if (-not (Test-HasFunctionAncestor $node)) { $topLevelMutationLines.Add([int]$node.Extent.StartLineNumber) } }
$memberMutations = @($ast.FindAll({
    param($node)
    if ($node -isnot [Management.Automation.Language.InvokeMemberExpressionAst]) { return $false }
    return $node.Extent.Text -match '(?i)\[IO\.File\]::Write|\[System\.IO\.File\]::Write|ZipFile\]::Create|ZipFile\]::Extract'
}, $true))
foreach ($node in $memberMutations) { if (-not (Test-HasFunctionAncestor $node)) { $topLevelMutationLines.Add([int]$node.Extent.StartLineNumber) } }

$preflightGuardLines = New-Object Collections.Generic.List[int]
if ($hasPreflight) {
    $preflightIfs = @($ast.FindAll({
        param($node)
        if ($node -isnot [Management.Automation.Language.IfStatementAst]) { return $false }
        if ($node.Extent.Text -notmatch '(?i)\$Preflight') { return $false }
        return @($node.FindAll({ param($inner) $inner -is [Management.Automation.Language.ReturnStatementAst] }, $true)).Count -gt 0
    }, $true))
    foreach ($node in $preflightIfs) { $preflightGuardLines.Add([int]$node.Extent.EndLineNumber) }
    if ($topLevelMutationLines.Count -gt 0) {
        if ($preflightGuardLines.Count -eq 0) {
            Add-Violation 'PREFLIGHT_HAS_NO_RETURN_BEFORE_MUTATION' 1 'Script declares Preflight and has top-level mutations, but no Preflight branch returns before mutation.'
        }
        else {
            $firstMutation = [int](($topLevelMutationLines | Measure-Object -Minimum).Minimum)
            $guardEnd = [int](($preflightGuardLines | Measure-Object -Maximum).Maximum)
            if ($firstMutation -le $guardEnd) { Add-Violation 'MUTATION_BEFORE_PREFLIGHT_RETURN' $firstMutation 'A top-level filesystem/process/task mutation is reachable before the non-mutating Preflight branch returns.' }
        }
    }
}

if ($broadRecursiveCommands.Count -gt 0 -and $formatCommands.Count -gt 0) {
    Add-Warning 'RECURSIVE_RENDERED_OUTPUT_RISK' 1 'Recursive enumeration combined with rendered output can exceed the evidence budget; ensure the root and cardinality are bounded.'
}

$result = [ordered]@{
    schema = 'argos_powershell_harness_safety_preflight_v1'
    checkedUtc = [DateTime]::UtcNow.ToString('o')
    state = if ($violations.Count -eq 0) { 'PASS_ARGOS_POWERSHELL_HARNESS_SAFETY' } else { 'FAIL_ARGOS_POWERSHELL_HARNESS_SAFETY' }
    metadataOnly = $true
    targetExecuted = $false
    powerShellScript = $resolved
    powerShellScriptSha256 = (Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash
    bytes = [int64]$length
    parserErrors = @($parserErrors).Count
    declaredParameters = $parameterNames
    nonMutatingModeDeclared = ($hasPreflight -or $hasRehearsal)
    topLevelMutationCount = $topLevelMutationLines.Count
    preflightReturnGuardCount = $preflightGuardLines.Count
    externalPowerShellAssignments = $externalAssignments.ToArray()
    conditionalCollectionAssignments = $conditionalCollectionAssignments.ToArray()
    conditionalCollectionAssignmentCount = $conditionalCollectionAssignments.Count
    simplifiedWhereOperatorTokenAdjacencyCount = $simplifiedWhereTokenAdjacency.Count
    renderedFormatCommandCount = $formatCommands.Count
    broadRecursiveWorkspaceCommandCount = $broadRecursiveCommands.Count
    warnings = $warnings.ToArray()
    violations = $violations.ToArray()
}
$json = $result | ConvertTo-Json -Depth 8
if ($AsJson) { $json } else { $result }
if ($violations.Count -gt 0 -and -not $ReturnFailureResult) { throw "Harness safety preflight failed with $($violations.Count) violation(s): $resolved" }
