[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$ConfigPath,
    [switch]$Once,
    [switch]$Preflight,
    [string]$EnvironmentProbeManifest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-MemberValue {
    param([object]$Object,[string]$Name,$Default=$null)
    if(($null -ne $Object) -and ($Object.PSObject.Properties.Name -contains $Name)){return $Object.$Name}
    return $Default
}
function Get-ShortSha256 {
    param([Parameter(Mandatory=$true)][string]$Text,[int]$Length=16)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{
        $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes($Text)
        $hex=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','')
        return $hex.Substring(0,$Length)
    }finally{$sha.Dispose()}
}
function Get-PortalPathBudget {
    param([Parameter(Mandatory=$true)][string]$Path,[ValidateRange(0,128)][int]$ReservedSuffixCharacters=32)
    $full=[IO.Path]::GetFullPath($Path)
    $components=@($full.Split(@([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar),[StringSplitOptions]::RemoveEmptyEntries))
    $maximumComponent=if($components.Count-gt0){[int](($components|Measure-Object Length -Maximum).Maximum)}else{0}
    $effective=$full.Length+$ReservedSuffixCharacters
    $state=if($effective-ge230-or$maximumComponent-gt80){'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH'}elseif($effective-ge200){'SHORT_ALIAS_REQUIRED_BEFORE_WRITE_OR_LAUNCH'}else{'PASS_PATH_BUDGET'}
    [pscustomobject]@{path=$full;pathLength=$full.Length;reservedSuffixCharacters=$ReservedSuffixCharacters;effectiveLength=$effective;longestComponentLength=$maximumComponent;state=$state}
}
function Assert-PortalPathBudget {
    param([Parameter(Mandatory=$true)][string]$Path,[ValidateRange(0,128)][int]$ReservedSuffixCharacters=32)
    $row=Get-PortalPathBudget -Path $Path -ReservedSuffixCharacters $ReservedSuffixCharacters
    if([string]$row.state-ne'PASS_PATH_BUDGET'){throw "Portal path budget failed: $($row.state) | effective=$($row.effectiveLength) | component=$($row.longestComponentLength) | $($row.path)"}
    return $row
}
function Get-EffectiveDataRoot {
    param([Parameter(Mandatory=$true)][object]$Mapping)
    $canonical=[IO.Path]::GetFullPath([string]$Mapping.path).TrimEnd('\')
    $aliasConfigPath=Join-Path (Split-Path -Parent $script:configPath) 'endpoint_path_aliases.json'
    if(-not(Test-Path -LiteralPath $aliasConfigPath -PathType Leaf)){return $canonical}
    $aliasConfig=Get-Content -LiteralPath $aliasConfigPath -Raw|ConvertFrom-Json
    if(([string]$aliasConfig.schema-ne'argos_project_portal_endpoint_path_aliases_v1')-or([string]$aliasConfig.role-ne[string]$script:config.role)-or(-not[bool]$aliasConfig.reviewOnly)-or[bool]$aliasConfig.productionRoutingEnabled){throw 'Endpoint path-alias safety contract failed.'}
    $record=@($aliasConfig.aliases|Where-Object{[string]$_.approvedRoot-eq[string]$Mapping.name})|Select-Object -First 1
    if($null-eq$record){return $canonical}
    $target=[IO.Path]::GetFullPath([string]$record.targetPath).TrimEnd('\')
    if(-not$target.Equals($canonical,[StringComparison]::OrdinalIgnoreCase)){throw "Endpoint alias target contract mismatch: $($Mapping.name)"}
    $alias=[IO.Path]::GetFullPath([string]$record.aliasPath).TrimEnd('\')
    if(-not(Test-Path -LiteralPath $alias -PathType Container)){throw "Endpoint data-root alias is absent: $alias"}
    $item=Get-Item -LiteralPath $alias -Force
    if([string]$item.LinkType-ne'Junction'){throw "Endpoint data-root alias is not a junction: $alias"}
    $actualTargets=@($item.Target|ForEach-Object{[IO.Path]::GetFullPath([string]$_).TrimEnd('\')})
    if($actualTargets.Count-ne1-or-not$actualTargets[0].Equals($canonical,[StringComparison]::OrdinalIgnoreCase)){throw "Endpoint data-root junction target mismatch: $alias"}
    return $alias
}
function Write-NewUtf8Json {
    param([string]$Path,$Value)
    if(Test-Path -LiteralPath $Path){throw "Refusing overwrite: $Path"}
    $parent=Split-Path -Parent $Path
    if(-not (Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent)}
    [IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 40),(New-Object Text.UTF8Encoding($false)))
}
function Write-Status {
    param([string]$State,[string]$Detail)
    $record=[ordered]@{schema='argos_project_portal_endpoint_status_v1';updatedUtc=(Get-Date).ToUniversalTime().ToString('o');role=[string]$script:config.role;state=$State;detail=$Detail;reviewOnly=$true;productionRoutingEnabled=$false}
    $path=Join-Path ([string]$script:config.stateRoot) 'STATUS.json'
    $temp=$path+'.partial.'+[Guid]::NewGuid().ToString('N')
    [IO.File]::WriteAllText($temp,($record|ConvertTo-Json -Depth 12),(New-Object Text.UTF8Encoding($false)))
    if(Test-Path -LiteralPath $path){
        $history=Join-Path ([string]$script:config.stateRoot) 'status_history'
        if(-not (Test-Path -LiteralPath $history)){[void](New-Item -ItemType Directory -Path $history)}
        $backup=Join-Path $history ('STATUS_'+(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')+'_'+[Guid]::NewGuid().ToString('N')+'.json')
        [IO.File]::Replace($temp,$path,$backup)
    }else{[IO.File]::Move($temp,$path)}
}
function Get-SafeChildPath {
    param([string]$Root,[string]$Relative)
    if([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)){throw "Unsafe relative path: $Relative"}
    $normalized=$Relative.Replace('/','\')
    if($normalized -match '(^|\\)\.\.(\\|$)'){throw "Parent traversal is forbidden: $Relative"}
    $rootFull=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $full=[IO.Path]::GetFullPath((Join-Path $Root $normalized))
    if(-not $full.StartsWith($rootFull,[StringComparison]::OrdinalIgnoreCase)){throw "Path escapes root: $Relative"}
    return $full
}
function Test-ApprovedDestination {
    param([string]$Path)
    $full=[IO.Path]::GetFullPath($Path)
    $lower=('\'+$full.Trim('\')+'\').ToLowerInvariant()
    foreach($forbidden in @('\secrets\','\credentials\','\argosauto\outbox\','\shermandata\')){
        if($lower.Contains($forbidden)){return $false}
    }
    foreach($root in @($script:config.approvedMaintenanceRoots)){
        $prefix=[IO.Path]::GetFullPath([string]$root).TrimEnd('\')+'\'
        if($full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){return $true}
    }
    return $false
}
function Invoke-CapturedPowerShell {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments,
        [string]$Stdout,
        [string]$Stderr,
        [ValidateRange(30,3600)][int]$TimeoutSeconds=900
    )
    function ConvertTo-ProcessArgument {
        param([AllowEmptyString()][string]$Value)
        if($Value -notmatch '[\s"]'){return $Value}
        $builder=New-Object Text.StringBuilder
        [void]$builder.Append('"')
        $slashes=0
        foreach($character in $Value.ToCharArray()){
            if($character -eq '\'){$slashes++;continue}
            if($character -eq '"'){
                [void]$builder.Append(('\' * (($slashes*2)+1)))
                [void]$builder.Append('"')
                $slashes=0
                continue
            }
            if($slashes-gt0){[void]$builder.Append(('\' * $slashes));$slashes=0}
            [void]$builder.Append($character)
        }
        if($slashes-gt0){[void]$builder.Append(('\' * ($slashes*2)))}
        [void]$builder.Append('"')
        return $builder.ToString()
    }
    $exe="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $list=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$ScriptPath)+@($Arguments)
    $startInfo=New-Object Diagnostics.ProcessStartInfo
    $startInfo.FileName=$exe
    $startInfo.Arguments=(@($list|ForEach-Object{ConvertTo-ProcessArgument ([string]$_)}) -join ' ')
    $startInfo.UseShellExecute=$false
    $startInfo.CreateNoWindow=$true
    $startInfo.RedirectStandardOutput=$true
    $startInfo.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process
    $process.StartInfo=$startInfo
    if(-not $process.Start()){throw "Portal child did not start: $ScriptPath"}
    $stdoutTask=$process.StandardOutput.ReadToEndAsync()
    $stderrTask=$process.StandardError.ReadToEndAsync()
    if(-not $process.WaitForExit($TimeoutSeconds*1000)){
        try{$process.Kill()}catch{}
        [void]$process.WaitForExit(5000)
        [IO.File]::WriteAllText($Stdout,[string]$stdoutTask.Result,(New-Object Text.UTF8Encoding($false)))
        [IO.File]::WriteAllText($Stderr,[string]$stderrTask.Result,(New-Object Text.UTF8Encoding($false)))
        throw "Portal child timed out after $TimeoutSeconds seconds: $ScriptPath"
    }
    $process.WaitForExit()
    [IO.File]::WriteAllText($Stdout,[string]$stdoutTask.Result,(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText($Stderr,[string]$stderrTask.Result,(New-Object Text.UTF8Encoding($false)))
    return $process.ExitCode
}
function Get-EnvironmentInventory {
    param([object]$Parameters)
    $request=Get-MemberValue $Parameters 'environmentInventory' $null
    if($null-eq$request-or-not[bool](Get-MemberValue $request 'enabled' $false)){return $null}
    $approvedRootName=[string](Get-MemberValue $request 'approvedDataRoot' '')
    $mapping=@($script:config.approvedDataRoots|Where-Object{[string]$_.name-eq$approvedRootName})|Select-Object -First 1
    if($null-eq$mapping){throw "Environment inventory approved data root is not configured: $approvedRootName"}
    $configuredRoot=[IO.Path]::GetFullPath([string]$mapping.path).TrimEnd('\')
    $volumeRoot=[IO.Path]::GetPathRoot($configuredRoot)
    if([string]::IsNullOrWhiteSpace($volumeRoot)){throw 'Environment inventory could not resolve the configured volume root.'}
    $drive=New-Object IO.DriveInfo($volumeRoot)
    if(-not$drive.IsReady){throw "Environment inventory volume is not ready: $volumeRoot"}

    $childNames=@(Get-MemberValue $request 'volumeRootChildNames' @())
    $relativeLeafPaths=@(Get-MemberValue $request 'approvedRootRelativeLeafPaths' @())
    if($childNames.Count-gt4){throw 'Environment inventory volume-root child count exceeds four.'}
    if($relativeLeafPaths.Count-gt8){throw 'Environment inventory exact-relative-leaf count exceeds eight.'}
    if($childNames.Count-eq0-and$relativeLeafPaths.Count-eq0){throw 'Environment inventory requires at least one bounded metadata selector.'}
    $seenChildren=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $children=@()
    foreach($value in $childNames){
        $name=[string]$value
        if($name-notmatch'^[A-Za-z][A-Za-z0-9_-]{0,31}$'){throw "Environment inventory child name is unsafe: $name"}
        if(-not$seenChildren.Add($name)){throw "Environment inventory child name is duplicated: $name"}
        $path=[IO.Path]::GetFullPath((Join-Path $volumeRoot $name))
        $prefix=[IO.Path]::GetFullPath($volumeRoot).TrimEnd('\')+'\'
        if(-not$path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw "Environment inventory child escaped the configured volume: $name"}
        $isContainer=Test-Path -LiteralPath $path -PathType Container
        $isLeaf=Test-Path -LiteralPath $path -PathType Leaf
        $exists=$isContainer-or$isLeaf
        $attributes=$null
        $reparse=$false
        if($exists){
            $item=Get-Item -LiteralPath $path -Force
            $attributes=[string]$item.Attributes
            $reparse=($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0
        }
        $children+=[pscustomobject]@{name=$name;path=$path;exists=$exists;pathType=if($isContainer){'CONTAINER'}elseif($isLeaf){'LEAF'}else{'ABSENT'};attributes=$attributes;reparsePoint=$reparse;enumerated=$false}
    }

    $leafRows=@()
    $aliasName=[string](Get-MemberValue $request 'processLocalAliasName' '')
    $aliasCreated=$false
    $aliasRemoved=$false
    if($relativeLeafPaths.Count-gt0){
        if($aliasName-ne'F'){throw 'Environment inventory exact-relative-leaf metadata requires fixed process-local alias F.'}
        $seenRelative=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $plans=@()
        foreach($value in $relativeLeafPaths){
            $relative=([string]$value).Replace('/','\').TrimStart('\')
            if([string]::IsNullOrWhiteSpace($relative)-or[IO.Path]::IsPathRooted($relative)-or$relative-match'(^|\\)\.\.?($|\\)' -or $relative.IndexOfAny([char[]]'*?[]')-ge0){throw "Environment inventory relative leaf is unsafe: $value"}
            if(-not$seenRelative.Add($relative)){throw "Environment inventory relative leaf is duplicated: $relative"}
            $canonical=Get-SafeChildPath -Root $configuredRoot -Relative $relative
            $canonicalBudget=Get-PortalPathBudget -Path $canonical -ReservedSuffixCharacters 32
            if([string]$canonicalBudget.state-eq'HARD_STOP_SHORTEN_BEFORE_WRITE_OR_LAUNCH'){throw "Environment inventory canonical path is a hard stop: $canonical"}
            $aliasPath=$aliasName+':\'+$relative
            $aliasBudget=Get-PortalPathBudget -Path $aliasPath -ReservedSuffixCharacters 32
            if([string]$aliasBudget.state-ne'PASS_PATH_BUDGET'){throw "Environment inventory alias path budget failed: $aliasPath"}
            $plans+=[pscustomobject]@{relativePath=$relative;normalizedFullPath=$canonical;aliasReadPath=$aliasPath;canonicalEffectiveLength=[int]$canonicalBudget.effectiveLength;aliasEffectiveLength=[int]$aliasBudget.effectiveLength;longestComponentLength=[int]$aliasBudget.longestComponentLength}
        }
        if($Preflight){
            foreach($plan in $plans){
                $leafRows+=[pscustomobject]@{relativePath=$plan.relativePath;normalizedFullPath=$plan.normalizedFullPath;aliasReadPath=$plan.aliasReadPath;containedByApprovedRoot=$true;exists=$null;pathType='UNOBSERVED_PREFLIGHT';attributes=$null;reparsePoint=$null;ancestorReparsePoint=$null;firstReparseAncestor=$null;length=$null;lastWriteTimeUtc=$null;canonicalEffectiveLength=$plan.canonicalEffectiveLength;aliasEffectiveLength=$plan.aliasEffectiveLength;longestComponentLength=$plan.longestComponentLength;enumerated=$false;filesRead=$false;imageBytesRead=$false;mutationsPerformed=$false}
            }
        }else{
            if(Get-PSDrive -Name $aliasName -ErrorAction SilentlyContinue){throw "Environment inventory process-local alias is already in use: $aliasName"}
            try{
                [void](New-PSDrive -Name $aliasName -PSProvider FileSystem -Root $configuredRoot -Scope Script -ErrorAction Stop)
                $aliasCreated=$true
                $driveRecord=Get-PSDrive -Name $aliasName -ErrorAction Stop
                if(-not([IO.Path]::GetFullPath([string]$driveRecord.Root).TrimEnd('\')).Equals($configuredRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Environment inventory process-local alias root mismatch.'}
                foreach($plan in $plans){
                    $segments=@($plan.relativePath.Split('\')|Where-Object{-not[string]::IsNullOrWhiteSpace($_)})
                    $current=$aliasName+':'
                    $finalItem=$null
                    $firstReparse=$null
                    $missing=$false
                    foreach($segment in $segments){
                        $current=$current+'\'+$segment
                        if(-not(Test-Path -LiteralPath $current)){$missing=$true;break}
                        $currentItem=Get-Item -LiteralPath $current -Force -ErrorAction Stop
                        if(($currentItem.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){$firstReparse=$current;break}
                        $finalItem=$currentItem
                    }
                    $ancestorReparse=($null-ne$firstReparse-and-not$firstReparse.Equals([string]$plan.aliasReadPath,[StringComparison]::OrdinalIgnoreCase))
                    $isFinal=($null-ne$finalItem-and-not$missing-and$null-eq$firstReparse-and$current.Equals([string]$plan.aliasReadPath,[StringComparison]::OrdinalIgnoreCase))
                    $exists=($isFinal-or($null-ne$firstReparse-and-not$ancestorReparse))
                    $pathType=if($ancestorReparse){'UNRESOLVED_REPARSE_ANCESTOR'}elseif($missing){'ABSENT'}elseif($isFinal-and[bool]$finalItem.PSIsContainer){'CONTAINER'}elseif($isFinal){'LEAF'}elseif($null-ne$firstReparse){'REPARSE_POINT'}else{'ABSENT'}
                    $leafRows+=[pscustomobject]@{relativePath=$plan.relativePath;normalizedFullPath=$plan.normalizedFullPath;aliasReadPath=$plan.aliasReadPath;containedByApprovedRoot=$true;exists=$exists;pathType=$pathType;attributes=if($isFinal){[string]$finalItem.Attributes}elseif($null-ne$firstReparse){[string](Get-Item -LiteralPath $firstReparse -Force).Attributes}else{$null};reparsePoint=($null-ne$firstReparse-and-not$ancestorReparse);ancestorReparsePoint=$ancestorReparse;firstReparseAncestor=$firstReparse;length=if($isFinal-and-not[bool]$finalItem.PSIsContainer){[int64]$finalItem.Length}else{$null};lastWriteTimeUtc=if($isFinal){$finalItem.LastWriteTimeUtc.ToString('o')}else{$null};canonicalEffectiveLength=$plan.canonicalEffectiveLength;aliasEffectiveLength=$plan.aliasEffectiveLength;longestComponentLength=$plan.longestComponentLength;enumerated=$false;filesRead=$false;imageBytesRead=$false;mutationsPerformed=$false}
                }
            }finally{
                if($aliasCreated){Remove-PSDrive -Name $aliasName -Scope Script -Force -ErrorAction Stop;$aliasRemoved=-not[bool](Get-PSDrive -Name $aliasName -ErrorAction SilentlyContinue)}
            }
            if(-not$aliasRemoved){throw 'Environment inventory process-local alias was not removed.'}
        }
    }

    $commandNames=@(Get-MemberValue $request 'commandNames' @())
    if($commandNames.Count-gt2){throw 'Environment inventory command-name count exceeds two.'}
    $allowedCommands=@('python.exe','py.exe')
    $seenCommandNames=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $seenCommandPaths=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $commands=@()
    foreach($value in $commandNames){
        $name=[string]$value
        if($allowedCommands-notcontains$name){throw "Environment inventory command name is not allowed: $name"}
        if(-not$seenCommandNames.Add($name)){throw "Environment inventory command name is duplicated: $name"}
        $matches=@(Get-Command -Name $name -CommandType Application -ErrorAction SilentlyContinue|Select-Object -First 4)
        foreach($match in $matches){
            $path=[string](Get-MemberValue $match 'Source' (Get-MemberValue $match 'Path' ''))
            if([string]::IsNullOrWhiteSpace($path)){continue}
            $full=[IO.Path]::GetFullPath($path)
            if(-not$seenCommandPaths.Add($full)){continue}
            $version=$null
            try{$version=[string](Get-Item -LiteralPath $full).VersionInfo.FileVersion}catch{}
            $commands+=[pscustomobject]@{name=$name;path=$full;fileVersion=$version}
        }
    }

    return [ordered]@{
        schema='argos_project_portal_environment_inventory_v2'
        createdUtc=(Get-Date).ToUniversalTime().ToString('o')
        approvedDataRoot=$approvedRootName
        configuredRoot=$configuredRoot
        volume=[ordered]@{name=[string]$drive.Name;driveType=[string]$drive.DriveType;driveFormat=[string]$drive.DriveFormat;isReady=[bool]$drive.IsReady;totalBytes=[int64]$drive.TotalSize;availableFreeBytes=[int64]$drive.AvailableFreeSpace}
        children=$children
        exactRelativeLeaves=$leafRows
        processLocalAlias=[ordered]@{name=$aliasName;created=$aliasCreated;removed=$aliasRemoved;persistent=$false}
        host=[ordered]@{machineName=[Environment]::MachineName;osVersion=[Environment]::OSVersion.VersionString;is64BitOperatingSystem=[Environment]::Is64BitOperatingSystem;is64BitProcess=[Environment]::Is64BitProcess;processorArchitecture=[string]$env:PROCESSOR_ARCHITECTURE;powerShellVersion=[string]$PSVersionTable.PSVersion}
        commands=$commands
        pathsEnumerated=$false
        filesRead=$false
        imageBytesRead=$false
        mutationsPerformed=$false
        reviewOnly=$true
        productionRoutingEnabled=$false
    }
}
function Invoke-StatusHandler {
    param([object]$Manifest,[string]$ResultRoot)
    $tasks=@()
    foreach($name in @(Get-MemberValue (Get-MemberValue $script:config 'status') 'tasks' @())){
        $task=Get-ScheduledTask -TaskName ([string]$name) -ErrorAction SilentlyContinue
        $tasks+=[pscustomobject]@{name=[string]$name;state=if($task){[string]$task.State}else{'NOT_FOUND'}}
    }
    $hashes=@()
    foreach($path in @(Get-MemberValue (Get-MemberValue $script:config 'status') 'hashFiles' @())){
        $hashes+=[pscustomobject]@{path=[string]$path;exists=(Test-Path -LiteralPath ([string]$path) -PathType Leaf);sha256=if(Test-Path -LiteralPath ([string]$path) -PathType Leaf){(Get-FileHash -LiteralPath ([string]$path) -Algorithm SHA256).Hash}else{$null};bytes=if(Test-Path -LiteralPath ([string]$path) -PathType Leaf){(Get-Item -LiteralPath ([string]$path)).Length}else{$null}}
    }
    $jsonStates=@()
    foreach($path in @(Get-MemberValue (Get-MemberValue $script:config 'status') 'jsonFiles' @())){
        $entry=[ordered]@{path=[string]$path;exists=(Test-Path -LiteralPath ([string]$path) -PathType Leaf);value=$null;readError=$null}
        if($entry.exists){try{$entry.value=Get-Content -LiteralPath ([string]$path) -Raw|ConvertFrom-Json}catch{$entry.readError=$_.Exception.Message}}
        $jsonStates+=[pscustomobject]$entry
    }
    $logs=@()
    foreach($path in @(Get-MemberValue (Get-MemberValue $script:config 'status') 'logs' @())){
        $logs+=[pscustomobject]@{path=[string]$path;tail=if(Test-Path -LiteralPath ([string]$path) -PathType Leaf){@(Get-Content -LiteralPath ([string]$path) -Tail 20)}else{@()}}
    }
    $parameters=Get-MemberValue $Manifest 'parameters' $null
    $environmentInventory=Get-EnvironmentInventory -Parameters $parameters
    Write-NewUtf8Json -Path (Join-Path $ResultRoot 'RESULT.json') -Value ([ordered]@{schema='argos_project_portal_status_result_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');role=[string]$script:config.role;state='PASS_STATUS_COLLECTED';tasks=$tasks;installedHashes=$hashes;jsonStates=$jsonStates;logs=$logs;environmentInventory=$environmentInventory;reviewOnly=$true;productionRoutingEnabled=$false})
    return 'PASS_STATUS_COLLECTED'
}
function Invoke-DataPullHandler {
    param([object]$Manifest,[string]$ResultRoot)
    $parameters=Get-MemberValue $Manifest 'parameters'
    $rootName=[string](Get-MemberValue $parameters 'approvedRoot')
    $mapping=@($script:config.approvedDataRoots|Where-Object{[string]$_.name -eq $rootName})|Select-Object -First 1
    if($null -eq $mapping){throw "DATA_PULL approved root is not configured: $rootName"}
    $relativePaths=@(Get-MemberValue $parameters 'relativePaths' @())
    $maximumFiles=[int](Get-MemberValue $parameters 'maximumFiles' 0)
    $maximumBytes=[int64](Get-MemberValue $parameters 'maximumBytes' 0)
    if(($relativePaths.Count -lt 1) -or ($relativePaths.Count -gt $maximumFiles) -or ($maximumFiles -gt 128)){throw 'DATA_PULL file count contract failed.'}
    if(($maximumBytes -lt 1) -or ($maximumBytes -gt [int64]$Manifest.maxResultBytes)){throw 'DATA_PULL byte limit contract failed.'}
    $effectiveRoot=Get-EffectiveDataRoot -Mapping $mapping
    $planned=New-Object Collections.Generic.List[object]
    $total=[int64]0
    $entryNames=@{}
    foreach($relativeValue in $relativePaths){
        $relative=([string]$relativeValue).Replace('\','/').TrimStart('/')
        $source=Get-SafeChildPath -Root $effectiveRoot -Relative $relative
        [void](Assert-PortalPathBudget -Path $source -ReservedSuffixCharacters 32)
        if(-not(Test-Path -LiteralPath $source -PathType Leaf)){throw "DATA_PULL source not found: $relative"}
        $item=Get-Item -LiteralPath $source
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint)-ne0){throw "DATA_PULL reparse source refused: $relative"}
        $total+=[int64]$item.Length
        if($total-gt$maximumBytes){throw 'DATA_PULL exceeded declared maximumBytes.'}
        $entryName=('data/'+$rootName+'/'+$relative).Replace('//','/')
        if($entryNames.ContainsKey($entryName)){throw "DATA_PULL duplicate return entry: $entryName"}
        $entryNames[$entryName]=$true
        $planned.Add([pscustomobject]@{relativePath=$relative;entryPath=$entryName;source=$source;bytes=[int64]$item.Length;sha256=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash})
    }
    $containerPath=Join-Path $ResultRoot 'DATA_PULL_PAYLOAD.zip'
    $containerPartial=$containerPath+'.partial'
    [void](Assert-PortalPathBudget -Path $containerPartial -ReservedSuffixCharacters 32)
    $stream=[IO.File]::Open($containerPartial,[IO.FileMode]::CreateNew,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
    try{
        $archive=New-Object IO.Compression.ZipArchive($stream,[IO.Compression.ZipArchiveMode]::Create,$true)
        try{
            foreach($row in $planned){
                $entry=$archive.CreateEntry([string]$row.entryPath,[IO.Compression.CompressionLevel]::NoCompression)
                $input=[IO.File]::OpenRead([string]$row.source)
                $output=$entry.Open()
                try{$input.CopyTo($output)}finally{$output.Dispose();$input.Dispose()}
            }
        }finally{$archive.Dispose()}
    }catch{
        $stream.Dispose()
        if(Test-Path -LiteralPath $containerPartial -PathType Leaf){Remove-Item -LiteralPath $containerPartial -Force -ErrorAction SilentlyContinue}
        throw
    }finally{$stream.Dispose()}
    [IO.File]::Move($containerPartial,$containerPath)
    $container=Get-Item -LiteralPath $containerPath
    if($container.Length-gt[int64]$Manifest.maxResultBytes){throw 'DATA_PULL return container exceeded manifest maxResultBytes.'}
    $returned=@($planned|ForEach-Object{[pscustomobject]@{relativePath=$_.relativePath;entryPath=$_.entryPath;bytes=$_.bytes;sha256=$_.sha256}})
    $resultPath=Join-Path $ResultRoot 'RESULT.json'
    [void](Assert-PortalPathBudget -Path $resultPath -ReservedSuffixCharacters 32)
    Write-NewUtf8Json -Path $resultPath -Value ([ordered]@{schema='argos_project_portal_data_pull_result_v2';createdUtc=(Get-Date).ToUniversalTime().ToString('o');state='PASS_DATA_PULL';approvedRoot=$rootName;container='DATA_PULL_PAYLOAD.zip';containerBytes=[int64]$container.Length;containerSha256=(Get-FileHash -LiteralPath $containerPath -Algorithm SHA256).Hash;files=$returned;totalSourceBytes=$total;sourcePathsPreservedAsZipEntries=$true;filesystemReturnPathsFlattened=$true;reviewOnly=$true;productionRoutingEnabled=$false})
    return 'PASS_DATA_PULL'
}
function Invoke-InsiteDiagnosticHandler {
    param([object]$Manifest,[string]$ResultRoot)
    $handlerName=[string]$Manifest.handler
    $handler=@($script:config.handlers|Where-Object{([string]$_.name -eq $handlerName) -and ([string]$_.jobClass -eq 'INSITE_DIAGNOSTIC')})|Select-Object -First 1
    if($null -eq $handler){throw "INSITE diagnostic handler is not installed: $handlerName"}
    $handlerPath=[IO.Path]::GetFullPath([string]$handler.scriptPath)
    if(-not (Test-Path -LiteralPath $handlerPath -PathType Leaf)){throw "INSITE diagnostic handler file is missing: $handlerName"}
    $expectedHandlerHash=([string]$handler.scriptSha256).ToUpperInvariant()
    if($expectedHandlerHash -notmatch '^[A-F0-9]{64}$'){throw "INSITE diagnostic handler hash is not pinned: $handlerName"}
    $actualHandlerHash=(Get-FileHash -LiteralPath $handlerPath -Algorithm SHA256).Hash
    if($actualHandlerHash -ne $expectedHandlerHash){throw "INSITE diagnostic handler hash mismatch: $handlerName"}
    # Arguments are fixed in the installed endpoint configuration. The signed
    # request selects only a named handler and cannot inject script text,
    # parameters, credentials, paths, or shell fragments.
    $handlerArguments=@('-OutputRoot',$ResultRoot)
    foreach($fixed in @(Get-MemberValue -Object $handler -Name 'fixedArguments' -Default @())){$handlerArguments+=[string]$fixed}
    $stdout=Join-Path $ResultRoot 'HANDLER.stdout.txt';$stderr=Join-Path $ResultRoot 'HANDLER.stderr.txt'
    $exit=Invoke-CapturedPowerShell -ScriptPath $handlerPath -Arguments $handlerArguments -Stdout $stdout -Stderr $stderr
    if($exit -ne 0){throw "INSITE diagnostic handler failed with exit code $exit. Exact stderr is attached."}
    Write-NewUtf8Json -Path (Join-Path $ResultRoot 'RESULT.json') -Value ([ordered]@{schema='argos_project_portal_insite_diagnostic_result_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');state='PASS_INSITE_DIAGNOSTIC';handler=$handlerName;handlerSha256=$actualHandlerHash;exitCode=$exit;reviewOnly=$true;credentialsWritten=$false;productionRoutingEnabled=$false})
    return 'PASS_INSITE_DIAGNOSTIC'
}
function Invoke-MaintenanceHandler {
    param([object]$Manifest,[string]$PackagePath,[string]$ResultRoot)
    $changes=@($Manifest.changes);if($changes.Count -lt 1){throw 'Maintenance request contains no changes.'}
    $maintenanceRoot=Join-Path ([string]$script:config.stateRoot) ('maintenance\'+[string]$Manifest.requestId)
    [void](Assert-PortalPathBudget -Path $maintenanceRoot -ReservedSuffixCharacters 32)
    if(Test-Path -LiteralPath $maintenanceRoot){throw 'Maintenance request work root already exists.'}
    $priorRoot=Join-Path $maintenanceRoot 'prior'
    $failedRoot=Join-Path $maintenanceRoot 'failed_new'
    [void](Assert-PortalPathBudget -Path $priorRoot -ReservedSuffixCharacters 32)
    [void](Assert-PortalPathBudget -Path $failedRoot -ReservedSuffixCharacters 32)
    [void](New-Item -ItemType Directory -Path $priorRoot -Force)
    [void](New-Item -ItemType Directory -Path $failedRoot -Force)
    $prepared=@()
    $changeIndex=0
    $requestToken=Get-ShortSha256 -Text ([string]$Manifest.requestId) -Length 10
    foreach($change in $changes){
        $source=Get-SafeChildPath -Root $PackagePath -Relative ([string]$change.source)
        $destination=[IO.Path]::GetFullPath([string]$change.destination)
        if(-not (Test-ApprovedDestination $destination)){throw "Maintenance destination is outside approved roots: $destination"}
        if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw "Maintenance source is missing: $($change.source)"}
        $sourceHash=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash
        if($sourceHash -ne [string]$change.installedSha256){throw "Maintenance source hash mismatch: $($change.source)"}
        $exists=Test-Path -LiteralPath $destination -PathType Leaf
        if($exists){
            $actual=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
            if(@($change.approvedPredecessorSha256) -notcontains $actual){throw "Installed predecessor is not approved: $destination`nActual: $actual"}
        }elseif(-not [bool](Get-MemberValue $change 'allowCreate' $false)){throw "Maintenance destination does not exist and allowCreate is false: $destination"}
        $destinationToken=Get-ShortSha256 -Text $destination -Length 10
        $evidenceToken=('M{0:D3}_{1}_{2}' -f $changeIndex,$destinationToken,$requestToken)
        $prior=Join-Path $priorRoot ($evidenceToken+'.prior')
        $replaceBackup=Join-Path $priorRoot ($evidenceToken+'.atomic')
        $staged=Join-Path (Split-Path -Parent $destination) ('.'+$evidenceToken+'.stage')
        $restore=Join-Path (Split-Path -Parent $destination) ('.'+$evidenceToken+'.restore')
        $failedCurrent=Join-Path $failedRoot ($evidenceToken+'.rollback')
        $failedCreated=Join-Path $failedRoot ($evidenceToken+'.created')
        foreach($plannedPath in @($destination,$prior,$replaceBackup,$staged,$restore,$failedCurrent,$failedCreated)){
            [void](Assert-PortalPathBudget -Path $plannedPath -ReservedSuffixCharacters 32)
        }
        $prepared+=[pscustomobject]@{
            source=$source;destination=$destination;destinationName=[IO.Path]::GetFileName($destination)
            evidenceToken=$evidenceToken;existed=$exists;prior=$prior;replaceBackup=$replaceBackup
            staged=$staged;restore=$restore;failedCurrent=$failedCurrent;failedCreated=$failedCreated
            installedSha256=$sourceHash
        }
        $changeIndex++
    }
    $applied=@()
    try{
        foreach($item in $prepared){
            $parent=Split-Path -Parent $item.destination
            if(-not (Test-Path -LiteralPath $parent)){[void](New-Item -ItemType Directory -Path $parent)}
            if($item.existed){Copy-Item -LiteralPath $item.destination -Destination $item.prior -ErrorAction Stop}
            $staged=$item.staged
            if(Test-Path -LiteralPath $staged){throw "Refusing existing staged path: $staged"}
            Copy-Item -LiteralPath $item.source -Destination $staged -ErrorAction Stop
            if((Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash -ne $item.installedSha256){throw 'Staged maintenance hash mismatch.'}
            if($item.existed){[IO.File]::Replace($staged,$item.destination,$item.replaceBackup)}else{[IO.File]::Move($staged,$item.destination)}
            $applied+=$item
        }
        $stdout=Join-Path $ResultRoot 'MAINTENANCE.stdout.txt';$stderr=Join-Path $ResultRoot 'MAINTENANCE.stderr.txt'
        $entry=Get-SafeChildPath -Root $PackagePath -Relative ([string]$Manifest.entryPoint)
        $exit=Invoke-CapturedPowerShell -ScriptPath $entry -Arguments @() -Stdout $stdout -Stderr $stderr
        if($exit -ne 0){throw "Maintenance verifier failed with exit code $exit. Exact stderr is attached."}
        $required=[string](Get-MemberValue (Get-MemberValue $Manifest 'rehearsal') 'requiredState' '')
        if($required -and (-not (Get-Content -LiteralPath $stdout -Raw).Contains($required))){throw "Maintenance verifier did not emit required state: $required"}
        foreach($item in $prepared){if((Get-FileHash -LiteralPath $item.destination -Algorithm SHA256).Hash -ne $item.installedSha256){throw "Post-maintenance hash mismatch: $($item.destination)"}}
        $changeEvidence=@($prepared|ForEach-Object{[ordered]@{
            destination=$_.destination;destinationName=$_.destinationName;evidenceToken=$_.evidenceToken
            installedSha256=$_.installedSha256;predecessorExisted=[bool]$_.existed
            priorEvidence=$_.prior;atomicReplaceEvidence=$_.replaceBackup
        }})
        Write-NewUtf8Json -Path (Join-Path $ResultRoot 'RESULT.json') -Value ([ordered]@{schema='argos_project_portal_maintenance_result_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');state='PASS_MAINTENANCE_PATCH';changedFiles=$prepared.Count;changes=$changeEvidence;entryPoint=[string]$Manifest.entryPoint;exitCode=$exit;quarantine=$maintenanceRoot;reviewOnly=$true;productionRoutingEnabled=$false})
        return 'PASS_MAINTENANCE_PATCH'
    }catch{
        $rollback=@($applied)
        [Array]::Reverse($rollback)
        foreach($item in $rollback){
            try{
                if($item.existed){
                    $restore=$item.restore
                    Copy-Item -LiteralPath $item.prior -Destination $restore -ErrorAction Stop
                    $failedCurrent=$item.failedCurrent
                    [IO.File]::Replace($restore,$item.destination,$failedCurrent)
                }elseif(Test-Path -LiteralPath $item.destination){
                    $failed=$item.failedCreated
                    Move-Item -LiteralPath $item.destination -Destination $failed -ErrorAction Stop
                }
            }catch{}
        }
        throw
    }
}
function New-SignedResponse {
    param([object]$Request,[string]$ResultRoot,[string]$State,[string]$Detail)
    $created=[DateTimeOffset]::UtcNow
    # Keep package paths short enough for Windows PowerShell 5 and deep approved
    # data-root relative paths. The full request id remains signed in the manifest.
    $responseId='R_'+(Get-ShortSha256 -Text ([string]$Request.requestId) -Length 12)+'_'+$created.ToString('yyyyMMddHHmmssfff')+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $partial=Join-Path ([string]$script:config.responseOutbox) ($responseId+'.partial')
    $ready=Join-Path ([string]$script:config.responseOutbox) ($responseId+'.ready')
    [void](Assert-PortalPathBudget -Path $partial -ReservedSuffixCharacters 32)
    [void](Assert-PortalPathBudget -Path $ready -ReservedSuffixCharacters 32)
    if((Test-Path -LiteralPath $partial) -or (Test-Path -LiteralPath $ready)){throw 'Response package collision.'}
    try{
        [void](New-Item -ItemType Directory -Path $partial)
        foreach($file in @(Get-ChildItem -LiteralPath $ResultRoot -Recurse -File)){
            [void](Assert-PortalPathBudget -Path $file.FullName -ReservedSuffixCharacters 32)
            $relative=$file.FullName.Substring($ResultRoot.TrimEnd('\').Length).TrimStart('\')
            $destination=Get-SafeChildPath -Root $partial -Relative $relative
            [void](Assert-PortalPathBudget -Path $destination -ReservedSuffixCharacters 32)
            $parent=Split-Path -Parent $destination
            [void](New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop)
            if(-not (Test-Path -LiteralPath $parent -PathType Container)){throw "Response destination parent was not created: $parent"}
            Copy-Item -LiteralPath $file.FullName -Destination $destination -ErrorAction Stop
        }
        $records=@(Get-ChildItem -LiteralPath $partial -Recurse -File|Sort-Object FullName|ForEach-Object{
            $relative=$_.FullName.Substring($partial.TrimEnd('\').Length).TrimStart('\').Replace('\','/')
            [ordered]@{path=$relative;bytes=$_.Length;sha256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        })
        $thumbprint=([string]$script:config.endpointSignerThumbprint).Replace(' ','').ToUpperInvariant()
        $manifest=[ordered]@{schema='argos_project_portal_response_manifest_v1';responseId=$responseId;requestId=[string]$Request.requestId;createdUtc=$created.ToString('o');sourceRole=[string]$script:config.role;state=$State;detail=$Detail;reviewOnly=$true;trainingEligible=$false;xmlEligible=$false;productionEligible=$false;productionRoutingEnabled=$false;credentialsIncluded=$false;signerThumbprint=$thumbprint;signatureAlgorithm='RSA-SHA256-PKCS1';files=$records}
        $bytes=(New-Object Text.UTF8Encoding($false)).GetBytes(($manifest|ConvertTo-Json -Depth 32))
        [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.json'),$bytes)
        $location=[string]$script:config.endpointSignerStoreLocation
        $cert=Get-Item -LiteralPath ("Cert:\$location\My\$thumbprint") -ErrorAction Stop
        $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        try{$signature=$rsa.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
        [IO.File]::WriteAllBytes((Join-Path $partial 'PORTAL_RESPONSE_MANIFEST.sig'),$signature)
        Move-Item -LiteralPath $partial -Destination $ready -ErrorAction Stop
        return $ready
    }catch{
        $responseError=$_.Exception
        if(Test-Path -LiteralPath $partial -PathType Container){
            try{
                $quarantineRoot=Join-Path ([string]$script:config.stateRoot) 'response_quarantine'
                if(-not(Test-Path -LiteralPath $quarantineRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $quarantineRoot)}
                $quarantine=Join-Path $quarantineRoot ($responseId+'.partial')
                [void](Assert-PortalPathBudget -Path $quarantine -ReservedSuffixCharacters 32)
                Move-Item -LiteralPath $partial -Destination $quarantine -ErrorAction Stop
            }catch{}
        }
        throw $responseError
    }
}
function Get-ResponseSearchRoots {
    $outbox=[IO.Path]::GetFullPath([string]$script:config.responseOutbox).TrimEnd('\')
    $roots=@($outbox)
    if((Split-Path -Leaf $outbox)-eq'pending'){
        $sent=Join-Path (Split-Path -Parent $outbox) 'sent'
        [void](Assert-PortalPathBudget -Path $sent -ReservedSuffixCharacters 32)
        if(Test-Path -LiteralPath $sent -PathType Container){$roots+=[IO.Path]::GetFullPath($sent).TrimEnd('\')}
    }
    return @($roots|Select-Object -Unique)
}
function Read-VerifiedReadyResponse {
    param([Parameter(Mandatory=$true)][IO.DirectoryInfo]$Candidate,[Parameter(Mandatory=$true)][string]$RequestId)
    $manifestPath=Join-Path $Candidate.FullName 'PORTAL_RESPONSE_MANIFEST.json'
    $signaturePath=Join-Path $Candidate.FullName 'PORTAL_RESPONSE_MANIFEST.sig'
    if(-not(Test-Path -LiteralPath $manifestPath -PathType Leaf)-or-not(Test-Path -LiteralPath $signaturePath -PathType Leaf)){return $null}
    try{
        $manifestBytes=[IO.File]::ReadAllBytes($manifestPath);$signature=[IO.File]::ReadAllBytes($signaturePath)
        $thumbprint=([string]$script:config.endpointSignerThumbprint).Replace(' ','').ToUpperInvariant();$location=[string]$script:config.endpointSignerStoreLocation
        $cert=Get-Item -LiteralPath ("Cert:\$location\My\$thumbprint") -ErrorAction Stop
        $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
        try{$valid=$rsa.VerifyData($manifestBytes,$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}finally{$rsa.Dispose()}
        if(-not$valid){return $null}
        $responseManifest=[Text.Encoding]::UTF8.GetString($manifestBytes)|ConvertFrom-Json
        if([string]$responseManifest.requestId-ne$RequestId-or[string]$responseManifest.sourceRole-ne[string]$script:config.role-or-not[bool]$responseManifest.reviewOnly-or[bool]$responseManifest.productionRoutingEnabled){return $null}
        foreach($file in @($responseManifest.files)){
            $path=Get-SafeChildPath -Root $Candidate.FullName -Relative ([string]$file.path)
            if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return $null}
            if((Get-Item -LiteralPath $path).Length-ne[int64]$file.bytes-or(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash-ne[string]$file.sha256){return $null}
        }
        return $responseManifest
    }catch{return $null}
}
function Find-ReadyResponseForRequest {
    param([Parameter(Mandatory=$true)][string]$RequestId)
    $candidates=@()
    foreach($root in @(Get-ResponseSearchRoots)){
        $candidates+=@(Get-ChildItem -LiteralPath $root -Directory -Filter '*.ready' -ErrorAction SilentlyContinue|ForEach-Object{[pscustomobject]@{root=$root;directory=$_}})
    }
    foreach($record in @($candidates|Sort-Object {$_.directory.CreationTimeUtc} -Descending)){
        $responseManifest=Read-VerifiedReadyResponse -Candidate $record.directory -RequestId $RequestId
        if($null-ne$responseManifest){return [pscustomobject]@{path=$record.directory.FullName;root=$record.root;manifest=$responseManifest}}
    }
    return $null
}
function Move-ExistingLedgerToQuarantine {
    param([Parameter(Mandatory=$true)][string]$LedgerPath,[Parameter(Mandatory=$true)][string]$RequestId)
    if(-not(Test-Path -LiteralPath $LedgerPath -PathType Leaf)){return $null}
    $root=Join-Path ([string]$script:config.stateRoot) 'ledger_quarantine'
    [void](Assert-PortalPathBudget -Path $root -ReservedSuffixCharacters 32)
    if(-not(Test-Path -LiteralPath $root -PathType Container)){[void](New-Item -ItemType Directory -Path $root)}
    $leaf='L_'+(Get-ShortSha256 -Text $RequestId -Length 12)+'_'+(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8)+'.json'
    $destination=Join-Path $root $leaf
    [void](Assert-PortalPathBudget -Path $destination -ReservedSuffixCharacters 32)
    if(Test-Path -LiteralPath $destination){throw "Ledger quarantine collision: $destination"}
    Move-Item -LiteralPath $LedgerPath -Destination $destination -ErrorAction Stop
    return $destination
}
function Move-RequestToArchive {
    param([Parameter(Mandatory=$true)][IO.DirectoryInfo]$Package,[Parameter(Mandatory=$true)][string]$ArchiveState)
    $archiveRoot=Join-Path ([string]$script:config.processedRoot) $ArchiveState
    if(-not(Test-Path -LiteralPath $archiveRoot -PathType Container)){[void](New-Item -ItemType Directory -Path $archiveRoot)}
    $archive=Join-Path $archiveRoot $Package.Name
    if(Test-Path -LiteralPath $archive){$archive=Join-Path $archiveRoot ($Package.BaseName+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8)+$Package.Extension)}
    [void](Assert-PortalPathBudget -Path $archive -ReservedSuffixCharacters 32)
    Move-Item -LiteralPath $Package.FullName -Destination $archive -ErrorAction Stop
    return $archive
}
function Process-One {
    $package=Get-ChildItem -LiteralPath ([string]$script:config.incomingRoot) -Directory -Filter '*.ready'|Sort-Object CreationTimeUtc,FullName|Select-Object -First 1
    if($null -eq $package){return $false}
    # The signed manifest carries the full request id. Use only its digest in the
    # transient work path so nested DATA_PULL files cannot hit MAX_PATH merely
    # because an operator chose a descriptive package name.
    $manifest=$null
    $attemptId='J_'+(Get-ShortSha256 -Text $package.BaseName -Length 12)+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $resultRoot=Join-Path ([string]$script:config.stateRoot) ('work\'+$attemptId)
    $state='FAILED';$detail='Endpoint request failed.'
    try{
        & ([string]$script:config.requestVerifierPath) -PackagePath $package.FullName -SignerCertificatePath ([string]$script:config.laptopSignerCertificatePath) -ExpectedTargetRole ([string]$script:config.role)|Out-Null
        $manifest=Get-Content -LiteralPath (Join-Path $package.FullName 'PORTAL_REQUEST_MANIFEST.json') -Raw|ConvertFrom-Json
        $ledgerPath=Join-Path ([string]$script:config.stateRoot) ('ledger\'+[string]$manifest.requestId+'.json')
        $existingResponse=Find-ReadyResponseForRequest -RequestId ([string]$manifest.requestId)
        if($null-ne$existingResponse){
            if(-not(Test-Path -LiteralPath $ledgerPath -PathType Leaf)){
                $existingLedger=[ordered]@{schema='argos_project_portal_request_ledger_v1';requestId=[string]$manifest.requestId;processedUtc=(Get-Date).ToUniversalTime().ToString('o');role=[string]$script:config.role;state=[string]$existingResponse.manifest.state;responsePackage=[string]$existingResponse.path;recoveredReplay=$true;reviewOnly=$true;productionRoutingEnabled=$false}
                Write-NewUtf8Json -Path $ledgerPath -Value $existingLedger
            }
            [void](Move-RequestToArchive -Package $package -ArchiveState 'replayed')
            Write-Status -State 'REQUEST_REPLAY_ARCHIVED' -Detail ([string]$manifest.requestId)
            return $true
        }
        if(Test-Path -LiteralPath $ledgerPath -PathType Leaf){throw 'Portal request ledger exists without its ready response.'}
        [void](Assert-PortalPathBudget -Path $resultRoot -ReservedSuffixCharacters 32)
        if(Test-Path -LiteralPath $resultRoot){throw "Endpoint attempt root collision: $resultRoot"}
        [void](New-Item -ItemType Directory -Path $resultRoot)
        switch([string]$manifest.jobClass){
            'STATUS'{$state=Invoke-StatusHandler -Manifest $manifest -ResultRoot $resultRoot}
            'DATA_PULL'{$state=Invoke-DataPullHandler -Manifest $manifest -ResultRoot $resultRoot}
            'INSITE_DIAGNOSTIC'{$state=Invoke-InsiteDiagnosticHandler -Manifest $manifest -ResultRoot $resultRoot}
            'MAINTENANCE_PATCH'{$state=Invoke-MaintenanceHandler -Manifest $manifest -PackagePath $package.FullName -ResultRoot $resultRoot}
            default{throw "Unsupported portal job class: $($manifest.jobClass)"}
        }
        $detail='Request completed and endpoint verification passed.'
    }catch{
        $detail=$_.Exception.Message
        if(-not(Test-Path -LiteralPath $resultRoot -PathType Container)){
            [void](Assert-PortalPathBudget -Path $resultRoot -ReservedSuffixCharacters 32)
            [void](New-Item -ItemType Directory -Path $resultRoot)
        }
        Write-NewUtf8Json -Path (Join-Path $resultRoot 'FAILURE.json') -Value ([ordered]@{schema='argos_project_portal_failure_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');state='FAILED';detail=$detail;scriptStack=$_.ScriptStackTrace;reviewOnly=$true;productionRoutingEnabled=$false})
    }
    if($null -eq $manifest){
        $manifest=[pscustomobject]@{requestId=$package.BaseName}
    }
    try{
        if([bool](Get-MemberValue $script:config 'rehearsalInjectPrimaryResponseFailure' $false)){throw 'REHEARSAL_INJECTED_PRIMARY_RESPONSE_FAILURE'}
        $response=New-SignedResponse -Request $manifest -ResultRoot $resultRoot -State $state -Detail $detail
    }catch{
        $primaryResponseError=$_.Exception.Message
        $state='FAILED_RESPONSE_CONSTRUCTION'
        $detail='Primary response construction failed; compact signed failure returned. '+$primaryResponseError
        $compactRoot=Join-Path ([string]$script:config.stateRoot) ('compact\C_'+(Get-ShortSha256 -Text ([string]$manifest.requestId) -Length 12)+'_'+[Guid]::NewGuid().ToString('N').Substring(0,8))
        [void](Assert-PortalPathBudget -Path $compactRoot -ReservedSuffixCharacters 32)
        [void](New-Item -ItemType Directory -Path $compactRoot)
        Write-NewUtf8Json -Path (Join-Path $compactRoot 'FAILURE.json') -Value ([ordered]@{schema='argos_project_portal_compact_response_failure_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');requestId=[string]$manifest.requestId;state=$state;detail=$detail;failedAttemptRoot=$resultRoot;reviewOnly=$true;productionRoutingEnabled=$false})
        $response=New-SignedResponse -Request $manifest -ResultRoot $compactRoot -State $state -Detail $detail
    }
    $archiveState=if($state-like'PASS*'){'completed'}else{'failed'}
    $terminalLedgerPath=Join-Path ([string]$script:config.stateRoot) ('ledger\'+[string]$manifest.requestId+'.json')
    $priorLedger=Move-ExistingLedgerToQuarantine -LedgerPath $terminalLedgerPath -RequestId ([string]$manifest.requestId)
    $ledger=[ordered]@{schema='argos_project_portal_request_ledger_v1';requestId=[string]$manifest.requestId;processedUtc=(Get-Date).ToUniversalTime().ToString('o');role=[string]$script:config.role;state=$state;responsePackage=$response;priorLedgerQuarantine=$priorLedger;reviewOnly=$true;productionRoutingEnabled=$false}
    try{Write-NewUtf8Json -Path $terminalLedgerPath -Value $ledger}catch{if($null-ne$priorLedger-and(Test-Path -LiteralPath $priorLedger -PathType Leaf)-and-not(Test-Path -LiteralPath $terminalLedgerPath)){Move-Item -LiteralPath $priorLedger -Destination $terminalLedgerPath -ErrorAction SilentlyContinue};throw}
    [void](Move-RequestToArchive -Package $package -ArchiveState $archiveState)
    Write-Status -State 'REQUEST_PROCESSED' -Detail ([string]$manifest.requestId+' | '+$state)
    return $true
}

$configFull=[IO.Path]::GetFullPath($ConfigPath)
$script:configPath=$configFull
$script:config=Get-Content -LiteralPath $configFull -Raw|ConvertFrom-Json
if(([string]$config.schema -ne 'argos_project_portal_endpoint_config_v1') -or (-not [bool]$config.reviewOnly) -or [bool]$config.productionRoutingEnabled){throw 'Endpoint config safety contract failed.'}
if($Preflight){
    if([string]::IsNullOrWhiteSpace($EnvironmentProbeManifest)){throw 'Environment inventory preflight requires EnvironmentProbeManifest.'}
    $preflightProbePath=[IO.Path]::GetFullPath($EnvironmentProbeManifest)
    $preflightProbe=Get-Content -LiteralPath $preflightProbePath -Raw|ConvertFrom-Json
    if([string]$preflightProbe.schema-ne'argos_project_portal_environment_probe_invocation_v1'){throw 'Environment preflight invocation schema mismatch.'}
    $preflightInventory=Get-EnvironmentInventory -Parameters (Get-MemberValue $preflightProbe 'parameters' $null)
    if($null-eq$preflightInventory){throw 'Environment preflight invocation did not enable inventory.'}
    [ordered]@{schema='argos_project_portal_environment_probe_preflight_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');state='PASS_JBOD_ENVIRONMENT_INVENTORY_PREFLIGHT';inventory=$preflightInventory;mutationsPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false}|ConvertTo-Json -Depth 30
    return
}
if(-not[string]::IsNullOrWhiteSpace($EnvironmentProbeManifest)){
    $probePath=[IO.Path]::GetFullPath($EnvironmentProbeManifest)
    $probe=Get-Content -LiteralPath $probePath -Raw|ConvertFrom-Json
    if([string]$probe.schema-ne'argos_project_portal_environment_probe_invocation_v1'){throw 'Environment probe invocation schema mismatch.'}
    $outputPath=[IO.Path]::GetFullPath([string]$probe.outputPath)
    if(-not(Test-ApprovedDestination $outputPath)){throw "Environment probe output is outside approved maintenance roots: $outputPath"}
    [void](Assert-PortalPathBudget -Path $outputPath -ReservedSuffixCharacters 32)
    $inventory=Get-EnvironmentInventory -Parameters (Get-MemberValue $probe 'parameters' $null)
    if($null-eq$inventory){throw 'Environment probe invocation did not enable inventory.'}
    $result=[ordered]@{schema='argos_project_portal_environment_probe_result_v1';createdUtc=(Get-Date).ToUniversalTime().ToString('o');state='PASS_JBOD_ENVIRONMENT_INVENTORY';workerPath=[IO.Path]::GetFullPath($MyInvocation.MyCommand.Path);workerSha256=(Get-FileHash -LiteralPath ([IO.Path]::GetFullPath($MyInvocation.MyCommand.Path)) -Algorithm SHA256).Hash;inventory=$inventory;reviewOnly=$true;productionRoutingEnabled=$false}
    Write-NewUtf8Json -Path $outputPath -Value $result
    $result|ConvertTo-Json -Depth 30
    return
}
foreach($path in @([string]$config.incomingRoot,[string]$config.processedRoot,[string]$config.responseOutbox,[string]$config.stateRoot)){if(-not (Test-Path -LiteralPath $path)){[void](New-Item -ItemType Directory -Path $path)}}
Write-Status -State 'WATCHING' -Detail ([string]$config.incomingRoot)
do{
    $processed=Process-One
    if($Once){break}
    if(-not $processed){Start-Sleep -Seconds 2}
}while($true)
