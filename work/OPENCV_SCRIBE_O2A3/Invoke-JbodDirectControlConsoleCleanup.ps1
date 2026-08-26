[CmdletBinding()]
param([switch]$Preflight)
$ErrorActionPreference='Stop'
$ids=[uint32[]](33032,27788,38176,25400,27964,39712,17516,35160,33428)
$protected=[uint32[]](3556,11008,8504)
if($Preflight){[ordered]@{schema='argos_jbod_direct_console_cleanup_preflight_v1';state='PASS_JBOD_DIRECT_CONSOLE_CLEANUP_PREFLIGHT';computerNameRequired='A1025645101';targetProcessIds=$ids;protectedProcessIds=$protected;targetExecuted=$false;mutationsPerformed=$false}|ConvertTo-Json -Compress;return}
if($env:COMPUTERNAME-ne'A1025645101'){throw'Wrong computer'}
$targets=@()
foreach($id in $ids){$p=Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction Stop;if($null-eq$p-or$p.Name-ne'powershell.exe'-or[uint32]$p.ParentProcessId-ne 20648-or[string]$p.CommandLine-match'(?i)-(File|EncodedCommand|Command|WindowStyle)'){throw"Target premise changed: $id"};$targets+=,$p}
foreach($id in $protected){if($null-eq(Get-CimInstance Win32_Process -Filter "ProcessId=$id" -ErrorAction SilentlyContinue)){throw"Protected process absent before cleanup: $id"}}
foreach($p in $targets){Stop-Process -Id $p.ProcessId -ErrorAction Stop}
Start-Sleep -Milliseconds 750
$remaining=@($ids|Where-Object {Get-Process -Id $_ -ErrorAction SilentlyContinue})
$protectedAfter=@($protected|Where-Object {Get-Process -Id $_ -ErrorAction SilentlyContinue})
if($remaining.Count-ne 0-or$protectedAfter.Count-ne$protected.Count){throw'Cleanup terminal invariant failed'}
[ordered]@{schema='argos_jbod_direct_console_cleanup_terminal_v1';state='PASS_JBOD_DIRECT_CONSOLES_CLOSED';computerName=$env:COMPUTERNAME;closedProcessIds=$ids;closedCount=$ids.Count;protectedProcessIds=$protectedAfter;protectedProcessCount=$protectedAfter.Count;taskActionsPerformed=$false;sourceMutationPerformed=$false;reviewOnly=$true;productionRoutingEnabled=$false;mutationsPerformed=$true}|ConvertTo-Json -Compress
