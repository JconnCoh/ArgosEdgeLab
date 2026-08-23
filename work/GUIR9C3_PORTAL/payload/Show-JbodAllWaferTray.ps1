[CmdletBinding()]
param(
    [string]$StateRoot = 'C:\ProgramData\ArgosEdgeLabRO\AllWaferProcessorV2',
    [switch]$StartHidden,
    [switch]$Rehearsal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($Rehearsal) {
    $self = Get-Content -LiteralPath $MyInvocation.MyCommand.Path -Raw
    $forbiddenScope = '$' + 'script:'
    if ($self.Contains($forbiddenScope)) { throw 'Rehearsal found forbidden script-scope callback state.' }
    foreach ($token in @('ActiveChildOperation','ReadToEndAsync()','TimeoutSeconds = 120','SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING','READ_ONLY_INSITE_LOOKUP_REQUIRED','MetadataHold')) {
        if (-not $self.Contains($token)) { throw "Rehearsal source token is absent: $token" }
    }
    $fakeForm = [pscustomobject]@{Tag = [pscustomobject]@{
        ActivityLines = New-Object 'Collections.Generic.Queue[string]'
        LastActivityKey = ''
        ExitRequested = $false
        LastGoodCatalog = $null
        LastGoodStatus = $null
        LastGoodScribeQueue = $null
        ActiveChildOperation = $null
        ActivityLogFaulted = $false
    }}
    foreach ($index in 1..12) {
        $fakeForm.Tag.ActivityLines.Enqueue("tick-$index")
        while ($fakeForm.Tag.ActivityLines.Count -gt 10) { [void]$fakeForm.Tag.ActivityLines.Dequeue() }
    }
    if ($fakeForm.Tag.ActivityLines.Count -ne 10 -or $fakeForm.Tag.ActivityLines.Peek() -ne 'tick-3') {
        throw 'Bounded captured activity queue rehearsal failed.'
    }
    $operationStates = @('PASS','FAILED','TIMEOUT')
    if (@($operationStates | Sort-Object -Unique).Count -ne 3) { throw 'Operation terminal-state rehearsal failed.' }
    [ordered]@{
        schema = 'argos_guir4_tray_rehearsal_v1'
        checkedUtc = [DateTime]::UtcNow.ToString('o')
        state = 'PASS_GUIR4_TRAY_REHEARSAL'
        activityLines = $fakeForm.Tag.ActivityLines.Count
        fixedTimerTicks = 4
        childTerminalStates = $operationStates
        mutableCallbackStateOnCapturedForm = $true
        childProcessesStarted = 0
        durableWrites = 0
        reviewOnly = $true
        productionRoutingEnabled = $false
    } | ConvertTo-Json -Depth 5
    return
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$createdNew = $false
$mutex = New-Object Threading.Mutex($true, 'Local\ArgosEdgeLabAllWaferTrayReviewOnlyV2', [ref]$createdNew)
$showEvent = New-Object Threading.EventWaitHandle($false,
    [Threading.EventResetMode]::AutoReset, 'Local\ArgosEdgeLabAllWaferTrayShowV2')
if (-not $createdNew) {
    [void]$showEvent.Set()
    $showEvent.Dispose()
    $mutex.Dispose()
    return
}

$statusPath = Join-Path $StateRoot 'state\STATUS.json'
$catalogPath = Join-Path $StateRoot 'catalog\ALL_WAFER_CATALOG.json'
$processorStatusPath = Join-Path $StateRoot 'processor\PROCESSOR_STATUS.json'
$ledgerPath = Join-Path $StateRoot 'processor\PROCESSING_LEDGER.json'
$scribeQueuePath = Join-Path $StateRoot 'identity\SCRIBE_IDENTITY_QUEUE.json'
$scribeWorkerStatusPath = Join-Path $StateRoot 'identity\SCRIBE_WORKER_STATUS.json'
$scribeGalleryPath = Join-Path $StateRoot 'identity\SCRIBE_VERIFICATION_GALLERY.html'
$processorConfigPath = Join-Path $StateRoot 'PROCESSOR_CONFIG.json'
$scribeImportPath = Join-Path $StateRoot 'Import-JbodScribeVerificationResponse.ps1'
$insiteExportPath = Join-Path $StateRoot 'Export-JbodPendingInsiteRequest.ps1'
$insiteImportPath = Join-Path $StateRoot 'Import-JbodLiveInsiteSnapshot.ps1'
$manifestPath = Join-Path $StateRoot 'dashboard_manifest.json'
$viewerPath = Join-Path $StateRoot 'ArgosEdgeLab.JbodCompositeAccepted.V1_2.exe'
$completedLotLauncherPath = Join-Path $StateRoot 'Open-JbodCompletedLot.ps1'
$fallbackReviewRoot = Join-Path $StateRoot 'outputs\review_only'


function Read-JsonSnapshot([string]$Path,[int]$Attempts=6,[int]$DelayMilliseconds=50) {
    $lastError=$null
    for($attempt=1;$attempt-le$Attempts;$attempt++){
        try {
            $stream=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,
                [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
            try {
                $reader=New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true)
                try { $text=$reader.ReadToEnd() } finally { $reader.Dispose() }
            } finally { $stream.Dispose() }
            if([string]::IsNullOrWhiteSpace($text)){throw "JSON snapshot is empty: $Path"}
            return ($text|ConvertFrom-Json)
        } catch {
            $lastError=$_
            if($attempt-lt$Attempts){Start-Sleep -Milliseconds $DelayMilliseconds}
        }
    }
    throw $lastError
}

function Get-ConfiguredReviewRoot {
    $candidate=$fallbackReviewRoot
    if(Test-Path -LiteralPath $processorConfigPath -PathType Leaf){
        $config=Read-JsonSnapshot $processorConfigPath
        if(($config.PSObject.Properties.Name-contains'outputRoot')-and-not[string]::IsNullOrWhiteSpace([string]$config.outputRoot)){$candidate=[string]$config.outputRoot}
    }
    $full=[IO.Path]::GetFullPath($candidate)
    $root=[IO.Path]::GetPathRoot($full)
    foreach($component in @($full.Substring($root.Length).Split([char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))){if($component.Length-gt80){throw "Review output component exceeds 80 characters: $component"}}
    if(($full.Length+32)-ge200){throw "Review output path must remain below effective length 200: $full"}
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}

function Get-ConfiguredMetadataSnapshotRoot {
    $candidate=Join-Path $StateRoot 'metadata\verified'
    if(Test-Path -LiteralPath $processorConfigPath -PathType Leaf){
        $config=Read-JsonSnapshot $processorConfigPath
        if([string]$config.schema-notin@('argos_jbod_all_wafer_processor_config_v2','argos_jbod_all_wafer_processor_config_v3') -or
           -not[bool]$config.reviewOnly -or [bool]$config.xmlExportEnabled -or [bool]$config.productionRoutingEnabled){
            throw 'Tray metadata-root config safety contract refused.'
        }
        if(($config.PSObject.Properties.Name-contains'metadataSnapshotRoot')-and-not[string]::IsNullOrWhiteSpace([string]$config.metadataSnapshotRoot)){
            $candidate=[string]$config.metadataSnapshotRoot
        }
    }
    $full=[IO.Path]::GetFullPath($candidate)
    $root=[IO.Path]::GetPathRoot($full)
    foreach($component in @($full.Substring($root.Length).Split([char[]]@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))){
        if($component.Length-gt80){throw "Metadata snapshot component exceeds 80 characters: $component"}
    }
    if(($full.Length+32)-ge200){throw "Metadata snapshot path must remain below effective length 200: $full"}
    return $full.TrimEnd([IO.Path]::DirectorySeparatorChar)
}
function Test-ObjectProperties([AllowNull()][object]$Object,[string[]]$Names) {
    if ($null -eq $Object) { return $false }
    foreach ($name in $Names) {
        if ($null -eq $Object.PSObject.Properties[$name]) { return $false }
    }
    return $true
}

function Test-StatusSnapshot([AllowNull()][object]$Candidate) {
    if (-not (Test-ObjectProperties $Candidate @('updatedUtc','detail','rawSearchRoot','counts'))) { return $false }
    return (Test-ObjectProperties $Candidate.counts @('stable','routeReady','held','waiting'))
}

function Test-ScribeQueueSnapshot([AllowNull()][object]$Candidate) {
    if (-not (Test-ObjectProperties $Candidate @('counts'))) { return $false }
    return (Test-ObjectProperties $Candidate.counts @('confirmed','proposalPending','proposalReady','insiteLookupPending','held'))
}

function Test-ScribeWorkerSnapshot([AllowNull()][object]$Candidate) {
    return (Test-ObjectProperties $Candidate @('state','updatedUtc'))
}

function Test-LedgerSnapshot([AllowNull()][object]$Candidate) {
    if (-not (Test-ObjectProperties $Candidate @('rows'))) { return $false }
    foreach ($row in @($Candidate.rows)) {
        if (-not (Test-ObjectProperties $row @('identity','state'))) { return $false }
    }
    return $true
}

function Test-CatalogSnapshot([AllowNull()][object]$Candidate) {
    if (-not (Test-ObjectProperties $Candidate @('acquisitions'))) { return $false }
    foreach ($row in @($Candidate.acquisitions)) {
        if (-not (Test-ObjectProperties $row @('identity','routeState','waferId','scanDateLocal','lot','scanTimestampLocal','slot','domain','step','tool'))) {
            return $false
        }
    }
    return $true
}

function Show-StatusWindow {
    if (-not $form.Visible) { $form.Show() }
    $form.WindowState = [Windows.Forms.FormWindowState]::Normal
    $form.ShowInTaskbar = $true
    $form.Activate()
}

function Open-ReviewApplication {
    try {
        if (-not (Test-Path -LiteralPath $completedLotLauncherPath -PathType Leaf)) { throw "Completed Lot launcher is missing: $completedLotLauncherPath" }
        $result = & $completedLotLauncherPath -StateRoot $StateRoot | Out-String | ConvertFrom-Json
        if ([string]$result.state -ne 'PASS_COMPLETED_LOT_WINDOW_PRESENTED') { throw "Completed Lot launcher returned an unexpected state: $($result.state)" }
        Add-ActivityLine ('Completed Lot opened; PID {0}; launch log {1}.' -f $result.processId,$result.launchLog)
    } catch {
        Add-ActivityLine ('Completed Lot launch failed: ' + $_.Exception.Message)
        [void][Windows.Forms.MessageBox]::Show($form,
            $_.Exception.Message,
            'Completed Lot launch failed',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Open-ScribeReview {
    if(Test-Path -LiteralPath $scribeGalleryPath -PathType Leaf){Start-Process -FilePath $scribeGalleryPath}
}

function ConvertTo-NativeQuotedScalar([string]$Value) {
    if ($Value.Contains('"')) { throw 'Native scalar arguments cannot contain a quote character.' }
    return '"' + $Value + '"'
}

function Get-OptionalFileEvidence([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return [pscustomobject][ordered]@{
        path = [IO.Path]::GetFullPath($Path)
        bytes = [int64](Get-Item -LiteralPath $Path).Length
        sha256 = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
        lastWriteUtc = (Get-Item -LiteralPath $Path).LastWriteTimeUtc.ToString('o')
    }
}

function Write-GuiOperationRecord([object]$Operation,[string]$State,[int]$ExitCode,[string]$Detail) {
    $operationRoot = Join-Path $StateRoot 'state\gui_operation_results'
    if (-not (Test-Path -LiteralPath $operationRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $operationRoot -Force)
    }
    $safeState = $State -replace '[^A-Z0-9_]', '_'
    $recordPath = Join-Path $operationRoot ($Operation.Id + '.' + $safeState + '.json')
    $outputEvidence = Get-OptionalFileEvidence ([string]$Operation.OutputPath)
    $queueAfter = Get-OptionalFileEvidence $scribeQueuePath
    $galleryAfter = Get-OptionalFileEvidence $scribeGalleryPath
    $record = [ordered]@{
        schema = 'argos_gui_child_operation_result_v1'
        createdUtc = [DateTime]::UtcNow.ToString('o')
        operationId = [string]$Operation.Id
        operationKind = [string]$Operation.Kind
        state = $State
        startedUtc = [string]$Operation.StartedUtc
        finishedUtc = [DateTime]::UtcNow.ToString('o')
        timeoutSeconds = [int]$Operation.TimeoutSeconds
        childExe = [string]$Operation.ChildExe
        childScript = [string]$Operation.ScriptPath
        childScriptSha256 = [string]$Operation.ScriptSha256
        childPid = [int]$Operation.Process.Id
        exitCode = $ExitCode
        input = $Operation.InputEvidence
        output = $outputEvidence
        queueBefore = $Operation.QueueBefore
        queueAfter = $queueAfter
        galleryBefore = $Operation.GalleryBefore
        galleryAfter = $galleryAfter
        detail = $Detail
        reviewOnly = $true
        productionRoutingEnabled = $false
    }
    $json = $record | ConvertTo-Json -Depth 8
    $encoding = New-Object Text.UTF8Encoding($false)
    $stream = [IO.File]::Open($recordPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
        $writer = New-Object IO.StreamWriter($stream,$encoding)
        try { $writer.Write($json + [Environment]::NewLine) } finally { $writer.Dispose() }
    } finally { if ($null -ne $stream) { $stream.Dispose() } }
    return $recordPath
}

function Set-GuiOperationControls([bool]$Enabled) {
    $importScribe.Enabled = $Enabled -and (Test-Path -LiteralPath $scribeImportPath -PathType Leaf)
    $importInsite.Enabled = $Enabled -and (Test-Path -LiteralPath $insiteImportPath -PathType Leaf)
    $importScribeItem.Enabled = $importScribe.Enabled
    $importInsiteItem.Enabled = $importInsite.Enabled
    if (-not $Enabled) {
        $exportInsite.Enabled = $false
        $exportInsiteItem.Enabled = $false
    }
}

function Start-GuiChildOperation([string]$Kind,[string]$ScriptPath,[string]$Arguments,[string]$InputPath,[string]$OutputPath,[string]$DisplayName) {
    if ($null -ne $form.Tag.ActiveChildOperation) {
        [void][Windows.Forms.MessageBox]::Show($form,'One bounded GUI operation is already active. Wait for its terminal result.','Operation already active',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    $resolvedScript = [IO.Path]::GetFullPath($ScriptPath)
    $resolvedStateRoot = [IO.Path]::GetFullPath($StateRoot).TrimEnd('\') + '\'
    if (-not $resolvedScript.StartsWith($resolvedStateRoot,[StringComparison]::OrdinalIgnoreCase) -or
        -not (Test-Path -LiteralPath $resolvedScript -PathType Leaf)) {
        throw "GUI child script is not an installed StateRoot file: $resolvedScript"
    }
    $powerShell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShell -PathType Leaf)) { throw "Windows PowerShell 5.1 is missing: $powerShell" }
    $startInfo = New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName = $powerShell
    $startInfo.Arguments = $Arguments
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $startInfo
    $operation = [pscustomobject][ordered]@{
        Id = [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '_' + [Guid]::NewGuid().ToString('N').Substring(0,8)
        Kind = $Kind
        DisplayName = $DisplayName
        ScriptPath = $resolvedScript
        ScriptSha256 = (Get-FileHash -LiteralPath $resolvedScript -Algorithm SHA256).Hash
        ChildExe = $powerShell
        InputEvidence = Get-OptionalFileEvidence $InputPath
        OutputPath = $OutputPath
        QueueBefore = Get-OptionalFileEvidence $scribeQueuePath
        GalleryBefore = Get-OptionalFileEvidence $scribeGalleryPath
        StartedUtc = [DateTime]::UtcNow.ToString('o')
        TimeoutSeconds = 120
        DrainWaitTicks = 0
        Process = $process
        StdoutTask = $null
        StderrTask = $null
    }
    try {
        [void]$process.Start()
        $operation.StdoutTask = $process.StandardOutput.ReadToEndAsync()
        $operation.StderrTask = $process.StandardError.ReadToEndAsync()
        $form.Tag.ActiveChildOperation = $operation
        Set-GuiOperationControls $false
        Add-ActivityLine ($DisplayName + ' started; bounded to 120 seconds.')
    } catch {
        $process.Dispose()
        throw
    }
}

function Complete-GuiChildOperationIfReady {
    $operation = $form.Tag.ActiveChildOperation
    if ($null -eq $operation) { return }
    $timedOut = (([DateTime]::UtcNow - [DateTime]$operation.StartedUtc).TotalSeconds -ge [int]$operation.TimeoutSeconds)
    if (-not $operation.Process.HasExited -and -not $timedOut) { return }
    try {
        if ($timedOut -and -not $operation.Process.HasExited) {
            try { $operation.Process.Kill() } catch {}
            [void]$operation.Process.WaitForExit(5000)
        }
        if (-not $operation.StdoutTask.IsCompleted -or -not $operation.StderrTask.IsCompleted) {
            $operation.DrainWaitTicks = [int]$operation.DrainWaitTicks + 1
            if ([int]$operation.DrainWaitTicks -le 3) { return }
            throw 'Child output drain did not finish within three fixed timer ticks.'
        }
        $stdout = [string]$operation.StdoutTask.Result
        $stderr = [string]$operation.StderrTask.Result
        $exitCode = if ($timedOut) { -1 } else { [int]$operation.Process.ExitCode }
        $detail = ($stderr + [Environment]::NewLine + $stdout).Trim()
        if ($detail.Length -gt 4000) { $detail = $detail.Substring(0,4000) }
        if ($timedOut) { throw ($operation.DisplayName + ' exceeded its 120-second deadline and its exact child process was terminated.') }
        if ($exitCode -ne 0) { throw ($operation.DisplayName + " failed with exit code $exitCode.`r`n" + $detail) }

        $message = ''
        if ([string]$operation.Kind -eq 'INSITE_EXPORT') {
            if (-not (Test-Path -LiteralPath $operation.OutputPath -PathType Leaf)) { throw 'Insite exporter returned success without its declared output file.' }
            $export = Read-JsonSnapshot $operation.OutputPath
            if ([string]$export.schema -ne 'argos_jbod_pending_insite_request_v1' -or -not [bool]$export.reviewOnly -or [bool]$export.imagesIncluded -or [bool]$export.credentialsIncluded) {
                throw 'Insite export output safety contract failed.'
            }
            $message = "Read-only Insite request exported safely.`r`n`r`n$($operation.OutputPath)`r`nSHA-256: $((Get-FileHash -LiteralPath $operation.OutputPath -Algorithm SHA256).Hash)`r`nActionable acquisitions: $($export.pendingAcquisitions)`r`n`r`nExport does not decrement the queue. Counts change only after a matching read-only Insite snapshot is imported and the queue rebuilds."
        } elseif ([string]$operation.Kind -eq 'SCRIBE_IMPORT') {
            if (-not (Test-Path -LiteralPath $scribeQueuePath -PathType Leaf) -or -not (Test-Path -LiteralPath $scribeGalleryPath -PathType Leaf)) { throw 'Scribe importer returned success without the refreshed queue and gallery.' }
            $message = "Scribe review imported safely.`r`n`r`n$($operation.InputEvidence.path)`r`nSHA-256: $($operation.InputEvidence.sha256)`r`n`r`nThe installed importer completed its queue and gallery refresh."
        } else {
            if (-not (Test-Path -LiteralPath $scribeQueuePath -PathType Leaf)) { throw 'Insite importer returned success without the refreshed identity queue.' }
            $message = "Read-only Insite snapshot imported safely.`r`n`r`n$($operation.InputEvidence.path)`r`nSHA-256: $($operation.InputEvidence.sha256)`r`n`r`nOnly exact complete acquisition/scribe matches can be released by the queue rebuild."
        }
        $recordPath = Write-GuiOperationRecord $operation 'PASS_GUI_CHILD_OPERATION' $exitCode $detail
        Add-ActivityLine ($operation.DisplayName + ' completed; result ' + $recordPath)
        [void][Windows.Forms.MessageBox]::Show($form,$message,$operation.DisplayName + ' completed',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information)
        if ([string]$operation.Kind -eq 'SCRIBE_IMPORT') { Open-ScribeReview }
    } catch {
        $failureMessage = $_.Exception.Message
        try { $recordPath = Write-GuiOperationRecord $operation 'FAILED_GUI_CHILD_OPERATION' -1 $failureMessage } catch { $recordPath = 'durable result write failed: ' + $_.Exception.Message }
        Add-ActivityLine ($operation.DisplayName + ' failed once; ' + $recordPath)
        [void][Windows.Forms.MessageBox]::Show($form,$failureMessage,$operation.DisplayName + ' failed',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)
    } finally {
        $operation.Process.Dispose()
        $form.Tag.ActiveChildOperation = $null
        Set-GuiOperationControls $true
    }
}

function Import-ScribeReview {
    try {
        if (-not (Test-Path -LiteralPath $scribeImportPath -PathType Leaf)) { throw "Installed scribe import script is missing: $scribeImportPath" }
        if (-not (Test-Path -LiteralPath $processorConfigPath -PathType Leaf)) { throw "Processor configuration is missing: $processorConfigPath" }
        $dialog = New-Object Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select the exact saved scribe review to import'
        $downloads = Join-Path $env:USERPROFILE 'Downloads'
        if (Test-Path -LiteralPath $downloads -PathType Container) { $dialog.InitialDirectory = $downloads }
        $dialog.Filter = 'Scribe response JSON (SCRIBE_VERIFICATION_RESPONSE*.json)|SCRIBE_VERIFICATION_RESPONSE*.json|JSON files (*.json)|*.json'
        $dialog.CheckFileExists = $true
        $dialog.Multiselect = $false
        try { if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }; $selectedPath = $dialog.FileName } finally { $dialog.Dispose() }
        $response = Read-JsonSnapshot $selectedPath
        if ([string]$response.schema -ne 'argos_jbod_scribe_operator_response_v1') { throw 'The selected file is not an Argos scribe operator response.' }
        $responseRows = @($response.rows)
        if ($responseRows.Count -lt 1 -or $responseRows.Count -gt 100) { throw "Refusing response row count outside 1..100: $($responseRows.Count)" }
        $confirmedRows = @($responseRows | Where-Object disposition -eq 'CONFIRMED_VISIBLE_STRING').Count
        $heldRows = @($responseRows | Where-Object disposition -eq 'HOLD_UNREADABLE_OR_CONFLICT').Count
        $choice = [Windows.Forms.MessageBox]::Show($form,"Import this exact file?`r`n`r`n$selectedPath`r`n`r`nRows: $($responseRows.Count)  Confirmed: $confirmedRows  Held: $heldRows`r`n`r`nExisting confirmations are preserved; conflicts are refused.",'Confirm exact scribe-review import',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
        if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File {0} -ConfigPath {1} -ResponsePath {2}' -f (ConvertTo-NativeQuotedScalar $scribeImportPath),(ConvertTo-NativeQuotedScalar $processorConfigPath),(ConvertTo-NativeQuotedScalar $selectedPath)
        Start-GuiChildOperation 'SCRIBE_IMPORT' $scribeImportPath $arguments $selectedPath '' 'Scribe review import'
    } catch {
        Add-ActivityLine ('Scribe import validation failed: ' + $_.Exception.Message)
        [void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'Scribe review import failed',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Export-InsiteRequest {
    try {
        if (-not (Test-Path -LiteralPath $insiteExportPath -PathType Leaf)) { throw "Insite request exporter is missing: $insiteExportPath" }
        $downloads = Join-Path $env:USERPROFILE 'Downloads'
        if (-not (Test-Path -LiteralPath $downloads -PathType Container)) { throw "Downloads folder is missing: $downloads" }
        $output = Join-Path $downloads ('ARGOS_INSITE_PENDING_REQUEST_' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ') + '.json')
        if (Test-Path -LiteralPath $output) { throw "Create-new Insite output already exists: $output" }
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File {0} -StateRoot {1} -MetadataSnapshotRoot {2} -OutputPath {3}' -f (ConvertTo-NativeQuotedScalar $insiteExportPath),(ConvertTo-NativeQuotedScalar $StateRoot),(ConvertTo-NativeQuotedScalar (Get-ConfiguredMetadataSnapshotRoot)),(ConvertTo-NativeQuotedScalar $output)
        Start-GuiChildOperation 'INSITE_EXPORT' $insiteExportPath $arguments '' $output 'Insite request export'
    } catch {
        Add-ActivityLine ('Insite export validation failed: ' + $_.Exception.Message)
        [void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'Insite request export failed',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Import-InsiteSnapshot {
    try {
        if (-not (Test-Path -LiteralPath $insiteImportPath -PathType Leaf)) { throw "Insite snapshot importer is missing: $insiteImportPath" }
        $dialog = New-Object Windows.Forms.OpenFileDialog
        $dialog.Title = 'Select the exact read-only Insite snapshot to import'
        $downloads = Join-Path $env:USERPROFILE 'Downloads'
        if (Test-Path -LiteralPath $downloads -PathType Container) { $dialog.InitialDirectory = $downloads }
        $dialog.Filter = 'Argos Insite snapshot JSON (*.json)|*.json'
        $dialog.CheckFileExists = $true
        $dialog.Multiselect = $false
        try { if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { return }; $selectedPath = $dialog.FileName } finally { $dialog.Dispose() }
        $snapshot = Read-JsonSnapshot $selectedPath
        if ([string]$snapshot.authority -ne 'READ_ONLY_SCRIBE_FIRST_VISUAL_STATE_AND_BACKSIDE_REGIME_SNAPSHOT' -or [string]$snapshot.lookupKey -ne 'confirmed 12-character wafer scribe') { throw 'The selected file is not an eligible Argos read-only Insite snapshot.' }
        $records = @($snapshot.records)
        $exact = @($records | Where-Object { [string]$_.queryState -eq 'MES_READ_ONLY_SNAPSHOT' -and [string]$_.lineage.state -eq 'MES_SCRIBE_LINEAGE_EXACT' -and [string]$_.visualState.state -eq 'COMPLETE' }).Count
        $choice = [Windows.Forms.MessageBox]::Show($form,"Import this exact Insite snapshot?`r`n`r`n$selectedPath`r`n`r`nRecords: $($records.Count)  Exact complete: $exact  Held: $($records.Count-$exact)`r`n`r`nExisting verified rows are preserved; acquisition/scribe conflicts are refused.",'Confirm exact Insite import',[Windows.Forms.MessageBoxButtons]::YesNo,[Windows.Forms.MessageBoxIcon]::Question)
        if ($choice -ne [Windows.Forms.DialogResult]::Yes) { return }
        $arguments = '-NoProfile -ExecutionPolicy Bypass -File {0} -StateRoot {1} -MetadataSnapshotRoot {2} -MesSnapshotPath {3}' -f (ConvertTo-NativeQuotedScalar $insiteImportPath),(ConvertTo-NativeQuotedScalar $StateRoot),(ConvertTo-NativeQuotedScalar (Get-ConfiguredMetadataSnapshotRoot)),(ConvertTo-NativeQuotedScalar $selectedPath)
        Start-GuiChildOperation 'INSITE_IMPORT' $insiteImportPath $arguments $selectedPath '' 'Insite snapshot import'
    } catch {
        Add-ActivityLine ('Insite import validation failed: ' + $_.Exception.Message)
        [void][Windows.Forms.MessageBox]::Show($form,$_.Exception.Message,'Insite snapshot import failed',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error)
    }
}
$form = New-Object Windows.Forms.Form
$form.Text = 'Argos JBOD - all-wafer inspection processor (review only)'
$form.Width = 1420
$form.Height = 870
$form.StartPosition = 'CenterScreen'
$form.BackColor = [Drawing.Color]::FromArgb(12, 20, 25)
$form.ForeColor = [Drawing.Color]::White

$title = New-Object Windows.Forms.Label
$title.SetBounds(20, 18, 1360, 34)
$title.Font = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
$title.Text = 'Waiting for background status...'
$form.Controls.Add($title)

$detail = New-Object Windows.Forms.Label
$detail.SetBounds(20, 58, 1360, 48)
$detail.Font = New-Object Drawing.Font('Segoe UI', 10)
$form.Controls.Add($detail)

$stableLabel = New-Object Windows.Forms.Label
$stableLabel.SetBounds(20, 112, 450, 24)
$form.Controls.Add($stableLabel)
$stableBar = New-Object Windows.Forms.ProgressBar
$stableBar.SetBounds(20, 138, 650, 24)
$form.Controls.Add($stableBar)

$readyLabel = New-Object Windows.Forms.Label
$readyLabel.SetBounds(710, 112, 650, 24)
$form.Controls.Add($readyLabel)
$readyBar = New-Object Windows.Forms.ProgressBar
$readyBar.SetBounds(710, 138, 650, 24)
$form.Controls.Add($readyBar)

$scribeStatusLabel = New-Object Windows.Forms.Label
$scribeStatusLabel.SetBounds(20, 168, 1340, 24)
$scribeStatusLabel.ForeColor = [Drawing.Color]::FromArgb(130, 220, 255)
$scribeStatusLabel.Text = 'Scribe reader: waiting for status...'
$form.Controls.Add($scribeStatusLabel)

$activityLog = New-Object Windows.Forms.TextBox
$activityLog.SetBounds(20, 198, 1340, 112)
$activityLog.Multiline = $true
$activityLog.ReadOnly = $true
$activityLog.ScrollBars = [Windows.Forms.ScrollBars]::Vertical
$activityLog.BackColor = [Drawing.Color]::FromArgb(8, 14, 18)
$activityLog.ForeColor = [Drawing.Color]::FromArgb(190, 235, 205)
$activityLog.Font = New-Object Drawing.Font('Consolas', 9)
$form.Controls.Add($activityLog)
$form.Tag = [pscustomobject]@{
    ActivityLines = New-Object 'Collections.Generic.Queue[string]'
    LastActivityKey = ''
    ExitRequested = $false
    LastGoodCatalog = $null
    LastGoodStatus = $null
    LastGoodScribeQueue = $null
    ActiveChildOperation = $null
    ActivityLogFaulted = $false
    ActivityLogFaultMessage = ''
}
function Add-ActivityLine([string]$Message) {
    try {
        $form.Tag.ActivityLines.Enqueue(('{0}  {1}' -f (Get-Date).ToString('HH:mm:ss'), $Message))
        while ($form.Tag.ActivityLines.Count -gt 10) { [void]$form.Tag.ActivityLines.Dequeue() }
        $activityLog.Lines = $form.Tag.ActivityLines.ToArray()
        $activityLog.SelectionStart = $activityLog.TextLength
        $activityLog.ScrollToCaret()
    } catch {
        if (-not [bool]$form.Tag.ActivityLogFaulted) {
            $form.Tag.ActivityLogFaulted = $true
            $form.Tag.ActivityLogFaultMessage = $_.Exception.Message
            try { $activityLog.Text = 'Activity log unavailable: ' + $_.Exception.Message } catch {}
        }
    }
}
$grid = New-Object Windows.Forms.DataGridView
$grid.SetBounds(20, 320, 1340, 404)
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AutoSizeColumnsMode = 'Fill'
$grid.BackgroundColor = [Drawing.Color]::FromArgb(18, 29, 35)
$grid.ForeColor = [Drawing.Color]::Black
$form.Controls.Add($grid)

$footer = New-Object Windows.Forms.Label
$footer.SetBounds(20, 777, 600, 28)
$footer.Text = 'X hides this monitor in the notification area. Background inspection continues. XML export remains disabled.'
$footer.ForeColor = [Drawing.Color]::FromArgb(255, 205, 72)
$form.Controls.Add($footer)

$importScribe = New-Object Windows.Forms.Button
$importScribe.SetBounds(630, 730, 210, 34)
$importScribe.Text = 'Import saved scribe review...'
$importScribe.BackColor = [Drawing.Color]::FromArgb(72, 92, 112)
$importScribe.ForeColor = [Drawing.Color]::White
$importScribe.FlatStyle = 'Flat'
$importScribe.Enabled = (Test-Path -LiteralPath $scribeImportPath -PathType Leaf)
$importScribe.Add_Click({ Import-ScribeReview })
$form.Controls.Add($importScribe)

$openScribe = New-Object Windows.Forms.Button
$openScribe.SetBounds(850, 730, 250, 34)
$openScribe.Text = 'Review pending scribes'
$openScribe.BackColor = [Drawing.Color]::FromArgb(166, 104, 0)
$openScribe.ForeColor = [Drawing.Color]::White
$openScribe.FlatStyle = 'Flat'
$openScribe.Enabled = $false
$openScribe.Add_Click({ Open-ScribeReview })
$form.Controls.Add($openScribe)

$openReview = New-Object Windows.Forms.Button
$openReview.SetBounds(1120, 730, 240, 34)
$openReview.Text = 'Open completed lot review'
$openReview.BackColor = [Drawing.Color]::FromArgb(0, 115, 170)
$openReview.ForeColor = [Drawing.Color]::White
$openReview.FlatStyle = 'Flat'
$openReview.Enabled = $false
$openReview.Add_Click({ Open-ReviewApplication })
$form.Controls.Add($openReview)

$exportInsite = New-Object Windows.Forms.Button
$exportInsite.SetBounds(630, 772, 210, 34)
$exportInsite.Text = 'Export Insite backlog...'
$exportInsite.BackColor = [Drawing.Color]::FromArgb(70, 96, 116)
$exportInsite.ForeColor = [Drawing.Color]::White
$exportInsite.FlatStyle = 'Flat'
$exportInsite.Enabled = $false
$exportInsite.Add_Click({ Export-InsiteRequest })
$form.Controls.Add($exportInsite)

$importInsite = New-Object Windows.Forms.Button
$importInsite.SetBounds(850, 772, 250, 34)
$importInsite.Text = 'Import Insite snapshot...'
$importInsite.BackColor = [Drawing.Color]::FromArgb(28, 112, 92)
$importInsite.ForeColor = [Drawing.Color]::White
$importInsite.FlatStyle = 'Flat'
$importInsite.Enabled = (Test-Path -LiteralPath $insiteImportPath -PathType Leaf)
$importInsite.Add_Click({ Import-InsiteSnapshot })
$form.Controls.Add($importInsite)

$menu = New-Object Windows.Forms.ContextMenuStrip
$showItem = $menu.Items.Add('Show inspection status')
$reviewItem = $menu.Items.Add('Open completed lot review')
$scribeItem = $menu.Items.Add('Review pending scribe identities')
$importScribeItem = $menu.Items.Add('Import exact saved scribe review...')
$exportInsiteItem = $menu.Items.Add('Export pending Insite request...')
$importInsiteItem = $menu.Items.Add('Import exact read-only Insite snapshot...')
$folderItem = $menu.Items.Add('Open review output folder')
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$exitItem = $menu.Items.Add('Exit monitor only (inspection continues)')

$notify = New-Object Windows.Forms.NotifyIcon
$notify.Icon = [Drawing.SystemIcons]::Information
$notify.Text = 'Argos inspection: starting'
$notify.ContextMenuStrip = $menu
$notify.Visible = $true
$notify.Add_DoubleClick({ Show-StatusWindow })
$showItem.Add_Click({ Show-StatusWindow })
$reviewItem.Add_Click({ Open-ReviewApplication })
$scribeItem.Add_Click({ Open-ScribeReview })
$importScribeItem.Add_Click({ Import-ScribeReview })
$exportInsiteItem.Add_Click({ Export-InsiteRequest })
$importInsiteItem.Add_Click({ Import-InsiteSnapshot })
$folderItem.Add_Click({
    $reviewRoot=Get-ConfiguredReviewRoot
    if (-not (Test-Path -LiteralPath $reviewRoot -PathType Container)) {
        [void](New-Item -ItemType Directory -Path $reviewRoot -Force)
    }
    Start-Process -FilePath 'explorer.exe' -ArgumentList @($reviewRoot)
})
$exitItem.Add_Click({
    $form.Tag.ExitRequested = $true
    $notify.Visible = $false
    $form.Close()
    [Windows.Forms.Application]::ExitThread()
})

$form.Add_FormClosing({
    param($sender, $eventArgs)
    if (-not $form.Tag.ExitRequested -and
        $eventArgs.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
        $eventArgs.Cancel = $true
        $form.Hide()
        $form.ShowInTaskbar = $false
        $notify.BalloonTipTitle = 'Argos inspection is still running'
        $notify.BalloonTipText = 'The monitor is in the notification area. Background processing was not stopped.'
        $notify.ShowBalloonTip(2500)
    }
})
$form.Add_Resize({
    if ($form.WindowState -eq [Windows.Forms.FormWindowState]::Minimized) {
        $form.Hide()
        $form.ShowInTaskbar = $false
    }
})

$timer = New-Object Windows.Forms.Timer
$timer.Interval = 2000
$timer.Add_Tick({
    try {
        Complete-GuiChildOperationIfReady
        if ($showEvent.WaitOne(0)) { Show-StatusWindow }
        if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
            $notify.Text = 'Argos inspection: waiting for status'
            return
        }
        $statusCandidate = Read-JsonSnapshot $statusPath
        if (Test-StatusSnapshot $statusCandidate) {
            $status = $statusCandidate
            $form.Tag.LastGoodStatus = $statusCandidate
        } elseif ($null -ne $form.Tag.LastGoodStatus) {
            $status = $form.Tag.LastGoodStatus
            Add-ActivityLine 'Status refresh deferred: schema-incomplete snapshot ignored; retaining the last valid status.'
        } else {
            Add-ActivityLine 'Status refresh deferred: waiting for the first schema-valid status snapshot.'
            return
        }
        $processor = if (Test-Path -LiteralPath $processorStatusPath -PathType Leaf) {
            Read-JsonSnapshot $processorStatusPath
        } else { $null }
        $processorState = if ($null -eq $processor -or -not $processor.PSObject.Properties['state']) { 'STARTING' } else { [string]$processor.state }
        $current = if ($null -eq $processor -or
            $null-eq$processor.PSObject.Properties['currentIdentity'] -or
            [string]::IsNullOrWhiteSpace([string]$processor.currentIdentity)) {
            'none'
        } elseif ($processor.PSObject.Properties['currentWaferId'] -and
                  -not [string]::IsNullOrWhiteSpace([string]$processor.currentWaferId)) {
            [string]$processor.currentWaferId
        } else { 'WAFER IDENTITY HOLD' }
        $live = $null
        if ($null -ne $processor -and
            $null-ne$processor.PSObject.Properties['outputRoot'] -and
            -not [string]::IsNullOrWhiteSpace([string]$processor.outputRoot)) {
            $livePath = Join-Path ([string]$processor.outputRoot) 'LIVE_PROGRESS.json'
            if (Test-Path -LiteralPath $livePath -PathType Leaf) {
                $live = Read-JsonSnapshot $livePath
            }
        }
        $nativeTilesComplete = 0
        $nativeTilesTotal = 0
        $shadowPeerCount = 0
        if ($null -ne $processor -and
            $processor.PSObject.Properties['outputRoot'] -and
            -not [string]::IsNullOrWhiteSpace([string]$processor.outputRoot)) {
            $workerRoot = Join-Path ([string]$processor.outputRoot) 'workers'
            if (Test-Path -LiteralPath $workerRoot -PathType Container) {
                foreach ($tileProgressFile in @(Get-ChildItem -LiteralPath $workerRoot -Recurse -File -Filter 'TILE_PROGRESS.csv' -ErrorAction SilentlyContinue)) {
                    $nativeTilesComplete += [Math]::Max(0, @(Get-Content -LiteralPath $tileProgressFile.FullName -ErrorAction SilentlyContinue).Count - 1)
                }
            }
            if ($null -ne $live -and $live.PSObject.Properties['tilesTotal']) {
                $nativeTilesTotal = [int]$live.tilesTotal
            }
            if ($processor.PSObject.Properties['jobConfig'] -and
                -not [string]::IsNullOrWhiteSpace([string]$processor.jobConfig) -and
                (Test-Path -LiteralPath ([string]$processor.jobConfig) -PathType Leaf)) {
                $activeJobConfig = Read-JsonSnapshot ([string]$processor.jobConfig)
                if ($null -ne $activeJobConfig -and $activeJobConfig.PSObject.Properties['peerBrightfieldPaths']) {
                    $shadowPeerCount = @($activeJobConfig.peerBrightfieldPaths).Count
                }
            }
        }
        $stage = if ($null -ne $live -and $live.PSObject.Properties['stage']) {
            [string]$live.stage
        } elseif ($null -ne $processor -and $processor.PSObject.Properties['currentStage']) {
            [string]$processor.currentStage
        } else { '' }
        $scribeWorker = if (Test-Path -LiteralPath $scribeWorkerStatusPath -PathType Leaf) {
            $scribeWorkerCandidate = Read-JsonSnapshot $scribeWorkerStatusPath
            if (Test-ScribeWorkerSnapshot $scribeWorkerCandidate) { $scribeWorkerCandidate } else { $null }
        } else { $null }
        $updatedCandidates = New-Object 'Collections.Generic.List[DateTime]'
        $updatedCandidates.Add([DateTime]$status.updatedUtc)
        if ($null-ne$processor -and $processor.PSObject.Properties['updatedUtc']) {
            $updatedCandidates.Add([DateTime]$processor.updatedUtc)
        }
        if ($null-ne$live -and $live.PSObject.Properties['updatedUtc']) {
            $updatedCandidates.Add([DateTime]$live.updatedUtc)
        }
        if ($null-ne$scribeWorker -and $scribeWorker.PSObject.Properties['updatedUtc']) {
            $updatedCandidates.Add([DateTime]$scribeWorker.updatedUtc)
        }
        $latestUpdated = @($updatedCandidates | Sort-Object -Descending)[0]
        $title.Text = 'Processor: {0}   Current: {1}   Updated: {2}' -f
            $processorState, $current, $latestUpdated.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss')
        $stageProgressDetail = ''
        if ($null -ne $live -and $live.PSObject.Properties['workersFinished'] -and $live.PSObject.Properties['workersTotal']) {
            $stageProgressDetail = '   Workers finished: {0}/{1}' -f [int]$live.workersFinished,[int]$live.workersTotal
        }
        if ($nativeTilesTotal -gt 0) {
            $stageProgressDetail += '   Native tiles complete: {0}/{1}' -f $nativeTilesComplete,$nativeTilesTotal
        }
        if ($shadowPeerCount -gt 0) {
            $stageProgressDetail += '   Target-excluded shadow peers: {0}' -f $shadowPeerCount
        }
        if ($null -ne $live -and $live.PSObject.Properties['elapsedSeconds']) {
            $stageProgressDetail += '   Stage elapsed: {0:N0}s' -f [double]$live.elapsedSeconds
        }
        $detail.Text = ('{0}   Stage: {1}{2}{3}Root: {4}' -f
            $status.detail, $stage, $stageProgressDetail, [Environment]::NewLine, $status.rawSearchRoot)
        $statusAcquisitions = [int]$status.counts.stable + [int]$status.counts.waiting
        if ($null -ne $status.counts -and $status.counts.PSObject.Properties['acquisitions']) {
            $statusAcquisitions = [int]$status.counts.acquisitions
        }
        $total = [Math]::Max(1, $statusAcquisitions)
        $stable = [int]$status.counts.stable
        $ready = [int]$status.counts.routeReady
        $held = [int]$status.counts.held
        $stableBar.Maximum = $total
        $stableBar.Value = [Math]::Min($total, $stable)
        $progress = if ($null -ne $live -and $live.PSObject.Properties['progressPercent']) {
            [int]$live.progressPercent
        } elseif ($null -eq $processor -or -not $processor.PSObject.Properties['progressPercent']) { 0 } else { [int]$processor.progressPercent }
        $readyBar.Maximum = 100
        $readyBar.Value = [Math]::Min(100, [Math]::Max(0, $progress))
        $stableLabel.Text = 'Stable inputs: {0}/{1}   Waiting: {2}' -f $stable, $total, $status.counts.waiting
        $scribePending = 0
        $scribeConfirmed = 0
        $scribeProposalPending = 0
        $scribeReady = 0
        $scribeInsitePending = 0
        $scribeInsiteActionable = 0
        $scribeInsiteMetadataHold = 0
        $scribeInputHolds = 0
        if (Test-Path -LiteralPath $scribeQueuePath -PathType Leaf) {
            $scribeQueueCandidate = Read-JsonSnapshot $scribeQueuePath
            if (Test-ScribeQueueSnapshot $scribeQueueCandidate) {
                $scribeQueue = $scribeQueueCandidate
                $form.Tag.LastGoodScribeQueue = $scribeQueueCandidate
            } elseif ($null -ne $form.Tag.LastGoodScribeQueue) {
                $scribeQueue = $form.Tag.LastGoodScribeQueue
                Add-ActivityLine 'Scribe queue refresh deferred: schema-incomplete snapshot ignored; retaining the last valid queue.'
            } else {
                Add-ActivityLine 'Scribe queue refresh deferred: waiting for the first schema-valid queue snapshot.'
                return
            }
            $scribeConfirmed = [int]$scribeQueue.counts.confirmed
            $scribeProposalPending = [int]$scribeQueue.counts.proposalPending
            $scribeReady = [int]$scribeQueue.counts.proposalReady
            $scribeInsitePending = [int]$scribeQueue.counts.insiteLookupPending
            $scribeInsiteActionable = @($scribeQueue.rows | Where-Object { [string]$_.state -eq 'SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING' -and [string]$_.nextAction -eq 'READ_ONLY_INSITE_LOOKUP_REQUIRED' }).Count
            $scribeInsiteMetadataHold = @($scribeQueue.rows | Where-Object { [string]$_.state -eq 'SCRIBE_CONFIRMED_INSITE_LOOKUP_PENDING' -and [string]$_.nextAction -eq 'NONE' }).Count
            if ($scribeInsitePending -ne ($scribeInsiteActionable + $scribeInsiteMetadataHold)) { throw 'Insite pending rows do not split exactly into actionable lookup and metadata hold cohorts.' }
            $scribeInputHolds = [int]$scribeQueue.counts.held
            $scribePending = $scribeProposalPending + $scribeReady + $scribeInputHolds
            $workerState = if ($null-eq$scribeWorker) { 'STARTING' } else { [string]$scribeWorker.state }
            $workerUpdated = if ($null-eq$scribeWorker) { 'not available' } else {
                ([DateTime]$scribeWorker.updatedUtc).ToLocalTime().ToString('HH:mm:ss')
            }
            $scribeStatusLabel.Text = 'Scribe reader: {0}   Updated: {1}   Confirmed: {2}   Reader backlog: {3}   Operator review holds: {4}   Insite actionable: {5}   Insite metadata holds: {6}   Other input holds: {7}' -f
                $workerState,$workerUpdated,$scribeConfirmed,$scribeProposalPending,$scribeReady,$scribeInsiteActionable,$scribeInsiteMetadataHold,$scribeInputHolds
        } else {
            $workerState = if ($null-eq$scribeWorker) { 'STARTING' } else { [string]$scribeWorker.state }
            $scribeStatusLabel.Text = 'Scribe reader: {0}; waiting for identity queue...' -f $workerState
        }
        $readyLabel.Text = 'Job: {0}%   Route-ready: {1}   Input holds: {2}   Scribe review holds: {3}' -f $progress, $ready, $held, $scribeReady
        $activityKey = '{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}|{8}|{9}|{10}|{11}' -f
            $processorState,$current,$stage,$progress,$workerState,$scribeConfirmed,$scribeProposalPending,$scribeReady,$scribeInsiteActionable,$scribeInsiteMetadataHold,$scribeInputHolds,$held
        if ($activityKey -ne [string]$form.Tag.LastActivityKey) {
            Add-ActivityLine ('Detector {0}, {1}, stage {2}, {3}%; scribe {4}: confirmed {5}, pending {6}, review {7}, Insite actionable {8}, metadata holds {9}, other holds {10}.' -f
                $processorState,$current,$stage,$progress,$workerState,$scribeConfirmed,$scribeProposalPending,$scribeReady,$scribeInsiteActionable,$scribeInsiteMetadataHold,$scribeInputHolds)
            $form.Tag.LastActivityKey = $activityKey
        }
        $openReview.Enabled = (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
            (Test-Path -LiteralPath $viewerPath -PathType Leaf) -and
            (Test-Path -LiteralPath $completedLotLauncherPath -PathType Leaf)
        $reviewItem.Enabled = $openReview.Enabled
        $scribeItem.Enabled = (Test-Path -LiteralPath $scribeGalleryPath -PathType Leaf)
        $guiOperationIdle = $null -eq $form.Tag.ActiveChildOperation
        $importScribe.Enabled = $guiOperationIdle -and (Test-Path -LiteralPath $scribeImportPath -PathType Leaf)
        $importScribeItem.Enabled = $importScribe.Enabled
        $exportInsite.Enabled = $guiOperationIdle -and $scribeInsiteActionable -gt 0 -and (Test-Path -LiteralPath $insiteExportPath -PathType Leaf)
        $exportInsite.Text = if ($scribeInsiteActionable -gt 0) { 'Export ' + $scribeInsiteActionable + ' actionable Insite lookups...' } elseif ($scribeInsiteMetadataHold -gt 0) { $scribeInsiteMetadataHold.ToString() + ' metadata holds; nothing exportable' } else { 'No actionable Insite lookups' }
        $exportInsiteItem.Enabled = $exportInsite.Enabled
        $importInsite.Enabled = $guiOperationIdle -and (Test-Path -LiteralPath $insiteImportPath -PathType Leaf)
        $importInsiteItem.Enabled = $importInsite.Enabled
        $openScribe.Enabled = $scribeReady -gt 0 -and (Test-Path -LiteralPath $scribeGalleryPath -PathType Leaf)
        $openScribe.Text = if ($scribeReady -gt 0) { 'Review {0} held scribe proposals' -f $scribeReady } else { 'No scribe reviews ready' }
        $notify.Icon = if ($processorState -eq 'FAILED') { [Drawing.SystemIcons]::Error } elseif ($held -gt 0) {
            [Drawing.SystemIcons]::Warning
        } else { [Drawing.SystemIcons]::Information }
        $notify.Text = ('Argos: {0}; ready {1}; holds {2}' -f $processorState, $ready, $held)
        if ($notify.Text.Length -gt 63) { $notify.Text = $notify.Text.Substring(0, 63) }
        if (Test-Path -LiteralPath $catalogPath -PathType Leaf) {
            $catalogCandidate = Read-JsonSnapshot $catalogPath
            $catalog = $null
            if (Test-CatalogSnapshot $catalogCandidate) {
                $catalog = $catalogCandidate
                $form.Tag.LastGoodCatalog = $catalogCandidate
            } elseif ($null -ne $form.Tag.LastGoodCatalog) {
                $catalog = $form.Tag.LastGoodCatalog
                Add-ActivityLine 'Catalog refresh deferred: schema-incomplete snapshot ignored; retaining the last valid catalog.'
            }
            if ($null -eq $catalog) {
                Add-ActivityLine 'Catalog refresh deferred: waiting for the first schema-valid acquisition snapshot.'
                return
            }
            $ledgerByIdentity = @{}
            if (Test-Path -LiteralPath $ledgerPath -PathType Leaf) {
                $ledger = Read-JsonSnapshot $ledgerPath
                if (Test-LedgerSnapshot $ledger) {
                    foreach ($entry in @($ledger.rows)) { $ledgerByIdentity[[string]$entry.identity] = [string]$entry.state }
                } else {
                    Add-ActivityLine 'Ledger refresh deferred: schema-incomplete snapshot ignored for this refresh.'
                }
            }
            $routeReadyRows = @($catalog.acquisitions | Where-Object { [string]$_.routeState -like 'READY_*' })
            $routeReadyRecorded = @($routeReadyRows | Where-Object { $ledgerByIdentity.ContainsKey([string]$_.identity) }).Count
            $routeReadyUnrecorded = [Math]::Max(0, $routeReadyRows.Count - $routeReadyRecorded)
            $readyLabel.Text = 'Job: {0}%   Route-ready ledger: {1}/{2} recorded; {3} active/unrecorded   Input holds: {4}   Scribe review holds: {5}' -f
                $progress,$routeReadyRecorded,$routeReadyRows.Count,$routeReadyUnrecorded,$held,$scribeReady
            $rows = @($catalog.acquisitions | Select-Object -First 250 | ForEach-Object {
                $operatorId = if ([string]::IsNullOrWhiteSpace([string]$_.waferId)) { 'WAFER IDENTITY HOLD' } else { [string]$_.waferId }
                [pscustomobject]@{
                    Wafer = $operatorId; Date = $_.scanDateLocal; Lot = $_.lot; Time = $_.scanTimestampLocal
                    Slot = $_.slot; Domain = $_.domain; Step = $_.step; Tool = $_.tool
                    Route = $_.routeState
                    Processing = $(if ($ledgerByIdentity.ContainsKey([string]$_.identity)) { $ledgerByIdentity[[string]$_.identity] } else { 'PENDING' })
                }
            })
            $grid.DataSource = $rows
        }
    }
    catch {
        $detail.Text = $_.Exception.Message
        $errorKey = 'ERROR|' + $_.Exception.Message
        if ($errorKey -ne [string]$form.Tag.LastActivityKey) { Add-ActivityLine ('Monitor error: ' + $_.Exception.Message); $form.Tag.LastActivityKey = $errorKey }
        $notify.Icon = [Drawing.SystemIcons]::Error
        $notify.Text = 'Argos monitor error; inspection task is independent'
    }
})

$form.Add_Shown({ $timer.Start() })
try {
    $timer.Start()
    if (-not $StartHidden) { Show-StatusWindow }
    [Windows.Forms.Application]::Run()
}
finally {
    if ($null -ne $form.Tag.ActiveChildOperation) {
        try { if (-not $form.Tag.ActiveChildOperation.Process.HasExited) { $form.Tag.ActiveChildOperation.Process.Kill() } } catch {}
        try { $form.Tag.ActiveChildOperation.Process.Dispose() } catch {}
        $form.Tag.ActiveChildOperation = $null
    }
    $timer.Stop()
    $timer.Dispose()
    $notify.Visible = $false
    $notify.Dispose()
    $menu.Dispose()
    $showEvent.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}
