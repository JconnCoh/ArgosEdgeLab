[CmdletBinding()]
param([switch]$Preflight)

$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root='C:\ProgramData\ArgosInsiteBridgeRO'
$taskName='ArgosEdgeLab.InsiteBridge.Worker.ReviewOnly.V1'
$task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
$actions=@(
    foreach($action in @($task.Actions)){
        $arguments=[string]$action.Arguments
        $scriptPath=''
        $match=[regex]::Match($arguments,'(?i)-File\s+(?:"([^"]+)"|([^\s]+))')
        if($match.Success){$scriptPath=if($match.Groups[1].Success){$match.Groups[1].Value}else{$match.Groups[2].Value}}
        $exists=-not[string]::IsNullOrWhiteSpace($scriptPath)-and(Test-Path -LiteralPath $scriptPath -PathType Leaf)
        [ordered]@{
            execute=[string]$action.Execute
            arguments=$arguments
            workingDirectory=[string]$action.WorkingDirectory
            scriptPath=$scriptPath
            scriptExists=$exists
            scriptBytes=if($exists){[int64](Get-Item -LiteralPath $scriptPath).Length}else{$null}
            scriptSha256=if($exists){(Get-FileHash -Algorithm SHA256 -LiteralPath $scriptPath).Hash}else{$null}
        }
    }
)
$visual=Join-Path $root 'query\Invoke-ArgosMesVisualStateSnapshot.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($visual,[ref]$tokens,[ref]$errors)
$parameters=@($ast.ParamBlock.Parameters|ForEach-Object{$_.Name.VariablePath.UserPath})
$missingParameters=@(@('Scribe','SqlCredential','OutputPath')|Where-Object{$parameters-notcontains$_})
[ordered]@{
    schema='argos_sna3_task_action_audit_v1'
    createdUtc=[DateTime]::UtcNow.ToString('o')
    state='PASS_SNA3_ARGOS_TASK_ACTION_AUDIT'
    bridgeRoot=$root
    task=[ordered]@{
        name=$taskName
        taskPath=[string]$task.TaskPath
        principal=[string]$task.Principal.UserId
        state=[string]$task.State
        actions=$actions
    }
    visual=[ordered]@{
        path=$visual
        sha256=(Get-FileHash -Algorithm SHA256 -LiteralPath $visual).Hash
        bytes=[int64](Get-Item -LiteralPath $visual).Length
        parserErrors=@($errors).Count
        parameterNames=$parameters
        candidateInvocationParametersPresent=$missingParameters.Count-eq0
    }
    writesPerformed=$false
    taskMutationPerformed=$false
    reviewOnly=$true
    productionRoutingEnabled=$false
}|ConvertTo-Json -Depth 12
