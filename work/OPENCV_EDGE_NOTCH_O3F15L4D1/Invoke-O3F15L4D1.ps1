#Requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Preflight,
    [switch]$PackageLeafPreflight,
    [switch]$Rehearsal,
    [string]$InvocationManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:D1ChildStarted = $false
$script:D1ChildContext = $null

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Sha([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash }
function Sha-Text([string]$Value) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($algorithm.ComputeHash([Text.Encoding]::UTF8.GetBytes($Value)))).Replace('-', '') }
    finally { $algorithm.Dispose() }
}
function Required-Property([object]$Value, [string]$Name) {
    $property = $Value.PSObject.Properties[$Name]
    Require ($null -ne $property) "O3F15L4D1 required property absent: $Name"
    $property.Value
}
function Assert-Hex256([object]$Value, [string]$Label) {
    Require ([string]$Value -cmatch '^[0-9A-F]{64}$') "O3F15L4D1 invalid SHA-256: $Label"
}
function Get-BoundedTail([string]$Value, [int]$MaximumCharacters, [int]$MaximumBytes) {
    $tail = if ($Value.Length -le $MaximumCharacters) { $Value } else { $Value.Substring($Value.Length - $MaximumCharacters) }
    while ([Text.Encoding]::UTF8.GetByteCount($tail) -gt $MaximumBytes -and $tail.Length -gt 0) { $tail = $tail.Substring(1) }
    [ordered]@{ value=$tail; characters=$tail.Length; bytes=[Text.Encoding]::UTF8.GetByteCount($tail); truncated=($tail.Length -ne $Value.Length) }
}
function Assert-ChildArgument([string]$Value, [string]$Label) {
    Require (-not [string]::IsNullOrWhiteSpace($Value)) "O3F15L4D1 empty child argument: $Label"
    Require ($Value.IndexOfAny([char[]]@('"', "`r", "`n")) -lt 0) "O3F15L4D1 child argument contains a forbidden character: $Label"
}
function Invoke-OwnedPreflight([string]$Python, [string]$Runner, [string]$WorkingDirectory, [int]$TimeoutSeconds, [int]$MaximumOutputBytes, [string]$FixtureMode) {
    $arguments = @('-I','-B',$Runner,'PREFLIGHT')
    foreach ($value in @($Python,$WorkingDirectory) + $arguments) { Assert-ChildArgument $value 'PREFLIGHT' }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Python
    $start.Arguments = [string]::Join(' ', @($arguments | ForEach-Object { '"' + $_ + '"' }))
    $start.WorkingDirectory = $WorkingDirectory
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.EnvironmentVariables['PYTHONDONTWRITEBYTECODE'] = '1'
    $start.EnvironmentVariables['PYTHONNOUSERSITE'] = '1'
    $start.EnvironmentVariables['PYTHONUTF8'] = '1'
    if (-not [string]::IsNullOrWhiteSpace($FixtureMode)) { $start.EnvironmentVariables['ARGOS_O3F15L4D1_FIXTURE_MODE'] = $FixtureMode }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    Require $process.Start() 'O3F15L4D1 PREFLIGHT child did not start.'
    $script:D1ChildStarted = $true
    $processId = [int]$process.Id
    $startedUtc = $process.StartTime.ToUniversalTime().ToString('o')
    $script:D1ChildContext = [ordered]@{ processId=$processId; startedUtc=$startedUtc; executable=$Python; arguments=$arguments }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) { try { $process.Kill() } catch { }; $process.WaitForExit() }
    $stdout = [string]$stdoutTask.Result
    $stderr = [string]$stderrTask.Result
    $exitCode = [int]$process.ExitCode
    $process.Dispose()
    $stdoutBytes = [Text.Encoding]::UTF8.GetByteCount($stdout)
    $stderrBytes = [Text.Encoding]::UTF8.GetByteCount($stderr)
    [ordered]@{
        processId=$processId; startedUtc=$startedUtc; timedOut=$timedOut; exitCode=$exitCode
        stdout=$stdout; stderr=$stderr; stdoutBytes=$stdoutBytes; stderrBytes=$stderrBytes
        totalOutputBytes=[int64]$stdoutBytes + [int64]$stderrBytes
        outputExceededBound=(([int64]$stdoutBytes + [int64]$stderrBytes) -gt $MaximumOutputBytes)
        stdoutSha256=Sha-Text $stdout; stderrSha256=Sha-Text $stderr
        arguments=$arguments; workingDirectory=$WorkingDirectory; executable=$Python
    }
}
function Assert-FrozenContract([object]$Contract) {
    Require ([string]$Contract.schema -ceq 'argos_ocv03_o3f15l4d1_metadata_diagnostic_contract_v1') 'O3F15L4D1 contract schema changed.'
    Require ([string]$Contract.state -ceq 'FROZEN_FOR_BUILD') 'O3F15L4D1 contract is not frozen.'
    Require ([string]$Contract.expectedComputerName -ceq 'A1025645101') 'O3F15L4D1 target identity changed.'
    Require ([string]$Contract.runnerSha256 -ceq '0D43F29355B7C8CCB1A9FB3A5275E752D305B61710B17F4E293518A3A94D1B81') 'O3F15L4D1 runner pin changed.'
    Require ([string]$Contract.focusedTestSha256 -ceq 'E98A90ADCF9E705BCA0B57979167FB7F0DAFE526D24FA015EC85DEA6F184BBE0') 'O3F15L4D1 focused-test pin changed.'
    Require ([int]$Contract.maximumOwnedChildCount -eq 1 -and [string]::Join('|', @($Contract.childArguments)) -ceq '-I|-B|Run-O3F15L4FrontReconcile.py|PREFLIGHT') 'O3F15L4D1 sole-child contract changed.'
    Require ([int]$Contract.maximumChildOutputBytes -eq 5242880 -and [int]$Contract.maximumClassificationEvidenceBytes -eq 4194304 -and [int]$Contract.maximumEmittedJsonBytes -eq 7340032 -and [int]$Contract.maximumWholeResponseBytes -eq 8388608) 'O3F15L4D1 byte bounds changed.'
    Require (-not [bool]$Contract.selfTestAllowed -and -not [bool]$Contract.focusedTestAllowedLive -and -not [bool]$Contract.gateAllowed -and -not [bool]$Contract.runAllowed -and -not [bool]$Contract.detectorResultRootCreationAllowed -and -not [bool]$Contract.qSubstAllowed -and -not [bool]$Contract.backgroundLaunchAllowed -and -not [bool]$Contract.imageBytesReadAllowed -and -not [bool]$Contract.sourceMutationAllowed -and -not [bool]$Contract.sourceDeletionAllowed -and -not [bool]$Contract.existingTaskOrProcessActionAllowed -and -not [bool]$Contract.providerActivationAllowed -and -not [bool]$Contract.selectorThresholdRelaxationAllowed -and -not [bool]$Contract.automaticHoldClearanceAllowed -and -not [bool]$Contract.requestRetryAuthorized) 'O3F15L4D1 authority widened.'
}
function Assert-Payload([object]$Contract) {
    $records = @($Contract.payloadFiles)
    Require ($records.Count -eq 17 -and @($records | ForEach-Object { $_.name } | Sort-Object -Unique).Count -eq 17) 'O3F15L4D1 payload cardinality changed.'
    foreach ($record in $records) {
        $name = [string]$record.name
        Require (-not [string]::IsNullOrWhiteSpace($name) -and -not [IO.Path]::IsPathRooted($name) -and $name -notmatch '[\\/]' -and $name -notmatch '^\.') "O3F15L4D1 unsafe payload name: $name"
        $path = Join-Path $PSScriptRoot $name
        Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4D1 package payload absent: $name"
        Require ((Sha $path) -ceq [string]$record.sha256) "O3F15L4D1 package payload changed: $name"
    }
    foreach ($name in @('Invoke-O3F15L4D1.ps1','O3F15L4D1DiagnosticFixture.py','Run-O3F15L4FrontReconcile.py','Test-O3F15L4PathHolds.py','Run-O3F15FrontReconcile.py','Run-O3F14Staged.py','FullPerimeterWaferTopologyOpenCvR11.py','OCV03_NotchReviewOpenCvV1.py')) {
        Require (@($records | Where-Object { [string]$_.name -ceq $name }).Count -eq 1) "O3F15L4D1 required payload absent: $name"
    }
    $records
}
function Assert-Target([object]$Contract) {
    Require ([Environment]::MachineName -ceq [string]$Contract.expectedComputerName) 'O3F15L4D1 diagnostic reached the wrong computer.'
    Require (Test-Path -LiteralPath ([string]$Contract.sourceRoot) -PathType Container) 'O3F15L4D1 source root is absent.'
    foreach ($pin in @($Contract.targetPins)) {
        $path = [string]$pin.path
        Require (Test-Path -LiteralPath $path -PathType Leaf) "O3F15L4D1 target pin is absent: $path"
        Require ((Sha $path) -ceq [string]$pin.sha256) "O3F15L4D1 target pin changed: $path"
    }
}
function Assert-Classification([object]$Classification, [int]$MaximumBytes) {
    $classes = @('DIRECT_SAFE','VERIFIED_SHORT_ALIAS_REQUIRED','DIRECT_USE_HARD_STOP_ALIAS_ONLY')
    $expectedTop = @('classificationLeafIdentitySha256','complete','corpus','hardStopIdentities','identityCount','orderedClassificationRecordSha256','orderedIdentitySha256','orderedSourceLeafRecordSha256','pairClassificationCounts','pairCount','serializedCoreBytes','serializedEvidenceLimitBytes','sourceLeafClassificationCounts','sourceLeafCount','sourceLeavesByClass','uniqueOrderedSourceLeafCount')
    Require ((@($Classification.PSObject.Properties | ForEach-Object {$_.Name} | Sort-Object) -join '|') -ceq (@($expectedTop | Sort-Object) -join '|')) 'O3F15L4D1 classification property set changed.'
    Require ([string](Required-Property $Classification 'corpus') -ceq 'ACTUAL_FROZEN_978' -and [bool](Required-Property $Classification 'complete')) 'O3F15L4D1 classification corpus changed.'
    Require ([int](Required-Property $Classification 'pairCount') -eq 978 -and [int](Required-Property $Classification 'identityCount') -eq 978 -and [int](Required-Property $Classification 'sourceLeafCount') -eq 1956 -and [int](Required-Property $Classification 'uniqueOrderedSourceLeafCount') -eq 1956) 'O3F15L4D1 classification cardinality changed.'
    $pairCounts = Required-Property $Classification 'pairClassificationCounts'
    $leafCounts = Required-Property $Classification 'sourceLeafClassificationCounts'
    $lists = Required-Property $Classification 'sourceLeavesByClass'
    $hashes = Required-Property $Classification 'classificationLeafIdentitySha256'
    foreach ($value in @($pairCounts,$leafCounts,$lists,$hashes)) { Require ((@($value.PSObject.Properties | ForEach-Object {$_.Name} | Sort-Object) -join '|') -ceq (@($classes | Sort-Object) -join '|')) 'O3F15L4D1 class property set changed.' }
    $pairTotal = 0; $leafTotal = 0
    $keys = New-Object 'Collections.Generic.HashSet[string]'
    $identityByOrdinal = @{}; $channelsByOrdinal = @{}; $classByOrdinal = @{}; $uniqueIdentities=New-Object 'Collections.Generic.HashSet[string]'
    $severity = @{DIRECT_SAFE=0;VERIFIED_SHORT_ALIAS_REQUIRED=1;DIRECT_USE_HARD_STOP_ALIAS_ONLY=2}
    $computedLeafCounts = @{DIRECT_SAFE=0;VERIFIED_SHORT_ALIAS_REQUIRED=0;DIRECT_USE_HARD_STOP_ALIAS_ONLY=0}
    foreach ($class in $classes) {
        $pairCount = [int](Required-Property $pairCounts $class); $leafCount = [int](Required-Property $leafCounts $class)
        Require ($pairCount -ge 0 -and $leafCount -ge 0) "O3F15L4D1 negative class count: $class"
        $pairTotal += $pairCount; $leafTotal += $leafCount
        $rows = @((Required-Property $lists $class))
        Require ($rows.Count -eq $leafCount) "O3F15L4D1 class-list cardinality changed: $class"
        $classKeys = New-Object Collections.Generic.List[string]
        foreach ($row in $rows) {
            $directFields=@('canonicalPath','channel','class','effectiveLength','identity','maximumComponentLength','ordinal','rawLength')
            $aliasFields=@($directFields + @('aliasPath','aliasPlannedEffectiveLength','aliasPlannedMaximumComponentLength','aliasPlannedRawLength'))
            $expectedFields=if($class -ceq 'DIRECT_SAFE'){$directFields}else{$aliasFields}
            Require ((@($row.PSObject.Properties | ForEach-Object {$_.Name} | Sort-Object) -join '|') -ceq (@($expectedFields | Sort-Object) -join '|')) "O3F15L4D1 leaf property set changed: $class"
            $ordinal=[int](Required-Property $row 'ordinal'); $identity=[string](Required-Property $row 'identity'); $channel=[string](Required-Property $row 'channel')
            Require ($ordinal -ge 1 -and $ordinal -le 978 -and -not [string]::IsNullOrWhiteSpace($identity) -and $channel -in @('BF','DF') -and [string](Required-Property $row 'class') -ceq $class) "O3F15L4D1 invalid class row: $class"
            Require ($keys.Add("$ordinal|$identity|$channel")) 'O3F15L4D1 duplicate ordered source leaf.'
            if ($identityByOrdinal.ContainsKey($ordinal)) { Require ([string]$identityByOrdinal[$ordinal] -ceq $identity) 'O3F15L4D1 ordinal maps to multiple identities.' } else { Require ($uniqueIdentities.Add($identity)) 'O3F15L4D1 identity appears at multiple ordinals.'; $identityByOrdinal[$ordinal]=$identity }
            if (-not $channelsByOrdinal.ContainsKey($ordinal)) { $channelsByOrdinal[$ordinal]=New-Object 'Collections.Generic.HashSet[string]' }
            Require ($channelsByOrdinal[$ordinal].Add($channel)) 'O3F15L4D1 duplicate ordinal channel.'
            if (-not $classByOrdinal.ContainsKey($ordinal) -or $severity[$class] -gt $severity[[string]$classByOrdinal[$ordinal]]) { $classByOrdinal[$ordinal]=$class }
            $computedLeafCounts[$class]=[int]$computedLeafCounts[$class]+1
            $canonical=[string](Required-Property $row 'canonicalPath')
            $raw=[int](Required-Property $row 'rawLength'); $effective=[int](Required-Property $row 'effectiveLength'); $maximumComponent=[int](Required-Property $row 'maximumComponentLength')
            $canonicalComponents=@($canonical -split '[\\/]' | Where-Object { -not [string]::IsNullOrEmpty($_) })
            $computedCanonicalMaximum=0;foreach($component in $canonicalComponents){if($component.Length -gt $computedCanonicalMaximum){$computedCanonicalMaximum=$component.Length}}
            $expectedDirectory=if($channel -ceq 'BF'){'BrightfieldFrontsideWafer'}else{'DarkfieldFrontsideWafer'}
            $canonicalPattern='^[Dd]:[\\/]KLARFExport[\\/].+[\\/]'+$expectedDirectory+'[\\/]resizedImage[\\/][^\\/]+$'
            Require (-not [string]::IsNullOrWhiteSpace($canonical) -and $canonical -cmatch $canonicalPattern -and $raw -eq $canonical.Length -and $effective -eq ($canonical.Length + 32) -and $maximumComponent -eq $computedCanonicalMaximum -and $maximumComponent -le 80) 'O3F15L4D1 canonical metrics or suffix binding changed.'
            if($class -ceq 'DIRECT_SAFE'){Require ($effective -lt 200) 'O3F15L4D1 DIRECT_SAFE boundary changed.'}
            elseif($class -ceq 'VERIFIED_SHORT_ALIAS_REQUIRED'){Require ($effective -ge 200 -and $effective -lt 230) 'O3F15L4D1 alias-required boundary changed.'}
            else{Require ($effective -ge 230) 'O3F15L4D1 hard-stop boundary changed.'}
            if ($class -cne 'DIRECT_SAFE') {
                $alias=[string](Required-Property $row 'aliasPath')
                $aliasRaw=[int](Required-Property $row 'aliasPlannedRawLength'); $aliasEffective=[int](Required-Property $row 'aliasPlannedEffectiveLength'); $aliasComponent=[int](Required-Property $row 'aliasPlannedMaximumComponentLength')
                $aliasComponents=@($alias -split '[\\/]' | Where-Object { -not [string]::IsNullOrEmpty($_) })
                $computedAliasMaximum=0;foreach($component in $aliasComponents){if($component.Length -gt $computedAliasMaximum){$computedAliasMaximum=$component.Length}}
                $aliasPattern='^[Qq]:[\\/]'+$expectedDirectory+'[\\/]resizedImage[\\/][^\\/]+$'
                Require (-not [string]::IsNullOrWhiteSpace($alias) -and $alias -cmatch $aliasPattern -and $aliasRaw -eq $alias.Length -and $aliasEffective -eq ($alias.Length + 32) -and $aliasEffective -lt 200 -and $aliasComponent -eq $computedAliasMaximum -and $aliasComponent -le 80) 'O3F15L4D1 alias metrics or suffix binding changed.'
            }
            $classKeys.Add("$identity|$channel")
        }
        $expectedClassHash = [string](Required-Property (Required-Property $Classification 'classificationLeafIdentitySha256') $class)
        Assert-Hex256 $expectedClassHash "classificationLeafIdentitySha256.$class"
        Require ((Sha-Text (([string]::Join("`n", $classKeys.ToArray())) + $(if ($classKeys.Count -gt 0) {"`n"} else {''}))) -ceq $expectedClassHash) "O3F15L4D1 class identity hash changed: $class"
    }
    Require ($pairTotal -eq 978 -and $leafTotal -eq 1956 -and $keys.Count -eq 1956 -and $identityByOrdinal.Count -eq 978 -and $uniqueIdentities.Count -eq 978) 'O3F15L4D1 classification totals changed.'
    $computedPairCounts=@{DIRECT_SAFE=0;VERIFIED_SHORT_ALIAS_REQUIRED=0;DIRECT_USE_HARD_STOP_ALIAS_ONLY=0}
    foreach($ordinal in 1..978){$computedPairCounts[[string]$classByOrdinal[$ordinal]]=[int]$computedPairCounts[[string]$classByOrdinal[$ordinal]]+1}
    foreach($class in $classes){Require ([int](Required-Property $pairCounts $class) -eq [int]$computedPairCounts[$class] -and [int](Required-Property $leafCounts $class) -eq [int]$computedLeafCounts[$class]) "O3F15L4D1 reconstructed counts changed: $class"}
    $orderedIdentities = New-Object Collections.Generic.List[string]
    foreach ($ordinal in 1..978) { Require ($identityByOrdinal.ContainsKey($ordinal) -and $channelsByOrdinal[$ordinal].SetEquals(@('BF','DF'))) "O3F15L4D1 identity/channel coverage changed: $ordinal"; $orderedIdentities.Add([string]$identityByOrdinal[$ordinal]) }
    $orderedHash=[string](Required-Property $Classification 'orderedIdentitySha256'); Assert-Hex256 $orderedHash 'orderedIdentitySha256'
    Require ((Sha-Text (([string]::Join("`n", $orderedIdentities.ToArray())) + "`n")) -ceq $orderedHash) 'O3F15L4D1 ordered identity hash changed.'
    foreach ($name in @('orderedClassificationRecordSha256','orderedSourceLeafRecordSha256')) { Assert-Hex256 ([string](Required-Property $Classification $name)) $name }
    $hardStops=@((Required-Property $Classification 'hardStopIdentities'))
    $computedHardOrdinals=@(1..978 | Where-Object {[string]$classByOrdinal[$_] -ceq 'DIRECT_USE_HARD_STOP_ALIAS_ONLY'})
    Require ($hardStops.Count -eq $computedHardOrdinals.Count) 'O3F15L4D1 hard-stop list cardinality changed.'
    for($i=0;$i -lt $hardStops.Count;$i++){$row=$hardStops[$i];$ordinal=$computedHardOrdinals[$i];$computedChannels=@();foreach($channel in @('BF','DF')){if($keys.Contains("$ordinal|$($identityByOrdinal[$ordinal])|$channel") -and @($lists.DIRECT_USE_HARD_STOP_ALIAS_ONLY|Where-Object{[int]$_.ordinal -eq $ordinal -and [string]$_.channel -ceq $channel}).Count -eq 1){$computedChannels+=$channel}};Require ((@($row.PSObject.Properties|ForEach-Object{$_.Name}|Sort-Object)-join '|') -ceq 'channels|identity|ordinal' -and [int]$row.ordinal -eq $ordinal -and [string]$row.identity -ceq [string]$identityByOrdinal[$ordinal] -and ((@($row.channels)-join '|') -ceq ($computedChannels-join '|'))) 'O3F15L4D1 hard-stop identity list changed.'}
    $producerBytes=[int](Required-Property $Classification 'serializedCoreBytes')
    Require ($producerBytes -ge 1 -and $producerBytes -le $MaximumBytes -and [int](Required-Property $Classification 'serializedEvidenceLimitBytes') -eq $MaximumBytes) 'O3F15L4D1 producer compact classification bound changed.'
    $json = $Classification | ConvertTo-Json -Depth 32 -Compress
    [ordered]@{ projectionJson=$json; powershellProjectionSha256=Sha-Text $json; powershellProjectionBytes=[Text.Encoding]::UTF8.GetByteCount($json); producerCompactCoreBytes=[int]$Classification.serializedCoreBytes; identityCount=978; sourceLeafCount=1956 }
}
function Write-Envelope([object]$Value, [int]$MaximumBytes) {
    $json = $Value | ConvertTo-Json -Depth 32 -Compress
    Require ([Text.Encoding]::UTF8.GetByteCount($json) -le $MaximumBytes) 'O3F15L4D1 emitted JSON exceeds its frozen bound.'
    $json
}

function Invoke-O3F15L4D1Main {
    Require (-not ($PackageLeafPreflight -and ($Preflight -or $Rehearsal -or -not [string]::IsNullOrWhiteSpace($InvocationManifest)))) 'O3F15L4D1 package-leaf preflight cannot be combined.'
    Require ($Rehearsal -or [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3F15L4D1 invocation manifest is rehearsal-only.'
    $contractPath = Join-Path $PSScriptRoot 'O3F15L4D1_DIAGNOSTIC_CONTRACT.json'
    Require (Test-Path -LiteralPath $contractPath -PathType Leaf) 'O3F15L4D1 diagnostic contract is absent.'
    $contract = Get-Content -LiteralPath $contractPath -Raw | ConvertFrom-Json
    Assert-FrozenContract $contract
    $payload = @(Assert-Payload $contract)
    if ($PackageLeafPreflight) {
        Write-Envelope ([ordered]@{schema='argos_ocv03_o3f15l4d1_package_leaf_preflight_v1';state='PASS_O3F15L4D1_EXACT_PACKAGED_DIAGNOSTIC_LEAVES';payloadPinCount=$payload.Count;maximumOwnedChildCount=1;detectorResultRootCreated=$false;imageBytesRead=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}) ([int]$contract.maximumEmittedJsonBytes)
        return
    }
    $fixtureMode = ''
    if ($Rehearsal) {
        Require (-not [string]::IsNullOrWhiteSpace($InvocationManifest)) 'O3F15L4D1 rehearsal requires an invocation manifest.'
        $invocation = Get-Content -LiteralPath ([IO.Path]::GetFullPath($InvocationManifest)) -Raw | ConvertFrom-Json
        Require ([string]$invocation.schema -ceq 'argos_ocv03_o3f15l4d1_rehearsal_invocation_v1') 'O3F15L4D1 rehearsal invocation schema changed.'
        $fixtureMode = [string]$invocation.fixtureMode
        Require ($fixtureMode -in @('PASS','PASS_ONE_ALIAS','PASS_MANY_ALIAS','CLASSIFICATION_OVERSIZE','ZERO_STDERR','NONZERO','MALFORMED','TIMEOUT','OVERSIZE')) 'O3F15L4D1 rehearsal fixture mode changed.'
        $python = [IO.Path]::GetFullPath([string]$invocation.pythonPath)
        Require (Test-Path -LiteralPath $python -PathType Leaf) 'O3F15L4D1 rehearsal Python is absent.'
        Require ((Sha $python) -ceq [string]$invocation.pythonSha256) 'O3F15L4D1 rehearsal Python changed.'
        $runner = Join-Path $PSScriptRoot 'O3F15L4D1DiagnosticFixture.py'
        $timeoutSeconds = [int]$invocation.timeoutSeconds
        Require ($timeoutSeconds -ge 1 -and $timeoutSeconds -le 30) 'O3F15L4D1 rehearsal timeout changed.'
    } else {
        Assert-Target $contract
        $python = [string]$contract.runtimePath
        $runner = Join-Path $PSScriptRoot 'Run-O3F15L4FrontReconcile.py'
        $timeoutSeconds = [int]$contract.preflightTimeoutSeconds
    }
    if ($Preflight) {
        Write-Envelope ([ordered]@{schema='argos_ocv03_o3f15l4d1_target_preflight_v1';state='PASS_O3F15L4D1_TARGET_PREFLIGHT';rehearsal=[bool]$Rehearsal;maximumOwnedChildCount=1;exactStage='PREFLIGHT';detectorResultRootCreated=$false;imageBytesRead=$false;processStarted=$false;mutationsPerformed=$false;reviewOnly=$true}) ([int]$contract.maximumEmittedJsonBytes)
        return
    }
    $child = Invoke-OwnedPreflight $python $runner $PSScriptRoot $timeoutSeconds ([int]$contract.maximumChildOutputBytes) $fixtureMode
    $parsed=$null; $parseError=''; $validationError=''; $validated=$null
    if (-not [bool]$child.outputExceededBound) {
        try { $parsed = ([string]$child.stdout).Trim() | ConvertFrom-Json } catch { $parseError=$_.Exception.Message }
        if ($null -ne $parsed -and [string]::IsNullOrWhiteSpace($parseError)) {
            try {
                Require ($parsed -is [System.Management.Automation.PSCustomObject]) 'Child JSON is not one object.'
                Require ([string](Required-Property $parsed 'schema') -ceq [string]$contract.expectedRunnerSchema -and [string](Required-Property $parsed 'state') -ceq [string]$contract.expectedRunnerState -and -not [bool](Required-Property $parsed 'mutationsPerformed')) 'Runner schema/state/mutation contract changed.'
                Require ([string](Required-Property $parsed 'runnerSha256') -ceq [string]$contract.runnerSha256 -and [string](Required-Property $parsed 'focusedTestSha256') -ceq [string]$contract.focusedTestSha256) 'Runner dependency hashes changed.'
                $cohorts=Required-Property $parsed 'cohortCounts'
                Require ([int](Required-Property $cohorts 'HOLDOUT18') -eq 18 -and [int](Required-Property $cohorts 'CURRENT_TAIL') -eq 247 -and [int](Required-Property $cohorts 'FULL_TAIL') -eq 713 -and [int](Required-Property $cohorts 'FULL978') -eq 978) 'Runner cohort counts changed.'
                $classification=Required-Property $parsed 'actualFrozen978LexicalClassification'
                $validated=Assert-Classification $classification ([int]$contract.maximumClassificationEvidenceBytes)
            } catch { $validationError=$_.Exception.Message }
        }
    }
    $childPassed = -not [bool]$child.timedOut -and -not [bool]$child.outputExceededBound -and [int]$child.exitCode -eq 0 -and [int]$child.stderrBytes -eq 0 -and $null -ne $validated -and [string]::IsNullOrWhiteSpace($parseError) -and [string]::IsNullOrWhiteSpace($validationError)
    if ($childPassed) {
        $envelope=[ordered]@{schema='argos_ocv03_o3f15l4d1_metadata_diagnostic_v1';state='COMPLETE_O3F15L4D1_METADATA_DIAGNOSTIC';childOutcome='PASS';rehearsal=[bool]$Rehearsal;childExecutable=[string]$child.executable;childArguments=@($child.arguments);childExitCode=[int]$child.exitCode;childTimedOut=$false;childStdoutBytes=[int]$child.stdoutBytes;childStderrBytes=[int]$child.stderrBytes;childOutputBytes=[int64]$child.totalOutputBytes;childStdoutSha256=[string]$child.stdoutSha256;childStderrSha256=[string]$child.stderrSha256;runnerSchema=[string]$parsed.schema;runnerState=[string]$parsed.state;runnerSha256=[string]$parsed.runnerSha256;focusedTestSha256=[string]$parsed.focusedTestSha256;cohortCounts=$parsed.cohortCounts;producerCompactClassificationCoreBytes=[int]$validated.producerCompactCoreBytes;powershellClassificationProjectionSha256=[string]$validated.powershellProjectionSha256;powershellClassificationProjectionBytes=[int]$validated.powershellProjectionBytes;actualFrozen978LexicalClassification=$parsed.actualFrozen978LexicalClassification;maximumOwnedChildCount=1;ownedChildCount=1;selfTestStarted=$false;focusedTestStarted=$false;gateStarted=$false;runStarted=$false;qSubstCreated=$false;detectorResultRootCreated=$false;backgroundLaunchStarted=$false;imageBytesRead=$false;sourceMutation=$false;sourceDeletion=$false;existingTaskActionCount=0;existingProcessActionCount=0;providerActivated=$false;selectorThresholdRelaxed=$false;holdsAutomaticallyCleared=$false;mutationsPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    } else {
        $stdoutTail=Get-BoundedTail ([string]$child.stdout) ([int]$contract.maximumFailureTailCharacters) ([int]$contract.maximumFailureTailBytes)
        $stderrTail=Get-BoundedTail ([string]$child.stderr) ([int]$contract.maximumFailureTailCharacters) ([int]$contract.maximumFailureTailBytes)
        $parseTail=Get-BoundedTail $parseError 16384 65536;$validationTail=Get-BoundedTail $validationError 16384 65536
        $envelope=[ordered]@{schema='argos_ocv03_o3f15l4d1_metadata_diagnostic_v1';state='HOLD_O3F15L4D1_METADATA_DIAGNOSTIC';childOutcome='FAIL';rehearsal=[bool]$Rehearsal;childExecutable=[string]$child.executable;childArguments=@($child.arguments);childExitCode=[int]$child.exitCode;childTimedOut=[bool]$child.timedOut;childOutputBytes=[int64]$child.totalOutputBytes;childOutputExceededBound=[bool]$child.outputExceededBound;childStdoutBytes=[int]$child.stdoutBytes;childStdoutSha256=[string]$child.stdoutSha256;childStdoutTail=[string]$stdoutTail.value;childStdoutTailBytes=[int]$stdoutTail.bytes;childStdoutTruncated=[bool]$stdoutTail.truncated;childStderrBytes=[int]$child.stderrBytes;childStderrSha256=[string]$child.stderrSha256;childStderrTail=[string]$stderrTail.value;childStderrTailBytes=[int]$stderrTail.bytes;childStderrTruncated=[bool]$stderrTail.truncated;parseError=[string]$parseTail.value;validationError=[string]$validationTail.value;maximumOwnedChildCount=1;ownedChildCount=1;selfTestStarted=$false;focusedTestStarted=$false;gateStarted=$false;runStarted=$false;qSubstCreated=$false;detectorResultRootCreated=$false;backgroundLaunchStarted=$false;imageBytesRead=$false;sourceMutation=$false;sourceDeletion=$false;existingTaskActionCount=0;existingProcessActionCount=0;providerActivated=$false;selectorThresholdRelaxed=$false;holdsAutomaticallyCleared=$false;mutationsPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}
    }
    Write-Envelope $envelope ([int]$contract.maximumEmittedJsonBytes)
}

try {
    Invoke-O3F15L4D1Main
} catch {
    $detail=Get-BoundedTail ([string]$_.Exception.Message) 16384 65536
    $context=$script:D1ChildContext
    Write-Envelope ([ordered]@{schema='argos_ocv03_o3f15l4d1_metadata_diagnostic_v1';state='HOLD_O3F15L4D1_METADATA_DIAGNOSTIC';childOutcome=$(if($script:D1ChildStarted){'FAIL'}else{'NOT_STARTED'});preChildFailure=(-not $script:D1ChildStarted);failureDetail=[string]$detail.value;failureDetailSha256=Sha-Text ([string]$_.Exception.Message);failureDetailTruncated=[bool]$detail.truncated;childExecutable=$(if($null-ne$context){[string]$context.executable}else{''});childArguments=$(if($null-ne$context){@($context.arguments)}else{@()});maximumOwnedChildCount=1;ownedChildCount=$(if($script:D1ChildStarted){1}else{0});selfTestStarted=$false;focusedTestStarted=$false;gateStarted=$false;runStarted=$false;qSubstCreated=$false;detectorResultRootCreated=$false;backgroundLaunchStarted=$false;imageBytesRead=$false;sourceMutation=$false;sourceDeletion=$false;existingTaskActionCount=0;existingProcessActionCount=0;providerActivated=$false;selectorThresholdRelaxed=$false;holdsAutomaticallyCleared=$false;mutationsPerformed=$false;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false}) 7340032
}
